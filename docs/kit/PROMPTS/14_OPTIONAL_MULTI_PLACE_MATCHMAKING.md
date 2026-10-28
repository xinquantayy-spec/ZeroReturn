# STAGE 14: Optional multi place matchmaking

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 14 of ZERO RETURN, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/08_MAP_AI_MATCH_SYSTEM.md`, `SPECS/06_PERSISTENCE_AND_EXPLOIT_PREVENTION.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
If, and ONLY if owner authorizes after stable core, implement separate safehouse/raid places and matchmaking safely.

### Tasks to execute
1. Evaluate if the game actually needs multiple places yet. If not, write `docs/MATCHMAKING_DEFERRED.md` with rationale and STOP without adding complexity.
2. If approved: design MemoryStore queue for 4–6 player raids and TeleportService reserved servers; no client-chosen arbitrary server access.
3. Ensure gear reservation before teleport and arrival verification after teleport. Handle failed Teleport, player disconnect, duplicate arrival and cross-place profile lock handoff.
4. Keep raid receipt idempotent, server authoritative; teleportData carries nontrusted hints only. Add timeout recovery.
5. Test on a published PRIVATE development universe because teleport support may not function in Studio the same way; don't publish public. Record precise available test results.
6. Do not introduce cross-server trading or flea market here.

### Definition of done and tests
- Either defensible deferral memo or private-dev end-to-end handoff and rollback tests.
- No destructive production storage migrations; no public publishing.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**

### Notes
This stage is optional, high complexity and expensive. Most users should defer it until after hardware tests.
