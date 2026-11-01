# Tarkov parity: information, quality of life, settings and graphics

**Standing rule (owner, 2026-10-31):** build Zero Return as close as possible to Escape from Tarkov in every aspect,
less the exceptions below. Every task starts with research on how Tarkov does it and ends with a check that the
result is as exact a copy as the exceptions allow. This file is the checklist for the parts that are not core
gameplay: item information, inventory and menu quality of life, controls, settings and visuals. It was written after
the owner pointed out that weapons show no fire rate or damage in our game (research 2026-10-31, sources at the end).

## Exceptions (assumed; the owner can add or remove)

1. **Intellectual property.** Original names, item and map art, icons and fonts; no real gun or gear brands; no
   Battlestate assets. Rules, numbers, behaviour and screen layouts are copied; the art is not. **Maps copy Tarkov's
   layouts** (terrain, roads and where every building stands, at real scale) with our own buildings, interiors and
   names (owner, 2026-11-01; in the project instructions since then).
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
| Glasses, ballistic glasses, gas masks | Blindness protection (the share of a flash charge it stops), weight, grid size; ballistic glasses also armor class, durability, material and the eyes area; what the item blocks | Missing (no eyewear slot) | Built 2026-11-01: BLINDNESS PROTECTION, LENS TINT, class, durability, material (GLASS), the EYES area and BLOCKS rows. Plain glasses show no durability, as in Tarkov. Not run in Studio yet |
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
| Hideout: modules, crafts, shooting range, customisation (0.16: wall finishes "Blue paint", "Factory walls", "Modest wallpaper"; floors "Small tiles", "Factory floor"; a "Factory ceiling"; unlocked by level, tasks, achievements and prestige; posters as hideout upgrades and loot; range targets by leveling the range) | Have (in the bunker); the bunker is one shared, kept relay station (painted walls, grime only where it gathers, 2026-11-01) | Customisation: per-player finishes drawn on each client (the bunker is shared), unlocked by level and tasks; posters; range targets |

**Skills (2026-11-01):** 24 skills in Tarkov's four groups, levels 0 to 51 (level n costs min(10n, 100) points), raid fatigue, Health and Charisma growing from their groups, each with a working effect. Missing: MASTERING, ACHIEVEMENTS, PRESTIGE, friends and chat.

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
| Head device (NVG, face shield) | N | Done 2026-11-01: N flips goggles or raises the face shield | - |
| Stationary guns (NSV, AGS-30): man the gun, aim, fire, leave | F is Interact; Tarkov documents no control for them, so how to leave and how to zoom were not found | Done 2026-11-01 with controls of our own: the prompt (F, pad X, tap) mounts; mouse / right stick / screen drag aims; fire and zoom follow the Fire and Aim keys, right trigger and left trigger, the FIRE and ZOOM buttons; F, B or LEAVE gets off (section below) | Sounds, animation, the real positions |
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
| Time of day that follows a raid clock; weather (clear, overcast, rain, fog, wind; winter snow) | Raid clock, weather and fog per raid; seasons from the real calendar (2026-11-01: winter snow and frost, autumn foliage and more rain, spring greener) | - |
| Per-material impacts, bullet holes, muzzle flash and smoke, tracers, blood | Have | Check against Tarkov in M15 |
| Pain darkening, tremor, tunnel vision, contusion, stun and flash white-out | Have | Check durations |
| Picture-in-picture optics, variable zoom, switch sights | Variable zoom done 2026-11-01 (Alt + right mouse steps the V6 between 1x, a red-dot view and 6x; kept per scope). PiP is not possible in Roblox (no rendering the world into a lens), so a scope zooms the whole view behind its mask (exception 3) | Switch sights (Ctrl + right mouse) once builds can carry a backup sight |
| Ballistics: bullets fly with drop and travel time by muzzle velocity, zeroing (Page Up / Page Down) | Done 2026-11-01: drop and travel time by muzzle velocity, AI aim for it, zeroing with Page Up / Page Down in Tarkov's steps | Per-scope zeroing lists, if needed |
| Night vision and thermals | Goggles done 2026-11-01: four night-vision tubes (monocular circle, two binoculars, panoramic quad; phosphor colour, gain, grain, light flare each) and thermal goggles, on mounted helmets or a head strap, drawn on characters up or down (ZR_EyeGear); the faceplate helmet's shield (raised = face open to hits, lowered = visor tint) | Night-vision and thermal scopes, the flip animation of the mount, AI wearing goggles at night |
| Face shield, glasses and gas mask overlays (cracks when hit) | Face shield: a tinted visor round the view (N). Glasses and gas mask built 2026-11-01: a mild lens tint per item, blindness protection against stun charges, the mask's rubber frame with smoked lenses; both step aside while night-vision goggles are down | Cracks when hit, the mask's breathing loop, fogging and raindrops (notes below) |
| Full-body awareness, weapon inertia and sway (0.13.5), visual recoil with bolt movement and camera shake (0.16) | Arms, sway, recoil | Legs in view, bolt movement |
| Audio: Steam Audio reverb and occlusion from the geometry (0.12.6 on, occlusion reworked in 0.16.7.0); indoor and outdoor sound; Interchange's mall soundscape | Written 2026-11-01, silent until `ZR_SFX_Amb` is uploaded (`Sounds.AMB_ATLAS`): one reverb for the listener's space (7 classes plus marked floors), room tone, mains hum with the power, car park tone, drips, distant gunfire, the IRONSIGHT siren, the substation generator, dust in the skylights (MEDIUM and up) | Per-source occlusion and reverb cannot be done in Roblox (exception 3); levels still to be set by ear once the asset is in; see "Atmosphere and ambience" below |

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
sound asset `assets/audio/out/ZR_SFX_Amb.ogg` (698 KB, 11 sounds) is **not uploaded**, so all of it is silent until the owner's
session sets `Sounds.AMB_ATLAS`.

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
  Roblox has one reverb for the listener and no occlusion: a shot in a hall heard from a washroom gets the washroom's reverb, and
  sounds carry through walls within their radius.
