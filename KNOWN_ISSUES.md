# Known Issues

## Open

1. **The real DataStore has not been exercised.**
   - The Studio place is unpublished, so profiles fall back to the in-memory store.
   - To test real persistence:
     1. Save the place to Roblox as a **private** place. This is the owner's decision.
     2. Turn on *Game Settings → Security → Enable Studio Access to API Services*.
     3. Re-run the persistence probes: rejoin, failWrites, crash recovery.
   - Studio uses `DEV_ZR_Profiles_v1`, never the live store.
2. **Multi-client is untested.** Squads (invites, shared insertion, armbands), player-vs-player hits and kill credit, two players contesting loot, late-join spawn distance and simultaneous extractions are implemented and covered by logic tests, but need a Studio *Clients and Servers* test (2–3 clients). The MCP tools can only drive one client.
3. **No hardware testing.** Phone, tablet and console have not been tested on real devices or the emulator.
   - The touch layout, safe areas and gamepad UI navigation are implemented but **not verified**.
   - The gamepad X conflict (reload vs. prompt) was fixed in code but has not been tested on a real pad.
4. **Performance has not been measured.** Not yet profiled: frame time, memory, network, and the cost of AI running at 5 Hz.
5. **Asset ownership.**
   - The meshes and audio belong to the owner's user account (5437527887).
   - If the game is ever published under a group, they must be re-uploaded to the group and `AssetIds.luau` / `Sounds.luau` updated. InsertService and private audio need matching owners.
6. **Audio upload quota.** Accounts without ID verification can upload about 10 audio assets per month; 7 were used by 2026-10-28 (the sound atlas packs 52 effects into one upload, so short effects no longer cost quota).
7. **Synthesised sound.** Footsteps, handling, impacts and cracks come from the procedural atlas (`synth_atlas.py`); they are functional placeholders until recorded or licensed sounds replace them.
8. **The name "Zero Return" has not been checked** for collisions or trademarks before a public release.
9. **The PC folder is still called `EscapeFromBloxov`.** Renaming it means restarting `rojo serve` from the new path.

10. **Prone keeps the upright collision box.** The humanoid root stays upright when prone (the body lies flat visually and as a hitbox), so you cannot crawl under objects lower than about 3 studs.
11. **Weapons are part-built.** All weapons and attachments use the shared `WeaponModels` spec (consistent first and third person). The earlier R17 Blender viewmodel mesh is retired; M10 re-authors weapon meshes in Blender against the same anchors.
12. **Inventory on short windows.** With a viewport shorter than about 600 px, the lower equipment slots (primary, holster, secondary) slide under the detail strip. Needs a scrollable gear column (M11).
13. **Movement extras not yet verified on devices.** Lean, prone and crouch-depth have touch buttons and gamepad shoulder buttons only for lean; free look (Alt) and hold breath (Shift while aiming) are keyboard-only so far.
14. **Third-person mesh art.** The operator body is a first Blender pass (segment meshes, vertex colours); gear (vests, helmets, packs) is still part-built and gets a Blender pass in M10.

15. **AI factions are temporary.** Until M8, the Harbor Watch guards ignore player scavs unless a scav shoots them (then they treat that scav as hostile for the raid).
16. **Paid exfils use stash money.** There is no physical cash item yet, so PIER 3 BOAT charges the profile balance on exit.
17. **Not yet in (planned M9):** dog tags on PMC bodies, the run-through status (needs XP), fence karma for scavs, co-op exfils.
18. **Late entry is a compromise.** Tarkov PMCs only spawn at raid start; here PMCs may join for the first 5 minutes so nobody waits a full 25-minute raid on a one-raid server. `Config.LATE_JOIN` controls it.
19. **Insurance timing** is 15 real minutes (`Config.INSURANCE_DELAY`). Returns reach the stash automatically when there is space; otherwise use COLLECT INSURANCE in the stash. Items mailed to offline owners need the real DataStore.

## Tool limitations (not game bugs)

- The Studio MCP `character_navigation` tool cannot drive this game's custom-controlled character. Test movement with keyboard input instead.
- `execute_luau` cannot read some protected properties, such as `Lighting.Technology`.
- Studio Place1 and Place2 contain scripts from a separate project. Never connect this Rojo session to them.
- The Baseplate texture warning `rbxassetid://203785492` comes from the default template and is harmless.

## Fixed this session

- The exits list never hid after the first O press (a `false ~= nil` check); it now shows for 6 s.
- Player corpses vanished on respawn (`LoadCharacter` destroys the old character even when detached); bodies are now copied into `ZR_Corpses`.

- Gamepad X pressed both reload and the open interaction prompt. A visible prompt now takes the press.
- The sync tool's `--commit` flag was being read as a path filter, which wiped the pending list. It now marks the last staged set as synced.
- Reusing a staging path could upload stale content. Each staging run now gets its own unique folder.
