# Character work — tool audit (C0) and rig/helmet round trip (C1)

Recorded 2026-10-28 for the character brief (`CLAUDE_CHARACTER_MODELING_PROMPT.md`, kit folder). The game is
named **Zero Return** in code and UI (the kit calls it Escape From Bloxov). Everything below was observed through
the tools named; nothing here is inferred from a tool's label.

## Environment

| Item | Value | How it was confirmed |
|---|---|---|
| Dev PC | Windows (win32 x64), Claude desktop app 4.29.0, linked to this session | `get_device_info` |
| Project folder | `C:\Users\lenovo\Documents\EscapeFromBloxov` (git, local commits only) | `get_device_info.connectedFolders` |
| Kit folder | `C:\Users\lenovo\Documents\ChatGPT\brainstorm\EscapeFromBloxov_ClaudeCode_Kit` (read only) | same |
| Blender | 5.2.3 LTS, Python 3.13, user's scene `Scene` kept active; batches build in their own scenes (`ZR_CharBase`, `ZR_CharGear`, `ZR_Preview`) | `execute_blender_code` (`bpy.app.version_string`) |
| Roblox Studio | 0.745.0.7451137, one instance: `Zero Return.rbxl` (id `d83bf6df-…`), place unpublished | `list_roblox_studios`, `execute_luau` (`version()`) |
| Rojo | 7.7.1, `rojo serve` on port 34873 (`default.project.json`: `src/shared` → `ReplicatedStorage.ZR`, `src/server` → `ServerScriptService.ZRServer`, `src/client` → `StarterPlayerScripts.ZRClient`, `src/materials` → `MaterialService`) | Studio readback of synced sources |
| Build marker | `Config.BUILD = "0.8.0-m11a"`, `RigSpec.bodyVersion = "ZR_BLOCK_R15_V1"` read back from the Edit datamodel after a Rojo sync | `execute_luau` (Edit) |

## MCP capabilities actually exercised

| Capability | Tool | Result |
|---|---|---|
| Run Python in the live Blender | `blender.execute_blender_code` | works; calls longer than 60 s time out on the bridge but keep running |
| Export FBX from a batch scene | `zr_lib.export_batch` (Blender `export_scene.fbx`: `use_selection`, `apply_unit_scale`, `FBX_SCALE_UNITS`, axis forward −Z / up Y, face smoothing, sRGB vertex colours, no leaf bones) | works |
| Upload a local FBX / PNG | Open Cloud Assets API called from Blender (`zr_upload.py`), key read from `C:\Users\lenovo\efb_opencloud_key.txt` (never printed or committed) | works; fresh uploads can return HTTP 502 / "being generated" for a few minutes |
| Import into Studio | `InsertService:LoadAsset(id)` in Edit and Server datamodels | works for the user's own uploads |
| Edit Luau | Rojo file sync (files written into the project folder through `device_commit_files`) | works; MCP `multi_edit` is available but not used for Rojo-owned files |
| Play / stop | `Roblox_Studio.start_stop_play` | works (single local client + server) |
| Screenshots | `Roblox_Studio.screen_capture`, Blender EEVEE renders (`zr_preview.py`) | works |
| Logs | `Roblox_Studio.get_console_output` | works |
| Multiple test clients | none found (no team-test / multi-client tool in this MCP) | **BLOCKED**: multi-client checks are run as server-side observers instead and labelled as such |
| Device emulation | none exposed through MCP | **BLOCKED** (manual Studio emulator only) |

## C1 evidence: calibration probe and rig + helmet round trip

1. **Calibration cube** (`build_char_base.py` → `ZR_CAL_Cube2`, 2 × 2 × 2 with a FRONT bump on −Z and a RIGHT bump
   on +X). Imported through the batch asset; measured MeshPart size 2.1 × 2.0 × 2.2 (bumps included) and centre
   equal to origin + (0.05, 1.0, −0.1), matching `ZR_CharBase.meta.json`. The red FRONT marker faces −Z
   (character front) and the green RIGHT marker faces +X. Axis mapping Roblox (x, y, z) = Blender (−x, z, y), 1 Blender
   unit = 1 stud, no scale factor. Evidence: `evidence/C01_calibration_cube_studio.jpg`.
2. **Block body `ZR_BLOCK_R15_V1`** (15 R15-named segments, Motor6D joints kept, procedural RigMath animation kept).
   Source of truth `tools/rig_def.py` → `src/shared/RigSpec.luau` + `assets/blender_scripts/rig_spec.json`.
   Every imported `ZR_BLK_*` MeshPart size matched its RigSpec part size. Body ≈ 3.9 k triangles.
3. **Helmet A** (`ZR_EQ_HelmetA`, 952 tris, 1.65 × 1.366 × 1.65) attached with `Head.CFrame * CFrame.new(AssetMeta.ZR_EQ_HelmetA)`;
   sits on the head with ear clearance. Evidence: `evidence/C01_helmetA_blender_views.jpg`, `evidence/C01_first_import_lineup.jpg`.
4. Batch asset `ZR_CharBase` = **101424875475699** (FBX sha1 `d8b22a9bc6e3df8def0f604f291640e36535f9b5`, 4,868 tris).
5. Logic suite after the rig change: **167 passed, 0 failed** (includes "block body proportions" and
   "support hand reaches (ready/aim)" with the 1.35× third-person weapon scale).

Status: C01 **STUDIO VERIFIED** (single client).

## Source-of-truth boundary

* Luau: Rojo (`src/`). Imported meshes: Roblox assets uploaded from `assets/exports/*.fbx`; their IDs live in
  `src/shared/AssetIds.luau`, attachment offsets in `src/shared/AssetMeta.luau` (copied from each batch's
  `.meta.json`). The game builds characters at runtime from these, so no assembled rig is saved into the place:
  a fresh sync/reopen rebuilds identical characters (C10 checks this).
* Blender sources: `assets/blender_scripts/*.py` (deterministic) plus `assets/exports/*.blend` written by each batch.
