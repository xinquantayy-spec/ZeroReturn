--!nonstrict
-- Relay 7 dressing (lobby L3): the Blender bunker kit (ZR_BunkerKitA/B/C, see KitMeta.luau and Kit.luau) placed on
-- the plan the shell and the stations use (Relay7.luau: x east 0..140, z south 0..104, floor y 0). The stations keep
-- the prompts; this module is what you see and bump into: furniture with box colliders, fittings without, painted
-- signs and floor lines, a little wear, and the lights.
-- Budget (owner: top detail without costing frames): under 300 kit props, six shadow-casting lights (one per main
-- room, each just under its own fitting, and fittings never cast shadows), the rest soft fill without shadows.
-- Without the kit (asset batch not loaded) every prop is a plain box of its size, so the bunker still plays the same.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local AssetMeta = require(Shared.AssetMeta)
local Wear = require(Shared.Wear)
local Kit = require(script.Parent.Kit)

local Dress = {}
local V = Vector3.new
local M = Enum.Material

local P -- plan -> world, from Relay7
local count = 0

local function hex(h)
	return Color3.fromHex(h)
end
local STENCIL = hex("D9D2BC") -- off-white stencil paint
local YELLOW = hex("C9A13C")
local WARM, COLD, AMBER = hex("FFD9A8"), hex("D8E6FF"), hex("FFB070")

-- ── placing ────────────────────────────────────────────────────────────────────────────────────────────────
-- a facing: N/E/S/W or degrees clockwise from north (north is -z on the plan)
local function dirOf(f)
	if type(f) == "string" then
		f = ({ N = 0, E = 90, S = 180, W = 270 })[f]
	end
	local a = math.rad(f)
	return V(math.sin(a), 0, -math.cos(a))
end
-- the facing from (x, z) toward (tx, tz), in degrees
local function toward(x, z, tx, tz)
	return math.deg(math.atan2(tx - x, -(tz - z)))
end
local function at(x, y, z, f)
	local p = P(x, y, z)
	return CFrame.lookAt(p, p + dirOf(f))
end
-- a kit prop with its origin (bottom centre) at plan (x, y, z), front toward f
local function put(parent, name, x, y, z, f, opts)
	count += 1
	return Kit.place(parent, name, at(x, y, z, f), opts)
end
-- a prop against a wall: (x, z) on the wall's surface, the prop facing f away from it, its back flat on the wall
local function wall(parent, name, x, y, z, f, opts)
	local size, c = Kit.size(name)
	local sz = (opts and opts.scale) and opts.scale.Z or 1
	local d = dirOf(f) * ((c.Z + size.Z / 2) * sz)
	return put(parent, name, x + d.X, y, z + d.Z, f, opts)
end
-- a prop hung under a ceiling at height `ceil`
local function hang(parent, name, x, z, ceil, f, opts)
	local size, c = Kit.size(name)
	local sy = (opts and opts.scale) and opts.scale.Y or 1
	return put(parent, name, x, ceil - (c.Y + size.Y / 2) * sy, z, f, opts)
end
-- a run of one prop along x (or z) from a to b at the given cross position, stretched to fill it exactly
local function run(parent, name, axis, a, b, cross, y, f, how, opts)
	local size = Kit.size(name)
	local len = b - a
	local n = math.max(1, math.floor(len / size.X + 0.5))
	local seg = len / n
	opts = table.clone(opts or {})
	opts.scale = V(seg / size.X, 1, 1)
	for k = 1, n do
		local s = a + seg * (k - 0.5)
		local x, z = s, cross
		if axis == "z" then
			x, z = cross, s
		end
		if how == "hang" then
			hang(parent, name, x, z, y, f, opts)
		elseif how == "wall" then
			wall(parent, name, x, y, z, f, opts)
		else
			put(parent, name, x, y, z, f, opts)
		end
	end
end

local function quiet(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p:SetAttribute("NoDetail", true)
end

-- a lamp: an invisible anchor with a PointLight (shadows only for the six room lights)
local function lamp(parent, name, x, y, z, color, range, brightness, shadows)
	local a = Instance.new("Part")
	a.Name = name
	a.Size = V(0.2, 0.2, 0.2)
	a.Transparency = 1
	quiet(a)
	a.CFrame = CFrame.new(P(x, y, z))
	local pl = Instance.new("PointLight")
	pl.Color = color
	pl.Range = range
	pl.Brightness = brightness
	pl.Shadows = shadows == true
	pl.Parent = a
	a.Parent = parent
	return a
end
-- a fluorescent fitting under the ceiling; light = { color, range, brightness, shadows } puts a lamp just under it
local function fluoro(parent, x, z, ceil, f, light, dead)
	local m = hang(parent, dead and "FluoroDead" or "Fluoro", x, z, ceil, f, { shadows = false })
	if light then
		lamp(m, "Lamp", x, ceil - 1.5, z, light[1], light[2], light[3], light[4])
	end
	return m
end

-- painted stencil lettering on a wall: (x, z) on the surface, y the centre height, facing f, w x h studs
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local function stencil(parent, text, x, y, z, f, w, h, color, board)
	local d = dirOf(f)
	local p = Instance.new("Part")
	p.Name = "Stencil"
	p.Size = V(w, h, 0.05)
	p.Transparency = 1
	quiet(p)
	local c = P(x, y, z) + d * 0.05
	p.CFrame = CFrame.lookAt(c, c + d)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 24
	g.LightInfluence = 1
	g.MaxDistance = 140
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = board or Color3.new()
	t.BackgroundTransparency = board and 0.05 or 1
	t.TextColor3 = color or STENCIL
	t.TextTransparency = 0.1
	t.FontFace = OSWALD
	t.TextScaled = true
	t.Text = text
	t.Parent = g
	if board then
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.12, 0)
		pad.PaddingBottom = UDim.new(0.12, 0)
		pad.PaddingLeft = UDim.new(0.04, 0)
		pad.PaddingRight = UDim.new(0.04, 0)
		pad.Parent = t
	end
	p.Parent = parent
	return p
