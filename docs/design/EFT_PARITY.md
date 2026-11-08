# Tarkov parity: information, quality of life, settings and graphics

**Standing rule (owner, 2026-10-31):** build Zero Return as close as possible to Escape from Tarkov in every aspect,
less the exceptions below. Every task starts with research on how Tarkov does it and ends with a check that the
result is as exact a copy as the exceptions allow. This file is the checklist and gap log for every part: item
information, inventory and menu quality of life, controls, settings and visuals (sections 1 to 6), maps (7), AI (8),
core gameplay (9), economy (10) and art (11). It was started after the owner pointed out that weapons show no fire rate
or damage in our game (research 2026-10-31, sources at the end). Sections 8 to 11 come from the audit of 2026-11-07
(`docs/audit/2026-11-07/`, where their sources are), brought up to date on 2026-11-08.

## Exceptions (assumed; the owner can add or remove)

1. **Intellectual property.** Original names, item and map art, icons and fonts; no real gun or gear brands; no
   Battlestate assets. Rules, numbers, behaviour and screen layouts are copied; the art is not. **Maps copy Tarkov's
   layouts** (terrain, roads and where every building stands, at real scale) with our own buildings, interiors and
   names (owner, 2026-11-01; in the project instructions since then).
2. **The owner's design choices.** The name Zero Return; the BODYCAM look (lens, grain, STBY/REC, the wide bodycam
   view); the Relay 7 bunker as a walk-around lobby (every Tarkov screen still opens from its key); one bunker per server;
   the block body (art-3a, 2026-11-07). **The keys (ui-6a, 2026-11-08):** out of a raid Tarkov's menu bar sits under every
   bunker screen and opens on M (gamepad: hold View; touch: the menu button): HIDEOUT, CHARACTER, TRADERS, FLEA MARKET,
   HANDBOOK, MESSENGER with its unread count, and DEPLOY. Each screen also has a key: H, Tab, Y, U, K and J (ours: EFT gives
   them none). Settings are on P and, in a raid, the time and exits on O. The stations still open the same screens; the
   gunsmith bench and insurance open only at their stations or from the inventory.
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

**Status (checked against `Inspect.luau` on 2026-11-08):** the INSPECT window was built on 2026-10-31 from the plan below,
with a turnable 3D model (the picture when an item has no model) and the attribute rows for every item kind. Still not
shown: heat, cooling and durability burn on weapon parts; an ammo's effect against each armour class; plates (they come
with gameplay-2a); a helmet's sound reduction. The middle column is the state before 2026-10-31.

| Item | Tarkov shows | Zero Return before | To do |
|---|---|---|---|
| Weapons | Weight, grid size, ergonomics, vertical and horizontal recoil, accuracy (MOA), sighting range, effective distance, muzzle velocity, fire modes, rate of fire (RPM), caliber, default ammo and magazine, durability | Gunsmith screen: ergonomics, recoil V/H, MOA, sighting range, velocity. Inventory: one line of small text | Full attribute sheet with bars, RPM, fire modes, caliber, effective distance, durability |
| Weapon parts | Modifiers: ergonomics, recoil %, accuracy, muzzle velocity, sighting range, loudness (suppressors), capacity, load/unload and check speed and malfunction chance (magazines), heat and cooling, durability burn; compatible slots | Ergonomics, recoil %, accuracy % as text | All modifiers as rows, green or red by sign |
| Ammo | Damage and penetration (in the inspector since 0.14.5; hovering shows the effect against armor classes), armor damage, speed, bleeding chance, accuracy and recoil modifiers, tracer, subsonic | INSPECT: damage, penetration, armour damage, fragmentation, bleeding, calibre, bullet speed, recoil and accuracy modifiers (since 2026-11-08, economy-1a), subsonic, the tracer's colour | The per-class effectiveness on hover |
| Body armor, armored rigs, plates | Armor class, durability (now/max), material, armored areas (thorax, stomach, sides, back, throat, groin), plates with their class and areas, movement speed %, turn speed %, ergonomics % | Class and durability | Material, areas, penalties, plates |
| Helmets | Class, durability, material, areas (top, nape, ears, eyes, jaws), ricochet chance, sound reduction, what it blocks (earpiece, eyewear, face cover), penalties | Class and durability | The rest |
| Glasses, ballistic glasses, gas masks | Blindness protection (the share of a flash charge it stops), weight, grid size; ballistic glasses also armor class, durability, material and the eyes area; what the item blocks | Missing (no eyewear slot) | Built 2026-11-01: BLINDNESS PROTECTION, LENS TINT, class, durability, material (GLASS), the EYES area and BLOCKS rows. Plain glasses show no durability, as in Tarkov. Not run in Studio yet |
| Rigs, backpacks, cases | Grid layout, weight, penalties, what a case accepts | Capacity | Penalties, filters |
| Meds | HP resource, max per use, use time, what it cures (light and heavy bleeding, fractures) and its cost, painkiller duration, side effects | HP resource, uses, what it treats, painkiller time, use time; a stim's buffs and side effects with their timing (gameplay-4b) | Max HP per use and each cure's HP cost |
| Food and drink | Energy, hydration, use time, effects | Description only | All rows |
| Headsets, keys, grenades | Hearing changes; uses left; fuse time and blast | Description only | Rows |
| Everything | Weight, grid size, found-in-raid mark, insured mark, durability bar | Weight, size, FIR, insured as text | Icons and bars |

## 2. Inventory and stash quality of life

Updated 2026-11-08 from the code (`Inventory.luau`, `Inspect.luau`); the screens were built on 2026-10-31.

| Tarkov | Zero Return | To do |
|---|---|---|
| Ctrl+click quick transfer, Alt+click equip, R rotates while dragging | Have; ROTATE in the item bar for touch, gamepad and phones (ui.1) | |
| Ctrl+drag splits a stack, Del discards the hovered item, middle mouse examines, double-click use (setting) | SPLIT IN HALF in the context menu; DOUBLE-CLICK QUICK USE for meds and food (setting, ui.8); DISCARD wants a second press within 3 s (ui.2); Del discards the hovered item (in a raid it drops it) and the middle button examines or inspects (ui.9, 2026-11-08, Studio check pending) | An amount on Ctrl+drag |
| A green or red ghost while dragging shows whether the item fits (from memory, unverified: ui audit) | The cells the item would take light green or red while dragging, and for an item picked up by tap or pad (ui.9, 2026-11-08, Studio check pending). The cue can disagree with the server where only the server knows the rule (a longer magazine on a gun in the grid, a vital part locked in a raid) | Touch drag and drop (ui-4a) |
| Hover an item in pockets or rig and press 4 to 0: quick slot; R + wheel picks the magazine to load | Done: 4 to 0 bind by hover, the bar (AUTO-HIDE, ALWAYS or NEVER), the key on the tile | R + wheel to pick the magazine |
| Context menu: inspect, open, use, equip, load and unload ammo, check magazine, fold stock, modding, tag (name and colour a container), filter by item, linked search, required search, add to wish list, insure, repair, discard | Inspect, examine, equip, use, load and unload ammo, modding, split, insure, sell, repair with a kit, discard; + WISH in INSPECT | Tag, filter by item, linked and required search, check magazine, fold stock (KNOWN_ISSUES 53) |
| Stash search window by category or name (0.16.7), sort, priority window (0.16) | SORT, and SEARCH by name | Search by category; the priority window |
| Searching reveals container contents one by one; unknown items until examined | Have | |
| Counters on tiles: stack size, med resource, key uses | Done: stack, med HP, key uses, armour durability, rounds in a magazine; FIR, INS, wish (W) and quick-slot marks | |
| Weight against the overweight thresholds on the character screen | The total in kg, orange past 40 kg | The thresholds, as Tarkov shows them |
| Drag and drop with the mouse (Tarkov is PC only) | Mouse drag; since 2026-11-08 (ui-4c) touch drag too: a finger resting 0.25 s lifts the item (moving sooner scrolls), it follows the finger with the green / red cue, a ROTATE button turns it, letting go drops it; held and let go in place opens the action menu; a double tap quick-moves. On touch and gamepad, pick up then tap to place still works, kept across the phone panels (M2) | On a phone a drag stays inside the open panel (moving to another panel is tap-and-place); no auto-scroll at a list's edge while dragging; a real finger not yet tried (Studio's test bridge drives the same steps with a scripted finger) |

## 3. Out-of-raid screens

| Tarkov | Zero Return | To do |
|---|---|---|
| Character: gear, health, skills, mastering, overall statistics, achievements, prestige, dog tag style | Tabs in the inventory: GEAR, HEALTH, SKILLS, MASTERING, OVERALL; TASKS in and out of raid, active tasks pinnable to the top (ui.14, 2026-11-08, Studio check pending) | Achievements, prestige, dog tag style, a MAP tab |
| Traders: TRADE (assortment grid with prices; sell from stash), TASKS (pinnable since 0.16.7), SERVICES (insurance, repair, healing) | Done 2026-10-31: TRADE, TASKS and SERVICES (repairs: weapons at VOS, armour at TILDA); insurance at the insurance window and from the context menu; one panel at a time on phones (M2). HALE's SERVICES tab has TREATMENT since 2026-11-08 (gameplay-6b, checked in Studio) | Picking treatment lines (HEAL ALL only). Task pinning built (ui.14, 2026-11-08, Studio check pending) |
| Flea market from level 15: offers, filters, filter by item, linked and required search, wish list | Done 2026-10-31: level 15, categories, search, WISH LIST, MY OFFERS, ADD OFFER with Tarkov's fee; since economy-3a (2026-11-08) a market of real players across servers with sellers' names and ratings, cheapest first by the price of one unit, partial purchases or packs, and EFT's ten BARTER ITEMS folders in BROWSE and the HANDBOOK (section 10) | Price, amount, condition and currency filters; filter by item, linked and required search; expiring-only filter; the FLEA screens keep PC-width columns on phones |
| Messenger: one chat per trader, insurance returns, task rewards, receive all | Done 2026-10-31: trader dialogs, insurance returns with RECEIVE ALL, task, loyalty and flea messages; an unread count and a notice when mail comes (ui.6) | |
| Handbook: every item by category with its description | Done 2026-10-31 (relay radio, HANDBOOK); flares under SPECIAL EQUIPMENT (economy.11, 2026-11-08) | |
| The footer: one click to the main menu, hideout, character, traders and flea market; the messenger and handbook beside them | The menu bar (ui-6a, 2026-11-08): HIDEOUT, CHARACTER, TRADERS, FLEA MARKET, HANDBOOK, MESSENGER (unread count), DEPLOY, under every bunker screen and on M, hold View or the touch menu button; a key per screen (H, Tab, Y, U, K, J: ours) | No main menu (the bunker is ours, exception 2); EFT's exact order and icons were not found documented |
| Wish list: items flagged for tasks, hideout or trading | Done 2026-10-31: + WISH in INSPECT, a W on the tile, the flea market's WISH LIST | |
| Hideout: modules, crafts, shooting range, customisation (0.16: wall finishes "Blue paint", "Factory walls", "Modest wallpaper"; floors "Small tiles", "Factory floor"; a "Factory ceiling"; unlocked by level, tasks, achievements and prestige; posters as hideout upgrades and loot; range targets by leveling the range) | Since 2026-11-08 (economy-7b) fourteen modules in one HIDEOUT screen (H or the menu bar): one module open at a time, have / need requirements in colour and words, fuel, farm and scav controls, LB / RB between modules; the bunker's bays open their module; STYLE since 2026-11-02: walls (7), floor (5) and ceiling (4), drawn per player on each client, unlocked by level (`docs/design/HIDEOUT_STYLE.md`); a free practice range in the lobby beside the range module | Unlocks by tasks, achievements and prestige; posters; range targets; Relay 7 stations for the six modules without a bay |

**Skills (2026-11-01):** 24 skills in Tarkov's four groups, levels 0 to 51 (level n costs min(10n, 100) points), raid fatigue, Health and Charisma growing from their groups, each with a working effect. MASTERING since 2026-11-02 (`docs/design/MASTERING.md`). Missing: ACHIEVEMENTS, PRESTIGE, friends and chat.

## 4. In-raid information and controls

Tarkov shows no crosshair, no ammo counter and no minimap; you check things. Default keys:

| Action | Tarkov | Zero Return | To do |
|---|---|---|---|
| Check magazine (approximate count) | Alt+T | Done: Alt+T | - |
| Check chamber, fix malfunction | Shift+T | Done: Shift+T | - |
| Fire mode / check fire mode | B / Alt+B | Done: B / Alt+B | - |
| Tactical device on, mode | T, Ctrl+T | Done 2026-11-02: T, and Ctrl+T cycles a combo between light, laser and both; lasers draw a beam and a dot (section below) | - |
| Inspect weapon (animation) | L | Done: L | - |
| Melee | V | Done: V | - |
| Quick slots | 4 to 0 | Done: 4 to 0 | - |
| Prone, drop the backpack | X, double Z | X | Double Z to drop the backpack |
| Time and exits | Double O (raid timer on by default since 0.16.7) | Done: O shows the time, twice lists the exits | - |
| Head device (NVG, face shield) | N | Done 2026-11-01: N flips goggles or raises the face shield | - |
| Stationary guns (NSV, AGS-30): man the gun, aim, fire, leave | F is Interact; Tarkov documents no control for them, so how to leave and how to zoom were not found | Done 2026-11-01 with controls of our own: the prompt (F, pad X, tap) mounts; mouse / right stick / screen drag aims; fire and zoom follow the Fire and Aim keys, right trigger and left trigger, the FIRE and ZOOM buttons; F, B or LEAVE gets off (section below) | Sounds, animation, the real positions |
| Walk, walk speed, side step, blind fire, hold breath, switch sights, magnification, zeroing, voice lines and gestures | Caps Lock, wheel, Alt+Q/E, Alt+W/S, Shift while aiming, Ctrl+RMB, Alt+RMB or Ctrl+wheel, Page Up/Down, Y and F1 to F12 | Walking speed on the wheel (crouch depth on C + wheel), hold breath (Shift while aiming), magnification (Alt+RMB, in steps) and zeroing (Page Up/Down) | Walk toggle, switch sights, voice lines, gestures. Blind fire and side step are left out by the owner's pick gameplay-5b |
| Rebinding with press, double press, hold and release | Settings, Controls | Done 2026-10-31: every PC key in Settings, CONTROLS, as a key plus one modifier (Ctrl, Alt or Shift) | Press, double press, hold and release modes |
| Health and stamina on screen | Health condition and stamina-and-stance indicators, each always shown or auto-hidden; health in Polychrome or Monochrome (GGRecon) | Built 2026-11-08 (ui-1a, checked in Studio on a PC): a body outline bottom left (top left on touch, where the stick is not) whose seven parts go green, yellow, orange, red and black, the effects as icons beside it, energy and water only as warnings under a quarter; stamina and arm bars over the weapon line with a stance marker (a bar as tall as the stance, flat when prone, blue arms while holding breath); numbers only on the HEALTH tab; in a raid only | The outline and marker are ours (lines, not Tarkov's drawn figure); the auto-hide times (5 s, 1.5 s) and the quarter warning are ours; the touch layout not seen yet (device emulator) |
| Weapon and fire mode on screen | No ammo counter; the fire mode shows only when it changes | Done (ui.3): the weapon corner shows for 4 s after a switch, a fire-mode change or a check, and stays while a malfunction flashes; no ammo counter | - |
| Interacting | A list of actions picked with the mouse wheel (unverified: ui audit) | One action per prompt | The action list |
| Talking in a raid | No text chat in a raid (unverified); proximity voice since 0.12.12 | Since 2026-11-08 (ui-7a): no public text chat to or from a raider; a squad channel reaches the squad, in a raid and out; the bunker keeps the public channel | Proximity voice (ui-7c, not picked) |
| Gamepad and touch (exception 4: Tarkov is keys and mouse only) | none | Done 2026-11-02: every control above but the slot keys and quick slots has a gamepad and a touch way (the next weapon and MED stand in for those). Settings, CONTROLS lists them on that device. Touch layout v2: icon buttons, tap and hold pairs, a MORE tray with captions (ui.10), a med wheel, a walk-and-run stick, FIRE that aims and steers, and an editor for every control (`docs/design/TOUCH_CONTROLS.md`, sections below). Phone menus show one panel at a time below 500 pt of height (M2); the HUD keeps inside the safe area (ui.11) | A real controller and phone |

## 5. Settings

Updated 2026-11-08 from `Screens.luau` (`SETTING_TABS`). The tabs are in Tarkov's order: GAME, GRAPHICS, SOUND, POSTFX,
CONTROLS (ui.8). Graphics level, FOV, sensitivity and grain are kept per kind of device; phones start at LOW, consoles at
MEDIUM and PCs at HIGH (tech-3b, M1). Numbers move with - and +, which repeat while held (ui.7); there is no slider.

| Tab | Tarkov | Zero Return | Plan |
|---|---|---|---|
| Game | FOV 50 to 75, head bobbing, show quick slots, stamina and health (always, auto-hide, never), health colour scheme, highlight available operations, double-click quick use, vaulting mode, malfunction notifications, priority window, continuous healing | FIELD OF VIEW (50 to 100, bodycam 85), HEAD BOBBING, SCREEN SHAKE, REDUCE MOTION, AIM MODE, QUICK SLOTS (AUTO-HIDE, ALWAYS, NEVER), HEALTH CONDITION and STAMINA AND STANCE (ALWAYS SHOWN, AUTO-HIDE, NEVER), HEALTH COLOR SCHEME (POLYCHROME, MONOCHROME), CENTER DOT, HIT FEEDBACK, HUD SCALE, CURVED HUD, MALFUNCTION NOTIFICATIONS, DOUBLE-CLICK QUICK USE; ours (ui-8a, 2026-11-08): MENU TEXT SIZE (100 to 150 %, per device: the menu screens drawn larger, laid out for the smaller screen) and HINTS (off, a prompt shows no key, the menu bar no keys and the HUD no "how to" words, as in Tarkov) | Highlight available operations; vaulting mode; priority window; continuous healing |
| Graphics | Texture and shadow quality, object LOD, overall visibility, AA, resampling, DLSS/FSR, HBAO, SSR, anisotropic, sharpness, Reflex, HQ colour, Z-blur, chromatic aberrations, noise, grass shadows, mip streaming, FPS limits | GRAPHICS (POTATO to HIGH), HOLD 30 FPS, FILM GRAIN, LENS EFFECTS, MOTION BLUR, RECORDER OVERLAY (ui-2b: FULL, CLEAN by default, OFF) | Our own rows for what we control (shadow lights, detail density, draw distance of props, grass, chromatic aberration); the rest is Roblox's slider (exception 3) |
| PostFX | Brightness, saturation, clarity, colourfulness, luma and adaptive sharpen, colour grading with intensity, colour-blind mode with intensity | BRIGHTNESS, SATURATION, CLARITY, COLOR GRADING (NONE, STEEL, EMBER, MOSS, DUSK) and GRADING INTENSITY; COLORBLIND MODE (NONE, PROTANOPIA, DEUTERANOPIA, TRITANOPIA) and COLORBLIND INTENSITY since 2026-11-08 (ui-8a): the HUD's and the menus' colours are daltonized (the lost difference moved into the channels that type still sees: red reads pink against green for a deuteranope) | Colourfulness and the two sharpen sliders; the colour-blind filter on the 3D image itself (Roblox cannot filter each colour channel of it) |
| Sound | Volume sliders: overall, interface, music, chat, VoIP | OVERALL VOLUME, EFFECTS, INTERFACE, AMBIENCE | Music, chat and voice once the game has them |
| Controls | Sensitivity, aim sensitivity, invert, every bind | MOUSE, AIM, GAMEPAD and TOUCH SENSITIVITY, INVERT Y AXIS (ui.7), touch AIM WHEN FIRING and FLOATING STICK, and every PC key rebindable (section 4) | Bind modes (press, release, hold, double press) |

## 6. Visuals

| Tarkov | Zero Return | To do |
|---|---|---|
| Time of day that follows a raid clock; weather (clear, overcast, rain, fog, wind; winter snow) | Raid clock, weather and fog per raid; seasons from the real calendar (2026-11-01: winter snow and frost, autumn foliage and more rain, spring greener) | - |
| Per-material impacts, bullet holes, muzzle flash and smoke, tracers, blood | Since 2026-11-08 (art.3 to art.5): a muzzle flash of two or three frames sized by the muzzle device (a brake bigger, a flash hider smaller, a suppressor only smoke) with a wisp of smoke, in first person too; impacts by surface (sparks, splinters, dirt, grit and dust, a splash) and chipped-ring bullet holes; ejected cases from your gun and from shooters within 60 studs (at most 20, kept 20 s); tracers for tracer rounds only; a dark red puff on a body hit. Before that the audit found one grey puff for every surface and a 4 cm flash (art finding 5) | Blood marks on walls, floors and bodies (art-7a; the Moderate label is the owner's call when publishing). Seen in Studio: dust puffs, cases and holes; not yet seen: the flash, sparks, splinters, a splash (TEST_RESULTS, batch 5) |
| Pain darkening, tremor, tunnel vision, contusion, stun and flash white-out | Have | Check durations |
| Picture-in-picture optics, variable zoom, switch sights | Variable zoom done 2026-11-01 (Alt + right mouse steps the V6 between 1x, a red-dot view and 6x; kept per scope). PiP is not possible in Roblox (no rendering the world into a lens), so a scope zooms the whole view behind its mask (exception 3) | Switch sights (Ctrl + right mouse) once builds can carry a backup sight |
| Ballistics: bullets fly with drop and travel time by muzzle velocity, zeroing (Page Up / Page Down) | Done 2026-11-01: drop and travel time by muzzle velocity, AI aim for it, zeroing with Page Up / Page Down in Tarkov's steps | Per-scope zeroing lists, if needed |
| Night vision and thermals | Goggles done 2026-11-01: four night-vision tubes (monocular circle, two binoculars, panoramic quad; phosphor colour, gain, grain, light flare each) and thermal goggles, on mounted helmets or a head strap, drawn on characters up or down (ZR_EyeGear); the faceplate helmet's shield (raised = face open to hits, lowered = visor tint) | Night-vision and thermal scopes, the flip animation of the mount, AI wearing goggles at night |
| Face shield, glasses and gas mask overlays (cracks when hit) | Face shield: a tinted visor round the view (N). Glasses and gas mask built 2026-11-01: a mild lens tint per item, blindness protection against stun charges, the mask's rubber frame with smoked lenses; both step aside while night-vision goggles are down | Cracks when hit, the mask's breathing loop, fogging and raindrops (notes below) |
| Full-body awareness, weapon inertia and sway (0.13.5), visual recoil with bolt movement and camera shake (0.16) | Arms, sway, recoil | Legs in view, bolt movement |
| Audio: Steam Audio reverb and occlusion from the geometry (0.12.6 on, occlusion reworked in 0.16.7.0); indoor and outdoor sound; Interchange's mall soundscape | Written 2026-11-01: one reverb for the listener's space (7 classes plus marked floors), room tone, mains hum with the power, car park tone, drips, the IRONSIGHT siren, the substation generator, dust in the skylights (MEDIUM and up); far shots only from real shots since 2026-11-07 (gameplay.13). Everything from the ambience atlas is silent: the asset in `Sounds.AMB_ATLAS` loads as 0.0 s long (KNOWN_ISSUES 73) | The owner re-uploads `ZR_SFX_Amb` (gameplay.17), then levels are set by ear. World one-shots on Border Yard are occluded since 2026-11-08 (gameplay-3a, the notes "Sound through walls" near the end); the other maps, the ambience loops and the phones' fallback check are still open |

### Eyewear, gas mask and goggles on characters (2026-11-01)

Researched first (sources below), then built. Status: written and passed through `tools/luau_check.py` only. The new
LogicTests and CharTests checks, the overlays and the 16 character meshes have not been run in Studio, in Blender or on
a phone or console.

Matched:
- **EYEWEAR slot** after FACE COVER in the gear column (`Items.SLOTS.eyes`, kind `eyewear`), with the touch and gamepad
  layout of every other slot. The slot accepts nothing else, and the gas mask is a FACE COVER item.
- **Items** with Tarkov-like weight, grid size, value order and durability: Sport Sunglasses (brown, 2x1, 0.05 kg), Range
  Glasses (yellow, 1x1, 0.03 kg), BG-1 Ballistic Glasses (clear, class 1, durability 25, 0.11 kg: the numbers of the 6B34,
  AFGlass and Condor), AF-2 Anti-Fragmentation Glasses (blue, class 2, durability 30, 0.27 kg: the Caiman's numbers) and
  the Canister Gas Mask (FACE COVER, 2x2, 0.45 kg: the GP-5's weight). Only the two ballistic glasses have armor and a
  durability, as in Tarkov.
- **Blindness protection:** every lens stops a share of a stun charge's white-out (10 to 15 percent; Tarkov's range is
  5 to 35). Glasses and the mask stack. The share comes from the worn item, never from the client's say-so.
- **Eyes zone:** a hit on the front of the head at eye height goes to the ballistic glasses (penetration chance by
  class, durability loss, blunt damage when stopped, nothing once worn out). A face-plate helmet takes the hit first
  while its plate is down; the glasses sit behind it once it is raised.
- **What blocks what:** helmets and face shields leave the eyewear slot free (Tarkov's pages for the Kolpak-1S, the
  EXFIL and the Maska-1SCh list no eyewear block), so HELMET_C5 does not block it. The gas mask and glasses refuse
  each other either way round (`GAS_MASK_BLOCKS_EYEWEAR`).
- **Traders and loot:** TILDA (our Ragman) sells the sunglasses at LL1, the range and BG-1 glasses at LL3 and the AF-2 at
  LL4, buys eyewear and repairs ballistic glasses. The gas mask is loot only (Tarkov's traders do not sell gas masks for
  cash); some AI wear glasses and a few a gas mask.
- **INSPECT:** BLINDNESS PROTECTION, LENS TINT, class, durability, material GLASS, the EYES area and BLOCKS.
- **Overlays** (`Eyewear.luau`, client): its own colour grade per lens and, with the mask, a rubber frame with slightly
  smoked lenses. They own their instances (`ZR_Eyewear`), so they cannot fight the goggles or the face shield, and
  they hide while goggles are down. Not quality-gated, like the other grade effects.
- **On characters:** glasses and mask are drawn on every character; night-vision goggles show on the helmet mount or
  strap, flipped up by default and down over the eyes after N.

Gaps (not copied):
- **Eyes are a band, not a hit area of their own.** Tarkov lists the eyes among a head's hit areas (the helmet row
  above); here the eye band is worked out from where on the head the shot landed (`Health.armorFor`), and the damage
  goes to the head pool. The body has no separate eyes pool.
- **No breathing loop for the mask.** The sound atlases hold only the one-shot `breath_heavy` and `breath_release`; a
  loop needs a new original sample.
- **Not modelled:** the mask's filter and gas protection, fogging and raindrops on the lenses, cracks on the lenses or
  glasses when hit, and the glasses' glow in the dark.
- **Class of the 6B34.** The brief asked for a class 2 pair "like the 6B34", but TarkovForge lists the 6B34 as class 1
  (durability 25, 0.12 kg) and the Caiman visor as class 2 (durability 30). The clear BG-1 follows the 6B34 and the blue
  AF-2 the Caiman.
- **Gas mask blocks eyewear is unverified.** The brief for this feature asked for it. The wiki page of a mask that loaded
  lists "Blocks Eyewear: No" (Jason mask), and the GP-5 and MSA pages failed to load, so Tarkov's rule for gas masks was
  not seen. Remove `blocks` from `VIS.GAS_MASK` if Tarkov lets both be worn.
- **Slot position unverified.** No source showed where Tarkov puts the eyewear slot; it sits beside the body armour, with
  the cells to its right free for an armband.
- **Plain glasses have no durability** and so no repair; ballistic glasses repair at TILDA like any armor.
- **No gamepad binding for N** (the existing head-device key); the touch button exists.
- **No pictures yet:** the five items have no inventory picture or loose-loot model (the item art set has 124 pictures);
  their tiles show the item colour and short name, and loose ones lie as a coloured block until an art pass.
- **Meshes:** built and uploaded 2026-11-01 (batch ZR_EyeGear, 16 meshes); the five items still use the generic inventory picture.

### Stationary (mounted) guns (2026-11-01)

Researched first (sources below and in `docs/design/STATIONARY_WEAPONS.md`, which has the rules, numbers, controls and the
tests), then built. Status: written and passed through `tools/luau_check.py` only. The new "stationary" LogicTests group, the
mounted camera, the gamepad and touch controls and the guard AI have not been run in Studio or on a phone or console.

Matched:
- **Two guns for Tarkov's two:** the HMG-12 "Bastion" for the NSV Utyos (650 RPM, 12.7 mm, the unofficial B-32 round: 182 damage,
  88 penetration) and the AGL-30 for the AGS-30 (425 RPM, a 30 mm round that bursts like a frag). Both spawn full each raid
  and cannot be reloaded; one operator at a time; players and posted guards can use them.
- **Rounds are real bullets** with drop, drag and travel time through the same hit path as every weapon (armour, hit zones,
  bleeds, propane, doors); the launcher's rounds burst through the grenade system. The gun shakes the camera when fired.
- **The AGS's two numbers while aiming** (arc and zeroing) are shown on the AGL-30.

Gaps (not copied or not found):
- **No documented controls in Tarkov** (F = Interact only): the mount and leave keys, the zoom, the mouse, trigger and stick
  mappings and the touch buttons are ours.
- **Not found, so ours:** belt sizes (100 and 30), traverse and elevation limits (70 left and right, +40 / -20; 60, +55 / -14),
  zoom (2x and 3x), spread and bloom, the VOG-30 blast numbers (150 fragments of 24 to 38 within 16 studs, blast 85 within 4.5),
  the arming distance (20 studs). No overheating, as none was found.
- **The AGL-30's zeroing is fixed** and its "arc" is the elevation in degrees; in Tarkov the arc is a number (such as -.02) that
  sets where the grenade lands and the zeroing only fine-tunes the alignment.
- **Ammo counter:** the HUD shows the gun's rounds (`87 / 100`) although Tarkov shows no counter; asked for in the task.
- **Positions:** only two guns, on the Bastion roof of Border Yard, placed by us. Tarkov has NSV and AGS guns on Customs, Ground
  Zero, Lighthouse, Reserve, Shoreline, Streets (and the NSV on Woods and Interchange); no source gave a position.
- **Bots:** only posted guards use a gun (in sight, inside the arcs and range, short bursts); Tarkov's bots use them in more
  ways and its AI handling was fixed in 2023 and 2024 (the details were not found).
- **Art and audio:** no mounting animation (the raider is moved to the spot), no operator pose on the grips, models built from
  parts, the shot sound is the rifle recording pitched down and louder.
- **Not run:** nothing above has been run in Studio, on a phone, on a gamepad or on a console, and no frame rate was measured.

### Atmosphere and ambience (2026-11-01)

Owner request: atmosphere and ambience that improve realism without costing performance (30 fps minimum). Researched first
(sources below, notes and costs in `docs/look/ATMOSPHERE.md`), then built. Status: written and passed through `tools/luau_check.py`
only. Nothing has been run in Studio, on a phone or on a console, no frame rate was measured, and no level was set by ear. The
sound asset `assets/audio/out/ZR_SFX_Amb.ogg` (698 KB, 11 sounds) was uploaded on 2026-11-01 and its id is in `Sounds.AMB_ATLAS`
(136853086315408, the upload with the glass sounds). Studio read it as 77.8 s long once that day, but as 0.0 s on 2026-11-02 and
again in the audit of 2026-11-07, so all of it is silent until the owner re-uploads `ZR_SFX_Amb` (KNOWN_ISSUES 73, gameplay.17).

Matched (as far as Roblox allows):
- **Indoor and outdoor sound:** Tarkov keeps an indoor / outdoor state for sound and runs Steam Audio reverb from the geometry. Here
  the listener's space is measured with at most 8 raycasts every 0.4 s and `SoundService.AmbientReverb` follows (Plain outdoors,
  Alley between buildings, Room, Hallway, StoneRoom, Auditorium for the anchor halls, ParkingLot in the car park; Bathroom, StoneCorridor
  and StoneRoom on marked floors), with hysteresis so it never flickers. POTATO has none, LOW only indoors.