- **Not in any source, so our design:** the mall's room tone, the fluorescent and mains hum, the car park tone, the drips, the dust
  in the skylights. Tarkov's Interchange soundscape (empty mall, wind, arcade, escalators) was not found documented anywhere.
- **Distant gunfire is scripted** (a faint burst every 40 to 120 s in raids, 200 to 320 studs away, quieter indoors). In Tarkov a
  far shot is a real fight; ours is harmless and tied to no one. The rate and level are ours.
- **Siren length and sound:** how long the Kiba alarm rings is not documented; ours is the existing 60 s. The sound is a procedural
  warble, not a recording.
- **Machines with power on** (escalators, arcade cabinets, announcements, lifts) are not built; only the hum.
- **Dust** is a column under the pane, not the sun's slanted shaft, and not tied to the actual lit floor area.
- **Levels and thresholds are untested by ear and by frame rate:** the space thresholds (section 3 of `docs/look/ATMOSPHERE.md`), the
  layer volumes, the Auditorium choice for the biggest halls (Hangar is a one-word change).
- **Roblox sound API not verified:** the region semantics of `Sound` (`PlaybackRegion`, `LoopRegion`) and `Stop` / `Play` on a region
  are not described on the Roblox pages that could be read; the code uses them the way the existing atlases do.
