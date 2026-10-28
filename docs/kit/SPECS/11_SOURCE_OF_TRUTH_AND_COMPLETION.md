# Definition of done / evidence

## Meaning of completion
- `WRITTEN`: source exists, hasn't been built.
- `BUILT`: Rojo build succeeded, not necessarily playable.
- `STUDIO VERIFIED`: launched in Studio and one realistic flow observed with exact evidence.
- `MULTICLIENT VERIFIED`: Studio 2+ clients exercised combat/loot/extract concurrently.
- `DEVICE VERIFIED`: real named handset/controller tested with FPS/memory + screenshot/log.
- `CONSOLE VERIFIED`: physical supported console tested; controller emulator alone does not count.

Claude must use these exact labels for progress reports. No 'finished mobile compatibility' after just building input scripts.

## M1 release gate
1. Loading profile and stash: no lost starter items.
2. Deploy enters active raid, consumes/reserves chosen gear.
3. Server-validated shoot/reload/AI kill, simple local animation.
4. Search loot container, claim item, move item to bag. No duplicate on rapid action.
5. Extract inside a zone + countdown. Success credits only confirmed loot; KIA/MIA/disconnect doesn't credit.
6. Post raid displays accurate retained/lost and can re-equip.
7. Two clients can join, shoot each other or AI with correct damage and inventory isolation.
8. A gamepad can choose/deploy/interact/loot/extract/menu; phone simulator controls work; real hardware tests explicitly pending if not performed.
9. At least 1 Blender mesh was imported and verified as actual MeshPart; source and asset path recorded.
10. No output errors, no catastrophic frame stutters on owner-provided baseline.

## Evidence template
For each stage include exact files, `rojo build` result, Studio test mode, clients, pass/fail of manual tests, link/path to any existing screenshot if tool actually produced it, device identity/metrics if measured, remaining blockers. Do not claim a screenshot exists when it does not.
