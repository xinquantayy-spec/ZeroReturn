# Stationary (mounted) weapons

Tarkov's fixed guns are the NSV "Utyos" 12.7x108 heavy machine gun and the AGS-30 30x29 automatic grenade launcher. Zero Return
has two of its own: the HMG-12 "Bastion" and the AGL-30. Research read on 2026-11-01 (wiki and patch-note text, not the game:
nothing below was seen running in Tarkov).

**Status:** written, and passed through `tools/luau_check.py` only (a structure check: brackets, blocks, strings). The new
"stationary" group in `src/server/Tests/LogicTests.luau` has not been run, nothing has been run in Studio, and nothing has been
tried on a phone, a gamepad or a console. The first Studio pass should run `tests` (ZR_Dev) and then mount a gun by hand.

Code:
- `src/shared/Stationary.luau`: the two kinds and their numbers, the aiming maths (frames, arcs, angles), shared by server,
  client and tests.
- `src/server/Services/Stationary.luau`: models, mount and dismount, arcs, rate of fire, belt, rounds in flight, damage, guards
  on a gun, raid reset. `World.kit().stationary(kind, cframe, opts)` places a gun from map code.
- `src/client/Controllers/Stationary.luau`: the mounted mode (camera, zoom, aim inside the arcs, fire, leave) and the head
  turning of every gun in view.
- Touches elsewhere: `Items.luau` (item `AGL30_ROUND`), `InputMap.luau` and `Input.luau` (the `mount` context), `Touch.luau`,
  `Hud.luau`, `Interact.luau` (prompts off while mounted), `Movement.luau`, `QuickSlots.luau`, `Weapon.luau`, `Effects.luau`,
  `Combat.luau` and `Grenades.luau` (no personal shot or throw while mounted), `AI.luau` (guards use guns), `Raid.luau` (reset),
  `Maps/Border/Play.luau` (the placements), `Main.server.luau` and `Main.client.luau` (wiring and a Studio test command).

## What Tarkov does (found in sources)

