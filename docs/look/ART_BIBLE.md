# Zero Return art bible

One page for anyone making art for Zero Return: models, materials, maps and effects. Written 2026-11-08 from the audit's
art report (`docs/audit/2026-11-07/art.md`), the owner's picks, `docs/look/*.md`, `docs/PIPELINE.md` and the colour tables
in the code. Where the kit's early brief (`docs/kit/REFERENCES/VISUAL_ART_DIRECTION.md`) disagrees, this page wins. These
are the rules for new work; how far today's assets are from them is in `docs/design/EFT_PARITY.md`, section 11.

## The aim

Tarkov's look, less the project's exceptions: real places in northwestern Russia (Tarkov is set in the fictional Norvinsk
region there), worn, cold and lived in, at real scale (3.125 studs = 1 m). The feel of each place is copied; every model,
texture, icon, font and name is ours. No Battlestate art, no real brands, no photos: textures are procedural or made by us.

Two of the owner's choices sit on top (exception 2):
- **BODYCAM.** An 85° view, the lens edge, grain, auto-exposure and the STBY/REC recorder overlay. The camera adds the grain
  and the lens; the world under it stays clean and real. Its night lift is to be halved (art-8b) so goggles and lights matter.
- **The block body** (art-3a). Players and AI keep `ZR_BLOCK_R15_V1`. A character looks real through its gear, materials and
  colours, never by changing the body's shape. Guns in third person stay 1.35x to fit the hands.

## Palette

