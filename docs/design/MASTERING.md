# Weapon mastering: research and plan (not built)

Status 2026-11-01: research done, nothing built (the owner paused the work). Nothing here has run.

## What Tarkov does

- **Groups and thresholds.** Mastering is per weapon group. SPT's copy of Tarkov's `globals.json` (github.com/sp-tarkov/server, branch master) lists 78 groups; each has a Level2 and a Level3 value, and level 1 starts at 0. Examples (Level2 / Level3):
  - M4 1600 / 2000, AKM 500 / 600, AK-74 2000 / 2200, SKS 200 / 300
  - MP5 200 / 250, MP7 550 / 800, Glock 17 100 / 125, PM and MP-443 75 / 100
  - MP-133 150 / 200, M870 100 / 200, Mosin 200 / 250, SV-98 100 / 175, SVD 250 / 300
  - `exp.level.mastering1/2` (1500 / 5000) in the same file looks like an unused leftover.
  - Not settled: whether Level3 is a running total or comes on top of Level2.
- **Gaining it.** 1 point per hit with that weapon on a living target; every shotgun pellet that hits counts. Sources: a Steam guide "EFT basics: Skills and Weapon Mastery" (removed from Steam since), boostroom.com's mastery page (it adds "online raids only"), NamuWiki.
- **What the levels give.** Level 2: another reload animation for some guns. Level 3: reload while aiming down sights with that group. Sources: the official forum thread "What does weapon mastery do?", boostroom, the Steam guide, NamuWiki (which also says recoil and reload speed improve, with no numbers). No official numbers were found for faster reloads, mag checks or chambering.
- **Screen.** Tarkov's character screen has a MASTERING tab; the level labels read "WEAPON MASTERING (01)" to "(03)", a toast says "{0} mastering leveled up to {1}", groups are named by weapon class, and one buff doubles mastering gain (SPT's English text file).
- **Prestige.** A code comment in the SPT server says 5 % of mastering carries over.

## Proposed mapping (Zero Return weapons to Tarkov groups)

R-17 → M4, KS-7 → AKM, SMG-9 → MP5, Harrow-12 → MP-133, Tundra → Mosin, P-9 → MP-443. The knife and the mounted guns get none, as in Tarkov.

## Plan

1. Groups, thresholds and the level maths in `src/shared/Progress.luau`.
2. Points granted on the server in `Combat.luau`, one per hit (per pellet), never from the client.
3. Saved in the profile (`Settle.progressFields`), sent to the client in `Economy.stateFor`, with the level-up toast.
4. Level 3: reload while aiming, in `Weapon.luau` and checked on the server.
5. A MASTERING tab in `Character.luau` and the `Inventory.luau` tab row (touch, controller and keyboard).
6. A `ZR_Dev` command to grant points; a LogicTests group; then the parity log and status docs.
