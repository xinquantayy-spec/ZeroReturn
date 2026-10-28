# STAGE 01: Lock gameplay and acceptance

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 01 of ESCAPE FROM BLOXOV, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/01_GAME_DESIGN_DOCUMENT.md`, `SPECS/02_SYSTEMS_AND_CONTENT.md`, `SPECS/11_SOURCE_OF_TRUTH_AND_COMPLETION.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Produce a concise, implementation-ready design contract and ruthless M1 scope without coding the whole game.

### Tasks to execute
1. Summarize player journey in 8 steps, the M1 feature inventory, essential data schemas (items, raid, gun, player profile), core map spaces and win/lose rules.
2. Create project-local `docs/GDD_LOCKED.md`, `docs/M1_ACCEPTANCE.md` and `docs/BACKLOG_LATER.md`. Mark scope as frozen; do NOT add survival meters, complex crafting, 10 gun families or multiple maps.
3. Define 6–8 minute raids and extract hold rules with fair solo and 2-client tests. Define tutorial (first chest and exit route) and recoverable beginner loadout.
4. Translate art constraints into 8-item quick style bible (no generic Roblox assets, custom viewmodel, industrial low-fi aesthetic).
5. Add dependency-aware milestone order; each future stage is implementable and testable. Do not claim M1 built.

### Definition of done and tests
- All specified design documents created, concise and internally consistent.
- User-facing product boundaries clear; no code/gameplay capability claimed.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
