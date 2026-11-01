--!nonstrict
-- AI 2.0 (Tarkov-style). Factions: AI scavs (leave player scavs alone unless provoked), the Harbor Watch
-- (raider-type guards, hostile to everyone else) and the Foreman with his crew (scav-aligned boss group).
-- Perception: vision builds awareness over time (distance, stance, movement, weapon light), hearing of
-- footsteps and gunshots, suppression from near misses, call-outs to nearby allies.
-- Tactics: cover points generated from the map, peek-and-hide, reload and heal in cover, strafe in the open,
-- search the last known position, followers stay with the boss and flank.
-- Grenades (M11): units with frags or stun charges flush targets that stay hidden behind cover, throw smoke to
-- cover a retreat, run from grenades that land near them; smoke blocks their sight, flashes blind and deafen.
-- Weapons are real: the rounds come from the AI's own magazines, reloads use its rig, every hit goes through the
-- same ballistics/armour model as players, and the body drops everything it carried.
-- A director spawns scavs at raid start, tops up as players join and sends waves through the raid.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local DEV = RunService:IsStudio()
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Weapons = require(Shared.Weapons)
local RigMath = require(Shared.RigMath)
local Inv = require(script.Parent.Inv)
local Env = require(Shared.Env)
local GR = require(Shared.Grenades)
local Ballistics = require(Shared.Ballistics)
local Progress = require(Shared.Progress)
local KARMA_HOSTILE = Progress.KARMA.hostileBelow

local AI = {}
local ctx
local units = {}
AI.units = units
AI.guards = units -- older name used by tools
local folder
local gen = 0
local seq = 0
local cover = { cells = {}, n = 0, ready = false }
AI.cover = cover
local director = { nextWave = math.huge, topUpUntil = 0, waves = 0, nextTopUp = 0 }
AI.director = director
-- the raid's light and weather (M10): darkness and fog shorten sight, rain masks footsteps; refreshed each second
local envView = { sight = 1, hear = 1, dark = 0 }
AI.envView = envView
local function refreshEnv()
	local e = ctx.Match and ctx.Match.env
	local t = workspace:GetServerTimeNow()
	envView.sight = Env.sight(e, t)
	envView.hear = Env.hearing(e)
	envView.dark = e and (1 - Env.daylight(Env.clock(e, t))) or 0
end

-- skill per kind: sight range, awareness build-up, hearing, reaction (s), aim error (deg + deg/stud),
-- head-shot share, cover use, aggression, reload speed, health scale
local SKILL = {
	scav = { sight = 125, notice = 1.5, hearing = 0.85, react = { 0.8, 1.5 }, spread = 3.6, spreadDist = 0.032, head = 0.04, cover = 0.45, aggression = 0.35, reload = 1.25, hp = 1, burstPause = 1.25, suppress = false },
	watch = { sight = 165, notice = 2.4, hearing = 1.0, react = { 0.55, 0.95 }, spread = 2.2, spreadDist = 0.016, head = 0.1, cover = 0.9, aggression = 0.6, reload = 1.0, hp = 1, burstPause = 1, suppress = true },
	follower = { sight = 165, notice = 2.6, hearing = 1.1, react = { 0.5, 0.9 }, spread = 1.9, spreadDist = 0.014, head = 0.12, cover = 0.8, aggression = 0.75, reload = 0.95, hp = 1.2, burstPause = 0.95, suppress = true },
	boss = { sight = 170, notice = 3.0, hearing = 1.2, react = { 0.45, 0.8 }, spread = 1.6, spreadDist = 0.012, head = 0.15, cover = 0.7, aggression = 0.85, reload = 0.9, hp = 1.6, burstPause = 0.9, suppress = true },
}
AI.SKILL = SKILL
local LABEL = { scav = "Scav", watch = "Harbor Watch", follower = "Crew", boss = "Foreman" }
local FACTION = { scav = "scav", watch = "watch", follower = "scav", boss = "scav" }
-- AI kind -> look (Equipment.PRESETS: scav -> scav, watch -> guard, follower -> bodyguard, boss -> foreman)
local Equipment = require(Shared.Equipment)
local LOOK = {}
for _, k in { "scav", "watch", "follower", "boss" } do
	LOOK[k] = Equipment.lookForAi(k)
end
local FOV_COS = math.cos(math.rad(62))
local CLOSE = 9
-- an ambusher lying in wait (THE CULT) listens all round: within this it picks out anyone who comes near, dark or not
local AMBUSH_SENSE = 22
local WALK, RUN, CROUCH = 8, 15, 5

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local worldParams = RaycastParams.new()
worldParams.FilterType = Enum.RaycastFilterType.Include
worldParams.IgnoreWater = true -- terrain maps (M13): hills and ground count, lake water does not

-- breakable glass (Glass.init): sight and aim checks are cast in a group that passes whole panes and their hit shells, so the AI
-- sees and shoots through windows as in Tarkov (its bullets still meet the glass and break it)
function AI.setSightGroup(group)
	params.CollisionGroup = group
	worldParams.CollisionGroup = group
end

local function now()
	return os.clock()
end
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local function rnd(a, b)
	return a + math.random() * (b - a)
end
local function rndr(r)
	return r[1] + math.random() * (r[2] - r[1])
end

local function alive(model)
	local hum = model and model.Parent and model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function byModel(model)
	for _, u in units do
		if u.model == model then
			return u
		end
	end
	return nil
end
AI.byModel = byModel

local function ignoreFor(u)
	return { u and u.model or nil, workspace:FindFirstChild("ZR_Corpses"), workspace:FindFirstChild("ZR_Loot"), workspace:FindFirstChild("ZR_Fx") }
end

-- ── friend / foe ─────────────────────────────────────────────────────────────
-- who is this character? { player, s } for raiders, { unit } for AI, nil otherwise
local function who(model)
	local p = Players:GetPlayerFromCharacter(model)
	if p then
		local s = ctx.Raid.session(p)
		if s and not s.done then
			return { player = p, s = s }
		end
		return nil
	end
	local o = byModel(model)
	return (o and o.alive) and { unit = o } or nil
end

-- pure rule (tested): AI never fight each other (the Watch and the scavs keep an uneasy truce); AI scavs and
-- the boss group leave player scavs alone unless that scav turned on them; the Watch shoots every raider.
function AI.hostileTo(faction, w)
	if w.unit then
		return false
	end
	if w.s and w.s.scav and faction == "scav" and not w.s.hostile and ((w.s.karma or 0) + (w.s.karmaDelta or 0)) >= KARMA_HOSTILE then
		return false
	end
	return true
end

-- THE FORESTER (Tarkov's Partisan, docs/design/BOSS_FORESTER.md) hunts raiders whose karma is low; anyone else only once
-- they come within `close` studs of him or hurt him, and then for the rest of the raid (u.grudge). Karma here is the
-- Fence standing (Progress.KARMA; Tarkov's PMC karma is hidden and has no counterpart). `chance` adds `perLow` to his
-- roll for every raider with low karma in the queue, up to `cap`.
AI.FOREST = { karma = 0, close = 25, perLow = 0.1, cap = 0.5 }
function AI.forestHostile(karma, grudge, dist)
	return (karma or 0) < AI.FOREST.karma or grudge == true or (dist ~= nil and dist < AI.FOREST.close)
end
function AI.forestChance(base, karmas)
	local n = 0
	for _, k in karmas or {} do
		if (k or 0) < AI.FOREST.karma then
			n += 1
		end
	end
	return math.min(AI.FOREST.cap, base + AI.FOREST.perLow * n)
end

local function hostile(u, w)
	if not w then
		return false
	end
	if w.player and DEV and w.player:GetAttribute("DevIgnore") then
		return false
	end
	if u.karmaHunt and w.player then
		local s = w.s
		local root = w.player.Character and w.player.Character:FindFirstChild("HumanoidRootPart")
		local dist = (root and u.root) and (root.Position - u.root.Position).Magnitude or nil
		local on = AI.forestHostile(s and ((s.karma or 0) + (s.karmaDelta or 0)), u.grudge[w.player], dist)
		if on and dist and dist < AI.FOREST.close then
			u.grudge[w.player] = true -- too close: he remembers you
		end
		return on
	end
	return AI.hostileTo(u.faction, w)
end

-- ── cover points (generated once from the map) ──────────────────────────────
local CELL = 16
local function cellKey(x, z)
	return math.floor(x / CELL) .. "," .. math.floor(z / CELL)
end

local function addCover(c)
	local k = cellKey(c.pos.X, c.pos.Z)
	local list = cover.cells[k]
	if not list then
		list = {}
		cover.cells[k] = list
	end
	table.insert(list, c)
	cover.n += 1
end

local function coverNear(pos, r)
	local out = {}
	local x0, x1 = math.floor((pos.X - r) / CELL), math.floor((pos.X + r) / CELL)
	local z0, z1 = math.floor((pos.Z - r) / CELL), math.floor((pos.Z + r) / CELL)
	for cx = x0, x1 do
		for cz = z0, z1 do
			for _, c in cover.cells[cx .. "," .. cz] or {} do
				if flat(c.pos - pos).Magnitude <= r then
					table.insert(out, c)
				end
			end
		end
	end
	return out
end
AI.coverNear = coverNear

local DIRS = {}
for i = 0, 7 do
	local a = i * math.pi / 4
	table.insert(DIRS, Vector3.new(math.cos(a), 0, math.sin(a)))
end

-- a point is cover when something solid sits within reach at crouched-chest height in some directions but it
-- is not boxed in; "full" cover also hides a standing body.
local function buildCover()
	workspace:WaitForChild("ZR_World", 30)
	local models = ctx.World.mapModels()
	if #models == 0 then
		warn("[ZR] AI: no map for cover")
		return
	end
	-- terrain maps (Pinewatch): the ground and hills are terrain, so sight and cover rays take it too
	local solid = table.clone(models)
	table.insert(solid, workspace.Terrain)
	worldParams.FilterDescendantsInstances = solid
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = models
	local count = 0
	-- every map has its own area, floor range and sample step (Quay 7: yard to mezzanine; Smelter: tunnels to
	-- catwalks; Border Yard: Customs at real scale, sampled every 8 studs). The map in play goes first, so its AI
	-- have cover while the big maps are still being sampled.
	local order = {}
	for id, m in ctx.World.maps do
		table.insert(order, { id = id, m = m })
	end
	local active = ctx.World.activeMap
	table.sort(order, function(a, b)
		if (a.id == active) ~= (b.id == active) then
			return a.id == active
		end
		return a.id < b.id
	end)
	for _, entry in order do
		local m = entry.m
		local b = m.bounds
		if not b then
			continue
		end
		local step = b.step or 3
		for x = b.x0, b.x1, step do
			for z = b.z0, b.z1, step do
				-- every walkable level at this spot (yard, building floors under roofs, catwalks, tunnels)
				local floors = {}
				local y = math.max(60, b.yMax + 20)
				for _ = 1, 6 do
					local hit = workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, -(y - b.yMin + 10), 0), worldParams)
					if not hit then
						break
					end
					if hit.Position.Y < b.yMax and hit.Normal.Y > 0.8 then
						table.insert(floors, hit.Position)
					end
					y = hit.Position.Y - 1.6
					if y < b.yMin then
						break
					end
				end
				for _, p in floors do
					local blocked = workspace:GetPartBoundsInBox(CFrame.new(p + Vector3.new(0, 3.3, 0)), Vector3.new(2, 5.4, 2), op)
					if #blocked == 0 then
						local dirs, full = {}, false
						for _, d in DIRS do
							if workspace:Raycast(p + Vector3.new(0, 2.4, 0), d * 3.2, worldParams) then
								table.insert(dirs, d)
								if workspace:Raycast(p + Vector3.new(0, 5.4, 0), d * 3.4, worldParams) then
									full = true
								end
							end
						end
						if #dirs > 0 and #dirs <= 5 then
							addCover({ pos = p, dirs = dirs, full = full })
						end
					end
				end
				count += 1
				if count % 300 == 0 then
					task.wait()
				end
			end
		end
	end
	cover.ready = true
	print(string.format("[ZR] AI cover points: %d", cover.n))
