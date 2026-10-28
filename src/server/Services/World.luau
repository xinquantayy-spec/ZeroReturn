--!nonstrict
-- Builds the safehouse and the Quay 7 raid map at server start (deterministic, no saved place data needed).
-- Uploaded Blender meshes (ReplicatedStorage.ZR_Assets) replace part-built fallbacks when available.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Config = require(Shared.Config)
local AssetMeta = require(Shared.AssetMeta)

local World = {}
World.spawns = {}
World.extracts = {}
World.containers = {}
World.patrols = {}
World.safehouse = {}

local root: Folder
local rng = Random.new(707)
local M = Enum.Material
local function hex(h)
	return Color3.fromHex(h)
end
local C = {
	concrete = hex("6F716C"), concreteDark = hex("575A56"), concreteLight = hex("8C8D86"), asphalt = hex("3D403F"),
	line = hex("A99A62"), rust = hex("8A6252"), rustDark = hex("5E4236"), metal = hex("5C6461"), metalDark = hex("33383B"),
	olive = hex("5E6448"), sand = hex("B1A893"), mist = hex("96A4A2"), orange = hex("C07946"), yellow = hex("C29A38"),
	pale = hex("D6DBC9"), wood = hex("6E5A44"), blue = hex("3E5868"), red = hex("7A3E33"), teal = hex("3D5A57"),
	wall = hex("666A63"), interior = hex("7D7F76"), floor = hex("4C4F4B"),
}
World.C = C

-- ── primitives ───────────────────────────────────────────────────────────────
local function part(parent, size, cf, color, mat, class)
	local p = Instance.new(class or "Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function box(parent, sx, sy, sz, x, y, z, color, mat, ry)
	local cf = CFrame.new(x, y, z)
	if ry then
		cf *= CFrame.Angles(0, math.rad(ry), 0)
	end
	return part(parent, Vector3.new(sx, sy, sz), cf, color, mat)
end
local function boxCF(parent, sx, sy, sz, cf, color, mat)
	return part(parent, Vector3.new(sx, sy, sz), cf, color, mat)
end
-- cylinder along local X; use cf rotation to orient
local function cyl(parent, length, diameter, cf, color, mat)
	local p = part(parent, Vector3.new(length, diameter, diameter), cf, color, mat)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function vcyl(parent, height, diameter, x, y, z, color, mat)
	return cyl(parent, height, diameter, CFrame.new(x, y + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)), color, mat)
end
local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
local function jitter(c, amt)
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v * (1 + rng:NextNumber(-amt, amt)), 0, 1))
end
local function light(parent, color, range, brightness, shadows)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows or false
	l.Parent = parent
	return l
end
local function sign(parent, face, text, textColor, bg)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 24
	g.LightInfluence = 1
	g.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = bg or C.metalDark
	t.BackgroundTransparency = bg and 0 or 1
	t.TextColor3 = textColor or C.pale
	t.Font = Enum.Font.RobotoMono
	t.TextScaled = true
	t.Text = text
	t.Parent = g
	return g
end

-- mesh asset or nil (ReplicatedStorage.ZR_Assets populated by the Assets service)
local function mesh(key, parent, bottomCF, color)
	local lib = ReplicatedStorage:FindFirstChild("ZR_Assets")
	local src = lib and lib:FindFirstChild(key)
	if not src then
		return nil
	end
	local m = src:Clone()
	m.Anchored = true
	m.CFrame = bottomCF * CFrame.new(AssetMeta[key] or Vector3.new(0, m.Size.Y / 2, 0))
	if color then
		m.Color = color
	end
	m.Parent = parent
	return m
end

-- wall along local X with door openings {center offset, width, height}
local function wall(parent, cf, length, height, thick, color, mat, openings)
	openings = openings or {}
	table.sort(openings, function(a, b)
		return a[1] < b[1]
	end)
	local x = -length / 2
	for _, o in openings do
		local left = o[1] - o[2] / 2
		if left > x then
			boxCF(parent, left - x, height, thick, cf * CFrame.new((x + left) / 2, height / 2, 0), color, mat)
		end
		boxCF(parent, o[2], height - o[3], thick, cf * CFrame.new(o[1], o[3] + (height - o[3]) / 2, 0), color, mat)
		x = o[1] + o[2] / 2
	end
	if x < length / 2 then
		boxCF(parent, length / 2 - x, height, thick, cf * CFrame.new((x + length / 2) / 2, height / 2, 0), color, mat)
	end
end

-- ── props (mesh first, part fallback) ─────────────────────────────────────────
local Props = {}
function Props.container(parent, cf, color, open)
	if mesh(open and "ZR_ENV_Container20_Open" or "ZR_ENV_Container20", parent, cf, color) then
		return
	end
	local m = model("Container", parent)
	local body = boxCF(m, 22, 9.4, 8.8, cf * CFrame.new(0, 4.7, 0), color, M.CorrodedMetal)
	for i = -3, 3 do
		boxCF(m, 0.5, 8.6, 9.2, cf * CFrame.new(i * 3, 4.7, 0), jitter(color, 0.08), M.Metal)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			boxCF(m, 0.9, 9.6, 0.9, cf * CFrame.new(sx * 10.7, 4.8, sz * 4.2), C.metalDark, M.Metal)
		end
	end
	boxCF(m, 0.4, 8, 8, cf * CFrame.new(11.1, 4.6, 0), jitter(color, 0.12), M.Metal)
	for _, z in { -2.2, 2.2 } do
		boxCF(m, 0.3, 7.6, 0.25, cf * CFrame.new(11.35, 4.6, z), C.metalDark, M.Metal)
	end
	body.Name = "Body"
