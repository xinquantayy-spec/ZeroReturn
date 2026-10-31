# Border Yard (Customs layout)

The fourth map in the rotation. Rebuilt on 2026-11-01 on Escape from Tarkov's Customs as it stands after the 0.16 rework,
at real scale: the layout (where things stand, how big, which way they face, how many floors, the river, roads, rails,
extracts, spawns) is Customs', the buildings, names and art are ours (the owner's decision of 2026-11-01, see
`BORDER_CUSTOMS_BUILD.md`: same map, own buildings and names). The first Border Yard (600 x 340 studs, 2026-10-31) is gone;
its code is in git history (`git show 7e05113:src/server/Maps/BorderYard.luau`).

Status: part 1 of 3 (foundation) is written: layout data, ground, river, roads, rails, bridges, fences, power lines,
boundary, forests and rocks, all 26 extracts, PMC spawns and scav zones. Buildings (part 2) and the play layer and
dressing (part 3) follow. Part 1 was written without a Luau runtime: only `tools/luau_check.py` and the Python generator
have run, nothing has run in Studio yet, so every number below that depends on the engine (terrain look, part counts,
timings) is an expectation.

## Frame

- Reference: `docs/maps/reference/CUSTOMS_REFERENCE.md` and `customs_layout.json` (metres, x east, z south, north is -z,
  origin at the centre of the 1070 x 544 m map bounds). The building outlines come from a community map under CC BY-NC-SA
  4.0, drawn before 0.16: they are a layout guide only; the SVG and the raw data are never shipped.
- Scale S = 3.125 studs per metre. Map origin `O = Vector3.new(0, 0, -5200)`. Code uses map-local studs; `H.V(x, y, z)` adds O.
- Playable polygon: 97 vertices, x -1615..1585, z -846..846 studs (1024 x 542 m). Raid time 2400 s (40 minutes).
- Heights: local y 0 is the flat plain (game y 1.3), y = (game y - 1.3) x S. The south-west plateau stands up to about +39 studs
  and the river bed falls to about -47 at the south end (the reference relief, 54 knots). The map is built far from every other
  map (O.Z -5200).
- Terrain: 3600 x 1880 studs, 900 x 470 columns of 4 studs, y -72..168 (the playable box plus 100 to 170 studs of berm and
  cliff that close the view). Voids are cut for the underground rooms.
- `Layout.luau` is generated: edit `tools/customs_layout.py` and run `python3 -I tools/customs_layout.py` from the repo root.
  Its header explains every table (rotation, yaw, strides, grades A to D).

## Layout

Centres are map-local studs (x, z). Building names follow the table in `BORDER_CUSTOMS_BUILD.md`.

| Area | Centre | What stands there |
|---|---|---|
| Tank farm and BUNKER K-11 | -1430, -200 | FUEL TANK 1 to 4 with PUMP PLATFORM N and S; the PUMP HOUSE (2 floors, -1402, -298); the BUNKER K-11 shed (-1469, -307) over a tunnel |
| Watchhouse and Store 7 | -1250, -190 | WATCHHOUSE (2 floors, -1272, -108); STORE 7 (2 floors, -1228, -267) with its yard |
| Depot | -976, -101 | DEPOT (one floor, roof at 42 studs with a sniper spot); the SMUGGLERS' HOLE shed (-960, -259) over a tunnel |
| Army post | -1310, 150 | ARMY POST HUT (2 floors, sniper spot on the roof) and BARRACKS on the west road; the west edge exits OFFICE GATE, OLD CHECKPOINT, FAR CORNER, ARMY GATE |
| The ridge and pylon pad | -1060, 400 | The south-west plateau: RIDGE BOOTH, PYLON PAD with its booth, ROCK PASS and ARMY LINE exits, most of the rock outcrops |
| Store row | -640, -90 | STORE 3 (-715, -184), STORE 4 (2 floors, -540, -87) with the STORE 4 BASEMENT (room 173 x 56 studs) and the K-13 lever; the shared apron and two roadside shacks |
| Fuel stop | -773, 206 | FUEL STOP (the new gas station) with its forecourt |
| Old pumps | -540, -440 | OLD PUMPS (the old gas station) with sheds A and B, the forecourt and the cellar under it |
| The derrick | -350, -26 | THE DERRICK: 4 floors, 167 studs tall, roof spot at 158 studs |
| Bastion and BUNKER K-13 | -125, -300 | THE BASTION (2 floors, scav base) with its west yard; the BUNKER K-13 room under the ground north of it (-137, -357) |
| The frame | -124, 65 | THE FRAME (3 floors) with north and south aprons and a kiosk |
| Blocks | -130, 600 | BLOCK B (2 floors, -212, 578) and BLOCK A (3 floors, -62, 630) with the gatehouse and pad; DORMS CAR at -57, 782; BUS STOP booths and pad at -240, 272 |
| Works | 200, -80 | MOTOR SHOP + BOILER HOUSE (3 floors, boiler roof 47 studs, roof spot) with the BOILER CELLAR under it; STORE 17 (3 floors, 360, -94); OLD WORKS (2 floors, 261, 73); the huts kiosks; two garages and booths |
| The squat | 247, -379 | THE SQUAT (2 floors) and its kiosk |
| The hill and south road | 300, 400 | THE HILL, HILL ROADBLOCK booth (425, 474), ROADSIDE HUT, the road to the Scrap Bridge |
| River | 700, 0 | The river runs north to south (z -656 to 560, 35 to 145 studs wide); MAIN BRIDGE (x 677..781, z 125..136, 37.5 studs wide); SCRAP BRIDGE (two plank decks and the island at 728, 253); BRIDGE BOOTH A and B |
| Red stores | 1163, -273 | RED STORES (2 floors, 191 x 100 studs) and its yard; RED STORES CABIN A and B; the east gate and booth |
| Storage yard | 1400, -280 | STORAGE YARD: four storage blocks, three garage rows and a diagonal row |
| Trailer lot | 1250, -540 | TRAILER A to D, the shack, the shed and the garage row; the TRAILER LOT extract in the trees |
| Rail | whole map | 11 lines (10,100 studs), 6 level crossings; the east line stands on a 5.9-stud embankment; three lines converge at the north tip |
| North border | -50, -760 | The border snipers' danger zone, the flare area and the NORTH LINE exit |

