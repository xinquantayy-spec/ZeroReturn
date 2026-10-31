--!nonstrict
-- An item's 3D model from its Blender pieces, shared by loose loot (server, Loot.luau) and the INSPECT window
-- (client, Inspect.luau): guns and gun parts from their parts as they are put together, other items from their
-- ItemMeta pieces, worn gear from the character meshes. Pieces come from ReplicatedStorage.ZR_Assets.
local Shared = script.Parent
local Items = require(Shared.Items)
local WeaponModels = require(Shared.WeaponModels)
local GunBuild = require(Shared.GunBuild)
local ItemMeta = require(Shared.ItemMeta)
local Equipment = require(Shared.Equipment)
local AssetMeta = require(Shared.AssetMeta)

local ItemModel = {}
local M = Enum.Material
-- item model material key (build_items_*.py) -> Roblox material, reflectance, transparency
local IT_MAT = {
	metal = { M.Metal }, gunmetal = { M.Metal }, brass = { M.Metal, 0.05 }, copper = { M.Metal, 0.05 }, gold = { M.Foil, 0.08 },
	chrome = { M.Metal, 0.15 }, plastic = { M.SmoothPlastic }, polymer = { M.Plastic }, rubber = { M.Rubber }, fabric = { M.Fabric },
	leather = { M.Leather }, paper = { M.SmoothPlastic }, cardboard = { M.Cardboard }, wood = { M.Wood }, ceramic = { M.SmoothPlastic, 0.02 },
	glass = { M.Glass, 0.05, 0.45 }, emissive = { M.Neon }, foil = { M.Foil },
}
-- worn equipment lying around: which slot shows it, and how it lies (armour and rigs front up)
local WEAR_SLOT = { helmet = "head", headwear = "head", headset = "ears", facecover = "face", armor = "armor", rig = "rig", backpack = "back" }
local WEAR_LIE = { armor = CFrame.Angles(-math.pi / 2, 0, 0), rig = CFrame.Angles(-math.pi / 2, 0, 0) }

local function assetLib()
	return game:GetService("ReplicatedStorage"):FindFirstChild("ZR_Assets")
end

function ItemModel.quiet(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
end

-- the item's Blender model (ItemMeta pieces) at surface cf; returns its bounding box (size, centre CFrame) or nil
function ItemModel.placeMeta(model, id, cf)
	local meta = ItemMeta[id]
	local lib = assetLib()
	if not meta or not lib then
		return nil
	end
	local n = 0
	for _, pc in meta.pieces do
		local src = lib:FindFirstChild("ZR_IT_" .. id .. "__" .. pc[1])
		if src then
			local p = src:Clone()
			ItemModel.quiet(p)
			local mm = IT_MAT[pc[1]] or IT_MAT.plastic
			p.Material = mm[1]
			p.Reflectance = mm[2] or 0
			p.Transparency = mm[3] or 0
			p.Color = Color3.new(1, 1, 1)
			p.CastShadow = meta.size.Magnitude > 0.5 and pc[1] ~= "glass"
			p.CFrame = cf * CFrame.new(pc[2])
			p.Parent = model
			n += 1
		end
	end
	if n == 0 then
		return nil
	end
	return meta.size, cf * CFrame.new(meta.center)
end

-- worn equipment: the same meshes the characters wear, tinted, lying on the surface
function ItemModel.placeWear(model, d, cf)
	local slot = WEAR_SLOT[d.kind]
	local vis = slot and Equipment.visualOf(slot, d.id)
	local lib = assetLib()
	if not vis or not lib then
		return nil
	end
	local host = vis.pieces[1] and vis.pieces[1].host
	local lie = WEAR_LIE[d.kind] or CFrame.new()
	local parts, lo, hi = {}, nil, nil
	for _, pc in vis.pieces do
		local src = pc.host == host and lib:FindFirstChild(pc.key)
		if src then
			local off = AssetMeta[pc.key] or Vector3.zero
			table.insert(parts, { src = src, off = off, pc = pc })
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local c = (lie * CFrame.new(off + src.Size * 0.5 * Vector3.new(sx, sy, sz))).Position
						lo = lo and lo:Min(c) or c
						hi = hi and hi:Max(c) or c
					end
				end
			end
		end
	end
	if #parts == 0 then
		return nil
	end
	-- the host frame sits so that the lowest corner touches the surface, centred over the spot
	local mid = (lo + hi) / 2
	local base = cf * CFrame.new(-mid.X, -lo.Y, -mid.Z) * lie
	for _, e in parts do
		local p = e.src:Clone()
		ItemModel.quiet(p)
		p.Color = e.pc.tint and Color3.fromHex(e.pc.tint) or Color3.new(1, 1, 1)
		p.Material = (e.pc.mat and Enum.Material[e.pc.mat]) or M.SmoothPlastic
		p.CastShadow = true
		p.CFrame = base * CFrame.new(e.off)
		p.Parent = model
	end
	return hi - lo, cf * CFrame.new(0, (hi.Y - lo.Y) / 2, 0)
end

-- guns and gun parts (weapons, parts, magazines): their Blender parts as they are put together in frame `lie`;
-- a list of unparented parts, or nil for other items
function ItemModel.gunPieces(items, g, lie)
	local it = items[g]
	local d = it and Items.defs[it.id]
	if not d then
		return nil
	end
	if d.kind == "weapon" or d.kind == "pistol" then
		local wspec = WeaponModels.build(items, it, lie, 1)
		if wspec then
			local pieces = {}
			for _, p in wspec.parts do
				table.insert(pieces, p)
			end
			for _, p in wspec.mag do
				table.insert(pieces, p)
			end
			return pieces
		end
	elseif d.kind == "mod" or d.kind == "mag" then
		return GunBuild.pieces(items, g, lie, 1)
	end
	return nil
end
ItemModel.bounds = GunBuild.bounds

return ItemModel
