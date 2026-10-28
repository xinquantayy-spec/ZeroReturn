# STAGE 06A: Persistent profile foundation split

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 06A of ZERO RETURN, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/06_PERSISTENCE_AND_EXPLOIT_PREVENTION.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Implement ONLY profile storage, sessions, migrations, isolated dev setup and secure deploy gear reservation; defer finalization to 06B.

### Tasks to execute
1. Build profile load/update with `UpdateAsync`, per-user session lock, bounded retry and error state.
2. Item model with GUID reference ownership, stash and equip, safehouse loadout selection and atomic `pendingRaid` reservation. Ensure reserved items unavailable in stash.
3. Use test-only store prefix and Studio dev experience, read/write no live data without authorization.
4. Test duplicate deploy and early quit; log profile revisions. Provide small test harness for stage 06B.
5. STOP without trying to implement final settlement or arts/UI cosmetics.

### Definition of done and tests
- Rejoin can load persistent stash, deploy consumes/reserves once, no duplicate reservation.
- M1 remains incomplete until 06B.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
