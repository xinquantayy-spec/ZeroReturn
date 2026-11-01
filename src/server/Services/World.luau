--!nonstrict
-- Builds the safehouse and every raid map at server start (deterministic, no saved place data needed). Each map
-- sits at its own origin; Match picks one per raid (map vote) and World.activate points the per-raid tables
-- (spawns, extracts, patrols, loose spots, AI zones, boss) at it. Containers and doors of every map stay live.
-- Uploaded Blender meshes (ReplicatedStorage.ZR_Assets) replace part-built fallbacks when available.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Config = require(Shared.Config)
local AssetMeta = require(Shared.AssetMeta)

local World = {}
World.spawns = {}
World.extracts = {}
World.containers = {}
World.patrols = {}
World.doors = {}
World.switches = {} -- M13: [id] = { id, label, part, prompt, delay, onChange(on), map } (Doors.luau runs them)
World.safehouse = {}

-- whether a switch (the Meridian Mall generator) is on in this raid
function World.switchOn(id)
	local sw = World.switches[id]
	return sw ~= nil and sw.on == true
end

local root: Folder

-- M13 map registry: per-map tables live in World.maps[id]; World.activate copies them onto the World fields
-- every service reads (ctx.World.spawns, ctx.World.extracts, ...).
World.maps = {}
World.activeMap = nil
local PER_MAP = { "spawns", "sideExtracts", "extracts", "patrols", "looseSpots", "scavZones", "watchPosts", "visitZones", "boss", "bounds" }
local currentMap = nil
local function beginMap(id)
	currentMap = id
	World.spawns, World.extracts, World.patrols, World.looseSpots = {}, {}, {}, {}
	World.sideExtracts, World.scavZones, World.watchPosts, World.visitZones = {}, {}, {}, {}
	World.boss, World.bounds = nil, nil
end
-- z-fighting (owner, 2026-11-01: "textures keep glitching near the corners"): two parts whose faces lie in the same
-- plane, facing the same way, over a shared area flicker as the camera moves (walls overlapping at a corner, slabs
-- overlapping where floors meet, trims flush with a wall end). Every such pair in a finished map gets one face pulled
-- back by a hair (the smaller part's), so one surface is always in front. Axis-aligned blocks only (the map kits'
-- walls, slabs and trims); meshes and invisible parts are left alone.
local ZF_EPS, ZF_TOL, ZF_CELL = 0.03, 0.004, 24
function World.fixCoplanar(model)
	local list = {}
	for _, p in model:GetDescendants() do
		if p:IsA("Part") and p.Shape == Enum.PartType.Block and p.Transparency < 1 then
			local cf = p.CFrame
			local ok = true
			for _, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
				local ax = math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
				if ax < 0.9999 then
					ok = false
					break
				end
			end
			if ok then
				local e = ((cf.RightVector * p.Size.X):Abs() + (cf.UpVector * p.Size.Y):Abs() + (cf.LookVector * p.Size.Z):Abs()) / 2
				table.insert(list, { p = p, lo = cf.Position - e, hi = cf.Position + e, vol = p.Size.X * p.Size.Y * p.Size.Z, solid = p.Transparency < 0.05 })
			end
		end
	end
	local cells = {}
	for i, b in list do
		for cx = math.floor(b.lo.X / ZF_CELL), math.floor(b.hi.X / ZF_CELL) do
			for cz = math.floor(b.lo.Z / ZF_CELL), math.floor(b.hi.Z / ZF_CELL) do
				local k = cx * 65536 + cz
				cells[k] = cells[k] or {}
				table.insert(cells[k], i)
			end
		end
	end
	local AX = { "X", "Y", "Z" }
	local OTHER = { X = { "Y", "Z" }, Y = { "X", "Z" }, Z = { "X", "Y" } }
	local seen, fixed = {}, 0
	-- a shared face that something else sits flush against (a wall's top under the ceiling, its foot on the floor,
	-- the inside of a junction) is never seen, so it cannot flicker, and pulling it back would only open a hairline
	-- slit along the whole part (owner, 2026-11-01: glitching in the bunker). Covered = five points of the overlap,
	-- just outside the face, all inside another solid block of the same map. (The map is not in the workspace yet
	-- while it is built, so this tests the blocks collected above, not a spatial query.)
	local function inside(x, y, z, a, b)
		local k = math.floor(x / ZF_CELL) * 65536 + math.floor(z / ZF_CELL)
		for _, idx in cells[k] or {} do
			local c = list[idx]
			if c ~= a and c ~= b and c.solid and x > c.lo.X and x < c.hi.X and y > c.lo.Y and y < c.hi.Y and z > c.lo.Z and z < c.hi.Z then
				return true
			end
		end
		return false
	end
	local function covered(a, b, ax, side)
		local o = OTHER[ax]
		local u0, u1 = math.max(a.lo[o[1]], b.lo[o[1]]), math.min(a.hi[o[1]], b.hi[o[1]])
		local v0, v1 = math.max(a.lo[o[2]], b.lo[o[2]]), math.min(a.hi[o[2]], b.hi[o[2]])
		local plane = (side > 0 and a.hi[ax] or a.lo[ax]) + side * 0.02
		for _, f in { { 0.5, 0.5 }, { 0.2, 0.2 }, { 0.8, 0.2 }, { 0.2, 0.8 }, { 0.8, 0.8 } } do
			local c = { [ax] = plane, [o[1]] = u0 + (u1 - u0) * f[1], [o[2]] = v0 + (v1 - v0) * f[2] }
			if not inside(c.X, c.Y, c.Z, a, b) then
				return false
			end
		end
		return true
	end
	-- pull face (axis, side) of part b back by ZF_EPS
	local function pull(b, axis, side)
		local p = b.p
		local cf = p.CFrame
		local w = (axis == "X" and Vector3.xAxis) or (axis == "Y" and Vector3.yAxis) or Vector3.zAxis
		local locals = { { cf.RightVector, "X" }, { cf.UpVector, "Y" }, { cf.LookVector, "Z" } }
		for _, l in locals do
			if math.abs(l[1]:Dot(w)) > 0.9999 then
				local size = p.Size
				local amt = math.min(ZF_EPS, size[l[2]] * 0.25)
				p.Size = Vector3.new(l[2] == "X" and size.X - amt or size.X, l[2] == "Y" and size.Y - amt or size.Y, l[2] == "Z" and size.Z - amt or size.Z)
				p.CFrame = cf - w * (side * amt / 2)
				if side > 0 then
					b.hi = b.hi - w * amt
				else
					b.lo = b.lo + w * amt
				end
				return
			end
		end
	end
	for _, idxs in cells do
		for ia = 1, #idxs do
			for ib = ia + 1, #idxs do
				local i, j = idxs[ia], idxs[ib]
				local key = i < j and (i * 1048576 + j) or (j * 1048576 + i)
				if not seen[key] then
					seen[key] = true
					local a, b = list[i], list[j]
					if a.lo.X < b.hi.X - ZF_TOL and b.lo.X < a.hi.X - ZF_TOL and a.lo.Y < b.hi.Y - ZF_TOL and b.lo.Y < a.hi.Y - ZF_TOL
						and a.lo.Z < b.hi.Z - ZF_TOL and b.lo.Z < a.hi.Z - ZF_TOL then
						local small = (a.vol <= b.vol) and a or b
						for _, ax in AX do
							if math.abs(a.hi[ax] - b.hi[ax]) < ZF_TOL and not covered(a, b, ax, 1) then
								pull(small, ax, 1)
								fixed += 1
							end
							if math.abs(a.lo[ax] - b.lo[ax]) < ZF_TOL and not covered(a, b, ax, -1) then
								pull(small, ax, -1)
								fixed += 1
							end
						end
					end
				end
			end
		end
	end
	return fixed
end

-- A switch's state (the Meridian power lever, the IRONSIGHT alarm terminal ...) is published as the workspace attribute
-- ZR_Sw_<id> (true / false) so clients can react to it: the mall's mains hum follows ZR_Sw_MALL_POWER (Ambience.luau). Doors.luau
-- calls onChange on every change and at every raid reset, so wrapping it is enough.
local function publishSwitch(sid, sw)
	if sw.published then
		return
	end
	sw.published = true
	local inner = sw.onChange
	local attr = "ZR_Sw_" .. tostring(sw.id or sid)
	sw.onChange = function(on)
		pcall(workspace.SetAttribute, workspace, attr, on == true)
		if inner then
			return inner(on)
		end
	end
end
World.publishSwitch = publishSwitch -- (LogicTests)

local function endMap(id, mapModel)
	local zf = World.fixCoplanar(mapModel)
	print(string.format("[ZR] %s: %d coplanar faces pulled back (z-fighting)", id, zf))

	local m = { id = id, model = mapModel }
	for _, k in PER_MAP do
		m[k] = World[k]
	end
	for _, d in World.doors do
		d.map = d.map or id
	end
	for sid, sw in World.switches do
		sw.map = sw.map or id
		publishSwitch(sid, sw)
	end
	World.maps[id] = m
	currentMap = nil
	return m
end
function World.activate(id)
	local m = World.maps[id]
	if not m then
		return false
	end
	for _, k in PER_MAP do
		World[k] = m[k]
	end
	World.activeMap = id
	World.map = m.model
	if World.onActivate then
		task.spawn(World.onActivate, id, m) -- the detail plan publishes this map's cells
	end
	return true
end
-- every map model (AI sight and cover, detail plan)
function World.mapModels()
	local out = {}
	for _, m in World.maps do
		table.insert(out, m.model)
	end
	return out
end

-- M13 concealing foliage (bushes, young pines on terrain maps). The meshes take no collisions and no queries, so
-- shots and grenades pass through, but they hide what is behind or inside them: players see that on screen and the
-- AI asks World.foliageBetween. Each piece is a vertical cylinder (centre, radius, height range) kept in 16-stud
-- cells.
local FCELL = 16
World.foliage = { cells = {}, n = 0 }
function World.addFoliage(pos, r, y0, y1)
	local f = World.foliage
	local item = { x = pos.X, z = pos.Z, r = r, y0 = y0, y1 = y1 }
	for cx = math.floor((pos.X - r) / FCELL), math.floor((pos.X + r) / FCELL) do
		for cz = math.floor((pos.Z - r) / FCELL), math.floor((pos.Z + r) / FCELL) do
			local k = cx .. "," .. cz
			local list = f.cells[k]
			if not list then
				list = {}
				f.cells[k] = list
			end
			table.insert(list, item)
		end
	end
	f.n += 1
	return item
end
-- does the sight line a -> b pass through foliage? (a viewer standing inside a bush still sees out of it)
function World.foliageBetween(a, b)
	local f = World.foliage
	if f.n == 0 then
		return false
	end
	local dx, dz = b.X - a.X, b.Z - a.Z
	local len = math.sqrt(dx * dx + dz * dz)
	local steps = math.max(1, math.ceil(len / (FCELL / 2)))
	local seen = {}
	for i = 0, steps do
		local t = i / steps
		local k = math.floor((a.X + dx * t) / FCELL) .. "," .. math.floor((a.Z + dz * t) / FCELL)
		if not seen[k] then
			seen[k] = true
			for _, it in f.cells[k] or {} do
				if seen[it] then
					continue
				end
				seen[it] = true
				local ox, oz = a.X - it.x, a.Z - it.z
				local cc = ox * ox + oz * oz - it.r * it.r
				if cc <= 0 then
					continue -- the viewer is inside this one
				end
				-- where does the line enter and leave the circle (t in 0..1)?
				local qa = dx * dx + dz * dz
				if qa < 1e-6 then
					continue
				end
				local qb = 2 * (ox * dx + oz * dz)
				local disc = qb * qb - 4 * qa * cc
				if disc > 0 then
					local sq = math.sqrt(disc)
					local t0, t1 = math.max(0, (-qb - sq) / (2 * qa)), math.min(1, (-qb + sq) / (2 * qa))
					if t0 < t1 then
						local y0, y1 = a.Y + (b.Y - a.Y) * t0, a.Y + (b.Y - a.Y) * t1
						if math.max(y0, y1) >= it.y0 and math.min(y0, y1) <= it.y1 then
							return true
						end
					end
				end
			end
		end
	end
	return false
end
local rng = Random.new(707)
local M = Enum.Material
local function hex(h)
	return Color3.fromHex(h)
end
local C = {
	concrete = hex("6F716C"), concreteDark = hex("575A56"), concreteLight = hex("8C8D86"), asphalt = hex("3D403F"),
	line = hex("A99A62"), rust = hex("8A6252"), rustDark = hex("5E4236"), metal = hex("5C6461"), metalDark = hex("33383B"),
	olive = hex("5E6448"), sand = hex("B1A893"), mist = hex("96A4A2"), orange = hex("C07946"), yellow = hex("C29A38"),
	pale = hex("D6DBC9"), wood = hex("6E5A44"), blue = hex("3E5868"), red = hex("7A3E33"), teal = hex("3D5A57"),
	wall = hex("666A63"), interior = hex("7D7F76"), floor = hex("4C4F4B"),
}
World.C = C

