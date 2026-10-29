--!nonstrict
-- M13 map: MERIDIAN MALL (mall-type). An original layout (docs/maps/MERIDIAN_MALL.md): a two-level mall with a
-- central atrium (dry fountain, crossing escalators, skylight), a supermarket with a rooftop car park, a food court
-- under a cinema, shops on both levels, a service corridor with loading docks and a cargo lift, a generator that
-- powers the lights and the lift, a surface car park and a loading yard. Furnished and damaged with the Blender
-- mall kit (Maps/Kit.luau); flat surfaces are parts with worn MaterialVariants.
-- Local coordinates: x east, z south, y up. Ground y = 0, upper level y = 18, main roof y = 36.
local O = Vector3.new(-1600, 0, 0)

return function(kit, root)
	local W, C, M, hex = kit.World, kit.C, kit.M, kit.hex
	local Props = kit.Props
	local H = require(script.Parent.MapKit)(kit, O)
	local Kit = require(script.Parent.Kit)
	local V, CF = H.V, H.CF
	local rng = Random.new(2611)
	local map = kit.model("MeridianMall", root)
	map:SetAttribute("NoWire", true) -- a shopping mall: no barbed wire on its parapets, bands or gallery edges

	-- ── helpers ──────────────────────────────────────────────────────────────────────────────────────────
	local Y2, YR = 18, 36 -- upper level floor top, main roof top
	local SL = 1.2 -- slab thickness
	local function tag(parts, variant)
		if variant then
			for _, p in parts do
				if p:IsA("BasePart") then
					p:SetAttribute("Wear", variant)
				end
			end
		end
		return parts
	end
	local function capture(parent, fn)
		local before = {}
		for _, c in parent:GetChildren() do
			before[c] = true
		end
		fn()
		local out = {}
		for _, c in parent:GetChildren() do
			if not before[c] then
				table.insert(out, c)
			end
		end
		return out
	end
	-- a part by its bounds (local x/z, world y)
	local function BOX(parent, x0, x1, y0, y1, z0, z1, color, mat, variant)
		local p = kit.part(parent, Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), CFrame.new(O.X + (x0 + x1) / 2, (y0 + y1) / 2, O.Z + (z0 + z1) / 2), color, mat)
		if variant then
			p:SetAttribute("Wear", variant)
		end
		return p
	end
	local function WX(parent, x0, x1, z, y0, h, t, color, mat, holes, variant)
		return tag(capture(parent, function()
			H.wallX(parent, x0, x1, z, y0, h, t, color, mat, holes)
		end), variant)
	end
	local function WZ(parent, z0, z1, x, y0, h, t, color, mat, holes, variant)
		return tag(capture(parent, function()
			H.wallZ(parent, z0, z1, x, y0, h, t, color, mat, holes)
		end), variant)
	end
	local function SLAB(parent, x0, x1, z0, z1, yTop, th, color, mat, holes, variant)
		return tag(capture(parent, function()
			H.slab(parent, x0, x1, z0, z1, yTop, th, color, mat, holes)
		end), variant)
	end
	-- kit props indoors cast no sun shadows (their contact shadows are baked into the vertex colours; the sun only
	-- reaches the atrium, the glass fronts and the outside), which keeps the shadow pass cheap
	local SUNLIT = { Site = true, Outside = true, RoofParking = true, Ramp = true, GeneratorCompound = true, Shell = true, Atrium = true, Gallery = true, LobbyFacade = true }
	local function K(parent, name, x, y, z, ry, opts)
		if not SUNLIT[parent.Name] then
			opts = opts or {}
			if opts.shadows == nil then
				opts.shadows = false
			end
		end
		return Kit.place(parent, name, CF(x, y, z, ry), opts)
	end
	local function noDetail(p)
		p:SetAttribute("NoDetail", true)
		return p
	end

	-- wall finishes: plain painted plaster in the public areas, peeling plaster back of house
	local PAINT, PEEL = "", "ZR_PlasterPeel"
	-- palette
	local EXT, EXT_D, EXT_L = hex("8A8983"), hex("6C6B65"), hex("A3A29B")
	local TERRAZZO, TILE, CEILING, VINYL = hex("D6D1C7"), hex("D9D6CE"), hex("D8D6CE"), hex("E2DED2")
	local FASCIA, PLASTER_W = hex("B4B0A5"), hex("C2BEB3")
	local SLAB_C = hex("7E7E78")

	-- materials of flat surfaces (Parts + MaterialVariants)
	local function floorTerrazzo(parent, x0, x1, z0, z1, y, holes)
		return SLAB(parent, x0, x1, z0, z1, y, 0.3, TERRAZZO, M.Marble, holes, "ZR_Terrazzo")
	end
	local function floorTiles(parent, x0, x1, z0, z1, y, color, holes)
		return SLAB(parent, x0, x1, z0, z1, y, 0.3, color or TILE, M.CeramicTiles, holes, "ZR_FloorTiles")
	end
	local function floorVinyl(parent, x0, x1, z0, z1, y, color, holes)
		return SLAB(parent, x0, x1, z0, z1, y, 0.3, color or VINYL, M.Plastic, holes, "ZR_VinylFloor")
	end
	local function floorCarpet(parent, x0, x1, z0, z1, y, plain, color)
		return SLAB(parent, x0, x1, z0, z1, y, 0.3, color or (plain and hex("4A4E56") or hex("FFFFFF")), M.Carpet, nil, plain and "" or "ZR_CarpetWorn")
	end
	local function floorConcrete(parent, x0, x1, z0, z1, y, holes)
		return SLAB(parent, x0, x1, z0, z1, y, 0.3, hex("8E8D86"), M.Concrete, holes, "ZR_FloorConcrete")
	end
	local function floorWood(parent, x0, x1, z0, z1, y)
		return SLAB(parent, x0, x1, z0, z1, y, 0.3, hex("8C6E4E"), M.WoodPlanks, nil, "")
	end
	-- suspended ceiling: the underside at y, holes { x0, x1, z0, z1 } where damaged modules go
	local function ceiling(parent, x0, x1, z0, z1, y, holes)
		return SLAB(parent, x0, x1, z0, z1, y + 0.3, 0.3, CEILING, M.Plaster, holes, "ZR_CeilingTiles")
	end
	local function soffit(parent, x0, x1, z0, z1, y, holes)
		return SLAB(parent, x0, x1, z0, z1, y + 0.3, 0.3, hex("C4C0B5"), M.Plaster, holes, PAINT)
	end

	-- ── power: ceiling panels that light with the generator, emergency lights that are always on ─────────
	local power = { panels = {}, lights = {} }
	local PANEL_OFF, PANEL_ON = hex("9C9D98"), hex("F4EEDC")
	local function panel(parent, x, y, z, ry, withLight, range)
		local p = kit.part(parent, Vector3.new(2, 0.12, 4), CF(x, y - 0.06, z, ry), PANEL_OFF, M.SmoothPlastic)
		p.CastShadow = false
		p.CanCollide = false
		p.CanQuery = false
		p.Name = "CeilingPanel"
		noDetail(p)
		if rng:NextNumber() < 0.12 then
			p.Color = hex("6E6F6A") -- dead tube: stays dark
			return p
		end
		table.insert(power.panels, p)
		if withLight then
			local l = kit.light(p, hex("FFF1D6"), math.min(range or 34, 36), 1.1, false)
			l.Enabled = false
			table.insert(power.lights, l)
		end
		return p
	end
	-- a grid of panels over an area (every `step` studs; one in `lightEvery` carries a light)
	local function panels(parent, x0, x1, z0, z1, y, step, lightEvery, range)
		local i = 0
		local x = x0 + step / 2
		while x < x1 do
			local z = z0 + step / 2
			while z < z1 do
				i += 1
				panel(parent, x, y, z, 0, i % ((lightEvery or 4) * 3) == 1, range) -- lights budget: one in 3x lightEvery
				z += step
			end
			x += step
		end
	end
	local EXIT_GREEN = hex("2FAF5A")
	local function exitSign(parent, x, y, z, ry)
		local s = kit.part(parent, Vector3.new(2.2, 0.8, 0.3), CF(x, y, z, ry), EXIT_GREEN, M.Neon)
		s.CastShadow = false
		s.CanCollide = false
		s.Name = "ExitSign"
		noDetail(s)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0
		g.Parent = s
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = "EXIT"
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.Parent = g
		local g2 = g:Clone()
		g2.Face = Enum.NormalId.Back
		g2.Parent = s
		kit.light(s, EXIT_GREEN, 9, 0.35, false)
		return s
	end
	local function emergencyLamp(parent, x, y, z)
		local p = kit.part(parent, Vector3.new(1, 0.5, 0.6), CF(x, y, z), hex("D86A3A"), M.Neon)
		p.CastShadow = false
		p.CanCollide = false
		noDetail(p)
		kit.light(p, hex("FF8A4A"), 20, 0.45, false)
		return p
	end

	-- ── store signs (sign box with lettering; some letters dead or missing) ─────────────────────────────
	local function sign(parent, text, x, y, z, ry, w, h, colors)
		colors = colors or {}
		local box = kit.part(parent, Vector3.new(w, h, 0.5), CF(x, y, z, ry), colors.box or hex("2A2B2E"), M.Metal)
		box.CanCollide = false
		box.Name = "StoreSign"
		noDetail(box)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 30
		g.LightInfluence = 0.85
		g.Parent = box
		-- wear: one letter missing in some signs
		local shown = text
		if #text > 4 and rng:NextNumber() < 0.45 then
			local k = rng:NextInteger(1, #text)
			if string.sub(text, k, k) ~= " " then
				shown = string.sub(text, 1, k - 1) .. " " .. string.sub(text, k + 1)
			end
		end
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(0.92, 0.8)
		t.Position = UDim2.fromScale(0.04, 0.1)
		t.BackgroundTransparency = 1
		t.Text = shown
		t.TextColor3 = colors.text or hex("E8E2D0")
		t.Font = colors.font or Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextTransparency = 0.05
		t.Parent = g
		return box
	end
	local function poster(parent, x, y, z, ry, w, h, text, bg)
		local p = kit.part(parent, Vector3.new(w, h, 0.06), CF(x, y, z, ry), bg or hex("5A4E6A"), M.SmoothPlastic)
		p.CanCollide = false
		p.CanQuery = false
		noDetail(p)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 24
		g.LightInfluence = 1
		g.Parent = p
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(0.86, 0.6)
		t.Position = UDim2.fromScale(0.07, 0.2)
		t.BackgroundTransparency = 1
		t.Text = text
		t.TextColor3 = hex("EDE6D2")
		t.Font = Enum.Font.Oswald
		t.TextScaled = true
		t.TextWrapped = true
		t.Parent = g
		return p
	end

	-- ── storefront line: 16-stud modules along x at z, front toward `facing` (+1 south, -1 north) ─────────
	-- kinds: "front" (glass, door), "broken", "shutter", "half", "bent", "wall" (plaster infill)
	local function frontLine(parent, x0, z, y0, facing, kinds, fasciaTop)
		local ry = facing > 0 and 180 or 0
		for i, k in kinds do
			local x = x0 + (i - 0.5) * 16
			if k == "front" then
				K(parent, "StoreFront", x, y0, z, ry)
			elseif k == "broken" then
				K(parent, "StoreFrontBroken", x, y0, z, ry)
			elseif k == "shutter" then
				K(parent, "Shutter", x, y0, z, ry)
			elseif k == "half" then
				K(parent, "ShutterHalf", x, y0, z, ry)
			elseif k == "bent" then
				K(parent, "ShutterBent", x, y0, z, ry)
			else
				BOX(parent, x - 8, x + 8, y0, y0 + 12, z - 0.4, z + 0.4, PLASTER_W, M.Plaster, PAINT)
			end
		end
		local x1 = x0 + #kinds * 16
		-- fascia band above the fronts up to the slab
		BOX(parent, x0, x1, y0 + 12, fasciaTop, z - 0.5, z + 0.5, FASCIA, M.Plaster, PAINT)
	end

	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	-- SITE
	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	local site = kit.model("Site", map)
	-- ground: car park south, roads west and south, the yard north, staff parking east, pavement round the building
	BOX(site, -210, 210, -1, 0, 76, 186, C.asphalt, M.Asphalt) -- car park
	BOX(site, -210, 210, -1, 0.02, 186, 202, hex("383B3A"), M.Asphalt) -- main road
	BOX(site, -210, -180, -1, 0, -156, 76, C.asphalt, M.Asphalt) -- west road
	BOX(site, -180, -162, -1, 0, -156, 76, hex("777770"), M.Concrete, "ZR_FloorConcrete") -- under the ramp
	BOX(site, -162, 162, -1, 0, -156, -96, hex("74746E"), M.Concrete, "ZR_FloorConcrete") -- north yard
	BOX(site, 162, 210, -1, 0, -156, 76, C.asphalt, M.Asphalt) -- east staff parking
	BOX(site, -162, 162, -1, 0, 72, 76, hex("8E8D86"), M.Concrete, "ZR_FloorConcrete") -- pavement south
	BOX(site, 160, 162, -1, 0, -96, 72, hex("8E8D86"), M.Concrete, "ZR_FloorConcrete")
	BOX(site, -162, -160, -1, 0, -96, 72, hex("8E8D86"), M.Concrete, "ZR_FloorConcrete")
	for _, g in { { -500, 500, -500, -156 }, { -500, 500, 202, 500 }, { -500, -210, -156, 202 }, { 210, 500, -156, 202 } } do
		noDetail(BOX(site, g[1], g[2], -1.5, -0.5, g[3], g[4], hex("4F4D42"), M.Ground))
	end
	-- road markings: car park bays (rows facing each other), centre lines on the road
	local LINE = hex("C9C3AE")
	for _, row in { { 96, 1 }, { 120, -1 }, { 136, 1 }, { 160, -1 } } do
		for x = -196, 196, 8 do
			if math.abs(x) > 24 or row[1] > 130 then
				noDetail(BOX(site, x - 0.15, x + 0.15, 0, 0.04, row[1], row[1] + row[2] * 14, LINE, M.SmoothPlastic))
			end
		end
	end
	for x = -200, 200, 14 do
		noDetail(BOX(site, x, x + 7, 0.02, 0.06, 193.8, 194.2, hex("C2A44A"), M.SmoothPlastic))
	end
	-- kerbed islands with dead planters in the car park
	for _, isl in { { -120, 128 }, { -40, 128 }, { 40, 128 }, { 120, 128 } } do
		BOX(site, isl[1] - 10, isl[1] + 10, 0, 0.5, isl[2] - 2, isl[2] + 2, hex("8A8880"), M.Concrete)
		K(site, "Planter", isl[1], 0, isl[2], rng:NextNumber(0, 360))
	end
	-- boundary: invisible walls, hoarding along the north and east, low walls south
	for _, b in { { 0, -158, 440, 4 }, { 0, 204, 440, 4 }, { -212, 24, 4, 380 }, { 212, 24, 4, 380 } } do
		local inv = kit.box(site, b[3], 140, b[4], O.X + b[1], 60, O.Z + b[2], C.pale, M.SmoothPlastic)
		inv.Transparency = 1
		inv.CanQuery = false
		inv.Name = "Boundary"
		noDetail(inv)
	end
	for x = -150, 150, 12 do
		if math.abs(x - 180) > 10 then
			K(site, "Hoarding", x, 0, -154, 0)
		end
	end
	for z = -150, 70, 12 do
		K(site, "Hoarding", 208, 0, z, 90)
		K(site, "Hoarding", -208, 0, z, 90)
	end
	-- distant buildings (no collision): housing blocks and a few towers on the horizon
	for k = 1, 22 do
		local ang = (k / 22) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local r = rng:NextNumber(470, 640)
		local tower = k % 5 == 0
		local sx, sz = tower and rng:NextNumber(26, 34) or rng:NextNumber(60, 110), tower and rng:NextNumber(26, 34) or rng:NextNumber(24, 34)
		local h = tower and rng:NextNumber(80, 120) or rng:NextNumber(28, 46)
		local s = kit.box(site, sx, h, sz, O.X + math.cos(ang) * r, h / 2 - 1, O.Z + math.sin(ang) * r, kit.jitter(hex("6A6C68"), 0.12), M.Concrete, math.deg(-ang) + 90)
		s.CanCollide = false
		s.CastShadow = false
		noDetail(s)
		s:SetAttribute("Wear", "ZR_ConcretePanel")
	end

	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	-- BUILDING SHELL
	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	local shell = kit.model("Shell", map)
	-- ground slab under the whole building (floors sit on it)
	BOX(shell, -160, 160, -1, 0, -96, 72, SLAB_C, M.Concrete)
	-- exterior walls: supermarket block (one storey + parapet) and the main block (two storeys + parapet)
	WX(shell, -160, -96, -95, 0, 19.2, 2, EXT, M.Concrete, { { -140, 8, 0, 9 } }, "ZR_ConcretePanel") -- warehouse dock door
	WX(shell, -160, -96, 71, 0, 19.2, 2, EXT, M.Concrete, { { -128, 16, 0, 9 } }, "ZR_ConcretePanel") -- supermarket car-park entrance
	WZ(shell, -96, 72, -159, 0, 19.2, 2, EXT, M.Concrete, {}, "ZR_ConcretePanel")
	local docks = { -60, -36, -12 }
	local northHoles = { { 40, 4, 0, 7.6 } }
	for _, dx in docks do
		table.insert(northHoles, { dx, 12, 0, 12 })
	end
	table.insert(northHoles, { 66, 9, 0, 10.5 }) -- cargo lift
	WX(shell, -96, 160, -95, 0, YR + 3, 2, EXT, M.Concrete, northHoles, "ZR_ConcretePanel")
	-- south facade: the lobby is a glass curtain wall (x -16..16), the rest concrete with window strips upstairs
	WX(shell, -96, 160, 71, 0, YR + 3, 2, EXT, M.Concrete, {
		{ 0, 32, 0, YR - 1 },
		{ -64, 56, Y2 + 3, Y2 + 10 }, { 80, 30, Y2 + 3, Y2 + 10 },
	}, "ZR_ConcretePanel")
	WZ(shell, -96, 72, 159, 0, YR + 3, 2, EXT, M.Concrete, { { -74, 4, 0, 7.6 }, { -4, 88, 6, 13 } }, "ZR_ConcretePanel")
	-- the main block's west wall above the supermarket roof (glass doors onto the roof car park)
	WZ(shell, -96, 72, -96, Y2, YR + 3 - Y2, 2, EXT, M.Concrete, { { 0, 16, 0, 8 } }, "ZR_ConcretePanel")
	-- facade bands
	for _, y in { Y2 - 0.6, YR - 0.6 } do
		BOX(shell, -97, 161, y, y + 1.2, -96.6, -95.6, EXT_D, M.Concrete)
		BOX(shell, -97, 161, y, y + 1.2, 71.6, 72.6, EXT_D, M.Concrete)
	end
	-- window glass (south strips, food-court east windows) and the lobby curtain wall
	local function glazing(parent, cf, w, h, frames)
		local g = kit.part(parent, Vector3.new(w, h, 0.2), cf, hex("6E8288"), M.Glass)
		g.Transparency = 0.55
		g.CastShadow = false
		noDetail(g)
		for k = 0, frames do
			local fx = -w / 2 + k * w / frames
			local f = kit.part(parent, Vector3.new(0.3, h, 0.4), cf * CFrame.new(fx, 0, 0), hex("3E4246"), M.Metal)
			noDetail(f)
		end
		return g
	end
	glazing(shell, CF(-64, Y2 + 6.5, 71), 56, 7, 7)
	glazing(shell, CF(80, Y2 + 6.5, 71), 30, 7, 4)
	glazing(shell, CF(159, 9.5, -4, 90), 88, 7, 11)
	-- lobby curtain wall: mullion grid, two door openings (the doors are gone)
	local lobby = kit.model("LobbyFacade", map)
	for k = 0, 8 do
		local x = -16 + k * 4
		noDetail(BOX(lobby, x - 0.2, x + 0.2, 0, YR - 1, 70.6, 71.4, hex("3E4246"), M.Metal))
	end
	for _, y in { 8.5, 17, 25.5, YR - 1.4 } do
		noDetail(BOX(lobby, -16, 16, y - 0.25, y + 0.25, 70.6, 71.4, hex("3E4246"), M.Metal))
	end
	for k = 0, 7 do
		local x = -14 + k * 4
		for j, band in { { 0, 8.25 }, { 8.75, 16.75 }, { 17.25, 25.25 }, { 25.75, YR - 1.65 } } do
			local doorway = j == 1 and (math.abs(x) < 9)
			local missing = (k == 6 and j == 2) or (k == 1 and j == 3)
			if not doorway and not missing then
				local g = BOX(lobby, x - 1.8, x + 1.8, band[1], band[2], 70.9, 71.1, hex("6E8288"), M.Glass)
				g.Transparency = 0.5
				g.CastShadow = false
				noDetail(g)
			end
		end
	end
	K(lobby, "GlassShards", 9.5, 0, 66, 30)
	K(lobby, "GlassShards", -10, 0, 76, 200)
	-- entrance canopy on posts
	BOX(lobby, -22, 22, 13, 14, 72, 86, hex("5A5D5E"), M.Metal)
	for _, x in { -20, 20 } do
		BOX(lobby, x - 0.6, x + 0.6, 0, 13, 84.4, 85.6, hex("3E4246"), M.Metal)
	end
	-- the MERIDIAN name on the facade over the lobby (two letters dark)
	sign(shell, "MERIDIAN", 0, 30, 73, 180, 30, 4.5, { box = hex("23252A"), text = hex("D9CFAE"), font = Enum.Font.Oswald })
	sign(shell, "KASSA", -128, 14.5, 72.4, 180, 18, 3.2, { box = hex("1E3A2A"), text = hex("E2D8B8") })
	sign(shell, "LUMEN CINEMA", 160.4, 30, -30, -90, 22, 3.6, { box = hex("2A1E2E"), text = hex("E8C878"), font = Enum.Font.Oswald })
	-- parapets and roof slabs (the supermarket roof is the roof car park, level with the upper floor)
	SLAB(shell, -160, 160, -96, 72, Y2, SL, SLAB_C, M.Concrete, {
		{ -20, 20, -26, 26 }, -- atrium void
		{ -16, 16, 40, 70 }, -- double-height lobby
		{ 21, 31, -38, -16 }, -- collapsed gallery floor
		{ -94, -80, -81, -64.4 }, { 80, 94, -81, -64.4 }, -- stair cores
	})
	SLAB(shell, -96, 160, -96, 72, YR, SL, SLAB_C, M.Concrete, { { -20, 20, -26, 26 } })
	WX(shell, -160, -96, -95, Y2, 1.4, 1.6, EXT_L, M.Concrete, {})
	WX(shell, -160, -96, 71, Y2, 1.4, 1.6, EXT_L, M.Concrete, {})
	WZ(shell, -96, 72, -159, Y2, 1.4, 1.6, EXT_L, M.Concrete, { { -32, 18, 0, 1.4 }, { -58, 6, 0, 1.4 } })
	-- roof clutter (seen from the roof car park)
	for _, h in { { -60, -60 }, { 40, -60 }, { 120, 0 }, { 60, 40 }, { -60, 50 } } do
		K(shell, "HVAC", h[1], YR, h[2], rng:NextInteger(0, 3) * 90)
	end

	-- ── skylight over the atrium void: a glass lantern on a steel grid, three panes gone ────────────────
	local sky = kit.model("Skylight", map)
	for _, e in { { -21, 21, -27, -25.5 }, { -21, 21, 25.5, 27 }, { -21, -19.5, -27, 27 }, { 19.5, 21, -27, 27 } } do
		BOX(sky, e[1], e[2], YR, YR + 2.5, e[3], e[4], EXT_L, M.Concrete)
	end
	local beam = hex("2F3336")
	for k = 0, 4 do
		local x = -20 + k * 10
		noDetail(BOX(sky, x - 0.3, x + 0.3, YR + 2.5, YR + 3.3, -26, 26, beam, M.Metal))
	end
	for k = 0, 4 do
		local z = -26 + k * 13
		noDetail(BOX(sky, -20, 20, YR + 2.5, YR + 3.3, z - 0.3, z + 0.3, beam, M.Metal))
	end
	local gone = { ["1,1"] = true, ["2,3"] = true, ["3,0"] = true }
	for i = 0, 3 do
		for j = 0, 3 do
			if not gone[i .. "," .. j] then
				local g = BOX(sky, -20 + i * 10 + 0.3, -10 + i * 10 - 0.3, YR + 3.1, YR + 3.25, -26 + j * 13 + 0.3, -13 + j * 13 - 0.3, hex("8FA3A6"), M.Glass)
				g.Transparency = 0.45
				g.CastShadow = false
				noDetail(g)
			end
		end
	end

	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	-- GROUND LEVEL (L1)
	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	local L1 = kit.model("Level1", map)
	local CE1 = 14 -- shop ceilings
	local SOF1 = Y2 - SL - 0.3 -- concourse soffit underside (16.5)

	-- concourse + atrium terrazzo, concourse soffit and panels
	floorTerrazzo(L1, -96, 96, -16, 16, 0.3)
	floorTerrazzo(L1, -32, 32, -40, -16, 0.3)
	floorTerrazzo(L1, -32, 32, 16, 40, 0.3)
	floorTerrazzo(L1, -16, 16, 40, 70, 0.3)
	soffit(L1, -96, -32, -16, 16, SOF1, { { -72, -56, -8, 8 } })
	K(L1, "CeilingHole", -64, SOF1, 0, 0)
	soffit(L1, 32, 96, -16, 16, SOF1)
	K(L1, "KioskBurnt", -64, 0.3, 0, 0)
	K(L1, "Kiosk", 64, 0.3, 0, 90)
	for _, b in { { -84, -10, 0 }, { -44, 10, 180 }, { 44, -10, 0 }, { 84, 10, 180 } } do
		K(L1, "Bench", b[1], 0.3, b[2], b[3])
	end
	for _, p in { { -84, 10 }, { 84, -10 }, { -44, -10 }, { 44, 10 } } do
		K(L1, "Planter", p[1], 0.3, p[2], 0)
	end
	K(L1, "Bin", -90, 0.3, 13, 0)
	K(L1, "Bin", 90, 0.3, -13, 0)
	K(L1, "VendingBroken", -94.4, 0.3, 12, 90)
	K(L1, "Vending", 94.4, 0.3, -12, -90)
	K(L1, "TrolleyTipped", -78, 0.3, 4, 60)
	K(L1, "CeilingDebris", -60, 0.3, 4, 0)
	soffit(L1, -32, 32, -40, 40, SOF1, { { -20, 20, -26, 26 }, { 21, 31, -38, -16 } })
	panels(L1, -96, -32, -14, 14, SOF1, 16, 2, 40)
	panels(L1, 32, 96, -14, 14, SOF1, 16, 2, 40)
	-- interior walls of the L1 grid
	local PW = PLASTER_W
	-- north row: back wall z -64 (doors to the stock rooms), corridor wall z -84
	local doorsN = {}
	for _, x in { -72, -48, 48 } do
		table.insert(doorsN, { x, 3.9, 0, 7.5 })
	end
	table.insert(doorsN, { 0, 3.9, 0, 7.5 }) -- VOLTA stock room (keyed)
	table.insert(doorsN, { 72, 3.9, 0, 7.5 }) -- bank vault (keycard)
	WX(L1, -96, 96, -64, 0, CE1, 0.8, PW, M.Plaster, doorsN, PAINT)
	BOX(L1, -96, 96, CE1, Y2 - SL, -64.4, -63.6, PW, M.Plaster) -- above the ceilings
	local corrDoors = {}
	for _, x in { -90, -72, -48, 48, 84 } do
		table.insert(corrDoors, { x, 3.9, 0, 7.5 })
	end
	WX(L1, -96, 96, -84, 0, Y2 - SL, 0.8, hex("9A988E"), M.Plaster, corrDoors, PEEL)
	-- north partitions
	WZ(L1, -84, -16, -64, 0, CE1, 0.8, PW, M.Plaster, { { -40, 8, 0, 9 } }, PAINT) -- the breach (WallBreach mesh)
	WZ(L1, -84, -16, 64, 0, CE1, 0.8, PW, M.Plaster, {}, PAINT)
	WZ(L1, -84, -16, -32, 0, CE1, 0.8, PW, M.Plaster, {}, PAINT)
	WZ(L1, -84, -16, 32, 0, CE1, 0.8, PW, M.Plaster, {}, PAINT)
	-- south row: back wall z 54, partitions, the lobby walls
	local doorsS = {}
	for _, x in { -80, -48, 48, 80 } do
		table.insert(doorsS, { x, 3.9, 0, 7.5 })
	end
	WX(L1, -96, -16, 54, 0, CE1, 0.8, PW, M.Plaster, { doorsS[1], doorsS[2] }, PAINT)
	WX(L1, 16, 96, 54, 0, CE1, 0.8, PW, M.Plaster, { doorsS[3], doorsS[4] }, PAINT)
	for _, x in { -64, -32, 32, 64 } do
		WZ(L1, 16, 70, x, 0, CE1, 0.8, PW, M.Plaster, {}, PAINT)
	end
	WZ(L1, 40, 70, -16, 0, Y2 - SL, 0.8, PW, M.Plaster, {}, PAINT)
	WZ(L1, 40, 70, 16, 0, Y2 - SL, 0.8, PW, M.Plaster, {}, PAINT)
	WX(L1, -32, -16, 54, 0, CE1, 0.8, PW, M.Plaster, { { -24, 3.9, 0, 7.5 } }, PAINT)
	WX(L1, 16, 32, 54, 0, CE1, 0.8, PW, M.Plaster, { { 24, 3.9, 0, 7.5 } }, PAINT)
	-- the supermarket wall (x -96): entrance from the concourse, a door from the corridor into the warehouse
	WZ(L1, -94, 70, -96, 0, Y2 - SL, 1, hex("9A988E"), M.Plaster, { { 0, 32, 0, CE1 }, { -89, 4, 0, 7.6 } }, PAINT)
	-- the food court boundary (x 96): concourse opening; the shops' east walls
	WZ(L1, -84, 70, 96, 0, Y2 - SL, 1, hex("9A988E"), M.Plaster, { { 0, 32, 0, CE1 + 2 } }, PAINT)

	-- storefront lines on the concourse (north row faces south, south row faces north) and round the atrium
	frontLine(L1, -96, -16, 0, 1, { "broken", "bent" }, SOF1 + 0.3) -- BOLTWORKS
	frontLine(L1, -64, -16, 0, 1, { "front", "shutter" }, SOF1 + 0.3) -- MEDIQ
	frontLine(L1, 32, -16, 0, 1, { "front", "broken" }, SOF1 + 0.3) -- KAVA
	frontLine(L1, 64, -16, 0, 1, { "shutter", "front" }, SOF1 + 0.3) -- MERIDIAN SAVINGS
	frontLine(L1, -96, 16, 0, -1, { "broken", "front" }, SOF1 + 0.3) -- NORDA
	frontLine(L1, -64, 16, 0, -1, { "half", "front" }, SOF1 + 0.3) -- TOYBOX
	frontLine(L1, 32, 16, 0, -1, { "front", "broken" }, SOF1 + 0.3) -- PEAKLINE
	frontLine(L1, 64, 16, 0, -1, { "broken", "shutter" }, SOF1 + 0.3) -- AURUM
	frontLine(L1, -32, -40, 0, 1, { "front", "broken", "half", "front" }, SOF1 + 0.3) -- VOLTA onto the atrium
	frontLine(L1, -32, 40, 0, -1, { "front" }, SOF1 + 0.3) -- CELLFIX
	frontLine(L1, 16, 40, 0, -1, { "broken" }, SOF1 + 0.3) -- KEYS & HEELS
	-- atrium side walls between the concourse and the atrium square (x ±32, z -40..-16 and 16..40)
	for _, x in { -32, 32 } do
		WZ(L1, -40, -16, x, 0, SOF1 + 0.3, 0.8, FASCIA, M.Plaster, {}, PAINT)
		WZ(L1, 16, 40, x, 0, SOF1 + 0.3, 0.8, FASCIA, M.Plaster, {}, PAINT)
	end
	-- signs
	local SIGNS1 = {
		{ "BOLTWORKS", -80, -15.2, 180, { box = hex("3A2A1E"), text = hex("E8A84A") } },
		{ "MEDIQ", -48, -15.2, 180, { box = hex("E8E8E2"), text = hex("2E8A5A") } },
		{ "KAVA", 48, -15.2, 180, { box = hex("2E2420"), text = hex("D8B888") } },
		{ "MERIDIAN SAVINGS", 80, -15.2, 180, { box = hex("1E2A3A"), text = hex("C8B878") } },
		{ "NORDA", -80, 15.2, 0, { box = hex("E2DCD0"), text = hex("2A2A2E") } },
		{ "TOYBOX", -48, 15.2, 0, { box = hex("D8462E"), text = hex("F8E85A") } },
		{ "PEAKLINE", 48, 15.2, 0, { box = hex("1E3A4E"), text = hex("F2F2E8") } },
		{ "AURUM", 80, 15.2, 0, { box = hex("1A1A1C"), text = hex("D8B860") } },
		{ "VOLTA", 0, -39.2, 180, { box = hex("121416"), text = hex("F2D23A") } },
		{ "CELLFIX", -24, 39.2, 0, { box = hex("2E3E7E"), text = hex("F2F2F2") } },
		{ "KEYS & HEELS", 24, 39.2, 0, { box = hex("4E2E1E"), text = hex("E8D8B8") } },
	}
	for _, s in SIGNS1 do
		sign(L1, s[1], s[2], 14.2, s[3], s[4], (s[1] == "VOLTA") and 20 or 13, 2.6, s[5])
	end

	-- ── atrium: fountain, escalators, columns, the collapsed gallery floor ──────────────────────────────
	local atr = kit.model("Atrium", map)
	K(atr, "Fountain", 0, 0.3, 0, 0)
	K(atr, "Escalator", -16.75, 0.3, 8, 0) -- rises north to the gallery at z -26
	K(atr, "Escalator", 16.75, 0.3, -8, 180) -- rises south to the gallery at z 26
	-- walkable shapes for the escalators: the step line, side guards
	local function ramp(x, zBottom, zTop, yBottom, yTop, width, walls)
		local a, b = V(x, yBottom, zBottom), V(x, yTop, zTop)
		local len = (b - a).Magnitude
		local look = CFrame.lookAt((a + b) / 2, b)
		local r = kit.part(atr, Vector3.new(width, 0.4, len), look * CFrame.new(0, -0.2, 0), hex("3A3C3E"), M.Metal)
		r.Transparency = 1
		r.Name = "EscalatorTread"
		noDetail(r)
		if walls then
			for _, s in { -1, 1 } do
				local wl = kit.part(atr, Vector3.new(0.3, 4.4, len), look * CFrame.new(s * (width / 2 + 0.2), 2.2, 0), hex("3A3C3E"), M.Metal)
				wl.Transparency = 1
				wl.Name = "EscalatorGuard"
				noDetail(wl)
			end
		end
		return r
	end
	ramp(-16.75, 5, -26, 0.3, Y2, 3.6, true)
	ramp(16.75, -5, 26, 0.3, Y2, 3.6, true)
	-- gallery columns (one spalled to the core next to the collapse)
	for _, c in { { -26, -33 }, { -26, 0 }, { -26, 33 }, { 26, 33 } } do
		K(atr, "Column", c[1], 0.3, c[2], 0)
	end
	K(atr, "ColumnDamaged", 26, 0.3, 0, 90)
	-- the collapsed gallery slab: from the hole's north edge down onto rubble, climbable both ways
	K(atr, "SlabCollapse", 26, 0, -18, 0, { variants = { stone = "ZR_Terrazzo" } })
	do
		local top, bot = V(26, Y2 - 0.3, -38), V(26, 3.6, -18)
		local len = (top - bot).Magnitude
		local look = CFrame.lookAt((top + bot) / 2, top)
		local s = kit.part(atr, Vector3.new(11, 0.5, len), look * CFrame.new(0, -0.25, 0), hex("6E6E68"), M.Concrete)
		s.Transparency = 1
		s.Name = "CollapseSlope"
		noDetail(s)
		-- rubble ramp from the floor up to the slab's low end
		local wd = kit.part(atr, Vector3.new(10, 3.6, 7), CF(26, 1.8, -14.5, 180), hex("6E6E68"), M.Concrete, "WedgePart")
		wd.Transparency = 1
		wd.Name = "RubbleRamp"
		noDetail(wd)
		K(atr, "RubbleB", 26, 0.3, -13.5, 20)
		K(atr, "BrokenEdge", 26, Y2, -38, 180)
		K(atr, "BrokenEdge", 26, Y2, -16, 0)
		K(atr, "RubbleA", 22, 0.3, -24, 70)
		K(atr, "CeilingDebris", 30, 0.3, -30, 0)
	end
	-- glass and leaves under the missing skylight panes
	K(atr, "GlassShards", -5, 0.3, -6, 0)
	K(atr, "GlassShards", 15, 0.3, 14, 120)
	K(atr, "GlassShards", 4, 0.3, -24, 200)
	K(atr, "TrolleyTipped", 9, 0.3, 11, 140)
	K(atr, "Bench", -10, 0.3, -30, 0)
	K(atr, "Bench", 10, 0.3, 30, 180)
	K(atr, "Planter", -28, 0.3, 22, 0)
	K(atr, "Planter", 28, 0.3, -24, 0)
	K(atr, "Bin", 6, 0.3, -31, 0)
	-- the gallery edge above: balustrades (one broken), openings at the escalator heads
	local gal = kit.model("Gallery", map)
	for _, x in { -8, 0, 8, 16 } do
		K(gal, (x == 8) and "BalustradeBroken" or "Balustrade", x, Y2, -26, 0)
	end
	for _, x in { -16, -8, 0, 8 } do
		K(gal, (x == -8) and "BalustradeBroken" or "Balustrade", x, Y2, 26, 180)
	end
	for _, z in { -22, -14, -6, 2, 10, 18 } do
		K(gal, "Balustrade", -20, Y2, z, 90)
		if z < -10 or z > 0 then
			K(gal, "Balustrade", 20, Y2, z, -90)
		end
	end
	K(gal, "BalustradeBroken", 20, Y2, -6, -90)
	K(gal, "Balustrade", -20, Y2, 24, 90) -- the short end by the south-west corner
	for _, x in { -12, -4, 4, 12 } do
		K(gal, "Balustrade", x, Y2, 40, 0) -- over the double-height lobby
	end

	-- ── supermarket KASSA ────────────────────────────────────────────────────────────────────────────────
	local sm = kit.model("Supermarket", map)
	floorVinyl(sm, -158, -96, -74.6, 70, 0.3)
	floorConcrete(sm, -158, -96, -94, -74.6, 0.3)
	ceiling(sm, -158, -96, -74.6, 70, CE1, { { -150, -134, -40, -24 }, { -126, -110, 26, 42 } })
	K(sm, "CeilingHole", -142, CE1, -32, 0)
	K(sm, "CeilingCollapse", -118, CE1, 34, 0)
	K(sm, "CeilingDebris", -118, 0.3, 34, 40)
	panels(sm, -158, -96, -74, 70, CE1, 16, 3, 40)
	BOX(sm, -158, -96, CE1 + 0.3, Y2 - SL, -75, -74.2, PW, M.Plaster)
	-- warehouse partition with two wide openings
	WX(sm, -158, -96, -74.6, 0, CE1, 0.8, hex("A8A498"), M.Plaster, { { -140, 10, 0, 10 }, { -110, 10, 0, 10 } }, PEEL)
	-- checkouts across the exit, trolleys at the entrance
	local regN = 0
	for _, z in { -60, -48, -36, -24, 24, 36, 48, 60 } do
		local m = K(sm, "Checkout", -106, 0.3, z, 0)
		regN += 1
		if regN % 3 == 1 and m then
			kit.container(sm, "MM_REG" .. regN, "register", "Till", CF(-106, 0.3, z), m:FindFirstChild("KitCollider"))
		end
	end
	K(sm, "TrolleyRow", -100, 0.3, 4, 90)
	K(sm, "TrolleyRow", -100, 0.3, -6, 90)
	K(sm, "Trolley", -112, 0.3, 12, 200)
	K(sm, "TrolleyTipped", -118, 0.3, -12, 30)
	-- aisles of gondolas (long axis along x), some sparse, two toppled
	local rowZ = { -62, -50, -38, -26, -14, -2, 10, 22, 34, 46, 58 }
	for ri, z in rowZ do
		for xi, x in { -144, -136, -128, -120 } do
			local roll = rng:NextNumber()
			local name = roll < 0.6 and "Gondola" or "GondolaSparse"
			if (ri == 4 and xi == 2) or (ri == 9 and xi == 3) then
				name = "GondolaToppled"
			end
			if not (ri == 9 and xi == 4) then -- under the collapsed ceiling
				K(sm, name, x, 0.3, z, 0)
			end
		end
	end
	-- fridge wall (west), a broken door here and there
	local fz = -66
	local fi = 0
	while fz <= 46 do
		fi += 1
		local m = K(sm, (fi % 4 == 2) and "FridgeBroken" or "Fridge", -156.3, 0.3, fz + 4, -90)
		if fi % 5 == 3 and m then
			kit.container(sm, "MM_FRIDGE" .. fi, "cooler", "Drinks fridge", CF(-156.3, 0.3, fz + 4), m:FindFirstChild("KitCollider"))
		end
		fz += 8
	end
	-- deli counter (south-west) and wall shelving on the north partition
	K(sm, "FoodCounter", -150, 0.3, 64, 0)
	for _, x in { -150, -126, -118 } do
		K(sm, "WallShelf", x, 0.3, -73.2, 180)
	end
	-- warehouse: racking, pallets, roll cages, the forklift
	for _, x in { -150, -134, -118 } do
		K(sm, "PalletRack", x, 0.3, -91.6, 0)
	end
	K(sm, "Forklift", -104, 0.3, -86, 70)
	local pb = K(sm, "PalletBoxes", -126, 0.3, -80, 15)
	if pb then
		kit.container(sm, "MM_SMW1", "grocery", "Delivery pallet", CF(-126, 0.3, -80), pb:FindFirstChild("KitCollider"))
	end
	K(sm, "PalletBoxes", -146, 0.3, -80, -10)
	local rc = K(sm, "RollCage", -102, 0.3, -78, 90)
	if rc then
		kit.container(sm, "MM_SMW2", "grocery", "Roll cage", CF(-102, 0.3, -78), rc:FindFirstChild("KitCollider"))
	end
	K(sm, "RollCage", -100, 0.3, -80, 0)
	K(sm, "CardboardPile", -134, 0.3, -83, 0)
	-- signs inside, exit signs, emergency lights
	exitSign(sm, -97, 9, -89, 90)
	exitSign(sm, -136, 10, 70.2, 0)
	emergencyLamp(sm, -110, 13, -74)
	emergencyLamp(sm, -150, 13, 20)

	-- ── BOLTWORKS hardware (N1) ──────────────────────────────────────────────────────────────────────────
	local n1 = kit.model("Boltworks", map)
	floorConcrete(n1, -96, -64, -64, -16, 0.3)
	ceiling(n1, -96, -64, -64, -16, CE1, { { -88, -72, -56, -40 } })
	K(n1, "CeilingHole", -80, CE1, -48, 90)
	panels(n1, -96, -64, -64, -16, CE1, 16, 2, 30)
	for _, z in { -56, -46, -36, -26 } do
		K(n1, "WallShelfTools", -94.7, 0.3, z, -90)
	end
	K(n1, "StorageShelf", -80, 0.3, -52, 0)
	K(n1, "StorageShelf", -80, 0.3, -36, 180)
	K(n1, "GondolaToppled", -78, 0.3, -27, 10)
	K(n1, "Checkout", -71, 0.3, -21, 90)
	K(n1, "PalletBoxes", -70, 0.3, -58, 25)
	kit.container(n1, "MM_BW1", "toolbox", "Workshop toolbox", CF(-90, 0.3, -61, 180))
	kit.container(n1, "MM_BW2", "toolbox", "Counter toolbox", CF(-68, 0.3, -30, 90))
	-- the breach through to MEDIQ
	do
		local wb = K(n1, "WallBreach", -64, 0.3, -40, 90)
		local _ = wb
	end

	-- ── MEDIQ pharmacy (N2) ──────────────────────────────────────────────────────────────────────────────
	local n2 = kit.model("Mediq", map)
	floorTiles(n2, -64, -32, -64, -16, 0.3, hex("E6E6E0"))
	ceiling(n2, -64, -32, -64, -16, CE1)
	panels(n2, -64, -32, -64, -16, CE1, 16, 2, 30)
	for _, z in { -46, -36, -26 } do
		K(n2, "WallShelfMeds", -33.3, 0.3, z, 90)
	end
	K(n2, "WallShelfMeds", -56, 0.3, -21, 0)
	K(n2, "Gondola", -48, 0.3, -31, 90, { tint = { plastic = hex("DDE6EE") } })
	-- the counter and the keyed dispensary behind it (z -64..-52)
	WX(n2, -64, -32, -52, 0, CE1, 0.6, hex("E2E2DC"), M.Plaster, { { -48, 3.9, 0, 7.5 } }, PAINT)
	K(n2, "Checkout", -42, 0.3, -48, 180)
	W.doors.MM_MEDIQ = { id = "MM_MEDIQ", cf = CF(-48, 3.75, -52), size = Vector3.new(3.9, 7.4, 0.35), key = "KEY_MEDIQ", label = "MEDIQ dispensary", parent = n2, color = hex("C8CCC8") }
	for _, x in { -60, -52 } do
		local m = K(n2, "WallShelfMeds", x, 0.3, -62.7, 180)
		if m then
			kit.container(n2, "MM_MQ" .. x, "pharmacy", "Dispensary shelf", CF(x, 0.3, -62.7), m:FindFirstChild("KitCollider"))
		end
	end
	kit.container(n2, "MM_MQ3", "medbag", "Pharmacist's bag", CF(-38, 0.3, -58, -90))
	K(n2, "CeilingDebris", -44, 0.3, -58, 0)

	-- ── VOLTA electronics (N3, onto the atrium) and its keyed stock room ─────────────────────────────────
	local n3 = kit.model("Volta", map)
	floorTiles(n3, -32, 32, -64, -40, 0.3, hex("7A7C7E"))
	ceiling(n3, -32, 32, -64, -40, CE1)
	panels(n3, -32, 32, -64, -40, CE1, 16, 2, 30)
	for _, x in { -26, -18, 18, 26 } do
		K(n3, "TVWall", x, 0.3, -63, 180)
	end
	for _, p in { { -18, -52 }, { -6, -52 }, { 6, -52 }, { 18, -52 }, { -12, -46 }, { 12, -46 } } do
		K(n3, "TechTable", p[1], 0.3, p[2], rng:NextInteger(-8, 8))
	end
	K(n3, "Checkout", 0, 0.3, -60, 180)
	K(n3, "TrolleyTipped", -4, 0.3, -43, 70)
	W.doors.MM_VOLTA = { id = "MM_VOLTA", cf = CF(0, 3.75, -64), size = Vector3.new(3.9, 7.4, 0.35), key = "KEY_VOLTA_STORE", label = "VOLTA stock room", parent = n3, color = hex("3A3E42") }
	-- stock room (two halves x -32..0 and 0..32, the door opens into the west half; the east half via a gap)
	local vs = kit.model("VoltaStock", map)
	floorConcrete(vs, -32, 32, -84, -64, 0.3)
	ceiling(vs, -32, 32, -84, -64, CE1)
	panels(vs, -32, 32, -84, -64, CE1, 16, 2, 26)
	for i, p in { { -26, -80, 0 }, { -14, -80, 0 }, { 14, -80, 0 }, { 26, -80, 0 }, { -26, -69, 180 }, { 26, -69, 180 } } do
		local m = K(vs, "StorageShelf", p[1], 0.3, p[2], p[3])
		if m and i <= 4 then
			kit.container(vs, "MM_VS" .. i, "techbox", "VOLTA stock shelf", CF(p[1], 0.3, p[2]), m:FindFirstChild("KitCollider"))
		end
	end
	K(vs, "RollCage", -6, 0.3, -76, 10)
	K(vs, "CardboardPile", 8, 0.3, -72, 0)

	-- ── KAVA café (N4) ──────────────────────────────────────────────────────────────────────────────────
	local n4 = kit.model("Kava", map)
	floorTiles(n4, 32, 64, -64, -16, 0.3, hex("C8A890"))
	ceiling(n4, 32, 64, -64, -16, CE1, { { 40, 56, -40, -24 } })
	K(n4, "CeilingHole", 48, CE1, -32, 0)
	panels(n4, 32, 64, -64, -16, CE1, 16, 2, 30)
	K(n4, "FoodCounter", 48, 0.3, -58, 180)
	K(n4, "FoodTableMess", 40, 0.3, -42, 0)
	K(n4, "FoodTable", 56, 0.3, -42, 20)
	K(n4, "FoodTableMess", 48, 0.3, -27, 45)
	K(n4, "Vending", 61.5, 0.3, -24, -90)
	kit.container(n4, "MM_KV1", "drawer", "Café till drawer", CF(42, 0.3, -52, 180))

	-- ── MERIDIAN SAVINGS bank (N5) and the vault ───────────────────────────────────────────────────────
	local n5 = kit.model("Bank", map)
	floorTerrazzo(n5, 64, 96, -64, -16, 0.3)
	ceiling(n5, 64, 96, -64, -16, CE1)
	panels(n5, 64, 96, -64, -16, CE1, 16, 2, 30)
	K(n5, "TicketBooth", 80, 0.3, -44, 180, { tint = { wood = hex("B8A890") } })
	K(n5, "OfficeDesk", 70, 0.3, -58, 180)
	K(n5, "OfficeDesk", 88, 0.3, -58, 180)
	kit.container(n5, "MM_BK1", "drawer", "Teller drawer", CF(76, 0.3, -48, 180))
	kit.container(n5, "MM_BK2", "drawer", "Manager's desk", CF(91, 0.3, -61, 180))
	K(n5, "ATM", 66.5, 0.3, -12.5, 0)
	K(n5, "ATM", 69.5, 0.3, -12.5, 0)
	W.doors.MM_VAULT = { id = "MM_VAULT", cf = CF(72, 3.75, -64), size = Vector3.new(3.9, 7.4, 0.4), key = "CARD_MALL_VAULT", card = true, label = "Savings vault", parent = n5, color = hex("5A5E62") }
	local vault = kit.model("Vault", map)
	floorConcrete(vault, 64, 80, -84, -64, 0.3)
	ceiling(vault, 64, 80, -84, -64, CE1)
	panel(vault, 72, CE1, -74, 0, true, 20)
	kit.container(vault, "MM_VLT1", "safe", "Vault safe", CF(66, 0.3, -82, 180))
	kit.container(vault, "MM_VLT2", "safe", "Deposit safe", CF(78, 0.3, -82, 180))
	H.desk(vault, 72, 0.3, -70, 5, 2.4)

	-- ── NORDA clothing (S1) ──────────────────────────────────────────────────────────────────────────────
	local s1 = kit.model("Norda", map)
	floorWood(s1, -96, -64, 16, 54, 0.3)
	ceiling(s1, -96, -64, 16, 54, CE1)
	panels(s1, -96, -64, 16, 54, CE1, 16, 2, 30)
	for i, p in { { -88, 28 }, { -76, 28 }, { -88, 40 }, { -76, 42 }, { -70, 32 } } do
		local m = K(s1, (i == 4) and "ClothesRackFallen" or "ClothesRack", p[1], 0.3, p[2], rng:NextInteger(0, 90))
		if i == 2 and m then
			kit.container(s1, "MM_ND1", "jacket", "Coat rack", CF(p[1], 0.3, p[2]), m:FindFirstChild("KitCollider"))
		end
	end
	for _, p in { { -92, 21, 0 }, { -68, 21, 0 } } do
		K(s1, "Mannequin", p[1], 0.3, p[2], p[3])
	end
	K(s1, "MannequinFallen", -82, 0.3, 20, 30)
	K(s1, "DisplayTable", -80, 0.3, 49, 0)
	K(s1, "WallShelfSparse", -94.7, 0.3, 44, 90, { tint = { plastic = hex("A8A4A0") } })

	-- ── TOYBOX (S2) ──────────────────────────────────────────────────────────────────────────────────────
	local s2 = kit.model("Toybox", map)
	floorVinyl(s2, -64, -32, 16, 54, 0.3, hex("D8E2E8"))
	ceiling(s2, -64, -32, 16, 54, CE1, { { -56, -40, 30, 46 } })
	K(s2, "CeilingCollapse", -48, CE1, 38, 90)
	K(s2, "CeilingDebris", -48, 0.3, 38, 0)
	panels(s2, -64, -32, 16, 54, CE1, 16, 2, 30)
	K(s2, "WallShelf", -62.7, 0.3, 28, 90)
	K(s2, "WallShelfSparse", -33.3, 0.3, 30, -90)
	K(s2, "GondolaSparse", -48, 0.3, 24, 90)
	K(s2, "Checkout", -40, 0.3, 50, 0)

	-- ── small units on the atrium: CELLFIX (phones) and KEYS & HEELS (key cutting) ──────────────────────
	local su = kit.model("SmallUnits", map)
	floorTiles(su, -32, -16, 40, 54, 0.3, hex("C8CCD4"))
	floorTiles(su, 16, 32, 40, 54, 0.3, hex("C8B8A0"))
	ceiling(su, -32, -16, 40, 54, CE1)
	ceiling(su, 16, 32, 40, 54, CE1)
	panel(su, -24, CE1, 47, 0, true, 22)
	panel(su, 24, CE1, 47, 0, true, 22)
	K(su, "TechTable", -24, 0.3, 46, 0)
	K(su, "Checkout", -24, 0.3, 51.5, 180)
	K(su, "WallShelfSparse", 24, 0.3, 52.7, 180, { tint = { plastic = hex("C8B88A") } })
	K(su, "Checkout", 24, 0.3, 45, 0)
	kit.container(su, "MM_CF1", "drawer", "Repair bench drawer", CF(-30, 0.3, 50, 90))

	-- ── PEAKLINE sports and outdoor (S3) ───────────────────────────────────────────────────────────────
	local s3 = kit.model("Peakline", map)
	floorTiles(s3, 32, 64, 16, 54, 0.3, hex("9EA4A8"))
	ceiling(s3, 32, 64, 16, 54, CE1)
	panels(s3, 32, 64, 16, 54, CE1, 16, 2, 30)
	K(s3, "Treadmill", 38, 0.3, 26, 0)
	K(s3, "Treadmill", 44, 0.3, 26, 0)
	K(s3, "WeightRack", 56, 0.3, 24, 0)
	K(s3, "ClothesRack", 40, 0.3, 40, 0)
	K(s3, "WallShelfTools", 62.7, 0.3, 36, -90)
	-- the hunting counter at the back: weapon boxes behind it
	K(s3, "Checkout", 48, 0.3, 46, 0)
	kit.container(s3, "MM_PK1", "weaponbox", "Hunting counter case", CF(42, 0.3, 51.5, 180))
	kit.container(s3, "MM_PK2", "weaponbox", "Ammunition cabinet", CF(56, 0.3, 51.5, 180))

	-- ── AURUM jeweller (S4) ─────────────────────────────────────────────────────────────────────────────
	local s4 = kit.model("Aurum", map)
	floorTerrazzo(s4, 64, 96, 16, 54, 0.3)
	ceiling(s4, 64, 96, 16, 54, CE1)
	panels(s4, 64, 96, 16, 54, CE1, 16, 2, 30)
	for _, p in { { 72, 28, 0 }, { 88, 28, 0 }, { 80, 38, 90 }, { 70, 46, 0 }, { 90, 46, 0 } } do
		K(s4, "JewelCase", p[1], 0.3, p[2], p[3])
	end
	K(s4, "GlassShards", 80, 0.3, 30, 0)
	kit.container(s4, "MM_AU1", "safe", "Jeweller's safe", CF(92, 0.3, 52, 180))

	-- ── stock rooms (north and south bands), the L1 service corridor ────────────────────────────────────
	local stk = kit.model("StockRooms", map)
	for _, r in { { -80, -64, -84, -64 }, { -64, -32, -84, -64 }, { 32, 64, -84, -64 },
		{ -96, -64, 54, 70 }, { -64, -32, 54, 70 }, { 32, 64, 54, 70 }, { 64, 96, 54, 70 }, { -32, -16, 54, 70 }, { 16, 32, 54, 70 } } do
		floorConcrete(stk, r[1], r[2], r[3], r[4], 0.3)
		ceiling(stk, r[1], r[2], r[3], r[4], CE1)
		panel(stk, (r[1] + r[2]) / 2, CE1, (r[3] + r[4]) / 2, 0, true, 22)
	end
	local stockProps = {
		{ "StorageShelf", -72, -81, 0 }, { "StorageShelfEmpty", -56, -81, 0 }, { "RollCage", -40, -72, 80 },
		{ "StorageShelf", 40, -81, 0 }, { "CardboardPile", 56, -72, 0 }, { "StorageShelf", -88, 67, 180 }, { "Lockers", -72, 68.6, 180 },
		{ "StorageShelfEmpty", -56, 67, 180 }, { "PalletBoxes", -40, 62, -10 }, { "StorageShelf", 40, 67, 180 }, { "RollCage", 56, 62, 90 },
		{ "StorageShelf", 72, 67, 180 }, { "Lockers", 88, 68.6, 180 }, { "CardboardPile", -24, 62, 0 }, { "StorageShelfEmpty", 24, 67, 180 },
	}
	for i, p in stockProps do
		local m = K(stk, p[1], p[2], 0.3, p[3], p[4])
		if m and (p[1] == "Lockers") then
			kit.container(stk, "MM_LK" .. i, "locker", "Staff locker", CF(p[2], 0.3, p[3]), m:FindFirstChild("KitCollider"))
		end
	end
	kit.container(stk, "MM_ST1", "crate", "Stock room crate", CF(-67, 0.3, -70, 90))
	kit.container(stk, "MM_ST2", "crate", "Stock room crate", CF(60, 0.3, 66, 0))
	kit.container(stk, "MM_ST3", "toolbox", "Maintenance toolbox", CF(-46, 0.3, 60, 0))
	-- the corridor: concrete floor, bare panels, a collapsed ceiling run, dock doors, the cargo lift
	local cor = kit.model("ServiceCorridor", map)
	floorConcrete(cor, -96, 158, -94, -84, 0.3)
	ceiling(cor, -96, 158, -94, -84, CE1, { { -4, 4, -96, -80 } })
	K(cor, "CeilingDebris", 0, 0.3, -89, 0)
	K(cor, "RubbleA", 2, 0.3, -90, 30)
	for x = -88, 152, 16 do
		panel(cor, x, CE1, -89, 90, (x % 32) == 8, 26)
	end
	for _, dx in docks do
		K(cor, (dx == -36) and "DockDoorOpen" or "DockDoor", dx, 0.3, -95, 0)
	end
	K(cor, "CargoLift", 66, 0.3, -99, 180)
	BOX(cor, 60, 72, 0, YR + 3, -104, -103, EXT, M.Concrete)
	BOX(cor, 59, 60, 0, YR + 3, -104, -96, EXT, M.Concrete)
	BOX(cor, 72, 73, 0, YR + 3, -104, -96, EXT, M.Concrete)
	K(cor, "ElectricCabinet", 120, 0.3, -93, 0)
	K(cor, "RollCage", -26, 0.3, -86.5, 90)
	K(cor, "PalletBoxes", 30, 0.3, -88, 0)
	exitSign(cor, -95.5, 9, -89, 90)
	exitSign(cor, 40, 9, -94.6, 0)
	emergencyLamp(cor, -50, 13, -93.5)
	emergencyLamp(cor, 100, 13, -93.5)

	-- ── stair cores (L1 corridor ↔ L2), north-west and north-east ─────────────────────────────────────
	local function stairCore(parent, xa)
		-- core x xa..xa+14 (z -83.2..-64.4): flight A from the corridor door (north) rising south, landing, flight B
		-- rising north to the upper corridor
		local cx = xa + 7
		WZ(parent, -83.2, -64.4, xa, 0, Y2 + 13, 0.8, hex("9A988E"), M.Plaster, {}, PEEL)
		WZ(parent, -83.2, -64.4, xa + 14, 0, Y2 + 13, 0.8, hex("9A988E"), M.Plaster, {}, PEEL)
		WX(parent, xa, xa + 14, -64.4, 0, Y2 + 13, 0.8, hex("9A988E"), M.Plaster, {}, PEEL)
		H.stairs(parent, xa + 3.5, -81.5, 0, 9, 1.3, 6, "+z", 0, hex("8C8B84"), M.Concrete)
		BOX(parent, xa, xa + 14, 0, 9, -69.8, -64.4, hex("8C8B84"), M.Concrete)
		H.stairs(parent, xa + 10.5, -69.8, 9, 9, 1.3, 6, "-z", 0, hex("8C8B84"), M.Concrete)
		H.rail(parent, cx, -81.5, cx, -69.8, 9)
		H.rail(parent, xa + 0.4, -81, xa + 7, -81, Y2)
		H.rail(parent, cx, -81, cx, -64.8, Y2)
		panel(parent, cx, 13, -74, 90, true, 22)
		panel(parent, cx, Y2 + 12.5, -74, 90, true, 22)
		emergencyLamp(parent, cx, Y2 - 2, -66)
	end
	local cores = kit.model("StairCores", map)
	stairCore(cores, -94)
	stairCore(cores, 80)
	-- the corridor's doors into the cores (holes already in the corridor wall at x -88 and 88)

	-- ── food court (east, L1) and kitchen ───────────────────────────────────────────────────────────────
	local fc = kit.model("FoodCourt", map)
	floorTiles(fc, 96, 158, -64, 54, 0.3, hex("D4CCB8"))
	floorTiles(fc, 96, 158, -84, -64, 0.3, hex("B8BCB8"))
	ceiling(fc, 96, 158, -64, 54, CE1 + 2, { { 120, 136, 4, 20 } })
	K(fc, "CeilingCollapse", 128, CE1 + 2, 12, 45)
	K(fc, "CeilingDebris", 128, 0.3, 12, 0)
	panels(fc, 96, 158, -64, 54, CE1 + 2, 16, 3, 40)
	ceiling(fc, 96, 158, -84, -64, CE1)
	panels(fc, 96, 158, -84, -64, CE1, 16, 2, 26)
	BOX(fc, 96, 158, CE1 + 2.3, Y2 - SL, 53.6, 54.4, PW, M.Plaster)
	-- counters on the north (backing onto the kitchen wall) and the south
	WX(fc, 96, 158, -64, 0, Y2 - SL, 0.8, hex("A8A498"), M.Plaster, { { 155, 3.9, 0, 7.5 }, { 100, 3.9, 0, 7.5 } }, PEEL)
	local FC_SIGNS = { "WOK HOUSE", "GRILL 22", "PIZZERIA", "NOODLE BAR" }
	for i, x in { 104, 118, 132, 146 } do
		K(fc, "FoodCounter", x, 0.3, -60, 180)
		sign(fc, FC_SIGNS[i], x, 13.2, -63.4, 180, 10, 1.8, { box = hex("2A2620"), text = hex("F2D8A8") })
	end
	WX(fc, 96, 158, 54, 0, CE1 + 2, 0.8, PW, M.Plaster, { { 104, 3.9, 0, 7.5 }, { 150, 3.9, 0, 7.5 } }, PAINT)
	for i, x in { 122, 138 } do
		K(fc, "FoodCounter", x, 0.3, 50, 0)
		sign(fc, (i == 1) and "BURGER BARN" or "JUICE CO.", x, 13.2, 53.4, 0, 10, 1.8, { box = hex("2A2620"), text = hex("F2D8A8") })
	end
	-- seating
	for xi, x in { 108, 122, 136, 150 } do
		for zi, z in { -44, -28, -12, 4, 20, 36 } do
			if not (x == 122 and z == 4) and not (x == 136 and z == 4) then
				K(fc, ((xi + zi) % 3 == 0) and "FoodTableMess" or "FoodTable", x, 0.3, z, rng:NextInteger(0, 3) * 90 + rng:NextInteger(-12, 12))
			end
		end
	end
	for _, c in { { 115, -36 }, { 143, -36 }, { 115, 28 }, { 143, 28 } } do
		K(fc, "Column", c[1], 0.3, c[2], 0)
	end
	K(fc, "Kiosk", 129, 0.3, -18, 90)
	K(fc, "Bin", 100, 0.3, 30, 0)
	K(fc, "Bin", 156, 0.3, -30, 0)
	K(fc, "VendingBroken", 156.3, 0.3, 40, -90)
	exitSign(fc, 157.6, 9, -74, -90)
	emergencyLamp(fc, 130, CE1 + 1.4, -62)
	-- kitchen: shelving, lockers, the staff exit (keyed)
	K(fc, "StorageShelf", 112, 0.3, -82.6, 0)
	K(fc, "StorageShelf", 132, 0.3, -82.6, 0)
	local kl = K(fc, "Lockers", 150, 0.3, -82.6, 0)
	if kl then
		kit.container(fc, "MM_FC1", "locker", "Kitchen staff locker", CF(150, 0.3, -82.6), kl:FindFirstChild("KitCollider"))
	end
	kit.container(fc, "MM_FC2", "grocery", "Kitchen supplies", CF(122, 0.3, -70, 180))
	W.doors.MM_STAFF = { id = "MM_STAFF", cf = CF(159, 3.75, -74, 90), size = Vector3.new(3.9, 7.4, 0.35), key = "KEY_MALL_STAFF", label = "Staff exit", parent = fc, color = hex("6E7A8A") }
	-- restroom block (south-east)
	WZ(fc, 54, 70, 130, 0, CE1, 0.8, PW, M.Plaster, { { 58, 3.9, 0, 7.5 } }, PAINT)
	floorTiles(fc, 130, 158, 54, 70, 0.3, hex("C8D2D8"))
	ceiling(fc, 96, 158, 54, 70, CE1)
	panel(fc, 144, CE1, 62, 0, true, 22)

	-- ── interior lights for the concourse ends and the lobby ────────────────────────────────────────────
	panels(L1, -16, 16, 42, 70, YR - SL - 0.3, 16, 2, 44)
	soffit(L1, -16, 16, 40, 70, YR - SL - 0.3)
	exitSign(L1, 0, 10, 69.6, 0)
	exitSign(L1, -95.5, 12, 0, 90)

	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	-- UPPER LEVEL (L2, y = 18)
	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	local L2 = kit.model("Level2", map)
	local CE2 = 31
	local SOF2 = YR - SL - 0.3 -- 34.5
	local F2 = Y2 + 0.3 -- floor finish top
	-- concourse and gallery terrazzo (holes match the slab)
	floorTerrazzo(L2, -96, 96, -16, 16, F2, { { -20, 20, -26, 26 } })
	floorTerrazzo(L2, -32, 32, -40, -16, F2, { { -20, 20, -26, 26 }, { 21, 31, -38, -16 } })
	floorTerrazzo(L2, -32, 32, 16, 40, F2, { { -20, 20, -26, 26 } })
	soffit(L2, -96, -32, -16, 16, SOF2)
	soffit(L2, 32, 96, -16, 16, SOF2)
	for _, b in { { -76, 10, 180 }, { 76, -10, 0 }, { -44, -10, 0 } } do
		K(L2, "Bench", b[1], F2, b[2], b[3])
	end
	for _, p in { { -56, 10 }, { 56, -10 }, { 76, 10 } } do
		K(L2, "Planter", p[1], F2, p[2], 0)
	end
	K(L2, "Bin", -88, F2, -13, 0)
	K(L2, "MannequinFallen", 44, F2, 6, 200)
	K(L2, "ClothesRackFallen", 60, F2, 4, 40)
	soffit(L2, -32, 32, -40, 40, SOF2, { { -20, 20, -26, 26 } })
	panels(L2, -96, -32, -14, 14, SOF2, 16, 2, 40)
	panels(L2, 32, 96, -14, 14, SOF2, 16, 2, 40)
	panels(L2, -32, 32, -40, -26, SOF2, 16, 2, 30)
	panels(L2, -32, 32, 26, 40, SOF2, 16, 2, 30)
	-- L2 walls: back walls, partitions, corridor wall
	local doorsN2 = {}
	for _, x in { -48, 48, 72 } do
		table.insert(doorsN2, { x, 3.9, 0, 7.5 })
	end
	table.insert(doorsN2, { -72, 3.9, 0, 7.5 })
	WX(L2, -96, 96, -64, Y2, CE2 - Y2, 0.8, PW, M.Plaster, doorsN2, PAINT)
	BOX(L2, -96, 96, CE2, YR - SL, -64.4, -63.6, PW, M.Plaster)
	local corr2 = {}
	for _, x in { -84, -48, 0, 48, 90 } do
		table.insert(corr2, { x, 3.9, 0, 7.5 })
	end
	WX(L2, -96, 96, -84, Y2, YR - SL - Y2, 0.8, hex("9A988E"), M.Plaster, corr2, PEEL)
	floorConcrete(L2, -96, 96, -94, -84, F2)
	ceiling(L2, -96, 96, -94, -84, CE2)
	for x = -88, 88, 16 do
		panel(L2, x, CE2, -89, 90, (x % 32) == 8, 26)
	end
	for _, x in { -64, -32, 32, 64 } do
		WZ(L2, -84, -16, x, Y2, CE2 - Y2, 0.8, PW, M.Plaster, {}, PAINT)
		WZ(L2, 16, 70, x, Y2, CE2 - Y2, 0.8, PW, M.Plaster, {}, PAINT)
	end
	WX(L2, -96, -16, 54, Y2, CE2 - Y2, 0.8, PW, M.Plaster, { { -80, 3.9, 0, 7.5 }, { -48, 3.9, 0, 7.5 } }, PAINT)
	WX(L2, 16, 96, 54, Y2, CE2 - Y2, 0.8, PW, M.Plaster, { { 48, 3.9, 0, 7.5 }, { 80, 3.9, 0, 7.5 } }, PAINT)
	WZ(L2, 40, 70, -16, Y2, YR - SL - Y2, 0.8, PW, M.Plaster, {}, PAINT)
	WZ(L2, 40, 70, 16, Y2, YR - SL - Y2, 0.8, PW, M.Plaster, {}, PAINT)
	WX(L2, -32, -16, 54, Y2, CE2 - Y2, 0.8, PW, M.Plaster, {}, PAINT)
	WX(L2, 16, 32, 54, Y2, CE2 - Y2, 0.8, PW, M.Plaster, {}, PAINT)
	for _, x in { -32, 32 } do
		WZ(L2, -40, -16, x, Y2, SOF2 + 0.3 - Y2, 0.8, FASCIA, M.Plaster, {}, PAINT)
		WZ(L2, 16, 40, x, Y2, SOF2 + 0.3 - Y2, 0.8, FASCIA, M.Plaster, {}, PAINT)
	end
	-- the cinema boundary (x 96) with the lobby opening
	WZ(L2, -84, 70, 96, Y2, YR - SL - Y2, 1, hex("9A988E"), M.Plaster, { { 0, 28, 0, 12 } }, PAINT)
	-- storefronts upstairs
	frontLine(L2, -96, -16, Y2, 1, { "front", "wall" }, SOF2 + 0.3) -- offices / security
	frontLine(L2, -64, -16, Y2, 1, { "front", "broken" }, SOF2 + 0.3) -- NESTA
	frontLine(L2, 32, -16, Y2, 1, { "front", "shutter" }, SOF2 + 0.3) -- MODA
	frontLine(L2, 64, -16, Y2, 1, { "broken", "front" }, SOF2 + 0.3) -- IRON YARD
	frontLine(L2, -32, -40, Y2, 1, { "front", "half", "broken", "front" }, SOF2 + 0.3) -- PIXEL PALACE
	frontLine(L2, -96, 16, Y2, -1, { "front", "broken", "front", "bent" }, SOF2 + 0.3) -- ALMA
	frontLine(L2, -32, 40, Y2, -1, { "front" }, SOF2 + 0.3) -- SNAPS
	frontLine(L2, 16, 40, Y2, -1, { "half" }, SOF2 + 0.3) -- GIFTS
	frontLine(L2, 32, 16, Y2, -1, { "front", "front" }, SOF2 + 0.3) -- INKWELL
	frontLine(L2, 64, 16, Y2, -1, { "broken", "shutter" }, SOF2 + 0.3) -- FUNZONE
	local SIGNS2 = {
		{ "MANAGEMENT", -80, -15.2, 180, { box = hex("2E3238"), text = hex("C8C8C0") } },
		{ "NESTA", -48, -15.2, 180, { box = hex("E8E0D0"), text = hex("6A4A2E") } },
		{ "MODA", 48, -15.2, 180, { box = hex("1A1A1A"), text = hex("F2EEE8") } },
		{ "IRON YARD", 80, -15.2, 180, { box = hex("2A2A2A"), text = hex("D84A2E") } },
		{ "PIXEL PALACE", 0, -39.2, 180, { box = hex("1E1236"), text = hex("6AE8F2") } },
		{ "ALMA", -64, 15.2, 0, { box = hex("EDE8DE"), text = hex("2A2E3A") } },
		{ "SNAPS", -24, 39.2, 0, { box = hex("E8C83A"), text = hex("1A1A1A") } },
		{ "GIFTS", 24, 39.2, 0, { box = hex("8E2E4E"), text = hex("F2E8D8") } },
		{ "INKWELL", 48, 15.2, 0, { box = hex("1E2E2A"), text = hex("E8DCC0") } },
		{ "FUNZONE", 80, 15.2, 0, { box = hex("2E8ACE"), text = hex("F8F2A8") } },
	}
	for _, s in SIGNS2 do
		sign(L2, s[1], s[2], Y2 + 14.2, s[3], s[4], (s[1] == "PIXEL PALACE" or s[1] == "ALMA") and 22 or 13, 2.6, s[5])
	end
	exitSign(L2, -95, Y2 + 9, 0, 90)
	exitSign(L2, 0, Y2 + 12, -26.5, 0)
	emergencyLamp(L2, -60, SOF2 - 0.6, 0)
	emergencyLamp(L2, 60, SOF2 - 0.6, 0)

	-- ── management offices and SECURITY ─────────────────────────────────────────────────────────────────
	local of = kit.model("Offices", map)
	floorCarpet(of, -96, -64, -64, -16, F2, true)
	ceiling(of, -96, -64, -64, -16, CE2)
	panels(of, -96, -64, -64, -16, CE2, 16, 2, 26)
	WX(of, -96, -64, -48, Y2, CE2 - Y2, 0.6, hex("D2D0C8"), M.Plaster, { { -80, 3.9, 0, 7.5 } }, PAINT)
	K(of, "OfficeDesk", -88, F2, -36, 0)
	K(of, "OfficeDesk", -72, F2, -36, 0)
	K(of, "OfficeDesk", -88, F2, -24, 180)
	K(of, "StorageShelfEmpty", -70, F2, -21, 0)
	kit.container(of, "MM_OF1", "drawer", "Office drawers", CF(-93, F2, -42, 90))
	W.doors.MM_SECURITY = { id = "MM_SECURITY", cf = CF(-80, Y2 + 3.75, -48), size = Vector3.new(3.9, 7.4, 0.35), key = "KEY_MALL_SECURITY", label = "Security office", parent = of, color = hex("3E4E6E") }
	K(of, "CCTVDesk", -80, F2, -61.5, 180)
	local sl = K(of, "Lockers", -94.7, F2, -54, -90)
	if sl then
		kit.container(of, "MM_SEC1", "locker", "Guard's locker", CF(-94.7, F2, -54), sl:FindFirstChild("KitCollider"))
	end
	kit.container(of, "MM_SEC2", "weaponbox", "Security armoury", CF(-67, F2, -61, -90))
	kit.container(of, "MM_SEC3", "drawer", "Shift supervisor's desk", CF(-72, F2, -52, 180))

	-- ── NESTA homewares ─────────────────────────────────────────────────────────────────────────────────
	local ne = kit.model("Nesta", map)
	floorWood(ne, -64, -32, -64, -16, F2)
	ceiling(ne, -64, -32, -64, -16, CE2, { { -56, -40, -44, -28 } })
	K(ne, "CeilingHole", -48, CE2, -36, 0)
	panels(ne, -64, -32, -64, -16, CE2, 16, 2, 26)
	K(ne, "Sofa", -56, F2, -24, 0)
	K(ne, "Sofa", -42, F2, -26, 160)
	K(ne, "Bed", -56, F2, -50, 0)
	K(ne, "Bed", -40, F2, -52, 0)
	K(ne, "DisplayTable", -48, F2, -38, 90)
	K(ne, "CeilingDebris", -48, F2, -34, 0)

	-- ── PIXEL PALACE arcade ─────────────────────────────────────────────────────────────────────────────
	local ar = kit.model("Arcade", map)
	floorCarpet(ar, -32, 32, -64, -40, F2)
	ceiling(ar, -32, 32, -64, -40, CE2)
	panels(ar, -32, 32, -64, -40, CE2, 16, 2, 26)
	for _, x in { -26, -21, -16, -11, 11, 16, 21, 26 } do
		K(ar, "Arcade", x, F2, -61.5, 180)
	end
	for _, x in { -18, -13, 13, 18 } do
		K(ar, "Arcade", x, F2, -50, (x < 0) and 90 or -90)
	end
	K(ar, "Checkout", 0, F2, -58, 180)
	K(ar, "Vending", -30, F2, -44, 90)
	kit.container(ar, "MM_AR1", "register", "Prize counter till", CF(0, F2, -58, 180))

	-- ── MODA, IRON YARD ─────────────────────────────────────────────────────────────────────────────────
	local mo = kit.model("Moda", map)
	floorTiles(mo, 32, 64, -64, -16, F2, hex("D8D2C8"))
	ceiling(mo, 32, 64, -64, -16, CE2)
	panels(mo, 32, 64, -64, -16, CE2, 16, 2, 26)
	for _, p in { { 40, -30 }, { 54, -30 }, { 46, -44 }, { 40, -56 } } do
		K(mo, "ClothesRack", p[1], F2, p[2], rng:NextInteger(0, 90))
	end
	K(mo, "Mannequin", 58, F2, -21, 0)
	K(mo, "MannequinFallen", 50, F2, -52, 120)
	local iy = kit.model("IronYard", map)
	SLAB(iy, 64, 96, -64, -16, F2, 0.3, hex("2E3030"), M.Rubber, nil, "")
	ceiling(iy, 64, 96, -64, -16, CE2)
	panels(iy, 64, 96, -64, -16, CE2, 16, 2, 26)
	for _, x in { 70, 76, 82, 88 } do
		K(iy, "Treadmill", x, F2, -58, 180)
	end
	K(iy, "WeightRack", 80, F2, -30, 0)
	K(iy, "WeightRack", 70, F2, -42, 90)
	local gl = K(iy, "Lockers", 94.7, F2, -40, -90)
	if gl then
		kit.container(iy, "MM_GY1", "locker", "Gym locker", CF(94.7, F2, -40), gl:FindFirstChild("KitCollider"))
	end

	-- ── ALMA department store, SNAPS, GIFTS, INKWELL, FUNZONE ───────────────────────────────────────────
	local al = kit.model("Alma", map)
	floorTiles(al, -96, -32, 16, 54, F2, hex("E2DCD0"))
	ceiling(al, -96, -32, 16, 54, CE2, { { -72, -56, 30, 46 } })
	K(al, "CeilingCollapse", -64, CE2, 38, 30)
	K(al, "CeilingDebris", -64, F2, 38, 0)
	panels(al, -96, -32, 16, 54, CE2, 16, 2, 28)
	for i, p in { { -88, 26 }, { -78, 26 }, { -88, 36 }, { -46, 26 }, { -40, 36 }, { -50, 46 }, { -86, 46 } } do
		local m = K(al, (i == 5) and "ClothesRackFallen" or "ClothesRack", p[1], F2, p[2], rng:NextInteger(0, 90))
		if i == 1 and m then
			kit.container(al, "MM_AL1", "jacket", "Coat rack", CF(p[1], F2, p[2]), m:FindFirstChild("KitCollider"))
		end
	end
	for _, p in { { -70, 22, 0 }, { -58, 22, 0 }, { -34.5, 30, -90 } } do
		K(al, "Mannequin", p[1], F2, p[2], p[3])
	end
	K(al, "MannequinFallen", -60, F2, 32, 70)
	K(al, "JewelCase", -74, F2, 48, 0)
	K(al, "JewelCase", -66, F2, 48, 0)
	K(al, "DisplayTable", -54, F2, 28, 0)
	local sg = kit.model("SnapsGifts", map)
	floorTiles(sg, -32, -16, 40, 54, F2, hex("D8D8D0"))
	floorTiles(sg, 16, 32, 40, 54, F2, hex("D8C8C0"))
	ceiling(sg, -32, -16, 40, 54, CE2)
	ceiling(sg, 16, 32, 40, 54, CE2)
	panel(sg, -24, CE2, 47, 0, true, 22)
	panel(sg, 24, CE2, 47, 0, true, 22)
	K(sg, "TechTable", -24, F2, 47, 0)
	K(sg, "DisplayTable", 24, F2, 47, 0)
	local ink = kit.model("Inkwell", map)
	floorCarpet(ink, 32, 64, 16, 54, F2, true, hex("5A4E44"))
	ceiling(ink, 32, 64, 16, 54, CE2)
	panels(ink, 32, 64, 16, 54, CE2, 16, 2, 26)
	for _, z in { 26, 36, 46 } do
		K(ink, "WallShelfBooks", 33.3, F2, z, 90)
		K(ink, "WallShelfBooks", 62.7, F2, z, -90)
	end
	K(ink, "DisplayTable", 48, F2, 30, 90)
	K(ink, "Checkout", 48, F2, 48, 0)
	kit.container(ink, "MM_IN1", "drawer", "Stationery drawer", CF(54, F2, 51.5, 180))
	local fz2 = kit.model("Funzone", map)
	floorVinyl(fz2, 64, 96, 16, 54, F2, hex("C8E0F0"))
	ceiling(fz2, 64, 96, 16, 54, CE2)
	panels(fz2, 64, 96, 16, 54, CE2, 16, 2, 26)
	K(fz2, "BallPit", 80, F2, 36, 0)
	K(fz2, "Bench", 70, F2, 22, 0)
	K(fz2, "Bench", 92, F2, 46, 90)

	-- ── L2 stock rooms (north band behind the shops) ────────────────────────────────────────────────────
	local stk2 = kit.model("StockRooms2", map)
	for _, r in { { -80, -64, -84, -64 }, { -64, -32, -84, -64 }, { -32, 32, -84, -64 }, { 32, 64, -84, -64 }, { 64, 80, -84, -64 },
		{ -96, -32, 54, 70 }, { 32, 64, 54, 70 }, { 64, 96, 54, 70 } } do
		floorConcrete(stk2, r[1], r[2], r[3], r[4], F2)
		ceiling(stk2, r[1], r[2], r[3], r[4], CE2)
		panel(stk2, (r[1] + r[2]) / 2, CE2, (r[3] + r[4]) / 2, 0, true, 22)
	end
	for _, x in { -16, 0, 16 } do
		WZ(stk2, -84, -64, x, Y2, CE2 - Y2, 0.8, PW, M.Plaster, { { -74, 3.9, 0, 7.5 } }, PEEL)
	end
	for _, p in { { "StorageShelf", -72, -81, 0 }, { "PalletBoxes", -48, -74, 30 }, { "StorageShelfEmpty", -24, -81, 0 }, { "RollCage", 8, -74, 0 },
		{ "StorageShelf", 24, -81, 0 }, { "CardboardPile", 48, -72, 0 }, { "StorageShelf", -80, 67, 180 }, { "PalletBoxes", 48, 62, 0 } } do
		K(stk2, p[1], p[2], F2, p[3], p[4])
	end
	kit.container(stk2, "MM_S2A", "crate", "Upstairs stock crate", CF(-56, F2, -80, 0))
	kit.container(stk2, "MM_S2B", "toolbox", "Arcade technician's box", CF(-6, F2, -80, 0))

	-- ── roof car park access: glass vestibule on the west wall ─────────────────────────────────────────
	local ves = kit.model("RoofVestibule", map)
	floorTerrazzo(ves, -104, -96, -8, 8, F2)
	BOX(ves, -104, -96, Y2 + 9, Y2 + 9.4, -8.4, 8.4, hex("3E4246"), M.Metal)
	for _, z in { -8, 8 } do
		local g = BOX(ves, -104, -96, Y2, Y2 + 9, z - 0.1, z + 0.1, hex("6E8288"), M.Glass)
		g.Transparency = 0.5
		g.CastShadow = false
	end
	for _, z in { -8, -4, 4, 8 } do
		BOX(ves, -104.2, -103.8, Y2, Y2 + 9, z - 0.15, z + 0.15, hex("3E4246"), M.Metal)
	end
	exitSign(ves, -96.6, Y2 + 9.6, 0, 90)

	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	-- CINEMA LUMEN (L2 over the food court)
	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	local cin = kit.model("Cinema", map)
	floorCarpet(cin, 96, 128, -24, 24, F2)
	floorCarpet(cin, 100, 112, -32, -24, F2)
	floorCarpet(cin, 100, 112, 24, 32, F2)
	SLAB(cin, 96, 158, -24, 24, YR - SL, 0.3, hex("2A2830"), M.Fabric, nil, "") -- dark ceiling
	panels(cin, 96, 128, -24, 24, YR - SL - 0.3, 12, 2, 30)
	-- lobby walls and the corridors to the two screens
	WX(cin, 96, 128, -24, Y2, YR - SL - Y2, 0.8, hex("4A3E46"), M.Plaster, { { 106, 6, 0, 9 } })
	WX(cin, 96, 128, 24, Y2, YR - SL - Y2, 0.8, hex("4A3E46"), M.Plaster, { { 106, 6, 0, 9 } })
	WZ(cin, -24, 24, 128, Y2, YR - SL - Y2, 0.8, hex("4A3E46"), M.Plaster, {})
	for _, side in { -1, 1 } do
		WZ(cin, side < 0 and -32 or 24, side < 0 and -24 or 32, 100, Y2, YR - SL - Y2, 0.6, hex("4A3E46"), M.Plaster, {})
		WZ(cin, side < 0 and -32 or 24, side < 0 and -24 or 32, 112, Y2, YR - SL - Y2, 0.6, hex("4A3E46"), M.Plaster, {})
	end
	K(cin, "TicketBooth", 116, F2, -20, 180, { tint = { wood = hex("6E4A5A") } })
	K(cin, "FoodCounter", 114, F2, 19.6, 0)
	K(cin, "Bench", 104, F2, 0, 90)
	K(cin, "VendingBroken", 126, F2, 4, -90)
	K(cin, "Vending", 126, F2, -4, -90)
	poster(cin, 127.5, Y2 + 7, 14, -90, 4, 6, "NIGHT TIDE  ·  NOW SHOWING", hex("2E3A5A"))
	poster(cin, 127.5, Y2 + 7, -12, -90, 4, 6, "THE LONG ROAD HOME", hex("5A3A2E"))
	sign(cin, "LUMEN", 112, Y2 + 12, -23.4, 0, 12, 2.4, { box = hex("1E1A22"), text = hex("E8C878"), font = Enum.Font.Oswald })
	kit.container(cin, "MM_CN1", "register", "Box office till", CF(116, F2, -21, 180))
	-- the two auditoriums: screen on the west wall, stadium rows rising east, a projection booth at the top
	local function auditorium(z0, z1, entryZ)
		local a = kit.model("Screen" .. (entryZ < 0 and "1" or "2"), cin)
		local zc = (z0 + z1) / 2
		local width = z1 - z0
		WX(a, 100, 158, z0, Y2, YR - SL - Y2, 0.8, hex("2E2830"), M.Fabric, entryZ > 0 and { { 106, 6, 0, 9 } } or {})
		WX(a, 100, 158, z1, Y2, YR - SL - Y2, 0.8, hex("2E2830"), M.Fabric, entryZ < 0 and { { 106, 6, 0, 9 } } or {})
		WZ(a, z0, z1, 100, Y2, YR - SL - Y2, 0.8, hex("2E2830"), M.Fabric, {})
		floorCarpet(a, 100, 114, z0, z1, F2, true, hex("3A2E34"))
		SLAB(a, 100, 158, z0, z1, YR - SL, 0.3, hex("1E1A20"), M.Fabric, nil, "")
		-- screen
		local scr = BOX(a, 100.4, 100.8, Y2 + 3, Y2 + 15, zc - width * 0.36, zc + width * 0.36, hex("B8BABC"), M.SmoothPlastic)
		noDetail(scr)
		-- risers and seat rows
		local rows = 7
		local seatsN = math.floor((width - 14) / 7.6)
		for k = 0, rows - 1 do
			local x0, x1 = 114 + k * 4, 118 + k * 4
			local top = Y2 + 1.3 * (k + 1)
			BOX(a, x0, 158, Y2, top, z0 + 0.4, z1 - 0.4, hex("3A2E34"), M.Carpet)
			-- the side aisle has half steps (0.65) between the 1.3 risers, so it can be walked without jumping
			BOX(a, x0 - 2, x0, Y2, top - 0.65, z0 + 0.4, z0 + 4.6, hex("33282E"), M.Carpet)
			for s = 0, seatsN - 1 do
				local zz = zc + (s - (seatsN - 1) / 2) * 7.6
				K(a, (rng:NextNumber() < 0.3) and "CinemaRowTorn" or "CinemaRow", (x0 + x1) / 2 + 0.5, top, zz, 90)
			end
		end
		-- back platform and the projection booth
		local topY = Y2 + 1.3 * rows
		BOX(a, 142, 158, Y2, topY, z0 + 0.4, z1 - 0.4, hex("3A2E34"), M.Carpet)
		WX(a, 150, 158, zc - 7, topY, YR - SL - topY, 0.6, hex("2E2830"), M.Plaster, { { 152.6, 4.4, 0, 7 } })
		WX(a, 150, 158, zc + 7, topY, YR - SL - topY, 0.6, hex("2E2830"), M.Plaster, {})
		WZ(a, zc - 7, zc + 7, 150, topY, YR - SL - topY, 0.6, hex("2E2830"), M.Plaster, { { zc, 4, 3, 5 } })
		K(a, "Projector", 154, topY, zc, -90)
		panel(a, 154, YR - SL - 0.3, zc, 0, true, 16)
		exitSign(a, 100.6, Y2 + 9, z0 + 4, 90)
		emergencyLamp(a, 157, topY + 6, zc + 10)
		return a, topY
	end
	local a1 = auditorium(-94, -32, -24)
	local a2 = auditorium(32, 70, 24)
	kit.container(a1, "MM_PJ1", "techbox", "Projection booth spares", CF(156.5, Y2 + 1.3 * 7, -63 + 5, -90))
	kit.container(a2, "MM_PJ2", "drawer", "Projectionist's drawer", CF(156.5, Y2 + 1.3 * 7, 51 + 5, -90))

	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	-- ROOF CAR PARK (on the supermarket, y = 18) and the broken ramp
	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	local rp = kit.model("RoofParking", map)
	BOX(rp, -158, -96, Y2, Y2 + 0.2, -94, 70, C.asphalt, M.Asphalt)
	for z = -86, 62, 8 do
		noDetail(BOX(rp, -150, -136, Y2 + 0.2, Y2 + 0.24, z - 0.15, z + 0.15, LINE, M.SmoothPlastic))
		noDetail(BOX(rp, -124, -110, Y2 + 0.2, Y2 + 0.24, z - 0.15, z + 0.15, LINE, M.SmoothPlastic))
	end
	local roofCars = { { "CarSedan", -143, -70, 90 }, { "CarHatch", -143, -46, 90 }, { "CarSedanSmashed", -117, -30, -90 }, { "CarSedan", -117, 2, -90 },
		{ "CarHatch", -143, 18, 90 }, { "CarSedan", -143, 42, 92 }, { "CarHatch", -117, 50, -88 } }
	local CAR_PAINT = { hex("8E2E2A"), hex("2E4A6E"), hex("C8C2B0"), hex("3A3E40"), hex("4E5E3A"), hex("9C8A5A"), hex("6E7478") }
	for i, c in roofCars do
		K(rp, c[1], c[2], Y2 + 0.2, c[3], c[4], { tint = CAR_PAINT[(i % #CAR_PAINT) + 1] })
	end
	Props.cover(rp, "CarWreck", CF(-117, Y2 + 0.2, -62, 80))
	for _, l in { { -130, -80 }, { -130, -30 }, { -130, 20, "flicker" }, { -130, 60, "dead" } } do
		Props.lamp(rp, CF(l[1], Y2 + 0.2, l[2]), l[3])
	end
	K(rp, "ParkingBarrier", -152, Y2 + 0.2, -26, 90)
	K(rp, "TrolleyBay", -104, Y2 + 0.2, 36, 90)
	K(rp, "TrolleyRow", -104, Y2 + 0.2, 36, 0)
	H.rail(rp, -159, -94, -159, -61, Y2 + 1.4)
	H.rail(rp, -159, -55, -159, -41, Y2 + 1.4)
	H.rail(rp, -159, -22, -159, 70, Y2 + 1.4)
	H.rail(rp, -159, 70, -96, 70, Y2 + 1.4)
	H.rail(rp, -159, -94, -96, -94, Y2 + 1.4)
	-- the ramp: rises north along the west facade, broken at mid-span
	local ramp = kit.model("Ramp", map)
	local RX0, RX1 = -178, -162
	local function rampY(z)
		return math.clamp((70 - z) / (70 - (-24)) * Y2, 0, Y2)
	end
	local function rampPart(za, zb)
		local a, b = V((RX0 + RX1) / 2, rampY(za), za), V((RX0 + RX1) / 2, rampY(zb), zb)
		local len = (b - a).Magnitude
		local look = CFrame.lookAt((a + b) / 2, b)
		kit.part(ramp, Vector3.new(RX1 - RX0, 1.2, len), look * CFrame.new(0, -0.6, 0), hex("7A7972"), M.Concrete)
		for _, s in { -1, 1 } do
			kit.part(ramp, Vector3.new(0.8, 1.6, len), look * CFrame.new(s * ((RX1 - RX0) / 2 - 0.4), 0.8, 0), hex("8A8983"), M.Concrete)
		end
	end
	rampPart(70, 30)
	rampPart(14, -24)
	BOX(ramp, RX0, RX1, Y2 - 1.2, Y2, -40, -24, hex("7A7972"), M.Concrete)
	BOX(ramp, RX1, -159, Y2 - 1.2, Y2 + 0.2, -38, -26, hex("7A7972"), M.Concrete) -- bridge to the deck
	for _, z in { 60, 44, 30, 14, -2, -18, -32 } do
		local y = rampY(z)
		if y > 2 then
			BOX(ramp, -171, -169, 0, y - 1.2, z - 1, z + 1, hex("8A8983"), M.Concrete)
		end
	end
	K(ramp, "BrokenEdge", (RX0 + RX1) / 2, rampY(30), 30, 0, { tint = nil })
	K(ramp, "BrokenEdge", (RX0 + RX1) / 2, rampY(14), 14, 180)
	K(ramp, "RubbleB", -170, 0, 22, 0)
	K(ramp, "RubbleA", -166, 0, 17, 40)
	-- fire escape (north-west): steel switchback from the ground to the roof deck
	local fe = kit.model("FireEscape", map)
	H.stairs(fe, -169, -60, 0, 9, 1.4, 5, "-z", 0, hex("4E5254"), M.DiamondPlate)
	BOX(fe, -174, -162, 8.6, 9, -78, -72.6, hex("4E5254"), M.DiamondPlate)
	H.stairs(fe, -164.5, -72.6, 9, 9, 1.4, 4, "+z", 9, hex("4E5254"), M.DiamondPlate)
	BOX(fe, -167, -159, Y2 - 0.4, Y2, -60.6, -56, hex("4E5254"), M.DiamondPlate)
	for _, p in { { -174, -78 }, { -162, -78 }, { -174, -60 }, { -162, -60 } } do
		BOX(fe, p[1] - 0.3, p[1] + 0.3, 0, Y2, p[2] - 0.3, p[2] + 0.3, hex("3A3E40"), M.Metal)
	end
	H.rail(fe, -174, -78, -174, -60, 9)
	H.rail(fe, -162, -78, -167, -78, 9)

	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	-- OUTSIDE: car park, yard, generator compound
	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	local out = kit.model("Outside", map)
	local CARS = {
		{ "CarSedan", -150, 104, 0 }, { "CarHatch", -134, 104, 4 }, { "CarSedanSmashed", -70, 104, -2 }, { "CarSedan", -46, 112, 180 },
		{ "CarHatch", 58, 104, 0 }, { "CarSedan", 98, 112, 178 }, { "CarHatch", 150, 104, 2 }, { "CarSedan", -102, 144, 0 },
		{ "CarSedanSmashed", -30, 152, 176 }, { "CarHatch", 30, 144, -4 }, { "CarSedan", 74, 152, 180 }, { "CarHatch", 122, 144, 0 },
		{ "CarSedan", 182, -20, 90 }, { "CarHatch", 184, 30, 92 }, { "CarSedan", 182, 120, 88 },
	}
	for i, c in CARS do
		K(out, c[1], c[2], 0, c[3], c[4], { tint = CAR_PAINT[(i * 3 % #CAR_PAINT) + 1] })
	end
	for _, w in { { -110, 120, 75 }, { 10, 104, 95 }, { 140, 160, 10 }, { -170, -120, 0 } } do
		Props.cover(out, "CarWreck", CF(w[1], 0, w[2], w[3]))
	end
	for _, l in { { -160, 128 }, { -80, 128, "flicker" }, { 0, 128 }, { 80, 128 }, { 160, 128, "dead" }, { -60, 176 }, { 60, 176 }, { 190, -60 }, { 190, 80 },
		{ -60, -120 }, { 60, -120, "flicker" }, { -190, -60 }, { -190, 100 } } do
		Props.lamp(out, CF(l[1], 0, l[2]), l[3])
	end
	K(out, "TrolleyBay", -60, 0, 92, 0)
	K(out, "TrolleyRow", -60, 0, 92, 90)
	K(out, "TrolleyBay", 60, 0, 92, 0)
	K(out, "TrolleyTipped", 66, 0, 100, 20)
	K(out, "Trolley", 14, 0, 120, 140)
	K(out, "BusShelter", -192, 0, 30, 90)
	K(out, "Bench", -186, 0, 46, 90)
	K(out, "ParkingBarrier", 0, 0, 186, 0)
	for _, b in { { -24, 78 }, { 24, 78 }, { -60, 78 }, { 60, 78 } } do
		K(out, "Bin", b[1], 0, b[2], 0)
	end
	-- the north yard: docks, trucks, containers, dumpsters, the sewer grate
	for _, dx in docks do
		BOX(out, dx - 7, dx + 7, 0, 0.3, -112, -96, hex("7E7D76"), M.Concrete, "ZR_FloorConcrete")
	end
	H.truck(out, CF(-36, 0, -112, 180), "canvas")
	H.truck(out, CF(-84, 0, -128, 95), "burnt")
	Props.container(out, CF(-10, 0, -136, 90), C.rust)
	Props.container(out, CF(18, 0, -140, 80), C.teal, true)
	for _, d in { { -120, -104, 0, hex("3E5A45") }, { -100, -104, 0, hex("3D5468") }, { 10, -104, 0, hex("3E5A45") }, { 86, -104, 90, hex("5A4A3A") } } do
		Props.cover(out, "Dumpster", CF(d[1], 0, d[2], d[3]), d[4])
	end
	for _, p in { { "PalletBoxes", -50, -106, 10 }, { "PalletBoxes", -20, -108, -20 }, { "RollCage", 0, -102, 30 }, { "CardboardPile", -70, -110, 0 } } do
		K(out, p[1], p[2], 0, p[3], p[4])
	end
	Props.cover(out, "PalletStack", CF(30, 0, -112, 15))
	Props.cover(out, "TyreStack", CF(-140, 0, -140, 0))
	Props.cover(out, "DrumDented", CF(-130, 0, -118, 0), C.blue)
	BOX(out, -124, -116, 0, 0.12, -140, -132, hex("2A2C2C"), M.DiamondPlate) -- sewer grate
	-- generator compound: fence, gate gap, the generator (its control panel is the power switch)
	local gc = kit.model("GeneratorCompound", map)
	BOX(gc, 104, 146, 0, 0.3, -146, -110, hex("7E7D76"), M.Concrete, "ZR_FloorConcrete")
	H.fence(gc, 104, -146, 146, -146, 0.3, 8)
	H.fence(gc, 104, -146, 104, -110, 0.3, 8)
	H.fence(gc, 146, -146, 146, -110, 0.3, 8)
	H.fence(gc, 104, -110, 118, -110, 0.3, 8)
	H.fence(gc, 128, -110, 146, -110, 0.3, 8)
	local gen = K(gc, "Generator", 128, 0.3, -130, -90)
	K(gc, "ElectricCabinet", 140, 0.3, -114, 180)
	K(gc, "HVAC", 116, 0.3, -140, 0)
	-- the switch: a panel at the generator's control box (west end after the -90 turn: +z side)
	local sw = kit.part(gc, Vector3.new(2.6, 2.6, 0.4), CF(128, 3.9, -121.6), hex("8A8E86"), M.Metal)
	sw.Name = "GeneratorPanel"
	sw.Transparency = 1
	sw.CanCollide = false
	noDetail(sw)
	local pp = Instance.new("ProximityPrompt")
	pp.KeyboardKeyCode = Enum.KeyCode.F
	pp.ActionText = "Start generator"
	pp.ObjectText = "Generator"
	pp.HoldDuration = 3
	pp.MaxActivationDistance = 8
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.Parent = sw
	local _ = gen
	W.switches.MALL_POWER = {
		id = "MALL_POWER", label = "Generator", part = sw, prompt = pp, delay = 9, startText = "GENERATOR STARTING",
		onChange = function(on)
			for _, p in power.panels do
				p.Material = on and M.Neon or M.SmoothPlastic
				p.Color = on and PANEL_ON or PANEL_OFF
			end
			for _, l in power.lights do
				l.Enabled = on
			end
		end,
	}
	Props.lamp(gc, CF(110, 0.3, -114), "flicker")

	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	-- LOOT (loose), EXFILS, SPAWNS, AI
	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	local L = kit.loose
	for _, s in {
		-- concourse, atrium, supermarket
		{ -70, 0.4, -4, "mall", 0.45 }, { 70, 0.4, 6, "mall", 0.45 }, { -8, 0.4, 32, "mall", 0.4 }, { 12, 0.4, -34, "mall", 0.4 },
		{ -106, 3.5, -60, "mall", 0.4 }, { -106, 3.5, 36, "mall", 0.4 }, { -140, 3.3, -14, "grocery", 0.5 }, { -126, 3.3, 34, "grocery", 0.5 },
		{ -150, 0.4, -40, "mall", 0.35 }, { -128, 4.6, -26, "grocery", 0.45 },
		-- stores
		{ -71, 3.5, -21, "junk", 0.5 }, { -84, 0.4, -60, "junk", 0.45 }, { -42, 3.5, -48, "mall", 0.45 }, { -56, 0.4, -58, "keys", 0.25 },
		{ -6, 3.4, -52, "tech", 0.5 }, { 6, 3.4, -52, "tech", 0.5 }, { -12, 3.4, -46, "mallgood", 0.3 }, { 0, 3.5, -60, "mallkeys", 0.25 },
		{ -20, 0.4, -78, "mallgood", 0.55 }, { 20, 0.4, -78, "tech", 0.6 }, { 48, 4.0, -58, "mall", 0.4 }, { 72, 3.0, -70, "vault", 0.7 },
		{ 76, 0.4, -80, "vault", 0.6 }, { 80, 3.7, -44, "office", 0.5 }, { -80, 3.3, 49, "mall", 0.35 }, { -40, 3.5, 50, "mall", 0.4 },
		{ -24, 3.4, 46, "tech", 0.45 }, { 24, 3.5, 45, "mallkeys", 0.3 }, { 48, 3.5, 46, "junk", 0.45 }, { 80, 3.3, 38, "mallgood", 0.35 },
		{ 70, 3.3, 46, "mallgood", 0.35 }, { 128, 4.0, -60, "mall", 0.4 }, { 140, 0.4, 20, "mall", 0.35 }, { 122, 2.9, -12, "mall", 0.35 },
		{ 112, 0.4, -78, "grocery", 0.5 }, { 100, 0.4, -88, "junk", 0.45 }, { -40, 0.4, -90, "junk", 0.45 }, { 66, 0.6, -99, "junk", 0.4 },
		-- upstairs
		{ -88, F2 + 2.9, -36, "office", 0.5 }, { -72, F2 + 2.9, -36, "office", 0.5 }, { -80, F2 + 2.9, -61, "mallkeys", 0.4 },
		{ -90, F2 + 0.1, -58, "mallgood", 0.35 }, { -48, F2 + 2.9, -38, "mall", 0.35 }, { 0, F2 + 3.5, -58, "mall", 0.4 },
		{ 46, F2 + 0.1, -44, "mall", 0.35 }, { 80, F2 + 0.1, -30, "mall", 0.35 }, { -66, F2 + 3.0, 48, "mallgood", 0.4 },
		{ -54, F2 + 2.9, 28, "mall", 0.35 }, { -24, F2 + 3.4, 47, "tech", 0.4 }, { 48, F2 + 3.5, 48, "office", 0.45 },
		{ 80, F2 + 2.0, 36, "mall", 0.35 }, { 116, F2 + 4.0, -20, "mall", 0.4 }, { 114, F2 + 4.0, 19, "mall", 0.4 },
		{ 154, Y2 + 9.4, -60, "tech", 0.45 }, { 154, Y2 + 9.4, 54, "office", 0.4 }, { -24, F2 + 0.1, -80, "tech", 0.45 },
		-- outside and the roof
		{ -36, 3.1, -112, "junk", 0.4 }, { 130, 0.4, -118, "junk", 0.45 }, { -140, Y2 + 0.3, -60, "mall", 0.35 }, { -110, Y2 + 0.3, 20, "junk", 0.35 },
		{ -192, 1.6, 30, "mall", 0.35 }, { 60, 0.1, 100, "mall", 0.3 },
	} do
		L(O.X + s[1], s[2], O.Z + s[3], s[4], s[5], "meridian", true)
	end

	kit.extract(map, "MB", "BUS DEPOT", V(-196, 0, 30), Vector3.new(16, 12, 24), { kind = "open" })
	kit.extract(map, "MS", "SERVICE RAMP", V(186, 0, -136), Vector3.new(18, 12, 16), { kind = "open" })
	kit.extract(map, "ML", "CARGO LIFT", V(66, 0.3, -99), Vector3.new(7, 9, 5), { kind = "power", switch = "MALL_POWER", needs = "NO POWER  ·  START THE GENERATOR" }, { compact = true })
	kit.extract(map, "MT", "TAXI RANK", V(130, 0, 192), Vector3.new(20, 12, 10), { kind = "paid", cost = 6000 })
	kit.extract(map, "MK", "STAFF EXIT", V(170, 0, -74), Vector3.new(10, 10, 12), { kind = "key", key = "KEY_MALL_STAFF" })
	kit.extract(map, "MD", "SEWER GRATE", V(-120, 0, -136), Vector3.new(8, 8, 8), { kind = "scav" }, { compact = true })
	local function sp(id, name, x, z, yaw, side)
		return { id = id, name = name, cf = CF(x, 3.4, z, yaw), side = side }
	end
	W.spawns = {
		sp("MW1", "WEST ROAD", -196, -110, -90, "west"), sp("MW2", "BUS LANE", -196, 140, -90, "west"),
		sp("MS1", "CAR PARK WEST", -140, 178, 0, "south"), sp("MS2", "CAR PARK EAST", 90, 178, 0, "south"), sp("MS3", "MAIN ROAD", -20, 196, 0, "south"),
		sp("ME1", "STAFF PARKING", 196, 20, 90, "east"), sp("ME2", "EAST ROAD", 196, 150, 90, "east"),
		sp("MN1", "LOADING YARD", -60, -146, 180, "north"), sp("MN2", "TRUCK GATE", 60, -148, 180, "north"),
	}
	W.sideExtracts = {
		west = { "MS", "MK", "MT", "ML" }, south = { "MS", "MB", "ML" }, east = { "MB", "MT", "ML" }, north = { "MT", "MB", "ML" },
	}
	for _, s in W.spawns do
		s.extracts = W.sideExtracts[s.side]
	end
	W.patrols = {
		-- the concourse loop round the atrium (L1)
		MC = { V(-80, 0.3, 0), V(-40, 0.3, -6), V(-24, 0.3, -34), V(0, 0.3, -34), V(24, 0.3, -30), V(40, 0.3, 4), V(80, 0.3, 0), V(40, 0.3, 8),
			V(24, 0.3, 34), V(0, 0.3, 34), V(-26, 0.3, 30), V(-40, 0.3, 6) },
		-- the gallery and the upper concourse (L2)
		MG = { V(-80, F2, 0), V(-40, F2, -8), V(-26, F2, -33), V(0, F2, -33), V(26, F2, 33), V(0, F2, 33), V(-26, F2, 33), V(-40, F2, 8), V(40, F2, 0), V(80, F2, 0) },
		-- the north yard and the generator compound
		MY = { V(-80, 0, -120), V(-40, 0, -124), V(0, 0, -120), V(40, 0, -122), V(90, 0, -120), V(124, 0.3, -116), V(90, 0, -104), V(0, 0, -104) },
		-- the supermarket aisles
		MK = { V(-110, 0.3, -8), V(-152, 0.3, -8), V(-152, 0.3, 40), V(-112, 0.3, 40), V(-112, 0.3, -44), V(-152, 0.3, -44) },
	}
	W.watchPosts = {
		{ route = "MG", post = V(-80, F2, -20), label = "Mall Security" }, -- outside the management suite
		{ route = "MG", label = "Mall Security" },
		{ route = "MY", post = V(118, 0.3, -114), label = "Mall Security" }, -- the generator gate
		{ route = "MK", label = "Mall Security" },
	}
	W.scavZones = {
		V(-70, 0.3, 0), V(-40, 0.3, 8), V(40, 0.3, -6), V(70, 0.3, 4), V(-24, 0.3, -30), V(24, 0.3, 30), V(0, 0.3, 30),
		V(-130, 0.3, -20), V(-130, 0.3, 28), V(-106, 0.3, 0), V(-140, 0.3, -84), V(-80, 0.3, -40), V(-48, 0.3, -30),
		V(0, 0.3, -50), V(48, 0.3, -36), V(80, 0.3, -30), V(-80, 0.3, 36), V(-48, 0.3, 36), V(48, 0.3, 36), V(80, 0.3, 30),
		V(120, 0.3, -20), V(140, 0.3, 30), V(120, 0.3, -74), V(0, 0.3, -89), V(-60, F2, 0), V(60, F2, 0), V(0, F2, -33),
		V(-80, F2, -30), V(-48, F2, -40), V(0, F2, -52), V(48, F2, -40), V(-64, F2, 36), V(48, F2, 36), V(112, F2, 0),
		V(130, Y2 + 4, -63), V(130, Y2 + 4, 51), V(-130, Y2 + 0.2, -10), V(-60, 0, -120), V(60, 0, -124), V(-80, 0, 120),
		V(80, 0, 130), V(-190, 0, 0), V(186, 0, 0),
	}
	W.visitZones = { FOUNTAIN = { pos = V(0, 0.3, 0), r = 12 }, PROJECTION = { pos = V(152.6, Y2 + 9.4, -67.5), r = 4 } }
	W.boss = {
		name = "THE CARETAKER", label = "Caretaker", home = V(0, 0.3, -52), look = "bodyguard", loadout = "caretakerLoadout",
		route = { V(0, 0.3, -52), V(-14, 0.3, -46), V(-24, 0.3, -34), V(-40, 0.3, -6), V(-24, 0.3, 30), V(0, 0.3, 34), V(24, 0.3, 30),
			V(40, 0.3, 4), V(24, 0.3, -34), V(14, 0.3, -46) },
		crew = {},
	}
	W.bounds = { x0 = O.X - 206, x1 = O.X + 206, z0 = O.Z - 152, z1 = O.Z + 198, yMin = -2, yMax = 40, step = 4 }

	-- lights off at build time (the raid reset sets them again)
	W.switches.MALL_POWER.onChange(false)
	return map
end
