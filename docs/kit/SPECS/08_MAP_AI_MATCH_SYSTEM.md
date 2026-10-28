# Quay 7 level, AI, and raid orchestration

## Greybox geometry
One connected small map (~400x400 studs initial), industrial waterfront, 3 routes and 3 loops, 2 spawn groups, 2 extraction zones. Avoid a single corridor death funnel; every loot POI has at least 2 entry/exit options. Unique landmarks must be legible in low-resolution on a phone: a yellow gantry, striped water tower, tall pump chimney. Test cover dimensions from actual FPS camera height.

## Spawn / extraction fairness
Spawns line-of-sight shielded for first moments; no immediate opponent spawn view; exits are opposite-side and identifiable through radios/signage, not map-copy color blobs. Randomize one or two player-eligible exits per raid, but preserve server guarantee each player has a valid exit. Raid timer 6–8 minutes for M1, expand 10–12 after loop is fun.

## Dynamic world
Ambient audio and optional gentle weather/lighting variance only once baseline stable. No uncontrolled real-time time-of-day lighting; if weather reduces visibility, don't make it impossible for touch/mobile to compete. Avoid paywall for map knowledge.

## AI states and optimization
Guard 01 patrols waypoint ring. Alert by hearing close gunshot or seeing player within max visible range and unobstructed LOS. If alert, aim and shoot with limited accuracy, stop and seek cover after damage (M2). AI logic uses perception updates at 3–6Hz and server path recomputation only on meaningful target/path changes, not every render step. Server raycasts cover. Despawn distant AI only when safe/uncorrelated with players.

## Match flow
M1 local same-server lobby with per-player active raid state. Avoid joining the middle of a different player's running raid unless server can isolate states. For two-client test, share a single raid space and respawn at side-specific positions. Persistence across raid load/unload must be deterministic.

## Later server segmentation
Roblox TeleportService can create reserved servers via `TeleportOptions.ShouldReserveServer`. Matchmaking uses MemoryStoreService ephemeral queue; durable profiles remain in DataStore. Teleport not a guaranteed Studio test substitute. Design for failure/retry and idempotent arrival; DO NOT implement until stable M1 and approved stage 14. Client-supplied teleport data is untrusted.
