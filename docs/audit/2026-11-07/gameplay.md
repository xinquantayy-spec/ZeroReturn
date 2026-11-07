# Gameplay audit (area: gameplay)

Audited 2026-11-07 against build `0.9.2-m13` (git `9f8343a` on `main`). Scope: movement, weapon handling, ballistics,
health, raid flow, grenades/mines/tripwires/mounted guns, sound as information, and game feel. Read-only: nothing in
the repo was changed.

Terms used below:
- **Spill**: damage that hits a destroyed ("blacked") limb and spreads to the other body parts.
- **Convergence**: the pull that brings a gun back towards where you aimed after it kicks.
- **Occlusion**: walls, floors and doors muffling a sound between its source and you.
- **FIR**: found in raid. **V-Ex**: a paid car extract.
- **Stud**: Roblox's length unit. This project uses 3.125 studs per metre (`docs/maps/BORDER_YARD.md` line 20).

## Current state

The core loop is built and runs in Studio with one player: deploy from the Relay 7 bunker, a shared raid per server,
fights against AI, looting, an extract with Tarkov's rules, then a raid report and settlement. Most of Tarkov's rules
are present in a simplified form. The numbers are mostly tuned by feel rather than taken from Tarkov's formulas, and
nothing has run with two players, on a phone or on a gamepad (`KNOWN_ISSUES.md` items 2 and 3).

| Sub-area | State | Key files |
|---|---|---|
| Movement | Stand, crouch with depth (C + wheel), prone with a timed change, lean Q/E with a wall check, walk-speed steps, sprint, leg and arm stamina, hold breath, weight limits, inertia, vault and mantle, free look. About 75 % of Tarkov's set. | `src/client/Controllers/Movement.luau`, `Camera.luau`, `src/shared/Config.luau`, `RigMath.luau` |
| Weapon handling | Fire modes, aim speed from ergonomics, spread from MOA, a recoil kick, magazine and shell-by-shell reloads, magazine and chamber checks (estimates), inspect (L), wear, heat and four malfunction types, zeroing, lights and lasers, mastering. About 70 %. | `src/client/Controllers/Weapon.luau`, `src/server/Services/Combat.luau`, `src/shared/Weapons.luau`, `WeaponParts.luau`, `GunBuild.luau` |
| Ballistics | Every bullet flies on the server with gravity and drag; zeroing tilts the bore; glass panes pass bullets. Armour has a class, durability, zones and blunt damage. About 55 %: no plates, no ammo velocity, no fragmentation. | `src/shared/Ballistics.luau`, `src/server/Services/Health.luau` (`armorFor`, `hit`), `src/shared/Items.luau` (`penChance`) |
| Health | Seven parts with Tarkov's 440 HP, light and heavy bleeds, fractures, pain, energy and hydration, timed meds in Tarkov's order, tourniquets for limbs only, surgery, a cultist toxin and its antidote, fall damage. About 65 %: no stims, and out-of-raid recovery is broken (finding 1). | `src/server/Services/Health.luau`, `src/shared/Items.luau`, `src/client/Controllers/Post.luau` |
| Raid flow | Queue, 12 s matching, one shared raid per server, raid time per map, PMC late entry for 5 min, scavs until 6 min are left; extracts: open, paid, key, chance, power, no-backpack, co-op, flare, car, scav-only, PMC-only, plus transits; scav mode and karma; insurance; KIA, MIA, run-through and disconnect outcomes; bodies stay. About 80 %. | `src/server/Services/Match.luau`, `Raid.luau`, `Extract.luau`, `Transit.luau`, `Settle.luau`, `src/shared/Maps.luau` |
| Grenades, mines, tripwires, mounted guns | Frag, stun and smoke grenades simulated on the server; minefields and border snipers; the Forester's tripwires; two mounted guns on Border Yard. Gaps are logged in their design docs. A players' tripwire kit is being built on branch `wip/tripwire-kit` (latest commit 2026-11-07). | `src/server/Services/Grenades.luau`, `Hazards.luau`, `Tripwires.luau`, `Stationary.luau`, `src/shared/Grenades.luau` |
| Sound as information | Footsteps from five surface families, positional legacy `Sound` objects, one reverb for the listener's space, deafness from blasts, headsets. Footsteps, handling and impacts are synthesised placeholders; one recorded gunshot is pitched for every gun; the ambience atlas is silent (`KNOWN_ISSUES.md` item 73). About 40 %. | `src/client/Controllers/Effects.luau`, `Ambience.luau`, `Atmos.luau`, `src/shared/SoundAtlas.luau`, `AmbAtlas.luau` |
| Tests | 341 logic checks (one covers malfunction chances). Studio checks are single-client only. `TEST_RESULTS.md` has no entry for malfunctions, wear or heat. | `src/server/Tests/LogicTests.luau`, `TEST_RESULTS.md` |