-- ── primitives ───────────────────────────────────────────────────────────────
local function part(parent, size, cf, color, mat, class)
	local p = Instance.new(class or "Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function box(parent, sx, sy, sz, x, y, z, color, mat, ry)
	local cf = CFrame.new(x, y, z)
	if ry then
		cf *= CFrame.Angles(0, math.rad(ry), 0)
	end
	return part(parent, Vector3.new(sx, sy, sz), cf, color, mat)
end
local function boxCF(parent, sx, sy, sz, cf, color, mat)
	return part(parent, Vector3.new(sx, sy, sz), cf, color, mat)
end
-- cylinder along local X; use cf rotation to orient
local function cyl(parent, length, diameter, cf, color, mat)
	local p = part(parent, Vector3.new(length, diameter, diameter), cf, color, mat)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function vcyl(parent, height, diameter, x, y, z, color, mat)
	return cyl(parent, height, diameter, CFrame.new(x, y + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)), color, mat)
end
local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
local function jitter(c, amt)
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v * (1 + rng:NextNumber(-amt, amt)), 0, 1))
end
local function light(parent, color, range, brightness, shadows)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows or false
	l.Parent = parent
	return l
end
local function sign(parent, face, text, textColor, bg)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 24
	g.LightInfluence = 1
	g.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = bg or C.metalDark
	t.BackgroundTransparency = bg and 0 or 1
	t.TextColor3 = textColor or C.pale
	t.Font = Enum.Font.RobotoMono
	t.TextScaled = true
	t.Text = text
	t.Parent = g
	return g
end

-- mesh asset or nil (ReplicatedStorage.ZR_Assets populated by the Assets service)
local function mesh(key, parent, bottomCF, color)
	local lib = ReplicatedStorage:FindFirstChild("ZR_Assets")
	local src = lib and lib:FindFirstChild(key)
	if not src then
		return nil
	end
	local m = src:Clone()
	m.Anchored = true
	m.CFrame = bottomCF * CFrame.new(AssetMeta[key] or Vector3.new(0, m.Size.Y / 2, 0))
	if color then
		m.Color = color
	end
	m.Parent = parent
	return m
end

-- wall along local X with door openings {center offset, width, height}
local function wall(parent, cf, length, height, thick, color, mat, openings)
	openings = openings or {}
	table.sort(openings, function(a, b)
		return a[1] < b[1]
	end)
	local x = -length / 2
	for _, o in openings do
		local left = o[1] - o[2] / 2
		if left > x then
			boxCF(parent, left - x, height, thick, cf * CFrame.new((x + left) / 2, height / 2, 0), color, mat)
		end
		boxCF(parent, o[2], height - o[3], thick, cf * CFrame.new(o[1], o[3] + (height - o[3]) / 2, 0), color, mat)
		x = o[1] + o[2] / 2
	end
	if x < length / 2 then
		boxCF(parent, length / 2 - x, height, thick, cf * CFrame.new((x + length / 2) / 2, height / 2, 0), color, mat)
	end
end

-- wall along local X with arbitrary rectangular holes { center offset, width, bottom, top } (doors: bottom 0)
local function wallHoles(parent, cf, length, height, thick, color, mat, holes)
	table.sort(holes, function(a, b)
		return a[1] < b[1]
	end)
	-- openings that share a stretch of the wall (slit windows over one another on each floor of a stair tower, a door
	-- against a gate): the wall is cut into stretches at every opening's edge, each built round the openings over it.
	-- Before 2026-11-02 the builders dropped the second of two such openings and left the wall solid there.
	local shared = false
	for i = 2, #holes do
		if holes[i][1] - holes[i][2] / 2 < holes[i - 1][1] + holes[i - 1][2] / 2 - 1e-6 then
			shared = true
			break
		end
	end
	if shared then
		local cuts = { -length / 2, length / 2 }
		for _, o in holes do
			table.insert(cuts, math.clamp(o[1] - o[2] / 2, -length / 2, length / 2))
			table.insert(cuts, math.clamp(o[1] + o[2] / 2, -length / 2, length / 2))
		end
		table.sort(cuts)
		for i = 1, #cuts - 1 do
			local a, b = cuts[i], cuts[i + 1]
			if b - a > 1e-3 then
				local mid = (a + b) / 2
				local gaps = {}
				for _, o in holes do
					if math.abs(mid - o[1]) < o[2] / 2 then
						table.insert(gaps, { math.max(0, o[3]), math.min(height, o[4]) })
					end
				end
				table.sort(gaps, function(p, q)
					return p[1] < q[1]
				end)
				local y = 0
				for _, g in gaps do
					if g[1] > y + 1e-3 then
						boxCF(parent, b - a, g[1] - y, thick, cf * CFrame.new(mid, (y + g[1]) / 2, 0), color, mat)
					end
					y = math.max(y, g[2])
				end
				if y < height - 1e-3 then
					boxCF(parent, b - a, height - y, thick, cf * CFrame.new(mid, (y + height) / 2, 0), color, mat)
				end
			end
		end
		return
	end
	local x = -length / 2
	for _, o in holes do
		local left, right = o[1] - o[2] / 2, o[1] + o[2] / 2
		if left > x then
			boxCF(parent, left - x, height, thick, cf * CFrame.new((x + left) / 2, height / 2, 0), color, mat)
		end
		if o[3] > 0 then
			boxCF(parent, o[2], o[3], thick, cf * CFrame.new(o[1], o[3] / 2, 0), color, mat)
		end
		if o[4] < height then
			boxCF(parent, o[2], height - o[4], thick, cf * CFrame.new(o[1], o[4] + (height - o[4]) / 2, 0), color, mat)
		end
		x = right
	end
	if x < length / 2 then
		boxCF(parent, length / 2 - x, height, thick, cf * CFrame.new((x + length / 2) / 2, height / 2, 0), color, mat)
	end
end

-- loose loot spots (M10): items lying on surfaces, rolled per raid by Loot (tbl = pool, chance per raid)
World.looseSpots = {}
local function loose(x, y, z, tbl, chance, area, snap)
	table.insert(World.looseSpots, { pos = Vector3.new(x, y, z), tbl = tbl, chance = chance or 0.5, area = area, snap = snap })
end

-- M13: loose spots marked `snap` drop onto the surface below them once the world is in the workspace (a counter,
-- a shelf, a floor), so a map can give approximate heights
local function snapLooseSpots()
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { root.Triggers }
	rp.IgnoreWater = true
	local moved = 0
	for _, m in World.maps do
		for _, sp in m.looseSpots do
			if sp.snap then
				local hit = workspace:Raycast(sp.pos + Vector3.new(0, 2.5, 0), Vector3.new(0, -7, 0), rp)
				if hit and hit.Instance.CanCollide then
					sp.pos = hit.Position + Vector3.new(0, 0.05, 0)
					moved += 1
				end
			end
		end
	end
	-- every spot must rest on something. One that floats (its shelf or mezzanine was not built, a slope moved the
	-- floor) drops onto the solid surface just below it, or is removed when there is none (MapTests M04). In
	-- place, so the active map's list stays the same table.
	local dropped = 0
	for _, m in World.maps do
		local list = m.looseSpots
		for i = #list, 1, -1 do
			local sp = list[i]
			if not workspace:Raycast(sp.pos + Vector3.new(0, 0.3, 0), Vector3.new(0, -0.8, 0), rp) then
				local hit = workspace:Raycast(sp.pos + Vector3.new(0, 0.3, 0), Vector3.new(0, -4.5, 0), rp)
				if hit and hit.Instance.CanCollide then
					sp.pos = hit.Position + Vector3.new(0, 0.05, 0)
					moved += 1
				else
					table.remove(list, i)
					dropped += 1
				end
			end
		end
	end
	if dropped > 0 then
		print(string.format("[ZR] loose loot: %d floating spots removed", dropped))
	end
	return moved
end

-- ── props (mesh first, part fallback) ─────────────────────────────────────────
local Props = {}
function Props.container(parent, cf, color, open)
	if mesh(open and "ZR_ENV_Container20_Open" or "ZR_ENV_Container20", parent, cf, color) then
		return
	end
	local m = model("Container", parent)
	local body = boxCF(m, 22, 9.4, 8.8, cf * CFrame.new(0, 4.7, 0), color, M.CorrodedMetal)
	for i = -3, 3 do
		boxCF(m, 0.5, 8.6, 9.2, cf * CFrame.new(i * 3, 4.7, 0), jitter(color, 0.08), M.Metal)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			boxCF(m, 0.9, 9.6, 0.9, cf * CFrame.new(sx * 10.7, 4.8, sz * 4.2), C.metalDark, M.Metal)
		end
	end
	boxCF(m, 0.4, 8, 8, cf * CFrame.new(11.1, 4.6, 0), jitter(color, 0.12), M.Metal)
	for _, z in { -2.2, 2.2 } do
		boxCF(m, 0.3, 7.6, 0.25, cf * CFrame.new(11.35, 4.6, z), C.metalDark, M.Metal)
	end
	body.Name = "Body"
end
function Props.crate(parent, cf)
	if mesh("ZR_PROP_Crate", parent, cf) then
		return
	end
	boxCF(parent, 4, 4, 4, cf * CFrame.new(0, 2, 0), C.wood, M.WoodPlanks)
end
function Props.barrel(parent, cf, color)
	if mesh("ZR_PROP_Barrel", parent, cf, color) then
		return
	end
	vcyl(parent, 4.4, 3.2, cf.X, cf.Y, cf.Z, color or C.blue, M.Metal)
	vcyl(parent, 0.2, 3.35, cf.X, cf.Y + 1.4, cf.Z, C.metalDark, M.Metal)
	vcyl(parent, 0.2, 3.35, cf.X, cf.Y + 3, cf.Z, C.metalDark, M.Metal)
end
function Props.pallet(parent, cf)
	if mesh("ZR_PROP_Pallet", parent, cf) then
		return
	end
	boxCF(parent, 5, 0.6, 4.2, cf * CFrame.new(0, 0.3, 0), C.wood, M.WoodPlanks)
end
function Props.barrier(parent, cf)
	if mesh("ZR_PROP_Barrier", parent, cf, C.concreteLight) then -- tinted: the bare mesh reads chalk-white in daylight
		return
	end
	boxCF(parent, 8, 1.4, 2.4, cf * CFrame.new(0, 0.7, 0), C.concreteLight, M.Concrete)
	boxCF(parent, 8, 2, 1.2, cf * CFrame.new(0, 2.4, 0), C.concreteLight, M.Concrete)
end
function Props.lamp(parent, cf, state)
	if not mesh("ZR_PROP_LightPole", parent, cf) then
		vcyl(parent, 18, 0.6, cf.X, cf.Y, cf.Z, C.metalDark, M.Metal)
		boxCF(parent, 3, 0.4, 0.8, cf * CFrame.new(1.2, 18, 0), C.metalDark, M.Metal)
	end
	local head = boxCF(parent, 1.2, 0.3, 0.8, cf * CFrame.new(2.4, 17.7, 0), hex("FFD9A0"), M.Neon)
	head.CastShadow = false
	light(head, hex("FFC98A"), 34, 1.4, false)
	if state then
		head:SetAttribute("Lamp", state) -- M12: "flicker" or "dead" (client Atmos)
	end
	CollectionService:AddTag(head, "ZR_Lamp") -- clients switch street lamps on in the dark (Atmos)
end
-- M12 cover props from the wear kit (build_wear_kit.py -> ZR_WearKit): gameplay geometry, they collide and stop
-- bullets. Each has a plain block stand-in of the same footprint in case the batch is missing.
local COVER_FALLBACK = {
	CarWreck = { Vector3.new(6.1, 4.3, 16.2), C.rustDark, M.CorrodedMetal },
	Dumpster = { Vector3.new(6.1, 5.2, 5), C.olive, M.Metal },
	TyreStack = { Vector3.new(4.5, 3.1, 2.9), C.metalDark, M.Rubber },
	CinderStack = { Vector3.new(5.9, 2.8, 4.2), C.concreteLight, M.Concrete },
	DrumDented = { Vector3.new(3.4, 4.5, 3.3), C.blue, M.Metal },
	CableReel = { Vector3.new(2.7, 4, 4), C.wood, M.WoodPlanks },
	BarrierBroken = { Vector3.new(7.7, 2.9, 2.5), C.concreteLight, M.Concrete },
	Sandbags = { Vector3.new(5.7, 2.2, 1.2), C.sand, M.Fabric },
	PalletStack = { Vector3.new(5.4, 2.6, 4.7), C.wood, M.WoodPlanks },
}
-- default tints for meshes whose baked colours are near white (the tint multiplies them)
local COVER_TINT = { BarrierBroken = C.concreteLight, Sandbags = hex("A39A80"), CinderStack = C.concreteLight, DrumDented = C.blue }
function Props.cover(parent, kind, cf, color)
	color = color or COVER_TINT[kind]
	local m = mesh("ZR_PROP_" .. kind, parent, cf, color)
	if not m then
		local f = COVER_FALLBACK[kind]
		m = boxCF(parent, f[1].X, f[1].Y, f[1].Z, cf * CFrame.new(0, f[1].Y / 2, 0), color or f[2], f[3])
	end
	m.Name = "Cover_" .. kind
	return m
