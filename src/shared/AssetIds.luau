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
	{ key = "ZR_EyeGear", id = 77373343248745 }, -- eyewear (2026-11-01): 4 glasses, the gas mask, the goggle head strap and 10 goggle poses (build_eyewear.py)
	{ key = "ZR_Nature", id = 120650690065241 }, -- M13 nature kit: 24 ZR_NAT_* pines and birches (trunk + crown; crowns as needle and leaf cards with foliage-atlas UVs since 2026-11-01), rocks, logs, bushes, ground cover (build_nature.py)
	-- M13 Meridian Mall kit (ZR_MK_<Prop>__<material> pieces, see KitMeta.luau and Maps/Kit.luau)
	{ key = "ZR_MallKitA", id = 133338997186647 }, -- structure and fixtures: storefronts, shutters, columns, ceiling holes, balustrades, escalator, fountain, wall breach, collapsed slab, rubble (build_mall_kit_a.py)
	{ key = "ZR_MallKitB", id = 127419668580872 }, -- (2026-11-08: lighter goods in the dusty palette, audit art.6/art.8; was 110014146320763) store furnishings: gondolas, wall shelves, fridges, checkouts, trolleys, kiosks, racks, mannequins, food court, cinema, gym, homewares (build_mall_kit_b.py)
	{ key = "ZR_MallKitC", id = 129684075485706 }, -- back of house and outdoor: pallet racks, cages, lockers, desks, generator, forklift, dock doors, cargo lift, cars, barrier, shelters, rooftop units (build_mall_kit_c.py)
	-- M13 item models for loose loot (ZR_IT_<item>__<material> pieces, see ItemMeta.luau; build_items_export.py)
	{ key = "ZR_ItemsA", id = 91684040376497 }, -- magazines, ammunition, grenades, weapon mods, repair kit, secure containers
	{ key = "ZR_ItemsB", id = 104263145712235 }, -- medicine, food and drink, keys and keycards, quest items
	{ key = "ZR_ItemsC", id = 125911946207153 }, -- valuables and barter goods
	-- M14 guns as parts (ZR_WP_<part>__<material> pieces, origin at the attach point; see GunMeta.luau, build_guns_all.py)
	{ key = "ZR_GunsAR", id = 130670418678516 }, -- R-17 receiver, uppers, barrels, gas blocks, handguards, stocks, grips, charging handles, sights, muzzle devices, magazines
	{ key = "ZR_GunsAK", id = 92833064438128 }, -- Kestrel KS-7 receiver, dust covers, handguards, stocks, grips, muzzle devices, side mount, magazines
	{ key = "ZR_GunsSMG", id = 106931227232196 }, -- Sparrow SMG-9 receiver, handguards, stocks, grips, claw mount, magazines
	{ key = "ZR_GunsSG", id = 70558979775509 }, -- Harrow-12 receiver, barrels, tubes, forends, stocks, chokes and brake
	{ key = "ZR_GunsBolt", id = 80035562450165 }, -- Tundra receiver, stocks, mounts, muzzle devices
	{ key = "ZR_GunsPistol", id = 99358645164066 }, -- P-9 frame, slides, barrels, compensator, magazines
	{ key = "ZR_GunsMods", id = 131071003311039 }, -- shared parts: sights and scopes, mounts, foregrips, lights and lasers, suppressors
	-- Relay 7 lobby bunker kit (ZR_MK_<Prop>__<material> pieces like the mall kit; see KitMeta.luau, Maps/Relay7.luau)
	{ key = "ZR_BunkerKitA", id = 126010320295919 }, -- shell and services: blast door, door frames, pipes and valves, cable trays, beams, ducts, lamps, boxes, safety kit, sandbags, rubble (build_bunker_kit_a.py)
	{ key = "ZR_BunkerKitB", id = 100322751912819 }, -- rooms and stations: bunks, lockers, mirror sink, map table, boards, trader counters, gun racks, armour stands, hideout modules, range booth and targets (build_bunker_kit_b.py)
	{ key = "ZR_BunkerKitC", id = 100282091818165 }, -- motor pool: van and its two rear door leaves, ramp, roller door, manhole, sign post, tool chest, tyres, jerry cans, work light, hose reel, oil stain (build_bunker_kit_c.py)
}
