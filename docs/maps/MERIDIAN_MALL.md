# Meridian Mall (Interchange layout)

The third map in the rotation. Rebuilt on 2026-11-01 on Escape from Tarkov's Interchange as it stands in 1.0 (the expanded
outside), at real scale: the layout (where things stand, how big, which way they face, how many floors, the roads, the car
parks, the camps, the extracts) is Interchange's, the buildings, names and art are ours (the owner's decision of 2026-11-01,
see `MERIDIAN_INTERCHANGE_BUILD.md`: same map, own buildings and names). The first Meridian Mall (a two-level mall of about
400 x 300 studs at origin (-1600, 0, 0), 2026-10) is gone; its code is in git history
(`git show 42049af:src/server/Maps/MeridianMall.luau`) and `src/server/Maps/MeridianMall.luau` is a stub.

Status: part 1 of 3 (foundation) is written: layout data, init, ground and outside structures, the power switch, the wiring in
`World.luau` and `Maps.luau` (raid time 2400 s). The shell (part 2) and the play layer (part 3) were written
afterwards (see below); the stores are not built yet. Part 1 was written without a Luau runtime: `tools/luau_check.py` (structure only) passes, and an
offline Lua 5.4 mock (stand-ins for the kit, `MapKit`, `TerrainKit` and the engine; not in the repo) ran `init`, `Ground` and
`Outside` against the real `Layout.luau` with no error and no warning. Nothing has run in Studio: every number below that depends
on the engine (terrain look, timings, frame rate) is an expectation, and the part counts are the mock's.

## Frame

- Reference: `docs/maps/reference/INTERCHANGE_REFERENCE.md` and `interchange_layout.json` (metres, x east, z south, north is -z,
  origin at the centre of the 1031 x 868 m bounds). The outlines come from a community map under CC BY-NC-SA 4.0: a layout guide
  only; the SVG and the raw data are never shipped.
- Scale S = 3.125 studs per metre. Map origin `O = Vector3.new(0, 0, 9000)` (the map spans x -1593..1574, z 7647..10266 in world
  studs, clear of every other map). Code uses map-local studs; `H.V(x, y, z)` adds O.
- Playable polygon (`L.boundary`, 56 vertices): x -1474..1457, z -1353..1266 (2931 x 2619 studs, 938 x 838 m). Outside it, a
  minefield band on the west (x -1593..-1336) and a sniper band on the east (x 1201..1574): players may walk into them (lethal
  logic is Play's); the invisible walls stand on the OUTER limit (`L.limit`, 54 vertices) with a berm behind.
- Heights: local y 0 is the flat ground and the mall's L0 (game y 21.4), y = (game y - 21.4) x S. **L1 = 17.81, L2 = 47.50**; ceilings
  16.25 / 45.94 / 67.50, roof about 69.1 (grade D). The relief outside is slight: the west lowland (x -1100..-700, z -900..-400, six
  ponds) falls to -20, the south-east corner rises to +12 near (875, 883); the berms outside the limit rise to about +100.
- Terrain: 3400 x 2880 studs, 850 x 720 columns of 4 studs (612,000), y -72..168. One height grid feeds TerrainKit and
  `B.ground(x, z)`. The terrain under the mall footprint lies at **y -0.4** so the shell's L0 slabs (top y 0) never fight it.
- `Layout.luau` is generated: edit `tools/interchange_layout.py` and run `python3 -I tools/interchange_layout.py` from the repo
  root. Its header explains every table, the rotations, the strides and the accuracy grades A to D.

## Layout

Centres are map-local studs (x, z). Names are ours.

| Area | Centre | What stands there |
|---|---|---|
| THE SUBSTATION | 901, -1082 | The power station's main building (81 x 61 studs, 20 high) with the power lever; its apron; four transformer pads (1014, -1075), (1004, -973), (994, -883), (993, -827) and eight yard sheds (YARD SHED A and B, SHED 1 to 6); the SUBSTATION CAR exit (1112, -1124) by the sniper band |
| North | 500, -1059 | NORTH SERVICE YARD, NORTH ACCESS PAD (511, -982), the road to the substation; NORTH SHED A and B at (-191, -1112) and (-253, -1069) |
| NESTA TOWER | 112, -1137 | The tall sign pylon on the mall's north side; three ponds (dry ditches) at x -122..-366, z -1143..-1179 |
| KART TRACK | -241, -767 | The track outline (189 x 95 studs) on its asphalt pad (272 x 193), the KART PIT HOUSE (-184, -653) |
| West lots | -237, -460 to 508 | WEST LOT 2 to 6: five surface car parks with worn bay markings, the LOT BOOTH and the ROADSIDE BOOTH |
| Highway | about -590 and -529, whole height | The N-S highway (two carriageways 34 studs wide, forking at the north end), HIGHWAY CAMP (-565, -10) and HIGHWAY BOOTH 1 to 7 along it |
| West camp | -1190, 270 to 550 | WEST CAMP: ten huts, the WEST CAMP PAD (-1009, 493), a dirt road; the RIVER PATH exit (-1372, 286) at the far west edge |
| West edge | -1390 to -1280 | two power lines (x -1391..-1276), the west railway (two lines, from the north-west corner past (-900, 300) to the south-west), the minefield band behind them (x -1593..-1336); RAIL SIDING at the north-west corner (-1232, -1314) |
| The mall | 400, -150 | the footprint (22-point outline, x -56..873, z -960..665): a flat pad, the four dock ramps on the east side (V_OUT_0..3), the ring road around it; THE SHELTER door in car park C (412, 172) |
| East docks | 806, -752 and 806, 458 | NESTA DOCK APRON and BOLTWORKS DOCK APRON along the east wall (315 x 108 studs each), the four ramps `V_OUT_0..3` |
| BOLTWORKS TOWER | -394, 695 | the second sign pylon, with a ring road loop around it |
| Cargo yards | 156, 838 and -160, 864 | CARGO YARD EAST and WEST (concrete), rock outcrops, the south road |
| RESCUE CAMP | 640, 765 | four tents and four shipping containers either side of the south ring road (z 720) |
| RESCUE CHECKPOINT | 1280, 846 | the OFFICE and GUARDHOUSE (rotated -16 degrees), the road gate on the road at (1243, 863), the RESCUE CHECKPOINT exit |
| East | 1000, -130 to 400 | EAST HUT 1 to 4 (1267..1324, -133..-84), the EAST SERVICE LANE (931, -38) with the FENCE GAP at (947, -219), the WALL BREAK hut (1064, 399), the EAST TRUCK LOT (1004, 316), the east canal (a dry ditch) |

## What part 1 builds

`init.luau` builds the model "Meridian", then runs the parts in order, each under pcall (a failing part is logged and the rest still
build; a part that does not exist is skipped): Ground, Outside, Mall, Stores, Play, Dress. It sets `W.bounds` (the whole box,
y -30..60 so the AI scan starts under the roof, step 9: about 94,000 columns), adds a `W.natureRegions` entry and prints one line,
`[ZR] Meridian: ...`, with the counts.

**Ground** (`Ground.luau`), each step under its own pcall:

1. Terrain from one 4-stud grid: 31 relief knots, graded roads (half width + 1, blended over 12 studs) and rails (6.5, 10), rock-field
   mounds, flat pads under every yard (blended over 22) and every building (16), the mall pad at y -0.4 (no outward blend), berms
   (62 studs wide, 100 high) outside the limit, the 13 ponds and the east canal dug as dry ditches (no terrain water). Materials by
   area: grass and earth, bare churned earth in the minefield band, rock on the rock fields, basalt along rails and tracks,
   concrete under yards and the mall, asphalt under roads and car parks, mud in the ditches. A flat slab stands in if TerrainKit fails.
2. Roads: 49 polylines (highway 34.4 studs wide, tarmac 22.8, gravel 14.4; gravel tracks are painted into the terrain). Asphalt boards,
   worn highway centre dashes, round patches at bends (the loop around the BOLTWORKS tower closes).
3. The four dock ramps `V_OUT_0..3` (wedge from the ground up to L1, 17.81 studs, with a kerb on both sides): the shell's L1 slab
   must meet their high ends (`L.mall.vert`, x0, z0 low end to x1, z1 high end).
4. Surface car parks: worn bay separators and a back line per double row on WEST LOT 2 to 6 (at most 260; 168 are placed).
5. Rails: ballast, sleepers and two rails per piece (the two south border rails lie outside the limit and are skipped).
6. Chain-link fences: 35 runs. Power lines: 17-part pylons for the towers inside the limit, sagging wires. Hazard bands: posts and
   tape along the inner edge of the minefield and the sniper band, a sign every third post.
7. The KART TRACK kerbs (red and white) with tyre stacks at every other corner, rock fields and boulders (nature kit, at most 240),
   the invisible boundary walls (54, 400 studs tall) on the outer limit.
8. While no `Mall.luau` exists (`B.hasMall`): a thin translucent outline of the mall's 22 wall edges (model "MallOutline", attribute
   `Placeholder`); it is not built once the shell exists.

