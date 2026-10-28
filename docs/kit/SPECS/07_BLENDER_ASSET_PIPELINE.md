# Original Blender low-poly asset workflow

## Art rules
Build an original coastal industrial quarantine setting. Should read as independent indie FPS, not default Roblox. All hero meshes authored in Blender (Blender bridge or documented `bpy` scripts). Parts may still be used for collision planes, blockout and invisible triggers. No Toolbox free-model dumps or ripped Tarkov/BODYCAM models/textures.

## M1 asset manifest and batching
Batch A: one shipping container, steel catwalk segment, pipe elbow, barrel, light pole, fence segment, industrial door, crate, locker, extraction beacon. Batch B: R-17 fictional rifle, right+left gloved FPS hands, patrol guard silhouette, canvas bag, med pouch, 2 loot pickups. Don't generate more than 5 assets per Claude tool iteration; inspect import/scale/materials between batches.

## Modeling budgets (initial hypotheses, change after device profiling)
| Asset | Approx triangles | Materials | Texture |
|---|---:|---:|---:|
| barrel/crate | 80–300 | 1 | 128–256 atlas |
| container/door | 150–600 | 1 | 256–512 atlas |
| hero rifle viewmodel | 1,500–3,000 | 1–2 | 512 atlas |
| third person guard | 1,500–3,500 | 1–2 | 512 atlas |
| fence/catwalk | 100–350 per modular piece | 1 | atlas |

These are design targets, not official Roblox limits. Maximize silhouettes and reusable texture atlas; reduce texture memory and part counts; MeshParts can use simple/block collision for static props. Avoid creating hundreds of physics-enabled tiny parts.

## Pipeline
1. Build in Blender with names `ZR_[category]_[assetname]_LOD0`. Apply transforms and verify dimensions against Roblox calibration cube.
2. Use intentional topology, UVs and atlas. Create `blender_sources/*.blend` or scriptable `.py` files, export `.fbx` or `.gltf`, create thumbnails via Blender rendering only if actually available. Build `ASSETS/IMPORT_MANIFEST.csv`.
3. Import via Roblox Studio 3D Importer or verified Studio bridge. Validate orientation/up axis, pivot, scaling, colors and collision; verify actual MeshPart instances and their IDs. Do not rely on imagined plugin import methods.
4. Keep exported assets in repo and original Blender source; manifest contains asset keys, dimensions, triangle counts, materials, texture sizes, export path, import status, Roblox IDs when confirmed.
5. Reuse props modularly, instance them instead of unique per scene meshes. Design lighting and collision separately from render meshes.
6. Make first-person hands independent from the world rig for controlled animation; never use visible Roblox default avatar arms over the custom viewmodel.

## Map environment
`Quay 7`: cold misty morning, overcast industrial shipping pier, teal-sea haze and warm rust, silhouettes of gantry cranes, breakwater and aerial cables. Three distinct POIs: `Harbor Stack`, `Pump Annex`, `Freight Depot`. Add shipping lane/warehouse flank routes, elevation changes, cover rhythm, consistent traversal width and uncluttered sightlines. No copies of Tarkov Customs/Factory/etc.

## Audio
Quiet wind and moored metal creaks, layered footfalls by material, compact indoor reverb, distinctive but not overwhelming firearm transients, positional AI shouts abstract/non-gory. Use original or properly licensed Creator Store sounds; confirm license and asset access. Sound design should carry threat even in low graphics setting.

## Recommended Blender tasks for Claude
- Programmatically create first calibration cube; inspect dimensions and screenshots from scene if tool returns them.
- Generate 1 asset batch and export; verify importer round trip before scene bulk.
- Author distinctive custom rifle and guards with no branded geometry; document rig and part attachments.
- Validate mesh count, material count, triangle count, asset packaging and rendering before proceeding.
