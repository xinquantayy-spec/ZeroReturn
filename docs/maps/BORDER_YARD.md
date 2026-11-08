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
| OP | OLD PUMPS | -469, -450 | east | chance 50 %; while it is there, a green star goes up over it every 50 to 80 s | in the basement; not always available; "green flares = open" (wiki) |
| DC | DORMS CAR | -56, 779 | both (PMCs only) | car: paid 25,000 MK per seat, chance 50 %, 4 seats, 60 s shared countdown | Tarkov's V-Ex: 5,000 roubles per player (wiki: depends on Scav karma), up to 4 players, 60 s shared timer, 50 % chance (SPT). Pay at the car (hold F on its prompt); see "Car exits" below |
| K13 | BUNKER K-13 | -137, -357 | both | power: lever `BORDER_STORE4` in Store 4 | lever in Store 4 (power stays on once thrown), then the basement door |
| CR | CROSSROADS | 1512, -134 | west | open | |
| TL | TRAILER LOT | 1468, -592 | west | open | in the trees |
| AR | ARMY ROADBLOCK | 571, -327 | west | open | sources disagree on its availability (grade C); the icon lies 56 studs past the limit |
| SB | SMUGGLERS' BOAT | 625, 474 | both | chance 50 % | secret exit; same Voron note as the hole |
| NL | NORTH LINE | -31, -766 | both | flare: closed until a green flare goes up within 94 studs (the signal area), then open to all for the raid | green flare fired in the flare area, then keep to the tracks past the border snipers (grade C) |
| BC | BOILER CELLAR | 181, -48 | both | co-op (2026-11-02): a PMC and a player scav in the zone together | scav cooperation: a PMC must bring a scav; the stairs door down still takes `KEY_BY_BOILER` |
| OF, FC, OC, AG | OFFICE GATE, FAR CORNER, OLD CHECKPOINT, ARMY GATE | west edge, z -70, -400, 17, 507 | scav | scav | scav exits on the west edge; the icons of OFFICE GATE and ARMY GATE lie 17 and 77 studs past the limit |
| RP, AL | ROCK PASS, ARMY LINE | -1147, 717; -1006, 765 | scav | scav | south-west rim |
| OR, HR, PL, CL | OLD ROAD GATE, HILL ROADBLOCK, PORT LINE, CITY LINE | -81, 775; 446, 506; 951, 253; 1020, -581 | scav | scav | named in the build spec |
| S4, HG, S17, TS | STORE 4 GATE, HUTS GATE, STORE 17 GATE, SHACK GATE | -546, 28; -137, 148; 352, -151; 1289, -626 | scav | scav | names are ours (the spec names 21 of the 26 exits) |
| PG | PUMPS GATE | -469, -494 | scav | scav | name is ours; not always available in the reference (grade D) |

Every PMC side has an open exit (east K-11; west CROSSROADS, TRAILER LOT, ARMY ROADBLOCK). The five underground exits stand on
their room's floor (y -16). Scavs may use every extract except DORMS CAR (Tarkov's vehicle exits are for PMCs), BUNKER K-13 and NORTH LINE: the reference
gives ZB-013 and the flare passage to PMCs only (rule `who = "pmc"`, 2026-11-02). The reference puts four exit icons on or past the traced limit (ARMY GATE,
ARMY ROADBLOCK, OFFICE GATE, CITY LINE), which the invisible wall would make unreachable, and DORMS CAR 12 studs from it: the
generator pulls each in until its whole zone lies inside the wall (72, 91, 30, 15 and 2 studs; the note in `L.ext` says so).
STORE 17 GATE (352, -151) lies inside STORE 17's footprint: the building needs a gate bay there.

**Car exits** (`Extract.luau`; the full rules and gaps are in `docs/design/EFT_PARITY.md`, "Car exits"). DORMS CAR is a vehicle exit like
Tarkov's V-Ex: `{ kind = "paid", cost = 25000, chance = 0.50, seats = 4, depart = 60 }` in `L.ext`. The roll at raid start puts the car
there in half the raids (rolled with the chance exits; when it is absent the car is gone, the zone says "NOT AVAILABLE THIS RAID" and the
exit list, which always shows it as "PAY 25,000 MK  ·  MAY BE UNAVAILABLE", turns red once the zone has told you). A sedan stands west of the zone's middle with a hold-F prompt on its
right flank ("Pay 25,000 MK · DORMS CAR", 1.5 s hold); the fare is taken at once and buys one of four seats. The first fare starts a
60 s countdown that later passengers join; when it ends the car leaves for good, taking every seated passenger who is inside the zone
(extracted with SUCCESS); passengers outside the zone are left behind and not refunded, and the exit reads "THE CAR HAS LEFT" for the rest of
the raid. Standing in the zone without a seat only says "PAY AT THE CAR". Everything resets at the next raid start.

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
"NO POWER  ·  THROW THE LEVER IN STORE 4"). This paragraph is part 1's state: `Living.luau` (part 2a) and `Works.luau` (part 2b) have
since filled the spots, and their sections below say what is built.

