# Next Task

**Current focus:** improvement program milestone **M6 — Movement & realistic animation** (owner asked for real-player movement and Tarkov mechanics; work continues milestone to milestone without stopping).

## M6 plan

1. **Custom operator rig (non-Roblox look).**
   - Roblox now builds avatars with `AnimationConstraint` joints, and the default dynamic head shows a face.
   - Build our own R15-named rig (Motor6D joints, human proportions, balaclava head, gloves, boots) as `StarterPlayer.StarterCharacter` at server start; AI uses the same rig.
   - Blender: segment meshes for the body; part-built fallback when meshes are missing.
2. **Procedural full-body animator** (players and AI): walk/run/crouch/prone cycles from velocity, aim pitch, lean, weapon held by two-bone arm IK at the shared weapon anchors, reload/draw/melee gestures from replicated attributes, distance LOD.
3. **Movement (client Movement.luau + server validation):** lean Q/E (camera + hitbox), prone Z, walk-speed scroll, crouch depth, leg/arm stamina, weight and overweight penalties, inertia, vault/mantle, free look (Alt), fall damage (done in Health), footsteps.
4. Verify with the `orbit` dev camera, two-character scenes and screenshots; commit M6.

Then M7 (multiplayer raids), M8 (AI), M9 (economy), M10 (world/art/audio), M11 (QA + docs).

## Resume steps

1. Read `DEVELOPMENT_STATUS.md` and `KNOWN_ISSUES.md`.
2. Start `rojo serve --port 34873` in `Documents\EscapeFromBloxov`; connect the Rojo plugin in Place3.
3. Play, then run `ZR_Dev:Invoke("tests")` (baseline **82/82**).
