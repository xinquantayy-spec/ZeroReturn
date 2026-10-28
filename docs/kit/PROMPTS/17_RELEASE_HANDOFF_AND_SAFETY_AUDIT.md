# STAGE 17: Release handoff and safety audit

## Copy/paste instruction to Claude Code

You are implementing ONLY stage 17 of ZERO RETURN, an original Roblox extraction shooter. Use Claude Code directly, **not Cowork**, and do not delegate to extra agents. I have approximately 50% weekly Claude usage remaining: conserve tokens, inspect only necessary files, favor direct tool calls, write code/assets to disk rather than long replies, and do not start later stages without permission.

### Read only
- `CLAUDE.md`, `STATE/PROGRESS.md`, `STATE/DECISIONS.md`.
- `SPECS/10_ROBLOX_CONTENT_POLICY.md`, `SPECS/11_SOURCE_OF_TRUTH_AND_COMPLETION.md`, `REFERENCES/SOURCE_LINKS.md`.
- The specific implementation files that this stage touches (targeted search, no repository dump).

### Goal
Prepare an owner-controlled private beta plan and reproducible build, without auto-publishing.

### Tasks to execute
1. Write `docs/DEPLOYMENT.md` with exact Roblox Studio/Rojo/Blender steps to rebuild, update asset IDs and publish to private dev universe; never publish automatically.
2. Write `docs/CONTENT_COMPLIANCE.md`: original IP and audio/asset source ownership, questionnaire recommendations (owner must answer), violence visual policy, age/country restrictions for relevant maturity label.
3. Write `docs/RELEASE_CHECKLIST.md`: crash safety, safe datastore separation, network budget, gamepad focus, mobile touch, real handset test, accessibility, controlled UI, risk/recovery onboarding, report-abuse mechanism as relevant.
4. Produce one compact owner handoff for further content: next 10 prioritized fixes, cost/risk and explicit estimates labeled as estimates. Defer major new game systems.
5. Return final file map, build status and open testing needs. Stop without starting extra features.

### Definition of done and tests
- User can reproduce the current working development game with connected tools.
- All absent hardware, console and public moderation tests marked as such.
- No real public release or account action without owner approval.

### Required output
- Implement files and actual changes; don't supply only pseudocode.
- Run relevant Rojo build, Studio playtests, or Blender import check **if tools allow**. For unavailable automation, provide precise manual action and label it `NOT TESTED`.
- Record exact tool evidence, files, test results, blockers and next prompt in `STATE/PROGRESS.md`; update architecture decision log if needed.
- Reply in <=250 words: what works, how verified, what still fails, what prompt to run next. **STOP after this stage.**
