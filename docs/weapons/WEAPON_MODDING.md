# Weapon modding (M14): Tarkov's system, our version

Owner request (2026-10-29):

- more detail on items, especially the guns, both in 2D (inventory pictures) and in 3D;
- attachments on guns, shown in the inventory picture and in detail in 3D;
- do it the way Escape from Tarkov does, after researching how Tarkov's modding works.

The systems, rules and screen layouts follow Tarkov as closely as we can. The names, models, pictures and fonts are
our own: no Battlestate art and no real-world brand names, so the game stays safe to publish.

## 1. What Tarkov does (research)

Sources: the Escape from Tarkov wiki (weapon mods, weapon and performance pages), the SPT server's inventory size
code (`InventoryHelper.getSizeByInventoryItemHash`), a modding-rules mod for SPT, and long-standing player
knowledge of the game. Links are at the end.

### 1.1 Mod categories

Tarkov sorts weapon parts into three groups.

| Group | Sub-categories |
|---|---|
| **Functional mods** | Bipods; foregrips; light and laser devices (flashlights, tactical combo devices, laser pointers); muzzle devices (flash hiders and muzzle brakes, muzzle adapters, suppressors); sights (assault scopes, reflex sights, compact reflex sights, iron sights, scopes, night vision and thermal sights); auxiliary parts |
| **Gear mods** | Charging handles; launchers; magazines; mounts; stocks and chassis |
| **Vital parts** | Barrels; gas blocks; handguards; pistol grips; receivers and slides (upper receivers, dust covers, pistol slides) |

### 1.2 Slots and trees

- Every weapon and every part has named slots: muzzle, barrel, gas block, handguard, upper receiver, dust cover,
  charging handle, pistol grip, stock, magazine, mount, scope/sight, front sight, rear sight, tactical, foregrip,
  and others.
- Slots are nested. On an AR-15 type rifle the lower receiver holds the pistol grip, the buffer tube (which holds
  the stock), the magazine and the upper receiver. The upper receiver holds the barrel (which holds the muzzle
  device and gas block), the handguard (foregrip, tactical devices, sight mounts), the charging handle and the
  rear sight.
- An AK holds pistol grip, stock, magazine, muzzle device, gas tube/handguard, dust cover, rear sight and a side
  mount directly on the receiver.
- **Required slots:** a weapon missing a required part (for example a barrel, a dust cover or a charging handle)
  cannot be used.
- **Compatibility:** each slot accepts only the parts listed for it, for example a thread type or a rail.
  Optics usually need a mount or rings, and some parts conflict with others.

### 1.3 Size in the inventory

A weapon's grid size grows with what is attached. Each part has `ExtraSizeLeft`, `Right`, `Up` and `Down`.

- For each direction, the largest value among the attached parts counts. Values are not added together.
- Parts marked `ExtraSizeForceAdd` add on top.
- Width = base width + left + right (plus forced). Height = base height + up + down (plus forced).
- A folded stock takes cells away.

Examples: a long suppressor makes a rifle longer; a 60-round magazine makes it taller.

### 1.4 Pictures and 3D

- A weapon's inventory icon is rendered from its current build, so attachments show on the icon.
- Inspecting an item opens a window with a 3D model you can turn.
- The **modding screen** (out of raid) shows the gun large in 3D with its slots around it. You pick parts for
  each slot and see the stats change.

### 1.5 Stats

| Stat | What it does | How parts change it |
|---|---|---|
| Ergonomics | Aim-down-sights speed, sway and aiming stamina | Parts add flat points |
| Recoil (vertical and horizontal) | How the gun climbs and kicks | Stocks, muzzle devices, grips and handguards reduce it by a percentage |
| Accuracy (MOA) | Spread of the shots | Set by the barrel; muzzle devices change it by a percentage |
| Muzzle velocity | Set by the barrel (percent) | Longer barrels are faster |
| Sighting range | Set by the sight in use | – |
| Loudness | Suppressors make the gun quieter | – |
| Weight | All parts add up | – |

### 1.6 Rules in raid

- **Vital parts cannot be swapped in raid** (barrels, gas blocks, handguards, pistol grips, receivers and slides).
  Since patch 0.14, carrying a **multitool** allows it.
- Functional and gear mods can be swapped in raid from the inventory: sights, muzzle devices, tactical devices,
  foregrips, magazines, mounts and stocks.
- Traders sell guns as **presets**: the factory build, or upgraded builds.

## 2. Our version

| Tarkov | Zero Return |
|---|---|
| Three groups of mods with the sub-categories above | The same groups and categories (`WeaponParts.CATS`); vital parts are flagged |
| Nested named slots, required slots, compatibility filters, conflicts | The same: each part has its slots with a fit tag (a thread, a rail or a platform), the accepted categories and a required flag; conflicts are listed per part |
| Size grows with parts (ExtraSize) | The size comes from the real geometry of the build: the length and height of every part, measured in Blender, in cells. A suppressor or a 60-round magazine grows the gun just as in Tarkov |
| Dynamic icon of the build | The picture is put together from Blender renders of each part (side view, same scale), placed at their slots, in the right order |
| 3D inspect and modding screen | A modding window with the build in 3D (the same Blender meshes), slots around it and the stats |
| Stats: ergonomics, recoil, accuracy, velocity, sighting range, loudness, weight | The same stats, summed over the build |
| No vital parts in raid unless you carry a multitool | The same rule and a multitool item |
| Trader presets | Default and upgraded builds sold by VOS |

### 2.1 Platforms (original guns)

