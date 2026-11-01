# Asset Manifest

Every asset is original or licensed for Roblox use. There are no ripped or third-party game assets.

The upload record, including hashes, is `assets/upload_manifest.json`. On the PC it is written by `zr_upload.py`.

## Meshes

All meshes were built with Blender scripts. They are vertex-coloured, untextured and owned by user 5437527887. The M16 character batches also keep their `.blend` sources (`assets/blender_sources/`) and FBX exports (`assets/exports/`) in the repo; hashes are in the character manifest.

| Upload key | Asset ID | Contents | Source script |
|---|---|---|---|
| ZR_BatchA | 125938077801710 | ZR_VM_R17 (680 tris), ZR_VM_R17_Mag, ZR_VM_Arms, ZR_WPN_R17_TP, ZR_ENV_Container20, ZR_PROP_Barrel, ZR_PROP_Pallet, ZR_PROP_Barrier, ZR_PROP_LightPole | `assets/blender_scripts/build_batch_a.py` |
| EFB_CAL_Crate4 | 98627364621889 | Calibration crate. Renamed at runtime to `ZR_PROP_Crate`. | Calibration export (pre-rename) |
| ZR_Operator | 89318251225515 | Retired in M16 (no longer loaded). The pre-M16 operator body (`ZR_OP_*`). | `assets/blender_scripts/build_operator.py` |
| ZR_Gear | 75319988582613 | Retired in M16 (no longer loaded). Pre-M16 gear (`ZR_GEAR_*`). | `assets/blender_scripts/build_gear.py` |
| ZR_WearKit | 122101191158248 | M12 wear kit: 29 cosmetic `ZR_WK_*` pieces (client detail layer) and 9 `ZR_PROP_*` cover props (28 placed on Quay 7 since 2026-10-29) | `assets/blender_scripts/build_wear_kit.py` |
| ZR_CharBase | 101424875475699 | M16 block body ZR_BLOCK_R15_V1 (15 `ZR_BLK_*` segments, 3,880 tris), helmet A (952), calibration cube | `assets/blender_scripts/build_char_base.py` |
| ZR_MallKitA | 133338997186647 | M13 Meridian Mall structure and fixtures, 20 props: storefronts (whole and broken), shutters (closed, half, bent), columns (whole, damaged), ceiling hole, ceiling collapse, ceiling debris, balustrades (whole, broken), escalator, fountain with ring sculpture, wall breach, collapsed slab, broken edge, rubble, glass shards. Each prop is one `ZR_MK_<Prop>__<material>` mesh per material sharing an origin. | `assets/blender_scripts/build_mall_kit_a.py` (shared code `zr_kit.py`) |
| ZR_MallKitB | 110014146320763 | M13 store furnishings, 42 props: gondolas (full, sparse, toppled), wall shelves (stocked, sparse, medicine, books, tools), fridges (dead, broken), checkout, trolleys (single, tipped, row), kiosks (whole, burnt), clothes racks, mannequins, display table, TV wall, tech table, food court tables and counter, cinema rows (whole, torn), ticket booth, bench, planter, bin, vending (whole, broken), ATM, arcade, treadmill, weight rack, sofa, bed, jewellery case, ball pit. | `assets/blender_scripts/build_mall_kit_b.py` |
| ZR_MallKitC | 129684075485706 | M13 back of house and outdoors, 24 props: pallet racks and boxes, roll cage, storage shelves, lockers, office and CCTV desks, electric cabinet, generator, forklift, dock doors (closed, open), cargo lift, three cars, parking barrier, bus shelter, trolley bay, rooftop HVAC, projector, cardboard pile, hoarding. | `assets/blender_scripts/build_mall_kit_c.py` |
| ZR_BunkerKitA | 126010320295919 | Lobby structure and fittings, 23 props: blast door, door frame, pipe runs and valve, cable tray, beam, duct, fluorescent fittings (lit, dead), cage lamps, vent, junction and fuse boxes, extinguisher, first aid, wall phone, speaker, clock, sandbags, rubble. | `assets/blender_scripts/build_bunker_kit_a.py` |
| ZR_BunkerKitB | 100322751912819 | Lobby furnishings and stations, 33 props: bunks, lockers, mirror sink, map table, departure board, whiteboard, cork board, insurance window, counter, gun rack, pegboard, medicine case, armour and rig stands, pigeonholes, Fence stall, hideout modules, gun bench, range booth, steel plate, paper target, range display, table, chair, ammo crate, drum. | `assets/blender_scripts/build_bunker_kit_b.py` |
| ZR_BunkerKitC | 100282091818165 | Lobby motor pool, 13 props: armoured van and its two rear door leaves, ramp, roller door, manhole, sign post, tool chest, tyres, jerry cans, work light, hose reel, oil stain. | `assets/blender_scripts/build_bunker_kit_c.py` |
| ZR_CharGear | 111486052124640 | M16 equipment, 33 meshes (13,242 tris for the whole batch): helmets, face plate, headsets, mic, gaiter, cap, beanie, hard hat, carrier, pouches, armour collar, soft vest, chest rig, packs, straps, body camera, belt rig, holster, arm guards, outfit overlays, first-person sleeve and cuff. Per-mesh rows: `docs/character/CHARACTER_ASSET_MANIFEST.csv`. | `assets/blender_scripts/build_char_gear.py` |
| ZR_ItemsA | 91684040376497 | M13 loose loot models, 33 items in 75 meshes (18,912 tris): weapon mods, magazines, ammunition, grenades, repair kit, secure containers. One `ZR_IT_<ITEM>__<material>` mesh per material, AO baked in. | `assets/blender_scripts/build_items_a.py`, `build_items_b.py` (secure containers), export `build_items_export.py` |
| ZR_ItemsB | 104263145712235 | M13 loose loot models, 29 items in 77 meshes (7,814 tris): medical, food and drink, keys and keycards, the two quest items. | `assets/blender_scripts/build_items_c.py`, export `build_items_export.py` |
| ZR_ItemsC | 125911946207153 | M13 loose loot models, 33 items in 83 meshes (17,538 tris): electronics, valuables, tools, household goods, parts, intel, dog tag. | `assets/blender_scripts/build_items_c.py`, export `build_items_export.py` |
| ZR_GunsAR | 130670418678516 | M14 R-17 as parts: receiver, upper, three barrels, two gas blocks, three handguards, stocks, grips, charging handles, iron sights, muzzle devices, magazines. One `ZR_WP_<PART>__<material>` mesh per material, origin at the attach point, AO and edge wear baked. | `assets/blender_scripts/guns_r17.py` (shared `zr_guns.py`, run by `build_guns_all.py`) |
| ZR_GunsAK | 92833064438128 | M14 KS-7 as parts: receiver, dust covers, handguards, stocks, grips, rear sight, muzzle devices, side mount, magazines. | `assets/blender_scripts/guns_kst.py` |
| ZR_GunsSMG | 106931227232196 | M14 SMG-9 as parts: receiver, handguards, stocks, trigger groups, flash hider, claw mount, magazines. | `assets/blender_scripts/guns_spr.py` |
| ZR_GunsSG | 70558979775509 | M14 Harrow-12 as parts: receiver, barrels, magazine tubes, forends, stocks, choke and brake. | `assets/blender_scripts/guns_har.py` |
| ZR_GunsBolt | 80035562450165 | M14 Tundra as parts: action, stocks, mounts, muzzle devices. | `assets/blender_scripts/guns_tun.py` |
| ZR_GunsPistol | 99358645164066 | M14 P-9 as parts: frame, slides, barrels, compensator, magazines. | `assets/blender_scripts/guns_p9.py` |
| ZR_GunsMods | 131071003311039 | M14 shared parts: reflex, holographic and compact sights, 4x, 1-6x and 8x scopes, mounts, foregrips, light and lasers, suppressors. | `assets/blender_scripts/guns_mods.py` |

