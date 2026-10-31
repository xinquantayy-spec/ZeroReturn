# Customs layout reference for the "Border Yard" rebuild

Escape from Tarkov Customs, state of 2026-11-01: 0.16.0 rework (2024-12-26) plus patches up to 1.3.0.0 (2026-10-29). Companion data with identical numbers: `customs_layout.json`. Preview render of that JSON: `customs_layout_preview.png`. SPT excerpts: `customs_spt_raw.json`.

**No live API data**: `customs_api.json` could not be produced because api.tarkov.dev and assets.tarkov.dev return HTTP 403 through the sandbox proxy. Rules and spawn points come from the SPT server database instead (see section 1).

## 0. Frame and conventions (one frame everywhere)

- Units metres. **x = east (+), z = south (+)**, so north is -z, the top of the 2D map. y = game height (flat central ground is y 1.0-1.5). Origin = centre of the tarkov.dev 2D bounds.
- game -> frame: `x_e = 163 - x_game`, `z_s = z_game + 35`, y unchanged (tarkov.dev rotates the game axes 180 degrees; its Leaflet code uses [z, x] order).
- SVG -> frame: `x_e = u*1070/1062.4827 - 535`, `z_s = v*544/535.17401 - 272` (Customs.svg viewBox units, about 1 unit = 1 m).
- Footprints: `cx, cz` centre; `w` = long side, `d` = short side; `rot` = angle of the w axis from +x (east) toward +z (south) = clockwise on the north-up map, range -90..90 (so +-82 means the long side runs N-S).
- Roblox: `CFrame.new(cx, y, cz) * CFrame.Angles(0, -math.rad(rot), 0)`, Size = (w, height, d). North = -Z, same as Roblox forward.
- Confidence: **A** traced footprint with a tarkov.dev label or floor extent within 10 m (+-3-5 m); **B** identified by matching extents, spawn points or old-map icons (+-5-10 m); **C** inferred or landmark-based (+-15-30 m); **D** no position source.
- Licence/IP note for the parent project: Customs.svg is CC BY-NC-SA 4.0 (non-commercial, share-alike, credit the-hideout/tarkov-dev-svg-maps); and project rule 1 lists "map layouts" among the things that must be original. This reference copies the EFT layout because the task asked for it - decide before shipping.

## 1. Data lineage and accuracy

| Layer | Source | Vintage | Accuracy |
|---|---|---|---|
| Building, road, rail, river, fence, forest, rock footprints | tarkov-dev-svg-maps `Customs.svg` (hand-traced; flattened by my own parser) | last edit 2024-01-10 = 0.12.x geometry | +-3-5 m |
| Labels (24), floor and underground extents, floor heights | tarkov.dev `src/data/maps.json` | 2025-01-18/20 (0.16 tiles `customs_0.16`), same bounds and labels as before | +-2 m |
| Extract positions | old 0.12.12 2D map icons, affine-aligned to the SVG (6 building matches, residual <= 2 m) | 2021-2023 map | +-5-10 m |
| Spawn points, extract rules, transits, boss rolls, raid settings | SPT server-csharp `bigmap/base.json`, `allExtracts`, locale (HEAD 2026-08-10, targets 0.16.9) | post-0.16 (has Voron secret exits, PvE bots) | exact coordinates, rules may differ from live PvP |
| Current rules, names, patch changes | wiki, patch notes, news sites (section 13) | to 2026-10-29 | sources disagree in places |

Consequences: the macro layout is taken as unchanged by 0.16 (tarkov.dev kept the same map bounds and all 24 labels while updating the tiles), but building outlines are 0.12.x shapes. The three buildings opened in 0.16 have no interior in the SVG.

## 2. Extents, orientation, perimeter

- 2D map frame: x -535..535, z -272..272 (1070 x 544 m). Playable polygon (SVG `Limit`, 97 vertices in JSON `boundary.poly`): x -516.7..507.2, z -270.6..270.8 = 1024 x 541 m, area 329,045 m2 (about 329,000). The long axis is east-west.
- Coarse outline (37 of 97 vertices, starting at the NE corner, same direction): (507,-173) (490,-205) (340,-206) (339,-190) (224,-180) (234,-138) (199,-128) (201,-112) (127,-95) (118,-146) (25,-128) (-13,-214) (12,-238) (-27,-270) (-98,-177) (-198,-159) (-194,-98) (-495,-134) (-510,-11) (-492,-9) (-515,164) (-440,173) (-408,198) (-411,220) (-315,270) (-271,246) (-241,258) (-204,207) (-167,201) (8,256) (99,169) (235,168) (250,86) (316,87) (474,-12) (489,-46) (504,-48)
- Shape (counter-clockwise on the north-up map from the NE corner): north edge z about -206 for x 340..490; steps to z -180 at x 224..339; pocket cut out at x 118..234, z < -105 (river north reach enters the map at z about -185); north-centre edge z -128..-146 for x 25..118; peninsula up to the north tip (-27,-270) between x -98 and 12; west edge x -495..-515 from z -134 to 164; SW corner cut diagonally (-515,164) > (-440,173) > (-411,220) > (-315,270); south edge (-271,246) > (-241,258) > (-204,207) > (-167,201) > (8,256) > (99,169) > (235,168); east side (250,86) > (316,87) > (474,-12) > (504,-48) > (507,-173).
- Border sniper danger quad (SVG `Sniper`): [[-47.8, -239.6], [-27.0, -267.2], [8.2, -238.2], [-15.9, -214.4]] - the three N-S railway lines converge into it at the north tip.
- Perimeter objects in the SVG: the `Limit` line itself (no wall layer), 68 fence polylines (1 m lines, no heights), 126 rock/cliff blobs (r 0.5-16 m; 59 in the SW quarter x < -200, z > 0, 17 along the river banks x 200..400, z -200..100), 37 forests. Wall/cliff heights are not in any source.
- Limit accuracy: edge extract icons lie 4-7 m inside the polygon, but RUAF Roadblock (18 m), Military Base CP (25 m) and Administration Gate (6 m) lie outside it - treat the polygon as +-25 m in the north-centre notch and the SW corner.

Regions (north-up):

| Region | x range | z range | contents |
|---|---|---|---|
| West industrial | -500..-140 | -140..30 | tank farm, Streamer House, Pump house, Warehouse 7, Depot, Warehouse 3, Warehouse 4, ZB-1011, ZB-1012, rail sidings |
| West edge / checkpoint | -515..-340 | 0..130 | Administration Gate, Scav Checkpoint (-485,5), Military Checkpoint hut + barracks (-419,40)/(-418,56), Sniper Ridge, military-base road |
| North-centre | -200..130 | -175..-40 | Old Gas Station, Fortress (Scav base) and yard, gravel loop roads, north rail tip |
| Centre | -130..160 | -60..60 | oil-rig tower, Skeleton, repair shop + boiler house, Warehouse 17, Old Construction, Crackhouse (north edge, z -121) |
| South-centre | -300..100 | 30..265 | New Gas Station, Bus Station, 2- and 3-storey dorms, large forests, Powerline Tower pad |
| South-west plateau | -515..-190 | 130..270 | end of the military-base road, Military Base CP, Passage Between Rocks, Railroad to Military Base, big rocks; ground 8-14 m above the plain |
| River + south-east | 200..285 | -211..181 | N-S river, Main Bridge, Junk Bridge, Smugglers Boat (200,152), Sniper Roadblock (143,162), RUAF road (x 131..181) |
| East | 290..510 | -205..70 | east railway, Big Red, Storage yard, Trailer Park, Crossroads (492,-43) |

## 3. Water, relief, vegetation

