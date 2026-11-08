# Factory layout reference for the SMELTER rebuild

Escape from Tarkov Factory (`factory4_day` / `factory4_night`), state of 2026-11-08: the 0.15.0.0 rework
(2024-08-20) with the transits, the 0.16 hidden exit and the 1.x extract list. Companion data with identical numbers:
`factory_layout.json` (metres). Render of that JSON alone: `factory_layout_preview.png`. What our builder makes, drawn
over it: `smelter_build_preview.png` (both made by `tools/smelter_preview.py`). Build spec: `../SMELTER_FACTORY_BUILD.md`.

**No live API data**: api.tarkov.dev and assets.tarkov.dev refuse the sandbox proxy (as for Customs), and SPT's
`looseLoot.json` is a Git LFS file the git proxy does not serve. Rules, spawns and bosses come from the SPT server
database instead (section 1). Nothing was worked around.

## 0. Frame and conventions

- Units metres. **x = east (+), z = south (+)**, north is -z (the top of the 2D map). y = game height (the main hall
  floor is y 0.1). Origin = centre of the tarkov.dev bounds (game x 5.75, z 1.45).
- game -> frame: `x = 1.45 - z_game`, `z = 5.75 - x_game` (tarkov.dev `coordinateRotation` 90).
- SVG -> frame: `x = u * 131.9 / 130.81831 - 65.95`, `z = v * 142.5 / 141.23242 - 71.25` (Factory.svg viewBox units).
- re3mr plan -> frame: `x = (px - ox) / 12.2`, `z = (py - 1273) / 12.2`, `ox` = 840 (third floor), 2472 (second),
  4098 (ground), 5732 (tunnels); registered to the SVG walls to about 0.5 m.
- Footprints: `cx, cz` centre, `w` long side, `d` short side, `rot` = angle of the w axis from +x toward +z (degrees).
  Floors are rings of points with a `role` (outer, island, hole, void) found by nesting depth.
- Roblox: `CFrame.new(cx, y, cz) * CFrame.Angles(0, -math.rad(rot), 0)`, north = -Z, as Roblox forward.
- Grades: **A** traced outline or label within 2 m; **B** an icon or SPT point matched to the traced walls (+-1-3 m);
  **C** inferred (a painted sign, a description) (+-5-15 m); **D** no position source.
- Licence and IP: Factory.svg and the re3mr plan are CC BY-NC-SA 4.0. Only positions and outlines were read; no SVG,
  no plan pixels and no raw SPT files are in the repo. Project rule 1 asks for Tarkov's layout with our own buildings,
  interiors and names: every name a player sees is ours (section 4).

## 1. Data lineage and accuracy

| Layer | Source | Vintage | Accuracy |
|---|---|---|---|
| Floors, walls, obstacles, stairs, ledges, silos (four levels) | tarkov-dev-svg-maps `Factory.svg` (hand-traced, my own parser) | rework drawn 2024-11-07 (e25d83f), transform applied (81177ae) | +-0.5-1 m (A) |
| 27 labels, layer windows, bounds | tarkov.dev `src/data/maps.json` | main 2026-11-07 | +-1 m (A) |
| Extract, transit, lock, breach, jump, drop and PMC-ring icons, painted gate numbers | re3mr Factory plan v1.7c (tarkov-dev `public/maps/factory-2d.jpg`) | 0.15 era (no Gate 2) | +-1-3 m (B) |
| Spawn points (player, bot, boss, co-op), exit rules, bosses, waves, transits, container groups | SPT server-csharp `factory4_day` and `factory4_night` (HEAD fe74b07, 2026-08-10, EFT 0.16.9) | 0.16.9 | exact coordinates; rules may differ from live PvP |
| Live names, Gate 2, key uses, boss chances | tarkovforge, tarkovkit (1.3.0.0), tarkov-navigator, the wiki | to 2026-11-08 | sources disagree in places (section 13) |

Floor heights are SPT spawn-point heights (section 3). Heights of roofs, wall tops and machines are in no source.

## 2. Extents, orientation, outline