end

-- is a crouched head at cover point c hidden from an eye at `from` (static geometry only)?
local function hiddenFrom(c, from)
	local head = c.pos + Vector3.new(0, 2.7, 0)
	local r = workspace:Raycast(from, head - from, worldParams)
	return r ~= nil and (r.Position - head).Magnitude < 7
end

-- can an eye at `from` see `to` past the static world?
local function worldClear(from, to)
	return workspace:Raycast(from, to - from, worldParams) == nil
end

local function findCover(u, threat, threatEye)
	if not cover.ready then
		return nil
	end
	local me = u.root.Position
	local t = now()
	local cands = {}
	for _, c in coverNear(me, 40) do
		local toT = flat(threat - c.pos)
		local dT = toT.Magnitude
		if dT > 9 and dT < 160 and not (c.owner and c.owner ~= u and c.owner.alive and t < (c.ownerUntil or 0)) then
			local dir = toT.Unit
			local prot = false
			for _, cd in c.dirs do
				if cd:Dot(dir) > 0.55 then
					prot = true
					break
				end
			end
			if prot then
				local dMe = flat(c.pos - me).Magnitude
				-- cautious AI prefer cover away from the threat, aggressive AI cover that closes the distance
				local closer = flat(threat - me).Magnitude - dT
				local score = -dMe + closer * (u.skill.aggression - 0.5) * 0.8 + (c.full and 2 or 0)
				table.insert(cands, { c = c, score = score })
			end
		end
	end
	table.sort(cands, function(a, b)
		return a.score > b.score
	end)
	for i = 1, math.min(5, #cands) do
		local c = cands[i].c
		if hiddenFrom(c, threatEye) then
			-- where to peek from: stand up behind low cover, step out sideways from full cover
			local peek = nil
			local fwd = flat(threat - c.pos).Unit
			local side = Vector3.new(-fwd.Z, 0, fwd.X)
			for _, s in { 1, -1 } do
				local pp = c.pos + side * s * 2.4
				if worldClear(c.pos + Vector3.new(0, 2.5, 0), pp + Vector3.new(0, 2.5, 0)) and worldClear(pp + Vector3.new(0, 5, 0), threatEye) then
					peek = pp
					break
				end
			end
			if not c.full and not peek and worldClear(c.pos + Vector3.new(0, 5.2, 0), threatEye) then
				peek = c.pos -- standing up is enough
			end
			c.owner = u
			c.ownerUntil = t + 30
			return { c = c, pos = c.pos, peek = peek, full = c.full }
		end
	end
	return nil
end

-- ── perception helpers ───────────────────────────────────────────────────────
local function exposure(model)
	local f = 1
	local st = model:GetAttribute("Stance")
	if st == "c" then
		f *= 0.7
	elseif st == "p" then
		f *= 0.45
		-- lying in grass (terrain maps) hides most of a body
		local hum = model:FindFirstChildOfClass("Humanoid")
		local fm = hum and hum.FloorMaterial
		if fm == Enum.Material.Grass or fm == Enum.Material.LeafyGrass then
			f *= 0.6
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local v = root and flat(root.AssemblyLinearVelocity).Magnitude or 0
	f *= (v > 2) and 1.25 or 0.85
	if model:GetAttribute("WeaponLight") then
		f *= (envView.dark > 0.5) and 3 or 1.3
	end
	return f
end

-- footstep loudness 0..1 (server view of what the client plays): sprint > walk > crouch > prone
local function rawNoise(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return 0
	end
	local v = flat(root.AssemblyLinearVelocity).Magnitude
	if v < 1.5 then
		return 0
	end
	if model:GetAttribute("Sprint") then
		return 1
	end
	local st = model:GetAttribute("Stance") or "s"
	if st == "p" then
		return 0.12
	elseif st == "c" then
		return 0.22 * math.min(1, v / 6)
	end
	return 0.5 * math.min(1.2, v / Config.WALK_SPEED)
end

-- a player's Covert Movement skill: footsteps carry less far
local function noiseOf(model)
	local n = rawNoise(model)
	local pl = n > 0 and Players:GetPlayerFromCharacter(model)
	local prof = pl and ctx.Profiles.get(pl)
	return prof and n * (1 - Progress.bonus(prof.skills, "covert")) or n
end

local function visiblePart(u, model, eye)
	params.FilterDescendantsInstances = ignoreFor(u)
	local G = ctx.Grenades
	local smoke = G ~= nil and #G.smokes > 0
	-- M13 bushes and young pines take no shots (no queries) but hide what is behind or inside them; right up close
	-- the movement still gives you away
	local W = ctx.World
	local leafy = W.foliage ~= nil and W.foliage.n > 0
	for _, name in { "Head", "UpperTorso", "LowerTorso" } do
		local p = model:FindFirstChild(name)
		if p and not (smoke and G.smokeBetween(eye, p.Position)) and not (leafy and (p.Position - eye).Magnitude > 6 and W.foliageBetween(eye, p.Position)) then
			local r = workspace:Raycast(eye, p.Position - eye, params)
			if r == nil or r.Instance:IsDescendantOf(model) then
				return p
			end
		end
	end
	return nil
end
AI.visiblePart = visiblePart -- the first of the head and torso parts of `model` in sight of `eye`, or nil (Stationary crews)

local function candidates(u)
	local out = {}
	for player, s in ctx.Raid.sessions() do
		if not s.done then
			local char = player.Character
			if char and alive(char) and hostile(u, { player = player, s = s }) then
				table.insert(out, char)
			end
		end
	end
	local me = u.root.Position
	for _, o in units do
		if o ~= u and o.alive and o.root and hostile(u, { unit = o }) and (o.root.Position - me).Magnitude < 130 then
			table.insert(out, o.model)
		end
	end
	return out
end

-- allies near u (same faction) learn about the target; the boss's crew always does
local function callout(u, target)
	local pos = u.lastPos[target] or (target.Parent and target:GetPivot().Position)
	if not pos then
		return
	end
	local t = now()
	for _, o in units do
		if o ~= u and o.alive and o.faction == u.faction then
			local d = (o.root.Position - u.root.Position).Magnitude
			local crew = (o.leader == u) or (u.leader == o) or (o.leader ~= nil and o.leader == u.leader)
			if d < 45 or (crew and d < 100) then
				o.aware[target] = math.max(o.aware[target] or 0, 0.8)
				o.lastPos[target] = pos
				if o.state ~= "ENGAGE" then
					o.state = "INVESTIGATE"
					o.goal = pos
					o.searchUntil = t + 16
					o.alert = t + 20
				end
			end
		end
	end
end

-- ── body: stance, facing, movement ──────────────────────────────────────────
local function setStance(u, st, depth)
	depth = depth or 0.8
	if u.stance ~= st or u.depth ~= depth then
		u.stance, u.depth = st, depth
		u.hum.HipHeight = RigMath.hipFor(st, depth)
	end
end

local function face(u, pos)
	u.hum.AutoRotate = false
	local d = flat(pos - u.root.Position)
	if d.Magnitude > 0.5 and u.turn then
		u.turn.CFrame = CFrame.lookAt(Vector3.zero, d)
		u.turn.Enabled = true
	end
end

local function freeTurn(u)
	u.hum.AutoRotate = true
	if u.turn then
		u.turn.Enabled = false
	end
end

local function stop(u)
	if u.moving then
		u.moving = false
		u.hum:MoveTo(u.root.Position)
	end
	u.sprint = false
end

local function newPath()
	-- radius 1.0 (the body is 2 studs wide): at 1.6, 1.4 or 1.2 no path led up Border's dog-leg stairs (4.7-stud flights
	-- between rails), so the AI never followed anyone upstairs in the dorms (Studio 2026-11-01, KNOWN_ISSUES 68)
	return PathfindingService:CreatePath({ AgentRadius = 1.0, AgentHeight = 5.6, AgentCanJump = false, WaypointSpacing = 5 })
end

local function moveTo(u, goal, run, keepFacing)
	local t = now()
	u.moving = true
	if not keepFacing then
		freeTurn(u)
	end
	u.sprint = run and u.stance ~= "c" and not keepFacing
	u.hum.WalkSpeed = (u.stance == "c") and CROUCH or ((run and not keepFacing) and RUN or WALK)
	if not u.pathGoal or (u.pathGoal - goal).Magnitude > 4 or t >= (u.nextPath or 0) then
		u.nextPath = t + 2.5
		u.pathGoal = goal
		u.pathObj = u.pathObj or newPath()
		local ok = pcall(function()
			u.pathObj:ComputeAsync(u.root.Position, goal)
		end)
		if ok and u.pathObj.Status == Enum.PathStatus.Success then
			u.path = u.pathObj:GetWaypoints()
			u.pathI = math.min(2, #u.path)
		else
			u.path = nil
		end
	end
	local wp = goal
	if u.path and u.path[u.pathI] then
		wp = u.path[u.pathI].Position
		if flat(wp - u.root.Position).Magnitude < 2.6 then
			u.pathI += 1
			wp = u.path[u.pathI] and u.path[u.pathI].Position or goal
		end
	end
	-- doors on the way: open unlocked ones (checked a couple of times a second)
	if t >= (u.nextDoorCheck or 0) and ctx.Doors then
		u.nextDoorCheck = t + 0.4
		local dir = flat(wp - u.root.Position)
		if dir.Magnitude > 0.1 then
			dir = dir.Unit
			for _, d in ctx.Doors.near(u.root.Position, 6) do
				local to = flat(d.cf.Position - u.root.Position)
				if to.Magnitude < 1.6 or dir:Dot(to.Unit) > 0.35 then
					ctx.Doors.aiOpen(d)
				end
			end
		end
	end
	u.hum:MoveTo(wp)
	-- stuck: re-path, then give up on this goal
	if t - (u.stuckT or 0) > 2 then
		if u.stuckPos and flat(u.root.Position - u.stuckPos).Magnitude < 1 then
			u.stuck = (u.stuck or 0) + 1
			u.nextPath = 0
		else
			u.stuck = 0
		end
		u.stuckPos = u.root.Position
		u.stuckT = t
	end
end

local function lookAround(u, t)
	if t >= (u.nextLook or 0) then
		u.nextLook = t + rnd(1.8, 4.5)
		local a = math.random() * math.pi * 2
		face(u, u.root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * 10)
	end
end

-- ── weapons ──────────────────────────────────────────────────────────────────
local function weaponIn(u, slot)
	local g = u.inv.slots[slot]
	local it = g and u.inv.items[g]
	local wd = it and Items.defs[it.id]
	local def = wd and wd.weapon and Weapons[wd.weapon]
	if not def or def.melee then
		return nil
	end
	return { g = g, slot = slot, def = def, wd = wd }
end

local function magOf(u)
	local w = u.w
	local it = w and u.inv.items[w.g]
	if not it then
		return nil
	end
	if w.wd.family then
		return it.mag and u.inv.items[it.mag] or nil
	end
	return it
end

local function roundsOf(u)
	local m = magOf(u)
	return m and (m.a or 0) or 0
end

local function capacityOf(u)
	local w = u.w
	if not w then
		return 0
	end
	if w.wd.family then
		local m = magOf(u)
		local md = m and Items.defs[m.id]
		return md and md.capacity or 10
	end
	return Inv.capacityOf(u.inv, w.g) or w.wd.capacity or 5
end

local function ammoStack(u, caliber)
	for _, cid in Inv.loadOrder(u.inv) do
		for g in u.inv.grids[cid] or {} do
			local it = u.inv.items[g]
			local d = it and Items.defs[it.id]
			if d and d.kind == "ammo" and d.caliber == caliber then
				return g
			end
		end
	end
	return nil
end

local function canReload(u)
	local w = u.w
	if not w then
		return false
	end
	if w.wd.family then
		local best = Inv.bestMag(u.inv, w.g)
		return best ~= nil and (u.inv.items[best].a or 0) > 0
	end
	local it = u.inv.items[w.g]
	return (it.a or 0) < (Inv.capacityOf(u.inv, w.g) or 0) and ammoStack(u, w.wd.caliber) ~= nil
end

-- tactical light on the AI's weapon (third-person SpotLight follows the WeaponLight attribute, like players)
local function setLight(u, on)
	local wg = u.w and u.w.g
	on = on == true and wg ~= nil and u.inv.items[wg] ~= nil and Inv.modStats(u.inv, wg).light == true
	if u.lightOn == on then
		return
	end
	u.lightOn = on
	u.model:SetAttribute("WeaponLight", on)
	for _, c in u.model:GetChildren() do
		if c.Name == "TPWeapon" then
			local l = c:FindFirstChild("WeaponLight")
			if l then
				l.Enabled = on
			end
		end
	end
end

local function equip(u, w)
	u.w = w
	u.lightOn = nil
	u.laserOn = nil
	u.model:SetAttribute("WeaponLaser", false)
	if w then
		ctx.Chars.setWeapon(u.model, u.inv, w.g)
		ctx.Chars.gesture(u.model, "draw", w.def.draw or 0.6)
		u.nextShot = now() + (w.def.draw or 0.6)
	end
end

local function startReload(u, t)
	local w = u.w
	if not w or u.reloadUntil then
		return false
	end
	if w.wd.family then
		local best = Inv.bestMag(u.inv, w.g)
		if not best or (u.inv.items[best].a or 0) <= 0 then
			return false
		end
		local cur = magOf(u)
		local dur = ((cur and (cur.a or 0) > 0) and w.def.reload or w.def.reloadEmpty) * u.skill.reload
		u.reloadUntil = t + dur
		u.reloadMag = best
		ctx.Chars.gesture(u.model, "reload", dur)
	else
		if not ammoStack(u, w.wd.caliber) then
			return false
		end
		local dur = w.def.reload * u.skill.reload
		u.reloadUntil = t + dur
		u.tube = true
		ctx.Chars.gesture(u.model, "tube", dur)
	end
	u.burstN = 0
	return true
end

local function reloadTick(u, t)
	if not u.reloadUntil or t < u.reloadUntil then
		return
	end
	local w = u.w
	u.reloadUntil = nil
	if not w or not u.inv.items[w.g] then
		return
	end
	if u.tube then
		local ag = ammoStack(u, w.wd.caliber)
		if ag then
			Inv.loadAmmo(u.inv, w.g, ag, 1)
		end
		local it = u.inv.items[w.g]
		-- keep loading shells unless the fight needs the gun now
		local busy = u.state == "ENGAGE" and u.visible and (it.a or 0) >= 1 and math.random() < 0.5
		if (it.a or 0) < (Inv.capacityOf(u.inv, w.g) or 0) and ammoStack(u, w.wd.caliber) and not busy then
			local dur = w.def.reload * u.skill.reload
			u.reloadUntil = t + dur
			ctx.Chars.gesture(u.model, "tube", dur)
		else
			u.tube = nil
		end
		return
	end
	local best = u.reloadMag
	u.reloadMag = nil
	if not best or not u.inv.items[best] then
		return
	end
	local okI, err = Inv.insertMag(u.inv, best, w.g)
	if not okI and err == "NO_SPACE" then
		local it = u.inv.items[w.g]
		local b = it.mag and Inv.take(u.inv, it.mag)
		if b then
			ctx.Loot.spawnPile(u.root.Position - Vector3.new(0, 2.5, 0), { b })
		end
		Inv.insertMag(u.inv, best, w.g)
	end
end

-- out of rounds and nothing to reload: draw another gun that still has ammo
local function rearm(u)
	for _, slot in { "primary", "secondary", "holster" } do
		local w = weaponIn(u, slot)
		if w and (not u.w or w.g ~= u.w.g) then
			local old = u.w
			u.w = w
			if roundsOf(u) > 0 or canReload(u) then
				equip(u, w)
				return true
			end
			u.w = old
		end
	end
	return false
end

-- ── shooting ─────────────────────────────────────────────────────────────────
local function shoot(u, t)
	local w = u.w
	local m = magOf(u)
	if not w or not m or (m.a or 0) <= 0 then
		u.wantFire = false
		return
	end
	local tm = u.target
	local aimPos
	if u.visible and tm and tm.Parent then
		local part = tm:FindFirstChild(u.aimPart or "UpperTorso") or tm:FindFirstChild("UpperTorso")
		aimPos = part and part.Position
	else
		aimPos = u.suppressPos
	end
	if not aimPos then
		return
	end
	local rcf = u.root.CFrame
	local muzzle = u.head.Position + rcf.LookVector * 1.2 + rcf.RightVector * 0.22 - Vector3.new(0, 0.35, 0)
	params.FilterDescendantsInstances = ignoreFor(u)
	-- never shoot through a friend
	local pre = workspace:Raycast(muzzle, aimPos - muzzle, params)
	if pre then
		local pm = pre.Instance:FindFirstAncestorOfClass("Model")
		local pu = pm and byModel(pm)
		if pu and pu.alive and pu.faction == u.faction then
			u.nextShot = t + 0.6
			u.blockedAt = t
			return
		end
	end
	local sk = u.skill
	local dist = (aimPos - muzzle).Magnitude
	local err = sk.spread + dist * sk.spreadDist
	local troot = tm and tm:FindFirstChild("HumanoidRootPart")
	if troot and flat(troot.AssemblyLinearVelocity).Magnitude > 4 then
		err += 1.1
	end
	if flat(u.root.AssemblyLinearVelocity).Magnitude > 2 then
		err += 1.5
	end
	if t < (u.suppressedUntil or 0) then
		err += 1.3
	end
	if t < (u.blindUntil or 0) then
		err += 7 -- flashed: spraying at where they last saw you
	end
	if u.stance == "c" and not u.moving then
		err *= 0.85
	end
	err += math.max(0, 3 - (t - (u.spottedAt or 0)) * 1.2) -- zeroing in over the first seconds of a fight
	err += (u.burstN or 0) * w.def.recoilV * 0.28
	if not u.visible then
		err += 2
	end
	local ammoDef = m.at and Items.defs[m.at]
	local ballistic = ammoDef and ammoDef.ammo or { dmg = 40, pen = 20 }
	local pellets = ballistic.pellets or 1
	local hit, firstPos, firstNormal, firstMat = false, nil, nil, nil
	local ms = Inv.modStats(u.inv, w.g)
	-- ballistics: the AI holds over for the drop at the target's distance, then the bullet flies like a player's
	local v0, k = Ballistics.muzzle(w.def, ms.vel), Ballistics.drag(w.def)
	local aimAt = aimPos + Vector3.new(0, Ballistics.dropAt((aimPos - muzzle).Magnitude, v0, k), 0)
	local base = CFrame.lookAt(muzzle, aimAt)
	local shotParams = Ballistics.copyParams(params)
	for i = 1, pellets do
		local e = err + ((pellets > 1) and (w.def.pelletSpread or 2.5) or 0)
		local dir = (base * CFrame.Angles(math.rad((math.random() * 2 - 1) * e * 0.75), math.rad((math.random() * 2 - 1) * e), 0)).LookVector
		local pr, hp = Ballistics.trace(muzzle, dir, v0, k, w.def.range, shotParams)
		if i == 1 then
			firstPos, firstNormal, firstMat = hp, pr and pr.Normal or nil, pr and pr.Material or nil
		end
		local pmod = pr and pr.Instance:FindFirstAncestorOfClass("Model")
		hit = hit or (pmod ~= nil and pmod ~= u.model and pmod:FindFirstChildOfClass("Humanoid") ~= nil)
		Ballistics.fly(muzzle, dir, v0, k, w.def.range, shotParams, function(r, hitPos, d, _, keep)
			if ctx.Hazards.hit(r.Instance, u.model) then
				return
			end
			keep = type(keep) == "number" and keep or 1 -- the share of its damage the bullet kept through panes of glass
			local model = r.Instance:FindFirstAncestorOfClass("Model")
			local hum = model and model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and model ~= u.model then
				local fs = w.def.range * Weapons.FALLOFF_START
				local fall = 1
				if d > fs then
					fall = math.max(Weapons.FALLOFF_MIN, 1 - (d - fs) / (w.def.range - fs) * (1 - Weapons.FALLOFF_MIN))
				end
				ctx.Combat.hitModel(model, {
					dmg = ballistic.dmg * fall * keep, pen = (ballistic.pen or 0) * (0.85 + 0.15 * fall) * keep, armorDmg = ballistic.armorDmg,
					bleedL = ballistic.bleedL, bleedH = ballistic.bleedH, part = r.Instance, hitPos = hitPos, attacker = u.model,
					from = muzzle, weapon = w.wd.name, ammo = ammoDef and ammoDef.name or "?",
				})
			end
		end)
	end
	m.a -= 1
	if m.a <= 0 then
		m.a = 0
		m.at = nil
	end
	ctx.Remotes.fx("shot", { o = muzzle, p = firstPos, n = firstNormal, h = hit, w = w.def.id, s = ms.suppressed or nil, t = ballistic.tracer, m = firstMat, ai = true })
	AI.hearShot(muzzle, u.model, u, (w.def.loudness or 1) * ms.loud)
	AI.bulletPassed(muzzle, firstPos, u.model)
	-- next shot: bursts for automatics (shorter at range), taps for semi, cycling for pump/bolt
	local cls = w.def.class
	local interval = 60 / w.def.rpm
	if cls == "rifle" or cls == "smg" then
		u.burstN = (u.burstN or 0) + 1
		if u.burstN >= (u.burstLen or 3) then
			u.burstN = 0
			u.burstLen = (dist < 20 and math.random(4, 8)) or (dist < 60 and math.random(2, 5)) or math.random(1, 2)
			u.nextShot = t + rnd(0.3, 0.8) * sk.burstPause
			u.aimPart = (math.random() < sk.head) and "Head" or ((math.random() < 0.08) and "LowerTorso" or "UpperTorso")
		else
			u.nextShot = t + interval
		end
	elseif cls == "pistol" then
		u.nextShot = t + math.max(interval, rnd(0.25, 0.55))
	elseif cls == "shotgun" then
		u.nextShot = t + math.max(interval, 0.85) + rnd(0, 0.35)
		ctx.Chars.gesture(u.model, "pump", 0.5)
	else
		u.nextShot = t + math.max(interval, 1.35) + rnd(0, 0.6)
		ctx.Chars.gesture(u.model, "bolt", 0.8)
	end
	if m.a <= 0 then
		u.wantFire = false
	end
end

-- ── states ───────────────────────────────────────────────────────────────────
local function pickZone(u)
	local zones = ctx.World.scavZones or {}
	local me = u.root.Position
	local best, bestScore = nil, -math.huge
	for _ = 1, 6 do
		local z = zones[math.random(1, math.max(1, #zones))]
		if z then
			local d = flat(z - me).Magnitude
			local score = -math.abs(d - 70) + math.random() * 30
			if d > 12 and score > bestScore then
				best, bestScore = z, score
			end
		end
	end
	return best
end

local function idle(u, t)
	if u.ambush and not u.provoked then
		setStance(u, "p", 1) -- lying in wait at its post (THE CULT)
	else
		setStance(u, (u.loiterCrouch and u.loiterUntil and t < u.loiterUntil) and "c" or "s", 0.7)
	end
	if u.leader then
		local L = u.leader
		if not L.alive then
			u.leader = nil
			u.route = ctx.World.boss and ctx.World.boss.route
			u.wp = 1
		else
			local off = (u.slot == 1) and Vector3.new(-5, 0, 4) or Vector3.new(5, 0, 4)
			local goal = L.root.CFrame:PointToWorldSpace(off)
			local d = flat(goal - u.root.Position).Magnitude
			if d > 4 then
				moveTo(u, goal, d > 14)
			else
				stop(u)
				lookAround(u, t)
			end
			return
		end
	end
	if u.post then
		if flat(u.post - u.root.Position).Magnitude > 3 then
			moveTo(u, u.post, false)
		else
			stop(u)
			lookAround(u, t)
		end
		return
	end
	if u.route and #u.route > 0 then
		if u.pauseUntil and t < u.pauseUntil then
			stop(u)
			lookAround(u, t)
			return
		end
		local wp = u.route[u.wp]
		if flat(wp - u.root.Position).Magnitude < 3.5 or (u.stuck or 0) >= 3 then
			u.wp = u.wp % #u.route + 1
			u.stuck = 0
			if math.random() < 0.45 then
				u.pauseUntil = t + rnd(1.5, 4.5)
			end
		else
			moveTo(u, wp, false)
		end
		return
	end
	-- scavs wander between points of interest and loiter
	if u.loiterUntil and t < u.loiterUntil then
		stop(u)
		lookAround(u, t)
		return
	end
	if not u.goal or (u.stuck or 0) >= 3 then
		u.goal = pickZone(u)
		u.stuck = 0
		u.loiterCrouch = false
	end
	if u.goal and flat(u.goal - u.root.Position).Magnitude < 4 then
		u.goal = nil
		u.loiterUntil = t + rnd(4, 16)
		u.loiterCrouch = math.random() < 0.3
		return
	end
	if u.goal then
		moveTo(u, u.goal, false)
	end
end

-- ── grenades (M11) ───────────────────────────────────────────────────────────
-- chance per check (every ~2 s) that a unit flushes a hidden target with a frag or stun charge
local NADE_CHANCE = { scav = 0.16, watch = 0.3, follower = 0.38, boss = 0.42 }
AI.nadeStats = { tries = 0, noNade = 0, range = 0, friend = 0, noPlan = 0, started = 0 }
local FRAG = { frag = true }
local STUN = { stun = true }
local SMOKE = { smoke = true }

-- a throw from this unit that ends near `target`: tries lobs and flat throws at a few strengths and keeps the
-- one whose simulated end point (bounces included) is closest; nil when nothing lands close enough
local function planThrow(u, target, fuse)
	local G = ctx.Grenades
	local look = flat(target - u.root.Position)
	if look.Magnitude < 2 then
		return nil
	end
	local eye = u.head.Position + Vector3.new(0, 0.12, 0)
	local origin = G.releaseFrom(eye, look.Unit, false)
	local best, bestErr = nil, math.huge
	for _, speed in { 34, 46, GR.THROW.over.speed } do
		for _, high in { true, false } do
			local dir = GR.aim(origin, target, speed, high)
			if dir then
				local vel = dir * speed
				local path = G.simulate(origin, vel, fuse)
				if path then
					local err = flat(path.final - target).Magnitude + math.abs(path.final.Y - target.Y) * 0.5
					if err < bestErr then
						best, bestErr = { origin = origin, vel = vel, final = path.final }, err
					end
				end
			end
		end
		if bestErr < 2 then
			break
		end
	end
	return (bestErr < 6) and best or nil
end

-- start a throw: pin now, the grenade leaves the hand a moment later (think() finishes it)
local function startThrow(u, t, g, plan, target)
	u.nadePending = { at = t + rnd(0.6, 0.85), g = g, origin = plan.origin, vel = plan.vel, target = target }
	u.model:SetAttribute("NadeItem", u.inv.items[g] and u.inv.items[g].id or "GREN_RK5")
	u.model:SetAttribute("Nade", true)
	ctx.Chars.gesture(u.model, "pin", 0.55)
	ctx.Remotes.fx("sfx", { n = "nade_pin", p = u.head.Position, v = 0.55 })
end

-- flush a target hiding at `lp`: never onto friends, never close enough to catch your own fragments
local function tryNade(u, t, lp)
	local NS = AI.nadeStats
	NS.tries += 1
	local G = ctx.Grenades
	local d = flat(lp - u.root.Position).Magnitude
	-- a frag when the target is far enough not to catch your own fragments, else a stun charge
	local g = G and G.pick(u.inv, FRAG, true)
	local spec = g and Items.defs[u.inv.items[g].id].nade
	if spec and d < math.max(10, spec.fragR * 0.55) then
		g, spec = nil, nil
	end
	if not g then
		g = G and G.pick(u.inv, STUN, true)
		spec = g and Items.defs[u.inv.items[g].id].nade
	end
	if not g then
		if G and not G.pick(u.inv, FRAG, true) then
			NS.noNade += 1
			u.nextNade = t + 40
		else
			NS.range += 1
		end
		return false
	end
	local minD = (spec.type == "frag") and math.max(10, spec.fragR * 0.55) or 8
	if d < minD or d > 55 then
		NS.range += 1
		return false
	end
	for _, o in units do
		if o ~= u and o.alive and o.root and o.faction == u.faction and (o.root.Position - lp).Magnitude < ((spec.type == "frag") and 11 or 7) then
			NS.friend += 1
			return false
		end
	end
	local spread = (1.2 + d * 0.05) * ((u.kind == "scav") and 1.6 or 1)
	local aimAt = lp + Vector3.new(rnd(-1, 1) * spread, 0, rnd(-1, 1) * spread)
	local plan = planThrow(u, aimAt, spec.fuse)
	if not plan or flat(plan.final - u.root.Position).Magnitude < minD * 0.8 then
		NS.noPlan += 1
		return false
	end
	NS.started += 1
	startThrow(u, t, g, plan, lp)
	u.nextNade = t + rnd(9, 16)
	return true
end

-- cover a retreat: smoke between you and the threat
local function throwSmoke(u, t, threat)
	local G = ctx.Grenades
	local g = G and G.pick(u.inv, SMOKE, true)
	if not g or u.nadePending or t < (u.nextSmoke or 0) then
		return false
	end
	local toward = flat(threat - u.root.Position)
	if toward.Magnitude < 4 then
		return false
	end
	local at = u.root.Position + toward.Unit * math.min(10, toward.Magnitude * 0.5)
	local plan = planThrow(u, at, 2)
	if not plan then
		return false
	end
	u.nextSmoke = t + 30
	startThrow(u, t, g, plan, at)
	return true
end

-- finish a pending throw (the pin is out, the unit stands still and faces the target)
local function nadeTick(u, t)
	local np = u.nadePending
	stop(u)
	u.wantFire = false
	face(u, np.target)
	if t < np.at then
		return
	end
	u.nadePending = nil
	u.model:SetAttribute("Nade", false)
	local it = u.inv.items[np.g]
	if it and ctx.Grenades then
		local id = it.id
		Inv.consume(u.inv, np.g)
		ctx.Chars.gesture(u.model, "toss", 0.55)
		ctx.Grenades.throwFrom(u.model, np.origin, np.vel, id)
		ctx.Remotes.fx("sfx", { n = "nade_throw", p = np.origin, v = 0.6 })
	end
end

-- a grenade landed close: get out of its radius, behind something solid if possible, then get low
local function evade(u, t)
	local e = u.evade
	if t >= e.stop then
		u.evade = nil
		return false
	end
	if t < e.start then
		return false
	end
	u.wantFire = false
	if not e.goal then
		local me = u.root.Position
		local best, bestD = nil, math.huge
		for _, c in coverNear(me, 16) do
			if flat(c.pos - e.from).Magnitude > 6 and hiddenFrom(c, e.from + Vector3.new(0, 0.8, 0)) then
				local dm = flat(c.pos - me).Magnitude
				if dm < bestD then
					best, bestD = c.pos, dm
				end
			end
		end
		if not best then
			local away = flat(me - e.from)
			away = (away.Magnitude > 0.1) and away.Unit or u.root.CFrame.RightVector
			local side = Vector3.new(-away.Z, 0, away.X)
			for _, dir in { away, (away + side).Unit, (away - side).Unit } do
				local goal = e.from + dir * (e.r + 4)
				if worldClear(me + Vector3.new(0, 1.5, 0), goal + Vector3.new(0, 1.5, 0)) then
					best = goal
					break
				end
			end
			best = best or (me + away * 12)
		end
		e.goal = best
	end
	if flat(e.goal - u.root.Position).Magnitude > 2 then
		setStance(u, "s")
		moveTo(u, e.goal, true)
	else
		stop(u)
		setStance(u, "c", 1)
	end
	return true
end

local function investigate(u, t)
	-- searching for someone who was just in a fight: a grenade at the last known position before pushing in
	local tm = u.target
	if u.state == "SEARCH" and tm and not u.nadePending and t >= (u.nextNade or 0) and alive(tm) then
		u.nextNade = t + rnd(1.2, 2)
		local lp = u.lastPos[tm]
		local hid = t - (u.seen[tm] or 0)
		if lp and hid > 1.2 and hid < 16 and math.random() < math.min(0.8, (NADE_CHANCE[u.kind] or 0.2) * 1.3) and tryNade(u, t, lp) then
			return
		end
	end
	setStance(u, "s")
	if u.goal and flat(u.goal - u.root.Position).Magnitude > 4 and (u.stuck or 0) < 3 then
		moveTo(u, u.goal, u.state == "SEARCH" and u.skill.aggression > 0.5)
	else
		stop(u)
		lookAround(u, t)
		-- sweep a couple of nearby spots
		if u.state == "SEARCH" and t >= (u.nextSweep or 0) and u.goal then
			u.nextSweep = t + rnd(4, 7)
			local a = math.random() * math.pi * 2
			u.goal = u.goal + Vector3.new(math.cos(a), 0, math.sin(a)) * rnd(6, 14)
			u.stuck = 0
		end
	end
	if t > (u.searchUntil or 0) then
		u.state = "RETURN"
		u.goal = nil
	end
end

local function shouldHeal(u, t, exposed)
	if t < (u.nextHealTry or 0) or u.healUntil then
		return false
	end
	local hs = ctx.Health.get(u.model)
	if not hs or hs.using then
		return false
	end
	local tot, max = ctx.Health.total(hs)
	local hurt = (tot / math.max(1, max) < 0.55) or next(hs.bleedH) ~= nil or next(hs.bleedL) ~= nil
	return hurt and not exposed
end

-- ── THE STOKER's sledgehammer (Tarkov's Tagilla; docs/design/BOSS_STOKER.md) ─────────────────────────────────
-- Within 15 m of a target he can see, with nothing in the way, he runs straight at it with the hammer and swings
-- within reach; shots do not stop the run, broken legs slow it (Health.mods). Otherwise he fights with his gun. The
-- hammer cannot be looted: it is a few parts in his hand, on his back while he shoots.
-- THE CULT's warriors and priest (Tarkov's cultists; docs/design/BOSS_CULT.md) charge the same way with a poisoned knife:
-- a shorter run, quicker stabs at the body, and every wound poisons (Health toxin). u.charge = true or "hammer" | "knife".
local MELEE = {
	hammer = { range = 47, speed = 18, reach = 4.6, every = 1.3, head = 0.6, dmg = 110, pen = 35, armorDmg = 0.8, bleedL = 0.3, bleedH = 0.1, weapon = "SLEDGEHAMMER", ammo = "BLUNT" },
	knife = { range = 40, speed = 17, reach = 4.0, every = 0.85, head = 0.15, dmg = 36, pen = 14, armorDmg = 0.3, bleedL = 0.5, bleedH = 0.2, weapon = "RITUAL KNIFE", ammo = "STAB", toxin = true },
}
AI.MELEE = MELEE
local function meleeOf(u)
	return MELEE[type(u.charge) == "string" and u.charge or "hammer"] or MELEE.hammer
end
local hammerTo
local function makeHammer(u)
	local knife = meleeOf(u) == MELEE.knife
	local m = Instance.new("Model")
	m.Name = knife and "RitualKnife" or "Sledgehammer"
	local function piece(size, color, mat)
		local p = Instance.new("Part")
		p.Size = size
		p.Color = color
		p.Material = mat
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
		p.Parent = m
		return p
	end
	local handle, head
	if knife then
		handle = piece(Vector3.new(0.16, 0.55, 0.16), Color3.fromRGB(40, 32, 28), Enum.Material.Wood)
		head = piece(Vector3.new(0.05, 0.95, 0.22), Color3.fromRGB(118, 122, 124), Enum.Material.Metal) -- the blade
		head.CFrame = handle.CFrame * CFrame.new(0, -0.75, 0)
	else
		handle = piece(Vector3.new(0.22, 3.1, 0.22), Color3.fromRGB(92, 70, 48), Enum.Material.Wood)
		head = piece(Vector3.new(1.05, 0.58, 0.58), Color3.fromRGB(58, 60, 62), Enum.Material.Metal)
		head.CFrame = handle.CFrame * CFrame.new(0, -1.55, 0)
	end
	handle.Name = "Handle"
	local hw = Instance.new("WeldConstraint")
	hw.Part0, hw.Part1 = handle, head
	hw.Parent = head
	local grip = Instance.new("Weld")
	grip.Name = "Grip"
	grip.Part1 = handle
	grip.Parent = handle
	m.Parent = u.model
	u.hammer = { model = m, grip = grip, knife = knife }
	hammerTo(u, false)
end
-- in hand (the head below the fist) or slung across the back
hammerTo = function(u, inHand)
	local hm = u.hammer
	if not hm or hm.inHand == inHand then
		return
	end
	local hand, torso = u.model:FindFirstChild("RightHand"), u.model:FindFirstChild("UpperTorso")
	local hips = u.model:FindFirstChild("LowerTorso")
	if hm.knife then
		-- the knife: in the fist, blade down, or in a sheath at the right hip
		if inHand and hand then
			hm.grip.Part0 = hand
			hm.grip.C0 = CFrame.new(0, -0.45, -0.15)
		elseif hips then
			hm.grip.Part0 = hips
			hm.grip.C0 = CFrame.new(0.62, 0.1, 0) * CFrame.Angles(0, 0, math.rad(8))
		end
		hm.inHand = inHand
		return
	end
	if inHand and hand then
		hm.grip.Part0 = hand
		hm.grip.C0 = CFrame.new(0, -0.9, -0.2)
	elseif torso then
		hm.grip.Part0 = torso
		hm.grip.C0 = CFrame.new(0, 0.2, 0.75) * CFrame.Angles(0, 0, math.rad(35))
	end
	hm.inHand = inHand
end
local function swing(u, tm)
	ctx.Chars.gesture(u.model, "slash", 0.6)
	ctx.Remotes.fx("sfx", { n = "knife_whoosh", p = u.root.Position, v = 1 })
	task.delay(0.3, function()
		if not (u.alive and alive(tm)) then
			return
		end
		local mp = meleeOf(u)
		local tor = tm:FindFirstChild("UpperTorso") or tm:FindFirstChild("HumanoidRootPart")
		if not tor or flat(tor.Position - u.root.Position).Magnitude > mp.reach + 1.2 then
			return -- stepped out of reach during the wind-up
		end
		-- the hammer swings at the head more often than not (Tarkov: it kills in one hit on contact); the knife stabs the body
		local part = (math.random() < mp.head and tm:FindFirstChild("Head")) or tor
		ctx.Combat.hitModel(tm, {
			dmg = mp.dmg, pen = mp.pen, armorDmg = mp.armorDmg, bleedL = mp.bleedL, bleedH = mp.bleedH, toxin = mp.toxin,
			part = part, hitPos = part.Position, attacker = u.model, from = u.head and u.head.Position or u.root.Position,
			weapon = mp.weapon, ammo = mp.ammo,
		})
		ctx.Remotes.fx("sfx", { n = "knife_hit", p = part.Position, v = 1 })
	end)
end
-- the charge for this tick; true when he is running at the target (the rest of combat is skipped)
local function chargeTick(u, t, tm, tpos, dist)
	if not u.charge then
		return false
	end
	local mp = meleeOf(u)
	local clear = u.visible and dist <= (u.charging and mp.range + 10 or mp.range)
		and worldClear(u.root.Position + Vector3.new(0, 1.5, 0), tpos + Vector3.new(0, 0.5, 0))
	if not clear then
		if u.charging then
			u.charging = false
			hammerTo(u, false)
		end
		return false
	end
	if not u.charging then
		u.charging = true
		hammerTo(u, true)
		if u.cover then
			u.cover.c.owner = nil
			u.cover = nil
		end
		ctx.Remotes.fx("sfx", { n = "breath_heavy", p = u.root.Position, v = 1.4 }) -- no yell in the atlases yet (logged)
		u.provoked = true -- an ambusher who has broken cover fights on with everything
	end
	local hs = ctx.Health.get(u.model)
	local mods = hs and ctx.Health.mods(hs)
	setStance(u, "s")
	face(u, tpos)
	u.wantFire = false
	if dist > mp.reach - 1.6 then
		u.hum.WalkSpeed = mp.speed * (mods and mods.speed or 1) * ((mods and not mods.sprint) and 0.6 or 1)
		u.moving = true
		u.hum:MoveTo(tpos)
	else
		stop(u) -- at arm's length: no running into the target (or up onto it)
	end
	if dist <= mp.reach and t >= (u.nextSwing or 0) then
		u.nextSwing = t + mp.every
		swing(u, tm)
	end
	return true
end

local function combat(u, t)
	local tm = u.target
	local w = tm and who(tm)
	if not tm or not alive(tm) or not hostile(u, w) then
		u.target = nil
		u.visible = false
		u.wantFire = false
		u.state = "SEARCH"
		u.searchUntil = t + 6
		if u.cover then
			u.cover.c.owner = nil
			u.cover = nil
		end
		return
	end
	local sk = u.skill
	-- flashed: crouch where you are and spray at the last place you saw them now and then
	if t < (u.blindUntil or 0) then
		u.visible = false
		setStance(u, "c", 1)
		stop(u)
		u.wantFire = sk.suppress and math.random() < 0.35 and u.lastPos[tm] ~= nil
		u.suppressPos = u.wantFire and (u.lastPos[tm] + Vector3.new(rnd(-3, 3), rnd(0, 2), rnd(-3, 3))) or nil
		return
	end
	u.visible = u.seen[tm] ~= nil and (t - u.seen[tm]) < 0.3
	local tor = tm:FindFirstChild("UpperTorso") or tm:FindFirstChild("HumanoidRootPart")
	local tpos = (u.visible and tor and tor.Position) or u.lastPos[tm] or (tor and tor.Position)
	if not tpos then
		return
	end
	local thead = tm:FindFirstChild("Head")
	local threatEye = (u.visible and thead and thead.Position) or (tpos + Vector3.new(0, 1.3, 0))
	local dist = flat(tpos - u.root.Position).Magnitude
	if chargeTick(u, t, tm, tpos, dist) then
		return
	end
	-- an ambusher (THE CULT: Tarkov's warriors lie prone in the dark) keeps still until the target comes within the
	-- knife's run and in sight, or until it is hurt; after that it fights on with its gun as well
	if u.ambush and not u.provoked then
		setStance(u, "p", 1)
		stop(u)
		face(u, tpos)
		u.wantFire = false
		return
	end
	-- out of ammo: reload, switch to the sidearm, or break off
	if roundsOf(u) <= 0 and not u.reloadUntil then
		if not startReload(u, t) and not rearm(u) then
			throwSmoke(u, t, tpos)
			u.state = "FLEE"
			u.goal = nil
			u.fleeUntil = t + 25
			u.wantFire = false
			return
		end
	elseif not u.visible and not u.reloadUntil and roundsOf(u) < capacityOf(u) * 0.4 then
		startReload(u, t) -- top up while there is no target in view
	end
	-- heal when hurt and not exposed
	local exposed = u.visible and not (u.cover and not u.peeking)
	if u.healUntil and t >= u.healUntil then
		u.healUntil = nil
	end
	if shouldHeal(u, t, exposed) then
		u.nextHealTry = t + 8
		local dur = ctx.Health.aiUse(u.model, u.inv)
		if dur then
			u.healUntil = t + dur
		end
	end
	local busy = u.reloadUntil ~= nil or u.healUntil ~= nil
	-- cover
	if u.useCover then
		if u.cover and t >= (u.coverCheck or 0) then
			u.coverCheck = t + 1
			if not hiddenFrom(u.cover.c, threatEye) then
				u.cover.c.owner = nil
				u.cover = nil
			end
		end
		if not u.cover and t >= (u.nextCoverSearch or 0) then
			u.nextCoverSearch = t + 2.5
			u.cover = findCover(u, tpos, threatEye)
			u.peeking = false
		end
	end
	u.suppressPos = nil
	if u.cover then
		local cpos = u.cover.pos
		local atCover = flat(cpos - u.root.Position).Magnitude <= 2.2
		local atPeek = u.cover.peek and flat(u.cover.peek - u.root.Position).Magnitude <= 1.6
		if not atCover and not (u.peeking and atPeek) then
			setStance(u, "s")
			moveTo(u, (u.peeking and u.cover.peek) or cpos, not u.peeking)
			u.wantFire = u.visible and dist < 35 and not busy
		else
			if not u.peekUntil or t >= u.peekUntil then
				u.peeking = (not u.peeking) and not busy and u.cover.peek ~= nil
				u.peekUntil = t + (u.peeking and rnd(1.2, 2.8) or rnd(0.7, 1.6))
			end
			if busy then
				u.peeking = false
			end
			if u.peeking then
				setStance(u, "s")
				if u.cover.peek and flat(u.cover.peek - u.root.Position).Magnitude > 1.2 then
					moveTo(u, u.cover.peek, false, true)
				else
					stop(u)
				end
			else
				setStance(u, "c", 1)
				if not atCover then
					moveTo(u, cpos, false, true)
				else
					stop(u)
				end
			end
			face(u, tpos)
			u.wantFire = u.peeking and not busy and (u.visible or (sk.suppress and t - (u.seen[tm] or 0) < 1.2))
		end
	else
		-- in the open: crouch at range, strafe at mid range, hold still to heal or reload
		face(u, tpos)
		if busy then
			setStance(u, "c", 1)
			stop(u)
		elseif dist > 45 then
			setStance(u, "c", 0.8)
			stop(u)
		else
			setStance(u, "s")
			if t >= (u.nextStrafe or 0) and sk.aggression > 0.3 then
				u.nextStrafe = t + rnd(1.4, 3)
				local side = u.root.CFrame.RightVector * (math.random() < 0.5 and -1 or 1) * rnd(3, 6)
				local goal = u.root.Position + side
				if worldClear(u.root.Position + Vector3.new(0, 1, 0), goal + Vector3.new(0, 1, 0)) then
					u.strafeGoal = goal
				end
			end
			if u.strafeGoal and flat(u.strafeGoal - u.root.Position).Magnitude > 1 then
				u.hum.WalkSpeed = WALK
				u.moving = true
				u.hum:MoveTo(u.strafeGoal)
			else
				stop(u)
			end
		end
		u.wantFire = not busy and (u.visible or (sk.suppress and t - (u.seen[tm] or 0) < 1.2))
	end
	if u.wantFire and not u.visible then
		u.suppressPos = tpos + Vector3.new(rnd(-1.5, 1.5), rnd(0, 1.5), rnd(-1.5, 1.5))
	end
	-- grenades: flush a target that stays hidden behind cover (Tarkov AI)
	if not u.visible and not busy and not u.nadePending and t >= (u.nextNade or 0) then
		u.nextNade = t + rnd(0.8, 1.4)
		local hid = t - (u.seen[tm] or 0)
		local lp = u.lastPos[tm]
		if lp and hid > 0.8 and hid < 14 and math.random() < (NADE_CHANCE[u.kind] or 0.2) then
			tryNade(u, t, lp)
		end
	end
	-- lost contact: push the last known position (aggressive) or hold a little longer
	local lost = t - (u.seen[tm] or 0)
	if lost > (sk.aggression > 0.5 and 3.5 or 7) then
		u.state = "SEARCH"
		u.goal = u.lastPos[tm] or tpos
		u.searchUntil = t + 18
		u.wantFire = false
		if u.cover then
			u.cover.c.owner = nil
			u.cover = nil
		end
	end
end

local function flee(u, t)
	setStance(u, "s")
	u.wantFire = false
	if not u.goal or flat(u.goal - u.root.Position).Magnitude < 4 then
		local away = u.target and u.lastPos[u.target]
		local best, bestD = nil, -1
		for _ = 1, 6 do
			local z = pickZone(u)
			if z then
				local d = away and flat(z - away).Magnitude or math.random(1, 100)
				if d > bestD then
					best, bestD = z, d
				end
			end
		end
		u.goal = best
	end
	if u.goal then
		moveTo(u, u.goal, true)
	end
	if t > (u.fleeUntil or 0) then
		u.state = "RETURN"
		u.goal = nil
	end
end

-- third-person pose: weapon up when fighting or alert, pitch at the target, stance, sprint
local function updatePose(u)
	local m = u.model
	local aim = (u.state == "ENGAGE" and (u.wantFire or u.peeking or u.visible)) or (u.state == "INVESTIGATE" or u.state == "SEARCH")
	local pitch = 0
	if u.state == "ENGAGE" and u.target and u.head then
		local th = u.target:FindFirstChild("Head")
		local p = (u.visible and th and th.Position) or u.suppressPos or u.lastPos[u.target]
		if p then
			local d = p - u.head.Position
			pitch = math.floor(math.deg(math.atan2(d.Y, Vector3.new(d.X, 0, d.Z).Magnitude)))
		end
	end
	local sprint = u.sprint == true and u.root.AssemblyLinearVelocity.Magnitude > 8
	local stance = u.stance or "s"
	local depth = math.floor((u.depth or 0.8) * 20 + 0.5) / 20
	aim = aim and not sprint
	if m:GetAttribute("Aim") ~= aim or m:GetAttribute("Sprint") ~= sprint or math.abs((m:GetAttribute("Pitch") or 0) - pitch) >= 4
		or m:GetAttribute("Stance") ~= stance or m:GetAttribute("Depth") ~= depth then
		m:SetAttribute("Aim", aim)
		m:SetAttribute("Sprint", sprint)
		m:SetAttribute("Pitch", pitch)
		m:SetAttribute("Stance", stance)
		m:SetAttribute("Depth", depth)
		m:SetAttribute("Crouch", stance == "c")
		ctx.Chars.pose(m)
	end
	m:SetAttribute("State", u.state)
end

local function perceive(u, t, dt)
	local eye = u.head.Position
	local look = u.root.CFrame.LookVector
	local sk = u.skill
	local alert = (t < (u.alert or 0)) or (u.state ~= "PATROL" and u.state ~= "WANDER" and u.state ~= "RETURN")
	local best, bestScore = nil, -math.huge
	for _, model in candidates(u) do
		local tor = model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
		if tor then
			local d = tor.Position - eye
			local dist = d.Magnitude
			local a = u.aware[model] or 0
			-- darkness and fog shorten sight; a lit weapon light gives you away from much further in the dark
			local range = sk.sight * envView.sight
			if model:GetAttribute("WeaponLight") then
				range = math.max(range, sk.sight * ((envView.dark > 0.5) and 1.4 or 1.05))
			end
			local vis = nil
			if dist < range and t >= (u.blindUntil or 0) then
				local inFov = dist < CLOSE or look:Dot(d.Unit) >= FOV_COS or (a >= 1 and dist < 45) or (u.ambush and dist < AMBUSH_SENSE)
				if inFov then
					vis = visiblePart(u, model, eye)
				end
			end
			if vis then
				local rate = sk.notice * exposure(model) * math.clamp(1.35 - dist / range, 0.15, 1.35)
				if alert then
					rate *= 2
				end
				if dist < CLOSE then
					rate *= 3
				end
				if u.ambush and dist < AMBUSH_SENSE then
					rate = math.max(rate, 1.6)
				end
				a = math.min(1.6, a + rate * dt)
				u.seen[model] = t
				if a >= 1 then
					u.lastPos[model] = tor.Position
				end
			else
				a = math.max(0, a - 0.3 * dt)
			end
			-- footsteps
			local nz = noiseOf(model)
			if nz > 0 and t >= (u.deafUntil or 0) and dist < 60 * nz * sk.hearing * envView.hear then
				u.heard = { pos = tor.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)), t = t }
				a = math.max(a, 0.4)
			end
			u.aware[model] = a
			if a >= 1 and vis then
				local score = -dist + ((model == u.target) and 25 or 0) + ((model == u.hurtBy) and 40 or 0)
				if score > bestScore then
					best, bestScore = model, score
				end
			end
		end
	end
	for model in u.aware do
		if not alive(model) then
			u.aware[model] = nil
			u.lastPos[model] = nil
			u.seen[model] = nil
		end
	end
	return best
end

local function think(u)
	local t = now()
	local dt = math.clamp(t - (u.lastThink or t), 0.05, 0.6)
	u.lastThink = t
	if not u.alive or not u.root or not u.root.Parent then
		return
	end
	-- perception: 5 Hz while alert or fighting, 2.5 Hz while calm
	u.tick = (u.tick or 0) + 1
	local calm = (u.state == "PATROL" or u.state == "WANDER" or u.state == "RETURN") and t >= (u.alert or 0)
	local seen = nil
	if not calm or u.tick % 2 == 0 then
		seen = perceive(u, t, calm and dt * 2 or dt)
	end
	if seen and u.state ~= "FLEE" then
		if u.state ~= "ENGAGE" then
			u.state = "ENGAGE"
			u.reactUntil = t + rndr(u.skill.react)
			u.spottedAt = t
			u.peeking = false
			u.burstN = 0
			u.burstLen = math.random(2, 3)
			u.aimPart = "UpperTorso"
			callout(u, seen)
		end
		u.target = seen
	end
	if u.heard and u.state ~= "ENGAGE" and u.state ~= "FLEE" and t - u.heard.t < 0.6 then
		u.state = "INVESTIGATE"
		u.goal = u.heard.pos
		u.searchUntil = t + 14
		u.alert = t + 20
		u.heard = nil
	end
	reloadTick(u, t)
	-- grenades: finish a throw in progress, or get away from one that landed close
	if u.nadePending then
		nadeTick(u, t)
		updatePose(u)
		return
	end
	if u.evade and evade(u, t) then
		updatePose(u)
		return
	end
	-- a guard posted at a stationary gun mans it while engaging a raider the gun can reach (Stationary.crew)
	if ctx.Stationary then
		local onGun, look = ctx.Stationary.crew(u, t)
		if onGun then
			u.wantFire = false
			u.visible = true
			stop(u)
			if look then
				face(u, look)
			end
			updatePose(u)
			return
		end
	end
	if u.state == "ENGAGE" then
		combat(u, t)
	elseif u.state == "INVESTIGATE" or u.state == "SEARCH" then
		u.wantFire = false
		investigate(u, t)
	elseif u.state == "FLEE" then
		flee(u, t)
	else
		u.wantFire = false
		if u.state == "RETURN" then
			u.goal = nil
			u.state = (u.route or u.post or u.leader) and "PATROL" or "WANDER"
		end
		idle(u, t)
		-- calm: top up the magazine
		if not u.reloadUntil and u.w and roundsOf(u) < capacityOf(u) * 0.5 and canReload(u) then
			startReload(u, t)
		end
	end
	-- at night, units with a weapon light use it while hunting someone (guards also on patrol); a visible laser runs
	-- with the light and in any fight, day or night (Tarkov's bots light their lasers when they engage)
	if envView.dark > 0.55 then
		local hunting = u.state == "INVESTIGATE" or u.state == "SEARCH" or u.state == "ENGAGE"
		setLight(u, hunting or (u.kind ~= "scav" and (u.state == "PATROL" or u.state == "RETURN")))
	elseif u.lightOn then
		setLight(u, false)
	end
	local w = u.w
	if w and w.hasLaser == nil then
		w.hasLaser = u.inv.items[w.g] ~= nil and Inv.modStats(u.inv, w.g).laser == true
	end
	local wantLaser = w ~= nil and w.hasLaser == true and (u.lightOn == true or u.state == "ENGAGE")
	if (u.laserOn == true) ~= wantLaser then
		u.laserOn = wantLaser
		u.model:SetAttribute("WeaponLaser", wantLaser)
	end
	updatePose(u)
end

-- ── spawning ─────────────────────────────────────────────────────────────────
local LOADOUT = {
	scav = function(r)
		return ctx.Loot.scavLoadout(r)
	end,
	watch = function(r)
		return ctx.Loot.guardLoadout(r)
	end,
	boss = function(r)
		return ctx.Loot.bossLoadout(r)
	end,
	follower = function(r)
		return ctx.Loot.crewLoadout(r)
	end,
}

-- the kit an AI kind spawns with (seeded: showroom / tests reproduce a preset exactly)
function AI.loadoutFor(kind, rand)
	local f = LOADOUT[kind]
	return f and f(rand or Random.new()) or nil
end
AI.LOOK = LOOK

local function liveCount(kind)
	local n = 0
	for _, u in units do
		if u.alive and (not kind or u.kind == kind) then
			n += 1
		end
	end
	return n
end
AI.liveCount = liveCount

function AI.spawn(kind, pos, opts)
	opts = opts or {}
	local skillOf = SKILL[opts.skill or kind] or SKILL[kind] -- a crew may fight with the boss's skill (THE HOUNDS)
	if liveCount() >= Config.AI_MAX then
		return nil
	end
	local myGen = gen
	local look = opts.look or LOOK[kind] -- a map's boss may bring its own look and loadout (M13)
	local variant = math.random(1, Equipment.variants(look))
	local ok, model = pcall(ctx.Chars.buildRig, look, variant)
	if not ok or not model or myGen ~= gen then
		if not ok then
			warn("[ZR] AI spawn failed", model)
		end
		return nil
	end
	seq += 1
	model.Name = (opts.name or LABEL[kind]) .. "_" .. seq
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	ctx.Chars.setupHumanoid(hum)
	hum.WalkSpeed = WALK
	model:PivotTo(CFrame.new(pos + Vector3.new(0, 3.3, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	local custom = opts.loadout and ctx.Loot[opts.loadout]
	local inv = custom and custom(Random.new()) or LOADOUT[kind](Random.new())
	local gear = ctx.Chars.gearOf(inv)
	ctx.Appearance.apply(model, { look = look, variant = variant, holder = inv, active = gear and gear.activeG })
	model:SetAttribute("ZR_AI", true)
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Faction", FACTION[kind])
	model:SetAttribute("Label", opts.label or LABEL[kind])
	model:SetAttribute("Stance", "s")
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	root.CanQuery = false
	-- turning by a physics constraint (setting the root CFrame can push a body into walls)
	local att = root:FindFirstChild("ZR_TurnAtt") or Instance.new("Attachment")
	att.Name = "ZR_TurnAtt"
	att.Parent = root
	local turn = Instance.new("AlignOrientation")
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = att
	turn.Responsiveness = 30
	turn.MaxTorque = 1e7
	turn.RigidityEnabled = false
	turn.Enabled = false
	turn.Parent = root
	local u = {
		id = seq, kind = kind, faction = FACTION[kind], label = opts.label or LABEL[kind], name = model.Name, skill = skillOf,
		model = model, hum = hum, root = root, head = model:FindFirstChild("Head"), inv = inv, alive = true, gen = myGen,
		state = (opts.route or opts.post or opts.leader) and "PATROL" or "WANDER", route = opts.route, wp = opts.wp or 1,
		post = opts.post, leader = opts.leader, slot = opts.slot,
		aware = {}, lastPos = {}, seen = {}, nextShot = 0, burstN = 0, burstLen = 3, stance = "s", depth = 0.8,
		useCover = math.random() < skillOf.cover, turn = turn, charge = opts.charge, ambush = opts.ambush,
		karmaHunt = opts.karmaHunt, grudge = {},
	}
	if opts.silent then
		model:SetAttribute("SilentSteps", true) -- every client plays no footsteps for him (Effects.footstep), only rustling grass
	end
	u.w = weaponIn(u, "primary") or weaponIn(u, "secondary") or weaponIn(u, "holster")
	table.insert(units, u)
	-- a boss may bring its own health (THE STOKER: Tarkov's Tagilla has 1,220 to a PMC's 440)
	ctx.Health.attach(model, { kind = "ai", scale = opts.hp or skillOf.hp, holder = function()
		return u.inv
	end })
	if u.charge then
		makeHammer(u)
	end
	hum.Died:Connect(function()
		ctx.Chars.ragdoll(model)
		AI.onKilled(model, nil)
	end)
	task.spawn(function()
		task.wait(math.random() * 0.2)
		while u.alive and model.Parent and myGen == gen do
			local okk, err = pcall(think, u)
			if not okk then
				warn("[ZR] AI think", err)
			end
			task.wait(0.2)
		end
	end)
	return u
end

-- a spot away from every raider (distance and line of sight), from a list of points
local function safeSpot(list, minDist)
	local raiders = {}
	for player, s in ctx.Raid.sessions() do
		local head = not s.done and player.Character and player.Character:FindFirstChild("Head")
		if head then
			table.insert(raiders, head.Position)
		end
	end
	local order = table.clone(list)
	for i = #order, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local fallback, fallbackD = nil, -1
	for _, p in order do
		local ok, nearest = true, math.huge
		-- never right on top of a PMC insertion point (raiders may not have spawned yet)
		for _, sp in ctx.World.spawns or {} do
			if (p - sp.cf.Position).Magnitude < 45 then
				ok = false
			end
		end
		for _, h in raiders do
			local d = (p - h).Magnitude
			nearest = math.min(nearest, d)
			if d < minDist or (d < 170 and worldClear(h, p + Vector3.new(0, 4, 0))) then
				ok = false
			end
		end
		if ok then
			return p
		end
		if nearest > fallbackD then
			fallback, fallbackD = p, nearest
		end
	end
	return fallbackD >= minDist * 0.6 and fallback or nil
end
AI.safeSpot = safeSpot

local function spawnScav()
	local p = safeSpot(ctx.World.scavZones or {}, 70)
	if p then
		return AI.spawn("scav", p + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
	end
	return nil
end
AI.spawnScav = spawnScav

local function desiredScavs()
	local n = (ctx.Match and ctx.Match.liveSessions) and ctx.Match.liveSessions() or 0
	return math.clamp(Config.SCAV_START + math.floor(n * Config.SCAV_PER_PLAYER), Config.SCAV_START, Config.SCAV_CAP)
end

local function directorTick()
	if not ctx.Raid.world or ctx.Raid.world.status ~= "RUNNING" then
		return
	end
	local t = now()
	local left = (ctx.Match and ctx.Match.endsAt or 0) - workspace:GetServerTimeNow()
	-- early in the raid: top the scav count up as raiders join
	if t < director.topUpUntil and t >= director.nextTopUp and liveCount("scav") < desiredScavs() then
		director.nextTopUp = t + 4
		spawnScav()
	end
	-- waves through the raid
	if t >= director.nextWave then
		director.nextWave = t + rnd(Config.SCAV_WAVE_EVERY * 0.8, Config.SCAV_WAVE_EVERY * 1.2)
		if left > 300 then
			director.waves += 1
			for _ = 1, math.random(2, 3) do
				if liveCount("scav") < Config.SCAV_CAP then
					spawnScav()
				end
			end
		end
	end
end

-- ── events from the rest of the game ─────────────────────────────────────────
-- a gunshot at pos: AI in earshot investigate (shooter: Player, Model or nil)
function AI.hearShot(pos, shooter, except, loudness)
	local radius = 200 * (loudness or 1) * math.sqrt(envView.hear) -- heavy rain dulls distant shots a little
	local t = now()
	local smodel = (typeof(shooter) == "Instance" and shooter:IsA("Player")) and shooter.Character or shooter
	for _, u in units do
		if u ~= except and u.alive and u.root then
			local d = (u.root.Position - pos).Magnitude
			local deaf = (t < (u.deafUntil or 0)) and 0.2 or 1
			if d < radius * u.skill.hearing * deaf then
				u.alert = t + 25
				if u.state ~= "ENGAGE" and u.state ~= "FLEE" and d < radius * 0.55 * u.skill.hearing then
					u.state = "INVESTIGATE"
					u.goal = pos + Vector3.new(rnd(-1, 1), 0, rnd(-1, 1)) * (4 + d * 0.06)
					u.searchUntil = t + 16
				end
				if typeof(smodel) == "Instance" and smodel:IsA("Model") and smodel ~= u.model then
					local w = who(smodel)
					if w and hostile(u, w) then
						u.aware[smodel] = math.max(u.aware[smodel] or 0, d < 60 and 0.6 or 0.35)
						u.lastPos[smodel] = pos
					end
				end
			end
		end
	end
end

-- a bullet flew from a to b: AI near its path are suppressed and know roughly where it came from
function AI.bulletPassed(a, b, shooterModel)
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then
		return
	end
	local seg = b - a
	local len = seg.Magnitude
	if len < 1 then
		return
	end
	local dir = seg / len
	local t = now()
	for _, u in units do
		if u.alive and u.head and u.model ~= shooterModel then
			local k = math.clamp((u.head.Position - a):Dot(dir), 0, len)
			if (a + dir * k - u.head.Position).Magnitude < 4 then
				u.suppressedUntil = t + 1.5
				u.alert = t + 25
				if typeof(shooterModel) == "Instance" and shooterModel:IsA("Model") then
					local w = who(shooterModel)
					if w and hostile(u, w) then
						u.aware[shooterModel] = math.max(u.aware[shooterModel] or 0, 0.85)
						u.lastPos[shooterModel] = a
						if u.state ~= "ENGAGE" and u.state ~= "FLEE" then
							u.state = "SEARCH"
							u.goal = a
							u.searchUntil = t + 15
						end
					end
				end
			end
		end
	end
end

-- Studio test bridge: make a unit throw its first grenade at `target` now (returns false if it cannot)
function AI.devThrow(u, target)
	local g = ctx.Grenades and ctx.Grenades.pick(u.inv, nil, true)
	if not g or u.nadePending then
		return false
	end
	local spec = Items.defs[u.inv.items[g].id].nade
	local plan = planThrow(u, target, spec.fuse)
	if not plan then
		return false
	end
	startThrow(u, now(), g, plan, target)
	return true
end

-- a grenade is on its way (Grenades.throwFrom): units near where it ends up notice it land and run
function AI.grenadeIncoming(info)
	if not info.radius or info.radius <= 0 then
		return
	end
	local t = now()
	for _, u in units do
		if u.alive and u.root then
			local d = flat(u.root.Position - info.pos).Magnitude
			if d < info.radius + 3 and math.abs(u.root.Position.Y - info.pos.Y) < 10 then
				local own = u.model == info.thrower
				if own or d < 7 or math.random() < 0.75 then
					local react = own and 0 or rnd(0.25, 0.7)
					u.evade = { from = info.pos, start = math.max(t, info.land or t) + react, stop = (info.boom or t + 3) + 0.35, r = info.radius }
					u.alert = math.max(u.alert or 0, t + 20)
				end
			end
		end
	end
end

-- a stun charge went off at pos: blind those facing it with line of sight, deafen everyone close
function AI.flashed(pos, spec)
	local t = now()
	for _, u in units do
		if u.alive and u.head and u.root then
			local to = pos - u.head.Position
			local d = to.Magnitude
			if d < math.max(spec.blindR, spec.deafR) then
				local los = worldClear(u.head.Position, pos)
				local fl = flat(to)
				local facing = (fl.Magnitude > 0.1) and u.root.CFrame.LookVector:Dot(fl.Unit) or 1
				local b = GR.blind(spec, d, facing, los)
				local f = GR.deaf(spec, d, los)
				if b > 0.05 then
					u.blindUntil = math.max(u.blindUntil or 0, t + 1 + 6 * b)
					u.suppressedUntil = math.max(u.suppressedUntil or 0, t + 2 + 4 * b)
				end
				if f > 0.05 then
					u.deafUntil = math.max(u.deafUntil or 0, t + 1.5 + 6 * f)
				end
				u.alert = math.max(u.alert or 0, t + 25)
			end
		end
	end
end

function AI.onDamaged(model, attacker)
	local u = byModel(model)
	if not u or not u.alive then
		return
	end
	local t = now()
	u.suppressedUntil = t + 1.2
	u.alert = t + 30
	u.provoked = true -- an ambusher that is hit gives up hiding
	local amodel = nil
	if typeof(attacker) == "Instance" then
		if attacker:IsA("Player") then
			amodel = attacker.Character
		elseif attacker:IsA("Model") then
			amodel = attacker
		end
	end
	if not amodel or amodel == model then
		return
	end
	local w = who(amodel)
	-- a player scav who shoots a scav (or the Foreman's people) turns every scav against them for the raid
	if w and w.s and w.s.scav and u.faction == "scav" then
		w.s.hostile = true
	end
	if w and w.unit and w.unit.faction == u.faction then
		return
	end
	if u.karmaHunt and w and w.player then
		u.grudge[w.player] = true -- whoever shoots THE FORESTER is his enemy for the raid
	end
	u.aware[amodel] = math.max(u.aware[amodel] or 0, 0.95)
	u.lastPos[amodel] = amodel:GetPivot().Position
	u.hurtBy = amodel
	if u.state ~= "ENGAGE" then
		u.state = "SEARCH"
		u.goal = u.lastPos[amodel]
		u.searchUntil = t + 15
		face(u, u.lastPos[amodel])
	end
	callout(u, amodel)
end

function AI.onKilled(model, _attacker)
	local u = byModel(model)
	if not u or not u.alive then
		return
	end
	u.alive = false
	u.state = "DEAD"
	u.wantFire = false
	if u.cover then
		u.cover.c.owner = nil
		u.cover = nil
	end
	model:SetAttribute("State", "DEAD")
	if u.turn then
		u.turn:Destroy()
		u.turn = nil
	end
	ctx.Loot.spawnBody(model, u.inv, u.label)
	-- the body stays until the raid ends (frozen once the ragdoll settles)
	ctx.Chars.freezeLater(model, 8)
end

function AI.clear()
	gen += 1
	for _, u in units do
		u.alive = false
		if u.model and u.model.Parent then
			u.model:Destroy()
		end
	end
	table.clear(units)
	for _, list in cover.cells do
		for _, c in list do
			c.owner = nil
		end
	end
	director.nextWave = math.huge
	director.topUpUntil = 0
end

-- raid start: the Watch at their posts, the Foreman's crew (some raids), the first scavs
function AI.reset()
	AI.clear()
	if ctx.Tripwires then
		pcall(ctx.Tripwires.clear) -- last raid's wires go with the last raid's bosses
	end
	local myGen = gen
	local t = now()
	director.waves = 0
	director.nextWave = t + rnd(Config.SCAV_WAVE_EVERY * 0.8, Config.SCAV_WAVE_EVERY * 1.2)
	director.topUpUntil = t + Config.LATE_JOIN + 30
	director.nextTopUp = t + 6
	task.spawn(function()
		local W = ctx.World
		-- every boss of the map rolls on its own (Interchange: THE CARETAKER 60 %, THE STOKER 35 %); a map with one boss
		-- gives it as W.boss. A boss may carry its own chance and a list of zones to pick from. AI.forceBoss forces them
		-- all, AI.forceBossId[label] one of them (Dev "boss").
		local bosses = W.bosses or (W.boss and { W.boss }) or {}
		local rolled = {}
		-- a night boss (THE CULT) rolls only in a raid that starts in the dark (Tarkov: cultists come out at night)
		local env = ctx.Match and ctx.Match.env
		local dark = env ~= nil and Env.daylight(env.clock0 or 12) < 0.35
		for _, b in bosses do
			local forced = AI.forceBoss
			if AI.forceBossId and AI.forceBossId[b.label] ~= nil then
				forced = AI.forceBossId[b.label]
			end
			if forced ~= nil then
				rolled[b] = forced
			elseif b.night and not dark then
				rolled[b] = false
			elseif b.karmaHunt then
				-- THE FORESTER comes more often when raiders with low karma are queued for this raid (Match.raidKarma)
				rolled[b] = math.random() < AI.forestChance(b.chance or Config.BOSS_CHANCE, ctx.Match and ctx.Match.raidKarma)
			else
				rolled[b] = math.random() < (b.chance or Config.BOSS_CHANCE)
			end
		end
		local bossRaid = false
		for _, on in rolled do
			bossRaid = bossRaid or on
		end
		AI.bossThisRaid = bossRaid
		AI.bossZone = nil
		AI.bossesThisRaid = {}
		for _, wp in W.watchPosts or {} do
			if myGen ~= gen then
				return
			end
			local route = W.patrols[wp.route]
			if route then
				local idx = math.random(1, #route)
				AI.spawn("watch", wp.post or route[idx], { route = (not wp.post) and route or nil, wp = idx, post = wp.post, label = wp.label, name = wp.label })
			end
		end
		for _, b in bosses do
			if rolled[b] then
				local zones = b.zones
				local zone = (zones and #zones > 0) and zones[math.random(1, #zones)] or nil
				AI.bossZone = AI.bossZone or (zone and zone.name) or nil
				table.insert(AI.bossesThisRaid, b.label or "Foreman")
				-- a roaming boss (THE FORESTER) starts at any point of his loop
				local home, wp = zone and zone.home or b.home, 1
				if b.roam and b.route and #b.route > 0 then
					wp = math.random(1, #b.route)
					home = b.route[wp]
				end
				local boss = AI.spawn("boss", home, {
					route = zone and zone.route or b.route, wp = wp, label = b.label or "Foreman", name = b.label, look = b.look,
					loadout = b.loadout, hp = b.hp, charge = b.charge, skill = b.skill, ambush = b.ambush,
					post = (zone and zone.post) or b.post, karmaHunt = b.karmaHunt, silent = b.silent,
				})
				-- his tripwires go into doorways near his loop (Tripwires.layAlong)
				if boss and b.traps and b.route and ctx.Tripwires then
					local okT, errT = pcall(ctx.Tripwires.layAlong, b.route, b.traps, boss.model)
					if not okT then
						warn("[ZR] tripwires", errT)
					end
				end
				for i, p in (zone and zone.crew) or b.crew or {} do
					if myGen ~= gen then
						return
					end
					-- a crew member is a spot, or { pos, look, loadout, hp, label, skill } (THE HOUNDS: each his own man); with
					-- `post` it keeps its own spot instead of following (THE CULT's warriors lying in wait round their priest)
					if typeof(p) == "Vector3" then
						AI.spawn("follower", p, { leader = boss, slot = i })
					elseif type(p) == "table" and typeof(p.pos) == "Vector3" and (not p.chance or math.random() < p.chance) then
						AI.spawn("follower", p.pos, {
							leader = (not p.post) and boss or nil, slot = i, look = p.look, loadout = p.loadout, hp = p.hp, label = p.label,
							name = p.label, skill = p.skill, charge = p.charge, ambush = p.ambush, post = p.post and p.pos or nil,
						})
					end
				end
			end
		end
		if not bossRaid and W.patrols.FD then
			AI.spawn("watch", W.patrols.FD[1], { route = W.patrols.FD, wp = 1 })
		end
		for _ = 1, Config.SCAV_START do
			if myGen ~= gen then
				return
			end
			spawnScav()
		end
	end)
end

function AI.init(c)
	ctx = c
	folder = Instance.new("Folder")
	folder.Name = "ZR_AI"
	folder.Parent = workspace
	task.spawn(buildCover)
	-- firing runs every frame (real fire rates); thinking runs at 5 Hz per unit
	RunService.Heartbeat:Connect(function()
		local t = now()
		for _, u in units do
			if u.alive and u.wantFire and u.target and t >= u.nextShot and t >= (u.reactUntil or 0) and not u.reloadUntil and not u.healUntil then
				local ok, err = pcall(shoot, u, t)
				if not ok then
					u.wantFire = false
					warn("[ZR] AI shoot", err)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(refreshEnv)
			local ok, err = pcall(directorTick)
			if not ok then
				warn("[ZR] AI director", err)
			end
		end
	end)
end

return AI