| Rule | What the source says | Source |
|---|---|---|
| What they are | "permanently fixed at specific locations throughout the game world, available for use by both players and bots"; "spawn fully loaded every raid and can't be reloaded" | EFT Fandom, Weapons, "Stationary weapons" |
| One operator | two players using one at the same time shows wrong character visuals, so a gun has one operator at a time (4 Apr 2023 fix) | EFT Fandom, Changelog |
| NSV Utyos | 12.7x108, full auto, 650 RPM, default ammo B-32, magazine "Belt"; adopted 1971 | EFT Fandom, item page and Weapons |
| AGS-30 | 30x29, full auto, 425 RPM, default ammo VOG-30, magazine "Belt drum"; "weighs 30 kg loaded"; based on the AGS-17. The item page itself would not load twice in the second pass; these figures are from the first pass (page text and a search snippet) | EFT Fandom, item page and Weapons |
| Rounds (unofficial numbers) | B-32 damage 182, penetration 88; BZT-44M damage 199, penetration 80 | SP-Tarkov hub mod page (a mod, not BSG) |
| Where they stand, aiming a launcher | Three AGS-30 sit on the edges of the abandoned military base on Reserve, with a mounted NSV; a player operates them from the mount. Each shot uses two numbers: the arc, which sets where the grenade lands, and the zeroing, which only helps line up shots and does not change where it lands. A Reddit map cited by the article lists the arc for each building (an arc of -.02 from the radar towers reaches the HQ building), and the three launchers cover the base but for its southeast corner. Nothing on controls, damage or reloading | Dexerto guide on grenade launchers; a second guide at xboxplay.games gives the same two numbers |
| Maps | NSV: Customs, Ground Zero, Lighthouse, Reserve, Shoreline, Streets, Woods, Interchange. AGS: Customs, Ground Zero, Lighthouse, Reserve, Shoreline, Streets. Pages give no positions ("check the interactive map") | EFT Fandom item pages |
| Customs | "Stationary weapons in the form of AGS-30 ... and NSV Utyos ..." (Features); the map was "expanded again with patch 0.12.7.8334 on July 20, 2020"; 0.12.7 notes: "added many new explorable buildings, stationary weapons, new location for Reshala spawn" | EFT Fandom Customs; GameSpot and aoeah 0.12.7 notes; thetarkovhandbook.com/Customs.html |
| First added | patch 0.12 (Reserve: two AGS in the military base, one on the weather station; NSV guarding Glukhar's followers) | IMFDB, Launchers, Explosives, Mounted Weapons |
| Customs crews | Reshala's men "fire machine guns and grenade launchers" in the northern factory area (expanded in 0.12.7) | NamuWiki, Customs (Korean wiki, English view) |
| Other crews | Rogues on "heavy machine gun and grenade launcher emplacements" at the Lighthouse water treatment plant; Kaban's guards "man AGS-30/NSV emplacements at every entrance" (LexOs dealership, Streets) | EFT Fandom Lighthouse; thetarkovhandbook.com/AI.html |
| Bots use them | AI behaviour with stationary weapons was fixed on 10 Aug 2023 and again on 3 Apr 2024 | EFT Fandom, Changelog |
| Camera shake | the guns shake the camera when fired (missing shake fixed 26 Feb 2024) | EFT Fandom, Changelog |
| Control | no stationary-weapon key in the controls list (F = Interact) | EFT Fandom, Controls |
| Not in the game | KORD, Maxim 1910, 2B14 mortar, SPG-9 are "upcoming" only | EFT Fandom, Weapons |

## Not found (nothing invented as fact; each is a gap below and in `EFT_PARITY.md`)

Mount key, prompt text and distance; how the player leaves; traverse and elevation limits; ADS and zoom; belt size;
overheating (none mentioned anywhere); recoil and spread; VOG-30 blast numbers; sounds; what the arc number means and how
zeroing is changed; exact Customs positions (`api.tarkov.dev` was blocked by the sandbox proxy and was not worked around). The
Border Yard layout has no mounted-gun list either (`L.hazard.mounted` is empty).

## The two guns

Rate and rounds come from the table above; everything else is our own choice (marked ours).

| | HMG-12 "Bastion" (NSV Utyos) | AGL-30 (AGS-30) |
|---|---|---|
| Rate | 650 RPM | 425 RPM |
| Belt | 100 rounds (ours) | 30 rounds (ours) |
| Round | 12.7 mm: 182 damage, 88 penetration (B-32 numbers), armour damage 0.85, bleed chances 35 and 20 percent (ours) | 30 mm launcher round (item `AGL30_ROUND`): bursts like a frag charge, 150 fragments of 24 to 38 damage and 10 to 16 penetration within 16 studs, blast 85 damage within 4.5 studs (ours; VOG-30 numbers not found) |
| Flight | 800 m/s, drag 0.45 per s, range 1,100 studs, zeroed at 200 m (ours) | 185 m/s, drag 0.12 per s, range 900 studs (a round that flies the whole range bursts itself), zeroed at 120 m, armed after 20 studs (a nearer hit is a dud) (ours) |
| Arcs | 70 degrees left, 70 right, 40 up, 20 down (ours) | 60 left, 60 right, 55 up, 14 down (ours) |
| Spread | 0.12 degrees plus bloom of 0.014 a round up to 0.75, settling after 0.12 s of silence | 0.1 degrees plus 0.035 a round up to 0.6 |
| Camera | 2x zoom, small shake | 3x zoom, bigger shake |
| Guard reach | up to 190 studs, turns 1.1 rad/s, bursts of 5 to 10 rounds, 0.7 to 1.5 s between | 40 to 170 studs, turns 0.9 rad/s, bursts of 2 to 4, 1.2 to 2.2 s between |

Damage falls off with distance like every weapon (`Weapons.FALLOFF_START` 35 percent of the range, down to `FALLOFF_MIN` 60 percent
at the range). Both spawn full each raid, cannot be reloaded and refill only when the world resets.

## How it works

The server owns everything that counts; the operator's client only says where it aims and whether the trigger is down.

- **Mounting.** Each gun has an Interact prompt ("Man the gun", F / pad X / tap, 7 studs) on its operator spot, 3.2 to 3.4 studs
  behind the pivot. `Stationary.mount` accepts a raider who is alive in a raid that is not over, within 12 studs (plus standing
  height) of the spot, on no other gun, not treating a wound or throwing a grenade, not within 0.6 s of leaving a gun (F is both
  the prompt and the leave key), at a gun with no operator and no guard on it. The raider is moved to the spot facing along the
  gun (flagged `TP` so the movement guard takes it as a server teleport), stands, loses their velocity, and gets the attribute
  `Mounted` (the gun's id). `Combat.shoot` and `Grenades.pull` refuse while it is set.
- **Aim.** The client sends `staim {y, p, f}` (yaw and pitch relative to the gun, trigger) at up to 20 Hz plus a keep-alive every
  0.25 s; the server clamps to the arcs and counts the trigger as released after 0.7 s without an update. The head of the gun turns
  on every client from the attributes `Yaw` and `Pitch`; `Rounds` follows the belt.
- **Fire.** `Stationary.trigger` fires a round when the belt has one and the clock has reached the next shot: a steady 60 / RPM
  interval while the trigger is held, from now after a pause. The round starts at the operator's eye and flies along the aim
  (the crosshair is where it lands, bore tilted for the zero, spread by the bloom): `Ballistics.trace` for the shot effect,
  `Ballistics.fly` for the real bullet, `Stationary.land` on a hit. Armour, hit zones, bleeds and doors work as for any
  weapon because the hit goes through `Hazards.hit` (propane) and `Combat.hitModel` to `Health.hit`.
- **The launcher's burst.** `Stationary.burst` sets the round off through `Grenades.blastAt` (fragments, blast, propane
  chain reaction, AI hearing), the same code as a thrown frag. A hit closer than 20 studs is a dud.
- **Getting off.** `stleave` (F, pad B, LEAVE), or the server puts the operator off when they die, the raid ends, they leave the
  game, move more than 8 studs from the spot, or the gun is reset or removed. The client is told with the note `stend`.
- **Being hit while mounted.** Nothing special: the operator is a normal exposed player (head and shoulders above the gun), nothing
  absorbs shots, and no overheating or jamming exists (none was found in Tarkov). Dying puts them off the gun.
- **Raid reset.** `Raid.resetWorld` calls `Stationary.reset`: every gun full, free and aimed straight ahead.
- **Guards.** `AI.think` calls `Stationary.crew` for a guard who has a post: when the guard is engaging a target the gun
  can reach (inside the arcs, between the kind's shortest and longest range, in sight) and stands on the operator spot, the
  guard mans the gun; it slews at the gun's turn rate, aims ahead of a moving target, fires short bursts, holds the launcher's
  fire when a friend stands near the target, and walks off when the target is dead, lost for 4 s, out of reach, the belt is
  empty or the guard was moved off the spot. Scavs and bosses on patrol never use a gun; a gun with a guard on it cannot be
  mounted and a guard does not use a gun a raider is on. Rounds from a crew's gun pass its own side (no guard is hit by a bullet);
  the launcher's fire is held while a friend stands within 12 studs of the target.
- **Sound to the AI.** Every round is heard like a shot, louder than a rifle's (`AI.hearShot`, loudness 2.6 and 2.4), and the AI
  near the line of fire are suppressed (`AI.bulletPassed`).

## Controls

Mount: the Interact prompt at the operator spot (F on keyboard, X on a gamepad, tap on touch). While mounted the actions of the
personal weapon (reload, sprint, crouch, lean, grenade, quick slots, fire mode and so on) are replaced by three of their own, in
the input context `mount` (`Input.setMounted`); the inventory and settings keys still work, and the prompts are off.

| Action | Keyboard and mouse | Gamepad | Touch |
|---|---|---|---|
| Aim | mouse | right stick | drag the screen or the FIRE button |
| Fire (hold) | left mouse (follows the player's Fire key) | right trigger | FIRE |
| Zoom | right mouse, held (follows the Aim key) | left trigger, held | ZOOM, toggles |
| Leave | F | B | LEAVE |

On screen: a ring reticle, "AT LIMIT" when the aim is at the edge of an arc, and on the AGL-30 "ARC" (elevation in degrees) and
"ZERO" (metres) as the AGS shows its two numbers while aiming. The weapon line shows the gun and its belt:
`HMG-12 'BASTION'  ·  87 / 100  ·  F TO LEAVE` (`TAP LEAVE` on touch; the count turns red at 10 percent of the belt or 5 rounds, whichever is more; Tarkov shows no
exact counter, so the count is a deliberate exception asked for in the task).
The camera sits at the gun's eye, zoomed 2x or 3x with the look sensitivity scaled by the lens, with a shake per shot that
the Reduce Motion setting dampens. The viewmodel is hidden and the character stands planted (no walking, jumping or lean). The
player's own gun follows their camera exactly; everyone else's turns toward the published aim.

## Where the guns stand

`kit.stationary(kind, cframe, opts)` from map code (opts: `parent`, `arcs`); guns go in `ZR_World/Stationary`. Border Yard (our
Customs layout) has two on the roof of the Bastion (the scav base), both against the yard-side parapet and pointing straight out
from it: the HMG-12 over the `BASTION_YARD` point, the AGL-30 95 studs along the wall, each on a concrete pad that lifts the gun
over the 3.4 stud parapet, each with a Watch guard posted behind it (route BG). The real Customs positions are not in any
source, so the roof is our choice, not a copy. Details: `docs/maps/BORDER_YARD.md`, "Gun nests".

## The first draft and what the review changed

The draft left by the first pass was checked line by line against this design; these were wrong or missing and are fixed:
- Guns were parented to `workspace.Stationary`, because `ZR_World` reaches the workspace only at the end of the build; `World.kit`
  now parents them in the world root.
- The personal weapon and grenades were not blocked server-side while mounted (`Mounted` was set and never read).
- A raider kept their running velocity on mounting.
- A key still held from the prompt could leave the gun at once (a 0.4 s guard on the client now), and a late `stend` for a gun
  already left could drop the player off the next one (it carries the gun id and is checked); a `stend` arriving while the client
  waits for the model to stream in is honoured.
- The gun of the player's own view was posed one frame behind their camera.
- The touch hint said "F TO LEAVE"; the AGL-30 showed no arc or zeroing numbers.
- A leaving player's restart timer was kept forever (`blocked`); it is now cleared after the vacate and held weakly.
- The Border comments called the wall "south"; it is the building's +v wall.
- The server file is split so that mounting, leaving, rate, belt, damage, guards and reset can be tested without a real player
  (`Stationary.sessionOf`, `Stationary.trigger` apart from `Stationary.fire`).

## Gaps against Tarkov (also in `EFT_PARITY.md`)

- Controls: Tarkov documents none, so F to mount and leave, the mouse, trigger and stick mappings and the touch buttons are ours.
- Arcs, zoom, belt sizes, spread and recoil are ours (nothing was found). No overheating, as none was found.
- The AGL-30 shows an arc and a zeroing number, but the zeroing is fixed (Tarkov's only fine-tunes the alignment) and our "arc"
  is the elevation angle in degrees, a guess at what Tarkov's number (such as -.02) means.
- Ammo: the VOG-30 blast numbers are ours; B-32 numbers are the unofficial ones; no other belts (BZT-44M) or ammo choice.
- Positions: only two guns, on the Bastion roof. Customs has many more (NSV and AGS at several places) and other maps have
  them too; none of the real positions is known.
- Bots: only posted guards use a gun, in the arcs and range described above; Tarkov's scavs and bosses use them in other ways
  (Reshala's men, rogues, Kaban's guards).
- Animation and art: no mounting animation (the raider is moved to the spot), no operator pose on the grips or turning body, the
  guns are built from parts (about 30 each), and the shot sound is the rifle recording pitched down and louder (no dedicated
  audio).
- A two-person crew (a loader), moving or dismantling a gun: none in Tarkov as far as found; not built.
- Untested: nothing here has run in Studio. Gamepad and touch handling, the camera and zoom feel, and the frame rate on a
  low-end phone with a gun firing (the server sends one unreliable effect per round to every client) have not been tried.

## Tests (`src/server/Tests/LogicTests.luau`, group "stationary"; not run yet)

The operators are stand-in tables (a rig for a character and a raid session the test hands out); the test guns are stepped by
hand with a clock of the test's own, away from the Heartbeat loop, at (9000, 2500, 0) in a folder that is destroyed afterwards.
- Shared numbers: the kinds carry 650 and 425 RPM, the belts, the B-32 numbers; every kind has the fields the server and client
  read; the interval is 60 / RPM; the launcher's round is a frag charge; arcs from the kind and narrowed per gun; clamp and
  `inArc` at the edges; positive yaw is left; `anglesFrom` puts a round from the eye on a point; `approach`; the input map's
  `mount` context (fire and zoom follow Fire and Aim, F or B leaves, every action has a touch button).
- Mounting: a raider too far, outside a raid, whose raid is over or who is dead is refused; one in reach is moved to the spot
  facing along the gun with `Mounted` set and the prompt off; one operator per gun and one gun per operator.
- Aiming: the update is clamped to the arcs, a non-number is ignored, a bystander cannot aim the gun.
- Getting off: leave frees the gun, the same raider is refused for 0.6 s and accepted after; 5 studs from the spot is inside the
  leash, 60 puts the operator off; the raid ending and death put the operator off; removing a gun does the same.
- Rate and belt: the HMG-12 fires 21 to 23 rounds in two seconds of simulated time and the AGL-30 14 to 16, each off the belt; a
  round inside the interval is refused; an empty belt stops the gun; a trigger whose updates stopped is released after 0.7 s;
  the belt and aim reach the model attributes; the falloff curve.
- Damage: a real round from the HMG-12 hits a dummy 80 studs ahead through `Combat.hitModel` and `Health.hit` (weapon,
  ammunition and health recorded); an AGL-30 round flies into a wall and bursts through `Grenades.blastAt` (shell and blast
  counters; needs the world to be up); a hit nearer than the arming distance is a dud, a round at the end of its range
  bursts itself, a machine-gun round just ends; shots by a guard's model and by an operator run the whole fire path.
- Guards: a gun with a raider on it is no post, a free one is; the reach (ahead yes; behind, to the side, past 190 studs, or
  nearer than 40 for the launcher no); a guard does not man a gun against a target behind it, does against one ahead, and then no
  raider can mount it; it lays the gun on the target and fires bursts off the belt; it leaves when the target dies or when moved
  off the spot.
- Reset: every gun full, free and straight ahead. Placement: Border Yard carries an HMG-12 and an AGL-30 inside the world folder.
- Not covered: the refusals in `Combat.shoot` and `Grenades.pull` while `Mounted` (they need a real player), the remote
  handlers `staim` and `stleave` (the same), the client controller, and a busy raider (treating a wound, a pin pulled) being
  refused.

A Studio helper on the client bridge: `ZR_ClientDev` command `stationary` reports the mounted state (gun, belt, zoom, aim, field
of view) and `"leave"` gets off the gun; `action` with `MountFire` or `MountZoom` drives it.

## Sources

- Escape from Tarkov Wiki (Fandom): [Weapons](https://escapefromtarkov.fandom.com/wiki/Weapons) ("Stationary weapons"),
  [NSV Utyos](https://escapefromtarkov.fandom.com/wiki/NSV_Utyos_12.7x108_heavy_machine_gun),
  [AGS-30](https://escapefromtarkov.fandom.com/wiki/AGS-30_30x29_automatic_grenade_launcher) (did not load in the second pass),
  and by name the Changelog, Customs, Lighthouse and Controls pages (the pages are named in the table; their addresses were not
  kept)
- [Dexerto: how to destroy Escape from Tarkov players using grenade launchers](https://www.dexerto.com/escape-from-tarkov/how-to-destroy-escape-from-tarkov-players-using-grenade-launchers-1355803/)
  and [a second guide on xboxplay.games](https://xboxplay.games/escape-from-tarkov/-how-to-kill-enemies-using-grenade-launchers-7496)
- By name, addresses not kept: IMFDB (Launchers, Explosives, Mounted Weapons), the SP-Tarkov hub page for the B-32 and BZT-44M
  numbers, the GameSpot and aoeah 0.12.7 patch notes, thetarkovhandbook.com (Customs, AI), NamuWiki (Customs). The IMFDB page on
  unusable weapons was read too and says nothing about the stationary guns.
