--!nonstrict
-- Map hazards (Tarkov's Customs): orange propane cylinders explode when a bullet hits them or a blast reaches them
-- (a fireball with heavy blast damage close in and a few fragments), and a burst one sets off its neighbours. Maps
-- register their cylinder spots while they build; every raid starts with all of them back in place. Also the border
-- snipers (watched strips along a map's edge) and minefields (hidden charges over a band of ground).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local CollectionService = game:GetService("CollectionService")

local Hazards = { spots = {}, CHAIN_R = 9 }
local ctx

local ORANGE, CAP = Color3.fromRGB(196, 92, 34), Color3.fromRGB(120, 116, 106)

-- build one cylinder (a body, a shoulder, a valve) at cf (its base); parent is the map model
local function build(spot)
	local m = Instance.new("Model")
	m.Name = "Propane"
	m:SetAttribute("NoDetail", true)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Cylinder
	body.Size = Vector3.new(3.6, 1.25, 1.25) -- 1.15 m tall, 0.4 m across (a 50 l cylinder)
	body.CFrame = spot.cf * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90))
	body.Color, body.Material = ORANGE, Enum.Material.Metal
	body.Anchored = true
	body.Parent = m
	local top = Instance.new("Part")
	top.Name = "Valve"
	top.Size = Vector3.new(0.35, 0.45, 0.35)
	top.CFrame = spot.cf * CFrame.new(0, 3.8, 0)
	top.Color, top.Material = CAP, Enum.Material.Metal
	top.Anchored, top.CanCollide = true, false
	top.Parent = m
	m.PrimaryPart = body
	CollectionService:AddTag(body, "ZR_Propane")
	m.Parent = spot.parent
	spot.model = m
	return m
end

-- a map's cylinder spot (call while the map builds)
function Hazards.register(parent, cf)
	local spot = { parent = parent, cf = cf }
	table.insert(Hazards.spots, spot)
	build(spot)
	return spot
end

local function spotOf(part)
	for _, s in Hazards.spots do
		if s.model and part:IsDescendantOf(s.model) then
			return s
		end
	end
	return nil
end

-- blow a cylinder up (a bullet, a blast or a neighbour): attacker gets the kill credit
function Hazards.burst(spot, attacker)
	if not spot.model then
		return
	end
	local center = spot.model.PrimaryPart and spot.model.PrimaryPart.Position or spot.cf.Position
	spot.model:Destroy()
	spot.model = nil
	if ctx.Grenades.blastAt then
		ctx.Grenades.blastAt(center, "PROPANE_TANK", attacker)
	end
	-- neighbours go off a moment later
	for _, s in Hazards.spots do
		if s.model and (s.cf.Position - spot.cf.Position).Magnitude < Hazards.CHAIN_R then
			task.delay(0.25 + math.random() * 0.3, Hazards.burst, s, attacker)
		end
	end
end

-- a bullet hit something: was it a cylinder?
function Hazards.hit(part, attacker)
	if part and CollectionService:HasTag(part, "ZR_Propane") then
		local s = spotOf(part)
		if s then
			Hazards.burst(s, attacker)
			return true
		end
	end
	return false
end

-- a blast at center with radius r reaches any cylinder in range
function Hazards.blast(center, r, attacker)
	for _, s in Hazards.spots do
		if s.model and (s.cf.Position - center).Magnitude < r then
			task.delay(0.15 + math.random() * 0.2, Hazards.burst, s, attacker)
		end
	end
end

