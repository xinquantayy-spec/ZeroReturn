--!nonstrict
-- Meridian Mall main floor stores, toolkit: StoresL1.luau and StoresL1Halls.luau build with it. A frame per unit (or stock room)
-- remembers the floor space taken so far (walls, columns, entrances and doors of the shell, then every prop), so props never
-- overlap and nothing stands in an opening. Kit props go in by footprint, in runs along a wall or a line, in rows; plain boxes and
-- walled rooms are the cheap pieces; containers, loose spots, doors and lamps register with the world; the counters feed the
-- summary line. Unit coordinates: x to the right when facing out through the front, d the depth from the front wall, heights above
-- the unit's floor. Yaw 0 faces the front of the unit, 180 the back, 90 faces -x and -90 faces +x.
return function(B)
	local kit, W, Kit, O = B.kit, B.W, B.Kit, B.O
	local M, hex = kit.M, kit.hex
	local T = {}
	local n = { props = 0, pieces = 0, colliders = 0, parts = 0, cont = 0, loose = 0, doors = 0, lamps = 0, rejected = 0 }
	T.n = n
	T.rejects = {}
	T.byKind = {}
	T.frames = {}
	local root = kit.model("StoresL1", B.map)
	T.root = root

	local PAL = {
		shelf = hex("5C6461"), shelfDark = hex("3A3F3D"), wood = hex("7A6448"), woodDark = hex("5A4733"), card = hex("A88B62"),
		cardDark = hex("8A7048"), white = hex("D8D8D0"), red = hex("8A3E33"), blue = hex("3E5868"), green = hex("4F6B4A"),
		yellow = hex("B89A3E"), orange = hex("B8693A"), steel = hex("8C9390"), black = hex("232726"), plaster = hex("7B7D75"),
		glass = hex("9CC2CA"), grey = hex("6B6F6C"), bars = hex("2E3332"), door = hex("6A6E66"), teal = hex("3D5A57"),
		plum = hex("6B4E5E"), sand = hex("B1A893"), lampLight = hex("FFD9A8"), lampOn = hex("FFE2B0"), lampOff = hex("6F6C64"),
		olive = hex("5E6448"), cream = hex("C9C2A8"),
	}
	T.PAL = PAL

	-- ── pacing, ids ─────────────────────────────────────────────────────────────────────────────────────
	local lastPace = os.clock()
	local function pace()
		if task and os.clock() - lastPace > 0.04 then
			task.wait()
			lastPace = os.clock()
		end
	end
	local function hashId(s)
		local h = 7
		for i = 1, #s do
			h = (h * 31 + string.byte(s, i)) % 2147483000
		end
		return h + 1
	end
	local function shortId(id)
		return (string.gsub(id, "^L1_", ""))
	end

	-- ── lamps follow the power ──────────────────────────────────────────────────────────────────────────────
	local lamps = {}
	B.powerHooks = B.powerHooks or {}
	B.powerHooks[#B.powerHooks + 1] = function(on)
		for _, q in lamps do
			q.light.Enabled = on and true or false
			q.part.Material = on and M.Neon or M.SmoothPlastic
			q.part.Color = on and PAL.lampOn or PAL.lampOff
		end
	end

	-- ── what the shell leaves in the way: collidable parts of the main floor, doors with their swing, openings ───────
	local FLOORY = 17.81
	for _, u in B.units do
		if u.level == 1 and u.floorY then
			FLOORY = u.floorY
			break
		end
	end
	local obs = {} -- map-local rectangles { x0, z0, x1, z1 }
	do
		local mall = B.map:FindFirstChild("Mall")
		local l1 = mall and mall:FindFirstChild("L1")
		if l1 then
			for _, p in l1:GetDescendants() do
				if p:IsA("BasePart") and p.CanCollide then
					local cf, s = p.CFrame, p.Size
					local r, up, lk = cf.RightVector, cf.UpVector, cf.LookVector
					local hx = (math.abs(r.X) * s.X + math.abs(up.X) * s.Y + math.abs(lk.X) * s.Z) / 2
					local hy = (math.abs(r.Y) * s.X + math.abs(up.Y) * s.Y + math.abs(lk.Y) * s.Z) / 2
					local hz = (math.abs(r.Z) * s.X + math.abs(up.Z) * s.Y + math.abs(lk.Z) * s.Z) / 2
					local pos = cf.Position
					if pos.Y + hy > FLOORY + 0.3 and pos.Y - hy < FLOORY + 9 then
						obs[#obs + 1] = { pos.X - O.X - hx, pos.Z - O.Z - hz, pos.X - O.X + hx, pos.Z - O.Z + hz }
					end
				end
			end
		end
		for _, d in W.doors do
			local pos = d.cf.Position
			if pos.Y > FLOORY and pos.Y < FLOORY + 12 then
				local look, right, w = d.cf.LookVector, d.cf.RightVector, d.size.X
				local a = pos - look * 2 - right * (w / 2 + 0.8)
				local b = pos + look * (w + 1) + right * (w / 2 + 0.8)
				obs[#obs + 1] = { math.min(a.X, b.X) - O.X, math.min(a.Z, b.Z) - O.Z, math.max(a.X, b.X) - O.X, math.max(a.Z, b.Z) - O.Z }
			end
		end
	end
	T.obs = obs
	local INWARD = { N = { 0, 1 }, S = { 0, -1 }, W = { 1, 0 }, E = { -1, 0 } }

	-- ── kit prop geometry: footprint (rotated), top of the collider ───────────────────────────────────────────
	local FP, CR = {}, {}
	local function rot(ry, cx, cz, hx, hz)
		if ry == 90 then
			return cz, -cx, hz, hx
		elseif ry == -90 then
			return -cz, cx, hz, hx
		elseif ry == 180 then
			return -cx, -cz, hx, hz
		end
		return cx, cz, hx, hz
	end
	local function footprint(name, ry, sc)
		local key = name .. ":" .. ry .. ":" .. (sc and (sc.X .. "," .. sc.Z) or "1")
		local fp = FP[key]
		if fp then
			return fp
		end
		local size, center = Kit.size(name)
		if not size then
			return nil
		end
		local sx, sz, cx, cz = size.X, size.Z, center.X, center.Z
		if sc then
			sx, sz, cx, cz = sx * sc.X, sz * sc.Z, cx * sc.X, cz * sc.Z
		end
		local ox, od, hx, hz = rot(ry, cx, cz, sx / 2, sz / 2)
		fp = { ox = ox, od = od, hx = hx, hz = hz }
		FP[key] = fp
		return fp
	end
	-- the largest collider that is more than a step high: where loose loot can lie on the prop
	local function colRect(name, ry, sc)
		local key = name .. ":" .. ry .. ":" .. (sc and (sc.X .. "," .. sc.Y .. "," .. sc.Z) or "1")
		local c = CR[key]
		if c ~= nil then
			return c or nil
		end
		local size, center = Kit.size(name)
		local list = Kit.COLL[name]
		local best, area = nil, 0
		if list == nil then
			if size then
				best, area = { size, center }, size.X * size.Z
			end
		else
			for _, q in list do
				local a = q[1].X * q[1].Z
				if q[2].Y + q[1].Y / 2 >= 1 and a > area then
					best, area = q, a
				end
			end
		end
		if not best then
			CR[key] = false
			return nil
		end
		local s, o = best[1], best[2]
		local sx, sy, sz, cx, cz = s.X, s.Y, s.Z, o.X, o.Z
		local top = o.Y + sy / 2
		if sc then
			sx, sz, cx, cz, top = sx * sc.X, sz * sc.Z, cx * sc.X, cz * sc.Z, top * sc.Y
		end
		local ox, od, hx, hz = rot(ry, cx, cz, sx / 2, sz / 2)
		c = { ox = ox, od = od, hx = hx, hz = hz, top = top }
		CR[key] = c
		return c
	end
	T.footprint = footprint

	-- ── frames ───────────────────────────────────────────────────────────────────────────────────────────
	local Frame = {}
	Frame.__index = Frame
	local EDGE = 0.1
	local WALLRY = { B = 0, F = 180, L = -90, R = 90 }
	local DOORRY = { F = 0, B = 180, R = -90, L = 90 }
	T.WALLRY = WALLRY

	-- the floor in front of an opening of the shell (9 studs in, the width of the opening and a little more) stays free
	local function keepOut(f, e)
		local px, pz = e.pos.X - O.X, e.pos.Z - O.Z
		local w = e.width / 2 + 1.5
		local dir = INWARD[e.side] or { 0, 0 }
		if dir[1] ~= 0 then
			f:reserveMap(math.min(px - dir[1] * 1.5, px + dir[1] * 9), pz - w, math.max(px - dir[1] * 1.5, px + dir[1] * 9), pz + w)
		else
			f:reserveMap(px - w, math.min(pz - dir[2] * 1.5, pz + dir[2] * 9), px + w, math.max(pz - dir[2] * 1.5, pz + dir[2] * 9))
		end
	end

	-- o.cframe / o.size / o.id: a stock room or a part of a unit; o.noEntrances: leave the unit's openings out
	function T.frame(u, o)
		o = o or {}
		local f = setmetatable({}, Frame)
		f.u = u
		f.id = o.id or u.id
		f.cf = o.cframe or u.cframe
		local size = o.size or u.size
		f.W, f.H, f.D = size.X, size.Y, size.Z
		f.hw = f.W / 2
		f.y0 = f.cf.Position.Y
		f.occ, f.recs = {}, {}
		-- the lowest ceiling above the floor, where the lamps hang
		f.ceil = f.H
		if u.ceilMin and u.ceilMin > 0 then
			f.ceil = math.min(f.H, u.ceilMin - (u.floorY or FLOORY))
		end
		f.model = kit.model(f.id, root)
		f.rng = Random.new(hashId(f.id))
		f.cnt = { props = 0, parts = 0, cont = 0, loose = 0, lamps = 0, doors = 0 }
		f.contN = 0
		T.frames[#T.frames + 1] = f
		-- the map-local rectangle of the frame, to pick the shell's obstacles
		local a = f.cf:PointToWorldSpace(Vector3.new(-f.hw, 0, -f.D / 2))
		local b = f.cf:PointToWorldSpace(Vector3.new(f.hw, 0, f.D / 2))
		local mx0, mx1 = math.min(a.X, b.X) - O.X - 1, math.max(a.X, b.X) - O.X + 1
		local mz0, mz1 = math.min(a.Z, b.Z) - O.Z - 1, math.max(a.Z, b.Z) - O.Z + 1
		f.cols = {} -- the square columns of the hall: { x, d } in unit coordinates
		for _, r in obs do
			if r[1] < mx1 and r[3] > mx0 and r[2] < mz1 and r[4] > mz0 then
				f:reserveMap(r[1], r[2], r[3], r[4])
				local w, h = r[3] - r[1], r[4] - r[2]
				if w > 3 and w < 4.2 and h > 3 and h < 4.2 then
					local cx, cd = f:local2((r[1] + r[3]) / 2, (r[2] + r[4]) / 2)
					if cx > -f.hw and cx < f.hw and cd > 0 and cd < f.D then
						f.cols[#f.cols + 1] = { cx, cd }
					end
				end
			end
		end
		if not o.noEntrances then
			-- the other units inside this one (the back-of-house blocks of an anchor, the security room of KASSA)
			for vid, v in B.units do
				local r = v.rect
				if vid ~= u.id and v.level == 1 and r and r.x0 >= mx0 + 0.7 and r.x1 <= mx1 - 0.7 and r.z0 >= mz0 + 0.7 and r.z1 <= mz1 - 0.7 then
					f:reserveMap(r.x0 - 0.5, r.z0 - 0.5, r.x1 + 0.5, r.z1 + 0.5)
				end
			end
			-- the openings that lead in: all of the unit's own for a whole unit; for a part of one (a stock room) or another unit (the
			-- dock doors in the outer wall of a stock block belong to the anchor) those on its edge that open into it
			for vid, v in B.units do
				if v.level == 1 then
					for _, e in v.entrances or {} do
						if vid == u.id and not o.cframe then
							keepOut(f, e)
						else
							local dir = INWARD[e.side]
							local px, pz = e.pos.X - O.X, e.pos.Z - O.Z
							if dir and px > mx0 - 2 and px < mx1 + 2 and pz > mz0 - 2 and pz < mz1 + 2 then
								local ix, iz, ox, oz = px + dir[1] * 4, pz + dir[2] * 4, px - dir[1] * 4, pz - dir[2] * 4
								local inIn = ix > mx0 + 1 and ix < mx1 - 1 and iz > mz0 + 1 and iz < mz1 - 1
								local outIn = ox > mx0 and ox < mx1 and oz > mz0 and oz < mz1
								if inIn and not outIn then
									keepOut(f, e)
								end
							end
						end
					end
				end
			end
		end
		return f
	end

	function Frame:pos(x, h, d)
		return self.cf * Vector3.new(x, h, d - self.D / 2)
	end
	function Frame:cfAt(x, h, d, ry)
		return self.cf * CFrame.new(x, h, d - self.D / 2) * CFrame.Angles(0, math.rad(ry or 0), 0)
	end
	function Frame:local2(wx, wz) -- map-local (x, z) -> unit coordinates
		local p = self.cf:PointToObjectSpace(Vector3.new(O.X + wx, self.y0, O.Z + wz))
		return p.X, p.Z + self.D / 2
	end
	function Frame:reserve(x0, d0, x1, d1)
		self.occ[#self.occ + 1] = { x0, d0, x1, d1 }
	end
	function Frame:reserveMap(ax, az, bx, bz)
		local x0, d0 = self:local2(ax, az)
		local x1, d1 = self:local2(bx, bz)
		self:reserve(math.min(x0, x1), math.min(d0, d1), math.max(x0, x1), math.max(d0, d1))
	end
	function Frame:free(x0, d0, x1, d1, pad)
		pad = pad or 0
		if x0 < -self.hw + EDGE or x1 > self.hw - EDGE or d0 < EDGE or d1 > self.D - EDGE then
			return false
		end
		local occ = self.occ
		for i = 1, #occ do
			local r = occ[i]
			if x0 - pad < r[3] - 0.01 and x1 + pad > r[1] + 0.01 and d0 - pad < r[4] - 0.01 and d1 + pad > r[2] + 0.01 then
				return false
			end
		end
		return true
	end
	local function reject(f, what, x, d)
		n.rejected += 1
		if #T.rejects < 60 then
			T.rejects[#T.rejects + 1] = string.format("%s %s (%.0f, %.0f)", f.id, what, x, d)
		end
	end

	-- a kit prop whose footprint is centred on (x, d); false in o.quiet leaves a blocked spot unreported
	function Frame:at(name, x, d, ry, o)
		o = o or {}
		ry = ry or 0
		local fp = footprint(name, ry, o.sc)
		if not fp then
			warn("[ZR] Meridian stores: no kit prop " .. tostring(name))
			return nil
		end
		local x0, x1, d0, d1 = x - fp.hx, x + fp.hx, d - fp.hz, d + fp.hz
		if not o.over and not self:free(x0, d0, x1, d1, o.pad) then
			if not o.quiet then
				reject(self, name, x, d)
			end
			return nil
		end
		pace()
		local cf = self:cfAt(x - fp.ox, o.h or 0, d - fp.od, ry)
		local opts = { shadows = false }
		if o.sc then
			opts.scale = o.sc
		end
		if o.tint then
			opts.tint = o.tint
		end
		if o.collide ~= nil then
			opts.collide = o.collide
		end
		local m = Kit.place(self.model, name, cf, opts)
		if not m then
			return nil
		end
		n.props += 1
		self.cnt.props += 1
		for _, c in m:GetChildren() do
			if c.Name == "KitCollider" then
				n.colliders += 1
			else
				n.pieces += 1
			end
		end
		local rec = { m = m, name = name, x = x, d = d, ry = ry, x0 = x0, d0 = d0, x1 = x1, d1 = d1, cf = cf, f = self }
		local cr = colRect(name, ry, o.sc)
		if cr then
			local cx, cd = x - fp.ox + cr.ox, d - fp.od + cr.od
			rec.cr = { cx - cr.hx, cd - cr.hz, cx + cr.hx, cd + cr.hz, top = cr.top + (o.h or 0) }
		end
		if not o.over and not o.free then
			self.occ[#self.occ + 1] = { x0, d0, x1, d1 }
		end
		self.recs[#self.recs + 1] = rec
		return rec
	end

	-- a prop against a wall (side B back, F front, L left, R right) with its centre at `along`, facing into the room
	function Frame:wall(name, side, along, o)
		o = o or {}
		local ry = WALLRY[side]
		local fp = footprint(name, ry, o.sc)
		if not fp then
			return nil
		end
		local gap = o.gap or 0.15
		local x, d
		if side == "B" then
			x, d = along, self.D - gap - fp.hz
		elseif side == "F" then
			x, d = along, gap + fp.hz
		elseif side == "L" then
			x, d = -self.hw + gap + fp.hx, along
		else
			x, d = self.hw - gap - fp.hx, along
		end
		return self:at(name, x, d, ry, o)
	end

	-- props side by side from a0 to a1 along a wall (side B/F/L/R, `inset` studs off it) or, with side "x" / "d", along a line
	-- at depth / x `inset`: name may be a list (picked at random, all of one width); o.gap spaces them, o.skip leaves out every
	-- n-th, o.limit stops after that many; the list of placed ones comes back
	function Frame:run(name, side, a0, a1, ry, o)
		o = o or {}
		local names = type(name) == "table" and name or { name }
		local wall = WALLRY[side] ~= nil
		local r = ry
		if wall then
			r = WALLRY[side]
		end
		local fp0 = footprint(names[1], r or 0, o.sc)
		if not fp0 then
			return {}
		end
		local alongX = (side == "B" or side == "F" or side == "x")
		local len = alongX and fp0.hx * 2 or fp0.hz * 2
		local gap = o.gap or 0
		local out = {}
		local a, k = a0, 0
		local q = table.clone(o)
		q.quiet = true
		while a + len <= a1 + 0.01 do
			k += 1
			local nm = names[1]
			if #names > 1 then
				nm = names[self.rng:NextInteger(1, #names)]
			end
			local c = a + len / 2
			local rec = nil
			if not (o.skip and k % o.skip == 0) then
				if wall then
					rec = self:wall(nm, side, c, q)
				elseif side == "x" then
					rec = self:at(nm, c, o.inset or 0, r, q)
				else
					rec = self:at(nm, o.inset or 0, c, r, q)
				end
			end
			if rec then
				out[#out + 1] = rec
				if o.limit and #out >= o.limit then
					break
				end
			end
			a += len + gap
		end
		return out
	end

	-- rows of the same prop along x at depths d0, d0 + pitch, ... (n rows), each from x0 to x1
	function Frame:rows(name, x0, x1, d0, nRows, pitch, ry, o)
		local out = {}
		for i = 0, nRows - 1 do
			local o2 = table.clone(o or {})
			o2.inset = d0 + i * pitch
			for _, rec in self:run(name, "x", x0, x1, ry, o2) do
				out[#out + 1] = rec
			end
		end
		return out
	end
	-- rows along d at x = x0, x0 + pitch, ... (n rows), each from d0 to d1
	function Frame:cols(name, d0, d1, x0, nRows, pitch, ry, o)
		local out = {}
		for i = 0, nRows - 1 do
			local o2 = table.clone(o or {})
			o2.inset = x0 + i * pitch
			for _, rec in self:run(name, "d", d0, d1, ry, o2) do
				out[#out + 1] = rec
			end
		end
		return out
	end

	-- the first free spot of a list { { x, d, ry }, ... }
	function Frame:first(name, cands, o)
		local q = table.clone(o or {})
		q.quiet = true
		for _, c in cands do
			local rec = self:at(name, c[1], c[2], c[3] or 0, q)
			if rec then
				return rec
			end
		end
		reject(self, name, cands[1][1], cands[1][2])
		return nil
	end

	-- ── plain boxes and rooms ─────────────────────────────────────────────────────────────────────────────
	-- a box from its unit rectangle and heights; solid ones take their floor space unless o.occupy == false
	function Frame:box(x0, d0, x1, d1, h0, h1, color, mat, o)
		o = o or {}
		if x1 - x0 < 0.02 or d1 - d0 < 0.02 or h1 - h0 < 0.02 then
			return nil
		end
		pace()
		local cf = self:cfAt((x0 + x1) / 2, (h0 + h1) / 2, (d0 + d1) / 2, 0)
		local p = kit.boxCF(self.model, x1 - x0, h1 - h0, d1 - d0, cf, color, mat or M.SmoothPlastic)
		p.CastShadow = false
		p.CanTouch = false
		p:SetAttribute("NoDetail", true)
		if o.name then
			p.Name = o.name
		end
		if o.ghost then
			p.CanCollide = false
			p.CanQuery = false
		elseif o.occupy ~= false and h0 < 9 then
			self.occ[#self.occ + 1] = { x0, d0, x1, d1 }
		end
		n.parts += 1
		self.cnt.parts += 1
		return p
	end
	-- a free-standing run of cheap shelving: a body with two coloured bands for the goods on both faces (3 parts), from a0 to a1 along
	-- x ("x" at depth `at`) or along d ("d" at x `at`); returns false when the space is not free
	function Frame:shelf(axis, at, a0, a1, o)
		o = o or {}
		local depth, h = o.depth or 3.6, o.h or 6.4
		local x0, x1, d0, d1
		if axis == "x" then
			x0, x1, d0, d1 = a0, a1, at - depth / 2, at + depth / 2
		else
			x0, x1, d0, d1 = at - depth / 2, at + depth / 2, a0, a1
		end
		if not self:free(x0, d0, x1, d1, o.pad) then
			return false
		end
		self:box(x0, d0, x1, d1, 0, h, o.body or PAL.shelf, M.Metal, { name = "Shelf" })
		local cols = o.goods or { PAL.red, PAL.blue, PAL.yellow, PAL.green, PAL.card }
		local e = 0.25
		for k = 1, 2 do
			local c = cols[self.rng:NextInteger(1, #cols)]
			local y = 0.9 + (k - 1) * 2.4
			self:box(x0 - (axis == "d" and e or 0), d0 - (axis == "x" and e or 0), x1 + (axis == "d" and e or 0), d1 + (axis == "x" and e or 0), y, y + 1.7, c, M.Fabric, { occupy = false, name = "Goods" })
		end
		return true
	end

	-- a walled room: walls of height h (thickness t) on the outer rectangle, a plate on top, openings on a side (F/B/L/R) at
	-- centre c of width w and height dh. Walls take their floor space.
	function Frame:room(x0, d0, x1, d1, h, opens, o)
		o = o or {}
		local t = o.t or 0.8
		local col, mat = o.color or PAL.plaster, o.mat or M.Plaster
		local function wallRun(side, a0, a1)
			local list = {}
			for _, op in opens or {} do
				if op.side == side then
					list[#list + 1] = op
				end
			end
			table.sort(list, function(p, q)
				return p.c < q.c
			end)
			local cur = a0
			local function seg(p, q, lo, hi)
				if q - p < 0.02 then
					return
				end
				if side == "F" then
					self:box(p, d0, q, d0 + t, lo, hi, col, mat, { name = "Wall" })
				elseif side == "B" then
					self:box(p, d1 - t, q, d1, lo, hi, col, mat, { name = "Wall" })
				elseif side == "L" then
					self:box(x0, p, x0 + t, q, lo, hi, col, mat, { name = "Wall" })
				else
					self:box(x1 - t, p, x1, q, lo, hi, col, mat, { name = "Wall" })
				end
			end
			for _, op in list do
				seg(cur, op.c - op.w / 2, 0, h)
				seg(op.c - op.w / 2, op.c + op.w / 2, op.h or 8.6, h)
				cur = op.c + op.w / 2
			end
			seg(cur, a1, 0, h)
		end
		wallRun("F", x0, x1)
		wallRun("B", x0, x1)
		wallRun("L", d0 + t, d1 - t)
		wallRun("R", d0 + t, d1 - t)
		if o.roof ~= false then
			self:box(x0, d0, x1, d1, h, h + 0.5, col, mat, { occupy = false, name = "Ceiling" })
		end
	end

	-- ── containers, loose loot, doors, lamps ────────────────────────────────────────────────────────────────
	local LOOK = {
		register = "Checkout", cooler = "Fridge", weaponbox = "AmmoCrate", toolbox = "ToolChest", crate = "PalletBoxes",
		locker = "Locker", techbox = "TechTable", pharmacy = "MedShelf", jacket = "ClothesRack", grocery = "Gondola",
	}
	local WORLD = { safe = { 3.2, 2.8 }, drawer = { 5.2, 2.8 } } -- stand-ins the world builds itself (x, z extents)
	T.LOOK = LOOK

	-- a medical bag: the kit has none
	function Frame:medbag(x, d, ry)
		local fp = { hx = 1.3, hz = 0.9 }
		if not self:free(x - fp.hx, d - fp.hz, x + fp.hx, d + fp.hz) then
			return nil
		end
		local a = self:box(x - 1.1, d - 0.6, x + 1.1, d + 0.6, 0, 1.3, PAL.olive, M.Fabric, { name = "Medbag" })
		self:box(x - 0.25, d - 0.65, x + 0.25, d + 0.65, 0.2, 1.1, PAL.white, M.SmoothPlastic, { occupy = false })
		return a
	end

	-- a searchable container of this kind: the kit prop it looks like (its collider carries the prompt), the world's own
	-- safe or drawer, or our medical bag; returns the prop record (or true) and registers it
	function Frame:cont(kind, label, x, d, ry, o)
		o = o or {}
		ry = ry or 0
		local prop = o.prop
		if prop == nil then
			prop = LOOK[kind]
		end
		local anchor, rec, cf
		if kind == "medbag" then
			anchor = self:medbag(x, d, ry)
			if not anchor then
				if not o.quiet then
					reject(self, "medbag", x, d)
				end
				return nil
			end
			cf = self:cfAt(x, 0, d, ry)
			rec = { x = x, d = d, x0 = x - 1.1, x1 = x + 1.1, d0 = d - 0.6, d1 = d + 0.6, cr = { x - 1.1, d - 0.6, x + 1.1, d + 0.6, top = 1.3 }, f = self }
		elseif prop then
			rec = self:at(prop, x, d, ry, o)
			if not rec then
				return nil
			end
			anchor = rec.m:FindFirstChild("KitCollider")
			cf = rec.cf
		else
			local z = WORLD[kind] or { 4, 4 }
			local hx, hz = z[1] / 2, z[2] / 2
			if ry == 90 or ry == -90 then
				hx, hz = hz, hx
			end
			if not self:free(x - hx, d - hz, x + hx, d + hz, o.pad) then
				if not o.quiet then
					reject(self, kind, x, d)
				end
				return nil
			end
			self:reserve(x - hx, d - hz, x + hx, d + hz)
			cf = self:cfAt(x, 0, d, ry)
			rec = { x = x, d = d, x0 = x - hx, x1 = x + hx, d0 = d - hz, d1 = d + hz, f = self }
			if kind == "safe" then
				rec.cr = { x - hx, d - hz, x + hx, d + hz, top = 3.2 }
			elseif kind == "drawer" then
				rec.cr = { x - hx, d - hz, x + hx, d + hz, top = 3.0 }
			end
		end
		self.contN += 1
		local id = "MM_L1_" .. shortId(self.id) .. "_C" .. self.contN
		kit.container(self.model, id, kind, label, cf, anchor)
		n.cont += 1
		self.cnt.cont += 1
		T.byKind[kind] = (T.byKind[kind] or 0) + 1
		rec.id = id
		return rec
	end

	-- a container against a wall (side B/F/L/R, its centre at `along`), facing into the room
	local function contDims(kind, prop, ry, sc)
		if kind == "medbag" then
			return 1.3, 0.9
		elseif prop then
			local fp = footprint(prop, ry, sc)
			return fp.hx, fp.hz
		end
		local z = WORLD[kind] or { 4, 4 }
		if ry == 90 or ry == -90 then
			return z[2] / 2, z[1] / 2
		end
		return z[1] / 2, z[2] / 2
	end
	T.contDims = contDims
	function Frame:contWall(kind, label, side, along, o)
		o = o or {}
		local ry = WALLRY[side]
		local prop = o.prop
		if prop == nil then
			prop = LOOK[kind]
		end
		local hx, hz = contDims(kind, prop, ry, o.sc)
		local gap = o.gap or 0.2
		local x, d
		if side == "B" then
			x, d = along, self.D - gap - hz
		elseif side == "F" then
			x, d = along, gap + hz
		elseif side == "L" then
			x, d = -self.hw + gap + hx, along
		else
			x, d = self.hw - gap - hx, along
		end
		return self:cont(kind, label, x, d, ry, o)
	end
	-- `count` containers of a kind against random walls (o.sides, o.x0 / o.x1 along the back, o.d0 / o.d1 along the sides);
	-- spots that are taken are skipped quietly; returns how many stand
	function Frame:scatter(kind, label, count, o)
		o = table.clone(o or {})
		o.quiet = true
		local sides = o.sides or ((self.D >= 24) and { "B", "B", "L", "R" } or { "B" })
		local a0, a1 = o.x0 or (-self.hw + 4), o.x1 or (self.hw - 4)
		local b0, b1 = o.d0 or 8, o.d1 or (self.D - 5)
		local placed, tries = 0, 0
		while placed < count and tries < count * 14 do
			tries += 1
			local side = sides[self.rng:NextInteger(1, #sides)]
			local along = nil
			if side == "B" or side == "F" then
				along = a0 + self.rng:NextNumber() * (a1 - a0)
			else
				along = b0 + self.rng:NextNumber() * (b1 - b0)
			end
			if self:contWall(kind, label, side, along, o) then
				placed += 1
			end
		end
		if placed < count then
			reject(self, kind .. " x" .. (count - placed), 0, 0)
		end
		return placed
	end
	-- loose loot on up to nMax of the counters and tables already placed
	local SURFACE = {
		Counter = true, Checkout = true, DisplayTable = true, TechTable = true, Table = true, Bench = true, FoodTable = true,
		OfficeDesk = true, GunBench = true, CraftBench = true, JewelCase = true,
	}
	function Frame:surfaces(pool, nMax, chance)
		local list = {}
		for _, r in self.recs do
			if SURFACE[r.name] and r.cr then
				list[#list + 1] = r
			end
		end
		local placed = 0
		while placed < nMax and #list > 0 do
			local i = self.rng:NextInteger(1, #list)
			placed += self:top(list[i], pool, chance, 1)
			table.remove(list, i)
		end
		return placed
	end

	-- a container made of a prop already placed (its collider carries the prompt)
	function Frame:adopt(rec, kind, label)
		local anchor = rec and rec.m and rec.m:FindFirstChild("KitCollider")
		if not anchor then
			return nil
		end
		self.contN += 1
		local id = "MM_L1_" .. shortId(self.id) .. "_C" .. self.contN
		kit.container(self.model, id, kind, label, rec.cf, anchor)
		n.cont += 1
		self.cnt.cont += 1
		T.byKind[kind] = (T.byKind[kind] or 0) + 1
		rec.id = id
		return rec
	end
	-- `count` containers of a kind at random free spots of a rectangle (not against a wall)
	function Frame:spread(kind, label, count, x0, x1, d0, d1, o)
		o = table.clone(o or {})
		o.quiet = true
		local ry = o.ry
		local placed, tries = 0, 0
		while placed < count and tries < count * 20 do
			tries += 1
			local x = x0 + self.rng:NextNumber() * (x1 - x0)
			local d = d0 + self.rng:NextNumber() * (d1 - d0)
			local r = ry
			if r == nil then
				r = self.rng:NextInteger(0, 3) * 90 - 90
			end
			if self:cont(kind, label, x, d, r, o) then
				placed += 1
			end
		end
		if placed < count then
			reject(self, kind .. " x" .. (count - placed), (x0 + x1) / 2, (d0 + d1) / 2)
		end
		return placed
	end
	-- the column line (x or d) nearest above `lo` within [lo, hi], or nil
	function Frame:colLine(axis, lo, hi)
		local best = nil
		for _, c in self.cols do
			local v = (axis == "x") and c[1] or c[2]
			if v >= lo - 0.5 and v <= hi and (best == nil or v < best) then
				best = v
			end
		end
		return best
	end

	-- a loose loot spot at (x, d), h above the floor (the world drops it onto the surface below)
	function Frame:spot(x, d, h, pool, chance)
		local p = self:pos(x, h, d)
		kit.loose(p.X, p.Y, p.Z, pool, chance or 0.4, "meridian", true)
		n.loose += 1
		self.cnt.loose += 1
	end
	-- loose loot on the top of a prop (its collider); k spots
	function Frame:top(rec, pool, chance, k)
		local cr = rec and rec.cr
		if not cr then
			return 0
		end
		local placed = 0
		for _ = 1, k or 1 do
			local w, l = cr[3] - cr[1], cr[4] - cr[2]
			local x = cr[1] + 0.5 + self.rng:NextNumber() * math.max(0, w - 1)
			local d = cr[2] + 0.5 + self.rng:NextNumber() * math.max(0, l - 1)
			self:spot(x, d, cr.top + 0.12, pool, chance)
			placed += 1
		end
		return placed
	end
	-- loose loot on the floor beside props already placed (a free patch 1.4 studs off a side)
	function Frame:litter(count, pool, chance)
		local placed, tries = 0, 0
		local recs = self.recs
		while placed < count and tries < count * 16 + 10 and #recs > 0 do
			tries += 1
			local r = recs[self.rng:NextInteger(1, #recs)]
			local side = self.rng:NextInteger(1, 4)
			local t = self.rng:NextNumber()
			local x, d
			if side == 1 then
				x, d = r.x0 - 1.4, r.d0 + t * (r.d1 - r.d0)
			elseif side == 2 then
				x, d = r.x1 + 1.4, r.d0 + t * (r.d1 - r.d0)
			elseif side == 3 then
				x, d = r.x0 + t * (r.x1 - r.x0), r.d0 - 1.4
			else
				x, d = r.x0 + t * (r.x1 - r.x0), r.d1 + 1.4
			end
			if self:free(x - 0.7, d - 0.7, x + 0.7, d + 0.7, 0.3) then
				self:spot(x, d, 0.15, pool, chance)
				placed += 1
			end
		end
		return placed
	end

	-- a hinged door on a wall line at (x, d): the leaf swings toward `swing` (F front, B back, L -x, R +x); wd wide, h high
	function Frame:door(id, label, x, d, swing, wd, h, key, o)
		o = o or {}
		h = h or 8.6
		local cf = self:cfAt(x, h / 2, d, DOORRY[swing])
		local rec = { id = id, cf = cf, size = Vector3.new(wd, h, 0.35), key = key, label = label, parent = self.model, color = o.color or PAL.door }
		if not key then
			rec.openChance = 0.35
		end
		W.doors[id] = rec
		n.doors += 1
		self.cnt.doors += 1
		-- the swing and the walkway either side stay clear
		local hw = wd / 2 + 0.6
		if swing == "B" then
			self:reserve(x - hw, d - 1.2, x + hw, d + wd + 0.6)
		elseif swing == "F" then
			self:reserve(x - hw, d - wd - 0.6, x + hw, d + 1.2)
		elseif swing == "R" then
			self:reserve(x - 1.2, d - hw, x + wd + 0.6, d + hw)
		else
			self:reserve(x - wd - 0.6, d - hw, x + 1.2, d + hw)
		end
		return rec
	end

	-- a ceiling lamp (dead until the power is on); o.h its height above the floor, o.range / o.bright, o.long its length
	function Frame:lamp(x, d, o)
		o = o or {}
		local top = self.ceil
		local h = o.h
		if not h then
			if top > 40 then
				h = 26 -- a tall hall: the lamp hangs on a cable
				pace()
				local c = kit.boxCF(self.model, 0.25, top - 0.4 - h, 0.25, self:cfAt(x, (h + top - 0.4) / 2, d, 0), PAL.bars, M.Metal)
				c.CastShadow = false
				c.CanCollide = false
				c.CanTouch = false
				c:SetAttribute("NoDetail", true)
				n.parts += 1
				self.cnt.parts += 1
			else
				h = top - 0.6
			end
		end
		pace()
		local p = kit.boxCF(self.model, o.long or 3.2, 0.35, 0.8, self:cfAt(x, h, d, o.ry or 0), PAL.lampOff, M.SmoothPlastic)
		p.CastShadow = false
		p.CanCollide = false
		p.CanTouch = false
		p:SetAttribute("NoDetail", true)
		local l = kit.light(p, PAL.lampLight, o.range or 40, o.bright or 0.85, false)
		l.Enabled = false
		lamps[#lamps + 1] = { light = l, part = p }
		n.lamps += 1
		n.parts += 1
		self.cnt.lamps += 1
		self.cnt.parts += 1
		return p
	end
	-- lamps in a grid over the free floor: `nx` along x and `nd` along d inside the given rectangle
	function Frame:lamps(nx, nd, o)
		o = o or {}
		local x0, x1 = o.x0 or -self.hw + 4, o.x1 or self.hw - 4
		local d0, d1 = o.d0 or 4, o.d1 or self.D - 4
		for i = 1, nx do
			for j = 1, nd do
				self:lamp(x0 + (x1 - x0) * (i - 0.5) / nx, d0 + (d1 - d0) * (j - 0.5) / nd, o)
			end
		end
	end

	-- a container against the inside of a room's wall `side` (front into the room), centred at `along`
	function Frame:atSide(kind, label, side, r, along, o)
		o = o or {}
		local ry = WALLRY[side]
		local prop = o.prop
		if prop == nil then
			prop = LOOK[kind]
		end
		local hx, hz = contDims(kind, prop, ry, o.sc)
		local x, d
		if side == "B" then
			x, d = along, r[4] - 0.2 - hz
		elseif side == "F" then
			x, d = along, r[2] + 0.2 + hz
		elseif side == "L" then
			x, d = r[1] + 0.2 + hx, along
		else
			x, d = r[3] - 0.2 - hx, along
		end
		return self:cont(kind, label, x, d, ry, o)
	end

	-- the inside of a cash or admin office: safes on the wall facing the door, drawers on the side walls, a desk with a PC.
	-- r = { x0, d0, x1, d1 } inside the walls; o: safes, drawers, desk (label), key spot
	function Frame:fillRoom(r, doorSide, o)
		local far = { L = "R", R = "L", F = "B", B = "F" }
		local side = far[doorSide]
		local horizontal = (side == "B" or side == "F")
		local a0, a1 = r[1], r[3]
		local b0, b1 = r[2], r[4]
		if not horizontal then
			a0, a1, b0, b1 = r[2], r[4], r[1], r[3]
		end
		local safes = o.safes or 2
		for k = 1, safes do
			self:atSide("safe", o.safeLabel or "Safe", side, r, a0 + (a1 - a0) * (k - 0.5) / safes, { quiet = true })
		end
		local adj = horizontal and { "L", "R" } or { "F", "B" }
		for k = 1, o.drawers or 2 do
			local s = adj[(k - 1) % 2 + 1]
			local along = (s == "L" or s == "R") and (r[2] + (r[4] - r[2]) * (0.35 + 0.3 * ((k - 1) // 2 % 2))) or (r[1] + (r[3] - r[1]) * (0.35 + 0.3 * ((k - 1) // 2 % 2)))
			self:atSide("drawer", o.drawerLabel or "Drawer", s, r, along, { quiet = true })
		end
		local cx, cd = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
		local desk = nil
		if o.desk then
			desk = self:cont("techbox", o.desk, cx, cd, horizontal and 0 or 90, { prop = "OfficeDesk", quiet = true })
			if desk then
				self:at("Chair", cx + (horizontal and 0 or -3.4), cd + (horizontal and -3.4 or 0), horizontal and 180 or -90, { quiet = true })
				self:top(desk, "office", 0.5, 1)
				self:top(desk, "mallkeys", o.keyChance or 0.12, 1)
			end
		end
		if o.locker then
			self:atSide("locker", "Locker", adj[1], r, (adj[1] == "L" or adj[1] == "R") and r[2] + 4 or r[1] + 4, { quiet = true })
		end
		self:litter(1, "office", 0.45)
	end

	-- a locked office: a walled room of w x l on the first free candidate { x0, d0, doorSide }, its door `swing`ing in
	function Frame:office(o)
		for _, c in o.cands do
			local x0, d0 = c[1], c[2]
			local x1, d1 = x0 + o.w, d0 + o.l
			if self:free(x0 - 0.5, d0 - 0.5, x1 + 0.5, d1 + 0.5, 3) then
				local side = c[3]
				local t = 0.8
				local dc = (side == "L" or side == "R") and (d0 + d1) / 2 or (x0 + x1) / 2
				self:room(x0, d0, x1, d1, 11.5, { { side = side, c = dc, w = 5.2, h = 8.6 } })
				local dx, dd, swing = nil, nil, nil
				if side == "L" then
					dx, dd, swing = x0 + t / 2, dc, "R"
				elseif side == "R" then
					dx, dd, swing = x1 - t / 2, dc, "L"
				elseif side == "F" then
					dx, dd, swing = dc, d0 + t / 2, "B"
				else
					dx, dd, swing = dc, d1 - t / 2, "F"
				end
				self:door(o.id, o.label, dx, dd, swing, 5.2, 8.6, o.key)
				if o.fill then
					o.fill(self, { x0 + t, d0 + t, x1 - t, d1 - t }, side)
				else
					self:fillRoom({ x0 + t, d0 + t, x1 - t, d1 - t }, side, o)
				end
				self:lamp((x0 + x1) / 2, (d0 + d1) / 2, { h = 10.4, range = 24, bright = 0.8 })
				return true
			end
		end
		warn("[ZR] Meridian stores L1: no room for " .. o.id)
		return false
	end

	-- the sign over the entrance takes the unit's name
	function T.name(u, text)
		u.name = text
		local g = u.signGui
		local lab = g and g:FindFirstChildOfClass("TextLabel")
		if lab then
			lab.Text = text
		end
	end

	function T.report()
		local nu = 0
		for _, f in T.frames do
			nu += 1
		end
		return string.format(
			"%d props (%d pieces, %d colliders), %d own parts, %d containers, %d loose spots, %d doors, %d lamps, %d frames, %d spots refused",
			n.props, n.pieces, n.colliders, n.parts, n.cont, n.loose, n.doors, n.lamps, nu, n.rejected
		)
	end

	return T
end
