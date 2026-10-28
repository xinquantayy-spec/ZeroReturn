# Zero Return: Development Status

Build `0.3.0-m6`. Last updated 2026-10-28.

Zero Return is an original extraction shooter for Roblox. The core loop is inspired by Tarkov and the camera language by BODYCAM. The map is **Quay 7**, an industrial coastal evacuation zone.

## Phase status

| Phase | State | Notes |
|---|---|---|
| A: Audit | Done | Tools probed. The original kit is preserved at `reference/COLD_SIGNAL_original_kit.zip`. The kit docs are renamed under `docs/kit/`. |
| B: Pipeline smoke test | Done | Rojo 7.7.1 syncs into Studio. Blender builds meshes, which are uploaded through Open Cloud and load in-game. |
| C: Vertical slice | Done | All Definition of Done steps were verified in a Studio playtest (single client, in-memory store). |
| D: Polish | Partly done | Done: Blender meshes (viewmodel, third-person rifle, props), FIELD RECORDER HUD, original audio. Still to do: multi-client, device and performance passes. |
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
| M7 Multiplayer raids | Next | Raid matching on one server (12 players), squads, PvP bodies, player-scav mode, conditional extracts, insurance, longer raids. |
| M8 AI 2.0 | Planned | Scavs, guards, a boss with followers, vision/hearing, cover, waves, friend-foe rules. |
| M9 Economy | Planned | Traders, barter, loyalty, quests, XP/skills, hideout crafting, keys and locked rooms. |
| M10 World | Planned | New POIs and boss compound, doors, loose loot, time of day/weather, audio atlas, Blender weapon/gear art. |
| M11 QA | Planned | Two-client test, device emulation, performance, exploit regression, docs, backup. |

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
  - Services: Remotes, Store, Profiles, Inv, Settle, Assets, World, Chars, Loot, Health, Combat, Extract, AI, Raid, Dev.
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
  - Look: Post (grain, lens, exposure, pain) and Lens (barrel-warped HUD text and icons) drive the recorder HUD.
  - Custom interaction prompts, grid inventory, deploy, summary, settings and exits screens, touch cluster.
- **Shared (`src/shared`)**: Config, Items, Weapons, WeaponModels, RigSpec (generated by `tools/rig_def.py`), RigMath, Grid, Net, InputMap, Util, AssetIds, AssetMeta, Sounds, SoundAtlas (generated), Textures, Version.
- **Test bridges (Studio only)**
  - `ServerStorage.ZR_Dev` (deploy, tp, loot, take, kill, extract, rejoin, crash, saveRetry, failWrites, expire, tests, abuse probes, hp, shootMe, wound, give [slot], weapon).
  - `PlayerScripts.ZR_ClientDev` (state, move, fire, reload, inv, look, aim, switch, cycle, magcheck, light, slash, firemode, stance, lean, tune, pose, orbit [target], screens).
  - Neither bridge exists on live servers.

## Key decisions

The full log is in `docs/kit/STATE/DECISIONS.md`.

- **Name:** Zero Return. It was formerly "Escape From Bloxov"; the PC folder name is unchanged.
- **Rojo port:** 34873. Port 34872 belongs to another project.
- **Art:** procedural Blender scripts with vertex colours and no textures, uploaded through Open Cloud. The API key stays in the owner's home folder.
- **Audio:** original synthesised sound effects, plus one ambience track from Roblox's licensed library.
- **Map:** one shared raid world per server. Each player has their own raid session.