Part 3 (gameplay agent): AI routes and watch posts (`W.patrols` and `W.watchPosts` are empty, so the MapTests check for watch
posts and routes fails until they exist), the Broker and his crew (`W.boss` is none; reference: 40 %, zones BLOCKS, FUEL STOP,
THE BASTION, four followers), visit zones, border snipers (`L.snipers` and the danger zone `L.hazard.sniper`), propane cylinders and
mounted weapons (`L.hazard.propane` and `.mounted` are empty: no reference data yet), airdrops, outdoor loot, the dressing pass.

Parity gaps (to copy into `docs/design/EFT_PARITY.md`, which was outside part 1's scope):

- BOILER CELLAR is Tarkov's co-op exit since 2026-11-02 (a PMC and a player scav together). TRANSIT TO MERIDIAN MALL stands at the
  trailer lot's wood (2026-11-02); the other transits do not exist.
- The Voron note for SMUGGLERS' HOLE and SMUGGLERS' BOAT and the ZB-1013 key for the K-13 basement door have no items; the two
  exits are plain 50 % chance extracts and the bunker door is not locked. The green flare exists since 2026-11-02 (NORTH LINE opens
  by flare, OLD PUMPS sends up green flares while it is there; `docs/design/EFT_PARITY.md`, "Flare exits").
- DORMS CAR is a vehicle exit now (50 % chance, pay at the car, 4 seats, shared 60 s countdown, single use). Still gaps: it costs 25,000 MK (the old
  map's price, kept) against Tarkov's 5,000 roubles, so check the MK scale in the economy; the price does not depend on Scav karma and
  using the car gives no karma; the 60 s countdown is grade C (from memory, to confirm: the wiki pages read do not state it, the map
  references quote a 60 s shared timer from SPT data).
- Mounted weapons (AGS, NSV): built later with positions of our own (see "Gun nests" under the guard routes); propane cylinders and
  the knight with two escorts, the sect priest with his warriors and the partisan were built 2026-11-02 as THE HOUNDS, THE CULT and
  THE FORESTER (`docs/design/BOSS_HOUNDS.md`, `docs/design/BOSS_CULT.md`, `docs/design/BOSS_FORESTER.md`).
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
| `src/server/Maps/Border/Buildings.luau` | dispatcher: runs `Living.luau` and `Works.luau` under pcall, creates `B.points` |
| `src/server/Maps/Border/Living.luau` | part 2a: the 43 dorm, station, house, cabin, kiosk, garage and shed footprints (see "Living quarters") |
| `src/server/Maps/Border/Play.luau` | extracts, PMC spawns, scav zones (minimal); part 3 grows it |
| `src/server/Maps/Border/Dress.luau` | stub for part 3 |
| `src/server/Maps/TerrainKit.luau` | shared terrain writer, now time-sliced, with an optional prebuilt grid and per-column water |
| `src/server/Maps/BorderYard.luau` | stub of the old module (no longer built) |
| `tools/customs_layout.py` | reference JSON to `Layout.luau` |

The context `B` every part receives: `kit, W, map, H, Kit, L, O, S, rng, count, ground(x, z)`; Ground adds `inside(x, z)`,
`riverD(x, z)` (studs inside the river channel, negative on land), `slope(x, z)`, `T` (the TerrainKit result) and `islandTop`.

## Living quarters (part 2a, `Living.luau`)

Written 2026-11-01 without a Luau runtime. `tools/luau_check.py` (structure only) passes, and an offline Lua 5.4 mock ran the module
against stand-ins for the kit, `MapKit` and `Layout` (the mock is not in the repo). Nothing has run in Studio: every count and check below
is the mock's, not the game's. `Buildings.luau` calls `Living.luau` under pcall and each building runs under its own pcall, so a failure
is one `warn` and the rest still stand. The server prints one line, `[ZR] Border living: ...`, with the counts. The other 24 footprints
(warehouses, the complex, big buildings, towers, tanks, platforms, bunker sheds) are `Works.luau`'s.

Each building stands on its `L.blds` footprint in its own frame (u along the width, v along the depth, y above `ground` at the centre).
The module reads only `L.blds` (centre, size, yaw). The traced outlines, locked rooms and stair footprints (`L.outline`, `L.locked`,
`L.stairs`) were worked into each builder's numbers by hand; checked offline for BLOCK A and BLOCK B: their outline corners and the
13 + 5 locked room numbers come out of those tables. After a change to `tools/customs_layout.py` the builders need a second look.
Walls are thin Block parts (0.8 to 1.2 studs): brick or concrete panel outside, plaster inside, with real door holes (3.9 x 7.5) and
window holes (mostly 2.6 to 3.6 wide, shop fronts and service windows 5 to 8), slab floors and roofs, stairs and railings.
Indoor props cast no shadow; only the bigger rooms get a shadow-casting lamp. Containers are kit props or small stand-ins (medical bag,
toolbox, weapon case, coat). Loose loot lies on a surface under it (pools `dorm`, `dorm_good`, `office`, `vault`, `grocery`, `drinks`,
`register`, `junk`, `tech`, `toolbox`, `weaponbox`; area `border`). Door ids start with `LV_`; the dormitory test in `LogicTests` counts
ids that start with `DORM`.

### The 43 buildings

| Kind | Buildings | Built as |
|---|---|---|
| dorm (2) | 26 BLOCK A, 25 BLOCK B | see below |
| station (2) | 24 FUEL STOP, 44 OLD PUMPS | see below |
| house (4) | 29 THE SQUAT, 18 WATCHHOUSE, 36 ARMY POST HUT, 37 ARMY POST BARRACKS | see below |
| kiosk, booths (11) | 38 PYLON PAD, 39 and 40 BUS STOP A and B, 42 and 43 HUTS KIOSK A and B, 45 WORKS, 47 HILL ROADBLOCK, 48 STORE 17, 49 RIDGE, 61 SQUAT, 62 FRAME | one room: a service window with a counter and a till behind it, a shelf, an end door. 39 and 40 have a bus shelter, 47 sandbags. 43 is locked (`KEY_BY_HUTSKIOSK`) and holds a toolbox, a medical bag and a coat |
| kiosk, huts (6) | 41 BLOCK A GATEHOUSE, 46 ROADSIDE HUT, 52 and 53 BRIDGE BOOTH A and B, 54 RED STORES BOOTH, 55 TRAILER LOT SHACK | cabin-sized with their own furniture: guard desk, lockers and bench (41); a small shop with till, gondola and drinks fridge (46); checkpoint offices (52, 53); a foreman's office with a safe (54); bunks, a sofa and a table (55, the TRAILER_LOT point) |
| cabin (6) | 5 and 6 RED STORES CABIN A and B, 56 and 57 TRAILER A and B, 58 and 60 TRAILER C and D | steel cabins under a shallow gable: offices (5, 6: desk, pigeonholes, locker) and bunk cabins (bed, table, locker). 56 and 57 are locked (`KEY_BY_TRAILERA`, `KEY_BY_TRAILERB`) and add a hidden safe, a weapon case and a coat |
| shed (6) | 35 and 66 OLD PUMPS SHED A and B, 59 TRAILER LOT SHED, 63 STORE 4 SHACK, 64 and 65 ROADSIDE SHACK W and E | corrugated sheds: a tool chest or workbench with drums and tyres or pallets (35, 66); a van, pallets and a bench (59); stock shelves and a toolbox, locked (63, `KEY_BY_SHACK4`); tyres, pallets and cardboard (64); a safe, a weapon case and a coat, locked (65, `KEY_BY_ROADSHACK`) |
| garage (2), garage_row (4) | 0 and 1 STORE 17 GARAGE A and B, 2 TRAILER LOT GARAGES, 3 and 4 STORAGE YARD EAST and WEST ROW, 7 STORAGE YARD DIAGONAL ROW | 50 bays with party walls (one per 19 studs or so of length); shut bays have a fixed roller slab, 13 stand open with a car, the odd-numbered ones also with a tool chest |

**BLOCK A** (id 26, three storeys of 11 studs, the traced L-shaped outline): a main block of 131 x 51 studs with a corridor down the
middle and 13 slots on each side, and a side wing of 52 x 40 studs with its own corridor and four rooms either side. The stairwell takes
the place of room 109 (the dog-leg stair, `ladder-25`, the same footprint on every level) and the passage into the wing that of room
116, which leaves 32 rooms a floor, numbered 101 to 134, 201 to 234 and 301 to 334. Two end towers (`ladder-26`, `ladder-27`, outer
doors `LV_A_TN` and `LV_A_TS`), a wing exit (`LV_A_WX`) and a roof hut (`LV_A_ROOF`) with two HVAC units and two vents. The rooms are
furnished from fixed seeds (2601 for A, 2602 for B), so every raid gets the same dorm. Since the 2026-11-01 interiors pass (see "Dorm
interiors" below) a fifth of the rooms are stripped (a mattress, rubbish, a fallen chair or a broken shelf), the others are lived in (a
bed or bunks, usually a wardrobe, often a desk and chair, now and then a bookcase, rubbish, curtains), every floor has a shared
washroom and the top floor of A a kitchen, nine in ten unlocked rooms have a hinged door, and the windows have glass. 13 rooms are locked (103, 125, 128, 201, 212, 225, 228, 229, 303, 310, 314, 317, 325, at the positions of
`L.locked`): each holds a bed, a wardrobe, a desk with drawers, a coat and three `dorm_good` spots, and 7 of them also a medical bag
(310, 201, 212), a weapon case (317, 228) or a toolbox (225, 103). ROOM 314 (`KEY_BY_314`) has no wardrobe; it keeps a safe, a weapon
case and six `dorm_good` spots. The ground-floor lobby by the north tower has a guard desk, cloakroom lockers, a vending machine and a
bin; boot-room lockers and a bench stand at the other end. **BLOCK B** (id 25, two storeys, brick, 131 x 52 studs): rows of 13 rooms
(101 to 113) and 12 rooms (114 to 126 without 122, which is the stairwell with `ladder-24`), 25 a floor and 50 in all; a west tower
(`LV_B_TW`, `ladder-28`), an east exit (`LV_B_TE`), a roof hut (`LV_B_ROOF`), the warden's desk and cloakroom lockers by the west door,
and five locked rooms (103, 111, 116, 124, 223, at the positions of `L.locked`), four of them with a medical bag (103, 116), a toolbox
(124) or a weapon case (223).

**FUEL STOP** (24): a shop (counter and till, three gondolas, two drinks fridges, wall shelves) with a locked till office
(`KEY_BY_FUELTILL`: desk, safe, staff locker) and a locked storeroom (`KEY_BY_FUELSTORE`: two stock shelves, a pallet, a toolbox) behind
it, a washroom with a cubicle and its own outer door, a staff door, a canopy on six columns over two pump islands (four pumps), three
cars (one smashed in the car park), a FUEL sign on a pole and a car park with bay lines. **OLD PUMPS** (44): a small brick shop (old till,
dusty display table, vending machine, tool chest), a locked back room (`KEY_BY_PUMPS`: mechanic's locker, drum, loose tools), a rusty
canopy on four columns over two pumps, a smashed car, jerry cans and a tyre stack. **THE SQUAT** (29): a gutted two-storey brick house
with a hall down the middle (living room, kitchen, stairs room with a dog-leg stair, party room, bedroom and junk room off it; a bunk
room, lounge, party floor and bedrooms upstairs), an iron stair (diamond plate) up the outside of one end wall to an upper door, and a
rusty gable over a flat roof deck. The stash room (hidden safe, weapon case, medical bag, shelf, leather coat) opens only through
the locked back door (`KEY_BY_SQUAT`). **WATCHHOUSE** (18): two brick wings of two floors round a lower hall whose roof is a terrace
level with both upper floors (stairs `ladder-15`, `ladder-16` and, inside the west wing, `ladder-31`); a reception desk with CCTV in the
hall, the mess, kitchen and lockers in the west wing, the briefing room and the barracks in the east wing, a watch post on the
terrace. Two rooms of the west wing are locked: the watch room (`KEY_BY_WATCHROOM`, rare: safe, weapon case, duty coat, duty desk) and
the store room (`KEY_BY_WATCHSTORE`: stock shelf, medical shelf). **ARMY POST**: the hut (36: a duty room with desk and locker, an
armoury behind `KEY_BY_ARMYHUT` with a gun rack, two ammo crates, an armour stand and a safe, a guard room above with a radio desk, and a
stair up to a roof perch) and the barracks (37: one long corridor, four rooms on each side with bunks, a store, a mess, a kitchen, an
office and a sofa room, three outer doors).

### Keys (29 new items in `Items.luau`, all in the `keys` pool of `Loot.luau`)

| Key | Door |
|---|---|
| `KEY_BY_A103`, `A125`, `A128`, `A201`, `A212`, `A225`, `A228`, `A229`, `A303`, `A310`, `A317`, `A325` (12) | the BLOCK A room of that number |
| `KEY_BY_B103`, `B111`, `B116`, `B124`, `B223` | the BLOCK B room of that number |
| `KEY_BY_FUELTILL`, `KEY_BY_FUELSTORE` | FUEL STOP till office, storeroom |
| `KEY_BY_PUMPS`, `KEY_BY_SQUAT` | OLD PUMPS back room, THE SQUAT back door |
| `KEY_BY_WATCHROOM` (rare), `KEY_BY_WATCHSTORE` | WATCHHOUSE watch room, store room |
| `KEY_BY_ARMYHUT` | ARMY POST HUT armoury |
| `KEY_BY_HUTSKIOSK`, `KEY_BY_TRAILERA`, `KEY_BY_TRAILERB`, `KEY_BY_SHACK4`, `KEY_BY_ROADSHACK` | HUTS KIOSK B, TRAILER A, TRAILER B, STORE 4 SHACK, ROADSIDE SHACK E |

That makes 30 locked doors with `KEY_BY_314`, which already existed. The five keys of `Works.luau` (`K11`, `STORE`, `RED`, `BASTION`, `MOTOR`)
were not touched. The new keys carry the same fields as the existing ones (name, short name, value, rarity, `key.uses`, description); no
per-key art was made. They weigh 1 to 2 in the `keys` pool, which every map's key spots share, so they thin out the other maps' key
rolls (the five of `Works.luau` did the same).

### `B.points` (11)

Map-local studs (x, y, z) from the flat mock; y is the floor plus 0.5 above the ground at the building centre. BLOCK_A_LOBBY (-35, 1,
578), BLOCK_A_ROOM314 (-64, 23, 690), BLOCK_A_STAIRS (-33, 1, 615), BLOCK_A_ROOF (-39, 34, 614), BLOCK_B_LOBBY (-219, 1, 629),
BLOCK_B_STAIRS (-217, 1, 557), FUEL_SHOP (-773, 1, 228), OLD_PUMPS_SHOP (-587, 1, -422), SQUAT (249, 1, -379), WATCHHOUSE_TOP (-1274, 12,
-108; on the terrace), TRAILER_LOT (1093, 1, -476; inside the shack, 55). `Play.luau` reads six of them: BLOCK_A_LOBBY (the Broker's
home), BLOCK_A_ROOM314 (the DORM314 visit zone), FUEL_SHOP, OLD_PUMPS_SHOP, SQUAT and BLOCK_B_LOBBY (scav zones). The other five are
not read by any module yet.

### Dorm interiors (update of 2026-11-01: rooms, doors, washrooms, glass)

Only `Living.luau` changed (the dorm section, the two dorm builders and a few helpers); no other file. Written without a Luau runtime:
`tools/luau_check.py` passes and the offline mock (below) ran it; nothing has been seen or run in Studio.

**What Tarkov's dorms have** (web research on 2026-11-01; the game itself was not run). Sourced: two dorm buildings in the far north,
the west one three floors and the east one two, each with a front entrance and a fire stair at each end with a door to every floor,
some blocked or locked (fandom and gamepedia Customs pages); rooms numbered by floor, keys for 103 to 118, 203 to 220 and 303 to 315
(wiki.biligame.com Customs key table); locked rooms hold safes, weapon boxes, toolboxes, jackets, sport bags and medical cases, a guard
desk room sits by the two-storey dorm's front door, and some doors open onto a bed ("jump over the bed to open the door", rooms 204 and
214: gamersdecide, eft-ammo and dignitas key guides); an L-shaped hall on the second floor of the three-storey dorm (Sportskeeda,
Chemical Part 2, room 220 behind a door covered in metal rods); windows are passable (room 206 "can be skipped since you can jump
through the windows", the guard room "visible from outside": eft-ammo, gamersdecide); a "Common area" on the first floor and a kitchen
and a rest area on the third (a Google Slides Customs guide, with Chinese captions); showers on the third floor of the three-storey dorm (a Medal clip
titled "Customs 3rd Floor of 3-story showers bugged"). Not found in any page: where the washrooms are on the other floors, whether the
two-storey dorm has any, whether any glass is left, curtains. `api.tarkov.dev` and the fandom raw page could not be fetched (blocked),
so no room position comes from the game's data. Everything below that rests on this is therefore inferred (grade C) or our own choice
(grade D); the list of what is which is in the gaps.

**Rooms.** `planDorm` replays the old dice first (seeds 2601 and 2602, same draws in the same order: door roll, layout roll, coat,
loose spots), so every desk with drawers, coat and loose-loot spot is thrown for the same room as before; geometry-dependent retries
of the old code (a spot with no room) now use a stream of their own, so one retry no longer shifts every later room. The new decisions
come from `seed + 5000` and one seed per room, so a room never moves another. Classes: a fifth of the calm rooms (not locked, no desk)
are `bare`, the rest `lived` (washrooms and the kitchen take their rooms first, below). Lived-in rooms: one bed 46 %, two beds 18 %,
bunks 24 % (a second bunk in a quarter of them), a double bed 12 %; a wardrobe 62 %; a desk and chair 50 %; a bookcase 30 %; two to
four pieces of rubbish; curtains in 40 % of rooms with a window. Bare rooms: a mattress on the floor 75 %, a fallen chair 50 %, a
broken shelf 35 %, a cardboard heap 35 %, five to eight pieces of rubbish, curtains 15 %. Beds, wardrobes, desks and bookcases are the
kit props stretched to dorm sizes (bed 3.1 x 6.7 studs, wardrobe 2.7 x 6.7 x 2.3, desk 4.2 x 2.4, bookcase 4.0 x 1.7); a prop whose
collider would overlap a wall or another prop is dropped without a word (109 of the 397 tried in the mock), so a room can come out
emptier than its dice say. Locked rooms keep their own furniture and containers (bed, wardrobe, desk with drawers, coat, extras, and
room 314's safe, weapon case and six `dorm_good` spots); their loose loot is now thrown last so nothing is built over it. Loose loot
that finds no room moves within its own room only (a ring that crossed a partition used to drop it into the next room, under a bed).

**Doors.** A hinged door through the existing `f:door` helper (prompt, `openChance`) in the corridor wall of 118 of the 128 unlocked
rooms: lived-in rooms 95 %, bare 70 %, washrooms and the kitchen always, and any room that had a door from the old dice keeps it. Ids
are `LV_<tag><number>` (never `DORM`); label "Room 2xx", "Washroom" or "Kitchen"; `openChance` 0.55 (bare 0.35, washroom 0.5).
The door holes stay 3.9 x 7.5 and the rooms' door landing (a 3.3 x 4.8 x 3.4 box either side of the slab) is kept free by the furniture
rules and checked in the mock. Locked doors are unchanged (30 in all, same keys).

**Washrooms and the kitchen.** A shared washroom on every floor: BLOCK A rooms x15 (115, 215, 315; if the old dice put a coat or a
desk in one of them, the next of x14, x18, x17), BLOCK B rooms x21 (121, 221; fallbacks x25, x19, x17, x20); BLOCK A's top floor has
a kitchen in room 308 (fallbacks 307, 306, 305). Never a locked room, a room with a desk or coat, or one that holds key loot. A
washroom is built from boxes in the room: tiled floor and half-height wall tiles, two sinks under mirrors (kit `MirrorSink`) with a
pipe over them, three toilet cubicles (steel partitions, bowl and high cistern, doors shut, broken or gone), three shower stalls at
the far end (tray, rose, curtain drawn or pushed aside), a drain, two puddles, a bin and a "WASHROOM" sign over the corridor side of
the door; its window, if it has one (BLOCK B's two do, BLOCK A's three stand behind the wing and have none), is frosted. The aisle is
4.7 studs wide. The kitchen: a run of worktops with a sink and a two-ring cooker on
the free wall, wall cupboards, a fridge, a table and two chairs. Both are on the plan the room classes already had (a bare stand-in
before), so they take no container and no key room.

**Glass.** Every outer-wall window hole of both blocks (all walls, 168 holes in A and B) gets a thin pane of 0.1 studs, Glass,
Transparency 0.5, `CastShadow = false`, `CanCollide = true`, `CanQuery = false`, `CanTouch = false`: bodies stop at it, shots and
sight pass through it (as they passed the open hole it replaces). The state of a window comes from a hash of its floor, wall and
position, so the wall and the room behind it agree: 68 % whole, 6 % the top half left, 6 % the bottom half left, 12 % open (no
pane), 8 % boarded (three planks across the hole, `CanCollide` and `CanQuery`); washroom windows are frosted (Transparency 0.12).
Half-broken and open windows drop a heap of glass on the floor inside (70 %). Curtains are thin cloth parts on the window wall of
a room (closed, drawn to both sides, or to one), never over a boarded or open window. The windows of the two end stair towers, the
roof huts and the door holes stay open. In the mock, A and B hold 168 window holes: 104 whole panes, 19 half panes, 2 frosted, 22
open and 21 boarded (63 boards), plus 54 curtains and 15 heaps of glass; the exact mix changes with the PRNG.

**What it costs** (the brief's ceiling was +2,500 parts). The mock's part count undercounts kit props (one stand-in box each), so the
estimate converts every kit prop to what `Kit.place` really builds, one mesh part per material piece (`KitMeta.luau`) plus its
colliders, adds two parts per added door (`World` builds a slab and a handle) and subtracts the same count for the old build. Result
for BLOCK A and B together: 2,181 parts before, about 3,780 after on the real seeds, +1,760 with the doors; across the real seeds and
twelve other random streams the gain was +1,760 to +1,890 (mean about +1,830), so Border goes from about 23,400 to about 25,200
parts. Kit props in the two blocks: 183 before, about 394 after (the other buildings' 440-prop cap is untouched; the dorm furniture
has its own cap of 900, which is not reached). No new lights (152, 12 with shadows). Every new part with all sides under 3 studs has
`CastShadow = false`; clutter under 1 stud has no collision and no query; the fittings carry `NoDetail` so the detail layer does not
decorate them. The build yields every room (`pace()`, as `Ground` does) so it does not hold the server up.

**What the mock checks** (clean on 13 runs: the real seeds and twelve other random streams; the mock's generator is not Roblox's, so
rooms differ in Studio, which is why the others were run): 0 failed buildings; no `DORM` door id; the same 30 locked doors, keys,
named points and room 314 setup; every door slab clear of solids, and every door's landing and every open doorway's landing free; no
prop collider overlaps a wall or another prop (about 600 colliders a run); every loose spot has a surface under it and does not start
inside a solid; container ids unique. With the old retry draws removed from the old build, the container ids come out identical
(234 and 234, and every old door is kept); against the old build as it was, 7 of its 231 container ids are absent and 10 others
present (coats and desk drawers of A's upper floors in a neighbouring room), and one old door (`LV_A227`) is gone, because the old
code's one retry (a locked room's loose spot with no room) shifted every later room's dice. A retry is geometry-dependent, so what the
old build did in Studio, with its own PRNG, cannot be told offline. The mock has no real PRNG, no physics and no
rendering: how the stretched kit meshes, the glass and the curtains look, whether the AI walks through the new doors, and the frame
rate on a phone with the extra 1,800 parts have not been seen or measured.

**For the Studio screenshots** (world position = the map-local position given here plus (0, 0, -5200); the washroom and kitchen rooms
move to a fallback room if the real PRNG gives the preferred one a coat or a desk, but the door label and the sign say which). A
furnished room: BLOCK A floor 2, rooms 204 to 208, doors at (-42.6, 15.3, -4535.1) to (-37.2, 15.3, -4574.3); stand in the corridor
at about (-44, 13, -4555) and look toward +x through room 206's door. A washroom: BLOCK A floor 1, door "Washroom" at (-54.5, 4.3,
-4516.7), room centre (-64.3, 0.5, -4519.7), the room runs toward -x (floors 2 and 3 are 11 and 22 studs higher); BLOCK B's is at
(-216.0, 4.3, -4631.1), centre (-225.8, 0.5, -4634.0). The kitchen: BLOCK A floor 3, door at (-37.2, 26.3, -4574.3), the room runs
toward +x. A window row: BLOCK A's east face, floor 2: panes from (-26.2, 16.6, -4504.5) to (-10.1, 16.6, -4622.3), seen from about
(-6, 16, -4564) looking toward -x (whole, half, open and boarded windows in one view). Also worth a look from inside: room 314 (far
corner, the safe) to see nothing was built over it.

### Counts (offline mock, not Studio)

Updated 2026-11-01 for the dorm interiors: 43 buildings (0 failed), 4,690 parts of its own plus 647 kit props (the props add their own
mesh parts), 152 lamps (12 with shadows; 57 of the lamps are in the two dorms), 211 doors (30 locked), 234 containers, 349 loose spots
(0 without room), 0 props rejected for overlap. Before the pass: 3,728 parts, 436 props, 129 doors, 231 containers and 346 loose
spots. The brief's ceilings are about 9,000 parts, 450 props and 20 shadow lamps; the module's own prop cap is 440 for the buildings
other than the dorm rooms (their furniture has a cap of 900 of its own) and it builds the dorms, stations and houses first, so the cap
would cut small buildings, not those. Biggest, props and parts: BLOCK A 274 and about 1,630, BLOCK B 120 and 860, THE SQUAT 47 and 306,
WATCHHOUSE 44 and 395, FUEL STOP 23 and 104. Containers by kind: drawer 46, locker 46, jacket 46, toolbox 19, grocery 18, register 14,
medbag 11, crate 9, safe 9, weaponbox 9, cooler 6, techbox 1. The `Works.luau` section counts 8,249 parts in its own mock run, so the
two modules together come to about 12,900 mock parts before the kit meshes.

What the mock checks (clean at the end): every key a door names is an item with `kind == "key"`, no door id starts with `DORM`; every
door slab stands in a real opening (no solid part inside it); a landing of 3.3 x 4.8 x 3.4 studs on both sides of every door and open
doorway is free of furniture and walls; no kit prop's collider overlaps a wall or another prop; no container centre lies inside a wall,
and container ids are unique; every pool and container kind exists; every loose spot has a surface within the 7-stud drop that
`snapLooseSpots` casts from 2.5 studs above it (so M04 should hold) and does not start inside a solid; none of the 11 points lies
inside a solid part (a 2.4 x 5 x 2.4 stud capsule). It ran on flat ground and on a sloped ground function.

### Gaps (to copy into `docs/design/EFT_PARITY.md`)

- Dorm furniture (2026-11-01, "Dorm interiors"): a fifth of the rooms are stripped, the others hold a bed or bunks, usually a wardrobe,
  often a desk and chair, now and then a bookcase, rubbish and curtains. Still missing against Tarkov: the second floor's L-shaped hall
  and the reference's room shapes (ours are 9.1 x 19.4 stud boxes off a straight corridor), wall fittings (radiators, posters, sockets,
  switches), books and papers as searchable things, and doors that open onto a bed (204, 214). The mix of furniture, the odds and the
  20 % bare share are ours (grade D; the brief asked for about a fifth); Tarkov's own shares are unknown.
- Interior doors: 118 of the 128 unlocked dorm rooms have a hinged door, the rest (bare rooms, mostly) are open doorways; the doors
  open and shut by prompt and have no kicked-in or ajar-at-spawn variants beyond `openChance`. The garage roller doors are fixed slabs
  and cannot open.
- Washrooms and kitchens (2026-11-01): a shared washroom on every dorm floor (A 115, 215, 315; B 121, 221) and a kitchen in A 308.
  The pages found confirm only showers on the third floor of the three-storey dorm, a kitchen and rest area on its third floor and a
  common area on its first; the washroom columns, B's washrooms (the two-storey dorm may have none), the counts of cubicles, sinks and
  showers and the kitchen's room are inferred (grade C) or ours (grade D). No common area or rest area is built as such (the lobby by
  the north tower and the top-floor kitchen stand in for them).
- Windows (2026-11-01): the outer windows of A and B have thin panes. Tarkov's dorm windows are passable openings (the guides jump and
  shoot through them); ours stop the body when whole. Since 2026-11-01 (main session) that is 30 % of them; 25 % are half broken, 35 % open and 10 % boarded (`winStyle`), so most are passable as in Tarkov. They pass shots and sight (`CanQuery = false`), do not break when hit, and have no cracks, blinds or shutters. The windows of the
  two end stair towers stay open holes. Lower the 0.68 in `winStyle` to leave more windows open. No light switches or power state; the
  lamps are always on.
- Stairs are straight or dog-leg approximations on the reference stair footprints (5.5 studs of rise per half flight, about 30
  degrees). Roofs are flat with a parapet (dorms, stations) or a low gable (cabins, sheds, the squat), without the reference's detail.
- Room numbers follow our own column grid and the locked set follows `L.locked`; the key-to-room assignments and the loot per room are
  our own (only room 314 and `KEY_BY_314` predate this build). Loot comes from the project's pools by container kind, not from
  per-room tables; the 29 keys are our own items and prices.
- No quest items or co-op specifics inside the buildings.

Unverified (nothing has run in Studio): every count above; the look of the kit props and stand-ins (a prop's mesh can be larger than its
collider); the gable wedges and roofs; frame rate on a low-end phone with 152 lamps; whether the AI paths through the 3.9-wide dorm
doorways; the part count with the kit's own meshes; `LogicTests` expects exactly 4 keyed doors among those with `d.map == nil or
"quay7"` and `MapTests` M05 wants `d.part`, `d.prompt` and `d.map` on every door (Border doors should carry a map tag, not run). Top-down
plans drawn from the mock's parts were reviewed for most of the larger buildings (and, for the dorm interiors, a washroom, the kitchen,
a few rooms and an elevation of the windows); no building has been seen in Studio. Not seen or measured either: the dorm furniture
stretched from the kit meshes, the glass, the curtains, the 80 extra door prompts and slabs, and the frame rate with about 1,800 more
parts in the two blocks. OLD PUMPS
CELLAR and its stair (`ladder-39`, between OLD PUMPS SHED A and B) are `Works.luau`'s; the two sheds here have no floor, keep the
stair's footprint clear and have a wall opening toward it, and whether those openings line up with Works' stair is unchecked on both sides. RED STORES CABIN A and B overlap by 0.23 studs in the
traced layout (grade B); cabin A is turned half a revolution so that its door faces away from cabin B.

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

**Gun nests** (`Play.luau`, "guns"; `docs/design/STATIONARY_WEAPONS.md`). Two mounted guns stand on the roof of the Bastion
(building 28, the scav base), both against the yard-side parapet (the building's +v wall, the one that faces the BASTION_YARD point) and pointing
straight out from it: the HMG-12 75 studs along the wall one way from the building's centre (over the `BASTION_YARD` point),
covering the yard; the AGL-30 20 studs along the other way (95 studs from the HMG), lobbing over the ground beyond. Each sits on a concrete pad that lifts the gun and its operator over the
3.4 stud parapet, and each has a Watch guard posted behind it on route BG ("Bastion Gunner", "Bastion Grenadier"). A guard who
engages a raider the gun can reach mans the gun (arcs 70 and 60 degrees either side of straight out); a raider can mount a free gun
from its prompt. The guns are placed through `kit.stationary`, which parents them under `ZR_World/Stationary`.

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

- Mounted AGS and NSV style guns: the reference positions are unknown (`L.hazard.mounted` is empty), so the mounted guns
  (HMG-12 and AGL-30, `docs/design/STATIONARY_WEAPONS.md`) stand on the Bastion's roof, our choice: two nests on the yard-side
  parapet with a posted gunner each (`Maps/Border/Play.luau`, "guns"). Move them when a position source turns up. Written and
  checked by `tools/luau_check.py` only; the pad and parapet clearance was worked out offline, and the arcs against the yard and a
  gunner's sight lines have not been seen in Studio.
- Co-op extracts and transits: BOILER CELLAR is a co-op exit since 2026-11-02 (a PMC and a player scav in the zone together;
  the stairs door down still takes the boiler house key, our addition). The transit to Interchange links to Meridian Mall
  since 2026-11-02 (`docs/design/TRANSITS.md`) and the one to Factory to the Smelter since 2026-11-09; those to Reserve and Shoreline do not exist.
- THE HOUNDS (the knight with Big Pipe and Birdeye), THE CULT (the sect priest with his warriors) and THE FORESTER (the partisan,
  with his tripwires in the doorways near the dorms and the frame) were built 2026-11-02 (`docs/design/BOSS_HOUNDS.md`,
  `docs/design/BOSS_CULT.md`, `docs/design/BOSS_FORESTER.md`).
- The Broker appears by the global boss chance (`BOSS_CHANCE` 0.5 in the AI config), not the reference's per-map chance (39 to 60 %
  by source), and always at the dorms.
- The four marksman perches in `L.snipers` (ARMY POST HUT, BOILER HOUSE ROOF, DEPOT ROOF, DERRICK ROOF) have no AI kind to fill them.
- Crew slots: `AI.spawn` only separates slot 1 from the others, so guards 2 to 4 start stacked on one offset around the Broker and
  spread out as they path.
- The AI director's numbers (`SCAV_START` 4, plus 0.5 per player up to `SCAV_CAP` 10, `AI_MAX` 18) were tuned for the small maps and
  are low for a map this size; the six guard routes are all the fixed AI the map has besides the Broker.
- The Voron note and the ZB-1013 key still have no items (part 1's list); the green flare was added 2026-11-02.

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
| `by_boiler` | KEY_BY_BOILER | the boilerman's cabin (the stairs to the BOILER CELLAR; the cellar's exit is co-op since 2026-11-02, no key) |
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
