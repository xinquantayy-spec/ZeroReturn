--!nonstrict
-- M12 detail plan. After a map is built the server reads its geometry once (walls and their faces, openings,
-- floors and slabs, wall caps) and writes a seeded list of cosmetic details, grouped in 64-stud cells, to
-- ReplicatedStorage.ZR_DetailPlan (one JSON StringValue per cell; underground cells end in "u"). Each client builds the cells near its camera at
-- its graphics level (client Detail controller). Details never collide, block sight or take bullets, and they are
-- kept low or flat against surfaces, so they never become cover; gameplay props stay in World.
--
-- Entry formats (compact arrays):
--   decal { 1, image, x, y, z, nx, ny, nz, w, h, spin, lod, tileU, tileV, transparency, offsetU }
--         carrier centre (already pushed off the surface), outward normal, size along the surface, rotation
--         about the normal (degrees, counter-clockwise as seen from the front); tileU > 0 makes it a Texture.
--   mesh  { 2, key, x, y, z, yaw, pitch, roll, lod, sx, sy, sz, rgb }
--         origin (bottom-centre, or the wall mount point with the piece facing yaw), scale, packed colour (0 = default)
-- lod: 1 = LOW and up, 2 = MEDIUM and up, 3 = HIGH only.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Wear = require(Shared.Wear)

local Plan = { count = 0, stats = {} }
local M = Enum.Material
local D = Wear.DEC
local CELL = Wear.CELL
local UP = Vector3.yAxis

local cells, rng, rp, op
local avoid = {} -- { pos, r }: loot spots, containers, doors, exfils, spawns (World.detailAvoid)

local function r2(v)
	return math.floor(v * 100 + 0.5) / 100
end
local function pack(c: Color3?)
	if not c then
		return 0
	end
	return math.floor(c.R * 255 + 0.5) * 65536 + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5)
end
local function stat(k)
	Plan.stats[k] = (Plan.stats[k] or 0) + 1
end
local UNDER = -2.5 -- entries below this height (tunnels) go into separate "u" cells
local function add(e, pos, kind)
	-- the cell comes from the stored (rounded) position, so an entry on a cell edge stays in its own cell;
	-- underground detail gets its own cells, which clients build only while the camera is underground
	local k = math.floor(e[3] / CELL) .. "_" .. math.floor(e[5] / CELL) .. ((e[4] < UNDER) and "u" or "")
	local c = cells[k]
	if not c then
		c = {}
		cells[k] = c
	end
	table.insert(c, e)
	Plan.count += 1
	stat(kind)
end

local DEC_NAME = {}
for k, v in D do
	DEC_NAME[v] = k
end
local function decal(tex, c, n, w, h, lod, spin, tu, tv, alpha, ou)
	add({ 1, tex, r2(c.X), r2(c.Y), r2(c.Z), r2(n.X), r2(n.Y), r2(n.Z), r2(w), r2(h), math.floor(spin or 0), lod, tu and r2(tu) or 0, tv and r2(tv) or 0, r2(alpha or 0), ou and r2(ou) or 0 }, c, "dec:" .. (DEC_NAME[tex] or "?"))
end
local function mesh(key, pos, yaw, lod, s, col, pitch, roll)
	add({ 2, key, r2(pos.X), r2(pos.Y), r2(pos.Z), math.floor(yaw or 0), math.floor(pitch or 0), math.floor(roll or 0), lod, s and r2(s.X) or 1, s and r2(s.Y) or 1, s and r2(s.Z) or 1, col or 0 }, pos, key)
end

-- yaw (degrees) whose CFrame LookVector is the horizontal direction n
local function yawFacing(n)
	return math.deg(math.atan2(-n.X, -n.Z))
end
local function cast(o, d)
	return workspace:Raycast(o, d, rp)
end
local function openSky(p)
	return cast(p, Vector3.new(0, 90, 0)) == nil
end
local function floorAt(p, maxd)
	local h = cast(p, Vector3.new(0, -(maxd or 4), 0))
	if h and h.Normal.Y > 0.7 then
		return h
	end
	return nil
end
-- nothing solid inside a box (centre, size)
local function free(centre, size)
	return #workspace:GetPartBoundsInBox(CFrame.new(centre), size, op) == 0
