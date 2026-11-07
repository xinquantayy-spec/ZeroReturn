--!nonstrict
-- Meridian Mall play layer (the gameplay agent, part 3 of 3): everything a raid needs on top of the shell and the stores.
--   extracts   the seven Interchange extracts with our names on their spots, W.sideExtracts nw / se. SHELTER EXIT waits for the
--              mall power and then a lever hidden in the L2 washroom; FENCE GAP needs an empty backpack slot (rule nobag)
--   power      what MALL_POWER changes: the washroom lever wakes, the electric locks work (the IRONSIGHT doors, the MEDIQ store
--              room, the shelter's card door, UNIT 14: doors that name KEY_MM_IRON_FRONT / _GRATE, KEY_MEDIQ, CARD_MALL_VAULT or
--              KEY_MM_UNIT14 get `power`), and the IRONSIGHT alarm: about 3 s after its front door opens a red lamp flashes, the
--              siren sounds (ZR_SFX_Amb, silent until that asset is uploaded) and every AI in earshot comes to look, until the
--              security terminal (switch MM_ALARM) is used (or 60 s pass)
--   spawns     one PMC spawn per reference cluster, on the MallNW and MallSE halves of the perimeter (W.spawns, side nw / se)
--   AI         W.patrols and W.watchPosts (car parks, docks, the substation, the L1 and L2 galleries at their floor heights),
--              W.scavZones (the reference's points by level plus ours), W.boss = THE CARETAKER (60 %, five zones)
--   quests     W.visitZones
--   hazards    the east sniper band (stair-step strips, like Border Yard's) and the west minefield (hidden charges, lethal)
--   loose loot yards, aprons, camps and the car parks (Dress adds a spot at each parked car)
-- Everything that depends on the shell (L1 and L2 points, the washroom, the security terminal) is checked against the parts the
-- shell actually built (a floor of the right height under the point) and left out when it is missing, so this runs with or
-- without Mall.luau. B.geo: the geometry tests (footprints, roads, fences, rails, rocks, keep-outs, part boxes, floors) for Dress.
-- Local coordinates (x east, z south), world positions through H.V.
return function(B)
	local kit, W, H, L, map = B.kit, B.W, B.H, B.L, B.map
	local V = H.V
	local O = B.O
	local ground = B.ground
	local M, hex = kit.M, kit.hex
	local points = B.points
	local rng = Random.new(9913)
	local LV = { [0] = L.H.ground, [1] = L.H.L1, [2] = L.H.L2 }
	local n = { spawn = 0, strip = 0, mine = 0, loose = 0, post = 0, door = 0 }
	local okH, Hazards = pcall(function()
		return require(script.Parent.Parent.Parent:WaitForChild("Services"):WaitForChild("Hazards"))
	end)
	if not okH then
		warn("[ZR] Meridian play: no Hazards service: " .. tostring(Hazards))
		Hazards = nil
	end

	local function try(name, f)
		local ok, err = pcall(f)
		if not ok then
			warn("[ZR] Meridian play: " .. name .. " failed: " .. tostring(err))
		end
	end
	local function loc(v) -- world position to map-local x, z
		return v.X - O.X, v.Z - O.Z
	end
	local function pointOf(p) -- a Vector3 or a CFrame from B.points, else nil
		if typeof(p) == "CFrame" then
			return p.Position
		elseif typeof(p) == "Vector3" then
			return p
		end
		return nil
	end

	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	-- geometry (Dress uses it too, as B.geo)
	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
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
		local best, cnt = math.huge, #p
		for i = 1, cnt - 1, 2 do
			local k = i + 2
			if k > cnt then
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
	local function lineD(p, x, z) -- distance to an open polyline
		local best = math.huge
		for i = 1, #p - 3, 2 do
			best = math.min(best, segD(x, z, p[i], p[i + 1], p[i + 2], p[i + 3]))
		end
		return best
	end
	G.segD, G.inPoly, G.polyDist = segD, inPoly, polyDist

	-- outdoor footprints (rotated rectangles) and the mall's outline
	local bl = {}
	for _, b in L.blds do
		local r = math.rad(b[9])
		local e = { id = b[1], name = b[2], kind = b[3], grp = b[4], cx = b[5], cz = b[6], hw = b[7] / 2, hd = b[8] / 2, c = math.cos(r), s = math.sin(r) }
		e.rad = math.sqrt(e.hw * e.hw + e.hd * e.hd) + 4
		table.insert(bl, e)
	end
	local MALL = { id = -1, name = "MERIDIAN", kind = "mall" }
	local MP, MB = L.mall.outline, L.mall.box
	local L0FLOOR = L.mall.levels[1].floor
	local function rectDist(r, x, z) -- signed distance to a rotated rectangle
		local dx, dz = x - r.cx, z - r.cz
		local u, v = dx * r.c + dz * r.s, -dx * r.s + dz * r.c
		local qx, qz = math.abs(u) - r.hw, math.abs(v) - r.hd
		if qx > 0 and qz > 0 then
			return math.sqrt(qx * qx + qz * qz)
		end
		return math.max(qx, qz)
	end
	function G.bldDist(x, z) -- studs to the nearest footprint or the mall (negative inside) and what it is
		local best, who = math.huge, nil
		for _, b in bl do
			local dx, dz = x - b.cx, z - b.cz
			if math.sqrt(dx * dx + dz * dz) - b.rad < best then
				local d = rectDist(b, x, z)
				if d < best then
					best, who = d, b
				end
			end
		end
		if x > MB[1] - best and x < MB[3] + best and z > MB[2] - best and z < MB[4] + best then
			local d = polyDist(MP, x, z)
			if d < best then
				best, who = d, MALL
			end
		end
		return best, who
	end
	function G.inL0(x, z) -- on the L0 floor of the mall (the car parks, garages and tunnels)
		return inPoly(L0FLOOR, x, z)
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
	function G.rockNear(x, z, pad) -- boulders (x, z, r flat) and the pylon bases
		local rk = L.rocks
		for i = 1, #rk - 2, 3 do
			local dx, dz = x - rk[i], z - rk[i + 1]
			local rr = rk[i + 2] + pad
			if dx * dx + dz * dz < rr * rr then
				return true
			end
		end
		local tw = L.towers
		for i = 1, #tw - 1, 2 do
			local dx, dz = x - tw[i], z - tw[i + 1]
			local rr = 9 + pad
			if dx * dx + dz * dz < rr * rr then
				return true
			end
		end
		return false
	end
	function G.edge(x, z) -- studs inside the playable boundary (negative outside)
		return -polyDist(L.boundary, x, z)
	end

	-- open ground: playable, dry, plain / concrete / gravel / asphalt, clear of footprints, fences, rails and the edge.
	-- o: bld, edge, road (minimum studs from a road's edge; nil allows roads), fence, rail
	function G.open(x, z, o)
		o = o or NOOPT
		if not B.inside(x, z) or B.wet(x, z) then
			return false
		end
		local cl = B.classAt(x, z)
		if cl == 1 or cl == 2 or cl >= 8 then
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
			local cnt = math.max(8, math.floor(ring * 1.3))
			for k = 0, cnt - 1 do
				local a = k / cnt * math.pi * 2
				local px, pz = x + math.cos(a) * ring, z + math.sin(a) * ring
				if ok(px, pz) then
					return px, pz
				end
			end
			ring += 4
		end
		return nil
	end

	-- keep-outs (gameplay): circles and route segments that clutter must stay away from. The circles live in a 48-stud grid (a
	-- circle is listed in every cell its box touches, a query reads every cell its own box touches), so thousands of loot spots
	-- inside the mall cost nothing.
	local KCELL, kgrid, NONE = 48, {}, {}
	function G.keep(x, z, r)
		local k = { x, z, r }
		table.insert(G.kp, k)
		for cx = math.floor((x - r) / KCELL), math.floor((x + r) / KCELL) do
			for cz = math.floor((z - r) / KCELL), math.floor((z + r) / KCELL) do
				local key = cx * 4096 + cz
				local list = kgrid[key]
				if not list then
					list = {}
					kgrid[key] = list
				end
				table.insert(list, k)
			end
		end
	end
	function G.keepSeg(ax, az, bx, bz, r)
		table.insert(G.ks, { ax, az, bx, bz, r })
	end
	function G.blocked(x, z, rq)
		for cx = math.floor((x - rq) / KCELL), math.floor((x + rq) / KCELL) do
			for cz = math.floor((z - rq) / KCELL), math.floor((z + rq) / KCELL) do
				for _, k in kgrid[cx * 4096 + cz] or NONE do
					local dx, dz = k[1] - x, k[2] - z
					local rr = k[3] + rq
					if dx * dx + dz * dz < rr * rr then
						return true
					end
				end
			end
		end
		for _, s in G.ks do
			if segD(x, z, s[1], s[2], s[3], s[4]) < s[5] + rq then
				return true
			end
		end
		return false
	end

	-- solid parts of the map in 32-stud buckets (built on first use, after the shell and the stores); boxes placed later are
	-- added with G.addBox so nothing overlaps
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
	local floors = nil -- [1] / [2] = boxes { x0, z0, x1, z1 } (local) of the parts whose top is at the L1 / L2 floor height
	local function ensureBuckets()
		if buckets then
			return
		end
		buckets = {}
		floors = { {}, {} }
		for _, p in map:GetDescendants() do
			if p:IsA("BasePart") and ((p.CanCollide and p.Transparency < 1) or p.Name == "KitCollider") then
				local cf, sz = p.CFrame, p.Size
				local e = ((cf.RightVector * sz.X):Abs() + (cf.UpVector * sz.Y):Abs() + (cf.LookVector * sz.Z):Abs()) / 2
				local pos = cf.Position
				if pos.Y + e.Y > ground(pos.X - O.X, pos.Z - O.Z) + 0.8 and e.X < 200 and e.Z < 200 then
					addToBuckets(pos - e, pos + e)
				end
				if p.CanCollide and p.Transparency < 1 and e.X > 2 and e.Z > 2 and e.Y < 6 then
					local top = pos.Y + e.Y
					for i = 1, 2 do
						if math.abs(top - LV[i]) < 0.7 then
							table.insert(floors[i], { pos.X - O.X - e.X, pos.Z - O.Z - e.Z, pos.X - O.X + e.X, pos.Z - O.Z + e.Z })
						end
					end
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
	-- is there a floor of level 1 (L1) or 2 (L2) under (x, z)? A part whose top sits at that level's height, measured on the parts
	-- the shell built. Level 0 is the L0 floor polygon inside the mall.
	function G.floorAt(level, x, z)
		if level == 0 then
			return inPoly(L0FLOOR, x, z)
		end
		ensureBuckets()
		for _, b in floors[level] or {} do
			if x >= b[1] and x <= b[3] and z >= b[2] and z <= b[4] then
				return true
			end
		end
		return false
	end
	-- is a footprint free? Returns the ground height. Local centre x, z; half sizes hx, hz in x and z; height h. o: road (true
	-- allows roads), bld (extra studs from buildings), edge, slope (limit), covered (a roof above is fine)
	local OP = {}
	function G.free(x, z, hx, hz, h, o)
		o = o or NOOPT
		local r = math.sqrt(hx * hx + hz * hz)
		OP.bld, OP.edge, OP.fence, OP.rail = (o.bld or 3) + r, o.edge or (12 + r), o.fence or (2 + r), o.rail or (6 + r)
		OP.road = nil
		if not o.road then
			OP.road = o.roadm or (r + 0.5)
		end
		if not G.open(x, z, OP) then
			return nil
		end
		if G.rockNear(x, z, r + 1) or B.slope(x, z) > (o.slope or 0.45) or G.blocked(x, z, r) then
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
	-- the same for the L0 floor under the mall: on the floor polygon (four corners), clear of keep-outs and of every solid part
	function G.freeL0(x, z, hx, hz, h)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				if not inPoly(L0FLOOR, x + sx * hx, z + sz * hz) then
					return nil
				end
			end
		end
		if G.blocked(x, z, math.sqrt(hx * hx + hz * hz) * 0.7) then
			return nil
		end
		local y = LV[0]
		if G.hits(V(x - hx, y + 0.35, z - hz), V(x + hx, y + h, z + hz)) then
			return nil
		end
		return y
	end

	-- a standing point on level `lvl` (0 = outdoors or L0): the floor must exist there
	local OPEN_STAND = { bld = 3, edge = 8, fence = 2, rail = 4 }
	local function standAt(x, z, lvl, snapR)
		if lvl > 0 then
			if G.floorAt(lvl, x, z) then
				return x, z, LV[lvl] + 0.5
			end
			return nil
		end
		if B.inMall(x, z) then
			if G.inL0(x, z) then
				return x, z, LV[0] + 0.5
			end
			return nil
		end
		local sx, sz = G.snap(x, z, snapR or 0, OPEN_STAND)
		if sx then
			return sx, sz, ground(sx, sz) + 0.5
		end
		return nil
	end
	local function levelOf(y)
		if y > 40 then
			return 2
		elseif y > 10 then
			return 1
		end
		return 0
	end

	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	-- power: the lever hidden in the L2 washroom (SHELTER EXIT's second step)
	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	W.sideExtracts = { nw = {}, se = {} }
	W.patrols = {}
	W.watchPosts = {}
	local leverOk = false
	try("lever", function()
		if W.switches.SHELTER_SWITCH then
			leverOk = true -- the shell built its own: the exit's rule still reads it
			return
		end
		local pt = points.SHELTER_SWITCH
		local p3 = pointOf(pt)
		local x, z, fy
		if p3 then
			x, z = loc(p3)
			fy = LV[0]
			for lvl = 2, 1, -1 do
				if p3.Y + 1 >= LV[lvl] then
					fy = LV[lvl]
					break
				end
			end
		else
			local w = L.poi.WASHROOM
			x, z, fy = w[1], w[2], LV[2]
		end
		local lvl = levelOf(fy + 1)
		if lvl > 0 and not G.floorAt(lvl, x, z) then
			warn("[ZR] Meridian play: no floor under the washroom lever; SHELTER EXIT stays a plain power exit")
			return
		end
		local m = kit.model("Shelter lever", map)
		local facing = (typeof(pt) == "CFrame") and pt.LookVector or Vector3.new(0, 0, 1)
		local at = Vector3.new(O.X + x, fy, O.Z + z)
		local base = CFrame.lookAt(at, at + Vector3.new(facing.X, 0, facing.Z))
		-- a water-service cabinet with a brass handle on its front (the "flush valve" the shelter chain starts from)
		kit.boxCF(m, 3.2, 6.2, 1.4, base * CFrame.new(0, 3.1, 0), hex("5E6A66"), M.Metal)
		kit.boxCF(m, 3.6, 0.5, 1.8, base * CFrame.new(0, 6.4, 0), hex("4A5450"), M.Metal)
		local lamp = kit.boxCF(m, 0.5, 0.5, 0.3, base * CFrame.new(0.9, 5.2, -0.75), hex("6F2A24"), M.SmoothPlastic)
		lamp.CanCollide = false
		local pivot = base * CFrame.new(0, 3.2, -0.95)
		local arm = kit.boxCF(m, 0.35, 2.0, 0.35, pivot * CFrame.new(0, 1.0, 0), hex("B8A66A"), M.Metal)
		local knob = kit.boxCF(m, 0.7, 0.7, 0.7, pivot * CFrame.new(0, 2.1, 0), hex("8E2F27"), M.SmoothPlastic)
		arm.CanCollide = false
		knob.CanCollide = false
		arm.Name = "LeverArm"
		local flip = pivot * CFrame.Angles(math.pi, 0, 0)
		local armOff, armOn = arm.CFrame, flip * CFrame.new(0, 1.0, 0)
		local knobOff, knobOn = knob.CFrame, flip * CFrame.new(0, 2.1, 0)
		local panel = kit.boxCF(m, 3.4, 6, 3.4, base * CFrame.new(0, 3.1, -1.8), hex("6C7A72"), M.Metal)
		panel.Name = "LeverPanel"
		panel.Transparency = 1
		panel.CanCollide = false
		panel:SetAttribute("NoDetail", true)
		m:SetAttribute("NoDetail", true)
		local pp = Instance.new("ProximityPrompt")
		pp.KeyboardKeyCode = Enum.KeyCode.F
		pp.ActionText = "Pull the handle"
		pp.ObjectText = "Service valve"
		pp.HoldDuration = 2
		pp.MaxActivationDistance = 8
		pp.RequiresLineOfSight = false
		pp.Style = Enum.ProximityPromptStyle.Custom
		pp.Parent = panel
		local leverOn, powered = false, false
		local function sync()
			pp.Enabled = powered and not leverOn
		end
		W.switches.SHELTER_SWITCH = {
			id = "SHELTER_SWITCH", label = "Service valve", part = panel, prompt = pp, delay = 3, startText = "PULLING THE HANDLE",
			doneText = "SOMETHING CLICKS BEHIND THE WALL",
			onChange = function(on)
				leverOn = on and true or false
				arm.CFrame = leverOn and armOn or armOff
				knob.CFrame = leverOn and knobOn or knobOff
				lamp.Color = leverOn and hex("6CC27A") or hex("6F2A24")
				lamp.Material = leverOn and M.Neon or M.SmoothPlastic
				sync()
			end,
		}
		-- the valve answers only while the mall has power (Interchange: the urinal keypad needs it)
		table.insert(B.powerHooks, function(on)
			powered = on and true or false
			sync()
		end)
		sync()
		points.SHELTER_SWITCH = points.SHELTER_SWITCH or V(x, fy + 3.3, z)
		leverOk = true
	end)

	-- THE SHELTER's door button (Tarkov's saferoom: once inside you close the door with the button by it, and only then
	-- does the exit count; the door stays shut for the rest of the raid, Doors.seal). A switch on the wall beside the card
	-- door, on the shelter side; SHELTER EXIT's rule reads it last (`last`).
	local buttonOk = false
	try("shelter button", function()
		if not leverOk then
			return
		end
		local door = nil
		for _, d in W.doors do
			if d.key == "CARD_MALL_VAULT" and d.cf and d.size then
				door = d
				break
			end
		end
		local room = pointOf(points.SHELTER_ROOM)
		if not (door and room) then
			return
		end
		local dcf = door.cf
		local n = Vector3.new(dcf.LookVector.X, 0, dcf.LookVector.Z).Unit
		if (room - dcf.Position):Dot(n) < 0 then
			n = -n
		end
		local right = n:Cross(Vector3.yAxis).Unit
		local floorY = dcf.Position.Y - door.size.Y / 2
		-- the wall face beside the door on the shelter side. The map is built away from the workspace, so no raycast:
		-- find a wall part (inside its box) half a stud behind the spot, then sit the button on that part's face
		local function solidAt(pt)
			for _, d in map:GetDescendants() do
				if d:IsA("BasePart") and d ~= door.part and d.CanCollide and (d.Position - pt).Magnitude < 40 then
					local lp = d.CFrame:PointToObjectSpace(pt)
					local h = d.Size / 2
					if math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z then
						return d
					end
				end
			end
			return nil
		end
		local wallAt = nil
		for _, side in { 1, -1 } do
			local beside = dcf.Position + right * side * (door.size.X / 2 + 1.4)
			beside = Vector3.new(beside.X, floorY + 4.2, beside.Z)
			local wall = solidAt(beside + n * 0.5)
			if wall then
				-- step out along n until clear of the wall's box: that is its face
				local face = beside
				for step = 0.5, 4, 0.1 do
					local q = beside + n * step
					local lp = wall.CFrame:PointToObjectSpace(q)
					local h = wall.Size / 2
					if not (math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z) then
						face = q
						break
					end
				end
				wallAt = face
				break
			end
		end
		if not wallAt then
			warn("[ZR] Meridian play: no wall beside the shelter door for its button; SHELTER EXIT keeps two steps")
			return
		end
		local m = kit.model("Shelter door button", map)
		local face = CFrame.lookAt(wallAt + n * 0.12, wallAt + n * 2)
		local plate = kit.boxCF(m, 0.9, 1.4, 0.2, face, hex("4B504C"), M.Metal)
		local btn = kit.boxCF(m, 0.45, 0.45, 0.2, face * CFrame.new(0, 0.2, -0.15), hex("8E2F27"), M.SmoothPlastic)
		btn.CanCollide = false
		plate:SetAttribute("NoDetail", true)
		m:SetAttribute("NoDetail", true)
		local pp = Instance.new("ProximityPrompt")
		pp.KeyboardKeyCode = Enum.KeyCode.F
		pp.ActionText = "Close the door"
		pp.ObjectText = "Door button"
		pp.HoldDuration = 0.6
		pp.MaxActivationDistance = 7
		pp.RequiresLineOfSight = false
		pp.Style = Enum.ProximityPromptStyle.Custom
		pp.Parent = plate
		local okD, Doors = pcall(function()
			return require(script.Parent.Parent.Parent:WaitForChild("Services"):WaitForChild("Doors"))
		end)
		if not okD then
			Doors = nil
		end
		W.switches.SHELTER_LOCK = {
			id = "SHELTER_LOCK", label = "Door button", part = plate, prompt = pp, delay = 1.2, startText = "THE DOOR IS CLOSING",
			doneText = "THE DOOR IS SHUT",
			onChange = function(on)
				btn.Color = on and hex("6CC27A") or hex("8E2F27")
				btn.Material = on and M.Neon or M.SmoothPlastic
				if on and Doors and Doors.seal then
					Doors.seal(door)
				end
			end,
		}
		buttonOk = true
	end)

	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	-- extracts: the seven (our names); the shelter and the service tunnel stand on the L0 floor under the mall
	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	-- transits (Tarkov 0.15; docs/design/TRANSITS.md): Interchange's transit to Customs is at the highway's south end (SPT
	-- icon at -193, 430 m on the aerial's edge; the playable ground ends at z 405 m, so ours stands at 395 m: -603, 1234)
	try("transits", function()
		local p = V(-603, ground(-603, 1234) + 0.1, 1234)
		W.transits = {
			{ id = "TR_BORDER", name = "TRANSIT TO BORDER YARD", to = "border", pos = p, size = Vector3.new(16, 10, 16), cf = CFrame.new(p + Vector3.new(0, 4.5, 0)) },
		}
	end)

	try("extracts", function()
		local ex = kit.model("Extracts", map)
		local sideIds = { nw = {}, se = {} }
		local UNDER = { SE = true, WC = true }
		for _, e in L.ext do
			local id, name, grp, x, z = e[1], e[2], e[3], e[4], e[5]
			local rule = table.clone(e[9])
			local y, opts = ground(x, z), nil
			if UNDER[id] then
				y, opts = LV[0] + 0.1, { compact = true }
			end
			if id == "SE" and leverOk then
				-- mall power first (the SUBSTATION lever), then the valve in the L2 washroom (Extract.blocked reads `also` first)
				rule = {
					kind = "power", switch = "SHELTER_SWITCH", also = "MALL_POWER",
					needs = "SEALED  ·  FIND THE VALVE HIDDEN IN A WASHROOM", needsAlso = rule.needs, time = rule.time,
					last = buttonOk and "SHELTER_LOCK" or nil, needsLast = "CLOSE THE DOOR WITH THE BUTTON BESIDE IT", who = rule.who,
				}
			end
			kit.extract(ex, id, name, V(x, y, z), Vector3.new(e[6], e[7], e[8]), rule, opts)
			if grp == "nw" or grp == "both" then
				table.insert(sideIds.nw, id)
			end
			if grp == "se" or grp == "both" then
				table.insert(sideIds.se, id)
			end
		end
		W.sideExtracts = sideIds
	end)

	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	-- electric locks and the IRONSIGHT alarm
	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	local ELECTRIC = { KEY_MM_IRON_FRONT = true, KEY_MM_IRON_GRATE = true, KEY_MEDIQ = true, CARD_MALL_VAULT = true, KEY_MM_UNIT14 = true }
	local alarm = { off = false, epoch = 0 }
	local function servicesModule(name)
		local ok, mod = pcall(function()
			return require(script.Parent.Parent.Parent:WaitForChild("Services"):WaitForChild(name))
		end)
		return ok and mod or nil
	end
	try("electric locks", function()
		-- doors the shell and the stores registered (they have no `map` yet): the keyed ones that need power get it
		for _, d in W.doors do
			if d.map == nil and d.key and ELECTRIC[d.key] and not d.power then
				d.power = "MALL_POWER"
				n.door += 1
			end
		end
	end)
	try("alarm", function()
		local door = nil
		for _, d in W.doors do
			if d.map == nil and d.key == "KEY_MM_IRON_FRONT" then
				door = d
				break
			end
		end
		if not door then
			return
		end
		local ax, az = L.hazard.ironAlarm[1], L.hazard.ironAlarm[2]
		local lamp = nil
		local siren = nil -- the shop's alarm bell: a looped Sound on the beacon (atmosphere pass); stays nil while Sounds.AMB_ATLAS is empty
		if G.floorAt(1, ax, az) then
			-- a red beacon hung from the ceiling over the shop (dark until the alarm rings)
			local m = kit.model("IRONSIGHT alarm", map)
			local top = L.H.ceil[2] - 1.2
			kit.boxCF(m, 0.4, 3, 0.4, CFrame.new(O.X + ax, top - 1.5 + 0.5, O.Z + az), hex("3A3E3C"), M.Metal)
			local b = kit.boxCF(m, 1.6, 1.2, 1.6, CFrame.new(O.X + ax, top - 3.6, O.Z + az), hex("6F2A24"), M.SmoothPlastic)
			b.CastShadow = false
			b.CanCollide = false
			b.Name = "AlarmBeacon"
			lamp = Instance.new("PointLight")
			lamp.Color = hex("FF3A2A")
			lamp.Range = 44
			lamp.Brightness = 3
			lamp.Shadows = false
			lamp.Enabled = false
			lamp.Parent = b
			local okA, AmbSound = pcall(function()
				return require(game:GetService("ReplicatedStorage"):WaitForChild("ZR"):WaitForChild("AmbSound"))
			end)
			if okA and AmbSound then
				siren = AmbSound.make("siren_loop", { parent = b, volume = 1, minDist = 14, maxDist = 150, name = "ZR_IronsightSiren" })
			end
		end
		local function ring(epoch)
			local AIm = servicesModule("AI")
			local t0, nextNoise = os.clock(), 0
			if siren then
				siren:Play() -- from the first flash until the terminal switches the alarm off (or after 60 s, like the lamp)
			end
			while os.clock() - t0 < 60 and alarm.epoch == epoch and not alarm.off do
				local t = os.clock() - t0
				if lamp then
					lamp.Enabled = (t % 1) < 0.5
					lamp.Parent.Material = lamp.Enabled and M.Neon or M.SmoothPlastic
				end
				if t >= nextNoise and AIm and AIm.hearShot then
					nextNoise = t + 5
					pcall(AIm.hearShot, Vector3.new(O.X + ax, LV[1] + 3, O.Z + az), nil, nil, 1.6)
				end
				task.wait(0.25)
			end
			if siren then
				siren:Stop()
			end
			if lamp then
				lamp.Enabled = false
				lamp.Parent.Material = M.SmoothPlastic
			end
		end
		-- watch the front door: three seconds after it opens the alarm rings (the door is locked again at every raid start)
		task.spawn(function()
			local seen = false
			while true do
				task.wait(0.5)
				if door.locked == true and not door.open then
					if seen then
						seen = false
						alarm.epoch += 1
					end
				elseif door.open and not seen then
					seen = true
					local e = alarm.epoch
					task.delay(3, function()
						if alarm.epoch == e and not alarm.off then
							ring(e)
						end
					end)
				end
			end
		end)
		-- the security terminal on the first floor switches the alarm off for the rest of the raid
		local tp = pointOf(points.SECURITY_TERMINAL)
		local tx, tz = L.poi.SECURITY_L1[1], L.poi.SECURITY_L1[2]
		if tp then
			tx, tz = loc(tp)
		end
		if G.floorAt(1, tx, tz) then
			local tm = kit.model("Alarm terminal", map)
			local base = CFrame.new(O.X + tx, LV[1], O.Z + tz)
			kit.boxCF(tm, 4.6, 3.2, 2.2, base * CFrame.new(0, 1.6, 0), hex("4A5450"), M.Metal)
			local screen = kit.boxCF(tm, 3.2, 2.2, 0.3, base * CFrame.new(0, 4.3, 0.4) * CFrame.Angles(math.rad(-12), 0, 0), hex("2A3A36"), M.SmoothPlastic)
			screen.CanCollide = false
			local pnl = kit.boxCF(tm, 5, 5, 4, base * CFrame.new(0, 2.5, -1), hex("6C7A72"), M.Metal)
			pnl.Transparency = 1
			pnl.CanCollide = false
			pnl:SetAttribute("NoDetail", true)
			tm:SetAttribute("NoDetail", true)
			local pp = Instance.new("ProximityPrompt")
			pp.KeyboardKeyCode = Enum.KeyCode.F
			pp.ActionText = "Disable the alarm"
			pp.ObjectText = "Security terminal"
			pp.HoldDuration = 2
			pp.MaxActivationDistance = 8
			pp.RequiresLineOfSight = false
			pp.Style = Enum.ProximityPromptStyle.Custom
			pp.Parent = pnl
			W.switches.MM_ALARM = {
				id = "MM_ALARM", label = "Security terminal", part = pnl, prompt = pp, delay = 2, startText = "ENTERING THE CODE", doneText = "IRONSIGHT ALARM DISABLED",
				onChange = function(on)
					alarm.off = on and true or false
					screen.Color = alarm.off and hex("3E8A5A") or hex("2A3A36")
					screen.Material = alarm.off and M.Neon or M.SmoothPlastic
				end,
			}
			points.SECURITY_TERMINAL = points.SECURITY_TERMINAL or V(tx, LV[1] + 3.3, tz)
		end
	end)

	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	-- PMC spawns: one per reference cluster, on its own half of the perimeter
	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	try("spawns", function()
		local SP = { bld = 6, edge = 4, fence = 3, rail = 6 }
		local function okSpawn(x, z)
			return G.open(x, z, SP) and B.slope(x, z) < 0.3
		end
		local spawns, spos = {}, {}
		for _, side in { "nw", "se" } do
			local tag = (side == "nw") and "N" or "S"
			local q = 0
			for _, c in L.clusters[side] do
				-- the group's own spawn point with the most room, nearest to its centre
				local best, bestScore, near, nearD = nil, -math.huge, nil, math.huge
				for _, p in L.pmc[side] do
					local dd = math.sqrt((p[1] - c[1]) * (p[1] - c[1]) + (p[2] - c[2]) * (p[2] - c[2]))
					if dd < nearD then
						near, nearD = p, dd
					end
					if dd <= 30 and okSpawn(p[1], p[2]) then
						local score = math.min(G.bldDist(p[1], p[2]), 14) - 0.1 * dd
						if score > bestScore then
							best, bestScore = p, score
						end
					end
				end
				local sx, sz, yaw = nil, nil, 0
				if best then
					sx, sz, yaw = best[1], best[2], best[4]
				elseif near then
					sx, sz = G.snap(near[1], near[2], 40, SP, okSpawn)
					yaw = near[4]
				end
				if sx then
					q += 1
					table.insert(spawns, {
						id = tag .. q,
						cf = CFrame.new(V(sx, ground(sx, sz) + 3.4, sz)) * CFrame.Angles(0, math.rad(yaw), 0),
						side = side,
					})
					table.insert(spos, { sx, sz })
				end
			end
		end
		-- names: the nearest area label or yard, each name once (the closest pairs first)
		local cand = {}
		for _, lb in L.labels do
			table.insert(cand, { lb[1], lb[2], lb[3] })
		end
		for _, y in L.yards do
			table.insert(cand, { y[2], y[4], y[5] })
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
			s.name = s.name or "MERIDIAN MALL"
			s.extracts = W.sideExtracts[s.side]
		end
		W.spawns = spawns
		n.spawn = #spawns
	end)

	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	-- AI: guard routes and posts
	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	-- { level, route points }: a car park lot, the NESTA dock apron, the substation apron, car park B (L0), the first-floor
	-- concourse loop (L1) and the upper gallery (L2). Every point must have its floor (outdoors: open ground within 20 studs, on
	-- L0 inside the walkable floor polygon, upstairs a floor part of the shell at that height).
	local ROUTES = {
		LOT = { 0, { { -310, -208 }, { -160, -208 }, { -160, -261 }, { -310, -261 } } },
		DOCK = { 0, { { 800, -880 }, { 830, -860 }, { 830, -640 }, { 790, -640 }, { 790, -860 } } },
		SUB = { 0, { { 770, -1100 }, { 840, -1100 }, { 840, -1060 }, { 770, -1060 } } },
		L0B = { 0, { { 60, -500 }, { 200, -500 }, { 200, -300 }, { 60, -300 } } },
		L1C = { 1, { { 266, -146 }, { 397, -146 }, { 397, 58 }, { 266, 58 } } },
		L2C = { 2, { { -3, -177 }, { 157, -177 }, { 266, -177 }, { 400, -177 }, { 400, -110 }, { 400, -177 }, { 266, -177 }, { 157, -177 } } },
	}
	local ROUTE_SRC = {} -- local x, z lists of the ground-level routes that were built, for the keep-outs
	local function buildRoute(spec)
		local lvl, out, src = spec[1], {}, {}
		for _, p in spec[2] do
			local x, z, y = standAt(p[1], p[2], lvl, 20)
			if x then
				table.insert(out, V(x, y, z))
				table.insert(src, { x, z })
			end
		end
		if #out < 2 then
			return nil
		end
		return out, src
	end
	try("posts", function()
		for id, spec in ROUTES do
			local r, src = buildRoute(spec)
			if r then
				W.patrols[id] = r
				if spec[1] == 0 then
					ROUTE_SRC[id] = src
				end
			end
		end
		-- the dock guard stands at the head of his apron, the others walk their route
		local posts = {}
		for _, wp in {
			{ "LOT", "Car Park Guard" }, { "DOCK", "Dock Guard", true }, { "SUB", "Substation Guard" },
			{ "L0B", "Garage Guard" }, { "L1C", "Concourse Guard" }, { "L2C", "Gallery Guard" },
		} do
			local r = W.patrols[wp[1]]
			if r then
				table.insert(posts, { route = wp[1], post = wp[3] and r[1] or nil, label = wp[2] })
			end
		end
		W.watchPosts = posts
		n.post = #posts
	end)

	-- ── THE CARETAKER (Interchange's Killa): 60 %, five zones (Tagilla is THE STOKER, below) ──
	local BOSS_ZONES = {
		{ "CENTRAL CONCOURSE", 1, { { 265.6, -143.8 }, { 330, -180 }, { 390, -150 }, { 330, -115 }, { 262, -115 }, { 200, -146 } } },
		{ "CENTRAL MALL", 2, { { 134.4, -137.5 }, { 134, -176 }, { 60, -176 }, { 60, -116 }, { 134, -116 } } },
		{ "KASSA HALL", 1, { { 631.2, -143.8 }, { 560, -120 }, { 560, -200 }, { 640, -240 }, { 700, -200 }, { 700, -100 } } },
		{ "BOLTWORKS HALL", 1, { { 265.6, 415.6 }, { 180, 380 }, { 180, 470 }, { 265, 520 }, { 350, 470 }, { 350, 380 } } },
		{ "NESTA HALL", 1, { { 265.6, -706.2 }, { 320, -640 }, { 400, -660 }, { 420, -740 }, { 340, -800 }, { 280, -780 } } },
	}
	try("boss", function()
		local cfg = L.bosses[1]
		local zones = {}
		for _, z in BOSS_ZONES do
			local r = buildRoute({ z[2], z[3] })
			if r and #r >= 3 then
				table.insert(zones, { name = z[1], home = r[1], route = r })
			end
		end
		if #zones == 0 then
			warn("[ZR] Meridian play: no floor under any of the Caretaker's zones; no boss on this map")
			return
		end
		W.boss = {
			name = "THE CARETAKER", label = "Caretaker", home = zones[1].home, look = "bodyguard", loadout = "caretakerLoadout",
			route = zones[1].route, crew = {}, chance = (cfg and cfg.chance) or 0.6, zones = zones,
			hp = 890 / 440, -- Killa's 890 (EFT; audit ai.2)
		}
	end)

	-- ── THE STOKER (Interchange's Tagilla; docs/design/BOSS_STOKER.md): 35 % (2026 Season 1 sources), alone, in the KASSA
	-- GARAGE under the hypermarket (the reference's hammer marker at L0 756, -431). 1,220 health, the hammer charge, the
	-- welding mask and a 12 gauge. Each boss rolls on its own (AI.reset reads W.bosses); W.boss stays the Caretaker.
	try("stoker", function()
		local r = buildRoute({ 0, { { 756.2, -431.2 }, { 840, -431 }, { 840, -300 }, { 760, -250 }, { 680, -300 }, { 680, -420 } } })
		if not r or #r < 3 then
			warn("[ZR] Meridian play: no floor for THE STOKER's garage route; he is left out")
			return
		end
		local stoker = {
			name = "THE STOKER", label = "Stoker", home = r[1], route = r, look = "stoker", loadout = "stokerLoadout", crew = {},
			chance = 0.35, hp = 1220 / 440, charge = true, zones = { { name = "KASSA GARAGE", home = r[1], route = r } },
		}
		W.bosses = W.boss and { W.boss, stoker } or { stoker }
	end)

	-- ── scav spawn zones ─────────────────────────────────────────────────────────────────────────────────
	local ZONE_SRC = {} -- local x, z of the ground-level zones, for the keep-outs
	try("scav", function()
		local zones, zpts, perBld = {}, {}, {}
		local function addZone(x, z, y, lvl)
			for _, q in zpts do
				if q[3] == lvl and (q[1] - x) * (q[1] - x) + (q[2] - z) * (q[2] - z) < 144 then
					return false
				end
			end
			table.insert(zpts, { x, z, lvl })
			table.insert(zones, V(x, y, z))
			if lvl == 0 then
				table.insert(ZONE_SRC, { x, z })
			end
			return true
		end
		local SCAV = { bld = 8, edge = 10, fence = 2.5 }
		local function indoorsOrOpen(x, z, y)
			local lvl = levelOf(y)
			if lvl > 0 then
				if G.floorAt(lvl, x, z) then
					return addZone(x, z, LV[lvl] + 0.4, lvl)
				end
				return false
			end
			if B.inMall(x, z) then
				if G.inL0(x, z) then
					return addZone(x, z, LV[0] + 0.4, 0)
				end
				return false
			end
			if not B.inside(x, z) then
				return false
			end
			local d, b = G.bldDist(x, z)
			if d >= 3 and G.open(x, z, SCAV) then
				return addZone(x, z, ground(x, z) + 0.3, 0)
			elseif b and b.id >= 0 and b.kind ~= "tower" and (perBld[b.id] or 0) < 4 then
				local sx, sz = G.snap(x, z, 70, SCAV)
				if sx and addZone(sx, sz, ground(sx, sz) + 0.3, 0) then
					perBld[b.id] = (perBld[b.id] or 0) + 1
					return true
				end
			end
			return false
		end
		-- the reference's scav and boss-zone points, each at its own level
		for _, zone in L.scav do
			for _, lst in { zone[7], zone[8] } do
				for q = 1, #lst, 4 do
					indoorsOrOpen(lst[q], lst[q + 1], lst[q + 2])
				end
			end
		end
		for _, ic in L.aiIcons do
			local lvlTag = ic[3]
			local y = 0
			if lvlTag == "L1" then
				y = LV[1]
			elseif lvlTag == "L2" then
				y = LV[2]
			end
			indoorsOrOpen(ic[1], ic[2], y)
		end
		-- ours: the car parks, the aprons, the yards, the camps, the halls and galleries on both floors
		local OUT = {
			{ -237, -460 }, { -236, -214 }, { -237, -58 }, { -237, 166 }, { -237, 507 }, { 806, -752 }, { 806, 458 }, { 1004, 316 },
			{ 156, 838 }, { -160, 864 }, { 500, -1058 }, { -226, -765 }, { -570, -10 }, { -1180, 400 }, { -1250, 300 }, { -1100, 480 },
			{ 640, 720 }, { 1260, 845 }, { 940, -1080 }, { 1010, -980 }, { 930, 0 }, { 1130, 600 }, { 20, 760 }, { -700, 300 },
			{ -800, -300 }, { -950, -700 }, { 300, -1100 }, { 1100, -700 },
		}
		for _, a in OUT do
			indoorsOrOpen(a[1], a[2], 0)
		end
		for _, a in { { 142, -773 }, { 80, -400 }, { 150, 55 }, { 156, 445 }, { 570, -737 }, { 760, -360 }, { 540, 453 }, { 100, -300 } } do
			indoorsOrOpen(a[1], a[2], 0)
		end
		for _, a in { { 266, -146 }, { 397, -40 }, { 266, 58 }, { 130, -146 }, { 600, -150 }, { 265, 415 }, { 265, -706 }, { -3, -250 }, { 130, 140 }, { 491, -250 } } do
			indoorsOrOpen(a[1], a[2], LV[1])
		end
		for _, a in { { 134, -137 }, { 62, -176 }, { 400, -110 }, { 202, 193 }, { -3, 100 }, { 156, -487 }, { 365, 230 } } do
			indoorsOrOpen(a[1], a[2], LV[2])
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
		zone("SUBSTATION", pointOf(points.SUBSTATION_SWITCH) or V(900.9, 3.3, -1081.9), 16)
		zone("SHELTER", V(512.5, LV[0] + 3.3, 77.2), 14)
		zone("IRONSIGHT", V(L.hazard.ironAlarm[1], LV[1] + 3.3, L.hazard.ironAlarm[2]), 12)
		zone("CONCOURSE", V(265.6, LV[1] + 3.3, -143.8), 16)
		zone("WEST_CAMP", pointOf(points.WEST_CAMP) or V(-1180, 3.3, 400), 24)
		zone("RESCUE_CAMP", pointOf(points.RESCUE_CAMP) or V(640, 3.3, 740), 24)
		zone("KART_TRACK", V(-226.6, 3.3, -765.6), 24)
		W.visitZones = vz
	end)

	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	-- hazards
	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	-- the east sniper band: stair-step boxes down its length, each inside the band (the intersection of its edges' spans, so the
	-- playable side stays safe). Spawns and extracts near it stay clear.
	local function span(poly, z) -- x extent of a polygon along the line z
		local xa, xb = math.huge, -math.huge
		local cnt = #poly
		for i = 1, cnt - 1, 2 do
			local j = i + 2
			if j > cnt then
				j = 1
			end
			local az, bz = poly[i + 1], poly[j + 1]
			if (az > z) ~= (bz > z) then
				local x = poly[i] + (poly[j] - poly[i]) * (z - az) / (bz - az)
				xa, xb = math.min(xa, x), math.max(xb, x)
			end
		end
		return xa, xb
	end
	try("snipers", function()
		if not Hazards then
			return
		end
		local q = L.snipe.poly
		local clear = {}
		for _, s in W.spawns or {} do
			table.insert(clear, s.cf.Position)
		end
		for _, e in L.ext do
			table.insert(clear, V(e[4], 0, e[5]))
		end
		local zmin, zmax = math.huge, -math.huge
		for i = 2, #q, 2 do
			zmin, zmax = math.min(zmin, q[i]), math.max(zmax, q[i])
		end
		local STEP = 40
		local z = zmin
		while z < zmax - 1 do
			local za, zb = z, math.min(z + STEP, zmax)
			local lo, hi = -math.huge, math.huge
			for _, zs in { za + 1, (za + zb) / 2, zb - 1 } do
				local xa, xb = span(q, zs)
				lo, hi = math.max(lo, xa), math.min(hi, xb)
			end
			if lo < hi and hi - lo > 6 then
				Hazards.sniperZone(V(lo, -40, za), V(hi, 130, zb), clear)
				n.strip += 1
			end
			z += STEP
		end
	end)
	-- the west minefield: hidden charges on a jittered grid inside the band, none within 12 studs of its playable edge
	try("mines", function()
		if not Hazards then
			return
		end
		local q, inner = L.mine.poly, L.mine.inner
		local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
		for i = 1, #q - 1, 2 do
			x0, x1 = math.min(x0, q[i]), math.max(x1, q[i])
			z0, z1 = math.min(z0, q[i + 1]), math.max(z1, q[i + 1])
		end
		local STEP = 34
		local pts = {}
		local z = z0
		while z <= z1 do
			local x = x0
			while x <= x1 do
				local px, pz = x + rng:NextNumber(-9, 9), z + rng:NextNumber(-9, 9)
				if inPoly(q, px, pz) and lineD(inner, px, pz) > 12 then
					table.insert(pts, V(px, ground(px, pz), pz))
				end
				x += STEP
			end
			z += STEP
		end
		if #pts > 0 then
			Hazards.mineField(pts)
		end
		n.mine = #pts
	end)

	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	-- keep-outs for loot and Dress: spawns, extracts, ground routes, posts, zones, doors, containers, loose loot, named points
	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	try("keepouts", function()
		for _, s in W.spawns or {} do
			G.keep(s.cf.Position.X - O.X, s.cf.Position.Z - O.Z, 14)
		end
		for _, e in W.extracts or {} do
			if typeof(e.pos) == "Vector3" then
				local x, z = loc(e.pos)
				G.keep(x, z, math.max(e.size.X, e.size.Z) * 0.75)
			end
		end
		local function segs(list)
			for i = 1, #list do
				local a, b = list[i], list[i + 1] or list[1]
				G.keepSeg(a[1], a[2], b[1], b[2], 4.5)
			end
		end
		for _, list in ROUTE_SRC do
			segs(list)
		end
		for _, wp in W.watchPosts or {} do
			if wp.post and levelOf(wp.post.Y) == 0 and not B.inMall(loc(wp.post)) then
				local x, z = loc(wp.post)
				G.keep(x, z, 6)
			end
		end
		for _, p in ZONE_SRC do
			G.keep(p[1], p[2], 5)
		end
		for _, d in W.doors do
			if d.map == nil and d.cf then
				G.keep(d.cf.Position.X - O.X, d.cf.Position.Z - O.Z, 6)
			end
		end
		for _, c in W.containers do
			if c.map == "meridian" and c.part and c.part.Parent then
				G.keep(c.part.Position.X - O.X, c.part.Position.Z - O.Z, 5)
			end
		end
		for _, l in W.looseSpots or {} do
			G.keep(l.pos.X - O.X, l.pos.Z - O.Z, 3)
		end
		for _, p in points do
			local v = pointOf(p)
			if v then
				G.keep(v.X - O.X, v.Z - O.Z, 8)
			end
		end
	end)

	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	-- outdoor loose loot: the yards and aprons (by what they are), the camps' ground, the car parks under the mall
	-- ═══════════════════════════════════════════════════════════════════════════════════════════════════
	try("loose", function()
		local lp = {} -- local x, z of the spots so far
		local LOOT = { bld = 5, edge = 12, fence = 2, rail = 4 }
		local function spot(x, z, y, pool, chance)
			for _, q in lp do
				if (q[1] - x) * (q[1] - x) + (q[2] - z) * (q[2] - z) < 900 then
					return false
				end
			end
			table.insert(lp, { x, z })
			kit.loose(O.X + x, y, O.Z + z, pool, chance, "meridian", true)
			G.keep(x, z, 3)
			n.loose += 1
			return true
		end
		-- what lies in a yard depends on what it is: lots hold shopping and small change, docks crates, the substation pads tools
		local function poolFor(y)
			local name = y[2]
			if string.find(name, "WEST LOT", 1, true) or string.find(name, "TRUCK", 1, true) then
				return "mall"
			elseif string.find(name, "SUBSTATION", 1, true) then
				return "toolbox"
			elseif string.find(name, "DOCK", 1, true) or string.find(name, "SERVICE", 1, true) or string.find(name, "CARGO", 1, true) then
				return "crate"
			end
			return "junk"
		end
		for _, y in L.yards do
			local p = y[10]
			local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
			for i = 1, #p - 1, 2 do
				x0, x1 = math.min(x0, p[i]), math.max(x1, p[i])
				z0, z1 = math.min(z0, p[i + 1]), math.max(z1, p[i + 1])
			end
			local want = math.clamp(math.floor(y[6] * y[7] / 12000 + 0.5), 1, 6)
			local pool, got, tries = poolFor(y), 0, 0
			while got < want and tries < 40 do
				tries += 1
				local x, z = rng:NextNumber(x0, x1), rng:NextNumber(z0, z1)
				if inPoly(p, x, z) and G.open(x, z, LOOT) and not G.blocked(x, z, 2) and spot(x, z, ground(x, z) + 1.5, pool, 0.4) then
					got += 1
				end
			end
		end
		-- the camps: a spot beside each hut (the huts are one-room shells, the ground round them is the camp)
		for _, b in L.blds do
			if b[4] == "camp" or b[4] == "rescue" or b[4] == "hut" or b[4] == "booth" then
				local ang = rng:NextNumber(0, math.pi * 2)
				local r = math.max(b[7], b[8]) / 2 + 9
				local x, z = G.snap(b[5] + math.cos(ang) * r, b[6] + math.sin(ang) * r, 24, LOOT)
				if x and not G.blocked(x, z, 2) then
					spot(x, z, ground(x, z) + 1.5, "junk", 0.35)
				end
			end
		end
		-- the car parks under the mall: spots in the aisles of each zone and garage
		local L0Z = { { 70, -770 }, { 40, -400 }, { 90, 40 }, { 150, 440 }, { 560, -740 }, { 760, -380 }, { 540, 450 }, { 230, -690 }, { 220, 330 }, { 600, -820 } }
		for _, c in L0Z do
			for _ = 1, 3 do
				local x, z = c[1] + rng:NextNumber(-60, 60), c[2] + rng:NextNumber(-60, 60)
				if G.floorAt(0, x, z) and not G.blocked(x, z, 2) and not G.hits(V(x - 1, 0.3, z - 1), V(x + 1, 3, z + 1)) then
					spot(x, z, LV[0] + 1, "mall", 0.4)
				end
			end
		end
	end)

	local function count(t)
		local c = 0
		for _ in t or {} do
			c += 1
		end
		return c
	end
	print(string.format(
		"[ZR] Meridian play: %d spawns, %d patrol routes, %d watch posts, %d scav zones, boss %s (%d zones)%s, %d visit zones, %d sniper strips, %d mines, %d electric locks, %d loose spots, lever %s",
		n.spawn, count(W.patrols), count(W.watchPosts), count(W.scavZones), W.boss and W.boss.name or "none", W.boss and #W.boss.zones or 0,
		(W.bosses and W.bosses[2]) and (", " .. W.bosses[2].name .. " (" .. #W.bosses[2].route .. " route points)") or "",
		count(W.visitZones), n.strip, n.mine, n.door, n.loose, leverOk and "built" or "missing"
	))
end
