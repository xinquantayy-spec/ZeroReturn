--!nonstrict
-- Grenades (M11, Tarkov rules). Players: act "nade" {op = "pull"} when G goes down (pin pulled; the hands leave
-- the weapon), {op = "throw", x, y, z, u} when it is released (u = underhand). The server takes the first grenade
-- in the rig, then the pockets, checks timing and direction, simulates the whole bouncing path at release
-- (shared Grenades.simulate, the static world only) and sends it to every client; when the fuse runs out:
--   frag  : fragments strike the body parts in line of sight (expected hits from area and distance, armour
--           applies through the health model) plus blast close in; kills credit the thrower
--   stun  : AI facing it are blinded and deafened (each player works out their own white-out from the event)
--   smoke : a cloud that blocks AI sight for about a minute (clients draw it; players see the particles)
-- AI throw through Grenades.throwFrom and run from grenades that land near them (AI.luau).
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local G = require(Shared.Grenades)
local Util = require(Shared.Util)
local Inv = require(script.Parent.Inv)

local Grenades = { live = {}, smokes = {}, stats = { thrown = 0, exploded = 0, fragHits = 0 } }
local ctx
local P = {} -- [player] = { s = session, pull = clock?, g = guid?, cd = clock }
local seq = 0
local rng = Random.new()

local worldRay = RaycastParams.new()
worldRay.FilterType = Enum.RaycastFilterType.Include
local losRay = RaycastParams.new()
losRay.FilterType = Enum.RaycastFilterType.Exclude

local function setWorld()
	local w = workspace:FindFirstChild("ZR_World")
	worldRay.FilterDescendantsInstances = { w }
	return w ~= nil
end

local function ray(origin, dir)
	local r = workspace:Raycast(origin, dir, worldRay)
	if r then
		return r.Position, r.Normal
	end
	return nil, nil
end