How meshes load and are placed:

- The runtime loads them with `InsertService:LoadAsset` into `ReplicatedStorage.ZR_Assets` (`Services/Assets.luau`).
- `AssetMeta.luau` holds each mesh's bounding-box centre offset, measured in Roblox space.
- Props use a bottom-centre origin. Viewmodel parts use a grip origin.

## Audio

| Key | Asset ID | Origin |
|---|---|---|
| R17_FIRE | 125276898958159 | Original. Procedural (`assets/audio/synth_sfx.py`). |
| R17_FIRE_FAR | 72578681964971 | Original. Procedural, low-passed with a long outdoor tail. |
| DRY_FIRE | 119000594646513 | Original. Procedural click. |
| RELOAD | 102400197652572 | Original. Procedural sequence: release, slide, seat, bolt. |
| HIT (also UI_CLICK) | 126592306693188 | Original. Procedural tick. |
| EXTRACT_BEEP | 120970680447327 | Original. Procedural 880 Hz double beep. |
| AMBIENCE | 9112829678 | "Marina Ambience 5 (SFX)" by ProSoundEffects, from Roblox's licensed audio library. |
| ATLAS (ZR_SFX_Atlas) | 117513374968391 | Original. 52 short effects played by region (`synth_atlas.py`, `SoundAtlas.luau`). |
| ENV_ATLAS (ZR_SFX_Env) | 111806710801040 | Original. Rain, roof rain, wind and insect loops; gusts, thunder, gulls, horn, creaks, doors, keys, pickup, UI (`synth_env.py`, `EnvAtlas.luau`). |
| COMBAT_ATLAS (ZR_SFX_Combat) | 129340593261177 | Original. Grenade pin, lever, throw, bounces, near/far explosions, debris, stun bang, smoke pop and hiss loop, tinnitus loop, misfire click, stoppage clearing, jam, repair kit (`synth_combat.py`, `CombatAtlas.luau`). |
| AMB_ATLAS (ZR_SFX_Amb) | 100848289442450 | Original, made and uploaded 2026-11-01. Mall room tone, mains hum, car park tone, three drips, three distant gunfire bursts, the IRONSIGHT siren, the generator loop (`synth_amb.py`, `AmbAtlas.luau`; `assets/audio/out/ZR_SFX_Amb.ogg`, 698 KB, 70.74 s). Set in `Sounds.AMB_ATLAS`; `docs/look/ATMOSPHERE.md`. |
| IMPACT | – | Not made yet |

