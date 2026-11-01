--!nonstrict
-- Mall shell, the plan (no engine calls, plain Lua): rasterises the layout into one label array per level, snaps the store
-- units to the grid, links the stairs, voids and landings, finds the walls (as runs along grid lines), their openings, the slabs
-- and the roof. Mall.luau builds parts from it. Map-local studs, x east, z south.
-- Labels: OUT outside, OPEN walkable floor (galleries, car park), SOLID solid mass (hollow inside: walls only on its faces),
-- HALL the floor of an anchor hall, VOID a hole in the floor, FILL scratch (not yet claimed), TERR open-air deck (L1 terraces) or
-- ground (the west pad), UNIT + n the n-th unit (store, room, stock room).
local G = require(script.Parent.MallGrid)
local P = {}

local OUT, OPEN, SOLID, HALL, VOID, FILL, TERR, UNIT = 0, 1, 2, 3, 4, 5, 6, 10
P.OUT, P.OPEN, P.SOLID, P.HALL, P.VOID, P.FILL, P.TERR, P.UNIT = OUT, OPEN, SOLID, HALL, VOID, FILL, TERR, UNIT

local function set(list)
	local s = {}
	for _, v in list do
		s[v] = true
	end
	return s
end
local GROUND = set({ OPEN, HALL, TERR })
local SOFT = set({ OUT, SOLID, FILL, VOID }) -- what a landing or a stair well may overwrite
local FREE = set({ OPEN, FILL, SOLID }) -- what a block, hall or unit may overwrite

local function isWalk(l)
	return l == OPEN or l == HALL or l == TERR or l >= UNIT
end

local function recRect(r)
	local rot = r.rot or 0
	if math.abs(rot) > 45 then
		return r.cx - r.d / 2, r.cz - r.w / 2, r.cx + r.d / 2, r.cz + r.w / 2
	end
	return r.cx - r.w / 2, r.cz - r.d / 2, r.cx + r.w / 2, r.cz + r.d / 2
end

-- the plan is a few seconds of plain computation at the most: now and then the thread is handed back, so a slow server never runs
-- into the script timeout (outside the engine there is no `task` and this does nothing)
local lastPace = os.clock()
local function pace()
	if task and os.clock() - lastPace > 0.05 then
		task.wait()
		lastPace = os.clock()
	end
end