end
local function pick(weights)
	local total = 0
	for _, w in weights do
		total += w[2]
	end
	local r = rng:NextNumber() * total
	for _, w in weights do
		r -= w[2]
		if r <= 0 then
			return w[1]
		end
	end
	return weights[#weights][1]
end
local function jitter(c: Color3, amt)
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v * (1 + rng:NextNumber(-amt, amt)), 0, 1))
end

-- ── a wall part ─────────────────────────────────────────────────────────────────
-- returns face data for a vertical slab (local Y up), or nil
local function slabFaces(p)
	if not p:IsA("Part") or p.Shape ~= Enum.PartType.Block or p.Transparency > 0.05 or not p.CanCollide then
		return nil
	end
	local cf, s = p.CFrame, p.Size
	if cf.UpVector.Y < 0.985 then
		return nil
	end
	local thin, len, nrm, along
	if s.Z <= s.X then
		thin, len, nrm, along = s.Z, s.X, cf.LookVector, cf.RightVector
	else
		thin, len, nrm, along = s.X, s.Z, cf.RightVector, cf.LookVector
	end
	if thin > 2.6 or s.Y < 2 or len < 2.4 then
		return nil
	end
	return { thin = thin, len = len, n = Vector3.new(nrm.X, 0, nrm.Z).Unit, along = Vector3.new(along.X, 0, along.Z).Unit, hgt = s.Y, bottom = p.Position.Y - s.Y / 2, top = p.Position.Y + s.Y / 2 }
end

local function rightOf(n)
	return (-n):Cross(UP).Unit -- screen-right for a viewer facing the surface
end

local GROUND_KIT = {
	{ "ZR_WK_Rubble", 14 }, { "ZR_WK_Chips", 16 }, { "ZR_WK_Weeds", 22 }, { "ZR_WK_Litter", 10 }, { "ZR_WK_Bricks", 5 },
	{ "ZR_WK_Planks", 5 }, { "ZR_WK_Cardboard", 6 }, { "ZR_WK_TrashBag", 6 }, { "ZR_WK_Tyre", 3 }, { "ZR_WK_Rebar", 3 }, { "ZR_WK_RubbleLarge", 3 },
}
local INDOOR_KIT = {
	{ "ZR_WK_Litter", 10 }, { "ZR_WK_Chips", 8 }, { "ZR_WK_Cardboard", 6 }, { "ZR_WK_BinTipped", 5 }, { "ZR_WK_ChairTipped", 3 },
	{ "ZR_WK_CeilingTile", 6 }, { "ZR_WK_Bricks", 2 }, { "ZR_WK_Planks", 3 },
}
local KIT_FOOT = { -- half extents on the ground for the free-space test
	ZR_WK_Rubble = Vector3.new(1.4, 0.4, 1.0), ZR_WK_RubbleLarge = Vector3.new(2.5, 0.8, 1.8), ZR_WK_Chips = Vector3.new(1.4, 0.15, 1.0),
	ZR_WK_Weeds = Vector3.new(0.7, 0.5, 0.7), ZR_WK_Litter = Vector3.new(1.0, 0.2, 0.7), ZR_WK_Bricks = Vector3.new(1.0, 0.4, 0.8),
	ZR_WK_Planks = Vector3.new(1.6, 0.3, 1.6), ZR_WK_Cardboard = Vector3.new(1.6, 0.6, 1.1), ZR_WK_TrashBag = Vector3.new(1.0, 0.6, 0.7),
	ZR_WK_Tyre = Vector3.new(1.3, 0.4, 1.3), ZR_WK_Rebar = Vector3.new(2.8, 0.4, 0.8), ZR_WK_BinTipped = Vector3.new(1.3, 0.6, 0.7),
	ZR_WK_ChairTipped = Vector3.new(0.8, 0.8, 1.5), ZR_WK_CeilingTile = Vector3.new(1.3, 0.3, 1.3), ZR_WK_Mattress = Vector3.new(1.6, 0.4, 3.2),
}
local KIT_LOD = { ZR_WK_Rubble = 2, ZR_WK_RubbleLarge = 2, ZR_WK_Weeds = 3, ZR_WK_Litter = 3, ZR_WK_Chips = 3 }