end
function Props.crate(parent, cf)
	if mesh("ZR_PROP_Crate", parent, cf) then
		return
	end
	boxCF(parent, 4, 4, 4, cf * CFrame.new(0, 2, 0), C.wood, M.WoodPlanks)
end
function Props.barrel(parent, cf, color)
	if mesh("ZR_PROP_Barrel", parent, cf, color) then
		return
	end
	vcyl(parent, 4.4, 3.2, cf.X, cf.Y, cf.Z, color or C.blue, M.Metal)
	vcyl(parent, 0.2, 3.35, cf.X, cf.Y + 1.4, cf.Z, C.metalDark, M.Metal)
	vcyl(parent, 0.2, 3.35, cf.X, cf.Y + 3, cf.Z, C.metalDark, M.Metal)
end
function Props.pallet(parent, cf)
	if mesh("ZR_PROP_Pallet", parent, cf) then
		return
	end
	boxCF(parent, 5, 0.6, 4.2, cf * CFrame.new(0, 0.3, 0), C.wood, M.WoodPlanks)
end
function Props.barrier(parent, cf)
	if mesh("ZR_PROP_Barrier", parent, cf) then
		return
	end
	boxCF(parent, 8, 1.4, 2.4, cf * CFrame.new(0, 0.7, 0), C.concreteLight, M.Concrete)
	boxCF(parent, 8, 2, 1.2, cf * CFrame.new(0, 2.4, 0), C.concreteLight, M.Concrete)
end
function Props.lamp(parent, cf)
	if not mesh("ZR_PROP_LightPole", parent, cf) then
		vcyl(parent, 18, 0.6, cf.X, cf.Y, cf.Z, C.metalDark, M.Metal)
		boxCF(parent, 3, 0.4, 0.8, cf * CFrame.new(1.2, 18, 0), C.metalDark, M.Metal)
	end
	local head = boxCF(parent, 1.2, 0.3, 0.8, cf * CFrame.new(2.4, 17.7, 0), hex("FFD9A0"), M.Neon)
	head.CastShadow = false
	light(head, hex("FFC98A"), 26, 1.1, false)
end
function Props.bollard(parent, cf)
	vcyl(parent, 1.6, 1.4, cf.X, cf.Y, cf.Z, C.metalDark, M.Metal)
	vcyl(parent, 0.4, 2, cf.X, cf.Y + 1.6, cf.Z, C.metalDark, M.Metal)
end

-- ── lighting / atmosphere ─────────────────────────────────────────────────────
local function setupLighting()
	Lighting.ClockTime = 7.3
	Lighting.GeographicLatitude = 52
	Lighting.Brightness = 1.7
	Lighting.Ambient = hex("3A3F40")
	Lighting.OutdoorAmbient = hex("7A8382")
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.45
	Lighting.ExposureCompensation = 0.1
	Lighting:SetAttribute("BaseExposure", 0.1) -- clients run auto-exposure around this
	for _, c in Lighting:GetChildren() do
		if c:IsA("Atmosphere") or c:IsA("PostEffect") or c:IsA("Sky") or c:IsA("Clouds") then
			c:Destroy()
		end
	end
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.46
	atm.Offset = 0.18
	atm.Color = hex("A9B4B1")
	atm.Decay = hex("5D6A69")
	atm.Glare = 0
	atm.Haze = 2.4
	atm.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ZR_Grade"
	cc.Saturation = -0.22
	cc.Contrast = 0.08
	cc.Brightness = 0.01
	cc.TintColor = hex("ECEFE8")
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.25
	bloom.Size = 18
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local terrain = workspace.Terrain
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.86
	clouds.Density = 0.62
	clouds.Color = hex("C7CDCB")
	clouds.Parent = terrain
	terrain.WaterColor = hex("2C4245")
	terrain.WaterTransparency = 0.12
	terrain.WaterReflectance = 0.45
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6
	terrain:FillBlock(CFrame.new(0, -24, 0), Vector3.new(1600, 36, 1600), M.Water)
end