| River polygon | x | z | area m2 | role |
|---|---|---|---|---|
| river_0 | 202..259 | -3..181 | 6829 | south reach (widest, 57 m) |
| river_1 | 228..240 | 68..94 | 233 | island in the south reach |
| river_2 | 216..277 | -99..-9 | 3523 | middle reach |
| river_3 | 219..283 | -211..-103 | 4584 | north reach |

- Flows north to south; outlines in JSON `river.polys`. The four polygons leave 4-6 m gaps (z -103..-99 and z -9..-3), probably tracing seams - assumption: build the river as continuous from the north boundary (z about -185) to its south end (z 181). The playable polygon cuts the north reach at z about -185/-138 on its west side.
- **Main Bridge**: the highway crosses the river on a 33 m span, east end (250,43), west end (217,40); label (232,44). Two small booths stand on the east bank at (286,35) and (318,28).
- **Junk Bridge** (label (229,81)): two deck pieces, 22 x 5 m at (218,82) and 18 x 4.5 m at (245,75), either side of the 12 x 26 m island (228..240, 68..94) so the crossing is deck - island - deck. No other road crosses the river in the SVG. SPT scav zone `ZoneWade` (x 142..180, z -106..-56) hints at a ford on the west bank north of the bridge (inference).
- **Relief from 237 spawn-point heights** (JSON `spawns.relief_samples`, game y): flat plain y 1.0-1.7 over most of x -340..490, z -205..80. Local rises: sniper-ridge slope y 3.2-3.4 at (-382..-348, 81..86); east railway embankment y 3.1-3.2 at (324..326, -134..-67); Depot yard y up to 2.7. Local dips: east bank y -2.1..-0.7 at (292..297, 69..79) and (369..385, 31..37); west checkpoint y -1.5..-0.6 at (-418..-406, 9..68); south of the dorms y -0.9..-0.6 at (-63..-56, 156..231); sunken tank-farm pit y -0.3 at (-457..-451, -68..-62). **River valley deepens southward**: y -3.9 at (116,161), -5.0 (165,162), -6.9..-8.5 (173..184, 148..163), -12.1 at (194,161). **South/south-west plateau** (z > 130): y 7.6-13.9 - (-425..-355, 177..239) y 7.8-11.4, (-202..-185, 184..191) y 8.9-12.7, (-284,146) y 7.6, high point (-388,177) y 13.9. Highest structures: tower roof y 52, boiler-house roof y 16, Depot roof y 14.8.
- **Forests**: 37 polygons (JSON `forests`), 29 of them south of z 50. Largest: (181,122) 92x38 m, (5,125) 77x37, (-128,194) 60x46, (52,197) 60x33, (-140,106) 52x48; long strip (293,-129) 106x21 on the east bank. Rocks: 126 blobs `[x,z,r]` in JSON `rocks`.

## 4. Roads, railway, fences, power lines

Widths from the SVG style: gravel 5 m, small tarmac 5 m, medium (main) 8 m, large (highway) 12 m, railway drawn 3 m. All polylines are in JSON `roads`, `railway`, `fences`.

| id | name | width | length m | polyline (x,z) |
|---|---|---|---|---|
| paved_main_0 | Main road (E-W trunk, W gate to highway junction) | 8 | 698 | (158,90) > (-503,5) > (-534,-1) |
| paved_main_1 | RUAF road (N-S, junction to RUAF Roadblock) | 8 | 231 | (131,87) > (168,-11) > (180,-52) > (181,-89) > (172,-134) |
| paved_highway_0 | Highway (east edge to Main Bridge to south edge via Sniper Roadblock) | 12 | 571 | (532,-64) > (403,4) > (321,43) > (303,46) > (284,47) > (195,38) > (183,42) > (169,60) > (158,89) > (150,135) > (141,229) |
| paved_highway_1 | East-edge highway (N-S, Trailer Park to Crossroads) | 12 | 243 | (499,-228) > (491,15) |

| small tarmac road | name | length m | start > end |
|---|---|---|---|
| paved_small_0 | Military-base road (checkpoint to SW corner) | 204 | (-396,19) > (-487,194) |
| paved_small_1 | Administration-gate road (W edge to Warehouse 4 apron) | 361 | (-530,-54) > (-200,16) |
| paved_small_2 | Warehouse 4 - Old Gas road (N-S) | 217 | (-204,43) > (-192,-172) |
| paved_small_3 | Tank-farm / Factory north road | 218 | (-500,-18) > (-364,-92) |
| paved_small_4 | Dorms road (from Bus Station pad to dorms loop) | 218 | (-11,68) > (-24,174) |
| paved_small_5 | Crackhouse - Warehouse 17 - construction road (N edge to Old Construction) | 238 | (99,-172) > (59,27) |
| paved_small_6 | Trailer Park road (E-W) | 151 | (496,-162) > (346,-163) |
| paved_small_7 | - | 30 | (-268,35) > (-266,64) |
| paved_small_8 | - | 104 | (-239,39) > (-220,41) |
| paved_small_9 | - | 42 | (104,-51) > (64,-59) |
| paved_small_10 | - | 20 | (-56,63) > (-63,80) |
| paved_small_11 | - | 23 | (118,-78) > (97,-87) |
| paved_small_12 | - | 23 | (358,-142) > (365,-163) |
| paved_small_13 | - | 11 | (365,-163) > (361,-173) |
| paved_small_14 | - | 15 | (432,-163) > (427,-149) |
| paved_small_15 | - | 34 | (389,7) > (376,-17) |

- 14 gravel tracks (`dirt_0..13`): the network `dirt_2..11` (about 700 m) fills x -87..68, z -167..-27 around the Fortress/scav-base yard, biggest piece the 300 m loop `dirt_6` west and north of the Fortress; `dirt_0` (135 m) runs from the military-base road at (-457,96) to (-340,145) at the Powerline Tower pad; `dirt_1` leaves the Dorms road southward off the map (-12,245) > (-60,304); `dirt_13` (-394,-4) > (-389,-51) is the lane along the east side of the Streamer House; `dirt_12` (432,-163) > (428,-183) is a Trailer Park lane.
- **Junctions** (computed from the polylines): highway x east-edge highway at (492.6,-43.1) = the Crossroads; main road x highway at (157.8,89.8); RUAF road leaves the main road at (131.7,86.4) going north; off the main road: military-base road (-397,19), spur (-268,35), New Gas loop (-239,39)..(-220,41), Warehouse 4 road (-204,43), Bus Station pad (-55,62), Dorms road (-11,68); Administration road x Warehouse 4 road (-200,16); Administration road x tank-farm road (-500,-19); Crackhouse road x two spurs (104,-51) and (116,-78); Trailer Park road x east-edge highway (496,-162) and x its spurs (365,-163), (428,-163). Road ends outside the polygon (highway (532,-64) and (141,229); main road (-534,-1); Dorms dirt road (-60,304); Crackhouse road (99,-172)) leave the map.
- **Rail/road crossings** (SVG gives no bridge/level info): main road x diagonal railway at (-158,49); highway x east railway at (306,46); Warehouse 4 road x west rails at (-186,-87)/(-185,-93); gravel track x spur rails at (-79,-69)/(-72,-71).

| rail | length m | start > ... > end (x,z) |
|---|---|---|
| rail_0 | 653 | (-338,271) > (-234,142) > (7,-262) |
| rail_1 | 558 | (-470,-123) > (-171,-86) > (3,-265) |
| rail_2 | 190 | (-65,8) > (-79,-71) > (-64,-175) |
| rail_3 | 473 | (300,216) > (315,-256) |
| rail_4 | 553 | (-469,-129) > (-172,-91) > (-1,-269) |
| rail_5 | 128 | (-294,-1) > (-284,-66) > (-234,-94) |
| rail_6 | 130 | (-355,-9) > (-346,-74) > (-294,-101) |
| rail_7 | 131 | (-345,-7) > (-336,-70) > (-283,-100) |
| rail_8 | 207 | (319,-14) > (324,-170) > (314,-220) |
| rail_9 | 104 | (-149,-192) > (-141,-158) > (-87,-162) |
| rail_10 | 110 | (-57,2) > (-72,-72) > (-83,-105) |