- Frame x -65.95..65.95, z -71.25..71.25 (131.9 x 142.5 m); tarkov.dev bounds in game units [[77, -64.5], [-65.5, 67.4]].
- Ground level (halls, annexes, yards): x -65.9..66.0, z -68.7..71.2, 11,540 m2 of floor in 2 outer rings, 26 holes
  (the pit, stair wells, the drop holes).
- Tunnels: x -66.0..47.8, z -71.2..52.0, 4,946 m2 (1 outer ring, 2 islands, 8 holes).
- Office second floor and the control gallery: 1,121 m2 in 5 pieces (x -47.2..37.8, z -55.7..29.1).
- Third floor and catwalks: 5,508 m2 drawn with 14 voids (3,564 m2): the office's third floor plus the catwalk grid
  over the main hall (x -62.0..38.3, z -60.9..47.2).
- North-up shape: the main hall (pit and crucibles) in the middle; the three-storey office block on its west side with
  the courtyard beyond it; the south-west wing (container room, timber store, loading dock, dugout, control gallery)
  south of the office; the furnace hall, pump house, machine house, north gallery and forklift bay along the north;
  the east bays and the east yard (transit to Customs) on the east; the aid post (Med Tent) in the south-east.

## 3. Levels and heights (game y)

| Level | game y | Source |
|---|---|---|
| tunnels | -2.60 | 33 SPT points (-2.60..-2.67) |
| sump (Underground Stash cave) | -3.86 | 4 SPT points |
| main hall, annexes, east yard | 0.10 | SPT points 0.04..0.31 |
| south-west wing, courtyard, office ground floor | 1.08 | SPT points 1.08..1.41 (courtyard 1.10..1.80) |
| control gallery (and the loading dock, ours) | 2.73 | 5 SPT points |
| office second floor | 4.57 | SPT points 4.55..4.57 |
| office third floor (and the catwalks, ours) | 8.23 | 1 SPT point; the catwalks meet it at the high bridge |

tarkov.dev layer windows: tunnels below -1, ground -1..3, second 3..6, third above 6.

## 4. Areas: tarkov.dev labels and our names

| EFT label | Ours | x, z (m) | game y window |
|---|---|---|---|
| Office Building | OFFICE BLOCK | -37.5, -15.2 | all |
| Main Office | SHIFT OFFICE | -37.5, -9.8 | third |
| Breach Room | RECORDS ROOM | -37.5, -18.8 | third |
| Locked Office | MANAGER'S OFFICE | -37.5, -24.8 | third |
| North Stairs / South Stairs | NORTH STAIR / SOUTH STAIR | -37.5, -29.2 / -37.5, -3.2 | all |
| Sky Bridge | HIGH BRIDGE | -24.6, -28.2 | third |
| Connector | THE LINK | -15.6, -23.8 | all |
| Locker Rooms | CHANGING ROOM | -39.5, -23.2 | second |
| Sinks | WASHROOM | -39.5, -9.2 | second |
| Hole | THE DROP | -40.5, -14.2 | second |
| Platform | LOADING DOCK | -35.5, 8.8 | ground-second |
| Servers | CONTROL GALLERY | -25.6, 26.8 | second |
| Med Tent | AID POST | 30.4, 23.8 | ground |
| Silos | THE CRUCIBLES | -9.1, 1.2 | ground |
| Heli Crash | THE WRECK | 9.9, -24.2 | all |
| Pit | CRUCIBLE PIT | -14.6, 6.8 | tunnels |
| Underground Stash | THE SUMP | 25.9, 7.8 | tunnels |
| Scav Bunker | THE DUGOUT | -21.6, 26.2 | ground |
| Blue Containers | CONTAINER ROOM | -48.5, 23.8 | ground |
| Wood Room | TIMBER STORE | -59.5, 51.2 | ground |
| Glass Hall | NORTH GALLERY | 21.4, -62.5 | ground |
| Boilers | FURNACE HALL | -3.5, -50.2 | ground-second |
| Pumping Station | PUMP HOUSE | 12.4, -35.2 | ground-second |
| East Halls | EAST BAYS | 37.5, -38.2 | ground |
| Forklifts | FORKLIFT BAY | 43.5, -60.2 | ground |
| Rafters | THE CATWALKS | -2.5, -12.2 | third |

