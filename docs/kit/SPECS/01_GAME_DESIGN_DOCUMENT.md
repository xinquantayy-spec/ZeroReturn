# Game design document v1 — ZERO RETURN

## The fantasy
A scavenger operative enters an abandoned coastal industrial exclusion zone to recover components, encrypted records and valuable equipment while rival operatives and autonomous security patrols search the same place. Leave through an extraction before a closing timer, or lose the gear taken in. The player keeps useful loot, improves a persistent stash and prepares for a riskier run.

## Reference translation (NOT asset copying)
| Escape from Tarkov | Our game mechanic | Simplification for Roblox/mobile |
|---|---|---|
| Scavenging in timed session raids | 8–12 minute Quay 7 raids; solo or 2–4 squad | Small connected map; 4 players in early prototype; scale after profiling |
| Stash + loadout risk | Persistent storage with equipment choice | Clear equipment screen, three explicit inventory containers |
| Lose-on-death extraction loop | Gear locked at insertion; failure consumes risked loadout | No hidden fees; beginner recovery kit |
| Loot containers and gear value | Searchable crates, drawers, lockers | Server rolled item IDs, 1–2 interactions, phone-friendly |
| Uneasy PvPvE | Slow-paced sightlines, AI patrols, rival players | No extreme realism; fair audio and visual feedback |
| Traders/quests | Fictional mechanics: supply dealer, field tech, archivist | First contracts: recover 2 transponders, survive 2 raids |
| Detailed health/armor/ballistics | Hits, stamina, armor durability, simplified wounds | M1 single health value, M3 injuries |
| Heavy weapon modding | 3 original equipment families, optic / magazine / stock slots | No real-world licensed models/trademarks |

## Core design pillars
1. **Risk has weight:** every raid has clear potential gains and painful but fair losses.
2. **Intuitive realism:** tactile, deliberate actions, not intricate simulator micromanagement.
3. **Original low-fi verisimilitude:** weathered industrial forms, excellent silhouettes and audio; not generic Roblox.
4. **Readability wins:** bodycam atmosphere must never sabotage mobile aiming, navigation or UI clarity.
5. **Fair multiplayer:** secure item records, server combat validation, no pay-to-win.

## Exact M1 vertical slice
- One private safehouse with 2 equip slots, `Stash` screen and 24 starter cells; starter gear always recoverable if player reaches zero inventory.
- One playable `Quay 7` greybox (~400x400 studs), 3 POIs: stacked-container alley, pump station, loading warehouse. At least 2 spawn locations and 2 extraction points placed to avoid direct spawn-to-extract shortest path.
- Up to 2 test clients in one server, extend to 4 only once stability proven. Each raid lasts 6–8 minutes for tests.
- One generic, stylized rifle (`R-17` fictional), a magazine, 30 rounds, primary fire, ADS, reload, sprint/crouch, one healing item. One AI security guard with patrol, investigate sound, alert, shoot and disengage behaviors (even if minimal).
- Six loot items and three searchable containers; loot is movable to bag; slots and weight constraints (M1 can defer rotation and use 1x1 / 1x2).
- At least one eligible extraction per player. Standing in zone triggers visible 6-second countdown; leaving cancels it; reaching zero means death/MIA and lose raid items.
- Post raid summary with extracted/lost, loot value, kills, time, changes to persistent stash. Rejoin loads previous confirmed stash without duplication.
- One original 3D environment prop and one FPS gun/viewmodel created in Blender and actually imported to Studio; not only Part placeholders at M1 completion.
- M1 must work on mouse and keyboard, touch, gamepad through action adapter and navigable inventory. Can be unpolished until M2, but not unsupported.

## Typical loop (player journey)
1. Main menu opens into diegetic safehouse. `DEPLOY` table. Quick tutorial introduces movement and one loot container.
2. Select equipment and insert into raid (preview risked value). `READY` commits server-side reservation.
3. Spawn with randomized route and known possible extracts. Player moves carefully and hears distant patrols.
4. Interact with drawers: 1-second search, server produces inventory, player chooses objects.
5. Audible firefight or enemy engagement: posture, recoil, hit feedback; no bright XP popups.
6. Exit via radio beacon; hold position for 6 seconds. Extract if alive and allowed.
7. Post-raid `RETAINED` / `LOST` report; confirmed items into stash, optional sale to dealer.
8. Choose next loadout or accept basic recovery kit.

## Phase 2/3 feature gates
- 3 original weapons with different handling; wearable armor, helmets, consumables and condition.
- 20–35 loot items across 5 rarity tiers with function (sell, craft, barter, quest).
- 3 AI archetypes: watchman, scout, marksman; tuning and nav profiles.
- Additional raid sector only after main map works; optional dynamic extraction schedules, locked rooms, per-map keycards.
- NPC supply dealers, 10 contracts, hideout upgrades, item crafting, optional insurance-like return system (not in M1).
- Optional matchmaking/multiple places using TeleportService + MemoryStore only after stable in-place sessions and transactional consistency are proved.
- No auction/flea market or live P2P trading at launch: huge dupe/abuse surface, expensive to maintain.

## No-go
No replica Tarkov maps, scav names, patch/logo, trader names, exact bodycam overlay screenshot, screenshots copied into textures, militarized police signage, torture or gore. Avoid default Roblox character appearance in raids, generic free asset packs, 'rebirth' purchases, click-to-earn simulator loops, 1000-part VFX, scripted jumpscares, forced purchases.

## Quantitative gates (hypotheses to playtest, not promises)
- Start to first movement within 15–30s on baseline phone (measure).
- New player reaches first searchable crate within 60–90s.
- First full raid can be won in under 8 min; average engaged session 10–15 min.
- First re-equip should take <60s after learning UI.
- A loss should feel attributable to player/AI actions, never lag or missing UI.
