# Modular kit: buildings from merged meshes (decision art-5b)

Owner's decision art-5b (audit 2026-11-07, `docs/audit/2026-11-07/art.md`, art-5): "Modular Blender kit: wall, window,
door, stair and facade modules as merged meshes with baked shading, placed by the builders instead of loose parts". It is
the only option that improves the look and cuts the part count, which is the main phone risk.

**Status (2026-11-09, phase 1, branch `art5b-kit`):** the census, this design and the pilot (stair flights, handrails,
railings) are written and checked offline. **Nothing here has run in Studio, on a phone or in Blender.** The Kit5 batches
are not built or uploaded, so every map still builds today's parts (the fallback path is checked identical, part by part).
All part counts below are offline (`tools/kit_census.py`, a Lua 5.4 stand-in for Roblox), not Studio.

## 1. How Escape from Tarkov builds it

Sources are community reverse-engineering projects that read EFT's shipped level files (EFT is a Unity game). They agree
on one structure, and none contradicts it:

- **Every building piece is a render mesh with LODs plus separate colliders.** EFT puts movement collision on a layer
  named `LowPolyCollider` (what players and bots walk against, also used to bake the navmesh) and bullet and sight
  collision on `HighPolyCollider` (a finer shell carrying a `BallisticCollider` material such as `MetalThin`). A roller
  shutter, for example, is `roller_shutters_02_LOD0..2`, `_SHADOW_LOD0`, a `_COLLIDER` on `LowPolyCollider` and a
  `_BALLISTIC_metalthin` mesh collider. EFT's ballistics ray mask leaves `LowPolyCollider` out, and the character's
  movement mask is `LowPolyCollider | DoorLowPolyCollider | Terrain | Player`.
  [atlas: build pipeline and pack format](https://github.com/ConocoFieldsForever/atlas) (`docs/extraction/build-pipeline-and-pack-format.md`,
  `docs/extraction/colliders-interactables-and-semantics.md`);
  [ArenaMapPort](https://github.com/maschine34675/ArenaMapPort) (`docs/progress/exfils-stage2.md`,
  `ArenaMapPort.Client/BallisticTwinRepairs.cs`); [SPT-FuckThesePhysics](https://github.com/rootdarkarchon/SPT-FuckThesePhysics)
  (`docs/research/movement-collision-batching.md`).
- **Stairs are one mesh walked on a ramp.** EFT's levels carry `Stairs_ramp` objects (ArenaMapPort,
  `docs/progress/airpit-source-060.md`), a flight is one mesh with LODs (`Sparja_stairs_LOD0`, 4.02 m of rise over a
  3.17 m run; atlas `viewer/src/nav_bake.rs`), and the community Tarkov map SDK, which copies retail practice, keeps "the
  ramp ... as what players and bots walk on (and the navmesh is baked from it)" while the steps stay "as its bullet
  collision" ([TushonkaMappingSDK README](https://github.com/ReplayDEVYT/TushonkaMappingSDK)).
- **Railings and fittings are repeated instances of one source asset** ("twelve copies of one railing are one" source
  object; atlas `viewer/src/assets.rs`), and EFT's navmesh agents have no drop or jump links (atlas build doc).
