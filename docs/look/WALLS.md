# Wall finishes: more kinds of wall (2026-11-01)

Owner request (2026-11-01): "the walls look repetitive and fake ... not higher resolution, but more variants, other types
of walls, as in Escape from Tarkov". **Status: written and passed through `tools/luau_check.py` (structure only). Nothing
here has been run in Studio, on a phone or on a console, and no frame rate was measured. The seven textures were made and
checked for seams offline (contact sheet `assets/textures/out/walls_preview.png`) but are not uploaded: their
`MaterialVariant` slots are empty, so no wall looks different until the main session uploads them and fills in the ids.**

## 1. Why the walls looked alike

`World.applyWear` gave every Plaster part `ZR_PlasterPeel`, and every concrete wall `ZR_ConcreteWorn` or
`ZR_ConcretePanel`. Every room therefore wore one texture at one scale. Resolution was never the problem (the textures
are 1024 px); the number of kinds was. So: seven new kinds, picked by room, not a sharper version of the old ones.

## 2. Tarkov reference (grade C: inferred)

No source read for this task lists the wall finishes of Tarkov's maps (a fetch of one guide page returned only its home
page). The finishes are inferred from period interiors (post-Soviet dormitories, depots and workshops: a gloss-painted
lower band under a lime-washed upper wall in corridors and stairwells, wallpaper in lived-in rooms, glazed tile in
washrooms and kitchens, brick in workshop halls, wood panelling in small offices) and from what Tarkov's interiors are
generally described as (peeling paint over plaster, patterned wallpaper, tile, bare brick). No page was read that states
this for a particular room, and none of it was re-read in this session. The mix, the weights and the hues below are
our estimate.

## 3. The seven finishes

All are original procedural textures (`assets/textures/gen_materials.py`): near-neutral colour so `Part.Color` tints
them, an OpenGL normal map and a roughness map. Studs per tile use 3.125 studs = 1 m.

| Variant | Base material, pattern | Studs per tile | Look | Goes on |
|---|---|---|---|---|
| `ZR_PaintGloss` | Plaster, organic | 4.7 (1.5 m) | oil paint, scuffed and dirty at the foot, chips | corridor and stairwell bands, 10% of plain walls |
| `ZR_Whitewash` | Plaster, organic | 10 (3.2 m) | chalky lime wash, water tide marks, chips | upper corridor walls, stairwells, huts, 35% of plain walls |
| `ZR_WallpaperA` | Plaster, regular | 6.25 (2 m) | floral damask, seams, peeled strips, stains | lived dorm rooms, offices, 15% of plain walls |
| `ZR_WallpaperB` | Plaster, regular | 6.25 (2 m) | geometric lattice over stripes, seams, stains | lived dorm rooms, offices, 15% of plain walls |
| `ZR_WallTiles` | CeramicTiles, regular | 7.5 (2.4 m) | glazed wall tiles, grout, missing and cracked ones | washrooms and kitchens |
| `ZR_BrickWall` | Brick, regular | 6.5 | brick courses, mortar, tone variation | brick halls (Store 4, Store 17), every thin brick wall |
| `ZR_WoodPanel` | WoodPlanks, regular | 5.0 | vertical panelling, grain, varnish wear | offices, guard rooms |

Each is a Rojo model `src/materials/<Name>.model.json` with empty `ColorMap`, `NormalMap` and `RoughnessMap`. The code
skips a variant while its `ColorMap` is empty, so the map keeps its old look until the ids are filled in.

## 4. Rules

**Which finish a part gets** (`World.applyWear`, first match wins):

1. The `Wear` attribute (a variant name; `""` = the plain material), as before.
2. The `Finish` attribute: on the part (any shape or material; `""` = no finish), or on the nearest Model above it, which
   only wall pieces take (upright thin boxes, lintels and jambs included; never `NoDetail` furniture or doors). A Model
   `Finish` reaches Plaster always, and Concrete or Brick only when the finish is brick or one of the two concrete
   variants. The part takes the variant's base material.
3. No `Finish` anywhere: a Plaster wall piece takes one from the weighted list, a Brick wall piece becomes
   `ZR_BrickWall` (this is new, on every map).
4. The shape rules of before (slabs, panels, worn concrete, asphalt, metal, planks, plaster peel).

**The weighted list** (stable hash of the nearest Model's full name plus the floor band `floor(y / 11)`, so a room
keeps its look on every server): whitewash 35, wallpaper A 15, wallpaper B 15, plaster peel 25, gloss 10. Outside
(thick) walls, coloured walls and `Tint = false` parts never take wallpaper, and thick gloss becomes whitewash.

**Colour.** Gloss, whitewash and wallpaper take one hue per room from: pale green, pale blue, beige, cream, dusty pink,
ochre, light grey (same hash), at the brightness the builder gave the wall (clamped 0.4 to 0.75). Wood and brick have
their own lists. Only parts in the builder's plain plaster colour are re-tinted (brick and wood: parts whose material
changes), or `Tint = true` on the part or its Model; `Tint = false` keeps the colour.

