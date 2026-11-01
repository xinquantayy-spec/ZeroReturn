# Test Results

Unless noted otherwise, every test ran in a Roblox Studio playtest with:

- one local client, player "wurdo0"
- an unpublished place, so the in-memory profile store was used
- the `ZR_Dev` and `ZR_ClientDev` bridges plus real mouse and keyboard input through Studio MCP

**NOT VERIFIED:** real DataStore, two or more clients, phone, tablet, console hardware, gamepad UI navigation, device emulator, and performance on devices (only indicative Studio frame rates on the T490 laptop, M12).

## Frame time in Studio: where it goes (2026-11-01, Meridian, KASSA)

Studio on the T490, Play mode (client and server in one process), Studio quality 10, the mall's power on. The owner's floor is 30 fps.

| Measure | Result |
|---|---|
| KASSA view (aisles to the checkouts) | 18 to 19 fps |
| Same spot looking straight up (almost nothing drawn) | 28.8 to 29.3 fps: about 34 ms a frame is not drawing |
| Server step | heartbeat scripts 0.6 ms, physics 2.2 ms |
| Client scripts | about 3 ms (heartbeat and render-step work) |
| Other maps removed from the server | no change (17.8 against 18.0) |
| Detail decals off | no change; lights off: no gain; shadows off: +0.6 fps |
| Stores L1 hidden | +3.3 fps (about 8 ms of drawing) |

So drawing KASSA costs about 20 ms, the game's scripts and physics about 6 ms, and the rest of a 55 ms frame is Studio and engine overhead
that the Roblox app does not have. The real client's frame rate is still to be measured (a Clients and Servers test, or the app).
Added after this: HOLD 30 FPS (on by default) lowers the GRAPHICS level a step whenever a device stays under 30 fps for 8 s.

## Meridian Mall on Interchange (2026-11-01)

Studio on the T490, one client, in-memory store.

| Check | How | Result |
|---|---|---|
| Automated | `dev:Invoke("tests")` with every part in | LogicTests 287/287, CharTests 46/46, LookTests 19/19, MapTests 38/38 (M05 failed before the stores added containers) |
| Build | Server log | The map model holds 18,400 parts and builds in 8 to 9 s: ground (612,000 terrain columns), outside, the mall shell (5,360 parts, 149 lamps, 65 doors, 84 units), stores L1 (941 props, 250 containers, 233 loose spots), stores L2 (662 props, 148 containers, 165 loose spots), play, dress; no errors |
| Fixes found by testing | Server log, screenshots | The shell stopped on an undefined glass colour (no walls, signs or stock rooms); the car park floor slabs were coplanar with the terrain (a camouflage pattern); barbed wire from the detail plan on the balustrades and ruin-grade cracks on every wall (now NoWire and the clean profile: 33,818 detail entries down to 10,962) |
| Raid with AI | Raid on Meridian, the Caretaker forced on; positions after three minutes, ray down from every unit | 6 guards (car park, dock, substation, garage, concourse on L1, gallery on L2), the Caretaker in BOLTWORKS, 4 scavs; scavs walked 260 to 915 studs, up to L2; every unit on a floor or the ground; no errors |
| Power | `switch MALL_POWER` | The shell's 149 lamps light; the five electric locks wait for it |
| Look | Screenshots | KASSA's aisles and checkouts, the L2 gallery over the atrium with the food court, the car park; the deep halls are very dark even with power |
| Frame rate | RenderStepped count, Studio quality 10 | 12 to 16 fps in the mall with about 16,800 parts streamed in, the same range as Border Yard that session. Indicative only |

