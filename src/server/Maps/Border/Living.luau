--!nonstrict
-- Border Yard (Customs layout) living quarters: the two dorm blocks, the fuel stop and the old pumps, the squat, the
-- watchhouse, the army post, the houses, trailer cabins, kiosks, sheds and garages (docs/maps/BORDER_CUSTOMS_BUILD.md,
-- docs/maps/BORDER_YARD.md "Living quarters"). Everything stands on a footprint of Layout.luau (centre, size, yaw, floors,
-- locked rooms, stairs) and is built in that footprint's own frame: u along its width, v along its depth, y above the
-- ground at the centre. Buildings.luau calls this under pcall; each building runs under its own pcall, so one failure
-- leaves the rest standing.
return function(B)
	local kit, W, map, H, Kit, L = B.kit, B.W, B.map, B.H, B.Kit, B.L
	local C, M, hex = kit.C, kit.M, kit.hex
	local ground = B.ground
	local points = B.points
	local CFn, V3 = CFrame.new, Vector3.new
	local rad = math.rad
	local CollectionService = game:GetService("CollectionService")
	local living = kit.model("Living", map)

	local LIMIT = { props = 440, shadows = 20, dorm = 900 } -- dorm: the furniture of the dorm rooms, counted apart from the other buildings' props
	local REJECTS = {}
	local st = { props = 0, dorm = 0, shadows = 0, lights = 0, doors = 0, locked = 0, containers = 0, loose = 0, ok = 0, failed = 0, cut = 0, rejected = 0, noRoom = 0 }
	local DOOR = V3(3.9, 7.4, 0.35)
	local STOREY = 11 -- floor to floor
	local SLAB = 1 -- floor slab thickness

	-- hand the server back now and then so a long build never stalls it (Ground does the same)
	local lastPace = os.clock()
	local function pace()
		if os.clock() - lastPace > 0.03 then
			task.wait()
			lastPace = os.clock()
		end
	end
	-- what the dorm interiors added, by kind (printed once at the end)
	local DC = { rooms = 0, lived = 0, bare = 0, wash = 0, kitchen = 0, doors = 0, props = 0, rejected = 0, bits = 0, fit = 0, panes = 0, frosted = 0, boards = 0, curtains = 0, shards = 0, cracked = 0, open = 0, boarded = 0, band = 0, tiles = 0 }

	local P = {
		panel = hex("A19E92"), panelDk = hex("7A776D"), brick = hex("7D4A3A"), brickDk = hex("5E392D"), plaster = hex("B3AD98"),
		plasterG = hex("8E9A86"), plasterB = hex("8497A3"), plasterY = hex("B9AF88"), lino = hex("4D473E"), tile = hex("7D7A70"),
		ceil = hex("A7A394"), roof = hex("3D4042"), steel = hex("4B5054"), conc = hex("7F8079"), concDk = hex("5F615C"),
		rustRoof = hex("6B4A3C"), timber = hex("6F5A43"), timberDk = hex("4E3F30"), board = hex("8A7C62"), door = hex("6E5E4A"),
		doorDk = hex("4F4A42"), metalGrn = hex("56624F"), metalBlu = hex("4A5C6B"), metalRed = hex("7A4034"), metalGry = hex("6C706D"),
		cloth = hex("6E6A58"), clothRed = hex("7F4A44"), white = hex("C9CCC2"), tar = hex("2E3032"), yellow = hex("C29A38"),
	}

	-- ── the building frame ───────────────────────────────────────────────────────────────────────────────────────────
	local Frame = {}
	Frame.__index = Frame

	local function newFrame(b, name)
		local f = setmetatable({}, Frame)
		f.b = b
		f.id = b[1]
		f.name = name or b[2]
		f.parent = kit.model(f.name, living)
		f.y0 = ground(b[4], b[5])
		f.base = H.CF(b[4], f.y0, b[5], -b[8])
		f.tag = "LV" .. tostring(b[1])
		f.solids = {} -- boxes props must not overlap and loose loot must not start in: { cf, hx, hy, hz }
		f.floors = {} -- floor slab pieces loose loot can drop onto: { cf, hx, hy, hz }
		return f
	end

	-- a CFrame at local (u, y, v), turned by ry degrees about the vertical
	function Frame:cf(u, y, v, ry)
		local c = self.base * CFn(u, y, v)
		if ry and ry ~= 0 then
			c = c * CFrame.Angles(0, rad(ry), 0)
		end
		return c
	end
	function Frame:pt(u, y, v)
		return self.base * V3(u, y, v)
	end
	function Frame:box(su, sy, sv, u, y, v, color, mat, ry)
		return kit.boxCF(self.parent, su, sy, sv, self:cf(u, y, v, ry), color, mat)
	end
	-- a box from local floor y to y + sy (so `y` is the bottom)
	function Frame:blk(su, sy, sv, u, y, v, color, mat, ry)
		local cf = self:cf(u, y + sy / 2, v, ry)
		table.insert(self.solids, { cf = cf, hx = su / 2, hy = sy / 2, hz = sv / 2 })
		return kit.boxCF(self.parent, su, sy, sv, cf, color, mat)
	end
	function Frame:cylV(h, d, u, y, v, color, mat)
		local p = self:pt(u, y, v)
		return kit.vcyl(self.parent, h, d, p.X, p.Y, p.Z, color, mat)
	end

	-- hole list (centre, width, bottom, top) in building coordinates -> wall-relative, sorted, clipped, no overlaps
	local function holesFor(holes, c0, c1, flip, h)
		local mid = (c0 + c1) / 2
		local list = {}
		for _, o in holes or {} do
			local a, b = math.max(o[1] - o[2] / 2, c0), math.min(o[1] + o[2] / 2, c1)
			if b - a > 0.25 then
				table.insert(list, { a, b, o[3], math.min(o[4], h) })
			end
		end
		table.sort(list, function(p, q)
			return p[1] < q[1]
		end)
		local out, last = {}, c0
		for _, o in list do
			local a = math.max(o[1], last)
			if o[2] - a > 0.25 then
				local cen = (a + o[2]) / 2 - mid
				table.insert(out, { flip and -cen or cen, o[2] - a, o[3], o[4] })
				last = o[2]
			end
		end
		return out
	end

	-- a sub-Model of the building that carries a wall finish (the attribute Finish, and Tint: may it take a hue from the list);
	-- walls built into it (the last parameter of wallU / wallV) get that finish from World.applyWear (docs/look/WALLS.md)
	function Frame:finModel(key, finish, tint)
		self.fins = self.fins or {}
		local m = self.fins[key]
		if not m then
			m = kit.model(key, self.parent)
			m:SetAttribute("Finish", finish)
			m:SetAttribute("Tint", tint == true)
			self.fins[key] = m
		end
		return m
	end

	-- a wall along u at v from u0 to u1, foot at y, height h, thickness t; holes { u, width, bottom, top }; into: the Model the
	-- pieces go in (a Frame:finModel), else the building
	function Frame:wallU(v, u0, u1, y, h, t, color, mat, holes, into)
		if u1 - u0 < 0.3 then
			return
		end
		kit.wallHoles(into or self.parent, self.base * CFn((u0 + u1) / 2, y, v), u1 - u0, h, t, color, mat, holesFor(holes, u0, u1, false, h))
		table.insert(self.solids, { cf = self.base * CFn((u0 + u1) / 2, y + h / 2, v), hx = (u1 - u0) / 2, hy = h / 2, hz = t / 2 })
	end
	-- a wall along v at u from v0 to v1; holes { v, width, bottom, top }; into as for wallU
	function Frame:wallV(u, v0, v1, y, h, t, color, mat, holes, into)
		if v1 - v0 < 0.3 then
			return
		end
		kit.wallHoles(into or self.parent, self.base * CFn(u, y, (v0 + v1) / 2) * CFrame.Angles(0, rad(90), 0), v1 - v0, h, t, color, mat, holesFor(holes, v0, v1, true, h))
		table.insert(self.solids, { cf = self.base * CFn(u, y + h / 2, (v0 + v1) / 2) * CFrame.Angles(0, rad(90), 0), hx = (v1 - v0) / 2, hy = h / 2, hz = t / 2 })
	end

	-- a slab (top at yTop) over u0..u1 / v0..v1 with rectangular holes { u0, u1, v0, v1 }
	function Frame:slab(u0, u1, v0, v1, yTop, th, color, mat, holes, wear)
		local us, vs, hs = { u0, u1 }, { v0, v1 }, {}
		for _, h in holes or {} do
			if h[2] > u0 and h[1] < u1 and h[4] > v0 and h[3] < v1 then
				table.insert(hs, h)
				table.insert(us, math.max(h[1], u0))
				table.insert(us, math.min(h[2], u1))
				table.insert(vs, math.max(h[3], v0))
				table.insert(vs, math.min(h[4], v1))
			end
		end
		local function uniq(t)
			table.sort(t)
			local o = {}
			for _, x in t do
				if #o == 0 or math.abs(o[#o] - x) > 1e-4 then
					table.insert(o, x)
				end
			end
			return o
		end
		us, vs = uniq(us), uniq(vs)
		local function inHole(cu, cv)
			for _, h in hs do
				if cu > h[1] and cu < h[2] and cv > h[3] and cv < h[4] then
					return true
				end
			end
			return false
		end
		for i = 1, #us - 1 do
			local a, b = us[i], us[i + 1]
			local run0 = nil
			for j = 1, #vs do
				local solid = j < #vs and not inHole((a + b) / 2, (vs[j] + vs[j + 1]) / 2)
				if solid and not run0 then
					run0 = vs[j]
				elseif not solid and run0 then
					local p = self:box(b - a, th, vs[j] - run0, (a + b) / 2, yTop - th / 2, (run0 + vs[j]) / 2, color, mat)
					table.insert(self.floors, { cf = p.CFrame, hx = (b - a) / 2, hy = th / 2, hz = (vs[j] - run0) / 2 })
					if wear ~= nil then
						p:SetAttribute("Wear", wear)
					end
					run0 = nil
				end
			end
		end
	end

	-- a straight flight: `rise` studs up in two 0.5-stud steps per stud, from (u, v) along dir ("+u" "-u" "+v" "-v") over
	-- `run`, `w` wide; solid down to yBase, or (yBase nil) a 1.5-stud saw-tooth that leaves the space under it open
	function Frame:flight(u, v, y0, rise, run, w, dir, yBase, color, mat)
		local n = math.max(1, math.floor(rise * 2 + 0.5))
		local r = run / n
		-- art-5b: the Kit5 flight (one mesh and a ramp) when the batch is loaded, these steps otherwise
		local du = (dir == "+u" and 1) or (dir == "-u" and -1) or 0
		local dv = (dir == "+v" and 1) or (dir == "-v" and -1) or 0
		local foot = self.base * CFrame.lookAt(V3(u, y0, v), V3(u + du, y0, v + dv))
		if H.k5Flight(self.parent, foot, n, rise / n, r, w, yBase and "C" or "O", color, mat, { base = yBase and (y0 - yBase) or nil }) then
			return
		end
		for k = 1, n do
			local top = y0 + k * rise / n
			local lo = yBase or (top - 1.5)
			local h = top - lo
			local off = (k - 0.5) * r
			local cu, cv, su, sv = u, v, r, w
			if dir == "+u" then
				cu = u + off
			elseif dir == "-u" then
				cu = u - off
			elseif dir == "+v" then
				cv, su, sv = v + off, w, r
			else
				cv, su, sv = v - off, w, r
			end
			self:box(su, h, sv, cu, lo + h / 2, cv, color, mat)
		end
	end

	-- a railing between two local points at deck height y (two bars and end posts)
	function Frame:rail(u0, v0, u1, v1, y, color, mat)
		local a, b = self:pt(u0, y, v0), self:pt(u1, y, v1)
		local len = (b - a).Magnitude
		if len < 0.3 then
			return
		end
		local look = CFrame.lookAt((a + b) / 2, b)
		local col, m = color or P.steel, mat or M.Metal
		if H.k5Rail(self.parent, a, b, col, m) then -- art-5b: the Kit5 railing when the batch is loaded
			return
		end
		kit.boxCF(self.parent, 0.25, 0.25, len, look * CFn(0, 3.3, 0), col, m)
		kit.boxCF(self.parent, 0.18, 0.18, len, look * CFn(0, 1.7, 0), col, m)
		for _, p in { a, b } do
			kit.boxCF(self.parent, 0.3, 3.4, 0.3, CFn(p + V3(0, 1.7, 0)), col, m)
		end
	end

	-- a pitched roof over u0..u1 / v0..v1 whose walls top out at yTop; the ridge runs along `along` ("u" or "v")
	function Frame:gable(u0, u1, v0, v1, yTop, pitch, along, color, mat, gableColor)
		local tp = math.tan(rad(pitch))
		local ov = 1.2
		local cu, cv = (u0 + u1) / 2, (v0 + v1) / 2
		local function P3(u, y, v)
			return self:pt(u, y, v)
		end
		if along == "u" then
			local d, len = v1 - v0, u1 - u0 + 2 * ov
			local rise = (d / 2) * tp
			for _, s in { -1, 1 } do
				local eave = P3(cu, yTop - ov * tp, cv + s * (d / 2 + ov))
				local ridge = P3(cu, yTop + rise, cv)
				kit.boxCF(self.parent, len, 0.5, (ridge - eave).Magnitude + 0.25, CFrame.lookAt((eave + ridge) / 2, ridge) * CFn(0, 0.25, 0), color, mat)
			end
			for _, gu in { u0 + 0.35, u1 - 0.35 } do
				for _, s in { -1, 1 } do
					kit.part(self.parent, V3(0.6, rise, d / 2), self:cf(gu, yTop + rise / 2, cv + s * d / 4, s > 0 and 180 or 0), gableColor, M.WoodPlanks, "WedgePart")
				end
			end
			self:box(len, 0.4, 0.6, cu, yTop + rise + 0.3, cv, gableColor, M.WoodPlanks)
		else
			local d, len = u1 - u0, v1 - v0 + 2 * ov
			local rise = (d / 2) * tp
			for _, s in { -1, 1 } do
				local eave = P3(cu + s * (d / 2 + ov), yTop - ov * tp, cv)
				local ridge = P3(cu, yTop + rise, cv)
				kit.boxCF(self.parent, len, 0.5, (ridge - eave).Magnitude + 0.25, CFrame.lookAt((eave + ridge) / 2, ridge) * CFn(0, 0.25, 0), color, mat)
			end
			for _, gv in { v0 + 0.35, v1 - 0.35 } do
				for _, s in { -1, 1 } do
					kit.part(self.parent, V3(0.6, rise, d / 2), self:cf(cu + s * d / 4, yTop + rise / 2, gv, s > 0 and -90 or 90), gableColor, M.WoodPlanks, "WedgePart")
				end
			end
			self:box(0.6, 0.4, len, cu, yTop + rise + 0.3, cv, gableColor, M.WoodPlanks)
		end
	end

	-- ── things that live in a building: props, lamps, doors, containers, loose loot ──────────────────────────────────
	-- do two yaw-turned boxes overlap by more than `shrink` on every side? (a, b: { cf, hx, hy, hz })
	local function boxesHit(a, b, shrink)
		local ac, bc = a.cf.Position, b.cf.Position
		if math.abs(ac.Y - bc.Y) >= a.hy + b.hy - 2 * shrink then
			return false
		end
		local dx, dz = bc.X - ac.X, bc.Z - ac.Z
		local function axisOf(cf)
			local r = cf.RightVector
			local l = math.sqrt(r.X * r.X + r.Z * r.Z)
			if l < 1e-6 then
				return 1, 0
			end
			return r.X / l, r.Z / l
		end
		local ax, az = axisOf(a.cf)
		local bx, bz = axisOf(b.cf)
		local ahx, ahz = math.max(0, a.hx - shrink), math.max(0, a.hz - shrink)
		local bhx, bhz = math.max(0, b.hx - shrink), math.max(0, b.hz - shrink)
		for _, axis in { { ax, az }, { -az, ax }, { bx, bz }, { -bz, bx } } do
			local x, z = axis[1], axis[2]
			local ea = ahx * math.abs(ax * x + az * z) + ahz * math.abs(-az * x + ax * z)
			local eb = bhx * math.abs(bx * x + bz * z) + bhz * math.abs(-bz * x + bx * z)
			if math.abs(dx * x + dz * z) >= ea + eb then
				return false
			end
		end
		return true
	end
	-- the horizontal centre and the radius of the circle round a solid, worked out once: the quick reject of the tests below
	local function bound(s)
		local r = s.r
		if not r then
			local p = s.cf.Position
			s.px, s.pz = p.X, p.Z
			r = math.sqrt(s.hx * s.hx + s.hz * s.hz)
			s.r = r
		end
		return s.px, s.pz, r
	end
	function Frame:hits(box, shrink)
		local bp = box.cf.Position
		local br = math.sqrt(box.hx * box.hx + box.hz * box.hz)
		for _, s in self.solids do
			local sx, sz, sr = bound(s)
			local dx, dz, rr = sx - bp.X, sz - bp.Z, sr + br
			if dx * dx + dz * dz < rr * rr and boxesHit(box, s, shrink or 0.15) then
				return true
			end
		end
		return false
	end
	-- would a ray dropped from 2.5 above p start inside something solid of this building?
	function Frame:blocked(p)
		local o = p + V3(0, 2.5, 0)
		for _, s in self.solids do
			local sx, sz, sr = bound(s)
			local dx, dz, rr = sx - o.X, sz - o.Z, sr + 0.5
			if dx * dx + dz * dz < rr * rr then
				local l = s.cf:PointToObjectSpace(o)
				if math.abs(l.X) < s.hx + 0.3 and math.abs(l.Z) < s.hz + 0.3 and math.abs(l.Y) < s.hy + 0.1 then
					return true
				end
			end
		end
		return false
	end

	-- a kit prop (front along -z of its frame); indoor props cast no shadow. A prop whose collider would overlap a wall or
	-- another prop is not placed (nil); opts.overlap = true skips the test
	function Frame:prop(name, u, y, v, ry, opts)
		if st.props >= LIMIT.props then
			st.cut += 1
			return nil
		end
		opts = opts or {}
		if opts.shadows == nil then
			opts.shadows = false
		end
		local m = Kit.place(self.parent, name, self:cf(u, y, v, ry), opts)
		if not m then
			return nil
		end
		local cols = {}
		for _, c in m:GetChildren() do
			if c.Name == "KitCollider" then
				table.insert(cols, { cf = c.CFrame, hx = c.Size.X / 2, hy = c.Size.Y / 2, hz = c.Size.Z / 2 })
			end
		end
		if not opts.overlap then
			for _, c in cols do
				if self:hits(c, 0.15) then
					m:Destroy()
					st.rejected += 1
					if #REJECTS < 40 then
						table.insert(REJECTS, string.format("%s %s (%.1f, %.1f)", self.name, name, u, v))
					end
					return nil
				end
			end
		end
		for _, c in cols do
			table.insert(self.solids, c)
		end
		st.props += 1
		return m
	end

	-- a kit prop of the dorm rooms, given as a CFrame: as Frame:prop, but counted in its own pool (LIMIT.dorm) so the dorms never
	-- use up the other buildings' share, and a prop that would overlap a wall or another prop is dropped without a word
	function Frame:dprop(name, cf, opts)
		if st.dorm >= LIMIT.dorm then
			st.cut += 1
			return nil
		end
		opts = opts or {}
		if opts.shadows == nil then
			opts.shadows = false
		end
		local m = Kit.place(self.parent, name, cf, opts)
		if not m then
			return nil
		end
		local cols = {}
		for _, c in m:GetChildren() do
			if c.Name == "KitCollider" then
				table.insert(cols, { cf = c.CFrame, hx = c.Size.X / 2, hy = c.Size.Y / 2, hz = c.Size.Z / 2 })
			end
		end
		for _, c in cols do
			if self:hits(c, 0.15) then
				m:Destroy()
				DC.rejected += 1
				return nil
			end
		end
		for _, c in cols do
			table.insert(self.solids, c)
		end
		st.dorm += 1
		DC.props += 1
		return m
	end

	-- a small or thin loose piece (clutter, curtains, glass, partitions, fittings) with its bottom at y. It has no collision, no
	-- ray hits and no touch unless asked: o.collide, o.query, or o.solid (both, and a place among the building's solids). It
	-- casts no shadow unless a side is 3 studs or more (o.shadow = false even then). o.alpha: transparency, o.roll / o.pitch:
	-- tilt in degrees, o.wear: leave it to the detail layer, o.cat: the counter it is added to, o.finish: the wall finish it
	-- takes (a variant name, no hue: its colour stays), o.plain: no worn variant at all
	function Frame:bit(su, sy, sv, u, y, v, color, mat, ry, o)
		o = o or {}
		su, sy, sv = math.max(su, 0.05), math.max(sy, 0.05), math.max(sv, 0.05)
		local cf = self:cf(u, y + sy / 2, v, ry)
		if o.roll or o.pitch then
			cf = cf * CFrame.Angles(rad(o.pitch or 0), 0, rad(o.roll or 0))
		end
		local p = kit.boxCF(self.parent, su, sy, sv, cf, color or P.cloth, mat or M.SmoothPlastic)
		local solid = o.solid == true
		p.CanCollide = solid or o.collide == true
		p.CanQuery = solid or o.query == true
		p.CanTouch = false
		p.CastShadow = (su >= 3 or sy >= 3 or sv >= 3) and o.shadow ~= false
		if o.alpha then
			p.Transparency = o.alpha
		end
		if not o.wear then
			p:SetAttribute("NoDetail", true)
		end
		if o.finish then
			p:SetAttribute("Finish", o.finish)
			p:SetAttribute("Tint", false)
		end
		if o.plain then
			p:SetAttribute("Wear", "")
		end
		if solid then
			table.insert(self.solids, { cf = cf, hx = su / 2, hy = sy / 2, hz = sv / 2 })
		end
		local k = o.cat or "bits"
		DC[k] = (DC[k] or 0) + 1
		return p
	end

	-- is the floor round the world point p (radius r, up to y1 over it) free of anything solid?
	function Frame:clearAt(p, r, y1)
		for _, s in self.solids do
			local sx, sz, sr = bound(s)
			local dx, dz, rr = sx - p.X, sz - p.Z, sr + r
			if dx * dx + dz * dz < rr * rr then
				local c = s.cf.Position
				if c.Y + s.hy > p.Y + 0.05 and c.Y - s.hy < p.Y + y1 then
					local l = s.cf:PointToObjectSpace(p)
					if math.abs(l.X) < s.hx + r and math.abs(l.Z) < s.hz + r then
						return false
					end
				end
			end
		end
		return true
	end

	-- a ceiling lamp (a flat Neon panel with a light); only `big` rooms get a shadow-casting light, up to the cap
	function Frame:lamp(u, y, v, range, big)
		local head = self:box(2.2, 0.3, 0.9, u, y, v, hex("FFE2B0"), M.Neon)
		head.CastShadow = false
		local sh = false
		if big and st.shadows < LIMIT.shadows then
			sh = true
			st.shadows += 1
		end
		kit.light(head, hex("FFD3A0"), range or 26, 1, sh)
		st.lights += 1
		return head
	end

	-- a hinged door slab in a wall: axis "u" = the wall runs along u (door at u = a, wall at v = c), "v" = along v;
	-- swing +1/-1 = which way along the other axis it opens
	function Frame:door(id, label, axis, a, c, y, swing, key, color, openChance)
		local cf
		if axis == "u" then
			cf = self:cf(a, y + 3.75, c, swing > 0 and 180 or 0)
		else
			cf = self:cf(c, y + 3.75, a, swing > 0 and -90 or 90)
		end
		W.doors[id] = { id = id, cf = cf, size = DOOR, key = key, label = label, parent = self.parent, color = color or P.door, openChance = openChance }
		st.doors += 1
		if key then
			st.locked += 1
		end
	end

	-- loose loot: dropped on the surface under (u, y, v); a spot whose drop ray would start inside a prop or wall moves aside
	local RING = { { 0, 0 }, { 1.5, 0 }, { -1.5, 0 }, { 0, 1.5 }, { 0, -1.5 }, { 2.5, 2.5 }, { -2.5, 2.5 }, { 2.5, -2.5 }, { -2.5, -2.5 }, { 3.5, 0 }, { -3.5, 0 }, { 0, 3.5 }, { 0, -3.5 } }
	-- is there a surface for the world's drop ray (from 2.5 above p, 7 studs down) to land on: a slab, a prop or the ground?
	function Frame:supported(p)
		local o = p + V3(0, 2.5, 0)
		for _, list in { self.floors, self.solids } do
			for _, s in list do
				local sx, sz, sr = bound(s)
				local dx, dz, rr = sx - o.X, sz - o.Z, sr + 0.01
				if dx * dx + dz * dz <= rr * rr then
					local l = s.cf:PointToObjectSpace(o)
					local top = s.cf.Position.Y + s.hy
					if math.abs(l.X) <= s.hx and math.abs(l.Z) <= s.hz and top <= o.Y and o.Y - top <= 7 then
						return true
					end
				end
			end
		end
		local gy = ground(p.X - B.O.X, p.Z - B.O.Z)
		return gy <= o.Y and o.Y - gy <= 7
	end
	function Frame:loose(u, y, v, pool, chance, quiet)
		for _, o in RING do
			local p = self:pt(u + o[1], y, v + o[2])
			if not self:blocked(p) and self:supported(p) then
				kit.loose(p.X, p.Y, p.Z, pool, chance or 0.4, "border", true)
				st.loose += 1
				return true
			end
		end
		if not quiet then
			st.noRoom += 1
		end
		return false
	end

	-- a searchable container; `anchor` is an existing prop part (a locker, a desk) or nil for the default stand-in
	local STANDIN = { safe = { 3, 3.2, 2.6 }, locker = { 3, 7, 2.2 }, drawer = { 5, 3, 2.6 }, crate = { 4, 4, 4 } }
	function Frame:container(id, kind, label, u, y, v, ry, anchor)
		if not anchor then
			-- the world builds its own stand-in; keep its box out of the way of props and loot
			local z = STANDIN[kind] or STANDIN.crate
			table.insert(self.solids, { cf = self:cf(u, y + z[2] / 2, v, ry), hx = z[1] / 2, hy = z[2] / 2, hz = z[3] / 2 })
		end
		kit.container(self.parent, id, kind, label, self:cf(u, y, v, ry), anchor)
		st.containers += 1
	end
	-- a kit prop that is the container (its collider carries the prompt)
	function Frame:stash(prop, id, kind, label, u, y, v, ry, opts)
		local m = self:prop(prop, u, y, v, ry, opts)
		local anchor = m and m:FindFirstChild("KitCollider")
		if not anchor then
			return nil
		end
		self:container(id, kind, label, u, y, v, ry, anchor)
		return m
	end
	-- does a box (su x sy x sv, bottom at y, centred at u, v, turned ry) fit among the walls and props placed so far?
	function Frame:fits(su, sy, sv, u, y, v, ry)
		local ok = not self:hits({ cf = self:cf(u, y + sy / 2, v, ry), hx = su / 2, hy = sy / 2, hz = sv / 2 }, 0.1)
		if not ok then
			st.rejected += 1
			if #REJECTS < 40 then
				table.insert(REJECTS, string.format("%s stand-in (%.1f, %.1f)", self.name, u, v))
			end
		end
		return ok
	end
	-- small visible stand-ins for containers the kit has no prop for (u, v is the centre, y the floor under it)
	function Frame:medbag(id, label, u, y, v, ry)
		if not self:fits(2.2, 1.3, 1.2, u, y, v, ry) then
			return
		end
		local a = self:blk(2.2, 1.3, 1.2, u, y, v, hex("56624F"), M.Fabric, ry)
		self:blk(0.5, 0.9, 1.25, u, y + 0.2, v, P.white, M.SmoothPlastic, ry)
		self:container(id, "medbag", label, u, y, v, ry, a)
	end
	function Frame:toolbox(id, label, u, y, v, ry)
		if not self:fits(2.8, 1.5, 1.3, u, y, v, ry) then
			return
		end
		local a = self:blk(2.8, 1.5, 1.3, u, y, v, P.metalRed, M.Metal, ry)
		self:blk(2.9, 0.15, 1.35, u, y + 1.5, v, P.steel, M.Metal, ry)
		self:container(id, "toolbox", label, u, y, v, ry, a)
	end
	function Frame:gunCase(id, label, u, y, v, ry)
		if not self:fits(4.6, 1.1, 1.7, u, y, v, ry) then
			return
		end
		local a = self:blk(4.6, 1.1, 1.7, u, y, v, hex("2F3331"), M.Metal, ry)
		self:blk(4.7, 0.12, 1.75, u, y + 1.1, v, hex("464B49"), M.Metal, ry)
		self:container(id, "weaponbox", label, u, y, v, ry, a)
	end
	function Frame:jacket(id, label, u, y, v, ry)
		if not self:fits(1.9, 2.6, 0.7, u, y, v, ry) then
			return
		end
		local a = self:blk(1.9, 2.6, 0.7, u, y, v, hex("5B5E46"), M.Fabric, ry)
		self:blk(2.1, 0.3, 0.9, u, y + 2.6, v, P.timberDk, M.Wood, ry)
		self:container(id, "jacket", label, u, y, v, ry, a)
	end

	-- a ring for rooms: a (offset along the door wall from the room centre) and d (depth from the door wall)
	local Room = {}
	Room.__index = Room
	-- f: frame, y: floor top, axis "u"/"v": the door wall runs along, a0: room centre along it, aw: clear width,
	-- d0: door wall position on the other axis, dir: +1/-1 into the room, dp: depth
	local function newRoom(f, y, axis, a0, aw, d0, dir, dp)
		return setmetatable({ f = f, y = y, axis = axis, a0 = a0, aw = aw, d0 = d0, dir = dir, dp = dp }, Room)
	end
	function Room:uv(a, d)
		if self.axis == "u" then
			return self.a0 + a, self.d0 + self.dir * d
		end
		return self.d0 + self.dir * d, self.a0 + a
	end
	-- facing: "in" = toward the far wall, "out" = toward the door wall, "a+" / "a-" = along the wall
	function Room:yaw(face)
		local fu, fv = 0, 0
		if face == "in" or face == "out" then
			local s = (face == "in") and self.dir or -self.dir
			if self.axis == "u" then
				fv = s
			else
				fu = s
			end
		else
			local s = (face == "a+") and 1 or -1
			if self.axis == "u" then
				fu = s
			else
				fv = s
			end
		end
		if fv < 0 then
			return 0
		elseif fu < 0 then
			return 90
		elseif fv > 0 then
			return 180
		end
		return -90
	end
	function Room:prop(name, a, d, face, opts)
		local u, v = self:uv(a, d)
		return self.f:prop(name, u, self.y, v, self:yaw(face), opts)
	end
	function Room:stash(prop, id, kind, label, a, d, face, opts)
		local u, v = self:uv(a, d)
		return self.f:stash(prop, id, kind, label, u, self.y, v, self:yaw(face), opts)
	end
	-- loose loot at (a, d), h over the floor. Something standing there moves it aside (the same ring as Frame:loose), but never out of
	-- the room: a ring that crossed a partition would drop the loot into the next room, where that room's bed is built later
	function Room:loose(a, h, d, pool, chance, quiet)
		local f = self.f
		local hw = self.aw / 2 - 0.9
		for _, o in RING do
			local a2, d2 = a + o[1], d + o[2]
			if math.abs(a2) <= hw and d2 >= 1.2 and d2 <= self.dp - 0.9 then
				local u, v = self:uv(a2, d2)
				local p = f:pt(u, self.y + h, v)
				if not f:blocked(p) and f:supported(p) then
					kit.loose(p.X, p.Y, p.Z, pool, chance or 0.4, "border", true)
					st.loose += 1
					return true
				end
			end
		end
		if not quiet then
			st.noRoom += 1
		end
		return false
	end
	function Room:lamp(a, d, range, big)
		local u, v = self:uv(a, d)
		return self.f:lamp(u, self.y + STOREY - SLAB - 0.4, v, range, big)
	end
	-- a box sa wide along the wall, sd deep, sh high, its bottom at floor + y, centred at (a, d)
	function Room:box(sa, sd, sh, a, y, d, color, mat)
		local u, v = self:uv(a, d)
		if self.axis == "u" then
			return self.f:blk(sa, sh, sd, u, self.y + y, v, color, mat)
		end
		return self.f:blk(sd, sh, sa, u, self.y + y, v, color, mat)
	end

	-- a kit prop placed by the centre of its box at (a, d) of the room: `face` as Room:yaw, opts as Kit.place (scale, tint, mats,
	-- collide) and the dorm furniture pool; nil when it would overlap a wall or another prop
	function Room:bprop(name, a, d, face, opts)
		local size, centre = Kit.size(name)
		if not size then
			return nil
		end
		opts = opts or {}
		local sc = opts.scale or V3(1, 1, 1)
		local u, v = self:uv(a, d)
		local cf = self.f:cf(u, self.y, v, self:yaw(face)) * CFn(-centre.X * sc.X, 0, -centre.Z * sc.Z)
		return self.f:dprop(name, cf, opts)
	end
	-- a Frame:bit given in room terms: sa along the wall, sh high, sd deep, centred at (a, d), bottom y0 over the floor
	function Room:rb(sa, sh, sd, a, y0, d, color, mat, o)
		local u, v = self:uv(a, d)
		if self.axis == "u" then
			return self.f:bit(sa, sh, sd, u, self.y + y0, v, color, mat, 0, o)
		end
		return self.f:bit(sd, sh, sa, u, self.y + y0, v, color, mat, 0, o)
	end

	local function pick(rng, list)
		return list[rng:NextInteger(1, #list)]
	end

	-- ── dorm rooms: what stands in them ──────────────────────────────────────────────────────────────────────────────
	-- R: a room seen from its door (a along the door wall from the centre, d into the room). The first dice of the old
	-- furnishing (door, layout, coat, loose loot) are still thrown for every room at the start, in the old order from the old
	-- seed, so every coat, every desk with drawers and every loose-loot spot stays where it was; what stands in the rooms is
	-- new. All that is new comes from a second seed and from one seed per room, so one room never moves another.
	local TI = 0.8 -- interior partition thickness
	local H10 = STOREY - SLAB

	local D = {
		bedding = { hex("66727F"), hex("7A6C58"), hex("5C6757"), hex("84605A"), hex("8A867A") },
		curtain = { hex("7C5B54"), hex("5F6B73"), hex("8A7F62"), hex("5A6A5A") },
		cloth = { hex("6B5E54"), hex("4F5A63"), hex("7B6F5A"), hex("5A4A46") },
		wood = hex("6A5641"), woodLt = hex("85735A"), glass = hex("A5BDC1"), frost = hex("D4DAD6"),
		tileW = hex("B7BBB0"), tileG = hex("7F8C89"), porc = hex("CFD1C8"), part = hex("7C8A86"),
		paper = hex("C8C4B2"), bottle = hex("5C7A55"), box = hex("8A7456"), water = hex("5E7479"), top = hex("B0A68F"),
	}
	-- the sizes the furniture is stretched to (the kit's beds and lockers are bigger than a dorm's)
	local SC = {
		single = V3(0.55, 1, 0.9), -- Bed 5.6 x 7.4 -> 3.1 x 6.7 studs: one metre by two
		ward = V3(1.4, 0.95, 1.15), -- Locker 1.95 x 7.1 x 2.0 -> 2.7 x 6.7 x 2.3
		desk = V3(0.7, 1, 0.8), -- Table 6 x 3.1 x 3 -> 4.2 x 3.1 x 2.4
		books = V3(0.5, 0.85, 0.8), -- WallShelfBooks 8 x 7.8 x 2.1 -> 4.0 x 6.6 x 1.7
	}
	-- a bunk bed's two decks as colliders (the kit's six, with the posts, leave nothing to lie on)
	local BUNK_COLL = { { V3(6.9, 1.6, 2.9), V3(0, 0.8, 0) }, { V3(6.9, 0.5, 2.9), V3(0, 4.35, 0) } }

	local function shuffled(list, rx)
		local t = {}
		for i, v in list do
			t[i] = v
		end
		for i = #t, 2, -1 do
			local j = rx:NextInteger(1, i)
			t[i], t[j] = t[j], t[i]
		end
		return t
	end
	-- the face of a prop that stands against the side wall at a (so it looks into the room)
	local function facing(a)
		return (a > 0) and "a-" or "a+"
	end

	-- n loose-loot spots as the old furnishing threw them: (a, d) in the room, two dice each
	local function throwSpots(rng, n, hw, dp)
		local t = {}
		for i = 1, n do
			local a = rng:NextNumber(-hw + 1.2, hw - 1.2)
			local d = rng:NextNumber(2.5, dp - 1.5)
			t[i] = { a, d }
		end
		return t
	end

	local function winKey(floor, wallId, c)
		return string.format("%d%s%d", floor, wallId, math.floor(c * 10 + 0.5))
	end
	-- how a window is glazed: the same answer every time for the same window, so the wall and the room agree
	local function winStyle(floor, wallId, c)
		local g = Random.new(floor * 100003 + string.byte(wallId) * 1009 + math.floor((c + 300) * 10 + 0.5))
		g:NextNumber()
		g:NextNumber()
		local r = g:NextNumber()
		-- Tarkov's dorm windows are mostly passable openings (players vault and shoot through them), so a whole pane is the
		-- exception: 30 % whole, 25 % half broken, 35 % open, 10 % boarded (shares ours; a shot or a blow breaks a pane, Glass.luau)
		if r < 0.30 then
			return "whole"
		elseif r < 0.55 then
			return (g:NextNumber() < 0.5) and "high" or "low"
		elseif r < 0.90 then
			return "open"
		end
		return "boards"
	end

	-- The plan of one block. cfg = { seed, floors, rows, locks, ctx, wash = { ns, floors }, kitchen = { floor, ns } }. The old
	-- dice go first, room by room in the order the block is built (floor, row, slot), draw for draw as before; then each room
	-- gets its class from the second seed: "wash", "kitchen", "bare" (a fifth of all rooms) or "lived".
	local function planDorm(cfg)
		local rng = Random.new(cfg.seed)
		local plan = { rooms = {}, list = {} }
		for k = 1, cfg.floors do
			for _, row in cfg.rows do
				local near = row.wallAt + row.dir * TI / 2
				local dp = math.abs(row.far - near)
				for _, s in row.slots do
					if s.kind == "room" then
						local num = k * 100 + s.n
						local hw = (s.a2 - s.a1 - TI) / 2
						local info = { num = num, floor = k, row = row, slot = s, hw = hw, dp = dp }
						if cfg.locks[num] then
							info.locked = true
							info.spots = throwSpots(rng, 3, hw, dp)
							if cfg.locks[num] == "KEY_BY_314" then
								info.spots2 = throwSpots(rng, 3, hw, dp)
							end
						else
							info.doorRoll = rng:NextNumber()
							info.roll = rng:NextNumber()
							if info.roll < 0.62 then
								if rng:NextNumber() < 0.25 then
									rng:NextNumber()
								end
							elseif info.roll >= 0.74 and info.roll < 0.83 then
								rng:NextNumber()
							end
							info.desk = info.roll >= 0.90 and info.roll < 0.95
							info.jacket = rng:NextNumber() < 0.12
							local n = 0
							if rng:NextNumber() < 0.65 then
								n += 1
							end
							if rng:NextNumber() < 0.15 then
								n += 1
							end
							info.spots = throwSpots(rng, n, hw, dp)
						end
						-- the window in the room's far wall, if it has one
						local we = cfg.ctx.win[row.name]
						if we then
							for _, h in we[1] do
								if h[3] >= 1.5 and math.abs(h[1] - s.a0) < 0.5 then
									info.win, info.wallId = h, we[2]
									break
								end
							end
						end
						plan.rooms[num] = info
						table.insert(plan.list, info)
					end
				end
			end
		end

		local rooms, list = plan.rooms, plan.list
		local rc = Random.new(cfg.seed + 5000)
		local function calm(i)
			return i ~= nil and not i.locked and not i.desk
		end
		local function free(i)
			return calm(i) and not i.jacket
		end
		-- washrooms: one column through the floors if every floor has a room for it, else the first free room of each
		local wz = cfg.wash
		if wz then
			local col = nil
			for _, n in wz.ns do
				local ok = true
				for _, k in wz.floors do
					if not free(rooms[k * 100 + n]) then
						ok = false
					end
				end
				if ok and not col then
					col = n
				end
			end
			for _, k in wz.floors do
				local at = col and rooms[k * 100 + col] or nil
				if not at then
					for _, n in wz.ns do
						local i = rooms[k * 100 + n]
						if not at and free(i) then
							at = i
						end
					end
				end
				if at then
					at.class = "wash"
					if at.win then
						cfg.ctx.frost[winKey(at.floor, at.wallId, at.win[1])] = true
					end
				end
			end
		end
		local kz = cfg.kitchen
		if kz then
			local at = nil
			for _, n in kz.ns do
				local i = rooms[kz.floor * 100 + n]
				if not at and free(i) and not i.class then
					at = i
				end
			end
			if at then
				at.class = "kitchen"
			end
		end
		-- a fifth of all the rooms are bare
		local pool = {}
		for _, i in list do
			if not i.class and calm(i) then
				table.insert(pool, i)
			end
		end
		for j = #pool, 2, -1 do
			local m = rc:NextInteger(1, j)
			pool[j], pool[m] = pool[m], pool[j]
		end
		for j = 1, math.min(math.floor(0.2 * #list + 0.5), #pool) do
			pool[j].class = "bare"
		end
		for _, i in list do
			if not i.locked then
				i.class = i.class or "lived"
				i.seed = rc:NextInteger(1, 2000000000)
				local fixed = i.class == "wash" or i.class == "kitchen"
				local dr = rc:NextNumber()
				-- a room whose old dice gave it a door (one in four) keeps it
				i.hasDoor = fixed or i.doorRoll < 0.25 or dr < ((i.class == "bare") and 0.7 or 0.95)
			end
		end
		return plan
	end

	-- loose loot at the spots the plan holds; a spot with no room is tried again elsewhere (up to three times) with dice of
	-- their own, so the plan's dice are never disturbed
	local function dormSpots(R, spots, pool, chance, rx)
		local hw, dp = R.aw / 2, R.dp
		for _, sp in spots do
			local placed = R:loose(sp[1], 0.5, sp[2], pool, chance, true)
			local try = 1
			while not placed and try < 3 do
				try += 1
				local a, d = rx:NextNumber(-hw + 1.2, hw - 1.2), rx:NextNumber(2.5, dp - 1.5)
				placed = R:loose(a, 0.5, d, pool, chance, try < 3)
			end
		end
	end

	-- ── thin glass, boards and curtains ──────────────────────────────────────────────────────────────────────────────
	-- Glass in the window holes of one outer wall: axis "u" = the wall runs along u at v = at, "v" = along v at u = at; inward:
	-- which way the rooms lie from it. A pane is CanCollide only (shots and sight pass it, as they passed the open hole); some
	-- windows keep half a pane, some none, some are boarded up. Broken ones leave glass on the floor inside. Every pane carries the
	-- tag "ZR_Glass": the Glass service (server/Services/Glass.luau) finds the breakable panes by it, so a shot or a blow breaks one.
	local function pane(p)
		if p then
			CollectionService:AddTag(p, "ZR_Glass")
		end
		return p
	end
	local function glaze(f, axis, at, inward, y, holes, wallId, floor, ctx)
		local ry = (axis == "u") and 0 or 90
		for _, h in holes do
			local c, w, b, t = h[1], h[2], h[3], h[4]
			if b >= 1.5 and w >= 1.5 and t - b >= 2.5 then
				local pu, pv = at, c
				if axis == "u" then
					pu, pv = c, at
				end
				local frost = ctx.frost[winKey(floor, wallId, c)] == true
				local style = frost and "whole" or winStyle(floor, wallId, c)
				local gw, gh = w - 0.1, t - b - 0.1
				if style == "whole" then
					pane(f:bit(gw, gh, 0.1, pu, y + b + 0.05, pv, frost and D.frost or D.glass, M.Glass, ry,
						{ collide = true, alpha = frost and 0.12 or 0.5, shadow = false, cat = frost and "frosted" or "panes" }))
				elseif style == "high" then
					pane(f:bit(gw, gh * 0.5, 0.1, pu, y + t - 0.05 - gh * 0.5, pv, D.glass, M.Glass, ry, { collide = true, alpha = 0.5, shadow = false, cat = "panes" }))
					DC.cracked += 1
				elseif style == "low" then
					pane(f:bit(gw, gh * 0.45, 0.1, pu, y + b + 0.05, pv, D.glass, M.Glass, ry, { collide = true, alpha = 0.5, shadow = false, cat = "panes" }))
					DC.cracked += 1
				elseif style == "open" then
					DC.open += 1
				else
					DC.boarded += 1
					for i = 1, 3 do
						f:bit(w + 0.5, 0.9, 0.2, pu, y + b + (i - 0.5) * ((t - b) / 3) - 0.45, pv, P.board, M.WoodPlanks, ry,
							{ collide = true, query = true, wear = true, roll = (i - 2) * 2.5, cat = "boards" })
					end
				end
				if style == "high" or style == "low" or style == "open" then
					local g = Random.new(math.floor(c * 100) + floor)
					if g:NextNumber() < 0.7 then
						local su, sv = pu, pv
						if axis == "u" then
							sv = pv + inward * 1.4
						else
							su = pu + inward * 1.4
						end
						if f:dprop("GlassShards", f:cf(su, y, sv, g:NextInteger(0, 359)), {}) then
							DC.shards += 1
						end
					end
				end
			end
		end
	end

	-- curtains on a room's own window (not over a boarded or open one)
	local function curtains(R, info, rx, chance)
		local h = info.win
		if not h or rx:NextNumber() > chance then
			return
		end
		local style = winStyle(info.floor, info.wallId, h[1])
		if style == "open" or style == "boards" then
			return
		end
		local aw = h[1] - info.slot.a0
		local col = pick(rx, D.curtain)
		local dd = R.dp - 0.35
		local kind = rx:NextNumber()
		local o = { cat = "curtains", shadow = false }
		if kind < 0.45 then
			R:rb(h[2] + 0.7, 4.8, 0.08, aw, 2.2, dd, col, M.Fabric, o)
		elseif kind < 0.8 then
			R:rb(1.2, 4.8, 0.08, aw - h[2] / 2 - 0.1, 2.2, dd, col, M.Fabric, o)
			R:rb(1.2, 4.8, 0.08, aw + h[2] / 2 + 0.1, 2.2, dd, col, M.Fabric, o)
		else
			local side = (rx:NextNumber() < 0.5) and -1 or 1
			R:rb(2.2, 4.8, 0.08, aw + side * (h[2] / 2 - 0.9), 2.2, dd, col, M.Fabric, o)
		end
	end

	-- ── what lies about ──────────────────────────────────────────────────────────────────────────────────────────────
	-- a clear patch of floor (radius r) away from the door's swing; returns u, v (the frame's) and a, d (the room's), or nil.
	-- `along`: the half length of a long thing lying in the room's depth, its two ends are tested as well
	local function spot(R, rx, r, y1, along)
		local hw, dp = R.aw / 2, R.dp
		for _ = 1, 8 do
			local a, d = rx:NextNumber(-hw + r, hw - r), rx:NextNumber(1.0 + (along or 0), dp - r - (along or 0))
			if not (a > -4.0 and a < 1.1 and d - (along or 0) < 5.6) then
				local u, v = R:uv(a, d)
				local ok = R.f:clearAt(R.f:pt(u, R.y, v), r, y1)
				if ok and along then
					local u1, v1 = R:uv(a, d - along)
					local u2, v2 = R:uv(a, d + along)
					ok = R.f:clearAt(R.f:pt(u1, R.y, v1), r, y1) and R.f:clearAt(R.f:pt(u2, R.y, v2), r, y1)
				end
				if ok then
					return u, v, a, d
				end
			end
		end
		return nil
	end
	local function dropJunk(f, rx, kind, u, y, v)
		local ry = rx:NextInteger(0, 359)
		if kind == "paper" then
			f:bit(1.4, 0.04, 1.0, u, y + 0.02, v, D.paper, M.SmoothPlastic, ry)
		elseif kind == "bottle" then
			f:bit(0.35, 1.0, 0.35, u, y, v, D.bottle, M.SmoothPlastic, ry)
		elseif kind == "clothes" then
			f:bit(1.6, 0.35, 1.2, u, y, v, pick(rx, D.cloth), M.Fabric, ry)
		elseif kind == "box" then
			f:bit(1.4, 0.9, 1.0, u, y, v, D.box, M.Cardboard, ry)
		elseif kind == "bag" then
			f:bit(2.0, 0.9, 1.0, u, y, v, pick(rx, D.cloth), M.Fabric, ry)
		else
			f:bit(0.6, 0.15, 0.9, u, y + 0.02, v, pick(rx, D.cloth), M.SmoothPlastic, ry)
		end
	end
	local LIVED_JUNK = { "paper", "bottle", "clothes", "bag", "book", "box" }
	local BARE_JUNK = { "paper", "paper", "bottle", "bottle", "clothes", "box", "box", "book" }
	local function scatter(R, rx, n, kinds)
		for _ = 1, n do
			local u, v = spot(R, rx, 0.8, 1.0)
			if u then
				dropJunk(R.f, rx, pick(rx, kinds), u, R.y, v)
			end
		end
	end

	-- the lived-in room: somewhere to sleep, then a wardrobe, a desk and chair, a bookcase, some rubbish, curtains
	local function furnishLived(R, info, rx)
		local hw, dp = R.aw / 2, R.dp
		local s = (R.doorA < 0) and 1 or -1
		local corner = hw - 1.7
		local ca = (rx:NextNumber() < 0.5) and 1 or -1 -- the far corner the first bed takes
		local sleep = rx:NextNumber()
		local tintA, tintB = { fabric = pick(rx, D.bedding) }, { fabric = pick(rx, D.bedding) }
		if sleep < 0.46 then
			R:bprop("Bed", ca * s * corner, dp - 3.4, "out", { scale = SC.single, tint = tintA })
		elseif sleep < 0.64 then
			R:bprop("Bed", ca * s * corner, dp - 3.4, "out", { scale = SC.single, tint = tintA })
			R:bprop("Bed", -ca * s * corner, dp - 3.4, "out", { scale = SC.single, tint = tintB })
		elseif sleep < 0.88 then
			local k = hw - 1.55
			local a1, a2 = ca * s * k, -ca * s * k
			if not R:bprop("BunkBed", a1, dp - 3.6, facing(a1), { collide = BUNK_COLL, tint = tintA }) then
				R:bprop("BunkBed", a2, dp - 3.6, facing(a2), { collide = BUNK_COLL, tint = tintA })
			end
			if rx:NextNumber() < 0.25 then
				R:bprop("BunkBed", a2, dp - 3.6, facing(a2), { collide = BUNK_COLL, tint = tintB })
			end
		else
			R:bprop("Bed", s * 1.3, dp - 3.85, "out", { tint = tintA })
		end
		local sideA = (rx:NextNumber() < 0.8) and s or -s -- the side wall the desk and the shelves stand on
		if rx:NextNumber() < 0.62 then
			local cands = shuffled({
				{ s * (hw - 1.2), 2.1, facing(s) }, -- inside the door, against the free wall
				{ -s * (hw - 1.45), dp - 1.2, "out" }, { s * (hw - 1.45), dp - 1.2, "out" },
				{ sideA * (hw - 1.2), 9.8, facing(sideA) },
			}, rx)
			for _, c in cands do
				if R:bprop("Locker", c[1], c[2], c[3], { scale = SC.ward, tint = D.wood, mats = { paint = { M.Wood } } }) then
					break
				end
			end
		end
		if rx:NextNumber() < 0.5 then
			local da, ch = sideA * (hw - 1.25), sideA * (hw - 3.2)
			local cands = shuffled({
				{ da, 7.4, facing(sideA), ch, 7.4, facing(-sideA) },
				{ da, 10.2, facing(sideA), ch, 10.2, facing(-sideA) },
				{ 0, dp - 1.3, "out", 0, dp - 3.4, "in" },
			}, rx)
			for _, c in cands do
				if R:bprop("Table", c[1], c[2], c[3], { scale = SC.desk }) then
					R:bprop("Chair", c[4], c[5], c[6])
					break
				end
			end
		end
		if rx:NextNumber() < 0.3 then
			-- the spot just inside the door only on the free wall: on the hinge side it would stand in the door's landing
			local list = { { sideA * (hw - 0.95), 12.4, facing(sideA) }, { -sideA * (hw - 0.95), 12.4, facing(-sideA) } }
			if sideA == s then
				list[#list + 1] = { sideA * (hw - 0.95), 4.2, facing(sideA) }
			end
			local cands = shuffled(list, rx)
			for _, c in cands do
				if R:bprop("WallShelfBooks", c[1], c[2], c[3], { scale = SC.books }) then
					break
				end
			end
		end
		scatter(R, rx, rx:NextInteger(2, 4), LIVED_JUNK)
		curtains(R, info, rx, 0.4)
	end

	-- the stripped room: a mattress on the floor, rubbish, and a fallen chair or a broken shelf or a heap of cardboard
	local function furnishBare(R, info, rx)
		local f, y = R.f, R.y
		if rx:NextNumber() < 0.75 then
			local u, v, a, d = spot(R, rx, 1.7, 1.0, 2.4)
			if u then
				R:rb(3.0, 0.5, 6.4, a, 0, d, pick(rx, D.bedding), M.Fabric, { cat = "bits" })
			end
		end
		if rx:NextNumber() < 0.5 then
			local u, v = spot(R, rx, 1.5, 1.3)
			if u then
				f:dprop("Chair", f:cf(u, y + 0.66, v, rx:NextInteger(0, 359)) * CFrame.Angles(0, 0, rad(90)), { collide = false })
			end
		end
		if rx:NextNumber() < 0.35 then
			local u, v = spot(R, rx, 2.2, 1.0)
			if u then
				local ry = rx:NextInteger(0, 359)
				f:bit(3.4, 0.22, 0.9, u, y + 0.02, v, D.woodLt, M.WoodPlanks, ry)
				f:bit(3.0, 0.22, 0.9, u + 0.5, y + 0.26, v + 0.4, D.wood, M.WoodPlanks, ry + 25)
				f:bit(0.25, 3.0, 0.9, u - 0.8, y + 0.02, v - 1.0, D.wood, M.WoodPlanks, ry + 70)
			end
		end
		if rx:NextNumber() < 0.35 then
			local u, v = spot(R, rx, 2.0, 1.0)
			if u then
				f:dprop("CardboardPile", f:cf(u, y, v, rx:NextInteger(0, 359)), { scale = V3(0.55, 0.7, 0.55) })
			end
		end
		scatter(R, rx, rx:NextInteger(5, 8), BARE_JUNK)
		curtains(R, info, rx, 0.15)
	end

	-- the shared washroom: sinks under mirrors along the free wall, three toilet cubicles along the other, three showers at the
	-- far end; tiles, a drain, puddles, a sign over the door. The aisle between is 4.7 studs wide.
	local function washroom(R, info)
		local hw, dp = R.aw / 2, R.dp
		local s = (R.doorA < 0) and 1 or -1
		local rx = Random.new(info.seed)
		local fit = { cat = "fit", shadow = false }
		local solid = { cat = "fit", solid = true }
		local tile = { cat = "fit", shadow = false, finish = "ZR_WallTiles" } -- glazed wall tiles (World.applyWear)
		R:rb(2 * hw - 0.3, 0.06, dp - 0.3, 0, 0.01, dp / 2, D.tileW, M.CeramicTiles, fit)
		R:rb(0.08, 4.4, dp - 1.0, s * (hw - 0.04), 0, dp / 2, D.tileG, M.CeramicTiles, tile)
		R:rb(0.08, 4.4, dp - 1.0, -s * (hw - 0.04), 0, dp / 2, D.tileG, M.CeramicTiles, tile)
		-- the far wall to head height too, but only to 2.9 under a window (its sill is at 3.0)
		R:rb(2 * hw - 0.4, info.win and 2.9 or 4.4, 0.08, 0, 0, dp - 0.04, D.tileG, M.CeramicTiles, tile)
		-- two sinks, each under its mirror, and the pipe over them
		for _, d in { 7.2, 11.4 } do
			R:bprop("MirrorSink", s * (hw - 0.75), d, facing(s), { mats = { glass = { M.Glass, nil, 0.1, 0.5, false } } })
		end
		R:rb(0.25, 0.25, 11, s * (hw - 0.2), 8.0, 9.4, P.steel, M.Metal, fit)
		-- three cubicles: partitions, a bowl and a high cistern each, doors shut, broken or gone
		local pa = -s * (hw - 1.45)
		for i = 0, 3 do
			R:rb(2.9, 5.4, 0.2, pa, 0.8, 5.8 + 3 * i, D.part, M.Metal, solid)
		end
		local states = shuffled({ "closed", "half", "gone" }, rx)
		for i = 0, 2 do
			local dc = 7.3 + 3 * i
			R:rb(1.5, 1.1, 1.0, -s * (hw - 1.1), 0, dc, D.porc, M.SmoothPlastic, solid)
			R:rb(0.5, 1.1, 0.9, -s * (hw - 0.3), 4.7, dc, D.porc, M.SmoothPlastic, fit)
			local state = states[i + 1]
			if state == "closed" then
				R:rb(0.15, 5.0, 2.5, -s * 1.72, 0.8, dc, D.part, M.Metal, solid)
			elseif state == "half" then
				R:rb(0.15, 5.0, 1.1, -s * 1.72, 0.8, dc - 0.7, D.part, M.Metal, solid)
			end
		end
		-- three shower stalls across the far end, curtains drawn or pushed aside
		for i = -1, 1 do
			local ac = i * 3.0
			R:rb(2.7, 0.2, 2.8, ac, 0, dp - 1.8, D.porc, M.SmoothPlastic, fit)
			R:rb(0.15, 5.4, 0.15, ac, 0, dp - 0.25, P.metalGry, M.Metal, fit)
			R:rb(0.9, 0.25, 0.9, ac, 5.4, dp - 0.8, P.metalGry, M.Metal, fit)
			local col = pick(rx, D.curtain)
			if rx:NextNumber() < 0.6 then
				R:rb(2.6, 5.0, 0.08, ac, 0.9, dp - 3.3, col, M.Fabric, fit)
			else
				R:rb(0.8, 5.0, 0.08, ac + 1.0, 0.9, dp - 3.3, col, M.Fabric, fit)
			end
		end
		for _, ac in { -1.5, 1.5 } do
			R:rb(0.2, 6.2, 3.1, ac, 0, dp - 1.75, D.part, M.Metal, solid)
		end
		-- a drain and two puddles; a bin by the door
		R:rb(0.9, 0.04, 0.9, 0.8, 0.08, 14.6, P.metalGry, M.Metal, fit)
		R:rb(2.2, 0.03, 1.6, 1.4, 0.08, 9.0, D.water, M.Glass, { cat = "fit", shadow = false, alpha = 0.45 })
		R:rb(1.8, 0.03, 1.4, 0.4, 0.08, dp - 4.4, D.water, M.Glass, { cat = "fit", shadow = false, alpha = 0.45 })
		R:bprop("Bin", s * (hw - 1.0), 1.6, "out")
		-- the sign above the door, on the corridor side of the wall
		local plate = R:rb(2.4, 0.9, 0.12, R.doorA, 8.2, -(TI + 0.05), P.steel, M.Metal, fit)
		local face
		if R.axis == "u" then
			face = (R.dir > 0) and Enum.NormalId.Front or Enum.NormalId.Back
		else
			face = (R.dir > 0) and Enum.NormalId.Left or Enum.NormalId.Right
		end
		kit.sign(plate, face, "WASHROOM", P.white, P.steel)
	end

	-- the kitchen of the top floor: worktops, a sink and a cooker along the free wall, a fridge, a table with two stools
	local function kitchen(R, info)
		local hw, dp = R.aw / 2, R.dp
		local s = (R.doorA < 0) and 1 or -1
		local rx = Random.new(info.seed)
		local fit = { cat = "fit", shadow = false }
		local solid = { cat = "fit", solid = true }
		local tile = { cat = "fit", shadow = false, finish = "ZR_WallTiles" }
		-- tiled to 4.4 studs (1.4 m) on three walls, like the washrooms
		R:rb(0.08, 4.4, dp - 1.0, s * (hw - 0.04), 0, dp / 2, D.tileW, M.CeramicTiles, tile)
		R:rb(0.08, 4.4, dp - 1.0, -s * (hw - 0.04), 0, dp / 2, D.tileW, M.CeramicTiles, tile)
		R:rb(2 * hw - 0.4, info.win and 2.9 or 4.4, 0.08, 0, 0, dp - 0.04, D.tileW, M.CeramicTiles, tile)
		DC.tiles += 3
		local ca = s * (hw - 1.15)
		R:rb(2.2, 3.0, 3.6, ca, 0, 7.4, D.wood, M.WoodPlanks, solid)
		R:rb(2.4, 0.2, 3.8, ca, 3.0, 7.4, D.top, M.Concrete, fit)
		R:rb(1.4, 0.15, 1.8, ca, 3.2, 7.4, P.steel, M.Metal, fit)
		R:rb(0.2, 1.0, 0.2, s * (hw - 0.3), 3.2, 7.4, P.metalGry, M.Metal, fit)
		R:rb(2.2, 3.1, 2.6, ca, 0, 10.5, P.white, M.Metal, solid)
		R:rb(0.8, 0.1, 0.8, ca, 3.1, 10.0, P.tar, M.Metal, fit)
		R:rb(0.8, 0.1, 0.8, ca, 3.1, 11.0, P.tar, M.Metal, fit)
		R:rb(2.2, 3.0, 2.8, ca, 0, 13.2, D.wood, M.WoodPlanks, solid)
		R:rb(2.4, 0.2, 3.0, ca, 3.0, 13.2, D.top, M.Concrete, fit)
		R:rb(1.2, 2.2, 3.6, s * (hw - 0.65), 5.4, 7.4, D.wood, M.WoodPlanks, fit)
		R:rb(1.2, 2.2, 2.8, s * (hw - 0.65), 5.4, 13.2, D.wood, M.WoodPlanks, fit)
		R:rb(0.9, 0.5, 0.9, ca, 3.2, 13.2, P.metalGry, M.Metal, fit)
		R:rb(0.8, 0.5, 0.8, ca, 3.2, 10.5, P.metalGry, M.Metal, fit)
		R:bprop("Fridge", s * (hw - 1.62), dp - 1.6, "out", { scale = V3(0.38, 0.95, 0.6) })
		local ta = -s * (hw - 1.4)
		R:bprop("Table", ta, 9.0, facing(-s), { scale = V3(0.5, 1, 0.8) })
		R:bprop("Chair", ta + s * 1.6, 8.2, facing(s))
		R:bprop("Chair", ta + s * 1.6, 9.8, facing(s))
		scatter(R, rx, 3, LIVED_JUNK)
		curtains(R, info, rx, 0.5)
	end

	-- one room that is not locked: what the old dice left (a desk with drawers and its chair, a coat), then the new furniture
	-- by class, then the loose loot at the old spots
	local function dormFurnish(R, ctx, info, spec)
		local hw, dp = R.aw / 2, R.dp
		local s = (R.doorA < 0) and 1 or -1
		local id = spec.stem
		if info.desk then
			R:stash("OfficeDesk", id .. "D", "drawer", "Desk drawers", s * 1.5, dp - 2.6, "out")
			R:prop("Chair", s * 1.5, dp - 5.4, "in")
		end
		if info.jacket then
			local ju, jv = R:uv(s * (hw - 0.6), dp * 0.42)
			R.f:jacket(id .. "J", "Jacket", ju, R.y, jv, R:yaw(s > 0 and "a-" or "a+"))
		end
		local rx = Random.new(info.seed)
		if info.class == "wash" then
			washroom(R, info)
			DC.wash += 1
		elseif info.class == "kitchen" then
			kitchen(R, info)
			DC.kitchen += 1
		elseif info.class == "bare" then
			furnishBare(R, info, rx)
			DC.bare += 1
		else
			furnishLived(R, info, rx)
			DC.lived += 1
		end
		dormSpots(R, info.spots, "dorm", spec.chance or 0.4, ctx.rx)
	end

	-- a locked room: richer, with its own containers. The vault room (314) keeps its bed on the far side and leaves the
	-- far corner on the bed's usual side to its safe (see onLocked in dormA)
	local function dormLocked(R, ctx, spec)
		local hw, dp = R.aw / 2, R.dp
		local s = (R.doorA < 0) and 1 or -1
		local id = spec.stem
		if spec.vault then
			R:prop("Bed", -s * 1.7, dp - 4.0, "out")
		else
			R:prop("Bed", s * 1.0, dp - 4.0, "out")
			R:stash("Locker", id .. "L", "locker", "Wardrobe", -s * (hw - 1.2), dp - 1.2, "out")
		end
		-- the desk stands against the free side wall, out of the door's way
		R:stash("OfficeDesk", id .. "D", "drawer", "Desk drawers", s * (hw - 1.65), 4.5, s > 0 and "a-" or "a+")
		R:prop("Chair", s * (hw - 4.6), 4.5, s > 0 and "a+" or "a-")
		local ju, jv = R:uv(-s * (hw - 0.6), dp * 0.55)
		R.f:jacket(id .. "J", "Jacket", ju, R.y, jv, R:yaw(s > 0 and "a+" or "a-"))
		R:lamp(0, dp * 0.5, 22, false)
	end

	-- ── wall finishes of the dorms (docs/look/WALLS.md) ──────────────────────────────────────────────────────────────
	-- World.applyWear reads the attribute Finish on a part or on the Model it stands in. Here: a corridor wall is whitewash over
	-- a gloss-painted band 1.5 m high (thin skins on its face with a darker line on top, cut at every doorway); each room's
	-- dividers carry that room's finish (wallpaper A or B or whitewash in a hue its Model's name picks, plaster peel in a bare
	-- room); a divider between two rooms that differ is two leaves, one per side, while WF_CAP.split lasts; the washrooms and
	-- the kitchen are tiled to 4.4 studs (see there). Every skin and line is a part of Frame:bit: no collision, no shadow,
	-- no ray.
	local BAND_H = 4.7 -- 1.5 m
	local BAND_COL = { green = hex("5E7B5C"), blue = hex("5C7684"), brown = hex("6E5440"), ochre = hex("A07F3E") }
	local BAND_BLOCK = { A = { BAND_COL.green, BAND_COL.blue, BAND_COL.brown }, B = { BAND_COL.ochre, BAND_COL.green } } -- by floor
	local WF = { skins = 0, lines = 0, stairs = 0, splits = 0, whole = 0, worst = 0 }
	local WF_CAP = { split = 125, parts = 440 } -- extra leaves; band skins and lines together
	local LOOK_RANK = { ZR_PlasterPeel = 1, ZR_Whitewash = 2, ZR_WallpaperB = 3, ZR_WallpaperA = 4 } -- the worse one wins a divider

	-- the finish of a room's own walls: bare rooms are plaster peel, the others wallpaper A, wallpaper B or whitewash by the
	-- room's seed (locked rooms have none: their number stands in)
	local function roomLook(info, num)
		if info == nil then
			return "ZR_Whitewash"
		elseif info.class == "bare" then
			return "ZR_PlasterPeel"
		elseif info.class == "wash" or info.class == "kitchen" then
			return "ZR_Whitewash"
		end
		local r = Random.new((info.seed or (num * 7919 + 17)) + 31):NextNumber()
		if r < 0.35 then
			return "ZR_WallpaperA"
		elseif r < 0.65 then
			return "ZR_WallpaperB"
		end
		return "ZR_Whitewash"
	end

	-- the Model that carries the finish of the room (or the stairwell) in a slot, and that finish
	local function slotFin(f, row, floor, s, ctx)
		if s.kind == "stairs" then
			return f:finModel(string.format("Stairwell %s%d", row.name, floor), "ZR_Whitewash", false), "ZR_Whitewash"
		end
		local num = floor * 100 + s.n
		local look = roomLook(ctx.plan.rooms[num], num)
		return f:finModel("Rm " .. num, look, look ~= "ZR_PlasterPeel"), look
	end

	-- a gloss-painted band BAND_H high on one face of a wall. The wall runs along `axis` ("u" or "v") from t0 to t1, `face` is the
	-- coordinate of its face across it and `out` (+1 / -1) the way the face looks. A skin 0.03 thick (World.applyWear gives it
	-- the gloss variant; its colour stays), and a darker line 0.2 high on top of it, 0.04 thick. Thin on purpose: the detail
	-- plan's wall decals float 0.055 and more off the face, and a skin as thick as that flickers against them (Relay7 had
	-- 0.06 slabs once and cut its walls instead, see its wall()); under 0.05 they stay in front
	local function band(f, axis, face, out, t0, t1, y, col, line)
		if t1 - t0 < 0.4 or WF.skins + WF.lines >= WF_CAP.parts then
			return
		end
		local len, mid = t1 - t0, (t0 + t1) / 2
		local o = { cat = "band", shadow = false, finish = "ZR_PaintGloss" }
		local at = face + out * 0.015
		if axis == "u" then
			f:bit(len, BAND_H, 0.03, mid, y, at, col, M.Plaster, 0, o)
		else
			f:bit(0.03, BAND_H, len, at, y, mid, col, M.Plaster, 0, o)
		end
		WF.skins += 1
		if line then
			local dark = Color3.new(col.R * 0.6, col.G * 0.6, col.B * 0.6)
			local lo = { cat = "band", shadow = false, plain = true }
			local la = face + out * 0.02
			if axis == "u" then
				f:bit(len, 0.2, 0.04, mid, y + BAND_H - 0.2, la, dark, M.Plaster, 0, lo)
			else
				f:bit(0.04, 0.2, len, la, y + BAND_H - 0.2, mid, dark, M.Plaster, 0, lo)
			end
			WF.lines += 1
		end
	end

	-- the band on the corridor face of a row's wall, from lo to hi, cut at every opening that reaches down to it (the doorways, the
	-- stairwell's, a gap)
	local function corridorBand(f, row, y, floor, holes, lo, hi, tag)
		local cols = BAND_BLOCK[tag] or BAND_BLOCK.A
		local col = cols[((floor - 1) % #cols) + 1]
		local out = -row.dir -- from the wall into the corridor
		local face = row.wallAt + out * TI / 2
		local cuts = {}
		for _, h in holes do
			if h[3] < BAND_H then
				table.insert(cuts, { h[1] - h[2] / 2, h[1] + h[2] / 2 })
			end
		end
		table.sort(cuts, function(p, q)
			return p[1] < q[1]
		end)
		local at = lo
		for _, c in cuts do
			if c[1] > at then
				band(f, row.axis, face, out, at, math.min(c[1], hi), y, col, true)
			end
			at = math.max(at, c[2])
		end
		if hi > at then
			band(f, row.axis, face, out, at, hi, y, col, true)
		end
	end

	-- the divider between two neighbouring slots of a row (it runs across the row's axis from c0 to c1, centred at a.a2): one wall
	-- when both rooms are bare, else two leaves of half the thickness, one in each room's finish, while the budget lasts; after
	-- that one wall in the worse of the two. A stairwell side gets a gloss band on its face
	local function divider(f, row, y, floor, a, b, c0, c1, ctx, tag)
		local ma, na = slotFin(f, row, floor, a, ctx)
		local mb, nb = slotFin(f, row, floor, b, ctx)
		local x = a.a2
		local function wall(at, t, into)
			if row.axis == "u" then
				f:wallV(at, c0, c1, y, H10, t, P.plaster, M.Plaster, nil, into)
			else
				f:wallU(at, c0, c1, y, H10, t, P.plaster, M.Plaster, nil, into)
			end
		end
		if na == nb and na == "ZR_PlasterPeel" then
			wall(x, TI, ma)
			WF.whole += 1
		elseif WF.splits < WF_CAP.split then
			wall(x - TI / 4, TI / 2, ma)
			wall(x + TI / 4, TI / 2, mb)
			WF.splits += 1
		else
			wall(x, TI, (LOOK_RANK[na] <= LOOK_RANK[nb]) and ma or mb)
			WF.worst += 1
		end
		if a.kind == "stairs" or b.kind == "stairs" then
			local side = (b.kind == "stairs") and 1 or -1
			local cols = BAND_BLOCK[tag] or BAND_BLOCK.A
			local before = WF.skins
			band(f, (row.axis == "u") and "v" or "u", x + side * TI / 2, side, c0, c1, y, cols[((floor - 1) % #cols) + 1], true)
			WF.stairs += WF.skins - before
		end
	end

	-- ── dorm rows: corridor wall with doorways, dividers, rooms ──────────────────────────────────────────────────────
	-- row = { name, axis, wallAt, dir, depth, far, doorOff, slots = { { a1, a2, kind, num } } } (kinds: room, stairs, gap)
	local function dormRow(f, y, floor, row, tag, ctx)
		local slots = row.slots
		local holes = {}
		for _, s in slots do
			s.a0 = (s.a1 + s.a2) / 2
			if s.kind == "room" then
				table.insert(holes, { s.a0 + row.doorOff, 3.9, 0, 7.5 })
			elseif s.kind == "stairs" then
				table.insert(holes, { s.a0, 6.2, 0, 7.5 })
			elseif s.kind == "gap" then
				table.insert(holes, { s.a0, s.a2 - s.a1 - TI, 0, H10 })
			end
		end
		local lo, hi = slots[1].a1, slots[#slots].a2
		if row.extend then
			hi = math.max(hi, row.extend)
		end
		-- the corridor wall: whitewash above a gloss-painted band
		local cor = f:finModel(string.format("Corridor %s%d", row.name, floor), "ZR_Whitewash", false)
		if row.axis == "u" then
			f:wallU(row.wallAt, lo, hi, y, H10, TI, row.color, M.Plaster, holes, cor)
		else
			f:wallV(row.wallAt, lo, hi, y, H10, TI, row.color, M.Plaster, holes, cor)
		end
		corridorBand(f, row, y, floor, holes, lo, hi, tag)
		local near = row.wallAt + row.dir * TI / 2
		local c0, c1 = math.min(near, row.far), math.max(near, row.far)
		for i = 1, #slots - 1 do
			local a, b = slots[i], slots[i + 1]
			if a.kind ~= "gap" and b.kind ~= "gap" then
				divider(f, row, y, floor, a, b, c0, c1, ctx, tag)
			end
		end
		for _, s in slots do
			if s.kind == "room" then
				local num = floor * 100 + s.n
				local info = ctx.plan.rooms[num]
				local aw = s.a2 - s.a1 - TI
				local R = newRoom(f, y, row.axis, s.a0, aw, near, row.dir, math.abs(row.far - near))
				R.doorA = row.doorOff
				local stem = "LV_" .. tag .. num
				local key = ctx.locks[num]
				local spec = { stem = stem, num = num, vault = (key == "KEY_BY_314"), info = info }
				DC.rooms += 1
				if key then
					f:door(stem, "Room " .. num, row.axis, s.a0 + row.doorOff, row.wallAt, y, row.dir, key, P.doorDk)
					dormLocked(R, ctx, spec)
					if row.onLocked then
						row.onLocked(R, num, spec)
					end
					dormSpots(R, info.spots, "dorm_good", 0.5, ctx.rx) -- last: the loot goes where nothing else will stand
				else
					if info.hasDoor then
						local label, chance = "Room " .. num, 0.55
						if info.class == "wash" then
							label, chance = "Washroom", 0.5
						elseif info.class == "kitchen" then
							label = "Kitchen"
						elseif info.class == "bare" then
							chance = 0.35
						end
						f:door(stem, label, row.axis, s.a0 + row.doorOff, row.wallAt, y, row.dir, nil, P.door, chance)
						DC.doors += 1
					end
					dormFurnish(R, ctx, info, spec)
				end
				pace()
			end
		end
	end

	-- ── dorm stairs, towers and roofs ────────────────────────────────────────────────────────────────────────────────
	local RUN = 9.6 -- run of a half flight (5.5 studs of rise): about 30 degrees

	-- the interior dogleg: lane A rises from the vestibule edge vS toward the far wall (sgn +1: toward +v), a landing at the
	-- far end, lane B comes back; the same footprint on every level (ladder-25 / ladder-24)
	-- g = { uc, sgn, vS, vFar, levels, ys }
	local function dormStairs(f, g)
		local uc, sgn, vS, vFar = g.uc, g.sgn, g.vS, g.vFar
		local run = g.run or RUN
		local vE = vS + sgn * run
		local outDir = sgn > 0 and "+v" or "-v"
		local backDir = sgn > 0 and "-v" or "+v"
		for k = 1, g.levels do
			local y = g.ys[k]
			local solid = (k == 1)
			f:flight(uc - 2.25, vS, y, 5.5, run, 4.0, outDir, solid and 0 or nil, P.conc, M.Concrete)
			if solid then
				f:blk(9.1, y + 5.5, math.abs(vFar - vE), uc, 0, (vE + vFar) / 2, P.conc, M.Concrete)
			else
				f:slab(uc - 4.55, uc + 4.55, math.min(vE, vFar), math.max(vE, vFar), y + 5.5, SLAB, P.conc, M.Concrete)
			end
			f:flight(uc + 2.25, vE, y + 5.5, 5.5, run, 4.0, backDir, solid and 0 or nil, P.conc, M.Concrete)
		end
		local top = g.ys[g.levels + 1]
		local partition = f:box(0.5, top - g.ys[1], run, uc, (g.ys[1] + top) / 2, (vS + vE) / 2, P.plaster, M.Plaster)
		partition:SetAttribute("Finish", "ZR_Whitewash") -- whitewash, its colour stays (World.applyWear)
		partition:SetAttribute("Tint", false)
	end

	-- an end stair tower on the outside of an end wall: the door on its outer face, a doorway to the corridor through the end
	-- wall, flights along v (ladder-26 / ladder-27 / ladder-28)
	-- g = { s (+1: at the +u end), vs (+1: the flights run toward +v), eF (the end wall's outer face), c (corridor axis),
	--       levels, ys, top, color, mat, doorId }
	local function dormTower(f, g)
		local s, vs, eF, c = g.s, g.vs, g.eF, g.c
		local function U(x)
			return eF + s * x
		end
		local function Vv(x)
			return c + vs * x
		end
		local function tb(a, b, y0, y1, v0, v1, color, mat)
			return f:box(math.abs(b - a), y1 - y0, math.abs(v1 - v0), U((a + b) / 2), (y0 + y1) / 2, (v0 + v1) / 2, color, mat)
		end
		local TRUN = 8.3
		local vA, vB = Vv(2.0), Vv(2.0 + TRUN)
		local vN, vF = Vv(-2.0), Vv(13.8)
		local ys, top = g.ys, g.top
		local outDir, backDir = vs > 0 and "+v" or "-v", vs > 0 and "-v" or "+v"
		tb(0, 6.8, ys[1] - SLAB, ys[1], vN, vF, P.conc, M.Concrete)
		for k = 1, g.levels do
			local y = ys[k]
			local solid = (k == 1)
			f:flight(U(1.65), vA, y, 5.5, TRUN, 3.3, outDir, solid and 0 or nil, P.conc, M.Concrete)
			if solid then
				tb(0, 6.8, 0, y + 5.5, vB, vF, P.conc, M.Concrete)
			else
				tb(0, 6.8, y + 5.5 - SLAB, y + 5.5, vB, vF, P.conc, M.Concrete)
			end
			f:flight(U(5.15), vB, y + 5.5, 5.5, TRUN, 3.3, backDir, solid and 0 or nil, P.conc, M.Concrete)
			tb(0, 6.8, ys[k + 1] - SLAB, ys[k + 1], vN, vA, P.conc, M.Concrete)
		end
		tb(3.3, 3.5, ys[1], top - SLAB, vA, vB, P.plaster, M.Plaster)
		tb(0, 7.8, ys[1], top - SLAB, Vv(-3.0), vN, g.color, g.mat)
		tb(0, 7.8, ys[1], top - SLAB, vF, Vv(14.8), g.color, g.mat)
		local vLo, vHi = math.min(vN, vF), math.max(vN, vF)
		for k = 1, #ys do
			local holes = { { Vv(12.1), 2.4, 7.4, 9.9 } }
			if k == 1 then
				table.insert(holes, { c, 3.9, 0, 7.5 })
			else
				table.insert(holes, { c, 2.6, 3.2, 7.4 })
			end
			f:wallV(U(7.3), vLo, vHi, ys[k], STOREY - SLAB, 1.0, g.color, g.mat, holes)
			f:lamp(U(3.4), ys[k] + 7.5, vF - vs * 0.5, 20, false)
		end
		tb(0, 7.8, top - SLAB, top, Vv(-3.0), Vv(14.8), P.roof, M.Concrete)
		f:door(g.doorId, "Stair entrance", "v", c, U(7.3), ys[1], -s, nil, P.door, 0.5)
		tb(7.8, 11.2, ys[1] + 8.4, ys[1] + 8.9, c - 3.2, c + 3.2, P.panelDk, M.Concrete)
		local uLo, uHi = math.min(U(0), U(7.8)), math.max(U(0), U(7.8))
		f:wallU(Vv(-2.5), uLo, uHi, top, 1.6, 0.8, P.panelDk, M.Concrete)
		f:wallU(Vv(14.3), uLo, uHi, top, 1.6, 0.8, P.panelDk, M.Concrete)
		f:wallV(U(7.4), math.min(Vv(-2.5), Vv(14.3)), math.max(Vv(-2.5), Vv(14.3)), top, 1.6, 0.8, P.panelDk, M.Concrete)
	end

	-- the roof hut over the stairwell: walls from the roof, a doorway on the corridor side, a cover slab
	-- g = { uc, vNear (the corridor wall), vFar (the exterior wall's centre), top (roof top), vOuter (outer wall's centre) }
	local function dormHut(f, g, doorId)
		local uc, top = g.uc, g.top
		local v0, v1 = math.min(g.vNear, g.vOuter), math.max(g.vNear, g.vOuter)
		for _, du in { -4.95, 4.95 } do
			f:wallV(uc + du, v0, v1, top, 8, 0.8, P.panelDk, M.Concrete)
		end
		f:wallU(g.vNear, uc - 5.35, uc + 5.35, top, 8, 0.8, P.panelDk, M.Concrete, { { uc, 3.9, 0, 7.5 } })
		f:wallU(g.vOuter, uc - 5.35, uc + 5.35, top, 8, 1.2, P.panelDk, M.Concrete)
		f:slab(uc - 5.35, uc + 5.35, v0 - 0.6, v1 + 0.6, top + 9, SLAB, P.roof, M.Concrete)
		f:door(doorId, "Roof hatch", "u", uc, g.vNear, top, -g.sgn, nil, P.metalGry, 0.3)
	end

	-- the roof edge around an L or rectangular outline (a list of { axis, pos, from, to })
	local function parapet(f, y, segs)
		for _, sg in segs do
			if sg[1] == "u" then
				f:wallU(sg[2], sg[3], sg[4], y, 1.6, 0.8, P.panelDk, M.Concrete)
			else
				f:wallV(sg[2], sg[3], sg[4], y, 1.6, 0.8, P.panelDk, M.Concrete)
			end
		end
	end

	-- ── BLOCK A and BLOCK B ──────────────────────────────────────────────────────────────────────────────────────────
	-- the dorm grid: 13 columns 9.9 studs wide, column i (0 at the +u end) centred at 59.1 - 9.9 i
	local function colEdge(j)
		return 64.05 - 9.9 * j
	end
	local function colC(i)
		return 59.1 - 9.9 * i
	end
	local function win(c, w, b, t)
		return { c, w or 3.6, b or 3.0, t or 7.2 }
	end
	function Room:alongYaw()
		return (self.axis == "u") and 0 or 90
	end
	-- the yaw that lays a box's long side along the room's depth
	function Room:depthYaw()
		return (self.axis == "u") and 90 or 0
	end
	-- extras the locked rooms carry besides their usual furniture: on the free side wall, long side along the depth
	local function lockedExtras(R, num, spec, kind)
		local s = (R.doorA < 0) and 1 or -1
		local id = spec.stem
		local u, v = R:uv(-s * 3.6, 7.4)
		if kind == "medbag" then
			R.f:medbag(id .. "M", "Medical bag", u, R.y, v, R:depthYaw())
		elseif kind == "gun" then
			R.f:gunCase(id .. "W", "Weapon case", u, R.y, v, R:depthYaw())
		elseif kind == "tool" then
			R.f:toolbox(id .. "T", "Toolbox", u, R.y, v, R:depthYaw())
		end
	end

	local function dormA(b)
		local f = newFrame(b, "BLOCK A")
		local FL = 3
		local ys = { 0.5, 11.5, 22.5 }
		local top = ys[1] + STOREY * FL
		local U0, U1, VLO, VHI, VFAR, UW = -65.7, 65.6, -5.9, 45.4, -45.4, -14.0
		local VC = 19.75
		local ext, extM = P.panel, M.Concrete
		local locks = {
			[103] = "KEY_BY_A103", [125] = "KEY_BY_A125", [128] = "KEY_BY_A128", [201] = "KEY_BY_A201", [212] = "KEY_BY_A212",
			[225] = "KEY_BY_A225", [228] = "KEY_BY_A228", [229] = "KEY_BY_A229", [303] = "KEY_BY_A303", [310] = "KEY_BY_A310",
			[314] = "KEY_BY_314", [317] = "KEY_BY_A317", [325] = "KEY_BY_A325",
		}
		local extras = { [310] = "medbag", [317] = "gun", [225] = "tool", [201] = "medbag", [228] = "gun", [103] = "tool", [212] = "medbag" }
		-- ctx: what the rooms share (the plan, the keys, the dice for loose loot that finds no room, the frosted windows)
		local ctx = { locks = locks, rx = Random.new(2601 + 9000), frost = {} }
		local slotsHI, slotsLO, slotsE, slotsW = {}, {}, {}, {}
		for i = 12, 0, -1 do
			local a1 = (i == 12) and -64.5 or colEdge(i + 1)
			local a2 = (i == 0) and 64.4 or colEdge(i)
			table.insert(slotsHI, { a1 = a1, a2 = a2, a0 = (a1 + a2) / 2, kind = (i == 4) and "stairs" or "room", n = 13 - i })
			table.insert(slotsLO, { a1 = a1, a2 = a2, a0 = (a1 + a2) / 2, kind = (i == 10) and "gap" or "room", n = 26 - i })
		end
		local wingC = {}
		for k = 0, 3 do
			local a1 = -44.2 + 9.675 * k
			table.insert(slotsE, { a1 = a1, a2 = a1 + 9.675, a0 = a1 + 4.8375, kind = "room", n = 27 + k })
			table.insert(slotsW, { a1 = a1, a2 = a1 + 9.675, a0 = a1 + 4.8375, kind = "room", n = 31 + k })
			table.insert(wingC, a1 + 4.8375)
		end
		local function onLocked(R, num, spec)
			local hw, dp = R.aw / 2, R.dp
			local s = (R.doorA < 0) and 1 or -1
			if num == 314 then
				local su, sv = R:uv(s * 3.0, dp - 1.7)
				R.f:container(spec.stem .. "S", "safe", "Room 314 safe", su, R.y, sv, R:yaw("out"))
				local gu, gv = R:uv(s * 3.6, dp - 7.0)
				R.f:gunCase(spec.stem .. "W", "Weapon case", gu, R.y, gv, R:depthYaw())
				dormSpots(R, spec.info.spots2, "dorm_good", 0.6, ctx.rx)
				local pu, pv = R:uv(0, dp * 0.4)
				points.BLOCK_A_ROOM314 = R.f:pt(pu, R.y + 0.5, pv)
			elseif extras[num] then
				lockedExtras(R, num, spec, extras[num])
			end
		end
		local rowHI = { name = "HI", axis = "u", wallAt = 24.4, dir = 1, far = 44.2, doorOff = -1.6, color = P.plasterG, slots = slotsHI, onLocked = onLocked }
		local rowLO = { name = "LO", axis = "u", wallAt = 15.1, dir = -1, far = -4.7, doorOff = -1.6, color = P.plasterG, slots = slotsLO, onLocked = onLocked }
		local rowE = { name = "E", axis = "v", wallAt = -34.95, dir = 1, far = -15.2, doorOff = -1.6, color = P.plasterG, extend = 14.7, slots = slotsE, onLocked = onLocked }
		local rowW = { name = "W", axis = "v", wallAt = -44.85, dir = -1, far = -64.5, doorOff = -1.6, color = P.plasterG, extend = 14.7, slots = slotsW, onLocked = onLocked }
		local stairHole = { 14.95, 24.05, 29.1, 44.2 }
		-- the window holes of the outer walls (the same on every floor), and the plan of the rooms behind them: washrooms (115, 215, 315
		-- where the old dice left them free: windowless, behind the corridor's west end) and a kitchen on the top floor
		local hN, hS, hE, hW, hWe = {}, {}, { { VC, 3.9, 0, 7.5 }, win(5.0), win(39.4) }, { { VC, 3.9, 0, 7.5 }, win(39.4), win(5.0) }, {}
		for _, sl in slotsHI do
			table.insert(hN, sl.kind == "room" and win(sl.a0) or { sl.a0, 2.6, 2.0, 8.6 })
		end
		for i = 0, 7 do
			table.insert(hS, win(colC(i)))
		end
		for _, c in wingC do
			table.insert(hW, win(c))
			table.insert(hWe, win(c))
		end
		ctx.win = { HI = { hN, "N" }, LO = { hS, "S" }, E = { hWe, "X" }, W = { hW, "W" } }
		ctx.plan = planDorm({
			seed = 2601, floors = FL, rows = { rowHI, rowLO, rowE, rowW }, locks = locks, ctx = ctx,
			wash = { ns = { 15, 14, 18, 17 }, floors = { 1, 2, 3 } }, kitchen = { floor = 3, ns = { 8, 7, 6, 5 } },
		})

		for k = 1, FL do
			local y = ys[k]
			f:slab(U0, U1, VLO, VHI, y, SLAB, P.conc, M.Concrete, k >= 2 and { stairHole } or nil)
			f:slab(U0, UW, VFAR, VLO, y, SLAB, P.conc, M.Concrete)
			-- the outside walls: windows at the room centres, a tall one at the stairwell, thin glass in them
			local hF = { win(-54.9), win(-24.9), k == 1 and { -39.9, 3.9, 0, 7.5 } or win(-39.9, 3.0) }
			f:wallU(VHI - 0.6, U0, U1, y, H10, 1.2, ext, extM, hN)
			glaze(f, "u", VHI - 0.6, -1, y, hN, "N", k, ctx)
			f:wallU(VLO + 0.6, -15.2, U1, y, H10, 1.2, ext, extM, hS)
			glaze(f, "u", VLO + 0.6, 1, y, hS, "S", k, ctx)
			f:wallU(-5.1, -64.5, -15.2, y, H10, TI, P.plaster, M.Plaster, { { -39.9, 9.1, 0, H10 } })
			f:wallV(U1 - 0.6, -4.7, 44.2, y, H10, 1.2, ext, extM, hE)
			glaze(f, "v", U1 - 0.6, -1, y, hE, "E", k, ctx)
			f:wallV(U0 + 0.6, -44.2, 44.2, y, H10, 1.2, ext, extM, hW)
			glaze(f, "v", U0 + 0.6, 1, y, hW, "W", k, ctx)
			f:wallU(VFAR + 0.6, U0, UW, y, H10, 1.2, ext, extM, hF)
			glaze(f, "u", VFAR + 0.6, 1, y, hF, "F", k, ctx)
			f:wallV(UW - 0.6, -44.2, -5.9, y, H10, 1.2, ext, extM, hWe)
			glaze(f, "v", UW - 0.6, -1, y, hWe, "X", k, ctx)
			dormRow(f, y, k, rowHI, "A", ctx)
			dormRow(f, y, k, rowLO, "A", ctx)
			dormRow(f, y, k, rowE, "A", ctx)
			dormRow(f, y, k, rowW, "A", ctx)
			for _, i in { 1, 4, 7 } do
				f:lamp(colC(i), y + 9.6, VC, 24, false)
			end
			f:lamp(-39.9, y + 9.6, -34, 24, false)
			f:lamp(-39.9, y + 9.6, -14, 24, false)
			f:lamp(-39.9, y + 9.6, VC, 24, false)
			f:lamp(19.5, y + 9.6, 27, 20, false)
		end
		-- the interior stairs, the roof hut, the two end towers
		dormStairs(f, { uc = 19.5, sgn = 1, vS = 29.1, vFar = 44.2, levels = FL, ys = { ys[1], ys[2], ys[3], top } })
		f:door("LV_A_WX", "Wing exit", "u", -39.9, VFAR + 0.6, ys[1], 1, nil, P.door, 0.5)
		for _, tw in { { 1, U1, "LV_A_TN" }, { -1, U0, "LV_A_TS" } } do
			dormTower(f, { s = tw[1], vs = 1, eF = tw[2], c = VC, levels = FL - 1, ys = ys, top = top, color = ext, mat = extM, doorId = tw[3] })
		end
		f:slab(U0, U1, VLO, VHI, top, SLAB, P.roof, M.Concrete, { stairHole })
		f:slab(U0, UW, VFAR, VLO, top, SLAB, P.roof, M.Concrete)
		parapet(f, top, {
			{ "u", VHI - 0.4, U0, U1 }, { "u", VLO + 0.4, UW, U1 }, { "u", VFAR + 0.4, U0, UW }, { "v", UW - 0.4, VFAR, VLO },
			{ "v", U1 - 0.4, VLO, VC - 3.0 }, { "v", U1 - 0.4, VC + 14.8, VHI },
			{ "v", U0 + 0.4, VFAR, VC - 3.0 }, { "v", U0 + 0.4, VC + 14.8, VHI },
		})
		dormHut(f, { uc = 19.5, vNear = 24.4, vOuter = 44.8, top = top, sgn = 1 }, "LV_A_ROOF")
		f:prop("HVAC", -30, top, 10, 0)
		f:prop("HVAC", 40, top, 4, 0)
		f:prop("Vent", -10, top, 38, 0)
		f:prop("Vent", 8, top, -2, 0)

		-- the ground-floor lobby at the north tower: the guard's desk, cloakroom lockers, a vending machine
		local y1 = ys[1]
		-- (the corridor doorways are 9.9 apart from u = 57.5; furniture stands on the free wall between two of them)
		f:stash("OfficeDesk", "LV_ALOBD", "drawer", "Guard desk", 52.55, y1, 22.5, 0)
		f:prop("Chair", 52.55, y1, 19.4, 180)
		f:stash("Lockers", "LV_ALOBL", "locker", "Cloakroom lockers", 42.65, y1, 17.1, 180)
		f:prop("Vending", 52.55, y1, 17.05, 180)
		f:prop("Bin", 61.0, y1, 16.5, 0)
		f:loose(52.55, y1 + 4.4, 22.5, "office", 0.5)
		f:loose(46.0, y1 + 0.5, 20.0, "dorm", 0.4)
		f:stash("Lockers", "LV_ALOBL2", "locker", "Boot room lockers", -56.35, y1, 22.5, 0)
		f:prop("Bench", -26.65, y1, 16.5, 180)
		points.BLOCK_A_LOBBY = f:pt(56, y1 + 0.5, VC)
		points.BLOCK_A_STAIRS = f:pt(19.5, y1 + 0.5, 26.9)
		points.BLOCK_A_ROOF = f:pt(19.5, top + 0.5, 21.0)
	end

	local function dormB(b)
		local f = newFrame(b, "BLOCK B")
		local FL = 2
		local ys = { 0.5, 11.5 }
		local top = ys[1] + STOREY * FL
		local U0, U1, VLO, VHI = -65.6, 65.5, -25.6, 25.9
		local VC = 0.05
		local ext, extM = P.brick, M.Brick
		local locks = { [111] = "KEY_BY_B111", [124] = "KEY_BY_B124", [103] = "KEY_BY_B103", [116] = "KEY_BY_B116", [223] = "KEY_BY_B223" }
		local extras = { [124] = "tool", [116] = "medbag", [223] = "gun", [103] = "medbag" }
		local ctx = { locks = locks, rx = Random.new(2602 + 9000), frost = {} }
		local slotsHI, slotsLO = {}, {}
		for i = 12, 0, -1 do
			local a1 = (i == 12) and -64.4 or colEdge(i + 1)
			local a2 = (i == 0) and 64.3 or colEdge(i)
			table.insert(slotsHI, { a1 = a1, a2 = a2, a0 = (a1 + a2) / 2, kind = "room", n = 13 - i })
			table.insert(slotsLO, { a1 = a1, a2 = a2, a0 = (a1 + a2) / 2, kind = (i == 4) and "stairs" or "room", n = 26 - i })
		end
		local function onLocked(R, num, spec)
			if extras[num] then
				lockedExtras(R, num, spec, extras[num])
			end
		end
		local rowHI = { name = "HI", axis = "u", wallAt = 4.75, dir = 1, far = 24.7, doorOff = -1.6, color = P.plasterB, slots = slotsHI, onLocked = onLocked }
		local rowLO = { name = "LO", axis = "u", wallAt = -4.65, dir = -1, far = -24.4, doorOff = -1.6, color = P.plasterB, slots = slotsLO, onLocked = onLocked }
		local stairHole = { 14.95, 24.05, -24.4, -9.35 }
		-- the window holes of the outer walls, and the plan of the rooms: every room has a window, so the washrooms (121, 221 where the
		-- old dice left them free) get frosted glass
		local hN, hS = {}, {}
		for _, sl in slotsHI do
			table.insert(hN, win(sl.a0))
		end
		for _, sl in slotsLO do
			table.insert(hS, sl.kind == "room" and win(sl.a0) or { sl.a0, 2.6, 2.0, 8.6 })
		end
		ctx.win = { HI = { hN, "N" }, LO = { hS, "S" } }
		ctx.plan = planDorm({
			seed = 2602, floors = FL, rows = { rowHI, rowLO }, locks = locks, ctx = ctx,
			wash = { ns = { 21, 25, 19, 17, 20 }, floors = { 1, 2 } },
		})
		for k = 1, FL do
			local y = ys[k]
			f:slab(U0, U1, VLO, VHI, y, SLAB, P.conc, M.Concrete, k >= 2 and { stairHole } or nil)
			local hE = { k == 1 and { VC, 3.9, 0, 7.5 } or win(VC, 3.0), win(15.0), win(-14.8) }
			local hW = { { VC, 3.9, 0, 7.5 }, win(15.0), win(-19.6) }
			f:wallU(VHI - 0.6, U0, U1, y, H10, 1.2, ext, extM, hN)
			glaze(f, "u", VHI - 0.6, -1, y, hN, "N", k, ctx)
			f:wallU(VLO + 0.6, U0, U1, y, H10, 1.2, ext, extM, hS)
			glaze(f, "u", VLO + 0.6, 1, y, hS, "S", k, ctx)
			f:wallV(U1 - 0.6, VLO + 1.2, VHI - 1.2, y, H10, 1.2, ext, extM, hE)
			glaze(f, "v", U1 - 0.6, -1, y, hE, "E", k, ctx)
			f:wallV(U0 + 0.6, VLO + 1.2, VHI - 1.2, y, H10, 1.2, ext, extM, hW)
			glaze(f, "v", U0 + 0.6, 1, y, hW, "W", k, ctx)
			dormRow(f, y, k, rowHI, "B", ctx)
			dormRow(f, y, k, rowLO, "B", ctx)
			for _, i in { 1, 4, 7, 10 } do
				f:lamp(colC(i), y + 9.6, VC, 24, false)
			end
			f:lamp(19.5, y + 9.6, -7.2, 20, false)
		end
		dormStairs(f, { uc = 19.5, sgn = -1, vS = -9.35, vFar = -24.4, levels = FL, ys = { ys[1], ys[2], top } })
		f:door("LV_B_TE", "East exit", "v", VC, U1 - 0.6, ys[1], -1, nil, P.door, 0.5)
		dormTower(f, { s = -1, vs = -1, eF = U0, c = VC, levels = FL - 1, ys = ys, top = top, color = ext, mat = extM, doorId = "LV_B_TW" })
		f:slab(U0, U1, VLO, VHI, top, SLAB, P.roof, M.Concrete, { stairHole })
		parapet(f, top, {
			{ "u", VHI - 0.4, U0, U1 }, { "u", VLO + 0.4, U0, U1 }, { "v", U1 - 0.4, VLO, VHI },
			{ "v", U0 + 0.4, VC + 3.0, VHI }, { "v", U0 + 0.4, VLO, VC - 14.8 },
		})
		dormHut(f, { uc = 19.5, vNear = -4.65, vOuter = -25.0, top = top, sgn = -1 }, "LV_B_ROOF")
		f:prop("HVAC", -20, top, 12, 0)
		f:prop("Vent", 30, top, -10, 0)
		local y1 = ys[1]
		f:stash("OfficeDesk", "LV_BLOBD", "drawer", "Warden's desk", -56.35, y1, 2.85, 0)
		f:prop("Chair", -56.35, y1, -0.4, 180)
		f:stash("Lockers", "LV_BLOBL", "locker", "Cloakroom lockers", -46.45, y1, -2.65, 180)
		f:prop("Bench", 32.75, y1, 3.4, 0)
		f:loose(-56.35, y1 + 4.4, 2.85, "office", 0.5)
		points.BLOCK_B_LOBBY = f:pt(-51.5, y1 + 0.5, VC)
		points.BLOCK_B_STAIRS = f:pt(19.5, y1 + 0.5, -7.2)
	end

	-- ── shared bits for the smaller buildings ────────────────────────────────────────────────────────────────────────
	-- the four walls of a rectangle u0..u1 / v0..v1 on floor y; holes per side: n (the v0 wall), s (v1), w (u0), e (u1)
	local function shell(f, u0, u1, v0, v1, y, h, t, color, mat, holes)
		holes = holes or {}
		f:wallU(v0 + t / 2, u0, u1, y, h, t, color, mat, holes.n)
		f:wallU(v1 - t / 2, u0, u1, y, h, t, color, mat, holes.s)
		f:wallV(u0 + t / 2, v0 + t, v1 - t, y, h, t, color, mat, holes.w)
		f:wallV(u1 - t / 2, v0 + t, v1 - t, y, h, t, color, mat, holes.e)
	end
	local function plateSign(f, text, u, y, v, ry, w, h, color, bg)
		local p = f:box(w, h, 0.3, u, y, v, bg or P.steel, M.Metal, ry)
		kit.sign(p, Enum.NormalId.Front, text, color or P.white, bg or P.steel)
		return p
	end
	-- a petrol pump on an island (its faces look along +-u): base, body, display head, a nozzle stub
	local function pump(f, u, v, color, y)
		f:blk(1.8, 0.5, 2.4, u, y, v, P.concDk, M.Concrete)
		f:blk(1.3, 4.6, 2.0, u, y + 0.5, v, color, M.Metal)
		f:blk(1.4, 0.9, 1.6, u, y + 5.1, v, P.steel, M.Metal)
		f:blk(0.2, 1.3, 0.3, u + 0.75, y + 2.4, v - 0.6, P.tar, M.Metal)
		f:blk(0.2, 1.3, 0.3, u - 0.75, y + 2.4, v + 0.6, P.tar, M.Metal)
	end
	-- a thin paved apron (top at 0.2 over the ground)
	local function apron(f, u0, u1, v0, v1, color)
		f:slab(u0, u1, v0, v1, 0.2, 0.4, color or P.concDk, M.Concrete)
	end

	-- ── FUEL STOP ────────────────────────────────────────────────────────────────────────────────────────────────────
	local function fuelStop(b)
		local f = newFrame(b, "FUEL STOP")
		local y1 = 0.5
		local WALL = P.plasterY
		-- the shop: sales floor, a till office and a storeroom behind it (both locked), a washroom with its own door outside
		f:slab(-32, 24, 16, 38.1, y1, SLAB, P.concDk, M.Concrete)
		f:slab(-32, 24, 16, 38.1, y1 + 11, SLAB, P.roof, M.Concrete)
		shell(f, -32, 24, 16, 38.1, y1, 10, 1.2, WALL, M.Concrete, {
			n = { { 1.5, 3.9, 0, 7.5 }, { -6.5, 8, 1.6, 8.2 }, { 13.5, 8, 1.6, 8.2 }, { -28.7, 3.9, 0, 7.5 }, { -19.5, 3.0, 3.0, 7.0 } },
			s = { win(-28.7, 2.6, 4.0, 7.0), win(-6), win(10) },
			w = { win(22, 2.4, 4.5, 7.0), win(32.5, 2.4, 4.5, 7.0) },
			e = { { 27, 3.9, 0, 7.5 } },
		})
		f:wallV(-13.25, 17.2, 36.9, y1, 10, TI, P.plaster, M.Plaster, { { 20.95, 3.9, 0, 7.5 }, { 30.5, 3.9, 0, 7.5 } })
		f:wallV(-25.15, 17.2, 36.9, y1, 10, TI, P.plaster, M.Plaster)
		-- the till office and the storeroom behind it: the partition stands at 26.4 so the office takes its desk, safe and
		-- locker clear of each other and of the door's swing (at 23.4 the safe stood in the desk's chair and the locker in
		-- the door's way; placement audit 2026-11-02)
		f:wallU(26.4, -25.55, -12.85, y1, 10, TI, P.plaster, M.Plaster)
		f:wallU(27.5, -30.8, -25.55, y1, 10, TI, P.plasterB, M.Plaster, { { -28.3, 3.9, 0, 7.5 } })
		f:door("LV_FUEL_FRONT", "Shop door", "u", 1.5, 16.6, y1, 1, nil, P.metalGry, 0.5)
		f:door("LV_FUEL_WC", "Washroom", "u", -28.7, 16.6, y1, 1, nil, P.door, 0.4)
		f:door("LV_FUEL_WC2", "Cubicle", "u", -28.3, 27.5, y1, 1, nil, P.door, 0.5)
		f:door("LV_FUEL_BACK", "Staff door", "v", 27, 23.4, y1, -1, nil, P.metalGry, 0.2)
		f:door("LV_FUEL_OFFICE", "Till office", "v", 20.95, -13.25, y1, -1, "KEY_BY_FUELTILL", P.doorDk)
		f:door("LV_FUEL_STORE", "Storeroom", "v", 30.5, -13.25, y1, -1, "KEY_BY_FUELSTORE", P.doorDk)
		parapet(f, y1 + 11, { { "u", 16.4, -32, 24 }, { "u", 37.7, -32, 24 }, { "v", -31.6, 16.4, 37.7 }, { "v", 23.6, 16.4, 37.7 } })
		f:prop("HVAC", -2, y1 + 11, 28, 0)
		-- sales floor: counter with the till, gondolas, fridges, shelves
		f:blk(11, 3.3, 2.4, 11.5, y1, 20.5, P.timberDk, M.WoodPlanks)
		f:blk(11.6, 0.3, 3.0, 11.5, y1 + 3.3, 20.5, P.board, M.WoodPlanks)
		local till = f:blk(1.8, 1.2, 1.4, 15.0, y1 + 3.6, 20.5, P.metalGry, M.Metal)
		f:container("LV_FUELTILL", "register", "Shop till", 15.0, y1 + 3.6, 20.5, 0, till)
		f:prop("Bin", 4.6, y1, 18.4, 0)
		for i, g in { { -5.5, 26.0 }, { 3.5, 27.0 }, { -2.0, 32.0 } } do
			f:stash("Gondola", "LV_FUELG" .. i, "grocery", "Shop shelf", g[1], y1, g[2], 0)
		end
		for i, u in { 10.5, 18.5 } do
			f:stash("Fridge", "LV_FUELF" .. i, "cooler", "Drinks fridge", u, y1, 34.45, 0)
		end
		f:prop("WallShelf", -8.5, y1, 35.85, 0)
		f:prop("WallShelf", -0.5, y1, 35.85, 0)
		f:prop("WallShelf", 21.75, y1, 21.3, 90)
		f:loose(11.5, y1 + 3.9, 20.5, "register", 0.5)
		f:loose(-5.5, y1 + 3.2, 26.0, "grocery", 0.45)
		f:loose(3.5, y1 + 3.2, 27.0, "drinks", 0.45)
		f:loose(-2.0, y1 + 3.2, 32.0, "grocery", 0.4)
		f:loose(8.0, y1 + 0.5, 29.5, "junk", 0.35)
		f:lamp(-2, y1 + 9.7, 24, 30, true)
		f:lamp(12, y1 + 9.7, 30, 30, true)
		-- till office (u -24.75 to -13.65, v 17.2 to 26.0): the desk with its chair against the front wall, the safe in the
		-- back corner, a staff locker on the back wall clear of the door
		f:stash("OfficeDesk", "LV_FUELOFD", "drawer", "Office desk", -21.75, y1, 18.7, 180)
		f:container("LV_FUELSAFE", "safe", "Fuel Stop safe", -23.25, y1, 24.7, 0)
		f:stash("Locker", "LV_FUELOFL", "locker", "Staff locker", -16.0, y1, 25.0, 0)
		f:loose(-21.75, y1 + 4.9, 18.75, "office", 0.6)
		f:loose(-20.2, y1 + 0.5, 24.8, "vault", 0.3)
		f:lamp(-19, y1 + 9.7, 21.6, 18, false)
		-- storeroom: stock shelves, a pallet, a toolbox
		f:stash("StorageShelf", "LV_FUELST1", "crate", "Stock shelf", -19.2, y1, 35.9, 0)
		f:stash("StorageShelf", "LV_FUELST2", "grocery", "Stock shelf", -19.2, y1, 27.8, 180)
		f:prop("PalletBoxes", -21.5, y1, 31.0, 0)
		f:toolbox("LV_FUELTB", "Storeroom toolbox", -14.6, y1, 33.8, 90)
		f:loose(-17.5, y1 + 0.5, 30.5, "junk", 0.5)
		f:loose(-24.0, y1 + 0.5, 30.0, "tech", 0.3)
		f:lamp(-19, y1 + 9.7, 31.6, 18, false)
		-- washroom: sinks at the front, a cubicle behind
		f:prop("MirrorSink", -26.25, y1, 20.2, 90)
		f:box(2.6, 2.8, 2.2, -28.3, y1 + 1.4, 35.0, P.white, M.SmoothPlastic)
		f:prop("Bin", -26.6, y1, 33.0, 0)
		f:loose(-28.0, y1 + 0.5, 31.5, "junk", 0.3)
		f:lamp(-28.2, y1 + 9.7, 23, 14, false)
		-- the canopy over the pumps, on a paved forecourt
		apron(f, -40, 34, -30, 16)
		f:slab(-36, 30, -28, 4, 15.2, 1.2, P.panel, M.Concrete)
		for _, c in { { -34, -26 }, { -2, -26 }, { 28, -26 }, { -34, 2 }, { -2, 2 }, { 28, 2 } } do
			f:cylV(14.0, 1.3, c[1], 0, c[2], P.steel, M.Metal)
		end
		for _, u in { -26, -6, 14 } do
			f:lamp(u, 14.0, -12, 30, false)
		end
		f:blk(66, 0.8, 0.3, -3, 14.4, -28.1, P.yellow, M.Metal)
		for i, vv in { -19.0, -7.0 } do
			f:blk(18, 0.5, 3.4, -4, 0, vv, P.concDk, M.Concrete)
			for _, uu in { -9, 1 } do
				pump(f, uu, vv, i == 1 and P.metalRed or P.metalBlu, 0.5)
			end
		end
		f:prop("CarSedan", -4, 0.2, -13.0, 90)
		f:prop("CarHatch", 14, 0.2, 8.0, 90)
		f:prop("OilStain", 2, 0.2, -13.0, 0)
		f:blk(1.0, 28, 1.0, -46, 0, -30, P.steel, M.Metal)
		plateSign(f, "FUEL", -46, 30, -30.2, 0, 9, 7, P.yellow, hex("1E2A33"))
		-- car park: bay lines, barriers, a wreck
		apron(f, 26, 52, 12, 34)
		for k = 0, 4 do
			f:blk(0.3, 0.06, 14, 30 + k * 5.5, 0.2, 20, P.white, M.SmoothPlastic)
		end
		f:prop("ParkingBarrier", 40, 0.2, 31.5, 0)
		f:prop("CarSedanSmashed", 41.5, 0.2, 19.5, 5)
		f:loose(47.5, 0.7, 19.5, "junk", 0.4)
		f:loose(-4, 0.7, -9.2, "junk", 0.3)
		points.FUEL_SHOP = f:pt(3, y1 + 0.5, 22)
		-- the open forecourt east of the pump islands, under the canopy: home of the Broker's fuel-stop zone (Reshala's
		-- new gas station on Customs; audit ai.3)
		points.FUEL_STOP_FORECOURT = f:pt(16, y1 + 0.5, -12)
	end

	-- ── OLD PUMPS ────────────────────────────────────────────────────────────────────────────────────────────────────
	local function oldPumps(b)
		local f = newFrame(b, "OLD PUMPS")
		local y1 = 0.5
		local WALL = P.brickDk
		f:slab(-20, -3, -8, 8, y1, SLAB, P.concDk, M.Concrete)
		f:slab(-20, -3, -8, 8, y1 + 11, SLAB, P.roof, M.Concrete)
		shell(f, -20, -3, -8, 8, y1, 10, 1.2, WALL, M.Brick, {
			n = { win(-8, 3.0), win(-16, 3.0) },
			s = { win(-10, 3.0) },
			w = { win(0, 3.0) },
			e = { { -0.5, 3.9, 0, 7.5 }, { -5.5, 5.0, 1.8, 7.8 } },
		})
		f:wallV(-12.5, -6.8, 0.2, y1, 10, TI, P.plaster, M.Plaster, { { -2.8, 3.9, 0, 7.5 } })
		f:wallU(-0.2, -18.8, -12.1, y1, 10, TI, P.plaster, M.Plaster)
		f:door("LV_PUMPS_FRONT", "Shop door", "v", -0.5, -3.6, y1, -1, nil, P.metalGry, 0.5)
		f:door("LV_PUMPS_BACK", "Back room", "v", -2.8, -12.5, y1, 1, "KEY_BY_PUMPS", P.doorDk)
		f:blk(7, 3.3, 2.1, -8.5, y1, 3.3, P.timberDk, M.WoodPlanks)
		f:blk(7.6, 0.3, 2.7, -8.5, y1 + 3.3, 3.3, P.board, M.WoodPlanks)
		local till = f:blk(1.6, 1.1, 1.3, -6.2, y1 + 3.6, 3.3, P.metalGry, M.Metal)
		f:container("LV_PUMPSTILL", "register", "Old till", -6.2, y1 + 3.6, 3.3, 0, till)
		f:prop("WallShelf", -8.5, y1, 5.75, 0)
		f:stash("DisplayTable", "LV_PUMPSDT", "grocery", "Dusty display", -16.5, y1, 3.5, 90)
		f:prop("Vending", -6.5, y1, -5.25, 180)
		f:stash("Locker", "LV_PUMPSLK", "locker", "Mechanic's locker", -17.85, y1, -5.7, 180)
		-- turned along the counter, clear of the back door's swing (v -4.75 to -0.85) and of the counter (from v 2.25); at 90 degrees
		-- it either stood in the swing or touched the counter and was not placed
		f:stash("ToolChest", "LV_PUMPSTB", "toolbox", "Tool chest", -10.3, y1, 0.9, 0)
		f:prop("Drum", -14.5, y1, -5.8, 0)
		f:prop("JerryCans", -10.3, y1, -5.6, 0)
		f:loose(-8.5, y1 + 3.9, 3.3, "register", 0.4)
		f:loose(-16.5, y1 + 3.8, 3.5, "grocery", 0.4)
		f:loose(-9.0, y1 + 0.5, -2.0, "junk", 0.4)
		f:loose(-15.6, y1 + 0.5, -3.6, "toolbox", 0.35)
		f:lamp(-9, y1 + 9.7, 0, 22, true)
		f:lamp(-15.8, y1 + 9.7, -3.5, 14, false)
		parapet(f, y1 + 11, { { "u", -7.6, -20, -3 }, { "u", 7.6, -20, -3 }, { "v", -19.6, -8, 8 }, { "v", -3.4, -8, 8 } })
		-- the canopy, rusty, on four columns over a cracked apron
		apron(f, -3, 22, -16, 16, P.conc)
		f:slab(-3, 18, -12, 12, 13.2, 1.0, P.rustRoof, M.CorrodedMetal)
		for _, c in { { -1.5, -11 }, { -1.5, 11 }, { 16.5, -11 }, { 16.5, 11 } } do
			f:cylV(12.6, 1.1, c[1], 0, c[2], P.metalRed, M.CorrodedMetal)
		end
		f:blk(3, 0.5, 16, 8, 0.2, 0, P.concDk, M.Concrete)
		for _, vv in { -4.5, 4.5 } do
			pump(f, 8, vv, P.metalGry, 0.7)
		end
		f:prop("JerryCans", 12, 0.2, -9.6, 30)
		f:prop("TyreStack", 11.5, 0.2, 9.8, 0)
		f:prop("CarSedanSmashed", 13.5, 0.2, 0, 0)
		f:lamp(8, 12.2, 0, 24, false)
		f:loose(19.5, 0.7, 3, "junk", 0.4)
		points.OLD_PUMPS_SHOP = f:pt(-8, y1 + 0.5, 0)
	end

	-- n evenly spaced window holes between c0 and c1 on a wall; join() glues hole lists together
	local function wins(c0, c1, n, w, b, t)
		local out = {}
		for i = 1, n do
			table.insert(out, { c0 + (i - 0.5) * (c1 - c0) / n, w or 3.0, b or 3.0, t or 7.2 })
		end
		return out
	end
	local function join(...)
		local out = {}
		for _, l in { ... } do
			for _, h in l do
				table.insert(out, h)
			end
		end
		return out
	end

	-- ── THE SQUAT ────────────────────────────────────────────────────────────────────────────────────────────────────
	-- a gutted two-storey brick house: a hall down the middle, rooms either side, a stair in the south-west corner, an
	-- iron stair up the east wall, and a stash room that only the locked back door opens
	local function squat(b)
		local f = newFrame(b, "THE SQUAT")
		local y1, y2, top = 0.5, 11.5, 22.5
		local U0, U1, V0, V1 = -38.1, 38.1, -25.3, 25.3
		local ext, extM = P.brickDk, M.Brick
		local hole = { -36.1, -26.1, 10.6, 24.0 }
		f:slab(U0, U1, V0, V1, y1, SLAB, P.concDk, M.Concrete)
		f:slab(U0, U1, V0, V1, y2, SLAB, P.conc, M.Concrete, { hole })
		f:slab(U0, U1, V0, V1, top, SLAB, P.roof, M.Concrete)
		for k, y in { y1, y2 } do
			local g = (k == 1)
			f:wallU(V0 + 0.6, U0, U1, y, H10, 1.2, ext, extM, join(wins(-35, -8, 3, 3.2), g and { { 0, 3.9, 0, 7.5 } } or wins(-3, 3, 1, 3.2), wins(8, 35, 3, 3.2)))
			f:wallU(V1 - 0.6, U0, U1, y, H10, 1.2, ext, extM, join(wins(-35, -8, 3, 3.2), g and { { 13.7, 3.9, 0, 7.5 } } or wins(10, 17, 1, 3.2), wins(-3, 8, 2, 3.2), wins(24, 35, 2, 3.2)))
			f:wallV(U0 + 0.6, V0 + 1.2, V1 - 1.2, y, H10, 1.2, ext, extM, wins(-22, 22, 4, 3.2))
			f:wallV(U1 - 0.6, V0 + 1.2, V1 - 1.2, y, H10, 1.2, ext, extM, join(wins(-8, 8, 1, 3.2), wins(-24, -19, 1, 3.2), g and { { -16, 3.9, 0, 7.5 } } or { { 14.5, 3.9, 0, 7.5 } }, wins(18, 23, 1, 3.2)))
			-- the hall walls (doorways to every room that has one)
			local d16 = { { -16, 3.9, 0, 7.5 }, { 0, 3.9, 0, 7.5 }, { 16, 3.9, 0, 7.5 } }
			f:wallV(-6.0, V0 + 1.2, V1 - 1.2, y, H10, TI, P.plaster, M.Plaster, d16)
			f:wallV(6.0, V0 + 1.2, V1 - 1.2, y, H10, TI, P.plaster, M.Plaster, g and { d16[1], d16[2] } or d16)
			-- the room partitions
			f:wallU(-8.8, U0 + 1.2, -6.4, y, H10, TI, P.plaster, M.Plaster, { { -14, 3.9, 0, 7.5 } })
			f:wallU(8.6, U0 + 1.2, -6.4, y, H10, TI, P.plaster, M.Plaster, { { g and -16 or -28.85, 3.9, 0, 7.5 } })
			f:wallU(-8.8, 6.4, U1 - 1.2, y, H10, TI, P.plaster, M.Plaster, { { 28, 3.9, 0, 7.5 } })
			f:wallU(8.6, 6.4, U1 - 1.2, y, H10, TI, P.plaster, M.Plaster, { { 28, 3.9, 0, 7.5 } })
			f:wallV(21.2, 8.6, V1 - 1.2, y, H10, TI, P.plaster, M.Plaster, (not g) and { { 16, 3.9, 0, 7.5 } } or nil)
		end
		f:door("LV_SQUAT_FRONT", "Front door", "u", 0, V0 + 0.6, y1, 1, nil, P.door, 0.25)
		f:door("LV_SQUAT_E1", "East door", "v", -16, U1 - 0.6, y1, -1, nil, P.door, 0.4)
		f:door("LV_SQUAT_BACK", "Back door", "u", 13.7, V1 - 0.6, y1, -1, "KEY_BY_SQUAT", P.doorDk)
		f:door("LV_SQUAT_EUP", "Upper door", "v", 14.5, U1 - 0.6, y2, -1, nil, P.door, 0.5)
		f:door("LV_SQUAT_D1", "Kitchen door", "v", 0, -6.0, y1, 1, nil, P.door, 0.5)
		f:door("LV_SQUAT_D2", "Bedroom door", "v", 0, 6.0, y1, -1, nil, P.door, 0.5)
		f:door("LV_SQUAT_D3", "Back room", "u", 28, 8.6, y1, 1, nil, P.door, 0.3)
		f:door("LV_SQUAT_D4", "Landing door", "u", -28.85, 8.6, y2, -1, nil, P.door, 0.5)
		f:door("LV_SQUAT_D5", "Upstairs door", "v", 16, 6.0, y2, -1, nil, P.door, 0.5)
		-- the roof: a rusty gable over a flat deck
		f:gable(U0, U1, V0, V1, top, 16, "u", P.rustRoof, M.CorrodedMetal, P.brickDk)
		-- stairs: the dog-leg in the south-west corner, the iron flight outside the east wall up to the upper door
		dormStairs(f, { uc = -31.1, sgn = 1, vS = 10.6, vFar = 24.0, levels = 1, ys = { y1, y2, top }, run = 7.4 })
		f:rail(-26.0, 11.0, -26.0, 24.0, y2)
		f:rail(-36.1, 10.6, -31.0, 10.6, y2)
		f:flight(40.9, -2.85, y1, 11, 13.85, 4.7, "+v", nil, P.steel, M.DiamondPlate)
		f:slab(U1, 43.25, 11.0, 17.0, y2, 0.6, P.steel, M.DiamondPlate)
		f:rail(43.1, -2.85, 43.1, 17.0, y2 - 8.0 + 0.0)
		f:rail(43.1, 11.0, 43.1, 17.0, y2)
		f:rail(U1, 17.0, 43.1, 17.0, y2)
		for _, v in { 11.0, 17.0 } do
			f:cylV(y2 - 0.3, 0.5, 43.0, 0, v, P.steel, M.Metal)
		end

		-- ground floor: the hall, the living room, the kitchen, the stairs room, the party room, the bedroom, the stash, the junk room
		f:prop("Sofa", 4.0, y1, -9.8, 90)
		f:prop("CardboardPile", -3.5, y1, -20.5, 0)
		f:prop("Bin", -4.5, y1, 5.0, 0)
		f:loose(0, y1 + 0.5, -14, "junk", 0.4)
		f:loose(0, y1 + 0.5, 8, "dorm", 0.4)
		f:lamp(0, y1 + 9.7, -10, 30, true)
		f:lamp(0, y1 + 9.7, 12, 24, false)
		-- living room
		f:prop("Sofa", -20, y1, -22.4, 180)
		f:prop("Table", -20, y1, -15.5, 0)
		f:prop("Chair", -26, y1, -14.0, 90)
		f:prop("Chair", -14, y1, -16.0, -90)
		f:jacket("LV_SQUAT_J1", "Coat", -36.2, y1, -18, 90)
		f:loose(-20, y1 + 3.6, -15.5, "drinks", 0.5)
		points.BY_SQUAT = f:pt(-22.4, y1 + 3.15, -15.5) -- a task's quest item: on the living-room table, beside the drinks
		f:loose(-30, y1 + 0.5, -20, "dorm", 0.4)
		f:loose(-12, y1 + 0.5, -21, "junk", 0.4)
		f:lamp(-21, y1 + 9.7, -17, 24, false)
		-- kitchen
		f:stash("FridgeBroken", "LV_SQUAT_FR", "cooler", "Broken fridge", -34.0, y1, -2.0, -90)
		f:prop("FoodTable", -20, y1, 0, 0)
		f:prop("Chair", -23.5, y1, 3.5, 0)
		f:prop("Chair", -17, y1, -3.6, 180)
		f:stash("Counter", "LV_SQUAT_KC", "drawer", "Kitchen counter", -22, y1, -6.8, 180)
		f:loose(-20, y1 + 3.8, 0, "grocery", 0.5)
		f:loose(-12, y1 + 0.5, 3, "junk", 0.4)
		f:loose(-28, y1 + 0.5, 4.5, "drinks", 0.4)
		f:lamp(-21, y1 + 9.7, 0, 22, false)
		-- stairs room
		f:prop("StorageRackEmpty", -16, y1, 23.0, 0)
		f:prop("Drum", -9.5, y1, 21.0, 0)
		f:prop("Drum", -9.5, y1, 23.0, 0)
		f:stash("Locker", "LV_SQUAT_LK", "locker", "Rusty locker", -7.6, y1, 11.5, 90)
		f:loose(-18, y1 + 0.5, 17, "junk", 0.4)
		f:loose(-12, y1 + 0.5, 13, "tech", 0.3)
		f:lamp(-16, y1 + 9.7, 16, 20, false)
		-- party room
		f:prop("BunkBedMessy", 12, y1, -22.0, 0)
		f:prop("BunkBedMessy", 26, y1, -22.0, 0)
		f:prop("Sofa", 20, y1, -12.6, 0)
		f:prop("Table", 20, y1, -17.0, 0)
		f:prop("Speaker", 8.5, y1, -23.0, 20)
		f:prop("Speaker", 34.5, y1, -23.0, -20)
		f:loose(20, y1 + 3.6, -17, "drinks", 0.55)
		f:loose(14, y1 + 0.5, -16, "dorm", 0.4)
		f:loose(30, y1 + 0.5, -14, "junk", 0.4)
		f:lamp(20, y1 + 9.7, -16, 30, true)
		-- bedroom
		f:prop("Bed", 13.4, y1, 1.0, 0)
		f:prop("Bed", 28, y1, 1.0, 0)
		f:stash("OfficeDesk", "LV_SQUAT_OD", "drawer", "Desk drawers", 20, y1, -5.4, 180)
		f:stash("Locker", "LV_SQUAT_L2", "locker", "Locker", 36.0, y1, -5.0, -90)
		f:loose(20, y1 + 4.4, -5.4, "office", 0.45)
		f:loose(20, y1 + 0.5, 3, "dorm", 0.4)
		f:lamp(21, y1 + 9.7, 0, 22, false)
		-- the stash behind the locked back door
		f:container("LV_SQUAT_SAFE", "safe", "Hidden safe", 14.0, y1, 10.4, 180)
		f:gunCase("LV_SQUAT_GUN", "Weapon case", 9.4, y1, 17.0, 90)
		f:medbag("LV_SQUAT_MED", "Medical bag", 9.6, y1, 12.4, 0)
		f:stash("StorageShelfEmpty", "LV_SQUAT_ST", "crate", "Back room shelf", 18.8, y1, 17.0, 90)
		f:jacket("LV_SQUAT_J2", "Leather coat", 7.0, y1, 21.0, 90)
		f:loose(14, y1 + 0.5, 15, "vault", 0.5)
		f:loose(12, y1 + 0.5, 19, "dorm_good", 0.5)
		f:loose(17, y1 + 0.5, 22, "tech", 0.4)
		f:lamp(14, y1 + 9.7, 17, 18, false)
		-- junk room
		f:prop("PalletBoxes", 30, y1, 22.0, 0)
		f:prop("Drum", 22.8, y1, 11.0, 0)
		f:prop("Drum", 25.0, y1, 11.0, 0)
		f:stash("ToolChest", "LV_SQUAT_TC", "toolbox", "Tool chest", 35.4, y1, 15.0, -90)
		f:loose(29, y1 + 0.5, 17.5, "junk", 0.45)
		f:loose(24, y1 + 0.5, 20, "tech", 0.3)

		-- upper floor
		f:prop("CeilingDebris", 0, y2, 8, 0)
		f:prop("Bin", 4.5, y2, -3, 0)
		f:loose(0, y2 + 0.5, -8, "junk", 0.4)
		f:lamp(0, y2 + 9.7, -6, 26, false)
		f:lamp(0, y2 + 9.7, 14, 22, false)
		-- west rooms: a bunk room, a lounge, the landing room
		f:prop("BunkBedMessy", -30, y2, -22.0, 0)
		f:prop("Bed", -14, y2, -17.0, 0)
		f:stash("Locker", "LV_SQUAT_L3", "locker", "Locker", -36.0, y2, -15.0, 90)
		f:loose(-22, y2 + 0.5, -16, "dorm", 0.45)
		f:lamp(-21, y2 + 9.7, -16, 20, false)
		f:prop("Sofa", -20, y2, 6.3, 180)
		f:prop("Table", -20, y2, 0, 0)
		f:prop("Chair", -12, y2, 1.5, -90)
		f:jacket("LV_SQUAT_J3", "Old jacket", -36.2, y2, 0, 90)
		f:loose(-20, y2 + 3.6, 0, "drinks", 0.45)
		f:lamp(-21, y2 + 9.7, 0, 20, false)
		f:prop("StorageRackEmpty", -14, y2, 23.0, 0)
		f:loose(-14, y2 + 0.5, 18, "junk", 0.4)
		-- east rooms: a party floor, a bedroom, the landing room by the iron stair
		f:prop("BunkBedMessy", 14, y2, -22.0, 0)
		f:prop("Table", 26, y2, -15.5, 0)
		f:prop("Sofa", 31, y2, -22.0, 180)
		f:loose(26, y2 + 3.6, -15.5, "drinks", 0.5)
		f:loose(14, y2 + 0.5, -15, "dorm", 0.4)
		f:lamp(21, y2 + 9.7, -16, 22, false)
		f:prop("Bed", 13.4, y2, 1.0, 0)
		f:stash("OfficeDesk", "LV_SQUAT_OD2", "drawer", "Desk drawers", 22, y2, -5.4, 180)
		f:loose(22, y2 + 4.4, -5.4, "office", 0.45)
		f:lamp(21, y2 + 9.7, 0, 20, false)
		f:prop("Bed", 14, y2, 18.0, 0)
		f:medbag("LV_SQUAT_MED2", "Medical bag", 30.0, y2, 20.5, 0)
		f:stash("Locker", "LV_SQUAT_L4", "locker", "Locker", 36.0, y2, 20.0, -90)
		f:loose(28, y2 + 0.5, 14, "junk", 0.4)
		f:loose(14, y2 + 0.5, 12, "dorm", 0.4)
		f:lamp(28, y2 + 9.7, 16, 18, false)
		points.SQUAT = f:pt(0, y1 + 0.5, -2)
	end

	-- ── THE WATCHHOUSE ───────────────────────────────────────────────────────────────────────────────────────────────
	-- two brick wings of two floors with a lower hall between them: its roof is a terrace level with both upper floors.
	-- Stairs climb from the hall into each wing (ladder-15 east, ladder-16 west) and inside the west wing (ladder-31); two
	-- locked rooms sit in the west wing's south side.
	local function watchhouse(b)
		local f = newFrame(b, "WATCHHOUSE")
		local y1, y2, top = 0.5, 11.5, 22.5
		local U0, U1, V0, V1 = -69.85, 69.85, -33.75, 33.75
		local wing, mid = P.brick, P.panel
		-- holes in the terrace slab where the stairs arrive
		local h15 = { 23.0, 33.5, 18.3, 24.3 }
		local h16 = { -33.5, -22.5, 18.4, 24.4 }
		local h31 = { -51.5, -42.6, -31.3, -25.3 }
		f:slab(U0, U1, V0, V1, y1, SLAB, P.concDk, M.Concrete)
		f:slab(U0, U1, V0, V1, y2, SLAB, P.conc, M.Concrete, { h15, h16, h31 })
		f:slab(U0, -23.9, V0, V1, top, SLAB, P.roof, M.Concrete)
		f:slab(24.25, U1, -24.65, V1, top, SLAB, P.roof, M.Concrete)
		-- ground floor: outer walls
		local function colourAt(u)
			return (u < -24.1 or u > 24.25) and wing or mid
		end
		f:wallU(V0 + 0.6, U0, -24.1, y1, H10, 1.2, wing, M.Brick, join(wins(-66, -28, 5, 3.4)))
		f:wallU(V0 + 0.6, -24.1, 24.25, y1, H10, 1.2, mid, M.Concrete, { { -2, 3.9, 0, 7.5 }, { 2, 3.9, 0, 7.5 }, { -14, 5, 1.6, 8 }, { 14, 5, 1.6, 8 }, { -20, 2.4, 3, 7 }, { 20, 2.4, 3, 7 } })
		f:wallU(V0 + 0.6, 24.25, U1, y1, H10, 1.2, wing, M.Brick, { { 32, 3.4, 3, 7.2 }, { 40, 3.4, 3, 7.2 }, { 48, 3.4, 3, 7.2 }, { 56, 3.9, 0, 7.5 }, { 64, 3.4, 3, 7.2 } })
		f:wallU(V1 - 0.6, U0, -24.1, y1, H10, 1.2, wing, M.Brick, { { -63, 2.4, 4.5, 7.2 }, { -56, 2.4, 4.5, 7.2 }, { -45, 2.4, 4.5, 7.2 }, { -38, 2.4, 4.5, 7.2 }, { -28, 3.4, 3, 7.2 } })
		f:wallU(V1 - 0.6, -24.1, 24.25, y1, H10, 1.2, mid, M.Concrete, { { 0, 3.9, 0, 7.5 }, { -10, 3.4, 3, 7.2 }, { 10, 3.4, 3, 7.2 } })
		f:wallU(V1 - 0.6, 24.25, U1, y1, H10, 1.2, wing, M.Brick, wins(30, 68, 4, 3.4))
		f:wallV(U0 + 0.6, V0 + 1.2, V1 - 1.2, y1, H10, 1.2, wing, M.Brick, wins(-28, 28, 5, 3.4))
		f:wallV(U1 - 0.6, V0 + 1.2, V1 - 1.2, y1, H10, 1.2, wing, M.Brick, { { -22, 3.4, 3, 7.2 }, { -12, 3.4, 3, 7.2 }, { 0, 3.9, 0, 7.5 }, { 12, 3.4, 3, 7.2 }, { 24, 3.4, 3, 7.2 } })
		-- the hall's end walls, with doorways and the arches the stairs pass through
		f:wallV(-24.1, V0 + 1.2, V1 - 1.2, y1, H10, TI, P.plaster, M.Plaster, { { -20, 3.9, 0, 7.5 }, { 0, 5.0, 0, 7.5 }, { 21.4, 8.8, 0, 10 } })
		f:wallV(24.25, V0 + 1.2, V1 - 1.2, y1, H10, TI, P.plaster, M.Plaster, { { -20, 3.9, 0, 7.5 }, { 0, 5.0, 0, 7.5 }, { 21.3, 8.8, 0, 10 } })
		-- west wing: the two locked rooms
		f:wallU(15.0, U0 + 1.2, -49.2, y1, H10, TI, P.plaster, M.Plaster, { { -59, 3.9, 0, 7.5 } })
		f:wallV(-49.2, 15.0, V1 - 1.2, y1, H10, TI, P.plaster, M.Plaster)
		f:wallU(18.4, -49.2, -33.4, y1, H10, TI, P.plaster, M.Plaster, { { -41, 3.9, 0, 7.5 } })
		f:wallV(-33.4, 18.4, V1 - 1.2, y1, H10, TI, P.plaster, M.Plaster)
		-- east wing: the briefing room and the barracks
		f:wallU(-8.8, 24.65, U1 - 1.2, y1, H10, TI, P.plaster, M.Plaster, { { 30, 3.9, 0, 7.5 } })
		f:door("LV_WATCH_FRONT1", "Front door", "u", -2, V0 + 0.6, y1, 1, nil, P.metalGry, 0.3)
		f:door("LV_WATCH_FRONT2", "Front door", "u", 2, V0 + 0.6, y1, 1, nil, P.metalGry, 0.3)
		f:door("LV_WATCH_BACK", "Back door", "u", 0, V1 - 0.6, y1, -1, nil, P.door, 0.2)
		f:door("LV_WATCH_NE", "North door", "u", 56, V0 + 0.6, y1, 1, nil, P.door, 0.3)
		f:door("LV_WATCH_E1", "East door", "v", 0, U1 - 0.6, y1, -1, nil, P.door, 0.3)
		f:door("LV_WATCH_RB", "Watch room", "u", -59, 15.0, y1, 1, "KEY_BY_WATCHROOM", P.doorDk)
		points.BY_WATCHROOM = f:pt(-52.5, y1 + 0.05, 23) -- a task's quest item: the floor of the locked watch room, past the desk
		f:door("LV_WATCH_RA", "Store room", "u", -41, 18.4, y1, 1, "KEY_BY_WATCHSTORE", P.doorDk)
		f:door("LV_WATCH_D1", "Briefing room", "u", 30, -8.8, y1, 1, nil, P.door, 0.5)
		-- upper floors
		f:wallU(V0 + 0.6, U0, -23.9, y2, H10, 1.2, wing, M.Brick, wins(-66, -28, 5, 3.4))
		f:wallU(V1 - 0.6, U0, -23.9, y2, H10, 1.2, wing, M.Brick, wins(-66, -28, 5, 3.4))
		f:wallV(U0 + 0.6, V0 + 1.2, V1 - 1.2, y2, H10, 1.2, wing, M.Brick, wins(-28, 28, 5, 3.4))
		f:wallV(-24.5, V0 + 1.2, V1 - 1.2, y2, H10, 1.2, wing, M.Brick, { { -10, 3.9, 0, 7.5 }, { -22, 3.4, 3, 7.2 }, { 8, 3.4, 3, 7.2 } })
		f:wallU(3.0, U0 + 1.2, -25.1, y2, H10, TI, P.plaster, M.Plaster, { { -40, 3.9, 0, 7.5 } })
		f:wallU(-24.05, 24.25, U1, y2, H10, 1.2, wing, M.Brick, { { 45, 3.9, 0, 7.5 }, { 33, 3.4, 3, 7.2 }, { 57, 3.4, 3, 7.2 }, { 65, 3.4, 3, 7.2 } })
		f:wallU(V1 - 0.6, 24.25, U1, y2, H10, 1.2, wing, M.Brick, wins(30, 68, 4, 3.4))
		f:wallV(U1 - 0.6, -23.45, V1 - 1.2, y2, H10, 1.2, wing, M.Brick, wins(-18, 28, 4, 3.4))
		f:wallV(24.85, -23.45, V1 - 1.2, y2, H10, 1.2, wing, M.Brick, { { -10, 3.9, 0, 7.5 }, { 8, 3.4, 3, 7.2 }, { 27, 3.4, 3, 7.2 } })
		f:wallU(3.0, 25.45, U1 - 1.2, y2, H10, TI, P.plaster, M.Plaster, { { 48, 3.9, 0, 7.5 } })
		f:door("LV_WATCH_T1", "Terrace door", "v", -10, -24.5, y2, 1, nil, P.metalGry, 0.4)
		f:door("LV_WATCH_T2", "Terrace door", "v", -10, 24.85, y2, -1, nil, P.metalGry, 0.4)
		f:door("LV_WATCH_T3", "Terrace door", "u", 45, -24.05, y2, 1, nil, P.metalGry, 0.4)
		f:door("LV_WATCH_D2", "Bunk room", "u", -40, 3.0, y2, 1, nil, P.door, 0.5)
		f:door("LV_WATCH_D3", "Barrack room", "u", 48, 3.0, y2, 1, nil, P.door, 0.5)
		-- the terrace edge and the roof edges
		parapet(f, y2, { { "u", V0 + 0.4, -23.9, U1 }, { "u", V1 - 0.4, -23.9, 24.25 }, { "v", U1 - 0.4, V0, -24.65 } })
		parapet(f, top, { { "u", V0 + 0.4, U0, -23.9 }, { "u", V1 - 0.4, U0, -23.9 }, { "v", U0 + 0.4, V0, V1 }, { "v", -24.2, V0, V1 } })
		parapet(f, top, { { "u", V1 - 0.4, 24.25, U1 }, { "u", -24.25, 24.25, U1 }, { "v", U1 - 0.4, -24.65, V1 }, { "v", 24.5, -24.65, V1 } })
		-- stairs
		f:flight(14.9, 21.3, y1, 11, 18.4, 6.0, "+u", 0, P.conc, M.Concrete)
		f:flight(-16.0, 21.4, y1, 11, 17.0, 6.0, "-u", 0, P.conc, M.Concrete)
		f:flight(-58.1, -28.3, y1, 11, 15.0, 6.0, "+u", 0, P.conc, M.Concrete)
		for _, r in { { 23.0, 18.3, 23.0, 24.3 }, { 23.0, 18.3, 33.5, 18.3 }, { 23.0, 24.3, 33.5, 24.3 }, { -22.5, 18.4, -22.5, 24.4 }, { -33.5, 18.4, -22.5, 18.4 }, { -33.5, 24.4, -22.5, 24.4 }, { -51.5, -25.3, -42.6, -25.3 }, { -51.5, -31.3, -51.5, -25.3 } } do
			f:rail(r[1], r[2], r[3], r[4], y2)
		end
		f:lamp(-30, y2 - 1.5, 21.4, 14, false)
		f:lamp(30, y2 - 1.5, 21.3, 14, false)

		-- the middle hall: front desk, CCTV, seating, a vending machine
		f:prop("CCTVDesk", -12, y1, -30.6, 180)
		f:stash("Counter", "LV_WATCH_RC", "drawer", "Reception desk", 10, y1, -22, 0)
		f:prop("Sofa", -17, y1, -8, 90)
		f:prop("Sofa", 17, y1, 8, -90)
		f:prop("Table", 0, y1, 4, 0)
		f:prop("Vending", -22.0, y1, 6, 90)
		f:loose(10, y1 + 3.9, -22, "office", 0.5)
		f:loose(0, y1 + 3.8, 4, "drinks", 0.45)
		f:loose(-8, y1 + 0.5, -12, "junk", 0.4)
		f:loose(8, y1 + 0.5, 14, "junk", 0.4)
		f:lamp(-6, y1 + 9.7, -12, 32, true)
		f:lamp(6, y1 + 9.7, 8, 32, true)
		-- west wing ground: the mess, the kitchen, the lockers
		f:prop("Table", -45, y1, -12, 0)
		f:prop("Table", -35, y1, 0, 0)
		f:stash("Fridge", "LV_WATCH_FR", "cooler", "Fridge", -66.4, y1, -20, -90)
		f:stash("Lockers", "LV_WATCH_LK", "locker", "Lockers", -66.8, y1, -4, -90)
		f:prop("Sofa", -34.5, y1, -22.5, 0)
		f:loose(-45, y1 + 3.6, -12, "grocery", 0.45)
		f:loose(-35, y1 + 3.6, 0, "drinks", 0.45)
		f:loose(-55, y1 + 0.5, 4, "junk", 0.4)
		f:lamp(-40, y1 + 9.7, -6, 30, true)
		f:lamp(-60, y1 + 9.7, -8, 20, false)
		-- the watch room (locked): a safe, a weapon case, a coat
		f:container("LV_WATCH_SAFE", "safe", "Watch room safe", -60, y1, 31.2, 0)
		f:gunCase("LV_WATCH_GUN", "Weapon case", -67.0, y1, 26.5, 90)
		f:jacket("LV_WATCH_J", "Duty coat", -52.0, y1, 31.8, 0)
		f:stash("OfficeDesk", "LV_WATCH_OD", "drawer", "Duty desk", -58, y1, 20.5, 180)
		f:loose(-58, y1 + 4.4, 20.5, "office", 0.55)
		f:loose(-62, y1 + 0.5, 26, "vault", 0.5)
		f:loose(-54, y1 + 0.5, 27, "dorm_good", 0.5)
		f:loose(-65, y1 + 0.5, 22, "dorm_good", 0.5)
		f:lamp(-59, y1 + 9.7, 24, 20, false)
		-- the store room (locked): shelving, pallets, a medical shelf
		f:stash("StorageShelf", "LV_WATCH_S1", "crate", "Stock shelf", -41, y1, 31.5, 0)
		f:stash("MedShelf", "LV_WATCH_MS", "medbag", "Medical shelf", -45.6, y1, 25, -90)
		f:prop("PalletBoxes", -38, y1, 24.5, 0)
		f:toolbox("LV_WATCH_TB", "Tool box", -44, y1, 21.5, 0)
		f:loose(-41, y1 + 0.5, 26, "junk", 0.5)
		f:loose(-37, y1 + 0.5, 29, "tech", 0.45)
		f:lamp(-41, y1 + 9.7, 25, 18, false)
		-- east wing ground: the briefing room and the barracks
		f:prop("MapTable", 46, y1, -21, 0)
		f:stash("GunRack", "LV_WATCH_GR", "weaponbox", "Gun rack", 58, y1, -32.0, 180)
		f:prop("Locker", 28, y1, -30.5, 0)
		f:loose(46, y1 + 3.6, -21, "office", 0.45)
		f:loose(34, y1 + 0.5, -14, "junk", 0.4)
		f:lamp(46, y1 + 9.7, -21, 34, true)
		for i, u in { 40.5, 48.5, 56.5, 64.5 } do
			f:prop("BunkBed", u, y1, -6.5, 0)
		end
		f:stash("Lockers", "LV_WATCH_LK2", "locker", "Barrack lockers", 66.0, y1, 10, -90)
		f:prop("Bed", 44, y1, 28, 0)
		f:prop("Table", 56, y1, 14, 0)
		f:loose(56, y1 + 3.6, 14, "dorm", 0.45)
		f:loose(48, y1 + 0.5, 8, "dorm", 0.4)
		f:loose(60, y1 + 0.5, 24, "junk", 0.4)
		f:lamp(52, y1 + 9.7, 12, 26, false)
		-- west wing upstairs: the bunk room (south) and the recreation room (north)
		for _, u in { -62, -54, -46, -38 } do
			f:prop("BunkBed", u, y2, 31.0, 0)
		end
		f:stash("Locker", "LV_WATCH_L3", "locker", "Locker", -67.3, y2, 12, 90)
		f:prop("Table", -45, y2, 14, 0)
		f:loose(-45, y2 + 3.6, 14, "dorm", 0.45)
		f:loose(-60, y2 + 0.5, 20, "dorm", 0.4)
		f:lamp(-50, y2 + 9.7, 18, 26, false)
		f:prop("TVWall", -60, y2, -31.4, 180)
		f:prop("Sofa", -60, y2, -22, 180)
		f:prop("Table", -35, y2, -14, 0)
		f:loose(-35, y2 + 3.6, -14, "drinks", 0.5)
		f:loose(-62, y2 + 0.5, -10, "junk", 0.4)
		f:lamp(-45, y2 + 9.7, -14, 26, false)
		-- east wing upstairs: the watch room and the bedrooms
		f:stash("OfficeDesk", "LV_WATCH_OD2", "drawer", "Watch desk", 40, y2, -20.4, 180)
		f:prop("Whiteboard", 58, y2, -23.5, 180)
		f:medbag("LV_WATCH_MED", "Medical bag", 64, y2, -8, 0)
		f:loose(40, y2 + 4.4, -20.4, "office", 0.5)
		f:loose(50, y2 + 0.5, -10, "junk", 0.4)
		f:lamp(46, y2 + 9.7, -12, 26, false)
		f:prop("Bed", 40, y2, 12, 0)
		f:prop("Bed", 52, y2, 12, 0)
		f:stash("Locker", "LV_WATCH_L4", "locker", "Locker", 67.6, y2, 22, -90)
		f:loose(46, y2 + 0.5, 24, "dorm", 0.4)
		f:lamp(52, y2 + 9.7, 16, 22, false)
		-- the terrace: a watch post
		f:prop("HVAC", 12, y2, 24, 0)
		f:prop("SandbagsLow", -6, y2, -31.6, 0)
		f:prop("SandbagsLow", 6, y2, -31.6, 0)
		f:prop("WorkLight", 18, y2, -28, 0)
		f:loose(0, y2 + 0.5, -26, "junk", 0.35)
		f:loose(-10, y2 + 0.5, 6, "tech", 0.3)
		f:prop("HVAC", -50, top, 10, 0)
		points.WATCHHOUSE_TOP = f:pt(0, y2 + 0.5, -2)
	end

	-- a dog-leg stair of any orientation: from its open edge `a0` two lanes (width `lane`) climb 5.5 studs per level along
	-- `dirA` ("+u" "-u" "+v" "-v"), a landing at the far end, then the second lane comes back to the open edge. `c` is
	-- the stair's centre line across the flights; the far (landing) end is at `a1`.
	-- g = { alongU, c, a0, a1, run, levels, ys, lane }
	local function dogleg(f, g)
		local lane = g.lane or 4.0
		local off = lane / 2 + 0.25
		local sgn = (g.a1 > g.a0) and 1 or -1
		local aE = g.a0 + sgn * g.run
		local dirOut, dirBack
		if g.alongU then
			dirOut, dirBack = (sgn > 0) and "+u" or "-u", (sgn > 0) and "-u" or "+u"
		else
			dirOut, dirBack = (sgn > 0) and "+v" or "-v", (sgn > 0) and "-v" or "+v"
		end
		local function at(a, b)
			if g.alongU then
				return a, b
			end
			return b, a
		end
		local function slabAt(a0, a1, y, th)
			local lo, hi = math.min(a0, a1), math.max(a0, a1)
			if g.alongU then
				f:slab(lo, hi, g.c - off - lane / 2, g.c + off + lane / 2, y, th, P.conc, M.Concrete)
			else
				f:slab(g.c - off - lane / 2, g.c + off + lane / 2, lo, hi, y, th, P.conc, M.Concrete)
			end
		end
		for k = 1, g.levels do
			local y = g.ys[k]
			local solid = (k == 1)
			local ua, va = at(g.a0, g.c - off)
			f:flight(ua, va, y, 5.5, g.run, lane, dirOut, solid and 0 or nil, P.conc, M.Concrete)
			if solid then
				local lo, hi = math.min(aE, g.a1), math.max(aE, g.a1)
				local w = off * 2 + lane
				local ctr = (lo + hi) / 2
				if g.alongU then
					f:blk(hi - lo, y + 5.5, w, ctr, 0, g.c, P.conc, M.Concrete)
				else
					f:blk(w, y + 5.5, hi - lo, g.c, 0, ctr, P.conc, M.Concrete)
				end
			else
				slabAt(aE, g.a1, y + 5.5, SLAB)
			end
			local ub, vb = at(aE, g.c + off)
			f:flight(ub, vb, y + 5.5, 5.5, g.run, lane, dirBack, solid and 0 or nil, P.conc, M.Concrete)
		end
		local top = g.ys[g.levels + 1]
		local mu, mv = at((g.a0 + aE) / 2, g.c)
		if g.alongU then
			f:box(g.run, top - g.ys[1], 0.5, mu, (g.ys[1] + top) / 2, mv, P.plaster, M.Plaster)
		else
			f:box(0.5, top - g.ys[1], g.run, mu, (g.ys[1] + top) / 2, mv, P.plaster, M.Plaster)
		end
	end

	-- ── ARMY POST: the hut and the barracks ─────────────────────────────────────────────────────────────────────────
	-- the hut: a duty room and a locked armoury below, a guard room above, a stair that climbs to a roof with a perch
	local function armyHut(b)
		local f = newFrame(b, "ARMY POST HUT")
		local y1, y2, top = 0.5, 11.5, 22.5
		local U0, U1, V0, V1 = -12.8, 12.8, -12.5, 12.5
		local ext = P.panelDk
		local hole = { 3.1, 12.3, 2.8, 11.5 }
		f:slab(U0, U1, V0, V1, y1, SLAB, P.concDk, M.Concrete)
		f:slab(U0, U1, V0, V1, y2, SLAB, P.conc, M.Concrete, { hole })
		f:slab(U0, U1, V0, V1, top, SLAB, P.roof, M.Concrete, { hole })
		for k, y in { y1, y2 } do
			local g = (k == 1)
			f:wallU(V0 + 0.6, U0, U1, y, H10, 1.2, ext, M.Concrete, g and { { -8, 2.4, 4.5, 7.2 }, { 0, 2.4, 4.5, 7.2 }, { 8, 2.4, 4.5, 7.2 } } or wins(-10, 10, 3, 3.2))
			f:wallU(V1 - 0.6, U0, U1, y, H10, 1.2, ext, M.Concrete, g and { { -6, 3.9, 0, 7.5 }, { 2, 3.2, 3, 7.2 }, { 9, 3.2, 3, 7.2 } } or wins(-10, 10, 3, 3.2))
			f:wallV(U0 + 0.6, V0 + 1.2, V1 - 1.2, y, H10, 1.2, ext, M.Concrete, g and { { -6, 2.6, 4, 7.2 }, { 7, 3.2, 3, 7.2 } } or wins(-10, 10, 3, 3.2))
			f:wallV(U1 - 0.6, V0 + 1.2, V1 - 1.2, y, H10, 1.2, ext, M.Concrete, g and { { -6, 2.6, 4, 7.2 }, { 7, 3.2, 3, 7.2 } } or wins(-10, 10, 3, 3.2))
		end
		f:wallU(2.3, U0 + 1.2, U1 - 1.2, y1, H10, TI, P.plaster, M.Plaster, { { -4, 3.9, 0, 7.5 } })
		f:door("LV_ARMY_FRONT", "Hut door", "u", -6, V1 - 0.6, y1, -1, nil, P.metalGry, 0.3)
		f:door("LV_ARMY_ARM", "Armoury", "u", -4, 2.3, y1, -1, "KEY_BY_ARMYHUT", P.doorDk)
		-- one stair for all three levels, along u, open edge at u = 3.1 (the duty room side)
		dogleg(f, { alongU = true, c = 7.0, a0 = 3.1, a1 = 12.3, run = 6.0, levels = 2, ys = { y1, y2, top }, lane = 3.8 })
		f:rail(3.1, 2.9, 3.1, 4.6, y2)
		f:rail(3.1, 2.9, 12.2, 2.9, y2)
		f:rail(3.1, 11.4, 12.2, 11.4, y2)
		f:rail(3.1, 2.9, 3.1, 4.6, top)
		f:rail(3.1, 2.9, 12.2, 2.9, top)
		f:rail(3.1, 11.4, 12.2, 11.4, top)
		f:rail(3.1, 8.0, 3.1, 11.4, top)
		parapet(f, top, { { "u", V0 + 0.4, U0, U1 }, { "u", V1 - 0.4, U0, U1 }, { "v", U0 + 0.4, V0, V1 }, { "v", U1 - 0.4, V0, V1 } })
		-- duty room
		f:stash("OfficeDesk", "LV_ARMY_OD", "drawer", "Duty desk", -10.0, y1, 7.7, -90)
		f:prop("Chair", -7.4, y1, 7.0, 90)
		f:prop("Bench", -0.4, y1, 10.35, 0)
		f:stash("Locker", "LV_ARMY_LK", "locker", "Duty locker", -10.4, y1, 3.7, 90)
		f:loose(-10.0, y1 + 4.4, 7.7, "office", 0.5)
		f:loose(-8, y1 + 0.5, 9, "junk", 0.4)
		f:lamp(-5, y1 + 9.7, 7, 20, true)
		-- the armoury (locked)
		f:stash("GunRack", "LV_ARMY_GR", "weaponbox", "Gun rack", 3, y1, -11.5, 180)
		f:stash("AmmoCrate", "LV_ARMY_AC1", "crate", "Ammo crate", 10, y1, -10.6, 0)
		f:stash("AmmoCrate", "LV_ARMY_AC2", "crate", "Ammo crate", -9, y1, -9.6, 90)
		f:stash("ArmorStand", "LV_ARMY_AS", "jacket", "Armour stand", -10.8, y1, -4, 0)
		f:container("LV_ARMY_SAFE", "safe", "Armoury safe", 10, y1, -3, 90)
		f:loose(0, y1 + 0.5, -6, "weaponbox", 0.5)
		f:loose(5, y1 + 0.5, -8, "vault", 0.4)
		f:loose(-4, y1 + 0.5, -9, "dorm_good", 0.5)
		points.BY_ARMYHUT = f:pt(-4, y1 + 0.05, -3) -- a task's quest item and place: the locked armoury's floor
		f:lamp(0, y1 + 9.7, -6, 18, false)
		-- guard room
		f:prop("Bed", -8.6, y2, -7.6, 0)
		f:prop("Bed", -2.8, y2, -7.6, 0)
		f:prop("Bed", 3.0, y2, -7.6, 0)
		f:stash("OfficeDesk", "LV_ARMY_OD2", "drawer", "Radio desk", -6, y2, 7, 180)
		f:stash("Locker", "LV_ARMY_L2", "locker", "Locker", 10.4, y2, -8, -90)
		f:prop("Chair", -6, y2, 10.5, 0)
		f:loose(-6, y2 + 4.4, 7, "office", 0.5)
		f:loose(-6, y2 + 0.5, 0, "dorm", 0.4)
		f:lamp(-4, y2 + 9.7, 0, 20, false)
		-- the roof perch
		f:prop("SandbagsLow", -7.6, top, -10.5, 0)
		f:prop("SandbagsLow", -1.2, top, -10.5, 0)
		f:prop("Sandbags", -10.5, top, -6.5, 90)
		f:prop("WorkLight", 8.5, top, -9.0, 0)
		f:loose(-7.0, top + 0.5, -8.5, "weaponbox", 0.3)
	end

	-- the barracks: one long corridor, bunk rooms to the north, mess, kitchen and office to the south
	local function armyBarracks(b)
		local f = newFrame(b, "ARMY POST BARRACKS")
		local y1 = 0.5
		local U0, U1, V0, V1 = -25.8, 25.8, -25.0, 25.0
		local ext = P.plasterG
		f:slab(U0, U1, V0, V1, y1, SLAB, P.concDk, M.Concrete)
		f:slab(U0, U1, V0, V1, y1 + 11, SLAB, P.roof, M.Concrete)
		local nw, sw = {}, {}
		for i = 1, 4 do
			local c = U0 + 6.45 + (i - 1) * 12.9
			table.insert(nw, { c, 3.2, 3, 7.2 })
			if i > 1 then
				table.insert(sw, { c, 3.2, 3, 7.2 })
			end
		end
		f:wallU(V0 + 0.6, U0, U1, y1, H10, 1.2, ext, M.Concrete, nw)
		f:wallU(V1 - 0.6, U0, U1, y1, H10, 1.2, ext, M.Concrete, join(sw, { { U0 + 6.45, 3.9, 0, 7.5 } }))
		f:wallV(U0 + 0.6, V0 + 1.2, V1 - 1.2, y1, H10, 1.2, ext, M.Concrete, { { 0, 3.9, 0, 7.5 }, { -14, 3.2, 3, 7.2 }, { 14, 3.2, 3, 7.2 } })
		f:wallV(U1 - 0.6, V0 + 1.2, V1 - 1.2, y1, H10, 1.2, ext, M.Concrete, { { 0, 3.9, 0, 7.5 }, { -14, 3.2, 3, 7.2 }, { 14, 3.2, 3, 7.2 } })
		-- the corridor walls and the room dividers
		local doorsN, doorsS = {}, {}
		for i = 1, 4 do
			local c = U0 + 6.45 + (i - 1) * 12.9
			table.insert(doorsN, { c, 3.9, 0, 7.5 })
			table.insert(doorsS, { c, 3.9, 0, 7.5 })
		end
		f:wallU(-3.0, U0 + 1.2, U1 - 1.2, y1, H10, TI, P.plaster, M.Plaster, doorsN)
		f:wallU(3.0, U0 + 1.2, U1 - 1.2, y1, H10, TI, P.plaster, M.Plaster, doorsS)
		for i = 1, 3 do
			local c = U0 + i * 12.9
			f:wallV(c, V0 + 1.2, -3.4, y1, H10, TI, P.plaster, M.Plaster)
			f:wallV(c, 3.4, V1 - 1.2, y1, H10, TI, P.plaster, M.Plaster)
		end
		f:door("LV_ARMY_BS", "Mess door", "u", U0 + 6.45, V1 - 0.6, y1, -1, nil, P.metalGry, 0.3)
		f:door("LV_ARMY_BW", "West door", "v", 0, U0 + 0.6, y1, 1, nil, P.door, 0.3)
		f:door("LV_ARMY_BE", "East door", "v", 0, U1 - 0.6, y1, -1, nil, P.door, 0.3)
		parapet(f, y1 + 11, { { "u", V0 + 0.4, U0, U1 }, { "u", V1 - 0.4, U0, U1 }, { "v", U0 + 0.4, V0, V1 }, { "v", U1 - 0.4, V0, V1 } })
		for i = 1, 4 do
			local c = U0 + 6.45 + (i - 1) * 12.9
			f:lamp(c, y1 + 9.7, -14, 20, i == 2)
			f:lamp(c, y1 + 9.7, 14, 20, false)
			f:door("LV_ARMY_N" .. i, "Room " .. i, "u", c, -3.0, y1, 1, nil, P.door, 0.45)
			f:door("LV_ARMY_S" .. i, "Room " .. (i + 4), "u", c, 3.0, y1, -1, nil, P.door, 0.45)
		end
		f:lamp(-12, y1 + 9.7, 0, 22, false)
		f:lamp(12, y1 + 9.7, 0, 22, false)
		-- bunk rooms: bunks along the north wall, a locker, kit on the floor
		for i = 1, 3 do
			local c = U0 + 6.45 + (i - 1) * 12.9
			f:prop("BunkBed", c, y1, -22.1, 0)
			f:prop("BunkBed", c, y1, -16.2, 0)
			f:loose(c, y1 + 0.5, -9, "dorm", 0.4)
		end
		f:stash("Locker", "LV_ARMY_BL", "locker", "Locker", -23.8, y1, -9.5, 90)
		f:stash("Locker", "LV_ARMY_BL2", "locker", "Locker", -11.0, y1, -9.5, 90)
		f:medbag("LV_ARMY_BM", "Medical bag", 16, y1, -20, 0)
		f:stash("StorageShelf", "LV_ARMY_BST", "crate", "Supply shelf", 19.4, y1, -22.8, 180)
		f:loose(19.4, y1 + 0.5, -12, "junk", 0.4)
		-- mess, kitchen, office
		f:prop("Table", -19.4, y1, 10, 0)
		f:prop("Table", -19.4, y1, 17, 0)
		f:prop("Chair", -19.4, y1, 13.2, 180)
		f:stash("Fridge", "LV_ARMY_FR", "cooler", "Fridge", -6.5, y1, 22.3, 0)
		f:stash("Counter", "LV_ARMY_KC", "drawer", "Kitchen counter", -6.5, y1, 8.8, 180)
		f:stash("OfficeDesk", "LV_ARMY_BO", "drawer", "Officer's desk", 6.5, y1, 18, 0)
		f:stash("Locker", "LV_ARMY_BL3", "locker", "Officer's locker", 11.2, y1, 6.5, 90)
		f:prop("Sofa", 19.4, y1, 16, 180)
		f:loose(-19.4, y1 + 3.6, 10, "grocery", 0.45)
		f:loose(-6.5, y1 + 3.8, 9, "drinks", 0.45)
		f:loose(6.5, y1 + 4.4, 18, "office", 0.5)
		f:loose(19.4, y1 + 0.5, 20, "junk", 0.4)
	end

	-- ── the small buildings: booths, huts, cabins, sheds, garages ────────────────────────────────────────────────────
	-- a one-room building on u0..u1 / v0..v1: floor, walls with door and window holes, a roof.
	-- o = { u0, u1, v0, v1, h, t, color, mat, win = { n, s, w, e (hole lists) }, doors = { { side, pos, key, label, wide, open } },
	--       roof = "flat" | "gable", roofColor, along, pitch, noFloor }; door ids are <tag>_D1, _D2 ...
	local function hut(f, o)
		local u0, u1, v0, v1 = o.u0, o.u1, o.v0, o.v1
		local y1, h, t = 0.5, o.h or 9, o.t or 1.0
		local holes = { n = {}, s = {}, w = {}, e = {} }
		for side, list in o.win or {} do
			for _, w in list do
				table.insert(holes[side], w)
			end
		end
		for _, d in o.doors or {} do
			table.insert(holes[d.side], { d.pos, d.wide or 3.9, 0, d.top or 7.5 })
		end
		if not o.noFloor then
			f:slab(u0, u1, v0, v1, y1, SLAB, o.floor or P.concDk, M.Concrete)
		end
		shell(f, u0, u1, v0, v1, y1, h, t, o.color, o.mat or M.Concrete, holes)
		for i, d in o.doors or {} do
			if not d.open then
				local axis, c, swing = "u", v0 + t / 2, 1
				if d.side == "s" then
					c, swing = v1 - t / 2, -1
				elseif d.side == "w" then
					axis, c, swing = "v", u0 + t / 2, 1
				elseif d.side == "e" then
					axis, c, swing = "v", u1 - t / 2, -1
				end
				f:door(f.tag .. "_D" .. i, d.label or "Door", axis, d.pos, c, y1, swing, d.key, d.key and P.doorDk or P.door, d.chance or 0.4)
			end
		end
		if o.roof == "gable" then
			f:gable(u0, u1, v0, v1, y1 + h, o.pitch or 18, o.along or "u", o.roofColor or P.rustRoof, M.CorrodedMetal, o.color)
		else
			f:slab(u0 - 0.7, u1 + 0.7, v0 - 0.7, v1 + 0.7, y1 + h + 0.8, 0.8, o.roofColor or P.roof, M.Concrete)
		end
		return y1
	end
	-- a shop counter along u at v: its body and plate; returns the top
	local function counter(f, c, v, len, y1)
		f:blk(len, 3.3, 2.0, c, y1, v, P.timberDk, M.WoodPlanks)
		f:blk(len + 0.5, 0.3, 2.5, c, y1 + 3.3, v, P.board, M.WoodPlanks)
		return y1 + 3.6
	end
	-- a till on a counter top, as the container
	local function till(f, id, label, u, top, v)
		local a = f:blk(1.6, 1.1, 1.3, u, top, v, P.metalGry, M.Metal)
		f:container(id, "register", label, u, top, v, 0, a)
	end

	-- a booth: a service window on the north wall, a counter and till behind it, a shelf, an end door
	local function booth(b, spec)
		spec = spec or {}
		local f = newFrame(b, b[2])
		local w, d = b[6], b[7]
		local u0, u1, v0, v1 = -w / 2, w / 2, -d / 2, d / 2
		local t, h = 1.0, 9
		local wc = -w / 4
		local ds = spec.doorSide or "e"
		local y1 = hut(f, {
			u0 = u0, u1 = u1, v0 = v0, v1 = v1, h = h, t = t, color = spec.color or P.plasterY, mat = spec.mat or M.Concrete,
			win = { n = { { wc, 8.0, 3.4, 7.2 }, { w / 4 + 1, 5.0, 3.4, 7.2 } }, s = { win(-w / 4 - 2, 3.0), win(w / 4, 3.0) }, [ds == "e" and "w" or "e"] = { win(0, 3.0) } },
			doors = { { side = ds, pos = 0, key = spec.key, label = spec.label or "Booth door", chance = 0.5 } },
		})
		f:blk(8.6, 0.4, 1.6, wc, y1 + 3.3, v0 - 0.9, P.timberDk, M.WoodPlanks)
		local cv = v0 + t + 1.1
		local top = counter(f, wc, cv, 10, y1)
		till(f, f.tag .. "_TILL", spec.tillLabel or "Cash register", wc + 3, top, cv)
		f:loose(wc - 2, top + 0.3, cv, "register", 0.4)
		f:stash("WallShelf", f.tag .. "_SH", "grocery", "Shelf", u0 + t + 4.2, y1, v1 - t - 1.05, 0)
		f:loose(-1.0, y1 + 0.5, 0.2, spec.pool or "grocery", 0.4)
		f:loose(w / 4, y1 + 0.5, 0, "junk", 0.35)
		f:lamp(0, y1 + h - 0.6, 0, 16, false)
		if spec.extra then
			spec.extra(f, y1, u0 + t, u1 - t, v0 + t, v1 - t)
		end
		return f
	end

	-- a cabin or trailer: steel walls under a shallow gable, a door on the south wall; fill places the furniture
	local function cabin(b, spec)
		local f = newFrame(b, b[2])
		if spec.turn then
			f.base = f.base * CFrame.Angles(0, math.pi, 0)
		end
		local w, d = b[6], b[7]
		local u0, u1, v0, v1 = -w / 2, w / 2, -d / 2, d / 2
		local t, h = 0.8, spec.h or 8.5
		local dp = spec.doorPos or -w / 4
		local y1 = hut(f, {
			u0 = u0, u1 = u1, v0 = v0, v1 = v1, h = h, t = t, color = spec.color or P.metalBlu, mat = M.Metal, roof = "gable", pitch = 10,
			roofColor = P.metalGry,
			win = { n = wins(u0 + 4, u1 - 4, spec.nWin or 2, 3.2), s = { win(w / 4 + 2, 3.2) }, w = { win(0, 2.6) }, e = { win(0, 2.6) } },
			doors = { { side = "s", pos = dp, key = spec.key, label = spec.label or "Door", chance = 0.4 } },
		})
		f:lamp(0, y1 + h - 0.4, 0, 16, false)
		spec.fill(f, y1, u0 + t, u1 - t, v0 + t, v1 - t)
		return f
	end

	-- a shed: corrugated walls, a gable roof, wide openings on the south wall or a plain door
	local function shed(b, spec)
		local f = newFrame(b, b[2])
		local w, d = b[6], b[7]
		local u0, u1, v0, v1 = -w / 2, w / 2, -d / 2, d / 2
		local t, h = 1.0, spec.h or 10
		local doors = spec.doors or { { side = "s", pos = 0, wide = 9.0, top = 8.5, open = true } }
		local win = spec.win or { n = wins(u0 + 4, u1 - 4, math.max(1, math.floor(w / 9)), 3.0, 4.0, 7.2) }
		local y1 = hut(f, {
			u0 = u0, u1 = u1, v0 = v0, v1 = v1, h = h, t = t, color = spec.color or P.metalGrn, mat = M.Metal, roof = "gable", pitch = 14,
			roofColor = P.rustRoof, win = win, doors = doors, noFloor = spec.noFloor, floor = P.conc,
		})
		if spec.block then
			-- a footprint the stair below keeps free: { cu, cv, hu, hv }
			local bk = spec.block
			table.insert(f.solids, { cf = f:cf(bk[1], 4, bk[2]), hx = bk[3], hy = 8, hz = bk[4] })
		end
		f:lamp(0, y1 + h - 0.4, 0, 20, spec.bigLamp == true)
		spec.fill(f, y1, u0 + t, u1 - t, v0 + t, v1 - t)
		return f
	end

	-- a row of garage bays along u: a back wall, party walls, a front opening per bay (a roller door when shut); the bays
	-- listed in `open` stand open with a vehicle inside
	local function garageRow(b, spec)
		local f = newFrame(b, b[2])
		local w, d = b[6], b[7]
		local u0, u1, v0, v1 = -w / 2, w / 2, -d / 2, d / 2
		local n = math.max(1, math.floor(w / (spec.bay or 19)))
		local bw = w / n
		local y1, h, t = 0.5, 10, 1.0
		local holes, shut = {}, {}
		for i = 1, n do
			local c = u0 + (i - 0.5) * bw
			table.insert(holes, { c, math.min(bw - 4, 14), 0, 9.5 })
			if not (spec.open and spec.open[i]) then
				table.insert(shut, c)
			end
		end
		f:slab(u0, u1, v0, v1, y1, SLAB, P.conc, M.Concrete)
		f:wallU(v1 - t / 2, u0, u1, y1, h, t, spec.color or P.panelDk, M.Concrete, holes)
		f:wallU(v0 + t / 2, u0, u1, y1, h, t, spec.color or P.panelDk, M.Concrete, spec.backWin)
		f:wallV(u0 + t / 2, v0 + t, v1 - t, y1, h, t, spec.color or P.panelDk, M.Concrete)
		f:wallV(u1 - t / 2, v0 + t, v1 - t, y1, h, t, spec.color or P.panelDk, M.Concrete)
		for i = 1, n - 1 do
			f:wallV(u0 + i * bw, v0 + t, v1 - t, y1, h, 0.8, P.plasterY, M.Plaster)
		end
		for _, c in shut do
			f:blk(math.min(bw - 4, 14) - 0.3, 9.2, 0.5, c, y1, v1 - t / 2 + 0.2, P.metalGry, M.CorrodedMetal)
		end
		f:slab(u0 - 0.7, u1 + 0.7, v0 - 0.7, v1 + 0.7, y1 + h + 0.8, 0.8, P.roof, M.Concrete)
		for i in spec.open or {} do
			local c = u0 + (i - 0.5) * bw
			f:lamp(c, y1 + h - 0.6, 0, 20, false)
			spec.fill(f, i, c, bw, y1, u0, u1, v0 + t, v1 - t)
		end
		return f
	end

	-- ── the specific small buildings ────────────────────────────────────────────────────────────────────────────────
	-- furniture for the cabins and trailers: a bed across the east end, a table and a locker; the locked ones also hold a safe
	local function fillBunk(rich)
		return function(f, y1, iu0, iu1, iv0, iv1)
			local mv = (iv0 + iv1) / 2
			f:prop("Bed", iu1 - 3.8, y1, mv, 90)
			f:stash("Locker", f.tag .. "_LK", "locker", "Locker", iu0 + 1.3, y1, iv1 - 1.1, 0)
			f:loose(iu1 - 3.8, y1 + 3.6, mv, "dorm", 0.5)
			f:loose(iu0 + 6.5, y1 + 0.5, mv, "junk", 0.4)
			if rich then
				f:container(f.tag .. "_SAFE", "safe", "Hidden safe", iu0 + 1.7, y1, iv0 + 1.5, 0)
				f:prop("Table", iu0 + 7.4, y1, iv0 + 1.7, 0)
				f:gunCase(f.tag .. "_GUN", "Weapon case", iu0 + 8.4, y1, iv1 - 1.0, 0)
				f:jacket(f.tag .. "_JK", "Coat", iu0 + 0.8, y1, mv, 90)
				f:loose(iu0 + 7.4, y1 + 3.6, iv0 + 1.7, "dorm_good", 0.55)
				f:loose(iu0 + 4.5, y1 + 0.5, mv, "vault", 0.4)
				f:loose(iu0 + 10.0, y1 + 0.5, mv, "dorm_good", 0.5)
			else
				f:prop("Table", iu0 + 7.4, y1, iv0 + 1.7, 0)
				f:loose(iu0 + 7.4, y1 + 3.6, iv0 + 1.7, "drinks", 0.45)
			end
		end
	end
	-- an office cabin: desk, pigeonholes, locker
	local function fillOffice(f, y1, iu0, iu1, iv0, iv1)
		local mv = (iv0 + iv1) / 2
		f:stash("OfficeDesk", f.tag .. "_OD", "drawer", "Office desk", iu0 + 5, y1, mv, 0)
		f:prop("Chair", iu0 + 5, y1, mv - 3.0, 180)
		f:stash("Pigeonholes", f.tag .. "_PH", "drawer", "Pigeonholes", iu1 - 4, y1, iv0 + 0.7, 180)
		f:stash("Locker", f.tag .. "_LK", "locker", "Locker", iu1 - 1.2, y1, iv1 - 1.1, 0)
		f:loose(iu0 + 5, y1 + 4.4, mv, "office", 0.5)
		f:loose(iu1 - 6, y1 + 0.5, mv, "junk", 0.4)
		f:loose(iu0 + 2, y1 + 0.5, iv1 - 2, "dorm", 0.35)
	end
	-- a workshop corner: bench, shelf, drums
	local function fillWork(f, y1, iu0, iu1, iv0, iv1)
		local mv = (iv0 + iv1) / 2
		f:stash("CraftBench", f.tag .. "_CB", "toolbox", "Workbench", iu0 + 4.5, y1, iv0 + 1.9, 180)
		f:stash("StorageShelf", f.tag .. "_ST", "crate", "Shelf", iu1 - 4.2, y1, iv0 + 1.1, 180)
		f:prop("Drum", iu1 - 1.4, y1, mv, 0)
		f:prop("TyreStack", iu0 + 2.4, y1, iv1 - 1.7, 0)
		f:loose(mv, y1 + 0.5, mv, "tech", 0.4)
		f:loose(iu0 + 8, y1 + 0.5, mv + 1, "junk", 0.45)
		f:loose(iu0 + 4.5, y1 + 3.6 + 0.2, iv0 + 1.9, "toolbox", 0.4)
	end

	local function garageFill(f, i, c, bw, y1, u0, u1, v0, v1)
		local cars = { "CarSedan", "CarHatch", "CarSedanSmashed" }
		f:prop(cars[i % 3 + 1], c - 2.2, y1, (v0 + v1) / 2, (i % 2 == 0) and 0 or 180)
		if i % 2 == 1 then
			f:stash("ToolChest", f.tag .. "_TC" .. i, "toolbox", "Tool chest", c + bw / 2 - 2.8, y1, v0 + 2.0, 0)
		end
		f:loose(c + 3.0, y1 + 0.5, v0 + 6, "junk", 0.4)
	end

	local function fn(spec, maker)
		return function(b)
			return maker(b, spec)
		end
	end
	local function kioskExtra(list)
		return function(f, y1, iu0, iu1, iv0, iv1)
			for _, e in list do
				e(f, y1, iu0, iu1, iv0, iv1)
			end
		end
	end
	local function richBooth(f, y1, iu0, iu1, iv0, iv1)
		f:toolbox(f.tag .. "_TB", "Toolbox", iu1 - 2.2, y1, iv1 - 0.8, 0)
		f:jacket(f.tag .. "_JK", "Coat", iu0 + 9.5, y1, iv1 - 0.8, 0)
		f:medbag(f.tag .. "_MB", "Medical bag", iu1 - 4.8, y1, iv1 - 1.2, 0)
		f:loose(iu1 - 3, y1 + 0.5, 0, "dorm_good", 0.5)
		f:loose(0, y1 + 0.5, 1, "vault", 0.4)
	end

	local kioskSpecs = {
		[38] = { color = P.metalGrn, mat = M.Metal, pool = "tech", extra = function(f, y1, iu0, iu1, iv0, iv1)
			f:stash("FuseBox", f.tag .. "_FB", "techbox", "Fuse box", iu1 - 6.2, y1, iv0 + 0.5, 180)
		end },
		[39] = { extra = function(f, y1)
			f:prop("BusShelter", 0, y1, 9.6, 0)
		end },
		[40] = { color = P.plasterG, extra = function(f, y1)
			f:prop("BusShelter", 0, y1, 9.0, 0)
		end },
		[42] = { color = P.plasterG },
		[43] = { key = "KEY_BY_HUTSKIOSK", label = "Kiosk door", color = P.brickDk, mat = M.Brick, extra = richBooth },
		[45] = { color = P.metalGry, mat = M.Metal, pool = "tech", extra = function(f, y1, iu0, iu1, iv0, iv1)
			f:toolbox(f.tag .. "_TB", "Toolbox", iu1 - 2.2, y1, iv1 - 0.8, 0)
		end },
		[47] = { color = P.panelDk, extra = function(f, y1)
			f:prop("Sandbags", 6, y1, 8.0, 0)
		end },
		[48] = { color = P.panel },
		[49] = { color = P.plasterB },
		[61] = { color = P.brickDk, mat = M.Brick, pool = "junk" },
		[62] = { color = P.plasterY },
	}
	local function kioskBuilder(b)
		return booth(b, kioskSpecs[b[1]])
	end

	-- the bigger huts of the kiosk kind
	local bigHuts = {
		-- the Block A gatehouse: guard desk, lockers, a bench, a bin
		[41] = { h = 9.5, color = P.panel, nWin = 3, fill = function(f, y1, iu0, iu1, iv0, iv1)
			f:stash("OfficeDesk", f.tag .. "_OD", "drawer", "Guard desk", 0, y1, iv0 + 3.0, 180)
			f:prop("Chair", 0, y1, iv0 + 6.2, 0)
			f:stash("Lockers", f.tag .. "_LK", "locker", "Guard lockers", iu1 - 3.3, y1, iv1 - 1.7, 0)
			f:prop("Bench", -1.0, y1, iv1 - 1.1, 0)
			f:loose(0, y1 + 4.4, iv0 + 3.0, "office", 0.5)
			f:loose(iu0 + 6, y1 + 0.5, 0, "junk", 0.4)
		end },
		-- the roadside hut: a small shop
		[46] = { h = 9.5, color = P.plasterY, nWin = 3, fill = function(f, y1, iu0, iu1, iv0, iv1)
			local top = counter(f, iu0 + 7, iv0 + 3.0, 10, y1)
			till(f, f.tag .. "_TILL", "Shop till", iu0 + 10, top, iv0 + 3.0)
			f:stash("Gondola", f.tag .. "_GO", "grocery", "Shop shelf", -2.5, y1, 1.5, 0)
			f:stash("Fridge", f.tag .. "_FR", "cooler", "Drinks fridge", iu1 - 4.3, y1, iv1 - 3.4, 0)
			f:prop("WallShelf", iu1 - 5.0, y1, iv0 + 1.1, 180)
			f:loose(iu0 + 7, top + 0.3, iv0 + 3.0, "register", 0.45)
			f:loose(-2.5, y1 + 3.6, 1.5, "grocery", 0.45)
			f:loose(iu1 - 4.3, y1 + 0.5, iv1 - 6, "drinks", 0.4)
		end },
		-- the bridge booths: a checkpoint office
		[52] = { h = 9.5, color = P.panelDk, nWin = 3, fill = function(f, y1, iu0, iu1, iv0, iv1)
			f:stash("OfficeDesk", f.tag .. "_OD", "drawer", "Checkpoint desk", iu0 + 5, y1, iv0 + 3.0, 180)
			f:stash("Locker", f.tag .. "_LK", "locker", "Locker", iu1 - 1.3, y1, iv0 + 1.2, 0)
			f:prop("Bench", iu1 - 4.0, y1, iv1 - 1.1, 0)
			f:loose(iu0 + 5, y1 + 4.4, iv0 + 3.0, "office", 0.5)
			f:loose(0, y1 + 0.5, 1, "junk", 0.4)
		end },
		[53] = { h = 9.5, color = P.panelDk, nWin = 3, fill = function(f, y1, iu0, iu1, iv0, iv1)
			f:stash("OfficeDesk", f.tag .. "_OD", "drawer", "Checkpoint desk", iu1 - 5, y1, iv0 + 3.0, 180)
			f:stash("Locker", f.tag .. "_LK", "locker", "Locker", iu0 + 1.3, y1, iv0 + 1.2, 0)
			f:prop("Bin", iu0 + 3.5, y1, iv1 - 1.1, 0)
			f:loose(iu1 - 5, y1 + 4.4, iv0 + 3.0, "office", 0.5)
			f:loose(0, y1 + 0.5, 1, "junk", 0.4)
		end },
		-- the Red Stores booth: a foreman's office with a safe
		[54] = { h = 9.5, color = P.metalRed, nWin = 4, fill = function(f, y1, iu0, iu1, iv0, iv1)
			f:stash("OfficeDesk", f.tag .. "_OD", "drawer", "Foreman's desk", iu0 + 5, y1, iv0 + 3.0, 180)
			f:stash("Lockers", f.tag .. "_LK", "locker", "Work lockers", iu1 - 3.3, y1, iv1 - 1.7, 0)
			f:container(f.tag .. "_SAFE", "safe", "Foreman's safe", iu0 + 1.7, y1, iv1 - 1.5, 0)
			f:loose(iu0 + 5, y1 + 4.4, iv0 + 3.0, "office", 0.55)
			f:loose(0, y1 + 0.5, 1, "junk", 0.4)
			f:loose(iu0 + 5, y1 + 0.5, iv1 - 2, "vault", 0.3)
		end },
		-- the trailer lot shack: beds, a table, a sofa (the TRAILER LOT extract lies at its door)
		[55] = { h = 9.5, color = P.metalGrn, nWin = 4, fill = function(f, y1, iu0, iu1, iv0, iv1)
			f:prop("Bed", iu1 - 3.8, y1, iv1 - 3.0, 90)
			f:prop("Bed", iu1 - 3.8, y1, iv0 + 3.0, 90)
			f:prop("Sofa", iu0 + 4.0, y1, iv0 + 1.7, 180)
			f:prop("Table", iu0 + 4.0, y1, iv0 + 5.3, 0)
			f:stash("Locker", f.tag .. "_LK", "locker", "Locker", iu0 + 11.0, y1, iv1 - 1.1, 0) -- clear of the door (placement audit)
			f:loose(iu0 + 4.0, y1 + 3.6, iv0 + 5.3, "drinks", 0.5)
			f:loose(iu0 + 10, y1 + 0.5, 0, "dorm", 0.4)
			f:loose(iu1 - 4, y1 + 0.5, 0, "junk", 0.4)
			points.TRAILER_LOT = f:pt(0, y1 + 0.5, 0)
		end },
	}
	bigHuts[53].doorPos = 5
	local function bigHutBuilder(b)
		local spec = bigHuts[b[1]]
		return cabin(b, spec)
	end

	local cabinSpecs = {
		[5] = { color = P.metalGrn, h = 9, fill = fillOffice, turn = true },
		[6] = { color = P.metalGry, h = 9, fill = fillOffice },
		[56] = { color = P.metalBlu, key = "KEY_BY_TRAILERA", label = "Trailer door", fill = fillBunk(true) },
		[57] = { color = P.metalGrn, key = "KEY_BY_TRAILERB", label = "Trailer door", fill = fillBunk(true) },
		[58] = { color = P.metalGry, fill = fillBunk(false) },
		[60] = { color = P.metalRed, fill = fillBunk(false) },
	}
	local function cabinBuilder(b)
		return cabin(b, cabinSpecs[b[1]])
	end

	-- the sheds
	local shedSpecs = {
		-- the OLD PUMPS sheds: no floor, a wall opening toward the stair into the cellar (ladder-39), which stays clear
		[35] = { color = P.metalGry, noFloor = true, block = { 11.4, -7.3, 9.4, 3.2 }, win = { n = wins(-9, 9, 2, 3.0, 4, 7.2), e = { { -7.3, 6.4, 0, 8.5 } } }, fill = function(f, y1, iu0, iu1, iv0, iv1)
			f:stash("ToolChest", f.tag .. "_TC", "toolbox", "Tool chest", iu0 + 2.2, y1, iv1 - 2.4, 90)
			f:prop("Drum", iu0 + 2.0, y1, iv0 + 2.0, 0)
			f:prop("TyreStack", iu1 - 2.4, y1, iv1 - 2.0, 0)
			f:loose(-4, y1 + 0.5, 4, "junk", 0.45)
			f:loose(-6, y1 + 0.5, -4, "tech", 0.4)
		end },
		[66] = { color = P.metalGrn, noFloor = true, block = { -16.6, -7.3, 9.4, 3.2 }, win = { n = wins(-9, 9, 2, 3.0, 4, 7.2), w = { { -7.3, 6.4, 0, 8.5 } } }, fill = function(f, y1, iu0, iu1, iv0, iv1)
			f:stash("CraftBench", f.tag .. "_CB", "toolbox", "Workbench", iu1 - 2.2, y1, iv1 - 4.2, -90)
			f:prop("JerryCans", iu0 + 2.2, y1, iv1 - 2.0, 0)
			f:prop("PalletBoxes", iu1 - 3.0, y1, iv0 + 3.0, 0)
			f:loose(2, y1 + 0.5, 5, "junk", 0.45)
			f:loose(-2, y1 + 0.5, -2, "tech", 0.4)
		end },
		-- the trailer lot shed: a van, pallets, a bench
		[59] = { color = P.metalGrn, doors = { { side = "s", pos = -12, wide = 10, top = 8.5, open = true }, { side = "s", pos = 12, wide = 10, top = 8.5, open = true } }, bigLamp = true, fill = function(f, y1, iu0, iu1, iv0, iv1)
			f:prop("Van", -14, y1, 0, 90)
			f:prop("PalletBoxes", 10, y1, -4, 0)
			f:prop("PalletBoxes", 18, y1, 3, 20)
			f:stash("CraftBench", f.tag .. "_CB", "toolbox", "Workbench", iu1 - 6, y1, iv0 + 1.9, 180)
			f:prop("Drum", iu1 - 1.6, y1, iv1 - 2, 0)
			f:stash("StorageShelf", f.tag .. "_ST", "crate", "Shelf", 2, y1, iv0 + 1.1, 180)
			f:loose(-2, y1 + 0.5, 3, "junk", 0.45)
			f:loose(14, y1 + 0.5, 0, "tech", 0.4)
			f:loose(-26, y1 + 0.5, -5, "junk", 0.4)
		end },
		-- the store 4 shack (locked): shelves and a toolbox
		[63] = { color = P.metalGry, doors = { { side = "s", pos = -5, key = "KEY_BY_SHACK4", label = "Shack door" } }, win = { n = wins(-6, 6, 2, 2.6, 4, 7.2) }, fill = function(f, y1, iu0, iu1, iv0, iv1)
			f:stash("StorageShelf", f.tag .. "_S1", "crate", "Stock shelf", -4, y1, iv0 + 1.1, 180)
			f:stash("StorageShelf", f.tag .. "_S2", "grocery", "Stock shelf", 5, y1, iv0 + 1.1, 180)
			f:prop("PalletBoxes", iu1 - 2.4, y1, iv1 - 2.2, 0)
			f:toolbox(f.tag .. "_TB", "Toolbox", iu0 + 0.9, y1, 0, 90)
			f:loose(0, y1 + 0.5, 0, "junk", 0.5)
			f:loose(-6, y1 + 0.5, 1, "tech", 0.45)
		end },
		-- the roadside shed, west: open, a wreck of crates
		[64] = { color = P.metalGrn, fill = function(f, y1, iu0, iu1, iv0, iv1)
			f:prop("TyreStack", iu0 + 2.4, y1, iv0 + 2.2, 0)
			f:prop("PalletBoxes", iu1 - 3.0, y1, iv0 + 3.0, 0)
			f:prop("CardboardPile", 0, y1, 2, 30)
			f:loose(-6, y1 + 0.5, 0, "junk", 0.5)
			f:loose(7, y1 + 0.5, -2, "junk", 0.45)
		end },
		-- the roadside shed, east (locked): a stash
		[65] = { color = P.metalGry, doors = { { side = "s", pos = -4, key = "KEY_BY_ROADSHACK", label = "Shack door" } }, win = { n = wins(-6, 6, 2, 2.6, 4, 7.2) }, fill = function(f, y1, iu0, iu1, iv0, iv1)
			f:container(f.tag .. "_SAFE", "safe", "Shack safe", iu1 - 1.9, y1, iv0 + 1.6, 0)
			f:gunCase(f.tag .. "_GUN", "Weapon case", 0, y1, iv0 + 1.3, 0)
			f:jacket(f.tag .. "_JK", "Coat", iu0 + 1.0, y1, 0, 90)
			f:stash("StorageShelf", f.tag .. "_ST", "crate", "Stock shelf", 2.3, y1, iv1 - 1.1, 0)
			f:prop("Table", iu1 - 3.4, y1, 3, 90)
			f:loose(0, y1 + 0.5, 3, "vault", 0.45)
			f:loose(-5, y1 + 0.5, -2, "dorm_good", 0.5)
			f:loose(iu1 - 3.4, y1 + 3.6, 3, "tech", 0.45)
		end },
	}
	local function shedBuilder(b)
		return shed(b, shedSpecs[b[1]])
	end

	local function garageBuilder(open)
		return function(b)
			return garageRow(b, { open = open, fill = garageFill })
		end
	end

	-- @@NEXT@@

	-- ── build everything ─────────────────────────────────────────────────────────────────────────────────────────────
	local MINE = { dorm = true, station = true, house = true, cabin = true, kiosk = true, garage = true, garage_row = true, shed = true }
	local builders = { [26] = dormA, [25] = dormB, [24] = fuelStop, [44] = oldPumps, [29] = squat, [18] = watchhouse, [36] = armyHut, [37] = armyBarracks }
	for id in bigHuts do
		builders[id] = bigHutBuilder
	end
	for id in cabinSpecs do
		builders[id] = cabinBuilder
	end
	for id in shedSpecs do
		builders[id] = shedBuilder
	end
	builders[0] = garageBuilder({ [2] = true })
	builders[1] = garageBuilder({ [2] = true })
	builders[2] = garageBuilder({ [2] = true, [5] = true })
	builders[3] = garageBuilder({ [3] = true, [7] = true, [12] = true })
	builders[4] = garageBuilder({ [2] = true, [6] = true, [11] = true, [15] = true })
	builders[7] = garageBuilder({ [3] = true, [6] = true })
	local kindBuilders = { kiosk = kioskBuilder }
	-- the main buildings first (so the prop cap never cuts them), then the rest in layout order
	local ORDER = { 26, 25, 24, 44, 29, 18, 36, 37 }
	local queue, seen = {}, {}
	for _, id in ORDER do
		seen[id] = true
	end
	for _, id in ORDER do
		for _, b in L.blds do
			if b[1] == id then
				table.insert(queue, b)
			end
		end
	end
	for _, b in L.blds do
		if not seen[b[1]] then
			table.insert(queue, b)
		end
	end
	for _, b in queue do
		if MINE[b[3]] then
			local fn = builders[b[1]] or kindBuilders[b[3]]
			if fn then
				local ok, err = pcall(fn, b)
				if ok then
					st.ok += 1
				else
					st.failed += 1
					warn("[ZR] Border living: " .. tostring(b[2]) .. " failed: " .. tostring(err))
				end
			end
		end
	end

	local nParts, nProps, nLights, nShadow = 0, 0, 0, 0
	for _, d in living:GetDescendants() do
		if d:IsA("BasePart") then
			if not (d.Parent and d.Parent:GetAttribute("Kit")) then
				nParts += 1
			end
		elseif d:IsA("Model") and d:GetAttribute("Kit") then
			nProps += 1
		end
	end
	print(
		string.format(
			"[ZR] Border living: %d buildings (%d failed), %d parts, %d kit props (%d cut by the cap), %d lights (%d with shadows), %d doors (%d locked), %d containers, %d loose spots (%d without room), %d props rejected for overlap",
			st.ok, st.failed, nParts, nProps, st.cut, st.lights, st.shadows, st.doors, st.locked, st.containers, st.loose, st.noRoom, st.rejected
		)
	)
	if #REJECTS > 0 then
		print("[ZR] Border living: not placed (overlap): " .. table.concat(REJECTS, "; "))
	end
	print(
		string.format(
			"[ZR] Border dorms: %d rooms (%d lived-in, %d bare, %d washrooms, %d kitchen, %d locked), %d room doors (locked ones apart), %d furniture props (%d dropped for overlap), %d clutter pieces, %d fittings, %d panes (%d frosted, %d half-broken, %d open, %d boarded with %d boards), %d curtains, %d glass-on-floor",
			DC.rooms, DC.lived, DC.bare, DC.wash, DC.kitchen, DC.rooms - DC.lived - DC.bare - DC.wash - DC.kitchen, DC.doors, DC.props,
			DC.rejected, DC.bits, DC.fit, DC.panes, DC.frosted, DC.cracked, DC.open, DC.boarded, DC.boards, DC.curtains, DC.shards
		)
	)
	print(
		string.format(
			"[ZR] Border dorm walls: %d band skins (%d on stairwells) and %d lines, %d dividers in two leaves, %d in one finish, %d in the worse of two finishes, %d kitchen tile pieces: %d parts added",
			WF.skins, WF.stairs, WF.lines, WF.splits, WF.whole, WF.worst, DC.tiles, WF.skins + WF.lines + WF.splits + DC.tiles
		)
	)
end
