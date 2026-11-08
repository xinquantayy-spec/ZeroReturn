# Test Results

Unless noted otherwise, every test ran in a Roblox Studio playtest with:

- one local client, player "wurdo0"
- an unpublished place, so the in-memory profile store was used
- the `ZR_Dev` and `ZR_ClientDev` bridges plus real mouse and keyboard input through Studio MCP

**NOT VERIFIED:** real DataStore, two or more clients, phone, tablet, console hardware, gamepad UI navigation, device emulator, and performance on devices (only indicative Studio frame rates on the T490 laptop, M12).

## Quick reload, stance stamina, overweight noise (decision gameplay-5b, part 1; 2026-11-08, about 13:55 SGT)

| Test | Result |
|---|---|
| Quick reload, Border Yard | With 19 rounds in the R-17 and two 25-round magazines in the rig, R twice 0.15 s apart: the gun held 25 again, and a "Dropped gear" pile lay 2.9 studs away with the old magazine, which had left the kit. (A first try failed: the magazines handed in for the test sat in the backpack, and Tarkov reloads only from the rig and pockets, so NO SPARE MAGAZINES was right.) |
| Overweight | The character's Overweight attribute read 0 with the normal kit, 1 after a 20 kg propane cylinder (over 26 kg), 2 after a second (over 46 kg), each within 2.5 s. |
| Not checked | The quick reload's shorter time measured on its own, a stance change's stamina cost read on screen, the louder rattle by ear, the gamepad and touch double taps. |

## Light blood (decision art-7a; 2026-11-08, about 13:35 SGT)

