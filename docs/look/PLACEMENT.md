# Placement: the tidy pass and the audit

Owner, 2026-11-01: "ensure the placements of the buildings, props, objects etc makes sense and is imitating the look of
escape from tarkov. ensure nothing is placed abnormally or glitching."

In Tarkov:

- Every prop stands on a floor or hangs on a wall.
- Nothing stands in a doorway or in a door's swing.
- Furniture stands against walls, not through them.
- Underground rooms are clean concrete boxes.
- Trees stand outside buildings.

The maps here are built by rule at server start, with thousands of props. Two tools check and fix them.

## The tidy pass: `src/server/Maps/Tidy.luau`

It runs once on every map (except the Relay 7 lobby), after the world is parented to the workspace. Rays and box queries
need the world there. It runs the same way on every server start and takes 0.3 to 0.9 s a map.

It never removes:

- a prop holding loot, a prompt or a door;
- a wall or ceiling fitting (`Tidy.FIXED`).

It may move a container's own box (crate, safe, drawers). These are now one model each (`Box_<id>`, attribute `LootBox`)
for this reason.

| Step | What it does |
|---|---|
| Doorways | Removes props standing in a closed leaf's opening, up to 1.2 studs either side. |
| Door swings | Doors.luau turns a leaf about its hinge. Each door is tried in all four ways it can hang: hinge at either end, opening to either side. It takes the way that opens widest, up to 100°. A wall, a column, a tank or anything holding loot stops the leaf. The choice is stored in `d.hinge`, `d.turn` and `d.swing`, and the handle moves to the free end. Props without loot in the chosen swing are removed. |
| Twins | Removes the second of two identical props on one spot. |
| Trees | Removes a trunk (with its crown), a crown or a bush that has grown through a building, a fence or a rock, or that stands on a road. |
| Fences | Removes a fence piece that runs into a building's wall or floor, so the fence stops at the building. |
| Water | Removes an outdoor dressing prop that stands on water or over nothing at its centre and all four corners. Props of 16 studs or more stay. |
| Sunk | Lifts a prop that stands 0.15 to 0.3 studs into a floor or the ground onto the surface. |
| Walls | Pushes a prop out of a wall, an upright tank (radial test), a wall fitting's collider, or a bigger prop on the same floor. It can take up to three pushes, so a prop gets out of a corner. The total move is at most half the prop's width. Small loose dressing that cannot be freed is removed: it is at most 4.5 studs and not a chair. Furniture and loot are left and logged. |
| Flush | Sets furniture that belongs against a wall back against it when it stands 0.08 to 1.6 studs off: lockers, shelves, cabinets, fridges, desks, benches and beds. Many kits have their origin off the middle of their footprint, so the builders left them standing off the wall. Nothing may be in the way, and the furniture must stay out of every doorway and door swing. |
| Stacked | Of two props sharing more than 40 % of the smaller one's box, removes the smaller. If that one holds loot, it removes the other. A chair pushed under a table stays. The office desk is not exempt: its kit has its own chair. |

The console prints one line per map, for example:

`[ZR] border tidy: 22 out of doorways, 1 out of door swings, 30 doors re-hung, ...`

## The audit: ZR_Dev `audit` and `tidylog`

These live in `src/server/Services/DevExt/Placement.luau`, on the Studio test bridge.

`ZR_Dev:Invoke("audit", mapId, examples)` returns JSON. For each check it gives a count, counts by kit, and the first
examples with positions. The checks:

- **floating:** nothing under the base, and not hung on a wall or a ceiling. A prop marked `Raised` is skipped.
- **sunk:** 0.3 studs to 60 % of its height into a floor, the terrain or a solid part.
- **clipping:** more than 0.3 studs into a solid part.
- **door:** in a doorway, or in a leaf's way as it opens the way it hangs.
- **stairs:** standing on a stair flight.
- **stacked:** two props share more than 40 % of the smaller box.
- **container:** a loot container's own box runs into a prop or a wall.
- **tree:** a trunk inside a building, or a crown through a roof.
- **road:** a trunk or a bush on a road.
- **gap:** furniture that belongs against a wall standing 0.25 to 1.6 studs off it.
- **fences, rails, power:** one of these running through a building. A rail spur into THE DEPOT is meant to be there.

`ZR_Dev:Invoke("tidylog", mapId, what)` lists what the last tidy run did to each prop. The `what` values are:
`doorway`, `swing`, `twin`, `stacked`, `water`, `lifted`, `moved`, `wedged`, `left` and `short`.

`ZR_Dev:Invoke("roadaudit", mapId, examples)` (`border` or `meridian`) walks every paved road inside the limit. Every
2 studs it samples the centre and a stud inside each edge, with a ray from above. It returns JSON:
- `samples`: the samples that hit anything;
- `buried`: where the terrain is hit before the asphalt boards, by how far it stands over the board (under 0.2, 0.5 and
  1 stud, then 1 or more);
