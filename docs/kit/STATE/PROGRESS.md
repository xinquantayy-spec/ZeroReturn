# Progress checkpoint
status: IN_PROGRESS
stage: Phase E (improvement program); M12 Look 2.0 done, next M13 Maps
gate: M12 verified in Studio on the T490 (single client, in-memory store); LogicTests 167/167, CharTests 38/38, LookTests 19/19
date: 2026-10-29

The live status files are at the repo root:
- `DEVELOPMENT_STATUS.md`: phases, Definition of Done, architecture, controls
- `TEST_RESULTS.md`: evidence
- `KNOWN_ISSUES.md`: open issues and tool limitations
- `NEXT_TASK.md`: the next steps
- `ASSET_MANIFEST.md`: asset IDs and licensing
- `docs/PIPELINE.md`: sync, Blender, audio and test procedures

## Working project path
- PC: `C:\Users\lenovo\Documents\EscapeFromBloxov`, served with `rojo serve --port 34873`
- Studio: `Zero Return.rbxl` (never Place1/Place2)

## Verified tool actions
- Blender MCP: verified (scripted builds, FBX export, Open Cloud uploads)
- Rojo 7.7.1: verified (serve plus Studio plugin sync)
- Roblox Studio MCP: verified (execute_luau, play control, input, console, capture)
- Other: NOT VERIFIED (real DataStore, two clients, devices)

## M12 Look 2.0 (2026-10-29)
- Files:
  - server `Main.server.luau`, `Services/World.luau` (cover props, `detailAvoid`, `NoDetail`, lamp states), `Services/DetailPlan.luau` (avoid zones, container wear), `Services/Raid.luau` (graphics 0–3), `Tests/LookTests.luau`;
  - client `Main.client.luau` (Detail in the order, `detail` probe), `Controllers/Detail.luau`, `Settings.luau`, `Screens.luau`, `Post.luau`, `Atmos.luau`;
  - `src/materials/*` (5 new roughness maps); `docs/look/`;
  - `tools/studio_patch.py`, `tools/pc_patch.py`.
- Tests: `ZR_Dev:Invoke("tests")` PASS (167 + 38 + 19). Visual evidence: `docs/look/evidence/L01`–`L11`. Studio frame rates on the T490 are in `docs/look/LOOK_2_0.md`.
- Tool notes: the laptop's shell tool was unavailable this session. Files went to the PC as a bundle through Blender's Python, and Rojo carried them into Studio.
- Open: devices NOT VERIFIED; chain-link fences and denser interiors left for later.
