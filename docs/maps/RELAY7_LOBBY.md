# Relay 7: the lobby bunker

The safehouse is a physical lobby: a worn cold-war relay bunker where every Tarkov screen has a station, and every
screen is meant to still open from its key. Today only the inventory (Tab), settings (P) and, in a raid, the time and
exits (O) have keys (`InputMap.luau`); traders, flea market, messenger, handbook, hideout, deploy and the gunsmith bench
open at their stations (`Interact.luau`). Tarkov's menu bar (audit ui-6a, approved 2026-11-07) will open them from
anywhere; it is not built yet. The owner approved the design on 2026-10-29 (the claude.ai doc "Zero Return Lobby:
Research and Concept"): a bunker setting, trader NPCs, hideout modules in the bunker with each player's own levels,
deploy by van with your squad, free range ammo, and one bunker shared by everyone on the server (up to 12).

## The plan

140 x 104 studs (45 x 33 m), floor at y 0, centred on `Config.SAFEHOUSE_ORIGIN` (0, -300, 4000), far from every map,
so no map streams in while you are here. Plan coordinates: x east 0..140, z south 0..104.

| Room | Plan (x, z) | Stations |
|---|---|---|
| Bunk room | 0-40, 0-36 | Six double bunks (12 beds; you spawn at yours), 12 lockers with callsign cards (stash), the mirror |
| Ops room | 40-92, 0-36 | Map table with four map sheets (deploy screen, votes), split-flap departure board, roster whiteboard (squad), cork task board (tasks), insurance window |
| Traders' hall | 92-140, 0-36 | VOS, HALE and TILDA at their counters on the north wall, DEKKER's counter across from them (NPCs), the Fence by the back door, 12 mail pigeonholes |
| Corridor | 0-140, 36-44 | Blast doors into ops, the hall and the hideout; signs over every door |
| Hideout wing | 0-52, 44-76 | Generator, workbench, medstation, water collector, storage racks; spare bays painted out |
| Gunsmith | 52-92, 44-76 | Bench with your gun in the vise (modding), two gun racks, KOVAC's counter on the south side |
| Firing range | 0-92, 76-104 + tunnel | Four booths, paper at 5 m, steel at 10 and 25 m, 50 m down the tunnel on lane 4 |
| Motor pool | 92-140, 44-104 | The van (deploy), ramp up to a roller door, scav hatch with its cooldown sign, ROOK's counter east of the vehicle opening and BRAM's west of it |

## How it is built

- `src/server/Maps/Relay7.luau`: the layout tables (rooms, walls with doors, bunks, traders, hideout bays, lanes and
  targets), the shell, the grime spots and the stations: invisible boxes carrying the prompts. A prompt sits on an
  attachment on the side you use the station from and needs a line of sight, so no prompt reaches through a wall.
- The shell is kept, not ruined (owner, 2026-11-01): walls are painted plaster with the paint in the wall blocks
  themselves (olive to 4.5 studs, a dark line, light plaster above), the floor and ceilings plain concrete, and no
  worn MaterialVariants (`Wear = ""`). The detail plan reads the shell with the "clean" profile: a soft strip of grime
  along the foot of each wall and now and then a hairline crack. `Relay7.grime` places about 200 `DetailSpot`s where
  dirt really gathers: every inside corner, every doorway (hand marks, scuffs, a worn threshold), the generator (oil,
  soot), the water collector (damp), the benches, the storage racks, the counters, the map table, the bunk aisle,
  the corridor, the range backstop (old hits), the tunnel (damp, a drip) and the motor pool (oil, tyre marks).
- `src/server/Maps/Relay7Dress.luau`: the Blender kit on the plan, about 290 props (budget under 300), signs, floor
  paint, a little wear, and the lights: six that cast shadows (one per main room, each just under its own fitting, and
  fittings never cast shadows) and soft fill lights that POTATO turns off. Surfaces are plain (no speckled
  MaterialVariants); the wear is baked chips on the props, a little lived-in litter (no rubble) and the decals above.
- Blender kit: `assets/blender_scripts/build_bunker_kit_a.py` (structure and fittings), `_b.py` (furnishings and
  stations), `_c.py` (motor pool); batches `ZR_BunkerKitA/B/C`, 70 props, 4 to 2900 triangles each.
- `src/server/Services/Lobby.luau`: the shared screens, written once a second: departure board (one character per flap,
  4 rows of 24: the shared raid, PMC entry, who is inside, scav entry; or matching and the vote), roster (everyone on
  the server, squad colour, bunker / queued / in raid), the four map sheets (votes, the live raid), callsign cards, the
  van's dashboard, and the van leaving (fx `van`). Also the trader NPCs: block-body rigs in their own clothes and kit
  (looks `vos`, `hale`, `tilda`, `dekker`, `kovac`, `rook`, `bram`, `fence` in `Equipment.LOOKS`; each stands behind his counter in `Relay7.TRADERS`) who turn to the nearest customer and now and then do
  something with their hands.
- `src/server/Services/Range.luau`: range shots. A shot counts only from inside a booth, aimed downrange, at the gun's
  fire rate; the ray only meets the targets and the range itself, so nobody can be hurt. Steel falls and stands up again,
  paper keeps the holes (clients animate both), and the booth display shows hits, the group on the paper and the time.
- `src/client/Controllers/Lobby.luau`: your side: the mirror (a slow orbit round you), your gun in the vise and your
  stash guns in the racks (from their Blender parts), your pigeonhole lamp, your hideout (the wing's lights run off your
  generator, racks fill with your storage level, a finished craft waits on the bench, "YOUR ... · LV n" labels), your
  tasks pinned on the cork board, flickering tubes, the range booths (practice mode), the van and the scav hatch.
- `src/client/Controllers/Weapon.luau`: practice mode. In a booth your gun comes up with a full practice magazine,
  reloads refill it, and shots go to the Range service instead of combat.

## A trip before a raid

Spawn at your bed; open your stash at your locker; trade at the counters (the NPC turns to you); fit parts at the
gunsmith bench (the gun in the vise is your current build); try it on the range next door; pick the map at the ops
table; insure at the window; walk to the van. Boarding queues you like the Ready button: you stand in the cargo box,
the dashboard counts down, and stepping out cancels. At departure the doors slam for everyone in the bunker, the
bodycam switches from STBY to REC, the screen fades and you are in the raid. With a raid running and PMC entry open
you go straight in. Scavs use the hatch: its sign shows your cooldown.

## Performance

Indicative only (Studio on the T490, client and server in one process, Studio's maximum render quality, the laptop
slow that day): the bunker 20 fps with 212 draw calls and 53k triangles in view, against Quay 7 at 12 fps, 572 draw
calls and 107k triangles at the same moment. Turning all bunker lights off or hiding all kit props changed the frame
rate by under 2 fps, so the bunker is not the bottleneck. Phones are not measured.

## Not done yet

- Other players do not see your gun in your hands at the range (only the shots and impacts).
- No lobby sounds yet: generator hum, radio chatter, pipes, the van's engine (a synthesized lobby atlas is planned).
- Squad members board the van one by one (the squad still deploys together).
- The fourth map sheet is Border Yard, shown as not in rotation until the map is built.
- The mirror's glass is a flat sheen (Roblox has no real reflections).
