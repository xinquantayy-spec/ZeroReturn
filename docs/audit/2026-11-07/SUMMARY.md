# Zero Return audit, 7 November 2026

The owner's input on these choices is collected in the interactive report **Zero Return Audit** (https://claude.ai/artifact/WmgDqevdd2j53hAHfDzxGA). To read it back, use ArtifactData `list` on collection `choices` (documents `<decision id>` with `opt` and `note`) and `get` on `meta/general` (`note`, `useRecs`: open cards take the recommendation, `ready`). **Nothing is implemented until the owner marks it ready.** The full research is in the repo at `docs/audit/2026-11-07/` (one report per area).

Headline findings:
- P0: a fresh server can break its first players' clients, because the client waits 30 s and the server builds four maps first. Seen in Studio on 7 Nov.
- P0: saving has never run on a real DataStore, and a live server falls back silently to memory.
- P0: the 30 FPS phone floor is unmeasured, and phones start at HIGH.
- P0: the menus don't fit a phone (computed from the layout code).
- Studio on the T490 at quality 2: 48-60 fps on Border Yard, 57-60 in the mall; one server holds 50,760 parts.
- Big gaps from Tarkov: block bodies about twice human width with cartoon faces; 2 of 13 maps; 279 items and 13 tasks; recoil without convergence; pre-0.14 armour; no sound occlusion (Roblox's Acoustic Simulation now allows it); AI sight a third of EFT's; no AI voices.

Decisions (★ marks my recommendation):

**Start here: direction and order**
- `start-1` What to work on first: ★ a) Release blockers first; b) The look first; c) Content first; d) Gameplay depth first
- `start-2` The quick wins: ★ a) Do them all; b) Only where I've chosen; c) I'll pick
- `start-3` How strictly to copy Tarkov's harshness: a) Tarkov-hard everywhere; ★ b) Tarkov rules, optional aids; c) Softer by default

**Performance, saving and release**
- `tech-1` Release staging: a) Stay unpublished; ★ b) Private test place now; c) Private now, public soft launch later; d) Public now
- `tech-2` Baseline phone and how to measure it: a) Your own phone; ★ b) Buy one budget Android; c) Testers' phones; d) Wait for analytics
- `tech-3` Default graphics level on phones: a) Keep HIGH everywhere; ★ b) Phones start at LOW; c) First-launch benchmark; d) Keep HIGH, two-way auto
- `tech-4` How maps are built and hosted: a) Keep it; ★ b) Leaner runtime build; c) Bake maps, then turn on SLIM; d) Lobby place plus one place per map
- `tech-5` How far the world streams: a) 1,024 studs (default); ★ b) 768 studs; c) 512 studs; d) A radius per map
- `tech-6` How to stop movement cheats: ★ a) Harden what we have; b) Roblox Server Authority; c) Leave it until after launch
- `tech-7` Disconnects and server shutdowns mid-raid: a) Keep the loss; b) Reconnect window; c) Refund on server shutdown; ★ d) Both b and c
- `tech-8` Code quality gate: a) Keep as is; b) Lint and type check on the laptop; ★ c) b plus automatic test runs

**Gameplay, combat and sound**
- `gameplay-1` Recoil model: ★ a) Tarkov model; b) Plateau and partial return; c) Keep and tune
- `gameplay-2` Armour system: ★ a) Full plate system; b) Zones and curves only; c) Keep, fix helmets
- `gameplay-3` Sound occlusion: ★ a) Acoustic Simulation; b) Scripted occlusion; c) Keep
- `gameplay-4` Health and meds depth: a) Full layer; ★ b) Core set; c) Numbers only
- `gameplay-5` Movement and handling extras: a) All of them; ★ b) High-value set; c) None now
- `gameplay-6` Real-time waits: a) Tarkov's times; ★ b) Tarkov's rules, scaled times; c) Keep
- `gameplay-7` Raid instances: ★ a) A server per raid; b) Shorter wait; c) Keep