-- drop a ground piece at p (searching down for the floor), facing roughly yaw
local function ground(key, p, yaw, lod, col, fy0)
	local hit = floorAt(p + Vector3.new(0, 2.5, 0), 6)
	if not hit then
		return false
	end
	local fy = hit.Position.Y
	if fy0 and math.abs(fy - fy0) > 0.6 then
		return false
	end
	for _, a in avoid do
		local d = a.pos - Vector3.new(p.X, fy, p.Z)
		if math.abs(d.Y) < 4 and d.X * d.X + d.Z * d.Z < a.r * a.r then
			return false
		end
	end
	local half = KIT_FOOT[key] or Vector3.new(1, 0.5, 1)
	-- the spot must be empty (no wall, crate, stair or door in the way); test a little above the floor
	if not free(Vector3.new(p.X, fy + half.Y + 0.25, p.Z), Vector3.new(half.X * 1.6, half.Y * 2, half.Z * 1.6)) then
		return false
	end
	mesh(key, Vector3.new(p.X, fy, p.Z), yaw, lod or KIT_LOD[key] or 2, nil, col)
	return true
end

local function wallFace(p, f, sign, mat)
	local n = f.n * sign
	local along = f.along
	local right = rightOf(n)
	local mid = (f.bottom + f.top) / 2
	local fc = Vector3.new(p.Position.X, mid, p.Position.Z) + n * (f.thin / 2)
	-- skip faces pressed against something (another wall, a container, a stair)
	if cast(fc + n * 0.05, n * 0.9) then
		return
	end
	local probe = fc + n * 1.4
	local ext = openSky(probe)
	local fh = floorAt(Vector3.new(probe.X, f.bottom + 0.6, probe.Z), 12)
	local floorY = fh and fh.Position.Y
	local onFloor = floorY and math.abs(f.bottom - floorY) < 0.9
	local concrete = mat == M.Concrete or mat == M.Brick or mat == M.Cobblestone
	local metal = mat == M.CorrodedMetal or mat == M.Metal or mat == M.DiamondPlate
	local plaster = mat == M.Plaster
	local len, hgt = f.len, f.hgt
	local u0 = fc:Dot(right) - len / 2
	local function at(u, y, off)
		return Vector3.new(fc.X, y, fc.Z) + right * u + n * off
	end
	-- 1. streaks hanging from the top edge, the whole face (texture strip)
	if hgt >= 2.5 and len >= 2.4 and rng:NextNumber() < (ext and 0.85 or 0.4) then
		decal(D.Streaks, at(0, mid, 0.02), n, len, hgt, 1, 0, rng:NextNumber(6, 9), hgt * 1.02, ext and rng:NextNumber(0.05, 0.3) or rng:NextNumber(0.35, 0.55), u0)
	end
	-- 2. dirt rising from the floor
	if onFloor then
		local hb = math.min(hgt, rng:NextNumber(2.4, 4.2))
		local damp = ext and rng:NextNumber() < 0.3
		decal(damp and D.BaseDamp or D.BaseGrime, at(0, f.bottom + hb / 2, 0.03), n, len, hb, 1, 0, rng:NextNumber(7, 10), hb, ext and rng:NextNumber(0, 0.2) or rng:NextNumber(0.25, 0.45), u0)
	end
	-- 3. interior plaster peels, takes water stains
	if plaster and not ext and hgt >= 3 and rng:NextNumber() < 0.65 then
		decal(D.Peel, at(0, mid, 0.04), n, len, hgt, 2, 0, rng:NextNumber(5, 8), rng:NextNumber(5, 8), rng:NextNumber(0.1, 0.35), u0)
	end
	-- 4. spot marks
	local spots = math.floor(len / 8 + rng:NextNumber())
	for i = 1, spots do
		local off = 0.05 + i * 0.006
		local roll = rng:NextNumber()
		if roll < 0.32 then
			local s = rng:NextNumber(2.4, 5)
			if hgt > s + 0.4 and len > s * 0.6 then
				decal(D.Crack, at(rng:NextNumber(-len / 2 + s / 3, len / 2 - s / 3), rng:NextNumber(f.bottom + s / 2, f.top - s / 2), off), n, s, s, 2, rng:NextInteger(0, 3) * 90, nil, nil, rng:NextNumber(0, 0.25))
			end
		elseif roll < 0.52 and concrete then
			local s = rng:NextNumber(1.3, 2.6)
			if hgt > s + 0.4 and len > s then
				decal(D.Spall, at(rng:NextNumber(-len / 2 + s / 2, len / 2 - s / 2), rng:NextNumber(f.bottom + s / 2, f.top - s / 2), off), n, s, s * 0.75, 2, 0)
			end
		elseif roll < 0.58 then
			local s = rng:NextNumber(1.8, 3)
			if hgt > s + 1 and len > s then
				decal(D.Holes, at(rng:NextNumber(-len / 2 + s / 2, len / 2 - s / 2), rng:NextNumber(f.bottom + 1.5, math.max(f.bottom + 1.6, math.min(f.top - s / 2, f.bottom + 6))), off), n, s, s, 3, rng:NextInteger(0, 3) * 90)
			end
		elseif roll < 0.68 and ext and onFloor and hgt >= 5 then
			local w = rng:NextNumber(4, 6)
			if len > w + 0.4 then
				local tag = pick({ { D.Tag1, 3 }, { D.Tag2, 2 }, { D.Tag3, 2 }, { D.Stencil, 2 } })
				decal(tag, at(rng:NextNumber(-len / 2 + w / 2, len / 2 - w / 2), f.bottom + rng:NextNumber(2.6, 4.6), off), n, w, w / 2, 2, 0, nil, nil, rng:NextNumber(0.05, 0.35))
			end
		elseif roll < 0.84 and metal then
			local w, h = rng:NextNumber(0.9, 1.6), rng:NextNumber(2.4, 4)
			if hgt > h and len > w then
				decal(D.RustRun, at(rng:NextNumber(-len / 2 + w / 2, len / 2 - w / 2), f.top - h / 2 - rng:NextNumber(0.1, 1.2), off), n, w, h, 2, 0)
			end
		elseif roll < 0.9 and not ext then
			local s = rng:NextNumber(2.5, 4)
			if hgt > s and len > s then
				decal(D.Leak, at(rng:NextNumber(-len / 2 + s / 2, len / 2 - s / 2), f.top - s / 2 - 0.1, off), n, s, s, 3, 0, nil, nil, rng:NextNumber(0.1, 0.3))
			end
		end
	end
	-- 5. things fixed to tall outside walls (conduit, AC unit, electrics, downpipe, vents, a lamp, sagging cable)
	local yaw = yawFacing(n)
	local function mount(key, u, y, need, lod, s)
		local pt = at(u, y, 0.01)
		-- nothing right in front of the piece (balcony slab, stairs, another building)
		if cast(pt + n * 0.05, n * (need or 1.2)) then
			return false
		end
		mesh(key, at(u, y, 0), yaw, lod, s)
		return true
	end
	if ext and hgt >= 7 and len >= 3 then
		if rng:NextNumber() < 0.22 and onFloor then
			local u = (rng:NextNumber() < 0.5 and -1 or 1) * (len / 2 - 0.55)
			mount("ZR_WK_Downpipe", u, floorY, 1.0, 2, Vector3.new(1, (f.top - floorY - 0.3) / 10.1, 1))
		end
		if rng:NextNumber() < 0.13 and len >= 3.4 then
			mount("ZR_WK_AC", rng:NextNumber(-len / 2 + 1.4, len / 2 - 1.4), f.bottom + rng:NextNumber(4.6, math.min(hgt - 1.1, 7.6)), 1.4, 2)
		end
		if rng:NextNumber() < 0.11 and onFloor and len >= 2 then
			mount("ZR_WK_ElecBox", rng:NextNumber(-len / 2 + 0.8, len / 2 - 0.8), floorY + 3.6, 0.8, 3)
		end
		if rng:NextNumber() < 0.2 and len >= 9 then
			mount("ZR_WK_Conduit", rng:NextNumber(-len / 2 + 4.3, len / 2 - 4.3), f.bottom + rng:NextNumber(5.8, hgt - 0.6), 0.6, 2)
		end
		if rng:NextNumber() < 0.12 then
			mount("ZR_WK_Vent", rng:NextNumber(-len / 2 + 0.7, len / 2 - 0.7), f.bottom + rng:NextNumber(1.4, hgt - 0.8), 0.4, 3)
		end
		if rng:NextNumber() < 0.08 and hgt >= 8 then
			mount("ZR_WK_WallLamp", rng:NextNumber(-len / 2 + 0.5, len / 2 - 0.5), f.bottom + rng:NextNumber(6, 7.4), 0.5, 3)
		end
		if rng:NextNumber() < 0.12 and len >= 11 then
			mount("ZR_WK_CableSag", rng:NextNumber(-len / 2 + 5.2, len / 2 - 5.2), f.top - rng:NextNumber(0.7, 1.6), 0.5, 3)
		end
	elseif not ext and plaster and onFloor and len >= 3 and rng:NextNumber() < 0.12 then
		mount("ZR_WK_Radiator", rng:NextNumber(-len / 2 + 1.5, len / 2 - 1.5), floorY + 0.05, 0.5, 3)
	end
	-- 6. ground clutter and leaves along the foot of the wall
	if onFloor then
		local step = 5
		local u = -len / 2 + rng:NextNumber(1, 3)
		while u < len / 2 - 1 do
			local dens = ext and 0.3 or 0.16
			if rng:NextNumber() < dens then
				local key = pick(ext and GROUND_KIT or INDOOR_KIT)
				local p0 = at(u + rng:NextNumber(-1, 1), floorY, rng:NextNumber(1.0, 1.8))
				local col = (key == "ZR_WK_Rubble" or key == "ZR_WK_RubbleLarge" or key == "ZR_WK_Chips") and pack(jitter(p.Color, 0.12)) or 0
				ground(key, p0, yaw + rng:NextNumber(-35, 35) + (key == "ZR_WK_Weeds" and rng:NextNumber(0, 360) or 0), nil, col, floorY)
			end
			if ext and rng:NextNumber() < 0.12 then
				local w = rng:NextNumber(2, 3.5)
				local gp = at(u, floorY + 0.03, w / 2 + 0.1)
				if floorAt(gp + Vector3.new(0, 0.5, 0), 1) then
					decal(D.Leaves, gp, UP, w, w, 3, rng:NextInteger(0, 359), w, w, rng:NextNumber(0, 0.2))
				end
			end
			u += step
		end
	end