-- minefields (Tarkov's mines): hidden charges spread over a band of ground. Anyone within MINE_R studs of a live one sets it
-- off: a blast under their feet and a lethal wound; one charge goes off once per raid. Maps hand in the charge positions
-- (world Vector3, on the ground) while they build.
Hazards.mines = {} -- sets: { cells = { [key] = { mine ... } }, list = { mine ... } }, mine = { x, y, z, live }
Hazards.MINE_R, Hazards.MINE_CELL = 3.4, 48
local function mineKey(cx, cz)
	return (cx + 4096) * 8192 + (cz + 4096)
end
function Hazards.mineField(points)
	local set = { cells = {}, list = {} }
	for _, p in points do
		local m = { x = p.X, y = p.Y, z = p.Z, live = true }
		table.insert(set.list, m)
		local k = mineKey(math.floor(m.x / Hazards.MINE_CELL), math.floor(m.z / Hazards.MINE_CELL))
		set.cells[k] = set.cells[k] or {}
		table.insert(set.cells[k], m)
	end
	table.insert(Hazards.mines, set)
	return set
end
-- the live charge within MINE_R studs (flat) of pos, or nil
function Hazards.mineNear(pos)
	local cx, cz = math.floor(pos.X / Hazards.MINE_CELL), math.floor(pos.Z / Hazards.MINE_CELL)
	local r2 = Hazards.MINE_R * Hazards.MINE_R
	for _, set in Hazards.mines do
		for i = -1, 1 do
			for j = -1, 1 do
				for _, m in set.cells[mineKey(cx + i, cz + j)] or {} do
					if m.live and math.abs(m.y - pos.Y) < 9 then
						local dx, dz = m.x - pos.X, m.z - pos.Z
						if dx * dx + dz * dz < r2 then
							return m
						end
					end
				end
			end
		end
	end
	return nil
end
-- a charge goes off under a player (the blast wakes everything nearby; the wound is the kill)
function Hazards.detonate(m, player, char)
	m.live = false
	local at = Vector3.new(m.x, m.y + 0.3, m.z)
	if ctx.Grenades.blastAt then
		ctx.Grenades.blastAt(at, "PROPANE_TANK", nil)
	end
	local part = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart"))
	if part then
		ctx.Combat.hitModel(char, {
			dmg = 400, pen = 100, armorDmg = 0.2, bleedL = 1, bleedH = 1, part = part, hitPos = part.Position,
			attacker = "MINE", from = at, weapon = "Land mine", ammo = "BLAST", cause = "MINE",
		})
	end
	if player then
		ctx.Remotes.note(player, "toast", { text = "MINE", tone = "warn" })
	end
end
function Hazards.mineStep()
	if #Hazards.mines == 0 then
		return
	end
	for player, s in ctx.Raid.sessions() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not s.done and root and hum and hum.Health > 0 then
			local m = Hazards.mineNear(root.Position)
			if m then
				Hazards.detonate(m, player, char)
			end
		end
	end
end

-- a new raid: every cylinder is back, every mine armed again
function Hazards.reset()
	for _, s in Hazards.spots do
		if not s.model then
			build(s)
		end
	end
	for _, set in Hazards.mines do
		for _, m in set.list do
			m.live = true
		end
	end
end

-- border snipers (Tarkov): the strips along a map's edge are watched; linger there and a warning shot cracks
-- past, then the hits come (head or chest) until you leave. Spawns and extracts near the edge are left clear.
Hazards.zones = {}
Hazards.WARN, Hazards.FIRST, Hazards.EVERY = 3, 6, 2.5

-- where the sniper fires from: 200 studs out past the strip's outer side, away from the map's middle, 40 up and
-- spread along the strip (audit ai.14; the shots all came from -Z before, whichever edge the strip was on)
function Hazards.sniperOffset(z)
	local c = (z.lo + z.hi) / 2
	local b = ctx.World and ctx.World.bounds
	local mc = b and Vector3.new((b.x0 + b.x1) / 2, 0, (b.z0 + b.z1) / 2) or Vector3.zero
	local along = math.random(-60, 60)
	if (z.hi.X - z.lo.X) < (z.hi.Z - z.lo.Z) then
		return Vector3.new(c.X > mc.X and 200 or -200, 40, along)
	end
	return Vector3.new(along, 40, c.Z > mc.Z and 200 or -200)
end
function Hazards.sniperZone(lo, hi, clear)
	table.insert(Hazards.zones, { lo = lo, hi = hi, clear = clear or {} })
end
local function inZone(pos)
	for _, z in Hazards.zones do
		if pos.X > z.lo.X and pos.X < z.hi.X and pos.Z > z.lo.Z and pos.Z < z.hi.Z and pos.Y < z.hi.Y then
			local ok = true
			for _, c in z.clear do
				if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(c.X, 0, c.Z)).Magnitude < 22 then
					ok = false
					break
				end
			end
			if ok then
				return z
			end
		end
	end
	return nil
end
local watch = {} -- [player] = { t = seconds inside, warned, nextShot }
function Hazards.sniperStep(dt)
	for player, s in ctx.Raid.sessions() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local w = watch[player]
		local zone = root and inZone(root.Position)
		if s.done or not root or not hum or hum.Health <= 0 or not zone then
			watch[player] = nil
		else
			w = w or { t = 0 }
			watch[player] = w
			w.t += dt
			local from = root.Position + Hazards.sniperOffset(zone)
			if w.t >= Hazards.WARN and not w.warned then
				w.warned = true
				ctx.Remotes.note(player, "toast", { text = "SNIPER ZONE  ·  GET BACK", tone = "warn" })
				ctx.Remotes.fx("shot", { o = from, p = root.Position + Vector3.new(1.5, 2, 0), w = "TUNDRA", ai = true })
			end
			if w.t >= Hazards.FIRST and (w.nextShot or 0) <= w.t then
				w.nextShot = w.t + Hazards.EVERY
				local part = char:FindFirstChild((math.random() < 0.4) and "Head" or "UpperTorso")
				if part then
					ctx.Remotes.fx("shot", { o = from, p = part.Position, h = true, w = "TUNDRA", ai = true })
					ctx.Combat.hitModel(char, {
						dmg = 75, pen = 55, armorDmg = 0.5, bleedL = 0.4, bleedH = 0.3, part = part, hitPos = part.Position,
						attacker = "BORDER SNIPER", from = from, weapon = "Border sniper", ammo = "7.6x54", cause = "SNIPER",
					})
				end
			end
		end
	end
end

function Hazards.init(c)
	ctx = c
end

function Hazards.start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(Hazards.sniperStep, 0.5)
			if not ok then
				warn("[ZR] snipers:", err)
			end
			local okM, errM = pcall(Hazards.mineStep)
			if not okM then
				warn("[ZR] mines:", errM)
			end
		end
	end)
end

return Hazards