- **Footsteps** come from the `BallisticCollider` material under one downward ray (ArenaMapPort `AGENTS.md`).
- Battlestate wrote its own culling and streamed 35 sub-terrains to hold the frame rate on its big maps
  ([Made with Unity: Escape from Tarkov](https://unity.com/ru/made-with-unity/escape-from-tarkov)). No source read here
  describes BSG's trim sheets or wall modules, so the wall and facade phases below are our design, not a copy.

## 2. Roblox facts the design follows

- A MeshPart is one part and one draw-able instance. Its size scales its geometry, details included, so a variant is
  never stretched to another step count: per-count variants, scaled only within tolerances.
- Game scripts cannot set SurfaceAppearance maps; colour comes from baked vertex colours tinted by `MeshPart.Color`, and
  Roblox materials tile on meshes without UVs (`docs/PIPELINE.md`, `Kit.luau`).
- Roblox ignores `CanQuery = false` on a part that collides (found in Studio on 2026-11-01, `Glass.luau`). A collider that
  stops bodies but not bullets therefore needs a collision group: bullets are cast in `ZR_Shot` and the AI's sight in
  `ZR_Sight` (`Glass.luau`), so a group that does not collide with those two passes both while bodies and ordinary rays
  (camera, vaulting, grenades) still meet it.
- The Humanoid walks wedges: the project already walks wedge ramps (Relay 7's motor pool, Meridian's south atrium, Quay 7's
  dock). `Humanoid.MaxSlopeAngle` is not set anywhere, so it is the engine default (89 degrees from memory; the Creator Hub
  page could not be read in this session). PathfindingService has no slope setting, and a DevForum report says its paths
  even cross slopes a character cannot climb ([DevForum](https://devforum.roblox.com/t/max-slope-for-pathfindingservice/1063491)),
  so ramps should path; the AI going up and down kit stairs is a Studio check (section 7).
- Kit props are cosmetic pieces plus a few invisible box colliders, with a plain stand-in while a batch loads (`Kit.luau`,
  `KitMeta.luau`); the tidy pass (`Tidy.luau`) moves and removes models that carry the `Kit` attribute.

## 3. Where the parts come from (census)

`python3 -I tools/kit_census.py all` builds each map under a Roblox stand-in (Lua 5.4 via lupa; prop, nature and cover
batches count as loaded, as in Studio) and records the builder call stack of every part. No Tidy or wear pass, no terrain.
Offline totals against the coordinator's Studio counts of 2026-11-09:

| Map | Offline | Studio | Groups (offline / Studio) |
|---|---|---|---|
| Border Yard | 25,205 | 25,544 | Works 9,540 / 9,666, Living 7,620 / 7,912, Fences 2,427 / 2,412, Forest 2,290 / 2,245, Dressing 1,078 / 1,021, Roads 839 / 839, Rails 762 / 762, Power 415 / 415 |
| Meridian Mall | 20,520 | 20,698 | Mall 5,502 / 5,632, StoresL1 4,624 / 4,636, StoresL2 2,645 / 2,657, Dressing 2,058 / 2,061, StoresFill 1,943 / 1,933, Outside 1,223 / 1,226, Power 558 / 558, Roads 546 / 546 |
| Smelter | 3,968 | 3,984 | Stairs 1,103 / 1,103, Walls 721 / 721, Railings 661 / 661, Floors 464 / 464, Machines 316 / 316, Lamps 227 / 227 |
| Relay 7 | 1,228 | 1,228 | Dress 1,085, Shell 98, Stations 45 |

Top categories by builder call (offline):

| Map | Biggest families |
|---|---|
| Border Yard | kit props 5,051 (Blender prop pieces and their colliders), walls with holes 4,127 (`World.wallHoles`), chain-link fences 2,643 (`MapKit.fence`), trees 2,440 (`MapKit.nat`), **railings 2,328** (`Works.rail` 1,532, `railAt` 644, `Living.rail`, bridge rails), **stairs 1,634** (`Works.stairs` 1,251, `Living.flight` 374), road and rail beds 1,502 (`Ground.board`), box-built interiors about 4,150 (Living's junk, bands and washrooms, Works' racks, shelves and lamps) |
| Meridian Mall | kit props 8,960, mall walls 3,006 (`MallShell.wallRun` 2,289, `shopFront` 717), box-built shop fittings about 4,400 (`StoresL1Kit.shelf` 582, `StoresFill`), power lines 558, glass balustrades 534, **stairs 491** (`MallLinks`), fences 451, trees 400, walls with holes 400 |
| Smelter | **stairs 1,103**, walls 721 (boxes from the layout), **railings 661**, floors 464, kit props 400, lamps 227 |
| Relay 7 | kit props 908 (the bunker kit), shell and stations 320; no stairs or railings |

## 4. The kit

**Principles.** A module is a merged mesh with baked shading (vertex-colour ambient occlusion, dust, worn edges) that takes
no collisions, rays or touches, plus the fewest invisible colliders that make it play like today: Tarkov's render mesh,
movement collider and ballistic collider. Variants are per count or per nominal length and scaled only within limits.
Meshes are near white and tinted with the builder's colour, so one variant serves every palette. Every builder tries the
kit first and keeps its part-built code as the fallback (batch not uploaded, still loading, or no variant fits), so a map
always plays the same. Kit placements are structure, not props: they drop the `Kit` attribute so the tidy pass leaves
them where the builder put them, as it leaves today's steps.

**Families, by measured saving** (phase 1 built; the others are proposals for the next phases):

| Phase | Family | What it replaces | Saving (offline estimate) |
|---|---|---|---|
| 1 (done) | Stair flights, handrails, railings | steps, stringers, posts and bars | Border 2,903, Smelter 1,254, Meridian 464 (measured, section 5) |
| 2 | One opaque piece per kit prop (glass and glow stay apart) | today's one piece per material | Meridian 4,132, Border 1,992, Relay 7 356, Smelter 160; costs per-material Roblox textures on those props unless a SurfaceAppearance atlas is made in the owner's upload session (art-4) |
| 2 | Fence modules (posts and top rail per stretch; the chain-link panel stays, it is the collider and carries the texture) | 6.8 parts a run | Border about 1,870 (386 runs), Meridian about 230 |
| 3 | Wall panels with openings: door, window and solid panels per length class with frames, sills and lintels in the mesh | `World.wallHoles` and `MallShell.wallRun` boxes | about a third of the wall parts if the panels collide by their own mesh (Studio check: an inserted MeshPart's `CollisionFidelity` keeps door and window holes open); otherwise the same count with a far better look |
| 3 | Power pylons, facades, cornices, gutters, balconies | pylon boxes; nothing today (look) | pylons about 70 % of 629 parts |

## 5. Phase 1: stair flights and railings

**Variants** (`assets/blender_scripts/build_kit5.py`, 170 props in two batches; one piece each):

| Batch | Prop | Counts | What it is |
|---|---|---|---|
| ZR_Kit5A | `K5StairC<n>` | 4..36, 50 | solid concrete flight down to a 0.25 skirt, a steel angle on every nosing |
| ZR_Kit5A | `K5StairO<n>` | 4..24 | concrete flight with a straight soffit (a waist slab 1.5 deep at the risers) |
| ZR_Kit5A | `K5StairS<n>` | 4..36 | steel flight: plate treads with folded nosings and brackets on two flat stringers, open risers |
| ZR_Kit5A | `K5StairE<n>` | 50 | a stopped escalator's steps: cleats, yellow edge lines (its own colours, untinted) |
| ZR_Kit5B | `K5HandA<n>`, `K5HandB<n>` | 4..36, 4..24 | one side's handrail for 0.5 / 0.65-stud risers: posts on the treads, a top rail 3.2 and a mid rail 1.6 over the nosing line |
| ZR_Kit5B | `K5Rail1..27` | 0.56 to 64 studs | level railing module: inset end posts, posts every 6 studs or less, top rail 3.3, mid rail 1.7, toe board |

Flights are modelled at riser 0.5, tread 0.8, width 4 and scaled to the flight within riser 0.35..0.73, tread 0.32..2.8
and width (steel 2.4..7.2, concrete any). The counts are those the maps build (C 7 to 34 and 50, O 11 to 22, S 9 to 32,
E 50) plus spares. Railing runs take the module of the nearest nominal length, stretched or squeezed 11 % at most; runs
over 64 studs are cut into equal modules of 32 to 64.

**Placement** (`src/server/Maps/MapKit.luau`): `H.k5Flight(parent, cf, n, h, t, w, style, color, mat, opts)` from the foot
of the flight (front edge of the first riser, middle of the width, looking up the flight) and `H.k5Rail(parent, a, b,
color, mat)` between two deck points. Both return nil when the kit cannot build it, and the builder builds its parts:
`MapKit.stairs` / `MapKit.rail`, Border's `Works.stairs` (with its rails as handrails) and `Works.rail` (and so
`railRect`, `pitRails`), `Living` `Frame:flight` / `Frame:rail`, the Smelter's `Shell` flights and deck rails, Meridian's
`MallLinks` stairs and escalators, Quay 7's two stairs in `World.luau`. Relay 7 builds no stairs or railings.

**Colliders.**
- A flight's ramp (`StairRamp`, in the default group, so feet, bullets and the AI's sight meet it as they met the steps)
  runs through the middle of every tread, from half a tread before the first riser (on the floor: no lip) to the back of
  the last tread (a quarter riser above the landing). Solid flights get a wedge (bullets stop in the stair, not under its
  treads); open and steel flights a 0.6 slab under the treads, which keeps the head room under the switchback towers.
  Feet are within half a riser of the tread under them (0 at the tread middles). Its material is the builder's, so
  footsteps sound as before. A flight filled more than a stud below its foot (off a landing) gets one plain block for
  the fill.
- A railing has one collider per straight run and each handrail one along the slope, 3.45 high, in the new collision
  group `ZR_Move`: bodies and ordinary rays meet it, bullets (`ZR_Shot`) and the AI's sight (`ZR_Sight`) pass it
  (Tarkov's `LowPolyCollider`; thin rails are no cover). MapKit registers the group and its two non-collisions the first
  time it builds a railing; if that fails, railings keep their parts.

**Measured** (offline census, the same build with and without the batch; every flight and railing call took the kit):

| Map | Total | Stairs | Railings | Kit calls |
|---|---|---|---|---|
| Border Yard | 25,205 -> 22,302 (-11.5 %) | 1,634 -> 444 | 2,328 -> 615 | 93 flights (55 C, 13 O, 25 S), 292 railing runs |
| Meridian Mall | 20,520 -> 20,056 (-2.3 %) | 491 -> 27 | balustrades unchanged | 13 flights (10 C, 3 E) |
| Smelter | 3,968 -> 2,714 (-31.6 %) | 1,103 -> 194 | 661 -> 316 | 72 flights (32 C, 40 S), 132 railing runs |
| Relay 7 | 1,228 -> 1,228 | none | none | none |
| Quay 7 | not run offline | 40 steps and 4 handrail parts -> about 8 | | 2 flights |

Checks run offline: the fallback build is identical to today's, part by part (class, size, position, rotation, material,
collision, name, model), on all four maps; every kit ramp lies within half a riser of the steps it replaces at 12 points
along its length (249 ramps); `KitTests` under the stand-in, with rays against boxes and wedges and the collision groups:
51 passed with the kit, 12 passed and 7 skipped without.

**Meridian's glass balustrades** (a pane and a handrail per run, 2 parts) and its flights' side panels stay parts: they
are already two parts a run, and glass and metal are two materials.

## 6. Plays the same?

| | Today | With the kit |
|---|---|---|
| Walking up stairs | the humanoid steps up 0.5-stud boxes | it walks a ramp at the treads' middle line; feet within half a riser of the tread; prone and crouch on a slope instead of ledges |
| Bullets and sight on stairs | stop on the steps | stop on the ramp (within half a riser of the step surface) |
| Railings and bullets | the bars (about 15 % of a railing's face) stop bullets and block sight | bullets and sight pass (Tarkov: thin metal, a movement-only collider) |
| Railings and bodies | blocked by the bars | blocked by a 3.45-high collider |
| Grenades at railings | bounce off a bar or pass a gap | bounce off the collider (a Studio check: a grenade lobbed through a railing gap now stops) |
| AI paths | navmesh over 0.5 steps | navmesh over ramps (Studio check) |
| Loot, props, tidy pass | | loose loot snaps to the ramp; kit meshes take no queries; Kit5 models are structure (no `Kit` attribute) |

## 7. To run and check (coordinator)

1. Blender: `g = {}; exec(open(r"<project>/assets/blender_scripts/build_kit5.py").read(), g)`, then `g["build"]()` until
   it reports `remaining 0` (45 s a call), `g["sheet"]("A")` and `g["sheet"]("B")` to look at the batches, `g["export"]()`.
2. Upload `assets/exports/ZR_Kit5A.fbx` and `ZR_Kit5B.fbx` (`zr_upload.upload_model`), add both ids to
   `src/shared/AssetIds.luau`, then `python3 tools/kit_meta.py ZR_MallKitA ZR_MallKitB ZR_MallKitC ZR_BunkerKitA
   ZR_BunkerKitB ZR_BunkerKitC ZR_Kit5A ZR_Kit5B` (no change to the tool is needed).
3. Studio: `KitTests` (ZR_Dev "tests"); walk, sprint, crouch and go prone up and down a C, O, S and E flight (the Border
   dorm stairwells, the Smelter's office and catwalk towers, Meridian's grand stairs and escalators, Quay 7's annex and
   dorm), with first-person camera smoothness and footstep sounds; an AI following a player upstairs in each; shooting
   through a railing (passes) and at a stair (stops); a grenade thrown at a railing; nothing tidied off a doorway; the
   part counts per group against section 5; a low-end phone's frame rate (never measured).

## 8. Against Tarkov

Matches: buildings' stairs as single meshes walked on ramps, with the steps' look kept; railings as repeated modules;
separate movement and ballistic collision (`ZR_Move` against `ZR_Shot` / `ZR_Sight`); footsteps from the walked
collider's material; steel stairs with plate treads and stringers, concrete flights with nosing angles, handrails on
posts, toe boards on industrial railings.

Gaps: railings let every bullet through (EFT's `BallisticCollider` lets a bar stop or slow a round by its material);
stairs stop bullets on the ramp, not on the step faces; no LODs or shadow meshes per module (Roblox picks its own mesh
detail); handrails follow two riser families and are stretched up to 14 %; walls, windows, doors and facades are still
part-built (phases 2 and 3); the variant dimensions and the stair and railing styles are ours (no BSG dimensions read).
