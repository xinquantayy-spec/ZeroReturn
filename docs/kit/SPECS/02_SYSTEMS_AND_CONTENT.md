# Systems, data and balance contracts

## Raid state machine (server owned)
`SAFEHOUSE -> LOADOUT_PENDING -> COMMITTED -> INSERTING -> ACTIVE -> EXTRACTING -> SUCCESS | KIA | MIA | DISCONNECTED -> FINALIZED -> SAFEHOUSE`
Every transition has preconditions; finalized cannot be re-run. `DISCONNECTED` during active raid is a failure by default, with grace design considered only later (avoid exploit by quit). Dedicated `RaidId`, player `SessionId`, monotonically increasing `profileRevision`. Rewards are applied **only by server** on `FINALIZED` success.

## Items and item instances
Item definition `{id, name, kind, gridW, gridH, mass, maxStack, baseValue, rarity, effects, assetKey, tags}`. Instance `{instanceId(UUID), itemId, quantity, durability?, ammoCount?, modIds?, foundInRaid?, acquiredAt?}`. Definitions replicated read-only; instance IDs and persistence are server truth. Each instance must occupy exactly one location among stash, equipped, raid inventory, world container, trader (when sold), or destroyed.

Starter item definitions (invent original visual identifiers):
| id | Kind | grid | mass (fictional units) | value |
|---|---|---|---:|---:|
| R17_RIFLE | weapon | 2x4 | 3.0 | 240 |
| R17_MAG | magazine | 1x2 | 0.4 | 24 |
| UNIVERSAL_CARTRIDGE | ammo | 1x1 | 0.01/round | 1 |
| BANDAGE_PATCH | heal | 1x1 | 0.1 | 18 |
| SIGNAL_COIL | salvage | 1x1 | 0.5 | 38 |
| CERAMIC_FUSE | salvage | 1x1 | 0.2 | 28 |
| CRACKED_LENS | salvage | 1x1 | 0.4 | 52 |
| DECK_TRANSCEIVER | salvage | 2x2 | 1.8 | 150 |
| RUSTED_KEYCARD | key item | 1x1 | 0.1 | 90 |
| SEALED_DRIVE | quest | 1x1 | 0.1 | 120 |

M1 inventory can use grid slots with server-validated move/rotate. Phone alternative `Tap item -> Move to bag/stash, Equip, Drop, Inspect` rather than pixel-perfect drag. M2 adds sorting and modular containers. Item rotations at multiples of 90 degrees only; tests ensure no overlap/out-of-bounds.

## Loot design
Server uses configurable weighted loot pools per point and world seed. Do not accept player-reported loot contents or worth. Container lock first open only, with search duration and distance validation, item ownership/reservation to prevent simultaneous duplication; container change replicates to participants. Reward density: 3 common per raid region; 1 uncommon in hazardous route; rare items are identifiable but not flashing UI beacons.

## Combat contract
Client sends `{sequence, aimDirection, cameraOriginHint, clientTime, weaponInstanceId}`; never damage or hit entity as truth. Server verifies weapon ownership/current state/ammo/fire interval, finite numbers, timestamp drift, origin near character, aim plausibility, and raycasts collision; applies server-side damage. Client immediately plays muzzle flash/recoil/audio, reconciles server resolution for hits; no instant death by forged remote. Bullet penetration, ammo armor classes and real-time rewind optional advanced task, NOT M1.

Initial illustrative balancing: R17 12 damage/tick equivalent per landed round to 100 HP, 550 RPM, 25-round magazine, 2.2s reload, 14–18 deg mild recoil visualization, 40–70 stud reliable mid-range tuned in Studio. These values are placeholders for game feel, NOT real ballistics. Damage falloff optional; clamp and test.

## Health and stamina
M1: 100 health, 100 stamina, crouch/sprint/ADS, single patch restores 25 after 2.5s animation, interrupted on hit. Later: head/torso/limb health, armor plates, bleed, slower movement from injury, bandage vs medkit semantics. No medical realism simulation required; UI must plainly indicate status.

## Extraction logic
Player receives 1 mandatory and 1 optional extraction tied to spawn side; no extraction that starts inside opposing spawn. Extract requires alive, accessible, `ACTIVE`, physically inside server zone, hold 6 seconds, can cancel on exit or downed, cannot use double-finalization. Server clock authoritative. Camera/hud radio indicator at beacon. End of timer yields MIA; no retain for active raid bag or equipped items by default. Insurance optional later.

## Enemy AI
Simple FSM: PATROL -> IDLE/INVESTIGATE (sounds/sighted silhouette) -> ENGAGE -> SEARCH -> RETURN. Server authoritative perception and damage. Attack rate limited, never target through static walls. Break path requests into controlled intervals; PathfindingService, raycast line-of-sight and fallback waypoints. Use no expensive 60Hz path computation.

## Player progression
Start with 1000 soft currency, recovery rifle access in safehouse, 24 slot stash, 2 sell/buy trader actions. After early slice, 3 traders and contracts unlock crafting and stash expansions. No robux-to-skill, pay-to-win guns, permanent performance buffs or paid lootboxes. Cosmetic sales may be evaluated only after game is enjoyable and safe.

## Disconnection exploit policy
Current raid risk items are already removed/reserved from available stash at deploy commit. Quit must not duplicate them. On later reconnect, server resolves raid ledger as finalized failure if no verified successful extraction. Atomicity and idempotency specified in `06_PERSISTENCE.md`.
