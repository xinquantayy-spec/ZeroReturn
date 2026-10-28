# STAGE 03: Greybox map and playable controller

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 03 of ZERO RETURN, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/08_MAP_AI_MATCH_SYSTEM.md`, `SPECS/05_INPUT_CROSS_PLATFORM.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Create an actual navigable safehouse and Quay 7 greybox with basic all-platform control paths.

### Tasks to execute
1. Construct or script a 400x400-stud greybox: Safehouse, Quay 7 with Harbor Stack/Pump Annex/Freight Depot, two spawns, two extraction beacons, 3 searchable crate positions. Add map navigation landmarks; collision should be proper.
2. Create clear local player raid/safehouse movement handling and a basic first-person camera that doesn't show default avatar head/arms; no heavy bodycam FX yet.
3. Implement central actions `Move/Look/Interact/Inventory/Fire/ADS/Reload/Sprint/Crouch` through verified Input Action System, or an adapter with fallback. Put PC, touch and gamepad bindings in one data source. Add tiny touch/console debug UI and context switching; don't perfect aesthetics yet.
4. Implement stub safehouse `Deploy` interaction to teleport local character to raid zone in the same place, with server validation; prevent casual teleport exploit by remote. Not yet economic gear reservation.
5. Because visual authorship matters from the start, make ONE original low-poly calibration crate in Blender, export and import it into the greybox via verified Studio tooling; record source and imported MeshPart asset. If importer is unavailable, record blocker instead of pretending it imported.
6. Test spawn collision, walkways, doors, map boundary, camera clipping and controller actions in Studio local and simulated phone. Record failings explicitly.

### Definition of done and tests
- Can walk a safehouse and raid greybox, interact with 2 marked locations, return to safehouse by debug control.
- Gamepad/touch controls have a working path, not only keyboard; UI not hidden behind safe insets.
- No economic persistence claim yet.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
