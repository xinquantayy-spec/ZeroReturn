# Bodycam-inspired visual identity and first-person UI

## Creative guardrails
Inspired by camera-recording footage and low-resolution indie visuals; do not recreate BODYCAM's layout pixel-for-pixel, copyrighted art or its proprietary filter. Roblox isn't Unreal Engine: simulate atmosphere via deliberately authored geometry, restrained grading and lightweight overlays, not screen-space raytracing or expensive full-screen fragment shaders. Name the game's original camera device `FIELD RECORDER M4`.

## Rendering art bible
- Palette: gunmetal #33383B, asphalt #555A56, sand #B1A893, sea mist #96A4A2, rust #8A6252, safety orange #C07946, pale UI #D6DBC9.
- Geometry: angular industrial forms, bevels and chipped silhouette changes, rich composition (pipes, cables, drains, vent grilles), almost no neon. Differentiated POIs by silhouette and ambient color.
- Texture: 128px or 256px per small prop, 512px major/hero elements; pixel-readable details, atlased UVs, subtle color variation, no complex PBR on low-end. Low res means deliberate texture choices, not unlegible smears.
- Lighting: baked-looking fake bounce using strategically placed area aesthetics, engine lighting modest shadows, color correction subtle. Avoid point lights on every prop, giant particles/fog, volumetric effects and frequent dynamic shadows.
- Character: custom R15-compatible silhouette or alternate custom rig; narrow shoulders, helmet/soft hood, simple webbing and mitt-like gloved hands; not standard avatar face/hair proportions. Camera collision invisible on body; local viewmodel only for the owner, third-person body for other players.
- Small ambient life: moving cable or fog bank, distant gull audio, blinking signal lamp, not constant VFX.

## Camera setup
Use first-person only in raid; safehouse first/third-person optional. Normalized Roblox FOV target 72–78, optional slider 65–90; keep wide-angle impression with mild edge vignette and slightly offset mount pose. No true barrel distortion unless an efficient verified platform method exists. Camera offset/roll are bounded; avoid per-frame post-processing recreation. FPS hands/weapon lag small, reload movement smooth. ADS narrows to 58–65 (tunable) but never changes actual competitive aiming rules unfairly across platforms.

## HUD layout
- TOP LEFT: `CH.04 | 2026.10.28 12:42:09` fictional configurable timestamp; `REC` amber; small battery/signal icon; do not use real police agency logos.
- TOP RIGHT: compact extraction status `QUAY 7 / EXIT A` / raid clock; optional latency.
- LOWER LEFT: slim health silhouette segments (simple at M1), stamina, small bleeding warning only when relevant.
- LOWER RIGHT: 25 / 125 ammo, fire mode, current tool; tiny weapon pictogram.
- CENTER: nearly no crosshair in hipfire or configurable subtle dot; center interact prompt appears only near valid entity.
- Extraction: when inside trigger, compact radio signal + progress bar and audible countdown cue; no huge green Roblox circle.
- Post-raid: diegetic dossier panel with retained/lost inventory, clear navigation, never force tiny drag operations on touch.

## UX scaling
Design constraints and padding; Roblox screen insets, safe zones, dynamic anchoring, UIAspectRatioConstraint where appropriate. Mobile buttons on ergonomic right edge, not covering main reticle; left stick/hud; landscape orientation, tablets have dedicated layout. Console TV-safe margins, readable font at distance, logical `Selectable` focus and selection/cancel/back behavior. Touch UI context actions provide equip/inspect/split/transfer without drag necessity. Never rely on hover or right click only.

## Effects quality ladder
**Low:** static subtle vignette corners if cheap, no film noise/grain/blur, no camera tilt sway except a tiny setting, no extra lights, reduce particle emissions; highest legibility.
**Medium:** optional weak grain texture with very slow change (<=3fps) and slight color correction, no flicker.
**High:** slight lens-edge chromatic hint IF implementable with supported performant Roblox features; avoid promising true shader-based chromatic aberration; optional dust motes and enhanced audio reverb.
`Reduce Motion`, `Disable Film`, `Screen Shake 0–100`, `FOV`, `Sensitivity`, `Aim Assist` settings persist. HUD never obscures target in a gunfight. Aesthetic must survive all effects off.

## Original mockup
`REFERENCES/BODYCAM_HUD_MOCKUP.png` conveys approximate placement and palette. It is a schematic design target; Claude must construct with real Roblox GUI objects, not import a whole flat UI screenshot.
