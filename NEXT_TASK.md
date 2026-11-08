# Next Task

**Standing rule (owner, 2026-10-31):** as close as possible to Escape from Tarkov in every aspect, less the exceptions in `docs/design/EFT_PARITY.md`. Research how Tarkov does it before each task; check the result against it before moving on; log the gaps in `EFT_PARITY.md`.

**NOW (2026-11-08): the audit's follow-up.**
- The research is in `docs/audit/2026-11-07/` (six area reports plus `SUMMARY.md`). The owner's picks are in the claude.ai
  report "Zero Return Audit" (https://claude.ai/artifact/WmgDqevdd2j53hAHfDzxGA; ArtifactData `list` on `choices`, `get`
  on `meta/general`): every quick win (start-2a), and the recommended option of every decision except art-3, where the
  block body stays (art-3a). Work goes in start-1a's order: release blockers first.
- Done (the section 7 entries of `docs/design/EFT_PARITY.md`, TEST_RESULTS): M1 release blockers; M2 lean servers
  (tech-4b) and phone menus (ui-3a); M3 quick wins in five batches; the Broker on Reshala's zones (ai.3); scav groups
  (ai.8); the mesh library split (tech.13).
- Checked in Studio 2026-11-08 (TEST_RESULTS): all of M3 batch 6, M4 batches 1-3 (ai-3a, gameplay-1a, ai-1a, ai-2,
  ai-7a, economy-2a, gameplay-2a), M4 batch 4 (Relay 7 counters for all eight traders, plates in the drag cue, pictures
  for every carried item, AI looting ai-8a, health and stamina indicators ui-1a) and the map-first tasks (economy-6a: 122
  tasks, 31 task places), gameplay-4b (four stims, fracture penalties, the stomach rule), gameplay-3a (sound through
  walls, piloted on Border Yard) and ui-6a (Tarkov's menu bar, every screen on a key) are on main; 12 suites, 911 checks
  pass. Studio's id is b79ee504-12b7-4e23-b725-da89d70d2f1a;
  Rojo serves on port 34873 (after a Studio restart the owner clicks Connect).
- Checked in Studio later on 2026-11-08 (TEST_RESULTS, pushed): art-8b, gameplay-5b (mounting, slow lean), gameplay-6b
  (recovery and insurance, merged from its thread), ui-8a and ui-2b (accessibility, recorder overlay), ai-5b (the
  Caretaker's KS-L, MORTAR's GL-6), economy-7b (EFT's 14 hideout modules, merged from its thread, all its requests
  applied) and economy-4b's experience side (EFT's level table to 79). 14 suites, 1,079 checks.
- Done later on 2026-11-08 (TEST_RESULTS, pushed): economy-1a's first seven slices (30 rounds; 54 barter goods with the
  hideout built from them; the KS-74 and the PM with 5.4x39 and 9x18; the SK-45 and the MR-10; the 7.6x51 calibre with
  the S-14 and the OB-7; the 9x39 calibre with the SV-9 and the AV-9; 4.6x30 and 5.7x28 with the PW-46 and the PD-57: 461 items, 18 guns, 70 rounds in 11 calibres),
  economy-3a (a flea market of real players across servers with an AI floor, built by a helper thread and merged),
  ui-4c (touch drag), the gamepad and touch slow lean, art-6a (first-person reload and check poses). 15 suites, 1,156
  checks.
- The owner's to try: the flea market between two servers needs a published place (publishing is the owner's call).
- In a helper thread since 17:20 SGT: economy-3a (the flea market with an AI floor; the first thread was stopped by the
  15:25 interrupt before it wrote anything). When its DONE is on the board: merge, apply its REQUESTs, run FleaTests.
- Next, in order: economy-1a's next slices (.366, .45 ACP, the Five-seveN, a revolver, more parts, the other barter goods, keys;
  more hideout crafts with them), ui-5a (tutorial raid), art-1a / 4b / 5b; bays and furniture in Relay 7 for the six
  hideout modules without one; bipods; ai-4a voices.
