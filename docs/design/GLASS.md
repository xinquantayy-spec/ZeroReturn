# Breakable glass (2026-11-01)

Window glass breaks when it is shot or struck, the bullet goes on, and a broken pane can be walked or vaulted through.
Written without a Luau runtime and not run in Studio: the new LogicTests block (`glass:` checks) has not been run either.
`python3 tools/luau_check.py src` passes, which checks structure only.

## Tarkov reference: what could and could not be found

Research on 2026-11-01. **No source that states how Tarkov's window glass behaves could be read**, so every number below
comes from the owner's brief, not from Tarkov, and sits in one table (`Glass.CFG`) to be tuned once checked in the game.

| Source (date) | What it says about glass |
| --- | --- |
| Tarkov wiki, Ballistics (read 2026-11-01) | Glass appears only in the armour material table (destructibility 0.6, explosive 0.6): that is visors, not windows. Nothing on windows or bullets passing glass. |
| Tarkov wiki, Changelog (read 2026-11-01) | Only render and sound fixes: 29 Aug 2024 "Fixed several graphical artifacts of glass and transparent surfaces on all locations"; 26 May 2023 glass rendering on Streets; 28 Dec 2022 sun glare on glass; 15 Apr 2024 "Improved the audibility through door and window openings". No line on shattering, shards or destructible glass. |
| PC Gamer, 10 Jun 2021 | Streets of Tarkov "will introduce destructible scenery"; no detail, glass not named. |
| GGRecon penetration guide (13 Dec 2022); wiki pages Interchange, Customs, Shoreline | Nothing on glass or windows. |
| Not readable | Forum threads "Glass Damage?" (topic 66442), "The Kiba store glass on Interchange" (100134), "A question about the kiba glass penetration" (140957), "Is barrier penetration a thing?" (167773): the titles show players asking, but the pages failed (client error) and web.archive.org is blocked. Wiki pages Penetration, Glass, Kiba Arms Outlet and a Reddit mirror also failed. |
| This project's earlier note (`docs/maps/BORDER_YARD.md`, 2026-11-01) | Tarkov's dorm windows are mostly passable openings (players vault and shoot through them). |

**Unverified, taken from the owner's brief:** a bullet breaks a whole pane and goes on with 5 to 10 % less damage; a blow
breaks one too; large panes break whole; a broken window can be walked or vaulted through; shards on the floor and a
breaking sound. **Not known at all:** the real loss (damage, speed, penetration), any deflection, whether melee breaks
glass, whether any pane is bulletproof (the Kiba store forum titles hint that it might be special). Bulletproof glass is not
built, because nothing found shows where Tarkov has it.

## What happens

| Event | Rule |
| --- | --- |
| A bullet meets a pane | The pane breaks for good (until the next raid) and the bullet goes on from just past it, on the same line, undeflected, with `CFG.keep` = 0.925 of its damage and of its penetration (midpoint of 5 to 10 %). Several panes multiply (three panes: 0.925^3). |
| A knife swing meets a pane | The pane breaks and the swing is spent on it; the AI hears it (loudness 0.35). |
| The effects trace (shot tracers, the AI's near-miss check) | Passes the pane on the same line and breaks nothing. |
| Mounted guns and the AI | Same as a player's bullets (`Stationary.land`, `AI.shoot`). |
| A long store front | `MallShell.shopFront` cuts each run of glass between two entrances (some are 80 to 250 studs) into panes of at most 20 studs, edge to edge, so a shot breaks one pane and not the whole front. |
| A new raid | `Doors.reset()` calls `Glass.reset()`: every pane is whole again. |
| Walking | A whole pane blocks as before (`CanCollide`); a broken one does not. The existing client vault takes a broken window like an open one (sill 1.0 to 4.6 studs). |

Client (`GlassFx.luau`): one pooled emitter bursts 8 to 20 shards from the pane (share by graphics level: HIGH 1, MEDIUM 0.7,
LOW 0.4, POTATO none; gone within about 1.2 s); a break sound (`glass_break_1` window, `_2` thick shopfront, `_3` small pane);
and 2 to 12 flat glass parts on the floor on each side (more for a wide pane), for the rest of the raid (cap 160 in the world). The floor shards are
driven by the pane's replicated attributes (`GlassBroken`, `GlassFloorA`, `GlassFloorB`), not by the event, so a pane that
streams in already broken shows them and a mended pane loses them.

## Design: the hit shell

Every pane is tagged `ZR_Glass` where its map builds it (`Border/Living.luau` `glaze`, `Meridian/MallShell.luau` `shopFront`).
`Services/Glass.luau` (started before `Combat`) registers the tagged parts (the maps build first; later ones come through the
tag signals) and puts an invisible, non-colliding, queryable box of the same size (at least 0.2 thick) beside each, in
collision group `ZR_Glass` (folder `workspace.ZR_GlassHit`). `ZR_Glass` does not collide with `Default`, so **no existing raycast
had to change**: sight, loot, grenades, the vault and the camera cast in `Default` and never meet a shell. Bullets and blows are
cast in group `ZR_Shot` (`Ballistics.shotParams`), which collides with everything, so only they meet it.

The pane itself stays solid for movement. Registration sets `CanQuery = false`, but **Roblox ignores `CanQuery` on a part that
collides** (Studio 2026-11-01: a ray still met such a pane, a frame later too), so a whole pane meets every ordinary ray, as the
Border panes always did. Registration therefore also puts the pane in group `ZR_Pane`. The AI's sight and aim checks are cast in
group `ZR_Sight` (`AI.setSightGroup`, called by `Glass.init`), which passes `ZR_Pane` and `ZR_Glass` and meets everything else:
the AI sees and aims through windows, as in Tarkov. `Ballistics.stepOnce` asks `Ballistics.through(res, dir, real)` at every hit; for a shell it gets the share kept and
the distance to the far face (slab maths, clamped to 3 studs, plus 0.05), a real bullet (`fly`, not `trace`) breaks the pane
(`Glass.shatter`), and the bullet carries on in the same step (at most 6 panes a step). `Combat.shoot`, `AI`, `Stationary` take
the fifth `onHit` argument (`keep`) and multiply damage and penetration. If the groups cannot be made, `Ballistics.shotGroup`
stays nil and glass simply does not break (nothing else changes). One `Remotes.fx("glass", { cf, sz, d, h })` per break
(at most 12 a second), to everyone.

## Sound and the OGG

Three procedural one-shots added to `assets/audio/synth_amb.py` (a bright crack, bell pings, a spray of shards, a tinkling
tail), appended after `gun_far_3`, so the earlier regions did not move (decoded with ffmpeg, the first 70 s of the new file are
sample for sample the same as the committed one). **`assets/audio/out/ZR_SFX_Amb.ogg` changed** (714,791
to 790,686 bytes; 70.74 s to 77.80 s) and **must be re-uploaded**, then `Sounds.AMB_ATLAS` replaced with the new id. Until then
`GlassFx` reads the asset's length from a probe Sound, finds it too short for the new regions and plays nothing (one console
line says so). No asset id was changed or invented.

