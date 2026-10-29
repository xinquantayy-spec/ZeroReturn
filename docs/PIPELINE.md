# Zero Return: Build and Asset Pipeline

## Source of truth and sync

- **Code.** The Rojo project is `default.project.json` (project name `ZeroReturn`, serve port **34873**).

  | Source folder | Synced into Studio as |
  |---|---|
  | `src/shared` | `ReplicatedStorage.ZR` |
  | `src/server` | `ServerScriptService.ZRServer` |
  | `src/client` | `StarterPlayerScripts.ZRClient` |

  Never hand-edit synced scripts in Studio. Rojo overwrites them.
- **Serving.** On the dev PC, run `rojo serve --port 34873` from `Documents\EscapeFromBloxov`. Rojo 7.7.1 is pinned in `rokit.toml`.
- **Playtests.** A playtest copies the Edit DataModel when it starts. To test new code, stop play, let Rojo sync, then start play again.
- **When Claude edits from the cloud workspace,** the steps are:
  1. Write the files.
  2. Run `python3 tools/luau_check.py src`.
  3. Run `python3 tools/stage_sync.py`. Each run stages into its own unique folder.
  4. `device_commit_files` copies the staged files onto the PC.
  5. Run `python3 tools/stage_sync.py --commit` to mark them as synced.
- **Files only the PC writes.** `assets/upload_manifest.json` is written by Blender on the PC. It is never pushed from the cloud; copy it back from the PC instead.

## Blender meshes (Blender MCP, Python)

**Conventions**

- 1 Blender unit = 1 stud.
- Blender −Y is the front, which becomes Roblox −Z. Coordinates convert as Blender (x, y, z) → Roblox (−x, z, y).
- **Origins:** props use bottom-centre; viewmodel parts use the grip point.
- **Colour:** vertex colours go in a `Col` corner attribute through the shared `ZR_M_VertexPalette` material. There are no textures. In Roblox the MeshPart colour is white, or a tint that multiplies the vertex colours.
- **Export:** FBX with apply_unit_scale, FBX_SCALE_UNITS, forward −Z, up Y, sRGB colours.
- **Shared code:** `zr_lib.py` holds the shared helpers: `Builder` (box, cyl, prism, ao, finish), `batch_scene`, `meta_for` and `export_batch`.

**Build a batch.** In Blender, run:

```python
g = {}; exec(open(r"<project>/assets/blender_scripts/build_batch_a.py").read(), g)
```

- This builds the batch in its own scene, `ZR_Assets`; the user's open scene is never reset.
- It writes `assets/exports/ZR_BatchA.fbx`, the `.blend` source and `.meta.json`.

**Upload.** In Blender, run:

```python
g = {}; exec(open(PATH_TO_zr_upload.py).read(), g); g["upload_model"](fbx, "ZR_BatchA")
```

- The Open Cloud API key is read from `%USERPROFILE%\efb_opencloud_key.txt`. It is never printed, copied or committed.
- Uploads are skipped when a file's SHA-1 is unchanged.

**Use in game.**

1. Add the asset ID to `src/shared/AssetIds.luau`.
2. Add each mesh's centre offset from `.meta.json` to `src/shared/AssetMeta.luau`.

`Services/Assets.luau` loads the meshes at runtime through InsertService, and `World.mesh()` places them using those offsets.

**Materials on meshes (measured 2026-10-29, `ZR_UVTest` probe).**

- A Roblox material (or MaterialVariant) on a MeshPart tiles at a fixed number of studs per texture, like on a
  Part. The mesh's UVs and the MeshPart's scale do not change it: a plane with UVs at 4 studs per unit, one at 8,
  and the same plane resized to half size all showed the same brick size as an 8x8 Part.
- Vertex colours multiply the material texture, so baked ambient occlusion and grime show on top of it.
- So kit meshes need no UVs and no textures of their own. Each prop is split by material into separate objects
  that share one origin (`<Name>__<material>`, for example `ZR_MK_Checkout__metal`). In game each piece gets its
  Roblox material and, where one fits, a MaterialVariant, with the colour coming from the vertex colours.
  Every prop gets the same texel density, and props share the material textures that are already loaded.

**Surface materials.** Big flat surfaces (floors, walls, ceilings) are Parts with MaterialVariants made by
`assets/textures/gen_materials.py` (colour at 1024, normal, roughness and metalness at 512). The images are
uploaded as Decals (`upload_model(png, key, desc, asset_type="Decal")`); the image id is read in Studio from the
Decal (`InsertService:LoadAsset(decalId)`, then `Decal.Texture`) and written to `src/materials/<name>.model.json`.
A texture with grid lines (tiles, ceiling grid) uses `MaterialPattern = "Regular"`.

**Item models and pictures.** Every item is modelled once (`build_items_a/b/c.py` on `zr_items.py`). The same
model is rendered to the inventory picture, which is packed into two atlas sheets uploaded as Decals; and it is
exported with baked AO for the loose loot (three Model batches). Generated tables are `ItemIcons.luau`
(`tools/item_icons.py`) and `ItemMeta.luau` (`tools/item_meta.py`). Full steps: `docs/items/ITEM_ART.md`.

## Audio

1. **Generate.** Run `python3 assets/audio/synth_sfx.py assets/audio/out`. It needs numpy, scipy and ffmpeg. The sounds are fully procedural, with no samples.
2. **Upload.** In Blender, run `g["upload_audio_dir"](<project>/assets/audio/out)`. This uploads each sound as an Audio asset (`audio/ogg`).
   - Accounts without ID verification can upload about 10 audio assets per month.
3. **Wire up.** Put the IDs in `src/shared/Sounds.luau`. Then confirm they load with `ContentProvider:PreloadAsync` in a Client playtest.

## Testing (Studio)

**Server bridge.** Call `game.ServerStorage.ZR_Dev:Invoke(cmd, playerName?, a, b)` from Server `execute_luau`.

| Command | What it does |
|---|---|
| `tests` | Logic suite. Baseline is 38/38. |
| `state` | JSON snapshot |
| `deploy`, `tp`, `loot`, `take`, `extract`, `kill`, `expire` | Drive the raid loop |
| `rejoin`, `crash`, `saveRetry`, `failWrites` | Persistence probes |
| `dispatch`, `shotAbuse`, `takeTwice` | Exploit probes |
| `ignore` | Guards stop targeting the player |
| `ai` | Guard states |

**Client bridge.** Call `PlayerScripts.ZR_ClientDev:Invoke(cmd, a)` with `state`, `fire`, `reload`, `inv`, `deployScreen`, `closeModal`, `settings`, `aim` or `look`.

**Real input.** UI buttons are named `Btn_<TEXT>`. Click them with `user_mouse_input` by instance path, for example `LocalPlayer.PlayerGui.ZR_Screens.Modal.Row.Btn_DEPLOY`.

Both bridges exist only when `RunService:IsStudio()` is true.

## Backup

The git history lives in the cloud workspace. A bundle snapshot is copied to `backup/ZeroReturn.gitbundle` on the PC. To restore it, run `git clone ZeroReturn.gitbundle ZeroReturn`.
