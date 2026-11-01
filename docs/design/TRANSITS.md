# Transits: from one map to another in the same raid

Status 2026-11-02: **built and checked in Studio with one player** (TEST_RESULTS "Transits").

## What Tarkov does

- **Since 0.15** a raider can move to another location mid-raid. They do not go back to the menu, and they keep their
  gear and their wounds.
- **Where:** each transit stands at a fixed spot on the map and leads to one other map. The ones that matter here:
  - **Customs to Interchange:** a cluster of parked vehicles next to the Trailer Park extract (SPT: 465, -190 m);
    Shacknews: "inside the bus near the small wooded area by the Trailer Park Worker's Shack".
  - **Interchange to Customs:** at the highway's south end, outside the mall at the OLI corner (SPT icon -193, 430 m;
    the playable ground ends at z 405 m).
  - Customs also has transits to Factory, Reserve and Shoreline; Interchange one to Streets.
- **When:**
  - SPT data: available 60 s into the raid, with a 20 s timer (both references).
  - Prima: the transits open after the first minute.
  - The 0.15 patch notes said 7 minutes.
- **How:**
  - Step into the transit zone and pick the option.
  - Once a transit is activated no other exit can be used.
  - A group can only transit when every living member is in the zone; strangers who transit together arrive together.
  - Items found in the raid can be sent to the stash for a price.
  - You lose stash access until the next hideout visit.
  - Scavs can transit too.
- **Sources:**
  - `docs/maps/reference/CUSTOMS_REFERENCE.md` and `INTERCHANGE_REFERENCE.md` (SPT `transits`, Prima, re3mr);
  - [CPG: 0.15 patch notes](https://consolepcgaming.com/escape-from-tarkov-0-15-patch-notes);
  - [Shacknews: Customs extracts and transits](https://www.shacknews.com/article/145072/customs-scav-extracts-escape-from-tarkov);
  - [Insider Gaming: map to map travel](https://insider-gaming.com/how-map-to-map-travel-works-in-escape-from-tarkov).

## Built (2026-11-02)

- **Two transits** (`Services/Transit.luau`; the points in `Maps/Border/Play.luau` and `Maps/Meridian/Play.luau`):
  - **TRANSIT TO MERIDIAN MALL** on Border Yard:
    - at (1420, -560), the edge of the trailer lot's wood, 46 studs north-west of the SPT point (which lies inside the wood);
    - two wrecks are parked beside it (`Dress.luau`).
  - **TRANSIT TO BORDER YARD** on Meridian Mall: at (-603, 1234), the highway's south end (395 m).
- **The zone and sign:**
  - a 16-stud zone with a faint blue mark on the ground;
  - a post with a blue lamp and the sign "TRANSIT · <MAP>" hanging beside it.
- **How it runs:**
  - The prompt at the sign (F, 1 s hold) starts a 20 s countdown, but only from 60 s into the raid.
  - During the countdown you must stay in the zone; stepping out cancels it. No other exit can be used meanwhile.
  - A squad goes only when every living member stands in the zone, and then all of them go.
  - At zero you arrive at the other map's transit, facing away from its sign, with your gear and wounds.
- **On the new map:**
  - Your exits are that map's: a PMC gets the list of the spawn nearest the arrival, a scav every exit a scav may use
    (not the car nor a PMC-only exit; on Meridian Mall that leaves the two corner exits and WEST CAMP).
  - The first raider to arrive on a map that is not in play rolls its chance exits and lets out six scavs there. They
    wander that map's scav zones (`AI.populate`, `u.zones`).
- **What follows you:**
  - The raid's tables keep the other map's exits under "map:id" (`Extract.key`), so flares and chance rolls work there
    too.
  - The raid info, the exits list and the bodycam's map name follow you.
- **HUD:**
  - Transits are listed after the exits on O, as "TRANSIT · OPEN" or "TRANSIT · OPENS A MINUTE IN".
  - The countdown uses the extraction's ("STAY IN THE TRANSIT ZONE").
  - On arrival the map's name comes up big.
- **Fixed on the way:** a raid info sent mid-raid (power switched on, a transit) no longer replays "INSERTION
  CONFIRMED" or clears a running extraction countdown.
- **Dev commands** (`DevExt/Transits.luau`): `transits`, `transitGo`, `transitStart`, `transitState`.

## Gaps (also in `EFT_PARITY.md`)

- **One raid clock:** the server runs one raid, so you arrive with the time it has left; Tarkov starts the new map's raid
  fresh.
- **The new map is quieter:** only six scavs, no bosses, no other players' spawns. Its car is not there, because the car
  stands only on the map in play.
- **No item transfer:** you cannot send found items to the stash for a fee.
- **Only Border Yard and Meridian Mall.** No transits to Factory, Reserve, Shoreline or Streets (no such maps), nor to
  or from Quay 7 or the Smelter.
- **No bus or vehicle cluster** at the Border transit beyond two wrecks, and no vehicle at Meridian's.
- **No detail layer on the new map:** the client's wall grime is published only for the map in play.
- **Not tested with two players** (the squad rule and strangers arriving together).
