# Modular kit: buildings from merged meshes (decision art-5b)

Owner's decision art-5b (audit 2026-11-07, `docs/audit/2026-11-07/art.md`, art-5): "Modular Blender kit: wall, window,
door, stair and facade modules as merged meshes with baked shading, placed by the builders instead of loose parts". It is
the only option that improves the look and cuts the part count, which is the main phone risk.

**Status (2026-11-09):** phase 1 (stair flights, handrails, railings) is live: ZR_Kit5A and ZR_Kit5B are uploaded and
the coordinator ran KitTests in Studio. Phase 2 (branch `art5b-kit`) adds fence modules (section 6, batch ZR_Kit5C, not
built or uploaded yet) and merged pieces for the mall and bunker kits (section 7, switched off; the merged exports are
not made yet). **Nothing of phase 2 has run in Studio, in Blender or on a phone.** Without the new batches every map builds
today's parts, checked identical part by part. All part counts below are offline (`tools/kit_census.py`, a Lua 5.4
stand-in for Roblox), not Studio.

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
- **Chain-link fences are cutout meshes on posts with thin colliders.** `metall_fence_2` is a mesh with an alpha-cutout
  texture (`chain_fence`, `chain_fence_nrm`) and its own small LOD group (ArenaMapPort `docs/progress/wp1.md`); thin
  fences carry box colliders scaled to about 1 cm (`docs/progress/stage1-combat.md`). The ballistic side has its own
  material, `Chainfence` (EFT's `MaterialType` 4, TushonkaMappingSDK `GameStubs/EFT.Ballistics/MaterialType.cs`, with its
  own sound in `Editor/TarkovAcoustics.cs`); Arena's tower fences carry the preset `Chainfence` over the collider material
  `MetalThin` (ArenaMapPort `docs/progress/bowl-release.md`, `tools/extract/extract_ballistics.py`). No source read gives
  BSG's post spacing or fence heights.
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
| 2 (built, section 6) | Fence modules (posts and top rail per stretch; the chain-link panel stays, it is the collider and carries the texture) | posts and rail parts | Border 1,630, Meridian 120 (measured) |
| 2 (built, off, section 7) | One opaque piece per kit prop (glass and glow stay apart) | today's one piece per material | one piece: Meridian 2,886, Border 1,738, Smelter 151, Relay 7 74 at a look cost of 27 to 36 % of the placed kit surface; the 10 % rule: 726, 549, 55, 39 at 1 to 6 % (measured) |
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

## 6. Phase 2: fence modules

**Variants** (`build_kit5.py`, batch ZR_Kit5C, 27 props, one metal piece each): `K5Fence1..27`, a chain-link fence's
frame `RAIL_LENGTHS` long (0.56 to 64 studs, the railing lengths): round posts with caps every 8 studs or less, sunk 0.6
into the ground, a top rail 0.12 under the 7.8-stud top, a tension wire near the ground. The end posts stand on the
module's ends (unlike the railing's inset posts), so where two modules or two runs meet, in a line or at a polyline
corner, their posts coincide and read as one post. The see-through panel is not in the mesh: each builder keeps its
`ChainLink` part, the collider and the carrier of the chain-link texture, exactly as today.

**Placement** (`MapKit.luau`): `H.k5Fence(parent, a, b, h, color, mat, opts)` builds a run between two ground points as
a `FenceKit` model of `FenceModule`s (attribute `Kit5 = "fence"`, structure, not a tidy-pass prop), cut into equal
modules of 64 studs or less, each scaled to its length within 11 % and to the height within 0.7..1.2 of 7.8. It returns
nil, and the builder builds its posts and rail, for runs steeper than 1.2 studs end to end (a level module there would
float at one end; 37 of Border's 385 runs, 10 of Meridian's 116) or the batch not loaded. `opts.bayStart` / `bayEnd`
mark the ends where a fence line ends (where it may meet a building): those ends are 8-stud modules of their own, so
the tidy pass, which removes fence parts that run into a building, trims a bay, as it trimmed posts, not the whole run.
Builders: `H.fence` (Border's ground fences, which mark the line ends, and dressing fences), `Works.fenceRun` (deck
guards), Meridian's ground fences (marking the line ends). The parked Pinewatch map keeps its own fence code.

**Measured** (offline, with ZR_Kit5A/B loaded in both runs):

| Map | Total | Fences | Runs |
|---|---|---|---|
| Border Yard | 22,318 -> 20,688 (-7.3 %) | 2,643 -> 1,029 (Fences group 2,427 -> 968, Dressing 1,078 -> 939) | 348 kit (453 modules), 37 steep runs on parts |
| Meridian Mall | 20,056 -> 19,936 (-0.6 %) | 451 -> 331 (its fences had posts every 28 studs; the modules have them every 8 or less) | 106 kit (191 modules), 10 steep runs on parts |

