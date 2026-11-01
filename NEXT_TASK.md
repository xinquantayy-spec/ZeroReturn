# Next Task

**Standing rule (owner, 2026-10-31):** as close as possible to Escape from Tarkov in every aspect, less the exceptions in `docs/design/EFT_PARITY.md`. Research how Tarkov does it before each task; check the result against it before moving on; log the gaps in `EFT_PARITY.md`.

**Done 2026-11-01:** the bunker graphics pass (painted walls, grime only where it gathers, no flicker; `docs/maps/RELAY7_LOBBY.md`), and before it the z-fighting pass, real-size air-con and stairs, Quay 7 interiors, bullet drop and zeroing, seasons, propane cylinders and border snipers on Border Yard.

**Done 2026-11-01 (later):** Border Yard rebuilt on Customs' layout at real scale (`docs/maps/BORDER_YARD.md`), Tarkov's EYEWEAR slot with glasses, ballistic glasses and a gas mask (meshes uploaded).

**Done 2026-11-01 (afternoon):** Meridian Mall rebuilt on Interchange's layout at real scale (`docs/maps/MERIDIAN_MALL.md`: ground and outside, the mall shell with the car park, 84 units, both store levels, gameplay with 7 exits and THE CARETAKER), mounted guns on Border Yard's Bastion (`docs/design/STATIONARY_WEAPONS.md`), item pictures for the eyewear and the Border Yard keys, the K-13 stair fix. GitHub `xinquantayy-spec/ZeroReturn` is the remote (owner allowed pushing, 2026-11-01).

**Resumed 2026-11-01 23:03 SGT (automated run, check-ins every 2 hours; no computer use).** The order was:
1. **Wallpaper repeat: done 2026-11-01 23:15** (clean tiles uploaded, more decal patches on papered walls; checked in Studio, docs/look/WALLS.md).
2. **Weapon mastering:** research done, nothing built: `docs/design/MASTERING.md`.
3. **Meridian's second boss (THE STOKER, our Tagilla in KASSA GARAGE):** research done, nothing built: `docs/design/BOSS_STOKER.md`. One decision is open there (the welding mask's slot).
4. Then the list below. Done today and checked in Studio: see-through foliage (all levels but POTATO), FOG weather closing the view at 480 studs with the map beyond it hidden, detail rings shortened (about 30 % fewer draws in wide views), car exits (one player), breakable glass and the AI seeing through whole panes.

**Placement pass (owner, 2026-11-01: "ensure nothing is placed abnormally or glitching"): first round done 2026-11-02 00:20 SGT** (b263a00, `docs/look/PLACEMENT.md`, TEST_RESULTS "Placement audit and tidy pass"). A tidy pass runs on every map at server start. ZR_Dev `audit` and `tidylog` report what is left. Fixed: terrain in Border's underground rooms, THE SUBSTATION's plinth, doors in solid walls and doors swinging into walls or containers, the pump platforms inside the fuel tanks, and containers drawn as 4-stud crates. Next round (`KNOWN_ISSUES` 69):
- Fix the 62 pieces of Border furniture still touching walls, in their builders (`tidylog border left`).
- Fix the 8 containers against walls.
- Walk the 30 re-hung doors.
- Check Living.luau's office rooms.
- Check outdoor placement: trees and props on roads, fences through buildings.

**Now, in order:**
1. **Meridian polish:** per-key loot and the key pictures are done. Fuller small shops are done and checked in Studio (`StoresFill.luau`, +1,938 parts). Lighting in the deep halls with the power on was checked on 2026-11-01 in the separate client: NESTA and KASSA by day, and KASSA at 23:00, all read as lit halls. Still to do: a walk-through of every exit by hand.
2. **Performance on phones:** Border Yard and Meridian stream 16,000 to 18,600 parts near the player (KNOWN_ISSUES 65); try a smaller streaming radius in Studio's Workspace settings and merge plain walls, then measure in the device emulator.
3. **Border Yard polish:** dorm interiors are done (furniture, washrooms, doors, glass; checked in Studio 2026-11-01). Still to do: the 0.16 interiors elsewhere, ladders, and the AI paths on Border stairs (KNOWN_ISSUES 68; the boiler cellar was inspected 2026-11-01).
4. **Mounted guns, the rest:** the grenade launcher by hand, gamepad and touch, AI gunners firing a mounted gun, Blender art.
5. Then the remaining parity list in `EFT_PARITY.md` (hideout customisation, MASTERING, co-op extracts and transits, other boss groups, Interchange's second boss).

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

Maps copy Tarkov's layouts (owner, 2026-11-01, now in the project instructions): same terrain, roads and building positions at real scale, with our own buildings, interiors and names; Battlestate's art, icons and fonts are not copied.

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
