# STAGE 08: Blender art batch and map identity

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 08 of ZERO RETURN, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/07_BLENDER_ASSET_PIPELINE.md`, `ASSETS/IMPORT_MANIFEST.csv`, `SPECS/09_PERFORMANCE_BUDGET.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Turn placeholder blocks and default rigs into unique low-poly industrial assets, imported successfully via Blender/Studio.

### Tasks to execute
1. Inspect connected Blender and Studio import tool schema, calibration cube first; verify units and orientation with an actual mesh round-trip.
2. Create small **Batch A** original modules: container, crate, barrel, door, light pole. Export FBX/glTF and verify mesh pivots/materials/physical scale in Studio; update manifest with actual asset references and source paths.
3. Create **Batch B**: R-17 weapon viewmodel and separate guard silhouette. Include UV atlas and proper viewmodel attachments; rig only where actually needed.
4. Replace greybox visuals in one POI, preserving collision and extraction markers. Build signature industrial silhouettes, rust/pale concrete palette and subtle detail without all-over grain.
5. Report triangle draw/texture estimates; inspect Studio screenshot and 5 min test on available simulator. Do not create an entire city or batch 100 assets blindly.

### Definition of done and tests
- At least 5 custom Blender MeshParts visible correctly in Studio, with reliable source/export/asset IDs.
- No copied game assets or default Roblox mannequin in first-person.
- Map remains fully playable, extraction triggers preserved, build passes.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