## 5. Floors, walls, stairs, landmarks (JSON keys)

- `floors`: rings per level (ground 28, tunnels 11, second 8, third 16). `walls`: polylines (ground 51, second 7,
  third 5). `obstacles`: machines, tanks, vehicles, pallet rows, lockers drawn solid in the SVG (ground 38, second 9),
  as footprints with a `kind`.
- `stairs`: 35 flights from the SVG stair symbols with the levels they join. 9 are U-turn towers: the office's north
  and south stairs (-38.6, -29.6 and -38.6, -3.2, tunnels to third floor), the link (-17.5, -24.3), two on the south
  hall wall (-12.1, 26.1 and 6.4, 26.1), the north-east (28.6, -47.8) and east (28.7, -25.0, tunnels to second)
  stairs, and two in the west wing (-50.3, 1.8 and -46.2, 44.1).
- `silos`: six round machines: three in the pit (r 3.58 m, x -14.54, z 10.56 / -0.93 / -11.74) and three on the hall
  floor east of it (r 2.92 m, x -4.18). `ledges`: the pit (34.4 x 9.85 m, N-S, sunk to the tunnel floor), two
  service pits by the wreck (6.7 x 1.54 m) and the raised loading dock (20.2 x 4.9 m). `machine_house`: the block in
  the north hall (13.8 x 6.6 m at 17.4, -53.9).
- Painted gate numbers on the re3mr plan: GATE 1 (55.2, -70.0), GATE 2 (46.9, -44.1), GATE 4 (41.7, 18.7), GATE 5
  (0.7, 30.3).

## 6. Extracts and transits

Hold times in EFT: 10 s for PMCs, 8 s for scavs (the hidden exit 15 s). Exits open 60 s after the raid starts (SPT).

