# Next Task

**Standing rule (owner, 2026-10-31):** as close as possible to Escape from Tarkov in every aspect, less the exceptions in `docs/design/EFT_PARITY.md`. Research how Tarkov does it before each task; check the result against it before moving on; log the gaps in `EFT_PARITY.md`.

**Done 2026-11-01:** the bunker graphics pass (painted walls, grime only where it gathers, no flicker; `docs/maps/RELAY7_LOBBY.md`), and before it the z-fighting pass, real-size air-con and stairs, Quay 7 interiors, bullet drop and zeroing, seasons, propane cylinders and border snipers on Border Yard.

**Done 2026-11-01 (later):** Border Yard rebuilt on Customs' layout at real scale (`docs/maps/BORDER_YARD.md`), Tarkov's EYEWEAR slot with glasses, ballistic glasses and a gas mask (meshes uploaded).

**Now, in order (owner, 2026-11-01):**
1. **Meridian Mall on Interchange's layout**, the same way as Border Yard: research the current layout, then foundation, buildings and gameplay (`docs/maps/BORDER_CUSTOMS_BUILD.md` is the template). Pinewatch stays parked.
2. **Border Yard polish from playtests:** dorm interiors (glass, washrooms, denser furniture), the 0.16 interiors, ladders, the lamp count on phones, the K-13 and boiler cellar entries (KNOWN_ISSUES).
3. **Inventory pictures for the eyewear items** (item art pipeline, `docs/items/ITEM_ART.md`).
4. **Mounted machine guns** need a stationary-weapon system first (Customs has them).
5. Then the remaining parity list in `EFT_PARITY.md` (hideout customisation, MASTERING, co-op extracts and transits, other boss groups).

**Waiting on the owner:** a two-client test (Test -> Clients and Servers, 2 players), a low-end phone in the device emulator, saving the place now and then (uploaded meshes live in the place file). Decisions that can wait: publishing, a cross-server flea market (MemoryStore).

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
3. Play, then run `ZR_Dev:Invoke("tests")`. Baselines: LogicTests **241/241**, CharTests **46/46**, LookTests **19/19**, MapTests **38/38**.
4. Without a shell on the laptop (a cloud session linked through the desktop app): rebuild the git repository in the cloud workspace from `backup/` (join the three parts of `ZeroReturn_2026-10-31.gitbundle`, clone, then pull the newest incremental bundle whose base is in it), work there, write changed files to the laptop with the file bridge while Studio is in edit mode (Rojo carries them in), and write a new incremental bundle to `backup/` at each milestone (KNOWN_ISSUES 44).
