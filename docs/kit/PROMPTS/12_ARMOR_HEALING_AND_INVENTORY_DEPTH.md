# STAGE 12: Armor healing and inventory depth

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 12 of ESCAPE FROM BLOXOV, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/02_SYSTEMS_AND_CONTENT.md`, `SPECS/06_PERSISTENCE_AND_EXPLOIT_PREVENTION.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Add high-value Tarkov-like survival depth with a SMALL ruleset manageable on touch and console.

### Tasks to execute
1. Add torso armor durability, limb/torso impacts if justified by playtest, two heal item categories with intuitive status icons. No complex medical encyclopedia.
2. Introduce equipment carry weight movement penalties with clear thresholds and no inconsistent client authority.
3. Add one weapon optic slot and one magazine variant with server-valid mod item ownership and optional weapon inspect.
4. Add 10 loot items (not hundreds) with identifiable uses, stack limits and value progression. Fill profile migration for new fields.
5. Test all items across death/extraction/disconnect, controller/touch item actions, store serialization and double-claim attacks. Tune to avoid one-shot untelegraphed deaths.

### Definition of done and tests
- Equipment alters gameplay in verified, deterministic manner and persists/losses correctly.
- Loot/injury UI clear at small scale; M1 compatibility maintained.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
