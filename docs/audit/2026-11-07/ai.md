# Audit: NPCs and their AI (area "ai")

Scope: scavs, raiders, rogues, guards, bosses and followers, cultists, snipers and PMC bots; behaviour, perception,
accuracy, spawns, bosses against EFT's on the matching map, loadouts, looks and animation, and the cost on a Roblox
server. Nothing in the repo was changed.

Terms used below:
- **stud**: Roblox's unit. The maps use 3.125 studs per metre (`docs/maps/BORDER_CUSTOMS_BUILD.md:14`).
- **AI cap**: the most AI alive at once (`Config.AI_MAX`).
- **sleep**: a bot far from every player stops thinking and moving until someone comes near (EFT does this).
- **aim ramp-up**: a bot's aim starts loose and tightens over the first moments of a fight.
- **hit affection**: a bot's aim is thrown off for a moment when it is hit.
- **Warn**: EFT's state where a boss or raider warns a player scav before shooting.
- **PvE**: EFT's mode against AI only, with AI-controlled PMCs.
- **SPT data**: the game's bot and map data as shipped by the SPT project (a community copy of EFT's server data). It
  may lag the live game, so 1.0-era patch notes are quoted next to it. Battlestate does not document these values;
  what each one means is read from its name (for example `FAR_DIST` as a hearing distance in metres).

## Current state

**What exists.** One AI service (`src/server/Services/AI.luau`, 2,357 lines) runs every NPC. Units are full operator
rigs that use the players' ballistics, armour, health, inventory and animation (`AI.luau:10-11`, `shoot` at
`AI.luau:788-917`). Four kinds share one state machine (patrol or wander, investigate, engage, search, flee):

| Kind | Skill (sight, reaction, aim error) | Faction | Who |
|---|---|---|---|
| scav | 125 studs (40 m), 0.8-1.5 s, 3.6° + 0.032°/stud | scav | AI scavs |
| watch | 165 studs (53 m), 0.55-0.95 s, 2.2° | watch | "Harbor Watch" raider-type guards on every map |
| follower | 165 studs, 0.5-0.9 s, 1.9°, 1.2x health | scav | boss guards, crews |
| boss | 170 studs (54 m), 0.45-0.8 s, 1.6°, 1.6x health | scav | every boss (own health, kit, look per map) |

Source: `AI.luau:54-62`. Boss variety comes from options on the same "boss" kind: a melee charge (hammer or knife),
a prone ambush, karma hunting, silent steps, tripwires (`AI.luau:1242-1385`, `2285-2311`).

**Roster per map** (from the map play data):

| Map (EFT match) | Fixed guards | Bosses | Scavs |
|---|---|---|---|
| Quay 7 (original) | 3 Watch, +1 depot patrol when no boss (`World.luau:1716-1726`, `AI.luau:2314-2316`) | THE FOREMAN + 2 crew, 50 % | 4 at start, +0.5 per raider, cap 10 |
| Smelter (factory-type, own layout) | 4 Watch (`Smelter.luau:727`) | none (`Smelter.luau:734`) | same |
| Border Yard (Customs) | 6 Watch + 2 Bastion gunners (`Border/Play.luau:645-652, 677`) | THE BROKER (Reshala) + 4 guards at the global 50 %; THE HOUNDS (Goons) 20 %; THE CULT, night, 20 %; THE FORESTER (Partisan) 20 % + karma (`Border/Play.luau:692-773`) | same |
| Meridian Mall (Interchange) | 6 Watch (`Meridian/Play.luau:968-977`) | THE CARETAKER (Killa) 60 %; THE STOKER (Tagilla) 35 % (`Meridian/Play.luau:1002-1021`) | same |
| Pinewatch (woods-type, parked) | 6 "Ranger" Watch | THE SAWYER + 2 crew | same |

**Behaviour that works:** awareness-based sight (distance, stance, movement, weapon light), foliage and smoke block
sight, glass does not (`AI.luau:378-449`); footsteps and gunshots heard (`AI.luau:1663-1668`, `2011-2036`);
suppression from near misses (`2039-2071`); silent information call-outs to nearby allies (`472-494`); cover points
sampled from the map (8,474 to 10,139 on Border Yard, `TEST_RESULTS.md:998, 1011`) with peek-and-hide (`321-375`,
`1459-1508`); crouch at range and strafe in the open; suppressive fire at the last seen spot; reloads from real
magazines; healing with real meds (`Health.aiUse`); flushing with frags or stuns, smoke for a retreat, running from
grenades, blinded by stuns (`1011-1196`, `2089-2133`); fleeing when out of ammo; doors opened on the way (`566-578`);
posted guards man the mounted guns (`1733-1746`); lights and lasers at night (`1766-1782`).

