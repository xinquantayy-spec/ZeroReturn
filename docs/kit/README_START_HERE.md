# ESCAPE FROM BLOXOV — Claude Code production kit

**Purpose:** Build an ORIGINAL, premium-feeling PvPvE extraction shooter for Roblox, inspired by Escape from Tarkov's raid/stash/loss loop and the visual language of body-mounted camera footage. Working title **ESCAPE FROM BLOXOV** is a placeholder; check any final branding before release. This is not permission to reproduce copyrighted names, maps, weapons, logos, game UI, sound, animations, characters or assets from either reference game.

**Intended agent:** Claude Code, with your chosen Opus 5.5 Max configuration (if available to your account). This is not a Claude Cowork workflow. The ZIP is an instruction/reference kit, **not** a prebuilt game or a working Claude integration.

## Fast start (recommended)
1. Extract this ZIP to a new folder, separate from any existing Roblox project. Keep `CLAUDE.md` at its root. Back up any existing Roblox place before Claude edits it.
2. Open a terminal **in this extracted folder** and start Claude Code there (the command may be `claude` if installed). Open the connected Roblox Studio project on your machine. Do not paste all prompts at once.
3. Paste `COPY_PASTE_START.txt` into Claude Code. This is the tool audit + safety gate.
4. Follow `PROMPTS/00_*` through `PROMPTS/06_*`, **one stage at a time**, checking `STATE/PROGRESS.md` after each. Stop at milestone **M1** and PLAY it. Later proceed through 07–17.
5. If the connection exists but one action is unavailable, use `TOOLS/CONNECTOR_TROUBLESHOOTING.md`. Let Claude find installed tools before adding anything.
6. Before it can create/edit/publish assets, make sure the correct Roblox place/group and asset owner are selected. Do not put API keys or account cookies in chat or files. Never auto-publish without your confirmation.

## What will be delivered (by Claude after execution)
- Rojo-managed typed Luau source for a complete playable vertical slice; modular services, controllers, data definitions and tests.
- One handcrafted, stylized **Quay 7** industrial extraction map, custom Blender low-poly assets, original camera overlay and FPS equipment.
- Safehouse/stash -> loadout -> raid -> looting/combat -> extraction/death -> persistent stash loop.
- Keyboard/mouse, touch and gamepad actions and adaptable UI, including controller-selectable inventory.
- Server-validated damage, loot, inventory transactions, extract and persistence. Actual device profiling and user playtesting remain necessary.

## Working sequence and stop gates
| Milestone | Prompts | Required evidence |
|---|---|---|
| M0 connection + plan | 00–02 | tools verified, source backups, project compiles, design locked |
| M1 **playable proof** | 03–06 | safehouse, one raid, one weapon, one AI, containers, extract, stash, death and reconnect checks |
| M2 recognizable identity | 07–11 | bodycam camera/HUD, original Blender environment, cross-platform inputs, polished audio and animation |
| M3 deeper game | 12–15 | robust PvPvE, medicine/armor, traders/quests, recovery and optimization |
| M4 release candidate | 16–17 | automated tests, real-device signoff, asset compliance and launch checklist |

**Important:** Early prompts may contain intentionally plain placeholders. Don't invest in final environment art until M1 works. One meaningful raid is worth more than a visually impressive empty map.

## Token-saving behavior
- Never ask Claude to 'build the entire game in one go'. Give one stage prompt and a completion gate.
- Let Claude read `CLAUDE.md`, `STATE/PROGRESS.md`, the named spec(s), and ONLY the files it is modifying. Do not repeatedly ask it to reread all kit files.
- Default **one agent**, no Cowork, no redundant subagents; don't launch exhaustive searches and broad refactors.
- Ask it to execute tools/tests, not narrate long plans. Progress reports should be under 250 words per stage.
- Use the `PROMPTS/06A_*` / `06B_*` split if M1 becomes too big for a single session.
- Cap asset creation to explicitly listed asset batches. A prototype has a maximum of one rifle, six loot types, three interactable containers, and three AI test instances.
- Pause whenever a tool needs credentials, Studio click, Roblox publishing/moderation permission or hardware testing.

## Reference and legal notes
`REFERENCES/SOURCE_LINKS.md` provides official sources plus visual analysis. `REFERENCES/BODYCAM_HUD_MOCKUP.png` is an original schematic reference generated for this kit, **not game output**. External images/videos are linked rather than redistributed.

## Folder guide
- `PROMPTS/`: copy/paste one instruction at a time.
- `SPECS/`: the product design and technical contracts Claude should follow.
- `TOOLS/`: detection, optional tools, Blender/Rojo/Studio workflow.
- `TESTS/`: acceptance tests and real-device validation.
- `STATE/`: Claude's compact checkpoint files; do not replace them with prose.
- `ASSETS/`: planned manifest, asset generation rules.
- `REFERENCES/`: primary sources, style board, HUD mockup.

If you have only ~50% of your Claude weekly allowance left: stop at M1 first, validate core fun, then spend remaining usage on the one bottleneck you actually observe.