-- ── safehouse ─────────────────────────────────────────────────────────────────
local function buildSafehouse()
	local f = model("Safehouse", root)
	local o = Config.SAFEHOUSE_ORIGIN
	local function b(sx, sy, sz, x, y, z, col, mat)
		return box(f, sx, sy, sz, o.X + x, o.Y + y, o.Z + z, col, mat)
	end
	b(44, 2, 34, 0, -1, 0, C.floor, M.Concrete)
	b(44, 1, 34, 0, 12.5, 0, C.concreteDark, M.Concrete)
	b(1, 12, 34, -22, 6, 0, C.interior, M.Plaster)
	b(1, 12, 34, 22, 6, 0, C.interior, M.Plaster)
	b(44, 12, 1, 0, 6, -17, C.interior, M.Plaster)
	b(44, 12, 1, 0, 6, 17, C.interior, M.Plaster)
	-- wainscot band + pipes
	b(43.6, 3.2, 0.3, 0, 1.6, -16.4, C.olive, M.SmoothPlastic)
	b(43.6, 3.2, 0.3, 0, 1.6, 16.4, C.olive, M.SmoothPlastic)
	cyl(f, 43, 0.7, CFrame.new(o.X, o.Y + 11, o.Z - 16), C.rust, M.Metal)
	cyl(f, 43, 0.5, CFrame.new(o.X, o.Y + 10.2, o.Z - 16.1), C.metal, M.Metal)
	for _, x in { -11, 11 } do
		local lampPart = b(4, 0.3, 1.2, x, 11.8, 0, hex("FFE3B3"), M.Neon)
		lampPart.CastShadow = false
		light(lampPart, hex("FFCF94"), 30, 1.3, true)
	end
	-- stash lockers (north wall)
	local stash = model("StashLockers", f)
	for i = 0, 3 do
		b(3, 8, 2.4, -16 + i * 3.1, 4, -15.4, C.olive, M.Metal)
		b(0.2, 0.9, 0.1, -15 + i * 3.1, 4.4, -14.15, C.metalDark, M.Metal)
	end
	local stashAnchor = b(12, 8, 1, -11.35, 4, -14.3, C.olive, M.Metal)
	stashAnchor.Transparency = 1
	stashAnchor.CanCollide = false
	stashAnchor.Name = "StashPrompt"
	stashAnchor.Parent = stash
	-- deploy map table
	local tbl = model("DeployTable", f)
	b(10, 0.4, 6, 8, 3.4, 2, C.wood, M.WoodPlanks).Parent = tbl
	for _, sx in { -4.5, 4.5 } do
		for _, sz in { -2.5, 2.5 } do
			b(0.4, 3.2, 0.4, 8 + sx, 1.6, 2 + sz, C.metalDark, M.Metal).Parent = tbl
		end
	end
	local mapSheet = b(8.6, 0.05, 4.8, 8, 3.63, 2, hex("C9C2A8"), M.SmoothPlastic)
	mapSheet.Parent = tbl
	sign(mapSheet, Enum.NormalId.Top, "QUAY 7 // EXCLUSION ZONE\nHARBOR STACK · PUMP ANNEX · FREIGHT DEPOT", hex("3A3A34"))
	local deployAnchor = b(10, 3, 6, 8, 4.5, 2, C.pale, M.SmoothPlastic)
	deployAnchor.Transparency = 1
	deployAnchor.CanCollide = false
	deployAnchor.Name = "DeployPrompt"
	deployAnchor.Parent = tbl
	-- radio desk + cot + shelving + posters
	b(6, 0.3, 3, 17, 3, -12, C.wood, M.WoodPlanks)
	b(2.2, 1.6, 1.6, 17, 4, -12, C.metalDark, M.Metal)
	b(7, 1.2, 3.4, -15, 1, 12, C.olive, M.Fabric)
	b(1, 7, 6, 21, 3.5, 8, C.metal, M.Metal)
	for k = 0, 2 do
		b(1.2, 0.2, 5.6, 21, 1.6 + k * 2.2, 8, C.metalDark, M.Metal)
	end
	local poster = b(5, 3.4, 0.1, 0, 7.5, 16.3, hex("BDB59C"), M.SmoothPlastic)
	sign(poster, Enum.NormalId.Front, "RELAY 7 SAFEHOUSE\nREPORT ALL EXFIL TIMES", hex("3A3A34"))
	World.safehouse = {
		spawn = CFrame.new(o + Vector3.new(-6, 3.2, 8)) * CFrame.Angles(0, math.rad(-120), 0),
		stash = stashAnchor,
		deploy = deployAnchor,
		center = o,
	}
	for _, spec in { { stashAnchor, "Open stash", "Stash lockers", "stash" }, { deployAnchor, "Plan deployment", "Quay 7 map", "deploy" } } do
		local pp = Instance.new("ProximityPrompt")
		pp.KeyboardKeyCode = Enum.KeyCode.F -- Tarkov interact key (Q/E lean)
		pp.ActionText = spec[2]
		pp.ObjectText = spec[3]
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 9
		pp.RequiresLineOfSight = false
		pp.Style = Enum.ProximityPromptStyle.Custom
		pp:SetAttribute("Screen", spec[4])
		pp.Parent = spec[1]
	end
end

-- ── Quay 7 ────────────────────────────────────────────────────────────────────
local function addContainerSpot(parent, id, kind, label, cf)
	local anchor
	if kind == "locker" then
		anchor = boxCF(parent, 3, 7, 2.2, cf * CFrame.new(0, 3.5, 0), C.olive, M.Metal)
		boxCF(parent, 0.15, 0.8, 0.1, cf * CFrame.new(0.9, 3.8, -1.12), C.metalDark, M.Metal)
	elseif kind == "drawer" then
		anchor = boxCF(parent, 5, 3, 2.6, cf * CFrame.new(0, 1.5, 0), C.metal, M.Metal)
		for k = 0, 2 do
			boxCF(parent, 4.4, 0.7, 0.1, cf * CFrame.new(0, 0.6 + k * 0.9, -1.33), C.metalDark, M.Metal)
		end
	else
		local m = mesh("ZR_PROP_Crate", parent, cf)
		anchor = m or boxCF(parent, 4, 4, 4, cf * CFrame.new(0, 2, 0), C.wood, M.WoodPlanks)
		boxCF(parent, 2.2, 0.15, 1.2, cf * CFrame.new(0, 4.08, 0), C.orange, M.SmoothPlastic)
	end
	anchor.Name = "Loot_" .. id
	local pp = Instance.new("ProximityPrompt")
	pp.KeyboardKeyCode = Enum.KeyCode.F -- Tarkov interact key (Q/E lean)
	pp.ActionText = "Search"
	pp.ObjectText = label
	pp.HoldDuration = 0
	pp.MaxActivationDistance = Config.INTERACT_RANGE - 1
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.Parent = anchor
	CollectionService:AddTag(anchor, "ZR_Container")
	table.insert(World.containers, { id = id, kind = kind, label = label, part = anchor, prompt = pp })
end

