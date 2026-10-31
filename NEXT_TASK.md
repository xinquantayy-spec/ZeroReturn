# Next Task

**The Relay 7 lobby is done (2026-10-31).** See `docs/maps/RELAY7_LOBBY.md`. Follow-ups (KNOWN_ISSUES 58-61): your gun in your hands seen by others at the range, lobby sounds (generator hum, radio, van engine), the squad boarding together, Border Yard on the fourth map sheet once it is built.

**Standing rule (owner, 2026-10-31):** as close as possible to Escape from Tarkov in every aspect, less the exceptions in `docs/design/EFT_PARITY.md` (also in `CLAUDE.md`). That file lists every gap found in item information, inventory quality of life, controls, settings and visuals, and the order of work.

**Next:** Tarkov-layout inventory, stash and trader screens (item 5 below), now with Tarkov's INSPECT window (the full attribute sheet for every item kind: fire rate, damage, penetration, armor material and penalties, med effects...), tile counters, stash search and sort. Then controls and settings parity, M11 part B, the character tabs / messenger / handbook / wish list, then Border Yard, the flea market and the Quay 7 and Smelter furnishing pass (`EFT_PARITY.md`, "Order of work").

**M14 weapon modding is done (part A, 2026-10-29).** Follow-ups from the fidelity check (KNOWN_ISSUES 52–57): laser beams and device modes, folding stocks, saved builds with buying missing parts, sight zeroing and variable zoom, 3D inspect for every item, part sizes against Tarkov's.

**M16 Characters (owner request, 2026-10-28) is done (part A).** Block body, Blender equipment set, server appearance system and role presets; see `docs/character/`. M16 part B is still to do:
- the two-client checks (C06, C08), which need a Studio Clients-and-Servers run by the owner;
- touch and controller emulation of the equipment screen (C11);
- a subtle fabric MaterialVariant;
- eyewear and goggles;
- the marksman/scout and safehouse-worker presets;
- a stash character preview;
- a showroom profile with the expected character count, on real hardware.

**M12 Look 2.0 is done (2026-10-29).** Worn materials, cover props, the client detail layer, the GRAPHICS setting (HIGH by default everywhere, POTATO opt-in) and flickering or dead lamps. See `docs/look/LOOK_2_0.md`. Leftovers (KNOWN_ISSUES 43):
- chain-link fences (block movement, not bullets or sight);
- denser interiors;
- wear on the older Blender props.

**Current focus (owner request, 2026-10-29):** four maps furnished and worn with Blender props (small details, furniture, structural damage) at full performance, the character's own arms in first person, a Blender picture for every item, and Tarkov's inventory/stash/trader layout (own art and fonts). Pinewatch is parked (kept in the repo, out of the vote). Order:

1. **First-person arms** = the character's block arms. **Done** (Weapon.luau `bodyArm`; evidence FP01–FP05).
2. **Blender material pipeline.** **Done.** Kit props split by material (no UVs needed: Roblox materials tile by studs on meshes, measured), baked vertex AO and grime, five new MaterialVariants (`docs/PIPELINE.md`).
3. **Meridian Mall.** **Done (2026-10-29), playable.** 86-prop Blender kit in three batches, 621 props placed, two levels, atrium, cinema, supermarket, about 20 stores, food court, service corridor, docks, roof car park, generator power, 6 exfils, 5 keys, 47 containers, the Caretaker; tests and frame rates in `docs/maps/MERIDIAN_MALL.md` and `TEST_RESULTS.md`. Possible polish later: a lower-poly product set for the shelving (KNOWN_ISSUES 46).
4. **Items.** **Done (2026-10-29).** A Blender model and picture for all 124 items (two atlas sheets, `ItemIcons.luau`), shown in every grid, slot, drag ghost, detail strip and trader row; loose loot lies as the real models (three batches, `ItemMeta.luau`; worn gear as the character meshes). `docs/items/ITEM_ART.md`, evidence I01–I07.
5. **Inventory, stash and trader screens** in Tarkov's layout (gear slots around a character view, grids with item pictures, names, counts and durability, context menus, examine). **Next.**
6. **Border Yard** built with MapKit/TerrainKit and the Blender props.
7. **Quay 7 and Smelter** furnishing and damage pass.

Performance rules for all of it: instanced meshes, low poly with baked shading, shared textures, near-player clutter scaled by the GRAPHICS level, few real lights, an FPS check after each map.

Maps are original. They are the same kinds of places as Tarkov's with their own layouts, landmarks and names; Battlestate's layouts, art, icons and fonts are not copied.

## M13 Maps

1. **Map system:** `World` builds one map per raid (gameplay geometry, spawns, exfils, loot, containers, doors, AI posts and patrols, cover). Queued players vote for the next raid's map; ties are random. Map modules share `Maps/MapKit` (walls, slabs, stairs, roofs, furniture, trucks, fences) and `Maps/TerrainKit` (voxel terrain from a height function).
2. **Smelter** (factory-type): furnace halls, catwalks, tunnels, offices; short raids, close fights. Playable.
3. **Pinewatch** (woods-type): built, parked by the owner (2026-10-29).
4. **Meridian Mall** (mall-type): playable (2026-10-29).
5. **Border Yard** (customs-type): a checkpoint, two dorm blocks, a fuel depot, warehouses, a river. Designed.

## After that

- **M11 part B:** weapon durability, malfunctions (misfire, failure to feed, jam; cleared with R), trader repairs and the repair kit (hideout).
- **M14 Weapon art:** Blender gun meshes on the WeaponModels anchors (R-17 and P-9 first).
- **M15 QA:** two-client test, device emulation, performance, exploit regression (vault speed checks), scrollable inventory gear column, docs, git bundle backup.
- Still to check from M10: rain streaks, lens droplets and environment sounds in a rainy raid.

## Resume steps

1. Read `DEVELOPMENT_STATUS.md` and `KNOWN_ISSUES.md`.
2. Start `rojo serve --port 34873` in `Documents\EscapeFromBloxov`; open `Zero Return.rbxl` and connect the Rojo plugin.
3. Play, then run `ZR_Dev:Invoke("tests")`. Baselines: LogicTests **167/167**, CharTests **38/38**, LookTests **19/19**, MapTests 32/32 (30 during a raid).
4. If the laptop's shell tool is missing, sync files with `tools/pc_patch.py` (a bundle run through Blender's Python). Rojo then carries `src/` into Studio. `tools/studio_patch.py` can patch Studio directly for quick tests; sync the PC afterwards.
