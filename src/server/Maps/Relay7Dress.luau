--!nonstrict
-- Relay 7 dressing (lobby L3): the Blender bunker kit (ZR_BunkerKitA/B/C, see KitMeta.luau and Kit.luau) placed on
-- the plan the shell and the stations use (Relay7.luau: x east 0..140, z south 0..104, floor y 0). The stations keep
-- the prompts; this module is what you see and bump into: furniture with box colliders, fittings without, painted
-- signs and floor lines, a little lived-in litter (no rubble: the bunker is kept), and the lights.
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
local WARM, COLD, AMBER = hex("FFD9A8"), hex("D8E6FF"), hex("FFC490")
local DUCT = { metal = hex("8E8F8A") } -- galvanised sheet gone dull: the baked colour times this

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
-- plain surfaces in the bunker (no speckled MaterialVariants): the baked chips and the decals carry the wear
local CLEAN = { paint = false, concrete = false, plaster = false }
local function place(parent, name, cf, opts)
	opts = opts or {}
	if opts.variants == nil then
		opts = table.clone(opts)
		opts.variants = CLEAN
	end
	return Kit.place(parent, name, cf, opts)
end
local function put(parent, name, x, y, z, f, opts)
	count += 1
	local cf = at(x, y, z, f)
	return place(parent, name, cf, opts), cf
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
	local n = (opts and opts.segs) or math.max(1, math.floor(len / size.X + 0.5))
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
	if not shadows then
		pl:SetAttribute("Fill", true) -- POTATO turns the fill lights off (client Detail)
	end
	pl.Parent = a
	a.Parent = parent
	return a
end
-- a small warm lamp at a point of a prop (its frame cf, offset in prop space): desk lamps, bench lamps
local function propLamp(parent, cf, off, color, range, brightness)
	local p = (cf * CFrame.new(off)).Position
	local a = Instance.new("Part")
	a.Name = "PropLamp"
	a.Size = V(0.2, 0.2, 0.2)
	a.Transparency = 1
	quiet(a)
	a.CFrame = CFrame.new(p)
	local pl = Instance.new("PointLight")
	pl.Color = color
	pl.Range = range
	pl.Brightness = brightness
	pl.Shadows = false
	pl:SetAttribute("Fill", true)
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
	-- a Top-face gui reads up along the plate's -X: point that the way the reader faces (f)
	p.Size = V(h, 0.05, w)
	p.Transparency = 1
	quiet(p)
	p.CFrame = CFrame.fromMatrix(P(x, 0.03, z), -dirOf(f or "N"), Vector3.yAxis)
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
-- a screen: an invisible plate at `cf` (w x h, its front along cf.LookVector, or its top when top = true) carrying a
-- SurfaceGui the game writes on (boards, cards, map sheets). Returns the plate and the gui.
local function screen(parent, name, cf, w, h, top, ppsd, maxDist)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = top and V(w, 0.04, h) or V(w, h, 0.04)
	p.Transparency = 1
	quiet(p)
	p.CFrame = cf
	local g = Instance.new("SurfaceGui")
	g.Name = "Gui"
	g.Face = top and Enum.NormalId.Top or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppsd or 40
	g.LightInfluence = 0.75
	g.MaxDistance = maxDist or 70
	g.Parent = p
	p.Parent = parent
	return p, g
end
local function label(parent, name, text, size, pos, color, font, align)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos or UDim2.new()
	t.Text = text
	t.TextColor3 = color or STENCIL
	t.FontFace = font or OSWALD
	t.TextScaled = true
	t.TextXAlignment = align or Enum.TextXAlignment.Center
	t.Parent = parent
	return t
