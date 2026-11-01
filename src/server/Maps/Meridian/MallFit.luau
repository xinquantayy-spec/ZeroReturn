--!nonstrict
-- Meridian Mall shell, step 3: what turns the shell into a mall. The stock rooms of the deeper stores (a partition across the back
-- with a door), the anchors' checkout lanes and goods-in marks, the washrooms (the men's room on L2 holds the spot of the SHELTER EXIT
-- valve) and the security room (the alarm terminal's spot), the columns of the car park, the shelter and the halls, the zone letters
-- on the L0 floor, the lamps; and the publication of every unit as B.units[id] (docs/maps/MERIDIAN_MALL.md, "Part 2").
local Plan = require(script.Parent.MallPlan)

return function(ctx)
	local B, plan, O, W, kit = ctx.B, ctx.plan, ctx.O, ctx.W, ctx.kit
	local C, M, hex = ctx.C, ctx.M, ctx.hex
	local YL, CEIL, g = plan.YL, plan.CEIL, plan.g
	local nx, nz = g.nx, g.nz
	local mk, ab, boxCF = ctx.mk, ctx.ab, ctx.boxCF
	local n = ctx.n
	local OPEN, HALL, VOID, OUT = Plan.OPEN, Plan.HALL, Plan.VOID, Plan.OUT
	local FRONT = { N = { 0, -1 }, S = { 0, 1 }, W = { -1, 0 }, E = { 1, 0 } }
	local OPP = { N = "S", S = "N", E = "W", W = "E" }
	local INTERIOR = ctx.INTERIOR
	local METAL = C.metalDark
	local rng = Random.new(2207)

	local function labAt(level, ix, iz)
		if ix < 1 or iz < 1 or ix > nx or iz > nz then
			return OUT
		end
		return plan.lab[level][(iz - 1) * nx + ix]
	end
	-- every cell within r cells of (ix, iz) has a label in the set `ok`
	local function clear(level, ix, iz, r, ok)
		for dz = -r, r do
			for dx = -r, r do
				if not ok[labAt(level, ix + dx, iz + dz)] then
					return false
				end
			end
		end
		return true
	end
	local function cellX(ix)
		return g.x0 + (ix - 0.5) * g.cell
	end
	local function cellZ(iz)
		return g.z0 + (iz - 0.5) * g.cell
	end

	-- ── keep-outs for columns and lamps: flights (with their landings) and every opening of the walls ────────
	local avoidR = {} -- { x0, z0, x1, z1 } any level
	for _, ln in plan.links do
		local m = 14
		avoidR[#avoidR + 1] = { ln.rx0 - m, ln.rz0 - m, ln.rx1 + m, ln.rz1 + m }
	end
	local avoidP = { [0] = {}, [1] = {}, [2] = {} } -- openings: { x, z }
	for level = 0, 2 do
		for _, orient in { "v", "h" } do
			for _, r in plan.runs[level][orient] do
				if r.gaps then
					for _, gp in r.gaps do
						if gp.kind ~= "none" then
							local x, z = r.x0, gp.c
							if orient == "h" then
								x, z = gp.c, r.z0
							end
							avoidP[level][#avoidP[level] + 1] = { x, z, gp.w / 2 + 10 }
						end
					end
				end
			end
		end
	end
	local function blocked(level, x, z)
		for _, r in avoidR do
			if x > r[1] and x < r[3] and z > r[2] and z < r[4] then
				return true
			end
		end
		for _, p in avoidP[level] do
			local dx, dz = x - p[1], z - p[2]
			if dx * dx + dz * dz < p[3] * p[3] then
				return true
			end
		end
		return false
	end

	-- is there an L2 floor above the cell? (an L1 store that is open to the roof in part has the gallery floor over the rest)
	local function colOf(x)
		return math.floor((x - g.x0) / g.cell) + 1
	end
	local function rowOf(z)
		return math.floor((z - g.z0) / g.cell) + 1
	end
	local function floorAbove(ix, iz)
		local l2 = labAt(2, ix, iz)
		return l2 ~= OUT and l2 ~= VOID
	end

	-- ── stock rooms ──────────────────────────────────────────────────────────────────────────────────────
	-- a store at least 22 wide and 28 deep gets a strip 9.4 studs deep along its back wall, behind a partition with a door
	local STOCK = 9.4
	local nStock = n.parts
	local sales = {} -- unit idx -> { x0, z0, x1, z1 } of the sales floor (inner rectangle less the stock room)
	for _, u in plan.units do
		local ix0, iz0, ix1, iz1 = u.x0 + 1.2, u.z0 + 1.2, u.x1 - 1.2, u.z1 - 1.2
		local r = { x0 = ix0, z0 = iz0, x1 = ix1, z1 = iz1 }
		sales[u.idx] = r
		local side = u.front
		if side and not u.service and not u.open then
			local w, d = ix1 - ix0, iz1 - iz0
			if side == "E" or side == "W" then
				w, d = d, w
			end
			if w >= 22 and d >= 28 then
				local par = ctx.m[u.level]
				local y0 = YL[u.level]
				local axis, line, lo, hi
				if side == "S" then
					axis, line, lo, hi = "x", iz0 + STOCK, ix0, ix1
					r.z0 = line + 0.6
				elseif side == "N" then
					axis, line, lo, hi = "x", iz1 - STOCK, ix0, ix1
					r.z1 = line - 0.6
				elseif side == "E" then
					axis, line, lo, hi = "z", ix0 + STOCK, iz0, iz1
					r.x0 = line + 0.6
				else
					axis, line, lo, hi = "z", ix1 - STOCK, iz0, iz1
					r.x1 = line - 0.6
				end
				local id = "MM_" .. u.id .. "_STOCK"
				local spec = { side = side, unit = u, door = { id = id, label = "Stock room" } }
				local gap = { c = lo + (hi - lo) * 0.3, w = 5.2, h = 8.6, kind = "door", spec = spec }
				-- the partition stops under the gallery floor when there is one above any part of it
				local ptop = u.top
				if u.level == 1 and ptop > CEIL[1] then
					if axis == "x" then
						for ix = colOf(lo), colOf(hi - 0.01) do
							if floorAbove(ix, rowOf(line - 0.7)) or floorAbove(ix, rowOf(line + 0.7)) then
								ptop = CEIL[1]
							end
						end
					else
						for iz = rowOf(lo), rowOf(hi - 0.01) do
							if floorAbove(colOf(line - 0.7), iz) or floorAbove(colOf(line + 0.7), iz) then
								ptop = CEIL[1]
							end
						end
					end
				end
				local holes = ctx.wallRun(par, axis, line, lo, hi, 1.2, y0, ptop, hex("74766E"), M.Plaster, { gap })
				for _, h in holes do
					ctx.addDoor(u.level, axis, line, h[3], spec, par, 1.2)
				end
				u.stock = { id = id, axis = axis, line = line, lo = lo, hi = hi }
			end
		end
	end
	ctx.stat.stock = n.parts - nStock

	-- ── publication ──────────────────────────────────────────────────────────────────────────────────────
	-- the frame of a store: origin at the middle of its floor, look vector out through the front (local -Z), size across the
	-- front x floor-to-ceiling x depth
	local function frameOf(level, x0, z0, x1, z1, side, top)
		local y = YL[level]
		local dir = FRONT[side] or FRONT.S
		local pos = Vector3.new(O.X + (x0 + x1) / 2, y, O.Z + (z0 + z1) / 2)
		local w, d = x1 - x0, z1 - z0
		if side == "E" or side == "W" then
			w, d = d, w
		end
		return CFrame.lookAt(pos, pos + Vector3.new(dir[1], 0, dir[2])), Vector3.new(w, top - y, d)
	end
	local function worldAt(level, x, z, dy)
		return Vector3.new(O.X + x, YL[level] + (dy or 0), O.Z + z)
	end
	for _, u in plan.units do
		local r = sales[u.idx]
		local side = u.front or "S"
		local cf, size = frameOf(u.level, r.x0, r.z0, r.x1, r.z1, side, u.top)
		-- ceilY is the tallest roof over the unit; ceilMin the lowest (a gallery floor over part of an L1 store that is open to the roof)
		local ceilMin = u.top
		if u.level == 1 and u.top > CEIL[1] then
			for iz = rowOf(r.z0 + 0.01), rowOf(r.z1 - 0.01) do
				for ix = colOf(r.x0 + 0.01), colOf(r.x1 - 0.01) do
					if floorAbove(ix, iz) then
						ceilMin = CEIL[1]
					end
				end
			end
		end
		local entry = {
			id = u.id, name = u.name, kind = u.kind, level = u.level, front = side, cframe = cf, size = size,
			rect = { x0 = r.x0, z0 = r.z0, x1 = r.x1, z1 = r.z1 }, outer = { x0 = u.x0, z0 = u.z0, x1 = u.x1, z1 = u.z1 },
			floorY = YL[u.level], ceilY = u.top, ceilMin = ceilMin, service = u.service and true or false, doors = u.doorIds or {},
			sign = u.sign, signGui = u.signGui, floor = u.plates and u.plates[1] or nil, entrances = {},
		}
		if u.stock then
			local s = u.stock
			local sx0, sz0, sx1, sz1 = u.x0 + 1.2, u.z0 + 1.2, u.x1 - 1.2, u.z1 - 1.2
			if s.axis == "x" then
				if side == "S" then
					sz1 = s.line - 0.6
				else
					sz0 = s.line + 0.6
				end
			elseif side == "E" then
				sx1 = s.line - 0.6
			else
				sx0 = s.line + 0.6
			end
			local scf, ssize = frameOf(u.level, sx0, sz0, sx1, sz1, side, u.top)
			entry.stock = { door = s.id, cframe = scf, size = ssize }
		end
		B.units[u.id] = entry
	end
	-- entrances (world positions of the openings in the fronts)
	for level = 0, 2 do
		for _, orient in { "v", "h" } do
			for _, r in plan.runs[level][orient] do
				if r.info.style == "front" and r.gaps then
					local u = r.info.unit
					local e = u and B.units[u.id]
					if e then
						for _, gp in r.gaps do
							if gp.kind == "shop" then
								local x, z = r.x0, gp.c
								if orient == "h" then
									x, z = gp.c, r.z0
								end
								e.entrances[#e.entrances + 1] = { pos = worldAt(level, x, z, 0), width = gp.w, side = r.info.side, kind = "shop" }
							end
						end
					end
				end
			end
		end
	end

	-- ── the anchors: hall entries, checkout lanes, goods-in ─────────────────────────────────────────────────
	local nAnch = n.parts
	local core = { 170, -140 }
	local GOODS = { NESTA = "MM_NESTA_GOODS" }
	for _, h in plan.halls do
		local x0, z0, x1, z1 = h.x0, h.z0, h.x1, h.z1
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		local dx, dz = core[1] - cx, core[2] - cz
		local side
		if math.abs(dx) > math.abs(dz) then
			side = dx > 0 and "E" or "W"
		else
			side = dz > 0 and "S" or "N"
		end
		local cf, size = frameOf(1, x0 + 1.2, z0 + 1.2, x1 - 1.2, z1 - 1.2, side, CEIL[1])
		local entry = {
			id = h.id, name = h.name, kind = "anchor", level = 1, front = side, cframe = cf, size = size,
			rect = { x0 = x0 + 1.2, z0 = z0 + 1.2, x1 = x1 - 1.2, z1 = z1 - 1.2 }, floorY = YL[1], ceilY = CEIL[1], service = false,
			doors = {}, entrances = {}, checkouts = {},
		}
		-- the checkout lanes: a row of floor strips across the hall 26 studs inside the front wall
		local dir = FRONT[side]
		local lanes = 8
		local across = (side == "N" or side == "S") and (x1 - x0) or (z1 - z0)
		local span = math.min(across * 0.6, 140)
		local pitch = span / (lanes - 1)
		local fx, fz
		if side == "N" then
			fx, fz = cx, z0 + 26
		elseif side == "S" then
			fx, fz = cx, z1 - 26
		elseif side == "W" then
			fx, fz = x0 + 26, cz
		else
			fx, fz = x1 - 26, cz
		end
		for q = 1, lanes do
			local off = -span / 2 + (q - 1) * pitch
			local lx, lz = fx, fz
			if side == "N" or side == "S" then
				lx = fx + off
			else
				lz = fz + off
			end
			local p
			if side == "N" or side == "S" then
				p = ab(ctx.m[1], lx - 0.5, YL[1] - 0.2, lz - 7, lx + 0.5, YL[1] + 0.05, lz + 7, hex("D0B24A"), M.SmoothPlastic)
			else
				p = ab(ctx.m[1], lx - 7, YL[1] - 0.2, lz - 0.5, lx + 7, YL[1] + 0.05, lz + 0.5, hex("D0B24A"), M.SmoothPlastic)
			end
			if p then
				p.Name = "CheckoutLane"
				p.CanCollide = false
				p:SetAttribute("NoDetail", true)
			end
			local pos = worldAt(1, lx, lz, 0)
			entry.checkouts[#entry.checkouts + 1] = CFrame.lookAt(pos, pos + Vector3.new(dir[1], 0, dir[2]))
		end
		-- goods-in: the back-of-house block behind the hall and its door
		for i, bk in plan.backs do
			if (i == 1 and h.id == "L1_idea") or (i == 2 and h.id == "L1_goshan") or ((i == 3 or i == 4) and h.id == "L1_oli") then
				entry.backs = entry.backs or {}
				table.insert(entry.backs, bk.id)
				for _, did in bk.doorIds or {} do
					table.insert(entry.doors, did)
				end
			end
		end
		entry.goodsIn = GOODS[h.name] or (entry.doors[1])
		B.units[h.id] = entry
	end
	-- the halls' openings: to the galleries (hall), to the terraces (entry) and the dock bays (dock; `open` when the shutter is up)
	for _, orient in { "v", "h" } do
		for _, r in plan.runs[1][orient] do
			for _, gp in r.gaps or {} do
				if gp.kind == "hall" or gp.kind == "entry" or gp.kind == "dock" then
					local line, along = r.x0, gp.c
					if orient == "h" then
						line, along = r.z0, gp.c
					end
					for _, h in plan.halls do
						local side, dist = nil, 0
						if orient == "v" and along > h.z0 and along < h.z1 then
							if math.abs(line - h.x0) < 3.2 then
								side, dist = "W", math.abs(line - h.x0)
							elseif math.abs(line - h.x1) < 3.2 then
								side, dist = "E", math.abs(line - h.x1)
							end
						elseif orient == "h" and along > h.x0 and along < h.x1 then
							if math.abs(line - h.z0) < 3.2 then
								side, dist = "N", math.abs(line - h.z0)
							elseif math.abs(line - h.z1) < 3.2 then
								side, dist = "S", math.abs(line - h.z1)
							end
						end
						if side then
							local x, z = line, along
							if orient == "h" then
								x, z = along, line
							end
							local e = B.units[h.id]
							if e then
								e.entrances[#e.entrances + 1] = {
									pos = worldAt(1, x, z, 0), width = gp.w, side = side, kind = gp.kind,
									open = (gp.kind == "dock") and (gp.spec ~= nil and gp.spec.open == true) or nil,
									along = along, dist = dist, -- scratch: removed below
								}
							end
						end
					end
				end
			end
		end
	end
	-- a wall that is two runs thick (the strip of one cell between a hall and its neighbour) opens in both faces: one entrance, the
	-- one at the hall's own edge
	for _, h in plan.halls do
		local e = B.units[h.id]
		if e then
			local keep = {}
			for i, a in e.entrances do
				local dup = false
				for j, b in e.entrances do
					if j ~= i and a.side == b.side and a.kind == b.kind and math.abs(a.along - b.along) < 1 then
						if b.dist < a.dist or (b.dist == a.dist and j < i) then
							dup = true
						end
					end
				end
				if not dup then
					keep[#keep + 1] = a
				end
			end
			for _, a in keep do
				a.along, a.dist = nil, nil
			end
			e.entrances = keep
		end
	end
	ctx.stat.anchors = n.parts - nAnch

	-- ── the car park zones: letters on the floor ─────────────────────────────────────────────────────────
	local nZone = n.parts
	local OK0 = { [OPEN] = true }
	for _, z in plan.zones do
		-- the free cell nearest to the middle of the zone
		local cx, cz = (z.x0 + z.x1) / 2, (z.z0 + z.z1) / 2
		local bestd, bx, bz = math.huge, nil, nil
		for iz = math.max(1, math.floor((z.z0 - g.z0) / g.cell) + 2), math.min(nz, math.floor((z.z1 - g.z0) / g.cell)) do
			for ix = math.max(1, math.floor((z.x0 - g.x0) / g.cell) + 2), math.min(nx, math.floor((z.x1 - g.x0) / g.cell)) do
				if labAt(0, ix, iz) == OPEN then
					local x, zz = cellX(ix), cellZ(iz)
					local d = (x - cx) * (x - cx) + (zz - cz) * (zz - cz)
					if d < bestd and clear(0, ix, iz, 2, OK0) then
						bestd, bx, bz = d, x, zz
					end
				end
			end
		end
		local id = z.id
		local entry = {
			id = id, name = z.name, kind = "parking", level = 0, front = nil, floorY = YL[0], ceilY = CEIL[0], service = false, doors = {},
			rect = { x0 = z.x0, z0 = z.z0, x1 = z.x1, z1 = z.z1 }, entrances = {},
		}
		entry.cframe = CFrame.new(O.X + cx, YL[0], O.Z + cz)
		entry.size = Vector3.new(z.x1 - z.x0, CEIL[0] - YL[0], z.z1 - z.z0)
		if bx then
			local label = z.name:gsub("CAR PARK ", "")
			local plate = ab(ctx.m[0], bx - 5, YL[0] - 0.2, bz - 5, bx + 5, YL[0] + 0.04, bz + 5, hex("2E3231"), M.Concrete)
			if plate then
				plate.Name = "ZoneMark"
				plate.CanCollide = false
				plate:SetAttribute("NoDetail", true)
				kit.sign(plate, Enum.NormalId.Top, label, hex("E0C45A"), nil)
				entry.mark = plate
			end
		end
		B.units[id] = entry
	end
	ctx.stat.zones = n.parts - nZone

	-- ── columns ──────────────────────────────────────────────────────────────────────────────────────────
	local nCol = n.parts
	local CON = C.concrete
	local function column(level, x, z, size, top)
		local y0 = YL[level]
		local p = ab(ctx.m[level], x - size / 2, y0 - 0.2, z - size / 2, x + size / 2, top, z + size / 2, CON, M.Concrete)
		if p then
			p.Name = "Column"
		end
	end
	-- L0: a grid of 16 cells (50 studs) over the car park floor, 3x3 free cells round each
	local STEP0 = 16
	for iz = 14, nz, STEP0 do
		for ix = 16, nx, STEP0 do
			if labAt(0, ix, iz) == OPEN and clear(0, ix, iz, 1, OK0) then
				local x, z = cellX(ix), cellZ(iz)
				if not blocked(0, x, z) then
					column(0, x, z, 3.2, CEIL[0])
				end
			end
		end
	end
	-- the shelter: the same grid inside the room, clear of the exit spot and the arch
	local sh = plan.rooms0.shelter
	local shK = sh.k
	for iz = 14, nz, STEP0 do
		for ix = 16, nx, STEP0 do
			if labAt(0, ix, iz) == shK then
				local x, z = cellX(ix), cellZ(iz)
				local okc = true
				for dz = -1, 1 do
					for dx = -1, 1 do
						if labAt(0, ix + dx, iz + dz) ~= shK then
							okc = false
						end
					end
				end
				local ex, ez = x - 512.5, z - 77.2
				if okc and ex * ex + ez * ez > 20 * 20 and not (math.abs(x - 412.5) < 24 and z > sh.z1 - 30) then
					column(0, x, z, 3.2, CEIL[0])
				end
			end
		end
	end
	-- the halls (L1): columns on a 22-cell grid inside the hall floor, off the entrances and the checkout lanes
	local OKH = { [HALL] = true }
	local STEPH = 22
	local lanePts = {}
	for _, h in plan.halls do
		local e = B.units[h.id]
		for _, cfq in e.checkouts or {} do
			local p = cfq.Position
			lanePts[#lanePts + 1] = { p.X - O.X, p.Z - O.Z }
		end
	end
	for iz = 4, nz, STEPH do
		for ix = 6, nx, STEPH do
			if labAt(1, ix, iz) == HALL and clear(1, ix, iz, 1, OKH) then
				local x, z = cellX(ix), cellZ(iz)
				local near = false
				for _, q in lanePts do
					if math.abs(x - q[1]) < 18 and math.abs(z - q[2]) < 18 then
						near = true
						break
					end
				end
				if not near and not blocked(1, x, z) then
					column(1, x, z, 3.6, CEIL[1])
				end
			end
		end
	end
	ctx.stat.columns = n.parts - nCol

	-- ── washrooms and the security room ──────────────────────────────────────────────────────────────────
	local nRooms = n.parts
	local wash = plan.wash2
	local TILE = hex("A9B2B0")
	-- the men's room: stalls along the west wall, a sink counter along the east wall, the valve cabinet's spot on the north wall
	do
		local u = wash.men
		local ix0, iz0, ix1, iz1 = u.x0 + 1.0, u.z0 + 1.0, u.x1 - 1.0, u.z1 - 1.0
		local y0 = YL[2]
		local par = ctx.m[2]
		for q = 0, 3 do
			local z = iz0 + 14 + q * 6.5
			ab(par, ix0, y0, z - 0.2, ix0 + 7.5, y0 + 7.5, z + 0.2, TILE, M.Plaster)
		end
		ab(par, ix0, y0, iz0 + 14 + 4 * 6.5 - 0.2, ix0 + 7.5, y0 + 7.5, iz0 + 14 + 4 * 6.5 + 0.2, TILE, M.Plaster)
		local sink = ab(par, ix1 - 3.2, y0, iz0 + 12, ix1, y0 + 3.2, iz0 + 30, hex("8C9694"), M.Concrete)
		if sink then
			sink.Name = "Sinks"
		end
		local mirror = ab(par, ix1 - 0.3, y0 + 5, iz0 + 13, ix1, y0 + 9, iz0 + 29, ctx.GLASS, M.Glass)
		ctx.glassOf(mirror)
		local cx = (ix0 + ix1) / 2
		local pos = Vector3.new(O.X + cx, YL[2] + 3.3, O.Z + iz0 + 0.9)
		B.points.SHELTER_SWITCH = CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
		wash.men.switchAt = { x = cx, z = iz0 + 0.9 }
	end
	do
		local u = wash.women
		local ix0, iz0, ix1, iz1 = u.x0 + 1.0, u.z0 + 1.0, u.x1 - 1.0, u.z1 - 1.0
		local y0 = YL[2]
		local par = ctx.m[2]
		for q = 0, 5 do
			local z = iz0 + 12 + q * 5.2
			ab(par, ix0, y0, z - 0.2, ix0 + 7.5, y0 + 7.5, z + 0.2, TILE, M.Plaster)
		end
		local sink = ab(par, ix1 - 3.2, y0, iz0 + 10, ix1, y0 + 3.2, iz0 + 28, hex("8C9694"), M.Concrete)
		if sink then
			sink.Name = "Sinks"
		end
		ctx.glassOf(ab(par, ix1 - 0.3, y0 + 5, iz0 + 11, ix1, y0 + 9, iz0 + 27, ctx.GLASS, M.Glass))
	end
	-- the security room: a desk with a monitor wall, a filing cabinet; the terminal's spot is on the north wall
	do
		local u = plan.security
		local ix0, iz0, ix1, iz1 = u.x0 + 1.0, u.z0 + 1.0, u.x1 - 1.0, u.z1 - 1.0
		local y0 = YL[1]
		local par = ctx.m[1]
		local cx = (ix0 + ix1) / 2
		B.points.SECURITY_TERMINAL = Vector3.new(O.X + cx, y0 + 3.3, O.Z + iz0 + 1.4)
		ab(par, ix0 + 1, y0, iz1 - 9, ix0 + 11, y0 + 3.0, iz1 - 3, hex("5B5F5A"), M.Metal) -- desk
		ab(par, ix0 + 3, y0 + 3.0, iz1 - 8.6, ix0 + 8, y0 + 5.2, iz1 - 8.3, hex("1E2423"), M.SmoothPlastic) -- monitor
		ab(par, ix0 + 1, y0, iz0 + 4, ix0 + 4, y0 + 6.5, iz0 + 12, hex("4C5250"), M.Metal) -- filing cabinets
		u.terminalAt = { x = cx, z = iz0 + 1.4 }
	end
	ctx.stat.rooms = n.parts - nRooms
	-- named points of the shelter
	B.points.SHELTER_DOOR = Vector3.new(O.X + 412.5, YL[0] + 3.3, O.Z + 171.9)
	B.points.SHELTER_ROOM = Vector3.new(O.X + 512.5, YL[0] + 3.3, O.Z + 77.2)

	-- ── lamps ────────────────────────────────────────────────────────────────────────────────────────────
	-- one lamp per block of cells, on the walkable cell nearest to the block's middle; the main lamps follow the power, the few
	-- emergency lamps stay lit. No lamp casts a shadow.
	local nLamp = n.parts
	local OKL = { [OPEN] = true, [HALL] = true }
	local function ceilAt(level, ix, iz)
		if level == 0 then
			return CEIL[0]
		elseif level == 2 then
			return CEIL[2]
		end
		if labAt(1, ix, iz) == HALL then
			return CEIL[1]
		end
		local l2 = labAt(2, ix, iz)
		if l2 ~= OUT and l2 ~= VOID then
			return CEIL[1]
		end
		return CEIL[2]
	end
	local function lamps(level, stride, offx, offz, main, range, brightness, limit)
		local placed = 0
		for bz = 1 + offz, nz, stride do
			for bx = 1 + offx, nx, stride do
				if not limit or placed < limit then
					local mx, mz = bx + stride / 2, bz + stride / 2
					local best, bix, biz = math.huge, nil, nil
					for iz = bz, math.min(nz, bz + stride - 1) do
						for ix = bx, math.min(nx, bx + stride - 1) do
							if OKL[labAt(level, ix, iz)] then
								local d = (ix - mx) * (ix - mx) + (iz - mz) * (iz - mz)
								if d < best and clear(level, ix, iz, 1, OKL) then
									best, bix, biz = d, ix, iz
								end
							end
						end
					end
					if bix then
						local x, z = cellX(bix), cellZ(biz)
						if not blocked(level, x, z) or not main then
							local cy = ceilAt(level, bix, biz) - 0.6
							local sx, sz = 5, 1.4
							if (bix + biz) % 2 == 0 then
								sx, sz = 1.4, 5
							end
							if not main then
								sx, sz = 1.2, 1.2
							end
							local p = ctx.lamp(ctx.m[level], x, cy, z, sx, 0.4, sz, range, brightness, main)
							if p then
								placed += 1
							end
						end
					end
				end
			end
		end
		return placed
	end
	-- with the power on the halls must read (Tarkov's lit Interchange); the lamps hang under ceilings up to 27 studs high,
	-- so the floors need more than the first pass's 0.8 (tested 2026-11-01: deep halls were black even with power)
	local mainL0 = lamps(0, 52, 0, 0, true, 52, 1.1)
	local mainL1 = lamps(1, 48, 0, 0, true, 60, 1.7)
	local mainL2 = lamps(2, 44, 0, 0, true, 54, 1.5)
	local emL0 = lamps(0, 70, 22, 30, false, 22, 0.5, 9)
	local emL1 = lamps(1, 70, 25, 28, false, 22, 0.5, 9)
	local emL2 = lamps(2, 60, 20, 25, false, 20, 0.5, 6)
	ctx.stat.lamps = n.parts - nLamp
	ctx.stat.lampMain = mainL0 + mainL1 + mainL2
	ctx.stat.lampEm = emL0 + emL1 + emL2

	-- the shelter's card reader and the security door stay lit: a red lamp over each
	for _, q in { { 0, 412.5, 175 }, { 1, plan.security.x1, (plan.security.z0 + plan.security.z1) / 2 } } do
		local level = q[1]
		local x, z = q[2], q[3]
		local p = ctx.lamp(ctx.m[level], x, YL[level] + 10.6, z, 1.0, 0.8, 1.0, 12, 0.5, false)
		if p then
			p.Name = "DoorLamp"
		end
	end
end
