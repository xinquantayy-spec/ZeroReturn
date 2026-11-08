--!nonstrict
-- Meridian Mall main floor, the canteen and the back-of-house blocks: NESTA CANTEEN (the food court), NESTA STOCK ROOMS, KASSA BACK OF
-- HOUSE, BOLTWORKS STOCK BLOCK (with the goods-in room, MM_BOLT_GOODS) and BOLTWORKS OFFICES (with the manager's office,
-- MM_BOLT_OFFICE). Called by StoresL1.luau after the halls, with the same toolkit (StoresL1Kit.luau). These rooms stand under the
-- high ceiling (49.7 studs), so their lamps hang on cables. Unit coordinates: x right when facing out through the front, d the
-- depth from the front wall.
return function(B, T)
	local V = Vector3.new
	local PAL = T.PAL
	local units = B.units

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
	-- `count` props of a kind at random free spots of a rectangle (quiet when taken)
	local function sprinkle(f, name, count, x0, x1, d0, d1, ry)
		local placed = 0
		for _ = 1, count do
			local r = ry
			if r == nil then
				r = f.rng:NextInteger(0, 3) * 90 - 90
			end
			for _ = 1, 6 do
				if f:at(name, x0 + f.rng:NextNumber() * (x1 - x0), d0 + f.rng:NextNumber() * (d1 - d0), r, { quiet = true }) then
					placed += 1
					break
				end
			end
		end
		return placed
	end
	-- a chair on the front side of each desk, facing it
	local function chairs(f, desks)
		for _, r in desks do
			f:at("Chair", r.x, r.d - 3.4, 180, { quiet = true })
		end
	end

	-- ── NESTA CANTEEN: the food court. Kitchen and serving line along the back wall, tables on a grid, benches and planters ──
	local function canteen(f, u)
		local hw, D = f.hw, f.D
		-- the kitchen: fridges along the back wall, a pantry, the staff's lockers and drawers, delivery crates
		local fr = f:run("Fridge", "B", -hw + 6, hw - 6, nil, { sc = V(1.2, 1, 1), gap = 1.5, limit = 10 })
		adoptSome(f, fr, "cooler", "Fridge", 3)
		f:cont("grocery", "Pantry shelf", -32, D - 17, 0, { quiet = true })
		f:cont("grocery", "Pantry shelf", 32, D - 17, 0, { quiet = true })
		f:contWall("locker", "Staff locker", "R", D - 34, { quiet = true })
		f:contWall("drawer", "Kitchen drawer", "R", D - 41, { quiet = true })
		f:spread("crate", "Food crate", 1, -85, 85, D - 30, D - 24, { ry = 0 })
		-- the serving line in two halves with a gap for the staff, a till at either end, the menu boards over it
		for _, half in { { -80, -14 }, { 10, 80 } } do
			f:run("FoodCounter", "x", half[1], half[2], 0, { inset = D - 30.6, gap = 1, limit = 4 })
		end
		f:cont("register", "Till", -hw + 10, D - 30.6, 0, { prop = "Counter", quiet = true })
		f:cont("register", "Till", hw - 10, D - 30.6, 0, { prop = "Counter", quiet = true })
		f:run("DepartureBoard", "B", -26, 26, nil, { h = 16, gap = 8, over = true, limit = 3 })
		-- the dining hall: tables on a staggered grid, thinned out; planters and benches between and along the walls
		local cols = { -76, -46, -16, 16, 46, 76 }
		local tables = {}
		for j = 0, 4 do
			for i, x in cols do
				if (i + j) % 2 == 1 then
					local rec = f:at("FoodTable", x + (j % 2) * 8, 40 + j * 46, 0, { quiet = true })
					if rec then
						tables[#tables + 1] = rec
					end
				end
			end
		end
		f:run("Planter", "x", -90, 90, 0, { inset = 109, gap = 36, limit = 3 })
		f:run("Planter", "x", -90, 90, 0, { inset = 201, gap = 36, limit = 3 })
		f:run("Bench", "L", 40, 250, nil, { gap = 60, limit = 2 })
		f:run("Bench", "R", 40, 250, nil, { gap = 60, limit = 2 })
		-- the front: bins, vending, a cash machine, a coffee kiosk where the queue forms
		f:run("Bin", "x", -92, 92, 0, { inset = 24, gap = 60, limit = 3 })
		f:wall("Vending", "L", 34, { quiet = true })
		f:wall("Vending", "R", 34, { quiet = true })
		f:wall("ATM", "L", 62, { quiet = true })
		f:at("Kiosk", 58, 262, 0, { quiet = true })
		-- loose loot: the tables, the floor round the kitchen and the dining hall
		f:surfaces("grocery", 5, 0.5)
		f:litter(4, "grocery", 0.4)
		f:litter(1, "mall", 0.4)
		f:spot(-hw + 8, D - 8, 0.15, "mallkeys", 0.08)
		-- the shell's lamps hang at the roof, 50 studs up; these hang lower over the dining hall
		f:lamps(3, 4, { x0 = -66, x1 = 66, d0 = 30, d1 = 300, range = 46, bright = 0.9 })
	end

	-- ── NESTA STOCK ROOMS: pallet racking in rows, boxes, cages, a forklift ───────────────────────────────────────────
	local function nestaStock(f, u)
		local hw, D = f.hw, f.D
		f:rows("PalletRack", -hw + 6, hw - 6, 26, 4, 34, 0, { sc = V(2.4, 1, 1), gap = 10 })
		f:spread("crate", "Pallet", 3, -hw + 8, hw - 8, 8, D - 8)
		f:spread("toolbox", "Toolbox", 1, -hw + 8, hw - 8, 8, D - 8)
		f:spread("weaponbox", "Locked crate", 1, -hw + 8, hw - 8, 8, D - 8)
		sprinkle(f, "PalletBoxes", 2, -hw + 8, hw - 8, 8, D - 8)
		sprinkle(f, "CardboardPile", 4, -hw + 8, hw - 8, 8, D - 8)
		f:run("RollCage", "x", -hw + 8, hw - 8, 0, { inset = D - 6, gap = 6, limit = 4 })
		f:at("Forklift", 0, 76, 90, { quiet = true })
		f:contWall("locker", "Staff locker", "B", -hw + 8, { quiet = true })
		f:contWall("drawer", "Goods-in drawer", "B", hw - 12, { quiet = true })
		f:litter(4, "crate", 0.4)
		f:litter(2, "junk", 0.4)
		f:spot(-hw + 14, D - 8, 0.15, "mallkeys", 0.08)
		f:lamps(2, 2, { x0 = -50, x1 = 50, d0 = 30, d1 = D - 30, bright = 0.9 })
	end

	-- ── KASSA BACK OF HOUSE: the cold room, dry stores, staff lockers ─────────────────────────────────────────────────
	local function kassaBack(f, u)
		local hw, D = f.hw, f.D
		local fr = f:run("Fridge", "B", -hw + 4, hw - 4, nil, { sc = V(1.4, 1, 1), gap = 1, limit = 6 })
		adoptSome(f, fr, "cooler", "Cold room fridge", 2)
		f:rows({ "StorageRack", "StorageRack", "StorageRackEmpty" }, -hw + 6, hw - 6, 30, 2, 28, 0, { sc = V(2.6, 1, 1), gap = 8 })
		f:cont("grocery", "Dry goods shelf", -20, D - 24, 0, { quiet = true })
		f:cont("grocery", "Dry goods shelf", 30, D - 24, 0, { quiet = true })
		f:spread("crate", "Pallet", 3, -hw + 8, hw - 8, 8, D - 8)
		f:contWall("locker", "Staff locker", "L", 90, { quiet = true })
		f:contWall("locker", "Staff locker", "L", 93, { quiet = true })
		f:contWall("drawer", "Manager's drawer", "R", 95, { quiet = true })
		f:contWall("drawer", "Delivery drawer", "R", 60, { quiet = true })
		sprinkle(f, "PalletBoxes", 2, -hw + 8, hw - 8, 8, D - 8)
		sprinkle(f, "CardboardPile", 2, -hw + 8, hw - 8, 8, D - 8)
		f:run("RollCage", "x", -hw + 8, hw - 8, 0, { inset = D - 16, gap = 8, limit = 2 })
		f:run("TrolleyRow", "x", -hw + 6, hw - 6, 0, { inset = 12, gap = 30, limit = 2 })
		f:run("Bin", "x", -hw + 6, hw - 6, 0, { inset = 66, gap = 50, limit = 2 })
		f:at("Bench", 52, D - 6, 0, { quiet = true })
		f:litter(3, "grocery", 0.4)
		f:litter(1, "junk", 0.4)
		f:spot(hw - 10, D - 6, 0.15, "mallkeys", 0.08)
		f:lamps(2, 2, { x0 = -50, x1 = 50, d0 = 25, d1 = D - 25, bright = 0.9 })
	end

	-- ── BOLTWORKS STOCK BLOCK: racking, tyres, drums, tool chests, and the locked goods-in room (MM_BOLT_GOODS) ─────────────
	-- the goods-in room: crates stacked on the far wall, a tool chest, a safe, the clerk's PC
	local function goodsFill(f, r, side)
		local far = { L = "R", R = "L", F = "B", B = "F" }
		local fs = far[side]
		local a0, a1 = r[2], r[4]
		if fs == "B" or fs == "F" then
			a0, a1 = r[1], r[3]
		end
		f:atSide("crate", "Goods-in pallet", fs, r, a0 + (a1 - a0) * 0.25, { quiet = true })
		f:atSide("crate", "Goods-in pallet", fs, r, a0 + (a1 - a0) * 0.6, { quiet = true })
		f:atSide("safe", "Goods-in safe", fs, r, a0 + (a1 - a0) * 0.88, { quiet = true })
		f:atSide("toolbox", "Tool chest", "B", r, (r[1] + r[3]) / 2, { prop = "ToolChest", quiet = true })
		f:atSide("toolbox", "Tool chest", "F", r, (r[1] + r[3]) / 2 + 4, { prop = "ToolChest", quiet = true })
		local desk = f:cont("techbox", "Goods-in PC", (r[1] + r[3]) / 2 - 2, (r[2] + r[4]) / 2, 0, { prop = "OfficeDesk", quiet = true })
		if desk then
			f:at("Chair", desk.x, desk.d - 3.4, 180, { quiet = true })
			f:top(desk, "mallkeys", 0.15, 1)
			f:top(desk, "office", 0.5, 1)
		end
		f:litter(2, "crate", 0.45)
	end
	local function boltStock(f, u)
		local hw, D = f.hw, f.D
		f:office({
			id = "MM_BOLT_GOODS", key = "KEY_MM_BOLT_GOODS", label = "BOLTWORKS goods-in office", w = 34, l = 28, fill = goodsFill,
			cands = { { hw - 40, D - 62, "L" }, { -hw + 6, D - 62, "R" }, { hw - 40, D - 100, "L" }, { -hw + 6, D - 100, "R" } },
		})
		f:rows("PalletRack", -hw + 5, hw - 5, 30, 4, 32, 0, { sc = V(2, 1, 1), gap = 8 })
		f:run("TyreStack", "d", 150, D - 8, 0, { inset = -hw + 5, gap = 1.5, limit = 4 })
		f:run("TyreStack", "d", 150, D - 8, 0, { inset = hw - 5, gap = 1.5, limit = 2 })
		f:run("Drum", "x", -hw + 8, hw - 8, 0, { inset = 164, gap = 4, limit = 3 })
		f:spread("toolbox", "Tool chest", 2, -hw + 8, hw - 8, 150, D - 8, { prop = "ToolChest" })
		f:spread("crate", "Pallet", 2, -hw + 8, hw - 8, 8, D - 8)
		sprinkle(f, "PalletBoxes", 3, -hw + 8, hw - 8, 8, D - 8)
		sprinkle(f, "CardboardPile", 2, -hw + 8, hw - 8, 8, D - 8)
		sprinkle(f, "JerryCans", 1, -hw + 8, hw - 8, 150, D - 8)
		f:run("RollCage", "x", -hw + 8, hw - 8, 0, { inset = 150, gap = 10, limit = 2 })
		f:at("Forklift", 0, 142, 0, { quiet = true })
		f:litter(4, "toolbox", 0.4)
		f:litter(2, "junk", 0.4)
		f:spot(-hw + 8, 8, 0.15, "mallkeys", 0.08)
		f:lamps(1, 3, { x0 = -30, x1 = 30, d0 = 30, d1 = D - 30, bright = 0.9 })
	end

	-- ── BOLTWORKS OFFICES: the open-plan office and the manager's office (MM_BOLT_OFFICE) ──────────────────────────────────
	local function boltOffices(f, u)
		local hw, D = f.hw, f.D
		f:office({
			id = "MM_BOLT_OFFICE", key = "KEY_MM_BOLT_OFFICE", label = "BOLTWORKS manager's office", w = 34, l = 28,
			safes = 2, drawers = 3, desk = "Manager's PC", safeLabel = "Office safe", drawerLabel = "Filing drawer", locker = true, keyChance = 0.15,
			cands = { { hw - 40, D - 36, "L" }, { -hw + 6, D - 36, "R" }, { hw - 40, 20, "L" }, { -hw + 6, 20, "R" } },
		})
		local desks = f:rows("OfficeDesk", -hw + 12, 40, 26, 2, 26, 0, { gap = 10, limit = 3 })
		-- a task's quest item (economy-6a): by the first desk of the open-plan office (World moves it to free floor)
		local d1 = desks and desks[1]
		if d1 and d1.cr then
			B.points.MM_BOLT_DESK = f:pos((d1.cr[1] + d1.cr[3]) / 2, 0.05, (d1.cr[2] + d1.cr[4]) / 2)
		end
		chairs(f, desks)
		adoptSome(f, desks, "techbox", "Office PC", 3)
		f:run("Pigeonholes", "B", -hw + 12, 40, nil, { gap = 4, limit = 3, over = true })
		f:run("CorkBoard", "L", 56, D - 8, nil, { h = 3, limit = 2, gap = 10, over = true })
		f:run("Whiteboard", "R", 8, 50, nil, { h = 2.5, limit = 1, over = true })
		f:scatter("locker", "Staff locker", 2, { sides = { "B", "L" }, d0 = 20 })
		f:scatter("drawer", "Filing drawer", 1, { sides = { "B", "R" }, d0 = 20 })
		local tb = f:at("Table", -hw + 40, D - 24, 0, { quiet = true })
		if tb then
			f:at("Chair", tb.x - 3.4, tb.d, -90, { quiet = true })
			f:at("Chair", tb.x + 3.4, tb.d, 90, { quiet = true })
			f:at("Chair", tb.x, tb.d - 3.2, 180, { quiet = true })
		end
		f:wall("Vending", "L", 12, { quiet = true })
		f:run("Bin", "x", -hw + 6, hw - 6, 0, { inset = 12, gap = 60, limit = 2 })
		f:run("Planter", "x", -hw + 6, hw - 6, 0, { inset = 12, gap = 70, limit = 2 })
		f:surfaces("office", 4, 0.5)
		f:litter(3, "office", 0.4)
		f:spot(hw - 10, D - 8, 0.15, "mallkeys", 0.08)
		f:lamps(2, 1, { x0 = -hw + 20, x1 = 30, d0 = 20, d1 = 70, bright = 0.9 })
	end

	build("L1_idea_bistro", canteen)
	build("BACK_1", nestaStock)
	build("BACK_2", kassaBack)
	build("BACK_3", boltStock)
	build("BACK_4", boltOffices)
end
