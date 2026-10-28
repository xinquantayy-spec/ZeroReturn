# STAGE 05: Raid loot extraction loop

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 05 of ZERO RETURN, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/02_SYSTEMS_AND_CONTENT.md`, `SPECS/03_ROBLOX_ARCHITECTURE.md`, `SPECS/08_MAP_AI_MATCH_SYSTEM.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Build server-issued loot, searchable containers, extraction clock and correct victory/defeat outcomes in memory.

### Tasks to execute
1. Server generates 6 collectible item types across 3 container positions using configured weighted pools + stable loot IDs. Implement interaction duration/range/LOS and server acquisition. Clients see simple loot list with take button and gamepad/touch selectable controls.
2. Add equipment bag with limited cells; simple inventory `Move/Drop/Take` with server validation; block overlapping cells/overcapacity and double requests.
3. Add RaidService state machine with `Active/Extracting/Success/KIA/MIA`, server timer, distinct allowed extracts per spawn, 6s held extraction countdown reset on departure, and timer expiry.
4. Create temporary in-memory raid summary (retained/lost), return to safehouse, clear ephemeral raid world inventory. Do not persist loot yet; mark persistence stage 06.
5. Test 2 clients trying to loot same item, player dying during extract, leaving extraction zone, spamming extract remote and timer expiring. Validate exact item GUID uniqueness.
6. Stop if core mission can't be fully completed. No art batch until this works.

### Definition of done and tests
- At least one end-to-end raid in Studio with loot + extract + summary; separate KIA/MIA path.
- Two clients cannot simultaneously claim same GUID.
- Clearly label in-memory only until stage 06.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