- **Not run:** nothing above has been run in Studio, on a phone or on a console, and no frame rate or memory was measured.

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
- Eyewear and face gear (2026-11-01): [TarkovForge: glasses](https://tarkovforge.com/glasses) (armor, durability, blindness protection), [6B34](https://tarkovforge.com/glasses/6b34-anti-fragmentation-glasses), [AFGlass](https://tarkovforge.com/glasses/anti-fragmentation-glasses), [Caiman visor](https://tarkovforge.com/glasses/galvion-caiman-fixed-arm-visor), [GP-5 gas mask](https://tarkovforge.com/face-covers/gp-5-gas-mask); Wiki: [Eyewear](https://escapefromtarkov.fandom.com/wiki/Eyewear), [RayBench Aviator glasses](https://escapefromtarkov.fandom.com/wiki/RayBench_Aviator_glasses) (Ragman LL4), [Kolpak-1S](https://escapefromtarkov.fandom.com/wiki/Kolpak-1S_riot_helmet), [EXFIL face shield](https://escapefromtarkov.fandom.com/wiki/Team_Wendy_EXFIL_Ballistic_face_shield_(Black)), [Maska-1SCh](https://escapefromtarkov.fandom.com/wiki/Maska-1SCh_face_shield_(Olive_Drab)), [Jason mask](https://escapefromtarkov.fandom.com/wiki/Jason_mask) (blocks lists)
- Stationary guns (2026-11-01): Wiki [Weapons](https://escapefromtarkov.fandom.com/wiki/Weapons) ("Stationary weapons"), [NSV Utyos](https://escapefromtarkov.fandom.com/wiki/NSV_Utyos_12.7x108_heavy_machine_gun), [AGS-30](https://escapefromtarkov.fandom.com/wiki/AGS-30_30x29_automatic_grenade_launcher); [Dexerto: grenade launchers](https://www.dexerto.com/escape-from-tarkov/how-to-destroy-escape-from-tarkov-players-using-grenade-launchers-1355803/) (arc and zeroing); the rest of the list is in `docs/design/STATIONARY_WEAPONS.md`
- Atmosphere and ambience (2026-11-01): [Gfinity: 0.12.6 notes](https://www.gfinityesports.com/article/escape-from-tarkov-12-6-patch-notes-update-full-list-changes-wipe-pc) (first Steam Audio, indoor sound fix), [Steamworks: Steam Audio](https://partner.steamgames.com/doc/features/steam_audio), [PCGamesN](https://www.pcgamesn.com/escape-from-tarkov/update-audio-overhaul) and [Insider Gaming](https://insider-gaming.com/tarkov-patch-overhauls-immersive-audio/) (0.16.7.0 occlusion), [Wiki: Interchange](https://escapefromtarkov.fandom.com/wiki/Interchange) (illumination grid, alarm), [TarkovForge: Kiba Arms outer door key](https://tarkovforge.com/keys/kiba-arms-outer-door-key) (alarm 3 s after the door), [Guild Order: audio guide](https://guildorder.com/hi/games/tarkov/guides/audio-fluency-and-sound-triangulation) (distant shots); the rest is in `docs/look/ATMOSPHERE.md`
- Patch notes: [0.16.0.0 (Sportskeeda)](https://sportskeeda.com/esports/escape-tarkov-patch-notes-update-0-16-0-0-new-event-customs-rework-prestige-system), [0.16.7.0 (AltChar)](https://www.altchar.com/game-news/escape-from-tarkov-patch-0.16.7.0-full-patch-notes-aP2RA1G8vdlq), [1.0.4.5 (AltChar)](https://www.altchar.com/game-news/escape-from-tarkov-patch-1.0.4.5-improves-performance-reworks-weapon-balance-and-fixes-key-issues-aPJVC8b37l9m)

## 7. Maps (owner, 2026-11-01: same map as Tarkov's, own buildings and names)

| Tarkov | Zero Return | To do |
|---|---|---|
| Customs | Border Yard rebuilt on Customs' current layout at real scale (2026-11-01): terrain, river and both bridges, roads, rail, 67 buildings and 6 underground spaces with interiors (Block A and B dorms, fuel stop, old pumps, the Squat, stores 3, 4, 7 and 17, Red Stores, the Bastion with bunker K-13, the Derrick, the Frame, motor shop and boiler cellar, K-11, the Smugglers' Hole), 26 extracts with their rules, 12 spawns by side, the Broker and his crew, border snipers, propane; `docs/maps/BORDER_YARD.md` | The real positions of the mounted guns (the system exists and two guns stand on the Bastion roof at our own positions: `docs/design/STATIONARY_WEAPONS.md`), co-op extracts and transits, the other boss groups (the trio, cultists, the partisan), ladders (built as stairs: no climbing), glass, washrooms and denser furniture in the dorms, the 0.16 interiors the reference only gives as extents |
| Interchange | Meridian Mall rebuilt on Interchange's layout at real scale (2026-11-01). Tested in Studio: the build, AI across the levels, every exit's path and rule, light by day and night, and the frame rate (`TEST_RESULTS.md`). Part 1 the outside, part 2 the mall shell (the car park, L1 and L2, atria, roof, stairs, dock bays and 84 empty store units; the stores' interiors are another agent's), part 3 the gameplay: 7 extracts with their rules (the shelter's power-then-valve chain, the empty-backpack fence gap), 25 PMC spawns on two halves, guard routes and posts, THE CARETAKER (60 %, five zones), what the mall power changes (electric locks, the IRONSIGHT alarm), a lethal minefield and a sniper band, ten new keys, car park dressing; `docs/maps/MERIDIAN_MALL.md` (Parts 2 and 3) | The second boss (the hammer boss), airdrops, co-op, flare and transit extracts, the car exit's karma pricing (the car itself is built: "Car exits" below), the shelter's keypad chain and the Terragroup container, per-extract timers, key art; the lists under "Interchange mall shell" and "Interchange gameplay" below |
| Woods | Pinewatch, parked by the owner | - |
| Hideout look | The bunker is kept, not ruined (2026-11-01): painted walls, grime only where it gathers | Hideout customisation (section 3) |

### Interchange ground and outside: Meridian Mall, part 1 (2026-11-01)

- Co-op extracts, transits and flares do not exist: WEST CAMP is scav-only at the reference's co-op spot, RIVER PATH is a plain open
  exit, SHELTER EXIT supports only the power rule (the hidden switch and the keycard panel are Play's).
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
- **Second boss**: Tagilla (hammer boss, KASSA garage, 35 % in the 2026 sources, absent from SPT) is not built; the AI keeps one boss per map.
- **Airdrops** (20 %, 6 or more players, 5 to 15 minutes in): there is no airdrop system; the numbers sit in `L.hazard.airdrop`.
- **Co-op, flare and transit extracts**: WEST CAMP is scav-only, RIVER PATH is a plain exit (no green flare), and the transits to Streets
  and Customs do not exist.
- **SUBSTATION CAR** was a plain paid exit when part 3 was written; it is a vehicle exit now (see "Car exits" below: 50 % chance, pay at the car, 4 seats, shared countdown, single use). Still a gap: no Scav karma in the price.
- **Saferoom chain simplified**: the urinal flush that reveals a keypad is a service valve in the washroom; not copied are the keypad,
  the padlocked door with its inside button, the lever for the Object-14 container, and the Terragroup container (Object #21WS card) in the
  south-west container yard.
- **Extract timers**: Tarkov gives each exit its own (3 to 60 s, 60 s shared at the car); here every extract but the cars uses the standard hold (a car has its own shared countdown: "Car exits" below).
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
