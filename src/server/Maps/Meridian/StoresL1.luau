--!nonstrict
-- Meridian Mall main floor (L1) stores: every unit of the first floor furnished for its kind, with the sign names, doors, keys,
-- containers and loose loot (docs/maps/MERIDIAN_MALL.md, Part 4a). This module does the shops, IRONSIGHT (front door, inner grate,
-- weapon room), RESCUE POINT (three keyed doors), the security room, the stock rooms behind the deep shops and the closed shop;
-- StoresL1Halls.luau does the three anchors (NESTA, KASSA, BOLTWORKS), the canteen and the back-of-house blocks. Both build with
-- StoresL1Kit.luau (frames, props by footprint, containers, doors, lamps). Each unit builds under its own pcall.
-- Budget: props are kit props (instanced meshes), scaled up for long runs; own parts only where the kit has no piece.
return function(B)
	local T = require(script.Parent.StoresL1Kit)(B)
	local kit, W, M = B.kit, B.W, B.kit.M
	local O = B.O
	local V = Vector3.new
	local PAL, n = T.PAL, T.n
	local t0 = os.clock()
	local units = B.units

	-- ── names: original, short, nothing a real brand or the reference's own names ──────────────────────────────
	-- r: the recipe; cap: props at most (default from the floor area); the others tune a recipe
	local SHOPS = {
		L1_nortex = { name = "WOOLHOUSE", r = "clothing" },
		L1_trend = { name = "CUTLINE", r = "clothing" },
		L1_mode7 = { name = "ATELIER 9", r = "clothing" },
		L1_dino_clothes = { name = "PIPKINS", r = "clothing", wsc = 1.5 },
		L1_kostin = { name = "TAILORED", r = "clothing" },
		L1_bizarro = { name = "MOTLEY", r = "clothing" },
		L1_the_national = { name = "HARTWELL", r = "clothing" },
		L1_brutal = { name = "IRONSTITCH", r = "clothing" },
		L1_top_brand = { name = "HIGHLINE", r = "clothing" },
		L1_yushka = { name = "SABLE", r = "clothing" },
		L1_tts = { name = "BYTEBAY", r = "electronics" },
		L1_mantis = { name = "MICROMART", r = "electronics" },
		L1_telespot = { name = "PIXELPOINT", r = "electronics" },
		L1_rasmussen = { name = "GADGETRY", r = "electronics" },
		L1_texho = { name = "PLUGGED IN", r = "electronics" },
		L1_viking = { name = "PEAKFORM", r = "sports" },
		L1_adik = { name = "SPRINTLINE", r = "sports" },
		L1_sports = { name = "FIELD & TRACK", r = "sports" },
		L1_book_store = { name = "INKWELL", r = "books" },
		L1_spiel = { name = "TOYBOX", r = "toys" },
		L1_boots_4_life = { name = "SOLE TRADE", r = "shoes" },
		L1_dom = { name = "HOMESTEAD", r = "homeware" },
		L1_pretty_lights = { name = "BRIGHTSIDE", r = "lighting" },
		L1_voyage = { name = "WAYFARE", r = "travel" },
		L1_avokado = { name = "GREENPLATE", r = "food" },
		L1_german = { name = "CORNER MART", r = "general" },
		L1_generic = { name = "VARIETY", r = "general" },
		L1_revis = { name = "DAILY NEEDS", r = "general" },
		L1_unlabelled_store_n_of_viking = { name = "TO LET", r = "closed" },
	}

	-- ── recipes: the props of a kind of shop ──────────────────────────────────────────────────────────────────
	-- wall: the unit along the walls (wsc: how much longer), island: props in rows across the floor (isc: longer), igap: space
	-- between them, desk: the cash desk prop, cont: containers { kind, label, count } against the walls, pool: loose loot
	local RECIPES = {
		clothing = {
			wall = "WallShelf", wsc = 2, island = { "ClothesRack", "DisplayTable", "ClothesRack" }, isc = 1.4, igap = 3.5,
			desk = "Counter", cont = { { "jacket", "Coat rack", 1 } }, pool = "mall", tops = "mall", litter = "mall",
			front = { { "Mannequin", 3 } },
		},
		electronics = {
			wall = "TVWall", wsc = 2, island = { "TechTable" }, isc = 1.6, igap = 4, desk = "Counter",
			cont = { { "techbox", "Electronics shelf", 1 } }, pool = "tech", tops = "tech", litter = "tech", front = { { "Vending", 1 } },
		},
		sports = {
			wall = "WallShelf", wsc = 2, island = { "WeightRack", "ClothesRack", "DisplayTable" }, isc = 1.5, igap = 4, desk = "Counter",
			cont = { { "toolbox", "Equipment box", 1 } }, pool = "mall", tops = "mall", litter = "junk",
			front = { { "Bin", 1 } },
		},
		books = {
			wall = "WallShelfBooks", wsc = 2, island = { "Gondola" }, isc = 1.8, igap = 3, desk = "Counter",
			cont = { { "drawer", "Desk drawer", 1 } }, pool = "office", tops = "office", litter = "office", front = { { "Bench", 1 } },
		},
		toys = {
			wall = "WallShelf", wsc = 2, island = { "DisplayTable", "Gondola" }, isc = 1.5, igap = 3.5, desk = "Counter",
			cont = { { "toolbox", "Toy box", 1 } }, pool = "mall", tops = "mall", litter = "mall", front = { { "Arcade", 1 }, { "Planter", 1 } },
		},
		shoes = {
			wall = "WallShelf", wsc = 2, island = { "Bench", "DisplayTable" }, isc = 1.5, igap = 4, desk = "Counter",
			cont = { { "locker", "Staff locker", 1 } }, pool = "mall", tops = "mall", litter = "mall", front = { { "Chair", 2 } },
		},
		homeware = {
			wall = "WallShelf", wsc = 2, island = { "Sofa", "Table", "Bed", "Table", "Sofa" }, isc = 1, igap = 5, desk = "Counter",
			cont = { { "drawer", "Chest of drawers", 1 }, { "locker", "Wardrobe", 1 } }, pool = "mall", tops = "mall", litter = "junk",
			front = { { "Planter", 2 } },
		},
		lighting = {
			wall = "WallShelf", wsc = 2, island = { "DisplayTable" }, isc = 1.5, igap = 5, desk = "Counter",
			cont = { { "drawer", "Counter drawer", 1 } }, pool = "tech", tops = "tech", litter = "tech", front = { { "Planter", 1 } },
		},
		travel = {
			wall = "CorkBoard", wsc = 1, island = { "Table", "Chair" }, isc = 1, igap = 5, desk = "Counter",
			cont = { { "jacket", "Coat stand", 1 } }, pool = "office", tops = "office", litter = "office",
			front = { { "Bench", 1 } },
		},
		general = {
			wall = "WallShelf", wsc = 2, island = { "Gondola" }, isc = 1.8, igap = 3, desk = "Checkout",
			cont = { { "grocery", "Shelf", 1 } }, pool = "grocery", tops = "grocery", litter = "mall",
			front = { { "Trolley", 1 }, { "Bin", 1 } },
		},
		food = {
			wall = "WallShelf", wsc = 2, island = { "FoodTable" }, isc = 1, igap = 5, desk = "Counter",
			cont = { { "cooler", "Fridge", 1 } }, pool = "grocery", tops = "drinks", litter = "grocery", front = { { "Bin", 1 } },
		},
	}

	-- ── common pieces ──────────────────────────────────────────────────────────────────────────────────────
	local function sc(x)
		return V(x or 1, 1, 1)
	end
	local function area(f)
		return f.W * f.D
	end
	-- the cash desk: a counter or till against a side wall near the front, with the register on it
	local function desk(f, s, rc)
		local prop = s.desk or rc.desk
		if not prop then
			return nil
		end
		local asReg = s.reg == true or f.rng:NextNumber() < 0.5
		local order = (f.rng:NextNumber() < 0.5) and { "L", "R", "B" } or { "R", "L", "B" }
		for _, side in order do
			local alongs = { 16, 24, 10, 32 }
			if side == "B" then
				alongs = { -f.hw * 0.5, f.hw * 0.5, 0 }
			end
			for _, a in alongs do
				if side == "B" or f.D >= a + 8 then
					local rec = nil
					if asReg then
						rec = f:contWall("register", "Cash register", side, a, { prop = prop, quiet = true })
					else
						rec = f:wall(prop, side, a, { quiet = true })
					end
					if rec then
						return rec
					end
				end
			end
		end
		return nil
	end
	-- island rows across the middle of the floor, until the unit's prop cap is reached
	local function islands(f, s, rc, wd)
		local list = rc.island
		if not list then
			return
		end
		local x0, x1 = -f.hw + 2, f.hw - 2
		if f.D >= 30 then
			x0, x1 = x0 + 7, x1 - 7
		end
		local d = 10
		local k = 0
		while f.cnt.props < s.cap and d < f.D - wd - 6 do
			local name = list[k % #list + 1]
			local isc = rc.isc
			local fp = T.footprint(name, 0, sc(isc))
			if fp then
				local depth = fp.hz * 2
				if d + depth > f.D - wd - 6 then
					break
				end
				f:run(name, "x", x0, x1, 0, { inset = d + depth / 2, sc = sc(isc), gap = rc.igap, limit = s.cap - f.cnt.props })
				d += depth + 6.5
			else
				break
			end
			k += 1
		end
	end
	-- loose loot: on the counters and tables, and on the floor beside things
	local function loot(f, rc, s)
		local area0 = area(f)
		local spots = math.clamp(math.floor(area0 / 1800), 1, 3)
		f:surfaces(rc.tops or "mall", math.min(2, spots), 0.45)
		f:litter(spots, rc.litter or "mall", 0.4)
	end
	-- the shell lights the three halls; a shop gets a lamp per 70 studs of its length and width (range 40 reaches the floor from the ceiling)
	local function lights(f)
		local nx = math.clamp(math.ceil((f.W - 14) / 70), 1, 3)
		local nd = math.clamp(math.ceil((f.D - 14) / 70), 1, 3)
		f:lamps(nx, nd, {})
	end

	-- the furnishing pass of the small shops (StoresFill.luau): a fitting room, wall units, posters, floor fixtures and litter, added
	-- after the recipe within a fixed part budget. It takes floor space in the frame like any prop and moves nothing the recipe placed;
	-- a pass that is missing or fails leaves the shop as the recipe made it.
	local Fill = nil
	local fillMod = script.Parent:FindFirstChild("StoresFill")
	if fillMod then
		local okFill, resFill = pcall(function()
			return require(fillMod)(B)
		end)
		if okFill then
			Fill = resFill
		else
			warn("[ZR] Meridian stores L1: StoresFill did not load: " .. tostring(resFill))
		end
	end
	local function fill(f, u, kind)
		if not Fill then
			return
		end
		Fill.shop({
			id = f.id, level = 1, cf = f.cf, W = f.W, D = f.D, ceil = f.ceil, kind = kind, u = u,
			rects = function()
				local out = {}
				for _, r in f.occ do
					out[#out + 1] = { r[1], r[2], r[3], r[4] }
				end
				return out
			end,
			take = function(x0, d0, x1, d1)
				f:reserve(x0, d0, x1, d1)
			end,
		})
	end

	-- a shop: containers first (they need their wall spots), the cash desk, the wall units, the island rows, a few front props
	local function shop(f, u, s)
		local rc = RECIPES[s.r]
		s.cap = s.cap or math.clamp(math.floor(area(f) / 360), 5, 20)
		for _, c in rc.cont or {} do
			f:scatter(c[1], c[2], c[3], { x0 = -f.hw + 6, x1 = f.hw - 6, d0 = 14, d1 = f.D - 6 })
		end
		desk(f, s, rc)
		local wsc = s.wsc or rc.wsc
		local wall = { sc = sc(wsc) }
		local wd = 2.2
		f:run(rc.wall, "B", -f.hw + 0.5, f.hw - 0.5, nil, wall)
		if f.D >= 30 then
			f:run(rc.wall, "L", 5, f.D - 3, nil, wall)
			f:run(rc.wall, "R", 5, f.D - 3, nil, wall)
		end
		islands(f, s, rc, wd)
		-- props near the front, to the sides of the entrance
		for _, fr in rc.front or {} do
			local placed = 0
			for _, side in { "L", "R" } do
				if placed < fr[2] then
					local rec = f:wall(fr[1], side, 6, { quiet = true })
					if rec then
						placed += 1
					end
				end
			end
		end
		loot(f, rc, s)
		lights(f)
		fill(f, u, s.r)
	end

	-- ── the stock room behind a deep shop: racks on the back wall, a container, a little loot ───────────────────────
	local function stockRoom(u, kind, label, pool)
		local st = u.stock
		if not st then
			return
		end
		local f = T.frame(u, { cframe = st.cframe, size = st.size, id = u.id .. "_stock" })
		if kind and f.W >= 40 then
			f:scatter(kind, label, 1, { sides = { "B" } })
		end
		local span = 3 * 16.5
		local a0 = -f.hw + 1 + f.rng:NextNumber() * math.max(0, f.W - span - 2)
		f:run({ "StorageRack", "StorageRack", "StorageRackEmpty" }, "B", a0, a0 + span, nil, { sc = V(2, 1, 1) })
		f:litter(1, pool or "mall", 0.45)
		f:lamp(0, f.D / 2, { long = 4 })
		return f
	end
	local STOCK = {
		clothing = { "locker", "Staff locker", "mall" }, electronics = { "techbox", "Spare stock", "tech" },
		sports = { "toolbox", "Equipment box", "mall" }, books = { "drawer", "Stock drawer", "office" },
		toys = { "toolbox", "Toy box", "mall" }, shoes = { "locker", "Staff locker", "mall" }, homeware = { "drawer", "Stock drawer", "junk" },
		lighting = { "toolbox", "Spares box", "tech" }, travel = { "drawer", "Stock drawer", "office" }, general = { "toolbox", "Stock box", "grocery" },
		food = { "locker", "Staff locker", "grocery" }, closed = { "toolbox", "Old toolbox", "junk" },
	}

	-- ── a closed shop: shelves down, cartons, rubble ────────────────────────────────────────────────────────────
	local function closed(f, u, s)
		f:scatter("toolbox", "Old toolbox", 1, { sides = { "B" } })
		f:scatter("drawer", "Counter drawer", 1, { sides = { "B", "L", "R" } })
		f:run("GondolaSparse", "B", -f.hw + 4, f.hw - 4, nil, { sc = V(1.3, 1, 1), gap = 6, limit = 4 })
		f:run("WallShelfSparse", "L", 8, f.D - 6, nil, { limit = 3, gap = 5 })
		for i = 1, 3 do
			f:at("GondolaToppled", -f.hw * 0.6 + i * f.hw * 0.35, 14 + f.rng:NextNumber() * (f.D - 34), 0, { quiet = true })
		end
		for _ = 1, 8 do
			f:at("CardboardPile", f.rng:NextNumber(-f.hw + 6, f.hw - 6), f.rng:NextNumber(10, f.D - 6), f.rng:NextInteger(0, 3) * 90 - 90, { quiet = true })
		end
		for _ = 1, 3 do
			f:at("PalletBoxes", f.rng:NextNumber(-f.hw + 6, f.hw - 6), f.rng:NextNumber(14, f.D - 6), 0, { quiet = true })
		end
		f:litter(4, "junk", 0.45)
		lights(f)
	end

	-- ── the doors that need their opening narrowed: a leaf, fixed panels beside and a header above ──────────────────
	-- e: an entrance of the unit (world position, width), frame f the door belongs to; the leaf stands in the wall's middle
	local function openingOf(f, e)
		local ex, ed = f:local2(e.pos.X - O.X, e.pos.Z - O.Z)
		local side, plane
		if ed < 3 then
			side, plane = "F", ed + 0.6
		elseif ed > f.D - 3 then
			side, plane = "B", ed - 0.6
		elseif ex < 0 then
			side, plane = "L", ex + 0.6
		else
			side, plane = "R", ex - 0.6
		end
		return side, plane, (side == "F" or side == "B") and ex or ed
	end
	-- a locked entrance: a leaf of `lw` (up to the opening) in the opening's middle, fixed grille panels either side, a header
	-- over it all; the leaf swings into the unit. The opening is 13.5 high; the leaf 9.
	local function lockedDoor(f, e, id, label, key, lw, col)
		local side, plane, c = openingOf(f, e)
		local w = e.width
		local ln = math.min(lw or 7.2, w)
		local swing = { F = "B", B = "F", L = "R", R = "L" }
		f:door(id, label, (side == "F" or side == "B") and c or plane, (side == "F" or side == "B") and plane or c, swing[side], ln, 9, key, { color = col })
		local gl = (w - ln) / 2
		local function panel(a0, a1, h0, h1)
			if a1 - a0 < 0.05 then
				return
			end
			if side == "F" or side == "B" then
				f:box(a0, plane - 0.2, a1, plane + 0.2, h0, h1, PAL.bars, M.Metal, { name = "Grille", occupy = false })
			else
				f:box(plane - 0.2, a0, plane + 0.2, a1, h0, h1, PAL.bars, M.Metal, { name = "Grille", occupy = false })
			end
		end
		panel(c - w / 2, c - ln / 2, 0, 9)
		panel(c + ln / 2, c + w / 2, 0, 9)
		panel(c - w / 2, c + w / 2, 9, 13.5)
		return gl
	end

	-- ── IRONSIGHT: the front door, the counter, the inner grate, the weapon room ─────────────────────────────────────
	local function ironsight(f, u)
		local e = u.entrances[1]
		local ex = f:local2(e.pos.X - O.X, e.pos.Z - O.Z)
		-- front door (electric: KEY_MM_IRON_FRONT)
		lockedDoor(f, e, "MM_IRON_FRONT", "IRONSIGHT front door", "KEY_MM_IRON_FRONT", 7.2, PAL.bars)
		-- the inner grate across the shop, a gate in it near the stock door (electric: KEY_MM_IRON_GRATE)
		local dg = 11.6
		local gx = 14
		f:box(-f.hw, dg - 0.3, gx - 3, dg + 0.3, 0, 2.6, PAL.bars, M.Metal, { name = "GrateBase" })
		f:box(gx + 3, dg - 0.3, f.hw, dg + 0.3, 0, 2.6, PAL.bars, M.Metal, { name = "GrateBase" })
		for _, seg in { { -f.hw, gx - 3 }, { gx + 3, f.hw } } do
			local g = f:box(seg[1], dg - 0.15, seg[2], dg + 0.15, 2.6, 13.5, PAL.bars, M.Metal, { name = "Grate" })
			if g then
				g.Transparency = 0.55
				g.CanQuery = false
			end
		end
		f:box(gx - 3, dg - 0.3, gx + 3, dg + 0.3, 9.4, 13.5, PAL.bars, M.Metal, { name = "GrateHeader", occupy = false })
		f:door("MM_IRON_GRATE", "IRONSIGHT inner grate", gx, dg, "B", 6, 9.4, "KEY_MM_IRON_GRATE", { color = PAL.bars })
		-- the weapon room first (containers need their spots): the weapon boxes, a safe, a clerk's drawer
		f:cont("weaponbox", "Weapon box", -f.hw + 3.2, f.D - 3.2, 0, { prop = "AmmoCrate" })
		f:cont("weaponbox", "Weapon box", -26, f.D - 1.4, 0, { prop = "AmmoCrate" })
		f:cont("weaponbox", "Weapon box", 27, f.D - 1.4, 0, { prop = "AmmoCrate" })
		f:cont("safe", "Gun shop safe", f.hw - 3.2, f.D - 8, -90)
		f:cont("drawer", "Clerk's drawer", -2, f.D - 1.6, 0)
		local bench = f:at("GunBench", -24, dg + 2.2, 0, { quiet = true })
		f:at("GunBench", 30, dg + 2.2, 0, { quiet = true })
		-- guns on the walls (they take no floor space)
		f:run("GunRack", "B", -f.hw + 1, f.hw - 1, nil, { h = 1.5, free = true })
		f:run("GunRack", "L", dg + 2, f.D - 1, nil, { h = 1.5, free = true })
		f:run("GunRack", "R", dg + 2, f.D - 1, nil, { h = 1.5, free = true })
		-- in front of the grate: the sales counters, a bench and the displays
		f:cont("register", "Cash register", -15, dg - 2.2, 0, { prop = "Counter" })
		f:at("Counter", -31, dg - 2.2, 0, { quiet = true })
		f:at("Counter", 27, dg - 2.2, 0, { quiet = true })
		f:at("DisplayTable", -f.hw + 8, 5, 0, { quiet = true })
		f:at("DisplayTable", f.hw - 8, 5, 0, { quiet = true })
		f:at("Bench", ex + 14, 4, 0, { quiet = true })
		f:run("RangeDisplay", "F", -f.hw + 3, f.hw - 3, nil, { gap = 14, h = 4, free = true })
		if bench then
			f:top(bench, "weaponbox", 0.5, 2)
		end
		f:surfaces("weaponbox", 2, 0.5)
		f:spot(-f.hw + 6, f.D - 4, 0.15, "mallkeys", 0.1)
		f:lamps(2, 1, { d0 = 3, d1 = dg - 1 })
		f:lamp(0, (dg + f.D) / 2, {})
	end

	-- ── RESCUE POINT: three keyed doors, a medical shop ───────────────────────────────────────────────────────────
	local function rescue(f, u)
		local key = "KEY_MM_RESCUE"
		local ids = { E = "MM_RESCUE_E", N = "MM_RESCUE_N", W = "MM_RESCUE_W" }
		local labels = { E = "RESCUE POINT front door", N = "RESCUE POINT north door", W = "RESCUE POINT west door" }
		local lens = { E = 6.5, N = 7.4, W = 4.2 }
		local fs = nil
		if u.stock then
			fs = T.frame(u, { cframe = u.stock.cframe, size = u.stock.size, id = u.id .. "_stock" })
		end
		for _, e in u.entrances do
			local fr = f
			if e.side == "W" and fs then
				fr = fs
			end
			local id = ids[e.side]
			if id then
				lockedDoor(fr, e, id, labels[e.side], key, lens[e.side])
			end
		end
		-- the shop: medicine shelves on the walls, a column of shelf islands, cots, a counter
		f:cont("pharmacy", "Medicine shelf", 0, 47, 0, { prop = "MedShelf" })
		f:cont("pharmacy", "Medicine shelf", 0, 35.5, 0, { prop = "MedShelf", quiet = true })
		f:cont("pharmacy", "Medicine shelf", 0, 24, 0, { prop = "MedShelf", quiet = true })
		f:contWall("pharmacy", "Pharmacy cabinet", "R", 14, { prop = "WallShelfMeds", quiet = true })
		f:scatter("medbag", "Medical bag", 3, { sides = { "B", "L", "R" }, d0 = 14 })
		f:cont("drawer", "Nurse's drawer", -f.hw + 3.5, 18, -90, { quiet = true })
		f:cont("safe", "Pharmacy safe", f.hw - 3.5, f.D - 4, 90, { quiet = true })
		f:run("WallShelfMeds", "B", -f.hw + 0.5, f.hw - 0.5, nil, {})
		f:run("WallShelfMeds", "L", 8, f.D - 3, nil, { limit = 3 })
		f:run("WallShelfMeds", "R", 8, f.D - 3, nil, { limit = 3 })
		desk(f, { cap = 99, reg = true }, { desk = "Counter" })
		f:wall("MedCot", "R", 14, { quiet = true })
		f:run("FirstAid", "L", 14, f.D - 4, nil, { h = 4.2, gap = 14, limit = 2, free = true })
		f:surfaces("pharmacy", 2, 0.5)
		f:litter(3, "medbag", 0.45)
		lights(f)
		if fs then
			fs:scatter("medbag", "Medical bag", 1, { sides = { "B" } })
			fs:run("StorageRack", "B", -fs.hw + 1, fs.hw - 1, nil, { sc = V(2, 1, 1), limit = 3 })
			fs:spot(-fs.hw + 8, fs.D - 3, 0.15, "mallkeys", 0.1)
			fs:lamp(0, fs.D / 2, { long = 4 })
		end
	end

	-- ── the security room: the shell has the desk and the monitor; lockers, a safe and the staff's things ────────────
	local function security(f, u)
		local tp = B.points.SECURITY_TERMINAL
		if tp then
			local tx, td = f:local2(tp.X - O.X, tp.Z - O.Z)
			f:reserve(tx - 4, td - 3.5, tx + 4, td + 3.5)
		end
		f:scatter("locker", "Guard locker", 2, { sides = { "B", "L", "R" }, d0 = 4 })
		f:scatter("safe", "Security safe", 1, { sides = { "B", "R", "L" } })
		f:at("Bench", 0, f.D - 3, 0, { quiet = true })
		f:at("Chair", 4, f.D - 9, 90, { quiet = true })
		f:litter(2, "office", 0.45)
		f:spot(2, f.D - 4, 3.4, "mallkeys", 0.1)
		f:lamp(0, f.D / 2, {})
	end

	-- ── build everything under pcall ────────────────────────────────────────────────────────────────────────────────
	local function build(id, fn)
		local u = units[id]
		if not u or not u.cframe then
			warn("[ZR] Meridian stores L1: no unit " .. id)
			return
		end
		local ok, err = pcall(function()
			local f = T.frame(u)
			fn(f, u)
			return f
		end)
		if not ok then
			warn("[ZR] Meridian stores L1: " .. id .. " failed: " .. tostring(err))
		end
	end
	-- names first, then the shops, the stock rooms behind them
	for id, s in SHOPS do
		local u = units[id]
		if u and s.name then
			T.name(u, s.name)
		end
	end
	for id, s in SHOPS do
		build(id, function(f, u)
			if s.r == "closed" then
				closed(f, u, s)
			else
				shop(f, u, s)
			end
		end)
		local u = units[id]
		if u and u.stock then
			local st = STOCK[s.r]
			local ok, err = pcall(stockRoom, u, st and st[1], st and st[2], st and st[3])
			if not ok then
				warn("[ZR] Meridian stores L1: " .. id .. " stock room failed: " .. tostring(err))
			end
		end
	end
	build("L1_kiba", ironsight)
	build("L1_emercom", rescue)
	build("SECURITY_ROOM", security)
	local u = units.L1_kiba
	if u and u.stock then
		pcall(stockRoom, u, "weaponbox", "Weapon box", "weaponbox")
	end

	-- the anchors (Halls), then the canteen and the back-of-house blocks (Back)
	for _, name in { "StoresL1Halls", "StoresL1Back" } do
		local mod = script.Parent:FindFirstChild(name)
		if mod then
			local ok, err = pcall(function()
				require(mod)(B, T)
			end)
			if not ok then
				warn("[ZR] Meridian stores L1: " .. name .. " failed: " .. tostring(err))
			end
		end
	end

	-- ── the key tiles of L.keys on this floor (the register keys: NESTA, KASSA, the west offices of BOLTWORKS) ─────
	-- The world rolls a whole pool at a loose spot (there is no single-item spot), so each tile holds a roll of the mall key pool;
	-- the exact key is a logged gap. The tile moves to the nearest free patch of the smallest furnished frame within 9 studs.
	-- { key id, loose pool }: a pool holding only that key would put the exact key on its tile
	local KEYTILES = {
		{ "KEY_MM_NESTA_REG", "mk_nesta_reg" }, { "KEY_MM_KASSA_REG", "mk_kassa_reg" }, { "KEY_MM_BOLT_REG", "mk_bolt_reg" },
		{ "KEY_MM_BOLT_OFFICE", "mk_bolt_office" }, { "KEY_MM_BOLT_GOODS", "mk_bolt_goods" },
	}
	local function keyTiles()
		local at = {}
		for _, k in (B.L and B.L.keys) or {} do
			at[k.id] = k
		end
		local put, lost = 0, {}
		for _, kt in KEYTILES do
			local id = kt[1]
			local k = at[id]
			local best, bl, bd, bscore = nil, 0, 0, 1e9
			if k and k.x and k.z then
				for _, f in T.frames do
					local lx, ld = f:local2(k.x, k.z)
					local ox = math.max(-f.hw - lx, 0, lx - f.hw)
					local od = math.max(0 - ld, 0, ld - f.D)
					local dist = math.sqrt(ox * ox + od * od)
					local score = dist * 100000 + f.W * f.D
					if dist <= 9 and score < bscore then
						best, bl, bd, bscore = f, lx, ld, score
					end
				end
			end
			local done = false
			if best then
				local cx = math.clamp(bl, -best.hw + 4, best.hw - 4)
				local cd = math.clamp(bd, 4, best.D - 4)
				for ring = 0, 4 do
					local steps = ring == 0 and 1 or 8
					for s = 1, steps do
						if not done then
							local a = (s - 1) / steps * math.pi * 2
							local x, d = cx + math.cos(a) * ring * 2.5, cd + math.sin(a) * ring * 2.5
							if best:free(x - 0.9, d - 0.9, x + 0.9, d + 0.9) then
								best:spot(x, d, 0.25, kt[2], 0.35)
								best:reserve(x - 1.2, d - 1.2, x + 1.2, d + 1.2)
								done = true
								put += 1
							end
						end
					end
				end
			end
			if not done then
				lost[#lost + 1] = id
			end
		end
		print(string.format("[ZR] Meridian stores L1: %d key tiles marked%s", put, #lost > 0 and (", no room for " .. table.concat(lost, ", ")) or ""))
	end
	local okKeys, errKeys = pcall(keyTiles)
	if not okKeys then
		warn("[ZR] Meridian stores L1: key tiles failed: " .. tostring(errKeys))
	end

	for _, r in T.rejects do
		warn("[ZR] Meridian stores L1: no room for " .. r)
	end
	local kinds = {}
	for k, c in T.byKind do
		kinds[#kinds + 1] = k .. " " .. c
	end
	table.sort(kinds)
	print(string.format("[ZR] Meridian stores L1: %s, %.2fs", T.report(), os.clock() - t0))
	if Fill then
		print("[ZR] Meridian small shops L1: " .. Fill.report(1))
	end
	print("[ZR] Meridian stores L1 containers: " .. table.concat(kinds, ", "))
	B.count = B.count or {}
	B.count.storesL1 = n.parts
	B.count.storesL1Props = n.props
	return T
end