What Ground (part 1) builds, in this order, each step under pcall so one failure leaves the rest standing:

1. Terrain from one 4-stud height grid that `B.ground(x, z)` also reads: relief, graded roads and rails, flat pads under every
   building and yard (blended over 16 to 22 studs), the east embankment, the river channel with banks and the island, berms and
   cliffs outside the boundary, voids for the underground rooms. Materials by area (grass, ground, leaf litter and mud under forests,
   gravel along rails and tracks, concrete under yards, asphalt under roads, sand and mud in the river, rock on steep ground).
   TerrainKit writes it time-sliced, so the server keeps running while it builds.
2. Roads: 34 polylines (2 highway 37.5 studs wide, 2 main roads 25, 16 small paved roads, 14 dirt tracks painted into the
   terrain). Asphalt boards along the paved ones, worn centre dashes, round patches at bends.
3. Rails: ballast, sleepers and two rails per piece; a plate at each of the 6 level crossings.
4. MAIN BRIDGE (concrete deck, parapets, two piers on the river bed, abutments) and SCRAP BRIDGE (two plank decks with rusty beams
   and railings, landing on the island).
5. Fences: 68 chain-link runs (8,170 studs), cut where they cross water or leave the boundary.
6. Power lines: lattice pylons for the 8 towers inside the map (of 12), sagging wires wherever a span has an end inside the map.
7. The boundary: 97 invisible walls (Transparency 1, solid, 400 studs tall) with the berm and cliff as the visible edge.
8. Nature kit: forests, bushes, lone trees and rocks (at most 700 trees and 900 bushes), with keep-out zones around buildings,
   extracts and spawn clusters.

Expected size: 423,000 terrain columns; about 560 road boards, 350 dashes and up to 60 bend patches; about 200 rail pieces of 4
parts; about 340 fence runs (about 2,400 parts); at most 700 trees; at most 900 bushes (aimed at 780); 126 rock sites; 97 boundary
walls. The init prints the real counts in one line (`[ZR] Border: ...`) when the map is built.

## Extracts (26)

Sides follow the reference. "east" and "west" name the half of the map a PMC spawns in (the exits are on the other side); "both"
serves both; "scav" is for scavs only. All 26 exist as `kit.extract` zones with the reference position.

