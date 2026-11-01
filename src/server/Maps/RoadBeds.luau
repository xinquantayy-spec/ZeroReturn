-- Road beds for the terrain maps (Border Yard, Meridian Mall). Shared by both Ground builders.
--
-- RoadBeds.profile: the height along a road, sampled every 4 studs and averaged over about 30 (two passes of +-16).
-- RoadBeds.bed: the last word on the ground under the roads. Across every road the ground lies flat at the road's
-- profile height out to a stud past the edge, then blends back over 8 studs.
--
-- Why (road audit, 2026-11-02). The grading ran a road straight between its vertices, and Border's main_0 has three
-- vertices over 2,000 studs. It cut a trench up to 10 studs deep, with the fuel stop 20 studs above the road. Pads,
-- rock mounds, pits and the river came after the grading and tilted the beds again. The banks stood up to 9 studs over
-- road edges, the asphalt boards were buried under them, and short boards stepped up and down the slopes. From a roof or
-- a hill the roads looked broken.
--
-- Roads go widest first: a narrower road leaves a wider one's bed alone and meets it at its height. Samples by a rail
-- keep their height, so level crossings stay level with the track.
local RoadBeds = {}

local STEP, BLEND = 4, 8

-- cumulative length at each vertex, the total, and the point at arc length `arc` (with its segment)
local function arcs(pts)
	local n = #pts / 2
	local cum = { 0 }
	for s = 1, n - 1 do
		cum[s + 1] = cum[s] + math.sqrt((pts[2 * s + 1] - pts[2 * s - 1]) ^ 2 + (pts[2 * s + 2] - pts[2 * s]) ^ 2)
	end
	return cum, math.max(cum[n], 1e-6)
end

-- the profile of a polyline: { cum, total, m, h } where h[1..m] are heights every total/(m-1) studs.
-- sample(x, z, j) gives the raw height; fixed(j) true keeps a sample out of the averaging (it still counts for its
-- neighbours); skip(j) true leaves it out of its neighbours' averages (a sample in the river).
function RoadBeds.profile(pts, sample, fixed, skip)
	local cum, total = arcs(pts)
	local n = #pts / 2
	local m = math.max(2, math.floor(total / STEP) + 1)
	local h, xs, zs = table.create(m, 0), table.create(m, 0), table.create(m, 0)
	local s = 1
	for j = 1, m do
		local arc = total * (j - 1) / (m - 1)
		while s < n - 1 and cum[s + 1] < arc do
			s += 1
		end
		local t = math.clamp((arc - cum[s]) / math.max(cum[s + 1] - cum[s], 1e-6), 0, 1)
		local x = pts[2 * s - 1] + (pts[2 * s + 1] - pts[2 * s - 1]) * t
		local z = pts[2 * s] + (pts[2 * s + 2] - pts[2 * s]) * t
		xs[j], zs[j] = x, z
		h[j] = sample(x, z, j)
	end
	local fix, off = table.create(m, false), table.create(m, false)
	for j = 1, m do
		fix[j] = fixed and fixed(xs[j], zs[j]) or false
		off[j] = skip and skip(xs[j], zs[j]) or false
	end
	for _ = 1, 2 do
		local nxt = table.clone(h)
		for j = 1, m do
			if not fix[j] and not off[j] then
				local sw, sh = 0, 0
				for q = math.max(1, j - 4), math.min(m, j + 4) do
					if not off[q] then
						sw += 1
						sh += h[q]
					end
				end
				if sw > 0 then
					nxt[j] = sh / sw
				end
			end
		end
		h = nxt
	end
	return { cum = cum, total = total, m = m, h = h }
end

-- the profile's height at segment s, position t (0..1) along it
function RoadBeds.at(pr, s, t)
	local f = (pr.cum[s] + t * (pr.cum[s + 1] - pr.cum[s])) / pr.total * (pr.m - 1) + 1
	local j0 = math.clamp(math.floor(f), 1, pr.m - 1)
	return pr.h[j0] + (pr.h[j0 + 1] - pr.h[j0]) * math.clamp(f - j0, 0, 1)
end

-- g: {
--   roads = L.roads ({ id, surf, w, pts }), rails = { pts, ... } (polylines that pin the profile within 10 studs),
--   HG, groundAt, eachNear, colOf, rowOf, xAt, zAt, smooth, pace,
--   keep = { [i * 1024 + k] = true } columns never changed (building footprints),
--   open(i, k) -> true where the bed may change the column (inside the map, on land),
--   wet(x, z) -> true for a profile sample off land (left out of the averages),
-- }
-- Returns the number of columns moved by more than 0.05 studs.
function RoadBeds.bed(g)
	local HG, groundAt, eachNear, colOf, rowOf, smooth = g.HG, g.groundAt, g.eachNear, g.colOf, g.rowOf, g.smooth
	local railNear = {}
	for _, pts in g.rails or {} do
		eachNear(pts, 10, function(i, k)
			railNear[i * 1024 + k] = true
		end)
	end
	local order = table.clone(g.roads)
	table.sort(order, function(p, q)
		if p[3] ~= q[3] then
			return p[3] > q[3]
		end
		return tostring(p[1]) < tostring(q[1])
	end)
	local core, changed = {}, 0
	for _, rd in order do
		local pts, halfW = rd[4], rd[3] / 2 + 1
		local pr = RoadBeds.profile(pts, function(x, z)
			return groundAt(x, z)
		end, function(x, z)
			local key = colOf(x) * 1024 + rowOf(z)
			return (core[key] or railNear[key]) and true or false
		end, g.wet)
		local gw, gh, gm = {}, {}, {}
		eachNear(pts, halfW + BLEND, function(i, k, d, t, s)
			local key = i * 1024 + k
			if core[key] or (g.keep and g.keep[key]) or not g.open(i, k) then
				return
			end
			local wgt = 1 - smooth((d - halfW) / BLEND)
			local w3 = wgt * wgt * wgt
			gw[key] = (gw[key] or 0) + w3
			gh[key] = (gh[key] or 0) + w3 * RoadBeds.at(pr, s, t)
			if wgt > (gm[key] or 0) then
				gm[key] = wgt
			end
		end)
		local cores = {}
		for key, wsum in gw do
			if wsum > 1e-6 then
				local i = math.floor(key / 1024)
				local k = key - i * 1024
				local col = HG[i]
				local nv = col[k] + (gh[key] / wsum - col[k]) * gm[key]
				if math.abs(nv - col[k]) > 0.05 then
					changed += 1
				end
				col[k] = nv
				if gm[key] >= 0.999 then
					table.insert(cores, key)
				end
			end
		end
		for _, key in cores do
			core[key] = true
		end
		if g.pace then
			g.pace()
		end
	end
	return changed
end

return RoadBeds
