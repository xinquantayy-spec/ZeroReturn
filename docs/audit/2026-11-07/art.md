# Art audit: maps and world, models, materials, lighting, animation and VFX

Area id: `art`. Audited on 2026-11-07 against build `0.9.2-m13` (project docs dated 2026-11-02). The repo was read only.
Screenshots were looked at from `docs/*/evidence`. Nothing was run.

Terms used in this report:
- **stud**: Roblox's length unit. This project uses 3.125 studs = 1 metre.
- **triangles**: the flat pieces a 3D model is made of. More triangles give more shape detail and cost more to draw.
- **draw call**: one batch of work sent to the graphics chip. Phones slow down when a view needs many.
- **vertex colours**: colours painted onto a model's corners. No image is used.
- **UVs**: the map that tells a model where each part of an image goes. A model needs UVs to wear a texture.
- **PBR textures**: images for colour, bumps (normal), shine (roughness) and metal. They make surfaces look real.
  On Roblox a **SurfaceAppearance** puts them on one model. A **MaterialVariant** is a tiled material for many parts.

## Current state

The world, models and effects are a working first pass. Everything is built by code (Luau) and by procedural Blender
scripts. Two maps copy Tarkov layouts at real scale. Three maps are our own layouts. Relay 7 is the lobby. The look is a
mix of worn PBR materials on walls and floors, plain vertex-coloured props, block-bodied characters and the bodycam
camera stack. Nothing has been measured on a phone.

### Maps we have

| Map | What it copies | Size (playable) | State | Key files |
|---|---|---|---|---|
| Relay 7 | The owner's walk-around bunker lobby (an allowed exception) | 45 x 33 m | Done, cohesive | `src/server/Maps/Relay7.luau`, `Relay7Dress.luau`; built from `World.luau:674-678` |
| Border Yard | Tarkov's **Customs**, real scale | 1,024 x 542 m | In the vote, first pass | `src/server/Maps/Border/*`, generator `tools/customs_layout.py` |
| Meridian Mall | Tarkov's **Interchange**, real scale | about 940 x 840 m | In the vote, first pass | `src/server/Maps/Meridian/*`, generator `tools/interchange_layout.py` |
| Quay 7 | **Nothing.** An original industrial port from the vertical slice | about 123 x 123 m | In the vote (the default map) | `src/server/Services/World.luau:692-1729` |
| Smelter | **Nothing.** An original "factory-type" walled compound | about 82 x 63 m | In the vote | `src/server/Maps/Smelter.luau` |
| Pinewatch | **Nothing.** An original "woods-type" forest | about 164 x 164 m | Parked by the owner | `src/server/Maps/Pinewatch.luau` |

Answers to the brief's questions:
- **Quay 7** is the original harbour map of the vertical slice (container stacks, a pump annex, the freight depot,
  a crew dormitory). Tarkov has no matching map. Its theme is closest to Terminal, Tarkov's port, which is far bigger.
- **Smelter** is an original compound with a furnace hall, a casting shed, offices and tunnels
  (`Smelter.luau:2-5`: "An original layout"). It does not follow Tarkov's Factory.
- **Pinewatch** is an original forest with a sawmill, a lake and a ridge shelter (`Pinewatch.luau:2`). It does not
  follow Tarkov's Woods. It is about 1/70 of Woods' area.
- **Relay 7 is the lobby.** It is built as the safehouse at `Config.SAFEHOUSE_ORIGIN`, far from every map
  (`World.luau:674-678`, `docs/maps/RELAY7_LOBBY.md:10`).

### Tarkov maps as of November 2026, and what we have

