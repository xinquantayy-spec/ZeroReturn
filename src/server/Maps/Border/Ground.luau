--!nonstrict
-- Border Yard ground (foundation, part 1 of 3). Map-local studs throughout (see Layout.luau): x east, z south.
-- 1. A height grid of 4-stud columns: the reference's relief, graded roads and rails, flat pads under every building and
--    yard, the east rail embankment, the river channel with banks and the island, and berms and cliffs outside the
--    boundary that close the view. TerrainKit writes it chunk by chunk (time-sliced); B.ground(x, z) reads the same grid,
--    so placing things never needs a raycast.
-- 2. Terrain materials by area (grass and ground, leaf litter and mud under forests, gravel along rails and tracks,
--    concrete under yards, asphalt under roads, sand and mud in the river, rock on steep ground).
-- 3. Parts: asphalt roads, rails and level crossings, MAIN BRIDGE and SCRAP BRIDGE, fences, power pylons and wires, the
--    invisible boundary walls, forests (trees, bushes) and rocks.
-- Sets on B: ground(x, z), inside(x, z), riverD(x, z) (studs inside the channel, negative on land), slope(x, z), T (the
-- TerrainKit result) and islandTop; counts go into B.count. Each section runs under pcall: a failure is logged and the
-- sections after it still build.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local R = 4 -- column size in studs (one terrain voxel)
local EX, EZ = 1800, 940 -- terrain half extents: the playable box plus 100 to 170 studs of berm and cliff
local NX, NZ = (2 * EX) / R, (2 * EZ) / R
local Y0, NY = -72, 60 -- voxel layers of 4 studs: y -72 .. 168
local MAXTREE, MAXBUSH = 700, 900

