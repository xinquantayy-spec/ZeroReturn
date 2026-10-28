# Tool detection and optional setup — for Claude Code

**Do not assume connecting MCP means a CLI exists.** Have Claude report tool names, descriptions, exact arguments and read-only results; use schemas rather than inventing tool methods.

## Preconnected tools: inspect first
1. **Blender bridge:** test `get_scene_info` or equivalent read-only inspection; verify Blender executable path/version and a test export to a **new disposable folder**, never an existing scene. Use blender `--background --python script.py` only if an executable is verified, not as an assumed requirement.
2. **Roblox Studio bridge:** test hierarchy or place metadata read; verify target place name and owner. Test a one-line safe disposable script/model in a new scratch container, then remove only that scratch item. Never overwrite original place. If plugin must be reopened, tell user exact UI action.
3. **Rojo:** shell `rojo --version`, `rojo help`, determine `default.project.json` and source sync status. In Studio ensure Rojo plugin matches installed server major version. `rojo serve` requires a functioning plugin connection; leave daemon running only when in use.
4. **Git:** check `git --version`, workspace git status. If not available, make a filesystem backup and change log, don't install Git automatically.

## Optional tools — install ONLY if a need is demonstrated
- **Rokit** for consistent Roblox tool versions; Roblox external tools documentation: https://create.roblox.com/docs/projects/external-tools
- **StyLua** for Luau formatting: https://github.com/JohnnyMorganz/StyLua
- **Selene** for static Luau linting: https://kampfkarren.github.io/selene/
- **Luau language server** for editor checks: https://github.com/JohnnyMorganz/luau-lsp
- **TestEZ** only if custom unit tests significantly benefit; otherwise use small internal assert-based spec runners in Roblox Studio.
- **Wally** package manager: https://wally.run/ — do not add until a named library is essential; minimize deps.
- **GitHub** is not necessary for an initial local build. Optional remote git sync only after explicit owner permission.

## For an optional tool install
1. Claude determines OS and architecture read-only, prints exact verified official download/source.
2. Claude chooses one version, checks checksum/signature where applicable, and asks owner approval if network/package manager install or elevated permissions needed.
3. Install the smallest set, verify with `--version`, document in `STATE/TOOL_AUDIT.md`.
4. Avoid API keys if Studio and Rojo import already work. If Roblox Open Cloud API upload is truly needed, user should create a least-privilege credential through Creator Dashboard, store it in OS environment/secret manager, never in source files or chat, and Claude should first attempt authorized Studio import instead.

## Roblox/Blender asset handoff
Blender exports `.fbx` or `.gltf` into `/assets/exports/`. Studio's 3D Importer accepts those formats; the bridge may be able to invoke import. If automated asset upload is unavailable, stop with a manual 3D Importer checklist and exact filenames. Never state an export is 'in Roblox' until the asset ID/Studio instance is confirmed.

## Diagnose tool failures without wasting credits
- Missing CLI: report exact missing command/path, don't rerun a loop 20 times.
- Rojo not syncing: check CLI version, server, Studio plugin connection, and relevant project mapping. Do not delete user content.
- Imported mesh unexpectedly large/rotated: make one calibration cube and verify transform before batch exporting.
- Unauthorized Studio action: ask for owner permission; no cookie/session-token workarounds.
- Studio limitations: fall back to writing Luau/Blender files and provide owner a short click path.
