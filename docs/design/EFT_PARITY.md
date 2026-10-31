# Tarkov parity: information, quality of life, settings and graphics

**Standing rule (owner, 2026-10-31):** build Zero Return as close as possible to Escape from Tarkov in every aspect,
less the exceptions below. Every task starts with research on how Tarkov does it and ends with a check that the
result is as exact a copy as the exceptions allow. This file is the checklist for the parts that are not core
gameplay: item information, inventory and menu quality of life, controls, settings and visuals. It was written after
the owner pointed out that weapons show no fire rate or damage in our game (research 2026-10-31, sources at the end).

## Exceptions (assumed; the owner can add or remove)

1. **Intellectual property.** Original names, item and map art, icons, fonts and map layouts; no real gun or gear
   brands; no Battlestate assets. Layouts, rules, numbers and behaviour are copied; the art is not.
2. **The owner's design choices.** The name Zero Return; the BODYCAM look (lens, grain, STBY/REC, the wide bodycam
   view); the Relay 7 bunker as a walk-around lobby (every Tarkov screen still opens from its key); one bunker per server.
3. **What Roblox does not let a game control.** Resolution, screen mode, VSync, frame-rate caps, DLSS/FSR, Reflex,
   anti-aliasing, texture and shadow quality belong to Roblox's own graphics slider; keys Roblox reserves (Esc, `/`,
   F9 and others); Roblox content rules (blood within the experience's maturity rating, no real-money gambling,
   filtered chat).
4. **Cross-platform.** Touch and gamepad versions of every screen and control (Tarkov is mouse and keyboard only),
   and budgets set by the 30 FPS floor on low-end phones.

## 1. Item information: the INSPECT window

Tarkov: any known item opens an inspect window with its name, a 3D model you turn with the mouse, the description,
and an attribute list (icon, name, value; handling stats with a bar). Unknown items show a silhouette until examined
(middle mouse in containers, stash and trader lists).

| Item | Tarkov shows | Zero Return before | To do |
|---|---|---|---|
| Weapons | Weight, grid size, ergonomics, vertical and horizontal recoil, accuracy (MOA), sighting range, effective distance, muzzle velocity, fire modes, rate of fire (RPM), caliber, default ammo and magazine, durability | Gunsmith screen: ergonomics, recoil V/H, MOA, sighting range, velocity. Inventory: one line of small text | Full attribute sheet with bars, RPM, fire modes, caliber, effective distance, durability |
| Weapon parts | Modifiers: ergonomics, recoil %, accuracy, muzzle velocity, sighting range, loudness (suppressors), capacity, load/unload and check speed and malfunction chance (magazines), heat and cooling, durability burn; compatible slots | Ergonomics, recoil %, accuracy % as text | All modifiers as rows, green or red by sign |
| Ammo | Damage and penetration (in the inspector since 0.14.5; hovering shows the effect against armor classes), armor damage, speed, bleeding chance, accuracy and recoil modifiers, tracer, subsonic | Damage, penetration, armor damage as text | Rows plus the per-class effectiveness on hover |
| Body armor, armored rigs, plates | Armor class, durability (now/max), material, armored areas (thorax, stomach, sides, back, throat, groin), plates with their class and areas, movement speed %, turn speed %, ergonomics % | Class and durability | Material, areas, penalties, plates |
| Helmets | Class, durability, material, areas (top, nape, ears, eyes, jaws), ricochet chance, sound reduction, what it blocks (earpiece, eyewear, face cover), penalties | Class and durability | The rest |
| Rigs, backpacks, cases | Grid layout, weight, penalties, what a case accepts | Capacity | Penalties, filters |
| Meds | HP resource, max per use, use time, what it cures (light and heavy bleeding, fractures) and its cost, painkiller duration, side effects | Description only (the data exists in `Items.luau`) | All rows |
| Food and drink | Energy, hydration, use time, effects | Description only | All rows |
| Headsets, keys, grenades | Hearing changes; uses left; fuse time and blast | Description only | Rows |
| Everything | Weight, grid size, found-in-raid mark, insured mark, durability bar | Weight, size, FIR, insured as text | Icons and bars |

## 2. Inventory and stash quality of life

