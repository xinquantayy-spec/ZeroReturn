# Zero Return audit: technical quality, performance, reliability, security and release readiness

Area id: `tech`. Read-only audit of `/home/claude/EscapeFromBloxov` (build `0.9.2-m13`, docs dated 2026-11-02).
Nothing in the repo was changed.

A few terms used below:
- **Draw call:** one batch of drawing work sent to the graphics chip. Fewer is faster, and phones need far fewer.
- **Streaming:** Roblox sends each player only the parts near them, and drops far ones.
- **SLIM:** Roblox's automatic simpler versions of far-away models. Roblox's cloud makes them, and only for models
  saved in the place file.
- **DataStore:** Roblox's save system. A **session lock** stops two servers from saving the same player at once.
- **Noclip:** a cheat that walks through walls.
- **Strict typing:** Luau checks what kind of value each variable holds before the code runs. **Lint:** a tool
  that flags likely mistakes, such as a misspelt variable name.
- **MicroProfiler:** Roblox's frame timer. It shows where each millisecond of a frame goes.

## Current state

**How the game starts.** `src/server/Main.server.luau` requires 29 services and 4 optional ones, in a fixed order.
It then does the heavy work before it opens the remotes that clients talk through (`Main.server.luau:49-104`):
1. **Meshes.** `Services/Assets.luau` loads 23 Blender batches one after another through InsertService. They go
   into `ReplicatedStorage.ZR_Assets`, about 1,000 MeshParts (1,008 in the lead's server log).
2. **Every map.** `Services/World.luau:1646-1863` builds the Relay 7 lobby, Quay 7, Smelter, Meridian Mall and Border
   Yard into one `workspace.ZR_World` folder. Pinewatch is parked. The lead's log reads "World built: 49,988 parts
   (23,605 worn)". The two real-scale maps add over a million terrain columns (Border 423,000, Meridian 612,000;
   TEST_RESULTS "Border Yard on Customs", "Meridian Mall on Interchange").
3. **Clean-up passes.** It runs a z-fighting pass per map, the worn-material pass on every part, and the tidy pass
   (0.3 to 0.9 s a map).
4. **Times.** Meridian takes 8 to 9 s and Border 4.8 s. The cosmetic detail plan is made in the background, which
   takes about 10 s. It holds about 36,000 entries in the lead's count; Border alone had 27,586 when it was first
   built. The AI then samples cover points over every map (`AI.luau:230-305`).

**Client.** `src/client/Main.client.luau` starts 30 controllers. About two dozen run every frame (RenderStepped,
Heartbeat or BindToRenderStep in Camera, Movement, Weapon, Animator, Atmos, Post, Detail, Hud, Touch, Interact,
Effects, Ambience, Eyewear, NightVision, LaserFx, Lobby, Trade and QuickSlots). Many return early when idle. In
Studio they measured about 3 ms a frame on the laptop (TEST_RESULTS "Frame time in Studio: where it goes").

**Graphics levers that exist.**
- **GRAPHICS level** (`Controllers/Settings.luau`, `Controllers/Detail.luau`; `docs/look/LOOK_2_0.md`). It runs
  from POTATO to HIGH, and HIGH is the default on every device (owner decision, M12).
- **What the levels change.** The detail rings (200 / 175 / 140 studs on HIGH), depth of field, sun rays, bloom,
  the second grain layer, how far leaves are see-through (520 studs on HIGH), tree shadows (90 studs), rain
  density and clouds. Only POTATO turns off sun shadows and the worn materials.
- **HOLD 30 FPS.** It steps the level down after 8 s under 30 fps.
- **Other levers.** Distance levels of detail for animation (`Animator.luau:6, 311-325`). Per-frame build budgets
  (60 detail pieces and 150 leaf textures a frame). Indoor props cast no sun shadows. In FOG raids the map beyond
  the fog is hidden. There is a Studio benchmark mode (`ZR_Bench`).
- **What no level changes.** Map geometry, lamps and the streaming distance. This is on purpose, so that no setting
  sees further than another.

**What was measured.** All of it is Studio on the owner's ThinkPad T490 laptop (KNOWN_ISSUES 65, 67; TEST_RESULTS
"Frame rate in a separate client window" and "Fog and draw cost").
- **Meridian's heaviest views:** 28 to 33 fps at Roblox's top render level, 58 fps at level 10, and the 60 fps cap
  at level 5. Sun shadows are the largest cost (4 to 5 ms).
- **A wide Border view:** 1,072 draw calls after the detail rings were shortened (1,575 before). The wear decals of
  the client detail layer were about 55% of them.
- **Parts held by one client:** about 18,600 at Border's centre, 16,800 by the mall, 2,500 on Quay 7.
- **Not measured:** no phone, tablet, console, live server or second player has ever run the game (TEST_RESULTS
  line 9).