local function setLos()
	local list = {}
	for _, name in { "ZR_Fx", "ZR_Loot", "ZR_Loose", "ZR_Corpses" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	losRay.FilterDescendantsInstances = list
end

local function alive(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return char, hum
	end
	return nil, nil
end

local function stateOf(player)
	local s = ctx.Raid.session(player)
	local p = P[player]
	if not p or p.s ~= s then
		p = { s = s, cd = 0 }
		P[player] = p
	end
	return p, s
end

-- a pin is pulled right now (no shooting, no weapon change until it is thrown)
function Grenades.busy(player)
	local p = P[player]
	return p ~= nil and p.pull ~= nil and p.s == ctx.Raid.session(player) and os.clock() - p.pull < G.PULL_MAX
end

function Grenades.pick(h, want, deep)
	return G.pick(h, Items.defs, want, deep)
end

-- where a throw would end up (AI planning): the same simulation the real throw uses
function Grenades.simulate(origin, vel, fuse)
	if not setWorld() then
		return nil
	end
	return G.simulate(origin, vel, fuse, ray)
end

-- ── explosions ───────────────────────────────────────────────────────────────
local function charactersNear(pos, r)
	local out = {}
	for player, s in ctx.Raid.sessions() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not s.done and root and (root.Position - pos).Magnitude < r + 4 then
			table.insert(out, char)
		end
	end
	for _, u in ctx.AI.units do
		if u.alive and u.root and (u.root.Position - pos).Magnitude < r + 4 then
			table.insert(out, u.model)
		end
	end
	return out
end

-- first thing a line from `from` to `part` meets belongs to `model`?
local function exposed(from, part, model)
	local to = part.Position - from
	local d = to.Magnitude
	if d < 0.05 then
		return true, part
	end
	local r = workspace:Raycast(from, to / d * (d + 0.6), losRay)
	if r and r.Instance:IsDescendantOf(model) then
		local hit = r.Instance
		-- a limb in front takes the strike instead (gear and the root part count as the aimed part)
		if ctx.Health.PART_OF[hit.Name] and hit.Name ~= "HumanoidRootPart" then
			return true, hit
		end
		return true, part
	end
	return false, nil
end

local function frag(n, center)
	local spec = n.spec
	local name = Items.defs[n.item].name
	setLos()
	for _, model in charactersNear(center, spec.fragR) do
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			for _, pn in G.BODY do
				local part = model:FindFirstChild(pn)
				if part and part:IsA("BasePart") and hum.Health > 0 then
					local d = (part.Position - center).Magnitude
					if d < spec.fragR then
						local los, struck = exposed(center, part, model)
						if los then
							local k = math.min(6, G.poisson(rng, G.fragLambda(spec.frags, G.areaOf(part.Size), d)))
							local dir = (struck.Position - center).Unit
							for _ = 1, k do
								if hum.Health <= 0 then
									break
								end
								local dmg, pen = G.fragHit(spec, d, rng)
								Grenades.stats.fragHits += 1
								ctx.Combat.hitModel(model, {
									dmg = dmg, pen = pen, armorDmg = 0.12, bleedL = 0.35, bleedH = 0.12, part = struck,
									hitPos = struck.Position - dir * 0.3, attacker = n.thrower, from = center, weapon = name,
									ammo = "FRAGMENT", cause = "GRENADE",
								})
							end
						end
					end
				end
			end
			-- blast: close in, it gets through armour (the plates only take the edge off)
			local torso = model:FindFirstChild("UpperTorso")
			if torso and hum.Health > 0 then
				local d = (torso.Position - center).Magnitude
				if d < spec.blastR and exposed(center, torso, model) then
					ctx.Combat.hitModel(model, {
						dmg = spec.blastDmg * (1 - d / spec.blastR), pen = 80, armorDmg = 0.05, bleedL = 0, bleedH = 0,
						part = torso, hitPos = torso.Position, attacker = n.thrower, from = center, weapon = name,
						ammo = "BLAST", cause = "GRENADE",
					})
				end
			end
		end
	end
end

local function explode(n)
	local spec = n.spec
	local center = n.pos + Vector3.new(0, 0.35, 0)
	Grenades.stats.exploded += 1
	ctx.Remotes.noteAll("nadeX", { id = n.id, k = spec.type, p = center, item = n.item })
	local loud = 2.4
	if spec.type == "frag" then
		frag(n, center)
	elseif spec.type == "stun" then
		loud = 1.8
		if ctx.AI.flashed then
			ctx.AI.flashed(center, spec)
		end
	elseif spec.type == "smoke" then
		loud = 0.35
		table.insert(Grenades.smokes, { id = n.id, pos = center + Vector3.new(0, 4, 0), t0 = os.clock(), spec = spec })
	end
	local smodel = n.thrower
	if typeof(smodel) == "Instance" and smodel:IsA("Player") then
		smodel = smodel.Character
	end
	ctx.AI.hearShot(center, smodel, nil, loud)
end

-- ── throwing ─────────────────────────────────────────────────────────────────
-- thrower: Player or AI Model; origin/vel in world space; returns the live grenade
function Grenades.throwFrom(thrower, origin, vel, itemId)
	local def = Items.defs[itemId]
	local spec = def and def.nade
	if not spec or not setWorld() then
		return nil
	end
	local path = G.simulate(origin, vel, spec.fuse, ray)
	seq += 1
	local t = os.clock()
	local n = { id = seq, item = itemId, spec = spec, thrower = thrower, path = path, t0 = t, at = t + spec.fuse, pos = path.final }
	Grenades.live[n.id] = n
	Grenades.stats.thrown += 1
	local who = nil
	if typeof(thrower) == "Instance" and thrower:IsA("Player") then
		who = thrower.UserId
	end
	ctx.Remotes.noteAll("nade", {
		id = n.id, k = spec.type, item = itemId, t0 = workspace:GetServerTimeNow(), t = path.t, p = path.p, b = path.b,
		f = spec.fuse, who = who,
	})
	if ctx.AI.grenadeIncoming then
		local tmodel = thrower
		if typeof(tmodel) == "Instance" and tmodel:IsA("Player") then
			tmodel = tmodel.Character
		end
		ctx.AI.grenadeIncoming({
			pos = path.final, kind = spec.type, radius = (spec.type == "frag" and spec.fragR * 0.75) or (spec.type == "stun" and 12) or 0,
			land = t + (path.land or path.endT), boom = n.at, thrower = tmodel,
		})
	end
	task.delay(spec.fuse, function()
		if Grenades.live[n.id] == n then
			Grenades.live[n.id] = nil
			local ok, err = pcall(explode, n)
			if not ok then
				warn("[ZR] grenade", err)
			end
		end
	end)
	return n
end

-- release point for a character: in front of the eye, pulled back if it would start inside a wall
function Grenades.releaseFrom(eye, look, under)
	local origin = G.releasePoint(eye, look, under)
	setWorld()
	local d = origin - eye
	local r = workspace:Raycast(eye, d, worldRay)
	if r then
		origin = r.Position - d.Unit * 0.35
	end
	return origin
end

local function pull(player)
	local ps, s = stateOf(player)
	if not s or s.done then
		return
	end
	local char = alive(player)
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local t = os.clock()
	if (ps.pull and t - ps.pull < G.PULL_MAX) or t < (ps.cd or 0) then
		return
	end
	local hs = ctx.Health.of(player)
	if hs and hs.using then
		return
	end
	local g = Grenades.pick(s.inv)
	if not g then
		ctx.Remotes.note(player, "nadeFail", { why = "none" })
		return
	end
	ps.pull, ps.g = t, g
	char:SetAttribute("NadeItem", s.inv.items[g].id)
	char:SetAttribute("Nade", true)
	ctx.Chars.gesture(char, "pin", G.PULL_TIME)
	ctx.Remotes.fx("sfx", { n = "nade_pin", p = head.Position, v = 0.55 }, player)
end

local function throw(player, p)
	local ps, s = stateOf(player)
	if not s or s.done or not ps.pull then
		return
	end
	local t = os.clock()
	if t - ps.pull < G.PULL_MIN then
		-- released during the pin pull: throw as soon as the pin is out
		local token = ps.pull
		task.delay(G.PULL_MIN - (t - ps.pull) + 0.02, function()
			if ps.pull == token then
				throw(player, p)
			end
		end)
		return
	end
	local char = alive(player)
	local head = char and char:FindFirstChild("Head")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local dir = Vector3.new(p.x, p.y, p.z)
	if not head or not root or not Util.vec(dir) then
		ps.pull, ps.g = nil, nil
		if char then
			char:SetAttribute("Nade", false)
		end
		return ctx.Remotes.strike(player, "bad throw")
	end
	local m = dir.Magnitude
	if m < 0.5 or m > 1.5 then
		return ctx.Remotes.strike(player, "bad throw direction")
	end
	dir /= m
	local g = (ps.g and s.inv.items[ps.g]) and ps.g or Grenades.pick(s.inv)
	ps.pull, ps.g = nil, nil
	ps.cd = t + G.COOLDOWN
	char:SetAttribute("Nade", false)
	if not g then
		ctx.Remotes.note(player, "nadeFail", { why = "gone" })
		return
	end
	local id = s.inv.items[g].id
	Inv.consume(s.inv, g)
	local under = p.u == true
	ctx.Chars.gesture(char, under and "tossu" or "toss", 0.55)
	local origin = Grenades.releaseFrom(head.Position + Vector3.new(0, 0.12, 0), dir, under)
	Grenades.throwFrom(player, origin, G.launch(dir, under, root.AssemblyLinearVelocity), id)
	ctx.Remotes.fx("sfx", { n = "nade_throw", p = origin, v = 0.6 }, player)
	ctx.Raid.push(player)
end

-- ── smoke ────────────────────────────────────────────────────────────────────
-- does the line of sight a-b run through a dense cloud? (AI vision)
function Grenades.smokeBetween(a, b)
	local smokes = Grenades.smokes
	if #smokes == 0 then
		return false
	end
	local t = os.clock()
	for i = #smokes, 1, -1 do
		local sm = smokes[i]
		local age = t - sm.t0
		local r, dens = G.cloud(sm.spec, age)
		if age > 5 and dens <= 0 then
			table.remove(smokes, i)
		elseif G.segmentInCloud(a, b, sm.pos, r, dens) then
			return true
		end
	end
	return false
end

-- Studio test bridge (Dev.luau): the real pull/throw handlers
Grenades._pull = pull
Grenades._throw = throw

-- raid over: nothing in flight goes off, clouds vanish
function Grenades.clear()
	table.clear(Grenades.live)
	table.clear(Grenades.smokes)
	table.clear(P)
	ctx.Remotes.noteAll("nadeClear", {})
end

function Grenades.init(c)
	ctx = c
	ctx.Remotes.onAct("nade", function(player, p)
		if type(p) ~= "table" then
			return
		end
		if p.op == "pull" then
			pull(player)
		elseif p.op == "throw" and type(p.x) == "number" and type(p.y) == "number" and type(p.z) == "number" then
			throw(player, p)
		end
	end, 3, 4)
	Players.PlayerRemoving:Connect(function(pl)
		P[pl] = nil
	end)
end

return Grenades
