--!nonstrict
-- Mall shell, raster helpers (no engine calls, plain Lua): a square-cell grid over the mall's footprint, flat arrays
-- (index = (iz - 1) * nx + ix), polygon and rectangle fills, a rectangle cover of a labelled area, and the walls between
-- neighbouring cells as runs along grid lines. Used by MallPlan.luau; the numbers are map-local studs.
local G = {}

function G.new(x0, z0, x1, z1, cell)
	local nx = math.ceil((x1 - x0) / cell - 1e-6)
	local nz = math.ceil((z1 - z0) / cell - 1e-6)
	return { x0 = x0, z0 = z0, cell = cell, nx = nx, nz = nz, n = nx * nz }
end

function G.array(g, v)
	return table.create(g.n, v)
end

-- left edge of column ix / top edge of row iz (also the grid line coordinates, ix 1..nx + 1)
function G.x(g, ix)
	return g.x0 + (ix - 1) * g.cell
end
function G.z(g, iz)
	return g.z0 + (iz - 1) * g.cell
end
-- column / row whose cell holds the coordinate (not clamped)
function G.col(g, x)
	return math.floor((x - g.x0) / g.cell) + 1
end
function G.row(g, z)
	return math.floor((z - g.z0) / g.cell) + 1
end
-- nearest grid line index to a coordinate
function G.lineX(g, x)
	return math.floor((x - g.x0) / g.cell + 0.5) + 1
end
function G.lineZ(g, z)
	return math.floor((z - g.z0) / g.cell + 0.5) + 1
end

