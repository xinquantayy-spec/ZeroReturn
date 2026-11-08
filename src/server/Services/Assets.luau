--!nonstrict
-- Loads uploaded Blender meshes into the mesh library (MeshParts keyed by name).
-- The library is split (audit tech.13; Roblox: "clients load everything in ReplicatedStorage"):
--   ServerStorage.ZR_Assets       every mesh, for the server's builders (maps, kits, characters)
--   ReplicatedStorage.ZR_Assets   only what clients clone: the wear kit, ground cover, guns, items, character gear
-- The mall and bunker kits (ZR_MK_*), trees, rocks and logs (ZR_NAT_*) and cover props (ZR_PROP_*) reach clients
-- only as the placed copies that stream in. Server code reads ServerStorage.ZR_Assets; client code and the shared
-- builders (GunBuild, ItemModel) read ReplicatedStorage.ZR_Assets.
-- Meshes already present (inserted at edit time) are kept; missing ones are loaded via InsertService.
-- A batch that fails (a fresh upload can still be processing) is retried in the background a few times; every
-- late success fires the onLoaded callbacks (Appearance reconciles characters that show a fallback).
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local AssetIds = require(ReplicatedStorage:WaitForChild("ZR"):WaitForChild("AssetIds"))

local CollectionService = game:GetService("CollectionService")

local Assets = {}
local listeners = {}
-- crowns and bushes are needle and leaf cards: each client dresses the ones near its camera with the see-through
-- foliage texture (Detail controller). The tag sits on the library mesh and rides along on every clone.
local function tagFoliage(l)
	for _, d in l:GetChildren() do
		local n = d.Name
		if d:IsA("MeshPart") and (n:match("^ZR_NAT_.+_C$") or n:match("^ZR_NAT_Bush%d$")) and not CollectionService:HasTag(d, "ZR_Foliage") then
			CollectionService:AddTag(d, "ZR_Foliage")
		end
	end
end
Assets.failed = {} -- key -> last error (batches still missing)
local RETRY = { 15, 45, 120, 300 }

local function folder(parent)
	local l = parent:FindFirstChild("ZR_Assets")
	if not l then
		l = Instance.new("Folder")
		l.Name = "ZR_Assets"
		l.Parent = parent
	end
	return l
end
local function lib() -- the whole library (server only)
	return folder(ServerStorage)
end
local function clientLib() -- what clients clone
	return folder(ReplicatedStorage)
end