end

-- openings: a part spanning over a gap (lintel). Corner cracks at the opening's corners, a broken window
-- (glass remnants and a rotten frame) when there is a sill below.
local function opening(p, f)
	local below = cast(Vector3.new(p.Position.X, f.bottom - 0.02, p.Position.Z), Vector3.new(0, -12, 0))
	if not below then
		return
	end
	local gap = f.bottom - below.Position.Y
	if gap < 2 then
		return
	end
	local hitPart = below.Instance
	local isWindow = hitPart and hitPart ~= p and hitPart:IsA("Part") and slabFaces(hitPart) ~= nil and below.Position.Y > (hitPart.Position.Y + hitPart.Size.Y / 2 - 0.05)
		and (floorAt(Vector3.new(p.Position.X, below.Position.Y - 0.1, p.Position.Z) + f.n * 1.5, 12) ~= nil)
	-- a sill that does not reach the floor: the hit part's bottom is the floor itself only for doors
	local sillTop = below.Position.Y
	if isWindow then
		local fb = floorAt(Vector3.new(p.Position.X, sillTop - 0.05, p.Position.Z) + f.n * (f.thin / 2 + 1.2), 12)
		isWindow = fb ~= nil and sillTop - fb.Position.Y > 0.8
	end
	for _, sign in { 1, -1 } do
		local n = f.n * sign
		local right = rightOf(n)
		local base = Vector3.new(p.Position.X, 0, p.Position.Z) + n * (f.thin / 2 + 0.06)
		for _, side in { 1, -1 } do
			local corner = base + right * (side * f.len / 2)
			if rng:NextNumber() < 0.35 then
				local s = rng:NextNumber(1.8, 2.8)
				local c = corner + right * (side * s / 2) + Vector3.new(0, f.bottom + s / 2, 0)
				decal(D.CornerCrack, c, n, s, s, 2, side == 1 and 0 or 90)
			end
			if isWindow and rng:NextNumber() < 0.3 then
				local s = rng:NextNumber(1.6, 2.4)
				local c = corner + right * (side * s / 2) + Vector3.new(0, sillTop - s / 2, 0)
				decal(D.CornerCrack, c, n, s, s, 2, side == 1 and 270 or 180)
			end
		end
		if isWindow and openSky(base + n * 1.5 + Vector3.new(0, f.bottom, 0)) and rng:NextNumber() < 0.12 then
			local w = math.min(f.len + 1, 5)
			decal(D.Soot, base + Vector3.new(0, f.bottom + w / 2 - 0.3, 0) + n * 0.01, n, w, w, 3, 0, nil, nil, 0.15)
		end
	end
	if isWindow then
		local h = f.bottom - sillTop
		local centre = Vector3.new(p.Position.X, (f.bottom + sillTop) / 2, p.Position.Z)
		local ext = f.n
		if not openSky(centre + ext * 2) and openSky(centre - ext * 2) then
			ext = -ext
		end
		local yaw = yawFacing(ext)
		if rng:NextNumber() < 0.6 then
			mesh("ZR_WK_Shards", centre, yaw, 2, Vector3.new(f.len / 4, h / 3.2, 1))
		end
		if rng:NextNumber() < 0.65 then
			mesh("ZR_WK_WindowFrame", centre + ext * 0.04, yaw, 2, Vector3.new(f.len / 4, h / 3.2, 1))
		end
	end
