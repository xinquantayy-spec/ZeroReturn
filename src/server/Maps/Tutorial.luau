--!nonstrict
-- Decision ui-5a: the FIRST RAID's area (shared/TutorialData.luau has the why and the sources). Tarkov 1.0's tutorial
-- runs on a closed-off part of Ground Zero; ours is a small course of its own, laid out in the same order: an office
-- lobby with a reception desk (the start), a corridor past a sandbag barricade to a body, a parking garage with cars
-- for cover, a street with a sandbag wall, an office block, a yard with two tents, and a gated fence where a green
-- flare burns over the exit. Green glowing bars on the floor lead the whole way, and control signs stand at each step.
-- Never in the map vote (Maps.order); a tutorial session plays it while any raid goes on elsewhere.
-- Built once at server start at its own origin. Local coordinates: x east, z south, y up; ground at y = 0, studs
-- (3.125 to the metre, Ballistics.STUDS_PER_M).
local O = Vector3.new(-2400, 0, 0)

return function(kit, root)
	local W, C, M, hex = kit.World, kit.C, kit.M, kit.hex
	local map = kit.model("Tutorial", root)
	local GREEN = hex("3CFF6A")

	local function V(x, y, z)
		return Vector3.new(O.X + x, y, O.Z + z)
	end
	local function CF(x, y, z, ry)
		local c = CFrame.new(O.X + x, y, O.Z + z)
		if ry then
			c *= CFrame.Angles(0, math.rad(ry), 0)
		end
		return c
	end
	local function B(parent, sx, sy, sz, x, y, z, color, mat, ry)
		return kit.box(parent, sx, sy, sz, O.X + x, y, O.Z + z, color, mat, ry)
	end
	-- wall along x at z / along z at x (holes { centre in map coordinates, width, bottom, top })
	local function wallX(parent, x0, x1, z, h, color, mat, holes)
		local cx = (x0 + x1) / 2
		local hs = {}
		for _, o in holes or {} do
			table.insert(hs, { o[1] - cx, o[2], o[3], o[4] })
		end
		kit.wallHoles(parent, CF(cx, 0, z), x1 - x0, h, 1.2, color, mat, hs)
	end
	local function wallZ(parent, z0, z1, x, h, color, mat, holes)
		local cz = (z0 + z1) / 2
		local hs = {}
		for _, o in holes or {} do
			table.insert(hs, { -(o[1] - cz), o[2], o[3], o[4] })
		end
		kit.wallHoles(parent, CF(x, 0, cz) * CFrame.Angles(0, math.rad(90), 0), z1 - z0, h, 1.2, color, mat, hs)
	end
	-- a room: floor, ceiling and four walls (holes per side: n, s, w, e)
	local function room(name, x0, x1, z0, z1, h, wallColor, floorColor, floorMat, holes, wallMat)
		local m = kit.model(name, map)
		wallMat = wallMat or M.Concrete
		B(m, x1 - x0, 1, z1 - z0, (x0 + x1) / 2, 0.02 - 0.5, (z0 + z1) / 2, floorColor, floorMat)
		B(m, x1 - x0 + 2.4, 1, z1 - z0 + 2.4, (x0 + x1) / 2, h + 0.5, (z0 + z1) / 2, C.concrete, M.Concrete)
		wallX(m, x0 - 0.6, x1 + 0.6, z0, h, wallColor, wallMat, holes.n)
		wallX(m, x0 - 0.6, x1 + 0.6, z1, h, wallColor, wallMat, holes.s)
		wallZ(m, z0, z1, x0, h, wallColor, wallMat, holes.w)
		wallZ(m, z0, z1, x1, h, wallColor, wallMat, holes.e)
		return m
	end
	-- Blender kit props (Maps/Kit.luau: cosmetic pieces, box colliders; a plain box stands in while the kit loads)
	local Kit = require(script.Parent.Kit)
	local function P(parent, name, x, y, z, ry, opts)
		opts = opts or {}
		opts.shadows = false
		return Kit.place(parent, name, CF(x, y, z, ry), opts)
	end
	local function lamp(parent, x, y, z, range, bright)
		local p = B(parent, 3, 0.3, 1, x, y, z, hex("E8E4D2"), M.Neon)
		kit.light(p, hex("FFF1D6"), range or 40, bright or 1.6, false)
		return p
	end
	-- a control sign (its front, -Z, faces the way it is turned: ry 0 faces north, 180 south, 90 west, -90 east): the actions it names are in the "ZR_TutSign" attribute; the client writes them for its device
	-- (Controllers/Tutorial.luau). The default text is the keyboard's, for a client that has not filled it yet.
	local signs = {}
	local function controlSign(parent, x, y, z, ry, actions, title)
		local p = B(parent, 9, 4.2, 0.3, x, y, z, hex("1C1F1D"), M.SmoothPlastic, ry)
		p.Name = "TutSign"
		p.CanCollide = false
		p:SetAttribute("ZR_TutSign", table.concat(actions, ","))
		p:SetAttribute("ZR_TutTitle", title)
		p:SetAttribute("NoDetail", true)
		kit.sign(p, Enum.NormalId.Front, title, hex("C8E6C0"), hex("1C1F1D"))
		table.insert(signs, p)
		return p
	end
	-- green guide bars on the floor along a path of map points (Tarkov 1.0's tutorial: "green glowing bars" to the exit)
	local guide = kit.model("Guide", map)
	local function bars(points, y)
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local d = Vector3.new(b[1] - a[1], 0, b[2] - a[2])
			local n = math.max(1, math.floor(d.Magnitude / 9))
			for k = 0, n - 1 do
				local t = (k + 0.5) / n
				local px, pz = a[1] + d.X * t, a[2] + d.Z * t
				local bar = B(guide, 0.7, 0.12, 3.2, px, (y or 0) + 0.08, pz, GREEN, M.Neon)
				bar.CFrame = CFrame.lookAt(bar.Position, bar.Position + d.Unit) * CFrame.new(0, 0, 0)
				bar.CanCollide, bar.CanQuery, bar.CastShadow = false, false, false
				bar:SetAttribute("NoDetail", true)
				bar:SetAttribute("ZR_TutBar", true)
			end
		end
	end

	-- ── the ground and the outer walls ──────────────────────────────────────────
	B(map, 230, 8, 440, 0, -4, -45, C.concrete, M.Concrete)
	local outer = kit.model("Outer", map)
	wallZ(outer, -70, 150, -100, 16, C.concreteDark, M.Concrete)
	wallZ(outer, -70, 150, 100, 16, C.concreteDark, M.Concrete)
	wallX(outer, -100, -60, -70, 16, C.concreteDark, M.Concrete)
	wallX(outer, 60, 100, -70, 16, C.concreteDark, M.Concrete)

	-- ── 1. the office lobby (the start) ─────────────────────────────────────────
	local lobby = room("Lobby", -40, 40, -250, -200, 14, hex("B4AE9E"), hex("8A857A"), M.CeramicTiles, { s = { { 0, 7, 0, 9 } } }, M.Plaster)
	B(lobby, 20, 3.6, 4.5, 0, 1.8, -214, hex("4A3B2E"), M.WoodPlanks) -- the reception desk
	B(lobby, 20.4, 0.3, 4.9, 0, 3.75, -214, hex("2E2B27"), M.Granite)
	for _, x in { -26, 26 } do
		P(lobby, "Bench", x, 0, -248.3, 180) -- waiting benches
	end
	P(lobby, "Sofa", -37.6, 0, -230, -90)
	P(lobby, "Sofa", 37.6, 0, -230, 90)
	for _, c in { { -36, -246 }, { 36, -246 }, { -36, -204 }, { 36, -204 } } do
		P(lobby, "Planter", c[1], 0, c[2], 0)
	end
	P(lobby, "Chair", 4, 0, -210.6, 0) -- behind the desk
	P(lobby, "Chair", -4, 0, -210.6, 0)
	P(lobby, "WallClock", 0, 10.2, -200.75, 0)
	P(lobby, "Extinguisher", 7, 0, -201.2, 0)
	P(lobby, "CorkBoard", -39.28, 4, -216, -90)
	P(lobby, "Vending", 37.7, 0, -214, 90)
	for _, x in { -30, 0, 30 } do
		lamp(lobby, x, 13.6, -225, 46, 1.8)
	end
	controlSign(lobby, 20, 7.5, -200.8, 0, { "Interact", "Inventory" }, "LOOT")
	controlSign(lobby, -20, 7.5, -200.8, 0, { "Sprint", "Crouch" }, "MOVE")

	-- ── 2. the corridor, the barricade and the body ─────────────────────────────
	local cor = room("Corridor", -5, 5, -200, -150, 10, hex("7E7C74"), hex("5E5A54"), M.Concrete, { n = { { 0, 7, 0, 9 } }, s = { { 0, 9, 0, 9 } } })
	for _, x in { -2.6, 2.6 } do
		kit.Props.cover(cor, "Sandbags", CF(x, 0, -186)) -- vault or jump it
	end
	for _, z in { -192, -170, -156 } do
		lamp(cor, 0, 9.6, z, 26, 1.2)
	end
	controlSign(cor, -4.2, 6, -194, -90, { "Vault" }, "BARRICADE")
	controlSign(cor, 4.2, 6, -168, 90, { "Interact", "Inventory" }, "THE BODY")

	-- ── 3. the parking garage ───────────────────────────────────────────────────
	local gar = room("Garage", -60, 60, -150, -70, 11, hex("6C6A62"), hex("4E4C48"), M.Concrete, { n = { { 0, 9, 0, 9 } }, s = { { 40, 18, 0, 10 } } })
	for _, x in { -20, 20 } do
		for _, z in { -125, -95 } do
			B(gar, 3.2, 11, 3.2, x, 5.5, z, hex("7A786E"), M.Concrete)
		end
	end
	for x = -52, 52, 13 do
		B(gar, 0.4, 0.06, 14, x, 0.06, -143, hex("D8D2B0"), M.SmoothPlastic) -- bay lines
		B(gar, 0.4, 0.06, 14, x, 0.06, -77, hex("D8D2B0"), M.SmoothPlastic)
	end
	kit.Props.cover(gar, "CarWreck", CF(-38, 0, -138, 4))
	kit.Props.cover(gar, "CarWreck", CF(-8, 0, -112, 82))
	kit.Props.cover(gar, "CarWreck", CF(26, 0, -120, -6))
	kit.Props.cover(gar, "CarWreck", CF(-42, 0, -96, 92))
	kit.Props.cover(gar, "CarWreck", CF(44, 0, -100, 178))
	kit.Props.cover(gar, "PalletStack", CF(6, 0, -84))
	for _, x in { -40, 0, 40 } do
		for _, z in { -132, -90 } do
			lamp(gar, x, 10.6, z, 34, 0.9)
		end
	end
	controlSign(gar, -10.5, 6, -149.2, 180, { "Primary", "Reload", "MagCheck" }, "WEAPON")
	controlSign(gar, 10.5, 6, -149.2, 180, { "Aim", "Fire", "LeanLeft", "LeanRight" }, "FIGHT")
	for _, o in { { -12, -128, 20 }, { 30, -86, -40 }, { -30, -100, 70 } } do
		P(gar, "OilStain", o[1], 0, o[2], o[3], { collide = false })
	end
	P(gar, "TyreStack", 55, 0, -144, 0)
	P(gar, "TyreStack", -55, 0, -76, 30)
	P(gar, "JerryCans", -56, 0, -144, 90)
	P(gar, "Drum", 56, 0, -78, 0)
	P(gar, "Drum", 53.6, 0, -78.4, 0)
	P(gar, "PalletBoxes", -54, 0, -112, 0)

	-- ── 4. the street ───────────────────────────────────────────────────────────
	local st = kit.model("Street", map)
	B(st, 200, 0.12, 22, 0, 0.06, -32, C.asphalt, M.Asphalt)
	for x = -92, 92, 16 do
		B(st, 7, 0.14, 0.5, x, 0.08, -32, C.line, M.SmoothPlastic)
	end
	for _, x in { 32, 37.7, 43.4, 49.1 } do
		kit.Props.cover(st, "Sandbags", CF(x, 0, -58)) -- the wall in front of the ramp
	end
	kit.Props.cover(st, "CarWreck", CF(-46, 0, -26, 96))
	kit.Props.cover(st, "BarrierBroken", CF(-18, 0, -12, 10))
	kit.Props.cover(st, "Dumpster", CF(70, 0, -10, 90))
	for _, x in { -70, 0, 70 } do
		local pole = B(st, 0.8, 18, 0.8, x, 9, -46, C.metalDark, M.Metal)
		pole.Name = "LampPole"
		lamp(st, x, 18, -44, 70, 1.4)
	end
	controlSign(st, 16, 6, 9.2, 0, { "Sprint", "Crouch" }, "CROSS")

	-- ── 5. the office block ─────────────────────────────────────────────────────
	local off = room("Office", -30, 30, 10, 60, 12, hex("A8A496"), hex("5E5A52"), M.Carpet, { n = { { 0, 7, 0, 9 } }, s = { { 0, 7, 0, 9 } } }, M.Plaster)
	wallZ(off, 10, 44, -10, 12, hex("8E8A7E"), M.Concrete, { { 30, 6, 0, 9 } }) -- a partition with a door
	for _, x in { 11, 17 } do
		P(off, "OfficeDesk", x, 0, 30, 180) -- desks for cover
	end
	for _, x in { -23, -17 } do
		P(off, "OfficeDesk", x, 0, 50, 0)
	end
	P(off, "Chair", 12, 0, 33.4, 0)
	P(off, "Chair", -20, 0, 46.6, 180)
	P(off, "Whiteboard", -9.15, 3, 20, -90)
	P(off, "StorageShelf", 28.4, 0, 48, 90)
	P(off, "WallClock", 0, 9.5, 10.75, 180)
	P(off, "CardboardPile", 24, 0, 16, 30)
	for _, z in { 22, 46 } do
		lamp(off, -20, 11.6, z, 30, 1.2)
		lamp(off, 12, 11.6, z, 30, 1.2)
	end
	controlSign(off, 9, 6, 10.8, 180, { "Heal", "Inventory" }, "FIRST AID")

	-- ── 6. the yard, the tents and the gate ─────────────────────────────────────
	local yard = kit.model("Yard", map)
	local function tent(x, z)
		local t = kit.model("Tent", yard)
		local cloth = hex("5B6448")
		B(t, 16, 0.3, 12, x, 0.15, z, hex("3A3D33"), M.Fabric)
		B(t, 0.4, 7, 12, x - 8, 3.5, z, cloth, M.Fabric)
		B(t, 0.4, 7, 12, x + 8, 3.5, z, cloth, M.Fabric)
		B(t, 16, 7, 0.4, x, 3.5, z + 6, cloth, M.Fabric)
		B(t, 17, 0.4, 13, x, 7.2, z, cloth, M.Fabric)
		B(t, 6, 2.4, 3, x - 4, 1.2, z + 3, hex("4A4F55"), M.Metal) -- a field table
		lamp(t, x, 6.6, z, 20, 0.9)
		P(t, "MedCot", x + 4, 0, z + 1.8, 90)
		return t
	end
	tent(-30, 92)
	tent(30, 92)
	P(yard, "PalletBoxes", -70, 0, 120, 10)
	P(yard, "PalletBoxes", 75, 0, 80, -20)
	P(yard, "Drum", -60, 0, 70, 0)
	P(yard, "Drum", -57.6, 0, 71, 0)
	P(yard, "JerryCans", 42, 0, 96, 0)
	P(yard, "Generator", -75, 0, 95, 90)
	P(yard, "WorkLight", 64, 0, 143, 200)
	-- the fence along z = 150 with its gate at x = 52 (open)
	for x = -100, 100, 8 do
		if math.abs(x - 52) > 8 then
			B(yard, 8, 10, 0.3, x, 5, 150, hex("6E7366"), M.DiamondPlate)
		end
	end
	for _, x in { 44, 60 } do
		B(yard, 1, 11, 1, x, 5.5, 150, C.metalDark, M.Metal)
	end
	B(map, 60, 8, 40, 52, -4, 170, C.concrete, M.Concrete) -- the ground past the gate
	wallX(outer, 22, 82, 190, 16, C.concreteDark, M.Concrete)
	wallZ(outer, 150, 190, 22, 16, C.concreteDark, M.Concrete)
	wallZ(outer, 150, 190, 82, 16, C.concreteDark, M.Concrete)
	controlSign(yard, 30, 6, 149.6, 0, { "Extracts" }, "EXITS")
	-- the green flare over the exit (Tarkov's tutorial marks its exit with one; our raids mark none, decision art-8b)
	local flare = B(yard, 1, 1, 1, 52, 2, 172, GREEN, M.Neon)
	flare.Name = "ExitFlare"
	flare.CanCollide, flare.CanQuery = false, false
	kit.light(flare, GREEN, 60, 3, false)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(hex("7CFF8E"), hex("2E6B3A"))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(5, 8)
	smoke.Rate = 6
	smoke.Speed = NumberRange.new(4, 7)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.LightEmission = 0.6
	smoke.Parent = flare

	-- the guide bars: lobby, corridor, garage to the ramp, the street to the office, through it, the yard to the gate
	bars({ { 0, -236 }, { 0, -206 }, { 0, -198 }, { 0, -152 }, { 0, -140 }, { 34, -110 }, { 40, -76 }, { 40, -64 }, { 40, -40 },
		{ 0, -12 }, { 0, 8 }, { 0, 14 }, { -2, 34 }, { 0, 62 }, { 10, 110 }, { 52, 140 }, { 52, 162 } })

	-- ── the exit, the spawn and what the tutorial service needs ─────────────────
	kit.extract(map, "TG", "YARD GATE", V(52, 0, 166), Vector3.new(14, 12, 10), { kind = "open" })
	W.spawns = { { id = "T0", name = "LOBBY", cf = CF(0, 3.4, -236, 180), side = "north" } }
	W.sideExtracts = { north = { "TG" } }
	W.spawns[1].extracts = { "TG" }
	W.bounds = { x0 = O.X - 102, x1 = O.X + 102, z0 = O.Z - 252, z1 = O.Z + 192, yMin = -4, yMax = 20 }
	W.tutorial = {
		origin = O,
		spawnCF = CF(0, 3.4, -236, 180),
		desk = V(0, 4.2, -214),
		body = { cf = CF(3.2, 0.6, -164, 0), pile = V(-2.6, 0.5, -163) },
		tentA = V(-34, 2.6, 95),
		tentB = V(26, 2.6, 95),
		-- scav posts: the garage pair, one on the street, one in the office
		posts = {
			{ group = "garage", pos = V(-30, 3.4, -92), leash = 18 }, { group = "garage", pos = V(36, 3.4, -108), leash = 18 },
			{ group = "street", pos = V(-50, 3.4, -18), leash = 22 }, { group = "office", pos = V(16, 3.4, 40), leash = 10 },
		},
		zones = {
			garage = { x0 = O.X - 60, x1 = O.X + 60, z0 = O.Z - 150, z1 = O.Z - 70 },
			office = { x0 = O.X - 30, x1 = O.X + 30, z0 = O.Z + 10, z1 = O.Z + 60 },
			yard = { x0 = O.X - 100, x1 = O.X + 100, z0 = O.Z + 62, z1 = O.Z + 190 },
		},
		signs = signs,
		model = map,
	}
	return map
end