| EFT | Ours | id | Sides | x, z (m) | Level | Grade | Rule |
|---|---|---|---|---|---|---|---|
| Gate 3 | ORE GATE | G3 | PMC, scav | -62.0, -53.3 | ground | B | always open (SPT, day and night) |
| Gate 0 | SLAG GATE | G0 | PMC | -54.6, 68.5 | ground | B | always open; SPT `DisabledScavExits` "Cellars,Gate 0" (the wiki's key note is pre-0.15) |
| Med Tent Gate | AID POST GATE | GM | PMC | 59.5, 23.4 | ground | B | behind the passage door the emergency exit key opens |
| Cellars | CABLE CELLAR | CL | PMC | 31.4, -66.4 | tunnels | B | behind the tunnel door the emergency exit key opens |
| Courtyard Gate | YARD GATE | GY | PMC | -62.4, -15.0 | courtyard | B | always open (SPT "Gate_o") |
| Gate 2 | COKE GATE | G2 | PMC | 47.0, -40.4 | ground | C | 1.x lists only; conditions unpublished; position = the painted GATE 2 |
| Camera Bunker Door | BUNKER HATCH | CB | scav | -38.6, 20.0 | tunnels | B | always open; the icon sits on the tunnel wall, the zone 4.8 m east in the tunnel |
| Office Window | TIMEKEEPER'S WINDOW | OW | scav | -38.9, -11.3 | third | B | always open |
| Smugglers' Passage | SMUGGLERS' CRAWL | SC | PMC, scav | 37.0, -43.2 | tunnels | B | hidden exit (`factory_secret_ark`): needs the note with the code word Ark, 15 s |

| EFT transit | Ours | To | x, z (m) | Level | Rule (SPT) |
|---|---|---|---|---|---|
| Transit to Customs | TRANSIT TO BORDER YARD | Border Yard | 53.0, -11.9 | ground (east yard) | active after 60 s, 20 s timer |
| Transit to Woods | (none: Pinewatch is parked) | - | -64.0, -9.8 | courtyard | active after 60 s, 20 s timer |
| Transit to The Lab | (none: no Lab here) | - | 44.5, 32.0 | tunnels | SPT "free access"; the re3mr plan says a lab keycard |

Customs' end of the Factory transit (Customs reference): (-150, -158) m in the Customs frame.

## 7. Spawns and AI points

- Player spawns: 18 SPT clusters (5 points each, facing given). One stands east of the frame at (74, -65) (a 0.12-era
  point) and one is a lone point (-37.7, 48.7); the other **16** are the groups the re3mr plan rings. Sides "All",
  infiltration "Factory": one entry point, so every PMC exit serves every spawn.
- Bot points (scavs): 12, at (23.1, -8.0, -2.3), (-21.3, 26.5, 0.2), (-35.0, -29.8, 8.2), (36.5, 1.0, 0.0),
  (-8.6, 12.5, 0.2), (32.1, -18.1, -2.6), (28.9, 11.6, 0.1), (-61.4, 25.7, 1.1), (35.9, -20.7, -2.5),
  (-33.9, -30.2, 4.5), (-28.5, 37.8, -2.6), (-61.6, 3.6, 1.1) (x, z, game y).
- Boss-capable points: 7, at (6.4, 24.9, -3.8), (10.1, -2.3, 0.1), (-36.9, -30.3, 1.1), (1.8, -26.0, 0.1),
  (-2.9, -16.6, 0.9), (-13.7, -25.0, 0.3), (-2.3, -9.2, 0.1).
- Co-op (PvE "Coop,Opposite") points: 41, kept in the JSON, not used.

## 8. Bosses

| Raid | Boss | Chance | Zone | Escort | Source |
|---|---|---|---|---|---|
| day | Tagilla | 30 % | BotZone (any scav spawn) | none | SPT; tarkovkit 1.3.0.0; tarkovforge |
| night | Tagilla | 30 % | BotZone | none | SPT |
| night | Cultist priest | 20 % | BotZone | 2-3 cultist warriors | SPT |

Live on 2026-11-08: tarkovforge shows infected bosses on Factory and 15 % for Night Factory cultists (the Halloween
event); tarkov-navigator lists Tagilla at 35 %. Ours keeps SPT's 30 % (THE STOKER) and the cult at night.

## 9. Keys, locked doors, breach, jump and drop spots

| Door (EFT) | x, z (m) | Level | Key |
|---|---|---|---|
| Med Tent Gate passage | 51.1, 25.0 | ground | Factory emergency exit key |
| Cellars passage | 31.4, -61.3 | tunnels | Factory emergency exit key |
| Locked Office | -35.2, -24.3 | third | Factory emergency exit key |
| TerraGroup storage room | -42.05, 26.04 (doorway x -42.39..-41.71, z 25.49..26.58; icon at -42.4, 24.4) | tunnels | TerraGroup storage room keycard (two bank safes) |

- Factory emergency exit key: 20 uses, 2 quests, 3 doors (tarkovforge, tarkovkit); found in jackets (wiki).
- Breach door: the Breach Room on the third floor (-35.6, -19.6).
- Jump windows: courtyard into the office ground floor (-45.2, -22.8) and (-43.2, -8.3); the courtyard stair into
  the office second floor (-47.6, -6.5); east bays to the east yard (47.5, -35.9).
- Drops: a hole by the north-east stair (30.8, -51.6) and the collapsed floor into the stash cave (13.6, 10.3), both
  ground to tunnels; the hole in the office second floor (-41.0, -14.4) to the ground floor.

## 10. Loot

SPT container placements (positions all zero in SPT: none known) and the expected number per raid:

| Kind | Placements | Per raid |
|---|---|---|
| Wooden crate | 63 | 25.1 |
| Toolbox | 22 | 10.8 |
| Jacket | 17 | 17.0 |
| Duffle bag | 13 | 6.8 |
| Weapon box | 13 | 6.0 |
| Grenade box | 10 | 3.5 |
| Drawer | 8 | 8.0 |
| Medbag | 7 | 3.0 |
| Dead scav | 4 | 4.0 |
| PMC body | 3 | 3.0 |
| Bank safe | 2 | 1.4 |
| Safe | 2 | 2.0 |
| Technical supply crate | 2 | 2.0 |
| **All** | **166** | **about 93** |

Groups (min-max a raid): crates in five areas (`wb_Area_01..04`, `wb_Administration_office`) and the basement
(`Basment_scontainer_Weapon_box_01`, 4-6), toolboxes 7-12, duffle bags 6-9, grenade boxes 4-6, medbags 3-5, weapon
boxes 1-3 and 4-7 (by the exits), bank safes 1-2 (`terra_stock`). Loose loot positions: SPT LFS, not reached (D).

## 11. Raid settings

- 20 minutes by day, 25 at night (wiki, SPT). Players: wiki 4-5 by day and 4-6 at night; tarkovforge 4-6; SPT
  7-8 and 5-6. Exit access after 60 s; insurance on. SPT global loot modifier 0.27 by day, 0.33 at night.
- SPT scav waves (seconds from the start): 40-150 (1-3), at start (2-4), 300-350 (2-4, hard), 300-400 (2-4),
  410-500 (2-4), 460-510 (3-4, hard), 1200-1500 (1-3, hard), 1600-1700 (0-3, hard).

## 12. What changed

- Factory is EFT's first location (wiki).
- 0.15.0.0 (2024-08-20) rework, patch notes as quoted by Sportskeeda: geometry and textures redesigned "while
  maintaining the general dimensions and layout"; rooms, basements and workshops refined; parts of the plant and "the
  cellar area that connects all four workshops" expanded; outdoor areas added around the plant; new crosswalks at
  dead ends; the upper level in the workshops made easier to reach; loot, containers, spawns and extracts adjusted.
  The SVG used here was redrawn for that rework (2024-11-07).
- Transits (Customs, Woods, The Lab) and the hidden exit with the code word Ark (0.16) are in SPT 0.16.9.
- Gate 2 is listed by the 1.x sources (tarkovforge, tarkovkit 1.3.0.0, tarkov-navigator) but is in neither SPT
  0.16.9 nor the re3mr v1.7c plan.

## 13. Open uncertainties and parity gaps

- Heights of roofs, wall tops, the catwalks over the hall and the machines: no source (ours in the build).
- Gate 2: position and conditions grade C. The live extract outlines (api.tarkov.dev) were not reachable.
- SPT is 0.16.9; live PvP rules may differ (Gate 0 for scavs, the Lab transit's keycard, boss chances).
- Container and loose-loot positions: none in any reachable source; the build places them (ours).
- tarkovkit's page contradicts itself (9 or 10 extracts, a 100 % infected boss header); tarkovforge shows the event's
  bosses. Section 8 keeps SPT's numbers and lists the others.
- The build departs from these numbers where Roblox needs room to walk (doorways 1.4 m, the courtyard's windows
  broken out, paired catwalks joined): `../SMELTER_FACTORY_BUILD.md`, "Walking room".

## 14. Sources

- the-hideout/tarkov-dev-svg-maps, `Factory.svg` (commits e25d83f, 81177ae; CC BY-NC-SA 4.0): https://github.com/the-hideout/tarkov-dev-svg-maps
- the-hideout/tarkov-dev, `src/data/maps.json` and `public/maps/factory-2d.jpg` (re3mr plan v1.7c, CC BY-NC-SA 4.0): https://github.com/the-hideout/tarkov-dev
- sp-tarkov/server-csharp, locations `factory4_day`, `factory4_night`, locale en (HEAD fe74b07): https://github.com/sp-tarkov/server-csharp
- https://escapefromtarkov.fandom.com/wiki/Factory
- https://tarkovforge.com/maps/factory, https://tarkovforge.com/map-guide/factory, https://tarkovforge.com/keys/factory-emergency-exit-key, https://tarkovforge.com/bosses/tagilla, https://tarkovforge.com/bosses/cultist-priest
- https://tarkovkit.com/en/guides/map-guide/factory (Factory Guide 1.3.0.0)
- https://tarkov-navigator.com/en/maps/factory/
- https://www.sportskeeda.com/esports/escape-tarkov-patch-0-15-0-0-notes-factory-rework-partisan-boss-qol-improvements
- Declined: api.tarkov.dev (GraphQL), assets.tarkov.dev, SPT `looseLoot.json` (LFS).
