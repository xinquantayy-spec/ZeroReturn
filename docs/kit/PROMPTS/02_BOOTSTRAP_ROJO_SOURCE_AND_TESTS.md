# STAGE 02: Bootstrap Rojo source and tests

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 02 of ZERO RETURN, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/03_ROBLOX_ARCHITECTURE.md`, `TOOLS/ROJO_PROJECT_EXAMPLE.project.json`, `TOOLS/COMMAND_CHEATSHEET.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Create a working source-controlled Luau + Rojo foundation that builds cleanly and connects to the intended Studio place.

### Tasks to execute
1. Create source repo directories and a correct `default.project.json` based on verified installed Rojo major version. Inspect project mapping and whether assets will be Studio packages or importer assets.
2. Add `--!strict` shared module scaffolds for types, constants, item data, remote IDs and simple bootstrap. Do not create 25 empty services to look complete.
3. Build minimal `Main.server.lua` and `Main.client.lua`: version handshake + one debug HUD line that shows connection, no game logic yet. Ensure created RemoteEvents exist server-side; client bounded waits.
4. Generate basic scripts/testing utilities only if they actually run in Studio. Optional local formatter/linter only when already installed; do not install package managers without approval.
5. `rojo build`, `rojo serve`/Studio connect if supported; take screenshot/tool evidence if available, but do not fake a screenshot. Add instructions to reassemble binary Studio assets from manifest.
6. Create a git commit only if repo configured and user permits local commit; no pushes.

### Definition of done and tests
- Rojo build passes; Studio observes client/server boot or clearly marked `NOT TESTED` with precise obstacle.
- No source overwrite, no external dependency bloat.
- Starter structure reusable for M1.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
