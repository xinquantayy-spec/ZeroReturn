# Item art (M13): models, inventory pictures and loose loot

Owner request (2026-10-29): every item gets a picture made in Blender, so players can see what they carry
(Tarkov's grid look), and loot lying in the world should be the real item, not a coloured block.

All the art is original: the guns are fictional designs built from generic parts, and the labels, brands and
packaging are the game's own. Nothing is traced from Tarkov's icons.

## What is in the game

- **All 124 items have a Blender model and a picture.** That covers 7 weapons (six guns and the knife),
  7 weapon mods, 5 magazines, 13 ammunition types, 4 grenades, the repair kit, 22 pieces of worn gear, 3 secure
  containers, 10 medical items, 6 food and drink items, 11 keys and keycards, 2 quest items and 33 loot items.
- **Pictures in every grid.** The stash, your pockets, rig, backpack and secure container, containers and bodies
  in a raid, and the trader screens all show the item's picture.
  - The picture fills the item's footprint (a 5×2 rifle gets a 5×2 picture) and turns with the item when you rotate it.
  - The tile behind the picture is a dark tint of the item's colour, so you can still tell categories apart at a glance.
  - An item you have not examined shows as a dark silhouette until you examine it.
  - The picture also appears when you drag an item, in the detail strip of a selected item, and next to every
    trader offer and barter.
- **Loose loot is the real model.**
  - 95 items lie in the world as their Blender model, with contact shadows baked in.
  - The 22 pieces of worn gear (helmets, headwear, headsets, gaiter, armour, rigs, packs) lie as the meshes that
    characters wear, tinted the same. Armour and rigs lie front up.
  - Guns lie as the shared weapon model, as before.
  - If a model batch has not loaded, the old block in the item's colour is used instead.

## Files

| File | Job |
|---|---|
| `assets/blender_scripts/zr_items.py` | Item builder (one mesh per material), the 18 render materials, studio light rig, camera views, icon render, atlas packing |
| `assets/blender_scripts/zr_item_reg.py` | Item registry (`@item(ID, w, h, view, margin)`), render runner with a time budget, review sheets |
| `assets/blender_scripts/build_items_a.py` | Guns, weapon mods, magazines, ammunition, grenades, repair kit |
| `assets/blender_scripts/build_items_b.py` | Worn gear (built from the character meshes in `build_char_gear.py` and helmet A in `build_char_base.py`, tinted with the colours from `Equipment.luau`) and the secure containers |
| `assets/blender_scripts/build_items_c.py` | Medical items, food and drink, keys and keycards, loot and quest items |
| `assets/blender_scripts/build_items_export.py` | Loose loot export: AO baked into the vertex colours, three FBX batches |
| `tools/item_icons.py` | Writes `src/shared/ItemIcons.luau` from `assets/renders/items/atlas.json` and the uploaded image ids |
| `tools/item_meta.py` | Writes `src/shared/ItemMeta.luau` (size, centre and pieces of every loose loot model) from the export metadata |
| `src/client/Controllers/UiKit.luau` | `K.itemIcon` (atlas picture in a tile, turned, silhouette) and `K.hasIcon` |
| `src/client/Controllers/Inventory.luau`, `Trade.luau` | The grids, drag ghost, detail strip and trader rows use the pictures |
| `src/server/Services/Loot.luau` | `placeItemModel` and `placeWearModel` build loose loot from the loaded meshes |

## How the models are made

- Items are modelled in metres and scaled by 3.125 studs per metre (the scale of the characters and weapons).
- Each item is one mesh per material, named `ZR_IT_<ITEM>__<material>`. All its meshes share one origin at the
  bottom centre, with the front facing Blender −Y.
- Colour is in vertex colours (sRGB). As with the mall kit, there are no textures and no UVs: in game each piece
  gets a Roblox material (metal, plastic, fabric, glass and so on), which tiles by studs and is shared with
  everything else.
- Detail is modelled, not painted: label bands, seams, zips, rivets, screw heads, blister cups, foil, caps,
  printed text bars, wear on edges.
- Worn gear reuses the character meshes, so a helmet in the stash is exactly the helmet on a player's head.

## Pictures

**Render.**
- Blender EEVEE with an orthographic camera and a transparent background. The image has the item's grid aspect,
  at 128 px per grid cell.
- The light is a studio product setup: four suns placed relative to the camera, the Standard view transform,
  exposure 0.55, and 32 anti-aliasing samples.
- Each item has its own camera angle (eight standard views plus one for packs): guns and magazines from the
  left with the muzzle to the left, small items at three-quarter, flat items from above, armour from the front,
  packs from behind.
- Vertex colours are sRGB, so the render materials convert them to linear (gamma 2.2) before shading. Without
  that, everything came out washed out.

**Atlas.** `pack_atlas()` scales each picture to 64 px per cell (a premultiplied box filter, so the edges stay
clean). It then packs all 124 into two 1024 × 1024 sheets with 2 px of transparent padding between pictures, and
writes `atlas.json`.

**Upload.** The sheets are uploaded through Open Cloud as Decals (`ZR_ItemIcons_0` and `_1`). The image ids are
read in Studio from each Decal, then `tools/item_icons.py` writes them into `ItemIcons.luau`.

**In game.** `K.itemIcon` puts an ImageLabel in the tile with the item's `ImageRectOffset` and `ImageRectSize`
from the sheet. A turned item gets `Rotation = 90` with its width and height swapped. An unknown item draws its
picture in a dark colour.

**Cost.** Two images hold every picture in the game. They load once, and a screen full of items is a few hundred
ImageLabels pointing at them.

## Loose loot models

- `build_items_export.py` builds the same models as the pictures, then bakes contact shading into the vertex
  colours: ambient occlusion from the item itself and from the surface it lies on, plus a light film of dust.
- It exports three batches, uploaded as Models:

  | Batch | Contents | Items | Meshes | Triangles |
  |---|---|---|---|---|
  | ZR_ItemsA | weapon mods, magazines, ammunition, grenades, repair kit, secure containers | 33 | 75 | 18,912 |
  | ZR_ItemsB | medical, food and drink, keys and keycards, the two quest items | 29 | 77 | 7,814 |
  | ZR_ItemsC | loot (electronics, valuables, tools, household, parts, intel) | 33 | 83 | 17,538 |

  An item averages about 470 triangles, so a room full of loose loot is a few thousand.
- **On the server**, `Loot.looseModel` clones the pieces. They are anchored and massless, with no collision, no
  raycast hits and no touch events, so they cost nothing in physics.
  - Each piece gets its Roblox material from the item's material key, and its colour stays white (the vertex
    colours carry it).
  - Only items larger than half a stud cast shadows, and glass never does.
  - One invisible box per item carries the TAKE prompt.