**Border dorms** (`src/server/Maps/Border/Living.luau`, BLOCK A and BLOCK B):

* Corridors are two-tone, as in the period buildings: whitewash above, a gloss band 4.7 studs (1.5 m) high below, with a
  darker line 0.2 high on top. The band is thin skins on the wall face, cut at every doorway and opening. One colour per
  floor in a block: A is green, blue-grey, brown; B is ochre, green.
* Stairwells: whitewash; the stairwell face of each divider gets the same band.
* Lived rooms: wallpaper A 35%, B 30%, whitewash 35% by the room's seed, hue by the room's name. Bare rooms: plaster
  peel. Washrooms and kitchens: glazed tile up to 4.4 studs (1.4 m; 2.9 under a window) on the side walls and the far
  wall; the washrooms already had the panels, the kitchens got three.
* A divider between two rooms that look different is two leaves of half the thickness (collision is unchanged), one per
  room, up to 125 in all; past that one wall in the worse finish (peel before whitewash before wallpaper B before A).

**Border Works** (`Works.luau`, finishes only, no new parts; a room gets a sub-Model `Room N`):

| Place | Finish |
|---|---|
| Store 4 and Store 17 halls | `ZR_BrickWall` on the building |
| The Bastion | `ZR_Whitewash` on the building (never wallpaper) |
| Store 3 north-east office, Store 7 locked office, Store 17 foreman's office, Red Stores office 2, The Frame foreman's office | `ZR_WoodPanel` |
| Store 4 shift office, the Depot inspectors' office, Old Works site office | `ZR_WallpaperB` |
| Store 7 mezzanine offices, Red Stores office 1 | `ZR_WallpaperA` |
| Pump platform control hut | `ZR_Whitewash` |

## 5. Cost

* Textures: 21 PNGs (7 colour 1024 x 1024, 7 normal and 7 roughness 512 x 512), 11 MB on disk. Memory on a device: not
  measured.
* Parts: Works adds none (11 sub-Models, one per finished room). The dorms add at most 488 parts (corridor skins and
  lines 340, stairwell 20, extra divider leaves 125, kitchen tiles 3). The skins and lines have no collision, no ray hits
  and no shadow; the build log prints the real number (`[ZR] Border dorm walls: ... parts added`). Skins are 0.03 thick
  (lines 0.04), under the 0.055 at which the detail layer floats its wall decals, so decals stay in front.
* Frame rate: not measured. Seven more materials are in view on the dorm walls. POTATO removes every
  `MaterialVariant` (`Detail.luau`), so there the walls fall back to plain Plaster, Brick, WoodPlanks and CeramicTiles;
  the bands keep their colour.
* The detail layer peels fewer patches over the new finishes (`PEEL_ODDS` in `DetailPlan.luau`: gloss 12%, whitewash 22%,
  wallpaper 16%, the rest 40%) because their textures carry wear of their own.
* Tests: `LookTests` L04 (13 checks): the tables, no part in a variant without textures, known `Finish` names, skins that
  cannot be touched or shot, and `World.applyWear` on 24 throwaway walls. The build log line `[ZR] Wall finishes:` counts
  the parts per finish.

## 6. To do before it shows

1. Upload the three PNGs of each variant (`assets/textures/out/materials/ZR_MAT_<Name>_{Color,Normal,Rough}.png`).
2. Paste the ids into `src/materials/<Name>.model.json` (`ColorMap`, `NormalMap`, `RoughnessMap`), then sync.
3. Run `ZR_Dev:Invoke("tests")` (L04) and look at the build log lines above; walk both dorm blocks at HIGH and POTATO.

## Gaps (copy to docs/design/EFT_PARITY.md)

* **Reference is grade C.** No Tarkov wall-finish source was read; the finishes, weights (35/15/15/25/10) and hues are
  inferred. To close it: read interior screenshots of the Customs dormitory, Interchange and Factory and set the mix
  per map.
* **Not uploaded, not run.** The seven variants have empty maps, so nothing changes on screen yet. No Studio run, no phone
  or console check, no frame rate. Roblox's texture origin on a part is not known offline: scuffs near the foot of the gloss
  and the seams of the wallpaper may not meet the floor or the band edge, and every wall piece is textured on its own, so
  a pattern does not continue across a door.
* **Pattern repeat.** Wallpaper repeats every 2 m with the same stains and a peeled strip; on a long wall this will
  show.
* **Only Border's dorms and Works use the new finishes by room.** Quay 7 and the other maps get the weighted pick and the
  brick rule only; interiors there have no per-room finish.
* **Stairwell bands are flat** (they do not follow the flights), and stair sides are not banded.
* **Skins float 0.015 off the wall.** Depth precision at long range could make them flicker; if it does, raise the offset.
* **Not built** (no source read for any of them): stencilled numbers and signs, glazed brick, rendered concrete, plywood,
  tiled floors. Each would be one more variant.