**Streaming.** It is on, per the map docs and the streamed detail cells (`docs/maps/BORDER_CUSTOMS_BUILD.md:68`;
TEST_RESULTS "Detail plan streamed with the map"). Its settings live only in the unpublished place file.
`default.project.json` sets no Workspace or Lighting properties, and scripts cannot read the streaming radius.
The code makes two lobby groups Persistent and a few models Atomic (`Relay7Dress.luau:526, 625, 965`), and calls
`RequestStreamAroundAsync` before each insertion (`Raid.luau:386`).

**Network.** There is one RemoteFunction (`Req`) and five RemoteEvents (`Shoot`, `Act`, `State`, `Note`, and the
unreliable `Fx`). Every request goes through rate limits, request-id de-duplication, payload checks and strikes
(`Services/Remotes.luau`). The server sends the full state snapshot (`Raid.state`, `Raid.luau:112-147`) after every
inventory change.

**Saving.** `Services/Store.luau`, `Profiles.luau` and `Settle.luau` handle it:
- UpdateAsync with a session lock that expires after 150 s.
- An autosave every 60 s.
- The loadout is held at deploy and saved before the player spawns.
- Each raid is settled once, by its raid id.
- A raid left open by a crash is settled as DISCONNECTED on the next join.
- On shutdown, a BindToClose handler waits up to 25 s for saves.

Studio uses the separate `DEV_ZR_Profiles_v1` store. The place is unpublished, so every test so far ran on the
in-memory fallback (KNOWN_ISSUES 1, 33).

**Security.** The server decides every shot, hit, inventory move, loot pick-up, payment and extraction. The client
owns its own movement, which is Roblox's default. `Services/Guard.luau` checks each player 4 times a second for
moves that are too fast.

**Code and tests.**
- **Size:** 159 Luau files, about 83,000 lines.
- **Strict typing:** 38 files, including the save and inventory core (`Store`, `Profiles`, `Remotes`, `Settle`,
  `Inv`). 119 are non-strict, including all of AI, Combat, Health, Raid, World and every client controller. Two
  files have no mode line.
- **Test suites:** LogicTests, CharTests, LookTests and MapTests. The latest counts are 341, 46, 33 and 38 checks
  (TEST_RESULTS "Detail plan streamed with the map"). They run inside a Studio playtest through the Studio-only
  `ZR_Dev` bridge.
- **Only static check:** `tools/luau_check.py`, which checks bracket and block balance (`luau_check.py:1-6`).
  `rokit.toml` pins only Rojo.

**Workflow.** The cloud agent writes files, runs `luau_check.py` and stages them to the laptop. Rojo carries them
into Studio, where the tests run through the Studio tools, with one client only. Git lives in the cloud workspace,
rebuilt from bundles (`docs/PIPELINE.md`, KNOWN_ISSUES 44).

**Overall.** The architecture is sound and server-first. What is missing is verification on the targets that
decide release: phones, a real DataStore, two players and a live server.

## Strengths