| Id | Name | At (x, z) | Side | Rule here | Reference |
|---|---|---|---|---|---|
| K11 | BUNKER K-11 | -1469, -307 | east | open | always open; underground exit at the end of the tunnel |
| SH | SMUGGLERS' HOLE | -960, -259 | both | chance 50 % | secret exit; needs the Voron note found in the same raid |
| OP | OLD PUMPS | -469, -450 | east | chance 50 % | in the basement; not always available, opened with a green flare |
| DC | DORMS CAR | -56, 779 | both | paid 25,000 MK | 5,000 roubles per player, up to 4 players, 60 s shared timer |
| K13 | BUNKER K-13 | -137, -357 | both | power: lever `BORDER_STORE4` in Store 4 | lever in Store 4 (power stays on once thrown), then the basement door |
| CR | CROSSROADS | 1512, -134 | west | open | |
| TL | TRAILER LOT | 1468, -592 | west | open | in the trees |
| AR | ARMY ROADBLOCK | 571, -327 | west | open | sources disagree on its availability (grade C); the icon lies 56 studs past the limit |
| SB | SMUGGLERS' BOAT | 625, 474 | both | chance 50 % | secret exit; same Voron note as the hole |
| NL | NORTH LINE | -31, -766 | both | chance 50 % | green flare fired in the flare area, then keep to the tracks past the border snipers (grade C) |
| BC | BOILER CELLAR | 181, -48 | both | key `KEY_BY_BOILER` | scav cooperation: a PMC must bring a scav |
| OF, FC, OC, AG | OFFICE GATE, FAR CORNER, OLD CHECKPOINT, ARMY GATE | west edge, z -70, -400, 17, 507 | scav | scav | scav exits on the west edge; the icons of OFFICE GATE and ARMY GATE lie 17 and 77 studs past the limit |
| RP, AL | ROCK PASS, ARMY LINE | -1147, 717; -1006, 765 | scav | scav | south-west rim |
| OR, HR, PL, CL | OLD ROAD GATE, HILL ROADBLOCK, PORT LINE, CITY LINE | -81, 775; 446, 506; 951, 253; 1020, -581 | scav | scav | named in the build spec |
| S4, HG, S17, TS | STORE 4 GATE, HUTS GATE, STORE 17 GATE, SHACK GATE | -546, 28; -137, 148; 352, -151; 1289, -626 | scav | scav | names are ours (the spec names 21 of the 26 exits) |
| PG | PUMPS GATE | -469, -494 | scav | scav | name is ours; not always available in the reference (grade D) |

Every PMC side has an open exit (east K-11; west CROSSROADS, TRAILER LOT, ARMY ROADBLOCK). The five underground exits stand on
their room's floor (y -16). Scavs may use every extract. The reference puts four exit icons on or past the traced limit (ARMY GATE,
ARMY ROADBLOCK, OFFICE GATE, CITY LINE), which the invisible wall would make unreachable, and DORMS CAR 12 studs from it: the
generator pulls each in until its whole zone lies inside the wall (72, 91, 30, 15 and 2 studs; the note in `L.ext` says so).
STORE 17 GATE (352, -151) lies inside STORE 17's footprint: the building needs a gate bay there.

## Spawns

PMC spawns: four outdoor groups per half, as far apart as the reference's groups allow, each on the reference spawn point nearest
the group centre (the reference has 50 east and 70 west points in 10 and 14 groups; groups that sit inside buildings are skipped
for now). Names come from the nearest map label.

| Id | Side | Name | At (x, z) |
|---|---|---|---|
| E1 | east | STORAGE YARD | 1511, -590 |
| E2 | east | SCRAP BRIDGE | 555, 489 |
| E3 | east | MOTOR SHOP | 208, -223 |
| E4 | east | RED STORES | 1180, 108 |
| W1 | west | ARMY POST | -1507, 254 |
| W2 | west | OLD PUMPS | -402, -507 |
| W3 | west | FUEL STOP | -616, 592 |
| W4 | west | DEPOT | -1063, -78 |

Scav spawn zones: the reference's 12 scav zones (ARMY POST, RIVER BANK, HUTS CROSSROAD, EAST YARDS, BLOCKS, DEPOT YARDS, TANK FARM,
FUEL STOP, OLD PUMPS, THE BASTION, MOTOR YARD, THE FORD) give up to 103 dry land points inside the boundary (`W.scavZones`). The
reference's boss spawn points per zone and the bot-zone points are in `L.scav` for part 3.

## Not done yet

Part 2 (buildings agent): all 67 building spots in `L.blds` are empty ground (flat pads, nothing on them). The six underground
rooms are dug as voids (`L.under`: the K-11 and SMUGGLERS' HOLE tunnels, the OLD PUMPS cellar, the STORE 4 basement, the BUNKER K-13
room, the BOILER CELLAR) with their level-0 shafts, but have no walls, floors or loot. Stairs, floors, containers and loose loot
inside buildings, and the K-13 lever `W.switches.BORDER_STORE4` in Store 4 (until it exists BUNKER K-13 stays closed with the text
"NO POWER  ·  THROW THE LEVER IN STORE 4").