- **Interchange's switchable parts:** the power lever now also changes sound (the mall hums only with the power on, the substation
  generator runs), and the Kiba Arms alarm now has its siren: it starts with the red lamp 3 s after the front door opens and stops at
  the security terminal (existing rule, 60 s cap).

Gaps (not copied or not found):
- **Per-source reverb and occlusion only on Border Yard so far** (gameplay-3a, 2026-11-08; the notes "Sound through walls"
  near the end). There, world one-shots play through Roblox's Acoustic Simulation: occlusion, bending round corners and
  reverb from the geometry, as Steam Audio does for Tarkov. Elsewhere, and on POTATO, a world sound counts the walls
  between it and you once as it starts (ours). Ambience loops and your own sounds stay legacy `Sound`s with one reverb for
  the listener.
- **Not in any source, so our design:** the mall's room tone, the fluorescent and mains hum, the car park tone, the drips, the dust
  in the skylights. Tarkov's Interchange soundscape (empty mall, wind, arcade, escalators) was not found documented anywhere.
- **Distant gunfire was scripted** (a faint burst every 40 to 120 s, tied to no one). Removed on 2026-11-07 (gameplay.13): only
  real shots are heard, and one too far for its own sound (560 to 2,400 studs) plays the distant boom from its direction.
- **Siren length and sound:** how long the Kiba alarm rings is not documented; ours is the existing 60 s. The sound is a procedural
  warble, not a recording.
- **Machines with power on** (escalators, arcade cabinets, announcements, lifts) are not built; only the hum.
- **Dust** is a column under the pane, not the sun's slanted shaft, and not tied to the actual lit floor area.
- **Levels and thresholds are untested by ear and by frame rate:** the space thresholds (section 3 of `docs/look/ATMOSPHERE.md`), the
  layer volumes, the Auditorium choice for the biggest halls (Hangar is a one-word change).
- **Roblox sound API not verified:** the region semantics of `Sound` (`PlaybackRegion`, `LoopRegion`) and `Stop` / `Play` on a region
  are not described on the Roblox pages that could be read; the code uses them the way the existing atlases do.
- **Not run:** nothing above has been run in Studio, on a phone or on a console, and no frame rate or memory was measured.

## 8. AI

From the audit's AI report (`docs/audit/2026-11-07/ai.md`: SPT bot data, the wiki), brought up to date on 2026-11-08 from
`AI.luau`, `Config.luau`, the maps' `Play.luau` and the M3 entries in section 7.