- **The server decides what matters.** Inventory, money, loot, extraction and profiles are server-side. Shots are
  re-traced on the server with its own ballistics, and its fire-rate, ammo, state and origin checks
  (`Combat.luau:209-283`). The abuse probes all held: 20 shots in a tick gave 1 accepted, replayed shots were
  rejected, a far origin was clamped, and a flood of 30 requests was throttled to 4 (TEST_RESULTS "Abuse and exploit
  probes").
- **The remote layer is sound.** It has rate limits per action (token buckets), replays that return the first
  result instead of running again, a depth and size check on every payload, and remotes that open only once all
  handlers are ready (`Remotes.luau:33-134, 189-191`).
- **Saving is designed carefully.** Session locks, an escrowed loadout saved before spawn, settlement once per raid
  id, crash recovery, a shutdown flush, a separate Studio store and capped message lists (`Store.luau`,
  `Profiles.luau`, `Raid.luau:1145-1206`, `Economy.luau:28-34`). The keys are `u_<userId>` and `mail_<userId>`, so
  Roblox's right-to-erasure deletion can find a player's data
  ([Roblox docs](https://create.roblox.com/docs/cloud/webhooks/automate-right-to-erasure)).
- **The client follows streaming.** Detail cells ride on streamed parts. Lamps, foliage and tree shadows follow tags
  as parts stream in. POTATO and the fog edge hook new parts as they arrive. The lobby sits far from every map
  (`Config.luau:73`).
- **Performance is measured honestly.** Benchmark mode, cost breakdowns, trimmed detail rings, per-frame budgets,
  animation levels of detail by distance, and "NOT VERIFIED" stated wherever it applies.
- **Faults stay contained.** Glass, tripwires, transits and airdrops are optional and wrapped. A map that fails to
  build is left out and the server still starts (`World.luau:1732-1769`).
- **Test tools stay out of live games.** `ZR_Dev` and `ZR_ClientDev` only exist in Studio (`Dev.luau:1237`,
  `Main.client.luau:43, 126`). No player-typed text is ever sent to other players (the text boxes are search
  fields), so no chat filtering is needed.

## Findings

Ranked by severity, then impact.

1. **P0. Saves have never run on a real DataStore, and a live server can run without saving and say nothing.**
   - Every test used the in-memory store (KNOWN_ISSUES 1, 33; TEST_RESULTS line 9).
   - `Store.init` probes the DataStore once at start. On any error it switches the whole server to memory mode for
     its lifetime, and it does not check whether it is in Studio (`Store.luau:20-33`).
   - The snapshot reports `persistence`, but no client code reads it. A DataStore hiccup at start on a live server
     would hand every player a blank profile and quietly save nothing.
2. **P0. The 30 FPS floor on low-end phones is unmeasured, and phones start at HIGH.**
   - No phone has run the game (KNOWN_ISSUES 3, 41).
   - The laptop gets 28 to 33 fps in Meridian at Roblox's top render level and 58 fps at level 10 (TEST_RESULTS
     "Frame rate in a separate client window"). Low-end phones have far weaker processors and graphics chips.
   - HIGH is the default everywhere (`Settings.luau:10, 187-193`). It adds depth of field outdoors, sun rays, bloom,
     two grain layers and the full detail rings (`LOOK_2_0.md` "Graphics setting").
3. **P1. The movement guard lets through teleports every 3 s, flying and noclip.**
   - A single large jump only counts as one strike. The new spot becomes the new baseline on the next quiet sample
     (`Guard.luau:49-67`). So one teleport every 3 s is never pulled back.
   - Downward moves are never checked.
   - Each 0.25 s check also allows 3 to 4 studs of slack (`Guard.luau:17-19`). The server's walk speed stays at 11,
     since the client's speed changes do not replicate (`Chars.luau:427`). So moving at about 45 studs/s (2.7 times
     sprint speed) or rising at about 44 studs/s passes every check, indefinitely.
   - Nothing checks for walls between samples.
   - Loot only checks distance (10 studs), with no line of sight (`Loot.luau:401-419`). A cheater can loot through
     a wall or a locked door, or teleport to loot and then to an exit.
   - The only test checks the limit numbers, not this logic (`LogicTests.luau:450-454`).
   - Strikes are only logged (`Remotes.luau:55-61`). They never lead to a kick or a ban.
4. **P1. The game has never been played by two people at once.**
   - Squads, player-vs-player hits and kill credit, contested loot, late-join spawns, simultaneous extractions, the
     car exit countdown and how gear replicates are covered only by logic tests and a single client (KNOWN_ISSUES 2,
     32; TEST_RESULTS line 9).
5. **P1. On a fresh server, early players can get a client that never works.**
   - The client waits at most 30 s for the remotes and never retries (`Net.luau:15-21`, `State.luau:75-84`).
   - The server opens the remotes only after it has loaded 23 mesh batches one by one and built all four maps
     (`Main.server.luau:52-53, 104`).
   - Meridian alone takes 8 to 9 s in Studio. The whole start-up time has never been measured.
6. **P1. Every server builds all four maps in code at start. That blocks Roblox's distance simplification, and it
   keeps 17,000 to 19,000 parts near the player.**
   - Roblox makes SLIM simplified models in its cloud, only for models saved in a published place. Changing parts
     at runtime breaks them ([SLIM docs](https://create.roblox.com/docs/workspace/streaming/slim); KNOWN_ISSUES 65).
   - Border's centre streams about 18,600 parts and the mall about 16,800 (KNOWN_ISSUES 65, 66).
   - On weak devices, Roblox's own frame-rate manager shortens how far the game draws. Players report it cutting
     hard, to about 200 studs, when many objects are in view
     ([community thread](https://devforum.roblox.com/t/improve-or-prioritize-render-distance-at-low-graphics-levels/3596299)).
     So phone players may see less than PC players.
7. **P1. A dropped connection or a server shutdown loses the kit, and there is no way back into the raid.**
   - Leaving settles the raid as DISCONNECTED at once (`Raid.luau:1183-1188`).
   - BindToClose settles every raid the same way (`Raid.luau:1189-1206`). Each Roblox update that restarts servers,
     and each server crash, would cost every raider their kit.
   - Phones drop connections more often (the app goes to the background, the network switches).
   - Tarkov lets players reconnect to a raid (see Gaps).
8. **P1. Draw calls on HIGH are above Roblox's own example budget.**
   - A wide Border view still makes 1,072 draw calls after the ring cut. The client wear decals were the largest
     part, about 870 of 1,575 before the cut (KNOWN_ISSUES 67; TEST_RESULTS "Fog and draw cost").
   - Roblox's example budget is under 1,000 draw calls and 1,000,000 triangles
     ([Design for performance](https://create.roblox.com/docs/performance-optimization/design)), and that is not a
     low-end phone budget.
9. **P2. Every inventory move sends the whole profile, and the inventory screen rebuilds from scratch.**
   - Each `inv` request (allowed up to 12 a second) ends in `afterChange`, which pushes `Raid.state` (`Raid.luau:980,
     1043, 1170`). Out of a raid that holds the whole stash, plus settings (the touch layout too), quests, traders,
     hideout, flea, the last 40 messages and claims (`Raid.luau:112-147`).
   - The inventory then destroys and rebuilds its whole panel on every snapshot (`Inventory.luau:952-966,
     1334-1338`). Trade waits a quarter second between redraws; Inventory does not (`Trade.luau:968-986`).
   - Risk: bandwidth (a community guide puts the per-player soft limit near 50 KB/s; unverified) and UI hitches on
     phones.
10. **P2. Every effect goes to every player, wherever they are, and each muzzle flash makes a light.**
    - `Remotes.fx` sends shots and sounds to all players, including players in the lobby and on the other map of a
      transit (`Remotes.luau:205-211`; 32 call sites).
    - Each remote shot builds a glow part and a PointLight on the client (`Effects.luau:380-390, 441-452`), even
      when the shot is a kilometre away.
11. **P2. Graphics settings follow the account, not the device.**
    - `quality`, `fov`, `sens`, `grain` and `hudScale` are saved in the profile and loaded on join (`Raid.luau:1075`,
      `Settings.luau:153-164`).
    - So a phone's automatic step-down also lowers the same player's PC. A PC player's HIGH also lands on their
      phone, and the phone's lighter film grain default is overwritten.
12. **P2. HOLD 30 FPS is slow, and it only steps down.**
    - After 20 s of calm, it needs 8 s under 30 fps per step, then 15 s to settle (`Detail.luau:787-877`). From
      HIGH, it takes about 50 s to reach LOW and 75 s to reach POTATO.
    - It never steps back up. It cannot touch Roblox's own graphics level.
    - The calm restarts on every spawn, so the first stretch of every raid is never judged.
13. **P2. The mesh library is sent to every client.**
    - About 1,000 MeshParts sit in `ReplicatedStorage.ZR_Assets` (`Assets.luau:27-35, 78-93`).
    - Roblox: "clients load everything in ReplicatedStorage"
      ([Design for performance](https://create.roblox.com/docs/performance-optimization/design)).
    - No client code clones the mall and bunker kits (`ZR_MK_*`, read only by the server's `Kit.luau` through
      `KitMeta`), the trees or the cover props. Their placed copies stream in anyway. Clients do clone the wear kit,
      the ground cover, gun parts, item pieces and character gear (`Detail.luau:42`, `GunBuild.luau:30`,
      `ItemModel.luau:27`, `Weapon.luau:321`).
14. **P2. Seasonal colours miss everything that streams in later.**
    - The season tint scans the workspace once, at deploy (`Atmos.luau:313-343, 494`). Trees and bushes that stream
      in afterwards keep their summer colours.
    - Seasons follow the real calendar (`Env.luau:44-52`), so this shows in every raid from September to May. The
      whole-workspace scan also causes a hitch at insertion.
15. **P2. Important engine settings live only in the place file.**
    - The streaming settings (target radius, stream-out behaviour, pause mode) and Lighting.Technology are not in
      `default.project.json`.
    - Five MaterialVariants exist only in the open Studio session (KNOWN_ISSUES 45).
    - Roblox recommends the Opportunistic stream-out mode
      ([streaming docs](https://create.roblox.com/docs/workspace/streaming)). The place may still be on the default
      (LowMemory); nobody can tell from the repo.
16. **P2. Shots can be dropped on jittery phone connections.**
    - The server rejects a shot that arrives less than 0.8 of the gun's interval after the last one
      (`Combat.luau:244-246`). Network jitter bunches shots together, and then the client has shown a shot the
      server never fired. Likely; it needs a jitter test.
    - The shot rate limit is 14 a second (`Remotes.luau:171`). Today's fastest gun is 800 RPM, about 13.3 a second
      (`Weapons.luau:20`), but Tarkov guns at 900 to 1,100 RPM would hit the limit and count as strikes.
17. **P2. Mistakes are not caught before Studio.**
    - Three quarters of the files (119 of 159) are non-strict, and no type checker or lint tool runs
      (`rokit.toml`; `luau_check.py:1-6`).
    - A real undeclared-global bug shipped: snow kicked up rain splashes (`Atmos.luau:232-233`).
    - Some features ship "written, not run": the stationary guns (DEVELOPMENT_STATUS line 54).
    - The resume baselines in NEXT_TASK are stale: 241, 19 and 38 checks against today's 341, 33 and 38.
18. **P2. The client's script time is unmeasured on phones.** About 3 ms a frame on the laptop (TEST_RESULTS "Frame
    time in Studio: where it goes"). On a low-end phone that could be several times more, out of a 33 ms budget.
    Unverified; it needs the on-device MicroProfiler.
19. **P2. Live server cost is unmeasured, and dead bodies stay in the physics simulation.**
    - The physics step was 8.3 ms with 761 moving parts on Border in Studio (TEST_RESULTS "Border Yard raid with AI").
    - Ragdolls are never anchored after they settle (`Chars.luau:614-655`).
    - The AI thinks 5 times a second per unit, finds a new path every 2.5 s while moving, and fires every frame
      (`AI.luau:543-556, 1898-1908, 2333-2344`).
20. **P3. Atmos rewrites about 20 lighting values every frame.**
    - That covers Lighting, Atmosphere, Clouds and colour grade, plus `GlobalWind` (`Atmos.luau:110-169, 581-587`).
    - The cost of constant Lighting changes on phones is unmeasured.
21. **P3. Every weapon light casts shadows.**
    - That covers first person and every third-person weapon light, including AI at night (`Chars.luau:224-233`,
      `Weapon.luau:453-463`). That can mean up to about 30 shadow-casting spotlights.
    - Roblox turns off its Future lighting on Android below graphics level 4 of 10, or when a device cannot hold 30
      fps ([Roblox staff, Oct 2024](https://devforum.roblox.com/t/future-is-bright-on-android-is-fully-rolled-out-client-beta/3235808?page=4)).
      Mid-range phones may still pay for it.
22. **P3. The HUD and lens overlays have hidden costs.**
    - Each HUD letter is drawn as up to three text labels: the letter and its red and blue copies
      (`Lens.luau:291-320`). There are 30 exit rows prebuilt (`Hud.luau:60`).
    - Nine full-screen overlays stay visible, only see-through, rather than hidden (`Post.luau:59-118`). It is
      unverified whether Roblox skips drawing fully see-through overlays.
23. **P3. One-off events travel on the channel that may drop messages.**
    - The airdrop plane, flares and the van leaving use `Fx`, which can drop messages on a poor connection
      (`Airdrop.luau:354-357`, `Extract.luau:262`). A phone player can miss the plane entirely.
24. **P3. Small leftovers.**
    - `Version.luau` still says `0.1.0-m1`, while `Config.BUILD` says `0.9.2-m13`.
    - No AnalyticsService events, so after launch there will be no data on deploys, extractions or deaths.

## Gaps vs EFT

| EFT feature | Ours | Gap |
|---|---|---|
| Separate graphics settings: texture and shadow quality, object LOD (level of detail), overall visibility (view distance), anti-aliasing, HBAO, SSR, sharpness, noise, grass shadows, mip streaming ([GGRecon](https://www.ggrecon.com/guides/escape-from-tarkov-best-settings-improve-fps-visibility/)) | One GRAPHICS level (POTATO to HIGH), film grain, a POSTFX tab; Roblox's own slider owns resolution, shadow and texture quality and render distance | Partial (exception 3). Rows we could add: shadows on LOW, foliage distance, detail density, each post effect |
| Settings stored on each PC (unverified) | Graphics, FOV and sensitivity stored in the profile and shared by every device | Departure that hurts cross-platform play (finding 11) |
| Reconnect to a raid after a disconnect, character left in the raid ([GameSpot, 0.12.6 notes](https://www.gamespot.com/articles/escape-from-tarkov-patch-126-wipes-character-data/1100-6477890/) fix "reconnect while indoors"; [guide](https://www.webfactoryltd.com/tarkov-server-connection-lost-heres-how-to-reconnect/), secondary source) | Leaving ends the raid as DISCONNECTED, kit lost; a server shutdown loses everyone's kit | Missing |
| BattlEye anti-cheat, ban waves, in-game reports (planned) ([PCGamesN](https://www.pcgamesn.com/escape-from-tarkov/cheating)) | Server-decided logic and checks; weak movement guard; strikes only logged; no kicks, bans or reports | Partial. Roblox offers Server Authority (since 9 July 2026) and a Ban API |
| Matching, then one map loaded per raid; waits from 2 to over 10 minutes ([TechRadar](https://www.techradar.com/gaming/pc-gaming/escape-from-tarkov-players-complain-of-long-loading-times-after-recent-wipe)) | All maps prebuilt in every server; 12 s matching, near-instant start | Departure: faster for players, but it costs server memory and start-up time and rules out SLIM |
| Profiles saved on the developer's servers; the game is online-only (unverified) | DataStore with session locks, escrow and crash recovery | Unverified: never run on a real DataStore |
| Long draw distances through the "Overall visibility" setting ([GGRecon](https://www.ggrecon.com/guides/escape-from-tarkov-best-settings-improve-fps-visibility/)) | Streaming radius probably Roblox's default of 1,024 studs (about 320 m at our scale); Roblox shortens render distance on weak devices | Partial (exception 3) |
| PC only, high-end hardware | 30 FPS on low-end phones, plus touch and gamepad | Owner exception 3 |

## Decisions

"Phone cost" means how heavy the result is for phones: none means no added cost (or a saving), high means likely
below 30 FPS on a low-end phone. Effort: S is up to a day, M is 2 to 5 days, L is over a week.

### tech-1. Release staging: when does the game first go onto Roblox's servers?
Real saves, two-player play, phone numbers, the Developer Console on a phone and Creator Analytics all need a
published place. Findings 1, 2, 4 and 7 cannot be closed without one. Publishing needs your approval.

| Option | What would be done | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. Stay unpublished | Keep testing in Studio only | S | none | partial |
| b. **Private test place now** | Publish as a private place, turn on Studio API access, run the save probes on the DEV store, invite 2 to 5 testers for two-player and phone runs; nothing public | S | none | close |
| c. Private now, public soft launch after fixes | Option b, then a public launch with no promotion once the P0 and P1 items pass and the content questionnaire is done | M | none | close |
| d. Public now | Publish publicly as it is | S | none | partial |

**Recommended: b.** It unblocks every P0 test today and keeps the game out of public view. Decide on c once those
results are in.

### tech-2. Which phone sets the 30 FPS floor, and how is it measured?
"Low-end phone" needs a concrete device. Roblox advises one baseline device, tested all through development
([Design for performance](https://create.roblox.com/docs/performance-optimization/design)). Studio's device emulator
is right for screen shape and controls, but not for speed or memory. Creator Analytics shows frame rate, memory and
crashes by device, but only above 100 daily players
([Performance dashboard](https://create.roblox.com/docs/production/analytics/performance)).

| Option | What would be done | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. Your own phone | Measure on the phone you have, with the on-device MicroProfiler and the Developer Console | S | none | close |
| b. **Buy one budget Android as the reference** | A current low-cost model (3 to 4 GB of memory) as the fixed baseline; every map gets a pass or fail at 30 fps in its heaviest views. Needs your approval to spend | S | none | close |
| c. Testers' phones | Collect MicroProfiler dumps and memory readings from 3 to 5 testers on the private place | S | none | close |
| d. Wait for analytics | Rely on Creator Analytics after launch | S | none | partial |

**Recommended: b.** A fixed low-end reference makes "30 FPS on low-end phones" testable and repeatable. Option a
does the same if your phone is low-end. Add c for breadth.

### tech-3. Default graphics level on phones
HIGH everywhere is your M12 decision. It came before the 30 FPS floor (2026-11-01), and phones are unmeasured.
HOLD 30 FPS needs about 50 s of stutter to get from HIGH to LOW (finding 12).

| Option | What would be done | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. Keep HIGH everywhere | As now | S | high | close |
| b. **Phones start at LOW, others at HIGH** | The first default follows the device (touch-only means LOW). The level is saved per device type, so a phone never changes the PC's level. HOLD 30 FPS stays, but judges in 3 s windows | S | none | close |
| c. First-launch benchmark | A 10 s test in the bunker picks the highest level that holds 40 fps, saved per device | M | none | close |
| d. Keep HIGH, two-way auto | Step down after 3 s under 30 fps; step up after 60 s over 50 fps | S | low | close |

**Recommended: b.** It is the safest way to hold 30 FPS before any phone data exists, and players can still raise
the level.

### tech-4. How maps are built and hosted
Today every server builds all four maps in code at start (finding 6). That costs start-up time and server memory,
and it rules out SLIM, Roblox's best tool for fewer draw calls on phones.

| Option | What would be done | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. Keep it | All maps built at every server start | S | high | departure |
| b. **Leaner runtime build** | Build only the map in play (plus its transit partner) at raid start. Merge plain wall and floor runs into fewer, larger parts in MapKit | M | none | close |
| c. Bake maps, then turn on SLIM | Run the same builders in Studio once, save the static shells into the place and set SLIM on building models. Doors, glass, containers and lamps stay dynamic | L | none | close |
| d. Lobby place plus one place per map | Teleport squads to a reserved server per raid, as Tarkov matches and loads one map per raid. Each map place can then use SLIM and its own streaming settings | L | none | exact |

**Recommended: b.** It cuts parts, start-up time and server load without restructuring. Move to c or d only if
phone tests still miss 30 fps.

### tech-5. How far the world streams on every device
The radius is the same for everyone, so it is fair. A smaller one means fewer parts and less memory on every
device, but distant buildings and players disappear. Area grows with the square of the radius, so 768 studs holds
about 56% of what 1,024 does. Roblox already shortens render distance on weak devices.

| Option | What would be done | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. 1,024 studs (default) | Keep the radius, switch to Opportunistic stream-out | S | med | close |
| b. **768 studs** | Every device streams to 768 studs (about 240 m), Opportunistic stream-out | S | low | close |
| c. 512 studs | About 160 m; long sniper fights end | S | low | partial |
| d. A radius per map | Quay 7 and Smelter at 1,024, the real-scale maps lower; needs one place per map (tech-4 d) | L | low | close |

**Recommended: b.** It removes roughly 40% of streamed parts in open areas and keeps about 240 m of view. Confirm
it on the baseline phone.

### tech-6. How to stop movement cheats
The client owns its movement, and the guard misses teleports, flying and noclip (finding 3). Roblox's Server
Authority has been fully released since 9 July 2026. It makes movement server-checked with client prediction, but
custom movement has to move to `BindToSimulation` and the new input system, and it raises server load
([DevForum](https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993)).

| Option | What would be done | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. **Harden what we have** | Pull back any single impossible move; check downward teleports and time in the air; cast a ray from the last good spot to catch noclip; require line of sight for loot, doors and the first step into an exit; log strikes and ban repeat cheaters (Players:BanAsync) | M | none | close |
| b. Roblox Server Authority | Rewrite Movement, Camera and character control on BindToSimulation and the new input system; retest everything on phones (phone and console clients get engine updates days later) | L | med | close |
| c. Leave it until after launch | No change | S | none | partial |

**Recommended: a.** It closes the worst holes in days. Revisit b once the 30 FPS work is done, since b touches every
movement feature.

### tech-7. Disconnects and server shutdowns mid-raid
Leaving or a server closing loses the kit at once (finding 7). Tarkov lets you reconnect while your character stays
in the raid.

| Option | What would be done | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. Keep the loss | As now | S | none | partial |
| b. Reconnect window | The body stays in the raid for up to 2 minutes, where it can be killed and looted. A player who rejoins within that time is sent back to the same server (TeleportToPlaceInstance) and resumes | M | none | exact |
| c. Refund on server shutdown | When a server closes (update or crash), escrowed kits return as they were and no loot is gained | S | none | departure |
| d. **Both b and c** | Reconnect for player disconnects, refund for server shutdowns | M | none | close |

**Recommended: d.** Phones drop connections often, and Roblox updates restart servers. Losing a kit on every
update would drive players away.

### tech-8. Code quality gate
No type checker or lint tool runs today, and the tests need a Studio session (finding 17). New tools on the laptop
and an Open Cloud key both need your approval.

| Option | What would be done | Effort | Phone cost | Parity |
|---|---|---|---|---|
| a. Keep as is | `luau_check.py` plus the Studio suites | S | none | close |
| b. Lint and type check on the laptop | Add selene (lint), StyLua (format) and luau-lsp (types) through rokit; run them before each sync; move Combat, Raid, Loot, Health and AI to strict | S | none | close |
| c. **b plus automatic test runs** | The four suites run headless on the private place through Open Cloud Luau Execution ([docs](https://create.roblox.com/docs/cloud/reference/features/luau-execution)) after each change | M | none | close |

**Recommended: c.** It catches bugs like the rain global before Studio, and it runs about 460 checks on every
change without anyone at the laptop.

## Quick wins

No decision needed. Each needs Studio or a code change, not your input.

1. **Engine settings in the repo.** Put StreamingEnabled, Opportunistic stream-out (Roblox's recommendation),
   PauseOutsideLoadedArea and the Lighting technology into `default.project.json` (`$properties`) so they are
   versioned. Save the place, so the five MaterialVariants persist (KNOWN_ISSUES 45).
2. **Saves must never be silent.**
   - On live servers, retry the DataStore probe with backoff, and refuse memory mode outside Studio.
   - If the store is down, kick with a clear message.
   - Show a "SAVING OFF" banner whenever `persistence ~= "DATASTORE"`.
3. **Fix the client start-up race.** Show "SERVER STARTING" and keep waiting for the remotes, with no 30 s give-up.
   Log the time of each start-up phase up to "server ready".
4. **Close the single-teleport hole now** (`Guard.luau:49-67`). Pull back any one move over twice the limit.
   Check downward moves as well.
5. **Line of sight for loot.** Add a line-of-sight ray (head to container, ignoring characters) to `Loot.reach` and
   to door use.
6. **Send effects only where they matter.** Send `Fx` only to players on the same map within range (shots about
   1,500 studs, small sounds about 400), and never to the lobby. Skip remote muzzle lights beyond about 150 studs.
7. **Lighter inventory updates.** Wait a quarter second between inventory redraws, as Trade does. Send the hideout,
   flea, message and claim blocks only when they change.
8. **Settings per device.** Save graphics level, FOV, sensitivity and grain under a device-type key (touch, PC,
   gamepad).
9. **Fix seasonal colours.** Tint nature parts as they stream in (a tag or DescendantAdded signal) and drop the
   whole-workspace scan at deploy.
10. **Safer shot limits.** Raise the shot rate limit to fit the fastest gun. Replace the strict per-shot gap with a
    small burst allowance, so jitter never eats shots and fair players never collect strikes.
11. **Anchor ragdolls** about 5 s after death, once they settle.
12. **Cheaper lights and overlays.** Only the first-person weapon light and lights within about 60 studs cast
    shadows (a client-side change). Hide overlays (`Visible = false`) while they are fully see-through. Write
    lighting values only when they change by a visible step.
13. **Trim the mesh library.** Move the server-only meshes (the mall and bunker kits, trees and cover props) to
    ServerStorage. Keep only what clients clone in ReplicatedStorage: the wear kit, ground cover, guns, items and
    character gear.
14. **Reliable one-off events.** Send the airdrop, flare and van events on the reliable `Note` channel.
15. **Tidy up.** Update or delete `Version.luau` and the NEXT_TASK test baselines.
16. **Measure after launch.** Add AnalyticsService events for join, deploy, extract, death and MIA, plus each raid's
    average fps and graphics level by device.

### How to measure on a phone (no phone data exists yet)
1. Publish the place privately (tech-1 b). Join it on the baseline phone.
2. Roblox menu, then Settings, then turn MicroProfiler on. On a PC on the same Wi-Fi, open the address and port the
   phone shows (port 1338). Capture frames in Meridian's KASSA and L2 gallery, Border's centre and a firefight, then
   "Save to file" ([MicroProfiler docs](https://create.roblox.com/docs/performance-optimization/microprofiler)).
3. Developer Console: Roblox menu, then Settings, then Developer Console (or type `/console` in chat). Read Memory
   (total, meshes, textures), Network and Log
   ([Developer Console](https://create.roblox.com/docs/studio/developer-console)).
4. Let the owner run the existing `ZR_Bench` walk on the private place (gate it by user id instead of Studio). It
   prints fps, render time and draw calls per view for every device.
5. After launch (100+ daily players), watch the Performance dashboard for client frame rate by platform, memory,
   crashes and out-of-memory exits, and server CPU and frame rate.
6. Log each run in TEST_RESULTS: phone model, Roblox graphics level, our GRAPHICS level, fps.

### Go-live checklist (the publishing steps need your approval)
1. **Saves.** Publish privately. Run the rejoin, failWrites and crash probes on the DEV store, then on the live store
   in a private server. Ship quick win 2 first.
2. **Players.** A two-client Studio test, then a squad test on real phones and a controller.
3. **Frame rate.** 30 fps on the baseline phone in every map's heaviest views, with the default level set
   accordingly (tech-3).
4. **Game settings.** Genre, maximum players (12, matching `Config.MAX_PLAYERS`), supported devices, avatar type
   (the game's own R15 rig) and chat.
5. **Content rating.** Answer Roblox's Maturity & Compliance Questionnaire. A game without it is restricted for
   everyone ([content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)). Realistic
   guns and deaths with little or no blood fit "Moderate". Heavy realistic blood or gore means "Restricted", which
   only age-checked players aged 18 and over can join.
6. **Assets.** Publish under the account that owns the meshes and audio, or re-upload them to a group
   (KNOWN_ISSUES 5). Re-upload the silent ambience atlas (KNOWN_ISSUES 73).
7. **Name.** Check "Zero Return" for clashes (KNOWN_ISSUES 8).
8. **Policies.** Decide how updates handle raids in progress (tech-7). Turn on bans for cheaters (tech-6). Set up the
   right-to-erasure webhook later; the key format already fits.

## Sources

Roblox:
- Instance streaming: https://create.roblox.com/docs/workspace/streaming
- SLIM: https://create.roblox.com/docs/workspace/streaming/slim
- Design for performance: https://create.roblox.com/docs/performance-optimization/design
- MicroProfiler: https://create.roblox.com/docs/performance-optimization/microprofiler
- Developer Console: https://create.roblox.com/docs/studio/developer-console
- Performance dashboard: https://create.roblox.com/docs/production/analytics/performance
- Data store limits: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits
- Right to erasure: https://create.roblox.com/docs/cloud/webhooks/automate-right-to-erasure
- Content maturity: https://create.roblox.com/docs/production/promotion/content-maturity
- Luau Execution (Open Cloud): https://create.roblox.com/docs/cloud/reference/features/luau-execution
- Ban API: https://create.roblox.com/docs/reference/engine/classes/Players/BanAsync
- Server Authority full release (9 July 2026): https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993
- Future lighting on Android (staff, Oct 2024): https://devforum.roblox.com/t/future-is-bright-on-android-is-fully-rolled-out-client-beta/3235808?page=4
- Render distance at low graphics levels (community reports, 2025; unverified): https://devforum.roblox.com/t/improve-or-prioritize-render-distance-at-low-graphics-levels/3596299
- Per-player bandwidth (community guide; unverified): https://devforum.roblox.com/t/network-optimization-2021-preventing-high-latency-reducing-lag/1046078

Escape from Tarkov:
- Graphics settings list (Feb 2024): https://www.ggrecon.com/guides/escape-from-tarkov-best-settings-improve-fps-visibility/
- Reconnect (0.12.6 notes mention "reconnect while indoors"): https://www.gamespot.com/articles/escape-from-tarkov-patch-126-wipes-character-data/1100-6477890/
- Reconnect behaviour (secondary source): https://www.webfactoryltd.com/tarkov-server-connection-lost-heres-how-to-reconnect/
- BattlEye, bans and planned in-game reports: https://www.pcgamesn.com/escape-from-tarkov/cheating
- Matching and loading waits (Jan 2024): https://www.techradar.com/gaming/pc-gaming/escape-from-tarkov-players-complain-of-long-loading-times-after-recent-wipe

Unverified: whether Roblox skips drawing fully see-through UI, whether depth of field is turned off on weak phones,
and what constant Lighting changes cost on phones. Tarkov's exact reconnect time limit was not found.
