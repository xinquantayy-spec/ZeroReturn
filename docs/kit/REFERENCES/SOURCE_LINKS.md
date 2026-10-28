# Research sources and reference shots (checked 2026-10-28)

This is a curation list, not an asset download list. **Open references in a browser; do not scrape, embed, copy UI art, or distribute third-party images/videos**. Source copyrights remain with rights holders. If a link changes, search official source and record replacement.

## Primary design references
1. **Escape from Tarkov — official Steam product page**: https://store.steampowered.com/app/3932890/Escape_from_Tarkov/ — high-stakes raid preparation, PvPvE, extract or lose. Steam lists a full release dated **November 15, 2025** as of research; don't build around exact game version changes.
2. **Unity developer showcase — Escape from Tarkov**: https://unity.com/made-with-unity/escape-from-tarkov — systems overview of weapon condition, status effects, AI Scavs, inventory and loss/retention. This makes the mechanics intelligible without reverse engineering or asset extraction.
3. **Escape from Tarkov community gameplay guide**: https://escapefromtarkov.fandom.com/wiki/How_to_Play_Guide_for_Escape_from_Tarkov — conditional extracts; source is a community wiki, may not reflect latest rules, use only as conceptual reference.
4. **BODYCAM official Steam page**: https://store.steampowered.com/app/2406770/Bodycam/ — character/camera movement, subdued HUD, body-mounted footage, weighty movement and immersive sound. Do NOT try to match Unreal Engine photorealism on Roblox.

## Art research visual links
- Tarkov inventory/stash inspiration (third-party illustrative image, do not download into game): https://regmedia.co.uk/2020/02/27/tarkov1.jpg
  **Observe only:** equipment slots, grid spatial logic and high density. **Adapt:** spacious phone-friendly view, no copied iconography, fictional labels.
- BODYCAM in-match screenshot (third-party illustrative image, do not redistribute): https://gaming-cdn.com/images/products/15713/screenshot/bodycam-pc-spel-steam-wallpaper-2.jpg?v=1718294361
  **Observe only:** first-person framing, small corner overlays, tactile body movement, sound-led tension. **Adapt:** no green rectangle target box, unique timestamp/system graphics, lower resolution original asset style.
- Original kit mockup: `BODYCAM_HUD_MOCKUP.png` — safe to use as working UI concept, built from scratch.
- Use official game Steam pages' own trailers as visual research, not assets for import. Roblox asset uploader requires rights to audio/models/images.

## Roblox Creator Hub platform docs
- Cross-platform: https://create.roblox.com/docs/projects/cross-platform
- Input Action System: https://create.roblox.com/docs/input/input-action-system
- PreferredInput, hardware switching: https://create.roblox.com/docs/input
- Gamepads: https://create.roblox.com/docs/input/gamepad
- Touch: https://create.roblox.com/docs/input/mobile
- Camera/ui constraints: https://create.roblox.com/docs/ui
- Studio device/controller/network testing: https://create.roblox.com/docs/studio/testing-modes
- Real-device performance: https://create.roblox.com/docs/performance-optimization/test-on-hardware
- Performance budgets: https://create.roblox.com/docs/performance-optimization/design
- Streaming and asset optimization: https://create.roblox.com/docs/performance-optimization/improve
- Server authority (feature availability/version must be verified): https://create.roblox.com/docs/projects/server-authority
- Securing remote calls/shots: https://create.roblox.com/docs/scripting/security/client-server-boundary
- Network ownership hazards: https://create.roblox.com/docs/physics/network-ownership
- DataStore best practices: https://create.roblox.com/docs/cloud-services/data-stores/best-practices
- Session locking example: https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing
- Mesh import from Blender: https://create.roblox.com/docs/art/blender
- Studio 3D importer: https://create.roblox.com/docs/studio/importer
- Rojo in Roblox toolchain: https://create.roblox.com/docs/projects/external-tools
- Rojo project mapping v7: https://rojo.space/docs/v7/project-format/
- Content maturity, violent content and regions: https://create.roblox.com/docs/production/promotion/content-maturity
- Audio ownership and import: https://create.roblox.com/docs/audio/assets

## Current Roblox competitive landscape (2026-10-28)
- [Extraction Raiders](https://www.roblox.com/games/110398021993835/Extraction-Raiders): PvPvE deploy/loot/extract, already states phone/tablet/Xbox/PlayStation support.
- [Blight Grab](https://www.roblox.com/games/95665217895534/Blight-Grab): loot/fight/extract, rarity, PvP and console/mobile controls.
- [Project Delta](https://www.roblox.com/games/7336302630/Project-Delta): stylized realism, tactical scavenging and persistent systems.
- [State of Anarchy](https://www.roblox.com/games/2000062521/State-of-Anarchy): explicit stash and loadout extraction game.
- [Hypercam](https://www.roblox.com/games/18497073993/Hypercam): bodycam-inspired tactical shooter, cross-platform.
- [Blackhawk Rescue Mission 5](https://www.roblox.com/games/2916899287/Blackhawk-Rescue-Mission-5): broad tactical FPS/sandbox features.

**Implication:** "Escape from Tarkov but on Roblox" is not sufficiently differentiated. Win through a superior coherent industrial mini-world, credible item risk with short quick-raids, intuitive controller/touch inventory, original recording-system HUD, excellent sound and smooth low-end phone performance—not by competing on total gun count.

## Research caveat
Sources are public docs/reference pages and illustrate design direction. Exact current Roblox API availability, creator account asset rights and console distribution prerequisites must be verified by Claude Code on the user's installed tools and in Roblox Creator Hub at implementation time. Sources are not a substitute for actual Studio/hardware testing.
