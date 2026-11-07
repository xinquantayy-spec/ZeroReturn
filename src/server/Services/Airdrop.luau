--!nonstrict
-- Airdrops (Escape from Tarkov). On the open maps a transport plane may cross the raid and drop a crate under a
-- parachute. The crate lands on open ground, gives off red smoke that can be seen across the map, and is searched like
-- any container. docs/design/AIRDROPS.md has the research and what is not copied.
--
-- The roll uses each map's L.hazard.airdrop, Tarkov's AirdropParameters:
--   chance (PlaneAirdropChance) = 0.2
--   minPlayers (MinPlayersCountToSpawnAirdrop) = 6
--   first = PlaneAirdropStartMin..Max seconds into the raid
--   cooldown
-- At most one plane per raid, as Tarkov's PlaneAirdropMax 1. The cooldown is kept for the red flare, which is not
-- built. "Players" counts everyone alive in the raid, people and AI; Tarkov's own count is not published.
--
-- Each client draws the plane and the falling crate itself, from one "airdrop" fx message, so both move smoothly
-- (Effects -> AirdropFx). The server places the real crate when it lands, and the loot is only there.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local HttpService = game:GetService("HttpService")

local Airdrop = { points = {}, raid = nil, plan = nil, crates = {}, dropped = 0 }
local ctx

local MAPS = {
	border = { folder = "Border", o = Vector3.new(0, 0, -5200), limit = "boundary" },
	meridian = { folder = "Meridian", o = Vector3.new(0, 0, 9000), limit = "limit" },
}
-- Tarkov's crates (2026): common supply (unmarked), medical (a cross), supply (barter goods, a box symbol), weapon (a
-- crosshair); every one a 10 x 12 grid. The weights are ours: Tarkov publishes none.
local TYPES = {
	{ id = "common", label = "Supply crate", pool = "airdrop_common", count = { 10, 16 }, w = 4 },
	{ id = "medical", label = "Medical crate", pool = "airdrop_medical", count = { 12, 18 }, w = 2 },
	{ id = "supply", label = "Barter crate", pool = "airdrop_supply", count = { 10, 15 }, w = 2 },
	{ id = "weapon", label = "Weapon crate", pool = "airdrop_weapon", count = { 6, 10 }, w = 1.5 },
}
Airdrop.TYPES = TYPES
local ALT = 420 -- the plane's height over the drop point (about 135 m)
local SPEED = 140 -- studs a second (about 160 km/h: a transport on its drop run)
local RUN = 1600 -- studs flown before the drop point, and after it
local FALL = 7 -- the crate's sink rate under its canopy, studs a second
local SMOKE = 300 -- seconds of red smoke after the landing
local SPREAD = 220 -- drop points at least this far apart
local CLEAR = 70 -- and this far from exits and spawns
local FLARE_WAIT = { 90, 150 } -- seconds from a red flare to the plane over it ("a few minutes")
local FLARE_COOLDOWN = { 900, 1020 } -- Tarkov: 15 to 17 minutes before the next call is answered
local FLARE_SCATTER = 15 -- the crate lands this close to the flare's spot
Airdrop.ALT, Airdrop.SPEED, Airdrop.RUN, Airdrop.FALL = ALT, SPEED, RUN, FALL

local function now()
	return workspace:GetServerTimeNow()
end

local function inside(poly, x, z)
	local c, n = false, #poly / 2
	local j = n
	for i = 1, n do
		local xi, zi, xj, zj = poly[2 * i - 1], poly[2 * i], poly[2 * j - 1], poly[2 * j]
		if ((zi > z) ~= (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi) + xi) then
			c = not c
		end
		j = i
	end
	return c
end

local function groundParams()
	local skip = {}
	for _, n in { "ZR_AI", "ZR_Loot", "ZR_Loose", "ZR_Corpses", "ZR_GlassHit", "ZR_Traders", "ZR_Airdrops" } do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(skip, f)
		end
	end
	local world = workspace:FindFirstChild("ZR_World")
	local trig = world and world:FindFirstChild("Triggers")
	if trig then
		table.insert(skip, trig)
	end
	for _, p in game:GetService("Players"):GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = skip
	rp.IgnoreWater = false
	return rp
end

