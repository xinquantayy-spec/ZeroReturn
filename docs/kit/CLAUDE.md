# Claude Code local project instructions: ESCAPE FROM BLOXOV

Treat this directory as the source of truth for a staged Roblox extraction shooter. **Do not use Cowork** or other agents unless owner explicitly opts in. Goal: original extraction game, not a one-for-one Tarkov or BODYCAM clone.

## Instruction order
1. The latest user instruction and safety/permissions.
2. `STATE/PROGRESS.md` and `STATE/DECISIONS.md`.
3. The **current numbered prompt** and only its specified spec(s).
4. Existing code and tool schemas necessary for touched files.
Never infer tool capabilities from connection names; inspect the exact available Blender/Rojo/Roblox Studio tool actions first. Use direct safe actions. Do not claim a playable build until tested.

## Work discipline
- One numbered stage per user turn. Do not start the next stage automatically. NEVER create dozens of placeholders in lieu of functional systems.
- First inspect, then edit, then build/test; fix errors before advancing.
- Prefer typed Luau (`--!strict`), explicit dependencies, composition and small modules. Code file authority is Rojo repo; avoid unsynchronized manual Studio edits to source-owned scripts.
- Keep server authority over shots/damage, loot and inventory, extraction, currency, quest rewards, trade outcomes and persistent profiles. Local client may predict cosmetics and interface only.
- For every remote, validate types, finite values, rate, range, current state, ownership, permissions and unique action IDs if state-changing. Never trust client-supplied hit damage or item values.
- Never use copyrighted/third-party paid assets without the owner's license. No pasted Tarkov/BODYCAM assets, UI skins, maps, logos, brand names, sound files, real-world police agency branding or scraped game files.
- Keep the style like a deliberately authored low-fidelity indie FPS: NOT Roblox default avatar/Tool templates, conventional neon simulator UI, chunky baseplate maps, generic free models or excessive PBR.
- Support mouse+keyboard, touch and gamepad from the first slice. Input Action System where verified, with a fallback adapter if feature/API status differs. Console GUI navigation must be genuinely testable.
- Optimize for 30 FPS minimum on owner-specified low-end phone baseline; aim for higher on capable PC/console. Do not claim performance until hardware profiling. Stream world assets; avoid per-frame full-screen effects and costly unbounded physics.
- Tests: one Studio local player, Studio two-client, device emulator + real phone. Mark hardware/console tests `NOT VERIFIED` until performed.
- No real purchases, automatic publishing, unapproved git pushes, credentials, deleting/migrating production stores, or modifying live Roblox assets.
- Change only current-scope files, no wide refactor unless required for correctness. Prefer built-in Roblox APIs over adding frameworks.

## Stage completion protocol
Update `STATE/PROGRESS.md` with milestone/stage, files changed, build/test commands with pass/fail, tool evidence, important decisions, open issues and next prompt. Update `STATE/DECISIONS.md` if an architecture decision changes. Include concise output: summary, tested evidence, blockers, next prompt. If you could not run the test, say `NOT TESTED` clearly. Stop after the stage.

## Performance / context discipline
Do not read all files recursively or repeatedly; use targeted search and stage-listed specs. No large pasted code listings in chat; write files and report paths. Keep generated assets in small batches, produce stable manifest entries, reuse atlas materials. Prefer scriptable Blender modeling for simple assets and verify import actually works.

## Default style direction
Working title `ESCAPE FROM BLOXOV`, map `QUAY 7`. Industrial coastal quarantine/evacuation world, olive/charcoal/sand/rust palette, simplified realistic silhouettes, intentionally soft/pixel-lean textures and small details that distinguish it from Roblox. Minimal diegetic bodycam overlay with signal/time/REC indicators, understated health/ammo readable on all screens. No heavy VHS distortion or direct BODYCAM UI copying.