local function addExtract(parent, id, name, pos, size, rule)
	local m = model("Exfil_" .. id, parent)
	-- beacon: pole + radio box + light + sign
	local px, pz = pos.X + size.X / 2 - 1.5, pos.Z - size.Z / 2 + 1.5
	vcyl(m, 9, 0.5, px, 0, pz, C.metalDark, M.Metal)
	local radio = box(m, 1.6, 1.2, 1, px, 6.4, pz, C.olive, M.Metal)
	local lamp = box(m, 0.7, 0.7, 0.7, px, 9.3, pz, C.orange, M.Neon)
	lamp.CastShadow = false
	lamp.Name = "BeaconLamp"
	light(lamp, C.orange, 18, 1.2, false)
	local plate = box(m, 5, 1.4, 0.2, px, 4.4, pz - 0.4, C.metalDark, M.Metal)
	sign(plate, Enum.NormalId.Front, "EXFIL " .. id .. " — " .. name, C.orange)
	sign(plate, Enum.NormalId.Back, "EXFIL " .. id .. " — " .. name, C.orange)
	radio.Name = "Radio"
	local zone = box(root.Triggers, size.X, size.Y, size.Z, pos.X, size.Y / 2, pos.Z, C.orange, M.ForceField)
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.Name = "ExfilZone_" .. id
	-- painted ground marking (thin, no collision)
	local mark = box(m, size.X, 0.06, size.Z, pos.X, 0.04, pos.Z, C.orange, M.SmoothPlastic)
	mark.Transparency = 0.82
	mark.CanCollide = false
	mark.CanQuery = false
	World.extracts[id] = { id = id, name = name, cf = zone.CFrame, size = size, pos = pos, beacon = lamp, rule = rule or { kind = "open" } }
end

