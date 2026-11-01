--!nonstrict
-- Border Yard dressing (gameplay agent, part 3 of 3): Customs' outdoor clutter on top of what Ground and Buildings
-- built, about 2,000 parts. Every piece is tested against the map's geometry (B.geo, from Play: the building
-- footprints, roads, fences, rails, forests, shafts, rocks, the boundary, the solid parts of the map in boxes, a roof
-- overhead) and against the keep-outs for spawns, extracts, AI routes, posts, the Broker's crew, scav zones, doors,
-- containers and loose loot. Nothing stands on a road except wrecks. Each section runs under pcall.
--   containers   rows of shipping containers, some stacked two high, on the open ground of the STORAGE YARD
--   wrecks       cars and vans on the road shoulders and in the car parks, an item lying beside some of them
--   poles        wooden poles with crossarms and wires along five small roads (Ground has the pylon lines)
--   checkpoints  sandbags, a broken barrier and a drum round each guard post
--   cover        clusters in the yards: sandbags, pallets, tyres, cinder blocks, drums, cable reels, bins, rubble
--   fences       broken chain-link runs along the edges of the yards
--   nature       bushes, grass and rocks inside the boundary where Ground left room
-- One summary line: [ZR] Border dress: ...
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(B)
	local G = B.geo
	if not G then
		warn("[ZR] Border dress: skipped, Play did not publish the geometry (B.geo)")
		return
	end
	local kit, W, H, L, map, Kit = B.kit, B.W, B.H, B.L, B.map, B.Kit
	local V, CF, VC = H.V, H.CF, H.VC
	local O = B.O
	local ground = B.ground
	local C, M, hex, Props = kit.C, kit.M, kit.hex, kit.Props
	local KitMeta = require(ReplicatedStorage:WaitForChild("ZR"):WaitForChild("KitMeta"))
	local drng = Random.new(4242)
	local dm = kit.model("Dressing", map)
	local left = 2450 -- parts we may still add (a kit prop counts its pieces and its colliders)
	local n = { wreck = 0, pole = 0, fence = 0, cover = 0, container = 0, nature = 0, loose = 0 }
	local lib = ReplicatedStorage:FindFirstChild("ZR_Assets")
	local NOOPT = {}
	local function try(name, f)
		local ok, err = pcall(f)
		if not ok then
			warn("[ZR] Border dress: " .. name .. " failed: " .. tostring(err))
		end
	end
	local function shuffle(t)
		for i = #t, 2, -1 do
			local j = drng:NextInteger(1, i)
			t[i], t[j] = t[j], t[i]
		end
	end
	local function bbox(p) -- x0, z0, x1, z1 of a flat x, z outline
		local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
		for i = 1, #p - 1, 2 do
			x0, x1 = math.min(x0, p[i]), math.max(x1, p[i])
			z0, z1 = math.min(z0, p[i + 1]), math.max(z1, p[i + 1])
		end
		return x0, z0, x1, z1
	end

	-- ── footprints ────────────────────────────────────────────────────────────────────────────────────────
	-- Is a rotated footprint free? It is sx by sz studs in its own frame, its centre offset (ox, oz) from (x, z) in that
	-- frame, turned ry degrees, h studs tall. The 3 x 5 sample points over it must stand clear of every building (o.bld
	-- studs, default 3), of roads (unless o.road), fences, rails and forests; the rest (rocks, the boundary, keep-outs, the
	-- map's solid parts, a roof overhead) is G.free's, at the centre. Returns the ground height there, the centre and the
	-- half sizes of its bounding box.
	local O2 = { roadm = 0, fence = 0, rail = 0, forest = 0 }
	local function spotFree(x, z, sx, sz, ox, oz, ry, h, o)
		o = o or NOOPT
		local a = math.rad(ry or 0)
		local ca, sa = math.cos(a), math.sin(a)
		local cx, cz = x + ca * ox + sa * oz, z - sa * ox + ca * oz
		local margin = o.bld or 3
		for i = -1, 1 do
			for j = -2, 2 do
				local px = cx + ca * i * sx / 2 + sa * j * sz / 4
				local pz = cz - sa * i * sx / 2 + ca * j * sz / 4
				if G.bldDist(px, pz) < margin or G.fenceDist(px, pz) < 1.5 or G.railEdge(px, pz) < 1 or G.inForest(px, pz, 0) then
					return nil
				end
				if not o.road and G.roadEdge(px, pz) < 0.5 then
					return nil
				end
			end
		end
		local hx, hz = (math.abs(ca) * sx + math.abs(sa) * sz) / 2, (math.abs(sa) * sx + math.abs(ca) * sz) / 2
		O2.road, O2.bld, O2.edge, O2.slope, O2.covered = o.road, -math.sqrt(hx * hx + hz * hz), o.edge, o.slope, o.covered
		local y = G.free(cx, cz, hx, hz, h, O2)
		if not y then
			return nil
		end
		if math.max(sx, sz) > 8 then -- a long footprint must not straddle a bank
			local lo, hi = math.huge, -math.huge
			for _, i in { -1, 1 } do
				for _, j in { -1, 1 } do
					local g = ground(cx + ca * i * sx / 2 + sa * j * sz / 2, cz - sa * i * sx / 2 + ca * j * sz / 2)
					lo, hi = math.min(lo, g), math.max(hi, g)
				end
			end
			if hi - lo > 1.4 then
				return nil
			end
			y = (lo + hi) / 2 - 0.1
		end
		return y, cx, cz, hx, hz
	end
	local function box(cx, y, cz, hx, hz, h) -- the footprint goes into the geometry boxes: later pieces keep off it
		G.addBox(V(cx - hx, y, cz - hz), V(cx + hx, y + h, cz + hz))
	end
	-- footprints of the wear-kit cover props (the stand-in blocks Props.cover builds without the meshes)
	local COVER = {
		CarWreck = Vector3.new(6.1, 4.3, 16.2), Dumpster = Vector3.new(6.1, 5.2, 5), TyreStack = Vector3.new(4.5, 3.1, 2.9),
		CinderStack = Vector3.new(5.9, 2.8, 4.2), DrumDented = Vector3.new(3.4, 4.5, 3.3), CableReel = Vector3.new(2.7, 4, 4),
		BarrierBroken = Vector3.new(7.7, 2.9, 2.5), Sandbags = Vector3.new(5.7, 2.2, 1.2), PalletStack = Vector3.new(5.4, 2.6, 4.7),
	}
	-- a wear-kit cover prop at local (x, z), turned ry degrees, if the spot is free
	local function coverAt(kind, x, z, ry, color, o)
		local sz = COVER[kind]
		if not sz or left < 1 then
			return false
		end
		local y, cx, cz, hx, hz = spotFree(x, z, sz.X, sz.Z, 0, 0, ry, sz.Y, o)
		if not y then
			return false
		end
		Props.cover(dm, kind, CF(x, y, z, ry), color)
		left -= 1
		box(cx, y, cz, hx, hz, sz.Y)
		return true
	end
	-- a Blender kit prop (Kit.place: cosmetic pieces plus invisible colliders), same test
	local function kitAt(name, x, z, ry, o)
		local p = KitMeta.props[name]
		if not p then
			return false
		end
		local colls = Kit.COLL[name]
		local cost = #p.pieces + (colls and #colls or 1)
		if left < cost then
			return false
		end
		local sz, c = p.size, p.center
		local y, cx, cz, hx, hz = spotFree(x, z, sz.X, sz.Z, c.X, c.Z, ry, sz.Y, o)
		if not y then
			return false
		end
		local m = Kit.place(dm, name, CF(x, y, z, ry), { shadows = o ~= nil and o.shadows == true, tint = o and o.tint })
		if not m then
			return false
		end
		left -= cost
		box(cx, y, cz, hx, hz, sz.Y)
		return true
	end

	local yardById, yardBox = {}, {}
	for _, y in L.yards do
		yardById[y[1]] = y
		local x0, z0, x1, z1 = bbox(y[8])
		yardBox[y[1]] = { x0, z0, x1, z1 }
	end
	local function randomIn(yard) -- a random point in a yard's outline
		local b = yardBox[yard[1]]
		for _ = 1, 12 do
			local x, z = drng:NextNumber(b[1], b[3]), drng:NextNumber(b[2], b[4])
			if G.inPoly(yard[8], x, z) then
				return x, z
			end
		end
		return nil
	end
	-- the extract zones are up to 30 studs across: a keep-out wide enough to cover their corners
	for _, e in L.ext do
		G.keep(e[4], e[5], math.max(e[6], e[8]) * 0.75)
	end

	-- ── containers: rows of shipping containers, some stacked, on the open ground of the STORAGE YARD ──────
	try("containers", function()
		local yard = yardById[1]
		if not yard then
			return
		end
		local cost = 17 -- parts of the plain-box stand-in; one with the mesh
		if lib and lib:FindFirstChild("ZR_ENV_Container20") then
			cost = 1
		end
		local colors = { C.rust, C.blue, C.olive, C.teal, C.red, C.metal, C.orange }
		local CO = { bld = 4, slope = 0.2 }
		local b = yardBox[1]
		local function put(x, z) -- one container, or two stacked, long side along the yard; true when placed
			if n.container >= 34 or left < cost * 2 then
				return false
			end
			local ry = 90 + 180 * drng:NextInteger(0, 1)
			local stack = drng:NextNumber() < 0.35
			local top = stack and 19.2 or 9.6
			local y, cx, cz, hx, hz = spotFree(x, z, 22, 8.8, 0, 0, ry, top, CO)
			if not y then
				return false
			end
			Props.container(dm, CF(x, y, z, ry), colors[drng:NextInteger(1, #colors)])
			left -= cost
			if stack then
				Props.container(dm, CF(x + drng:NextNumber(-0.5, 0.5), y + 9.5, z, ry), colors[drng:NextInteger(1, #colors)])
				left -= cost
			end
			box(cx, y, cz, hx, hz, top)
			n.container += 1
			return true
		end
		-- random spots on rows 23.6 studs apart; a placed container often has neighbours to its east and west
		for _ = 1, 500 do
			if n.container < 34 then
				local x, z = drng:NextNumber(b[1], b[3]), drng:NextNumber(b[2], b[4])
				if G.inPoly(yard[8], x, z) then
					z = b[2] + 12 + 23.6 * math.floor((z - b[2] - 12) / 23.6 + 0.5)
					if put(x, z) then
						for _, d in { 1, -1 } do
							local k = 1
							while k < 4 and drng:NextNumber() < 0.7 and put(x + d * 9.8 * k, z + drng:NextNumber(-0.8, 0.8)) do
								k += 1
							end
						end
					end
				end
			end
		end
	end)

	-- ── wrecks: on the road shoulders (a third half on the road) and in the car parks ─────────────────────
	local WRECKS = {
		{ "c", "CarWreck" }, { "c", "CarWreck" }, { "c", "CarWreck" }, { "k", "CarSedanSmashed" }, { "k", "CarSedanSmashed" },
		{ "k", "CarSedan" }, { "k", "CarHatch" }, { "k", "Van" },
	}
	local PAINT = { hex("6C7A80"), hex("7A5C4E"), hex("5E6B52"), hex("8A8680"), hex("4D5B6E"), hex("6B3A32") }
	local WO = { road = true, slope = 0.3, shadows = true, bld = 2 }
	local ITEM = { road = true, bld = 2 }
	-- a wreck of a random kind at (x, z); `side` (-1 or 1) is the flank an item may lie on, tested before the car's box
	-- goes in
	local function wreckAt(x, z, ry, o, side)
		local w = WRECKS[drng:NextInteger(1, #WRECKS)]
		o.tint = PAINT[drng:NextInteger(1, #PAINT)]
		local item = nil
		if n.loose < 14 and drng:NextNumber() < 0.5 then
			local a = math.rad(ry)
			local lx, lz = x + math.cos(a) * 5.6 * side, z - math.sin(a) * 5.6 * side
			local iy = G.free(lx, lz, 0.5, 0.5, 1.5, ITEM)
			if iy then
				item = { lx, iy, lz }
			end
		end
		local ok = false
		if w[1] == "c" then
			ok = coverAt(w[2], x, z, ry, nil, o)
		else
			ok = kitAt(w[2], x, z, ry, o)
		end
		if ok then
			n.wreck += 1
			if item then
				kit.loose(O.X + item[1], item[2] + 0.3, O.Z + item[3], "junk", 0.4, "border", true)
				G.keep(item[1], item[3], 3)
				n.loose += 1
			end
		end
		return ok
	end
	try("wrecks", function()
		-- candidates along the roads, spaced by road class, shuffled
		local GAP = { H = 150, M = 170, T = 240, G = 380 }
		local cands = {}
		for _, rd in L.roads do
			local p = rd[4]
			local total, segs = 0, {}
			for i = 1, #p - 3, 2 do
				local len = math.sqrt((p[i + 2] - p[i]) * (p[i + 2] - p[i]) + (p[i + 3] - p[i + 1]) * (p[i + 3] - p[i + 1]))
				table.insert(segs, { i, len, total })
				total += len
			end
			local cnt = math.floor(total / (GAP[rd[2]] or 250))
			for k = 1, cnt do
				local t = (k - 0.5 + drng:NextNumber(-0.35, 0.35)) / cnt * total
				for _, s in segs do
					if s[2] > 0.01 and t <= s[3] + s[2] then
						local i, f = s[1], (t - s[3]) / s[2]
						table.insert(cands, {
							x = p[i] + (p[i + 2] - p[i]) * f, z = p[i + 1] + (p[i + 3] - p[i + 1]) * f,
							dx = (p[i + 2] - p[i]) / s[2], dz = (p[i + 3] - p[i + 1]) / s[2], half = rd[3] / 2,
						})
						break
					end
				end
			end
		end
		shuffle(cands)
		local onRoads = 0
		for _, c in cands do
			if onRoads < 36 then
				local side = 1
				if drng:NextNumber() < 0.5 then
					side = -1
				end
				local off = c.half + 4.5 + drng:NextNumber(0, 3) -- on the shoulder
				if drng:NextNumber() < 0.35 then
					off = c.half - 3.5 -- on the road, against its edge
				end
				local x, z = c.x - c.dz * side * off, c.z + c.dx * side * off
				local ry = math.deg(math.atan2(c.dx, c.dz)) + 180 * drng:NextInteger(0, 1) + drng:NextNumber(-22, 22)
				if wreckAt(x, z, ry, WO, side) then
					onRoads += 1
				end
			end
		end
		-- the vehicles parked at a transit (Tarkov's Customs: "a cluster of parked vehicles next to the Trailer Park")
		for _, tr in W.transits or {} do
			local tx, tz = tr.pos.X - O.X, tr.pos.Z - O.Z
			local got = 0
			for _ = 1, 16 do
				if got < 2 then
					local a = drng:NextNumber(0, math.pi * 2)
					local r = drng:NextNumber(12, 17)
					if wreckAt(tx + math.cos(a) * r, tz + math.sin(a) * r, drng:NextNumber(0, 360), { slope = 0.3, shadows = true, bld = 4 }, 1) then
						got += 1
					end
				end
			end
		end
		-- car parks: cars along the yard's axes with a little scatter
		local PARKS = { [11] = 3, [13] = 2, [14] = 1, [8] = 2, [7] = 2, [9] = 3, [5] = 2, [4] = 1, [2] = 2, [0] = 3, [6] = 1, [12] = 1 }
		local PO = { slope = 0.3, shadows = true, bld = 4 }
		for yid, want in PARKS do
			local yard = yardById[yid]
			if yard then
				local got = 0
				for _ = 1, 16 do
					if got < want then
						local x, z = randomIn(yard)
						if x then
							local ry = -yard[7] + 90 * drng:NextInteger(0, 1) + drng:NextNumber(-12, 12)
							if wreckAt(x, z, ry, PO, 1) then
								got += 1
							end
						end
					end
				end
			end
		end
	end)

	-- ── poles with wires along five small roads, clear of Ground's pylon lines ────────────────────────────
	try("poles", function()
		local POLE, WIRE, GLASS = hex("4A3F33"), hex("1E1F1F"), hex("8FA3A8")
		local roadById = {}
		for _, rd in L.roads do
			roadById[rd[1]] = rd
		end
		local function nearPower(x, z)
			for _, row in L.power do
				local p = row[2]
				for i = 1, #p - 3, 2 do
					if G.segD(x, z, p[i], p[i + 1], p[i + 2], p[i + 3]) < 45 then
						return true
					end
				end
			end
			return false
		end
		local function roadLen(rd)
			local p, total = rd[4], 0
			for i = 1, #p - 3, 2 do
				total += math.sqrt((p[i + 2] - p[i]) * (p[i + 2] - p[i]) + (p[i + 3] - p[i + 1]) * (p[i + 3] - p[i + 1]))
			end
			return total
		end
		-- the point `s` studs along a road, 7 studs beyond its edge on one flank, and the road's direction there
		local function polePos(rd, s, side)
			local p, acc = rd[4], 0
			local off = (rd[3] / 2 + 7) * side
			for i = 1, #p - 3, 2 do
				local ax, az, bx, bz = p[i], p[i + 1], p[i + 2], p[i + 3]
				local len = math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
				if len > 0.01 and s <= acc + len then
					local f = (s - acc) / len
					local dx, dz = (bx - ax) / len, (bz - az) / len
					return ax + (bx - ax) * f - dz * off, az + (bz - az) * f + dx * off, dx, dz
				end
				acc += len
			end
			return nil
		end
		local function poleSpot(rd, s, side)
			local x, z, dx, dz = polePos(rd, s, side)
			if not x or nearPower(x, z) then
				return nil
			end
			local y = G.free(x, z, 0.6, 0.6, 22, nil)
			if not y then
				return nil
			end
			return x, y, z, dx, dz
		end
		-- { road, where it starts (fraction of its length), poles }
		local LINES = {
			{ "paved_small_4", 0.04, 12 }, { "paved_small_2", 0.12, 9 }, { "paved_small_5", 0.08, 9 }, { "paved_small_0", 0.1, 8 },
			{ "paved_small_3", 0.1, 6 },
		}
		for _, ln in LINES do
			local rd = roadById[ln[1]]
			if rd and n.pole < 44 then
				local s0 = roadLen(rd) * ln[2]
				local bestSide, best = 1, -1
				for _, side in { 1, -1 } do -- the flank with more room
					local ok = 0
					for k = 0, ln[3] - 1 do
						if poleSpot(rd, s0 + k * 42, side) then
							ok += 1
						end
					end
					if ok > best then
						bestSide, best = side, ok
					end
				end
				local last = nil
				for k = 0, ln[3] - 1 do
					local x, y, z, dx, dz = nil, nil, nil, nil, nil
					if left >= 12 and n.pole < 44 then
						x, y, z, dx, dz = poleSpot(rd, s0 + k * 42, bestSide)
					end
					if x then
						n.pole += 1
						left -= 5
						local pole = VC(dm, 22, 0.7, x, y, z, POLE, M.Wood)
						pole.Name = "PowerPole"
						local top = V(x, y + 20.6, z)
						local nrm = Vector3.new(-dz, 0, dx)
						local arm = kit.boxCF(dm, 0.35, 0.35, 6, CFrame.lookAt(top, top + nrm), POLE, M.Wood)
						arm.Name = "Crossarm"
						arm.CanCollide = false
						local tops = {}
						for i, off in { -2.6, 0, 2.6 } do
							local at = top + nrm * off + Vector3.new(0, 0.5, 0)
							local ins = kit.boxCF(dm, 0.25, 0.5, 0.25, CFrame.new(at), GLASS, M.Glass)
							ins.CanCollide = false
							tops[i] = at + Vector3.new(0, 0.3, 0)
						end
						if last and (tops[1] - last[1]).Magnitude < 50 and left >= 3 then
							left -= 3
							for i = 1, 3 do
								local a, b = last[i], tops[i]
								local wire = kit.boxCF(dm, 0.08, 0.08, (b - a).Magnitude, CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.6, 0), WIRE, M.SmoothPlastic)
								wire.CanCollide = false
								wire.CanQuery = false
								wire.CastShadow = false
								wire:SetAttribute("NoDetail", true)
							end
						end
						last = tops
						box(x, y, z, 0.5, 0.5, 22)
					else
						last = nil
					end
				end
			end
		end
	end)

	-- ── roads into the hills: a road that leaves the map used to run straight into the boundary rock. A line of concrete
	-- barriers now closes it 6 studs short of the limit, as Tarkov closes its map edges. ARMY ROADBLOCK (RUAF Roadblock)
	-- gets a manned roadblock on the road in front of its zone: two staggered rows of barriers, sandbag walls on the
	-- shoulders and a booth. The rows and the clearance rules are Maps/RoadEnds.luau's; the pieces stand on the road
	-- directly and their boxes keep later props off.
	try("road ends", function()
		local inside = B.inside
		if not inside then
			return
		end
		local spawnsAt = {}
		for _, sp in W.spawns or {} do
			table.insert(spawnsAt, Vector2.new(sp.cf.Position.X - O.X, sp.cf.Position.Z - O.Z))
		end
		local function at(kind, x, z, ry, sz)
			local y = ground(x, z) + 0.16
			Props.cover(dm, kind, CF(x, y, z, ry), nil)
			left -= 1 -- one mesh part, as coverAt counts it
			local a = math.rad(ry)
			local hx = (math.abs(math.cos(a)) * sz.X + math.abs(math.sin(a)) * sz.Z) / 2
			local hz = (math.abs(math.sin(a)) * sz.X + math.abs(math.cos(a)) * sz.Z) / 2
			box(x, y, z, hx, hz, sz.Y)
			n.cover += 1
		end
		local RE = require(script.Parent.Parent.RoadEnds).new({
			L = L, inside = inside, place = at, spawns = spawnsAt, rng = drng, size = COVER.BarrierBroken,
		})
		local clearOfPlay, barrierRow = RE.clear, RE.row
		-- the roadblock in front of ARMY ROADBLOCK: the road through its zone, the way in from the map along it
		local ar = nil
		for _, e in L.ext do
			if e[1] == "AR" then
				ar = e
			end
		end
		if ar then
			-- the nearest road: its direction, its width and the point on its middle line abreast of the zone (the zone
			-- stands beside the road, not on it)
			local best, bux, buz, bw, rx, rz = math.huge, 0, 0, 0, ar[4], ar[5]
			for _, rd in L.roads do
				local pts = rd[4]
				for s = 1, #pts / 2 - 1 do
					local ax, az, bx, bz = pts[2 * s - 1], pts[2 * s], pts[2 * s + 1], pts[2 * s + 2]
					local dx, dz = bx - ax, bz - az
					local l2 = dx * dx + dz * dz
					if l2 > 1 then
						local t = math.clamp(((ar[4] - ax) * dx + (ar[5] - az) * dz) / l2, 0, 1)
						local ex, ez = ar[4] - (ax + dx * t), ar[5] - (az + dz * t)
						local d = math.sqrt(ex * ex + ez * ez)
						if d < best then
							local l = math.sqrt(l2)
							best, bux, buz, bw, rx, rz = d, dx / l, dz / l, rd[3], ax + dx * t, az + dz * t
						end
					end
				end
			end
			if best < 20 then
				-- (bux, buz) toward the map: the direction in which the map goes on longer
				local fwd, back = 0, 0
				while fwd < 200 and inside(rx + bux * fwd, rz + buz * fwd) do
					fwd += 4
				end
				while back < 200 and inside(rx - bux * back, rz - buz * back) do
					back += 4
				end
				if fwd < back then
					bux, buz = -bux, -buz
				end
				local reach = math.max(ar[6], ar[8]) / 2 + 3 + COVER.BarrierBroken.X / 2 + 1
				local cx, cz = rx + bux * reach, rz + buz * reach
				-- the rows are crossed from the map side, so the way "out" of a row is back toward the zone
				barrierRow(cx, cz, -bux, -buz, bw, 1.2)
				barrierRow(cx + bux * 5, cz + buz * 5, -bux, -buz, bw, -1.2)
				local px, pz = -buz, bux
				for _, sg in { -1, 1 } do
					for j = 0, 1 do
						local sx = cx + px * sg * (bw / 2 + 2.5) + bux * (j * 6 + 1)
						local sz2 = cz + pz * sg * (bw / 2 + 2.5) + buz * (j * 6 + 1)
						if clearOfPlay(sx, sz2, COVER.Sandbags.X / 2) then
							at("Sandbags", sx, sz2, math.deg(math.atan2(-bux, -buz)) + 90, COVER.Sandbags)
						end
					end
				end
				-- the guard booth on the shoulder, facing the road
				local bx2, bz2 = cx + px * (bw / 2 + 7) + bux * 3, cz + pz * (bw / 2 + 7) + buz * 3
				local p = KitMeta.props.TicketBooth
				if p and clearOfPlay(bx2, bz2, 4) then
					local m = Kit.place(dm, "TicketBooth", CF(bx2, ground(bx2, bz2), bz2, math.deg(math.atan2(px, pz))), { shadows = false })
					if m then
						left -= #p.pieces + 1
						box(bx2, ground(bx2, bz2), bz2, 4, 4, p.size.Y)
					end
				end
			end
		end
		-- every road's way off the map
		RE.edges()
	end)

	-- ── checkpoints: sandbags, a broken barrier and a drum round each guard post ───────────────────────────
	-- (the post, the patrol round it and the scav zones keep most of the ground free: each prop tries ten spots)
	try("checkpoints", function()
		local RING = { "Sandbags", "BarrierBroken", "Sandbags", "DrumDented", "Sandbags" }
		for _, wp in W.watchPosts or {} do
			if wp.post then
				local px, pz = wp.post.X - O.X, wp.post.Z - O.Z
				for _, kind in RING do
					for _ = 1, 10 do
						local a, r = drng:NextNumber(0, math.pi * 2), drng:NextNumber(7, 16)
						-- the long side of the prop lies along the ring
						if coverAt(kind, px + math.cos(a) * r, pz + math.sin(a) * r, math.deg(math.atan2(math.cos(a), math.sin(a))), nil, nil) then
							n.cover += 1
							break
						end
					end
				end
			end
		end
	end)

	-- ── cover clusters in the yards ────────────────────────────────────────────────────────────────────────
	try("cover", function()
		local DRUMS = { C.blue, C.rust, C.olive, C.red }
		-- { source, prop, count }: c = wear-kit cover prop, k = Blender kit prop
		local THEMES = {
			{ { "c", "Sandbags", 2 }, { "c", "DrumDented", 1 } },
			{ { "c", "PalletStack", 2 }, { "k", "PalletBoxes", 1 } },
			{ { "c", "TyreStack", 2 }, { "k", "Drum", 1 } },
			{ { "c", "CinderStack", 2 }, { "c", "BarrierBroken", 1 } },
			{ { "c", "DrumDented", 2 }, { "k", "JerryCans", 1 }, { "k", "Drum", 1 } },
			{ { "c", "CableReel", 1 }, { "c", "PalletStack", 1 }, { "c", "CinderStack", 1 } },
			{ { "c", "Dumpster", 1 }, { "k", "Bin", 1 }, { "k", "CardboardPile", 1 } },
			{ { "k", "RubbleB", 1 }, { "k", "Rubble", 1 }, { "c", "CinderStack", 1 } },
		}
		local WORKS = { [3] = true, [12] = true, [5] = true, [4] = true } -- building sites and yards: blocks, pallets, reels
		local STATION = { [7] = true, [8] = true } -- fuel: drums and tyres
		local function themeFor(yid)
			local r = drng:NextNumber()
			if WORKS[yid] and r < 0.6 then
				return THEMES[({ 2, 4, 6, 8 })[drng:NextInteger(1, 4)]]
			end
			if STATION[yid] and r < 0.6 then
				return THEMES[({ 3, 5, 1 })[drng:NextInteger(1, 3)]]
			end
			return THEMES[drng:NextInteger(1, #THEMES)]
		end
		for _, yard in L.yards do
			local yid = yard[1]
			if yid ~= 15 and yid ~= 16 then -- the scrap bridge landings are Play's loot spots
				local want = math.clamp(math.floor(yard[5] * yard[6] / 6500 + 0.5), 1, 10)
				if yid == 1 then
					want = 3 -- the containers are the storage yard's cover
				end
				for _ = 1, want do
					local cx, cz = nil, nil
					for _ = 1, 14 do
						local x, z = randomIn(yard)
						if x and G.free(x, z, 3.5, 3.5, 3, nil) then
							cx, cz = x, z
							break
						end
					end
					if cx and left > 40 then
						local base = drng:NextNumber(0, 360)
						for _, e in themeFor(yid) do
							for _ = 1, e[3] do
								for _ = 1, 4 do
									local x, z = cx + drng:NextNumber(-5, 5), cz + drng:NextNumber(-5, 5)
									local ry = base + drng:NextNumber(-25, 25)
									local ok = false
									if e[1] == "c" then
										local color = nil
										if e[2] == "DrumDented" then
											color = DRUMS[drng:NextInteger(1, #DRUMS)]
										end
										ok = coverAt(e[2], x, z, ry, color, nil)
									else
										ok = kitAt(e[2], x, z, ry, nil)
									end
									if ok then
										n.cover += 1
										break
									end
								end
							end
						end
					end
				end
			end
		end
	end)

	-- ── broken chain-link runs along the edges of some yards (a run, a gap, another run) ───────────────────
	try("fences", function()
		local FO = { bld = 2 }
		for _, yid in { 9, 8, 7, 5, 4, 3, 12, 11, 13, 0, 2, 6, 14, 10 } do
			local yard = yardById[yid]
			if yard then
				local p = yard[8]
				local edges, total = {}, 0
				for i = 1, #p - 1, 2 do
					local j = i + 2
					if j > #p then
						j = 1
					end
					local len = math.sqrt((p[j] - p[i]) * (p[j] - p[i]) + (p[j + 1] - p[i + 1]) * (p[j + 1] - p[i + 1]))
					if len > 30 then
						table.insert(edges, { p[i], p[i + 1], p[j], p[j + 1], len })
						total += len
					end
				end
				local want = 2
				if yard[5] * yard[6] > 20000 then
					want = 3
				end
				local got = 0
				for _ = 1, want * 4 do
					if got < want and total > 0 and left >= 12 then
						local t = drng:NextNumber(0, total)
						local e = edges[#edges]
						for _, ed in edges do
							t -= ed[5]
							if t <= 0 then
								e = ed
								break
							end
						end
						local dx, dz = (e[3] - e[1]) / e[5], (e[4] - e[2]) / e[5]
						local nx, nz = -dz, dx
						if (e[1] - yard[3]) * nx + (e[2] - yard[4]) * nz < 0 then
							nx, nz = -nx, -nz -- away from the yard
						end
						local runLen = math.min(e[5] - 4, drng:NextNumber(18, 42))
						local t0 = drng:NextNumber(2, e[5] - runLen - 2)
						local off = drng:NextNumber(2.5, 4)
						local x0, z0 = e[1] + dx * t0 + nx * off, e[2] + dz * t0 + nz * off
						local x1, z1 = x0 + dx * runLen, z0 + dz * runLen
						local steps = math.ceil(runLen / 6)
						local ok = true
						for q = 0, steps do
							if ok and not G.free(x0 + (x1 - x0) * q / steps, z0 + (z1 - z0) * q / steps, 0.5, 0.5, 6.6, FO) then
								ok = false
							end
						end
						if ok then
							H.fence(dm, x0, z0, x1, z1, ground(x0, z0), 6, ground(x1, z1))
							left -= math.max(1, math.floor(runLen / 6 + 0.5)) + 3
							for q = 0, steps do
								local sx, sz = x0 + (x1 - x0) * q / steps, z0 + (z1 - z0) * q / steps
								box(sx, ground(sx, sz), sz, 0.7, 0.7, 6.6)
							end
							n.fence += 1
							got += 1
						end
					end
				end
			end
		end
	end)

	-- ── nature along the boundary where Ground left room: bushes, grass, rocks ─────────────────────────────
	try("nature", function()
		if not (lib and lib:FindFirstChild("ZR_NAT_Bush1")) then
			return
		end
		local p = L.boundary
		local cands = {}
		for i = 1, #p - 1, 2 do
			local j = i + 2
			if j > #p then
				j = 1
			end
			local ax, az, bx, bz = p[i], p[i + 1], p[j], p[j + 1]
			local len = math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
			if len > 1 then
				local dx, dz = (bx - ax) / len, (bz - az) / len
				local nx, nz = -dz, dx
				if not G.inside(ax + dx * len / 2 + nx * 12, az + dz * len / 2 + nz * 12) then
					nx, nz = -nx, -nz -- toward the inside
				end
				local d = drng:NextNumber(0, 30)
				while d < len do
					local inset = drng:NextNumber(6, 22)
					table.insert(cands, { ax + dx * d + nx * inset, az + dz * d + nz * inset })
					d += drng:NextNumber(26, 44)
				end
			end
		end
		shuffle(cands)
		local NO = { edge = 4, bld = 3, slope = 0.6 }
		for _, c in cands do
			if n.nature < 150 and left > 20 then
				local roll = drng:NextNumber()
				local key, sc, solid = "ZR_NAT_Bush" .. drng:NextInteger(1, 2), drng:NextNumber(1, 1.7), false
				if roll > 0.88 then
					key, sc, solid = "ZR_NAT_RockPile", drng:NextNumber(0.9, 1.4), true
				elseif roll > 0.7 then
					key, sc = "ZR_NAT_Grass", drng:NextNumber(1, 1.5)
				elseif roll > 0.42 then
					key, sc, solid = "ZR_NAT_Rock" .. drng:NextInteger(1, 3), drng:NextNumber(0.8, 1.7), true
				end
				local y = G.free(c[1], c[2], 1.6 * sc, 1.6 * sc, 3 * sc, NO)
				if y and H.nat(dm, key, CF(c[1], y - 0.2, c[2], drng:NextNumber(0, 360)), sc, nil, solid) then
					left -= 1
					n.nature += 1
					G.keep(c[1], c[2], 1.4 * sc)
				end
			end
		end
	end)

	local parts = 0
	for _, d in dm:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	print(string.format(
		"[ZR] Border dress: %d wrecks, %d poles, %d fence runs, %d cover pieces, %d containers, %d nature, %d loose spots, %d parts",
		n.wreck, n.pole, n.fence, n.cover, n.container, n.nature, n.loose, parts
	))
	if parts > 2500 then
		warn("[ZR] Border dress: " .. parts .. " parts, over the budget of 2,500")
	end
end
