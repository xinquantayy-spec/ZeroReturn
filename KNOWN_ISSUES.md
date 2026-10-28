# Known Issues

## Open

1. **The real DataStore has not been exercised.**
   - The Studio place is unpublished, so profiles fall back to the in-memory store.
   - To test real persistence:
     1. Save the place to Roblox as a **private** place. This is the owner's decision.
     2. Turn on *Game Settings → Security → Enable Studio Access to API Services*.
     3. Re-run the persistence probes: rejoin, failWrites, crash recovery.
   - Studio uses `DEV_ZR_Profiles_v1`, never the live store.
2. **Multi-client is untested** (also the M16 two-client checks, see 32). Squads (invites, shared insertion, armbands), player-vs-player hits and kill credit, two players contesting loot, late-join spawn distance and simultaneous extractions are implemented and covered by logic tests, but need a Studio *Clients and Servers* test (2–3 clients). The MCP tools can only drive one client.
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
14. **Character materials are vertex colours only.** The M16 body and gear have no texture maps. Body segments and soft gear use Roblox's built-in Fabric, which looks coarse up close, and first-person sleeves use SmoothPlastic. A subtle custom fabric MaterialVariant is still to make.

15. **AI limits.** No grenades, voice lines or doors yet; peeking steps sideways from full cover rather than leaning; AI do not loot. Pathfinding occasionally lifts a unit onto a door frame for a moment (it recovers). Cover points come from a 3-stud sampling of the map (834 points), so open yards have little cover.
20. **AI lethality is tuned by feel.** Reaction times, aim error and zeroing penalties are in `AI.luau` (`SKILL`); a guard can still kill a player standing in the open within a few seconds, which matches Tarkov but may need tuning after playtests.
16. **Paid exfils use stash money.** There is no physical cash item yet, so PIER 3 BOAT charges the profile balance on exit.
17. **Not yet in:** co-op exfils (scav + PMC), a flea market (player-to-player trading across servers), the scav case and other hideout modules (lavatory, intelligence centre, shooting range).
21. **Dog tags need space.** The tag goes into the dead PMC's pockets, rig or backpack; if all of them are completely full, no tag is added.
22. **Trader stock is per player.** Each player has their own purchase limits per 30-minute restock (Tarkov shares some stock between players).
23. **Economy balance is first-pass.** Prices, XP values, task rewards, build times (5–40 min) and craft times (15–45 min) are tuned by feel and need playtests.
25. **Rain and environment sounds not yet checked.** The DNS problem is fixed and the meshes and lens textures load, but the rain streaks, splashes, lens droplets and the environment sound atlas still need a look in a rainy raid.
26. **Weather is per raid.** Rain, fog and cloud cover are fixed for a whole raid (no changes mid-raid); the sun follows Roblox's fixed-season sky (sunrise about 6:00, sunset about 18:00).
27. **Loose loot models are simple.** Non-weapon items lying in the world are blocks in the item's colour and size; weapons use the real weapon model.
28. **Doors swing one way.** Doors always open inward by 100° around the hinge; a player standing in the swing is not pushed. Closed doors do not muffle sound yet.
29. **Grenade paths ignore people.** The server works out the whole path at release against the static world, so a grenade passes through characters, and a door that moves after the throw does not change it.
30. **AI only react to where a grenade ends up.** Units near the landing point notice it once it lands; they do not dodge a grenade in flight.
31. **No first-person arms for a throw without a weapon in hand.** With no weapon drawn, only the grenade shows in first person.
32. **Characters, multi-client (M16).** The two-client checks (C06: a second observer and late join; C08: the other player's view) are BLOCKED by the single-client MCP. Replication of the server-built gear is standard Roblox replication, but has not been observed from a second client.
34. **Looking up with a raid pack is limited.** Tall packs cap the neck tilt (`NeckUp`); the waist bends further instead. The aim direction is unchanged, but the head looks stiffer under a raid pack.
35. **Layer scaling stretches pouches.** A chest rig over a plate carrier is scaled about 1.3× deep to clear it, so its pouches look deeper than when worn alone.
36. **Small overlaps by design.**
    - Helmet chin straps run through the headset ear cups.
    - The armour collar sits on top of the carrier's shoulder straps.
    - The hard hat refuses headsets, because its brim would cut the ear cups.
37. **Not built yet (M16 part B).** Eyewear and goggles, the marksman/scout and safehouse-worker presets, a stash character preview (viewport), and per-item first-person gloves (gloves follow the outfit).
38. **Belt rig pouches are at the back.** They sit there to stay clear of the thighs when crouching and of the hands hanging at the sides.
33. **Unpublished place: profiles are in memory.** `Zero Return.rbxl` is not published, so Studio cannot reach DataStores and every play session starts a fresh profile. Publishing (owner's decision) restores the DEV DataStore.
24. **Task objectives are basic.** Eliminate / hand in / extract / visit only; no "plant or mark an item", weapon or gear conditions, or time-of-day conditions yet.
18. **Late entry is a compromise.** Tarkov PMCs only spawn at raid start; here PMCs may join for the first 5 minutes so nobody waits a full 25-minute raid on a one-raid server. `Config.LATE_JOIN` controls it.
19. **Insurance timing** is 15 real minutes (`Config.INSURANCE_DELAY`). Returns reach the stash automatically when there is space; otherwise use COLLECT INSURANCE in the stash. Items mailed to offline owners need the real DataStore.

## Tool limitations (not game bugs)

- The Studio MCP `character_navigation` tool cannot drive this game's custom-controlled character. Test movement with keyboard input instead.
- `execute_luau` cannot read some protected properties, such as `Lighting.Technology`.
- Studio Place1 and Place2 contain scripts from a separate project. Never connect this Rojo session to them.
- The Baseplate texture warning `rbxassetid://203785492` comes from the default template and is harmless.

## Fixed this session

- M16:
  - Long guns slung on the back pointed straight out behind the character; they now lie flat across the back, over the pack or plates.
  - "Quick move to stash" in the safehouse was refused with BAD_INPUT, because the server tried to resolve "stash" as a container.
  - The first-person hidden-part list kept destroyed parts, so it grew with every gear change.
  - Showroom dummies floated when crouched or prone.

- M9: the restock timer froze when the trader screen was reopened; long hideout requirement lines were cut off; door prompts kept their old text after the server changed them; run-through reports listed picked-up items as found-in-raid; a dead PMC's own dog tag showed up in their report.

- The exits list never hid after the first O press (a `false ~= nil` check); it now shows for 6 s.
- Player corpses vanished on respawn (`LoadCharacter` destroys the old character even when detached); bodies are now copied into `ZR_Corpses`.

- Gamepad X pressed both reload and the open interaction prompt. A visible prompt now takes the press.
- The sync tool's `--commit` flag was being read as a path filter, which wiped the pending list. It now marks the last staged set as synced.
- Reusing a staging path could upload stale content. Each staging run now gets its own unique folder.
