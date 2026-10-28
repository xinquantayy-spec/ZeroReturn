# STAGE 15: Mobile console performance pass

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 15 of ZERO RETURN, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/09_PERFORMANCE_BUDGET.md`, `SPECS/04_BODYCAM_GRAPHICS_UI.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Profile and optimize actual bottlenecks, not vague visual settings.

### Tasks to execute
1. Capture Studio performance Summary and stats during 2-client fire+AI+loot test, including drawcalls, tris, script time, memory and network. Keep frame profiler outputs if tools provide them.
2. Evaluate streaming and visibility; simplify meshes, texture atlases, shadows and FX based on measured hot spots. Avoid optimizing speculative bottlenecks.
3. Build Low/Medium/High presets, with low having zero film noise and minimal shadows, but no gameplay visibility disadvantage.
4. Prepare real-handset test: ask owner for one low/mid phone and optionally physical console; provide instructions to join private dev place and turn on Performance Stats. If owner cannot test, mark DEVICE VERIFIED = no.
5. Run 10–15 min thermals/performance scenario if physical tool/device available and record CPU/GPU frame, FPS and mem as measured; do not invent stats.
6. Ensure network remote flood tests, bounded AI paths, animation/particle allocations and no expensive each-frame UI loops.

### Definition of done and tests
- Document benchmark table with measured device, build version, result and actions.
- Performance regressions addressed, otherwise issue-specific blockers documented.
- No false real-device or physical-console claims.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
