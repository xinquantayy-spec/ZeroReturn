--!nonstrict
-- Loads uploaded Blender meshes into ReplicatedStorage.EFB_Assets (MeshParts keyed by name).
-- Meshes already present (inserted at edit time) are kept; missing ones are loaded via InsertService.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetIds = require(ReplicatedStorage:WaitForChild("EFB"):WaitForChild("AssetIds"))

local Assets = {}

function Assets.init(_ctx)
	local lib = ReplicatedStorage:FindFirstChild("EFB_Assets")
	if not lib then
		lib = Instance.new("Folder")
		lib.Name = "EFB_Assets"
		lib.Parent = ReplicatedStorage
	end
	local loaded, failed = 0, 0
	for _, entry in AssetIds do
		local ok, model = pcall(InsertService.LoadAsset, InsertService, entry.id)
		if ok and model then
			for _, d in model:GetDescendants() do
				if d:IsA("MeshPart") then
					local name = (entry.rename and entry.rename[d.Name]) or d.Name
					if not lib:FindFirstChild(name) then
						d.Name = name
						d.Anchored = true
						d.Color = Color3.new(1, 1, 1)
						d.Material = Enum.Material.SmoothPlastic
						for _, ch in d:GetChildren() do
							if not ch:IsA("SurfaceAppearance") then
								ch:Destroy()
							end
						end
						d.Parent = lib
						loaded += 1
					end
				end
			end
			model:Destroy()
		else
			failed += 1
			warn("[EFB] asset load failed", entry.key, entry.id, model)
		end
	end
	print(string.format("[EFB] Assets: %d meshes loaded, %d batches failed, library has %d", loaded, failed, #lib:GetChildren()))
end

function Assets.get(name: string): Instance?
	local lib = ReplicatedStorage:FindFirstChild("EFB_Assets")
	return lib and lib:FindFirstChild(name)
end

return Assets