-- fill the cells whose centre lies inside the polygon (flat list x, z, x, z ...; even-odd) with v; `only` is an optional set
-- of the values that may be overwritten. Returns the number of cells set.
function G.poly(g, a, pts, v, only)
	local np = math.floor(#pts / 2)
	if np < 3 then
		return 0
	end
	local nx, nz, c = g.nx, g.nz, g.cell
	local xs = {}
	for i = 1, np do
		local j = i % np + 1
		local xa, za, xb, zb = pts[2 * i - 1], pts[2 * i], pts[2 * j - 1], pts[2 * j]
		if za ~= zb then
			if za > zb then
				xa, za, xb, zb = xb, zb, xa, za
			end
			local r0 = math.max(1, math.ceil((za - g.z0) / c + 0.5))
			local r1 = math.min(nz, math.ceil((zb - g.z0) / c + 0.5) - 1)
			local k = (xb - xa) / (zb - za)
			for iz = r0, r1 do
				local zc = g.z0 + (iz - 0.5) * c
				local lst = xs[iz]
				if not lst then
					lst = {}
					xs[iz] = lst
				end
				lst[#lst + 1] = xa + (zc - za) * k
			end
		end
	end
	local cnt = 0
	for iz = 1, nz do
		local lst = xs[iz]
		if lst then
			table.sort(lst)
			local base = (iz - 1) * nx
			for q = 1, #lst - 1, 2 do
				local i0 = math.max(1, math.ceil((lst[q] - g.x0) / c + 0.5))
				local i1 = math.min(nx, math.ceil((lst[q + 1] - g.x0) / c + 0.5) - 1)
				for ix = i0, i1 do
					local k2 = base + ix
					if not only or only[a[k2]] then
						a[k2] = v
						cnt += 1
					end
				end
			end
		end
	end
	return cnt
end

-- fill the cells whose centre lies in x0 <= x < x1, z0 <= z < z1
function G.rect(g, a, x0, z0, x1, z1, v, only)
	local c = g.cell
	local i0 = math.max(1, math.ceil((x0 - g.x0) / c + 0.5 - 1e-9))
	local i1 = math.min(g.nx, math.ceil((x1 - g.x0) / c + 0.5 - 1e-9) - 1)
	local j0 = math.max(1, math.ceil((z0 - g.z0) / c + 0.5 - 1e-9))
	local j1 = math.min(g.nz, math.ceil((z1 - g.z0) / c + 0.5 - 1e-9) - 1)
	local cnt = 0
	for iz = j0, j1 do
		local base = (iz - 1) * g.nx
		for ix = i0, i1 do
			local k = base + ix
			if not only or only[a[k]] then
				a[k] = v
				cnt += 1
			end
		end
	end
	return cnt
end

-- count the cells of a rectangle whose value is in the set `which` (or any value when nil)
function G.count(g, a, x0, z0, x1, z1, which)
	local c = g.cell
	local i0 = math.max(1, math.ceil((x0 - g.x0) / c + 0.5 - 1e-9))
	local i1 = math.min(g.nx, math.ceil((x1 - g.x0) / c + 0.5 - 1e-9) - 1)
	local j0 = math.max(1, math.ceil((z0 - g.z0) / c + 0.5 - 1e-9))
	local j1 = math.min(g.nz, math.ceil((z1 - g.z0) / c + 0.5 - 1e-9) - 1)
	local cnt = 0
	for iz = j0, j1 do
		local base = (iz - 1) * g.nx
		for ix = i0, i1 do
			if not which or which[a[base + ix]] then
				cnt += 1
			end
		end
	end
	return cnt
end

-- cover the cells of a class array (0 or nil = nothing) with rectangles of one class: rows are scanned top to bottom and a
-- run is merged into the rectangle above it when both its ends match. Returns { x0, z0, x1, z1, k } in studs.
function G.cover(g, cls)
	local nx, nz = g.nx, g.nz
	local out = {}
	local open = {}
	for iz = 1, nz + 1 do
		local nextOpen = {}
		if iz <= nz then
			local base = (iz - 1) * nx
			local ix = 1
			while ix <= nx do
				local k = cls[base + ix]
				if k and k ~= 0 then
					local jx = ix
					while jx < nx and cls[base + jx + 1] == k do
						jx += 1
					end
					local key = ix .. ":" .. jx .. ":" .. k
					local r = open[key]
					if r then
						r.iz1 = iz
						open[key] = nil
					else
						r = { ix0 = ix, ix1 = jx, iz0 = iz, iz1 = iz, k = k }
						out[#out + 1] = r
					end
					nextOpen[key] = r
					ix = jx + 1
				else
					ix += 1
				end
			end
		end
		open = nextOpen
	end
	for _, r in out do
		r.x0 = g.x0 + (r.ix0 - 1) * g.cell
		r.x1 = g.x0 + r.ix1 * g.cell
		r.z0 = g.z0 + (r.iz0 - 1) * g.cell
		r.z1 = g.z0 + r.iz1 * g.cell
	end
	return out
end

-- the walls between neighbouring cells. edge(a, b, ia, ib, vertical, ix, iz) gets the labels of the two cells (a = west or north,
-- b = east or south; 0 outside the grid) and returns nil (no wall) or an info table; tables returned for the same kind of
-- edge must be the same table (runs merge by identity). Wall edges (info.wall) mark their end vertices so that corners can be
-- joined. Returns { v = runs along z on x-lines, h = runs along x on z-lines }, each run
-- { info, line (grid line index), i0, i1 (first and last cell along the line), x0, z0, x1, z1 (the line's extent, studs) }.
-- Horizontal runs are cut where a vertical wall touches the line; `ext0` / `ext1` tell how far a run is lengthened at its
-- ends: vertical runs reach half a thickness past a vertex where a horizontal wall touches, horizontal runs stop half a
-- thickness short of a vertical wall.
function G.walls(g, lab, edge)
	local nx, nz = g.nx, g.nz
	local W1 = nx + 1
	local ev, eh = {}, {} -- ev[(iz - 1) * W1 + ix]: edge on x-line ix, row iz; eh[(iz - 1) * nx + ix]: edge on z-line iz, column ix
	local fl, vt = {}, {} -- per vertex (iz - 1) * W1 + ix: bit flags N 1, S 2, W 4, E 8; widest vertical wall thickness there
	local function has(f, bit)
		return math.floor((f or 0) / bit) % 2 == 1
	end
	local function mark(vid, bit, t)
		if not has(fl[vid], bit) then
			fl[vid] = (fl[vid] or 0) + bit
		end
		if bit <= 2 then
			if not vt[vid] or vt[vid] < t then
				vt[vid] = t
			end
		end
	end
	for iz = 1, nz do
		local base = (iz - 1) * nx
		for ix = 1, nx + 1 do
			local ia = ix > 1 and lab[base + ix - 1] or 0
			local ib = ix <= nx and lab[base + ix] or 0
			if ia ~= ib then
				local info = edge(ia, ib, base + ix - 1, base + ix, true, ix, iz)
				if info then
					ev[(iz - 1) * W1 + ix] = info
					if info.wall then
						mark((iz - 1) * W1 + ix, 2, info.t)
						mark(iz * W1 + ix, 1, info.t)
					end
				end
			end
		end
	end
	for iz = 1, nz + 1 do
		for ix = 1, nx do
			local ia = iz > 1 and lab[(iz - 2) * nx + ix] or 0
			local ib = iz <= nz and lab[(iz - 1) * nx + ix] or 0
			if ia ~= ib then
				local info = edge(ia, ib, (iz - 2) * nx + ix, (iz - 1) * nx + ix, false, ix, iz)
				if info then
					eh[(iz - 1) * nx + ix] = info
					if info.wall then
						mark((iz - 1) * W1 + ix, 8, info.t)
						mark((iz - 1) * W1 + ix + 1, 4, info.t)
					end
				end
			end
		end
	end
	local runsV, runsH = {}, {}
	-- vertical runs: along z on each x-line
	for ix = 1, nx + 1 do
		local cur = nil
		for iz = 1, nz + 1 do
			local info = iz <= nz and ev[(iz - 1) * W1 + ix] or nil
			if cur and cur.info == info then
				cur.i1 = iz
			else
				if cur then
					runsV[#runsV + 1] = cur
				end
				cur = nil
				if info then
					cur = { info = info, line = ix, i0 = iz, i1 = iz }
				end
			end
		end
	end
	-- horizontal runs: along x on each z-line, cut at vertices where a vertical wall touches
	for iz = 1, nz + 1 do
		local cur = nil
		for ix = 1, nx + 1 do
			local info = ix <= nx and eh[(iz - 1) * nx + ix] or nil
			local cut = false
			if cur and ix > cur.i0 then
				local f = fl[(iz - 1) * W1 + ix]
				cut = has(f, 1) or has(f, 2)
			end
			if cur and cur.info == info and not cut then
				cur.i1 = ix
			else
				if cur then
					runsH[#runsH + 1] = cur
				end
				cur = nil
				if info then
					cur = { info = info, line = iz, i0 = ix, i1 = ix }
				end
			end
		end
	end
	local c = g.cell
	for _, r in runsV do
		local x = g.x0 + (r.line - 1) * c
		r.x0, r.x1 = x, x
		r.z0, r.z1 = g.z0 + (r.i0 - 1) * c, g.z0 + r.i1 * c
		r.ext0, r.ext1 = 0, 0
		if r.info.wall then
			local ft = fl[(r.i0 - 1) * W1 + r.line]
			local fb = fl[r.i1 * W1 + r.line]
			if has(ft, 4) or has(ft, 8) then
				r.ext0 = r.info.t / 2
			end
			if has(fb, 4) or has(fb, 8) then
				r.ext1 = r.info.t / 2
			end
		end
	end
	for _, r in runsH do
		local z = g.z0 + (r.line - 1) * c
		r.z0, r.z1 = z, z
		r.x0, r.x1 = g.x0 + (r.i0 - 1) * c, g.x0 + r.i1 * c
		r.ext0, r.ext1 = 0, 0
		if r.info.wall then
			local fa = fl[(r.line - 1) * W1 + r.i0]
			local fb = fl[(r.line - 1) * W1 + r.i1 + 1]
			if has(fa, 1) or has(fa, 2) then
				r.ext0 = -(vt[(r.line - 1) * W1 + r.i0] or 0) / 2
			end
			if has(fb, 1) or has(fb, 2) then
				r.ext1 = -(vt[(r.line - 1) * W1 + r.i1 + 1] or 0) / 2
			end
		end
	end
	return { v = runsV, h = runsH }
end

return G
