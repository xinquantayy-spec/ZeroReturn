# Next Task

**Current focus:** finish M10 leftovers, then milestone **M11 — Combat extras** (Tarkov grenades, weapon wear).

## M10 leftovers (need the dev PC online)

1. Upload `assets/exports/ZR_Gear.fbx` (`zr_upload.upload_model(path, "ZR_Gear")`), add it to `AssetIds.luau`, check the helmet, plate carrier, pouches, pack, body camera and holster on players and AI in Studio.
2. Check in Studio: rain streaks and splashes, lens droplets, the new vignette and edge haze, the environment sounds (rain, roof, wind, insects, gulls, thunder, doors, keys, pickup).
3. Blender weapon meshes against the `WeaponModels` anchors (start with the R-17 and the P-9).

## M11 plan

1. **Grenades.** Frag, stun and smoke grenades as rig/pocket items. G throws the first grenade in your rig (overhand; underhand when crouched), 3.5 s fuse after release, server-simulated arc with bounces. Frag: fragments hit random body parts within ~9 studs behind no cover (armour applies, low penetration); stun: white-out and ringing when facing it nearby; smoke: a cloud that blocks sight for players and AI.
2. **AI grenades.** Units with grenades throw them at a target that stays in cover, and run from grenades that land near them.
3. **Weapon durability.** Every shot wears the weapon a little; worn weapons malfunction more (misfire, failure to feed, jam). A malfunction stops the weapon until you clear it (the reload key, longer for jams). Traders repair weapons for money; repair kits restore part of it in raid.
4. Logic tests, Studio test, docs, commit.

Then M12 (QA: two-client test, device emulation, performance, exploit regression including vault speed checks, scrollable inventory gear column, docs, git bundle backup).

## Resume steps

1. Read `DEVELOPMENT_STATUS.md` and `KNOWN_ISSUES.md`.
2. Start `rojo serve --port 34873` in `Documents\EscapeFromBloxov`; open the place (now saved as `Zero Return.rbxl`) and connect the Rojo plugin.
3. Play, then run `ZR_Dev:Invoke("tests")` (baseline **146/146**).
