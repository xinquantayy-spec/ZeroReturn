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
| ZR_CharGear | 111486052124640 | M16 equipment, 33 meshes (13,242 tris for the whole batch): helmets, face plate, headsets, mic, gaiter, cap, beanie, hard hat, carrier, pouches, armour collar, soft vest, chest rig, packs, straps, body camera, belt rig, holster, arm guards, outfit overlays, first-person sleeve and cuff. Per-mesh rows: `docs/character/CHARACTER_ASSET_MANIFEST.csv`. | `assets/blender_scripts/build_char_gear.py` |

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
| IMPACT | – | Not made yet |

Sound effects from the Creator Store that turned out to be rips of commercial games were rejected and are not used.

## Textures

Original images from `assets/textures/gen_textures.py`, uploaded as decals; `Textures.luau` holds the image IDs: film grain, lens (old), HUD icon atlas, glow, scope eyepiece, rain streak, splash, lens droplets, vignette v2, edge haze.

M12 (all original and procedural, uploaded as decals; image IDs in code):

- **Worn materials:** `assets/textures/gen_materials.py` makes colour, normal and roughness maps (plus metalness for painted metal) for eight MaterialVariants. Their IDs are in `src/materials/*.model.json`.
  - The roughness maps of worn concrete, concrete panels, plaster, painted metal and asphalt were uploaded again on 2026-10-29, because the first set rendered black in Studio. The new image IDs are 120779423170065, 118230642067713, 109208062124239, 87686061059520 and 109437077250813.
  - The PC's `assets/upload_manifest.json` records the decal assets.
- **Mall materials (M13):** five more MaterialVariants from `gen_materials.py`: terrazzo (Marble base, 16 studs a tile, 4×4 panels with dark joints, chips, traffic wear, cracks), floor tiles (CeramicTiles, 8), ceiling tiles (Plaster, 8, T-grid and water stains), vinyl (Plastic, 8) and worn carpet (Carpet, 8). Image IDs in `src/materials/ZR_Terrazzo|ZR_FloorTiles|ZR_CeilingTiles|ZR_VinylFloor|ZR_CarpetWorn.model.json` (terrazzo and floor tiles are the second version, uploaded 2026-10-29 because the first looked flat in game).
- **Wear decals:** `assets/textures/gen_wear.py` makes 26 overlays: streaks, grime and damp, rust runs, cracks, spalls, peeling paint, soot, oil, ground cracks, wet patches, three graffiti tags of the game's own factions, a stencil, papers, debris, leaves, skid marks, a manhole, chain-link, leaks, floor dust, glass grime and bullet holes. Their IDs are in `src/shared/Wear.luau`.

## Built in code (no asset)

These are built from parts and terrain in `Services/World.luau`:

- the map layout: Harbor Stack, Pump Annex, Freight Depot, pier, relay tower, rail cut, water tower, ferry tunnel
- lighting and grading
- neutral gear stand-ins while an equipment mesh has not loaded (`Services/Appearance.luau`)
- weapons: the shared part-built spec (`WeaponModels.luau`) for first and third person
- grenades in hand and in flight, explosions, smoke (client `Grenade.luau`)
