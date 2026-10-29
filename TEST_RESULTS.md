# Test Results

Unless noted otherwise, every test ran in a Roblox Studio playtest with:

- one local client, player "wurdo0"
- an unpublished place, so the in-memory profile store was used
- the `ZR_Dev` and `ZR_ClientDev` bridges plus real mouse and keyboard input through Studio MCP

**NOT VERIFIED:** real DataStore, two or more clients, phone, tablet, console hardware, gamepad UI navigation, device emulator, and performance on devices (only indicative Studio frame rates on the T490 laptop, M12).

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
