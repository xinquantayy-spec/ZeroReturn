# Test Results

Unless noted otherwise, every test ran in a Roblox Studio playtest with:

- one local client, player "wurdo0"
- an unpublished place, so the in-memory profile store was used
- the `ZR_Dev` and `ZR_ClientDev` bridges plus real mouse and keyboard input through Studio MCP

**NOT VERIFIED:** real DataStore, two or more clients, phone, tablet, console hardware, gamepad UI navigation, device emulator, and performance numbers.

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