-- does any client clone this mesh? The ground cover Detail.luau scatters is the only nature clients clone (keep this
-- list in step with Detail's GROUND table)
local CLIENT_NAT = { ZR_NAT_Grass = true, ZR_NAT_Fern = true, ZR_NAT_Branch = true, ZR_NAT_Reeds = true, ZR_NAT_RockPile = true }
local function clientNeeds(name: string): boolean
	if string.sub(name, 1, 6) == "ZR_MK_" or string.sub(name, 1, 8) == "ZR_PROP_" then
		return false
	end
	if string.sub(name, 1, 7) == "ZR_NAT_" then
		return CLIENT_NAT[name] == true
	end
	return true
end
Assets.clientNeeds = clientNeeds

-- art-4b: a gun piece re-exported with UVs wears its texture sheet (colour, normal, roughness, metalness): the
-- sheet's SurfaceAppearance (ReplicatedStorage.ZR.ZR_GunSA, synced by Rojo; a game script cannot set its maps) is
-- cloned into the library mesh, and every copy GunBuild makes carries it
local GunTex = require(ReplicatedStorage.ZR:WaitForChild("GunTex"))
local function dress(d)
	local sheet = GunTex.pieces[d.Name]
	if not sheet or d:FindFirstChildOfClass("SurfaceAppearance") then
		return
	end
	local sas = ReplicatedStorage.ZR:FindFirstChild("ZR_GunSA")
	local sa = sas and sas:FindFirstChild(sheet)
	if sa then
		sa:Clone().Parent = d
	end
end
Assets.dress = dress

-- put a library mesh where it belongs: always in the server's library, and a copy for clients when they clone it
local function file(d)
	dress(d)
	local l, c = lib(), clientLib()
	if not l:FindFirstChild(d.Name) then
		d.Parent = l
	end
	if clientNeeds(d.Name) and not c:FindFirstChild(d.Name) then
		d:Clone().Parent = c
	end
end

-- meshes inserted into ReplicatedStorage.ZR_Assets at edit time: copied into the server's library, and the ones no
-- client clones taken out of ReplicatedStorage
local function migrate()
	local c, l = clientLib(), lib()
	for _, d in c:GetChildren() do
		if d:IsA("MeshPart") then
			if not l:FindFirstChild(d.Name) then
				d:Clone().Parent = l
			end
			if not clientNeeds(d.Name) then
				d:Destroy()
			end
		end
	end
end

-- load one batch into the library; returns ok, meshes added (pre: a model LoadAsset already fetched for it)
local function loadBatch(entry, pre)
	local l = lib()
	local ok, model = true, pre
	if not model then
		ok, model = pcall(InsertService.LoadAsset, InsertService, entry.id)
	end
	if not ok or not model then
		return false, 0, model
	end
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			local name = (entry.rename and entry.rename[d.Name]) or d.Name
			if not l:FindFirstChild(name) then
				d.Name = name
				d.Anchored = true
				d.Color = Color3.new(1, 1, 1)
				d.Material = Enum.Material.SmoothPlastic
				for _, ch in d:GetChildren() do
					if not ch:IsA("SurfaceAppearance") then
						ch:Destroy()
					end
				end
				file(d)
				n += 1
			end
		end
	end
	model:Destroy()
	if not pre then
		tagFoliage(l)
		tagFoliage(clientLib())
	end
	return true, n
end

function Assets.onLoaded(fn)
	table.insert(listeners, fn)
end

local function fire(key)
	for _, fn in listeners do
		task.spawn(fn, key)
	end
end

function Assets.init(_ctx)
	lib()
	clientLib()
	migrate()
	local loaded, failedN = 0, 0
	local retry = {}
	-- fetch every batch at once, at most 8 at a time (one by one took about 13 s of the server's start-up on 2026-11-07),
	-- then add them to the library in AssetIds order, so a name two batches share still goes to the first
	local entries = {}
	for _, entry in AssetIds do
		table.insert(entries, entry)
	end
	local fetched, pending, running = {}, #entries, 0
	for i, entry in entries do
		while running >= 8 do
			task.wait()
		end
		running += 1
		task.spawn(function()
			local ok, model = pcall(InsertService.LoadAsset, InsertService, entry.id)
			fetched[i] = { ok = ok, model = model }
			running -= 1
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait()
	end
	for i, entry in entries do
		local f = fetched[i]
		local ok, n, err
		if f and f.ok and f.model then
			ok, n, err = loadBatch(entry, f.model)
		else
			ok, n, err = false, 0, f and f.model
		end
		if ok then
			loaded += n
		else
			failedN += 1
			Assets.failed[entry.key] = tostring(err)
			table.insert(retry, entry)
			warn("[ZR] asset load failed", entry.key, entry.id, err)
		end
	end
	tagFoliage(lib())
	tagFoliage(clientLib())
	print(string.format("[ZR] Assets: %d meshes loaded, %d batches failed, library has %d (%d sent to clients)", loaded, failedN,
		#lib():GetChildren(), #clientLib():GetChildren()))
	if #retry > 0 then
		task.spawn(function()
			for _, wait in RETRY do
				task.wait(wait)
				for i = #retry, 1, -1 do
					local entry = retry[i]
					local ok, n = loadBatch(entry)
					if ok then
						table.remove(retry, i)
						Assets.failed[entry.key] = nil
						print(string.format("[ZR] Assets: late load %s (%d meshes)", entry.key, n))
						fire(entry.key)
					end
				end
				if #retry == 0 then
					break
				end
			end
		end)
	end
end

-- test hook: announce that meshes became available (also used after a manual library insert)
function Assets.announce(key)
	fire(key or "manual")
end

function Assets.get(name: string): Instance?
	local l = ServerStorage:FindFirstChild("ZR_Assets")
	return l and l:FindFirstChild(name)
end

return Assets