end

-- shipping containers (Blender mesh, long axis = local X): rust runs under the roof rail, dirt streaks and
-- grime at the foot on every long side that is not pressed against a neighbour
local function container(p)
	local cf, s = p.CFrame, p.Size
	if cf.UpVector.Y < 0.985 then
		return
	end
	local len, hgt = s.X, s.Y
	local bottom, top = p.Position.Y - hgt / 2, p.Position.Y + hgt / 2
	for _, sign in { 1, -1 } do
		local n = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit * sign
		local fc = Vector3.new(p.Position.X, (bottom + top) / 2, p.Position.Z) + n * (s.Z / 2)
		if cast(fc + n * 0.05, n * 0.9) then
			continue -- the next container in the row
		end
		local right = rightOf(n)
		local function at(u, y, off)
			return Vector3.new(fc.X, y, fc.Z) + right * u + n * off
		end
		local u0 = fc:Dot(right) - len / 2
		if rng:NextNumber() < 0.75 then
			decal(D.Streaks, at(0, (bottom + top) / 2, 0.03), n, len * 0.98, hgt * 0.96, 2, 0, rng:NextNumber(6, 9), hgt, rng:NextNumber(0.3, 0.55), u0)
		end
		for _ = 1, rng:NextInteger(1, 3) do
			local w, h = rng:NextNumber(0.9, 1.6), rng:NextNumber(2.4, 4.2)
			decal(D.RustRun, at(rng:NextNumber(-len / 2 + 1, len / 2 - 1), top - h / 2 - rng:NextNumber(0.2, 0.8), 0.04), n, w, h, 2, 0)
		end
		if rng:NextNumber() < 0.25 then
			local w = rng:NextNumber(3, 5)
			local tag = pick({ { D.Tag1, 3 }, { D.Tag3, 2 }, { D.Stencil, 2 } })
			decal(tag, at(rng:NextNumber(-len / 2 + w / 2, len / 2 - w / 2), bottom + rng:NextNumber(2.4, 4.4), 0.05), n, w, w / 2, 3, 0, nil, nil, rng:NextNumber(0.1, 0.35))
		end
		local fh = floorAt(at(0, bottom + 0.6, 1.4), 1.2)
		if fh then
			local hb = rng:NextNumber(1.6, 2.6)
			decal(D.BaseGrime, at(0, bottom + hb / 2, 0.035), n, len * 0.98, hb, 2, 0, rng:NextNumber(7, 10), hb, rng:NextNumber(0.1, 0.35), u0)
		end
	end
