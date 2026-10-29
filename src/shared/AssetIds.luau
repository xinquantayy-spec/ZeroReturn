--!strict
-- Uploaded Blender batches (Roblox Model assets owned by the developer account).
-- Each model contains MeshParts named after their Blender objects; `rename` maps object -> library key.
-- Maintained by the asset pipeline (assets/upload_manifest.json on the dev PC).
return {
	{ key = "ZR_CAL_Crate4", id = 98627364621889, rename = { EFB_CAL_Crate4 = "ZR_PROP_Crate" } }, -- uploaded before the rename
	{ key = "ZR_BatchA", id = 125938077801710 }, -- R-17 viewmodel/mag/arms, TP rifle, container, barrel, pallet, barrier, light pole
	-- retired in M16 (superseded by ZR_CharBase / ZR_CharGear, no longer loaded): ZR_Operator 89318251225515,
	-- ZR_Gear 75319988582613
	{ key = "ZR_WearKit", id = 122101191158248 }, -- M12 wear kit: 29 cosmetic ZR_WK_* pieces, 9 ZR_PROP_* cover props (build_wear_kit.py)
	{ key = "ZR_CharBase", id = 101424875475699 }, -- M16 block body ZR_BLOCK_R15_V1 (15 ZR_BLK_* segments), helmet A, calibration cube (build_char_base.py)
	{ key = "ZR_CharGear", id = 111486052124640 }, -- M16 equipment: 33 ZR_EQ_* / ZR_OV_* / ZR_FP_* meshes (build_char_gear.py)
	{ key = "ZR_Nature", id = 131399075967241 }, -- M13 nature kit: 20 ZR_NAT_* pines (trunk + crown), rocks, logs, bushes, ground cover (build_nature.py)
	-- M13 Meridian Mall kit (ZR_MK_<Prop>__<material> pieces, see KitMeta.luau and Maps/Kit.luau)
	{ key = "ZR_MallKitA", id = 133338997186647 }, -- structure and fixtures: storefronts, shutters, columns, ceiling holes, balustrades, escalator, fountain, wall breach, collapsed slab, rubble (build_mall_kit_a.py)
	{ key = "ZR_MallKitB", id = 110014146320763 }, -- store furnishings: gondolas, wall shelves, fridges, checkouts, trolleys, kiosks, racks, mannequins, food court, cinema, gym, homewares (build_mall_kit_b.py)
	{ key = "ZR_MallKitC", id = 129684075485706 }, -- back of house and outdoor: pallet racks, cages, lockers, desks, generator, forklift, dock doors, cargo lift, cars, barrier, shelters, rooftop units (build_mall_kit_c.py)
}
