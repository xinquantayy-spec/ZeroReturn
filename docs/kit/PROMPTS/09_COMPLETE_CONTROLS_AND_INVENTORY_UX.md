# STAGE 09: Complete controls and inventory UX

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 09 of ESCAPE FROM BLOXOV, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/05_INPUT_CROSS_PLATFORM.md`, `SPECS/04_BODYCAM_GRAPHICS_UI.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Polish true mobile/console/PC input parity and full inventory navigation.

### Tasks to execute
1. Reconcile Input Action bindings and input-context switching (`PLAY`, `INVENTORY`, `SAFEHOUSE`, `POST_RAID`, `SETTINGS`), with hot switching based on PreferredInput.
2. Touch layout: adjustable sensitivity and buttons, contextual loot, tap-to-move, backpack modal and healing, hide irrelevant buttons. Honor touch safe area.
3. Console: selectable focus in stash/loadout/loot/trader panels, joystick + d-pad focus, back/confirm, no mouse-only drag, button prompts update by device. Verify with Studio Controller Emulator or actual connected controller.
4. PC: raw mouse aiming where appropriate, ADS hold/toggle, rebinding where feasible; fire disabled while menus open.
5. Add settings for FOV, sensitivity, effect toggles and reduce motion. Run complete action matrix and keep known hardware gaps labeled.

### Definition of done and tests
- All actions in `SPECS/05` work in Studio's corresponding emulators; broken focus paths explicitly fixed.
- Real mobile/gamepad performance labels remain NOT VERIFIED unless physically tested.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
