--!nonstrict
-- M12 client detail layer and graphics presets.
-- The server publishes a detail plan (ReplicatedStorage.ZR_DetailPlan: one JSON list per 64-stud cell, see the
-- server DetailPlan module). This controller builds the cells around the camera in distance rings: fine clutter
-- close by, medium marks further out, the big grime strips furthest. It creates a few dozen instances per frame so
-- nothing hitches, and tears cells down again as the camera moves away. Detail is local to this client and never
-- collides, takes bullets or blocks sight.
-- Graphics presets (Settings.quality): 3 HIGH, 2 MEDIUM, 1 LOW, 0 POTATO. Potato builds no detail, swaps the worn
-- materials back to plain ones and turns shadows off, on this client only (switching back restores everything).
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Wear = require(Shared.Wear)
local AssetMeta = require(Shared.AssetMeta)

local Detail = { level = 3, instances = 0, cells = 0, pending = 0 }
local ctx
local root: Folder
local cells = {} -- key -> { center, byLod = { [1] = {}, ... }, built = { [lod] = Folder } }
local queue = {} -- { cell, lod, i, folder, d }
-- distance (studs from the camera to the cell centre) up to which each lod is built, per level
local RINGS = {
	[3] = { 270, 215, 150 },
	[2] = { 200, 155 },
	[1] = { 135 },
}
local BUDGET = 60 -- instances per frame
local HALF = Wear.CELL / 2

-- ── building ────────────────────────────────────────────────────────────────────
local templates = {}
local function template(key)
	local t = templates[key]
	if t == nil then
		local lib = ReplicatedStorage:FindFirstChild("ZR_Assets")
		t = lib and lib:FindFirstChild(key) or false
		if t then
			templates[key] = t
		end
	end
	return t or nil
end