end
function Props.bollard(parent, cf)
	vcyl(parent, 1.6, 1.4, cf.X, cf.Y, cf.Z, C.metalDark, M.Metal)
	vcyl(parent, 0.4, 2, cf.X, cf.Y + 1.6, cf.Z, C.metalDark, M.Metal)
end

-- ── lighting / atmosphere ─────────────────────────────────────────────────────
local function setupLighting()
	Lighting.ClockTime = 7.3
	Lighting.GeographicLatitude = 52
	Lighting.Brightness = 1.7
	Lighting.Ambient = hex("3A3F40")
	Lighting.OutdoorAmbient = hex("7A8382")
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.45
	Lighting.ExposureCompensation = 0.1
	Lighting:SetAttribute("BaseExposure", 0.1) -- clients run auto-exposure around this
	for _, c in Lighting:GetChildren() do
		if c:IsA("Atmosphere") or c:IsA("PostEffect") or c:IsA("Sky") or c:IsA("Clouds") then
			c:Destroy()
		end
	end
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.46
	atm.Offset = 0.18
	atm.Color = hex("A9B4B1")
	atm.Decay = hex("5D6A69")
	atm.Glare = 0
	atm.Haze = 2.4
	atm.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ZR_Grade"
	cc.Saturation = -0.22
	cc.Contrast = 0.08
	cc.Brightness = 0.01
	cc.TintColor = hex("ECEFE8")
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.25
	bloom.Size = 18
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local terrain = workspace.Terrain
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.86
	clouds.Density = 0.62
	clouds.Color = hex("C7CDCB")
	clouds.Parent = terrain
	terrain.WaterColor = hex("2C4245")
	terrain.WaterTransparency = 0.12
	terrain.WaterReflectance = 0.45
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6
	terrain:FillBlock(CFrame.new(0, -24, 0), Vector3.new(1600, 36, 1600), M.Water)
end

-- ── safehouse: Relay 7, the bunker lobby (Maps/Relay7.luau) ───────────────────────────
local function buildSafehouse()
	local Relay7 = require(script.Parent.Parent.Maps.Relay7)
	World.safehouse = Relay7.build(root, Config.SAFEHOUSE_ORIGIN)
	World.Relay7 = Relay7
	local sh = World.safehouse
	local shellModel = sh and (sh.model or sh.shell)
	if typeof(shellModel) == "Instance" then
		print(string.format("[ZR] relay7: %d coplanar faces pulled back (z-fighting)", World.fixCoplanar(shellModel)))
	end
end

-- is a world position inside the safehouse bunker?
function World.inSafehouse(pos: Vector3): boolean
	local R = World.Relay7
	return R ~= nil and R.inside(World.safehouse, pos)
end