| Tarkov | Zero Return | To do |
|---|---|---|
| Ctrl+click quick transfer, Alt+click equip, R rotates while dragging | Have | |
| Ctrl+drag splits a stack, Del discards the hovered item, middle mouse examines, double-click use (setting) | Partly | Split drag, Del, middle mouse, double-click |
| Hover an item in pockets or rig and press 4 to 0: quick slot; R + wheel picks the magazine to load | Missing | Quick slots and the bar |
| Context menu: inspect, open, use, equip, load and unload ammo, check magazine, fold stock, modding, tag (name and colour a container), filter by item, linked search, required search, add to wish list, insure, repair, discard | Some | Tag, searches, wish list, check magazine, repair |
| Stash search window by category or name (0.16.7), sort, priority window (0.16) | Missing | Search, sort, priority |
| Searching reveals container contents one by one; unknown items until examined | Have | |
| Counters on tiles: stack size, med resource, key uses | Stack only | Med HP, key uses |
| Weight against the overweight thresholds on the character screen | Partly | Weight bar |

## 3. Out-of-raid screens

| Tarkov | Zero Return | To do |
|---|---|---|
| Character: gear, health, skills, mastering, overall statistics, achievements, prestige, dog tag style | Profile tab (level, skills, karma, record) | Tarkov's character tabs |
| Traders: TRADE (assortment grid with prices; sell from stash), TASKS (pinnable since 0.16.7), SERVICES (insurance, repair, healing) | Buy, barter, sell, tasks as lists | Tarkov layout (task #56), services |
| Flea market from level 15: offers, filters, filter by item, linked and required search, wish list | Missing | Flea market |
| Messenger: one chat per trader, insurance returns, task rewards, receive all | Pigeonhole lamp only | Messenger |
| Handbook: every item by category with its description | Missing | Handbook |
| Wish list: items flagged for tasks, hideout or trading | Missing | Wish list |
| Hideout: modules, crafts, shooting range, customisation (0.16) | Have (in the bunker) | Customisation later |

## 4. In-raid information and controls

Tarkov shows no crosshair, no ammo counter and no minimap; you check things. Default keys:

| Action | Tarkov | Zero Return | To do |
|---|---|---|---|
| Check magazine (approximate count) | Alt+T | T | Move to Alt+T |
| Check chamber, fix malfunction | Shift+T | Missing | Add (with M11 part B malfunctions) |
| Fire mode / check fire mode | B / Alt+B | V / none | Move, add the check |
| Tactical device on, mode | T, Ctrl+T | L | Move |
| Inspect weapon (animation) | L | Missing | Add |
| Melee | V | 4 | Move |
| Quick slots | 4 to 0 | Heal on H | Quick slots |
| Prone | X | Z | Move; double Z drops the backpack |
| Time and exits | Double O (raid timer on by default since 0.16.7) | O (exits) | Add the time |
| Head device (NVG, face shield) | N | Missing | With NVG |
| Walk, walk speed, side step, blind fire, hold breath, switch sights, magnification, voice lines and gestures | Caps Lock, wheel, Alt+Q/E, Alt+W/S, Shift while aiming, Ctrl+RMB, Alt+RMB or Ctrl+wheel, Y and F1 to F12 | Some | The rest |
| Rebinding with press, double press, hold and release | Settings, Controls | Missing | Keybinding screen |

## 5. Settings

| Tab | Tarkov | Zero Return | Plan |
|---|---|---|---|
| Game | FOV 50 to 75, head bobbing, show quick slots, stamina and health (always, auto-hide, never), health colour scheme, highlight available operations, double-click quick use, vaulting mode, malfunction notifications, priority window, continuous healing | FOV (bodycam 85), sensitivity, shake, reduce motion, ADS toggle, reticle | Add the Tarkov rows that apply |
| Graphics | Texture and shadow quality, object LOD, overall visibility, AA, resampling, DLSS/FSR, HBAO, SSR, anisotropic, sharpness, Reflex, HQ colour, Z-blur, chromatic aberrations, noise, grass shadows, mip streaming, FPS limits | GRAPHICS preset (POTATO to HIGH), film grain | Same tab, our own rows for what we control (shadow lights, detail density, draw distance of props, grass, noise, chromatic aberration, blur); the rest goes to Roblox's slider (exception 3) |
| PostFX | Brightness, saturation, clarity, colourfulness, luma and adaptive sharpen, colour grading with intensity, colour-blind mode with intensity | Missing | Brightness, saturation, clarity, colourfulness, grading presets with original names, colour-blind HUD palettes |
| Sound | Volume sliders | Missing | Overall, effects, interface, music, voices |
| Controls | Sensitivity, aim sensitivity, invert, every bind | Sensitivity | Aim sensitivity, invert, rebinding |

## 6. Visuals

| Tarkov | Zero Return | To do |
|---|---|---|
| Time of day that follows a raid clock; weather (clear, overcast, rain, fog, wind; winter snow) | Weather and fog per raid | Raid clock, seasons |
| Per-material impacts, bullet holes, muzzle flash and smoke, tracers, blood | Have | Check against Tarkov in M15 |
| Pain darkening, tremor, tunnel vision, contusion, stun and flash white-out | Have | Check durations |
| Picture-in-picture optics, variable zoom, switch sights | Fixed zoom | Variable zoom and PiP (KNOWN_ISSUES 52-57) |
| Night vision and thermals | Missing | NVG and thermal sights |
| Face shield, glasses and gas mask overlays (cracks when hit) | Missing | Overlays |
| Full-body awareness, weapon inertia and sway (0.13.5), visual recoil with bolt movement and camera shake (0.16) | Arms, sway, recoil | Legs in view, bolt movement |

## Order of work

1. **Now (task #56):** the INSPECT window with the full attribute sheet for every item kind (a turnable 3D view in a
   ViewportFrame), tile counters, stash search and sort, the trader screen in Tarkov's TRADE / TASKS / SERVICES layout.
2. Controls parity (Tarkov's default keys, quick slots 4 to 0, the checks, the raid time, rebinding) and settings
   parity (Game, Graphics, PostFX, Sound, Controls tabs).
3. M11 part B (durability, malfunctions, check chamber) so the weapon side is complete.
4. Character tabs, messenger, handbook, wish list.
5. Border Yard, then flea market, then the Quay 7 and Smelter pass (the owner's map order stays).
6. Visuals: NVG and thermals, face overlays, variable zoom and PiP, raid clock and seasons.

## Sources

- Escape from Tarkov Wiki (Fandom): [Steyr AUG A1](https://escapefromtarkov.fandom.com/wiki/Steyr_AUG_A1_5.56x45_assault_rifle) (weapon fields), [6B13 assault armor](https://escapefromtarkov.fandom.com/wiki/6B13_assault_armor_(Flora)) (armor fields), [Performance modifiers](https://escapefromtarkov.fandom.com/wiki/Performance_modifiers)
- [CPG: ammo stats can now be seen in-game](https://consolepcgaming.com/escape-from-tarkov-ammo-stats-can-now-be-seen-in-game) (0.14.5)
- [GGRecon: best settings](https://www.ggrecon.com/guides/escape-from-tarkov-best-settings-improve-fps-visibility/) and [TarkovForge: graphics settings 2026](https://tarkovforge.com/blog/best-tarkov-graphics-settings-2025) (settings tabs)
- [GameSpot: controls and hotkeys](https://www.gamespot.com/articles/escape-from-tarkov-guide-for-controls-and-hotkeys/1100-6472601/), [Prima Games: controls](https://primagames.com/tips/escape-from-tarkov-complete-controls-guide)
- [TarkovForge: Salewa](https://tarkovforge.com/meds/salewa-first-aid-kit) (med fields), [Gamepressure: health and injuries](https://www.gamepressure.com/escape-from-tarkov/health-and-injuries/z1cf2f)
- Patch notes: [0.16.0.0 (Sportskeeda)](https://sportskeeda.com/esports/escape-tarkov-patch-notes-update-0-16-0-0-new-event-customs-rework-prestige-system), [0.16.7.0 (AltChar)](https://www.altchar.com/game-news/escape-from-tarkov-patch-0.16.7.0-full-patch-notes-aP2RA1G8vdlq), [1.0.4.5 (AltChar)](https://www.altchar.com/game-news/escape-from-tarkov-patch-1.0.4.5-improves-performance-reworks-weapon-balance-and-fixes-key-issues-aPJVC8b37l9m)