local function quiet(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
end

local function makeDecal(e)
	local c = Vector3.new(e[3], e[4], e[5])
	local n = Vector3.new(e[6], e[7], e[8])
	local cf = CFrame.lookAt(c, c + n, math.abs(n.Y) > 0.9 and Vector3.zAxis or Vector3.yAxis)
	if e[11] ~= 0 then
		cf *= CFrame.Angles(0, 0, math.rad(e[11]))
	end
	local p = Instance.new("Part")
	quiet(p)
	p.CastShadow = false
	p.Transparency = 1
	-- a thin carrier keeps the decal close to the depth the plan chose for it (DetailPlan layers)
	p.Size = Vector3.new(math.max(0.05, e[9]), math.max(0.05, e[10]), 0.02)
	p.CFrame = cf
	local d
	if e[13] > 0 then
		d = Instance.new("Texture")
		d.StudsPerTileU = e[13]
		d.StudsPerTileV = e[14]
		d.OffsetStudsU = e[16] % e[13]
	else
		d = Instance.new("Decal")
	end
	d.Texture = e[2]
	d.Transparency = e[15]
	d.Face = Enum.NormalId.Front
	d.Parent = p
	return p
end

local function makeMesh(e)
	local key = e[2]
	local t = template(key)
	if not t then
		return nil
	end
	local m = t:Clone()
	local off = AssetMeta[key] or Vector3.new(0, t.Size.Y / 2, 0)
	if e[10] ~= 1 or e[11] ~= 1 or e[12] ~= 1 then
		local s = Vector3.new(e[10], e[11], e[12])
		m.Size = t.Size * s
		off *= s
	end
	m.CFrame = CFrame.new(e[3], e[4], e[5]) * CFrame.Angles(0, math.rad(e[6]), 0) * CFrame.Angles(math.rad(e[7]), 0, math.rad(e[8])) * CFrame.new(off)
	quiet(m)
	local def = Wear.MESH[key] or {}
	m.CastShadow = def.shadow == true
	local rgb = e[13]
	if rgb ~= 0 then
		m.Color = Color3.fromRGB(rgb // 65536, (rgb // 256) % 256, rgb % 256)
	elseif def.color then
		m.Color = def.color
	end
	if def.material then
		m.Material = def.material
	end
	if def.transparency then
		m.Transparency = def.transparency
	end
	return m
end

local function lodOf(e)
	return e[1] == 1 and e[12] or e[9]
end

-- ── M13 ground cover on terrain maps ───────────────────────────────────────────────────────────────────────
-- The server names the terrain regions (plan attribute "Nature": { x0, z0, x1, z1, yMin, yMax } in world studs). Each
-- client scatters grass, ferns, reeds, fallen branches and stones over the terrain of the cells near its camera,
-- seeded per cell, so every client gets the same layout. Nothing here is taller than a prone body (no setting hides
-- more than another); like the rest of the layer it never collides or blocks sight.
-- material -> { key, share of sample points, lod, min scale, max scale }
local NAT = {
	[Enum.Material.Grass] = { { "ZR_NAT_Grass", 0.34, 3, 0.75, 0.98 }, { "ZR_NAT_Fern", 0.08, 2, 0.7, 1.1 } },
	[Enum.Material.LeafyGrass] = { { "ZR_NAT_Fern", 0.26, 2, 0.7, 1.2 }, { "ZR_NAT_Grass", 0.12, 3, 0.7, 0.95 }, { "ZR_NAT_Branch", 0.02, 3, 0.6, 1.0 } },
	[Enum.Material.Ground] = { { "ZR_NAT_Branch", 0.04, 3, 0.6, 1.1 }, { "ZR_NAT_Fern", 0.05, 2, 0.6, 0.9 } },
	[Enum.Material.Mud] = { { "ZR_NAT_Reeds", 0.45, 2, 0.42, 0.52 } }, -- only by the water (see genNature)
	[Enum.Material.Rock] = { { "ZR_NAT_RockPile", 0.05, 2, 0.18, 0.3 } },
	[Enum.Material.Slate] = { { "ZR_NAT_RockPile", 0.05, 2, 0.18, 0.3 } },
}
local NAT_GRID = 12 -- sample points per cell side
local natParams = RaycastParams.new()
natParams.FilterType = Enum.RaycastFilterType.Include
local function r2(v)
	return math.floor(v * 100 + 0.5) / 100
end

-- scatter one cell's ground cover; false when the terrain there has not streamed in yet (try again later)
local function genNature(cell)
	local r = cell.natRegion
	natParams.FilterDescendantsInstances = { workspace.Terrain, workspace:FindFirstChild("ZR_World") }
	local rnd = Random.new(bit32.bxor(cell.cx * 73856093, cell.cz * 19349663) % 2147483647)
	local step = Wear.CELL / NAT_GRID
	local x0, z0 = cell.center.X - HALF, cell.center.Z - HALF
	local hits, added = 0, 0
	for i = 0, NAT_GRID - 1 do
		for k = 0, NAT_GRID - 1 do
			local x, z = x0 + (i + rnd:NextNumber(0.1, 0.9)) * step, z0 + (k + rnd:NextNumber(0.1, 0.9)) * step
			local roll, yaw, sr = rnd:NextNumber(), rnd:NextNumber(0, 360), rnd:NextNumber()
			if x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4] then
				local hit = workspace:Raycast(Vector3.new(x, r[6], z), Vector3.new(0, r[5] - r[6], 0), natParams)
				if hit then
					hits += 1
				end
				-- terrain only (not a floor, a trunk or a rock), not too steep
				local opts = hit and hit.Instance == workspace.Terrain and hit.Normal.Y > 0.75 and NAT[hit.Material]
				if opts then
					local acc = 0
					for _, o in opts do
						acc += o[2]
						if roll < acc then
							if not (o[1] == "ZR_NAT_Reeds" and hit.Position.Y > 2.6) then -- reeds by the lake, not in road ruts
								local s = o[4] + (o[5] - o[4]) * sr
								local y = r2(hit.Position.Y - 0.05)
								table.insert(cell.byLod[o[3]], { 2, o[1], r2(x), y, r2(z), math.floor(yaw), 0, 0, o[3], r2(s), r2(s), r2(s), 0 })
								cell.y0 = math.min(cell.y0, y)
								cell.y1 = math.max(cell.y1, y + 1)
								added += 1
							end
							break
						end
					end
				end
			end
		end
	end
	return hits > 0, added
end

local function dropCell(cell, lod)
	local f = cell.built[lod]
	if f then
		Detail.instances -= f:GetAttribute("N") or 0
		f:Destroy()
		cell.built[lod] = nil
	end
end

local function loadCell(sv)
	local ok, list = pcall(HttpService.JSONDecode, HttpService, sv.Value)
	if not ok or type(list) ~= "table" then
		return
	end
	local cx, cz, u = string.match(sv.Name, "^(-?%d+)_(-?%d+)(u?)$")
	if not cx then
		return
	end
	local cell = { key = sv.Name, center = Vector3.new(tonumber(cx) * Wear.CELL + HALF, 0, tonumber(cz) * Wear.CELL + HALF), byLod = { {}, {}, {} }, built = {}, y0 = math.huge, y1 = -math.huge, under = u == "u" }
	for _, e in list do
		local l = math.clamp(lodOf(e) or 2, 1, 3)
		table.insert(cell.byLod[l], e)
		local y = e[4]
		if type(y) == "number" then
			cell.y0 = math.min(cell.y0, y)
			cell.y1 = math.max(cell.y1, y)
		end
	end
	if cell.y0 > cell.y1 then
		cell.y0, cell.y1 = 0, 0
	end
	-- a cell that already carried ground cover keeps its region (the cover is scattered again)
	local old = cells[sv.Name]
	if old and old.natRegion then
		cell.natRegion, cell.natPending, cell.cx, cell.cz = old.natRegion, true, old.cx, old.cz
		cell.y0, cell.y1 = math.min(cell.y0, old.natRegion[5]), math.max(cell.y1, old.natRegion[6])
		for lod = 1, 3 do
			dropCell(old, lod)
		end
	end
	cells[sv.Name] = cell
end

-- cells over terrain regions get ground cover, scattered when the camera first comes near
local function addNatureCells(regions)
	local CELL = Wear.CELL
	for _, r in regions do
		if type(r) == "table" and #r >= 6 then
			for cx = math.floor(r[1] / CELL), math.floor(r[3] / CELL) do
				for cz = math.floor(r[2] / CELL), math.floor(r[4] / CELL) do
					local key = cx .. "_" .. cz
					local cell = cells[key]
					if not cell then
						cell = { key = key, center = Vector3.new(cx * CELL + HALF, 0, cz * CELL + HALF), byLod = { {}, {}, {} }, built = {}, y0 = r[5], y1 = r[6], under = false }
						cells[key] = cell
					else
						cell.y0, cell.y1 = math.min(cell.y0, r[5]), math.max(cell.y1, r[6])
					end
					cell.cx, cell.cz, cell.natRegion, cell.natPending = cx, cz, r, true
				end
			end
		end
	end
end

local function clearAll()
	for _, cell in cells do
		for lod = 1, 3 do
			dropCell(cell, lod)
		end
	end
	table.clear(queue)
	Detail.instances = 0
end

-- ── which cells, at which detail ────────────────────────────────────────────────
-- distance from the camera to a cell's box (its 64-stud square and the height range of its details)
local function cellDist(cell, camPos)
	local dx = math.max(0, math.abs(cell.center.X - camPos.X) - HALF)
	local dz = math.max(0, math.abs(cell.center.Z - camPos.Z) - HALF)
	local dy = math.max(0, cell.y0 - camPos.Y, camPos.Y - cell.y1)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function refresh()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local rings = RINGS[Detail.level]
	local built = 0
	-- tunnels and the surface hide each other: underground cells only while the camera is underground, and only
	-- the surface right around a stairwell while it is
	local camUnder = camPos.Y < -1
	local reach = rings and (rings[1] + 40) or 0
	local gen = {}
	for _, cell in cells do
		local d = cellDist(cell, camPos)
		if cell.under ~= camUnder then
			d = (cell.under or d > 40) and math.huge or d
		end
		if cell.natPending and d < reach and os.clock() >= (cell.natRetry or 0) then
			table.insert(gen, { cell = cell, d = d })
		end
		for lod = 1, 3 do
			local r = rings and rings[lod]
			local have = cell.built[lod] ~= nil
			local want = r ~= nil and d < (have and r + 30 or r) and #cell.byLod[lod] > 0
			if want and not have then
				local f = Instance.new("Folder")
				f.Name = cell.key .. "_" .. lod
				f:SetAttribute("N", 0)
				f.Parent = root
				cell.built[lod] = f
				table.insert(queue, { cell = cell, lod = lod, i = 1, folder = f, d = d + lod * 20 })
			elseif have and not want then
				dropCell(cell, lod)
			end
			if cell.built[lod] then
				built += 1
			end
		end
	end
	Detail.cells = built
	-- ground cover for the nearest pending cells (a couple per pass; they build on the next pass)
	table.sort(gen, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.min(2, #gen) do
		local cell = gen[i].cell
		local ok, added = genNature(cell)
		if ok then
			cell.natPending = false
			Detail.natureCells = (Detail.natureCells or 0) + 1
			Detail.natureItems = (Detail.natureItems or 0) + added
			for lod = 1, 3 do
				dropCell(cell, lod) -- rebuild with the cover included
			end
		else
			cell.natRetry = os.clock() + 2 -- terrain not streamed in yet
		end
	end
	-- nearest jobs first; drop jobs whose folder was torn down
	local keep = {}
	for _, j in queue do
		if j.folder.Parent then
			j.d = cellDist(j.cell, camPos) + j.lod * 20
			table.insert(keep, j)
		end
	end
	table.sort(keep, function(a, b)
		return a.d < b.d
	end)
	queue = keep
end

local function work()
	local budget = BUDGET
	while budget > 0 and #queue > 0 do
		local j = queue[1]
		if not j.folder.Parent then
			table.remove(queue, 1)
			continue
		end
		local list = j.cell.byLod[j.lod]
		local n = 0
		while budget > 0 and j.i <= #list do
			local e = list[j.i]
			j.i += 1
			local inst = (e[1] == 1) and makeDecal(e) or makeMesh(e)
			if inst then
				inst.Parent = j.folder
				n += 1
			end
			budget -= 1
		end
		j.folder:SetAttribute("N", (j.folder:GetAttribute("N") or 0) + n)
		Detail.instances += n
		if j.i > #list then
			table.remove(queue, 1)
		end
	end
	Detail.pending = #queue
end

-- ── M13 tree shadows: forest trees arrive without shadows (thousands of casters would sink the frame rate);
-- the trees near the camera cast them, the radius set by the graphics level ─────────────────────────────────
local TREE_SHADOW = { [3] = 90, [2] = 55, [1] = 0, [0] = 0 }
local trees = {} -- tagged trunks and crowns (streamed in and out)
local shadowOn = {}
local lastShadowPos = nil
local function treeShadows(camPos, force)
	if not force and lastShadowPos and (camPos - lastShadowPos).Magnitude < 6 then
		return
	end
	lastShadowPos = camPos
	local r = TREE_SHADOW[Detail.level] or 0
	local r2 = r * r
	for p in trees do
		local d = p.Position - camPos
		local want = r > 0 and (d.X * d.X + d.Z * d.Z) < r2
		if want ~= (shadowOn[p] == true) then
			p.CastShadow = want
			shadowOn[p] = want or nil
		end
	end
end

-- ── potato: plain materials, no shadows, no cloud layer, no fill lights (local only, reversible) ───
-- Fog, light levels and exposure stay the same on every preset, so no setting sees further or through more.
-- strong keys: a weak-keyed table would drop Instance keys (their Lua handles get collected while the parts live on),
-- and leaving POTATO would then not restore the materials
local stripped = {}
local stripConn
local function strip(d)
	if d:IsA("BasePart") and d.MaterialVariant ~= "" then
		stripped[d] = d.MaterialVariant
		d.MaterialVariant = ""
	elseif d:IsA("Light") and d.Enabled and d:GetAttribute("Fill") then
		stripped[d] = true -- extra fill lights (the lobby bunker) go out on POTATO
		d.Enabled = false
	end
end
local function setPotato(on)
	local world = workspace:FindFirstChild("ZR_World")
	if on then
		if world then
			for _, d in world:GetDescendants() do
				strip(d)
			end
			if not stripConn then
				stripConn = world.DescendantAdded:Connect(strip) -- parts streamed in later
			end
		end
		Lighting.GlobalShadows = false
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
		if clouds then
			clouds.Enabled = false
		end
	else
		if stripConn then
			stripConn:Disconnect()
			stripConn = nil
		end
		for p, v in stripped do
			if p.Parent then
				if v == true then
					p.Enabled = true
				else
					p.MaterialVariant = v
				end
			end
		end
		table.clear(stripped)
		Lighting.GlobalShadows = true
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
		if clouds then
			clouds.Enabled = true
		end
	end
end

function Detail.setLevel(level)
	level = math.clamp(math.floor(tonumber(level) or 3), 0, 3)
	if level == Detail.level and Detail.applied then
		return
	end
	local wasPotato = Detail.applied and Detail.level == 0
	Detail.level = level
	Detail.applied = true
	clearAll()
	local cam = workspace.CurrentCamera
	if cam then
		treeShadows(cam.CFrame.Position, true)
	end
	if level == 0 then
		setPotato(true)
	elseif wasPotato then
		setPotato(false)
	end
	-- the cloud layer is sky dressing only: LOW and POTATO go without it
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Enabled = level >= 2
	end
	refresh()
end

function Detail.stats()
	return { level = Detail.level, instances = Detail.instances, cells = Detail.cells, pending = Detail.pending, natureCells = Detail.natureCells or 0, natureItems = Detail.natureItems or 0, planCells = (function()
		local n = 0
		for _ in cells do
			n += 1
		end
		return n
	end)() }
end

function Detail.init(c)
	ctx = c
	root = Instance.new("Folder")
	root.Name = "ZR_Detail"
	root.Parent = workspace
	task.spawn(function()
		local pf = ReplicatedStorage:WaitForChild("ZR_DetailPlan", 300)
		while true do
			if pf then
				clearAll()
				table.clear(cells)
				for _, sv in pf:GetChildren() do
					loadCell(sv)
				end
				local okN, regions = pcall(HttpService.JSONDecode, HttpService, pf:GetAttribute("Nature") or "[]")
				if okN and type(regions) == "table" then
					addNatureCells(regions)
				end
				pf.ChildAdded:Connect(loadCell)
				refresh()
				-- a new plan (another map) replaces the folder
				pf.AncestryChanged:Wait()
			end
			pf = ReplicatedStorage:WaitForChild("ZR_DetailPlan", 300)
		end
	end)
	-- forest trees (streamed in and out)
	for _, p in CollectionService:GetTagged("ZR_TreeShadow") do
		trees[p] = true
	end
	CollectionService:GetInstanceAddedSignal("ZR_TreeShadow"):Connect(function(p)
		trees[p] = true
		lastShadowPos = nil
	end)
	CollectionService:GetInstanceRemovedSignal("ZR_TreeShadow"):Connect(function(p)
		trees[p] = nil
		shadowOn[p] = nil
	end)
	-- potato also has to catch the world folder if it arrives after the setting
	workspace.ChildAdded:Connect(function(ch)
		if ch.Name == "ZR_World" and Detail.level == 0 then
			if stripConn then
				stripConn:Disconnect()
				stripConn = nil
			end
			setPotato(true)
		end
	end)
	c.Settings.changed:Connect(function(d)
		Detail.setLevel(d.quality)
	end)
	Detail.setLevel(c.Settings.data.quality)
	local acc = 0
	-- HIGH is everyone's default (phones too); if a device keeps struggling, say once where to turn it down
	local frames, window, lowFor, hinted = 0, 0, 0, false
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.4 then
			acc = 0
			refresh()
			local cam = workspace.CurrentCamera
			if cam then
				treeShadows(cam.CFrame.Position, false)
			end
		end
		if #queue > 0 then
			work()
		end
		frames += 1
		window += dt
		if window >= 1 then
			local fps = frames / window
			frames, window = 0, 0
			if not hinted and Detail.level > 0 and fps < 24 then
				lowFor += 1
				if lowFor >= 20 then
					hinted = true
					if ctx.Hud and ctx.Hud.toast then
						ctx.Hud.toast("Low frame rate - a lower GRAPHICS level in Settings may help", "warn")
					end
				end
			else
				lowFor = 0
			end
		end
	end)
end

return Detail