**What a new player sees.** They start in the Relay 7 bunker with 250,000 MK and a ready kit: an R-17, a pistol,
class 2 armour, a rig, a bag and basic meds (`Settle.luau` lines 43-81). They walk to the van and deploy. No tutorial
or first-time hint explains checking a magazine, the order to treat wounds, the exits list or found-in-raid. The range
in the bunker is the only practice.

**How it should feel, from the code.** Shooting has a camera kick with a viewmodel kick and roll, impact dust and
sounds, a small muzzle flash, a flinch when hit, and sway that lags behind the mouse. Moving has head bob, landing
dips, breathing, inertia and stamina. Three things will feel unlike Tarkov: recoil climbs without settling (finding
3), every gun sounds like the same recording (finding 11), and other players' footsteps go quiet within 11 to 38 m
(finding 10). No playtest notes about feel were found in the docs.

## Strengths

- **Server authority done right.** Shots, damage, ammo, reloads, meds and extracts are decided on the server. Bullets
  are real projectiles with drop and travel time, flown frame by frame on the server (`Ballistics.luau` lines 147-179).
- **Tarkov's information rules.** No crosshair, hit sound or ammo counter by default (`Settings.luau` lines 10-11);
  magazine checks give estimates (`Combat.luau` lines 583-599); a malfunction must be found with L before Shift+T
  clears it (`Combat.luau` lines 155-207).
- **Malfunctions match the wiki closely.** No mechanical malfunctions above 93 % condition, feed failures from big
  magazines, hard jams only at 5 % or less, heat that raises the chance and jams the bolt at maximum
  (`Combat.luau` lines 120-148).
- **The health model has Tarkov's bones.** 440 HP over seven parts, death at a destroyed head or thorax, spill over the
  living parts, bleeds and fractures treated before HP, tourniquets for limbs only (`Health.luau` lines 17-27, 166-194,
  520-560).
- **The run-through rule is exactly Tarkov's.** Extract before 7 minutes with under 200 raid XP and nothing becomes FIR
  (`Progress.luau` line 31, `Raid.luau` line 427), matching the wiki's "200 EXP or 7 minutes".
