--!nonstrict
-- Map hazards (Tarkov's Customs): orange propane cylinders explode when a bullet hits them or a blast reaches them
-- (a fireball with heavy blast damage close in and a few fragments), and a burst one sets off its neighbours. Maps
-- register their cylinder spots while they build; every raid starts with all of them back in place.
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

-- a new raid: every cylinder is back
function Hazards.reset()
	for _, s in Hazards.spots do
		if not s.model then
			build(s)
		end
	end
end

-- border snipers (Tarkov): the strips along a map's edge are watched; linger there and a warning shot cracks
-- past, then the hits come (head or chest) until you leave. Spawns and extracts near the edge are left clear.
Hazards.zones = {}
Hazards.WARN, Hazards.FIRST, Hazards.EVERY = 3, 6, 2.5
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
		if s.done or not root or not hum or hum.Health <= 0 or not inZone(root.Position) then
			watch[player] = nil
		else
			w = w or { t = 0 }
			watch[player] = w
			w.t += dt
			local from = root.Position + Vector3.new(math.random(-60, 60), 40, -200)
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
		end
	end)
end

return Hazards