Matches Tarkov now:
- **Bosses, each on its own roll:** THE BROKER (Reshala: the dorms, the fuel stop or the Bastion, 45 %, 752 health, four
  guards of 630 spread round him, no armour), THE HOUNDS (the Goons), THE CULT (cultists, warriors at 850), THE FORESTER
  (Partisan), THE CARETAKER (Killa: 890 health, five double pockets) and THE STOKER (Tagilla). Smelter rolls THE STOKER at
  30 % and THE CULT at 8 % in night raids, as Factory does. Bosses and their crews ignore the AI cap (EFT's IgnoreMaxBots).
- **Player scavs:** the Caretaker, the cultists, MORTAR and KESTREL shoot them on sight; the other bosses leave a scav alone
  while its karma holds (EFT's data, ai.4).
- **Scav groups:** alone, in pairs or in threes; the leader wanders and the others follow (ai.8). A follower whose leader
  dies keeps his own group's route (ai.7).
- **EFT's numbers for senses and aim (ai-3a, 2026-11-08, Studio check pending; `src/shared/BotData.luau`, from SPT's copy
  of the game data):** sight and cone per role (scavs 125/129/137 m over 70/70/75° each side by difficulty, raiders
  127 m, Reshala 140 m, Killa and Tagilla 137 m all round, Big Pipe 170 m, Birdeye 250 m); notice time 0.1 s close, 1 s
  at 90 m, 3 s at 160 m (bosses faster); calm bots see less far; hearing 10/30 m for scavs (26/56 raiders and Reshala,
  36/66 Killa, Tagilla, Goons, cultists); memory 52 s (Knight 104 s) and 22 s of searching; aim that starts wide and
  settles; a hit knocks a scav's aim 19-32° for 1.17 s; EFT 1.0's narrower cones, first-contact delay, repeat
  detection and no head aim on someone unseen for 15 s; rain cuts sight by up to 35 %; scavs roll easy, normal or hard
  10/50/40 per spawn. Our roles without an EFT twin: the Watch as raiders, the Foreman as Glukhar, the Sawyer as Shturman.
- **Sleep (ai-2, 2026-11-08, Studio check pending):** calm bots more than 300 m from every raider sleep and wake inside
  265 m (EFT's DistToSleep and DistToActivate).
- **Player scavs' window (ai-7a, 2026-11-08, Studio check pending):** from 17 minutes in on Border Yard and Meridian
  (from the start on Smelter and Quay 7), at scav spots away from raiders; a queue of scavs alone starts a raid already
  17 minutes along.
- **Senses (ours, kept):** sight builds awareness over time; rain and fog shorten it; no seeing through vegetation; weapon lights give
  you away; doors a player works are heard within about 19 m (ai.12); a hit or near miss gives a rough position, not the
  exact one (ai.13).
- **Fighting:** cover, peeking, suppression, healing with real meds, grenades, doors, searching the last known position;
  posted guards man the mounted guns; scavs come in waves through the raid.
- **Ours (performance, exception 3):** AI stream in whole and skip unused humanoid states (ai.10, ai.11); far AI keep moving
  in a scope (ai.9).

Still a gap:

| Tarkov | Zero Return | To do |
|---|---|---|
| Every bot's own sight, cone, notice time, hearing, memory, aim settling and hit knock | Ported (ai-3a, above). Read as ours: VisibleAngle as degrees off the look direction (read as the whole cone, every cone halves and Killa would not see behind him); the 1.0 presets taken over the bot files; notice time past 160 m extrapolated | Check in Studio; the gunfire hearing radius stays ours (EFT gives no figure); HearingSense, DISPERSION_COEF, per-role ScatteringPerMeter, MAX_AIMING_UPGRADE_BY_TIME and PANIC_* not ported |
| Each spawn wave carries its own difficulty (Customs' dorm and scav-base waves hard) | Every scav rolls the map's 10/50/40 | With ai-2b's waves |
| Scav caps per map (Customs 19, Interchange 30); bots leave after 20 to 30 min | 10 scavs at most (`SCAV_CAP`) and 18 AI in all (`AI_MAX`); they sleep beyond 300 m (ai-2) but never leave | ai-2b: EFT's caps, after a live-server test at 20, 30 and 45 AI (needs the private test place) |
| Scav groups of up to four or five | Three at most (45 % alone, 45 % pairs, 10 % threes) | Bigger groups once ai-2b raises the cap |
| Raiders only on Reserve and Labs; sniper scavs on Customs | Built 2026-11-08 (ai-1a, Studio check pending): Border Yard and Meridian's posts, routes and the Bastion's gunners are scavs; marksmen (hard, a scoped Tundra) on the reference's perches: the derrick always, the boiler house and depot roofs half the time, the block post empty, as EFT's waves | The Watch stays on Quay 7 and Smelter (our maps); EFT's marksmen are the sniper-scav role, ours use BotData's marksman numbers |
| Voice lines, call-outs, boss voices, a warning to player scavs | Silent; call-outs share positions without a sound | ai-4a: recorded voice packs (the audio quota, KNOWN_ISSUES 6) |
| Bots loot bodies and loose loot; what they take is lost to insurance | Built 2026-11-08 (ai-8a, checked in Studio): a calm scav goes to a body or dropped gear within 30 m, or a loose item worth 4,000 MK or more within 15 m, searches 4-8 s crouched (1.5 s for a loose item) and takes a gun worth a fifth more than its own with its rounds (its own gun slung), gear for an empty slot, and up to four valuables; one bot to a body; a fight or a noise breaks it off; what it takes loses its insurance (EFT 0.13.5's note) | Which items EFT's bots prefer, their search times and ranges are ours (not published); scavs only, PMC bots with ai-6b; bots do not look in containers; nothing out of the secure container |
| Killa's LMG, Big Pipe's grenade launcher, Birdeye's marksman rifle, Tagilla's semi-auto 12 gauge, Reshala's golden pistol | Since 2026-11-08 (ai-5b, checked in Studio): THE CARETAKER carries the KS-L light machine gun (our RPK-16: the KS-7 action with a heavy barrel and a folded bipod, 650 rounds a minute, ergonomics 45, recoil 106 / 316, a 95-round drum of 0.68 kg) seven times in ten, and fires it in bursts of 8 to 14 rounds close in, 4 to 8 far off; the gun and the drum are loot, and VOS barters them at LL3. MORTAR carries the GL-6 (our M32A1: a six-round cylinder loaded a round at a time, 30 rounds a minute, ergonomics 30, recoil 238 / 560, 76 m/s) with six 40x46 HE rounds in it and four spare (EFT's M386: 199 damage, an explosion of 1 to 7 m, armed after 0.26 s of flight, about 20 m; a round that strikes sooner is a dud); he lobs them at anyone past 40 studs (13 m), takes his KS-7 inside 22 studs (7 m), and the launcher and rounds are loot (DEKKER sells the rounds at LL3). Stand-ins still: the Stoker's pump gun, the Broker's plain pistol | Killa's other guns; one 40x46 round where EFT has six (M381, M386, M406, M433, M441, M576 buckshot); no launcher skill; the KS-L in 7.6 where EFT's RPK-16 is 5.45 (our KS family); its mastering shares the KS-7's group; the drum's -12 ergonomics are not modelled (our magazines carry none) |
| PvE mode with AI PMCs | None | ai-6b, after ai-2 and ai-3 |
| Leaning, prone and vaulting bots; flanking and group pushes; shooting and looking at bodies | Not built; peeking steps sideways from full cover | Later |
| Health per body part for bosses | Spread evenly over the parts | Logged per boss (`docs/design/BOSS_*.md`) |
| Rogues, Glukhar, Sanitar, Shturman, Kaban, Kollontay, Zryachiy, Black Division | None | They need their maps (section 11) |

## 9. Core gameplay

From the audit's gameplay report (`docs/audit/2026-11-07/gameplay.md`), brought up to date on 2026-11-08 from `Combat.luau`,
`Health.luau`, `Effects.luau`, `Maps.luau` and the M1 and M3 entries in section 7.

Matches Tarkov now:
- **Health:** 440 over seven parts, death at the head or thorax; spill x0.49 arms, x0.7 legs, x1.05 stomach (gameplay.4);
  wounds kept after a survived raid, and bunker recovery saved between raids (M1, gameplay.1).
- **Ballistics:** drop and travel time by muzzle velocity, zeroing; damage and penetration scale with the speed the bullet
  keeps (gameplay.2); rounds with 20 or more penetration fragment for +50 % damage (gameplay.3).
- **Malfunctions (M11 part B; Tarkov's rules since gameplay.11, 2026-11-08; neither checked in Studio yet):** Tarkov's four
  types and four sources (wear, the round, the magazine, heat); from 93 % condition nothing but heat causes one; found
  with L and cleared with Shift+T.
- **Handling:** ergonomics sets aim speed, sway and how fast aiming tires the arms (gameplay.10).
- **Raids:** Border Yard and Meridian Mall 40 minutes, Smelter 20 like Factory (gameplay.15); every extract type (open,
  chance, paid, car, co-op, flare, scav-only, transit); the run-through rule (200 XP or 7 minutes).
- **Sound:** footsteps carry Tarkov's distances, about 134 studs (43 m) crouch-walking slowly to over 312 (100 m) sprinting
  (gameplay.5); subsonic rounds make no crack (gameplay.7); only real shots are heard far off (gameplay.13).
- **Grenades** fall under the world's gravity (gameplay.14).

Still a gap:

| Tarkov | Zero Return | To do |
|---|---|---|
| Recoil with a climb angle, dispersion and convergence; full auto levels off | Built 2026-11-08 (gameplay-1a, Studio check pending; `src/shared/Recoil.luau`): an angle and dispersion each shot, convergence back to the aim point, full auto settles after the first shots (an R-17 peaks near 2.9° and settles near 1.3°, was 13.6° over 30 rounds), camera recoil apart from the gun's, shots and iron sights follow the gun; each gun's figures from its Tarkov 1.0 default build (R-17 79/228 as the M4A1, KS-7 90/221 as the AKM), pose and skill factors from Tarkov's globals, 1.0.4.5's part rules; RECOIL CONTROL trains on every shot | Per-gun angle, dispersion, convergence, camera share and stable shot are ours by class (Tarkov's per-gun figures were out of reach; every angle 90); the conversion to degrees, spring rates and the ergonomics term are ours; ammo recoil modifiers; bipods (mounting on cover is in, gameplay-5b); camera recoil growing with FOV |
| Soft armour plus plates in front, back and side slots, protection by zone; helmet zones (top, nape, ears, eyes, jaws); ricochet by angle | Built 2026-11-08 (gameplay-2a; PlateTests 54/54 in Studio; `src/shared/Plates.luau`): 16 plates copying EFT's (class, durability, material, weight, penalties), the five vests and the plate rig as soft-armour parts with plate slots, zones from where the hit lands, helmet zones and ricochet, EFT's penetration curve, damage loss, blunt damage and armour wear; plates change only off the body; traders sell, buy and repair them; class 5-6 plates banned from the flea; old saves migrate | The curve, damage-loss and blunt formulas are the community's copy recalled, not fetched; the wear formula's shape, zone and plate sizes, ricochet numbers and some soft classes are ours; no per-round penetration spread or limb pass-through; 6 vests and 16 plates (EFT 108 and 38); plate icons; the drag cue for plates |
| Each round has its own muzzle speed and ballistic coefficient | Speed per gun, drag per gun class; mounted guns still use a range fall-off | Per-round speed and drag |
| Overheating in four stages with cook-offs, a fire-rate change and maximum durability loss; a flash on a malfunction; a chance per round; a 5 s quick draw of the sidearm after a jam | Built 2026-11-08 (gameplay.11, Studio check pending): heat on Tarkov's 0-200 scale with its cooling; from 100 wear rises up to x3 and spread up to x1.5; fire rate moves 0.85-1.15 above 140; cook-offs from 170; the bolt held at 200; hot shots cut the maximum durability (never below 55); a red, yellow or green glow on a malfunction, its check and its fix; a 5 s quick draw of the sidearm after a jam | Only the AKM's numbers are verified (every gun uses its base chance and cooling); every round uses the 7.62x39 chance; 40- and 50-round magazines keep our wear; base wear about twice the AKM's; no Troubleshooting elite or Weapon Maintenance; clearing by chamber check or reload; per-weapon malfunction kinds; barrel glow and heat haze |
| A round in the chamber (30 + 1) | No chamber round | The chamber round |
| Mounting on cover and bipods; quick reload (double R drops the magazine); slow lean; stance changes cost leg stamina; overweight is louder | Since 2026-11-08 (gameplay-5b): R twice (pad X twice, touch RELOAD twice) drops the old magazine at your feet and reloads in 0.75 of the time; every stance change costs leg stamina (getting up more); an overweight raider's kit rattles more often, louder and further (the server's Overweight attribute). Part 2: V while aiming mounts the gun on a ledge under the handguard or a wall edge beside it (0.15's "suitable horizontal or vertical surface"), with 0.65 of the recoil, a quarter of the sway and a fifth of the arm stamina; moving, turning past 30 degrees, a stance change, lowering the sights or V again takes it off; not prone (EFT allows that only on a bipod); a word right of the stamina bars shows MOUNT and its key, or MOUNTED, for EFT's corner icon. A gamepad or touch player mounts by holding still for 0.4 s while aiming at a support. Since 2026-11-08 bipods: a gun with one (the KS-L's folded legs) mounts lying down on the ground ahead, and on a ledge with its legs out, with the bipod's own "Recoil % when mounted" as EFT lists it (the KS-L -80, as EFT's PK, RPD, M60 and G36 bipods; in Studio the camera climbed 0.08 degrees a shot mounted against 0.44 unmounted); the word reads BIPOD. Slow lean: Alt+A/D lean a little at a time and the lean stays Since 2026-11-08 the slow lean also works on a gamepad and a touch screen: a tap of LB / RB or LEAN L / R is the full lean (or upright), holding it leans a little at a time and stays there (ours: EFT has no pad). | Bipod parts on rails (EFT's Harris -75, Atlas -65, SV-98 -70; the wiki's Weapon mods table, read 2026-11-08) and EFT's Ctrl+V to fold them; the KS-L's bipod is ours where EFT's RPK-16 has none; how EFT stacks a bipod's cut with mounting's own, and a bipod's sway and stamina cuts (ours: 0.12 and 0.1); no bipod or prone mounting animation; EFT's own icon and its figures for the mounted cuts (ours); EFT's figures for the reload saving and the stance costs were not found (ours) |
| Fractures (a leg -45 %; arms slow aiming, drawing and searching); stims with buffs and side effects; a destroyed stomach drains energy and water x5 | EFT's fracture penalties and the stomach rule; four stims with EFT's figures, after Propital, SJ6, Zagustin and the Adrenaline injector (gameplay-4b, 2026-11-08) | About 34 more stims, per-kit costs and two surgery kits (option a); the gaps under "Stimulants" near the end of this file |
| After death or MIA: 30 % health regaining 7.61 HP a minute, paid healing at the Therapist; insurance 12 to 36 h, held 4 to 6 days; scav cooldown about 25 min | Since 2026-11-08 (gameplay-6b, checked in Studio): 30 % health after death or MIA, regaining at four times EFT's rate out of raid (also while offline); HALE's TREATMENT at EFT's prices, free at level 5 or below; three insurers at EFT's times divided by 12, held for EFT's storage divided by 4; scav cooldown 15 min | EFT's message timing, faster 1.1.0 insurance figures, Jaeger's figures; the scav cooldown's base (EFT about 25 min, unofficial) (section below) |
| PMCs only enter at the start of a raid | PMCs may join for 5 min (`Config.LATE_JOIN`) | gameplay-7a: a server per raid (needs the published place) |
| Occlusion through walls, floors and stairways | On Border Yard, world sounds through Roblox's Acoustic Simulation (one wall about -17 dB, a floor about -14 dB); elsewhere a wall count muffles them (gameplay-3a, 2026-11-08) | The other maps after the pilot; the ambience loops; a phone check |
| Each gun its own sound; footsteps on snow, water, tile and metal stairs; headsets with their own compression | One recording pitched for every gun; five surface families; one headset rule | Recorded or licensed sounds; gameplay.16 |
| Perception lengthens how far you hear steps; Covert Movement quietens yours | Built 2026-11-08 (gameplay.9, Studio check pending): Perception +0.3 % hearing a level (+15 % elite), Covert Movement -1.2 % a level on common surfaces (-60 % elite), for players and the AI | Perception's loot radius and elite loot notice; Covert Movement's sneak speed; metal and gravel as Tarkov's uncommon surfaces is our reading |
| A tutorial raid (1.0): a closed-off part of Ground Zero; an office lobby with medical supplies on the reception desk, a body past a barricade with an SMG and three magazines, two or three scavs in a parking garage with cars for cover, more on the street, a second building, tents with medkits and splints, a green flare over a gated exit; control signs on the walls and green lights on the floor; about 20 minutes (Prima Games, VidaExtra, Insider Gaming, 2025) | Since 2026-11-08 (ui-5a, checked in Studio): FIRST RAID on a course of its own (`Maps/Tutorial.luau`) laid out in that order, with Blender kit props; offered (START, LATER, SKIP) to a profile that has never raided; a loaned kit (knife, chest rig, day bag, one dressing); eight steps on an objective line; four scavs held to their ground by a leash (two in the garage, one on the street, one in the office); signs name the control for the device in use (keyboard, gamepad or touch); a 20-minute timer; the extract finishes it (what is carried out goes to the stash, found in raid, settled like a scav run), and a death or a give-up costs nothing and leaves the offer open | Offered, not forced, and can be skipped; one run at a time per server (Tarkov gives each player an instance of their own; KNOWN_ISSUES 83); no voice-over or story scene; the Studio run used the dev bridges and teleports, not a new player's play-through |
| The players' tripwire kit (0.15) | The server side on `wip/tripwire-kit`, parked | Build the client, then merge |
| Transits open 7 min in (0.15 notes); car fares in roubles you carry (unverified) | 60 s (SPT data); fares from the stash balance | The sources disagree; no cash item yet (KNOWN_ISSUES 16) |
| Bullets through thin walls; ricochets off surfaces (unverified) | Only glass lets bullets through | Not known |

## 10. Economy

From the audit's economy report (`docs/audit/2026-11-07/economy.md`), brought up to date on 2026-11-08 from `Items.luau`,
`TraderData.luau`, `QuestData.luau`, `FleaRules.luau`, `Loot.luau`, `Progress.luau` and `Config.luau`.

Matches Tarkov now:
- **Items** carry weight, grid size and value (values set by hand); 58 keys and keycards with uses, locked rooms and
  electric locks.
- **Found in raid:** crafts are found in raid, and an item taken into a raid loses the mark (economy.4).
- **Containers** roll whether they hold anything: 50 %, jackets and registers 60 %, safes and weapon boxes always
  (economy.10; SPT's mean is 0.28, ours stays higher while the item list is small).
- **Airdrops:** 20 % with 6 or more alive, four crate kinds, the red flare (no bonus pack, no fixed zones).
- **Flea market rules:** level 15, Tarkov's listing-fee formula, offer slots by rating, 12 h offers; simulated buyers stop
  at 1.25x the market price, and epic and legendary items get fewer offers (economy.1, .2).
- **Charisma:** 0.1 % off insurance, repairs and paid exits a level, and no trader discount (economy.6).
- **Repairs** at VOS and TILDA lower the maximum durability; the repair kit lowers it less.
- **The Sealed Drive** is wanted by a task: TILDA's "Sealed Records" (economy.8).
- **Beginners:** a free recovery kit when broke, close to 1.1.0's beginner package.

Still a gap:

| Tarkov | Zero Return | To do |
|---|---|---|
| 2,169 items in 2021 (102 weapons, 1,421 parts); 184 rounds in 27 calibres in 2026 | 540 items (2026-11-09): 33 guns, 123 parts, 104 rounds in 17 gun calibres, 102 barter goods. Since economy-1a's fourteenth slice, EFT's VPO-209 as the Tern T-209 (recoil 122 / 305 with its default stock from EFT's 154 / 386, 600 a minute single shots, 300 m; the KS-7's action, furniture and magazines; its own thread protector, rear sight and hunting stock; Skier and Jaeger at LL1; the scavs' 6.4 %), the KS-7's 10-round magazine (EFT's AK aluminium 10-round), the SR-96 suppressor (EFT's Rotor 43 .366) and the KS-74's TS-5 suppressor (EFT's AK-74 TGP-A); and EFT's calibre rule: a magazine takes what its feed lips take (every KS-7 magazine 7.6x39 and 9.6x39, as EFT's AK 7.62x39 magazines take .366 TKM), a gun fires its own calibre only, a magazine fits by type whatever it holds and a foreign round never chambers, and the reload passes over magazines the gun cannot fire. Since economy-1a's thirteenth slice: printer paper, the cookbook, Geiger counter, textbook, magnet, sledgehammer (EFT's grid, weight and handbook value; the textbook's grid and weight ours), the SV-1 stim (EFT's SJ1, its course from SPT's 0.16.9 data) and 7.62x39 and 7.62x54R FMJ (Prapor LL1 / LL2). Since economy-1a's twelfth slice, three more 9x19 guns: the Dunlin D-17 for the Glock 17 (recoil 311 / 260, a 17-round magazine), the Avocet AV-9 for the SIG MPX (recoil 51 / 269, 850 a minute, 20- and 30-round magazines, a top rail) and the Bunting B-19 for the PP-19-01 Vityaz (recoil 58 / 270, 700 a minute, a 30-round magazine, the side dovetail); sold by Peacekeeper's and Prapor's counterparts at levels of ours. Since economy-1a's eleventh slice, EFT's revolvers with their cylinders loaded round by round: the Crake C-357 for the Chiappa Rhino 50DS (.357 Magnum, our 9x33R, all four loads; recoil 383 / 280), the Crake C-9 for the Rhino 200DS (9x19; recoil 306 / 200) and the Bustard B-12 for the RSh-12 (12.7x55, all three loads; recoil 493 / 340, five rounds); Jaeger's .357 and Prapor's 12.7x55 as in EFT. Since economy-1a's tenth slice, EFT's 9x21 with all six loads and .366 TKM (our 9.6x39, its metric name) with all four: the Wren W-21 for the SR-1MP Gyurza (recoil 442 / 325, an 18-round magazine), the Jay J-21 for the SR-2M Veresk (recoil 54 / 234, 950 a minute, 20- and 30-round magazines, a top rail) and the Tern T-215 for the VPO-215 Gornostay (bolt action, recoil 200 / 486, a 4-round magazine, a top rail); Prapor's 9x21 and Jaeger's .366 offers as in EFT, the guns by barter or at Jaeger (levels ours); the workbench's .366 AP-M and 9x21 P gzh crafts with them. Since economy-1a's ninth slice, EFT's 7.62x25 TT (our 7.6x25) with all ten loads, the 1.0 sabot loads among them, and the Pipit P-33 for the TT-33 (recoil 553 / 325, 8 rounds) and the Grackle G-41 for the PPSh-41 (recoil 89 / 294, 1,000 a minute, a 35-round magazine or the 71-round drum it comes with); both by barter only, as in EFT. Since economy-1a's eighth slice, EFT's .45 ACP (our 11.4x23, its metric name) with all five loads and three more guns: the Harrier HS-45 for the HK UMP 45 (recoil 72 / 240, 600 a minute, a 25-round magazine, a top rail), the Lark L-11 for the Colt M1911A1 (recoil 451 / 355, 7- and 11-round magazines) and the Finch F-57 for the FN Five-seveN MK2 in 5.7x28 (recoil 281 / 240, a 20-round magazine); all by barter only, as in EFT. Since economy-1a's seventh slice, EFT's personal defence weapons with all their loads (five in 4.6x30, seven in 5.7x28): the Swift PW-46 for the HK MP7A1 (recoil 50 / 178, 950 a minute, 20-, 30- and 40-round magazines in the grip, a top rail) and the Petrel PD-57 for the FN P90 (recoil 54 / 243, 900 a minute, the 50-round magazine on top, a built-in ring sight); both by barter only, as in EFT. Since economy-1a's sixth slice, EFT's 9x39 with its six subsonic loads and two silenced rifles: the Owl SV-9 for the VSS Vintorez (single shots or bursts) and the Nightjar AV-9 for the AS VAL (bursts or single shots), both recoil 80 / 270, 400 m, 900 a minute, sharing the 10- and 20-round magazines, each with its integral barrel-suppressor as a part of its own as in EFT (a vital part: a multitool to change it in a raid); barter only, as in EFT. Since economy-1a's fifth slice, EFT's 7.62x51 NATO (our 7.6x51) with its eight rounds and two rifles: the Shrike S-14 for the M1A (single shots, recoil 214 / 405, 700 m, 10- and 20-round magazines, a bridge mount for a scope; the Mechanic's at LL3 as in EFT) and the Osprey OB-7 for the Remington Model 700 (a bolt action with a detachable 5- or 10-round magazine and a rail base, no iron sights, recoil 199 / 670, 1,000 m; barter only, as in EFT). Since economy-1a's fourth slice, two of EFT's self-loaders: the Siskin SK-45 for the SKS (an assault carbine in 7.62x39: recoil 155 / 360, 400 m, a fixed 10-round magazine loaded a round at a time, barter only, the scavs' second rifle) and the Merlin MR-10 for the SVDS (a marksman rifle in 7.62x54R: recoil 220 / 647, about 900 m, a 10-round magazine, the AK-type side dovetail for a scope mount and the Tundra's muzzle devices, barter only at LL3). Since economy-1a's third slice, EFT's two commonest scav guns: the KS-74 for the AK-74N (5.4x39, our 5.45x39: 650 rpm, 650 m, recoil 96 / 244 before its default stock and brake, sold by our Mechanic at LL2) with the 74 brake and the 6L20 and 6L26 magazines, and the Makar PM for the PM (9x18: recoil 380 / 265, ergonomics 85, 50 m, barter only) with its 8-round magazine; seven 5.45 loads (HP, US, T, PS, BT, BP, BS) and six 9x18 (P, PSV, PPT, Pst, RG028, PBM) with EFT's figures, at Prapor's and Jaeger's levels; scavs carry the KS-74 most and the PM as their sidearm; the 5.45 BP and 9x18 crafts now make those rounds. Since economy-1a's second slice, 54 of EFT's barter goods have one of ours each, with EFT's grid size, its handbook price as the value and its handbook folder (`cat`): the tools (screwdriver, pliers, wrench, ratchet and pipe wrenches, hand and electric drills, toolset, files, tape measure, awl, sewing kit), building materials (screws, nuts, nails, silicone tube, corrugated hose, pressure gauge, sealing tape and foam, metal spare parts), electronics (phase relay, motor, power supply, cooling fan, power cord, T-plug, military power filter and cable, energy-saving lamp), info (SSD, survey maps, secure flash drive), a lithium battery, flammables (penetrating oil, TNT, thermite, lighter, gun lube), household goods (toilet paper, salt, chlorine, alkaline cleaner), medical supplies (syringe, pile of meds, saline, bloodset, transilluminator, ophthalmoscope), weapon parts, a water filter, a grenade fuze, a golden rooster and a gold skull ring; each in the containers where EFT finds it, and the commoner ones in daily tasks. Since economy-1a's first slice six of EFT's loads for each of our five gun calibres with EFT's damage, penetration, armour damage, fragmentation, speed, recoil and accuracy modifiers, tracers and subsonics (5.56: FMJ, HP, M855, M856A1, M855A1, M995; 7.62x39: HP, US, T-45M1, PS, PP, BP; 9x19: FMJ M882, Pst gzh, Green Tracer, AP 6.3, PBP, RIP; 12/70: 7 mm and Magnum buckshot, flechette, lead slug, Poleva-6u, AP-20; 7.62x54R: LPS, T-46M, PS, BT, SNB, BS), at EFT's traders and levels where a page gave them | economy-1a's next slices: more calibres and guns (about 10 more across EFT's classes: a marksman rifle, a carbine such as the SKS, SMGs in 4.6 / 5.7 / .45, a 7.62x51 bolt action, a revolver), parts, the other barter goods (about 25 more, among them EFT's DVD drive, CPU, LCD, Tetriz, Virtex, VPX, gas analyzer, the four fabrics apart, the three gunpowders apart, Pliers Elite, cable cutter, Shustrilo foam, Poxeram, insulating tape, Zibbo, hunting matches, sodium bicarbonate, shampoo, multivitamins, hydrogen peroxide, Majaica, sugar, the other books) and keys toward about 600; the barter goods' weights are ours (no page gave them) and the older barter goods keep our earlier values rather than EFT's handbook prices; the KS-74 takes the KS-7's furniture (EFT's AK-74 family has its own parts and the AKS-74, AKS-74U and AK-74M variants), its stock's -22 % is the AKM stock's (the AK-74 stock's page was out of reach), the PM has no grip-panel slot or PM (t), and the KS-74 and PM mastering thresholds are borrowed from the KS-7 and P-9; the SK-45 takes no parts (EFT's SKS takes stocks, mounts, detachable magazines and stripper clips) and its and the MR-10's recoil figures are their pages' taken as the built guns'; the MR-10 trains the rifle skill (EFT has a Marksman Rifles skill) and its and the SK-45's mastering thresholds are borrowed; the S-14 takes no stocks, barrels or gas parts and the OB-7 no stocks or barrels (EFT's take dozens), there is no 7.6x51 suppressor yet, the two rifles' weights and velocities are ours, the OB-7's default build carries the rail base (ours), its barter's trader and goods are ours, and the 7.6x51 bleeding adds EFT's changes to a base of ours; tarkovforge.com's VSS and AS VAL pages give both rifles the same figures (taken as given); the SV-9 and AV-9 take no stocks, grips, handguards or covers (EFT's take a dozen), their dovetail takes the KS-7's side mount (ours), their weights, barter trader and goods are ours, and their mastering thresholds are borrowed; the PW-46 and PD-57 take no suppressors, stocks or receivers (EFT's take many), the PD-57's ring sight is fixed, the 5.7x28 loads carry our names (FX, EX, LF, SR, SUB, TR and SS for R37.F, R37.X, SS198LF, SS197SR, SB193, L191 and SS190), their magazines are sold by barter only (ours); the HS-45, L-11 and F-57 take no barrels, slides, stocks or suppressors (EFT's take many), the 11.4x23 loads carry our names (FX, HP, TR, FMJ and AP for RIP, Hydra-Shok, Lasermatch, Match FMJ and AP), the F-57's 650 m/s is ours, and their barters and mastering thresholds are ours; the P-33 and G-41 take no barrels, stocks, covers or suppressors (EFT's TT has a makeshift suppressor), the G-41's 480 m/s is ours, the 7.6x25 loads carry our names where EFT's are makers' (Match for AKBS; SBT, SB and SBAP for the TT M856A1, M855A1 and M995), and the three sabot loads' prices are ours (they are newer than SPT's handbook); the base bleeding chances per calibre are ours; some base prices are estimated from trader prices; M855A1, BT, BS and AP-20 come from loot only (EFT also crafts them); PS 7.62x39 stays at LL2 for want of EFT's FMJ and SP ; thirteenth slice: the textbook's grid and weight are ours, the SV-1's course is unchecked against the current patch (and EFT's SJ1 text speaks of dulled pain its effects do not list), 7.62x39 PS stays at Prapor LL2 for SP (EFT: PS at Prapor LL3, SP at Skier LL1), one tracker marks 7.62x39 FMJ and PS flea-banned (ours tradeable), every 7.6x54R round weighs 0.012 kg against EFT's about 0.024; crafts still out by the value rule: 7.62x39 FMJ x200 (1.87x its inputs at our values, EFT 0.88x) and SJ6 x2 (2.66x, EFT 0.68x); fourteenth slice: the T-209 wears the KS-7's dust cover, handguard and grip for EFT's Molot ones (same figures in EFT; our KS-7 handguard is +6 to EFT's +10); no launcher, charging-handle or front-sight slot and no TT01 rail; no bare receiver at Mechanic LL2 (we sell builds only); magazines carry no ergonomics or own malfunction chance (EFT's aluminium 10-round: +4, 2 %), so the T-209's 52 includes its 10-round magazine; which magazine EFT's quick reload picks when some hold foreign rounds, and whether EFT shows anything beyond the dry trigger, are not verified (ours: passes them over; clicks); EFT's SKS internal magazine also takes .366 TKM (ours refuses); no .300 BLK or 6.8x51 yet, so EFT's other two-calibre families (AR-15, AR-10 magazines) are not needed; Reshala's guards' suppressed VPO-209 (EFT 10 %) is not in our Broker's guards' kits; scavs carry no AP-M; the T-209 is flea-gated at 25 as a rifle (EFT's gate names assault rifles; the VPO-209 is an assault carbine); prices from our parts' values (Skier 39,969, Jaeger 36,772 vs EFT's 28,378 / 31,217); 590 m/s is EFT's +1.8 % on our FMJ; dispersion by class (EFT: VPO 12, AKM 11); no 7.6x51 suppressor yet |
| Eight traders (Prapor, Therapist, Skier, Peacekeeper, Mechanic, Ragman, Jaeger, Fence), plus Ref, Lightkeeper and the BTR driver; money as items in three currencies | Built 2026-11-08 (economy-2a; TraderTests 38/38 in Studio): VOS (Prapor), HALE (Therapist), FENCE, ROOK (Skier), DEKKER (Peacekeeper), KOVAC (Mechanic), TILDA (Ragman), BRAM (Jaeger), each with its role's goods, buyers and repairs; tasks moved to their EFT givers; old saves migrate; MK only | Buy shares and which item opens at which LL are ours (EFT's trader files out of reach); Jaeger and the Peacekeeper open from the start; Relay 7 counters, NPCs and portraits for the four new traders; Ref, Lightkeeper and the BTR driver (no Arena, Lighthouse or BTR) |
| LL2 to LL4 at levels about 13 to 42 (1.1.0 dropped the sales requirement); 892 barters | EFT 1.1.0's rule since economy-2a: each trader's own levels plus a standing, no money asked; standings scaled so LL4 needs all of a trader's task standing (we have 1-6 tasks a trader, EFT 52-91); 14 barters | economy-6a (tasks) to restore EFT's standings; economy-4b |
| Fence sells what players sold him; his LL2 at reputation 6.0 | 11 fixed offers; LL2 at karma 6.0 (his dorm key), prices x1.2 at -7 to x0.8 at +6, karma -7 to 6 (economy.5, 2026-11-08, Studio check pending) | Player-sold stock; his LL2 tab of better goods; what he pays still moves 4 % a karma point; scav cooldown and hostility keep our curve; our karma gains are 3-8 times EFT's |
| Flea level gates by category up to 40 (1.0); bans on secure containers, currency, some weapons, ammo, armour, packs, helmets; fee 5 % since 1.1.0 | Built 2026-11-08 (economy.3, Studio check pending): EFT 1.0's gates (20: bolt-actions, foregrips, muzzle devices; 25: assault rifles, packs, lights and lasers; 30: barter goods, goggles, injectors, keycards; 35: the LPS-class round and M80), greyed offers, and EFT's ban list with the top piercers of each calibre; the 5 % fee of 1.1.0 with EFT's formula, not refunded (economy-3a); EFT's listing limits (5 at a time of LEDX and the like) and 1.0.4.0's full ammunition stacks | BSG publishes no full gate table, and 1.0 may have turned some bans into gates; EFT's wiki says rounds cannot be listed and trackers mark many banned, ours bans only the top piercers |
| A market of real players, with barter offers | Since economy-3a (2026-11-08, FleaTests 73/73 in Studio; cross-server play not yet tried): each seller's offers in a DataStore escrow book, shown on every server through a MemoryStore index; purchases exactly once (two buyers on two servers: one wins, the other gets EFT's "Sorry, the offer has already been purchased" and the money back); sales reach offline sellers; 12 h offers; REMOVE ends an offer 72 s later and it can be bought until then; rating +0.02 per 100,000 sold and -0.03 per 100,000 unsold; returns keep found in raid and wait 72 h when the stash is full; sales and returns in TILDA's chat (EFT's Ragman); player barter offers are gone as in EFT since March 2023; operators fill in only where players offer too few, their stock shared by every server; AI buyers take only an item's cheapest offer at or below the going rate | Operators and AI buyers are ours (EFT has neither) and so are their prices and rates; sale money is credited at once (EFT attaches it to Ragman's message); offer slots keep the wiki's table (EFT 0.16.9's settings carry a larger one, unverified for 1.x); the rating loss read as proportional (unverified); no EXTEND THE TIME, no priority offers, no traders' offers on the flea, no unique-buyer rule; at most 40 player offers an item on show (Roblox's memory quota); the rating shown is the one at listing time; one stash stack per offer; another server sees a new offer within a minute |
| Loot tables per map; 21 container templates (SPT, Interchange) | One pool per container kind for every map; 13 kinds | Tables per map |
| Secure containers Alpha to Kappa with trader and task paths; item cases (documents, keytool, SICC, junk box, medicine, magazine, keycard holder) | Pouch S, M and L: M is TILDA's LL2 barter (EFT's Beta), L the reward of FENCE's task Keepsakes (EFT 1.1's Kappa); weapon parts, grenades, goggles, glasses and headsets go in (economy.7, 2026-11-08, Studio check pending) | The cases; full containers cannot nest; Pouch L asks 10 of our valuables, Kappa 44 collectibles |
| Stash 10x30, up to 10x68 or 10x72 | Since 2026-11-08 (economy-7b, checked in Studio): stash levels 10x30 / 40 / 50 / 68 at EFT's costs (38.2M MK for level 4); old saves keep their rows (storage racks level L became stash level L+1) | The 10x72 of the top edition (economy-8, editions) |
| 531 tasks for 11 traders: conditional kills, found-in-raid hand-ins, plant and mark, visit, extract, skill and LL, gunsmith builds; side tasks per LL, dailies and weeklies, task-locked offers | 122 tasks for 8 traders in EFT 1.1.0's loyalty-level groups on our four maps: conditional kills, found-in-raid hand-ins, plant and mark, quest items kept only by getting out, visit, extract (not on a run-through), gunsmith builds; three dailies, a weekly and Fence's scav task; task-locked offers; 31 task places (economy-6a, 2026-11-08; mark and find checked in Studio) | The gaps in "Map-first tasks" near the end of this file: 409 more tasks and the story tasks; our rewards, hold times and operational figures; no skill, loyalty or failure objectives |
| Hideout: 26 modules, 67 levels, 214 crafts; generator fuel; scav case; bitcoin farm; the shooting range as a module | Since 2026-11-08 (economy-7b, checked in Studio): EFT's 14 core modules (security, lavatory, stash, generator, water collector, medstation, nutrition unit, rest space, workbench, intelligence center, shooting range, scav case, illumination, bitcoin farm), EFT 1.1's 41 levels with its money (1 rouble = 1 MK), item counts (since economy-1a's second slice almost all with EFT's own goods and tools; the crafts hold EFT's own tool and give it back), module and skill prerequisites and bonuses, each level's bonuses added up; several builds at once, one craft per module with tools given back; fuel (a canister is EFT's 60-unit tank: 3 h 9 min) and power (powered crafts start only with power and run 14 times slower without, the farm stops); the bitcoin farm (EFT's 300,000 s and card formula, 10 / 25 / 50 cards, 3 wallets held); the scav case's five runs; 83 of EFT 1.x's 212 crafts in these six modules (the tenth catalogue slice added .366 AP-M and 9x21 P gzh; the thirteenth the magnet, 12/70 flechette with the sledgehammer as a tool, 7.62x54R LPS from FMJ, SJ1 and toilet paper from printer paper, and gave Salty Dog, Max Energy, Hot Rod and the graphics card their tools back) (the crafts thread, 2026-11-08: tarkovforge.com's hideout pages for levels, counts, inputs and times, SPT's exact seconds where a craft is unchanged, returned tools from SPT or item pages; the other 134 are listed in HideoutData with the reason each is out); crafts, scav returns and wallets found in raid. The intelligence center cuts flea fees (30 %), the scav cooldown (15 / 35 %) and insurance returns (20 %) and adds task money (5 / 15 %); the workbench gates weapon repair kits and cuts their points (3 / 6 %); the range trains combat skills 10 % faster; the nutrition unit, water collector and rest space speed energy and hydration | 12 more modules (vents, heating, library, gym, air filtering, solar power, booze generator, hall of fame, racks, defective wall, cultist circle, Christmas tree); about 150 more crafts with economy-1a (ours make what we have items for; a few margins are richer than EFT's: Propital, Hot Rod, purified water); no Hideout Management skill; builds finish by themselves (EFT: FINISH); the first canister starts the generator and fuel cannot be taken out; a module cannot craft and upgrade at once (ours); purified water is a craft you restart that uses up a whole water filter (EFT: two-thirds of one, the filter running nonstop); no effect yet for maximum energy +10, faster debuff recovery, armour kits or the filter slot; Relay 7 has bays for eight modules; security, the nutrition unit, the rest space, the range, illumination and the bitcoin farm open from the HIDEOUT screen; crafts: 134 of the 212 out (no item of ours for the product or an input); tasks that unlock crafts not modelled; five kept crafts lack one EFT tool or input (Salty Dog, Max Energy, Hot Rod, the graphics card, the intel folder); generic food and supplies turn some crafts into one-item conversions; at our item values Propital pays 5.8 times its inputs (EFT 1.25), Grizzly 3.5 (EFT 1.7), Hot Rod 2.1 (EFT 1.6); new crafts' times within about 30 s |
| Builds and crafts take hours to days; EFT's level table to 79 (level 15 at 177,337, the top at 172,016,256: senseos.gg, patch 1.3.0.0; the older 161,139 for level 15 is superseded) | Since 2026-11-08: EFT's build, craft, fuel, farm and scav case times divided by 4 (economy-7b, Config.HIDEOUT_TIME_DIV); EFT's level table to 79 (economy-4b, checked in Studio); a raid lost (KIA or MIA) keeps 75 % of its experience (EFT 1.0.2.0); a head kill x1.2; task experience keeps each task's old share of a level, counted on EFT's table | Raid experience per kill, search and examine is ours (EFT's is not published); EFT's survived multiplier (raised in 0.16.9.5, figure not published); daily task experience by level (not published; ours 400 + 90 a level) |
| Skills such as Hideout Management, Mag Drills, Weapon Maintenance, Aim Drills, DMR, HMG, revolvers, launchers | 26 skills (LIGHT MACHINE GUNS since 2026-11-08) | With the content they need |
| Insurance: Prapor 24 to 36 h, Therapist 12 to 24 h, Jaeger quick (1.1.0) | Since 2026-11-08 (gameplay-6b): VOS 2-3 h at 7 % of value, HALE 1-2 h at 1.33x, BRAM 10-20 min at 2.5x, each return held 24 h (HALE 36 h) and lost after | 1.1.0's own figures were not published; BRAM's are ours |
| No forced wipes since 1.0; seasonal characters every 4 to 6 months (1.1.0); prestige (0.16); the PvE Zone | A wipe when the save format changes; no prestige or PvE | economy-5b: permanent plus an opt-in season |
| Weapon builds that buy the missing parts | None (KNOWN_ISSUES 54) | - |
| Money sinks: fuel, filters, the scav case, costly builds, flea fees, insurance, repairs | Since 2026-11-08: fuel, the scav case's runs, multi-million builds (economy-7b), flea fees, insurance, repairs | Filters (no filter item) |
| Paid editions; a free battle pass (1.1.0) | None | economy-8a: none for now (the owner approves any) |
| The handbook and flea list every item kind | Flares under SPECIAL EQUIPMENT (economy.11, 2026-11-08); seven items have no picture (ANTIDOTE, FLARE_RED, FLARE_GREEN, FORESTER_PACK, MASK_WELDER, RITUAL_AMULET, RITUAL_KNIFE) | Render the seven pictures |

## 11. Art

From the audit's art report (`docs/audit/2026-11-07/art.md`), brought up to date on 2026-11-08. The rules for new art are in
`docs/look/ART_BIBLE.md`.

Matches Tarkov now:
- **Layouts:** Customs and Interchange at real scale (Border Yard, Meridian Mall) with our own buildings, interiors and names.
- **Time and weather:** the 7x clock; four weathers per raid; seasons from the real calendar.
- **Effects:** explosions (flash, fireball, smoke, debris, scorch) and smoke grenades; since 2026-11-08 the muzzle flash by
  device with smoke, impacts by surface and ejected cases (section 6).
- **Devices:** four night-vision tubes and thermal goggles, drawn on characters.
- **Glass:** 594 breakable panes with shards (their sound is in the silent ambience atlas, KNOWN_ISSUES 73).

The owner's choices (exception 2): the block body stays (art-3a), so heads and bodies are bigger targets than Tarkov's and
guns are drawn 1.35x in third person to fit the hands; the BODYCAM auto-gain lifts nights (art-8b halves it).

Still a gap:

| Tarkov | Zero Return | To do |
|---|---|---|
| 13 locations; End of the Line due in December 2026 | 3 Tarkov layouts (Border Yard, Meridian Mall, and the Smelter on Factory's since 2026-11-09); Quay 7, our own layout, still in the vote until the art-1a vote change; Pinewatch parked | art-2d: no new map until Border Yard and Meridian Mall hold 30 fps on a measured low-end phone; then Factory, Woods, Reserve, Shoreline, Streets, Lighthouse, The Lab, Ground Zero, and the small-group maps last |
| Factory (142 x 132 m) and Woods (1.4 x 1.36 km) | Since 2026-11-09 (art-1a, the factory thread) the Smelter is Factory's layout at real scale (131.9 x 142.5 m, four levels at SPT's floor heights) with our buildings and names; Pinewatch, an original 164 m forest | Pinewatch on Woods' layout; Quay 7 leaves the vote and stays the test map; the Smelter's gaps in section 7 |
| Customs after 0.16; Interchange's ponds and outbuildings | Pre-0.16 outlines, no 0.16 interiors; dry ponds, one-room outbuildings | Section 7's lists |
| Fully modelled buildings: frames, sills, cornices, gutters, balconies | Part walls with cut holes, flat slabs | art-5b: a modular Blender kit of merged meshes, which also cuts the part count |
| Dense, lived-in interiors; map edges of fences, forest and terrain | About 10 props a shop, stretched furniture, plain box containers; tall terraced rock walls | art-5b; fenced and wooded edges |
| Trees and grass that move in the wind | See-through cards, no sway | Sway |
| Players choose the raid time; nights so dark that goggles and lights matter | One of 8 start times; the bodycam adds about 0.3 exposure at full dark (halved by art-8b, 2026-11-08) | Choose the time |
| No exit markers in the world | Since 2026-11-08 (art-8b) none either: exits are found by their place (gates, tunnel portals, a roadblock, a boat, a car) and the exits list | Some exits have no landmark of their own yet (art-8a would add them) |
| Hazy skies | Roblox's default sky with a cloud layer; the lighting model is not set in code | art.2: an original sky set (clear, overcast, night); art.1: set LightingStyle and PrioritizeLightingQuality and record them |
| Post effects: ambient occlusion, reflections, chromatic aberration, noise, grading | Grade, bloom, sun rays, depth of field, grain, vignette, edge haze; grading presets | Partial; part of it is a Roblox limit |
| Detailed, textured guns, gear and items | Since 2026-11-09 (art-4b, checked in Studio) every gun part wears texture sheets: 332 pieces of the 19 gun batches on 48 sheets (the pilot, 2026-11-08, was the R-17 family's 45 pieces on four): 1024 px (colour, normal, roughness, metalness at 1.5 px per mm): a dark coat worn back to bare steel in patches along sharp convex edges, grime along concave ones, edges rounded in the normal map, polymer and rubber rough, worn metal polished (assets/blender_scripts/zr_tex.py; Roblox clones each sheet's SurfaceAppearance into its pieces). Everything else is still vertex colour without UVs: gear about 400 triangles, 95 item models | EFT's weapon parts are each modelled and textured as their own asset ([an MCX Spear made for EFT](https://digitalforms.artstation.com/projects/YGwry6): every component individually modelled); ours are low-poly procedural parts with procedural bakes, no markings, and 1.5 px per mm where EFT's close-up textures are far sharper; worn gear and items seen up close still to do; no surface grain (finer than a texel here); a few pieces show bent normals where the bevel met thin features |
| Hand-made reloads, checks and inspects with the bolt and charging handle moving | Code-made poses. Since 2026-11-08 (art-6a): a quick reload lets the old magazine fall; a reload from empty ends with the left hand pulling the charging handle back and letting it go, with a jolt as the bolt goes home; a chamber check pulls the handle a short way; a magazine check carries the magazine up in front of the eye, with the fist low on it so its top shows | Hand-made animation. Only the hand moves: the bolt and charging handle stay still. AR-pattern guns rack the handle instead of pressing the bolt catch. Every gun uses the same poses, and only the R-17's have been looked at. Inspects are still code-made. |
| Blood on hits | A dark red puff; since 2026-11-08 (art-7a) small dark marks on the wall or floor behind a body hit and now and then a drop under it (at most 30, gone after 40 s; none on bodies) | Marks on bodies; when publishing, the owner answers the maturity questionnaire for light realistic blood (Moderate) |
| Muted, dirty colours on goods and props | Saturated shop goods and props | art.6: pull them toward the palette with a grime gradient |

Also open (our own polish, no Tarkov row): one wear strip per facade instead of a decal per wall part (art.7,
KNOWN_ISSUES 67); a lighter set of shelf goods (art.8, 46); the 59 off-centre kit origins (art.9, 69); the owner saving the
place to keep five Studio-only materials (art.10, 45); a rainy-raid check of streaks, splashes and lens drops (art.12, 25);
Meridian's deep halls, very dark with the power on (66); coarse cloth on the characters (14).

## Order of work

Since 2026-11-07 the order is the audit's: release blockers first (start-1a), every quick win (start-2a), Tarkov's rules
with optional aids (start-3b). `NEXT_TASK.md` holds the current list. The list of 2026-10-31, for the record:

1. Done 2026-10-31: the INSPECT window with an attribute sheet for every item kind and a turnable 3D model (the picture
   when an item has no model), tile counters, stash search and sort, the trader screen as TRADE / TASKS / SERVICES.
2. Done 2026-10-31: controls parity (Tarkov's default keys, quick slots 4 to 0, the checks, the raid time, rebinding)
   and settings parity (the five tabs).
3. Built: M11 part B. Every shot wears the gun, more when hot; Tarkov's four malfunctions (misfire, failure to eject,
   failure to feed, jammed bolt); since gameplay.11 (2026-11-08) on Tarkov's rules: from 93 % condition nothing but heat
   causes one, and wear, the round, the magazine and heat each add a chance below it; L finds the fault and Shift+T
   clears it; trader repairs and the repair kit lower the maximum (`Combat.luau`, `Economy.luau`, `Weapons.luau`). Not yet
   checked in Studio.
4. Done 2026-10-31: character tabs, messenger, handbook, wish list.
5. Done: Border Yard (2026-11-01), the flea market (2026-10-31), Quay 7 and Smelter furnished (2026-11-01). Next for the
   maps: art-1a and art-2d (section 11).
6. Done 2026-11-01: night vision and thermals, face overlays, variable zoom, the raid clock and seasons. PiP is not
   possible in Roblox (section 6).

## Sources

- Escape from Tarkov Wiki (Fandom): [Steyr AUG A1](https://escapefromtarkov.fandom.com/wiki/Steyr_AUG_A1_5.56x45_assault_rifle) (weapon fields), [6B13 assault armor](https://escapefromtarkov.fandom.com/wiki/6B13_assault_armor_(Flora)) (armor fields), [Performance modifiers](https://escapefromtarkov.fandom.com/wiki/Performance_modifiers)
- [CPG: ammo stats can now be seen in-game](https://consolepcgaming.com/escape-from-tarkov-ammo-stats-can-now-be-seen-in-game) (0.14.5)
- [GGRecon: best settings](https://www.ggrecon.com/guides/escape-from-tarkov-best-settings-improve-fps-visibility/) and [TarkovForge: graphics settings 2026](https://tarkovforge.com/blog/best-tarkov-graphics-settings-2025) (settings tabs)
- [GameSpot: controls and hotkeys](https://www.gamespot.com/articles/escape-from-tarkov-guide-for-controls-and-hotkeys/1100-6472601/), [Prima Games: controls](https://primagames.com/tips/escape-from-tarkov-complete-controls-guide)
- [TarkovForge: Salewa](https://tarkovforge.com/meds/salewa-first-aid-kit) (med fields), [Gamepressure: health and injuries](https://www.gamepressure.com/escape-from-tarkov/health-and-injuries/z1cf2f)
- Eyewear and face gear (2026-11-01): [TarkovForge: glasses](https://tarkovforge.com/glasses) (armor, durability, blindness protection), [6B34](https://tarkovforge.com/glasses/6b34-anti-fragmentation-glasses), [AFGlass](https://tarkovforge.com/glasses/anti-fragmentation-glasses), [Caiman visor](https://tarkovforge.com/glasses/galvion-caiman-fixed-arm-visor), [GP-5 gas mask](https://tarkovforge.com/face-covers/gp-5-gas-mask); Wiki: [Eyewear](https://escapefromtarkov.fandom.com/wiki/Eyewear), [RayBench Aviator glasses](https://escapefromtarkov.fandom.com/wiki/RayBench_Aviator_glasses) (Ragman LL4), [Kolpak-1S](https://escapefromtarkov.fandom.com/wiki/Kolpak-1S_riot_helmet), [EXFIL face shield](https://escapefromtarkov.fandom.com/wiki/Team_Wendy_EXFIL_Ballistic_face_shield_(Black)), [Maska-1SCh](https://escapefromtarkov.fandom.com/wiki/Maska-1SCh_face_shield_(Olive_Drab)), [Jason mask](https://escapefromtarkov.fandom.com/wiki/Jason_mask) (blocks lists)
- Stationary guns (2026-11-01): Wiki [Weapons](https://escapefromtarkov.fandom.com/wiki/Weapons) ("Stationary weapons"), [NSV Utyos](https://escapefromtarkov.fandom.com/wiki/NSV_Utyos_12.7x108_heavy_machine_gun), [AGS-30](https://escapefromtarkov.fandom.com/wiki/AGS-30_30x29_automatic_grenade_launcher); [Dexerto: grenade launchers](https://www.dexerto.com/escape-from-tarkov/how-to-destroy-escape-from-tarkov-players-using-grenade-launchers-1355803/) (arc and zeroing); the rest of the list is in `docs/design/STATIONARY_WEAPONS.md`
- Rounds (2026-11-08, economy-1a): Wiki [12/70](https://escapefromtarkov.fandom.com/wiki/12/70) and round pages ([M855](https://escapefromtarkov.fandom.com/wiki/5.56x45mm_M855), [M995](https://escapefromtarkov.fandom.com/wiki/5.56x45mm_M995), [HP](https://escapefromtarkov.fandom.com/wiki/5.56x45mm_HP), [US gzh](https://escapefromtarkov.fandom.com/wiki/7.62x39mm_US_gzh), [T-45M1](https://escapefromtarkov.fandom.com/wiki/7.62x39mm_T-45M1_gzh), [Green Tracer](https://escapefromtarkov.fandom.com/wiki/9x19mm_Green_Tracer), [LPS gzh](https://escapefromtarkov.fandom.com/wiki/7.62x54mm_R_LPS_gzh), [BS gs](https://escapefromtarkov.fandom.com/wiki/7.62x54mm_R_BS_gs)); TarkovForge ammo pages ([FMJ](https://tarkovforge.com/ammo/556x45mm-fmj), [M856A1](https://tarkovforge.com/ammo/556x45mm-m856a1), [M855A1](https://tarkovforge.com/ammo/556x45mm-m855a1), [PP gzh](https://tarkovforge.com/ammo/762x39mm-pp-gzh), [Pst gzh](https://tarkovforge.com/ammo/9x19mm-pst-gzh), [PBP gzh](https://tarkovforge.com/ammo/9x19mm-pbp-gzh), [SNB](https://tarkovforge.com/ammo/762x54mm-r-snb-gzh), [8.5 mm Magnum](https://tarkovforge.com/ammo/1270-85mm-magnum-buckshot)); xgamingserver item pages, snapshot 2026-11-04 ([7.62x39 HP](https://xgamingserver.com/tools/escape-from-tarkov/item/762x39mm-hp), [PS](https://xgamingserver.com/tools/escape-from-tarkov/item/762x39mm-ps-gzh), [BP](https://xgamingserver.com/tools/escape-from-tarkov/item/762x39mm-bp-gzh), [AP 6.3](https://xgamingserver.com/tools/escape-from-tarkov/item/9x19mm-ap-63), [RIP](https://xgamingserver.com/tools/escape-from-tarkov/item/9x19mm-rip), [FMJ M882](https://xgamingserver.com/tools/escape-from-tarkov/item/9x19mm-fmj-m882), [T-46M](https://xgamingserver.com/tools/escape-from-tarkov/item/762x54mm-r-t-46m-gzh), [PS 54R](https://xgamingserver.com/tools/escape-from-tarkov/item/762x54mm-r-ps-gzh), [BT](https://xgamingserver.com/tools/escape-from-tarkov/item/762x54mm-r-bt-gzh), [LPS](https://xgamingserver.com/tools/escape-from-tarkov/item/762x54mm-r-lps-gzh))
- Barter goods (2026-11-08, economy-1a's second slice): EFT's handbook prices, handbook folders and item names from SPT's server database (`project/assets/database/templates/handbook.json` and `locales/global/en.json` in [sp-tarkov/server](https://github.com/sp-tarkov/server)); grid sizes from TarkovForge's item pages (for example [Pack of screws](https://tarkovforge.com/loot/pack-of-screws), [Pressure gauge](https://tarkovforge.com/loot/pressure-gauge), [Hand drill](https://tarkovforge.com/loot/hand-drill), [Sewing kit](https://tarkovforge.com/loot/sewing-kit)); which goods the hideout and its crafts use from economy-7b's notes (tarkovforge.com/hideout). Weights: not on those pages, ours.
- Guns and rounds (2026-11-08, economy-1a's third slice): TarkovForge's [AK-74N](https://tarkovforge.com/weapons/kalashnikov-ak-74n-545x39-assault-rifle) and [PM](https://tarkovforge.com/weapons/makarov-pm-9x18pm-pistol) pages, its [AK-74 muzzle brake](https://tarkovforge.com/attachments/ak-74-545x39-muzzle-brake) and [6L20 magazine](https://tarkovforge.com/attachments/ak-74-545x39-6l20-30-round-magazine) pages, its [ammo table](https://tarkovforge.com/ammo) and round pages (for example [5.45 BS gs](https://tarkovforge.com/ammo/545x39mm-bs-gs) and [9x18 PBM gzh](https://tarkovforge.com/ammo/9x18mm-pm-pbm-gzh)); handbook prices from SPT's `handbook.json`.
- Self-loaders (2026-11-08, economy-1a's fourth slice): TarkovForge's [SKS](https://tarkovforge.com/weapons/toz-simonov-sks-762x39-carbine) and [SVDS](https://tarkovforge.com/weapons/svds-762x54r-sniper-rifle) pages; handbook prices from SPT's `handbook.json` (SKS 19,331, SVDS 42,800, SVD magazine 3,750, SVDS brake 602).
- 7.6x51 (2026-11-08, economy-1a's fifth slice): TarkovForge's [M1A](https://tarkovforge.com/weapons/springfield-armory-m1a-762x51-rifle) and [Remington Model 700](https://tarkovforge.com/weapons/remington-model-700-762x51-bolt-action-sniper-rifle) pages and its round pages (tarkovforge.com/ammo/762x51mm-<round>; the [ammo chart](https://tarkovforge.com/ammo) for the traders); handbook prices from SPT's `handbook.json` (M1A 30,264, M700 17,500, M1A magazines 1,234 and 2,468, the M700's Wyatt's Outdoor magazines 1,850 and 3,500, the National Match flash suppressor 4,759, the A.R.M.S. #18 mount 3,217, the multi-slot rail base 2,640, rounds 105 to 1,723).
- 9x39 (2026-11-08, economy-1a's sixth slice): TarkovForge's [VSS Vintorez](https://tarkovforge.com/weapons/vss-vintorez-9x39-special-sniper-rifle) and [AS VAL](https://tarkovforge.com/weapons/as-val-9x39-special-assault-rifle) pages and its round pages (tarkovforge.com/ammo/9x39mm-<round>); handbook prices from SPT's `handbook.json` (VSS 65,203, AS VAL 66,869, their integral barrel-suppressors 22,507 and 23,346, the 6L24 and 6L25 magazines 4,637 and 5,999, rounds 140 to 1,300).
- 4.6x30 and 5.7x28 (2026-11-08, economy-1a's seventh slice): TarkovForge's [MP7A1](https://tarkovforge.com/weapons/hk-mp7a1-46x30-submachine-gun) and [P90](https://tarkovforge.com/weapons/fn-p90-57x28-submachine-gun) pages and its round pages (tarkovforge.com/ammo/46x30mm-<round> and 57x28mm-<round>); handbook prices from SPT's `handbook.json` (MP7A1 44,288, P90 45,200, MP7 magazines 4,026, 6,001 and 12,142, the P90 magazine 10,500, rounds 70 to 745).
- 11.4x23 and the Five-seveN (2026-11-08, economy-1a's eighth slice): TarkovForge's [UMP 45](https://tarkovforge.com/weapons/hk-ump-45-acp-submachine-gun), [M1911A1](https://tarkovforge.com/weapons/colt-m1911a1-45-acp-pistol) and [Five-seveN MK2](https://tarkovforge.com/weapons/fn-five-seven-mk2-57x28-pistol) pages and its round pages (tarkovforge.com/ammo/45-acp-<round>); handbook prices from SPT's `handbook.json` (UMP 45 26,500, M1911A1 5,408, Five-seveN MK2 14,238, magazines 1,100 to 3,660, rounds 76 to 670).
- 9x19 guns (2026-11-08, economy-1a's twelfth slice): TarkovForge's [Glock 17](https://tarkovforge.com/weapons/glock-17-9x19-pistol), [MPX](https://tarkovforge.com/weapons/sig-mpx-9x19-submachine-gun) and [PP-19-01](https://tarkovforge.com/weapons/pp-19-01-vityaz-9x19-submachine-gun) pages; handbook prices from SPT's `handbook.json` (6,608, 18,907, 14,751; magazines 1,476, 1,450, 2,073, 2,422). Gaps: which trader sells each gun and at what level is ours (EFT's sellers not checked); no Glock 33-round or 50-round drum, no MPX or Vityaz parts (handguards, stocks, muzzle devices); weights ours.
- Revolvers (2026-11-08, economy-1a's eleventh slice): TarkovForge's [Rhino 50DS](https://tarkovforge.com/weapons/chiappa-rhino-50ds-357-revolver), [Rhino 200DS](https://tarkovforge.com/weapons/chiappa-rhino-200ds-9x19-revolver) and [RSh-12](https://tarkovforge.com/weapons/rsh-12-127x55-revolver) pages and its round pages (tarkovforge.com/ammo/357-magnum-<round>, /ammo/127x55mm-<round>); handbook prices from SPT's `handbook.json` (10,443, 5,800, 30,443; rounds 100 to 900). Gaps: the trader levels of .357 SP, the 12.7x55 loads and the guns are ours (the RSh-12 by barter); the two Crakes share one mastering group (EFT's Rhinos do); no speed loader; weights ours.
- 9x21 and .366 TKM (2026-11-08, economy-1a's tenth slice): TarkovForge's [SR-1MP](https://tarkovforge.com/weapons/serdyukov-sr-1mp-gyurza-9x21-pistol), [SR-2M](https://tarkovforge.com/weapons/sr-2m-veresk-9x21-submachine-gun) and [VPO-215](https://tarkovforge.com/weapons/molot-arms-vpo-215-gornostay-366-tkm-bolt-action-rifle) pages, its round pages (tarkovforge.com/ammo/9x21mm-<round> and /ammo/366-tkm-<round>) and its [workbench page](https://tarkovforge.com/hideout/workbench) for the two crafts; handbook prices from SPT's `handbook.json` (SR-1MP 19,292, SR-2M 31,000, VPO-215 7,350, magazines 1,506, 2,900, 3,500 and 1,200, rounds 70 to 788). Gaps: the VPO-209 came in the fourteenth slice with EFT's two-calibre magazines; the T-215 has its rail built in (EFT's VPO-215 takes a separate scope mount); the trader levels of 9x21 PS, BT and 7N42, the guns' and the magazines' are ours, and so are the weights; whether 7N42 is banned on the flea is not verified (here it is sold).
- VPO-209 and the two-calibre magazines (2026-11-09, economy-1a's fourteenth slice): TarkovForge's [VPO-209](https://tarkovforge.com/weapons/molot-arms-vpo-209-366-tkm-carbine), thread protector, rear sight, wooden stock and handguard, Rotor 43 .366, AK aluminium 10-round magazine, AKM and TGP-A pages; SPT 3.10.1's `items.json` and trader assorts (github.com/sp-tarkov/server, tag 3.10.1: magazine cartridge filters, chamber filters, slots, weights, malfunction chance; Skier, Jaeger, Mechanic); SPT's globals (the VPO-209 preset, the AKM mastering group) and `bots/types/assault.json` (the scavs' 6.4 %); the SPT Realism mod's `Weapons/ReloadPatches.cs` (EFT chambers only compatible ammunition); tarkov-market.com (today's sellers); the EFT wiki's VPO-209 page.
- 7.6x25 (2026-11-08, economy-1a's ninth slice): TarkovForge's [TT-33](https://tarkovforge.com/weapons/tokarev-tt-33-762x25-tt-pistol) and [PPSh-41](https://tarkovforge.com/weapons/ppsh-41-762x25-submachine-gun) pages and its round pages (tarkovforge.com/ammo/762x25mm-tt-<round>); handbook prices from SPT's `handbook.json` (TT-33 4,189, PPSh-41 10,251, magazines 1,157, 2,631 and 16,000, rounds 48 to 70).
- Hideout (2026-11-08, economy-7b, by the hideout thread): [TarkovForge: Hideout Tracker](https://tarkovforge.com/hideout/medstation) (levels, costs, bonuses, crafts), [TarkovForge: currency](https://tarkovforge.com/currency), Wiki [Hideout](https://escapefromtarkov.fandom.com/wiki/Hideout) (fuel, crafting without power), [GGRecon: fuel](https://cms.ggrecon.com/guides/escape-from-tarkov-fuel-where-to-find-craft-use/), [timesaver.gg: bitcoin farm](https://timesaver.gg/blog/tarkov-bitcoin-farm-guide), [timesaver.gg: scav case](https://timesaver.gg/blog/tarkov-scav-case-guide), [gameslikefinder: scav case](https://gameslikefinder.com/article/tarkov-scav-case/), [west-games: scav cooldown](https://west-games.com/scav-cooldown-calculator/), [xgamingserver: fuel tank](https://xgamingserver.com/tools/escape-from-tarkov/item/expeditionary-fuel-tank)
- Levels and experience (2026-11-08, economy-4b): [senseos.gg: Tarkov XP chart](https://senseos.gg/guides/escape-from-tarkov/levels-and-xp/) (the table to 79, the KIA / MIA modifier), [timesaver.gg: level up fast](https://timesaver.gg/blog/tarkov-how-to-level-up-fast) (head kills x1.2), gamemaps.net task pages ([Spa Tour 1](https://www.gamemaps.net/game/tarkov/quests/spa-tour-part-1), [Spa Tour 2](https://www.gamemaps.net/game/tarkov/quests/spa-tour-part-2), [A Shooter Born in Heaven](https://www.gamemaps.net/game/tarkov/quests/a-shooter-born-in-heaven), [The Punisher 1](https://www.gamemaps.net/game/tarkov/quests/the-punisher-part-1), [The Punisher 6](https://www.gamemaps.net/game/tarkov/quests/the-punisher-part-6), [The Cleaner](https://www.gamemaps.net/game/tarkov/quests/the-cleaner)), [AltChar: dailies](https://www.altchar.com/guides/escape-from-tarkov-5-reasons-why-you-should-be-doing-daily-quests-a8CQH4h5cKJ5)
- Boss weapons (2026-11-08, ai-5b): Wiki [40x46mm](https://escapefromtarkov.fandom.com/wiki/40x46mm) (damage, arming times, explosion radius, 76 m/s), [TarkovForge: M32A1 MSGL](https://tarkovforge.com/weapons/milkor-m32a1-msgl-40mm-grenade-launcher) (30 rounds a minute, ergonomics 30, recoil 238 / 560, effective distance 70 m), [IMFDB: launchers](https://www.imfdb.org/wiki/Escape_from_Tarkov/Launchers,_Explosives,_Mounted_Weapons,_Other) (only Big Pipe carries it)
- Atmosphere and ambience (2026-11-01): [Gfinity: 0.12.6 notes](https://www.gfinityesports.com/article/escape-from-tarkov-12-6-patch-notes-update-full-list-changes-wipe-pc) (first Steam Audio, indoor sound fix), [Steamworks: Steam Audio](https://partner.steamgames.com/doc/features/steam_audio), [PCGamesN](https://www.pcgamesn.com/escape-from-tarkov/update-audio-overhaul) and [Insider Gaming](https://insider-gaming.com/tarkov-patch-overhauls-immersive-audio/) (0.16.7.0 occlusion), [Wiki: Interchange](https://escapefromtarkov.fandom.com/wiki/Interchange) (illumination grid, alarm), [TarkovForge: Kiba Arms outer door key](https://tarkovforge.com/keys/kiba-arms-outer-door-key) (alarm 3 s after the door), [Guild Order: audio guide](https://guildorder.com/hi/games/tarkov/guides/audio-fluency-and-sound-triangulation) (distant shots); the rest is in `docs/look/ATMOSPHERE.md`
- Patch notes: [0.16.0.0 (Sportskeeda)](https://sportskeeda.com/esports/escape-tarkov-patch-notes-update-0-16-0-0-new-event-customs-rework-prestige-system), [0.16.7.0 (AltChar)](https://www.altchar.com/game-news/escape-from-tarkov-patch-0.16.7.0-full-patch-notes-aP2RA1G8vdlq), [1.0.4.5 (AltChar)](https://www.altchar.com/game-news/escape-from-tarkov-patch-1.0.4.5-improves-performance-reworks-weapon-balance-and-fixes-key-issues-aPJVC8b37l9m)

## 7. Maps (owner, 2026-11-01: same map as Tarkov's, own buildings and names)

| Tarkov | Zero Return | To do |
|---|---|---|
| Customs | Border Yard rebuilt on Customs' current layout at real scale (2026-11-01): terrain, river and both bridges, roads, rail, 67 buildings and 6 underground spaces with interiors (Block A and B dorms, fuel stop, old pumps, the Squat, stores 3, 4, 7 and 17, Red Stores, the Bastion with bunker K-13, the Derrick, the Frame, motor shop and boiler cellar, K-11, the Smugglers' Hole), 26 extracts with their rules, 12 spawns by side, the Broker and his crew, THE HOUNDS (the Goons) and THE CULT (the cultists, both 2026-11-02), border snipers, propane; `docs/maps/BORDER_YARD.md` | The real positions of the mounted guns (the system exists and two guns stand on the Bastion roof at our own positions: `docs/design/STATIONARY_WEAPONS.md`), transits to Reserve and Shoreline (the one to Interchange is in, the one to Factory since 2026-11-09, as are co-op and THE FORESTER, all 2026-11-02), ladders (built as stairs: no climbing), glass, washrooms and denser furniture in the dorms, the 0.16 interiors the reference only gives as extents |
| Interchange | Meridian Mall rebuilt on Interchange's layout at real scale (2026-11-01). Tested in Studio: the build, AI across the levels, every exit's path and rule, light by day and night, and the frame rate (`TEST_RESULTS.md`). Part 1 the outside, part 2 the mall shell (the car park, L1 and L2, atria, roof, stairs, dock bays and 84 empty store units; the stores' interiors are another agent's), part 3 the gameplay: 7 extracts with their rules (the shelter's power-then-valve chain, the empty-backpack fence gap), 25 PMC spawns on two halves, guard routes and posts, THE CARETAKER (60 %, five zones), what the mall power changes (electric locks, the IRONSIGHT alarm), a lethal minefield and a sniper band, ten new keys, car park dressing; `docs/maps/MERIDIAN_MALL.md` (Parts 2 and 3) | The transit to Streets (the one to Customs, the co-op and flare exits are in since 2026-11-02), the car exit's karma pricing (the car itself is built: "Car exits" below), the shelter's keypad chain and the Terragroup container, per-extract timers, key art; the lists under "Interchange mall shell" and "Interchange gameplay" below |
| Factory | The Smelter rebuilt on Factory's layout at real scale (2026-11-09; `docs/maps/SMELTER_FACTORY_BUILD.md`, reference `docs/maps/reference/FACTORY_REFERENCE.md` from the 2024-11 SVG of the 0.15 rework, tarkov.dev, the re3mr plan and SPT 0.16.9): the four levels (tunnels and sump, ground, gallery and second floor, third floor and catwalks) with the office block's three floors, 35 stair flights, the high bridge, catwalks, the crucible pit and vessels; nine exits with their sides and rules (one waits for its item), 16 spawns at SPT's groups, THE STOKER (Tagilla) at 30 % from SPT's seven boss points, THE CULT at night, the transit to Border Yard (and Border Yard's back to it), the emergency exit key's three doors (KEY_SMELT_OFFICE, 20 uses as EFT's), 92 containers in SPT's mix by kind and 50 loose spots, a 20-minute raid | Heights of roofs, walls, catwalks and machines are ours (no source has them); container and loose loot positions ours; Gate 2's position and rules grade C; the smugglers' crawl opens with our code-word note (since 2026-11-09: EFT's note with the code word "Ark", found in the Smelter's drawers and jackets only and taken away when the raid settles; our word and loot weights) and the sealed store with its keycard (EFT's TerraGroup storage room keycard: 10 uses, handbook 850,000; where EFT spawns it is unknown, ours is a rare key loot); transits to Woods and the Lab; the breach room is a plain door; duffle bags, grenade boxes and bodies are crates; one raid length (EFT's night Factory is 25 minutes); the cult chance 8 % (SPT 20 %); fewer container spots than planned in the manager's office (1 of 3) and the shift office (1 of 4); no PvE AI PMCs; the part count and a phone's frame rate not yet measured |
| Woods | Pinewatch, parked by the owner | - |
| Hideout look | The bunker is kept, not ruined (2026-11-01): painted walls, grime only where it gathers | Hideout customisation (section 3) |

### Interchange ground and outside: Meridian Mall, part 1 (2026-11-01)

- The transit to Streets does not exist (the one to Customs does). WEST CAMP is a co-op exit at the reference's co-op spot and
  RIVER PATH a flare exit (all 2026-11-02);
  SHELTER EXIT supports only the power rule (the hidden switch and the keycard panel are Play's).
- SUBSTATION CAR costs 20,000 MK (the 2026 figure) and is a vehicle exit since the "Car exits" work below (the price still ignores Scav karma); FENCE GAP's `nobag` rule is new.
- The second boss (the hammer boss in the KASSA garage), mounted guns, propane cylinders, airdrop points and the lethal bands are not built.
- The ponds and the east canal are dry ditches (the budget allows no terrain water), so there is no wading or swimming; the relief is
  a smooth blend of 31 knots and 155 height samples, so peaks are lower than the reference; the rock mounds and berms are ours.
- The roof height, the shelter room, UNIT 14, the washroom switch and the security terminal are grade D in the reference (placeholders).
- The two south border rails (`rail_2`, `rail_3`) lie outside the limit and are not built.
- Outdoor buildings are single rooms with one or two doors; the reference's real interiors of the camps and sheds are not copied.

### Interchange main floor stores: Meridian Mall, part 4a (2026-11-01)

- **Shop interiors are recipes, not copies.** Which shelf, counter and rack stands where in each of the reference's shops is in no source,
  so a shop is built from its kind, with about ten props (capped by floor area) rather than a shop's worth, to hold 30 fps on a phone.
  The 29 names, the signs and the sizes are the reference's; the fixtures are ours.
- **Containers are the existing kinds only.** There are no ammo box, grenade box, duffel bag or PC case kinds, so IRONSIGHT has weapon boxes,
  a safe, a drawer and a register (no ammo boxes, no grenade box, no armoured mannequins; the guns on its walls are scenery), and the
  clothing shops' mannequins carry nothing. Container counts per shop are ours (249 on L1, 81 of them registers).
- **RESCUE POINT** is medicine shelves, medbags, a drawer and a safe, with the three keyed doors; the reference's surgical and stimulant
  containers are not separate kinds.
- **Key spawns are pool rolls.** A loose spot can only roll a pool, so the five key tiles (NESTA, KASSA and the three BOLTWORKS keys) each
  roll the whole mall key pool (any `KEY_MM_*` or older mall key) instead of holding their one key. The IRONSIGHT, RESCUE POINT and security
  keys have no tile of their own (their `L.keys` positions are door and terminal icons) and come only from 16 low-chance spots; a key's
  chance is its pool weight, not the reference's per-key rate (about 3.35 key rolls a raid on L1).
- **Register keys open the till offices, not the registers** (already listed in Part 3; the registers themselves are open containers).
- **The closed unit** north of VIKING reads `TO LET` on its sign; the reference's unlabelled store has no sign.
- **The NESTA CANTEEN kitchen has no staff door** (it is open plan; `KEY_MALL_STAFF` opens the L2 food-court kitchen only).
- **Not built on L1:** loot or props in the concourse, the atria and the halls outside the shops, shop shutters and glass doors, shop-window
  displays, price tags, posters and signage art (no logos by design), and any sound.
- **Loot density** per container and per loose spot comes from the shared pools, with no per-spot tuning against the reference.

### Placement of props, doors and terrain (2026-11-01/02, owner: "ensure nothing is placed abnormally or glitching")

What Tarkov does: on Customs and Interchange every prop stands on a floor or hangs on a wall. Doorways and door swings
are clear: a door that opens into furniture does not occur. Furniture stands against walls, not through them.
Basements and bunkers are clean concrete rooms with no ground showing through. Trees stand outside buildings.

| Item | Tarkov | Zero Return before | Now |
|---|---|---|---|
| Underground rooms | Concrete floor, walls and ceiling | Terrain humps along every wall of Border's 6 underground rooms, up to 9.5 studs | Clean (the dig reaches past the walls) |
| Doors | Swing clear | 22 met a wall or a container as built, 6 could open only 10°; one stood in a solid wall | Each hangs the way that opens widest; 1 opens 90° |
| Containers | Chest, crate, safe or bag at its real size | Plain ones were all 4-stud crates, some floating over stair shafts or inside racks | Their own look prop; one model each, which the tidy can move |
| Props on floors | On the floor | THE SUBSTATION's props 1.15 studs into a plinth; drums and crates in terrain | On the floor |
| Props in props | Never | 15 stacked pairs, 33 chairs inside desks' own chairs | Removed by the tidy pass |
| Furniture in walls | Against the wall | 30 clipping | 14, all under 1.4 studs; 62 pieces of Border furniture still touch walls (`KNOWN_ISSUES` 69) |

Gaps still open:

- Furniture is still into walls by 0.2 to 2 studs.
- Kit origins sit off the middle of the footprint, so 59 kits stand up to a stud forward of where the builders aimed
  (`KNOWN_ISSUES` 69).
- The pump platforms were shortened to fit between the fuel tanks. Check that against the reference.

### Trees (2026-11-01, owner: "the trees are opaque", "i dont want the leaves totally opaque")

Like Tarkov's trees, crowns and bushes are alpha-tested needle and leaf cards. Spruce sprays hang like a comb spruce, and birches (white ringed trunks, airy crowns) grow among the spruce on Border and Pinewatch. The see-through texture is drawn within a radius of the camera that is set by the graphics level (HIGH 520 studs, MEDIUM 240, LOW 110). Beyond it, and on POTATO, the same cards are solid: a lower level of detail, as in Tarkov's LODs. Checked in Studio (`TEST_RESULTS.md`, See-through foliage).

Gaps against Tarkov's foliage:
- No wind sway.
- No separate LOD meshes or billboards beyond Roblox's automatic ones.
- One atlas for all trees: four kinds of card, no seasonal leaf colour on the birches (autumn yellow).
- Birch bark is vertex colour on a ring every 3.5 studs, not a bark texture.
- Fog: FOG raids close the view at about 150 m (480 studs) with a flat classic fog. Tarkov's fog also varies in thickness within a raid and lifts over time; ours is one level for the whole raid.

### Wall finishes (2026-11-01, owner: "walls look repetitive and fake")

Seven new MaterialVariants (gloss paint, whitewash, two wallpapers, wall tiles, brick, wood panelling), chosen per room or floor with a hue each (`docs/look/WALLS.md`):
- Border's dorm corridors and stairwells have Tarkov's Soviet two-tone: gloss paint to 1.5 m, a dark line, whitewash above.
- Checked in Studio: corridor before and after, room 104 in wallpaper (`TEST_RESULTS.md`).

Gaps:
- The reference is grade C: finishes and mix are inferred from period interiors, not read from Tarkov.
- Wallpaper tiles are clean (fixed 2026-11-01: the stains used to repeat every 2 m); its wear comes from scattered decals, and the print itself still repeats every 2 m, as real wallpaper does.
- Only Border's dorms and works pick finishes by room; the other maps use the weighted pick.
- Stairwell bands do not follow the flights.
- No stencilled signs, glazed brick, rendered concrete or plywood.
- Texture origins are not aligned to floors or doors.

### Customs dorm interiors: Border Yard (2026-11-01)

Built in `Living.luau`, checked in Studio (`TEST_RESULTS.md`, Border Yard dorm interiors):
- Rooms: a fifth stripped, the rest lived in.
- Doors: hinged on 118 of 128 unlocked rooms.
- Washrooms and kitchen: a shared washroom on every floor (A 115/215/315, B 121/221) and a kitchen in A 308.
- Windows: 30 % whole panes, the rest half broken, open or boarded.

Gaps (details in `docs/maps/BORDER_YARD.md`, Gaps):
- No L-shaped second-floor hall or the reference's room shapes.
- No radiators, posters or switches.
- Panes do not break when shot, and Tarkov's glass does.
- The washrooms' places and B's washrooms are inferred.
- No common or rest area as such.
- The furniture shares are ours.

### Interchange small shops filled (2026-11-01)

`StoresFill.luau` furnishes 45 small shops by kind, with 1,938 parts (`TEST_RESULTS.md`, Meridian small shops filled):
- clothing: rails, racks, mannequins and a fitting room;
- electronics: TV walls and tech tables;
- sport: shoe walls and weight racks;
- the rest: shelving, fridges and gondolas;
- in every shop: posters, wall bands, fallen goods and a toppled rack.

Gaps:
- No source gives Tarkov's small-shop fixtures, so these are ours by kind and copy no Tarkov shop.
- Posters are blank coloured sheets.
- L2's shops and L1's shallow shops (VOYAGE, GERMAN, SPIEL, TEXHO) stayed near their old density, because their recipes already fill the floor.
- Some side walls are still bare.

### Interchange upper floor stores and car-park rooms: Meridian Mall, part 4b (2026-11-01)

Researched first (`docs/maps/reference/INTERCHANGE_REFERENCE.md` sections 4.4 and 8.1 to 8.5: the L2 store list and what each sells, the
ULTRA medical storage, the saferoom's and Object 14's contents, TECHLIGHT as the best tech store, the SPT container groups), then built.
Status: written and passed through `tools/luau_check.py`; the placement also ran in an offline plain-Lua mock against the real shell and
was checked there (nothing overlapping or through a wall, entrances clear, walkable floor to every container and loose spot). Nothing has
run in Luau, Studio, on a phone or on a console, and no frame rate was measured. Details, the unit table and the counts:
`docs/maps/MERIDIAN_MALL.md`, "Part 4b".

Matched:
- **All 31 units of the upper floor furnished for what they are**, at the reference's rectangles: 11 food-court restaurants (kitchens,
  counters, seating), 7 clothing stores, 2 general stores, 2 pharmacies, 2 electronics stores, the furniture store, the museum, the travel
  agency, the sports and games hall, the closed unit under repair and the "opening soon" unit (half-built, dust sheets); a stock room behind
  each unit that has one in the shell (25 of 31).
- **The ULTRA medical storage as a locked room full of medical loot**, next to the ULTRA pharmacy (MEDIQ), opened by `KEY_MEDIQ` (a key door
  that also needs the mall power, by Play's electric-lock rule).
- **TECHLIGHT (VOLTA) as the best tech store**: computers on the floor and a stock room locked with `KEY_VOLTA_STORE`, full of graphics cards,
  server cases and cable crates (the `tech` pool).
- **The food-court staff kitchen** behind the reference's Burger Spot #49, locked with `KEY_MALL_STAFF` (kitchen fridge, dry store, lockers,
  a safe, a first-aid case).
- **The saferoom's reference contents** (a couch with valuables, food and drink shelves, a weapon case and crates) inside THE SHELTER.
- **The key tiles' positions** for `KEY_MALL_STAFF`, `CARD_MALL_VAULT` and `KEY_VOLTA_STORE` (loose spots of the key pool) and for `KEY_MEDIQ`
  (inside its room, on MEDIQ's till).
- **The game's own container kinds and loot tables** only (`Loot.luau` untouched): 148 containers and 166 loose spots, 60 lamps that stay dead
  until `MALL_POWER`.

Gaps (not copied or not found):
- **Interiors are ours.** The reference gives each unit's rectangle and kind (and a few loot notes), not its shelves, counters or tables;
  every room is built by recipe from the kit.
- **Every container is filled in every raid.** SPT draws a subset of its container groups per raid (Ultra 45 to 49 of 129, MedicalShops 14 to
  18 of 38, ClothingShops 14 to 18 of 29); here all 114 on L2 and 34 on L0 exist and roll their kind's table, so loot density needs tuning
  against the reference once the map can run.
- **The saferoom** has no microwave (nothing in the kit) and no keypad or urinal step (those are Play's); its dormitory, mess, infirmary and
  armoury are ours. **UNIT 14**'s interior is ours (the reference gives none): six walk-in shipping containers holding safes, crates and cases.
- **The ULTRA medical storage** is a whole locked unit behind one door (the reference places the room, not the door: grade C); the four LEDX
  spawn spots are not copied (no such item here).
- **A loose spot cannot name its item**: the key tiles are `mallkeys` pool spots, so the key that lies there is a roll of that pool (a pool
  holding only that key would fix it, as Part 4a notes).
- **Stock rooms** exist for 25 of the 31 units; five restaurants and `L2_father_sons` have none, as in the shell. The MEDIQ STORE ROOM's own
  stock strip is nearly empty (the stock door's swing zone takes most of it).
- **The sports hall, travel agency, museum and the two unfinished units** are only named by the reference; what they hold is ours.
- **Lamps** (60, off until the mall power) are ours; the reference's lighting is not documented.
- **Not run**: nothing above has run in Luau, Studio, on a phone or on a console; no frame rate or part count was measured in Studio.

### Interchange gameplay: Meridian Mall, part 3 (2026-11-01)

Researched first (`docs/maps/reference/INTERCHANGE_REFERENCE.md` sections 6 to 8: SPT data of the old map, tarkovforge and re3mr 2026,
the wiki, keengamer, ggrecon, lfcarry), then built. Status: written and passed through `tools/luau_check.py` only; nothing has run in
Studio, on a phone or on a console, and no frame rate was measured. Details and counts: `docs/maps/MERIDIAN_MALL.md`, "Part 3".

Matched:
- **Seven extracts at the reference's spots**, offered to the half of the perimeter SPT offers them to: RAIL SIDING (Railway Exfil) to
  MallSE, RESCUE CHECKPOINT (Emercom Checkpoint) to MallNW, SUBSTATION CAR (Power Station V-Ex, paid), SHELTER EXIT (Saferoom Exfil),
  RIVER PATH (Path to River), FENCE GAP (Hole in the Fence) to both, WEST CAMP (Scav Camp) scavs only.
- **FENCE GAP needs an empty backpack slot** (SPT `RequiredSlot` Backpack): refused on entering and cancelled if a pack is put on during
  the hold; the HUD says "NO BACKPACK".
- **The mall power matters**: the Kiba (IRONSIGHT) doors, the ULTRA medical storage (MEDIQ store room), the saferoom card door and the
  container-room card are electric locks, dead without power even with the key.
- **Saferoom chain starts with the power**, then a hidden handle in a second-floor washroom, then the card door, then the exit.
- **The Kiba alarm**: it sounds about 3 s after the outer door opens, calls bots, and is switched off at a terminal in a first-floor
  security room.
- **Killa as THE CARETAKER**: 60 % (tarkovforge 2026), five zones (the reference's), one picked each raid, no guards (SPT
  `BossEscortAmount` 0).
- **Spawns**: 13 + 12 groups (the reference's clusters) on the two halves; the 40-minute raid (2,400 s) was set in part 1.
- **Keys**: 40 uses on door and register keys, 10 on the two Object keycards (tarkovforge key pages 2026); the ULTRA key (MEDIQ) now has 40.
- **The west band is a minefield and the east band is a sniper band**, both outside the playable area as in the reference.

Gaps (not copied or not found):
- **Second boss: built 2026-11-02** as THE STOKER (`docs/design/BOSS_STOKER.md`). He is rolled at 35 % on his own beside
  THE CARETAKER, alone in the KASSA GARAGE. He has 1,220 health, a class 6 carrier, the welding mask (a face cover that stops face hits),
  and a shotgun. Within 15 m of a target he can see, he charges with a sledgehammer that cannot be looted. Gaps:
  - his gun is a pump, not a semi-auto, and there are no flechette rounds;
  - no yell;
  - the mask reuses the faceplate mesh, and a player wearing it sees the gas mask frame;
  - the body's health scales evenly (thorax 235 against 320);
  - the arms keep the gun pose while he swings;
  - no ambush or breaching.
- **Airdrops: built 2026-11-02** (`docs/design/AIRDROPS.md`). Each raid rolls 20 % with 6 or more alive (people and AI);
  the plane comes 5 to 15 minutes in, at most once. A crate (common, medical, supply or weapon; 10 x 12) comes down under
  a canopy and gives off red smoke. Gaps:
  - the plane is silent until a sound is uploaded;
  - the red flare (built the same day, from the inventory or a quick slot) has no special slot or flare gun;
  - drop points are found as open level ground, not Tarkov's fixed zones;
  - no bonus backpack.
- **Transit extracts**: the transit to Streets does not exist; the one to Customs links to Border Yard. (WEST CAMP is a co-op exit
  and RIVER PATH a green-flare exit since 2026-11-02.)
- **SUBSTATION CAR** was a plain paid exit when part 3 was written; it is a vehicle exit now (see "Car exits" below: 50 % chance, pay at the car, 4 seats, shared countdown, single use). Still a gap: no Scav karma in the price.
- **Saferoom chain simplified**: the urinal flush that reveals a keypad is a service valve in the washroom; not copied are the keypad,
  the lever for the Object-14 container, and the Terragroup container (Object #21WS card) in the south-west container yard. The inside
  button was added 2026-11-02: once inside, pressing it shuts and seals the card door for the rest of the raid (`Doors.seal`, switch
  `SHELTER_LOCK`), and only then does SHELTER EXIT count (rule `last`).
- **Extract timers: done 2026-11-02.** Each exit has its own timer as in Tarkov (SPT `ExfiltrationTime`): the standard 8 s
  (it was 6), SHELTER EXIT 3 s (the Saferoom), FENCE GAP 10 s (the Hole in the Fence); a car keeps its 60 s shared countdown.
  Still a gap: exits other than Interchange's and Customs' use the standard 8 s without a check against their own data, and
  RIVER PATH's timer is in no source.
- **Exits as places (walk-through 2026-11-02)**: the Saferoom is a room-sized bunker, not the whole block; the Hole in the
  Fence is a hole in a fence with drums and a red container; the railway leaves through a tunnel portal (our boundary is a
  hill, where Tarkov's world goes on past a fence). Added 2026-11-02: an orange oil tanker by the fence hole, a toll booth with
  a lowered boom at RIVER PATH's flare spot, and the Saferoom's door button. The booth and tanker are built from parts, with
  positions our own (the guides name them, no source places them).
- **Bands' rules are in no source** ("deadly sniper", "minefield"): the mine radius (3.4 studs), the blast, the lethal wound and the
  sniper strips are ours (the snipers copy Border Yard's).
- **Alarm details**: the siren (a procedural warble in `ZR_SFX_Amb`, silent until that asset is uploaded), the beacon, the 60 s length
  and the terminal's position are ours (the only source places terminals on a pre-0.12.4 map at grade D).
- **Register keys open the till offices**, not the registers (a container cannot be key-locked here).
- **Killa's AI and gear**: routes, aggro and regeneration are in no source; the existing Caretaker AI and kit stand in.
- **Mounted guns and propane cylinders**: no source places any on Interchange, so none stand on Meridian.
- **Spawns on the mall's terraces** are moved to the ground; the 2026 sources call both corner exits neutral, the build follows SPT.
- **Art**: the ten new keys have no icon or model yet.
- **Not run**: nothing above has been run in Studio, on a phone or on a console, and the new LogicTests group and MapTests M01 to M05 for
  this map have not been run either.

### Interchange mall shell: Meridian Mall, part 2 (2026-11-01)

Researched first (`docs/maps/reference/INTERCHANGE_REFERENCE.md` sections 4 and 5: outline and wings, heights, vertical links, docks,
restrooms, power), then built. Status: written and passed through `tools/luau_check.py`; the geometry also ran in an offline plain-Lua
mock and was checked there (floor tops, walkability, openings, Play's floor rule). Nothing has run in Luau, Studio, on a phone or on a
console, and no frame rate was measured. Details, the unit table and the counts: `docs/maps/MERIDIAN_MALL.md`, "Part 2".

Matched:
- **The footprint, wings and three levels at real scale**: the 22-point outline, the car park at floor 0, L1 at 17.81 and L2 at 47.50 (the
  reference's 5.7 m and 15.2 m above the car park, times 3.125), the L2 floor only over the central block, the three halls open up to their roofs.
- **Three anchor halls** at the reference's rectangles (KASSA east, NESTA north, BOLTWORKS south) with their back-of-house blocks, stock
  rooms, offices and goods-in, and eight checkout lanes each.
- **All 76 store records** of the reference as fitted empty units at their rectangles (snapped to 1 m): glass front, entrances at the
  reference's openings, stock room, party walls, sign over the door.
- **Vertical links where the reference puts them**: nine stairs or ramps between the car park and L1, two stairs and three escalators
  (stopped, as in the game) between L1 and L2 on the central axis, the four dock ramps (Ground) meeting the L1 decks.
- **The car park**: zones A to D and the NESTA, KASSA and BOLTWORKS garages, the service tunnel, THE SHELTER block with its vestibule and
  card door, UNIT 14 with its card door; stairs up at the nine spots.
- **Two atria with octagonal domes and about 40 skylights**; the roof cannot be reached (no stairs or ladders in the reference).
- **Two docks on the east walls** with their bays at the reference's 8.1 m pitch.
- **A washroom on L2 for the saferoom chain and a security room on L1** for the alarm terminal.
- **Dark until the power is on**: the main lamps follow the mall power; a few red emergency lamps stay lit.

Gaps (not copied or not found):
- **Walls are inferred**: the reference draws the outline, some closed blocks and a few partitions; every other wall follows the store,
  hall and corridor rectangles snapped to a 1 m grid (within 1.6 studs).
- **Escalators** are solid single-lane flights (no up and down lanes, no moving steps); one stair is steeper than the reference (32 degrees
  against 28) because the grid shortened its run.
- **Domes** are eight-pane glass drums with a stepped cap; the skylights are 41 flat strips.
- **Loading docks**: 7 bays per dock (the reference: 8) in a straight wall, not a sawtooth; the bay doors, their size and any levellers are
  in no source; six bays stand open and eight are shut by a plate (our choice).
- **Interiors that no source gives** (the shelter room, UNIT 14, the washrooms, the security room, the tunnel's inside) are ours; so is the
  tunnel's east passage to the KASSA garage and the car park's column grid (50 studs; the reference: about 8 m).
- **Lighting**: the reference's lamps and their dead/alive rules are not documented; ours are 149 sparse lamps and 26 red ones.
- **The atria open down to the car park**: no source says what lies under them.
- **The stores are empty boxes**: no counters, shelves, stock or loot (the stores agents'); 12 small or open stores have no stock room.
- **Not run**: nothing above has been run in Luau, Studio, on a phone or on a console.

### Car exits: Tarkov's vehicle extracts (V-Ex), Border Yard and Meridian Mall (2026-11-01)

Researched first (escapefromtarkov.party "Every Extraction Type" and tarkov.help, read 2026-11-01; the maps' own references:
`docs/maps/reference/CUSTOMS_REFERENCE.md` for the Dorms V-Ex and `docs/maps/reference/INTERCHANGE_REFERENCE.md` for the Power Station
V-Ex: SPT data, the wiki, re3mr 2026), then built in `src/server/Services/Extract.luau`, `Match.luau` and `Raid.luau` with the HUD in
`Hud.luau`. The two exits are DORMS CAR (Border Yard `DC`, 25,000 MK) and SUBSTATION CAR (Meridian Mall `SC`, 20,000 MK); their rules in
`L.ext` are `{ kind = "paid", cost, chance = 0.50, seats = 4, depart = 60 }`. Details: `docs/maps/BORDER_YARD.md` and
`docs/maps/MERIDIAN_MALL.md`, "Car exits". Status: written and passed through `tools/luau_check.py` only; nothing has run in Luau, Studio,
on a phone or on a console, and the new LogicTests group ("car ..." checks) has not been run.

Matched:
- **The car is not there every raid**: its `chance` is rolled at raid start with the chance exits (SPT: 50 % for both cars). An absent car
  is gone from the map, the zone says "NOT AVAILABLE THIS RAID" and the fare prompt does not exist; the exits list shows the car like a
  chance exit ("PAY 20,000 MK  ·  MAY BE UNAVAILABLE", red once the zone has told you).
- **You pay at the car**: a hold-F prompt on the car, "Pay 20,000 MK · SUBSTATION CAR". The fare is taken at once, from each passenger
  (a squad pays one fare per head), and is never refunded.
- **Four seats**: the fifth passenger is refused ("THE CAR IS FULL"). No money, not in the raid, the car already gone and a seat
  already held are also refused, each with a toast and without taking anything.
- **One countdown for the car**: the first fare starts it, later passengers join the same one, and every seated passenger sees it
  ("CAR LEAVES IN 0:45", the last ten seconds on the big notice with the extraction beep).
- **Stay by the car**: when the countdown ends the car leaves; a seated passenger inside the zone extracts (SUCCESS, the usual summary),
  one outside it is left behind and told "THE CAR HAS LEFT WITHOUT YOU", with no refund.
- **Single use**: after the departure the exit reads "THE CAR HAS LEFT" for the rest of the raid, in the zone, at the prompt and in
  every raider's exit list (they all get a fresh snapshot).
- **PMCs only**: scavs do not get a car in their exit list and cannot pay one.
- **No normal hold at a car**: standing in the zone without a seat does nothing but say "PAY AT THE CAR".
- **Reset**: seats, countdown and departure start clean with every raid.

Gaps (not copied or not found):
- **Price by Scav karma**: Tarkov's fare depends on Scav karma (wiki) and each ride adds karma (+0.2, re3mr 2026). There is no karma
  here, so the fare is one flat figure per exit: 25,000 MK at DORMS CAR (the old map's price, kept) and 20,000 MK at SUBSTATION CAR (the
  2026 figure; the wiki and SPT say 5,000 roubles). Check both against the MK scale in the economy.
- **Countdown length is grade C (from memory, to confirm)**: the sources read for this work do not state it; the maps' references quote a
  60 s shared timer (SPT data), so each car carries `depart = 60`. It is one field per exit; the default in `Extract.luau` is also 60.
- **The 50 % chance** is SPT's for both cars; the wiki calls the Power Station car "always" there (the sources disagree; the build follows SPT).
- **The car itself**: one sedan prop beside the zone's middle for every car (Tarkov's vehicles differ per map), with no engine sound, no
  doors and no drive-away: it simply disappears when it leaves. Tarkov pays through an interaction at the car; ours is a held prompt on
  its right flank (1.5 s).
- **Joining after the first fare**: a later passenger can still pay and take a seat while the countdown runs. The sources read describe
  no cut-off, so none is built; if Tarkov locks the car shortly before it leaves, this is a gap.
- **Squad rules**: nothing ties a squad to one car; each member pays and boards on their own.
- **Not run**: nothing above has been run in Luau, Studio, on a phone or on a console. A second player is needed to see the shared
  countdown and the "left behind" case. The touch tap on a prompt now holds it for its whole hold time (`Interact.luau`), which also
  affects the other hold prompts (the Meridian levers, the Border switches); that is untested on a phone too.

### Breakable glass: window panes (2026-11-01)

Researched first; **no source that states how Tarkov's window glass behaves could be read** (the wiki's Ballistics and Changelog pages say
nothing about windows; the forum threads about glass damage and the Kiba store glass, the wiki's Penetration page and web.archive.org
could not be opened). The rules below are therefore the owner's brief, not checked against the game, and sit in one table
(`Glass.CFG`) to tune. Built in `src/server/Services/Glass.luau` and `src/client/Controllers/GlassFx.luau`, with small hooks in
`Ballistics.luau`, `Combat.luau`, `AI.luau`, `Stationary.luau`, `Doors.luau`, `Effects.luau` and the two map builders (`Border/Living.luau`,
`Meridian/MallShell.luau`). Full design, costs, Studio check list and gap list: `docs/design/GLASS.md`. Status: written and passed through
`tools/luau_check.py` only; nothing has run in Luau, Studio, on a phone or on a console, and the new LogicTests `glass:` checks have not been run.

Matched (to the brief):
- **A bullet breaks the pane and goes on** from just past it, on the same line, with 7.5 % less damage and penetration per pane (the middle
  of 5 to 10 %), no deflection; the AI's and the mounted guns' bullets do the same.
- **A knife swing breaks a pane** and is spent on it; the AI hears it.
- **A broken pane no longer blocks**: it is gone and can be walked or vaulted through like an open window; a new raid mends every pane.
- **Shards and sound**: a short spray of shards (none on the lowest graphics level), glass on the floor on both sides for the raid, a
  breaking sound that carries further for a bigger pane.

Gaps (not copied or not found):
- **Tarkov's real behaviour is unverified**: the loss, "no deflection", melee breaking and that every pane breaks are all from the brief.
- **No bulletproof glass**: nothing found shows where Tarkov has it (the Kiba store forum titles hint that some glass is special).
- **A pane breaks whole**: no cracking stage, no partial holes, no fragments left in the frame; Meridian's shop fronts are cut into panes
  of at most 20 studs so one shot does not clear a front.
- **Only window glass**: balustrades, skylights, mirrors, counter glass, vehicle windows and the sawmill booth are unchanged; grenade blasts
  and fists do not break glass.
- **Meridian's shop glass no longer stops the AI's sight or thrown grenades** (it was solid to every ray before); only shots and blows meet it.
- **The sound is not in the game until `ZR_SFX_Amb` is re-uploaded** (the file changed: three glass sounds added at its end) and
  `Sounds.AMB_ATLAS` is replaced; until then glass breaks silently.
- **Not run**: the collision-group plan (hit shells in group `ZR_Glass`, shots in `ZR_Shot`) rests on documented Roblox behaviour and
  has not been seen working in Studio.

### THE HOUNDS: Customs' Goons on Border Yard (2026-11-02)

Researched first (tarkovforge's Knight, Big Pipe and Birdeye pages, timesaver.gg's Goons guide for patch 1.1.0, the Fandom
pages; `docs/design/BOSS_HOUNDS.md`), then built in `Maps/Border/Play.luau`, `AI.luau`, `Loot.luau`, `Inv.luau` and
`Equipment.luau`. Checked in Studio with one player (TEST_RESULTS "THE HOUNDS").

Matched:
- **Three bosses who move together**, rolled at 20 % on Customs' map, from the Stronghold (our Bastion yard), roaming a
  loop of the map.
- **Their health**: 1,120, 910 and 795.
- **Their gear, where we have an equivalent**:
  - HALBERD (Knight): class 5 on the body, an unarmoured head with a goggle mount and the panoramic goggles now and then,
    a face cover;
  - MORTAR (Big Pipe): no head armour, grenades for flushing cover, and since 2026-11-08 (ai-5b) the GL-6 six-shot
    grenade launcher (our M32A1), lobbed from range, with his rifle for close in;
  - KESTREL (Birdeye): a class 4 vest, a chest rig, a frame pack, a marksman rifle.
- **Five double pockets** (ten cells) on all three, drawn as 5 x 2 on their bodies.

Gaps:
- **One launcher round**: 40x46 HE only (EFT's M386 figures); no buckshot or HEDP rounds.
- **Weapons**: no Mk47 or 7.62 x 51 marksman rifle; the R-17 builds stand in.
- **No unique items**: no skull mask (a gaiter, cosmetic, where Tarkov's is class 1), no bandana or pipe (a beanie), no
  class 5 armoured rig (a vest with a chest rig on top).
- **Ours**: KESTREL's class 3 helmet, the 35 % goggle chance and the loot rolls.
- **One map**: they do not rotate to other maps; there is no tracker.
- **One AI**: all three use the boss skill, with no leader push or overwatch of their own.
- **Health spreads evenly** over the body's parts, not Tarkov's per-part numbers.
- **Looks reuse existing overlays and gear**: no new meshes.

### Flare exits: the green signal flare (2026-11-02)

Researched first:
- the Fandom Customs page: Railroad Passage (Flare) and Old Gas Station;
- tarkovforge's page for the green RSP-30;
- dotesports' flare guide and diamondlobby's Klimov Street guide;
- our map references (`CUSTOMS_REFERENCE.md` section 9, `INTERCHANGE_REFERENCE.md` for Path to River).

Built in `Items.luau`, `Airdrop.luau` (the shot), `Extract.luau`, `Match.luau`, `Raid.luau`, `Hud.luau` and the two layouts.
Checked in Studio with one player (TEST_RESULTS "Flare exits").

Matched:
- **The green flare** `FLARE_GREEN`: 1 x 2, 0.19 kg.
  - Sold by VOS at loyalty 1 (Tarkov: Jaeger LL1). Found where red flares are, a little more often.
  - Used like the red one: a 1.2 s use, open sky only, a green star.
- **Flare exits** (rule `flare`): NORTH LINE on Border Yard (Railroad Passage) and RIVER PATH on Meridian Mall (Path to River).
  - Each exit is there every raid but closed.
  - A green flare fired under the open sky inside its signal area (94 and 75 studs round the exit) opens it for the rest of the
    raid. A flare outside the area opens nothing.
  - The shooter gets "SIGNAL SEEN · ... OPEN".
- **"Signal Area"**: stepping into a closed flare exit's area shows "SIGNAL AREA · FIRE A GREEN FLARE TO OPEN ...".
- **Exits list**: it reads "GREEN FLARE IN THE SIGNAL AREA" until the flare, then "OPEN · FLARE SEEN". The zone itself says
  "FIRE A GREEN FLARE IN THE SIGNAL AREA".
- **Old Gas Station's "Green flares = Open"**: OLD PUMPS keeps its 50 % roll. While it is there, a green star goes up over it
  every 50 to 80 s (rule `signal`).

Gaps:
- **Who it opens for is ours.** No source says whether the flare opens the exit for the shooter, the group or everyone; here it
  opens for everyone in the raid. Streets' guide says one player's flare stops the sniper for all.
- **Height**: Tarkov's flare must climb high enough. Ours needs open sky above the shooter (220 studs).
- **The signal areas are ours**: Customs' flare area position is unknown (the north rail tip is used). Interchange's is inferred
  at the toll booth, 34 studs from the exit.
- **Railroad Passage's sniper rule** ("stay on the tracks") is not tied to the flare: the border snipers' strips already leave the
  rail walk clear.
- **Old Gas Station's signal** is our reading of "Green flares = Open". The interval is ours.
- **No flare gun, no yellow flare** (quests), and no special slot.
- **No art**: the item has no inventory picture yet.

### THE CULT: Customs' cultists on Border Yard (2026-11-02)

Researched first (tarkovforge's Cultist Priest page, live from tarkov.dev; timesaver.gg's priest guide for patch 1.1.5;
v-tarkov's older page; `docs/design/BOSS_CULT.md`). Built in `Maps/Border/Play.luau`, `AI.luau`, `Health.luau`, `Loot.luau`,
`Items.luau` and `Equipment.luau`. Checked in Studio with one player (TEST_RESULTS "THE CULT").

Matched:
- **Spawn:** a priest with two to four warriors, 20 % on Customs' map, night raids only, by the crackhouse and the
  construction site.
- **Health and armour:** the priest's 850 health; robes and no armour.
- **Ambush:** warriors lie prone in the dark and spring up to stab anyone who comes close; hurt or spotted, they fight on
  with suppressed SMGs.
- **Poison:** a stab poisons with a toxin that keeps hurting until an antidote; the knife is the signature loot.

Gaps:
- **No raised hood** (a beanie stands in; the hood mesh hangs down the back).
- **The toxin's numbers are ours** (1 hp/s over the body, faster thirst and hunger); only one cure (no Augmentin).
- **The looted knife** has the field knife's stats and does not poison.
- **The night rule** is "the raid starts in the dark", not Tarkov's exact hours.
- **Zones are ours**; not on other maps; no cultist circle.

### Hideout style: walls, floor and ceiling (2026-11-02)

Researched first: the 0.16.0.0 patch notes (floor, walls, ceiling and range targets; posters and collectibles; unlocks
by level, tasks and achievements; visiting friends) (`docs/design/HIDEOUT_STYLE.md`). Built in `HideoutStyle.luau`,
`Hideout.luau`, `Trade.luau` and `LobbyStyle.luau`. Checked in Studio with one player (TEST_RESULTS "Hideout style").

Matched:
- **Three categories:** walls, floor and ceiling styles, chosen in the hideout screen.
- **Unlocks by character level,** including Tarkov's named rewards: modest wallpaper, blue paint, small tiles.

Ours (exception 2, the shared Relay 7 bunker):
- **Each player sees their own style** in the shared bunker.

Gaps:
- **Level unlocks only** (no tasks or achievements).
- **No posters, collectibles or range targets.**
- **No visiting another player's hideout.**

### Transits: Border Yard and Meridian Mall linked (2026-11-02)

Researched first: the Customs and Interchange references (SPT `transits`: open 60 s in, 20 s timer; Prima and re3mr
positions), the 0.15 patch notes (zone, context option, no other exit once started, groups only together, stash for a
price) and Shacknews' Customs list (`docs/design/TRANSITS.md`). Built in `Transit.luau` (new), `Extract.luau`,
`Raid.luau`, `AI.luau`, `World.luau`, `Hud.luau` and both maps' `Play.luau`. Checked in Studio with one player
(TEST_RESULTS "Transits").

Matched:
- **Where:** Customs to Interchange at the trailer park's vehicles (two wrecks by the wood); Interchange to Customs at
  the highway's south end.
- **When:** open 60 s into the raid, 20 s in the zone.
- **Rules:** no other exit once it runs; a squad only when everyone is there.
- **What you keep:** your gear and wounds go with you, and you arrive at the other map's transit with its exits.

Gaps:
- **One raid clock** for both maps (Tarkov's new raid starts fresh).
- **The new map is quieter:** six scavs, no bosses, no car.
- **No sending found items to the stash.**
- **Only these two maps;** no grime detail on the map you arrive on.

### Co-op exits: a PMC and a scav leave together (2026-11-02)

Researched first: Shacknews' Customs extract list ("Boiler Room Basement (Co-Op) ... you need to have a PMC with you in
order for this extract to activate"), the Customs reference (`docs/maps/reference/CUSTOMS_REFERENCE.md`: scav cooperation,
since 1.2.0.0 open to PMCs from either side), the Interchange reference (Scav Camp co-op in the garage tunnel) and Prima
Games (co-op extraction raises Fence reputation for the scav and the PMC). Built in `Extract.luau` (rule `coop`),
`Economy.luau`, `Progress.luau` and both map layouts.

Matched:
- **BOILER CELLAR** (Customs' Boiler Room Basement) and **WEST CAMP** (Interchange's Scav Camp) are co-op exits.
- **Both must be there:** a PMC can leave only with a player scav in the zone, and a scav only with a PMC. Each hold runs
  only while a partner from the other side is still in the zone.
- **Both gain Fence standing** for leaving that way (`Progress.KARMA.coop`).

Gaps:
- **Our numbers:** +0.2 standing each; no source gives Tarkov's.
- **No rule against partners who shot each other**, and no co-op voice prompt or gesture.
- **Not seen with two clients** (a LogicTest stands a rig in as the partner).
- **The stairs door to the boiler cellar still takes the boiler house key** (ours).

### THE FORESTER: Customs' Partisan on Border Yard (2026-11-02)

Researched first: tarkovforge's Partisan page (live from tarkov.dev), timesaver.gg's guide (September 2026), the Japanese
wiki, Prima Games and GGRecon on karma, tarkovforge's Partisan's bag, Shacknews and GGRecon on tripwires
(`docs/design/BOSS_FORESTER.md`). Built in `Maps/Border/Play.luau`, `AI.luau`, `Tripwires.luau` (new), `Loot.luau`,
`Items.luau`, `Equipment.luau`, `Interact.luau` and `Effects.luau`. Checked in Studio with one player (TEST_RESULTS "THE
FORESTER and tripwires").

Matched:
- **A lone boss:** 950 health (Tarkov's part split is not applied), no armour, roaming Customs' tree lines, the
  construction site's edges and the dorms. 20 % a raid, more with low-karma raiders.
- **Who he hunts:** raiders with low karma; anyone else once they come close or shoot him.
- **Silent steps;** only the grass rustles.
- **Tripwires:**
  - grenades tied across doorways near his walk;
  - a step through, a shot that meets the wire or a blast nearby sets one off, and the grenade keeps its own fuse;
  - disarming takes 11 s, or 3 s with a multitool, and you keep the grenade;
  - his own wires never set him off.
- **His bag:** Tarkov's numbers (4x3, 20 slots, 0.7 kg, -5 % speed, -2 % turn, -8 ergonomics).

Gaps:
- **Karma is the Fence standing:** Tarkov's PMC karma is hidden and follows how you play.
- **Wires only in doorways** and all laid when he spawns; not on trails, fence gaps or log piles.
- **No tripwire kit for players** (Jaeger's), so no 10-minute timeout.
- **AI never set off a wire.**
- **His guns are ours:** no AVT-40, APS, VOG or RGO grenades, ice pick or GP-25.
- **His tactics are the shared boss AI:** no deliberate stuns at players holding still, no moving on after a fight.
- **Only on Border Yard;** no inventory picture for the pack.

### Tactical devices: lasers and modes (2026-11-02)

Researched first: Prima Games' Tarkov controls guide gives T for "Toggle Laser/Light" and Ctrl+T for "Toggle Tactical
Device Mode", and Left Alt + RMB (another of its tables: Ctrl + wheel) for the scope's magnification; the wiki's weapon
mods page lists lights, lasers and combo devices. Built in `Combat.luau`, `AI.luau`, `GunBuild.luau`, `Chars.luau`,
`Weapon.luau`, `LaserFx.luau` (new), `InputMap.luau`, `Touch.luau` and `NightVision.luau`. Checked in Studio with one player (TEST_RESULTS "Tactical lasers").

Matched:
- **Keys:** T turns the device on and off; Ctrl+T cycles a light/laser combo (the LC-4) between both, light and laser. A
  device with one function ignores the mode.
- **Visible laser:** every client draws a red beam from the device along the barrel and a dot where it lands, up to 250
  studs. It shows the barrel, not the crosshair, so in hip fire the dot is where the gun points. Others' lasers stop on
  whatever they meet, you included.
- **Others see it:** the server sets WeaponLight and WeaponLaser on the character from the device and its mode.

Ours (Roblox, cross-platform, or no source found):
- **AI:** bots with a light use it at night while hunting, and guards on patrol; a laser runs with the light and in
  any fight, day or night. No source gives Tarkov's rule for when bots switch devices on.
- **Gamepad:** hold D-right for the device (a tap is still the fire mode). Held while aiming, it switches the mode.
- **Touch:** LGT toggles; holding it switches the mode. The new NV button flips goggles; on a pad, hold D-left.

Gaps:
- **One colour.** Tarkov has red, green and infrared lasers (the last seen only through night vision); ours are red.
- **No laser hip-fire numbers from Tarkov.** A laser steadies hip fire by 20 %, our figure.
- **The beam's look is ours** (transparency 0.62 at night, 0.88 by day; the dot keeps a few pixels at range).
- **No second-client check** of another player's beam; the same code draws the AI's, which was seen.


### HUD and touch layout: the exits list, the menu row (2026-11-02)

Researched first: the Customs reference (section 9) and Interchange reference (section 6). They list which exits are
for PMCs, which for scavs and which for both. Gamepressure's extraction guide describes the list Tarkov shows on O: every
extraction point of the raid and the time left. A plain field means no condition; a question mark means the exit needs
something. Built in `Hud.luau`, `Lens.luau`, `Touch.luau`, `Extract.luau`, `Match.luau`, `Transit.luau` and both maps'
`Layout.luau` (and their generators). Checked in Studio with touch forced (TEST_RESULTS "HUD and touch layout").

Matched:
- **The whole list:** every exit and transit a raider has now shows on O. Before, the HUD showed at most 6 rows (8
  after the transits work), so a Border scav saw 8 of 26.
- **The scav's exits:** a scav no longer gets the exits the references give to PMCs only. On Border Yard that is BUNKER
  K-13 (ZB-013) and NORTH LINE (the flare passage). On Meridian Mall it is SHELTER EXIT (the saferoom), RIVER PATH (the
  flare path) and FENCE GAP (the hole in the fence). The cars were already left out. The rule is `who = "pmc"` on the
  exit, read by `Extract.scavMay`.

Ours (Roblox, cross-platform):
- **Touch menu row:** SET, EXIT and BAG stand at the top centre, in the band of the top bar that Roblox leaves free right
  of its own menu (`GuiService.TopbarInset`). They no longer cover the raid clock (KNOWN_ISSUES 75).
- **Touch exits list:** it drops down under that row, in two columns meeting at the centre when it is long. It shrinks
  to pass between the vitals and the recorder column, and the thumb buttons under a row fade while it shows.
- **A long list:** with keys, a long list shrinks to fit under the clock and splits in two columns past 62 % size.
- **Vitals:** on small screens they start below Roblox's own menu instead of under it.
- **Toasts:** on touch they start right of the RUN button when they would reach it (KNOWN_ISSUES 77).

Gaps:
- **Disputed scav exits kept:** ZB-1011 and Old Gas Station are PMC exits in SPT and scav exits too per TarkovForge; a
  scav keeps BUNKER K-11 and OLD PUMPS.
- **Our wording, not Tarkov's:** the list writes requirements out ("NEEDS POWER", "CO-OP EXTRACTION") where Tarkov
  marks a condition with a question mark.
- **Not checked on a phone** or in the device emulator; the narrow-screen fit was checked with the HUD scale at 1.4.

### Gamepad and touch for the weapon checks, zeroing, sight, inspect and free look (2026-11-02)

Researched first: Tarkov's own keys for these controls (section 4: Shift+T, Alt+B, Page Up/Down, Alt+RMB, L, Alt, Shift
while aiming; Prima Games' controls guide). Tarkov has no gamepad or touch controls, so these mappings are ours
(exception 4). Built in `InputMap.luau`, `Input.luau` (shared-button arbitration), `Touch.luau`, `Camera.luau`,
`Weapon.luau`, `NightVision.luau`, `Grenade.luau` and `Screens.luau`. Checked in Studio with the gamepad and touch paths
driven by the test bridge (TEST_RESULTS "Gamepad and touch controls"); no real controller or phone.

Ours (exception 4):
- **Gamepad, one rule for every shared button:** a short tap and a hold do different things, and with LT held (aiming)
  some taps do more (`padHow`, `padAim` in `InputMap`):
  - D-up: heal / free look (hold; the right stick turns the head) / zeroing up (aiming)
  - D-down: exits / grenade (hold) / zeroing down (aiming)
  - D-right: fire mode / tactical device (hold) / device mode (aiming, hold)
  - D-left: next weapon / goggles (hold) / sight mode (aiming)
  - R3: magazine check / chamber check (hold) / fire-mode check (aiming)
  - B: crouch / prone (hold); Y: inventory / inspect the weapon (hold)
  - Hold breath: L3 (sprint) while aiming, as Shift is on keys.
- **Touch** (replaced the same day by the v2 layout, next section):
  - CHK: hold to check the chamber. SWAP: hold to inspect the weapon.
  - New MODE button: a tap switches the fire mode; held, it opens a weapon tray under the menu row with CHECK, ZERO +,
    ZERO - and SIGHT.
  - New LOOK button: dragged, it turns the head (free look).
  - Hold breath: hold RUN while aiming.
- **Settings, CONTROLS:** with a gamepad or touch the list shows that device's buttons instead of the PC keys.

Gaps:
- **No slot keys on gamepad or touch:** 1, 2, 3 and V are reached by cycling (D-left, SWAP); quick slots 4 to 0 by MED
  and the inventory.
- **Not on hardware:** no controller, phone or tablet has run these.
- **A variable scope's power on the pad and the tray** was only checked with a sight that has none (the tap did nothing,
  as it should). The handler is the same as Alt+RMB's.

### Touch controls v2: icons, fewer buttons, a walk-and-run stick, FIRE that aims (2026-11-02)

Tarkov has no touch controls, so every choice here is ours (exception 4). The owner asked for:

- symbols instead of words;
- fewer buttons, with the rare ones behind a button that opens;
- a stick that walks and then runs;
- a layout that can be resized and moved;
- Call of Duty: Mobile's FIRE, which aims down sights and steers with the thumb;
- round buttons.

Researched first:

- Activision's guide to Call of Duty: Mobile's controls: per-weapon one-tap ADS, joystick sprint, custom layout with
  size and opacity, fixed stick and fixed fire options.
- PocketGamer on PUBG Mobile: the run lock ahead of the thumb, the eye button for free look, a left fire button.
- PocketGamer on Arena Breakout's best layouts: three and four fingers, auto ADS, fire for the left index finger.

The full design, with sources, is in `docs/design/TOUCH_CONTROLS.md`. Built in `TouchLayout.luau` (new), `Touch.luau`
(rewritten), `Movement.luau`, `Weapon.luau`, `Settings.luau`, `Screens.luau`, `Input.luau`, `Raid.luau` and
`Remotes.luau`. Checked in Studio with touch forced (TEST_RESULTS "Touch controls v2").

Ours (exception 4):
- **Icons, round buttons:** 32 icons of our own (`gen_touch_icons.py`). The menu row (settings, exits, bag) is rounded
  squares; everything else is round.
- **Fewer buttons on screen:** 14 round controls in a raid (HOLD BREATH appears only while aiming) where v1 had more,
  all with words. Ten actions moved into the MORE tray, and a hold gives five buttons a second job:
  - RELOAD: check the magazine
  - CROUCH: prone
  - SWAP: inspect
  - MODE: check the fire mode
  - MED: the best med now
- **MED wheel:** AUTO, then quick slots 4 to 0 with their items (Tarkov's quick slots).
- **Stick:**
  - It walks with analog speed. Pushed past its ring forward, it runs (Tarkov's sprint).
  - Let go on the lock above it and the run continues until the stick is touched again.
  - It floats to the thumb, or stays fixed (FLOATING STICK).
- **FIRE:** held, it aims down sights and the view follows the thumb (AIM WHEN FIRING, on by default). Off, it fires
  from the hip.
- **Editor** (Settings, CONTROLS, EDIT TOUCH LAYOUT): move, resize (60 to 160 %), fade (25 to 100 %), hide or show
  every control; reset; save to the profile.
  - The server keeps only known controls with numbers in range (`TouchLayout.sanitize`).
  - LEFT FIRE, the device and the goggles start hidden and can be shown.
- **Stationary guns:** their FIRE, ZOOM and LEAVE take the places of FIRE, AIM and RELOAD in the player's layout.
- **Roblox's own touch stick and jump** are turned off while ours show.

Gaps:
- **Not on hardware:** no phone or tablet has run v2. Two thumbs at once were not exercised (the bridge drives one
  finger at a time), and real notches and safe areas were not checked (KNOWN_ISSUES 79).
- **Saved layout across sessions:** the join load was replayed from a fresh server snapshot. A real second session needs
  the DataStore (KNOWN_ISSUES 1).
- **No gyro aiming:** Arena Breakout recommends it for two-finger players. Roblox exposes the gyro
  (`UserInputService.GyroscopeEnabled`), but it is not built yet.

### Release blockers, M1 (2026-11-07)

The audit (`docs/audit/2026-11-07/`) and the owner's picks (start-1a: release blockers first) put these first. Tarkov
was checked for each one that has a Tarkov side; the rest are Roblox's (exception 3).

Matches Tarkov:
- **No looting or opening doors through walls.** Tarkov's interactions need the object in front of you; the server now
  refuses a search, a loot move or a door when a solid wall stands between the head and the target (`Guard.canSee`, a
  1.2-stud margin for the container's own furniture, 1.5 for the door's frame). A probe of all 971 containers and 441
  doors found every container and every door usable from a spot within reach (MapTests M12 and M13).
- **Health between raids.** Tarkov keeps your wounds after a raid and heals you slowly out of raid, faster with the
  medstation. The bunker character's health is now saved before a PMC raid and when the player leaves, so recovery in
  the bunker is kept instead of the raid starting from the last raid's end.
- **The loading screen shows progress.** Tarkov 1.0.1.0 (December 2025) added a raid loading bar with the time left and
  the total wait. Our join card shows the server's boot stage, a progress bar, "ABOUT n S LEFT" and the wait.

Ours (exception 3, Roblox):
- **A server that closes mid-raid (an update, a crash) settles every raid in progress as SERVER_CLOSED:** the kit and
  everything carried are kept, nothing becomes found-in-raid and the raid does not count as survived, for a PMC or a
  player scav. The report says so, and the bunker messenger tells the player on their next visit. Tarkov has no
  Roblox-style shutdowns.
- **Saves:** a live server whose DataStore does not answer after six tries turns players away with a message instead of
  letting them play unsaved. In Studio it falls back to the in-memory store (SAVING OFF on the HUD).
- **Graphics level, FOV, sensitivity and grain are kept per kind of device** (phone, console, PC). Phones start at
  LOW, consoles at MEDIUM, PCs at HIGH (tech-3b).
- **Anti-cheat:** the movement guard (speed, falls, walls, hovering; kicks after ten pull-backs in a minute) and a
  fire-rate token bucket (the weapon's rate plus 10 %, a burst of two). Tarkov's own anti-cheat is not visible to players.
- **Faster server start:** the mesh library loads in parallel (models 13.4 s to 3.7 s; ready 26.5 s to 17.9 s in Studio).

Owner's choice (exception 2):
- **The block body stays (art-3a).** Tarkov's operators are realistic human models; ours keep the block body with
  Blender-made gear on it.

Gaps:
- **Reconnecting to a raid (tech-7d) and one server per raid (gameplay-7a)** need the published private test place:
  TeleportService does not work in an unpublished Studio place (KNOWN_ISSUES 1).
- **Two doors open into a wall on one side** (Border Yard: `LV_A127` in BLOCK A, `LV61_D1` at the SQUAT KIOSK;
  KNOWN_ISSUES 80). The art-1a map re-base rebuilds these buildings.

### Lean servers, M2 (tech-4b, 2026-11-07)

Tarkov loads one map per raid: the raid's server and every client in it hold that location only. A Zero Return server
now builds only the maps it plans (`World.planMaps`): every map by default, while one server runs the bunker and the
raids; one map once a server runs a single raid (gameplay-7a, after the place is published). The map vote offers only
the maps the server built, and a transit to a map that is not there is not offered.

Measured in Studio: Meridian alone builds 21,895 parts and is ready in 12.4 s, Border Yard alone 26,897 parts in 9.2 s,
against 49,988 parts and 17.7 s for every map.

Gaps:
- **Transits between maps** need both maps on one server today. With a server per raid they become Tarkov's transit:
  the raider is moved to the other map's raid server (gameplay-7a, needs the published place).
- **Merging plain wall and floor runs** was dropped after measuring: under 1 % of parts could merge (TEST_RESULTS, M2).
  The phone frame budget needs a phone measurement first (tech-2b).

### Phone menus, M2 (ui-3a, 2026-11-07)

Tarkov's inventory and trader screens are PC layouts: gear, containers and stash side by side; the trader's goods beside
the stash with the deal along the bottom. Below about 500 pt of height (phones, exception 4) Zero Return shows the same
panels one at a time:
- **Inventory:** a rail of EQUIPMENT, BAGS and STASH (LOOT in a raid, opened first when a container or body opens). An
  item picked up stays picked up while you switch panels, then a tap on a cell or slot places it.
- **Traders:** a rail of GOODS, STASH, DEAL, TASKS and SERVICES; picking an offer opens DEAL.
- **Sizes:** 36-pt cells (48 in the trader grids when there is room), 44-pt rail buttons, 13-pt text.
- **Every other window** takes the whole screen with a thin margin on a phone.

A PC (500 pt or taller) keeps Tarkov's layouts unchanged.

Gaps: no phone has run these (tech-2b); the Hideout, flea market, messenger and handbook use the full-screen window but
no layout of their own yet.

### Audit quick wins, batch 1: ballistics, health and AI (M3, 2026-11-07)

Brought to Tarkov's numbers (sources in `docs/audit/2026-11-07/gameplay.md` and `ai.md`):
- **Velocity factor (gameplay.2):** a bullet's damage and penetration scale with the share of its muzzle speed it still
  has (tarkov-ballistics.com), for players and AI. It replaced a straight fall-off by weapon range.
- **Fragmentation (gameplay.3):** rounds with 20 or more penetration roll their fragmentation chance for +50 % damage.
- **Spill (gameplay.4):** x0.49 arms, x0.7 legs, x1.05 stomach (EFT wiki, Health system).
- **Death screen (gameplay.6):** distances at 0.32 m a stud, as INSPECT.
- **Subsonic rounds (gameplay.7):** no crack as they pass.
- **Grenades (gameplay.14):** real gravity (30.7 studs/s2, as bullets), throw speeds lowered to keep the reach.
- **Factory time (gameplay.15):** Smelter raids last 20 minutes.
- **AI (ai.1, .2, .5, .6, .7, .12, .13, .15):** bosses and crews ignore the AI cap (EFT's IgnoreMaxBots); EFT health
  (cult warriors 850, THE CARETAKER 890, the Broker 752, his guards 630); the Caretaker carries Killa's five double
  pockets; guards spread round their leader; an orphaned follower keeps its own group's loop; doors a player works
  are heard by AI within about 19 m; a shot's origin is judged a few metres off, not exactly; Smelter rolls THE STOKER
  (Tagilla) at 30 % and THE CULT at 8 % in night raids, as Factory does.

Gaps: stationary guns still use the range fall-off; each round has no muzzle speed or ballistic coefficient of its own
yet (speed is per gun, drag per gun class).

### Audit quick wins, batch 2: HUD, inventory, loot and network (M3, 2026-11-07)

Matches Tarkov now:
- **Weapon corner (ui.3):** shown for 4 s after a weapon switch, a fire-mode change or a check; kept up while a
  malfunction flashes.
- **No vitals in the bunker, no HUD under a screen (ui.4):** health, stamina and needs show only in a raid (the HEALTH
  tab has them in the bunker); the HUD hides while the inventory, a trader, the hideout or a report is open.
- **DISCARD asks first (ui.2):** a second press within 3 s throws the item away.
- **ROTATE in the item bar (ui.1)** for touch, gamepad and the phone layout.
- **A scav's exits list (ui.15)** drops the SCAV ONLY tag, since every row is one.
- **Found in raid (economy.4):** hideout crafts are found in raid; an item taken into a raid loses the status.
- **Empty containers (economy.10):** each container rolls whether it holds anything (50 %; jackets and registers 60 %;
  safes and weapon boxes, which stand behind keys, always). SPT's mean is 0.28; ours stays higher while the item list
  is small.

Ours (performance and network, exception 3):
- **Bodies settle (tech.11):** ragdolls are anchored 5 s after death.
- **Reliable effects (tech.14):** airdrops, signal flares and the van leaving go on the reliable channel.
- **Inventory redraws (tech.7):** at most four a second for incoming snapshots.

Gaps: EFT 1.2.0 keeps every container in a locked room stocked; ours knows safes and weapon boxes, not rooms.

### Audit quick wins, batch 3: sound, sniper and AI cost (M3, 2026-11-07)

Matches Tarkov now:
- **Footsteps carry Tarkov's distances (gameplay.5):** about 134 studs (43 m) crouch-walking slowly to over 312 studs
  (100 m) sprinting.
- **No scripted distant gunfire (gameplay.13):** only real shots are heard; one too far for its own sound (560 to 2,400
  studs) plays the distant boom from its direction. (Silent until ZR_SFX_Amb is re-uploaded, KNOWN_ISSUES 73.)
- **The border sniper fires from outside the map (ai.14),** beyond whichever edge the strip is on.
- **Far AI keep moving in a scope (ai.9):** the animator measures distance as it looks through the current zoom.

Ours (performance, exception 3):
- **Effects by distance (tech.6):** shots go to players within 2,400 studs, small sounds and glass within 400; a muzzle
  light only within 150 studs of the camera. The bunker, 4,000 studs from every map, gets no raid effects.
- **AI cost (ai.10, ai.11):** AI stream in and out whole (Atomic) and skip the climbing, swimming, seated and flying
  states.

### Audit quick wins, batch 4: economy, skills and touch (M3, 2026-11-07)

Matches Tarkov now:
- **Flea market (economy.1, .2):** the simulated buyers stop at 1.25x the market price; epic and legendary items get
  fewer offers than rare ones.
- **Charisma (economy.6):** 0.1 % off insurance, repairs and paid exits a level; trader prices no longer drop with it.
- **The Sealed Drive (economy.8)** is wanted by a new task: Tilda's "Sealed Records" (two, found in raid).
- **VOLT (gameplay.8):** the drink speeds stamina recovery by half for a minute, as its description says.
- **Ergonomics (gameplay.10):** aiming tires the arms 1.3x as fast at 0 ergonomics, 0.7x at 100.
- **Bosses and player scavs (ai.4):** the Caretaker, the cultists, MORTAR and KESTREL shoot player scavs on sight; the
  other bosses leave a scav alone while its karma holds.

Ours (exception 4, touch and phones):
- **MORE tray captions (ui.10):** a word under each icon; MORE and LOOK moved off the centre of the screen.
- **Safe area (ui.11):** the HUD's side columns start inside a notch or rounded corner.

Also: the unused `Version.luau` was removed and the build label is `0.10.0-audit` (tech.15).

### Audit quick wins, batch 5: settings, messenger and shot visuals (M3, 2026-11-08)

Matches Tarkov now:
- **Settings (ui.7, ui.8):** the tabs in Tarkov's order (GAME, GRAPHICS, SOUND, POSTFX, CONTROLS); separate MOUSE,
  GAMEPAD and TOUCH sensitivity beside AIM SENSITIVITY; INVERT Y AXIS; MALFUNCTION NOTIFICATIONS (off: no flashing notice,
  inspect to find out); DOUBLE-CLICK QUICK USE (a med or food item); - and + repeat while held.
- **Messenger (ui.6):** the MESSENGER tab shows the unread count, and a new message pops a notice naming the sender.
- **Muzzle flash (art.3):** a hot core, a star of flame for two or three frames along the barrel and a wisp of smoke;
  a brake throws a bigger flash, a flash hider a smaller one, a suppressor only the smoke. First person shows it too.
- **Impacts by surface (art.4):** sparks off metal, splinters off wood, dirt off the ground, grit and dust off concrete
  and stone, a splash off water, a dark red puff off a body; bullet holes are a chipped ring in the surface's colour round
  a dark core (the wear set's hole decal is a strip of holes and read as a smear on one hit).
- **Ejected cases (art.5):** brass from your own gun and from shooters within 60 studs, red shells from the shotgun,
  at most 20 at a time; they settle and stay for 20 s.

All the particle images are Roblox's own (rbxasset textures); nothing new was uploaded.

### The Broker and scav groups (M3, 2026-11-08)

Matches Tarkov now:
- **The Broker (ai.3, our Reshala):** EFT's three Customs zones in our places: the dorms, the fuel stop (the new gas
  station) and the Bastion (the Stronghold). He spawns in 45 % of raids (EFT's 39-57 %) with 752 health and four guards
  of 630 (ai.2). He wears no armour or helmet and carries his own kit and his own look, not the Foreman's loot.
- **Scav groups (ai.8):** scavs spawn alone or in groups. A group's leader wanders and the others walk with him;
  if he dies, they wander on alone.

Still a gap:
- **Group sizes:** EFT's spawns can hold four or five scavs. Ours stop at three because a server holds ten scavs at most:
  45 % alone, 45 % in pairs, 10 % in threes. These are the Donuts mod's live-like weights (210/210/45), cut at three.
  BSG publishes no wave table, so this is the closest public source.
- **Dorm guards:** they start in the courtyard, 75 to 95 studs from the Broker's lobby, and walk in to him. In EFT his
  guards spawn beside him.


### Audit quick wins, batch 6: four helper threads merged (M3, 2026-11-08; none of it checked in Studio yet)

Built by the economy, ui, gameplay and docs threads and merged into main. The rows they changed are in sections 2, 3, 9
and 10; the gaps they found are in the same tables.
- **Economy:** flea level gates and EFT's ban list (economy.3); Fence's loyalty and prices from karma (economy.5); Pouch M
  and L with EFT's paths and a wider secure-container filter (economy.7); seven map tasks and boss targets (economy.9);
  flares in the handbook (economy.11); Tarkov's Perception and Covert Movement rates.
- **Interface:** gamepad focus and LB/RB tabs (ui.5, our own: exception 4); the green or red fit cue, Del and middle-click
  (ui.9); pinned tasks and a TASKS tab out of raid (ui.14).
- **Gameplay and tech:** what players hear follows Perception and Covert Movement (gameplay.9); Tarkov's heat, wear and
  malfunction rules (gameplay.11); cheaper lights and overlays (tech.12); the season tint as nature streams in (tech.9);
  AnalyticsService events (tech.16, recorded only once the game is published).
- **Docs:** sections 8 to 11 (AI, core gameplay, economy, art), the art bible (`docs/look/ART_BIBLE.md`).
- **Coordinator:** scav groups (ai.8), the Broker's zones fixed, the mesh library split (tech.13), the hazy sky textures
  (art.2, not yet switched on), mall kit B halved in triangles and dulled (art.6, art.8), AI sleep beyond 300 m (ai-2).
- **AI senses and aim (ai-3a, the ai thread):** EFT's numbers per role from SPT's copy of the game data (section 8); scavs
  now see about three times as far as before, so the AI's script time must be measured again on Border Yard.
- **Recoil (gameplay-1a, the recoil thread):** Tarkov's model with convergence (section 9); a phone at 30 FPS now keeps a
  gun's full rate of fire (it fired an 800 RPM gun at about 600).
- **EFT's roster (ai-1a, coordinator):** no Watch on Border Yard and Meridian Mall; scavs on their posts and the
  Bastion's guns; marksmen on Customs' perches (section 8).

### Map-first tasks (decision economy-6a, 2026-11-08)

Built by the tasks thread (0568127, TaskTests) and placed in the maps by the coordinator. Marking and finding were
checked in Studio on Border Yard (TEST_RESULTS); all 12 suites pass, 888 checks.

Matches Tarkov now:
- **122 tasks for the eight traders**, opening at loyalty levels in EFT 1.1.0's groups (two to four at once a level),
  on Border Yard, Meridian Mall, the Smelter and Quay 7, in the patterns of EFT's tasks on the matching maps.
- **Every objective type EFT's map tasks use:** conditional kills (map, place, weapon class, gun, distance, body part,
  raid time, as a scav, suppressed, no armour, no night vision, worn item, in one raid), found-in-raid hand-ins, plant
  and mark (a marker counts once you have stayed alive 30 s after setting it), quest items kept only by getting out,
  visits, extracts that a run-through does not count, and gunsmith builds with stated figures.
- **Standings:** every trader's tasks add up to at least EFT 1.1.0's LL4 standing, so the loyalty table is EFT's own.
- **Task-locked offers:** an offer opens when its task is done and shows a TASK overlay until then.
- **Operational tasks:** dailies, a weekly and Fence's scav task, each replaceable for money and standing.
- **Task places:** 31 of them, with prompts only the task's owner sees. Markers, cameras and beacons also turn up as
  loot in tech and toolbox containers.

Still a gap:
- 122 of EFT's 531 tasks: no Lightkeeper, Ref or BTR driver tasks, no story tasks.
- Two patterns are from memory, not fetched: V15's grenade kills (after Prapor's) and H16's close-range kills in a gas
  mask (after Decontamination Service). H8's household hand-in names no EFT task.
- Task money is ours. Task XP since economy-4b keeps each task's old share of a level on EFT's table: about EFT's own near
  level 12, 1.5 to 4 times EFT's from level 14 up (fewer tasks), less than EFT's at levels 1 to 5. Standing per task is
  about four times EFT's, because there are fewer tasks.
- EFT's operational counts, reward formulas, replace price and reset time were not found. Ours: three dailies, one
  weekly and one scav task; 6,000 MK plus 1,800 a level for a daily, four times that for a weekly; half the money and
  0.01 standing to replace one; resets at UTC midnight and on Monday.
- Fence's scav tasks open at level 5 (EFT: Intelligence Center level 1, which Relay 7 lacks).
- Pouch L still asks for the four old chain ends, not every trader's last task.
- A quest item lies as a plain box that other players can see; only its prompt is the owner's alone.
- Plant and mark hold times are ours (6 s, 4 s).
- No skill-level or loyalty objectives, no failure conditions, no start equipment, no progress shared in a squad (1.1.0).
- Markers, cameras and beacons are sold only while a task needs them (EFT sells markers outright).
- Gunsmith specs check kinds of parts, not named parts, and have no size or effective-distance condition.
- Pins work for tasks, not for operational tasks.
- A place on a floor is found by SpotFinder near a point we chose; EFT's places are set by hand.

### Sound through walls (decision gameplay-3a, 2026-11-08; piloted on Border Yard)

Built by the coordinator; measured in Studio (TEST_RESULTS). Tarkov's 0.16.7.0 notes say sound now passes walls by their
thickness, floors and stairways, doors and windows; EFT uses Steam Audio's geometry for occlusion and reverb.

Matches Tarkov now (on Border Yard, not on POTATO):
- **World one-shots go through Roblox's Acoustic Simulation:** other people's shots and steps, impacts, blasts, gulls and
  creaks. Walls, floors, doors and window panes muffle a sound between its source and you. Sound bends round corners and
  through doorways, and the reverb comes from the geometry.
- **Measured** with an AudioAnalyzer on the listener in the watchhouse's watch room, against the same sound with every map
  part made transparent to sound:
  - through the room's wall, 9.7 studs away: -17.6 dB;
  - through the floor, 8 studs below: -13.8 dB;
  - in the same room, 3 studs away: +0.7 dB (the room's reflections).
- **What blocks:** walls, floors, doors, kit colliders and unbroken window panes. Decor without collision, the detail layer,
  bodies, loot and effects do not.

Still a gap:
- **The acoustic density is ours.** At Roblox's own densities our thin plaster walls hardly muffle: -2.8 dB for the
  source above. On each client the anchored solid parts get x3 their density, at most 6. Anchored parts do not move, so
  physics is unchanged.
- **Only Border Yard, and not on POTATO.** Elsewhere a world sound counts the walls between it and the camera once as it
  starts. Each wall takes its volume x0.25 and cuts the highs (ours, option b as the fallback).
- **Still legacy `Sound`s:** your own sounds (rightly 2D) and the ambience loops (room tone, hum, generator, rain).
  Legacy sounds are not simulated (Roblox is working on it).
- **Not checked:** the cost on phones and the frame rate with many emitters (at most 24 at once), and the levels by ear.
  Roblox lowers the simulation's accuracy on weak devices.

### Stimulants, fractures and the stomach (decision gameplay-4b, 2026-11-08)

Built by the coordinator and checked in Studio (TEST_RESULTS). Figures from the EFT wiki (Health system; Medical, the
injector table with each effect's delay and duration) and TarkovForge's item pages.

Matches Tarkov now:
- **Four stims, 1x1, 0.05 kg, 2 s to inject, one use, with EFT's numbers:**
  - **RG-5**, after Propital: health +1 a second for 300 s, Metabolism, Health and Vitality +20 levels, a painkiller for
    245 s; hand tremor and tunnel vision from 270 s for 30 s.
  - **SV-3**, after SJ6: maximum stamina +30 and stamina recovery +2 a second for 240 s; hand tremor and tunnel vision
    from 200 s for 40 s. No trader sells it.
  - **HM-2**, after Zagustin: stops every bleed, and no new bleed takes for 180 s; Vitality +20, Metabolism -5; hand
    tremor and hydration -1.4 a second from 170 s for 40 s.
  - **Adrenaline**, after EFT's Adrenaline injector: a painkiller for 65 s; Endurance, Strength and Recoil Control +10
    and Stress Resistance -10 for 60 s; health +4 a second for 15 s; energy -0.8 and hydration -1 a second from 50 s
    for 30 s.
- **Where they come from:** HALE (our Therapist) sells RG-5 and HM-2 at LL4, as EFT's Therapist sells Propital and
  Zagustin. All four turn up in medical bags, pharmacies and medical airdrops.
- **Fractures:** each broken leg slows you by 45 %, and you cannot sprint unless on painkillers. A broken right arm
  makes using items and searching 50 % slower, and reloading, drawing and aiming 67 % slower. A broken left arm makes
  using and searching 67 % slower, and reloading and drawing 50 % slower. A destroyed limb counts as broken.
- **Destroyed stomach:** energy and water drain five times as fast.
- **On screen:** each buff shows as a green icon and each side effect as an orange one beside the health figure. The
  INSPECT window lists every buff and side effect with its timing.

Still a gap:
- 4 of EFT's 38 or so stims. The rest (eTG-change, SJ1, SJ12, Meldonin, L1, M.U.L.E., Obdolbos, Perfotoran, PNB,
  Trimadol, AHF1-M and the others) can follow with the art pipeline (option a).
- EFT does not publish how health regeneration splits over the parts. Ours is one pool a second, spread evenly over the
  damaged living parts.
- Injecting the same stim again starts its course again (EFT's stacking rule was not found).
- A skill buff adds skill levels (our reading of EFT's "+20").
- The +2 stamina recovery is added to our base recovery of 6 a second (EFT's base figure was not found).
- RG-5 and adrenaline do not cure the blast concussion, which Propital and Adrenaline cure in EFT.
- Two broken legs multiply (x0.55 x0.55). The wiki only says 45 % a leg.
- Sprinting on a broken leg under painkillers does not hurt it (EFT: it does; no figure found), and jump height is not
  lowered.
- A stim's painkiller lasts longer with Stress Resistance, as our pills do (ours).
- Tunnel vision is our dark vignette closing in.
- Ours: HALE sells the adrenaline at LL2, and the prices are near EFT's trader prices. The AI do not use stims.

### Recovery and insurance (decision gameplay-6b, 2026-11-08: Tarkov's rules, scaled times)

Built by a helper thread and checked in Studio by the coordinator (TEST_RESULTS; RecoveryTests 72 checks). Figures from
the EFT wiki (Insurance; Health system; Therapist).

Matches Tarkov now:
- **Three insurers, each with EFT's choice and price:** VOS (Prapor's role) returns in 2-3 h and holds for 24 h at 7 %
  of the value; HALE (the Therapist's) 1-2 h, held 36 h, at 1.33 times VOS's price; BRAM (Jaeger's, 1.1.0) 10-20 min,
  held 24 h, at 2.5 times. The times are EFT's divided by 12 and the storage by 4 (our scaling). The deploy screen and
  the item menu offer all three with their prices.
- **Returns:** each insurer's items come back at a random time inside its window, wait in the messenger for RECEIVE ALL
  and are lost after the storage time, with a notice. Magazines come back empty. Insuring a pack insures what can be
  insured inside it; food, medicine, ammunition, keys and melee weapons (but the cult's knife) cannot be insured. The
  kit worn when you go missing in action does not come back; after a death, insured gear nobody took does.
- **Health after a raid:** every part at 30 % after a death or MIA. Out of raid the body regains health at four times
  EFT's rate (1,826 an hour over the damaged parts), more with the medstation, and energy and water 4 a minute; the
  recovery carries on while the player is offline.
- **HALE's TREATMENT:** 30, 33, 36 or 40.5 MK a point of health by loyalty level, 750 or 1,400 a bleed, 1,350 a
  fracture; free while you are level 5 or below.
- **Scav cooldown:** 15 minutes, with the karma curve kept.

Still a gap:
- EFT says nothing until the insurer's message at the return time, and also writes when nothing was found. We list a
  return in the messenger as soon as the raid ends ("the insurer is bringing them back") and write nothing when
  everything was looted.
- EFT 1.1.0's faster returns and higher prices for Prapor and the Therapist were not published (the older hours are
  used). BRAM's figures are ours, and HALE's price ratio is a flat 1.33 times (EFT's varies by loyalty level).
- EFT may keep insurance on items you extract with (not confirmed); ours ends after a survived raid.
- Not built: the Intelligence Center's shorter returns, the editions' storage times, a chat per insurer (returns share
  one INSURANCE dialog), the 1 % health after a suicide, a team kill or a disconnect, energy and hydration treatment,
  picking treatment lines (HEAL ALL only).
- Ours: a destroyed part stays destroyed out of raid until HALE treats it (our reading; no source we could open says
  so), and restoring one costs its health plus 2,500 MK (EFT's price is not published).
- EFT's scav cooldown is about 25 minutes (unofficial); ours is 15.

### Accessibility and the recorder overlay (decisions ui-8a and ui-2b, 2026-11-08)

Checked in Studio (TEST_RESULTS). EFT has a COLORBLIND MODE on its POSTFX tab (protanopia, deuteranopia, tritanopia,
with an intensity) and no menu text size or hints setting.

Matches Tarkov now:
- **COLORBLIND MODE and its intensity** on the POSTFX tab, with EFT's three types.

Ours:
- **The colour-blind mode recolours the HUD and the menus only.** Roblox cannot remap the colour channels of the 3D
  image, so the colours are daltonized instead: what that type of colour blindness loses is moved into the channels it
  still sees. Words and shapes stay beside every colour.
- **MENU TEXT SIZE** (100 to 150 %, kept per device): each menu screen (inventory, inspect, modding, the modal screens,
  the menu bar) sits in a root frame laid out for the screen divided by the size and drawn that much larger, so text,
  buttons and gaps grow together; a phone at 150 % gets the compact layouts sooner. The HUD keeps HUD SCALE.
- **HINTS:** on by default; off, a prompt shows no key, the menu bar no keys and the HUD no "how to" words, as Tarkov
  shows them.
- **RECORDER OVERLAY** (decision ui-2b) is FULL, CLEAN (the default) or OFF. CLEAN keeps the REC dot and tag, the time
  stamp, the raid clock and the corner brackets; it drops the device line and keeps the colour split on the REC tag only,
  so the numbers are crisp. OFF drops the bodycam frame and keeps the clock. SAVING OFF shows in every mode.
- **Fixed on the way:** the inventory read the pointer from the top of the screen and the frames from under Roblox's top
  bar, so its context menu and drag picture sat 58 px under the cursor; the menu bar's six buttons now share the width
  left of DEPLOY (they ran into it on a narrow screen); a locked task's reason now puts what is missing first and
  the tasks to finish after ("Requires level 3. Opens after Signal Check."; not looked at on screen yet) instead of
  "Requires after Signal Check.".

Still a gap:
- The colour-blind filter on the 3D image itself.
- Not checked: dragging an item with the mouse at a larger MENU TEXT SIZE (the test tool's drags did not move items at
  100 % either), a phone, the palettes by a colour-blind player.

### M4 batch 4, coordinator's part (2026-11-08)

Checked in Studio (TEST_RESULTS, 11:00 to 11:40 SGT; all 11 suites pass, 850 checks):
- **Relay 7 counters for all eight traders.** DEKKER across the hall from VOS, HALE and TILDA; KOVAC in the gunsmith's
  room; ROOK and BRAM either side of the motor pool's vehicle opening; each with an NPC in his own clothes and a name
  board. Our design choice (the walk-around bunker); every trader screen still opens from its key.
- **Plates in the drag cue.** A plate dropped on a vest's tile lights green when a slot takes it, red onto a worn vest
  (Tarkov 0.14: take it off first). A part or plate a drop replaces goes to the stash out of a raid.
- **Pictures for every carried item.** The 16 plates, the antidote, both flares, the ritual amulet and knife, the
  Forester's pack and the welding mask.
- **AI looting (ai-8a).** The row in section 8 above says what matches EFT and what is ours.
- **Tarkov's health and stamina indicators (ui-1a).** The rows in section 5 above.

### M4 batch 1-3 checked in Studio (2026-11-08)

All of batch 6 and M4 batches 1-3 ran in Studio on 2026-11-08 (TEST_RESULTS): every suite passes, 830 checks. The eight
traders (economy-2a) and the plates (gameplay-2a) are merged into main; their rows above say what matches Tarkov and what
does not.

