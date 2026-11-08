# SMELTER on the Factory layout: build spec

Owner, decision art-1a (2026-11-08): rebuild the Smelter on Escape from Tarkov's Factory layout at real scale; keep
the name SMELTER and its kit (a smelting works: furnaces, crucibles, slag). Same map, our own buildings and names.
Reference: `docs/maps/reference/FACTORY_REFERENCE.md` and `factory_layout.json` (metres; section 0 has the frame,
section 1 the grades A to D). The outlines come from a community map licensed CC BY-NC-SA 4.0: they are a layout
guide only, and no SVG, plan pixels or raw SPT data are shipped.

## Frame, scale, origin

- Reference frame: metres, x east, z south (north is -z), origin at the centre of the tarkov.dev bounds; the frame is
  131.9 x 142.5 m.
- Roblox: **S = 3.125 studs per metre** (the project's scale). Map-local studs = metres x S; the frame is
  x -206.1..206.1, z -222.7..222.7 studs (`L.frame`); the layout's outside ground fills `L.outer` (+-212.5, +-231.25).
- Origin **`O = Vector3.new(1600, 0, 0)`** (the Smelter's old spot): world `W.bounds` x 1393.9..1806.1,
  z -222.7..222.7, y -14.4..33.4. Clear of Quay 7 (0), Border Yard (z -5200), Meridian, the bunker (z 4000) and the
  tutorial (x -2400); SmelterTests S01 checks it against every built map's bounds.
- Heights: the main hall floor (game y 0.1) is local y 0; **local y = (game y - 0.1) x S**.

| Level | game y | local y (studs) |
|---|---|---|
| the sump (stash cave) | -3.86 | -12.38 |
| tunnels | -2.60 | -8.44 |
| main hall, annexes, east yard | 0.10 | 0 |
| west wing, courtyard, office ground floor | 1.08 | 3.06 |
| control gallery, loading dock | 2.73 | 8.22 |
| office second floor | 4.57 | 13.97 |
| office third floor, catwalks | 8.23 | 25.41 |
| roof of the halls (ours) | 12.6 | 39.06 |
| roofs of the single-storey annexes (ours) | 6.0 | 18.44 |
| walls round the two yards (ours) | 4.5 m | 13.75 |
| the two service pits by the wreck (ours) | 1.5 m deep | -4.69 |

## Modules

`Smelter.luau` stays the module World requires (`moduleMap("smelter", "Smelter")` unchanged); its parts sit in the
sibling folder `SmelterParts` (a folder named `Smelter` would sit beside the laptop's stale `Smelter.luau`, giving two
ModuleScripts named Smelter). Each part is `return function(B)` and runs under pcall, in this order.

| File | What |
|---|---|
| `src/server/Maps/Smelter.luau` | entry `return function(kit, root)`: model "Smelter", the context B, runs the parts, sets `W.bounds`, prints a part summary |
| `src/server/Maps/SmelterParts/Layout.luau` | GENERATED: the reference in studs with our names (slabs, walls, lines, doors, flights, landings, steps, rails, boxes, cyls, labels, extracts, transits, spawns, scav and boss points, containers, loose spots, routes, cult zones, lamps) |
| `src/server/Maps/SmelterParts/Shell.luau` | floors, walls, roofs, stairs, landings, level steps, railings, the crucibles and vessels on legs, the outside ground, the play boundary, distant blocks |
| `src/server/Maps/SmelterParts/Play.luau` | extracts and rules, the transit, spawns, AI routes and posts, scav zones, THE STOKER, THE CULT, task places, doors and keys, containers, loose loot |
| `src/server/Maps/SmelterParts/Dress.luau` | Blender kit props on the reference's obstacles (blast furnaces for its boilers, forklifts, tank skids, pallet racks, vans, machines, lockers, benches), the rail siding and hopper wagons, task furniture, office and hall furniture, lamps |
| `tools/factory_layout.py` | reference JSON -> Layout.luau (`python3 -I tools/factory_layout.py`; numpy, scipy, Pillow) |
| `tools/smelter_preview.py` | offline previews and checks (below) |
| `src/server/Tests/SmelterTests.luau` | the built map's checks (ZR_Dev "tests") |
| `src/shared/Maps.luau` | smelter: kind "SMELTING WORKS", raidTime 1200, new description |
| `src/shared/QuestData.luau` | the Smelter's task places and texts re-placed on this layout |

How the generator works: a 0.1 m raster per level from the reference's floor rings; walls are a 0.4 m band round
every floor plus the reference's wall lines, with the doors and windows of the re3mr plan cut out; walls under an
upper floor stop at its underside; stairs come from the SVG's stair symbols, solved to the levels they join (straight
flights, U-turn towers with landings); railings on open deck edges; floors are cut over flights and under landings;
roofs over the halls and annexes; spawns, containers and AI points are nudged off walls, machines and stairs.

## Our names (the layout is Factory's, the names are ours)

| Factory | SMELTER |
|---|---|
| Office Building (Main Office, Breach Room, Locked Office) | OFFICE BLOCK (SHIFT OFFICE, RECORDS ROOM, MANAGER'S OFFICE) |
| North / South Stairs, Sky Bridge, Connector | NORTH STAIR / SOUTH STAIR, HIGH BRIDGE, THE LINK |
| Locker Rooms, Sinks, Hole | CHANGING ROOM, WASHROOM, THE DROP |
| Platform, Servers, Scav Bunker | LOADING DOCK, CONTROL GALLERY, THE DUGOUT |
| Silos, Pit, Boilers, Rafters | THE CRUCIBLES, CRUCIBLE PIT, FURNACE HALL, THE CATWALKS |
| Med Tent, Heli Crash, Underground Stash | AID POST, THE WRECK, THE SUMP |
| Blue Containers, Wood Room, Glass Hall | CONTAINER ROOM, TIMBER STORE, NORTH GALLERY |
| Pumping Station, East Halls, Forklifts | PUMP HOUSE, EAST BAYS, FORKLIFT BAY |
| TerraGroup storage room | the sealed store (SM_STORE) |
| Tagilla / cultists | THE STOKER / THE CULT (existing) |

| Exit (EFT) | Ours | id | Rule here |
|---|---|---|---|
| Gate 3 | ORE GATE | G3 | open, PMCs and scavs |
| Gate 0 | SLAG GATE | G0 | open, PMCs only |
| Med Tent Gate | AID POST GATE | GM | open, PMCs only; reached through SM_GATEDOOR (KEY_SMELT_OFFICE) |
| Cellars | CABLE CELLAR | CL | open, PMCs only; reached through SM_CELLAR (KEY_SMELT_OFFICE) |
| Courtyard Gate | YARD GATE | GY | open, PMCs only |
| Gate 2 | COKE GATE | G2 | open, PMCs only (EFT's conditions unpublished: ours) |
| Camera Bunker Door | BUNKER HATCH | CB | scavs |
| Office Window | TIMEKEEPER'S WINDOW | OW | scavs |
| Smugglers' Passage | SMUGGLERS' CRAWL | SC | key exit with the note NOTE_SMELT_CRAWL; built only once that item exists |
| Transit to Customs | TRANSIT TO BORDER YARD | TR_BORDER | to "border" (Woods and Lab transits: no map) |

One entry point (EFT): `W.sideExtracts = { all = ... }`, and every spawn lists every PMC exit.

## Hooks (Play)

- Spawns: 16, one per SPT player group (the point with the most room), side "all", named after the nearest of our
  place names on the same floor.
- AI: four scav routes (HL the hall loop, FN the furnace hall, TN the tunnels, WW the west wing; FN and WW have posts),
  19 scav zones (SPT's 12 bot and 7 boss points). EFT's Factory has scavs only, so every post is a scav post.
- THE STOKER (Tagilla): chance 0.3, hp 1220/440, charges, homes = SPT's seven boss points, walks the hall loop.
- THE CULT: night only, chance 0.08 (kept), three zones: SOUTH TUNNEL, EAST TUNNEL, CONTAINER ROOM.
- Task places: STACK (east yard, the slag heap at 50, 9 m), SM_CATWALK (catwalks over the hall), SM_MANAGER (manager's desk), SM_CASTING (the
  aid post's table), SM_PUMPHOUSE, SM_SIDING (hopper wagons on the rail siding through the hall).
- Doors: SM_GATEDOOR, SM_CELLAR, SM_MGR take KEY_SMELT_OFFICE (EFT's emergency exit key); SM_RECORDS and SM_SHIFT
  are plain doors; SM_STORE takes the card KEY_SMELT_STORE once that item exists (unlocked until then).
- Loot: 88 containers (positions ours; SPT's mix by kind: 42 crates, 13 toolboxes, 9 weapon boxes, 8 jackets,
  7 drawers, 4 safes, 3 tech boxes, 2 medbags; duffle bags and grenade boxes become crates, bank safes safes) and 51
  loose spots (33 junk, 15 office, 3 keys).
- Transit: TR_BORDER's zone at (50.6, -7.8) m on clear floor in the east yard, by the east gate.
- Raid: 20 minutes (`Maps.defs.smelter.raidTime = 1200`).

## Walking room (Roblox, not EFT): what the layout gives up so every way is walkable

Studio's exit walk (ZR_Dev exitcheck, Roblox's pathfinding agent: radius 1 stud, 5.6 tall, doors open; 2026-11-09)
found the first build closed in places: no spawn reached ORE GATE or TIMEKEEPER'S WINDOW, the office's third floor
did not connect, four spawns were walled in. The causes and what `tools/factory_layout.py` now does:

- **Doorways** (`MIN_PASS` = 1.4 m, 4.4 studs): EFT's are 0.8-1.0 m, and the agent found no way through 0.85 m gaps.
  Floor necks narrower than 1.4 m that open onto wider floor at two places are widened about their middle; gaps
  between wall lines that face each other end to end (16 on the ground floor, 1 upstairs) step back to 1.4 m; the six
  door leaves and their openings are 1.4 m (the cable cellar's door now stands in the SVG's own doorway at
  x 30.8, z -60.95 m, with lintels over both tunnel doors).
- **Head room** (`HEAD` = 7 studs): a floor over a stair that ends less than 7 studs under it is cut away (the
  switchback towers' half landings had 4.5 studs under the office's second and third floors); the office's two towers
  stop at the wall they reached 0.6 m into, so their half landings are deep enough to turn on.
- **The courtyard**: EFT's two jump windows from the office and the window over the courtyard stair are vaulted
  through; with no vaulting here they are broken out to the floor (a sill slab under the upstairs one).
- **Stairs to the second floor**: at most 45 degrees (the east block's two were 50) and a landing a metre past the
  top step, kept clear of the second floor's walls (both ran into them).
- **Catwalks**: EFT's paired 0.9 m catwalks (0.6 m apart) are one deck; catwalks under 1.4 m widen to it.
- **Switchback towers**: a steel side panel up each flight's open side (to a rail's height over its top step) and a
  rail on every open landing edge (walk test: holding W up a hall tower's first flight ran the player off its half
  landing); a storey landing's end stays open where a floor lies beyond it.
- **Placement**: the transit's zone stands on clear floor (it was on the van at the east gate); STACK and the slag heap
  stand in the east yard proper at (50, 9) m (64 m east was outside the yard's wall); the shift office's desks are off
  TIMEKEEPER'S WINDOW's zone; loot boxes keep out of doorways, narrow passages, each other and the walls on their
  storey, and a 2D walk per storey drops any box that would close a way or stand out of reach (88 boxes; SPT's mix).

## Budgets and part count

Owner: full detail at full performance, 30 FPS on low-end phones. Counted offline with the part fallbacks (stub kit, no
Kit5 batch: NOT Studio): **3,952 instances**, 3,767 parts (the side panels and landing rails added about 260); 104
lights, none casting shadows; 83 kit props (several parts each in Roblox); 88 boxes, 51 loose spots. Studio counted
3,497 parts with the Kit5 stairs and rails before this change (coordinator, 2026-11-09). Nothing has been measured on
a phone.

## Offline checks and previews (NOT Studio)

    python3 -I tools/factory_layout.py                       # regenerate Layout.luau (prints counts and warnings)
    <python with lupa> -I tools/smelter_preview.py run rec.json
    python3 -I tools/smelter_preview.py draw rec.json        # -> docs/maps/reference/smelter_build_preview.png
    python3 -I tools/smelter_preview.py paths rec.json [png] # the walk; docs/maps/reference/smelter_walk_preview.png
    python3 -I tools/smelter_preview.py ref                  # -> docs/maps/reference/factory_layout_preview.png

`run` builds the map under Lua 5.4 with a stub kit (Kit5 off, so MapKit's part fallbacks); `draw` draws every
recorded part per floor over the reference and runs MapTests-like box checks. `paths` voxelises every colliding part
at 0.5 studs and walks it with two agents: strict (radius 1.5, 6.5 tall, a body from 1.6 studs over its floor) for
every spawn to every exit it lists, the scav exits, the hidden exit and the transit, the office's floors and rooms and
every AI point; soft (radius 1, 6 tall) for the task places, loot boxes and loose spots. Cells join their neighbours a
stud up or down, so storeys join only where a flight, a ramp or a landing meets them. Calibration: on the build Studio
walked it flags all of exitcheck's failures (and more: it is the stricter agent); on this build it finds 0 problems,
and `draw` 0. Not a Roblox run: no physics, no navmesh, no door leaves (taken as open), Kit5 ramps not modelled.

## Gaps (also in EFT_PARITY.md once the coordinator logs them)

- Heights of roofs, walls and the catwalks; container and loose positions; Gate 2's spot and conditions: ours.
- Doorways 1.4 m (EFT 0.8-1.0 m), catwalks 1.4 m where EFT's are 0.9 m, the courtyard's windows broken out to the
  floor, side panels on the switchback towers: for Roblox's pathfinding and the missing vault.
- The second floor's small rooms north of the office's north stair take no loot (the walk finds them out of reach).
- One raid length (EFT: 25 minutes at night). No Woods or Lab transit. No breaching or vaulting beyond doors and open
  windows. No duffle bag, grenade box or body containers (crates stand in). No PvE AI PMCs.