Part 3 (gameplay agent): AI routes and watch posts (`W.patrols` and `W.watchPosts` are empty, so the MapTests check for watch
posts and routes fails until they exist), the Broker and his crew (`W.boss` is none; reference: 40 %, zones BLOCKS, FUEL STOP,
THE BASTION, four followers), visit zones, border snipers (`L.snipers` and the danger zone `L.hazard.sniper`), propane cylinders and
mounted weapons (`L.hazard.propane` and `.mounted` are empty: no reference data yet), airdrops, outdoor loot, the dressing pass.

Parity gaps (to copy into `docs/design/EFT_PARITY.md`, which was outside part 1's scope):

- Co-op extracts and transits do not exist here yet (BOILER CELLAR is a plain key extract; in Tarkov a PMC must bring a scav).
- The Voron note for SMUGGLERS' HOLE and SMUGGLERS' BOAT, the green flare for NORTH LINE and OLD PUMPS, and the ZB-1013 key for the
  K-13 basement door have no items; the three exits are plain 50 % chance extracts and the bunker door is not locked.
- DORMS CAR costs 25,000 MK (the old map's price, kept); Tarkov charges 5,000 roubles, so check the MK scale in the economy.
- Mounted weapons (AGS, NSV), propane cylinders and the three other boss groups the reference lists (a knight with two escorts, a
  sect priest with four warriors, a partisan) are not built.
- Five scav exit names are ours (STORE 4 GATE, HUTS GATE, STORE 17 GATE, SHACK GATE, PUMPS GATE).
- The reference outlines are 0.12-era shapes and the extract positions are good to 5 to 10 m (grades in `L.blds` and `L.ext`).

Unverified (nothing has run in Studio yet): the TerrainKit change (time-sliced writes, a prebuilt height grid, per-column water) and
the whole Ground pass; the terrain relief is diffuse (a smooth blend of 54 knots, so peaks are lower than the reference); the river's
north end (z about -656, x 744..830) lies outside the playable boundary, so the berm and the channel overlap there; the AI cover
scan samples `W.bounds` (3,200 x 1,690 studs) at step 4, about 340,000 columns, which may be slow at server start; frame rate on a
low-end phone and memory use are untested.

## Files

| File | What |
|---|---|
| `src/server/Maps/Border/init.luau` | entry: model "Border", the context `B`, calls the four parts under pcall, sets `W.bounds`, prints counts |
| `src/server/Maps/Border/Layout.luau` | generated layout data (do not edit) |
| `src/server/Maps/Border/Ground.luau` | terrain, river, roads, rails, bridges, fences, power lines, boundary, nature |
| `src/server/Maps/Border/Buildings.luau` | stub for part 2 |
| `src/server/Maps/Border/Play.luau` | extracts, PMC spawns, scav zones (minimal); part 3 grows it |
| `src/server/Maps/Border/Dress.luau` | stub for part 3 |
| `src/server/Maps/TerrainKit.luau` | shared terrain writer, now time-sliced, with an optional prebuilt grid and per-column water |
| `src/server/Maps/BorderYard.luau` | stub of the old module (no longer built) |
| `tools/customs_layout.py` | reference JSON to `Layout.luau` |

The context `B` every part receives: `kit, W, map, H, Kit, L, O, S, rng, count, ground(x, z)`; Ground adds `inside(x, z)`,
`riverD(x, z)` (studs inside the river channel, negative on land), `slope(x, z)`, `T` (the TerrainKit result) and `islandTop`.

## Gameplay (part 3 of 3)

Written 2026-11-01 without a Luau runtime: `tools/luau_check.py` (structure only) and an offline Python mirror of the placement tests
(footprints, roads, fences, rails, forests, rocks, keep-outs; the parts inside the buildings are not in the mirror) have run, nothing has
run in Studio. The counts below are expectations from that mirror. `Play.luau` keeps part 1's extracts code and adds everything below; it
publishes its geometry helper as `B.geo` (distances to footprints, roads, fences, rails, forests and the boundary, open-ground and
footprint tests, keep-outs, the boxes of placed parts) for `Dress.luau`. Both read the buildings' named points from `B.points` and fall
back to the matching footprint centre in `L.blds` when one is missing (names used: BLOCK_A_LOBBY, BLOCK_A_ROOM314, BLOCK_B_LOBBY,
BASTION_YARD, FUEL_SHOP, OLD_PUMPS_SHOP, SQUAT, MOTOR_SHOP, RED_STORES, BOILER_CELLAR, DERRICK_TOP, FRAME_TOP, SMUGGLERS_HOLE; every
point in `B.points` also keeps the dressing 8 studs away). Each step runs under pcall, so one failing step leaves the others standing.
Look for `[ZR] Border play: ...` and `[ZR] Border dress: ...` in the server output.

### PMC spawns (12)

Six outdoor groups per half, picked farthest-first from the east or west rim (groups inside buildings are skipped: they would fail the
head-room test in MapTests), each on the reference spawn point with the most room within 30 studs of the group centre. Names come from
the nearest map label or yard, each used once. Six per side keeps a 12-player raid spread (`Match.pickSpawn` maximises the distance to
the others). Positions and names below are what the mirror gives; the names are assigned at run time.

| Id | Name | At (x, z) | Id | Name | At (x, z) |
|---|---|---|---|---|---|
| E1 | TRAILER LOT | 1511, -590 | W1 | ARMY POST | -1507, 254 |
| E2 | SCRAP BRIDGE | 555, 489 | W2 | OLD PUMPS | -402, -507 |
| E3 | MOTOR SHOP FORECOURT | 208, -223 | W3 | FUEL STOP | -616, 592 |
| E4 | RED STORES | 1180, 108 | W4 | DEPOT | -1063, -78 |
| E5 | RED STORES YARD | 972, -314 | W5 | PYLON PAD | -1133, 731 |
| E6 | STORAGE YARD | 1458, -170 | W6 | STORE 3 | -714, -258 |

E6 stands 10 studs from a building (the storage yard is crowded); E1, E4, W2 and W5 lie 20 to 30 studs from the boundary wall.

### Guard routes, posts and the Broker

Six closed routes along roads and yards, checked offline against footprints, fences, the river and the boundary (not against the
dressing or the real interior walls). A guard with a post stands at it; the others walk their route.

| Id | Where | Points | Guard |
|---|---|---|---|
| OC | OLD CHECKPOINT, the west road gate | 4 | post at -1498, 6 |
| AP | ARMY POST, between the hut and the road | 5 | post at -1256, 118 |
| BG | THE BASTION, the gravel ring round the bunker yard | 10 | post at `BASTION_YARD` |
| FS | FUEL STOP forecourt | 4 | walks |
| S4 | STORE 3-4 apron | 6 | walks |
| TL | TRAILER LOT | 4 | walks |

THE BROKER (Reshala): home the lobby of BLOCK A (`BLOCK_A_LOBBY`, the dorms; `Maps.defs.border.desc` says he keeps the dorms), a loop of
nine points round the dorm yard and the road north of it (x -160..-70, z 498..626) that returns to the lobby, four guards waiting at
(-130, 572), (-110, 572), (-130, 590) and (-110, 590). The reference lists three areas for him (ZoneDormitory, ZoneGasStation,
ZoneScavBase; his points are in `L.bosses` and `L.scav`); one home is chosen here, so the fuel stop and the Bastion keep plain guards.

Scav zones: the reference's 103 normal points (84 survive the inside, dry and 12-stud spacing tests; points inside a building move to
the open ground beside it, at most 4 per building), 29 hand-placed anchors (dorms, fuel stop, Bastion, stores, trailer lot, Red Stores,
old pumps) and six standing points inside the shops, the squat and the dorm lobby: about 118 zones. Visit zones: DORM314 (room 314
in BLOCK A, r 7), BOILER (the cellar, r 14), DERRICK (the roof, r 12), FRAME (the top floor, r 10), SMUGGLERS (the tunnel room, r 10).

### Hazards and outdoor loot

- Propane: 9 spots (fuel stop, old works, motor shop, Frame site, trailer lot, old pumps, Store 17), two cylinders 3.2 studs apart at
  six of them: up to 15 cylinders, each on open ground (not near a wall, a road or the boundary) through `Hazards.register`.
- Border snipers: six stair-step `Hazards.sniperZone` strips over the reference quad `L.sniper` (north tip, -150..25 x -835..-670),
  height -40 to 130. Spawns, all extracts and points every 24 studs along the rail to NORTH LINE inside the quad are exempt (since
  1.2.0.0 the sniper no longer fires at players walking along the rails).
- Loose loot (pool "junk", area "border"): 1 to 5 spots per yard by area (30-stud spacing), one on each pump platform, one on each scrap
  bridge landing, and up to 14 beside the wrecks: about 45 spots.

### Dressing (`Dress.luau`)

Every piece is tested against the footprints (corners and edge midpoints), roads, fences, rails, forests, rocks, the boundary, the
solid parts already in the map, a roof overhead, the keep-outs (spawns, extracts with their whole zone, routes, posts, the Broker's
crew, scav zones, doors, containers, loose loot, propane) and the pieces placed before it. Nothing stands on a road except wrecks.
Budget 2,450 parts (counted as it goes); the run prints the real count.

| What | Expected | Where |
|---|---|---|
| Container stacks | 34 (a third two high) | rows on the open lanes of the STORAGE YARD |
| Wrecks (cars, vans) | about 55 | 36 on the road shoulders (a third half on the road), about 20 in the yards' car parks |
| Poles with wires | up to 44 | five small roads (`paved_small_4`, `_2`, `_5`, `_0`, `_3`), 42 studs apart, clear of Ground's pylon lines |
| Checkpoint props | a few | sandbags, a broken barrier and a drum within 7 to 16 studs of the three guard posts |
| Cover clusters | about 55 clusters, 100 to 150 pieces | every yard but the scrap bridge landings: sandbags, pallets, tyres, cinder blocks, drums, cable reels, bins, rubble |
| Broken fence runs | about 30 | 18 to 42 studs long, along the edges of 14 yards |
| Bushes, grass, rocks | 150 | 6 to 22 studs inside the boundary where Ground left room |

### Gaps (to copy into `docs/design/EFT_PARITY.md`)

- Mounted AGS and NSV style guns are not built: the reference positions are unknown (`L.hazard.mounted` is empty).
- Co-op extracts and transits: BOILER CELLAR is a plain key extract (a PMC must bring a scav in Tarkov); the transits to Factory,
  Interchange, Reserve and Shoreline that the reference lists do not exist.
- Other boss groups are not built: the knight with Big Pipe and Birdeye, the sect priest with four warriors, the partisan.
- The Broker appears by the global boss chance (`BOSS_CHANCE` 0.5 in the AI config), not the reference's per-map chance (39 to 60 %
  by source), and always at the dorms.
