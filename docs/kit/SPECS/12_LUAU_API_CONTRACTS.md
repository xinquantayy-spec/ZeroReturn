# Concrete implementation interfaces for Claude (adapt only after tool/API verification)

These are suggested interfaces, **not a code library already implemented**. Use consistent names to prevent cross-stage rewrite and avoid elaborate abstraction.

## Shared definitions (typed Luau)
```lua
--!strict
export type ItemDefinition = {
  id: string, name: string, kind: string,
  width: number, height: number, mass: number,
  stackMax: number, baseValue: number, assetKey: string,
}
export type ItemInstance = {
  guid: string, defId: string, count: number,
  durability: number?, ammo: number?,
}
export type RaidOutcome = "SUCCESS" | "KIA" | "MIA" | "DISCONNECTED"
export type RaidState = "SAFEHOUSE" | "LOADOUT_PENDING" | "COMMITTED" | "INSERTING" | "ACTIVE" | "EXTRACTING" | "FINALIZED"
export type WeaponState = {
  weaponGuid: string, roundsInMag: number,
  chambered: boolean, reloadingUntil: number,
  lastShotAt: number, shotSequence: number,
}
export type PlayerUiSnapshot = {
  raidId: string?, state: RaidState,
  health: number, stamina: number, ammo: number,
  raidTimeLeft: number, extractId: string?,
  revision: number,
}
```

## Services recommended callable shape
```text
ProfileService.Load(userId) -> Profile | error
ProfileService.Commit(userId, expectedRevision, mutator) -> newRevision | error
ProfileService.Release(userId) -> ()
InventoryService.Transfer(userId, requestId, guid, source, destination, targetCell) -> Result
InventoryService.VerifyInvariants(profile, raidState) -> Result
RaidService.Deploy(player, loadoutGuids, clientRevision) -> RaidId | error
RaidService.Transition(raidId, userId, expectedState, newState) -> Result
RaidService.Finalize(raidId, userId, outcome) -> SettlementReceipt | alreadyFinalized
LootService.Open(player, containerId, requestId) -> ItemList | error
LootService.Claim(player, containerId, guid, requestId) -> Result
CombatService.ProcessShot(player, sequence, originHint, direction, clientTime) -> ShotResult
ExtractionService.Begin(player, zoneId) -> serverOwnedCountdown | error
ExtractionService.Cancel(player, zoneId) -> ()
```

## Policy specifics
- `Result` contains `ok:boolean`, opaque `code` and a UI-safe message; no raw datastore internals exposed.
- `ProfileService.Commit` uses one logical mutation serialized per player. No two concurrent writes to the same key without queue and profile revision control.
- All data received from client is validated before invoking state services. Server only mutates state; controller never calls DataStore directly.
- `requestId` deduplication window (e.g. last 64 IDs per player/action) bounded in memory. Raid receipts are durable and bounded/compacted appropriately.
- `CombatService.ProcessShot` accepts aim vector but does not accept target, damage, fire rate or client ammo as facts.
- Client `StateSnapshot`/`StateDelta` should not expose other players' stash, quest inventory or secure item locations.

## Semantics of failure
- `BAD_INPUT`: reject and increment cheap abuse counter.
- `STALE_REVISION`: ask client to refresh inventory.
- `NOT_AUTHORIZED`: action impossible in current state.
- `TOO_FAR`, `OCCLUDED`, `BUSY`, `COOLDOWN`: contextual UI message.
- `STORE_UNAVAILABLE`: do not allow deploy with gear; show retry instead of temporary gift.
- `OUTCOME_UNKNOWN`: freeze settlement and recheck durable receipt; no duplicate grant.

## Server state mutation test
Simulate two requests in the same scheduler tick to transfer item GUID X to slots 1 and 2. Exactly one may commit. Assert after each commit that item X appears once and profile revision incremented once. Repeating requestId should be idempotent and return original receipt, not a second move.
