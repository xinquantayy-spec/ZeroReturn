# Interchange layout reference for the "Meridian Mall" rebuild

Escape from Tarkov Interchange, state of 2026-11-01: the expanded 1.0 map (2025-11) plus patches up to 1.3.0.0 (2026-10-29). Companion data with identical numbers: `interchange_layout.json`. Preview render of that JSON (outside plus the three mall levels, north up, labelled): `interchange_layout_preview.png`.

**No live API data**: api.tarkov.dev and assets.tarkov.dev return HTTP 403 through the sandbox proxy, so there is no `interchange_api.json`. Extract positions come from the re3mr community infographic (2026-01), rules and spawn points from the SPT server database (pre-1.0 era), footprints from the tarkov-dev-svg-maps SVG (see section 1).

**What a builder must know first**

- Playable area 938 x 838 m (0.68 km2), x -472..466, z -433..405, inside a 1031 x 868 m 2D frame. The long axis is east-west; the mall sits in the middle, the highway (two carriageways, x -197..-169) runs N-S on its west side, the minefield band is the west edge and the sniper band the east edge.
- Mall footprint 297 x 520 m (x -17.9..279.5, z -307.1..212.8, 140,962 m2 over 22 vertices). Three levels: **L0 garage** floor y 21.4 (same height as the outdoor ground), **L1 main floor** y 27.1, **L2 upper floor** y 36.6; floor-to-floor 5.7 m and 9.5 m. The L2 floor exists only over the central block (x -25..156, z -170..78, 31,619 m2); the IDEA, Goshan and OLI halls and the bistro have no upper floor and are single tall volumes.
- Layout in one line (north up): IDEA hall + bistro (north wing), a central block of about 30 small stores around an E-W concourse (z -47) with three escalator pairs, Goshan hall (east), OLI hall (south wing); two 18 m octagonal dome atria at (85.5,-112.9) and (85.4,19.6); 8 sawtooth dock bays on each of the IDEA and OLI east walls; the L1 east side is a dock terrace at y 27.1 reached by four outdoor ramps from the ground apron.
- Power switch in the Power Station main building (288,-346) at the north-east; it lights the mall and unlocks the Kiba store keys, the Saferoom exfil, Object-14, the Terragroup container and the ULTRA medical room.
- 7 extracts (Railway NW, Emercom SE, Power Station V-Ex NE, Saferoom in the garage, Scav Camp co-op in the garage tunnel, Path to River flare exit far west, Hole in the Fence) and 2 active transits (Streets at the highway north end, Customs at its south end; SPT also lists one inactive event transit). Boss: Killa; Tagilla is also listed in the 2026 sources (section 7.4).
- Spawns (SPT, old area only): 125 PMC points in 25 sites of 5 (MallNW 65, MallSE 60), 35 scav, 22 boss-capable, 24 AI-PMC (PvE only) and 46 co-op start points; the 2026 plan shows 25 PMC rings that mostly differ from the SPT sites (section 7.1). Keys: 16 (section 8); the SPT loot data draws 269-325 grouped containers per raid, with no positions (section 8.4).
- The mall interior in the SVG is geometrically identical in the 2024-06-19 and 2026-01-09 file versions; the 1.0 expansion added the outer ring (playable area grew from 468,825 to 680,115 m2, section 2). The SPT spawn data covers only the old area.
- Not in any source (grade D): ceiling heights, slab thickness, roof height, garage pillar grid, interior of the Saferoom and Object-14 rooms, wall and fence heights, terrain heightmap.

## 0. Frame and conventions (one frame everywhere)