| World (the kit's cards) | Hex | Used for |
|---|---|---|
| Gunmetal | `#33383B` | metal, guns, dark gear |
| Wet concrete | `#555A56` | concrete, asphalt |
| Dust | `#B1A893` | dust, dry grass, sand, bare plaster |
| Sea mist | `#96A4A2` | haze, painted steel, distance |
| Oxidation | `#8A6252` | rust, old brick |
| Faded warning | `#C07946` | safety paint, signs |

- **Air and light** (`World.luau`): ambient `#3A3F40`, outdoor ambient `#7A8382`, atmosphere `#A9B4B1` with decay `#5D6A69`
  (haze 2.4), clouds `#C7CDCB`; the grade takes saturation down 0.22 and contrast up 0.08 under a `#ECEFE8` tint.
- **Interiors** (`docs/look/WALLS.md`): one hue per room from pale green, pale blue, beige, cream, dusty pink, ochre and light
  grey, at brightness 0.4 to 0.75; dorm corridors two-tone, gloss paint below and whitewash above.
- **UI** (`UiKit.luau`): background `#101314`, panels `#1B1F21` and `#252A2C`, text `#D6DBC9`, dim `#8C948D`, accent ochre
  `#C9A13C`, warning `#C07946`, danger `#C24A35`, good `#93A57C`.
- **Rules:** colours are muted and dirtied. Only small signals are bright: warning paint, armbands, the Foreman's high-vis.
  Shop goods and props are pulled toward the palette with a grime gradient (art.6). Gear stays olive, khaki, tan, black or grey.

## Texture density

- **Surfaces** (walls, floors, ceilings, roads): Roblox materials and our MaterialVariants (colour 1024 px; normal, roughness
  and metalness 512), tiled by studs. Today 320 to 680 px a metre (a 1024 tile over 1.5 to 3.2 m). Keep new variants in that
  band, in near-neutral colour so `Part.Color` tints them.
- **Bulk props and building modules** (art-5b): no UVs and no textures of their own. Split them by material, bake colour and
  ambient occlusion into vertex colours, and the material tiles on top at the walls' density (measured, `docs/PIPELINE.md`).
- **Hero assets** (art-4b): first-person guns and attachments, worn gear, items seen up close. One UV set and a baked PBR set
  (colour, normal, roughness, metalness) of 512 or 1024 px a model, Roblox's maximum being 1024. Aim at about 1,000 px a
  metre on the gun in first person and 500 to 1,000 on gear and items.
- **Wear:** one wear strip along a facade rather than a decal per wall part (art.7); scratches, dents and chips rather than
  noisy textures (owner, KNOWN_ISSUES 62); grime only where it gathers: corners, wall feet, doorways, round machines.

## Triangle budgets

"Today" is measured (`assets/exports/*.meta.json`, the audit). The budgets are ours: starting points to check on the measured
low-end phone (tech-2b). Roblox allows 20,000 triangles a mesh.

| Asset class | Today | Budget |
|---|---|---|
| First-person gun, whole build | KS-7 preset 3,378 in 13 meshes; parts 128 to 1,544 | up to 8,000; a part up to 2,500 |
| Character body | block body 3,880 | as it is (art-3a) |
| Worn gear | about 400 a piece (33 gear meshes 13,242; 16 eyewear 6,300) | up to 1,500 a piece; body and full kit under 12,000 |
| Loose item and INSPECT model | 44 to 2,392, about 470 on average | small 300, large 1,500 |
| Kit prop | 72 to 2,900; a stocked gondola 7,326 | small 80 to 600, large up to 3,000; repeated dressing low (half the gondola, art.8) |
| Tree crown | 1,050 to 1,260 (alpha cards) | under 1,500 |
| Building module (art-5b) | none yet | set after the first batch is measured |
| Whole view on the low-end phone | a wide Border view: 1,072 draw calls | under 700 draw calls and 700k triangles at 30 fps (`docs/kit/SPECS/09_PERFORMANCE_BUDGET.md`) |

Also: at most 4 shadow-casting lights in view; indoor props cast no sun shadows.

## Light and sky

Lighting engine settings (art.1, decided 2026-11-08, in `default.project.json`):
- `LightingStyle = Soft`, kept. The BODYCAM grade (Atmosphere, ColorCorrection, bloom, auto-exposure) was tuned and
  approved under Soft. `Realistic` is closer to Tarkov's hard sun shadows, but it needs a side-by-side in Edit mode on the
  PC before it replaces the approved look; switching it at runtime hung Studio for seven hours on 2026-11-08.
- `PrioritizeLightingQuality = false`. Low-end devices keep their view distance and lose shadow detail first. Border
  Yard and Meridian are long-sightline maps, and Tarkov players lower shadows long before visibility.
- Not done: the device emulator check of the shadow-casting lamps (it needs Studio's emulator panel, a click the owner
  makes).

Skies are an original hazy set, clear, overcast and night, switched with the weather under the cloud layer (art.2;
`src/shared/Sky.luau`, built and checked 2026-11-08: clear at noon, overcast in rain). No exit markers in
the world: exits are learned and read from landmarks (art-8b). Blood stays light: small marks on walls, floors and bodies
(art-7a).

## Reference boards

Written boards of the real-world look to match. Gather your own photos of real places like these, never Battlestate images.

- **Border Yard (our Customs).** A late-Soviet customs terminal and industrial estate on a river in northwestern Russia,
  autumn by default (seasons follow the calendar). Two- and three-storey dormitory blocks of brick and precast panels; a
  roadside fuel stop; long corrugated warehouses; a red-brick works; a half-built concrete frame; concrete
  fences under wire; rail sidings with freight wagons; a road bridge; birch and pine tree lines; pylons. Light: low, flat,
  overcast; wet ground. Colours: grey concrete, faded green and ochre paint, rust, brown grass, red brick. Inside: chipped
  gloss paint, patterned wallpaper, tiled washrooms, rooms looted and stripped.
- **Meridian Mall (our Interchange).** A big out-of-town shopping centre of the 2000s at a motorway junction: a long, low box
  with three anchor halls (our NESTA, BOLTWORKS and KASSA), two levels of small shops round domed atria, escalators, a food
  court, a car park under the building and loading docks. Outside: empty car parks under tall lamp masts, overpasses and
  road signs, a substation, an emergency camp of tents and vehicles. Light: dead fluorescent grids, emergency lamps,
  daylight from the skylights; with the power on, cold white tubes and lit shop signs. Colours: terrazzo, white and grey
  cladding, shop colours faded under dust. A sudden evacuation: tipped trolleys, spilled shelves, shutters half down. Our
  own shop names and logos only.
- **Smelter (our Factory, once art-1a rebuilds it).** The inside of a Soviet industrial plant (Tarkov's Factory is a chemical
  works; ours keeps Smelter's furnaces and casting shed): tall dark halls, rusted pipes and tanks, catwalks and gantries, a three-storey office and locker block, tunnels and a basement, gates out to small yards.
  Light: little; shafts from high windows and a few working lamps, black at night. Colours: black-brown steel, rust, oily
  concrete, green tiles in the washrooms, faded safety yellow. Close quarters, where every doorway is a silhouette.
- **Quay 7 (our test map; no Tarkov counterpart).** A cold northern commercial harbour: stacks of rusted shipping containers,
  concrete aprons with bollards and rails, a pump annex with turbines, a freight depot and its office, a crew dormitory and a
  relay mast on the skyline. Light: pale sea sky by day, sodium lamps at night, wet concrete. Colours: sea mist, gunmetal,
  rust, container paint faded to chalk. It keeps the kit's first look and stays the test map after art-1a.
- **Relay 7 (the lobby).** As built: a kept, not ruined, cold-war relay bunker, painted plaster with grime only where it
  gathers (`docs/maps/RELAY7_LOBBY.md`).

Sources for the setting: [Wikipedia, via Wikiwand: Escape from Tarkov](https://www.wikiwand.com/en/articles/Escape_from_Tarkov)
("the fictional Norvinsk region in northwestern Russia"); the map facts are in `docs/maps/reference/` and the audit.
