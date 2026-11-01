# Meridian Mall (Interchange layout)

The third map in the rotation. Rebuilt on 2026-11-01 on Escape from Tarkov's Interchange as it stands in 1.0 (the expanded
outside), at real scale: the layout (where things stand, how big, which way they face, how many floors, the roads, the car
parks, the camps, the extracts) is Interchange's, the buildings, names and art are ours (the owner's decision of 2026-11-01,
see `MERIDIAN_INTERCHANGE_BUILD.md`: same map, own buildings and names). The first Meridian Mall (a two-level mall of about
400 x 300 studs at origin (-1600, 0, 0), 2026-10) is gone; its code is in git history
(`git show 42049af:src/server/Maps/MeridianMall.luau`) and `src/server/Maps/MeridianMall.luau` is a stub.

Status: part 1 of 3 (foundation) is written: layout data, init, ground and outside structures, the power switch, the wiring in
`World.luau` and `Maps.luau` (raid time 2400 s). The mall itself (shell, stores) and the play layer are not built: the footprint
is a flat pad with a thin outline. Part 1 was written without a Luau runtime: `tools/luau_check.py` (structure only) passes, and an
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
| RS | RAIL SIDING | -1232, -1314 | se | open | north-west corner beside the west double railway |
| RC | RESCUE CHECKPOINT | 1246, 862 | nw | open | south-east corner beside the checkpoint (moved 8 studs inward from the reference) |
| SC | SUBSTATION CAR | 1112, -1124 | both | paid 20,000 MK | north-east corner by the sniper band; the car, 50 % chance and karma are gaps |
| SE | SHELTER EXIT | 512, 77 | both | power (`MALL_POWER`) | the hidden room east of car park C: power, then a hidden switch in the L2 washroom and a keycard at a panel (Play) |
| WC | WEST CAMP | 550, -210 | scav | scav | at the reference's co-op position (the service tunnel, L0), not at the huts; the spec name is kept |
| RP | RIVER PATH | -1372, 286 | both | open | far west edge on the dirt road; the flare is a gap |
| FG | FENCE GAP | 947, -219 | both | `nobag` (new kind) | the 46 m gap in the east service lane fence; the backpack slot must be empty (grade D) |

Until Play adds the kind `nobag` to `World`/`Raid`, FENCE GAP behaves as an open extract.

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

- **Mall shell** (agent 2): outer walls and entrances, L0 car park, garages, SHELTER and UNIT 14, L1 and L2 slabs, atria, roof, corridors,
  escalators and stairs, service corridors, docks, washrooms, empty store units with shopfronts.
- **Stores** (agents 3): every store's interior, containers, loose loot, doors, locked rooms and their keys, the ten new key items.
- **Play** (agent 3): extracts, PMC spawns by side (`W.spawns`, `W.sideExtracts`), scav zones, AI routes and watch posts (`W.patrols`,
  `W.watchPosts`), THE CARETAKER and his zones, what the power changes, the IRONSIGHT alarm, visit zones, lethal minefield and sniper
  bands, outdoor loot (the SUBSTATION yard, the camps, the checkpoint, the trucks), the `nobag` rule. Until then MapTests M01 (spawns,
  exfils, AI zones, patrol routes) and M05 (at least 10 containers per map; keys are real items) fail for this map; the others were not
  looked at.
- **Dress**: parked and burnt cars, trolleys, barriers, cones, bins, sandbags, nature at the edges.
- Outdoor containers and loose loot exist only inside THE SUBSTATION (8 containers); the camps, huts and sheds are empty shells.

## Parity gaps (to copy into `docs/design/EFT_PARITY.md`)

- Co-op extracts, transits and flares do not exist: WEST CAMP is scav-only at the reference's co-op spot, RIVER PATH is a plain open
  exit, SHELTER EXIT supports only the power rule (the hidden switch and the keycard panel are Play's).
- SUBSTATION CAR costs 20,000 MK (the 2026 figure; the car, the 50 % chance and karma are gaps); FENCE GAP's `nobag` rule is new.
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
