# STAGE 06: Persistent inventory and gear loss

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 06 of ZERO RETURN, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/06_PERSISTENCE_AND_EXPLOIT_PREVENTION.md`, `SPECS/11_SOURCE_OF_TRUTH_AND_COMPLETION.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Complete M1 economic persistence and idempotent raid settlement before expanding game content.

### Tasks to execute
1. Implement isolated `DEV_` versioned datastore or robust in-memory stub if cloud access not authorized. Use `UpdateAsync` with bounded retries and session locking, migrations and clean server close. Do not enable Studio access to live production stores.
2. Model every item GUID in exactly one authoritative location. Safehouse loadout selection reserves/commits gear before insertion. Deploy failure must not spawn player with uncommitted valuables.
3. On successful extraction finalize exactly once (raidId receipt) and credit loot; on KIA/MIA/disconnect resolve loadout as lost and never mint raid loot. Provide beginner recovery kit without tradable duplication.
4. Implement persistent stash inventory with server-driven `Equip/Move/Sell?` if already available and clear item count/weight UI. Stash must survive quit/rejoin and repeated finalize.
5. Add scripted/in-Game adversarial tests: transfer same GUID twice, deploy/quit/rejoin, concurrent container claim, force failed store write, duplicate settlement, two clients fighting. Test in isolated dev experience with authorization; otherwise record NOT TESTED and provide manual steps.
6. Finish with one complete gameplay video only if a verified capture tool is present; otherwise screenshot and playtest log.

### Definition of done and tests
- M1 one full successful raid with loot retaining after rejoin; one KIA and one disconnect show correct gear loss.
- Concurrency and duplicate settlement tests pass or block completion; no false `done`.
- State checkpoint has one concrete M1 user playtest recipe.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**

### Notes
If stage 06 is too large, use `06A_*` and `06B_*` instead of this combined prompt; never run all three.