**Not verified:** every exit walked by hand (SHELTER EXIT's power and valve chain, FENCE GAP without a backpack, the paid car), the IRONSIGHT alarm, keyed doors by hand, phones, two clients.

## Border Yard on Customs, and the eyewear slot (2026-11-01)

Studio on the T490, one client, in-memory store.

| Check | How | Result |
|---|---|---|
| Automated | `dev:Invoke("tests")` | LogicTests 241/241, CharTests 46/46, LookTests 19/19, MapTests 38/38 |
| Border Yard build | Server log | 25,822 parts in 4.8 s: ground (423,000 terrain columns, roads, rail, fences, 700 trees, 780 bushes, bridges, boundary), living quarters (43 buildings, 440 kit props, 127 doors, 223 containers), industrial side (9,357 parts, 428 kit props, 139 doors, 311 containers), gameplay (12 spawns, 6 routes, 6 posts, 118 scav zones, the Broker and 4 guards, 15 propane, 6 sniper strips), dressing (40 wrecks, 134 cover pieces); detail plan 27,586 entries in 10 s; AI cover 8,474 points (map in play first) |
| Look | Aerial screenshots of the whole map, the industrial centre and the dorms | Customs' layout recognisable: rail lines, the Derrick, the Frame, the stores, Block A and B round the car park, the river |
| Fixes found by testing | Server log, MapTests | an invalid terrain material (Pebble) stopped the whole terrain; barbed wire on the power cables; the cover test ran before the big map was sampled; 7 loose loot spots floating (now dropped onto the surface or removed) |
| Eyewear | Showroom dummies | Sunglasses, range glasses, BG-1, AF-2 and the gas mask sit right on the block head; CharTests C01 finds every ZR_EyeGear mesh |

**Not verified:** a full raid on Border Yard with AI walking the new routes through the buildings, frame rates there and on phones (343 lamps across the buildings), two clients.

### Border Yard raid with AI (2026-11-01, later)

One PMC raid on Border Yard (night, rain, autumn, the Broker forced on), five minutes of AI time, player in god mode at the Bastion.

| Check | How | Result |
|---|---|---|
| Spawns | `dev:Invoke("ai")` 20 s in | 6 watch guards (3 posted: checkpoint, army post, Bastion; 3 on routes: fuel stop, stores, trailers), the Broker with 4 guards at the dorms, 4 scavs; a scav wave added 3 more by minute 5; 10,139 cover points ready |
| Movement | Positions after 304 s, ray down from every unit | Scavs walked 119 to 1,058 studs, route guards 69 to 136, posted guards held their posts, the Broker group stayed round the dorms; every unit stood on ground (terrain or a floor, 3.2 studs above it); none stuck or fallen through |
| Errors | Output window | None from the game (only the known Baseplate texture warning) |
| Server cost | Stats on the server, Script Profiler | Lua heartbeat 0.7 ms a frame, physics step 8.3 ms (761 moving parts, all characters); scripts are not the bottleneck |
| Frame rate | RenderStepped count, Studio (client and server in one process), Studio quality 10, same night and rain | Border Yard centre 13.2 to 13.6 fps (18,653 parts streamed in, 205 lights), 18.6 looking at the sky; Quay 7 16.4 and 22.4 at the same moment (2,516 parts). Lights, particles, post effects, water and the detail layer off each changed it by under 1 fps; shadows off gave +2. The laptop ran about half as fast as in earlier sessions (Quay 7 was 36.8), so only the ratio means anything: Border Yard costs about 20% more than Quay 7 |

**Not verified:** fights on the new map (AI combat is covered by LogicTests elsewhere), phones, two clients.

### Mounted guns (2026-11-01, later)

| Check | How | Result |
|---|---|---|
| Automated | `dev:Invoke("tests")` | LogicTests 276/276 (35 new stationary checks), CharTests 46/46, LookTests 19/19, MapTests 38/38 |
| On the Bastion roof | Raid on Border Yard; real F key and mouse through Studio | The prompt "[F] MAN THE GUN · HMG-12 'BASTION'" shows when you look at the gun; F mounts it (camera at the gun's sights, HUD "HMG-12 'BASTION' · 100 / 100 · F TO LEAVE"); holding the left button fired 15 rounds in about 1.3 s (belt 100 to 85, Tarkov's Utyos is 650 rounds a minute); F leaves and the prompts come back |
| AI | `dev:Invoke("ai")` with the player on the roof | The two posted gunners fought the player with their own rifles; neither took a gun, as the player stood behind the guns' arcs |

**Not verified:** the grenade launcher by hand, gamepad and touch controls, AI gunners firing a mounted gun at a target in its arc, the sight picture (the receiver block hides part of the view under the reticle; placeholder art).

### Border Yard underground entries (2026-11-01, later)

| Check | How | Result |
|---|---|---|
| BUNKER K-13 | Lever thrown, bunker doors opened; pathfinding and a walk with `Humanoid:MoveTo` from the top of each flight to the exit zone | **Bug found and fixed:** the open-tread flight ran into the west wall between its handrails, so a player walking down was boxed in at the bottom (pathfinding: no path). Both flights now stop 4.5 studs short of their shaft's end. After the fix: paths from the tops of both flights; the walk down the open flight reached the exit zone (30 waypoints, none missed) and the extract ran (raid report: extracted) |
| BOILER CELLAR | Boiler house door opened; pathfinding from the cabin to the exit zone | A path exists (37 waypoints down the dog-leg stair). The walk itself could not be checked: in that play session the character ignored `MoveTo` everywhere, the open cellar hall included, so it was a test-harness state, not the map. Still to check by walking it |

### Item pictures, sheet 4 (2026-11-01, later)

| Check | How | Result |
|---|---|---|
| Pictures | Rendered in Blender, review sheet by eye; then the stash in Studio with the items given and examined | All 44 new pictures (five eyewear items, the goggle strap, the propane cylinder, 37 Border Yard keys) show in the stash at their grid size with durability bars; unexamined keys show as dark silhouettes, as designed; every item in `Items.luau` now has a picture (258 in 4 sheets) |

## Bunker graphics: clean shell, grime where it gathers, no flicker (2026-11-01)

Studio on the T490, one client, in-memory store. Before and after captures B01 to B04 were taken in the session (not kept as files).

| Check | How | Result |
|---|---|---|
| Automated | `dev:Invoke("tests")` | LogicTests 224/224 (2 new: shell plain with the paint in the walls and no slits; grime placed with the clean profile), CharTests 38/38, LookTests 19/19, MapTests 38/38 |
| Shell | Server count | 98 shell parts, 0 with a worn MaterialVariant, 0 paint slabs, 197 DetailSpots |
| Decal depth | Client audit of every decal face in the bunker (260) | 0 overlapping pairs closer than 0.02 studs (3 found and fixed in the first pass: two tunnel damp strips level with the corner bands, a crack level with a doorway scuff) |
| z-fighting pass | Server log | Pulls skip hidden faces: relay7 175 to 43, quay7 211 to 108, smelter 459 to 273, meridian 1327 to 513, border 825 to 203; WallPaint and WallLine keep their full height |
| Look | Screenshots of the corridor (same spot, before and after), the ops room and the hideout | Painted walls (olive band, dark line, light plaster), plain floor and ceilings; grime in the corners and along the wall feet, soot over the generator, oil in front of it |

**Not verified:** flicker by eye while walking (a moving effect; the audit is geometric), phones.

## Lobby: Relay 7 bunker (2026-10-31)

Studio on the T490, one client, in-memory store.

| Check | How | Result |
|---|---|---|
| Automated | `dev:Invoke("tests")` | LogicTests 195/195 (11 new: under 300 kit props, at most 6 shadow lights, every prop built from its meshes, no prompt through a wall, every station has its prompt, 12 beds/lockers/spawns, departure rows 24 flaps, all four rows filled, each booth is its lane, no lane downrange, 13 targets none hidden), CharTests 38/38, LookTests 19/19, MapTests 32/32 |
| The bunker built | Server count | 293 kit props, 0 fallback boxes, 30 lights (6 casting shadows) |
| Rooms | Screenshots of every room | Bunks and locker row, ops room with boards and table, traders' hall with NPCs, corridor, hideout (dark with emergency light at generator level 0), gunsmith, range, motor pool with van and ramp |
| Shared screens | Server read-back and screenshots | Departure board "NO RAID ... RELAY 7 / NEXT RAID ... BOARD THE VAN"; roster "1/12 ON SERVER"; map sheets readable from the south side; locker card shows the callsign |
| Your side | Screenshots | Mirror orbit; R-17 clamped in the vise by its magwell; four stash guns in the rack; hideout labels "YOUR WORKBENCH · NOT BUILT" |
| Range | Fired from booth 2 | Practice ammo 25 then reload to full; display "HITS 1/8 · TIME 00:01.1", then "GROUP 26.5 CM · TIME 00:00.8"; shots outside a booth are not scored |
| Van | Boarded with the prompt | Queued, dashboard countdown, toast "IN THE VAN · STEP OUT TO LEAVE THE QUEUE", departure fade, landed on Quay 7 with REC on |
| Frame rate | RenderStepped count, render quality 21 | Bunker 20 fps (212 draw calls, 53k triangles) against Quay 7 12 fps (572, 107k) at the same moment; lights or props off changed it by under 2 fps. Indicative only |

**Not verified:** two clients (shared screens, squads boarding, others seeing the doors slam), phones, the scav hatch run to the end, a full hideout with every module built.

## M14 Weapon modding and guns as parts (2026-10-29)

Studio on the owner's T490 laptop, one client. Design and fidelity check: `docs/weapons/WEAPON_MODDING.md`.

| Test | Method | Result |
|---|---|---|
| Suites | `ZR_Dev:Invoke("tests")` | **LogicTests 184/184, CharTests 38/38, LookTests 19/19, MapTests 32/32.** |
| Modding rules | LogicTests M14 block (32 checks) | Pass. Starter rifle is a full default build (5x2); a 9 mm suppressor is refused on the 6.2 barrel (WRONG_FIT); a rail optic is refused on the pistol (NO_SLOT); the 6.2 suppressor swaps the flash hider to the stash and makes the rifle 6x2; reflex then 4x scope swap; stats (suppressed, 4x, quieter, less recoil); quad rail replaces the carbine handguard; a light dropped on the equipped gun lands on the rail; the free-float handguard is refused over the front-sight gas block (CONFLICT); barrel off with its parts makes the gun inoperable and lighter; a barrel with a suppressor is bigger than the bare barrel; the whole build moves as one bundle; a magazine dropped on the holster loads it; presets arrive as builds; tube capacity comes from the tube; in raid a pistol grip is locked without a multitool (detach and drag both refused), a flash hider is not, and with a multitool the grip comes off. |
| Asset loading | Server log | Pass. "792 meshes loaded, 0 batches failed": the seven gun batches add 187 pieces. |
| 2D pictures | Every preset drawn large through `UiKit.gunPicture`; stash capture | Pass. Each preset shows its own parts (R-17 patrol, marksman and close-quarters builds, KS-7 tactical and quiet, Harrow tactical, SMG-9 tactical, P-9 tactical, Tundra marksman and scout). A stripped rifle keeps 5x2 (standard magazine outline); a marksman build is 6x2. |
| First person | Raid on `quay7` with the R-17 patrol build | Pass. The viewmodel is built from the 14 part meshes plus the magazine; hip and aimed views; the RS-1 reflex dot sits on the bore line. |
| Third person | Orbit camera | Pass. The character holds the same build (quad rail, vertical grip, flash hider). |
| Loose loot | Raid on `quay7` | Pass for magazines (built from their part meshes); no loose gun or part rolled in the checked raid. |
| Modding screen | `ZR_ClientDev modding` on the R-17 marksman build | Pass. 3D gun, slot boxes with leader lines, stats (ergonomics 45, recoil 72/26, 10 MOA, 800 m, 942 m/s, 650 RPM, 4.42 kg, 6x2, 6x, loud, ready to fire). Dark polymer parts now use their sprites; tiny parts keep their close-up renders. |
| Console | Output | No ZR errors. |
| Not verified | – | Phones, two clients, trader preset rows on screen, every part fitted by hand in the modding screen. |

## M13 Item pictures and loose loot models (2026-10-29)

Studio on the owner's T490 laptop, one client. Pipeline and details: `docs/items/ITEM_ART.md`. Captures: `docs/items/evidence/I01`–`I07`.

| Test | Method | Result |
|---|---|---|
| Suites | `ZR_Dev:Invoke("tests")` in a raid | **LogicTests 167/167, CharTests 38/38, LookTests 19/19, MapTests 30/30.** |
| Coverage | `atlas.json` against every item id | Pass. 124 of 124 items have a picture; 95 have a loose loot model, the 22 worn items use the character meshes, the 7 weapons the weapon model. |
| Asset loading | Server log | Pass. "605 meshes loaded, 0 batches failed" (three mall kits plus the three item batches, 235 item meshes). |
| Stash and gear | Inventory screen in the safehouse, capture `I01` | Pass. Pictures fill each item's footprint, turned items show turned pictures, unexamined items are dark silhouettes, the selected item's picture is in the detail strip, and dragging shows the picture. |
| Traders | Relay radio, capture `I02` | Pass. Every offer and barter row has its item's picture. |
| Loose loot | Raid on `meridian`, capture `I03` | Pass. Wires on a VOLTA shelf lie as the Blender model with baked contact shading; the TAKE prompt works on the invisible pick box. Items are anchored with no collision or raycast hits. |
| Review sheets | `zr_item_reg.sheet` | All 124 pictures on stash-style sheets (`I04` weapons and ammunition, `I05` gear, `I06` medical, food and keys, `I07` loot). |
| Console | Output | No ZR errors. |
| Not verified | – | Phones (picture readability, memory), two clients. |

## M13 Meridian Mall (2026-10-29)

Studio on the owner's T490 laptop, one client, raids on `meridian` started through the dev bridge (`map`, `deploy`). Screenshots: `docs/maps/evidence/M01`–`M08`.

| Test | Method | Result |
|---|---|---|
| Suites | `ZR_Dev:Invoke("tests")` | **LogicTests 167/167, CharTests 38/38, LookTests 19/19, MapTests 32/32** (30 during a raid). MapTests now cover the mall: built, spawns on floors with head room, exfils over floors, every side with an open exit, loose loot resting on surfaces (snapped at build), containers and keyed doors live, AI zones, cover points, detail plan. |
| Build | Server log | Pass. The mall builds in 0.24 s: 2,407 parts and 1,810 kit meshes (621 props of all 86 kinds), 47 containers, 53 prompts. All three kit batches load (370 meshes, 0 failed). |
| Generator | Real prompt (`InputHoldBegin`, 3 s hold) | Pass. "GENERATOR STARTING", prompt disabled; 9 s later lit lights 47 → 123 and 288 ceiling panels glow; the raid info reaches the client with CARGO LIFT `powered = true` and the player gets "POWER ON". **Bug found and fixed:** the exits list kept saying NEEDS POWER until the next raid-info update; the server now sends it when the power comes on. |
| Cargo lift exit | Teleport into the zone | Pass. With power: extracted after 7 s. Fresh raid without power: still in the raid after 12 s. |
| AI paths | PathfindingService with the AI agent (radius 1.6, height 5.6, no jumping); `aiGoto` | Pass: L1 ↔ L2 (escalators, collapse slope, stair cores), yard → L2, car park → lobby, ground → roof car park over the ramp; a scav sent from L1 to the L2 gallery arrived. **Fixed:** the cinema seating (1.3-stud risers) had no path to the back or the projection booths; a side aisle with half steps and a wider booth door fixed it, and the PROJECTION visit point moved off the projector. |
| Barbed wire | Detail plan | **Fixed:** the plan put 173 barbed-wire pieces on the mall's facade bands, parapets and gallery edges; the mall now opts out (`NoWire`), 0 left. |
| Muzzle flash (owner request) | Fired the R-17 in a raid, `ZR_Fx` probe, capture `W01` | Pass. First person: a 0.12-stud round glow (was a 0.35 cube), light range 9 / brightness 1.6 (was 12 / 2.5), exposure kick halved. Other shooters: 0.22 round glow. No errors. |
| Frame rate | RenderStepped count, Studio (client and server in one process), our HIGH | Mall 25.6–31.4 fps at Studio's render quality 21, 45.8–57.7 at quality 10, 60 (the cap) at quality 5, against Quay 7 30.1 / 60 / 60. Before the pass: atrium 23–24 / 45, gallery 22–23 / 43–47. Table and cost breakdown in `docs/maps/MERIDIAN_MALL.md`. Indicative only. |
| Console | Output | No ZR errors. New warnings: `rbxassetid://111777818918264` fails to load (HTTP 502 or "being generated") and is not referenced by any instance (KNOWN_ISSUES 48); the two new floor maps returned HTTP 502 once and loaded after a retry. |
| Not verified | – | Phones and consoles; two clients; a full 25-minute raid with players fighting through the mall. |

## M12 Look 2.0 (2026-10-29)

Studio on the owner's T490 laptop. Details and screenshots: `docs/look/LOOK_2_0.md`, `docs/look/evidence/L01`–`L11`.

| Test | Method | Result |
|---|---|---|
| Suites | `ZR_Dev:Invoke("tests")` | **LogicTests 167/167, CharTests 38/38, LookTests 19/19.** LookTests: the graphics level through the real dispatcher (0 and 3 accepted, 1.4 rounds to 1, 9 clamps to 3, −4 to 0, a string refused); the published detail plan (count, cells, known images, library meshes, clutter clear of loot, containers, doors, exfils and spawns, 164 KB < 400 KB); no server-side detail; 28 solid cover props using the meshes, clear of spawns and exfils; a shot at a car wreck stops at the wreck. |
| Detail plan | Server log | Pass. 2,024 entries in 63 cells, 164 KB, 1.24 s at server start. AI cover points 834 → 1,018 with the new props. |
| Detail layer | Client `detail` probe, captures | Pass. HIGH builds about 1,000–1,700 details near the camera and none from the safehouse under the map. Streaks, grime, cracks, puddles, rubble, graffiti, wall fittings and container rust render (`L01`, `L02`, `L04`, `L05`). |
| Graphics setting | Real settings screen (mouse clicks), captures | Pass. GRAPHICS shows HIGH by default; four clicks on − reach POTATO (clamped); + returns to HIGH. POTATO removes the detail, the worn materials (681 parts), shadows and clouds; leaving it restores all 681 (`L03`, `L07`). |
| Worn materials | Test wall of every variant | **Bug found and fixed.** Five of the eight variants rendered almost black although each texture loaded on its own. New roughness maps fixed them (`L08` before, `L09` after). |
| Cover props | Top-down and ground captures | Pass. 28 meshes placed and tinted; no overlaps with map parts; clear of spawns, exfils, AI paths, loot spots, containers and doors (`L10`). |
| Lamps | Night raid (22:30), light-state sampling | Pass. The relay gate lamp stays dark; a flickering lamp dipped twice in 8 s (0.24 s dark), the others burn steady (`L06`). |
| Frame rate | RenderStepped count, Studio on the T490 (client and server in one process) | South yard: HIGH 36.8, MEDIUM 43.1, LOW 45.4, POTATO 58.9 fps. Harbor Stack: 33.5 / 39.4 / 42.6 / 58.2. The detail layer itself costs about 3 fps there. Indicative only; no device numbers. |
| Not verified | – | Phones, tablets and consoles at HIGH (the owner's default); two clients seeing the same detail. |

## M16 Characters and equipment (2026-10-28)

The full C01–C12 table with evidence levels and paths is in `docs/character/TEST_REPORT.md`.

| Test | Method | Result |
|---|---|---|
| Logic suite | `ZR_Dev:Invoke("tests")` | **167/167 pass**, including the block-body proportion and support-hand reach checks with 1.35× third-person weapons. |
| Character checks | `ZR_Dev:Invoke("chartests")` | **38/38 pass**: C01 import and sizes, C02 layering, C03 equip/replace/unequip and per-slot diff, C04 delayed-load fallback and reconcile, C05 invalid requests through the real dispatcher, C06 idempotency, C07 hits ignore gear, C09 presets and 480 seeded kits, C12 churn. |
| Presets | Showroom captures (front, side, back, close-ups) and Blender renders | Pass: operator, scavenger, guard, bodyguard and Foreman are distinct and reuse one rig. Heavy kit (face-plate helmet, Bulwark armour with collar and arm guards, raid pack) and a hooded scav variant were also captured. |
| Poses with gear | Showroom with the real animator | Pass. Covered: idle, aim, walk, sprint, crouch, crouch-aim, prone, look up with the raid pack (neck limit), look down, pistol. No detached gear. |
| In raid | Deploy and give through the dev bridge | Pass. Helmet, headset (behind the neck) and gaiter appear on the character. First person hides all 41 own parts locally. Viewmodel sleeves are block meshes in the outfit colour. |
| Death, respawn, reload | `kill`, `rejoin` | Pass. The corpse keeps all 11 gear pieces. The safehouse respawn wears the remaining profile kit with no duplicates. A profile reload keeps the appearance. |
| Safehouse requests | Real `inv` dispatcher | Pass. Equipping a shell, patrol pack and carrier shows on the character. A headset under the shell is refused (HELMET COVERS EARS). Quick move to stash works again; it was always refused before. |
| Restart | Play stop → start | Pass. The five presets look identical before and after. |
| Inventory | Tab through MCP keyboard input | Pass (structure). EARS and FACE slots render and are selectable. |
| Not verified | – | Two or more clients (C06 late join, a second observer for C08), touch and controller emulation (C11), devices and performance. |

## M10 World (2026-10-28, in progress)

| Test | Method | Result |
|---|---|---|
| Logic suite | `ZR_Dev:Invoke("tests")` | **146/146 pass** (12 new: 7x raid clock and midnight wrap, daylight curve, valid environment rolls, AI sight day > fog > night and hearing dulled only by rain, crew weapon lights in valid kits, 56 loose spots with valid pools, every pool item exists, 8 dorm doors with real keys, vault keycard, key spots roll keys). |
| Time and weather | `env` dev command, screenshots | Pass. Noon clear, overcast afternoon, dusk 18:10, rainy night 22:48 and clear night 22:30 all render; the REC stamp follows the raid clock; street lamps on at night. Night fill was retuned after the first test was near black (Roblox lights in linear space). |
| Lens and HUD | Screenshots | Pass. HUD text straight; grain halved; vignette lighter and neutral (no colour); colour fringing tried and removed at the owner's request. |
| Dormitory | Screenshots, real F key | Pass. Two storeys, rooms 101–204, balcony and stairs; a scav inside room 102 opened its closed door and walked out (AI door use). |
| Loose loot | `loose` list, real F key | Pass. 17 items spawned around the map; MATCHES taken from a dorm desk went to the pockets as found-in-progress; the prompt reads TAKE · MATCHES. |
| Vault | Real F key with office key then keycard | Pass. Office opens with the key; the vault prompt reads SWIPE CARD; the card reader LED turns from red to green, the door opens onto two safes and the arms crate; the prompt then reads CLOSE. |
| First-person arms | Screenshots | Pass. Round sleeves, elbow, cuff and gloves instead of thin sticks. |
| Not verified | – | Rain streaks, lens droplets, the new lens textures, the env sound atlas and the Blender gear meshes: the PC's DNS failed during testing, so Studio could not download them. |

## M9 Economy (2026-10-28)

| Test | Method | Result |
|---|---|---|
| Logic suite | `ZR_Dev:Invoke("tests")` | **134/134 pass** (19 new: XP curve and levels, skill bonuses, trader prices by loyalty, best buyer, quest items unsellable, fence karma pricing, dog tag value by level, data consistency (every offer, barter, task, recipe and module references real items), run-through rule, loyalty from level/spend/standing, give/consume stash, sell quote, task status/complete/hand-in with FIR items, storage racks → stash 10x25; the scav cooldown test now expects the karma-adjusted cooldown). |
| Buying | `dispatch trade buy` (real dispatcher) | Pass. P-9 Vesna 11,875 MK (250,000 → 238,125), 2 × 60 FMJ (−18,000), SMG then SMG again → OUT_OF_STOCK (limit 1 per restock), KST rifle → LOCKED (loyalty 2). |
| Barter | Hale: Road Kit for 2 cigarettes + matches | Pass. Without items → "Missing: Cigarettes."; with them → traded. |
| Selling | Spark plug, gold chain | Pass. Plug sold to the best buyer (+2,250); an unexamined chain is refused ("Examine it first."); VOS refuses loot; after examining, the chain sold for +31,000 to the best buyer. |
| Tasks | First Aid (Hale) | Pass. Accept → turn-in refused while incomplete → 2 dressings + 1 kit found-in-raid → turned in: +12,000 MK, +400 XP, Hale standing +0.05, the Road Kit reward reached the stash as found-in-raid. Locked tasks refuse ACCEPT. |
| Task progress | Signal Check (kill 5 scavs) | Pass. A scav shot in a raid moved it to 1/5 immediately (toast), before extraction. |
| Hideout | Build generator → storage → workbench, craft FMJ | Pass. Missing items / missing generator / busy builder refused with the right message; each build finished with `hideoutNow`; stash grew to 10x25; craft refused a second recipe while busy and early collection; collected 60 FMJ. Money 198,375 → 18,375 (−40k −80k −60k). |
| Screens | Relay radio (VOS, HALE, PROFILE tabs), workbench | Pass (screenshots). Offers with price and stock, loyalty requirements, tasks with status, progress and rewards, XP bar, skills, karma; hideout modules with requirements (have/need in green/red), build timers, crafts. Fixed: long requirement lines were cut off (now full width, two lines); the restock timer froze when the screen was reopened. |
| Locked door | Depot office, real F key | Pass. Without the key: "LOCKED · REQUIRES HARBOR OFFICE KEY", door stays shut; with the key: "UNLOCKED · DEPOT OFFICE", door swings open, the office light and safe are reachable. Fixed: the on-screen prompt kept saying UNLOCK after the door opened. |
| Run-through | Extract after 1:53 with one kill | Pass. "EXTRACTED (RUN THROUGH)" with the explanation line; loot kept, nothing found-in-raid. Fixed: the report still listed a picked-up key under FOUND IN RAID. |
| Dog tag | PMC KIA | Pass. Body B1 holds DOGTAG {name, level}; the player's own report no longer lists the tag as lost or found. |
| Console | Output log | No ZR errors. |

## M8 AI 2.0 (2026-10-28)

| Test | Method | Result |
|---|---|---|
| Logic suite | `ZR_Dev:Invoke("tests")` | **115/115 pass** (10 new: faction rules incl. player-scav truce and provocation, Watch vs player scavs, AI truce, guard/boss/crew loadouts valid and loaded with spare magazines, skill ordering). |
| Spawning | Raid start, `ZR_Dev ai` | Pass. 3 Watch (mezzanine overwatch post, two patrols), the Foreman + 2 crew on boss raids (otherwise a depot Watch patrol), 4 scavs at points of interest away from insertion points; cover map 834 points (interiors included). |
| AI vs AI | Earlier build without the truce | Watch and scavs wiped each other within a minute; switched to a truce (AI never target AI). Verified afterwards: no AI-vs-AI engagements. |
| Engagement | Studio god-mode target 60 studs from a Watch guard | Pass. Spotted after ~0.5 s, crouched at range, fired bursts (16 → 0), reloaded from the rig (2.9 s) to a fresh 22-round magazine, kept firing. |
| Lethality | Real damage, player standing in the open | A scav SMG and a Watch R-17 each brought the player from 440 to ~180 in a few seconds; deaths credited "KILLED BY HARBOR WATCH · R-17 · HEAD" / "KILLED BY SCAV · Harrow-12 · 12/70 Buckshot". Accuracy and reactions were lowered after this test. |
| Boss group | Forced boss raid, target inside the depot | Pass. Foreman and crew patrol in formation; on contact they take cover (cover=true), alternate crouch and peek, reload, search the last known position, then push the player's position. First-person screenshot shows the crew aiming from the dock doors. |
| Out of ammo | Scav with a single magazine | Pass. Emptied the magazine, found no spare, fled to a far point of interest. |
| Boss loot | Kill the Foreman | Pass. Body container created with his full kit. |
| Performance | Server stats with 10 AI fighting | Heartbeat callbacks 0.44 ms, physics step 3.3 ms, physics 60 FPS (Studio, client and server in one process). |
| Console | Output log | No ZR errors. |

## M7 Multiplayer raids (2026-10-28)

| Test | Method | Result |
|---|---|---|
| Logic suite | `ZR_Dev:Invoke("tests")` | **105/105 pass** (17 new: scav kit, scav deploy keeps the PMC loadout, cooldown, scav extract to stash with FIR, scav death leaves the PMC untouched, insure item + mag, insure-all quote, non-insurable secure container, insured gear collected from a body, only insured parts return, claim waits for the delay, claim delivers to the stash). |
| Queue → raid | Real `deploy` request | Pass. IDLE → MATCHING (12 s countdown on the HUD and terminal: "YOU ARE QUEUED · INSERTION IN 00:08") → RUNNING; west spawn with exfils A, B, E, F; chance exfil F rolled closed. |
| Queue lock | Discard and redeploy while queued, then cancel | Pass. QUEUED errors; cancel returns to IDLE and the discard then succeeds. |
| Late entry | Deploy while the raid runs | Pass. Entered directly (`entered: true`). |
| Exfil rules | Teleport into F (closed), E (no key), B (paid) | Pass. F and E refused (session stays ACTIVE); B extracted after 6 s and charged 8,000 MK (250,000 → 242,000). Exfils outside the session's list do nothing. |
| Exits list | O key, screenshot | Pass. Names with requirement text and colour (PAY 8,000 MK, KEY REQUIRED, MAY BE UNAVAILABLE). Fixed: the list now hides again after 6 s. |
| KIA body | Dev kill | Pass. Lootable body B1, the corpse copy stays in `ZR_Corpses` after the hideout respawn (41 parts, frozen); orbit screenshot shows the ragdoll with [F] SEARCH · BODY. |
| Empty raid | Kill the only raider | Pass. Raid ended after ~8 s (`EMPTY`), bodies and corpses cleared, insurance settled into 1 claim. |
| Insurance (KIA) | Insure all (−11,439 MK), die, raid ends, claim | Pass. The insured kit returned to the stash with magazines and rig contents; uninsured ammo did not; invariant OK. |
| Insurance (MIA) | Insure an SMG, deploy, expire the shared clock | Pass. MIA, claim created immediately, SMG returned after the claim. |
| Player scav | Deploy as scav, extract at D (scav-only) | Pass. Random kit (Tundra bolt rifle, rig, bag, junk), scav clothes and cap, no bodycam, full health, all 6 exfils, 10-min cooldown; the kit went to the stash; stats scavRaids 1 / scavSurvived 1. |
| HUD size | Screenshots before and after | Pass. Vitals, recorder line, clock/money, exits and status text are larger (scaled for small windows) and stay in the margins. |
| Console | Output log | No ZR errors. |

## M6 Movement & animation (2026-10-28)

| Test | Method | Result |
|---|---|---|
| Logic suite | `ZR_Dev:Invoke("tests")` | **88/88 pass** (6 new rig-math tests: arm IK reach, full-body solve, stance hip heights, stand/prone eye height, lean offset, crouch ankle planting). |
| Operator rig | Server and screenshots | Pass. Players load the StarterCharacter rig (15 Motor6D, Blender meshes, no AnimationConstraint conversion); guards use the same rig in navy kit. |
| Third-person animation | Orbit camera on self and a patrolling guard | Pass. Walk cycle with planted feet, rifle held in both hands at low ready; crouch, prone and lean poses (screenshots). |
| Server hitboxes | Prone, check Motor6D.C0 on the server | Pass. Root pitched −88°, head 0.78 studs above the floor and 1.39 forward. |
| First-person eye | Prone and lean | Pass. Prone eye 0.84 studs high and 1.69 forward; lean right rolls and shifts the view. |
| Vault | Space facing a jersey barrier | Pass. Carried over the barrier (x −13.3 → −7.6), no jump stamina spent. |
| Walking speed | Mouse wheel ×3 | Pass. Speed step 10 → 7, walk speed scaled. |
| Arm stamina | Aim for several seconds | Pass. Arms drain while aiming (HUD shows ARMS), recover when lowered. |
| Sound atlas | Preload + live sounds | Pass. 25.6 s atlas loads; guard footsteps play as positional regions. |
| Ragdoll | Guard health to 0 | Pass. 14 joints become ball sockets, body falls, lootable with [F] SEARCH. |

## M5 Weapons 2.0 (2026-10-28)

| Test | Method | Result |
|---|---|---|
| Logic suite | `ZR_Dev:Invoke("tests")` | **82/82 pass** (14 new: mounts, caliber-specific muzzle devices, swap returns old part, mod stats, slot drops, bundles keep mods, mag onto holster). |
| Weapon switching | ClientDev `switch` primary → holster → melee → secondary | Pass. Server `active` follows; draw time blocks firing; third-person weapon in hand, long guns slung. |
| Auto-draw | Drop the weapon in hands via the real `inv` dispatcher | Pass. Next weapon drawn, visuals refreshed. |
| Magazine reload | Fire 6, press reload | Pass. 19 → 25 with the rig magazine; predicted count used for the spare check. |
| Tube reload | Harrow-12 empty, reload | Pass. Shells loaded one by one (0 → 2 → 6); bolt rifle loads the same way. |
| Pump / bolt | Fire Harrow-12 and Tundra | Pass. Rounds 6 → 4 and 4 → 3; cycling animation gates the next shot. |
| Mag check | T / ClientDev `magcheck` | Pass. Timed check, HUD shows the estimate text. |
| Knife | ClientDev `slash` | Pass. Swing animation, server melee request. |
| Attachments | `inv` op `mod` with suppressor, reflex, light, then 4x scope swap | Pass. Mod stats on the server (loud 0.35, recoil 0.93); third-person parts 13 → 18; old reflex returned to the grid on swap. |
| Optics | Aim with reflex, then 4x | Pass. Reflex dot overlay; scope overlay with FOV 25.8° and zoom-scaled sensitivity (screenshot). |
| Weapon light | L / ClientDev `light` | Pass. Viewmodel SpotLight; server attribute and third-person light on. |

## Automated

| Suite | Result |
|---|---|
| `src/server/Tests/LogicTests.luau` (inventory, settlement, escrow, finalize idempotency, migration, recovery kit, grid) | **38/38 pass** |
| `tools/luau_check.py src` (structural block and bracket check, 41 files) | pass |

## Gameplay loop (2026-10-28)

| Test | Method | Result |
|---|---|---|
| Deploy | Real click on `Btn_DEPLOY` | Pass. Loadout escrowed, spawned at WEST/SOUTH, 3 guards spawned. |
| Loot | E prompt → timed server search → TAKE ALL | Pass. Items moved to the raid inventory, invariant OK. |
| Combat | ClientDev fire; guard killed | Pass. Shots accepted, ammo tracked on the server, kill credited, body lootable. |
| Reload | R key | Pass. Swapped to the 25-round mag, 31 rounds spare. |
| Movement | WASD and Shift | Pass. Sprint drains stamina; walking regenerates it. |
| Extraction | Stand in zone for 6 s | Pass. EXTRACTED dossier shown, profile credited, simulated rejoin identical. |
| Death (KIA) | Dev kill | Pass. Dossier shown, at-risk gear lost, respawned in the safehouse. |
| MIA | Dev expire timer | Pass. Gear lost. |
| Safehouse | Recovery kit, fill magazines, move items in the UI | Pass |
| Save retry | `ZR_Dev saveRetry` with 2 injected write failures | Pass. A critical save succeeded on attempt 3 after 1.5 s. |
| Save retry, exhausted | 5 injected failures | As designed. All 4 attempts failed (`STORE_ERROR:SIMULATED_FAILURE`); the profile stays dirty so autosave retries later. |
| Crash mid-raid | `ZR_Dev crash`: session dropped without settlement, live profile discarded, profile reloaded from the store | Pass. Before the crash, the stored copy already held `pendingRaid` (saved before spawn). On reload it was settled as DISCONNECTED: the 6 escrowed items were lost, `pendingRaid` was cleared in the store, the invariant held, stats show raids=1 / lost=1, and the player respawned in the safehouse at 100 HP. |

## Abuse and exploit probes

All probes ran through the real dispatcher (`ZR_Dev dispatch` / `shotAbuse`). Inventory invariants held after every probe.

| Probe | Result |
|---|---|
| Deploy spam while in raid | ALREADY_IN_RAID |
| Two concurrent takes of the same item GUID | One OK, one GONE. Exactly 1 copy. |
| Sell while in raid | NOT_AUTHORIZED |
| NaN coordinates, unknown op, nested payload, oversized string, unknown action | BAD_INPUT |
| Take from an unsearched or distant container | TOO_FAR |
| 20 shots in the same tick | 1 accepted |
| Replayed shot sequence, NaN direction | Rejected |
| Shot origin 500 studs away | Clamped to the head |
| 30-request flood | 4 accepted, 26 throttled |

## Audio (2026-10-28)

| Test | Result |
|---|---|
| `ContentProvider:PreloadAsync` on all 7 sound IDs | All **Success**. Lengths match the source files (fire 1.35 s, far 2.05 s, reload 2.35 s). |
| In raid: 3 shots and a reload | 3 R17_FIRE instances and 1 RELOAD instance created |
| Ambience | 1 looping ambience track playing |
| Extraction hold | Countdown beeps played (4 captured); summary shown |
| UI click on RETURN TO SAFEHOUSE | Click sound played; modal closed |
| Console | No ZR errors. The only warning is the Baseplate texture warning (203785492), which predates this project. |

## Assets

- **Meshes:**
  - Batch A (9 meshes) and the crate load through InsertService ("9 meshes loaded, 0 batches failed").
  - The world dropped from 1,530 to 648 parts.

## M11 part A: grenades (2026-10-28, Studio, single client, in-memory store)

| Test | Result |
|---|---|
| Logic tests | **164/164 pass** (18 new: landing and rolling to rest, throw distances, wall bounce, path sampling and interpolation, lob/flat aiming, fragment falloff and counts, stun facing and walls, smoke growth and line-of-sight blocking, rig-before-pockets pick and no backpack, item/trader/loot/craft wiring, AI carry rates). |
| Asset loading after the DNS fix | All 31 Blender meshes load ("0 batches failed"); the operator body uses the Blender model; players wear the gear meshes (vest, pouches, body camera, pack, holster are MeshParts); the new vignette and edge haze textures show. |
| Pin pull and hold (client bridge `nade`) | The weapon drops out of view; the right hand brings up the RK-5 with its top above the glove; the HUD reads "RK-5 · RELEASE G TO THROW · HOLD RMB: UNDERHAND". |
| Throw | The server took the grenade from the pockets, simulated the path and exploded it after the fuse (`nades`: thrown/exploded counters). |
| Third person | Orbit view of your own character: right hand raised by the head holding the grenade (held grenade 0.18 studs from the hand), rifle lowered. |
| Frag damage | An RK-5 at about 7 studs: one fragment struck the left arm for 23 (heavy bleed, fracture, pain), everything else untouched. Matches the expected 2-3 hits at that range. |
| Stun | A ZS-3 at 8 studs in view: the picture washed out and blurred, then recovered. |
| Smoke | A DS-2 filled the alley with a dense white screen that hides the far end. |
| AI evasion | Two scavs next to a dropped RK-5 ran out of its radius before it went off (no damage). |
| AI flush (`nadeDrill`) | Found by the Foreman or a Watch guard, then hidden behind full cover: the Foreman threw once about 4 s after losing sight; the Watch guard threw twice. Before the fix, units with grenades only in their backpack never threw ("noNade"); AI now use grenades from the backpack and pick a stun charge when the target is too close for a frag. |
| Console | No new errors. The only warning is the Baseplate template texture (203785492). |