-- the open, level spots of a map where a crate may come down: terrain under open sky, level for 14 studs round, not in
-- water, 70 studs from the map's exits and spawns, at least 220 apart. Worked out once per map from the built world.
function Airdrop.findPoints(mapId)
	if Airdrop.points[mapId] then
		return Airdrop.points[mapId]
	end
	local spec = MAPS[mapId]
	if not spec then
		return {}
	end
	local okL, L = pcall(require, script.Parent.Parent.Maps[spec.folder].Layout)
	local poly = okL and L[spec.limit]
	if not poly then
		return {}
	end
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	for i = 1, #poly, 2 do
		x0, x1 = math.min(x0, poly[i]), math.max(x1, poly[i])
		z0, z1 = math.min(z0, poly[i + 1]), math.max(z1, poly[i + 1])
	end
	local keep = {}
	local m = ctx.World.maps and ctx.World.maps[mapId]
	for _, e in (m and m.extracts) or {} do
		table.insert(keep, e.pos or (e.cf and e.cf.Position))
	end
	for _, sp in (m and m.spawns) or {} do
		table.insert(keep, sp.cf and sp.cf.Position)
	end
	local rp = groundParams()
	local cands = {}
	local n = 0
	for x = x0 + 30, x1 - 30, 40 do
		for z = z0 + 30, z1 - 30, 40 do
			if inside(poly, x, z) then
				local wx, wz = spec.o.X + x, spec.o.Z + z
				local h = workspace:Raycast(Vector3.new(wx, 700, wz), Vector3.new(0, -1000, 0), rp)
				if h and h.Instance == workspace.Terrain and h.Material ~= Enum.Material.Water and h.Normal.Y > 0.96 then
					local ok = true
					for k = 0, 7 do
						local a = k * math.pi / 4
						local q = workspace:Raycast(Vector3.new(wx + math.cos(a) * 14, 700, wz + math.sin(a) * 14), Vector3.new(0, -1000, 0), rp)
						if not q or q.Instance ~= workspace.Terrain or q.Material == Enum.Material.Water or math.abs(q.Position.Y - h.Position.Y) > 2 then
							ok = false
							break
						end
					end
					for _, p in keep do
						if ok and p and (Vector3.new(p.X, 0, p.Z) - Vector3.new(wx, 0, wz)).Magnitude < CLEAR then
							ok = false
						end
					end
					if ok then
						table.insert(cands, h.Position)
					end
				end
			end
			n += 1
			if n % 400 == 0 then
				task.wait()
			end
		end
	end
	-- spread them out: a fixed shuffle (the same every server), then keep each spot far enough from those kept
	local rng = Random.new(#cands * 7919 + 13)
	for i = #cands, 2, -1 do
		local j = rng:NextInteger(1, i)
		cands[i], cands[j] = cands[j], cands[i]
	end
	local picks = {}
	for _, p in cands do
		local far = true
		for _, q in picks do
			if (p - q).Magnitude < SPREAD then
				far = false
				break
			end
		end
		if far then
			table.insert(picks, p)
		end
	end
	Airdrop.points[mapId] = picks
	return picks
end

-- people and AI alive in the raid
local function headcount()
	local n = 0
	for _, s in ctx.Raid.sessions() do
		if not s.done then
			n += 1
		end
	end
	for _, u in (ctx.AI and ctx.AI.units) or {} do
		if u.alive then
			n += 1
		end
	end
	return n
end

local function pickType(rng, want)
	if want then
		for _, t in TYPES do
			if t.id == want then
				return t
			end
		end
	end
	local total = 0
	for _, t in TYPES do
		total += t.w
	end
	local r = rng:NextNumber() * total
	for _, t in TYPES do
		r -= t.w
		if r <= 0 then
			return t
		end
	end
	return TYPES[1]
end

local function folder()
	local f = workspace:FindFirstChild("ZR_Airdrops")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ZR_Airdrops"
		f.Parent = workspace
	end
	return f
end

local function part(parent, size, cf, color, mat, name)
	local p = Instance.new("Part")
	p.Name = name or "Part"
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- the landed crate: a ribbed olive box (about 1.5 m) on a pallet with its marking, the canopy collapsed beside it,
-- and red smoke from a canister on its lid
local MARK = { medical = "cross", supply = "box", weapon = "crosshair" }
function Airdrop.buildCrate(pos, kind, yaw)
	local m = Instance.new("Model")
	m.Name = "Airdrop_" .. kind
	m:SetAttribute("NoDetail", true)
	local base = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	local OLIVE, DARK, WOOD = Color3.fromRGB(78, 86, 58), Color3.fromRGB(52, 57, 40), Color3.fromRGB(112, 92, 62)
	part(m, Vector3.new(5.4, 0.6, 5.4), base * CFrame.new(0, 0.3, 0), WOOD, Enum.Material.WoodPlanks, "Pallet")
	local body = part(m, Vector3.new(4.8, 4.4, 4.8), base * CFrame.new(0, 2.8, 0), OLIVE, Enum.Material.Metal, "Body")
	for _, dy in { 1.1, 4.5 } do
		part(m, Vector3.new(5.0, 0.35, 5.0), base * CFrame.new(0, dy, 0), DARK, Enum.Material.Metal, "Rib")
	end
	part(m, Vector3.new(0.9, 0.9, 0.9), base * CFrame.new(1.4, 5.45, 1.4), Color3.fromRGB(150, 40, 32), Enum.Material.Metal, "Canister")
	-- the marking on two sides
	local mark = MARK[kind]
	local WHITE = Color3.fromRGB(226, 222, 206)
	for _, side in { 0, 180 } do
		local face = base * CFrame.Angles(0, math.rad(side), 0) * CFrame.new(0, 2.8, -2.43)
		if mark == "cross" then
			part(m, Vector3.new(0.7, 2.4, 0.06), face, Color3.fromRGB(176, 38, 34), Enum.Material.SmoothPlastic, "Mark").CanCollide = false
			part(m, Vector3.new(2.4, 0.7, 0.06), face, Color3.fromRGB(176, 38, 34), Enum.Material.SmoothPlastic, "Mark").CanCollide = false
		elseif mark == "box" then
			for _, o in { { 0, 0.9, 1.9, 0.25 }, { 0, -0.9, 1.9, 0.25 }, { 0.85, 0, 0.25, 1.9 }, { -0.85, 0, 0.25, 1.9 } } do
				part(m, Vector3.new(o[3], o[4], 0.06), face * CFrame.new(o[1], o[2], 0), WHITE, Enum.Material.SmoothPlastic, "Mark").CanCollide = false
			end
		elseif mark == "crosshair" then
			for _, o in { { 0, 0.85, 0.22, 0.7 }, { 0, -0.85, 0.22, 0.7 }, { 0.85, 0, 0.7, 0.22 }, { -0.85, 0, 0.7, 0.22 } } do
				part(m, Vector3.new(o[3], o[4], 0.06), face * CFrame.new(o[1], o[2], 0), WHITE, Enum.Material.SmoothPlastic, "Mark").CanCollide = false
			end
			part(m, Vector3.new(0.3, 0.3, 0.06), face, WHITE, Enum.Material.SmoothPlastic, "Mark").CanCollide = false
		end
	end
	-- the canopy, collapsed on the ground downwind
	local cloth = part(m, Vector3.new(9, 0.25, 6), base * CFrame.new(0, 0.12, 7.6) * CFrame.Angles(0, math.rad(12), math.rad(2)), Color3.fromRGB(96, 104, 76), Enum.Material.Fabric, "Canopy")
	cloth.CanCollide = false
	for _, dx in { -2.4, 0, 2.4 } do
		local a, b = (base * CFrame.new(dx * 0.4, 4.6, 2.3)).Position, (base * CFrame.new(dx, 0.2, 5.4)).Position
		local line = part(m, Vector3.new(0.06, 0.06, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(60, 60, 52), Enum.Material.SmoothPlastic, "Line")
		line.CanCollide, line.CanQuery = false, false
	end
	-- red smoke (Tarkov: seen across the map)
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(1.4, 2.9, 1.4)
	att.Parent = body
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Smoke"
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(196, 46, 38), Color3.fromRGB(150, 70, 66))
	pe.LightEmission = 0.05
	pe.LightInfluence = 0.85
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(0.4, 9), NumberSequenceKeypoint.new(1, 22) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(9, 14)
	pe.Rate = 7
	pe.Speed = NumberRange.new(9, 14)
	pe.SpreadAngle = Vector2.new(12, 12)
	pe.Acceleration = Vector3.new(1.6, 1.2, 0.8) -- drifts downwind as it rises
	pe.Drag = 0.6
	pe.RotSpeed = NumberRange.new(-20, 20)
	pe.Rotation = NumberRange.new(0, 360)
	pe.Parent = att
	m.PrimaryPart = body
	m.Parent = folder()
	return m, body, pe
end

-- the landing: the crate model, its loot and the smoke
local function land(d)
	if Airdrop.raid ~= d.raid then
		return -- a different raid by now
	end
	local m, body, pe = Airdrop.buildCrate(d.pos, d.kind, d.yaw)
	local t = nil
	for _, ty in TYPES do
		if ty.id == d.kind then
			t = ty
		end
	end
	t = t or TYPES[1]
	local rng = Random.new(d.seed)
	local c = ctx.Loot.spawnCrate(body, { label = t.label, pool = t.pool, w = 10, h = 12, count = rng:NextInteger(t.count[1], t.count[2]), seed = d.seed })
	table.insert(Airdrop.crates, { model = m, container = c, raid = d.raid })
	ctx.Remotes.fx("sfx", { n = "impact_metal_2", p = d.pos + Vector3.new(0, 2, 0), v = 1.4 })
	task.delay(0.4, function()
		ctx.Remotes.fx("sfx", { n = "smoke_pop", p = d.pos + Vector3.new(0, 4, 0), v = 1.2 })
	end)
	task.delay(SMOKE, function()
		if pe.Parent then
			pe.Enabled = false
		end
	end)
	Airdrop.dropped += 1
	print(string.format("[ZR] airdrop landed: %s crate at %.0f, %.0f, %.0f (%d items)", d.kind, d.pos.X, d.pos.Y, d.pos.Z, #c.order))
end

-- send the plane now: kind (optional), at (an optional world point on the ground; else a random drop point)
function Airdrop.drop(kind, at)
	local mapId = ctx.World.activeMap
	local rng = Random.new()
	local pos = at
	if not pos then
		local pts = Airdrop.findPoints(mapId)
		if #pts == 0 then
			return nil, "no drop points on " .. tostring(mapId)
		end
		pos = pts[rng:NextInteger(1, #pts)]
	end
	local t = pickType(rng, kind)
	local heading = rng:NextNumber(0, 2 * math.pi)
	local dir = Vector3.new(math.cos(heading), 0, math.sin(heading))
	local over = pos + Vector3.new(0, ALT, 0)
	local d = {
		raid = Airdrop.raid, kind = t.id, pos = pos, yaw = math.deg(heading) + rng:NextNumber(-25, 25), seed = rng:NextInteger(1, 2 ^ 30),
		from = over - dir * RUN, to = over + dir * RUN, t0 = now(), flight = 2 * RUN / SPEED, release = RUN / SPEED,
	}
	d.fall = (ALT - 6) / FALL
	-- every client draws the plane and the falling crate (Effects -> AirdropFx); the crate is placed here on landing
	ctx.Remotes.fxReliable("airdrop", {
		id = HttpService:GenerateGUID(false), kind = d.kind, pos = d.pos, from = d.from, to = d.to, t0 = d.t0, flight = d.flight,
		release = d.release, fall = d.fall, yaw = d.yaw,
	})
	task.delay(d.release + d.fall, land, d)
	Airdrop.last = d
	return d
end

-- the map in play's airdrop numbers (L.hazard.airdrop), or nil on a map without airdrops
local function cfgOf(mapId)
	local spec = MAPS[mapId]
	if not spec then
		return nil
	end
	local okL, L = pcall(require, script.Parent.Parent.Maps[spec.folder].Layout)
	return okL and L and L.hazard and L.hazard.airdrop or nil
end

local function skyParams()
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain, workspace:FindFirstChild("ZR_World") }
	return rp
end

-- can this player fire a flare here? (in a raid, alive, under the open sky); false, code, message otherwise
function Airdrop.canFlare(player)
	local s = ctx.Raid.session(player)
	local char = player.Character
	local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
	if not s or s.done or not head then
		return false, "NOT_AUTHORIZED"
	end
	if workspace:Raycast(head.Position + Vector3.new(0, 1, 0), Vector3.new(0, 220, 0), skyParams()) then
		return false, "NEED_OPEN_SKY", "Fire the flare under the open sky."
	end
	return true
end

-- a fired flare (Health has used it up): everyone sees the star; a red one on a map with airdrops calls a plane to the
-- spot unless one is already on its way or the airspace is still congested from the last call
function Airdrop.flare(player, f)
	local char = player.Character
	local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
	if not head then
		return false
	end
	local p = head.Position
	local color = (f and f.color) or "red"
	ctx.Remotes.fxReliable("flare", { p = p + Vector3.new(0, 1.2, 0), c = color })
	if f and f.exit and ctx.Extract and ctx.Extract.flareFired then
		return ctx.Extract.flareFired(player, p) -- a green flare: the flare exits round the shooter
	end
	if not (f and f.call) then
		return true
	end
	local M = ctx.Match
	if M.state ~= "RUNNING" or not cfgOf(ctx.World.activeMap) then
		return false
	end
	local t = now()
	if Airdrop.pending or t < (Airdrop.flareReady or 0) then
		ctx.Remotes.note(player, "toast", { text = "WAIT FOR ARRIVAL! AIRSPACE IS CONGESTED", tone = "warn" })
		return false
	end
	local rng = Random.new()
	Airdrop.flareReady = t + rng:NextNumber(FLARE_COOLDOWN[1], FLARE_COOLDOWN[2])
	Airdrop.pending = true
	local a = rng:NextNumber(0, 2 * math.pi)
	local r = rng:NextNumber(0, FLARE_SCATTER)
	local probe = Vector3.new(p.X + math.cos(a) * r, p.Y + 6, p.Z + math.sin(a) * r)
	local hit = workspace:Raycast(probe, Vector3.new(0, -400, 0), skyParams())
	local at = hit and hit.Position or Vector3.new(p.X, p.Y - 2.5, p.Z)
	local raid = Airdrop.raid
	local wait = rng:NextNumber(FLARE_WAIT[1], FLARE_WAIT[2])
	Airdrop.called = { at = at, eta = t + wait + RUN / SPEED, by = player.Name }
	task.delay(wait, function()
		Airdrop.pending = false
		if Airdrop.raid == raid then
			local ok, err = pcall(Airdrop.drop, nil, at)
			if not ok then
				warn("[ZR] flare airdrop failed:", err)
			end
		end
	end)
	return true
end

-- a new raid: clear the last one's crates and roll this one's plane
local function newRaid(raidId, mapId)
	for _, c in Airdrop.crates do
		if c.model and c.model.Parent then
			c.model:Destroy()
		end
	end
	table.clear(Airdrop.crates)
	Airdrop.raid = raidId
	Airdrop.plan = nil
	Airdrop.pending, Airdrop.flareReady, Airdrop.called = false, 0, nil
	local cfg = cfgOf(mapId)
	if not cfg then
		return
	end
	local rng = Random.new()
	local forced = Airdrop.force -- ZR_Dev: true = always, false = never, nil = roll
	if forced == false then
		return
	end
	if forced == true or rng:NextNumber() < (cfg.chance or 0) then
		local first = cfg.first or { 300, 900 }
		Airdrop.plan = { at = now() + rng:NextNumber(first[1], first[2]), minPlayers = cfg.minPlayers or 0, forced = forced == true }
	end
	-- find the drop points while the raid starts (cached per map)
	task.spawn(Airdrop.findPoints, mapId)
end

local function tick()
	local M = ctx.Match
	if M.state ~= "RUNNING" or not M.id then
		if Airdrop.raid then
			newRaid(nil, nil)
		end
		return
	end
	if M.id ~= Airdrop.raid then
		newRaid(M.id, ctx.World.activeMap)
	end
	local plan = Airdrop.plan
	if plan and now() >= plan.at then
		Airdrop.plan = nil
		if plan.forced or headcount() >= plan.minPlayers then
			local ok, err = pcall(Airdrop.drop)
			if not ok then
				warn("[ZR] airdrop failed:", err)
			end
		end
	end
end

function Airdrop.init(c)
	ctx = c
end

function Airdrop.start()
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tick)
			if not ok then
				warn("[ZR] airdrop tick", err)
			end
		end
	end)
end

return Airdrop
