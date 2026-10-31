--!nonstrict
-- M13 map: BORDER YARD (customs-type, docs/maps/BORDER_YARD.md). An original layout of the kind of place Tarkov's
-- Customs is: a customs terminal on a river crossing. The highway runs west to east past the checkpoint (canopy,
-- booth, barriers, the two-storey customs office with its records room), two dormitory blocks round a courtyard
-- (the Broker's), the bridge road north over the river, a fuel stop, a fenced tank farm, two warehouses and a crane
-- yard, a trailer lot in the trees, a building site with a boiler house, and the rail line along the south.
-- Ground is Roblox terrain from a height function (flat yards, the river channel and banks, berms closing the view;
-- asphalt, concrete, grass and mud by area). Built once at server start at its own origin.
-- Local coordinates: x east, z south (north = -z), ground y = 0, river surface y = -4.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local O = Vector3.new(0, 0, -2000)
local PX, PZ = 300, 170 -- playable half-extents (invisible walls just outside)
local WL = -4 -- river level (a voxel boundary)
local FH = 4.2 -- dorm storey height

return function(kit, root)
	local W, C, M, hex = kit.World, kit.C, kit.M, kit.hex
	local rng = Random.new(1717)
	local map = kit.model("BorderYard", root)
	local H = require(script.Parent.MapKit)(kit, O)
	local V, CF, B, VC = H.V, H.CF, H.B, H.VC
	local Kit = require(script.Parent.Kit)
	-- a Blender kit prop (indoors they cast no sun shadow; contact shadows are baked in)
	local nProps = 0
	local function P(parent, name, x, y, z, ry, opts)
		opts = opts or {}
		if opts.shadows == nil then
			opts.shadows = false
		end
		local m = Kit.place(parent, name, CF(x, y, z, ry), opts)
		if m then
			nProps += 1
		end
		return m
	end
	local function anchorOf(m)
		return m and m:FindFirstChild("KitCollider") or nil
	end
	local terrain = workspace.Terrain

	-- palette
	local CONC, CONC_D, BRICK, BRICK_D = hex("8A867D"), hex("5E5B55"), hex("7A5747"), hex("5C4337")
	local PANEL, TRIM, GLASS, STEEL = hex("9EA39A"), hex("4A4E4A"), hex("6F8A92"), hex("5A5E60")
	local RED, WHITE, YELLOW = hex("8C3A30"), hex("D8D6CF"), hex("B8923A")

	-- ── terrain: flat yards, the river channel and banks, berms beyond the play area ─────────────────────
	local function inRoad(x, z)
		return (math.abs(z + 30) <= 8 and math.abs(x) <= 340) -- highway
			or (math.abs(x - 48) <= 6 and z <= -22 and z >= -118) -- bridge road
			or (math.abs(x - 136) <= 6 and z >= -22 and z <= 140) -- south road
			or (math.abs(z - 2) <= 5 and x >= 66 and x <= 136) -- fuel stop apron link
	end
	local function inYard(x, z)
		return (x >= -290 and x <= -205 and z >= -50 and z <= 30) -- checkpoint
			or (x >= 20 and x <= 96 and z >= -22 and z <= 22) -- fuel stop
			or (x >= -134 and x <= -26 and z >= 26 and z <= 114) -- tank farm
			or (x >= 146 and x <= 292 and z >= -18 and z <= 100) -- warehouses and crane yard
			or (x >= -284 and x <= -176 and z >= 36 and z <= 152) -- building site
			or (x >= -136 and x <= -14 and z >= -108 and z <= -44) -- dorms
	end
	local function ground(x, z)
		if z <= -140 then
			return -12
		elseif z < -118 then
			return -12 + 12 * (z + 140) / 22
		end
		local over = math.max(math.abs(x) - (PX + 8), z - (PZ + 8), 0)
		if over > 0 then
			return math.min(18, over * 0.45) + math.noise(x / 31, z / 31) * 2
		end
		return 0
	end
	local TK = require(script.Parent.TerrainKit)
	local T = TK.build({
		O = O, extX = 352, extZ = 232, y0 = -24, ny = 12, wl = WL,
		ground = ground,
		water = function(x, z)
			return z < -118
		end,
		material = function(x, z, h)
			if h < -0.5 then
				return (h < -6) and Enum.Material.Mud or Enum.Material.Sand
			elseif inRoad(x, z) then
				return Enum.Material.Asphalt
			elseif inYard(x, z) then
				return Enum.Material.Concrete
			end
			return (math.noise(x / 46, z / 46, 0.37) > 0.08) and Enum.Material.Grass or Enum.Material.Ground
		end,
		colors = {
			[Enum.Material.Asphalt] = "3B3B38", [Enum.Material.Concrete] = "75726B", [Enum.Material.Ground] = "5A5040",
			[Enum.Material.Grass] = "5D6A3D", [Enum.Material.Mud] = "463C30", [Enum.Material.Sand] = "6E6450",
		},
	})
	local _ = T

	-- highway markings: centre dashes and edge lines
	local marks = kit.model("Markings", map)
	for x = -296, 296, 12 do
		B(marks, 6, 0.06, 0.4, x, 0.03, -30, hex("C9C2A5"), M.SmoothPlastic)
	end
	for _, z in { -37.6, -22.4 } do
		B(marks, 2 * PX, 0.06, 0.3, 0, 0.03, z, hex("BFBBA8"), M.SmoothPlastic)
	end

	-- door slabs: Doors.luau builds them from W.doors (key = the item that opens it)
	local function door(id, label, parent, cf, w, key, color, h)
		W.doors[id] = { id = id, cf = cf, size = Vector3.new(w or 3.4, h or 3.6, 0.3), key = key, label = label, parent = parent, color = color or TRIM }
	end

	-- a box building: walls round x0..x1, z0..z1 on floors (each { y0, h }), with holes per side
	-- holes = { n = { {x, w, bottom, top} }, s = ..., w = { {z, w, b, t} }, e = ... }
	local function shell(parent, x0, x1, z0, z1, floors, color, mat, holes, t)
		t = t or 0.8
		for fi, f in floors do
			local hs = holes[fi] or {}
			H.wallX(parent, x0, x1, z0, f[1], f[2], t, color, mat, hs.n)
			H.wallX(parent, x0, x1, z1, f[1], f[2], t, color, mat, hs.s)
			H.wallZ(parent, z0, z1, x0, f[1], f[2], t, color, mat, hs.w)
			H.wallZ(parent, z0, z1, x1, f[1], f[2], t, color, mat, hs.e)
		end
	end
	-- a row of windows along a wall (holes table entries)
	local function windows(a0, a1, step, bottom, top, skip)
		local out = {}
		for a = a0, a1, step do
			if not (skip and skip(a)) then
				table.insert(out, { a, 2.4, bottom, top })
			end
		end
		return out
	end

	-- ── CHECKPOINT (west): canopy over the highway, the booth, barriers, the customs office ────────────────
	local cp = kit.model("Checkpoint", map)
	B(cp, 34, 0.8, 34, -252, 8.9, -30, CONC_D, M.Concrete)
	B(cp, 34.4, 1.4, 0.6, -252, 8.6, -47, YELLOW, M.Metal)
	B(cp, 34.4, 1.4, 0.6, -252, 8.6, -13, YELLOW, M.Metal)
	for _, x in { -266, -252, -238 } do
		for _, z in { -45, -15 } do
			VC(cp, 8.5, 1.2, x, 0, z, CONC, M.Concrete)
		end
	end
	-- the booth on the median, glass all round
	B(cp, 4, 0.4, 7, -252, 0.2, -30, CONC_D, M.Concrete)
	for _, sx in { -1, 1 } do
		B(cp, 0.3, 3.2, 7, -252 + sx * 1.85, 2, -30, TRIM, M.Metal)
	end
	B(cp, 4, 1.2, 0.3, -252, 1, -33.4, TRIM, M.Metal)
	B(cp, 4, 1.2, 0.3, -252, 1, -26.6, TRIM, M.Metal)
	local g1 = B(cp, 3.4, 2, 0.12, -252, 2.6, -33.4, GLASS, M.Glass)
	g1.Transparency = 0.5
	local g2 = B(cp, 3.4, 2, 0.12, -252, 2.6, -26.6, GLASS, M.Glass)
	g2.Transparency = 0.5
	B(cp, 4.4, 0.4, 7.4, -252, 3.8, -30, TRIM, M.Metal)
	kit.container(cp, "BY_BOOTH", "weaponbox", "Booth gun locker", CF(-252, 0.4, -31.5, 90))
	-- barriers (one arm up, one down) and the speed bumps
	for _, e in { { -264, -34, 0 }, { -240, -26, 70 } } do
		VC(cp, 1.4, 0.8, e[1], 0, e[2] + (e[2] < -30 and -4 or 4), RED, M.Metal)
		local arm = kit.boxCF(cp, 0.3, 0.3, 7.6, CF(e[1], 1.3, e[2], 0) * CFrame.Angles(math.rad(e[3]), 0, 0) * CFrame.new(0, 0, 0), WHITE, M.SmoothPlastic)
		arm.Name = "Barrier"
	end
	for _, x in { -272, -232 } do
		B(cp, 0.8, 0.25, 14, x, 0.12, -30, YELLOW, M.Metal)
	end
	P(cp, "SandbagsLow", -246, 0, -50, 0, { shadows = true })
	P(cp, "WorkLight", -274, 0, -48, 30, { shadows = true })
	-- the truck queue east of the canopy and a tanker on the shoulder
	H.truck(cp, CF(-212, 0, -26, 90), "box")
	H.truck(cp, CF(-190, 0, -26, 90), "box")
	H.truck(cp, CF(-205, 0, -43, -90), "tanker")
	-- the customs office: two storeys, offices along a corridor, the records room (key)
	local of = kit.model("CustomsOffice", cp)
	local OX0, OX1, OZ0, OZ1, OH = -252, -214, -4, 24, 4.6
	B(of, OX1 - OX0, 0.4, OZ1 - OZ0, (OX0 + OX1) / 2, 0.2, (OZ0 + OZ1) / 2, CONC_D, M.Concrete)
	shell(of, OX0, OX1, OZ0, OZ1, { { 0.4, OH }, { 0.4 + OH, OH } }, PANEL, M.Concrete, {
		{ n = { { -233, 4, 0, 3.8 }, { -246, 2.4, 1.2, 3.4 }, { -240, 2.4, 1.2, 3.4 }, { -226, 2.4, 1.2, 3.4 }, { -220, 2.4, 1.2, 3.4 } },
			s = windows(-248, -218, 6, 1.2, 3.4), w = windows(0, 20, 6, 1.2, 3.4), e = { { 16, 3.2, 0, 3.8 } } },
		{ n = windows(-248, -218, 5, 1.2, 3.4), s = windows(-248, -218, 6, 1.2, 3.4), w = windows(0, 20, 6, 1.2, 3.4), e = windows(0, 20, 6, 1.2, 3.4) },
	})
	door("BY_OFFICE_FRONT", "Customs office", of, CF(-233, 2.3, OZ0), 3.8, nil, nil, 3.8)
	door("BY_OFFICE_YARD", "Office yard door", of, CF(OX1, 2.3, 16, 90), 3.2, nil, nil, 3.8)
	-- ground floor: corridor along z = 10; offices north, the records room and the guard room south
	H.wallX(of, OX0, OX1, 7.5, 0.4, OH, 0.4, PANEL, M.Concrete, { { -244, 3, 0, 3.6 }, { -232, 3, 0, 3.6 }, { -222, 3, 0, 3.6 } })
	H.wallX(of, OX0, OX1, 12.5, 0.4, OH, 0.4, PANEL, M.Concrete, { { -244, 3, 0, 3.6 }, { -228, 3, 0, 3.6 } })
	H.wallZ(of, OZ0, 7.5, -238, 0.4, OH, 0.4, PANEL, M.Concrete)
	H.wallZ(of, OZ0, 7.5, -227, 0.4, OH, 0.4, PANEL, M.Concrete)
	H.wallZ(of, 12.5, OZ1, -236, 0.4, OH, 0.4, PANEL, M.Concrete)
	door("BY_RECORDS", "Records room", of, CF(-244, 2.2, 12.5), 2.9, "KEY_BY_RECORDS", hex("5A5040"))
	for _, d in { { -247, 1 }, { -232, 0 }, { -220, 2 } } do
		P(of, "OfficeDesk", d[1], 0.4, d[2], 180)
		P(of, "Chair", d[1], 0.4, d[2] - 2.2, rng:NextNumber() * 30)
	end
	P(of, "Whiteboard", -244, 0.4, -3.4, 0)
	P(of, "WallShelf", -249, 0.4, 23.4, 180)
	P(of, "FirstAid", -214.6, 0.4, 20, -90)
	kit.container(of, "BY_OF1", "drawer", "Inspector's desk", CF(-247, 0.4, 2.6, 180))
	kit.container(of, "BY_OF2", "drawer", "Clerk's desk", CF(-220, 0.4, 3.6, 180))
	kit.container(of, "BY_REC", "safe", "Seizure safe", CF(-250.6, 0.4, 20, 90))
	kit.container(of, "BY_REC2", "drawer", "Records cabinet", CF(-240, 0.4, 22.6, 180))
	kit.container(of, "BY_GUARD", "medbag", "Guard room first aid", CF(-216, 0.4, 22.6, 180))
	-- stairs up at the east end, the upper floor an open office
	H.stairs(of, -218, 9, 0.4, 5, 1.6, 3.2, "-x", 0.4, CONC, M.Concrete)
	H.slab(of, OX0, OX1, OZ0, OZ1, 0.4 + OH, 0.4, CONC_D, M.Concrete, { { -229, -217, 7.6, 10.6 } })
	H.slab(of, OX0 - 0.6, OX1 + 0.6, OZ0 - 0.6, OZ1 + 0.6, 0.4 + 2 * OH + 0.4, 0.5, CONC_D, M.Concrete)
	for i, x in { -246, -238, -230, -222 } do
		P(of, "OfficeDesk", x, 0.4 + OH, 18, 0)
		P(of, "Chair", x, 0.4 + OH, 15.8, rng:NextNumber() * 40 - 20)
		if i % 2 == 1 then
			kit.container(of, "BY_OFU" .. i, "drawer", "Open-plan desk", CF(x, 0.4 + OH, 19.6, 180))
		end
	end
	for _, p in { { -235, 0.4 + OH - 0.5, 0 }, { -235, 0.4 + 2 * OH - 0.5, 10 } } do
		local lp = B(of, 0.6, 0.2, 2, p[1], p[2], p[3], WHITE, M.Neon)
		kit.light(lp, hex("F2E8D5"), 22, 0.6)
	end

	-- ── DORMS (north): block A (three storeys) and block B (two) round a courtyard, the Broker's ──────────────
	local dm = kit.model("Dorms", map)
	local function block(name, x0, x1, storeys, stairX)
		local b = kit.model(name, dm)
		local z0, z1, zc0, zc1 = -104, -86, -96, -93
		local n = math.floor((x1 - x0 - 6) / 6.25)
		B(b, x1 - x0, 0.4, z1 - z0, (x0 + x1) / 2, 0.2, (z0 + z1) / 2, CONC_D, M.Concrete)
		for f = 1, storeys do
			local y0 = 0.4 + (f - 1) * FH
			local ext = { n = windows(x0 + 3.2, x1 - 9, 6.25, 1.2, 3.2), s = windows(x0 + 3.2, x1 - 9, 6.25, 1.2, 3.2), w = windows(-101, -89, 6, 1.2, 3.2), e = {} }
			if f == 1 then
				table.insert(ext.s, { stairX, 3.6, 0, 3.6 }) -- the entrance at the stairwell
				table.insert(ext.w, { (zc0 + zc1) / 2, 2.6, 0, 3.4 }) -- the fire door at the far end
			end
			H.wallX(b, x0, x1, z0, y0, FH, 0.7, BRICK, M.Brick, ext.n)
			H.wallX(b, x0, x1, z1, y0, FH, 0.7, BRICK, M.Brick, ext.s)
			H.wallZ(b, z0, z1, x0, y0, FH, 0.7, BRICK, M.Brick, ext.w)
			H.wallZ(b, z0, z1, x1, y0, FH, 0.7, BRICK, M.Brick, ext.e)
			-- corridor walls with a door to each room, partitions every 6.25
			local doors = {}
			for i = 1, n do
				table.insert(doors, { x0 + (i - 0.5) * 6.25, 1.6, 0, 3.2 })
			end
			H.wallX(b, x0, x1 - 6, zc0, y0, FH, 0.3, PANEL, M.Plaster, doors)
			H.wallX(b, x0, x1 - 6, zc1, y0, FH, 0.3, PANEL, M.Plaster, doors)
			for i = 1, n - 1 do
				local x = x0 + i * 6.25
				H.wallZ(b, z0, zc0, x, y0, FH, 0.25, PANEL, M.Plaster)
				H.wallZ(b, zc1, z1, x, y0, FH, 0.25, PANEL, M.Plaster)
			end
			H.wallZ(b, z0, z1, x1 - 6, y0, FH, 0.25, PANEL, M.Plaster, { { (zc0 + zc1) / 2, 2.6, 0, 3.4 } })
			-- furniture: kit beds, bunks, tables and chairs (a different mix per room)
			for i = 1, n do
				local x = x0 + (i - 0.5) * 6.25
				local k = (i * 7 + f * 3) % 5
				P(b, (k == 0) and "BunkBedMessy" or ((k < 3) and "Bed" or "BunkBed"), x - 1.4, y0, z0 + 2.4, 90)
				if k ~= 4 then
					P(b, (k % 2 == 0) and "Table" or "Chair", x + 1.6, y0, z0 + 5.4, rng:NextNumber() * 40 - 20)
				end
				if (i + f) % 2 == 0 then
					P(b, (k == 1) and "BunkBedMessy" or "Bed", x + 1.2, y0, z1 - 2.6, -90)
				end
			end
			-- lights in the corridor
			local lp = B(b, 0.5, 0.15, 1.6, (x0 + x1) / 2, y0 + FH - 0.35, (zc0 + zc1) / 2, WHITE, M.Neon)
			kit.light(lp, hex("E8E2D0"), 20, 0.45)
			-- the stairwell at the east end: one flight per storey, the lanes alternating so each lands on a floor
			local lane = (f % 2 == 1) and (x1 - 4.3) or (x1 - 1.7)
			if f < storeys then
				H.slab(b, x0, x1, z0, z1, y0 + FH, 0.35, CONC, M.Concrete, { { lane - 1.3, lane + 1.3, z1 - 8.4, z1 - 0.4 } })
				H.stairs(b, lane, z1 - 1.2, y0, 4, 1.7, 2.4, "-z", y0, CONC, M.Concrete)
			end
		end
		local top = 0.4 + storeys * FH
		H.slab(b, x0 - 0.5, x1 + 0.5, z0 - 0.5, z1 + 0.5, top + 0.4, 0.5, CONC_D, M.Concrete)
		door(name .. "_ENTRY", name .. " entrance", b, CF(stairX, 2.2, z1), 3.6)
		return b, n
	end
	local blockA, nA = block("BlockA", -134, -84, 3, -87)
	local blockB = block("BlockB", -74, -30, 2, -33)
	-- room 314 (block A, third storey, fourth room on the north side): the key room
	local r314x = -134 + 3.5 * 6.25
	door("BY_314", "Room 314", blockA, CF(r314x, 0.4 + 2 * FH + 1.6, -96), 1.6, "KEY_BY_314", hex("6A4A36"), 3.2)
	kit.container(blockA, "BY_314S", "safe", "Room 314 safe", CF(r314x - 1.8, 0.4 + 2 * FH, -103.3))
	kit.container(blockA, "BY_314W", "weaponbox", "Room 314 rifle case", CF(r314x + 1.6, 0.4 + 2 * FH, -100, -90))
	for i, s in { { -128, 1, -98 }, { -115, 1, -89 }, { -103, 2, -98 }, { -96, 2, -89 }, { -122, 3, -89 }, { -66, 1, -98 }, { -52, 2, -89 }, { -42, 1, -89 } } do
		local y = 0.4 + (s[2] - 1) * FH
		local south = s[3] > -93
		local parent = s[1] < -80 and blockA or blockB
		local lz = south and -87.2 or -102.9
		local lm = P(parent, "Locker", s[1], y, lz, south and 180 or 0)
		kit.container(parent, "BY_DL" .. i, "locker", "Dorm locker", CF(s[1], y, lz, south and 180 or 0), anchorOf(lm))
	end
	kit.container(blockB, "BY_DMED", "medbag", "Dorm first aid", CF(-35, 0.4, -94.5, 90))
	kit.container(blockB, "BY_DWB", "weaponbox", "Broker's stash", CF(-70, 0.4 + FH, -103.3))
	local _ = nA
	-- the courtyard: parked cars, a low wall with a gate to the highway, the V-Ex car
	for i, c in { { -120, -68, 0 }, { -104, -62, 15 }, { -60, -66, -8 }, { -30, -60, 170 } } do
		P(dm, (i == 3) and "CarSedanSmashed" or "CarSedan", c[1], 0, c[2], c[3], { shadows = true, tint = (i == 2) and hex("7A6A50") or nil })
	end
	P(dm, "Bin", -130, 0, -50, 0)
	P(dm, "Bench", -90, 0, -48, 180)
	H.wallX(dm, -136, -14, -46, 0, 2.2, 0.6, CONC, M.Concrete, { { -78, 10, 0, 2.2 } })
	H.wallZ(dm, -104, -46, -136, 0, 2.2, 0.6, CONC, M.Concrete)
	H.wallZ(dm, -104, -46, -14, 0, 2.2, 0.6, CONC, M.Concrete)
	kit.container(dm, "BY_YARD", "crate", "Courtyard pallets", CF(-24, 0, -54))

	-- ── BRIDGE (north): the bridge road over the river ───────────────────────────────────────────────────
	local br = kit.model("Bridge", map)
	B(br, 13, 1.2, 66, 48, 0.4, -146, CONC_D, M.Concrete)
	B(br, 12, 0.08, 66, 48, 1.04, -146, hex("3B3B38"), M.Asphalt)
	for _, x in { 41.6, 54.4 } do
		H.rail(br, x, -113, x, -179, 1, STEEL, M.Metal)
	end
	for _, z in { -128, -150, -172 } do
		VC(br, 16, 4, 48, -15, z, CONC_D, M.Concrete)
	end

	-- ── FUEL STOP (south of the highway): canopy, pump islands, the shop ───────────────────────────────────
	local fs = kit.model("FuelStop", map)
	B(fs, 38, 0.7, 26, 46, 6.6, -2, WHITE, M.SmoothPlastic)
	B(fs, 38.4, 1, 0.4, 46, 6.4, -15.2, RED, M.SmoothPlastic)
	B(fs, 38.4, 1, 0.4, 46, 6.4, 11.2, RED, M.SmoothPlastic)
	for _, x in { 32, 60 } do
		for _, z in { -10, 6 } do
			VC(fs, 6.4, 0.9, x, 0, z, STEEL, M.Metal)
		end
	end
	for _, x in { 38, 54 } do
		for _, z in { -6, 2 } do
			B(fs, 1.4, 0.3, 3.6, x, 0.15, z, CONC, M.Concrete)
			B(fs, 1, 2.2, 0.8, x, 1.4, z, hex("C7C2B6"), M.SmoothPlastic)
		end
	end
	local sh = kit.model("FuelShop", fs)
	B(sh, 20, 0.4, 18, 82, 0.2, 0, CONC_D, M.Concrete)
	shell(sh, 72, 92, -9, 9, { { 0.4, 4.4 } }, PANEL, M.Concrete, {
		{ w = { { -4, 6, 1, 3.6 }, { 4, 3, 0, 3.6 } }, n = windows(76, 88, 6, 1.2, 3.4), s = { { 88, 2.6, 0, 3.4 } }, e = {} },
	})
	door("BY_SHOP", "Fuel stop shop", sh, CF(72, 2.2, 4, 90), 2.8)
	H.slab(sh, 71.4, 92.6, -9.6, 9.6, 5.2, 0.4, CONC_D, M.Concrete)
	local till = P(sh, "Checkout", 77, 0.4, -4, 90)
	kit.container(sh, "BY_TILL", "register", "Till", CF(77, 0.4, -4, 90), anchorOf(till))
	local fridge = P(sh, "Fridge", 90.6, 0.4, -5, -90)
	kit.container(sh, "BY_COOL", "cooler", "Drinks fridge", CF(90.6, 0.4, -5, -90), anchorOf(fridge))
	local gon = P(sh, "Gondola", 84, 0.4, 2, 0)
	kit.container(sh, "BY_SHELF", "grocery", "Shop shelf", CF(84, 0.4, 2), anchorOf(gon))
	P(sh, "GondolaSparse", 84, 0.4, 6.4, 0)
	P(sh, "Vending", 91, 0.4, 6, -90)
	local sl = B(sh, 0.6, 0.2, 2, 82, 4.6, 0, WHITE, M.Neon)
	kit.light(sl, hex("F0E9D8"), 18, 0.5)

	-- ── TANK FARM (south centre): four tanks, a pipe rack, the pump house, a fence ─────────────────────────
	local tf = kit.model("TankFarm", map)
	for _, p in { { -110, 50 }, { -70, 50 }, { -110, 92 }, { -70, 92 } } do
		VC(tf, 15, 20, p[1], 0, p[2], hex("A8A79E"), M.Metal)
		VC(tf, 0.6, 20.6, p[1], 15, p[2], hex("8F8E86"), M.Metal)
		VC(tf, 1, 22, p[1], 0, p[2], CONC_D, M.Concrete)
		-- a ladder up each tank
		B(tf, 1.2, 15, 0.3, p[1] + 10.3, 7.5, p[2], STEEL, M.Metal)
	end
	for x = -126, -40, 12 do
		B(tf, 0.6, 5, 0.6, x, 2.5, 71, STEEL, M.Metal)
	end
	B(tf, 88, 0.5, 1.6, -83, 5, 71, STEEL, M.Metal)
	for _, dz in { -0.4, 0.4 } do
		kit.cyl(tf, 88, 0.7, CF(-83, 5.6, 71 + dz), hex("6E6A5E"), M.Metal)
	end
	local ph = kit.model("PumpHouse", tf)
	B(ph, 16, 0.4, 16, -42, 0.2, 48, CONC_D, M.Concrete)
	shell(ph, -50, -34, 40, 56, { { 0.4, 5 } }, CONC, M.Concrete, { { n = { { -42, 3.4, 0, 3.8 } }, s = windows(-46, -38, 8, 1.6, 3.6), w = {}, e = {} } })
	door("BY_PUMP", "Pump house", ph, CF(-42, 2.3, 40), 3.2, nil, nil, 3.8)
	H.slab(ph, -50.6, -33.4, 39.4, 56.6, 5.8, 0.4, CONC_D, M.Concrete)
	VC(ph, 2.6, 3, -46, 0.4, 50, hex("4F6A5A"), M.Metal)
	local chest = P(ph, "ToolChest", -37, 0.4, 54, 180)
	kit.container(ph, "BY_PUMPT", "toolbox", "Fitter's toolbox", CF(-37, 0.4, 54, 180), anchorOf(chest))
	P(ph, "ElectricCabinet", -49.2, 0.4, 52, 90)
	P(ph, "PipeValve", -46, 0.4, 44, 0)
	for k, p in { { -124, 34 }, { -40, 104 }, { -96, 108 }, { -60, 34 } } do
		P(tf, (k % 2 == 0) and "Drum" or "JerryCans", p[1], 0, p[2], k * 40, { shadows = true })
	end
	P(tf, "HoseReel", -90, 0, 30, 0, { shadows = true })
	kit.container(ph, "BY_PUMPW", "weaponbox", "Watchman's case", CF(-48.5, 0.4, 44, 90))
	kit.container(tf, "BY_TF1", "crate", "Valve crates", CF(-56, 0, 104))
	kit.container(tf, "BY_TF2", "crate", "Drum pallet", CF(-124, 0, 106))
	H.fence(tf, -134, 26, -60, 26, 0, 3.4)
	H.fence(tf, -46, 26, -26, 26, 0, 3.4)
	H.fence(tf, -134, 114, -26, 114, 0, 3.4)
	H.fence(tf, -134, 26, -134, 114, 0, 3.4)
	H.fence(tf, -26, 26, -26, 114, 0, 3.4)

	-- ── WAREHOUSES and the CRANE YARD (east) ────────────────────────────────────────────────────────────
	local wh = kit.model("Warehouses", map)
	local function shed(name, x0, x1, z0, z1, doorN, doorS)
		local s = kit.model(name, wh)
		B(s, x1 - x0, 0.4, z1 - z0, (x0 + x1) / 2, 0.2, (z0 + z1) / 2, CONC_D, M.Concrete)
		shell(s, x0, x1, z0, z1, { { 0.4, 12 } }, hex("7D817A"), M.CorrodedMetal, {
			{ n = { { doorN, 10, 0, 8 } }, s = { { doorS, 10, 0, 8 } }, w = windows(z0 + 8, z1 - 8, 10, 8.5, 10.5), e = windows(z0 + 8, z1 - 8, 10, 8.5, 10.5) },
		}, 0.6)
		H.roof(s, x0, x1, z0, z1, 12.4, 12, "x", hex("6B6E68"), M.CorrodedMetal, hex("7D817A"))
		-- pallet racks in rows, pallets and drums on the floor, a forklift
		for i, z in { z0 + 12, z0 + 22, z0 + 32 } do
			for j, x in { x0 + 10, x0 + 22, x1 - 22, x1 - 10 } do
				P(s, ((i + j) % 3 == 0) and "StorageRackEmpty" or "PalletRack", x, 0.4, z, 0)
			end
		end
		P(s, "Forklift", x0 + 30, 0.4, z0 + 5, 90, { shadows = false })
		for k = 1, 4 do
			P(s, (k % 2 == 0) and "PalletBoxes" or "Drum", x0 + 4 + k * 3, 0.4, z1 - 4, rng:NextNumber() * 360)
		end
		for _, p in { { (x0 + x1) / 2 - 10, z0 + 18 }, { (x0 + x1) / 2 + 10, z1 - 10 } } do
			local lp = B(s, 0.8, 0.2, 2, p[1], 11.6, p[2], WHITE, M.Neon)
			kit.light(lp, hex("E9E4D6"), 28, 0.5)
		end
		return s
	end
	local w3 = shed("Warehouse3", 150, 210, -14, 36, 172, 196)
	local w9 = shed("Warehouse9", 226, 286, -14, 36, 248, 270)
	for i, p in { { 160, -2 }, { 200, 26 }, { 186, 9 } } do
		kit.container(w3, "BY_W3C" .. i, "crate", "Warehouse 3 crate", CF(p[1], 0.4, p[2]))
	end
	kit.container(w3, "BY_W3T", "toolbox", "Forklift toolbox", CF(208, 0.4, -10, -90))
	for i, p in { { 236, -2 }, { 276, 26 } } do
		kit.container(w9, "BY_W9C" .. i, "crate", "Warehouse 9 crate", CF(p[1], 0.4, p[2]))
	end
	-- the cage in warehouse 9: seized weapons
	H.fence(w9, 268, 0, 284, 0, 0.4, 4)
	H.fence(w9, 268, 0, 268, 12, 0.4, 4)
	kit.container(w9, "BY_W9W", "weaponbox", "Seized weapons", CF(280, 0.4, -10))
	kit.container(w9, "BY_W9T", "toolbox", "Cage toolbox", CF(282, 0.4, 6, -90))
	-- crane yard: container stacks and a gantry crane
	local cy = kit.model("CraneYard", wh)
	local CCOL = { hex("7A3F32"), hex("3F5A6E"), hex("6E6A3E"), hex("4F5A4A"), hex("8A6A3A") }
	for i, p in { { 160, 58, 0 }, { 160, 66, 0 }, { 176, 58, 1 }, { 210, 60, 0 }, { 210, 60, 1 }, { 226, 70, 0 }, { 256, 58, 0 }, { 256, 66, 0 }, { 256, 58, 1 }, { 272, 84, 0 } } do
		B(cy, 14, 7, 6.2, p[1], 3.5 + p[3] * 7, p[2], CCOL[(i % #CCOL) + 1], M.CorrodedMetal)
	end
	kit.container(cy, "BY_CY1", "crate", "Container goods", CF(226, 0, 76))
	kit.container(cy, "BY_CY2", "crate", "Container goods", CF(170, 0, 76))
	for _, x in { 192, 240 } do
		for _, z in { 52, 92 } do
			B(cy, 1.6, 20, 1.6, x, 10, z, YELLOW, M.Metal)
		end
		B(cy, 1.8, 1.8, 42, x, 20.9, 72, YELLOW, M.Metal)
	end
	B(cy, 50, 2.2, 2.2, 216, 22.4, 72, YELLOW, M.Metal)
	B(cy, 4, 2, 4, 216, 20, 72, STEEL, M.Metal)

	-- ── TRAILER LOT (south-east, in the trees) ───────────────────────────────────────────────────────────
	local tl = kit.model("TrailerLot", map)
	for i, p in { { 168, 112, 0 }, { 186, 114, 4 }, { 204, 111, -3 }, { 250, 113, 2 }, { 268, 110, -5 } } do
		local c = kit.model("Cabin" .. i, tl)
		local cx, cz = p[1], p[2]
		B(c, 12, 0.5, 6, cx, 0.6, cz, hex("5B5E58"), M.Metal)
		H.wallX(c, cx - 6, cx + 6, cz - 3, 0.85, 3.2, 0.3, hex("C2B9A2"), M.CorrodedMetal, { { cx - 3, 2.4, 1.2, 2.6 }, { cx + 3, 2.4, 1.2, 2.6 } })
		H.wallX(c, cx - 6, cx + 6, cz + 3, 0.85, 3.2, 0.3, hex("C2B9A2"), M.CorrodedMetal, { { cx + 3.5, 1.8, 0, 2.8 } })
		H.wallZ(c, cz - 3, cz + 3, cx - 6, 0.85, 3.2, 0.3, hex("C2B9A2"), M.CorrodedMetal)
		H.wallZ(c, cz - 3, cz + 3, cx + 6, 0.85, 3.2, 0.3, hex("C2B9A2"), M.CorrodedMetal)
		B(c, 12.4, 0.3, 6.4, cx, 4.2, cz, hex("8D8878"), M.CorrodedMetal)
		P(c, "Table", cx + 2, 0.85, cz, 0)
		P(c, "Chair", cx + 2, 0.85, cz + 1.6, 180)
		if i ~= 3 then
			kit.container(c, "BY_TL" .. i, (i % 2 == 0) and "locker" or "drawer", "Cabin locker", CF(cx - 4.6, 0.85, cz, 90))
		end
	end
	kit.container(tl, "BY_TLMED", "medbag", "Site first aid", CF(204, 0.85, 111, 90))
	-- pines round the lot (the Blender nature kit)
	local trees = 0
	for i = 1, 40 do
		local x, z = 150 + rng:NextNumber() * 145, 100 + rng:NextNumber() * 34
		if not (z < 118 and z > 104 and (math.abs(x - 168) < 8 or math.abs(x - 186) < 8 or math.abs(x - 204) < 8 or math.abs(x - 250) < 8 or math.abs(x - 268) < 8)) and math.abs(x - 136) > 9 then
			local s = 0.7 + rng:NextNumber() * 0.4
			local t = H.nat(tl, (i % 3 == 0) and "ZR_NAT_PineB_T" or "ZR_NAT_PineA_T", CF(x, -0.4, z, rng:NextNumber() * 360), s, nil, true)
			if t then
				t.CastShadow = false
				CollectionService:AddTag(t, "ZR_TreeShadow")
				local cr = H.nat(tl, (i % 3 == 0) and "ZR_NAT_PineB_C" or "ZR_NAT_PineA_C", CF(x, -0.4, z, rng:NextNumber() * 360), s, nil, false)
				if cr then
					cr.CastShadow = false
					CollectionService:AddTag(cr, "ZR_TreeShadow")
				end
				trees += 1
			end
		end
	end

	-- ── BUILDING SITE (south-west): a concrete frame, the boiler house with two chimneys ───────────────────
	local bs = kit.model("BuildingSite", map)
	for _, x in { -270, -256, -242, -228, -214 } do
		for _, z in { 46, 60, 74, 88 } do
			B(bs, 1, 9.4, 1, x, 4.7, z, CONC, M.Concrete)
		end
	end
	H.slab(bs, -271, -213, 45, 89, 4.8, 0.5, CONC, M.Concrete, { { -268, -264, 62, 72 } })
	H.slab(bs, -271, -213, 45, 89, 9.6, 0.5, CONC, M.Concrete, { { -240, -213, 45, 60 }, { -254, -250, 62, 72 } })
	H.stairs(bs, -266, 63, 0, 5, 1.6, 3, "+z", 0, CONC, M.Concrete)
	H.stairs(bs, -252, 63, 4.8, 5, 1.6, 3, "+z", 4.8, CONC, M.Concrete)
	for i, p in { { -200, 52 }, { -196, 70 }, { -204, 96 } } do
		for k = 0, 3 do
			kit.cyl(bs, 12, 0.3, CF(p[1], 0.3 + k * 0.32, p[2] + k * 0.4) * CFrame.Angles(0, math.rad(90), 0), hex("6A4A3A"), M.Metal)
		end
		local _ = i
	end
	VC(bs, 3, 3.4, -190, 0, 112, hex("C49A3A"), M.Metal)
	kit.container(bs, "BY_BS1", "toolbox", "Foreman's toolbox", CF(-228, 4.8, 80))
	kit.container(bs, "BY_BS2", "crate", "Site crate", CF(-200, 0, 84))
	kit.container(bs, "BY_BS3", "toolbox", "Rebar shed toolbox", CF(-186, 0, 58, 90))
	local bh = kit.model("BoilerHouse", bs)
	B(bh, 28, 0.4, 24, -268, 0.2, 136, CONC_D, M.Concrete)
	shell(bh, -282, -254, 124, 148, { { 0.4, 8 } }, BRICK_D, M.Brick, { { n = { { -268, 3.4, 0, 3.8 } }, s = {}, w = windows(128, 144, 8, 4.5, 6.8), e = windows(128, 144, 8, 4.5, 6.8) } })
	door("BY_BOILER", "Boiler house", bh, CF(-268, 2.3, 124), 3.2, "KEY_BY_BOILER", hex("4A3A30"), 3.8)
	H.slab(bh, -282.6, -253.4, 123.4, 148.6, 8.8, 0.4, CONC_D, M.Concrete)
	for _, x in { -276, -264 } do
		VC(bh, 24, 3.4, x, 0.4, 152, BRICK_D, M.Brick)
	end
	VC(bh, 4.5, 6, -272, 0.4, 138, hex("3E3A34"), M.Metal)
	kit.container(bh, "BY_BOIL", "toolbox", "Stoker's toolbox", CF(-258, 0.4, 144, -90))
	P(bh, "Generator", -258, 0.4, 130, -90)
	P(bh, "PipeRunRust", -272, 4, 146, 0)
	P(bs, "WorkLight", -232, 0, 92, 200, { shadows = true })
	P(bs, "TyreStack", -186, 0, 120, 0, { shadows = true })
	P(bs, "Rubble", -246, 0, 100, 30, { shadows = true })
	P(bs, "PalletBoxes", -210, 0, 46, 10, { shadows = true })

	-- ── RAIL LINE (south) and the tunnel portal (east) ───────────────────────────────────────────────────
	local rl = kit.model("Rail", map)
	B(rl, 2 * PX + 20, 0.6, 7, 0, 0.3, 150, hex("5A554C"), M.Slate)
	for _, dz in { -1.6, 1.6 } do
		B(rl, 2 * PX + 20, 0.35, 0.3, 0, 0.78, 150 + dz, STEEL, M.Metal)
	end
	for x = -PX - 8, PX + 8, 6 do
		B(rl, 1, 0.25, 5.4, x, 0.62, 150, hex("4A3D30"), M.Wood)
	end
	for i, x in { -150, -122, 40 } do
		local car = B(rl, 26, 8, 9, x, 5.2, 150, (i == 2) and hex("6E3A2E") or hex("4F4A3E"), M.CorrodedMetal)
		car.Name = "Boxcar"
	end
	kit.container(rl, "BY_RAIL", "crate", "Boxcar freight", CF(40, 1.2, 150))
	B(rl, 6, 18, 24, PX + 6, 9, 150, CONC_D, M.Concrete)
	local mouth = B(rl, 1, 10, 10, PX + 2.6, 5, 150, hex("0E0E0D"), M.SmoothPlastic)
	mouth.CanCollide = false

	-- ── RIVER JETTY and the smugglers' boat (north-east) ──────────────────────────────────────────────────
	local jt = kit.model("Jetty", map)
	B(jt, 8, 0.5, 20, 216, -0.2, -128, hex("6A5A44"), M.WoodPlanks)
	for _, z in { -136, -128, -120 } do
		for _, x in { 212.6, 219.4 } do
			VC(jt, 6, 0.8, x, -6, z, hex("4A3D30"), M.Wood)
		end
	end
	B(jt, 4.4, 1.6, 12, 225, -3.4, -132, hex("3F4F4A"), M.Metal)
	B(jt, 2.4, 1.2, 3, 225, -2, -129, hex("2F3B38"), M.Metal)

	-- ── loose loot ───────────────────────────────────────────────────────────────────────────────────────
	for _, s in {
		{ -247, 1.3, 1, "office", 0.5 }, { -232, 1.3, 0, "office", 0.45 }, { -220, 1.3, 2, "office", 0.45 }, { -240, 1.3, 20, "keys", 0.3 },
		{ -238, 5.9, 18, "office", 0.45 }, { -222, 5.9, 18, "office", 0.4 }, { -252, 1.2, -30, "keys", 0.25 },
		{ -128, 1.2, -100, "junk", 0.4 }, { -115, 1.2, -89, "junk", 0.35 }, { -103, 5.4, -100, "junk", 0.4 }, { -110, 9.6, -89, "keys", 0.3 },
		{ r314x, 9.6, -101, "office", 0.7 }, { -60, 1.2, -100, "junk", 0.35 }, { -45, 5.4, -89, "office", 0.4 }, { -38, 1.2, -100, "keys", 0.25 },
		{ 77, 1.3, -6, "office", 0.4 }, { 86, 2.4, -1, "junk", 0.5 }, { -42, 1.2, 52, "junk", 0.4 }, { -90, 0.3, 71, "junk", 0.3 },
		{ 166, 3, 22, "junk", 0.45 }, { 196, 0.6, 30, "junk", 0.4 }, { 252, 3, 2, "junk", 0.45 }, { 276, 1.2, -4, "keys", 0.3 },
		{ 204, 1.5, 111, "office", 0.4 }, { 268, 1.5, 110, "junk", 0.4 }, { -230, 5.4, 70, "junk", 0.4 }, { -256, 1.2, 140, "keys", 0.35 },
		{ -24, 0.3, -60, "junk", 0.35 }, { 225, -1.6, -130, "junk", 0.5 },
	} do
		kit.loose(O.X + s[1], s[2], O.Z + s[3], s[4], s[5], "border", true)
	end

	-- ── exfils, spawns, AI ───────────────────────────────────────────────────────────────────────────────
	kit.extract(map, "CR", "CROSSROADS", V(292, 0, -30), Vector3.new(10, 12, 18), { kind = "open" })
	kit.extract(map, "BR", "BRIDGE ROAD", V(48, 1, -162), Vector3.new(12, 12, 10), { kind = "open" })
	kit.extract(map, "RT", "RAIL TUNNEL", V(292, 0, 150), Vector3.new(8, 10, 12), { kind = "open" })
	kit.extract(map, "RB", "SMUGGLERS' BOAT", V(216, 0, -126), Vector3.new(8, 8, 10), { kind = "chance", chance = 0.55 })
	kit.extract(map, "TL", "TRAILER LOT", V(230, 0, 122), Vector3.new(12, 10, 10), { kind = "open" })
	kit.extract(map, "VX", "DORMS CAR", V(-104, 0, -62), Vector3.new(10, 8, 12), { kind = "paid", cost = 25000 })
	kit.extract(map, "BC", "BOILER CELLAR", V(-262, 0.4, 140), Vector3.new(8, 8, 8), { kind = "key", key = "KEY_BY_BOILER" })
	kit.extract(map, "CP", "CHECKPOINT", V(-292, 0, -30), Vector3.new(8, 12, 16), { kind = "scav" })
	local function sp(id, name, x, z, yaw, side)
		return { id = id, name = name, cf = CF(x, 3.4, z, yaw), side = side }
	end
	W.spawns = {
		sp("BW1", "OLD ROAD", -288, -60, -90, "west"), sp("BW2", "OFFICE YARD", -288, 12, -90, "west"),
		sp("BE1", "CROSSROADS", 288, -52, 90, "east"), sp("BE2", "CRANE YARD", 288, 60, 90, "east"),
		sp("BS1", "RAIL EMBANKMENT", -60, 162, 0, "south"), sp("BS2", "SIGNAL BOX", 90, 162, 0, "south"),
	}
	W.sideExtracts = {
		west = { "CR", "TL", "RT", "VX", "RB" }, east = { "BR", "BC", "VX", "RB" }, south = { "BR", "CR", "VX", "RB" },
	}
	for _, s in W.spawns do
		s.extracts = W.sideExtracts[s.side]
	end
	W.patrols = {
		CK = { V(-270, 0, -50), V(-232, 0, -50), V(-208, 0, -10), V(-210, 0, 28), V(-258, 0, 28), V(-262, 0, -8) },
		DP = { V(-138, 0, 30), V(-30, 0, 30), V(-30, 0, 110), V(-138, 0, 110) },
		WH = { V(170, 0, -22), V(286, 0, -22), V(296, 0, 44), V(216, 0, 100), V(148, 0, 44) },
		RD = { V(-180, 0, -30), V(0, 0, -30), V(130, 0, -30), V(136, 0, 60), V(0, 0, 130), V(-160, 0, 120) },
	}
	-- the Customs guards: a booth post, the office, the tank farm watchman, a warehouse round
	W.watchPosts = { { route = "CK", post = V(-252, 0.4, -29) }, { route = "CK" }, { route = "DP", post = V(-42, 0.4, 46) }, { route = "WH" } }
	W.scavZones = {
		V(-262, 0, -10), V(-226, 0, 10), V(-232, 4.6, 16), V(-200, 0, -46), V(-120, 0, -60), V(-96, 0, -94), V(-110, 4.6, -94), V(-52, 0, -94),
		V(-50, 0, -60), V(10, 0, -70), V(48, 0, -96), V(40, 0, 0), V(84, 0, 0), V(-90, 0, 32), V(-40, 0, 70), V(-120, 0, 72),
		V(170, 0, 10), V(200, 0, 30), V(256, 0, 10), V(276, 0, 0), V(190, 0, 76), V(240, 0, 84), V(200, 0, 116), V(260, 0, 118),
		V(-240, 0, 66), V(-228, 4.8, 80), V(-200, 0, 100), V(-268, 0, 136), V(-100, 0, 140), V(60, 0, 140), V(120, 0, 100), V(216, 0, -112),
	}
	W.visitZones = { DORM314 = { pos = V(r314x, 9, -100), r = 6 }, BOILER = { pos = V(-268, 0, 136), r = 10 } }
	W.boss = {
		name = "THE BROKER", label = "Broker", home = V(-52, 0.4, -94.5),
		route = { V(-52, 0.4, -94.5), V(-33, 0.4, -84), V(-60, 0, -70), V(-104, 0, -64), V(-110, 0.4, -94.5), V(-88, 0.4, -84), V(-60, 0, -52), V(40, 0, -16), V(-20, 0, -40) },
		crew = { V(-40, 0.4, -94.5), V(-64, 0, -64), V(-100, 0, -70) },
	}
	-- ── dressing pass (2026-11-01): Customs' clutter on the open ground between the areas: wrecks on the road
	-- shoulders, power-line poles with wires, broken fence runs, bushes and rocks, small cover clusters in the
	-- yards. Every piece is checked against the map's geometry (bounding boxes; the map is not in the workspace
	-- yet, so no spatial queries), kept outdoors (nothing overhead), off the roads (wrecks aside) and clear of the
	-- spawns, extracts, AI routes and posts, scav zones, loose loot and doors.
	local dressed = { wreck = 0, pole = 0, fence = 0, nature = 0, cover = 0 }
	do
		local KitMeta = require(ReplicatedStorage:WaitForChild("ZR"):WaitForChild("KitMeta"))
		local drng = Random.new(4242)
		local dm = kit.model("Dressing", map)
		-- solid geometry in 32-stud buckets (flat road and floor pieces left out)
		local CELL, buckets = 32, {}
		local function cellKey(cx, cz)
			return cx * 4096 + cz
		end
		for _, p in map:GetDescendants() do
			if p:IsA("BasePart") and ((p.CanCollide and p.Transparency < 1) or p.Name == "KitCollider") then
				local cf, sz = p.CFrame, p.Size
				local e = ((cf.RightVector * sz.X):Abs() + (cf.UpVector * sz.Y):Abs() + (cf.LookVector * sz.Z):Abs()) / 2
				local lo, hi = cf.Position - e, cf.Position + e
				local lx, lz = cf.Position.X - O.X, cf.Position.Z - O.Z
				if hi.Y > ground(lx, lz) + 0.8 and e.X < 200 and e.Z < 200 then
					local b = { lo, hi }
					for cx = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
						for cz = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
							local k = cellKey(cx, cz)
							buckets[k] = buckets[k] or {}
							table.insert(buckets[k], b)
						end
					end
				end
			end
		end
		local function hits(lo, hi)
			for cx = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
				for cz = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
					for _, b in buckets[cellKey(cx, cz)] or {} do
						if b[1].X < hi.X and b[2].X > lo.X and b[1].Y < hi.Y and b[2].Y > lo.Y and b[1].Z < hi.Z and b[2].Z > lo.Z then
							return true
						end
					end
				end
			end
			return false
		end
		-- keep-outs (world coordinates): points with radii and route segments
		local pts, segs = {}, {}
		local function pt(v, r)
			table.insert(pts, { v, r })
		end
		for _, sp in W.spawns do
			pt(sp.cf.Position, 14)
		end
		for _, e in { { 292, -30 }, { 48, -162 }, { 292, 150 }, { 216, -126 }, { 230, 122 }, { -104, -62 }, { -262, 140 }, { -292, -30 } } do
			pt(V(e[1], 0, e[2]), 12)
		end
		for _, route in W.patrols do
			for i = 1, #route do
				table.insert(segs, { route[i], route[i % #route + 1] })
			end
		end
		for i = 1, #W.boss.route do
			table.insert(segs, { W.boss.route[i], W.boss.route[i % #W.boss.route + 1] })
		end
		for _, c in W.boss.crew do
			pt(c, 5)
		end
		for _, wp in W.watchPosts do
			if wp.post then
				pt(wp.post, 6)
			end
		end
		for _, z in W.scavZones do
			pt(z, 5)
		end
		for _, d in W.doors do
			if d.parent and d.parent:IsDescendantOf(map) then
				pt(d.cf.Position, 6)
			end
		end
		for _, l in W.looseSpots or {} do
			pt(l.pos, 3)
		end
		local function segDist(p, a, b)
			local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
			local t = ab.Magnitude > 0 and math.clamp(ap:Dot(ab) / ab:Dot(ab), 0, 1) or 0
			return (ap - ab * t).Magnitude
		end
		-- is a footprint (local centre x, z; half sizes hx, hz; height h) free? returns the ground height
		local function free(x, z, hx, hz, h, opts)
			opts = opts or {}
			if z < -112 or math.abs(x) > PX - 4 or z > PZ - 4 then
				return nil
			end
			if not opts.road and (inRoad(x, z) or inRoad(x - hx, z - hz) or inRoad(x + hx, z + hz) or inRoad(x - hx, z + hz) or inRoad(x + hx, z - hz)) then
				return nil
			end
			-- the footprint's centre, corners and edge midpoints against the keep-outs
			local w = V(x, 0, z)
			local samples = {}
			for _, sx in { -1, 0, 1 } do
				for _, sz in { -1, 0, 1 } do
					table.insert(samples, V(x + sx * hx, 0, z + sz * hz))
				end
			end
			for _, q in samples do
				for _, k in pts do
					if (Vector3.new(k[1].X - q.X, 0, k[1].Z - q.Z)).Magnitude < k[2] then
						return nil
					end
				end
				for _, sg in segs do
					if segDist(q, sg[1], sg[2]) < 4.5 then
						return nil
					end
				end
			end
			local y = ground(x, z)
			if hits(Vector3.new(w.X - hx, y + 0.35, w.Z - hz), Vector3.new(w.X + hx, y + h, w.Z + hz)) then
				return nil
			end
			-- outdoors: nothing overhead
			if hits(Vector3.new(w.X - 0.5, y + h, w.Z - 0.5), Vector3.new(w.X + 0.5, y + 60, w.Z + 0.5)) then
				return nil
			end
			return y
		end
		local function kitFree(name, x, z, ry, opts)
			local sz = KitMeta.props[name].size
			local a = math.rad(ry or 0)
			local hx = (math.abs(math.cos(a)) * sz.X + math.abs(math.sin(a)) * sz.Z) / 2
			local hz = (math.abs(math.sin(a)) * sz.X + math.abs(math.cos(a)) * sz.Z) / 2
			local y = free(x, z, hx, hz, sz.Y, opts)
			if y and P(dm, name, x, y, z, ry, opts and opts.place) then
				return true
			end
			return false
		end
		-- wrecks on the shoulders of the highway (z -30) and the south road (x 136)
		for i, wx in { -176, -132, -64, -8, 22, 104, 168, 214, 262 } do
			local side = (i % 2 == 0) and 1 or -1
			local name = (i % 4 == 0) and "Van" or "CarSedanSmashed"
			if kitFree(name, wx, -30 + side * 9.5, 90 + drng:NextNumber(-12, 12), { road = true }) then
				dressed.wreck += 1
			end
		end
		for _, wz in { 34, 88 } do
			if kitFree("CarSedanSmashed", 136 + 9, wz, drng:NextNumber(-10, 10), { road = true }) then
				dressed.wreck += 1
			end
		end
		-- power-line poles along the highway's south verge, wires between neighbours
		local POLE, WIRE = hex("4A3F33"), hex("1E1F1F")
		local lastTop
		for px = -280, 280, 40 do
			local x, z = px + drng:NextNumber(-3, 3), -20.5
			local y = free(x, z, 0.6, 0.6, 22)
			if y then
				dressed.pole += 1
				local pole = VC(dm, 22, 0.7, x, y + 11, z, POLE, M.Wood)
				pole.Name = "PowerPole"
				B(dm, 0.35, 0.35, 6, x, y + 20.6, z, POLE, M.Wood).Name = "Crossarm"
				local tops = {}
				for k, dz in { -2.6, 0, 2.6 } do
					local ins = B(dm, 0.25, 0.5, 0.25, x, y + 21, z + dz, hex("8FA3A8"), M.Glass)
					ins.CanCollide = false
					tops[k] = V(x, y + 21.2, z + dz)
				end
				if lastTop and (tops[1] - lastTop[1]).Magnitude < 50 then
					for k = 1, 3 do
						local a, b = lastTop[k], tops[k]
						local wire = kit.boxCF(dm, 0.08, 0.08, (b - a).Magnitude, CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.6, 0), WIRE, M.SmoothPlastic)
						wire.CanCollide = false
						wire.CanQuery = false
						wire.CastShadow = false
						wire:SetAttribute("NoDetail", true)
					end
				end
				lastTop = tops
			else
				lastTop = nil
			end
		end
		-- broken chain-link along the highway's north verge (gaps where it fell or something is in the way)
		for fx = -200, 288, 12 do
			if drng:NextNumber() < 0.7 then
				local y0 = free(fx + 6, -41.5, 6.2, 0.4, 7)
				if y0 then
					H.fence(dm, fx, -41.5, fx + 12, -41.5, y0, 6)
					dressed.fence += 1
				end
			end
		end
		-- propane cylinders (Customs' hazard): by the fuel stop, the building site, the boiler house, the tank farm
		local Hazards = require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("Hazards"))
		local placedTanks = 0
		for _, c in { { 34, -4 }, { 37, -4.5 }, { 90, 16 }, { -250, 60 }, { -253, 60.5 }, { -214, 118 }, { -60, 40 }, { -63, 41 }, { 180, 60 } } do
			local y = free(c[1], c[2], 0.8, 0.8, 4)
			if y then
				Hazards.register(dm, CF(c[1], y, c[2], 0))
				placedTanks += 1
			end
		end
		dressed.propane = placedTanks
		-- border snipers watch a strip along each edge (Customs' out-of-bounds); spawns and extracts there stay clear
		local clear = {}
		for _, sp in W.spawns do
			table.insert(clear, sp.cf.Position)
		end
		for _, e in { { 292, -30 }, { 48, -162 }, { 292, 150 }, { 216, -126 }, { 230, 122 }, { -262, 140 }, { -292, -30 } } do
			table.insert(clear, V(e[1], 0, e[2]))
		end
		Hazards.sniperZone(V(-PX - 2, 0, -PZ - 2), V(-PX + 6, 60, PZ + 2), clear) -- west
		Hazards.sniperZone(V(PX - 6, 0, -PZ - 2), V(PX + 2, 60, PZ + 2), clear) -- east
		Hazards.sniperZone(V(-PX - 2, 0, PZ - 6), V(PX + 2, 60, PZ + 2), clear) -- south
		Hazards.sniperZone(V(-PX - 2, -20, -PZ - 2), V(PX + 2, 60, -PZ + 6), clear) -- north (the far river bank)
		-- the open ground: bushes, grass, rocks; the yards: cover clusters
		local COVER = { "PalletBoxes", "Drum", "TyreStack", "SandbagsLow", "JerryCans", "ParkingBarrier", "Sandbags" }
		for gx = -292, 292, 13 do
			for gz = -110, 164, 13 do
				local x, z = gx + drng:NextNumber(-5, 5), gz + drng:NextNumber(-5, 5)
				local roll = drng:NextNumber()
				if inYard(x, z) then
					if roll < 0.16 then
						local name = COVER[drng:NextInteger(1, #COVER)]
						if kitFree(name, x, z, drng:NextNumber(0, 360)) then
							dressed.cover += 1
							if name == "Drum" and drng:NextNumber() < 0.6 then
								kitFree("Drum", x + 2.3, z + drng:NextNumber(-1, 1), 0)
							end
						end
					end
				elseif roll < 0.42 then
					local key, sc, solid = "ZR_NAT_Bush" .. (roll < 0.2 and "1" or "2"), drng:NextNumber(1, 1.7), false
					if roll > 0.36 then
						key, sc, solid = "ZR_NAT_Rock" .. drng:NextInteger(1, 3), drng:NextNumber(0.8, 1.6), true
					elseif roll > 0.31 then
						key, sc = "ZR_NAT_Grass", drng:NextNumber(1, 1.5)
					end
					local y = free(x, z, 1.6 * sc, 1.6 * sc, 3 * sc)
					if y and H.nat(dm, key, CF(x, y - 0.2, z, drng:NextNumber(0, 360)), sc, nil, solid) then
						dressed.nature += 1
					end
				end
			end
		end
	end

	-- the play boundary: invisible walls just outside the yards
	for _, b in { { 0, -PZ - 1, 2 * PX + 4, 2 }, { 0, PZ + 1, 2 * PX + 4, 2 }, { -PX - 1, 0, 2, 2 * PZ + 4 }, { PX + 1, 0, 2, 2 * PZ + 4 } } do
		local inv = B(map, b[3], 160, b[4], b[1], 60, b[2], C.pale, M.SmoothPlastic)
		inv.Transparency = 1
		inv.CanQuery = false
		inv.CanTouch = false
		inv.CastShadow = false
		inv.Name = "Boundary"
		inv:SetAttribute("NoDetail", true)
	end
	W.bounds = { x0 = O.X - PX, x1 = O.X + PX, z0 = O.Z - PZ, z1 = O.Z + PZ, yMin = -6, yMax = 18, step = 4 }
	print(string.format("[ZR] Border Yard: %d kit props, %d trees, dorm blocks %s and %s; dressing: %d wrecks, %d poles, %d fence runs, %d nature, %d cover, %d propane", nProps, trees, blockA.Name, blockB.Name, dressed.wreck, dressed.pole, dressed.fence, dressed.nature, dressed.cover, dressed.propane or 0))
	return map
end