**NPCs and AI**
- `ai-1` Who populates the two Tarkov-layout maps: ★ a) EFT roster; b) Scav-aligned Watch; c) Keep
- `ai-2` AI count and how to pay for it on a Roblox server: a) Bosses outside the cap; ★ b) EFT caps with sleep; c) Scale with players
- `ai-3` EFT's numbers for AI senses and aim: ★ a) Port EFT's numbers; b) Scale and patch; c) Keep ours
- `ai-4` AI voice lines and call-outs: ★ a) Recorded packs; b) Roblox text-to-speech; c) Wordless cues
- `ai-5` Boss-only weapons: a) All five; ★ b) The two that change the fight; c) Tuned stand-ins
- `ai-6` PvE mode with AI PMCs: a) Not now; ★ b) EFT-style PvE servers; c) Bot backfill in PvP
- `ai-7` Player scav entry time and spawn points: ★ a) EFT window; b) EFT window, cross-server; c) Spawn points only
- `ai-8` AI looting: ★ a) EFT rules; b) Loot, softened; c) No looting

**Loot, economy and progression**
- `economy-1` Item catalogue size: ★ a) Core set, about 600; b) Mid set, about 1,200; c) Full mirror, 3,000+; d) Keep about 280
- `economy-2` Trader roster and currencies: ★ a) EFT's eight, one currency; b) EFT's eight plus three currencies; c) Keep four, deepen them
- `economy-3` Flea market model: ★ a) Real market with an AI floor; b) Hybrid; c) Rules only
- `economy-4` Progression pacing: a) EFT exact; ★ b) EFT curves, faster clocks; c) Current pace
- `economy-5` Wipes, seasons and modes: a) Permanent profile, no wipes; ★ b) Permanent plus an opt-in season; c) Scheduled full wipes; d) Add a PvE profile
- `economy-6` Task content: ★ a) Map-first core, about 120; b) EFT's full tree, about 500; c) Small story and dailies
- `economy-7` Hideout scope: a) Full EFT set; ★ b) Economy core, about 14; c) Add two
- `economy-8` Monetisation options (owner approval required): ★ a) None for now; b) Cosmetics only; c) EFT-style editions; d) Private servers and a free pass

**HUD, screens and controls**
- `ui-1` In-raid health and stamina display: ★ a) EFT's model; b) Numbers that auto-hide; c) Keep as is
- `ui-2` Bodycam overlay strength on the HUD: a) Keep the full overlay everywhere; ★ b) A clean default; c) By device
- `ui-3` Menus on a 390-pt phone: ★ a) Compact phone layouts; b) Keep the layouts, fix the worst
- `ui-4` Moving items on touch: a) Touch drag and drop; b) Improve tap-and-place; ★ c) Both
- `ui-5` Onboarding for new players: ★ a) EFT 1.0-style tutorial raid; b) Bunker boot camp; c) Hints only; d) None
- `ui-6` Opening screens outside the walk-around bunker: ★ a) EFT's menu bar; b) PC hotkeys only; c) Walk-only
- `ui-7` Chat in raids: ★ a) Squad channel only; b) No text chat in raid; c) a plus proximity voice; d) Leave as is
- `ui-8` Accessibility settings: ★ a) Colour-blind palettes, menu text size and hints; b) Palettes only; c) Nothing beyond HUD SCALE

**Art, maps and models**
- `art-1` Original-layout maps (Quay 7, Smelter, Pinewatch): ★ a) Re-base on Tarkov; b) Keep as originals; c) Retire now
- `art-2` Order of the missing Tarkov maps: a) Small maps first; b) Big outdoor maps first; c) Mixed sizes; ★ d) Performance base first
- `art-3` Character body proportions: a) Keep the block body; ★ b) Human-proportioned rigid body; c) Realistic skinned character
- `art-4` Texture pipeline for hero assets: a) Stay vertex-coloured; ★ b) Hybrid; c) PBR everywhere
- `art-5` Building and interior fidelity: a) Trim pass; ★ b) Modular Blender kit; c) Kit plus hand-dressed rooms
- `art-6` First-person weapon animation: ★ a) Extend the code-made poses; b) Keyframed per weapon class; c) Keep as is
- `art-7` Blood on hits: ★ a) Light realistic blood; b) No realistic blood; c) Heavy realistic blood
- `art-8` Readability aids Tarkov does not have: a) Tarkov-hard; ★ b) Middle; c) Keep both
