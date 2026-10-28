# Zero Return: Development Status

Build `0.7.0-m10`. Last updated 2026-10-28.

Zero Return is an original extraction shooter for Roblox. The core loop is inspired by Tarkov and the camera language by BODYCAM. The map is **Quay 7**, an industrial coastal evacuation zone.

## Phase status

| Phase | State | Notes |
|---|---|---|
| A: Audit | Done | Tools probed. The original kit is preserved at `reference/COLD_SIGNAL_original_kit.zip`. The kit docs are renamed under `docs/kit/`. |
| B: Pipeline smoke test | Done | Rojo 7.7.1 syncs into Studio. Blender builds meshes, which are uploaded through Open Cloud and load in-game. |
| C: Vertical slice | Done | All Definition of Done steps were verified in a Studio playtest (single client, in-memory store). |
| D: Polish | Partly done | Done: Blender meshes (viewmodel, third-person rifle, props), FIELD RECORDER HUD, original audio. Still to do: two-client test, device and performance passes. |
| E: Expansion (improvement program M2–M11) | In progress | See the milestone table below and `NEXT_TASK.md`. |

## Improvement program (owner request, 2026-10-28)

Goal: BODYCAM look with an R.E.P.O.-style lens-warped HUD, real-player multiplayer raids with AI scavs, guards and bosses, and Tarkov rules for every mechanic (original names, items, maps and art).

