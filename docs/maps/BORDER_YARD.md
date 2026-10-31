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