- Units metres. **x = east (+), z = south (+)**, so north is -z, the top of the 2D map. y = game height (flat outdoor ground y 21.4; mall L1 y 27.1; L2 y 36.6). Origin = centre of the tarkov.dev 2D bounds (game x 82.5, z -8). 2D frame: x -515.5..515.5, z -434..434 (1031 x 868 m).
- game -> frame: `x_e = 82.5 - x_game`, `z_s = z_game + 8`, y unchanged (tarkov.dev rotates the game axes by 180 degrees: `coordinateRotation` 180). frame -> game: `x_game = 82.5 - x_e`, `z_game = z_s - 8`. Example: tarkov.dev label "Garage A" at game (33,-222) = frame (49.5,-214); label "Power Station" at game (-186.5,-319) = frame (269,-311).
- tarkov.dev coordinates (`src/data/maps.json`): label `position` = [x_game, z_game]; layer `extents` boxes = [[x_game, z_game], [x_game, z_game]] corners; `bounds` [[598,-442],[-433,426]] = west/north corner and east/south corner in game x, z (frame x 515.5 -> -515.5, z -434 -> 434 after the formula above); its map code addresses markers as [z, x] (same code as Customs). So any position copied from tarkov.dev goes through the game -> frame formula.
- SVG -> frame: `x_e = u*1031/1127.6852 - 515.5`, `z_s = v*868/947.02582 - 434` (Interchange.svg viewBox 1127.6852 x 947.02582; 1 unit = 0.914 m in x, 0.917 m in z).
- re3mr infographic pixels -> frame (image `interchange-3d.jpg`, 4800 x 2700 px): aerial view `x_e = -30 + (px - 1226)/2.64`, `z_s = -312 + (py - 683)/2.64` (checked against SVG roads, rails and fences to 1-3 m); the floor-plan panels in the same image use 2.56 px per metre (L2 panel 2.57) with the same offsets: `x_e = -30 + (px - ox)/s`, `z_s = -312 + (py - oy)/s`, (ox, oy) = L0 (2696,698), L1 (3488,700), L2 (4292,692).
- Footprints: `cx, cz` centre; `w` = long side, `d` = short side; `rot` = angle of the w axis from +x (east) toward +z (south) = clockwise on the north-up map, range -90..90 (so +-90 means the long side runs N-S). Axis-aligned rectangles in the mall tables are given by `x0..x1, z0..z1` as well.
- Roblox: `CFrame.new(cx, y, cz) * CFrame.Angles(0, -math.rad(rot), 0)`, Size = (w, height, d); Roblox X = x_e, Z = z_s, Y = y (north = -Z = Roblox forward). Spawn facing in the JSON: 0 = east, 90 = south, = Unity yaw + 90.
- Confidence: **A** footprint traced from the SVG with a tarkov.dev label or floor extent within 10 m (+-3-5 m position, +-3 m size); **B** identified by matching extents, SPT spawn points or re3mr icons, or SVG geometry whose meaning is certain but whose position was read from a drawing (+-5-10 m); **C** inferred, hand-read from a plan image, or landmark-based (+-15-30 m); **D** no position source, or a description without a map - do not rely on it.
- Licence/IP note for the parent project: `Interchange.svg` is by Shebuka, tarkov-dev-svg-maps, CC BY-NC-SA 4.0 (non-commercial, share-alike, credit the-hideout/tarkov-dev-svg-maps); the re3mr infographic states in its own footer "Map made by re3mr.com" (tarkov.dev links the author as https://reemr.se), credits the EFT Fandom wiki for quest and area information and Battlestate Games for the exterior terrain mesh, and is licensed CC BY-NC-SA 4.0; only positions were read from it and none of its pixels are in the committed files (the preview PNG is drawn from the JSON alone). Project rule 1 lists "map layouts", names, art and icons among the things that must be original. This reference copies the EFT layout because the task asked for it - **decide before shipping**. Store names, logos, sign texts and boss names in this file are Battlestate's: the Meridian Mall build should use its own names; the `kind` and `sells` columns are what to build from. Road, hut and yard names in sections 3 and 4 are my own descriptors.

## 1. Data lineage and accuracy

| Layer | Source | Vintage | Accuracy |
|---|---|---|---|
| Outdoor footprints: roads, rails, fences, buildings, water, rocks, power lines, Danger bands, Limit lines | tarkov-dev-svg-maps `Interchange.svg` (hand-traced, flattened by my own parser; commit 6bbddad "Interchange update") | 2026-01-09 = expanded 1.0 map | +-3-5 m |
| Mall outline, L0/L1/L2 floor outlines, walls, blocks, pillars, ramp strokes (stairs, escalators, vehicle ramps) | same SVG; groups Floor-1, Floor-2, Garage, Structure, Ramps, Big_Ramps unchanged since 81fa164 (2024-06-19): I compared all 94 + 31 floor sub-paths and the ramps, deviation <= 0.001 SVG units after one shift; the only difference is the 10 m wide ramp stroke at (85.4, 14..26), which moved by up to 2.8 m | 2024-06 geometry, still current per patch notes | +-1-3 m (outline), walls +-1 m |
| Store, room and gallery rectangles on L0, L1, L2 | my hand-read of the re3mr infographic plan panels registered to the SVG floor outline (alignment +-2 m); entrances computed from the SVG free-space mask | 2026-01 plans | L1 +-3-8 m (B), anchors and L2 +-8-15 m (C) |
| 77 labels, layer extents, floor height windows, map bounds | tarkov.dev `src/data/maps.json` (labels 2024-02-17..19, one position edit 2024-03-16, layer box 2024-02-08, bounds commit 5aad245a 2026-02-16) | pre-1.0 labels (name the old points only) | +-2 m |
| Extract icons, 25 PMC spawn rings, AI scav icons, boss icons, stair icons, power-switch text, V-Ex cost | re3mr "Interchange" infographic v0.1 (`interchange-3d.jpg`, tarkov.dev, added 2026-01-07), read manually | 2026-01 | +-3 m (icon), +-6-12 m (use point) |
| Spawn points (252 rows), scav zones and waves, boss rolls, extract rules and timers, raid settings, airdrop | SPT server-csharp `locations/interchange` (HEAD 2026-08-10); exact coordinates, but the old (pre-1.0) map only: 248 of the 252 rows lie inside the 2024 Limit polygon and the other four sit on its west edge (0.2-0.5 m outside) | pre-1.0 era | exact position, rules may differ from live PvP |
| Floor heights | median y of the SPT PMC/scav spawn points inside the mall (L0 21.35-21.57, L1 27.06-27.30, L2 36.58-36.73); tarkov.dev layer windows 25 and 34 | 2020-2026 (stable) | +-0.3 m; ceilings: none |
| Terrain relief | 155 SPT spawn heights outside the mall; no heightmap in any source | pre-1.0 | flat plain +-1 m; lowlands/rises sampled only |
| Rules, names, requirements | wiki (undated), tarkovforge map guide (2026), timesaver (2026-06-13 to 2026-09-09), ggrecon (2022-07-05), progameguides (2023-03-14, 2023-07-01), Prima (2020-01-16 and 1.0 launch article), ingamenews (2025-11), keengamer (2020-03-16), theglobalgaming (2023-10-12), eft-ammo (undated), biligame wiki snapshot (2020-08-29) | 2020-2026 | sources disagree in places (section 10) |
| Keys (16), quests, durability, loot behind the doors | tarkovforge key list and key pages (2026), lfcarry ULTRA key guide, eft-ammo, biligame snapshot (2020-08-29), padlock and key icons of the re3mr plan | 2020-2026 | quests and uses B; only 4 doors have a position (section 8) |
| Static loot containers | SPT `statics.json` and `staticContainers.json` | pre-1.0 era | group sizes exact, no positions, no loose loot (section 8.4) |
| Patch changes | patched.gg pages for 1.0.2.0, 1.0.2.5, 1.0.4.0, 1.0.4.5, 1.0.5.0, 1.0.6.0, 1.1.0.0, 1.2.0.0 and 1.3.0.0; tarkovforge and timesaver 1.2.0.0 articles (2026-10-06 build, 10-09 hotfix); NME (2021-08-26, 2023-04-05); ginx.tv (0.12.4, 2020-03-13) | 2020 to 2026-10-29 | paraphrased, no numbers in the notes (section 9) |

Consequences: (1) The outside is the expanded 1.0 layout and is the best-covered part (SVG 2026-01-09). (2) The mall interior geometry is the 2024-06 SVG, identical in the 2026 file, and agrees with the 2026-01 plans to +-2 m; no patch up to 1.3.0.0 lists a mall layout change. (3) Every one of the 33 L1 and 30 L2 store labels of tarkov.dev (2024-02) finds its shop on the 2026 plans; the plans add only IDEA Bistro, one unlabelled L1 store and the ULTRA med room. (4) The SPT data (spawns, scav zones, boss zones, exit rules) describes the old, smaller map: it has nothing for the new west strip (x < -199) and the new east strip (x > 300). (5) Anything that appears only in 2026 sources (Path to River flare exit, Tagilla, V-Ex 20,000, Scav Camp co-op icon in the garage) has no second source and is graded B-C at best. (6) The SVG draws no doors and no room names; store rectangles and their openings are my reading of the plans.

## 2. Extents and perimeter (playable polygon)

- 2D map frame: x -515.5..515.5, z -434..434 (1031 x 868 m, the tarkov.dev bounds). **Playable polygon** (`boundary.poly`, 56 vertices, simplified at 0.8 m): x -471.6..466.2, z -433..405.2 = 938 x 838 m, area 680,115 m2 (0.68 km2). The long axis is east-west. It is built from the SVG `Limit` polylines (north and south edges) and the inner edges of the two `Danger` bands (west and east edges); the SVG has no wall layer, so the perimeter is the Limit line itself.
- Full outline, clockwise on the north-up map from the north-east corner (all 56 vertices, same order as the JSON): (384,-413) (386,-258) (390,-234) (400,-208) (411,-185) (422,-171) (443,-153) (454,-142) (461,-129) (465,-115) (466,265) (444,272) (375,286) (221,296) (159,305) (118,317) (82,333) (34,360) (-27,397) (-40,403) (-63,405) (-438,405) (-440,309) (-441,300) (-447,287) (-448,280) (-449,243) (-450,230) (-457,204) (-468,169) (-471,157) (-472,146) (-469,104) (-466,92) (-461,83) (-447,75) (-439,65) (-434,50) (-430,23) (-427,-69) (-440,-185) (-442,-220) (-444,-284) (-443,-362) (-441,-409) (-417,-421) (-417,-433) (-363,-433) (-363,-421) (-354,-414) (-226,-413) (-216,-422) (-216,-433) (-143,-433) (-143,-422) (-133,-413)
- Shape: the **north edge** is the straight line z about -413 from x -354 to x 384, with two tabs that reach z -433: x -417..-363 (holds the Railway Exfil) and x -216..-143 (holds the Streets transit, between the two highway carriageways at x -193 and -172); the north-west corner is cut diagonally from (-441,-409) to (-417,-421). The **east edge** starts at (384,-413), runs south-east along the sniper band (390,-234) (411,-185) (443,-153) (465,-115) and then straight south along x 465-466 to the south-east corner (466,265). The **south edge** runs west from there as a gentle arc (444,272) (375,286) (221,296) (118,317) (34,360) (-40,403) and then straight along z 405 to the south-west corner (-438,405). The **west edge** is the inner edge of the minefield band and runs north with a bulge to x -472 at z 146: (-448,280) (-457,204) (-472,146) (-461,83) (-439,65) (-430,23) (-427,-69) (-440,-185) (-444,-284) (-441,-409).
- Limit lines as drawn (`boundary.limit_north`, `limit_south`): north 13 vertices from (-446,-409) via the two tabs to (413,-413); south 12 vertices from (478,261) via (221,296) (34,360) (-63,405) to (-450,405). Both ends continue under the Danger bands. Perimeter outside the polygon: the east-edge road (#44) and the southern road (#43) run along or outside the south-east boundary; two border rails (rail_2, rail_3 at z 411 and 417) lie outside the south edge; two power lines (x -445..-408, 12 towers) run N-S along the inner edge of the minefield band.
- **Minefield (west band, `boundary.minefield_west`)**: SVG `Danger` polygon, about 40 m wide (x -482..-440 in the north, x -510..-470 near z 100-150); re3mr legend: yellow dotted line = MINEFIELD. Outer edge: (-441,-409) (-479,-409) (-482,-313) (-482,-252) (-479,-195) (-466,-73) (-467,10) (-470,39) (-477,65) (-485,75) (-500,84) (-505,95) (-510,146) (-507,169) (-495,204) (-488,230) (-487,243) (-487,280) (-478,309). Inner edge = the west edge of the playable polygon above.
- **Sniper band (east band, `boundary.sniper_east`)**: SVG `Danger` polygon, about 38 m wide along the east edge; re3mr legend: red dotted line = SNIPER, "areas guarded by a deadly sniper". Outer edge: (504,261) (503,-102) (496,-133) (488,-146) (460,-171) (437,-208) (428,-234) (423,-258) (422,-413). The Power Station V-Ex icon lies 28 m inside the inner edge. Neither band has a gradient or a warning strip in the SVG; the band widths are exact, the kill rules are not (section 7).

### Old (pre-1.0) playable area versus now

`interchange_layout.json` `boundary.pre_1_0_polygon` holds the closed `Limit` polygon of the 2024-06-19 SVG, moved into the current frame by the mall floor outline (the two files agree to 0.001 units after one shift of (73.85, -0.92) SVG units). It is the map before the 1.0 expansion.

| polygon | area m2 | extent | notes |
|---|---|---|---|
| pre-1.0 playable polygon (SVG 2024-06-19) | 468,825 | x -446.3..443.3, z -433..405.2 | 66 vertices; west edge = the highway (x -199) for z -115..376, west bulge to x -446 only north of z -115; east edge x 298-338 for z -390..112 |
| playable polygon now (SVG 2026-01-09) | 680,115 | x -471.6..466.2, z -433..405.2 | +211,290 m2 (+45 %) |
| added: west strip beyond the highway | 136,689 | x -472..-199, z -300..406 | minefield band, Path to River exit, west camp, rock fields, west gravel tracks |
| added: east strip and north notch | 75,268 | x 134..467, z -413..274 | sniper band, east-edge road, east truck lot and huts, Power Station north apron, Streets/Customs-side corners |
| removed (in the old polygon, not in the new) | 640 | - | slivers at the polygon edges |

Old polygon outline (coarse, 66 vertices, clockwise from the south-east corner): (443,271) (375,286) (221,296) (159,305) (118,317) (82,333) (34,360) (-27,397) (-40,403) (-63,405) (-210,405) (-210,383) (-204,376) (-199,-115) (-281,-114) (-324,-115) (-324,-136) (-330,-156) (-336,-166) (-383,-201) (-412,-230) (-434,-266) (-445,-306) (-446,-409) (-417,-421) (-417,-433) (-363,-433) (-363,-421) (-354,-414) (-226,-413) (-216,-422) (-216,-433) (-143,-433) (-143,-422) (-133,-413) (136,-415) (136,-395) (133,-375) (134,-350) (168,-350) (182,-336) (233,-336) (233,-376) (237,-378) (247,-390) (322,-388) (338,-372) (338,-238) (309,-238) (298,-228) (298,-168) (300,-163) (301,-108) (297,-107) (298,-40) (307,-34) (307,14) (303,14) (298,16) (298,52) (300,56) (337,56) (337,112) (422,150) (422,175) (443,188)

What this tells a builder: everything that has SPT spawn points, tarkov.dev labels (all 77 lie inside the old polygon), scav zones and boss zones is in the old part; the new strips have only the 2026 icons (11 of the 25 re3mr PMC spawn rings, Path to River, 14 huts, 3 gravel tracks, the camp pad). The old west edge was the highway (per the 2024 Limit polygon): before 1.0 the playable ground ended at the carriageways except in the north (z < -115).

Regions (north-up; coordinates are the frame):

| region | x range | z range | contents |
|---|---|---|---|
| North strip | -440..380 | -433..-300 | Highway Construction (label (-291,-383)), three ponds at (-117,-366) (-83,-372) (-39,-377), Idea Tower (36,-350) with its base hut (36,-364), north sheds (-61,-356) (-81,-342), north service yard (160,-339) 59 x 22 m, the two border tabs (Railway Exfil, Streets transit), the two highway slip roads |
| North-west lowland | -360..-200 | -300..-100 | ponds and swamp (13 water polygons in the whole map; here water_0..4, 10, 11 at x -337..-207, z -226..-117 and a 3,162 m2 pond at (-360,-140)); ground 5-6 m below the plain (y 15-17) |
| Power Station quarter (north-east) | 250..430 | -380..-250 | Power Station main building (288,-346) 26 x 19.6 m with the power switch, 8 sheds, 4 compound pads (x 308..332, z -353..-259) and the west apron (256,-346), V-Ex icon (356,-360), power line east to the map edge |
| North ring and Go Kart | -120..-25 | -325..-190 | Go Kart pad (-75,-245) 87 x 62 m with a 61 x 30 m track outline and the pit building (-59,-209); Go Kart link road z -300 (x -118..-27); north ring road z -325 (x -29..264) |
| West car parks | -123..-30 | -190..215 | five paved lots (lots 2-6, each about 63 m wide at x -107..-44 and 35-110 m long N-S, centres z -147, -68, -19, 53, 162) between the west ring road (x -119) and the west mall road (x -35..-26), plus the Go Kart pad; label "Four Camp" at (-75,-70) in lot 3; 10 stub roads into the lots |
| Mall (centre) | -25..280 | -307..213 | section 4 |
| East service lane and dock aprons | 240..345 | -290..185 | two dock aprons (north-east (258,-241) 101 x 35 m, south-east (258,147) 101 x 35 m) with four vehicle ramps up to the L1 terraces, east service lane pad (298,-12) 54 x 16 m, east truck lot (321,101) 89 x 29 m, Wall Break hut (341,128), label "Ramps" (258,153); fence_17 from (337,-284) to (300,-150) |
| South-east / Emercom | 185..430 | 175..290 | Emercom camp (8 tent or container boxes at x 190..220, z 218..270), Emercom Checkpoint buildings (410,267) (412,274), extract (399,278), south-east diagonal road to the map edge; ground rises to y 25 at (280,283) |
| South container yards | -125..125 | 228..340 | south container yard (50,268) 81 x 51 m, south-west container yard with the Terragroup container (-51,277) 70 x 66 m (the object #21WS door, about (-58,285)), label "Cargo Containers" (14,321), Oli Tower circle road (-125,222) 47 m across with the tower base (-126,222), fences around the yards |
| Highway corridor | -279..-78 | -434..434 | two 11 m carriageways (x -197..-189 and -176..-169, 868 m long), two slip roads in the north (x -279..-189 and -169..-78, z -398..-254), roadside booths at (-196,-72) (-176,-68) (-196,-57) and four at (-197..-168, 2..21), transits at both ends |
| West of the highway | -410..-200 | -130..400 | the biggest of 19 rock fields (8,699 m2, x -407..-292, z -129..196) and 18 smaller ones, the west gravel track along the minefield (x -442..-410), the dirt road west (z 74-149) to the Path to River exit, the west camp (10 huts x -412..-338, z 87..175, pad (-323,158)) |
| Far west | -510..-440 | -409..405 | minefield band, Path to River flare exit (-439,91.5), power lines |

## 3. Outside (terrain, roads, car parks, railway, fences, power station, camps, every outdoor structure)

Everything in this section is the SVG of 2026-01-09 unless noted. Column `1.0` marks objects that lie (wholly or partly) outside the pre-1.0 playable polygon of section 2, i.e. added by the expansion. Names of roads, huts and pads are my own descriptors; the 10 outdoor tarkov.dev labels are listed at the end.

### 3.1 Terrain relief

No heightmap exists in any source. Terrain height (game y) sampled from the 155 SPT spawn points outside the mall footprint (pre-1.0 database: it covers only the old playable area, boundary.pre_1_0_polygon, so the new west strip x < -199 and the new east strip x > 300 are not sampled). Ground height of the whole mall apron is y 21.4 (the garage floor and all outdoor aprons).

| region | x | z | ground y | notes |
|---|---|---|---|---|
| flat central plain, parking lots, mall apron | - | - | 20.5..22.9 | 80 of 155 samples at y 21.0-21.9; the mall ground floor is y 21.4 |
| north-west lowland (ponds and swamp) | -303..-223 | -287..-126 | 14.8..17.4 | 5-6 m below the plain: PMC spawn points at (-303,-286) y 15.1, (-233,-129) y 17.0, (-283,-180) y 16.7; the SVG puts six ponds in this area (x -349..-254, z -239..-126) and a 3,162 m2 pond at (-360,-140) |
| north edge, IDEA Park bots | -352..-30 | -381..-251 | 16.9..18.9 | scav points of ZoneIDEAPark sit 2.5-4.5 m below the plain |
| south-east rise | 278..283 | 281..285 | 24.9..25.3 | PMC spawn cluster (280,283) on a bank 3.5 m above the plain; the southern road #43 and the diagonal road #14 climb here |
| rock outcrop west (hill) | -407..-292 | -130..197 | not sampled | 19 large rock fields (8,699 m2 for the biggest) west of the highway; heights not sampled |

Build rule of thumb: flat plain y 21.4 everywhere except the north-west lowland (y 15-17, about 5-6 m lower, ponds), the north edge strip (y 17-19) and the south-east bank (y 25). The 155 height samples are in JSON `relief.samples` as [x, z, y]. The mall ground is the plain; the L1 terraces at y 27.1 stand 5.7 m above it.

### 3.2 Water and rocks

| polygon | cx | cz | w x d | rot | area m2 | 1.0 |
|---|---|---|---|---|---|---|
| water_0 | -270.8 | -145.4 | 40.7 x 18.8 | 63 | 593 |  |
| water_1 | -300 | -200.1 | 25.3 x 12.3 | -15.2 | 232 |  |
| water_2 | -336.5 | -225.8 | 30.6 x 17.3 | 24.9 | 359 |  |
| water_3 | -267 | -210.8 | 13 x 8 | 44.8 | 78 |  |
| water_4 | -310.4 | -212.6 | 13.6 x 9.5 | 72.4 | 106 |  |
| water_5 | 433.9 | 67.6 | 51.4 x 40 | -44 | 1193 | new |
| water_6 | 470.6 | -48.5 | 587.6 x 77.5 | 80.8 | 11,636 | new |
| water_7 | -39.1 | -377.2 | 35.1 x 27.9 | -80.8 | 474 |  |
| water_8 | -117.2 | -365.8 | 24.5 x 13.7 | 84.8 | 255 |  |
| water_9 | -82.9 | -372.5 | 38 x 27.4 | -15.4 | 611 |  |
| water_10 | -207.7 | -116.7 | 18.9 x 6 | -85.9 | 82 | part new |
| water_11 | -230.7 | -142.9 | 29.1 x 13.8 | 35.1 | 175 |  |
| water_12 | -359.6 | -140.4 | 89.3 x 47.8 | 37.5 | 3162 | part new |

- 13 water polygons (18,956 m2 in total). The big one, water_6 (11,636 m2, 588 m long, x 397..501, z -337..246, along the sniper band), is the river/canal east of the mall; water_12 (3,162 m2) and the six small ponds (water_0..4, 10, 11) are the north-west swamp; water_7..9 are three ponds on the north edge; water_5 (1,193 m2) is a pond at (434,68). Depth and shore slope are not in any source.
- [x, z, equivalent_radius_m] boulder/cliff blobs from the SVG 'Rocks' layer; 'big' holds the 19 outlines larger than 400 m2 (rock fields/hills on the west half). Heights are not in any source. Outlines of the 19 fields over 400 m2 (JSON `rocks.big`):

| rock field | area m2 | x | z |
|---|---|---|---|
| rock_field_3 | 8699 | -407..-292 | -129..196 |
| rock_field_1 | 2375 | -473..-251 | 373..406 |
| rock_field_12 | 2351 | -256..-204 | -98..97 |
| rock_field_7 | 1692 | -429..-307 | 197..262 |
| rock_field_11 | 1069 | -465..-388 | 306..352 |
| rock_field_18 | 969 | -257..-235 | -7..76 |
| rock_field_9 | 891 | -318..-273 | 309..339 |
| rock_field_16 | 831 | -306..-268 | 235..290 |
| rock_field_15 | 780 | -409..-344 | 294..316 |
| rock_field_14 | 771 | -231..-215 | 202..265 |
| rock_field_13 | 643 | -232..-211 | 125..191 |
| rock_field_6 | 638 | -407..-382 | 192..224 |
| rock_field_17 | 605 | -257..-238 | 113..167 |
| rock_field_2 | 577 | -413..-387 | -243..-213 |
| rock_field_4 | 571 | -344..-318 | 70..102 |
| rock_field_10 | 541 | -262..-243 | 271..312 |
| rock_field_0 | 495 | -437..-412 | 371..395 |
| rock_field_5 | 473 | -400..-367 | 67..85 |
| rock_field_8 | 453 | -232..-214 | 280..313 |

All 19 fields (x -473..-211) and 36 of the 42 small boulders lie west of x -200; the other 6 boulders are at (328,-22), (417,-50), (364,-101), (403,-87), (167,255) and (-138,-262), so the east half of the map is almost free of rocks. Heights are not in any source.

### 3.3 Roads

Widths from the SVG stroke widths: gravel 4.6 m, tarmac 7.3 m, highway 11 m. 49 roads: 3 gravel tracks (1192 m), 42 tarmac roads (5460 m), 4 highway pieces (2094 m); polylines in JSON `roads[].pts`. Road ends that leave the playable polygon are marked in the notes column.

| id | name | surface | width m | length m | polyline (x,z), coarse | 1.0 |
|---|---|---|---|---|---|---|
| 0 | south-west gravel track | gravel | 4.6 | 320 | (-196,299) > (-225,327) > (-251,340) > (-300,351) > (-385,353) > (-499,362) | part new |
| 1 | dirt road west (towards Path to River) | gravel | 4.6 | 235 | (-323,149) > (-349,102) > (-376,94) > (-423,91) > (-501,74) > (-521,79) | new |
| 2 | west gravel track along the minefield (N-S) | gravel | 4.6 | 637 | (-435,227) > (-439,154) > (-412,-1) > (-412,-58) > (-430,-272) > (-430,-399) | part new |
| 3 | south-west link road to the Oli Tower circle | tarmac | 7.3 | 74 | (-176,291) > (-161,274) > (-119,244) |  |
| 4 | Oli Tower circle (closed loop) | tarmac | 7.3 | 145 | (-101,222) > (-118,244) > (-141,239) > (-146,215) > (-126,199) > (-102,215) (closed) |  |
| 5 | link from the highway to the west ring road (z 127-151) | tarmac | 7.3 | 75 | (-172,127) > (-170,133) > (-155,149) > (-147,151) > (-121,136) > (-119,130) |  |
| 6 | west ring road (long curve west of the mall, S to N) | tarmac | 7.3 | 603 | (-119,199) > (-118,-307) > (-113,-317) > (-102,-322) > (-28,-324) |  |
| 7 | south stub (x 160) | tarmac | 7.3 | 20 | (160,211) > (160,231) |  |
| 8 | south ring road (E-W, below the mall) | tarmac | 7.3 | 445 | (344,231) > (-102,230) |  |
| 9 | south-west container road | tarmac | 7.3 | 383 | (121,228) > (118,275) > (-3,333) > (-97,333) > (-121,321) > (-124,245) |  |
| 10 | west mall road (N-S, x -35..-26) | tarmac | 7.3 | 554 | (-26,-323) > (-26,-188) > (-34,-168) > (-35,4) > (-26,93) > (-26,227) |  |
| 11 | north ring road (E-W, above the mall) | tarmac | 7.3 | 293 | (-29,-324) > (264,-325) |  |
| 12 | south-east corner connector | tarmac | 7.3 | 110 | (344,231) > (343,198) > (335,185) > (315,177) > (275,175) |  |
| 13 | east mall road (N-S, x 264..287) | tarmac | 7.3 | 513 | (287,176) > (286,-302) > (284,-310) > (279,-319) > (273,-323) > (264,-325) |  |
| 14 | south-east diagonal road | tarmac | 7.3 | 195 | (401,288) > (390,251) > (357,232) > (302,230) > (288,212) > (287,177) | part new |
| 15 | parking-lot entrance stub | tarmac | 7.3 | 17 | (-46,171) > (-28,171) |  |
| 16 | parking-lot entrance stub | tarmac | 7.3 | 17 | (-45,135) > (-29,135) |  |
| 17 | parking-lot entrance stub | tarmac | 7.3 | 10 | (-47,71) > (-36,71) |  |
| 18 | parking-lot entrance stub | tarmac | 7.3 | 11 | (-47,36) > (-36,36) |  |
| 19 | parking-lot entrance stub | tarmac | 7.3 | 11 | (-47,-29) > (-36,-29) |  |
| 20 | parking-lot entrance stub | tarmac | 7.3 | 12 | (-104,35) > (-116,35) |  |
| 21 | parking-lot entrance stub | tarmac | 7.3 | 12 | (-104,71) > (-117,71) |  |
| 22 | parking-lot entrance stub | tarmac | 7.3 | 13 | (-103,-65) > (-117,-65) |  |
| 23 | parking-lot entrance stub | tarmac | 7.3 | 11 | (-47,-129) > (-36,-129) |  |
| 24 | parking-lot entrance stub | tarmac | 7.3 | 11 | (-46,-165) > (-36,-165) |  |
| 25 | parking-lot entrance stub | tarmac | 7.3 | 14 | (-103,-165) > (-117,-165) |  |
| 26 | parking-lot entrance stub | tarmac | 7.3 | 14 | (-103,-131) > (-117,-131) |  |
| 27 | parking-lot entrance stub | tarmac | 7.3 | 17 | (-45,-229) > (-28,-229) |  |
| 28 | Go Kart link road (E-W) | tarmac | 7.3 | 92 | (-118,-300) > (-27,-300) |  |
| 29 | north stub (x 62) | tarmac | 7.3 | 22 | (62,-323) > (62,-301) |  |
| 30 | parking-lot entrance stub | tarmac | 7.3 | 29 | (46,227) > (46,198) |  |
| 31 | parking-lot entrance stub | tarmac | 7.3 | 15 | (38,228) > (38,243) |  |
| 32 | parking-lot entrance stub | tarmac | 7.3 | 13 | (-64,232) > (-64,245) |  |
| 33 | parking-lot entrance stub | tarmac | 7.3 | 11 | (-35,-65) > (-46,-65) |  |
| 34 | north-east dock apron entrance stub | tarmac | 7.3 | 14 | (275,-273) > (289,-273) |  |
| 35 | parking-lot entrance stub | tarmac | 7.3 | 17 | (-25,-218) > (-8,-218) |  |
| 36 | parking-lot entrance stub | tarmac | 7.3 | 17 | (-33,-89) > (-16,-89) |  |
| 37 | parking-lot entrance stub | tarmac | 7.3 | 17 | (-32,-7) > (-16,-7) |  |
| 38 | parking-lot entrance stub | tarmac | 7.3 | 17 | (-25,135) > (-8,135) |  |
| 39 | north stub (x 258) | tarmac | 7.3 | 8 | (258,-335) > (258,-327) |  |
| 40 | Power Station access road (N-S, x 311) | tarmac | 7.3 | 72 | (311,-360) > (311,-288) |  |
| 41 | Power Station east road (E-W, z -362) | tarmac | 7.3 | 140 | (424,-362) > (284,-362) | part new |
| 42 | Power Station link road | tarmac | 7.3 | 33 | (310,-327) > (286,-326) > (279,-321) |  |
| 43 | southern road (south-east boundary, runs E to W off the map) | tarmac | 7.3 | 648 | (546,250) > (383,292) > (216,304) > (139,317) > (59,353) > (-63,431) | new |
| 44 | east-edge road (N-S, along the sniper band) | tarmac | 7.3 | 715 | (506,260) > (505,-129) > (487,-157) > (452,-194) > (432,-244) > (423,-430) | new |
| 45 | north-east slip road (to the east carriageway) | highway | 11 | 179 | (-78,-398) > (-112,-376) > (-131,-357) > (-162,-302) > (-167,-280) > (-169,-254) |  |
| 46 | highway, west carriageway | highway | 11 | 868 | (-197,434) > (-189,-262) > (-189,-434) | part new |
| 47 | north-west slip road (to the west carriageway) | highway | 11 | 179 | (-279,-398) > (-243,-374) > (-228,-359) > (-200,-314) > (-193,-292) > (-189,-254) |  |
| 48 | highway, east carriageway | highway | 11 | 868 | (-176,434) > (-169,-214) > (-169,-434) | part new |

- **Ring system round the mall**: north ring #11 (z -325, x -29..264) meets the west mall road #10 at (-26,-324) and the east mall road #13 at (264,-325); #13 runs south to (287,176) where the south-east connector #12 and the diagonal #14 branch off; #12 reaches the south ring #8 (z 230, x -102..344) at (344,231), #14 crosses #8 at (303,231) and (332,231) and runs on to the map edge at (401,288); #8 meets #9 at (121,231), #7 at (160,231), #31 at (38,230), #32 at (-64,230) and the Oli Tower circle #4 at (-102,230). West side: ring road #6 runs from the Oli circle (-119,199) north to (-28,-324), crossing the lot stubs at (-119,71) (-118,-65) (-118,-131) (-118,-165) and the Go Kart link #28 at (-118,-300); the highway link #5 joins it at (-119,130); the west mall road #10 meets the north ring at (-26,-324) and the Go Kart link at (-26,-300).
- **Stubs**: 25 short tarmac stubs of 8-29 m (ids 7, 15..27, 29..39) join the lots, aprons and the mall edge to the ring roads: on the west side stubs of x -117..-103 face the west ring road and stubs of x -47..-8 face the west mall road (z -229, -218, -165, -131, -129, -89, -65, -29, -7, 36, 71, 135, 171); #30..#32 and #7 enter the south ring (x 38, 46, -64, 160); #29 and #39 are north stubs (x 62 and 258), #34 is the north-east dock apron entrance (275..289, -273).
- **Highway**: two 11 m carriageways x -197..-189 (west) and x -176..-169 (east), both 868 m long from the north tab to the south edge; slip roads #47 and #45 meet the carriageways at about (-189,-254) and (-169,-254) and curve north-west and north-east to z -398; link #3 joins the east carriageway at (-175,290), gravel track #0 the west carriageway at (-195,298). Transit icons: Streets at the north end (-184,-421), Customs at the south end (-193,430).
- **West gravel network**: #2 (637 m, x -442..-410, N-S along the minefield), #1 (the dirt road west, 235 m, from (-323,149) to (-521,79), crossing #2 at (-428,90): the Path to River exit lies on it), #0 (the south-west track, 320 m).
- **East/south edge roads**: #44 runs N-S outside the sniper band from (506,260) to the map edge (423,-430); #43 is the southern boundary road from (546,250) to (-63,431), joining #44 at (506,261) and #14 at (401,288). Both lie along or outside the polygon edge and are scenery for the border.

### 3.4 Railway

| rail | length m | description | polyline (x,z), coarse |
|---|---|---|---|
| rail_0 | 914 | west double track, west rail: from the south-west edge (-506,278) east to (-290,188), north along x -288..-286 to z -122, then NNW to the north edge (-387,-433) | (-506,278) > (-310,229) > (-286,-122) > (-363,-219) > (-387,-433) |
| rail_1 | 923 | west double track, east rail (7 m east of the first) | (-506,283) > (-329,256) > (-278,-115) > (-358,-223) > (-380,-433) |
| rail_2 | 1070 | south border rail (E-W, z 411), lies outside the playable polygon | (-528,411) > (542,412) |
| rail_3 | 1070 | south border rail (E-W, z 417), lies outside the playable polygon | (-528,417) > (542,418) |

Drawn 2.7 m wide as a dashed line (gauge and sleepers are not in the SVG). The west double track runs 7 m apart, from the south-west edge (-506,278) east to (-290,188), north along x -288..-286 to z -122, then north-north-west to the north edge at x -387 and -380 - the Railway Exfil (-394,-420) sits at its north end. No drawn road crosses the two west rails (no polyline intersections), so there are no level crossings or bridges to build; the SVG gives no bridge or level information either way. The rails pass 7 m (rail_0) and 14 m (rail_1) from the Railway Exfil icon; the nearest west-camp hut is 50 m from them and the Path to River icon is 151 m west of the nearest rail. The two south border rails (z 411, 417) are outside the polygon. No station building, platform or train cars appear in the SVG: progameguides (2023) puts the Railway Exfil beside a railway station with graffiti walls and ggrecon (2022) says to head to the trains in the corner, but those objects are not placed in any source.

### 3.5 Fences and walls

35 fence polylines, 1817 m in total (SVG `Fence` layer, new in the 2026-01-09 file); there is no wall layer and no height anywhere. Longest 14 (all in JSON `fences`):

| fence | length m | vertices | polyline (x,z), coarse | 1.0 |
|---|---|---|---|---|
| fence_fence_15 | 290 | 12 | (131,-330) > (168,-350) > (232,-376) > (246,-390) > (337,-365) | part new |
| fence_fence_17 | 169 | 7 | (337,-284) > (308,-238) > (297,-227) > (297,-171) > (300,-150) | part new |
| fence_fence_34 | 135 | 8 | (-41,310) > (-18,302) > (-15,259) > (-18,257) > (-60,243) |  |
| fence_fence_33 | 119 | 8 | (-69,243) > (-84,257) > (-87,299) > (-84,302) > (-50,310) |  |
| fence_fence_0 | 103 | 2 | (-199,-135) > (-200,-31) | part new |
| fence_fence_30 | 93 | 4 | (77,278) > (42,294) > (9,294) > (9,273) |  |
| fence_fence_29 | 90 | 4 | (43,242) > (91,242) > (91,272) > (81,276) |  |
| fence_fence_12 | 82 | 4 | (-82,-338) > (-63,-338) > (-63,-353) > (-16,-353) |  |
| fence_fence_1 | 68 | 4 | (-212,405) > (-211,384) > (-205,378) > (-205,339) | part new |
| fence_fence_2 | 56 | 2 | (-202,94) > (-201,39) | new |
| fence_fence_3 | 54 | 3 | (-201,31) > (-200,-15) > (-202,-23) | new |
| fence_fence_23 | 51 | 2 | (337,80) > (337,131) |  |
| fence_fence_31 | 51 | 3 | (9,269) > (9,242) > (32,242) |  |
| fence_fence_16 | 45 | 2 | (337,-358) > (337,-313) |  |

- **fence_15** (290 m) is the north-east perimeter: from (131,-330) it runs south-east around the north service yard and Power Station quarter ((168,-350) (182,-336) (232,-336) (232,-376) (246,-390) (319,-390) (337,-372)) to (337,-365). **fences 16..24** (x 297..337, z -358..146) are the east service-lane fence, nine segments with eight gaps: z -313..-284, -150..-115, -91..-45, -10..3, 20..51, a 12 m gap at (314..326, 56), z 71..80 and z 131..137; the 6 m gap at (337,131..137) next to hut #31 is the "Wall Break" label, and the "Hole in the Fence" extract is one of the others (probably z -91..-45, section 6). **fence_0, 2, 3** (213 m) run along the west edge of the highway at x -200 from z -135 to 94 and fence_1 (68 m) at its south end (-212,405) > (-205,339). **fences 29..31, 33, 34** (51-135 m) enclose the two south container yards. fence_12..14 line the north edge at x -82..-16, z -412..-338. The rest are short lot fences (3-45 m).
- **The fences follow the old boundary**: fence_15 east of x 232, fence_17 and the north end of fence_16 coincide with the pre-1.0 Limit polygon of section 2 (its east edge x 297-338 and its north-east corner (319,-390)), and fence_0..3 lie on its west edge at the highway (x -200). The expansion strips therefore lie outside a fence line on the east and west: gaps in these fences are the connections to the new strips (inference from geometry, grade C).

### 3.6 Power lines

| line | polyline (x,z) |
|---|---|
| powerline_0 | (-445,437) > (-445,230) > (-426,-110) > (-438,-280) > (-438,-439) |
| powerline_1 | (-427,437) > (-427,230) > (-408,-110) > (-420,-280) > (-420,-439) |
| powerline_2 | (324,-344) > (537,-344) |
| powerline_3 | (312,-264) > (341,-84) > (343,38) > (342,156) > (350,279) > (353,446) |
| powerline_4 | (323,-265) > (338,-212) > (408,-138) > (479,-100) > (560,-85) |

Towers (23): (-438,-405) (-420,-405) (-438,-280) (-420,-279) (-426,-110) (-408,-110) (-436,60) (-418,60) (-445,230) (-427,230) (-445,322) (-427,322) (376,-343) (501,-343) (321,-210) (341,-83) (343,38) (341,156) (350,279) (354,402) (338,-212) (407,-138) (480,-100). Lines 0 and 1 run N-S along the minefield band (6 towers each pair at z -405, -280, -110, 60, 230, 322); line 2 leaves the Power Station east at z -344; lines 3 and 4 run along the east side. Pylon height and sag are not in any source.

### 3.7 Outdoor structures (SVG `Buildings`, 50 footprints)

All are single oriented boxes, assumed one storey with no interior (the SVG has no heights or doors). Confidence A for the Power Station main building (label within 35 m), B for the rest.

| id | name | kind | cx | cz | w x d | rot | c | 1.0 |
|---|---|---|---|---|---|---|---|---|
| 0 | Power Station yard shed | shed | 328.9 | -368.7 | 5.8 x 5.7 | -90 | B |  |
| 1 | Power Station yard shed | shed | 320 | -368.7 | 5.9 x 5.8 | 0 | B |  |
| 2 | Idea Tower base | tower | 35.7 | -363.9 | 5.8 x 4.9 | 17.8 | B |  |
| 3 | north-west hut (Railway Exfil approach) | hut | -372.4 | -363.2 | 12.8 x 8.4 | -90 | B |  |
| 4 | north shed | shed | -61.2 | -355.8 | 4.3 x 3.6 | -90 | B |  |
| 5 | Power Station, main building (power switch inside) | power_station | 288.3 | -346.2 | 26 x 19.6 | 0 | A |  |
| 6 | north shed | shed | -80.8 | -342 | 7.1 x 3.1 | -90 | B |  |
| 7 | Power Station compound building | shed | 317.6 | -295.7 | 5.7 x 5.5 | -90 | B |  |
| 8 | Power Station compound building | shed | 327.6 | -295.6 | 5.8 x 5.5 | -90 | B |  |
| 9 | Power Station compound building | shed | 332.7 | -287.5 | 5.3 x 4.2 | -90 | B |  |
| 10 | Power Station compound building | shed | 332.7 | -277.9 | 5.3 x 4.3 | -90 | B |  |
| 11 | Power Station compound building | shed | 303.9 | -264.2 | 6.4 x 2.6 | -90 | B |  |
| 12 | Power Station compound building | shed | 303.9 | -257.5 | 5.9 x 2.7 | -90 | B |  |
| 13 | Go Kart pit building | building | -58.8 | -209 | 12.7 x 8.5 | 0 | B |  |
| 14 | highway roadside booth | booth | -195.7 | -71.5 | 10.1 x 5.4 | -90 | B |  |
| 15 | highway roadside booth | booth | -175.6 | -68.2 | 8.3 x 4.6 | -90 | B |  |
| 16 | highway roadside booth | booth | -195.7 | -57.1 | 10.1 x 5.4 | -90 | B |  |
| 17 | east-edge hut | hut | 405.3 | -42.5 | 9.8 x 5.1 | 40.9 | B | new |
| 18 | east-edge hut | hut | 413.7 | -40.1 | 6 x 4.7 | 32.7 | B | new |
| 19 | east-edge hut | hut | 423.8 | -39.1 | 4.3 x 4.1 | -30.2 | B | new |
| 20 | west parking booth | booth | -102.1 | -30 | 9.6 x 6.2 | -44.8 | B |  |
| 21 | east-edge hut | hut | 418.5 | -27 | 6 x 5.1 | -19.6 | B | new |
| 22 | roadside booth west of the Scav Camp label | booth | -142 | 1.8 | 5.8 x 5.2 | 0 | B |  |
| 23 | highway roadside booth (old Scav Camp area) | booth | -176.8 | 4.6 | 8.3 x 4.6 | -90 | B |  |
| 24 | highway roadside booth (old Scav Camp area) | booth | -187.5 | 5.3 | 10.1 x 5.4 | -90 | B |  |
| 25 | highway roadside booth (old Scav Camp area) | booth | -196.4 | 6.5 | 10.1 x 5.4 | -90 | B |  |
| 26 | highway roadside booth (old Scav Camp area) | booth | -168.2 | 20.9 | 10.1 x 5.4 | -90 | B |  |
| 27 | block inside the mall footprint (probable Saferoom vestibule) | inside_mall | 129.7 | 51.4 | 9.6 x 3.4 | 0 | B |  |
| 28 | west camp hut | camp | -382.9 | 86.7 | 8.3 x 4 | 1.8 | B | new |
| 29 | west camp hut | camp | -408 | 90.6 | 7.1 x 6.5 | 6.3 | B | new |
| 30 | west camp hut | camp | -411.9 | 102.6 | 6.2 x 5.2 | 0 | B | new |
| 31 | Wall Break hut | hut | 340.6 | 127.6 | 6.8 x 3.5 | 0 | B |  |
| 32 | west camp hut | camp | -337.9 | 144.4 | 12.7 x 10.1 | -70.3 | B | new |
| 33 | west camp hut | camp | -378.5 | 155.4 | 10.1 x 5.2 | -56.4 | B | new |
| 34 | west camp hut | camp | -394.9 | 156.1 | 8.4 x 5.6 | -69.8 | B | new |
| 35 | west camp hut | camp | -343 | 162.8 | 12.8 x 9.7 | 19.9 | B | new |
| 36 | west camp hut | camp | -401.6 | 167.5 | 8.3 x 3.6 | -90 | B | new |
| 37 | west camp hut | camp | -383.3 | 168.5 | 10.1 x 5.2 | 78.1 | B | new |
| 38 | west camp hut | camp | -394.1 | 175.4 | 10.1 x 5.2 | 0 | B | new |
| 39 | Emercom camp tent/container | camp | 211.4 | 218.1 | 9.7 x 5.2 | 0 | B |  |
| 40 | Emercom camp tent/container | camp | 191.2 | 219.9 | 9.4 x 2.8 | -80.9 | B |  |
| 41 | Oli Tower base | tower | -126 | 222.5 | 5.8 x 5.2 | 0 | B |  |
| 42 | Emercom camp tent/container | camp | 211.3 | 239.9 | 9.8 x 5.3 | 0 | B |  |
| 43 | Emercom camp tent/container | camp | 208.8 | 251 | 6.6 x 6.2 | 0 | B |  |
| 44 | Emercom camp tent/container | camp | 193.7 | 253.2 | 12.5 x 2.6 | -90 | B |  |
| 45 | Emercom camp tent/container | camp | 218.6 | 254.4 | 11.7 x 2.7 | 88.3 | B |  |
| 46 | Emercom camp tent/container | camp | 202.5 | 256.8 | 5.6 x 4.9 | 0 | B |  |
| 47 | Emercom Checkpoint building | building | 409.8 | 267.4 | 9.8 x 5 | -16 | B |  |
| 48 | Emercom camp tent/container | camp | 198.3 | 268.8 | 11.5 x 2.4 | 0 | B |  |
| 49 | Emercom Checkpoint building | building | 411.9 | 274.3 | 9.6 x 5.1 | -16 | B |  |

- **Power Station**: main building #5 (26 x 19.6 m at (288,-346)) holds the power switch; the compound (x 303..333, z -296..-257) has 6 sheds (#7..#12) and the two yard sheds (#0, #1) stand at (320..329,-369), 25 m north-east of the main building; concrete pads: west apron (256,-346) 37 x 24 m, four compound pads (yards 3..6). The V-Ex pickup (356,-360) is 68 m east of the main building, the sniper band starts 28 m further east.
- **Go Kart**: pad (-75,-245) 87 x 62 m with the 61 x 30 m track outline polygon (22 vertices, yard 9, a closed loop in the middle of the pad) and the pit building #13 (-59,-209).
- **Towers**: "Idea Tower" (label (36,-350)) and "Oli Tower" (label (-120,227)) are marked in the SVG only by a 5-6 m hut at their base (#2, #41); the towers themselves (height, shape) are not drawn. The Oli tower stands in the middle of the 47 m ring road (#4).
- **Highway and edge huts**: seven 8-10 m booths along the carriageways (#14..#16 at z -72..-57 and #23..#26 at z 5..21, the old "Scav Camp" area), a booth between the highway and the west ring road (#22, (-142,2)), a booth at the west parking lot (#20, (-102,-30)), four huts on the east edge (#17..#19, #21 at x 405..424, z -43..-27, new in 1.0), the Wall Break hut #31, the Emercom camp boxes (#39, #40, #42..#46, #48: 8 boxes 3-12 m long at x 190..220, z 218..269), two Emercom Checkpoint buildings (#47, #49, 10 x 5 m, rot -16).
- **West camp** (new in 1.0): ten huts #28..#30, #32..#38 (4-13 m, x -412..-338, z 87..175) on a camp pad (-323,158) 20 x 12 m; SPT has no spawn point here, the re3mr 2026-01 map draws an AI scav icon at (-386,127). The Path to River exit lies about 30 m west of the nearest hut (#30).
- **Block #27** (130,51), 9.6 x 3.4 m, lies inside the mall footprint at ground level: probably the vestibule of the hidden Saferoom (the SVG draws the Saferoom block solid; the padlocked door is at (132,55)). Grade C.

### 3.8 Yards, car parks and pavement (SVG `Outdoors`/pavement polygons)

| id | name | cx | cz | w x d | rot | area m2 | outline pts | 1.0 |
|---|---|---|---|---|---|---|---|---|
| 0 | north service yard | 160.1 | -338.8 | 58.8 x 22 | 0 | 1045 | 5 |  |
| 1 | Power Station west apron | 256.4 | -345.8 | 37.3 x 24 | 0 | 894 | 4 |  |
| 2 | north-east dock apron (IDEA docks, ramp up to the L1 terrace) | 257.9 | -240.7 | 100.8 x 34.6 | -90 | 3487 | 4 |  |
| 3 | Power Station compound pad | 324.4 | -344 | 17.9 x 14.9 | -90 | 267 | 4 |  |
| 4 | Power Station compound pad | 321.4 | -311.5 | 23.9 x 15 | -90 | 358 | 4 |  |
| 5 | Power Station compound pad | 318.1 | -282.5 | 19.4 x 9.8 | 0 | 191 | 4 |  |
| 6 | Power Station compound pad | 317.9 | -264.6 | 19.9 x 9.9 | 0 | 197 | 4 |  |
| 7 | south container yard (east) | 50 | 268.2 | 81.1 x 51.3 | 0 | 3605 | 5 |  |
| 8 | Go Kart pad | -75.1 | -244.7 | 87 x 61.7 | -90 | 5367 | 4 |  |
| 9 | Go Kart track outline (inner polygon) | -77 | -245.5 | 60.6 x 30.4 | -87.1 | 1124 | 22 |  |
| 10 | west parking lot 2 | -76 | -147.1 | 94.5 x 62.8 | -90 | 5932 | 4 |  |
| 11 | west parking lot 3 (Four Camp) | -75.6 | -68.5 | 62.9 x 49.2 | 0 | 3095 | 4 |  |
| 12 | west parking lot 4 | -75.8 | -18.6 | 63.1 x 34.8 | 0 | 2196 | 4 |  |
| 13 | west parking lot 5 | -75.8 | 53.1 | 95.4 x 63.3 | -90 | 6038 | 4 |  |
| 14 | west parking lot 6 | -75.9 | 162.4 | 109.5 x 63.4 | -90 | 6130 | 5 |  |
| 15 | south-west container yard (Terragroup container) | -51.1 | 276.5 | 70.1 x 66.4 | 0 | 4517 | 12 |  |
| 16 | east service lane pad | 298 | -12.1 | 54.4 x 15.5 | -90 | 801 | 7 |  |
| 17 | east truck lot | 321.3 | 101.1 | 88.5 x 29 | -90 | 2569 | 4 |  |
| 18 | south-east dock apron (OLI docks, ramp up to the L1 terrace) | 258 | 146.5 | 100.8 x 34.5 | -90 | 3473 | 4 |  |
| 19 | north access pad | 163.5 | -314.1 | 47.8 x 14.2 | 0 | 680 | 4 |  |
| 20 | west camp pad | -322.8 | 157.7 | 20.5 x 11.9 | -69.4 | 208 | 8 | new |

Outlines (`yards[].outline`) are exact polygons; the table gives the oriented box. The mall apron itself is not a separate polygon: the garage floor (section 4.2) and the two L1 dock terraces cover it. West of the mall the five lots are separated by 6-8 m strips (z -100..-93, -44..-36, -1..5, 101..108) and tied together by the stubs of section 3.3; the SVG draws no parking-bay markings or barriers.

### 3.9 Named outdoor places (tarkov.dev labels, layer "outside", y -1..10)

| label | x | z | game x, z | what is there |
|---|---|---|---|---|
| Power Station | 268.9 | -310.7 | -186.4, -318.7 | label 35 m south-west of the main building centre; the quarter with the power switch |
| Go Kart | -72.5 | -245 | 155, -253 | label on the Go Kart pad centre |
| Four Camp | -75.5 | -70.5 | 158, -78.5 | in west parking lot 3; not an extract in any source |
| Cargo Containers | 14.3 | 320.9 | 68.2, 312.9 | south container yards (SVG pads at (50,268) and (-51,277); the label sits 12-27 m south of them) |
| Wall Break | 342.7 | 131.8 | -260.2, 123.8 | hut #31 at the 6 m gap (337,131..137) between fence_23 and fence_24 of the east service-lane fence; the break itself is not drawn |
| Ramps | 258 | 153.1 | -175.5, 145.1 | south-east dock apron with the vehicle ramps up to the L1 terrace |
| Oli Tower | -119.8 | 227.4 | 202.3, 219.4 | tower base hut #41 in the Oli circle road |
| Idea Tower | 36 | -350.5 | 46.5, -358.5 | tower base hut #2 on the north edge |
| Scav Camp | -180.7 | -3.1 | 263.2, -11.1 | old Scav Camp area by the highway booths #22..#26; the re3mr 2026-01 co-op extract icon is elsewhere (section 6) |
| Highway Construction | -291 | -383.2 | 373.5, -391.2 | north-west, 19 m from the north end of slip road #47 (-279,-398); the SVG has no construction object there |

The 67 indoor labels (4 garage zones, 33 on L1 incl. the three anchors, 30 on L2) are used in sections 4.2 to 4.4. All 77 labels are in JSON `labels` with game coordinates and y ranges.

## 4. The mall building ("ULTRA" in EFT; Meridian Mall in Zero Return)

Store names below are the sign texts read from the plans (Battlestate's, to be replaced by original names); `kind` and `sells` are what the shop is. Rectangles are axis-aligned (rot 0 = long side E-W, 90 = long side N-S) and are my reading of the 2026-01 plans over the SVG outline; the SVG itself draws walls and closed blocks but no room names. "Openings" are gaps in the wall mask computed on the SVG free space (side of the rectangle, centre of the gap, width); `*` marks a gap wider than 12 m (an open front). The anchors have no computed openings.

### 4.1 Outer footprint, wings and heights

- **Outline** (`mall.outline`, 22 vertices, SVG `Structure`; ground-level building footprint): (-17.9,-172.4) (-17.9,77.7) (-10.7,77.7) (-10.7,185.6) (-12.4,185.6) (-12.4,202.9) (4.7,202.9) (4.7,200.9) (109.8,200.9) (109.8,212.8) (240.8,212.8) (240.8,96.1) (275.2,96.1) (279.5,77.7) (279.5,-172.6) (275.2,-190.3) (240.6,-190.3) (240.6,-307.1) (109.6,-307) (109.6,-297.2) (-10.6,-297.2) (-10.6,-172.4). Bounding box x -17.9..279.5, z -307.1..212.8 = 297.4 x 519.9 m; area 140,962 m2.

| wing | x | z | notes |
|---|---|---|---|
| North wing (IDEA hall + IDEA Bistro) | -10.6..240.6 | -307.1..-172 | one storey (L1 only), tall hall; east wall = 8 dock bays; bistro at the north-west corner |
| Central block (small stores, concourse, atria, Goshan) | -17.9..279.5 | -190.3..96.1 | west part x -18..160 holds the stores, galleries and the L2 floor; east part x 160..262 is the Goshan hall; the Goshan east bay protrudes to x 279.5 at z -172..78 |
| South wing (OLI hall) | -12.4..240.8 | 77.7..212.8 | one storey (L1 only), tall hall; east wall = 8 dock bays; offices in the west end |

- Upper outline (`mall.outline_L2`, 16 vertices): (-17.9,-171.9) (-17.9,78.1) (-10.6,78.1) (-10.6,201) (213.9,201.1) (213.9,78.4) (264.2,78.4) (264.2,-22.6) (279.3,-22.6) (279.3,-71.4) (263.7,-71.4) (263.7,-172) (213.9,-172) (213.9,-296.7) (-10.6,-296.7) (-10.6,-171.9). This is the SVG footprint of everything above the first floor (the three hall roofs and the central block); the L2 *floor* (`levels[2].floor_outline`) is only the small area x -25.5..155.8, z -170.1..77.5.
- West entrance vestibule: the L1 and L2 floor outlines protrude 7 m west of the footprint at x -25..-16, z -61..-32, at the west end of the central concourse (z -47); the L0 SVG "west pad" (x -23..-3.5, z -61..-34, 20 x 27 m) is the matching ground-level apron outside it. This is the main pedestrian door, facing the west car parks. The east side has no pedestrian front: its doors are the 16 dock bays and the Goshan east bay.
- tarkov.dev layer box "mall" (game [[120,218],[-222,-327]] = frame x -37.5..304.5, z -319..226): the area in which the L1/L2 map layers are shown, 12-25 m larger than the footprint on every side.

| level | floor y | ceiling y | ceiling basis | floor area m2 |
|---|---|---|---|---|
| L0 garage / car park | 21.4 | 26.6 | assumed (floor + 5.2 m clear = L1 floor - 0.5 m slab) | 80,753 |
| L1 main floor | 27.1 | 36.1 | assumed (L2 floor - 0.5 m slab) under the L2 gallery; the three halls are open to the roof | 120,142 |
| L2 upper floor | 36.6 | - | unknown (D) | 31,619 |

Floor y values are SPT spawn-height medians (+-0.3 m); the 0.5 m slab and the ceilings are my assumptions, not data. More in section 5.

### 4.2 L0 - ground-level car park ("PARKING", garage zones A-D, IDEA / Goshan / OLI garages)

The garage is the ground floor: its floor is the outdoor ground (y 21.4), so cars and players enter from the aprons at ground level and the mall proper starts 5.7 m above. The SVG floor outline (`levels[0].floor_outline`, 110 vertices, area 80,753 m2, x -17.9..279.4, z -307..212.7) is jagged along all four sides with 3-15 m notches: these are the open car-park bays and entrances (the exact doors are not marked). The garage covers the whole footprint except the wings' stock areas. Not traced: the car park is a pillared hall (the plan shows a column grid about every 8 m); only the outer outline is exact (svg)

| area | kind | cx | cz | w x d | rot | c | notes |
|---|---|---|---|---|---|---|---|
| Garage A (central parking, north hall) | parking | 45.5 | -247.5 | 105 x 95 | 90 | C | pillared parking hall; stair up at (20,-257); 'A' painted on the east wall at (87,-230) |
| Garage B (central parking) | parking | 26.5 | -126 | 98 x 93 | 90 | C | pillared parking hall; stair up at (14,-178) and (83,-166); 'B' on the east wall at (82,-98); scav icon at (26,-139) |
| Garage C (central parking) | parking | 49 | 17.5 | 138 x 125 | 0 | C | parking hall west of the Saferoom block; 'C' (big letter) at (82,0); stairs at (79,18), (-5,-45) |
| Garage D (central parking, south) | parking | 50 | 142.5 | 125 x 124 | 90 | C | parking hall under OLI's west half (pink-grey floor on the plan); 'D' at (130,135); stairs at (20,96), (89,75), (127,87); scav icon at (66,106) |
| IDEA Garage | parking | 182.5 | -236 | 132 x 115 | 90 | C | north-east garage below the IDEA hall; stair up at (177,-174) |
| Goshan Garage | parking | 243.5 | -115 | 136 x 77 | 90 | C | east garage below Goshan; Tagilla icon at (242,-138); ramp up at (274,-45) |
| OLI Garage | parking | 172.5 | 145 | 120 x 75 | 90 | C | south-east garage below OLI; scav icon at (174,152) |
| Scav Camp tunnel (co-op extract) | extract | 162.5 | -67 | 95 x 12 | 0 | C | passage between the central parking (zone B) and the Goshan garage; extract icon 'S' at (176,-67) |
| Saferoom Exfil room | extract | 165 | 12.5 | 70 x 65 | 0 | D | hidden room behind a padlocked door at (132,55); plan shows the block as solid black with the 'A' extract icon at (165,25); real room size not drawn |
| Object-14 container room | locked room | 15 | -267.5 | 35 x 30 | 90 | D | secret weapon stash container 'Object-14', opened remotely by a switch/lever in the Saferoom room; padlock at (11,-250) |

- The five garage areas of the central part are the labelled zones **A** (label (49.5,-214)), **B** (35.5,-104), **C** (82.5,55), **D** (62.5,146) and the three named garages under the anchors: IDEA Garage (north-east), Goshan Garage (east), OLI Garage (south-east). The big letters painted on the walls (A at (87,-230), B at (82,-98), C at (82,0), D at (130,135)) are the in-game zone markers; zone boundaries inside the car park are not drawn, my rectangles are the plan's coloured areas (grade C).
- SVG pavement/garage extras: **garage island** (x 23.6..54.6, z -185.3..-173.1, 31 x 12 m): a hole or core inside the car park between zones A and B (ramp shaft or core, unlabelled). **West pad** (x -23..-3.5, z -61..-34): apron outside the west entrance.
- **Scav Camp tunnel (co-op extract)** (x 115..210, z -73..-61): service passage between garage zone B/C and the Goshan garage; the re3mr plan puts the S extract icon at (176,-67)
- **Saferoom block** (x 130..200, z -20..45, grade D): hidden room behind a padlocked door at (132,55) south-west of the block; the SVG draws the block as solid. The extract icon is at (164,25). Inside (keengamer 2020, ggrecon 2022): couch with valuables, food and drink shelf, weapon attachments beside a microwave, a weapon case, weapon crate and items case, a door button, and the lever that opens Object-14. **Object-14 container room** (x 0..30, z -285..-250, grade D) in the north-west garage: a secret weapon-stash container, a padlock icon at (11,-250), opened remotely from the Saferoom lever; loot: valuables, weapon rack, attachments, large weapon crate (keengamer).
- Vertical links: the garage connects up by 9 stairs/ramps drawn in the SVG, 4 more stair icons from the plans, and four 7.3 m wide vehicle ramps outside (table in 4.6). The 9.8 m wide ramp at (85.3, 15..31) leads from the south octagon atrium (L1) down into garage zone C - the "large hole" of the Saferoom walk-through.
- Scav icons (re3mr 2026-01, "AI SCAV LOCATION") in the garage: (26,-139) zone B, (66,106) zone D, (174,152) OLI garage. Tagilla hammer icon at (242,-138) in the Goshan garage (legend "in the Goshan parking lot").

### 4.3 L1 - main (first) floor, y 27.1

Floor outline `levels[1].floor_outline` (606 vertices, SVG `Floor-1`): area 120,142 m2, x -24.9..277.5, z -296.7..199.9; walls and blocks as 93 holes in `levels[1].walls_and_blocks` (31 thin walls, 53 partitions/small blocks, 9 large blocks or voids of 9,875 m2 in total: back rooms, shelving islands, pillars). tarkov.dev calls this the "2nd Floor" layer (y 25..34).

**Stores and halls (35)**

| name (sign on the plan) | kind | cx | cz | w x d | rot | c | sells / holds | openings: side (x,z) width m |
|---|---|---|---|---|---|---|---|---|
| IDEA | anchor | 134 | -235.5 | 152 x 127 | 0 | C | furniture, homeware and hardware warehouse hall with long shelving aisles | - |
| IDEA Bistro | food | 20 | -247 | 104 x 64 | 90 | C | cafeteria / bistro hall (pale tiled floor), kitchen rooms at the NW corner | S (19,-195) 8.2; S (31,-195) 13.2*; S (47,-195) 10.8; E (52,-284) 12.5*; E (52,-196) 2.8 |
| Goshan | anchor | 209 | -46 | 248 x 98 | 90 | C | supermarket hall (food, drinks, household), warehouse/back-of-house in the NE corner (x 210-260, z -168..-128) | - |
| OLI | anchor | 99 | 142.5 | 222 x 113 | 0 | C | DIY / hardware hall, offices and stock rooms in the west (x -12..20, z 130-190) and a back-of-house block (x 153-190, z 100-185) | - |
| Nortex | clothing | -12.5 | -152.5 | 35 x 9 | 90 | C | clothing store on the west edge | S (-12,-135) 8.5; E (-8,-169) 1.8; E (-8,-163) 5.5; E (-8,-148) 4 |
| TRend | clothing | 19.5 | -148 | 28 x 10 | 0 | B | clothing | N (16,-153) 3.8; N (23,-153) 4.2 |
| Mode7 | clothing | 11.5 | -130 | 19 x 12 | 90 | B | clothing | W (6,-131) 3.5 |
| TTS | electronics | 63.5 | -127 | 27 x 13 | 0 | B | tech / appliances | S (71,-120) 12.8*; E (77,-124) 6 |
| Book Store | books | 112.8 | -120.8 | 40.5 x 25.5 | 0 | B | books and stationery | S (96,-108) 6.5; S (127,-108) 11.5; E (133,-110) 3.2; W (92,-122) 9.8 |
| Dino Clothes | clothing | -12.5 | -113 | 40 x 9 | 90 | C | clothing | N (-12,-133) 8.5; E (-8,-132) 2.5; E (-8,-114) 3.2; E (-8,-95) 4.2 |
| EMERCOM | locked store | 60.5 | -98.5 | 23 x 10 | 0 | B | emergency-ministry relief/medical shop; gas analyser and GM counter spawn (old community note) | N (59,-104) 2.5; E (72,-97) 6.5; W (49,-101) 2.2 |
| Kostin | clothing | 106.5 | -97.8 | 26 x 16.5 | 0 | B | clothing / shoes | N (96,-106) 5; E (120,-96) 5.2; W (94,-103) 6.5 |
| Bizarro | clothing | 143.8 | -94.8 | 17.5 x 8.5 | 0 | B | clothing | E (152,-95) 4; W (135,-95) 4.2 |
| Spiel | toys | -12 | -76.5 | 18 x 9 | 90 | B | toys and games | N (-16,-86) 1.8; N (-10,-86) 5.2; E (-8,-77) 4.5 |
| Voyage | travel | 98.2 | -80.2 | 11.5 x 10.5 | 0 | B | bags and travel goods | W (92,-77) 4.8 |
| Viking | sports | 26.8 | -65 | 42.5 x 20 | 0 | B | outdoor / sports clothing | S (16,-55) 6; S (40,-55) 5 |
| Mantis | electronics | 64.8 | -65 | 25.5 x 20 | 0 | B | tech; gas analyser / GM counter spawn (old community note) | S (61,-55) 4; S (70,-55) 5; E (78,-65) 5.2 |
| German | general | 97.5 | -66.8 | 11.5 x 10 | 90 | B | general retail | W (92,-70) 5.2 |
| The National | clothing | 27 | -28.5 | 43 x 20 | 0 | B | clothing | N (16,-38) 6; N (39,-38) 5.2; W (6,-28) 4.2 |
| Brutal | clothing | 64.8 | -28.5 | 25.5 x 20 | 0 | B | clothing | N (60,-38) 3.5; N (69,-38) 3.8; E (78,-29) 5.2 |
| Kiba | locked store | 98.8 | -20.8 | 25.5 x 12.5 | 90 | B | firearms shop (Kiba Arms): weapon boxes, ammo, armour on mannequins, grenades, cash registers | W (92,-24) 4.5 |
| Pretty Lights | lighting | 113.2 | -20.8 | 25.5 x 12.5 | 90 | B | lamps and lighting | N (112,-34) 3; E (120,-24) 4.8 |
| Telespot | electronics | -12 | -14.8 | 23.5 x 9 | 90 | B | mobile phones | E (-8,-18) 4.5 |
| Revis | general | 19.2 | -8.5 | 27.5 x 14 | 0 | B | general retail | S (15,-2) 4.2; S (24,-2) 4.5 |
| ADIK | sports | 60.5 | -2.5 | 26 x 23 | 90 | B | sportswear (open to the east gallery, 22 m opening) | S (60,10) 5; E (72,-4) 22*; W (49,-8) 14* |
| Generic | general | 109 | 3 | 21 x 17 | 0 | B | general retail | E (120,2) 3.8; W (98,2) 14.8* |
| Top Brand | clothing | -6.5 | 12 | 27 x 20 | 90 | B | clothing | N (-1,-2) 9.8; S (-12,26) 9; S (-1,26) 9.8; E (4,6) 12 |
| Sports | sports | 19.2 | 17 | 27.5 x 11 | 0 | D | sports goods | N (16,12) 4; N (23,12) 4 |
| Unlabelled store N of Viking | unlabelled | 25.5 | -89.5 | 41 x 19 | 0 | D | store room with shelving and pallets, no tarkov.dev label | S (19,-80) 28*; W (5,-96) 5 |
| Yushka | clothing | 12 | 35.8 | 19.5 x 13 | 90 | B | clothing | W (6,36) 4.2 |
| Rasmussen | electronics | 62.8 | 32.8 | 27.5 x 12.5 | 0 | B | tech / electronics (old community note) | N (72,26) 8.5; E (76,29) 4.2; E (76,37) 4.5; W (49,33) 5.8 |
| Avokado | food | 116.2 | 33.2 | 33.5 x 13.5 | 0 | B | grocery / food | N (125,26) 4; W (100,30) 7; W (100,38) 1.8 |
| Boots 4 Life | shoes | -12 | 57.5 | 38 x 9 | 90 | B | shoes | E (-8,53) 13*; E (-8,72) 10 |
| Texho | electronics | 19.2 | 54.2 | 27.5 x 9.5 | 0 | B | tech / electronics | S (15,59) 4.2; S (23,59) 3.8; E (33,54) 3.2 |
| Dom | homeware | 73.5 | 53.2 | 48 x 20.5 | 0 | B | home goods | S (64,64) 13.2*; S (85,64) 15.8*; W (50,45) 4 |

Notes on special rooms (L1):
- **IDEA** (x 58..210, z -299..-172, 152 x 127 m): the north anchor, a furniture/homeware/hardware warehouse with long shelving aisles; its east wall is the sawtooth dock wall (x 210..218, 8 bays at z -213..-270); stock and back rooms in its north-east corner (x 160..210, z -299..-250, D); Killa icon (85,-226); the IDEA cash-register key tile at (52,-241). About 20 cash registers (key IDEA cash register key).
- **IDEA Bistro** (x -12..52, z -299..-195, 64 x 104 m): open cafeteria hall with kitchen rooms at the north-west corner (x -12..25); the L0-L1 stair at (8..24,-258) rises inside it; label "IDEA BISTRO" is on the infographic only (not a tarkov.dev label).
- **Goshan** (x 160..258, z -170..78, 98 x 248 m): the east supermarket hall, 27 cash registers; the left (west) side stocked with food rations; back-of-house at the north-east corner (x 210..260, z -168..-128, D); its west wall faces the central concourse (x 160), the east side opens onto the Goshan east bay and the dock terraces (x 258..278). Killa icon (202,-46), scav icon (170,-50) and (261,-67).
- **OLI** (x -12..210, z 86..199, 222 x 113 m): the south DIY/hardware hall, 18 cash registers; offices (administrator, logistics, outlet utility) and stock rooms in the west end (x -12..20, z 130..190); a stock block behind the docks (x 153..190, z 100..185, D); east wall = 8 dock bays at z 119..176; stair at (-8,189); Killa icon (85,133).
- **EMERCOM** (x 49..72, z -103.5..-93.5): locked relief/medical shop, door lock on the west side at (49,-98), needs the Emercom key; the plan has a key tile near (64,-86).
- **Kiba** (Kiba Arms firearms store, x 92.5..105, z -33.5..-8): door lock icon at (90,-29) on the west wall; two keys (outer door "KIBA", inner grate "KSM") and the mall power on; opening the outer door triggers a store alarm about 3 s later (terminal in the security room, section 4.9); loot: weapon boxes, ammo, mannequin armour, grenades, two cash registers (section 8).
- **Unlabelled store N of Viking** (x 5..46, z -99..-80, D): store room with shelving and pallets that has no tarkov.dev label; **Sports** (x 5.5..33, z 11.5..22.5, D) was read north of Yushka after the automatic growth failed there.
- Stores on the west edge (Nortex, Dino Clothes, Spiel, Telespot, Top Brand, Boots 4 Life, x -17..-8 or -17..3.5) face east onto the west gallery; Avokado, Generic, Dom, Rasmussen, ADIK and Texho open onto the south and east galleries (openings above).

**Corridors, galleries and concourses (L1)**. The JSON holds 36 maximal empty rectangles of walkable floor (`levels[1].corridors`, capped at 60 m, grade C); the circulation they form is:

| route | x | z | width m | JSON ids | notes |
|---|---|---|---|---|---|
| Central E-W concourse | -25..92 (+ hall to 130, door zone to 160) | -53..-41 (hall -59..-36) | 12.5-13 (hall 23) | c2, c3, c4, c0, c23, c25 | runs from the west vestibule (x -25) to the Goshan wall (x 160), 185 m; the three escalator pairs cross it at x 18..38, 51..71 and 100..120 (z -47); widens into a 50 x 23 m hall at x 80..130 |
| West gallery (N-S) | -6..4 | -159..64 | 7.5-9.5 | c17, c24, c28, c32, c33 | the 9-10 m gallery behind the west-edge shops; links the north and south cross-galleries |
| North cross-gallery (E-W) | 2..99 | -171..-155 | 11.5-15.5 | c7, c8, c10 | north stair hall: the L1-L2 stair at (6..27,-161) and the L0-L1 stair (88..97,-169) are here |
| South cross-gallery (E-W) | 3..110 | 61..86 | 15-20.5 | c1, c11, c26 | links the OLI hall (south) to the central block; L1-L2 stair at (6..27,67.6) and L0-L1 stairs (83..94,73), (9..24,94) |
| Inner spine (N-S) | 80..90 | -100..22 | 6.5-11 | c12, c13, c27 | between the two octagon atria (z -113 and 19.6) |
| East gallery (N-S) | 121..133 | -108..17 | 11.5 | c9, c14 | ends at the Goshan door zone; Book Store, Bizarro, Generic and ADIK open onto it |
| Goshan frontage (N-S) | 154..160 | -118..-39 | 5.5 | c34, c35 | strip along the Goshan west wall |
| Stair halls (N-S) | 36..48 and 35..47 | -167..-107 and 8..68 | 12-12.5 | c5, c6, c16 | two N-S halls between the north/south cross-galleries and the escalators; c16 (x 36..54, z -193..-159) and c20 (x 29..58, z -194..-176) link the central block to the IDEA Bistro door zone |
| Goshan east bay (N-S) | 258..272 | -70..-24 | 13.5 | c15 | east pedestrian/truck door of the Goshan hall onto the east service lane |

**Atria and voids on L1 (`levels[1].atria`)**

| id | kind | cx | cz | across m | c | octagon vertices | notes |
|---|---|---|---|---|---|---|---|
| L1_atrium_north | octagon_dome_atrium | 85.5 | -112.9 | 17.9 | A | (81.7,-121.9) (89.2,-121.9) (94.4,-116.6) (94.4,-109.1) (89.2,-103.8) (81.7,-103.8) (76.5,-109.1) (76.5,-116.6) | octagonal void in the L2 floor with a glass dome above; on L1 it is open floor (railing arcs at its rim) |
| L1_atrium_south | octagon_dome_atrium | 85.4 | 19.6 | 17.9 | A | (81.7,10.5) (89.1,10.5) (94.3,15.8) (94.3,23.3) (89.1,28.6) (81.7,28.6) (76.5,23.3) (76.5,15.8) | as above; the 9 m wide ramp down to the garage zone C starts at its south side (x 85.4, z 14..31) |

Both are regular octagons about 17.9 m across, cut out of the L2 floor and covered by a glass dome on the roof; on L1 they are open floor with a railing arc on the rim. The north one sits in the middle of the north cross-gallery side, the south one at the start of the 9.8 m ramp down to garage zone C.

**Dock terraces (L1)**: two paved L1-level aprons on the east side, reached by the four outdoor ramps of section 4.6: `levels[1].terraces`.

| terrace | x | z | vertices | notes |
|---|---|---|---|---|
| L1_terrace_south | 110.9..278.6 | -22.9..211.6 | 17 | SVG First_Floor Pavament-1: paved L1-level apron east of the OLI wing, dock side |
| L1_terrace_north | 110.8..278.6 | -305.9..-71.1 | 17 | SVG First_Floor Pavament-1: paved L1-level apron east and north of the IDEA wing, dock side |

**Service**: docks and back-of-house areas are in 4.7.

### 4.4 L2 - upper (second) floor, y 36.6

Floor outline `levels[2].floor_outline` (249 vertices, SVG `Floor-2`): area 31,619 m2, x -25.5..155.8, z -170.1..77.5. It is a gallery ring around three voids (the two octagon atria and the central concourse void), with shops on the rim; there is no L2 over the three halls. Walls/blocks: 30 holes (10 walls, 10 partitions, 10 large blocks or voids of 6,324 m2). tarkov.dev calls it the "3rd Floor" layer (y 34..1000).

**Stores and rooms (31)**

| name (sign on the plan) | kind | cx | cz | w x d | rot | c | sells / holds | openings: side (x,z) width m |
|---|---|---|---|---|---|---|---|---|
| Father & Sons | clothing | 44.2 | -166 | 26.5 x 8 | 0 | C | men's clothing | S (50,-162) 4.2 |
| Tarkovstar | general | 11.7 | -145.6 | 13 x 10.8 | 0 | C | general retail | N (16,-151) 3 |
| Eastland | clothing | 55.8 | -143 | 14.4 x 13 | 0 | C | clothing | N (57,-150) 4.5 |
| Arena | sports | 11.6 | -130.4 | 15.9 x 12.8 | 90 | C | sports / gaming | S (12,-122) 11; W (5,-128) 4.2 |
| ТАРЗДРАВ (Tarzdrav) | pharmacy | 27.4 | -122.7 | 31.4 x 13.8 | 90 | C | pharmacy, medicines (loot: meds) | E (34,-128) 3.2 |
| МЕБЕЛЬ МК (Furniture MK) | furniture | 63.2 | -127 | 27.5 x 14.7 | 0 | C | furniture showroom | S (59,-120) 6; S (74,-120) 5.2; E (77,-122) 5.8 |
| Intourist | travel | 11.6 | -111.9 | 12.8 x 10.7 | 0 | C | travel agency | S (15,-106) 3.8 |
| Burger Spot (#49) | food | 115.2 | -92 | 35.5 x 14 | 0 | C | restaurant; the men's toilet with the urinal keypad (Saferoom exfil step 2) is inside this complex | N (115,-99) 35.5*; S (127,-85) 7.2; W (98,-98) 2.8 |
| ПУШКИН (Pushkin) | food | 115 | -73 | 24 x 16 | 90 | C | restaurant / cafe | S (122,-61) 1.5; E (123,-73) 24* |
| FCK | food | 14.4 | -89.9 | 18.4 x 7.8 | 0 | C | fast-food outlet | N (22,-94) 2; S (22,-86) 3.2 |
| McDaniels | food | 14.4 | -82.5 | 18.4 x 7 | 0 | C | fast-food outlet | N (22,-86) 3.2; S (22,-79) 3.2 |
| Tarducks | food | 14.4 | -65.8 | 18.4 x 9.5 | 0 | C | coffee shop | N (22,-70) 1.2; S (8,-61) 5.2; W (5,-64) 5.2 |
| Coffee Joy | food | 38.1 | -65.8 | 20.9 x 10.2 | 0 | C | coffee shop | S (38,-61) 6 |
| Jacob & Jacob | clothing | 65.5 | -68.1 | 27.5 x 14.7 | 0 | C | clothing / jewellery | S (61,-61) 4.8; S (69,-61) 4.8; E (79,-72) 2.8 |
| Sushi Huyushi | food | 14.4 | -25.1 | 18.4 x 5.7 | 0 | C | sushi restaurant | N (10,-28) 7; E (24,-25) 2.5 |
| Burger House | food | 14.4 | -18.9 | 18.4 x 6.8 | 0 | C | burger restaurant | S (22,-16) 2.5 |
| Shiccos | food | 14.4 | -11.4 | 18.4 x 7.2 | 0 | C | restaurant / cafe | N (22,-15) 2.5; S (22,-8) 2.5 |
| Underway | food | 99.2 | -21.5 | 25 x 15.6 | 90 | C | sandwich shop | W (92,-13) 3.8 |
| Philly Cute | food | 114.5 | -20 | 28 x 15 | 90 | C | restaurant | S (111,-6) 5; S (117,-6) 2.5; S (121,-6) 2.2; E (122,-26) 3.2; E (122,-7) 1.2; W (107,-7) 1.2 |
| МУЗЕЙ ИСТОРИИ (History Museum) | museum | 64.7 | 6 | 30.3 x 13 | 0 | C | museum of history | N (56,0) 11.5; N (68,0) 1.2; N (75,0) 6; S (61,12) 4.8; S (75,12) 6.2; E (80,7) 6.5 |
| Papillon | clothing | -11.7 | 18.2 | 35.5 x 9.8 | 90 | C | clothing / lingerie | E (-7,16) 3.8; E (-7,23) 3.2 |
| TECHLIGHT | electronics | -11.7 | 58.8 | 37.5 x 9.8 | 90 | C | large electronics store (laptops, GPUs, cables); best tech loot on L2 | E (-7,50) 3.2; E (-7,59) 2.8; E (-7,72) 10.8 |
| ЗАКРЫТО НА РЕМОНТ (Closed for repairs) | closed | 34.8 | 11.8 | 26.5 x 22.5 | 0 | D | shop closed for renovation (sign only) | N (22,0) 1.5; N (39,0) 4.8; S (41,23) 13.5*; E (48,18) 10.5; W (22,6) 12 |
| НА-СВЯЗИ (Na-Svyazi) | electronics | 11.7 | 36 | 16 x 13 | 90 | C | mobile phones / communications | N (10,28) 7.8; N (17,28) 2.2; W (5,34) 5 |
| СКОРО ОТКРЫТИЕ (Opening soon) | closed | 27.1 | 32.5 | 15 x 12.5 | 90 | C | shop 'opening soon' (sign only) | S (29,40) 6.8; E (34,31) 9.8 |
| АПТЕКА (Apteka) | pharmacy | 11.7 | 52.2 | 13 x 9.8 | 0 | C | pharmacy (loot: meds); old note: gas analyser, GM counter | S (16,57) 4.2 |
| SARA | general | 27.1 | 52.2 | 12.5 x 9.8 | 0 | C | general retail | S (23,57) 3.2 |
| Figaro | clothing | 63.2 | 32.1 | 27.5 x 14.3 | 0 | C | clothing / hair | N (58,25) 5; N (74,25) 5.5; E (77,29) 6.8 |
| Urban Clothes | clothing | 56.2 | 49.1 | 13.4 x 12.5 | 0 | C | clothing | S (56,56) 2.8 |
| Fashion Store | clothing | 44.2 | 72.5 | 26.5 x 10 | 0 | C | clothing | N (37,68) 3; N (50,68) 5 |
| ULTRA med (locked room) | locked store | 10.3 | 18.8 | 10.7 x 10.3 | 90 | C | ULTRA Apteka medical storage: medical loot (LEDX, ophthalmoscope, saline); power on + Ultra medical storage key | - |

Notes on special rooms (L2):
- **Burger Spot (#49)** (x 97.5..133, z -99..-85): the restaurant complex in the north-east corner of the upper floor; inside it the men's toilet holds the urinal that reveals the Object #11SR keycard panel (power must be on). The toilet's position inside the complex is not resolved (keengamer 2020: "top right corner of the second floor", toilet fixture opposite the door).
- **ULTRA med (locked room)** (x 5.2..15.5, z 13.4..24.1): dark room with the ULTRA med logo and a key tile on the plan; the ULTRA medical storage (power + key), medical loot. The "Closed for repairs" and "Opening soon" shops beside it are sign-only shops (no loot content known).
- **TECHLIGHT** (x -16.6..-6.8, z 40..77.5): the large electronics store on the west strip, south-west corner of L2; tarkovforge calls Techlight one of the "big stores".
- Food units on the rim: the fast-food strip FCK / McDaniels / Tarducks and Coffee Joy at x 5..48, z -94..-61; Sushi Huyushi / Burger House / Shiccos at x 5..24, z -28..-8; Underway and Philly Cute at x 91..122, z -34..-6; Pushkin at (107..123,-85..-61).
- Several shops have an unlabelled neighbour room (east of Tarkovstar x 20.5..34, z -151..-140; below McDaniels z -79..-71; below Shiccos z -6.6..0); they are included in the neighbours' notes only.

**Corridors and galleries (L2)**

| route | x | z | width m | JSON ids | notes |
|---|---|---|---|---|---|
| West gallery (N-S) | -16..5 | -159..62 | 9-21.5 | c0, c1, c4, c6, c7, c8, c14, c27 | the main N-S gallery, 21 m wide near the central void (z -93..-2); the west-edge shops (Papillon, Techlight) open onto it |
| North cross-gallery (E-W) | 35..95 | -161..-151 | 9.5 | c11, c29 | links the west gallery to the NE corner stair (143,-166) |
| Central cross-galleries (E-W) | -22..134 | -60..-34 | 5-7 | c18, c19, c20, c21, c28, c30, c31, c32 | two parallel balconies (z -60..-53 and -40..-34) either side of the central concourse void |
| Inner galleries (N-S) | 36..48; 79..91 | -155..-95; -103..-55 and -38..10 | 11-13 | c2, c10, c13, c16 | around the octagon atria |
| East gallery (N-S) | 122..134 | -85..14 | 8-12 | c3, c9, c17, c33 | eastern balcony, ends at the Burger Spot and Philly Cute |
| South cross-gallery (E-W) | -4..95; 101..133 | 57..67; 70..78 | 6.5-9.5 | c12, c22, c34 | south balcony to the SE corner stair (156,70) |
| Mid cross-galleries (E-W) | -6..76 | 0..25; -119..-94 | 9.5-12.5 | c5, c15, c23, c24, c26 | short links between the stair halls and the rim shops |

**Atria and voids on L2 (`levels[2].atria`)**

| id | kind | cx | cz | across / w x d m | c | notes |
|---|---|---|---|---|---|---|
| L2_atrium_north | octagon_dome_atrium | 85.5 | -112.9 | 17.9 | A | 18 m octagon cut out of the L2 floor; black on the re3mr plan |
| L2_atrium_south | octagon_dome_atrium | 85.4 | 19.6 | 17.9 | A | 18 m octagon; the "hole down to the parking" the guides mention is the L1 ramp under it |
| L2_void_central_concourse | void_over_concourse | 85.5 | -46.6 | 69 x 16.5 | B | SVG Floor-2 hole 15 (x 51..120, z -55..-38) plus hole 16 (x 5..38, z -53..-41): the opening over the central E-W concourse that the three escalator pairs cross |
| L2_void_food_court_north | large_void_or_closed_block | 44.9 | -83.1 | 68.7 x 46.3 | C | SVG Floor-2 hole 9: black on the plan, the L2 gallery ring and the FCK / McDaniels / Tarducks / Coffee Joy / Jacob & Jacob units sit on its rim |
| L2_void_south | large_void_or_closed_block | 42.1 | -10.8 | 74.8 x 46.2 | C | SVG Floor-2 hole 17 (153 vertices): black on the plan, Sushi Huyushi / Burger House / Shiccos / the museum units sit on its rim |

The three voids on the plan are black (no floor): the 69 x 16.5 m opening over the central concourse is crossed by the three escalator pairs; the two big black blocks (grade C) are either further voids or closed service blocks - the gallery ring and the food and museum units sit on their rims. The upper outline is **not closed** towards the halls: the Goshan and IDEA/OLI sides of the central block are walls.

### 4.5 Roof

Roof reachable: **no**. No stairs, ladders or doors to the roof appear on any plan or in any guide; the two octagon domes and ~40 skylights are visible from the air only. Roof height unknown (D). The SVG gives the footprints of the roof volumes only (`mall.outline_L2` above); the two octagon domes and the skylight rows over the galleries are visible on the aerial image.

### 4.6 Vertical circulation: stairs, escalators, ramps, elevators

| id | kind | joins | width m | low end / icon (x,z) | high end (x,z) | run m | rise m | slope | c | notes / source |
|---|---|---|---|---|---|---|---|---|---|---|
| V_ICON_0 | stair | L0-L1 | - | (177,-174) | - | - | - | - | C | Goshan garage stair (L0 up icon at (177,-174), L1 down icon at (182,-182)) |
| V_ICON_1 | stair | L0-L1 | - | (136,-49) | - | - | - | - | C | stair between the central block and Goshan (L0 (135,-49), L1 (138,-49)) |
| V_ICON_2 | stair | L0-L1 | - | (211,-48) | - | - | - | - | D | L0 icon only; stair inside the Goshan garage |
| V_ICON_5 | stair | L0-L1 | - | (-8,189) | - | - | - | - | D | OLI south-west stair (L1 icon) |
| V_L0_L1_0 | stair or ramp | L0-L1 | 9.8 | (85.3,30.8) | (85.3,15.1) | 15.7 | 5.7 | 20 deg | B | SVG Ground_Level ramp 131 + First_Floor ramp 241 |
| V_L0_L1_1 | stair or ramp | L0-L1 | 4.6 | (-3.4,-178.5) | (23.5,-178.5) | 26.9 | 5.7 | 12 deg | B | SVG Ground_Level ramp 132 + First_Floor ramp 244 |
| V_L0_L1_2 | stair or ramp | L0-L1 | 4.6 | (9.9,-257.8) | (24.4,-257.8) | 14.5 | 5.7 | 21 deg | B | SVG Ground_Level ramp 133 + First_Floor ramp 245 |
| V_L0_L1_3 | stair or ramp | L0-L1 | 4.6 | (-14,-46.8) | (0.9,-46.8) | 14.9 | 5.7 | 21 deg | B | SVG Ground_Level ramp 134 + First_Floor ramp 249 |
| V_L0_L1_4 | stair or ramp | L0-L1 | 4.6 | (8.9,93.9) | (23.8,93.9) | 14.9 | 5.7 | 21 deg | B | SVG Ground_Level ramp 135 + First_Floor ramp 247 |
| V_L0_L1_5 | stair or ramp | L0-L1 | 4.6 | (111.7,85.7) | (135.2,85.7) | 23.5 | 5.7 | 14 deg | B | SVG Ground_Level ramp 136 + First_Floor ramp 246 |
| V_L0_L1_6 | stair or ramp | L0-L1 | 4.6 | (273.8,-52.8) | (273.8,-41.3) | 11.6 | 5.7 | 26 deg | C | the L0 and L1 drawings disagree about which end is the low one; a stair is certain, the climb direction is not |
| V_L0_L1_7 | stair or ramp | L0-L1 | 4.6 | (96.6,-168.6) | (88.3,-168.6) | 10.9 | 5.7 | 28 deg | C | the L0 and L1 drawings disagree about which end is the low one; a stair is certain, the climb direction is not |
| V_L0_L1_8 | stair or ramp | L0-L1 | 4.6 | (94.4,72.9) | (83,72.9) | 11.4 | 5.7 | 27 deg | B | SVG Ground_Level ramp 139 + First_Floor ramp 254 |
| V_OUT_0 | vehicle ramp | ground-L1 | 7.3 | (273.8,-286) | (240.7,-286) | 33.1 | 5.7 | 10 deg | B | outdoor ramp from the apron (ground, y 21.4) up to the L1 dock terrace (y 27.1) |
| V_OUT_1 | vehicle ramp | ground-L1 | 7.3 | (269.5,-221.9) | (269.5,-190.4) | 31.5 | 5.7 | 10 deg | B | outdoor ramp from the apron (ground, y 21.4) up to the L1 dock terrace (y 27.1) |
| V_OUT_2 | vehicle ramp | ground-L1 | 7.3 | (269.4,129.7) | (269.4,94.5) | 35.2 | 5.7 | 9 deg | B | outdoor ramp from the apron (ground, y 21.4) up to the L1 dock terrace (y 27.1) |
| V_OUT_3 | vehicle ramp | ground-L1 | 7.3 | (273.9,191.1) | (241,191.1) | 32.9 | 5.7 | 10 deg | B | outdoor ramp from the apron (ground, y 21.4) up to the L1 dock terrace (y 27.1) |
| V_ICON_3 | stair | L1-L2 | - | (143,-166) | - | - | - | - | C | L1 icon (143,-166) with the L2 stair at (156,-167): NE corner stair of the upper floor |
| V_ICON_4 | stair | L1-L2 | - | (156,70) | - | - | - | - | C | L2 icon (156,70): SE corner stair of the upper floor; L1 end near (147,76) |
| V_L1_L2_0 | stair | L1-L2 | 4.6 | (26.7,-161.1) | (6,-160.9) | 18.8 | 9.5 | 27 deg | B | SVG First_Floor ramp 242 + Second_Floor ramp 257 |
| V_L1_L2_1 | stair | L1-L2 | 4.6 | (26.6,67.5) | (6.1,67.7) | 18.6 | 9.5 | 27 deg | B | SVG First_Floor ramp 248 + Second_Floor ramp 261 |
| V_L1_L2_2 | escalator or stair | L1-L2 | 4.6 | (18.3,-46.8) | (38.2,-46.6) | 19.7 | 9.5 | 26 deg | B | on the central concourse axis z -47: very likely the escalators the wiki mentions; the SVG does not separate up and down lanes |
| V_L1_L2_3 | escalator or stair | L1-L2 | 4.6 | (71.3,-46.9) | (51,-46.7) | 19.8 | 9.5 | 26 deg | B | on the central concourse axis z -47: very likely the escalators the wiki mentions; the SVG does not separate up and down lanes |
| V_L1_L2_4 | escalator or stair | L1-L2 | 4.6 | (99.7,-46.8) | (120,-46.6) | 20 | 9.5 | 25 deg | B | on the central concourse axis z -47: very likely the escalators the wiki mentions; the SVG does not separate up and down lanes |

- 24 connectors: 9 SVG stairs/ramps L0-L1 (plus 4 plan icons), 5 SVG stairs/escalators L1-L2 (plus 2 plan icons), 4 outdoor vehicle ramps ground-L1. "Low end" is the end at the lower level, decoded from the SVG ramp gradients; the L0 and L1 drawings of V_L0_L1_6 and V_L0_L1_7 contradict each other, so only their existence is certain (grade C).
- **Escalators**: the three 4.6 m wide L1-L2 connectors on the central axis z -47 (x 18.3..38.2, 51..71.3 and 99.7..120; 19.7-20 m run for 9.5 m rise = 26 deg) are almost certainly the escalators the wiki mentions ("middle of the mall near the escalators"; "first-floor escalator" at biligame 2020); 4.6 m is two 2.3 m lanes (one up, one down). Their direction pairs are not separated in the SVG. The two L1-L2 stairs at (6..27,-161) and (6..27,67.6) are 18.7 m long, 4.6 m wide ordinary stairs; the NE and SE corner stairs (143,-166) / (156,70) are plan icons only (grade C).
- **Vehicle ramps** (outdoor, 7.3 m wide, 5.7 m rise over 31.5-35.2 m = 9-10 deg, grade B): NE (273.8,-286) up to (240.7,-286), east-north (269.5,-222) up to (269.5,-190), east-south (269.4,130) up to (269.4,94.5) and SE (273.9,191) up to (241,191). They raise a truck from the ground apron (y 21.4) onto the dock terraces (y 27.1); the label "Ramps" is on the south-east one.
- **Elevators: none documented.** No elevator appears on any plan, in the SVG or in any guide (wiki: "Not mentioned: elevators"); patch 1.1.0.0 (2026-08-03) added "elevator doors" as an interactive mechanic, but no source places one in the mall. Freight lifts for the docks are not documented either. Grade C.
- **Garage-to-L1 stairs by location** (SVG, 4.6 m wide unless noted): (85.3,15..31) 9.8 m wide ramp; (-3..23.5,-178.5); (10..24,-258); (-14..1,-47); (9..24,94); (112..135,86); (274,-53..-41); (88..97,-169); (83..94,73). Icon stairs: (177,-174) Goshan garage, (136,-49), (211,-48), (-8,189).

### 4.7 Loading docks and service corridors

| dock | bays | pitch m | wall x | apex x | tooth m | bay apex z (8 teeth) | c |
|---|---|---|---|---|---|---|---|
| IDEA docks (north-east, L1 terrace) | 8 | 8.1 | 212.7 | 218.9 | 6.2 | -213.3, -221.4, -229.5, -237.6, -245.7, -253.8, -261.8, -269.9 | A |
| OLI docks (south-east, L1 terrace) | 8 | 8.1 | 212.5 | 218.9 | 6.4 | 119, 127.1, 135.2, 143.3, 151.4, 159.6, 167.6, 175.7 | A |

- Each dock is a sawtooth in the SVG floor outline: the east wall of the hall stands at x 212.6; every 8.1 m a tooth juts out 6.2-6.4 m to an apex at x 218.9 (slanted sides at about 45 degrees, 2.5-2.8 m of straight wall between teeth), so a truck backs in at an angle. 8 teeth per hall (IDEA z -213..-270, OLI z 119..176). The dock terraces (4.3) are at L1 level (y 27.1): the dock doors are at hall floor level. Dock door size and leveler are not in any source.
- **IDEA stock and back rooms** (x 160..210, z -299..-250): north-east part of the IDEA hall, partitioned (SVG walls); D
- **Goshan back-of-house** (x 210..260, z -168..-128): north-east corner of the Goshan hall behind the dividing wall at x 215; D
- **OLI stock block** (x 153..190, z 100..185): partitioned block behind the OLI hall, next to the docks; D
- **OLI west offices (administrator, logistics, outlet rooms)** (x -12..20, z 130..190): key doors (OLI administrator / logistics / outlet utility); D
- **Service level**: the garage is the service level (L0): trucks use the outdoor ramps to the L1 terraces, cars the ground-level aprons; the Scav Camp tunnel (x 115..210, z -73..-61) is the only enclosed service passage documented (it links garage zones B/C and the Goshan garage). No service corridor, staff stair or back-of-house corridor system is drawn in the SVG apart from the thin partition walls inside the three halls.
- Key registers: IDEA ~20, Goshan ~27 and OLI ~18 cash registers (key-locked; 1.2.0.0 changed their loot template); the standalone ULTRA store registers no longer need keys since 1.2.0.0.

### 4.8 Restrooms

Only one is documented: the Burger Spot men's toilet with the urinal keypad (Saferoom Exfil step 2). Rect on L2: x 97.5..133, z -99..-85 (the Burger Spot complex; exact position of the toilet inside it: not resolved, grade D). No other restroom is documented anywhere; the SVG has no toilet marks. Zero Return can place restrooms freely; EFT has no other public toilets in the data.

### 4.9 Power switch and what power changes

- **Switch**: Power Station main building (SVG building id 5, 26 x 19.6 m) at (288.3,-346.2), +-15 m, grade B. ggrecon 2022: inside the main building, just before the door to the office/waiting room; the tarkov.dev label "Power Station" sits at (269,-311); wiki: "illumination grid switchable at the power station"
- **Effects** (re3mr infographic text (2026-01), ggrecon (2022-07-05), wiki, eft-ammo):
  - lights start working in the mall (partial) and arcade machines play sounds
  - unlocks / enables: Kiba Arms store doors (both keys need power), the Terragroup container (Object #21WS keycard), Object-14, the ULTRA Apteka medical storage on L2, the Burger Spot urinal keypad (Saferoom Exfil step 2), the Saferoom exfil itself
  - Power Station V-Ex: patch-era dependent; the re3mr legend lists it as "requires payment" only
- **Alarms**: Opening the Kiba door triggers a store alarm about 3 s later (tarkovforge key page); it can be disabled at a security-room terminal on the first floor. Position of the Kiba alarm siren ((98.8,-20.8), grade C) is the store itself; the "designated alarm terminals" (one per floor, biligame 2020 and wiki) are drawn as stars on the pre-0.12.4 Lorathor map at about (190,75) on L1 and (127,-45) on L2 (+-30 m, grade D): not on the 2026 plans.
- Other state changes: the keycard doors and the Saferoom are the only gameplay locks tied to the power switch; whether ceiling lights or the escalators change state with power is not documented beyond "lights start working (partial)". Once thrown the switch stays on for the raid (wiki, keengamer: "if the lights are already on someone else flipped it").

## 5. Floors and heights

One table for every level, then what the numbers rest on. All y values are game y (the same y the SPT spawn points and tarkov.dev layer windows use); "above ground" is y minus the outdoor plain (21.4). The build spec for the Roblox map converts with studs = metres x 3.125.

### 5.1 Levels

| level | floor y | above ground m | ceiling y | clear height m | basis | grade |
|---|---|---|---|---|---|---|
| Outdoor plain, mall apron, aprons of all four docks | 21.4 | 0 | - | - | SPT scav/PMC spawn heights at x -199..470 (80 of 155 samples at 21.0-21.9) | B |
| L0 garage / car park (SVG `Garage`, floor outline 80,753 m2) | 21.4 | 0 | 26.6 | 5.2 (assumed) | floor = the outdoor ground; ceiling = L1 floor minus an assumed 0.5 m slab | floor B, ceiling D |
| L1 main floor (SVG `First_Floor`, 120,142 m2) and the two dock terraces | 27.1 | 5.7 | 36.1 | 9.0 under the L2 ring (assumed) | SPT medians 27.06-27.30; the terraces are at the same y (spawn points at y 27.13-27.23 outside the mall outline) | floor B, ceiling D |
| L2 upper floor (SVG `Second_Floor`, 31,619 m2) | 36.6 | 15.2 | - | unknown | SPT medians 36.58-36.73 (9 spawn points, all inside the L2 floor outline) | floor B, ceiling D |
| Roof (central block and the three halls; two glass domes, about 40 skylights) | - | - | - | - | not in any source; not reachable (section 4.5) | D |

- **Floor-to-floor**: L0 to L1 5.7 m, L1 to L2 9.5 m (L0 to L2 15.2 m). The L1 to L2 rise is the same for the escalators (three pairs, 19.7-20 m run), the two ordinary stairs and the corner stairs; the L0 to L1 rise of 5.7 m is the same for the nine stair/ramp connectors and the four outdoor vehicle ramps (section 4.6).
- **The garage is not underground**: its floor is the outdoor ground (y 21.4) and its east side is open to the aprons; the L1 sales floor sits 5.7 m above ground on top of it, which is why the dock terraces and the outdoor ramps exist. SPT calls the L0 loot group `UndergroundParking`, the wiki says "not mentioned: underground parking", the 1.0 re3mr plan calls the level PARKING. Zero Return should build it as a ground-level hall with a 5.2 m clear height and a thick (5.7 m) structural floor zone above, not a basement.
- **No level below the garage and no level above L2**: no basement, tunnel or mezzanine appears on any plan. The only enclosed rooms below L1 are the hidden Saferoom, the Object-14 room and the service tunnel in the garage (section 4.2), all at ground level.
- **Slab thickness, ceiling heights, parapet and railing heights, door heights, pillar sizes, roof height: none of them is in any source (grade D).** The 0.5 m slab is my assumption: with it the L1 clear height under the L2 ring is 9.0 m (a tall mall atrium level) and the garage clear height 5.2 m. If the builder prefers a lower garage, keep the 5.7 m L0 to L1 spacing so the stairs, ramps and terraces stay at their measured rise.

### 5.2 What the heights were measured from

| level | SPT points | y min | y median | y max | where |
|---|---|---|---|---|---|
| L0 / ground | 36 | 21.33 | 21.42 | 21.57 | garage zones, aprons, outdoor points inside the mall bounding box |
| L1 / terraces | 54 | 27.06 | 27.15 | 27.3 | IDEA, Goshan and OLI halls, central block, dock terraces |
| L2 | 9 | 36.58 | 36.63 | 36.73 | all 9 points lie in the L2 floor outline: ZoneCenter (4 normal, 3 boss points) and ZoneCenterBot (1 normal, 1 boss) |

The registration was checked with these points: of the 54 spawn points at L1 height inside the mall bounding box 48 lie inside the SVG L1 floor outline and 6 on the south dock terrace (x 217..231, z 207..210, y 27.23, and (220.8,161.2)), none inside a wall or block hole; all 9 points at L2 height lie inside the L2 floor outline and none in a hole. So the frame transform (section 0), the floor outlines and the level heights agree to the metre. Spawn y is the standing height of the player root, i.e. the floor, +-0.3 m (the median within a level varies by that much between zones).

### 5.3 tarkov.dev layers (how the community map splits the levels)

| tarkov.dev layer | SVG group | player y window | extent | shows |
|---|---|---|---|---|
| ground (default) | Ground_Level | -1000 .. 25 | whole map | garage, aprons, everything outdoors |
| "2nd Floor" | First_Floor | 25 .. 34 | mall box, frame x -37.5..304.5, z -319..226 (game [[120,218],[-222,-327]]) | L1 and the dock terraces (the tarkov.dev floor numbering counts the garage as the 1st floor) |
| "3rd Floor" | Second_Floor | 34 .. 1000 | same mall box | L2 |

The window edges (25 and 34) lie 2.1 m below the L1 floor (27.1) and 2.6 m below the L2 floor (36.6), so each layer switches on a little before a player reaches the floor. They carry no ceiling data. There is no 4th layer, so nothing is drawn above the L2 gallery level.

### 5.4 Vertical connectors at a glance

| group | count | width m | run m | rise m | slope |
|---|---|---|---|---|---|
| ordinary stairs/ramps L0-L1 (SVG) | 9 | 4.6..9.8 | 10.9..26.9 | 5.7 | 12..28 deg |
| vehicle ramps ground to L1 terrace (SVG) | 4 | 7.3..7.3 | 31.5..35.2 | 5.7 | 9..10 deg |
| escalators L1-L2 (three pairs on z -47) | 3 | 4.6..4.6 | 19.7..20 | 9.5 | 25..26 deg |
| ordinary stairs L1-L2 (SVG) | 2 | 4.6..4.6 | 18.6..18.8 | 9.5 | 27..27 deg |
| stairs known from plan icons only | 6 | - | - | - | - |

The SVG ramp strokes give the floor length each stair occupies: 10.9-26.9 m for the 5.7 m L0-L1 stairs (12-28 degrees on paper) and 18.6-18.8 m for the two L1-L2 stairs. An ordinary stair at 30-35 degrees needs only 8-10 m of run for 5.7 m, so the longer strokes probably include landings; treat the run as the available floor space and the rise as exact. No stair has a step count, riser height, handrail or landing in any source.

### 5.5 Outdoor heights that matter for the mall

- Dock terraces and the four vehicle ramps: terraces at y 27.1 (+5.7 m), ramps 7.3 m wide rising 5.7 m over 31.5-35.2 m (9-10 degrees); their guard walls and the dock door heights are not in any source.
- The ring of aprons around the mall is flat at y 21.4 on all sides except the south-east, where the ground climbs to y 25 at (280,283) (section 3.1).
- Idea Tower and Oli Tower: only their base huts are drawn; tower heights are unknown (D). The Power Station buildings and the go-kart pit are single boxes with no height.
- Highest walkable level in the whole map: the L2 gallery (y 36.6, 15.2 m above ground); the roof is closed. There is no sniper perch above the L2 level.

## 6. Extracts and transits

Position = best point in the frame; `err` = stated uncertainty radius in metres; `c` = grade (section 0). Timers are the SPT `ExfiltrationTime`; "group" is the PMC entry point whose extract list contains the exit (SPT `EntryPoints`: a PMC that starts in the MallNW half (north strip and west side) is offered the south-east exit and vice versa; shared exits list both). **Seven extracts and two active transits** exist in the 2026 sources; tarkovforge (2026) lists nine rows because Railway Exfil and Emercom Checkpoint appear once for PMCs and once for Scavs. The extract icon positions are the re3mr 2026-01 aerial icons (+-3 m), the points in the JSON are my best "use" points. The SPT server data has no exit positions or trigger sizes, and the 2026 sources give none either: **trigger zone sizes are unknown (D)**.

| extract | side | PMC group | x | z | err | c | condition (paraphrased) | chance % | timer s |
|---|---|---|---|---|---|---|---|---|---|
| Railway Exfil | pmc + scav | MallSE half (SPT "NW Exfil"); re3mr 2026: neutral | -394.1 | -420.4 | 6 | B | none, always open | 100 | 8 |
| Emercom Checkpoint | pmc + scav | MallNW half (SPT "SE Exfil"); re3mr 2026: neutral | 399.1 | 278.4 | 6 | B | none, always open | 100 | 8 |
| Power Station V-Ex (vehicle) | pmc | both | 355.9 | -359.6 | 8 | B | pay roubles per player (5,000 in wiki and SPT; 20,000 in the re3mr 2026-01 text; 3,000-4,000 in 2020 sources), max 4 players per car, stay next to the car or it leaves without you; fee depends on Scav karma; each use +0.2 karma (re3mr) | SPT 50; wiki "always" | 60 shared |
| Saferoom Exfil (hidden room) | pmc | both | 164 | 24.7 | 6 | B | mall power on (Power Station switch) > flush the urinal in the Burger Spot men's toilet (L2) > swipe the Object #11SR keycard at the revealed panel > walk to the padlocked door at (132,55) in garage zone C > inside, close the door with the button; a lever inside opens the Object-14 container | 100 | 3 (manual) |
| Scav Camp (Co-Op) | scav + any PMC | both | 175.9 | -67.1 | 8 | B | a player Scav and a PMC (any) at the zone together; scav karma +0.25 with diminishing returns (re3mr) | 100 | 8 shared |
| Path to River (flare) = "Smuggler's Tunnel" | pmc | both | -439 | 91.5 | 20 | B | fire a green flare (flare pistol cartridge or handheld flare) straight up between the two power lines beside the toll booth and barricade, then run past the "Evac" sign; added with 1.0, not in the SPT data | 100 (assumed) | unknown |
| Hole in the Fence | pmc | both | 303 | -70 | 25 | D | backpack slot empty (SPT `RequiredSlot` Backpack, passage requirement "Empty"); **status in 2026 uncertain, see below** | 100 | 10 |

Notes per extract (everything the JSON `extracts[]` records also holds the full source list and the conflicts):

- **Railway Exfil** (-394.1,-420.4) +-6 m, grade B: north-west corner, inside the top tab of the playable polygon (x -417..-363, z to -433); next to the west double railway line (rails reach the north edge at x -387/-380)
- **Emercom Checkpoint** (399.1,278.4) +-6 m, grade B: south-east corner, beside the Emercom checkpoint buildings (SVG ids 47, 49); progameguides: stand near the green truck. The Emercom camp (tents) is 190 m west at (190..220, 218..270)
- **Power Station V-Ex** (355.9,-359.6) +-8 m, grade B: north-east corner next to the sniper band, 68 m east of the Power Station main building. Cost by source: 3,000 (Lorathor, pre-0.12.4), 4,000 (Prima 2020-01-16), 5,000 (wiki undated, SPT, ggrecon 2022-07-05, progameguides 2023-03/07), 20,000 (re3mr infographic 2026-01). SPT: 50 % chance the exit is offered, 60 s timer, TransferItem 5,000 roubles, 4 players. re3mr: +0.2 scav karma per use
- **Saferoom Exfil** (164,24.7) +-6 m, grade B: ground-level hidden room east of garage zone C (the SVG draws the block as solid); room size not drawn. Wiki lists it as non-single-use; keengamer (2020) says the unlocked door is on the left after the hole in the wall
- **Scav Camp (Co-Op)** (175.9,-67.1) +-8 m, grade B: inside the ground-level tunnel between garage zone B/C and the Goshan garage (x 115..210, z -73..-61). Conflict: older sources put the zone at the west/highway camp (Lorathor; tarkov.dev label "Scav Camp" at (-181,-3)) or "opposite the entrance to the ULTRA supermarket" (progameguides 2023); the re3mr 2026-01 map puts the icon in the garage
- **Path to River (flare)** (-439,91.5) +-20 m, grade B: far west edge, past the highway, on the dirt road west (gravel #1 (-323,149) > (-521,79)); the re3mr text: "head down the dirt road west until exfil starts". ingamenews: the tunnel entrance is in an embankment near the railway tracks (the icon is 151 m west of the nearest drawn rail). Prima (1.0 launch): from the Railway Exfil follow the tracks south, cross freight containers used as bridges to a large camp, turn left; the checkpoint (blue container with a red star) is at the north-east corner of the camp - the icon lies 27 m west of the westmost hut of the west camp (huts #28..#38), i.e. at its north-west side, so the two descriptions disagree by about 100 m. The flare zone itself is not drawn in any source I can read
- **Hole in the Fence** (303,-70) +-25 m, grade D: behind the ULTRA market, on the east service lane near green/brown drums and an orange oil tanker (progameguides 2023); the east service lane pad is at (290..306, -39..15). The SVG east service-lane fence (fence_16..24, x 297..337) has several gaps: the 46 m gap between fence_18 and fence_19 at z -91..-45 contains this point; other candidates are z -150..-115, -10..3, 20..51 and 71..80 (the 6 m gap at (337,131..137) is the Wall Break label, a different feature). NOT in the re3mr 2026-01 legend: either removed by the 1.0 expansion or left off the infographic. SPT/wiki/tarkovforge all still list it

**Path to River route cues (1.0 guides, thegameslayer and Prima, 2025-11)**: from the mall parking lot cross the highway towards the railway; open freight carriages stand on the right of the track; a hill path leads left; a metal grate and a sign reading Terragroup Labs on the right; then right along the path to a **toll booth with a barricade**, the flare spot is "right beside the toll booth and the barricade", aiming up between the two power lines; the Evac sign is just beyond. Prima describes a different approach (follow the tracks towards the Customs transit, cross freight containers that act as bridges to a large camp, turn left, the checkpoint is a blue freight container with a red star in the camp's north-east corner). The re3mr icon (-439,91.5) lies on the dirt road west (gravel #1), 1.5 m west of the westernmost of the two N-S power lines (x -437.5 and -419.4 at z 91.5) and 27 m west of the westernmost west-camp hut (#29); the dirt road crosses the N-S gravel track #2 at (-428,90), exactly between the two power lines, so the **flare spot is most likely that crossing, (-428,90), with the toll booth probably hut #29 (-408,91) or #30 (-412,103)** (inference from the guide text and the SVG, grade C; the barricade is not drawn). The extract itself is a concrete tunnel mouth in an embankment near the map edge (ingamenews). Scavs cannot use it (PMC only in every source); single use per raid (ingamenews, as recorded in the JSON).

**Hole in the Fence, 2026 status**: SPT, the wiki and tarkovforge (2026) still list it and a Prima article of the 1.0 era (late 2025) names "the former Hole in the Fence extraction" as a landmark on the way to a small forest camp, closer to the Emercom Checkpoint than the Power Station, which suggests it was removed or changed with the 1.0 expansion; the re3mr 2026-01 legend (the newest map) has no such icon. Position (303,-70) comes from a 2023 description (east service lane, near drums and an oil tanker); it is the 46 m gap in the east service-lane fence between fence_18 and fence_19. Build it as an optional extract and log the uncertainty (grade D).

### 6.1 Scav side

| scav exit | SPT record | position | other sources |
|---|---|---|---|
| Railway Exfil | SPT `NW Exfil` (Side Scav), 100 %, 8 s | same icon as the PMC exit (-394.1,-420.4) | tarkovforge 2026: Railway Exfil (Scav) |
| Emercom Checkpoint | SPT `SE Exfil` (Side Scav), 100 %, 8 s | same icon as the PMC exit (399.1,278.4) | tarkovforge 2026: Emercom Checkpoint (Scav) |
| Scav Camp (Co-Op) | SPT `Interchange Cooperation` (Side Coop), shared timer 8 s, requirement ScavCooperation | garage tunnel (175.9,-67.1) | wiki: "Player Scav + any PMC"; open to every Scav |

A Scav has **no exit of its own beyond these three**: no scav-only gate, no key exit. SPT base.json carries `DisabledScavExits = "scav_NW,scav_SE"` (meaning not documented; the wiki and tarkovforge 2026 list both scav exits as usable, so I read it as the names of the two scav exit objects, not as closed exits; unverified, section 10). The SPT raid length is 40 minutes for every player type (co-op 30); the Scav player spawn points are the scav zones of section 7.

### 6.2 Transits (to another map without returning to the hideout)

| transit | SPT id -> target | to | x | z | err | c | opens after s | timer s | where |
|---|---|---|---|---|---|---|---|---|---|
| Transit to Streets of Tarkov | INT_TRANSIT_7 -> TarkovStreets (5714dc692459777137212e12) | Streets of Tarkov | -183.9 | -421 | 8 | B | 60 | 20 | north end of the highway, between the two carriageways (x -193 and -172), inside the top tab of the playable polygon |
| Transit to Customs | INT_TRANSIT_6 -> bigmap (56f40101d2720b2a4d8b45d6) | Customs | -193 | 430 | 25 | C | 60 | 20 | south end of the highway; the icon sits on the bottom edge of the aerial (z 434), the playable polygon ends at z 405, so the real trigger zone is probably at z 395-405 |
| NY_FINAL (inactive event transit) | NY_FINAL id 42, location Interchange -> Interchange | Interchange | - | - | - | D | 300 | 20 | SPT lists an inactive new-year event transit back to the same map; no position |

- Both live transits are `active: true` in SPT, become available **60 s after the raid starts** and run a 20 s timer; once a transit is activated no other extract can be used and the player loses stash access until the next hideout visit (re3mr 2026-01, Prima). They are not tied to a spawn group.
- Prima (patch 0.16.8, before 1.0): "Interchange to Customs: outside the mall at the OLI corner, towards the railroad tracks, opposite the Railway Exfil"; "to Streets of Tarkov: between the Railway Exfil and the IDEA entrance, next to the main road, a common PMC spawn". Both descriptions fit the two icons (the Streets one is on the north tab of the highway, 210 m from the Railway Exfil; the Customs one is at the highway's south end, the only icon on the south edge). Customs is the weaker position: the icon sits on the aerial's bottom edge (z 430) while the playable polygon ends at z 405, so the real trigger is probably at z 395-405 (err 25 m).
- `NY_FINAL` (id 42) is an **inactive** new-year event transit that points back at Interchange itself (activate after 300 s, 20 s); it has no position and no building should carry it.
- Transit trigger sizes and any visuals (gate, sign, vehicle) are not in any source.

### 6.3 Names and ids

| display name (2026) | SPT name | other names |
|---|---|---|
| Railway Exfil | NW Exfil | railway exit, northwest exit (wiki) |
| Emercom Checkpoint | SE Exfil | southeast exit (wiki), Emercom camp checkpoint |
| Power Station V-Ex | PP Exfil (item id of the payment 5449016a4bdc2d6f028b456f = roubles) | Power Plant exit |
| Saferoom Exfil | Saferoom Exfil (tip text EXFIL_INTERCHANGE_SAFEROOM_TIP) | safe room, Object #11SR exit |
| Hole in the Fence | Hole Exfill (tip EXFIL_INTERCHANGE_HOLE_TIP) | fence gap |
| Scav Camp (Co-Op) | Interchange Cooperation (tip EXFIL_Cooperate) | Scav Camp |
| Path to River (Flare) | not in SPT | Smuggler's Tunnel (Prima, ingamenews, thegameslayer 2025-11) |

### 6.4 Distances (frame metres, straight line)

|  | Railway | Emercom | V-Ex | River | Hole | Saferoom | Co-op | mall centre (130,-47) |
|---|---|---|---|---|---|---|---|---|
| Railway | 0 | 1057 | 752 | 514 | 780 | 714 | 671 | 644 |
| Emercom | 1057 | 0 | 639 | 859 | 361 | 346 | 411 | 422 |
| V-Ex | 752 | 639 | 0 | 914 | 294 | 430 | 343 | 386 |
| River | 514 | 859 | 914 | 0 | 759 | 607 | 635 | 586 |
| Hole | 780 | 361 | 294 | 759 | 0 | 168 | 127 | 175 |
| Saferoom | 714 | 346 | 430 | 607 | 168 | 0 | 93 | 79 |
| Co-op | 671 | 411 | 343 | 635 | 127 | 93 | 0 | 50 |

The two corner exits are 1057 m apart. The exit a PMC is always offered lies far away from its spawn: the 13 north/west spawn clusters are 597-926 m (median 757) from the Emercom Checkpoint and the 12 south/east clusters 766-1067 m (median 875) from the Railway Exfil, straight line (SPT data, old playable area; section 7). The other corner exit is much closer: 163-792 m from the north/west clusters to the Railway Exfil and 22-497 m from the south/east clusters to the Emercom Checkpoint, but it is not offered to them (SPT rule; the 2026 sources call both exits neutral, so Zero Return must decide). All distances ignore the mall, the highway and the minefield.

## 7. Spawns, bosses, bots, hazards, airdrops, raid settings

Everything tagged "SPT" comes from the SPT server database (`locations/interchange/base.json`, HEAD fe74b07 of 2026-08-10, built for the 0.16-era client). Its coordinates are exact, but it describes the **old playable area only** (468,825 m2): 248 of its 252 spawn rows lie inside `boundary.pre_1_0_polygon` and the other four sit on its west edge, 0.2-0.5 m outside. The 1.0 strips (west strip x -472..-199, east strip with the north-edge notch x 134..467, section 2) therefore have **no SPT spawn, zone or boss data**; the only 2026 placement data for them are the re3mr icons (25 PMC rings, 10 AI scav icons, boss icons). Spawn `facing` in the JSON is a yaw in degrees measured from +x towards +z (0 east, 90 south).

### 7.1 PMC spawn points (PvP raid)

65 + 60 = 125 PMC spawn points (SPT category `Player`, side `Pmc`), always in **clusters of 5** (13 + 12 = 25 sites; the 5 points of a site lie within 2-7 m of its centre). Each point carries a 50 m spawn sphere and a 4 s delay (`ColliderParams.Radius`, `DelayToCanSpawnSec`: a spawner is placed only if no other player stands inside the sphere; the exact rule is not documented); map-wide `MinDistToFreePoint` 50 m, `MaxDistToFreePoint` 170 m, `MinDistToExitPoint` 30 m. All 125 points are in JSON `spawns.pmc_group_*.points` as (x, z, y, facing).

**Entry groups.** The SPT field `Infiltration` splits the points into **MallNW** (65) and **MallSE** (60). The names are halves of the perimeter, each an L-shape wrapped round its corner: **MallNW = the whole north edge (including the NE corner at the Power Station) and the west side down the highway to z 346**, **MallSE = the east side and the south edge**. A fitted rule (MallNW if z < -250 or x < -190, else MallSE) reproduces the group of 125 of the 125 points. The group decides the extract list: a MallNW spawner is offered the south-east exit (Emercom Checkpoint), a MallSE spawner the north-west exit (Railway Exfil), i.e. always the far corner (SPT `EntryPoints`, section 6; the 2026 sources call both exits neutral). Terrain: all 25 sites are outdoors and their y follows the ground (14.8-25.3); the north-west lowland sites (-302,-286), (-283,-180), (-233,-129) lie 4-7 m below the 21.4 plain, the site at (280,283) climbs to y 25, and one site, (224,208), stands on the south L1 dock terrace (y 27.2) outside the mall walls. No site is inside the mall. BEAR and USEC share the same points.

| group | x | z | y | points | where (nearest feature) |
|---|---|---|---|---|---|
| MallNW | -302.2 | -285.6 | 14.8..15.3 | 5 | 86 m E of Railway Exfil rails |
| MallNW | -282.7 | -179.7 | 16.6..16.8 | 5 | 20 m SE of north-west swamp |
| MallNW | -232.6 | -129.1 | 16.8..17.3 | 5 | 91 m SE of north-west swamp |
| MallNW | -214.9 | -414.2 | 21.4..21.8 | 5 | 32 m W of Transit to Streets of Tarkov |
| MallNW | -201.4 | 95.2 | 21.4..21.4 | 5 | by road: highway, west carriageway |
| MallNW | -196.4 | -1.1 | 21.4..21.4 | 5 | at highway roadside booth (old Scav Camp area) |
| MallNW | -194.2 | 346.3 | 21.4..21.4 | 5 | by road: highway, west carriageway |
| MallNW | -150.1 | -280.4 | 19.6..19.9 | 5 | 85 m NW of Go Kart |
| MallNW | -67.5 | -402.6 | 19.5..20 | 5 | 114 m NW of mall NW corner |
| MallNW | -27.1 | -346.8 | 19.9..20.1 | 5 | 48 m N of mall NW corner |
| MallNW | -12.1 | -405.8 | 21.6..21.7 | 5 | 73 m NW of Idea Tower |
| MallNW | 98.4 | -393.5 | 21.8..22.6 | 5 | 76 m NE of Idea Tower |
| MallNW | 250.4 | -382.8 | 21.4..21.4 | 5 | 74 m N of Power Station |
| MallSE | -85.2 | 391.8 | 22.3..22.9 | 5 | 114 m E of Transit to Customs |
| MallSE | 22.8 | 276.5 | 21.4..21.4 | 5 | on south container yard (east) |
| MallSE | 79.7 | 261.9 | 21.4..21.4 | 5 | on south container yard (east) |
| MallSE | 159.1 | 296.4 | 22.4..22.9 | 5 | 70 m SW of Emercom camp |
| MallSE | 224 | 208.1 | 27.2..27.2 | 5 | L1 dock terrace |
| MallSE | 267.1 | 141.5 | 21.4..21.4 | 5 | on south-east dock apron (OLI docks, ramp up to the L1 terrace) |
| MallSE | 280.2 | 282.7 | 24.9..25.3 | 5 | 73 m S of mall SE corner |
| MallSE | 286.9 | -69 | 21.4..21.4 | 5 | by road: east mall road (N-S, x 264..287) |
| MallSE | 299.1 | 13.2 | 21.4..21.4 | 5 | on east service lane pad |
| MallSE | 333.9 | 65.5 | 21.4..21.4 | 5 | on east truck lot |
| MallSE | 403.2 | 153.2 | 22.4..23.6 | 5 | 64 m E of Wall Break |
| MallSE | 419.5 | 269.5 | 21.4..22.1 | 5 | at Emercom Checkpoint building |

#### The 2026 PMC spawn rings (re3mr infographic, 25 dotted circles, +-3 m)

| # | x | z | area | group (rule above) | SPT site within 60 m (its group, distance) | where |
|---|---|---|---|---|---|---|
| 1 | -166 | -424 | old area | NW | NW 50 m | by road: highway, east carriageway |
| 2 | -291 | -389 | old area | NW | - | near label "Highway Construction" (6 m) |
| 3 | -68 | -404 | old area | NW | NW 1 m | 115 m NW of mall NW corner |
| 4 | -12 | -410 | old area | NW | NW 4 m | 76 m NW of Idea Tower |
| 5 | 48 | -386 | old area | NW | NW 51 m | near label "Idea Tower" (37 m) |
| 6 | 145 | -389 | **1.0 strip** | NW | NW 47 m | 116 m E of Idea Tower |
| 7 | 254 | -403 | **1.0 strip** | NW | NW 21 m | 93 m N of Power Station |
| 8 | -340 | -292 | old area | NW | NW 38 m | 48 m E of Railway Exfil rails |
| 9 | -268 | -191 | old area | NW | NW 19 m | 32 m E of north-west swamp |
| 10 | -260 | -96 | **1.0 strip** | NW | NW 43 m | 102 m SE of north-west swamp |
| 11 | 352 | -302 | **1.0 strip** | NW | - | 58 m S of Power Station V-Ex |
| 12 | 362 | -183 | **1.0 strip** | SE | - | 127 m NE of Hole in the Fence |
| 13 | 388 | -107 | **1.0 strip** | SE | - | 93 m NE of Hole in the Fence |
| 14 | -199 | -9 | old area | NW | NW 8 m | near label "Scav Camp" (19 m) |
| 15 | -214 | 110 | **1.0 strip** | NW | NW 19 m | 118 m S of highway camp (old Scav Camp label) |
| 16 | -226 | 330 | **1.0 strip** | NW | NW 36 m | by road: south-west gravel track |
| 17 | -75 | 379 | old area | SE | SE 16 m | 107 m SW of Cargo Containers |
| 18 | -72 | 288 | old area | SE | - | on south-west container yard (Terragroup container) |
| 19 | 72 | 322 | old area | SE | - | 58 m E of Cargo Containers |
| 20 | 176 | 295 | old area | SE | SE 17 m | 60 m SW of Emercom camp |
| 21 | 278 | 285 | old area | SE | SE 3 m | 75 m S of mall SE corner |
| 22 | 423 | 270 | old area | SE | SE 4 m | 25 m E of Emercom Checkpoint |
| 23 | 382 | 115 | **1.0 strip** | SE | SE 44 m | near label "Wall Break" (43 m) |
| 24 | 320 | 19 | **1.0 strip** | SE | SE 22 m | 38 m SE of east service lane |
| 25 | 393 | 4 | **1.0 strip** | SE | - | 87 m W of sniper band (east) |

11 of the 25 rings lie in the 1.0 strips (#6, 7, 10, 11, 12, 13, 15, 16, 23, 24, 25): 3 on the west side (#10, 15, 16), 2 on the north edge (#6, 7), 6 on the east side (#11, 12, 13, 23, 24, 25). **The 2026 layout is not the SPT layout**: only 5 rings coincide with an SPT site within 12 m (#3, 4, 14, 21, 22) and 11 within 25 m, and 14 of the 25 SPT sites have no ring within 25 m (among them both sites on the south-east dock apron and terrace, (267,141) and (224,208), and (-150,-280) at the Go Kart). Neither list carries a faction. **Use for the rebuild**: the 25 rings as the site centres of the 1.0 map (they cover the whole playable area, none inside the mall), with the SPT sites as local detail (ground y, facing, a 5-point pattern); group each ring by the rule above (grade C, no source states the group of a ring).

### 7.2 Co-op and PvE-raid starts (SPT categories `Coop` + `Group` and `Coop` + `Opposite`)

| category | points | x | z | entry names |
|---|---|---|---|---|
| Coop + Group | 22 | 75..98 | -124..-96 | MallSE 12, MallNW 10 |
| Coop + Opposite | 24 | -28..263 | -326..160 | MallNW 13, MallSE 11 |

- **Coop + Group** (22 points, position grade A; the purpose is inferred from the category names, grade C; sphere 50 m, delay 4 s): all on L1 (y 27.15) in one blob (x 75..98, z -124..-96, centroid (85.4,-111.1)) round the **north octagon atrium** (85.5,-112.9). It is the group start of a co-op (Scav plus PMC) or PvE-group raid and lies **inside the mall on the main floor, north of the central concourse**. Its MallNW (10) and MallSE (12) tags overlap on the same blob, so treat it as one start area.
- **Coop + Opposite** (24 points, same grading; sphere 100 m, delay 4 s): 13 in the north-west corner (x -28..-22, z -326..-313, facing 50, on the north ring road and the west mall road just outside the mall corner) and 11 on the east side (x 260..263, z 141..160, facing 191, on the south-east dock apron). It reads as the start on the other side for the second member of a co-op pair; the MallNW tag goes with the north-west points and MallSE with the east ones.

### 7.3 Scav zones and waves (pre-1.0)

| zone | scav pts | boss-capable pts | AI-PMC pts | where the points are |
|---|---|---|---|---|
| ZoneOLIPark | 2 | 1 | 0 | L0 garage D (south central parking), x 109..111, z 83..90 |
| ZoneOLI | 5 | 4 | 0 | L1 OLI hall: west end (9..12, 179) and centre (160..176, 86..148); 2 normal points in garage D (109..113, 90) |
| ZoneCenterBot | 2 | 3 | 0 | L1 Generic (beside Kiba) and Revis, L2 Jacob & Jacob and the L2 corridor; first of Killa's five zones, the only zone with a PvP scav wave |
| ZoneRoad | 2 | 2 | 1 | highway camp on the west carriageway (booths), x -199..-170, z 7..36; one AI-PMC point at (-160,102) |
| ZoneCenter | 4 | 3 | 0 | L2 food court and west shops (Jacob & Jacob, McDaniels, Burger House, Sushi), x 22..68, z -83..-21 |
| ZoneGoshan | 6 | 3 | 0 | L1 Goshan hall east end (238..244, z -77..-28) and the corridor/Bizarro at its west end (x 152, z -92..-19) |
| ZoneIDEAPark | 3 | 2 | 12 | L0 central parking, north halls A/B (x -8..2, z -198..-160); the 12 AI-PMC points are scattered outdoors over the north strip and the west side |
| ZonePowerStation | 4 | 0 | 4 | Power Station main building and yard sheds (x 290..336, z -371..-347); AI-PMC points at (252,-354), (328,-261), (282,-60) and (268,44) |
| ZoneTrucks | 3 | 1 | 7 | south-east dock apron, the OLI terrace (221,161) and the garage edge (x 213..246, z 138..169); 7 AI-PMC points along the south and east edges (x 44..343, z 72..227) |
| ZoneIDEA | 4 | 3 | 0 | L1 IDEA hall (x 75..153, z -279..-187) |

Totals: 35 scav points (SPT categories `Bot` + `Player`), 22 boss-capable points (`Boss` + `Bot` + `Player`) and 24 AI-PMC points (`BotPmc` + `Player`) = 81 of the 252 rows (125 PMC + 46 co-op + 81). `OpenZones` lists all ten zones. Every scav, boss and AI-PMC point has a spawn sphere of 70-120 m and a delay of 40 s (PMC points: 50 m and 4 s). A boss-capable point can also host an ordinary Scav. Heights of the zone points: garage 21.4-21.6, L1 27.1-27.3, L2 36.6-36.7 (section 5). All points are in JSON `spawns.scav_zones` (normal, boss, pmc_bot lists of x, z, y, facing).

| wave zone | bot preset | slots (min-max) | raid mode |
|---|---|---|---|
| ZoneCenter | hard | 0-2 | PvE only |
| ZoneCenterBot | normal | 1-3 | PvP and PvE |
| ZoneOLI | normal | 0-2 | PvE only |
| ZoneIDEA | normal | 0-2 | PvE only |
| ZoneRoad | easy | 0-2 | PvE only |
| ZoneIDEAPark | hard | 0-2 | PvE only |
| ZoneGoshan | normal | 0-2 | PvE only |
| ZonePowerStation | normal | 0-2 | PvE only |
| ZoneTrucks | normal | 0-2 | PvE only |

- **9 scav waves** (type `assault`, `time_min` and `time_max` -1: no timing, the global spawner fills them). **Only the ZoneCenterBot wave exists in PvP**; the other eight are `SpawnMode ["pve"]`. `KeepZoneOnSpawn` is true only for ZoneCenterBot.
- **Global bot settings**: `BotMax` 30 (`BotMaxPvE` 30), `MaxBotPerZone` 2, `BotStart` 20 s, `BotStop` 2,400 s (the whole raid), spawn windows of 340-350 s "on" and 10-12 s "off", `BotSpawnCountStep` 4, `BotSpawnPeriodCheck` 15 s. **Non-wave groups**: 50 % chance that a spawn is a group of 2-3 Scavs, `NonWaveSpawnBotsLimitPerPlayer` 10. AI wakes within 260 m of a player and sleeps beyond 300 m (`DistToActivate`, `DistToSleep`); spawn lock `LockSpawnCheckRadius` 150 m, `LockSpawnStartTime` 10 s, `LockSpawnStepTime` 50 s (a point near a player is locked; the exact rule is not documented). Difficulty mix: Easy 10, Normal 50, Hard 40, Impossible 0; roles Assault 100 %, Marksman 0 %. Bots leave between 1,200 and 1,800 s (`MinExfiltrationTime`, `MaxExfiltrationTime`).
- **No sniper Scavs** (no marksman wave, no snipe zone, `BotMarksman` 0) in the SPT data. Prima's LEDX guide (1.0 era) says a sniper Scav covers the river beside the small forest camp east of the mall; no position is given and no spawn is in any data, so it is grade D (the river is the east water polygon, section 3).
- **re3mr 2026-01 "AI SCAV LOCATION" icons** (the newest placement data, +-3 m; the distance is to the nearest SPT scav-zone point on the same level):

| level | x | z | where | nearest SPT scav point |
|---|---|---|---|---|
| L1 | 55 | -283 | L1, corridor/open floor | ZoneIDEA 56 m |
| L1 | 170 | -50 | L1, Goshan | ZoneGoshan 35 m |
| L1 | 261 | -67 | L1, corridor/open floor | ZoneGoshan 19 m |
| L2 | -5 | -45 | L2, corridor/open floor | ZoneCenter 36 m |
| L0 | 26 | -139 | L0 garage, Garage B (central parking) | ZoneIDEAPark 32 m |
| L0 | 66 | 106 | L0 garage, Garage D (central parking, south) | ZoneOLI 46 m |
| L0 | 174 | 152 | L0 garage, OLI Garage | ZoneTrucks 42 m |
| outside (highway camp) | -180 | -25 | near label "Scav Camp" (22 m) | ZoneRoad 32 m |
| outside (west camp) | -386 | 127 | 7 m NW of west camp huts | ZoneRoad 208 m |
| outside (SE dock plaza) | 259 | 142 | on south-east dock apron (OLI docks, ramp up to the L1 terrace) | ZoneTrucks 30 m |

9 of the 10 icons lie within 60 m (19-56 m) of an SPT scav point of the same level, i.e. the 2026 icons agree with the SPT zones (an icon marks a roaming area, not a spawn point). The **west camp** icon (-386,127) belongs to the 1.0 strip and has no SPT point, and the Power Station quarter shows no icon although SPT has scav points there (ZonePowerStation). **Builder note**: use the SPT zones for the mall and the old outdoor area, add a Scav zone at the west camp, and keep the Power Station zone (its four points are in the main building and the yard sheds).

### 7.4 Bosses

| boss | chance % by source | SPT zones | where | guards | c |
|---|---|---|---|---|---|
| Killa | SPT (pre-1.0 data): 49; tarkovforge 2026: 60; timesaver 2026-08-27: ~75 (snapshot, unverified) | ZoneCenterBot, ZoneCenter, ZoneOLI, ZoneIDEA, ZoneGoshan | IDEA hall, OLI hall, Goshan hall, the middle of the mall near the escalators (wiki), and the parking area below IDEA and OLI; re3mr 2026-01 draws the Killa icon at (85,-226) IDEA, (85,-46) central concourse, (202,-46) Goshan, (85,133) OLI on L1 and (43,-44) on L2 | none (SPT escort amount 0, followerTagilla placeholder; tarkovforge and timesaver: hunts alone) | B |
| Tagilla | SPT (pre-1.0 data): absent; tarkovforge 2026: 35; timesaver 2026-09-05 (Tagilla guide): 35; timesaver 2026-08-27 (boss guide): 50-75 (range, snapshot) | - | Goshan parking lot (re3mr 2026-01: hammer icon at (242,-138) on the ground-level plan, legend "in the Goshan parking lot"); timesaver: "roams the mall, often near Goshan / the parking garage" | none documented | C |
| PMC-faction bosses (pmcBEAR / pmcUSEC) | SPT: 50 | - | PvE mode only (SPT SpawnMode ["pve"]); 3 BEAR groups + 3 USEC groups, escorts 0-3 | 0-3 followers | C |
| Santa (gifter) | SPT: 0 | - | none outside the holiday event | none | D |

- **Killa** is the only boss with data in every source. Gear: RPK-16 light machine gun, Maska-1SCh helmet and face shield (Killa variants), 6B13 M assault armour (tan), BlackHawk Commando chest harness (black), 890 HP in total (tarkovforge and timesaver). Per SPT he has no guards (`BossEscortAmount` 0; the escort type `followerTagilla` is a placeholder), `BossZone` = his five zones, `Time` -1 (at raid start), `ForceSpawn` false, `IgnoreMaxBots` true, `SpawnMode` pve and regular. In the hostility settings (7.5) he is an enemy of both PMC factions and a friend of every Scav and of the other bosses. Chance conflict: SPT 49, tarkovforge 2026 60, timesaver snapshot 2026-08-27 about 75, the wiki gives none. **Use 50-60 %.** History: until August 2021 he spawned only around Kiba Arms; an unannounced change (NME, 2021-08-26) spread him to the IDEA, OLI and Goshan stores, the car parks beneath each and "various second-floor locations". The SPT `BossZone` list still has no garage zone, so the garage part of that statement rests on the 2021 article and the wiki.
- **Tagilla** is listed for Interchange by tarkovforge 2026 (35 %), timesaver 2026-09-05 (35 %), timesaver 2026-08-27 (50-75 %, snapshot) and the re3mr 2026-01 infographic (header "BOSS: KILLA, TAGILLA", hammer icon at (242,-138) on the ground-level plan, legend "in the Goshan parking lot"; timesaver: "roams the mall, often near Goshan / the parking garage"). The SPT file has no Tagilla on Interchange and I found no patch note that added him, so **the date he arrived is unsettled**: the re3mr infographic of 2026-01 already shows him, while timesaver (2026-09-05) credits Season 1 (patch 1.1.0, 2026-08-03) with "expanding where he appears" and lists Interchange; the patched.gg page for patch 1.1.0 does not mention him. His spawn area is only the Goshan garage under the Goshan hall (grade C; no spawn points, no zone name). The 1.2.0.0 notes mention a Tagilla fix for Factory only.
- **No other boss**: the SPT file lists only Killa among real bosses, re3mr 2026-01 names only Killa and Tagilla, and `gifter` (Santa) has chance 0.
- **AI PMC groups** (`pmcBEAR` x3, `pmcUSEC` x3, 50 % each, `SpawnMode ["pve"]`) exist only in PvE mode (7.5).
- Not found in any source: Killa's patrol routes, aggro ranges or HP regeneration, and Tagilla's behaviour on this map.

Killa's spawn candidates: the 16 boss-capable SPT points of his five zones (game y shows the level):

| zone | x | z | y | facing | where |
|---|---|---|---|---|---|
| ZoneCenterBot | 109.6 | 5.9 | 27.12 | 181 | L1, Generic |
| ZoneCenterBot | 62.3 | -72.6 | 36.63 | 143 | L2, Jacob & Jacob |
| ZoneCenterBot | 25.9 | -3.1 | 27.06 | 155 | L1, Revis |
| ZoneCenter | 22 | -21.3 | 36.73 | 264 | L2, Sushi Huyushi |
| ZoneCenter | 23.4 | -79.4 | 36.63 | 147 | L2, McDaniels |
| ZoneCenter | 23.3 | -20.9 | 36.73 | 264 | L2, Burger House |
| ZoneOLI | 159.3 | 91.5 | 27.12 | 13 | L1, OLI |
| ZoneOLI | 166.6 | 85.8 | 27.12 | 155 | L1, OLI |
| ZoneOLI | 170 | 148 | 27.1 | 90 | L1, OLI |
| ZoneOLI | 175.9 | 147.6 | 27.1 | 90 | L1, OLI |
| ZoneIDEA | 148.3 | -267.6 | 27.27 | 167 | L1, IDEA |
| ZoneIDEA | 118.1 | -186.6 | 27.3 | 90 | L1, IDEA |
| ZoneIDEA | 153 | -253.7 | 27.12 | 356 | L1, IDEA |
| ZoneGoshan | 239.9 | -64.7 | 27.12 | 90 | L1, Goshan |
| ZoneGoshan | 241.3 | -65.6 | 27.12 | 90 | L1, Goshan |
| ZoneGoshan | 244.1 | -76.6 | 27.12 | 125 | L1, Goshan |

4 of the 16 points are on L2 (ZoneCenter's three and one of ZoneCenterBot's), the other 12 on L1 (IDEA hall 3, OLI hall 4, Goshan hall 3, Generic and Revis). **No boss point is in the garage**: the zones with garage points (ZoneIDEAPark, ZoneOLIPark) are not in his `BossZone` list, yet the wiki says he also appears in "the parking area below IDEA and OLI" (grade C for the garage). The wiki lists his places as the IDEA, OLI and Goshan stores, "the middle of the mall near the escalators" and the parking area; the re3mr infographic draws his icons at (85,-226) IDEA, (85,-46) central concourse, (202,-46) Goshan and (85,133) OLI on L1 and at (43,-44) on L2 (+-3 m); each icon lies 30-85 m from the nearest SPT boss point of the same hall (an icon marks an area, not a spawn point).

### 7.5 PvE mode (local PvE raid, SPT data)

- **Eight extra Scav waves** (every zone except ZoneCenterBot, 0-2 Scavs each, 7.3) and **six AI PMC groups** that exist only in PvE: three `pmcBEAR` and three `pmcUSEC`, each rolled at 50 %, with 0-3 followers (a weighted list: the first BEAR and the first USEC group draw from `0,0,0,0,2,2,2,1,1,1,1,1,0`, the other four also from 2 and 3). They spawn at the **24 `BotPmc` points**: ZoneIDEAPark 12, ZoneTrucks 7, ZonePowerStation 4, ZoneRoad 1. 2 of them stand on the open edge of the garage ((147,205), (268,44)), the rest outdoors on the north strip, the west side, the Power Station quarter and the south and east edges.
- **Loot**: `GlobalLootChanceModifier` 0.35 in PvP and **0.74 in PvE**; `GlobalContainerChanceModifier` 1. Raid length PvE 40 min (`EscapeTimeLimitPVE`), co-op 30 min (`EscapeTimeLimitCoop`), PvP 40 min. `BotMaxPvE` 30, `DistToActivatePvE` 260 m, `DistToSleepPvE` 300 m.
- **Hostility** (SPT `AdditionalHostilitySettings`): AI BEAR are always enemies of Killa, Tagilla and every other boss and follower, of `pmcBot` and of ex-USEC, and enemies of Scavs and marksmen (100 %) and of AI USEC (75 %); AI USEC the same without ex-USEC (15 %) and with Knight at 15 %. Their reaction to a player PMC is rolled by faction (`BearEnemyChance` 75 / `UsecEnemyChance` 90 for AI BEAR, 90 / 75 for AI USEC), to a player Scav "warn". Scavs and Killa are always enemies of both PMC factions and always friends of each other. Nothing in the data makes Scavs hostile to players beyond that.
- The SPT file also carries a `Halloween2024` zombie-event block (infected waves, 2 crowds, 125 m call radius). It is event-only and not part of the normal map.
- 1.2.0.0 (2026-10-06) added "new loot spots and lootable PMC bodies" on Interchange (section 9); where the bodies lie is not published.

### 7.6 Hazards, snipers, mounted weapons

- **West minefield band** (grade B for the shape, D for the rules): the SVG `Danger` polygon (38 vertices, x -510..-428, z -409..405) along the whole west edge, drawn red dashed; the re3mr legend calls the yellow dotted line a MINEFIELD. About 40 m wide (x -480..-440 in the north, widening to x -510..-470 near z 100-150). Its inner edge is the west edge of the playable polygon, so **the band lies outside the playable area**: a player who leaves the map enters it. The Path to River icon (-439,91.5) is 26 m inside that edge. Two N-S power lines (12 towers, x -445..-408) run beside it, the western line 5 m and the eastern line 23 m inside the edge. What the band does (instant kill, damage per step, warning text, mine density) is in no source.
- **East sniper band** (same grading): the SVG `Danger` polygon along the east edge (22 vertices, x 384..504, z -413..261), about 38 m wide, outside the playable limit like the west band. re3mr legend: red dotted line = SNIPER, "areas guarded by a deadly sniper". The Power Station V-Ex icon (356,-360) lies 28 m inside its inner edge. No sniper position, perch, range, fire rate or kill rule is in any source.
- **Kiba Arms alarm** (L1, store centre (98.8,-20.8), grade C): opening the outer door sets off a store alarm about 3 s later (tarkovforge key page); it is switched off at a terminal in the security room on the first floor (position not found). Only one source places terminals: the Lorathor 2D map (pre-0.12.4, schematic scale) draws one alarm-terminal star per floor at about (190,75) on L1 and (127,-45) on L2, +-30 m (grade D, not on the 2026 plans). The wiki adds that "some stores have alarms" which "can be switched off at designated terminals". The alarm attracts bots; its volume and range are unknown.
- **Mounted weapons and propane cylinders**: no mounted gun and no explosive cylinder is placed in any retrievable Interchange source. `docs/design/STATIONARY_WEAPONS.md` (research of 2026-11-01) lists Interchange among the NSV maps (EFT Fandom item page) but "pages give no positions". Positions unknown, none to build from this reference.
- **Fog**: the indoor fog that filled the mall corridors from 2018 on was removed by the patch of 2023-04-04 (NME, 2023-04-05; no version number in the article). The mall has no fog; SPT's `FogVisibilityDistanceCoef` for bots is 0.
- **V-Ex zone bug**: the wiki warns that the Power Station V-Ex zone is buggy near the toll barrier ("getting too close to the toll barrier exits the zone, so do not move while in the zone"); the 1.0 Path to River also has a toll booth and a barricade (section 6). No radiation, gas or trap zone is documented anywhere on the map.

### 7.7 Airdrops

| setting | value | SPT key |
|---|---|---|
| chance that a plane flies | 0.2 | `PlaneAirdropChance` |
| minimum players in the raid | 6 | `MinPlayersCountToSpawnAirdrop` |
| first plane window | 300-900 s | `PlaneAirdropStartMin`, `PlaneAirdropStartMax` |
| cooldown between planes | 800-900 s | `PlaneAirdropCooldownMin`, `PlaneAirdropCooldownMax` |
| last time a plane may start | 1800 s | `PlaneAirdropEnd` |
| max planes per raid | 1 | `PlaneAirdropMax` |
| penalty after a failed try | 600 s | `UnsuccessfulTryPenalty` |
| drop point deactivation distance | 100 m | `AirdropPointDeactivateDistance` |

One airdrop at most per raid, at 20 % chance, from 5 to 15 minutes in, and only with 6 or more players. The SPT file lists **no drop positions** (they belong to the client scene) and no 2026 source says where drops land on Interchange or whether the 1.0 expansion changed them; grade D for the positions. Airdrop contents are not part of the map data.

### 7.8 Raid time and settings

| setting | value | notes |
|---|---|---|
| raid length | 40 min (SPT, tarkovforge 2026, re3mr 2026-01); 45 min in the wiki (undated) and biligame (2020-08-29) | co-op 30 min, PvE 40 min (SPT) |
| players per raid | SPT 10-14 (`MinPlayers` 10, `MaxPlayers` 14); re3mr 2026-01 and tarkovforge 2026: 11-15; biligame 2020: 10-14 | `MaxCoopGroup` 14; the matchmaker lowers the minimum with the waiting time: 14 at 240 s, 12 at 300 s, 10 at 360 s, 8 at 390 s, 6 at 420 s, 4 at 450 s, 2 at 480 s, 1 at 510 s |
| group size | PMC groups up to 5, Scav groups up to 4 | `PmcMaxPlayersInGroup`, `ScavMaxPlayersInGroup` |
| required level | 0-100 | no key level gate (`MinPlayerLvlAccessKeys` 0) |
| average play time / level | 35 min / level 25 | SPT |
| insurance | yes |  |
| map size | about 914 x 855 m (re3mr); this reference: playable polygon 938 x 838 m (x -471.6..466.2, z -433..405), 0.68 km2 | tarkov.dev 2D bounds 1031 x 868 m |
| scene | maps/shopping_mall.bundle | `Shopping_Mall.ScenesPreset.asset`; `OcculsionCullingEnabled` true |
| exits | SPT `exit_access_time` 60 s (read as the delay before exits work, grade C), `exit_time` 90 s and `exit_count` 2 (meaning undocumented) | individual exits have their own timers, 3-60 s (section 6) |
| time of day and weather | not in any source I could read for this map |  |
| loot | loot chance modifier PvP 0.35, PvE 0.74; container modifier 1 | static container groups in section 8 |
| item caps | `maxItemCountInLocation`: item 634959225289190e5e773b3b capped at 7 per raid, the Saiga-12 FA preset (676bf44c5539167c3603e869) capped at 0 | server loot caps, no layout meaning |
| matchmaking timers | `matching_min_seconds` 60, `users_spawn_seconds_n` 120, `users_spawn_seconds_n2` 200, `sav_summon_seconds` 60 | SPT, not gameplay |
| bots | `BotMax` 30, start at 20 s, stop at 2,400 s, 2 per zone | section 7.3 |

## 8. Keys, locked rooms and loot

Lineage: the key list is the **16-key Interchange list of tarkovforge (2026)**; names, quests and durability come from its key pages, the doors and loot from eft-ammo, ggrecon (2022), keengamer (2020), theglobalgaming (2023), lfcarry (ULTRA key guide), the biligame snapshot of 2020-08-29, the Lorathor 2D map (before patch 0.12.4) and the re3mr plan of 2026-01. The EFT Fandom key pages could not be fetched (section 11). Static container groups come from the SPT database (pre-1.0). "Uses" is the durability of the key. Only four doors have a position on the plan (Kiba (90,-29), EMERCOM (49,-98), the Saferoom (132,55) and Object-14 (11,-250)); the ULTRA med room and the Terragroup container are placed without a door and the other keys have no position at all (grade D).

### 8.1 The 16 Interchange keys

| no. | key | quest | uses | needs power | opens (and where) | c |
|---|---|---|---|---|---|---|
| 1 | KIBA Arms outer door key (KIBA) | Provocation (Lightkeeper) | 40 | yes | front door of Kiba Arms, L1; lock icon (90,-29); plan key tile "KIBA outer" (140,34) | B |
| 2 | Goshan cash register key | - | 40 | not stated | Goshan cash registers (about 27); plan key tile (163,-18) | C |
| 3 | IDEA cash register key | - | 40 | not stated | IDEA cash registers (about 20); plan key tile (52,-241) | C |
| 4 | OLI cash register key | - | 40 | not stated | OLI cash registers (about 18); the OLI west offices are the probable key area | C |
| 5 | ULTRA medical storage key | - | 40 | yes | ULTRA medical storage room, L2, x 5.2..15.5, z 13.4..24.1; door not drawn | C |
| 6 | KIBA Arms inner grate key (KSM) | Provocation (Lightkeeper) | 40 | yes | inner grate of Kiba Arms; plan key tile "KIBA inner" (140,17) | B |
| 7 | NecrusPharm pharmacy key | - | 40 | not stated | medical storage of a pharmacy shop; door unresolved (L1 Mantis, L2 Tarzdrav or L2 Apteka) | D |
| 8 | OLI logistics key (also: OLI logistics department office key) | A Big Loss (Ragman) | 40 | not stated | OLI logistics department office (OLI west offices); door not placed | D |
| 9 | Object #11SR keycard | Provocation (Lightkeeper) | 10 | yes | keypad revealed by the Burger Spot urinal (L2); opens the Saferoom exfil door (132,55) | B |
| 10 | Emercom store key (also: EMERCOM medical unit key) | - | 40 | not stated | EMERCOM medical unit, L1, x 49..72, z -103.5..-93.5: three doors (N, E, W); lock icon (49,-98) | B |
| 11 | OLI administrator room key (also: OLI administration office key) | - | 40 | not stated | OLI administration office (OLI west offices); door not placed | D |
| 12 | Object #21WS keycard | Irresistible (Skier), Provocation (Lightkeeper) | 10 | yes | Terragroup container with the weapon stash, south-west container yard, about (-58,285) | B |
| 13 | OLI outlet utility room key | - | 40 | not stated | OLI outlet utility room (OLI west offices?); door not placed | D |
| 14 | Substation / power-station utility key (also: Power substation utility cabin key) | - | 40 | not stated | power substation utility cabin, Power Station compound; door not placed | D |
| 15 | Grumpy's hideout key | - | 5 | not stated | unknown door on Interchange; tarkovforge: "a detailed door guide for this key is coming soon" | D |
| 16 | Station 14-4 KORD Arshavin K. pass (Restored) | - | ? | not stated | unknown; listed under Interchange by tarkovforge, no other source | D |

The number is the position in the tarkovforge list (sorted by flea price, so it carries no map meaning). Power is documented only for the Kiba doors, the ULTRA med room and the two Object keycards (eft-ammo, ggrecon, lfcarry, tarkovforge, re3mr); every "not stated" is an absence of data, not a statement that no power is needed. The key tiles on the re3mr plan lie 19 m (EMERCOM tile (64,-86)), 68 m (Kiba inner) and 80 m (Kiba outer) from the lock icon of the door they belong to, so I read them as hints where the key spawns, not as door marks (grade C).

What is behind each door (loot text as the sources give it):

| no. | key | loot behind the door | sources |
|---|---|---|---|
| 1 | KIBA Arms outer door key | weapon boxes, ammo, mannequin armour, grenades, 2 cash registers | eft-ammo, theglobalgaming, ggrecon, tarkovforge key page 2026 (alarm 3 s after opening; security-room terminal on the first floor) |
| 2 | Goshan cash register key | cash, small loot | plan tile; Lorathor; patch 1.2.0.0; tarkovforge key list 2026 (no quest, loot key) |
| 3 | IDEA cash register key | cash, small loot | plan tile; Lorathor; patch 1.2.0.0 (new register loot template); tarkovforge key list 2026 (no quest, loot key) |
| 4 | OLI cash register key | cash, small loot | Lorathor; patch 1.2.0.0; tarkovforge key list 2026 (no quest, loot key) |
| 5 | ULTRA medical storage key | loose valuables, medications, stims, medical supplies, LEDX Skin Transilluminator (not guaranteed; two known spots in the tarkovforge page, four on shelves and tables in the lfcarry guide), ophthalmoscope, saline (lfcarry, theglobalgaming, biligame 2020: medcase/medbag, loose loot) | lfcarry ULTRA key guide (floor 2, power on, 40 uses), re3mr power-switch text, theglobalgaming 2023, tarkovforge ULTRA key page 2026 ("the storage room inside the pharmacy on the second floor", power on, 40 uses) |
| 6 | KIBA Arms inner grate key | racks and walls with dozens of possible high-end weapon spawns, armour and helmets on mannequins, weapon boxes (4x4 and 5x5 in the 2020 list), locked cash registers, loose currency (tarkovforge key page 2026, biligame 2020); the outer-door page calls the area past the inner grate "one of the best weapon loot rooms in the game" | eft-ammo, theglobalgaming, Lorathor map, biligame 2020, tarkovforge key list and inner-grate key page 2026 |
| 7 | NecrusPharm pharmacy key | salewa, morphine, antibiotics (eft-ammo); loose medical loot, LEDX, ophthalmoscope, saline (theglobalgaming, which mislabels the key); loose loot (biligame 2020: "Pharmacy") | tarkovforge key list 2026 (no door guide), eft-ammo, theglobalgaming 2023, biligame 2020 |
| 8 | OLI logistics key | PC block, loose loot (biligame 2020) | Lorathor key list; biligame 2020; tarkovforge key page 2026 |
| 9 | Object #11SR keycard | Saferoom: attachments, valuables, weapon case, weapon crate; lever opens Object-14 | wiki, ggrecon, re3mr 2026-01, keengamer, tarkovforge key page 2026 |
| 10 | Emercom store key | two wall medbags, a sports bag, a jacket, loose meds and valuables, a portable defibrillator spawn and LEDX spawn spots (tarkovforge) | plan padlock icon; Lorathor key list; tarkovforge key page 2026; biligame 2020 |
| 11 | OLI administrator room key | PC block, loose loot (biligame 2020) | Lorathor key list; biligame 2020; tarkovforge key page 2026 (loot key, door guide "coming soon") |
| 12 | Object #21WS keycard | 3 weapon boxes (4x4, 5x5, 6x3), MPX spawn, Trooper-class armour spawn, weapon mods, rare loose loot | re3mr 2026-01, ggrecon 2022, theglobalgaming 2023, biligame 2020, tarkovforge key page 2026 |
| 13 | OLI outlet utility room key | not listed (biligame 2020) | tarkovforge key list 2026 (loot key, door guide "coming soon"), biligame 2020 |
| 14 | Substation / power-station utility key | wooden crate, weapon box 4x4, loose loot (biligame 2020) | Lorathor key note; biligame 2020; tarkovforge key page 2026 (loot key, door guide "coming soon") |
| 15 | Grumpy's hideout key | unknown | tarkovforge key page 2026 (not sold on the flea market) |
| 16 | Station 14-4 KORD Arshavin K. pass | unknown | tarkovforge key list 2026 (not on the flea market); no other source found |

Conflicts and corrections to the earlier 12-key list in the JSON: (a) the **ULTRA medical storage key (no. 5) and the NecrusPharm pharmacy key (no. 7) are two keys**; theglobalgaming 2023 merges them, tarkovforge lists both (its ULTRA page: "the storage room inside the pharmacy on the second floor", power on, 40 uses, two known LEDX spots; its NecrusPharm page: a loot key, 40 uses, no door), and lfcarry names only the ULTRA key (lock "inside AΠTEKA / Pharmacy on floor 2", power on, 40 uses, four LEDX spots). (b) The Object #11SR keycard has **10 uses** (1 quest use) in tarkovforge 2026 and 15 in keengamer 2020 (the extraction summary of that tarkovforge page names The Lab as the map, probably a page error: the Saferoom use rests on the wiki, ggrecon and keengamer); the Object #21WS keycard also has 10 uses in tarkovforge (2 quest uses) and 15 in theglobalgaming 2023. (c) The Goshan register key is a loot key in tarkovforge 2026, a quest key in the biligame snapshot of 2020. (d) The 2026 sources name **no key for the power switch**; the Lorathor note of a Power Station key (before 0.12.4) became the "power substation utility cabin key" (no. 14), a loot key for a utility cabin, not the mall power. (e) Keys 15 and 16 have no door in any source; build them as unspecified locked props or leave them out.

### 8.2 Locked rooms, doors and switches by level

| level | room | rect or point | lock and key | c |
|---|---|---|---|---|
| L0 | Saferoom room (hidden L0 block east of garage zone C) | x 130..200, z -20..45 | padlocked door (132,55); keypad panel revealed by the urinal; Object #11SR keycard; mall power | D |
| L0 | Object-14 container room (secret weapon stash) | x 0..30, z -285..-250 | padlock (11,-250); opens by a lever in the Saferoom room, no key | D |
| L1 | EMERCOM medical unit | x 49..72, z -103.5..-93.5 | three entrances N (58.8,-103.5), E (72,-96.8), W (49,-101.4); lock icon (49,-98); Emercom key, 40 uses, one use per opening | B |
| L1 | Kiba Arms | x 92.5..105, z -33.5..-8 | lock icon (90,-29), entrance W (92,-24); outer-door key and inner-grate key; mall power; alarm 3 s after opening | B |
| L1 | OLI west offices: administration, logistics, outlet utility room | x -12..20, z 130..190 | three key doors (keys 11, 8, 13); positions not resolved | D |
| L1 | cash registers in IDEA, Goshan, OLI | see 8.3 | IDEA, Goshan and OLI register keys | C |
| L2 | ULTRA med storage room (inside the pharmacy column) | x 5.2..15.5, z 13.4..24.1 | door not drawn; ULTRA medical storage key; mall power | C |
| L2 | Burger Spot men's toilet urinal keypad (Saferoom step) | Burger Spot x 97.5..133, z -99..-85 | not a locked room: the urinal reveals the keycard panel when the power is on; toilet position inside the complex unresolved | D |
| outside | Terragroup container (weapon stash) | south-west container yard x -86..-16, z 243..310 | container door; Object #21WS keycard; mall power | B |
| outside | mall power switch | Power Station main building (288,-346) | no key named in 2026 sources; a green light on the switch shows power is live (lfcarry) | B |
| outside | power substation utility cabin | Power Station compound, not placed | utility cabin key (no. 14) | D |
| ? | pharmacy medical storage (NecrusPharm key) | unresolved | key no. 7; candidates L1 Mantis (64.8,-65), L2 Tarzdrav (27.4,-122.7), L2 Apteka (11.7,52.2) | D |

Notes: (1) lfcarry places the ULTRA lock "inside AΠTEKA / Pharmacy on floor 2"; the dark "ULTRA med" room of the plan lies 23 m north of the АПТЕКА label (11.7,52.2) in the same shop column, so the pharmacy name probably covers the whole column (grade C). (2) The Saferoom block is drawn solid on the plan (section 4), the real room size is unknown. (3) Patch 1.1.0.0 added generic padlocks and elevator doors; no source says which Interchange doors use them (section 9). (4) Patch 1.2.0.0: "locked containers are now guaranteed to hold loot".

### 8.3 Cash registers

- **IDEA** about 20, **Goshan** 27, **OLI** 18 registers (counted on the re3mr plan, grade C), each hall opened with its own register key (keys 3, 2, 4); Kiba Arms adds one or two behind its own doors (sources differ).
- Patch 1.2.0.0 (2026-10-06): the OLI, Goshan and IDEA registers use a **new loot template**; their keys are still needed. The registers of the **standalone ULTRA stores need no key any more**.
- What a register holds (roubles, small valuables) and its roll chances are not published; build them as keyed containers with a cash-heavy table.

### 8.4 Static loot containers (SPT database, pre-1.0 map)

`statics.json` lists **823 container objects** in **16 groups** plus **130 ungrouped ones that always spawn**; each group draws between its minimum and maximum per raid, so 269-325 containers are drawn from the groups in every raid, plus the ungrouped ones. `staticContainers.json` holds 824 records (202 always-spawn, the rest rolled by a probability of 0.08 to 0.71, mean 0.28) of **21 container templates** (item and count tables in `staticLoot.json`). **No positions**: every position in the file is (0,0,0), and `looseLoot.json` is a git-LFS pointer (65,763,894 bytes) that could not be fetched, so there is **no loose-loot data**. The area column is my reading of the SPT group name (grade C). Source: SPT `locations/interchange/statics.json`, `staticContainers.json`; JSON `loot_groups`.

| SPT group | drawn per raid | candidates | always-spawn | rolled | reading of the name |
|---|---|---|---|---|---|
| Ultra | 45-49 | 129 | 34 | 95 | the ULTRA mall itself: general shops, corridors, food court (name; largest pool) |
| UndergroundParking | 44-52 | 97 | 15 | 82 | the garage (SPT calls it underground parking; our L0 garage is at ground level) |
| Stashes_Shopping_mall | 17-19 | 89 | 0 | 89 | hidden stashes in the mall (name) |
| OLI | 35-39 | 59 | 4 | 55 | OLI hall (name) |
| LoadingRooms | 20-24 | 56 | 4 | 52 | loading and back-of-house rooms (name) |
| Goshan | 19-23 | 42 | 2 | 40 | Goshan hall (name) |
| PowerStation | 16-20 | 38 | 8 | 30 | Power Station compound (name) |
| MedicalShops | 14-18 | 38 | 0 | 38 | medical shops (name; pharmacies and medical units) |
| IDEA | 10-14 | 32 | 0 | 32 | IDEA hall (name) |
| ClothingShops | 14-18 | 29 | 0 | 29 | clothing shops (name) |
| Parking | 7-11 | 25 | 0 | 25 | outdoor car parks (name) |
| BackLoadingSquare | 8-12 | 21 | 0 | 21 | loading squares behind the docks (name) |
| Road | 8-10 | 19 | 0 | 19 | roadside vehicles and containers (name) |
| Other | 9-10 | 12 | 2 | 10 | miscellaneous; holds Lootable_00001 and a Test_for_export container |
| LockedSeaContainer | 2-3 | 4 | 1 | 3 | locked shipping containers (name; the Terragroup container may be one of them, none is identified) |
| KibaArms | 1-3 | 3 | 1 | 2 | Kiba Arms store (name) |
| (no group) | all | 130 | 130 | 0 | ungrouped containers, always present |

The group sizes show where SPT puts the weight of the map: the ULTRA mall itself, the garage ("UndergroundParking", 97), the stash group (89), OLI (59) and the loading rooms (56) dominate, Kiba Arms has only 3 candidate containers (1-3 per raid), the locked sea containers 4 (2-3 per raid). How the draw treats the 71 always-spawn members inside groups is not in the data (grade D).

### 8.5 Notable loot rooms and areas

- **Weapons**: Kiba Arms (L1, centre (98.8,-20.8)): weapon boxes 4x4 and 5x5, ammo, mannequin armour, grenades, registers; "one of the best weapon loot rooms in the game" (needs both Kiba keys and the power). Terragroup container (outside, about (-58,285)): three weapon boxes (4x4, 5x5, 6x3), an MPX spawn, a Trooper-class armour spawn, mods (Object #21WS keycard). Object-14 container room (L0, x 0..30, z -285..-250): the secret weapon stash, opened by the lever in the Saferoom room. Saferoom room (L0, x 130..200, z -20..45): couch with valuables, food and drink shelf, attachments beside a microwave, weapon case, weapon crate, items case.
- **Medical**: EMERCOM unit (L1, (60.5,-98.5)): two wall medbags, a sports bag, a jacket, loose meds and valuables, portable defibrillator and LEDX spawn spots. ULTRA med storage (L2, (10.3,18.8)): medications, stims, medical supplies, LEDX (two to four spawn spots on shelves and tables, not guaranteed), ophthalmoscope, saline. Pharmacies Tarzdrav (L2, (27.4,-122.7)) and Apteka (L2, (11.7,52.2)), and the NecrusPharm key room (salewa, morphine, antibiotics; door unresolved). An old community note adds gas analyser and GM counter spawns at EMERCOM, Mantis and Apteka (undated, grade D).
- **LEDX Skin Transilluminator** (Prima, 1.0 era): ULTRA Medical Unit, Emercom Medical Unit, "the TT" (probably the TTS electronics store, L1 (63.5,-127), grade D), random duffel and sports bags, and the **Small Camp in the forest** (shelves and a metal container) reached by heading into the forest "past the former Hole in the Fence extraction, closer to the Emercom Checkpoint than the Power Station"; the forest camp is not in the layout data (position grade D, between the Hole in the Fence landmark (303,-70) and the Emercom Checkpoint (399,278)). The same article warns of a sniper Scav covering the river there (section 7.3).
- **Electronics**: TECHLIGHT (L2, SW corner, (-11.7,58.8)) is the largest tech store (laptops, GPUs, cables; "best tech loot on L2"); L1 TTS, Mantis, Texho, Telespot, Rasmussen sell tech; L2 Na-Svyazi (11.7,36) mobile phones.
- **Halls**: IDEA (home and hardware), Goshan (food, the west side stocked with rations), OLI (DIY and hardware, offices and stock rooms in the west end) have the most containers (SPT groups OLI 59, Goshan 42, IDEA 32) and the register keys. The garage (L0) is the largest container pool after the mall (97).
- **Patch 1.2.0.0 loot spots** ("Emercom camp, Objects #11SR, #14 and #21WS, OLI service areas, Kiba Arms store"): the Emercom camp is the tent group at x 189..220, z 215..270 (eight tent and container footprints, section 3). My reading, grade C: Object #11SR is the Saferoom room, Object #14 the Object-14 container room and Object #21WS the Terragroup container (the numbers match the keycard and container names); the OLI service areas are probably the back-of-house rooms at the west end of the OLI hall and the stock block behind the docks (x 153..190, z 100..185, grade D). Exact spots are not published.
- **Outdoor camps in the 1.0 strip**: ten west-camp huts (centres x -412..-338, z 87..175, section 3); no source lists loot for them.

### 8.6 Gaps in this section

- No container positions, names or per-container item tables beyond the 21 templates in `staticLoot.json` (not analysed here); no loose-loot spawn list (git-LFS object not fetched); no data for the 1.0 strips; the 1.2.0.0 changes (new loot spots, lootable PMC bodies, new register template) are not in the SPT data.
- Door positions are missing for keys 7, 8, 11, 13, 14, 15 and 16; the pharmacy column versus the ULTRA med room (note 1 in 8.2) is unsettled.
- Prices, flea availability and trader sales of the keys are not part of the map data and are left out on purpose.

## 9. What changed recently, and which data is older than the current map

State of this reference: 2026-11-01, patch 1.3.0.0 (2026-10-29). The map was released in 2018 (NME 2023). The patch pages read were the patched.gg pages for 1.0.2.0, 1.0.2.5, 1.0.4.0, 1.0.4.5, 1.0.5.0, 1.0.6.0, 1.1.0.0, 1.2.0.0 and 1.3.0.0; other 1.0.x hotfix pages were not read, and the Fandom patch pages could not be fetched.

### 9.1 Change history that touches Interchange

| date | version | change | effect on this reference | source |
|---|---|---|---|---|
| 2020-03-13 | 0.12.4 (build 0.12.4.6254) | "Interchange location has been reworked", lighting updated, "new interactive objects, new location exfils", "various problems with culling, physical colliders have been fixed"; the article does not say what the rework changed | Everything older (the Lorathor 2D map with its key lists and alarm terminals) describes the pre-rework mall; the SVG and re3mr plan used here are newer | ginx.tv (published 2020-03-13) |
| 2021-08-26 | unannounced | Killa no longer spawns only "around Kiba Arms": also in the IDEA, OLI and Goshan stores, the car parks beneath each (Reddit post cited by NME) and "various locations across the second floor" | Boss spawn spread (7.4); the SPT zone list matches the mall halls but has no garage zone | NME 2021-08-26 |
| 2023-04-04 | not stated | Indoor fog removed from the mall corridors (present since 2018); Reserve also changed | Build the mall without fog (7.6) | NME 2023-04-05 |
| 2025-11-15 | 1.0 | Interchange **expanded**: the playable area grows from 468,825 m2 (the 2024 Limit polygon) to 680,115 m2, by a west strip beyond the highway (minefield band, Path to River exit, west camp) and an east strip with a notch on the north edge (sniper band); new Path to River flare exit | Sections 2, 3, 6 and 7: the strips have no SPT spawn, zone, boss or loot data. The mall geometry in the SVG is identical in the 2024-06-19 and 2026-01-09 files (section 1), the added regions lie outside the mall and no source reports a change inside it | Prima, invenglobal (launch date), ingamenews, thegameslayer, SVG diff of 2024-06-19 against 2026-01-09 |
| 2026-03-27 | 1.0.4.0 | "Implemented updated player culling system on Interchange to improve performance" | none for the layout; relevant for the performance budget (occlusion culling is on, 7.8) | patched.gg |
| 2026-04-20 | 1.0.4.5 | players getting stuck in the secret saferoom fixed | the Saferoom is a real enclosed room with a door and an exit trigger (6) | patched.gg |
| 2026-08-03 | 1.1.0.0 | no Interchange entry; generic new interactive mechanics (padlocks, elevator doors, breakable bottles); timesaver credits Season 1 (patch 1.1.0) with expanding where Tagilla appears and lists Interchange | door types are not tied to a map in any source; Tagilla arrival date unsettled (7.4) | patched.gg, timesaver 2026-09-05 |
| 2026-10-06 | 1.2.0.0 | new loot spots (Emercom camp, Objects #11SR, #14 and #21WS, OLI service areas, Kiba Arms store); locked containers always hold loot; new loot containers including lootable PMC bodies; new register loot template for OLI, Goshan and IDEA; standalone ULTRA store registers need no key; truck cabins wrongly locked by the Factory emergency exit key fixed | Section 8 (loot and keys); the SPT loot data predates all of it | patched.gg, timesaver, tarkovforge |
| 2026-10-29 | 1.3.0.0 | "Fixed various visual issues with geometry and colliders on Interchange" | none for the layout; the SVG of 2026-01-09 is the newest geometry source and may be older than this fix | patched.gg |

Not found in any source: the date Tagilla was added, any change to extract positions after the 1.0 launch, any change to the mall floor plan after 0.12.4, and the 1.0 patch notes for Interchange (the launch coverage lists the expansion and the Path to River exit only). The re3mr infographic (2026-01) is the newest placement source and predates 1.1.0.0, 1.2.0.0 and 1.3.0.0.

### 9.2 Data older than the current map

| data | date or era | what it describes | how this reference uses it |
|---|---|---|---|
| SPT server database (spawn points, zones, bosses, waves, extracts, airdrops, loot groups, raid settings) | HEAD 2026-08-10, describing the 0.16-era map | 468,825 m2 playable area, before the 1.0 expansion; 248 of 252 spawn rows inside the old polygon | Used exactly for the old area and the mall; the strips get re3mr icons only. Expect SPT chances (Killa 49 %) to differ from 2026 sources (60 %). |
| tarkov.dev map labels (`maps.json`) | labels 2024-02-17/18; bounds 2026-02-16 | all 77 of 77 labels lie inside the old polygon; no label names a feature of the 1.0 strips | Used for names and as a position check inside the old area only. |
| SVG footprints (Interchange.svg) | 2026-01-09 (commit 6bbddad) | current playable area (680,115 m2); the old Limit polygon is the 2024-06-19 file (commit 81fa164) | Newest geometry. Heights, ceilings and doors are not in it (section 5). |
| re3mr infographic (plan, aerial icons, legend) | 2026-01 | current map; predates patches 1.1.0.0 to 1.3.0.0 | Newest placement data (extract icons, 25 PMC rings, AI scav icons, boss icons). Its legend omits the Hole in the Fence. |
| exits against the old playable polygon | SPT exits + 2026 icons | Railway Exfil, Emercom Checkpoint, Saferoom, Scav Camp and the Streets transit are inside; Hole in the Fence (303,-70) lies 5 m outside, the V-Ex icon 18 m outside, the Customs transit icon 25 m outside (on the aerial edge); Path to River is 236 m outside (new in 1.0) | The Hole in the Fence is within its position error of the old edge; the V-Ex icon may mark a later car stop than the SPT trigger (no source says the V-Ex moved). |
| Lorathor 2D map | before patch 0.12.4 (March 2020) | pre-rework mall: alarm-terminal stars, key lists, a Power Station key note, V-Ex 3,000 roubles | Grade D wherever it is the only source (terminal positions, OLI office key list, substation key). |
| biligame Interchange page | snapshot 2020-08-29 | raid 45 min, 10-14 players, key and loot lists of 2020 | Loot lists kept as grade D hints (section 8); raid length and player counts superseded by SPT and tarkovforge 2026. |
| wiki (Fandom) Interchange text | undated, read through search snippets only | raid 45 min, V-Ex 5,000, Hole in the Fence, "always" chances | Superseded where SPT or 2026 sources disagree (7.8, 6). |
| keengamer 2020, ggrecon 2022, theglobalgaming 2023, progameguides 2023 | 2020-2023 | Saferoom steps, Scav Camp wording, keycard uses (15), key doors | Steps kept; keycard uses overruled by tarkovforge 2026 (10); the Scav Camp position follows the 2026 icon (6). |
| Prima transit page | patch 0.16.8 (before 1.0) | positions of the Customs and Streets transits in words | Kept; both fit the 2026 icons (6.2). |
| Prima LEDX page, thegameslayer, ingamenews | 1.0 launch era, 2025-11 | Path to River route, the forest Small Camp, "the former Hole in the Fence extraction" | Newest text for the strips; no coordinates. |
| timesaver Tagilla and 1.2.0.0 pages, tarkovforge key and boss pages | 2026-08 to 2026-10 | boss chances (Killa 60, Tagilla 35), key list of 16, durability | Newest chance and key data; Killa varied between 49 (SPT), 60 and about 75 (snapshot of 2026-08-27). |

Consequences for the builder: take the mall, the old outdoor area and the spawn, zone and loot rules from the SPT-backed sections and the SVG, take the west and east strips, the Path to River exit and the Tagilla/Killa chances from the 2026 sources, and treat everything marked grade D as a placeholder. Where an old and a new source disagree the text says so (6, 7.4, 7.8, 8.1).

## 10. Open uncertainties and parity gaps

Nothing in this reference was tested in Roblox Studio, on a phone or on any device; it is map data only. Grades are explained in section 0. Items are grouped by what a builder has to do about them.

### 10.1 Missing data (grade D): build a placeholder and log it

- **Ceiling heights, slab thickness, roof height and the dome and skylight geometry** (section 5): no source. Floor levels are known (21.4 / 27.1 / 36.6); the clear heights in section 5.1 rest on an assumed 0.5 m slab.
- **Heights of everything outdoors**: fences, walls, huts, towers (Idea Tower and Oli Tower are drawn only as base huts), rock fields (19 outlines over 400 m2), the Power Station buildings, the go-kart pit. The relief of the two 1.0 strips has no spawn or SPT height points to check against.
- **Door positions** for keys 7, 8, 11, 13, 14, 15, 16, the ULTRA med door, the Terragroup container door and the keypad inside the Burger Spot men's toilet (section 8).
- **Trigger sizes and visuals** of every extract and transit (section 6), the Path to River timer, the V-Ex car, the Saferoom room size.
- **Mounted weapons and propane cylinders**, **container positions and names**, **loose-loot spawns** (SPT `looseLoot.json` is an LFS pointer), **airdrop positions**, **time of day and weather**.
- **Rules of the two danger bands** (what the minefield and the sniper do, section 7.6), **Killa's patrol routes and aggro ranges**, **Tagilla's spawn points**, the **sniper Scav** position by the river, the Kiba alarm terminal position.
- **Data for the 1.0 strips**: no SPT spawn, zone, boss or loot data, no names, no container lists; only the SVG shapes and the re3mr icons.

### 10.2 Conflicting sources: the text states both sides

| topic | sources and values | section | treatment here |
|---|---|---|---|
| Hole in the Fence in 2026 | SPT, wiki and tarkovforge 2026 list it; the re3mr 2026-01 legend omits it; a Prima article of the 1.0 era says "the former Hole in the Fence extraction" | 6 | build as an optional extract, grade D |
| V-Ex price | 3,000 (Lorathor), 4,000 (Prima 2020), 5,000 (wiki, SPT, ggrecon 2022, progameguides 2023), 20,000 (re3mr 2026-01) | 6 | newest source says 20,000; SPT 5,000 predates 1.0 |
| Killa chance | SPT 49 %, tarkovforge 2026 60 %, timesaver snapshot 2026-08-27 about 75 % | 7.4 | use 50-60 % |
| Tagilla chance and arrival | tarkovforge 2026 and timesaver 2026-09-05: 35 %; snapshot 2026-08-27: 50-75 %; not in SPT; re3mr 2026-01 already shows him, timesaver ties him to Season 1 (1.1.0) | 7.4 | about 35 %, Goshan garage, date unknown |
| Killa in the garage | wiki and NME 2021 say the car parks beneath IDEA, OLI and Goshan; the SPT `BossZone` list has no garage zone | 7.4 | grade C for the garage |
| Raid length and players | 40 min (SPT, tarkovforge, re3mr) against 45 min (wiki, biligame 2020); 10-14 players (SPT, biligame) against 11-15 (re3mr, tarkovforge 2026) | 7.8 | use 40 min and 11-15 |
| Object keycard uses (#11SR, #21WS) | 10 each (tarkovforge 2026) against 15 (keengamer 2020 for #11SR, theglobalgaming 2023 for #21WS) | 8.1 | use 10 |
| Scav Camp (Co-Op) position | garage tunnel (re3mr 2026-01 icon) against the highway camp (Lorathor, tarkov.dev label "Scav Camp" at (-181,-3)) against "opposite the entrance to the ULTRA supermarket" (progameguides 2023) | 6 | icon wins, grade B |
| Path to River | two approach descriptions (thegameslayer, Prima); flare spot inferred at (-428,90) +-15 m (grade C); the icon is at (-439,91.5) +-20 m | 6 | build at the icon, move the flare zone to the toll booth when known |
| PMC spawn layout | SPT: 25 sites of 5 points; re3mr 2026-01: 25 rings, only 5 within 12 m of an SPT site; 11 rings in the 1.0 strips | 7.1 | rings for the 1.0 map, SPT for local detail |
| MallNW and MallSE | halves of the perimeter, not corners; the group rule fits all 125 SPT points but is inferred for the rings (grade C); the 2026 sources call both corner exits neutral while SPT offers each group the far corner | 6, 7.1 | decide the extract rule for Zero Return |
| ULTRA medical room against the pharmacy | lfcarry: the lock is "inside AΠTEKA / Pharmacy"; the plan's ULTRA med room is 23 m north of the АПТЕКА label; the NecrusPharm key (no. 7) is a different key with an unresolved door | 8.2 | grade C / D |
| `DisabledScavExits` "scav_NW,scav_SE" | SPT field with no documentation; the wiki and tarkovforge 2026 list both scav exits as usable | 6.1 | read as exit object names |
| Goshan register key | loot key (tarkovforge 2026) against quest key (biligame 2020) | 8.1 | loot key |

### 10.3 My own readings, to be re-checked on the first build

- **Store rectangles** on L1 and L2 are read off the re3mr plan with the SVG floor outline laid over it (alignment +-2 m); L1 stores mostly grade B, the anchors and all of L2 grade C. The 36 + 36 corridor rectangles are computed (largest empty rectangles of walkable floor), grade C, and are not authored rooms.
- **Road, hut, yard and camp names** are my descriptors; only the 77 tarkov.dev labels and the sign names on the plans are official.
- **Key tiles** on the plan read as key-spawn hints, the SPT loot-group areas read from group names, "the TT" read as TTS (all grade C or D).
- **Power switch** at (288,-346) +-15 m inside the Power Station main building (ggrecon 2022); whether the V-Ex works without the mall power is patch-dependent in the sources.
- **Elevators**: none documented; patch 1.1.0.0 added "elevator doors" as a generic mechanic and no source places one in the mall (grade C).
- **Vegetation**: the SVG has no tree or bush layer; forest density in the strips is not documented.

### 10.4 Project-level points for the decision maker

- **Rule 1 of the project (original map layouts) against this task**: the rebuild copies the Interchange layout at real scale and the JSON licence note says so; the SVG is CC BY-NC-SA 4.0 (non-commercial, share-alike, credit the-hideout/tarkov-dev-svg-maps) and the re3mr infographic is CC BY-NC-SA 4.0. Decide before shipping or publishing; the build spec renames every shop and landmark.
- **Parity log**: the gaps above belong in `docs/design/EFT_PARITY.md`; that file is outside the scope of this task and was not edited.
- **Cross-platform**: the mall has a 140,962 m2 footprint over three levels (floor areas 80,753 / 120,142 / 31,619 m2), 66 store rectangles on L1 and L2 and about 40 skylights; streaming, culling and a 30 FPS floor on low-end phones are decisions for the build, not data in this reference.

## 11. Sources

Data (downloaded as untrusted data, parsed only):

- https://github.com/the-hideout/tarkov-dev-svg-maps - `Interchange.svg` by Shebuka (CC BY-NC-SA 4.0; current file commit 6bbddad, 2026-01-09; the 2024-06-19 file, commit 81fa164, gives the pre-1.0 `Limit` polygon)
- https://github.com/the-hideout/tarkov-dev - `src/data/maps.json` (bounds commits 2026-01-12 and 2026-02-16, 77 labels dated 2024-02-17/18; `interchange-3d` added 2026-01-07) and the two map images it names: `interchange-2d` by Lorathor (https://www.reddit.com/user/Lorathor6/, before patch 0.12.4, schematic scale) and `interchange-3d`, the re3mr infographic (image footer "Map made by re3mr.com", tarkov.dev author link https://reemr.se, v0.1, January 2026, licensed CC BY-NC-SA 4.0 according to the footer)
- https://github.com/sp-tarkov/server-csharp - `Libraries/SPTarkov.Server.Assets/SPT_Data/database/locations/interchange/` (`base.json`, `statics.json`, `staticContainers.json`, `staticLoot.json`, `staticAmmo.json`, `allExtracts.json`; HEAD fe74b07c6361e2c6d1532dc21ba1c3b981d88d93, 2026-08-10; `looseLoot.json` is a git-LFS pointer of 65,763,894 bytes)
- this repository: `docs/design/STATIONARY_WEAPONS.md` (2026-11-01), `docs/maps/reference/CUSTOMS_REFERENCE.md` (method and style)

Rules, names, patches (paraphrased):

- https://escapefromtarkov.fandom.com/wiki/Interchange (undated; extraction table, bosses, raid text, read through the page summary only)
- https://tarkovforge.com/map-guide/interchange , https://tarkovforge.com/bosses/killa , https://tarkovforge.com/blog/tarkov-patch-1-2-0-0-quests-keys-maps
- https://tarkovforge.com/keys (the 16 Interchange keys) and the key pages `kiba-arms-outer-door-key`, `kiba-arms-inner-grate-door-key`, `goshan-cash-register-key`, `idea-cash-register-key`, `oli-cash-register-key`, `ultra-medical-storage-key`, `necruspharm-pharmacy-key`, `oli-logistics-department-office-key`, `oli-administration-office-key`, `oli-outlet-utility-room-key`, `object-11sr-keycard`, `object-21ws-keycard`, `emercom-medical-unit-key`, `power-substation-utility-cabin-key`, `grumpys-hideout-key` under https://tarkovforge.com/keys/
- https://timesaver.gg/blog/eft-bosses-guide (2026-06-13, updated 2026-08-27) , https://timesaver.gg/blog/tarkov-tagilla-boss-guide (2026-09-05, updated 2026-09-09) , https://timesaver.gg/blog/tarkov-customs-interchange-loot-changes-1-2-0-0
- https://patched.gg/games/escape-from-tarkov and its pages `patch-1020`, `patch-1025`, `patch-1040`, `patch-1045`, `patch-1050`, `patch-1060`, `patch-1100`, `patch-1200`, `patch-1300`
- https://www.nme.com/news/escape-from-tarkov-patch-fixes-a-long-running-problem-with-interchange-3426371 (2023-04-05, fog) , https://www.nme.com/news/escape-from-tarkov-boss-killa-can-now-spawn-all-over-interchange-3029852 (2021-08-26)
- https://www.ginx.tv/en/?p=3201 (patch 0.12.4, published 2020-03-13) ; https://labs.invenglobal.com/articles/19896/escape-from-tarkov-sets-november-15-launch-date-as-servers-begin-24-hour-patch-downtime (headline only, 1.0 launch 2025-11-15)
- https://primagames.com/tips/escape-tarkov-interchange-map-extraction-points (2020-01-16) , https://primagames.com/tips/where-is-the-smugglers-tunnel-extraction-location-for-interchange-in-escape-from-tarkov (1.0 launch) , https://primagames.com/tips/interchange-ledx-spawn-locations-in-escape-from-tarkov-1-0 , https://primagames.com/tips/all-transit-locations-in-escape-from-tarkov (patch 0.16.8)
- https://thegameslayer.com/guides/tarkov-1-0-interchange-smugglers-tunnel-green-flare-extract-guide/ , https://ingamenews.com/2025/11/escape-from-tarkov-interchange.html
- https://www.ggrecon.com/guides/escape-from-tarkov-interchange-map-best-loot-extractions/ (2022-07-05) , https://progameguides.com/escape-from-tarkov/escape-from-tarkov-interchange-map-all-extraction-spawn-points/ (2023-03-14, updated 2023-07-01) , https://www.keengamer.com/articles/guides/escape-from-tarkov-saferoom-exfil-guide/ (2020-03-16) , https://theglobalgaming.com/gaming/best-keys-interchange-escape-from-tarkov (2023-10-12)
- https://eft-ammo.com/wiki/escape-from-tarkov-interchange-map , https://www.eft-ammo.com/wiki/escape-from-tarkov-the-ultimate-key-guide-for-loot-rooms , https://lfcarry.com/guides/tarkov-ultra-medical-key , https://wiki.biligame.com/eft/Interchange (snapshot 2020-08-29) , https://wand.com/ja/maps/escape-from-tarkov/interchange/checklist/place-of-interests/extraction-point (six extracts)

Tried and failed (do not retry): api.tarkov.dev and assets.tarkov.dev (HTTP 403 through the sandbox proxy); `escapefromtarkov.fandom.com/wiki/Interchange?action=raw` and the Fandom key pages (fetch error); wikiwiki.jp NecrusPharm key page and tarkov-market.com Object #11SR page (fetch error); fdaytalk.com `?p=63746` and `?p=63643` (no Interchange extract content); media.githubusercontent.com LFS object of `looseLoot.json` (HTTP 404 for both `main` and the commit); pcgamesn post-launch article (no date, no Interchange content).

Licence note: the SVG and the re3mr infographic are CC BY-NC-SA 4.0 (non-commercial, share-alike, credit the-hideout/tarkov-dev-svg-maps and re3mr); the SPT database is data downloaded for reading only and no Battlestate asset is included; the infographic footer credits Battlestate Games for its exterior terrain mesh, so no pixel of it was copied (positions were read only). Section 10.4 raises the question of copying the layout.
