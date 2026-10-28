# Character / equipment test report (C01–C12)

* **Environment:** Roblox Studio 0.745, one local client (wurdo0) plus the server, unpublished place (in-memory
  profiles), Rojo 7.7.1, Blender 5.2.3.
* **Build:** 0.9.0-m16a. Body version ZR_BLOCK_R15_V1. Assets ZR_CharBase 101424875475699 and
  ZR_CharGear 111486052124640.
* **Runs:** 2026-10-28, 22:30–23:45 SGT.
* **Automated suites:** `ZR_Dev:Invoke("tests")` passes 167/167 and `ZR_Dev:Invoke("chartests")` passes 38/38.
  Both ran several times; the last run was after the final code change.

Evidence levels (kit definitions):

| Level | Meaning |
|---|---|
| EXPORTED | Blender export only |
| IMPORTED | Loaded in Studio |
| STUDIO VERIFIED | Checked in a Studio playtest (one client unless stated) |
| MULTICLIENT VERIFIED | Not reached: no multi-client tool |
| EMULATED | Not reached |
| DEVICE VERIFIED | Not reached |

| ID | Test | Mode / equipped keys | Result | Status | Level | Evidence |
|---|---|---|---|---|---|---|
| C01 | Export/import one helmet on the rig (then the whole set) | `build_char_base.py` and `build_char_gear.py` → FBX → Open Cloud → `InsertService` | Calibration cube orientation and scale correct. 15 body segments and 33 gear meshes imported as MeshParts; sizes equal the Blender exports (≤ 0.02 studs). Helmet A pivots on the head centre and sits correctly. Asset IDs resolved. | PASS | STUDIO VERIFIED | `evidence/C01_*`, CharTests C01 ×4 |
| C02 | Idle, walk, sprint, crouch, crouch-aim, prone, aim, look up / down, pistol, reload | Operator kit (helmet A, GS-1, plate rig, patrol or raid pack, holster); showroom dummies driven by the real RigMath / Animator | Gear follows its segments with no detached parts. Layers clear each other (rig scaled over the carrier, pack moved back, camera forward). With the raid pack the neck limit stops the helmet sinking into the pack. Weapons are no longer slung pointing straight back. Reload frame inconclusive (mid-gesture). Head yaw (free look) not captured separately. | PASS (notes) | STUDIO VERIFIED | `evidence/C02_gear_poses_*.jpg`, CharTests C02 ×2 |
| C03 | Equip A → B → none; per-slot diff; covered regions | Dummies through Inv + Appearance; the real player in the safehouse through the request path | Only the authoritative slot contents remain. A is destroyed when B replaces it, and the gear count returns to base. A backpack change keeps the helmet and outfit instances. The chest-rig back harness hides under a pack and comes back without it. The headset band goes behind the neck under a cut helmet or cap. Safehouse: shell → cap swap, then the headset fits. | PASS | STUDIO VERIFIED | CharTests C03 ×6, session log |
| C04 | Rapid changes during delayed loading | Helmet B mesh removed from the library, then B → A → B, then "loaded" | Neutral box fallback (decorative flags). On arrival it reconciles to the latest state (B), with the revision bumped. Protection stays class 2 from the item. The live retry loop was not exercised because all batches loaded first time. | PASS | STUDIO VERIFIED (simulated delay) | CharTests C04 ×3 |
| C05 | Invalid equip requests | Real `inv` dispatcher with a test-double player and a fresh profile | Refused: unknown instance (`NO_ITEM`), stale revision (`STALE_REVISION`), wrong slot (`WRONG_SLOT`), headset under a full-cut helmet (`HELMET_COVERS_EARS`), raid container in the safehouse (`NOT_IN_RAID`), committed / queued loadout (`QUEUED`). Client `visual`, `mesh` and `armor` fields are ignored. Real player: headset under a shell refused. | PASS | STUDIO VERIFIED | CharTests C05 ×9 |
| C06 | Two clients, late join, respawn, reconnect | Single client only | Same state rebuilds with the same revision and no duplicates. Death in raid: the corpse keeps all 11 pieces, and the respawn shows the remaining profile kit with no duplicates. Profile reload ("rejoin") keeps the appearance. The server shows the gear at Transparency 0. A second observer client and a real late join could not be run. | BLOCKED (multi-client); server side PASS | STUDIO VERIFIED (server side) | CharTests C06, session log |
| C07 | Shots at decorative pouches / backpack | Combat raycast filter on a dummy with shell, carrier, chest rig and raid pack | Pieces have no collision, queries or touch and are massless and welded. A shot from behind passes the pack and hits UpperTorso. A shot through the pack alone hits nothing. A shot down through the helmet hits Head; armour is decided by Health from the item. | PASS | STUDIO VERIFIED | CharTests C07 ×4 |
| C08 | First- and third-person views | Player in a raid and in the safehouse | First person: all 41 local parts are hidden locally, including 11 gear pieces. Viewmodel sleeves are block meshes in the look's colour (`4F543E` = expected). Orbit and third-person views show the gear. Server copies stay visible to others; no second client was available to observe them. | PASS (single client) | STUDIO VERIFIED | `evidence/C08_*` |
| C09 | Operator, scavenger, guard, bodyguard, Foreman | Presets: look plus seeded AI loadout (operator: reference kit) | All five reuse one rig and one appearance path and are distinct. 480 seeded AI kits contain no invalid combination. Front, side and back captures were taken in Blender and in Studio. | PASS | STUDIO VERIFIED | `evidence/C09_*`, CharTests C09 ×7 |
| C10 | Save / close / reopen and Rojo sync | Play stop → start (fresh server, Rojo-synced code, assets reloaded) | The five presets' appearance descriptions are identical before and after. Not done: saving and closing the place file, which is an owner action. Persistent profiles need the published place's DataStore. | PASS (restart); reopen NOT RUN | STUDIO VERIFIED | session log (`c10_before/after`) |
| C11 | Touch / controller equipment screen | Studio, keyboard (Tab via MCP input) | The inventory opens. EARS and FACE slots render under HEADWEAR, and every slot box is a Selectable button (gamepad navigation path). Equip, transfer and back work through tap/click-to-select (no drag needed); the stash quick-move bug is fixed. Touch and controller emulation were not run. | PARTIAL | STUDIO VERIFIED (structure, KBM) | `evidence/C11_inventory_ears_face_slots.jpg` |
| C12 | Equipment churn | 360 changes on a dummy; 30 real requests on the player | Dummy descendants return to the baseline (38 = 38). The player's first-person hidden set equals the current parts (39 = 39); the old list leaked destroyed parts. | PASS | STUDIO VERIFIED | CharTests C12, session log |

## Triangle budget (counts only; not a performance measurement)

Body: 3,880 tris. Fully equipped totals (meshes only; weapons are part-built):

| Preset | Tris |
|---|---|
| Operator | 8,952 |
| Bodyguard | 8,438 |
| Foreman | 8,012 |
| Guard | 6,892 |
| Scavenger | 5,484 |
| Heaviest possible kit (faceplate helmet, Bulwark armour with collar and arm guards, chest rig, raid pack) | 9,988 |

Per-item counts:

| Item | Tris | Target |
|---|---|---|
| Helmet A | 952 | Slightly over 400–900 |
| Helmet B | 684 | 400–900 |
| Carrier + pouches | 1,800 | 900–1,800 |
| Patrol pack | 732 | 500–1,000; 1,060 with the shared straps |

Frame time, memory and device profiling: **NOT RUN**. Physical phone and console: **NOT VERIFIED**.