- Railway notes: rail_0 (long diagonal SW corner > centre > north tip), rail_1 and rail_4 (twin lines from the west factory edge east along z -125..-86, then NE to the north tip), rail_2/rail_10 (short N-S sidings at x -57..-85 between the tower and the Fortress), rail_5..7 (three diagonal sidings between the Depot and Warehouse 3), rail_9 (spur north of Old Gas), rail_3 and rail_8 (east railway x 300-324). Scav extracts sit at the ends: Railroad to Military Base (-322,245), Railroad to Port (304,81), Railroad to Tarkov (326,-191).

| longest fences (68 total) | length m | from | to |
|---|---|---|---|
| fence_3 | 326 | (-354.6, 9.8) | (-167.7, -82.9) |
| fence_45 | 145 | (390.1, -38.7) | (362.9, -156.3) |
| fence_52 | 127 | (-301.6, -111.8) | (-341.8, 1.8) |
| fence_24 | 123 | (2.3, 58) | (111.2, 34.9) |
| fence_4 | 91 | (-163.3, 32.8) | (-103.3, 28.2) |
| fence_50 | 83 | (-103.3, 87.5) | (-52.3, 77.9) |
| fence_54 | 82 | (-102.5, 23.8) | (-89, -40.3) |
| fence_42 | 72 | (315.3, -88.3) | (313.8, -16.6) |
| fence_43 | 71 | (314.3, -11.9) | (368.8, 6.8) |
| fence_1 | 70 | (-483.8, -8.3) | (-414.9, 1.6) |

- Power lines: 2 lines, 12 towers (JSON `powerlines`): west line towers (-663,-25) (-514,-32) (-373,46) (-329,141) (-239,250) (-166,370) (line leaves the map at (-703,-27) and (-135,421)); east line towers (367,337) (323,204) (325,65) (394,-16) (409,-181) (468,-304). A pad with a booth for the Powerline Tower label is at (-338,151) 50 x 31 m rot -56 (booth (-339,129)).

## 5. Buildings and landmarks

Ground footprints from the SVG (confidence A unless marked). `fl` = levels above ground (0 = not enterable, tanks), `B` = has a basement. Concave outlines for ids 21, 25, 26, 27, 28, 30, 31, 34 are in JSON `buildings[].outline`. Full notes in the JSON.

| id | name | kind | cx | cz | w x d | rot | fl | c | notes |
|---|---|---|---|---|---|---|---|---|---|
| 8 | Storage block NW | warehouse_small | 436.8 | -126.1 | 31.8 x 15.5 | -88.7 | 1 | B | one of four 15.5 m-deep storage blocks (Storage label (451,-99)) |
| 9 | Storage block NE | warehouse_small | 460.5 | -123.1 | 36.5 x 15.5 | -88.6 | 1 | B | storage block |
| 10 | Storage block SW | warehouse_small | 434.9 | -72.7 | 49.7 x 15.6 | -88.2 | 1 | B | storage block |
| 11 | Storage block SE | warehouse_small | 459 | -78.6 | 36.4 x 15.4 | -88.5 | 1 | B | storage block |
| 12 | Fuel tank 1 (NW) | tank | -470.3 | -67.6 | 20.2 x 20 | 82.6 | 0 | B | round tank, about 20 m across; not enterable (assumed) |
| 13 | Fuel tank 2 (NE) | tank | -440.7 | -63.2 | 20.2 x 20 | 82.6 | 0 | B | round tank |
| 14 | Tank farm pump platform N | platform | -455.6 | -65 | 13.9 x 10 | 7.9 | 0 | B | pipe/pump gap between tanks 1 and 2; 5 west-group PMC spawns here at y -0.3 |
| 15 | Fuel tank 3 (SW) | tank | -474.8 | -40.1 | 20.2 x 20 | 82.6 | 0 | B | round tank |
| 16 | Fuel tank 4 (SE) | tank | -445.1 | -35.6 | 20.2 x 20 | 82.6 | 0 | B | round tank |
| 17 | Tank farm pump platform S | platform | -460 | -37.5 | 13.8 x 10 | 7.9 | 0 | B | pipe/pump gap between tanks 3 and 4 |
| 18 | Streamer House | house | -407 | -34.4 | 44.7 x 21.6 | -82.1 | 2 | A | 2nd floor in two blocks; possible 3rd ("USEC 2nd" layer); 2 locked ground rooms north; labelled Streamer House |
| 19 | Pump house | warehouse_small | -448.5 | -95.2 | 23.9 x 16.2 | 6.1 | 2 | A | 2 floors; ZB-1011 shed 21 m west |
| 20 | Warehouse 7 (dead scav warehouse) | warehouse | -392.9 | -85.4 | 42.7 x 24 | 7.2 | 2 | A | hall + two 2nd-floor rooms at x -405/-391 ("dead scav warehouse") |
| 21 | Depot (chemical warehouse) | warehouse | -312.2 | -32.2 | 49.1 x 41.1 | -81.2 | 1 | A | tall hall, L-shaped; flat roof y 14-15 = scav-sniper perch; PMC spawns inside |
| 22 | Warehouse 3 | warehouse | -228.7 | -58.8 | 54.6 x 38.2 | 8.6 | 1 | A | single big hall; PMC spawns inside |
| 23 | Warehouse 4 (switch/power building) | warehouse | -172.8 | -27.9 | 67.5 x 30.1 | -81.4 | 2+B | A | hall + partial 2nd floor + roof gantry + basement corridor 54x17; holds the ZB-013 power lever |
| 24 | New Gas Station | station | -247.3 | 65.9 | 33.2 x 24.4 | 7 | 1 | A | store 24x10 + canopy; 2 locked back rooms |
| 25 | Dorms, 2-storey | dorm | -68 | 184.8 | 42 x 16.5 | -82.3 | 2 | A | 4 locked rooms on L1, 1 on L2 |
| 26 | Dorms, 3-storey | dorm | -20 | 201.7 | 42 x 29.1 | -82.2 | 3 | A | 3 / 5 / 5 locked rooms on L1 / L2 / L3 |
| 27 | Oil-rig tower ("oilrig & panda") | tower | -112 | -8.4 | 73.6 x 32.1 | -78.2 | 4 | B | levels to y 54.7, roof perch y 52; opened in 0.16 (inferred); upper footprint reaches x -83 |
| 28 | Fortress (Scav base) | big_building | -40 | -93 | 61.4 x 25.1 | 79.8 | 2+B | A | 2 floors + basement ZB-013 (22.8x19.3); scav base compound |
| 29 | Crackhouse | house | 79.1 | -121.2 | 24.4 x 16.2 | 78.6 | 2 | A | 2 floors; "mechanic" layer covers it |
| 30 | Repair shop + boiler house complex | complex | 41.8 | -30.2 | 59.9 x 59.2 | -11.9 | 3+B | A | concave; boiler block 3 floors + basement, roof perch y 16.2; repair shop north arm 1 floor |
| 31 | Warehouse 17 | warehouse | 115.1 | -30.2 | 48.9 x 47.6 | -11.5 | 3 | A | concave; 3 levels (opened in 0.16, inferred); scav extract beside it |
| 32 | Old Construction | big_building | 83.4 | 23.4 | 25.5 x 19.7 | 4.3 | 2 | A | 2 floors; layer above 5.7 m at x 70..98, z 13..35 |
| 33 | Big Red | warehouse | 372.2 | -87.3 | 61 x 31.9 | -88.4 | 2 | A | long axis N-S; 2nd floor = room block at the south end (368,-68) 23x11 |
| 34 | Skeleton (unfinished tower) | tower | -39.6 | 20.8 | 60.7 x 25.1 | -10.5 | 3 | B | unfinished tower; 2nd floor = two 60x11 strips; height not in sources |
| 35 | Old Gas Station shed A (north) | shed | -152.7 | -149.6 | 8.9 x 8.8 | 76.9 | 1 | A | stairs (-150,-147) down to the basement extract |
| 36 | Military Checkpoint hut | house | -419.1 | 40 | 8.2 x 8 | 40.5 | 2 | A | scav-sniper perch y 3.1 on 2nd floor; 1 locked ground room |
| 37 | Military Checkpoint barracks | house | -418.1 | 56.3 | 16.5 x 16 | 47.4 | 1 | A | barracks, rotated 47 deg |
| 44 | Old Gas Station main building | station | -185.2 | -135.4 | 13 x 12.6 | -11.4 | 1 | A | forecourt pavement (-171,-138) 40x31 |
| 50 | ZB-1011 bunker entrance shed | bunker_entrance | -470 | -98.3 | 8.1 x 4.1 | -82.7 | 1+B | A | stairs (-470,-98) to bunker corridor (-465,-93) 14.7x3.4 |
| 51 | ZB-1012 bunker entrance shed | bunker_entrance | -307.3 | -82.8 | 8.1 x 4.1 | -83.2 | 1+B | A | stairs (-307,-83) to bunker corridor (-302,-78) 14.3x3.1 |
| 66 | Old Gas Station shed B (south) | shed | -150.7 | -140.9 | 9 x 8.4 | 76.9 | 1+B | A | second shed over the basement |