**Outside** (`Outside.luau`): every outdoor footprint of `L.blds` except the shelter vestibule (the shell's), each a shell from
`wallHoles` (door and window holes, gable or flat roof, floor slab) with two or three Blender kit props against the back wall:

| Group | Count | Built as |
|---|---|---|
| THE SUBSTATION | 1 + 4 pads | Hall (west, 49 x 58 studs: three transformers, a generator, four switch cabinets, the lever plate on the partition), the OFFICE (south-east) and the locked UTILITY ROOM (north-east); a vehicle gate (16 x 12 open) on the west wall, windows high on every wall, flat roof with a parapet; transformers on the four pads |
| Yard sheds | 10 | flat-roofed metal sheds, one wide opening toward the road |
| Booths | 9 | HIGHWAY BOOTH 1 to 7, LOT BOOTH, ROADSIDE BOOTH: door, counter windows, a canopy over the front |
| Huts | 5 | EAST HUT 1 to 4, WALL BREAK HUT: concrete, gable roof, windows, props |
| RAILSIDE HUT, KART PIT HOUSE | 2 | the hut with a gable roof; the pit house with three garage openings, a flat red roof and tyre stacks |
| WEST CAMP | 10 huts | timber huts on gable roofs with beds, bunks, shelves, a drum |
| RESCUE CAMP | 4 tents + 4 containers | tents: groundsheet, canvas walls and roof, ridge pole, two cots; containers: skids, ribbed body, doors with lock bars |
| RESCUE CHECKPOINT | OFFICE + GUARDHOUSE + the road gate | two buildings (the office has a door leaf `MM_RC_OFFICE`), then two staggered boom barriers across the road, a ticket booth, sandbags and signs on the inland side of the extract |
| Sign pylons | 2 | NESTA (teal) and BOLTWORKS (orange): plinth, 88-stud shaft with fins, a lit double-sided 38 x 14 board |

Measured by the mock (not Studio): Ground 2,492 parts (roads 527, power 558, fences 445, rails 276, rocks 240, car parks 168, hazard 146,
boundary 54, kart 44, ramps 12, outline 22), Outside 1,022 parts with 100 kit props, 13 lights (none with shadows), 4 door leaves, 8
containers: **3,514 parts in all**. The budget for outside plus dressing is under 6,000: Dress has about 2,500 parts to spend.

### THE SUBSTATION's switch (`MALL_POWER`)

`Outside` registers `W.switches.MALL_POWER` (label "Power switch", hold 3 s, 6 s delay, "THROWING THE SWITCH" / "POWER ON"): a lever
on the partition between the hall and the east rooms; its arm and knob flip, the six hall lamps and the two room lamps come on
(they are dead at raid start; one red emergency lamp over the lever stays lit), and the indicator beside the lever turns on. The
SHELTER EXIT extract carries the rule `{ kind = "power", switch = "MALL_POWER" }`. **Later parts must not register the switch again.**
Anything that follows the power (the mall's lights, the cargo lift, the alarm, the shelter door) appends a `function(on)` to
`B.powerHooks`; the lever calls each under pcall whenever it changes (`Doors.resetSwitches` calls it with false at every raid start) and
a hook applies the off state itself when it is built. `B.points.SUBSTATION_SWITCH` is the standing point in front of the lever.

The utility room's door `MM_SUB_UTILITY` needs `KEY_MM_SUBSTATION` (an item that does not exist yet): until `Items.luau` defines it the
door stays locked, and MapTests M05 "keys are real items" fails for it. The room holds four of the eight containers
(`MM_SUB_C1..C8`: switchgear boxes, toolboxes, a locker, drawers, crates; kinds `techbox`, `toolbox`, `drawer`, `locker`, `crate`,
`weaponbox`).

## Extracts (7)

`grp` is the PMC entry half the reference offers it to (se / nw), "both" serves both, "scav" is scavs only. All seven are in `L.ext`
with their positions and rules; Play builds them (`kit.extract`).

| Id | Name | At (x, z) | Side | Rule here | Reference |
|---|---|---|---|---|---|
| RS | RAIL SIDING | -1232, -1314 | se | open | north-west corner beside the west double railway, which leaves the map through a tunnel portal |
| RC | RESCUE CHECKPOINT | 1246, 862 | nw | open | south-east corner beside the checkpoint (moved 8 studs inward from the reference) |
| SC | SUBSTATION CAR | 1112, -1124 | both (PMCs only) | car: paid 20,000 MK per seat, chance 50 %, 4 seats, 60 s shared countdown | north-east corner by the sniper band; Tarkov's V-Ex (SPT: 50 % chance, 60 s timer, 4 players; wiki: always there); pay at the car, see "Car exits" below; karma pricing is a gap |
| SE | SHELTER EXIT | 512, 77 | both | power (`MALL_POWER`) | the hidden room east of car park C: power, then a hidden switch in the L2 washroom, a keycard at the door, and the button inside that seals the door (Play) |
| WC | WEST CAMP | 550, -210 | both | co-op (2026-11-02): a PMC and a player scav together | at the reference's co-op position (the service tunnel, L0), not at the huts; the spec name is kept |
| RP | RIVER PATH | -1372, 286 | both | flare: closed until a green flare goes up within 75 studs (2026-11-02) | far west edge on the dirt road; the likely flare spot is 34 studs east |
| FG | FENCE GAP | 929, -219 | both | `nobag` (new kind) | a hole in the fence that closes the 46 m gap in the east service lane fence (reference point 947, -219), with drums and a red container; the backpack slot must be empty (grade D) |

Until Play adds the kind `nobag` to `World`/`Raid`, FENCE GAP behaves as an open extract.

**Car exits** (`Extract.luau`; the full rules and gaps are in `docs/design/EFT_PARITY.md`, "Car exits"). SUBSTATION CAR is a vehicle exit
like Tarkov's V-Ex: `{ kind = "paid", cost = 20000, chance = 0.50, seats = 4, depart = 60 }` in `L.ext`. It is rolled at raid start with the
chance exits (there in half the raids; when it is absent the zone says "NOT AVAILABLE THIS RAID" and the car is gone). A sedan stands west
of the zone's middle with a hold-F prompt on its right flank ("Pay 20,000 MK · SUBSTATION CAR", 1.5 s hold); the fare is taken at once and
buys one of four seats. The first fare starts a 60 s countdown that later passengers join; when it ends the car leaves for good, taking the
seated passengers inside the zone (extracted with SUCCESS), leaving the others behind without a refund, and the exit reads "THE CAR HAS
LEFT" until the next raid. Standing in the zone without a seat only says "PAY AT THE CAR". Scavs cannot use it (PMCs only).

## Spawns, AI and bosses (data for Play)

`L.pmc.nw` (65 points) and `L.pmc.se` (60) are the reference's PMC spawn points, `L.clusters` the 13 + 12 groups of 5, `L.rings` the 25
spawn rings of 2026. `L.scav` holds the 10 scav zones (BOLTWORKS PARK, BOLTWORKS HALL, CENTRAL CONCOURSE, RING ROAD, CENTRAL MALL,
KASSA HALL, NESTA PARK, SUBSTATION, TRUCK YARDS, NESTA HALL) with normal, boss and bot points, `L.aiIcons` the 2026 AI scav icons,
`L.bosses` THE CARETAKER (60 %, five zones) and a second boss entry that is not built, `L.hazard` the mine and sniper bands, the
IRONSIGHT alarm position (309, -65) and the raid time.

## The mall footprint (for the shell agent)

- The outline is `L.mall.outline` (ground, 22 points), `outL1` and `outL2` (the upper volumes); levels in `L.mall.levels[1..3]` with
  `floor`, `stores`, `corr`, `walls`; vertical links in `L.mall.vert` (including the four `V_OUT_*` vehicle ramps Ground already
  builds); `atria`, `voids`, `docks`, `service`, `terraces`, `pads` ({ id = "garage_island" } and { id = "west_pad" }).
- Ground: a flat pad at y -0.4 under the outline columns, so L0 slab tops go at **y 0**; the west pad is at 0. `B.inMall(x, z)` tells
  whether a point is under the ground footprint. A `Mall.luau` part makes `B.hasMall` true, so the placeholder outline is not built.
- Heights and thicknesses: `L.H = { ground = 0, L1 = 17.81, L2 = 47.50, ceil = { 16.25, 45.94, 67.50 }, roof = 69.10, slab = 1.6 }`.
- Door and container ids must be unique across the whole world; the old mall's `MM_` prefix is kept (this part uses `MM_SUB_` and `MM_RC_`).

## Names and keys

Nineteen unit names are fixed by the spec and set in `L.mall.levels[i].stores`: CAR PARK A to D, NESTA GARAGE, KASSA GARAGE, BOLTWORKS
GARAGE, SERVICE TUNNEL, THE SHELTER, UNIT 14, NESTA, NESTA CANTEEN, KASSA, BOLTWORKS, RESCUE POINT, IRONSIGHT, VOLTA, MEDIQ and the MEDIQ
STORE ROOM (BOLTWORKS OFFICE and GOODS-IN are rooms inside BOLTWORKS). Every other unit has `name = ""` and gets an original name from
the stores agents, who list them here next to the reference id. Outdoor names: THE SUBSTATION, WEST CAMP, RESCUE
CAMP, RESCUE CHECKPOINT, KART TRACK, KART PIT HOUSE, WEST LOT 2 to 6, HIGHWAY BOOTH 1 to 7, CARGO YARDS, NESTA TOWER, BOLTWORKS TOWER.
The `id` fields in `Layout.luau` are the reference's own record ids, kept as stable keys: some of them carry its brand words. They
are never shown to a player, so no sign, prompt or label may use an `id`; show `name`.

Keys (`L.keys`, 15; `exists` says whether `Items.luau` already has the item):

| Id | Opens | Level | Exists |
|---|---|---|---|
| KEY_MM_IRON_FRONT, KEY_MM_IRON_GRATE | IRONSIGHT front door, inner grate (weapon room) | L1 | no |
| KEY_MM_RESCUE | RESCUE POINT (three doors) | L1 | no |
| KEY_MEDIQ | MEDIQ store room | L2 | yes (reused) |
| KEY_VOLTA_STORE | VOLTA stock room | L2 | yes (reused) |
| KEY_MM_NESTA_REG, KEY_MM_KASSA_REG, KEY_MM_BOLT_REG | cash registers of the three anchors | L1 | no |
| KEY_MM_BOLT_OFFICE, KEY_MM_BOLT_GOODS | BOLTWORKS OFFICE, GOODS-IN | L1 | no |
| KEY_MM_SUBSTATION | THE SUBSTATION utility room (door `MM_SUB_UTILITY`) | outside | no |
| CARD_MALL_VAULT | the hidden keycard panel in the L2 washroom (opens the SHELTER door) | L2 | yes (reused; its description and name still speak of the old savings vault: reword them) |
| KEY_MM_UNIT14 | UNIT 14 container room | L0 | no |
| KEY_MALL_SECURITY | the SECURITY ROOM with the alarm terminal (L1 or L2, grade D; the item text says "upper level") | L1 | yes (kept: it gets this door) |
| KEY_MALL_STAFF | the staff door of the NESTA CANTEEN kitchen / the food-court kitchen (the item text matches) | L2 | yes (kept: it gets this door) |

Ten new key items (`KEY_MM_*`) are missing from `Items.luau`; part 1 does not edit that file. A door that names one stays locked until
the item exists.

## Not done yet

- **Mall shell**: written, see Part 2 below (not run in Luau or Studio).
- **Stores** (agents 3): every store's interior, containers, loose loot, doors, locked rooms and their keys, the ten new key items.
- **Play** (agent 3): extracts, PMC spawns by side (`W.spawns`, `W.sideExtracts`), scav zones, AI routes and watch posts (`W.patrols`,
  `W.watchPosts`), THE CARETAKER and his zones, what the power changes, the IRONSIGHT alarm, visit zones, lethal minefield and sniper
  bands, outdoor loot (the SUBSTATION yard, the camps, the checkpoint, the trucks), the `nobag` rule. Until then MapTests M01 (spawns,
  exfils, AI zones, patrol routes) and M05 (at least 10 containers per map; keys are real items) fail for this map; the others were not
  looked at.
- **Dress**: parked and burnt cars, trolleys, barriers, cones, bins, sandbags, nature at the edges.
- Outdoor containers and loose loot exist only inside THE SUBSTATION (8 containers); the camps, huts and sheds are empty shells.

## Parity gaps (copied to `docs/design/EFT_PARITY.md`)

- TRANSIT TO BORDER YARD stands at the highway's south end (2026-11-02); the one to Streets does not exist. WEST CAMP is Tarkov's
  co-op exit since 2026-11-02 (a PMC and a player scav together); SHELTER EXIT supports
  only the power rule (the hidden switch and the keycard panel are Play's). RIVER PATH opens by green flare since 2026-11-02.
- SUBSTATION CAR is a vehicle exit now (50 % chance, pay at the car, 4 seats, shared 60 s countdown, single use); it costs 20,000 MK (the
  2026 figure) and the price does not depend on Scav karma (a gap). FENCE GAP's `nobag` rule is new.
- The second boss (the hammer boss in the KASSA garage), mounted guns, propane cylinders, airdrop points and the lethal bands are not built.
- The ponds and the east canal are dry ditches (the budget allows no terrain water), so there is no wading or swimming; the relief is
  a smooth blend of 31 knots and 155 height samples, so peaks are lower than the reference; the rock mounds and berms are ours.
- The roof height, the shelter room, UNIT 14, the washroom switch and the security terminal are grade D in the reference (placeholders).
- The two south border rails (`rail_2`, `rail_3`) lie outside the limit and are not built.
- Outdoor buildings are single rooms with one or two doors; the reference's real interiors of the camps and sheds are not copied.

## Unverified (nothing has run in Studio yet)

The whole Ground pass and the TerrainKit write (612,000 columns, about 45 percent more than Border Yard's 423,000: time and memory at
server start), the look of the terrain, the roads and the ramps' fit to the shell, the Blender kit props in the buildings (the mock
stood in plain boxes), door swing directions and heights, the lever's flip, the pylon signs' text, the checkpoint gate's fit, the AI
cover scan (about 94,000 columns at step 9), frame rate on a low-end phone and memory use.

## Files

| File | What |
|---|---|
| `src/server/Maps/Meridian/init.luau` | entry: model "Meridian", the context `B`, runs the six parts under pcall, sets `W.bounds`, prints counts |
| `src/server/Maps/Meridian/Layout.luau` | generated layout data (do not edit) |
| `src/server/Maps/Meridian/Ground.luau` | terrain, roads, ramps, car park marks, rails, fences, power lines, hazard bands, kart track, rocks, boundary |
| `src/server/Maps/Meridian/Outside.luau` | THE SUBSTATION and its lever, camps, checkpoint, booths, huts, sheds, sign pylons |
| `src/server/Maps/MeridianMall.luau` | stub of the old module (no longer built) |
| `src/server/Maps/TerrainKit.luau` | shared terrain writer (unchanged) |
| `tools/interchange_layout.py` | reference JSON to `Layout.luau` |
| `docs/maps/MERIDIAN_INTERCHANGE_BUILD.md` | the build spec for all agents |

The context `B` every part receives: `kit, W, map, H, Kit, L, O, S, rng, count, points, powerHooks, hasMall, ground(x, z)`; Ground adds
`inside(x, z)` (playable polygon), `insideLimit(x, z)`, `band(x, z)` (0 playable, 1 minefield, 2 sniper), `classAt(x, z)` (0 plain, 1 rock
field, 2 rail bed, 3 concrete, 4 gravel, 5 asphalt, 8 outside the limit, 9 pond or canal bed, 10 bank), `wet(x, z)`, `slope(x, z)`,
`inMall(x, z)` and `T` (the TerrainKit result); Outside adds the named points in `B.points`: `SUBSTATION_SWITCH`, `SUBSTATION_UTILITY`,
`SUBSTATION_GATE`, `RESCUE_CHECKPOINT`, `RESCUE_GATE`, `WEST_CAMP`, `RESCUE_CAMP`, `KART_PIT`, `NESTA_TOWER`, `BOLTWORKS_TOWER`
(world positions at standing height).

## Part 2: the mall shell (car park, L1 and L2, atria, roof, empty store units)

Written 2026-11-01 by the mall shell agent, in parallel with the gameplay and stores agents: `Mall.luau`, `MallGrid.luau`, `MallPlan.luau`,
`MallShell.luau`, `MallLinks.luau` and `MallFit.luau` in `src/server/Maps/Meridian/`. `python3 tools/luau_check.py src` (structure only)
passes. **Nothing here has run in Luau or Studio.** The six files were transpiled to Lua 5.3 and run against the real `Layout.luau` with
stand-ins for the kit and the engine (offline, not in the repo): no error, no warning; every count below is that run's, and the checks
listed under "Checked offline" were made on its part list. This part replaces the "Mall shell" bullet under "Not done yet" and the
Status sentence that calls the mall a flat pad.

### What is built

The building at real scale on the reference's outline, empty: walls, floors, roof, stairs, the empty store units; no furniture, loot,
containers or store interiors. **5,360 parts** (budget 7,000) in the model "Mall": L0 706, L1 2,171, L2 1,442, Roof 431, Links 547, Units
(the 63 sign boards) 63. The plan (`MallPlan`, plain Lua, no engine calls) rasterises `Layout` into 3.125-stud cells (302 x 523: x -65.6..878,
z -965.6..668.8), one label array per level (outside, open floor, solid mass, hall, void, deck, unit n); every store rectangle of
`L.mall.levels[i].stores` is snapped to that grid and gets a label of its own. Walls are found as runs along the grid lines between cells
of different labels, and what a run is follows from the pair of labels (below). `Mall` runs `MallShell`, `MallLinks` and `MallFit` under
`pcall` (a failing step is logged and the rest still builds), then prints `[ZR] Meridian mall: ...` and a `detail` line.

| Area | Built as |
|---|---|
| Walls | Outer walls 2.4 thick (16.25 high at L0, up to the roof 69.1 above L1 and L2); partitions, party walls and shop fronts 2.0; the parapet round the open L1 decks 1.6 thick, 3.4 high; balustrades where a gallery meets a void (glass 3.5 high, handrail to 4.0). 3,191 wall parts; no wall part is thicker than 2.4 |
| L0 car park | Floor slab top at **y 0** (1.6 thick), the outline of `L.mall.levels[1].floor`; ceiling 16.25; 305 columns (3.2 square) on a 50-stud grid, kept clear of walls, flights and openings; zones A to D and the three garages as seven parking units with a 10 x 10 floor mark (letter or name); 13 gates in the outer wall (20 or 14 wide, 13 high); the west pad opens into the car park |
| L0 rooms | THE SHELTER (134 x 89 since 2026-11-02, was the whole 216 x 201 block; with columns, arch to its vestibule and the card door `MM_SHELTER` in car park C at (412.5, 175)); UNIT 14 (91 x 69, card door `MM_UNIT14` at (34.4, -818.8)); the SERVICE TUNNEL (297 x 37.5, WEST CAMP's extract inside, open at the west end and through a 19-stud passage at the east end into the KASSA garage) |
| L1 | Floor slab top **17.81**, ceiling 45.94 under the L2 floor and 49.69 (up to the roof) elsewhere; the galleries and corridors, 40 units, the three anchor halls, terraces and decks (open air, parapets) with 12 entries (14 x 12) and the dock bays, 71 openings (18 x 13) between halls and galleries |
| L2 | Floor slab top **47.50**, ceiling 67.50; galleries, 33 units (shops and the food court), the two washrooms (the men's holds the valve spot) |
| Anchors | KASSA (773 x 304), NESTA (473 x 394) and BOLTWORKS (691 x 351): one open hall each, 28.13 high under a thin roof (top 46.64), columns on a 68.75-stud grid (111), 11, 6 and 14 entrances, eight checkout lanes marked on the floor 26 studs inside the front (the yellow strips are not collidable), back-of-house blocks with keyless doors (see the door table), goods-in |
| Store units | Every unit of `L.mall.levels[i].stores` (76) plus eight of ours: an empty fitted box with party walls, a back wall, a glass front 13.5 high with one or more open entrances 13 high, a header and a sign board over the widest entrance, a roller-grille housing over the entrances of every third store (the grille is rolled up), a floor plate (0.03 above the slab), and for stores at least 22 wide and 28 deep a stock room: a 9.4-stud strip behind a partition with a keyless door `MM_<unit id>_STOCK` (51 of them) |
| Atria | Two octagonal voids through the L1 and L2 slabs (the car park ceiling is open under them), a glass balustrade wherever a gallery meets a void and a wall where a store does, the ramp `V_L0_L1_0` in the south one; above each a glass drum of eight panes with a metal rim and a stepped four-disc cap on the roof (the roof hole is the atrium shrunk by 4.6 studs) |
| Roof | Slab top 69.06 (153 parts), thin hall roofs (top 46.64), 41 skylight panes (strips 9.4 wide) over the halls and galleries; **not reachable** (the reference has no way up) |
| Links | 8 stairs L0 to L1, 2 stairs L1 to L2 and 3 stopped escalators at the positions of `L.mall.vert` (solid treads of at most 0.594 rise, 30 treads for 17.81 and 50 for 29.69, side panels and handrails, landings of at least 6 studs), the ramp `V_L0_L1_0` (a wedge); the four `V_OUT_*` vehicle ramps are Ground's, the shell's L1 deck meets their high ends |
| Docks | 14 bays (7 on each dock wall, 10 to 13 wide, 14 high); six stand open, eight are closed by a collidable `Shutter` plate (every third bay is open) |
| Washrooms (L2) | The east end of the reference's washroom rectangle (the burger spot keeps the west part): men's room x 362.5..390.6 and women's room x 390.6..415.6, z -309.4..-265.6, doors on the south side (`MM_WASH2_MEN`, `MM_WASH2_WOMEN`), stalls, sinks and a mirror; the valve spot `B.points.SHELTER_SWITCH` is on the men's north wall at (376.6, -307.5) |
| Security room (L1) | About 25 x 28 at x 581..606, z 216..244 (north of the BOLTWORKS hall), door `MM_SECURITY` on its east face (KEY_MALL_SECURITY), a desk, a monitor and filing cabinets; `B.points.SECURITY_TERMINAL` stands in it |
| Light | See "Points, power and lights" |

The part counts by step: shell 4,046 (floors 361, roof 431, walls 3,191, sign boards 63), links 547 (490 treads, 28 handrails, 28 side
panels, 1 wedge), fit 767 (stock walls 153, anchors 24, zone marks 7, columns 416, rooms 18, lamps 147, door lamps 2). In the mock the
plan took about 2.3 s and the build 0.15 s (plain Lua 5.3; Luau and Roblox will differ). The plan and the build hand the thread back
(`task.wait()`, only when `task` exists, after 0.04 to 0.05 s of work) so that a slow server cannot run into the script timeout.

### Units: `B.units[id]`

Every unit is published under its Layout store id (`L1_adik`); ours are `BACK_1` to `BACK_4` (NESTA stock rooms, KASSA back of house,
BOLTWORKS stock block, BOLTWORKS offices; L1), `SECURITY_ROOM` (L1), `SHELTER_VESTIBULE` (L0), `WASH_L2_MEN` and `WASH_L2_WOMEN`. The `id`
is a key and is never shown (some carry the reference's brand words); show `name`.

| Field | Meaning |
|---|---|
| `id`, `name`, `kind`, `level` | the Layout record (`name` is "" for the 57 stores the stores agents name; `kind` is the Layout's: `clothing`, `food`, `electronics`, `locked store`, `closed` ...) |
| `front` | `"N"`, `"S"`, `"E"` or `"W"`: the side of the entrance (the side with most entrance width; a service room: the side of its door; anchors: the side facing the central concourse); nil for the seven parking units |
| `cframe` | world `CFrame` at the middle of the sales area's floor, y = the slab top (the plate is 0.03 above); its look vector points **out through the front**, so local -Z is the front and +Z the back wall; local +X is to the right when looking out |
| `size` | `Vector3(width across the front, floor to ceiling, depth)` of the sales area |
| `rect` | `{ x0, z0, x1, z1 }` the sales area in map-local studs (axis aligned; the stock strip and the walls are excluded); `outer` is the whole unit with the stock strip (not on anchors) |
| `floorY`, `ceilY`, `ceilMin` | the slab top, the highest and the lowest ceiling (an L1 store partly under an L2 gallery has two: `L1_book_store`, `L1_dom`) |
| `service` | true when the unit has no glass front (stock blocks, rooms, washrooms) |
| `doors` | ids in `W.doors` that belong to the unit |
| `entrances` | `{ pos = Vector3 (world, at floor level), width, side, kind }` for every opening of the front: `"shop"`; anchors list `"hall"` (to the galleries), `"entry"` (to the terraces) and `"dock"` (with `open = true` when the shutter is up). Keep these clear |
| `stock` | `{ door = id, cframe, size }` of the stock strip, when the unit has one (same frame convention) |
| `sign`, `signGui` | the board (`Sign_<id>`, model Mall/Units) and its `SurfaceGui`; the `TextLabel` holds the name, or the kind in capitals while the name is "". Set the text there and `u.name` when naming a store |
| `floor` | the `UnitFloor` plate |
| anchors only | `checkouts` (eight `CFrame`s, look vector out through the front), `backs` (ids of their back-of-house units), `goodsIn` (door id) |
| parking only | `mark` (the `ZoneMark` plate); `cframe` is the zone's middle and `size` the whole zone |

A prop at depth `d` studs in from the front line and `x` studs to the right: `u.cframe * CFrame.new(x, 0, d - u.size.Z / 2)`.
Store entrances are open gaps: a store that needs a door (IRONSIGHT, RESCUE POINT, MEDIQ STORE ROOM, a grille) builds it in the gap from
`entrances`. A store may re-key a shell door by setting `W.doors[id].key` before `World` builds the doors.

### The units (84)

76 from `Layout` (L0 10, L1 35 with the three anchors, L2 31) and eight of ours: `SHELTER_VESTIBULE`, `BACK_1` to `BACK_4`, `SECURITY_ROOM`,
`WASH_L2_MEN`, `WASH_L2_WOMEN`. Sales W x D are the `size` of the sales area in studs (width across the front, depth), Height is floor to
ceiling (two values: the highest and the lowest ceiling), Entr. the number of `entrances`, Stock whether the unit has a stock room, Other
doors the leaves in `W.doors` besides its own stock room door. The 57 blank store names are for the stores agents.

**L0** (11 units)

| Id | Name | Kind | Front | Sales W x D | Height | Entr. | Stock | Other doors |
|---|---|---|---|---|---|---|---|---|
| `L0_garage_a_central_parking_north_hall` | CAR PARK A | parking | - | 297 x 328 | 16.25 | 0 |  |  |
| `L0_garage_b_central_parking` | CAR PARK B | parking | - | 291 x 306 | 16.25 | 0 |  |  |
| `L0_garage_c_central_parking` | CAR PARK C | parking | - | 431 x 391 | 16.25 | 0 |  |  |
| `L0_garage_d_central_parking_south` | CAR PARK D | parking | - | 388 x 391 | 16.25 | 0 |  |  |
| `L0_idea_garage` | NESTA GARAGE | parking | - | 359 x 412 | 16.25 | 0 |  |  |
| `L0_goshan_garage` | KASSA GARAGE | parking | - | 241 x 425 | 16.25 | 0 |  |  |
| `L0_oli_garage` | BOLTWORKS GARAGE | parking | - | 234 x 375 | 16.25 | 0 |  |  |
| `L0_scav_camp_tunnel_co_op_extract` | SERVICE TUNNEL | tunnel | W | 35 x 294 | 16.25 | 0 |  |  |
| `L0_saferoom_exfil_room` | THE SHELTER | shelter | S | 134 x 89 | 16.25 | 0 |  |  |
| `SHELTER_VESTIBULE` |  | vestibule | S | 26 x 32 | 16.25 | 0 |  | `MM_SHELTER` |
| `L0_object_14_container_room` | UNIT 14 | unit14 | S | 91 x 69 | 16.25 | 0 |  | `MM_UNIT14` |

**L1** (40 units)

| Id | Name | Kind | Front | Sales W x D | Height | Entr. | Stock | Other doors |
|---|---|---|---|---|---|---|---|---|
| `L1_goshan` | KASSA | anchor | W | 773 x 304 | 28.13 | 11 |  | `MM_KASSA_BACK_2`, `MM_KASSA_BACK_1` |
| `L1_idea` | NESTA | anchor | S | 473 x 394 | 28.13 | 6 |  | `MM_NESTA_STOCK_2`, `MM_NESTA_GOODS`, `MM_NESTA_STOCK_1` |
| `L1_oli` | BOLTWORKS | anchor | N | 691 x 351 | 28.13 | 14 |  | `MM_BOLT_STOCK_2`, `MM_BOLT_STOCK_1`, `MM_BOLT_OFFICES_1`, `MM_BOLT_OFFICES_2` |
| `BACK_1` | NESTA STOCK ROOMS | stock | S | 154 x 151 | 49.69 | 0 |  | `MM_NESTA_STOCK_2`, `MM_NESTA_GOODS`, `MM_NESTA_STOCK_1` |
| `BACK_2` | KASSA BACK OF HOUSE | stock | S | 154 x 123 | 49.69 | 0 |  | `MM_KASSA_BACK_2`, `MM_KASSA_BACK_1` |
| `BACK_3` | BOLTWORKS STOCK BLOCK | stock | N | 113 x 263 | 49.69 | 0 |  | `MM_BOLT_STOCK_2`, `MM_BOLT_STOCK_1` |
| `BACK_4` | BOLTWORKS OFFICES | stock | E | 185 x 98 | 49.69 | 0 |  | `MM_BOLT_OFFICES_1`, `MM_BOLT_OFFICES_2` |
| `SECURITY_ROOM` | SECURITY | security | E | 26 x 23 | 49.69 | 0 |  | `MM_SECURITY` |
| `L1_adik` |  | sports | E | 76 x 59 | 28.13 | 3 | yes |  |
| `L1_avokado` |  | food | W | 41 x 94 | 49.69 | 2 | yes |  |
| `L1_bizarro` |  | clothing | W | 23 x 44 | 49.69 | 2 | yes |  |
| `L1_book_store` |  | books | S | 123 x 69 | 49.69 / 28.13 | 5 | yes |  |
| `L1_boots_4_life` |  | shoes | E | 119 x 23 | 28.13 | 2 |  |  |
| `L1_brutal` |  | clothing | N | 79 x 50 | 28.13 | 3 | yes |  |
| `L1_dino_clothes` |  | clothing | N | 26 x 113 | 28.13 | 4 | yes |  |
| `L1_dom` |  | homeware | S | 148 x 50 | 49.69 / 28.13 | 4 | yes |  |
| `L1_emercom` | RESCUE POINT | locked store | E | 26 x 59 | 28.13 | 3 | yes |  |
| `L1_generic` |  | general | W | 51 x 53 | 28.13 | 2 | yes |  |
| `L1_german` |  | general | W | 35 x 26 | 28.13 | 1 |  |  |
| `L1_idea_bistro` | NESTA CANTEEN | food | S | 198 x 323 | 49.69 | 6 |  |  |
| `L1_kiba` | IRONSIGHT | locked store | W | 79 x 25 | 28.13 | 1 | yes |  |
| `L1_kostin` |  | clothing | W | 48 x 66 | 28.13 | 4 | yes |  |
| `L1_mantis` |  | electronics | S | 79 x 50 | 28.13 | 3 | yes |  |
| `L1_mode7` |  | clothing | W | 57 x 25 | 28.13 | 1 | yes |  |
| `L1_nortex` |  | clothing | E | 107 x 26 | 49.69 | 4 |  |  |
| `L1_pretty_lights` |  | lighting | E | 79 x 25 | 28.13 | 2 | yes |  |
| `L1_rasmussen` |  | electronics | E | 35 x 75 | 28.13 | 4 | yes |  |
| `L1_revis` |  | general | S | 85 x 31 | 28.13 | 2 | yes |  |
| `L1_spiel` |  | toys | E | 54 x 23 | 28.13 | 2 |  |  |
| `L1_sports` |  | sports | N | 85 x 22 | 28.13 | 2 | yes |  |
| `L1_telespot` |  | electronics | E | 73 x 23 | 28.13 | 1 |  |  |
| `L1_texho` |  | electronics | S | 85 x 19 | 28.13 | 3 | yes |  |
| `L1_the_national` |  | clothing | N | 132 x 50 | 28.13 | 3 | yes |  |
| `L1_top_brand` |  | clothing | S | 60 x 75 | 28.13 | 4 | yes |  |
| `L1_trend` |  | clothing | N | 85 x 19 | 28.13 | 2 | yes |  |
| `L1_tts` |  | electronics | S | 82 x 28 | 28.13 | 3 | yes |  |
| `L1_unlabelled_store_n_of_viking` |  | unlabelled | S | 126 x 47 | 28.13 | 2 | yes |  |
| `L1_viking` |  | sports | S | 129 x 50 | 28.13 | 2 | yes |  |
| `L1_voyage` |  | travel | W | 29 x 25 | 28.13 | 1 | yes |  |
| `L1_yushka` |  | clothing | W | 60 x 25 | 28.13 | 1 | yes |  |

**L2** (33 units)

| Id | Name | Kind | Front | Sales W x D | Height | Entr. | Stock | Other doors |
|---|---|---|---|---|---|---|---|---|
| `WASH_L2_MEN` | MEN | washroom | S | 26 x 41 | 20 | 0 |  | `MM_WASH2_MEN` |
| `WASH_L2_WOMEN` | WOMEN | washroom | S | 23 x 41 | 20 | 0 |  | `MM_WASH2_WOMEN` |
| `L2_apteka` | MEDIQ | pharmacy | S | 38 x 19 | 20 | 1 | yes |  |
| `L2_arena` |  | sports | S | 38 x 38 | 20 | 2 | yes |  |
| `L2_burger_house` |  | food | S | 57 x 16 | 20 | 1 |  |  |
| `L2_burger_spot_49` |  | food | N | 57 x 31 | 20 | 2 | yes |  |
| `L2_closed_for_repairs` |  | closed | W | 66 x 69 | 20 | 5 | yes |  |
| `L2_coffee_joy` |  | food | S | 63 x 19 | 20 | 1 | yes |  |
| `L2_eastland` |  | clothing | N | 41 x 28 | 20 | 1 | yes |  |
| `L2_fashion_store` |  | clothing | N | 79 x 19 | 20 | 2 | yes |  |
| `L2_father_sons` |  | clothing | S | 79 x 23 | 20 | 1 |  |  |
| `L2_fck` |  | food | N | 57 x 23 | 20 | 1 |  |  |
| `L2_figaro` |  | clothing | N | 85 x 31 | 20 | 3 | yes |  |
| `L2_furniture_mk` |  | furniture | S | 85 x 31 | 20 | 3 | yes |  |
| `L2_history_museum` |  | museum | N | 91 x 28 | 20 | 6 | yes |  |
| `L2_intourist` |  | travel | S | 38 x 19 | 20 | 1 | yes |  |
| `L2_jacob_jacob` |  | clothing | S | 82 x 31 | 20 | 3 | yes |  |
| `L2_mcdaniels` |  | food | S | 57 x 19 | 20 | 1 |  |  |
| `L2_na_svyazi` |  | electronics | N | 38 x 38 | 20 | 2 | yes |  |
| `L2_opening_soon` |  | closed | E | 44 x 25 | 20 | 2 | yes |  |
| `L2_papillon` |  | clothing | E | 110 x 19 | 20 | 2 | yes |  |
| `L2_philly_cute` |  | food | S | 44 x 75 | 20 | 5 | yes |  |
| `L2_pushkin` |  | food | E | 73 x 38 | 20 | 1 | yes |  |
| `L2_sara` |  | general | S | 35 x 19 | 20 | 1 | yes |  |
| `L2_shiccos` |  | food | N | 57 x 19 | 20 | 2 |  |  |
| `L2_sushi_huyushi` |  | food | N | 57 x 16 | 20 | 1 |  |  |
| `L2_tarducks` |  | food | S | 57 x 19 | 20 | 3 | yes |  |
| `L2_tarkovstar` |  | general | N | 38 x 22 | 20 | 1 | yes |  |
| `L2_tarzdrav` |  | pharmacy | E | 94 x 31 | 20 | 1 | yes |  |
| `L2_techlight` | VOLTA | electronics | E | 116 x 19 | 20 | 3 | yes |  |
| `L2_ultra_med_locked_room` | MEDIQ STORE ROOM | locked store | W | 32 x 19 | 20 | 1 | yes |  |
| `L2_underway` |  | food | W | 76 x 38 | 20 | 1 | yes |  |
| `L2_urban_clothes` |  | clothing | S | 41 x 25 | 20 | 1 | yes |  |

### Doors and keys

65 doors in `W.doors`, all `MM_` ids and unique, 5.2 x 8.6 studs, a 0.35 leaf swinging into the unit; keyless ones carry `openChance = 0.4`;
a card door has a reader panel and a status lamp on the outside. Play marks `power` by key, so the shell
does not.

| Id | Where | Key | What |
|---|---|---|---|
| `MM_SHELTER` | (412.5, 175), L0, the vestibule south of THE SHELTER in car park C | `CARD_MALL_VAULT` (card) | the shelter's door; the room has a 13.8-wide arch behind it |
| `MM_UNIT14` | (34.4, -818.8), L0, UNIT 14's south wall | `KEY_MM_UNIT14` (card) | UNIT 14 |
| `MM_SECURITY` | (606.2, 229.7), L1, the security room's east face | `KEY_MALL_SECURITY` | the security room |
| `MM_WASH2_MEN`, `MM_WASH2_WOMEN` | (376.6, -265.6), (403.1, -265.6), L2 | none | the washrooms |
| `MM_NESTA_STOCK_1`, `MM_NESTA_STOCK_2`, `MM_NESTA_GOODS` | (578.1, -781.2), (500, -857.8), (656.2, -818), L1 | none | NESTA's stock block `BACK_1`; goods-in opens east, onto the dock bays |
| `MM_KASSA_BACK_1`, `MM_KASSA_BACK_2` | (734.4, -400), (656.2, -462.5), L1 | none | KASSA's back of house `BACK_2` |
| `MM_BOLT_STOCK_1`, `MM_BOLT_STOCK_2` | (535.9, 312.5), (478.1, 445.3), L1 | none | BOLTWORKS' stock block `BACK_3` |
| `MM_BOLT_OFFICES_1`, `MM_BOLT_OFFICES_2` | (62.5, 500), (12.5, 406.2), L1 | none | BOLTWORKS' offices `BACK_4` |
| `MM_<unit id>_STOCK` (51) | in each partition, label "Stock room" | none | the stock rooms of the stores |

Part 3 expects these ids that the shell does **not** build (they belong to the stores, who fit them into the entrance gaps and rooms):
`MM_IRON_FRONT`, `MM_IRON_GRATE`, `MM_RESCUE_N/E/W`, `MM_MEDIQ_STORE`, `MM_VOLTA_STORE`, `MM_NESTA_CASH`, `MM_KASSA_CASH`, `MM_BOLT_CASH`,
`MM_BOLT_OFFICE`, `MM_BOLT_GOODS`, `MM_STAFF_KITCHEN`. The BOLTWORKS office and stock doors above are keyless placeholders: re-key them
(`W.doors.MM_BOLT_OFFICES_1.key = "KEY_MM_BOLT_OFFICE"`) or ignore them.

### Points, power and lights

- `B.points.SHELTER_SWITCH`: a `CFrame` at (376.6, 50.8, -307.5) map-local (world z + 9000): standing height on the L2 men's room floor,
  look vector (0, 0, 1), so the cabinet faces south into the room; nothing stands within 5 studs of it.
- `B.points.SECURITY_TERMINAL`: a `Vector3` at (593.75, 21.11, 218.0) map-local, standing height in the L1 security room (an L1 floor part
  lies under it). Play builds the valve and the terminal there; the shell registers neither switch.
- `B.points.SHELTER_DOOR` (412.5, 3.3, 171.9) and `B.points.SHELTER_ROOM` (512.5, 3.3, 77.2), both standing points on the L0 floor
  (the second is the SHELTER EXIT).
- **Lights: 149**, none with shadows (the budget is 400 for the map and 40 shadowed; Outside has 13, so 162 are used). 123 main lamps
  (5 x 1.4 fixtures under the ceiling, one per block of 52 cells on L0, 48 on L1, 44 on L2; range 48, 48 and 44 studs, brightness 0.8)
  are **dead at build** and follow `MALL_POWER` through one `B.powerHooks` entry (the fixture turns neon, the light comes on). 24
  emergency lamps (red, 1.2 studs, range 20 to 22, brightness 0.5; nine on L0, nine on L1, six on L2) and two door lamps (over the
  shelter's reader and the security door) stay lit, so the mall is dark and red until the switch is thrown. The sign boards are lit by
  the lamps (`LightInfluence` 1).

### For the stores and gameplay agents

1. Build in `B.units[id]` (frame and fields above); keep the `entrances` and the stock room door clear. The stock rooms are empty
   boxes; 12 stores (too shallow, or open like the NESTA CANTEEN) have none.
2. To name a store set `u.name` and the text of `u.signGui`'s `TextLabel`; never show an `id`.
3. Do not register `SHELTER_SWITCH` or `MM_ALARM`; do not set `power` on doors (Play matches by key).
4. Extra lights: append to `B.powerHooks`, apply the off state when built, stay under the budget above.
5. The anchors' `checkouts` are the places for the tills; `goodsIn` names the door to the goods-in area; `entrances` of kind `dock` tell
   which bays stand open.
6. The shell's parts are anchored and named: `Floor` (slabs), `UnitFloor` (plates), `Column`, `Sign_<id>`, `Shutter`, `ZoneMark`,
   `CheckoutLane`, `Reader`/`Led` (card doors). Floor tops are exactly 0, 17.81 and 47.50.

### Known quirks

- Four reference points sit on a wall line or over a void: `KEY_MM_RESCUE`'s tile (153.1, -306.2) on RESCUE POINT's west wall,
  `KEY_MM_NESTA_REG`'s (162.5, -753.1) on the NESTA CANTEEN's east glass front, the scav point (520.6, 268.1) on BOLTWORKS' north wall, and
  Play's L1C route point (266, 58) over the south atrium (Play drops points without a floor). Move the first three 2 to 3 studs onto the
  floor. The card key's tile (359.4, -287.5) lies on the floor of `L2_burger_spot_49`, 2 studs from the washroom wall.
- Two L1 stores stand partly under an L2 gallery and are open to the roof elsewhere: `L1_book_store` and `L1_dom` (two ceilings:
  `ceilY` 67.5 and `ceilMin` 45.94).
- Flights are as short as the reference's runs, snapped to the grid: slopes run from 12 to 27 degrees, except `V_L0_L1_7` at 32 degrees
  with 0.94-stud treads (reference 28). The three escalators are solid stairs (stopped), one 15.6-wide flight each, not two lanes.
- The atria open the car park ceiling: nothing in the reference says what lies under them. The south atrium holds the ramp.
- Closed dock bays carry a collidable shutter plate; the dock wall is straight (no sawtooth) with solid blocks between the bays.
- Four L1 `Part` slabs (the dock deck pieces at the ends of the dock ramps) stand outside the footprint on purpose; Play counts them as L1
  floors, which they are.

### Checked offline

On the mock's 5,360 parts (Python over the part list; the Luau code itself never ran):

- Slab tops are exactly y 0, 17.81 and 47.50 (none off); unit plates are 0.03 above. Play's floor rule finds 104 L1 floors (60 slabs, 40 plates,
  4 dock deck pieces) and 107 L2 floors (74 slabs, 33 plates); the hall roofs (top 46.64) and skylights (46.5) are more than 0.7 below 47.50, so
  they are not taken for floors. Every walkable cell of every level has a floor part under it; no L2 floor lies over a void.
- Walkability: on a lattice of half cells, a point is blocked by a collidable part between floor + 0.6 and floor + 6.4; from the 39 gates,
  entries and dock bays, joined across the levels by the 13 flights and the ramp, **every** free walkable cell is reached (L0 86,885,
  L1 128,258, L2 25,593; none left). Every wall opening is clear (0 blocked probes).
- No wall part is thicker than 2.4 (the one 3.0 vertical part is the security room's filing cabinet); no exact duplicate parts; 136
  coplanar overlapping top faces remain (2.4 x 2.4 joints of collinear walls of one style, hidden duplicates inside slabs).
- Flights: 30 (L0 to L1) or 50 (L1 to L2) treads, rise 0.594 at most, the last tread's top within 0.001 of the next floor, landings at
  both ends, nothing hangs over a flight.
- The gameplay agent's points (routes, boss zones, extracts SE and WC, poi): on a floor and free, except those named above.

### Parity gaps from this part (copied to `docs/design/EFT_PARITY.md`)

- **Walls are inferred.** The reference draws the outline, a few closed blocks and some partitions; every other wall follows the store,
  hall and corridor rectangles snapped to a 1 m grid (within 1.6 studs of the reference), so gallery widths are whole metres.
- **Escalators** are three stopped, solid, single-lane flights (no up and down lanes); the stairs L0 to L1 are 15.6 wide flights with
  handrails and side panels, the steepest 32 degrees (reference 28).
- **Domes** are eight-pane glass drums with a stepped cap, not the reference's curved domes; 41 skylight strips (the reference: about 40).
- **Loading docks**: 7 bays per dock, 14 in all (the reference: 8 per dock), straight wall instead of a sawtooth, 6 open and 8 shut; dock
  doors and levellers are in no source.
- **Interiors** of the shelter, UNIT 14, the washrooms, the security room and the tunnel are ours (grade C or D in the reference); the car park's
  column grid is 50 studs (the reference: about 8 m) and its column positions are ours.
- **Lighting**: 149 sparse lamps (one per 150 studs), dead until the power is on, plus 26 red lamps; the reference's lighting is not
  documented.
- **Atria** open down to the car park; the reference does not say.
- **Stores** are empty boxes: no counters, shelves, stock or loot yet (the stores agents'); 12 small or open stores have no stock room.
- **The tunnel's east end** links the KASSA garage through a 19-stud passage cut in the solid block between them.
- **Not run**: nothing has run in Studio, on a phone or on a console; no frame rate was measured.

### Unverified (part 2; nothing has run in Luau)

The whole of `Mall*.luau` in Luau and Studio. In particular: the real part count and build time (the mock took 2.3 s for the plan and
0.15 s for the build in plain Lua; the code yields with `task.wait()` after 0.04 to 0.05 s of work, never between making a part and setting
it up); collision of the real parts (the walkability result is geometric, not a Humanoid's), above all on the steepest flights; whether a
0.594-stud tread feels right on a phone; the look under the real lighting (the mall is dark until the switch); sign legibility; door swing
directions; the fit of Play's valve cabinet and terminal in their rooms; the AI's pathing round 416 columns (305 in the car park, 111 in the
halls); frame rate on a low-end phone with 5,360 parts here, Ground and Outside's 3,514 and Dress.

### Files (part 2)

| File | What |
|---|---|
| `src/server/Maps/Meridian/Mall.luau` | orchestrator: context, part helpers, pacing, power hook, order of the steps, `B.units` fallback, summary lines |
| `src/server/Maps/Meridian/MallGrid.luau` | the grid: rasterising polygons, the run finder (walls along grid lines), rectangle cover |
| `src/server/Maps/Meridian/MallPlan.luau` | the plan: labels per level, units, atria, flights, wall classes, openings, slabs, roof, reachability and its repair |
| `src/server/Maps/Meridian/MallShell.luau` | floors, roof, domes, walls, store fronts, balustrades, door leaves, dock shutters, sign boards |
| `src/server/Maps/Meridian/MallLinks.luau` | stairs, the ramp, escalators |
| `src/server/Maps/Meridian/MallFit.luau` | stock rooms, `B.units`, anchors' checkouts, zone marks, columns, washrooms, security room, lamps |

## Part 3: gameplay (extracts, spawns, AI, the Caretaker, power, keys, dressing)

Written 2026-11-01 by the gameplay agent, in parallel with the shell and the stores: `Play.luau` and `Dress.luau` in
`src/server/Maps/Meridian/`, ten new key items, small additive edits to seven service and client files, and a group of checks in
`src/server/Tests/LogicTests.luau`. `python3 tools/luau_check.py src` (structure only) passes. **Nothing here has run**: the build
environment has no Luau runtime and Studio was not used. Counts marked (offline) were recomputed in Python from `Layout.luau` with
the same rules; they are not output of the Luau code. This part replaces the "Play" and "Dress" bullets under "Not done yet" and the
line under "Extracts (7)" that says FENCE GAP behaves as an open extract until Play adds `nobag`.

### What `Play.luau` builds

Each section runs under its own `pcall`, so a failure is logged (`[ZR] Meridian play: <section> failed`) and the rest still build. One
summary line is printed: `[ZR] Meridian play: ... spawns, ... patrol routes, ... watch posts, ... scav zones, boss ..., ... mines ...`.
Everything that depends on the shell (L1 and L2 points, the washroom, the security room) is checked against the floor parts the shell
actually built and left out when absent, so the map still builds without `Mall.luau`.

**Extracts (7)**, positions and sizes from `L.ext`:

| Id | Name | Offered to | Rule as built |
|---|---|---|---|
| RS | RAIL SIDING | MallSE spawners | open |
| RC | RESCUE CHECKPOINT | MallNW spawners | open |
| SC | SUBSTATION CAR | both (PMCs only) | car: `paid` 20,000 MK with `chance` 0.5, `seats` 4, `depart` 60 (`Extract.luau`: pay at the car) |
| SE | SHELTER EXIT | both | `power` with `also` and `last`: the mall power (`MALL_POWER`), then the washroom valve (`SHELTER_SWITCH`), then the door button inside (`SHELTER_LOCK`, which seals the card door for the raid); a plain `MALL_POWER` rule if the valve could not be built |
| WC | WEST CAMP | scavs only | scav |
| RP | RIVER PATH | both | flare |
| FG | FENCE GAP | both | `nobag` |

`W.sideExtracts`: nw = RC, SC, SE, RP, FG; se = RS, SC, SE, RP, FG. Scavs get all seven except SC (a car is for PMCs). SE and WC stand on the L0 floor
under the mall (y 0.1, compact boxes). `Extract.blocked` reads `also` first, so before the power is on a player reads the original
"throw the switch at the substation" text and afterwards "sealed, find the valve hidden in a washroom". FENCE GAP refuses while the
`back` slot holds a pack and cancels the hold if one is put on during it; the HUD shows "NO BACKPACK".

**The valve** (`W.switches.SHELTER_SWITCH`): a water-service cabinet with a brass handle (6 parts) at `B.points.SHELTER_SWITCH`, else
at `L.poi.WASHROOM` on L2. Prompt "Pull the handle", 2 s hold, 3 s delay; it answers only while `MALL_POWER` is on (a `B.powerHooks`
entry) and the handle has not been pulled, and resets at every raid start. It is skipped, with a warning and the plain power rule, when
there is no L2 floor part under the point; if the shell registered a switch of that id first, Play builds nothing and the rule reads the
shell's. This stands for Tarkov's urinal flush, which reveals a keypad (see the gaps).

**Electric locks**: Play sets `power = "MALL_POWER"` on every door of this map (registered in `W.doors`, no `map` yet) whose key is
KEY_MM_IRON_FRONT, KEY_MM_IRON_GRATE, KEY_MEDIQ, CARD_MALL_VAULT or KEY_MM_UNIT14 (Tarkov: the Kiba doors, the ULTRA medical storage,
the saferoom keypad and the Object keycards need the mall power). `Doors.use` then refuses the key until the switch is on ("NO POWER"
toast, locked sound). Doors are matched by their key, never by their id.

**IRONSIGHT alarm**: Play polls the door whose key is KEY_MM_IRON_FRONT twice a second. Three seconds after it opens, a red beacon
(hung under the L1 ceiling at `L.hazard.ironAlarm`, 2 parts and one light without shadows, only where an L1 floor exists) flashes for up
to 60 s and every 5 s `AI.hearShot` (loudness 1.6, about 320 studs) calls everything in earshot to the shop. The security terminal
(switch `MM_ALARM`, prompt "Disable the alarm", 2 s hold, 3 parts) is built at `B.points.SECURITY_TERMINAL`, else at `L.poi.SECURITY_L1`,
only on an L1 floor; using it silences the alarm for the rest of the raid. The alarm arms again when the door is locked again at the
next raid. The terminal is not locked: the security room's own door (KEY_MALL_SECURITY) is the shell's or the stores' to place.

**PMC spawns**: 25 (offline), `N1` to `N13` (side nw, MallNW) and `S1` to `S12` (side se, MallSE), one per `L.clusters` entry: the
reference spawn point (`L.pmc`) with the most room within 30 studs of the cluster centre, else the nearest one moved to open ground
(at most 40 studs); 3.4 studs above the ground, yaw from the reference, at least 6 studs from any building, 4 from the boundary, 3 from a
fence, 6 from a rail, slope under 0.3. Reference points that stand on the mall's terraces end up on the ground beside the mall. Each
spawn is named from the nearest label or yard (each name once) and carries its side's extracts.

**AI**: six patrol routes and watch posts, each point kept only where it has its floor (outdoors: open ground within 20 studs; L0:
inside `L.mall.levels[1].floor`; L1 and L2: a shell floor part of that level under the point). A route with fewer than two valid
points is dropped with its post.

| Route | Post | Level | Where |
|---|---|---|---|
| LOT | Car Park Guard | ground | WEST LOT 3, a loop |
| DOCK | Dock Guard (stands at the head of the apron) | ground | NESTA DOCK APRON |
| SUB | Substation Guard | ground | the apron west of THE SUBSTATION's main building |
| L0B | Garage Guard | L0 | CAR PARK B |
| L1C | Concourse Guard | L1 | the loop round the central concourse |
| L2C | Gallery Guard | L2 | the upper gallery corridor, out and back |

Scav zones (`W.scavZones`): the reference's scav and boss-zone points of the ten `L.scav` zones and the 2026 AI icons, each at its own
level, plus 53 anchors of ours (the five west lots, the aprons, the yards, the camps, the halls and galleries on both floors); outdoors
snapped to open ground, upstairs floor-checked, 12 studs apart, at most 4 per building. MapTests M01 needs 10.

**THE CARETAKER** (`W.boss`): chance 0.6 (`L.bosses`), look `bodyguard`, loadout `caretakerLoadout`, no crew (Killa has no guards), five
zones: CENTRAL CONCOURSE (L1), CENTRAL MALL (L2), KASSA HALL, BOLTWORKS HALL and NESTA HALL (L1), each a closed route of five or six
points with its home at the first. The AI rolls the 60 % at raid start and, if it hits, picks one zone at random (`AI.bossZone`). A
zone without a shell floor under at least three of its points is dropped; with none left there is no boss.

**Visit zones** (`W.visitZones`, centre and radius): SUBSTATION, SHELTER, IRONSIGHT, CONCOURSE, WEST_CAMP, RESCUE_CAMP, KART_TRACK.

**Hazards** (both bands lie outside the playable polygon, as in the reference): the east sniper band gets 53 (offline) stair-step strips
40 studs long (`Hazards.sniperZone`, the same rules as Border Yard: a warning shot after 3 s, hits from 6 s), spawns and extracts within
22 studs stay clear. The west minefield gets about 241 (offline) hidden charges on a jittered 34-stud grid, none within 12 studs of the
playable edge (`Hazards.mineField`, new). A player within 3.4 studs of a live charge sets it off: a propane-sized blast under the feet
and a 400-damage wound (cause MINE), so it kills. Each charge goes off once per raid; `Hazards.reset` arms them again.

**Outdoor loose loot** (`kit.loose`, area "meridian", snapped): one to six spots per yard by what it is (WEST LOT and TRUCK yards pool
`mall`, SUBSTATION `toolbox`, DOCK, SERVICE and CARGO `crate`, the rest `junk`), one beside each hut, camp, booth and rescue building
(`junk`), 30 on the L0 floor (`mall`); never within 30 studs of another spot of Play's.

**`B.geo`**: Play publishes its geometry tests to `Dress` (footprints, roads, fences, rails, rocks, the boundary, keep-outs for spawns,
extracts, routes, posts, zones, doors, containers, loose loot and named points, a spatial index of the map's solid parts, and
`floorAt(level, x, z)`). The index of solid parts is built on first use by scanning the map model once, so Play and Dress must run
after the shell and the stores (they do: `init.luau` order).

### Edits outside `src/server/Maps/Meridian/` (all small and additive)

- `Services/Extract.luau`: kind `nobag` (`Extract.blocked` and the new `Extract.holdBlocked`, checked again every tick of the hold);
  kind `power` takes an optional `also` (a switch that must be on first) and `needsAlso` (its text).
- `Controllers/Hud.luau`: `Hud.exitStatus` shows "NO BACKPACK" for `nobag`.
- `Services/Doors.luau`: a door with `power` (a switch id) is an electric lock; the key does nothing until that switch is on.
- `Services/Hazards.luau`: `mineField`, `mineNear`, `detonate`, `mineStep` (run from the existing 0.5 s loop), re-armed by `reset`.
- `Services/AI.luau`: `AI.reset` honours `W.boss.chance` and picks one of `W.boss.zones`; a boss without those behaves as before.
- `shared/Items.luau`, `Services/Loot.luau`: the ten keys below, the `mallkeys` pool, the Caretaker's pockets.
- `Tests/LogicTests.luau`: 11 checks before the summary: 5 always run (the nobag rule and its hold check, the two-step power rule,
  the minefield, the ten keys), 6 when the map built (extract rules and sides, spawns by side, the boss, guard routes, mines exist).

### Keys, doors and what power changes

The shell and the stores choose the final door ids (the shell already has `MM_SHELTER` and `MM_UNIT14`); Play matches by key, so a
different id changes nothing but this table. Uses follow the reference (tarkovforge, 2026): 40 for door and register keys, 10 for the
two Object keycards. The stores agents place the key items as loose loot or in containers where `L.keys` says (map-local studs); the
`mallkeys` pool also serves the generic key spots.

| Key item | Uses | Door id expected | Opens | Power |
|---|---|---|---|---|
| KEY_MM_IRON_FRONT | 40 | MM_IRON_FRONT | IRONSIGHT front door, L1; opening it starts the alarm | yes |
| KEY_MM_IRON_GRATE | 40 | MM_IRON_GRATE | IRONSIGHT inner grate (the weapon room) | yes |
| KEY_MM_RESCUE | 40 | MM_RESCUE_N, MM_RESCUE_E, MM_RESCUE_W | RESCUE POINT, three doors, one use per opening | no |
| KEY_MEDIQ (reused, 20 -> 40 uses) | 40 | MM_MEDIQ_STORE | MEDIQ STORE ROOM, L2 | yes |
| KEY_VOLTA_STORE (reused) | 12 | MM_VOLTA_STORE | VOLTA stock room, L2 | no |
| KEY_MM_NESTA_REG, KEY_MM_KASSA_REG, KEY_MM_BOLT_REG | 40 | MM_NESTA_CASH, MM_KASSA_CASH, MM_BOLT_CASH | the till office behind each anchor's tills (a container cannot be key-locked, so the register key opens the cash office) | no |
| KEY_MM_BOLT_OFFICE, KEY_MM_BOLT_GOODS | 40 | MM_BOLT_OFFICE, MM_BOLT_GOODS | BOLTWORKS OFFICE, GOODS-IN | no |
| KEY_MM_SUBSTATION | 40 | MM_SUB_UTILITY (Outside builds it) | THE SUBSTATION utility room | no |
| CARD_MALL_VAULT ("Shelter Keycard", reused, 6 -> 10 uses) | 10 | MM_SHELTER | THE SHELTER door in CAR PARK C | yes |
| KEY_MM_UNIT14 (card) | 10 | MM_UNIT14 | UNIT 14, L0 | yes |
| KEY_MALL_SECURITY (kept) | 15 | MM_SECURITY | the security room that holds the alarm terminal | no |
| KEY_MALL_STAFF (kept) | 20 | MM_STAFF_KITCHEN | the staff door of the L2 food-court kitchen | no |

**Fate of the old keys**: KEY_MALL_SECURITY and KEY_MALL_STAFF are kept (no loot weight removed), each with the door named above.
KEY_VOLTA_STORE and KEY_MEDIQ keep their ids. Key icons for the ten new items do not exist yet (the tiles show the item colour and short
name until an art pass).

Loot: the `mallkeys` pool (Loot.luau) holds all ten new keys (weights: RESCUE 4, the three register keys 5 each, BOLT OFFICE and GOODS 3 each,
SUBSTATION 2.5, IRON FRONT and IRON GRATE 1.5 each, UNIT 14 0.8); THE CARETAKER carries KEY_MM_IRON_FRONT (15 %) and KEY_MM_UNIT14 (10 %).

**What the mall power does** (the `MALL_POWER` lever in THE SUBSTATION, existing): the lamps (hooks appended to `B.powerHooks` by
Outside and the shell), the electric locks above, the washroom valve; then, for the shelter, the valve and the keycard door. Without
power IRONSIGHT's two doors, the MEDIQ store room, the shelter door and UNIT 14 cannot be opened even with the key.

### What the shell and the stores must provide for this part

1. `B.points.SHELTER_SWITCH`: a `Vector3` or `CFrame` at standing height on the L2 washroom floor (a `CFrame`'s look vector is the way the
   cabinet faces). Without it Play uses `L.poi.WASHROOM`; with no L2 floor part there, SHELTER EXIT stays a plain power exit.
2. `B.points.SECURITY_TERMINAL`: a point inside the security room on L1 (else `L.poi.SECURITY_L1`).
3. Floor parts: every walkable L1 and L2 surface as an anchored, collidable, opaque part wider than 2 studs both ways and under 6
   thick whose top is within 0.7 studs of 17.81 (L1) or 47.50 (L2). Play's L1 and L2 routes, scav zones, boss zones, the terminal and the
   valve are placed only on such parts. The L0 floor must match `L.mall.levels[1].floor` with slab tops at y 0 (SHELTER EXIT and WEST CAMP
   stand there; MapTests M03 needs an upward surface under them).
4. Doors registered through the usual door call so they sit in `W.doors` with `key = "<item id>"`; do not set `power` yourselves (Play
   does, by key), and do not register `SHELTER_SWITCH` or `MM_ALARM` (Play does).
5. Anything that follows the power appends a `function(on)` to `B.powerHooks` and applies the off state itself when built.

### Dress (`Dress.luau`)

Cars, trolleys, barriers, cones, bins, sandbags and clutter, capped at 2,300 parts (a kit prop counts its pieces and colliders; a
warning is printed above 2,500); every piece is tested against `B.geo`, so nothing but wrecks stands on a road and nothing blocks a
spawn, an extract, a route, a post, a zone, a door, a container or loose loot. Sections (each under `pcall`): **lots** (cars in about one
bay in eight on WEST LOT 2 to 6, in the bay frame Ground paints), **garages** (cars on the L0 floor: CAR PARK A to D 8, 7, 8 and 7, the
NESTA, KASSA and BOLTWORKS garages 3, 4 and 3), **wrecks** (cars on the road shoulders, at most 40, three in five as cover wrecks),
**furniture** (trolley rows and tipped trolleys, boom barriers with cones at lot entrances, bins, up to 14 street lamps), **camps**
(sandbags, tyres, drums, a broken barrier at the camps, the checkpoint, the substation gate, the kart pit), **docks** (pallets, boxes,
roll cages, jerry cans, dumpsters, vans, forklifts on the aprons and yards, up to 20 shipping containers in the cargo yards), **nature**
(bushes, grass and rocks inside the boundary, at most 160). Cars use the Blender kit (sedan, hatch, smashed sedan); 28 % are burnt (dark
tint) and an item lies beside 40 % of them (at most 26 loose spots). There is no cone prop in the kit, so a cone is two plain parts.
Budget check: Ground 2,492 + Outside 1,022 (the mock's counts) + Dress at most 2,300 stays under the 6,000 of the spec; the real count is
printed as `[ZR] Meridian dress: ... parts`.

### Parity gaps from this part (copied to `docs/design/EFT_PARITY.md`)

- **Second boss: built 2026-11-02** as THE STOKER, our Tagilla (`docs/design/BOSS_STOKER.md`). He is rolled at 35 %, on his own beside THE
  CARETAKER's 60 %, and walks a six-point route in the KASSA GARAGE from the reference's hammer marker (L0 756, -431). The gaps are in
  `EFT_PARITY.md`.
- **Airdrops: built 2026-11-02** (`docs/design/AIRDROPS.md`): 20 %, 6 or more alive, 5 to 15 minutes in. Meridian has 80 drop
  points, found as open level ground; Tarkov uses fixed zones.
- **Co-op and transit extracts**: WEST CAMP is scav-only at the co-op spot, and the two transits (Streets, Customs) do not exist.
  RIVER PATH opens by green flare since 2026-11-02.
- **SUBSTATION CAR** is a vehicle exit (20,000 MK, the 2026 figure; 50 % chance, pay at the car, 4 seats, shared 60 s countdown, stay inside
  the zone, single use). Still a gap: the price does not depend on Scav karma and the ride gives no karma; the 60 s countdown is grade C
  (from memory, to confirm).
- **SHELTER EXIT is simplified**: mall power, then a hidden valve in the L2 washroom (for the urinal flush that reveals a keypad), then the
  keycard door, then the exit. Not copied: the keypad, the padlocked door with its inside button, the lever that opens Object-14, and
  the Terragroup container with the Object #21WS keycard in the south-west container yard.
- **Extract timers**: done 2026-11-02: each exit has its own (8 s standard, SHELTER EXIT 3 s, FENCE GAP 10 s, the car 60 s shared).
- **FENCE GAP** is built as a grade D optional extract (its 2026 status is uncertain in the sources).
- **Mines and snipers**: what the bands do is in no source (the reference calls the west band a minefield and the east band "a deadly
  sniper"); the 3.4-stud trigger, the blast and the 400-damage wound, and the sniper strips, are ours.
- **IRONSIGHT alarm**: no siren sound (the audio atlas has none); the beacon, the terminal's place and the 60 s length are ours; the
  reference gives only "about 3 s after the door opens" and "a terminal in the first-floor security room".
- **Register keys** open the till offices, not the registers (a container cannot be key-locked here).
- **THE CARETAKER**: Killa's routes, aggro and regeneration are in no source, so the zone routes and the existing Caretaker AI and kit
  stand in for them. His spawn zones and 60 % are the reference's.
- **Mounted guns and propane cylinders**: no source places any on Interchange, so none stand on Meridian.
- **Spawns**: points the reference puts on the mall's terraces are moved to the ground; the 2026 sources call both corner exits neutral,
  the build follows SPT (RAIL SIDING to MallSE, RESCUE CHECKPOINT to MallNW).
- **Key art**: the ten new keys have no icon or model yet.

### Unverified (part 3; nothing has run)

Everything in `Play.luau` and `Dress.luau`, and the 11 new `LogicTests` checks and MapTests M01 to M05 for this map (written to hold,
not run). In particular: the one-off scan of the map model for the solid-part index (time at server start with about 24,000 parts); that
the shell's floor parts satisfy the floor test, which decides whether the L1 and L2 routes, the boss zones, the valve and the terminal
exist; the valve's and terminal's fit in their rooms; the alarm's timing and what `AI.hearShot` does to the guards; the electric-lock
messages; the mines' blast and wound on a real character and whether the sniper strips follow the band; the boss's walk along the
upper corridors; the kit prop names in `ZR_Assets` (a missing one is skipped without a warning, so the cars could be fewer); the real
part and light counts; frame rate on a low-end phone.

### Files (part 3)

| File | What |
|---|---|
| `src/server/Maps/Meridian/Play.luau` | extracts, valve, electric locks, alarm, spawns, routes and posts, scav zones, the Caretaker, visit zones, snipers, mines, loose loot, `B.geo` |
| `src/server/Maps/Meridian/Dress.luau` | cars, trolleys, barriers, cones, bins, lamps, camps, docks, nature |
| `src/server/Services/Extract.luau`, `Doors.luau`, `Hazards.luau`, `AI.luau`, `src/client/Controllers/Hud.luau` | the `nobag` and two-step power rules, electric locks, mines, per-zone boss |
| `src/shared/Items.luau`, `src/server/Services/Loot.luau` | ten key items, key pool, the Caretaker's pockets |
| `src/server/Tests/LogicTests.luau` | the Meridian rules group |

## Part 4a: main floor stores (the three anchors, the canteen, IRONSIGHT, RESCUE POINT and 29 more units)

Every unit of L1 is furnished: the 35 of `Layout` (NESTA, KASSA, BOLTWORKS, the NESTA CANTEEN, IRONSIGHT, RESCUE POINT and 29 shops) and our
`BACK_1` to `BACK_4` and `SECURITY_ROOM`. The upper floor is Part 4b (`StoresL2.luau`, another agent). **Nothing here has run in Luau or
Studio**; the only run was an offline mock (see "Checked offline").

### What is built

`Stores.luau` makes sure `B.points` and `B.powerHooks` exist and runs `StoresL1` and `StoresL2`, each under `pcall` (a failing floor is
logged, the other still builds). `StoresL1` builds, every unit under its own `pcall`: the 29 shops and their stock rooms, IRONSIGHT, RESCUE
POINT, the security room, then `StoresL1Halls` (the three anchors), `StoresL1Back` (the canteen and `BACK_1` to `BACK_4`), and last the key
tiles. It prints `[ZR] Meridian stores L1: ...` (props, parts, containers, loose spots, doors, lamps) and the container kinds, and sets
`B.count.storesL1` and `B.count.storesL1Props`. All of it is built with `StoresL1Kit`:

- **Frames.** Each unit (and each stock room) gets a frame in its own coordinates (x to the right when facing out through the front, d the
  depth from the front wall). A prop is placed by its footprint (`KitMeta`) against a list of occupied rectangles. The shell's columns, the
  door swings, the other L1 units inside it and the floor in front of every opening (9 studs deep) are reserved first, so nothing stands in
  an entrance, the walkways between props are at least 6 studs wide (checked, see below) and nothing goes through a shell wall. Props stand on
  the floor at `u.floorY`. Long runs (wall shelves, gondolas, racks, checkout banks) are one kit prop scaled along its length.
- **Parts.** Kit props (instanced Blender meshes plus invisible `KitCollider` boxes) wherever the kit has a prop. Plain parts only for the
  cheap aisle shelving of KASSA and BOLTWORKS (a body and two colour bands), room walls, the grilles and the IRONSIGHT grate, and the lamps.
- **Shops (29).** One recipe per kind (clothing, electronics, sports, books, toys, shoes, homeware, lighting, travel, general, food): wall
  shelving, island rows across the floor, a cash desk (a register container half the time), a few props at the front, one or two loose spots
  on the counters and the floor, and a lamp per 70 studs. A prop cap by floor area (area / 360, from 5 to 20) keeps the budget. 24 of
  the 29 shops have a stock room: racks, a lamp and, if it is at least 40 wide, a container (four narrow ones have none). The unlabelled store north
  of VIKING is closed: its sign reads `TO LET`, with toppled gondolas, cartons, pallets and an old toolbox.
- **NESTA** (`L1_idea`): 21 checkout stations in three ranks on the shell's lanes (20 register containers), the locked till office
  `MM_NESTA_CASH` (two safes, drawers, a desk PC), a furniture showroom (four rows of living, bedroom, dining, work and lounge stations with
  chests of drawers, wardrobes and coat racks), wall shelving, a kiosk, an ATM and a vending machine, and the warehouse across the back
  (two rows of pallet racks, pallets, crates, forklifts, roll cages, a toolbox and a locked crate).
- **KASSA** (`L1_goshan`): 27 checkout stations in four ranks (26 register containers), the till office `MM_KASSA_CASH`, a hypermarket in
  three blocks of aisles (cheap coloured shelving, every fifth row a run of scaled gondolas, grocery shelves and fridge containers), a fridge
  wall and wall shelving.
- **BOLTWORKS** (`L1_oli`): 18 checkouts (18 registers), the till office `MM_BOLT_CASH`, hardware and car-parts aisles in blocks (cheap
  shelving, every fourth row scaled tool shelving), toolboxes, tool chests, tyre stacks, and the goods-in docks along the back wall.
- **IRONSIGHT** (`L1_kiba`): the steel front door `MM_IRON_FRONT` in a narrowed opening (leaf, fixed grille panels, header), a sales area
  with counters, a register, display tables and a range display, then the inner grate across the shop 11.6 studs in with the gate
  `MM_IRON_GRATE`, and behind it the weapon room: four weapon boxes (one in its stock room), a safe, a clerk's drawer, two gun benches and
  guns on the walls (scenery). Loose weapon boxes lie on the benches. Its lamps are in the sales area and the weapon room.
- **RESCUE POINT** (`L1_emercom`): three keyed doors (`MM_RESCUE_N`, `_E`, `_W`; the west one is in the stock room's wall), four medicine
  shelf containers (`pharmacy`), medbags, a nurse's drawer, a safe, cots, first-aid props, a counter with a register, loose medical items.
- **NESTA CANTEEN** (`L1_idea_bistro`, open plan): a kitchen along the back (fridges, three coolers, a pantry of grocery shelves, staff locker,
  drawer, crates), a serving line in two halves with a till at each end and menu boards, about 15 tables with chairs, planters, benches, bins,
  vending machines, an ATM and a kiosk, 12 pendant lamps on cables (the hall is 49.7 high).
- **Back-of-house** (our units): `BACK_1` NESTA STOCK ROOMS (pallet racks, crates, lockers, a forklift, roll cages); `BACK_2` KASSA BACK OF
  HOUSE (a cold room of fridges and coolers, dry-goods racks, grocery shelves, lockers); `BACK_3` BOLTWORKS STOCK BLOCK (the locked goods-in
  room `MM_BOLT_GOODS`, racks, tyres, drums, tool chests); `BACK_4` BOLTWORKS OFFICES (the locked manager's office `MM_BOLT_OFFICE` with two
  safes, drawers and a PC, six desks with chairs and PCs, pigeonholes, boards, lockers, a meeting table); `SECURITY_ROOM` (lockers, a safe,
  a bench; Play puts the alarm terminal there).
- **Lights.** 109 lamps (a plain housing, `Enabled = false`, dead grey until power), none with shadows, range 40, on cables in the tall halls,
  every one in a single `B.powerHooks` function that turns it Neon FFE2B0 and lights it when `MALL_POWER` is on.
- **Loose loot.** 238 spots, each snapped to a surface by `World` (a floating one is dropped): counters and desks (`surfaces`), the floor
  beside props (`litter`), the stock and warehouse floors. Pools by kind (mall, grocery, tech, office, toolbox, junk, crate, medbag,
  weaponbox, drinks) and `mallkeys` for keys.
- **Key tiles.** The reference marks key spawn tiles for the three register keys (`L.keys`): NESTA (162.5, -753.1, on the canteen's east
  glass wall), KASSA (509.4, -56.2) and the three BOLTWORKS keys at (12.5, 500) in the offices. `World` can only roll a pool at a loose spot,
  so each tile is a `mallkeys` spot (chance 0.35) on the nearest free floor of the furnished unit within 9 studs: NESTA (157.3, -753) in the
  canteen, KASSA at its tile, three BOLTWORKS spots side by side in `BACK_4`. The other L1 entries of `L.keys` (IRONSIGHT front and grate,
  RESCUE POINT, the security key) are door or terminal icons, not key spawns: those keys come only from 16 generic `mallkeys` spots (chance
  0.08 to 0.15: office desks, back-room corners, IRONSIGHT, the RESCUE POINT stock room, the security room); 3.35 key rolls a raid on L1 in all.

### The units (L1, 40)

Reference name is the reference's own store (from its record id; its plan labels are blank for most). Containers are the sales area, plus
the stock room after the plus sign. Props are kit props. Counts are the offline mock's.

| Reference id | Reference name | Our name | Kind | Containers | Loose | Props | Lamps |
|---|---|---|---|---|---|---|---|
| `L1_idea` | IDEA | NESTA | anchor | 36 | 21 | 159 | 3 |
| `L1_goshan` | Goshan | KASSA | anchor | 45 | 26 | 111 | 3 |
| `L1_oli` | OLI | BOLTWORKS | anchor | 33 | 30 | 112 | 3 |
| `L1_idea_bistro` | IDEA Bistro | NESTA CANTEEN | food | 9 | 12 | 58 | 12 |
| `L1_kiba` | Kiba Arms Outlet | IRONSIGHT | locked store | 6 + 1 | 6 | 22 | 4 |
| `L1_emercom` | EMERCOM | RESCUE POINT | locked store | 9 + 1 | 4 | 11 | 2 |
| `BACK_1` | (ours) | NESTA STOCK ROOMS | stock | 7 | 7 | 29 | 4 |
| `BACK_2` | (ours) | KASSA BACK OF HOUSE | stock | 10 | 5 | 34 | 4 |
| `BACK_3` | (ours) | BOLTWORKS STOCK BLOCK | stock | 10 | 11 | 36 | 4 |
| `BACK_4` | (ours) | BOLTWORKS OFFICES | stock | 13 | 14 | 30 | 3 |
| `SECURITY_ROOM` | (ours) | SECURITY | security | 3 | 3 | 2 | 1 |
| `L1_adik` | Adik | SPRINTLINE | sports | 1 + 1 | 4 | 13 | 2 |
| `L1_avokado` | Avokado | GREENPLATE | food | 2 + 1 | 5 | 13 | 3 |
| `L1_bizarro` | Bizarro | MOTLEY | clothing | 1 | 2 | 4 | 2 |
| `L1_book_store` | Book Store | INKWELL | books | 2 + 1 | 6 | 24 | 3 |
| `L1_boots_4_life` | Boots 4 Life | SOLE TRADE | shoes | 1 | 2 | 8 | 2 |
| `L1_brutal` | Brutal | IRONSTITCH | clothing | 2 + 1 | 4 | 13 | 2 |
| `L1_dino_clothes` | Dino Clothes | PIPKINS | clothing | 2 | 3 | 15 | 3 |
| `L1_dom` | Dom | HOMESTEAD | homeware | 3 + 1 | 5 | 23 | 3 |
| `L1_generic` | Generic | VARIETY | general | 1 + 1 | 3 | 8 | 2 |
| `L1_german` | German | CORNER MART | general | 2 | 2 | 5 | 1 |
| `L1_kostin` | Kostin | TAILORED | clothing | 2 + 1 | 3 | 9 | 2 |
| `L1_mantis` | Mantis | MICROMART | electronics | 1 + 1 | 5 | 14 | 2 |
| `L1_mode7` | Mode 7 | ATELIER 9 | clothing | 2 + 1 | 3 | 10 | 2 |
| `L1_nortex` | Nortex | WOOLHOUSE | clothing | 1 | 2 | 7 | 2 |
| `L1_pretty_lights` | Pretty Lights | BRIGHTSIDE | lighting | 1 + 1 | 3 | 9 | 2 |
| `L1_rasmussen` | Rasmussen | GADGETRY | electronics | 2 | 2 | 7 | 2 |
| `L1_revis` | Revis | DAILY NEEDS | general | 2 + 1 | 3 | 11 | 3 |
| `L1_spiel` | Spiel | TOYBOX | toys | 2 | 2 | 5 | 1 |
| `L1_sports` | Sports | FIELD & TRACK | sports | 2 + 1 | 3 | 9 | 3 |
| `L1_telespot` | Telespot | PIXELPOINT | electronics | 1 | 2 | 6 | 1 |
| `L1_texho` | Texho | PLUGGED IN | electronics | 2 + 1 | 3 | 8 | 3 |
| `L1_the_national` | The National | HARTWELL | clothing | 2 + 1 | 5 | 23 | 3 |
| `L1_top_brand` | Top Brand | HIGHLINE | clothing | 1 + 1 | 5 | 13 | 2 |
| `L1_trend` | Trend | CUTLINE | clothing | 2 + 1 | 3 | 9 | 3 |
| `L1_tts` | TTS | BYTEBAY | electronics | 1 + 1 | 3 | 10 | 2 |
| `L1_unlabelled_store_n_of_viking` | (unlabelled, north of Viking) | TO LET | unlabelled | 2 + 1 | 5 | 20 | 3 |
| `L1_viking` | Viking | PEAKFORM | sports | 1 + 1 | 5 | 22 | 3 |
| `L1_voyage` | Voyage | WAYFARE | travel | 1 | 3 | 7 | 2 |
| `L1_yushka` | Yushka | SABLE | clothing | 1 + 1 | 3 | 10 | 2 |
| **40 units** | | | | **249** | **238** | **939** | **109** |

### Doors and keys (10 doors)

Each door is in `W.doors` with its key item id in `key`; `Play` matches them by that id and marks the two IRONSIGHT doors electric (dead
without power). Positions are map-local studs. None has an `openChance`: all are locked until the key is used.

| Door | Key | At | Size | What |
|---|---|---|---|---|
| `MM_IRON_FRONT` | `KEY_MM_IRON_FRONT` | (291, -75) | 7.2 x 9 | IRONSIGHT front: a leaf in the 13.5 high opening, fixed grille panels beside it and a header; Play's alarm rings 3 s after it opens |
| `MM_IRON_GRATE` | `KEY_MM_IRON_GRATE` | (303, -80) | 6 x 9.4 | the gate in the inner grate (a see-through steel grate across the shop) to the weapon room |
| `MM_RESCUE_N`, `_E`, `_W` | `KEY_MM_RESCUE` | (184, -321), (224, -306), (154, -317) | 7.4, 6.5, 4.2 x 9 | the three doors of RESCUE POINT (the west one in its stock room's wall); the key's uses are shared |
| `MM_NESTA_CASH` | `KEY_MM_NESTA_REG` | (318, -559) | 5.2 x 8.6 | NESTA till office: two safes, drawers, a desk PC |
| `MM_KASSA_CASH` | `KEY_MM_KASSA_REG` | (521, -244) | 5.2 x 8.6 | KASSA till office, the same fit |
| `MM_BOLT_CASH` | `KEY_MM_BOLT_REG` | (410, 290) | 5.2 x 8.6 | BOLTWORKS till office, the same fit |
| `MM_BOLT_OFFICE` | `KEY_MM_BOLT_OFFICE` | (-14, 553) | 5.2 x 8.6 | the manager's office in `BACK_4`: two safes, three filing drawers, a PC, a locker |
| `MM_BOLT_GOODS` | `KEY_MM_BOLT_GOODS` | (553, 529) | 5.2 x 8.6 | the goods-in office in `BACK_3`: two pallets, a safe, two tool chests, a PC |

The offices are walled rooms (11.5 high, door on the side facing the hall, a lamp inside) placed on the first free spot of a short list per
unit, so a layout change can move them; the door ids and keys stay.

### Containers and loot

Only the container kinds and pools that `Loot.luau` already has. 249 containers on L1, ids `MM_L1_<unit>_C<n>` (a stock room adds `_stock`):
register 81 (64 on the checkouts of the three anchors: 20, 26 and 18; 17 on shop counters, the canteen and IRONSIGHT), toolbox 25, drawer 25,
locker 23, crate 20, techbox 16, jacket 12, safe 12, grocery 11, cooler 10, weaponbox 6, pharmacy 4, medbag 4. Per place: NESTA 36, KASSA 45,
BOLTWORKS 33, canteen 9, IRONSIGHT 7, RESCUE POINT 10, the four back blocks 40, the security room 3, the 29 shops 66. A container is
anchored on a kit prop's collider (a shelf, a counter, a locker, a desk), which `World` names `Loot_<id>`, so its prompt sits on the
prop; a long scaled run is one prompt at its centre. 238 loose spots on L1, about 97 items a raid (the sum of the chances): mall 64, grocery 38, office 27, toolbox 27,
junk 23, `mallkeys` 21, tech 18, crate 10, weaponbox 5, medbag 3, drinks 2. These are above the brief's marks (about 150 containers and
200 loose spots): 64 registers are fixed by the three anchors' checkouts, and the rest is the shops' own counters and corners.

### Counts and budget (the offline mock's, not the engine's)

| | L1 stores | Budget |
|---|---|---|
| kit props | 939 (2,774 mesh pieces, 905 colliders by the module's tally) | 1,100 |
| all parts (the mock's export) | 4,611: 932 own (41 are container anchors), 2,982 kit pieces (208 are container anchors), 697 colliders | 5,000 |
| own parts (the module's tally) | 784 | |
| containers, loose spots, doors | 249, 238, 10 | about 150, about 200 |
| lamps | 109, none shadowed, all in one `B.powerHooks` function | the map's 400 (40 shadowed): the shell 149 and Outside 13 make 162; with `StoresL2`'s 60 (its mock run) the map holds 331 |
| build time | 0.14 s in the mock (the kit's real mesh placement is slower) | |

The module's own tally leaves out the walls of the offices and a few container stand-ins (about 150 parts); the export's total is the figure
to hold against the budget. The cheap aisle shelving is the bulk of the own parts (KASSA and BOLTWORKS: 314 runs of three parts).

### Checked offline

A throwaway harness (a translator from this Luau to Lua 5.4 and a mock of parts, CFrames, the kit, `World` and `Random`; it lives in the
session's scratchpad, not in the repo) ran the shell and then `Stores` with `StoresL1`, the kit, Halls and Back, in a strict environment
where an undefined global is an error. Results of the last run: no error and no warning; 0 spots refused; every door and key as in the table
above; none of the 1,680 collidable parts of the stores more than 0.25 studs inside a shell wall; the 115 openings of the L1 units are clear
(only the grilles of IRONSIGHT's and RESCUE POINT's own doors stand in them); in the three anchors, the canteen and the four back blocks the
largest connected region of floor with a 6 stud wide walkway holds NESTA 91 %, KASSA 89 %, BOLTWORKS 73 %, the canteen 100 % and the back
blocks 98 to 100 % of all such floor (what is cut off is the rooms behind the 5.2 wide office doors and short pockets between props), and
every entrance of those units reaches it except NESTA's north service opening (578, -934) and KASSA's north entrance (691, -531), which open
onto a 6 stud strip of the shell itself. The small shops were checked only for walls and openings. `python3 tools/luau_check.py src` passes
(136 files; a structure check only).

### For the main session and Part 4b

1. The key tiles are in `KEYTILES` in `StoresL1.luau` as `{ key id, pool }`. With a pool that holds only that key (a `Loot.POOLS` entry per
   key, for instance `key_nesta_reg = { { id = "KEY_MM_NESTA_REG", w = 1 } }`) the exact key lies on its tile: change the pool name there.
2. A shop's prop cap is `cap` in its `SHOPS` entry in `StoresL1.luau` and its look is its recipe in `RECIPES`; the anchors' and the back
   blocks' layouts are coordinates in `StoresL1Halls.luau` and `StoresL1Back.luau`.
3. The frame toolkit (`StoresL1Kit.luau`) takes any unit of `B.units`, so a later pass can furnish more with `T.frame(u)`; it reads
   `B.points.SECURITY_TERMINAL` (Play's) to keep the terminal's floor free, and nothing else outside the shell's `B`.
4. No file outside `src/server/Maps/Meridian/` and this document was edited.

### Parity gaps from this part (copied to `docs/design/EFT_PARITY.md`)

- **Shop interiors are recipes, not copies.** Which shelf, counter and rack stands where in each of the reference's shops is in no source,
  so a shop is built from its kind, with about ten props (capped by floor area) rather than a shop's worth, to hold 30 fps on a phone.
  The 29 names, the signs and the sizes are the reference's; the fixtures are ours.
- **Containers are the existing kinds only.** There are no ammo box, grenade box, duffel bag or PC case kinds, so IRONSIGHT has weapon boxes,
  a safe, a drawer and a register (no ammo boxes, no grenade box, no armoured mannequins; the guns on its walls are scenery), and the
  clothing shops' mannequins carry nothing. Container counts per shop are ours (249 on L1, 81 of them registers).
- **RESCUE POINT** is medicine shelves, medbags, a drawer and a safe, with the three keyed doors; the reference's surgical and stimulant
  containers are not separate kinds.
- **Key spawns are pool rolls.** A loose spot can only roll a pool, so the five key tiles (NESTA, KASSA and the three BOLTWORKS keys) each
  roll the whole mall key pool (any `KEY_MM_*` or older mall key) instead of holding their one key. The IRONSIGHT, RESCUE POINT and security
  keys have no tile of their own (their `L.keys` positions are door and terminal icons) and come only from 16 low-chance spots; a key's
  chance is its pool weight, not the reference's per-key rate (about 3.35 key rolls a raid on L1).
- **Register keys open the till offices, not the registers** (already listed in Part 3; the registers themselves are open containers).
- **The closed unit** north of VIKING reads `TO LET` on its sign; the reference's unlabelled store has no sign.
- **The NESTA CANTEEN kitchen has no staff door** (it is open plan; `KEY_MALL_STAFF` opens the L2 food-court kitchen only).
- **Not built on L1:** loot or props in the concourse, the atria and the halls outside the shops, shop shutters and glass doors, shop-window
  displays, price tags, posters and signage art (no logos by design), and any sound.
- **Loot density** per container and per loose spot comes from the shared pools, with no per-spot tuning against the reference.

### Unverified (part 4a; nothing has run in Luau or Studio)

Everything above: that the modules load and build in the engine at all (the mock stands in for the kit, `World` and the part classes); the
real part and light counts and the build time at server start; each kit prop's facing and scale in the scene (the yaw conventions come
from the Border and Living maps and a front line of `KitMeta`, not from a look at the result); the collider boxes under scaled runs
and their prompts' reach; that the loose spots land on the surfaces meant (the world drops any it cannot snap); the look and brightness of
the lamps lit at power-on, the grate's transparency and the doors' swing and fit in their openings; the key tiles' places; and frame rate
and memory on a low-end phone.

### Files (part 4a)

| File | What |
|---|---|
| `src/server/Maps/Meridian/Stores.luau` | the dispatcher: `StoresL1` and `StoresL2`, each under `pcall` |
| `src/server/Maps/Meridian/StoresL1.luau` | the shops and stock rooms, IRONSIGHT, RESCUE POINT, the security room, the key tiles, the totals line |
| `src/server/Maps/Meridian/StoresL1Kit.luau` | the frame toolkit: placement by footprint, containers, loose spots, doors, offices, lamps |
| `src/server/Maps/Meridian/StoresL1Halls.luau` | NESTA, KASSA, BOLTWORKS |
| `src/server/Maps/Meridian/StoresL1Back.luau` | the NESTA CANTEEN, `BACK_1` to `BACK_4` |

## Part 4b: upper floor stores and the car-park rooms

`src/server/Maps/Meridian/StoresL2.luau` is the second half of the stores (`Stores.luau` runs it after `StoresL1`, each under its own
`pcall`). It furnishes the 31 L2 units the shell fitted, the stock rooms behind them, and the insides of THE SHELTER and UNIT 14 on L0 (their
walls, doors and cards are the shell's and Play's). Researched first (`docs/maps/reference/INTERCHANGE_REFERENCE.md` sections 4.4, 8.1,
8.2, 8.4 and 8.5: what each L2 unit sells, the ULTRA medical storage, the saferoom's and Object-14's contents, TECHLIGHT as the best tech
store, the SPT container groups), then built. Status: written and passed through `tools/luau_check.py`; the placement also ran in an offline
plain-Lua mock against the real shell and was checked there (see "Checked offline"). Nothing has run in Luau, Studio, on a phone or on a
console, and no frame rate was measured.

### What is built

Numbers are the mock's (a kit prop counts its pieces and colliders from `KitMeta`, as the budget does). Where two totals are shown the mock
gave either: `L2_shiccos` has an entrance on both long walls and the shell's choice of its front varied between runs (see "Known quirks");
every other number was the same in every run:

| | Count |
|---|---|
| Rooms | 58: 31 sales floors (30 shops and the MEDIQ STORE ROOM), 25 stock rooms behind them, THE SHELTER, UNIT 14 |
| Kit props | 663 or 664 (budget 700): 552 or 553 on L2, 111 on L0 |
| Parts | 2,747 or 2,752 (budget 3,000): 2,543 or 2,548 kit pieces and colliders, 204 plain parts (stand-in boxes, six cargo containers, small cases, door fillers, dust sheets, lamps) |
| Containers | 148: 114 on L2 and 34 on L0 (shelter 17, UNIT 14 17) |
| Loose loot spots | 166: 129 on L2 and 37 on L0 |
| Doors | 1 new (`MM_MEDIQ_STORE`), 2 of the shell's given a key |
| Lamps | 60 (48 on L2, 12 on L0), all dead until `MALL_POWER` |

The aim was about 100 containers and about 120 loose spots: L2 alone is 114 and 129, and the two car-park rooms add 34 and 37 (that is where
the mall's best loot is meant to lie).

Containers by kind: register 22, crate 18, jacket 16, cooler 15, pharmacy 13, grocery 12, techbox 12, locker 10, medbag 8, safe 7, toolbox 6,
drawer 5, weaponbox 4. Loose spots by pool: grocery 36, mall 33, pharmacy 21, junk 20, tech 20, vault 11, office 8, mallgood 5, drinks 4,
mallkeys 4, dorm 2, dorm_good 2. Only existing container kinds and loot tables are used (`Loot.luau` is untouched). The module prints one
line (`[ZR] Meridian stores L2: ...`) with these totals and the number of placements it refused (144 or 146: a prop that did not fit its
slot, skipped, not an error); it adds to `B.count.prop`, `container`, `door` and `light`.

### How a room is furnished

Each unit gets two frames, the sales floor and the stock strip (8.8 deep), each in its own coordinates (x across the front, d the depth from
the front wall). A kit prop goes in by the centre of its footprint and is **refused** (counted, not placed) when it would overlap another
prop, a column or wall of the shell, an entrance strip (7.5 deep, 5.5 for an entrance 30 or more wide, 1.2 more either side), or the swing of
a stock door (4.5 deep and 3.6 either side on the sales side, 6.8 and 6.4 on the stock side). Props stand on `u.floorY`; the counters'
colliders are lower boxes (a prop's own bounding box would be taller than the counter) so loose items can lie on them. Loose items lie only
where a player can reach them (a surface at most 4.8 up). The code stops adding at 2,960 parts or 690 props (nothing was cut). Recipes by kind:

- **Food** (11 restaurants): shallow units (under 24 deep) serve over food counters and fridges along the back wall; deeper ones have a service
  line (counters and tills with a gap for the staff) and a kitchen behind it; seating in rows of tables in front; a till, a drinks fridge or
  vending machine, a staff locker in the larger ones; dry-store shelves in the stock room.
- **Clothing** (7), **general** (2), **pharmacies** (2), **electronics** (2), **furniture** (1), **museum** (1), **travel** (1): shelving on
  the walls, rows of racks, aisles, tables, display cases or desks by kind, a till, and what the kind sells on top; each stock room has
  shelves along the back wall, boxes in the corners and a container kind that fits the shop (spare coats, stock cabinets, packed crates,
  archive drawers).
- **PLAYFIELD** (the sports and games hall): shelves and lockers on the back wall, treadmills and weight racks in front of them, arcade
  machines along one side, racks and gondolas in rows, a till and a gym bag.
- **CLOSED FOR REFIT** and **OPENING SOON** (half-built): dust sheets over what is left, rubble, pallets and cardboard, a hoarding across the
  middle (the first); empty shelves, pallets of boxes, fitters' tools (the second). Both keep a container or two so they are worth a visit.

### The units (31)

Reference id and name are the reference's (never shown to a player); our names are original. VOLTA and MEDIQ are fixed by the spec. W x D is the
sales area in studs; Props counts kit props in both rooms; Containers is the total, with the sales floor and the stock room in brackets
where the unit has one; Loose is the loose spots in both rooms. Five restaurants (`L2_fck`, `L2_mcdaniels`, `L2_burger_house`, `L2_shiccos`,
`L2_sushi_huyushi`) and `L2_father_sons` have no stock room, as in the shell.

| Reference id | Reference name | Our name | Kind | W x D | Props | Containers | Loose |
|---|---|---|---|---|---|---|---|
| `L2_apteka` | Apteka (ULTRA Medical's pharmacy) | MEDIQ | pharmacy | 38 x 19 | 8 | 3 (2 + 1) | 3 |
| `L2_arena` | Arena | PLAYFIELD | sports | 38 x 38 | 21 | 5 (4 + 1) | 4 |
| `L2_burger_house` | Burger House | SMOKEHOUSE | food | 57 x 16 | 10 | 2 | 1 |
| `L2_burger_spot_49` | Burger Spot (#49) | STACK & SIZZLE | food | 57 x 31 | 26 | 10 (3 + 7) | 10 |
| `L2_closed_for_repairs` | Closed for repairs | CLOSED FOR REFIT | closed | 66 x 69 | 32 | 4 (3 + 1) | 6 |
| `L2_coffee_joy` | Coffee Joy | CUP & SAUCER | food | 63 x 19 | 13 | 3 (2 + 1) | 3 |
| `L2_eastland` | Eastland | LINDEN WEAR | clothing | 41 x 28 | 17 | 3 (2 + 1) | 4 |
| `L2_fashion_store` | Fashion Store | CATWALK | clothing | 79 x 19 | 19 | 3 (2 + 1) | 3 |
| `L2_father_sons` | Father & Sons | HALE & KIN | clothing | 79 x 23 | 19 | 2 | 1 |
| `L2_fck` | FCK | GOLDEN WING | food | 57 x 23 | 10 | 2 | 1 |
| `L2_figaro` | Figaro | SHEARS & CO | clothing | 85 x 31 | 27 | 2 (1 + 1) | 3 |
| `L2_furniture_mk` | Furniture MK | HEARTH & HOME | furniture | 85 x 31 | 25 | 2 (1 + 1) | 3 |
| `L2_history_museum` | History Museum | REGIONAL MUSEUM | museum | 91 x 28 | 21 | 2 (1 + 1) | 4 |
| `L2_intourist` | Intourist | HORIZON TRAVEL | travel | 38 x 19 | 9 | 2 (1 + 1) | 3 |
| `L2_jacob_jacob` | Jacob & Jacob | HOLLIS & PARK | clothing | 82 x 31 | 28 | 3 (2 + 1) | 4 |
| `L2_mcdaniels` | McDaniels | BIG BITE | food | 57 x 19 | 9 | 2 | 1 |
| `L2_na_svyazi` | Na-Svyazi | SIGNAL POINT | electronics | 38 x 38 | 14 | 2 (1 + 1) | 3 |
| `L2_opening_soon` | Opening soon | OPENING SOON | closed | 44 x 25 | 10 | 3 (2 + 1) | 4 |
| `L2_papillon` | Papillon | VELVET MOTH | clothing | 110 x 19 | 26 | 3 (2 + 1) | 3 |
| `L2_philly_cute` | Philly Cute | COPPER PAN | food | 44 x 75 | 19 | 4 (3 + 1) | 6 |
| `L2_pushkin` | Pushkin | SILVER FORK | food | 73 x 38 | 23 | 5 (4 + 1) | 6 |
| `L2_sara` | SARA | EVERYDAY STORE | general | 35 x 19 | 8 | 3 (2 + 1) | 2 |
| `L2_shiccos` | Shiccos | OLIVE & SALT | food | 57 x 19 | 8 or 9 | 2 | 1 |
| `L2_sushi_huyushi` | Sushi Huyushi | TIDE SUSHI | food | 57 x 16 | 8 | 2 | 1 |
| `L2_tarducks` | Tarducks | DAWN ROAST | food | 57 x 19 | 10 | 3 (2 + 1) | 3 |
| `L2_tarkovstar` | Tarkovstar | ALDER GENERAL | general | 38 x 22 | 9 | 3 (2 + 1) | 3 |
| `L2_tarzdrav` | Tarzdrav | WELLSPRING | pharmacy | 94 x 31 | 42 | 4 (3 + 1) | 3 |
| `L2_techlight` | Techlight | VOLTA | electronics | 116 x 19 | 30 | 13 (4 + 9) | 15 |
| `L2_ultra_med_locked_room` | ULTRA med (locked room) | MEDIQ STORE ROOM | locked store | 32 x 19 | 8 | 9 (8 + 1) | 15 |
| `L2_underway` | Underway | CROSSTOWN DELI | food | 76 x 38 | 29 | 5 (4 + 1) | 6 |
| `L2_urban_clothes` | Urban Clothes | METRO WEAR | clothing | 41 x 25 | 14 | 3 (2 + 1) | 4 |

**THE SHELTER** (`L0_saferoom_exfil_room`, 134 x 89 since 2026-11-02; 65 kit props): the hidden saferoom. The room was the
whole 216 x 201 block the reference draws solid, which left a near-empty hall around the exit; it is now a bunker around the
exit icon, and the rest of the block stays solid. Entry wall: two benches, a cork board and a whiteboard, gun racks and a bench
carrying two weapon cases. Back wall: armour and rig stands, five lockers (3 locker containers), the supply racks (2 rack
containers), two water tanks, pallets of boxes, drums and jerry cans. Left wall: the kitchen (a ration fridge and a galley
counter), a couch with valuables, an electric cabinet, a fuse box and the generator with its toolbox. Middle: six mess tables
with 12 chairs, the infirmary by the front wall (three shelves, three cots, two med cases), a briefing table and two rows of
four bunks with two jackets between them. The exit zone keeps 24 studs clear around it.

**UNIT 14** (`L0_object_14_container_room`, 91 x 69; 24 props, 17 containers, 18 loose spots, 3 lamps): the best loot of the mall. Six
walk-in shipping containers in two rows (the kit has no container prop, so each is nine plain parts: roof, two sides, back, four posts and a
header; open at one end), each holding two of: a safe, a sealed crate, a weapon case, a server case, a medical case, a toolbox; five pallet
racks along the back wall (three are containers), a forklift, pallets of boxes, roll cages, drums, tool chests (one is a container), a work
light, and a dispatch drawer. 4 safes, 6 crates, 2 weapon cases, a tech case, a med case, 2 toolboxes and a drawer in all. The card door's
swing stays free.

### Doors and keys

| Door | Key | Opens |
|---|---|---|
| `MM_MEDIQ_STORE` (new) | `KEY_MEDIQ` | the MEDIQ STORE ROOM (`L2_ultra_med_locked_room`). The shell left the unit open; the widest entrance is closed by two wall fillers and a lintel round a 5.2 x 8.6 leaf that opens inward. Play puts the power lock on it (its electric-lock pass takes every keyed door of `KEY_MEDIQ`) |
| `MM_L2_techlight_STOCK` (the shell's, keyed here) | `KEY_VOLTA_STORE` | VOLTA's stock room |
| `MM_L2_burger_spot_49_STOCK` (the shell's, keyed here) | `KEY_MALL_STAFF` | the staff kitchen behind STACK & SIZZLE (the reference's Burger Spot #49) |
| `MM_SHELTER`, `MM_UNIT14` (the shell's) | `CARD_MALL_VAULT`, `KEY_MM_UNIT14` | unchanged; the room behind each keeps the swing and the way in free |

Part 3 expected the ids `MM_VOLTA_STORE` and `MM_STAFF_KITCHEN`; the shell already had a stock door in each unit, so those two were keyed
instead of adding a second door. Play matches doors by key, so nothing else changes (read the two ids in Part 3's table as the ids above).
The other 22 stock-room doors stay as the shell made them (unkeyed, open about 40 % of the time).

Where the keys lie: the reference's key tiles are loose spots of the `mallkeys` pool (`KEY_MALL_STAFF` at (309.4, -287.5) and the shelter card
at (359.4, -287.5) on the counters of STACK & SIZZLE, `KEY_VOLTA_STORE` at (-36.6, 183.8) on VOLTA's sales floor). `KEY_MEDIQ`'s tile (32.2,
58.8) lies inside the room it opens, so its spot is on MEDIQ's till in the pharmacy instead. A loose spot rolls from its pool, so the item that
appears is any key of `mallkeys`, not the one the tile names. Part 4a's remedy applies here too: a `Loot.POOLS` entry holding only that key,
named in the `mallkeys` spots of the STACK & SIZZLE, MEDIQ and VOLTA entries of `PLAN` in `StoresL2.luau`, would put the exact key on its tile.

### What the rooms hold

- **STACK & SIZZLE's kitchen** (7 containers, 5 loose spots): a kitchen fridge, a dry store, a kitchen till, two staff lockers, the
  manager's safe, a first-aid case; the aisle stays 3.4 wide or more.
- **The MEDIQ STORE ROOM** (9 containers, 15 loose spots; the best medical loot of L2): racks and shelves of medicines (6 pharmacy
  containers: 5 in the room, 1 in the strip behind it), two med cases and a narcotics safe, `pharmacy` pool spots on the floor and the shelves.
- **VOLTA's stock room** (9 containers, 10 loose spots): racks of graphics cards, server cases and cable crates (6 tech boxes, a packing
  crate), a stock safe and a fitter's toolbox, `tech` pool spots (graphics cards are in that pool).
- Registers (22) are the tills of the shops, the fridges and vending machines (cooler 15) hold drinks, the coat racks and spare coats (jacket
  16) hold clothes, the pharmacy shelves (pharmacy 13) medicines.

### Lights

Sixty flat fixtures (2.6 x 0.35 x 0.9, under the ceiling) with a `PointLight` each (range 24 to 50, no shadows), dead until the mall power
is on: one `B.powerHooks` function switches all of them (neon material and a warm colour when on). A lamp is placed only where no lamp of
the shell or of ours reaches 80 % of its range, on a grid of 44 studs (72 in the shelter, 46 in UNIT 14), so most shops get one to three and
the stock rooms of the small shops none (the lamps of the shop beside them reach in).

### Known quirks (part 4b)

- The MEDIQ STORE ROOM's own stock strip (32 x 8.8) holds one medicine shelf and a pallet of boxes: the stock door's swing zone (6.8 deep,
  6.4 either side) takes most of it and the rack slots next to it were refused. The room in front carries the loot.
- `L2_shiccos` (OLIVE & SALT) has a shop entrance on both long walls, and which one the shell makes its front changed from one run of the
  mock to the next (the unit's `cframe` faces north or south). The module builds from `u.cframe` and `u.entrances`, so either works; the
  room has 8 or 9 props and the totals above move by one prop (3 to 5 parts). Both outcomes passed the same checks.
- Three planters (HISTORY MUSEUM, WELLSPRING, VOLTA) have a collider reaching 0.3 below the floor (the kit's own data); it sinks into the slab.
- The shelter's right wall is full of pilasters, so the 14-stud gun bench has few places that fit: it is tried at three depths and its two
  weapon cases are made only when it was placed (it was, in the mock).

### Checked offline

The Luau code never ran. These ran in an offline plain-Lua mock of the Roblox API (the real `Layout`, `Kit`, `KitMeta` and `Mall` shell, the
real `StoresL2.luau` text passed through a Luau-to-Lua rewrite; kit props are boxes there, not meshes) and over its part list in Python:

- `python3 tools/luau_check.py src`: 136 files, 0 failing. The module ran to the end with no error (warnings: none) and nothing cut by the
  budget (663 or 664 of 700 props, 2,747 or 2,752 of 3,000 parts).
- Every container id is unique (148, all `MM2_...`, none shared with the L1 stores' `MM_L1_...`) and every pool and container kind exists in
  `Loot.luau`; every colour and material the module uses is a defined value (`C`, `hex`, `Enum.Material`), after the shell's first run died on
  a nil colour.
- On a 0.5-stud lattice, per room: no two props overlap (same height band, over 0.5 square stud), no prop stands in a shell wall or column
  (0.7 square stud), no collider lies outside its room, no prop stands in an entrance strip or a stock door's keep-out. Only the three
  planter notes above remain.
- Walkable floor for a 2-stud-wide walker, from each room's doors and entrances: at least 95 % of every room's free floor is connected (the
  staff kitchen first had a cut-off end, fixed), and every container and loose spot has that floor within 4.5 studs.
- Not covered: how the props face (the kit's front is -Z, taken from `Kit.luau`), how anything looks, how a Humanoid moves among them.

### Parity gaps from this part (copied to `docs/design/EFT_PARITY.md`)

- **Interiors are ours.** The reference gives each unit's rectangle and kind (and a few loot notes); the shelves, counters, tables and racks are
  placed by recipe, not copied from any plan.
- **Every container is filled in every raid.** SPT draws a subset of its container groups per raid (Ultra 45 to 49 of 129, MedicalShops 14 to
  18 of 38, ClothingShops 14 to 18 of 29); here all 114 on L2 and 34 on L0 exist and roll their kind's table. The loot tables are the game's own.
- **The saferoom** has the reference's couch with valuables, food and drink shelves, weapon cases and crates, but no microwave (nothing in
  the kit), no keypad or urinal step (Play's), and a dormitory, mess, infirmary and armoury of our own; **Object 14** has the secret stash as six
  walk-in containers (our design; the reference gives no interior).
- **The ULTRA medical storage** is a whole locked unit behind one door (the reference places the room, not the door, grade C), full of
  medicine shelves and med cases; the four LEDX spawn spots are not copied (no such item here).
- **A loose spot cannot name its item**: key tiles are `mallkeys` spots, so the key that lies there is a roll of that pool.
- **Stock rooms** of 25 of the 31 units; the five restaurants and `L2_father_sons` have none, as in the shell.
- **Lamps** (60, switched by the power) are ours; the reference's lighting is not documented.
- **Not run**: nothing above has run in Luau, Studio, on a phone or on a console; no frame rate or part count in Studio.

### Unverified (part 4b; nothing has run in Luau or Studio)

The module in Luau and Studio: the real part count and build time (the code hands the thread back every 0.04 s of work, like the shell); the
kit meshes and colliders in `ZR_Assets` (a prop whose mesh is missing is skipped by the kit without a warning, so rooms could be sparser);
the look and scale of the props in the rooms, and which way they face; whether the counters' lower colliders let a loose item land where it
should (the loot spawns by a ray 3 studs down); whether the prompts of containers inside the cargo containers and behind shelves are easy to
reach; the height of the gun bench's top against the weapon cases (3.4 studs, from the bench's collider); the swing and lock of
`MM_MEDIQ_STORE` with the power rule; the lamps (brightness, count) in the dark; the AI's pathing round the new furniture; frame rate on a
low-end phone with about 2,750 more parts on top of the shell's.

### Files (part 4b)

| File | What |
|---|---|
| `src/server/Maps/Meridian/StoresL2.luau` | the L2 units, the MEDIQ STORE ROOM, VOLTA's and the staff kitchen's stock rooms, THE SHELTER and UNIT 14: room frames and the placement rules, recipes by kind, special rooms, doors and keys, lamps, totals |
| `src/server/Maps/Meridian/Stores.luau` | the dispatcher (the L1 agent's): runs `StoresL1` then `StoresL2`; unchanged |
| `docs/design/EFT_PARITY.md` | the parity gaps above, as "Interchange upper floor stores and car-park rooms: Meridian Mall, part 4b" |

## Small shops: wall fixtures, floor fixtures, litter and fitting rooms (`StoresFill.luau`, 2026-11-01)

A Studio screenshot of L1 TAILORED (`L1_kostin`) showed about nine props and bare walls. `StoresFill.luau` is a furnishing pass that runs
when a shop's recipe is done (L1: at the end of `shop()`; L2: after the room's lamps). It only adds: the stores' containers, loose-loot
spots and doors are the same list, in the same places, with and without it (checked offline, below). It is called under `pcall`; if it
is missing or fails, a shop stays as its recipe made it.

### What Tarkov's small shops hold (read 2026-11-01)

No page describes the fixtures of the small shops; they name containers and loot, not furniture.

- eft-ammo wiki (Interchange): tech stores (Texho, Techlight, Rasmussen) have shelving and boxes; medical stores shelved medicine; KIBA
  weapon boxes, racks, armour racks and ammunition cases; the clothing shops "dominate the second level", with no description.
  Mannequins, fitting rooms and posters are not mentioned.
- ensigame guide: ADIK has a weapon box, three jackets, a duffle bag and occasional hat, backpack and armour spawns; the EMERCOM unit has
  loose medical items, three medbags, a jacket and a weapon crate. thelostgamer guide: KIBA has a weapon cabinet, two registers, two weapon
  crates, shelves and cabinets of mods and a box of grenades by the counter.
- The fandom wiki, ggrecon, sportskeeda (names five clothing shops, no interiors), ginx.tv (published 2023-05-09, updated 2024-07-19), the
  biligame wiki and tarkov.dev (page metadata only) add nothing about small-shop interiors.
- Our own `docs/maps/reference/INTERCHANGE_REFERENCE.md` agrees with the above (KIBA: armour on mannequins, registers, weapon boxes).

So the fixtures are what a shop of that kind has, by general retail knowledge, and the containers stay what the recipes already name.

### What was added, by shop type (45 shops: 28 on L1, 17 on L2)

| Type (shops) | Wall units | Floor fixtures | Litter |
|---|---|---|---|
| Clothing (17) | hanging-clothes rails over folded stacks, pegboards, kit shelves | clothes racks, display tables, mannequins, clothes bins | clothes heaps, cartons, a toppled rack or mannequin |
| Electronics (7) | TV walls, kit shelves, pegboards | tech tables, plinths with products, glass counters | cartons, glass shards, papers |
| Sports (4) | shoe-box walls, shelves, rails, pegboards | weight racks, roll cages, benches, mannequins | shoe boxes, clothes heaps |
| General and food (6) | kit shelves, fridges | gondolas, goods bins, trolleys | fallen goods, cartons, glass shards |
| Books, toys, shoes (3) | book shelves / shelves and pegboards / shoe walls | gondolas, tables, benches, an arcade cabinet, bins | books, toys, shoe boxes |
| Homeware, furniture, lighting (3) | shelves, pegboards | sofas, tables, a bed, rugs, standing lamps | cartons, a cardboard pile |
| Pharmacy, travel, museum (5) | medicine shelves / cork boards, pegboards | glass counters / luggage, benches / plinths and cases | papers, cartons |

- **A fitting room in every clothing shop (17 of 17).** Two or three cubicles with curtains, mirrors and stools under a header, against a free
  stretch of wall (with the walking strip in front) or free-standing with a back panel; the two most crowded shops (FASHION STORE,
  URBAN CLOTHES) have a single cubicle.
- **Posters and price boards** on every shop's bare wall: a frame and a coloured sheet, no lettering and no brand. A coloured band runs along
  the top of the walls.
- **Not touched:** the three anchors and IDEA's bistro, the food-court restaurants (their kitchens are recipes of their own), the locked stores
  (KIBA, EMERCOM, ULTRA's room) and the closed and unlabelled units.

### Budget and how it is counted

- Limit: +2,000 parts over both levels, a part being every Part and MeshPart (kit pieces and invisible colliders included). Counted by running
  the offline mock with and without the pass: stores 7,352 parts before (L1 4,611, L2 2,741), 9,280 after (L1 6,170, L2 3,110), so
  **+1,928** (1,091 own, 632 kit pieces, 205 colliders; 271 kit props): fitting rooms 224, wall units 327, posters 248, wall bands 140, floor
  fixtures 753, litter 236. The pass stops at 1,960 in all, 1,650 on L1 and 560 on L2 (it never reached them). A shop's share follows its
  floor area (24 to 80 parts on L1, 16 to 38 on L2) and each phase may spend only a part of it. The log prints `[ZR] Meridian small shops
  L1`, `L2` and `both floors` with these numbers; the L2 module's own part limit does not count them.
- Every new part has CastShadow and CanTouch off; none has a light. The ones nobody bumps into (posters, bands, litter under a stud high, rugs,
  hanging clothes) also have CanCollide and CanQuery off, so loot-snap rays, bullets and AI rays pass through; only fixtures that stand in
  the way keep collision (kit colliders, partitions, bins, counters, stools, lamp poles). Colours come from one palette of 25 and sizes
  repeat: a rail of clothes is one long part, a shelf of boxes one box.

### Checked offline (mock: kit props are boxes there; nothing ran in Luau, Studio, on a phone or for frame rate)

- `python3 tools/luau_check.py src`: 140 files, 0 failing; `StoresFill` has no undefined global in the mock's run.
- Containers (397), loose spots (406) and doors (76) are identical with and without the pass.
- No collidable part of ours stands in a loose spot's drop column, within 1.5 studs of a container, in an entrance's keep-out (9 studs
  deep, the opening's width plus 3; wall units may touch its edge) or in the 7-stud lane in front of a stock door (the closest part
  of ours stands 0.8 stud from a door leaf). None overlaps a recipe part by more than 0.35 stud; no poster or band sinks into one.
- Walkable floor on a 1-stud grid with a 1.2-stud margin round every solid: each container, each stock door and each pair of entrances
  that could reach each other before the pass still can (665 checks, none lost).

### Remaining gaps (for `docs/design/EFT_PARITY.md`, which this change did not touch)

- **Small-shop interiors are ours.** No source gives their fixtures, so racks, shelves, fitting rooms and clutter are by kind, not a copy
  of any Tarkov shop; posters are blank coloured sheets.
- **L2 shops stay sparse.** Their recipes already fill the floor, so 17 shops got +369 parts (SARA, ARENA, NA SVYAZI and TARKOVSTAR 7 to 16,
  mostly posters, bands and litter); L1's shallow shops (VOYAGE, GERMAN, SPIEL, TEXHO) did not reach their targets for the same reason.
- **Checked in Studio, 2026-11-01:** 1,938 parts and 0 failed shops. The map builds in 7.5 s. TAILORED and MICROMART were screenshotted (`TEST_RESULTS.md`).
- **Still unverified:** the real part count and load time (the pass hands the thread back every 0.04 s), the look and scale of the
  fixtures (kit meshes in `ZR_Assets`; a missing mesh is skipped), the loot snap and AI paths round them, and frame rate on a low-end
  phone with about 1,900 more parts.

### Files (small shops)

| File | What |
|---|---|
| `src/server/Maps/Meridian/StoresFill.luau` | new: the pass (`B.shopFill`; `Fill.shop(a)`, `Fill.report(level)`), the styles by shop kind, the budget |
| `src/server/Maps/Meridian/StoresL1.luau` | the `fill` adapter, called at the end of `shop()`, and the log line |
| `src/server/Maps/Meridian/StoresL2.luau` | the same for the L2 rooms (`FILL_KIND`, Intourist's board kept clear) and the log lines |

## Tested in Studio (2026-11-01)

The whole map ran in Studio on the T490 (one client, in-memory store); see `TEST_RESULTS.md`, Meridian Mall on Interchange.

- Builds in 8 to 9 s at server start with no errors: 18,400 parts in the map model (mall shell 5,360; stores L1 941 props, 250
  containers, 233 loose spots; stores L2 662 props, 148 containers, 165 loose spots; play; dress 2,060), 70 doors, 5 electric locks.
- Fixed while testing: the shell failed on an undefined glass colour (no walls, signs or stock rooms were built); the L0 floor slabs were
  coplanar with the terrain (a camouflage pattern on the car park floor; the terrain now lies 2.5 studs under the slabs); the detail plan
  crowned the balustrades with barbed wire and cracked every wall like a ruin (the mall and both store levels now carry NoWire and the
  clean profile: the map's detail entries went from 33,818 to 10,962).
- AI walk the map: scavs crossed 260 to 915 studs in three minutes, up the ramps and escalators to L2; route guards walk, posted guards
  hold; THE CARETAKER walks BOLTWORKS. MapTests 38/38 with the stores in.
- Frame rate on the laptop in Studio: 12 to 16 fps in the mall (about 16,800 parts streamed in), the same range as Border Yard that
  session. Phones are unmeasured.