**Spawns:** watch posts, then each boss rolled on its own, then 4 scavs (`AI.reset`, `AI.luau:2219-2324`). A director
tops scavs up for the first 5.5 minutes and sends waves of 2-3 every 4 minutes while more than 5 minutes remain
(`1984-2007`). Every AI counts against one cap of 18 (`Config.luau:20-25`, `AI.luau:1823-1825`). Player scavs use the
PMC insertion points and may enter until 6 minutes are left (`Match.luau:279-296, 341-349`, `Raid.luau:383-387`).

**Cost (measured in Studio only):** 10 AI fighting: scripts 0.44 ms, physics 3.3 ms a frame (`TEST_RESULTS.md:1208`).
Border Yard with about 18 AI: scripts 0.7 ms, physics 8.3 ms with 761 moving parts (`TEST_RESULTS.md:1014`). Each unit
thinks 5 times a second and looks 5 times a second when alert, 2.5 when calm, wherever it is
(`AI.luau:1695-1701, 1899-1908`); paths are
recomputed at most every 2.5 s or when the goal moves 4 studs (`543-556`). Clients animate rigs at full rate within
80 studs, half to 160, a quarter to 300, and freeze them beyond (`Animator.luau:317`). Not measured: a live server,
phones (`KNOWN_ISSUES.md:16`, item 4).

**Completeness.** The foundation is strong and most EFT combat behaviours exist. It was tuned for the small first
maps (Quay 7 is about 120 m across), so on the real-scale Customs and Interchange layouts the senses are too short, the
cap is too small and the roster is not EFT's. Voice, looting, scav groups, marksmen and PvE AI PMCs are missing.

**Key files:** `src/server/Services/AI.luau`, `Loot.luau` (AI kits, `996-1449`), `Health.luau` (`aiUse`, scaling),
`Combat.luau` (`84-111`, hits into `AI.onDamaged`), `Hazards.luau` (border snipers, mines), `Match.luau`,
`Raid.luau`, `src/server/Maps/Border/Play.luau`, `Meridian/Play.luau`, `Smelter.luau`, `World.luau` (Quay 7),
`src/client/Controllers/Animator.luau`, `docs/design/BOSS_*.md`. `Guard.luau` is the players' movement anti-cheat,
not NPC code.

## Strengths

- **One rule set for players and AI.** AI bullets fly with drop, go through glass and armour, and hit the same body
  parts; AI bodies drop their whole kit (`AI.luau:848-891`, `2195`). This is EFT's model.
