# Border Yard on the Customs layout: build spec

Owner, 2026-11-01: maps that imitate Tarkov's are a 100% imitation of the layout, less the exceptions: **same map,
own buildings and names** (Customs and Interchange; Woods stays parked). Border Yard is rebuilt on Customs' current
(post-0.16) layout at real scale. Reference: `docs/maps/reference/CUSTOMS_REFERENCE.md` and `customs_layout.json`
(metres; read section 0 for the frame and section 1 for accuracy grades A to D). The building outlines come from a
community map licensed CC BY-NC-SA 4.0 and drawn before the 0.16 rework: use them as a layout guide (where things
stand, how big, which way they face, how many floors), and design our own buildings on those spots. Never ship the
SVG or the raw data.

## Frame, scale, origin

- Reference frame: metres, x east, z south (north is -z), origin at the centre of the map bounds (1070 x 544 m).
- Roblox: **S = 3.125 studs per metre** (the project's scale; a character is 1.76 m). Map-local studs = metres x S.
- Origin `O = Vector3.new(0, 0, -5200)`: the map spans about x -1672..1672, z -6050..-4350 in world studs, far from
  every other map (Quay 7 at 0, Smelter x 1600, Meridian x -1600, the bunker z 4000).
- Heights: the flat plain (game y about 1.3) is local y 0. Local y studs = (game y - 1.3) x S. The south-west plateau
  stands 8 to 14 m higher; the river surface is about 1.5 m below the plain.
- Map-local coordinates in all code (MapKit's convention: `H.V(x, y, z)` adds O).

## Modules (Rojo: a folder with init.luau is one ModuleScript with children)

| File | Owner | What |
|---|---|---|
| `src/server/Maps/Border/init.luau` | foundation | entry `return function(kit, root)`: map model "Border", calls the parts in order, sets `W.bounds`, returns the model |
| `src/server/Maps/Border/Layout.luau` | foundation (generated) | the reference converted to studs with our names: boundary, river, roads, rails, fences, forests, rocks, yards, buildings, underground, floors, extracts, spawns, bosses, hazards, sniper zone |
| `src/server/Maps/Border/Ground.luau` | foundation | terrain (relief, river, banks, plateau, forest floor), roads and rail as parts or terrain, bridges, fences, power lines, yards, boundary walls |
| `src/server/Maps/Border/Buildings.luau` | buildings | every structure with floors, stairs, roofs, doors, windows, interiors (Blender kit props), containers and loose loot inside |
| `src/server/Maps/Border/Play.luau` | gameplay | extracts, spawns by side, AI routes, posts, scav zones, the boss and crew, visit zones, border snipers, propane, loose loot outdoors |
| `src/server/Maps/Border/Dress.luau` | gameplay | outdoor clutter: wrecks, poles, fence runs, cover, nature (adapt the old dressing pass) |
| `tools/customs_layout.py` | foundation | JSON -> Layout.luau (run with `python3 -I`) |

- World: `moduleMap("border", "Border")`. `src/server/Maps/BorderYard.luau` becomes a short stub (the laptop's copy
  cannot be deleted from a cloud session); it is no longer built.
- `src/shared/Maps.luau`: Border Yard raid time 2400 s (Customs is 40 minutes); new description.
- The old module is the best example of every API: `git show HEAD:src/server/Maps/BorderYard.luau` (kit.model,
  MapKit, Kit.place, TerrainKit, kit.extract, kit.loose, kit.container, doors, W.spawns, W.sideExtracts, W.patrols,
  W.watchPosts, W.scavZones, W.visitZones, W.boss, the dressing pass, hazards and snipers).

## Our names (the layout is Customs', the names are ours)

| Customs | Border Yard |
|---|---|
| Dorms, 3-storey / 2-storey | BLOCK A / BLOCK B (marked room: ROOM 314, existing KEY_BY_314) |
| New Gas Station / Old Gas Station | FUEL STOP / OLD PUMPS |
| Big Red | RED STORES |
| Fortress (scav base) | THE BASTION |
| Skeleton | THE FRAME |
| Oil-rig tower | THE DERRICK |
| Crackhouse | THE SQUAT |
| Repair shop + boiler house | MOTOR SHOP + BOILER HOUSE (existing KEY_BY_BOILER) |
| Warehouse 3, 4, 7, 17 | STORE 3, STORE 4, STORE 7, STORE 17 |
| Depot / Streamer House / Old Construction / Factory Shacks | DEPOT / WATCHHOUSE / OLD WORKS / FACTORY HUTS |
| Trailer Park / Storage yard | TRAILER LOT / STORAGE YARD |
| ZB-1011 / ZB-1012 / ZB-013 | BUNKER K-11 / SMUGGLERS' HOLE / BUNKER K-13 |
| Scav Checkpoint / Military Checkpoint / Administration Gate | OLD CHECKPOINT / ARMY POST / OFFICE GATE |
| Main Bridge / Junk Bridge | MAIN BRIDGE / SCRAP BRIDGE |
| Reshala and guards | THE BROKER and his crew (existing) |

Extract names: CROSSROADS, TRAILER LOT, OLD PUMPS, BUNKER K-11, BUNKER K-13, SMUGGLERS' HOLE, DORMS CAR (paid),
SMUGGLERS' BOAT (chance), OLD ROAD GATE, ROCK PASS, ARMY GATE, ARMY ROADBLOCK, CITY LINE, PORT LINE, ARMY LINE,
FAR CORNER, OFFICE GATE, OLD CHECKPOINT, BOILER CELLAR, NORTH LINE (the flare exit), HILL ROADBLOCK. Conditions and
sides follow the reference (section 9): keys, switches and paid exits use our key items and the existing extract kinds
(open, paid, key, chance, scav, switch); co-op extracts and transits do not exist here yet (log the gap).

## Budgets (owner: full detail at full performance, 30 FPS on low-end phones)

- Built once at server start; StreamingEnabled is on. Building parts under about 18,000; Blender kit props under
  900; at most 40 lights that cast shadows (most lights without shadows); terrain water for the river only.
- Interiors are furnished with the existing Blender kits (`src/shared/KitMeta.luau`, 155 props: beds, lockers, desks,
  shelves, pallet racks, cars, a forklift, generators...) and MapKit furniture. Indoor props cast no sun shadow.
- Detail plan: walls are real wall parts (Block, CanCollide, thin <= 2.6), floors slabs, so the detail layer finds
  them; inside rooms use plaster or concrete, outside brick, concrete panels or corrugated metal.

## Rules for every agent

- Work only in `/home/claude/EscapeFromBloxov`. No tools starting with mcp__remote-devices__, no Studio, Blender or
  browser: the main session runs Studio and tests your code.
- Match the code style around you (compact data tables, plain comments). `python3 tools/luau_check.py src` must pass.
  There is no Luau runtime here: write carefully, keep functions small, nil-check everything that can be missing.
- Touch only your own files (table above) plus anything your brief names. Commit only your files, with the message
  your brief gives and these two lines at the end:

      Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
      Claude-Session: https://claude.ai/code/session_01518mnhhAQemNYvSZZj7jTR

  If git says index.lock exists, wait 20 s and try again.
