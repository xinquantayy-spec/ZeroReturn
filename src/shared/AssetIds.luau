--!strict
-- Uploaded Blender batches (Roblox Model assets owned by the developer account).
-- Each model contains MeshParts named after their Blender objects; `rename` maps object -> library key.
-- Maintained by the asset pipeline (assets/upload_manifest.json on the dev PC).
return {
	{ key = "ZR_CAL_Crate4", id = 98627364621889, rename = { EFB_CAL_Crate4 = "ZR_PROP_Crate" } }, -- uploaded before the rename
	{ key = "ZR_BatchA", id = 125938077801710 }, -- R-17 viewmodel/mag/arms, TP rifle, container, barrel, pallet, barrier, light pole
	{ key = "ZR_Operator", id = 89318251225515 }, -- operator body: 15 R15-named segments (build_operator.py, RigSpec sizes)
	{ key = "ZR_Gear", id = 75319988582613 }, -- helmet, face plate, plate carrier, pouch, pack, body camera, holster (build_gear.py)
}