| Test | Result |
|---|---|
| Border Yard, watch room | Four body hits sent to the client, the rounds flying on toward the room's wall: four marks on the wall behind (0.36 to 0.61 studs) and one drop on the floor (screenshot). The marks were then made darker; that tint was not looked at again. |
| Not checked | Own shots hitting a scav (the same function, passed the shot's direction), phones, POTATO (no marks there by design). |

## Chat in raids (decision ui-7a; 2026-11-08, about 13:20 SGT)

| Test | Result |
|---|---|
| Automated suites | All 12 pass, 913 checks. LogicTests 423/423, new: the public channel only between two players in the bunker; the squad channel reaches the sender and the squad, nobody else. |
| One player, bunker then Border Yard | In the bunker the chat bar pointed at RBXGeneral. In the raid it pointed at ZR_Squad. A message sent there came back to the sender (alone, so his own squad). A message sent on the public channel in the raid reached nobody, the sender included. |
| Not checked | Two or more players (a squadmate receiving it, a bunker player not hearing a raider), bubble chat, phones. |

## Tarkov's menu bar (decision ui-6a; 2026-11-08, about 13:00 SGT)

| Test | Result |
|---|---|
| Automated suites | All 12 pass, 911 checks. UiTests 34/34 (new: the bar is M and a held View, the screens H, Y, U, K and J; a tap and a hold may share a button in menus). LogicTests: View is the eighth shared gamepad button (tap: settings, hold: the bar); screen keys need no gamepad way of their own (the bar is it). |
| The bar, in the bunker (keyboard and mouse) | M showed the bar: [H] HIDEOUT, [TAB] CHARACTER, [Y] TRADERS, [U] FLEA MARKET, [K] HANDBOOK, [J] MESSENGER (1), an X and DEPLOY; the mouse came free (screenshot). M again hid it and locked the mouse. |
| Screen to screen | Y opened the traders with the bar under the screen and TRADERS lit. Tab went on to the character screen, H to the hideout, K to the handbook, J to the messenger (its unread count cleared), each with its button lit (screenshots). J again closed the messenger, hid the bar and locked the mouse. Clicking DEPLOY on the bar opened the deployment screen (screenshot). Every screen kept clear of the bar. |
| Not checked | The gamepad (hold View) and touch (menu button) by hand, a phone's layout, prompts staying off while the bar is open by itself. |

## Sound through walls on Border Yard (decision gameplay-3a; 2026-11-08, about 12:40 SGT)

| Test | Result |
|---|---|
| Automated suites | All 12 pass, 910 checks (no new checks: the audio runs on the client). |
| Roblox's simulation, a test rig 900 studs up | A rain loop 30 studs from a listener with an AudioAnalyzer. A 40 x 40, 2-stud concrete wall between them took 24.5 dB off. With that wall's AudioCanCollide off, the level matched the open air again. A 0.5-stud wooden wall and a 6 x 6 concrete wall each took 0.1 dB off (thin wood; sound round a small wall). A closed concrete room took 17 dB off, and the same room with a doorway 1.1 dB. |
| Border Yard, in raid | WorldAudio switched on: AcousticSimulationEnabled, one listener on the camera, one output. Of 8,148 streamed map parts, 2,223 without collision stopped blocking sound. Five Fx events fired at the player played through AudioEmitters; 60 emitters appeared in those 8 s (the five and other world sounds), at most 7 at once. |
| Our walls at Roblox's densities | From the watchhouse's watch room, a source 8.9 studs outside, through the plaster wall: -2.8 dB against the free field (every map part made transparent). With the acoustic density x2: -16.9 dB, x3: -17.1 dB, x4.5: -21.8 dB. We use x3, capped at 6. |
| With x3, after a restart | Through the wall, 9.7 studs: -17.6 dB. Through the floor, 8 studs below: -13.8 dB. In the same room, 3 studs: +0.7 dB. No errors in the output. |
| Not checked | Hearing it (levels by ear), the fallback wall count (POTATO and the other maps) live, phones, frame cost with many emitters. |

## Stimulants, fractures and the stomach (decision gameplay-4b; 2026-11-08, about 12:30 SGT)

| Test | Result |
|---|---|
| Automated suites | All 12 pass, 910 checks. GameplayTests 70/70, 22 of them new: the four injectors and their courses at the right moments (buffs from 1 s, each side effect at its delay, nothing after the course), skill buffs from 0 to elite, the adrenaline's Recoil Control in the recoil, regeneration split over the damaged parts and skipping a destroyed one, every fracture penalty, two arms and two legs multiplying, painkillers letting you sprint on a broken leg. UiTests: the four injectors have pictures. |
| HM-2, Border Yard (god on) | With a heavy bleed on the left leg and a broken right arm, the injection took 3 s (2 s x 1.5 for the arm). The bleed stopped and BLEEDING BLOCKED showed. Near the end of its course HAND TREMOR and DEHYDRATING showed (screenshot), and hydration fell from 90 to 25: -1.4 a second for 40 s plus the normal drain. |
| SV-3 and RG-5 | The client's stamina rose to 130 (maximum +30). RG-5's painkiller showed at once. Regeneration started a second later and healed the bled leg from 61 to 65. From 200 s, SV-3's TUNNEL VISION and HAND TREMOR, with the screen edges darker (screenshot). Each buff showed as a green icon and each side effect as an orange one beside the health figure (screenshots). |
| Broken leg | A broken left leg dropped the walk speed from 3.773 to 2.075 (x0.55). RG-5's painkiller kept sprinting allowed. |
| INSPECT | RG-5 lists PAIN (245 S), HEALTH REGENERATION +1/S · 300 S, Health, Metabolism and Vitality +20 · 300 S, and HAND TREMOR AFTER 270 S, 30 S in red (screenshot). |
| Pictures | The four pens were rendered in Blender (build_items_g.py), packed on sheet 5 and uploaded (image 93201093719667). |
| Not checked | Aiming with a broken right arm by eye, a slower search with a broken arm live, the adrenaline live, a destroyed stomach's drain live (the tests check the constant), trading the stims at HALE, phone and gamepad. |

## Map-first tasks merged and placed (decision economy-6a; 2026-11-08, about 12:05 SGT)

| Test | Result |
|---|---|
| Automated suites | All 12 pass, 888 checks. New suite TaskTests (the list, the places, gunsmith specs, standings and loyalty groups, task-locked offers, operational tasks, kill conditions). The co-op exit check in LogicTests now runs with the task hooks (a stand-in raid has no player). |
| Task places | The 31 places economy-6a asked for are in the maps: 12 on Border Yard, 10 on Meridian Mall, 5 on the Smelter, 4 on Quay 7. A place on a floor is moved to the nearest clear floor after the map is built (new SpotFinder: no wall, solid part or furniture over it, headroom for a kneeling player). A place on a desk, bench, shelf, deck or boat sits exactly there. ZR_Dev `taskSpots` showed every floor place set and clear. |
| Mark, Border Yard (V10, fuel tank 1) | At the foot of tank 1 the prompt [F] MARK · SPOT MARKER showed (screenshot). Held with no marker in the raid kit (the one given before the raid went to the stash): "YOU NEED A SPOT MARKER", nothing taken. With a marker: "MARKED · STAY ALIVE 30 S", the marker left the kit, and 30 s later the objective read 1/1. |
| Find, Border Yard (V12, watch room) | Upstairs in the watchhouse, [F] PICK UP · WATCH ROOM LOGBOOK (screenshot). Picking it up showed "FOUND WATCH ROOM LOGBOOK · GET OUT TO KEEP IT". After a survived exit the logbook went to the quest-item pouch: find 1/1, and the hand-over counted 1/1 from the pouch. |
| Run-through | The same exit was a run-through (4:37, no XP): V10's "extract" objective did not count, as in EFT. |
| Prompts are the owner's | Each prompt carried the owner's UserId (`taskPrompts`); the client hides prompts that are not its own. Only one client ran, so a second player's view was not seen. |
| Not checked | The TASKS tab and the TASK overlay on locked offers on screen, handing over at a trader, a plant (the same path as a mark, without the 30 s), kill conditions in a live fight (the tests cover them), operational tasks live, quest items lost on death live, two or more clients, phone and gamepad prompts. |

## Tarkov's health and stamina indicators (decision ui-1a; 2026-11-08, about 11:35 SGT)

| Test | Result |
|---|---|
| Health figure, Border Yard, PC layout | The numbers are gone from the top left. Bottom left, a body outline: shot in the left arm (9 mm, 6 of 60 left) and twice in the right leg (destroyed), the arm showed red, the leg black and the rest green, with the bleeding icon beside it (screenshot, zoomed). |
| Stamina and stance | After a 3.5 s sprint and a crouch the stamina and arm bars and the stance marker showed over the weapon line (auto-hide), then went (screenshot). |
| Automated suites | All 11 pass, 851 checks (the server keeps the three new settings). |
| Not checked | The touch layout (figure top left) and the exits drop-down beside it on a phone, the MONOCHROME scheme and the NEVER modes on screen, the low energy and water warnings, holding breath (blue arm bar). |

## AI looting (decision ai-8a; 2026-11-08, about 11:30 SGT)

| Test | Result |
|---|---|
| Automated suites | AiTests 65/65 (new: a better gun with rounds taken and the bot's own slung, a helmet for an empty slot, a gold chain taken, no cheap dressing, key or secure-container item, the loaded magazine follows the gun, taken items lose their insurance, a cheaper gun and other-calibre rounds left, four things at most); all 11 suites pass, 850 checks. |
| Live, Border Yard (god and ignore on) | A pile 16 studs ahead (a KS-7 rifle, its loaded magazine, an insured helmet, an insured gold chain) and a scav 20 studs past it: within 25 s the scav (already carrying a KS-7) took the magazine, the helmet and the chain and left the rifle (not a fifth better than its own). In the same 25 s three other scavs picked up loose items worth carrying; one could not fit its item and moved on. Another scav was seen crouched in LOOT state. |
| Not checked | The insurance flag on the live scav's items (the tests check it), a scav swapping guns live, bodies of players killed by the AI, looting during a fight (the dispatch only runs it while calm), the AI cost with many bodies. |

## Plate pictures (2026-11-08, about 11:15 SGT)

| Test | Result |
|---|---|
| Icons | The 16 plates rendered in Blender (build_items_d.py), packed on a fifth sheet (ZR_ItemIcons_4) and uploaded; in the stash KITE III, BASALT V, PC-4 F, HP-5 S, BULWARK F and ALBATROSS VI show their pictures (screenshot). The sheet showed blank for about a minute after the upload, then loaded. |
| Coverage | 297 item definitions: 8 were without a picture. Seven now have one (build_items_e.py: the antidote, both flares, the ritual amulet and knife, the Forester's pack, the welding mask; sheet 5 packed again and uploaded, image 84071911896199), seen in the stash (screenshot; the amulet shows "?" until examined, as Tarkov does). The launcher round is never carried. New UiTests check: every carried item has a picture (UiTests 33/33, all suites 839). |

## Plates in the drag cue (2026-11-08, about 11:05 SGT)

| Test | Result |
|---|---|
| Automated suites | UiTests 32/32 (new: six plate drops checked against the server's own move on the same holder: a front plate onto an empty PC-4's tile, a western plate into its back slot, a side plate refused, a plate onto the worn vest red with TAKE_OFF_FIRST, a swap in the bunker that sends the old plate to the stash, the same swap in a raid with nowhere for the old plate refused); every other suite passing: 838 checks. |
| Server change | A part or plate a drop replaces now goes to the stash out of a raid (as the modding menu already did), not only to the pockets, rig and pack. |
| Not checked | The cue watched live while dragging (the logic is the one the tests check). |

## Relay 7: counters for all eight traders (2026-11-08, 11:00 SGT)

| Test | Result |
|---|---|
| Automated suites | LogicTests 421/421 (new: every trader of the trader screen has a counter prompt and an NPC), the other 10 suites unchanged and passing: 832 checks. |
| DEKKER, traders' hall | A counter across the hall from VOS, HALE and TILDA, facing them; DEKKER behind it with a gun rack on the wall behind him, the board DEKKER · LIAISON, the prompt [F] TRADE · DEKKER at the counter (screenshot). The Fence's stall and the blast door's leaves are clear of it. |
| KOVAC, gunsmith's room | On the south side, his parts rack behind him, board KOVAC · GUNSMITH, prompt [F] TRADE · KOVAC; the path from the corridor door to the range door stays open (screenshot). |
| ROOK and BRAM, motor pool | Either side of the vehicle opening: ROOK on the east wall (a stock rack, drums), BRAM on the west wall (hunting rifles on a rack), boards ROOK · FIXER and BRAM · GAMEKEEPER, their prompts (screenshots). |
| VOS, HALE, TILDA | Unchanged (screenshot). |
| Not checked | Opening each new trader's screen from its counter (the prompt routes to the same trader screen as before, by id), phone and gamepad prompts. |

## Skies, rain and malfunctions (audit art.2, art.12, gameplay.12; 2026-11-08, about 10:35 SGT)

| Test | Result |
|---|---|
| Automated suites | LogicTests 420/420 (new: the sky sets and the server's sky), every other suite unchanged and passing. |
| Sky (art.2) | The server's ZR_Sky starts on the clear set; Border Yard at 13:00 shows our hazy blue-grey gradient (screenshot). Switching the raid to rain turned the client's sky to the overcast set within 3 s. The night set was not seen. |
| Rain (art.12) | Rain 0.6 at 13:00 on Border Yard: streaks across the view, a dark overcast sky with a dense cloud layer (screenshot). Splashes and lens drops were not distinguishable in a still. |
| Malfunction (gameplay.12) | R-17 at 20 % condition, A62_FMJ: 25 rounds, then 17 rounds and the gun stopped; the server reported a failure to eject (malf "eject", not yet known), condition 17.9 after 42 shots. The client's MalfGlow overlay exists; its flashes were not watched. |

## M3 batch 6 and M4 batches 1-3: first Studio session after the hang (2026-11-08, about 10:15-10:30 SGT)

Studio hung at about 03:20 SGT on a runtime lighting switch; the owner closed it and I reopened it (new Studio id
b79ee504). Everything below ran in that session, on main as each branch was merged.

| Test | Result |
|---|---|
| Automated suites, main (helpers' M3 work, ai-3a, gameplay-1a, ai-1a, ai-2, ai-7a) | LogicTests 419/419, CharTests 47/47, LookTests 33/33, MapTests 41/41, EconomyTests 34/34, AiTests 54/54, GameplayTests 48/48, RecoilTests 36/36, UiTests 26/26, all on the first run. |
| + the eight traders (economy-2a) | Same, plus TraderTests 38/38. The radio's 11 tabs scroll on the compact layout (the Studio window is under 500 pt tall), DEKKER's goods and LL gates show (screenshot). |
| + the plates (gameplay-2a) and the plate trade follow-ups | PlateTests 53/54 and TraderTests 37/38 on the first run; both failures were the tests' own: PlateTests read the side plate's place after dropping it back into the vest, and TraderTests' "gear only" list for TILDA lacked the new plate kind. Fixed: all 11 suites pass, 830 checks. |
| Hits through the new armour, live raid | The worn class 2 vest (migrated to soft armour): a 9 mm PST in the thorax 33.6 damage (54 bare), 6.2 FMJ 37.4, stomach 34.0, an arm 54.0 with no armour. |
| Inventory | The migrated vest shows as VEST II 100/100 in the body armour slot (compact layout). |
| Boot and assets | Boot 16.5 s. All 1,009 meshes load, the new mall kit B batch (127419668580872) among them, with no failed batches; 527 go to clients. |
| AI cost, Border Yard, 18 AI | Calm raid, 9 awake and 9 asleep: server heartbeat 0.47 ms a frame. Worst case, all 18 woken and stood 60-180 studs round the player, two shooting at him: 0.80 ms, 59 fps (was 0.7 ms with 18 AI before scavs saw three times as far). |
| Marksmen | Two of three perches manned this raid: the depot roof (y 45) and the derrick (y 164), standing on THE DEPOT and THE DERRICK. Bug found: the derrick marksman spawned 6 studs above his platform and was put to sleep in mid-air; fixed (the perch drops 3 studs; units sleep only on the ground). |
| Player scav window | Border raid 2.2 min in: scav entry opens in 14.8 min (17 min in) and closes 6 min before the end. |
| Recoil, R-17, 30 rounds full auto | The camera climbs to 1.17° and sits at 0.49° at the end of the burst; 1.5 s later it is back to -0.19° (below the aim, as Tarkov's convergence leaves it when the shooter does not pull down). Before: 13.6° of permanent climb over 30 rounds. The gun's own climb (bullets and sights) was not measured here. |
| Not checked | The Relay 7 counters for the four new traders (built and checked at 11:00, above), plate icons (not made), gamepad and touch plate menus, sky textures (decals not yet resolved), M11 malfunction glow, rain (art.12), the lighting style (art.1). |

## M3: the Broker, scav groups and a lighter mesh library (audit ai.3, ai.8, tech.13; 2026-11-08)

| Test | Result |
|---|---|
| Automated suites | LogicTests 412/412, CharTests 47/47, LookTests 33/33, MapTests 41/41. |
| The Broker, three zones | Forced on Border for four raids: he came up at the Bastion twice, the fuel stop once and the dorms once, at 752 health. His four guards had 630 each and stood 2 to 11 studs from him at the Bastion and the fuel stop (on the forecourt, under the canopy). At the dorms they were 15 to 32 studs away 5 s in, walking in from the courtyard. |
| Bug found and fixed | The first version doubled the map offset, so the fuel-stop and Bastion guards spawned off the map and fell. The fuel stop had also fallen back to building 8, a storage block across the map. The test now checks every zone is on the map at its own building. |
| Scav groups | Border raid start: one leader with two followers (1 to 6 studs apart) and one scav alone, 4 in all (SCAV_START). 40 s later the three had walked about 220 studs together, the followers 16 studs behind the leader. |
| Mesh library (tech.13) | The server keeps all 1,009 meshes in ServerStorage; clients get 527 (the mall and bunker kits, trees, rocks, logs and cover props stay on the server). On the client in the lobby: 696 bunker kit pieces streamed in. On Border: 152 tree trunks and 148 crowns with their meshes, the client's own grass and wear kit, and a normal-looking view (screenshot). CharTests' delayed-load test now takes the helmet mesh out of the server's library. |
| Not seen | A group's man going back to wandering after his leader dies; waves of groups later in a raid; the memory or join-time saving on a phone. |

## M3 quick wins, batch 5: settings, messenger and shot visuals (2026-11-08)

| Test | Result |
|---|---|
| Automated suites | LogicTests 408/408, CharTests 47/47, LookTests 33/33, MapTests 39/39 (two activation checks skip while a raid runs). |
| Settings | CONTROLS showed MOUSE, AIM, GAMEPAD and TOUCH SENSITIVITY and INVERT Y AXIS; the tabs read GAME, GRAPHICS, SOUND, POSTFX, CONTROLS. |
| Messenger | `ZR_Dev mail vos`: the notice "NEW MESSAGE · VOS · RELAY RADIO, MESSENGER" showed; the tab read MESSENGER (3), and plain MESSENGER after it was opened once. |
| Shots | Firing at a Quay 7 wall and the concrete deck: dust puffs on the wall, cases on the ground (7 in the effects folder, capped), chipped-ring bullet holes. The first version used the wear set's hole decal, which showed as a striped smear; replaced. |
| Touch | MORE tray captions under the icons; LOOK now sits below the raid clock (re-shot). |
| Not seen | The flash itself (it lasts 0.05 s, shorter than a screenshot takes), sparks off metal, splinters off wood, a splash, hold-to-repeat, invert Y in play, double-click use. |

## M3 quick wins, batch 4: economy, skills and touch (2026-11-07)

| Test | Result |
|---|---|
| Automated suites | LogicTests **408/408** (new: Charisma lowers repair quotes and not trader prices; the Sealed Drive has a task), CharTests 47/47, LookTests 33/33, MapTests 41/41. |
| MORE tray (touch forced) | Opened in a Quay 7 raid: MAG, CHAMBER, MODE?, INSPECT, ZERO + and ZERO - captions under the icons. The screenshot showed LOOK over the raid clock; moved below it (not re-shot yet). |
| Not seen in play | The VOLT boost, the ergonomics drain, the boss hostility to player scavs, the flea buyer cap, the safe-area margins on a notched phone. |

## M3 quick wins, batch 3: sound, sniper and AI cost (2026-11-07)

| Test | Result |
|---|---|
| Automated suites | LogicTests **406/406** (new: the border sniper fires from the strip's outer side), CharTests 47/47, LookTests 33/33, MapTests 41/41. |
| Border raid | 18 AI spawned with ModelStreamingMode Atomic and climbing disabled; no errors in the console. |
| Not heard | The far-shot boom and the longer footsteps (the ambience atlas is still silent, KNOWN_ISSUES 73; footsteps need a second client). |

## M3 quick wins, batch 2: HUD, inventory, loot and network (2026-11-07)

| Test | Result |
|---|---|
| Automated suites | LogicTests **405/405** (new: deploying clears found-in-raid), CharTests 47/47, LookTests 33/33, MapTests 41/41. |
| Bunker HUD | Screenshot in the bunker: no health, stamina or needs top left; the recorder column, money and the raid line stay. |
| Not seen in play | The weapon corner timing, DISCARD's second press, ROTATE in the item bar, the reliable flare and van events, a ragdoll anchoring, an empty container. |

## M3 quick wins, batch 1: ballistics, health and AI (2026-11-07)

| Test | Result |
|---|---|
| Automated suites | LogicTests **404/404** (8 new: velocity factor, fragmentation, spill, grenade gravity, Factory time, Smelter's bosses, the Broker's and the Caretaker's health and pockets), CharTests 47/47, LookTests 33/33, MapTests 41/41. The grenade path tests passed unchanged under the new gravity. |
| Smelter boss | With the Stoker forced (`ZR_Dev boss true Stoker`) and a Smelter raid, THE STOKER spawned with 1,220 health and the 12 gauge, patrolling the furnace hall. |
| Not seen in play | The crack skipped for a subsonic round, a door heard by AI, the rough shot origin, fragmentation on a hit (all covered by code review and the unit tests only). |

## M2 phone menus, ui-3a (2026-11-07)

Checked in Studio with the new `ZR_ClientDev preview` command, which lays the menus out as on a screen of a given size
(centred in the Studio window). No phone has run them.

| Screen | Result |
|---|---|
| Inventory at 844x390 | One row of tabs (GEAR, HEALTH, SKILLS, MASTERING, OVERALL), the weight and money, CLOSE; a rail of EQUIPMENT, BAGS and STASH beside one panel; 36-pt cells; the info bar below at 13-pt text. EQUIPMENT showed the health strip and the slots, BAGS the rig, pockets and backpack grids, STASH the 10x20 stash. |
| Inventory at 932x430 | STASH with SEARCH and SORT on their own row at finger size (34 pt). |
| Traders at 844x390 | Title row with level, money, restock and CLOSE; the trader tabs; a rail of GOODS, STASH, DEAL, TASKS, SERVICES; GOODS showed BUY/SELL, the categories and the assortment in 48-pt cells (2.5 rows visible, was under one row). |
| Traders at 667x375 | STASH panel: the stash with items Vos will not buy dimmed; the trader tabs scroll sideways. |
| Studio's own window | 1156 x 407 pt here, so Studio on this laptop now shows the phone layout too (any screen under 500 pt tall does). Mouse clicks select and place, as taps do. |
| Not checked | A real phone; the DEAL panel with an offer picked (needs a tap); 667x375 for the inventory. |

## M2 lean servers, tech-4b (2026-11-07)

| Test | Result |
|---|---|
| Lean server, Meridian only (`ZR_Maps = "meridian"`) | 21,895 parts (49,988 with every map), ready at 12.4 s (17.7 s). A PMC deploy that voted for Border Yard went to Meridian, the only map offered. LogicTests 377 passed, 9 skipped (checks about maps not built), CharTests 47, LookTests 33. MapTests ran before the loop fix below, so its per-map checks did not run here; the Border run after the fix did. |
| Lean server, Border Yard only (`ZR_Maps = "border"`) | 26,897 parts, ready at 9.2 s; detail plan 21,438 entries (36,139); AI cover points 5,620 (14,013). LogicTests 377 passed, 5 skipped; MapTests 23/23, including the line-of-sight probes for Border's 538 containers and 347 doors. |
| Every map (attribute cleared) | LogicTests 396/396, CharTests 47/47, LookTests 33/33, MapTests 41/41. |
| Found on the way | MapTests' per-map checks had stopped running after the map-list change: the loop that builds the list iterated the empty list. Fixed; a new check fails if a planned map is missing. |
| Wall and floor merging (tech-4b's second half) | Measured, not built: of 49,996 parts, 31,218 are childless anchored blocks, and only 353 pairs of them share a full face with the same look. Merging would save under 1 %. |

## M1 release blockers (2026-11-07)

| Test | Result |
|---|---|
| Automated suites | LogicTests **396/396** (new: server-closed settlement for a PMC and a scav, line of sight through a wall, guard falls and walls), CharTests 47/47, LookTests 33/33, MapTests **40/40** (new M12: all 971 containers searchable from a spot within reach; new M13: all 441 doors usable from at least one side). |
| Server start | Boot log: models loaded in 3.7 s (13.4 s before the parallel fetch), ready at 17.9 s (26.5 s before). Studio on the owner's PC, so a live server will differ. |
| Join card | Seen at 00:04: "SERVER STARTING · BUILDING MERIDIAN", the progress bar, "ABOUT 12 S LEFT". |
| Server closed mid-raid | `ZR_Dev finalize SERVER_CLOSED` with a found-in-raid item added: kit and item kept (32 items), item not found-in-raid, survived count unchanged, profile invariant OK, the bunker message sent. Report: "SERVER CLOSED - KIT KEPT", one orange line, CARRIED OUT and FOUND IN RAID (0). The first version stacked the run-through line on top of it; fixed. |
| Bunker health kept | `ZR_Dev keepHealth` took 30 off the thorax in the bunker: the profile kept 55; the next raid started at 419/440 (the bunker had healed some of it). |
| Line-of-sight probe | Found three blocked containers or doors before the fixes: a first aid bag inside a stair, lockers behind a treadmill row, and two doors that open into a wall on one side (KNOWN_ISSUES 80). |
| Code gate (tech-8) | New `tools/luau_lint.py` (a Luau parser that resolves every name) passed a self-test of undefined reads, missing locals, generics, interpolation, if-expressions and `continue`, then found one real bug in `src`: the gunsmith repair kit used an undefined `prof`, so every repair failed. Fixed; in Studio the first repair returned ok and a second "It is in full condition." `tools/gate.py` now runs before every sync. |
| Not tested | A real server shutdown, the saves-down kick (live only), reconnect and server-per-raid (need the published place), phones and consoles. |

## Touch controls v2 (2026-11-02)

Setup:
- One player, touch forced with `ZR_ClientDev` "device".
- The Studio viewport is 1156 x 465, not a phone.
- Places: the Relay 7 hideout and Border PMC raids with the R-17.
- Controls were driven through the bridge:
  - "touch" (`Touch.simulate`): a finger's press, hold and drag;
  - "stick" (`Touch.stick`);
  - "touchEdit" and real mouse clicks on the editor's buttons.

Results:
- **Look:** every control shows its icon. The menu row is rounded squares; the rest are round. Screenshots:
  - the raid layout: `UI12_touch_v2_raid.jpg`
  - the med wheel: `UI13_touch_v2_med_wheel.jpg`
  - the tray: `UI14_touch_v2_tray.jpg`
  - the editor: `UI15_touch_v2_editor.jpg`
  - a stationary gun: `UI16_touch_v2_stationary_gun.jpg`
- **Stick, floating:**
  - Walked 14.5 studs in 1.6 s; pushed past the ring forward, ran 24.9 studs.
  - Let go on the lock: kept running (25.8 studs); a touch on the stick ended it.
- **Stick, fixed (FLOATING STICK off):**
  - A thumb landing 0.8 radii right and 0.4 down left the stick in place and moved the knob there. With the floating
    stick, the stick moved to the thumb instead.
  - The touch area shrank to a 295 px square around the stick.
  - A forward push past the ring ran 18.3 studs in 1.2 s.
- **FIRE:**
  - Held, it aimed down sights and let go after. A 100 px drag turned the view 13.9 degrees.
  - With AIM WHEN FIRING off, a 0.9 s hold fired 4 rounds from the hip, not aiming. Back on, it aimed while held.
- **Tap and hold buttons:**
  - CROUCH: a tap crouched; a hold went prone (the icon changed).
  - MODE: a tap changed the fire mode; a hold checked it.
  - RELOAD: a hold checked the magazine.
- **MED wheel:** a tap opened AUTO and quick slot 4 (painkillers, bound with "quick"). The buttons under it faded.
- **MORE tray:** with the R-17 (no device, a fixed sight) it held 6 items: magazine, chamber, fire-mode check, inspect,
  zero up, zero down. The sight, device and goggle items stayed out, as they could do nothing. MODE under it faded.
- **Stationary gun:** the HMG-12 on Border was mounted through its prompt.
  - GUN FIRE, GUN ZOOM and LEAVE stood where FIRE, AIM and RELOAD stand.
  - The stick, CROUCH, JUMP, GRENADE, MED, MORE, LOOK, the leans and EXITS hid; SETTINGS and BAG stayed.
  - GUN FIRE held 0.6 s with a 120 px drag fired 8 rounds and traversed the gun 26.9 degrees.
  - GUN ZOOM taps went FOV 85 to 49.2 and back.
  - LEAVE got off the gun, and the weapon's buttons came back.
- **Editor:**
  - Dragging moved FIRE. SIZE + made it 137 px. HIDE hid LEAN LEFT. SAVE kept both.
  - RESET then SAVE (mouse clicks) brought the defaults back, and the profile's layout was cleared.
  - Junk in a saved layout (an unknown control, x = 5) was dropped by the server.
- **The layout across a join:** this found a bug, now fixed.
  - The bug: the settings loader only took keys that have a default, and the layout has none, so a saved layout was
    never loaded on joining.
  - The fix: `Settings.fromServer` with an optional `touchLayout` table.
  - The check: the "rejoinSettings" bridge forgets the layout, asks for a fresh snapshot and loads it as a new session
    does. FIRE came back at x 0.78 and 148 px, with LEAN LEFT hidden.
- **Logic tests** (388 passed, 0 failed), CharTests 47, LookTests 33 and MapTests 38. The new touch tests:
  - every icon and action exists;
  - no control overlaps another or leaves the screen on four phone and tablet sizes;
  - `sanitize` works;
  - a full 24-control layout passes the settings request (it used to stop at 16 keys) and junk is refused.
- **Not verified:** a phone or tablet, two thumbs at once, real safe areas, a real second session (DataStore).

## Gamepad and touch controls: checks, zeroing, sight, inspect, free look (2026-11-02)

One player, a Border PMC raid with the R-17. The gamepad was forced with `ZR_ClientDev` "device" and its buttons pressed
through the new "pad" command, which goes through the same tap/hold/aim arbitration as a controller. Touch buttons were
pressed through "touch" (`Touch.simulate`), which runs a finger's press, hold and drag.

- **Gamepad:**
  - B: a tap crouched and another stood up; held, prone; a tap from prone crouched.
  - D-right tap: AUTO to SEMI. R3: a tap checked the magazine, a hold the chamber.
  - D-up: held, free look on while held and off after.
  - Aiming: D-up raised the zero 100 to 150 and D-down lowered it to 100. R3 checked the fire mode, with no magazine
    check. D-left did nothing with the R-17's fixed sight, and the weapon did not change.
  - Y: held, the weapon inspection without the inventory; tapped, the inventory opened and a second tap closed it.
  - D-left taps: primary, holster, melee. D-right held in melee: nothing, as there is no device.
  - D-down: a tap listed the exits (all 10 rows: 9 exits and the transit, `UI10_pad_exits_pmc_west.jpg`). Held, it
    started a grenade ("NO GRENADES IN RIG OR POCKETS" for this kit, `UI11_pad_grenade_hold.jpg`).
- **Touch:**
  - MODE: a tap went AUTO to SEMI. Held, it opened the tray (`UI09_touch_weapon_tray.jpg`).
  - The tray: CHECK checked the fire mode; ZERO + twice and ZERO - once went 100, 150, 200, 150. A MODE tap with the
    tray open closed it without changing the mode.
  - CHK: a tap checked the magazine, a hold the chamber. SWAP: held, the inspection; tapped, the next weapon.
  - LOOK dragged 120 px: free look on, head turned 26.9 degrees, off when let go.
- **Settings, CONTROLS** with the gamepad: the list shows HOLD B, HOLD D-UP, LT + R3 and the rest
  (`UI08_controls_gamepad.jpg`).
- **Tests, all passing on the second run:** LogicTests 384 (the input-map test now checks the seven shared buttons, and
  a new one checks that every control but the slot keys has a gamepad way), CharTests 47, LookTests 33, MapTests 38.
  - The first run, at the start of the playtest, failed 9 stationary-gun tests. The cause was two test runs at once
    (KNOWN_ISSUES 78, resolved): the timed-out first MCP call had started one. `tests` now runs one at a time. On a
    fresh playtest the retry joined the run in progress and reported 384 passed, 0 failed.
- **Not verified:** a real controller, a phone or tablet, the IAS and CAS backends with real buttons, a variable scope.

## HUD and touch layout: the menu row, the exits list (2026-11-02)

One player; touch forced with `ZR_ClientDev` "device" (the Studio viewport, 1156 x 465, is not a phone); a Border scav
raid, a Border PMC raid and a Meridian PMC raid.

- **Before:** with the touch layout on, SET, EXIT and BAG sat over the money and the raid clock
  (`docs/maps/evidence/UI01_touch_row_before.jpg`, `W05_touch_lgt_nv.jpg`).
- **The menu row:** it now stands at the top centre, in the band Roblox leaves free right of its own menu
  (`GuiService.TopbarInset`, read in Studio as x 164 to 1156, y 0 to 58). Only the buttons shown are centred: SET and BAG
  in the hideout, all three in a raid. The clock column is clear (`UI02_touch_menu_row_hideout.jpg`).
- **The vitals:** on this small screen they now start below Roblox's menu (y 58) instead of under it. At 1080p nothing
  moves.
- **The exits list on touch:** a drop-down under the menu row, centred (`UI03_touch_exits_dropdown.jpg`).
  - Touch buttons under a row fade while the list shows. MED faded for the Meridian list; ADS, CRCH, MED and SWAP for
    the scav's two columns.
  - Only buttons under an actual row fade: with one box around the whole list, MED faded when no row touched it.
- **A long list:**
  - **Found:** the list had 6 rows until the transits work and 8 after it, so a Border Yard PMC on the west side lost a
    row (9 exits and the transit) and a scav saw 8 of 26.
  - **Now:** all rows show. A Border scav's 24 rows split into two columns: on touch the columns meet at the centre at
    full size (`UI04_touch_scav_exits_two_columns.jpg`); with keys they stand right-aligned under the clock
    (`UI06_pc_scav_exits.jpg`).
  - **Narrow screens:** with the HUD scale at 1.4, which makes the text as wide, relative to the screen, as on a 16:9
    phone, the drop-down shrank to pass between the vitals and the recorder column, still legible
    (`UI05_touch_exits_narrow_fit.jpg`).
  - The first width rule (the widest row against the room beside the vitals) made the text unreadably small. Only rows
    level with the vitals or the clock are held to that room now, and the co-op row reads "CO-OP EXTRACTION".
- **The scav's exits:** BUNKER K-13 and NORTH LINE are no longer in a Border scav's list. The Customs reference gives
  ZB-013 and the flare passage to PMCs only.
- **Toasts on touch:** two "THE TRANSIT OPENS A MINUTE INTO THE RAID" toasts now stand right of the RUN button instead of
  under it (`UI07_touch_toasts_beside_run.jpg`).
- **Tests, all passing:** LogicTests 383, CharTests 47, LookTests 33, MapTests 38. Two LogicTests changed: a scav's list
  leaves out the PMC-only exits, and a scav arriving at Meridian by transit gets 3 exits.
  - The first run, three seconds after the playtest started, failed 12 stationary-gun tests. A run 20 s in passed
    them all. This was first put down to the server still starting; the real cause was two runs at once (KNOWN_ISSUES
    78).
- **Not verified:** a real phone or tablet, the device emulator, the Roblox menu opened wider over the row, a portrait
  screen.

## Hideout style (2026-11-02)

One player in Relay 7.

- **A new profile (level 1):** asking for the whitewash walls was refused with "Unlocks at level 5."
- **After adding XP to level 40:**
  - blue paint walls, terrazzo floor and ceiling tiles were accepted, with a toast for each;
  - the bunk room took them at once.
- **Too pale at first:** the terrazzo first rendered almost white with no texture. Darkened (ADA799), it shows its
  speckled tiles. The small tiles were darkened the same way.
- **Second set:** wood panelling walls, terrazzo and a whitewashed ceiling (`docs/maps/evidence/R7_style_panel_terrazzo.jpg`).
- **The hideout screen:** the STYLE section lists all sixteen options with USE or IN USE (`R7_style_screen.jpg`).
- **Tests, all passing:** LogicTests 383 (2 new: the options and their unlocks; every MaterialVariant a finish names is
  in MaterialService), CharTests 47, LookTests 33, MapTests 38.
- **Not verified:** a second player seeing their own style in the same bunker.

## Transits (2026-11-02)

One player, Border raids at 13:00, god mode.

- **Border Yard's transit:** the zone at the trailer lot's wood edge, with its blue mark, the sign "TRANSIT · MERIDIAN
  MALL" hanging beside the post, and a wreck parked beside it (`docs/maps/evidence/BY_transit_zone.jpg`,
  `BY_transit_sign.jpg`).
  - At first the sign hung in front of the post, which hid letters from behind. It now hangs beside the post.
  - Standing in the zone showed "[F] TRANSIT · MERIDIAN MALL".
- **Too early:** 10 s into the raid the start was refused (TOO_EARLY).
- **After 60 s:**
  - The 20 s countdown ran with "STAY IN THE TRANSIT ZONE" and the transit's name on the bar
    (`BY_transit_countdown.jpg`).
  - The player arrived at Meridian Mall's highway south end (-603, 10239).
  - The session's map became meridian with the exits RC, SC, SE, WC, RP and FG, and the bodycam read MERIDIAN MALL.
  - Six scavs were let out on Meridian Mall.
- **Exits on arrival:** O listed the six Meridian exits with their rules and "TRANSIT TO BORDER YARD · TRANSIT · OPEN"
  (`MM_transit_arrival_exits.jpg`).
- **Leaving from the new map:** at RESCUE CHECKPOINT the raid ended in a success after 8.3 s; the profile counted one
  survived raid.
- **Stepping out of the zone** 2 s into a countdown cancelled it (1 cancelled), and the exits stayed Border's.
- **There and back:** Border to Meridian, then Meridian to Border. The player arrived at Border's transit with the east
  side's exits again; 2 arrivals.
- **Tests, all passing:** LogicTests 381 (4 new in "transit": the two transits and their zones; the SPT timings; the exits
  on arrival for a PMC and a scav; the other map's keys), CharTests 47, LookTests 33, MapTests 38.
- **Not verified:**
  - a squad;
  - two players arriving together;
  - a flare or a chance exit used on the other map (the keys are tested, not a flare fired there).

## Co-op exits (2026-11-02)

One player in Studio, so the partner side ran with a stand-in (a rig placed in the zone) in LogicTests; the zone itself
was visited as a PMC.

- **Alone as a PMC** at BOILER CELLAR (Border): the notice read "EXFIL BOILER CELLAR · CO-OP: A SCAV MUST BE HERE WITH
  YOU" and no hold started (`docs/maps/evidence/BY_boiler_coop.jpg`).
  - The notices name the exit now; they used to show its code ("EXFIL BC").
- **LogicTests** (stand-in sessions):
  - the PMC alone is refused (COOP);
  - with a scav partner in the zone, the exit opens and the hold runs;
  - another PMC is no partner;
  - when the partner steps out the hold breaks;
  - a co-op leave adds Fence standing to a PMC's profile.
  - WEST CAMP (Meridian) is co-op and both PMC sides now have it.
- **Found and fixed:** on the short poles of the underground exits (BOILER CELLAR, the bunkers, the shelter, WEST CAMP)
  the radio box stood at eye height and hid the sign from behind. It now sits under the lamp.
- **Tests, all passing:** LogicTests 377 (2 new), CharTests 47, LookTests 33, MapTests 38.
- **Not verified:** two real players leaving together (the owner's two-client test).

## THE FORESTER and tripwires (2026-11-02)

Border raids at 13:00, one player, god mode, THE FORESTER forced in with ZR_Dev `boss(true, "Forester")` and the other
bosses forced out.

- **Spawn:**
  - He spawned alone at a random point of his loop, 950 health, silent (`SilentSteps`).
  - Five wires were laid in doorways near the loop, none refused, two raids in a row. Three were at building entrances
    and two at inside doors, one of them upstairs in a dorm.
  - His kit: once the KS-7, once the pump shotgun.
- **Who he fights:**
  - **Karma 0.2** (a new profile): with the player put 50 studs in front of him, he kept walking his loop. Not
    hostile at 39, 34 and 30 studs; at 24 studs he marked the player (`grudge`).
  - **Karma -1** (a new raid): he engaged at 61 studs within a second, with no grudge.
- **Tripwires:**
  - **Seen close up:** two stakes, a steel wire and the grenade at the foot of one, across the sill
    (`docs/maps/evidence/BY_forester_tripwire.jpg`).
  - **Inside door:** the same, across a corridor doorway whose leaf opens into the room (`BY_tripwire_interior.jpg`).
  - **First wire colour:** at first it was dark grey and almost invisible; it is now bare steel, 0.028 studs thick.
  - **Walking into one:** the player was stepped from 3 studs out to the door side.
    - The wire went off and the RK-5 dropped and exploded: 1 thrown, 35 fragment hits.
    - The player stayed at 440 (god mode).
  - **Disarming by hand:**
    - Looking at the wire from 3.9 studs showed "[F] DISARM · TRIPWIRE"; the multitool prompt stayed hidden.
    - F held for 12 s disarmed it. The hold bar filled under the button (`BY_tripwire_disarm.jpg`).
    - The RK-5 went into the inventory.
  - **Disarming with a multitool:**
    - With one in the pack, only the 3 s prompt showed.
    - A 3.6 s hold disarmed the next wire and the F-7 went into the inventory.
  - **A shot at the wire:** a ray cast in the shots' group (`ZR_Shot`, which collides with Default) met the wire's
    shell from both sides. The LogicTest drives the bullet hook with that shell and the wire goes off.
- **Seen:** the Forester walking the dorms in his olive jacket and beanie, the shotgun on his back
  (`BY_forester.jpg`).
- **Tests, all passing:**

  | Suite | Passed | Failed | New |
  |---|---|---|---|
  | LogicTests | 375 | 0 | 8 in "forester" and "tripwire": the boss; who he hunts; his roll; his kit and pack; his look; a step across the wire; a wire across a doorway; a shot at the wire |
  | CharTests | 47 | 0 | |
  | LookTests | 33 | 0 | |
  | MapTests | 38 | 0 | |

  The glass test now accepts the wires' hook in front of the panes' (`Tripwires.prevThrough`).
- **Not verified:**
  - his silent steps by ear (the code path only);
  - a real gun firing at a wire;
  - two players;
  - a phone.

## Tactical lasers and device modes (2026-11-02)

Border raids at 01:00 and 13:00, one player, god mode, the R-17 close-quarters build (LC-4 light/laser) given into the
second weapon slot with ZR_Dev `give`.

- **Device on and off, modes:**
  - T (real keyboard input through Studio MCP) turned the device off and on. Ctrl+T switched laser to both and did not
    also toggle the device.
  - ZR_ClientDev `devicemode` cycled both → light → laser → both. The server attributes followed each time (light only:
    WeaponLight on, WeaponLaser off; laser only: the reverse; both: both).
  - In light mode the player's own beam was removed; laser and both drew it again.
  - The HUD's weapon line read LIGHT, LASER or LIGHT + LASER.
- **What it looks like:**
  - Night, hip fire, laser mode: a red beam from the device along the barrel (not the crosshair) and a dot 28 studs away
    (0.19 studs across) (`docs/maps/evidence/W02_laser_night_hip.jpg`).
  - Day: the beam fades to a hint (transparency 0.88, 0.62 at night); the dot stays (`W04_laser_day_hint.jpg`).
  - An AI guard's laser seen from the side at night: the beam from its SMG's device (`W03_laser_ai_side.jpg`).
  - Dots scale with distance (0.43 studs at 61 studs), so they stay a few pixels wide.
- **AI:**
  - At night the guards with a combo had the light and the laser on while patrolling. Beyond 600 studs nothing was drawn
    (3 lasers on, 2 drawn).
  - At 13:00 the same guard had both off while patrolling. When it engaged the player, the laser came on and the light
    stayed off.
  - HALBERD (THE HOUNDS, R-17 close-quarters build) had his laser on in a fight. While he held cover his gun pointed
    16 to 80 degrees away from the player, so no dot landed on the player in that sample.
- **Gamepad and touch** (handlers driven with ZR_ClientDev `device` and `press`; Studio MCP cannot send real gamepad
  input):
  - **Gamepad, D-right:**
    - a tap changed the fire mode (AUTO to SEMI) and left the device alone;
    - a 0.7 s hold turned the device on;
    - a hold while aiming switched both to light;
    - a hold not aiming turned it off.
  - **Gamepad, D-left:** a tap went to the next weapon. Holds flipped the goggles up and down (NvDown) without changing
    weapons.
  - **Touch, LGT:** a tap toggled the device. Holds cycled light → laser → both.
  - The new LGT and NV buttons sit left of the right-hand cluster with no overlap. NV shows only with goggles or a face
    shield, LGT only with a light or laser on the gun (`W05_touch_lgt_nv.jpg`).
- **Tests, all passing:**

  | Suite | Passed | Failed | New |
  |---|---|---|---|
  | LogicTests | 367 | 0 | T and Ctrl+T are Tarkov's; the shared gamepad buttons are only the three tap/hold pairs |
  | CharTests | 47 | 0 | |
  | LookTests | 33 | 0 | |
  | MapTests | 38 | 0 | |

- **Not verified:**
  - another player's laser seen by a second client (the same code path as the AI's, which was seen);
  - a real gamepad;
  - a phone.

## THE CULT, Border Yard's night group (2026-11-02)

Border raids, one player, THE CULT forced in with ZR_Dev `boss(true, "Priest")` and the other bosses forced out.

- **Spawn:** the priest (850 health) and two to four warriors (440 each) appeared in one of the three zones, all prone with the knife at the hip. Seen: SQUAT WEST with two warriors, THE FRAME with four (`docs/maps/evidence/BY_cult_night.jpg`, `BY_cult_ambush.jpg`).
- **Found and fixed:**
  - At first nobody noticed a player standing still 14 studs away at night, because darkness and the narrow field of view kept them blind. Ambushers now pick out anyone within 22 studs all round.
  - In daylight their heads showed bare under the hood that hangs down the back. They now wear black beanies.
- **Ambush, god mode on:**
  - With the player 12 studs from a warrior, it rose with the knife within 1.2 s and ran to 2 studs.
  - The others got up, closed in, and a second one drew its knife.
- **The poison:** god mode was off for 1.3 s. The stabs left "BLEEDING, POISONED" among the effects (ZR_Dev `hp`), and one stab to the head killed the player.
- **Tests, all passing:**

  | Suite | Passed | Failed | New |
  |---|---|---|---|
  | LogicTests | 365 | 0 | 5 in "cult": the group and its rules; the knife against the hammer; a stab poisons and POISONED shows, and the antidote cures it; the kits; the looks |
  | CharTests | 47 | 0 | |
  | LookTests | 33 | 0 | |
  | MapTests | 38 | 0 | |

**Not checked:**
- the antidote used by hand in a raid;
- the toxin running for minutes;
- looting the priest;
- two clients;
- phones.

## Visual sweep of Border Yard (2026-11-02)

Eight views at eye height or from above, one player, 13:00 clear:
- the dorms;
- the fuel stop;
- OLD PUMPS;
- THE DERRICK;
- THE BASTION;
- the motor shop and boiler house;
- RED STORES;
- the bridge booths and a rail portal.

Found and fixed:
- **Black half-discs on the fuel stop forecourt.** The round patches that fill a road's bends drew their outer halves on the concrete where the access roads turn into the forecourt (`BY_fuelstop_discs_before.jpg`). Patches are now left out on concrete yards (`BY_fuelstop_discs_after.jpg`).

Nothing else looked out of place. Noted, not changed:
- THE BASTION is a plain two-storey block;
- one access road still shows a small notch where two of its boards meet at an angle.

Tests: LogicTests 360, CharTests 47, LookTests 33, MapTests 37, all passing.

## Meridian exits: the shelter button, the toll booth, the tanker (2026-11-02)

Meridian raids, one player, god mode.

- **SHELTER EXIT:** the mall power and the washroom valve were on (ZR_Dev `switch`). Standing in the exit zone gave "EXFIL SE · CLOSE THE DOOR WITH THE BUTTON BESIDE IT".
  - The button: a red push button on the wall beside the card door, inside. The first build found no wall, because raycasts cannot see the map while it is built away from the workspace. It is now placed from the wall part's box.
  - Pressing it (ZR_Dev `switch("SHELTER_LOCK", true)`, the same change the prompt makes) turned it green, shut the door and changed its prompt to "Sealed". The exit then counted: "EXTRACTING · SHELTER EXIT" (`docs/maps/evidence/MM_shelter_button.jpg`).
- **RIVER PATH:** a small derelict booth stands at the crossing of the dirt road and the gravel track between the power lines, its boom lowered across the road (`MM_riverpath_tollbooth.jpg`).
- **FENCE GAP:** an orange fuel tanker stands on the field side, north of the red container (`MM_fencegap_tanker.jpg`).
- **Tests, all passing:**

  | Suite | Passed | Failed |
  |---|---|---|
  | LogicTests | 360 | 0 |
  | CharTests | 47 | 0 |
  | LookTests | 33 | 0 |
  | MapTests | 37 | 0 |

  MapTests ran 37 rather than 38, with the raid on Meridian.

**Not checked:** pressing the prompt by hand, and a second player locked out by the sealed door.

## No grass through ground floors (2026-11-02)

KNOWN_ISSUES 72, fixed.
- **Before:** downward probes onto the terrain round STORE 3 found grass 0.5 studs inside the walls at 14 points. The terrain was concrete under the floor, but its surface blended into the grass voxels outside, and Roblox draws grass blades a few studs past a grass voxel.
- **Change:** a ring of bare earth out to 7 studs round every building on both maps, wherever the ground would be grass.
- **After:** probes 0.7 studs inside the walls found no grass under any of Border's 67 buildings (5,326 points) or Meridian's 49 (1,450 points). Inside STORE 3 along the north wall, no blades were seen.
- **Tests:** all passing after the change (LogicTests 360, CharTests 47, LookTests 33, MapTests 38).

## Flare exits (2026-11-02)

Border raids, one player, god mode, noon.

- **Signal area:** standing 55 studs from NORTH LINE showed "SIGNAL AREA · FIRE A GREEN FLARE TO OPEN NORTH LINE" (`docs/maps/evidence/BY_signal_area.jpg`).
- **The flare:** a green flare (ZR_Dev `give`, then the inventory "use" request) went up green over the rail cut (`BY_green_flare.jpg`).
- **Extraction:** walking into the zone after the flare started the 8 s extraction, "EXTRACTING · NORTH LINE" (`BY_northline_exfil.jpg`). The raid ended with the player out.
- **Next raid:** the zone refused again with "EXFIL NL · FIRE A GREEN FLARE IN THE SIGNAL AREA", because the flare state resets each raid.
- **OLD PUMPS:** forced open with ZR_Dev `exitOpen`. A green star rose over it 3 s after the check began (`BY_oldpumps_signal.jpg`).
- **Tests, all passing:**

  | Suite | Passed | Failed | New |
  |---|---|---|---|
  | LogicTests | 360 | 0 | 3 in "flare exits": the item; the rules on both maps; closed until a flare inside the area, nothing from one outside |
  | CharTests | 47 | 0 | |
  | LookTests | 33 | 0 | |
  | MapTests | 38 | 0 | |

**Not checked:**
- RIVER PATH on Meridian in a raid (only the rule test);
- buying the flare from VOS;
- two clients (the flare opening the exit for a second player);
- phones.

## THE HOUNDS, Border Yard's second boss group (2026-11-02)

Border raids with the trio forced in by ZR_Dev `boss(true, "Halberd")` and THE BROKER forced out.

- **Spawn:** HALBERD, MORTAR and KESTREL spawned at the Bastion yard with 1,120, 910 and 795 health. They walked the route together, about 16 studs apart. Pictures: `docs/maps/evidence/BY_hounds_trio.jpg`.
- **First fight:** the player stood in the open, 45 studs ahead, in god mode.
  - All three engaged. MORTAR threw an F-7 grenade.
  - KESTREL ran dry and fled (FLEE). His kit showed why:
    - his plate rig was refused over his vest, so he had no rig and no spare magazines;
    - the medkits of HALBERD and MORTAR did not fit at all, since pockets take only 1 x 1 items.
- **Fixed:** the three now have Tarkov's five double pockets (5 x 2, `Inv` `pocketsW`/`pocketsH`), and KESTREL wears a chest rig and a frame pack. His gear now follows the wiki:
  - HALBERD: a goggle head mount and a gaiter instead of a helmet;
  - MORTAR: a beanie instead of a helmet.
- **Second fight,** same set-up. Over 26 s all three stayed in ENGAGE and reloaded again and again (KESTREL 0 to 20 rounds twice). Nobody fled.
- **Body:** KESTREL's body, searched with ZR_Dev `loot`, showed:
  - the pockets as 5 x 2 (two smoke grenades in one pocket, upright medkits and the red flare in their own);
  - four magazines in the rig;
  - the frame pack.

  Picture: `docs/maps/evidence/BY_hounds_pockets.jpg`.
- **Tests, all passing:**

  | Suite | Passed | Failed | New |
  |---|---|---|---|
  | LogicTests | 357 | 0 | 7 in "hounds": two groups rolled on their own; the trio's health and skill; their route; the kits fit whole over 40 seeds; their gear; a double pocket takes a 1 x 2 upright and refuses a 2 x 2; their looks |
  | CharTests | 47 | 0 | |
  | LookTests | 33 | 0 | |
  | MapTests | 38 | 0 | |

**Not checked:**
- the whole route walked end to end;
- MORTAR's grenades in the second fight (the player stood in the open, and grenades go at cover);
- dragging items into a body's double pockets by hand;
- two clients;
- phones.

## AI paths into Border's cellars and bunkers (2026-11-02)

ZR_Dev `exitcheck("border", 12, true)` found two faults, both fixed and re-checked. After the fixes, every one of the 26 exits is reached from every spawn that may use it:
- BOILER CELLAR: 12 of 12;
- K-11: 6 of 6.

**Boiler cellar.** It had never had an AI path (KNOWN_ISSUES 68).
- PathfindingService (radius 1.0) found no way across the cabin floor to the stair. That floor was 2.7 studs wide between the door wall and the shaft kerb.
- One of the hall's columns stood on the top steps, at (4, 28) inside the cabin (`BY_boiler_cabin_before.jpg`).
- The column now stands at (4, 39.5), and the cabin reaches to u -6.
- Probes then: cabin to the top step, top step to the landing, landing to the cellar floor, and cabin to the cellar all succeed.

**K-11.** It had passed earlier in the day and failed now: 0 of 6.
- Ground samples in front of the shed door found holes to y -16.
- The shaft's open cut (`Ground` voids: its footprint + 2 studs) runs 0.75 studs past the shed's end walls. The 4-stud terrain columns along them were dug.
- The pathfinder found its way across them in the earlier run and not this time.
- Concrete pads 4.5 studs deep now cover both ends of the K-11 and Smugglers' Hole sheds (`bunkerShed`). The holes are gone (`BY_k11_shed_door.jpg` shows the door before the pads).

## Airdrops (2026-11-02)

Run in a Border Yard raid with ZR_Dev `airdrop("weapon", -21, -5255)`. The design and the gaps are in `docs/design/AIRDROPS.md`.

- **The plane:** it crossed the map at 420 studs. It is the four-engine transport built from parts: high wing, T-tail. Picture: `BY_airdrop_plane.jpg`.
- **The crate:**
  - it left the plane over the point and came down under its canopy (`BY_airdrop_falling.jpg`);
  - it landed after 71 s, as planned;
  - the server's crate replaced the falling one, with the canopy collapsed beside it and red smoke rising high (`BY_airdrop_landed.jpg`).
- **The loot:** ZR_Dev `loot` searched the crate item by item, as for any container. It held a built R-17 (red dot, light, grip, quad rail), two magazines, 108 rounds of 7.62 FMJ and a grenade.
- **Drop points:** Border Yard has 41, Meridian Mall 80. A Meridian raid rolled no plane, which is the 80 % case.
- **Tests, all passing:**

  | Raid | LogicTests | CharTests | LookTests | MapTests |
  |---|---|---|---|---|
  | Border | 349 | 47 | 33 | 37 |
  | Meridian | 349 | 47 | 33 | 37 |

  New: 4 airdrop checks in LogicTests (the crates and pools, the 10 x 12 fit, the maps' numbers, the flight), and M11 in MapTests (the map in play has 6 or more open, spread drop points clear of its exits).

**The red flare (later the same day):**
- under the fuel stop roof it was refused ("Fire the flare under the open sky.");
- in the open the red star climbed and burned (`BY_red_flare.jpg`);
- a common crate landed 191 s after the flare, 8 studs from the spot;
- a second flare 20 s later fired, but no second plane came (one crate at 261 s);
- LogicTests 350, all passing.

**Not checked:**
- the natural roll reaching its time (5 to 15 minutes in);
- the plane's sound: silent, because the ambience atlas loads as 0.0 s long;
- two clients;
- phones.

## Placement round 5 on Border Yard (2026-11-02)

The six builder faults fixed are listed in `docs/look/PLACEMENT.md` ("Furniture through walls, racks and stairs"). Each was checked in a Border raid with ZR_Dev `audit` and `tidylog`.

**Audit before and after:**

| Check | Before | After |
|---|---|---|
| clipping | 5 | 1 (0.3 studs, at the threshold) |
| door | 1 | 0 |
| gap | 11 | 8 |
| props the tidy pass leaves | 7 | 2 (BLOCK A chairs, 0.4 studs) |

The earlier run with every door opened (after `exitcheck`) also flagged desks touching open leaves; doors left in their raid state do not.

**Pictures (before, after):**
- `BY_fuel_office_before.jpg` / `BY_fuel_office_after.jpg`: the fuel stop's till office.
- `BY_store3_office_before.jpg` / `BY_store3_office_after.jpg`: STORE 3's office. A rack came through the wall and pallets stood between the desks.

**Tests:** Logic 345, Char 47, Look 33 and Map 36, all passing in the Border raid. The road audit is unchanged.

**Seen and not fixed:** grass blades at the foot of STORE 3's north wall inside (KNOWN_ISSUES 72).

## Road beds on Border Yard and Meridian Mall (2026-11-02)

The owner asked for nothing placed abnormally or glitching. From a roof or a hill, Border's roads looked broken.

**How the roads were checked.** The road audit (now ZR_Dev `roadaudit`, `docs/look/PLACEMENT.md`) walks every paved road inside the map's limit. Every 2 studs it samples the centre and a stud inside each edge, and casts a ray from above. It counts the samples where the terrain is hit before the asphalt boards, by how far the ground stands over the board.

| Map | Samples | Ground over the asphalt: < 0.2 stud | 0.2–0.5 | 0.5–1 | 1 or more | Worst |
|---|---|---|---|---|---|---|
| Border Yard, before | 15,344 | 409 | 111 | 76 | 203 | 18.8 studs (highway_0 at the east edge) |
| Border Yard, after | 15,344 | 67 | 19 | 14 | 1 | 1.6 (the highway crossing at the east edge) |
| Meridian Mall, before | 29,284 | 183 | 66 | 35 | 86 | 2.8 seen (south-west highways) |
| Meridian Mall, after | 29,284 | 11 | 4 | 1 | 3 | 1.6 (road 47) |

The no-board samples did not change (Border 274, Meridian 534). They are the bridge spans and the stretches outside the inner limit, where roads are painted into the terrain.

**Causes:**
- **Straight grading.** A road was graded straight between its vertices, and main_0 has three vertices over 2,000 studs. Through the hill under the fuel stop it ran in a trench up to 10 studs deep, with the fuel stop forecourt 20 studs above it.
- **Steps that ran after the grading.** The pads, rock mounds, pits and the river came after it and tilted the beds again. Banks stood up to 9 studs over road edges, and boards on slopes were short and stepped.

**Fix (`Maps/RoadBeds.luau`, both maps):**
- Roads now follow the relief along their length, averaged over about 30 studs. Rails keep their straight grades.
- A last "road beds" step levels the ground across every road at that height, out to a stud past the edge, then blends it back over 8 studs.
- Roads are done widest first, so where roads meet, a narrower one meets a wider one at its height.
- Samples near a rail keep their height, so level crossings stay level.
- Building footprints, the river, ponds and the ground outside the limit are left alone.

**Pictures (before, after):**
- `BY_road_fuelstop_before.jpg` / `BY_road_fuelstop_after.jpg`: the main road along the fuel stop from above. Stepped boards with bare ground along both edges became one straight road with clean junctions.
- `BY_road_main0_before.jpg` / `BY_road_main0_after.jpg`: main_0 by the building site. It lay in a cutting with grass over its edge; it now runs level with the ground beside it.
- `MM_road_interchange_after.jpg`: Meridian's south-west highway ramps.

The main bridge, the level crossing on main_0 and the highway junction by the east rock were looked at after the change.

**Tests (all passing):**

| Raid | LogicTests | CharTests | LookTests | MapTests |
|---|---|---|---|---|
| Border Yard | 345 | 47 | 33 | 36 |
| Meridian Mall | 345 | 47 | 33 | 36 |

**Exits re-checked after the change** with ZR_Dev `exitcheck` (doors opened):
- **Meridian:** all 7 exits are reached from every spawn that may use them.
- **Border Yard:** 25 of 26 exits are reached from every spawn that may use them. BOILER CELLAR still is not: the pathfinder does not get onto its narrow stair (KNOWN_ISSUES 68; a player walks it).

## THE STOKER, Meridian's second boss (2026-11-02)

Meridian raid, the boss forced in with ZR_Dev `boss(true, "Stoker")`.

- **Spawn:** he spawns at the KASSA GARAGE marker (L0 756, -431) with 1,220 health, the sledgehammer on his back, the welding mask, the carrier and the shotgun.
  - Picture: `docs/maps/evidence/MM_boss_stoker.jpg`. It was taken under a temporary light that was removed afterwards.
- **Charge:** with god mode off, the player stood in the open 26 studs away. He took the hammer into his hand, ran at speed 18 and killed the player with one swing.
  - The raid report read "KILLED BY STOKER · SLEDGEHAMMER · BLUNT · HEAD · 0 M".
- **Found and fixed:** against a god-mode player standing still, he ran up onto the player's head. He now stops running when the player is within 3 studs.
- **Re-checked after the fix, god mode on:**
  - With the player 22 studs ahead, he took the hammer into his hand and ran at 18. He stopped body to body (2 studs apart, 0.3 higher) and swung 4 times in 5 s.
  - With the player 22 studs behind him, he did not notice the player and walked on.
- **Tests, all passing:**

  | Suite | Passed | Failed | New |
  |---|---|---|---|
  | LogicTests | 345 | 0 | 4 in "stoker": two bosses rolled on their own; his route, health and charge; his kit; his look |
  | CharTests | 47 | 0 | C13: the welding mask takes jaw and eye hits but not the crown; the gas mask is no armour |
  | LookTests | 33 | 0 | |
  | MapTests | 38 | 0 | |

**Not checked:**
- looting his body;
- the mask worn by a player;
- him fighting AI;
- two clients;
- phones.

## Border Yard exit walk-through (2026-11-02)

The same checks as Meridian's, on all 26 Border Yard exits.

**Paths** (`exitcheck border 99 true`: 347 doors unlocked and opened): 25 of 26 exits are reached by every spawn that
may use them. For the 14 scav exits, all 12 PMC spawns were walked, since no PMC may use them. **BOILER CELLAR: 0 of
12 by the pathfinder.** The break is the top of the cabin stair (KNOWN_ISSUES 68). The way onto the first step is about
3 studs wide, between the shaft's rail and the stair. A player walked it with the keyboard instead: from inside the
cabin, down both flights, across the cellar and into the exit zone (D, W, A, S held through Studio, the character
moving under its own controller).

**Rules** (`exitwalk`):

| Exits | In the zone | Rule met |
|---|---|---|
| 14 scav exits | refused: SCAVS ONLY | as a scav: extracting (8 s) |
| CROSSROADS, TRAILER LOT, ARMY ROADBLOCK, BUNKER K-11 | extracting | |
| NORTH LINE, OLD PUMPS, SMUGGLERS' BOAT, SMUGGLERS' HOLE (chance) | extracting once rolled open for the test | |
| BUNKER K-13 | refused: NO POWER · THROW THE LEVER IN STORE 4 | lever on: extracting |
| BOILER CELLAR | refused: REQUIRES BOILER HOUSE KEY | carrying KEY_BY_BOILER: extracting |
| DORMS CAR | PAY AT THE CAR | (the fare is paid at the car) |

**Looks:** SMUGGLERS' BOAT had only the beacon on the river bank. There is now a small open motorboat moored off the
west bank beside the exit, tied to a post (`docs/maps/evidence/BY_exit_smugglers_boat.jpg`). CITY LINE's track ran
into the boundary rock, and now has its portal (`BY_exit_city_line_portal.jpg`).

Roads into the rock: Border's roads crossed the boundary in 13 places (CROSSROADS among them), and Meridian's in 8. They
all ran into the rock. They are now closed by concrete barrier rows (`Maps/RoadEnds.luau`; Meridian 31 barriers,
`MM_road_end_barriers.jpg`), and ARMY ROADBLOCK has a roadblock in front of its zone
(`BY_exit_army_roadblock.jpg`, `BY_road_end_barriers.jpg`). Border dress: cover pieces 118 to 164. Suites in a Border
raid afterwards: LogicTests 341, CharTests 46, LookTests 33, MapTests 36, none failed. The first try put the
roadblock inside the AR zone, and L03 (cover clear of exits and spawns) failed with 25 pieces.

**NOT VERIFIED:**

- AI going down the boiler cellar stair.
- The other 17 Border exits looked at by camera.

## Rail portals, trees by the rails, clutter in door swings (2026-11-02)

| Check | Result |
|---|---|
| Portals built | Meridian 2 (the west double line at both ends, openings 40.7 and 32.7 studs); Border 5 (ARMY LINE, NORTH LINE, CITY LINE, PORT LINE and the old pumps line). NORTH LINE's three tracks first met a 33.6-stud opening, and the outer track ran into a pier. Every rail end within 45 studs now sets the width (48.4 studs; `BY_exit_north_line_portal.jpg`) |
| Looked at | Meridian RAIL SIDING and its south-west end, Border CITY LINE and ARMY LINE: the tracks run under the shut gates, the portal set in the hill or the boundary rock |
| Tidy, Border | 15 trees off roads and rails (2 on roads before); the tree in front of the CITY LINE portal is gone |
| Suites in the lobby / a Border raid / a Meridian raid | all pass: LogicTests 341, CharTests 46, LookTests 33, MapTests 38 in the lobby and 36 in a raid (two map-swap checks skip while a raid runs). L02's clutter check had failed during a Border raid (11 and 19 pieces in door swings) before `World.detailAvoid` held the swing |

Evidence: `docs/maps/evidence/MM_exit_rail_portal.jpg`.

## Detail plan streamed with the map (2026-11-02)

The client detail layer's plan for the map in play now sits on invisible parts in `workspace.ZR_DetailCells`, which
stream in and out with the map. Before, it was all in ReplicatedStorage. Checked on Meridian with one player:

| Check | Result |
|---|---|
| Published | 769 cells on parts (971 KB in all), the lobby's 13 cells in ReplicatedStorage; Count 10,866 entries over both |
| Client by the mall (-211, 7737) | 276 streamed cells (274 KB) plus the lobby's 21 KB; 1,091 details built in 46 folders |
| Client teleported to the south-east corner (1112, 9861) | 282 cells, 16 within 250 studs; 842 details built there in 41 folders |
| Suites | LogicTests 341/341, CharTests 46/46, LookTests 33/33 (L02 now checks what every client gets at once, 21 KB, and the streamed parts), MapTests 36/36 |

**NOT VERIFIED:** a phone, where streaming out under memory pressure would also drop far cells.

## Meridian exit walk-through (2026-11-02)

Every exit, walked from every spawn that may use it and stood in with its rule met, then looked at.

**Paths** (ZR_Dev `exitcheck meridian 99 true`: all 80 map doors unlocked and opened first, since a keyed door on the way
is the exit's own rule; agent radius 1, height 5.6, can jump). A walk the pathfinder gives up on (it stops at about 3,100
studs) is tried in two legs through the ground part way along.

| Exit | Rule | Spawns that reach it | Walk |
|---|---|---|---|
| FG FENCE GAP | no backpack | 25 of 25 | 35 to 2,279 studs |
| RC RESCUE CHECKPOINT | open | 13 of 13 | 1,938 to 3,116 |
| RP RIVER PATH | open | 25 of 25 (2 in two legs) | 782 to 3,193 |
| RS RAIL SIDING | open | 12 of 12 (4 in two legs) | 2,645 to 3,916 |
| SC SUBSTATION CAR | car, 20,000 | 24 of 25 (4 in two legs); WEST LOT 3 by hand in two legs through (-383, 8297): 523 + 1,623 | 344 to 3,098 |
| SE SHELTER EXIT | power, valve, card door | 25 of 25 | 713 to 2,154 |
| WC WEST CAMP | scavs only | 25 of 25 PMC spawns (no spawn may use it) | 402 to 1,986 |

The first run gave SHELTER EXIT 0 of 25: its card door was locked, which is the rule. RAIL SIDING 8 of 12 and RIVER
PATH 24 of 25 were the pathfinder's length limit (all reach it in two legs).

**Rules** (ZR_Dev `exitwalk`: the player's character is put in each zone in turn and the server's own extract tick
decides):

| Exit | In the zone | Rule met | Hold |
|---|---|---|---|
| FENCE GAP | refused: BACKPACK SLOT MUST BE EMPTY | backpack off: extracting; put back on mid-hold: refused again | 10 s |
| RESCUE CHECKPOINT, RIVER PATH, RAIL SIDING | extracting | | 8 s |
| SUBSTATION CAR | PAY AT THE CAR | (the fare is paid at the car; tested 2026-11-01) | 60 s shared |
| WEST CAMP | refused: SCAVS ONLY | as a scav: extracting | 8 s |
| SHELTER EXIT | refused: NO POWER · THROW THE SWITCH AT THE SUBSTATION | power on: SEALED · FIND THE VALVE HIDDEN IN A WASHROOM; valve pulled: extracting | 3 s, then the raid ended in SUCCESS |

Exit timers are now each exit's own, from the reference (SPT `ExfiltrationTime`): the standard 8 s (was 6), the
saferoom 3 s, the hole in the fence 10 s. The HUD bar runs over each exit's own time.

**Looks** (a camera at each exit, mall power on):

| Exit | Before | Now |
|---|---|---|
| SHELTER EXIT | the room was the whole 216 x 201 block: a near-empty concrete hall, the exit marker alone in the middle | a 134 x 89 saferoom around the exit (the rest of the block stays solid): entry benches and boards, gun racks and bench, bunks, lockers, supply racks, kitchen, mess, infirmary, briefing table; 65 kit props placed |
| FENCE GAP | the marker stood in an open field 19 studs past the end of the fence | the 46 m gap is fenced, with a 5.6-stud hole at the exit; old drums on both sides and a red container on the field side, as the guides describe |
| RAIL SIDING | the double line ran into the hillside | a concrete tunnel portal with shut steel gates where the rails meet the hill (also at the line's south-west end) |
| RESCUE CHECKPOINT, SUBSTATION CAR, RIVER PATH, WEST CAMP | | sensible: the barrier and booth; the car on the road; the dirt road; the service tunnel |

Evidence: `docs/maps/evidence/MM_exit_shelter.jpg`, `MM_exit_fence_gap.jpg`, `MM_exit_rail_portal.jpg`.

Audit after the changes (`audit meridian`): one finding, the shelter's gun bench 0.30 studs off its wall (the check
flags 0.25).

Suites (raid running on Meridian): LogicTests 341/341, CharTests 46/46, MapTests 36/36 (the two map-swap checks skip
while a raid runs), **LookTests 31/32: L02 failed**. The detail plan published for Meridian was 970 KB in 787 cells,
against a 400 KB limit. The biggest cell is 12 KB, so these changes do not explain it. It came from the real-scale
Meridian, and is fixed in the next section up (the plan now streams with the map).

**NOT VERIFIED:**

- A walk by a person: the paths are the pathfinder's, the rules were met by the test bridge.
- Paying for the car on this run.
- Two players at the car.
- The exits on a phone or a gamepad.

## Weapon mastering in Studio (2026-11-02)

The mastering commits (dadf46b, 54c8b8d) had never been synced to the laptop. They were synced and checked with one
player:

| Check | Result |
|---|---|
| `ZR_Dev masterySet R17` 1,599 / 1,600 / 99,999 points | level 1 (next 1,600) / level 2 (next 2,000) / level 3, reload while aiming on |
| `ZR_Dev mastery P9` from 74 points, one point through `Economy.masteryUp` (the hit path's call) | level 2, next 100 |
| An unknown weapon | usage text, no change |
| MASTERING tab (clicked in the inventory) | groups under ASSAULT RIFLE, SMG, SHOTGUN and the rest, "WEAPON MASTERING (02)", bar 1,800 / 2,000, level-2 perk lit (`docs/design/evidence/MASTERING_tab.jpg`) |
| LogicTests mastering group (9 checks) | passed; LogicTests 341, CharTests 46, LookTests 32, MapTests 38, 0 failed |

**NOT VERIFIED:**

- Points from real hits in a raid.
- The aimed reload and the level-2 reload motion in first person.
- The level-up notice on screen.
- Gamepad and touch on the tab.

## Placement audit and tidy pass (2026-11-01/02, all four raid maps)

Studio playtests with one player. The audit is ZR_Dev `audit` (`docs/look/PLACEMENT.md`). The first column is the
audit before any fixes. The second is after the tidy pass and the builder fixes, on a fresh server start. Kit props:
Border 1,285, Meridian 2,260, Smelter 100, Quay 7 85.

| Map, check | Before | After |
|---|---|---|
| Border floating | 5 (rubble over the river; a car on a lift, a false hit) | 0 (the lift car is marked `Raised`) |
| Border sunk | 12 (drums and crates in terrain inside bunkers) | 0 |
| Border clipping | 30 | 5, 0.3 to 1.0 studs (a rack touching a ceiling, a locker 0.6 into a thin wall, a fuse box against a stepped gable) |
| Border stacked | 15 | 0 |
| Border props in a door's way | 7 (box check) | 0 (leaf-sweep check, the stricter one) |
| Border containers run into something | not checked | 0 |
| Meridian sunk / clipping | 5 / 12 (THE SUBSTATION) | 0 / 0 |
| Meridian floating | not checked (fuse box was exempt) | 0 |
| Smelter | clean | clean |
| Quay 7 | clean | clean |
| Terrain over the floor in Border's 6 underground rooms (2-stud grid) | 539 of 5,813 spots, up to 9.5 studs high | 0; ceilings 0 |
| Doors whose leaf meets a wall or a container, as built | 22 (six could open only 10°) | 1 (opens 90°); 30 doors re-hung to open the other way |

- **Tidy pass time:** 0.27 s Smelter, 0.43 s Border, 0.92 s Meridian, 0.01 s Quay 7.
- **Logic suites after the change:** LogicTests 332 passed, CharTests 46, LookTests 32, MapTests 38, all with 0 failed.
- **Screenshots:**
  - Bunker K-11 before and after: `placement_k11_before_after.jpg`, sent to the owner. The floor is flat where a
    terrain mound came through it.
  - THE SUBSTATION office: desk, chair, lockers and bench all standing on the floor.

Round 4 (2026-11-02 01:30 SGT) added the gap check and the flush step. Furniture standing off its wall:

| Map | Before | After |
|---|---|---|
| Border | 85 | 11 |
| Meridian | 191 | 0 |
| Smelter | 9 | 0 |
| Quay 7 | 3 | 0 |

Props set back against their wall: 135 on Border, 275 on Meridian, 11 on Smelter, 4 on Quay 7. A KASSA fridge row was
checked on screen: the fridges stand against the back wall. The flush keeps furniture out of doorways and door swings.
At first it moved two pieces into a doorway's margin, and that was fixed before this run. All suites pass: LogicTests
341, CharTests 46, LookTests 32, MapTests 38.

Round 2 (2026-11-02 01:00 SGT) found that the push out of walls ran the wrong way for walls whose thin side is their
Z axis. LookVector is -Z, so the push went into the wall. After the fix:

- 72 props are moved out of walls, and only 7 are left, against 62 before the fix.
- The Smugglers' Hole and the old pumps cellar were re-laid to fit.
- Four Living props were moved out of doorways.
- THE SUBSTATION's fuse box now stands on the floor.

**NOT VERIFIED:**

- AI pathing through the re-hung doors.
- Each re-hung door by hand.

## Frame rate in a separate client window (2026-11-01, Meridian)

Studio on the T490, Test → Clients and Servers with one player, so the client has its own process. It was driven over Studio MCP, which can reach the test windows. Settings: Roblox quality 10 (render level 21), viewport 1274×712, the mall's power on. The views were held with a fixed camera, the benchmark loop described below, cycles of 4 views × 11 s.

| Measure | Result |
|---|---|
| Bunker lobby, window not in front | 15.0 fps; frame times 62.7 to 71.0 ms, median 66.7 ms; render thread 10 ms a frame |
| Meridian views, window not in front, 4 cycles | KASSA 13.5 to 14.7 fps, L2 gallery 11.8 to 14.9, car park 12.8 to 15.0, outside east 11.7 to 15.0 |
| Game updates while not in front | PostSimulation fired 241 times in 4 s (60 a second) while frames were drawn 15 a second |
| Render thread per drawn frame | KASSA 11 to 20 ms, L2 gallery 17 to 19, car park 15 to 21, outside east 17 to 27 |
| Draw calls (scene + sun shadow) | KASSA about 65 to 118 + 300 to 370, L2 gallery 250 + 270, car park 235 + 350, outside east 268 + 480 |
| KASSA, sun shadows off | render thread 11.4 → 9.8 ms |
| KASSA, no shadow from parts under 3 / under 12 studs (226 / 1,687 parts) | no change (shadow draws 361 → 340) |
| KASSA, the mall's 330 lamps off | no change on the render thread (graphics card time is not reported on this laptop) |

**With the window in front** (owner clicked it, 15:40), same views, Roblox render level 21 (the top):

| View | fps | Render thread | Sun shadows off | The mall's lamps off, post effects off, glass hidden, screen UI off |
|---|---|---|---|---|
| KASSA aisles | 32.4 | 28.2 ms | 38.3 fps | 32.2, 32.3, 33.2, 33.1 fps (no change) |
| L2 gallery | 27.7 to 29.9 | 31 to 34 ms | 30.4 fps | 27.8, 25.1, 27.1 fps (no change) |
| Outside east | 29.9 | 31.2 ms | 34.8 fps | 30.4, 29.3, 27.1, 32.3 fps |

L2 gallery by Roblox render level (set from the client for the test, then put back to 21):

| Level | fps | Render thread | Draw calls (scene + shadow) |
|---|---|---|---|
| 21 (top) | 29.9 | 31.1 ms | 198 + 290 |
| 10 | 58.4 | 15.6 ms | 209 + 68 |
| 5 | 60.0 (cap) | 9.6 ms | 195 + 0 |
| 1 | 60.0 (cap) | 7.7 ms | 168 + 0 |

The user's graphics slider (`SavedQualityLevel`) cannot be set by a script ("lacking capability"); `settings().Rendering.QualityLevel` could be set from the MCP context.

So in a window that is not in front, Studio draws at most 15 frames a second while the game keeps running at 60. The 15 fps the owner saw is that cap, not the game's cost. Each frame needs 10 to 27 ms on the render thread, which would allow about 37 to 90 fps on the CPU side. With the window in front, the top render level gives 28 to 33 fps in Meridian's heaviest views, bound by the render thread. The sun's shadows are the largest single cost, at 4 to 5 ms. Level 10 gives 58 fps, and level 5 or lower hits Roblox's 60 fps cap. The benchmark marks rows counted in front FOCUSED. The earlier Play mode result below was probably capped the same way. It found "about 34 ms a frame is not drawing" and 29 fps when looking straight up, and both fit a background cap, not real overhead.

Benchmark: set the workspace attribute `ZR_Bench` to a map id (`meridian`, `border`) in Edit mode and start a test. Dev.luau deploys the first player and walks the viewpoints. The client holds each view for 4 s, counts frames for 6 s and shows a table. Rows counted while the window was in the background are marked BACKGROUND.

## Trees: branch whorls instead of solid cones (2026-11-01)

Owner: "the trees are opaque, i want it looking more realistic without compromising performance". The pine crowns of the nature kit (`build_nature.py`, `crown_whorl`) are now whorls of drooping, ragged, double-sided branch sprays with open gaps between sprays and whorls, instead of stacked solid cones. They are vertex coloured, with no textures and no transparency. Uploaded as `ZR_Nature` 120510695580100; the crown offsets are in `AssetMeta`.

| Check | Result |
|---|---|
| Triangles a crown | PineA 1,256, PineB 1,256, PineC 1,048. The old stacked cones were about 250. |
| Look (Border forest at 150, 7, -4638 looking north-east) | Before: faceted solid cones. After: layered sprays with sky between the whorls, lighter tips and darker insides. The distant trees read thinner. |
| Cost in that view, same session (Studio Play, window not in front) | All 536 streamed crowns shown: render thread 53.2 / 53.6 ms, 340k triangles. Hidden: 52.3 ms, 279k triangles. So the crowns cost about 1 ms and 61k triangles there; the old cones would be about 12k of those. Draw calls 402 against 400. |

## See-through foliage and birches (2026-11-01)

Owner: "i dont want the leaves totally opaque", then "i want the see through foliage on low graphics too, but maybe less detail". Studio Play mode on the T490, window not in front, Border, 13:00 clear, autumn.

| Check | Result |
|---|---|
| Build | Crown and bush cards carry UVs into a 1024 px foliage atlas (`assets/textures/gen_foliage.py`): spruce dark, spruce young, birch leaves, shrub leaves. The atlas is uploaded as a Decal (image 108334554762066) and set on a SurfaceAppearance template (`src/shared/ZR_FoliageSA.model.json`) in Transparency mode. The parts stay opaque, so the gaps are cut with depth and nothing is sorted. Spruce sprays hang like a comb spruce (a tent, not a flat plate), and leafy sprays are banked at random. New birches A and B (white ringed trunks, airy crowns) are in the Border mix (16 + 12 of 115) and in Pinewatch (6 + 5). `ZR_Nature` 120650690065241. |
| Runtime | Each client dresses the tagged crowns and bushes (`ZR_Foliage`, set on the library meshes and carried by every clone) within a radius: HIGH 520 studs, MEDIUM 240, LOW 110, POTATO none. Beyond the radius the cards are solid and vertex-coloured. At most 150 changes a frame. |
| Counts (forest at 150, 7, -4638) | 1,104 to 1,225 foliage parts streamed in; 435 dressed on HIGH, 66 on LOW. |
| Look | Needles and leaves show sky and trunks through them. Spruces read full from the side, and birches stand out white among the spruce. On LOW, near trees are see-through and far ones solid. |
| Cost in that view (A/B by removing the 435 textures) | See-through: 392 to 404 draws, 231k to 236k triangles, render thread 11.9 to 14.3 ms. Solid: 352 draws, 216k triangles, 12.1 ms. So about +40 draw calls and no measurable CPU change. GPU time is not reported in Studio, and the alpha-test fill cost on phones is not measured. |
| Tone | `SurfaceAppearance.Color` can be set by the client at runtime: each texture takes its tree's tone (checked: 0.996 grey on both). |
| Errors | None in the output. |

## Car exits and breakable glass in Studio (2026-11-01)

Studio Play mode on the T490, one player, god mode, Border.

| Check | Result |
|---|---|
| Automated | LogicTests 332/332 (car exits and glass groups included), CharTests 46/46, LookTests 32/32, MapTests 38/38 |
| Car exit DC | Opened with `exitOpen`, 100,000 MK. The prompt reads "[F] PAY 25,000 MK · DORMS CAR". Paid by clicking the prompt button: money 75,000, one seat taken, "CAR LEAVES IN 00:52 · DORMS CAR" with a bar. A second payment is refused (money unchanged, still one seat). The car left at 0 and the raid ended in SUCCESS (survived 1, 173,720 extracted). Not tested: a second player (shared countdown, left behind, the fifth seat), the Meridian car. |
| Glass | Two rounds at the BLOCK B washroom window from 8 studs: the pane went (transparency 1, no collision, no query) and the room behind showed through. No errors. |
| Glass test bug found | Roblox ignores `CanQuery` on a part that collides, so a whole pane met every ordinary ray, the AI's sight included. Panes now go in group `ZR_Pane` and the AI's sight and aim rays in `ZR_Sight`, which passes them (docs/design/GLASS.md). |
| Glass sound | The ambience atlas with the glass sounds was uploaded again (136853086315408). Studio read 0.0 s while it processed, and 77.8 s when checked again later in the session. |
| Prompts from a script | `ProximityPrompt:InputHoldBegin()` from the test tool and a simulated F key did not pay. A mouse click on the prompt button did. Earlier, after a death, the camera stayed in a far orbit and no prompt showed until a fresh session. |

## Fog and draw cost (2026-11-01)

Owner: fog only to improve rendering performance, the same on every graphics level. Measured in Studio Play on Border, camera 45 studs up at (0, 45, -5200) looking east along the map: 1,575 draw calls, 692k triangles.

| Check | Result |
|---|---|
| Fog alone | Atmosphere density 1 (haze 10), or legacy fog ending at 120 studs: the same 431 draws and 355k triangles as clear in the forest view. Roblox fog hides, it does not skip drawing anything. |
| Hiding everything beyond a distance (client `LocalTransparencyModifier`) | Beyond 1,200 studs: -1 draw, -2k triangles. Beyond 900: -32 draws, -26k. Beyond 700: -48 draws, -51k. Beyond 500: -95 draws (6 %), -177k triangles (26 %). |
| What the frame is made of (each hidden in turn) | Detail layer wear decals (2,210 Decals and Textures, 23 different images): about 870 draws, 55 % of all. Map decals (672): 140 draws. Tree trunks, crowns and bushes (1,864): 37 draws, 191k triangles. Kit meshes (3,070): 116 draws, 69k triangles. Terrain and characters with everything else hidden: 417 draws, 443k triangles. |
| FOG weather now | Density 0.74 still shows the hills about 1,500 studs away: much thinner than Tarkov's foggy raids. |

So a fog wall saves little unless it sits closer than about 500 studs (160 m), which would make every raid a foggy one. Most of the cost is near the player, and the largest single cost is the detail layer's wear decals.

FOG weather made thick (same day). Roblox's Atmosphere cannot close the view: at density 1 with haze 10, the hills 1,500 studs away still showed clearly. So FOG raids now use classic distance fog, clear to 38 studs and opaque at 480 (about 150 m), in the overcast sky's colour, with the Atmosphere parked meanwhile. Each client also hides the map beyond the fog's end (96-stud cells, `LocalTransparencyModifier`), the same on every graphics level. Same wide view as above: clear 1,097 draws and 637k triangles; FOG 1,085 draws and 526k triangles (13,735 parts and decals hidden), so -17 % triangles and about the same draw calls. Switching back to clear lifted the fog, put the Atmosphere back and left nothing hidden.

Follow-up the same day: the far ring held 1,372 of the decals, about 620 draws. Hiding the far ring's decals beyond 200 studs, the medium ring's beyond 175 and the fine ring's beyond 140 took that view from 1,516 to 1,020 draws. The detail rings are now HIGH 200 / 175 / 140 (were 270 / 215 / 150), MEDIUM 165 / 135 (200 / 155) and LOW 120 (135). Measured again in a fresh session from the same view: 1,072 draws (was about 1,516), 648k triangles, 1,267 wear decals (was 2,050). Nothing changes within 140 studs.

## Wall finishes and indoor light (2026-11-01)

Studio Play mode on the T490. Owner: "the walls look repetitive and fake".

| Check | Result |
|---|---|
| Light (dorm room 206, A/B by overriding Lighting on the client) | Indoor `Ambient` hardly changed the room; the indoor auto-gain (+0.55 exposure) did. That gain is now +0.35, and the daytime indoor fill is 74,77,80, down from 96,100,102. Rooms are darker than outside, with more falloff. Night interiors stay readable (lamps and night gain). |
| Upload | 21 images (colour, normal and roughness for 7 variants) uploaded as Decals; image ids read with `InsertService`; `src/materials/*.model.json` filled |
| Bug found | `World.applyWear` read `MaterialVariant.ColorMap`, which a game script may not do ("lacking capability Plugin"). The whole world build stopped and `ZR_Dev` never appeared. The read is now in a pcall, and unreadable counts as ready; same in LookTests. |
| Automated | LogicTests 293/293, CharTests 46/46, LookTests 32/32 (13 new, L04), MapTests 38/38 |
| Build | Border dorm walls: 180 band skins (10 on stairwells), 180 lines, 125 dividers in two leaves, 3 kitchen tile pieces: 488 parts. Border finishes: whitewash 635, wallpaper A 89, wallpaper B 102, gloss 189, peeling plaster 94 (it was every plaster wall), brick 1,148, wood panel 37, wall tiles 18. |
| Look | Corridor before: every wall the same stained plaster. After: green gloss to 1.5 m with chips and a dark line, whitewash above, radiators. Room 104: faded lattice wallpaper with peeling seams and water stains. |
| First-session glitch | In the first Play session after the upload, the new variants drew flat. In that session a Decal with the same image showed it, and a fresh runtime variant with an already-loaded old image worked. The next session rendered all seven, in a sky probe and in the raid. |

## Border Yard exits on the navigation mesh (2026-11-01)

Studio Play mode, Roblox PathfindingService (agent radius 1.6 to 2, height 5.5, can jump) from the dorms yard and from RED STORES to every exit zone.

| Result | Exits |
|---|---|
| Path from the dorms yard | AL, AR, CL, CR, DC, FC, HG, HR, K13, NL, OC, OF, OR, PG, PL, RP, S17, S4, SB, TL, TS, AG |
| No path from RED STORES only (the far west scav exits, over 2,500 studs away) | AG, OC, OF, RP |
| BOILER CELLAR | needs its key door (by design; the cellar path itself was checked earlier) |
| OLD PUMPS | path from its sheds to the cellar floor (19 waypoints) |
| **BUNKER K-11 and SMUGGLERS' HOLE: bug found and fixed** | No path into either shed. The name plate over each shed door hung at 5.2 to 6.8 studs, inside the doorway, which left 5.2 studs of headroom. Lifting the plates in the live server gave paths at once. In `Works.luau` the plate now hangs at 8.05 to 9.35. After a rebuild: K-11 from outside its shed, 21 waypoints; SMUGGLERS' HOLE 15, and 269 from the dorms yard. |

## Border Yard dorm interiors (2026-11-01)

Studio Play mode on the T490, one client, in-memory store.

| Check | Result |
|---|---|
| Automated | LogicTests 293/293, CharTests 46/46, LookTests 19/19, MapTests 38/38 |
| Build | 146 dorm rooms: 93 lived-in, 29 bare, 5 washrooms, 1 kitchen, 18 locked. 115 room doors. 331 furniture props (93 dropped for overlap), 513 clutter pieces, 188 fittings, 148 panes (2 frosted, 20 half-broken, 13 open, 5 boarded), 33 curtains. Border is 27,611 parts (was 25,736), living 4,656, doors 208 (30 locked); builds in 3.8 s; no errors. |
| Look | Room 206: a stripped room (mattress, rubbish, a fallen chair) with a hinged door. A ground-floor room: bed, wardrobe, desk with papers, chair. Washroom 215: tiled walls, cubicles, sinks under cracked mirrors and a towel dispenser; it opens to the corridor and has a second door to the neighbouring room. East facade: three rows of windows. |
| Fixed by this test | Tall terrain grass grew up through the ground-floor rooms. Border's terrain is now Concrete under every building footprint (checked under BLOCK A: Concrete; the room is clean). Window panes: 68 % whole made most windows walls. Now 30 % are whole and most are passable, as in Tarkov; rebuilt in Studio: 110 panes, 43 half broken, 50 open, 6 boarded, 53 glass-on-floor, Border 27,646 parts, no errors. Hold 30 fps stepped the graphics level down during a background Play test; it now waits for the window to gain focus or the player's first input. |

## Meridian small shops filled (2026-11-01)

Studio Play mode on the T490, one client, in-memory store.

| Check | Result |
|---|---|
| Automated | LogicTests 293/293, CharTests 46/46, LookTests 19/19, MapTests 38/38 |
| Build | 45 shops, +1,938 parts against a 2,000 budget (L1 28 shops +1,563, L2 17 shops +375). Fitting rooms 225, wall units 316, posters 248, bands 140, floor fixtures 751, litter 258; 0 shops failed. Meridian is 20,375 parts (was 18,437) and builds in 7.5 s. No errors in the output. |
| Look | TAILORED (clothing, L1): mannequins, racks, a fitting room, posters, wall bands and a full shelf wall; its right-hand wall is still bare. MICROMART (electronics, L1): display tables with laptops, a TV wall, a shelf of boxed goods, a counter, posters and a stocked back room. |
| Cost, with the window not in front (indicative) | Hiding the 1,938 new parts on the client: MICROMART 31.8 → 31.7 ms on the render thread (no change). TAILORED 42.2 → 37.5 ms, but the sun's shadow map redrew in the first sample (373 shadow draw calls against 0), so most of that gap is the shadow pass. |

## Meridian exits on the navigation mesh (2026-11-01)

Server of the same Clients and Servers test, Roblox PathfindingService (agent radius 2, height 5.5, can jump), raid running with the mall's power on.

| From | RAIL SIDING | RESCUE CHECKPOINT | SUBSTATION CAR | WEST CAMP | RIVER PATH | FENCE GAP |
|---|---|---|---|---|---|---|
| PMC spawn north-west | path | path | path | not tried | path | path |
| Car park, L0 | path | path | path | path | path | path |
| KASSA, L1 | path | path | path | path | path | path |
| Gallery, L2 | path | path | path | path | path | path |

SHELTER EXIT:
- No path with the power on and the valve pulled while THE SHELTER's card door is locked. That is by design: the chain is power, then the valve in the L2 washroom, then CARD_MALL_VAULT at the door.
- With the door unlocked (`door MM_SHELTER`): car park to the door, the door to the exit and the car park to the exit all have paths.

Exit rules, player teleported into each zone, with the client's `extract` notes logged:

| Exit | State | Note to the player |
|---|---|---|
| FENCE GAP | wearing the canvas bag | denied: BACKPACK SLOT MUST BE EMPTY |
| SHELTER EXIT | power on, valve pulled | hold starts; stepping out cancels it |
| SHELTER EXIT | power on, valve not pulled | denied: SEALED · FIND THE VALVE HIDDEN IN A WASHROOM |
| SHELTER EXIT | power off | denied: NO POWER · THROW THE SWITCH AT THE SUBSTATION |
| RIVER PATH | open | hold starts; stepping out cancels it |
| SUBSTATION CAR | 250,000 on the profile | hold starts showing 20,000. After the normal hold the raid ends SUCCESS, money is 230,000, and raids and survived each go up by 1 |

Gap: Tarkov's car exits (V-Ex) take 5,000 roubles per player for at most four players, are not there every raid, and leave once a group has used them. We have no per-raid chance and no departure, and our car uses the normal hold instead of the vehicle's longer countdown. The countdown length needs checking against Tarkov.

## Frame time in Studio: where it goes (2026-11-01, Meridian, KASSA)

Studio on the T490, Play mode (client and server in one process), Studio quality 10, the mall's power on. The owner's floor is 30 fps.

| Measure | Result |
|---|---|
| KASSA view (aisles to the checkouts) | 18 to 19 fps |
| Same spot looking straight up (almost nothing drawn) | 28.8 to 29.3 fps: about 34 ms a frame is not drawing |
| Server step | heartbeat scripts 0.6 ms, physics 2.2 ms |
| Client scripts | about 3 ms (heartbeat and render-step work) |
| Other maps removed from the server | no change (17.8 against 18.0) |
| Detail decals off | no change; lights off: no gain; shadows off: +0.6 fps |
| Stores L1 hidden | +3.3 fps (about 8 ms of drawing) |

So drawing KASSA costs about 20 ms and the game's scripts and physics about 6 ms. At the time, the rest of a 55 ms frame was put down to Studio and engine overhead; the section above shows it was most likely Studio's cap on a window that is not in front. The real client's frame rate is still to be measured (a Clients and Servers test, or the app).
Added after this: HOLD 30 FPS (on by default) lowers the GRAPHICS level a step whenever a device stays under 30 fps for 8 s.

## Meridian Mall on Interchange (2026-11-01)

Studio on the T490, one client, in-memory store.

| Check | How | Result |
|---|---|---|
| Automated | `dev:Invoke("tests")` with every part in | LogicTests 287/287, CharTests 46/46, LookTests 19/19, MapTests 38/38 (M05 failed before the stores added containers) |
| Build | Server log | The map model holds 18,400 parts and builds in 8 to 9 s: ground (612,000 terrain columns), outside, the mall shell (5,360 parts, 149 lamps, 65 doors, 84 units), stores L1 (941 props, 250 containers, 233 loose spots), stores L2 (662 props, 148 containers, 165 loose spots), play, dress; no errors |
| Fixes found by testing | Server log, screenshots | The shell stopped on an undefined glass colour (no walls, signs or stock rooms); the car park floor slabs were coplanar with the terrain (a camouflage pattern); barbed wire from the detail plan on the balustrades and ruin-grade cracks on every wall (now NoWire and the clean profile: 33,818 detail entries down to 10,962) |
| Raid with AI | Raid on Meridian, the Caretaker forced on; positions after three minutes, ray down from every unit | 6 guards (car park, dock, substation, garage, concourse on L1, gallery on L2), the Caretaker in BOLTWORKS, 4 scavs; scavs walked 260 to 915 studs, up to L2; every unit on a floor or the ground; no errors |
| Power | `switch MALL_POWER` | The shell's 149 lamps light; the five electric locks wait for it |
| Look | Screenshots | KASSA's aisles and checkouts, the L2 gallery over the atrium with the food court, the car park; the deep halls are very dark even with power |
| Frame rate | RenderStepped count, Studio quality 10 | 12 to 16 fps in the mall with about 16,800 parts streamed in, the same range as Border Yard that session. Indicative only |

**Not verified:** every exit walked by hand (SHELTER EXIT's power and valve chain, FENCE GAP without a backpack, the paid car), the IRONSIGHT alarm, keyed doors by hand, phones, two clients.

## Border Yard on Customs, and the eyewear slot (2026-11-01)

Studio on the T490, one client, in-memory store.

| Check | How | Result |
|---|---|---|
| Automated | `dev:Invoke("tests")` | LogicTests 241/241, CharTests 46/46, LookTests 19/19, MapTests 38/38 |
| Border Yard build | Server log | 25,822 parts in 4.8 s: ground (423,000 terrain columns, roads, rail, fences, 700 trees, 780 bushes, bridges, boundary), living quarters (43 buildings, 440 kit props, 127 doors, 223 containers), industrial side (9,357 parts, 428 kit props, 139 doors, 311 containers), gameplay (12 spawns, 6 routes, 6 posts, 118 scav zones, the Broker and 4 guards, 15 propane, 6 sniper strips), dressing (40 wrecks, 134 cover pieces); detail plan 27,586 entries in 10 s; AI cover 8,474 points (map in play first) |
| Look | Aerial screenshots of the whole map, the industrial centre and the dorms | Customs' layout recognisable: rail lines, the Derrick, the Frame, the stores, Block A and B round the car park, the river |
| Fixes found by testing | Server log, MapTests | an invalid terrain material (Pebble) stopped the whole terrain; barbed wire on the power cables; the cover test ran before the big map was sampled; 7 loose loot spots floating (now dropped onto the surface or removed) |
| Eyewear | Showroom dummies | Sunglasses, range glasses, BG-1, AF-2 and the gas mask sit right on the block head; CharTests C01 finds every ZR_EyeGear mesh |

**Not verified:** a full raid on Border Yard with AI walking the new routes through the buildings, frame rates there and on phones (343 lamps across the buildings), two clients.

### Border Yard raid with AI (2026-11-01, later)

One PMC raid on Border Yard (night, rain, autumn, the Broker forced on), five minutes of AI time, player in god mode at the Bastion.

| Check | How | Result |
|---|---|---|
| Spawns | `dev:Invoke("ai")` 20 s in | 6 watch guards (3 posted: checkpoint, army post, Bastion; 3 on routes: fuel stop, stores, trailers), the Broker with 4 guards at the dorms, 4 scavs; a scav wave added 3 more by minute 5; 10,139 cover points ready |
| Movement | Positions after 304 s, ray down from every unit | Scavs walked 119 to 1,058 studs, route guards 69 to 136, posted guards held their posts, the Broker group stayed round the dorms; every unit stood on ground (terrain or a floor, 3.2 studs above it); none stuck or fallen through |
| Errors | Output window | None from the game (only the known Baseplate texture warning) |
| Server cost | Stats on the server, Script Profiler | Lua heartbeat 0.7 ms a frame, physics step 8.3 ms (761 moving parts, all characters); scripts are not the bottleneck |
| Frame rate | RenderStepped count, Studio (client and server in one process), Studio quality 10, same night and rain | Border Yard centre 13.2 to 13.6 fps (18,653 parts streamed in, 205 lights), 18.6 looking at the sky; Quay 7 16.4 and 22.4 at the same moment (2,516 parts). Lights, particles, post effects, water and the detail layer off each changed it by under 1 fps; shadows off gave +2. The laptop ran about half as fast as in earlier sessions (Quay 7 was 36.8), so only the ratio means anything: Border Yard costs about 20% more than Quay 7 |

**Not verified:** fights on the new map (AI combat is covered by LogicTests elsewhere), phones, two clients.

### Mounted guns (2026-11-01, later)

| Check | How | Result |
|---|---|---|
| Automated | `dev:Invoke("tests")` | LogicTests 276/276 (35 new stationary checks), CharTests 46/46, LookTests 19/19, MapTests 38/38 |
| On the Bastion roof | Raid on Border Yard; real F key and mouse through Studio | The prompt "[F] MAN THE GUN · HMG-12 'BASTION'" shows when you look at the gun; F mounts it (camera at the gun's sights, HUD "HMG-12 'BASTION' · 100 / 100 · F TO LEAVE"); holding the left button fired 15 rounds in about 1.3 s (belt 100 to 85, Tarkov's Utyos is 650 rounds a minute); F leaves and the prompts come back |
| AI | `dev:Invoke("ai")` with the player on the roof | The two posted gunners fought the player with their own rifles; neither took a gun, as the player stood behind the guns' arcs |

**The grenade launcher by hand (2026-11-01, evening):**
- Real F held on the prompt manned the AGL-30 (`Op` = the player).
- A 1.5 s hold of the left mouse button fired 13 rounds (`Rounds` 30 → 17).
- A 0.7 s hold fired 8 more, and the client got 8 `nadeX` blast events.
- The HUD read `AGL-30 · 17 / 30 · F TO LEAVE`, with the reticle and `ARC 0.0 · ZERO 120 M`.
- F left the gun. No errors.

**Not verified:**
- gamepad and touch controls;
- AI gunners firing a mounted gun at a target in its arc: no guard was posted at a gun in that raid; the crew logic is `Stationary.crew`;
- the sight picture: the receiver block hides part of the view under the reticle; placeholder art.

### Border Yard underground entries (2026-11-01, later)

| Check | How | Result |
|---|---|---|
| BUNKER K-13 | Lever thrown, bunker doors opened; pathfinding and a walk with `Humanoid:MoveTo` from the top of each flight to the exit zone | **Bug found and fixed:** the open-tread flight ran into the west wall between its handrails, so a player walking down was boxed in at the bottom (pathfinding: no path). Both flights now stop 4.5 studs short of their shaft's end. After the fix: paths from the tops of both flights; the walk down the open flight reached the exit zone (30 waypoints, none missed) and the extract ran (raid report: extracted) |
| BOILER CELLAR | Boiler house door opened; pathfinding from the cabin to the exit zone | A path exists (37 waypoints down the dog-leg stair). The walk itself could not be checked: in that play session the character ignored `MoveTo` everywhere, the open cellar hall included, so it was a test-harness state, not the map. Still to check by walking it |

### Item pictures, sheet 4 (2026-11-01, later)

| Check | How | Result |
|---|---|---|
| Pictures | Rendered in Blender, review sheet by eye; then the stash in Studio with the items given and examined | All 44 new pictures (five eyewear items, the goggle strap, the propane cylinder, 37 Border Yard keys) show in the stash at their grid size with durability bars; unexamined keys show as dark silhouettes, as designed; every item in `Items.luau` now has a picture (258 in 4 sheets) |

## Bunker graphics: clean shell, grime where it gathers, no flicker (2026-11-01)

Studio on the T490, one client, in-memory store. Before and after captures B01 to B04 were taken in the session (not kept as files).

| Check | How | Result |
|---|---|---|
| Automated | `dev:Invoke("tests")` | LogicTests 224/224 (2 new: shell plain with the paint in the walls and no slits; grime placed with the clean profile), CharTests 38/38, LookTests 19/19, MapTests 38/38 |
| Shell | Server count | 98 shell parts, 0 with a worn MaterialVariant, 0 paint slabs, 197 DetailSpots |
| Decal depth | Client audit of every decal face in the bunker (260) | 0 overlapping pairs closer than 0.02 studs (3 found and fixed in the first pass: two tunnel damp strips level with the corner bands, a crack level with a doorway scuff) |
| z-fighting pass | Server log | Pulls skip hidden faces: relay7 175 to 43, quay7 211 to 108, smelter 459 to 273, meridian 1327 to 513, border 825 to 203; WallPaint and WallLine keep their full height |
| Look | Screenshots of the corridor (same spot, before and after), the ops room and the hideout | Painted walls (olive band, dark line, light plaster), plain floor and ceilings; grime in the corners and along the wall feet, soot over the generator, oil in front of it |

**Not verified:** flicker by eye while walking (a moving effect; the audit is geometric), phones.

## Lobby: Relay 7 bunker (2026-10-31)

Studio on the T490, one client, in-memory store.

| Check | How | Result |
|---|---|---|
| Automated | `dev:Invoke("tests")` | LogicTests 195/195 (11 new: under 300 kit props, at most 6 shadow lights, every prop built from its meshes, no prompt through a wall, every station has its prompt, 12 beds/lockers/spawns, departure rows 24 flaps, all four rows filled, each booth is its lane, no lane downrange, 13 targets none hidden), CharTests 38/38, LookTests 19/19, MapTests 32/32 |
| The bunker built | Server count | 293 kit props, 0 fallback boxes, 30 lights (6 casting shadows) |
| Rooms | Screenshots of every room | Bunks and locker row, ops room with boards and table, traders' hall with NPCs, corridor, hideout (dark with emergency light at generator level 0), gunsmith, range, motor pool with van and ramp |
| Shared screens | Server read-back and screenshots | Departure board "NO RAID ... RELAY 7 / NEXT RAID ... BOARD THE VAN"; roster "1/12 ON SERVER"; map sheets readable from the south side; locker card shows the callsign |
| Your side | Screenshots | Mirror orbit; R-17 clamped in the vise by its magwell; four stash guns in the rack; hideout labels "YOUR WORKBENCH · NOT BUILT" |
| Range | Fired from booth 2 | Practice ammo 25 then reload to full; display "HITS 1/8 · TIME 00:01.1", then "GROUP 26.5 CM · TIME 00:00.8"; shots outside a booth are not scored |
| Van | Boarded with the prompt | Queued, dashboard countdown, toast "IN THE VAN · STEP OUT TO LEAVE THE QUEUE", departure fade, landed on Quay 7 with REC on |
| Frame rate | RenderStepped count, render quality 21 | Bunker 20 fps (212 draw calls, 53k triangles) against Quay 7 12 fps (572, 107k) at the same moment; lights or props off changed it by under 2 fps. Indicative only |

**Not verified:** two clients (shared screens, squads boarding, others seeing the doors slam), phones, the scav hatch run to the end, a full hideout with every module built.

## M14 Weapon modding and guns as parts (2026-10-29)

Studio on the owner's T490 laptop, one client. Design and fidelity check: `docs/weapons/WEAPON_MODDING.md`.

| Test | Method | Result |
|---|---|---|
| Suites | `ZR_Dev:Invoke("tests")` | **LogicTests 184/184, CharTests 38/38, LookTests 19/19, MapTests 32/32.** |
| Modding rules | LogicTests M14 block (32 checks) | Pass. Starter rifle is a full default build (5x2); a 9 mm suppressor is refused on the 6.2 barrel (WRONG_FIT); a rail optic is refused on the pistol (NO_SLOT); the 6.2 suppressor swaps the flash hider to the stash and makes the rifle 6x2; reflex then 4x scope swap; stats (suppressed, 4x, quieter, less recoil); quad rail replaces the carbine handguard; a light dropped on the equipped gun lands on the rail; the free-float handguard is refused over the front-sight gas block (CONFLICT); barrel off with its parts makes the gun inoperable and lighter; a barrel with a suppressor is bigger than the bare barrel; the whole build moves as one bundle; a magazine dropped on the holster loads it; presets arrive as builds; tube capacity comes from the tube; in raid a pistol grip is locked without a multitool (detach and drag both refused), a flash hider is not, and with a multitool the grip comes off. |
| Asset loading | Server log | Pass. "792 meshes loaded, 0 batches failed": the seven gun batches add 187 pieces. |
| 2D pictures | Every preset drawn large through `UiKit.gunPicture`; stash capture | Pass. Each preset shows its own parts (R-17 patrol, marksman and close-quarters builds, KS-7 tactical and quiet, Harrow tactical, SMG-9 tactical, P-9 tactical, Tundra marksman and scout). A stripped rifle keeps 5x2 (standard magazine outline); a marksman build is 6x2. |
| First person | Raid on `quay7` with the R-17 patrol build | Pass. The viewmodel is built from the 14 part meshes plus the magazine; hip and aimed views; the RS-1 reflex dot sits on the bore line. |
| Third person | Orbit camera | Pass. The character holds the same build (quad rail, vertical grip, flash hider). |
| Loose loot | Raid on `quay7` | Pass for magazines (built from their part meshes); no loose gun or part rolled in the checked raid. |
| Modding screen | `ZR_ClientDev modding` on the R-17 marksman build | Pass. 3D gun, slot boxes with leader lines, stats (ergonomics 45, recoil 72/26, 10 MOA, 800 m, 942 m/s, 650 RPM, 4.42 kg, 6x2, 6x, loud, ready to fire). Dark polymer parts now use their sprites; tiny parts keep their close-up renders. |
| Console | Output | No ZR errors. |
| Not verified | – | Phones, two clients, trader preset rows on screen, every part fitted by hand in the modding screen. |

## M13 Item pictures and loose loot models (2026-10-29)

Studio on the owner's T490 laptop, one client. Pipeline and details: `docs/items/ITEM_ART.md`. Captures: `docs/items/evidence/I01`–`I07`.

| Test | Method | Result |
|---|---|---|
| Suites | `ZR_Dev:Invoke("tests")` in a raid | **LogicTests 167/167, CharTests 38/38, LookTests 19/19, MapTests 30/30.** |
| Coverage | `atlas.json` against every item id | Pass. 124 of 124 items have a picture; 95 have a loose loot model, the 22 worn items use the character meshes, the 7 weapons the weapon model. |
| Asset loading | Server log | Pass. "605 meshes loaded, 0 batches failed" (three mall kits plus the three item batches, 235 item meshes). |
| Stash and gear | Inventory screen in the safehouse, capture `I01` | Pass. Pictures fill each item's footprint, turned items show turned pictures, unexamined items are dark silhouettes, the selected item's picture is in the detail strip, and dragging shows the picture. |
| Traders | Relay radio, capture `I02` | Pass. Every offer and barter row has its item's picture. |
| Loose loot | Raid on `meridian`, capture `I03` | Pass. Wires on a VOLTA shelf lie as the Blender model with baked contact shading; the TAKE prompt works on the invisible pick box. Items are anchored with no collision or raycast hits. |
| Review sheets | `zr_item_reg.sheet` | All 124 pictures on stash-style sheets (`I04` weapons and ammunition, `I05` gear, `I06` medical, food and keys, `I07` loot). |
| Console | Output | No ZR errors. |
| Not verified | – | Phones (picture readability, memory), two clients. |

## M13 Meridian Mall (2026-10-29)

Studio on the owner's T490 laptop, one client, raids on `meridian` started through the dev bridge (`map`, `deploy`). Screenshots: `docs/maps/evidence/M01`–`M08`.

| Test | Method | Result |
|---|---|---|
| Suites | `ZR_Dev:Invoke("tests")` | **LogicTests 167/167, CharTests 38/38, LookTests 19/19, MapTests 32/32** (30 during a raid). MapTests now cover the mall: built, spawns on floors with head room, exfils over floors, every side with an open exit, loose loot resting on surfaces (snapped at build), containers and keyed doors live, AI zones, cover points, detail plan. |
| Build | Server log | Pass. The mall builds in 0.24 s: 2,407 parts and 1,810 kit meshes (621 props of all 86 kinds), 47 containers, 53 prompts. All three kit batches load (370 meshes, 0 failed). |
| Generator | Real prompt (`InputHoldBegin`, 3 s hold) | Pass. "GENERATOR STARTING", prompt disabled; 9 s later lit lights 47 → 123 and 288 ceiling panels glow; the raid info reaches the client with CARGO LIFT `powered = true` and the player gets "POWER ON". **Bug found and fixed:** the exits list kept saying NEEDS POWER until the next raid-info update; the server now sends it when the power comes on. |
| Cargo lift exit | Teleport into the zone | Pass. With power: extracted after 7 s. Fresh raid without power: still in the raid after 12 s. |
| AI paths | PathfindingService with the AI agent (radius 1.6, height 5.6, no jumping); `aiGoto` | Pass: L1 ↔ L2 (escalators, collapse slope, stair cores), yard → L2, car park → lobby, ground → roof car park over the ramp; a scav sent from L1 to the L2 gallery arrived. **Fixed:** the cinema seating (1.3-stud risers) had no path to the back or the projection booths; a side aisle with half steps and a wider booth door fixed it, and the PROJECTION visit point moved off the projector. |
| Barbed wire | Detail plan | **Fixed:** the plan put 173 barbed-wire pieces on the mall's facade bands, parapets and gallery edges; the mall now opts out (`NoWire`), 0 left. |
| Muzzle flash (owner request) | Fired the R-17 in a raid, `ZR_Fx` probe, capture `W01` | Pass. First person: a 0.12-stud round glow (was a 0.35 cube), light range 9 / brightness 1.6 (was 12 / 2.5), exposure kick halved. Other shooters: 0.22 round glow. No errors. |
| Frame rate | RenderStepped count, Studio (client and server in one process), our HIGH | Mall 25.6–31.4 fps at Studio's render quality 21, 45.8–57.7 at quality 10, 60 (the cap) at quality 5, against Quay 7 30.1 / 60 / 60. Before the pass: atrium 23–24 / 45, gallery 22–23 / 43–47. Table and cost breakdown in `docs/maps/MERIDIAN_MALL.md`. Indicative only. |
| Console | Output | No ZR errors. New warnings: `rbxassetid://111777818918264` fails to load (HTTP 502 or "being generated") and is not referenced by any instance (KNOWN_ISSUES 48); the two new floor maps returned HTTP 502 once and loaded after a retry. |
| Not verified | – | Phones and consoles; two clients; a full 25-minute raid with players fighting through the mall. |

## M12 Look 2.0 (2026-10-29)

Studio on the owner's T490 laptop. Details and screenshots: `docs/look/LOOK_2_0.md`, `docs/look/evidence/L01`–`L11`.

| Test | Method | Result |
|---|---|---|
| Suites | `ZR_Dev:Invoke("tests")` | **LogicTests 167/167, CharTests 38/38, LookTests 19/19.** LookTests: the graphics level through the real dispatcher (0 and 3 accepted, 1.4 rounds to 1, 9 clamps to 3, −4 to 0, a string refused); the published detail plan (count, cells, known images, library meshes, clutter clear of loot, containers, doors, exfils and spawns, 164 KB < 400 KB); no server-side detail; 28 solid cover props using the meshes, clear of spawns and exfils; a shot at a car wreck stops at the wreck. |
| Detail plan | Server log | Pass. 2,024 entries in 63 cells, 164 KB, 1.24 s at server start. AI cover points 834 → 1,018 with the new props. |
| Detail layer | Client `detail` probe, captures | Pass. HIGH builds about 1,000–1,700 details near the camera and none from the safehouse under the map. Streaks, grime, cracks, puddles, rubble, graffiti, wall fittings and container rust render (`L01`, `L02`, `L04`, `L05`). |
| Graphics setting | Real settings screen (mouse clicks), captures | Pass. GRAPHICS shows HIGH by default; four clicks on − reach POTATO (clamped); + returns to HIGH. POTATO removes the detail, the worn materials (681 parts), shadows and clouds; leaving it restores all 681 (`L03`, `L07`). |
| Worn materials | Test wall of every variant | **Bug found and fixed.** Five of the eight variants rendered almost black although each texture loaded on its own. New roughness maps fixed them (`L08` before, `L09` after). |
| Cover props | Top-down and ground captures | Pass. 28 meshes placed and tinted; no overlaps with map parts; clear of spawns, exfils, AI paths, loot spots, containers and doors (`L10`). |
| Lamps | Night raid (22:30), light-state sampling | Pass. The relay gate lamp stays dark; a flickering lamp dipped twice in 8 s (0.24 s dark), the others burn steady (`L06`). |
| Frame rate | RenderStepped count, Studio on the T490 (client and server in one process) | South yard: HIGH 36.8, MEDIUM 43.1, LOW 45.4, POTATO 58.9 fps. Harbor Stack: 33.5 / 39.4 / 42.6 / 58.2. The detail layer itself costs about 3 fps there. Indicative only; no device numbers. |
| Not verified | – | Phones, tablets and consoles at HIGH (the owner's default); two clients seeing the same detail. |

## M16 Characters and equipment (2026-10-28)

The full C01–C12 table with evidence levels and paths is in `docs/character/TEST_REPORT.md`.

| Test | Method | Result |
|---|---|---|
| Logic suite | `ZR_Dev:Invoke("tests")` | **167/167 pass**, including the block-body proportion and support-hand reach checks with 1.35× third-person weapons. |
| Character checks | `ZR_Dev:Invoke("chartests")` | **38/38 pass**: C01 import and sizes, C02 layering, C03 equip/replace/unequip and per-slot diff, C04 delayed-load fallback and reconcile, C05 invalid requests through the real dispatcher, C06 idempotency, C07 hits ignore gear, C09 presets and 480 seeded kits, C12 churn. |
| Presets | Showroom captures (front, side, back, close-ups) and Blender renders | Pass: operator, scavenger, guard, bodyguard and Foreman are distinct and reuse one rig. Heavy kit (face-plate helmet, Bulwark armour with collar and arm guards, raid pack) and a hooded scav variant were also captured. |
| Poses with gear | Showroom with the real animator | Pass. Covered: idle, aim, walk, sprint, crouch, crouch-aim, prone, look up with the raid pack (neck limit), look down, pistol. No detached gear. |
| In raid | Deploy and give through the dev bridge | Pass. Helmet, headset (behind the neck) and gaiter appear on the character. First person hides all 41 own parts locally. Viewmodel sleeves are block meshes in the outfit colour. |
| Death, respawn, reload | `kill`, `rejoin` | Pass. The corpse keeps all 11 gear pieces. The safehouse respawn wears the remaining profile kit with no duplicates. A profile reload keeps the appearance. |
| Safehouse requests | Real `inv` dispatcher | Pass. Equipping a shell, patrol pack and carrier shows on the character. A headset under the shell is refused (HELMET COVERS EARS). Quick move to stash works again; it was always refused before. |
| Restart | Play stop → start | Pass. The five presets look identical before and after. |
| Inventory | Tab through MCP keyboard input | Pass (structure). EARS and FACE slots render and are selectable. |
| Not verified | – | Two or more clients (C06 late join, a second observer for C08), touch and controller emulation (C11), devices and performance. |

## M10 World (2026-10-28, in progress)

| Test | Method | Result |
|---|---|---|
| Logic suite | `ZR_Dev:Invoke("tests")` | **146/146 pass** (12 new: 7x raid clock and midnight wrap, daylight curve, valid environment rolls, AI sight day > fog > night and hearing dulled only by rain, crew weapon lights in valid kits, 56 loose spots with valid pools, every pool item exists, 8 dorm doors with real keys, vault keycard, key spots roll keys). |
| Time and weather | `env` dev command, screenshots | Pass. Noon clear, overcast afternoon, dusk 18:10, rainy night 22:48 and clear night 22:30 all render; the REC stamp follows the raid clock; street lamps on at night. Night fill was retuned after the first test was near black (Roblox lights in linear space). |
| Lens and HUD | Screenshots | Pass. HUD text straight; grain halved; vignette lighter and neutral (no colour); colour fringing tried and removed at the owner's request. |
| Dormitory | Screenshots, real F key | Pass. Two storeys, rooms 101–204, balcony and stairs; a scav inside room 102 opened its closed door and walked out (AI door use). |
| Loose loot | `loose` list, real F key | Pass. 17 items spawned around the map; MATCHES taken from a dorm desk went to the pockets as found-in-progress; the prompt reads TAKE · MATCHES. |
| Vault | Real F key with office key then keycard | Pass. Office opens with the key; the vault prompt reads SWIPE CARD; the card reader LED turns from red to green, the door opens onto two safes and the arms crate; the prompt then reads CLOSE. |
| First-person arms | Screenshots | Pass. Round sleeves, elbow, cuff and gloves instead of thin sticks. |
| Not verified | – | Rain streaks, lens droplets, the new lens textures, the env sound atlas and the Blender gear meshes: the PC's DNS failed during testing, so Studio could not download them. |

## M9 Economy (2026-10-28)

| Test | Method | Result |
|---|---|---|
| Logic suite | `ZR_Dev:Invoke("tests")` | **134/134 pass** (19 new: XP curve and levels, skill bonuses, trader prices by loyalty, best buyer, quest items unsellable, fence karma pricing, dog tag value by level, data consistency (every offer, barter, task, recipe and module references real items), run-through rule, loyalty from level/spend/standing, give/consume stash, sell quote, task status/complete/hand-in with FIR items, storage racks → stash 10x25; the scav cooldown test now expects the karma-adjusted cooldown). |
| Buying | `dispatch trade buy` (real dispatcher) | Pass. P-9 Vesna 11,875 MK (250,000 → 238,125), 2 × 60 FMJ (−18,000), SMG then SMG again → OUT_OF_STOCK (limit 1 per restock), KST rifle → LOCKED (loyalty 2). |
| Barter | Hale: Road Kit for 2 cigarettes + matches | Pass. Without items → "Missing: Cigarettes."; with them → traded. |
| Selling | Spark plug, gold chain | Pass. Plug sold to the best buyer (+2,250); an unexamined chain is refused ("Examine it first."); VOS refuses loot; after examining, the chain sold for +31,000 to the best buyer. |
| Tasks | First Aid (Hale) | Pass. Accept → turn-in refused while incomplete → 2 dressings + 1 kit found-in-raid → turned in: +12,000 MK, +400 XP, Hale standing +0.05, the Road Kit reward reached the stash as found-in-raid. Locked tasks refuse ACCEPT. |
| Task progress | Signal Check (kill 5 scavs) | Pass. A scav shot in a raid moved it to 1/5 immediately (toast), before extraction. |
| Hideout | Build generator → storage → workbench, craft FMJ | Pass. Missing items / missing generator / busy builder refused with the right message; each build finished with `hideoutNow`; stash grew to 10x25; craft refused a second recipe while busy and early collection; collected 60 FMJ. Money 198,375 → 18,375 (−40k −80k −60k). |
| Screens | Relay radio (VOS, HALE, PROFILE tabs), workbench | Pass (screenshots). Offers with price and stock, loyalty requirements, tasks with status, progress and rewards, XP bar, skills, karma; hideout modules with requirements (have/need in green/red), build timers, crafts. Fixed: long requirement lines were cut off (now full width, two lines); the restock timer froze when the screen was reopened. |
| Locked door | Depot office, real F key | Pass. Without the key: "LOCKED · REQUIRES HARBOR OFFICE KEY", door stays shut; with the key: "UNLOCKED · DEPOT OFFICE", door swings open, the office light and safe are reachable. Fixed: the on-screen prompt kept saying UNLOCK after the door opened. |
| Run-through | Extract after 1:53 with one kill | Pass. "EXTRACTED (RUN THROUGH)" with the explanation line; loot kept, nothing found-in-raid. Fixed: the report still listed a picked-up key under FOUND IN RAID. |
| Dog tag | PMC KIA | Pass. Body B1 holds DOGTAG {name, level}; the player's own report no longer lists the tag as lost or found. |
| Console | Output log | No ZR errors. |

## M8 AI 2.0 (2026-10-28)

| Test | Method | Result |
|---|---|---|
| Logic suite | `ZR_Dev:Invoke("tests")` | **115/115 pass** (10 new: faction rules incl. player-scav truce and provocation, Watch vs player scavs, AI truce, guard/boss/crew loadouts valid and loaded with spare magazines, skill ordering). |
| Spawning | Raid start, `ZR_Dev ai` | Pass. 3 Watch (mezzanine overwatch post, two patrols), the Foreman + 2 crew on boss raids (otherwise a depot Watch patrol), 4 scavs at points of interest away from insertion points; cover map 834 points (interiors included). |
| AI vs AI | Earlier build without the truce | Watch and scavs wiped each other within a minute; switched to a truce (AI never target AI). Verified afterwards: no AI-vs-AI engagements. |
| Engagement | Studio god-mode target 60 studs from a Watch guard | Pass. Spotted after ~0.5 s, crouched at range, fired bursts (16 → 0), reloaded from the rig (2.9 s) to a fresh 22-round magazine, kept firing. |
| Lethality | Real damage, player standing in the open | A scav SMG and a Watch R-17 each brought the player from 440 to ~180 in a few seconds; deaths credited "KILLED BY HARBOR WATCH · R-17 · HEAD" / "KILLED BY SCAV · Harrow-12 · 12/70 Buckshot". Accuracy and reactions were lowered after this test. |
| Boss group | Forced boss raid, target inside the depot | Pass. Foreman and crew patrol in formation; on contact they take cover (cover=true), alternate crouch and peek, reload, search the last known position, then push the player's position. First-person screenshot shows the crew aiming from the dock doors. |
| Out of ammo | Scav with a single magazine | Pass. Emptied the magazine, found no spare, fled to a far point of interest. |
| Boss loot | Kill the Foreman | Pass. Body container created with his full kit. |
| Performance | Server stats with 10 AI fighting | Heartbeat callbacks 0.44 ms, physics step 3.3 ms, physics 60 FPS (Studio, client and server in one process). |
| Console | Output log | No ZR errors. |

## M7 Multiplayer raids (2026-10-28)

| Test | Method | Result |
|---|---|---|
| Logic suite | `ZR_Dev:Invoke("tests")` | **105/105 pass** (17 new: scav kit, scav deploy keeps the PMC loadout, cooldown, scav extract to stash with FIR, scav death leaves the PMC untouched, insure item + mag, insure-all quote, non-insurable secure container, insured gear collected from a body, only insured parts return, claim waits for the delay, claim delivers to the stash). |
| Queue → raid | Real `deploy` request | Pass. IDLE → MATCHING (12 s countdown on the HUD and terminal: "YOU ARE QUEUED · INSERTION IN 00:08") → RUNNING; west spawn with exfils A, B, E, F; chance exfil F rolled closed. |
| Queue lock | Discard and redeploy while queued, then cancel | Pass. QUEUED errors; cancel returns to IDLE and the discard then succeeds. |
| Late entry | Deploy while the raid runs | Pass. Entered directly (`entered: true`). |
| Exfil rules | Teleport into F (closed), E (no key), B (paid) | Pass. F and E refused (session stays ACTIVE); B extracted after 6 s and charged 8,000 MK (250,000 → 242,000). Exfils outside the session's list do nothing. |
| Exits list | O key, screenshot | Pass. Names with requirement text and colour (PAY 8,000 MK, KEY REQUIRED, MAY BE UNAVAILABLE). Fixed: the list now hides again after 6 s. |
| KIA body | Dev kill | Pass. Lootable body B1, the corpse copy stays in `ZR_Corpses` after the hideout respawn (41 parts, frozen); orbit screenshot shows the ragdoll with [F] SEARCH · BODY. |
| Empty raid | Kill the only raider | Pass. Raid ended after ~8 s (`EMPTY`), bodies and corpses cleared, insurance settled into 1 claim. |
| Insurance (KIA) | Insure all (−11,439 MK), die, raid ends, claim | Pass. The insured kit returned to the stash with magazines and rig contents; uninsured ammo did not; invariant OK. |
| Insurance (MIA) | Insure an SMG, deploy, expire the shared clock | Pass. MIA, claim created immediately, SMG returned after the claim. |
| Player scav | Deploy as scav, extract at D (scav-only) | Pass. Random kit (Tundra bolt rifle, rig, bag, junk), scav clothes and cap, no bodycam, full health, all 6 exfils, 10-min cooldown; the kit went to the stash; stats scavRaids 1 / scavSurvived 1. |
| HUD size | Screenshots before and after | Pass. Vitals, recorder line, clock/money, exits and status text are larger (scaled for small windows) and stay in the margins. |
| Console | Output log | No ZR errors. |

## M6 Movement & animation (2026-10-28)

| Test | Method | Result |
|---|---|---|
| Logic suite | `ZR_Dev:Invoke("tests")` | **88/88 pass** (6 new rig-math tests: arm IK reach, full-body solve, stance hip heights, stand/prone eye height, lean offset, crouch ankle planting). |
| Operator rig | Server and screenshots | Pass. Players load the StarterCharacter rig (15 Motor6D, Blender meshes, no AnimationConstraint conversion); guards use the same rig in navy kit. |
| Third-person animation | Orbit camera on self and a patrolling guard | Pass. Walk cycle with planted feet, rifle held in both hands at low ready; crouch, prone and lean poses (screenshots). |
| Server hitboxes | Prone, check Motor6D.C0 on the server | Pass. Root pitched −88°, head 0.78 studs above the floor and 1.39 forward. |
| First-person eye | Prone and lean | Pass. Prone eye 0.84 studs high and 1.69 forward; lean right rolls and shifts the view. |
| Vault | Space facing a jersey barrier | Pass. Carried over the barrier (x −13.3 → −7.6), no jump stamina spent. |
| Walking speed | Mouse wheel ×3 | Pass. Speed step 10 → 7, walk speed scaled. |
| Arm stamina | Aim for several seconds | Pass. Arms drain while aiming (HUD shows ARMS), recover when lowered. |
| Sound atlas | Preload + live sounds | Pass. 25.6 s atlas loads; guard footsteps play as positional regions. |
| Ragdoll | Guard health to 0 | Pass. 14 joints become ball sockets, body falls, lootable with [F] SEARCH. |

## M5 Weapons 2.0 (2026-10-28)

| Test | Method | Result |
|---|---|---|
| Logic suite | `ZR_Dev:Invoke("tests")` | **82/82 pass** (14 new: mounts, caliber-specific muzzle devices, swap returns old part, mod stats, slot drops, bundles keep mods, mag onto holster). |
| Weapon switching | ClientDev `switch` primary → holster → melee → secondary | Pass. Server `active` follows; draw time blocks firing; third-person weapon in hand, long guns slung. |
| Auto-draw | Drop the weapon in hands via the real `inv` dispatcher | Pass. Next weapon drawn, visuals refreshed. |
| Magazine reload | Fire 6, press reload | Pass. 19 → 25 with the rig magazine; predicted count used for the spare check. |
| Tube reload | Harrow-12 empty, reload | Pass. Shells loaded one by one (0 → 2 → 6); bolt rifle loads the same way. |
| Pump / bolt | Fire Harrow-12 and Tundra | Pass. Rounds 6 → 4 and 4 → 3; cycling animation gates the next shot. |
| Mag check | T / ClientDev `magcheck` | Pass. Timed check, HUD shows the estimate text. |
| Knife | ClientDev `slash` | Pass. Swing animation, server melee request. |
| Attachments | `inv` op `mod` with suppressor, reflex, light, then 4x scope swap | Pass. Mod stats on the server (loud 0.35, recoil 0.93); third-person parts 13 → 18; old reflex returned to the grid on swap. |
| Optics | Aim with reflex, then 4x | Pass. Reflex dot overlay; scope overlay with FOV 25.8° and zoom-scaled sensitivity (screenshot). |
| Weapon light | L / ClientDev `light` | Pass. Viewmodel SpotLight; server attribute and third-person light on. |

## Automated

| Suite | Result |
|---|---|
| `src/server/Tests/LogicTests.luau` (inventory, settlement, escrow, finalize idempotency, migration, recovery kit, grid) | **38/38 pass** |
| `tools/luau_check.py src` (structural block and bracket check, 41 files) | pass |

## Gameplay loop (2026-10-28)

| Test | Method | Result |
|---|---|---|
| Deploy | Real click on `Btn_DEPLOY` | Pass. Loadout escrowed, spawned at WEST/SOUTH, 3 guards spawned. |
| Loot | E prompt → timed server search → TAKE ALL | Pass. Items moved to the raid inventory, invariant OK. |
| Combat | ClientDev fire; guard killed | Pass. Shots accepted, ammo tracked on the server, kill credited, body lootable. |
| Reload | R key | Pass. Swapped to the 25-round mag, 31 rounds spare. |
| Movement | WASD and Shift | Pass. Sprint drains stamina; walking regenerates it. |
| Extraction | Stand in zone for 6 s | Pass. EXTRACTED dossier shown, profile credited, simulated rejoin identical. |
| Death (KIA) | Dev kill | Pass. Dossier shown, at-risk gear lost, respawned in the safehouse. |
| MIA | Dev expire timer | Pass. Gear lost. |
| Safehouse | Recovery kit, fill magazines, move items in the UI | Pass |
| Save retry | `ZR_Dev saveRetry` with 2 injected write failures | Pass. A critical save succeeded on attempt 3 after 1.5 s. |
| Save retry, exhausted | 5 injected failures | As designed. All 4 attempts failed (`STORE_ERROR:SIMULATED_FAILURE`); the profile stays dirty so autosave retries later. |
| Crash mid-raid | `ZR_Dev crash`: session dropped without settlement, live profile discarded, profile reloaded from the store | Pass. Before the crash, the stored copy already held `pendingRaid` (saved before spawn). On reload it was settled as DISCONNECTED: the 6 escrowed items were lost, `pendingRaid` was cleared in the store, the invariant held, stats show raids=1 / lost=1, and the player respawned in the safehouse at 100 HP. |

## Abuse and exploit probes

All probes ran through the real dispatcher (`ZR_Dev dispatch` / `shotAbuse`). Inventory invariants held after every probe.

| Probe | Result |
|---|---|
| Deploy spam while in raid | ALREADY_IN_RAID |
| Two concurrent takes of the same item GUID | One OK, one GONE. Exactly 1 copy. |
| Sell while in raid | NOT_AUTHORIZED |
| NaN coordinates, unknown op, nested payload, oversized string, unknown action | BAD_INPUT |
| Take from an unsearched or distant container | TOO_FAR |
| 20 shots in the same tick | 1 accepted |
| Replayed shot sequence, NaN direction | Rejected |
| Shot origin 500 studs away | Clamped to the head |
| 30-request flood | 4 accepted, 26 throttled |

## Audio (2026-10-28)

| Test | Result |
|---|---|
| `ContentProvider:PreloadAsync` on all 7 sound IDs | All **Success**. Lengths match the source files (fire 1.35 s, far 2.05 s, reload 2.35 s). |
| In raid: 3 shots and a reload | 3 R17_FIRE instances and 1 RELOAD instance created |
| Ambience | 1 looping ambience track playing |
| Extraction hold | Countdown beeps played (4 captured); summary shown |
| UI click on RETURN TO SAFEHOUSE | Click sound played; modal closed |
| Console | No ZR errors. The only warning is the Baseplate texture warning (203785492), which predates this project. |

## Assets

- **Meshes:**
  - Batch A (9 meshes) and the crate load through InsertService ("9 meshes loaded, 0 batches failed").
  - The world dropped from 1,530 to 648 parts.

## M11 part A: grenades (2026-10-28, Studio, single client, in-memory store)

| Test | Result |
|---|---|
| Logic tests | **164/164 pass** (18 new: landing and rolling to rest, throw distances, wall bounce, path sampling and interpolation, lob/flat aiming, fragment falloff and counts, stun facing and walls, smoke growth and line-of-sight blocking, rig-before-pockets pick and no backpack, item/trader/loot/craft wiring, AI carry rates). |
| Asset loading after the DNS fix | All 31 Blender meshes load ("0 batches failed"); the operator body uses the Blender model; players wear the gear meshes (vest, pouches, body camera, pack, holster are MeshParts); the new vignette and edge haze textures show. |
| Pin pull and hold (client bridge `nade`) | The weapon drops out of view; the right hand brings up the RK-5 with its top above the glove; the HUD reads "RK-5 · RELEASE G TO THROW · HOLD RMB: UNDERHAND". |
| Throw | The server took the grenade from the pockets, simulated the path and exploded it after the fuse (`nades`: thrown/exploded counters). |
| Third person | Orbit view of your own character: right hand raised by the head holding the grenade (held grenade 0.18 studs from the hand), rifle lowered. |
| Frag damage | An RK-5 at about 7 studs: one fragment struck the left arm for 23 (heavy bleed, fracture, pain), everything else untouched. Matches the expected 2-3 hits at that range. |
| Stun | A ZS-3 at 8 studs in view: the picture washed out and blurred, then recovered. |
| Smoke | A DS-2 filled the alley with a dense white screen that hides the far end. |
| AI evasion | Two scavs next to a dropped RK-5 ran out of its radius before it went off (no damage). |
| AI flush (`nadeDrill`) | Found by the Foreman or a Watch guard, then hidden behind full cover: the Foreman threw once about 4 s after losing sight; the Watch guard threw twice. Before the fix, units with grenades only in their backpack never threw ("noNade"); AI now use grenades from the backpack and pick a stun charge when the target is too close for a frag. |
| Console | No new errors. The only warning is the Baseplate template texture (203785492). |
