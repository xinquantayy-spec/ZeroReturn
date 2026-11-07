--!nonstrict
-- Loads uploaded Blender meshes into ReplicatedStorage.ZR_Assets (MeshParts keyed by name).
-- Meshes already present (inserted at edit time) are kept; missing ones are loaded via InsertService.
-- A batch that fails (a fresh upload can still be processing) is retried in the background a few times; every
-- late success fires the onLoaded callbacks (Appearance reconciles characters that show a fallback).
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local function lib()
	local l = ReplicatedStorage:FindFirstChild("ZR_Assets")
	if not l then
		l = Instance.new("Folder")
		l.Name = "ZR_Assets"
		l.Parent = ReplicatedStorage
	end
	return l
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
				d.Parent = l
				n += 1
			end
		end
	end
	model:Destroy()
	if not pre then
		tagFoliage(l)
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
	print(string.format("[ZR] Assets: %d meshes loaded, %d batches failed, library has %d", loaded, failedN, #lib():GetChildren()))
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
	local l = ReplicatedStorage:FindFirstChild("ZR_Assets")
	return l and l:FindFirstChild(name)
end

return Assets
