# STAGE 06B: Extract settlement and loss split

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 06B of ESCAPE FROM BLOXOV, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/06_PERSISTENCE_AND_EXPLOIT_PREVENTION.md`, `SPECS/11_SOURCE_OF_TRUTH_AND_COMPLETION.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Complete M1 economic settlement and reconnect tests using the 06A foundation.

### Tasks to execute
1. Implement idempotent `raidId` settlement for `SUCCESS`, `KIA`, `MIA`, `DISCONNECTED` with bounded settled-receipt log.
2. Credit retrieved loot only after proven success and delete/reserve equipped on failures. Guard uncertain datastore outcomes, process per-key retries in order.
3. Add simple post-raid summary and profile reload; test two-client loot fight, duplicate success requests, restart/reconnect and unknown write result.
4. Prepare one 8-minute end-to-end Studio checklist and run it; mark device tests NOT VERIFIED.
5. Verify no item GUID duplicated across stash/equipped/raid on every state transition. Stop.

### Definition of done and tests
- Exact M1 success vs failure tests pass without duplicated/lost legitimately extracted items.
- If persistence blocks on user setting, stop with a one-sentence required UI action, do not fake cloud results.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