The build without ZR_Kit5C is today's, part by part, on both maps. The tidy pass's fence rule replayed offline on the
census (its overlap and wall-depth tests against the buildings' structural parts): with parts it would remove 13 posts and
2 rails (43 studs) on Border, with the kit 3 modules (42 studs); none on Meridian.

## 7. Phase 2: merged pieces

A kit prop is one MeshPart per material today, so a prop of five materials is five parts. The merged export joins a
prop's opaque pieces into one mesh `ZR_MK_<Prop>__<mat>_M` (batches `ZR_MallKitAM` .. `ZR_BunkerKitCM`), and
`Kit.place` uses it where `Kit.MERGE[batch]` is on and the mesh is loaded.

**The rule** (`zr_kit.merge_plan`, one function for the Blender export and the offline estimate): the opaque pieces join
under the material with the most surface area (a tie goes to the first in the material list); a material joins when it
renders like that one or its share of the opaque area is at most `absorb` (default 1.0: every opaque piece, one piece
per prop, as asked). Glass stays apart (it is see-through) and so does glow (the lobby switches it on and off). The joined
surfaces keep their colours (baked vertex colours) and take the main material's Roblox material, variant and reflectance:
that is the look cost.

**Play stays the same.** Bullets, the AI's sight and footsteps read the material of the part they hit or stand on. Kit
pieces take no collisions, queries or touches, merged or not, so they are never hit; the prop's box colliders keep the
material of its first piece either way (`Kit.place` reads it from `pieces`, which the merge does not change). Where the
merge could change what is built, it is kept out:
- a placement that tints, re-materials or re-variants a joined piece keeps its pieces (the joined mesh has one look);
- `Kit.NOMERGE`: the steel plate (the lobby drops its "paint" piece when shot) and the first aid box (no collider, so
  Border's `cont` makes its biggest piece the loot container);
- a merged piece carries `KitJoins` (the pieces it stands for) and Meridian's `StoresFill` counts it against its part
  budget, so the budget fills the same and the same props are placed.
Checked offline on all four maps and both rules: every part but the cosmetic pieces (every collider, wall, floor and
container) is identical with the merge on; KitTests K06 builds every mall and bunker prop with the merge off and on and
compares the colliders (count, size, place, material, CanQuery, CanCollide).

**Look cost, measured.** The areas come from the six build scripts run under an offline stand-in for Blender's
`bmesh`/`mathutils` (`kit_census.py merge`; checked against the exported pieces' bounding boxes: 416 of 449 within 0.02
studs, the rest rubble chunks and cylinders turned a few degrees, whose area is the same; bevels count as plain boxes).
The look cost is the share of surface whose Roblox material, variant or reflectance changes.

| | One piece per prop (absorb 1.0) | absorb 0.1 |
|---|---|---|
| Library (one of each prop) | 449 pieces -> 194; look cost 14 to 42 % of each batch's surface | 449 -> 352; 1.5 to 6 % |
| Meridian Mall | 19,936 -> 17,050 (-2,886, -14.5 %); 1,657 placements merged, 461 kept their pieces (tinted, re-materialled or NOMERGE); look cost 26.7 % | -726; 0.8 % |
| Border Yard | 20,688 -> 18,950 (-1,738, -8.4 %); 1,129 merged, 243 kept; 31.9 % | -549; 1.1 % |
| Smelter | 2,897 -> 2,746 (-151, -5.2 %); 76 merged; 36.3 % | -55; 5.6 % |
| Relay 7 | 1,228 -> 1,154 (-74, -6 %); 58 merged, 162 kept (most of the lobby's props are tinted); 1.8 %; 298 kit props either way (rule: under 300) | -39; 0.7 % |

The worst props under one piece are those with near-equal areas of three materials: a sparse gondola (metal, paint and
plastic, 65 % changes), the ceiling holes (concrete over plaster and metal, 62 %), the trader counter (61 %), shelves and
fridges (50 to 57 %). Under absorb 0.1 the worst is the van (13 %: its plastic, fabric and rubber take the paint).

**A/B in Studio:** `Kit.MERGE` is read when a prop is placed, so switch a batch on (command bar:
`require(game.ServerScriptService.ZRServer.Maps.Kit).MERGE.ZR_MallKitB = true`) and rebuild the map. Merged pieces carry
`KitMerged = true`.

## 8. Plays the same?

| | Today | With the kit |
|---|---|---|
| Walking up stairs | the humanoid steps up 0.5-stud boxes | it walks a ramp at the treads' middle line; feet within half a riser of the tread; prone and crouch on a slope instead of ledges |
| Bullets and sight on stairs | stop on the steps | stop on the ramp (within half a riser of the step surface) |
| Railings and bullets | the bars (about 15 % of a railing's face) stop bullets and block sight | bullets and sight pass (Tarkov: thin metal, a movement-only collider) |
| Railings and bodies | blocked by the bars | blocked by a 3.45-high collider |
| Grenades at railings | bounce off a bar or pass a gap | bounce off the collider (a Studio check: a grenade lobbed through a railing gap now stops) |
| AI paths | navmesh over 0.5 steps | navmesh over ramps (Studio check) |
| Loot, props, tidy pass | | loose loot snaps to the ramp; kit meshes take no queries; Kit5 models are structure (no `Kit` attribute) |
| Fences | posts and a rail as parts, the `ChainLink` panel collides | modules take no collisions; the same `ChainLink` panel collides; the tidy pass trims an 8-stud bay where a fence line runs into a building |
| Merged pieces (when switched on) | one piece per material | the same colliders and colliders' materials, the same layout (offline: every non-cosmetic part identical); only the look of the joined surfaces changes |

## 9. To run and check (coordinator)

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
4. Fences (phase 2): after step 1's `exec`, `g["build"]([n for n in g["prop_names"]() if n.startswith("K5Fence")])`
   builds the 27 fence modules alone (its "remaining" also counts batches A and B when they are not in the scene), then
   `g["sheet"]("C")` to look and `g["export"]("C")` -> `assets/exports/ZR_Kit5C.fbx` (it refuses while a fence variant is
   missing); upload it, add `ZR_Kit5C` to `AssetIds.luau`, run `kit_meta.py` with ZR_Kit5C added to the list. Studio: KitTests (K01 sizes, K02 fence, K05 fence runs); Border's and Meridian's fence
   lines at corners, on slopes and where they meet buildings; walking into a fence (the panel still stops you).
5. Merged pieces (phase 2): in Blender, for each of the six kit scripts (build_mall_kit_a/b/c.py,
   build_bunker_kit_a/b/c.py): `g = {}; exec(open(r"<project>/assets/blender_scripts/build_mall_kit_a.py").read(), g)`,
   `names = list(g["PROPS"])`, `g["build"](names)`; these builds start again from the first prop on every call, so when
   one reports `_stopped_after: X`, continue with `g["build"](names[names.index(X) + 1:])` until none does. Then
   `import zr_kit; zr_kit.kit_export_merged(g["objects"](), "ZR_MallKitA", g["scene"](), expect=names)` (it refuses a
   half-built batch; add `absorb=0.1` for the cheaper rule; it prints the batch's look cost). Upload the six
   `ZR_*KitAM..CM.fbx`, add their keys to `AssetIds.luau`, run `kit_meta.py` with the usual list (it finds the merged
   exports itself). Studio: KitTests K06; the A/B of section 7 on Meridian (gondolas, wall shelves, fridges, ceiling
   holes), Border, the Smelter and Relay 7.
6. K07 (a note in the KitTests line): whether the WallBreach and DoorFrame meshes, remade with each `CollisionFidelity`,
   keep their openings open; this decides whether wall panels (phase 3) could collide by their own mesh.

## 10. Against Tarkov

Matches: buildings' stairs as single meshes walked on ramps, with the steps' look kept; railings as repeated modules;
separate movement and ballistic collision (`ZR_Move` against `ZR_Shot` / `ZR_Sight`); footsteps from the walked
collider's material; steel stairs with plate treads and stringers, concrete flights with nosing angles, handrails on
posts, toe boards on industrial railings.

Phase 2 matches: chain-link fences as a frame mesh with a separate see-through panel and a thin collider, as EFT's
cutout meshes on posts with thin box colliders; a prop drawn as one mesh with its colliders apart, as EFT draws a
building piece as one render mesh with separate colliders (section 1).

Gaps: railings let every bullet through (EFT's `BallisticCollider` lets a bar stop or slow a round by its material);
stairs stop bullets on the ramp, not on the step faces; no LODs or shadow meshes per module (Roblox picks its own mesh
detail); handrails follow two riser families and are stretched up to 14 %; walls, windows, doors and facades are still
part-built (phase 3); the variant dimensions and the stair, railing and fence styles are ours (no BSG dimensions read).
Fences: the chain-link panel stops bullets and sight (KNOWN_ISSUES 43; EFT gives chain-link its own ballistic material,
`Chainfence`); steep runs keep their parts. Merged pieces: a Unity mesh can carry several materials, a Roblox MeshPart
only one, so the joined surfaces lose their own grain (the look cost in section 7).
