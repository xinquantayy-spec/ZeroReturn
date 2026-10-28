# STAGE 10: AI and encounter design

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 10 of ESCAPE FROM BLOXOV, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/08_MAP_AI_MATCH_SYSTEM.md`, `SPECS/02_SYSTEMS_AND_CONTENT.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Upgrade basic security patrol into believable, efficient PvE encounter loops and map pacing.

### Tasks to execute
1. Build guard AI FSM patrol/investigate/engage/search/return with controlled tick rate, LOS, hearing events, cover use if stable. Use server authoritative rays for AI combat and PathfindingService only when path changes.
2. Place 2–3 guards with patrol loops and timed encounter triggers near valuable loot; no constant waves of enemies or rubber-band spawns.
3. Tune meaningful sound detection and fairness: cooldown between turns/shots, visual suspicion cue if accessible, no hits through occluders.
4. Test 2 clients drawing aggro, AI reset after player exit, path blocked, stop/restart; profile CPU under 3 AI load.
5. Add bot debugging toggle restricted to Studio test role; disable in live play. Keep no client authority over AI targets.

### Definition of done and tests
- AI behaves deterministically and within CPU budget; does not shoot through walls.
- Core extraction loop remains playable with AI; M1 persistence remains valid.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
