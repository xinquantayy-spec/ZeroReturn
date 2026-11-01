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
- **fences, rails, power:** one of these running through a building. A rail spur into THE DEPOT is meant to be there.

`ZR_Dev:Invoke("tidylog", mapId, what)` lists what the last tidy run did to each prop. The `what` values are:
`doorway`, `swing`, `twin`, `stacked`, `water`, `lifted`, `moved`, `wedged`, `left` and `short`.

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

## Left for later

See `KNOWN_ISSUES.md` 69.
