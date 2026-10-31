# Border Yard (customs-type map)

The fourth map in the rotation, built 2026-10-31. Researched against Tarkov's Customs (the Escape from Tarkov wiki):
a large industrial customs zone with a checkpoint, dorms held by a boss and his guards, fuel stations, warehouses,
a construction site with a boiler house, a trailer park, a river with a smugglers' boat, rail lines out, a paid car
extract at the dorms and a key-only extract. Border Yard is an original layout of the same kind of place
(exception 1 in `docs/design/EFT_PARITY.md`: no Battlestate layouts or names).

## Layout

600 x 340 studs (about 190 x 110 m), origin (0, 0, -2000), raid 35 minutes, terrain from a height function
(`src/server/Maps/BorderYard.luau`, TerrainKit): flat yards, asphalt roads, the river along the north with banks,
berms closing the view. Local coordinates: x east, z south.

| Area | Where | What |
|---|---|---|
| Checkpoint | west, on the highway | Canopy, glass booth with a gun locker, barriers, a truck queue, the two-storey customs office (offices, the RECORDS room behind KEY_BY_RECORDS with the seizure safe, an open-plan upper floor) |
| Dorms | north centre | Block A (three storeys) and block B (two) round a courtyard; rooms off a corridor; ROOM 314 behind KEY_BY_314 (safe, rifle case); the Broker and three guards; the DORMS CAR paid extract |
| Bridge | north, x 48 | The bridge road over the river: BRIDGE ROAD extract |
| Fuel stop | south of the highway | Canopy, pump islands, the shop (till, fridge, shelves) |
| Tank farm | south centre | Four tanks, a pipe rack, the pump house (watchman's case), fenced |
| Warehouses | east | Warehouse 3 and warehouse 9 (pallet racks, a seized-weapons cage), the crane yard (container stacks, a gantry) |
| Trailer lot | south-east | Five cabins in the pines: TRAILER LOT extract |
| Building site | south-west | A two-storey concrete frame, rebar, the boiler house with two chimneys: BOILER CELLAR extract (KEY_BY_BOILER) |
| Rail | south | The line with boxcars and the tunnel portal: RAIL TUNNEL extract |
| River | north-east | Jetty and boat: SMUGGLERS' BOAT extract (55 % of raids) |

Extracts by spawn side (Tarkov gives each side its own set): west CROSSROADS, TRAILER LOT, RAIL TUNNEL, DORMS CAR,
SMUGGLERS' BOAT; east BRIDGE ROAD, BOILER CELLAR, DORMS CAR, SMUGGLERS' BOAT; south BRIDGE ROAD, CROSSROADS,
DORMS CAR, SMUGGLERS' BOAT. Scavs also have the CHECKPOINT.

## Not done yet

- Blender pictures for the three new keys (they show the generic key picture).
- Stationary weapons, border snipers and propane cylinders (Customs has them).
- The Broker's own loadout and look (he uses the default boss kit).
