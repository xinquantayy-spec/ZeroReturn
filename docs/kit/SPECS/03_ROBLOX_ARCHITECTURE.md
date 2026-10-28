# Roblox repo architecture & authority map

## Repository layout (target, adapt to existing connection after audit)
```text
ZeroReturn/
  default.project.json
  aftman.toml OR rokit.toml (only if installed)
  src/shared/
    Constants.lua, Types.lua, ItemDefinitions.lua, WeaponDefinitions.lua,
    RemoteNames.lua, InputActions.lua, InventoryGeometry.lua, RaidContracts.lua
  src/server/
    Main.server.lua
    Services/ProfileService.lua, InventoryService.lua, RaidService.lua,
    CombatService.lua, LootService.lua, ExtractionService.lua,
    AIService.lua, TraderService.lua, AntiAbuseService.lua
  src/client/
    Main.client.lua
    Controllers/CameraController.lua, InputController.lua,
    HudController.lua, InventoryController.lua, WeaponController.lua,
    AudioController.lua, InteractionController.lua
    UI/SafehouseView.lua, StashView.lua, RaidHud.lua, RaidSummary.lua
  assets/blender_sources/
  assets/exports/
  studio/manifest.json (Studio imported assets + IDs, updated after verification)
  tests/unit/, tests/studio/, docs/
```
Use typed Luau where practical. No expensive framework by default. Explicit startup order: definitions/remotes created on server; profile load -> raid services -> players; client waits for bounded initialization and handles failure gracefully. Avoid requiring modules that perform implicit side effects.

## Separation
- `ReplicatedStorage` only small shared definitions, remotes, UI templates and essential assets. Put maps, server-spawned loot and NPC templates in `ServerStorage` or streamed Workspace when appropriate.
- `ServerScriptService` authoritative services and state. `StarterPlayerScripts` client presentation/controls only. `StarterGui` can hold UI trees if map authoring split is maintained.
- Workspace: two areas `Safehouse` / `RaidQuay7` separated within a place in M1, with per-player logical zones. M2 multiple players in raid. In-place zoning is a prototyping compromise; private hub/raid servers require architecture refactor only after M1 success.
- `CollectionService` tags e.g. `LootContainer`, `ExtractionZone`, `AISpawn`, `Interactable`. `Attributes` for non-sensitive static metadata only, not durable inventory.

## Remote contracts
| Remote | Direction | Min checks |
|---|---|---|
| `RequestDeploy` | C->S | in safehouse, profile locked, selected items owned, not already in raid, revision matches |
| `RequestShoot` | C->S | sequence/replay, alive, weapon/round ownership, shot cadence, origin/direction plausibility, raycast |
| `RequestReload` | C->S | mag owned, valid weapon, ammo server-side, reload state |
| `RequestInteract` | C->S | tagged target, distance/LOS, alive, interaction cooldown, unique request ID |
| `RequestTransferItem` | C->S | GUID and source/destination authority, inventory geometry, not duplicate, action ID |
| `RequestExtract` | C->S (optional) | server zone and timer always controls success, request never grants loot directly |
| `RequestHeal` | C->S | heal item owned and unused, alive, timed cooldown |
| `RequestTrade` | C->S | safehouse, item owner, server price, atomic debit/credit |
| `StateSnapshot` / `StateDelta` | S->C | send only authorized player info, stable schema, delta version |
| `CosmeticShot` | S->nearby C | visual tracer/audio, non-authoritative, bounded frequency |

Rate limits per player+action: use token bucket or minimum intervals. Don't trust `Instance` references from clients as proof; resolve known identifier to server-side model and range-check it. Validate NaN/infinity and nested tables with strict max lengths. Reject unknown action/weapon/item IDs. Handle replay and double clicks. Every drop/loot/trader success has one server transaction.

## Data authority
- Server owns: raids, timers, loot seed, damage, health, weapon ammo, extraction, inventory, money, quests, XP.
- Client owns presentation: frame-specific camera bob, UI animations, local sound, buttons, preview selection, optimistic indicator. Not authoritative values.
- Shared definitions serve read-only lookups but are not privileged input. Never depend on `LocalScript` to enforce money/health constraints.

## Networking/replication
Send compact state deltas for local inventory and raid updates; avoid flooding `RemoteEvent` every render frame or replicating every bullet as a physics Part. Noncritical tracers/smoke can use `UnreliableRemoteEvent` if verified and tolerated on drop; all mutations via reliable events. Shot reconciliation optional later. Introduce capped queue for combat and loot requests and instrument rate-limited logs.

## Studio/Rojo source of truth
Map imported MeshParts/Roblox asset IDs are tracked in a manifest, with scripted assembly or a Studio package saved explicitly. Rojo sync handles Luau scripts. Claude must say how a fresh machine can rebuild the playable place from repo + imported assets, and must not pretend Rojo alone transports mesh binary uploads automatically.
