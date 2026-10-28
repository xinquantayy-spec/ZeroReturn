# Character work — progress checkpoints (M16)

Brief: kit `CLAUDE_CHARACTER_MODELING_PROMPT.md`. Body version **ZR_BLOCK_R15_V1**. Game name: Zero Return.

## Checkpoint 3 — 2026-10-28 23:50 SGT: poses, first person, restart, docs (M16 part A complete)

* **Verified in Studio:**
  * poses with gear (crouch and prone grounded, look up with the raid pack under the new `NeckUp` limit, look
    down, pistol, sprint);
  * the in-raid kit change (helmet, headset behind the neck, gaiter);
  * first person: 41 of 41 own parts hidden locally, block sleeves in the outfit colour, now SmoothPlastic;
  * death (the corpse keeps its 11 pieces), respawn and profile reload;
  * the safehouse kit preview through real requests;
  * a play restart: the five presets look identical;
  * the inventory's EARS and FACE slots;
  * churn: 30 real requests leave the hidden set at 39 = 39 parts.
* **Code:**
  * the neck limit under tall packs (RigMath, Chars, Animator, Appearance);
  * smooth first-person sleeves;
  * showroom dummies grounded for crouch and prone, and a client `hidden` probe;
  * the superseded ZR_Operator and ZR_Gear batches retired (no longer loaded);
  * build 0.9.0-m16a.
* **Docs:** `EQUIPMENT_SYSTEM.md`, `TEST_REPORT.md`, `CHARACTER_ASSET_MANIFEST.csv` (50 meshes, all STUDIO VERIFIED),
  and updates to the root DEVELOPMENT_STATUS, TEST_RESULTS, KNOWN_ISSUES, NEXT_TASK and ASSET_MANIFEST.
* **Tests:** LogicTests 167/167 and CharTests 38/38.
* **Blockers:**
  * two clients (C06 late join, C08 second observer): no multi-client MCP;
  * touch and controller emulation (C11);
  * physical devices;
  * performance profiling;
  * saving, closing and reopening the place file is an owner action.
* **Next (M16 part B):** the items above plus a fabric MaterialVariant, eyewear, the scout and worker presets, and
  a stash character preview. Otherwise resume M12.

## Checkpoint 2 — 2026-10-28 23:25 SGT: first gear set imported, appearance system, presets

* **Blender:** `assets/blender_scripts/build_char_gear.py` (33 meshes, 13,242 tris for the whole batch) with
  helpers `zr_char.py` (`shell`, `band`, `arc_plate`, `strap`, `rround`), preview tools `zr_preview.py`,
  `preview_presets.py`. Sources `assets/blender_sources/ZR_CharGear.blend`, export `assets/exports/ZR_CharGear.fbx`
  (sha1 `8d40be25…`). Uploaded as **ZR_CharGear = 111486052124640**; imported in Studio (all 32 equipment keys +
  helmet A present as MeshParts, sizes equal to the export within 0.02 studs).
* **Code:** `src/shared/Equipment.luau` (looks, item visuals, layering shells, compatibility, hidden regions,
  presets, resolver), `src/server/Services/Appearance.luau` (per-slot diff, revisions, fallback + reconcile),
  Items (headwear / headset / facecover kinds; `ears` and `face` slots; 6 new items), Inv (equipment revision
  `erev`, compatibility refusals), Raid (stale-revision refusal; safehouse shows the profile kit), AI / Loot
  (look per preset, coordinated faction kit, the Foreman's hard hat), client first-person sleeves/gloves from the
  look, headset hearing, inventory slots, Camera hidden-set fix, slung long guns over the worn back gear.
* **Tests:** LogicTests 167/167; CharTests 38/38 (C01, C02 layering, C03, C04, C05, C06 idempotency, C07, C09,
  C12 server side). Studio captures of the five presets (front / side / back + close-ups) in `evidence/`.
* **Fixed on the way:** slung long guns pointed straight back from the torso (now flat across the back, muzzle
  over a shoulder); safehouse "quick move to stash" was refused with BAD_INPUT (the server tried to resolve
  "stash" as a holder).
* **Blockers:** no multi-client tool in this Studio MCP (C06 two clients / late join = BLOCKED, server-side
  idempotency only); no device emulation through MCP (C11 = structural check only); no physical devices.
* **Next:** pose proof with gear (walk, sprint, crouch, aim, reload, head turn, prone), first-person sleeve check in
  a raid, C10 restart check, docs and manifest.

## Checkpoint 1 — 2026-10-28 22:40 SGT: audit, rig and helmet round trip

* `docs/character/TOOL_AUDIT.md`; calibration cube and ZR_CharBase (101424875475699) imported and measured;
  logic suite 167/167 with the block body and the 1.35× third-person weapons.
