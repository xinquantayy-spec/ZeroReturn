# Screen sketches / platform adaptation

## Raiding — 16:9
```text
  ◉ REC  FIELD RECORDER M4 / CH.04                     QUAY 7 / ACTIVE
  10:08:17  ███▒ SIGNAL                               06:34 LEFT / EXFIL A


                       <world viewport — minimal reticle>

             [E/TAP/X] Search supply crate  (only context)

  H E A L T H [██████████]    S T A M I N A [█████░░░]         R-17  25 | 90
```

## Phone landscape
- Left 24–35% virtual movement; sprint toggle just above. Right 30% ADS/fire/reload/interact clustered (do not cover center).
- Very small corner REC text can become just `● REC` and timer. Health/ammo labels get priority over metadata.
- Backpack panel uses 2/3 screen with scroll sections, tap-to-transfer and large close. Fire disabled when UI is open.
- No drag-to-grid mandatory; use item action sheet: `Take / Equip / Move / Drop / Inspect`.

## Console
- At safehouse, one focused tab bar: `LOADOUT | STASH | DEALERS | CONTRACTS | SETTINGS` with LB/RB navigation, focused panel at each side, D-pad/analog focus and X/□ to act.
- Inventory focus never lost when item removed; set next focus nearest valid cell. Scroll positions persist when switching panels.
- In raid, `Y/△` opens backpack and `B/○` closes; selection rings clearly visible. Roblox system menu buttons take precedence.

## Post raid
Two large columns: `CARRIED OUT` vs `LOST`, then `GEAR RETURNED`, `NET VALUE`, `THREAT LOG`. Primary `RETURN TO SAFEHOUSE` action large and focused by default; no popup spam. Avoid long unscrollable item grids.

## Original visual treatment
Rectilinear panels with 1px instrument borders, simple thin-line pictograms, warm off-white over charcoal with muted ochre highlights. Text by semantics, not using neon rarity colors everywhere. No copied BODYCAM overlay arrangement; mockup is an initial example, refine freely.