- `noboard`: no board at all (bridges, and roads outside the inner limit, which are painted into the terrain);
- `worst`: the worst places.

## Builder faults found and fixed at the source (2026-11-01/02)

- **Terrain in every Border underground room.** It stood along the walls, up to 9.5 studs over the floor of K-11, and
  hung under the ceilings. The terrain dig reached only 2 studs past each room, and smooth terrain slopes over a whole
  4-stud voxel. Rooms now get a 6-stud cut, and so do the stair shafts below the surface. The surface opening stays at 2.
- **THE SUBSTATION (Meridian).** The plinth was a 1.4-stud slab over the whole floor, so every prop, container and
  transformer stood 1.15 studs deep in it. The plinth is now flush with the floor.
- **Openings that shared a stretch of wall were dropped.** This left a door in a solid wall (STORE 17, beside the
  east gate) and bricked up the depot stair tower's slit windows. `World.wallHoles` now cuts the wall into stretches
  at every opening's edge.
- **Pump platforms.** They ran 6 to 7 studs into both fuel tanks. Now 29 studs long, they fit between the tanks. The
  hut stood across the pipe rack and its post, and its door was wider than its wall. It has moved and been resized,
  and its door now opens out.
- **Containers.** A plain container drew a 4-stud crate whatever it was: a first aid bag, a radio box or a chest.
  Every container now gets its look prop. A drawer on a desk uses the desk.
- **Hand-placed props in the motor shop and in STORE 3, 7 and 17.** Benches, chests, crates and lockers that stood
  in each other or in doorways have been moved.

Found on the Meridian exit walk-through (2026-11-02, TEST_RESULTS "Meridian exit walk-through"):

- **THE SHELTER was the whole block.** The reference draws the block solid and gives no room size, so the builder made
  the whole 216 x 201 block one room. Its furniture stood along far walls, and the exit sat alone in an empty concrete
  hall. The room is now a 134 x 89 bunker around the exit, and its furniture was laid out again.
- **FENCE GAP stood in a field.** The exit marker was 19 studs past the end of a fence, in open grass. The gap is now
  fenced, with a hole at the exit, drums and a red container.
- **Rails ran into the hill.** Where a railway leaves the map, its rails ended in the hillside or in Border's
  boundary rock. A tunnel portal with shut gates now takes the line in (`Maps/RailPortals.luau`, called from both maps'
  `Ground.luau`). It is built where the ground rises 10 studs within 14 past a line's end, or, on Border, where the
  boundary stands. Meridian has 2 portals, Border 5.
- **Trees by the rails.** A tree or bush on a track bed or right beside it is now removed, as on roads. This includes
  one in front of Border's CITY LINE portal. The pass removed 13 on Border.
- **SMUGGLERS' BOAT had no boat.** The exit was a beacon on the river bank. A small open motorboat is now moored
  off the west bank beside it, its deck just above the water (terrain water fills anything below), tied to a post on
  the bank (`Border/Play.luau`).
- **Roads into the rock (both maps).** Roads that leave the map ran straight into the boundary rock: 13 places on
  Border, including CROSSROADS, and 8 on Meridian. A row of concrete barriers now closes each road 6 studs short of the
  limit (`Maps/RoadEnds.luau`). A row is left out where it would reach into an exit zone or near a spawn, so all cover
  keeps clear of play spots (LookTests L03). Meridian's RESCUE CHECKPOINT road keeps its own gate.
- **ARMY ROADBLOCK had no roadblock.** The road just ended at the rock by the beacon. There is now a roadblock on the
  road in front of the zone: two staggered rows of barriers, sandbag walls on the shoulders and a guard booth
  (`Border/Dress.luau`, "road ends").
- **Clutter in door swings.** The client's ground clutter (tipped bins, litter) kept clear of a door's closed leaf,
  but not of where the leaf opens, and doors that start a raid ajar moved the spot. `World.detailAvoid` now holds the
  closed leaf and the leaf at a third, two thirds and all of its swing. Before this, LookTests L02 found 11 to 19
  clutter pieces in door swings during a Border raid; now there are none.

- **Roads in trenches and buried under banks (both maps, 2026-11-02).** A road was graded straight between its
  vertices, and Border's main_0 has three over 2,000 studs. It ran in a cutting up to 10 studs deep past the fuel stop,
  whose forecourt stood 20 studs over the road. The pads, rock mounds, pits and the river came after the grading and
  tilted road beds again, burying board edges under banks (up to 18.8 studs on Border).
  - `Maps/RoadBeds.luau` grades roads along the smoothed relief and levels the ground across every road last.
  - Ground over the asphalt by a stud or more: Border 203 to 1 samples, Meridian 86 to 3 (TEST_RESULTS "Road beds").

## Left for later

See `KNOWN_ISSUES.md` 69.
