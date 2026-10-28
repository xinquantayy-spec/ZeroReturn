# Next Task

**Current focus (owner request, 2026-10-28):** milestone **M12 Look 2.0**, then **M13 Maps**. The owner wants Tarkov-level wear and imperfection on every building and model, at least four locations, and a game that still runs on phones, consoles and PCs (with an opt-in Potato mode; phones keep the full look by default).

Maps are original. They are the same kinds of places as Tarkov's (factory, forest, industrial outskirts) with their own layouts, landmarks and names; Battlestate's layouts are not copied.

## M12 Look 2.0

1. **Blender wear kit** (`assets/blender_scripts/build_wear_kit.py`): modular, vertex-coloured pieces with baked dirt and AO, slightly uneven and damaged.
   - Building: chipped concrete wall caps and corners, cracked panels, spalled columns, patched repairs, broken window frames with glass shards, rusted corrugated sheets (dented, holed), bent railings, sagging cable runs, pipes with brackets, rusted downpipes, broken lamp heads.
   - Ground: rubble piles, broken pallets, tyres, trash bags, paper, cans, oil drums (dented, rust bands), cinder blocks, rebar, cracked asphalt patches, puddles.
   - Interior: broken chairs, desks with drawers out, filing cabinets (dented), lockers, mattresses, radiators, fallen ceiling tiles, wires hanging.
2. **Grime textures** (`assets/textures/gen_wear.py`): tiling transparent overlays (water streaks, rust runs, soot, peeling paint, moss, cracks, oil stains, graffiti tags of the game's own factions) used as `Texture` objects on part faces.
3. **Detail layer:** the server builds gameplay geometry only; each client adds cosmetic detail (clutter, debris, stains) from a seeded list, sized to the graphics setting.
4. **Potato mode** (Settings → GRAPHICS: POTATO / LOW / MEDIUM / HIGH): no detail layer, no blur/DoF/sun rays/bloom, fewer particles, simpler fog, shadows off. Opt-in only.
5. **Quay 7 pass:** wear, clutter and lighting imperfections across the whole map; screenshots for the owner.

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
3. Play, then run `ZR_Dev:Invoke("tests")` (baseline **164/164**).
