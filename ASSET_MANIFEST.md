# Asset Manifest

Every asset is original or licensed for Roblox use. There are no ripped or third-party game assets.

The upload record, including hashes, is `assets/upload_manifest.json`. On the PC it is written by `zr_upload.py`.

## Meshes

All meshes were built with Blender scripts. They are vertex-coloured, untextured and owned by user 5437527887.

| Upload key | Asset ID | Contents | Source script |
|---|---|---|---|
| ZR_BatchA | 125938077801710 | ZR_VM_R17 (680 tris), ZR_VM_R17_Mag, ZR_VM_Arms, ZR_WPN_R17_TP, ZR_ENV_Container20, ZR_PROP_Barrel, ZR_PROP_Pallet, ZR_PROP_Barrier, ZR_PROP_LightPole | `assets/blender_scripts/build_batch_a.py` |
| EFB_CAL_Crate4 | 98627364621889 | Calibration crate. Renamed at runtime to `ZR_PROP_Crate`. | Calibration export (pre-rename) |
| ZR_Operator | 89318251225515 | Operator body: 15 R15-named segments (`ZR_OP_*`) on the RigSpec sizes | `assets/blender_scripts/build_operator.py` |
| ZR_Gear | 75319988582613 | ZR_GEAR_Helmet, FacePlate, Vest, Pouch, Pack, BodyCam, Holster (tinted per faction at runtime) | `assets/blender_scripts/build_gear.py` |

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

## Built in code (no asset)

These are built from parts and terrain in `Services/World.luau`:

- the map layout: Harbor Stack, Pump Annex, Freight Depot, pier, relay tower, rail cut, water tower, ferry tunnel
- lighting and grading
- gear fallbacks when a mesh cannot load, and the soft cap (`Services/Chars.luau`)
- weapons: the shared part-built spec (`WeaponModels.luau`) for first and third person
- grenades in hand and in flight, explosions, smoke (client `Grenade.luau`)