end
-- lettering painted on the floor (read from the south unless f says otherwise)
local function floorText(parent, text, x, z, w, h, f, color)
	local p = Instance.new("Part")
	p.Name = "FloorText"
	p.Size = V(w, 0.05, h)
	p.Transparency = 1
	quiet(p)
	p.CFrame = at(x, 0.03, z, f or "N")
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	g.LightInfluence = 1
	g.MaxDistance = 90
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextColor3 = color or YELLOW
	t.TextTransparency = 0.15
	t.FontFace = OSWALD
	t.TextScaled = true
	t.Text = text
	t.Parent = g
	p.Parent = parent
	return p
end
-- a painted floor strip between plan corners
local function paint(parent, x0, z0, x1, z1, color)
	local a, b = P(math.min(x0, x1), 0.004, math.min(z0, z1)), P(math.max(x0, x1), 0.03, math.max(z0, z1))
	local p = Instance.new("Part")
	p.Name = "FloorPaint"
	p.Size = (b - a):Abs()
	p.CFrame = CFrame.new((a + b) / 2)
	p.Color = color or YELLOW
	p.Material = M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	quiet(p)
	p.Parent = parent
	return p
end
-- yellow and black hazard bands on a wall (a gradient with hard stops): (x, z) on the surface, from y0 to y1
local function hazard(parent, x, y0, y1, z, f, w)
	local d = dirOf(f)
	local p = Instance.new("Part")
	p.Name = "Hazard"
	p.Size = V(w, y1 - y0, 0.05)
	p.Transparency = 1
	quiet(p)
	local c = P(x, (y0 + y1) / 2, z) + d * 0.05
	p.CFrame = CFrame.lookAt(c, c + d)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 8
	g.LightInfluence = 1
	g.MaxDistance = 120
	g.Parent = p
	local fr = Instance.new("Frame")
	fr.Size = UDim2.fromScale(1, 1)
	fr.BackgroundColor3 = Color3.new(1, 1, 1)
	fr.BorderSizePixel = 0
	fr.BackgroundTransparency = 0.12
	fr.Parent = g
	local keys, n = {}, 9
	local blk = hex("1E1F1C")
	for k = 0, n - 1 do
		local col = (k % 2 == 0) and YELLOW or blk
		table.insert(keys, ColorSequenceKeypoint.new(k / n, col))
		table.insert(keys, ColorSequenceKeypoint.new(math.min(1, (k + 1) / n - 0.001), col))
	end
	keys[#keys] = ColorSequenceKeypoint.new(1, keys[#keys].Value)
	local gr = Instance.new("UIGradient")
	gr.Color = ColorSequence.new(keys)
	gr.Rotation = 45
	gr.Parent = fr
	p.Parent = parent
	return p
end
-- a wear-kit piece (litter, chips, puddles: ZR_WK_*) on the floor
local function wk(parent, key, x, z, yaw, s)
	local lib = ReplicatedStorage:FindFirstChild("ZR_Assets")
	local src = lib and lib:FindFirstChild(key)
	if not src then
		return nil
	end
	local m = src:Clone()
	quiet(m)
	local off = AssetMeta[key] or V(0, src.Size.Y / 2, 0)
	if s then
		m.Size = src.Size * s
		off *= s
	end
	m.CFrame = CFrame.new(P(x, 0, z)) * CFrame.Angles(0, math.rad(yaw or 0), 0) * CFrame.new(off)
	local def = Wear.MESH[key] or {}
	if def.color then
		m.Color = def.color
	end
	if def.material then
		m.Material = def.material
	end
	if def.transparency then
		m.Transparency = def.transparency
	end
	m.Parent = parent
	return m
end
local function group(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- ── the rooms ──────────────────────────────────────────────────────────────────────────────────────────────
local function bunkRoom(g, R)
	-- six double bunks head to the west wall, a locker at each foot (every locker opens your stash)
	for i, z in R.BUNKS do
		put(g, (i % 2 == 0) and "BunkBedMessy" or "BunkBed", 5.0, 0, z + 1.5, 180 + ((i * 37) % 5 - 2) * 0.6)
		put(g, (i == 5) and "LockerOpen" or "Locker", 10.5, 0, z + 1.5, "E")
	end
	-- the mirror (check your kit), first aid, the pipe drop by the corner
	wall(g, "MirrorSink", 33.5, 0, 0.6, "S")
	wall(g, "FirstAid", 28.6, 4.6, 0.6, "S")
	wall(g, "PipeValve", 37.6, 0, 0.6, "S")
	wall(g, "PipeRun", 8.6, 9.6, 0.6, "S")
	wall(g, "PipeRunRust", 24.6, 9.6, 0.6, "S")
	wall(g, "Speaker", 38.2, 10.3, 0.6, "S")
	-- a card table in the middle of the room
	put(g, "Table", 27, 0, 21.5, 183)
	put(g, "Chair", 25.6, 0, 24.0, toward(25.6, 24.0, 27, 21.5))
	put(g, "Chair", 29.6, 0, 23.6, toward(29.6, 23.6, 27, 21.5) + 12)
	put(g, "Chair", 23.0, 0, 20.6, toward(23.0, 20.6, 27, 21.5) - 8)
	-- foot lockers by the east wall, an oil drum in the corner
	wall(g, "AmmoCrate", 39.4, 0, 27.4, "W")
	wall(g, "AmmoCrate", 39.4, 0, 30.6, 268)
	put(g, "AmmoCrate", 37.6, 1.59, 29.0, 262)
	put(g, "Drum", 37.7, 0, 33.6, 0)
	wall(g, "WallClock", 39.4, 8.8, 9, "W")
	wall(g, "JunctionBox", 39.4, 2.6, 24.0, "W")
	wall(g, "Vent", 39.4, 8.6, 31.5, "W")
	wall(g, "Extinguisher", 12.4, 0.6, 35.4, "N")
	wall(g, "CageLamp", 18, 9.0, 35.4, "N", { shadows = false })
	-- ceiling: two joists, three fittings (the middle one holds the room's light; one tube is dead)
	run(g, "Beam", "x", 0.6, 39.4, 12, 12, "S", "hang")
	run(g, "Beam", "x", 0.6, 39.4, 25, 12, "S", "hang")
	fluoro(g, 21, 18.5, 12, "S", { WARM, 32, 1.25, true })
	fluoro(g, 21, 6.5, 12, "S", { WARM, 16, 0.35, false })
	fluoro(g, 21, 30.5, 12, "S", nil, true)
	put(g, "Rubble", 37.4, 0, 4.0, 210)
	wk(g, "ZR_WK_Litter", 30.5, 26.5, 40)
	wk(g, "ZR_WK_Litter", 20.0, 33.0, 160)
	wk(g, "ZR_WK_Chips", 2.2, 34.0, 15)
end

local function opsRoom(g, R)
	-- the map table (plan your deployment), chairs round it
	put(g, "MapTable", 68, 0, 17, "S")
	for _, c in { { 59.5, 23.7 }, { 66.5, 23.9 }, { 74.0, 23.6 }, { 62.0, 10.3 }, { 75.0, 10.4 }, { 54.4, 17.6 }, { 81.6, 15.8 } } do
		put(g, "Chair", c[1], 0, c[2], toward(c[1], c[2], 68, 17) + ((c[1] * 7) % 11 - 5))
	end
	-- boards: departures (north wall), roster (west), tasks (east); the insurance hatch in the south wall
	wall(g, "DepartureBoard", 75, 5.2, 0.6, "S")
	wall(g, "WallClock", 62.5, 8.3, 0.6, "S")
	wall(g, "Whiteboard", 40.6, 3.2, 27, "E")
	wall(g, "CorkBoard", 91.4, 3.0, 28, "W")
	wall(g, "InsuranceWindow", 49, 0, 35.4, "N")
	-- a dark office behind the insurance glass
	local back = Instance.new("Part")
	back.Name = "InsuranceBack"
	back.Size = V(10, 4, 0.06)
	back.Color = hex("141615")
	back.Material = M.SmoothPlastic
	quiet(back)
	back.CFrame = at(49, 5, 35.4 - 0.04, "N")
	back.Parent = g
	stencil(g, "DEPARTURES", 75, 11.35, 0.6, "S", 6, 0.8)
	stencil(g, "ROSTER", 40.6, 8.0, 27, "E", 3.2, 0.8)
	stencil(g, "TASKS", 91.4, 8.0, 28, "W", 3.2, 0.8)
	stencil(g, "INSURANCE", 49, 8.3, 35.4, "N", 5, 0.9)
	-- the radio desk in the corner, the phone by the door, the fuse panel
	wall(g, "Table", 91.4, 0, 6.5, "W")
	put(g, "Chair", 87.0, 0, 6.8, 95)
	wall(g, "WallPhone", 40.6, 3.8, 10.5, "E")
	wall(g, "FuseBox", 44.6, 0, 0.6, "S")
	wall(g, "Speaker", 91.4, 10.3, 2.6, "W")
	wall(g, "Extinguisher", 60.4, 0.6, 35.4, "N")
	wall(g, "PipeRun", 91.4, 9.6, 9.0, "W")
	wall(g, "PipeRunRust", 91.4, 9.6, 25.0, "W")
	-- ceiling: the duct along the north side, a cable tray along the south, three fittings over the table
	run(g, "Duct", "x", 40.6, 91.4, 5.2, 12, "S", "hang")
	run(g, "CableTray", "x", 40.6, 91.4, 31.0, 12, "S", "hang")
	fluoro(g, 59.5, 17, 12, "S")
	fluoro(g, 68, 17, 12, "S", { WARM, 36, 1.4, true })
	fluoro(g, 76.5, 17, 12, "S")
	fluoro(g, 84.5, 28, 12, "S", nil, true)
	wk(g, "ZR_WK_Litter", 85.5, 31.0, 75)
end

local function tradersHall(g, R)
	for _, t in R.TRADERS do
		put(g, "Counter", (t.x0 + t.x1) / 2, 0, 10.5, "S")
	end
	-- VOS, the quartermaster: a gun rack and ammunition crates
	wall(g, "GunRack", 101, 1.2, 0.6, "S")
	put(g, "AmmoCrate", 96.6, 0, 6.6, 78)
	put(g, "AmmoCrate", 96.5, 1.59, 6.4, 84)
	put(g, "AmmoCrate", 105.6, 0, 3.0, 6)
	-- HALE, the field medic: the medicine case, a first-aid box, a stool
	wall(g, "MedShelf", 116, 0, 0.6, "S")
	wall(g, "FirstAid", 121.0, 4.6, 0.6, "S")
	put(g, "Chair", 111.6, 0, 5.4, 165)
	-- TILDA, the outfitter: armour and a rig on stands, a rack of packs and helmets
	put(g, "ArmorStand", 126.7, 0, 2.6, 172)
	put(g, "RigStand", 129.3, 0, 2.6, 188)
	wall(g, "StorageRack", 134.6, 0, 0.6, "S")
	-- the boards over the counters
	local board = hex("23261F")
	for _, t in R.TRADERS do
		local def = ({ vos = "VOS · QUARTERMASTER", hale = "HALE · FIELD MEDIC", tilda = "TILDA · OUTFITTER" })[t.id]
		stencil(g, def, (t.x0 + t.x1) / 2, 9.4, 0.6, "S", 9, 1.3, STENCIL, board)
	end
	-- the Fence's junk stall against the south wall, between the doors
	wall(g, "FenceStall", 117, 0, 35.4, "N")
	put(g, "Drum", 121.4, 0, 33.4, 0)
	put(g, "JerryCans", 112.6, 0, 33.6, 10)
	stencil(g, "FENCE", 117, 6.2, 35.4, "N", 3.2, 1.0, hex("C2B48E"))
	-- mail pigeonholes on the east wall
	wall(g, "Pigeonholes", 139.4, 0, 22.5, "W")
	stencil(g, "MAIL", 139.4, 8.0, 22.5, "W", 2.6, 0.8)
	-- a table to wait at
	put(g, "Table", 125, 0, 22, 92)
	put(g, "Chair", 122.6, 0, 22.6, 88)
	put(g, "Chair", 127.4, 0, 21.0, 262)
	wall(g, "WallClock", 92.6, 8.6, 28.5, "E")
	wall(g, "Extinguisher", 126.4, 0.6, 35.4, "N")
	wall(g, "Speaker", 139.4, 10.3, 33.5, "W")
	wall(g, "PipeRun", 139.4, 9.6, 9.0, "W")
	wall(g, "PipeRunRust", 139.4, 9.6, 30.0, "W")
	-- ceiling
	run(g, "Beam", "x", 92.6, 139.4, 14, 12, "S", "hang")
	run(g, "Beam", "x", 92.6, 139.4, 28, 12, "S", "hang")
	fluoro(g, 101, 7, 12, "S")
	fluoro(g, 131, 7, 12, "S")
	fluoro(g, 116, 17, 12, "S", { WARM, 36, 1.3, true })
	fluoro(g, 107, 27, 12, "S", nil, true)
	fluoro(g, 126, 30, 12, "S")
	wk(g, "ZR_WK_Litter", 108.0, 33.5, 20)
	wk(g, "ZR_WK_Cardboard", 113.0, 30.4, 70)
end

local function corridor(g, R)
	-- doors: blast doors into ops, the traders' hall and the hideout (their open leaves stand in those rooms), light
	-- frames on the rest (the 6-stud doors take a narrowed frame)
	put(g, "BlastDoor", 66, 0, 36, "N")
	put(g, "BlastDoor", 102, 0, 36, "N")
	put(g, "BlastDoor", 24, 0, 44, "S")
	put(g, "DoorFrame", 18, 0, 36, "S")
	put(g, "DoorFrame", 132, 0, 36, "S")
	put(g, "DoorFrame", 40, 0, 18, "E")
	put(g, "DoorFrame", 92, 0, 18, "E")
	put(g, "DoorFrame", 87, 0, 44, "N", { scale = V(0.75, 1, 1) })
	put(g, "DoorFrame", 87, 0, 76, "S", { scale = V(0.75, 1, 1) })
	-- signs over the doors (corridor side)
	stencil(g, "BUNK ROOM", 18, 9.2, 36.6, "S", 4.6, 0.9)
	stencil(g, "OPERATIONS", 66, 9.25, 36.6, "S", 5.2, 0.9)
	stencil(g, "TRADERS", 102, 9.25, 36.6, "S", 4.2, 0.9)
	stencil(g, "TRADERS", 132, 9.2, 36.6, "S", 4.2, 0.9)
	stencil(g, "HIDEOUT", 24, 9.25, 43.4, "N", 4.2, 0.9)
	stencil(g, "GUNSMITH · RANGE", 87, 9.2, 43.4, "N", 6.2, 0.9)
	stencil(g, "MOTOR POOL", 96, 5.8, 43.4, "N", 5.6, 1.2)
	stencil(g, "RELAY 7", 4.0, 6.0, 36.6, "S", 5.0, 1.8)
	-- hazard paint on the vehicle opening's sides
	hazard(g, 99.2, 0, 7, 43.4, "N", 1.6)
	hazard(g, 124.8, 0, 7, 43.4, "N", 1.6)
	-- services along the ceiling: a cable tray on the north side, the main duct on the south side
	run(g, "CableTray", "x", 0.6, 139.4, 38.4, 10, "S", "hang")
	run(g, "Duct", "x", 0.6, 139.4, 41.7, 10, "S", "hang")
	for k, x in { 12, 40, 68, 96, 124 } do
		local dead = (k == 4)
		local m = fluoro(g, x, 39.9, 10, "S", { COLD, 18, dead and 0.25 or 0.6, false }, dead)
		if dead then
			m:SetAttribute("Flicker", true)
		end
	end
	-- the dead west end: a sandbag wall and rubble
	put(g, "Sandbags", 2.4, 0, 40, "E")
	put(g, "SandbagsLow", 2.4, 2.39, 40.2, 92)
	put(g, "Rubble", 5.6, 0, 42.0, 120)
	wk(g, "ZR_WK_RubbleLarge", 6.4, 38.2, 60)
	wk(g, "ZR_WK_Chips", 8.2, 40.6, 200)
	-- the east end, safety kit, PA and boxes on the walls
	wall(g, "FuseBox", 139.4, 0, 40, "W")
	wall(g, "Extinguisher", 30, 0.6, 36.6, "S")
	wall(g, "Extinguisher", 80, 0.6, 36.6, "S")
	wall(g, "Extinguisher", 136.8, 0.6, 43.4, "N")
	wall(g, "Speaker", 50, 8.6, 36.6, "S")
	wall(g, "Speaker", 113, 8.6, 36.6, "S")
	wall(g, "JunctionBox", 46, 2.6, 43.4, "N")
	wall(g, "JunctionBox", 77, 2.6, 36.6, "S")
	wall(g, "Vent", 56, 1.4, 43.4, "N")
	wall(g, "Vent", 118, 1.4, 36.6, "S")
	wall(g, "WallPhone", 9.0, 3.8, 43.4, "N")
	-- walkway lines
	paint(g, 0.6, 37.1, 139.4, 37.35, YELLOW)
	paint(g, 0.6, 42.65, 100, 42.9, YELLOW)
	paint(g, 124, 42.65, 139.4, 42.9, YELLOW)
	wk(g, "ZR_WK_Litter", 34, 42.0, 110)
	wk(g, "ZR_WK_Litter", 72, 37.8, 300)
	wk(g, "ZR_WK_Puddle", 110, 41.2, 30)
end

local function hideout(g, R)
	-- generator (fuel and a fuse panel by it), workbench, medstation, water collector, storage racks
	wall(g, "HideoutGenerator", 9, 0, 44.6, "S")
	put(g, "JerryCans", 15.8, 0, 47.2, 168)
	put(g, "Drum", 2.6, 0, 47.4, 0)
	wall(g, "FuseBox", 0.6, 0, 52.5, "E")
	wall(g, "CraftBench", 40, 0, 44.6, "S")
	wall(g, "ToolChest", 47.6, 0, 44.6, "S")
	wall(g, "MedCot", 51.4, 0, 58, "W")
	wall(g, "MedShelf", 51.4, 0, 67.5, "W")
	wall(g, "FirstAid", 51.4, 4.6, 63.2, "W")
	wall(g, "WaterTank", 0.6, 0, 62, "E")
	wk(g, "ZR_WK_Puddle", 5.6, 66.2, 80, 0.8)
	wall(g, "StorageRack", 14, 0, 75.4, "N")
	wall(g, "StorageRack", 23, 0, 75.4, "N")
	wall(g, "StorageRackEmpty", 32, 0, 75.4, "N")
	-- labels over the modules (the hideout screen shows their levels)
	stencil(g, "GENERATOR", 9, 7.6, 44.6, "S", 4.2, 0.8)
	stencil(g, "WORKBENCH", 40, 8.4, 44.6, "S", 4.2, 0.8)
	stencil(g, "MEDSTATION", 51.4, 8.2, 62.5, "W", 4.6, 0.8)
	stencil(g, "WATER", 0.6, 8.2, 62, "E", 2.6, 0.8)
	stencil(g, "STORAGE", 23, 8.4, 75.4, "N", 3.6, 0.8)
	-- the middle of the room: a table to sit at
	put(g, "Table", 25, 0, 62, 4)
	put(g, "Chair", 22.6, 0, 63.6, 60)
	put(g, "Chair", 27.6, 0, 60.2, 236)
	-- generator cable along the ceiling, joists, fittings (cold light)
	run(g, "CableTray", "x", 0.6, 51.4, 50.5, 12, "S", "hang")
	run(g, "Beam", "x", 0.6, 51.4, 58, 12, "S", "hang")
	run(g, "Beam", "x", 0.6, 51.4, 70, 12, "S", "hang")
	fluoro(g, 26, 63.5, 12, "S", { COLD, 32, 1.1, true })
	fluoro(g, 12, 54, 12, "S")
	fluoro(g, 40, 54, 12, "S")
	fluoro(g, 12, 68, 12, "S", nil, true)
	wall(g, "Vent", 0.6, 9.4, 70.5, "E")
	wall(g, "Speaker", 51.4, 10.3, 46.4, "W")
	wall(g, "Extinguisher", 18.6, 0.6, 44.6, "S")
	wk(g, "ZR_WK_Litter", 31.0, 69.5, 200)
	wk(g, "ZR_WK_Cardboard", 42.2, 73.6, 15)
end

local function gunsmith(g, R)
	-- the bench (your gun goes in its vise), the pegboard of parts over it, racks of builds on the west wall
	wall(g, "GunBench", 66, 0, 44.6, "S")
	wall(g, "Pegboard", 66, 5.4, 44.6, "S")
	wall(g, "GunRack", 52.6, 1.0, 53.5, "E")
	wall(g, "GunRack", 52.6, 1.0, 66.5, "E")
	wall(g, "ToolChest", 76.2, 0, 44.6, "S")
	put(g, "WorkLight", 77.5, 0, 52.5, toward(77.5, 52.5, 68, 47))
	-- a cleaning table, crates of ammunition, a parts rack
	put(g, "Table", 68, 0, 62.5, 178)
	put(g, "Chair", 66.4, 0, 64.8, 10)
	put(g, "Chair", 70.6, 0, 60.2, 195)
	put(g, "AmmoCrate", 56.6, 0, 73.0, 2)
	put(g, "AmmoCrate", 56.4, 0, 70.4, 356)
	put(g, "AmmoCrate", 56.5, 1.59, 71.7, 8)
	put(g, "Drum", 60.6, 0, 73.4, 0)
	wall(g, "StorageRack", 71, 0, 75.4, "N")
	wall(g, "CageLamp", 87, 9.0, 44.6, "S", { shadows = false })
	wall(g, "CageLampRed", 87, 9.0, 75.4, "N", { shadows = false })
	stencil(g, "RANGE", 87, 10.7, 75.4, "N", 2.8, 0.8)
	wall(g, "Extinguisher", 91.4, 0.6, 50, "W")
	wall(g, "PipeRun", 91.4, 9.6, 53, "W")
	wall(g, "PipeRunRust", 91.4, 9.6, 67, "W")
	run(g, "Beam", "x", 52.6, 91.4, 54, 12, "S", "hang")
	run(g, "Beam", "x", 52.6, 91.4, 68, 12, "S", "hang")
	fluoro(g, 66, 49.5, 12, "S", { WARM, 28, 1.3, true })
	fluoro(g, 66, 62, 12, "S")
	fluoro(g, 83, 60, 12, "E")
	wk(g, "ZR_WK_Chips", 62.5, 48.5, 30, 0.7)
	wk(g, "ZR_WK_Litter", 80.0, 70.0, 140)
end

local function range(g, R)
	local line, spm = R.FIRING_LINE, R.STUDS_PER_M
	-- booths at the firing line (a divider on each lane's north edge, its shelf at the line)
	for i, l in R.LANES do
		put(g, "RangeBooth", line + 5, 0, l[1], "S")
		local mid = (l[1] + l[2]) / 2
		-- the lane's display over the line, on a hanger from the ceiling
		put(g, "RangeDisplay", line + 0.4, 7.4, mid, "E", { shadows = false })
		local rod = Instance.new("Part")
		rod.Name = "Hanger"
		rod.Size = V(0.08, 11 - 9.6, 0.08)
		rod.Color = hex("2E3032")
		rod.Material = M.Metal
		quiet(rod)
		rod.CFrame = CFrame.new(P(line + 0.4, (9.6 + 11) / 2, mid))
		rod.Parent = g
		-- free range ammunition behind each booth
		wall(g, "AmmoCrate", 91.4, 0, mid, "W")
		floorText(g, tostring(i), line + 3.4, mid, 1.6, 1.6, "W")
		-- steel at 10 and 25 m (and 50 m down the tunnel on lane 4)
		for k, m in R.PLATES do
			if m < 50 or i == 4 then
				local dz = (k == 1) and -1.2 or (k == 2 and 1.2 or 0)
				put(g, "SteelPlate", line - m * spm, 0, mid + dz, "E")
			end
		end
	end
	-- paper at 5 m on lanes 2 and 3
	put(g, "PaperTarget", line - 5 * spm, 0, (R.LANES[2][1] + R.LANES[2][2]) / 2 + 0.6, "E")
	put(g, "PaperTarget", line - 5 * spm, 0, (R.LANES[3][1] + R.LANES[3][2]) / 2 - 0.6, "E")
	-- the firing line and distance marks
	paint(g, line - 0.2, 76.6, line + 0.2, 103.4, YELLOW)
	for _, m in { 10, 25 } do
		stencil(g, m .. " M", line - m * spm, 8.6, 76.6, "S", 2.2, 0.9)
		paint(g, line - m * spm - 0.08, 82, line - m * spm + 0.08, 98, hex("8C8A80"))
	end
	stencil(g, "50 M", -74.25, 6.6, 98.6, "S", 2.2, 0.9)
	stencil(g, "LIVE FIRE · EARS ON", line + 5, 9.3, 76.6, "S", 7.0, 1.0)
	-- backstops: sandbags against the west wall (two high) and at the end of the tunnel
	for k = 0, 3 do
		local z = 76.6 + 2.7 + k * 5.4
		put(g, "Sandbags", 1.6, 0, z, "E", { scale = V(0.9, 1, 1) })
		put(g, "SandbagsLow", 1.6, 2.38, z + 0.3, 90 + (k % 2) * 3, { scale = V(0.9, 1, 1) })
	end
	put(g, "Sandbags", -76.4, 0, 101, "E", { scale = V(0.82, 1, 1) })
	put(g, "SandbagsLow", -76.4, 2.38, 101, 92, { scale = V(0.82, 1, 1) })
	-- the strip north of lane 1: a low concrete baffle, spare targets leaning on the wall
	local baffle = Instance.new("Part")
	baffle.Name = "Baffle"
	baffle.Anchored = true
	baffle.Size = V(line - 2.6, 3.2, 0.8)
	baffle.CFrame = CFrame.new(P(2.6 + (line - 2.6) / 2, 1.6, 81.5))
	baffle.Color = hex("6A675F")
	baffle.Material = M.Concrete
	baffle.MaterialVariant = "ZR_ConcreteWorn"
	baffle:SetAttribute("NoDetail", true)
	baffle.Parent = g
	for k, x in { 44.0, 46.6, 49.2 } do
		local cf = at(x, 0, 77.4, "S") * CFrame.new(0, 0, -0.9) * CFrame.Angles(math.rad(-10 - k), 0, 0)
		count += 1
		Kit.place(g, "PaperTarget", cf)
	end
	put(g, "AmmoCrate", 60.0, 0, 78.4, 2)
	put(g, "Drum", 64.0, 0, 78.2, 0)
	-- light: fittings down the range, one over the booths, cage lamps in the tunnel
	for _, x in { 20, 50, 74 } do
		fluoro(g, x, 92.5, 11, "S", { COLD, 26, 0.8, false })
	end
	fluoro(g, line + 5.5, 90.5, 11, "E", { WARM, 22, 0.9, false })
	wall(g, "CageLampRed", line + 5, 8.4, 76.6, "S", { shadows = false })
	wall(g, "Speaker", 91.4, 9.4, 80, "W")
	for _, x in { -12, -40, -66 } do
		wall(g, "CageLamp", x, 6.2, 98.6, "S", { shadows = false })
	end
	lamp(g, "LampTunnel", -40, 6.4, 101, COLD, 24, 0.5, false)
	run(g, "PipeRunRust", "x", -77.4, -0.2, 98.6, 5.6, "S", "wall")
	run(g, "Beam", "z", 76.6, 103.4, 12, 11, "E", "hang")
	run(g, "Beam", "z", 76.6, 103.4, 36, 11, "E", "hang")
	run(g, "Beam", "z", 76.6, 103.4, 62, 11, "E", "hang")
	wk(g, "ZR_WK_Chips", 86.6, 85.0, 30, 0.6)
	wk(g, "ZR_WK_Chips", 87.4, 96.0, 110, 0.6)
end

local function motorPool(g, R)
	-- the van, rear doors open (the deploy screen swings them shut), nose toward the corridor opening
	local van = put(g, "Van", 118, 0, 69.5, "N")
	local vcf = at(118, 0, 69.5, "N")
	local doors = {}
	for _, d in { { "VanDoor", 3.25, 1 }, { "VanDoorR", -3.25, -1 } } do
		local hinge = vcf * CFrame.new(d[2], 1.4, 9.63)
		count += 1
		local m = Kit.place(g, d[1], hinge * CFrame.Angles(0, math.rad(105 * d[3]), 0), { name = d[1] })
		m:SetAttribute("Hinge", hinge)
		m:SetAttribute("OpenYaw", 105 * d[3])
		table.insert(doors, m)
	end
	-- the ramp up to the roller door, sandbags facing it, a red lamp over the door
	put(g, "Ramp", 132.8, 0, 85.4, "N")
	wall(g, "RollerDoor", 132.8, 9.0, 103.4, "N")
	wall(g, "CageLampRed", 132.8, 20.2, 103.4, "N", { shadows = false })
	put(g, "Sandbags", 131.0, 0, 60.6, 176)
	put(g, "SandbagsLow", 124.4, 0, 63.4, 140)
	-- the scav hatch in the south-west corner and its board
	put(g, "Manhole", 98.5, 0, 97.5, "N")
	put(g, "SignPost", 103.6, 0, 99.6, "N")
	stencil(g, "SCAV EXIT", 98.5, 6.0, 103.4, "N", 4.4, 1.1, hex("C2B48E"))
	-- workshop corner on the west wall, tyres, cans, drums
	wall(g, "ToolChest", 92.6, 0, 57.5, "E")
	wall(g, "HoseReel", 92.6, 4.6, 70, "E")
	put(g, "TyreStack", 95.6, 0, 48.6, 0)
	put(g, "TyreStack", 99.2, 0, 47.6, 28)
	put(g, "JerryCans", 108.0, 0, 60.6, 70)
	put(g, "JerryCans", 124.4, 0, 86.0, 200)
	put(g, "Drum", 137.6, 0, 47.4, 0)
	put(g, "Drum", 135.3, 0, 47.2, 0)
	put(g, "Drum", 137.4, 0, 49.7, 0)
	do -- one drum on its side
		local cf = at(134.2, 1.0, 51.2, 64) * CFrame.Angles(0, 0, math.rad(90))
		count += 1
		Kit.place(g, "Drum", cf * CFrame.new(0, -1.0, 0))
	end
	-- work lights on the van
	for _, w in { { 109.0, 83.0 }, { 104.5, 63.0 } } do
		local m = put(g, "WorkLight", w[1], 0, w[2], toward(w[1], w[2], 118, 72))
		local s = Instance.new("SpotLight")
		s.Color = AMBER
		s.Range = 30
		s.Angle = 70
		s.Brightness = 1.4
		s.Shadows = false
		s.Face = Enum.NormalId.Front
		local a = Instance.new("Part")
		a.Name = "Beam"
		a.Size = V(0.2, 0.2, 0.2)
		a.Transparency = 1
		quiet(a)
		local p = P(w[1], 5.4, w[2])
		a.CFrame = CFrame.lookAt(p, P(118, 2.5, 72))
		s.Parent = a
		a.Parent = m
	end
	-- oil on the floor, the van bay painted out
	put(g, "OilStain", 118.5, 0, 66.0, 15)
	put(g, "OilStain", 117.0, 0, 74.5, 200)
	put(g, "OilStain", 106.0, 0, 92.0, 80)
	paint(g, 112.0, 57.0, 112.3, 84.0)
	paint(g, 123.7, 57.0, 124.0, 84.0)
	paint(g, 112.0, 83.7, 124.0, 84.0)
	floorText(g, "PMC TRANSPORT", 118, 87.6, 9, 1.8, "N")
	wk(g, "ZR_WK_Puddle", 103, 76, 10, 1.4)
	wk(g, "ZR_WK_Puddle", 128, 64, 200)
	wk(g, "ZR_WK_Chips", 95.5, 90.0, 40)
	-- walls and ceiling
	stencil(g, "MOTOR POOL", 112, 15.0, 44.6, "S", 12, 2.6)
	stencil(g, "RELAY 7", 108, 13.0, 103.4, "N", 12, 4.2)
	wall(g, "Extinguisher", 92.6, 0.6, 50, "E")
	wall(g, "Speaker", 92.6, 12.5, 80, "E")
	wall(g, "FuseBox", 92.6, 0, 86, "E")
	run(g, "PipeRun", "z", 46, 94, 92.6, 12.5, "E", "wall")
	for _, z in { 52, 68, 84, 100 } do
		run(g, "Beam", "x", 92.6, 139.4, z, 22, "S", "hang")
	end
	fluoro(g, 104, 58, 22, "S")
	fluoro(g, 104, 88, 22, "S")
	fluoro(g, 128, 58, 22, "S", nil, true)
	fluoro(g, 118, 72, 22, "S", { AMBER, 44, 1.2, true })
	return doors
end

-- dress the bunker `f` (the Relay7 model); P maps plan to world; R is the Relay7 module (its layout tables)
function Dress.build(f, plan, R)
	P = plan
	count = 0
	local root = Instance.new("Model")
	root.Name = "Dress"
	root.Parent = f
	bunkRoom(group(root, "BunkRoom"), R)
	opsRoom(group(root, "Ops"), R)
	tradersHall(group(root, "Traders"), R)
	corridor(group(root, "Corridor"), R)
	hideout(group(root, "Hideout"), R)
	gunsmith(group(root, "Gunsmith"), R)
	range(group(root, "Range"), R)
	local doors = motorPool(group(root, "MotorPool"), R)
	return { model = root, props = count, vanDoors = doors }
end

return Dress
