--!nonstrict
-- Loads uploaded Blender meshes into ReplicatedStorage.ZR_Assets (MeshParts keyed by name).
-- Meshes already present (inserted at edit time) are kept; missing ones are loaded via InsertService.
-- A batch that fails (a fresh upload can still be processing) is retried in the background a few times; every
-- late success fires the onLoaded callbacks (Appearance reconciles characters that show a fallback).
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetIds = require(ReplicatedStorage:WaitForChild("ZR"):WaitForChild("AssetIds"))

local Assets = {}
local listeners = {}
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

-- load one batch into the library; returns ok, meshes added
local function loadBatch(entry)
	local l = lib()
	local ok, model = pcall(InsertService.LoadAsset, InsertService, entry.id)
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
	for _, entry in AssetIds do
		local ok, n, err = loadBatch(entry)
		if ok then
			loaded += n
		else
			failedN += 1
			Assets.failed[entry.key] = tostring(err)
			table.insert(retry, entry)
			warn("[ZR] asset load failed", entry.key, entry.id, err)
		end
	end
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
