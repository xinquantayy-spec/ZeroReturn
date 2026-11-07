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
   the block body (art-3a, 2026-11-07). **Not yet true of the keys:** only the inventory (Tab), settings (P) and, in a raid,
   the time and exits (O) have one (`InputMap.luau`). Traders, flea market, messenger and handbook open at a station as one
   relay radio window whose tabs reach the others; the hideout, deploy and insurance, and the gunsmith bench open only at
   their own stations (`Interact.luau`). Tarkov opens all of them from its main menu; Tarkov's menu bar (ui-6a, approved
   2026-11-07) is not built yet.
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
| Ammo | Damage and penetration (in the inspector since 0.14.5; hovering shows the effect against armor classes), armor damage, speed, bleeding chance, accuracy and recoil modifiers, tracer, subsonic | Damage, penetration, armor damage as text | Rows plus the per-class effectiveness on hover |
| Body armor, armored rigs, plates | Armor class, durability (now/max), material, armored areas (thorax, stomach, sides, back, throat, groin), plates with their class and areas, movement speed %, turn speed %, ergonomics % | Class and durability | Material, areas, penalties, plates |
| Helmets | Class, durability, material, areas (top, nape, ears, eyes, jaws), ricochet chance, sound reduction, what it blocks (earpiece, eyewear, face cover), penalties | Class and durability | The rest |
| Glasses, ballistic glasses, gas masks | Blindness protection (the share of a flash charge it stops), weight, grid size; ballistic glasses also armor class, durability, material and the eyes area; what the item blocks | Missing (no eyewear slot) | Built 2026-11-01: BLINDNESS PROTECTION, LENS TINT, class, durability, material (GLASS), the EYES area and BLOCKS rows. Plain glasses show no durability, as in Tarkov. Not run in Studio yet |
| Rigs, backpacks, cases | Grid layout, weight, penalties, what a case accepts | Capacity | Penalties, filters |
| Meds | HP resource, max per use, use time, what it cures (light and heavy bleeding, fractures) and its cost, painkiller duration, side effects | Description only (the data exists in `Items.luau`) | All rows |
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
| Drag and drop with the mouse (Tarkov is PC only) | Mouse drag; on touch and gamepad, pick up then tap to place, kept across the phone panels (M2) | Touch drag and drop (ui-4c, approved) |

## 3. Out-of-raid screens

| Tarkov | Zero Return | To do |
|---|---|---|
| Character: gear, health, skills, mastering, overall statistics, achievements, prestige, dog tag style | Tabs in the inventory: GEAR, HEALTH, SKILLS, MASTERING, OVERALL; TASKS in and out of raid, active tasks pinnable to the top (ui.14, 2026-11-08, Studio check pending) | Achievements, prestige, dog tag style, a MAP tab |
| Traders: TRADE (assortment grid with prices; sell from stash), TASKS (pinnable since 0.16.7), SERVICES (insurance, repair, healing) | Done 2026-10-31: TRADE, TASKS and SERVICES (repairs: weapons at VOS, armour at TILDA); insurance at the insurance window and from the context menu; one panel at a time on phones (M2) | Healing at HALE (gameplay-6b). Task pinning built (ui.14, 2026-11-08, Studio check pending) |
| Flea market from level 15: offers, filters, filter by item, linked and required search, wish list | Done 2026-10-31: level 15, categories, search, WISH LIST, MY OFFERS, ADD OFFER with Tarkov's fee; simulated sellers and buyers (section 10) | Price, currency and condition filters; filter by item, linked and required search; the level gates by category are built (economy.3, 2026-11-08, Studio check pending) |
| Messenger: one chat per trader, insurance returns, task rewards, receive all | Done 2026-10-31: trader dialogs, insurance returns with RECEIVE ALL, task, loyalty and flea messages; an unread count and a notice when mail comes (ui.6) | |
| Handbook: every item by category with its description | Done 2026-10-31 (relay radio, HANDBOOK); flares under SPECIAL EQUIPMENT (economy.11, 2026-11-08) | |
| Wish list: items flagged for tasks, hideout or trading | Done 2026-10-31: + WISH in INSPECT, a W on the tile, the flea market's WISH LIST | |
| Hideout: modules, crafts, shooting range, customisation (0.16: wall finishes "Blue paint", "Factory walls", "Modest wallpaper"; floors "Small tiles", "Factory floor"; a "Factory ceiling"; unlocked by level, tasks, achievements and prestige; posters as hideout upgrades and loot; range targets by leveling the range) | Five modules in the shared, kept bunker (section 10); STYLE since 2026-11-02: walls (7), floor (5) and ceiling (4), drawn per player on each client, unlocked by level (`docs/design/HIDEOUT_STYLE.md`); a free practice range in the lobby | Unlocks by tasks, achievements and prestige; posters; range targets; the range as a module |

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
| Health and stamina on screen | Health condition and stamina-and-stance indicators, each always shown or auto-hidden; health in Polychrome or Monochrome (GGRecon) | Total health, stamina, energy and water as numbers, in a raid only, hidden under any screen (ui.4) | Tarkov's indicators and their settings (ui-1a, approved) |
| Weapon and fire mode on screen | No ammo counter; the fire mode shows only when it changes | Done (ui.3): the weapon corner shows for 4 s after a switch, a fire-mode change or a check, and stays while a malfunction flashes; no ammo counter | - |
| Interacting | A list of actions picked with the mouse wheel (unverified: ui audit) | One action per prompt | The action list |
| Gamepad and touch (exception 4: Tarkov is keys and mouse only) | none | Done 2026-11-02: every control above but the slot keys and quick slots has a gamepad and a touch way (the next weapon and MED stand in for those). Settings, CONTROLS lists them on that device. Touch layout v2: icon buttons, tap and hold pairs, a MORE tray with captions (ui.10), a med wheel, a walk-and-run stick, FIRE that aims and steers, and an editor for every control (`docs/design/TOUCH_CONTROLS.md`, sections below). Phone menus show one panel at a time below 500 pt of height (M2); the HUD keeps inside the safe area (ui.11) | A real controller and phone |

