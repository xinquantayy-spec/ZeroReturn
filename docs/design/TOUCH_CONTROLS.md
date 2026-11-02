# Touch controls

Status: version 2, built 2026-11-02 (`src/shared/TouchLayout.luau`, `src/client/Controllers/Touch.luau`).
Checked in Studio with touch forced through the test bridge; **not yet run on a phone or tablet**.

Tarkov has no touch controls, so this layout is ours (EFT_PARITY exception 4, cross-platform). It follows the owner's
brief of 2026-11-02 and what the big mobile shooters settled on.

## The owner's brief

- Symbols on the buttons, not words.
- Fewer buttons. The rarely used ones go behind a button that opens and closes.
- One movement stick that walks and, pushed further, runs.
- Every control can be resized and moved.
- FIRE like Call of Duty: Mobile: it aims down sights by itself, and the shot follows the thumb as it moves on FIRE.
- Round buttons, except the settings-type ones.
- Research what works in other mobile shooters and improve on the brief where it helps.

## What the research found

| Game | What we took |
|---|---|
| Call of Duty: Mobile ([Activision](https://blog.activision.com/call-of-duty/2019-10/Getting-a-Grip-on-the-Call-of-Duty-Mobile-Controls)) | One-tap ADS when firing, set per weapon in Advanced mode. Joystick Sprint: hold the stick forward to sprint. Custom Layout: drag, resize and fade every element. A Fixed Joystick option. A Fixed R-Fire Button option (by default the fire button moves with the thumb). |
| PUBG Mobile ([PocketGamer](https://www.pocketgamer.com/playerunknowns-battlegrounds/pubg-for-mobile-cheats-and-tips-essential-tips-to-master-touch-screen-controls)) | Run lock: while running, an icon appears ahead of the thumb; release on it and the character keeps running. The eye button is dragged for free look. A left-side fire button. A fire-mode button. |
| Arena Breakout, the closest mobile game to Tarkov ([PocketGamer](https://www.pocketgamer.com/arena-breakout/best-control-layouts)) | Good players use three or four fingers: a fire button at the top left for the left index finger, auto ADS, and peek, jump, crouch and reload within reach of the right index finger. Two-finger defaults suit beginners. |

What this means for the layout:

- Two-thumb defaults that work out of the box.
- A left fire button that three-finger players can switch on.
- Every element can be moved, resized, faded or hidden.
- Holding a button does a second job, so fewer buttons are needed.

## The layout

Defaults, as a share of the safe area, with sizes in px on a 390 px tall screen; larger screens scale up to 1.35x. Each
icon comes from one atlas (below) and is tinted at runtime. A button lights in ochre while it is on: held, aiming,
crouched, leaning, or with its tray or wheel open.

| Control | Icon | Default | Tap | Hold | Notes |
|---|---|---|---|---|---|
| Move stick | ring, knob | left, floats | walk (analog) | | Pushed past its ring, within 55 degrees of straight ahead, it runs. While running, a lock shows above it: let go on the lock and the run continues until the stick is touched again. |
| FIRE | round | right, 96 px | fire | fire | Held, it aims down sights (AIM WHEN FIRING) and lets go after. Dragging the thumb on it turns the view, so the shots follow it. |
| AIM | crosshair | above-left of FIRE | aim on / off | | On touch, a tap always toggles aiming. |
| RELOAD | magazine arrow | right edge | reload | check the magazine | |
| JUMP | arrow up | bottom right | jump or vault | | |
| CROUCH | crouching figure | bottom | crouch or stand | prone | The icon shows the stance you are in. |
| GRENADE | grenade | bottom | | hold, drag, let go | Hold to ready it, drag to aim, let go to throw. |
| MED | cross | bottom centre | the med wheel | the best med now | The wheel holds AUTO plus the items in quick slots 4 to 0. |
| SWAP | arrows | centre | next weapon | inspect the weapon | |
| MODE | three rounds | centre | fire mode | check the fire mode | |
| LEAN L / LEAN R | leaning figures | top right | lean while held | | |
| LOOK | eye | top centre | free look while held, drag to turn the head | | |
| MORE | three dots | top centre | opens the tray | | |
| HOLD BREATH | lungs | left | | while aiming | Shown only while aiming. |
| Menu row | rounded squares | top bar band | settings, exits, bag | | |

Off by default; the editor can turn them on:

- **LEFT FIRE:** the three-finger layout.
- **TACTICAL DEVICE:** tap it to toggle the device, hold it to change the device's mode.
- **NIGHT VISION.**

The device and the goggles are also in the tray, and their buttons only show when the gun or helmet has one.

**The tray (MORE)** holds the rarely used actions: check the magazine, check the chamber, check the fire mode, inspect,
zeroing up, zeroing down, sight mode, tactical device, device mode and night vision.

- An item shows only when it can do something. For example, sight mode needs a sight with more than one zoom, and
  device mode needs a light and laser combo.
- The tray closes after 5 s or when you leave the raid.
- Buttons under the tray fade so the tray reads.

**At a stationary gun:**

- GUN FIRE, GUN ZOOM and LEAVE take FIRE's, AIM's and RELOAD's places in the player's own layout. GUN FIRE is dragged
  to traverse the gun.
- The other controls hide, apart from SETTINGS and BAG.

Tarkov's keys are reached like this:

- **Slot keys (1, 2, 3, V):** SWAP cycles through them.
- **Quick slots 4 to 0:** the MED wheel.
- **Inventory:** BAG. **Exits:** EXITS.

## Editing the layout

Open it from Settings, CONTROLS, EDIT TOUCH LAYOUT.

- Every control shows; hidden ones are dimmed.
- Drag a control to move it. Tap it to pick it, then use the bar:
  - SIZE - / SIZE +: 60 % to 160 %
  - OPACITY - / OPACITY +: 25 % to 100 %
  - HIDE / SHOW
- RESET goes back to the defaults. CANCEL closes without changes. SAVE keeps the layout.
- A saved layout goes into the profile with the other settings:
  - `TouchLayout.sanitize` keeps only known controls, finite numbers within the limits, and true/false for hidden.
  - The settings request accepts up to 32 keys per table (`Remotes.onReq` maxKeys), because the layout has 24 controls.
- On joining, `Settings.fromServer` loads the layout back.

## Settings, CONTROLS

- **TOUCH: AIM WHEN FIRING** (on by default): FIRE aims down sights while held. Off, it fires from the hip.
- **TOUCH: FLOATING STICK** (on by default): the stick comes to where the thumb lands, anywhere in the left 40 % under
  the top 30 %. Off, it stays where the layout puts it, and the knob goes to the thumb.
- **EDIT TOUCH LAYOUT.**

While this layout is on, Roblox's own stick and jump button are turned off (`GuiService.TouchControlsEnabled`).

## Icons

`assets/textures/gen_touch_icons.py` draws 32 white icons in 128 px cells, 8 per row, on a 1024 x 512 sheet
(`ZR_TEX_TouchIcons.png`). The sheet was uploaded as decal 112837097438845 and image 124317104695534
(`TouchLayout.ICONS`). The icons are our own drawings: no game's icons were copied.

## Testing

Logic tests check that:

- every icon and action exists;
- no two controls overlap and none is off screen on 844 x 390, 667 x 375, 932 x 430 and 1024 x 768;
- `sanitize` keeps and drops the right things;
- the settings request takes a full 24-control layout and refuses junk.

Studio results: TEST_RESULTS "Touch controls v2".

Not verified (KNOWN_ISSUES 79):

- a real phone or tablet, or two thumbs at once;
- notches and safe areas on real devices;
- the layout surviving a real second session (the place is unpublished, so the store is in-memory).
