# Next Task

**Current focus:** improvement program milestone **M9 — Economy** (Tarkov progression with original names).

## M9 plan

1. **Traders.** 3–4 original traders (gear, weapons/ammo, medical, fence) with buy/sell lists, loyalty levels (spend + reputation), restock timers and limited stock; currency MK.
2. **Barter trades.** Items for items (e.g. gold chain + wires → plate carrier), shown with "have/need" counts.
3. **Quests.** Trader tasks: find-in-raid hand-ins, eliminate (scavs/PMCs/the Foreman), visit/mark locations, extract from a given exfil; rewards (MK, items, loyalty, unlocks).
4. **XP and skills.** XP from kills, extracts, looting, quests; run-through status (low XP + short raid = no FIR); a few skills (endurance, strength, health, vitality) that level with use.
5. **Hideout.** Upgradable modules (generator, medstation, workbench, lavatory) built with items/money; crafting with timers (ammo, meds, barters).
6. **Keys and locked rooms.** Locked doors (office, vault) opened with keys that have limited uses; locked loot behind them.
7. **Fence karma.** Scav karma from kills of AI scavs / player scavs; affects scav cooldown and fence prices; dog tags on PMC bodies.
8. Logic tests, Studio test, docs, commit.

Then M10 (world: POIs, boss compound, doors, loose loot, time of day/weather, Blender gear/weapon art, audio), M11 (QA: two-client test, devices, performance, docs).

## Resume steps

1. Read `DEVELOPMENT_STATUS.md` and `KNOWN_ISSUES.md`.
2. Start `rojo serve --port 34873` in `Documents\EscapeFromBloxov`; connect the Rojo plugin in Place3.
3. Play, then run `ZR_Dev:Invoke("tests")` (baseline **115/115**).
