# Hideout style: the bunker's walls, floor and ceiling

Status 2026-11-02: **built and checked in Studio with one player** (TEST_RESULTS "Hideout style").

## What Tarkov does (0.16.0.0)

- "You can customize the Hideout's floor, walls, ceiling, Shooting Range targets", and place posters on the walls and
  collectibles on the shelves and tables.
- "Hideout styles are unlocked for character level, completing certain tasks, and earning achievements". Achievement
  rewards include the "Modest Wallpaper" and "Blue paint" wall styles and the "Small tiles" floor.
- Shooting Range targets unlock by levelling the range and by tasks; posters are found as loot and earned with
  Prestige; mounting them unlocks as the hideout is upgraded.
- You can visit a friend's hideout from their profile; lighting can be switched there.
- Source: [Sportskeeda: 0.16.0.0 patch notes](https://sportskeeda.com/esports/escape-tarkov-patch-notes-update-0-16-0-0-new-event-customs-rework-prestige-system).

## Built (2026-11-02)

- **Relay 7 is one bunker everyone shares** (the owner's design), so a style is what you see: each client paints the
  shell with its own player's choice. Others see theirs.
- **Three categories** (`shared/HideoutStyle.luau`), the shell as built first in each:
  - **Walls:** the issue olive band; whitewash (level 5); blue paint (10); modest wallpaper (15); a tiled wainscot (20);
    wood panelling (25); bare brick (30). Each paints the walls' three cuts: the band, the line, the upper wall.
  - **Floor:** bare concrete; small tiles (8); vinyl sheet (12); terrazzo (18); old planks (24).
  - **Ceiling:** bare concrete; ceiling tiles (6); whitewash (14); wood boards (22).
  - The finishes are the game's own MaterialVariants (ZR_Whitewash, ZR_WallpaperA, ZR_FloorTiles, ZR_Terrazzo,
    ZR_CeilingTiles and others).
- **How to choose:**
  - In the hideout screen (the workbench), the STYLE section lists every option with USE, IN USE, or the level it
    unlocks at.
  - The server checks the level (`Hideout` op `style`), keeps the choice in the profile and confirms with a toast.
- **Painting:** `LobbyStyle.luau` paints `ZR_World.Relay7.Shell` on every state change, and repaints parts as they
  stream in.

## Gaps (also in `EFT_PARITY.md`)

- **Unlocks are by level only:** no tasks or achievements (the game has none yet). The levels are ours.
- **No posters, collectibles or range targets yet,** and no visiting another player's hideout.
- **Everyone sees their own style.** Tarkov's hideout is private, so the shared bunker cannot show one owner's style
  to all.