end

-- wall caps and the top of long boundary walls: barbed wire
local function capWire(p)
	local s = p.Size
	local cf = p.CFrame
	if cf.UpVector.Y < 0.985 or s.Y > 1.6 then
		return
	end
	local len, dir = s.X, cf.RightVector
	if s.Z > s.X then
		len, dir = s.Z, cf.LookVector
	end
	if len < 40 or math.min(s.X, s.Z) > 3 or p.Position.Y < 9 then
		return
	end
	local top = p.Position.Y + s.Y / 2
	local yaw = yawFacing(Vector3.new(dir.Z, 0, -dir.X).Unit)
	local k = -len / 2 + 6
	while k < len / 2 - 6 do
		if rng:NextNumber() < 0.75 then
			mesh("ZR_WK_Barbed", Vector3.new(p.Position.X, top, p.Position.Z) + dir * k, yaw, 3)
		end
		k += 8
	end
end

-- horizontal surfaces: ground marks, puddles, debris outside; dust, papers, a fallen tile, hanging wires inside
local function floorPart(p)
	if not p:IsA("BasePart") or p.Transparency > 0.05 or not p.CanCollide or p:IsA("MeshPart") or p:IsA("WedgePart") then
		return
	end
	if p:IsA("Part") and p.Shape ~= Enum.PartType.Block then
		return
	end
	local cf, s = p.CFrame, p.Size
	if cf.UpVector.Y < 0.985 or s.Y > 9 or math.min(s.X, s.Z) < 4 then
		return
	end
	local top = p.Position.Y + s.Y / 2
	if top > 16 then
		return -- roofs
	end
	local asphalt = p.Material == M.Asphalt
	local area = s.X * s.Z
	local samples = math.clamp(math.floor(area / (asphalt and 110 or 170)), 1, 16)
	for _ = 1, samples do
		local lx, lz = rng:NextNumber(-s.X / 2 + 1, s.X / 2 - 1), rng:NextNumber(-s.Z / 2 + 1, s.Z / 2 - 1)
		local pt = (cf * CFrame.new(lx, s.Y / 2, lz)).Position
		local hit = cast(pt + Vector3.new(0, 3, 0), Vector3.new(0, -3.4, 0))
		if hit and hit.Instance == p then
			local y = hit.Position.Y
			local c = Vector3.new(pt.X, y + 0.025, pt.Z)
			local inside = not openSky(Vector3.new(pt.X, y + 0.5, pt.Z))
			local roll = rng:NextNumber()
			if not inside then
				if asphalt and roll < 0.18 then
					local w = rng:NextNumber(10, 14)
					decal(D.Skid, c, UP, w, w * 0.25, 3, rng:NextInteger(0, 359), nil, nil, rng:NextNumber(0.1, 0.4))
				elseif asphalt and roll < 0.24 then
					decal(D.Manhole, c + Vector3.new(0, 0.005, 0), UP, 2.6, 2.6, 2, rng:NextInteger(0, 359))
				elseif roll < 0.48 then
					local w = rng:NextNumber(6, 11)
					decal(D.GroundCrack, c, UP, w, w, 2, rng:NextInteger(0, 359), w, w, rng:NextNumber(0, 0.25))
				elseif roll < 0.58 then
					local w = rng:NextNumber(2, 4.5)
					decal(D.Oil, c, UP, w, w, 2, rng:NextInteger(0, 359), nil, nil, rng:NextNumber(0.05, 0.3))
				elseif roll < 0.7 then
					local w = rng:NextNumber(3.5, 6)
					decal(D.Wet, c, UP, w, w * 0.75, 2, rng:NextInteger(0, 359), nil, nil, rng:NextNumber(0.1, 0.35))
					if rng:NextNumber() < 0.6 then
						mesh("ZR_WK_Puddle", Vector3.new(c.X, y + 0.01, c.Z), rng:NextNumber(0, 360), 2, Vector3.new(w / 4.2, 1, w / 4.2))
					end
				elseif roll < 0.82 then
					local w = rng:NextNumber(2.5, 4.5)
					decal(D.Debris, c, UP, w, w, 3, rng:NextInteger(0, 359), w, w, rng:NextNumber(0, 0.3))
				elseif roll < 0.9 then
					local w = rng:NextNumber(3, 5)
					decal(D.Leaves, c, UP, w, w, 3, rng:NextInteger(0, 359), w, w, rng:NextNumber(0, 0.3))
				elseif roll < 0.97 then
					ground(pick({ { "ZR_WK_Litter", 4 }, { "ZR_WK_Weeds", 3 }, { "ZR_WK_Planks", 1 }, { "ZR_WK_Tyre", 1 }, { "ZR_WK_TrashBag", 1 } }), c, rng:NextNumber(0, 360), nil, nil, y)
				end
			else
				if roll < 0.42 then
					local w = rng:NextNumber(5, 8)
					decal(D.FloorDust, c, UP, w, w, 2, rng:NextInteger(0, 359), w, w, rng:NextNumber(0.1, 0.35))
				elseif roll < 0.66 then
					local w = rng:NextNumber(2.2, 3.6)
					decal(D.Papers, c, UP, w, w, 3, rng:NextInteger(0, 359), nil, nil, rng:NextNumber(0, 0.15))
				elseif roll < 0.76 then
					local w = rng:NextNumber(2, 3.5)
					decal(D.Debris, c, UP, w, w, 3, rng:NextInteger(0, 359), w, w, rng:NextNumber(0.1, 0.4))
				elseif roll < 0.9 then
					local key = pick(INDOOR_KIT)
					if ground(key, c, rng:NextNumber(0, 360), 3, nil, y) and key == "ZR_WK_CeilingTile" then
						local ceil = cast(Vector3.new(c.X, y + 0.5, c.Z), Vector3.new(0, 14, 0))
						if ceil then
							mesh("ZR_WK_WiresHang", ceil.Position - Vector3.new(0, 0.02, 0), rng:NextNumber(0, 360), 3)
						end
					end
				else
					local ceil = cast(Vector3.new(c.X, y + 0.5, c.Z), Vector3.new(0, 14, 0))
					if ceil and ceil.Position.Y - y > 6 then
						mesh("ZR_WK_WiresHang", ceil.Position - Vector3.new(0, 0.02, 0), rng:NextNumber(0, 360), 3)
					end
				end
			end
		end
	end
