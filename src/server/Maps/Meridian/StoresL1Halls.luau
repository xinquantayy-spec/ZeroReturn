--!nonstrict
-- Meridian Mall main floor, the three anchors: NESTA (furniture showrooms, warehouse racks, 21 tills), KASSA (hypermarket aisles,
-- 27 checkouts, fridge wall) and BOLTWORKS (hardware and car-parts aisles, 18 checkouts, goods-in docks), each with its locked till
-- office (MM_NESTA_CASH / MM_KASSA_CASH / MM_BOLT_CASH). The back-of-house blocks and the canteen are in StoresL1Back.luau.
-- Called by StoresL1.luau with the toolkit (StoresL1Kit.luau). Unit coordinates: x right when facing out through the front, d the
-- depth from the front wall. The halls' columns sit on a 68.75-stud grid; aisle rows stand at a sixth of that, so every sixth row
-- hides a column and the rest of the aisles stay clear.
return function(B, T)
	local kit, W, M = B.kit, B.W, B.kit.M
	local V = Vector3.new
	local PAL, n = T.PAL, T.n
	local units = B.units
	local PITCH = 68.75 / 6

	local function build(id, fn)
		local u = units[id]
		if not u or not u.cframe then
			warn("[ZR] Meridian stores L1: no unit " .. id)
			return nil
		end
		local out = nil
		local ok, err = pcall(function()
			local f = T.frame(u)
			fn(f, u)
			out = f
		end)
		if not ok then
			warn("[ZR] Meridian stores L1: " .. id .. " failed: " .. tostring(err))
		end
		return out
	end

	-- ── shared pieces ─────────────────────────────────────────────────────────────────────────────────
	-- registers on checkout counters: ranks = { { d, { x, ... } }, ... }; the counters run along d, their front toward -x
	local function checkouts(f, ranks)
		local placed = 0
		for _, rank in ranks do
			for _, x in rank[2] do
				if f:cont("register", "Cash register", x, rank[1], 90, { prop = "Checkout", quiet = true }) then
					placed += 1
				end
			end
		end
		return placed
	end

	local function office(f, o)
		return f:office(o)
	end

	-- aisles: rows along d (axis "d": at x = lo.. hi, each from b0 to b1) or along x (axis "x": at depths lo..hi); every
	-- kitEvery-th row is a run of kit props (o.prop, o.sc long), the rest cheap shelving in segments of o.seg; rows stand at a
	-- sixth of the column pitch, one of them on a column line. Returns the kit props placed.
	local function aisles(f, o)
		local axis = o.axis
		local first = f:colLine(axis == "d" and "x" or "d", o.lo, o.hi)
		local a = o.lo + 2
		if first then
			a = first + math.ceil((o.lo + 2 - first) / PITCH) * PITCH
		end
		local k = 0
		local kitRecs = {}
		local sc = V(o.sc or 3, 1, 1)
		while a <= o.hi - 2 do
			if o.kitEvery and k % o.kitEvery == 0 then
				local ry
				if axis == "d" then
					ry = (k // o.kitEvery % 2 == 0) and 90 or -90
				else
					ry = (k // o.kitEvery % 2 == 0) and 0 or 180
				end
				for _, r in f:run(o.prop or "Gondola", axis, o.b0, o.b1, ry, { inset = a, sc = sc, gap = 0.5 }) do
					kitRecs[#kitRecs + 1] = r
				end
			else
				-- segments of o.seg (30) would fit n0 times; the same length is covered by about 1.75 times fewer, longer runs
				-- (fewer parts); a run that does not fit is tried again as two halves
				local seg = o.seg or 30
				local n0 = math.floor((o.b1 - o.b0 + 1.2 + 0.01) / (seg + 1.2))
				local nseg = math.max(1, math.ceil(n0 / 1.75))
				local len = (n0 * seg + (n0 - 1) * 1.2 - (nseg - 1) * 1.2) / nseg
				local sh = { goods = o.goods, body = o.body, h = o.h }
				local p = o.b0
				for _ = 1, n0 >= 1 and nseg or 0 do
					if not f:shelf(axis, a, p, p + len, sh) then
						local half = (len - 1.2) / 2
						f:shelf(axis, a, p, p + half, sh)
						f:shelf(axis, a, p + half + 1.2, p + len, sh)
					end
					p += len + 1.2
				end
			end
			a += PITCH
			k += 1
		end
		return kitRecs
	end

	-- some of a list of placed props become containers
	local function adoptSome(f, recs, kind, label, count)
		local list = table.clone(recs)
		local done = 0
		while done < count and #list > 0 do
			local i = f.rng:NextInteger(1, #list)
			if f:adopt(list[i], kind, label) then
				done += 1
			end
			table.remove(list, i)
		end
		return done
	end

	-- two lamps over the checkout area (the shell's own lamps, every 48 studs under the hall ceiling, light the rest)
	local function checkoutLamps(f, x0, x1, d0, d1)
		f:lamps(2, 1, { x0 = x0, x1 = x1, d0 = d0, d1 = d1, bright = 0.9 })
	end

	-- ── NESTA: furniture showrooms, warehouse racks, checkouts, the till office ────────────────────────────────────
	-- station = { prop, dx, dd, ry } around a centre; the first prop must fit or the station is skipped
	local STATIONS = {
		living = { { "Sofa", 0, 0, 0 }, { "Table", 0, -6.5, 0 }, { "Planter", 11, -1, 0 }, { "Chair", -7, -6.5, -90 } },
		bedroom = { { "Bed", 0, 0, 0 }, { "Locker", -6.5, 1, 0 } },
		dining = { { "Table", 0, 0, 0 }, { "Chair", -5.5, 0, -90 }, { "Chair", 5.5, 0, 90 } },
		work = { { "OfficeDesk", 0, 0, 0 }, { "Chair", 0, -4.5, 180 }, { "Pigeonholes", 0, 5.5, 0 } },
		lounge = { { "Sofa", -4, 0, -90 }, { "Sofa", 4, 0, 90 }, { "Planter", 0, 0, 0 }, { "Bin", 0, 9, 0 } },
	}
	local ORDER = { "living", "bedroom", "dining", "work", "lounge", "living", "dining", "bedroom" }
	local function station(f, kind, x, d)
		local list = STATIONS[kind]
		local first = list[1]
		local rec = f:at(first[1], x + first[2], d + first[3], first[4], { quiet = true })
		if not rec then
			return false
		end
		for i = 2, #list do
			local e = list[i]
			f:at(e[1], x + e[2], d + e[3], e[4], { quiet = true })
		end
		return true
	end

	local function nesta(f, u)
		-- the tills: three ranks across the lanes the shell marked 26 studs inside the front
		checkouts(f, {
			{ 25.2, { -70, -50, -30, -10, 10, 30, 50, 70 } },
			{ 47, { -60, -40, -20, 0, 20, 40, 60 } },
			{ 69, { -50, -30, -10, 10, 30, 50 } },
		})
		office(f, {
			id = "MM_NESTA_CASH", key = "KEY_MM_NESTA_REG", label = "NESTA till office", w = 26, l = 20,
			cands = { { 100, 10, "L" }, { 100, 34, "L" }, { -126, 10, "R" }, { -126, 34, "R" } },
			safes = 2, drawers = 2, desk = "Cash office PC", safeLabel = "Till office safe", drawerLabel = "Cash drawer", keyChance = 0.12,
		})
		-- the warehouse: racks in rows across the back, boxes between them
		f:rows("PalletRack", -76, 232, 272, 2, 52, 0, { sc = V(2.6, 1, 1), gap = 4 })
		f:spread("crate", "Pallet", 4, -76, 232, 250, 388, { ry = 0 })
		f:spread("toolbox", "Toolbox", 1, -76, 232, 250, 388)
		f:spread("weaponbox", "Locked crate", 1, -76, 232, 250, 388)
		for _ = 1, 4 do
			f:at("CardboardPile", f.rng:NextNumber(-76, 232), f.rng:NextNumber(256, 386), f.rng:NextInteger(0, 3) * 90 - 90, { quiet = true })
		end
		f:at("Forklift", 120, 296, 90, { quiet = true })
		f:at("Forklift", -30, 330, -90, { quiet = true })
		f:run("RollCage", "x", -70, 230, 0, { inset = 380, gap = 12, limit = 4 })
		-- the showroom: stations on a grid, kinds alternating
		local k = 0
		for j = 1, 4 do
			for i = 1, 8 do
				k += 1
				local x = -182 + (i - 1) * 52
				local d = 106 + (j - 1) * 40
				station(f, ORDER[(i + j * 3) % #ORDER + 1], x, d)
			end
		end
		f:spread("drawer", "Chest of drawers", 2, -210, 210, 104, 220)
		f:spread("locker", "Wardrobe", 2, -210, 210, 104, 220)
		f:spread("jacket", "Coat rack", 1, -210, 210, 100, 220, { ry = 0 })
		-- the walls: shelving along the back and the left wall of the showroom, the way in marked by planters and benches
		f:run("WallShelf", "B", -70, 232, nil, { sc = V(3, 1, 1), gap = 0 })
		f:run("WallShelf", "R", 8, 380, nil, { sc = V(3, 1, 1), gap = 0, limit = 8 })
		f:run("WallShelf", "L", 8, 240, nil, { sc = V(3, 1, 1), gap = 0, limit = 5 })
		for _, e in u.entrances do
			if e.side == "S" then
				local ex = f:local2(e.pos.X - B.O.X, e.pos.Z - B.O.Z)
				f:at("Planter", ex - 14, 14, 0, { quiet = true })
				f:at("Bench", ex + 14, 6, 0, { quiet = true })
			end
		end
		f:at("ATM", 150, 5, 0, { quiet = true })
		f:at("Vending", -100, 4, 0, { quiet = true })
		f:at("Kiosk", 60, 128, 0, { quiet = true })
		f:run("Bin", "x", -200, 200, 0, { inset = 98, gap = 90, limit = 3 })
		-- loose loot: tables and desks, the floor beside the racks and the stations
		f:surfaces("mall", 6, 0.5)
		f:litter(7, "mall", 0.4)
		f:litter(4, "crate", 0.4)
		f:spot(-60, 262, 0.15, "mallkeys", 0.08)
		checkoutLamps(f, -80, 80, 30, 60)
	end

	-- ── KASSA: checkouts, grocery aisles in three blocks, fridge wall, wall shelving ───────────────────────────────────
	local function kassa(f, u)
		checkouts(f, {
			{ 25, { -70, -50, -30, -10, 10, 30, 50, 70 } },
			{ 47, { -60, -40, -20, 0, 20, 40, 60 } },
			{ 69, { -70, -50, -30, -10, 10, 30, 50, 70 } },
			{ 91, { -30, -10, 10, 30 } },
		})
		office(f, {
			id = "MM_KASSA_CASH", key = "KEY_MM_KASSA_REG", label = "KASSA till office", w = 26, l = 20,
			cands = { { 100, 10, "L" }, { 100, 34, "L" }, { -126, 10, "R" }, { -126, 34, "R" } },
			safes = 2, drawers = 2, desk = "Cash office PC", safeLabel = "Till office safe", drawerLabel = "Cash drawer", keyChance = 0.12,
		})
		-- the aisles run front to back; the first row of each block and every fifth one is kit shelving
		local goods = { PAL.red, PAL.blue, PAL.yellow, PAL.green, PAL.orange, PAL.white }
		local recs = {}
		for _, blk in { { -380, -190 }, { -130, 130 }, { 150, 250 } } do
			for _, r in aisles(f, { axis = "d", lo = blk[1], hi = blk[2], b0 = 112, b1 = 292, kitEvery = 5, sc = 4, goods = goods, seg = 30 }) do
				recs[#recs + 1] = r
			end
		end
		adoptSome(f, recs, "grocery", "Shelf", 4)
		for _, r in recs do
			if f.rng:NextNumber() < 0.12 then
				f:top(r, "grocery", 0.4, 1)
			end
		end
		-- fridges along the right wall, wall shelving along the back and the left wall
		local fr = f:run("Fridge", "R", 10, 150, nil, { sc = V(1.5, 1, 1), gap = 0.5 })
		adoptSome(f, fr, "cooler", "Fridge", 4)
		f:run("WallShelf", "B", -380, 250, nil, { sc = V(3.5, 1, 1), gap = 0, limit = 14 })
		f:run("WallShelf", "L", 8, 296, nil, { sc = V(3.5, 1, 1), gap = 0, limit = 8 })
		-- the entrance plaza: displays and trolley rows; the staff's lockers and a drawer at the back
		f:rows("DisplayTable", 150, 360, 20, 2, 18, 0, { sc = V(1.6, 1, 1), gap = 18, limit = 5 })
		f:run("TrolleyRow", "x", -330, -100, 0, { inset = 14, gap = 30, limit = 3 })
		f:run("Bin", "x", -370, 240, 0, { inset = 100, gap = 60, limit = 4 })
		f:spread("locker", "Staff locker", 2, -300, 130, 280, 296, { ry = 180 })
		f:spread("drawer", "Manager's drawer", 2, -300, 130, 280, 296)
		f:spread("crate", "Pallet", 2, -120, 120, 240, 292)
		f:at("ATM", 100, 5, 0, { quiet = true })
		f:at("Vending", -100, 4, 0, { quiet = true })
		f:surfaces("grocery", 5, 0.5)
		f:litter(8, "grocery", 0.4)
		f:litter(3, "mall", 0.4)
		f:spot(-120, 285, 0.15, "mallkeys", 0.08)
		checkoutLamps(f, -80, 80, 30, 80)
	end

	-- ── BOLTWORKS: checkouts, tool and fastener aisles, tyres and car parts, goods-in docks on the back wall ─────────────
	local function bolt(f, u)
		checkouts(f, {
			{ 25.3, { -70, -50, -30, -10, 10, 30, 50, 70 } },
			{ 47, { -60, -40, -20, 0, 20, 40, 60 } },
			{ 69, { -30, -10, 10 } },
		})
		office(f, {
			id = "MM_BOLT_CASH", key = "KEY_MM_BOLT_REG", label = "BOLTWORKS till office", w = 26, l = 20,
			cands = { { 100, 10, "L" }, { 100, 34, "L" }, { -126, 10, "R" }, { -126, 34, "R" } },
			safes = 2, drawers = 2, desk = "Cash office PC", safeLabel = "Till office safe", drawerLabel = "Cash drawer", keyChance = 0.12,
		})
		local goods = { PAL.orange, PAL.steel, PAL.yellow, PAL.blue, PAL.red }
		local recs = {}
		for _, blk in { { -240, -60 }, { -45, 160 } } do
			for _, r in aisles(f, { axis = "d", lo = blk[1], hi = blk[2], b0 = 100, b1 = 335, kitEvery = 4, sc = 4, prop = "WallShelfTools", goods = goods, seg = 30, body = PAL.shelfDark }) do
				recs[#recs + 1] = r
			end
		end
		adoptSome(f, recs, "toolbox", "Tool shelf", 3)
		for _, r in recs do
			if f.rng:NextNumber() < 0.12 then
				f:top(r, "toolbox", 0.4, 1)
			end
		end
		-- tool chests, tyres and drums where the shelves end
		f:spread("toolbox", "Tool chest", 4, -240, 160, 340, 346, { prop = "ToolChest", ry = 180 })
		f:run("ToolChest", "x", -235, 160, 0, { inset = 84, gap = 22, limit = 5 })
		f:run("TyreStack", "x", 290, 340, 0, { inset = 60, gap = 2, limit = 2 })
		f:run("TyreStack", "d", 70, 330, 0, { inset = 330, gap = 2, limit = 5 })
		f:run("Pegboard", "B", -230, 160, nil, { gap = 0, h = 2.5, free = true })
		f:run("WallShelfTools", "R", 40, 300, nil, { sc = V(2.5, 1, 1), gap = 0, limit = 6 })
		-- the docks: pallets, cages, a forklift, boxes
		f:spread("crate", "Pallet", 3, -230, 340, 290, 346)
		for _ = 1, 5 do
			f:at("PalletBoxes", f.rng:NextNumber(-230, 340), f.rng:NextNumber(300, 344), f.rng:NextInteger(0, 3) * 90 - 90, { quiet = true })
		end
		f:run("RollCage", "x", -200, 340, 0, { inset = 310, gap = 20, limit = 4 })
		f:at("Forklift", 60, 322, 90, { quiet = true })
		f:run("Drum", "x", 290, 340, 0, { inset = 300, gap = 2, limit = 4 })
		f:at("JerryCans", 300, 280, 0, { quiet = true })
		f:run("TrolleyRow", "x", -330, -100, 0, { inset = 14, gap = 30, limit = 3 })
		f:at("ATM", 100, 5, 0, { quiet = true })
		f:at("Vending", -100, 4, 0, { quiet = true })
		f:surfaces("toolbox", 4, 0.5)
		f:litter(8, "toolbox", 0.4)
		f:litter(3, "junk", 0.4)
		f:spot(-150, 342, 0.15, "mallkeys", 0.08)
		checkoutLamps(f, -80, 80, 30, 60)
	end

	build("L1_idea", nesta)
	build("L1_goshan", kassa)
	build("L1_oli", bolt)
end
