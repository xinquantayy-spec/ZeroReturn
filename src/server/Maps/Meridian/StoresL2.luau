--!nonstrict
-- Meridian Mall stores, upper floor and the car-park rooms (stores agent 2, "Part 4b" of docs/maps/MERIDIAN_MALL.md). Furnishes every
-- L2 unit the shell published in B.units for its kind (restaurants with kitchens and seating, shops, the pharmacies, MEDIQ and its locked
-- store room, VOLTA and its stock room, the furniture store, the museum, the half-built units), the stock rooms behind them, and the
-- insides of THE SHELTER and UNIT 14 on L0. Names the units (u.name and the text of the sign), puts the keys on their doors and
-- registers containers, loose loot spots and a few lamps that follow the power (B.powerHooks, dead at build).
-- Everything is placed in each room's own frame (x across the front, d = depth from the front wall) with kit props from the Blender
-- kit; a prop that would overlap another, a wall, an entrance or a stock door is not placed (counted in the summary line).
-- Counts: B.count.prop (kit props), container, door, light. One summary line is printed at the end.
return function(B)
	local kit, W, L, O, Kit, map = B.kit, B.W, B.L, B.O, B.Kit, B.map
	local C, M, hex = kit.C, kit.M, kit.hex
	local V3 = Vector3.new
	local rad = math.rad
	local t0 = os.clock()
	local count = B.count or {}
	B.count = count
	for _, key in { "prop", "door", "light", "container" } do
		count[key] = count[key] or 0
	end
	B.powerHooks = B.powerHooks or {}
	local rng = Random.new(4412)

	-- budgets: this module stays under 3,000 parts (kit pieces and colliders counted) and 700 kit props
	local LIMIT = { parts = 2960, props = 690 }
	local n = {
		props = 0, kparts = 0, parts = 0, containers = 0, loose = 0, doors = 0, keyed = 0, lights = 0, rejected = 0, cut = 0, rooms = 0, byRoom = {},
	}
	local REJECTS = {}
	-- the build hands the thread back now and then (a script that never yields can hit the engine's timeout on a slow server);
	-- called before a part or a prop is made, never between making it and setting it up
	local lastPace = os.clock()
	local function pace()
		if task and os.clock() - lastPace > 0.04 then
			task.wait()
			lastPace = os.clock()
		end
	end

	-- pieces per kit prop, for the part budget: KitMeta's own count when it can be read, else this table
	local okMeta, KitMeta = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("ZR"):WaitForChild("KitMeta"))
	end)
	local PIECES = {
		AmmoCrate = 3, ArmorStand = 3, Arcade = 2, Bed = 2, Bench = 2, Bin = 2, BunkBed = 3, Chair = 2, Checkout = 4, ClothesRack = 2,
		CorkBoard = 3, Counter = 6, CraftBench = 4, DepartureBoard = 3, DisplayTable = 2, Drum = 2, ElectricCabinet = 2, Extinguisher = 4,
		FirstAid = 2, FoodCounter = 3, FoodTable = 3, Fridge = 4, FuseBox = 4, Gondola = 3, GondolaSparse = 3, GunRack = 2, HideoutGenerator = 4,
		Hoarding = 2, JerryCans = 2, JewelCase = 4, Locker = 2, Lockers = 2, MapTable = 5, Mannequin = 3, MedCot = 4, MedShelf = 4,
		OfficeDesk = 4, PalletBoxes = 2, Pegboard = 3, Planter = 4, RigStand = 3, RollCage = 3, RubbleA = 2, RubbleB = 2, Sandbags = 1,
		SandbagsLow = 1, Sofa = 2, StorageRack = 4, StorageRackEmpty = 3, StorageShelf = 2, StorageShelfEmpty = 2, Table = 3, TechTable = 3,
		TVWall = 3, ToolChest = 2, Treadmill = 3, TyreStack = 1, Vending = 4, WallClock = 3, WallShelf = 3, WallShelfBooks = 3,
		WallShelfMeds = 3, WallShelfSparse = 3, WallShelfTools = 3, WaterTank = 4, WeightRack = 2, Whiteboard = 2, WorkLight = 3,
		CardboardPile = 1, Beam = 2, Whiteboard2 = 2, CinemaRow = 3, Trolley = 3, Bed2 = 2, Generator = 3, CCTVDesk = 3, WallPhone = 3,
		MirrorSink = 4, ATM = 2, Fluoro = 2, CageLamp = 3, Speaker = 2, PaperTarget = 2, InsuranceWindow = 4, GunBench = 6,
	}

	local function piecesOf(name)
		local p = okMeta and KitMeta and KitMeta.props and KitMeta.props[name]
		if p and p.pieces then
			return #p.pieces
		end
		return PIECES[name] or 3
	end

	-- colliders of props whose bounding box is much taller than the thing you stand at (a menu board over a counter, a lane light
	-- over a checkout, the posts of a bunk bed): prop space, { size, centre }, so loose items can lie on the counters
	local function bx(sx, sy, sz, x, y, z)
		return { V3(sx, sy, sz), V3(x, y, z) }
	end
	local COLL2 = {
		FoodCounter = { bx(12, 3.7, 4.2, 0, 1.85, 1.9), bx(12, 4.8, 0.3, 0, 6.1, 3.9) },
		Checkout = { bx(8.0, 3.1, 2.4, 0, 1.55, 0) },
		Counter = { bx(12, 3.7, 3.0, 0, 1.85, 0) },
		BunkBed = { bx(6.9, 5.0, 2.9, -0.1, 2.5, 0) },
		BunkBedMessy = { bx(6.9, 5.0, 3.8, -0.1, 2.5, -0.4) },
	}

	-- ── colours (every colour is a defined local or a C / hex value) ────────────────────────────────────
	local COL = {
		white = hex("E4E6E0"), medGreen = hex("56624F"), steel = C.metal, steelDk = C.metalDark, redBox = hex("8A3A2E"), sheet = hex("B9B5A6"),
		sheetDk = hex("A3A092"), case = hex("2F3331"), caseLid = hex("464B49"), cloth = hex("5B5E46"), timber = C.wood, plaster = hex("74766E"),
		counterTop = hex("A9A48F"), brass = hex("A9A48F"), cardboard = hex("A98B62"), floorPaint = hex("C29A38"),
	}
	local LAMP_ON, LAMP_OFF = hex("FFE2B0"), hex("6F6C64")
	local TINT = {
		food = hex("8A5A3A"), clothing = hex("6B4E5E"), electronics = hex("3E5868"), pharmacy = hex("4E7A62"), general = hex("5E6448"),
		furniture = hex("6E5A44"), museum = hex("5A5E7A"), sports = hex("3D5A57"), travel = hex("4A6A7A"), closed = hex("4A4E4C"),
		store = hex("4E7A62"), shelter = hex("5E6448"), unit14 = hex("5C6461"),
	}
	local CONT = { C.olive, C.rust, C.blue, C.red, C.teal, C.yellow, C.rustDark }

	local root = kit.model("StoresL2", map)
	root:SetAttribute("NoWire", true) -- indoors: no barbed wire from the detail plan
	root:SetAttribute("DetailProfile", "clean")

	-- ── the shell's solid parts that stand in the rooms (columns and the like), found once ─────────────
	local shell = {}
	local shellLamps = {} -- where the shell already hangs a lamp (a room with one of those inside needs none of ours)
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide and d.Size.Y > 1.5 then
			local y0, y1 = d.Position.Y - d.Size.Y / 2, d.Position.Y + d.Size.Y / 2
			if (y1 > 1 and y0 < 15) or (y1 > 48.5 and y0 < 62) then
				shell[#shell + 1] = { p = d, x = d.Position.X, z = d.Position.Z, r = (d.Size.X + d.Size.Z) / 2, y0 = y0, y1 = y1 }
			end
		elseif d:IsA("PointLight") then
			local lp = d.Parent
			if lp and lp:IsA("BasePart") then
				shellLamps[#shellLamps + 1] = { p = lp.Position, r = d.Range }
			end
		end
	end

	-- ── frames ────────────────────────────────────────────────────────────────────────────────────────
	-- a room: cf at the middle of its floor looking out through the front, w across, d deep; x right of the middle, d from the
	-- front wall (0) to the back wall (d). Props are placed by the centre of their footprint.
	local Frame = {}
	Frame.__index = Frame
	local YAW = { F = 0, B = 180, L = 90, R = -90 } -- the way a prop's front looks: F toward the front wall, B the back wall, L left, R right
	local TURN = { B = "F", F = "B", L = "R", R = "L" } -- a prop standing against wall X looks this way

	local framesAll = {}
	local function newFrame(parent, stem, cf, size, floorY, tint)
		n.rooms += 1
		local f = setmetatable({
			parent = parent, stem = stem, cf = cf, w = size.X, h = size.Y, d = size.Z, hw = size.X / 2, hd = size.Z / 2, floorY = floorY, tint = tint,
			solids = {}, keeps = {}, tops = {}, nc = 0, nprops = 0, nloose = 0, lampN = 0,
		}, Frame)
		framesAll[#framesAll + 1] = f
		return f
	end

	-- a point (x, z) of a prop's own frame, as seen in the room once the prop is turned to `face`
	local function rot(face, x, z)
		if face == "L" then
			return z, -x
		elseif face == "R" then
			return -z, x
		elseif face == "B" then
			return -x, -z
		end
		return x, z
	end
	-- footprint of a prop turned to `face`: offset of its centre from its origin and the half extents, in the room's x and z
	local function footprint(size, center, face)
		local hx, hz = size.X / 2, size.Z / 2
		local ox, oz = rot(face, center.X, center.Z)
		if face == "L" or face == "R" then
			return ox, oz, hz, hx
		end
		return ox, oz, hx, hz
	end

	function Frame:keep(x0, x1, d0, d1)
		self.keeps[#self.keeps + 1] = { x0, x1, d0 - self.hd, d1 - self.hd }
	end

	-- is the footprint (centre x, z; half extents) inside the room and clear of keep-outs and solids?
	function Frame:free(x, z, ex, ez, gap)
		gap = gap or 0.05
		if x - ex < -self.hw + 0.05 or x + ex > self.hw - 0.05 or z - ez < -self.hd + 0.05 or z + ez > self.hd - 0.05 then
			return false
		end
		for _, s in self.keeps do
			if x - ex < s[2] and x + ex > s[1] and z - ez < s[4] and z + ez > s[3] then
				return false
			end
		end
		for _, s in self.solids do
			if x - ex < s[2] - gap and x + ex > s[1] + gap and z - ez < s[4] - gap and z + ez > s[3] + gap then
				return false
			end
		end
		return true
	end

	-- a point (x, depth) clear of walls, keep-outs and solids
	function Frame:pointFree(x, d, pad)
		pad = pad or 0.9
		local z = d - self.hd
		if x < -self.hw + pad or x > self.hw - pad or z < -self.hd + pad or z > self.hd - pad then
			return false
		end
		for _, list in { self.keeps, self.solids } do
			for _, s in list do
				if x > s[1] - 0.4 and x < s[2] + 0.4 and z > s[3] - 0.4 and z < s[4] + 0.4 then
					return false
				end
			end
		end
		return true
	end

	local function note(f, what, x, d)
		if #REJECTS < 80 then
			REJECTS[#REJECTS + 1] = string.format("%s %s (%.1f, %.1f)", f.stem, what, x, d)
		end
	end

	local function collidersOf(name, opts)
		if opts and opts.collide ~= nil then
			return opts.collide or {}
		end
		if COLL2[name] then
			return COLL2[name]
		end
		local c = Kit.COLL[name]
		if c then
			return c
		end
		local size, center = Kit.size(name)
		return { { size, center } }
	end
	local function topOf(cols)
		local top = nil
		for _, c in cols do
			local ctr = c[2]
			if typeof(ctr) == "CFrame" then
				ctr = ctr.Position
			end
			local t = ctr.Y + c[1].Y / 2
			if not top or t > top then
				top = t
			end
		end
		return top
	end

	-- a kit prop centred (footprint) at x, depth d, its front toward `face`. opts: y (height above the floor), tint, collide, overlap
	-- (skip the clearance test), hang (wall decor: no solid is kept). Returns { model, x, d, top, cf } or nil.
	function Frame:prop(name, face, x, d, opts)
		opts = opts or {}
		local size, center = Kit.size(name)
		if not size then
			return nil
		end
		local ox, oz, ex, ez = footprint(size, center, face)
		local z = d - self.hd
		if not opts.overlap and not self:free(x, z, ex, ez) then
			if not opts.quiet then
				n.rejected += 1
				note(self, name, x, d)
			end
			return nil
		end
		local cols = collidersOf(name, opts)
		local cost = piecesOf(name) + #cols
		if n.props >= LIMIT.props or n.kparts + n.parts + cost > LIMIT.parts then
			n.cut += 1
			return nil
		end
		local ko = { shadows = false, tint = opts.tint or self.tint, collide = cols }
		local cf = self.cf * CFrame.new(x - ox, opts.y or 0, z - oz) * CFrame.Angles(0, rad(YAW[face]), 0)
		pace()
		local m = Kit.place(self.parent, name, cf, ko)
		if not m then
			return nil
		end
		n.props += 1
		n.kparts += cost
		self.nprops += 1
		if not opts.hang then
			self.solids[#self.solids + 1] = { x - ex, x + ex, z - ez, z + ez }
		end
		local info = { model = m, name = name, x = x, d = d, ex = ex, ez = ez, face = face, top = topOf(cols), cf = cf, sx = x, sd = d }
		if cols[1] then
			-- the middle of the first collider (where things can lie)
			local c1 = cols[1][2]
			if typeof(c1) == "CFrame" then
				c1 = c1.Position
			end
			local rx, rz = rot(face, c1.X, c1.Z)
			info.sx, info.sd = (x - ox) + rx, (z - oz) + rz + self.hd
		end
		if info.top and info.top < 4.8 and not opts.hang then
			self.tops[#self.tops + 1] = info
		end
		return info
	end

	-- a prop with its back to a wall (B back, F front, L left, R right), centred at s along the wall (x for B and F, depth for L and R)
	function Frame:against(wall, name, s, opts)
		local size, center = Kit.size(name)
		if not size then
			return nil
		end
		local face = TURN[wall]
		local _, _, ex, ez = footprint(size, center, face)
		if wall == "B" then
			return self:prop(name, face, s, self.d - 0.1 - ez, opts)
		elseif wall == "F" then
			return self:prop(name, face, s, 0.1 + ez, opts)
		elseif wall == "L" then
			return self:prop(name, face, -self.hw + 0.1 + ex, s, opts)
		end
		return self:prop(name, face, self.hw - 0.1 - ex, s, opts)
	end

	-- props along a wall from s0 to s1 (names: one prop or a list used in turn); a slot that does not fit is skipped. opts: gap between
	-- props, step (stride when a slot is skipped), plus the prop options. Returns the placed infos.
	function Frame:run(wall, names, s0, s1, opts)
		opts = opts or {}
		if type(names) == "string" then
			names = { names }
		end
		local out = {}
		local quiet = {}
		for key, v in opts do
			quiet[key] = v
		end
		quiet.quiet = true
		local s = s0
		local k = 0
		local guard = 0
		while guard < 80 do
			guard += 1
			local name = names[k % #names + 1]
			local size = Kit.size(name)
			if not size then
				return out
			end
			local half = size.X / 2
			if s + 2 * half > s1 + 0.01 or (opts.max and #out >= opts.max) then
				break
			end
			local info = self:against(wall, name, s + half, quiet)
			if info then
				out[#out + 1] = info
				k += 1
				s += 2 * half + (opts.gap or 0)
			else
				s += opts.step or 1
			end
		end
		return out
	end

	-- islands in a row along x at depth d, centred on x0 ... x1 every `pitch`; names cycle; face as given
	function Frame:row(names, face, d, x0, x1, pitch, opts)
		opts = opts or {}
		if type(names) == "string" then
			names = { names }
		end
		local out = {}
		local k = 0
		local x = x0
		while x <= x1 + 0.01 do
			local info = self:prop(names[k % #names + 1], face, x, d, opts)
			if info then
				out[#out + 1] = info
			end
			k += 1
			x += pitch
		end
		return out
	end

	-- props side by side along x from x0 to x1 (face F or B), their near edges at depth `edge`; gap between them
	function Frame:pack(names, face, edge, x0, x1, gap, opts)
		opts = opts or {}
		if type(names) == "string" then
			names = { names }
		end
		local out = {}
		local quiet = {}
		for key, v in opts do
			quiet[key] = v
		end
		quiet.quiet = true
		local k = 0
		local x = x0
		local guard = 0
		while guard < 80 do
			guard += 1
			local name = names[k % #names + 1]
			local size, center = Kit.size(name)
			if not size then
				return out
			end
			local _, _, ex, ez = footprint(size, center, face)
			if x + 2 * ex > x1 + 0.01 then
				break
			end
			local d = (face == "B") and (edge - ez) or (edge + ez)
			local info = self:prop(name, face, x + ex, d, quiet)
			if info then
				out[#out + 1] = info
				k += 1
				x += 2 * ex + gap
			else
				x += opts.step or 1
			end
		end
		return out
	end

	-- a placed prop becomes a container (its collider carries the prompt)
	function Frame:anchor(info, kind, label)
		if not info or info.anchored then
			return false
		end
		local a = info.model:FindFirstChild("KitCollider")
		if not a then
			return false
		end
		info.anchored = true
		self:register(kind, label, info.cf, a)
		return true
	end

	-- plain box: bottom at height y, centred at (x, d), turned to face; no solid is kept (use solidBox for floor-standing ones)
	function Frame:blk(sx, sy, sz, x, y, d, color, mat, face)
		local cf = self.cf * CFrame.new(x, y + sy / 2, d - self.hd) * CFrame.Angles(0, rad(YAW[face or "F"]), 0)
		pace()
		local p = kit.boxCF(self.parent, sx, sy, sz, cf, color, mat or M.SmoothPlastic)
		p.CastShadow = false
		p.CanTouch = false
		p:SetAttribute("NoDetail", true)
		n.parts += 1
		return p
	end
	-- a floor-standing box that blocks the room: refused when it overlaps something
	function Frame:solidBox(sx, sy, sz, x, d, color, mat, face)
		local ex, ez = sx / 2, sz / 2
		if face == "L" or face == "R" then
			ex, ez = ez, ex
		end
		local z = d - self.hd
		if not self:free(x, z, ex, ez) then
			n.rejected += 1
			note(self, "box", x, d)
			return nil
		end
		if n.kparts + n.parts + 1 > LIMIT.parts then
			n.cut += 1
			return nil
		end
		self.solids[#self.solids + 1] = { x - ex, x + ex, z - ez, z + ez }
		local p = self:blk(sx, sy, sz, x, 0, d, color, mat, face)
		p.CanCollide = true
		return p
	end

	-- containers ------------------------------------------------------------------------------------------------------------
	function Frame:register(kind, label, cf, anchor)
		self.nc += 1
		n.containers += 1
		n.byRoom[self.stem] = (n.byRoom[self.stem] or 0) + 1
		kit.container(self.parent, string.format("%s_%d", self.stem, self.nc), kind, label, cf, anchor)
	end
	-- a kit prop whose collider is the container
	function Frame:stash(name, face, x, d, kind, label, opts)
		local info = self:prop(name, face, x, d, opts)
		if not info then
			return nil
		end
		local anchor = info.model:FindFirstChild("KitCollider")
		if anchor then
			self:register(kind, label, info.cf, anchor)
		end
		return info
	end
	-- the world's own stand-in (crate, locker, drawer, safe) on the floor
	local STAND = { crate = { 4, 4, 2 }, locker = { 3, 2.2, 2 }, drawer = { 5, 2.6, 4 }, safe = { 3, 2.6, 5 } }
	function Frame:box(kind, label, x, d, face)
		local s = STAND[kind] or STAND.crate
		local ex, ez = s[1] / 2, s[2] / 2
		face = face or "F"
		if face == "L" or face == "R" then
			ex, ez = ez, ex
		end
		local z = d - self.hd
		if not self:free(x, z, ex, ez) then
			n.rejected += 1
			note(self, "stand-in " .. kind, x, d)
			return false
		end
		if n.kparts + n.parts + s[3] > LIMIT.parts then
			n.cut += 1
			return false
		end
		n.parts += s[3]
		self.solids[#self.solids + 1] = { x - ex, x + ex, z - ez, z + ez }
		self:register(kind, label, self.cf * CFrame.new(x, 0, z) * CFrame.Angles(0, rad(YAW[face]), 0), nil)
		return true
	end
	-- small containers of our own parts, on the floor (y 0) or on a surface at height y
	function Frame:small(kind, label, sx, sy, sz, color, mat, x, d, y, face, strip)
		face = face or "F"
		if (y or 0) < 0.1 then
			local ex, ez = sx / 2, sz / 2
			if face == "L" or face == "R" then
				ex, ez = ez, ex
			end
			if not self:free(x, d - self.hd, ex, ez) then
				n.rejected += 1
				note(self, kind, x, d)
				return false
			end
			self.solids[#self.solids + 1] = { x - ex, x + ex, d - self.hd - ez, d - self.hd + ez }
		end
		if n.kparts + n.parts + 2 > LIMIT.parts then
			n.cut += 1
			return false
		end
		local a = self:blk(sx, sy, sz, x, y or 0, d, color, mat, face)
		self:blk(sx + 0.1, 0.18, sz * 0.5, x, (y or 0) + sy * 0.6, d, strip or COL.caseLid, M.Metal, face)
		self:register(kind, label, a.CFrame, a)
		return true
	end
	function Frame:medbag(x, d, y, face, label)
		return self:small("medbag", label or "Med case", 2.2, 1.3, 1.2, COL.medGreen, M.Fabric, x, d, y, face, COL.white)
	end
	function Frame:toolbox(x, d, y, face, label)
		return self:small("toolbox", label or "Toolbox", 2.8, 1.5, 1.3, COL.redBox, M.Metal, x, d, y, face, COL.steel)
	end
	function Frame:gunCase(x, d, y, face, label)
		return self:small("weaponbox", label or "Weapon case", 4.6, 1.1, 1.7, COL.case, M.Metal, x, d, y, face, COL.caseLid)
	end
	function Frame:coat(x, d, y, face, label)
		return self:small("jacket", label or "Jacket", 1.9, 2.6, 0.7, COL.cloth, M.Fabric, x, d, y, face, C.wood)
	end
	function Frame:till(x, d, y, face, label)
		return self:small("register", label or "Till", 1.8, 0.9, 1.4, COL.steelDk, M.Metal, x, d, y, face, COL.counterTop)
	end

	-- loose loot ------------------------------------------------------------------------------------------------------------
	-- an item lying at (x, d), `y` above the floor; the world drops it onto the surface under it
	function Frame:spot(x, d, y, pool, chance)
		local p = self.cf * V3(x, y, d - self.hd)
		kit.loose(p.X, p.Y, p.Z, pool, chance or 0.4, "meridian", true)
		n.loose += 1
		self.nloose += 1
		return true
	end
	function Frame:floorSpot(x, d, pool, chance)
		if self:pointFree(x, d) then
			return self:spot(x, d, 0.4, pool, chance)
		end
		return false
	end
	-- on top of a placed prop (info from prop/stash), dx and dd offset from its centre
	function Frame:topSpot(info, pool, chance, dx, dd)
		if not info or not info.top or info.top > 4.8 then
			return false
		end
		return self:spot(info.sx + (dx or 0), info.sd + (dd or 0), info.top + 0.3, pool, chance)
	end
	-- floor spots at random places of a band (tries a few times), for rooms with no furniture to lay things on
	function Frame:scatter(count, pool, chance, d0, d1)
		local made = 0
		for _ = 1, count do
			for _ = 1, 6 do
				local lo, hi = d0 or 2, d1 or self.d - 2
				if hi < lo then
					hi = lo
				end
				local x = rng:NextNumber(-self.hw + 2, self.hw - 2)
				local d = rng:NextNumber(lo, hi)
				if self:floorSpot(x, d, pool, chance) then
					made += 1
					break
				end
			end
		end
		return made
	end
	-- the placed prop with a top nearest to a map-local point (the reference's key tiles)
	function Frame:nearestTop(mx, mz)
		local w = O + V3(mx, 0, mz)
		local lp = self.cf:PointToObjectSpace(V3(w.X, self.floorY, w.Z))
		local best, bd = nil, 1e9
		for _, t in self.tops do
			local dx, dz = t.x - lp.X, (t.d - self.hd) - lp.Z
			local dd = dx * dx + dz * dz
			if dd < bd and t.top > 1.5 then
				best, bd = t, dd
			end
		end
		return best
	end

	-- lights: a flat fixture under the ceiling with a light that is dead until the mall has power (B.powerHooks)
	local lamps = {}
	function Frame:lamp(x, d, range, bright, y)
		if n.kparts + n.parts + 1 > LIMIT.parts then
			return nil
		end
		local p = self:blk(2.6, 0.35, 0.9, x, y or (self.h - 0.6), d, LAMP_OFF, M.SmoothPlastic, "F")
		p.CanCollide = false
		p.Name = "Lamp"
		local l = kit.light(p, hex("FFD9A8"), range or 30, bright or 0.8, false)
		l.Enabled = false
		lamps[#lamps + 1] = { light = l, part = p }
		shellLamps[#shellLamps + 1] = { p = p.Position, r = range or 30 }
		n.lights += 1
		self.lampN += 1
		return p
	end

	-- is the point (x, d) of this room farther than 0.8 of a lamp's range from every lamp of this level (the shell's or ours)?
	function Frame:dark(x, d)
		local w = self.cf * V3(x, 0, d - self.hd)
		for _, q in shellLamps do
			local dy = q.p.Y - w.Y
			if dy > self.h * 0.4 and dy < self.h + 3 then
				local dx, dz = q.p.X - w.X, q.p.Z - w.Z
				local r = q.r * 0.8
				if dx * dx + dz * dz < r * r then
					return false
				end
			end
		end
		return true
	end
	-- lamps where the room is dark: sample points on a grid of `pitch` studs (44 by default), a lamp at each dark one
	function Frame:lightUp(range, bright, pitch)
		pitch = pitch or 44
		local nx = math.clamp(math.floor(self.w / pitch + 0.5), 1, 6)
		local nd = math.clamp(math.floor(self.d / pitch + 0.5), 1, 6)
		local made = 0
		for i = 1, nx do
			for j = 1, nd do
				local x = -self.hw + self.w * (i - 0.5) / nx
				local d = self.d * (j - 0.5) / nd
				if self:dark(x, d) then
					if self:lamp(x, d, range or 30, bright or 0.8) then
						made += 1
					end
				end
			end
		end
		return made
	end

	-- keep-outs ---------------------------------------------------------------------------------------------------------------
	-- an opening in a wall of this room (e.pos on the wall line, e.width wide) keeps a strip in front of it free
	function Frame:openings(list)
		for _, e in list or {} do
			local lp = self.cf:PointToObjectSpace(e.pos)
			local lx, lz = lp.X, lp.Z
			local half = e.width / 2 + 1.2
			local depth = (e.width >= 30) and 5.5 or 7.5
			if lz < -self.hd - 0.3 and lz > -self.hd - 3.5 and math.abs(lx) <= self.hw + 0.6 then
				self:keep(lx - half, lx + half, 0, depth)
			elseif lz > self.hd + 0.3 and lz < self.hd + 3.5 and math.abs(lx) <= self.hw + 0.6 then
				self:keep(lx - half, lx + half, self.d - depth, self.d)
			elseif lx > self.hw + 0.3 and lx < self.hw + 3.5 and math.abs(lz) <= self.hd + 0.6 then
				self:keep(self.hw - depth, self.hw, lz + self.hd - half, lz + self.hd + half)
			elseif lx < -self.hw - 0.3 and lx > -self.hw - 3.5 and math.abs(lz) <= self.hd + 0.6 then
				self:keep(-self.hw, -self.hw + depth, lz + self.hd - half, lz + self.hd + half)
			end
		end
	end
	-- a door leaf of the shell (or ours) in a wall of this room: the swing and the way to it stay free
	function Frame:doorway(rec, depthIn, halfW)
		if not rec then
			return
		end
		local lp = self.cf:PointToObjectSpace(rec.cf.Position)
		local lx, lz = lp.X, lp.Z
		local hw2 = halfW or 4.4
		local dp = depthIn or 6.5
		if lz < -self.hd - 0.2 and lz > -self.hd - 3.5 then
			self:keep(lx - hw2, lx + hw2, 0, dp)
		elseif lz > self.hd + 0.2 and lz < self.hd + 3.5 then
			self:keep(lx - hw2, lx + hw2, self.d - dp, self.d)
		elseif lx > self.hw + 0.2 and lx < self.hw + 3.5 then
			self:keep(self.hw - dp, self.hw, lz + self.hd - hw2, lz + self.hd + hw2)
		elseif lx < -self.hw - 0.2 and lx > -self.hw - 3.5 then
			self:keep(-self.hw, -self.hw + dp, lz + self.hd - hw2, lz + self.hd + hw2)
		end
	end
	-- the shell's solid parts that stand inside the room
	function Frame:shellSolids()
		local fx, fz = self.cf.Position.X, self.cf.Position.Z
		local fr = (self.w + self.d) / 2 + 4
		for _, s in shell do
			if math.abs(s.x - fx) < s.r + fr and math.abs(s.z - fz) < s.r + fr and s.y1 > self.floorY + 0.8 and s.y0 < self.floorY + 14 then
				local p = s.p
				local hx, hz = p.Size.X / 2, p.Size.Z / 2
				local x0, x1, z0, z1 = 1e9, -1e9, 1e9, -1e9
				for _, sx in { -hx, hx } do
					for _, sz in { -hz, hz } do
						local lp = self.cf:PointToObjectSpace(p.CFrame * V3(sx, 0, sz))
						x0, x1 = math.min(x0, lp.X), math.max(x1, lp.X)
						z0, z1 = math.min(z0, lp.Z), math.max(z1, lp.Z)
					end
				end
				local ox = math.min(x1, self.hw) - math.max(x0, -self.hw)
				local oz = math.min(z1, self.hd) - math.max(z0, -self.hd)
				if ox > 0.4 and oz > 0.4 then
					self.solids[#self.solids + 1] = { x0 - 0.1, x1 + 0.1, z0 - 0.1, z1 + 0.1 }
				end
			end
		end
	end

	local function stemOf(id, prefix)
		local s = string.upper(string.sub(id, 4))
		return (prefix or "MM2_") .. s
	end

	-- a unit's two rooms: its sales floor and, when it has one, the stock room behind it
	local function roomsOf(u, tint)
		local m = kit.model(u.id, root)
		local f = newFrame(m, stemOf(u.id), u.cframe, u.size, u.floorY, tint)
		f:openings(u.entrances)
		f:shellSolids()
		local s = nil
		if u.stock then
			s = newFrame(m, stemOf(u.id) .. "_S", u.stock.cframe, u.stock.size, u.floorY, tint)
			s:openings(u.entrances)
			s:shellSolids()
			local door = W.doors[u.stock.door]
			if door then
				f:doorway(door, 4.5, 3.6)
				s:doorway(door, 6.8, 6.4)
			end
		end
		return f, s
	end

	-- ── shipping containers you can walk into (Unit 14) ───────────────────────────────────────────────
	-- a face turned by another face (a thing placed in the container's own frame, seen from the room)
	local function compose(a, b)
		local ang = (YAW[a] + YAW[b]) % 360
		if ang == 0 then
			return "F"
		elseif ang == 90 then
			return "L"
		elseif ang == 180 then
			return "B"
		end
		return "R"
	end
	local CARGO = { len = 19.0, wid = 7.6, hgt = 8.1, t = 0.35 }
	-- x, d: the middle of its footprint; face: the way the open end looks. Nine plain parts: roof, two sides, back wall, four posts
	-- and a header over the open end. Returns { x, d, face, base } or nil.
	function Frame:cargo(x, d, face, color)
		local Lc, Wc, Hc, T = CARGO.len, CARGO.wid, CARGO.hgt, CARGO.t
		local ex, ez = Wc / 2, Lc / 2
		if face == "L" or face == "R" then
			ex, ez = ez, ex
		end
		local z = d - self.hd
		if not self:free(x, z, ex, ez) then
			n.rejected += 1
			note(self, "cargo", x, d)
			return nil
		end
		if n.kparts + n.parts + 9 > LIMIT.parts then
			n.cut += 1
			return nil
		end
		self.solids[#self.solids + 1] = { x - ex, x + ex, z - ez, z + ez }
		local base = self.cf * CFrame.new(x, 0, z) * CFrame.Angles(0, rad(YAW[face]), 0)
		local function piece(sx, sy, sz, px, py, pz, col, mat)
			pace()
			local p = kit.boxCF(self.parent, sx, sy, sz, base * CFrame.new(px, py, pz), col, mat)
			p.CastShadow = false
			p:SetAttribute("NoDetail", true)
			n.parts += 1
			return p
		end
		piece(Wc, 0.3, Lc, 0, Hc - 0.15, 0, color, M.CorrodedMetal) -- roof
		piece(T, Hc - 0.3, Lc, -Wc / 2 + T / 2, (Hc - 0.3) / 2, 0, color, M.CorrodedMetal) -- left side
		piece(T, Hc - 0.3, Lc, Wc / 2 - T / 2, (Hc - 0.3) / 2, 0, color, M.CorrodedMetal) -- right side
		piece(Wc - 2 * T, Hc - 0.3, T, 0, (Hc - 0.3) / 2, Lc / 2 - T / 2, color, M.CorrodedMetal) -- back wall
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				piece(0.5, Hc, 0.5, sx * (Wc / 2 - 0.25), Hc / 2, sz * (Lc / 2 - 0.25), COL.steelDk, M.Metal)
			end
		end
		piece(Wc, 0.6, 0.5, 0, Hc - 0.6, -Lc / 2 + 0.25, COL.steelDk, M.Metal) -- header over the open end
		return { x = x, d = d, face = face, base = base, len = Lc, wid = Wc }
	end
	function Frame:techCase(x, d, y, face, label)
		return self:small("techbox", label or "Tech case", 2.6, 1.8, 1.6, COL.case, M.Metal, x, d, y, face, COL.caseLid)
	end
	-- an item inside a cargo container: lx across its width, lz along its length (-len/2 is the open end), face2 the way it looks
	function Frame:cargoItem(c, kind, label, lx, lz, face2)
		if not c then
			return false
		end
		face2 = face2 or "F"
		if STAND[kind] then
			if n.kparts + n.parts + STAND[kind][3] > LIMIT.parts then
				n.cut += 1
				return false
			end
			n.parts += STAND[kind][3]
			self:register(kind, label, c.base * CFrame.new(lx, 0, lz) * CFrame.Angles(0, rad(YAW[face2]), 0), nil)
			return true
		end
		local rx, rz = rot(c.face, lx, lz)
		local f = compose(c.face, face2)
		local fns = { medbag = self.medbag, toolbox = self.toolbox, weaponbox = self.gunCase, jacket = self.coat, register = self.till, techbox = self.techCase }
		local fn = fns[kind]
		if not fn then
			return false
		end
		return fn(self, c.x + rx, c.d + rz, 0.12, f, label)
	end

	-- ── recipes ───────────────────────────────────────────────────────────────────────────────────────────
	local function pick(list)
		return list[rng:NextInteger(1, #list)]
	end
	-- first placed prop of a name in a list of infos
	local function firstOf(list, name, skip)
		local seen = 0
		for _, info in list do
			if info.name == name then
				if seen >= (skip or 0) then
					return info
				end
				seen += 1
			end
		end
		return nil
	end
	-- the k-th of `total` evenly spread picks of a list (nil for an empty list)
	local function spread(list, k, total)
		if #list == 0 then
			return nil
		end
		if total <= 1 then
			return list[math.ceil(#list / 2)]
		end
		return list[math.floor(1 + (k - 1) * (#list - 1) / (total - 1) + 0.5)]
	end

	-- centre lines (depths) of rows of furniture in a room `limit` deep: `front` studs kept free at the front, `back` at the back,
	-- rows at least `pitch` apart, each needing `half` either side; one row sits in the middle of what is left
	local function rowDepths(limit, half, pitch, front, back)
		local usable = limit - front - back
		local list = {}
		if usable < 2 * half then
			return list
		end
		local cnt = math.floor((usable - 2 * half) / pitch) + 1
		if cnt == 1 then
			list[1] = front + usable / 2
		else
			local step = (usable - 2 * half) / (cnt - 1)
			for k = 1, cnt do
				list[k] = front + half + (k - 1) * step
			end
		end
		return list
	end

	-- the room behind a store: shelves along its back wall with gaps between them, boxes in the two end corners, containers on
	-- the shelves (spec.kinds, one container kind per pick), loose items on the floor and on the boxes (spec.pool).
	-- spec: names (shelf props in turn), shelves (how many), kinds, labels, loose, pool, chance, pallets (false: no corner boxes)
	local function stock(S, spec)
		if not S then
			return
		end
		spec = spec or {}
		local hw = S.hw
		local nShelf = spec.shelves or math.clamp(math.floor(S.w / 18), 2, 5)
		local gap = spec.gap or math.max(2, (S.w - 1.0 - nShelf * 8.0) / math.max(1, nShelf - 1))
		local shelves = S:run("B", spec.names or { "StorageShelf", "StorageRack", "StorageShelf" }, -hw + 0.5, hw - 0.5, { gap = gap, step = 2, max = nShelf })
		local boxes = {}
		if spec.pallets ~= false then
			boxes[#boxes + 1] = S:prop("PalletBoxes", "F", -hw + 2.4, 2.6)
			boxes[#boxes + 1] = S:prop("PalletBoxes", "F", hw - 2.4, 2.6)
		end
		local kinds = spec.kinds or { "crate" }
		local labels = spec.labels or { "Stock crate" }
		for k, kind in kinds do
			local s = spread(shelves, k, #kinds)
			local label = labels[k] or labels[1] or "Stock shelf"
			if kind == "safe" or kind == "drawer" or kind == "locker" or not S:anchor(s, kind, label) then
				S:box(kind, label, -hw + 6 + k * 7, 4.4, "F")
			end
		end
		S:topSpot(boxes[1], spec.pool or "mall", spec.chance or 0.4)
		S:scatter(spec.loose or 1, spec.pool or "mall", spec.chance or 0.4, 1.5, S.d - 3)
		return shelves
	end

	-- restaurants: shallow ones serve over counters set against the back wall; deeper ones have a service line (counters and tills
	-- with a gap for the staff every so often) and the kitchen behind it. Tables in rows in front; spec.pitchX and spec.rowPitch
	-- space the seating, spec.row0 keeps more of the front free
	local function food(F, S, spec)
		spec = spec or {}
		local D, hw = F.d, F.hw
		local area = F.w * F.d
		local shallow = D < 24
		local back, line
		local cd0
		if shallow then
			back = F:run("B", { "FoodCounter", "Fridge", "FoodCounter", "Locker" }, -hw + 0.5, hw - 0.5, { gap = 1.5, step = 2 })
			line = back
			cd0 = D - 4.4
		else
			local bk = (D >= 28) and 5.0 or 3.2
			cd0 = math.max(7.0, D - bk - 3.6 - 4.2)
			back = F:run("B", { "Locker", "Fridge", "Counter", "StorageShelf", "Fridge" }, -hw + 0.5, hw - 0.5, { gap = 1 })
			line = F:pack({ "FoodCounter", "Checkout" }, "F", cd0, -hw + 1.0, hw - 1.0, spec.passGap or 5.5, { step = 2 })
		end
		local tables = {}
		local k = 0
		for _, dd in rowDepths(cd0 - 1.5, 3.1, spec.rowPitch or 10.0, spec.row0 or 3.2, 0.6) do
			for _, t in F:row("FoodTable", "F", dd, -hw + 4.5 + (k % 2) * 5, hw - 4.5, spec.pitchX or 11) do
				tables[#tables + 1] = t
			end
			k += 1
		end
		if area > 1700 then
			F:prop("Planter", "F", hw - 3.6, 3.6)
		end
		local vend = F:against("R", "Vending", cd0 - 3.2)
		if not vend then
			vend = F:against("L", "Vending", cd0 - 3.2)
		end
		F:prop("Bin", "F", -hw + 1.2, math.min(cd0 - 2.2, 6.0))
		-- containers and loose loot
		local till = firstOf(line, "Checkout") or line[1]
		F:anchor(till, "register", "Till")
		if area > 2400 then
			F:anchor(firstOf(line, "Checkout", 1) or line[2], "register", "Till")
		end
		if not F:anchor(firstOf(back, "Fridge"), "cooler", "Drinks fridge") then
			F:anchor(vend, "cooler", "Vending machine")
		end
		if area > 1700 then
			F:anchor(firstOf(back, "Locker"), "locker", "Staff locker")
		end
		F:topSpot(till, "mall", 0.5)
		F:topSpot(tables[math.ceil(#tables / 2)], "grocery", 0.45)
		if area > 1700 then
			F:topSpot(tables[#tables], "drinks", 0.4)
		end
		if area > 2400 then
			F:scatter(1, "mall", 0.4, 2, cd0)
		end
		if spec.stock ~= false then
			stock(S, { kinds = { "grocery" }, labels = { "Dry store shelf" }, pool = "grocery", loose = 1 })
		end
		return { line = line, back = back, tables = tables, till = till }
	end

	-- clothes shops: shelving on the walls, racks and tables in rows, mannequins at the front, a till at the back
	local function clothing(F, S, spec)
		spec = spec or {}
		local D, hw = F.d, F.hw
		F:run("B", { "WallShelf", "WallShelf", "WallShelfSparse" }, -hw + 0.5, hw - 0.5, { gap = 0 })
		F:run("L", "WallShelf", 8.5, D - 2.4, { gap = 0 })
		F:run("R", "WallShelf", 8.5, D - 2.4, { gap = 0 })
		local racks = {}
		local k = 0
		for _, dd in rowDepths(D, 2.85, 10.4, 3.4, 5.6) do
			local list
			if k % 2 == 0 then
				list = F:row("ClothesRack", "F", dd, -hw + 9, hw - 9, spec.pitch or 10.5)
			else
				list = F:row("DisplayTable", "F", dd, -hw + 11, hw - 11, spec.pitch or 10.5)
			end
			for _, r in list do
				racks[#racks + 1] = r
			end
			k += 1
		end
		F:prop("Mannequin", "F", -hw + 2.4, 2.4)
		F:prop("Mannequin", "F", hw - 2.4, 2.4)
		local till = F:prop("Checkout", "F", hw - 9.5, D - 7.6)
		F:anchor(till, "register", "Till")
		local coats = {}
		for _, r in racks do
			if r.name == "ClothesRack" then
				coats[#coats + 1] = r
			end
		end
		F:anchor(spread(coats, 1, 2), "jacket", "Coat rack")
		if #coats > 7 then
			F:anchor(spread(coats, 2, 2), "jacket", "Coat rack")
		end
		F:topSpot(till, "mall", 0.45)
		F:topSpot(firstOf(racks, "DisplayTable"), "mall", 0.4)
		stock(S, { kinds = { "jacket" }, labels = { "Spare coats" }, pool = "mall", loose = 1 })
	end

	-- general and grocery shops: gondola aisles in blocks of three, fridges, two tills at the front
	local function grocery(F, S, spec)
		spec = spec or {}
		local D, hw = F.d, F.hw
		F:run("B", { "WallShelf", "WallShelf", "WallShelfSparse" }, -hw + 0.5, hw - 0.5, { gap = 0 })
		local fr = F:against("R", "Fridge", D - 13)
		local fr2 = F:against("L", "Fridge", D - 13)
		local gond = {}
		for _, dd in rowDepths(D, 2.1, 10.6, 8.2, 5.0) do
			local x = -hw + 6
			local cnt = 0
			while x + 4 <= hw - 5 do
				local g = F:prop("Gondola", "F", x + 4, dd)
				if g then
					gond[#gond + 1] = g
				end
				cnt += 1
				x += 8.5
				if cnt % 3 == 0 then
					x += 5.5
				end
			end
		end
		local c1 = F:prop("Checkout", "F", -hw + 8, 3.2)
		local c2 = F:prop("Checkout", "F", hw - 8, 3.2)
		F:anchor(c1 or c2, "register", "Till")
		F:anchor(spread(gond, 2, 3), "grocery", "Shelf")
		F:anchor(fr or fr2, "cooler", "Drinks fridge")
		F:topSpot(c1 or c2, "grocery", 0.5)
		F:scatter(1, "grocery", 0.4, 3, D - 4)
		stock(S, { kinds = { "grocery" }, labels = { "Stock shelf" }, pool = "grocery", loose = 1 })
	end

	-- pharmacies: shelving with medicines, cabinets in rows, fridges, tills, a bench for waiting
	local function pharmacy(F, S, spec)
		spec = spec or {}
		local D, hw = F.d, F.hw
		F:run("B", "WallShelfMeds", -hw + 0.5, hw - 0.5, { gap = 0 })
		F:run("L", "WallShelfMeds", 8.5, D - 2.4, { gap = 0 })
		F:run("R", "WallShelfMeds", 8.5, D - 2.4, { gap = 0 })
		local cab = {}
		for _, dd in rowDepths(D, 1.5, 9.0, 3.4, 6.0) do
			for _, c in F:row("MedShelf", "F", dd, -hw + 9, hw - 9, spec.pitch or 11) do
				cab[#cab + 1] = c
			end
		end
		local fr = F:against("R", "Fridge", D - 13)
		local c1 = F:prop("Checkout", "F", -hw + 8, 3.2)
		F:prop("Bench", "F", 0, 2.0)
		if F.w * D > 1500 then
			F:prop("Planter", "F", hw - 3.6, 3.6)
		end
		F:anchor(c1, "register", "Till")
		F:anchor(fr, "pharmacy", "Medicine fridge")
		F:anchor(spread(cab, 1, 2), "pharmacy", "Medicine shelf")
		if #cab > 6 then
			F:anchor(spread(cab, 2, 2), "pharmacy", "Medicine shelf")
		end
		F:medbag(-hw + 14, 2.4, 0, "F", "Med case")
		F:topSpot(c1, "pharmacy", 0.5)
		F:topSpot(cab[1], "pharmacy", 0.4)
		F:scatter(1, "pharmacy", 0.4, 3, D - 4)
		stock(S, { kinds = { "pharmacy" }, labels = { "Stock cabinet" }, pool = "pharmacy", loose = 1 })
		return { c1 = c1, cab = cab }
	end

	-- electronics: screens on the back wall, tables with computers and phones in rows, tills
	local function electronics(F, S, spec)
		spec = spec or {}
		local D, hw = F.d, F.hw
		F:run("B", { "WallShelf", "TVWall", "WallShelf", "WallShelf" }, -hw + 0.5, hw - 0.5, { gap = 0 })
		F:run("L", "WallShelf", 8.5, D - 2.4, { gap = 0 })
		F:run("R", "WallShelf", 8.5, D - 2.4, { gap = 0 })
		local tbl = {}
		local k = 0
		for _, dd in rowDepths(D, 1.5, 9.5, 3.4, 6.0) do
			local list
			if k % 2 == 0 then
				list = F:row({ "TechTable", "DisplayTable" }, "F", dd, -hw + 8, hw - 8, spec.pitch or 10)
			else
				list = F:row({ "DisplayTable", "TechTable" }, "F", dd, -hw + 13, hw - 8, spec.pitch or 10)
			end
			for _, t in list do
				tbl[#tbl + 1] = t
			end
			k += 1
		end
		local c1 = F:prop("Checkout", "F", -hw + 8, 3.2)
		if F.w * D > 1500 then
			F:prop("Planter", "F", hw - 3.6, 3.6)
		end
		F:anchor(c1, "register", "Till")
		local pcs = {}
		for _, t in tbl do
			if t.name == "TechTable" then
				pcs[#pcs + 1] = t
			end
		end
		local nPc = spec.pcs or 1
		for q = 1, nPc do
			F:anchor(spread(pcs, q, nPc), "techbox", "Computer")
		end
		F:topSpot(c1, "tech", 0.5)
		F:topSpot(spread(tbl, 2, 3), "tech", 0.4)
		F:scatter(spec.scatter or 0, "tech", 0.35, 3, D - 4)
		if spec.stock ~= false then
			stock(S, { kinds = { "techbox" }, labels = { "Spare stock" }, pool = "tech", loose = 1 })
		end
		return { c1 = c1, tbl = tbl, pcs = pcs }
	end

	-- furniture showroom: sets of sofas, tables, beds and desks, wardrobes on the back wall
	local function furniture(F, S, spec)
		local D, hw = F.d, F.hw
		F:run("B", { "StorageShelf", "TVWall", "StorageShelf", "StorageShelf" }, -hw + 0.5, hw - 0.5, { gap = 0 })
		F:run("L", "StorageShelf", 8.5, D - 2.4, { gap = 3 })
		local desks = {}
		local rows = 0
		for _, dd in rowDepths(D, 3.7, 11.0, 3.4, 8.0) do
			local x = -hw + 6
			local q = 0
			while x + 3.5 <= hw - 5 do
				local name = ({ "Sofa", "Bed", "OfficeDesk", "Table", "Sofa", "Bed" })[(q + rows * 2) % 6 + 1]
				local size = Kit.size(name)
				local info = F:prop(name, "F", x + size.X / 2, dd)
				if info and name == "OfficeDesk" then
					desks[#desks + 1] = info
				end
				x += size.X + 5.5
				q += 1
			end
			rows += 1
		end
		F:prop("Planter", "F", hw - 3.6, 3.6)
		local till = F:prop("Checkout", "F", hw - 9, D - 8)
		F:anchor(till, "register", "Till")
		F:anchor(spread(desks, 1, 1), "drawer", "Desk drawer")
		F:topSpot(till, "mall", 0.45)
		F:topSpot(desks[1], "office", 0.4)
		stock(S, { kinds = { "crate" }, labels = { "Packed crate" }, pool = "junk", loose = 1, gap = 9 })
	end

	-- the museum: cases and plinths in rows, exhibits, benches, an office and a vault at the back
	local function museum(F, S, spec)
		local D, hw = F.d, F.hw
		F:run("B", { "WallShelfBooks", "WallShelfBooks", "StorageShelf" }, -hw + 0.5, hw - 0.5, { gap = 1 })
		F:run("L", "WallShelfBooks", 8.5, D - 2.4, { gap = 4 })
		F:run("R", "WallShelfBooks", 8.5, D - 2.4, { gap = 4 })
		local cases = {}
		local k = 0
		for _, dd in rowDepths(D, 2.5, 9.6, 3.4, 7.0) do
			local list
			if k % 2 == 0 then
				list = F:row("JewelCase", "F", dd, -hw + 10, hw - 10, 14)
			else
				list = F:row({ "DisplayTable", "Mannequin", "DisplayTable" }, "F", dd, -hw + 17, hw - 10, 9.5)
			end
			for _, c in list do
				cases[#cases + 1] = c
			end
			k += 1
		end
		F:prop("Bench", "F", -hw + 8, 2.6)
		F:prop("Bench", "F", hw - 8, 2.6)
		F:prop("Planter", "F", 0, 3.6)
		local till = F:prop("Checkout", "F", hw - 9, D - 8.5)
		local desk = F:prop("OfficeDesk", "F", -hw + 8, D - 8)
		F:anchor(till, "register", "Gift shop till")
		F:anchor(desk, "drawer", "Curator's desk")
		local jc = {}
		for _, c in cases do
			if c.name == "JewelCase" then
				jc[#jc + 1] = c
			end
		end
		F:anchor(spread(jc, 1, 1), "safe", "Display case")
		F:box("crate", "Exhibit crate", hw - 5, D - 15, "F")
		F:topSpot(desk, "office", 0.45)
		F:topSpot(till, "mall", 0.4)
		F:topSpot(spread(cases, 2, 3), "office", 0.35)
		stock(S, { kinds = { "drawer" }, labels = { "Archive drawer" }, pool = "office", loose = 1, gap = 8 })
	end

	-- a travel agency: desks with clerks' chairs, a departures board, brochures
	local function travel(F, S, spec)
		local D, hw = F.d, F.hw
		F:run("B", { "WallShelfBooks", "WallShelfBooks" }, -hw + 0.5, hw - 0.5, { gap = 1 })
		F:prop("DepartureBoard", "F", 0, D - 0.9, { y = 7.4, hang = true, overlap = true })
		local desks = F:row("OfficeDesk", "F", D - 9, -hw + 7, hw - 7, 11)
		local till = F:prop("Checkout", "F", -hw + 7, 4.0)
		F:prop("Sofa", "F", hw - 6, 3.2)
		F:prop("Planter", "F", hw - 3.6, D - 3.6)
		F:anchor(till, "register", "Till")
		F:anchor(spread(desks, 1, 1), "drawer", "Booking desk")
		F:topSpot(desks[1], "office", 0.4)
		F:topSpot(till, "mall", 0.4)
		stock(S, { kinds = { "crate" }, labels = { "Brochure box" }, pool = "office", loose = 1, gap = 9 })
	end

	-- the first of several positions along a wall where a prop fits
	local function againstAny(F, wall, name, list)
		for _, at in list do
			local info = F:against(wall, name, at, { quiet = true })
			if info then
				return info
			end
		end
		return nil
	end

	-- a sports and games hall: shelves and lockers on the back wall, weights and treadmills in front of them, arcade machines
	-- along the left wall, racks and gondolas in rows, a till on the right wall (its door and the front stay free)
	local function sports(F, S, spec)
		local D, hw = F.d, F.hw
		local back = F:run("B", { "WallShelf", "Lockers", "WallShelf", "WallShelf", "Lockers" }, -hw + 0.5, hw - 0.5, { gap = 0, step = 1 })
		F:row("Treadmill", "B", D - 7.5, -hw + 6, -2, 4.4)
		local wr = F:row("WeightRack", "F", D - 8.5, 4, hw - 9, 8)
		F:run("L", "Arcade", 7, D - 12, { gap = 0.5, step = 1 })
		F:against("L", "Bench", 4.0, { quiet = true })
		local rk = {}
		local gond = {}
		local k = 0
		for _, dd in rowDepths(D - 12, 2.9, 9.0, 7.6, 1.5) do
			if k % 2 == 0 then
				for _, r in F:row("ClothesRack", "F", dd, -hw + 9, hw - 14, 10.5) do
					rk[#rk + 1] = r
				end
			else
				for _, g in F:row("Gondola", "F", dd, -hw + 10, hw - 14, 11) do
					gond[#gond + 1] = g
				end
			end
			k += 1
		end
		local till = againstAny(F, "R", "Checkout", { 30, 9, 33, 12 })
		F:anchor(till, "register", "Till")
		F:anchor(firstOf(back, "Lockers"), "locker", "Team lockers")
		F:anchor(spread(rk, 1, 1), "jacket", "Team jackets")
		F:medbag(-hw + 3.0, D - 10.5, 0, "F", "Gym bag")
		F:topSpot(till, "mall", 0.45)
		F:topSpot(spread(gond, 1, 2), "junk", 0.35)
		F:topSpot(wr[1], "junk", 0.35)
		stock(S, { kinds = { "crate" }, labels = { "Kit crate" }, pool = "junk", loose = 1 })
	end

	-- a closed unit: dust sheets over what is left, rubble and cardboard, a hoarding across the middle
	local function sheet(F, sx, sy, sz, x, d, face)
		return F:solidBox(sx, sy, sz, x, d, pick({ COL.sheet, COL.sheetDk }), M.Fabric, face)
	end
	local function closedBig(F, S, spec)
		local D, hw = F.d, F.hw
		F:run("B", { "StorageShelfEmpty", "WallShelfSparse", "StorageShelfEmpty" }, -hw + 0.5, hw - 0.5, { gap = 5, step = 2 })
		F:run("L", "StorageShelfEmpty", 12, D - 4, { gap = 12, step = 3 })
		-- a hoarding wall across the unit with two gaps
		F:row("Hoarding", "F", 17.5, -hw + 8, hw - 8, 17.5)
		local pal = {}
		local specs = { "PalletBoxes", "CardboardPile", "RubbleB", "PalletBoxes", "CardboardPile", "RubbleA", "Beam", "Sandbags", "TyreStack" }
		for k = 1, 22 do
			local name = specs[(k - 1) % #specs + 1]
			local info = nil
			for _ = 1, 4 do
				local x = rng:NextNumber(-hw + 6, hw - 6)
				local d = rng:NextNumber(24, D - 8)
				info = F:prop(name, pick({ "F", "R", "L", "B" }), x, d)
				if info then
					break
				end
			end
			if info and name == "PalletBoxes" then
				pal[#pal + 1] = info
			end
		end
		local bench = F:prop("CraftBench", "F", -hw + 10, D - 9)
		F:prop("WorkLight", "F", -hw + 18, D - 8)
		local chest = F:prop("ToolChest", "F", hw - 8, D - 6)
		local chest2 = F:prop("ToolChest", "B", hw - 20, 28)
		F:anchor(chest, "toolbox", "Contractor's toolbox")
		F:anchor(pal[1], "crate", "Building supplies")
		F:anchor(pal[2], "crate", "Building supplies")
		F:box("safe", "Site safe", -hw + 4, D - 20, "R")
		for _ = 1, 3 do
			sheet(F, 8.4, 5.2, 4.8, rng:NextNumber(-hw + 8, hw - 8), rng:NextNumber(26, D - 10), pick({ "F", "R" }))
		end
		F:topSpot(bench, "junk", 0.45)
		F:scatter(3, "junk", 0.35, 8, D - 3)
		stock(S, { kinds = { "crate" }, labels = { "Left-behind crate" }, pool = "junk", loose = 2, gap = 9, names = { "StorageShelfEmpty", "StorageShelf" } })
	end
	local function openingSoon(F, S, spec)
		local D, hw = F.d, F.hw
		F:run("B", { "WallShelf", "StorageShelfEmpty", "WallShelfSparse" }, -hw + 0.5, hw - 0.5, { gap = 0, step = 2 })
		F:run("L", "StorageShelfEmpty", 8.5, D - 3, { gap = 6, step = 3 })
		local g = F:row("Gondola", "F", D - 11, -hw + 8, hw - 8, 14)
		F:row("PalletBoxes", "F", 10.5, -hw + 6, hw - 6, 17)
		local till = F:prop("Checkout", "F", hw - 8, D - 6.5)
		local crates = F:row("PalletBoxes", "F", 5.0, -hw + 9, hw - 9, 19)
		F:anchor(till, "register", "Till")
		F:anchor(g[1], "crate", "Fitting-out crate")
		F:toolbox(-hw + 6, D - 5, 0, "F", "Fitters' toolbox")
		for _ = 1, 2 do
			sheet(F, 8.4, 5.0, 4.6, rng:NextNumber(-hw + 8, hw - 8), rng:NextNumber(10, D - 8), pick({ "F", "R" }))
		end
		F:topSpot(till, "junk", 0.4)
		F:scatter(2, "junk", 0.35, 5, D - 3)
		stock(S, { kinds = { "crate" }, labels = { "Fitting-out crate" }, pool = "junk", loose = 1, gap = 10 })
	end

	-- ── doors ─────────────────────────────────────────────────────────────────────────────────────────────
	local function addDoor(id, cf, size, key, label, parent)
		local rec = { id = id, cf = cf, size = size, key = key, label = label, parent = parent, color = hex("6A6E66") }
		if not key then
			rec.openChance = 0.4
		end
		W.doors[id] = rec
		n.doors += 1
		return rec
	end
	-- an existing door of the shell takes a key (the world locks every door that has one)
	local function rekey(id, key)
		local d = W.doors[id]
		if not d then
			return false
		end
		d.key = key
		d.openChance = nil
		n.keyed += 1
		return true
	end
	-- the widest entrance of a unit is closed by two wall fillers either side of a door and a lintel over it: the room behind
	-- can only be entered with the key. Returns the door record.
	local function frontDoor(u, parent, id, key, label)
		local best = nil
		for _, e in u.entrances or {} do
			if not best or e.width > best.width then
				best = e
			end
		end
		if not best then
			return nil
		end
		local lp = u.cframe:PointToObjectSpace(best.pos)
		local lx, lz = lp.X, lp.Z
		local half = best.width / 2
		local dw, wallH, wallT = 5.2, 13.5, 2.0
		local fill = (half - dw / 2) / 2
		local fcol, fmat = hex("74766E"), M.Plaster
		if fill > 0.2 then
			for _, sgn in { -1, 1 } do
				local f = kit.boxCF(parent, half - dw / 2, wallH, wallT, u.cframe * CFrame.new(lx + sgn * (dw / 2 + fill), wallH / 2, lz), fcol, fmat)
				f.Name = "DoorFiller"
				f:SetAttribute("NoDetail", true)
				n.parts += 1
			end
		end
		local lintel = kit.boxCF(parent, dw, wallH - 8.6, wallT, u.cframe * CFrame.new(lx, 8.6 + (wallH - 8.6) / 2, lz), fcol, fmat)
		lintel.Name = "DoorLintel"
		lintel:SetAttribute("NoDetail", true)
		n.parts += 1
		-- the leaf swings toward the inside (a door opens toward its local -Z), so it is turned half a circle from the unit's frame
		local cf = u.cframe * CFrame.new(lx, 4.3, lz) * CFrame.Angles(0, math.pi, 0)
		return addDoor(id, cf, V3(dw, 8.6, 0.35), key, label, parent)
	end

	-- ── special rooms of the upper floor ──────────────────────────────────────────────────────────────────
	-- the staff kitchen behind the food-court restaurant of the reference's #49: steel counters, fridges, lockers; KEY_MALL_STAFF
	local function kitchen(S)
		if not S then
			return
		end
		local hw = S.hw
		-- the strip is 8.8 deep: the aisle stays 3.4 wide or more, so fridges (4.9 deep) stand where nothing faces them and the
		-- lockers (2 deep) only face counters and shelves (3 deep at most)
		local back = {}
		for _, info in S:run("B", "Fridge", -hw + 0.3, -hw + 10.5, { step = 1 }) do
			back[#back + 1] = info
		end
		for _, info in S:run("B", { "Counter", "StorageShelf", "Counter" }, -4.8, hw - 0.3, { gap = 0.3, step = 1 }) do
			back[#back + 1] = info
		end
		local banks = {}
		for _, info in S:run("F", "Locker", hw - 13, hw - 1, { gap = 0.3, step = 1 }) do
			banks[#banks + 1] = info
		end
		for _, info in S:run("F", "Locker", -3.5, 4.5, { gap = 0.3, step = 1 }) do
			banks[#banks + 1] = info
		end
		S:anchor(banks[2], "locker", "Staff locker")
		S:anchor(banks[#banks - 1], "locker", "Staff locker")
		S:anchor(firstOf(back, "Fridge"), "cooler", "Kitchen fridge")
		S:anchor(firstOf(back, "StorageShelf"), "grocery", "Dry store")
		S:anchor(firstOf(back, "Counter"), "register", "Kitchen till")
		-- the safe stands against the partition between the two locker banks, the case in the niche at the left end
		for _, x in { 7.5, 8.0, 7.0 } do
			if S:box("safe", "Manager's safe", x, 1.5, "B") then
				break
			end
		end
		S:medbag(-hw + 3.5, 1.6, 0, "F", "First-aid case")
		for _, c in back do
			if c.name == "Counter" then
				S:topSpot(c, "grocery", 0.55)
			end
		end
		S:topSpot(firstOf(back, "Counter", 1), "mallkeys", 0.3)
		S:scatter(2, "grocery", 0.45, 2, S.d - 2)
		S:lightUp(28, 0.9)
	end

	-- VOLTA's stock room: racks of graphics cards, servers and cable, a safe; KEY_VOLTA_STORE
	local function voltaStore(S)
		if not S then
			return
		end
		local hw = S.hw
		stock(S, {
			names = { "StorageRack", "StorageShelf", "StorageRack" },
			shelves = 7, gap = 5.5,
			kinds = { "techbox", "techbox", "techbox", "crate", "techbox", "techbox", "techbox" },
			labels = { "GPU crate", "Server case", "Cable crate", "Packing crate", "Router box", "GPU crate", "Parts bin" },
			pool = "tech", loose = 4, chance = 0.55,
		})
		for _, x in { hw - 9, -hw + 9, 0, hw - 25 } do
			if S:box("safe", "Stock safe", x, 4.6, "F") then
				break
			end
		end
		S:toolbox(-hw + 12, 4.2, 0, "F", "Fitter's toolbox")
		S:scatter(5, "tech", 0.5, 1.5, S.d - 3)
		S:lightUp(30, 0.9)
	end

	-- the MEDIQ store room: the whole unit sits behind a keyed front door (KEY_MEDIQ, power on)
	local function mediqStore(u)
		local F, S = roomsOf(u, TINT.store)
		local rec = frontDoor(u, F.parent, "MM_MEDIQ_STORE", "KEY_MEDIQ", "MEDIQ store room")
		if rec then
			F:doorway(rec, 6.5, 4.4)
		end
		local hw, D = F.hw, F.d
		local back = F:run("B", { "MedShelf", "StorageRack", "MedShelf", "StorageRack" }, -hw + 0.5, hw - 0.5, { gap = 0.5, step = 2 })
		local left = F:run("L", "MedShelf", 8.5, D - 3.2, { gap = 0.5, step = 2 })
		local right = F:run("R", "MedShelf", 8.5, D - 3.2, { gap = 0.5, step = 2 })
		local mid = F:row("StorageRack", "F", 11.5, -5, 5, 10)
		F:anchor(back[1], "pharmacy", "Medicine shelf")
		F:anchor(back[2], "pharmacy", "Dispensary rack")
		F:anchor(back[3], "pharmacy", "Medicine shelf")
		F:anchor(left[1], "pharmacy", "Medicine shelf")
		F:anchor(right[1], "pharmacy", "Medicine shelf")
		F:anchor(mid[1], "pharmacy", "Dispensary rack")
		F:medbag(-hw + 3, 3.4, 0, "F", "Med case")
		F:medbag(hw - 3, 3.4, 0, "F", "Med case")
		F:medbag(-hw + 3, 8.0, 0, "R", "Surgical case")
		for _, x in { hw - 4, -hw + 4, hw - 10 } do
			if F:box("safe", "Narcotics safe", x, 5.8, "F") then
				break
			end
		end
		F:box("drawer", "Dispensary drawer", -hw + 10.5, D - 7.2, "F")
		F:scatter(9, "pharmacy", 0.6, 3, D - 3)
		F:lightUp(28, 0.9)
		if S then
			local sh = stock(S, {
				names = { "MedShelf", "StorageRack", "MedShelf" },
				shelves = 4, kinds = { "pharmacy", "pharmacy", "pharmacy", "crate" },
				labels = { "Medicine shelf", "Cold-chain rack", "Medicine shelf", "Delivery crate" }, pool = "pharmacy", loose = 5, chance = 0.6,
			})
			S:medbag(-S.hw + 3, 5.2, 0, "F", "Trauma case")
			S:medbag(S.hw - 3, 5.2, 0, "F", "Trauma case")
			S:lightUp(24, 0.8)
			return { front = F, stock = S, shelves = sh }
		end
		return { front = F }
	end

	-- ── THE SHELTER (L0): the hidden saferoom behind the card door ─────────────────────────────────────────
	-- Tarkov's saferoom is a bunker you can loot in peace once the door is shut: bunks, supply racks, a weapon bench, food
	-- and medicine. The reference draws the whole block as solid and gives no room size (grade D); the room is about
	-- 43 x 28 m around the exit icon (Layout service.shelter), the arch from the vestibule at its front-right corner.
	-- Walls: R (right, the arch's side) entry benches, notice boards and the armoury; B (back) lockers, supply racks and
	-- tanks; L (left) the kitchen, a sofa and the utility corner. Middle: mess tables, the briefing table and the bunks.
	local function shelter(u)
		local F = roomsOf(u, TINT.shelter)
		local hw, D = F.hw, F.d
		-- the arch from the vestibule; the exit zone's marking and beacon stay free
		F:keep(hw - 26, hw, 0, 20)
		local pt = B.points and B.points.SHELTER_ROOM
		if pt then
			local lp = F.cf:PointToObjectSpace(pt)
			F:keep(lp.X - 12, lp.X + 12, lp.Z + F.hd - 12, lp.Z + F.hd + 12)
		end
		-- entry wall: benches, notices, then the armoury (racks of weapons, a bench with cases, kit stands)
		F:against("R", "Bench", 26)
		F:against("R", "Bench", 34)
		F:prop("CorkBoard", "L", hw - 0.3, 42, { hang = true, overlap = true, y = 3.2 })
		F:prop("Whiteboard", "L", hw - 0.5, 50, { hang = true, overlap = true, y = 3.0 })
		F:run("R", "GunRack", 52, 72, { gap = 1, step = 2 })
		local gb = nil
		for _, at in { D - 8, D - 9, D - 10 } do
			gb = F:against("R", "GunBench", at, { quiet = true })
			if gb then
				break
			end
		end
		if gb then
			F:gunCase(gb.sx, gb.sd - 3.5, 3.4, "L", "Weapon case")
			F:gunCase(gb.sx, gb.sd + 3.5, 3.4, "L", "Weapon case")
		end
		F:against("B", "ArmorStand", hw - 6)
		F:against("B", "ArmorStand", hw - 9)
		F:against("B", "RigStand", hw - 12)
		-- back wall: the bunk lockers, the supply racks, water and fuel
		local lockers = F:run("B", "Lockers", 14, hw - 15, { gap = 1.2, step = 2 })
		F:anchor(lockers[1], "locker", "Bunk locker")
		F:anchor(lockers[3], "locker", "Bunk locker")
		F:anchor(lockers[5], "locker", "Bunk locker")
		local racks = F:run("B", { "StorageRack", "StorageShelf", "StorageRack" }, -24, 12, { gap = 1.5, step = 2 })
		F:anchor(racks[1], "crate", "Supply rack")
		F:anchor(racks[3], "crate", "Ration rack")
		F:topSpot(firstOf(racks, "StorageShelf"), "junk", 0.4)
		F:against("B", "WaterTank", -hw + 16)
		F:against("B", "WaterTank", -hw + 23)
		F:against("B", "PalletBoxes", -hw + 30)
		F:against("B", "PalletBoxes", -hw + 35)
		F:row("Drum", "F", D - 8, -hw + 29, -hw + 37, 4)
		F:prop("JerryCans", "F", -hw + 40, D - 2)
		-- the utility corner (back-left): the generator, its toolbox, the fuse box and the cabinet
		F:against("L", "HideoutGenerator", D - 12)
		F:toolbox(-hw + 6, D - 20, 0, "R", "Generator toolbox")
		F:against("L", "FuseBox", 64, { y = 1.5 })
		F:against("L", "ElectricCabinet", 56)
		-- the sofa with valuables (the reference's saferoom has one)
		local couch = F:against("L", "Sofa", 46, { quiet = true }) or F:against("L", "Sofa", 50, { quiet = true })
		F:topSpot(couch, "mallgood", 0.6)
		-- the kitchen along the left wall and the mess in front of it
		local kit1 = F:run("L", { "Fridge", "Counter", "Counter" }, 5, 42, { gap = 0.5, step = 2 })
		F:anchor(firstOf(kit1, "Fridge"), "cooler", "Ration fridge")
		F:anchor(firstOf(kit1, "Counter"), "grocery", "Galley counter")
		local tables = F:row("Table", "F", 26, -46, -18, 14)
		for _, t in F:row("Table", "F", 13, -46, -18, 14) do
			tables[#tables + 1] = t
		end
		for _, t in tables do
			F:prop("Chair", "F", t.x, t.d + 3.2)
			F:prop("Chair", "B", t.x, t.d - 3.2)
			F:topSpot(t, "grocery", 0.3)
		end
		-- the infirmary by the front wall
		local ms = F:run("F", "MedShelf", -2, 22, { gap = 0.5, step = 2 })
		F:anchor(ms[1], "pharmacy", "Infirmary shelf")
		local cots = F:row("MedCot", "F", 13, 0, 24, 12)
		F:medbag(6, 19, 0, "F", "Med case")
		F:medbag(14, 19, 0, "F", "Med case")
		F:topSpot(firstOf(cots, "MedCot"), "pharmacy", 0.45)
		-- the briefing table, and the bunks in two rows
		F:prop("MapTable", "F", -6, 44)
		local bunks = {}
		for _, row in { 72, 58 } do
			for _, b in F:row("BunkBed", "F", row, 6, 6 + 13 * 3, 13) do
				bunks[#bunks + 1] = b
			end
		end
		-- what the sleepers left beside their beds (a bunk is 5 high: nothing can lie on it within reach, so it lies in front)
		for k = 1, 4 do
			local b = spread(bunks, k, 4)
			if b then
				F:floorSpot(b.x, b.d - 3.2, (k % 2 == 0) and "dorm_good" or "dorm", 0.5)
			end
		end
		F:coat(12, 65, 0, "F", "Jacket")
		F:coat(38, 65, 0, "F", "Jacket")
		F:scatter(4, "junk", 0.4, 6, D - 4)
		F:scatter(2, "mall", 0.4, 6, D - 4)
		F:lightUp(40, 0.9, 36)
		return F
	end

	-- ── UNIT 14 (L0): the container room ──────────────────────────────────────────────────────────────────
	local function unit14(u)
		local F = roomsOf(u, TINT.unit14)
		local hw, D = F.hw, F.d
		-- the card door is in the front wall: its swing stays free
		local door = W.doors["MM_UNIT14"]
		if door then
			F:doorway(door, 7.0, 5.0)
		end
		local cols = { hex("8A3A2E"), hex("3E5868"), C.olive, hex("A9822F"), C.teal, C.rust }
		-- two rows of walk-in shipping containers
		local conts = {}
		local rowsAt = { 21, 45 }
		local faces = { { "R", "L", "L" }, { "R", "R", "L" } }
		local xs = { -30, 0, 30 }
		local ci = 0
		for r, dd in rowsAt do
			for k, x in xs do
				ci += 1
				local c = F:cargo(x, dd, faces[r][k], cols[(ci - 1) % #cols + 1])
				if c then
					conts[#conts + 1] = c
				end
			end
		end
		-- what is inside them: the best loot of the mall (the first item stands on the left, the second on the right)
		local SLOT = {
			safe = { 1.95, 6.6, "F" }, crate = { 1.6, 6.2, "F" }, drawer = { 2.0, 6.8, "F" }, techbox = { 2.2, 7.3, "F" },
			medbag = { 2.2, 7.4, "F" }, toolbox = { 2.1, 7.3, "F" }, weaponbox = { 2.6, 6.8, "L" },
		}
		local inside = {
			{ { "safe", "Container safe" }, { "crate", "Sealed crate" } },
			{ { "weaponbox", "Weapon case" }, { "crate", "Sealed crate" } },
			{ { "techbox", "Server case" }, { "safe", "Container safe" } },
			{ { "medbag", "Medical case" }, { "safe", "Container safe" } },
			{ { "crate", "Sealed crate" }, { "weaponbox", "Weapon case" } },
			{ { "safe", "Container safe" }, { "toolbox", "Toolbox" } },
		}
		for k, c in conts do
			local list = inside[k] or inside[1]
			for i, it in list do
				local s = SLOT[it[1]]
				F:cargoItem(c, it[1], it[2], ((i == 1) and -1 or 1) * s[1], s[2], s[3])
			end
			local rx, rz = rot(c.face, 0, -2.0)
			F:spot(c.x + rx, c.d + rz, 0.5, "vault", 0.5)
		end
		-- racks along the back wall
		local racks = F:run("B", "PalletRack", -hw + 0.5, hw - 0.5, { gap = 1.5, step = 2 })
		for k, r in racks do
			if k % 2 == 1 then
				F:anchor(r, "crate", "Pallet rack")
			end
		end
		F:prop("Forklift", "F", -hw + 12, D - 16)
		F:prop("Forklift", "B", hw - 10, 56, { overlap = false })
		for _, spot in { { -38, 8 }, { -20, 33 }, { 18, 33 }, { 40, 10 }, { -38, 58 }, { 38, 58 }, { 4, 33 }, { -10, 58 } } do
			F:prop("PalletBoxes", "F", spot[1], spot[2])
		end
		F:prop("RollCage", "F", -14, 9)
		F:prop("RollCage", "F", -10, 9)
		F:prop("CardboardPile", "F", 22, 56)
		F:row("Drum", "F", 62, -20, 0, 6)
		F:prop("JerryCans", "F", hw - 3, 36)
		F:prop("ToolChest", "F", -hw + 3, 36)
		F:anchor(F:prop("ToolChest", "F", -hw + 3.5, 30), "toolbox", "Rigger's chest")
		F:prop("WorkLight", "L", hw - 3, 28)
		F:box("safe", "Cargo safe", hw - 4, 12, "L")
		F:box("drawer", "Dispatch drawer", -hw + 5, 14, "R")
		F:scatter(5, "vault", 0.5, 4, D - 4)
		F:scatter(4, "mallgood", 0.45, 4, D - 4)
		F:scatter(3, "tech", 0.45, 4, D - 4)
		F:lightUp(36, 0.9, 46)
		return F
	end

	-- ── the units of the upper floor ──────────────────────────────────────────────────────────────────────
	-- the sign over the entrance takes the unit's name; its board grows or shrinks to the text (the shell sized it for the kind)
	local function rename(u, text)
		u.name = text
		local g = u.signGui
		local lab = g and g:FindFirstChildOfClass("TextLabel")
		if lab then
			lab.Text = text
		end
		local board = u.sign
		if board and board:IsA("BasePart") then
			local w = math.clamp(#text * 1.15 + 4, 8, 26)
			board.Size = V3(w, board.Size.Y, board.Size.Z)
		end
	end

	-- id -> { reference name, our sign, recipe, tint, spec, after }. Fixed names: VOLTA (Techlight), MEDIQ (ULTRA Medical).
	local PLAN = {
		-- food court
		L2_fck = { ref = "FCK", name = "GOLDEN WING", run = food, tint = "food" },
		L2_mcdaniels = { ref = "McDaniels", name = "BIG BITE", run = food, tint = "food" },
		L2_tarducks = { ref = "Tarducks", name = "DAWN ROAST", run = food, tint = "food" },
		L2_coffee_joy = { ref = "Coffee Joy", name = "CUP & SAUCER", run = food, tint = "food" },
		L2_sushi_huyushi = { ref = "Sushi Huyushi", name = "TIDE SUSHI", run = food, tint = "food" },
		L2_burger_house = { ref = "Burger House", name = "SMOKEHOUSE", run = food, tint = "food" },
		L2_shiccos = { ref = "Shiccos", name = "OLIVE & SALT", run = food, tint = "food" },
		L2_underway = { ref = "Underway", name = "CROSSTOWN DELI", run = food, tint = "food" },
		L2_philly_cute = { ref = "Philly Cute", name = "COPPER PAN", run = food, tint = "food", spec = { rowPitch = 13.5 } },
		L2_pushkin = { ref = "Pushkin", name = "SILVER FORK", run = food, tint = "food", spec = { row0 = 9.5 } },
		L2_burger_spot_49 = {
			ref = "Burger Spot (#49)", name = "STACK & SIZZLE", run = food, tint = "food", spec = { stock = false },
			after = function(F, S)
				kitchen(S)
				rekey("MM_L2_burger_spot_49_STOCK", "KEY_MALL_STAFF")
				F:topSpot(F:nearestTop(309.4, -287.5), "mallkeys", 0.55)
				F:topSpot(F:nearestTop(359.4, -287.5), "mallkeys", 0.55)
			end,
		},
		-- clothing
		L2_father_sons = { ref = "Father & Sons", name = "HALE & KIN", run = clothing, tint = "clothing" },
		L2_eastland = { ref = "Eastland", name = "LINDEN WEAR", run = clothing, tint = "clothing" },
		L2_jacob_jacob = { ref = "Jacob & Jacob", name = "HOLLIS & PARK", run = clothing, tint = "clothing" },
		L2_papillon = { ref = "Papillon", name = "VELVET MOTH", run = clothing, tint = "clothing", spec = { pitch = 14 } },
		L2_figaro = { ref = "Figaro", name = "SHEARS & CO", run = clothing, tint = "clothing" },
		L2_urban_clothes = { ref = "Urban Clothes", name = "METRO WEAR", run = clothing, tint = "clothing" },
		L2_fashion_store = { ref = "Fashion Store", name = "CATWALK", run = clothing, tint = "clothing" },
		-- general
		L2_tarkovstar = { ref = "Tarkovstar", name = "ALDER GENERAL", run = grocery, tint = "general" },
		L2_sara = { ref = "SARA", name = "EVERYDAY STORE", run = grocery, tint = "general" },
		-- pharmacies
		L2_tarzdrav = { ref = "Tarzdrav", name = "WELLSPRING", run = pharmacy, tint = "pharmacy" },
		L2_apteka = {
			ref = "Apteka (ULTRA Medical's pharmacy)", name = "MEDIQ", run = pharmacy, tint = "pharmacy",
			after = function(F, S, info)
				F:topSpot(info and info.c1, "mallkeys", 0.55)
			end,
		},
		-- electronics
		L2_na_svyazi = { ref = "Na-Svyazi", name = "SIGNAL POINT", run = electronics, tint = "electronics" },
		L2_techlight = {
			ref = "Techlight", name = "VOLTA", run = electronics, tint = "electronics", spec = { stock = false, pcs = 3, scatter = 2 },
			after = function(F, S)
				voltaStore(S)
				rekey("MM_L2_techlight_STOCK", "KEY_VOLTA_STORE")
				F:topSpot(F:nearestTop(-36.6, 183.8), "mallkeys", 0.55)
			end,
		},
		-- the rest
		L2_furniture_mk = { ref = "Furniture MK", name = "HEARTH & HOME", run = furniture, tint = "furniture" },
		L2_history_museum = { ref = "History Museum", name = "REGIONAL MUSEUM", run = museum, tint = "museum" },
		L2_intourist = { ref = "Intourist", name = "HORIZON TRAVEL", run = travel, tint = "travel" },
		L2_arena = { ref = "Arena", name = "PLAYFIELD", run = sports, tint = "sports" },
		L2_closed_for_repairs = { ref = "Closed for repairs", name = "CLOSED FOR REFIT", run = closedBig, tint = "closed" },
		L2_opening_soon = { ref = "Opening soon", name = "OPENING SOON", run = openingSoon, tint = "closed" },
	}
	-- units handled by their own function (the reference's ULTRA med locked room)
	local SPECIAL = {
		L2_ultra_med_locked_room = { ref = "ULTRA med (locked room)", name = "MEDIQ STORE ROOM" },
	}

	-- the furnishing pass of the small shops (StoresFill.luau): a fitting room, wall units, posters, floor fixtures and litter, added
	-- after the recipe and the lamps, within its own part budget (these parts are not counted in LIMIT above). The frame's solids carry
	-- what it takes, so nothing else is placed over it; a pass that is missing or fails leaves the shop as the recipe made it.
	local Fill = nil
	local fillMod = script.Parent:FindFirstChild("StoresFill")
	if fillMod then
		local okFill, resFill = pcall(function()
			return require(fillMod)(B)
		end)
		if okFill then
			Fill = resFill
		else
			warn("[ZR] Meridian StoresL2: StoresFill did not load: " .. tostring(resFill))
		end
	end
	local FILL_KIND = {
		clothing = true, general = true, pharmacy = true, electronics = true, furniture = true, museum = true, travel = true, sports = true,
	}
	local function fill(F, u, plan)
		if not Fill or not FILL_KIND[plan.tint] then
			return
		end
		local a = {
			id = u.id, level = 2, cf = F.cf, W = F.w, D = F.d, ceil = F.h, kind = plan.tint, u = u,
			rects = function()
				local out = {}
				for _, s in F.solids do
					out[#out + 1] = { s[1], s[3] + F.hd, s[2], s[4] + F.hd }
				end
				for _, s in F.keeps do
					out[#out + 1] = { s[1], s[3] + F.hd, s[2], s[4] + F.hd }
				end
				return out
			end,
			take = function(x0, d0, x1, d1)
				F.solids[#F.solids + 1] = { x0, x1, d0 - F.hd, d1 - F.hd }
			end,
		}
		if plan.ref == "Intourist" then
			-- the departure board hangs on the middle of the back wall; the recipe does not keep that floor space
			a.noPoster = { B = true }
			a.extra = { { -6.5, F.d - 2.0, 6.5, F.d } }
		end
		Fill.shop(a)
	end

	-- the L0 rooms first (their budget is reserved), then the locked store, then the shops in id order
	local rooms0 = {}
	local l0 = B.units["L0_saferoom_exfil_room"]
	if l0 and l0.cframe and l0.size then
		local ok, err = pcall(shelter, l0)
		if not ok then
			warn("[ZR] Meridian StoresL2: the shelter failed: " .. tostring(err))
		end
		rooms0[#rooms0 + 1] = "L0_saferoom_exfil_room"
	end
	local u14 = B.units["L0_object_14_container_room"]
	if u14 and u14.cframe and u14.size then
		local ok, err = pcall(unit14, u14)
		if not ok then
			warn("[ZR] Meridian StoresL2: unit 14 failed: " .. tostring(err))
		end
		rooms0[#rooms0 + 1] = "L0_object_14_container_room"
	end

	local um = B.units["L2_ultra_med_locked_room"]
	local mediqDone = 0
	if um and um.cframe and um.size then
		rename(um, SPECIAL.L2_ultra_med_locked_room.name)
		local ok, err = pcall(mediqStore, um)
		if ok then
			mediqDone = 1
		else
			warn("[ZR] Meridian StoresL2: the MEDIQ store room failed: " .. tostring(err))
		end
	end

	local ids = {}
	for id, p in PLAN do
		local u = B.units[id]
		if u and u.cframe and u.size then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	local done = {}
	for _, id in ids do
		local u = B.units[id]
		local plan = PLAN[id]
		rename(u, plan.name)
		local ok, err = pcall(function()
			local F, S = roomsOf(u, TINT[plan.tint])
			local info = plan.run(F, S, plan.spec or {})
			if plan.after then
				plan.after(F, S, info)
			end
			F:lightUp()
			if S then
				S:lightUp()
			end
			fill(F, u, plan)
			done[#done + 1] = id
		end)
		if not ok then
			warn("[ZR] Meridian StoresL2: " .. id .. " failed: " .. tostring(err))
		end
	end

	-- ── lamps follow the power ────────────────────────────────────────────────────────────────────────────
	B.powerHooks[#B.powerHooks + 1] = function(on)
		for _, q in lamps do
			q.light.Enabled = on and true or false
			q.part.Material = on and M.Neon or M.SmoothPlastic
			q.part.Color = on and LAMP_ON or LAMP_OFF
		end
	end

	-- ── totals ────────────────────────────────────────────────────────────────────────────────────────────
	count.prop += n.props
	count.container += n.containers
	count.door += n.doors
	count.light += n.lights
	print(string.format(
		"[ZR] Meridian stores L2: %d rooms (%d L2 units, %d L0 rooms), %d kit props, %d parts (%d kit pieces and colliders, %d own), %d containers, %d loose spots, %d new doors, %d keyed doors, %d lamps, %d placements refused, %d cut for budget, %.2fs",
		n.rooms, #done + mediqDone, #rooms0, n.props, n.kparts + n.parts, n.kparts, n.parts, n.containers, n.loose, n.doors, n.keyed, n.lights, n.rejected, n.cut, os.clock() - t0
	))
	if Fill then
		print("[ZR] Meridian small shops L2: " .. Fill.report(2))
		print("[ZR] Meridian small shops, both floors: " .. Fill.report())
	end
	-- an offline test harness sets B.debugStores to read the rooms back; the game never sets it
	if B.debugStores then
		local out = {}
		for _, f in framesAll do
			out[#out + 1] = { stem = f.stem, cf = f.cf, w = f.w, d = f.d, solids = f.solids, keeps = f.keeps, floorY = f.floorY, nprops = f.nprops, nloose = f.nloose, nc = f.nc, lamps = f.lampN }
		end
		B.debugStores.frames = out
		B.debugStores.rejects = REJECTS
		B.debugStores.stats = n
	end
end
