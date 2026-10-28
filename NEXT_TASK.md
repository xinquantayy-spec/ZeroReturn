# Next Task

**Current focus:** improvement program milestone **M7 — Multiplayer raids** (owner: real players fight each other, co-op squads, Tarkov rules).

## M7 plan

1. **Raid lifecycle on one server (up to 12 players).** Shared raid instance with a start window: players deploy into the running raid until a cut-off, then a new raid cycles once everyone is out; Tarkov-length raid timer (Config.RAID_DURATION ~25 min) with MIA on expiry.
2. **Spawns.** Spread spawn points per raid, never near another player; each spawn has its own extract list.
3. **PvP.** Player bodies become lootable containers with the full kit (secure container excluded); kill credit and death screen (killer weapon/ammo/distance, body part); combat-log bodies when a player leaves mid-raid.
4. **Squads.** Invite/accept in the hideout, deploy together, shared spawn, squad HUD list (State.squad), friendly identification (armband attribute), no squad-mate kill credit.
5. **Player-scav mode.** Random scav kit, own cooldown, no gear risk, separate stash transfer on extract.
6. **Conditional extracts.** Paid (MK), key-locked, co-op (needs a scav), always-open; timer gates.
7. **Insurance.** Insure gear in the hideout; uncollected insured items return after a delay if not looted by others.
8. Two-client Studio test for PvP/loot races (Test → Clients and Servers), then commit.

Then M8 (AI 2.0), M9 (economy), M10 (world/art/audio), M11 (QA + docs).

## Resume steps

1. Read `DEVELOPMENT_STATUS.md` and `KNOWN_ISSUES.md`.
2. Start `rojo serve --port 34873` in `Documents\EscapeFromBloxov`; connect the Rojo plugin in Place3.
3. Play, then run `ZR_Dev:Invoke("tests")` (baseline **88/88**).