function P.build(L)
	local m = L.mall
	local H = L.H
	lastPace = os.clock()
	local g = G.new(-65.625, -965.625, 878.125, 668.75, 3.125)
	local c = g.cell
	local nx = g.nx
	local plan = { g = g, H = H, warn = {}, units = {}, byId = {}, halls = {}, zones = {}, links = {}, runs = {}, extraSlabs = {}, stats = {} }
	local function warn(s)
		plan.warn[#plan.warn + 1] = s
	end
	local lab0, lab1, lab2 = G.array(g, OUT), G.array(g, OUT), G.array(g, OUT)
	plan.lab = { [0] = lab0, [1] = lab1, [2] = lab2 }
	local levels = m.levels -- levels[1] = L0, levels[2] = L1, levels[3] = L2
	local YL = { [0] = H.ground, [1] = H.L1, [2] = H.L2 }
	local CEIL = { [0] = H.ceil[1], [1] = H.ceil[2], [2] = H.ceil[3] }
	plan.YL, plan.CEIL = YL, CEIL

	local function snap(x0, z0, x1, z1)
		local function sx(v)
			return g.x0 + math.floor((v - g.x0) / c + 0.5) * c
		end
		local function sz(v)
			return g.z0 + math.floor((v - g.z0) / c + 0.5) * c
		end
		x0, x1, z0, z1 = sx(x0), sx(x1), sz(z0), sz(z1)
		if x1 - x0 < 2 * c then
			x1 = x0 + 2 * c
		end
		if z1 - z0 < 2 * c then
			z1 = z0 + 2 * c
		end
		return x0, z0, x1, z1
	end

	-- a unit: a snapped rectangle with a label value of its own; opts: service (no glass front), top (wall height), name, kind
	local function addUnit(level, id, name, kind, x0, z0, x1, z1, rec, opts)
		opts = opts or {}
		x0, z0, x1, z1 = snap(x0, z0, x1, z1)
		local u = {
			id = id, name = name or "", kind = kind, level = level, x0 = x0, z0 = z0, x1 = x1, z1 = z1, rec = rec,
			service = opts.service, ents = {}, doors = opts.doors, arch = opts.arch, group = opts.group,
		}
		u.idx = #plan.units + 1
		u.k = UNIT + u.idx
		u.top = CEIL[level]
		u.open = opts.open
		plan.units[u.idx] = u
		plan.byId[id] = u
		if rec and rec.ent then
			for _, e in rec.ent do
				local along = (e[1] == "N" or e[1] == "S") and e[2] or e[3]
				u.ents[#u.ents + 1] = { side = e[1], c = along, w = e[4] }
			end
		end
		return u
	end
	plan.addUnit = addUnit

	-- ── L0 ───────────────────────────────────────────────────────────────────────────────────────────────
	G.poly(g, lab0, m.outline, SOLID)
	G.poly(g, lab0, levels[1].floor, OPEN)
	for _, p in m.pads do
		if p.id == "west_pad" then
			G.poly(g, lab0, p.pts, TERR, set({ OUT }))
			G.poly(g, lab0, p.pts, OPEN, set({ SOLID }))
		end
	end
	local svc = m.service
	for _, s in levels[1].stores do
		if s.kind == "parking" then
			local x0, z0, x1, z1 = recRect(s)
			plan.zones[#plan.zones + 1] = { id = s.id, name = s.name, x0 = x0, z0 = z0, x1 = x1, z1 = z1 }
		end
	end
	-- the rooms of L0 come from the service table (the reference's store records of the same rooms agree with them); their ids are the
	-- records' ids, so that every store of the layout is found in B.units under its own id
	local function storeId(name, fallback)
		for _, s in levels[1].stores do
			if s.name == name then
				return s.id
			end
		end
		return fallback
	end
	local tn, sh, u14 = svc.tunnel, svc.shelter, svc.unit14
	local rooms0 = {}
	rooms0.tunnel = addUnit(0, storeId("SERVICE TUNNEL", "SERVICE_TUNNEL"), "SERVICE TUNNEL", "tunnel", tn.x0, tn.z0, tn.x1, tn.z1, nil, { service = true })
	rooms0.shelter = addUnit(0, storeId("THE SHELTER", "THE_SHELTER"), "THE SHELTER", "shelter", sh.x0, sh.z0, sh.x1, sh.z1, nil, { service = true, group = "shelter" })
	rooms0.vest = addUnit(0, "SHELTER_VESTIBULE", "", "vestibule", 398.4, sh.z1, 425.0, 175.0, nil, { service = true, group = "shelter" })
	-- the reference's rectangle is grade D and crosses the stair V_L0_L1_2: the room keeps its north part
	rooms0.unit14 = addUnit(0, storeId("UNIT 14", "UNIT_14"), "UNIT 14", "unit14", u14.x0, u14.z0, u14.x1, -818.5, nil, { service = true })
	for _, k in { "tunnel", "shelter", "vest", "unit14" } do
		local u = rooms0[k]
		G.rect(g, lab0, u.x0, u.z0, u.x1, u.z1, u.k, nil)
	end
	-- the tunnel's east end: a passage through the solid mass to the KASSA garage (the reference's tunnel links the garages)
	do
		local tz = (rooms0.tunnel.z0 + rooms0.tunnel.z1) / 2
		for iz = G.row(g, tz - 7 + 0.01), G.row(g, tz + 7 - 0.01) do
			local ix = G.col(g, rooms0.tunnel.x1 + 0.01)
			while ix <= nx and lab0[(iz - 1) * nx + ix] == SOLID do
				lab0[(iz - 1) * nx + ix] = OPEN
				ix += 1
			end
		end
	end
	plan.rooms0 = rooms0
	pace()

	-- ── L1 ───────────────────────────────────────────────────────────────────────────────────────────────
	G.poly(g, lab1, m.outline, TERR)
	G.poly(g, lab1, m.outL1, TERR)
	for _, t in m.terraces do
		G.poly(g, lab1, t.pts, TERR)
	end
	G.poly(g, lab1, m.outL2, FILL)
	G.poly(g, lab1, levels[2].floor, OPEN, set({ FILL }))
	for _, w in levels[2].walls do
		if w.kind == "wall" or w.kind == "block" then
			G.poly(g, lab1, w.pts, SOLID, set({ FILL, OPEN }))
		end
	end
	for _, p in m.pads do
		if p.id == "garage_island" then
			G.poly(g, lab1, p.pts, OPEN, set({ FILL, SOLID, OUT, TERR }))
		end
	end
	-- the anchors' halls
	for _, s in levels[2].stores do
		if s.kind == "anchor" then
			local x0, z0, x1, z1 = recRect(s)
			x0, z0, x1, z1 = snap(x0, z0, x1, z1)
			local h = { id = s.id, name = s.name, kind = "hall", level = 1, x0 = x0, z0 = z0, x1 = x1, z1 = z1, rec = s }
			plan.halls[#plan.halls + 1] = h
			plan.byId[s.id] = h
			G.rect(g, lab1, x0, z0, x1, z1, HALL, set({ OPEN, FILL, SOLID }))
		end
	end
	-- an unclaimed strip of the envelope next to a hall (up to 50 studs) belongs to the hall
	for _, h in plan.halls do
		local ex0, ez0, ex1, ez1 = h.x0 - 50, h.z0 - 50, h.x1 + 50, h.z1 + 50
		local i0, i1 = math.max(1, G.col(g, ex0)), math.min(g.nx, G.col(g, ex1))
		local j0, j1 = math.max(1, G.row(g, ez0)), math.min(g.nz, G.row(g, ez1))
		local queue, qn = {}, 0
		for iz = G.row(g, h.z0), G.row(g, h.z1 - 0.01) do
			for ix = G.col(g, h.x0), G.col(g, h.x1 - 0.01) do
				if lab1[(iz - 1) * nx + ix] == HALL then
					qn += 1
					queue[qn] = (iz - 1) * nx + ix
				end
			end
		end
		local head = 1
		while head <= qn do
			local idx = queue[head]
			head += 1
			local iz = math.floor((idx - 1) / nx) + 1
			local ix = idx - (iz - 1) * nx
			for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local jx, jz = ix + d[1], iz + d[2]
				if jx >= i0 and jx <= i1 and jz >= j0 and jz <= j1 then
					local k = (jz - 1) * nx + jx
					if lab1[k] == FILL then
						lab1[k] = HALL
						qn += 1
						queue[qn] = k
					end
				end
			end
		end
	end
	-- a thin walkway (up to 5 cells wide) between a hall and a mass, a wall or the deck is part of the hall (the dock aisles)
	do
		local claim = {}
		local nz2 = g.nz
		for iz = 1, nz2 do
			for ix = 1, nx do
				local k = (iz - 1) * nx + ix
				if lab1[k] == OPEN then
					for axis = 1, 2 do
						local step = (axis == 1) and 1 or nx
						local lim = (axis == 1) and ix or iz
						local top = (axis == 1) and nx or nz2
						local lt, rt = nil, nil
						local n = 0
						while n < 6 do
							n += 1
							local pos = lim - n
							if pos < 1 then
								lt = OUT
								break
							end
							local v = lab1[k - n * step]
							if v ~= OPEN then
								lt = v
								break
							end
						end
						n = 0
						while n < 6 do
							n += 1
							local pos = lim + n
							if pos > top then
								rt = OUT
								break
							end
							local v = lab1[k + n * step]
							if v ~= OPEN then
								rt = v
								break
							end
						end
						if lt and rt and ((lt == HALL and (rt == SOLID or rt == FILL or rt == TERR or rt == OUT)) or (rt == HALL and (lt == SOLID or lt == FILL or lt == TERR or lt == OUT))) then
							claim[#claim + 1] = k
						end
					end
				end
			end
		end
		for _, k in claim do
			lab1[k] = HALL
		end
	end
	-- the stores of L1 (the canteen is a big one), then the hall service blocks
	for _, s in levels[2].stores do
		if s.kind ~= "anchor" then
			local x0, z0, x1, z1 = recRect(s)
			local u = addUnit(1, s.id, s.name, s.kind, x0, z0, x1, z1, s, { open = (s.kind == "food" and s.w > 150) })
			G.rect(g, lab1, u.x0, u.z0, u.x1, u.z1, u.k, nil)
		end
	end
	local backs = {}
	for i, b in svc.back do
		local u = addUnit(1, "BACK_" .. i, b.name, "stock", b.x0, b.z0, b.x1, b.z1, nil, { service = true })
		G.rect(g, lab1, u.x0, u.z0, u.x1, u.z1, u.k, nil)
		backs[i] = u
	end
	plan.backs = backs
	-- the security room of the first floor (the alarm terminal's room): a service room inside the hall at the reference's marker,
	-- against the hall's south wall
	do
		local sp = L.poi.SECURITY_L1
		local u = addUnit(1, "SECURITY_ROOM", "SECURITY", "security", sp[1] - 12.5, sp[2] - 18.75, sp[1] + 12.5, sp[2] + 9.4, nil, { service = true })
		local foreign = 0
		for iz = G.row(g, u.z0 + 0.01), G.row(g, u.z1 - 0.01) do
			for ix = G.col(g, u.x0 + 0.01), G.col(g, u.x1 - 0.01) do
				if lab1[(iz - 1) * nx + ix] ~= HALL then
					foreign += 1
				end
			end
		end
		if foreign > 0 then
			warn(string.format("SECURITY_ROOM: %d cells are not hall floor", foreign))
		end
		G.rect(g, lab1, u.x0, u.z0, u.x1, u.z1, u.k, nil)
		plan.security = u
	end
	pace()

	-- ── L2 ───────────────────────────────────────────────────────────────────────────────────────────────
	G.poly(g, lab2, levels[3].floor, OPEN)
	for _, w in levels[3].walls do
		if w.kind == "wall" or w.kind == "block" then
			G.poly(g, lab2, w.pts, SOLID, set({ OUT, OPEN }))
		end
	end
	for _, s in levels[3].stores do
		local x0, z0, x1, z1 = recRect(s)
		local opts = nil
		if s.id == "L2_burger_spot_49" then
			-- the washrooms take the east part of this food unit (the reference puts the washroom with the hidden switch here); the unit
			-- keeps the reference's washroom centre (359.4, -287.5), where the card key lies, on its floor
			x1 = x0 + 59.375
		end
		local u = addUnit(2, s.id, s.name, s.kind, x0, z0, x1, z1, s, opts)
		G.rect(g, lab2, u.x0, u.z0, u.x1, u.z1, u.k, nil)
	end
	do
		local wr = svc.washroom
		local wx0 = plan.byId["L2_burger_spot_49"].x1
		local men = addUnit(2, "WASH_L2_MEN", "MEN", "washroom", wx0, wr.z0, wx0 + 28.125, wr.z1, nil, { service = true, group = "wash2" })
		local wom = addUnit(2, "WASH_L2_WOMEN", "WOMEN", "washroom", wx0 + 28.125, wr.z0, wr.x1, wr.z1, nil, { service = true, group = "wash2" })
		G.rect(g, lab2, men.x0, men.z0, men.x1, men.z1, men.k, nil)
		G.rect(g, lab2, wom.x0, wom.z0, wom.x1, wom.z1, wom.k, nil)
		plan.wash2 = { men = men, women = wom }
	end
	pace()

	-- ── atria and voids ──────────────────────────────────────────────────────────────────────────────────
	plan.atria = {}
	for _, a in m.atria do
		G.poly(g, lab1, a.pts, VOID, set({ OPEN, FILL, SOLID, HALL, TERR }))
		G.poly(g, lab2, a.pts, VOID, nil)
		G.poly(g, lab0, a.pts, OPEN, set({ OUT, SOLID }))
		-- the apothem (the shortest distance from the middle to an edge), used for the roof hole and the dome drum
		local np = math.floor(#a.pts / 2)
		local ap = math.huge
		for i = 1, np do
			local j = i % np + 1
			local ex, ez = a.pts[2 * j - 1] - a.pts[2 * i - 1], a.pts[2 * j] - a.pts[2 * i]
			local len = math.sqrt(ex * ex + ez * ez)
			if len > 0 then
				local d = math.abs((a.cx - a.pts[2 * i - 1]) * ez - (a.cz - a.pts[2 * i]) * ex) / len
				if d < ap then
					ap = d
				end
			end
		end
		plan.atria[#plan.atria + 1] = { id = a.id, cx = a.cx, cz = a.cz, pts = a.pts, ap = ap }
	end
	local concourse = nil
	for _, v in m.voids do
		if v.id == "L2_void_central_concourse" then
			G.poly(g, lab2, v.pts, VOID, nil)
			concourse = v
		end
	end
	plan.concourse = concourse
	-- an L2 block that holds an escalator flight is a void too (the reference draws the shaft as a block)
	local escs = {}
	for _, v in m.vert do
		if v.kind == "escalator_or_stair" then
			escs[#escs + 1] = v
		end
	end
	for _, w in levels[3].walls do
		if w.kind == "block" then
			for _, e in escs do
				if e.x0 > w.cx - w.w / 2 and e.x1 < w.cx + w.w / 2 and e.z0 > w.cz - w.d / 2 and e.z0 < w.cz + w.d / 2 then
					G.poly(g, lab2, w.pts, VOID, set({ OPEN, SOLID, OUT }))
					break
				end
			end
		end
	end

	pace()
	-- ── stairs, ramps and escalators ─────────────────────────────────────────────────────────────────────
	-- walk from the end of a flight outwards in cell-deep strips, turning what is not floor into floor until the strip lands on
	-- floor (after at least minLen studs) or maxLen is reached
	local function landing(arr, x, z, ux, uz, w, minLen, maxLen)
		local n = math.ceil(maxLen / c)
		for s = 0, n - 1 do
			local a0, a1 = s * c, (s + 1) * c
			local x0, x1, z0, z1
			if ux ~= 0 then
				x0, x1 = x + ux * a0, x + ux * a1
				if x0 > x1 then
					x0, x1 = x1, x0
				end
				z0, z1 = z - w / 2, z + w / 2
			else
				z0, z1 = z + uz * a0, z + uz * a1
				if z0 > z1 then
					z0, z1 = z1, z0
				end
				x0, x1 = x - w / 2, x + w / 2
			end
			local tot = G.count(g, arr, x0, z0, x1, z1, nil)
			local walk = 0
			for iz = G.row(g, z0 + 0.01), G.row(g, z1 - 0.01) do
				for ix = G.col(g, x0 + 0.01), G.col(g, x1 - 0.01) do
					if isWalk(arr[(iz - 1) * nx + ix]) then
						walk += 1
					end
				end
			end
			if a0 >= minLen and tot > 0 and walk * 5 >= tot * 4 then
				return a0
			end
			G.rect(g, arr, x0, z0, x1, z1, OPEN, SOFT)
		end
		return maxLen
	end
	plan.links = {}
	for _, v in m.vert do
		if v.w then
			local dx, dz = v.x1 - v.x0, v.z1 - v.z0
			local ln = {
				id = v.id, w = v.w, rise = v.rise, rec = v, joins = v.joins,
			}
			if math.abs(dx) >= math.abs(dz) then
				ln.ux, ln.uz = dx > 0 and 1 or -1, 0
				ln.ax = (v.z0 + v.z1) / 2
				ln.x0, ln.z0, ln.x1, ln.z1 = v.x0, ln.ax, v.x1, ln.ax
			else
				ln.ux, ln.uz = 0, dz > 0 and 1 or -1
				ln.ax = (v.x0 + v.x1) / 2
				ln.x0, ln.z0, ln.x1, ln.z1 = ln.ax, v.z0, ln.ax, v.z1
			end
			if v.id:sub(1, 5) ~= "V_OUT" then
				-- the flight sits on the grid (ends on grid lines, a whole number of cells wide) so that the opening in the upper
				-- floor is exactly the flight
				local function onLine(val, base)
					return base + math.floor((val - base) / c + 0.5) * c
				end
				local cells = math.max(3, math.floor(v.w / c + 0.5))
				ln.w = cells * c
				if ln.ux ~= 0 then
					ln.x0, ln.x1 = onLine(ln.x0, g.x0), onLine(ln.x1, g.x0)
					ln.ax = onLine(ln.ax - ln.w / 2, g.z0) + ln.w / 2
					ln.z0, ln.z1 = ln.ax, ln.ax
				else
					ln.z0, ln.z1 = onLine(ln.z0, g.z0), onLine(ln.z1, g.z0)
					ln.ax = onLine(ln.ax - ln.w / 2, g.x0) + ln.w / 2
					ln.x0, ln.x1 = ln.ax, ln.ax
				end
				dx, dz = ln.x1 - ln.x0, ln.z1 - ln.z0
			end
			ln.len = math.abs(dx) + math.abs(dz)
			local hw = ln.w / 2
			ln.rx0, ln.rx1 = math.min(ln.x0, ln.x1), math.max(ln.x0, ln.x1)
			ln.rz0, ln.rz1 = math.min(ln.z0, ln.z1), math.max(ln.z0, ln.z1)
			if ln.ux ~= 0 then
				ln.rz0, ln.rz1 = ln.rz0 - hw, ln.rz1 + hw
			else
				ln.rx0, ln.rx1 = ln.rx0 - hw, ln.rx1 + hw
			end
			if v.id:sub(1, 5) == "V_OUT" then
				ln.type = "vehicle"
			elseif v.kind == "escalator_or_stair" then
				ln.type = "escalator"
			elseif v.id == "V_L0_L1_0" then
				ln.type = "ramp"
			else
				ln.type = "stairs"
			end
			local lowL = (v.joins[1] == "L0") and 0 or ((v.joins[1] == "L1") and 1 or -1)
			ln.lo, ln.hi = lowL, lowL + 1
			plan.links[#plan.links + 1] = ln
			if ln.type ~= "vehicle" then
				local lowArr, hiArr = plan.lab[ln.lo], plan.lab[ln.hi]
				-- the flight stands on the lower floor and opens the upper one
				local nUnit = 0
				for iz = G.row(g, ln.rz0 + 0.01), G.row(g, ln.rz1 - 0.01) do
					for ix = G.col(g, ln.rx0 + 0.01), G.col(g, ln.rx1 - 0.01) do
						if hiArr[(iz - 1) * nx + ix] >= UNIT or lowArr[(iz - 1) * nx + ix] >= UNIT then
							nUnit += 1
						end
					end
				end
				local inOpen = false
				for _, u in plan.units do
					if u.open and u.level == ln.hi and ln.rx0 >= u.x0 and ln.rx1 <= u.x1 and ln.rz0 >= u.z0 and ln.rz1 <= u.z1 then
						inOpen = true
					end
				end
				if nUnit > 0 and not inOpen then
					warn(string.format("%s: %d cells of the flight lie in units", v.id, nUnit))
				end
				G.rect(g, lowArr, ln.rx0, ln.rz0, ln.rx1, ln.rz1, OPEN, SOFT)
				for _, u in plan.units do
					if u.open and u.level == ln.hi and ln.rx0 >= u.x0 and ln.rx1 <= u.x1 and ln.rz0 >= u.z0 and ln.rz1 <= u.z1 then
						G.rect(g, hiArr, ln.rx0, ln.rz0, ln.rx1, ln.rz1, VOID, set({ u.k }))
						ln.inUnit = u
					end
				end
				if ln.type == "escalator" then
					G.rect(g, hiArr, ln.rx0, ln.rz0, ln.rx1, ln.rz1, VOID, set({ OPEN, SOLID, OUT }))
				else
					G.rect(g, hiArr, ln.rx0, ln.rz0, ln.rx1, ln.rz1, VOID, set({ OPEN, FILL, SOLID, HALL, TERR, OUT }))
				end
				ln.landHi = landing(hiArr, ln.x1, ln.z1, ln.ux, ln.uz, ln.w, 6, 40)
				ln.landLo = landing(lowArr, ln.x0, ln.z0, -ln.ux, -ln.uz, ln.w, 6, 40)
			end
		end
	end

	-- the dock ramps (built by Ground): the deck must meet their high ends, and the parapet is open there
	plan.outRamps = {}
	for _, ln in plan.links do
		if ln.type == "vehicle" then
			plan.outRamps[#plan.outRamps + 1] = ln
			local hw = ln.w / 2
			local x0, x1, z0, z1
			if ln.ux ~= 0 then
				x0, x1 = ln.x1 - ln.ux * 0.3, ln.x1 + ln.ux * -9
				x0, x1 = math.min(x0, x1), math.max(x0, x1)
				z0, z1 = ln.z1 - hw, ln.z1 + hw
			else
				z0, z1 = ln.z1 - ln.uz * 0.3, ln.z1 + ln.uz * -9
				z0, z1 = math.min(z0, z1), math.max(z0, z1)
				x0, x1 = ln.x1 - hw, ln.x1 + hw
			end
			plan.extraSlabs[#plan.extraSlabs + 1] = { level = 1, x0 = x0, x1 = x1, z0 = z0, z1 = z1, k = 4 }
		end
	end

	-- whatever of the envelope no hall or store took is solid mass
	for i = 1, g.n do
		if lab1[i] == FILL then
			lab1[i] = SOLID
		end
	end
	-- the reference's outlines are ragged (wall stubs, one-cell notches): fill the dents, drop the splinters
	local function smooth(arr, a, b, passes)
		for _ = 1, passes do
			local flips = {}
			for iz = 1, g.nz do
				for ix = 1, nx do
					local k = (iz - 1) * nx + ix
					local l = arr[k]
					if l == a or l == b then
						local na, nb = 0, 0
						local n1 = ix > 1 and arr[k - 1] or -1
						local n2 = ix < nx and arr[k + 1] or -1
						local n3 = iz > 1 and arr[k - nx] or -1
						local n4 = iz < g.nz and arr[k + nx] or -1
						for _, v in { n1, n2, n3, n4 } do
							if v == a then
								na += 1
							elseif v == b then
								nb += 1
							end
						end
						if l == a and nb >= 3 then
							flips[#flips + 1] = k
						elseif l == b and na >= 3 then
							flips[#flips + 1] = k
						end
					end
				end
			end
			if #flips == 0 then
				return
			end
			for _, k in flips do
				if arr[k] == a then
					arr[k] = b
				else
					arr[k] = a
				end
			end
		end
	end
	-- pockets of floor that nothing joins (an atrium's floor on L0) get a corridor to the main floor; specks are filled
	local function joinPockets(arr, widen)
		local comp = G.array(g, 0)
		local sizes, outdoor, cid = {}, {}, 0
		for k = 1, g.n do
			if comp[k] == 0 and (arr[k] == OPEN or arr[k] == TERR) then
				cid += 1
				local q, qn, head = { k }, 1, 1
				comp[k] = cid
				local od = false
				while head <= qn do
					local idx = q[head]
					head += 1
					if arr[idx] == TERR then
						od = true
					end
					local iz = math.floor((idx - 1) / nx) + 1
					local ix = idx - (iz - 1) * nx
					local nbr = { ix > 1 and idx - 1 or 0, ix < nx and idx + 1 or 0, iz > 1 and idx - nx or 0, iz < g.nz and idx + nx or 0 }
					for _, nk in nbr do
						if nk > 0 and comp[nk] == 0 and (arr[nk] == OPEN or arr[nk] == TERR) then
							comp[nk] = cid
							qn += 1
							q[qn] = nk
						end
					end
				end
				sizes[cid] = qn
				outdoor[cid] = od
			end
		end
		local main, best = 0, 0
		for id, n in sizes do
			if n > best then
				main, best = id, n
			end
		end
		for id = 1, cid do
			if id ~= main and not outdoor[id] then
				local cells = {}
				for k = 1, g.n do
					if comp[k] == id then
						cells[#cells + 1] = k
					end
				end
				if #cells < 4 then
					for _, k in cells do
						arr[k] = SOLID
					end
				else
					-- breadth first through solid mass to the main floor
					local parent = {}
					local q, qn, head = {}, 0, 1
					for _, k in cells do
						qn += 1
						q[qn] = k
						parent[k] = -1
					end
					local goal = nil
					while head <= qn and not goal do
						local idx = q[head]
						head += 1
						local iz = math.floor((idx - 1) / nx) + 1
						local ix = idx - (iz - 1) * nx
						local nbr = { ix > 1 and idx - 1 or 0, ix < nx and idx + 1 or 0, iz > 1 and idx - nx or 0, iz < g.nz and idx + nx or 0 }
						for _, nk in nbr do
							if nk > 0 and not parent[nk] and not goal then
								local v = arr[nk]
								if comp[nk] == main then
									parent[nk] = idx
									goal = nk
								elseif v == SOLID then
									parent[nk] = idx
									qn += 1
									q[qn] = nk
								end
							end
						end
					end
					if goal then
						local cur = parent[goal]
						while cur and cur > 0 and parent[cur] ~= -1 do
							local iz = math.floor((cur - 1) / nx) + 1
							local ix = cur - (iz - 1) * nx
							for dz = -widen, widen do
								for dx = -widen, widen do
									local jx, jz = ix + dx, iz + dz
									if jx >= 1 and jx <= nx and jz >= 1 and jz <= g.nz and arr[(jz - 1) * nx + jx] == SOLID then
										arr[(jz - 1) * nx + jx] = OPEN
									end
								end
							end
							cur = parent[cur]
						end
						plan.stats.joined = (plan.stats.joined or 0) + 1
					else
						warn("floor pocket of " .. #cells .. " cells could not be joined")
					end
				end
			end
		end
	end
	pace()
	smooth(lab0, OPEN, SOLID, 2)
	joinPockets(lab0, 2)
	pace()
	smooth(lab1, OPEN, SOLID, 2)
	smooth(lab2, OPEN, SOLID, 2)
	smooth(lab2, OUT, OPEN, 2)
	smooth(lab2, OUT, SOLID, 2)
	-- an L1 store that stands under the open roof (no L2 above it) is as tall as the space around it
	for _, u in plan.units do
		if u.level == 1 then
			local tot, open = 0, 0
			for iz = G.row(g, u.z0 + 0.01), G.row(g, u.z1 - 0.01) do
				for ix = G.col(g, u.x0 + 0.01), G.col(g, u.x1 - 0.01) do
					tot += 1
					local l2 = lab2[(iz - 1) * nx + ix]
					if l2 == OUT or l2 == VOID then
						open += 1
					end
				end
			end
			if tot > 0 and open * 2 > tot then
				u.top = CEIL[2]
			end
		end
	end
	P.edges(plan, L)
	return plan
end

-- ── walls ────────────────────────────────────────────────────────────────────────────────────────────────
-- the kind of wall between two neighbouring cells (a = west or north): style wall (plain), front (a store's glass front), ext
-- (outer wall), rail (balustrade; walk = the side people stand on), parapet (low wall round a deck)
local function classifier(plan, level)
	local units, lab2 = plan.units, plan.lab[2]
	local y0 = plan.YL[level]
	local CEIL = plan.CEIL
	local memo = {}
	local function spaceTop(idx)
		if level == 0 then
			return CEIL[0]
		elseif level == 2 then
			return CEIL[2]
		end
		local l2 = lab2[idx]
		if l2 ~= OUT and l2 ~= VOID then
			return CEIL[1]
		end
		return CEIL[2]
	end
	local function unitOf(l)
		if l >= UNIT then
			return units[l - UNIT]
		end
		return nil
	end
	local function cat(l)
		if l == OUT then
			return "out"
		elseif l == SOLID or l == FILL then
			return "solid"
		elseif l == OPEN then
			return "open"
		elseif l == HALL then
			return "hall"
		elseif l == VOID then
			return "void"
		elseif l == TERR then
			return "deck"
		end
		return "unit"
	end
	local function info(style, wall, t, top, pair, extra)
		local key = style .. "|" .. t .. "|" .. (top or 0) .. "|" .. pair .. "|" .. (extra and extra.key or "")
		local i = memo[key]
		if not i then
			i = { style = style, wall = wall, t = t, y0 = y0, top = top, pair = pair, level = level }
			if extra then
				for k, v in extra do
					i[k] = v
				end
			end
			memo[key] = i
		end
		return i
	end
	-- the ceiling that a wall next to this cell must reach (units have a lower ceiling of their own)
	local function wallTop(l, idx)
		local u = unitOf(l)
		if u then
			return u.top
		elseif l == HALL then
			return CEIL[1]
		elseif l == OPEN or l == VOID or l == SOLID or l == FILL then
			return spaceTop(idx)
		end
		return nil
	end
	local function classify(la, lb, ia, ib, vertical, ix, iz)
		local ca, cb = cat(la), cat(lb)
		local pair = ca .. "|" .. cb
		local ua, ub = unitOf(la), unitOf(lb)
		-- outside the building (nothing, or an open-air deck / the west pad)
		local outA = (ca == "out" or ca == "deck")
		local outB = (cb == "out" or cb == "deck")
		if outA or outB then
			if outA and outB then
				if level == 1 then
					return info("parapet", true, 1.6, y0 + 3.4, pair)
				end
				return nil
			end
			local o, oi, oc = la, ia, ca
			local deck = cb == "deck"
			if outA then
				o, oi, oc = lb, ib, cb
				deck = ca == "deck"
			end
			if level == 0 and deck and oc == "open" then
				return nil -- the west pad opens into the car park
			end
			if oc == "void" then
				return info("rail", false, 0, nil, pair, { key = outA and "b" or "a", walk = outA and "b" or "a" })
			end
			local u = unitOf(o)
			local top = CEIL[0]
			if level ~= 0 then
				if oc == "hall" then
					top = CEIL[1] + 1.6
				elseif u then
					top = u.top + 1.6
				else
					top = spaceTop(oi) + 1.6
				end
			end
			return info("ext", true, 2.4, top, pair, { key = u and u.id or "", unit = u })
		end
		if ca == "solid" and cb == "solid" then
			return nil
		end
		-- voids: a rail where people stand beside them, a wall against masses and stores
		if ca == "void" or cb == "void" then
			local o, oc = lb, cb
			local walk = "b"
			if ca ~= "void" then
				o, oc = la, ca
				walk = "a"
			end
			local u = unitOf(o)
			if oc == "open" or oc == "hall" or (u and u.open) then
				return info("rail", false, 0, nil, pair, { key = walk, walk = walk })
			end
			local vi = (ca == "void") and ia or ib
			return info("wall", true, 2.0, wallTop(o, (ca == "void") and ib or ia) or spaceTop(vi), pair, { key = u and u.id or "", unit = u })
		end
		-- solid mass against a space
		if ca == "solid" or cb == "solid" then
			local o, oi = lb, ib
			if cb == "solid" then
				o, oi = la, ia
			end
			local u = unitOf(o)
			return info("wall", true, 2.0, wallTop(o, oi), pair, { key = u and u.id or "", unit = u })
		end
		-- space against space: stores, halls, galleries
		if ua or ub then
			local top = math.max(ua and ua.top or 0, ub and ub.top or 0)
			if ua and ub then
				return info("wall", true, 2.0, top, pair, { key = ua.id .. ">" .. ub.id, unit = ua, unit2 = ub })
			end
			local u = ua or ub
			local o = ua and lb or la
			local side
			if vertical then
				side = ua and "E" or "W"
			else
				side = ua and "S" or "N"
			end
			local style = "front"
			if u.service then
				style = "wall"
			end
			return info(style, true, 2.0, top, pair, { key = u.id .. ":" .. side, unit = u, side = side })
		end
		-- OPEN | HALL
		local top = math.max(wallTop(la, ia) or 0, wallTop(lb, ib) or 0)
		return info("wall", true, 2.0, top, pair, { key = "hall" })
	end
	-- the same wall with another top (same key scheme as info)
	local function retop(i, top)
		local key = i.style .. "|" .. i.t .. "|" .. top .. "|" .. i.pair .. "|" .. (i.key or "")
		local n = memo[key]
		if not n then
			n = {}
			for k, v in i do
				n[k] = v
			end
			n.top = top
			memo[key] = n
		end
		return n
	end
	return function(la, lb, ia, ib, vertical, ix, iz)
		local i = classify(la, lb, ia, ib, vertical, ix, iz)
		-- an L1 wall that has an L2 floor above either of its sides stops under that floor (the L2 walls and rails stand on it): a
		-- tall store (open to the roof over most of its area) must not push its walls up through the gallery floors
		if i and level == 1 and i.top and i.wall then
			local a, b = lab2[ia], lab2[ib]
			if (a ~= OUT and a ~= VOID) or (b ~= OUT and b ~= VOID) then
				local c = CEIL[1]
				if i.style == "ext" then
					c = CEIL[1] + 1.6
				end
				if i.top > c then
					return retop(i, c)
				end
			end
		end
		return i
	end
end

-- ── openings ─────────────────────────────────────────────────────────────────────────────────────────────
-- a run's extent along its axis: horizontal runs along x, vertical along z
local function runSpan(r)
	if r.x0 == r.x1 then
		return r.z0 - (r.ext0 or 0), r.z1 + (r.ext1 or 0), "z"
	end
	return r.x0 - (r.ext0 or 0), r.x1 + (r.ext1 or 0), "x"
end

-- adds an opening centred on c (clipped into the run); false when it does not fit or touches another
local function addGap(r, c, w, h, kind, spec)
	local lo, hi = runSpan(r)
	-- a gap keeps clear of the ends of its run, and of the reach of a collinear neighbour (two runs that meet at a corner each
	-- lengthen by half a thickness into the other)
	lo, hi = lo + 1.5 + 2 * math.max(r.ext0 or 0, 0), hi - 1.5 - 2 * math.max(r.ext1 or 0, 0)
	if hi - lo < 4 then
		return false
	end
	if w > hi - lo then
		w = hi - lo
	end
	if c - w / 2 < lo then
		c = lo + w / 2
	end
	if c + w / 2 > hi then
		c = hi - w / 2
	end
	r.gaps = r.gaps or {}
	for _, o in r.gaps do
		if math.abs(c - o.c) < (w + o.w) / 2 + 1 then
			return false
		end
	end
	r.gaps[#r.gaps + 1] = { c = c, w = w, h = h, kind = kind, spec = spec }
	table.sort(r.gaps, function(a, b)
		return a.c < b.c
	end)
	return true
end
P.addGap = addGap

local function allRuns(plan, level)
	local list = {}
	for _, r in plan.runs[level].v do
		list[#list + 1] = r
	end
	for _, r in plan.runs[level].h do
		list[#list + 1] = r
	end
	return list
end

local SIDEAXIS = { N = "x", S = "x", E = "z", W = "z" }

function P.gaps(plan, L)
	local m = L.mall
	for level = 0, 2 do
		local runs = allRuns(plan, level)
		-- the units' own openings
		local frontRuns = {}
		for _, r in runs do
			local i = r.info
			if i.style == "front" then
				local u = i.unit
				frontRuns[u.idx] = frontRuns[u.idx] or {}
				table.insert(frontRuns[u.idx], r)
				local _, _, axis = runSpan(r)
				for _, e in u.ents do
					if e.side == i.side and SIDEAXIS[e.side] == axis then
						local w = e.w
						local lo, hi = runSpan(r)
						if w >= 37.5 then
							w = math.min(w, hi - lo - 6)
						end
						addGap(r, e.c, w, 13, "shop", { unit = u, wide = e.w >= 37.5 })
					end
				end
			end
		end
		for _, u in plan.units do
			if u.level == level and not u.service then
				local runsU = frontRuns[u.idx] or {}
				local has = false
				local best, bestLen = nil, 0
				for _, r in runsU do
					if r.gaps and #r.gaps > 0 then
						has = true
					end
					local lo, hi = runSpan(r)
					if hi - lo > bestLen then
						best, bestLen = r, hi - lo
					end
				end
				if not has and best then
					local lo, hi = runSpan(best)
					addGap(best, (lo + hi) / 2, math.min(14, bestLen - 4), 13, "shop", { unit = u, auto = true })
					plan.stats.autoEntrances = (plan.stats.autoEntrances or 0) + 1
				elseif not has then
					plan.warn[#plan.warn + 1] = "unit " .. u.id .. " has no open front"
				end
			end
		end
		-- doors and arches of the service units
		for _, r in runs do
			local i = r.info
			if i.style == "wall" or i.style == "ext" then
				local lo, hi, axis = runSpan(r)
				for _, u in { i.unit, i.unit2 } do
					if u and u.doors then
						local side = nil
						if axis == "x" then
							local zline = r.z0
							if math.abs(zline - u.z0) < 0.1 then
								side = "N"
							elseif math.abs(zline - u.z1) < 0.1 then
								side = "S"
							end
						else
							local xline = r.x0
							if math.abs(xline - u.x0) < 0.1 then
								side = "W"
							elseif math.abs(xline - u.x1) < 0.1 then
								side = "E"
							end
						end
						for _, d in u.doors do
							if d.side == side and SIDEAXIS[side] == axis and not d.placed then
								local sideLo, sideHi = u.x0, u.x1
								if axis == "z" then
									sideLo, sideHi = u.z0, u.z1
								end
								local c = math.min(math.max(d.c, sideLo + d.w / 2 + 3), sideHi - d.w / 2 - 3)
								local needUnit2 = d.kind == "arch"
								local pairOk = true
								if needUnit2 then
									pairOk = i.unit2 ~= nil
								elseif i.pair:find("solid") then
									pairOk = false
								end
								if pairOk and c > lo and c < hi and addGap(r, c, d.w, d.h or 8.6, d.kind, d) then
									d.placed = true
									d.unit = u
								end
							end
						end
					end
				end
			end
		end
		-- hall entrances, building doors on the decks, the car park's gates
		local cand = {}
		for _, r in runs do
			local i = r.info
			local lo, hi = runSpan(r)
			local len = hi - lo
			if (i.style == "wall" and (i.pair == "open|hall" or i.pair == "hall|open")) and len >= 20 then
				local n = math.min(3, math.max(1, math.floor(len / 130)))
				for q = 1, n do
					addGap(r, lo + len * (q - 0.5) / n, 18, 13, "hall", nil)
				end
			elseif level == 1 and i.style == "ext" and len >= 30 and (i.pair:find("deck") ~= nil) and not i.pair:find("solid") then
				cand[#cand + 1] = r
			elseif level == 0 and i.style == "ext" and len >= 30 and not i.pair:find("solid") and not i.pair:find("unit") then
				cand[#cand + 1] = r
			end
		end
		if level == 1 then
			-- the loading docks: the reference's wall has a tooth between the bays; every opening between two teeth is a bay and
			-- every third one stands open
			for _, d in m.docks do
				local zmin, zmax = math.huge, -math.huge
				for _, z in d.apexZ do
					zmin, zmax = math.min(zmin, z), math.max(zmax, z)
				end
				local bays = {}
				for _, r in runs do
					local i = r.info
					if r.x0 == r.x1 and i.style == "ext" and math.abs(r.x0 - d.wallX) < 12 and (i.pair == "hall|deck" or i.pair == "open|deck") then
						local lo, hi = runSpan(r)
						if hi - lo >= 8 and hi - lo <= 26 and (lo + hi) / 2 > zmin - 22 and (lo + hi) / 2 < zmax + 22 then
							bays[#bays + 1] = r
						end
					end
				end
				table.sort(bays, function(p, q)
					return p.z0 < q.z0
				end)
				for q, r in bays do
					local lo, hi = runSpan(r)
					addGap(r, (lo + hi) / 2, hi - lo, 14, "dock", { bay = q, dock = d.name, open = (q % 3 == 1) })
				end
			end
			for _, r in cand do
				local lo, hi = runSpan(r)
				local len = hi - lo
				local n = math.min(3, math.max(1, math.floor(len / 160)))
				for q = 1, n do
					addGap(r, lo + len * (q - 0.5) / n, 14, 12, "entry", nil)
				end
			end
		elseif level == 0 then
			table.sort(cand, function(a, b)
				local la, lb = runSpan(a), runSpan(b)
				local a1 = select(2, runSpan(a)) - la
				local b1 = select(2, runSpan(b)) - lb
				return a1 > b1
			end)
			for q = 1, math.min(12, #cand) do
				local r = cand[q]
				local lo, hi = runSpan(r)
				local len = hi - lo
				local n = 1
				if len >= 220 then
					n = 2
				end
				for k = 1, n do
					addGap(r, lo + len * (k - 0.5) / n, (len >= 60) and 20 or 14, 13, "gate", nil)
				end
			end
		end
		-- the dock ramps open the deck's parapet; stairs arrive through the balustrade
		if level == 1 then
			for _, ln in plan.outRamps do
				for _, r in runs do
					if r.info.style == "parapet" then
						if ln.ux ~= 0 and r.x0 == r.x1 and math.abs(r.x0 - ln.x1) < 8 and ln.z1 > r.z0 and ln.z1 < r.z1 then
							addGap(r, ln.z1, ln.w + 2, 4, "none", nil)
						elseif ln.uz ~= 0 and r.z0 == r.z1 and math.abs(r.z0 - ln.z1) < 8 and ln.x1 > r.x0 and ln.x1 < r.x1 then
							addGap(r, ln.x1, ln.w + 2, 4, "none", nil)
						end
					end
				end
			end
		end
		for _, ln in plan.links do
			if ln.type ~= "vehicle" and ln.hi == level then
				for _, r in runs do
					if r.info.style == "rail" then
						if ln.ux ~= 0 and r.x0 == r.x1 and math.abs(r.x0 - ln.x1) < 4.5 and ln.z1 > r.z0 and ln.z1 < r.z1 then
							addGap(r, ln.z1, ln.w + 0.5, 4, "none", nil)
						elseif ln.uz ~= 0 and r.z0 == r.z1 and math.abs(r.z0 - ln.z1) < 4.5 and ln.x1 > r.x0 and ln.x1 < r.x1 then
							addGap(r, ln.x1, ln.w + 0.5, 4, "none", nil)
						end
					end
				end
			end
		end
	end
end

-- ── slabs and roofs ──────────────────────────────────────────────────────────────────────────────────────
function P.slabs(plan)
	local g = plan.g
	local nx = g.nx
	local lab = plan.lab
	plan.slabs = {}
	plan.unitRects = {}
	for level = 0, 2 do
		local a = lab[level]
		local cls = G.array(g, 0)
		local ucls = G.array(g, 0)
		for i = 1, g.n do
			local l = a[i]
			local k = 0
			if l >= UNIT then
				k = 1
				ucls[i] = l
			elseif l == OPEN or l == SOLID or l == HALL then
				k = 1
			elseif l == TERR and level > 0 then
				k = 4
			end
			cls[i] = k
		end
		plan.slabs[level] = G.cover(g, cls)
		plan.unitRects[level] = G.cover(g, ucls)
	end
	-- the roof: 1 over the halls, 2 over everything else that is enclosed (the central core), 3 / 4 skylights in the hall / core
	-- roof, 5 a hole for a dome, 0 none
	local roof = G.array(g, 0)
	local l1, l2 = lab[1], lab[2]
	for i = 1, g.n do
		local a, b = l1[i], l2[i]
		if a == HALL and b == OUT then
			roof[i] = 1
		elseif b ~= OUT then
			roof[i] = 2
		elseif a ~= OUT and a ~= TERR and a ~= HALL then
			roof[i] = 2
		end
	end
	if plan.concourse then
		G.poly(g, roof, plan.concourse.pts, 4, set({ 2 }))
	end
	for _, h in plan.halls do
		-- long strips of glass across the hall roof, three cells wide, one every sixteen cells, clear of the walls
		local i0, i1 = G.col(g, h.x0) + 4, G.col(g, h.x1 - 0.01) - 4
		local j0, j1 = G.row(g, h.z0) + 4, G.row(g, h.z1 - 0.01) - 4
		local alongX = (h.x1 - h.x0) >= (h.z1 - h.z0)
		if alongX then
			for jz = j0, j1 - 2, 16 do
				for jj = jz, jz + 2 do
					for ix = i0, i1 do
						local k = (jj - 1) * nx + ix
						if roof[k] == 1 then
							roof[k] = 3
						end
					end
				end
			end
		else
			for jx = i0, i1 - 2, 16 do
				for jj = jx, jx + 2 do
					for iz = j0, j1 do
						local k = (iz - 1) * nx + jj
						if roof[k] == 1 then
							roof[k] = 3
						end
					end
				end
			end
		end
	end
	-- the dome's opening is the atrium shrunk by 4.6 studs all round, so that the glass drum (MallShell) stands on roof slab
	for _, a in plan.atria do
		local k = math.max(0.2, (a.ap - 4.6) / a.ap)
		local pts = {}
		for i = 1, #a.pts, 2 do
			pts[i] = a.cx + (a.pts[i] - a.cx) * k
			pts[i + 1] = a.cz + (a.pts[i + 1] - a.cz) * k
		end
		G.poly(g, roof, pts, 5, nil)
	end
	plan.roof = roof
	plan.roofRects = G.cover(g, roof)
end

function P.doors(plan)
	-- doors, arches and openings of the service rooms
	local function door(u, side, c, w, kind, d)
		u.doors = u.doors or {}
		u.doors[#u.doors + 1] = { side = side, c = c, w = w, kind = kind, door = d, h = (kind == "door") and 8.6 or ((kind == "arch") and 12 or 9) }
	end
	local r0 = plan.rooms0
	door(r0.tunnel, "W", (r0.tunnel.z0 + r0.tunnel.z1) / 2, 14, "open")
	door(r0.tunnel, "E", (r0.tunnel.z0 + r0.tunnel.z1) / 2, 14, "open")
	door(r0.shelter, "S", 412.5, 14, "arch")
	door(r0.vest, "S", 412.5, 5.2, "door", { id = "MM_SHELTER", label = "The shelter", key = "CARD_MALL_VAULT" })
	door(r0.unit14, "S", 34.4, 5.2, "door", { id = "MM_UNIT14", label = "Unit 14", key = "KEY_MM_UNIT14" })
	local b = plan.backs
	door(b[1], "S", (b[1].x0 + b[1].x1) / 2, 5.2, "door", { id = "MM_NESTA_STOCK_1", label = "Stock room" })
	door(b[1], "W", (b[1].z0 + b[1].z1) / 2, 5.2, "door", { id = "MM_NESTA_STOCK_2", label = "Stock room" })
	door(b[1], "E", -818, 5.2, "door", { id = "MM_NESTA_GOODS", label = "Goods in" })
	door(b[2], "S", (b[2].x0 + b[2].x1) / 2, 5.2, "door", { id = "MM_KASSA_BACK_1", label = "Back of house" })
	door(b[2], "W", (b[2].z0 + b[2].z1) / 2, 5.2, "door", { id = "MM_KASSA_BACK_2", label = "Back of house" })
	door(b[3], "N", (b[3].x0 + b[3].x1) / 2, 5.2, "door", { id = "MM_BOLT_STOCK_1", label = "Stock room" })
	door(b[3], "W", (b[3].z0 + b[3].z1) / 2, 5.2, "door", { id = "MM_BOLT_STOCK_2", label = "Stock room" })
	door(b[4], "E", (b[4].z0 + b[4].z1) / 2, 5.2, "door", { id = "MM_BOLT_OFFICES_1", label = "Offices" })
	door(b[4], "N", (b[4].x0 + b[4].x1) / 2, 5.2, "door", { id = "MM_BOLT_OFFICES_2", label = "Offices" })
	door(plan.security, "E", (plan.security.z0 + plan.security.z1) / 2, 5.2, "door", { id = "MM_SECURITY", label = "Security room", key = "KEY_MALL_SECURITY" })
	local w2 = plan.wash2
	door(w2.men, "S", (w2.men.x0 + w2.men.x1) / 2, 5.2, "door", { id = "MM_WASH2_MEN", label = "Men" })
	door(w2.women, "S", (w2.women.x0 + w2.women.x1) / 2, 5.2, "door", { id = "MM_WASH2_WOMEN", label = "Women" })
end

-- runs, openings and slabs from the current labels (run again after the labels changed)
function P.runs(plan, L)
	local g = plan.g
	for _, u in plan.units do
		if u.doors then
			for _, d in u.doors do
				d.placed = nil
			end
		end
	end
	for level = 0, 2 do
		pace()
		plan.runs[level] = G.walls(g, plan.lab[level], classifier(plan, level))
	end
	pace()
	P.gaps(plan, L)
	pace()
	P.slabs(plan)
end

-- ── reachability ─────────────────────────────────────────────────────────────────────────────────────────
-- the walkable components: neighbouring walkable cells are joined across every edge without a wall (or inside a gap of one); the
-- stairs, ramps and escalators join the levels, and what the gates, entries and docks open to is outside. Returns the
-- components that do not lead outside: { level, cells = {...}, unit = bool }.
function P.reach(plan)
	local g = plan.g
	local nx, nz = g.nx, g.nz
	local W1 = nx + 1
	local c = g.cell
	local lab = plan.lab
	local comps = {} -- level -> { id = array, n = count }
	local blockV, blockH = {}, {}
	for level = 0, 2 do
		pace()
		local bv, bh = {}, {}
		local function covered(r, pos)
			if r.gaps then
				for _, gp in r.gaps do
					if math.abs(pos - gp.c) <= gp.w / 2 + 1e-6 then
						return true
					end
				end
			end
			return false
		end
		for _, r in plan.runs[level].v do
			for iz = r.i0, r.i1 do
				if not covered(r, g.z0 + (iz - 0.5) * c) then
					bv[(iz - 1) * W1 + r.line] = true
				end
			end
		end
		for _, r in plan.runs[level].h do
			for ix = r.i0, r.i1 do
				if not covered(r, g.x0 + (ix - 0.5) * c) then
					bh[(r.line - 1) * nx + ix] = true
				end
			end
		end
		blockV[level], blockH[level] = bv, bh
	end
	local parent = {}
	local function find(a)
		parent[a] = parent[a] or a
		local r = a
		while parent[r] ~= r do
			r = parent[r]
		end
		while parent[a] ~= r do
			local nxt = parent[a]
			parent[a] = r
			a = nxt
		end
		return r
	end
	local function union(a, b)
		parent[find(a)] = find(b)
	end
	local sizes = {}
	for level = 0, 2 do
		local arr = lab[level]
		local id = G.array(g, 0)
		local bv, bh = blockV[level], blockH[level]
		local n = 0
		for start = 1, g.n do
			if id[start] == 0 and isWalk(arr[start]) then
				n += 1
				id[start] = n
				local q, qn, head = { start }, 1, 1
				while head <= qn do
					local idx = q[head]
					head += 1
					local iz = math.floor((idx - 1) / nx) + 1
					local ix = idx - (iz - 1) * nx
					if ix > 1 and id[idx - 1] == 0 and isWalk(arr[idx - 1]) and not bv[(iz - 1) * W1 + ix] then
						id[idx - 1] = n
						qn += 1
						q[qn] = idx - 1
					end
					if ix < nx and id[idx + 1] == 0 and isWalk(arr[idx + 1]) and not bv[(iz - 1) * W1 + ix + 1] then
						id[idx + 1] = n
						qn += 1
						q[qn] = idx + 1
					end
					if iz > 1 and id[idx - nx] == 0 and isWalk(arr[idx - nx]) and not bh[(iz - 1) * nx + ix] then
						id[idx - nx] = n
						qn += 1
						q[qn] = idx - nx
					end
					if iz < nz and id[idx + nx] == 0 and isWalk(arr[idx + nx]) and not bh[iz * nx + ix] then
						id[idx + nx] = n
						qn += 1
						q[qn] = idx + nx
					end
				end
			end
		end
		comps[level] = { id = id, n = n }
	end
	local function node(level, x, z)
		local ix, iz = G.col(g, x), G.row(g, z)
		if ix < 1 or iz < 1 or ix > nx or iz > nz then
			return nil
		end
		local v = comps[level].id[(iz - 1) * nx + ix]
		if v == 0 then
			return nil
		end
		return level * 1000000 + v
	end
	for _, ln in plan.links do
		if ln.type ~= "vehicle" then
			local lo = node(ln.lo, ln.x0 - ln.ux * 4, ln.z0 - ln.uz * 4)
			local hi = node(ln.hi, ln.x1 + ln.ux * 4, ln.z1 + ln.uz * 4)
			if lo and hi then
				union(lo, hi)
			end
		end
	end
	local OUTSIDE = -1
	for level = 0, 2 do
		local arr, id = lab[level], comps[level].id
		if level <= 1 then
			for k = 1, g.n do
				if arr[k] == TERR and id[k] > 0 then
					union(level * 1000000 + id[k], OUTSIDE)
				end
			end
		end
		for _, orient in { "v", "h" } do
			for _, r in plan.runs[level][orient] do
				if r.info.style == "ext" and r.gaps then
					for _, gp in r.gaps do
						if gp.kind == "gate" or gp.kind == "entry" or gp.kind == "dock" or gp.kind == "open" then
							local x, z = r.x0, r.z0
							if orient == "v" then
								z = gp.c
							else
								x = gp.c
							end
							for _, d in { { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 } } do
								local nd = node(level, x + d[1], z + d[2])
								if nd then
									union(nd, OUTSIDE)
								end
							end
						end
					end
				end
			end
		end
	end
	local root = find(OUTSIDE)
	local bad = {}
	for level = 0, 2 do
		local id, arr = comps[level].id, lab[level]
		local byId = {}
		for k = 1, g.n do
			local v = id[k]
			if v > 0 then
				local b = byId[v]
				if not b then
					if find(level * 1000000 + v) ~= root then
						b = { level = level, cells = {}, unit = false }
						byId[v] = b
						bad[#bad + 1] = b
					else
						byId[v] = false
					end
				end
				if b then
					b.cells[#b.cells + 1] = k
					if arr[k] >= UNIT then
						b.unit = true
					end
				end
			end
		end
	end
	return bad, comps, find, root
end

-- every walkable component that leads nowhere is dealt with: a speck or an island inside a hall is merged into its surroundings,
-- anything else is joined to the main floor by a corridor cut through the solid mass (at L2 also through the open air); the walls
-- are redone after a change
function P.fixReach(plan, L)
	local g = plan.g
	local nx, nz = g.nx, g.nz
	for pass = 1, 5 do
		pace()
		local bad, comps, find, root = P.reach(plan)
		if #bad == 0 then
			return
		end
		local changed = false
		for _, b in bad do
			local arr = plan.lab[b.level]
			local inb = {}
			for _, k in b.cells do
				inb[k] = true
			end
			local hist = {}
			for _, k in b.cells do
				local iz = math.floor((k - 1) / nx) + 1
				local ix = k - (iz - 1) * nx
				local nbr = { ix > 1 and k - 1 or 0, ix < nx and k + 1 or 0, iz > 1 and k - nx or 0, iz < nz and k + nx or 0 }
				for _, nk in nbr do
					if nk > 0 and not inb[nk] then
						hist[arr[nk]] = (hist[arr[nk]] or 0) + 1
					end
				end
			end
			local dom, domN = SOLID, 0
			for l, n in hist do
				if n > domN then
					dom, domN = l, n
				end
			end
			if not b.unit and #b.cells < 20 then
				local nl = SOLID
				if dom == HALL or dom == OPEN then
					nl = dom
				end
				for _, k in b.cells do
					arr[k] = nl
				end
				changed = true
			else
				local parent = {}
				local q, qn, head = {}, 0, 1
				for _, k in b.cells do
					qn += 1
					q[qn] = k
					parent[k] = -1
				end
				local goal = nil
				local ids = comps[b.level].id
				while head <= qn and not goal do
					local idx = q[head]
					head += 1
					local iz = math.floor((idx - 1) / nx) + 1
					local ix = idx - (iz - 1) * nx
					local nbr = { ix > 1 and idx - 1 or 0, ix < nx and idx + 1 or 0, iz > 1 and idx - nx or 0, iz < nz and idx + nx or 0 }
					for _, nk in nbr do
						if nk > 0 and not parent[nk] and not goal then
							local v = arr[nk]
							if v == SOLID or (v == OUT and b.level == 2) then
								parent[nk] = idx
								qn += 1
								q[qn] = nk
							elseif v == OPEN and ids[nk] > 0 and find(b.level * 1000000 + ids[nk]) == root then
								parent[nk] = idx
								goal = nk
							end
						end
					end
				end
				if goal then
					local cur = goal
					local carved = 0
					while cur and cur > 0 do
						local iz = math.floor((cur - 1) / nx) + 1
						local ix = cur - (iz - 1) * nx
						if parent[cur] ~= -1 then
							for dz = -1, 1 do
								for dx = -1, 1 do
									local jx, jz = ix + dx, iz + dz
									if jx >= 1 and jx <= nx and jz >= 1 and jz <= nz then
										local kk = (jz - 1) * nx + jx
										if arr[kk] == SOLID or (arr[kk] == OUT and b.level == 2) then
											arr[kk] = OPEN
											carved += 1
										end
									end
								end
							end
						end
						cur = parent[cur]
					end
					if carved > 0 then
						plan.stats.carved = (plan.stats.carved or 0) + 1
						changed = true
					elseif pass >= 3 then
						-- the component touches a reachable floor across a wall that has no room for a door: open one cell wide
						plan.warn[#plan.warn + 1] = string.format("L%d: a walkable area of %d cells touches the floor through a wall", b.level, #b.cells)
					end
				elseif not b.unit and #b.cells < 60 then
					for _, k in b.cells do
						arr[k] = SOLID
					end
					changed = true
				elseif pass == 5 then
					plan.warn[#plan.warn + 1] = string.format("L%d: a walkable area of %d cells is cut off", b.level, #b.cells)
				end
			end
		end
		if not changed then
			return
		end
		P.runs(plan, L)
	end
end

function P.edges(plan, L)
	P.doors(plan)
	P.runs(plan, L)
	pace()
	P.fixReach(plan, L)
end

return P
