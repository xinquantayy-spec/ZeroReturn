# Meridian Mall on the Interchange layout: build spec

Owner, 2026-11-01: maps that imitate Tarkov's are a 100% imitation of the layout, less the exceptions: **same map,
own buildings and names** (Customs and Interchange). Meridian Mall is rebuilt on Interchange's current (1.0, expanded
outside) layout at real scale, the same way as Border Yard (`docs/maps/BORDER_CUSTOMS_BUILD.md`, `BORDER_YARD.md`).
Reference: `docs/maps/reference/INTERCHANGE_REFERENCE.md` and `interchange_layout.json` (metres; read sections 0 and 1
of the reference for the frame and the accuracy grades A to D). The SVG outlines it was measured from are licensed CC
BY-NC-SA 4.0: use them as a layout guide (where things stand, how big, which way they face, how many floors) and design
our own buildings, stores and signs on those spots. Never ship the SVG or the raw data. No real brands, no Tarkov store
names, logos or fonts: every name below and every store name the agents invent is ours.

## Frame, scale, origin

- Reference frame: metres, x east, z south (north is -z), origin at the centre of the tarkov.dev 2D bounds
  (1031 x 868 m). Game heights: flat ground y 21.4, the mall's main floor L1 y 27.1, the upper floor L2 y 36.6.
- Roblox: **S = 3.125 studs per metre** (a character is 1.76 m). Map-local studs = metres x S.
- Origin **`O = Vector3.new(0, 0, 9000)`**: the map spans about x -1611..1611, z 7644..10356 in world studs, clear of
  every other map (Quay 7 at 0, Smelter x 1600, Border Yard z -5200, Pinewatch (parked) z 2000, the bunker z 4000).
- Heights: local y studs = (game y - 21.4) x S. Ground and the car park level L0 = 0, **L1 = 17.8**, **L2 = 47.5**.
  The roof height is in no source (grade D): put the L2 ceiling about 6.5 m (20 studs) above L2 and the roof slab on it;
  the two domes and the skylights stand on the roof. The roof is not reachable in Tarkov; keep it closed.
