# When to paste which prompt

First session: `COPY_PASTE_START.txt` -> it reads and executes stage 00.

Then run these **in separate Claude Code turns**, copying each file's entire contents:
1. `01_LOCK_GAMEPLAY_AND_ACCEPTANCE.md`
2. `02_BOOTSTRAP_ROJO_SOURCE_AND_TESTS.md`
3. `03_GREYBOX_MAP_AND_PLAYABLE_CONTROLLER.md`
4. `04_SERVER_COMBAT_AND_ONE_WEAPON.md`
5. `05_RAID_LOOT_EXTRACTION_LOOP.md`
6. **Either** `06_PERSISTENT_INVENTORY_AND_GEAR_LOSS.md` **or** two smaller calls `06A_PERSISTENT_PROFILE_FOUNDATION_SPLIT.md` then `06B_EXTRACT_SETTLEMENT_AND_LOSS_SPLIT.md`. Never run combined 06 and its split versions, as that duplicates work.
7. STOP, test M1 personally, send one focused fix prompt if needed.
8. `07_BODYCAM_CAMERA_AND_ORIGINAL_HUD.md`
9. `08_BLENDER_ART_BATCH_AND_MAP_IDENTITY.md`
10. `09_COMPLETE_CONTROLS_AND_INVENTORY_UX.md`
11. `10_AI_AND_ENCOUNTER_DESIGN.md`
12. `11_WEAPON_FEEL_ANIMATION_AND_SOUND.md`
13. `12_ARMOR_HEALING_AND_INVENTORY_DEPTH.md`
14. `13_TRADERS_TASKS_AND_SAFEHOUSE_PROGRESSION.md`
15. `14_OPTIONAL_MULTI_PLACE_MATCHMAKING.md` OPTIONAL (large token cost; prefer defer).
16. `15_MOBILE_CONSOLE_PERFORMANCE_PASS.md`
17. `16_MULTIPLAYER_QA_EXPLOIT_REGRESSION.md`
18. `17_RELEASE_HANDOFF_AND_SAFETY_AUDIT.md`

For a new session, `99_COMPACT_RESUME.md` is a short context-efficient resume. For bugs, `98_FOCUSED_BUGFIX.md` avoids restarting a whole implementation stage. If Claude lacks access to your project folder, ensure Claude Code was started with the extracted folder open and tool permissions are available.