local function buildGround(map)
	-- quay slabs 50x50 (top at y = 0)
	for i = -4, 3 do
		for j = -4, 3 do
			box(map, 50, 8, 50, i * 50 + 25, -4, j * 50 + 25, jitter(C.concrete, 0.05), M.Concrete)
		end
	end
	-- roads
	box(map, 384, 0.12, 22, -8, 0.06, 0, C.asphalt, M.Asphalt)
	box(map, 22, 0.12, 400, 20, 0.07, 0, C.asphalt, M.Asphalt)
	for x = -190, 170, 16 do
		if math.abs(x - 20) > 14 then
			box(map, 7, 0.14, 0.5, x, 0.08, 0, C.line, M.SmoothPlastic)
		end
	end
	-- quay edge (east + south) with curb, bollards and fenders
	box(map, 2, 1.2, 341, 199, 0.6, -29.5, C.concreteLight, M.Concrete)
	box(map, 2, 1.2, 41, 199, 0.6, 179.5, C.concreteLight, M.Concrete)
	box(map, 400, 1.2, 2, 0, 0.6, 199, C.concreteLight, M.Concrete)
	for k = -180, 180, 30 do
		if math.abs(k - 150) > 14 then
			Props.bollard(map, CFrame.new(196, 0, k))
			cyl(map, 2.4, 2.6, CFrame.new(200.6, -2, k + 12) * CFrame.Angles(0, 0, math.rad(90)), C.metalDark, M.Rubber)
		end
		Props.bollard(map, CFrame.new(k, 0, 196))
	end
	-- exclusion wall (north + west) with cap and wire posts
	for _, w in { { CFrame.new(0, 0, -201), 404, { { -180, 14, 12 }, { 184, 12, 11 } } }, { CFrame.new(-201, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 404, { { -10, 14, 12 } } } } do
		wall(map, w[1], w[2], 14, 2, C.concreteDark, M.Concrete, w[3])
		boxCF(map, w[2], 0.8, 2.6, w[1] * CFrame.new(0, 14.4, 0), C.concreteLight, M.Concrete)
		for k = -w[2] / 2 + 6, w[2] / 2 - 6, 12 do
			boxCF(map, 0.25, 3, 0.25, w[1] * CFrame.new(k, 16.3, 0), C.metalDark, M.Metal)
		end
	end
	-- distant skyline silhouettes (fog-soft, no collision)
	for k = 1, 10 do
		local sx, sz = rng:NextNumber(30, 70), rng:NextNumber(30, 70)
		local h = rng:NextNumber(20, 60)
		local onNorth = k <= 5
		local x = onNorth and rng:NextNumber(-260, 260) or rng:NextNumber(-420, -280)
		local z = onNorth and rng:NextNumber(-420, -280) or rng:NextNumber(-260, 260)
		local s = box(map, sx, h, sz, x, h / 2, z, jitter(C.concreteDark, 0.1), M.Concrete)
		s.CanCollide = false
		s.CastShadow = false
	end
	box(map, 760, 2, 280, 40, -1, -344, C.concreteDark, M.Concrete).CanCollide = false
	box(map, 280, 2, 480, -344, -1, -40, C.concreteDark, M.Concrete).CanCollide = false
	-- invisible play boundary
	for _, b in { { 24, -206, 470, 4 }, { 24, 212, 470, 4 }, { -206, 3, 4, 430 }, { 254, 3, 4, 430 } } do
		local inv = box(map, b[3], 120, b[4], b[1], 50, b[2], C.pale, M.SmoothPlastic)
		inv.Transparency = 1
		inv.CanQuery = false
		inv.Name = "Boundary"
	end
end

local function buildHarborStack(map)
	local hs = model("HarborStack", map)
	local colors = { C.rust, C.blue, C.olive, C.teal, C.red, C.metal, C.orange }
	local blocks = { -158, -126, -94, -62 }
	for _, bz in blocks do
		for sub = 0, 1 do
			local z = bz + sub * 9.2
			for _, x in { -160, -137, -114, -78, -55 } do
				if rng:NextNumber() > 0.12 then
					local col = jitter(colors[rng:NextInteger(1, #colors)], 0.06)
					Props.container(hs, CFrame.new(x, 0, z) * CFrame.Angles(0, (rng:NextNumber() > 0.5) and math.pi or 0, 0), col)
					if rng:NextNumber() > 0.55 then
						local col2 = jitter(colors[rng:NextInteger(1, #colors)], 0.06)
						Props.container(hs, CFrame.new(x + rng:NextNumber(-0.6, 0.6), 9.4, z), col2)
					end
				end
			end
		end
	end
	-- yellow gantry crane landmark straddling the cross alley
	local g = model("Gantry", hs)
	for _, lx in { -101, -91 } do
		for _, lz in { -137, -73 } do
			box(g, 2, 42, 2, lx, 21, lz, C.yellow, M.Metal)
		end
		box(g, 2.4, 3, 68, lx, 43.5, -105, C.yellow, M.Metal)
	end
	box(g, 12.4, 3, 3, -96, 43.5, -137, C.yellow, M.Metal)
	box(g, 12.4, 3, 3, -96, 43.5, -73, C.yellow, M.Metal)
	box(g, 7, 6, 6, -96, 39, -100, hex("B98C34"), M.Metal)
	cyl(g, 22, 0.3, CFrame.new(-96, 27, -105) * CFrame.Angles(0, 0, math.rad(90)), C.metalDark, M.Metal)
	box(g, 5, 1.2, 9, -96, 16, -105, C.metalDark, M.Metal)
	-- pallets/barrels in alleys for cover
	for _, p in { { -125, -140 }, { -66, -140 }, { -146, -108 }, { -102, -76 }, { -40, -108 } } do
		Props.pallet(hs, CFrame.new(p[1], 0, p[2]) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
		Props.barrel(hs, CFrame.new(p[1] + 3, 0, p[2] + 2), jitter(C.blue, 0.1))
	end
	addContainerSpot(hs, "HS1", "crate", "Supply crate", CFrame.new(-96, 0, -110) * CFrame.Angles(0, 0.3, 0))
	addContainerSpot(hs, "HS2", "locker", "Dock worker locker", CFrame.new(-36, 0, -142) * CFrame.Angles(0, math.rad(-90), 0))
	World.patrols.HS = { Vector3.new(-96, 0, -140), Vector3.new(-40, 0, -140), Vector3.new(-40, 0, -76), Vector3.new(-96, 0, -76), Vector3.new(-150, 0, -108), Vector3.new(-96, 0, -108) }
end

local function buildPumpAnnex(map)
	local pa = model("PumpAnnex", map)
	local x0, x1, z0, z1, H = 40, 120, 55, 115, 22
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	box(pa, x1 - x0, 0.4, z1 - z0, cx, 0.2, cz, C.floor, M.Concrete)
	wall(pa, CFrame.new(cx, 0, z0), x1 - x0, H, 1.5, C.wall, M.Concrete, { { 70 - cx, 10, 11 } })
	wall(pa, CFrame.new(cx, 0, z1), x1 - x0, H, 1.5, C.wall, M.Concrete, {})
	wall(pa, CFrame.new(x0, 0, cz) * CFrame.Angles(0, math.rad(90), 0), z1 - z0, H, 1.5, C.wall, M.Concrete, { { -(85 - cz), 9, 10 } })
	wall(pa, CFrame.new(x1, 0, cz) * CFrame.Angles(0, math.rad(90), 0), z1 - z0, H, 1.5, C.wall, M.Concrete, { { -(100 - cz), 9, 10 } })
	-- roof with skylight gap
	box(pa, x1 - x0 + 2, 1, 26, cx, H + 0.5, z0 + 13, C.concreteDark, M.Concrete)
	box(pa, x1 - x0 + 2, 1, 26, cx, H + 0.5, z1 - 13, C.concreteDark, M.Concrete)
	for k = x0 + 6, x1 - 6, 12 do
		box(pa, 0.8, 0.8, 9, k, H + 0.4, cz, C.metalDark, M.Metal)
	end
	-- pumps (turbine room)
	for i, px in { 58, 80, 102 } do
		box(pa, 9, 2.4, 9, px, 1.2, 76, C.concreteLight, M.Concrete)
		local col = (i == 2) and C.teal or C.olive
		cyl(pa, 12, 7, CFrame.new(px, 6, 76) * CFrame.Angles(0, math.rad(90), 0), col, M.Metal)
		vcyl(pa, 10, 2, px, 6, 70, C.metal, M.Metal)
		cyl(pa, 18, 1.6, CFrame.new(px, 16, 70 - 2) * CFrame.Angles(0, math.rad(90), 0), C.rust, M.Metal)
	end
	cyl(pa, 78, 1.6, CFrame.new(cx, 17.5, 61), C.rust, M.Metal)
	-- mezzanine along south wall with stairs on the west side
	local mzY = 10
	box(pa, 78, 0.8, 14.5, 80, mzY - 0.4, 106.75, C.metal, M.DiamondPlate) -- x 41..119, z 99.5..114
	box(pa, 68, 3, 0.3, 85, mzY + 1.5, 99.6, C.metalDark, M.Metal) -- rail leaves the stair landing open
	for k = 0, 9 do
		box(pa, 6, 1, 1.9, 46, k + 0.5, 81 + k * 1.9, C.metal, M.DiamondPlate)
	end
	box(pa, 6, mzY - 0.8, 1, 46, (mzY - 0.8) / 2, 100.2, C.metalDark, M.Metal)
	local booth = box(pa, 10, 7, 8, 104, mzY + 3.5, 109, C.olive, M.Metal)
	booth.Name = "ControlBooth"
	local ctrlLamp = box(pa, 0.6, 0.6, 0.6, 104, mzY + 5, 104.6, C.orange, M.Neon)
	light(ctrlLamp, C.orange, 22, 1.6, true)
	addContainerSpot(pa, "PA1", "locker", "Maintenance locker", CFrame.new(64, mzY, 111) * CFrame.Angles(0, math.rad(180), 0))
	addContainerSpot(pa, "PA2", "crate", "Valve parts crate", CFrame.new(100, 0.4, 92))
	-- chimney landmark (striped)
	for k = 0, 9 do
		vcyl(pa, 6, 8, 116, k * 6, 50, (k % 2 == 0) and C.pale or C.rust, M.Concrete)
	end
	for _, p in { { 34, 70 }, { 34, 74 }, { 126, 66 } } do
		Props.barrel(pa, CFrame.new(p[1], 0, p[2]), jitter(C.rust, 0.1))
	end
	Props.barrier(pa, CFrame.new(30, 0, 92) * CFrame.Angles(0, math.rad(90), 0))
	World.patrols.PA = { Vector3.new(30, 0, 85), Vector3.new(60, 0.4, 88), Vector3.new(96, 0.4, 92), Vector3.new(126, 0, 100), Vector3.new(126, 0, 48), Vector3.new(70, 0, 48) }
end

local function buildFreightDepot(map)
	local fd = model("FreightDepot", map)
	local x0, x1, z0, z1, H, F = 50, 150, -160, -100, 24, 4
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	box(fd, x1 - x0, F, (z1 - z0) + 12, cx, F / 2, (z0 + z1 + 12) / 2, C.concreteDark, M.Concrete)
	box(fd, x1 - x0, 0.6, 1, cx, F + 0.3, z1 + 11.5, C.yellow, M.SmoothPlastic)
	local wallC = hex("6F7468")
	wall(fd, CFrame.new(cx, F, z1), x1 - x0, H, 1, wallC, M.CorrodedMetal, { { 70 - cx, 12, 14 }, { 100 - cx, 12, 14 }, { 130 - cx, 12, 14 } })
	wall(fd, CFrame.new(cx, F, z0), x1 - x0, H, 1, wallC, M.CorrodedMetal, {})
	wall(fd, CFrame.new(x0, F, cz) * CFrame.Angles(0, math.rad(90), 0), z1 - z0, H, 1, wallC, M.CorrodedMetal, { { -(-130 - cz), 8, 10 } })
	wall(fd, CFrame.new(x1, F, cz) * CFrame.Angles(0, math.rad(90), 0), z1 - z0, H, 1, wallC, M.CorrodedMetal, {})
	-- pitched roof
	for _, s in { -1, 1 } do
		local roofPart = boxCF(fd, x1 - x0 + 2, 1, 33, CFrame.new(cx, F + H + 3, cz + s * 15) * CFrame.Angles(math.rad(s * 11), 0, 0), C.metal, M.CorrodedMetal)
		roofPart.Name = "Roof"
	end
	-- roll-up doors (half open) and dock bumpers
	for _, dx in { 70, 100, 130 } do
		box(fd, 12, 5, 0.4, dx, F + 11.5, z1 + 0.2, C.metalDark, M.CorrodedMetal)
		box(fd, 1, 1.4, 0.8, dx - 5, 3, z1 + 12.2, C.metalDark, M.Rubber)
		box(fd, 1, 1.4, 0.8, dx + 5, 3, z1 + 12.2, C.metalDark, M.Rubber)
	end
	-- ramps (west end of dock, west door)
	local function ramp(x, z, length, width, ry)
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.Size = Vector3.new(width, F, length)
		w.CFrame = CFrame.new(x, F / 2, z) * CFrame.Angles(0, math.rad(ry), 0)
		w.Color = C.concreteLight
		w.Material = M.Concrete
		w.Parent = fd
	end
	ramp(x0 - 6, -94, 12, 12, 90)
	ramp(x0 - 6, -130, 12, 8, 90)
	ramp(x1 + 6, -94, 12, 12, -90)
	-- interior racks
	for _, rz in { -150, -138 } do
		for rx = 60, 108, 16 do
			local rack = model("Rack", fd)
			for _, sx in { -7, 7 } do
				for _, sz in { -2, 2 } do
					box(rack, 0.4, 14, 0.4, rx + sx, F + 7, rz + sz, C.orange, M.Metal)
				end
			end
			for k = 0, 2 do
				box(rack, 14.4, 0.3, 4.4, rx, F + 1 + k * 5, rz, C.metalDark, M.Metal)
				if rng:NextNumber() > 0.35 then
					Props.crate(rack, CFrame.new(rx + rng:NextNumber(-4, 4), F + 1.15 + k * 5, rz))
				end
			end
		end
	end
	-- office
	local off = model("Office", fd)
	wall(off, CFrame.new(136, F, -138), 26, 10, 0.6, C.interior, M.Plaster, { { -6, 4, 7.5 } })
	wall(off, CFrame.new(123, F, -149) * CFrame.Angles(0, math.rad(90), 0), 22, 10, 0.6, C.interior, M.Plaster, {})
	box(off, 26, 0.5, 22, 136, F + 10.25, -149, C.concreteLight, M.Plaster)
	local olamp = box(off, 3, 0.2, 1, 136, F + 9.9, -149, hex("FFE6BF"), M.Neon)
	light(olamp, hex("FFD7A6"), 16, 1, false)
	addContainerSpot(off, "FD1", "drawer", "Office cabinet", CFrame.new(142, F, -156))
	addContainerSpot(fd, "FD2", "crate", "Freight crate", CFrame.new(84, F, -93))
	for _, p in { { 110, -92 }, { 116, -93 }, { 58, -120 } } do
		Props.pallet(fd, CFrame.new(p[1], F, p[2]))
	end
	World.patrols.FD = { Vector3.new(36, 0, -94), Vector3.new(62, F, -94), Vector3.new(138, F, -94), Vector3.new(130, F, -112), Vector3.new(90, F, -126), Vector3.new(58, F, -130), Vector3.new(36, 0, -130) }
end

local function buildLandmarksAndRoutes(map)
	local misc = model("Quay", map)
	-- striped water tower (SW)
	local wt = model("WaterTower", misc)
	for _, sx in { -6, 6 } do
		for _, sz in { -6, 6 } do
			box(wt, 1.2, 32, 1.2, -130 + sx, 16, 120 + sz, C.metalDark, M.Metal)
		end
	end
	for k = 0, 3 do
		vcyl(wt, 3.5, 18, -130, 32 + k * 3.5, 120, (k % 2 == 0) and C.orange or C.pale, M.Metal)
	end
	vcyl(wt, 1, 19, -130, 46, 120, C.metalDark, M.Metal)
	-- west spawn: ferry service tunnel mouth in the west wall
	local tun = model("FerryTunnel", misc)
	box(tun, 14, 2, 20, -207, 13, 10, C.concreteDark, M.Concrete)
	box(tun, 14, 8, 22, -207, -4, 10, C.concreteDark, M.Concrete)
	box(tun, 14, 14, 2, -207, 7, -1, C.concreteDark, M.Concrete)
	box(tun, 14, 14, 2, -207, 7, 21, C.concreteDark, M.Concrete)
	box(tun, 6, 14, 22, -213, 7, 10, C.concreteDark, M.Concrete)
	local tl = box(tun, 0.4, 0.4, 3, -201, 11.6, 10, hex("FFD9A0"), M.Neon)
	light(tl, hex("FFC98A"), 18, 0.9, false)
	-- south spawn shelter
	local sh = model("Shelter", misc)
	box(sh, 12, 0.6, 6, -50, 8.3, 192, C.metal, M.CorrodedMetal)
	for _, sx in { -5.5, 5.5 } do
		box(sh, 0.5, 8, 0.5, -50 + sx, 4, 194.5, C.metalDark, M.Metal)
	end
	-- pier 3 + boat (exfil B)
	local pier = model("Pier3", misc)
	box(pier, 50, 1.2, 16, 226, -0.6, 150, C.wood, M.WoodPlanks)
	for px = 206, 246, 10 do
		for _, pz in { 143, 157 } do
			vcyl(pier, 14, 1.2, px, -14, pz, C.rustDark, M.Wood)
		end
	end
	box(pier, 18, 3, 7, 244, -1.8, 162, C.pale, M.SmoothPlastic)
	box(pier, 8, 2.4, 5, 240, 0.9, 162, C.metal, M.Metal)
	-- relay gate (exfil A) tower
	local relay = model("RelayTower", misc)
	for _, sx in { -2, 2 } do
		for _, sz in { -2, 2 } do
			box(relay, 0.5, 52, 0.5, 190 + sx, 26, -190 + sz, C.metalDark, M.Metal)
		end
	end
	for k = 1, 8 do
		box(relay, 4.5, 0.3, 4.5, 190, k * 6, -190, C.metalDark, M.Metal)
	end
	local rl = box(relay, 1, 1, 1, 190, 52.5, -190, hex("D0583F"), M.Neon)
	rl.Name = "BeaconLamp"
	-- rail cut (exfil C)
	local rail = model("RailCut", misc)
	for _, rx in { -184, -176 } do
		box(rail, 0.6, 0.5, 60, rx, 0.25, -175, C.rustDark, M.Metal)
	end
	for rz = -200, -150, 4 do
		box(rail, 10, 0.3, 1.2, -180, 0.15, rz, C.wood, M.Wood)
	end
	-- scattered cover along routes
	local cover = {
		{ "barrier", -150, 40, 0 }, { "barrier", -120, 30, 90 }, { "barrier", -60, 20, 0 }, { "barrier", -20, -30, 90 },
		{ "barrier", 60, 20, 0 }, { "barrier", 150, 10, 90 }, { "barrier", 160, -50, 0 }, { "barrier", -10, 120, 90 },
		{ "barrel", -80, 150, 0 }, { "barrel", -76, 152, 0 }, { "barrel", 170, 120, 0 }, { "barrel", 30, -60, 0 },
		{ "crate", -158, 60, 20 }, { "crate", 0, 70, 0 }, { "crate", 150, -40, 45 }, { "crate", -30, -175, 0 },
		{ "pallet", -100, 60, 0 }, { "pallet", 120, 30, 30 },
	}
	for _, c in cover do
		local cf = CFrame.new(c[2], 0, c[3]) * CFrame.Angles(0, math.rad(c[4]), 0)
		if c[1] == "barrier" then
			Props.barrier(misc, cf)
		elseif c[1] == "barrel" then
			Props.barrel(misc, cf, jitter(C.blue, 0.1))
		elseif c[1] == "crate" then
			Props.crate(misc, cf)
		else
			Props.pallet(misc, cf)
		end
	end
	-- a few loose containers in the south yard
	Props.container(misc, CFrame.new(-90, 0, 60) * CFrame.Angles(0, math.rad(90), 0), C.blue)
	Props.container(misc, CFrame.new(-30, 0, 150), C.rust)
	Props.container(misc, CFrame.new(90, 0, 160) * CFrame.Angles(0, math.rad(20), 0), C.olive)
	Props.container(misc, CFrame.new(150, 0, -20) * CFrame.Angles(0, math.rad(90), 0), C.teal)
	for _, lp in { { -150, 14 }, { -60, 14 }, { 34, 30 }, { 34, -60 }, { 120, 14 }, { 34, 150 }, { 180, -120 } } do
		Props.lamp(misc, CFrame.new(lp[1], 0, lp[2]))
	end
end

function World.build()
	for _, n in { "Baseplate", "SpawnLocation" } do
		local inst = workspace:FindFirstChild(n)
		if inst and inst:IsA("BasePart") then
			inst:Destroy()
		end
	end
	local old = workspace:FindFirstChild("ZR_World")
	if old then
		old:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "ZR_World"
	local trig = Instance.new("Folder")
	trig.Name = "Triggers"
	trig.Parent = root
	setupLighting()
	buildSafehouse()
	local map = model("Quay7", root)
	buildGround(map)
	buildHarborStack(map)
	buildPumpAnnex(map)
	buildFreightDepot(map)
	buildLandmarksAndRoutes(map)
	-- extract rules (Tarkov): open, paid (MK on exit), key (carry the key), chance (rolled per raid), scav-only
	addExtract(map, "A", "RELAY GATE", Vector3.new(184, 0, -184), Vector3.new(18, 12, 16), { kind = "open" })
	addExtract(map, "B", "PIER 3 BOAT", Vector3.new(236, 0, 150), Vector3.new(16, 12, 14), { kind = "paid", cost = 8000 })
	addExtract(map, "C", "RAIL CUT", Vector3.new(-180, 0, -188), Vector3.new(16, 12, 14), { kind = "open" })
	addExtract(map, "D", "STORM CULVERT", Vector3.new(-186, 0, 132), Vector3.new(12, 10, 12), { kind = "scav" })
	addExtract(map, "E", "SERVICE SHAFT", Vector3.new(92, 0, -186), Vector3.new(12, 10, 12), { kind = "key", key = "KEY_OFFICE" })
	addExtract(map, "F", "CRANE YARD LIFT", Vector3.new(-122, 0, 184), Vector3.new(14, 12, 12), { kind = "chance", chance = 0.6 })
	-- PMC spawns per side; each side exits on the far side of the quay (scavs may use every extract)
	local function sp(id, name, x, z, yaw, side)
		return { id = id, name = name, cf = CFrame.new(x, 3.4, z) * CFrame.Angles(0, math.rad(yaw), 0), side = side }
	end
	World.spawns = {
		sp("W1", "FERRY TUNNEL", -190, 10, -90, "west"), sp("W2", "WEST FENCE", -188, -110, -90, "west"), sp("W3", "PUMP LANE", -186, 80, -90, "west"),
		sp("S1", "SOUTH YARD", -50, 186, 0, "south"), sp("S2", "COLD STORE", 60, 184, 0, "south"), sp("S3", "BERTH 9", 150, 182, 20, "south"),
		sp("E1", "EAST APRON", 186, -70, 90, "east"), sp("E2", "BOLLARD ROW", 184, 40, 90, "east"),
		sp("N1", "NORTH LOT", 0, -188, 180, "north"), sp("N2", "SCRAP GATE", -100, -186, 180, "north"),
	}
	World.sideExtracts = {
		west = { "A", "B", "E", "F" }, south = { "A", "C", "E" }, east = { "C", "F", "E" }, north = { "B", "F", "C" },
	}
	for _, s in World.spawns do
		s.extracts = World.sideExtracts[s.side]
	end
	-- AI (M8): scav wander/spawn points around the points of interest, Harbor Watch posts, the Foreman's depot
	local function v(x, y, z)
		return Vector3.new(x, y, z)
	end
	World.scavZones = {
		-- Harbor Stack alleys
		v(-96, 0, -140), v(-40, 0, -140), v(-40, 0, -76), v(-96, 0, -76), v(-150, 0, -108), v(-96, 0, -108),
		-- around the Pump Annex
		v(30, 0, 85), v(126, 0, 100), v(126, 0, 48), v(70, 0, 48), v(60, 0.4, 88),
		-- south yard, water tower, culvert side
		v(-90, 0, 78), v(-30, 0, 132), v(0, 0, 110), v(60, 0, 150), v(120, 0, 140), v(-130, 0, 98), v(-160, 0, 150),
		-- roads, east apron, pier approach, rail cut
		v(-20, 0, 18), v(-60, 0, 32), v(60, 0, 32), v(100, 0, 12), v(160, 0, -70), v(170, 0, 100), v(-170, 0, -150),
		-- depot dock
		v(36, 0, -94), v(36, 0, -130),
	}
	World.watchPosts = {
		{ route = "PA", post = v(70, 10, 106) }, -- mezzanine overwatch in the turbine room
		{ route = "PA" },
		{ route = "HS" },
	}
	World.boss = {
		name = "THE FOREMAN", home = v(136, 4, -150),
		route = { v(136, 4, -150), v(116, 4, -128), v(84, 4, -126), v(62, 4, -110), v(100, 4, -112), v(130, 4, -112) },
		crew = { v(112, 4, -130), v(80, 4, -122) },
	}
	root.Parent = workspace
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	print(string.format("[ZR] World built: %d parts, %d containers, %d spawns", n, #World.containers, #World.spawns))
end

function World.init(_ctx) end

World.Props = Props
World.part = part
World.box = box
return World
