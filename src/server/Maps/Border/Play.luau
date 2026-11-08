--!nonstrict
-- Border Yard play layer (the gameplay agent, part 3 of 3): everything a raid needs on top of Ground and Buildings.
--   extracts       all 26 reference extracts at their positions with the reference rules and our names, W.sideExtracts
--   spawns         six outdoor groups per PMC half (12 in all), each at the reference spawn point with the most room
--   AI             W.patrols (six guard routes), W.watchPosts, W.scavZones (the reference's points by area density, the
--                  ones inside buildings moved to the open ground beside them, plus the dorms, the stores, the trailer
--                  lot, Red Stores, the old pumps and the shops), W.boss (THE BROKER: the dorms, four guards)
--   quests         W.visitZones: DORM314, BOILER, DERRICK, FRAME, SMUGGLERS
--   hazards        the border snipers over the reference's sniper quad (walking the rails to NORTH LINE is safe: the
--                  1.2.0.0 change), propane cylinders on open ground
--   loose loot     yards, the pump platforms, the scrap bridge landings (Dress adds a spot at each wreck)
--   mounted guns   two on the roof of the Bastion, each with a gunner posted behind it (Stationary.luau)
-- Buildings publish named standing points in B.points (BLOCK_A_LOBBY ...); each one used here falls back to the matching
-- footprint centre in L.blds when it is missing. Local coordinates (x east, z south), world positions through H.V.
-- B.geo: the geometry tests below (footprints, roads, fences, rails, forests, keep-outs, part boxes) for Dress.
-- The mounted guns (docs/maps/BORDER_YARD.md, Gameplay) are the Bastion's roof nests: Tarkov has stationary weapons on Customs
-- but no source gives where, so the roof of the scav base is our choice (docs/design/STATIONARY_WEAPONS.md).
return function(B)
	local kit, W, H, L, map = B.kit, B.W, B.H, B.L, B.map
	local V = H.V
	local O = B.O
	local ground = B.ground
	local inside = B.inside or function()
		return true
	end
	local riverD = B.riverD or function()
		return -999
	end
	local slopeAt = B.slope or function()
		return 0
	end
	local okH, Hazards = pcall(function()
		return require(script.Parent.Parent.Parent:WaitForChild("Services"):WaitForChild("Hazards"))
	end)
	if not okH then
		warn("[ZR] Border play: no Hazards service: " .. tostring(Hazards))
		Hazards = nil
	end
	local rng = Random.new(9907)
	local nSpawn, nPropane, nStrip, nLoose = 0, 0, 0, 0

	local function try(name, f)
		local ok, err = pcall(f)
		if not ok then
			warn("[ZR] Border play: " .. name .. " failed: " .. tostring(err))
		end
	end

	-- ── extracts: the five underground exits stand on their room's floor, the rest on the ground ────────────
	W.sideExtracts = { east = {}, west = {} }
	W.patrols = {}
	try("extracts", function()
		local UNDER = { K11 = true, SH = true, OP = true, K13 = true, BC = true }
		local floorOf = {}
		for _, u in L.under do
			floorOf[u[1]] = u[9]
		end
		local ex = kit.model("Extracts", map)
		local sideIds = { east = {}, west = {} }
		for _, e in L.ext do
			local id, name, grp, x, z = e[1], e[2], e[3], e[4], e[5]
			local y, opts = ground(x, z), nil
			if UNDER[id] and floorOf[id] then
				y, opts = floorOf[id] + 0.1, { compact = true }
			end
			kit.extract(ex, id, name, V(x, y, z), Vector3.new(e[6], e[7], e[8]), table.clone(e[9]), opts)
			if grp == "east" or grp == "both" then
				table.insert(sideIds.east, id)
			end
			if grp == "west" or grp == "both" then
				table.insert(sideIds.west, id)
			end
		end
		W.sideExtracts = sideIds
	end)

	-- SMUGGLERS' BOAT: Tarkov's exit is a smugglers' motorboat moored on the river bank. The beacon alone stood on the
	-- slope, so a small open motorboat now lies in the water off the west bank beside it, tied to a post on the bank.
	try("smugglers' boat", function()
		local riverAt = B.riverAt
		local sb = nil
		for _, e in L.ext do
			if e[1] == "SB" then
				sb = e
			end
		end
		if not (riverAt and sb) then
			return
		end
		local bz = sb[5] - 18
		local xl, _, wy = riverAt(bz)
		local bx = xl + 5
		local m = kit.model("SmugglersBoat", map)
		-- the hull's own frame: x across, z along (bow toward -z), y from the waterline
		local base = CFrame.new(V(bx, wy, bz))
		local HULL, TRIM, DARK = kit.hex("D8D4C8"), kit.hex("3F5B6E"), kit.hex("2E3134")
		local function blk(sx, sy, sz, cf, col, mat)
			local p = kit.boxCF(m, sx, sy, sz, base * cf, col, mat)
			p.CastShadow = false
			return p
		end
		local L0, Wd, Hh = 12, 4.6, 1.9 -- the straight part of the hull, its beam and its side height (0.5 below the water)
		-- the deck lies just over the water: terrain water fills anything below it
		blk(Wd, 0.3, L0, CFrame.new(0, -0.05, 0), HULL, Enum.Material.SmoothPlastic)
		for _, sg in { -1, 1 } do
			blk(0.25, Hh, L0, CFrame.new(sg * (Wd / 2 - 0.125), Hh / 2 - 0.5, 0), HULL, Enum.Material.SmoothPlastic)
			blk(0.3, 0.25, L0, CFrame.new(sg * (Wd / 2 - 0.1), Hh - 0.4, 0), TRIM, Enum.Material.SmoothPlastic)
			-- the bow: two sides meeting 4 studs ahead of the straight part
			local side = (Vector3.new(0, 0, -L0 / 2 - 4) - Vector3.new(sg * (Wd / 2 - 0.125), 0, -L0 / 2))
			local mid = Vector3.new(sg * (Wd / 2 - 0.125), 0, -L0 / 2) + side / 2
			blk(0.25, Hh, side.Magnitude, CFrame.lookAt(mid, mid + side) * CFrame.new(0, Hh / 2 - 0.5, 0), HULL, Enum.Material.SmoothPlastic)
		end
		blk(Wd, Hh, 0.25, CFrame.new(0, Hh / 2 - 0.5, L0 / 2 - 0.125), HULL, Enum.Material.SmoothPlastic) -- the transom
		blk(Wd - 0.6, 0.25, 1.4, CFrame.new(0, 0.85, 1.2), kit.hex("6E5C48"), Enum.Material.WoodPlanks) -- a bench
		blk(1.6, 1.2, 1.0, CFrame.new(0.9, 0.7, -1.4), TRIM, Enum.Material.SmoothPlastic) -- the console
		blk(1.5, 0.12, 0.7, CFrame.new(0.9, 1.4, -1.85) * CFrame.Angles(math.rad(-30), 0, 0), kit.hex("8FA3AA"), Enum.Material.Glass).Transparency = 0.5
		-- the outboard motor over the transom
		blk(1.1, 1.4, 1.3, CFrame.new(0, 1.2, L0 / 2 + 0.6), DARK, Enum.Material.Metal)
		blk(0.35, 1.8, 0.35, CFrame.new(0, -0.2, L0 / 2 + 0.75), DARK, Enum.Material.Metal)
		-- jerry cans and a tarp-covered load (the smugglers' goods)
		blk(1.0, 1.1, 0.6, CFrame.new(-1.2, 0.65, 3.6), kit.hex("6B3A2E"), Enum.Material.Plastic)
		blk(2.6, 0.9, 2.2, CFrame.new(-0.5, 0.55, -3.6), kit.hex("4B5440"), Enum.Material.Fabric)
		-- tied to a post on the bank
		local post = V(xl - 3, ground(xl - 3, bz - 2), bz - 2)
		local pp = kit.boxCF(m, 0.6, 3.2, 0.6, CFrame.new(post + Vector3.new(0, 1.2, 0)), kit.hex("4A3D30"), Enum.Material.Wood)
		pp.CastShadow = false
		local bow = (base * CFrame.new(-Wd / 2 + 0.3, Hh - 0.5, -L0 / 2 + 1)).Position
		local top = post + Vector3.new(0, 2.3, 0)
		local rope = kit.boxCF(m, 0.12, 0.12, (bow - top).Magnitude, CFrame.lookAt((bow + top) / 2, bow), kit.hex("9A8F78"), Enum.Material.Fabric)
		rope.CanCollide = false
		rope.CastShadow = false
	end)

	-- ── geometry (Dress uses it too, as B.geo) ────────────────────────────────────────────────────────────
	local G = { kp = {}, ks = {} }
	B.geo = G
	local NOOPT = {}
	local function segD(px, pz, ax, az, bx, bz)
		local dx, dz = bx - ax, bz - az
		local l2 = dx * dx + dz * dz
		local t = 0
		if l2 > 1e-9 then
			t = math.clamp(((px - ax) * dx + (pz - az) * dz) / l2, 0, 1)
		end
		local ex, ez = px - (ax + dx * t), pz - (az + dz * t)
		return math.sqrt(ex * ex + ez * ez)
	end
	local function inPoly(p, x, z)
		local inn, j = false, #p - 1
		for i = 1, #p - 1, 2 do
			local ax, az, bx, bz = p[i], p[i + 1], p[j], p[j + 1]
			if (az > z) ~= (bz > z) and x < (bx - ax) * (z - az) / (bz - az) + ax then
				inn = not inn
			end
			j = i
		end
		return inn
	end
	local function polyDist(p, x, z) -- distance to a flat x, z outline, negative inside
		local best, n = math.huge, #p
		for i = 1, n - 1, 2 do
			local k = i + 2
			if k > n then
				k = 1
			end
			local d = segD(x, z, p[i], p[i + 1], p[k], p[k + 1])
			if d < best then
				best = d
			end
		end
		if inPoly(p, x, z) then
			return -best
		end
		return best
	end
	G.segD, G.inPoly, G.polyDist = segD, inPoly, polyDist

	-- building footprints (rotated rectangles, or the traced outline of a concave building)
	local bl, byId = {}, {}
	for _, b in L.blds do
		local r = math.rad(b[8])
		local e = { id = b[1], name = b[2], kind = b[3], cx = b[4], cz = b[5], hw = b[6] / 2, hd = b[7] / 2, c = math.cos(r), s = math.sin(r), floors = b[9], h = b[10], poly = L.outline[b[1]] }
		e.rad = math.sqrt(e.hw * e.hw + e.hd * e.hd) + 4
		table.insert(bl, e)
		byId[e.id] = e
	end
	G.byId = byId
	local function rectDist(r, x, z) -- signed distance to a rotated rectangle
		local dx, dz = x - r.cx, z - r.cz
		local u, v = dx * r.c + dz * r.s, -dx * r.s + dz * r.c
		local qx, qz = math.abs(u) - r.hw, math.abs(v) - r.hd
		if qx > 0 and qz > 0 then
			return math.sqrt(qx * qx + qz * qz)
		end
		return math.max(qx, qz)
	end
	function G.bldDist(x, z) -- studs to the nearest footprint (negative inside) and that building
		local best, who = math.huge, nil
		for _, b in bl do
			local dx, dz = x - b.cx, z - b.cz
			if math.sqrt(dx * dx + dz * dz) - b.rad < best then
				local d
				if b.poly then
					d = polyDist(b.poly, x, z)
				else
					d = rectDist(b, x, z)
				end
				if d < best then
					best, who = d, b
				end
			end
		end
		return best, who
	end

	-- polylines with their bounding boxes: roads (half width), fences, rails (bed and embankment as half width)
	local function lineSet(rows, pIdx, hwOf, tagOf)
		local set = {}
		for _, row in rows do
			local p = row[pIdx]
			if p and #p >= 4 then
				local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
				for i = 1, #p - 1, 2 do
					x0, x1 = math.min(x0, p[i]), math.max(x1, p[i])
					z0, z1 = math.min(z0, p[i + 1]), math.max(z1, p[i + 1])
				end
				local hw = hwOf(row)
				table.insert(set, { p = p, hw = hw, tag = tagOf(row), x0 = x0 - hw, z0 = z0 - hw, x1 = x1 + hw, z1 = z1 + hw })
			end
		end
		return set
	end
	local function lineDist(set, x, z, lim) -- distance to the nearest edge of the set (negative on it), and its tag
		local best, tag = math.huge, nil
		for _, ln in set do
			if x > ln.x0 - lim and x < ln.x1 + lim and z > ln.z0 - lim and z < ln.z1 + lim then
				local p = ln.p
				for i = 1, #p - 3, 2 do
					local d = segD(x, z, p[i], p[i + 1], p[i + 2], p[i + 3]) - ln.hw
					if d < best then
						best, tag = d, ln.tag
					end
				end
			end
		end
		return best, tag
	end
	local roadSet = lineSet(L.roads, 4, function(r)
		return r[3] / 2
	end, function(r)
		return r[2]
	end)
	local fenceSet = lineSet(L.fences, 2, function()
		return 0
	end, function(r)
		return r[1]
	end)
	local railSet = lineSet(L.rails, 3, function(r)
		return 4 + (r[2] or 0) * 1.5
	end, function(r)
		return r[1]
	end)
	function G.roadEdge(x, z) -- studs from the nearest road's edge (negative on a road) and its surface letter
		return lineDist(roadSet, x, z, 40)
	end
	function G.fenceDist(x, z)
		return (lineDist(fenceSet, x, z, 30))
	end
	function G.railEdge(x, z)
		return (lineDist(railSet, x, z, 30))
	end

	-- forests (the trees stand inside the polygons), rocks, shafts and open underground rooms
	local fo = {}
	for _, f in L.forests do
		if f[7] and #f[7] >= 6 then
			table.insert(fo, { p = f[7], cx = f[2], cz = f[3], rad = math.sqrt(f[4] * f[4] + f[5] * f[5]) / 2 + 12 })
		end
	end
	function G.inForest(x, z, margin)
		for _, f in fo do
			local dx, dz = x - f.cx, z - f.cz
			local rr = f.rad + margin
			if dx * dx + dz * dz < rr * rr then
				if inPoly(f.p, x, z) or (margin > 0 and polyDist(f.p, x, z) < margin) then
					return true
				end
			end
		end
		return false
	end
	local vo = {}
	local function addVoid(cx, cz, w, d, rot)
		local r = math.rad(rot)
		table.insert(vo, { cx = cx, cz = cz, hw = w / 2, hd = d / 2, c = math.cos(r), s = math.sin(r) })
	end
	for _, s in L.stairs do
		if s[2] == 0 then
			addVoid(s[3], s[4], s[5], s[6], s[7])
		end
	end
	for _, u in L.under do
		if u[11] == 1 then
			addVoid(u[4], u[5], u[6], u[7], u[8])
		end
	end
	function G.voidDist(x, z)
		local best = math.huge
		for _, r in vo do
			best = math.min(best, rectDist(r, x, z))
		end
		return best
	end
	function G.rockNear(x, z, pad)
		local rk = L.rocks
		for i = 1, #rk - 2, 3 do
			local dx, dz = x - rk[i], z - rk[i + 1]
			local rr = rk[i + 2] + pad
			if dx * dx + dz * dz < rr * rr then
				return true
			end
		end
		return false
	end

	local box = L.box
	function G.inside(x, z)
		return x > box[1] and x < box[3] and z > box[2] and z < box[4] and inside(x, z)
	end
	function G.edge(x, z) -- studs inside the playable boundary (negative outside)
		return -polyDist(L.boundary, x, z)
	end

	-- open ground: inside the boundary, dry, clear of footprints, fences, rails, forests and shafts. o: bld, edge, river,
	-- road (minimum studs from a road's edge; nil allows roads), fence, rail, forest
	function G.open(x, z, o)
		o = o or NOOPT
		if not G.inside(x, z) then
			return false
		end
		if riverD(x, z) > -(o.river or 10) then
			return false
		end
		if G.bldDist(x, z) < (o.bld or 8) then
			return false
		end
		if G.edge(x, z) < (o.edge or 14) then
			return false
		end
		if o.road and G.roadEdge(x, z) < o.road then
			return false
		end
		if G.fenceDist(x, z) < (o.fence or 3) then
			return false
		end
		if G.railEdge(x, z) < (o.rail or 6) then
			return false
		end
		if G.inForest(x, z, o.forest or 2) then
			return false
		end
		if G.voidDist(x, z) < 5 then
			return false
		end
		return true
	end
	-- the nearest point to (x, z) that passes test (default: open with o), searched in rings up to r studs
	function G.snap(x, z, r, o, test)
		local ok = test or function(px, pz)
			return G.open(px, pz, o)
		end
		if ok(x, z) then
			return x, z
		end
		local ring = 4
		while ring <= (r or 40) do
			local n = math.max(8, math.floor(ring * 1.3))
			for k = 0, n - 1 do
				local a = k / n * math.pi * 2
				local px, pz = x + math.cos(a) * ring, z + math.sin(a) * ring
				if ok(px, pz) then
					return px, pz
				end
			end
			ring += 4
		end
		return nil
	end

	-- keep-outs (gameplay): circles and route segments that clutter must stay away from
	function G.keep(x, z, r)
		table.insert(G.kp, { x, z, r })
	end
	function G.keepSeg(ax, az, bx, bz, r)
		table.insert(G.ks, { ax, az, bx, bz, r })
	end
	function G.blocked(x, z, rq)
		for _, k in G.kp do
			local dx, dz = k[1] - x, k[2] - z
			local rr = k[3] + rq
			if dx * dx + dz * dz < rr * rr then
				return true
			end
		end
		for _, s in G.ks do
			if segD(x, z, s[1], s[2], s[3], s[4]) < s[5] + rq then
				return true
			end
		end
		return false
	end

	-- solid parts of the map in 32-stud buckets (flat road and floor pieces left out), built on first use; boxes
	-- placed later are added with G.addBox so nothing overlaps
	local CELL, buckets = 32, nil
	local function addToBuckets(lo, hi)
		local bx = { lo, hi }
		for cx = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
			for cz = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
				local k = cx * 4096 + cz
				local list = buckets[k]
				if not list then
					list = {}
					buckets[k] = list
				end
				table.insert(list, bx)
			end
		end
	end
	local function ensureBuckets()
		if buckets then
			return
		end
		buckets = {}
		for _, p in map:GetDescendants() do
			if p:IsA("BasePart") and ((p.CanCollide and p.Transparency < 1) or p.Name == "KitCollider") then
				local cf, sz = p.CFrame, p.Size
				local e = ((cf.RightVector * sz.X):Abs() + (cf.UpVector * sz.Y):Abs() + (cf.LookVector * sz.Z):Abs()) / 2
				local pos = cf.Position
				if pos.Y + e.Y > ground(pos.X - O.X, pos.Z - O.Z) + 0.8 and e.X < 200 and e.Z < 200 then
					addToBuckets(pos - e, pos + e)
				end
			end
		end
	end
	function G.addBox(lo, hi)
		ensureBuckets()
		addToBuckets(lo, hi)
	end
	function G.hits(lo, hi)
		ensureBuckets()
		for cx = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
			for cz = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
				for _, b in buckets[cx * 4096 + cz] or {} do
					if b[1].X < hi.X and b[2].X > lo.X and b[1].Y < hi.Y and b[2].Y > lo.Y and b[1].Z < hi.Z and b[2].Z > lo.Z then
						return true
					end
				end
			end
		end
		return false
	end
	-- is a footprint (local centre x, z; half sizes hx, hz in x and z; height h) free? Returns the ground height.
	-- o: road (true allows roads), bld (extra studs from buildings), edge (studs from the boundary), slope (limit), covered (a
	-- roof above is fine). The margins are measured from the centre and default to the circle round the footprint (r) plus
	-- a little; a caller that tested the corners itself passes roadm, fence, rail and forest to cancel them.
	local OP = {}
	function G.free(x, z, hx, hz, h, o)
		o = o or NOOPT
		local r = math.sqrt(hx * hx + hz * hz)
		OP.bld, OP.edge, OP.fence, OP.rail, OP.forest = (o.bld or 3) + r, o.edge or (12 + r), o.fence or (2 + r), o.rail or (6 + r), o.forest or r
		OP.road = nil
		if not o.road then
			OP.road = o.roadm or (r + 0.5)
		end
		if not G.open(x, z, OP) then
			return nil
		end
		if G.rockNear(x, z, r + 1) or slopeAt(x, z) > (o.slope or 0.45) or G.blocked(x, z, r) then
			return nil
		end
		local y = ground(x, z)
		if G.hits(V(x - hx, y + 0.35, z - hz), V(x + hx, y + h, z + hz)) then
			return nil
		end
		if not o.covered and G.hits(V(x - 0.5, y + h, z - 0.5), V(x + 0.5, y + 60, z + 0.5)) then
			return nil
		end
		return y
	end

	-- ── helpers: named building points ────────────────────────────────────────────────────────────────────
	local points = B.points or {}
	local function bcentre(id, up) -- the footprint centre of a building, `up` studs above the ground
		local b = byId[id]
		if not b then
			return nil
		end
		return V(b.cx, ground(b.cx, b.cz) + (up or 0.5), b.cz)
	end
	local function named(name, id, up) -- B.points[name], else the matching footprint centre
		local p = points[name]
		if typeof(p) == "CFrame" then
			p = p.Position
		end
		if typeof(p) == "Vector3" then
			return p
		end
		return bcentre(id, up)
	end
	local function underCentre(id, up) -- a standing point in an underground room
		for _, u in L.under do
			if u[1] == id then
				return V(u[4], u[9] + (up or 3.3), u[5])
			end
		end
		return nil
	end
	local function loc(v) -- world position to map-local x, z
		return v.X - O.X, v.Z - O.Z
	end
	local function route(list) -- {{x, z} ...} to world points on the ground
		local out = {}
		for _, p in list do
			table.insert(out, V(p[1], ground(p[1], p[2]) + 0.5, p[2]))
		end
		return out
	end

	-- ── PMC spawns: six outdoor groups per half, as far apart as the reference's groups allow ───────────────
	try("spawns", function()
		local function spread(list, n, fromMax)
			local outdoor = {}
			for _, c in list do
				if c[6] == false then
					table.insert(outdoor, c)
				end
			end
			table.sort(outdoor, function(a, b)
				if fromMax then
					return a[1] > b[1]
				end
				return a[1] < b[1]
			end)
			local picked = { outdoor[1] }
			while #picked < n and #picked < #outdoor do
				local best, bestD = nil, -1
				for _, c in outdoor do
					local nearest = math.huge
					for _, p in picked do
						nearest = math.min(nearest, (c[1] - p[1]) * (c[1] - p[1]) + (c[2] - p[2]) * (c[2] - p[2]))
					end
					if nearest > bestD then
						best, bestD = c, nearest
					end
				end
				table.insert(picked, best)
			end
			return picked
		end
		local spawns, spos = {}, {}
		for _, side in { "east", "west" } do
			local tag = "W"
			if side == "east" then
				tag = "E"
			end
			for q, c in spread(L.clusters[side], 6, side == "east") do
				-- the group's own spawn point with the most room (not against a wall), nearest to its centre
				local best, bestScore, near, nearD = nil, -math.huge, nil, math.huge
				for _, p in L.spawns[side] do
					local dd = math.sqrt((p[1] - c[1]) * (p[1] - c[1]) + (p[2] - c[2]) * (p[2] - c[2]))
					if dd < nearD then
						near, nearD = p, dd
					end
					if dd <= 30 then
						local score = math.min(G.bldDist(p[1], p[2]), 14) - 0.1 * dd
						if score > bestScore then
							best, bestScore = p, score
						end
					end
				end
				best = best or near
				if best then
					table.insert(spawns, {
						id = tag .. q,
						cf = CFrame.new(V(best[1], ground(best[1], best[2]) + 3.4, best[2])) * CFrame.Angles(0, math.rad(best[4]), 0),
						side = side,
					})
					table.insert(spos, { best[1], best[2] })
				end
			end
		end
		-- names: the nearest area label or yard, each name once (the closest pairs first)
		local cand = {}
		for _, lb in L.labels do
			table.insert(cand, { lb[1], lb[2], lb[3] })
		end
		for _, y in L.yards do
			if not string.find(y[2], "LANDING", 1, true) then
				table.insert(cand, { y[2], y[3], y[4] })
			end
		end
		local pl = {}
		for si, sp in spos do
			for _, c in cand do
				table.insert(pl, { math.sqrt((c[2] - sp[1]) * (c[2] - sp[1]) + (c[3] - sp[2]) * (c[3] - sp[2])), si, c[1] })
			end
		end
		table.sort(pl, function(a, b)
			return a[1] < b[1]
		end)
		local used = {}
		for _, p in pl do
			local s = spawns[p[2]]
			if not s.name and not used[p[3]] then
				s.name, used[p[3]] = p[3], true
			end
		end
		for _, s in spawns do
			s.name = s.name or "BORDER YARD"
			s.extracts = W.sideExtracts[s.side]
		end
		W.spawns = spawns
		nSpawn = #spawns
	end)

	-- ── AI routes and guard posts ────────────────────────────────────────────────────────────────────────
	-- Six guard routes, each along roads and yards between the buildings (checked against footprints, fences and the
	-- river): the old checkpoint, the army post, round the Bastion, the fuel stop forecourt, the store 3-4 apron and
	-- the trailer lot. The first three guards stand at a post; the others walk their route.
	local PATROLS = {
		OC = { { -1512, 48 }, { -1420, 58 }, { -1415, 4 }, { -1505, -6 } },
		AP = { { -1258, 92 }, { -1226, 132 }, { -1228, 198 }, { -1258, 214 }, { -1252, 150 } },
		BG = { { -232, -300 }, { -228, -232 }, { -190, -170 }, { -120, -160 }, { -60, -185 }, { -50, -262 }, { -50, -340 }, { -60, -410 }, { -150, -420 }, { -215, -395 } },
		FS = { { -852, 148 }, { -700, 152 }, { -690, 262 }, { -846, 254 } },
		S4 = { { -700, -84 }, { -657, -22 }, { -644, 34 }, { -598, 40 }, { -668, 40 }, { -735, 0 } },
		TL = { { 1125, -615 }, { 1235, -615 }, { 1240, -562 }, { 1128, -570 } },
	}
	local PATROL_SRC = {} -- local x, z lists, for the keep-outs
	try("posts", function()
		for id, list in PATROLS do
			W.patrols[id] = route(list)
			PATROL_SRC[id] = list
		end
		-- EFT's Customs has scavs, marksmen and bosses, no raiders (audit ai-1a): the posts and routes are scav posts
		W.watchPosts = {
			{ route = "OC", post = V(-1498, ground(-1498, 6) + 0.5, 6), label = "Checkpoint Scav", kind = "scav" },
			{ route = "AP", post = V(-1256, ground(-1256, 118) + 0.5, 118), label = "Army Post Scav", kind = "scav" },
			{ route = "BG", post = named("BASTION_YARD", 28, 0.5), label = "Bastion Scav", kind = "scav" },
			{ route = "FS", label = "Fuel Stop Scav", kind = "scav" },
			{ route = "S4", label = "Store Scav", kind = "scav" },
			{ route = "TL", label = "Trailer Scav", kind = "scav" },
		}
		-- marksmen (EFT's sniper scavs, hard) on Customs' perches as the reference placed them (L.snipers): the tower one
		-- always, the bridge and factory ones half the time (slots 0-1), the block post none (slots 0)
		local PERCH = { ZoneSnipeTower = { 1, "DERRICK_TOP" }, ZoneSnipeBrige = { 0.5 }, ZoneSnipeFactory = { 0.5, "DEPOT_ROOF" } }
		for _, sp in L.snipers or {} do
			local how = PERCH[sp[1]]
			if how then
				local p = how[2] and points[how[2]]
				if typeof(p) == "CFrame" then
					p = p.Position
				end
				if typeof(p) == "Vector3" then
					p -= Vector3.new(0, 3, 0) -- (Works' named points stand 3 studs up; AI.spawn lifts the body itself)
				end
				if typeof(p) ~= "Vector3" then
					p = V(sp[3], ground(sp[3], sp[4]) + sp[5] + 1, sp[4]) -- on the roof at the building's height
				end
				table.insert(W.watchPosts, {
					post = p, label = "Marksman", kind = "scav", role = "marksman", diff = "hard", chance = how[1], loadout = "marksmanLoadout",
				})
			end
		end
	end)

	-- ── mounted guns: two nests on the roof of the Bastion (the scav base), a gunner posted behind each ─────────────────
	-- Both stand against the yard-side parapet, the building's +v wall (the one facing the BASTION_YARD point), pointing straight out
	-- from it. The pad lifts the gun and its operator so the barrel clears the 3.4 high parapet. The HMG-12 sits over the
	-- BASTION_YARD point (75 studs along the wall) and covers the yard; the AGL-30 sits 95 studs further along the same wall
	-- and lobs over the ground beyond (arcs 70 and 60 degrees either side of straight out). The gunners are scavs (EFT's
	-- scav base; audit ai-1a) on the posts behind the guns: the AI mans a gun when it engages a raider the gun can reach
	-- (Stationary.crew).
	try("guns", function()
		local b = byId[28]
		if not (b and kit.stationary and W.watchPosts) then
			return
		end
		local top = points.BASTION_TOP
		local roofY = (typeof(top) == "Vector3") and (top.Y - 3) or (ground(b.cx, b.cz) + 25.8)
		local nests = kit.model("Gun nests", map)
		local out = Vector3.new(-b.s, 0, b.c) -- the building's +v side: the yard and the gate
		for _, n in { { "HMG12", -75, "Bastion Gunner" }, { "AGL30", 20, "Bastion Grenadier" } } do
			local v = b.hd - 4.4
			local pos = V(b.cx + n[2] * b.c - v * b.s, roofY + 1.8, b.cz + n[2] * b.s + v * b.c)
			local cf = CFrame.lookAt(pos, pos + out)
			kit.boxCF(nests, 6, 1.8, 7.4, cf * CFrame.new(0, -0.9, 1.1), kit.hex("5A5E58"), kit.M.Concrete)
			local gun = kit.stationary(n[1], cf, {})
			if gun then
				table.insert(W.watchPosts, { route = "BG", post = gun.frame:PointToWorldSpace(gun.spec.op + Vector3.new(0, 0.5, 0)), label = n[3], kind = "scav" })
			end
		end
	end)

	-- ── the Broker (Reshala): the dorms, four guards ─────────────────────────────────────────────────────
	local BOSS_ROUTE = { { -120, 580 }, { -160, 545 }, { -96, 548 }, { -72, 545 }, { -70, 498 }, { -78, 566 }, { -85, 606 }, { -120, 622 }, { -160, 626 } }
	local CREW = { { -130, 572 }, { -110, 572 }, { -130, 590 }, { -110, 590 } }
	local bossHome
	try("boss", function()
		bossHome = named("BLOCK_A_LOBBY", 26, 1.2)
		local r = route(BOSS_ROUTE)
		if bossHome then
			table.insert(r, 1, bossHome) -- the loop returns to the lobby
		end
		-- Reshala's 752 and his guards' 630 (EFT; audit ai.2). His own look and kit and EFT's three zones, the dorms, the
		-- fuel stop and the Bastion (Customs: dorms, new gas station, Stronghold), at 45 % (EFT's 39-57 %; audit ai.3)
		-- named() gives world points and route() takes local ones (x east, z south from O): back to local first
		-- (the first version doubled the map offset and the guards spawned off the map and fell)
		local function ring(c, rx, rz)
			local x, z = c.X - O.X, c.Z - O.Z
			return route({ { x - rx, z - rz }, { x + rx, z - rz }, { x + rx, z + rz }, { x - rx, z + rz } })
		end
		local function guards(c)
			local x, z = c.X - O.X, c.Z - O.Z
			return route({ { x - 8, z - 6 }, { x + 8, z - 6 }, { x - 8, z + 6 }, { x + 8, z + 6 } })
		end
		local zones = { { name = "DORMS", home = bossHome or r[1], route = r, crew = route(CREW) } }
		-- (building 24 is the fuel stop; 8, the first version's fallback, is the forecourt's id among the yards and a storage
		-- block among the buildings, across the map)
		local fuel = named("FUEL_STOP_FORECOURT", 24, 0.5)
		if fuel then
			table.insert(zones, { name = "FUEL STOP", home = fuel, route = ring(fuel, 26, 18), crew = guards(fuel) })
		end
		local yard = named("BASTION_YARD", 28, 0.5)
		if yard then
			table.insert(zones, { name = "BASTION", home = yard, route = ring(yard, 22, 16), crew = guards(yard) })
		end
		W.boss = {
			name = "THE BROKER", label = "Broker", home = zones[1].home, route = r, crew = zones[1].crew, zones = zones,
			look = "broker", loadout = "brokerLoadout", chance = 0.45, hp = 752 / 440, crewHp = 630 / 440,
		}
	end)

	-- ── THE HOUNDS (Tarkov's Goons: Knight, Big Pipe and Birdeye; docs/design/BOSS_HOUNDS.md) ────────────────────────
	-- Three rogues who roam the map together. On Customs they turn up at the Stronghold (our Bastion) in 20 % of raids. Here
	-- they set out from the Bastion's yard and walk a loop past the frame, along the main road, by the motor shop and back.
	-- Every leg of the loop was checked with the AI pathfinder (2026-11-02). Each has Tarkov's health: HALBERD 1,120,
	-- MORTAR 910, KESTREL 795. All three fight with the boss's skill; the AI rolls them on their own, beside the Broker.
	local HOUNDS_ROUTE = { { -190, -170 }, { -200, -40 }, { -180, 150 }, { -100, 205 }, { 150, 237 }, { 400, 100 }, { 290, -150 }, { 241, -258 }, { 60, -260 }, { -50, -340 } }
	try("hounds", function()
		local r = route(HOUNDS_ROUTE)
		local home = named("BASTION_YARD", 28, 0.5) or r[1]
		local hx, hz = home.X - O.X, home.Z - O.Z
		local spots = route({ { hx + 4, hz + 3 }, { hx - 4, hz + 3 } })
		local hounds = {
			name = "THE HOUNDS", label = "Halberd", home = home, route = r, look = "halberd", loadout = "halberdLoadout",
			chance = 0.2, hp = 1120 / 440, skill = "boss",
			crew = {
				{ pos = spots[1], label = "Mortar", look = "mortar", loadout = "mortarLoadout", hp = 910 / 440, skill = "boss" },
				{ pos = spots[2], label = "Kestrel", look = "kestrel", loadout = "kestrelLoadout", hp = 795 / 440, skill = "boss" },
			},
		}
		W.bosses = W.boss and { W.boss, hounds } or { hounds }
	end)

	-- THE CULT (Tarkov's cultists on Customs; docs/design/BOSS_CULT.md): a priest (850 health) and two to four warriors,
	-- 20 %, in night raids only. tarkov.dev puts them at the Stronghold (here THE HOUNDS' home), the 2026 guides at the
	-- crackhouse and garages and the construction site: our THE SQUAT (either side) and THE FRAME. The warriors lie prone
	-- in the grass round their priest and charge with poisoned knives when someone comes near; hurt, they fight on with
	-- suppressed SMGs.
	local CULT_ZONES = {
		{ "SQUAT WEST", 205, -378 },
		{ "SQUAT EAST", 290, -378 },
		{ "THE FRAME", -123, 125 },
	}
	local CULT_POSTS = { { 10, 6 }, { -10, 6 }, { 8, -10, 0.5 }, { -8, -10, 0.5 } } -- the last two in half the raids each
	try("cult", function()
		local zones = {}
		for _, z in CULT_ZONES do
			local home = route({ { z[2], z[3] } })[1]
			local crew = {}
			for _, o in CULT_POSTS do
				table.insert(crew, {
					pos = route({ { z[2] + o[1], z[3] + o[2] } })[1], label = "Cultist", look = "cultist", loadout = "cultistLoadout",
					hp = 850 / 440, skill = "boss", charge = "knife", ambush = true, post = true, chance = o[3], -- EFT's 850 (audit ai.2)
				})
			end
			table.insert(zones, { name = z[1], home = home, post = home, crew = crew })
		end
		local cult = {
			name = "THE CULT", label = "Priest", home = zones[1].home, route = nil, look = "priest", loadout = "priestLoadout",
			chance = 0.2, night = true, hp = 850 / 440, skill = "boss", charge = "knife", ambush = true, zones = zones,
		}
		table.insert(W.bosses, cult)
	end)

	-- ── transits (Tarkov 0.15; docs/design/TRANSITS.md) ─────────────────────────────────────────────────────────
	-- Customs' transit to Interchange stands among parked vehicles next to the Trailer Park (SPT: 465, -190 m, our
	-- 1453, -594). That point is inside the trailer lot's wood, so ours stands 46 studs north-west at its edge, where the
	-- ground is clear (checked in Studio); Dress parks two wrecks beside it.
	try("transits", function()
		local p = route({ { 1420, -560 } })[1]
		W.transits = {
			{ id = "TR_MERIDIAN", name = "TRANSIT TO MERIDIAN MALL", to = "meridian", pos = p, size = Vector3.new(16, 10, 16), cf = CFrame.new(p + Vector3.new(0, 4.5, 0)) },
		}
	end)

	-- THE FORESTER (Tarkov's Partisan; docs/design/BOSS_FORESTER.md): a lone boss with 950 health and no armour, 20 % (more
	-- when raiders with low karma are in), who roams the tree lines and the construction site's edges (the 2026 guides; the
	-- dorms are where he was seen most) and leaves tripwires in the doorways near his walk. He hunts raiders with low
	-- karma; anyone else he leaves alone unless they come close or shoot at him. His steps make no sound.
	-- The loop: the frame's south apron, between the two woods, the west edge of the near wood, north of BLOCK B, south of
	-- the dorms along the wood, east of BLOCK A, the east edge of the long wood and back (each leg checked with the AI
	-- pathfinder, 2026-11-02).
	local FORESTER_ROUTE = { { -40, 160 }, { -60, 280 }, { -165, 420 }, { -160, 520 }, { -120, 690 }, { -5, 560 }, { 85, 450 }, { 60, 250 } }
	try("forester", function()
		local r = route(FORESTER_ROUTE)
		local forester = {
			name = "THE FORESTER", label = "Forester", home = r[1], route = r, roam = true, look = "forester", loadout = "foresterLoadout",
			chance = 0.2, hp = 950 / 440, skill = "boss", karmaHunt = true, silent = true, traps = 5,
		}
		table.insert(W.bosses, forester)
	end)

	-- ── scav spawn zones ─────────────────────────────────────────────────────────────────────────────────
	try("scav", function()
		local zones, zpts, perBld = {}, {}, {}
		local function addZone(x, z)
			for _, q in zpts do
				if (q[1] - x) * (q[1] - x) + (q[2] - z) * (q[2] - z) < 144 then
					return false
				end
			end
			table.insert(zpts, { x, z })
			table.insert(zones, V(x, ground(x, z) + 0.3, z))
			return true
		end
		local SCAV = { bld = 8, edge = 10, fence = 2.5 }
		-- the reference's normal scav points: dry land inside the boundary. Points inside a building (the motor yard
		-- is mostly the repair shop and Warehouse 17) move to the open ground beside it, four per building at most.
		for _, zone in L.scav do
			local lst = zone[7]
			for q = 1, #lst, 4 do
				local x, z = lst[q], lst[q + 1]
				if inside(x, z) and riverD(x, z) < -2 then
					local d, b = G.bldDist(x, z)
					if d >= 3 then
						addZone(x, z)
					elseif b and b.kind ~= "tank" and b.kind ~= "tower" and b.kind ~= "platform" and (perBld[b.id] or 0) < 4 then
						local sx, sz = G.snap(x, z, 70, SCAV)
						if sx and addZone(sx, sz) then
							perBld[b.id] = (perBld[b.id] or 0) + 1
						end
					end
				end
			end
		end
		-- more where Customs is busy: the dorms, the fuel stop, the Bastion, the stores, the trailer lot, Red Stores,
		-- the old pumps
		local ANCHORS = {
			{ -120, 585 }, { -150, 548 }, { -100, 622 }, { -262, 565 }, { -150, 662 }, { -18, 600 },
			{ -700, 180 }, { -862, 230 }, { -790, 276 },
			{ -142, -425 }, { -45, -300 }, { -205, -150 },
			{ -690, -60 }, { -625, 25 }, { -1131, -245 }, { -1185, -190 }, { 315, -190 }, { 402, -118 },
			{ 1150, -590 }, { 1232, -598 }, { 1300, -545 }, { 1350, -575 },
			{ 1100, -410 }, { 1058, -320 }, { 1092, -190 }, { 1130, -102 },
			{ -520, -405 }, { -562, -378 }, { -500, -468 },
		}
		for _, a in ANCHORS do
			local sx, sz = G.snap(a[1], a[2], 50, SCAV)
			if sx then
				addZone(sx, sz)
			end
		end
		-- inside the shops, the squat and the dorm lobby: the buildings' own standing points
		for _, e in { { "FUEL_SHOP", 24 }, { "OLD_PUMPS_SHOP", 44 }, { "SQUAT", 29 }, { "MOTOR_SHOP", 30 }, { "RED_STORES", 33 }, { "BLOCK_B_LOBBY", 25 } } do
			local p = named(e[1], e[2], 0.3)
			if p then
				table.insert(zones, p)
			end
		end
		W.scavZones = zones
	end)

	-- ── quest places ─────────────────────────────────────────────────────────────────────────────────────
	try("visit", function()
		local vz = {}
		local function zone(name, p, r)
			if p then
				vz[name] = { pos = p, r = r }
			end
		end
		zone("DORM314", named("BLOCK_A_ROOM314", 26, 17), 7)
		zone("BOILER", points.BOILER_CELLAR or underCentre("BC", 3.3), 14)
		local derrick = byId[27]
		zone("DERRICK", points.DERRICK_TOP or (derrick and V(derrick.cx, derrick.h + 3.3, derrick.cz)), 12)
		local frame = byId[34]
		zone("FRAME", points.FRAME_TOP or (frame and V(frame.cx, ground(frame.cx, frame.cz) + 3.3 + (frame.floors - 1) * 12.4, frame.cz)), 10)
		zone("SMUGGLERS", points.SMUGGLERS_HOLE or underCentre("SH", 3.3), 10)
		W.visitZones = vz
	end)

	-- ── keep-outs for propane, loot and Dress: spawns, extracts, routes, posts, the boss crew, scav zones, doors,
	-- containers, loose loot and the buildings' named points ─────────────────────────────────────────────────
	try("keepouts", function()
		for _, s in W.spawns or {} do
			G.keep(s.cf.Position.X - O.X, s.cf.Position.Z - O.Z, 14)
		end
		for _, e in W.extracts or {} do
			if typeof(e.pos) == "Vector3" then
				local x, z = loc(e.pos)
				G.keep(x, z, 14)
			end
		end
		local function segs(list, closed)
			for i = 1, #list do
				local a, b = list[i], list[i + 1]
				if not b and closed then
					b = list[1]
				end
				if b then
					G.keepSeg(a[1], a[2], b[1], b[2], 4.5)
				end
			end
		end
		for _, list in PATROL_SRC do
			segs(list, true)
		end
		segs(BOSS_ROUTE, true)
		if bossHome then
			local x, z = loc(bossHome)
			G.keep(x, z, 10)
			G.keepSeg(x, z, BOSS_ROUTE[1][1], BOSS_ROUTE[1][2], 4.5)
		end
		for _, c in CREW do
			G.keep(c[1], c[2], 5)
		end
		for _, wp in W.watchPosts or {} do
			if wp.post then
				local x, z = loc(wp.post)
				G.keep(x, z, 6)
			end
		end
		for _, zv in W.scavZones or {} do
			local x, z = loc(zv)
			G.keep(x, z, 5)
		end
		for _, d in W.doors or {} do
			if d.parent and d.cf and d.parent:IsDescendantOf(map) then
				G.keep(d.cf.Position.X - O.X, d.cf.Position.Z - O.Z, 6)
			end
		end
		for _, c in W.containers or {} do
			if c.map == "border" and c.part and c.part.Parent then
				G.keep(c.part.Position.X - O.X, c.part.Position.Z - O.Z, 5)
			end
		end
		for _, l in W.looseSpots or {} do
			G.keep(l.pos.X - O.X, l.pos.Z - O.Z, 3)
		end
		for _, p in points do
			if typeof(p) == "Vector3" then
				G.keep(p.X - O.X, p.Z - O.Z, 8)
			end
		end
	end)

	-- ── hazards: propane cylinders on open ground ───────────────────────────────────────────────────────
	try("propane", function()
		if not Hazards then
			return
		end
		local dm = kit.model("Propane", map)
		-- the fuel stop, the old works, the motor shop, the Frame's site, the trailer lot, the old pumps, Store 17;
		-- a third of the spots hold one cylinder, the rest two close together (a burst one sets off its neighbour)
		local SPOTS = {
			{ -790, 270, 2 }, { -842, 232, 2 }, { 232, 135, 2 }, { 262, -250, 2 }, { -80, 120, 2 }, { -55, -30, 2 },
			{ 1150, -560, 1 }, { -505, -405, 1 }, { 330, -190, 1 },
		}
		local FREEO = { bld = 6, slope = 0.3 }
		local function fits(x, z)
			return G.free(x, z, 0.9, 0.9, 4.2, FREEO) ~= nil and G.roadEdge(x, z) > 2 and G.edge(x, z) > 20
		end
		for _, s in SPOTS do
			local x, z = G.snap(s[1], s[2], 36, nil, fits)
			if x then
				local cyl = { { x, z } }
				if s[3] == 2 then
					local a = rng:NextNumber(0, math.pi * 2)
					local x2, z2 = x + math.cos(a) * 3.2, z + math.sin(a) * 3.2
					if fits(x2, z2) then
						table.insert(cyl, { x2, z2 })
					end
				end
				for _, c in cyl do
					local y = ground(c[1], c[2])
					Hazards.register(dm, H.CF(c[1], y, c[2], 0))
					G.addBox(V(c[1] - 0.8, y, c[2] - 0.8), V(c[1] + 0.8, y + 4.2, c[2] + 0.8))
					G.keep(c[1], c[2], 2.5)
					nPropane += 1
				end
			end
		end
	end)

	-- ── hazards: the border snipers over the reference's sniper quad at the north tip, as stair-step boxes. Spawns,
	-- extracts and the rail walk to NORTH LINE (the exit sits by the rails; since 1.2.0.0 the sniper no longer fires at
	-- players walking along them) stay clear ───────────────────────────────────────────────────────────────
	try("snipers", function()
		if not Hazards then
			return
		end
		local q = L.sniper
		local clear = {}
		for _, s in W.spawns or {} do
			table.insert(clear, s.cf.Position)
		end
		local nl = nil
		for _, e in L.ext do
			table.insert(clear, V(e[4], 0, e[5]))
			if e[1] == "NL" then
				nl = e
			end
		end
		if nl then
			local rail, bd = nil, math.huge
			for _, r in L.rails do
				local p = r[3]
				for i = 1, #p - 3, 2 do
					local d = segD(nl[4], nl[5], p[i], p[i + 1], p[i + 2], p[i + 3])
					if d < bd then
						rail, bd = p, d
					end
				end
			end
			if rail then
				for i = 1, #rail - 3, 2 do
					local ax, az, bx, bz = rail[i], rail[i + 1], rail[i + 2], rail[i + 3]
					local n = math.max(1, math.ceil(math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az)) / 24))
					for k = 0, n do
						local x, z = ax + (bx - ax) * k / n, az + (bz - az) * k / n
						if inPoly(q, x, z) then
							table.insert(clear, V(x, 0, z))
						end
					end
				end
			end
		end
		local zmin, zmax = math.huge, -math.huge
		for i = 2, #q, 2 do
			zmin, zmax = math.min(zmin, q[i]), math.max(zmax, q[i])
		end
		local n = 6
		local h = (zmax - zmin) / n
		for k = 0, n - 1 do
			local za, zb = zmin + k * h, zmin + (k + 1) * h
			local zm = (za + zb) / 2
			local xa, xb = math.huge, -math.huge
			for i = 1, #q - 1, 2 do
				local j = i + 2
				if j > #q then
					j = 1
				end
				local ay, by = q[i + 1], q[j + 1]
				if (ay > zm) ~= (by > zm) then
					local x = q[i] + (q[j] - q[i]) * (zm - ay) / (by - ay)
					xa, xb = math.min(xa, x), math.max(xb, x)
				end
			end
			if xa < xb then
				Hazards.sniperZone(V(xa, -40, za), V(xb, 130, zb), clear)
				nStrip += 1
			end
		end
	end)

	-- ── outdoor loose loot: the yards, the pump platforms and the scrap bridge landings ──────────────────
	try("loose", function()
		local lp = {} -- local x, z of the spots so far
		local LOOT = { bld = 5, edge = 12, fence = 2, rail = 4 }
		local function spot(x, z, y, chance)
			for _, q in lp do
				if (q[1] - x) * (q[1] - x) + (q[2] - z) * (q[2] - z) < 900 then
					return false
				end
			end
			table.insert(lp, { x, z })
			kit.loose(O.X + x, y, O.Z + z, "junk", chance, "border", true)
			G.keep(x, z, 3)
			nLoose += 1
			return true
		end
		-- the yards: more spots in the bigger ones, random open ground inside the outline
		for _, y in L.yards do
			local p = y[8]
			local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
			for i = 1, #p - 1, 2 do
				x0, x1 = math.min(x0, p[i]), math.max(x1, p[i])
				z0, z1 = math.min(z0, p[i + 1]), math.max(z1, p[i + 1])
			end
			local want = math.clamp(math.floor(y[5] * y[6] / 14000 + 0.5), 1, 5)
			local got, tries = 0, 0
			while got < want and tries < 40 do
				tries += 1
				local x, z = rng:NextNumber(x0, x1), rng:NextNumber(z0, z1)
				if inPoly(p, x, z) and G.open(x, z, LOOT) and not G.blocked(x, z, 2) and spot(x, z, ground(x, z) + 1.5, 0.4) then
					got += 1
				end
			end
		end
		-- the pump platforms (snap drops the spot onto whatever surface is below)
		for _, id in { 14, 17 } do
			local b = byId[id]
			if b then
				spot(b.cx + 5, b.cz + 2, ground(b.cx, b.cz) + 3, 0.5)
			end
		end
		-- the scrap bridge landings (yards 15 and 16)
		for _, y in L.yards do
			if y[1] == 15 or y[1] == 16 then
				spot(y[3], y[4], ground(y[3], y[4]) + 1.5, 0.45)
			end
		end
	end)

	local function count(t)
		local n = 0
		for _ in t or {} do
			n += 1
		end
		return n
	end
	print(string.format(
		"[ZR] Border play: %d spawns, %d patrol routes, %d watch posts, %d scav zones, boss %s with %d guards%s, %d visit zones, %d propane, %d sniper strips, %d loose spots",
		nSpawn, count(W.patrols), count(W.watchPosts), count(W.scavZones), W.boss and W.boss.name or "none",
		W.boss and #W.boss.crew or 0, (W.bosses and W.bosses[2]) and (", " .. W.bosses[2].name .. " (" .. #W.bosses[2].route .. " route points)") or "",
		count(W.visitZones), nPropane, nStrip, nLoose
	))
end
