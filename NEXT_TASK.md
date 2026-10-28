# Next Task

**Current focus:** Phase D, verification depth. Do these in order and stop at any step marked [owner].

1. **Two-client test.** Use Studio's Test → Clients and Servers with 2 players.
   - Both players deploy into the shared world.
   - Contest the same container: exactly one copy should exist.
   - Player-vs-player hit: damage validated and kill credited.
   - Both players extract.
   - Check that profiles stay separate.
2. **Device emulator pass.**
   - Phone (portrait-safe landscape) and tablet: touch cluster, HUD legibility, modal fit inside safe insets.
   - Console 1080p: gamepad selection in the inventory, deploy and summary screens.
   - Record screenshots.
3. **Performance snapshot.**
   - In a 2-minute raid, record part and instance counts, script activity (AI think time) and client effect caps.
   - Log the numbers in `TEST_RESULTS.md`.
4. **[owner] Real persistence.**
   - The owner saves the place as a private Roblox place and enables Studio API access.
   - Then re-run the rejoin, failWrites and crash-recovery probes against `DEV_ZR_Profiles_v1`.
5. **Impact sound effect.**
   - Synthesise `ZR_SFX_Impact` (concrete and metal).
   - Upload it (1 of the remaining audio quota) and wire it into `Effects.impact`.

**After that, Phase E** (one feature per session):

- armour and helmet protection classes
- a second weapon (pistol)
- traders and tasks in the safehouse
- a second guard archetype
- extending Quay 7

**Resume steps:**

1. Read `DEVELOPMENT_STATUS.md` and `KNOWN_ISSUES.md`.
2. Start `rojo serve --port 34873`.
3. Run `ZR_Dev:Invoke("tests")` to get the 38/38 baseline.
