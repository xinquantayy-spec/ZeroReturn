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
- Task places: STACK (east yard), SM_CATWALK (catwalks over the hall), SM_MANAGER (manager's desk), SM_CASTING (the
  aid post's table), SM_PUMPHOUSE, SM_SIDING (hopper wagons on the rail siding through the hall).
- Doors: SM_GATEDOOR, SM_CELLAR, SM_MGR take KEY_SMELT_OFFICE (EFT's emergency exit key); SM_RECORDS and SM_SHIFT
  are plain doors; SM_STORE takes the card KEY_SMELT_STORE once that item exists (unlocked until then).
- Loot: 92 containers (positions ours; SPT's mix by kind: 43 crates, 13 toolboxes, 12 jackets, 9 weapon boxes,
  5 drawers, 4 safes, 3 medbags, 3 tech boxes; duffle bags and grenade boxes become crates, bank safes safes) and 50
  loose spots (33 junk, 15 office, 2 keys).
- Raid: 20 minutes (`Maps.defs.smelter.raidTime = 1200`).

## Budgets and part count

Owner: full detail at full performance, 30 FPS on low-end phones. Counted offline (stub kit, NOT Studio):
**3,750 instances**, of which 3,561 parts: stair steps 1,103, walls 721, railing parts 661, floors 464, lamps 227,
machine blocks 88, roofs 64, crucibles and vessels 47, gate parts 28, outside 21, furniture 37, siding 8, container
boxes 92; plus 104 lights, 83 kit props (each counted once: in Roblox a prop is several parts) and 50 loose spots. Real
counts in Studio will be higher (prop pieces, container fittings, door leaves, prompts); nothing has been measured
in Studio or on a phone. Indoor props cast no sun shadow; walls are real wall parts (the detail layer finds them).

## Offline checks and previews (NOT Studio)

    python3 -I tools/factory_layout.py                       # regenerate Layout.luau (prints counts and warnings)
    <python with lupa> -I tools/smelter_preview.py run rec.json
    python3 -I tools/smelter_preview.py draw rec.json        # -> docs/maps/reference/smelter_build_preview.png
    python3 -I tools/smelter_preview.py ref                  # -> docs/maps/reference/factory_layout_preview.png

`run` builds the map under Lua 5.4 with a stub kit; `draw` draws every recorded part per floor over the reference
and runs MapTests-like checks with axis-aligned boxes (spawns on a floor with head room, exits over a floor, loose
spots on a surface, containers and AI points out of the walls). Last run: 0 problems. This is not a Roblox run: no
physics, raycasts against real geometry, lighting or frame rate.

## Gaps (also in EFT_PARITY.md once the coordinator logs them)

- Heights of roofs, walls and the catwalks; container and loose positions; Gate 2's spot and conditions: ours.
- Items pending: the emergency key's name and uses, the sealed store's card, the hidden exit's note.
- One raid length (EFT: 25 minutes at night). No Woods or Lab transit. No breaching or vaulting beyond doors and open
  windows. No duffle bag, grenade box or body containers (crates stand in). No PvE AI PMCs.
