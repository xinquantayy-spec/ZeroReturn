# UI audit: HUD, screens, controls, settings and onboarding

Area id: `ui`. Audited 2026-11-07, read-only, against the repo at build `0.9.2-m13`.

Terms used once and then plainly:
- **pt** is a screen point, the unit Roblox reports on phones. An iPhone 14 held sideways is 844 x 390 pt.
- **Safe area** is the part of a phone screen that the notch, rounded corners and home bar do not cover.
- **Glyph** is one drawn character.
- **UIScale** is a Roblox object that grows or shrinks a whole screen at once.

**One correction to the brief.** EFT is no longer without onboarding. Version 1.0 (15 Nov 2025) added a tutorial. It is a custom raid that starts after character creation. It teaches controls, weapons, healing and combat, and green glowing bars show the way to the exit. A chain of story missions follows it ([VidaExtra](https://www.vidaextra.com/fps/nunca-ha-sido-mejor-momento-para-iniciarse-escape-from-tarkov-pese-al-desastre-que-ha-sido-su-aterrizaje-steam), [Insider Gaming](https://insider-gaming.com/tarkov-getting-easier-first-time-decade/)). So a tutorial would now be parity with EFT, not a departure from it.

## Current state

All the parts are built. Most screens copy Tarkov's structure closely. The weak points are how these parts behave on phones, on a gamepad and for new players. Nothing in this area has run on a phone, a tablet, a real controller or the device emulator (TEST_RESULTS.md, line 9; KNOWN_ISSUES 3 and 79).

| Part | What exists | Key files |
|---|---|---|
| In-raid HUD | Drawn glyph by glyph in the Oswald font, with a red/blue split and a glow on each glyph. It shows:<br>- Vitals at top left: total health, stamina, energy and water, and effects.<br>- REC or STBY with the date and time, a device line, and the raid clock (the money in the bunker) at top right.<br>- The exits list, on O pressed twice.<br>- Centre notices and a progress bar.<br>- A weapon line at bottom centre.<br>- Toasts, the squad list, a death card and corner brackets.<br>The HUD sways with the camera. Settings: HUD SCALE 70 to 140 %, an optional centre dot, and a curved HUD option. | `Hud.luau`, `Lens.luau`, `Post.luau` |
| Quick slots | Tarkov's keys 4 to 0. The bar has AUTO-HIDE, ALWAYS and NEVER. | `QuickSlots.luau` |
| Interaction | One prompt at a time, e.g. "[F] SEARCH · BODY". A tap works it on touch. | `Interact.luau` |
| Inventory | Tarkov's three columns: gear slots, containers, then the stash or loot. Character tabs: GEAR, HEALTH, SKILLS, MASTERING, and OVERALL (TASKS in a raid).<br>Item pictures, and FIR, INS and wish-list marks. SORT and SEARCH. A right-click menu and a 40-pt info bar with action buttons. | `Inventory.luau`, `Character.luau` |
| Inspect | Up to three draggable windows. Each has a turnable 3D model, an attribute sheet, the chance to penetrate armour by class, and a wish-list toggle. | `Inspect.luau` |
| Relay radio | One window with seven tabs: VOS, HALE, TILDA, FENCE, FLEA MARKET, MESSENGER and HANDBOOK. Traders have TRADE (a goods grid with BUY and SELL), TASKS and SERVICES. | `Trade.luau`, `Menus.luau` |
| Other screens | - Deploy: PMC or scav, the loadout, gear at risk, insurance, map vote and squad.<br>- Raid report.<br>- Hideout: modules, crafting and STYLE.<br>- Modding: the gun in 3D. | `Screens.luau`, `Trade.luau`, `Modding.luau` |
| Settings | Five tabs:<br>- GAME: FOV 50 to 100, head bob, shake, reduce motion, aim hold or toggle, quick slots, centre dot, hit feedback, HUD scale, curved HUD.<br>- GRAPHICS: preset, HOLD 30 FPS, grain, lens, motion blur, recorder overlay.<br>- POSTFX: brightness, saturation, clarity, four grades and their intensity.<br>- SOUND: overall, effects, interface, ambience.<br>- CONTROLS: sensitivity, aim sensitivity, two touch toggles. PC rebinding takes Alt, Shift or Ctrl combinations. The list shows each device's own buttons. EDIT TOUCH LAYOUT is here too. | `Screens.luau` lines 585-855, `Settings.luau` |
| Gamepad | Shared buttons tell a tap, a hold and "while aiming" apart. Menus use Roblox's built-in selection. | `InputMap.luau`, `Input.luau` |
| Touch v2 | 14 round icon buttons, a walk-and-run stick, and a FIRE button that also aims. Rare actions sit in a MORE tray, and MED opens a wheel. A layout editor saves to the profile. | `Touch.luau`, `TouchLayout.luau`, `docs/design/TOUCH_CONTROLS.md` |
| Lobby | Relay 7. Each screen has a station with a prompt. A pigeonhole lamp lights for insurance returns, and active tasks are pinned on the cork board. | `Lobby.luau`, `Interact.luau` lines 165-197 |
| Onboarding | A welcome message in the messenger, a help line in the inventory, and the recovery kit. Nothing else. | `Raid.luau:1154`, `Inventory.luau:885` |
| Loading | Roblox's default screen when you join. At deployment the van screen fades, then the server waits up to 4 s for the map to stream in. | `Lobby.luau:565-660`, `Raid.luau:386` |

## Strengths

- **Tarkov's screens are copied in depth.**
  - The inventory uses EFT's three columns and slot names.
  - INSPECT has a full attribute sheet for every kind of item, including the chance to penetrate each armour class (`Inspect.luau:514-525`).
  - The flea market uses the same fee formula on client and server (`Menus.luau:231-235`), and the messenger has RECEIVE ALL.
  - The handbook has categories, search and the wish list. Mastering has its own tab.
- **Tarkov's information scarcity is kept where it matters most.** There is no ammo counter, no hit marker, no compass and no minimap, and the exits show only on demand (`Hud.luau:4`, `Hud.luau:411`).
- **The controls are thorough.**
  - PC uses EFT's default keys, Alt, Shift and Ctrl combinations, rebinding, and a warning when a key is already bound (`Screens.luau:659-675`).
  - The gamepad's tap, hold and aiming rules reach every Tarkov action except the slot keys (`InputMap.luau:5-13`).
  - Touch v2 was researched from CoD Mobile, PUBG Mobile and Arena Breakout. It has an editor, and the server cleans each saved layout (`TouchLayout.luau:87-115`).
  - Logic tests check that touch buttons never overlap on four phone and tablet sizes (`TOUCH_CONTROLS.md:121`).
- **The visual language is consistent.** It is a "field recorder" palette of charcoal panels with an ochre accent (`UiKit.luau:15-19`).
  - Contrast is readable: the dim text is about 6:1 on the background, and the ochre tab about 5:1 on its fill (my calculation).
  - The icons are our own (`gen_touch_icons.py`).
  - The fonts are Roblox's own Oswald and Roboto Mono, so there is no IP issue.
- **The HUD adapts its layout.**
  - It keeps clear of Roblox's top bar.
  - A long exits list shrinks or splits into two columns.
  - Toasts move clear of the touch stick (`Hud.luau:78-238`).

## Findings

Ranked, most serious first. "Computed" means I worked it out from the layout code; I did not see it on a device.

1. **P0. The menus do not fit a phone.**
   - **What and why:** The menus use fixed pixel sizes, with text from 9 to 17 px and nothing that scales them. `K.scale()` exists but nothing calls it, and the code has no UIScale.
   - **Trader:** On an 844 x 390 phone the relay radio window is 271 to 329 pt tall inside. It depends on whether Roblox's 58-pt top bar is excluded. After the title, the tabs, the trader header, BUY/SELL and the category row, the goods grid has 33 pt, less than one 34-pt row. With the top bar excluded it has a negative height (computed). So the trader screen cannot show its goods on a phone.
   - **Inventory:** Cells are 24 pt. Item labels are 10 pt and the FIR/INS tags 9 pt. Action buttons are 30 pt tall with 10-pt text. Both are below the usual 44-pt touch target (Apple's guideline, from memory; the page could not be fetched here).
   - **Evidence:** `Trade.luau:791`, `825-826`, `741-746`, `330-334`, `350-397`; `Screens.luau:32-40`; `Inventory.luau:972-974`, `1019-1024`, `586`, `605`, `874`; `UiKit.luau:146-150` (never called); [Roblox adaptive design](https://create.roblox.com/docs/production/publishing/adaptive-design) ("UI should scale up or down with the screen").

2. **P1. The HUD always shows exact numbers that EFT keeps off the screen.**
   - **What and why:** Total health ("440/440", the largest HUD text), stamina "100/100", energy and water are drawn every frame (`Hud.luau:552-596`).
   - **EFT:** It has a "Health condition" indicator and a "Stamina and stance" indicator. Each can be "Always shown" or set to auto-hide, and health has a Polychrome or Monochrome colour scheme ([GGRecon](https://www.ggrecon.com/guides/escape-from-tarkov-best-settings-improve-fps-visibility/), [esports.net](https://www.esports.net/wiki/guides/best-escape-from-tarkov-settings/)). Exact health per body part is on the Health tab. That EFT's indicator is a body outline without numbers is from my knowledge (unverified).
   - **On a phone:** The HUD scale is 0.54 (`Lens.luau:107`). The health numerals are 42 pt tall, and the vitals block runs from about 60 to 190 pt down a 390-pt screen, a third of its height (computed from `Hud.luau:52-56` and `94`).

3. **P1. Most screens cannot be opened from a key.**
   - **What and why:** The owner's design choice is "every Tarkov screen still opens from its key" (`EFT_PARITY.md:16`, `RELAY7_LOBBY.md:3-4`).
   - **Code:** Only the inventory (Tab), settings (P) and exits (O) have keys (`InputMap.luau:20-77`). Traders, the flea market, messenger, handbook, hideout, deploy and insurance open only from a station prompt in the bunker (`Interact.luau:165-197`). In EFT these are one click away in the main menu ([ClutchPoints](https://clutchpoints.com/gaming/escape-from-tarkov-beginners-guide-how-to-get-started); the exact bottom bar is unverified).

4. **P1. Touch and gamepad players cannot turn an item when placing it.**
   - **What and why:** Placing an item uses a rotation flag. That flag changes only with the R key, or with a ROTATE button that exists only in the old tall detail strip. The info bar is now 40 pt, so that strip is never drawn and the bar has no ROTATE.
   - **Evidence:** `Inventory.luau:1019` (`detailH = 40`), `857-882`, `936-939`, `1384-1391`.

5. **P1. One tap or click can destroy, sell or pay.**
   - **What and why:** DISCARD and "SELL TO ..." act at once, with no confirmation (`Inventory.luau:469-489`). On touch they sit in a row of 30-pt buttons (`Inventory.luau:873-881`). A tap on a hold prompt runs the whole hold, so one tap pays a car fare of up to 25,000 MK (`Interact.luau:57-65`).
   - **EFT:** Whether EFT asks before a discard is unverified. The risk to a young audience on phones stands either way.

6. **P1. New players get no onboarding.**
   - **What and why:** There is one welcome message ("Trade at the counters, plan at the ops table, board the van", `Raid.luau:1154`) and an inventory help line written for mouse users (`Inventory.luau:885`). EFT 1.0 now has a tutorial raid (see the correction above). The Roblox audience is younger and newer.

7. **P2. The weapon line always shows the fire mode.**
   - **What and why:** The bottom-centre line shows the weapon, fire mode and device state the whole time a weapon is drawn (`Hud.luau:449-468`). This makes Tarkov's fire-mode check (Alt+B) pointless.
   - **EFT:** It shows neither the rounds left nor the fire mode, and the mode appears only when you change it ([Gamepressure](https://www.gamepressure.com/escape-from-tarkov/using-weapons/z0cf2e)).

8. **P2. The bodycam overlay costs legibility and drawing work. Its cost on phones is not measured.**
   - **Labels:** Every HUD glyph is three TextLabels: main, red and blue (`Lens.luau:163`, `291-319`). By my count the default raid HUD holds about 400 of them.
   - **Size:** The REC line with date and time is about 300 pt wide on a phone (my estimate). It sits above the device line "ZR BODYCAM 4 · X7F3A21 · map" (`Hud.luau:380-392`).
   - **Sway:** The whole HUD root moves with the camera (`Hud.luau:699-706`).
   - **Full-screen layers:** Two grain layers, a vignette and an edge haze cover the whole screen (`Post.luau:74-118`).
   - **What it adds:** It carries the owner's bodycam identity, shows REC versus STBY, and shows the raid clock, which matches EFT's timer, shown by default since 0.16.7 ([AltChar](https://www.altchar.com/game-news/escape-from-tarkov-patch-0.16.7.0-full-patch-notes-aP2RA1G8vdlq)). It also shows the in-world time of day, which EFT does not show in raid (unverified).
   - **Evidence of cost:** The laptop measured the HUD as almost free (`KNOWN_ISSUES` 65); phones have not been measured.

9. **P2. The default touch layout covers the middle of the view.**
   - **What and why:** MORE sits just above the crosshair (x 0.49, y 0.33). LOOK, MODE and SWAP sit at x 0.59, MED at 0.61 and AIM at 0.70/0.49, so five buttons are in the central third of the screen, where targets appear (`TouchLayout.luau:35-46`; screenshot `docs/maps/evidence/UI12_touch_v2_raid.jpg`).
   - **Also:** The icons in the MORE tray have no captions (`UI14_touch_v2_tray.jpg`).

10. **P2. Settings lack EFT's rows and per-device controls.**
    - **What and why:** These EFT rows are missing ([GGRecon](https://www.ggrecon.com/guides/escape-from-tarkov-best-settings-improve-fps-visibility/), [GamersDecide](https://gamersdecide.com/articles/escape-from-tarkov-best-postfx-settings)):
      - GAME: stamina and stance, health condition, health colour scheme, malfunction notifications, double-click item quick use, highlight available operations.
      - POSTFX: colourfulness, the two sharpen sliders, and colour-blind mode (Protanopia, Deuteranopia or Tritanopia, with an intensity).
      - SOUND: music, chat and VoIP.
    - **Our own gaps:** One sensitivity drives the mouse, the gamepad stick and touch, and there is no invert (`Camera.luau:129-142`). Numbers move only by - and + steps, with no slider (`Screens.luau:781-792`). The rows are in `Screens.luau:589-630`.

11. **P2. Mail arrives silently.**
    - **What and why:** New messages (finished tasks, flea sales, loyalty levels) are stored with no toast, unread flag or badge (`Economy.luau:28-33`). The pigeonhole lamp lights only for insurance (`Lobby.luau:223-228`). The messenger shows message totals, not unread counts (`Menus.luau:73-84`).

12. **P2. Roblox's server-wide text chat stays on in raids.**
    - **What and why:** Nothing configures TextChatService, and only the backpack, health and player list are hidden (`Main.client.luau:27-31`). Dead players and the bunker can call out positions to people still in the raid.
    - **EFT:** It has proximity voice since 0.12.12 ([Gamepressure](https://www.gamepressure.com/newsroom/escape-from-tarkov-patch-01212-adds-new-map-and-voip/z03dd5)). That it has no text chat in raid is unverified.

13. **P2. Drag and drop lacks EFT's helpers.**
    - **What and why:**
      - While dragging, the ghost is always ochre. It does not show whether the item fits (`Inventory.luau:1219-1258`). EFT's green/red cue is from my knowledge (unverified).
      - Split only halves a stack (`439-447`). EFT's Ctrl+drag picks an amount.
      - There is no Del to discard, no double-click to use and no middle-click to examine (`EFT_PARITY.md:49`; `Inventory.luau:3`, `610-631`).
      - Drag works only with a mouse (`610-631`, `1375-1379`).

14. **P2. The UI docs are out of date.**
    - **`EFT_PARITY.md:44-100`:** It still lists as missing things built on 2026-10-31: messenger, handbook, flea market, wish list, rebinding, POSTFX, SOUND, quick slots, and stash search and sort.
    - **KNOWN_ISSUES 12:** It is stale, because the columns now scroll (`Inventory.luau:1026-1028`).
    - **KNOWN_ISSUES 51:** It quotes 64-pt cells, but cells are now 24 to 46 pt (`Inventory.luau:1021`).
    - **`DEVELOPMENT_STATUS.md:282`:** It still says "no flea market yet".
    - **TEST_RESULTS:** It records no Studio check of the 2026-10-31 screens: inventory columns, INSPECT, trader tabs, rebinding, flea market, messenger and handbook.

15. **P2. Gamepad menus need work.**
    - **What and why:**
      - Focus goes to the first tab, not the open one. The screenshot `UI08_controls_gamepad.jpg` rings GAME while CONTROLS is open.
      - Focus is also set for mouse users (`Screens.luau:854`, `Trade.luau:840`, `Inspect.luau:552`).
      - There is no shoulder-button tab switching.
      - The 3D inspect model turns only with a mouse or a finger (`Inspect.luau:447-472`).

16. **P3. The HUD ignores the notch.**
    - **What and why:** The HUD uses no screen insets and a 4 % left margin. That is 34 pt on an 844-pt phone, inside a notch inset of about 47 pt (`Hud.luau:64`, `242`).

17. **P3. The HUD stays on in the bunker.**
    - **What and why:** It shows full health, stamina, energy and water, which never change there. It stays drawn around every screen except the inventory (`Hud.luau:708`; screenshots `UI08`, `R7_style_screen.jpg`).

18. **P3. Item tiles carry a rarity stripe that EFT does not have.**
    - **What and why:** The stripe is ochre, orange, purple or red (`Inventory.luau:592-595`). EFT tints item backgrounds by type instead (unverified).

19. **P3. There is no loading screen of our own.**
    - **What and why:** Joining shows Roblox's default screen, and deploying is a fade (`Lobby.luau:565-660`). EFT shows matching and loading stages (unverified).

20. **P3. The post-raid flow is one report.**
    - **What and why:** There is no healing step, kill list or XP breakdown (`Screens.luau:548-583`), and the operator is fully healed outside a raid (`Character.luau:33-37`).
    - **EFT:** It opens a healing screen after the raid ([Alphr](https://www.alphr.com/escape-tarkov-heal-after-raid/)). Whether health carries over belongs to the health area.

21. **P3. Tasks cannot be pinned.**
    - **What and why:** EFT 0.16.7 added pinning active quests ([AltChar](https://www.altchar.com/game-news/escape-from-tarkov-patch-0.16.7.0-full-patch-notes-aP2RA1G8vdlq)). Our task lists are plain lists (`Trade.luau:621-686`), and the TASKS tab exists only in raid (`Inventory.luau:993`).

22. **P3. The game is English only, and the HUD cannot be translated.**
    - **What and why:** All text is hard-coded. The HUD's one-character labels (`Lens.luau:340-356`) cannot be put through Roblox's automatic translation. EFT has a language setting (unverified).

## Gaps vs EFT

| EFT feature | Ours | Gap |
|---|---|---|
| Health condition indicator; Always / auto-hide; Polychrome / Monochrome ([GGRecon](https://www.ggrecon.com/guides/escape-from-tarkov-best-settings-improve-fps-visibility/)) | Total health, energy and water numbers, always shown | Departure (finding 2) |
| Stamina and stance indicator, with the same options | Stamina number always shown, arm stamina as text | Departure |
| No ammo counter; fire mode shown only on change ([Gamepressure](https://www.gamepressure.com/escape-from-tarkov/using-weapons/z0cf2e)) | No ammo counter; fire mode always shown | Partial (finding 7) |
| Raid time shown by default; O twice lists the exits ([AltChar](https://www.altchar.com/game-news/escape-from-tarkov-patch-0.16.7.0-full-patch-notes-aP2RA1G8vdlq), [Biligame](https://wiki.biligame.com/eft/How_to_Play_Guide_for_Escape_from_Tarkov)) | Clock always shown; O twice on PC, one press on pad and touch | Matches; we write out requirements where EFT shows "?" (logged) |
| Quick slots 4 to 0, with Always / Autohide ([esports.net](https://www.esports.net/wiki/guides/best-escape-from-tarkov-settings/)) | Same, plus NEVER | Matches |
| Interaction list chosen with the wheel (unverified) | One action per prompt | Gap (rated P3 here; it belongs mainly to gameplay) |
| Inventory in three columns; INSPECT window | Built | Matches; not checked on phones |
| Drag helpers: fit cue, Ctrl+drag split, Del, double-click, middle-click | Ctrl+click, Alt+click and R only | Partial (finding 13) |
| Trader TRADE / TASKS / SERVICES | Built | Matches on PC; broken on phones (finding 1) |
| Flea market: search, filters by price, currency and condition, linked search, add offer, level 15 ([GGRecon](https://www.ggrecon.com/guides/escape-from-tarkov-flea-market/)) | Categories, search, WISH LIST, MY OFFERS, ADD OFFER with the fee, level 15 | No price or currency filters; no linked or required search |
| Messenger with notifications | Messenger with no unread state | Gap (finding 11) |
| Handbook, wish list | Built | Matches |
| Character tabs: Gear, Health, Skills, Maps, Tasks, Overall ([ClutchPoints](https://clutchpoints.com/gaming/escape-from-tarkov-beginners-guide-how-to-get-started)) | GEAR, HEALTH, SKILLS, MASTERING, OVERALL (TASKS in raid only) | No out-of-raid TASKS; no MAP tab |
| Task pinning (0.16.7) | None | Gap |
| Post-raid healing screen ([Alphr](https://www.alphr.com/escape-tarkov-heal-after-raid/)), kill list, statistics | One raid report | Gap (finding 20) |
| Settings: Game, Graphics, Sound, PostFX ([GGRecon](https://www.ggrecon.com/guides/escape-from-tarkov-best-settings-improve-fps-visibility/)) and Controls | GAME, GRAPHICS, POSTFX, SOUND, CONTROLS | Missing rows (finding 10); the tab order differs |
| Colour-blind mode with intensity ([GamersDecide](https://gamersdecide.com/articles/escape-from-tarkov-best-postfx-settings)) | None | Gap. Roblox cannot filter each colour channel of the 3D image, so only the UI can be recoloured |
| Key binds that act on press, release or continuously ([esports.net](https://www.esports.net/wiki/guides/best-escape-from-tarkov-settings/)) | A key plus one modifier | Partial |
| Proximity voice since 0.12.12 ([Gamepressure](https://www.gamepressure.com/newsroom/escape-from-tarkov-patch-01212-adds-new-map-and-voip/z03dd5)) | None; Roblox server-wide text chat stays on | Gap (finding 12) |
| Tutorial raid in 1.0 ([VidaExtra](https://www.vidaextra.com/fps/nunca-ha-sido-mejor-momento-para-iniciarse-escape-from-tarkov-pese-al-desastre-que-ha-sido-su-aterrizaje-steam)) | A welcome message | Gap (finding 6) |
| Main-menu access to every screen (bottom bar unverified) | Walk to a station; three keys | Gap (finding 3) |
| Loading and matching screens (unverified) | Roblox default, van fade | Gap (P3) |
| Language setting (unverified) | English only | Gap (P3) |

## Decisions

### ui-1. How should health and stamina show in a raid?
**Context.** Our HUD always shows total health, stamina, energy and water as large numbers. EFT shows a health-condition indicator and a stamina-and-stance indicator. Each can be always shown or auto-hidden, and exact numbers stay on the Health tab. On a phone our vitals take a third of the screen height.

| Option | What would be built | Effort | Phone perf | Parity |
|---|---|---|---|---|
| a. EFT's model | - A body outline at bottom left, with each part coloured by its condition.<br>- Effect icons beside it.<br>- Stamina, arm and breath bars that appear when they change.<br>- Energy and water only as warning icons; numbers only on the HEALTH tab.<br>- EFT's settings: HEALTH CONDITION and STAMINA AND STANCE (always / auto-hide / never), and HEALTH COLOUR SCHEME (polychrome / monochrome).<br>- Drawn in the bodycam style. | M | none | exact |
| b. Numbers that auto-hide | Keep the numbers. Show them for 4 s after a change or while below 50 %, plus the same settings. | S | none | partial |
| c. Keep as is | Always-on numbers. | S | none | departure |

**Recommended: a.** It matches EFT's scarce information and frees a third of a phone screen.

### ui-2. How strong should the bodycam overlay be on the HUD?
**Context.** The REC stamp, device line, corner brackets, red/blue split and glow on every glyph, grain, vignette and haze are the owner's bodycam look. They cost legibility, about 300 pt of a phone's top edge and about 400 labels. Their phone frame cost is not measured. They add identity, the REC/STBY state and the raid clock.

| Option | What would be built | Effort | Phone perf | Parity |
|---|---|---|---|---|
| a. Keep the full overlay as default everywhere | No change. | S | low | departure |
| b. A clean default | - Keep the REC dot and tag, the raid clock and the brackets.<br>- Drop the device line.<br>- Use the colour split only on the REC tag, so the numbers stay crisp.<br>- RECORDER OVERLAY becomes FULL / CLEAN / OFF. | S | none | partial |
| c. By device | Full overlay on PC and console, clean on phones. | S | none | partial |

**Recommended: b.** It keeps the bodycam identity and makes the numbers readable on every screen size.

### ui-3. How should the menus work on a 390-pt phone?
**Context.** The menus are laid out in fixed pixels for a laptop. On a phone the trader shows less than one row of goods, inventory cells are 24 pt and text is 9 to 13 pt (finding 1). Phones are most of Roblox's audience.

| Option | What would be built | Effort | Phone perf | Parity |
|---|---|---|---|---|
| a. Compact phone layouts | - Below about 500 pt of height, each screen becomes one panel at a time, with a tab rail.<br>- Inventory: GEAR / BAGS / STASH or LOOT. Trader: GOODS / STASH / DEAL.<br>- Text at least 13 pt, buttons at least 44 pt, cells at least 36 pt.<br>- Checked at 844x390, 667x375 and 932x430.<br>- PC keeps EFT's layout. | L | none | partial |
| b. Keep the layouts, fix the worst | - Full-screen windows on phones.<br>- A collapsible trader deal bar.<br>- Minimum 12-pt text and 32-pt cells, with more scrolling. | M | none | close |

**Recommended: a.** EFT's side-by-side columns cannot hold readable text and finger-sized cells at 390 pt.

### ui-4. How should items move on touch?
**Context.** Drag works only with a mouse. Touch players tap an item, then tap a cell, and they cannot turn the item. The cells are small.

| Option | What would be built | Effort | Phone perf | Parity |
|---|---|---|---|---|
| a. Touch drag and drop | - A long press (0.25 s) picks up; drag and let go to place.<br>- A ROTATE button shows while dragging.<br>- A double tap quick-moves; a long press with no drag opens the action menu. | M | none | close |
| b. Improve tap-and-place | Add ROTATE, larger cells and a green/red fit cue. | S | none | partial |
| c. Both | Drag first, with tap-and-place kept as a fallback. | M | none | close |

**Recommended: c.** Drag is EFT's own model, and tap-and-place helps players with small screens or less precise fingers.

### ui-5. What onboarding should new players get?
**Context.** We have one welcome message. EFT 1.0 added a tutorial raid with control signs and a lit path to the exit, followed by story missions. The Roblox audience is younger and newer.

| Option | What would be built | Effort | Phone perf | Parity |
|---|---|---|---|---|
| a. EFT 1.0-style tutorial raid | - A short scripted raid on its own small area, offered on first join.<br>- Control signs for the player's device.<br>- A guided first aid, loot and inventory lesson.<br>- The exit marked by a lit path.<br>- Then a three-task starter chain at the traders. | L | none | exact |
| b. A bunker boot camp | A guided first walk through Relay 7: locker, trader counter, a range drill, then the van, with hint cards. | M | none | partial |
| c. Hints only | First-time tips for each screen and the first raid, which players can dismiss, with a HINTS on/off setting. | S | none | partial |
| d. None | Keep EFT's pre-1.0 approach. | S | none | departure |

**Recommended: a.** It is now parity with EFT, and it addresses the audience's biggest risk: quitting early. Option c can ship first as a stopgap.

### ui-6. How do the screens open outside the walk-around bunker?
**Context.** The owner's rule is that every screen opens from its key, but only the inventory, settings and exits do. EFT reaches every screen from its main menu in one click.

| Option | What would be built | Effort | Phone perf | Parity |
|---|---|---|---|---|
| a. EFT's menu bar | - A bar of CHARACTER, TRADERS, FLEA MARKET, HIDEOUT, HANDBOOK, MESSENGER (with an unread count) and DEPLOY, usable anywhere in the bunker.<br>- Opened from a key, a pad button or a touch button.<br>- PC hotkeys for each screen.<br>- The stations still work. | M | none | close |
| b. PC hotkeys only | Gamepad and touch players walk to the stations. | S | none | partial |
| c. Walk-only | Correct the docs. | S | none | departure |

**Recommended: a.** It fulfils the owner's own rule and gives EFT's one-click access on every device.

### ui-7. What chat should raids have?
**Context.** Roblox's server-wide text chat is on in raids, so the dead and the bunker can call out positions. EFT has proximity voice since 0.12.12. Whether it lacks text chat in raid is unverified.

| Option | What would be built | Effort | Phone perf | Parity |
|---|---|---|---|---|
| a. Squad channel only | In raid, hide public chat and keep a squad-only channel. Full chat in the bunker. | S | none | close |
| b. No text chat in raid | Hide all text chat in raids. | S | none | close |
| c. a plus proximity voice | Add Roblox's spatial voice for raiders who have voice enabled (EFT's VoIP). | M | low | close |
| d. Leave as is | No change. | S | none | departure |

**Recommended: a.** It stops position call-outs and keeps squads usable. Voice (c) is an owner policy choice because of moderation and the age checks Roblox requires for voice.

### ui-8. Which accessibility settings should we add?
**Context.** EFT has a colour-blind mode (Protanopia, Deuteranopia, Tritanopia, with an intensity). We have only HUD SCALE, REDUCE MOTION and SCREEN SHAKE. Roblox cannot filter each colour channel of the 3D image, so a colour mode can only recolour the UI.

| Option | What would be built | Effort | Phone perf | Parity |
|---|---|---|---|---|
| a. Colour-blind palettes, menu text size and hints | - EFT's COLOUR-BLIND MODE row and its intensity, done as colour-safe HUD and menu palettes, keeping words and shapes next to every colour.<br>- MENU TEXT SIZE from 100 to 150 %.<br>- The HINTS toggle. | M | none | partial |
| b. Palettes only | The colour-blind palettes, nothing else. | S | none | partial |
| c. Nothing beyond HUD SCALE | No change. | S | none | departure |

**Recommended: a.** Text size matters on phones, and the colour row exists in EFT.

## Quick wins (no decision needed)

1. Put ROTATE back in the 40-pt info bar for touch and gamepad, and give it a pad button while an item is selected (`Inventory.luau:857-882`).
2. Ask before DISCARD, before selling a whole stack, and before any paid prompt on touch. Keep destructive buttons apart from the others (`Inventory.luau:486`, `Interact.luau:57-65`).
3. Show the weapon line only for about 4 s after a weapon switch, a fire-mode change or a check. Keep the malfunction flash (`Hud.luau:449-468`).
4. Hide the vitals in the bunker, and hide the HUD while any screen is open (`Hud.luau:708`).
5. Gamepad:
   - Focus the open tab, and only when a pad is in use (`Screens.luau:854`, `Trade.luau:840`, `Inspect.luau:552`).
   - Let LB and RB switch tabs.
   - Let the right stick turn the inspect model.
6. Mail: give the MESSENGER tab and the pigeonhole an unread count, and show a toast when mail arrives (`Economy.luau:28-33`).
7. Controls: add invert Y, separate MOUSE / GAMEPAD / TOUCH sensitivities, and sliders or hold-to-repeat for number settings (`Camera.luau:129-142`, `Screens.luau:781-792`).
8. Settings: reorder the tabs to EFT's GAME, GRAPHICS, SOUND, POSTFX, CONTROLS. Add MALFUNCTION NOTIFICATIONS and DOUBLE-CLICK QUICK USE.
9. Inventory: add a green/red fit cue while dragging, Del to discard (with the confirmation), middle-click to examine and double-click to use (`Inventory.luau:1219-1258`).
10. Touch:
    - Captions in the MORE tray.
    - Move MORE and LOOK off the centre line in the default layout (`TouchLayout.luau:45-46`).
11. Use the device's safe area for the HUD's left and right margins on notched phones (`Hud.luau:242`).
12. Loading:
    - A bodycam-style loading card at join (a ReplicatedFirst script).
    - Another card at insertion while the map streams in (`Raid.luau:386`).
13. Docs and tests:
    - Bring `EFT_PARITY.md` sections 2 to 5, KNOWN_ISSUES 12 and 51, and `DEVELOPMENT_STATUS.md:282` up to date.
    - Record Studio checks of the 2026-10-31 screens in TEST_RESULTS.
    - Fix the "opens from its key" claim (or build ui-6).
14. Let players pin tasks, and show the TASKS tab out of raid too (EFT 0.16.7).
15. Drop the "SCAV ONLY" tag from a scav's own exits list. Every row in it is a scav exit (`UI06_pc_scav_exits.jpg`).

## Sources

EFT:
- GGRecon, best settings (Game, Graphics, Sound and PostFX rows): https://www.ggrecon.com/guides/escape-from-tarkov-best-settings-improve-fps-visibility/
- esports.net, best settings (Game rows and options, bind modes): https://www.esports.net/wiki/guides/best-escape-from-tarkov-settings/
- GearUP, game settings (health and stamina indicators): https://www.gearupbooster.com/blog/best-escape-from-tarkov-game-setting.html
- GamersDecide, PostFX (colour-blind modes): https://gamersdecide.com/articles/escape-from-tarkov-best-postfx-settings
- Gamepressure, using weapons (no ammo counter, fire mode on change): https://www.gamepressure.com/escape-from-tarkov/using-weapons/z0cf2e
- AltChar, 0.16.7.0 patch notes (raid timer default, stash search, task pinning): https://www.altchar.com/game-news/escape-from-tarkov-patch-0.16.7.0-full-patch-notes-aP2RA1G8vdlq
- Biligame EFT wiki, how to play (O and double O, body-part colours): https://wiki.biligame.com/eft/How_to_Play_Guide_for_Escape_from_Tarkov
- GGRecon, flea market guide: https://www.ggrecon.com/guides/escape-from-tarkov-flea-market/
- ClutchPoints, beginner's guide (menu and Character tabs): https://clutchpoints.com/gaming/escape-from-tarkov-beginners-guide-how-to-get-started
- Alphr, healing after a raid (post-raid healing screen): https://www.alphr.com/escape-tarkov-heal-after-raid/
- VidaExtra, 20 Nov 2025 (the 1.0 tutorial raid): https://www.vidaextra.com/fps/nunca-ha-sido-mejor-momento-para-iniciarse-escape-from-tarkov-pese-al-desastre-que-ha-sido-su-aterrizaje-steam
- Insider Gaming (1.0 tutorial): https://insider-gaming.com/tarkov-getting-easier-first-time-decade/
- Multiplayer.it, 14 Nov 2025 (1.0 tutorial): https://multiplayer.it/notizie/escape-from-tarkov-tutorial-aiutare-chi-abbandona-gioco-subito.html
- Inven Global, 1.0 launch date (headline only): https://www.invenglobal.com/articles/19896/escape-from-tarkov-sets-november-15-launch-date-as-servers-begin-24-hour-patch-downtime
- Gamepressure, 0.12.12 adds VoIP (headline only): https://www.gamepressure.com/newsroom/escape-from-tarkov-patch-01212-adds-new-map-and-voip/z03dd5

Roblox and mobile:
- Roblox adaptive design guidelines: https://create.roblox.com/docs/production/publishing/adaptive-design
- Touch references already cited in `docs/design/TOUCH_CONTROLS.md`: Activision on CoD Mobile, and PocketGamer on PUBG Mobile and Arena Breakout.

Marked unverified in the text:
- EFT's health indicator is drawn as a body outline without numbers.
- EFT asks before a discard.
- EFT shows a green/red fit cue while dragging.
- EFT chooses interactions from a list with the mouse wheel.
- EFT has no text chat in raid.
- EFT's main-menu bottom bar.
- EFT's loading stages.
- EFT has a language setting.
- EFT tints item backgrounds by type.
- EFT does not show the time of day in raid.
- Apple's 44-pt minimum touch target (its accessibility guidelines page could not be fetched).
