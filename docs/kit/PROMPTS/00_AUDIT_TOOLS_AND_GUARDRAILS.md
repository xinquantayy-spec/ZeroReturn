# STAGE 00: Audit tools and guardrails

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 00 of ZERO RETURN, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `TOOLS/CONNECTOR_TROUBLESHOOTING.md`, `TOOLS/COMMAND_CHEATSHEET.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Verify every connected Blender/Rojo/Roblox Studio action before modifying production state; isolate the project.

### Tasks to execute
1. Inspect currently available integration tools by their actual exposed names, descriptions and schemas. Report read-only probes: Studio place metadata/hierarchy, Blender scene info, Rojo version/help. If no tool enumeration method exists, inspect tool list available to Claude Code; never fabricate results.
2. Print OS, root working folder, git status, project/Studio place name, owner and any active Rojo sync. Ask permission only for a truly destructive/privileged action; otherwise make a new isolated `ZeroReturn/` source folder (avoid a nested copy of the prompt kit if that would cause configuration conflicts).
3. Back up existing game/place source if one is selected; never edit an existing game without exact owner target and backup. Do not install anything yet.
4. Create `STATE/TOOL_AUDIT.md` with working read-only commands, tool limitations, actual version strings and evidence. Note whether Studio can programmatically play/test, import mesh assets, inspect UI tree and publish; do NOT publish.
5. Confirm choice of development-only experience and file/source-of-truth locations. Report at most 3 blockers; propose only verified fixes.

### Definition of done and tests
- Specific usable Blender, Rojo, Studio operations recorded or explicitly marked unavailable.
- Existing place and asset libraries untouched.
- Correct project path verified. No claimed functionality beyond audit.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