- **Worn gear** uses `Equipment.visualOf` for its slot. The meshes are placed so that the lowest corner rests on
  the surface, centred over the loot spot.

## Making them again

All of this runs in Blender on the laptop. The scripts live in `assets/blender_scripts`, which goes on `sys.path`.

1. Reload `zr_items` and `zr_item_reg`, clear `zr_item_reg.REG`, then reload `build_items_a`, `_b` and `_c`.
2. Render: `zr_item_reg.run_budget(list(REG), 45)`. Repeat until nothing is left, since the MCP call has a 60 s limit.
3. `zr_items.pack_atlas(...)` writes the sheets and `atlas.json`.
4. Upload the sheets as Decals (`zr_upload.upload_model(png, key, desc, asset_type="Decal")`). Read the image ids
   in Studio, then run `python3 tools/item_icons.py <id of sheet 0> <id of sheet 1>`.
5. For loose loot, run `build_items_export.export(name, ids)` for each of `batches()`, upload the FBX files, put
   the ids in `AssetIds.luau`, and run `python3 tools/item_meta.py`.
6. To review, `zr_item_reg.sheet(ids, png, cell=64, cols=12)` lays pictures out on a stash-like grid.

## Tests

- In Studio, `ZR_Dev:Invoke("tests")` passed LogicTests 167/167, CharTests 38/38, LookTests 19/19 and MapTests
  30/30 (in a raid).
- The console reports "605 meshes loaded, 0 batches failed": the three mall kits and the three item batches.
  Every icon resolves to a sheet: 124 of 124, with no item missing a picture.
- Checked by eye in Studio: stash and gear slots (`I01`), the trader screen (`I02`), and loose wires on a VOLTA
  shelf in the mall (`I03`). Review sheets of all 124 pictures are `I04` (weapons and ammunition), `I05` (gear),
  `I06` (medical, food and keys) and `I07` (loot).
- **Not verified:** how readable the pictures are on a phone screen, and how much memory they use on a device.

## Limits

- A modded gun shows the picture of the bare gun. Its attachments are listed in the detail strip, but they are
  not drawn on the picture.
- Pictures do not change with an item's state. A magazine's round count, a stack's size, armour durability and a
  medkit's remaining points show as text in the tile's corner.