## 5. Settings

Updated 2026-11-08 from `Screens.luau` (`SETTING_TABS`). The tabs are in Tarkov's order: GAME, GRAPHICS, SOUND, POSTFX,
CONTROLS (ui.8). Graphics level, FOV, sensitivity and grain are kept per kind of device; phones start at LOW, consoles at
MEDIUM and PCs at HIGH (tech-3b, M1). Numbers move with - and +, which repeat while held (ui.7); there is no slider.

| Tab | Tarkov | Zero Return | Plan |
|---|---|---|---|
| Game | FOV 50 to 75, head bobbing, show quick slots, stamina and health (always, auto-hide, never), health colour scheme, highlight available operations, double-click quick use, vaulting mode, malfunction notifications, priority window, continuous healing | FIELD OF VIEW (50 to 100, bodycam 85), HEAD BOBBING, SCREEN SHAKE, REDUCE MOTION, AIM MODE, QUICK SLOTS (AUTO-HIDE, ALWAYS, NEVER), CENTER DOT, HIT FEEDBACK, HUD SCALE, CURVED HUD, MALFUNCTION NOTIFICATIONS, DOUBLE-CLICK QUICK USE | Stamina and health display with the colour scheme (ui-1a); highlight available operations; vaulting mode; priority window; continuous healing |
| Graphics | Texture and shadow quality, object LOD, overall visibility, AA, resampling, DLSS/FSR, HBAO, SSR, anisotropic, sharpness, Reflex, HQ colour, Z-blur, chromatic aberrations, noise, grass shadows, mip streaming, FPS limits | GRAPHICS (POTATO to HIGH), HOLD 30 FPS, FILM GRAIN, LENS EFFECTS, MOTION BLUR, RECORDER OVERLAY | Our own rows for what we control (shadow lights, detail density, draw distance of props, grass, chromatic aberration); the rest is Roblox's slider (exception 3) |
| PostFX | Brightness, saturation, clarity, colourfulness, luma and adaptive sharpen, colour grading with intensity, colour-blind mode with intensity | BRIGHTNESS, SATURATION, CLARITY, COLOR GRADING (NONE, STEEL, EMBER, MOSS, DUSK) and GRADING INTENSITY | Colourfulness and the two sharpen sliders; colour-blind palettes for the HUD and menus (ui-8a: Roblox cannot filter each colour channel of the 3D image) |
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
| Audio: Steam Audio reverb and occlusion from the geometry (0.12.6 on, occlusion reworked in 0.16.7.0); indoor and outdoor sound; Interchange's mall soundscape | Written 2026-11-01: one reverb for the listener's space (7 classes plus marked floors), room tone, mains hum with the power, car park tone, drips, the IRONSIGHT siren, the substation generator, dust in the skylights (MEDIUM and up); far shots only from real shots since 2026-11-07 (gameplay.13). Everything from the ambience atlas is silent: the asset in `Sounds.AMB_ATLAS` loads as 0.0 s long (KNOWN_ISSUES 73) | The owner re-uploads `ZR_SFX_Amb` (gameplay.17), then levels are set by ear. Occlusion through walls, floors and doors is now possible: Roblox's Acoustic Simulation left beta on 22 September 2026, for the Audio API only (gameplay-3a, approved; section 9) |

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
- **No per-source reverb or occlusion** (Steam Audio's geometry raycasts per sound, the 0.16.7.0 floor and stairway transmission).
  The legacy `Sound` objects this game uses get one reverb for the listener and no occlusion: a shot in a hall heard from a
  washroom gets the washroom's reverb, and sounds carry through walls within their radius. Since 22 September 2026 Roblox's
  Acoustic Simulation gives occlusion, bending round corners and reverb from the geometry, but only to the Audio API
  (`AudioPlayer`, `AudioEmitter`); moving the sounds to it is the owner's pick gameplay-3a (audit gameplay finding 3).
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
| Raiders only on Reserve and Labs; sniper scavs on Customs | The Watch: 8 guards on Border Yard (2 on the Bastion's guns) and 6 on Meridian, hostile to player scavs; no sniper scavs (the border sniper is a hazard beyond the map edge) | ai-1a: EFT's roster on both maps |
| Voice lines, call-outs, boss voices, a warning to player scavs | Silent; call-outs share positions without a sound | ai-4a: recorded voice packs (the audio quota, KNOWN_ISSUES 6) |
| Bots loot bodies and loose loot; what they take is lost to insurance | AI never loot | ai-8a |
| Killa's LMG, Big Pipe's grenade launcher, Birdeye's marksman rifle, Tagilla's semi-auto 12 gauge, Reshala's golden pistol | Stand-ins: the Caretaker's shotgun, MORTAR throws grenades, the Stoker's pump gun, the Broker's plain pistol | ai-5b: the LMG and the launcher; stand-ins for the rest |
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
| Recoil with a climb angle, dispersion and convergence; full auto levels off | Built 2026-11-08 (gameplay-1a, Studio check pending; `src/shared/Recoil.luau`): an angle and dispersion each shot, convergence back to the aim point, full auto settles after the first shots (an R-17 peaks near 2.9° and settles near 1.3°, was 13.6° over 30 rounds), camera recoil apart from the gun's, shots and iron sights follow the gun; each gun's figures from its Tarkov 1.0 default build (R-17 79/228 as the M4A1, KS-7 90/221 as the AKM), pose and skill factors from Tarkov's globals, 1.0.4.5's part rules; RECOIL CONTROL trains on every shot | Per-gun angle, dispersion, convergence, camera share and stable shot are ours by class (Tarkov's per-gun figures were out of reach; every angle 90); the conversion to degrees, spring rates and the ergonomics term are ours; ammo recoil modifiers; mounting and bipods (gameplay-5b); camera recoil growing with FOV |
| Soft armour plus plates in front, back and side slots, protection by zone; helmet zones (top, nape, ears, eyes, jaws); ricochet by angle | One class per vest; helmets roll dice, with face and eye bands | gameplay-2a: the full plate system |
| Each round has its own muzzle speed and ballistic coefficient | Speed per gun, drag per gun class; mounted guns still use a range fall-off | Per-round speed and drag |
| Overheating in four stages with cook-offs, a fire-rate change and maximum durability loss; a flash on a malfunction; a chance per round; a 5 s quick draw of the sidearm after a jam | Built 2026-11-08 (gameplay.11, Studio check pending): heat on Tarkov's 0-200 scale with its cooling; from 100 wear rises up to x3 and spread up to x1.5; fire rate moves 0.85-1.15 above 140; cook-offs from 170; the bolt held at 200; hot shots cut the maximum durability (never below 55); a red, yellow or green glow on a malfunction, its check and its fix; a 5 s quick draw of the sidearm after a jam | Only the AKM's numbers are verified (every gun uses its base chance and cooling); every round uses the 7.62x39 chance; 40- and 50-round magazines keep our wear; base wear about twice the AKM's; no Troubleshooting elite or Weapon Maintenance; clearing by chamber check or reload; per-weapon malfunction kinds; barrel glow and heat haze |
| A round in the chamber (30 + 1) | No chamber round | The chamber round |
| Mounting on cover and bipods; quick reload (double R drops the magazine); slow lean; stance changes cost leg stamina; overweight is louder | None of these; a magazine drops only when there is no room for it | gameplay-5b (blind fire and side step are left out) |
| Fractures (a leg -45 %; arms slow aiming, drawing and searching); stims with buffs and side effects; a destroyed stomach drains energy and water x5 | A leg -14 %, arms slow reloads; no stims; no stomach rule | gameplay-4b: the core set |
| After death or MIA: 30 % health regaining 7.61 HP a minute, paid healing at the Therapist; insurance 12 to 36 h, held 4 to 6 days; scav cooldown about 25 min | Full health after death, no paid healing; one insurer, 15 min, kept until collected; 10 min | gameplay-6b: Tarkov's rules, scaled times |
| PMCs only enter at the start of a raid | PMCs may join for 5 min (`Config.LATE_JOIN`) | gameplay-7a: a server per raid (needs the published place) |
| Occlusion through walls, floors and stairways | Legacy sounds with one reverb for the listener | gameplay-3a: Acoustic Simulation (section 6) |
| Each gun its own sound; footsteps on snow, water, tile and metal stairs; headsets with their own compression | One recording pitched for every gun; five surface families; one headset rule | Recorded or licensed sounds; gameplay.16 |
| Perception lengthens how far you hear steps; Covert Movement quietens yours | Built 2026-11-08 (gameplay.9, Studio check pending): Perception +0.3 % hearing a level (+15 % elite), Covert Movement -1.2 % a level on common surfaces (-60 % elite), for players and the AI | Perception's loot radius and elite loot notice; Covert Movement's sneak speed; metal and gravel as Tarkov's uncommon surfaces is our reading |
| A tutorial raid (1.0) | A welcome message | ui-5a |
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
| 2,169 items in 2021 (102 weapons, 1,421 parts); 184 rounds in 27 calibres in 2026 | 279 items: 6 guns, 96 parts, 13 rounds in 5 calibres, 58 keys | economy-1a: a core set of about 600 |
| Eight traders (Prapor, Therapist, Skier, Peacekeeper, Mechanic, Ragman, Jaeger, Fence), plus Ref, Lightkeeper and the BTR driver; money as items in three currencies | VOS, HALE, TILDA and the FENCE; one balance in MK | economy-2a: EFT's eight, one currency |
| LL2 to LL4 at levels about 13 to 42 (1.1.0 dropped the sales requirement); 892 barters | LL2 to LL4 at levels 3, 7 and 12 with 150k to 1.2M MK traded; 12 barters | economy-2a, economy-4b |
| Fence sells what players sold him; his LL2 at reputation 6.0 | 11 fixed offers; LL2 at karma 6.0 (his dorm key), prices x1.2 at -7 to x0.8 at +6, karma -7 to 6 (economy.5, 2026-11-08, Studio check pending) | Player-sold stock; his LL2 tab of better goods; what he pays still moves 4 % a karma point; scav cooldown and hostility keep our curve; our karma gains are 3-8 times EFT's |
| Flea level gates by category up to 40 (1.0); bans on secure containers, currency, some weapons, ammo, armour, packs, helmets; fee 5 % since 1.1.0 | Built 2026-11-08 (economy.3, Studio check pending): EFT 1.0's gates (20: bolt-actions, foregrips, muzzle devices; 25: assault rifles, packs, lights and lasers; 30: barter goods, goggles, injectors, keycards; 35: the LPS-class round), greyed offers, and EFT's ban list; fee 3 % | The 5 % fee; BSG publishes no full gate table, and 1.0 may have turned some bans into gates |
| A market of real players, with barter offers | Simulated sellers and buyers, cash only | economy-3a: a real market with an AI floor |
| Loot tables per map; 21 container templates (SPT, Interchange) | One pool per container kind for every map; 13 kinds | Tables per map |
| Secure containers Alpha to Kappa with trader and task paths; item cases (documents, keytool, SICC, junk box, medicine, magazine, keycard holder) | Pouch S, M and L: M is TILDA's LL2 barter (EFT's Beta), L the reward of FENCE's task Keepsakes (EFT 1.1's Kappa); weapon parts, grenades, goggles, glasses and headsets go in (economy.7, 2026-11-08, Studio check pending) | The cases; full containers cannot nest; Pouch L asks 10 of our valuables, Kappa 44 collectibles |
| Stash 10x30, up to 10x68 or 10x72 | 10x20, up to 10x30 | Stash levels (economy-7b) |
| 531 tasks for 11 traders: conditional kills, found-in-raid hand-ins, plant and mark, visit, extract, skill and LL, gunsmith builds; side tasks per LL, dailies and weeklies, task-locked offers | 23 tasks for 4 traders: kill (a named boss too), hand in, extract and visit on a named map, tasks that need other tasks, karma or loyalty (economy.7, economy.9, 2026-11-08, Studio check pending) | economy-6a: a map-first core of about 120 |
| Hideout: 26 modules, 67 levels, 214 crafts; generator fuel; scav case; bitcoin farm; the shooting range as a module | 5 modules, 8 levels, 10 crafts; no fuel; one build at a time; a free range in the lobby | economy-7b: an economy core of about 14 |
| Builds and crafts take hours to days; level 15 at 161,139 XP (the top level about 82.6 million, unverified) | 5 to 45 minutes; level 15 at 52,383 XP, cap 40 | economy-4b: EFT's curves, faster clocks |
| Skills such as Hideout Management, Mag Drills, Weapon Maintenance, Aim Drills, DMR, LMG, HMG, revolvers, launchers | 24 skills | With the content they need |
| Insurance: Prapor 24 to 36 h, Therapist 12 to 24 h, Jaeger quick (1.1.0) | One insurer at 7 %, 15 min | economy-2a, gameplay-6b |
| No forced wipes since 1.0; seasonal characters every 4 to 6 months (1.1.0); prestige (0.16); the PvE Zone | A wipe when the save format changes; no prestige or PvE | economy-5b: permanent plus an opt-in season |
| Weapon builds that buy the missing parts | None (KNOWN_ISSUES 54) | - |
| Money sinks: fuel, filters, the scav case, costly builds, flea fees, insurance, repairs | Flea fees, insurance, repairs, a one-time 785k hideout | Come with economy-7b and economy-4b |
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
| 13 locations; End of the Line due in December 2026 | 2 Tarkov layouts; Quay 7 and Smelter, our own layouts, in the vote; Pinewatch parked | art-2d: no new map until Border Yard and Meridian Mall hold 30 fps on a measured low-end phone; then Factory, Woods, Reserve, Shoreline, Streets, Lighthouse, The Lab, Ground Zero, and the small-group maps last |
| Factory (142 x 132 m) and Woods (1.4 x 1.36 km) | Smelter, an original 82 x 63 m compound; Pinewatch, an original 164 m forest | art-1a: rebuild both on Tarkov's layouts at real scale; Quay 7 leaves the vote and stays the test map |
| Customs after 0.16; Interchange's ponds and outbuildings | Pre-0.16 outlines, no 0.16 interiors; dry ponds, one-room outbuildings | Section 7's lists |
| Fully modelled buildings: frames, sills, cornices, gutters, balconies | Part walls with cut holes, flat slabs | art-5b: a modular Blender kit of merged meshes, which also cuts the part count |
| Dense, lived-in interiors; map edges of fences, forest and terrain | About 10 props a shop, stretched furniture, plain box containers; tall terraced rock walls | art-5b; fenced and wooded edges |
| Trees and grass that move in the wind | See-through cards, no sway | Sway |
| Players choose the raid time; nights so dark that goggles and lights matter | One of 8 start times; the bodycam adds about 0.6 exposure at full dark | Choose the time; art-8b |
| No exit markers in the world | A glowing lamp, a sign and a painted zone at every exit | art-8b: remove them; the landmarks stay |
| Hazy skies | Roblox's default sky with a cloud layer; the lighting model is not set in code | art.2: an original sky set (clear, overcast, night); art.1: set LightingStyle and PrioritizeLightingQuality and record them |
| Post effects: ambient occlusion, reflections, chromatic aberration, noise, grading | Grade, bloom, sun rays, depth of field, grain, vignette, edge haze; grading presets | Partial; part of it is a Roblox limit |
| Detailed, textured guns, gear and items | Vertex colour, no UVs: gun parts 128 to 1,544 triangles, gear about 400, 95 item models | art-4b: PBR sets (512 to 1024) for first-person guns, attachments, worn gear and items seen up close |
| Hand-made reloads, checks and inspects with the bolt and charging handle moving | Code-made poses | art-6a: the bolt release or charging handle, a quick reload, a magazine check that shows the magazine, a chamber pull |
| Blood on hits | A dark red puff | art-7a: light blood marks (the Moderate label at publishing is the owner's call) |
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
- Atmosphere and ambience (2026-11-01): [Gfinity: 0.12.6 notes](https://www.gfinityesports.com/article/escape-from-tarkov-12-6-patch-notes-update-full-list-changes-wipe-pc) (first Steam Audio, indoor sound fix), [Steamworks: Steam Audio](https://partner.steamgames.com/doc/features/steam_audio), [PCGamesN](https://www.pcgamesn.com/escape-from-tarkov/update-audio-overhaul) and [Insider Gaming](https://insider-gaming.com/tarkov-patch-overhauls-immersive-audio/) (0.16.7.0 occlusion), [Wiki: Interchange](https://escapefromtarkov.fandom.com/wiki/Interchange) (illumination grid, alarm), [TarkovForge: Kiba Arms outer door key](https://tarkovforge.com/keys/kiba-arms-outer-door-key) (alarm 3 s after the door), [Guild Order: audio guide](https://guildorder.com/hi/games/tarkov/guides/audio-fluency-and-sound-triangulation) (distant shots); the rest is in `docs/look/ATMOSPHERE.md`
- Patch notes: [0.16.0.0 (Sportskeeda)](https://sportskeeda.com/esports/escape-tarkov-patch-notes-update-0-16-0-0-new-event-customs-rework-prestige-system), [0.16.7.0 (AltChar)](https://www.altchar.com/game-news/escape-from-tarkov-patch-0.16.7.0-full-patch-notes-aP2RA1G8vdlq), [1.0.4.5 (AltChar)](https://www.altchar.com/game-news/escape-from-tarkov-patch-1.0.4.5-improves-performance-reworks-weapon-balance-and-fixes-key-issues-aPJVC8b37l9m)

## 7. Maps (owner, 2026-11-01: same map as Tarkov's, own buildings and names)

| Tarkov | Zero Return | To do |
|---|---|---|
| Customs | Border Yard rebuilt on Customs' current layout at real scale (2026-11-01): terrain, river and both bridges, roads, rail, 67 buildings and 6 underground spaces with interiors (Block A and B dorms, fuel stop, old pumps, the Squat, stores 3, 4, 7 and 17, Red Stores, the Bastion with bunker K-13, the Derrick, the Frame, motor shop and boiler cellar, K-11, the Smugglers' Hole), 26 extracts with their rules, 12 spawns by side, the Broker and his crew, THE HOUNDS (the Goons) and THE CULT (the cultists, both 2026-11-02), border snipers, propane; `docs/maps/BORDER_YARD.md` | The real positions of the mounted guns (the system exists and two guns stand on the Bastion roof at our own positions: `docs/design/STATIONARY_WEAPONS.md`), transits to Factory, Reserve and Shoreline (the one to Interchange is in, as are co-op and THE FORESTER, all 2026-11-02), ladders (built as stairs: no climbing), glass, washrooms and denser furniture in the dorms, the 0.16 interiors the reference only gives as extents |
| Interchange | Meridian Mall rebuilt on Interchange's layout at real scale (2026-11-01). Tested in Studio: the build, AI across the levels, every exit's path and rule, light by day and night, and the frame rate (`TEST_RESULTS.md`). Part 1 the outside, part 2 the mall shell (the car park, L1 and L2, atria, roof, stairs, dock bays and 84 empty store units; the stores' interiors are another agent's), part 3 the gameplay: 7 extracts with their rules (the shelter's power-then-valve chain, the empty-backpack fence gap), 25 PMC spawns on two halves, guard routes and posts, THE CARETAKER (60 %, five zones), what the mall power changes (electric locks, the IRONSIGHT alarm), a lethal minefield and a sniper band, ten new keys, car park dressing; `docs/maps/MERIDIAN_MALL.md` (Parts 2 and 3) | The transit to Streets (the one to Customs, the co-op and flare exits are in since 2026-11-02), the car exit's karma pricing (the car itself is built: "Car exits" below), the shelter's keypad chain and the Terragroup container, per-extract timers, key art; the lists under "Interchange mall shell" and "Interchange gameplay" below |
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
  - MORTAR (Big Pipe): no head armour, grenades for flushing cover;
  - KESTREL (Birdeye): a class 4 vest, a chest rig, a frame pack, a marksman rifle.
- **Five double pockets** (ten cells) on all three, drawn as 5 x 2 on their bodies.

Gaps:
- **No grenade launcher**: MORTAR throws grenades.
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
