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
	p.Size = Vector3.new(math.max(0.05, e[9]), math.max(0.05, e[10]), 0.05)
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

local function loadCell(sv)
	local ok, list = pcall(HttpService.JSONDecode, HttpService, sv.Value)
	if not ok or type(list) ~= "table" then
		return
	end
	local cx, cz = string.match(sv.Name, "^(-?%d+)_(-?%d+)$")
	if not cx then
		return
	end
	local cell = { key = sv.Name, center = Vector3.new(tonumber(cx) * Wear.CELL + HALF, 0, tonumber(cz) * Wear.CELL + HALF), byLod = { {}, {}, {} }, built = {} }
	for _, e in list do
		local l = math.clamp(lodOf(e) or 2, 1, 3)
		table.insert(cell.byLod[l], e)
	end
	cells[sv.Name] = cell
end

local function dropCell(cell, lod)
	local f = cell.built[lod]
	if f then
		Detail.instances -= f:GetAttribute("N") or 0
		f:Destroy()
		cell.built[lod] = nil
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
local function refresh()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local rings = RINGS[Detail.level]
	local built = 0
	for _, cell in cells do
		local dv = cell.center - camPos
		local d = math.sqrt(dv.X * dv.X + dv.Z * dv.Z) - HALF
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
	-- nearest jobs first; drop jobs whose folder was torn down
	local keep = {}
	for _, j in queue do
		if j.folder.Parent then
			local dv = j.cell.center - camPos
			j.d = math.sqrt(dv.X * dv.X + dv.Z * dv.Z) + j.lod * 20
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

-- ── potato: plain materials, no shadows (local only, reversible) ─────────────────
local stripped = setmetatable({}, { __mode = "k" })
local stripConn
local function strip(d)
	if d:IsA("BasePart") and d.MaterialVariant ~= "" then
		stripped[d] = d.MaterialVariant
		d.MaterialVariant = ""
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
	else
		if stripConn then
			stripConn:Disconnect()
			stripConn = nil
		end
		for p, v in stripped do
			if p.Parent then
				p.MaterialVariant = v
			end
		end
		table.clear(stripped)
		Lighting.GlobalShadows = true
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
	if level == 0 then
		setPotato(true)
	elseif wasPotato then
		setPotato(false)
	end
	refresh()
end

function Detail.stats()
	return { level = Detail.level, instances = Detail.instances, cells = Detail.cells, pending = Detail.pending, planCells = (function()
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
				pf.ChildAdded:Connect(loadCell)
				refresh()
				-- a new plan (another map) replaces the folder
				pf.AncestryChanged:Wait()
			end
			pf = ReplicatedStorage:WaitForChild("ZR_DetailPlan", 300)
		end
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
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.4 then
			acc = 0
			refresh()
		end
		if #queue > 0 then
			work()
		end
	end)
end

return Detail
