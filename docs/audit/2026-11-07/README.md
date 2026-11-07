# Audit, 7 November 2026

The owner asked for deep research into every part of the game, then a report on which to give input before anything is
implemented. This folder holds that research. The owner's choices are recorded in the interactive report on claude.ai
("Zero Return Audit"). The report saves each pick and note in its database: `choices/<decision id>`, and `meta/general`
for general notes, the "use your recommendation" flag and the ready flag. **Nothing from this audit is implemented until
the owner marks the report ready.**

## What was done

Six research agents each audited one area against Escape from Tarkov (as of late 2026) and against what a phone can
run. They read the code and docs and changed nothing:

| Area | Report | Decisions | Findings (P0 / P1 / P2 / P3) |
|---|---|---|---|
| Performance, saving and release | `tech.md` | 8 | 2 / 6 / 11 / 5 (the start-up race was raised to P0 after it happened in Studio) |
| Gameplay, combat and sound | `gameplay.md` | 8 (onboarding merged into ui-5) | 0 / 6 / 11 / 12 |
| NPCs and AI | `ai.md` | 8 | 0 / 5 / 13 / 8 |
| Loot, economy and progression | `economy.md` | 8 | 1 / 7 / 12 / 5 (its DataStore P0 is the same as Tech's) |
| HUD, screens and controls | `ui.md` | 8 | 1 / 5 / 9 / 7 |
| Art, maps and models | `art.md` | 8 | 0 / 7 / 10 / 5 |

Each `.json` file holds the same decisions and findings in machine-readable form, with ids such as `tech-1`. The report
adds three direction choices (`start-1` work order, `start-2` quick wins, `start-3` how strictly to copy Tarkov's
harshness). It narrows `economy-4` to XP, loyalty and hideout timers; insurance, the scav cooldown and healing between
raids are `gameplay-6`.

## Checked live on 7 November 2026 (`measured.json`)

- **Studio** on the owner's T490 laptop, Play Solo at Studio graphics quality level 2. These are not phone numbers.
  - Hideout: 60 fps.
  - Border Yard: 48-60 fps, render CPU 9-15 ms, GPU 11-17 ms, 12,856 parts streamed in.
  - Meridian Mall: 57-60 fps, 22,474 parts streamed in.
  - One server holds 50,760 parts, 477 lights and 9.1 million terrain cells.
- **Bug seen:** the client gave up after 30 s waiting for the server (Net.luau and State.luau), so a raid showed STBY
  and 0 MK with no loadout.
- **Console:** the ambience atlas asset is 0.0 s long, so it is silent, and asset 203785492 fails to load.
- **Blender:** the KS-7 preset is 3,378 triangles, and all 107 gun meshes come to 57,776. A textured-material mock-up of
  the KS-7 was rendered next to today's vertex colours. It shows what textures add to the same shapes; it is not art
  for the game.
