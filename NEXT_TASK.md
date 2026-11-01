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

**Placement pass (owner, 2026-11-01: "ensure nothing is placed abnormally or glitching"): three rounds done 2026-11-02 by 01:00 SGT** (b263a00, 7115c6d, b3d7111; `docs/look/PLACEMENT.md`; TEST_RESULTS "Placement audit and tidy pass"). A tidy pass runs on every map at server start. ZR_Dev `audit` and `tidylog` report what is left.

Fixed:
- terrain in Border's underground rooms;
- THE SUBSTATION's plinth;
- doors in solid walls, and doors swinging into walls or containers (each door now hangs the way that opens widest);
- the pump platforms inside the fuel tanks;
- containers drawn as 4-stud crates;
- the Smugglers' Hole and old pumps cellar layouts;
- pushes out of walls going the wrong way;
- trees on roads, and fences through buildings.

Audit now: Meridian, Smelter and Quay 7 are clean. Border has 5 clips under 1 stud, 3 fence pieces against slab edges, and the rail spur into THE DEPOT (meant to be there).

Next round (`KNOWN_ISSUES` 69):
- walk the re-hung doors, with AI paths through them;
- the 7 props the pass leaves;
- off-centre kit origins, builder by builder;
- the fuel stop safe against the desk;
- ~~the road boards~~: **done 2026-11-02**. Roads on both maps follow the smoothed relief and lie level across (`Maps/RoadBeds.luau`, TEST_RESULTS "Road beds"). ZR_Dev `roadaudit` checks them.

**Now, in order:**
1. **Meridian polish:** per-key loot and the key pictures are done. Fuller small shops are done and checked in Studio (`StoresFill.luau`, +1,938 parts). Lighting in the deep halls with the power on was checked on 2026-11-01 in the separate client: NESTA and KASSA by day, and KASSA at 23:00, all read as lit halls. **Exit walk-through done 2026-11-02** (TEST_RESULTS "Meridian exit walk-through"): every spawn reaches every exit it may use, each rule refuses and then lets the player out, exits have their own timers (8 s standard, saferoom 3 s, fence hole 10 s), and three exits were rebuilt to look right (the saferoom, the fence hole, the tunnel portal on the railway). Left: KNOWN_ISSUES 71. **Border Yard's 26 exits were walked the same way the same night.** Also done that night:
   - tunnel portals wherever a railway meets the hills or the boundary rock (Meridian 2, Border 5);
   - barriers on every road into the rock (Border 13, Meridian 8);
   - a roadblock at ARMY ROADBLOCK and a boat at SMUGGLERS' BOAT;
   - trees cleared off the rail beds;
   - client clutter kept out of door swings;
   - the detail plan streamed with the map (Meridian's is 970 KB).
2. **THE STOKER (Meridian's second boss, our Tagilla): done 2026-11-02**, checked in Studio with one player (TEST_RESULTS "THE STOKER"; gaps in `docs/design/BOSS_STOKER.md`). Decisions taken:
   - the welding mask is a face cover (`kind = "facecover"`), and `Health.armorFor` lets a face cover with `zones.face` protect the face, as in Tarkov;
   - `W.bosses` is a list, each boss rolled on its own (`AI.reset`), and `W.boss` stays for the old readers;
   - the hammer charge goes in `AI.combat`: within 15 m with a clear line, sprint (18) straight at the target and swing with the "slash" gesture, the blow through `Combat.hitModel`;
   - health through `opts.hp` (1,220 / 440 = 2.77).

   No new meshes can be uploaded from the cloud (Open Cloud needs the owner's key), so his look reuses existing gear, logged as a gap.
2b. **Done 2026-11-02, after the Stoker, all checked in Studio:**
   - road beds on both maps: roads follow the smoothed relief and lie level across (`Maps/RoadBeds.luau`, ZR_Dev `roadaudit`);
   - placement round 5 on Border: the fuel stop office, STORE 3, STORE 7, the motor shop stores, the Red Stores and Old Pumps (`docs/look/PLACEMENT.md`);
   - airdrops: Tarkov's plane and four crates on Border and Meridian (`docs/design/AIRDROPS.md`).

   Also done after these:
   - the red flare calling an airdrop (`docs/design/AIRDROPS.md`);
   - AI paths into Border's boiler cellar and bunker K-11 (KNOWN_ISSUES 68). All 26 Border exits are now reached from every spawn.
   - THE HOUNDS, Border Yard's Goons: three bosses at 20 % from the Bastion, Tarkov's health, kits and five double pockets (`docs/design/BOSS_HOUNDS.md`).
   - The green flare and flare exits: NORTH LINE and RIVER PATH open by flare, OLD PUMPS sends up green flares while it is there (`EFT_PARITY.md`, "Flare exits").

   Left from these:
   - KNOWN_ISSUES 72: grass blades inside STORE 3;
   - KNOWN_ISSUES 73: the ambience atlas is silent until the owner re-uploads it.
3. **Performance on phones:** Border Yard and Meridian stream 16,000 to 18,600 parts near the player (KNOWN_ISSUES 65); try a smaller streaming radius in Studio's Workspace settings and merge plain walls, then measure in the device emulator.
4. **Border Yard polish:** dorm interiors are done (furniture, washrooms, doors, glass; checked in Studio 2026-11-01). Still to do: the 0.16 interiors elsewhere, ladders, and the AI paths on Border stairs (KNOWN_ISSUES 68; the boiler cellar was inspected 2026-11-01).
5. **Mounted guns, the rest:** the grenade launcher by hand, gamepad and touch, AI gunners firing a mounted gun, Blender art.
6. Then the remaining parity list in `EFT_PARITY.md`: hideout customisation, co-op extracts and transits, other boss groups (cultists, the partisan; the Goons are done), yellow flares for quests (the green flare and flare exits are done).

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