- **No wall-hacks.** Sight is ray-cast to the head and torso; bushes, smoke and darkness hide you; weapon lights give
  you away (`AI.luau:378-449, 1632-1636`). EFT 0.16.2 made bots unable to see through vegetation unless very close, as
  ours do ([Insider Gaming](https://insider-gaming.com/escape-from-tarkov-ai-upgrade-patch/)).
- **Real tactics.** Generated cover with peeking, suppression, grenade throws planned by simulating the throw
  (`AI.luau:1021-1049`), evasion of landed grenades, healing and reloading behind cover.
- **Bosses with EFT numbers where it counts.** THE STOKER 1,220, THE HOUNDS 1,120/910/795, the priest 850, THE
  FORESTER 950, as in EFT's data (SPT); the hammer charge, the cult ambush and poison, karma hunting, silent steps and
  tripwires are built and seen in Studio (`TEST_RESULTS.md` sections for each boss).
- **Cheap scripts.** Under 1 ms of script time a frame for about 18 AI (`TEST_RESULTS.md:1014`).
- **Client animation LOD** already exists (`Animator.luau:317`).
- **Logic tests** cover factions, kits and boss data (`LogicTests.luau:810-840, 1189-1254, 2427-2433`).

## Findings

Ranked by severity, then impact.

1. **P1 · The AI cap starves the maps and can silently drop bosses.** Guards and bosses count against the one cap of
   18, and guards spawn first. On Border Yard, 8 Watch + the Broker's group (5) leave room for at most 5 scavs; with
   THE HOUNDS, 2; a night raid with the Broker and THE CULT leaves 0-2, and a rolled THE FORESTER can be refused without
   a log. Waves cannot add scavs either. EFT caps only scavs (Customs 19, Interchange 30)
   and bosses ignore the cap (`IgnoreMaxBots`). Evidence: `AI.luau:1823-1825, 2263-2321`; `Config.luau:20-23`;
   `Border/Play.luau:645-652, 677`; `TEST_RESULTS.md:1011` (6 + 5 + 4 + 3 = 18 before the 2 gunners were added); SPT
   `locations/bigmap/base.json` and `interchange/base.json`.
2. **P1 · Raider-grade guards on maps where EFT has none.** Border Yard has 8 Watch (2 on the Bastion's guns) and
   Meridian 6. EFT's Customs and Interchange spawn no raiders (no `pmcBot` in either map's boss list; SPT data). The
   Watch shoot player scavs on sight (`AI.luau:137-145`), so a player scav is fired on at our Bastion, which is EFT's
   scav base. The Watch came from the 2026-10-28 programme, before the "copy EFT" rule; the departure is not logged in
   `EFT_PARITY.md`. Evidence: `Border/Play.luau:645-652, 670-678`; `Meridian/Play.luau:966-977`.
3. **P1 · AI sight is a third of EFT's on real-scale maps.** Scavs see 40 m, guards 53 m, bosses 54 m, over a 124°
   cone (`AI.luau:54-59, 69, 1633-1639`); at night 15-20 m. EFT's data: scavs 120 m over 130°, marksmen 137 m,
   bosses 137-142 m, Big Pipe 170 m, Birdeye 250 m, rogues 222 m; notice time 0.1 s close, 1 s at 90 m, 3 s at 160 m
   (SPT bot data). On the 1 km Border Yard a player can shoot AI from well outside their vision.
4. **P1 · No voice lines or audible call-outs.** No voice sound exists in any atlas; `callout()` shares positions
   silently (`AI.luau:472-494`). EFT scavs "say voice lines in russian, seemingly at random, very often"
   ([wiki](https://escapefromtarkov.fandom.com/wiki/Scavs)), bots talk on patrol (`TALK_WITH_QUERY`, talk delays in SPT
   data), call out, and bosses warn player scavs. Voice is how EFT players find AI and tell them from players.
   `KNOWN_ISSUES.md:34` (item 15) lists it.
5. **P1 · The Broker and THE CARETAKER do not match Reshala and Killa.** The Broker has no look, kit or chance of his
   own (`Border/Play.luau:692`), so he wears the Foreman's hard hat and padded jacket over class 5 armour, carries the
   Foreman's KS-7 rifle, rolls at the global 50 %, always at the dorms, and drops Quay 7's office key, ledger and brass
   lion (`AI.luau:1794-1796`, `Loot.luau:1051-1083`). EFT's Reshala: no armour, a golden TT, hides behind four guards,
   752 health, three zones, 39-57 % ([tarkovforge](https://tarkovforge.com/bosses/reshala), SPT). THE CARETAKER fights
   with a pump shotgun in the generic bodyguard look with 704 health (`Meridian/Play.luau:1002-1005`,
   `Loot.luau:1087-1122`, `AI.luau:58`). EFT's Killa: an RPK-16 with a 95-round drum, class 5 armour, a helmet with face
   shield, 890 health, five double pockets, "relentlessly suppresses", strafes and pushes, hostile to player scavs
   ([wiki](https://escapefromtarkov.fandom.com/wiki/Killa), [timesaver 2026](https://timesaver.gg/blog/tarkov-killa-boss-guide)).
6. **P2 · Hearing is short.** Footsteps carry 8 m walking and 16 m sprinting for scavs (`AI.luau:1665`); gunfire
   alerts within 54-77 m by kind and sends AI to look only within 30-42 m (`2012, 2021`). EFT bots hear simple sounds at 10-30 m
   (`CLOSE_DIST`, `FAR_DIST`, SPT); their gunfire radius is longer (exact figure unverified).
7. **P2 · Aim fairness has holes.** Being hit adds only 1.3° for 1.2 s (`AI.luau:830-832, 2141`); EFT's data gives a
   scav a hit affection of 1.17 s and 19-32° (`BASE_HIT_AFFECTION_*`, SPT), bosses 0.27-0.57 s. A target that reappears within 3.5-7 s gets no new reaction
   delay or aim penalty, because both are only set on entering a fight (`1702-1713`) and awareness stays full for about
   2 s (`1655-1661`); EFT 1.0 lengthened repeated detection and stopped head aim after 15 s unseen
   ([PCGamesN](https://www.pcgamesn.com/escape-from-tarkov/patch-notes-enemy-aim)). Every scav has the same skill;
   EFT rolls easy, normal and hard bots (10/50/40 on Customs and Interchange, SPT).
8. **P2 · AI never loot.** No looting code exists (`KNOWN_ISSUES.md:34`). EFT scavs loot bodies since 0.12.7
   ([Gfinity](https://www.gfinityesports.com/article/escape-from-tarkov-scav-abilities-patch-0-12-7-update)), what they
   take is lost to insurance since 0.13.5 ([NME](https://www.nme.com/news/escape-from-tarkov-patch-makes-it-even-harder-to-get-lost-gear-back-3481157)),
   and 1.0.2 fixed bots re-equipping looted weapons ([MP1st](https://mp1st.com/title-updates-and-patches/escape-from-tarkov-update-1-0-2-servers-go-down-maintenance-february-10)).
9. **P2 · Scavs are loners and nobody flanks.** Each scav spawns alone at its own spot, waves included
   (`AI.luau:1953-1960, 2000-2004`). EFT: half of spawns are groups of 2-3 (`NonWaveGroupScenario`, SPT), "groups of 3"
   on patrol (wiki), groups push when they have the upper hand (Gfinity). `AI.luau:7` says followers flank; no flanking
   code exists.
10. **P2 · Faction rules differ per boss.** Every boss and follower is scav-faction and ignores player scavs until
    provoked (`AI.luau:62, 137-145`). EFT's data: Killa, cultists, Big Pipe and Birdeye are always hostile to player
    scavs; Reshala, his guards, Tagilla, Knight, Partisan and raiders warn first and shoot a quarter of the time
    (`DEFAULT_SAVAGE_BEHAVIOUR`, `CHANCE_SHOOT_WHEN_WARN_PLAYER_100` 25, SPT). There is no Warn state.
11. **P2 · Health numbers off EFT's.** Cult warriors 440 (`Border/Play.luau:736`) against 850; THE CARETAKER 704
    against 890; the Broker's guards 528 against 630 (`AI.luau:57-58`); all spread evenly over the body (logged per
    boss). EFT values from SPT bot data.
12. **P2 · Player scavs enter like PMCs.** They use PMC insertion points and can enter from the first second
    (`Match.luau:279-311, 341-349`; `Config.luau:13`). EFT moved player scavs to no earlier than 17 minutes in, on all
    maps but Reserve, Factory and Ground Zero ([Insider Gaming](https://insider-gaming.com/escape-from-tarkov-scavs-upgraded/),
    2025; not re-checked for 1.x, unverified).
13. **P2 · No marksman (sniper) scavs.** Customs has four sniper perches; no AI kind fills them
    (`docs/maps/BORDER_YARD.md:543`). EFT's data has marksman waves on Customs, and 1.0.2 fixed sniper scavs on Customs
    (SPT; MP1st).
14. **P2 · No sleep for far AI.** Every unit thinks and runs physics wherever it is (`AI.luau:1899-1908`). Physics is
    the main server cost (8.3 ms a frame for about 18 AI, `TEST_RESULTS.md:1014`). EFT's data puts bots to sleep beyond
    300 m from every player and wakes them at 265 m (`DistToSleep`, `DistToActivate`, SPT). This blocks EFT's AI
    counts.
15. **P2 · No PvE mode or AI PMCs.** EFT has PvE with six AI PMC groups on Customs and on Interchange, each at 50 %
    (SPT); 1.2.0.0 reworked them
    ([patched.gg](https://patched.gg/games/escape-from-tarkov/patch-1200)) and 1.3.0.0 added harder ones
    ([GameLeap](https://www.gameleap.com/articles/escape-from-tarkov-1-3-0-0-patch-notes-all-changes)). Nothing exists here.
16. **P2 · AI vision ignores local light.** Sight follows only the raid clock and weather (`Env.luau:119-126`), so AI
    see into the dark mall or a cellar as in daylight; an aware AI also sees all round within 14 m (`AI.luau:1639`).
    EFT's data has light-specific vision values (`VISIBLE_DISNACE_WITH_LIGHT`, `ENEMY_LIGHT_ADD`); whether EFT reads
    local light levels is unverified.
17. **P2 · AI rigs stream in part by part (Roblox).** AI models keep the default streaming mode (`AI.luau:1856`), and
    Roblox streams default models part by part ([Roblox docs](https://create.roblox.com/docs/workspace/streaming)). At
    the streaming edge, and on low-memory phones where the radius shrinks, a client can see half a rig or none while it
    shoots. Not tested.
18. **P2 · The AI's parity gaps are not logged.** `docs/design/EFT_PARITY.md` has no AI section (its sections are
    items, inventory, screens, controls, settings, visuals and maps); project rule 2 asks for it. `KNOWN_ISSUES.md:34`
    is stale (it says no grenades or doors; both exist), and `AI.luau:7` claims flanking.
19. **P3 · Broker guards stack.** Slots 2-4 share one offset beside the leader (`AI.luau:950`; logged in
    `BORDER_YARD.md:544`).
20. **P3 · Orphaned followers walk the wrong loop.** When a leader dies, followers take `W.boss`'s route
    (`AI.luau:945-948`), so THE HOUNDS' survivors walk the Broker's dorm loop.
21. **P3 · Far rigs freeze even through a scope.** Animation stops beyond 300 studs (96 m) whatever the zoom
    (`Animator.luau:317`); with EFT ranges this shows.
22. **P3 · AI learn the exact shooter position** from a near miss or a hit (`AI.luau:2060, 2167`); EFT spreads heard
    positions (`DISPERSION_COEF`, SPT).
23. **P3 · AI do not hear doors, reloads or looting.** `Doors.luau` never calls `AI.hearShot`; EFT bots hear simple
    sounds 65 % of the time (`CHANCE_TO_HEAR_SIMPLE_SOUND_0_1`, SPT).
24. **P3 · Border sniper shots always come from one fixed side (-Z) of the player** (`Hazards.luau:224`), whichever edge
    the band is on; on Meridian's east band they come along the band.
25. **P3 · No boss on Smelter.** EFT's Factory has Tagilla (30 %) and night cultists (8 %) (SPT;
    `docs/design/BOSS_CULT.md`). Matters once Smelter copies Factory.
26. **P3 · Movement and animation limits.** AI never lean (they step sideways), never go prone outside the cult
    ambush, cannot jump or vault (`AI.luau:532`); the hammer swing uses the knife gesture with the gun pose (logged in
    `BOSS_STOKER.md`).

## Gaps vs EFT

| EFT feature | Ours | Gap |
|---|---|---|
| Scavs with several health presets (wiki; SPT data has three) | Scavs at 440 | Close |
| Sniper (marksman) scavs on Customs | None | Missing |
| Raiders only on Reserve and Labs | Watch guards on all five maps | Departure on Customs and Interchange |
| Rogues (Lighthouse; Knight's escorts in SPT data) | None | No matching map yet |
| Reshala + 4 guards, 3 zones, no armour, golden pistol | THE BROKER in the Foreman's kit, dorms only, global 50 % | Partial |
| Goons: Knight, Big Pipe (launcher), Birdeye (marksman, 250 m sight) | THE HOUNDS with stand-in guns, shared boss skill | Partial (`BOSS_HOUNDS.md`) |
| Cultists: priest and warriors at 850, always hostile to player scavs | THE CULT; warriors 440; ignore player scavs | Partial |
| Partisan: karma, tripwires, quiet | THE FORESTER | Close (`BOSS_FORESTER.md`) |
| Killa: LMG, suppress and push, 890 | THE CARETAKER: shotgun, 704 | Partial |
| Tagilla: hammer, semi-auto 12 g | THE STOKER: hammer, pump | Close (`BOSS_STOKER.md`) |
| Tagilla and cultists on Factory | Smelter has no boss | Missing once Smelter copies Factory |
| Glukhar, Sanitar, Shturman, Kaban, Kollontay, Zryachiy, Black Division (2026, Icebreaker and Terminal) | None | No matching map |
| Scav cap per map (Customs 19, Interchange 30); bosses outside it | One cap of 18 for all | Too low; bosses refused |
| Scav groups of 2-3 (50 %) | Singles | Missing |
| Timed waves and spawn windows | Waves of 2-3 every 4 min | Close |
| Bots sleep beyond 300 m | Never | Missing |
| Bots leave the raid after 20-30 min | Never | Missing (minor) |
| Vision 120-250 m, 120-180°, notice 0.1-3 s by distance | 40-54 m, 124°, awareness build-up | Large |
| Rain and fog cut vision | Weather and clock multiplier | Close |
| No seeing through vegetation (0.16.2) | Blocked beyond 2 m | Exact |
| Flashlights give you away | Weapon light raises range and exposure | Close |
| Hearing 10-30 m | Footsteps 8-16 m; gunfire 54-77 m | Short |
| Memory 52 s (Knight 104 s) | About 20-25 s | Short |
| Aim ramp-up over 1.5 s; hit affection; difficulty mix | 3° penalty over 2.5 s; tiny hit penalty; one skill per kind | Partial |
| 1.0: slower repeated detection; no head aim after 15 s unseen | Instant re-acquire; head share every burst | Missing |
| Cover, peeking, suppression, healing, grenades, doors | Built | Close |
| Leaning, prone, vaulting | Not built | Missing (minor) |
| Flanking and group pushes | Not built (claimed in a comment) | Missing |
| Looting bodies and loose loot; insurance loss | Not built | Missing |
| Voice lines, call-outs, boss voices, Warn | Not built | Missing |
| Shooting dead bodies (52 %), looking at bodies | Not built | Missing (minor) |
| Mounted guns used by bots | Posted guards | Close |
| Player scavs from 17 min, scav spawn points | From the start, PMC spawns | Missing |
| PvE mode with AI PMCs (teaming, neutral chance, POIs, gear by level) | None | Missing |
| Per-part boss health | Even spread | Logged per boss |

## Decisions

### ai-1 · Who populates the two Tarkov-layout maps?
Should Border Yard and Meridian Mall keep the raider-grade Harbor Watch, or carry EFT's own roster? EFT's Customs and
Interchange have scavs (and marksmen on Customs), bosses and their guards, no raiders. Our 14 Watch there are
raider-grade, shoot player scavs, and use the AI cap scavs need.

| Option | What | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. EFT roster | Remove the Watch from Border Yard and Meridian. Their posts and routes become scav posts (scav skill and faction), the Bastion gunners become scavs, and marksman scavs take Customs' four perches. The Watch stays on Quay 7 and Smelter. | M | none | exact |
| b. Scav-aligned Watch | Keep them everywhere, but scav-faction with scav skill (safe for player scavs). | S | none | close |
| c. Keep | As now. | S | none | departure |

**Recommended: a.** It is EFT's roster, frees about a third of the AI budget for scavs, and stops player scavs being
shot at the scav base.

### ai-2 · How many AI per raid, and how do we pay for them?
EFT caps scavs per map (Customs 19, Interchange 30), keeps bosses outside the cap and puts far bots to sleep. Ours: one
cap of 18 for everything and no sleep. In Studio, about 18 AI cost 0.7 ms of scripts but 8.3 ms of physics a frame.

| Option | What | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. Bosses outside the cap | Keep 18 for scavs and guards; bosses and crews never count. | S | low | partial |
| b. EFT caps with sleep | Per-map caps from EFT's data plus bosses outside them; AI more than about 940 studs (300 m) from every player sleep (root anchored, no thinking); unused humanoid states off; proven by a live-server test at 20, 30 and 45 AI first. | M | med | exact |
| c. Scale with players | Cap = 8 + 1.5 per raider, up to EFT's cap, with sleep. | M | low | close |

**Recommended: b.** It gives EFT's density on real-scale maps, and sleep is EFT's own way to keep the cost down.

### ai-3 · Should the AI's senses and aim use EFT's numbers?
Ours were tuned by feel for small maps (sight 40-54 m, footsteps 8-16 m, memory about 25 s, one skill per kind, almost
no hit penalty). EFT's data gives each bot type its own sight, cone, hearing, memory, aim ramp-up, hit affection and an
easy/normal/hard mix; 1.0 slowed detection.

| Option | What | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. Port EFT's numbers | Per role (scav, marksman, each boss and guard, PMC bot) from the game data in studs, with notice time by distance, the 1.0 detection changes, rain and fog factors and a per-spawn difficulty roll. | M | low | close |
| b. Scale and patch | Keep our model; triple sight and hearing on the big maps; add hit affection, a re-acquire delay and a difficulty roll. | S | low | partial |
| c. Keep ours | As now. | S | none | departure |

**Recommended: a.** The maps are real scale now; only EFT's numbers start fights at EFT's ranges and feel EFT-fair.

### ai-4 · How should the AI get voice lines?
EFT bots chatter, call out grenades and reloads, warn player scavs, and bosses have their own voices. Ours are silent.
Limits: about 10 audio uploads a month on this account (lines can be packed into atlases, `KNOWN_ISSUES.md` item 6),
Roblox audio moderation, and the original-IP rule (no EFT voices). Roblox has a built-in text-to-speech voice
(`AudioTextToSpeech`: 11 languages, 300 characters, rate-limited;
[docs](https://create.roblox.com/docs/reference/engine/classes/AudioTextToSpeech)).

| Option | What | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. Recorded packs | Original scripts recorded by actors or the owner: three scav voices and one per boss, about 40 lines each, packed into atlases. Costs money (owner approval). | M | low | close |
| b. Roblox text-to-speech | Lines generated in game with its voices, pitch and speed; free within the rate limit; sounds synthetic. | S | low | partial |
| c. Wordless cues | Radio clicks, whistles, grunts from our synth pipeline. | S | none | departure |

**Recommended: a.** Voice is how EFT players read and find AI; synthetic or wordless cues lose that. Use b as
placeholders if there is no budget yet.

### ai-5 · Boss-only weapons: build them or keep stand-ins?
Killa's light machine gun, Big Pipe's grenade launcher, Birdeye's 7.62x51 marksman rifle, Tagilla's semi-auto
12-gauge and Reshala's golden pistol have stand-ins today. Each new gun needs Blender parts, first- and third-person
models, stats and a picture (the M14 pipeline), uploaded from the owner's machine.

| Option | What | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. All five | Original designs of all five. | L | low | close |
| b. The two that change the fight | The LMG (THE CARETAKER) and the launcher (MORTAR); stand-ins for the rest. | M | low | partial |
| c. Tuned stand-ins | No new guns: an R-17 with a drum and long bursts for THE CARETAKER, rapid frag throws for MORTAR. | S | none | partial |

**Recommended: b.** Those two weapons decide how those fights play; the other three are close to their stand-ins.

### ai-6 · Should Zero Return get EFT's PvE mode with AI PMCs?
EFT's PvE mode has AI PMC groups that roam, fight scavs, bosses and each other; 1.2.0.0 (October 2026) made them team
up more, sometimes stay neutral, head for points of interest and scale gear with level. A Roblox PvE raid could run on
a reserved server per squad.

| Option | What | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. Not now | PvP raids only. | S | none | departure |
| b. EFT-style PvE servers | Separate PvE raids (solo or squad) on reserved servers, with AI PMC groups of two factions that loot, fight and extract, and EFT's separate PvE progression. | L | med | exact |
| c. Bot backfill in PvP | AI PMCs fill empty raider slots in PvP raids. | M | med | departure |

**Recommended: b.** It is EFT's mode and suits solo Roblox players; build it after ai-2 and ai-3, which it reuses.

### ai-7 · When and where should player scavs enter?
EFT: no earlier than 17 minutes into the raid on most maps (not Factory, Reserve or Ground Zero), at scav spawn points.
Ours: from the first second, at PMC insertion points, until 6 minutes are left. With one shared raid per server, a
later window means a scav who queues early waits.

| Option | What | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. EFT window | Scav entry opens 17 minutes in on Border Yard and Meridian (from the start on Smelter, a Factory-type map), at scav spawn points away from raiders. Early queuers wait. | S | none | exact |
| b. EFT window, cross-server | As a, but a queuing scav is sent to a server whose raid is inside the window (MemoryStore matchmaking and teleport). | L | none | exact |
| c. Spawn points only | Keep entry from the start; use scav spawn points. | S | none | partial |

**Recommended: a.** EFT's rule stops scavs racing PMCs to the loot; on the 40-minute maps the window is still
17 minutes long.

### ai-8 · Should AI loot like EFT's bots?
EFT bots loot bodies and loose loot; what they take is lost to insurance unless their own body is looted. Ours never
loot, so insured kit always comes back unless a raider extracted it.

| Option | What | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. EFT rules | Scavs (and PMC bots) walk to bodies and loose loot, take better or valuable items, swap guns; taken items are lost to insurance. | M | low | exact |
| b. Loot, softened | As a, but insurance still returns items an AI took. | M | low | close |
| c. No looting | As now. | S | none | departure |

**Recommended: a.** It is EFT's risk model and makes bodies and dropped kit feel contested.

## Quick wins

No decision needed; each is about a day or less.

1. Bosses and their crews ignore the AI cap (EFT's `IgnoreMaxBots`); log any refused spawn; add a LogicTest that the
   full Border Yard roster spawns (`AI.luau:1823-1825`).
2. EFT health: cult warriors 850, THE CARETAKER 890, the Broker 752, his guards 630 (`Border/Play.luau:736`,
   `AI.luau:57-58`).
3. The Broker: his own chance, EFT's three zones (dorms, fuel stop, Bastion), his own loot without Quay 7's office
   key, ledger and brass lion, and a look without armour or the hard hat (`Border/Play.luau:692`, `Loot.luau:1072-1080`).
4. Hostility from EFT's data: THE CARETAKER, THE CULT, MORTAR and KESTREL shoot player scavs; the rest keep ignoring
   them until a Warn state arrives with voice lines (`AI.luau:62, 137-145`).
5. THE CARETAKER gets Killa's five double pockets (`k.doublePockets()` already exists, `Loot.luau:965-967`).
6. Spread the four Broker guards round him (`AI.luau:950`).
7. Orphaned followers keep their own group's route (`AI.luau:945-948`).
8. Half of scav spawns come as groups of 2-3 through the existing leader and follower code (`AI.luau:1953-1960`).
9. Scale the animator's distance by the camera zoom so scoped AI keep moving (`Animator.luau:317`).
10. Set AI models to `ModelStreamingMode.Atomic` (`AI.luau:1856`), then check a far AI on a low-memory phone.
11. Turn off unused humanoid states on AI (climbing, swimming, seated, flying), measuring physics before and after
    (`Chars.luau:424-432`; [DevForum](https://devforum.roblox.com/t/how-to-optimize-humanoids/389801)).
12. Opening and closing doors make a quiet noise the AI hear (`Doors.luau`).
13. When hit or near-missed, the AI learns a rough position a few metres off, not the exact one (`AI.luau:2060, 2167`).
14. Border snipers fire from the band's outer side (`Hazards.luau:224`).
15. Smelter, our Factory-type map: roll THE STOKER at 30 % and THE CULT at 8 % at night, as EFT's Factory does.
16. Docs: refresh `KNOWN_ISSUES.md` item 15, drop "flank" from `AI.luau:7` and the stale Tagilla comment at
    `Meridian/Play.luau:981`, and add an AI section to `EFT_PARITY.md` with the table above.

## Sources

EFT game data (SPT's copy, downloaded 2026-11-07 and read as data only):
- Bot types: [assault](https://github.com/sp-tarkov/server-csharp/blob/main/Libraries/SPTarkov.Server.Assets/SPT_Data/database/bots/types/assault.json),
  marksman, pmcbot, exusec, bear, usec, bossbully, followerbully, bosskilla, bosstagilla, bossknight, followerbigpipe,
  followerbirdeye, sectantpriest, sectantwarrior, bosspartisan (same folder:
  https://github.com/sp-tarkov/server-csharp/tree/main/Libraries/SPTarkov.Server.Assets/SPT_Data/database/bots/types).
  Used: `VisibleDistance`, `VisibleAngle`, `Look`, `Hearing`, `Mind`, `Aiming`, `Scattering`, health.
- Maps: [Customs (bigmap)](https://github.com/sp-tarkov/server-csharp/blob/main/Libraries/SPTarkov.Server.Assets/SPT_Data/database/locations/bigmap/base.json),
  [Interchange](https://github.com/sp-tarkov/server-csharp/blob/main/Libraries/SPTarkov.Server.Assets/SPT_Data/database/locations/interchange/base.json),
  [Factory](https://github.com/sp-tarkov/server-csharp/blob/main/Libraries/SPTarkov.Server.Assets/SPT_Data/database/locations/factory4_day/base.json).
  Used: `BotMax`, `MaxBotPerZone`, difficulty mix, `NonWaveGroupScenario`, boss rolls and `IgnoreMaxBots`, waves,
  `DistToSleep`, `DistToActivate`, exfil times, hostility settings.

Patch notes and guides:
- 1.0 AI detection changes: [PCGamesN](https://www.pcgamesn.com/escape-from-tarkov/patch-notes-enemy-aim),
  [Express Tribune](https://tribune.com.pk/story/2577596/escape-from-tarkov-patch-reduces-ai-accuracy-and-detection-speed-following-player-frustration).
- 0.16.2.0 AI changes: [Insider Gaming](https://insider-gaming.com/escape-from-tarkov-ai-upgrade-patch/).
- 1.0.2 (looting, fog, sniper scavs): [MP1st](https://mp1st.com/title-updates-and-patches/escape-from-tarkov-update-1-0-2-servers-go-down-maintenance-february-10).
- 1.1.0.0: [patched.gg](https://patched.gg/games/escape-from-tarkov/patch-1100).
- 1.2.0.0 PMC bot rework: [patched.gg](https://patched.gg/games/escape-from-tarkov/patch-1200),
  [timesaver](https://timesaver.gg/blog/tarkov-pve-ai-overhaul-money-runs),
  [iXBT](https://ixbt.games/en/news/2026/10/06/440585-v-escape-from-tarkov-peredelali-cvk-botov-i-dobavili-prestiz-v-pve-vyslo-obnovlenie-1200.amp.html).
- 1.3.0.0: [GameLeap](https://www.gameleap.com/articles/escape-from-tarkov-1-3-0-0-patch-notes-all-changes).
- Scav looting: [Gfinity (0.12.7)](https://www.gfinityesports.com/article/escape-from-tarkov-scav-abilities-patch-0-12-7-update),
  [NME (0.13.5)](https://www.nme.com/news/escape-from-tarkov-patch-makes-it-even-harder-to-get-lost-gear-back-3481157).
- Player scav timing: [Insider Gaming](https://insider-gaming.com/escape-from-tarkov-scavs-upgraded/),
  [OpenCritic / Game Rant](https://opencritic.com/news/13743/escape-from-tarkov-makes-changes-to-scavs).
- Scavs, Killa: [EFT wiki: Scavs](https://escapefromtarkov.fandom.com/wiki/Scavs),
  [EFT wiki: Killa](https://escapefromtarkov.fandom.com/wiki/Killa),
  [timesaver: Killa (2026)](https://timesaver.gg/blog/tarkov-killa-boss-guide),
  [tarkovforge: Killa](https://tarkovforge.com/bosses/killa), [tarkovforge: Reshala](https://tarkovforge.com/bosses/reshala).
- New 2026 AI faction: [timesaver: Black Division](https://timesaver.gg/blog/tarkov-black-division-guide).
- The boss docs' own sources: `docs/design/BOSS_STOKER.md`, `BOSS_HOUNDS.md`, `BOSS_CULT.md`, `BOSS_FORESTER.md`;
  map references `docs/maps/reference/CUSTOMS_REFERENCE.md` (section 10) and `INTERCHANGE_REFERENCE.md` (section 7).

Roblox:
- [Streaming and model streaming modes](https://create.roblox.com/docs/workspace/streaming).
- [AudioTextToSpeech](https://create.roblox.com/docs/reference/engine/classes/AudioTextToSpeech).
- [DevForum: How to optimize Humanoids](https://devforum.roblox.com/t/how-to-optimize-humanoids/389801) (community advice).

Unverified: EFT's gunfire hearing radius; whether EFT bots read local light levels; whether the 17-minute player scav
rule still holds in 1.x; boss chances move with live data (Reshala and Killa show 57 % on tarkovforge today, 39 % and
49 % in SPT, about 45 % for Killa in timesaver's 2026 guide).