| Gun | Type | Base item | Slots on the base |
|---|---|---|---|
| R-17 Carbine | AR-type rifle, 6.2x40 | lower receiver | pistol grip\*, stock, magazine, upper receiver\* |
| Kestrel KS-7 | AK-type rifle, 7.6x39 | receiver with barrel | pistol grip\*, stock, dust cover\*, handguard\*, muzzle, rear sight, side mount, magazine |
| Sparrow SMG-9 | roller-delayed SMG, 9x19 | receiver with barrel | trigger group\*, stock, handguard\*, muzzle (three-lug), claw mount, magazine |
| Harrow-12 | pump shotgun, 12 gauge | receiver | barrel\*, forend\*, stock, magazine tube\*, top rail |
| Tundra | bolt-action rifle, 7.6x54R | action with barrel | stock\*, muzzle, mount |
| P-9 Vesna | pistol, 9x19 | frame | slide\*, barrel\*, tactical rail, magazine |

\* required slot.

Nested slots:

- R-17 upper receiver: barrel\*, handguard, charging handle\*, top rail (sight or mount), rear sight.
- R-17 barrel: muzzle, gas block\*.
- Railed handguards: foregrip, tactical, top or front sight.
- Railed dust cover and mounts: scope.
- Optic-cut pistol slide: compact reflex sight.
- Threaded pistol barrel: muzzle.

### 2.2 Parts

About 90 new parts plus the existing mods. Names and models are original.

| Group | Parts |
|---|---|
| Barrels | R-17 10.5", 14.5", 18"; Harrow 14", 18.5", 20" heat shield; P-9 standard, threaded |
| Gas blocks | R-17 front sight block, low profile |
| Handguards | R-17 carbine, QR-9 quad rail, FL-13 free float; KS-7 wood, polymer, KR-4 rail; SMG-9 slim, TR-3 tri-rail; Harrow wood, polymer, PF-2 rail forends |
| Receivers and slides | R-17 upper; KS-7 dust cover, RD-7 railed cover; P-9 slide, optic-cut slide |
| Pistol grips | R-17 standard, EG-2, AG-15; KS-7 standard, EK-1, RK rubber; SMG-9 trigger groups |
| Stocks | R-17 fixed, collapsible, SK skeleton; KS-7 wood, folding, TA-7 tube; SMG-9 fixed, retractable, end cap; Harrow wood, pistol-grip, TS-12; Tundra wood, sporter, CH-54 chassis |
| Charging handles | R-17 standard, extended latch |
| Magazines | existing ones, plus R-17 60-round, KS-7 polymer and 40-round, SMG-9 50-round drum, P-9 33-round; Harrow 4/6/8-shell tubes |
| Muzzle devices | birdcage, MB-6 brake, CP-3 compensator, SR-6K and the 6.2 suppressor; KS-7 slant brake, 7.6 brake, SR-7; SMG-9 three-lug flash hider and the 9 mm suppressor; Harrow choke and breacher; Tundra brake, SR-54; P-9 PC-1 compensator |
| Sights | flip-up front and rear iron sights, KS-7 tangent sight; RS-1 reflex, HS-3 holographic, MR-1 compact reflex, C4 4x prism, V6 1-6x, L8 8x |
| Mounts | RM-1 riser, 30 mm scope mount, KS-7 SM-2 side mount, SMG-9 claw mount, Tundra side mount and scout rail |
| Foregrips | vertical, AFG angled, stubby, handstop |
| Tactical devices | WL-2 light, LC-4 light/laser, LP-1 laser |
| Tools | multitool (vital parts in raid) |

### 2.3 Pipeline

1. **Blender** (`assets/blender_scripts/zr_guns.py` and `guns_*.py`): each part is modelled in its own frame, with
   its origin at the point where it attaches. It records its slots (child attachment points) and anchors (hands,
   eye, muzzle, light beam, magazine well, ejection port). From each part come:
   - a standalone inventory picture, through the item icon pipeline;
   - a side-view sprite at a fixed cells-per-metre scale, with the pixel of its origin;
   - meshes per material (`ZR_WP_<PART>__<mat>`) with baked AO, exported in batches.
2. **Generated data**: `GunMeta.luau` holds the pieces, slots, anchors, 2D extents and sprite rectangles.
3. **Shared rules**: `WeaponParts.luau` holds the parts, categories, fits, stats and presets. It provides size,
   layout, stats, compatibility and operability. The server and the client share it.
4. **Server**: `Inv` works on trees.
   - attach and detach any part in any slot, swapping;
   - the size check where the gun lies;
   - vital parts in raid only with a multitool;
   - required parts, conflicts, presets and the migration of old builds.
5. **Client**:
   - the viewmodel and third-person guns are assembled from the meshes (hands, eye and muzzle come from the
     build);
   - inventory tiles draw the composite picture;
   - the modding window shows the build in 3D with its slots and stats.

## Sources

- [Escape from Tarkov Wiki: Weapon mods](https://escapefromtarkov.fandom.com/wiki/Weapon_mods)
- [Escape from Tarkov Wiki: Performance modifiers](https://escapefromtarkov.fandom.com/wiki/Performance_modifiers)
- [Escape from Tarkov Wiki: AK-74M](https://escapefromtarkov.fandom.com/wiki/Kalashnikov_AK-74M_5.45x39_assault_rifle)
- [Escape from Tarkov Wiki: M4A1](https://escapefromtarkov.fandom.com/wiki/Colt_M4A1_5.56x45_assault_rifle)
- [SPT server, InventoryHelper.ts (item size with attachments)](https://github.com/sp-tarkov/server/blob/master/project/src/helpers/InventoryHelper.ts)
- [Fontaine's Weapon Modding Quality of Life (describes the in-raid vital part rule)](https://hub.sp-tarkov.com/files/file/1188-fontaine-s-weapon-modding-quality-of-life)
- [TarkovForge attachment categories](https://tarkovforge.com/attachments)
