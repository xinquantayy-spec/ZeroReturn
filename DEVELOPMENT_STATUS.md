# Zero Return: Development Status

Build `0.1.0-m1`. Last updated 2026-10-28.

Zero Return is an original extraction shooter for Roblox. The core loop is inspired by Tarkov and the camera language by BODYCAM. The map is **Quay 7**, an industrial coastal evacuation zone.

## Phase status

| Phase | State | Notes |
|---|---|---|
| A: Audit | Done | Tools probed. The original kit is preserved at `reference/COLD_SIGNAL_original_kit.zip`. The kit docs are renamed under `docs/kit/`. |
| B: Pipeline smoke test | Done | Rojo 7.7.1 syncs into Studio. Blender builds meshes, which are uploaded through Open Cloud and load in-game. |
| C: Vertical slice | Done | All Definition of Done steps were verified in a Studio playtest (single client, in-memory store). |
| D: Polish | Partly done | Done: Blender meshes (viewmodel, third-person rifle, props), FIELD RECORDER HUD, original audio. Still to do: multi-client, device and performance passes. |
| E: Expansion | Not started | See `NEXT_TASK.md`. |

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
| Exits list | O | D-pad Down | EXIT |
| Inventory | Tab or I | Y | BAG |
| Settings | P | Select | SET |
| Interact | E | X | tap prompt |

## Architecture

- **Server (`src/server`)**
  - Main and Services share one `ctx` table.
  - Services: Remotes, Store, Profiles, Inv, Settle, Assets, World, Chars, Loot, Combat, Extract, AI, Raid, Dev.
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
  - Scriptable first-person camera, procedural viewmodel and animator, IAS input with a CAS fallback, recorder HUD.
  - Custom interaction prompts, grid inventory, deploy, summary, settings and exits screens, touch cluster.
- **Shared (`src/shared`)**: Config, Items, Weapons, Grid, Net, InputMap, Util, AssetIds, AssetMeta, Sounds, Version.
- **Test bridges (Studio only)**
  - `ServerStorage.ZR_Dev` (deploy, tp, loot, kill, extract, rejoin, crash, saveRetry, failWrites, expire, tests, abuse probes).
  - `PlayerScripts.ZR_ClientDev` (fire, reload, inv, look, aim, screens).
  - Neither bridge exists on live servers.

## Key decisions

The full log is in `docs/kit/STATE/DECISIONS.md`.

- **Name:** Zero Return. It was formerly "Escape From Bloxov"; the PC folder name is unchanged.
- **Rojo port:** 34873. Port 34872 belongs to another project.
- **Art:** procedural Blender scripts with vertex colours and no textures, uploaded through Open Cloud. The API key stays in the owner's home folder.
- **Audio:** original synthesised sound effects, plus one ambience track from Roblox's licensed library.
- **Map:** one shared raid world per server. Each player has their own raid session.
