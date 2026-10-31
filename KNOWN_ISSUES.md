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

15. **AI limits.** No grenades, voice lines or doors yet; peeking steps sideways from full cover rather than leaning; AI do not loot. Pathfinding occasionally lifts a unit onto a door frame for a moment (it recovers). Cover points come from a 3-stud sampling of the map (1,018 points since the M12 cover props).
20. **AI lethality is tuned by feel.** Reaction times, aim error and zeroing penalties are in `AI.luau` (`SKILL`); a guard can still kill a player standing in the open within a few seconds, which matches Tarkov but may need tuning after playtests.
16. **Paid exfils use stash money.** There is no physical cash item yet, so PIER 3 BOAT charges the profile balance on exit.
17. **Not yet in:** co-op exfils (scav + PMC), a flea market (player-to-player trading across servers), the scav case and other hideout modules (lavatory, intelligence centre, shooting range).
21. **Dog tags need space.** The tag goes into the dead PMC's pockets, rig or backpack; if all of them are completely full, no tag is added.
22. **Trader stock is per player.** Each player has their own purchase limits per 30-minute restock (Tarkov shares some stock between players).
23. **Economy balance is first-pass.** Prices, XP values, task rewards, build times (5–40 min) and craft times (15–45 min) are tuned by feel and need playtests.
25. **Rain and environment sounds not yet checked.** The DNS problem is fixed and the meshes and lens textures load, but the rain streaks, splashes, lens droplets and the environment sound atlas still need a look in a rainy raid.
26. **Weather is per raid.** Rain, fog and cloud cover are fixed for a whole raid (no changes mid-raid); the sun follows Roblox's fixed-season sky (sunrise about 6:00, sunset about 18:00).
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
37. **Not built yet (M16 part B).** The marksman/scout and safehouse-worker presets, a stash character preview (viewport), and per-item first-person gloves (gloves follow the outfit). Eyewear, the gas mask and goggles on characters are built; see 64 for what still waits on their meshes.
38. **Belt rig pouches are at the back.** They sit there to stay clear of the thighs when crouching and of the hands hanging at the sides.
39. **Worn materials can render black after a fresh upload (Studio).** If a material's textures fail to load once (for example while new images are still processing), Studio keeps rendering that exact set of textures black for the session. Restart Studio, or upload one of the maps again so the set gets a new ID (done for five materials on 2026-10-29).
40. **Client-side clutter is not identical for everyone.** HIGH draws low clutter (trash bags, cardboard, tipped bins) that POTATO does not, so a player lying prone right beside clutter is slightly easier to see on POTATO. Clutter is kept low and mostly along walls, and fog, light and cover are identical at every level.
41. **Performance on devices is unknown.** HIGH (the owner's default everywhere, phones included) adds depth of field (outdoors only since M13), sun rays, bloom and the full detail layer. On the T490 laptop in Studio it runs at about 34–37 fps on Quay 7 against 58 on POTATO, and 26–31 fps in the mall at Studio's maximum render quality (46–58 at quality 10). Phones and consoles have not been measured.
42. **Container decals float slightly.** Rust and grime on shipping containers sit on a flat plane just outside the corrugation, which shows at grazing angles.
43. **Not built yet (M12 leftovers):**
    - chain-link fences: they need to block movement but not bullets or sight;
    - denser interiors: desks with drawers out, filing cabinets, lockers;
    - wear on the older Blender props (containers, pallets, barrels have only their baked colours plus the decals).
45. **Five new MaterialVariants live only in the open Studio session.** Rojo could not create `ZR_Terrazzo`, `ZR_FloorTiles`, `ZR_CeilingTiles`, `ZR_VinylFloor` and `ZR_CarpetWorn` in MaterialService ("parent doesn't exist"), so they were added to the place directly with the same properties as `src/materials/*.model.json`. Save the place in Studio (owner) to keep them; reconnecting the Rojo plugin should also create them.
46. **Stocked shelving is triangle-heavy.** Each product is real geometry: a gondola is 7.3k triangles and the supermarket view about 114k triangles of shelving. It measured about 1 ms a frame at render quality 10 on the T490, so it was left as is; a lower-poly product set (box products without hidden faces, one filler block per shelf) would roughly halve it if phones need it.
47. **Cinema risers are 1.3 studs.** Players step up them; AI use the side aisle with half steps.
48. **An unknown asset warning.** `rbxassetid://111777818918264` (and once `92890594649410`) fail to load in raids ("HTTP 502" or "Asset content representation is being generated"). No instance in the client or server references them; likely a freshly uploaded image or mesh still processing. Harmless so far; watch the console.
49. **Studio frame rates depend on Studio's render quality.** Studio renders at quality 21 (the maximum) during Play; devices choose their own level. `settings().Rendering.QualityLevel` can be set from the client command bar for comparisons (it resets when Play stops).
50. **Resolved in M14 (2026-10-29): a modded gun now shows its build.** Every grid tile, drag ghost, detail strip and trader preset row draws the gun from the sprites of the parts actually on it.
51. **Item pictures are not checked on a phone.** At 64 px per grid cell they look sharp in Studio on the laptop; how readable the small ones (ammunition, keys) are on a phone screen is not verified.
52. **Tactical lasers have no beam (M14 gap).** The LC-4 and LP-1 count as lasers in the stats, but nothing is drawn and there are no device modes yet; Tarkov cycles light, laser and both.
53. **Folding stocks cannot be folded (M14 gap).** Tarkov lets you fold a stock to make the gun one or two cells shorter; the KS-7 folding stock is always unfolded here.
54. **No saved weapon builds (M14 gap).** Tarkov's modding screen saves builds and buys the missing parts from traders; here you fit parts you own, one at a time.
55. **No sight zeroing or variable zoom (M14 gap).** Scopes have one fixed zoom (the V6 is shown as 6x) and no zeroing distance.
56. **3D inspect only for guns (M14 gap).** The modding screen shows a gun in 3D; other items have only their picture.
57. **Part grid sizes are hand-set.** Only the pistol grips (1x1) were checked against Tarkov's wiki; barrels, handguards, stocks and sights keep sizes chosen to look like Tarkov's.
58. **At the range others do not see the gun in your hands (lobby gap).** Practice mode raises your gun on your own screen; other players hear the shots and see the impacts and the targets react, but your character keeps its weapons slung.
59. **No lobby sounds yet.** The design calls for the generator's hum once you have built it, radio chatter at the ops table, pipes knocking and the van idling through the countdown; there is no synthesized lobby audio yet (doors slam with a metal impact sound).
60. **Squads board the van one by one.** Each member walks in and boards; the squad still deploys together and wears one armband colour.
61. **Lobby frame rates on phones are unknown.** Measured only in Studio on the T490 (the bunker draws fewer calls and triangles than Quay 7).
44. **Syncing to the laptop without the shell tool.** Sessions linked to the laptop through the desktop app reach the project folder with the file bridge (stage and write files); there is no shell on the laptop then. The git repository lives in the session's cloud workspace, rebuilt from `backup/` (the full bundle, then the newest incremental bundle); changes are committed there, written to the laptop and carried into Studio by Rojo, and a new incremental bundle is written to `backup/` at each milestone. The incrementals `83cca47-23cdad8`, `23cdad8-221ba9f` and `221ba9f-c2ccd5d` need commit 83cca47, which was never bundled, so that stretch of history (2026-10-31 20:23 to 2026-11-01 00:30) is one sync commit (`c20bb53`).
33. **Unpublished place: profiles are in memory.** `Zero Return.rbxl` is not published, so Studio cannot reach DataStores and every play session starts a fresh profile. Publishing (owner's decision) restores the DEV DataStore.
24. **Task objectives are basic.** Eliminate / hand in / extract / visit only; no "plant or mark an item", weapon or gear conditions, or time-of-day conditions yet.
18. **Late entry is a compromise.** Tarkov PMCs only spawn at raid start; here PMCs may join for the first 5 minutes so nobody waits a full 25-minute raid on a one-raid server. `Config.LATE_JOIN` controls it.
19. **Insurance timing** is 15 real minutes (`Config.INSURANCE_DELAY`). Returns reach the stash automatically when there is space; otherwise use COLLECT INSURANCE in the stash. Items mailed to offline owners need the real DataStore.

62. **No scratch, dent or paint-chip decals yet.** The owner wants small details (scratches, dents, bullet holes) rather than noisy textures. The decal set has cracks, spalling, bullet holes, scuffs and stains; a set of scratches, dents and paint chips needs new textures (`assets/textures/gen_wear.py`) and an upload.
63. **Bunker flicker is fixed by analysis, not by eye on every screen.** In Studio no two decals in the bunker overlap within 0.02 studs any more, and the paint is in the walls. Flicker is a moving effect, so the owner's own walk-through is the final check.
64. **Resolved 2026-11-01: eyewear, the gas mask and the goggles are real meshes.** `build_eyewear.py` ran in Blender (16 meshes, 6,300 triangles, every size and centre on target) and the batch ZR_EyeGear is uploaded (77373343248745); CharTests C01 checks every key is in the library. Still missing for these items: inventory pictures and loose-loot models (they use the generic pictures).
    - To finish it: run the script in Blender (the steps are in its docstring), upload `assets/exports/ZR_EyeGear.fbx`, add the batch id as `ZR_EyeGear` in `AssetIds.luau`, check that `ZR_EyeGear.meta.json` matches the centres in `AssetMeta.luau` (the script forces the designed ones), then empty `Equipment.PENDING`. CharTests C01 lists the pending keys and fails if one stays listed after its mesh is in the library.
    - Until then characters wear neutral boxes in the item's colour (the night-vision head strap, which wore a beanie as a stand-in, is a box too) and loose copies lie as the old coloured block. Protection, the slot rules and the screen overlays do not depend on the meshes.
    - The five new items have no inventory picture or loose-loot model yet (their tiles show the item colour and name).
    - The gas mask has no breathing sound: the sound atlases hold only one-shot breaths, no loop.
    - Not modelled: lens cracks, fogging and raindrops, the mask's filter. The gas mask blocking glasses was asked for in the brief; Tarkov's own rule for gas masks could not be checked (see `docs/design/EFT_PARITY.md`, section 6).
    - The night-vision key N still has no gamepad binding (the touch button exists).

65. **Border Yard streams in many parts at once.** At the map centre the client holds about 18,600 parts (Quay 7: 2,500), with the default streaming radius. In Studio it ran about 20% slower than Quay 7 (TEST_RESULTS, Border Yard raid with AI). Phones are unmeasured, and the 30 fps rule makes this the main risk on the map. Levers, in order: a smaller `StreamingTargetRadius` (set in Studio's Workspace properties; scripts cannot read it), fewer separate parts per building (merge plain walls into meshes), then lamps. Roblox's distant-model meshes (`LevelOfDetail = StreamingMesh`) are made when a place is published, so they do not help maps built by script at server start.

## Tool limitations (not game bugs)

- The Studio MCP `character_navigation` tool cannot drive this game's custom-controlled character. Test movement with keyboard input instead.
- `execute_luau` cannot read some protected properties, such as `Lighting.Technology`.
- Studio Place1 and Place2 contain scripts from a separate project. Never connect this Rojo session to them.
- The Baseplate texture warning `rbxassetid://203785492` comes from the default template and is harmless.
- Write files to the laptop only while Studio is in edit mode. A file written during a play session, or while it stops, is not picked up by Rojo until it changes again.
- Downloading tools from outside (for example the Luau analyzer from GitHub releases) is refused in the cloud workspace; `tools/luau_check.py` is the structural check.

## Fixed this session

- Bunker graphics (owner, 2026-11-01: "glitching textures", "too dirty for the whole bunker"):
  - The olive paint band was a thin slab 0.06 studs in front of every wall, and the detail decals sat at the same depth (one layer exactly level with it), so they flickered as the camera moved. The paint is now part of the wall blocks (olive plaster, a dark line, light plaster above).
  - Every concrete surface in the bunker had a worn texture variant, and every wall got streaks, peeling and cracks. The shell is now plain painted plaster and concrete, and the detail plan's new "clean" profile adds only a soft strip of grime along the foot of each wall and an occasional hairline crack.
  - Grime is placed where it builds up (197 spots): corners, doorways (hand marks, scuffs, worn thresholds), oil and soot at the generator and benches, damp at the water collector and in the old tunnel, old hits on the range backstop, boot dust where people stand, oil and tyre marks in the motor pool.
  - The z-fighting pass shrank parts even where the shared face was hidden (a wall top under the ceiling, a foot on the floor), opening hairline slits; it now skips covered faces (bunker 175 pulls to 43, Quay 7 211 to 108, Smelter 459 to 273, Meridian 1327 to 513, Border Yard 825 to 203).
  - Decal layers on every map now sit at least 0.025 studs apart (thinner carriers), so overlapping layers no longer fight in the depth buffer.
  - Rubble and chips were removed from the bunker's rooms and corridor; the lived-in litter, cardboard and puddles stay.

- M13 items (owner request): loose loot was a block in the item's colour (old issue 27). Every item now has a Blender model and a picture: 124 inventory pictures in two atlas sheets, and loose loot lies as the real model (95 items from three new batches, worn gear as the character meshes, guns as before). See `docs/items/ITEM_ART.md`.

- M13 Meridian Mall:
  - The exits list kept showing CARGO LIFT as NEEDS POWER after the generator started (the raid info was not re-sent).
  - AI could not reach the cinema's back rows or projection booths (1.3-stud risers, a 3.6-wide booth door, the visit point inside the projector).
  - The detail plan put barbed wire on the mall's facade bands, parapets and gallery edges.
  - Interior walls carried whole-wall rain streaks and peeling plaster layers on most faces (the costliest detail indoors); now occasional streaks and plaster patches.
  - Depth of field ran indoors, where nothing is far enough to blur; it now switches off under a roof (HIGH).
  - The muzzle flash was a large square glow; it is now small and round (owner request).

- M12:
  - Five worn materials (worn concrete, precast panels, plaster, painted metal, asphalt) rendered almost black; they now have fresh roughness maps.
  - Leaving POTATO did not restore the worn materials: the table of stripped parts had weak keys, so it lost them.
  - The safehouse built map detail 300 studs above it (distance ignored height).
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
