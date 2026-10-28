--!nonstrict
-- AI 2.0 (Tarkov-style). Factions: AI scavs (leave player scavs alone unless provoked), the Harbor Watch
-- (raider-type guards, hostile to everyone else) and the Foreman with his crew (scav-aligned boss group).
-- Perception: vision builds awareness over time (distance, stance, movement, weapon light), hearing of
-- footsteps and gunshots, suppression from near misses, call-outs to nearby allies.
-- Tactics: cover points generated from the map, peek-and-hide, reload and heal in cover, strafe in the open,
-- search the last known position, followers stay with the boss and flank.
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
local KARMA_HOSTILE = require(Shared.Progress).KARMA.hostileBelow

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
local LOOK = { scav = "scav", watch = "guard", follower = "boss", boss = "boss" }
local FOV_COS = math.cos(math.rad(62))
local CLOSE = 9
local WALK, RUN, CROUCH = 8, 15, 5

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local worldParams = RaycastParams.new()
worldParams.FilterType = Enum.RaycastFilterType.Include

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

local function hostile(u, w)
	if not w then
		return false
	end
	if w.player and DEV and w.player:GetAttribute("DevIgnore") then
		return false
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
	local map = workspace:WaitForChild("ZR_World", 30)
	map = map and map:FindFirstChild("Quay7")
	if not map then
		warn("[ZR] AI: no map for cover")
		return
	end
	worldParams.FilterDescendantsInstances = { map }
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = { map }
	local count = 0
	for x = -192, 192, 3 do
		for z = -192, 192, 3 do
			-- every walkable level at this spot (yard, building floors under roofs, the mezzanine)
			local floors = {}
			local y = 60
			for _ = 1, 5 do
				local hit = workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, -(y + 10), 0), worldParams)
				if not hit then
					break
				end
				if hit.Position.Y < 16 and hit.Normal.Y > 0.8 then
					table.insert(floors, hit.Position)
				end
				y = hit.Position.Y - 1.6
				if y < -2 then
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
			if count % 150 == 0 then
				task.wait()
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
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local v = root and flat(root.AssemblyLinearVelocity).Magnitude or 0
	f *= (v > 2) and 1.25 or 0.85
	if model:GetAttribute("WeaponLight") then
		f *= 1.8
	end
	return f
end

-- footstep loudness 0..1 (server view of what the client plays): sprint > walk > crouch > prone
local function noiseOf(model)
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

local function visiblePart(u, model, eye)
	params.FilterDescendantsInstances = ignoreFor(u)
	for _, name in { "Head", "UpperTorso", "LowerTorso" } do
		local p = model:FindFirstChild(name)
		if p then
			local r = workspace:Raycast(eye, p.Position - eye, params)
			if r == nil or r.Instance:IsDescendantOf(model) then
				return p
			end
		end
	end
	return nil
end

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
	return PathfindingService:CreatePath({ AgentRadius = 1.6, AgentHeight = 5.6, AgentCanJump = false, WaypointSpacing = 5 })
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
	return w.wd.capacity or 5
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
	return (it.a or 0) < (w.wd.capacity or 0) and ammoStack(u, w.wd.caliber) ~= nil
end

local function equip(u, w)
	u.w = w
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
		if (it.a or 0) < (w.wd.capacity or 0) and ammoStack(u, w.wd.caliber) and not busy then
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
	local base = CFrame.lookAt(muzzle, aimPos)
	for i = 1, pellets do
		local e = err + ((pellets > 1) and (w.def.pelletSpread or 2.5) or 0)
		local dir = (base * CFrame.Angles(math.rad((math.random() * 2 - 1) * e * 0.75), math.rad((math.random() * 2 - 1) * e), 0)).LookVector
		local r = workspace:Raycast(muzzle, dir * w.def.range, params)
		local hp = r and r.Position or (muzzle + dir * w.def.range)
		if i == 1 then
			firstPos, firstNormal, firstMat = hp, r and r.Normal or nil, r and r.Material or nil
		end
		if r then
			local model = r.Instance:FindFirstAncestorOfClass("Model")
			local hum = model and model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and model ~= u.model then
				local d = (hp - muzzle).Magnitude
				local fs = w.def.range * Weapons.FALLOFF_START
				local fall = 1
				if d > fs then
					fall = math.max(Weapons.FALLOFF_MIN, 1 - (d - fs) / (w.def.range - fs) * (1 - Weapons.FALLOFF_MIN))
				end
				local res = ctx.Combat.hitModel(model, {
					dmg = ballistic.dmg * fall, pen = (ballistic.pen or 0) * (0.85 + 0.15 * fall), armorDmg = ballistic.armorDmg,
					bleedL = ballistic.bleedL, bleedH = ballistic.bleedH, part = r.Instance, hitPos = hp, attacker = u.model,
					from = muzzle, weapon = w.wd.name, ammo = ammoDef and ammoDef.name or "?",
				})
				hit = hit or res ~= nil
			end
		end
	end
	m.a -= 1
	if m.a <= 0 then
		m.a = 0
		m.at = nil
	end
	local ms = Inv.modStats(u.inv, w.g)
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
	setStance(u, (u.loiterCrouch and u.loiterUntil and t < u.loiterUntil) and "c" or "s", 0.7)
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