Small structures (kiosks, cabins, sheds, garage rows; all 1 level, confidence A/B):

| id | name | cx | cz | w x d | rot | locked room |
|---|---|---|---|---|---|---|
| 0 | Garage N of Warehouse 17 (a) | 147.6 | -75.7 | 18.2 x 6.3 | 82.6 |  |
| 1 | Garage N of Warehouse 17 (b) | 161 | -62.1 | 18.1 x 6.2 | -89.3 |  |
| 2 | Trailer-park south garage row | 454.3 | -151.4 | 45.1 x 6.3 | 2.1 |  |
| 3 | Storage yard east wall-row | 478.5 | -100.7 | 90.5 x 6.4 | -88.1 |  |
| 4 | Storage yard west wall-row | 416.4 | -87.3 | 104.1 x 6.1 | -88.2 |  |
| 5 | Cabin S of Big Red (a) | 416.9 | -29.1 | 7.8 x 4.6 | -57.2 |  |
| 6 | Cabin S of Big Red (b) | 422.2 | -28.4 | 7.9 x 4.6 | -66.6 |  |
| 7 | Storage yard diagonal row | 450.8 | -39.7 | 53.1 x 6.3 | -26.5 |  |
| 38 | Booth by powerline-tower pad | -338.8 | 128.5 | 6.3 x 2.8 | -54.4 |  |
| 39 | Bus Station booth (a) | -57.8 | 96.3 | 6.6 x 2.8 | 0 |  |
| 40 | Bus Station booth (b) | -38.8 | 107.4 | 6.1 x 2.5 | -0.3 |  |
| 41 | Dorms guard booth | -12.5 | 163.2 | 8.4 x 6.2 | -82.6 |  |
| 42 | Kiosk S of Skeleton (a) | -15.7 | 46.9 | 6.2 x 2.5 | 0 |  |
| 43 | Kiosk S of Skeleton (b) | -39.6 | 48.7 | 6.3 x 2.8 | 8.4 | yes |
| 45 | Booth S of Old Construction | 63.1 | 61.3 | 6.3 x 2.9 | 9.1 |  |
| 46 | Roadside hut E of Old Construction | 148 | 72.6 | 8.4 x 6.3 | 14.5 |  |
| 47 | Booth near Sniper Roadblock | 135.9 | 151.6 | 6.4 x 2.9 | -87.7 |  |
| 48 | Booth S of Warehouse 17 | 143.6 | 10.6 | 6.4 x 2.8 | -66.7 |  |
| 49 | Booth near Sniper Ridge | -361.6 | 80.3 | 6.3 x 2.7 | 6.2 |  |
| 52 | Main Bridge east booth (a) | 285.9 | 35.4 | 6.7 x 6.2 | 2 |  |
| 53 | Main Bridge east booth (b) | 317.5 | 28.2 | 6.7 x 6.2 | 3.2 |  |
| 54 | Booth S of Big Red | 365.5 | 1.4 | 10 x 5.4 | -23.8 |  |
| 55 | Trailer Park shack | 349.8 | -152.3 | 9.9 x 5.4 | -1 |  |
| 56 | Trailer A | 355.5 | -173.1 | 6.4 x 2.9 | -86.8 | yes |
| 57 | Trailer B | 412.2 | -188 | 6.4 x 2.8 | -83.9 | yes |
| 58 | Trailer C | 418.1 | -199.6 | 6.3 x 2.8 | -58.9 |  |
| 59 | Trailer Park long shed | 437.8 | -198.2 | 16.9 x 6.3 | 4.6 |  |
| 60 | Trailer D | 421.8 | -151 | 6.4 x 2.8 | -85.7 |  |
| 61 | Crackhouse kiosk | 92.6 | -137.6 | 6.6 x 2.9 | 79 |  |
| 62 | Kiosk E of Skeleton | -0.1 | 3.7 | 6.4 x 2.6 | -9.1 |  |
| 63 | Locked shack N of Warehouse 4 road | -205.4 | -15.1 | 6.4 x 2.9 | -82 | yes |
| 64 | Shack by main road (W) | -201.4 | 23.1 | 8.7 x 5.9 | -81.5 |  |
| 65 | Shack by main road (E) | -195.8 | 23.9 | 6.8 x 6.1 | -82.1 | yes |