Tarkov now has 13 locations ([TarkovForge](https://tarkovforge.com/maps), [eft-ammo](https://eft-ammo.com/maps)).
Sizes are the 2D map frames from [tarkov.dev's maps.json](https://github.com/the-hideout/tarkov-dev/blob/main/src/data/maps.json),
a little larger than the playable areas.

| Tarkov location | Tarkov size | Players, raid time | Ours |
|---|---|---|---|
| Customs | 1,070 x 544 m | 8-12, 40 min | Border Yard |
| Interchange | 1,031 x 868 m | 10-14, 40 min | Meridian Mall |
| Factory | 142 x 132 m | 4-6, 20 / 25 min | **Missing** (Smelter is an original, 82 x 63 m, 15 min raids, `Maps.luau:24-29`) |
| Woods | 1,407 x 1,356 m | 9-14, 40 min | **Missing** (Pinewatch is an original, 164 m, parked) |
| Shoreline | 1,560 x 1,033 m | 10-13, 45 min | **Missing** |
| Reserve | 592 x 537 m | 9-12, 40 min | **Missing** |
| Lighthouse (reworked in September 2026) | 1,060 x 1,723 m | 10-14, 40 min | **Missing** |
| Streets of Tarkov | 603 x 827 m | 12-16, 50 min | **Missing** |
| Ground Zero (starter map) | 348 x 488 m | 8-10, 35 min | **Missing** |
| The Lab | 207 x 284 m | 6-10, 35 min | **Missing** |
| The Labyrinth (permanent since April 2025) | 105 x 113 m | 1-5, 30 min | **Missing** |
| Terminal (the 1.0 end-game location) | 896 x 1,055 m | 1-5, 45 min | **Missing** |
| Icebreaker (May 2026, AI only, 1-3 players) | unverified (tarkov.dev repeats Factory's frame) | 1-3, 50 min | **Missing** |
| End of the Line | Not out: due in December 2026 (roadmap) | - | - |

Sources for the dates: Terminal ([Insider Gaming](https://insider-gaming.com/escape-from-tarkov-terminal-map-entered/)),
Icebreaker ([Insider Gaming, 1.0.5 notes](https://insider-gaming.com/escape-from-tarkov-1-5-update-patch-notes-icebreaker/)),
Lighthouse rework and End of the Line ([Vandal, 2026 roadmap](https://vandal.elespanol.com/noticia/2026240017/escape-from-tarkov-detalla-su-hoja-de-ruta-hasta-final-de-2026-nuevo-mapa-jefe-armas-y-unity-6/)),
the Labyrinth staying after its event ([CPG](https://consolepcgaming.com/escape-from-tarkovs-labyrinth-map-will-become-permanent-feature)).

### How the world is built

- **Buildings** are Roblox Parts made in code: walls are thin blocks with holes cut for doors and windows, floors and
  roofs are slabs (`MapKit.luau:42-58`, `docs/maps/BORDER_YARD.md:208-209`). Dorm doors are 3.9 x 7.5 studs (1.25 x 2.4 m).
- **Terrain** comes from height functions written by `TerrainKit.luau`. Roads lie on graded beds (`RoadBeds.luau`).
- **Props**: about 210 Blender props in kits (mall 86, bunker 70, wear 38 including the cover props, nature 20).
  `Kit.luau` places one mesh per material with invisible box colliders.
- **Worn materials**: 20 MaterialVariants with procedural PBR maps (`src/materials/*.model.json`), picked per part by
  `World.applyWear`.
- **Detail layer**: the server writes a plan of decals and small meshes (`DetailPlan.luau`). Each client builds the
  plan near its camera in distance rings set by the graphics level (`Detail.luau`). It never blocks shots or sight.
- **Placement**: `Tidy.luau` moves props out of doorways and walls at server start. A z-fighting pass removes flicker.
- **Glass** breaks (`Glass.luau`, 594 panes). **Doors** swing and lock (`Doors.luau`).

### Models

| Kind | What exists | Triangles |
|---|---|---|
| Character body | One block body for players and AI (`ZR_BLOCK_R15_V1`), 15 rigid segments on Motor6D joints | 3,880 |
| Worn gear | 33 gear meshes plus 16 eyewear meshes, rigid, welded, layered by scaling | 13,242 and 6,300 (about 400 each) |
| Guns | 6 guns and 91 parts as 187 meshes in 7 batches; viewmodel and world guns assembled from the parts | 128 to 1,544 per part |
| Items | 95 loose-loot models in 3 batches; 214 inventory pictures rendered from the models | 44 to 2,392 per item |
| Props | Mall kit A, B, C (86 props), bunker kit A, B, C (70), wear kit (38), nature kit (20) | most 72 to 2,900; a stocked shelf 7,326 |
| Trees | Pine and birch crowns of alpha-cut leaf cards | about 1,050 to 1,260 per crown |

Triangle sums come from `assets/exports/*.meta.json` and `TEST_RESULTS.md:834`.

**Pipeline** (`docs/PIPELINE.md:24-75`): Blender Python scripts make every mesh. Colour is vertex colour. There are no
UVs and no textures per model. Roblox's own materials and the MaterialVariants tile on top, measured in studs, so every
prop shares the same few loaded textures. Shading, ambient occlusion and grime are baked into the vertex colours. The
only SurfaceAppearance is the foliage atlas (`src/shared/ZR_FoliageSA.model.json`).

### Lighting, atmosphere and post-processing

- **Base light** is set on the server (`World.luau:623-660`): sun latitude 52, ambient, an Atmosphere, a colour grade
  and bloom. The code sets no `LightingStyle` and no `PrioritizeLightingQuality`.
- **Raid light** (`Atmos.luau`): a clock running at 7 times real time from one of eight start times, four weathers
  (clear, overcast, fog, rain), seasons from the real calendar (snow in winter, autumn colours), rain cells with
  splashes and lens drops, street lamps, lightning. FOG closes the view at 480 studs (150 m) (`Env.luau:10-32`).
- **Bodycam post** (`Post.luau`): two colour grades, bloom, sun rays, depth of field outdoors on HIGH, turn blur,
  auto-exposure with an indoor probe, two grain layers, a vignette and an edge haze. Pain, flash, smoke and concussion
  overlays. Field of view is 85 degrees vertical (`Config.luau:62`).
- **Devices**: night vision and thermal goggles (`NightVision.luau`), glasses and gas mask overlays (`Eyewear.luau`),
  laser beams (`LaserFx.luau`), glass shards (`GlassFx.luau`).
- **Graphics levels** POTATO to HIGH. HIGH is the default on every platform, phones included. HOLD 30 FPS steps the
  level down after 8 s under 30 fps (`docs/look/LOOK_2_0.md:78-95`).

### Animation and effects

- **First person** (`Weapon.luau`): poses blended in code. Hip, aim, sprint, reload (the magazine goes to a pouch and
  back), magazine and chamber check, inspect, shell-by-shell and pump, bolt, knife and grenade. Sway, bob, recoil and a
  pull-back near walls. The arms are the character's own block arms, scaled down.
- **Third person** (`Animator.luau`, `RigMath.luau`): procedural full-body poses. Walking with planted feet, crouch,
  prone, lean, aim pitch, gestures and ragdoll, with a distance level of detail.
- **Effects** (`Effects.luau`, `Grenade.luau`): muzzle flash, tracers for tracer rounds, one impact puff, bullet marks,
  explosions, smoke clouds and stun flashes.

## Strengths

1. **Real-scale layouts from graded data.** Border Yard and Meridian Mall come from traced community maps, SPT data and
   patch notes, with every position graded A to D for confidence and generated by scripts
   (`docs/maps/reference/CUSTOMS_REFERENCE.md`, `INTERCHANGE_REFERENCE.md`). The macro layouts are close to Tarkov's.
2. **A cheap, consistent material pipeline.** Props split by material share the textures already loaded, so a new prop
   costs no texture memory. Baked vertex shading keeps them readable on any device (`docs/PIPELINE.md:60-69`).
3. **Measured, honest performance work.** Draw calls were broken down by cause, the detail rings were cut about 30 %,
   FOG raids hide what lies past the fog, and the docs say plainly what was not run (`TEST_RESULTS.md:865-880`).
4. **Features unusual on Roblox.** Breakable glass, see-through foliage, seasons, night vision and thermals, lasers,
   flickering lamps, a z-fighting pass and a placement tidy pass with audit commands.
5. **A cohesive lobby.** Relay 7 has one clear period look and is cheap to draw (212 draw calls, 53,000 triangles,
   `docs/maps/RELAY7_LOBBY.md:67-72`).
6. **Good tools.** Layout generators, `ZR_Dev audit`, `tidylog`, `roadaudit`, and a benchmark mode (`ZR_Bench`).

## Findings

Ranked by severity, then by impact.

1. **[P1] Three of the five maps are not Tarkov layouts.** Quay 7 (about 123 m square), Smelter (about 82 x 63 m) and
   the parked Pinewatch (about 164 m square) are original designs, and Quay 7 and Smelter are in the vote. The project
   rule says maps copy Tarkov's layouts at real scale. Smelter is labelled "factory-type" but shares nothing with Factory
   (142 x 132 m, one large building).
   *Evidence:* `src/shared/Maps.luau:14-45`; `src/server/Maps/Smelter.luau:2` and `:735`; `src/server/Maps/Pinewatch.luau:2`
   and `:16`; `src/server/Services/World.luau:1728`; tarkov.dev bounds.
2. **[P1] 11 of Tarkov's 13 locations are missing.** Factory, Woods, Shoreline, Reserve, Lighthouse, Streets of Tarkov,
   Ground Zero, The Lab, The Labyrinth, Terminal and Icebreaker. End of the Line follows in December 2026.
   *Evidence:* `src/shared/Maps.luau:14`; [TarkovForge maps](https://tarkovforge.com/maps).
3. **[P1] Characters are block bodies about twice as wide as a person.** The body is 1.74 m tall but 1.37 m across the
   arms, the torso 0.69 m wide and the head 0.40 m wide (a real head is about 0.16 m). Shots hit these parts, so heads
   and bodies are far bigger targets than in Tarkov, and guns in third person are drawn 1.35 times real size to fit the
   hands. Dot-eye faces and toy proportions are the biggest single break from Tarkov's look. The owner chose the block
   body on 2026-10-28, before the parity rule of 2026-10-31, and the rule's exceptions do not list it.
   *Evidence:* `src/shared/RigSpec.luau:10-27`; `src/server/Services/Health.luau:21-26`; `src/shared/WeaponModels.luau:228-230`;
   `docs/kit/STATE/DECISIONS.md:12` (D11); `docs/character/evidence/C09_studio_roster_front_v1.jpg`,
   `docs/maps/evidence/BY_hounds_trio.jpg`.
4. **[P1] The real-scale maps are over the draw budget and unmeasured on phones.** Border Yard streams about 18,600
   parts near the player and Meridian about 16,800 (Quay 7: 2,500). A wide Border view needed 1,575 draw calls; shorter
   detail rings brought it to 1,072, still above the project's own starting target of under 700. Meridian's heaviest
   views ran 28 to 33 fps on the laptop at top quality. The biggest single cost is the wear decals: before the rings were
   shortened, 2,210 decals, each on its own thin part, made 55 % of the 1,575 draw calls. The 30 fps phone floor is a
   release condition.
   *Evidence:* `KNOWN_ISSUES.md` items 65, 66, 67; `TEST_RESULTS.md:867-880`; `DEVELOPMENT_STATUS.md:56`;
   `docs/kit/SPECS/09_PERFORMANCE_BUDGET.md` ("<700 draw calls"); `src/server/Services/DetailPlan.luau:62-70`.
5. **[P1] Combat effects are thin, and the parity doc says they are done.** The muzzle flash is a glowing ball 0.12
   studs (4 cm) wide in first person and 0.22 studs for others, shown for 0.045 s, with no smoke. Every bullet impact is
   the same grey puff from Roblox's stock smoke texture plus a black plastic disc as the hole, on any surface. Body hits
   make a dark puff. There is no blood and no ejected casings. `EFT_PARITY.md` lists per-material impacts, muzzle smoke
   and blood as "Have".
   *Evidence:* `src/client/Controllers/Effects.luau:366-438`; `src/client/Controllers/Weapon.luau:785-791`; a search of
   `src` for blood and casings finds none; `docs/design/EFT_PARITY.md:107`; `docs/maps/evidence/W01_muzzle_flash_small.jpg`.
6. **[P1] Buildings are block-built shells.** Walls are thin Parts with rectangular holes, floors and roofs are flat
   slabs, windows have panes but no frames, sills or lintels, and facades have no cornices, gutters or balconies. A large
   wall shows one tiled material from end to end. Next to Tarkov's modelled buildings this reads as a blockout.
   *Evidence:* `docs/maps/BORDER_YARD.md:208-209` and `:568-570`; `src/server/Maps/MapKit.luau:42-58`;
   `docs/maps/evidence/M08_meridian_facade.jpg`, `MM_exit_shelter.jpg`, `BY_tripwire_interior.jpg`.
7. **[P1] Props, guns and items are low in detail and flat in colour.** All meshes are vertex-coloured with no UVs, so
   they cannot show labels, print, scratches or fine bevels. Gun parts have 128 to 1,544 triangles and gear about 400.
   Shop goods are plain, saturated boxes, and the aimed first-person gun reads as dark blocks. Roblox allows 20,000
   triangles per mesh and PBR maps up to 1024 x 1024 per model, so there is room.
   *Evidence:* `assets/exports/*.meta.json`; `docs/PIPELINE.md:31` and `:60-69`; `docs/maps/evidence/M04_meridian_supermarket.jpg`,
   `docs/items/evidence/I03_loose_wires_volta.jpg`, `docs/character/evidence/FP02_block_arms_ads.jpg`;
   [Roblox mesh specifications](https://create.roblox.com/docs/art/modeling/specifications),
   [texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications).
8. **[P2] First-person animations are code-made poses and miss Tarkov's steps.** An empty reload only adds a "bolt
   forward" sound: there is no bolt release or charging handle. There is no quick reload that drops the magazine. The
   magazine check tugs the magazine a few centimetres instead of showing it. The inspect is two tilts. Third person uses
   procedural poses on the block rig and looks stiff. Tarkov plans new first-person magazine-loading animations for
   December 2026 ([Vandal](https://vandal.elespanol.com/noticia/2026240017/escape-from-tarkov-detalla-su-hoja-de-ruta-hasta-final-de-2026-nuevo-mapa-jefe-armas-y-unity-6/)).
   *Evidence:* `src/client/Controllers/Weapon.luau:880`, `:1197-1207`, `:1234-1290`; `src/client/Controllers/Animator.luau:1-6`;
   `docs/character/evidence/C02_gear_poses_idle_aim_walk_sprint.jpg`.
9. **[P2] Exits glow and are labelled in the world.** Every extract on every map has an orange glowing lamp on a pole,
   a sign reading "EXFIL id - name" and an orange painted zone on the ground. In Tarkov exits are not marked; players
   learn them and read cues such as flares ([GGRecon](https://www.ggrecon.com/guides/escape-from-tarkov-how-to-extract/)).
   *Evidence:* `src/server/Services/World.luau:741-768`, used by every map through `kit.extract` (for example
   `src/server/Maps/Border/Play.luau:66`); `docs/maps/evidence/MM_exit_fence_gap.jpg`.
10. **[P2] Nights are lifted by the bodycam auto-gain.** At full dark the exposure rises by about 0.6 and the grain
    grows, so nights stay readable without goggles. In Tarkov, night raids are very hard to see in without night vision
    ([Turtle Beach](https://www.turtlebeach.com/blog/escape-from-tarkov-day-versus-night-raids-explained)). This lowers
    the value of goggles and lights. It comes from the bodycam choice, so it is a tuning question, not a bug.
    *Evidence:* `src/client/Controllers/Atmos.luau:100`; `src/client/Controllers/Post.luau:282`;
    `docs/look/evidence/L06_night_flicker_lamp.jpg`.
11. **[P2] The lighting model is unknown.** Roblox has deprecated `Lighting.Technology` and now uses `LightingStyle` and
    `PrioritizeLightingQuality`. The code sets neither and the tools could not read `Technology`, so nobody knows which
    lighting the place uses, whether the shadow-casting lamps (6 in Relay 7, 12 in the dorms) cast shadows on phones, or
    which setting the screenshots used.
    *Evidence:* `src/server/Services/World.luau:623-660`; `KNOWN_ISSUES.md:230`;
    [Roblox Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting),
    [Roblox lighting guide](https://create.roblox.com/docs/environment/lighting).
12. **[P2] The sky is Roblox's default.** The server deletes any Sky object and makes none, so clear raids show the
    default saturated blue sky with cartoon clouds rather than Tarkov's hazy skies.
    *Evidence:* `src/server/Services/World.luau:635-639`; `docs/look/evidence/L01_south_yard_high.jpg`,
    `docs/maps/evidence/M08_meridian_facade.jpg`.
13. **[P2] Raid time and weather work differently from Tarkov.** The server rolls one of eight start times, while
    Tarkov players choose the time ([Turtle Beach](https://www.turtlebeach.com/blog/escape-from-tarkov-day-versus-night-raids-explained)).
    Weather is one of four states for the whole raid, foliage does not move in the wind, and rain streaks, splashes and
    lens drops have never been checked in a rainy raid.
    *Evidence:* `src/shared/Env.luau:10-15` and `:26-32`; `KNOWN_ISSUES.md` items 25 and 26; `docs/design/EFT_PARITY.md:329`.
14. **[P2] Layouts are close at map scale but rough below it.** Border Yard uses outlines traced before Tarkov's 0.16
    Customs rework; the three buildings Tarkov opened in 0.16 have no reference interiors; exits sit within 5 to 10 m;
    the ground is a smooth blend, so peaks are lower. Meridian's ponds and canal are dry ditches and its outdoor
    buildings are single rooms. Both maps end in tall terraced rock walls, not Tarkov's fenced and wooded edges.
    *Evidence:* `docs/maps/reference/CUSTOMS_REFERENCE.md:21-27` and `:461-463`; `docs/design/EFT_PARITY.md:275-279`;
    `docs/maps/BORDER_YARD.md:25`; `docs/maps/evidence/MM_road_interchange_after.jpg`, `BY_exit_army_roadblock.jpg`.
15. **[P2] Outdoor and indoor density is low.** Border's whole outdoor dressing budget is 2,450 parts for half a square
    kilometre, with at most 700 trees. Shops get about ten props each. Dorm beds and wardrobes are kit meshes stretched to
    size, and 109 of 397 tried props were dropped for overlap in the offline run. Most industrial-side containers are
    plain boxes.
    *Evidence:* `docs/maps/BORDER_YARD.md:73-74`, `:317-319`, `:516`, `:573-574`; `docs/design/EFT_PARITY.md:283-284`;
    `src/server/Services/World.luau:707-725`; `docs/maps/evidence/BY_road_main0_after.jpg`, `MM_exit_shelter.jpg`.
16. **[P2] There is no current art bible.** The kit's art brief asks for "low-fidelity observational realism", "chunky
    deliberate polygon silhouettes" and "not expensive dynamic PBR", while the rule since 2026-10-31 asks for Tarkov
    parity. Assets now aim at different targets: PBR-tiled walls, flat saturated props, block characters.
    *Evidence:* `docs/kit/REFERENCES/VISUAL_ART_DIRECTION.md:1-10`; `docs/maps/evidence/M01_meridian_atrium.jpg`, `M04_meridian_supermarket.jpg`.
17. **[P2] Five floor and ceiling materials exist only in the open Studio session.** Terrazzo, floor tiles, ceiling
    tiles, vinyl and carpet were added to the place by hand because Rojo could not create them. If the place is not
    saved, the mall falls back to plain materials.
    *Evidence:* `KNOWN_ISSUES.md` item 45.
18. **[P3] 59 kit props have off-centre origins** and stand up to a stud from where the builders aimed them.
    *Evidence:* `KNOWN_ISSUES.md` item 69.
19. **[P3] Stocked shelving is heavy.** A stocked gondola is 7,326 triangles and the supermarket view about 114,000.
    *Evidence:* `KNOWN_ISSUES.md` item 46; `assets/exports/ZR_MallKitB.meta.json`.
20. **[P3] Character cloth looks coarse up close.** The body and soft gear use Roblox's stock Fabric over vertex colours.
    *Evidence:* `KNOWN_ISSUES.md` item 14.
21. **[P3] Meridian's deep halls are very dark even with the power on** (149 lamps at 0.8 brightness under 27-stud ceilings).
    *Evidence:* `KNOWN_ISSUES.md` item 66.
22. **[P3] Some docs no longer match the code.** `DEVELOPMENT_STATUS.md:5` still calls Border Yard "designed".
    `docs/look/LOOK_2_0.md:17-20` says the wall-finish textures are empty, but `src/materials/ZR_WallpaperA.model.json:5-7`
    has them. `ASSET_MANIFEST.md:86` lists weapons as part-built (the part spec is now only a loading fallback,
    `WeaponModels.luau:213`). `EFT_PARITY.md:205-207` says the ambience sounds are not uploaded, but `Sounds.luau:21`
    points to an upload, and `KNOWN_ISSUES.md` item 73 says it read as 0.0 s long on 2026-11-02 (audio area).

## Gaps vs EFT

| EFT feature | Ours | Gap |
|---|---|---|
| 13 locations, End of the Line in December 2026 | 2 Tarkov layouts, 2 original maps in the vote, 1 parked | 11 locations missing |
| Customs layout | Border Yard at real scale | Close; pre-0.16 outlines, no 0.16 interiors, our own interiors |
| Interchange layout | Meridian Mall at real scale | Close; recipe shops, dry ponds, single-room outbuildings |
| Factory | Smelter, an original 82 x 63 m compound, 15 min raids | Layout departure |
| Woods | Pinewatch, an original 164 m forest, parked | Layout departure |
| Fully modelled buildings with trims | Part walls with cut holes, slabs | Partial |
| Dense, lived-in interiors | About 10 props per shop, stretched furniture, box containers | Partial |
| Map edges of fences, forest and terrain | Tall terraced rock walls | Partial |
| Vegetation that moves in the wind (improved again with Unity 6, per the roadmap) | See-through cards, no sway | Partial |
| Players choose the raid time; 7x clock | Random start time from 8 slots; 7x clock | Partial |
| Weather states and seasons ([seasons since 0.14.5](https://insider-gaming.com/new-tarkov-update-btr-seasons/)) | 4 states per raid, seasons from the calendar | Close; no mid-raid change (unverified for Tarkov) |
| Dark nights where goggles and lights matter | Bodycam auto-gain lifts nights | Departure (bodycam choice) |
| Realistic skies | Roblox default sky with a cloud layer | Partial |
| Post effects: ambient occlusion, reflections, chromatic aberration, noise, grading presets (`EFT_PARITY.md` §5) | Grade, bloom, sun rays, depth of field, grain, vignette, edge haze | Partial (part of it is a Roblox limit) |
| Realistic human characters | Block body, dot-eye faces, 1.35x guns in third person | Departure |
| Detailed gear models | 49 rigid meshes, about 400 triangles each, vertex colour | Partial |
| Detailed first-person guns with textures | 6 guns, 187 meshes, vertex colour, 128 to 1,544 triangles per part | Partial |
| Detailed items and inspect models | 95 low-poly models; 3D inspect only for guns | Partial |
| Hand-made first-person reloads, checks and inspects | Code-made poses; no bolt or charging-handle motion | Partial |
| Natural third-person movement | Procedural poses on a block rig | Partial |
| Muzzle flash and smoke by muzzle device (detail unverified) | Tiny glowing ball, no smoke | Gap |
| Impact effects by surface | One grey puff and a black disc for every surface | Gap |
| Blood on hits (unverified from a fetched source) | None | Gap |
| Ejected casings (unverified from a fetched source) | None | Gap |
| Explosions and smoke grenades | Flash, fireball, smoke, debris, scorch | Close |
| Night vision and thermal | Four tubes and thermal, drawn on characters | Close |
| Breakable glass | 594 panes, shards, sound | Close |
| No exit markers in the world | Glowing lamp, sign and painted zone at every exit | Departure |

## Decisions

### art-1. What happens to the three maps that are not Tarkov layouts?

Quay 7 and Smelter are in the vote and Pinewatch is parked, but none copies a Tarkov map. Factory (142 x 132 m) is the
closest match for Smelter and Woods (1.4 x 1.36 km) for Pinewatch. Quay 7 has no match, and tests and the Foreman boss
use it.

| Option | What would be built or changed | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. Re-base on Tarkov | Rebuild Smelter on Factory's layout and Pinewatch on Woods' layout at real scale, keeping their names and kits. Take Quay 7 out of the vote and keep it as the test map. | L | med | exact |
| b. Keep as originals | Keep all three as extra maps beside the Tarkov copies. | S | none | departure |
| c. Retire now | Take Quay 7 and Smelter out of the vote today, leaving Border Yard and Meridian Mall until replacements exist. | S | none | partial |

**Recommended: a.** Smelter and Pinewatch become Factory and Woods without losing their work, and Quay 7 stays useful for tests.

### art-2. Which missing Tarkov maps come next, and in what order?

11 locations are missing, from 105 x 113 m (Labyrinth) to 1.06 x 1.72 km (Lighthouse). Border Yard and Meridian Mall
each took about a day for a first pass, but each streams 16,800 to 18,600 parts, and no phone has been measured.

| Option | What would be built or changed | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. Small maps first | Factory, Ground Zero, The Lab, then Reserve. | L | low | close |
| b. Big outdoor maps first | Woods, Shoreline, Lighthouse, Reserve, then Streets. | L | high | close |
| c. Mixed sizes | Factory, Woods, Reserve, Shoreline, Streets, Lighthouse, The Lab, Ground Zero; the small-group locations (Labyrinth, Terminal, Icebreaker) last. | L | med | close |
| d. Performance base first | No new map until Border Yard and Meridian Mall hold 30 fps on a measured low-end phone (merged wall meshes, fewer decals, a smaller streaming radius), then order c. | M then L | low | close |

**Recommended: d.** Two real-scale maps already exceed the draw budget unmeasured; each new big map multiplies the risk.

### art-3. Should characters keep the block body or move to human proportions?

The block body is 1.37 m across the arms with a 0.40 m head, so hitboxes are far larger than Tarkov's and third-person
guns are drawn 1.35 times real size. The owner chose it on 2026-10-28; the parity rule came on 2026-10-31 and does not
list it as an exception. The gear (49 meshes), the first-person arms and the animation code are fitted to it.

| Option | What would be built or changed | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. Keep the block body | No change. | S | none | departure |
| b. Human-proportioned rigid body | Keep the R15 parts, joints and procedural animation, but resize them to real proportions (head about 0.23 m tall, shoulders about 0.5 m), give the head a face or balaclava texture instead of dot eyes, refit the gear meshes, and draw guns at real size. Needs the owner's upload session. | M | none | close |
| c. Realistic skinned character | A textured skinned body with authored animations through Roblox's Animator, replacing the procedural third-person poses, and gear refitted to it. | L | med | close |

**Recommended: b.** Real-size hitboxes and silhouettes at moderate cost, keeping the working rig, gear system and animation code.

### art-4. Should hero assets get real PBR textures, or stay vertex-coloured?

Vertex colours keep memory tiny but cannot show labels, print, scratches or fine bevels; the aimed first-person gun looks
flat. Roblox supports PBR maps up to 1024 x 1024 per model (colour, normal, roughness, metal), needs one set of UVs, and
loads lower-quality textures first on weaker devices.

| Option | What would be built or changed | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. Stay vertex-coloured | Add shape detail only: bevels, screws, cut-outs, more triangles on guns and gear. | M | low | partial |
| b. Hybrid | Unwrap and bake 512 to 1024 PBR sets in Blender for first-person guns and attachments, worn gear and items seen up close; keep vertex colours for bulk props and buildings. | M | low | close |
| c. PBR everywhere | Shared texture sheets for every kit prop and building module as well. | L | med | close |

**Recommended: b.** The player looks at the gun all raid; texturing hero assets gives most of the gain for a small memory cost.

### art-5. How should buildings and interiors be raised toward Tarkov's level?

Buildings are part-built shells with cut holes and few trims; shops hold about ten props; Border streams about 18,600
parts near the player, the main phone risk.

| Option | What would be built or changed | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. Trim pass | Add frames, sills, door casings, skirting, cornices, gutters and balconies to the part-built shells through MapKit. | M | med | partial |
| b. Modular Blender kit | Wall, window, door, stair and facade modules as merged meshes with baked shading, placed by the builders instead of loose parts. | L | low | close |
| c. Kit plus hand-dressed rooms | Option b, plus hand placement of the named loot rooms and landmarks (dorm Room 314, the dorm halls, IRONSIGHT, the Bastion) matched to Tarkov screenshots. | L | med | close |

**Recommended: b.** It is the only option that improves the look and cuts the part count; key rooms can be dressed later.

### art-6. How should first-person weapon animations be made?

Reloads, checks and the inspect are code-made poses with missing steps (no bolt release, no quick reload, the magazine
check does not show the magazine). Any arm animation will need redoing if the body changes (art-3).

| Option | What would be built or changed | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. Extend the code-made poses | Add the bolt release or charging handle on an empty reload, a quick reload that drops the magazine, a magazine check that brings it into view, and a chamber-check pull. | M | none | partial |
| b. Keyframed per weapon class | Author first-person animations in Blender for AR, AK, SMG, pump, bolt and pistol, played as Roblox animation tracks on the viewmodel. | L | low | close |
| c. Keep as is | No change. | S | none | partial |

**Recommended: a.** Visible gains now, without building keyframed arms before the body decision.

### art-7. Should hits show realistic blood?

There is no blood: body hits make a dark grey puff. Roblox allows "light realistic blood" only under the Moderate
maturity label and "heavy realistic blood" only under Restricted
([Roblox maturity labels](https://en.help.roblox.com/hc/en-us/articles/8862768451604-Content-Maturity-Labels)).
Publishing is the owner's decision.

| Option | What would be built or changed | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. Light realistic blood | Red hit puffs and small blood marks on nearby walls, floors and bodies; set Moderate in the maturity questionnaire. | S | low | close |
| b. No realistic blood | Keep the dark puff; the game stays eligible for lower labels. | S | none | departure |
| c. Heavy realistic blood | Larger sprays and pools; the Restricted label. | S | low | close |

**Recommended: a.** It gives Tarkov's hit feedback without the most restrictive label.

### art-8. Should the game keep readability aids that Tarkov does not have?

Every exit has a glowing lamp, a sign and a painted zone, and the bodycam auto-gain lifts nights so they read without
goggles. Tarkov marks no exits and its nights are dark. Several exits already have landmarks of their own (tunnel
portals, a roadblock, a boat, a car).

| Option | What would be built or changed | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. Tarkov-hard | Remove the exit lamps, signs and paint, give each exit a fitting landmark, and cut the night lift to a trace so goggles and lights are needed. | S | none | exact |
| b. Middle | Remove the exit lamps, signs and paint; halve the night lift. | S | none | close |
| c. Keep both | No change. | S | none | departure |

**Recommended: b.** It matches Tarkov at the exits and keeps the bodycam's character at night without making goggles pointless.

## Quick wins

No decision needed. Each is small and safe.

1. **Set the lighting model.** In Studio, set `Lighting.LightingStyle` and `PrioritizeLightingQuality` on purpose, write
   the choice into `docs/look/`, and check in the device emulator that the shadow-casting lamps still work.
2. **An original hazy sky.** Add a skybox set of our own (clear, overcast, night) that `Atmos.luau` switches with the
   weather, keeping the cloud layer.
3. **A real muzzle flash.** Two or three frames of crossed flash cards sized by the muzzle device (none behind a
   suppressor), a brief smoke wisp, and a first-person flash big enough to see (`Effects.luau:380-390`, `Weapon.luau:787`).
4. **Impacts by surface.** Use the existing surface lookup (`Effects.luau:296`) to pick sparks (metal), splinters (wood),
   dust (concrete, plaster), dirt (ground) and a splash (water), and replace the black disc with the bullet-hole decals
   already in `Wear.luau`.
5. **Ejected casings** in first person and for nearby shooters, client-only, pooled and capped at about 20.
6. **A colour pass on props.** Pull saturated shop goods and prop colours toward the palette (sun-faded, dusty), with a
   grime gradient (`assets/blender_scripts/build_mall_kit_b.py`).
7. **Fewer wear-decal draw calls.** One wear strip per facade instead of one decal per wall part (`KNOWN_ISSUES.md` item 67).
8. **A lower-poly product set** for the stocked shelves (`KNOWN_ISSUES.md` item 46).
9. **Centre the 59 off-centre kit origins**, one builder at a time (`KNOWN_ISSUES.md` item 69).
10. **Owner: save the place** so the five Studio-only floor and ceiling materials are kept (`KNOWN_ISSUES.md` item 45).
11. **Fix the docs** listed in finding 22 and the VFX row of `EFT_PARITY.md` §6, and log this audit's art gaps in
    `docs/design/EFT_PARITY.md` (project rule 2).
12. **Check rain** streaks, splashes and lens drops in a rainy raid (`KNOWN_ISSUES.md` item 25).
13. **After the decisions, write a one-page art bible**: palette, texture density, triangle budgets per asset class, and
    reference boards per map.

## Sources

Tarkov (fetched 2026-11-07 unless noted):
- TarkovForge, maps (13 locations, players, raid times): https://tarkovforge.com/maps
- eft-ammo, maps list: https://eft-ammo.com/maps
- tarkov.dev, `src/data/maps.json` (map frames): https://github.com/the-hideout/tarkov-dev/blob/main/src/data/maps.json
- Insider Gaming, Terminal entered: https://insider-gaming.com/escape-from-tarkov-terminal-map-entered/
- Insider Gaming, 1.0.5 patch notes (Icebreaker): https://insider-gaming.com/escape-from-tarkov-1-5-update-patch-notes-icebreaker/
- Vandal, roadmap to the end of 2026 (Lighthouse rework, End of the Line, Unity 6, vegetation, magazine-loading animations): https://vandal.elespanol.com/noticia/2026240017/escape-from-tarkov-detalla-su-hoja-de-ruta-hasta-final-de-2026-nuevo-mapa-jefe-armas-y-unity-6/
- AltChar, maps planned for 2026: https://www.altchar.com/game-news/escape-from-tarkov-outlines-major-new-maps-mechanics-and-gear-planned-for-2026-a3xuK4o0BJLL
- gaming-st.com, Unity 6 move delayed to 1.3.5.0: https://gaming-st.com/news/tarkov-unity6-migration-delayed-1350/
- CPG, the Labyrinth stays after its event: https://consolepcgaming.com/escape-from-tarkovs-labyrinth-map-will-become-permanent-feature
- AltChar, the Labyrinth arrives with 0.16.5.0 (search-result title, not fetched): https://www.altchar.com/game-news/escape-from-tarkov-the-labyrinth-event-arrives-with-patch-0.16.5.0-auImi2P5thFm
- GGRecon, how to extract (no markers in the world): https://www.ggrecon.com/guides/escape-from-tarkov-how-to-extract/
- Turtle Beach, day and night raids (players choose the time; dark nights): https://www.turtlebeach.com/blog/escape-from-tarkov-day-versus-night-raids-explained
- Insider Gaming, 0.14.5 seasons: https://insider-gaming.com/new-tarkov-update-btr-seasons/
- The 0.16 Customs rework details come from the project's own reference, `docs/maps/reference/CUSTOMS_REFERENCE.md` §11 and §13.

Unverified (no fetched source): Tarkov's blood effects, ejected casings, muzzle-flash differences by muzzle device,
weather changing during a raid, and hand-animated reloads per weapon.

Roblox:
- Mesh specifications (20,000 triangles a mesh, 4 bone influences): https://create.roblox.com/docs/art/modeling/specifications
- Texture specifications (PBR maps, 1024 x 1024, one UV set, lower quality first on weak devices): https://create.roblox.com/docs/art/modeling/texture-specifications
- Lighting class (`Technology` deprecated; `LightingStyle`, `PrioritizeLightingQuality`): https://create.roblox.com/docs/reference/engine/classes/Lighting
- Lighting guide: https://create.roblox.com/docs/environment/lighting
- Content maturity labels (blood): https://en.help.roblox.com/hc/en-us/articles/8862768451604-Content-Maturity-Labels