local function investigate(u, t)
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
	u.visible = u.seen[tm] ~= nil and (t - u.seen[tm]) < 0.3
	local tor = tm:FindFirstChild("UpperTorso") or tm:FindFirstChild("HumanoidRootPart")
	local tpos = (u.visible and tor and tor.Position) or u.lastPos[tm] or (tor and tor.Position)
	if not tpos then
		return
	end
	local thead = tm:FindFirstChild("Head")
	local threatEye = (u.visible and thead and thead.Position) or (tpos + Vector3.new(0, 1.3, 0))
	local dist = flat(tpos - u.root.Position).Magnitude
	-- out of ammo: reload, switch to the sidearm, or break off
	if roundsOf(u) <= 0 and not u.reloadUntil then
		if not startReload(u, t) and not rearm(u) then
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
			local range = sk.sight * (model:GetAttribute("WeaponLight") and 1.4 or 1)
			local vis = nil
			if dist < range then
				local inFov = dist < CLOSE or look:Dot(d.Unit) >= FOV_COS or (a >= 1 and dist < 45)
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
			if nz > 0 and dist < 60 * nz * sk.hearing then
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
	if liveCount() >= Config.AI_MAX then
		return nil
	end
	local myGen = gen
	local ok, model = pcall(ctx.Chars.buildRig, LOOK[kind])
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
	local inv = LOADOUT[kind](Random.new())
	ctx.Chars.dress(model, LOOK[kind], ctx.Chars.gearOf(inv))
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
		id = seq, kind = kind, faction = FACTION[kind], label = opts.label or LABEL[kind], name = model.Name, skill = SKILL[kind],
		model = model, hum = hum, root = root, head = model:FindFirstChild("Head"), inv = inv, alive = true, gen = myGen,
		state = (opts.route or opts.post or opts.leader) and "PATROL" or "WANDER", route = opts.route, wp = opts.wp or 1,
		post = opts.post, leader = opts.leader, slot = opts.slot,
		aware = {}, lastPos = {}, seen = {}, nextShot = 0, burstN = 0, burstLen = 3, stance = "s", depth = 0.8,
		useCover = math.random() < SKILL[kind].cover, turn = turn,
	}
	u.w = weaponIn(u, "primary") or weaponIn(u, "secondary") or weaponIn(u, "holster")
	table.insert(units, u)
	ctx.Health.attach(model, { kind = "ai", scale = SKILL[kind].hp, holder = function()
		return u.inv
	end })
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
	local radius = 200 * (loudness or 1)
	local t = now()
	local smodel = (typeof(shooter) == "Instance" and shooter:IsA("Player")) and shooter.Character or shooter
	for _, u in units do
		if u ~= except and u.alive and u.root then
			local d = (u.root.Position - pos).Magnitude
			if d < radius * u.skill.hearing then
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

function AI.onDamaged(model, attacker)
	local u = byModel(model)
	if not u or not u.alive then
		return
	end
	local t = now()
	u.suppressedUntil = t + 1.2
	u.alert = t + 30
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
	local myGen = gen
	local t = now()
	director.waves = 0
	director.nextWave = t + rnd(Config.SCAV_WAVE_EVERY * 0.8, Config.SCAV_WAVE_EVERY * 1.2)
	director.topUpUntil = t + Config.LATE_JOIN + 30
	director.nextTopUp = t + 6
	task.spawn(function()
		local W = ctx.World
		local bossRaid = (AI.forceBoss ~= nil) and AI.forceBoss or (math.random() < Config.BOSS_CHANCE)
		AI.bossThisRaid = bossRaid
		for _, wp in W.watchPosts or {} do
			if myGen ~= gen then
				return
			end
			local route = W.patrols[wp.route]
			if route then
				local idx = math.random(1, #route)
				AI.spawn("watch", wp.post or route[idx], { route = (not wp.post) and route or nil, wp = idx, post = wp.post })
			end
		end
		if bossRaid and W.boss then
			local boss = AI.spawn("boss", W.boss.home, { route = W.boss.route, wp = 1, label = "Foreman" })
			for i, p in W.boss.crew or {} do
				if myGen ~= gen then
					return
				end
				AI.spawn("follower", p, { leader = boss, slot = i })
			end
		elseif W.patrols.FD then
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
			local ok, err = pcall(directorTick)
			if not ok then
				warn("[ZR] AI director", err)
			end
		end
	end)
end

return AI
