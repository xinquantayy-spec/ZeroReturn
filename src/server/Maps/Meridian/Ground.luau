--!nonstrict
-- Meridian ground (foundation, part 1 of 2). Map-local studs throughout (see Layout.luau): x east, z south.
-- 1. A height grid of 4-stud columns: the reference's relief, graded roads and rails, rock-field mounds, flat pads under every
--    yard and building, the mall's level pad, ponds and the east canal dug as ditches (no terrain water), and berms outside the
--    outer limit that close the view. TerrainKit writes it chunk by chunk (time-sliced); B.ground(x, z) reads the same grid,
--    so placing things never needs a raycast.
-- 2. Terrain materials by area (grass and ground, bare earth in the minefield band, rock on the rock fields, gravel along
--    rails and tracks, concrete under yards and the mall, asphalt under roads and car parks, mud in the ponds).
-- 3. Parts: asphalt roads with bend discs and highway dashes, the four dock ramps, surface car parks with worn bay markings,
--    rails, chain-link fences, power pylons and wires, hazard posts and tape along the inner edges of the minefield and sniper
--    bands, the kart track kerbs, rock fields, the invisible boundary walls (on the OUTER limit: players may enter the bands)
--    and, while the mall shell does not exist (B.hasMall), a thin outline of the mall's walls.
-- Sets on B: ground(x, z), inside(x, z) (the playable polygon), insideLimit(x, z) (inside the outer limit, bands included),
--   band(x, z) (0 playable, 1 minefield, 2 sniper), classAt(x, z) (terrain class: 0 plain, 1 rock field, 2 rail bed, 3 concrete,
--   4 gravel, 5 asphalt, 8 outside the limit, 9 pond or canal bed, 10 bank), wet(x, z), slope(x, z), inMall(x, z) (inside the
--   mall's ground footprint) and T (the TerrainKit result); counts go into B.count. Each section runs under pcall: a failure
--   is logged and the sections after it still build.
-- The terrain under the mall footprint lies at y -0.4 so that the shell's L0 floor slabs (top y 0) never fight it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Wear = require(ReplicatedStorage:WaitForChild("ZR"):WaitForChild("Wear"))

local RoadBeds = require(script.Parent.Parent.RoadBeds)
local R = 4 -- column size in studs (one terrain voxel)
local EX, EZ = 1700, 1440 -- terrain half extents: the outer limit plus 90 to 130 studs of berm
local NX, NZ = (2 * EX) / R, (2 * EZ) / R
local Y0, NY = -72, 60 -- voxel layers of 4 studs: y -72 .. 168
local MALL_Y = -2.5 -- the terrain under the mall sits below the L0 floor slabs (top y 0, 1.6 thick): at -0.4 its surface
-- reached y 0 in places and fought the slabs (a camouflage pattern on the car park floor)
local MAXROCK, MAXMARK = 240, 260

return function(B)
	local kit, H, map, L, O, rng = B.kit, B.H, B.map, B.L, B.O, B.rng
	local C, M, hex = kit.C, kit.M, kit.hex
	local V = H.V
	local count = B.count or {}
	B.count = count
	for _, key in { "terrain", "road", "dash", "mark", "rail", "fence", "pylon", "wire", "boundary", "hazard", "rock", "kart", "ramp", "outline" } do
		count[key] = count[key] or 0
	end
	local TK = require(script.Parent.Parent.TerrainKit)

	local function step(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			warn("[ZR] Meridian ground: " .. name .. " failed: " .. tostring(err))
		end
		return ok
	end
	local last = os.clock()
	local function pace()
		if os.clock() - last > 0.03 then
			task.wait()
			last = os.clock()
		end
	end
	local function smooth(t)
		t = math.clamp(t, 0, 1)
		return t * t * (3 - 2 * t)
	end
	local function xAt(i)
		return -EX + (i - 0.5) * R
	end
	local function zAt(k)
		return -EZ + (k - 0.5) * R
	end
	local function colOf(x)
		return math.clamp(math.floor((x + EX) / R) + 1, 1, NX)
	end
	local function rowOf(z)
		return math.clamp(math.floor((z + EZ) / R) + 1, 1, NZ)
	end

	-- ── plane geometry ───────────────────────────────────────────────────────────────────────────────────
	-- distance from (px, pz) to the segment a-b, and the position 0..1 of the nearest point on it
	local function segDist(px, pz, ax, az, bx, bz)
		local dx, dz = bx - ax, bz - az
		local l2 = dx * dx + dz * dz
		local t = 0
		if l2 > 1e-9 then
			t = math.clamp(((px - ax) * dx + (pz - az) * dz) / l2, 0, 1)
		end
		local ex, ez = px - (ax + dx * t), pz - (az + dz * t)
		return math.sqrt(ex * ex + ez * ez), t
	end
	-- is the point inside the closed polygon (flat x, z list)
	local function pointIn(pts, x, z)
		local inside = false
		local n = #pts / 2
		local j = n
		for e = 1, n do
			local ax, az, bx, bz = pts[2 * e - 1], pts[2 * e], pts[2 * j - 1], pts[2 * j]
			if (az > z) ~= (bz > z) and x < (bx - ax) * (z - az) / (bz - az) + ax then
				inside = not inside
			end
			j = e
		end
		return inside
	end
	-- distance to the polygon's outline, negative inside
	local function polyDist(pts, x, z)
		local n = #pts / 2
		local best = math.huge
		for e = 1, n do
			local f = (e % n) + 1
			local d = segDist(x, z, pts[2 * e - 1], pts[2 * e], pts[2 * f - 1], pts[2 * f])
			if d < best then
				best = d
			end
		end
		if pointIn(pts, x, z) then
			best = -best
		end
		return best
	end
	-- the z values where the vertical line at x crosses the polygon, sorted (inside between 1-2, 3-4, ...)
	local function crossings(pts, x)
		local zs = {}
		local n = #pts / 2
		for e = 1, n do
			local f = (e % n) + 1
			local ax, az, bx, bz = pts[2 * e - 1], pts[2 * e], pts[2 * f - 1], pts[2 * f]
			if (ax <= x and bx > x) or (bx <= x and ax > x) then
				table.insert(zs, az + (x - ax) / (bx - ax) * (bz - az))
			end
		end
		table.sort(zs)
		return zs
	end
	-- calls fn(i, k) for every column whose centre is inside the polygon
	local function fillPoly(pts, fn)
		local minx, maxx = math.huge, -math.huge
		for q = 1, #pts, 2 do
			minx, maxx = math.min(minx, pts[q]), math.max(maxx, pts[q])
		end
		for i = colOf(minx), colOf(maxx) do
			local zs = crossings(pts, xAt(i))
			for q = 1, #zs - 1, 2 do
				local ka = math.max(1, math.ceil((zs[q] + EZ) / R + 0.5))
				local kb = math.min(NZ, math.floor((zs[q + 1] + EZ) / R + 0.5))
				for k = ka, kb do
					fn(i, k)
				end
			end
			if i % 12 == 0 then
				pace()
			end
		end
	end
	-- calls fn(i, k, d, t, s) for every column within `reach` of the polyline (d = distance, t = position on segment s)
	local function eachNear(pts, reach, fn)
		for s = 1, #pts / 2 - 1 do
			local ax, az, bx, bz = pts[2 * s - 1], pts[2 * s], pts[2 * s + 1], pts[2 * s + 2]
			local i0, i1 = colOf(math.min(ax, bx) - reach), colOf(math.max(ax, bx) + reach)
			local k0, k1 = rowOf(math.min(az, bz) - reach), rowOf(math.max(az, bz) + reach)
			for i = i0, i1 do
				local x = xAt(i)
				for k = k0, k1 do
					local d, t = segDist(x, zAt(k), ax, az, bx, bz)
					if d < reach then
						fn(i, k, d, t, s)
					end
				end
			end
			if s % 3 == 0 then
				pace()
			end
		end
	end

	-- ── the grids ────────────────────────────────────────────────────────────────────────────────────────
	-- HG height of each column's surface; CL class (0 plain, 1 rock field, 2 rail bed, 3 concrete, 4 gravel, 5 asphalt, 8 outside
	-- the limit, 9 pond or canal bed, 10 bank); ZN zone (0 outside the outer limit, 1 playable, 2 minefield band, 3 sniper band)
	local HG, CL, ZN = table.create(NX), table.create(NX), table.create(NX)
	for i = 1, NX do
		CL[i], ZN[i] = table.create(NZ, 0), table.create(NZ, 0)
	end

	-- 1. relief: the reference's samples as Gaussian knots, evaluated on a 20-stud grid and interpolated
	step("relief", function()
		local CR = 20
		local cnx, cnz = (2 * EX) / CR + 1, (2 * EZ) / CR + 1
		local knots = {}
		for n = 1, #L.relief, 4 do
			table.insert(knots, { L.relief[n], L.relief[n + 1], L.relief[n + 2], L.relief[n + 3] })
		end
		local RG = table.create(cnx)
		for a = 1, cnx do
			local col = table.create(cnz, 0)
			local x = -EX + (a - 1) * CR
			for b = 1, cnz do
				local z = -EZ + (b - 1) * CR
				local sw, sy = 0.05, 0
				for _, kn in knots do
					local dx, dz = x - kn[1], z - kn[2]
					local d2 = dx * dx + dz * dz
					local sg = kn[4]
					if d2 < 9 * sg * sg then
						local wgt = math.exp(-d2 / (2 * sg * sg))
						sw += wgt
						sy += wgt * kn[3]
					end
				end
				col[b] = sy / sw
			end
			RG[a] = col
			pace()
		end
		for i = 1, NX do
			local fx = (xAt(i) + EX) / CR
			local a = math.clamp(math.floor(fx), 0, cnx - 2)
			local tx = fx - a
			local c0, c1 = RG[a + 1], RG[a + 2]
			local hc = table.create(NZ, 0)
			for k = 1, NZ do
				local fz = (zAt(k) + EZ) / CR
				local b = math.clamp(math.floor(fz), 0, cnz - 2)
				local tz = fz - b
				local v0 = c0[b + 1] + (c1[b + 1] - c0[b + 1]) * tx
				local v1 = c0[b + 2] + (c1[b + 2] - c0[b + 2]) * tx
				hc[k] = v0 + (v1 - v0) * tz
			end
			HG[i] = hc
			if i % 6 == 0 then
				pace()
			end
		end
	end)
	for i = 1, NX do
		if not HG[i] then
			HG[i] = table.create(NZ, 0) -- a flat world if the relief failed
		end
	end

	-- height of the surface at a point (bilinear on the column centres, what the voxels draw)
	local function groundAt(x, z)
		local fx, fz = (x + EX) / R + 0.5, (z + EZ) / R + 0.5
		local i0 = math.clamp(math.floor(fx), 1, NX - 1)
		local k0 = math.clamp(math.floor(fz), 1, NZ - 1)
		local tx, tz = math.clamp(fx - i0, 0, 1), math.clamp(fz - k0, 0, 1)
		local c0, c1 = HG[i0], HG[i0 + 1]
		local a = c0[k0] + (c1[k0] - c0[k0]) * tx
		local b = c0[k0 + 1] + (c1[k0 + 1] - c0[k0 + 1]) * tx
		return a + (b - a) * tz
	end
	-- inside the mall's footprint the floor is the L0 slabs (top y 0); the terrain lies MALL_Y under them
	B.ground = function(x, z)
		if B.inMall and B.inMall(x, z) then
			return 0
		end
		return groundAt(x, z)
	end
	local function insideAt(x, z)
		return ZN[colOf(x)][rowOf(z)] == 1
	end
	B.inside = insideAt
	local function limitAt(x, z)
		return ZN[colOf(x)][rowOf(z)] > 0
	end
	B.insideLimit = limitAt
	B.band = function(x, z)
		return math.max(0, ZN[colOf(x)][rowOf(z)] - 1)
	end
	B.classAt = function(x, z)
		return CL[colOf(x)][rowOf(z)]
	end
	B.wet = function(x, z)
		return CL[colOf(x)][rowOf(z)] >= 9
	end
	local function slopeAt(x, z)
		local dx = (groundAt(x + R, z) - groundAt(x - R, z)) / (2 * R)
		local dz = (groundAt(x, z + R) - groundAt(x, z - R)) / (2 * R)
		return math.sqrt(dx * dx + dz * dz)
	end
	B.slope = slopeAt
	local MO = L.mall.outline
	B.inMall = function(x, z)
		return pointIn(MO, x, z)
	end

	-- 2. the zones: inside the outer limit, and the two bands; the distance to the limit from outside (for the berms)
	local DBK = {} -- column key (i * 1024 + k) -> distance to the outer limit, for the columns outside it within reach
	local LIM = L.limit
	step("zones", function()
		fillPoly(LIM, function(i, k)
			ZN[i][k] = 1
		end)
		fillPoly(L.mine.poly, function(i, k)
			ZN[i][k] = 2
		end)
		fillPoly(L.snipe.poly, function(i, k)
			ZN[i][k] = 3
		end)
		local REACH = 84
		local nb = #LIM / 2
		for e = 1, nb do
			local f = (e % nb) + 1
			local ax, az, bx, bz = LIM[2 * e - 1], LIM[2 * e], LIM[2 * f - 1], LIM[2 * f]
			for i = colOf(math.min(ax, bx) - REACH), colOf(math.max(ax, bx) + REACH) do
				local x = xAt(i)
				local zcol = ZN[i]
				for k = rowOf(math.min(az, bz) - REACH), rowOf(math.max(az, bz) + REACH) do
					if zcol[k] == 0 then
						local d = segDist(x, zAt(k), ax, az, bx, bz)
						local key = i * 1024 + k
						local cur = DBK[key]
						if cur == nil or d < cur then
							DBK[key] = d
						end
					end
				end
			end
			if e % 3 == 0 then
				pace()
			end
		end
	end)

	-- 3. roads and rails are graded: across a road the ground is level (so a road board never sits on a cross slope),
	-- blending back into the relief beside it. Along a road the ground follows the relief, sampled every 4 studs and
	-- averaged over about 30 (Maps/RoadBeds.luau), the plain held flat; rails keep straight grades between their
	-- vertices. Until 2026-11-02 roads also ran straight between their vertices (road audit, Border Yard).
	local GRD = {} -- key (i * 1024 + k) -> grading weight
	step("grade", function()
		local gw, gh = {}, {}
		local function line(pts, halfW, blend, follow)
			local n = #pts / 2
			local hs = table.create(n, 0)
			for q = 1, n do
				local h = groundAt(pts[2 * q - 1], pts[2 * q])
				if math.abs(h) < 3 then
					h = 0 -- the plain stays exactly flat
				end
				hs[q] = h
			end
			local prof = follow
				and RoadBeds.profile(pts, function(x, z)
					local h = groundAt(x, z)
					return math.abs(h) < 3 and 0 or h
				end)
			eachNear(pts, halfW + blend, function(i, k, d, t, s)
				local wgt = 1 - smooth((d - halfW) / blend)
				if wgt > 0.004 then
					local key = i * 1024 + k
					local h = prof and RoadBeds.at(prof, s, t) or (hs[s] + (hs[s + 1] - hs[s]) * t)
					gw[key] = (gw[key] or 0) + wgt
					gh[key] = (gh[key] or 0) + wgt * h
					if wgt > (GRD[key] or 0) then
						GRD[key] = wgt
					end
				end
			end)
			pace()
		end
		for _, rd in L.roads do
			line(rd[4], rd[3] / 2 + 1, 12, true)
		end
		for _, rl in L.rails do
			if rl[2] == 0 then
				line(rl[3], 6.5, 10)
			end
		end
		for key, wsum in gw do
			local i = math.floor(key / 1024)
			local k = key - i * 1024
			local col = HG[i]
			col[k] = col[k] + (gh[key] / wsum - col[k]) * GRD[key]
		end
	end)

	-- 4. rock fields: low mounds (the reference gives the outlines and areas only; the height is ours, about 5.5 cm per metre
	-- of the square root of the area, a gap logged in docs/maps/MERIDIAN_MALL.md)
	step("rock mounds", function()
		for _, f in L.rockFields do
			local pts = f[3]
			local peak = math.min(18, 0.055 * math.sqrt(f[2]) * L.S)
			fillPoly(pts, function(i, k)
				local x, z = xAt(i), zAt(k)
				local din = -polyDist(pts, x, z)
				local nz = 0.85 + 0.5 * (math.noise(x / 37 + 1.3, z / 37 + 2.9, 3.1) + 0.3)
				HG[i][k] += peak * smooth(din / 36) * math.max(0.5, nz)
			end)
		end
	end)

	-- 5. flat pads under every yard and building (the plain stays at y 0 under them; elsewhere the pad takes the ground height
	-- at its centre), blending out over 16 to 22 studs; then the mall's ground footprint and the west pad beside it
	step("pads", function()
		local list = {}
		for _, y in L.yards do
			table.insert(list, { y[4], y[5], y[6], y[7], y[8], 22 })
		end
		table.sort(list, function(a, b)
			return a[3] * a[4] > b[3] * b[4]
		end)
		for _, b in L.blds do
			if b[4] ~= "mall" then
				table.insert(list, { b[5], b[6], b[7], b[8], b[9], 16 })
			end
		end
		for n, p in list do
			local cxp, czp, w, d, rot, blend = p[1], p[2], p[3], p[4], p[5], p[6]
			local y = groundAt(cxp, czp)
			if math.abs(y) < 3.2 then
				y = 0
			end
			local a = math.rad(rot)
			local ca, sa = math.cos(a), math.sin(a)
			local hw, hd = w / 2, d / 2
			local reach = math.sqrt(hw * hw + hd * hd) + blend
			for i = colOf(cxp - reach), colOf(cxp + reach) do
				local x = xAt(i)
				local col = HG[i]
				for k = rowOf(czp - reach), rowOf(czp + reach) do
					local dx, dz = x - cxp, zAt(k) - czp
					local u = math.max(math.abs(dx * ca + dz * sa) - hw, 0)
					local v = math.max(math.abs(dz * ca - dx * sa) - hd, 0)
					local dist = math.sqrt(u * u + v * v)
					if dist < blend then
						col[k] = col[k] + (y - col[k]) * (1 - smooth(dist / blend))
					end
				end
			end
			if n % 4 == 0 then
				pace()
			end
		end
		for _, pd in L.mall.pads do
			if pd.id == "west_pad" then
				fillPoly(pd.pts, function(i, k)
					HG[i][k] = 0
				end)
			end
		end
		fillPoly(MO, function(i, k)
			HG[i][k] = MALL_Y
		end)
	end)

	-- 6. berms and cliffs outside the outer limit (the view closes 60 to 120 studs beyond the invisible wall)
	step("berm", function()
		local BW, BH = 62, 100
		for i = 1, NX do
			local x = xAt(i)
			local hc, cc, zc = HG[i], CL[i], ZN[i]
			for k = 1, NZ do
				if zc[k] == 0 then
					local z = zAt(k)
					local n1 = math.noise(x / 85 + 11.3, z / 85 + 4.7, 1.9)
					local dist = DBK[i * 1024 + k] or 90
					local u = math.clamp(dist / (BW + 14 * n1), 0, 1)
					local rise = (BH + 40 * n1) * u * u * (3 - 2 * u)
					rise += 5 * math.noise(x / 23 + 0.3, z / 23 + 0.7, 7.3) * smooth((dist - 40) / 40)
					hc[k] = math.min(158, hc[k] + math.max(0, rise))
					cc[k] = 8
				end
			end
			if i % 8 == 0 then
				pace()
			end
		end
	end)

	-- 7. ponds and the east canal: ditches, no terrain water. The bed lies up to `depth` studs under the ground at the traced
	-- outline's own level, with banks sloping in from the outline.
	step("pits", function()
		for _, w in L.water do
			local depth, pts = w[3], w[9]
			local bank = depth * 1.8
			if w[2] == "canal" then
				bank = depth * 2.2
			end
			fillPoly(pts, function(i, k)
				if ZN[i][k] > 0 then
					local din = -polyDist(pts, xAt(i), zAt(k))
					HG[i][k] -= depth * smooth(din / bank)
					if din > 0.3 * bank then
						CL[i][k] = 9
					else
						CL[i][k] = 10
					end
				end
			end)
		end
	end)

	-- 7b. road beds (Maps/RoadBeds.luau): across every road the ground lies flat at the road's smoothed height, after the
	-- rock mounds, pads and pits had tilted some beds again (road audit, 2026-11-02). Building footprints (+1), the mall's
	-- footprint, the pits and the ground outside the limit are left alone.
	step("road beds", function()
		local keep = {}
		for _, b in L.blds do
			if b[4] ~= "mall" then
				local cxp, czp, w, d, rot = b[5], b[6], b[7], b[8], b[9]
				if type(cxp) == "number" and type(czp) == "number" and type(w) == "number" and type(d) == "number" then
					local a = math.rad(tonumber(rot) or 0)
					local ca, sa = math.cos(a), math.sin(a)
					local hw, hd = w / 2 + 1, d / 2 + 1
					local reach = math.sqrt(hw * hw + hd * hd)
					for i = colOf(cxp - reach), colOf(cxp + reach) do
						local x = xAt(i)
						for k = rowOf(czp - reach), rowOf(czp + reach) do
							local dx, dz = x - cxp, zAt(k) - czp
							if math.abs(dx * ca + dz * sa) <= hw and math.abs(dz * ca - dx * sa) <= hd then
								keep[i * 1024 + k] = true
							end
						end
					end
				end
			end
		end
		fillPoly(MO, function(i, k)
			keep[i * 1024 + k] = true
		end)
		local rails = {}
		for _, rl in L.rails do
			if rl[2] == 0 then
				table.insert(rails, rl[3])
			end
		end
		count.roadBed = RoadBeds.bed({
			roads = L.roads, rails = rails, HG = HG, groundAt = groundAt, eachNear = eachNear,
			colOf = colOf, rowOf = rowOf, xAt = xAt, zAt = zAt, smooth = smooth, pace = pace, keep = keep,
			open = function(i, k)
				return ZN[i][k] > 0 and CL[i][k] < 9
			end,
			wet = function(x, z)
				local i, k = colOf(x), rowOf(z)
				return ZN[i][k] == 0 or CL[i][k] >= 9 -- the berm outside the limit, ponds and the canal
			end,
		})
	end)

	-- 8. terrain classes by area (the material callback reads them): the highest code wins, except that columns outside the
	-- limit (8) and the pits (9, 10) keep theirs
	step("classes", function()
		local function paint(i, k, code)
			local col = CL[i]
			if code > col[k] then
				col[k] = code
			end
		end
		for _, f in L.rockFields do
			fillPoly(f[3], function(i, k)
				paint(i, k, 1)
			end)
		end
		for _, rl in L.rails do
			if rl[2] == 0 then
				eachNear(rl[3], 5.5, function(i, k)
					paint(i, k, 2)
				end)
			end
		end
		fillPoly(MO, function(i, k)
			paint(i, k, 3)
		end)
		-- under every other building: concrete, three studs past the walls, so terrain grass never grows through a ground
		-- floor (a 4-stud column straddling a wall line is concrete too), then bare earth out to 7 studs where the ground
		-- would be grass: grass decoration reaches a few studs past its voxel (as on Border Yard, KNOWN_ISSUES 72)
		local function eachBuilding(margin, fn)
			for _, b in L.blds do
				if b[4] ~= "mall" then
					local cxp, czp, w, d, rot = b[5], b[6], b[7], b[8], b[9]
					if type(cxp) == "number" and type(czp) == "number" and type(w) == "number" and type(d) == "number" then
						local a = math.rad(tonumber(rot) or 0)
						local ca, sa = math.cos(a), math.sin(a)
						local hw, hd = w / 2 + margin, d / 2 + margin
						local reach = math.sqrt(hw * hw + hd * hd)
						for i = colOf(cxp - reach), colOf(cxp + reach) do
							local x = xAt(i)
							for k = rowOf(czp - reach), rowOf(czp + reach) do
								local dx, dz = x - cxp, zAt(k) - czp
								if math.abs(dx * ca + dz * sa) <= hw and math.abs(dz * ca - dx * sa) <= hd then
									fn(i, k)
								end
							end
						end
					end
				end
			end
		end
		eachBuilding(3, function(i, k)
			paint(i, k, 3)
		end)
		eachBuilding(7, function(i, k)
			local col = CL[i]
			if col and col[k] ~= nil and col[k] < 2 then
				col[k] = 8
			end
		end)
		for _, pd in L.mall.pads do
			if pd.id == "west_pad" then
				fillPoly(pd.pts, function(i, k)
					paint(i, k, 3)
				end)
			end
		end
		for _, y in L.yards do
			local code = 3
			if y[3] == "A" then
				code = 5
			end
			fillPoly(y[10], function(i, k)
				paint(i, k, code)
			end)
		end
		for _, rd in L.roads do
			local code = 5
			if rd[2] == "G" then
				code = 4
			end
			eachNear(rd[4], rd[3] / 2 + 1, function(i, k)
				paint(i, k, code)
			end)
			pace()
		end
	end)

	-- ── the terrain ──────────────────────────────────────────────────────────────────────────────────────
	local PAL = Enum.Material
	local function matAt(x, z, h, slope)
		local i, k = colOf(x), rowOf(z)
		local c = CL[i][k]
		if c == 9 then
			return PAL.Mud
		elseif c == 10 then
			return PAL.Sand
		elseif c == 8 then
			if slope > 0.8 then
				return PAL.Rock
			elseif slope > 0.35 then
				return PAL.Slate
			end
			return PAL.Ground
		elseif c == 5 then
			return PAL.Asphalt
		elseif c == 4 or c == 2 then
			return PAL.Basalt -- gravel and ballast (Pebble is not a terrain material)
		elseif c == 3 then
			return PAL.Concrete
		elseif slope > 1.0 then
			return PAL.Rock
		elseif slope > 0.62 then
			return PAL.Slate
		elseif c == 1 then
			local n = math.noise(x / 17 + 3.1, z / 17 + 7.7, 0.5)
			if n > 0.22 then
				return PAL.Rock
			elseif n > -0.1 then
				return PAL.Slate
			end
			return PAL.Ground
		elseif h < -10 then
			return PAL.Mud -- the north-west lowland is a swamp
		elseif h < -5 then
			if math.noise(x / 29 + 2.2, z / 29 + 6.1, 4.4) > -0.05 then
				return PAL.Mud
			end
			return PAL.LeafyGrass
		elseif ZN[i][k] == 2 then
			-- the minefield band: bare, churned earth
			local n = math.noise(x / 31 + 0.7, z / 31 + 9.3, 2.6)
			if n > 0.14 then
				return PAL.Mud
			elseif n > -0.22 then
				return PAL.Ground
			end
			return PAL.Grass
		end
		-- open ground is grass, worn to earth here and there
		if math.noise(x / 46, z / 46, 0.37) > 0.34 then
			return PAL.Ground
		end
		return PAL.Grass
	end

	local T = nil
	step("terrain", function()
		T = TK.build({
			O = O, extX = EX, extZ = EZ, y0 = Y0, ny = NY,
			hg = HG, material = matAt,
			colors = {
				[PAL.Asphalt] = "3B3B38", [PAL.Concrete] = "75726B", [PAL.Ground] = "6B6350", [PAL.Grass] = "5D6A3D",
				[PAL.Mud] = "5A5243", [PAL.Sand] = "7A6E56", [PAL.LeafyGrass] = "4C5A33", [PAL.Basalt] = "77736A",
				[PAL.Rock] = "6A675F", [PAL.Slate] = "55595A",
			},
		})
		T.waitReady(0, 0)
	end)
	B.T = T
	count.terrain = NX * NZ
	if not T then
		-- the terrain failed: a flat slab keeps the map walkable so the rest can still be tested
		local slab = kit.box(map, 3400, 6, 2880, O.X, -3, O.Z, hex("5D6A3D"), M.Grass)
		slab.Name = "FallbackGround"
		warn("[ZR] Meridian ground: terrain failed, a flat slab stands in")
	end

	-- ── helpers for the parts ────────────────────────────────────────────────────────────────────────────
	local function onLand(x, z)
		local i, k = colOf(x), rowOf(z)
		return ZN[i][k] > 0 and CL[i][k] < 9
	end
	-- the stretches of a straight run (a, b) where test(x, z) holds, as { t0, t1 } pairs of run positions
	local function landRuns(ax, az, bx, bz, test)
		local len = math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
		local n = math.max(1, math.ceil(len / 2))
		local runs, start = {}, nil
		for q = 0, n do
			local t = q / n
			local ok = test(ax + (bx - ax) * t, az + (bz - az) * t)
			if ok and not start then
				start = t
			elseif not ok and start then
				table.insert(runs, { start, (q - 1) / n })
				start = nil
			end
		end
		if start then
			table.insert(runs, { start, 1 })
		end
		return runs
	end
	-- splits a straight run into pieces that follow the ground and calls emit(x0, z0, x1, z1) for each
	local function pieces(x0, z0, x1, z1, maxLen, minLen, tol, emit)
		local len = math.sqrt((x1 - x0) * (x1 - x0) + (z1 - z0) * (z1 - z0))
		local split = len > maxLen
		if not split and len > minLen then
			local h0, h1 = groundAt(x0, z0), groundAt(x1, z1)
			for q = 1, 3 do
				local t = q / 4
				local dv = math.abs(groundAt(x0 + (x1 - x0) * t, z0 + (z1 - z0) * t) - (h0 + (h1 - h0) * t))
				if dv > tol then
					split = true
				end
			end
		end
		if split then
			local mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
			pieces(x0, z0, mx, mz, maxLen, minLen, tol, emit)
			pieces(mx, mz, x1, z1, maxLen, minLen, tol, emit)
		else
			emit(x0, z0, x1, z1)
		end
	end
	-- world points on a line `off` above the ground (plus the lift that keeps a straight board clear of the ground between
	-- its ends)
	local function topLine(x0, z0, x1, z1, off)
		local h0, h1 = groundAt(x0, z0), groundAt(x1, z1)
		local lift = 0
		for q = 1, 3 do
			local t = q / 4
			local dv = groundAt(x0 + (x1 - x0) * t, z0 + (z1 - z0) * t) - (h0 + (h1 - h0) * t)
			if dv > lift then
				lift = dv
			end
		end
		return V(x0, h0 + lift + off, z0), V(x1, h1 + lift + off, z1)
	end
	-- a board whose top face runs along the line a-b (world points), th thick, w wide, `extra` longer; decor boards are not
	-- solid and cast no shadow
	local function board(parent, w, th, a, b, color, mat, extra, decor)
		local len = (b - a).Magnitude
		if len < 0.05 then
			return nil
		end
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -th / 2, 0)
		local p = kit.boxCF(parent, w, th, len + (extra or 0), cf, color, mat)
		p.CanTouch = false
		p.CastShadow = false
		if decor then
			p.CanCollide = false
			p.CanQuery = false
		end
		return p
	end
	local function decorate(p)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		return p
	end

	-- ── the invisible boundary: walls along the OUTER limit (players may enter the minefield and sniper bands) ──
	step("boundary", function()
		local bm = kit.model("Boundary", map)
		bm:SetAttribute("NoWire", true) -- the detail plan would crown long high parts with barbed wire
		local area = 0
		local nb = #LIM / 2
		for e = 1, nb do
			local f = (e % nb) + 1
			area += LIM[2 * e - 1] * LIM[2 * f] - LIM[2 * f - 1] * LIM[2 * e]
		end
		local sgn = 1
		if area < 0 then
			sgn = -1
		end
		for e = 1, nb do
			local f = (e % nb) + 1
			local ax, az, bx, bz = LIM[2 * e - 1], LIM[2 * e], LIM[2 * f - 1], LIM[2 * f]
			local dx, dz = bx - ax, bz - az
			local len = math.sqrt(dx * dx + dz * dz)
			if len > 0.5 then
				local ox, oz = dz / len * sgn, -dx / len * sgn -- outward normal
				local mx, mz = (ax + bx) / 2 + ox * 1.2, (az + bz) / 2 + oz * 1.2
				local cf = CFrame.new(O.X + mx, 110, O.Z + mz) * CFrame.Angles(0, -math.atan2(dz, dx), 0)
				local wall = kit.boxCF(bm, len + 2.4, 400, 2.4, cf, C.pale, M.SmoothPlastic)
				wall.Transparency = 1
				wall.CanQuery = false
				wall.CanTouch = false
				wall.CastShadow = false
				wall.Name = "Boundary"
				wall:SetAttribute("NoDetail", true)
				count.boundary += 1
			end
		end
	end)

	-- ── roads: asphalt boards along the polylines (gravel tracks are painted into the terrain) ────────────
	step("roads", function()
		local rm = kit.model("Roads", map)
		local ASPH = { H = hex("3A3C3B"), T = hex("424543") }
		local MARK = hex("C9C2A5")
		local parity = 0
		for _, rd in L.roads do
			local surf, w, pts = rd[2], rd[3], rd[4]
			if surf ~= "G" then
				local n = #pts / 2
				local col = ASPH[surf] or ASPH.T
				for s = 1, n - 1 do
					local ax, az, bx, bz = pts[2 * s - 1], pts[2 * s], pts[2 * s + 1], pts[2 * s + 2]
					for _, rn in landRuns(ax, az, bx, bz, onLand) do
						local x0, z0 = ax + (bx - ax) * rn[1], az + (bz - az) * rn[1]
						local x1, z1 = ax + (bx - ax) * rn[2], az + (bz - az) * rn[2]
						if (x1 - x0) * (x1 - x0) + (z1 - z0) * (z1 - z0) > 4 then
							pieces(x0, z0, x1, z1, 160, 40, 0.5, function(px0, pz0, px1, pz1)
								parity = (parity + 1) % 3
								local a, b = topLine(px0, pz0, px1, pz1, 0.14 + 0.02 * parity)
								board(rm, w, 0.6, a, b, col, M.Asphalt, 0.4, false)
								count.road += 1
								if surf == "H" then
									-- a worn centre line: 8-stud dashes every 32
									local len = (b - a).Magnitude
									local dir = (b - a) / math.max(len, 0.01)
									local d0 = 4
									local up = Vector3.new(0, 0.07, 0)
									while d0 + 8 <= len - 2 do
										board(rm, 0.6, 0.12, a + dir * d0 + up, a + dir * (d0 + 8) + up, MARK, M.SmoothPlastic, 0, true)
										count.dash += 1
										d0 += 32
									end
								end
							end)
						end
					end
				end
				-- a round patch at each real bend fills the wedge between the boards (a closed loop bends at its first point too)
				local closed = math.abs(pts[1] - pts[2 * n - 1]) < 0.5 and math.abs(pts[2] - pts[2 * n]) < 0.5
				local from, to = 2, n - 1
				if closed then
					from = 1
				end
				for q = from, to do
					local vx, vz = pts[2 * q - 1], pts[2 * q]
					local pa = q - 1
					if pa < 1 then
						pa = n - 1
					end
					local ux, uz = vx - pts[2 * pa - 1], vz - pts[2 * pa]
					local wx, wz = pts[2 * q + 1] - vx, pts[2 * q + 2] - vz
					local cosA = (ux * wx + uz * wz) / math.max(0.01, math.sqrt(ux * ux + uz * uz) * math.sqrt(wx * wx + wz * wz))
					if cosA < 0.9945 and onLand(vx, vz) then
						local disk = kit.vcyl(rm, 0.6, w, O.X + vx, groundAt(vx, vz) - 0.4, O.Z + vz, col, M.Asphalt)
						disk.CanTouch = false
						disk.CastShadow = false
						count.road += 1
					end
				end
			end
			pace()
		end
	end)

	-- ── the four dock ramps (V_OUT_*): a wedge from the ground up to the shell's L1 level with a kerb along both sides ──
	step("ramps", function()
		local rm = kit.model("Ramps", map)
		local CONC, KERB = hex("7A7B74"), hex("66685F")
		for _, v in L.mall.vert do
			if v.kind == "vehicle_ramp" and string.sub(v.id, 1, 5) == "V_OUT" then
				local dx, dz = v.x1 - v.x0, v.z1 - v.z0
				local run = math.sqrt(dx * dx + dz * dz)
				local ux, uz = dx / run, dz / run -- toward the high end
				local gy = groundAt(v.x0, v.z0)
				local top = L.H.L1
				local mid = V((v.x0 + v.x1) / 2, (gy - 0.6 + top) / 2, (v.z0 + v.z1) / 2)
				local cf = CFrame.lookAt(mid, mid - Vector3.new(ux, 0, uz))
				local wedge = kit.part(rm, Vector3.new(v.w, top - gy + 0.6, run), cf, CONC, M.Concrete, "WedgePart")
				wedge.Name = v.id
				wedge.CanTouch = false
				count.ramp += 1
				local a, b = V(v.x0, gy, v.z0), V(v.x1, top, v.z1)
				local side = Vector3.new(-uz, 0, ux)
				for _, sd in { -1, 1 } do
					local off = side * (sd * (v.w / 2 - 0.5))
					local pa, pb = a + off, b + off
					local kerb = kit.boxCF(rm, 1.0, 3.2, (pb - pa).Magnitude, CFrame.lookAt((pa + pb) / 2, pb) * CFrame.new(0, 1.6, 0), KERB, M.Concrete)
					kerb.CanTouch = false
					kerb.CastShadow = false
					count.ramp += 1
				end
			end
		end
	end)

	-- ── surface car parks: worn bay markings on the five west lots (a few separators per row, kept sparse for the budget) ──
	step("car parks", function()
		local cm = kit.model("CarParks", map)
		local PAINT = hex("B9B7A8")
		local BAY, DEPTH, AISLE = 7.8, 15.6, 21.9
		for _, y in L.yards do
			if y[9] == 1 and count.mark < MAXMARK then
				local cx, cz, w, d, rot, pts = y[4], y[5], y[6], y[7], y[8], y[10]
				local a = math.rad(rot)
				local ca, sa = math.cos(a), math.sin(a)
				-- the rows across the lot: a single row on the edge, then double rows (back to back) between aisles
				local rows = {}
				local v = -d / 2 + 3
				table.insert(rows, { v + DEPTH / 2, DEPTH })
				v += DEPTH + AISLE
				while v + 2 * DEPTH <= d / 2 - 3 do
					table.insert(rows, { v + DEPTH, 2 * DEPTH })
					v += 2 * DEPTH + AISLE
				end
				if v + DEPTH <= d / 2 - 3 then
					table.insert(rows, { v + DEPTH / 2, DEPTH })
				end
				local base = CFrame.new(O.X + cx, 0, O.Z + cz) * CFrame.Angles(0, -a, 0)
				local function at(u, vv)
					return cx + u * ca - vv * sa, cz + u * sa + vv * ca
				end
				for _, row in rows do
					local vc, depth = row[1], row[2]
					local u = -w / 2 + 6
					while u < w / 2 - 6 do
						if rng:NextNumber() < 0.55 then
							local px, pz = at(u, vc)
							if pointIn(pts, px, pz) and count.mark < MAXMARK then
								local g = groundAt(px, pz)
								decorate(kit.boxCF(cm, 0.45, 0.08, depth, base * CFrame.new(u, g + 0.06, vc), PAINT, M.SmoothPlastic))
								count.mark += 1
							end
						end
						u += 2 * BAY
					end
					if depth > DEPTH + 1 and count.mark < MAXMARK then
						-- the line along the back of a double row, trimmed to the lot's outline
						local u0, u1 = -w / 2 + 6, w / 2 - 6
						local px, pz = at(u0, vc)
						while u0 < u1 and not pointIn(pts, px, pz) do
							u0 += 4
							px, pz = at(u0, vc)
						end
						px, pz = at(u1, vc)
						while u1 > u0 and not pointIn(pts, px, pz) do
							u1 -= 4
							px, pz = at(u1, vc)
						end
						if u1 - u0 > 12 then
							local g = groundAt(at((u0 + u1) / 2, vc))
							decorate(kit.boxCF(cm, u1 - u0, 0.08, 0.45, base * CFrame.new((u0 + u1) / 2, g + 0.06, vc), PAINT, M.SmoothPlastic))
							count.mark += 1
						end
					end
				end
			end
		end
	end)

	-- ── rails: a ballast bed, a sleeper strip and two rails per piece (the two border rails south of the limit are skipped) ──
	step("rails", function()
		local rm = kit.model("Rails", map)
		rm:SetAttribute("NoWire", true) -- the detail plan would crown long high parts with barbed wire
		local BALLAST, SLEEP, STEEL = hex("5C574E"), hex("4B3F33"), hex("6A5A4E")
		-- where a line leaves the map (past the limit the hills rise), its rails stop at the foot of the slope: every run end
		-- and its way on, for the tunnel portals (below; RailPortals keeps the ends where the hill rises right past them)
		local exits, ends = {}, {}
		for _, rl in L.rails do
			local pts = rl[3]
			if rl[2] == 0 then
				for s = 1, #pts / 2 - 1 do
					local ax, az, bx, bz = pts[2 * s - 1], pts[2 * s], pts[2 * s + 1], pts[2 * s + 2]
					local sl = math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
					local ux, uz = (bx - ax) / math.max(sl, 0.01), (bz - az) / math.max(sl, 0.01)
					for _, rn in landRuns(ax, az, bx, bz, onLand) do
						local x0, z0 = ax + (bx - ax) * rn[1], az + (bz - az) * rn[1]
						local x1, z1 = ax + (bx - ax) * rn[2], az + (bz - az) * rn[2]
						-- the line's own ends and the ends of clipped runs (not a bend, where the next piece goes on)
						if rn[2] < 0.999 or s == #pts / 2 - 1 then
							table.insert(exits, { x = x1, z = z1, ux = ux, uz = uz })
						end
						if rn[1] > 0.001 or s == 1 then
							table.insert(exits, { x = x0, z = z0, ux = -ux, uz = -uz })
						end
						table.insert(ends, { x = x0, z = z0 })
						table.insert(ends, { x = x1, z = z1 })
						if (x1 - x0) * (x1 - x0) + (z1 - z0) * (z1 - z0) > 4 then
							pieces(x0, z0, x1, z1, 140, 30, 0.3, function(px0, pz0, px1, pz1)
								local a, b = topLine(px0, pz0, px1, pz1, 0)
								local dir = (b - a).Unit
								local side = Vector3.new(-dir.Z, 0, dir.X).Unit
								board(rm, 9.6, 0.7, a + Vector3.new(0, 0.3, 0), b + Vector3.new(0, 0.3, 0), BALLAST, M.Pebble, 0.3, false)
								board(rm, 8.4, 0.3, a + Vector3.new(0, 0.6, 0), b + Vector3.new(0, 0.6, 0), SLEEP, M.WoodPlanks, 0.3, false)
								for _, sd in { -2.375, 2.375 } do
									local off = side * sd + Vector3.new(0, 1.0, 0)
									board(rm, 0.5, 0.4, a + off, b + off, STEEL, M.Metal, 0.15, false)
								end
								count.rail += 1
							end)
						end
					end
				end
			end
			pace()
		end
		-- tunnel portals where the line meets the rising hill (Maps/RailPortals.luau)
		count.portal = require(script.Parent.Parent.RailPortals)(kit, rm, exits, ends, groundAt, V)
	end)

	-- ── fences: chain-link runs along the reference polylines (a see-through panel that blocks walking but not shots, posts
	-- every 28 studs) ──────────────────────────────────────────────────────────────────────────────────────
	step("fences", function()
		local fm = kit.model("Fences", map)
		local FENCE = hex("6D716C")
		local FH = 7.8
		local function piece(x0, z0, x1, z1)
			local a, b = V(x0, groundAt(x0, z0), z0), V(x1, groundAt(x1, z1), z1)
			local len = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
			local n = math.max(1, math.floor(len / 28 + 0.5))
			for q = 0, n do
				local p = a:Lerp(b, q / n)
				local post = kit.boxCF(fm, 0.3, FH + 0.6, 0.3, CFrame.new(p + Vector3.new(0, (FH + 0.6) / 2 - 0.6, 0)), FENCE, M.Metal)
				post.CanTouch = false
				count.fence += 1
			end
			local mid = (a + b) / 2
			local look = CFrame.lookAt(mid, Vector3.new(b.X, mid.Y, b.Z))
			local mesh = kit.boxCF(fm, 0.08, FH - 0.2, len, look * CFrame.new(0, FH / 2, 0), FENCE, M.SmoothPlastic)
			mesh.Transparency = 1
			mesh.CanQuery = false
			mesh.CanTouch = false
			mesh.CastShadow = false
			mesh:SetAttribute("NoDetail", true)
			mesh.Name = "ChainLink"
			for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
				local tx = Instance.new("Texture")
				tx.Texture = Wear.DEC.ChainLink
				tx.Face = face
				tx.StudsPerTileU = 3
				tx.StudsPerTileV = 3
				tx.Parent = mesh
			end
			count.fence += 1
		end
		for _, f in L.fences do
			local pts = f[2]
			for s = 1, #pts / 2 - 1 do
				local ax, az, bx, bz = pts[2 * s - 1], pts[2 * s], pts[2 * s + 1], pts[2 * s + 2]
				for _, rn in landRuns(ax, az, bx, bz, onLand) do
					local x0, z0 = ax + (bx - ax) * rn[1], az + (bz - az) * rn[1]
					local x1, z1 = ax + (bx - ax) * rn[2], az + (bz - az) * rn[2]
					if (x1 - x0) * (x1 - x0) + (z1 - z0) * (z1 - z0) > 9 then
						pieces(x0, z0, x1, z1, 96, 24, 0.6, piece)
					end
				end
			end
			pace()
		end
	end)

	-- ── power lines: lattice pylons where a tower stands inside the limit, sagging wires between them ──────
	step("power", function()
		local pm = kit.model("Power", map)
		pm:SetAttribute("NoWire", true) -- the detail plan would crown long high parts with barbed wire
		local STEEL, WIRE = hex("6E7370"), hex("23262A")
		local function beam(parent, p, q, th)
			local len = (q - p).Magnitude
			if len < 0.1 then
				return
			end
			local part = kit.boxCF(parent, th, th, len, CFrame.lookAt((p + q) / 2, q), STEEL, M.Metal)
			part.CanTouch = false
			part.CastShadow = false
		end
		-- attach points on a pylon: across the line and height (the wires hang 2.5 below the arm)
		local ATT = { { -11, 44 }, { 11, 44 }, { 0, 52 } }
		local function frameOf(t, g)
			local px, pz = -t.dz, t.dx
			return function(u, v, y)
				return V(t.x + px * u + t.dx * v, g + y, t.z + pz * u + t.dz * v)
			end
		end
		local function pylon(t)
			local g = groundAt(t.x, t.z)
			local P = frameOf(t, g)
			local base, tip = 6, 1.4
			for _, su in { -1, 1 } do
				for _, sv in { -1, 1 } do
					beam(pm, P(su * base, sv * base, -1), P(su * tip, sv * tip, 52), 1.0)
				end
			end
			for _, y in { 16, 34 } do
				local hw = base + (tip - base) * (y + 1) / 53
				beam(pm, P(-hw, -hw, y), P(hw, -hw, y), 0.6)
				beam(pm, P(hw, -hw, y), P(hw, hw, y), 0.6)
				beam(pm, P(hw, hw, y), P(-hw, hw, y), 0.6)
				beam(pm, P(-hw, hw, y), P(-hw, -hw, y), 0.6)
			end
			beam(pm, P(-11, 0, 44), P(11, 0, 44), 0.8)
			beam(pm, P(-4, 0, 52), P(4, 0, 52), 0.7)
			for _, at in ATT do
				beam(pm, P(at[1], 0, at[2]), P(at[1], 0, at[2] - 2.5), 0.5)
			end
			count.pylon += 1
		end
		local function wires(ta, tb)
			local ga = groundAt(ta.x, ta.z)
			local gb = ga
			if limitAt(tb.x, tb.z) then
				gb = groundAt(tb.x, tb.z)
			end
			local PA, PB = frameOf(ta, ga), frameOf(tb, gb)
			local span = math.sqrt((tb.x - ta.x) ^ 2 + (tb.z - ta.z) ^ 2)
			local sag = math.min(14, 0.03 * span)
			local nseg = 4
			if span < 150 then
				nseg = 3
			end
			for _, at in ATT do
				local A = PA(at[1], 0, at[2] - 2.5)
				local Bp = PB(at[1], 0, at[2] - 2.5)
				local prev = A
				for q = 1, nseg do
					local t = q / nseg
					local p = A:Lerp(Bp, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
					if limitAt(prev.X - O.X, prev.Z - O.Z) or limitAt(p.X - O.X, p.Z - O.Z) then
						local len = (p - prev).Magnitude
						if len > 0.1 then
							local w = kit.boxCF(pm, 0.2, 0.2, len, CFrame.lookAt((prev + p) / 2, p), WIRE, M.Metal)
							w.CanCollide = false
							w.CanQuery = false
							w.CanTouch = false
							w.CastShadow = false
							count.wire += 1
						end
					end
					prev = p
				end
			end
		end
		for _, pl in L.power do
			local pts = pl[2]
			local list = {}
			for q = 1, #L.towers, 2 do
				local tx, tz = L.towers[q], L.towers[q + 1]
				local best, arc, run = math.huge, 0, 0
				for s = 1, #pts / 2 - 1 do
					local ax, az, bx, bz = pts[2 * s - 1], pts[2 * s], pts[2 * s + 1], pts[2 * s + 2]
					local d, t = segDist(tx, tz, ax, az, bx, bz)
					local sl = math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
					if d < best then
						best, arc = d, run + t * sl
					end
					run += sl
				end
				if best < 14 then
					table.insert(list, { x = tx, z = tz, arc = arc, dx = 1, dz = 0 })
				end
			end
			table.sort(list, function(p, q)
				return p.arc < q.arc
			end)
			for q, t in list do
				local pv, nx = list[q - 1] or t, list[q + 1] or t
				local vx, vz = nx.x - pv.x, nx.z - pv.z
				local l = math.sqrt(vx * vx + vz * vz)
				if l > 0.1 then
					t.dx, t.dz = vx / l, vz / l
				end
			end
			for _, t in list do
				if limitAt(t.x, t.z) then
					pylon(t)
				end
			end
			for q = 1, #list - 1 do
				if limitAt(list[q].x, list[q].z) or limitAt(list[q + 1].x, list[q + 1].z) then
					wires(list[q], list[q + 1])
				end
			end
			pace()
		end
	end)

	-- ── hazard posts and tape along the inner edge of the minefield and sniper bands, with a warning board every third post ──
	step("hazard", function()
		local hm = kit.model("Hazard", map)
		local TAPE = hex("C29A38")
		-- points every `stride` studs along an open polyline, ends included
		local function sample(pts, stride)
			local out = { pts[1], pts[2] }
			local acc = 0
			for s = 1, #pts / 2 - 1 do
				local ax, az, bx, bz = pts[2 * s - 1], pts[2 * s], pts[2 * s + 1], pts[2 * s + 2]
				local len = math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
				local d = stride - acc
				while d <= len do
					table.insert(out, ax + (bx - ax) * d / len)
					table.insert(out, az + (bz - az) * d / len)
					d += stride
				end
				acc = len - (d - stride)
			end
			table.insert(out, pts[#pts - 1])
			table.insert(out, pts[#pts])
			return out
		end
		local function edge(pts, text, bg)
			local sp = sample(pts, 80)
			local n = #sp / 2
			for q = 1, n do
				local x, z = sp[2 * q - 1], sp[2 * q]
				local g = groundAt(x, z)
				local tall = 6
				local signed = q % 3 == 1
				if signed then
					tall = 9
				end
				local post = kit.boxCF(hm, 0.5, tall, 0.5, CFrame.new(V(x, g + tall / 2, z)), C.metalDark, M.Metal)
				post.CanTouch = false
				count.hazard += 1
				if q < n then
					local x2, z2 = sp[2 * q + 1], sp[2 * q + 2]
					local a, b = V(x, g + 4.6, z), V(x2, groundAt(x2, z2) + 4.6, z2)
					if (b - a).Magnitude > 1 then
						local tape = kit.boxCF(hm, 0.12, 0.6, (b - a).Magnitude, CFrame.lookAt((a + b) / 2, b), TAPE, M.Fabric)
						decorate(tape)
						count.hazard += 1
					end
				end
				if signed then
					local dx, dz = sp[math.min(2 * q + 1, 2 * n - 1)] - sp[math.max(2 * q - 3, 1)], sp[math.min(2 * q + 2, 2 * n)] - sp[math.max(2 * q - 2, 2)]
					local l = math.max(0.01, math.sqrt(dx * dx + dz * dz))
					local nrm = Vector3.new(-dz / l, 0, dx / l)
					local pos = V(x, g + 7.4, z)
					local sign = kit.boxCF(hm, 7, 3.6, 0.25, CFrame.lookAt(pos, pos + nrm), C.yellow, M.Metal)
					sign.CanTouch = false
					sign.CastShadow = false
					kit.sign(sign, Enum.NormalId.Front, text, C.metalDark, bg)
					kit.sign(sign, Enum.NormalId.Back, text, C.metalDark, bg)
					count.hazard += 1
				end
			end
		end
		edge(L.mine.inner, "DANGER  ·  MINES", C.yellow)
		edge(L.snipe.inner, "RESTRICTED  ·  KEEP OUT", C.yellow)
	end)

	-- ── the kart track: kerbs along its outline and tyre stacks at every other corner ───────────────────────
	step("kart", function()
		local km = kit.model("KartTrack", map)
		local RED, WHITE = hex("9A3A31"), hex("C9C6BA")
		for _, y in L.yards do
			if y[2] == "KART TRACK" then
				local pts = y[10]
				local n = #pts / 2
				for e = 1, n do
					local f = (e % n) + 1
					local ax, az, bx, bz = pts[2 * e - 1], pts[2 * e], pts[2 * f - 1], pts[2 * f]
					local a, b = V(ax, groundAt(ax, az) + 0.35, az), V(bx, groundAt(bx, bz) + 0.35, bz)
					if (b - a).Magnitude > 0.5 then
						local col = RED
						if e % 2 == 0 then
							col = WHITE
						end
						decorate(board(km, 1.2, 0.35, a, b, col, M.Concrete, 0.3, true))
						count.kart += 1
					end
				end
				if B.Kit and B.Kit.place then
					-- the outside of each corner: a stack of tyres a few studs beyond the kerb
					local cx, cz = y[4], y[5]
					for e = 1, n, 2 do
						local px, pz = pts[2 * e - 1], pts[2 * e]
						local dx, dz = px - cx, pz - cz
						local l = math.max(0.01, math.sqrt(dx * dx + dz * dz))
						local x, z = px + dx / l * 3.5, pz + dz / l * 3.5
						local m = B.Kit.place(km, "TyreStack", CFrame.new(V(x, groundAt(x, z), z)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), { shadows = false })
						if m then
							count.kart += 1
						end
					end
				end
			end
		end
	end)

	-- ── rock fields and boulders (nature kit; a plain rock when the kit did not load) ──────────────────────
	step("rocks", function()
		local rk = kit.model("Rocks", map)
		local lib = game:GetService("ServerStorage"):FindFirstChild("ZR_Assets")
		local function tint(amt)
			local k = 1 - rng:NextNumber(0, amt)
			return Color3.new(k, k, k)
		end
		-- keep-out zones: building footprints (plus 10 studs) and extract spots
		local BLK = {}
		for _, b in L.blds do
			local a = math.rad(b[9])
			table.insert(BLK, { b[5], b[6], math.cos(a), math.sin(a), b[7] / 2 + 10, b[8] / 2 + 10 })
		end
		for _, e in L.ext do
			table.insert(BLK, { e[4], e[5], 1, 0, 20, 20 })
		end
		local function blocked(x, z)
			for _, q in BLK do
				local dx, dz = x - q[1], z - q[2]
				if math.abs(dx * q[3] + dz * q[4]) < q[5] and math.abs(dz * q[3] - dx * q[4]) < q[6] then
					return true
				end
			end
			return false
		end
		local function okSpot(x, z)
			if not insideAt(x, z) then
				return false
			end
			local c = CL[colOf(x)][rowOf(z)]
			return c <= 1 and slopeAt(x, z) < 1.1 and not blocked(x, z)
		end
		local ROCKS = { "ZR_NAT_Rock1", "ZR_NAT_Rock1", "ZR_NAT_Rock2", "ZR_NAT_Rock3", "ZR_NAT_RockPile" }
		local function rock(x, z, rr)
			if count.rock >= MAXROCK then
				return
			end
			local key = ROCKS[rng:NextInteger(1, #ROCKS)]
			local tpl = lib and lib:FindFirstChild(key)
			local y = groundAt(x, z)
			local yaw = rng:NextNumber(0, 360)
			local m = nil
			if tpl then
				local foot = math.max(tpl.Size.X, tpl.Size.Z, 0.5)
				local s = math.clamp(2 * rr / foot, 0.3, 14)
				m = H.nat(rk, key, CFrame.new(O.X + x, y - 0.25 * s, O.Z + z) * CFrame.Angles(0, math.rad(yaw), 0), Vector3.new(s, s * rng:NextNumber(0.7, 1.1), s), tint(0.12), true)
			end
			if not m then
				m = kit.part(rk, Vector3.new(2 * rr, 1.3 * rr, 1.7 * rr), CFrame.new(O.X + x, y + 0.3 * rr, O.Z + z) * CFrame.Angles(0, math.rad(yaw), 0), hex("6B675F"), M.Rock)
			end
			m.Name = "Rock"
			count.rock += 1
		end
		-- the rock fields: boulders spread over each outline, more on the big ones
		for _, f in L.rockFields do
			local pts = f[3]
			local minx, maxx, minz, maxz = math.huge, -math.huge, math.huge, -math.huge
			for q = 1, #pts, 2 do
				minx, maxx = math.min(minx, pts[q]), math.max(maxx, pts[q])
				minz, maxz = math.min(minz, pts[q + 1]), math.max(maxz, pts[q + 1])
			end
			local want = math.clamp(math.floor(f[2] / 160 + 0.5), 3, 36)
			local placed, tries = 0, 0
			while placed < want and tries < want * 14 do
				tries += 1
				local x, z = rng:NextNumber(minx, maxx), rng:NextNumber(minz, maxz)
				if pointIn(pts, x, z) and okSpot(x, z) then
					rock(x, z, rng:NextNumber(2.5, 7.5))
					placed += 1
				end
			end
			pace()
		end
		-- the reference's loose boulders and outcrops: a cluster by size
		for q = 1, #L.rocks, 3 do
			local x, z, r = L.rocks[q], L.rocks[q + 1], L.rocks[q + 2]
			if insideAt(x, z) then
				local n = math.clamp(math.floor(r / 14 + 0.5), 1, 6)
				for _ = 1, n do
					local ang, dist = rng:NextNumber(0, 6.2832), rng:NextNumber(0, 0.7) * r
					local px, pz = x + math.cos(ang) * dist, z + math.sin(ang) * dist
					if okSpot(px, pz) then
						rock(px, pz, math.clamp(r * rng:NextNumber(0.1, 0.2), 2.5, 9))
					end
				end
			end
		end
	end)

	-- ── a thin outline of the mall's walls while the shell does not exist ───────────────────────────────────
	if not B.hasMall then
		step("outline", function()
			local om = kit.model("MallOutline", map)
			om:SetAttribute("Placeholder", true)
			local n = #MO / 2
			for e = 1, n do
				local f = (e % n) + 1
				local ax, az, bx, bz = MO[2 * e - 1], MO[2 * e], MO[2 * f - 1], MO[2 * f]
				local len = math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
				if len > 0.5 then
					local cf = CFrame.new(O.X + (ax + bx) / 2, 4, O.Z + (az + bz) / 2) * CFrame.Angles(0, -math.atan2(bz - az, bx - ax), 0)
					local p = kit.boxCF(om, len, 8, 0.6, cf, hex("B07A3C"), M.SmoothPlastic)
					p.Transparency = 0.5
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					p.CastShadow = false
					p.Name = "OutlineWall"
					p:SetAttribute("NoDetail", true)
					count.outline += 1
				end
			end
		end)
	end
end
