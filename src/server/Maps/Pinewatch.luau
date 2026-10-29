--!nonstrict
-- M13 map: PINEWATCH (woods-type). An original layout on rolling, pine-covered hills: a sawmill compound (saw shed,
-- office, bunkhouse, log yard), a convoy ambushed on the logging road, a lake with a boathouse and a jetty, an old
-- command shelter dug into the north ridge, a radio mast on a hilltop, a ranger station with a fire lookout, hunting
-- stands, a lakeside camp and a ruined hut. The ground is Roblox terrain written from a deterministic height function
-- (hills, the ridge, the lake basin, levelled yards, a graded logging road); trees, rocks, logs and bushes are the
-- Blender nature kit (ZR_Nature). Big and open: long sight lines broken by trunks, bushes and folds in the ground.
-- Built once at server start at its own origin. Local coordinates: x east, z south; heights are world y (the lake
-- surface is y = 0, the yards sit where the hills put them).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local AssetMeta = require(ReplicatedStorage:WaitForChild("ZR"):WaitForChild("AssetMeta"))
local Wear = require(ReplicatedStorage:WaitForChild("ZR"):WaitForChild("Wear"))

local O = Vector3.new(0, 0, 2000)
local PLAY = 256 -- playable half-extent (invisible walls just outside)
local EXT = 320 -- terrain half-extent (the hills beyond close the view)
local WL = 0 -- lake water level (a voxel boundary)
local R = 4 -- voxel size

