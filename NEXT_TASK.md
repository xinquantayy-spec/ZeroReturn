# Next Task

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

**Current focus (owner request, 2026-10-28):** milestone **M13 Maps**. The owner wants at least four locations. Each new map gets the M12 treatment from the start: worn materials, cover props and the detail plan (`DetailPlan.generate` after the build).

Maps are original. They are the same kinds of places as Tarkov's (factory, forest, industrial outskirts) with their own layouts, landmarks and names; Battlestate's layouts are not copied.

## M13 Maps

1. **Map system:** `World` builds one map per raid (gameplay geometry, spawns, exfils, loot, containers, doors, AI posts and patrols, cover). Queued players vote for the next raid's map; ties are random.
2. **Smelter** (factory-type): furnace halls, catwalks, tunnels, offices; short raids, close fights.
3. **Pinewatch** (woods-type): pine forest, a lumber yard, a lake, a bunker, a crashed convoy; big and open.
4. **Border Yard** (customs-type): a checkpoint, two dorm blocks, a fuel depot, warehouses, a river.

## After that

- **M11 part B:** weapon durability, malfunctions (misfire, failure to feed, jam; cleared with R), trader repairs and the repair kit (hideout).
- **M14 Weapon art:** Blender gun meshes on the WeaponModels anchors (R-17 and P-9 first).
- **M15 QA:** two-client test, device emulation, performance, exploit regression (vault speed checks), scrollable inventory gear column, docs, git bundle backup.
- Still to check from M10: rain streaks, lens droplets and environment sounds in a rainy raid.

## Resume steps

1. Read `DEVELOPMENT_STATUS.md` and `KNOWN_ISSUES.md`.
2. Start `rojo serve --port 34873` in `Documents\EscapeFromBloxov`; open `Zero Return.rbxl` and connect the Rojo plugin.
3. Play, then run `ZR_Dev:Invoke("tests")`. Baselines: LogicTests **167/167**, CharTests **38/38**, LookTests **19/19**.
4. If the laptop's shell tool is missing, sync files with `tools/pc_patch.py` (a bundle run through Blender's Python). Rojo then carries `src/` into Studio. `tools/studio_patch.py` can patch Studio directly for quick tests; sync the PC afterwards.
