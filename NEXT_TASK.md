# Next Task

**Current focus:** improvement program milestone **M8 — AI 2.0** (owner: NPC scavengers, guards and bosses alongside real players, Tarkov rules).

## M8 plan

1. **Factions and friend-foe rules.** AI scavs (friendly to player scavs unless provoked), guards/raiders (hostile to everyone), boss + followers. Player scavs who shoot scavs become hostile for the raid. PMCs are hostile to all AI.
2. **Spawning.** Scav waves over the raid (timed, near POIs, never in view of a player), guards at fixed posts, a boss with 2–3 followers at a compound (chance per raid). Cap total AI by player count.
3. **Perception.** Vision cone with light/stance/distance and foliage-free LOS, hearing (footsteps by surface and speed, gunshots by loudness/suppressor), memory of the last known position, flashlight visibility.
4. **Behaviour.** Patrol routes, investigate, take cover (cover point search), peek and suppress, push or hold, retreat to heal, search after losing contact; boss followers protect the boss.
5. **Combat model.** Weapons and ammo from the real item defs (AI loadouts through Loot), recoil/spread by distance and stance, real reloads with mag counts, server-side shots through the same Combat path as players.
6. **Animation.** AI use the shared rig + RigMath poses (aim pitch, crouch, lean around cover), footstep sounds through the atlas.
7. **Loot.** AI bodies carry their real loadout (scav kits, guard kits, boss items).
8. Logic tests for faction rules and loadouts; Studio test with screenshots; docs; commit.

Then M9 (economy: traders, barter, loyalty, quests, XP/skills, hideout, keys, fence karma, dog tags, run-through), M10 (world/art/audio), M11 (QA: two-client test, devices, performance, docs).

## Resume steps

1. Read `DEVELOPMENT_STATUS.md` and `KNOWN_ISSUES.md`.
2. Start `rojo serve --port 34873` in `Documents\EscapeFromBloxov`; connect the Rojo plugin in Place3.
3. Play, then run `ZR_Dev:Invoke("tests")` (baseline **105/105**).