- Still open from those: trader portraits (no trader screen shows one yet); the TASKS tab, a plant, kills and a hand-over
  seen live (economy-6a); the touch layout and the monochrome scheme of the health figure (ui-1a); the device-emulator
  check of shadow-casting lamps (art.1, the owner's click); a Realistic-vs-Soft side-by-side in Edit mode, never a runtime
  switch (that hung Studio); kit origins (art.9); ZR_SFX_Amb (the owner checks why it reads as 0.0 s before any
  re-upload).
- Next: the other maps on Acoustic Simulation once Border Yard has been heard (gameplay-3a's pilot); tech-8c (a Luau
  runtime for tests) needs the owner's OK to build the official Luau from source.
- The gaps by area: `docs/design/EFT_PARITY.md` sections 8 (AI), 9 (core gameplay), 10 (economy) and 11 (art); the look
  rules for new art: `docs/look/ART_BIBLE.md`.
- Parked: the players' tripwire kit. The server side is merged on branch `wip/tripwire-kit`, the client is not built, and the branch is not on main.

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
   - THE CULT, Border Yard's cultists: a priest and two to four warriors at night, prone ambushes, poisoned knives and the antidote (`docs/design/BOSS_CULT.md`).
   - THE FORESTER, Border Yard's Partisan: a lone 950-health boss who hunts low karma, walks silently and leaves tripwires in doorways near his loop; the tripwires go off on a step, a shot or a blast and can be disarmed (`docs/design/BOSS_FORESTER.md`).
   - Tactical lasers and device modes (KNOWN_ISSUES 52): T and Ctrl+T, a beam and a dot for every laser, the AI's too; gamepad holds on D-right and D-left, touch LGT and NV (`EFT_PARITY.md`, "Tactical devices"). KNOWN_ISSUES 55 (zeroing, variable zoom) was already done and is closed.

   Left from these:
   - KNOWN_ISSUES 73: the ambience atlas is silent until the owner re-uploads it.
   (KNOWN_ISSUES 72, grass blades inside STORE 3, was fixed 2026-11-02: a bare-earth ring round every building.)
3. **Performance on phones:** Border Yard and Meridian stream 16,000 to 18,600 parts near the player (KNOWN_ISSUES 65); try a smaller streaming radius in Studio's Workspace settings and merge plain walls, then measure in the device emulator.
4. **Border Yard polish:** dorm interiors are done (furniture, washrooms, doors, glass; checked in Studio 2026-11-01). Still to do: the 0.16 interiors elsewhere, ladders, and the AI paths on Border stairs (KNOWN_ISSUES 68; the boiler cellar was inspected 2026-11-01).
5. **Mounted guns, the rest:** the grenade launcher by hand, gamepad and touch, AI gunners firing a mounted gun, Blender art.
6. Then the remaining parity list in `EFT_PARITY.md`: hideout posters, collectibles and range targets (the walls, floor and ceiling styles are done, as are the transits and co-op exits), the players' tripwire kit (Jaeger's; THE FORESTER's wires are done), yellow flares for quests (the green flare and flare exits are done). Customs' boss list is complete: the Broker, the Hounds, the Cult and the Forester.

**Waiting on the owner:** a two-client test (Test -> Clients and Servers, 2 players), a low-end phone in the device emulator, saving the place now and then (uploaded meshes live in the place file; art.10), re-uploading `ZR_SFX_Amb` (gameplay.17, KNOWN_ISSUES 73). Decided in the audit: a private test place (tech-1b), a budget Android phone to measure on (tech-2b) and a real flea market with an AI floor (economy-3a); publishing and any purchase still need the owner's go (rule 3).

**M14 weapon modding is done (part A, 2026-10-29).** Follow-ups from the fidelity check (KNOWN_ISSUES 53, 54, 57): folding stocks, saved builds with buying missing parts, part sizes against Tarkov's. 3D inspect (56) came with the INSPECT window on 2026-10-31. Laser beams and device modes (52) and zeroing and variable zoom (55) are done.

**M16 Characters (owner request, 2026-10-28) is done (part A).** Block body, Blender equipment set, server appearance system and role presets; see `docs/character/`. M16 part B is still to do:
- the two-client checks (C06, C08), which need a Studio Clients-and-Servers run by the owner;
- touch and controller emulation of the equipment screen (C11);
- a subtle fabric MaterialVariant;
- ~~eyewear and goggles~~: done 2026-11-01 (ZR_EyeGear);
- the marksman/scout and safehouse-worker presets;
- a stash character preview;
- a showroom profile with the expected character count, on real hardware.

**M12 Look 2.0 is done (2026-10-29).** Worn materials, cover props, the client detail layer, the GRAPHICS setting (since 2026-11-07 phones start at LOW, consoles at MEDIUM and PCs at HIGH; POTATO opt-in) and flickering or dead lamps. See `docs/look/LOOK_2_0.md`. Leftovers (KNOWN_ISSUES 43):
- chain-link fences (block movement, not bullets or sight);
- denser interiors;
- wear on the older Blender props.

**Current focus (owner request, 2026-10-29):** four maps furnished and worn with Blender props (small details, furniture, structural damage) at full performance, the character's own arms in first person, a Blender picture for every item, and Tarkov's inventory/stash/trader layout (own art and fonts). Pinewatch is parked (kept in the repo, out of the vote). Order:

1. **First-person arms** = the character's block arms. **Done** (Weapon.luau `bodyArm`; evidence FP01–FP05).
2. **Blender material pipeline.** **Done.** Kit props split by material (no UVs needed: Roblox materials tile by studs on meshes, measured), baked vertex AO and grime, five new MaterialVariants (`docs/PIPELINE.md`).
3. **Meridian Mall.** **Done (2026-10-29), playable.** 86-prop Blender kit in three batches, 621 props placed, two levels, atrium, cinema, supermarket, about 20 stores, food court, service corridor, docks, roof car park, generator power, 6 exfils, 5 keys, 47 containers, the Caretaker; tests and frame rates in `docs/maps/MERIDIAN_MALL.md` and `TEST_RESULTS.md`. Possible polish later: a lower-poly product set for the shelving (KNOWN_ISSUES 46).
4. **Items.** **Done (2026-10-29).** A Blender model and picture for all 124 items (two atlas sheets, `ItemIcons.luau`), shown in every grid, slot, drag ghost, detail strip and trader row; loose loot lies as the real models (three batches, `ItemMeta.luau`; worn gear as the character meshes). `docs/items/ITEM_ART.md`, evidence I01–I07.
5. **Inventory, stash and trader screens** in Tarkov's layout (gear slots around a character view, grids with item pictures, names, counts and durability, context menus, examine). **Done (2026-10-31).**
6. **Border Yard** built with MapKit/TerrainKit and the Blender props. **Done (2026-11-01)**, on Customs' layout.
7. **Quay 7 and Smelter** furnishing and damage pass. **Furnished (2026-11-01).** The owner's pick art-1a rebuilds Smelter on Factory's layout and keeps Quay 7 as the test map.

Performance rules for all of it: instanced meshes, low poly with baked shading, shared textures, near-player clutter scaled by the GRAPHICS level, few real lights, an FPS check after each map.

Maps copy Tarkov's layouts (owner, 2026-11-01, now in the project instructions): same terrain, roads and building positions at real scale, with our own buildings, interiors and names; Battlestate's art, icons and fonts are not copied.

## M13 Maps

1. **Map system:** `World` builds one map per raid (gameplay geometry, spawns, exfils, loot, containers, doors, AI posts and patrols, cover). Queued players vote for the next raid's map; ties are random. Map modules share `Maps/MapKit` (walls, slabs, stairs, roofs, furniture, trucks, fences) and `Maps/TerrainKit` (voxel terrain from a height function).
2. **Smelter** (factory-type): furnace halls, catwalks, tunnels, offices; 20-minute raids, close fights. Playable; an original layout until art-1a rebuilds it on Factory's.
3. **Pinewatch** (woods-type): built, parked by the owner (2026-10-29); art-1a rebuilds it on Woods' layout.
4. **Meridian Mall** (mall-type): playable (2026-10-29); rebuilt on Interchange's layout at real scale (2026-11-01).
5. **Border Yard** (customs-type): playable, on Customs' layout at real scale (2026-11-01).

## After that

- **M11 part B: built.** Weapon wear and heat, Tarkov's four malfunctions (found with L, cleared with Shift+T), trader repairs and the repair kit (`Combat.luau`). Tarkov's heat and malfunction rules added (gameplay.11) and the Studio malfunction check done (gameplay.12, 2026-11-08: a failure to eject at 20 % condition).
- **M14 Weapon art: done (2026-10-29).** 187 Blender part meshes; textures for first-person guns are art-4b.
- **M15 QA:** two-client test, device emulation, performance, exploit regression (vault speed checks), docs, git bundle backup. (The inventory columns scroll since 2026-10-31.)
- Still to check from M10: rain streaks, lens droplets and environment sounds in a rainy raid.

## Resume steps

1. Read `DEVELOPMENT_STATUS.md` and `KNOWN_ISSUES.md`.
2. Start `rojo serve --port 34873` in `Documents\EscapeFromBloxov`; open `Zero Return.rbxl` and connect the Rojo plugin.
3. Play, then run `ZR_Dev:Invoke("tests")`. Baselines (TEST_RESULTS, 2026-11-08, every map built): LogicTests **412/412**, CharTests **47/47**, LookTests **33/33**, MapTests **41/41**.
4. Without a shell on the laptop (a cloud session linked through the desktop app): rebuild the git repository in the cloud workspace from `backup/` (join the three parts of `ZeroReturn_2026-10-31.gitbundle`, clone, then pull the newest incremental bundle whose base is in it), work there, write changed files to the laptop with the file bridge while Studio is in edit mode (Rojo carries them in), and write a new incremental bundle to `backup/` at each milestone (KNOWN_ISSUES 44).