Locked (key) rooms from the SVG: 29 in total - dorms 3-storey 13 (L1 3, L2 5, L3 5), dorms 2-storey 5 (L1 4, L2 1), Streamer House 2, New Gas Station 2, Big Red 1 (strip on L2), and one each in #36, #43, #56, #57, #63, #65. Coordinates in JSON `buildings[].locked_rooms` (each about 6.2 x 3.0 m).
Verify-list status: 3-storey and 2-storey dorms present; new and old gas stations present; warehouses 3, 4, 7, 17, Depot and Big Red present; Fortress, Crackhouse present; construction = Old Construction (#32) and the Skeleton tower (#34); Trailer Park present (label (374,-184), trailers #56-#60, long shed #59); bunkers ZB-1011, ZB-1012, ZB-013 (+ Warehouse 4 switch basement, boiler-room basement, Old Gas basement); shacks/kiosks present (ids above); checkpoints = Military Checkpoint hut + barracks (#36/#37) plus extract-only gates (RUAF Roadblock, Sniper Roadblock, Administration Gate, Old Road Gate); **no stand-alone power-station building** exists in any source - the power switch is the Warehouse 4 lever/basement, and the "Powerline Tower" label marks the pylon pad at (-334,145); nothing was found that was removed in 0.16.

## 6. Floors, basements, stairs

tarkov.dev floor extents (y = player-height window in which that layer is shown; ground floor is y < 2.7; JSON `floor_extents`, `underground`):

| layer | extent | y | x | z |
|---|---|---|---|---|
| 2nd Floor | dorms | 2.7..6.5 | -80..-2 | 160..225 |
| 2nd Floor | mechanic | 2.7..6.5 | 47..91 | -135..-48 |
| 2nd Floor | switch 2nd | 2.7..6.5 | -193..-178 | -49..5 |
| 2nd Floor | switch 2nd | 2.7..6.5 | -171..-158 | -24..-17 |
| 2nd Floor | scav checkpoint | 2.7..6.5 | -426..-414 | 34..45 |
| 2nd Floor | dead scav warehouse | 2.7..6.5 | -417..-369 | -99..-69 |
| 2nd Floor | pump 2nd | 2.7..6.5 | -462..-436 | -104..-85 |
| 2nd Floor | dead scav warehouse | 5.7..up | -417..-369 | -99..-69 |
| 2nd Floor | big red 2nd | 5.7..up | 362..386 | -96..-55 |
| 2nd Floor | skeleton | 5.7..up | -76..-6 | -125..38 |
| 2nd Floor | switch snipe | 5.7..up | -173..-153 | -60..-21 |
| 2nd Floor | USEC 2nd | 5.7..up | -421..-393 | -57..-11 |
| 2nd Floor | construction 2nd | 5.7..up | 70..98 | 13..35 |
| 2nd Floor | chemical warehouse sniper scav | 14..15 | -334..-287 | -55..-9 |
| 2nd Floor | warehouse 17 | 3.9..7.6 | 90..141 | -3..92 |
| 2nd Floor | boiler | 4.4..6.5 | 44..63 | -22..-7 |
| 2nd Floor | oilrig & panda | 4.6..7.9 | -116..-83 | -44..33.6 |
| 3rd Floor | dorms | 5.7..up | -80..-2 | 160..225 |
| 3rd Floor | warehouse 17 | 7.7..11.3 | 90..141 | -38..-3 |
| 3rd Floor | boiler | 6.7..11.6 | 37..75 | -29..0 |
| 3rd Floor | oilrig & panda | 8.0..11.1 | -116..-83 | -44..33.6 |
| 4th Floor | oilrig & panda | 11.2..54.7 | -116..-83 | -44..33.6 |

| underground extent (y <= 0.5) | x | z |
|---|---|---|
| zb-1011 | -472..-457 | -102..-90 |
| zb-1012 | -310..-295 | -87..-75 |
| old gas | -151..-145 | -149..-138 |
| switch basement | -186..-160 | -53..3 |
| zb-013 | -56..-30 | -123..-102 |
| boiler room | 41..75 | -26..-5 |

| cx | cz | w x d | rot | SVG underground polygon |
|---|---|---|---|---|
| -173.4 | -24.8 | 54.3 x 16.9 | -81.5 | Warehouse 4 switch basement corridor (6 pillars 1.7 m along its axis) |
| -43.9 | -114.1 | 22.8 x 19.3 | -10 | ZB-013 basement (Fortress north end) |
| -148 | -141.9 | 3.7 x 2.6 | 76.8 | Old Gas Station basement |
| -464.6 | -93.1 | 14.7 x 3.4 | 7.9 | ZB-1011 corridor |
| -302.1 | -77.8 | 14.3 x 3.1 | 7 | ZB-1012 corridor |

The boiler-room basement (x 41..75, z -26..-5, co-op extract) was added in 0.16 and has no SVG polygon. Stairs/ladders: 62 polygons in JSON `underground.stairs` (level 0 = underground, 1-3 = floor layers; the same `id` on several levels = one stairwell). Underground stairs: (-470,-98) ZB-1011, (-307,-83) ZB-1012, (-179,-11) and (-172,-47) Warehouse 4 basement, (-150,-147) Old Gas, (-34,-105) and (-50,-115) ZB-013. Upper-floor interior polygons per building: JSON `buildings[].upper_floor_polys`. Floor spacing inferred from those y windows: about 3-4 m (2nd floor surface at y 4-5, 3rd at y 7-8.5; the big warehouses have 4 m+ ground storeys).

## 7. Yards and pavement (concrete pads)

| id | name | cx | cz | w x d | rot | area m2 |
|---|---|---|---|---|---|---|
| 0 | Big Red yard | 356.8 | -79.9 | 125.1 x 67.8 | -88.3 | 5645 |
| 1 | Storage yard | 447.4 | -89.2 | 118.3 x 55.5 | -88.1 | 5934 |
| 2 | North trailer pad | 371.5 | -187.5 | 65.6 x 35 | 1.5 | 2266 |
| 3 | Skeleton north apron | -24.7 | -12.4 | 50.3 x 32.5 | -10 | 1572 |
| 4 | Repair shop forecourt | 77.4 | -82.7 | 48.4 x 36.1 | -11.1 | 1400 |
| 5 | Construction yard (S of boiler complex) | 42.6 | 36.3 | 79.6 x 45.2 | 4.2 | 3111 |
| 6 | Yard W of Scav base / tower base | -100 | -59.2 | 47.1 x 29.7 | 11.8 | 1185 |
| 7 | Old Gas Station forecourt | -171.4 | -138.4 | 39.7 x 30.9 | 79.5 | 961 |
| 8 | New Gas Station forecourt | -246.9 | 68.2 | 49.8 x 42.5 | 6.8 | 2095 |
| 9 | Warehouse 3/4 apron | -225 | -6.4 | 116.6 x 60 | 8.3 | 5177 |
| 10 | Warehouse 7 yard | -362 | -78.4 | 37 x 19.9 | -82.9 | 693 |
| 11 | Bus Station pad | -77.9 | 87.1 | 49.5 x 22.7 | 1.1 | 1061 |
| 12 | Skeleton south apron | -37.3 | 33.3 | 60.7 x 50.6 | -10.3 | 1997 |
| 13 | Powerline-tower pad | -338.5 | 151 | 50.2 x 30.7 | -56.1 | 987 |
| 14 | Dorms pad | -48.1 | 209.1 | 22.4 x 14.3 | 7.5 | 273 |
| 15 | Junk Bridge deck W | 217.9 | 81.9 | 21.6 x 4.8 | 0.5 | 103 |
| 16 | Junk Bridge deck E | 245.5 | 75.4 | 17.8 x 4.5 | -4.7 | 78 |

Outlines in JSON `yards[].outline`.

## 8. tarkov.dev labels (frame) and distances

Labels: Big Red (378, -84); Dorms (-37, 185); New Gas (-241, 66); Old Gas (-168, -138); Fortress (-38, -92); Crackhouse (80, -118); Streamer House (-404, -32); Main Bridge (232, 44); Sniper Hill (53, 120); Storage (451, -99); Trailer Park (374, -184); Junk Bridge (229, 81); Repair Shop (57, -55); Sniper Ridge (-328, 98); Old Construction (88, 26); Skeleton (-37, 22); Warehouse 3 (-227, -59); Depot (-309, -32); Warehouse 7 (-392, -83); Military Checkpoint (-409, 35); Bus Station (-75, 88); Warehouse 4 (-170, -32); Powerline Tower (-334, 145); Warehouse 17 (117, -24).

Straight-line distances (m) between landmark centres:

|  | Big Red | Dorms 3st | New Gas | Old Gas | Fortress | Skeleton | WH17 | Boiler | WH4 | Depot | Trailer Pk | Main Br. |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Big Red | 0 | 487 | 638 | 559 | 412 | 426 | 263 | 335 | 548 | 687 | 97 | 192 |
| Dorms 3st | 487 | 0 | 265 | 375 | 295 | 182 | 268 | 240 | 276 | 374 | 551 | 297 |
| New Gas | 638 | 265 | 0 | 211 | 261 | 213 | 375 | 305 | 120 | 118 | 670 | 480 |
| Old Gas | 559 | 375 | 211 | 0 | 151 | 214 | 318 | 250 | 108 | 164 | 561 | 454 |
| Fortress | 412 | 295 | 261 | 151 | 0 | 114 | 167 | 103 | 148 | 279 | 424 | 305 |
| Skeleton | 426 | 182 | 213 | 214 | 114 | 0 | 163 | 96 | 142 | 278 | 462 | 273 |
| WH17 | 263 | 268 | 375 | 318 | 167 | 163 | 0 | 73 | 288 | 427 | 301 | 138 |
| Boiler | 335 | 240 | 305 | 250 | 103 | 96 | 73 | 0 | 215 | 354 | 366 | 204 |
| WH4 | 548 | 276 | 120 | 108 | 148 | 142 | 288 | 215 | 0 | 139 | 569 | 411 |
| Depot | 687 | 374 | 118 | 164 | 279 | 278 | 427 | 354 | 139 | 0 | 703 | 550 |
| Trailer Pk | 97 | 551 | 670 | 561 | 424 | 462 | 301 | 366 | 569 | 703 | 0 | 269 |
| Main Br. | 192 | 297 | 480 | 454 | 305 | 273 | 138 | 204 | 411 | 550 | 269 | 0 |

## 9. Extracts and transits

Position = my best point; `err` = stated uncertainty radius. "East/west group" = the PMC entry point whose extract list contains it (SPT `EntryPoints`: **Customs** = east spawn half, **Boiler Tanks** = west spawn half; shared ones list both), so east-half spawners extract in the west and vice versa. Standard individual exit timer 8 s. JSON also keeps `icon_xy` (old-map icon position) per extract.

| PMC / shared / secret / co-op extract | side | group | x | z | err | c | condition (paraphrased) | chance % |
|---|---|---|---|---|---|---|---|---|
| ZB-1011 | pmc(+scav per TarkovForge) | east | -470 | -98.3 | 8 | B | none (always open) | 100 |
| Smugglers' Bunker (ZB-1012) | pmc+scav (secret) | both | -307.3 | -82.8 | 8 | B | secret exfil: needs "Note with code word Voron" found in the same raid (item 675aaab74bca0b001d02f356) | n/a (secret) |
| Old Gas Station | pmc(+scav per TarkovForge) | east | -150 | -144 | 8 | B | SPT chance 50 %; wiki: not always available, opened with a green flare, in the basement | 50 |
| Dorms V-Ex | pmc | both | -18.2 | 250.1 | 6 | B | pay 5,000 roubles (item id 5449016a4bdc2d6f028b456f) per player; max 4 players; 60 s shared timer; wiki: fee depends on Scav karma; single use | 50 |
| ZB-013 (also written ZB-1013) | pmc | both | -43.9 | -114.1 | 8 | B | power lever in Warehouse 4 (power stays on once thrown) + basement door; from 1.2.0.0 the door needs the ZB-1013 Key (40 uses) instead of the Factory emergency exit key | 100 |
| Crossroads | pmc+scav | west | 483.7 | -43 | 8 | B | none | 100 |
| Trailer Park | pmc+scav | west | 469.8 | -189.5 | 8 | B | none (wiki: in the trees) | 100 |
| RUAF Roadblock | pmc+scav (wiki: PvE only) | west | 175.5 | -126.8 | 8 | C | none; availability disputed: SPT exits list 100 %, SPT allExtracts lists PMC chance 0, wiki says PvE only | disputed |
| Smugglers' Boat | pmc+scav (secret) | both | 200.1 | 151.6 | 12 | B | secret exfil: same Voron note as the bunker exit | n/a (secret) |
| Railroad Passage (Flare) | pmc | both | -10 | -245 | 30 | C | fire a green signal flare (RSP-30 or 26x75) in the flare area and keep to the tracks; a sniper covers the wall (1.2.0.0: it no longer fires at players walking along the wall) | 100 |
| Boiler Room Basement (Co-op) | pmc+scav co-op | both | 58 | -15.5 | 8 | B | scav-cooperation: a PMC must bring a scav; since 1.2.0.0 available regardless of spawn side | 100 |

| scav extract | internal id | x | z | err | c | where |
|---|---|---|---|---|---|---|
| Administration Gate | Administration Gate | -513.4 | -23.9 | 6 | B | west edge gate on the Administration road |
| Factory Far Corner | Factory Far Corner | -486.2 | -128 | 6 | B | NW corner of the factory compound |
| Scav Checkpoint | Military Checkpoint | -484.6 | 5.4 | 6 | B | west main-road checkpoint; Reserve transit is behind it |
| Military Base CP | Shack | -476.7 | 191.2 | 6 | B | SW corner, end of the military-base road |
| Passage Between Rocks | Beyond Fuel Tank | -367 | 229.5 | 6 | B | south-west edge between rocks |
| Railroad to Military Base | Railroad To Military Base | -322 | 244.7 | 6 | B | south end of the long diagonal railway |
| Warehouse 4 | Warehouse 4 | -174.6 | 9.1 | 6 | B | beside Warehouse 4 |
| Factory Shacks | Factory Shacks | -43.9 | 47.4 | 6 | B | opposite the stacked portable cabins S of the Skeleton |
| Old Road Gate | Old Road Gate | -26 | 247.9 | 6 | B | south boundary on the old dirt road |
| Warehouse 17 | Warehouse 17 | 112.5 | -48.2 | 6 | B | beside Warehouse 17 |
| Sniper Roadblock | Sniper Roadblock | 142.8 | 161.9 | 6 | B | south on the highway; Shoreline transit is here since 0.16 |
| Railroad to Port | Railroad To Port | 304.4 | 80.9 | 6 | B | east railway south part |
| Railroad to Tarkov | Railroad To Tarkov | 326.3 | -190.6 | 6 | B | east railway north part |
| Trailer Park Workers' Shack | Trailer Park Workers Shack | 412.6 | -200.3 | 6 | B | NE trailer park |
| Old Gas Station Gate | Old Azs Gate | -150 | -158 | 25 | D | POSITION UNKNOWN: no icon on the 0.12.12 map; guessed near the Old Gas Station / Factory transit gate |

Shared extracts also usable by scavs: Crossroads, RUAF Roadblock (scav id `RUAF Roadblock_scav`), Trailer Park, Boiler Room Basement (co-op; the scav side is always on but needs a PMC co-op partner). Scav list above = SPT/wiki set as of 0.16-1.0; the wiki marks Old Gas Station Gate "not always available".
**Patch 1.2.0.0 (2026-10-06)** "adjusted PMC and Scav extracts by adding new exits": no retrievable source names them. TarkovForge (lists 22 extracts, undated) shows `Gate Near Medblock`, `Railroad to Reserve`, `Reserve Checkpoint` and omits Military Base CP, Railroad to Military Base, Scav Checkpoint, Old Gas Station Gate, Trailer Park Workers Shack, Warehouse 17, Factory Far Corner; `Railroad to Reserve` and `Reserve Checkpoint` are probably renames of the "Military Base" pair (unverified), `Gate Near Medblock` is unplaced. Treat positions of those as unknown.

| EFT display name | internal / older name | note |
|---|---|---|
| ZB-013 | EXFIL_ZB013; 0.12.12 map says ZB-1013 | called ZB-1013 again in 1.2.0.0 sources; key now "ZB-1013 Key" (40 uses, not sold on flea) |
| Smugglers' Bunker (ZB-1012) | customs_secret_voron_bunker; was ZB-1012 | secret since 0.16 (Voron note) |
| Smugglers' Boat | customs_secret_voron_boat; was Smuggler's Boat | secret since 0.16 |
| Railroad Passage (Flare) | customs_sniper_exit | new in 0.16 |
| Boiler Room Basement (Co-op) | Custom_scav_pmc | new in 0.16; 1.2.0.0: works from either spawn side |
| Scav Checkpoint | Military Checkpoint |  |
| Military Base CP | Shack |  |
| Passage Between Rocks | Beyond Fuel Tank |  |
| Old Gas Station Gate | Old Azs Gate |  |

Transits (SPT `transits`: all `active`, available after 60 s in raid, 20 s timer; Prima: open after the first minute; you lose stash access):

| transit | id | x | z | err | c | where |
|---|---|---|---|---|---|---|
| Transit to Shoreline | CUS_TRANSIT_42 / TRANSIT04 | 142.8 | 161.9 | 25 | C | metal door beside the main road at the former Sniper Roadblock, next to the Smugglers secret exfil |
| Transit to Reserve | CUS_TRANSIT_9 / TRANSIT03 | -498 | 4 | 25 | C | gate on the road behind the Scav Checkpoint |
| Transit to Interchange | CUS_TRANSIT_11 / TRANSIT02 | 465 | -190 | 25 | C | cluster of parked vehicles next to the Trailer Park extract |
| Transit to Factory | CUS_TRANSIT_10 / TRANSIT01 | -150 | -158 | 25 | C | orange gate beside the Old Gas Station extract |

Secret exits need `Note with code word Voron` (item 675aaab74bca0b001d02f356) found in the same raid (Prima; SPT). Dorms V-Ex: fee 5,000 roubles per player in SPT (wiki: depends on Scav karma), max 4 players, 60 s shared timer, 50 % chance. ZB-013: lever in Warehouse 4 (power stays on once thrown) + key since 1.2.0.0; the 0.12.12 map text read "req. power, factory exit key, in basement". No time-window extracts were found; Old Gas Station / Smugglers Boat / ZB-1012 were 50 % chance extracts in older data.

## 10. Spawns, bosses, hazards

PMC spawn points (SPT, exact coordinates; 5-point clusters; JSON `spawns.pmc_group_*`, point = [x, z, y, facing_deg], facing 0 = east, 90 = south):

| group | cluster x | cluster z | y | inside building |
|---|---|---|---|---|
| east | 67.7 | -71.2 | 1.1..1.4 | - |
| east | 147.6 | -91.4 | 1.2..1.4 | - |
| east | 177.4 | 155.7 | -8.5..-5 | - |
| east | 295.4 | 75.7 | -2.1..-1.4 | - |
| east | 313.9 | -100 | 1..1.7 | - |
| east | 356.5 | -199.6 | 1.5..1.6 | - |
| east | 376.7 | 34.4 | -1.5..-0.7 | - |
| east | 382.4 | -108.9 | 1.1..1.2 | Big Red |
| east | 471.6 | -56.8 | 0.9..1 | - |
| east | 485 | -189 | 0.9..1.2 | - |
| west | -482 | 81.8 | 1.3..1.9 | - |
| west | -454.1 | -64.3 | -0.3..-0.3 | Tank farm pump platform N |
| west | -419.3 | 180.3 | 8.9..11.4 | - |
| west | -408.6 | -79.2 | 1.5..1.5 | Warehouse 7 (dead scav warehouse) |
| west | -407.5 | -17.6 | 1.5..1.5 | Streamer House |
| west | -381.9 | 83.1 | 2.2..3.2 | - |
| west | -360.6 | 228.2 | 7.8..10.1 | - |
| west | -340.1 | -24.8 | 1.2..1.2 | - |
| west | -316.8 | -46.5 | 2.7..2.7 | Depot (chemical warehouse) |
| west | -224.9 | -82.1 | 1.1..2.2 | - |
| west | -218 | -55.7 | 1.4..1.4 | Warehouse 3 |
| west | -195.6 | 187.8 | 8.9..12.7 | - |
| west | -152.6 | -49.8 | 1.1..1.2 | - |
| west | -128.9 | -163.1 | 1.4..1.9 | - |

Co-op PMC group start: 20 points within x 57..67, z 47..55 (south of the boiler complex, y 1.2). Co-op opposite starts: 20 points along the main road (x -407..297, z 16..51). Per-faction (USEC/BEAR) spawn separation: none in the data - both factions use both groups.

Scav bot zones (SPT; `normal` = scav spawn points, `boss` = boss-capable points, `pmc_bot` = PvE PMC-bot points; bbox of the normal points):

| zone | normal | boss | pmc bot | x | z | area |
|---|---|---|---|---|---|---|
| ZoneBlockPost | 5 | 1 | 3 | -417..-325 | 42..81 | military checkpoint area |
| ZoneBrige | 6 | 0 | 3 | 116..194 | 6..163 | river west bank, Main Bridge to Sniper Roadblock |
| ZoneCrossRoad | 4 | 2 | 0 | -51..-12 | 30..37 | crossroads S of the Skeleton; boss points near dorms |
| ZoneCustoms | 15 | 3 | 6 | 321..499 | -201..21 | east: Big Red, Storage, Trailer Park |
| ZoneDormitory | 1 | 7 | 0 | -28 | 211 | dorms |
| ZoneFactoryCenter | 8 | 0 | 3 | -308..-160 | -82..11 | Depot, Warehouse 3/4 yards |
| ZoneFactorySide | 7 | 5 | 3 | -495..-351 | -104..-20 | west factory, tank farm side |
| ZoneGasStation | 9 | 0 | 0 | -304..-249 | 35..146 | New Gas Station and road south |
| ZoneOldAZS | 5 | 0 | 1 | -176..-128 | -157..-122 | Old Gas Station |
| ZoneScavBase | 7 | 13 | 0 | -97..29 | -75..-46 | Fortress yard; 13 boss points |
| ZoneTankSquare | 30 | 0 | 0 | -10..136 | -36..57 | repair shop / boiler / Warehouse 17 (23 of 30 points are inside buildings) |
| ZoneWade | 6 | 0 | 0 | 142..180 | -106..-56 | river west bank north of the bridge |

Sniper-scav perches (marksman spawn points):

| zone | x | z | y | spawn radius | on |
|---|---|---|---|---|---|
| ZoneBlockPostSniper | -418.8 | 35.9 | 3.1 | 115 | Military Checkpoint hut |
| ZoneSnipeBrige | 55.9 | -12.9 | 16.2 | 120 | Repair shop + boiler house complex |
| ZoneSnipeFactory | -313.1 | -36.9 | 14.8 | 120 | Depot (chemical warehouse) |
| ZoneSnipeTower | -90.8 | 15.6 | 52.0 | 130 | tower roof (inside its x -116..-83 extent) |

Bosses (SPT roll tables vs later sources - **chances disagree**):

| boss | chance % | SPT zones | where | guards |
|---|---|---|---|---|
| Reshala | spt 39; tarkovforge 60; timesaver ~75 (maybe event-elevated; normal 25-30) | ZoneDormitory, ZoneGasStation, ZoneScavBase | Dorms, New Gas Station, Scav base ("Stronghold" in TarkovForge) | 4 x followerBully |
| Knight + Big Pipe + Birdeye (the Goons-style trio) | spt 20; timesaver ~30 | ZoneScavBase | Scav base / ZB-013 area | Big Pipe 1, Birdeye 1 (SPT also lists 2 exUsec escorts, likely legacy) |
| Cultist Priest | spt 20; timesaver ~25 | ZoneScavBase (SPT) | wiki: area between Warehouse 17 and the repair shop | 4 x sectantWarrior |
| Partisan | spt 15; update 2026 10 09 base 25 (karma dependent) | - | anywhere (trigger PARTISAN_TRIGGER), ambush from tree lines | none |

Zone ids -> places: `ZoneDormitory` dorms, `ZoneGasStation` New Gas Station, `ZoneScavBase` Fortress/"Stronghold" (boss spawn points: 13, bbox x -123..121, z -135..-17, 7 inside buildings). Other SPT entries: Gifter 0 %, arena-fighter pack 5 % (zones FactoryCenter/ScavBase), PvE-only PMC-bot groups 50 %. Partisan base chance was raised to 25 % on 2026-10-09 (karma-dependent in PvP).

Hazards and mounted weapons:
- Border snipers: danger quad at the north tip (section 2). A sniper also guards the Railroad Passage flare area (1.2.0.0 fixed it shooting players who walk along the wall); position unknown.
- Mounted AGS-30 grenade launchers and NSV Utyos machine guns exist (wiki); **positions not found** in any retrievable source. Explosive propane cylinders were added in 0.16; **positions not found**.
- Airdrop: chance 0.2, needs >= 6 players, first plane 300-900 s, cooldown 600-700 s, max 1 (SPT). Raid 40 min (co-op 25 min), 12 players max in SPT data, max 4 bots per zone, 20 bots at start.

## 11. What changed: 0.12.x layout -> 0.16.0 -> 1.x

| version / date | change | basis |
|---|---|---|
| 0.6.0.861, 0.11.0.2448, 0.12.7.8334 | earlier Customs expansions listed by the wiki; the 0.12.12 2D map (icon source) and the SVG footprints predate the rework | wiki |
| 0.16.0.0, 2024-12-26 | rework: textures/materials/objects replaced, some buildings fully rebuilt, opaque glass blocks replaced by transparent ones, **three industrial-area buildings opened**, exploding propane cylinders, new points of interest, new exfils, transit to Shoreline (SPT also lists Reserve, Factory, Interchange) | patch notes (Insider Gaming, Sportskeeda) |
| 0.16.0 reveal article | Repair shop and surroundings heavily upgraded; small interiors around the Scav Checkpoint altered; additional underground sections; formerly closed buildings opened | Insider Gaming reveal |
| tarkov.dev 2025-01-18/20 | new tiles `customs_0.16`; **new floor layers for Warehouse 17 (2nd/3rd), boiler house (2nd/3rd), oil-rig tower (2nd-4th, up to y 54.7); new boiler-room basement**; map bounds and all 24 labels unchanged - matches the "three buildings opened" note (my inference) | maps.json history |
| 0.16 extract changes (data) | Smuggler's Boat and ZB-1012 became secret (Voron note); new Railroad Passage flare exit; new co-op Boiler Room Basement exit; ZB-013 needs the Warehouse 4 power lever; four transits | SPT, wiki, Prima |
| 1.1.0.0, 2026-08-03 | "additional optimization work on Customs", no layout change stated | patched.gg |
| 1.2.0.0, 2026-10-06 | new PMC and Scav exits (unnamed); new loot spots in locked dorm rooms, "USEC warehouse" and elsewhere; locked containers always hold loot; keys ZB-1013 Key and Guard Post Key added (guard post across from a gas station in the industrial area, unplaced; shacks #64/#65 near the main road are candidates); director-office safes reachable; flare-exit sniper fix; co-op extract works from any spawn; Factory-key door fixes; geometry fixes | SteamDB notes, TarkovForge, Timesaver, gaming-st.com |
| 2026-10-09 hotfixes | stuck spots on Customs fixed; Partisan base chance 25 % | senseos.gg |
| 1.3.0.0, 2026-10-29 | no Customs entry (visual/collider fixes on Icebreaker, Interchange, Shoreline only) | patched.gg |

Added/removed areas by name: no source lists any; nothing in the data was removed. Earlier 1.0.x notes (to 1.0.6.0, 2026-07-03) showed no Customs layout change.

## 12. Open uncertainties and parity gaps

- Building outlines are 0.12.x (SVG last edited 2024-01-10); post-rework footprints, new buildings and changed openings are unverified. Re3mr community maps (updated 2026-01-07) and the `customs_0.16` tile set could not be downloaded.
- The oil-rig tower, Warehouse 17 and boiler-house interiors (opened in 0.16) have extents and floor heights only, no room layout.
- Extract positions are 0.12.12 icon positions (+-5-10 m); Railroad Passage (inferred at the north rail tip), the four transits (landmark-based) and Old Gas Station Gate have 15-30 m or no position; extracts added or renamed in 1.2.0.0 are unknown.
- Boss chances conflict (Reshala 39 / 60 / ~75 %); Priest zone differs (SPT: scav base; wiki: between Warehouse 17 and the repair shop); Knight escorts differ (SPT lists 2 exUsec as well).
- RUAF Roadblock as a PvP PMC extract (wiki says PvE only; SPT lists chance 0 in one file and 100 in another).
- Mounted weapon and propane cylinder positions, loot spots by room, building heights above the floor counts, fence/wall heights: not available.
- Skeleton tower height and Streamer House third level unknown.
- ZB-013 lever place: wiki says crane yard of Warehouse 4; gaming-st.com says electrical panel in the building west of centre; the SVG shows the Warehouse 4 basement corridor and roof gantry as the "switch" areas.

## 13. Sources

Data (downloaded as untrusted data, parsed only): 
- https://github.com/the-hideout/tarkov-dev-svg-maps - `Customs.svg` (CC BY-NC-SA 4.0; last Customs edit f1d1c28, 2024-01-10)
- https://github.com/the-hideout/tarkov-dev - `src/data/maps.json` (commits fedc1cab 2025-01-18, bde396cd 2025-01-20, 756ec500 2026-01-07), `src/pages/map/index.jsx`, `public/maps/customs-2d.jpg` (0.12.12 map)
- https://github.com/the-hideout/tarkov-data-manager - `map_coordinates.json` (Customs rotation 180)
- https://github.com/sp-tarkov/server-csharp - `bigmap/base.json`, `allExtracts`, English locale (HEAD fe74b07, 2026-08-10)
Rules, names, patches (paraphrased):
- https://escapefromtarkov.fandom.com/wiki/Customs and https://escapefromtarkov.fandom.com/wiki/Reshala
- https://insider-gaming.com/tarkov-0-16-0-0-patch-notes-full-guide/ , https://sportskeeda.com/esports/escape-tarkov-patch-notes-update-0-16-0-0-new-event-customs-rework-prestige-system , https://insider-gaming.com/escape-from-tarkov-customs-rework-reveal
- https://primagames.com/tips/all-secret-exfil-locations-in-escape-from-tarkov , https://primagames.com/tips/all-transit-locations-in-escape-from-tarkov
- https://www.shacknews.com/article/145072/customs-scav-extracts-escape-from-tarkov , https://www.shacknews.com/article/145588/escape-from-tarkov-patch-notes-01690
- https://tarkovforge.com/maps/customs , https://tarkovforge.com/bosses/reshala , https://tarkovforge.com/blog/tarkov-patch-1-2-0-0-quests-keys-maps
- https://timesaver.gg/blog/tarkov-customs-map-guide , https://timesaver.gg/blog/tarkov-customs-interchange-loot-changes-1-2-0-0
- https://steamdb.info/patchnotes/25753588/ (1.2.0.0), https://patched.gg/games/escape-from-tarkov/patch-1100 , /patch-1200 , /patch-1300 , https://patched.gg/games/escape-from-tarkov
- https://gaming-st.com/pc-games/tarkov-zb-1013-key-customs-factory-key/ , https://senseos.gg/guides/escape-from-tarkov/coming-back-to-tarkov/
- https://www.gosunoob.com/guides/escape-from-tarkov-zb-013-extract-location-new-12-7-customs-map-expansion/ (2020, pre-rework only), https://insider-gaming.com/?p=175449 (1.0.2), https://www.bamboogaming.net/tarkov/patch (patch list)

Tried and failed: api.tarkov.dev/graphql and assets.tarkov.dev (HTTP 403), escorenews.com Customs extract article (fetch error).