| Milestone | State | Summary |
|---|---|---|
| M2 Look | Done (e1a1686) | Bodycam FOV 85, motion, grain/lens overlays, auto-exposure, REC overlay, lens-warped HUD (Oswald, RGB split, glow, spring pop). |
| M3 Inventory 2.0 | Done (42b1490) | Tarkov slots, nested rig/backpack/secure grids, 10x20 stash, search reveal, found-in-raid, drag and drop, context menu. |
| M4 Health & ballistics | Done (79e505d) | 7 body parts (440 HP), bleeds, fractures, pain, energy/hydration, armor classes/durability/penetration, Tarkov-order meds. |
| M5 Weapons 2.0 | Done | 7 weapons from one shared part-built spec (first and third person), IK arms, slot switching with draw times, auto/semi/pump/bolt, mag and shell-by-shell reloads, mag check, knife, attachments (reflex, 4x scope, suppressors, brake, grip, light), modding in the inventory. |
| M6 Movement & animation | Done | Own operator rig (Blender body, Motor6D skeleton) for players and AI; shared RigMath IK solver drives server hitboxes and client animation (gait, crouch depth, prone, lean, aim pitch, two-hand weapon holds, gestures, ragdoll); Tarkov movement (lean Q/E, prone Z, walk-speed wheel, leg/arm stamina, hold breath, weight, inertia, vault/mantle, free look Alt); procedural sound atlas (footsteps by surface, handling, impacts, bullet cracks). |
| M7 Multiplayer raids | Done | One shared 25-min raid per server (queue → matching → raid, up to 12 operators), PMC late entry for 5 min, player scavs until 6 min left; squads (invite/accept/kick, shared insertion, armband colour, no friendly markers); spread spawns with per-side exfils; bodies that stay in the raid (KIA and disconnects); player-scav mode (free random kit, 10-min cooldown, loot to stash, PMC health untouched); exfil rules (open, paid, key, chance, scav-only); insurance with returns after the raid; larger lens HUD. |
| M8 AI 2.0 | Done | AI scavs (random kits, wander and loiter, waves through the raid), Harbor Watch guards (posts and patrols), the Foreman with two crew at the freight depot (50% of raids, heavy armour, unique loot); awareness-based vision, hearing of footsteps and gunshots, suppression and call-outs; cover points generated from the map with peek-and-hide, crouching at range, strafing, suppressive fire, reloads from real magazines, healing with real meds, searching the last known position, fleeing when out of ammo; player scavs are left alone unless they attack scavs. |
| M9 Economy | Done | Four traders (VOS weapons/ammo, HALE medical/food, TILDA gear, the FENCE) with loyalty levels 1–4 (level + money traded + standing), per-restock stock limits (30 min) and barters; selling to the best-paying trader (examined, empty items only); 13 trader tasks (eliminate, hand in found-in-raid items, extract, visit) with money/XP/standing/item rewards; XP and levels (kills, headshots, looting, examining, survival), the run-through rule, four skills that level with use (endurance, strength, vitality, metabolism); a hideout with five modules built over real time (generator, medstation, workbench, storage racks, water collector) and timed crafts; scav karma (fence prices, scav cooldown, hostile locals); dog tags on PMC bodies; a locked depot office opened with a key that wears out. |
| M10 World | Mostly done | Raid time of day (7x clock, dawn/day/dusk/night) and weather (clear/overcast/fog/rain) with matching light, fog, rain, wind, lamps and night bodycam gain; AI senses follow light and weather and guards use weapon lights at night; a two-storey crew dormitory with locked rooms and a depot vault behind the office (keycard); 56 loose-loot spots; keys; doors that AI open; world and UI sound atlas; bodycam lens v2 (straight HUD, light vignette, soft edge haze, halved grain); rounded first-person arms with gloves; Blender gear meshes (helmet, plate carrier, pouch, pack, body camera, holster) built. Left: upload the gear meshes and check them in Studio (the PC's DNS was failing), Blender weapon meshes. |
| M11 Combat extras | Next | Grenades (frag, stun, smoke; AI throw them), weapon durability and malfunctions with repairs. |
| M12 QA | Planned | Two-client test, device emulation, performance, exploit regression, docs, backup. |

## How a raid works (M7)

1. **Deploy** at the hideout terminal as a **PMC** (your gear) or a **player scav** (free random kit, 10-minute cooldown).
2. If no raid is running, the first deploy starts a **12-second matching** countdown; everyone who deploys meanwhile goes in together. Squad members insert at the same point.
3. The raid lasts **25 minutes** for everyone. PMCs can still join during the **first 5 minutes**, scavs until **6 minutes are left**; otherwise you queue for the next raid.
4. Exfils depend on your insertion side. Some cost money (PIER 3 BOAT, 8,000 MK), need a key (SERVICE SHAFT, office key), may be closed for the whole raid (CRANE YARD LIFT), or are scav-only (STORM CULVERT). Press **O** to see yours.
5. When the clock runs out, anyone still inside is **missing in action**. The raid also ends once nobody is left inside. Bodies and dropped gear are cleared, and **insured** items that nobody extracted come back to their owner 15 minutes later.

## Progression and economy (M9)

- **Traders** (relay radio in the hideout): VOS (weapons, magazines, ammunition, attachments), HALE (medicine and food), TILDA (armour, rigs, packs) and the FENCE (buys anything at a poor rate; sells a few odds and ends, including the office key). Each has loyalty levels 1–4 that need a player level, money traded with them and standing (from tasks). Higher levels unlock better stock and are 5% cheaper per level. Stock is limited per 30-minute restock.
- **Selling:** right-click an item in the stash and choose SELL; the best-paying trader buys it. Items must be examined and containers empty. Quest items, secure containers and the recovery kit cannot be sold.
- **Tasks:** accept them at the trader, progress in raids (kills count even if you die later; extractions; visiting places), hand in **found-in-raid** items and collect the reward (money, XP, standing, items delivered to the stash).
- **XP and skills:** XP for kills (more for headshots, Watch, the Foreman and PMCs), looting, examining and surviving; levels follow Tarkov's curve. Endurance (sprint drain), strength (weight limits), vitality (bleed chance) and metabolism (energy/water drain) level up with use.
- **Run-through:** extracting within 7 minutes with less than 200 raid XP keeps the loot but nothing becomes found-in-raid.
- **Hideout** (workbench terminal): build and upgrade modules with money and items over real time (builds also finish while offline): generator, medstation (hideout healing x2/x4, med crafts), workbench (ammo crafts), storage racks (stash 10x25, 10x30), water collector. Each module runs one craft at a time.
- **Scav karma:** killing local scavs as a player scav lowers karma; extracting as one raises it. High karma shortens the scav cooldown and improves the Fence's prices; below −1 the locals shoot your scav on sight.
- **Dog tags:** a dead PMC's body carries their dog tag (name, level, killer); tags are worth more at higher levels.
- **Keys:** the depot office is locked; the Harbor Office Key opens it for the rest of the raid; each unlock uses up one of its 25 uses.

## Raid world (M10)

- **Time and weather:** every raid rolls a start time and weather; in-world time runs at 7x, so a dusk raid ends in the dark. The deployment terminal shows the next raid's time and weather, and the REC stamp shows the raid clock.
- **Night:** the bodycam's auto-gain lifts the picture with more grain; street lamps switch on; weapon lights matter (and give you away). Guards and the Foreman's crew use theirs at night.
- **Weather:** fog shortens sight for everyone (AI included); rain dulls hearing, wets surfaces and lenses, and brings thunder with lightning in heavy storms.
- **Crew dormitory (Block B):** two storeys of crew rooms off an exterior balcony and stairs. Rooms 104 and 203 are locked (keys from raids or the Fence) and hold better loot.
- **Depot vault:** behind the locked harbor office; the Vault Keycard (10 uses) opens it at the card reader. Two safes, an arms crate and a shelf of valuables.
- **Loose loot:** items lie on desks, shelves, pallets and floors around the map; look at one and press F to take it (found-in-raid if you extract). Unexamined items show as UNKNOWN ITEM.
- **Doors:** AI open unlocked doors on their way; locked doors block AI paths until someone unlocks them; some doors start ajar.

## Definition of Done

All steps below were verified in Studio. Evidence is in `TEST_RESULTS.md`.

| # | Step | Status |
|---|---|---|
| 1 | Enter safehouse | Verified |
| 2 | Equip weapon and gear (stash ⇄ slots, fill magazines, recovery kit) | Verified |
| 3 | Start raid (deploy screen, escrowed loadout) | Verified |
| 4 | Move, aim, shoot, reload | Verified |
| 5 | Fight AI (3 guards: patrol, investigate, engage, search) | Verified |
| 6 | Search container | Verified |
| 7 | Pick up and manage loot | Verified |
| 8 | Navigate to exit (exit list, compass) | Verified |
| 9 | Extract (6 s hold) | Verified |
| 10 | Return with loot saved (simulated rejoin is identical) | Verified |
| – | Die or go MIA and lose at-risk gear | Verified |

## How to run

1. Open a Command Prompt in `Documents\EscapeFromBloxov` and run `rojo serve --port 34873`.
2. In Studio, use a blank Baseplate place (currently Place3). Connect the Rojo plugin to port 34873 and press Play.

Notes:
- Do not connect Rojo to the places that contain the moon project.
- In an unpublished place, profiles use an in-memory store. Studio always uses the separate `DEV_ZR_Profiles_v1` DataStore, never the live store.

## Controls

| Action | Keyboard and mouse | Gamepad | Touch |
|---|---|---|---|
| Fire / Aim | LMB / RMB | R2 / L2 | FIRE / ADS |
| Reload | R | X (an open interaction prompt takes X first) | RLD |
| Sprint / Crouch | Shift / C or Ctrl | L3 / B | RUN / CRCH |
| Heal | H | D-pad Up | MED |
| Fire mode | V | D-pad Right | – |
| Primary / secondary / sidearm / knife | 1 / 2 / 3 / 4 | D-pad Left cycles | SWAP cycles |
| Lean left / right (toggle) | Q / E | LB / RB | LN-L / LN-R |
| Prone | Z | – | PRN |
| Crouch depth / walking speed | C + wheel / wheel | – | – |
| Hold breath (while aiming) | Shift | – | – |
| Vault / mantle | Space at waist- or chest-high cover | A (jump) | jump |
| Free look | hold Alt | – | – |
| Mag check | T | R3 | CHK |
| Weapon light | L | – | – |
| Exits list | O | D-pad Down | EXIT |
| Inventory | Tab or I | Y | BAG |
| Settings | P | Select | SET |
| Interact | F | X | tap prompt |

## Architecture

- **Server (`src/server`)**
  - Main and Services share one `ctx` table.
  - Services: Remotes, Store, Profiles, Inv, Settle, Assets, World, Chars, Loot, Health, Combat, Extract, AI, Raid, Match, Economy, Quests, Hideout, Doors, Dev.
  - Match rolls each raid's environment (shared `Env`); Loot also owns loose loot (spawned per raid from World.looseSpots).
  - AI owns AI units (perception, tactics, weapons) plus the spawn director and the cover-point map; units use the same rig, ballistics, health and loot as players.
  - Match owns the raid cycle (queue, matching, shared clock, entry windows, end conditions), squads, spawn picking and insurance settlement; Raid owns per-player sessions, deploy/enter/finalize and inventory requests.
  - Economy owns traders, selling, XP, skills and karma; Quests owns task state and progress; Hideout owns modules and crafts; Doors owns locked doors and keys.
  - Everything that matters is decided on the server: shots and damage, inventory, loot, extraction, currency and profiles.
- **Persistence**
  - Session-locked profiles (UpdateAsync with a lock that expires after 150 s).
  - Loadouts are held in escrow at deploy and saved before the player spawns.
  - Raids are settled idempotently by raid ID.
  - An unresolved raid on load is settled as a DISCONNECTED loss.
- **Remotes**
  - One RemoteFunction (`Req`) plus Shoot, Act, State, Note and Fx.
  - Every request goes through token buckets, request-ID de-duplication, payload checks and strikes.
- **Client (`src/client`)**
  - Scriptable first-person bodycam camera (eye from the rig pose), Movement (stance, lean, stamina, weight, vault), Weapon (viewmodel from the shared spec, IK arms, optics), Animator (RigMath full-body animation of every operator), IAS input with a CAS fallback.
  - Look: Post (grain, vignette, edge haze, exposure, pain), Atmos (raid lighting, weather, rain, lamps, ambience) and Lens (HUD text and icons, straight by default) drive the recorder look.
  - Custom interaction prompts, grid inventory, deploy, summary, settings and exits screens, trader and hideout terminals (Trade), touch cluster.
- **Shared (`src/shared`)**: Config, Items, Weapons, WeaponModels, RigSpec (generated by `tools/rig_def.py`), RigMath, Grid, Net, InputMap, Util, AssetIds, AssetMeta, Sounds, SoundAtlas (generated), Textures, Version, TraderData, QuestData, HideoutData, Progress.
- **Test bridges (Studio only)**
  - `ServerStorage.ZR_Dev` (deploy [pmc|scav, skips the matching countdown], match, endRaid, expire [shared clock], hold, setExtracts, claimNow, ai, spawnAI, boss [force on/off], god [Studio-only damage immunity], place, tp, loot, take, kill, extract, rejoin, crash, saveRetry, failWrites, tests, abuse probes, hp, shootMe, wound, give [slot], weapon, dispatch [any request through the real dispatcher], xp, money, fir [found-in-raid items to the stash], hideoutNow, econ, contents [container/body], find [item guids]).
  - `PlayerScripts.ZR_ClientDev` (state, move, fire, reload, inv, look, aim, switch, cycle, magcheck, light, slash, firemode, stance, lean, tune, pose, orbit [target], screens).
  - Neither bridge exists on live servers.

## Key decisions

The full log is in `docs/kit/STATE/DECISIONS.md`.

- **Name:** Zero Return. It was formerly "Escape From Bloxov"; the PC folder name is unchanged.
- **Rojo port:** 34873. Port 34872 belongs to another project.
- **Art:** procedural Blender scripts with vertex colours and no textures, uploaded through Open Cloud. The API key stays in the owner's home folder.
- **Audio:** original synthesised sound effects, plus one ambience track from Roblox's licensed library.
- **Map:** one shared raid world per server, one raid at a time (Match). Each player has their own raid session inside it.
- **AI factions:** AI never fight each other (the Watch and the scavs keep a truce, so the map does not empty itself); AI scavs and the Foreman's group ignore player scavs unless provoked; everyone else is a target.
- **AI fairness:** reaction delays (0.45–1.5 s), a zeroing-in penalty for the first seconds of a fight, burst recoil, movement/suppression penalties and no wall-hacks (they see through glass gaps and doorways only).
- **Raid cycle:** 12 s matching, 25 min raids, PMC late entry 5 min (a compromise so nobody waits a full raid), scavs until 6 min left, early end when empty.
- **Squads:** no friendly markers or teammate health (Tarkov); squads wear one armband colour on both arms. The roster shows in the hideout and briefly at insertion or with O.
- **Bodies:** Roblox destroys a character on respawn, so a dead player's body is copied into `workspace.ZR_Corpses` and stays lootable until the raid ends.
- **Economy scope:** traders, barters, tasks, hideout and skills follow Tarkov's rules with original names; no flea market yet (it needs cross-server trading). Trader stock limits are per player per 30-minute restock.
- **Run-through:** 7 minutes / 200 XP (Tarkov uses similar values), so quick dev extractions show the rule.
- **HUD size:** text is authored at 1080p and scales with screen height to the power 0.6 (minimum 0.5), so small windows and phones keep readable numerals; everything stays in the screen margins.
