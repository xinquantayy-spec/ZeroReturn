# STAGE 04: Server combat and one weapon

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 04 of ESCAPE FROM BLOXOV, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/03_ROBLOX_ARCHITECTURE.md`, `SPECS/02_SYSTEMS_AND_CONTENT.md`, `SPECS/06_PERSISTENCE_AND_EXPLOIT_PREVENTION.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Implement R-17 gun shooting/reload/ADS and a dummy target with authoritative ammo/damage, plus visible client feedback.

### Tasks to execute
1. Implement one fictional weapon configuration. Server maintains current weapon, magazine/ammo, fire rate, reload timer, player alive-state, and authoritative damage. Player sends shot intent only; server validates IDs, rate, direction, origin, geometry LOS and time, then raycasts against target.
2. Client predicts local recoil, gunfire sound/brief muzzle flash, ADS movement, reload animation state; reconcile ammo count from server. Create one original simple low-poly rifle viewmodel from Blender if its tool connection works; use a handmade temporary mesh only as an explicit fallback, never a default Roblox Tool hand. Final polished Blender viewmodel comes later.
3. Add simple test dummy with 100 health and combat log. Test damage from plausible range, miss vs hit, occlusion, finite aim and field-of-view limits.
4. Add tests for spoofed ammo, rapid-fire spam, player dead, reloading, NaN vector and client fabricated damage. Rate-limit reports; use no `Touched` to inflict weapon damage.
5. Test one and two clients. If lag compensation not implemented, document measured limitations and defer advanced rewind; don't promise competitive high-latency precision.

### Definition of done and tests
- Repro: equip R-17 -> fire -> ammunition decreases -> cover blocks shot -> reload -> fire; client sees feedback and server controls damage.
- Flooding invalid shots does not produce damage.
- Two clients observe weapon state without cross-contamination.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