return function(B)
	local kit, H, map, L, O, rng = B.kit, B.H, B.map, B.L, B.O, B.rng
	local C, M, hex = kit.C, kit.M, kit.hex
	local V = H.V
	local count = B.count or {}
	B.count = count
	for _, key in { "terrain", "road", "rail", "crossing", "fence", "pylon", "wire", "bridge", "boundary", "tree", "bush", "rock" } do
		count[key] = count[key] or 0
	end
	local TK = require(script.Parent.Parent.TerrainKit)

	local function step(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			warn("[ZR] Border ground: " .. name .. " failed: " .. tostring(err))
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
		end
	end

	-- ── the grids ────────────────────────────────────────────────────────────────────────────────────────
	-- HG height of each column's surface; CL class (0 plain, 1 forest, 2 rail bed, 3 yard, 4 track, 5 asphalt, 8 outside
	-- the boundary, 9 river bed, 10 bank and shallows); INS inside the boundary; DB distance to the boundary (outside)
	local HG, CL, INS, DB = table.create(NX), table.create(NX), table.create(NX), table.create(NX)
	for i = 1, NX do
		CL[i], INS[i], DB[i] = table.create(NZ, 0), table.create(NZ, false), table.create(NZ, 90)
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
	B.ground = groundAt
	local function insideAt(x, z)
		return INS[colOf(x)][rowOf(z)]
	end
	B.inside = insideAt
	local function slopeAt(x, z)
		local dx = (groundAt(x + R, z) - groundAt(x - R, z)) / (2 * R)
		local dz = (groundAt(x, z + R) - groundAt(x, z - R)) / (2 * R)
		return math.sqrt(dx * dx + dz * dz)
	end
	B.slope = slopeAt

	-- 2. the boundary: which columns are inside, and the distance to it from outside (for the berms)
	local BP = L.boundary
	step("boundary field", function()
		for i = 1, NX do
			local zs = crossings(BP, xAt(i))
			local col = INS[i]
			for q = 1, #zs - 1, 2 do
				local ka = math.max(1, math.ceil((zs[q] + EZ) / R + 0.5))
				local kb = math.min(NZ, math.floor((zs[q + 1] + EZ) / R + 0.5))
				for k = ka, kb do
					col[k] = true
				end
			end
			if i % 20 == 0 then
				pace()
			end
		end
		local REACH = 84
		local nb = #BP / 2
		for e = 1, nb do
			local f = (e % nb) + 1
			local ax, az, bx, bz = BP[2 * e - 1], BP[2 * e], BP[2 * f - 1], BP[2 * f]
			for i = colOf(math.min(ax, bx) - REACH), colOf(math.max(ax, bx) + REACH) do
				local x = xAt(i)
				local dcol = DB[i]
				for k = rowOf(math.min(az, bz) - REACH), rowOf(math.max(az, bz) + REACH) do
					local d = segDist(x, zAt(k), ax, az, bx, bz)
					if d < dcol[k] then
						dcol[k] = d
					end
				end
			end
			if e % 6 == 0 then
				pace()
			end
		end
	end)

	-- 3. roads and rails are graded: across a road the ground follows the line between its vertices (so a road board
	-- never sits on a cross slope), blending back into the relief beside it
	local GRD = {} -- key (i * 1024 + k) -> grading weight, kept so the river valley leaves road beds alone
	step("grade", function()
		local gw, gh = {}, {}
		local function line(pts, halfW, blend)
			local n = #pts / 2
			local hs = table.create(n, 0)
			for q = 1, n do
				local h = groundAt(pts[2 * q - 1], pts[2 * q])
				if math.abs(h) < 3 then
					h = 0 -- the plain stays exactly flat
				end
				hs[q] = h
			end
			eachNear(pts, halfW + blend, function(i, k, d, t, s)
				local wgt = 1 - smooth((d - halfW) / blend)
				if wgt > 0.004 then
					local key = i * 1024 + k
					gw[key] = (gw[key] or 0) + wgt
					gh[key] = (gh[key] or 0) + wgt * (hs[s] + (hs[s + 1] - hs[s]) * t)
					if wgt > (GRD[key] or 0) then
						GRD[key] = wgt
					end
				end
			end)
			pace()
		end
		for _, rd in L.roads do
			line(rd[4], rd[3] / 2 + 1, 12)
		end
		for _, rl in L.rails do
			line(rl[3], 6.5, 10)
		end
		for key, wsum in gw do
			local i = math.floor(key / 1024)
			local k = key - i * 1024
			local col = HG[i]
			col[k] = col[k] + (gh[key] / wsum - col[k]) * GRD[key]
		end
	end)

	-- 4. flat pads under every yard and building (the plain stays at y 0 under them; elsewhere the pad takes the ground
	-- height at its centre), blending out over 16 to 22 studs
	step("pads", function()
		local list = {}
		for _, y in L.yards do
			if not string.find(y[2], "SCRAP BRIDGE", 1, true) then
				table.insert(list, { y[3], y[4], y[5], y[6], y[7], 22 })
			end
		end
		table.sort(list, function(a, b)
			return a[3] * a[4] > b[3] * b[4]
		end)
		for _, b in L.blds do
			table.insert(list, { b[4], b[5], b[6], b[7], b[8], 16 })
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
	end)

	-- 5. the raised east railway (rail_8): a bed with sloped sides, tapering out at both ends
	step("embankment", function()
		for _, rl in L.rails do
			local emb, pts = rl[2], rl[3]
			if emb > 0 then
				local n = #pts / 2
				local cum, total = { 0 }, 0
				for s = 1, n - 1 do
					total += math.sqrt((pts[2 * s + 1] - pts[2 * s - 1]) ^ 2 + (pts[2 * s + 2] - pts[2 * s]) ^ 2)
					cum[s + 1] = total
				end
				local add = {}
				eachNear(pts, 17, function(i, k, d, t, s)
					local arc = cum[s] + t * (cum[s + 1] - cum[s])
					local taper = math.min(1, arc / 60, (total - arc) / 60)
					local a = emb * taper * (1 - smooth((d - 7) / 10))
					local key = i * 1024 + k
					if a > (add[key] or 0) then
						add[key] = a
					end
				end)
				for key, a in add do
					local i = math.floor(key / 1024)
					local k = key - i * 1024
					HG[i][k] += a
				end
			end
		end
	end)

	-- ── the river: bank rows and the water surface ───────────────────────────────────────────────────────
	local RV = L.river
	local RN = RV.n
	local ZA, ZB = RV.z0, RV.z0 + (RN - 1) * RV.dz
	local rxl, rxr, rws, wsE = table.create(RN, 0), table.create(RN, 0), table.create(RN, 0), table.create(RN, 0)
	for r = 1, RN do
		rxl[r], rxr[r], rws[r] = RV.rows[3 * r - 2], RV.rows[3 * r - 1], RV.rows[3 * r]
		wsE[r] = rws[r]
	end
	for _ = 1, 2 do
		local nl, nr = table.clone(rxl), table.clone(rxr)
		for r = 2, RN - 1 do
			nl[r] = rxl[r - 1] * 0.25 + rxl[r] * 0.5 + rxl[r + 1] * 0.25
			nr[r] = rxr[r - 1] * 0.25 + rxr[r] * 0.5 + rxr[r + 1] * 0.25
		end
		rxl, rxr = nl, nr
	end
	-- bank x west, bank x east and water surface at z (the end rows continue past the ends)
	local function rowAt(z)
		local f = (math.clamp(z, ZA, ZB) - ZA) / RV.dz
		local r0 = math.min(RN - 1, math.floor(f) + 1)
		local t = f - (r0 - 1)
		return rxl[r0] + (rxl[r0 + 1] - rxl[r0]) * t, rxr[r0] + (rxr[r0 + 1] - rxr[r0]) * t, wsE[r0] + (wsE[r0 + 1] - wsE[r0]) * t
	end
	local function riverD(x, z)
		if z < ZA - 70 or z > ZB + 70 then
			return -999
		end
		local xl, xr = rowAt(z)
		return math.min(x - xl, xr - x)
	end
	B.riverD = riverD

	-- the water surface: the reference's, lowered where the banks are low, never rising downstream
	step("river levels", function()
		for r = 1, RN do
			local z = ZA + (r - 1) * RV.dz
			local bank = math.min(groundAt(rxl[r] - 10, z), groundAt(rxr[r] + 10, z))
			wsE[r] = math.min(rws[r], bank - 3)
		end
		for r = 2, RN do
			wsE[r] = math.min(wsE[r], wsE[r - 1])
		end
	end)

	-- 6. berms and cliffs outside the boundary (the view closes 70 to 120 studs beyond the invisible wall)
	step("berm", function()
		local BW, BH = 62, 100
		for i = 1, NX do
			local x = xAt(i)
			local hc, cc, ic, dc = HG[i], CL[i], INS[i], DB[i]
			for k = 1, NZ do
				if not ic[k] then
					local z = zAt(k)
					local n1 = math.noise(x / 85 + 11.3, z / 85 + 4.7, 1.9)
					local u = math.clamp(dc[k] / (BW + 14 * n1), 0, 1)
					local rise = (BH + 40 * n1) * u * u * (3 - 2 * u)
					rise += 5 * math.noise(x / 23 + 0.3, z / 23 + 0.7, 7.3) * smooth((dc[k] - 40) / 40)
					hc[k] = math.min(158, hc[k] + math.max(0, rise))
					cc[k] = 8
				end
			end
			if i % 8 == 0 then
				pace()
			end
		end
	end)

	-- 7. the channel: a bed under the water surface, banks sloping up to the ground, a valley where the river lies
	-- deep, the channel closing at both ends, and the island
	local WGRID = {} -- WGRID[i][k] = water surface of the column, absent on dry columns
	step("river", function()
		local DEPTH, BW, RB0, CAP, VSL = 7, 16, 14, 56, 0.3
		local xmin, xmax = math.huge, -math.huge
		for r = 1, RN do
			xmin, xmax = math.min(xmin, rxl[r]), math.max(xmax, rxr[r])
		end
		local i0, i1 = colOf(xmin - 170), colOf(xmax + 170)
		local k0, k1 = rowOf(ZA - CAP - 4), rowOf(ZB + CAP + 4)
		for i = i0, i1 do
			local x = xAt(i)
			local hc, cc, ic = HG[i], CL[i], INS[i]
			local wcol = {}
			WGRID[i] = wcol
			for k = k0, k1 do
				local z = zAt(k)
				local xl, xr, ws = rowAt(z)
				local ex = 0
				if z < ZA then
					ex = ZA - z
				elseif z > ZB then
					ex = z - ZB
				end
				local close = 1 - smooth(ex / CAP)
				if close > 0.002 then
					local dxIn = math.min(x - xl, xr - x)
					local h0 = hc[k]
					local hn = h0
					if dxIn > 0 then
						hn = math.min(h0, ws - DEPTH * smooth(dxIn / BW))
						wcol[k] = ws
						if close > 0.3 then
							cc[k] = 10
						end
					else
						local dd = -dxIn
						local hv = h0
						if ic[k] and dd < 190 then
							local gwt = GRD[i * 1024 + k] or 0
							hv = math.min(h0, ws + 4 + VSL * dd) * (1 - gwt) + h0 * gwt
						end
						local rb = RB0 + 0.45 * math.max(0, hv - ws - 8)
						if dd < rb then
							hn = math.min(hv, ws + (hv - ws) * smooth(dd / rb))
							if close > 0.3 then
								cc[k] = 10
							end
						else
							hn = hv
						end
					end
					hc[k] = h0 + (hn - h0) * close
				end
			end
			pace()
		end
		-- the island stands 3.4 studs over the water
		local ip = L.island
		local sx0, sx1, sz0, sz1 = math.huge, -math.huge, math.huge, -math.huge
		for q = 1, #ip, 2 do
			sx0, sx1 = math.min(sx0, ip[q]), math.max(sx1, ip[q])
			sz0, sz1 = math.min(sz0, ip[q + 1]), math.max(sz1, ip[q + 1])
		end
		local _, _, wsI = rowAt((sz0 + sz1) / 2)
		local top = wsI + 3.4
		B.islandTop = top
		for i = colOf(sx0 - 14), colOf(sx1 + 14) do
			local x = xAt(i)
			for k = rowOf(sz0 - 14), rowOf(sz1 + 14) do
				local d = polyDist(ip, x, zAt(k))
				if d < 9 then
					local s = 1
					if d > 0 then
						s = 1 - smooth(d / 9)
					end
					local cur = HG[i][k]
					if top > cur then
						HG[i][k] = cur + (top - cur) * s
					end
				end
			end
		end
		-- dry columns lose their water level; the rest get the river classes
		for i = i0, i1 do
			local wcol, hc, cc = WGRID[i], HG[i], CL[i]
			for k = k0, k1 do
				local lv = wcol[k]
				if lv then
					local h = hc[k]
					if h < lv - 0.25 then
						if h < lv - 2.5 then
							cc[k] = 9
						else
							cc[k] = 10
						end
					else
						wcol[k] = nil
						cc[k] = 10
					end
				end
			end
		end
	end)
	local function waterAt(x, z)
		local col = WGRID[colOf(x)]
		return col and col[rowOf(z)] or nil
	end

	-- 8. voids: the underground rooms and tunnels, and the open shafts down to them (the buildings agent fills them)
	local CAVE = {}
	step("voids", function()
		-- margin: how far past the room's edge the terrain is dug. Smooth terrain slopes over about one 4-stud voxel from a
		-- full column to an empty one, so with 2 studs the slope stood inside the rooms along every wall, up to 9.5 studs
		-- over the floor of K-11 (found by the placement audit, 2026-11-01). Rooms get 6 (the slope ends behind the wall
		-- lining); the open stair shafts keep 2, as a wider cut there would show round the sheds at the surface.
		local function stamp(cxp, czp, w, d, rot, lo, hi, margin)
			local a = math.rad(rot)
			local ca, sa = math.cos(a), math.sin(a)
			local hw, hd = w / 2 + margin, d / 2 + margin
			local reach = math.sqrt(hw * hw + hd * hd) + R
			for i = colOf(cxp - reach), colOf(cxp + reach) do
				local x = xAt(i)
				for k = rowOf(czp - reach), rowOf(czp + reach) do
					local dx, dz = x - cxp, zAt(k) - czp
					if math.abs(dx * ca + dz * sa) <= hw and math.abs(dz * ca - dx * sa) <= hd then
						CAVE[i * 1024 + k] = { lo, hi }
					end
				end
			end
		end
		for _, u in L.under do
			local hi = u[10]
			if u[11] == 1 then
				hi = 400
			end
			stamp(u[4], u[5], u[6], u[7], u[8], u[9], hi, u[11] == 1 and 2 or 6)
		end
		for _, s in L.stairs do
			if s[2] == 0 then
				-- underground the shaft gets the rooms' wide cut, open to the sky only its own footprint (+2)
				stamp(s[3], s[4], s[5], s[6], s[7], -16, -4, 6)
				stamp(s[3], s[4], s[5], s[6], s[7], -16, 400, 2)
			end
		end
	end)
	local function caveAt(x, z)
		local c = CAVE[colOf(x) * 1024 + rowOf(z)]
		if c then
			return c[1], c[2]
		end
		return nil
	end

	-- 9. terrain classes by area (the material callback reads them)
	step("classes", function()
		local function paint(i, k, code)
			local col = CL[i]
			if code > col[k] then
				col[k] = code
			end
		end
		for _, f in L.forests do
			fillPoly(f[7], function(i, k)
				paint(i, k, 1)
			end)
		end
		for _, rl in L.rails do
			eachNear(rl[3], 5.5, function(i, k)
				paint(i, k, 2)
			end)
		end
		for _, y in L.yards do
			if not string.find(y[2], "SCRAP BRIDGE", 1, true) then
				fillPoly(y[8], function(i, k)
					paint(i, k, 3)
				end)
			end
		end
		-- under every building: concrete (class 3), so terrain grass never grows up through a ground floor (tall grass stood in
		-- BLOCK A's ground-floor rooms, seen in Studio 2026-11-01); one stud of margin round the footprint
		for _, b in L.blds do
			local cxp, czp, w, d, rot = b[4], b[5], b[6], b[7], b[8]
			if type(cxp) == "number" and type(czp) == "number" and type(w) == "number" and type(d) == "number" then
				local a = math.rad(tonumber(rot) or 0)
				local ca, sa = math.cos(a), math.sin(a)
				local hw, hd = w / 2 + 1, d / 2 + 1
				local reach = math.sqrt(hw * hw + hd * hd)
				for i = colOf(cxp - reach), colOf(cxp + reach) do
					local col = CL[i]
					if col then
						local x = xAt(i)
						for k = rowOf(czp - reach), rowOf(czp + reach) do
							if col[k] ~= nil then
								local dx, dz = x - cxp, zAt(k) - czp
								if math.abs(dx * ca + dz * sa) <= hw and math.abs(dz * ca - dx * sa) <= hd then
									paint(i, k, 3)
								end
							end
						end
					end
				end
			end
		end
		for _, rd in L.roads do
			local code = 5
			if rd[2] == "G" then
				code = 4
			end
			eachNear(rd[4], rd[3] / 2 + 1, function(i, k)
				if riverD(xAt(i), zAt(k)) < -10 then
					paint(i, k, code)
				end
			end)
			pace()
		end
	end)

	-- ── the terrain ──────────────────────────────────────────────────────────────────────────────────────
	local PAL = Enum.Material
	local function matAt(x, z, _h, slope)
		local c = CL[colOf(x)][rowOf(z)]
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
			-- forest floor: leafy grass, bare earth in the hollows (Customs' woods are not swamps)
			if math.noise(x / 21 + 3.1, z / 21 + 7.7, 0.5) > 0.38 then
				return PAL.Ground
			end
			return PAL.LeafyGrass
		end
		-- open ground is grass, worn to earth here and there (the old camouflage of mud and grass read as fake)
		if math.noise(x / 46, z / 46, 0.37) > 0.34 then
			return PAL.Ground
		end
		return PAL.Grass
	end

	local T = nil
	step("terrain", function()
		T = TK.build({
			O = O, extX = EX, extZ = EZ, y0 = Y0, ny = NY,
			hg = HG, waterAt = waterAt, material = matAt, cave = caveAt,
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
		local slab = kit.box(map, 3400, 6, 1760, O.X - 15, -3, O.Z, hex("5D6A3D"), M.Grass)
		slab.Name = "FallbackGround"
		warn("[ZR] Border ground: terrain failed, a flat slab stands in")
	end

	-- ── helpers for the parts ────────────────────────────────────────────────────────────────────────────
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
	-- world points on a line `off` above the ground (plus the lift that keeps a straight board clear of the ground
	-- between its ends)
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
	-- a board whose top face runs along the line a-b (world points), th thick, w wide, `extra` longer; decor boards are
	-- not solid and cast no shadow
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
	local function onLand(x, z)
		return insideAt(x, z) and riverD(x, z) < -10
	end

	-- ── roads: asphalt boards along the polylines (gravel tracks are painted into the terrain) ────────────
	step("roads", function()
		local rm = kit.model("Roads", map)
		local ASPH, MARK = C.asphalt, hex("C9C2A5")
		local parity = 0
		for _, rd in L.roads do
			local surf, w, pts = rd[2], rd[3], rd[4]
			if surf ~= "G" then
				local n = #pts / 2
				for s = 1, n - 1 do
					local ax, az, bx, bz = pts[2 * s - 1], pts[2 * s], pts[2 * s + 1], pts[2 * s + 2]
					for _, rn in landRuns(ax, az, bx, bz, onLand) do
						local x0, z0 = ax + (bx - ax) * rn[1], az + (bz - az) * rn[1]
						local x1, z1 = ax + (bx - ax) * rn[2], az + (bz - az) * rn[2]
						if (x1 - x0) * (x1 - x0) + (z1 - z0) * (z1 - z0) > 4 then
							pieces(x0, z0, x1, z1, 30, 14, 0.5, function(px0, pz0, px1, pz1)
								parity = 1 - parity
								local a, b = topLine(px0, pz0, px1, pz1, 0.14 + 0.02 * parity)
								board(rm, w, 0.6, a, b, ASPH, M.Asphalt, 0.4, false)
								count.road += 1
								if surf ~= "T" then
									-- a worn centre line: 5-stud dashes every 12
									local len = (b - a).Magnitude
									local dir = (b - a) / math.max(len, 0.01)
									local d0 = 3
									while d0 + 5 <= len - 2 do
										local up = Vector3.new(0, 0.07, 0)
										board(rm, 0.5, 0.12, a + dir * d0 + up, a + dir * (d0 + 5) + up, MARK, M.SmoothPlastic, 0, true)
										d0 += 12
									end
								end
							end)
						end
					end
				end
				-- a round patch at each bend fills the wedge between the boards
				for q = 2, n - 1 do
					local vx, vz = pts[2 * q - 1], pts[2 * q]
					local ux, uz = vx - pts[2 * q - 3], vz - pts[2 * q - 2]
					local wx, wz = pts[2 * q + 1] - vx, pts[2 * q + 2] - vz
					local cosA = (ux * wx + uz * wz) / math.max(0.01, math.sqrt(ux * ux + uz * uz) * math.sqrt(wx * wx + wz * wz))
					if cosA < 0.995 and onLand(vx, vz) then
						local disk = kit.vcyl(rm, 0.6, w, O.X + vx, groundAt(vx, vz) - 0.4, O.Z + vz, ASPH, M.Asphalt)
						disk.CanTouch = false
						disk.CastShadow = false
						count.road += 1
					end
				end
			end
			pace()
		end
	end)

	-- ── rails: a ballast bed, a sleeper strip and two rails per piece; a plate at each level crossing ─────
	step("rails", function()
		local rm = kit.model("Rails", map)
		rm:SetAttribute("NoWire", true) -- the detail plan would crown long high parts with barbed wire
		local BALLAST, SLEEP, STEEL = hex("5C574E"), hex("4B3F33"), hex("6A5A4E")
		for _, rl in L.rails do
			local pts = rl[3]
			for s = 1, #pts / 2 - 1 do
				local ax, az, bx, bz = pts[2 * s - 1], pts[2 * s], pts[2 * s + 1], pts[2 * s + 2]
				for _, rn in landRuns(ax, az, bx, bz, onLand) do
					local x0, z0 = ax + (bx - ax) * rn[1], az + (bz - az) * rn[1]
					local x1, z1 = ax + (bx - ax) * rn[2], az + (bz - az) * rn[2]
					if (x1 - x0) * (x1 - x0) + (z1 - z0) * (z1 - z0) > 4 then
						pieces(x0, z0, x1, z1, 80, 20, 0.3, function(px0, pz0, px1, pz1)
							local a, b = topLine(px0, pz0, px1, pz1, 0)
							local dir = (b - a).Unit
							local side = Vector3.new(-dir.Z, 0, dir.X).Unit
							board(rm, 9.6, 0.7, a + Vector3.new(0, 0.3, 0), b + Vector3.new(0, 0.3, 0), BALLAST, PAL.Pebble, 0.3, false)
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
			pace()
		end
		-- level crossings: an asphalt (or gravel) plate over the bed where a road crosses a track
		local roadBy, railBy = {}, {}
		for _, rd in L.roads do
			roadBy[rd[1]] = rd
		end
		for _, rl in L.rails do
			railBy[rl[1]] = rl
		end
		local function dirAt(pts, x, z)
			local best, bd = 1, math.huge
			for s = 1, #pts / 2 - 1 do
				local d = segDist(x, z, pts[2 * s - 1], pts[2 * s], pts[2 * s + 1], pts[2 * s + 2])
				if d < bd then
					best, bd = s, d
				end
			end
			local dx, dz = pts[2 * best + 1] - pts[2 * best - 1], pts[2 * best + 2] - pts[2 * best]
			local l = math.max(0.01, math.sqrt(dx * dx + dz * dz))
			return dx / l, dz / l
		end
		for _, cr in L.rcross do
			local rd, rl = roadBy[cr[1]], railBy[cr[2]]
			if rd and rl and onLand(cr[3], cr[4]) then
				local rdx, rdz = dirAt(rd[4], cr[3], cr[4])
				local tdx, tdz = dirAt(rl[3], cr[3], cr[4])
				local along = 11 / math.max(0.5, math.abs(rdx * tdz - rdz * tdx))
				local a, b = topLine(cr[3] - rdx * along / 2, cr[4] - rdz * along / 2, cr[3] + rdx * along / 2, cr[4] + rdz * along / 2, 0.62)
				local plate = board(rm, rd[3], 1.0, a, b, rd[2] == "G" and BALLAST or C.asphalt, rd[2] == "G" and PAL.Pebble or M.Asphalt, 0, false)
				if plate then
					plate.Name = "Crossing"
					count.crossing += 1
				end
			end
		end
	end)

	-- ── the two bridges ──────────────────────────────────────────────────────────────────────────────────
	step("bridges", function()
		local bm = kit.model("Bridges", map)
		bm:SetAttribute("NoWire", true) -- the detail plan would crown long high parts with barbed wire
		local CONC, CONC_D = C.concreteLight, C.concreteDark
		-- MAIN BRIDGE: a concrete deck with an asphalt surface, parapets, two piers and abutments; it runs 13 studs past
		-- each bank edge so it overlaps the road boards, which stop 10 studs from the water
		local mb = L.bridges.main
		local dx, dz = mb.x1 - mb.x0, mb.z1 - mb.z0 -- east end to west end
		local l0 = math.sqrt(dx * dx + dz * dz)
		local ux, uz = dx / l0, dz / l0
		local wx, wz = mb.x1 + ux * 13, mb.z1 + uz * 13 -- beyond the west end
		local ex, ez = mb.x0 - ux * 13, mb.z0 - uz * 13 -- beyond the east end
		local hW, hE = groundAt(wx, wz) + 0.14, groundAt(ex, ez) + 0.14
		local a, b = V(wx, hW, wz), V(ex, hE, ez)
		local len = (b - a).Magnitude
		local drop = Vector3.new(0, -0.3, 0)
		local body = board(bm, mb.w, 1.6, a + drop, b + drop, CONC, M.Concrete, 0, false)
		board(bm, mb.w - 3.6, 0.3, a, b, C.asphalt, M.Asphalt, 0, false)
		if body then
			body.Name = "MainBridgeDeck"
			local frame = CFrame.lookAt((a + b) / 2 + drop, b + drop) -- top of the body, looking along the bridge
			for _, sx in { -1, 1 } do
				local rail = kit.boxCF(bm, 0.9, 3.0, len, frame * CFrame.new(sx * (mb.w / 2 - 0.45), 1.5, 0), CONC, M.Concrete)
				rail.CastShadow = false
			end
			-- piers: a cap beam under the deck on three round columns standing on the river bed
			for _, fr in { 0.34, 0.66 } do
				local zoff = (fr - 0.5) * len
				local beam = kit.boxCF(bm, mb.w - 6, 1.4, 3.6, frame * CFrame.new(0, -1.6 - 0.7, zoff), CONC_D, M.Concrete)
				beam.CastShadow = false
				for _, cx in { -(mb.w / 2 - 7), 0, mb.w / 2 - 7 } do
					local p = (frame * CFrame.new(cx, -2.3, zoff)).Position
					local bed = groundAt(p.X - O.X, p.Z - O.Z) - 1.5
					if p.Y - bed > 1 then
						local col = kit.vcyl(bm, p.Y - bed, 3.2, p.X, bed, p.Z, CONC_D, M.Concrete)
						col.CastShadow = false
					end
				end
			end
			-- abutments under the deck at the two bank edges
			for _, fr in { 13 / len, 1 - 13 / len } do
				local p = (frame * CFrame.new(0, -1.6, (fr - 0.5) * len)).Position
				local bed = groundAt(p.X - O.X, p.Z - O.Z) - 3
				if p.Y - bed > 1 then
					local ab = kit.boxCF(bm, mb.w - 1, p.Y - bed, 4, frame * CFrame.new(0, -1.6 - (p.Y - bed) / 2, (fr - 0.5) * len), CONC_D, M.Concrete)
					ab.CastShadow = false
				end
			end
			count.bridge += 1
		end

		-- SCRAP BRIDGE: two plank decks between the banks and the island, each with rusty railings
		local sb = L.bridges.scrap
		local top = (B.islandTop or 0) + 0.14
		local PLANK, RUST = hex("5E4B3A"), hex("7A5546")
		for idx, d in sb.decks do
			local cx, cz, ln, wd, rot = d[1], d[2], d[3], d[4], d[5]
			local ca, sa = math.cos(math.rad(rot)), math.sin(math.rad(rot))
			local ax, az = cx - ca * ln / 2, cz - sa * ln / 2 -- west end
			local bx, bz = cx + ca * ln / 2, cz + sa * ln / 2 -- east end
			local ya, yb = top, top
			if idx == 1 then
				ax, az = ax - ca * 10, az - sa * 10 -- the west deck lands on the west bank
				ya = groundAt(ax, az) + 0.14
			else
				bx, bz = bx + ca * 10, bz + sa * 10 -- the east deck lands on the east bank
				yb = groundAt(bx, bz) + 0.14
			end
			local pa, pb = V(ax, ya, az), V(bx, yb, bz)
			local deck = board(bm, wd, 0.8, pa, pb, PLANK, M.WoodPlanks, 0, false)
			if deck then
				deck.Name = "ScrapBridgeDeck"
				local frame = CFrame.lookAt((pa + pb) / 2, pb)
				for _, sx in { -1, 1 } do
					local beam = kit.boxCF(bm, 0.9, 1.1, (pb - pa).Magnitude, frame * CFrame.new(sx * (wd / 2 - 1.2), -1.0, 0), RUST, M.CorrodedMetal)
					beam.CastShadow = false
				end
				-- railings in short sections along both edges (H.rail is level, so each section takes its own height)
				local nx, nz = -sa, ca
				local secs = math.max(1, math.floor((pb - pa).Magnitude / 14))
				for sd = -1, 1, 2 do
					for q = 0, secs - 1 do
						local t0, t1 = q / secs, (q + 1) / secs
						local h = ya + (yb - ya) * (t0 + t1) / 2
						local off = sd * (wd / 2 - 0.4)
						H.rail(bm, ax + (bx - ax) * t0 + nx * off, az + (bz - az) * t0 + nz * off, ax + (bx - ax) * t1 + nx * off, az + (bz - az) * t1 + nz * off, h, RUST, M.CorrodedMetal)
					end
				end
				count.bridge += 1
			end
		end
	end)

	-- ── fences: chain-link runs along the reference polylines ────────────────────────────────────────────
	step("fences", function()
		local fm = kit.model("Fences", map)
		local function landF(x, z)
			return insideAt(x, z) and riverD(x, z) < -4
		end
		for _, f in L.fences do
			local pts = f[2]
			for s = 1, #pts / 2 - 1 do
				local ax, az, bx, bz = pts[2 * s - 1], pts[2 * s], pts[2 * s + 1], pts[2 * s + 2]
				for _, rn in landRuns(ax, az, bx, bz, landF) do
					local x0, z0 = ax + (bx - ax) * rn[1], az + (bz - az) * rn[1]
					local x1, z1 = ax + (bx - ax) * rn[2], az + (bz - az) * rn[2]
					if (x1 - x0) * (x1 - x0) + (z1 - z0) * (z1 - z0) > 9 then
						pieces(x0, z0, x1, z1, 36, 12, 0.5, function(px0, pz0, px1, pz1)
							H.fence(fm, px0, pz0, px1, pz1, groundAt(px0, pz0), 7.8, groundAt(px1, pz1))
							count.fence += 1
						end)
					end
				end
			end
			pace()
		end
	end)

	-- ── power lines: lattice pylons where a tower stands inside the map, sagging wires between them ───────
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
		local ATT = { { -13, 40 }, { 13, 40 }, { 0, 47 } }
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
					beam(pm, P(su * base, sv * base, -1), P(su * tip, sv * tip, 46), 1.0)
				end
			end
			local levels = { -1, 12, 26, 38, 46 }
			for q = 1, #levels do
				local y = levels[q]
				local hw = base + (tip - base) * (y + 1) / 47
				if q > 1 then
					beam(pm, P(-hw, -hw, y), P(hw, -hw, y), 0.6)
					beam(pm, P(hw, -hw, y), P(hw, hw, y), 0.6)
					beam(pm, P(hw, hw, y), P(-hw, hw, y), 0.6)
					beam(pm, P(-hw, hw, y), P(-hw, -hw, y), 0.6)
				end
				if q < #levels then
					local yn = levels[q + 1]
					local hn = base + (tip - base) * (yn + 1) / 47
					beam(pm, P(-hw, -hw, y), P(hn, -hn, yn), 0.5)
					beam(pm, P(hw, -hw, y), P(hn, hn, yn), 0.5)
					beam(pm, P(hw, hw, y), P(-hn, hn, yn), 0.5)
					beam(pm, P(-hw, hw, y), P(-hn, -hn, yn), 0.5)
				end
			end
			beam(pm, P(-13, 0, 40), P(13, 0, 40), 0.8)
			beam(pm, P(-4, 0, 47), P(4, 0, 47), 0.7)
			beam(pm, P(0, 0, 46), P(0, 0, 52), 0.6)
			for _, at in ATT do
				beam(pm, P(at[1], 0, at[2]), P(at[1], 0, at[2] - 2.5), 0.5)
			end
			count.pylon += 1
		end
		local function wires(ta, tb)
			local ga = groundAt(ta.x, ta.z)
			local gb = ga
			if insideAt(tb.x, tb.z) then
				gb = groundAt(tb.x, tb.z)
			end
			local PA, PB = frameOf(ta, ga), frameOf(tb, gb)
			local span = math.sqrt((tb.x - ta.x) ^ 2 + (tb.z - ta.z) ^ 2)
			local sag = math.min(14, 0.03 * span)
			for _, at in ATT do
				local A = PA(at[1], 0, at[2] - 2.5)
				local Bp = PB(at[1], 0, at[2] - 2.5)
				local nseg = 10
				local prev = A
				for q = 1, nseg do
					local t = q / nseg
					local p = A:Lerp(Bp, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
					if insideAt(prev.X - O.X, prev.Z - O.Z) or insideAt(p.X - O.X, p.Z - O.Z) then
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
				if best < 4 then
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
				if insideAt(t.x, t.z) then
					pylon(t)
				end
			end
			for q = 1, #list - 1 do
				if insideAt(list[q].x, list[q].z) or insideAt(list[q + 1].x, list[q + 1].z) then
					wires(list[q], list[q + 1])
				end
			end
		end
	end)

	-- ── the boundary: invisible walls along the polygon (the berm and cliff outside is the visible edge) ───
	step("boundary", function()
		local bm = kit.model("Boundary", map)
		bm:SetAttribute("NoWire", true) -- the detail plan would crown long high parts with barbed wire
		local area = 0
		local nb = #BP / 2
		for e = 1, nb do
			local f = (e % nb) + 1
			area += BP[2 * e - 1] * BP[2 * f] - BP[2 * f - 1] * BP[2 * e]
		end
		local sgn = 1
		if area < 0 then
			sgn = -1
		end
		for e = 1, nb do
			local f = (e % nb) + 1
			local ax, az, bx, bz = BP[2 * e - 1], BP[2 * e], BP[2 * f - 1], BP[2 * f]
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

	-- ── forests, bushes and rocks (nature kit) ───────────────────────────────────────────────────────────
	step("nature", function()
		local fm = kit.model("Forest", map)
		local lib = ReplicatedStorage:FindFirstChild("ZR_Assets")
		local function tint(amt)
			local k = 1 - rng:NextNumber(0, amt)
			return Color3.new(k, k, k)
		end
		-- keep-out zones: building footprints (plus 8 studs), extract zones and spawn clusters
		local BLK = {}
		for _, b in L.blds do
			local a = math.rad(b[8])
			table.insert(BLK, { b[4], b[5], math.cos(a), math.sin(a), b[6] / 2 + 8, b[7] / 2 + 8 })
		end
		local SPOTS = {}
		for _, e in L.ext do
			table.insert(SPOTS, { e[4], e[5], 14 })
		end
		for _, side in { L.clusters.east, L.clusters.west } do
			for _, c in side do
				table.insert(SPOTS, { c[1], c[2], 12 })
			end
		end
		local function blocked(x, z)
			for _, q in BLK do
				local dx, dz = x - q[1], z - q[2]
				if math.abs(dx * q[3] + dz * q[4]) < q[5] and math.abs(dz * q[3] - dx * q[4]) < q[6] then
					return true
				end
			end
			for _, s in SPOTS do
				if (x - s[1]) * (x - s[1]) + (z - s[2]) * (z - s[2]) < s[3] * s[3] then
					return true
				end
			end
			return false
		end
		-- open ground a plant may stand on: inside the boundary, on plain or forest floor, clear of water and slopes
		local function okSpot(x, z, maxSlope)
			if not insideAt(x, z) then
				return false
			end
			local c = CL[colOf(x)][rowOf(z)]
			if c > 1 or riverD(x, z) > -14 then
				return false
			end
			return slopeAt(x, z) < maxSlope and not blocked(x, z)
		end

		local TREES = {
			{ t = "ZR_NAT_PineA_T", c = "ZR_NAT_PineA_C", w = 40 },
			{ t = "ZR_NAT_PineB_T", c = "ZR_NAT_PineB_C", w = 30 },
			{ t = "ZR_NAT_PineC_T", c = "ZR_NAT_PineC_C", w = 24, young = true },
			-- birches (Customs mixes them in with the spruce along the roads and the yards)
			{ t = "ZR_NAT_BirchA_T", c = "ZR_NAT_BirchA_C", w = 16 },
			{ t = "ZR_NAT_BirchB_T", c = "ZR_NAT_BirchB_C", w = 12 },
			{ t = "ZR_NAT_Snag_T", w = 5 },
		}
		local wsum = 0
		for _, t in TREES do
			wsum += t.w
		end
		local function tree(x, z)
			if count.tree >= MAXTREE then
				return
			end
			local pick, s, yaw = rng:NextNumber() * wsum, rng:NextNumber(0.82, 1.22), rng:NextNumber(0, 360)
			local kind = TREES[#TREES]
			for _, t in TREES do
				pick -= t.w
				if pick <= 0 then
					kind = t
					break
				end
			end
			local y = groundAt(x, z)
			local tilt = math.min(slopeAt(x, z), 2.7)
			local base = CFrame.new(O.X + x, y - 0.4 - tilt * 1.3 * s, O.Z + z) * CFrame.Angles(0, math.rad(yaw), 0)
			local trunk = H.nat(fm, kind.t, base, s, nil, true)
			if not trunk then
				-- stand-in when the nature kit did not load: a plain trunk and a dark crown
				trunk = kit.vcyl(fm, 24 * s, 1.2 * s, O.X + x, y - 0.4, O.Z + z, hex("4A3B2E"), M.Wood)
				if kind.c then
					local crown = kit.part(fm, Vector3.one * 9 * s, CFrame.new(O.X + x, y + 17 * s, O.Z + z), hex("34482F"), M.LeafyGrass)
					crown.Shape = Enum.PartType.Ball
					crown.CanCollide = false
					crown.CanQuery = false
				end
			else
				-- trees cast no shadow by default; each client lets the trees near its camera cast one (Detail controller)
				trunk.CastShadow = false
				CollectionService:AddTag(trunk, "ZR_TreeShadow")
				if kind.c then
					local tone = tint(0.16)
					if rng:NextNumber() < 0.04 then
						tone = hex("C9A97E")
					end
					local crown = H.nat(fm, kind.c, base, s, tone, false)
					if crown then
						crown.Name = "Crown"
						crown.CastShadow = false
						CollectionService:AddTag(crown, "ZR_TreeShadow")
					end
				end
			end
			trunk.Name = "Trunk"
			trunk:SetAttribute("Wear", "")
			if kind.young then
				-- a young pine's low branches hide what is behind them
				kit.foliage(V(x, y, z), 3.1 * s, y + 1.4 * s, y + 11 * s)
			end
			count.tree += 1
		end
		local function bush(x, z)
			if count.bush >= MAXBUSH then
				return
			end
			local key = "ZR_NAT_Bush1"
			if rng:NextNumber() < 0.55 then
				key = "ZR_NAT_Bush2"
			end
			local s, yaw = rng:NextNumber(1.0, 1.6), rng:NextNumber(0, 360)
			local y = groundAt(x, z)
			local m = H.nat(fm, key, CFrame.new(O.X + x, y - 0.25, O.Z + z) * CFrame.Angles(0, math.rad(yaw), 0), s, tint(0.2), false)
			if m then
				m.Name = "Bush"
				m.CastShadow = false
				kit.foliage(V(x, y, z), math.max(m.Size.X, m.Size.Z) * 0.42, y + 0.3, y + m.Size.Y * 0.95)
				count.bush += 1
			end
		end

		-- forests: a jittered grid inside each polygon, dense (about one tree per 19 x 19 studs), plus bushes between
		local area = 0
		for _, f in L.forests do
			local pts, a2 = f[7], 0
			local n = #pts / 2
			for e = 1, n do
				local g = (e % n) + 1
				a2 += pts[2 * e - 1] * pts[2 * g] - pts[2 * g - 1] * pts[2 * e]
			end
			area += math.abs(a2) / 2
		end
		local gT = math.sqrt(math.max(area, 1) / 560) -- grid spacing for about 560 forest trees
		local gB = math.sqrt(math.max(area, 1) / 480)
		for _, f in L.forests do
			local pts = f[7]
			local minx, maxx, minz, maxz = math.huge, -math.huge, math.huge, -math.huge
			for q = 1, #pts, 2 do
				minx, maxx = math.min(minx, pts[q]), math.max(maxx, pts[q])
				minz, maxz = math.min(minz, pts[q + 1]), math.max(maxz, pts[q + 1])
			end
			local gx = minx
			while gx <= maxx do
				local gz = minz
				while gz <= maxz do
					local x, z = gx + rng:NextNumber(-0.45, 0.45) * gT, gz + rng:NextNumber(-0.45, 0.45) * gT
					if count.tree < 560 and rng:NextNumber() > 0.12 and pointIn(pts, x, z) and okSpot(x, z, 0.6) then
						tree(x, z)
					end
					gz += gT
				end
				gx += gT
			end
			gx = minx + gB / 2
			while gx <= maxx do
				local gz = minz + gB / 2
				while gz <= maxz do
					local x, z = gx + rng:NextNumber(-0.45, 0.45) * gB, gz + rng:NextNumber(-0.45, 0.45) * gB
					if count.bush < 480 and rng:NextNumber() > 0.2 and pointIn(pts, x, z) and okSpot(x, z, 0.6) then
						bush(x, z)
					end
					gz += gB
				end
				gx += gB
			end
			pace()
		end
		-- lone trees and bushes in the open: patchy, never on roads, yards, rails or near buildings
		local lx0, lz0, lx1, lz1 = L.box[1], L.box[2], L.box[3], L.box[4]
		local tries = 0
		while count.tree < MAXTREE and tries < 6000 do
			tries += 1
			local x, z = rng:NextNumber(lx0, lx1), rng:NextNumber(lz0, lz1)
			if math.noise(x / 160 + 5.3, z / 160 + 1.7, 2.2) > -0.05 and CL[colOf(x)][rowOf(z)] == 0 and okSpot(x, z, 0.5) and rng:NextNumber() < 0.5 then
				tree(x, z)
			end
		end
		tries = 0
		while count.bush < 640 and tries < 6000 do
			tries += 1
			local x, z = rng:NextNumber(lx0, lx1), rng:NextNumber(lz0, lz1)
			if CL[colOf(x)][rowOf(z)] == 0 and okSpot(x, z, 0.5) and rng:NextNumber() < 0.4 then
				bush(x, z)
			end
		end
		-- bushes along fences
		tries = 0
		local fenceCount = #L.fences
		while count.bush < 780 and tries < 3000 and fenceCount > 0 do
			tries += 1
			local f = L.fences[rng:NextInteger(1, fenceCount)][2]
			if #f >= 4 then
				local s = rng:NextInteger(1, #f / 2 - 1)
				local t = rng:NextNumber()
				local ax, az, bx, bz = f[2 * s - 1], f[2 * s], f[2 * s + 1], f[2 * s + 2]
				local sd = rng:NextNumber(3, 7) * ((rng:NextNumber() < 0.5) and -1 or 1)
				local l = math.max(0.01, math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az)))
				local x, z = ax + (bx - ax) * t - (bz - az) / l * sd, az + (bz - az) * t + (bx - ax) / l * sd
				if CL[colOf(x)][rowOf(z)] == 0 and okSpot(x, z, 0.5) then
					bush(x, z)
				end
			end
		end
		pace()

		-- rocks: the reference's rocks and outcrops, each a single rock or a cluster by size
		local ROCKS = { "ZR_NAT_Rock1", "ZR_NAT_Rock1", "ZR_NAT_Rock2", "ZR_NAT_Rock3", "ZR_NAT_RockPile" }
		local function rock(x, z, rr)
			local key = ROCKS[rng:NextInteger(1, #ROCKS)]
			local tpl = lib and lib:FindFirstChild(key)
			local y = groundAt(x, z)
			local yaw = rng:NextNumber(0, 360)
			local m = nil
			if tpl then
				local foot = math.max(tpl.Size.X, tpl.Size.Z, 0.5)
				local s = math.clamp(2 * rr / foot, 0.3, 14)
				m = H.nat(fm, key, CFrame.new(O.X + x, y - 0.25 * s, O.Z + z) * CFrame.Angles(0, math.rad(yaw), 0), Vector3.new(s, s * rng:NextNumber(0.7, 1.1), s), tint(0.12), true)
			end
			if not m then
				m = kit.part(fm, Vector3.new(2 * rr, 1.3 * rr, 1.7 * rr), CFrame.new(O.X + x, y + 0.3 * rr, O.Z + z) * CFrame.Angles(0, math.rad(yaw), 0), hex("6B675F"), M.Rock)
			end
			m.Name = "Rock"
			count.rock += 1
		end
		for q = 1, #L.rocks, 3 do
			local x, z, r = L.rocks[q], L.rocks[q + 1], L.rocks[q + 2]
			if insideAt(x, z) and riverD(x, z) < -6 then
				local n = math.clamp(math.floor(r / 7 + 0.5), 1, 8)
				if n == 1 then
					rock(x, z, r)
				else
					rock(x, z, r * 0.5)
					for _ = 2, n do
						local ang, dist = rng:NextNumber(0, 6.2832), rng:NextNumber(0.3, 0.8) * r
						rock(x + math.cos(ang) * dist, z + math.sin(ang) * dist, r * rng:NextNumber(0.22, 0.4))
					end
				end
			end
		end
	end)
end
