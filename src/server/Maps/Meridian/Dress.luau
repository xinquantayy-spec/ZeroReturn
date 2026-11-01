--!nonstrict
-- Meridian Mall dressing (the gameplay agent, part 3 of 3): the outdoor and car park clutter on top of what Ground, Outside,
-- the shell and the stores built, up to about 2,300 parts. Every piece is tested against the map's geometry (B.geo, from Play:
-- footprints, roads, fences, rails, rocks, the boundary, the solid parts of the map in boxes, a roof overhead, the L0 floor
-- polygon) and against the keep-outs for spawns, extracts, AI routes, posts, scav zones, doors, containers and loose loot.
-- Nothing but wrecks stands on a road. Each section runs under pcall.
--   lots       parked and burnt cars in the bays of the five west car parks (the frame Ground paints the bay marks in)
--   garages    cars on the L0 floor under the mall: car parks A to D and the three anchor garages (floor y 0, clear of columns)
--   wrecks     cars on the road shoulders, an item lying beside some of them
--   furniture  trolley bays, boom barriers, cones, bins and street lamps in and round the lots, at the booths and huts
--   camps      sandbags, tyres, drums and a broken barrier round the west camp, the rescue camp, the checkpoint, the substation gate
--   docks      pallets, boxes, roll cages, jerry cans, drums, dumpsters, vans and a forklift on the aprons; containers in the cargo yards
--   nature     bushes, grass and rocks inside the boundary where Ground left room
-- One summary line: [ZR] Meridian dress: ...
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(B)
	local G = B.geo
	if not G then
		warn("[ZR] Meridian dress: skipped, Play did not publish the geometry (B.geo)")
		return
	end
	local kit, W, H, L, map, Kit = B.kit, B.W, B.H, B.L, B.map, B.Kit
	local V, CF = H.V, H.CF
	local O = B.O
	local ground = B.ground
	local points = B.points
	local C, M, hex, Props = kit.C, kit.M, kit.hex, kit.Props
	local KitMeta = require(ReplicatedStorage:WaitForChild("ZR"):WaitForChild("KitMeta"))
	local drng = Random.new(4243)
	local dm = kit.model("Dressing", map)
	local left = 2300 -- parts we may still add (a kit prop counts its pieces and its colliders)
	local n = { car = 0, burnt = 0, l0 = 0, wreck = 0, trolley = 0, barrier = 0, cone = 0, bin = 0, lamp = 0, camp = 0, dock = 0, container = 0, nature = 0, loose = 0 }
	local lib = ReplicatedStorage:FindFirstChild("ZR_Assets")
	local NOOPT = {}
	local function try(name, f)
		local ok, err = pcall(f)
		if not ok then
			warn("[ZR] Meridian dress: " .. name .. " failed: " .. tostring(err))
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
	local function pointOf(p)
		if typeof(p) == "CFrame" then
			return p.Position
		elseif typeof(p) == "Vector3" then
			return p
		end
		return nil
	end

	-- ── footprints ────────────────────────────────────────────────────────────────────────────────────────
	-- Is a rotated footprint free? It is sx by sz studs in its own frame, its centre offset (ox, oz) from (x, z) in that
	-- frame, turned ry degrees, h studs tall. The 3 x 5 sample points over it must stand clear of every building (o.bld
	-- studs, default 3), of roads (unless o.road), fences and rails; the rest (rocks, the boundary, keep-outs, the map's
	-- solid parts, a roof overhead) is G.free's, at the centre. Returns the ground height there, the centre and the half
	-- sizes of its bounding box.
	local O2 = { roadm = 0, fence = 0, rail = 0 }
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
				if G.bldDist(px, pz) < margin or G.fenceDist(px, pz) < 1.5 or G.railEdge(px, pz) < 1 then
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
	local function kitCost(name)
		local p = KitMeta.props[name]
		if not p then
			return nil
		end
		local colls = Kit.COLL[name]
		return #p.pieces + (colls and #colls or 1), p
	end
	local function kitAt(name, x, z, ry, o)
		local cost, p = kitCost(name)
		if not cost or left < cost then
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
	-- the same on the L0 floor under the mall (floor y 0, inside the walkable floor polygon, clear of columns and walls)
	local function kitAtL0(name, x, z, ry, o)
		local cost, p = kitCost(name)
		if not cost or left < cost then
			return false
		end
		local sz = p.size
		local a = math.rad(ry or 0)
		local ca, sa = math.cos(a), math.sin(a)
		local hx, hz = (math.abs(ca) * sz.X + math.abs(sa) * sz.Z) / 2, (math.abs(sa) * sz.X + math.abs(ca) * sz.Z) / 2
		local y = G.freeL0(x, z, hx, hz, sz.Y)
		if not y then
			return false
		end
		local m = Kit.place(dm, name, CF(x, y, z, ry), { shadows = true, tint = o and o.tint })
		if not m then
			return false
		end
		left -= cost
		box(x, y, z, hx, hz, sz.Y)
		return true
	end

	local yardById, yardBox = {}, {}
	for _, y in L.yards do
		yardById[y[1]] = y
		local x0, z0, x1, z1 = bbox(y[10])
		yardBox[y[1]] = { x0, z0, x1, z1 }
	end
	local function randomIn(yard) -- a random point in a yard's outline
		local b = yardBox[yard[1]]
		for _ = 1, 12 do
			local x, z = drng:NextNumber(b[1], b[3]), drng:NextNumber(b[2], b[4])
			if G.inPoly(yard[10], x, z) then
				return x, z
			end
		end
		return nil
	end
	-- the extract zones are up to 30 studs across: a keep-out wide enough to cover their corners
	for _, e in L.ext do
		G.keep(e[4], e[5], math.max(e[6], e[8]) * 0.75)
	end

	-- ── cars: paint, burnt shells and a few cover wrecks ─────────────────────────────────────────────────────
	local PAINT = { hex("6C7A80"), hex("7A5C4E"), hex("5E6B52"), hex("8A8680"), hex("4D5B6E"), hex("6B3A32"), hex("A39E92"), hex("3F4F47") }
	local BURNT = { hex("2B2926"), hex("34302B"), hex("3C362F"), hex("262523") }
	local CARS = { "CarSedan", "CarSedan", "CarSedan", "CarHatch", "CarHatch", "CarSedanSmashed", "CarSedanSmashed", "wreck" }
	local ITEM = { road = true, bld = 2 }
	-- a car of a random kind at (x, z); `side` (-1 or 1) is the flank an item may lie on, tested before the car's box goes in
	local function carAt(x, z, ry, o, side, kindOverride)
		local kind = kindOverride or CARS[drng:NextInteger(1, #CARS)]
		local burnt = drng:NextNumber() < 0.28
		o.tint = burnt and BURNT[drng:NextInteger(1, #BURNT)] or PAINT[drng:NextInteger(1, #PAINT)]
		local item = nil
		if n.loose < 26 and drng:NextNumber() < 0.4 then
			local a = math.rad(ry)
			local lx, lz = x + math.cos(a) * 5.6 * side, z - math.sin(a) * 5.6 * side
			local iy = G.free(lx, lz, 0.5, 0.5, 1.5, ITEM)
			if iy then
				item = { lx, iy, lz }
			end
		end
		local ok
		if kind == "wreck" then
			ok = coverAt("CarWreck", x, z, ry, burnt and o.tint or nil, o)
		else
			ok = kitAt(kind, x, z, ry, o)
		end
		if ok then
			n.car += 1
			if burnt then
				n.burnt += 1
			end
			if item then
				kit.loose(O.X + item[1], item[2] + 0.3, O.Z + item[3], "junk", 0.4, "meridian", true)
				G.keep(item[1], item[3], 3)
				n.loose += 1
			end
		end
		return ok
	end

	-- ── the five west car parks: cars in the bays Ground marks, about one bay in eight taken ────────────────────
	try("lots", function()
		local BAY, DEPTH, AISLE = 7.8, 15.6, 21.9
		local LO = { slope = 0.3, shadows = true, bld = 4 }
		for _, y in L.yards do
			if y[9] == 1 then
				local cx, cz, w, d, rot, pts = y[4], y[5], y[6], y[7], y[8], y[10]
				local a = math.rad(rot)
				local ca, sa = math.cos(a), math.sin(a)
				-- the rows across the lot, as Ground lays them: a single row on the edge, double rows between aisles
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
				local bays = {}
				for _, row in rows do
					local vc, depth = row[1], row[2]
					local lanes = { vc }
					if depth > DEPTH + 1 then
						lanes = { vc - DEPTH / 2, vc + DEPTH / 2 }
					end
					for _, lv in lanes do
						local u = -w / 2 + 6 + BAY / 2
						while u < w / 2 - 6 do
							table.insert(bays, { u, lv })
							u += BAY
						end
					end
				end
				shuffle(bays)
				local want = math.max(6, math.floor(#bays / 8))
				local got = 0
				for _, bay in bays do
					if got >= want or left < 40 then
						break
					end
					local px = cx + bay[1] * ca - bay[2] * sa + drng:NextNumber(-0.4, 0.4)
					local pz = cz + bay[1] * sa + bay[2] * ca + drng:NextNumber(-0.4, 0.4)
					if G.inPoly(pts, px, pz) then
						local ry = -rot + 180 * drng:NextInteger(0, 1) + drng:NextNumber(-3, 3)
						if carAt(px, pz, ry, LO, 1) then
							got += 1
						end
					end
				end
			end
		end
	end)

	-- ── the car parks under the mall: cars in the zones and garages, on the floor polygon ──────────────────────
	try("garages", function()
		local zones = {
			{ "CAR PARK A", 8 }, { "CAR PARK B", 7 }, { "CAR PARK C", 8 }, { "CAR PARK D", 7 },
			{ "NESTA GARAGE", 3 }, { "KASSA GARAGE", 4 }, { "BOLTWORKS GARAGE", 3 },
		}
		local byName = {}
		for _, s in L.mall.levels[1].stores do
			byName[s.name] = s
		end
		local KINDS = { "CarSedan", "CarSedan", "CarHatch", "CarHatch", "CarSedanSmashed" }
		local tint = {}
		for _, zt in zones do
			local s = byName[zt[1]]
			if s then
				local x0, z0, x1, z1 = bbox(s.pts)
				local got = 0
				for _ = 1, zt[2] * 16 do
					if got < zt[2] and left >= 14 then
						local x, z = drng:NextNumber(x0 + 8, x1 - 8), drng:NextNumber(z0 + 8, z1 - 8)
						if G.inL0(x, z) then
							local ry = 90 * drng:NextInteger(0, 1) + 180 * drng:NextInteger(0, 1) + drng:NextNumber(-3, 3)
							local burnt = drng:NextNumber() < 0.25
							tint.tint = burnt and BURNT[drng:NextInteger(1, #BURNT)] or PAINT[drng:NextInteger(1, #PAINT)]
							if kitAtL0(KINDS[drng:NextInteger(1, #KINDS)], x, z, ry, tint) then
								got += 1
								n.l0 += 1
								if burnt then
									n.burnt += 1
								end
								if got % 3 == 1 and n.loose < 26 then
									local ia = math.rad(ry)
									local ix, iz = x + math.cos(ia) * 5.8, z - math.sin(ia) * 5.8
									if G.inL0(ix, iz) and not G.blocked(ix, iz, 2) and not G.hits(V(ix - 1, 0.3, iz - 1), V(ix + 1, 2, iz + 1)) then
										kit.loose(O.X + ix, 0.4, O.Z + iz, "junk", 0.4, "meridian", true)
										G.keep(ix, iz, 3)
										n.loose += 1
									end
								end
							end
						end
					end
				end
			end
		end
	end)

	-- ── wrecks on the road shoulders (a third on the road, against its edge) ──────────────────────────────────
	local WO = { road = true, slope = 0.3, shadows = true, bld = 2 }
	try("wrecks", function()
		-- candidates along the roads, spaced by road class, shuffled
		local GAP = { H = 170, T = 420, G = 500 }
		local cands = {}
		for _, rd in L.roads do
			local p = rd[4]
			local total, segs = 0, {}
			for i = 1, #p - 3, 2 do
				local len = math.sqrt((p[i + 2] - p[i]) * (p[i + 2] - p[i]) + (p[i + 3] - p[i + 1]) * (p[i + 3] - p[i + 1]))
				table.insert(segs, { i, len, total })
				total += len
			end
			local cnt = math.floor(total / (GAP[rd[2]] or 420))
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
		for _, c in cands do
			if n.wreck < 40 and left > 200 then
				local side = 1
				if drng:NextNumber() < 0.5 then
					side = -1
				end
				local off = c.half + 4.5 + drng:NextNumber(0, 3) -- on the shoulder
				if drng:NextNumber() < 0.33 then
					off = c.half - 3.5 -- on the road, against its edge
				end
				local x, z = c.x - c.dz * side * off, c.z + c.dx * side * off
				local ry = math.deg(math.atan2(c.dx, c.dz)) + 180 * drng:NextInteger(0, 1) + drng:NextNumber(-22, 22)
				-- mostly rusted cover wrecks (one part), now and then a whole kit car
				local kind = (drng:NextNumber() < 0.6) and "wreck" or nil
				if carAt(x, z, ry, WO, side, kind) then
					n.wreck += 1
				end
			end
		end
	end)

	-- ── furniture of the car parks: trolleys, barriers, cones, bins, lamps ────────────────────────────────────
	local CONE = hex("D9601E")
	local function coneAt(x, z)
		if left < 2 then
			return false
		end
		local y = G.free(x, z, 0.5, 0.5, 2.1, ITEM)
		if not y then
			return false
		end
		local a = kit.vcyl(dm, 1.0, 1.1, O.X + x, y, O.Z + z, CONE, M.Plastic)
		local b = kit.vcyl(dm, 1.1, 0.55, O.X + x, y + 0.95, O.Z + z, CONE, M.Plastic)
		for _, p in { a, b } do
			p.CanCollide = false
			p.CanQuery = false
			p.CastShadow = false
			p:SetAttribute("NoDetail", true)
		end
		left -= 2
		box(x, y, z, 0.6, 0.6, 2.1)
		n.cone += 1
		return true
	end
	-- a short row of cones from (x, z) along (dx, dz)
	local function coneRow(x, z, dx, dz, cnt, gap)
		for k = 0, cnt - 1 do
			coneAt(x + dx * gap * k + drng:NextNumber(-0.4, 0.4), z + dz * gap * k + drng:NextNumber(-0.4, 0.4))
		end
	end
	-- ── roads into the hills: a row of concrete barriers closes each road 6 studs short of the limit, clear of the exit
	-- zones and the spawns (Maps/RoadEnds.luau; the RESCUE CHECKPOINT road has its own gate) ─────────────────────────
	try("road ends", function()
		local inside = B.insideLimit
		if not inside then
			return
		end
		local spawnsAt = {}
		for _, sp in W.spawns or {} do
			table.insert(spawnsAt, Vector2.new(sp.cf.Position.X - O.X, sp.cf.Position.Z - O.Z))
		end
		require(script.Parent.Parent.RoadEnds).new({
			L = L, inside = inside, spawns = spawnsAt, rng = drng, size = COVER.BarrierBroken,
			place = function(kind, x, z, ry, sz)
				local y = ground(x, z) + 0.16
				Props.cover(dm, kind, CF(x, y, z, ry), nil)
				left -= 1 -- one mesh part, as coverAt counts it
				local a = math.rad(ry)
				local hx = (math.abs(math.cos(a)) * sz.X + math.abs(math.sin(a)) * sz.Z) / 2
				local hz = (math.abs(math.sin(a)) * sz.X + math.abs(math.cos(a)) * sz.Z) / 2
				box(x, y, z, hx, hz, sz.Y)
				n.barrier += 1
			end,
		}).edges()
	end)

	try("furniture", function()
		local lots = {}
		for _, y in L.yards do
			if y[9] == 1 then
				table.insert(lots, y)
			end
		end
		for _, y in lots do
			local p = y[10]
			-- trolley bays and tipped trolleys on the aisles
			local done = 0
			for _ = 1, 40 do
				if done < 4 and left > 30 then
					local x, z = randomIn(y)
					if x then
						local tipped = done == 3
						local ry = 90 * drng:NextInteger(0, 1) + drng:NextNumber(-12, 12)
						if kitAt(tipped and "TrolleyTipped" or "TrolleyRow", x, z, ry, nil) then
							done += 1
							n.trolley += 1
						end
					end
				end
			end
			-- boom barriers where the lot meets a road: on an edge midpoint within 45 studs of one, set 4 studs inside it
			local barriers = 0
			for i = 1, #p - 1, 2 do
				local j = i + 2
				if j > #p then
					j = 1
				end
				local ax, az, bx, bz = p[i], p[i + 1], p[j], p[j + 1]
				local len = math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
				if len > 30 and barriers < 2 and left > 30 then
					local dx, dz = (bx - ax) / len, (bz - az) / len
					local mx, mz = ax + (bx - ax) * drng:NextNumber(0.3, 0.7), az + (bz - az) * drng:NextNumber(0.3, 0.7)
					if G.roadEdge(mx, mz) < 45 then
						local nx, nz = -dz, dx
						if not G.inPoly(p, mx + nx * 6, mz + nz * 6) then
							nx, nz = -nx, -nz -- toward the inside
						end
						local px, pz = mx + nx * 5, mz + nz * 5
						local ry = math.deg(math.atan2(-dz, dx))
						if kitAt("ParkingBarrier", px, pz, ry, { road = true, bld = 2 }) then
							barriers += 1
							n.barrier += 1
							coneRow(px + nx * 5 - dx * 6, pz + nz * 5 - dz * 6, dx, dz, 4, 4)
						end
					end
				end
			end
			-- bins along the lot's edge
			local bins = 0
			for _ = 1, 30 do
				if bins < 3 and n.bin < 20 and left > 20 then
					local i = 2 * drng:NextInteger(1, #p // 2) - 1
					local ax, az = p[i], p[i + 1]
					local cx, cz = y[4], y[5]
					local k = drng:NextNumber(0.08, 0.22)
					local x, z = ax + (cx - ax) * k, az + (cz - az) * k
					if G.inPoly(p, x, z) and kitAt("Bin", x, z, drng:NextNumber(0, 360), nil) then
						bins += 1
						n.bin += 1
					end
				end
			end
		end
		-- a bin and a trolley at the booths and huts, a barrier beside each toll booth
		for _, b in L.blds do
			if b[4] == "booth" or b[4] == "hut" then
				local ang = drng:NextNumber(0, math.pi * 2)
				local r = math.max(b[7], b[8]) / 2 + 5
				local x, z = b[5] + math.cos(ang) * r, b[6] + math.sin(ang) * r
				if n.bin < 28 and left > 20 and kitAt("Bin", x, z, drng:NextNumber(0, 360), nil) then
					n.bin += 1
				end
				if b[4] == "booth" and n.barrier < 12 and left > 30 then
					local ry = -b[9] + 90
					local bx, bz = b[5] + math.cos(math.rad(b[9]) + math.pi / 2) * (b[8] / 2 + 12), b[6] + math.sin(math.rad(b[9]) + math.pi / 2) * (b[8] / 2 + 12)
					if kitAt("ParkingBarrier", bx, bz, ry, { road = true, bld = 2 }) then
						n.barrier += 1
					end
				end
			end
		end
		-- cones at the highway works
		for _, lb in L.labels do
			if lb[1] == "HIGHWAY WORKS" then
				for k = 0, 2 do
					coneRow(lb[2] + k * 14, lb[3] + k * 5, 1, 0.3, 5, 4.5)
				end
			end
		end
		-- street lamps: two in each lot, one on each dock apron (some flicker, one is dead)
		local function lampAt(x, z, state)
			if left < 3 or n.lamp >= 14 then
				return false
			end
			local y = G.free(x, z, 0.8, 0.8, 18, ITEM)
			if not y then
				return false
			end
			Props.lamp(dm, CF(x, y, z, drng:NextNumber(0, 360)), state)
			left -= 3
			box(x, y, z, 0.8, 0.8, 18)
			n.lamp += 1
			return true
		end
		local states = { false, false, "flicker", false, "dead", false }
		for _, y in L.yards do
			if y[9] == 1 or y[1] == 2 or y[1] == 18 then
				local want = (y[9] == 1) and 2 or 1
				local got = 0
				for _ = 1, 30 do
					if got < want then
						local x, z = randomIn(y)
						if x and lampAt(x, z, states[drng:NextInteger(1, #states)] or nil) then
							got += 1
						end
					end
				end
			end
		end
	end)

	-- ── the camps and posts: sandbags, tyres, drums, a broken barrier ─────────────────────────────────────────
	try("camps", function()
		local THEMES = {
			{ { "k", "Sandbags" }, { "k", "Sandbags" }, { "k", "Drum" } },
			{ { "k", "TyreStack" }, { "c", "BarrierBroken" }, { "k", "JerryCans" } },
			{ { "c", "DrumDented" }, { "k", "Sandbags" }, { "k", "PalletBoxes" } },
			{ { "c", "Sandbags" }, { "c", "TyreStack" }, { "k", "Drum" } },
		}
		local DRUMS = { C.blue, C.rust, C.olive, C.red }
		local CO = { bld = 2 }
		-- a theme of three pieces round (cx, cz)
		local function cluster(cx, cz, spread)
			local base = drng:NextNumber(0, 360)
			local th = THEMES[drng:NextInteger(1, #THEMES)]
			for _, e in th do
				for _ = 1, 5 do
					local x, z = cx + drng:NextNumber(-spread, spread), cz + drng:NextNumber(-spread, spread)
					local ry = base + drng:NextNumber(-25, 25)
					local ok
					if e[1] == "c" then
						ok = coverAt(e[2], x, z, ry, e[2] == "DrumDented" and DRUMS[drng:NextInteger(1, #DRUMS)] or nil, CO)
					else
						ok = kitAt(e[2], x, z, ry, CO)
					end
					if ok then
						n.camp += 1
						break
					end
				end
			end
		end
		-- every hut of the two camps gets a cluster beside it, one in two for the sheds and booths
		for _, b in L.blds do
			if b[4] == "camp" or b[4] == "rescue" or b[4] == "check" then
				local ang = drng:NextNumber(0, math.pi * 2)
				local r = math.max(b[7], b[8]) / 2 + 8
				cluster(b[5] + math.cos(ang) * r, b[6] + math.sin(ang) * r, 4)
			elseif (b[4] == "shed" or b[4] == "kart") and drng:NextNumber() < 0.5 then
				local ang = drng:NextNumber(0, math.pi * 2)
				local r = math.max(b[7], b[8]) / 2 + 7
				cluster(b[5] + math.cos(ang) * r, b[6] + math.sin(ang) * r, 3)
			end
		end
		-- named points: the checkpoint gate, the substation gate, the middle of each camp
		for _, key in { "RESCUE_GATE", "RESCUE_CHECKPOINT", "SUBSTATION_GATE", "SUBSTATION_UTILITY", "RESCUE_CAMP", "WEST_CAMP", "KART_PIT" } do
			local p = pointOf(points[key])
			if p then
				local px, pz = p.X - O.X, p.Z - O.Z
				for _ = 1, 2 do
					local ang = drng:NextNumber(0, math.pi * 2)
					cluster(px + math.cos(ang) * 13, pz + math.sin(ang) * 13, 4)
				end
			end
		end
	end)

	-- ── docks and yards: clutter by what the yard is, vans on the aprons, containers in the cargo yards ──────
	try("docks", function()
		local DRUMS = { C.blue, C.rust, C.olive, C.red }
		local THEMES = {
			{ { "k", "PalletBoxes", 2 }, { "c", "PalletStack", 1 } },
			{ { "k", "RollCage", 2 }, { "k", "CardboardPile", 1 } },
			{ { "c", "DrumDented", 2 }, { "k", "JerryCans", 1 }, { "k", "Drum", 1 } },
			{ { "c", "Dumpster", 1 }, { "k", "Bin", 1 }, { "k", "CardboardPile", 1 } },
			{ { "c", "TyreStack", 2 }, { "k", "Drum", 1 } },
			{ { "c", "CinderStack", 2 }, { "c", "BarrierBroken", 1 } },
			{ { "c", "CableReel", 1 }, { "c", "PalletStack", 1 }, { "k", "ToolChest", 1 } },
		}
		local YO = { bld = 3, slope = 0.25 }
		-- the yards that get clutter, with how much (area per cluster) and what themes suit them
		local YARDS = {
			[0] = { 7000, { 1, 2, 5, 7 } }, [1] = { 6500, { 3, 6, 7 } }, [2] = { 6500, { 1, 2, 4, 5 } }, [18] = { 6500, { 1, 2, 4, 5 } },
			[16] = { 7000, { 1, 4, 5, 6 } }, [17] = { 9000, { 4, 5, 6 } }, [19] = { 6000, { 1, 6, 7 } }, [7] = { 9000, { 1, 3, 6 } },
			[15] = { 9000, { 1, 3, 6 } }, [3] = { 6000, { 3, 7 } }, [4] = { 6500, { 3, 7 } }, [5] = { 6000, { 3, 7 } }, [6] = { 6000, { 3, 7 } },
			[8] = { 12000, { 5, 6 } },
		}
		for yid, spec in YARDS do
			local yard = yardById[yid]
			if yard then
				local want = math.clamp(math.floor(yard[6] * yard[7] / spec[1] + 0.5), 1, 9)
				for _ = 1, want do
					local cx, cz = nil, nil
					for _ = 1, 14 do
						local x, z = randomIn(yard)
						if x and G.free(x, z, 3.5, 3.5, 3, nil) then
							cx, cz = x, z
							break
						end
					end
					if cx and left > 60 then
						local base = drng:NextNumber(0, 360)
						for _, e in THEMES[spec[2][drng:NextInteger(1, #spec[2])]] do
							for _ = 1, e[3] do
								for _ = 1, 4 do
									local x, z = cx + drng:NextNumber(-5, 5), cz + drng:NextNumber(-5, 5)
									local ry = base + drng:NextNumber(-25, 25)
									local ok = false
									if e[1] == "c" then
										ok = coverAt(e[2], x, z, ry, e[2] == "DrumDented" and DRUMS[drng:NextInteger(1, #DRUMS)] or nil, YO)
									else
										ok = kitAt(e[2], x, z, ry, YO)
									end
									if ok then
										n.dock += 1
										break
									end
								end
							end
						end
					end
				end
			end
		end
		-- vans and a forklift on the aprons and the truck lot (a van costs 14 parts)
		local VANS = { [2] = 2, [18] = 2, [17] = 2, [16] = 1, [0] = 1, [19] = 1 }
		local VO = { slope = 0.2, shadows = true, bld = 4 }
		local VP = { hex("6C7A80"), hex("8A8680"), hex("A39E92"), hex("4D5B6E") }
		for yid, want in VANS do
			local yard = yardById[yid]
			if yard then
				local got = 0
				for _ = 1, 20 do
					if got < want and left > 120 then
						local x, z = randomIn(yard)
						if x then
							VO.tint = VP[drng:NextInteger(1, #VP)]
							local ry = -yard[8] + 90 * drng:NextInteger(0, 1) + 180 * drng:NextInteger(0, 1) + drng:NextNumber(-8, 8)
							if kitAt("Van", x, z, ry, VO) then
								got += 1
								n.dock += 1
							end
						end
					end
				end
			end
		end
		for _, yid in { 2, 18 } do
			local yard = yardById[yid]
			if yard then
				for _ = 1, 16 do
					local x, z = randomIn(yard)
					if x and left > 30 and kitAt("Forklift", x, z, drng:NextNumber(0, 360), YO) then
						n.dock += 1
						break
					end
				end
			end
		end
		-- shipping containers in rows on the two cargo yards (one part with the mesh, 17 without)
		local cost = 17
		if lib and lib:FindFirstChild("ZR_ENV_Container20") then
			cost = 1
		end
		local colors = { C.rust, C.blue, C.olive, C.teal, C.red, C.metal, C.orange }
		local CT = { bld = 4, slope = 0.2 }
		for _, yid in { 7, 15 } do
			local yard = yardById[yid]
			if yard then
				local b = yardBox[yid]
				local put = 0
				for _ = 1, 160 do
					if put < 10 and n.container < 20 and left >= cost * 2 + 40 then
						local x, z = drng:NextNumber(b[1], b[3]), drng:NextNumber(b[2], b[4])
						if G.inPoly(yard[10], x, z) then
							local ry = 90 * drng:NextInteger(0, 1) + 180 * drng:NextInteger(0, 1)
							local stack = drng:NextNumber() < 0.3
							local top = stack and 19.2 or 9.6
							local sx, sz = 22, 8.8
							local y, cx, cz, hx, hz = spotFree(x, z, sx, sz, 0, 0, ry, top, CT)
							if y then
								Props.container(dm, CF(x, y, z, ry), colors[drng:NextInteger(1, #colors)])
								left -= cost
								if stack then
									Props.container(dm, CF(x + drng:NextNumber(-0.5, 0.5), y + 9.5, z, ry), colors[drng:NextInteger(1, #colors)])
									left -= cost
								end
								box(cx, y, cz, hx, hz, top)
								put += 1
								n.container += 1
							end
						end
					end
				end
			end
		end
	end)

	-- ── nature along the boundary where Ground left room: bushes, grass, rocks ──────────────────────────────
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
				if not B.inside(ax + dx * len / 2 + nx * 12, az + dz * len / 2 + nz * 12) then
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
			if n.nature < 160 and left > 20 then
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
		"[ZR] Meridian dress: %d outdoor cars (%d of them on the road shoulders), %d on L0, %d burnt in all, %d trolleys, %d barriers, %d cones, %d bins, %d lamps, %d camp pieces, %d dock pieces, %d containers, %d nature, %d loose spots, %d parts",
		n.car, n.wreck, n.l0, n.burnt, n.trolley, n.barrier, n.cone, n.bin, n.lamp, n.camp, n.dock, n.container, n.nature, n.loose, parts
	))
	if parts > 2500 then
		warn("[ZR] Meridian dress: " .. parts .. " parts, over the budget of 2,500")
	end
end