## Costs

- Server: one extra invisible anchored part per pane (the start-up line `[ZR] Glass: N breakable panes (...)` gives N; they
  replicate to clients like any part); one `pcall`ed function call per bullet hit on world geometry; nothing per frame.
- Client: 3 pooled emitter parts, at most 20 particles a break, up to 160 floor parts, nothing per frame.
- Network: one small unreliable event per break, capped at 12 a second.

## Changes to other systems

- **The AI sees through glass.** Whole panes (Border windows, Meridian shop fronts) used to block the AI's sight like walls. Now
  its sight and aim rays pass them (group `ZR_Sight`), and it can shoot through them: its bullets meet the shell and break the
  pane. Every other ordinary ray (grenade flight, the camera, the vault) still meets a whole pane, as before.
- `Combat.melee` casts in the shot group and `Combat.filter` is unchanged.

## Check in Studio (the checks below have not been done)

1. Server output shows `[ZR] Glass: N breakable panes (border ..., meridian ...)` and no `could not be made` warning; run the
   `tests` command and read the `glass:` lines.
2. **Border dorm window.** BLOCK B washroom window, always a whole frosted pane (floor 1, south face, slot of room 121): pane
   centre (-236.0, 5.6, -4635.4). Stand at (-243.9, 5, -4636.4), face +x, shoot. If room 121 was not the washroom that raid, the
   frosted pane is one slot over (rooms 125, 119, 117 or 120 sit at u 49.2, -10.2, -30.0, -0.3 on the same wall). BLOCK A's east
   face has 13 windows (30 % whole, 25 % half, the rest open or boarded) at world (-26.2, y, -4504.5) to (-10.1, y, -4622.3)
   in steps of about 1.35 in x and 9.8 in z, y 5.6 on floor 1 and 16.6 on floor 2; stand 8 studs east of one.
3. **Meridian shopfront.** NESTA CANTEEN's south glass front (L1, z 8390.6; the unit spans x -37.5 to 162.5, its three
   entrances leave glass at x -37.5 to 45.3, which is cut into five panes of 16.6 studs): the middle pane is about
   (3.9, 24.5, 8390.6), glass y 17.7 to 31.3. Stand at (4, 21, 8404.6), face -z, shoot. The east front is the other choice:
   x 162.5, around z 8246.9.
4. After the shot: pane gone, shards on the floor both sides, sound (only once the OGG is re-uploaded), walk through; shoot a
   target behind a pane and read the damage (7.5 % less); a knife swing breaks one; start a new raid and the panes are back.
   Before the shot, with the pane whole: the client's own tracer/hit marker lands on what lies behind the pane (the invisible
   shell must not stop client rays), and the camera does not jump in front of the window.

## Gaps

- Tarkov's real behaviour is unverified (above): the 7.5 % loss, "no deflection", melee breaking, and that every pane breaks.
- No bulletproof glass anywhere.
- A pane breaks whole; there is no cracking stage, no partial holes and no fragments left in the frame.
- Only window glass is breakable: balustrades, skylights and domes, mirrors, escalator panels, counter glass, vehicle
  windscreens and the sawmill booth glass are unchanged and stay solid or decorative.
- Grenade blasts, falling objects and fists do not break glass.
- Walking on floor shards makes no extra noise and does no damage.
- Shards are flat parts of one look, no mesh pieces, no decals; none are made where the floor is more than 6 studs below the
  sill (a window high over open ground has none outside).
- Thrown grenades fly through a whole pane (see above), where Tarkov's may bounce.
- The AI does not path through or avoid broken panes; navigation is not recomputed.
- The glass sound is one of three recordings, procedural, not Tarkov's; it plays at the pane, not at each shard.
- Assumed, not checked: the collision-group settings the server makes (`ZR_Glass` does not collide with `Default`) reach the
  clients, as they do for the usual character groups. If they did not, a client's own rays (weapon prediction, the vault)
  would stop at the invisible shells; the Studio check above (aim at a whole pane, the shot's hit marker lands on what is
  behind it) would show that.
- A pane that leaves the world broken (its map removed) is mended when it is unregistered, so it comes back whole; the game
  never removes a map today, so this is untested.