return function(kit, root)
	local W, C, M, hex = kit.World, kit.C, kit.M, kit.hex
	local Props = kit.Props
	local rng = Random.new(2029)
	local map = kit.model("Pinewatch", root)
	local terrain = workspace.Terrain

	local function V(x, y, z)
		return Vector3.new(O.X + x, y, O.Z + z)
	end
	local function CF(x, y, z, ry)
		local c = CFrame.new(O.X + x, y, O.Z + z)
		if ry then
			c *= CFrame.Angles(0, math.rad(ry), 0)
		end
		return c
	end
	local function B(parent, sx, sy, sz, x, y, z, color, mat, ry)
		return kit.box(parent, sx, sy, sz, O.X + x, y, O.Z + z, color, mat, ry)
	end
	local function VC(parent, h, d, x, y, z, color, mat)
		return kit.vcyl(parent, h, d, O.X + x, y, O.Z + z, color, mat)
	end
	local function smooth(t)
		t = math.clamp(t, 0, 1)
		return t * t * (3 - 2 * t)
	end
	local function lerp(a, b, t)
		return a + (b - a) * t
	end

	-- ── the ground: a height function ───────────────────────────────────────────────────────────────────
	local LAKE = { x = 70, z = -40, rx = 80, rz = 55 }
	local function lakeD(x, z)
		local dx, dz = (x - LAKE.x) / LAKE.rx, (z - LAKE.z) / LAKE.rz
		return math.sqrt(dx * dx + dz * dz) + math.noise(x / 40 + 1.31, z / 40 + 2.27, 8.83) * 0.16
	end
	local MOUNDS = { { -150, -200, 46, 12 }, { 175, -172, 52, 16 } } -- the shelter hill, the radio hill: x, z, radius, height
	local function natural(x, z)
		local h = 12 + math.noise(x / 170 + 0.31, z / 170 + 0.77, 1.13) * 16
		h += math.noise(x / 62 + 3.17, z / 62 + 1.71, 2.93) * 6
		h += math.noise(x / 23 + 7.37, z / 23 + 5.13, 4.71) * 1.6
		h += smooth((-z - 120) / 110) * (24 + 8 * math.noise(x / 90 + 9.13, 0.57, 6.61)) -- the north ridge
		for _, m in MOUNDS do
			local dx, dz = x - m[1], z - m[2]
			h += m[4] * math.exp(-(dx * dx + dz * dz) / (m[3] * m[3]))
		end
		local e = math.max(math.abs(x), math.abs(z)) - 236 -- hills close the map beyond the playable area
		if e > 0 then
			h += (math.min(e, 84) / 84) ^ 1.5 * 30
		end
		local d = lakeD(x, z) -- the lake basin
		if d < 1.4 then
			local bed = lerp(-8, 1.2, smooth((d - 0.55) / 0.45))
			h = lerp(bed, h, smooth((d - 1) / 0.4))
		end
		return math.min(h, 60)
	end

	-- levelled yards (height taken from the hills at their centre unless given)
	local PADS = {
		sawmill = { x = -150, z = 140, hx = 62, hz = 50, blend = 26 },
		convoy = { x = 40, z = 94, hx = 46, hz = 16, blend = 18 },
		boathouse = { x = 150, z = -42, hx = 12, hz = 12, blend = 14, h = 2.2 },
		bunker = { x = -158, z = -153, hx = 20, hz = 19, blend = 16 }, -- the apron in front of the shelter's facade
		radio = { x = 175, z = -172, hx = 16, hz = 16, blend = 14 },
		ranger = { x = 160, z = 152, hx = 36, hz = 30, blend = 22 },
		camp = { x = -6, z = -40, hx = 10, hz = 10, blend = 12, h = 2.2 },
	}
	local PADLIST = { "sawmill", "convoy", "boathouse", "bunker", "radio", "ranger", "camp" }
	for _, name in PADLIST do
		local p = PADS[name]
		p.name = name
		p.h = p.h or math.floor(natural(p.x, p.z) * 2 + 0.5) / 2
	end
	local function inPad(x, z, margin)
		for _, name in PADLIST do
			local p = PADS[name]
			if math.abs(x - p.x) <= p.hx + margin and math.abs(z - p.z) <= p.hz + margin then
				return name
			end
		end
		return nil
	end
	local function padded(x, z)
		local h = natural(x, z)
		for _, name in PADLIST do
			local p = PADS[name]
			local dx = math.max(math.abs(x - p.x) - p.hx, 0)
			local dz = math.max(math.abs(z - p.z) - p.hz, 0)
			if dx < p.blend and dz < p.blend then
				local d = math.sqrt(dx * dx + dz * dz)
				if d < p.blend then
					h = lerp(p.h, h, smooth(d / p.blend))
				end
			end
		end
		return h
	end

	-- roads and tracks: polylines (local x, z) with a half width; only the logging road is graded (levelled across
	-- and cut through the hills), the tracks follow the ground
	local ROADS = {
		{ w = 6, flat = true, pts = { { -330, 124 }, { -250, 126 }, { -205, 146 }, { -160, 148 }, { -110, 136 }, { -60, 110 }, { -6, 94 }, { 40, 92 }, { 90, 86 }, { 130, 68 }, { 185, 40 }, { 250, 22 }, { 330, 18 } } },
		{ w = 3.5, pts = { { 30, 92 }, { 0, 50 }, { -40, 0 }, { -80, -60 }, { -120, -110 }, { -150, -140 } } }, -- the shelter track
		{ w = 3, pts = { { 150, 62 }, { 154, 20 }, { 151, -14 }, { 150, -32 } } }, -- down to the boathouse
		{ w = 3.5, pts = { { 130, 68 }, { 148, 110 }, { 160, 132 }, { 160, 176 }, { 158, 220 }, { 160, 330 } } }, -- the ranger track
		{ w = 3, pts = { { -150, -140 }, { -110, -176 }, { -50, -214 }, { 20, -238 }, { 38, -330 } } }, -- the ridge trail
		{ w = 3, pts = { { -40, 0 }, { -30, -30 }, { 10, -104 }, { 80, -112 }, { 130, -140 }, { 172, -160 } } }, -- the lake path to the radio hill
	}
	local SEGS = {}
	for _, r in ROADS do
		r.h = {}
		for i, p in r.pts do
			r.h[i] = padded(p[1], p[2])
		end
		for i = 1, #r.pts - 1 do
			local a, b = r.pts[i], r.pts[i + 1]
			local m = r.w + 8
			table.insert(SEGS, {
				r = r, i = i, ax = a[1], az = a[2], vx = b[1] - a[1], vz = b[2] - a[2],
				x0 = math.min(a[1], b[1]) - m, x1 = math.max(a[1], b[1]) + m, z0 = math.min(a[2], b[2]) - m, z1 = math.max(a[2], b[2]) + m,
			})
		end
	end
	-- the nearest road: distance from its edge (negative on it), its height there, the road, distance from its centre
	local function roadAt(x, z)
		local best, bh, br, bc = 99, 0, nil, 0
		for _, s in SEGS do
			if x >= s.x0 and x <= s.x1 and z >= s.z0 and z <= s.z1 then
				local t = math.clamp(((x - s.ax) * s.vx + (z - s.az) * s.vz) / (s.vx * s.vx + s.vz * s.vz), 0, 1)
				local px, pz = s.ax + s.vx * t - x, s.az + s.vz * t - z
				local c = math.sqrt(px * px + pz * pz)
				local d = c - s.r.w
				if d < best then
					best, bh, br, bc = d, lerp(s.r.h[s.i], s.r.h[s.i + 1], t), s.r, c
				end
			end
		end
		return best, bh, br, bc
	end
	-- the shelter under the ridge: rooms (interior x0, x1, z0, z1), dug straight into the voxel data (see the writer)
	-- behind a concrete facade at z = PORTAL; the ground over them is raised to give at least COVER of earth
	local FB = PADS.bunker.h
	local CEIL, PORTAL, COVER = 7.5, -172, 16.5
	local ROOMS = {
		E1 = { -153, -147, -196, -173 }, G = { -170, -154, -190, -176 }, DORM = { -180, -161, -212, -197 }, HALL = { -160, -141, -212, -197 },
		ARM = { -140, -124, -212, -197 }, E2 = { -153, -147, -226, -213 }, HATCH = { -160, -140, -238, -227 },
	}
	local ROOMLIST = { "E1", "G", "DORM", "HALL", "ARM", "E2", "HATCH" }
	local CAVE = {}
	for _, n in ROOMLIST do
		local r = ROOMS[n]
		table.insert(CAVE, { r[1] - 5.5, r[2] + 5.5, r[3] - 5.5, math.min(r[4] + 5.5, PORTAL) })
	end
	local function caveDist(x, z)
		local best = math.huge
		for _, c in CAVE do
			local dx = math.max(c[1] - x, 0, x - c[2])
			local dz = math.max(c[3] - z, 0, z - c[4])
			best = math.min(best, math.sqrt(dx * dx + dz * dz))
		end
		return best
	end
	local function inCave(x, z)
		return caveDist(x, z) == 0
	end
	local function ground(x, z)
		local h = padded(x, z)
		local d, rh, r = roadAt(x, z)
		if r and r.flat and d < 7 then
			h = lerp(rh, h, smooth(d / 7))
		end
		-- earth over the shelter (not in front of its facade)
		if z <= PORTAL or x < -178 or x > -138 then
			local cd = caveDist(x, z)
			if cd < COVER then
				h = math.max(h, FB + COVER - cd)
			end
		end
		return h, d
	end

	-- ── terrain voxels ─────────────────────────────────────────────────────────────────────────────────────
	local NX, NY, Y0 = (2 * EXT) / R, 19, -12
	local HG, LG, MG, CG = table.create(NX), table.create(NX), table.create(NX), table.create(NX) -- heights, lake, materials, shelter
	for i = 1, NX do
		local hc, lc, cc = table.create(NX), table.create(NX), table.create(NX)
		local x = -EXT + (i - 0.5) * R
		for k = 1, NX do
			local z = -EXT + (k - 0.5) * R
			hc[k] = (ground(x, z))
			lc[k] = lakeD(x, z) < 1.05
			cc[k] = inCave(x, z)
		end
		HG[i], LG[i], CG[i] = hc, lc, cc
	end
	-- ground height between column centres (what the voxels draw)
	local function hAt(x, z)
		local fx, fz = (x + EXT) / R + 0.5, (z + EXT) / R + 0.5
		local i0, k0 = math.clamp(math.floor(fx), 1, NX - 1), math.clamp(math.floor(fz), 1, NX - 1)
		local tx, tz = math.clamp(fx - i0, 0, 1), math.clamp(fz - k0, 0, 1)
		return lerp(lerp(HG[i0][k0], HG[i0 + 1][k0], tx), lerp(HG[i0][k0 + 1], HG[i0 + 1][k0 + 1], tx), tz)
	end
	local YARD = { sawmill = true, ranger = true, radio = true, bunker = true, convoy = true }
	local function surfaceMat(i, k)
		local x, z = -EXT + (i - 0.5) * R, -EXT + (k - 0.5) * R
		local h = HG[i][k]
		if LG[i][k] and h < 1.8 then
			return (h < -1.5) and M.Ground or M.Mud -- the lake bed and its muddy margin
		end
		local d, _, r, c = roadAt(x, z)
		if d < 0 then
			if r.flat and math.abs(c - r.w * 0.45) < 0.9 then
				return M.Mud -- wheel ruts
			end
			return M.Ground
		elseif d < 2.2 then
			return (math.noise(x / 6 + 0.5, z / 6 + 0.5, 3.3) > 0) and M.Ground or M.LeafyGrass
		end
		local i0, i1, k0, k1 = math.max(1, i - 1), math.min(NX, i + 1), math.max(1, k - 1), math.min(NX, k + 1)
		local sx = (HG[i1][k] - HG[i0][k]) / ((i1 - i0) * R)
		local sz = (HG[i][k1] - HG[i][k0]) / ((k1 - k0) * R)
		local slope = math.sqrt(sx * sx + sz * sz)
		if slope > 1.0 then
			return M.Rock
		elseif slope > 0.7 then
			return (math.noise(x / 9 + 1.1, z / 9 + 2.2, 5.5) > 0) and M.Slate or M.Ground
		end
		local pad = inPad(x, z, 0)
		if pad and YARD[pad] then
			-- worn earth with puddled mud; sawdust about the mill, stony patches elsewhere
			local n = math.noise(x / 11 + 0.7, z / 11 + 0.3, 7.1)
			if n > 0.25 then
				return M.Mud
			elseif n < -0.42 then
				return (pad == "sawmill") and M.Sand or M.Slate
			end
			return M.Ground
		end
		local n = math.noise(x / 34 + 4.4, z / 34 + 7.7, 9.9)
		if n > 0.16 then
			return M.Grass
		elseif n < -0.22 then
			return M.Ground
		end
		return M.LeafyGrass
	end
	for i = 1, NX do
		local mc = table.create(NX)
		for k = 1, NX do
			mc[k] = surfaceMat(i, k)
		end
		MG[i] = mc
	end
	local CH = 32
	for ci = 0, NX - 1, CH do
		for ck = 0, NX - 1, CH do
			local nx, nz = math.min(CH, NX - ci), math.min(CH, NX - ck)
			local mats, occs = table.create(nx), table.create(nx)
			for a = 1, nx do
				local i = ci + a
				local mcol, ocol = table.create(NY), table.create(NY)
				for j = 1, NY do
					local yb = Y0 + (j - 1) * R
					local mrow, orow = table.create(nz), table.create(nz)
					for b = 1, nz do
						local k = ck + b
						local hv = HG[i][k] - 2 -- Roblox draws the surface 2 studs above the occupancy height
						local occ = math.clamp((hv - yb) / R, 0, 1)
						local m
						if CG[i][k] then
							-- the shelter: rock under its floor slab, air for the rooms, earth over the ceiling slab
							local lo, hi = FB - 3, FB + CEIL + 3
							local below = math.clamp((lo - 2 - yb) / R, 0, 1)
							local above = math.min(math.clamp((yb + 2 - hi) / R, 0, 1), occ)
							if below > 0 then
								m, occ = (lo - yb < 8) and M.Ground or M.Rock, below
							elseif above > 0 then
								m, occ = (hv - yb < R * 2) and MG[i][k] or M.Ground, above
							else
								m, occ = M.Air, 0
							end
						elseif LG[i][k] and yb + R <= WL then
							-- under the lake surface: lake bed (the water fills what the bed leaves of a voxel) or water
							if occ > 0 then
								m = MG[i][k]
							else
								m, occ = M.Water, 1
							end
						elseif occ <= 0 then
							m = M.Air
						elseif hv - yb < R * 2 then
							m = MG[i][k]
						elseif hv - yb < 12 then
							m = M.Ground
						else
							m = M.Rock
						end
						mrow[b], orow[b] = m, occ
					end
					mcol[j], ocol[j] = mrow, orow
				end
				mats[a], occs[a] = mcol, ocol
			end
			local p0 = Vector3.new(O.X - EXT + ci * R, Y0, O.Z - EXT + ck * R)
			terrain:WriteVoxels(Region3.new(p0, p0 + Vector3.new(nx * R, NY * R, nz * R)), R, mats, occs)
		end
	end
	-- muted forest colours (only this map uses these terrain materials; Quay 7's harbour is water)
	for mat, col in { [M.Grass] = "5F6B45", [M.LeafyGrass] = "4D5A39", [M.Ground] = "5B4D3D", [M.Mud] = "4A4135", [M.Rock] = "6B6B64", [M.Slate] = "5E605A", [M.Sand] = "6B5E4A" } do
		terrain:SetMaterialColor(mat, hex(col))
	end

	local SY, CY, BY, HY, RY, KY = PADS.sawmill.h, PADS.convoy.h, PADS.boathouse.h, PADS.radio.h, PADS.ranger.h, PADS.camp.h
	-- touches dug into the ground before anything is placed on it
	terrain:FillBall(V(-146, SY - 2.6, 113), 5, M.Sand) -- sawdust heap at the saw shed's outfeed
	terrain:FillBall(V(66, CY + 0.8, 79), 3.6, M.Air) -- a blast crater by the burnt truck
	terrain:FillBall(V(58, CY + 1.2, 101), 2.4, M.Air)

	-- terrain takes raycasts from the next frame on; wait for it (placement below reads the real ground)
	local tParams = RaycastParams.new()
	tParams.FilterType = Enum.RaycastFilterType.Include
	tParams.FilterDescendantsInstances = { terrain }
	tParams.IgnoreWater = true
	do
		local t0 = os.clock()
		repeat
			task.wait()
		until workspace:Raycast(V(PADS.sawmill.x, 140, PADS.sawmill.z), Vector3.new(0, -180, 0), tParams) or os.clock() - t0 > 6
	end

	-- ground height at a spot (terrain only, from above); the voxel heights when the ray finds nothing
	local function gy(x, z)
		local hit = workspace:Raycast(Vector3.new(O.X + x, 140, O.Z + z), Vector3.new(0, -180, 0), tParams)
		if hit then
			return hit.Position.Y, hit.Normal
		end
		return hAt(x, z), Vector3.yAxis
	end

	-- ── building helpers ────────────────────────────────────────────────────────────────────────────────
	-- wall along x at z (holes { x, width, bottom, top } in map x, heights from the wall's foot)
	local function wallX(parent, x0, x1, z, y0, h, t, color, mat, holes)
		local cx = (x0 + x1) / 2
		local hs = {}
		for _, o in holes or {} do
			table.insert(hs, { o[1] - cx, o[2], o[3], o[4] })
		end
		kit.wallHoles(parent, CF(cx, y0, z), x1 - x0, h, t, color, mat, hs)
	end
	-- wall along z at x (holes { z, width, bottom, top } in map z)
	local function wallZ(parent, z0, z1, x, y0, h, t, color, mat, holes)
		local cz = (z0 + z1) / 2
		local hs = {}
		for _, o in holes or {} do
			table.insert(hs, { -(o[1] - cz), o[2], o[3], o[4] })
		end
		kit.wallHoles(parent, CF(x, y0, cz) * CFrame.Angles(0, math.rad(90), 0), z1 - z0, h, t, color, mat, hs)
	end
	-- a slab (top at yTop) over x0..x1, z0..z1 with rectangular holes { x0, x1, z0, z1 }
	local function slab(parent, x0, x1, z0, z1, yTop, th, color, mat, holes)
		local xs, zs, hs = { x0, x1 }, { z0, z1 }, {}
		for _, h in holes or {} do
			if h[2] > x0 and h[1] < x1 and h[4] > z0 and h[3] < z1 then
				table.insert(hs, h)
				table.insert(xs, math.max(h[1], x0))
				table.insert(xs, math.min(h[2], x1))
				table.insert(zs, math.max(h[3], z0))
				table.insert(zs, math.min(h[4], z1))
			end
		end
		local function uniq(t)
			table.sort(t)
			local o = {}
			for _, v in t do
				if #o == 0 or math.abs(o[#o] - v) > 1e-6 then
					table.insert(o, v)
				end
			end
			return o
		end
		xs, zs = uniq(xs), uniq(zs)
		local function inHole(cx, cz)
			for _, h in hs do
				if cx > h[1] and cx < h[2] and cz > h[3] and cz < h[4] then
					return true
				end
			end
			return false
		end
		for i = 1, #xs - 1 do
			local a, b = xs[i], xs[i + 1]
			local run0 = nil
			for j = 1, #zs do
				local solid = j < #zs and not inHole((a + b) / 2, (zs[j] + zs[j + 1]) / 2)
				if solid and not run0 then
					run0 = zs[j]
				elseif not solid and run0 then
					B(parent, b - a, th, zs[j] - run0, (a + b) / 2, yTop - th / 2, (run0 + zs[j]) / 2, color, mat)
					run0 = nil
				end
			end
		end
	end
	-- a railing between two points at deck height y
	local RAILC = hex("4A3D30")
	local function rail(parent, x0, z0, x1, z1, y, color, mat)
		local a, b = V(x0, y, z0), V(x1, y, z1)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		if len < 0.2 then
			return
		end
		local look = CFrame.lookAt(mid, b)
		kit.boxCF(parent, 0.25, 0.25, len, look * CFrame.new(0, 3.3, 0), color or RAILC, mat or M.WoodPlanks)
		kit.boxCF(parent, 0.18, 0.18, len, look * CFrame.new(0, 1.7, 0), color or RAILC, mat or M.WoodPlanks)
		for _, p in { a, b } do
			kit.boxCF(parent, 0.3, 3.4, 0.3, CFrame.new(p + Vector3.new(0, 1.7, 0)), color or RAILC, mat or M.WoodPlanks)
		end
	end
	-- straight stairs: n steps of 1 stud, each `run` deep, from (x, y0, z) along dir; solid down to yBase
	local function stairs(parent, x, z, y0, n, run, w, dir, yBase, color, mat)
		for k = 1, n do
			local top = y0 + k
			local h = top - yBase
			local off = (k - 0.5) * run
			local c, m = color or C.wood, mat or M.WoodPlanks
			if dir == "+x" then
				B(parent, run, h, w, x + off, yBase + h / 2, z, c, m)
			elseif dir == "-x" then
				B(parent, run, h, w, x - off, yBase + h / 2, z, c, m)
			elseif dir == "+z" then
				B(parent, w, h, run, x, yBase + h / 2, z + off, c, m)
			else
				B(parent, w, h, run, x, yBase + h / 2, z - off, c, m)
			end
		end
	end
	local function desk(parent, x, y0, z, w, d, color)
		B(parent, w, 0.3, d, x, y0 + 2.6, z, color or C.wood, M.WoodPlanks)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				B(parent, 0.22, 2.45, 0.22, x + sx * (w / 2 - 0.3), y0 + 1.22, z + sz * (d / 2 - 0.3), C.metalDark, M.Metal)
			end
		end
	end
	local function lampHang(parent, x, y, z, range, dead)
		local head = B(parent, 2, 0.4, 1.2, x, y, z, dead and hex("6F6C64") or hex("FFE2B0"), dead and M.SmoothPlastic or M.Neon)
		head.CastShadow = false
		if not dead then
			kit.light(head, hex("FFD3A0"), range or 28, 1.05, false)
		end
		return head
	end
	-- two-tier bunk along x (or z when ry = 90)
	local function bunk(parent, x, y0, z, ry)
		local cf = CF(x, y0, z, ry or 0)
		for _, sx in { -3, 3 } do
			for _, sz in { -1.2, 1.2 } do
				kit.boxCF(parent, 0.25, 5.6, 0.25, cf * CFrame.new(sx, 2.8, sz), C.metalDark, M.Metal)
			end
		end
		for _, y in { 1.2, 4.0 } do
			kit.boxCF(parent, 6.2, 0.25, 2.6, cf * CFrame.new(0, y, 0), C.metal, M.Metal)
			kit.boxCF(parent, 5.8, 0.45, 2.3, cf * CFrame.new(0, y + 0.35, 0), hex("6E6A58"), M.Fabric)
		end
	end
	-- a pitched roof over the rectangle x0..x1 / z0..z1 with the walls topping out at yTop. The ridge runs along x
	-- (along = "x") or z; the gable ends are filled with wedges.
	local function roof(parent, x0, x1, z0, z1, yTop, pitch, along, color, mat, gableColor)
		local tp = math.tan(math.rad(pitch))
		local ov = 1.2
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		if along == "x" then
			local d, len = z1 - z0, x1 - x0 + 2 * ov
			local rise = (d / 2) * tp
			for _, s in { -1, 1 } do
				local eave = V(cx, yTop - ov * tp, cz + s * (d / 2 + ov))
				local ridge = V(cx, yTop + rise, cz)
				local cf = CFrame.lookAt((eave + ridge) / 2, ridge)
				kit.boxCF(parent, len, 0.5, (ridge - eave).Magnitude + 0.25, cf * CFrame.new(0, 0.25, 0), color, mat)
			end
			for _, gx in { x0 + 0.35, x1 - 0.35 } do
				for _, s in { -1, 1 } do
					kit.part(parent, Vector3.new(0.6, rise, d / 2), CF(gx, yTop + rise / 2, cz + s * d / 4, s > 0 and 180 or 0), gableColor, M.WoodPlanks, "WedgePart")
				end
			end
			B(parent, len, 0.4, 0.6, cx, yTop + rise + 0.3, cz, gableColor, M.WoodPlanks) -- ridge board
		else
			local d, len = x1 - x0, z1 - z0 + 2 * ov
			local rise = (d / 2) * tp
			for _, s in { -1, 1 } do
				local eave = V(cx + s * (d / 2 + ov), yTop - ov * tp, cz)
				local ridge = V(cx, yTop + rise, cz)
				local cf = CFrame.lookAt((eave + ridge) / 2, ridge)
				kit.boxCF(parent, len, 0.5, (ridge - eave).Magnitude + 0.25, cf * CFrame.new(0, 0.25, 0), color, mat)
			end
			for _, gz in { z0 + 0.35, z1 - 0.35 } do
				for _, s in { -1, 1 } do
					-- wedge local +Z (full height) toward the ridge: rotate so it points along -s*x
					kit.part(parent, Vector3.new(0.6, rise, d / 2), CF(cx + s * d / 4, yTop + rise / 2, gz, s > 0 and -90 or 90), gableColor, M.WoodPlanks, "WedgePart")
				end
			end
			B(parent, 0.6, 0.4, len, cx, yTop + rise + 0.3, cz, gableColor, M.WoodPlanks)
		end
	end
	-- a timber cabin: plank floor on a stone footing, plank walls with doors and windows, pitched roof
	local function cabin(parent, s)
		local t = 0.7
		local col = s.color or hex("6E5A44")
		local cx, cz = (s.x0 + s.x1) / 2, (s.z0 + s.z1) / 2
		local wx, wz = s.x1 - s.x0, s.z1 - s.z0
		B(parent, wx + 0.4, 3.2, wz + 0.4, cx, s.fy - 1.6, cz, hex("6B6A63"), M.Cobblestone):SetAttribute("Wear", "")
		B(parent, wx - 0.2, 0.3, wz - 0.2, cx, s.fy - 0.15, cz, hex("5E4E3C"), M.WoodPlanks)
		wallX(parent, s.x0, s.x1, s.z0 + t / 2, s.fy, s.h, t, col, M.WoodPlanks, s.n)
		wallX(parent, s.x0, s.x1, s.z1 - t / 2, s.fy, s.h, t, col, M.WoodPlanks, s.s)
		wallZ(parent, s.z0 + t, s.z1 - t, s.x0 + t / 2, s.fy, s.h, t, col, M.WoodPlanks, s.w)
		wallZ(parent, s.z0 + t, s.z1 - t, s.x1 - t / 2, s.fy, s.h, t, col, M.WoodPlanks, s.e)
		roof(parent, s.x0, s.x1, s.z0, s.z1, s.fy + s.h, s.pitch or 28, s.roof or "x", s.roofColor or hex("4B4F48"), s.roofMat or M.CorrodedMetal, col)
		-- a ceiling so the roof void stays dark and the detail plan sees an interior
		B(parent, wx - 2 * t, 0.3, wz - 2 * t, cx, s.fy + s.h - 0.15, cz, hex("5A4A3A"), M.WoodPlanks)
	end
	-- an army cargo truck facing base.LookVector; kind "canvas", "logs" or "burnt"
	local function truck(parent, base, kind)
		local burnt = kind == "burnt"
		local body = burnt and hex("2F2B27") or ((kind == "logs") and hex("5A4E3C") or hex("4F563F"))
		local mat = burnt and M.CorrodedMetal or M.Metal
		local function bx(sx, sy, sz, x, y, z, c, m)
			return kit.boxCF(parent, sx, sy, sz, base * CFrame.new(x, y, z), c or body, m or mat)
		end
		bx(3.8, 0.8, 15.6, 0, 2.1, 0, C.metalDark, M.Metal) -- chassis
		for _, wz in { -5.4, 2.8, 5.2 } do
			for _, wx in { -2.25, 2.25 } do
				kit.cyl(parent, 1.1, 3.4, base * CFrame.new(wx, 1.7, wz), burnt and hex("1D1B19") or hex("262624"), M.Rubber)
			end
		end
		bx(4.6, 3.8, 3.6, 0, 4.4, -4.6) -- cab
		bx(4.2, 1.9, 2.8, 0, 3.4, -7.6) -- bonnet
		bx(4.4, 0.6, 0.4, 0, 2.4, -9.1, C.metalDark, M.Metal) -- bumper
		bx(3.9, 1.5, 0.1, 0, 5.4, -6.44, burnt and hex("141414") or hex("2B3532"), burnt and M.Slate or M.Glass) -- windscreen
		for _, sx in { -2.31, 2.31 } do
			bx(0.1, 1.4, 2, sx, 5.3, -4.8, burnt and hex("141414") or hex("2B3532"), burnt and M.Slate or M.Glass)
		end
		bx(4.8, 0.4, 9.6, 0, 2.9, 2.6) -- bed
		bx(0.25, 1.4, 9.6, -2.28, 3.8, 2.6)
		bx(0.25, 1.4, 9.6, 2.28, 3.8, 2.6)
		bx(4.8, 1.4, 0.25, 0, 3.8, 7.3)
		bx(4.8, 2.4, 0.25, 0, 4.3, -2.1)
		if kind == "canvas" then
			local CAN = hex("5B5E46")
			for _, hz in { -1.6, 2.6, 6.8 } do
				bx(4.7, 0.18, 0.18, 0, 7.4, hz, C.metalDark, M.Metal)
			end
			bx(4.9, 0.15, 9.6, 0, 7.55, 2.6, CAN, M.Fabric)
			bx(0.15, 3, 9.6, -2.42, 6.05, 2.6, CAN, M.Fabric)
			bx(0.15, 1.2, 9.6, 2.42, 6.95, 2.6, CAN, M.Fabric) -- this side rolled up
			bx(0.6, 0.6, 9.4, 2.4, 6.15, 2.6, hex("50533E"), M.Fabric)
		elseif kind == "logs" then
			for _, sz in { -1.6, 2.6, 6.8 } do
				for _, sx in { -2.3, 2.3 } do
					bx(0.3, 3.4, 0.3, sx, 4.8, sz, C.metalDark, M.Metal)
				end
			end
		end
	end

	-- nature kit pieces (ZR_Nature): origin at the base; nil when the kit is missing
	local lib = ReplicatedStorage:FindFirstChild("ZR_Assets")
	local function nat(parent, key, cf, scale, color, solid)
		local t = lib and lib:FindFirstChild(key)
		if not t then
			return nil
		end
		local m = t:Clone()
		local s = (typeof(scale) == "Vector3") and scale or Vector3.one * (scale or 1)
		m.Size = t.Size * s
		m.CFrame = cf * CFrame.new((AssetMeta[key] or Vector3.new(0, t.Size.Y / 2, 0)) * s)
		m.Anchored = true
		m.CanCollide = solid == true
		m.CanQuery = solid == true
		m.CanTouch = false
		if color then
			m.Color = color
		end
		m.Parent = parent
		return m
	end
	-- a chain-link fence run (posts, top rail, a see-through mesh panel that blocks walking but not shots)
	local FENCE = hex("6D716C")
	local function fence(parent, x0, z0, x1, z1, y, h)
		local a, b = V(x0, y, z0), V(x1, y, z1)
		local len = (b - a).Magnitude
		local look = CFrame.lookAt((a + b) / 2, b)
		local n = math.max(1, math.floor(len / 6 + 0.5))
		for k = 0, n do
			local p = a:Lerp(b, k / n)
			kit.boxCF(parent, 0.3, h + 0.4, 0.3, CFrame.new(p + Vector3.new(0, (h + 0.4) / 2 - 0.4, 0)), FENCE, M.Metal)
		end
		kit.boxCF(parent, 0.15, 0.15, len, look * CFrame.new(0, h, 0), FENCE, M.Metal)
		local mesh = kit.boxCF(parent, 0.08, h - 0.2, len, look * CFrame.new(0, h / 2, 0), FENCE, M.SmoothPlastic)
		mesh.Transparency = 1
		mesh.CanQuery = false
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
	end

	-- places the forest keeps clear of (spawns, exfils, loot, stands, AI posts): { x, z, r }
	local avoid = {}
	local function keepClear(x, z, r)
		table.insert(avoid, { x, z, r })
	end
	local function clear(x, z)
		for _, a in avoid do
			local dx, dz = x - a[1], z - a[2]
			if dx * dx + dz * dz < a[3] * a[3] then
				return false
			end
		end
		return true
	end
	local L = kit.loose
	local function loose(x, y, z, tbl, chance)
		L(O.X + x, y, O.Z + z, tbl, chance, "pinewatch")
		keepClear(x, z, 3)
	end

	-- ── the sawmill ───────────────────────────────────────────────────────────────────────────────────────
	local saw = kit.model("Sawmill", map)
	do
		-- the saw shed: an open steel frame under a mono-pitch roof, clad at the back and the infeed end
		local F = SY + 0.4
		B(saw, 46, 0.8, 24, -174, SY, 113, C.concreteDark, M.Concrete)
		for k = 0, 6 do
			local x = -196 + k * (44 / 6)
			VC(saw, 12, 0.6, x, F, 124, C.metalDark, M.Metal)
			VC(saw, 10.5, 0.6, x, F, 102, C.metalDark, M.Metal)
		end
		B(saw, 45, 0.7, 0.5, -174, F + 11.8, 124, C.metalDark, M.Metal)
		B(saw, 45, 0.7, 0.5, -174, F + 10.3, 102, C.metalDark, M.Metal)
		do
			local s, n = V(-174, F + 12.25, 125.6), V(-174, F + 10.6, 100.4)
			local cf = CFrame.lookAt((s + n) / 2, n)
			kit.boxCF(saw, 47.5, 0.35, (n - s).Magnitude, cf, hex("4E524C"), M.CorrodedMetal)
		end
		wallX(saw, -196.3, -151.7, 101.6, F, 6, 0.3, C.rust, M.CorrodedMetal, {})
		wallZ(saw, 102, 124, -196.6, F, 9.5, 0.3, C.rust, M.CorrodedMetal, { { 113, 6, 0, 5 } })
		-- the carriage line: rails, a carriage with a log, the head saw and the outfeed rollers
		for _, z in { 111.6, 114.4 } do
			B(saw, 36, 0.25, 0.3, -178, F + 0.125, z, C.metalDark, M.Metal)
		end
		B(saw, 4, 0.8, 4.2, -183, F + 0.65, 113, hex("4A4F47"), M.Metal)
		nat(saw, "ZR_NAT_Log", CF(-183, F + 1.05, 113), Vector3.new(0.9, 1.15, 1.15), nil, true)
		B(saw, 3, 7, 3.8, -166, F + 3.5, 110.2, C.yellow, M.Metal).Name = "HeadSaw"
		kit.cyl(saw, 0.15, 6.2, CF(-166, F + 3.3, 113) * CFrame.Angles(0, math.rad(90), 0), hex("8C8F8A"), M.Metal)
		B(saw, 3, 1.4, 1.2, -166, F + 7.6, 113, C.yellow, M.Metal)
		for k = 0, 5 do
			kit.cyl(saw, 3.6, 0.55, CF(-160 + k * 1.7, F + 1.4, 113) * CFrame.Angles(0, math.rad(90), 0), C.metal, M.Metal)
		end
		for _, z in { 111, 115 } do
			B(saw, 11, 0.3, 0.3, -155.5, F + 1.2, z, C.metalDark, M.Metal)
			for k = 0, 2 do
				B(saw, 0.3, 1.2, 0.3, -160 + k * 4.5, F + 0.6, z, C.metalDark, M.Metal)
			end
		end
		-- the sawyer's booth and a bench with blades
		B(saw, 3.6, 7, 3.2, -172, F + 3.5, 121.6, hex("5E6448"), M.Metal)
		B(saw, 2.4, 1.4, 0.1, -172, F + 5, 119.95, hex("2B3532"), M.Glass)
		desk(saw, -190, F, 120.6, 6, 2.2)
		loose(-190, F + 2.75, 120.6, "junk", 0.45)
		for k = 0, 2 do
			kit.cyl(saw, 0.12, 2.6, CF(-188 + k * 2.8, F + 4.6, 102.1) * CFrame.Angles(0, math.rad(90), 0), hex("8C8F8A"), M.Metal)
		end
		lampHang(saw, -184, F + 10.5, 113, 32, false)
		lampHang(saw, -162, F + 10.8, 116, 32, true)
		kit.container(saw, "PW1", "toolbox", "Saw shed toolbox", CF(-192, F, 106, 0))
		kit.container(saw, "PW2", "crate", "Saw parts crate", CF(-157, F, 106.5, 15))
		loose(-160, F + 0.05, 121, "junk", 0.35)
		keepClear(-174, 113, 30)
	end
	do
		-- log piles at the infeed and loose logs about the yard
		for _, z in { 100, 112.5, 125 } do
			nat(saw, "ZR_NAT_LogPile", CF(-205, SY, z, 90), 1, nil, true)
		end
		for _, l in { { -197, 136, 12 }, { -136, 186, 80 }, { -92, 150, 30 } } do
			nat(saw, "ZR_NAT_Log", CF(l[1], SY - 0.2, l[2], l[3]), Vector3.new(1.2, 1.1, 1.1), nil, true)
		end
		-- sawn planks stacked to dry
		for _, p in { { -140, 112 }, { -140, 118.5 } } do
			for k = 0, 2 do
				B(saw, 8, 0.5, 3.2, p[1], SY + 0.25 + k * 0.6, p[2], kit.jitter(hex("8A7458"), 0.06), M.WoodPlanks)
				B(saw, 3.4, 0.12, 0.3, p[1] - 3, SY + 0.56 + k * 0.6, p[2], hex("4A3D30"), M.WoodPlanks)
				B(saw, 3.4, 0.12, 0.3, p[1] + 3, SY + 0.56 + k * 0.6, p[2], hex("4A3D30"), M.WoodPlanks)
			end
		end
		-- the fuel tank on saddles, a pump and drums
		kit.cyl(saw, 10, 4.6, CF(-98, SY + 3.4, 118) * CFrame.Angles(0, math.rad(90), 0), hex("6B6E5E"), M.Metal)
		for _, z in { 114.5, 121.5 } do
			B(saw, 4, 1.4, 0.8, -98, SY + 0.7, z, C.metalDark, M.Metal)
		end
		B(saw, 1.4, 4, 1.2, -98, SY + 2, 125.4, C.red, M.Metal)
		kit.sign(B(saw, 4, 1, 0.1, -98, SY + 5.9, 112.95, C.metalDark, M.Metal), Enum.NormalId.Front, "DIESEL", C.yellow)
		keepClear(-98, 118, 8)
	end
	do
		-- the office: front room and the foreman's room behind
		local off = kit.model("SawmillOffice", saw)
		local OF = SY + 0.6
		cabin(off, {
			x0 = -128, x1 = -112, z0 = 100, z1 = 112, fy = OF, h = 9,
			n = { { -124, 2.6, 3, 6.2 }, { -116, 2.6, 3, 6.2 } },
			s = { { -116, 4.2, 0, 7.6 }, { -124, 2.6, 3, 6.2 } },
			w = { { 106, 2.6, 3, 6.2 } }, e = { { 104, 2.6, 3, 6.2 } },
		})
		W.doors.PW_OFFICE = { id = "PW_OFFICE", cf = CF(-116, OF + 3.75, 111.65), size = Vector3.new(3.9, 7.4, 0.35), label = "Sawmill office", parent = off, openChance = 0.5, color = hex("5E4C3A") }
		wallZ(off, 100.7, 111.3, -121, OF, 9, 0.4, hex("75614A"), M.WoodPlanks, { { 108, 3.6, 0, 7.4 } })
		desk(off, -116.5, OF, 103.2, 4, 2)
		loose(-116.5, OF + 2.76, 103.2, "office", 0.5)
		kit.container(off, "PW3", "drawer", "Office drawers", CF(-114.1, OF, 107, 90))
		kit.container(off, "PW4", "safe", "Sawmill safe", CF(-125, OF, 102.1, 180))
		desk(off, -124.5, OF, 109.6, 3.4, 1.6)
		loose(-124.5, OF + 2.76, 109.6, "keys", 0.3)
		lampHang(off, -117, OF + 8.4, 106, 22, false)
		-- the porch
		B(off, 16, 0.4, 3, -120, OF - 0.2, 113.6, hex("5E4E3C"), M.WoodPlanks)
		B(off, 3, 0.6, 1.2, -116, SY + 0.3, 115.6, hex("6B6A63"), M.Concrete)
		keepClear(-120, 106, 14)
	end
	do
		-- the bunkhouse: bunks, lockers, a stove and a table
		local bh = kit.model("Bunkhouse", saw)
		local BF = SY + 0.6
		cabin(bh, {
			x0 = -130, x1 = -108, z0 = 162, z1 = 174, fy = BF, h = 8.5,
			n = { { -119, 4.2, 0, 7.6 }, { -126, 2.6, 3, 6 }, { -112, 2.6, 3, 6 } },
			s = { { -125, 2.6, 3, 6 }, { -118, 2.6, 3, 6 }, { -112, 2.6, 3, 6 } },
			w = { { 168, 2.6, 3, 6 } }, e = {},
		})
		W.doors.PW_BUNK = { id = "PW_BUNK", cf = CF(-119, BF + 3.75, 162.35), size = Vector3.new(3.9, 7.4, 0.35), label = "Bunkhouse", parent = bh, openChance = 0.6, color = hex("5E4C3A") }
		bunk(bh, -125.5, BF, 171.8, 0)
		bunk(bh, -116.5, BF, 171.8, 0)
		kit.container(bh, "PW5", "locker", "Bunkhouse locker", CF(-110, BF, 166, 90))
		kit.container(bh, "PW6", "locker", "Bunkhouse locker", CF(-110, BF, 169.5, 90))
		kit.container(bh, "PW7", "medbag", "First-aid box", CF(-127.2, BF, 165, -90))
		desk(bh, -119.5, BF, 167, 4, 2.2)
		loose(-119.5, BF + 2.76, 167, "dorm", 0.5)
		B(bh, 2, 3, 2, -112.5, BF + 1.5, 164, C.metalDark, M.Metal)
		VC(bh, 7.5, 0.5, -112.5, BF + 3, 164, C.metalDark, M.Metal)
		lampHang(bh, -119, BF + 7.9, 168, 22, true)
		keepClear(-119, 168, 15)
	end
	do
		-- the log truck, lamps and yard cover
		local tb = CF(-182, SY, 170, -90)
		truck(saw, tb, "logs")
		for k, y in { 3.65, 3.65, 4.95 } do
			local zz = ({ -1.2, 1.2, 0 })[k]
			nat(saw, "ZR_NAT_Log", tb * CFrame.new(zz, y - 0.62, 2.6) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.85, 1.05, 1.05), nil, true)
		end
		keepClear(-182, 170, 12)
		for _, lp in { { -165, 131 }, { -128, 152 }, { -96, 134 } } do
			Props.lamp(saw, CF(lp[1], SY, lp[2]), nil)
			keepClear(lp[1], lp[2], 3)
		end
		for _, c in {
			{ "PalletStack", -140, 125, 20 }, { "PalletStack", -186, 132, 0 }, { "CableReel", -134, 118, 0 }, { "TyreStack", -170, 182, 30 },
			{ "DrumDented", -104, 112, 0, C.red }, { "DrumDented", -101.4, 110.6, 0, C.olive }, { "DrumDented", -103, 124.5, 0, C.blue },
			{ "CarWreck", -96, 176, 15 },
		} do
			Props.cover(saw, c[1], CF(c[2], SY, c[3], c[4]), c[5])
		end
	end

	-- ── the convoy on the logging road ────────────────────────────────────────────────────────────────────
	local con = kit.model("Convoy", map)
	do
		local t1 = CF(80, CY, 85, -78)
		truck(con, t1, "burnt")
		local t2 = CF(52, CY, 90.5, -84)
		truck(con, t2, "canvas")
		local t3 = CF(22, CY + 2.42, 104, -100) * CFrame.Angles(0, 0, math.rad(90))
		truck(con, t3, "canvas")
		Props.cover(con, "CarWreck", CF(2, CY, 99, -60), hex("4F563F"))
		kit.container(con, "PW8", "weaponbox", "Convoy weapon case", CF(30, CY, 112, 10))
		kit.container(con, "PW9", "crate", "Convoy supply crate", CF(64, CY, 100, -20))
		kit.container(con, "PW10", "crate", "Truck cargo crate", t2 * CFrame.new(0, 3.1, 3.4))
		kit.container(con, "PW11", "medbag", "Medic's bag", CF(8, CY, 106, 40))
		local bedT1 = (t1 * CFrame.new(0, 3.12, 4.6)).Position
		L(bedT1.X, bedT1.Y, bedT1.Z, "junk", 0.45, "pinewatch")
		loose(36, gy(36, 116) + 0.05, 116, "junk", 0.4)
		loose(14, gy(14, 92) + 0.05, 92, "keys", 0.2)
		for _, c in { { "Sandbags", 96, 73, 30 }, { "Sandbags", 100.5, 75.5, 75 }, { "BarrierBroken", 112, 78, 60 }, { "DrumDented", 70, 104, 0, C.olive } } do
			Props.cover(con, c[1], CF(c[2], CY, c[3], c[4]), c[5])
		end
		for _, p in { { 36, 106, 20 }, { 40.5, 110, -15 }, { 46, 107, 40 } } do
			Props.crate(con, CF(p[1], CY, p[2], p[3]))
		end
		keepClear(40, 94, 52)
	end

	-- ── the lake: boathouse, jetty, a moored boat ─────────────────────────────────────────────────────────
	local lake = kit.model("Lakeside", map)
	do
		local BF = BY + 0.6
		cabin(lake, {
			x0 = 140, x1 = 154, z0 = -50, z1 = -38, fy = BF, h = 8,
			n = { { 147, 2.6, 3, 6 } }, s = { { 147, 2.6, 3, 6 } },
			w = { { -44, 6, 0, 6.6 } }, e = { { -44, 4.2, 0, 7.6 } },
			color = hex("6A5846"),
		})
		W.doors.PW_BOAT = { id = "PW_BOAT", cf = CF(153.65, BF + 3.75, -44, 90), size = Vector3.new(3.9, 7.4, 0.35), label = "Boathouse", parent = lake, openChance = 0.5, color = hex("5A4A3A") }
		desk(lake, 149, BF, -48.4, 3.6, 1.4)
		loose(149, BF + 2.76, -48.4, "junk", 0.45)
		kit.container(lake, "PW12", "toolbox", "Boathouse toolbox", CF(143.6, BF, -47.2, 180))
		kit.container(lake, "PW13", "crate", "Fishing gear crate", CF(146.5, BF, -40.8, 0))
		lampHang(lake, 147, BF + 7.4, -44, 20, true)
		-- the jetty on posts
		B(lake, 28, 0.4, 4, 126, 1.7, -42, hex("6E5C48"), M.WoodPlanks)
		for x = 114, 138, 6 do
			for _, z in { -44.2, -39.8 } do
				VC(lake, 8.4, 0.5, x, -6.6, z, hex("4A3D30"), M.Wood)
			end
		end
		-- a rowboat moored by the jetty
		local bt = CF(124, -0.15, -36.6, 3)
		local HULL = hex("5A6A6E")
		kit.boxCF(lake, 8.4, 0.3, 2.6, bt * CFrame.new(0, 0.15, 0), HULL, M.WoodPlanks)
		for _, s in { -1.3, 1.3 } do
			kit.boxCF(lake, 8.4, 1.1, 0.22, bt * CFrame.new(0, 0.7, s), HULL, M.WoodPlanks)
		end
		kit.boxCF(lake, 0.22, 1.1, 2.6, bt * CFrame.new(-4.2, 0.7, 0), HULL, M.WoodPlanks)
		kit.boxCF(lake, 0.22, 1.1, 2.0, bt * CFrame.new(4.4, 0.7, 0) * CFrame.Angles(0, math.rad(0), 0), HULL, M.WoodPlanks)
		for _, x in { -1.8, 1.6 } do
			kit.boxCF(lake, 0.9, 0.15, 2.4, bt * CFrame.new(x, 0.95, 0), hex("6E5C48"), M.WoodPlanks)
		end
		Props.lamp(lake, CF(140, BY, -36), "flicker")
		keepClear(147, -44, 14)
	end

	-- ── the camp on the west shore ────────────────────────────────────────────────────────────────────────
	local camp = kit.model("Camp", map)
	do
		local TENT = hex("6E6448")
		for _, s in { -1, 1 } do
			local a, b = V(-11, KY + 0.05, -44 + s * 2.6), V(-11, KY + 3.2, -44)
			kit.boxCF(camp, 6, 0.12, (b - a).Magnitude, CFrame.lookAt((a + b) / 2, b), TENT, M.Fabric)
		end
		nat(camp, "ZR_NAT_RockPile", CF(-4, KY - 0.3, -36, 20), 0.42, hex("C8C6BC"), false)
		for k = 0, 1 do
			nat(camp, "ZR_NAT_Branch", CF(-4, KY + 0.1, -36, 30 + k * 70), 0.4, hex("3A332C"), false)
		end
		nat(camp, "ZR_NAT_Log", CF(-4, KY - 0.1, -32.4, 0), Vector3.new(0.35, 0.7, 0.7), nil, true)
		nat(camp, "ZR_NAT_Log", CF(0.2, KY - 0.1, -36.5, 90), Vector3.new(0.35, 0.7, 0.7), nil, true)
		desk(camp, 2, KY, -43, 3, 1.6, hex("8A8476"))
		loose(2, KY + 2.76, -43, "junk", 0.5)
		kit.container(camp, "PW20", "crate", "Camp supply box", CF(-13, KY, -37, 30))
		keepClear(-6, -40, 12)
	end

	-- ── the shelter under the ridge ───────────────────────────────────────────────────────────────────────
	local bun = kit.model("Shelter", map)
	local CONC, CONC_D = hex("6E6F69"), hex("575954")
	do
		local function room(name, h)
			local r = ROOMS[name]
			local x0, x1, z0, z1 = r[1], r[2], r[3], r[4]
			local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
			-- slabs three studs thick: the dug-out voxels end at their outer faces
			B(bun, x1 - x0 + 2, 3, z1 - z0 + 2, cx, FB - 1.5, cz, CONC_D, M.Concrete)
			B(bun, x1 - x0 + 2, 3, z1 - z0 + 2, cx, FB + CEIL + 1.5, cz, CONC_D, M.Concrete)
			if h.n ~= false then
				wallX(bun, x0 - 1, x1 + 1, z0 - 0.5, FB, CEIL, 1, CONC, M.Concrete, h.n)
			end
			if h.s ~= false then
				wallX(bun, x0 - 1, x1 + 1, z1 + 0.5, FB, CEIL, 1, CONC, M.Concrete, h.s)
			end
			if h.w ~= false then
				wallZ(bun, z0, z1, x0 - 0.5, FB, CEIL, 1, CONC, M.Concrete, h.w)
			end
			if h.e ~= false then
				wallZ(bun, z0, z1, x1 + 0.5, FB, CEIL, 1, CONC, M.Concrete, h.e)
			end
		end
		room("E1", { n = false, s = false, w = { { -183, 4.2, 0, 7.4 } } })
		room("G", { e = false })
		room("HALL", { s = { { -150, 6, 0, CEIL } }, n = { { -150, 6, 0, CEIL } }, w = { { -204, 4.2, 0, 7.2 } }, e = { { -204, 4.2, 0, 7.4 } } })
		room("DORM", { e = false })
		room("ARM", { w = false })
		room("E2", { n = false, s = false })
		room("HATCH", { s = { { -150, 6, 0, CEIL } } })
		-- the blast door inside the corridor and the armoury's locked door
		wallX(bun, -153, -147, -177, FB, CEIL, 1, CONC, M.Concrete, { { -150, 4.2, 0, 7.4 } })
		W.doors.PB_GATE = { id = "PB_GATE", cf = CF(-150, FB + 3.75, -177), size = Vector3.new(3.9, 7.4, 0.35), label = "Shelter blast door", parent = bun, openChance = 0.6, color = hex("4E5247") }
		W.doors.PB_ARMORY = { id = "PB_ARMORY", cf = CF(-140.5, FB + 3.75, -204, 90), size = Vector3.new(3.9, 7.4, 0.35), key = "KEY_PINE_BUNKER", label = "Shelter armoury", parent = bun, color = hex("464A42") }
		-- the facade: a concrete retaining wall across the hill's foot with the portal, a sign and an apron
		wallX(bun, -177, -139, PORTAL - 0.5, FB, COVER + 0.5, 1, CONC, M.Concrete, { { -150, 6, 0, CEIL } })
		B(bun, 38.6, 0.8, 1.8, -158, FB + COVER + 0.9, PORTAL - 0.5, C.concreteLight, M.Concrete)
		for _, x in { -170, -158, -142 } do
			B(bun, 1.6, COVER + 0.5, 1.2, x, FB + (COVER + 0.5) / 2, PORTAL + 0.5, CONC_D, M.Concrete) -- buttresses
		end
		kit.sign(B(bun, 6, 1, 0.2, -150, FB + 8.9, PORTAL + 0.1, C.metalDark, M.Metal), Enum.NormalId.Back, "SHELTER P-7", C.pale)
		B(bun, 20, 0.4, 12, -150, FB - 0.05, PORTAL + 6, CONC_D, M.Concrete)
		-- guard room: table, bunk, a locker
		desk(bun, -162, FB, -183, 4, 2.2)
		loose(-162, FB + 2.76, -183, "junk", 0.4)
		bunk(bun, -165, FB, -177.6, 0)
		kit.container(bun, "PB1", "locker", "Guard locker", CF(-168.8, FB, -187, -90))
		-- the hall: a map table, the radio desk, the command post files
		desk(bun, -150, FB, -204.5, 6, 3.5, hex("5B5446"))
		B(bun, 5.2, 0.05, 2.8, -150, FB + 2.78, -204.5, hex("B9B193"), M.SmoothPlastic)
		loose(-149, FB + 2.82, -204, "office", 0.5)
		desk(bun, -156, FB, -210.6, 4, 1.8)
		B(bun, 2.2, 1.5, 1.2, -156.6, FB + 3.5, -210.8, C.metalDark, M.Metal)
		B(bun, 0.3, 0.3, 0.3, -155.7, FB + 4.1, -210.15, hex("6CC27A"), M.Neon).CastShadow = false
		loose(-155, FB + 2.76, -210.4, "office", 0.4)
		kit.container(bun, "PB2", "drawer", "Command post files", CF(-144, FB, -210.6, 180))
		B(bun, 0.15, 4, 6, -159.9, FB + 3.6, -200.5, hex("A39F8A"), M.SmoothPlastic)
		-- the armoury
		kit.container(bun, "PB3", "weaponbox", "Armoury case", CF(-136, FB, -209.9, 180))
		kit.container(bun, "PB4", "weaponbox", "Armoury case", CF(-129, FB, -209.9, 180))
		kit.container(bun, "PB5", "crate", "Ammunition crate", CF(-126.1, FB, -201, 90))
		for k = 0, 2 do
			B(bun, 3, 5, 0.6, -136 + k * 4, FB + 2.5, -197.6, hex("4A4E46"), M.Metal)
		end
		loose(-133, FB + 0.05, -203, "junk", 0.4)
		-- the dormitory
		for _, b in { { -175, -210.6 }, { -167, -210.6 }, { -175, -198.4 }, { -167, -198.4 } } do
			bunk(bun, b[1], FB, b[2], 0)
		end
		kit.container(bun, "PB6", "locker", "Dorm locker", CF(-178.8, FB, -206, -90))
		kit.container(bun, "PB7", "locker", "Dorm locker", CF(-178.8, FB, -202.5, -90))
		kit.container(bun, "PB8", "medbag", "Shelter first aid", CF(-171, FB, -204.5, 90))
		loose(-165, FB + 0.05, -207, "dorm", 0.5)
		-- the hatch room: a ladder to the emergency hatch, the generator
		for _, x in { -150.9, -149.1 } do
			B(bun, 0.2, CEIL, 0.2, x, FB + CEIL / 2, -237.7, C.metalDark, M.Metal)
		end
		for y = 1, 7 do
			B(bun, 1.8, 0.12, 0.12, -150, FB + y, -237.7, C.metalDark, M.Metal)
		end
		B(bun, 3, 0.3, 3, -150, FB + CEIL - 0.1, -236.5, hex("3F433E"), M.DiamondPlate)
		local red = B(bun, 0.6, 0.3, 0.6, -147.5, FB + CEIL - 0.25, -236, hex("C0392B"), M.Neon)
		red.CastShadow = false
		kit.light(red, hex("FF5A3C"), 16, 0.9, false)
		B(bun, 4, 3, 2.5, -143, FB + 1.5, -235.5, hex("5E6448"), M.Metal)
		VC(bun, CEIL - 3, 0.4, -143, FB + 3, -235.5, C.metalDark, M.Metal)
		kit.container(bun, "PB9", "toolbox", "Hatch room toolbox", CF(-157.9, FB, -232, -90))
		Props.cover(bun, "DrumDented", CF(-142.6, FB, -229.5, 0), C.olive)
		-- lights (some dead)
		for _, l in { { -150, -186, false }, { -162, -183, false }, { -150, -201, false }, { -150, -208, true }, { -170, -204, true }, { -132, -204, false }, { -150, -219, true }, { -152, -232, false } } do
			lampHang(bun, l[1], FB + CEIL - 0.3, l[2], 22, l[3])
		end
		-- the emergency hatch where it comes out on the hillside
		local hy = gy(-150, -236)
		B(map, 4.4, 1.2, 4.4, -150, hy + 0.2, -236, CONC, M.Concrete)
		B(map, 3.2, 0.3, 3.2, -150, hy + 0.95, -236, hex("3F433E"), M.DiamondPlate)
		keepClear(-150, -236, 6)
		keepClear(-158, -160, 22)
	end

	-- ── the radio hill ────────────────────────────────────────────────────────────────────────────────────
	local rad = kit.model("RadioHill", map)
	do
		local HF = HY + 0.4
		-- the equipment hut
		B(rad, 9, 0.8, 9, 168, HY, -178, CONC_D, M.Concrete)
		wallX(rad, 164, 172, -181.6, HF, 8.5, 0.8, CONC, M.Concrete, {})
		wallX(rad, 164, 172, -174.4, HF, 8.5, 0.8, CONC, M.Concrete, { { 168, 4.2, 0, 7.6 } })
		wallZ(rad, -181.2, -174.8, 164.4, HF, 8.5, 0.8, CONC, M.Concrete, { { -178, 2.4, 3.4, 5.8 } })
		wallZ(rad, -181.2, -174.8, 171.6, HF, 8.5, 0.8, CONC, M.Concrete, {})
		B(rad, 9.2, 0.6, 9.2, 168, HF + 8.8, -178, CONC_D, M.Concrete)
		W.doors.PR_HUT = { id = "PR_HUT", cf = CF(168, HF + 3.75, -174.4), size = Vector3.new(3.9, 7.4, 0.35), label = "Radio hut", parent = rad, openChance = 0.4, color = hex("4E5247") }
		kit.container(rad, "PW14", "drawer", "Radio log cabinet", CF(167.5, HF, -179.8, 180))
		desk(rad, 165.6, HF, -176.6, 1.4, 3.2)
		B(rad, 1.1, 0.9, 1.4, 165.6, HF + 3.2, -177.6, C.metalDark, M.Metal)
		B(rad, 0.1, 0.2, 0.2, 166.2, HF + 3.3, -177.2, hex("6CC27A"), M.Neon).CastShadow = false
		loose(165.6, HF + 2.76, -175.8, "office", 0.45)
		lampHang(rad, 168, HF + 8.1, -178, 16, false)
		-- the mast: three legs, braced rings, antennas and a red beacon; guy wires to anchors
		local mx, mz, top = 184, -168, 44
		local legs = {}
		for k = 0, 2 do
			local a = math.rad(90 + k * 120)
			table.insert(legs, { mx + math.cos(a) * 2.5, mz + math.sin(a) * 2.5 })
		end
		for _, l in legs do
			B(rad, 0.4, top, 0.4, l[1], HY + top / 2, l[2], hex("8A8E86"), M.Metal)
			B(rad, 1.2, 1.2, 1.2, l[1], HY + 0.4, l[2], CONC, M.Concrete)
		end
		for y = 4, top - 2, 5.5 do
			for k = 1, 3 do
				local a, b = legs[k], legs[k % 3 + 1]
				local p, q = V(a[1], HY + y, a[2]), V(b[1], HY + y, b[2])
				kit.boxCF(rad, 0.18, 0.18, (q - p).Magnitude, CFrame.lookAt((p + q) / 2, q), hex("8A8E86"), M.Metal)
				local q2 = V(b[1], HY + y + 5.5, b[2])
				if y + 5.5 <= top then
					kit.boxCF(rad, 0.12, 0.12, (q2 - p).Magnitude, CFrame.lookAt((p + q2) / 2, q2), hex("8A8E86"), M.Metal)
				end
			end
		end
		for k = 0, 2 do
			local a = math.rad(k * 120 + 30)
			B(rad, 0.15, 6, 0.15, mx + math.cos(a) * 1.4, HY + top + 3, mz + math.sin(a) * 1.4, C.metalDark, M.Metal)
		end
		kit.cyl(rad, 0.4, 3.2, CF(mx, HY + top - 6, mz - 2.6) * CFrame.Angles(0, math.rad(90), 0), hex("B8BAB2"), M.Metal)
		local beacon = B(rad, 0.7, 0.7, 0.7, mx, HY + top + 0.4, mz, hex("C0392B"), M.Neon)
		beacon.CastShadow = false
		kit.light(beacon, hex("FF4A3A"), 26, 1.1, false)
		for k = 0, 2 do
			local a = math.rad(20 + k * 120)
			local ax, az = mx + math.cos(a) * 26, mz + math.sin(a) * 26
			local p, q = V(mx, HY + 30, mz), V(ax, gy(ax, az) + 0.3, az)
			local wire = kit.boxCF(rad, 0.08, 0.08, (q - p).Magnitude, CFrame.lookAt((p + q) / 2, q), hex("3A3D3B"), M.Metal)
			wire.CanCollide = false
			wire.CanQuery = false
			wire.CastShadow = false
			B(rad, 1.2, 0.8, 1.2, ax, q.Y, az, CONC, M.Concrete)
		end
		-- the compound fence (gate gap on the south side), a generator and drums
		fence(rad, 161, -187, 190, -187, HY, 7)
		fence(rad, 161, -187, 161, -157, HY, 7)
		fence(rad, 190, -187, 190, -157, HY, 7)
		fence(rad, 161, -157, 170, -157, HY, 7)
		fence(rad, 178, -157, 190, -157, HY, 7)
		B(rad, 3, 2.5, 2, 176, HY + 1.25, -180, hex("5E6448"), M.Metal)
		kit.container(rad, "PW15", "crate", "Spare parts crate", CF(175.5, HY, -184.5, 90))
		Props.cover(rad, "DrumDented", CF(179.5, HY, -181, 0), C.olive)
		keepClear(176, -172, 22)
	end

	-- ── the ranger station ────────────────────────────────────────────────────────────────────────────────
	local rs = kit.model("RangerStation", map)
	do
		local F1 = RY + 0.6
		local F2 = F1 + 9
		local t = 0.7
		local WOOD = hex("6A5642")
		B(rs, 20.4, 3.2, 14.4, 142, F1 - 1.6, 147, hex("6B6A63"), M.Cobblestone):SetAttribute("Wear", "")
		B(rs, 19.8, 0.3, 13.8, 142, F1 - 0.15, 147, hex("5E4E3C"), M.WoodPlanks)
		local up = 9
		wallX(rs, 132, 152, 140 + t / 2, F1, 18, t, WOOD, M.WoodPlanks, { { 137, 2.6, 3, 6.2 }, { 147, 2.6, 3, 6.2 }, { 137, 2.6, up + 3, up + 6.2 }, { 147, 2.6, up + 3, up + 6.2 } })
		wallX(rs, 132, 152, 154 - t / 2, F1, 18, t, WOOD, M.WoodPlanks, { { 136, 2.6, 3, 6.2 }, { 146, 2.6, 3, 6.2 }, { 136, 2.6, up + 3, up + 6.2 }, { 146, 2.6, up + 3, up + 6.2 } })
		wallZ(rs, 140 + t, 154 - t, 152 - t / 2, F1, 18, t, WOOD, M.WoodPlanks, { { 147, 4.2, 0, 7.6 }, { 142.4, 2.4, 3, 6.2 }, { 143.5, 2.6, up + 3, up + 6.2 }, { 150, 2.4, up + 3, up + 6.2 } })
		wallZ(rs, 140 + t, 154 - t, 132 + t / 2, F1, 18, t, WOOD, M.WoodPlanks, { { 147, 2.6, 3, 6.2 }, { 144, 2.6, up + 3, up + 6.2 } })
		roof(rs, 132, 152, 140, 154, F1 + 18, 30, "x", hex("4B4F48"), M.CorrodedMetal, WOOD)
		B(rs, 18.6, 0.3, 12.6, 142, F1 + 17.85, 147, hex("5A4A3A"), M.WoodPlanks)
		-- the upper floor with the stairwell, the stairs along the north wall
		slab(rs, 132.7, 151.3, 140.7, 153.3, F2, 0.6, hex("5E4E3C"), M.WoodPlanks, { { 139, 150.6, 140.7, 143.9 } })
		stairs(rs, 150.5, 142.3, F1, 9, 1.2, 3, "-x", F1, hex("5E4E3C"), M.WoodPlanks)
		rail(rs, 139, 144.1, 150.6, 144.1, F2)
		W.doors.PR_STATION = { id = "PR_STATION", cf = CF(152 - t / 2, F1 + 3.75, 147, 90), size = Vector3.new(3.9, 7.4, 0.35), label = "Ranger station", parent = rs, openChance = 0.5, color = hex("5A4A3A") }
		-- ground floor: the office
		desk(rs, 139, F1, 150.4, 4, 2)
		loose(139, F1 + 2.76, 150.4, "office", 0.5)
		loose(140.4, F1 + 2.76, 150.8, "keys", 0.35)
		kit.container(rs, "PW16", "drawer", "Ranger's desk drawers", CF(134.4, F1, 150, -90))
		kit.container(rs, "PW17", "weaponbox", "Rifle cabinet", CF(135.1, F1, 145.4, -90))
		B(rs, 0.15, 3.6, 4, 151.2, F1 + 4.2, 151.2, hex("A39F8A"), M.SmoothPlastic)
		lampHang(rs, 142, F1 + 8.4, 148, 22, false)
		-- upstairs: bunks, a locker, the first-aid kit
		bunk(rs, 138, F2, 151.6, 0)
		bunk(rs, 146, F2, 151.6, 0)
		kit.container(rs, "PW18", "locker", "Ranger's locker", CF(150.1, F2, 147.6, 90))
		kit.container(rs, "PW19", "medbag", "Ranger first-aid kit", CF(134.8, F2, 146.5, -90))
		desk(rs, 142.5, F2, 146.8, 3, 1.6)
		loose(142.5, F2 + 2.76, 146.8, "dorm", 0.5)
		lampHang(rs, 142, F2 + 8.4, 148, 20, true)
		-- the porch and its steps
		B(rs, 4, 0.4, 8, 154, F1 - 0.2, 147, hex("5E4E3C"), M.WoodPlanks)
		B(rs, 1.2, 0.3, 4, 156.6, RY + 0.3, 147, hex("6B6A63"), M.Concrete)
		keepClear(142, 147, 16)
		-- the fire lookout: four timber legs, a platform with a little roof, a straight stair
		local LX, LZ, LT = 182, 160, RY + 12
		local TIM = hex("57483A")
		for _, sx in { -4, 4 } do
			for _, sz in { -4, 4 } do
				B(rs, 0.8, 12.4, 0.8, LX + sx, RY + 6, LZ + sz, TIM, M.Wood)
				B(rs, 0.4, 7.4, 0.4, LX + sx * 1.15, LT + 3.7, LZ + sz * 1.15, TIM, M.Wood)
			end
		end
		for _, side in { { -4, -4, 4, -4 }, { -4, 4, 4, 4 }, { -4, -4, -4, 4 }, { 4, -4, 4, 4 } } do
			local p, q = V(LX + side[1], RY + 0.5, LZ + side[2]), V(LX + side[3], LT - 1, LZ + side[4])
			kit.boxCF(rs, 0.3, 0.3, (q - p).Magnitude, CFrame.lookAt((p + q) / 2, q), TIM, M.Wood)
		end
		B(rs, 10, 0.5, 10, LX, LT - 0.25, LZ, hex("5E4E3C"), M.WoodPlanks)
		B(rs, 11, 0.4, 11, LX, LT + 7.6, LZ, hex("4B4F48"), M.CorrodedMetal)
		rail(rs, LX - 5, LZ - 5, LX + 5, LZ - 5, LT)
		rail(rs, LX - 5, LZ + 5, LX + 5, LZ + 5, LT)
		rail(rs, LX + 5, LZ - 5, LX + 5, LZ + 5, LT)
		rail(rs, LX - 5, LZ - 5, LX - 5, LZ - 1.8, LT)
		rail(rs, LX - 5, LZ + 1.8, LX - 5, LZ + 5, LT)
		stairs(rs, LX - 17, LZ, RY, 12, 1.0, 3, "+x", RY - 1, TIM, M.WoodPlanks)
		loose(LX + 2, LT + 0.05, LZ - 2, "junk", 0.45)
		keepClear(LX - 4, LZ, 16)
		-- the woodshed, the outhouse, the ranger's pickup
		local WS = kit.model("Woodshed", rs)
		wallX(WS, 130, 140, 160.3, RY, 7, 0.5, WOOD, M.WoodPlanks, {})
		wallZ(WS, 160.6, 168, 130.25, RY, 6, 0.5, WOOD, M.WoodPlanks, {})
		wallZ(WS, 160.6, 168, 139.75, RY, 6, 0.5, WOOD, M.WoodPlanks, {})
		do
			local a, b = V(135, RY + 7.1, 159.6), V(135, RY + 5.9, 169)
			kit.boxCF(WS, 11, 0.35, (b - a).Magnitude, CFrame.lookAt((a + b) / 2, b), hex("4B4F48"), M.CorrodedMetal)
		end
		nat(WS, "ZR_NAT_LogPile", CF(135, RY, 163.4, 0), Vector3.new(0.8, 0.6, 0.6), nil, true)
		B(rs, 3.2, 7, 3.2, 127, RY + 3.5, 134, hex("665441"), M.WoodPlanks)
		B(rs, 3.8, 0.3, 3.8, 127, RY + 7.15, 134, hex("4B4F48"), M.CorrodedMetal)
		Props.cover(rs, "CarWreck", CF(170, RY, 128, 30), hex("4F5E45"))
		Props.lamp(rs, CF(155.5, RY, 138.5), nil)
		for _, c in { { "PalletStack", 168, 176, 10 }, { "DrumDented", 138.5, 157.5, 0, C.red }, { "DrumDented", 141, 158, 0, C.olive } } do
			Props.cover(rs, c[1], CF(c[2], RY, c[3], c[4]), c[5])
		end
		keepClear(135, 164, 8)
	end

	-- ── hunting stands, a ruined hut, an abandoned car ───────────────────────────────────────────────────
	local misc = kit.model("Woods", map)
	local STANDS = { { -60, -70, 0 }, { 212, 72, 90 }, { -216, -38, 180 }, { 44, 206, 270 } }
	for _, s in STANDS do
		local x, z, yaw = s[1], s[2], s[3]
		-- the stair runs out from the platform's open side; the platform sits eight steps above the stair's foot
		local dirs = { [0] = { 0, 1, "-z" }, [90] = { 1, 0, "-x" }, [180] = { 0, -1, "+z" }, [270] = { -1, 0, "+x" } }
		local d = dirs[yaw]
		local fx, fz = x + d[1] * (2.2 + 8 * 0.9), z + d[2] * (2.2 + 8 * 0.9)
		local fy = gy(fx, fz)
		local top = fy + 8
		local TIM = hex("57483A")
		for _, c in { { -1.9, -1.9 }, { 1.9, -1.9 }, { -1.9, 1.9 }, { 1.9, 1.9 } } do
			local lx, lz = x + c[1], z + c[2]
			local g = gy(lx, lz)
			B(misc, 0.45, top - g + 0.6, 0.45, lx, (top + g - 0.6) / 2, lz, TIM, M.Wood)
		end
		B(misc, 4.6, 0.4, 4.6, x, top - 0.2, z, hex("5E4E3C"), M.WoodPlanks)
		for _, side in { { -2.3, -2.3, 2.3, -2.3 }, { -2.3, 2.3, 2.3, 2.3 }, { -2.3, -2.3, -2.3, 2.3 }, { 2.3, -2.3, 2.3, 2.3 } } do
			-- leave the stair side open
			local mx, mz = (side[1] + side[3]) / 2, (side[2] + side[4]) / 2
			if not (math.abs(mx - d[1] * 2.3) < 0.1 and math.abs(mz - d[2] * 2.3) < 0.1) then
				local p, q = V(x + side[1], top, z + side[2]), V(x + side[3], top, z + side[4])
				kit.boxCF(misc, 0.2, 0.2, (q - p).Magnitude, CFrame.lookAt((p + q) / 2, q) * CFrame.new(0, 2.6, 0), TIM, M.Wood)
				kit.boxCF(misc, 0.08, 1.4, (q - p).Magnitude, CFrame.lookAt((p + q) / 2, q) * CFrame.new(0, 1.9, 0), hex("5F6448"), M.Fabric)
			end
		end
		stairs(misc, fx, fz, fy, 8, 0.9, 1.8, d[3], fy - 2, TIM, M.WoodPlanks)
		loose(x + 0.6, top + 0.05, z - 0.4, "junk", 0.45)
		keepClear(x, z, 6)
		keepClear(fx, fz, 4)
	end
	do
		-- a ruined hut: low walls, no roof
		local hx, hz = -100, 20
		local hy = gy(hx, hz)
		local RU = hex("6A6A62")
		B(misc, 13, 2.6, 10, hx, hy - 1.1, hz, hex("5F5E57"), M.Concrete)
		wallX(misc, hx - 6.5, hx + 6.5, hz - 4.6, hy + 0.2, 4.5, 0.8, RU, M.Cobblestone, { { hx + 2, 2.6, 1.2, 3.6 } })
		wallX(misc, hx - 6.5, hx - 1, hz + 4.6, hy + 0.2, 2.6, 0.8, RU, M.Cobblestone, {})
		wallX(misc, hx + 2.2, hx + 6.5, hz + 4.6, hy + 0.2, 1.4, 0.8, RU, M.Cobblestone, {})
		wallZ(misc, hz - 4.2, hz + 4.2, hx - 6.1, hy + 0.2, 3.6, 0.8, RU, M.Cobblestone, { { hz + 1, 2.4, 1.2, 3.2 } })
		wallZ(misc, hz - 4.2, hz + 1, hx + 6.1, hy + 0.2, 5.2, 0.8, RU, M.Cobblestone, {})
		loose(hx - 3, hy + 0.25, hz - 2, "junk", 0.5)
		keepClear(hx, hz, 10)
		Props.cover(misc, "CarWreck", CF(-70, gy(-70, -45) - 0.2, -45, 40), hex("6B5442"))
		keepClear(-70, -45, 7)
		local dz = gy(-24, 168)
		Props.cover(misc, "TyreStack", CF(-24, dz, 168, 15), nil)
	end

	-- ── exfils, spawns ────────────────────────────────────────────────────────────────────────────────────
	local function ex(id, name, x, z, size, rule, y, opts)
		local yy = y or gy(x, z)
		kit.extract(map, id, name, V(x, yy, z), size, rule, opts)
		keepClear(x, z, math.max(size.X, size.Z) / 2 + 4)
	end
	ex("PW", "WEST LOGGING ROAD", -248, 126.8, Vector3.new(10, 12, 16), { kind = "open" })
	ex("PE", "EAST ROAD BLOCK", 248, 22.6, Vector3.new(10, 12, 16), { kind = "open" })
	ex("PN", "RIDGE TRAIL", 22, -246, Vector3.new(12, 12, 10), { kind = "open" })
	ex("PS", "RANGER TRAIL", 158.5, 248, Vector3.new(12, 12, 10), { kind = "open" })
	ex("PB", "BOATHOUSE JETTY", 117, -42, Vector3.new(8, 10, 6), { kind = "chance", chance = 0.5 }, 1.9)
	ex("PK", "SHELTER HATCH", -150, -234.6, Vector3.new(7, 6.4, 5), { kind = "key", key = "KEY_PINE_BUNKER" }, FB, { compact = true })
	ex("PC", "CULVERT", -80, 247, Vector3.new(8, 10, 8), { kind = "scav" })
	-- the east road block and the culvert pipe
	for _, p in { { 236, 30, 75 }, { 238, 14, 105 } } do
		Props.barrier(map, CF(p[1], gy(p[1], p[2]), p[2], p[3]))
	end
	do
		local cy = gy(-80, 242)
		local pipe = kit.cyl(map, 10, 5, CF(-80, cy + 1.6, 238) * CFrame.Angles(0, math.rad(90), 0), C.concreteLight, M.Concrete)
		pipe.CanCollide = true
		B(map, 9, 3, 1.2, -80, cy + 1, 232.6, C.concrete, M.Concrete)
	end
	local function sp(id, name, x, z, yaw, side)
		keepClear(x, z, 8)
		return { id = id, name = name, cf = CF(x, gy(x, z) + 3.4, z, yaw), side = side }
	end
	W.spawns = {
		sp("W1", "WEST TREELINE", -246, 40, -90, "west"), sp("W2", "LOG LANDING", -244, 196, -90, "west"),
		sp("E1", "EAST CLEARCUT", 246, -64, 90, "east"), sp("E2", "PIPELINE CUT", 244, 114, 90, "east"),
		sp("S1", "SOUTH FENCE", -150, 246, 0, "south"), sp("S2", "CREEK BED", 64, 246, 0, "south"),
		sp("N1", "RIDGE SADDLE", -80, -244, 180, "north"), sp("N2", "NORTH CAIRN", 112, -246, 180, "north"),
	}
	W.sideExtracts = {
		west = { "PE", "PS", "PB", "PK" }, east = { "PW", "PN", "PB", "PK" },
		south = { "PN", "PB", "PK" }, north = { "PS", "PW", "PB" },
	}
	for _, s in W.spawns do
		s.extracts = W.sideExtracts[s.side]
	end

	-- ── AI: patrols, posts, scav zones, the Sawyer ───────────────────────────────────────────────────────
	local function G(x, z)
		local y = gy(x, z)
		keepClear(x, z, 3)
		return V(x, y, z)
	end
	W.patrols = {
		PS = { G(-190, 132), G(-150, 130), G(-118, 124), G(-100, 150), G(-118, 182), G(-160, 182), G(-200, 165) },
		PC = { G(-10, 104), G(30, 114), G(70, 106), G(96, 82), G(60, 78), G(20, 82) },
		PB = { G(-150, -140), G(-128, -150), V(-150, FB, -160), G(-172, -150) },
		PR = { G(150, 126), G(172, 132), G(192, 150), G(172, 178), G(140, 178), G(124, 150) },
		PL = { G(-20, -20), G(0, 12), G(60, 22), G(120, 12), G(150, -20), G(140, -100), G(60, -110), G(-10, -90) },
	}
	keepClear(-150, -160, 4)
	W.watchPosts = {
		{ route = "PR", post = V(182, RY + 12, 160), label = "Ranger" }, -- the fire lookout
		{ route = "PR", label = "Ranger" },
		{ route = "PB", post = V(-150, FB, -160), label = "Ranger" }, -- the shelter's approach cut
		{ route = "PL", label = "Ranger" },
		{ route = "PL", post = G(176, -163), label = "Ranger" }, -- the radio hill
		{ route = "PC", label = "Ranger" },
	}
	W.scavZones = {
		G(-175, 118), G(-120, 120), G(-118, 180), G(-102, 130), G(-198, 112), G(-150, 165),
		G(10, 112), G(45, 106), G(76, 98), G(30, 80),
		G(-6, -32), G(20, 30), G(110, 15), G(130, -100), G(158, -52), G(150, -28),
		G(145, 130), G(175, 140), G(140, 172), G(186, 176),
		G(178, -150), G(150, -186), G(-150, -140), G(-128, -152), V(-150, FB, -204),
		G(-60, -62), G(212, 82), G(-216, -28), G(44, 216),
		G(-60, 112), G(100, 80), G(200, 36), G(-40, 0), G(-100, -90), G(0, -112), G(-100, 30),
	}
	W.visitZones = {
		CONVOY = { pos = V(40, CY, 94), r = 22 }, SHELTER = { pos = V(-150, FB, -204), r = 12 }, LOOKOUT = { pos = V(182, RY + 12, 160), r = 6 },
	}
	W.boss = {
		name = "THE SAWYER", label = "Sawyer", home = V(-120, SY + 0.6, 114),
		route = W.patrols.PS,
		crew = { V(-125, SY, 117), V(-113, SY, 117) },
	}
	W.bounds = { x0 = O.X - PLAY, x1 = O.X + PLAY, z0 = O.Z - PLAY, z1 = O.Z + PLAY, yMin = -2, yMax = 72, step = 4 }
	-- clients scatter grass, ferns and reeds over this terrain (Detail controller)
	table.insert(W.natureRegions, { O.X - PLAY - 24, O.Z - PLAY - 24, O.X + PLAY + 24, O.Z + PLAY + 24, -10, 76 })

	-- ── the forest ────────────────────────────────────────────────────────────────────────────────────────
	local forest = kit.model("Forest", map)
	local CLEARCUT = { -246, -204, 158, 228 } -- logged ground west of the sawmill: stumps, slash, no standing trees
	local function inClearcut(x, z)
		return x > CLEARCUT[1] and x < CLEARCUT[2] and z > CLEARCUT[3] and z < CLEARCUT[4]
	end
	local function tint(base, amt)
		local k = 1 - rng:NextNumber(0, amt)
		return Color3.new(base.R * k, base.G * k, base.B * k)
	end
	local TREES = {
		{ t = "ZR_NAT_PineA_T", c = "ZR_NAT_PineA_C", w = 40 },
		{ t = "ZR_NAT_PineB_T", c = "ZR_NAT_PineB_C", w = 30 },
		{ t = "ZR_NAT_PineC_T", c = "ZR_NAT_PineC_C", w = 24, young = true },
		{ t = "ZR_NAT_Snag_T", w = 5 },
	}
	local wsum = 0
	for _, t in TREES do
		wsum += t.w
	end
	local nTrees, nBush, nRock = 0, 0, 0
	local function tree(x, z, kind, s, yaw)
		local y, n = gy(x, z)
		local tilt = math.sqrt(math.max(0, 1 - n.Y * n.Y)) / math.max(0.35, n.Y)
		local base = CFrame.new(O.X + x, y - 0.4 - tilt * 1.3 * s, O.Z + z) * CFrame.Angles(0, math.rad(yaw), 0)
		local trunk = nat(forest, kind.t, base, s, nil, true)
		if not trunk then
			-- stand-in when the nature kit did not load: a plain trunk and a dark crown
			trunk = VC(forest, 24 * s, 1.2 * s, x, y - 0.4, z, hex("4A3B2E"), M.Wood)
			if kind.c then
				local b = kit.part(forest, Vector3.one * 9 * s, CFrame.new(O.X + x, y + 17 * s, O.Z + z), hex("34482F"), M.LeafyGrass)
				b.Shape = Enum.PartType.Ball
				b.CanCollide = false
				b.CanQuery = false
			end
		else
			-- trees cast no shadow by default; each client lets the trees near its camera cast one (Detail controller)
			trunk.CastShadow = false
			CollectionService:AddTag(trunk, "ZR_TreeShadow")
			if kind.c then
				local crown = nat(forest, kind.c, base, s, (rng:NextNumber() < 0.04) and hex("C9A97E") or tint(Color3.new(1, 1, 1), 0.16), false)
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
			W.addFoliage(V(x, y, z), 3.1 * s, y + 1.4 * s, y + 11 * s)
		end
		nTrees += 1
	end
	local REACH = PLAY + 12 -- decorative trees just beyond the boundary; the closing hills and the haze do the rest
	for gx = -REACH, REACH, 10 do
		for gz = -REACH, REACH, 10 do
			local x, z = gx + rng:NextNumber(-4, 4), gz + rng:NextNumber(-4, 4)
			local roll, pick, s, yaw = rng:NextNumber(), rng:NextNumber() * wsum, rng:NextNumber(0.82, 1.22), rng:NextNumber(0, 360)
			local h, rd = ground(x, z)
			local dens = 0.6 + 0.45 * math.noise(x / 80 + 2.2, z / 80 + 6.6, 3.7)
			if math.abs(x) > PLAY or math.abs(z) > PLAY then
				dens = math.max(dens, 0.6)
			end
			if roll < dens and h > 1.6 and rd > 3 and not inPad(x, z, 5) and not inClearcut(x, z) and lakeD(x, z) > 1.12 and clear(x, z) then
				local kind = TREES[#TREES]
				for _, t in TREES do
					pick -= t.w
					if pick <= 0 then
						kind = t
						break
					end
				end
				tree(x, z, kind, s, yaw)
			end
		end
	end
	-- bushes: concealment, no collision, no queries
	for _ = 1, 460 do
		local x, z = rng:NextNumber(-PLAY + 4, PLAY - 4), rng:NextNumber(-PLAY + 4, PLAY - 4)
		local key, s, yaw = (rng:NextNumber() < 0.55) and "ZR_NAT_Bush2" or "ZR_NAT_Bush1", rng:NextNumber(1.0, 1.6), rng:NextNumber(0, 360)
		local h, rd = ground(x, z)
		if h > 1.6 and rd > 1.5 and not inPad(x, z, 2) and lakeD(x, z) > 1.08 and clear(x, z) then
			local y = gy(x, z)
			local m = nat(forest, key, CF(x, y - 0.25, z, yaw), s, tint(Color3.new(1, 1, 1), 0.2), false)
			if m then
				m.Name = "Bush"
				m.CastShadow = false
				W.addFoliage(V(x, y, z), math.max(m.Size.X, m.Size.Z) * 0.42, y + 0.3, y + m.Size.Y * 0.95)
				nBush += 1
			end
		end
	end
	-- rocks (more on the ridge), fallen logs, stumps (thick in the clearcut)
	local ROCKS = { { "ZR_NAT_Rock1", 0.8, 1.5 }, { "ZR_NAT_Rock1", 0.8, 1.5 }, { "ZR_NAT_Rock2", 0.7, 1.4 }, { "ZR_NAT_Rock3", 0.8, 1.6 }, { "ZR_NAT_RockPile", 0.8, 1.3 } }
	for _ = 1, 170 do
		local x, z = rng:NextNumber(-PLAY + 6, PLAY - 6), rng:NextNumber(-PLAY + 6, PLAY - 6)
		local r = ROCKS[rng:NextInteger(1, #ROCKS)]
		local s, yaw, keep = rng:NextNumber(r[2], r[3]), rng:NextNumber(0, 360), rng:NextNumber()
		local h, rd = ground(x, z)
		if keep < 0.35 + 0.65 * smooth((-z - 90) / 120) and h > 1.4 and rd > 2 and not inPad(x, z, 3) and lakeD(x, z) > 1.06 and clear(x, z) then
			local y = gy(x, z)
			local m = nat(forest, r[1], CF(x, y - 0.3 * s, z, yaw), s, tint(Color3.new(1, 1, 1), 0.12), true)
			if m then
				m.Name = "Rock"
				nRock += 1
			end
		end
	end
	for _ = 1, 90 do
		local x, z = rng:NextNumber(-PLAY + 8, PLAY - 8), rng:NextNumber(-PLAY + 8, PLAY - 8)
		local len, th, yaw = rng:NextNumber(0.7, 1.7), rng:NextNumber(0.8, 1.25), rng:NextNumber(0, 360)
		local h, rd = ground(x, z)
		if h > 1.6 and rd > 3 and not inPad(x, z, 4) and lakeD(x, z) > 1.1 and clear(x, z) then
			local y, n = gy(x, z)
			if n.Y > 0.93 then
				local m = nat(forest, "ZR_NAT_Log", CF(x, y - 0.3 * th, z, yaw), Vector3.new(len, th, th), nil, true)
				if m then
					m.Name = "FallenLog"
				end
			end
		end
	end
	for k = 1, 220 do
		local inCut = k <= 90
		local x = inCut and rng:NextNumber(CLEARCUT[1], CLEARCUT[2]) or rng:NextNumber(-PLAY + 6, PLAY - 6)
		local z = inCut and rng:NextNumber(CLEARCUT[3], CLEARCUT[4]) or rng:NextNumber(-PLAY + 6, PLAY - 6)
		local s, yaw = rng:NextNumber(0.75, 1.3), rng:NextNumber(0, 360)
		local h, rd = ground(x, z)
		if h > 1.6 and rd > 2 and not inPad(x, z, 2) and lakeD(x, z) > 1.08 and clear(x, z) then
			local y = gy(x, z)
			local m = nat(forest, "ZR_NAT_Stump", CF(x, y - 0.25, z, yaw), s, nil, true)
			if m then
				m.Name = "Stump"
				m.CastShadow = false
			end
		end
	end

	-- ── the play boundary: invisible walls just inside the closing hills ──────────────────────────────────
	for _, b in { { 0, -PLAY - 1, 2 * PLAY + 4, 2 }, { 0, PLAY + 1, 2 * PLAY + 4, 2 }, { -PLAY - 1, 0, 2, 2 * PLAY + 4 }, { PLAY + 1, 0, 2, 2 * PLAY + 4 } } do
		local inv = B(map, b[3], 220, b[4], b[1], 90, b[2], C.pale, M.SmoothPlastic)
		inv.Transparency = 1
		inv.CanQuery = false
		inv.CanTouch = false
		inv.CastShadow = false
		inv.Name = "Boundary"
		inv:SetAttribute("NoDetail", true)
	end
	print(string.format("[ZR] Pinewatch: %d trees, %d bushes, %d rocks, yards at sawmill %.1f, shelter %.1f, radio %.1f, ranger %.1f", nTrees, nBush, nRock, SY, FB, HY, RY))
	return map
end
