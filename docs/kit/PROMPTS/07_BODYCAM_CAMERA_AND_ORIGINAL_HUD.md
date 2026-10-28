# STAGE 07: Bodycam camera and original HUD

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 07 of ESCAPE FROM BLOXOV, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/04_BODYCAM_GRAPHICS_UI.md`, `REFERENCES/BODYCAM_HUD_MOCKUP.png`, `SPECS/09_PERFORMANCE_BUDGET.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Build the distinctive body-camera presentation and responsive tactical HUD without hurting mobile performance.

### Tasks to execute
1. Implement `CameraController`, custom client viewmodel offsets/ADS behavior, mild capped sway and optional vignette. Never simulate true heavyweight distortion via a per-pixel shader that Roblox cannot offer.
2. Create original Roblox GUI from components: `FIELD RECORDER M4` channel/REC/time, raid timer/extraction, HP/stamina, ammo, context interaction, extraction progress, status warnings. Do not insert screenshot as static HUD.
3. Implement quality presets and reduced-motion/film-off options; ensure color contrast and stable camera when low effect setting.
4. Inspect actual in-Studio screenshots at 16:9 PC, a small notched phone landscape, tablet and controller emulator; fix overlap and safe insets.
5. Keep overlay visually distinctive and uncluttered. Show non-combat safehouse UI separately (dossier style).

### Definition of done and tests
- Screenshot or observable Studio UI matching original mockup direction, not copyrighted screenshots.
- HUD reacts to actual server values and no default giant Roblox UI remains.
- No strobe/rapid noise and small-screen readability verified in emulator.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