-- ── Quay 7 ────────────────────────────────────────────────────────────────────
local function addContainerSpot(parent0, id, kind, label, cf, anchorPart)
	local anchor
	local parent = parent0
	if not anchorPart then
		-- its own box and fittings (drawer fronts, a dial, a tag) go in one model, so the placement tidy pass
		-- (Maps/Tidy.luau) can move the container out of a wall as one piece
		parent = Instance.new("Model")
		parent.Name = "Box_" .. id
		parent:SetAttribute("LootBox", kind)
		parent.Parent = parent0
	end
	if anchorPart then
		-- M13: an existing prop part is the container (a checkout's till, a fridge, a stock-room shelf)
		anchor = anchorPart
	elseif kind == "locker" then
		anchor = boxCF(parent, 3, 7, 2.2, cf * CFrame.new(0, 3.5, 0), C.olive, M.Metal)
		boxCF(parent, 0.15, 0.8, 0.1, cf * CFrame.new(0.9, 3.8, -1.12), C.metalDark, M.Metal)
	elseif kind == "drawer" then
		anchor = boxCF(parent, 5, 3, 2.6, cf * CFrame.new(0, 1.5, 0), C.metal, M.Metal)
		for k = 0, 2 do
			boxCF(parent, 4.4, 0.7, 0.1, cf * CFrame.new(0, 0.6 + k * 0.9, -1.33), C.metalDark, M.Metal)
		end
	elseif kind == "safe" then
		-- squat steel safe with a dial and handle (front faces local -Z)
		anchor = boxCF(parent, 3, 3.2, 2.6, cf * CFrame.new(0, 1.6, 0), hex("3B3F3D"), M.DiamondPlate)
		boxCF(parent, 2.5, 2.7, 0.08, cf * CFrame.new(0, 1.65, -1.32), hex("2F3331"), M.Metal)
		cyl(parent, 0.12, 0.7, cf * CFrame.new(-0.5, 2.1, -1.4) * CFrame.Angles(0, math.rad(90), 0), hex("A9A48F"), M.Metal)
		boxCF(parent, 0.18, 0.9, 0.18, cf * CFrame.new(0.7, 1.6, -1.42), hex("A9A48F"), M.Metal)
	else
		local m = mesh("ZR_PROP_Crate", parent, cf)
		anchor = m or boxCF(parent, 4, 4, 4, cf * CFrame.new(0, 2, 0), C.wood, M.WoodPlanks)
		boxCF(parent, 2.2, 0.15, 1.2, cf * CFrame.new(0, 4.08, 0), C.orange, M.SmoothPlastic)
	end
	anchor.Name = "Loot_" .. id
	anchor:SetAttribute("NoDetail", true) -- furniture, not a wall: no grime or wall fittings from the detail plan
	local pp = Instance.new("ProximityPrompt")
	pp.KeyboardKeyCode = Enum.KeyCode.F -- Tarkov interact key (Q/E lean)
	pp.ActionText = "Search"
	pp.ObjectText = label
	pp.HoldDuration = 0
	pp.MaxActivationDistance = Config.INTERACT_RANGE - 1
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.Parent = anchor
	CollectionService:AddTag(anchor, "ZR_Container")
	table.insert(World.containers, { id = id, kind = kind, label = label, part = anchor, prompt = pp, map = currentMap })
end

local function addExtract(parent, id, name, pos, size, rule, opts)
	local m = model("Exfil_" .. id, parent)
	-- beacon: pole + radio box + light + sign (compact under a low ceiling, e.g. a tunnel)
	local y0 = pos.Y
	local poleH = (opts and opts.compact) and 6.4 or 9
	local px, pz = pos.X + size.X / 2 - 1.5, pos.Z - size.Z / 2 + 1.5
	vcyl(m, poleH, 0.5, px, y0, pz, C.metalDark, M.Metal)
	local radio = box(m, 1.6, 1.2, 1, px, y0 + poleH - 2.6, pz, C.olive, M.Metal)
	local lamp = box(m, 0.7, 0.7, 0.7, px, y0 + poleH + 0.3, pz, C.orange, M.Neon)
	lamp.CastShadow = false
	lamp.Name = "BeaconLamp"
	light(lamp, C.orange, 18, 1.2, false)
	local plate = box(m, 5, 1.4, 0.2, px, y0 + poleH - 4.6, pz - 0.4, C.metalDark, M.Metal)
	sign(plate, Enum.NormalId.Front, "EXFIL " .. id .. " — " .. name, C.orange)
	sign(plate, Enum.NormalId.Back, "EXFIL " .. id .. " — " .. name, C.orange)
	radio.Name = "Radio"
	local zone = box(root.Triggers, size.X, size.Y, size.Z, pos.X, y0 + size.Y / 2, pos.Z, C.orange, M.ForceField)
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.Name = "ExfilZone_" .. id
	-- painted ground marking (thin, no collision)
	local mark = box(m, size.X, 0.06, size.Z, pos.X, y0 + 0.04, pos.Z, C.orange, M.SmoothPlastic)
	mark.Transparency = 0.82
	mark.CanCollide = false
	mark.CanQuery = false
	World.extracts[id] = { id = id, name = name, cf = zone.CFrame, size = size, pos = pos, beacon = lamp, rule = rule or { kind = "open" }, map = currentMap }
end

local function buildGround(map)
	-- quay slabs 50x50 (top at y = 0)
	for i = -4, 3 do
		for j = -4, 3 do
			box(map, 50, 8, 50, i * 50 + 25, -4, j * 50 + 25, jitter(C.concrete, 0.05), M.Concrete)
		end
	end
	-- roads
	box(map, 384, 0.12, 22, -8, 0.06, 0, C.asphalt, M.Asphalt)
	box(map, 22, 0.12, 400, 20, 0.07, 0, C.asphalt, M.Asphalt)
	for x = -190, 170, 16 do
		if math.abs(x - 20) > 14 then
			box(map, 7, 0.14, 0.5, x, 0.08, 0, C.line, M.SmoothPlastic)
		end
	end
	-- quay edge (east + south) with curb, bollards and fenders
	box(map, 2, 1.2, 341, 199, 0.6, -29.5, C.concreteLight, M.Concrete)
	box(map, 2, 1.2, 41, 199, 0.6, 179.5, C.concreteLight, M.Concrete)
	box(map, 400, 1.2, 2, 0, 0.6, 199, C.concreteLight, M.Concrete)
	for k = -180, 180, 30 do
		if math.abs(k - 150) > 14 then
			Props.bollard(map, CFrame.new(196, 0, k))
			cyl(map, 2.4, 2.6, CFrame.new(200.6, -2, k + 12) * CFrame.Angles(0, 0, math.rad(90)), C.metalDark, M.Rubber)
		end
		Props.bollard(map, CFrame.new(k, 0, 196))
	end
	-- exclusion wall (north + west) with cap and wire posts
	for _, w in { { CFrame.new(0, 0, -201), 404, { { -180, 14, 12 }, { 184, 12, 11 } } }, { CFrame.new(-201, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 404, { { -10, 14, 12 } } } } do
		wall(map, w[1], w[2], 14, 2, C.concreteDark, M.Concrete, w[3])
		boxCF(map, w[2], 0.8, 2.6, w[1] * CFrame.new(0, 14.4, 0), C.concreteLight, M.Concrete)
		for k = -w[2] / 2 + 6, w[2] / 2 - 6, 12 do
			boxCF(map, 0.25, 3, 0.25, w[1] * CFrame.new(k, 16.3, 0), C.metalDark, M.Metal)
		end
	end
	-- distant skyline silhouettes (fog-soft, no collision)
	for k = 1, 10 do
		local sx, sz = rng:NextNumber(30, 70), rng:NextNumber(30, 70)
		local h = rng:NextNumber(20, 60)
		local onNorth = k <= 5
		local x = onNorth and rng:NextNumber(-260, 260) or rng:NextNumber(-420, -280)
		local z = onNorth and rng:NextNumber(-420, -280) or rng:NextNumber(-260, 260)
		local s = box(map, sx, h, sz, x, h / 2, z, jitter(C.concreteDark, 0.1), M.Concrete)
		s.CanCollide = false
		s.CastShadow = false
	end
	box(map, 760, 2, 280, 40, -1, -344, C.concreteDark, M.Concrete).CanCollide = false
	box(map, 280, 2, 480, -344, -1, -40, C.concreteDark, M.Concrete).CanCollide = false
	-- invisible play boundary
	for _, b in { { 24, -206, 470, 4 }, { 24, 212, 470, 4 }, { -206, 3, 4, 430 }, { 254, 3, 4, 430 } } do
		local inv = box(map, b[3], 120, b[4], b[1], 50, b[2], C.pale, M.SmoothPlastic)
		inv.Transparency = 1
		inv.CanQuery = false
		inv.Name = "Boundary"
	end
end

local function buildHarborStack(map)
	local hs = model("HarborStack", map)
	local colors = { C.rust, C.blue, C.olive, C.teal, C.red, C.metal, C.orange }
	local blocks = { -158, -126, -94, -62 }
	for _, bz in blocks do
		for sub = 0, 1 do
			local z = bz + sub * 9.2
			for _, x in { -160, -137, -114, -78, -55 } do
				if rng:NextNumber() > 0.12 then
					local col = jitter(colors[rng:NextInteger(1, #colors)], 0.06)
					Props.container(hs, CFrame.new(x, 0, z) * CFrame.Angles(0, (rng:NextNumber() > 0.5) and math.pi or 0, 0), col)
					if rng:NextNumber() > 0.55 then
						local col2 = jitter(colors[rng:NextInteger(1, #colors)], 0.06)
						Props.container(hs, CFrame.new(x + rng:NextNumber(-0.6, 0.6), 9.4, z), col2)
					end
				end
			end
		end
	end
	-- yellow gantry crane landmark straddling the cross alley
	local g = model("Gantry", hs)
	for _, lx in { -101, -91 } do
		for _, lz in { -137, -73 } do
			box(g, 2, 42, 2, lx, 21, lz, C.yellow, M.Metal)
		end
		box(g, 2.4, 3, 68, lx, 43.5, -105, C.yellow, M.Metal)
	end
	box(g, 12.4, 3, 3, -96, 43.5, -137, C.yellow, M.Metal)
	box(g, 12.4, 3, 3, -96, 43.5, -73, C.yellow, M.Metal)
	box(g, 7, 6, 6, -96, 39, -100, hex("B98C34"), M.Metal)
	cyl(g, 22, 0.3, CFrame.new(-96, 27, -105) * CFrame.Angles(0, 0, math.rad(90)), C.metalDark, M.Metal)
	box(g, 5, 1.2, 9, -96, 16, -105, C.metalDark, M.Metal)
	-- pallets/barrels in alleys for cover
	for _, p in { { -125, -140 }, { -66, -140 }, { -146, -108 }, { -102, -76 }, { -40, -108 } } do
		Props.pallet(hs, CFrame.new(p[1], 0, p[2]) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
		Props.barrel(hs, CFrame.new(p[1] + 3, 0, p[2] + 2), jitter(C.blue, 0.1))
	end
	addContainerSpot(hs, "HS1", "crate", "Supply crate", CFrame.new(-96, 0, -110) * CFrame.Angles(0, 0.3, 0))
	for _, p in { { -125, -140 }, { -66, -140 }, { -146, -108 }, { -102, -76 }, { -40, -108 } } do
		loose(p[1], 0.65, p[2], "junk", 0.35, "stack")
	end
	loose(-38, 0.05, -138, "keys", 0.2, "stack")
	addContainerSpot(hs, "HS2", "locker", "Dock worker locker", CFrame.new(-36, 0, -142) * CFrame.Angles(0, math.rad(-90), 0))
	World.patrols.HS = { Vector3.new(-96, 0, -140), Vector3.new(-40, 0, -140), Vector3.new(-40, 0, -76), Vector3.new(-96, 0, -76), Vector3.new(-150, 0, -108), Vector3.new(-96, 0, -108) }
end

local function buildPumpAnnex(map)
	local pa = model("PumpAnnex", map)
	local x0, x1, z0, z1, H = 40, 120, 55, 115, 22
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	box(pa, x1 - x0, 0.4, z1 - z0, cx, 0.2, cz, C.floor, M.Concrete)
	wall(pa, CFrame.new(cx, 0, z0), x1 - x0, H, 1.5, C.wall, M.Concrete, { { 70 - cx, 10, 11 } })
	wall(pa, CFrame.new(cx, 0, z1), x1 - x0, H, 1.5, C.wall, M.Concrete, {})
	wall(pa, CFrame.new(x0, 0, cz) * CFrame.Angles(0, math.rad(90), 0), z1 - z0, H, 1.5, C.wall, M.Concrete, { { -(85 - cz), 9, 10 } })
	wall(pa, CFrame.new(x1, 0, cz) * CFrame.Angles(0, math.rad(90), 0), z1 - z0, H, 1.5, C.wall, M.Concrete, { { -(100 - cz), 9, 10 } })
	-- roof with skylight gap
	box(pa, x1 - x0 + 2, 1, 26, cx, H + 0.5, z0 + 13, C.concreteDark, M.Concrete)
	box(pa, x1 - x0 + 2, 1, 26, cx, H + 0.5, z1 - 13, C.concreteDark, M.Concrete)
	for k = x0 + 6, x1 - 6, 12 do
		box(pa, 0.8, 0.8, 9, k, H + 0.4, cz, C.metalDark, M.Metal)
	end
	-- pumps (turbine room)
	for i, px in { 58, 80, 102 } do
		box(pa, 9, 2.4, 9, px, 1.2, 76, C.concreteLight, M.Concrete)
		local col = (i == 2) and C.teal or C.olive
		cyl(pa, 12, 7, CFrame.new(px, 6, 76) * CFrame.Angles(0, math.rad(90), 0), col, M.Metal)
		vcyl(pa, 10, 2, px, 6, 70, C.metal, M.Metal)
		cyl(pa, 18, 1.6, CFrame.new(px, 16, 70 - 2) * CFrame.Angles(0, math.rad(90), 0), C.rust, M.Metal)
	end
	cyl(pa, 78, 1.6, CFrame.new(cx, 17.5, 61), C.rust, M.Metal)
	-- the turbine hall's lamps (hung from the roof trusses) and the workshop's under the mezzanine
	for i, lp in { { 58, 64, H - 3 }, { 80, 64, H - 3 }, { 102, 64, H - 3 }, { 58, 94, H - 3 }, { 80, 94, H - 3 }, { 102, 94, H - 3 }, { 62, 106, 9 }, { 90, 106, 9 } } do
		local head = box(pa, 2.4, 0.4, 1.2, lp[1], lp[3], lp[2], hex("FFE6C0"), M.Neon)
		head.CastShadow = false
		head.Name = "HallLamp"
		if lp[3] > 10 then
			box(pa, 0.12, 2.6, 0.12, lp[1], lp[3] + 1.5, lp[2], C.metalDark, M.Metal)
		end
		if i == 5 then
			head.Color, head.Material = hex("6F6C64"), M.SmoothPlastic -- a dead tube
		else
			light(head, Color3.fromRGB(255, 226, 184), lp[3] > 10 and 36 or 18, 1.5, i == 2)
		end
	end
	-- mezzanine along south wall with stairs on the west side
	local mzY = 10
	box(pa, 78, 0.8, 14.5, 80, mzY - 0.4, 106.75, C.metal, M.DiamondPlate) -- x 41..119, z 99.5..114
	box(pa, 68, 3, 0.3, 85, mzY + 1.5, 99.6, C.metalDark, M.Metal) -- rail leaves the stair landing open
	-- open steel stairs, real-size steps (20 x 0.48 studs up to the mezzanine deck at 10)
	for i = 1, 20 do
		box(pa, 6, 0.5, 0.95, 46, 0.4 + i * 0.48 - 0.25, 80.525 + (i - 1) * 0.95, C.metal, M.DiamondPlate)
	end
	box(pa, 6, mzY - 0.8, 1, 46, (mzY - 0.8) / 2, 100.2, C.metalDark, M.Metal)
	local booth = box(pa, 10, 7, 8, 104, mzY + 3.5, 109, C.olive, M.Metal)
	booth.Name = "ControlBooth"
	local ctrlLamp = box(pa, 0.6, 0.6, 0.6, 104, mzY + 5, 104.6, C.orange, M.Neon)
	light(ctrlLamp, C.orange, 22, 1.6, true)
	addContainerSpot(pa, "PA1", "locker", "Maintenance locker", CFrame.new(64, mzY, 111) * CFrame.Angles(0, math.rad(180), 0))
	addContainerSpot(pa, "PA2", "crate", "Valve parts crate", CFrame.new(100, 0.4, 92))
	loose(94, mzY + 0.05, 106, "junk", 0.45, "annex")
	loose(112, mzY + 0.05, 104, "keys", 0.25, "annex")
	loose(62, 2.45, 72.2, "junk", 0.3, "annex")
	loose(84, 2.45, 79.8, "junk", 0.3, "annex")
	-- chimney landmark (striped)
	for k = 0, 9 do
		vcyl(pa, 6, 8, 116, k * 6, 50, (k % 2 == 0) and C.pale or C.rust, M.Concrete)
	end
	for _, p in { { 34, 70 }, { 34, 74 }, { 126, 66 } } do
		Props.barrel(pa, CFrame.new(p[1], 0, p[2]), jitter(C.rust, 0.1))
	end
	Props.barrier(pa, CFrame.new(30, 0, 92) * CFrame.Angles(0, math.rad(90), 0))
	World.patrols.PA = { Vector3.new(30, 0, 85), Vector3.new(60, 0.4, 88), Vector3.new(96, 0.4, 92), Vector3.new(126, 0, 100), Vector3.new(126, 0, 48), Vector3.new(70, 0, 48) }
end

local function buildFreightDepot(map)
	local fd = model("FreightDepot", map)
	local x0, x1, z0, z1, H, F = 50, 150, -160, -100, 24, 4
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	box(fd, x1 - x0, F, (z1 - z0) + 12, cx, F / 2, (z0 + z1 + 12) / 2, C.concreteDark, M.Concrete)
	box(fd, x1 - x0, 0.6, 1, cx, F + 0.3, z1 + 11.5, C.yellow, M.SmoothPlastic)
	local wallC = hex("6F7468")
	wall(fd, CFrame.new(cx, F, z1), x1 - x0, H, 1, wallC, M.CorrodedMetal, { { 70 - cx, 12, 14 }, { 100 - cx, 12, 14 }, { 130 - cx, 12, 14 } })
	wall(fd, CFrame.new(cx, F, z0), x1 - x0, H, 1, wallC, M.CorrodedMetal, { { 134 - cx, 4.4, 8 } }) -- vault door (office)
	wall(fd, CFrame.new(x0, F, cz) * CFrame.Angles(0, math.rad(90), 0), z1 - z0, H, 1, wallC, M.CorrodedMetal, { { -(-130 - cz), 8, 10 } })
	wall(fd, CFrame.new(x1, F, cz) * CFrame.Angles(0, math.rad(90), 0), z1 - z0, H, 1, wallC, M.CorrodedMetal, {})
	-- pitched roof
	for _, s in { -1, 1 } do
		local roofPart = boxCF(fd, x1 - x0 + 2, 1, 33, CFrame.new(cx, F + H + 3, cz + s * 15) * CFrame.Angles(math.rad(s * 11), 0, 0), C.metal, M.CorrodedMetal)
		roofPart.Name = "Roof"
	end
	-- roll-up doors (half open) and dock bumpers
	for _, dx in { 70, 100, 130 } do
		box(fd, 12, 5, 0.4, dx, F + 11.5, z1 + 0.2, C.metalDark, M.CorrodedMetal)
		box(fd, 1, 1.4, 0.8, dx - 5, 3, z1 + 12.2, C.metalDark, M.Rubber)
		box(fd, 1, 1.4, 0.8, dx + 5, 3, z1 + 12.2, C.metalDark, M.Rubber)
	end
	-- ramps (west end of dock, west door)
	local function ramp(x, z, length, width, ry)
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.Size = Vector3.new(width, F, length)
		w.CFrame = CFrame.new(x, F / 2, z) * CFrame.Angles(0, math.rad(ry), 0)
		w.Color = C.concreteLight
		w.Material = M.Concrete
		w.Parent = fd
	end
	ramp(x0 - 6, -94, 12, 12, 90)
	ramp(x0 - 6, -130, 12, 8, 90)
	ramp(x1 + 6, -94, 12, 12, -90)
	-- interior racks (Blender kit pallet racks, two rows facing the aisle between them) and the hall's lamps
	do
		local Kit = require(script.Parent.Parent:WaitForChild("Maps"):WaitForChild("Kit"))
		for _, row in { { -150, 180 }, { -138, 0 } } do
			for _, rx in { 59.5, 76, 92.5, 109 } do
				Kit.place(fd, "PalletRack", CFrame.new(rx, F, row[1]) * CFrame.Angles(0, math.rad(row[2]), 0), { shadows = false })
			end
		end
		for i, lp in { { 66, -128 }, { 92, -128 }, { 118, -128 }, { 66, -112 }, { 92, -112 }, { 118, -112 }, { 84, -144 } } do
			local head = box(fd, 2.4, 0.4, 1.2, lp[1], F + 17, lp[2], hex("FFE6C0"), M.Neon)
			head.CastShadow = false
			head.Name = "HallLamp"
			box(fd, 0.12, 2.6, 0.12, lp[1], F + 18.5, lp[2], C.metalDark, M.Metal)
			if i ~= 5 then
				light(head, Color3.fromRGB(255, 226, 184), 34, 1.5, i == 2)
			else
				head.Color, head.Material = hex("6F6C64"), M.SmoothPlastic -- a dead tube
			end
		end
	end
	-- office
	local off = model("Office", fd)
	wall(off, CFrame.new(136, F, -138), 26, 10, 0.6, C.interior, M.Plaster, { { -6, 4, 7.5 } })
	wall(off, CFrame.new(123, F, -149) * CFrame.Angles(0, math.rad(90), 0), 22, 10, 0.6, C.interior, M.Plaster, {})
	box(off, 26, 0.5, 22, 136, F + 10.25, -149, C.concreteLight, M.Plaster)
	local olamp = box(off, 3, 0.2, 1, 136, F + 9.9, -149, hex("FFE6BF"), M.Neon)
	light(olamp, hex("FFD7A6"), 16, 1, false)
	addContainerSpot(off, "FD1", "drawer", "Office cabinet", CFrame.new(142, F, -156))
	-- the office is locked (Harbor Office Key); its safe holds valuables
	addContainerSpot(off, "FD3", "safe", "Office safe", CFrame.new(128, F, -155))
	World.doors.OFFICE = { id = "OFFICE", cf = CFrame.new(130, F + 3.75, -138), size = Vector3.new(3.9, 7.4, 0.35), key = "KEY_OFFICE", label = "Depot office", parent = off }
	-- office desk (paperwork, sometimes a key)
	box(off, 5, 0.3, 2.4, 141, F + 2.6, -146, C.wood, M.WoodPlanks)
	for _, dx in { -2.2, 2.2 } do
		for _, dz in { -0.9, 0.9 } do
			box(off, 0.3, 2.45, 0.3, 141 + dx, F + 1.22, -146 + dz, C.metalDark, M.Metal)
		end
	end
	loose(140, F + 2.76, -146.3, "office", 0.6, "office")
	loose(142.2, F + 2.76, -145.8, "keys", 0.3, "office")
	-- the vault (M10): a strongroom behind the office, opened with the Vault Keycard (layered: office key, then card)
	local vault = model("Vault", fd)
	local VZ0, VZ1, VX0, VX1 = -172, -160.5, 127, 141
	local vc = hex("4E524F")
	box(vault, VX1 - VX0, F, VZ1 - VZ0, (VX0 + VX1) / 2, F / 2, (VZ0 + VZ1) / 2, C.concreteDark, M.Concrete)
	wall(vault, CFrame.new((VX0 + VX1) / 2, F, VZ0), VX1 - VX0 + 1.2, 10, 1.2, vc, M.Concrete, {})
	wall(vault, CFrame.new(VX0, F, (VZ0 + VZ1) / 2) * CFrame.Angles(0, math.rad(90), 0), VZ1 - VZ0, 10, 1.2, vc, M.Concrete, {})
	wall(vault, CFrame.new(VX1, F, (VZ0 + VZ1) / 2) * CFrame.Angles(0, math.rad(90), 0), VZ1 - VZ0, 10, 1.2, vc, M.Concrete, {})
	box(vault, VX1 - VX0 + 1.2, 0.8, VZ1 - VZ0 + 1.2, (VX0 + VX1) / 2, F + 10.4, (VZ0 + VZ1) / 2, vc, M.Concrete)
	local vlamp = box(vault, 3, 0.2, 0.6, 134, F + 9.85, -166, hex("D8E6F0"), M.Neon)
	light(vlamp, hex("CFE2F2"), 14, 0.9, false)
	addContainerSpot(vault, "VT1", "safe", "Vault safe", CFrame.new(129.6, F, -169.6) * CFrame.Angles(0, math.rad(180), 0))
	addContainerSpot(vault, "VT2", "safe", "Vault safe", CFrame.new(138.4, F, -169.6) * CFrame.Angles(0, math.rad(180), 0))
	addContainerSpot(vault, "VT3", "weaponbox", "Arms crate", CFrame.new(134, F, -170))
	-- shelf along the west wall with loose valuables
	box(vault, 1.6, 0.2, 7, 128.4, F + 3.2, -165, C.metalDark, M.Metal)
	box(vault, 1.6, 0.2, 7, 128.4, F + 5.6, -165, C.metalDark, M.Metal)
	for _, sz in { -168.3, -161.7 } do
		box(vault, 0.2, 6, 0.2, 129.1, F + 3, sz, C.metalDark, M.Metal)
	end
	loose(128.4, F + 3.32, -167, "vault", 0.85, "vault")
	loose(128.4, F + 3.32, -164, "vault", 0.6, "vault")
	loose(128.4, F + 5.72, -165.5, "vault", 0.6, "vault")
	-- card reader on the office side, its lamp turns green once the vault is open (Doors)
	local reader = box(fd, 0.5, 0.8, 0.2, 136.7, F + 4.3, -159.35, hex("2A2D2B"), M.Metal)
	reader.Name = "CardReader"
	local led = box(fd, 0.18, 0.18, 0.06, 136.7, F + 4.55, -159.23, hex("C24A35"), M.Neon)
	led.Name = "ReaderLed"
	World.doors.VAULT = { id = "VAULT", cf = CFrame.new(134, F + 3.75, -160), size = Vector3.new(4.2, 7.4, 0.5), key = "RUSTED_KEYCARD", card = true, label = "Depot vault", parent = vault, led = led, color = hex("6B706C") }
	addContainerSpot(fd, "FD2", "crate", "Freight crate", CFrame.new(84, F, -93))
	loose(70, F + 0.05, -96, "junk", 0.35, "depot")
	loose(128, F + 0.05, -97, "junk", 0.35, "depot")
	loose(96, F + 0.05, -144.5, "junk", 0.3, "depot")
	for _, p in { { 110, -92 }, { 116, -93 }, { 58, -120 } } do
		Props.pallet(fd, CFrame.new(p[1], F, p[2]))
	end
	World.patrols.FD = { Vector3.new(36, 0, -94), Vector3.new(62, F, -94), Vector3.new(138, F, -94), Vector3.new(130, F, -112), Vector3.new(90, F, -126), Vector3.new(58, F, -130), Vector3.new(36, 0, -130) }
end

-- ── crew dormitory (M10) ──────────────────────────────────────────────────────
-- Two storeys of crew rooms opening onto an exterior walkway / balcony, stairs at the east end. Rooms 104 and
-- 203 are locked (keys found in raids or sold by the Fence); every room has a bunk, a desk and a locker or
-- drawer, and loose loot. Doors start closed (some ajar) each raid.
local function buildDormitory(map)
	local dm = model("Dormitory", map)
	local X0, X1, Z0, Z1, H = -70, -26, 40, 58, 10
	local wallC, trimC = hex("7C766A"), hex("57534B")
	local cx, cz = (X0 + X1) / 2, (Z0 + Z1) / 2
	local drng = Random.new(1042)
	-- slabs
	box(dm, X1 - X0, 0.4, Z1 - Z0, cx, 0.2, cz, C.floor, M.Concrete)
	box(dm, X1 - X0, 0.6, Z1 - Z0, cx, H, cz, C.concreteDark, M.Concrete)
	box(dm, X1 - X0 + 6, 0.6, 4.5, cx + 3, H, Z1 + 2.25, C.concreteDark, M.Concrete) -- balcony + stair landing
	box(dm, X1 - X0 + 2, 0.6, Z1 - Z0 + 2, cx, 2 * H + 0.3, cz, trimC, M.Concrete) -- roof
	box(dm, X1 - X0 + 2, 1.2, 0.4, cx, 2 * H + 1, Z0 - 0.8, trimC, M.Concrete) -- roof lip
	box(dm, X1 - X0 + 2, 1.2, 0.4, cx, 2 * H + 1, Z1 + 0.8, trimC, M.Concrete)
	box(dm, X1 - X0 + 6, 0.1, 4.2, cx + 3, 0.05, Z1 + 2.1, C.concreteLight, M.Concrete) -- ground walkway
	-- balcony railing (open at the stair head, x -24..-20)
	for _, ry in { 1.6, 3.4 } do
		box(dm, X1 - X0 + 1.8, 0.2, 0.2, (X0 + X1 + 1.8) / 2, H + 0.3 + ry, Z1 + 4.35, C.metalDark, M.Metal)
	end
	for px = X0 + 1, X1 + 1, 4 do
		box(dm, 0.2, 3.4, 0.2, px, H + 0.3 + 1.7, Z1 + 4.35, C.metalDark, M.Metal)
	end
	-- stairs: east end, rising north from the ground to the balcony (real-size half-stud steps like the annex)
	for i = 1, 20 do
		box(dm, 4, 0.5, 0.95, -22, i * 0.5 - 0.25, 80.525 - (i - 1) * 0.95, C.concreteLight, M.Concrete)
	end
	for _, sx in { -24.15, -19.85 } do
		local bottom, top = Vector3.new(sx, 4, 80.5), Vector3.new(sx, H + 3.6, 62.6)
		local mid = (bottom + top) / 2
		boxCF(dm, 0.2, 0.2, (top - bottom).Magnitude, CFrame.lookAt(mid, top), C.metalDark, M.Metal)
		boxCF(dm, 0.3, 3, 0.3, CFrame.new(sx, 1.5, 80.5), C.metalDark, M.Metal)
	end
	-- outer walls per storey: windows north, doors (+ a small window) south, a window at each end
	for floor = 0, 1 do
		local yb = floor * H
		local northHoles, southHoles = {}, {}
		for i = 1, 4 do
			local rcx = X0 + (i - 0.5) * 11
			table.insert(northHoles, { rcx - cx, 4, 3.2, 6.4 })
			table.insert(southHoles, { rcx - cx, 3.8, 0, 7.6 })
			table.insert(southHoles, { rcx - 3.6 - cx, 2.2, 3.4, 6.2 })
		end
		wallHoles(dm, CFrame.new(cx, yb, Z0), X1 - X0, H, 0.6, wallC, M.Concrete, northHoles)
		wallHoles(dm, CFrame.new(cx, yb, Z1), X1 - X0, H, 0.6, wallC, M.Concrete, southHoles)
		wallHoles(dm, CFrame.new(X0, yb, cz) * CFrame.Angles(0, math.rad(90), 0), Z1 - Z0, H, 0.6, wallC, M.Concrete, { { 0, 3, 3.2, 6.4 } })
		wallHoles(dm, CFrame.new(X1, yb, cz) * CFrame.Angles(0, math.rad(90), 0), Z1 - Z0, H, 0.6, wallC, M.Concrete, { { 0, 3, 3.2, 6.4 } })
		for i = 1, 3 do
			wall(dm, CFrame.new(X0 + i * 11, yb, cz) * CFrame.Angles(0, math.rad(90), 0), Z1 - Z0 - 0.6, H, 0.4, C.interior, M.Plaster, {})
		end
		-- rooms
		for i = 1, 4 do
			local num = (floor + 1) * 100 + i
			local rx0 = X0 + (i - 1) * 11
			local rcx = rx0 + 5.5
			local fy = yb + (floor == 0 and 0.4 or 0.3)
			local locked = (num == 104) or (num == 203)
			-- bunk bed against the west side, a table along the east partition with its chair (Blender kit pieces)
			do
				local Kit = require(script.Parent.Parent:WaitForChild("Maps"):WaitForChild("Kit"))
				local messy = num % 2 == 0
				Kit.place(dm, messy and "BunkBedMessy" or "BunkBed", CFrame.new(rx0 + (messy and 2.4 or 2), fy, Z0 + 4.3) * CFrame.Angles(0, math.rad(90), 0), { shadows = false })
				Kit.place(dm, "Table", CFrame.new(rx0 + 9, fy, Z0 + 6.8) * CFrame.Angles(0, math.rad(90), 0), { shadows = false })
				Kit.place(dm, "Chair", CFrame.new(rx0 + 6.9, fy, Z0 + 6.8) * CFrame.Angles(0, math.rad(-90), 0), { shadows = false })
			end
			-- locker by the door (even rooms) or a drawer under the window (odd rooms)
			local cid = "DM" .. num
			if i % 2 == 0 then
				addContainerSpot(dm, cid, "locker", "Crew locker", CFrame.new(rx0 + 9.2, fy, Z1 - 1.5))
			else
				addContainerSpot(dm, cid, "drawer", "Bedside drawer", CFrame.new(rx0 + 6.7, fy, Z0 + 1.6) * CFrame.Angles(0, math.rad(180), 0))
			end
			-- ceiling lamp (some dead)
			local lp = box(dm, 1.6, 0.15, 0.6, rcx, yb + H - 0.4, cz, hex("FFE6BF"), M.Neon)
			lp.CastShadow = false
			if drng:NextNumber() < 0.6 then
				light(lp, hex("FFD9A8"), 14, 0.8, true)
			else
				lp.Material = M.SmoothPlastic
				lp.Color = hex("8D8A80")
			end
			-- loose loot: desk, bunk, floor (locked rooms hold better things)
			loose(rx0 + 9.6, fy + 3.15, Z0 + 6.2, locked and "dorm_good" or "dorm", locked and 0.85 or 0.55, "dorm", true)
			loose(rx0 + 2, fy + 1.65, Z0 + 2.8, locked and "dorm_good" or "dorm", locked and 0.6 or 0.3, "dorm", true)
			loose(rx0 + 5.5, fy + 0.05, Z0 + 9.5, locked and "dorm" or "junk", locked and 0.5 or 0.25, "dorm")
			if num == 101 or num == 202 then
				loose(rx0 + 9.6, fy + 3.15, Z0 + 7.6, "keys", 0.35, "dorm", true)
			end
			-- door
			World.doors["DORM" .. num] = {
				id = "DORM" .. num, cf = CFrame.new(rcx, fy + 3.57, Z1), size = Vector3.new(3.7, 7.1, 0.3),
				key = (num == 104) and "KEY_DORM_104" or ((num == 203) and "KEY_DORM_203" or nil),
				label = "Room " .. num, parent = dm, openChance = locked and 0 or 0.35, color = hex("6E5E4A"),
			}
			-- room number plate next to the door (outside)
			local plate = box(dm, 1.2, 0.6, 0.06, rcx + 2.6, fy + 5.6, Z1 + 0.33, hex("C9C2A8"), M.SmoothPlastic)
			sign(plate, Enum.NormalId.Back, tostring(num), hex("2E2E2A"))
		end
	end
	local nameplate = box(dm, 8, 1.6, 0.1, X1 + 0.36, 2 * H - 2, cz, C.metalDark, M.Metal)
	nameplate.CFrame = CFrame.new(X1 + 0.36, 2 * H - 2, cz) * CFrame.Angles(0, math.rad(90), 0)
	sign(nameplate, Enum.NormalId.Back, "CREW BLOCK B", C.pale)
	World.patrols.DM = { Vector3.new(-74, 0, 62), Vector3.new(-48, 0, 61), Vector3.new(-20, 0, 70), Vector3.new(-48, H + 0.3, 60.5), Vector3.new(-66, H + 0.3, 60.5) }
end

-- furnishing and damage pass (2026-11-01): Blender kit props in the pump annex, the freight depot and its office,
-- and the crew rooms, the way Tarkov's interiors are filled (benches, racks, cabinets, valves, debris)
local function buildQuayDressing(map)
	local Kit = require(script.Parent.Parent:WaitForChild("Maps"):WaitForChild("Kit"))
	local dr = model("Dressing", map)
	local n = 0
	local function P(name, x, y, z, ry)
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(ry or 0), 0)
		if Kit.place(dr, name, cf, { shadows = false }) then
			n += 1
		end
	end
	-- pump annex (floor 0.4, mezzanine 10): workshop under the mezzanine, forklift and pallets, valves by the pumps
	local AF, MZ = 0.4, 10
	P("StorageRack", 60, AF, 113.25, 0)
	P("StorageRack", 70, AF, 113.25, 0)
	P("ToolChest", 80, AF, 113, 0)
	P("CraftBench", 90, AF, 112.5, 0)
	P("WallShelfTools", 100, AF, 112.25, 0)
	P("FuseBox", 42.3, AF, 108, -90)
	P("Forklift", 88, AF, 92, 90)
	P("PalletBoxes", 110, AF, 92)
	P("PalletBoxes", 113.4, AF, 87.6, 20)
	P("Drum", 44, AF, 66)
	P("Drum", 45.9, AF, 64.5)
	P("JerryCans", 44.5, AF, 70.2, 80)
	for _, px in { 58, 80, 102 } do
		P("PipeValve", px + 5.5, AF, 70)
	end
	P("CableTray", 55, 8, 56.75, 180)
	P("CableTray", 95, 8, 56.75, 180)
	P("OilStain", 70, AF + 0.02, 85)
	P("OilStain", 95, AF + 0.02, 66, 40)
	P("RubbleA", 116.5, AF, 60, 20)
	P("Table", 85, MZ, 110)
	P("Chair", 83.5, MZ, 107.4, 180)
	P("Chair", 86.5, MZ, 112.7, 0)
	P("Lockers", 72, MZ, 112.6, 0)
	P("StorageShelf", 115, MZ, 113.2, 0)
	P("WallClock", 85, 15, 114.1, 0)
	-- freight depot (floor 4): the forklift aisle, pallets, the office's chair, shelf, boards and bin
	local F = 4
	P("Forklift", 85, F, -120, 90)
	P("PalletBoxes", 62, F, -112)
	P("PalletBoxes", 66.5, F, -111.4, 20)
	P("PalletBoxes", 118, F, -118)
	P("PalletBoxes", 121.2, F, -122.4, 45)
	P("Trolley", 100, F, -126, 30)
	P("TyreStack", 140, F, -104)
	P("JerryCans", 146, F, -112)
	P("OilStain", 76, F + 0.02, -124, 15)
	P("Chair", 141, F, -143.9, 0)
	P("StorageShelf", 148.5, F, -150, 90)
	P("Whiteboard", 142, F + 3.5, -138.6, 180)
	P("CorkBoard", 123.45, F + 3, -150, -90)
	P("Pigeonholes", 145, F, -158.9, 0)
	P("Bin", 125, F, -140)
	-- crew rooms (dormitory x -70..-26, z 40..58, storeys at 0.4 and 10.3): a bin by each door, boxes in the odd rooms
	for floor = 0, 1 do
		local fy = floor * 10 + (floor == 0 and 0.4 or 0.3)
		for i = 1, 4 do
			local rx0 = -70 + (i - 1) * 11
			P("Bin", rx0 + 1.3, fy, 56.7)
			if i % 2 == 1 then
				P("CardboardPile", rx0 + 2.7, fy, 52.5, 90)
			end
		end
	end
	print(string.format("[ZR] Quay 7 dressing: %d kit props", n))
end

local function buildLandmarksAndRoutes(map)
	local misc = model("Quay", map)
	-- striped water tower (SW)
	local wt = model("WaterTower", misc)
	for _, sx in { -6, 6 } do
		for _, sz in { -6, 6 } do
			box(wt, 1.2, 32, 1.2, -130 + sx, 16, 120 + sz, C.metalDark, M.Metal)
		end
	end
	for k = 0, 3 do
		vcyl(wt, 3.5, 18, -130, 32 + k * 3.5, 120, (k % 2 == 0) and C.orange or C.pale, M.Metal)
	end
	vcyl(wt, 1, 19, -130, 46, 120, C.metalDark, M.Metal)
	-- west spawn: ferry service tunnel mouth in the west wall
	local tun = model("FerryTunnel", misc)
	box(tun, 14, 2, 20, -207, 13, 10, C.concreteDark, M.Concrete)
	box(tun, 14, 8, 22, -207, -4, 10, C.concreteDark, M.Concrete)
	box(tun, 14, 14, 2, -207, 7, -1, C.concreteDark, M.Concrete)
	box(tun, 14, 14, 2, -207, 7, 21, C.concreteDark, M.Concrete)
	box(tun, 6, 14, 22, -213, 7, 10, C.concreteDark, M.Concrete)
	local tl = box(tun, 0.4, 0.4, 3, -201, 11.6, 10, hex("FFD9A0"), M.Neon)
	light(tl, hex("FFC98A"), 18, 0.9, false)
	-- south spawn shelter
	local sh = model("Shelter", misc)
	box(sh, 12, 0.6, 6, -50, 8.3, 192, C.metal, M.CorrodedMetal)
	for _, sx in { -5.5, 5.5 } do
		box(sh, 0.5, 8, 0.5, -50 + sx, 4, 194.5, C.metalDark, M.Metal)
	end
	-- pier 3 + boat (exfil B)
	local pier = model("Pier3", misc)
	box(pier, 50, 1.2, 16, 226, -0.6, 150, C.wood, M.WoodPlanks)
	for px = 206, 246, 10 do
		for _, pz in { 143, 157 } do
			vcyl(pier, 14, 1.2, px, -14, pz, C.rustDark, M.Wood)
		end
	end
	box(pier, 18, 3, 7, 244, -1.8, 162, C.pale, M.SmoothPlastic)
	box(pier, 8, 2.4, 5, 240, 0.9, 162, C.metal, M.Metal)
	-- relay gate (exfil A) tower
	local relay = model("RelayTower", misc)
	for _, sx in { -2, 2 } do
		for _, sz in { -2, 2 } do
			box(relay, 0.5, 52, 0.5, 190 + sx, 26, -190 + sz, C.metalDark, M.Metal)
		end
	end
	for k = 1, 8 do
		box(relay, 4.5, 0.3, 4.5, 190, k * 6, -190, C.metalDark, M.Metal)
	end
	local rl = box(relay, 1, 1, 1, 190, 52.5, -190, hex("D0583F"), M.Neon)
	rl.Name = "BeaconLamp"
	-- rail cut (exfil C)
	local rail = model("RailCut", misc)
	for _, rx in { -184, -176 } do
		box(rail, 0.6, 0.5, 60, rx, 0.25, -175, C.rustDark, M.Metal)
	end
	for rz = -200, -150, 4 do
		box(rail, 10, 0.3, 1.2, -180, 0.15, rz, C.wood, M.Wood)
	end
	-- scattered cover along routes
	local cover = {
		{ "barrier", -150, 40, 0 }, { "barrier", -120, 30, 90 }, { "barrier", -60, 20, 0 }, { "barrier", -20, -30, 90 },
		{ "barrier", 60, 20, 0 }, { "barrier", 150, 10, 90 }, { "barrier", 160, -50, 0 }, { "barrier", -10, 120, 90 },
		{ "barrel", -80, 150, 0 }, { "barrel", -76, 152, 0 }, { "barrel", 170, 120, 0 }, { "barrel", 30, -60, 0 },
		{ "crate", -158, 60, 20 }, { "crate", 0, 70, 0 }, { "crate", 150, -40, 45 }, { "crate", -30, -175, 0 },
		{ "pallet", -100, 60, 0 }, { "pallet", 120, 30, 30 },
	}
	for _, c in cover do
		local cf = CFrame.new(c[2], 0, c[3]) * CFrame.Angles(0, math.rad(c[4]), 0)
		if c[1] == "barrier" then
			Props.barrier(misc, cf)
		elseif c[1] == "barrel" then
			Props.barrel(misc, cf, jitter(C.blue, 0.1))
		elseif c[1] == "crate" then
			Props.crate(misc, cf)
		else
			Props.pallet(misc, cf)
		end
	end
	-- M12 cover from the wear kit: wrecks, dumpsters, stacks and sandbags break up the open yards and the roads.
	-- Every spot is clear of spawns, exfil zones, AI posts and paths, loot spots, containers and doors.
	local DUMPSTER = { hex("3E5A45"), hex("3D5468"), hex("6B4A3A") }
	local kit = {
		-- north lot and the cross road
		{ "CarWreck", -20, -150, 20 }, { "Sandbags", 2, -168, 0 }, { "CinderStack", -36, -128, 15 }, { "CarWreck", 25, -60, 3 },
		-- behind the depot, north strip
		{ "PalletStack", 172, -140, 10 }, { "TyreStack", 182, -112, 0 }, { "CableReel", 60, -180, 90 }, { "Sandbags", 112, -178, 0 },
		-- east apron
		{ "CarWreck", 172, 72, 5 }, { "CableReel", 186, 96, 0 }, { "Sandbags", 166, 52, 90 }, { "BarrierBroken", 100, -8, 0 },
		-- south yard
		{ "CarWreck", -100, 140, 70 }, { "TyreStack", -160, 165, 25 }, { "Dumpster", -60, 118, 0 }, { "CinderStack", -15, 105, 40 },
		{ "CarWreck", 125, 158, -15 }, { "DrumDented", 40, 140, 0, C.blue }, { "DrumDented", 43.6, 141.5, 0, C.red }, { "PalletStack", 150, 135, 30 },
		-- between the dormitory and the road, around the annex
		{ "BarrierBroken", -5, 40, 90 }, { "DrumDented", 10, 95, 0, C.olive }, { "Dumpster", 128, 80, 90 }, { "PalletStack", 95, 42, 10 },
		-- west side and the main road
		{ "Dumpster", -170, -40, 90 }, { "CarWreck", -140, -22, 80 }, { "TyreStack", -165, 95, 0 }, { "CarWreck", -110, 5, 92 },
	}
	local nd = 0
	for _, c in kit do
		local col = c[5]
		if c[1] == "Dumpster" then
			nd += 1
			col = DUMPSTER[(nd - 1) % #DUMPSTER + 1]
		end
		Props.cover(misc, c[1], CFrame.new(c[2], 0, c[3]) * CFrame.Angles(0, math.rad(c[4]), 0), col)
	end
	-- loose loot in the open (rolled per raid)
	for _, lp in { { -130, 0.05, 116 }, { -50, 0.05, 190 }, { 230, 0.05, 147 }, { 240, 2.15, 162 }, { 190, 0.05, -184 }, { -178, 0.05, -168 },
		{ -204, 0.05, 6 }, { -96, 0.05, 154 }, { 4, 0.05, 72 }, { 160, 0.05, -38 }, { 96, 0.05, 174 } } do
		loose(lp[1], lp[2], lp[3], "junk", 0.3, "open")
	end
	loose(-52, 0.05, 192, "keys", 0.15, "open")
	-- a few loose containers in the south yard
	Props.container(misc, CFrame.new(-90, 0, 60) * CFrame.Angles(0, math.rad(90), 0), C.blue)
	Props.container(misc, CFrame.new(-30, 0, 150), C.rust)
	Props.container(misc, CFrame.new(90, 0, 160) * CFrame.Angles(0, math.rad(20), 0), C.olive)
	Props.container(misc, CFrame.new(150, 0, -20) * CFrame.Angles(0, math.rad(90), 0), C.teal)
	-- street lamps; at night one by the depot stutters, one on the west road flickers, the one by the relay gate is dead
	for _, lp in { { -150, 14, "flicker" }, { -60, 14 }, { 34, 30 }, { 34, -60, "flicker" }, { 120, 14 }, { 34, 150 }, { 180, -120, "dead" } } do
		Props.lamp(misc, CFrame.new(lp[1], 0, lp[2]), lp[3])
	end
end

-- ── wear (M12): worn PBR materials from MaterialService (Rojo src/materials, procedural textures) ──────────────
-- Part-built geometry gets a MaterialVariant by material and shape: cast concrete walls stained and cracked,
-- long perimeter walls as precast panels, slabs and floors scuffed, roads cracked and patched, plaster peeling,
-- painted steel chipped and rusting, corrugated sheet with rust runs, weathered planks. A part can ask for a
-- specific variant with the attribute "Wear" ("" = keep the plain material). Meshes keep their vertex colours.
local WEAR_BY_MATERIAL = {
	[M.Asphalt] = "ZR_AsphaltCracked", [M.Plaster] = "ZR_PlasterPeel", [M.Metal] = "ZR_MetalPaint",
	[M.CorrodedMetal] = "ZR_Corrugated", [M.WoodPlanks] = "ZR_WoodWeathered",
}

-- ── wall finishes (docs/look/WALLS.md) ───────────────────────────────────────────────────────────────────────
-- Seven variants make walls read as different finishes: gloss oil paint, whitewash, two wallpapers, glazed wall tiles,
-- brick and wood panelling. A variant whose ColorMap is still empty (its textures are not uploaded yet) is skipped
-- everywhere, so the map looks as it did until the ids are filled in.
-- A part gets its look from the first of these that applies:
--   1. the attribute Wear (a variant name; "" = the plain material), as always;
--   2. the attribute Finish on the part (a variant name, any shape and material; "" = no finish), or Finish on the
--      nearest Model above it, which only wall pieces take: Plaster always, Concrete and Brick only for the structural
--      finishes. The part gets the variant's base material; a Finish that is not ready leaves the shape rules in step 4;
--   3. no Finish anywhere: Plaster wall pieces take a finish from DEFAULT_PICK, chosen by a stable hash of the nearest
--      Model and the floor band (y // 11), and Brick wall pieces become ZR_BrickWall;
--   4. the shape rules (concrete slabs, panels and worn concrete, asphalt, metal, planks, plaster peel).
-- Colour: gloss, whitewash and wallpaper take a hue from WALL_HUES.paint by the same hash, at the brightness the builder
-- gave the wall (0.4 to 0.75); wood and brick take theirs from their own lists as they are. Only parts with the
-- builder's plain plaster colour are re-tinted (brick and wood: parts whose material changes), or Tint = true on the
-- part or its Model; Tint = false keeps the colour.
-- Furniture and doors (NoDetail) are never walls. Upright thin boxes are wall pieces, lintels and jambs included.
local DEFAULT_PICK = {
	{ "ZR_Whitewash", 35 }, { "ZR_WallpaperA", 15 }, { "ZR_WallpaperB", 15 }, { "ZR_PlasterPeel", 25 }, { "ZR_PaintGloss", 10 },
}
local WALL_FINISHES = { "ZR_PaintGloss", "ZR_Whitewash", "ZR_WallpaperA", "ZR_WallpaperB", "ZR_WallTiles", "ZR_BrickWall", "ZR_WoodPanel" }
local STRUCTURAL = { ZR_BrickWall = true, ZR_ConcreteWorn = true, ZR_ConcretePanel = true }
local FINISH_KIND = { -- which hue list re-tints the finish
	ZR_PaintGloss = "paint", ZR_Whitewash = "paint", ZR_WallpaperA = "paint", ZR_WallpaperB = "paint", ZR_WoodPanel = "wood", ZR_BrickWall = "brick",
}
local WALL_HUES = {
	-- pale green, pale blue, beige, cream, dusty pink, ochre, light grey
	paint = { hex("A0AE98"), hex("9BAAB3"), hex("B0A68D"), hex("BAB195"), hex("AE9490"), hex("AE9863"), hex("A8AAA3") },
	wood = { hex("B08C64"), hex("A07850"), hex("8A6444"), hex("9C8460") },
	brick = { hex("A5654F"), hex("98584A"), hex("AA7458"), hex("8F5E4D") },
}
World.WALL_FINISHES, World.WALL_HUES, World.DEFAULT_PICK = WALL_FINISHES, WALL_HUES, DEFAULT_PICK
local NO_ATTR = {} -- "this Model and the ones above it do not have the attribute" in the attribute caches

-- a stable 32-bit hash of a string (djb2)
local function hashString(str)
	local h = 5381
	for i = 1, #str do
		h = (h * 33 + string.byte(str, i)) % 4294967296
	end
	return h
end
-- the builder's plain plaster colour: grey, beige or green-grey in a mid range (not a painted or coloured wall)
local function plainPlaster(c)
	local r, g, b = c.R * 255, c.G * 255, c.B * 255
	local hi = math.max(r, g, b)
	return math.abs(r - g) <= 8 and math.abs(g - b) <= 24 and r >= b - 4 and hi >= 100 and hi <= 215
end
-- an upright, thin box: a wall, or a lintel, sill or jamb piece of one (not a floor, slab, column or block)
local function wallPiece(p)
	local s = p.Size
	local thin = math.min(s.X, s.Z)
	local big = math.max(s.X, s.Y, s.Z)
	if big <= 1.5 or s.Y <= thin or thin > 2.6 then
		return false
	end
	return thin <= 1.6 or math.max(s.X, s.Z) >= 2 * thin
end
-- the value of an attribute on the nearest Model at or above inst (nil when there is none); memo is per attribute
local function modelAttr(inst, name, memo)
	if inst == nil then
		return nil
	end
	local hit = memo[inst]
	if hit ~= nil then
		if hit == NO_ATTR then
			return nil
		end
		return hit
	end
	local v = nil
	if inst:IsA("Model") then
		v = inst:GetAttribute(name)
	end
	if v == nil then
		v = modelAttr(inst.Parent, name, memo)
	end
	if v == nil then
		memo[inst] = NO_ATTR
	else
		memo[inst] = v
	end
	return v
end

function World.applyWear(folder)
	local MS = game:GetService("MaterialService")
	-- ready variants: name -> base material. A game script may not read MaterialVariant.ColorMap ("lacking capability
	-- Plugin"; reading it stopped the whole world build in Studio, 2026-11-01), so a variant counts as ready unless the read
	-- succeeds and says its map is empty.
	local base = {}
	for _, v in MS:GetChildren() do
		if v:IsA("MaterialVariant") then
			local ok, map = pcall(function()
				return v.ColorMap
			end)
			if not ok or map ~= "" then
				base[v.Name] = v.BaseMaterial
			end
		end
	end
	local memoFinish, memoTint, memoNoDetail, memoPick, memoName = {}, {}, {}, {}, {}
	local stats = {}
	local n = 0

	-- the pick of a part's Model and floor band: { name = a DEFAULT_PICK finish, h = the hash the hues come from }
	local function pickFor(p)
		local m = p:FindFirstAncestorOfClass("Model") or p.Parent
		local full = memoName[m]
		if full == nil then
			full = m:GetFullName()
			memoName[m] = full
		end
		local key = full .. "#" .. math.floor(p.Position.Y / 11)
		local pk = memoPick[key]
		if pk == nil then
			local h = hashString(key)
			local roll = Random.new(h):NextInteger(1, 100)
			pk = { name = "ZR_PlasterPeel", h = h, hue = {} }
			local acc = 0
			for _, e in DEFAULT_PICK do
				acc += e[2]
				if roll <= acc then
					pk.name = e[1]
					break
				end
			end
			memoPick[key] = pk
		end
		return pk
	end
	local function hueOf(pk, kind)
		local c = pk.hue[kind]
		if c == nil then
			local list = WALL_HUES[kind]
			c = list[Random.new(pk.h + 7919):NextInteger(1, #list)]
			pk.hue[kind] = c
		end
		return c
	end
	-- may this part take a hue from the lists? Tint (on the part, else the nearest Model) says; else the builder's plain
	-- plaster colour does. Brick and wood keep a colour the builder chose for that very material
	local function mayTint(p, kind, orig, now)
		local t = p:GetAttribute("Tint")
		if t == nil then
			t = modelAttr(p.Parent, "Tint", memoTint)
		end
		if t ~= nil then
			return t == true
		end
		return plainPlaster(p.Color) and (kind == "paint" or orig ~= now)
	end

	for _, p in folder:GetDescendants() do
		if p:IsA("Part") and p.Transparency < 1 then
			local want = p:GetAttribute("Wear")
			local finish, kind, pk = false, nil, nil
			local orig = p.Material
			if want == nil then
				local s = p.Size
				local thin = math.min(s.X, s.Y, s.Z)
				local big = math.max(s.X, s.Y, s.Z)
				-- wall finishes: a Finish attribute (the part's own, or the nearest Model's for wall pieces), else the default
				local own = p:GetAttribute("Finish")
				local explicit = type(own) == "string"
				local fin = nil
				local wall = false
				if explicit then
					fin = own
				else
					-- furniture and doors are not walls: NoDetail on the part or on a Model above it
					wall = wallPiece(p) and p:GetAttribute("NoDetail") ~= true and modelAttr(p.Parent, "NoDetail", memoNoDetail) ~= true
					if wall then
						local up = modelAttr(p.Parent, "Finish", memoFinish)
						if type(up) == "string" then
							fin = up
						end
					end
				end
				if fin ~= nil then
					if fin ~= "" then
						if string.sub(fin, 1, 3) ~= "ZR_" then
							fin = "ZR_" .. fin
						end
						local fits = explicit or orig == M.Plaster or ((orig == M.Concrete or orig == M.Brick) and STRUCTURAL[fin] == true)
						if fits and base[fin] ~= nil then
							want, finish, kind = fin, true, FINISH_KIND[fin]
							pk = pickFor(p)
						end
					end
				elseif wall then
					if orig == M.Plaster then
						pk = pickFor(p)
						local name = pk.name
						-- wallpaper and gloss are for inside: outside (thick) walls, coloured walls and Tint = false get whitewash
						local thick = math.min(s.X, s.Z) > 0.95
						if name == "ZR_WallpaperA" or name == "ZR_WallpaperB" then
							if thick or not mayTint(p, "paint", orig, orig) then
								name = "ZR_Whitewash"
							end
						elseif name == "ZR_PaintGloss" and thick then
							name = "ZR_Whitewash"
						end
						if base[name] ~= nil then
							want, finish, kind = name, true, FINISH_KIND[name]
						end
					elseif orig == M.Brick and base.ZR_BrickWall ~= nil then
						want, finish = "ZR_BrickWall", true -- the builder's brick colour stays
					end
				end
				if want == nil then
					-- the shape rules
					if orig == M.Concrete then
						if s.Y <= math.min(s.X, s.Z) and s.Y < 9 and math.max(s.X, s.Z) > 6 then
							want = "ZR_FloorConcrete" -- slabs, floors, roofs seen from below
						elseif big > 60 and thin <= 2.5 then
							want = "ZR_ConcretePanel" -- long perimeter walls
						elseif big > 3 then
							want = "ZR_ConcreteWorn"
						end
					elseif orig == M.CorrodedMetal then
						want = big > 6 and "ZR_Corrugated" or nil
					elseif WEAR_BY_MATERIAL[orig] and big > 1.5 then
						want = WEAR_BY_MATERIAL[orig]
					end
				end
			end
			if want and want ~= "" and base[want] ~= nil then
				if finish then
					-- a finish sets the material its variant belongs to, and a hue where the part may take one
					if orig ~= base[want] then
						p.Material = base[want]
					end
					if kind ~= nil and pk ~= nil and mayTint(p, kind, orig, p.Material) then
						local hue = hueOf(pk, kind)
						if kind == "paint" then
							-- the hue of the list at the brightness the builder gave the wall
							local hh, hs = hue:ToHSV()
							local _, _, pv = p.Color:ToHSV()
							p.Color = Color3.fromHSV(hh, hs, math.clamp(pv, 0.4, 0.75))
						else
							p.Color = hue
						end
					end
				end
				p.MaterialVariant = want
				n += 1
				stats[want] = (stats[want] or 0) + 1
			end
		end
	end
	return n, stats
end

-- building kit handed to map modules (src/server/Maps/*): the same primitives, props and registration helpers
-- Quay 7 uses. Coordinates are world coordinates; each map module adds its own origin.
function World.kit()
	return {
		World = World, root = root, C = C, M = M, hex = hex, rng = rng, Props = Props,
		part = part, box = box, boxCF = boxCF, cyl = cyl, vcyl = vcyl, model = model, jitter = jitter, light = light,
		sign = sign, mesh = mesh, wall = wall, wallHoles = wallHoles, loose = loose,
		container = addContainerSpot, extract = addExtract, foliage = World.addFoliage,
		-- a mounted gun (Stationary.luau): kind "HMG12" or "AGL30", the ground point under it with its heading, opts. The guns
		-- go in a Stationary folder of the world root (ZR_World reaches the workspace only when the build is done)
		stationary = function(kind, cf, opts)
			opts = table.clone(opts or {})
			if not opts.parent then
				local folder = root:FindFirstChild("Stationary")
				if not folder then
					folder = Instance.new("Folder")
					folder.Name = "Stationary"
					folder.Parent = root
				end
				opts.parent = folder
			end
			return require(script.Parent.Stationary).place(kind, cf, opts)
		end,
	}
end

function World.build()
	for _, n in { "Baseplate", "SpawnLocation" } do
		local inst = workspace:FindFirstChild(n)
		if inst and inst:IsA("BasePart") then
			inst:Destroy()
		end
	end
	local old = workspace:FindFirstChild("ZR_World")
	if old then
		old:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "ZR_World"
	World.foliage = { cells = {}, n = 0 }
	World.natureRegions = {} -- terrain areas that get client ground cover (M13): { x0, z0, x1, z1, yMin, yMax }
	local trig = Instance.new("Folder")
	trig.Name = "Triggers"
	trig.Parent = root
	setupLighting()
	buildSafehouse()
	beginMap("quay7")
	local map = model("Quay7", root)
	buildGround(map)
	buildHarborStack(map)
	buildPumpAnnex(map)
	buildFreightDepot(map)
	buildDormitory(map)
	buildLandmarksAndRoutes(map)
	buildQuayDressing(map)
	-- extract rules (Tarkov): open, paid (MK on exit), key (carry the key), chance (rolled per raid), scav-only
	addExtract(map, "A", "RELAY GATE", Vector3.new(184, 0, -184), Vector3.new(18, 12, 16), { kind = "open" })
	addExtract(map, "B", "PIER 3 BOAT", Vector3.new(236, 0, 150), Vector3.new(16, 12, 14), { kind = "paid", cost = 8000 })
	addExtract(map, "C", "RAIL CUT", Vector3.new(-180, 0, -188), Vector3.new(16, 12, 14), { kind = "open" })
	addExtract(map, "D", "STORM CULVERT", Vector3.new(-186, 0, 132), Vector3.new(12, 10, 12), { kind = "scav" })
	addExtract(map, "E", "SERVICE SHAFT", Vector3.new(92, 0, -186), Vector3.new(12, 10, 12), { kind = "key", key = "KEY_OFFICE" })
	addExtract(map, "F", "CRANE YARD LIFT", Vector3.new(-122, 0, 184), Vector3.new(14, 12, 12), { kind = "chance", chance = 0.6 })
	-- PMC spawns per side; each side exits on the far side of the quay (scavs may use every extract)
	local function sp(id, name, x, z, yaw, side)
		return { id = id, name = name, cf = CFrame.new(x, 3.4, z) * CFrame.Angles(0, math.rad(yaw), 0), side = side }
	end
	World.spawns = {
		sp("W1", "FERRY TUNNEL", -190, 10, -90, "west"), sp("W2", "WEST FENCE", -188, -110, -90, "west"), sp("W3", "PUMP LANE", -186, 80, -90, "west"),
		sp("S1", "SOUTH YARD", -50, 186, 0, "south"), sp("S2", "COLD STORE", 60, 184, 0, "south"), sp("S3", "BERTH 9", 150, 182, 20, "south"),
		sp("E1", "EAST APRON", 186, -70, 90, "east"), sp("E2", "BOLLARD ROW", 184, 40, 90, "east"),
		sp("N1", "NORTH LOT", 0, -188, 180, "north"), sp("N2", "SCRAP GATE", -100, -186, 180, "north"),
	}
	World.sideExtracts = {
		west = { "A", "B", "E", "F" }, south = { "A", "C", "E" }, east = { "C", "F", "E" }, north = { "B", "F", "C" },
	}
	for _, s in World.spawns do
		s.extracts = World.sideExtracts[s.side]
	end
	-- AI (M8): scav wander/spawn points around the points of interest, Harbor Watch posts, the Foreman's depot
	local function v(x, y, z)
		return Vector3.new(x, y, z)
	end
	World.scavZones = {
		-- Harbor Stack alleys
		v(-96, 0, -140), v(-40, 0, -140), v(-40, 0, -76), v(-96, 0, -76), v(-150, 0, -108), v(-96, 0, -108),
		-- around the Pump Annex
		v(30, 0, 85), v(126, 0, 100), v(126, 0, 48), v(70, 0, 48), v(60, 0.4, 88),
		-- south yard, water tower, culvert side
		v(-90, 0, 78), v(-30, 0, 132), v(0, 0, 110), v(60, 0, 150), v(120, 0, 140), v(-130, 0, 98), v(-160, 0, 150),
		-- roads, east apron, pier approach, rail cut
		v(-20, 0, 18), v(-60, 0, 32), v(60, 0, 32), v(100, 0, 12), v(160, 0, -70), v(170, 0, 100), v(-170, 0, -150),
		-- depot dock
		v(36, 0, -94), v(36, 0, -130),
		-- crew dormitory walkway, balcony and the yard in front
		v(-60, 0, 62), v(-36, 0, 62), v(-48, 10.3, 60.4), v(-30, 0, 76),
	}
	World.watchPosts = {
		{ route = "PA", post = v(70, 10, 106) }, -- mezzanine overwatch in the turbine room
		{ route = "PA" },
		{ route = "HS" },
	}
	World.visitZones = { PIER3 = { pos = v(236, 0, 150), r = 18 }, RELAY = { pos = v(190, 0, -190), r = 14 } }
	World.boss = {
		name = "THE FOREMAN", home = v(116, 4, -128),
		route = { v(116, 4, -128), v(84, 4, -126), v(62, 4, -110), v(100, 4, -112), v(140, 4, -112), v(142, 4, -128) },
		crew = { v(112, 4, -130), v(80, 4, -122) },
	}
	-- the area the AI samples for cover points, and the floor heights it keeps
	World.bounds = { x0 = -192, x1 = 192, z0 = -192, z1 = 192, yMin = -2, yMax = 16 }
	endMap("quay7", map)
	-- M13: the other maps, each built at its own origin by its own module (src/server/Maps). A module that fails is
	-- left out (logged, its half-built parts removed) so the server still starts with the maps that did build.
	local function moduleMap(id, moduleName)
		local trig = #root.Triggers:GetChildren()
		beginMap(id)
		local t0 = os.clock()
		local ok, res = pcall(function()
			return require(script.Parent.Parent.Maps[moduleName])(World.kit(), root)
		end)
		if ok and res then
			endMap(id, res)
			print(string.format("[ZR] map %s built in %.2fs", id, os.clock() - t0))
			return
		end
		warn("[ZR] map " .. id .. " failed to build: " .. tostring(res))
		local partial = root:FindFirstChild(moduleName)
		if partial then
			partial:Destroy()
		end
		for i = #World.containers, 1, -1 do
			if World.containers[i].map == id then
				table.remove(World.containers, i)
			end
		end
		for did, d in World.doors do
			if d.map == nil then
				World.doors[did] = nil
			end
		end
		for sid, sw in World.switches do
			if sw.map == nil then
				World.switches[sid] = nil
			end
		end
		local kids = root.Triggers:GetChildren()
		for i = trig + 1, #kids do
			kids[i]:Destroy()
		end
		currentMap = nil
	end
	moduleMap("smelter", "Smelter")
	moduleMap("meridian", "Meridian")
	moduleMap("border", "Border")
	-- parked for now (owner's call, M13): moduleMap("pinewatch", "Pinewatch")
	-- doors: a hinged slab with an interaction prompt (state and keys: Doors.luau)
	for _, d in World.doors do
		local slab = Instance.new("Part")
		slab.Name = "Door_" .. d.id
		slab.Size = d.size
		slab.CFrame = d.cf
		slab.Anchored = true
		slab.Color = d.color or hex("5A5F57")
		slab.Material = d.card and M.DiamondPlate or M.Metal
		slab:SetAttribute("NoDetail", true) -- it swings open; decals would be left hanging in the air
		-- AI paths go through doors (they open unlocked ones on the way; Doors.luau blocks locked ones)
		local pm = Instance.new("PathfindingModifier")
		pm.Label = "Door"
		pm.PassThrough = d.key == nil
		pm.Parent = slab
		d.modifier = pm
		slab.TopSurface = Enum.SurfaceType.Smooth
		slab.BottomSurface = Enum.SurfaceType.Smooth
		slab.Parent = d.parent
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.15, 0.15, 0.6)
		handle.CFrame = d.cf * CFrame.new(d.size.X / 2 - 0.4, -0.3, 0)
		handle.Anchored = false
		handle.Massless = true
		handle.CanCollide = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = slab
		weld.Part1 = handle
		weld.Parent = handle
		handle.Color = hex("2A2D2B")
		handle.Material = M.Metal
		handle.Parent = slab
		local pp = Instance.new("ProximityPrompt")
		pp.KeyboardKeyCode = Enum.KeyCode.F
		pp.ActionText = "Open"
		pp.ObjectText = d.label
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 7
		pp.RequiresLineOfSight = false
		pp.Style = Enum.ProximityPromptStyle.Custom
		pp.Parent = slab
		d.part, d.handle, d.prompt = slab, handle, pp
		d.parent = nil
	end
	World.activate("quay7")
	local worn, wornBy = World.applyWear(root)
	root.Parent = workspace
	-- props and trees that landed wrong: out of doorways, off water, out of walls and floors (Maps/Tidy.luau). It needs
	-- the world in the workspace for its rays and box queries, so it runs here, once every map is built; the lobby is
	-- placed by hand and left alone
	for id, mm in World.maps do
		if id ~= "relay7" and mm.model and mm.model:IsDescendantOf(workspace) then
			local okT, tidy = pcall(function()
				return require(script.Parent.Parent.Maps.Tidy).run(id, mm.model, World.doors)
			end)
			if okT then
				print(string.format("[ZR] %s tidy: %d out of doorways, %d out of door swings, %d doors re-hung, %d doors open less than 100 degrees, %d twins, %d stacked, %d trees, %d off water (%d big ones kept), %d lifted, %d out of walls (%d removed, %d left), %.2fs",
					id, tidy.doorways, tidy.swing, tidy.doorsTurned, tidy.doorsShort, tidy.twins, tidy.stacked, tidy.trees, tidy.water, tidy.waterBig, tidy.sunk, tidy.walls, tidy.wallsGone, tidy.wallsLeft, tidy.seconds))
			else
				warn("[ZR] " .. id .. " tidy failed: " .. tostring(tidy))
			end
		end
	end
	snapLooseSpots()
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	local names = {}
	for id in World.maps do
		table.insert(names, id)
	end
	table.sort(names)
	print(string.format("[ZR] World built: %d parts (%d worn), maps %s, %d containers, %d doors", n, worn, table.concat(names, "+"), #World.containers, (function()
		local k = 0
		for _ in World.doors do
			k += 1
		end
		return k
	end)()))
	-- how many parts took each wall finish (the new variants only count once their maps are filled in)
	local fin = {}
	for _, name in WALL_FINISHES do
		table.insert(fin, string.format("%s %d", string.sub(name, 4), (wornBy and wornBy[name]) or 0))
	end
	print("[ZR] Wall finishes: " .. table.concat(fin, ", "))
end

-- places the cosmetic detail plan keeps its ground clutter away from (M12): loot spots, containers, doors (and
-- their swing), exfil zones and spawns of every map, so clutter never hides loot or a prompt and never fills a doorway
function World.detailAvoid()
	local out = {}
	local function add(pos, r)
		table.insert(out, { pos = pos, r = r })
	end
	for _, m in World.maps do
		for _, s in m.looseSpots do
			add(s.pos, 1.8)
		end
		for _, e in m.extracts do
			add(e.pos, math.max(e.size.X, e.size.Z) / 2 + 1)
		end
		for _, sp in m.spawns do
			add(sp.cf.Position, 4)
		end
	end
	for _, c in World.containers do
		if c.part then
			add(c.part.Position, math.max(c.part.Size.X, c.part.Size.Z) / 2 + 2)
		end
	end
	for _, d in World.doors do
		local cf = d.part and d.part.CFrame or d.cf
		if cf and d.size then
			add(cf.Position, d.size.X + 0.6)
		end
	end
	return out
end

function World.init(_ctx) end

World.Props = Props
World.part = part
World.box = box
return World
