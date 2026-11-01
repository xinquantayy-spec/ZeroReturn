# Look 2.0 (M12): wear, clutter and graphics levels

Zero Return's maps should look used and neglected (Tarkov-level imperfection) and still run on phones, consoles and
older PCs. Three layers do that work, and a graphics setting decides how much of it each player draws.

## 1. Worn materials (everyone, part of the map)

* Eight original MaterialVariants (Rojo `src/materials/*.model.json`), made from procedural textures by
  `assets/textures/gen_materials.py` (colour, normal, roughness; no photos):
  * concrete worn and precast panels;
  * floor concrete;
  * plaster peel;
  * painted metal;
  * corrugated sheet;
  * weathered planks;
  * cracked asphalt.
* `World.applyWear` picks a variant for each part by its material and shape. Slabs become floor concrete, long
  perimeter walls become precast panels, and roads become cracked asphalt. A part can ask for a specific one with
  the `Wear` attribute.
* **Fixed this session:** five of the eight variants rendered almost black. Each texture loaded fine on its own;
  only those exact texture sets failed, most likely a load failure cached while the images were still processing
  after upload. New roughness maps (new asset IDs) fixed all five (`evidence/L08`, `evidence/L09`).

## 2. Cover props (everyone, gameplay geometry)

There are 28 props from the Blender wear kit (`ZR_WearKit`) on Quay 7:

| Prop | Count |
|---|---|
| Burnt-out car wrecks | 7 |
| Dumpsters (green, blue, rust) | 3 |
| Tyre stacks | 3 |
| Cinder block stacks | 2 |
| Dented drums | 3 |
| Cable reels | 2 |
| Broken barriers | 2 |
| Sandbags | 3 |
| Pallet stacks | 3 |

* Where they go: the open yards, the roads, the north lot, the east apron and around the annex. The top-down view
  is `evidence/L10`.
* Behaviour: they collide and stop bullets. AI cover sampling picks them up (cover points went from 834 to 1,018).
* Clearances: every spot was checked against spawns, exfil zones, AI posts and paths, loot spots, containers and
  doors.
* Fallback: each prop has a same-size block in case the mesh batch is missing.
* Code: `World.luau` (`Props.cover`, the `kit` list in `buildLandmarksAndRoutes`).

## 3. Detail layer (each client, cosmetic only)

* **Server, once per map:** `DetailPlan.generate` reads the finished map and writes a seeded list of details. It
  looks at:
  * wall faces, wall openings and windows;
  * floors and roads;
  * wall caps;
  * shipping containers.
* The list goes into 64-stud cells in `ReplicatedStorage.ZR_DetailPlan`. Quay 7 has about 2,000 entries (164 KB),
  and generation takes about 1.2 s at server start.
  * Decals: water streaks, ground grime and damp, peeling plaster, cracks, spalls, bullet holes, rust runs, leaks,
    soot, graffiti of the game's own factions, oil, puddles, debris, leaves, skid marks, manholes.
  * Wear-kit meshes: rubble, litter, cardboard, trash bags, tyres, planks, weeds, rebar. Indoors: tipped bins and
    chairs, fallen ceiling tiles and hanging wires. On walls: downpipes, AC units, electrical boxes, conduit, vents,
    lamps, cable runs and radiators. Also barbed wire on boundary walls, plus broken window frames and glass.
* **Client:** `Detail.luau` builds the cells around the camera in rings (60 instances per frame, so there is no
  hitch) and removes them as the camera moves on.
  * The distance is to the cell's 3D box, so the safehouse under the map builds nothing.
  * Details never collide, take bullets, block sight or show up in raycasts.
  * Clutter keeps clear of loot spots, containers, doors (and their swing), exfils and spawns, and stays low or flat
    against surfaces.
* Doors and container furniture are marked `NoDetail`, so nothing hangs in the air when a door opens.

## Graphics setting (Settings → GRAPHICS)

**HIGH is the default on every platform, phones included** (owner decision). Lower levels are opt-in.

| Level | Detail rings (studs) | Post effects | Materials | Shadows | Other |
|---|---|---|---|---|---|
| HIGH (3) | 270 / 215 / 150 | depth of field, sun rays, bloom, two grain layers, turn blur | worn variants | on | full rain, most particles |
| MEDIUM (2) | 200 / 155 / – | sun rays, bloom, two grain layers, turn blur | worn variants | on | full rain |
| LOW (1) | 135 / – / – | one grain layer, turn blur | worn variants | on | half rain, fewer particles |
| POTATO (0) | no detail | one grain layer, no turn blur | plain (variants removed locally) | off | no cloud layer, 30% rain, fewest particles |

* The three ring numbers are the distances for fine, medium and coarse detail.
* Every level has the same fog, light levels, exposure and gameplay geometry, so no setting sees further or through
  more.
* The server accepts 0–3 only. Other numbers are rounded and clamped, and anything that is not a number is refused.
* Leaving POTATO restores every material.
* HOLD 30 FPS (on by default, owner 2026-11-01): a device that stays under 30 fps for 8 seconds steps down one GRAPHICS level (not in the first 20 s of a life, then 15 s between steps). It only judges while the game window is in front: it waits for the window to gain focus or for the first input, and pauses when focus is lost. Studio and a background window slow the frames otherwise. With it off, a one-time notice points to Settings → GRAPHICS after 20 seconds under 24 fps. The
  level is never lowered automatically.

## Lamps

* Street lamps switch on in the dark, fog or heavy rain.
* The map marks some lamps with the `Lamp` attribute:
  * the one by the depot and the one on the west road **flicker** in short bursts;
  * the one by the relay gate is **dead**.
* Every client sees the same lamps (`evidence/L06`).

## Performance (Studio on the T490 laptop; indicative only)

Measured with one client and the server in the same Studio process, so Studio's own cost is included. These are not
device numbers.

| Place | HIGH | MEDIUM | LOW | POTATO |
|---|---|---|---|---|
| South yard / dormitory | 36.8 fps (1,148 details) | 43.1 (693) | 45.4 (174) | 58.9 (0) |
| Harbor Stack (with container wear) | 33.5 (1,709) | 39.4 (1,023) | 42.6 (172) | 58.2 (0) |

* The detail layer itself costs about 3 fps at the Harbor Stack: 32.6 fps with it, 35.8 with the folder removed.
* Most of the gap between levels comes from post effects (depth of field on HIGH; sun rays, bloom and the second
  grain layer on MEDIUM and above), plus shadows and materials on POTATO.
* Phones, tablets and consoles: **not measured**.

## Tests

* `ZR_Dev:Invoke("tests")` runs `LookTests` (19 checks), which cover:
  * the graphics level through the real request path;
  * the published plan: well formed, known images, library meshes, clutter clear of play spots, under 400 KB;
  * the server building no detail itself;
  * cover props: solid, using the meshes, clear of spawns and exfils, and a shot at a car wreck stopping at the
    wreck.
* Visual checks: `evidence/L01`–`L11`.

## Adding detail to a new map

1. Build the gameplay geometry in `World` as usual. Mark moving or furniture parts `NoDetail`.
2. Call `DetailPlan.generate({ mapModel }, seed, World.detailAvoid())` after the map is parented (see
   `Main.server.luau`).
3. Run `tests` and walk the map at HIGH and POTATO.