end
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local MARKER = Font.fromEnum(Enum.Font.PermanentMarker)
-- a wear-kit piece (litter, chips, puddles: ZR_WK_*) on the floor
local function wk(parent, key, x, z, yaw, s)
	local lib = game:GetService("ServerStorage"):FindFirstChild("ZR_Assets")
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
	end
	-- the locker row on the north wall: one per bed, the owner's callsign on the card (Lobby service), and a spare
	-- standing open at the end of the row
	local cards = {}
	for k = 1, 12 do
		local x = R.LOCKER_X0 + (k - 0.5) * R.LOCKER_W
		local _, cf = wall(g, "Locker", x, 0, 0.6, "S", { name = "Locker" .. k })
		local card, gui = screen(g, "Card" .. k, cf * CFrame.new(0, 5.1, -1.02), 0.78, 0.34, false, 60, 26)
		card:SetAttribute("Bed", k)
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = hex("D8D2BE")
		bg.BorderSizePixel = 0
		bg.Parent = gui
		label(bg, "Name", "", UDim2.fromScale(0.92, 0.8), UDim2.fromScale(0.04, 0.1), hex("1E1E1A"), MONO)
		cards[k] = card
	end
	wall(g, "LockerOpen", R.LOCKER_X0 + 12.5 * R.LOCKER_W, 0, 0.6, "S")
	Dress.cards = cards
	stencil(g, "LOCKERS", R.LOCKER_X0 + 6 * R.LOCKER_W, 8.0, 0.6, "S", 3.6, 0.8)
	-- the mirror (check your kit), first aid, the pipe drop by the corner
	wall(g, "MirrorSink", 33.5, 0, 0.6, "S", { mats = { glass = { M.Glass, nil, 0.05, 0.32, false } }, tint = { glass = hex("B9C3C6") } })
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
	run(g, "Beam", "x", 0.6, 39.4, 25, 12, "S", "hang")
	fluoro(g, 21, 18.5, 12, "S", { WARM, 32, 1.25, true })
	fluoro(g, 21, 6.5, 12, "S", { WARM, 16, 0.35, false })
	fluoro(g, 21, 30.5, 12, "S", nil, true)
	put(g, "Rubble", 37.4, 0, 4.0, 210)
	wk(g, "ZR_WK_Litter", 30.5, 26.5, 40)
	wk(g, "ZR_WK_Litter", 20.0, 33.0, 160)
end

local function opsRoom(g, R)
	-- the map table (plan your deployment), chairs round it, its desk lamp
	local _, tcf = put(g, "MapTable", 68, 0, 17, "S")
	propLamp(g, tcf, V(9.6, 4.8, 2.9), hex("FFC890"), 12, 0.8)
	-- the four map sheets: the map, its kind and the votes for the next raid (Lobby service)
	for i, x in { 8.6, 2.9, -2.9, -8.6 } do
		-- (a Top-face gui reads up along the plate's -X: turn the plate so that points away from the south side)
		local turn = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.yAxis)
		local _, gui = screen(g, "MapSheet" .. i, tcf * CFrame.new(x, 3.47, -0.6) * turn, 4.0, 5.0, true, 40, 50)
		label(gui, "Name", "", UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.06), hex("2A2A24"), OSWALD)
		label(gui, "Kind", "", UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.27), hex("5A5546"), OSWALD)
		label(gui, "Votes", "", UDim2.fromScale(0.9, 0.16), UDim2.fromScale(0.05, 0.5), hex("8E2A22"), MONO)
		label(gui, "State", "", UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.76), hex("2E4A2E"), OSWALD)
	end
	for _, c in { { 61.0, 23.7 }, { 72.5, 23.8 }, { 66.0, 10.3 }, { 54.4, 17.6 }, { 81.6, 15.8 } } do
		put(g, "Chair", c[1], 0, c[2], toward(c[1], c[2], 68, 17) + ((c[1] * 7) % 11 - 5))
	end
	-- boards: departures (north wall), roster (west), tasks (east); the insurance hatch in the south wall
	local _, dcf = wall(g, "DepartureBoard", 75, 5.2, 0.6, "S")
	wall(g, "WallClock", 62.5, 8.3, 0.6, "S")
	local _, wcf = wall(g, "Whiteboard", 40.6, 3.2, 27, "E")
	local _, ccf = wall(g, "CorkBoard", 91.4, 3.0, 28, "W")
	-- the departure board: one character per flap (4 rows of 24), written by the Lobby service
	do
		local _, gui = screen(g, "DepartureScreen", dcf * CFrame.new(0.045, 1.98, -0.1), 11.28, 2.88, false, 40, 90)
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromScale(1 / 24, 1 / 4)
		grid.CellPadding = UDim2.new()
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = gui
		for r = 1, 4 do
			for c = 1, 24 do
				local t = label(gui, ("R%dC%d"):format(r, c), "", UDim2.new(), nil, hex("F2C46A"), MONO)
				t.LayoutOrder = r * 100 + c
				local pad = Instance.new("UIPadding")
				pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
				pad.Parent = t
			end
		end
	end
	-- the roster whiteboard (marker): everyone on the server, their squad colour and where they are
	do
		local _, gui = screen(g, "RosterScreen", wcf * CFrame.new(0, 2.0, -0.02), 5.7, 3.7, false, 40, 60)
		gui.LightInfluence = 0.45
		label(gui, "Count", "", UDim2.fromScale(0.6, 0.1), UDim2.fromScale(0.04, 0.03), hex("6E1E18"), MARKER, Enum.TextXAlignment.Left)
		for i = 1, 12 do
			local col = (i - 1) // 6
			local row = (i - 1) % 6
			local t = label(gui, "Row" .. i, "", UDim2.fromScale(0.46, 0.12), UDim2.fromScale(0.03 + col * 0.49, 0.16 + row * 0.135), hex("101C30"), MARKER, Enum.TextXAlignment.Left)
			t.RichText = true
		end
	end
	-- the task board: your own tasks are pinned on it by your client (Lobby controller)
	screen(g, "TaskScreen", ccf * CFrame.new(0, 2.0, -0.06), 7.8, 3.8, false, 40, 50)
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
	run(g, "Duct", "x", 40.6, 91.4, 5.2, 12, "S", "hang", { tint = DUCT })
	run(g, "CableTray", "x", 40.6, 91.4, 31.0, 12, "S", "hang", { tint = DUCT })
	fluoro(g, 59.5, 17, 12, "S")
	fluoro(g, 68, 17, 12, "S", { WARM, 36, 1.4, true })
	fluoro(g, 76.5, 17, 12, "S")
	wk(g, "ZR_WK_Litter", 85.5, 31.0, 75)
