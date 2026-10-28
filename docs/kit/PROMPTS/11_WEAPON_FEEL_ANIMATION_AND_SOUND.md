# STAGE 11: Weapon feel animation and sound

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 11 of ZERO RETURN, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/04_BODYCAM_GRAPHICS_UI.md`, `SPECS/07_BLENDER_ASSET_PIPELINE.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Make combat feel polished through subtle motion, audio and art-driven feedback instead of costly graphics.

### Tasks to execute
1. Polish R-17 viewmodel equip, ADS, muzzle, reload and idle; implement limited camera sway/recoil and correct third-person firearm alignment for observers.
2. Add distinct licensed/original directional gunfire, suppressor optional later, footsteps by surface material, distant metallic reverb and environmental loops; track license/source of each asset.
3. Control sound distance/volume and caption important audible events. Keep memory light by using existing asset playback rather than many looping duplicate sounds.
4. Add a basic player death fade/summary with NO gore or detailed wound effects.
5. Studio test sound spatialization with two clients, no huge volume spikes, one phone simulator pass and FX-off screenshot.

### Definition of done and tests
- Actions feel responsive and readable; sounds never use unauthorized reference assets.
- Audio and viewmodel alignment function with multiple clients; option to disable camera shake.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