Sound effects from the Creator Store that turned out to be rips of commercial games were rejected and are not used.

## Textures

Original images from `assets/textures/gen_textures.py`, uploaded as decals; `Textures.luau` holds the image IDs: film grain, lens (old), HUD icon atlas, glow, scope eyepiece, rain streak, splash, lens droplets, vignette v2, edge haze.

M12 (all original and procedural, uploaded as decals; image IDs in code):

- **Worn materials:** `assets/textures/gen_materials.py` makes colour, normal and roughness maps (plus metalness for painted metal) for eight MaterialVariants. Their IDs are in `src/materials/*.model.json`.
  - The roughness maps of worn concrete, concrete panels, plaster, painted metal and asphalt were uploaded again on 2026-10-29, because the first set rendered black in Studio. The new image IDs are 120779423170065, 118230642067713, 109208062124239, 87686061059520 and 109437077250813.
  - The PC's `assets/upload_manifest.json` records the decal assets.
- **Mall materials (M13):** five more MaterialVariants from `gen_materials.py`: terrazzo (Marble base, 16 studs a tile, 4×4 panels with dark joints, chips, traffic wear, cracks), floor tiles (CeramicTiles, 8), ceiling tiles (Plaster, 8, T-grid and water stains), vinyl (Plastic, 8) and worn carpet (Carpet, 8). Image IDs in `src/materials/ZR_Terrazzo|ZR_FloorTiles|ZR_CeilingTiles|ZR_VinylFloor|ZR_CarpetWorn.model.json` (terrazzo and floor tiles are the second version, uploaded 2026-10-29 because the first looked flat in game).
- **Item pictures (M13, redone in M14):** Blender renders of all 214 items (the 124 from M13 plus the M14 weapon parts and magazines; `zr_items.py`, `build_items_*.py`, `build_guns_all.py`), packed 64 px per grid cell into three 1024 × 1024 sheets uploaded as decals; image IDs 87867732430143, 113186498772250 and 89528084000387. The IDs and each item's rectangle are in `src/shared/ItemIcons.luau` (generated by `tools/item_icons.py`). See `docs/items/ITEM_ART.md`.
- **Gun part sprites (M14):** a side view of every weapon part at one scale per picture class (long guns 5.5 cells a metre, pistols 7), with turned versions for side-rail devices, packed into one sheet (image 105623866578178). Inventory tiles put a gun's picture together from these. Rectangles and origins are in `src/shared/GunMeta.luau` (generated by `tools/gun_meta.py`). See `docs/weapons/WEAPON_MODDING.md`.
- **Foliage atlas (2026-11-01):** `assets/textures/gen_foliage.py` makes one 1024 × 1024 RGBA atlas of four branch sprays (spruce dark, spruce young, birch leaves, shrub leaves), uploaded as a Decal (asset 77955732744737, image 108334554762066). The image is on the SurfaceAppearance template `src/shared/ZR_FoliageSA.model.json`; the crown and bush cards of `ZR_Nature` (120650690065241) carry UVs into it.
- **Wear decals:** `assets/textures/gen_wear.py` makes 26 overlays: streaks, grime and damp, rust runs, cracks, spalls, peeling paint, soot, oil, ground cracks, wet patches, three graffiti tags of the game's own factions, a stencil, papers, debris, leaves, skid marks, a manhole, chain-link, leaks, floor dust, glass grime and bullet holes. Their IDs are in `src/shared/Wear.luau`.

## Built in code (no asset)

These are built from parts and terrain in `Services/World.luau`:

- the map layout: Harbor Stack, Pump Annex, Freight Depot, pier, relay tower, rail cut, water tower, ferry tunnel
- lighting and grading
- neutral gear stand-ins while an equipment mesh has not loaded (`Services/Appearance.luau`)
- weapons: the shared part-built spec (`WeaponModels.luau`) for first and third person
- grenades in hand and in flight, explosions, smoke (client `Grenade.luau`)
