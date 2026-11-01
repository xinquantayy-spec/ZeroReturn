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
| SC | SUBSTATION CAR | both | paid, 20,000 MK |
| SE | SHELTER EXIT | both | `power` with `also`: the mall power (`MALL_POWER`), then the washroom valve (`SHELTER_SWITCH`); a plain `MALL_POWER` rule if the valve could not be built |
| WC | WEST CAMP | scavs only | scav |
| RP | RIVER PATH | both | open |
| FG | FENCE GAP | both | `nobag` |

`W.sideExtracts`: nw = RC, SC, SE, RP, FG; se = RS, SC, SE, RP, FG. Scavs get all seven (existing rule). SE and WC stand on the L0 floor
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

- **Second boss**: Tagilla (the hammer boss in the KASSA garage, 35 % in the 2026 sources, absent from SPT) is not built; the AI supports one
  boss per map.
- **Airdrops** (20 %, 6 or more players, 5 to 15 minutes in): no airdrop system exists; the numbers are in `L.hazard.airdrop`.
- **Co-op, flare and transit extracts**: WEST CAMP is scav-only at the co-op spot, RIVER PATH is a plain open exit (no flare), and the two
  transits (Streets, Customs) do not exist.
- **SUBSTATION CAR** is a plain paid exit (20,000 MK, the 2026 figure): no car, no 50 % chance, no stay-by-the-car rule, no karma.
- **SHELTER EXIT is simplified**: mall power, then a hidden valve in the L2 washroom (for the urinal flush that reveals a keypad), then the
  keycard door, then the exit. Not copied: the keypad, the padlocked door with its inside button, the lever that opens Object-14, and
  the Terragroup container with the Object #21WS keycard in the south-west container yard.
- **Extract timers**: Tarkov gives each exit its own timer (3 to 60 s); here all use the standard hold.
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