- The four marksman perches in `L.snipers` (ARMY POST HUT, BOILER HOUSE ROOF, DEPOT ROOF, DERRICK ROOF) have no AI kind to fill them.
- Crew slots: `AI.spawn` only separates slot 1 from the others, so guards 2 to 4 start stacked on one offset around the Broker and
  spread out as they path.
- The AI director's numbers (`SCAV_START` 4, plus 0.5 per player up to `SCAV_CAP` 10, `AI_MAX` 18) were tuned for the small maps and
  are low for a map this size; the six guard routes are all the fixed AI the map has besides the Broker.
- The Voron note, the green flare and the ZB-1013 key still have no items (part 1's list).

Unverified (nothing has run in Studio): every count above; that the spawns, routes and posts sit on walkable ground in the built
map; the head-room test for the 12 spawns; the Broker's loop with the real dorm walls; `B.points` names against what the buildings
agents register; the part count and server time of the dressing (the geometry buckets are built from every solid part in the map on
first use); whether the stand-in blocks (no meshes) or the kit props look right; the frame rate on a low-end phone.

The Files table above still lists `Play.luau` as minimal and `Dress.luau` as a stub: they are the two files this section describes.

## Industrial side (part 2b, `Works.luau`)

Written 2026-11-01 without a Luau runtime. `python3 tools/luau_check.py src` passes (115 files, 0 failing). An offline Lua 5.4 mock (the
module converted to Lua and run against stand-ins for `kit`, `Kit`, `MapKit`, `Layout` and `Instance`; the mock is not in the repo) ran it
with 0 warnings and 0 failed structures, and top-down and side drawings of its parts were looked at. Nothing has run in Studio: every count
below is the mock's, not the game's. `Buildings.luau` requires `Works.luau` under pcall and each structure runs under its own pcall (a
failure is a `warn` naming it, the rest still stand). The module prints one line, in the mock `[ZR] Border works: 8249 parts, 428 kit props,
311 containers, 199 loose spots, 139 doors, 191 lamps, 0 lights with shadows, 81 props skipped, 0 failed`.

It builds the 24 footprints of kind warehouse, warehouse_small, big_building, complex, tower, tank, platform and bunker_entrance (the other
43 are `Living.luau`'s) and the six spaces of `L.under`. Each stands on its footprint in its own frame (u along the width, v along the depth,
y up from the flat pad) and follows `L.outline`, `L.upper`, `L.floors` and `L.stairs` where they exist. Walls are thin Block parts (brick,
precast concrete panel or corrugated sheet outside; plaster, concrete or steel inside) with real openings: vehicle gates 12 to 16 studs wide,
doors 4.2 wide and 7.9 high, windows. Floors, mezzanines and roofs are slabs. Every climb is a stair flight: the game has no ladder climbing,
so the layout's `ladder-N` pits became stairs. Flat roofs have parapets and the `Works` model carries `NoWire`, so the detail layer puts no
barbed wire on roofs and gantries. Tables, benches, bunks and shelves are built from parts (`NoDetail`); the kit props go to racks, cars,
forklifts, generators and the like. Containers are kit props (the collider carries the prompt) while a building is under its prop cap, then
plain World containers (311: crate 73, toolbox 53, weaponbox 44, techbox 29, locker 27, safe 26, drawer 25, medbag 25, jacket 5, others 4);
loose loot uses the pools `junk`, `tech`, `vault`, `keys` and `office`, area `border`. 159 light sources, none casts a shadow.

| Id | Structure | Parts | What stands there |
|---|---|---|---|
| 22 | STORE 3 | 230 | one 170 x 119 hall under a gable roof: pallet racks in six rows, forklifts, roll cages, a workshop corner, an office in the north-east corner (desk, safe) |
| 23 | STORE 4 | 411 + 183 | the hall with an office deck; under it the switch basement (`L.under` S4, stairs ladder-35 and ladder-36): three zones split by two walls, pillars, the generator hall with the K-13 lever at its west end |
| 20 | STORE 7 | 344 | two office mezzanines over the hall and a locked office in the south-east corner (`by_store7`) |
| 31 | STORE 17 | 337 | the L-shaped hall (`L.outline`), a gate bay with canopy, apron, bollards and a painted lane in the notch where the STORE 17 GATE scav extract stands, racks, a mezzanine with the foreman's office, a gallery above it |
| 21 | THE DEPOT | 346 | the tall L-shaped factory hall, an overhead crane, a stair tower to the roof, the DEPOT ROOF perch |
| 33 | RED STORES | 426 | the 190 x 100 brick hall with a row of shuttered stores, an upper deck and a wire cage of seized goods (`by_red`) |
| 28 | THE BASTION | 851 + 244 | two storeys and a walkable roof: a double-height drill hall in the north, a corridor with rooms on both sides, two dog-leg stair halls, the strongroom (`by_bastion`), a yard apron with a guard booth and floodlights; the two K-13 stairs come down inside it to BUNKER K-13 (`L.under` K13: a bulkhead with a hermetic door, side doors, a status lamp the lever lights) |
| 27 | THE DERRICK | 1362 | the open steel frame: three platform blocks on two decks (13 and 26 studs), a braced lattice tower with a switchback stair to the top deck (y 158), a mast to 167 and a jib to the sniper perch |
| 34 | THE FRAME | 546 | the unfinished concrete skeleton: columns with rebar stubs, beams, strip slabs at three levels, two solid dog-leg stairs, no walls; a foreman's cabin, brick pallets, sand and a mixer at its foot |
| 30 | MOTOR SHOP + BOILER HOUSE | 1158 + 71 | the brick boiler hall (46.6 high: galleries at two levels, a stair tower of four dog-legs to the roof, three drum boilers, a stack, the BOILER HOUSE ROOF perch with cover), the workshop wing in the west (gantry crane, a car on a lift, a parts mezzanine, the foreman's office `by_motor`), the parts store in the north (mezzanine, a stair to its roof) and the boilerman's cabin whose locked door (`by_boiler`) opens on a stairwell down to the BOILER CELLAR (`L.under` BC: five pumps, two feed tanks, valves and a desk) |
| 32 | OLD WORKS | 312 | the unfinished concrete works: a one-storey hall under a roof terrace in the west, the two-storey block in the east with a site office, a stair to the deck and one to the roof |
| 19 | PUMP HOUSE | 241 | the brick pump hall: four pumps in a double-height void, a gallery all round, two stairs |
| 8 to 11 | STORAGE BLOCKS | 85 to 107 | four 100 to 155 long steel-clad sheds: loading gates on the north side, racks on the back wall, stacked crates |
| 12, 13, 15, 16 | FUEL TANKS | 90 each | 22-stud steel tanks on a concrete ring; a 36-step spiral stair round the shell and a railed catwalk across the roof |
| 14, 17 | PUMP PLATFORMS | 51, 53 | concrete pads with two pump skids, pipe racks, a control hut and light poles; the strip the PMC spawns stand on stays free |
| 50, 51 | K-11 and SMUGGLERS' HOLE sheds | 19 each | brick sheds over the two stair shafts; below them `L.under` K11 (114 parts: arrival hall, blast door, bunks, the vault `by_k11`) and SH (111: a timber-propped cache of crates and barrels) |
| - | OLD PUMPS CELLAR (OP) | 86 | the cellar under the old gas station: two buried tanks, a pump bench, shelves and stores; Living's two sheds above keep its stair shaft (ladder-39) clear |

Budgets: 8,249 parts (the brief says about 9,000), 428 kit props (450), 0 lights with shadows (20; the spec allows 40 for the whole map).

### Points (`B.points`)

Map-local x and z, world y at standing height (3 studs above the floor), from the mock.

| Name | Where | x, y, z |
|---|---|---|
| STORE4_LEVER | at the lever, west end of the STORE 4 basement | -560.5, -12.9, 2.4 |
| K11_DOOR | K-11's blast door | -1460.8, -12.9, -292.1 |
| K13_DOOR | K-13's bulkhead door | -130.3, -12.9, -357.8 |
| SMUGGLERS_HOLE | the tunnel's arrival hall | -962.1, -12.9, -243.3 |
| BASTION_TOP | the Bastion's roof | -121.5, 28.8, -270.9 |
| BASTION_YARD | the yard apron by the guard booth | -188.7, 3.1, -355.3 |
| DERRICK_TOP | the top deck | -327.0, 161.4, 39.9 |
| FRAME_TOP | the Frame's third level | -166.4, 28.1, 54.6 |
| BOILER_CELLAR | the middle of the cellar (the extract zone) | 181.2, -12.9, -48.4 |
| MOTOR_SHOP | the workshop floor | 74.7, 3.2, -78.5 |
| RED_STORES | the long hall | 1173.1, 3.2, -272.5 |
| DEPOT_ROOF | the Depot's roof perch (also in `L.snipers`) | -978.4, 45.2, -115.2 |

### The power switch

`W.switches.BORDER_STORE4` is a lever in the STORE 4 basement (an F prompt, 8 studs, a 5 s delay: "THROWING THE LEVER", then "POWER ON"). Its
`onChange` switches every lamp and status panel it owns: the basement's and K-13's. It is built first in the basement, so the K-13 exit
has its switch whatever fails below. The raid starts with it off (`World.resetSwitches` calls `onChange(false)`; the module calls it once
more when the build ends). The K-13 exit rule in `Layout.ext` is `{ kind = "power", switch = "BORDER_STORE4", needs = "NO POWER  ·  THROW THE LEVER IN STORE 4" }`.

### Keys

| Door id | Key item | Where |
|---|---|---|
| `by_store7` | KEY_BY_STORE | STORE 7's locked office |
| `by_red` | KEY_BY_RED | the cage of seized goods in the RED STORES |
| `by_bastion` | KEY_BY_BASTION | the Bastion's strongroom |
| `by_motor` | KEY_BY_MOTOR | the Motor Shop's foreman's office |
| `by_boiler` | KEY_BY_BOILER | the boilerman's cabin (the stairs to the BOILER CELLAR; the cellar's exit uses the same key) |
| `by_k11` | KEY_BY_K11 | K-11's vault door (the way in stays open, as in the reference) |

K-13's door is not locked: no key item exists for it. Every other door in the module is an unlocked door that opens at random (35 %).

### Gaps and judgment calls (to copy into `docs/design/EFT_PARITY.md`; this part did not edit it)

- No ladders: the game has no climbing, so the layout's `ladder-N` pits are stair flights, wider and longer than the reference's ladders (the
  Derrick's switchback, the tanks' spirals, the Frame's dog-legs).
- The interiors are our own plans on the reference footprints, floors, stairs and locked rooms; rooms, props and loot spots are not the reference's.
- The Depot's crane, the car lift, the boilers, tanks and pumps are static scenery, not machines.
- K-13: the power lever and the exit rule follow the reference; the bunker's own door is open (no key item exists for it).
- K-11 has an extra locked vault door (`by_k11`) for its cache; the reference's way in is open.
- The three marksman perches on these roofs (BOILER HOUSE ROOF, DEPOT ROOF, DERRICK ROOF) are walkable, but no AI kind fills them.

Unverified (nothing has run in Studio): that every stair flight is climbable and every rail, hole and door is where the drawings put it; the
kit colliders carrying the container prompts; the frame rate on a low-end phone (8,249 parts here, plus Living's). Known risks:

- The BOILER CELLAR has no level-0 stair entry in `L.stairs`, so Ground dug no shaft for it: the cabin's stairwell is cut with
  `Terrain:FillBlock` (under pcall) and a hole in the cellar's earth ceiling. If the cut fails, the cellar is sealed and its key extract
  cannot be reached.
- K-13 is built in the Bastion's frame (rot 79.8) while its void is stamped at rot -10 on a 4-stud grid: the same box turned 90 degrees, so the
  walls may sit up to two studs off the void's edge.
- The Derrick's decks reach y 158 to 167, but `W.bounds.yMax` in `init.luau` is 110, the top of the box `DetailPlan.publish` covers. Raise it
  to about 175 there (not this module's file).
- 81 props were skipped by the keep-out circles round spawns, extracts and scav points and by each building's prop cap.
- Whether the wall openings of Living's OLD PUMPS sheds line up with the stair this module's cellar brings up in the shaft ladder-39 is unchecked.
