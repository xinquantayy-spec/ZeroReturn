# Asset Manifest

Every asset is original or licensed for Roblox use. There are no ripped or third-party game assets.

The upload record, including hashes, is `assets/upload_manifest.json`. On the PC it is written by `zr_upload.py`.

## Meshes

All meshes were built with Blender scripts. They are vertex-coloured, untextured and owned by user 5437527887.

| Upload key | Asset ID | Contents | Source script |
|---|---|---|---|
| ZR_BatchA | 125938077801710 | ZR_VM_R17 (680 tris), ZR_VM_R17_Mag, ZR_VM_Arms, ZR_WPN_R17_TP, ZR_ENV_Container20, ZR_PROP_Barrel, ZR_PROP_Pallet, ZR_PROP_Barrier, ZR_PROP_LightPole | `assets/blender_scripts/build_batch_a.py` |
| EFB_CAL_Crate4 | 98627364621889 | Calibration crate. Renamed at runtime to `ZR_PROP_Crate`. | Calibration export (pre-rename) |

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
| IMPACT | – | Not made yet |

Sound effects from the Creator Store that turned out to be rips of commercial games were rejected and are not used.

## Built in code (no asset)

These are built from parts and terrain in `Services/World.luau`:

- the map layout: Harbor Stack, Pump Annex, Freight Depot, pier, relay tower, rail cut, water tower, ferry tunnel
- lighting and grading
- gear visuals: helmet, visor, vest, pouches, bodycam, pack (`Services/Chars.luau`)
