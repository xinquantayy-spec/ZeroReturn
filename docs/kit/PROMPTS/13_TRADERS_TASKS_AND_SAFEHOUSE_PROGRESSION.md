# STAGE 13: Traders tasks and safehouse progression

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 13 of ZERO RETURN, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/01_GAME_DESIGN_DOCUMENT.md`, `SPECS/02_SYSTEMS_AND_CONTENT.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Create a meaningful original metagame without a pay-to-win or generic tycoon economy.

### Tasks to execute
1. Add three original fictional NPC dealers: Wharf Mechanic (equipment), Archivist (data), Quartermaster (supply). Unique names and art, do not borrow Tarkov traders.
2. Implement Buy/Sell via server-only quotes/currency validation, safehouse restricted with atomic item-money mutation. Add no player-to-player trading yet.
3. Add 5 contracts: retrieve 2 signal coils, survive 2 raids, inspect freight depot, extract one sealed drive, eliminate 2 rogue guards. Server grants reward once with idempotent receipt.
4. Expand safehouse with one visual workbench and storage locker upgrade that raises stash capacity. Test after reconnect and repeated purchases.
5. Add player-visible economy reporting, helpful loss recovery kit, no lootbox and no Robux buffs. Add a nonintrusive roadmap for cosmetics only, not implementation.

### Definition of done and tests
- Each task and merchant action can be completed in Studio without duplicate reward or negative balance.
- Progress persists, UI works on touch and controller.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