- **Rich extract rules,** each walked and checked in Studio on both real-scale maps (`TEST_RESULTS.md` "Border Yard exit
  walk-through", "Meridian exit walk-through").
- **A full movement set** with stance depth, leaning blocked by walls, inertia and arm stamina, all fed to server hit
  boxes through the shared `RigMath`.
- **Cross-platform from the start.** Nearly every action has a gamepad and touch way.

## Findings

Ranked by severity, then by impact.

### P1

1. **P1 - Hideout recovery is thrown away: survivors start the next raid with their old wounds, energy and water.**
   The profile's health is written only at the end of a raid. In the bunker the character heals at 0.6 HP a second per
   part, but that state is never saved, and the raid character is rebuilt from the saved post-raid values. A player
   who extracted with a blacked arm at 5 energy starts every later raid that way until they die. The HEALTH tab even
   says "every body part is at full health" out of raid.
   Evidence: `src/server/Services/Raid.luau` lines 418-425 (the only writes to `prof.health`);
   `src/server/Services/Chars.luau` lines 553 and 570-578 (`LoadCharacter`, then `saved = prof.health`);
   `src/server/Services/Health.luau` lines 794-805 (bunker healing, never saved);
   `src/client/Controllers/Character.luau` line 34.

2. **P1 - Sound goes through walls and floors unmuffled, and the docs call the fix impossible.** Tarkov checks for
   obstruction between you and each sound and models sound through floors, stairways and walls of different thickness
   (0.16.7.0). This game uses legacy `Sound` objects with distance fall-off only, so a shot upstairs sounds the same as
   one in your room. `EFT_PARITY.md` says per-source occlusion "cannot be done in Roblox (exception 3)", but Roblox
   released Acoustic Simulation (occlusion, diffraction, reverb from geometry) on 22 September 2026. It needs the newer
   Audio API (`AudioPlayer`, `AudioEmitter`, `AudioListener`).
   Evidence: `docs/design/EFT_PARITY.md` lines 114 and 219-221; `src/client/Controllers/Effects.luau` lines 73-105 and
   129-183 (legacy `Sound`).

3. **P1 - Recoil never settles or returns to the aim point.** Each shot moves the aim up permanently by 60 % of the kick;
   only 40 % springs back. An R-17 burst while aiming climbs about 0.45 degrees a shot without end, so a 25-round
   magazine climbs about 11 degrees unless the player pulls down. Tarkov's recoil has a climb angle, a random spread
   around it, and convergence that returns the gun to where you aimed; in full auto the climb levels off. This is the
   main thing that makes shooting feel like Tarkov.
   Evidence: `src/client/Controllers/Camera.luau` lines 34-39 and 158-160; `src/client/Controllers/Weapon.luau`
   lines 804-811.

4. **P1 - Armour is pre-0.14 Tarkov.** Since 0.14 Tarkov armour is soft armour (class 3 at most on its own) plus hard
   plates in front, back and side slots, each with its own class and durability, protecting only what it covers
   (throat, groin, shoulders, sides). Helmets have five zones (top, nape, ears, eyes, jaws). Here each vest has one class
   for thorax, stomach and sometimes arms; a helmet protects a hit by a dice roll (coverage + 30 %); penetration is a
   straight-line stand-in; a penetrating round loses 4-24 % damage where Tarkov's lose 0-40 %.
   Evidence: `src/shared/Items.luau` lines 78-91 and 381-384; `src/server/Services/Health.luau` lines 222-230
   and 288-290.

5. **P1 - Key sound cues are silent.** The ambience atlas loads as 0.0 s long, so breaking glass, the airdrop plane, the
   mall's room tone and the scripted distant shots never play. Breaking glass is a gameplay cue (someone is coming in).
   Fixing it needs the owner's upload key.
   Evidence: `KNOWN_ISSUES.md` item 73; `src/client/Controllers/Effects.luau` lines 120-123.

6. **P1 - The player-versus-player core has never run with two players.** Player hits and kill credit, the co-op exits,
   the car's shared countdown and squads are covered only by logic tests with stand-ins.
   Evidence: `KNOWN_ISSUES.md` item 2; `TEST_RESULTS.md` line 9 ("NOT VERIFIED: ... two or more clients").

### P2

7. **P2 - Damage at range ignores the bullet's real speed.** The flight code passes the bullet's remaining speed to the
   hit handler, which throws it away and applies a straight-line fall-off by weapon range instead. Ammo has no muzzle
   velocity or drag of its own; drag is set per weapon class. In Tarkov a "velocity factor" from the bullet's speed
   scales both damage and penetration, and each round has its own speed and ballistic coefficient.
   Evidence: `src/shared/Ballistics.luau` lines 12, 29-35 and 163; `src/server/Services/Combat.luau` lines 340 and
   350-356.

8. **P2 - Fragmentation is shown but never applied.** INSPECT lists FRAGMENTATION CHANCE for every round, and hollow
   points carry 45-100 %, but no damage code reads it. Tarkov: rounds with 20 or more penetration can fragment for 50 %
   extra damage to the part hit.
   Evidence: `src/shared/Items.luau` lines 63-75; `src/client/Controllers/Inspect.luau` line 101;
   `src/server/Services/Combat.luau` lines 355-359.

9. **P2 - Spill damage is about 43 % harsher than Tarkov's.** Damage to a destroyed arm, leg or stomach spreads at
   x0.7, x1.0 and x1.5. The wiki's Health system page lists x0.49, x0.7 and x1.05. Limb hits kill faster than in
   Tarkov.
   Evidence: `src/server/Services/Health.luau` line 27.

10. **P2 - Footsteps carry about a third of Tarkov's distance.** Other players' steps fade out by about 35 studs when
    crouch-walking and 118 studs when sprinting (11 to 38 m; 1.3 times that with a headset). After Tarkov 0.14.5.5,
    crouch-walking was measured audible at 43 m and sprinting from over 100 m.
    Evidence: `src/client/Controllers/Effects.luau` line 327; `src/client/Controllers/Animator.luau` line 132.

11. **P2 - Gunshots fade early and every gun shares one recording.** A shot plays with inverse fall-off from 12 studs:
    about 12 % volume at 32 m, 4 % at 96 m, and nothing past 192 m. Every gun is the same recorded rifle shot at a
    different pitch, with one "far" variant and no indoor or outdoor tail, so players cannot tell guns or fight
    distance apart by ear. (How far Tarkov's shots carry was not verified.)
    Evidence: `src/client/Controllers/Effects.luau` lines 73-83 and 343-364; `KNOWN_ISSUES.md` item 7.

12. **P2 - Missing Tarkov handling and movement actions.** No weapon mounting on cover and no bipods (0.15: less recoil,
    sway and stamina use), no quick reload (double R drops the magazine; here the magazine drops only when there is no
    room), no side step, slow lean or blind fire.
    Evidence: `docs/design/EFT_PARITY.md` line 88; `src/server/Services/Combat.luau` lines 490-500; no mount or bipod
    code anywhere in `src`.

13. **P2 - The health layer is thin.** No stims (Tarkov injectors give timed buffs with side effects, for example SJ6:
    +30 maximum stamina for 240 s, then hand tremor and tunnel vision). A broken leg slows you by 14 % (6 % on
    painkillers) where the wiki lists 45 %; a broken arm only slows reloads, where Tarkov also slows aiming, drawing
    and searching. A destroyed stomach does not speed up energy and water loss (Tarkov: five times).
    Evidence: `src/shared/Items.luau` lines 142-153; `src/server/Services/Health.luau` lines 344-368 and 784-793.

14. **P2 - Out-of-raid health departs from Tarkov.** After death or MIA the PMC comes back at full health; Tarkov sets 30 %
    and regenerates 7.61 HP a minute plus 1 energy and 1 hydration a minute, with paid healing at the Therapist after the
    raid. Here the bunker heals about 33 times faster (when it works, see finding 1) and no trader heals.
    Evidence: `src/server/Services/Raid.luau` lines 421-424; `src/server/Services/Health.luau` lines 796-805;
    `src/shared/TraderData.luau` (no healing service).

15. **P2 - Malfunctions are built, but the docs say they are not, and they were never checked in Studio.** The status
    table, the next-task list, the modding doc and the parity file all list "M11 part B" as to do. The wiki rules it still
    lacks: maximum durability falling while hot, a changed fire rate and cook-offs at severe heat, a screen flash on a
    malfunction, malfunction chance per round, and the 5 s quick swap to the secondary weapon after a jam.
    Evidence: `src/server/Services/Combat.luau` lines 120-148 and 290-311; `DEVELOPMENT_STATUS.md` line 34;
    `NEXT_TASK.md` line 117; `docs/weapons/WEAPON_MODDING.md` line 208; `docs/design/EFT_PARITY.md` line 242;
    no malfunction entry in `TEST_RESULTS.md`.

16. **P2 - Core gameplay parity is not logged.** `EFT_PARITY.md` says it covers "the parts that are not core gameplay".
    Project rule 2 asks for every gap to be logged there, so the gaps in this report have no home.
    Evidence: `docs/design/EFT_PARITY.md` lines 5-6.

17. **P2 - Stamina misses Tarkov's 0.12.4 rules.** Stance changes cost no leg stamina, an empty arm-stamina bar does not
    start draining the legs, there is no fatigue for staying low too long, and carrying too much does not make you
    louder.
    Evidence: `src/client/Controllers/Movement.luau` lines 62-78 and 273-295; `src/client/Controllers/Effects.luau`
    lines 306-331.

### P3

18. **P3 - The death screen shows kill distances 12 % short.** It converts at 0.28 m per stud; the project's scale is
    0.32 (INSPECT uses 0.32). Evidence: `src/server/Services/Raid.luau` line 566;
    `src/client/Controllers/Inspect.luau` line 22.
19. **P3 - Perception and Covert Movement do not change what players hear.** Perception promises "you hear footsteps from
    further away" but nothing reads it; Covert only lowers what the AI hears. Evidence: `src/shared/Progress.luau`
    lines 47 and 52; `src/server/Services/AI.luau` line 428; `src/client/Controllers/Effects.luau` lines 306-331.
20. **P3 - The VOLT drink promises a stamina boost that does nothing.** Evidence: `src/shared/Items.luau` line 157;
    `src/server/Services/Health.luau` lines 466-472.
21. **P3 - Subsonic rounds still crack past your head.** The shot effect carries no subsonic flag.
    Evidence: `src/client/Controllers/Effects.luau` lines 455-467; `src/server/Services/Combat.luau` line 373.
22. **P3 - Fake distant gunfire.** A shot plays every 40 to 120 s, 200 to 320 studs away, tied to no one. In Tarkov a far
    shot means a real fight. Evidence: `src/client/Controllers/Ambience.luau` lines 456-468.
23. **P3 - Grenades fall under a different gravity** (45 studs/s squared) than bullets (30.7, real gravity at this
    scale). Evidence: `src/shared/Grenades.luau` line 7; `src/shared/Ballistics.luau` line 11.
24. **P3 - Smelter raids last 15 minutes;** Tarkov's Factory lasts 20. Evidence: `src/shared/Maps.luau` line 28.
25. **P3 - Ergonomics does not affect aiming stamina** (the wiki says it does); only weapon weight does.
    Evidence: `src/client/Controllers/Movement.luau` lines 283-286.
26. **P3 - Five footstep surfaces.** Snow plays dirt steps (seasons add snow); no water, tile, carpet or glass-shard steps.
    Evidence: `src/client/Controllers/Effects.luau` lines 293-301.
27. **P3 - Prone keeps the upright collision box,** so you cannot crawl under low cover. Evidence: `KNOWN_ISSUES.md`
    item 10.
28. **P3 - No separate chamber round.** Tarkov guns hold one round in the chamber (30 + 1); here the chamber check reads
    the magazine count. Evidence: `src/server/Services/Combat.luau` lines 628-631.
29. **P3 - One table of med costs for every kit and one surgery kit.** Tarkov's kits each have their own bleed and fracture
    costs, and two surgery kits (CMS leaves 25-45 % of maximum, Surv12 60-72 %). Evidence:
    `src/server/Services/Health.luau` lines 34 and 515.

## Gaps vs EFT

| EFT feature | Ours | Gap |
|---|---|---|
| Recoil with angle, dispersion and convergence; climb settles in full auto | Kick; 60 % of it is permanent climb | Large |
| Ergonomics sets aim speed, sway and aiming stamina | Aim speed and sway only | Small |
| Weapon mounting on cover (V) and bipods (Ctrl+V) | None | Missing |
| Quick reload (double R drops the magazine) | Drops only when there is no room | Missing |
| Slow lean, side step, blind fire | None | Missing |
| Round in the chamber (30 + 1) | No chamber round | Partial |
| Malfunctions: four types, inspect to identify, 93 % threshold | Same | None |
| Overheating: four stages, cook-offs, fire-rate change, maximum durability loss | Stages 1, 2 and 4 only | Partial |
| Ammo with its own speed and ballistic coefficient; velocity factor on damage and penetration | Speed per gun, drag per gun class, fall-off by range | Large |
| Fragmentation (penetration 20 and up, +50 % damage) | Shown, not applied | Missing |
| Soft armour plus plates in front, back and side slots; protection by zone | One class per vest | Large |
| Helmet zones: top, nape, ears, eyes, jaws | Dice roll, plus face and eyes bands | Large |
| Ricochet off helmets by angle | Dice roll on helmets only | Partial |
| Shooting through thin walls and surface ricochets (unverified) | Only glass passes bullets | Unknown |
| 440 HP over seven parts; death at head or thorax | Same | None |
| Spill x0.49 arms, x0.7 legs, x1.05 stomach | x0.7, x1.0, x1.5 | Numbers |
| Fracture penalties (leg -45 %; arms slow aiming, drawing, searching) | Leg -14 %; arms slow reloads | Weak |
| Stims with buffs and side effects | None | Missing |
| Destroyed stomach: energy and water loss x5 | Not modelled | Missing |
| After death or MIA: 30 % health, 7.61 HP a minute, paid Therapist healing | Full health; fast bunker healing that is not saved | Large |
| Run-through: 200 XP or 7 minutes | Same | None |
| Raid time: Customs 40, Interchange 40, Factory 20 minutes | 40, 40, Smelter 15 | Small |
| PMCs only spawn at raid start | PMCs may join for 5 minutes | Compromise |
| Insurance: Prapor 24-36 h, Therapist 12-24 h, held 4-6 days | One insurer, 15 minutes, kept until collected | Compromise |
| Scav cooldown about 25 minutes base (unofficial planning figure) | 10 minutes | Compromise |
| Extract types (open, chance, paid, car, co-op, flare, scav-only, transit) | All present | None |
| Car extract paid in roubles you carry (unverified) | Paid from stash money | Unverified |
| Transits open 7 minutes in (0.15 notes) | 60 s (SPT data) | Sources disagree |
| Tutorial for new players (1.0) | None | Missing |
| Players' tripwire kit (0.15) | In progress on `wip/tripwire-kit` | In progress |
| Sound occlusion through walls, floors and stairways | None (Roblox now offers it) | Large |
| Footsteps: crouch-walk about 43 m, sprint over 100 m | About 11 m and 38 m | Large |
| Each gun its own sound; real distant fights | One recording; scripted fake far shots | Large |
| Stance changes cost leg stamina; fatigue; overweight is louder | None of these | Missing |
| Headsets with their own compression | One shared headset rule | Partial |

## Decisions

### gameplay-1: Recoil model
**Question:** Should recoil copy Tarkov's model (a climb that levels off and returns to the aim point), or keep
today's kick that the player must pull down?
**Context:** Today 60 % of each kick moves the aim for good, so a long burst climbs without limit. Tarkov's recoil
has a set climb angle, a random spread around it and convergence that pulls the gun back; in full auto it levels off.
This decides how shooting feels more than anything else.

| Option | What gets built | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. Tarkov model | Convergence per gun, a climb angle with dispersion, camera recoil separate from gun recoil, all scaled by the build's recoil and ergonomics and the weapon skills; values set against each gun's Tarkov counterpart | M | none | close |
| b. Plateau and partial return | Keep the kick; cap the climb after a few shots and return most of it after the burst | S | none | partial |
| c. Keep and tune | Only change the numbers | S | none | departure |

**Recommended: a.** The biggest gain in feel and parity, at no frame cost.

### gameplay-2: Armour system
**Question:** Should armour move to Tarkov's current plates-and-zones system?
**Context:** Since 0.14 Tarkov armour is soft armour plus separate plates, each piece with its own class and durability,
protecting only the zones it covers; helmets have five zones. Ours is one class per vest and a dice roll for helmets,
with a straight-line penetration stand-in. Armour drives what players loot, buy and fear.

| Option | What gets built | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. Full plate system | Plate items and plate slots in carriers and rigs; soft-armour zones including throat, groin, sides and back; helmet zones from where the hit lands; Tarkov's penetration and damage-loss curves; INSPECT, traders, loot and AI kits updated; new plate art | L | low | close |
| b. Zones and curves only | One item per vest, but a class per zone, helmet zones from where the hit lands, Tarkov's curves; no plate items | M | none | partial |
| c. Keep, fix helmets | Keep today's model; replace the helmet dice roll with zones | S | none | departure |

**Recommended: a.** Plates are central to Tarkov 1.0's loot and economy, and doing b first would mean building armour twice.

### gameplay-3: Sound occlusion
**Question:** Should world sounds move to Roblox's Audio API so walls, floors and doors muffle them as in Tarkov?
**Context:** Roblox's Acoustic Simulation (occlusion, sound bending round corners, reverb from the geometry) left beta on
22 September 2026. It only works with `AudioPlayer` and `AudioEmitter`, not the legacy `Sound` this game uses, and it
lowers its own accuracy to protect the frame rate. Sound is how Tarkov players find people.

| Option | What gets built | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. Acoustic Simulation | Move `Effects` and `Ambience` to the Audio API, turn on `SoundService.AcousticSimulationEnabled`, set density and absorption on map parts and kit colliders, keep it off on POTATO if phones need it | L | med | close |
| b. Scripted occlusion | Keep legacy sounds; a few times a second cast a ray from the listener to each loud source (shots, steps, blasts), muffle with an equaliser and lower the volume per wall; cap at the 8 loudest | M | low | partial |
| c. Keep | Listener reverb only | S | none | departure |

**Recommended: a,** piloted on one map with b as the fallback for low-end phones. It is the only route to Tarkov-like
sound through walls and round corners, and Roblox scales its cost.

### gameplay-4: Health and meds depth
**Question:** How much of Tarkov's wider health layer should be built: stims, stronger fractures, the stomach rule?
**Context:** Tarkov has stim injectors with timed buffs and side effects, fractures that cut a leg's speed by 45 % and
slow aiming and searching, and a destroyed stomach that drains energy and water five times faster. Ours has no stims
and much milder fractures. New items also need Blender art and the owner's upload key.

| Option | What gets built | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. Full layer | A buff and side-effect system, 6 to 10 original stims, Tarkov's fracture penalties, the stomach rule, per-kit bleed costs, two surgery kits | L | low | close |
| b. Core set | The buff system with 3 or 4 stims (stamina, regeneration with painkiller, anti-bleed), Tarkov's fracture penalties and the stomach rule | M | low | partial |
| c. Numbers only | No stims; set fracture penalties and the stomach rule to Tarkov's | S | none | partial |

**Recommended: b.** It brings the main Tarkov effects quickly; the rest of the stims can follow the art pipeline.

### gameplay-5: Movement and handling extras
**Question:** Which missing Tarkov actions should be built, knowing each also needs a touch and a gamepad version?
**Context:** Missing: weapon mounting and bipods, quick reload, slow lean, side step, blind fire, stance changes that cost
stamina, louder movement when overweight. Every new action takes a button or gesture on phones and gamepads.

| Option | What gets built | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. All of them | Every action above, with touch and gamepad versions | L | low | close |
| b. High-value set | Quick reload, mounting on cover plus bipod parts, slow lean, stance stamina and overweight noise; no blind fire or side step | M | low | partial |
| c. None now | Keep today's set | S | none | departure |

**Recommended: b.** These change fights the most; blind fire and side step cost the most screen space for the least play.

### gameplay-6: Real-time waits
**Question:** Should insurance returns, the scav cooldown and out-of-raid recovery use Tarkov's real-world times or
shorter times that fit Roblox sessions?
**Context:** Tarkov returns insurance after 12-36 hours and holds it 4-6 days; the scav cooldown is about 25 minutes;
after death or MIA health is 30 % and regenerates 7.61 HP a minute, with paid Therapist healing. Ours: 15 minutes, 10
minutes, full health after death, fast bunker healing (currently not saved, finding 1).

| Option | What gets built | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. Tarkov's times | The real timers, two insurers, a post-raid healing screen at HALE | M | none | exact |
| b. Tarkov's rules, scaled times | The same rules with times divided by one constant (for example insurance 1-3 h held 1 day, scav 15 min, 30 % health after death regenerating 4 times faster), paid healing at HALE | M | none | close |
| c. Keep | Today's timers and full heal after death | S | none | departure |

**Recommended: b.** Every Tarkov rule and choice stays, and one constant fits it to Roblox's shorter play sessions.

### gameplay-7: Raid instances
**Question:** Should each raid run on its own server, as Tarkov's matchmaking does, or stay one shared raid per server
with late entry?
**Context:** One server runs one raid at a time for up to 12 players. PMCs may join for 5 minutes after the start, which
Tarkov never allows, and anyone who misses that waits up to 40 minutes. Roblox reserved servers can start a fresh raid
per match from the bunker. This needs a published place (the owner's call under rule 3).

| Option | What gets built | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. A server per raid | The bunker queues and matches by map, teleports the group to a fresh raid server and brings them back; no PMC late entry; scavs join running raids | L | none | exact |
| b. Shorter wait | Keep one raid per server; shorten late entry to 2 minutes and add an any-map queue | S | none | partial |
| c. Keep | 5-minute late entry | S | none | partial |

**Recommended: a.** It removes the late-entry compromise and lets several raids and maps run at once.

### gameplay-8: New-player onboarding
**Question:** Should Zero Return add a first-time tutorial like Tarkov 1.0's?
**Context:** Tarkov 1.0 (15 November 2025) added a tutorial covering healing, the inventory and weapon handling, plus
progression guides. Ours drops a new player in the bunker with no explanation of magazine checks, wound order, the exits
list or found-in-raid.

| Option | What gets built | Effort | Mobile perf | Parity |
|---|---|---|---|---|
| a. Guided first raid | A short, skippable scripted run (a quiet part of Smelter or the range) teaching movement, the magazine check, treating a bleed, looting, the exits list and extracting, then the bunker stations; touch and gamepad prompts | M | low | close |
| b. First-time hints | One-time prompts at the van, the first bleed, the first malfunction, the first extract | S | none | partial |
| c. None | As now | S | none | departure |

**Recommended: a,** with b's hints added. It is 1.0 parity, and lost Roblox players leave within minutes.

## Quick wins

No decision needed; each is about a day or less.
1. Save bunker recovery: write the safehouse health to the profile before deploy and when it changes, and correct the
   HEALTH tab text (`Raid.luau` 418-425, `Chars.luau` 574, `Character.luau` 34).
2. Scale damage and penetration by the bullet's remaining speed, which `Ballistics.fly` already passes
   (`Combat.luau` line 340).
3. Apply fragmentation: rounds with penetration 20 or more roll the round's chance for +50 % damage to the part hit.
4. Set spill to x0.49 arms, x0.7 legs and x1.05 stomach (`Health.luau` line 27).
5. Lengthen footstep range to Tarkov's measured figures: about 43 m (134 studs) for slow crouch-walking and over 100 m
   (312 studs) for sprinting (`Effects.luau` line 327).
6. Death screen: convert at 0.32 m per stud (`Raid.luau` line 566).
7. Send the round's subsonic flag with the shot effect and skip the crack for subsonic rounds.
8. Make the VOLT drink's stamina boost work, or remove it from the description.
9. Make Perception lengthen hearing of others' steps and Covert Movement quieten your steps for other players.
10. Add ergonomics to the aiming-stamina drain (`Movement.luau` lines 283-286).
11. Add the missing malfunction rules from the wiki: maximum durability loss while hot, fire-rate change and cook-offs at
    severe heat, a malfunction flash, malfunction chance per round, the 5 s secondary swap after a jam.
12. Docs: mark M11 part B as built (`DEVELOPMENT_STATUS.md` line 34, `NEXT_TASK.md` line 117,
    `docs/weapons/WEAPON_MODDING.md` line 208, `EFT_PARITY.md` line 242); add a core-gameplay section to `EFT_PARITY.md`
    with this report's gap table; run and log a Studio malfunction check.
13. Remove the scripted distant gunfire, or play it only for real shots beyond normal hearing range.
14. Put grenades under the world's gravity (30.7 studs/s squared) and re-tune the throw speed to keep the same reach.
15. Set Smelter's raid to 20 minutes if it stands in for Factory (`Maps.luau` line 28).
16. Add footstep families for snow, water, tile and metal stairs (snow already exists through the seasons).
17. Owner action: re-upload `ZR_SFX_Amb` and set `Sounds.AMB_ATLAS` (`KNOWN_ISSUES.md` item 73).

## Sources

EFT facts used, with what each supports:
- tarkov-ballistics.com book: velocity factor scales damage and penetration; fragmentation needs 20 penetration and adds
  50 % - https://book.tarkov-ballistics.com/print.html
- eft-ammo.com: damage loss through armour 0-40 %, material destructibility, five helmet zones, helmet ricochet by angle -
  https://eft-ammo.com/armor-and-penetration
- GGRecon (0.14.11): soft armour plus plates, plate slots, protection by zone -
  https://ggrecon.com/guides/escape-from-tarkov-best-armour-armour-hitboxes
- EFT Wiki, Health system: spill x0.49 / x0.7 / x1.05, fracture penalties, surgery kits, 456.6 HP an hour out of raid,
  30 % after death or MIA, Therapist prices - https://escapefromtarkov.fandom.com/wiki/Health_system
- EFT Wiki, Weapon malfunctions: types, inspect then Shift+T, 93 %, hard jams at 5 %, heat stages, secondary swap buff -
  https://escapefromtarkov.fandom.com/wiki/Weapon_malfunctions
- EFT Wiki, Performance modifiers: what ergonomics does - https://escapefromtarkov.fandom.com/wiki/Performance_modifiers
- EFT Wiki, Strength: +30 % carry weight at elite, sprint and jump bonuses - https://escapefromtarkov.fandom.com/wiki/Strength
- EFT Wiki, Found in raid: run-through is 200 XP or 7 minutes - https://escapefromtarkov.fandom.com/wiki/Found_in_raid
- CPG, damage spread over non-destroyed limbs (2021) -
  https://consolepcgaming.com/escape-from-tarkov-latest-patch-introduces-damage-distribution-mechanic-blacked-out-limbs
- CPG, 0.15 patch notes: weapon mounting, bipods, tripwire kit, transits after 7 minutes, occlusion and headset work,
  hidden PMC karma - https://consolepcgaming.com/escape-from-tarkov-0-15-patch-notes
- Sportskeeda, 0.16.7.0: occlusion checks, sound through floors, stairways and walls -
  https://www.sportskeeda.com/esports/escape-tarkov-patch-notes-0-16-7-0-all-major-changes-audio-updates
- Mein-MMO (0.14.5.5): crouch-walk heard at 43 m, sprint over 100 m -
  https://mein-mmo.de/en/all-shooter-players-want-better-sound-but-in-escape-from-tarkov-it-is-now-too-good,1115647
- Roblox DevForum, Acoustic Simulation (beta 28 January 2026, full release 22 September 2026) -
  https://devforum.roblox.com/t/full-release-acoustic-simulation-emit-audio-with-presence/4307121
- VK "Tarkovskoe Metadvizhenie" (13 March 2023): recoil angle, dispersion, convergence, camera recoil -
  https://m.vk.ru/@metadvijenie-otdacha-v-eft
- SPT Forge, Fontaine's Recoil Overhaul: vanilla auto-compensation and muzzle rise that settles -
  https://forge.sp-tarkov.com/mod/718/fontaines-recoil-overhaul
- CPG, recoil rework tested on the test server (November 2023) -
  https://consolepcgaming.com/escape-from-tarkov-introduces-reworked-recoil-system-in-latest-ets-phase
- Dexerto, 0.12.4: stamina split, stance changes use leg stamina, fatigue, overweight noise -
  https://www.dexerto.com/escape-from-tarkov/escape-from-tarkov-update-0-12-4-patch-notes-overweight-system-more-1340788/
- Fan controls sheet (2020): quick reload with double R, slow lean, side step -
  https://gist.github.com/xXPhenomXx/f6fce8b49b247a1c3fc6e9c9511e8c4b
- Prima Games controls: blind fire, side step, drop backpack - https://primagames.com/tips/escape-from-tarkov-complete-controls-guide
- TarkovForge: Factory 20 minutes - https://tarkovforge.com/map-guide/factory ; Interchange 40 minutes -
  https://tarkovforge.com/map-guide/interchange
- West Games: scav cooldown 25 minute planning baseline (not official) - https://west-games.com/scav-cooldown-calculator/
- eft-ammo.com insurance guide: Prapor 24-36 h, Therapist 12-24 h, held 4 and 6 days -
  https://www.eft-ammo.com/wiki/escape-from-tarkov-insurance-guide
- TarkovForge, SJ6 stim: buffs and side effects - https://tarkovforge.com/meds/sj6-tglabs-combat-stimulant-injector
- Multiplayer.it: tutorial added with 1.0 on 15 November 2025 -
  https://multiplayer.it/notizie/escape-from-tarkov-tutorial-aiutare-chi-abbandona-gioco-subito.html
- GameLeap, patch 1.3.0.0 (29 October 2026): longer life for players' tripwires; no core changes -
  https://www.gameleap.com/articles/escape-from-tarkov-1-3-0-0-patch-notes-all-changes
- GGRecon: car extracts take roubles and leave after about a minute -
  https://www.ggrecon.com/guides/escape-from-tarkov-how-to-extract/

Unverified (no source confirmed them): Tarkov's walk and sprint speeds, stamina numbers, weight thresholds, bleed rates,
energy and water drain in raid, how far gunshots carry, shooting through walls and surface ricochets, mine damage,
whether the car fare must be carried as cash, and whether MIA returns insured items (sources disagree).

Blocked or failed during research:
- https://raw.githubusercontent.com/sp-tarkov/server/master/project/assets/database/globals.json (the permission request
  was not answered; it would have given exact stamina, bleed and drain numbers).
- The Guild Order audio guide and the PCGamesN audio overhaul article cited in `EFT_PARITY.md` (blocked: not opened).
- EFT Wiki "Recoil" and "Endurance" pages, and BoostMatch's 1.1 insurance guide (site errors).