- Map-local coordinates in all code (MapKit's convention: `H.V(x, y, z)` adds O).

## Modules (Rojo: a folder with init.luau is one ModuleScript with children)

| File | Owner | What |
|---|---|---|
| `src/server/Maps/Meridian/init.luau` | foundation | entry `return function(kit, root)`: map model "Meridian", runs the parts in order under pcall, sets `W.bounds`, prints a summary, returns the model (copy the pattern of `Maps/Border/init.luau`) |
| `src/server/Maps/Meridian/Layout.luau` | foundation (generated) | the reference converted to studs with our names: boundary, minefield and sniper bands, relief, roads, car parks, railway, fences, outdoor buildings, the mall outline per level, every store with its id, kind, footprint and our name, corridors, atria, escalators and stairs, service corridors, docks, the garage zones, extracts, spawns, scav zones, boss zones, keys |
| `src/server/Maps/Meridian/Ground.luau` | foundation | terrain (relief, the west minefield band, banks), roads, the ring road and ramps, surface car parks with markings, the railway and siding, fences and boundary walls, power lines, the kart track |
| `src/server/Maps/Meridian/Outside.luau` | foundation | every outdoor structure: THE SUBSTATION (power station main building with the switch room, its compound), the WEST CAMP huts, the RESCUE CAMP tents and containers, RESCUE CHECKPOINT, booths and huts, the two sign pylons |
| `src/server/Maps/Meridian/Mall.luau` | mall shell | the mall's outer walls and entrances, the L0 car park (columns, ramps, zones A to D and the three anchor garages, the SHELTER room, UNIT 14), the L1 and L2 slabs with the atria voids, the roof with domes and skylights, columns, corridors and galleries (floor finishes, balustrades), escalators, stairs, service corridors, loading docks, washrooms; the store grid as empty fitted units with shopfronts (glass, roller grilles, doors) so the stores agents only fill them |
| `src/server/Maps/Meridian/Stores.luau` (+ `StoresL1.luau`, `StoresL2.luau` if it grows) | stores | every store's interior: the three anchors, the 30-odd L1 units, the L2 units and food court, stock rooms; Blender kit props, containers, loose loot, doors, locked rooms with their keys |
| `src/server/Maps/Meridian/Play.luau` | gameplay | extracts with their rules, spawns by side, AI routes, posts, scav zones, THE CARETAKER (Killa) and his zones, the power switch and what power changes, the IRONSIGHT alarm, visit zones, the minefield and sniper bands, airdrops if the system supports them, outdoor loot |
| `src/server/Maps/Meridian/Dress.luau` | gameplay | outdoor and car park clutter: parked and burnt cars, trolleys, barriers, cones, bins, sand bags; nature at the edges |
| `tools/interchange_layout.py` | foundation | JSON -> Layout.luau (run with `python3 -I`) |

- World: `moduleMap("meridian", "Meridian")`. `src/server/Maps/MeridianMall.luau` becomes a short stub (the laptop's
  copy cannot be deleted from a cloud session); it is no longer built. Map id stays `meridian`.
- `src/shared/Maps.luau`: Meridian Mall raid time 2400 s (Interchange is 40 minutes); a new description.
- The old module is the best example of a mall: `src/server/Maps/MeridianMall.luau` (its Blender mall kit, generator
  power, the Caretaker, keys, shopfronts, escalators). Border Yard's modules are the best example of the split above and
  of every API (kit.model, MapKit, Kit.place, TerrainKit, kit.extract, kit.loose, kit.container, doors, W.spawns,
  W.sideExtracts, W.patrols, W.watchPosts, W.scavZones, W.visitZones, W.boss, W.switches, hazards and snipers,
  `kit.stationary` for mounted guns).

## Our names (the layout is Interchange's, the names are ours)

| Interchange | Meridian |
|---|---|
| ULTRA (the mall) | MERIDIAN |
| IDEA (furniture and homeware anchor) + IDEA Bistro | NESTA + NESTA CANTEEN |
| Goshan (hypermarket anchor) | KASSA |
| OLI (hardware and car parts anchor), OLI logistics, OLI administration | BOLTWORKS, BOLTWORKS GOODS-IN, BOLTWORKS OFFICE |
| KIBA Arms (gun shop) | IRONSIGHT |
| Techlight (electronics) | VOLTA |
| ULTRA Medical / Apteka medical storage | MEDIQ and the MEDIQ STORE ROOM |
| EMERCOM store | RESCUE POINT |
| Power Station | THE SUBSTATION |
| Emercom camp, Emercom Checkpoint | RESCUE CAMP, RESCUE CHECKPOINT |
| Scav camp (west huts) | WEST CAMP |
| Saferoom | THE SHELTER |
| Object-14 container room | UNIT 14 |
| Go-kart track | KART TRACK |
| Underground parking zones A to D, IDEA/Goshan/OLI garages | CAR PARK A to D, NESTA / KASSA / BOLTWORKS GARAGE |
| Killa | THE CARETAKER (existing boss) |

Every other store gets an original name from the stores agents (short, fitting its kind, no real brand, nothing that
reads like Tarkov's name for that unit); they list them in `docs/maps/MERIDIAN_MALL.md` next to the reference's id.

Extract names: RAIL SIDING (Railway Exfil), RESCUE CHECKPOINT (Emercom Checkpoint), SUBSTATION CAR (Power Station
V-Ex, paid), SHELTER EXIT (Saferoom Exfil: power on, then a hidden switch in a washroom), WEST CAMP (Scav Camp co-op),
RIVER PATH (the flare exit), FENCE GAP (Hole in the Fence: backpack slot empty). Conditions and sides follow the
reference (section 6) with the existing extract kinds (open, paid, key, chance, scav, switch); add a `nobag` kind for
FENCE GAP if it is small. Co-op extracts, flares and transits do not exist here yet: WEST CAMP and RIVER PATH become
plain extracts with the gap logged, as on Border Yard.

Keys (new items `KEY_MM_*`, existing ones reused where they fit): IRONSIGHT front door and back grate (two keys, as KIBA),
RESCUE POINT store, the MEDIQ store room (reuse `KEY_MEDIQ`), the VOLTA store room (reuse `KEY_VOLTA_STORE`), the three
anchors' cash register keys (NESTA, KASSA, BOLTWORKS), BOLTWORKS OFFICE and GOODS-IN, the SUBSTATION utility room, and
two keycards for the hidden panel and UNIT 14 (reuse `CARD_MALL_VAULT` for one, a new card for the other). Old mall
keys that no longer open anything here (`KEY_MALL_SECURITY`, `KEY_MALL_STAFF`) get a door on the new map or are
retired with their loot weight removed; say which in the doc.

## Budgets (owner: full detail at full performance, 30 FPS on low-end phones)

The mall is very large (about 141,000 m2 a level). StreamingEnabled is on and streams by distance, not by walls, so
part density near the player is what costs. Border Yard's centre already streams 18,600 parts (KNOWN_ISSUES 65).

- Built once at server start. Whole map under **24,000 parts** (shell under 7,000, stores under 11,000, outside and
  dressing under 6,000), Blender kit props under **1,800** (instanced meshes are cheap; prefer them to part-built
  furniture), at most **400 lights**, at most **40 with shadows**, terrain water none (or a ditch).
- Big plain surfaces as few large parts (a corridor floor is one slab per bay, not tiles). Shelving rows from kit props.
- Walls are real wall parts (Block, CanCollide, thin <= 2.6) and floors slabs, so the detail layer finds them.
- Power off at raid start: emergency lamps only; the switch brings the mall's lights up in part (as Tarkov).

## Phases

1. **Foundation**: `interchange_layout.py`, Layout, init, Ground, Outside, World and Maps wiring, the old module stubbed.
   The map builds with empty mall bounds marked (a flat pad and the outline) so later phases can start.
2. **Mall shell** (after 1).
3. **Stores** (after 2; one or two agents by level) and **gameplay** (after 2, in parallel).
4. Main session: Studio build, tests, raid with AI, screenshots, fixes, docs (`MERIDIAN_MALL.md` rewritten).

## Rules for every agent

- Work only in `/home/claude/EscapeFromBloxov`. No tools starting with `mcp__remote-devices__`, no Studio, Blender or
  browser: the main session runs Studio and tests your code.
- Match the code style around you (compact data tables, plain comments). `python3 tools/luau_check.py src` must pass.
  There is no Luau runtime here: write carefully, keep functions small, nil-check everything that can be missing.
- Touch only your own files (table above) plus anything your brief names. Other agents work in the same tree at the
  same time: never use `git add -A`, `git commit -a`, `git stash` or `git checkout` of files you did not write. Commit
  only your files by explicit path, with the message your brief gives and these two lines at the end:

      Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
      Claude-Session: https://claude.ai/code/session_01518mnhhAQemNYvSZZj7jTR

  If git says index.lock exists, wait 20 s and try again.