end

-- the seven trade counters (Relay7.TRADERS), each with its desk lamp and a name board on the wall behind the trader
local function counters(g, R)
	local board = hex("23261F")
	for _, t in R.TRADERS do
		local _, cf = put(g, "Counter", t.x, 0, t.z, t.face)
		propLamp(g, cf, V(-5.0, 4.6, 0.7), hex("FFC890"), 13, 0.9) -- the desk lamp
		stencil(g, t.label .. " · " .. t.title, t.board[1], 9.4, t.board[2], t.face, 9, 1.3, STENCIL, board) -- faces the room, as the counter does
	end
end

local function tradersHall(g, R)
	-- VOS, the quartermaster: a gun rack, a wall of parts, ammunition crates
	wall(g, "GunRack", 101, 1.2, 0.6, "S")
	wall(g, "Pegboard", 92.6, 2.2, 4.8, "E", { scale = V(0.8, 1, 1) })
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
	-- DEKKER, the liaison, across the hall: a rack of western rifles on the wall behind him, a crate of rounds
	wall(g, "GunRack", 114, 1.2, 35.4, "N")
	put(g, "AmmoCrate", 109.8, 0, 33.4, 182)
	-- the Fence's junk stall by the back door (the motor pool side)
	local _, fcf = wall(g, "FenceStall", 123.4, 0, 35.4, "N")
	propLamp(g, fcf, V(-1.3, 2.6, 0.3), hex("FFB070"), 9, 0.7)
	put(g, "Drum", 119.2, 0, 33.4, 0)
	put(g, "JerryCans", 116.4, 0, 33.6, 10)
	stencil(g, "FENCE", 123.4, 6.2, 35.4, "N", 3.2, 1.0, hex("C2B48E"))
	-- mail pigeonholes on the east wall: a cell per bed (4 x 3); your client lights yours when mail is waiting
	local _, pcf = wall(g, "Pigeonholes", 139.4, 0, 22.5, "W")
	local lamps = Instance.new("Model")
	lamps.Name = "MailLamps"
	lamps.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	for k = 1, 12 do
		local col, row = (k - 1) % 4, (k - 1) // 4
		local lamp = Instance.new("Part")
		lamp.Name = "Cell" .. k
		lamp.Size = V(1.2, 0.08, 0.06)
		lamp.Material = M.Neon
		lamp.Color = hex("FFB24A")
		lamp.Transparency = 1
		quiet(lamp)
		-- cell centres: x 2.25 .. -2.25 across (the viewer's left first), rows from the top (y 6.5, 5.1, 3.7)
		lamp.CFrame = pcf * CFrame.new(2.25 - col * 1.5, 7.08 - row * 1.4, -0.63)
		lamp:SetAttribute("Bed", k)
		lamp.Parent = lamps
	end
	lamps.Parent = g
	do
		local _, gui = screen(g, "MailNumbers", pcf * CFrame.new(0, 5.1, -0.62), 6.0, 4.2, false, 30, 30)
		for k = 1, 12 do
			local col, row = (k - 1) % 4, (k - 1) // 4
			label(gui, "N" .. k, tostring(k), UDim2.fromScale(0.08, 0.07), UDim2.fromScale(col * 0.25 + 0.085, row / 3 + 0.255), hex("CFC6A8"), MONO)
		end
	end
	stencil(g, "MAIL", 139.4, 8.0, 22.5, "W", 2.6, 0.8)
	wall(g, "WallClock", 92.6, 8.6, 28.5, "E")
	wall(g, "Extinguisher", 126.4, 0.6, 35.4, "N")
	wall(g, "PipeRun", 139.4, 9.6, 9.0, "W")
	wall(g, "PipeRunRust", 139.4, 9.6, 30.0, "W")
	-- ceiling
	run(g, "Beam", "x", 92.6, 139.4, 21.5, 12, "S", "hang")
	fluoro(g, 101, 7, 12, "S")
	fluoro(g, 131, 7, 12, "S")
	fluoro(g, 116, 17, 12, "S", { WARM, 36, 1.3, true })
	fluoro(g, 107, 27, 12, "S", nil, true)
	fluoro(g, 126, 30, 12, "S")
	wk(g, "ZR_WK_Litter", 103.0, 22.5, 20)
	wk(g, "ZR_WK_Cardboard", 118.6, 31.0, 70)
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
	run(g, "CableTray", "x", 0.6, 139.4, 38.4, 10, "S", "hang", { segs = 6, tint = DUCT })
	run(g, "Duct", "x", 0.6, 139.4, 41.7, 10, "S", "hang", { segs = 6, tint = DUCT })
	for k, x in { 12, 40, 68, 96, 124 } do
		local m = fluoro(g, x, 39.9, 10, "S", { COLD, 18, 0.6, false })
		if k == 4 then
			m:SetAttribute("Flicker", true) -- a failing tube (your client flickers it)
		end
	end
	-- the dead west end: a sandbag wall and rubble
	put(g, "Sandbags", 2.4, 0, 40, "E")
	put(g, "SandbagsLow", 2.4, 2.39, 40.2, 92)
	put(g, "Rubble", 5.6, 0, 42.0, 120)
	-- the east end, safety kit, PA and boxes on the walls
	wall(g, "FuseBox", 139.4, 0, 40, "W")
	wall(g, "Extinguisher", 80, 0.6, 36.6, "S")
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
	wk(g, "ZR_WK_Puddle", 110, 41.2, 30)
end

local function hideout(g, R)
	g.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- your client swaps parts of it (your levels)
	-- generator (fuel and a fuse panel by it), workbench, medstation, water collector, storage racks
	local _, gcf = wall(g, "HideoutGenerator", 9, 0, 44.6, "S")
	local glamp = Instance.new("Part")
	glamp.Name = "GenLamp" -- your client shows it green while your generator runs, red when you have none
	glamp.Size = V(0.22, 0.22, 0.08)
	glamp.Material = M.Neon
	glamp.Color = hex("8A2A20")
	quiet(glamp)
	glamp.CFrame = gcf * CFrame.new(-2.4, 3.25, -1.52)
	glamp.Parent = g
	put(g, "JerryCans", 15.8, 0, 47.2, 168)
	put(g, "Drum", 2.6, 0, 47.4, 0)
	wall(g, "FuseBox", 0.6, 0, 52.5, "E")
	local _, wbcf = wall(g, "CraftBench", 40, 0, 44.6, "S")
	-- a finished craft waiting on the bench (shown by your client when yours is ready to collect)
	local crate = place(g, "AmmoCrate", wbcf * CFrame.new(1.6, 3.3, 0.2) * CFrame.Angles(0, math.rad(8), 0), { name = "CraftReady", collide = false, scale = V(0.7, 0.7, 0.7) })
	count += 1
	crate:SetAttribute("CraftReady", "workbench")
	wall(g, "ToolChest", 47.6, 0, 44.6, "S")
	wall(g, "MedCot", 51.4, 0, 58, "W")
	wall(g, "MedShelf", 51.4, 0, 67.5, "W")
	wall(g, "FirstAid", 51.4, 4.6, 63.2, "W")
	wall(g, "WaterTank", 0.6, 0, 62, "E")
	wk(g, "ZR_WK_Puddle", 5.6, 66.2, 80, 0.8)
	-- three rack bays: full or bare by your storage level (both stand here; your client hides one of each pair)
	for t, x in { 14, 23, 32 } do
		local full = wall(g, "StorageRack", x, 0, 75.4, "N", { name = "RackFull" .. t })
		local bare = wall(g, "StorageRackEmpty", x, 0, 75.4, "N", { name = "RackBare" .. t, collide = false })
		full:SetAttribute("Rack", t)
		full:SetAttribute("Full", true)
		bare:SetAttribute("Rack", t)
		bare:SetAttribute("Full", false)
	end
	-- labels over the modules (the hideout screen shows their levels)
	-- your client writes your own level on each module's label ("YOUR GENERATOR · LV 1")
	for _, m in { { "generator", "GENERATOR", 9, 7.6, 44.6, "S" }, { "workbench", "WORKBENCH", 40, 8.4, 44.6, "S" },
		{ "medstation", "MEDSTATION", 51.4, 8.2, 62.5, "W" }, { "water", "WATER COLLECTOR", 0.6, 8.2, 62, "E" },
		{ "stash", "STASH", 23, 8.4, 75.4, "N" } } do
		local st = stencil(g, m[2], m[3], m[4], m[5], m[6], 8.4, 0.8)
		st:SetAttribute("Module", m[1])
	end
	-- the middle of the room: bays painted out for the lavatory, the scav case and the intelligence center (their prompts
	-- open the module: Relay7.HIDEOUT; furniture still to come)
	for k, name in { "LAVATORY", "SCAV CASE", "INTEL CENTRE" } do
		local x0 = 10 + (k - 1) * 10
		local x1, z0, z1 = x0 + 8, 55, 65
		local c = hex("A89A6A")
		paint(g, x0, z0, x1, z0 + 0.25, c)
		paint(g, x0, z1 - 0.25, x1, z1, c)
		paint(g, x0, z0, x0 + 0.25, z1, c)
		paint(g, x1 - 0.25, z0, x1, z1, c)
		floorText(g, name, (x0 + x1) / 2, (z0 + 1.4), 7.2, 1.7, "S", c) -- read from the wing's door (north)
	end
	-- every module has its place (2026-11-08): the three middle bays get a plywood back wall, and each of the fourteen
	-- modules a stencil that your client fills with your level (YOUR SECURITY · LV 2, or NOT BUILT). The furniture that
	-- would show each module as it is built (the plan: sink and drum, case, desk and board, camera desk, switch cabinet,
	-- card benches, prep table and drinks machine, sofa and computer) does not fit the bunker's budget of under 300 kit
	-- props (owner; 298 placed): the client already hides and shows props by level (ModuleId / ModuleMin / ModuleBare,
	-- Lobby.luau) for when the budget allows them (KNOWN_ISSUES 84).
	put(g, "AmmoCrate", 34.2, 0, 58.0, 12) -- materials waiting in the intel bay
	local function partition(x0, x1, z)
		local a, b = P(x0, 0, z - 0.2), P(x1, 7, z + 0.2)
		local p = Instance.new("Part")
		p.Name = "Partition"
		p.Size = (b - a):Abs()
		p.CFrame = CFrame.new((a + b) / 2)
		p.Color = hex("8C7A5C")
		p.Material = M.WoodPlanks
		p.Anchored = true
		p.Parent = g
		return p
	end
	for _, b in { { "lavatory", "LAVATORY", 10.3, 17.7 }, { "scavcase", "SCAV CASE", 20.3, 27.7 }, { "intel", "INTEL CENTRE", 30.3, 37.7 } } do
		partition(b[3], b[4], 64.6)
		local st = stencil(g, b[2], (b[3] + b[4]) / 2, 5.6, 64.4, "N", 7.2, 0.7)
		st:SetAttribute("Module", b[1])
	end
	for _, m in { { "security", "SECURITY", 6, 7.6, 36.6, "S" }, { "illumination", "ILLUMINATION", 0.6, 8.2, 54, "E" },
		{ "bitcoin", "BITCOIN FARM", 42.5, 8.4, 75.4, "N" }, { "nutrition", "NUTRITION UNIT", 39.4, 8.2, 8.4, "W" },
		{ "rest", "REST SPACE", 30, 8.2, 35.4, "N" }, { "range", "SHOOTING RANGE", 63, 8, 76.6, "S" } } do
		local st = stencil(g, m[2], m[3], m[4], m[5], m[6], 8.4, 0.8)
		st:SetAttribute("Module", m[1])
	end
	-- generator cable along the ceiling, joists, fittings (cold light)
	run(g, "CableTray", "x", 0.6, 51.4, 50.5, 12, "S", "hang", { tint = DUCT })
	run(g, "Beam", "x", 0.6, 51.4, 69, 12, "S", "hang")
	-- the wing's lights run off your generator (your client turns them off while you have none); a red
	-- emergency lamp stays on either way
	for _, f in { fluoro(g, 26, 63.5, 12, "S", { COLD, 32, 1.1, true }), fluoro(g, 12, 54, 12, "S"), fluoro(g, 40, 54, 12, "S") } do
		f:SetAttribute("Powered", true)
	end
	fluoro(g, 12, 68, 12, "S", nil, true)
	wall(g, "CageLampRed", 51.4, 9.6, 46.0, "W", { shadows = false })
	lamp(g, "Emergency", 50.4, 9.8, 46.0, hex("FF5A40"), 34, 0.85, false)
	lamp(g, "Emergency2", 1.6, 9.8, 56.0, hex("FF5A40"), 30, 0.7, false)
	wall(g, "Vent", 0.6, 9.4, 70.5, "E")
	wall(g, "Extinguisher", 18.6, 0.6, 44.6, "S")
	wk(g, "ZR_WK_Litter", 31.0, 69.5, 200)
	wk(g, "ZR_WK_Cardboard", 42.2, 73.6, 15)
end

local function gunsmith(g, R)
	-- the bench (your gun goes in its vise), the pegboard of parts over it, racks of builds on the west wall
	local _, bcf = wall(g, "GunBench", 66, 0, 44.6, "S")
	Dress.benchCF = bcf -- the vise (L4 clamps your gun in it)
	propLamp(g, bcf, V(-4.0, 5.6, 0.4), hex("FFD8A8"), 12, 0.9)
	wall(g, "Pegboard", 66, 5.4, 44.6, "S")
	local _, r1 = wall(g, "GunRack", 52.6, 1.0, 53.5, "E")
	local _, r2 = wall(g, "GunRack", 52.6, 1.0, 66.5, "E")
	Dress.racks = { r1, r2 }
	wall(g, "ToolChest", 76.2, 0, 44.6, "S")
	put(g, "WorkLight", 77.5, 0, 52.5, toward(77.5, 52.5, 68, 47))
	-- a cleaning table, crates of ammunition; KOVAC's counter on the south side, his parts rack behind him
	put(g, "Table", 68, 0, 57.5, 178)
	put(g, "Chair", 66.4, 0, 59.8, 10)
	put(g, "Chair", 70.6, 0, 55.2, 195)
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
	wk(g, "ZR_WK_Litter", 80.0, 70.0, 140)
end

local function range(g, R)
	local line, spm = R.FIRING_LINE, R.STUDS_PER_M
	-- booths at the firing line (a divider on each lane's north edge, its shelf at the line)
	for i, l in R.LANES do
		put(g, "RangeBooth", line + 5, 0, l[1], "S")
		local mid = (l[1] + l[2]) / 2
		-- the lane's display over the line, on a hanger from the ceiling (the Range service writes your string on it)
		local _, dcf = put(g, "RangeDisplay", line + 0.4, 7.4, mid, "E", { shadows = false })
		do
			local _, gui = screen(g, "LaneScreen" .. i, dcf * CFrame.new(0, 1.1, -0.06), 2.1, 1.9, false, 50, 45)
			local bg = Instance.new("Frame")
			bg.Size = UDim2.fromScale(1, 1)
			bg.BackgroundColor3 = hex("0E1210")
			bg.BorderSizePixel = 0
			bg.Parent = gui
			local green = hex("7CE08A")
			label(bg, "Who", "LANE " .. i, UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.04), green, MONO)
			label(bg, "Hits", "READY", UDim2.fromScale(0.9, 0.22), UDim2.fromScale(0.05, 0.28), green, MONO)
			label(bg, "Group", "", UDim2.fromScale(0.9, 0.18), UDim2.fromScale(0.05, 0.54), green, MONO)
			label(bg, "Time", "", UDim2.fromScale(0.9, 0.18), UDim2.fromScale(0.05, 0.76), green, MONO)
		end
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
	end
	-- targets (Relay7.targets: paper at 5 m, steel at 10 and 25 m, and 50 m down the tunnel on lane 4)
	local targets = {}
	for _, t in R.targets() do
		local m, cf = put(g, t.kind == "paper" and "PaperTarget" or "SteelPlate", t.x, 0, t.z, "E", { name = ("Target_%d_%d"):format(t.lane, t.m) })
		m:SetAttribute("Lane", t.lane)
		m:SetAttribute("Metres", t.m)
		m:SetAttribute("Frame", cf)
		table.insert(targets, m)
	end
	Dress.targets = targets
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
	baffle:SetAttribute("NoDetail", true)
	baffle.Parent = g
	for k, x in { 44.0, 46.6 } do
		local cf = at(x, 0, 77.4, "S") * CFrame.new(0, 0, -0.9) * CFrame.Angles(math.rad(-10 - k), 0, 0)
		count += 1
		place(g, "PaperTarget", cf)
	end
	put(g, "AmmoCrate", 60.0, 0, 78.4, 2)
	put(g, "Drum", 64.0, 0, 78.2, 0)
	-- light: fittings down the range, one over the booths, cage lamps in the tunnel
	for k, x in { 20, 50, 74 } do
		local m = fluoro(g, x, 92.5, 11, "S", { COLD, 26, 0.8, false })
		if k == 2 then
			m:SetAttribute("Flicker", true)
		end
	end
	fluoro(g, line + 5.5, 90.5, 11, "E", { WARM, 22, 0.9, false })
	wall(g, "CageLampRed", line + 5, 8.4, 76.6, "S", { shadows = false })
	wall(g, "Speaker", 91.4, 9.4, 80, "W")
	for _, x in { -20, -56 } do
		wall(g, "CageLamp", x, 6.2, 98.6, "S", { shadows = false })
	end
	lamp(g, "LampTunnel", -40, 6.4, 101, COLD, 24, 0.5, false)
	run(g, "PipeRunRust", "x", -77.4, -0.2, 98.6, 5.6, "S", "wall", { segs = 3 })
	run(g, "Beam", "z", 76.6, 103.4, 42, 11, "E", "hang")
end

local function motorPool(g, R)
	-- the van, rear doors open (the deploy screen swings them shut), nose toward the corridor opening
	local van, vcf = put(g, "Van", 118, 0, 69.5, "N")
	Dress.vanCF = vcf
	-- the dashboard on the bulkhead inside the cargo box: the matching countdown (Lobby service)
	do
		local _, gui = screen(g, "VanScreen", vcf * CFrame.new(0, 5.4, -2.62) * CFrame.Angles(0, math.pi, 0), 2.6, 1.3, false, 50, 30)
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = hex("120E0A")
		bg.BorderSizePixel = 0
		bg.Parent = gui
		local amber = hex("FFB04A")
		label(bg, "State", "STANDBY", UDim2.fromScale(0.9, 0.3), UDim2.fromScale(0.05, 0.06), amber, MONO)
		label(bg, "Clock", "--:--", UDim2.fromScale(0.9, 0.36), UDim2.fromScale(0.05, 0.36), amber, MONO)
		label(bg, "Info", "", UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.76), hex("C98A3A"), MONO)
		lamp(g, "VanDash", 118, 5.2, 69.5 - 2.0, hex("FFB04A"), 9, 0.6, false)
	end
	local doors = {}
	for _, d in { { "VanDoor", 3.25, 1 }, { "VanDoorR", -3.25, -1 } } do
		local hinge = vcf * CFrame.new(d[2], 1.4, 9.63)
		count += 1
		local m = place(g, d[1], hinge * CFrame.Angles(0, math.rad(105 * d[3]), 0), { name = d[1] })
		m:SetAttribute("Hinge", hinge)
		m:SetAttribute("OpenYaw", 105 * d[3])
		table.insert(doors, m)
	end
	-- the ramp up to the roller door, sandbags facing it, a red lamp over the door
	put(g, "Ramp", 132.8, 0, 85.4, "N")
	wall(g, "RollerDoor", 132.8, 9.0, 103.4, "N")
	-- a cold glow from the top of the ramp (light leaking past the shutter)
	lamp(g, "RampGlow", 132.8, 11.5, 100.5, hex("9FB8D8"), 26, 0.7, false)
	local leak = Instance.new("Part")
	leak.Name = "ShutterLeak"
	leak.Size = V(12.4, 0.12, 0.3)
	leak.Color = hex("B8CCE0")
	leak.Material = M.Neon
	leak.Transparency = 0.35
	quiet(leak)
	leak.CFrame = CFrame.new(P(132.8, 9.08, 102.9))
	leak.Parent = g
	-- the red work light on the west wall by the van
	wall(g, "CageLampRed", 92.6, 7.5, 76, "E", { shadows = false })
	lamp(g, "RedWork", 94.0, 7.8, 76, hex("FF5A40"), 24, 0.9, false)
	put(g, "Sandbags", 131.0, 0, 60.6, 176)
	put(g, "SandbagsLow", 124.4, 0, 63.4, 140)
	-- the scav hatch in the south-west corner and its board
	put(g, "Manhole", 98.5, 0, 97.5, "N")
	local _, scf = put(g, "SignPost", 103.6, 0, 99.6, "N")
	Dress.hatchCF = at(98.5, 0, 97.5, "N")
	-- the scav sign: your cooldown (your client writes it)
	do
		local _, gui = screen(g, "ScavSign", scf * CFrame.new(0, 4.6, -0.13), 2.8, 1.8, false, 50, 40)
		gui.Parent:SetAttribute("ScavSign", true)
		label(gui, "Head", "SCAV EXIT", UDim2.fromScale(0.9, 0.36), UDim2.fromScale(0.05, 0.08), hex("1E1E1A"), OSWALD)
		label(gui, "State", "", UDim2.fromScale(0.9, 0.4), UDim2.fromScale(0.05, 0.5), hex("7A2A24"), MONO)
	end
	stencil(g, "SCAV EXIT", 98.5, 6.0, 103.4, "N", 4.4, 1.1, hex("C2B48E"))
	-- workshop corner on the west wall, tyres, cans, drums
	wall(g, "ToolChest", 92.6, 0, 57.5, "E")
	wall(g, "HoseReel", 92.6, 4.6, 70, "E")
	put(g, "TyreStack", 95.6, 0, 48.6, 0)
	put(g, "TyreStack", 99.2, 0, 47.6, 28)
	put(g, "JerryCans", 108.0, 0, 60.6, 70)
	put(g, "JerryCans", 124.4, 0, 86.0, 200)
	-- ROOK, the fixer, east of the vehicle opening: his stock on a rack and in drums behind the counter
	wall(g, "StorageRack", 139.4, 0, 53, "W")
	put(g, "Drum", 137.7, 0, 46.2, 0)
	put(g, "Drum", 135.4, 0, 46.0, 0)
	do -- one drum on its side
		local cf = at(137.4, 1.0, 60.8, 4) * CFrame.Angles(0, 0, math.rad(90))
		count += 1
		place(g, "Drum", cf * CFrame.new(0, -1.0, 0))
	end
	-- BRAM, the gamekeeper, west of it: hunting rifles on the wall behind him, a crate of rounds
	wall(g, "GunRack", 92.6, 1.2, 56, "E")
	put(g, "AmmoCrate", 95.2, 0, 63.6, 4)
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
	floorText(g, "PMC TRANSPORT", 118, 55.6, 9, 1.8, "S")
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
	for _, z in { 60, 86 } do
		run(g, "Beam", "x", 92.6, 139.4, z, 22, "S", "hang")
	end
	fluoro(g, 104, 58, 22, "S")
	fluoro(g, 104, 88, 22, "S")
	fluoro(g, 128, 58, 22, "S", nil, true)
	fluoro(g, 118, 72, 22, "S", { AMBER, 44, 1.05, true })
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
	counters(group(root, "Counters"), R)
	corridor(group(root, "Corridor"), R)
	hideout(group(root, "Hideout"), R)
	gunsmith(group(root, "Gunsmith"), R)
	range(group(root, "Range"), R)
	local doors = motorPool(group(root, "MotorPool"), R)
	-- frames your client needs whatever has streamed in: the vise, the gun racks (Lobby controller)
	local refs = Instance.new("Model")
	refs.Name = "LobbyRefs"
	refs.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Size = V(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	quiet(anchor)
	anchor.CFrame = CFrame.new(P(70, 0, 52))
	anchor.Parent = refs
	refs:SetAttribute("ViseCF", Dress.benchCF * CFrame.new(0, 3.95, -0.2))
	refs:SetAttribute("VanCF", Dress.vanCF)
	refs:SetAttribute("HatchCF", Dress.hatchCF)
	for i, l in R.LANES do
		local z = Instance.new("Part")
		z.Name = "BoothZone" .. i
		z.Transparency = 1
		quiet(z)
		local a, b = P(R.FIRING_LINE + 0.3, 0, l[1] + 0.15), P(91.6, 9, math.min(l[2], 103.4) - 0.15)
		z.Size = (b - a):Abs()
		z.CFrame = CFrame.new((a + b) / 2)
		z:SetAttribute("Lane", i)
		z.Parent = refs
	end
	for i, r in Dress.racks do
		refs:SetAttribute("Rack" .. i, r)
	end
	refs.Parent = root
	return { model = root, props = count, vanDoors = doors, cards = Dress.cards }
end

return Dress