end

function Plan.generate(list, seed, avoidList)
	cells, Plan.count, Plan.stats = {}, 0, {}
	avoid = avoidList or {}
	rng = Random.new(seed or 1207)
	rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = list
	rp.RespectCanCollide = true
	op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = list
	op.RespectCanCollide = true
	local t0 = os.clock()
	local parts = {}
	for _, m in list do
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
	end
	-- deterministic order (GetDescendants order is stable per build, but sort anyway)
	table.sort(parts, function(a, b)
		local pa, pb = a.Position, b.Position
		if pa.X ~= pb.X then
			return pa.X < pb.X
		end
		if pa.Z ~= pb.Z then
			return pa.Z < pb.Z
		end
		return pa.Y < pb.Y
	end)
	for i, p in parts do
		if p:GetAttribute("NoDetail") then
			continue
		end
		if p:IsA("MeshPart") and p.Name == "ZR_ENV_Container20" then
			container(p)
			continue
		end
		local f = slabFaces(p)
		if f then
			if f.hgt <= 6.5 and f.len <= 8 then
				local base = cast(Vector3.new(p.Position.X, f.bottom - 0.02, p.Position.Z), Vector3.new(0, -12, 0))
				if base and f.bottom - base.Position.Y >= 2 then
					opening(p, f)
				end
			end
			for _, sign in { 1, -1 } do
				wallFace(p, f, sign, p.Material)
			end
		else
			capWire(p)
			floorPart(p)
		end
		if i % 120 == 0 then
			task.wait()
		end
	end
	-- publish: one JSON string per cell
	local folder = ReplicatedStorage:FindFirstChild("ZR_DetailPlan")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "ZR_DetailPlan"
	local bytes = 0
	for k, list2 in cells do
		local sv = Instance.new("StringValue")
		sv.Name = k
		sv.Value = HttpService:JSONEncode(list2)
		bytes += #sv.Value
		sv.Parent = folder
	end
	folder:SetAttribute("Count", Plan.count)
	folder.Parent = ReplicatedStorage
	local top = {}
	for k, v in Plan.stats do
		table.insert(top, { k, v })
	end
	table.sort(top, function(a, b)
		return a[2] > b[2]
	end)
	local parts2 = {}
	for i2 = 1, math.min(14, #top) do
		table.insert(parts2, top[i2][1] .. "=" .. top[i2][2])
	end
	print(string.format("[ZR] Detail plan: %d entries in %d cells (%.0f KB) in %.2fs; %s", Plan.count, #folder:GetChildren(), bytes / 1024, os.clock() - t0, table.concat(parts2, " ")))
	return Plan.count
end

return Plan
