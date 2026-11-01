# Atmosphere pass: reverb by space, mall ambience, the shop siren, dust in the light (2026-11-01)

Owner request (2026-11-01): "consider the atmosphere, ambience that can improve realism, without affecting performance; at least
30 fps". This page says what Tarkov does (researched first), what was built, what it costs, what is not copied, and what has to be
done before it is heard. **Status: written and passed through `tools/luau_check.py` (structure only). Nothing here has been run
in Studio, on a phone or on a console; no frame rate was measured; no level was set by ear (nobody has heard it yet).**

## 1. What Tarkov does (sources read 2026-11-01)

- **Reverb and occlusion come from Steam Audio.** The first iteration arrived with patch 0.12.6 (late May 2020): "Added the first
  iteration of Steam Audio, aimed at improving the positioning of sound in game", with a "Steam Audio: Binaural audio" option that is
  off by default; the same notes fix a bug where, after reconnecting indoors, "all sounds were not switched as indoor sounds", so the
  game keeps an indoor / outdoor state for sound ([Gfinity Esports, 0.12.6 notes, published 1 Jun 2020](https://www.gfinityesports.com/article/escape-from-tarkov-12-6-patch-notes-update-full-list-changes-wipe-pc);
  [Shazoo, 29 May 2020](https://shazoo.ru/2020/05/29/94905/vajp-novaya-ekipirovka-i-steam-audio-escape-from-tarkov-poluchila-krupnyj-patch)
  calls it the headline feature). What the toolkit does ([Steamworks: Steam Audio](https://partner.steamgames.com/doc/features/steam_audio)):
  raycasts direct sound against solid objects (occlusion, partial occlusion, transmission through geometry), computes reflections and
  reverb from the size, shape, layout and materials of the rooms, and models propagation down hallways, round corners and through doors
  and windows. Whether Tarkov uses every one of those features is not stated in any source found.
- **0.16.7.0** (scheduled for 23 June, "a Monday" in [PCGamesN](https://www.pcgamesn.com/escape-from-tarkov/update-audio-overhaul), so 2025;
  [Insider Gaming](https://insider-gaming.com/tarkov-patch-overhauls-immersive-audio/) gives no date): BSG "readjusted the sound subsystem that checks for obstructions between the listener and the
  source"; sources behind terrain, vehicles, rocks and crates, and occlusion "in several locations", improved; sound transmission between
  floors and stairways improved; bushes quieter. Neither article says anything about reverb, ambience or distant gunfire.
- **Interchange:** the wiki lists "a fully linked illumination grid, able to be switched on at the power station" and "a triggerable alarm
  at the Kiba Arms Store" that "can be switched off at designated terminals" ([Wiki: Interchange](https://escapefromtarkov.fandom.com/wiki/Interchange)).
  Opening the Kiba Arms outer door "triggers a store alarm three seconds later" and it is disabled at the first-floor security room
  terminal; how long it rings is not stated ([TarkovForge: Kiba Arms outer door key](https://tarkovforge.com/keys/kiba-arms-outer-door-key)).
- **Distant gunfire:** in Tarkov a far shot is a real fight somewhere ("you are an audience, not a target", [Guild Order: audio and sound
  triangulation](https://guildorder.com/hi/games/tarkov/guides/audio-fluency-and-sound-triangulation)). No source describes scripted
  ambient gunfire.
- **Not found in any source:** the sound of Interchange's mall (empty-mall room tone, wind through the building, what the lights and
  machines sound like with the power on, arcade or escalator sounds), and dust shafts in the light.
  ([ConsolePCGaming: Interchange getting new lighting](https://consolepcgaming.com/escape-from-tarkov-interchange-getting-new-lighting)
  only says the mall is "engulfed in darkness", and the wiki and one map guide have no sound notes.) The mall layers and the dust below
  are therefore **our design**, not a copy; they are logged as such in `docs/design/EFT_PARITY.md`.

## 2. What was built

| Piece | Where | What it does |
|---|---|---|
| Reverb by space | `src/client/Controllers/Ambience.luau` | Every 0.4 s the camera's space is measured with at most 8 raycasts and `SoundService.AmbientReverb` follows (table in section 3). A new class must win two probes in a row and a class you are in is easier to stay in, so it never flickers. A floor part can name its own reverb with the attribute `Reverb` (washroom floors: Bathroom, the service tunnel: StoneCorridor, the shelter, its vestibule and UNIT 14: StoneRoom; `MallShell.luau`). |
| Room tone | same | Looped, 2D, in the `ZR_Ambient` group (so the AMBIENCE slider rules it), crossfaded over about 1.6 s. Indoors in raids at full level (0.8 in the bunker), 40 % lower in rain. Outdoors Atmos's wind and rain stay as they were; the rain on the roof indoors is Atmos's too (not duplicated). |
| Car park tone | same | Replaces the room tone in the car park class (Meridian's L0). |
| Mains and fluorescent hum | same + `World.luau` | In raids: only inside Meridian's mall (the roof ray from the camera hits a part of the Mall, StoresL1 or StoresL2 model) and only while the power lever is on. The server now publishes every switch as the workspace attribute `ZR_Sw_<id>` (`World.luau`, `publishSwitch`: wraps `onChange`, which Doors.luau calls on every change and every reset), so the client reads `ZR_Sw_MALL_POWER`. In the Relay 7 bunker it hums at 0.6 (its own lamps and relays). |
| Water drips | same | A pooled sound (3 variants, 3 Attachments in Terrain) every 8 to 25 s indoors (5 to 15 s in the car park, washrooms and tunnel), placed on the floor along a free line of sight 3 to 17 studs away, pitch varied 0.94 to 1.08. |
| Distant gunfire | same | One burst every 40 to 120 s in raids (first one after 25 to 60 s), 200 to 320 studs away, Linear roll-off 140 to 520, quieter indoors (x0.4) and in rain (x0.7), pitch varied, never the same variant twice in a row. Long echo tails are in the recording. |
| Gun-shop siren | `src/server/Maps/Meridian/Play.luau` | A looped Sound on the IRONSIGHT beacon, started with the first red flash (3 s after the front door opens) and stopped when the terminal (switch `MM_ALARM`) is used. It follows the existing 60 s cap of the lamp and the AI call, then stops. |
| Generator hum | `src/server/Maps/Meridian/Outside.luau` | A looped Sound on the substation generator, on from the power lever's `B.powerHooks` call with true and off with false (every raid starts off). |
| Dust in the light | `Ambience.luau` + `MallShell.luau` | The roof's glass panes (41 in the plan) are tagged `ZR_Skylight`. At graphics MEDIUM and HIGH, indoors in a raid, by day (sun factor above 0.35), the six nearest panes within 60 studs get a Box-volume ParticleEmitter column (at most 12 x 12 studs, up to 26 high) at 1.5 to 4 motes a second each, lifetime 7 to 11 s, 0.1 stud motes drifting at 0.05 to 0.25 studs/s. The pool (6 parts and 6 emitters in `workspace.ZR_Dust`) is built the first time it is needed and is set to rate 0 otherwise. |
| The sounds | `assets/audio/synth_amb.py` -> `assets/audio/out/ZR_SFX_Amb.ogg`, `src/shared/AmbAtlas.luau` | See section 4. `src/shared/AmbSound.luau` makes a Sound from one region (returns nil while the id is empty). `Effects.luau` also finds the atlas names, so `Effects.play("drip_2")` works. |

## 3. Space classes (the test, then the Enum.ReverbType)

Measured each probe: the distance up to a roof (90 studs), down to the floor (16), six level rays 60 degrees apart from 1 stud below
the camera (70 studs), and on every second probe six rays tilted 32 degrees up (80 studs) that count the ones that end on a ceiling.
The four probes of a cycle alternate the ring's turn by 30 degrees, so every direction is seen within 1.6 s. Averages are smoothed.
"Width" below is measured along each of the three axes of the ring and only between two walls that face each other (their normals
point against each other), so standing in the corner of a big hall does not read as a narrow room. The thresholds were checked offline
on synthetic boxes with a Python port of the probe (a car park 300 x 300 x 16.25, an anchor hall 400 x 350 x 28.13, galleries, shops,
a substation-size hall, corridors, corners, a street, a porch): every case landed in the class the table gives, except that a
24-wide, 28-high gallery reads as a hall and not as a corridor. That check ran on a port of the logic, not on the Luau.

| Class | Test (after "indoors": a roof over us and at least 3 of 6 rays ending on a ceiling or a wall) | Reverb |
|---|---|---|
| outdoors | no roof, or a roof without walls or ceiling around (a porch, an awning) | Plain |
| alley | outdoors, 4.5 or more level rays blocked and mean free distance under 26 studs | Alley |
| marked room | the floor under the camera has the attribute `Reverb` | that value |
| car park | floor to ceiling under 19, mean free distance 28 or more, narrowest width 30 or more (Meridian L0 is 16.25 high; a 40 x 60 x 14 hall reads as a hall) | ParkingLot |
| corridor | narrowest width under 24, widest more than 2.4 times that, mean free distance 9 or more | Hallway |
| room | mean free distance under 16 | Room |
| hangar-size hall | floor to ceiling 21 or more, mean free distance 34 or more (the anchor halls are 28 high and hundreds wide) | Auditorium (about 4 s) |
| hall | mean free distance 20 or more | StoneRoom |
| otherwise | | Room |

Numbers are first guesses from the mall's measurements in `docs/maps/MERIDIAN_MALL.md`, not tuned. If the anchor halls should ring
longer, `REVERB_OF.hangar` in `Ambience.luau` can say "Hangar" (about 10 s tail). `Enum.ReverbType` items are looked up through pcall,
so a wrong name cannot error.

## 4. The sounds (`assets/audio/synth_amb.py`)

Procedural and original, no samples: numpy, written like `synth_env.py`; run `python3 -I assets/audio/synth_amb.py <out_dir>
src/shared/AmbAtlas.luau`. Output `assets/audio/out/ZR_SFX_Amb.ogg`: mono, 44.1 kHz, Vorbis q6, **714,791 bytes (698 KB), 70.74 s**.
Regenerated 2026-11-01 and compared: same atlas file, same decoded audio. Loops are whole cycles of random-phase band noise with
circular filters and reverb, so they repeat exactly; the seam curvature of every decoded loop is at most 0.61 of the sharpest
curvature inside it. Levels were set from A-weighted loudness against the existing beds, not by ear.

| Name | Start (s) | Length (s) | Gain | Loop | Used for |
|---|---|---|---|---|---|
| `room_tone_loop` | 0.12 | 12.0 | 0.5 | yes | empty-mall room tone |
| `elec_hum_loop` | 12.24 | 8.0 | 0.35 | yes | mains and fluorescent hum |
| `garage_tone_loop` | 20.36 | 12.0 | 0.5 | yes | car park tone |
| `siren_loop` | 32.48 | 3.2 | 0.9 | yes | the IRONSIGHT alarm (warble) |
| `generator_loop` | 35.8 | 8.0 | 0.6 | yes | the substation generator |
| `drip_1`, `drip_2`, `drip_3` | 43.92, 46.24, 48.56 | 2.2 each | 0.7 | no | water drips with a small room tail |
| `gun_far_1`, `gun_far_2`, `gun_far_3` | 50.88, 57.5, 64.12 | 6.5 each | 0.6 | no | distant bursts with long echo tails |

**The asset is not uploaded and `Sounds.AMB_ATLAS` is the empty string.** Until the owner's session uploads it and sets the id, every
sound above stays silent: `AmbSound.make` returns nil, the controller never creates a Sound, the siren and the generator are never
built. Reverb and dust work without it.

## 5. Cost

- **Per frame:** one `Heartbeat` callback that adds `dt` and compares (no work until 0.08 s have passed). Nothing is created or
  destroyed per frame, and no work is done per part.
- **Every 0.08 s (12 per second):** three layer fades (a multiply-add each, one `Volume` write for each layer that is audible), the
  one-shot timers, the dust timer.
- **Every 0.4 s:** one probe: **at most 8 raycasts** (2 + 6) with a filter of 5 or 6 instances, a few dozen arithmetic operations, one
  enum compare and at most one `AmbientReverb` write. 20 rays a second in total, the same size as the existing indoor probe in `Post.luau`
  (5 rays every 0.25 s), which stays as it is: Post and Atmos keep their own "indoor" measure for exposure and for the wind and rain beds.
- **Every 1.2 s, and only at MEDIUM and above indoors in a raid by day:** one `GetTagged("ZR_Skylight")` (at most 41 streamed panes), a
  sort of at most a few dozen, up to 6 part moves and rate writes (a rate is only written when it changes).
- **Instances:** 3 layer Sounds, 3 drip + 3 gun Sounds with 6 Attachments (created the first time each is used, never destroyed),
  at most 6 dust parts and 6 emitters (about 14 to 36 live motes each, so at most about 220), plus on the server one Sound on the siren
  beacon and one on the generator. Sounds playing at once: at most 2 loops from this controller (room or car park tone, and the hum),
  one drip, one gunshot; plus the siren or generator when near. A layer that has faded out is paused; with the ambience volume at 0
  every layer fades out and pauses and no drip or gunshot is started.
- **Memory:** the file is 698 KB (Env atlas: 521 KB). Roblox may hold it decoded (about 6 MB of 16-bit mono PCM); not measured.
- **Reverb DSP** is the one cost this pass cannot make cheap on its own: any `AmbientReverb` other than NoReverb runs a reverb on the
  mix. So POTATO has no reverb at all, LOW only indoors, MEDIUM and HIGH everywhere.
- **Not measured:** no frame time or memory was measured. The 30 fps rule is met by design (the numbers above), not by test; the
  separate-client frame-rate check in `NEXT_TASK.md` should be run again with the asset in.

Graphics levels: POTATO (0) no reverb, no dust; LOW (1) reverb indoors only, no dust; MEDIUM (2) and HIGH (3) everything. The sounds
themselves do not depend on the level.

## 6. Gaps (also in `docs/design/EFT_PARITY.md`)

- **No per-source reverb or occlusion.** Tarkov (Steam Audio) computes reflections and occlusion for each sound from the geometry
  between it and the listener. Roblox has one `AmbientReverb` for the listener and no occlusion, so a shot in a hall heard from a washroom
  gets the washroom's reverb, and the siren and the generator are heard through walls within their radius. Roblox rule, exception 3.
- **Mall soundscape, ambient gunfire and dust shafts are our design** (section 1): no Tarkov source describes them. Ambient gunfire is
  also a deviation in kind: Tarkov's distant shots are real fights. Ours are scripted, harmless and not tied to anyone; they are only
  in raids, once a minute or two.
- **Siren length** follows the 60 s of the existing lamp and AI call; Tarkov's is not documented.
- **Dust is a column under the pane, not the lit parallelogram**: it does not follow the sun's slant, and the light is Roblox's
  (the glass panes do not cast shadows, so the sun reaches the floor through every skylight).
- **Machines and mall details with power on** (escalators, arcade, music, announcements, lifts) are not built; only the hum.
- **Weather indoors:** rain on the roof is Atmos's existing layer; wind through the building is not added.
- **Not verified in the engine:** `Sound` region semantics are not described on any Roblox page I could read (the Sound class page lists
  the properties without text; the `Stop` and `Play` pages only show that `Stop` then `Play` restarts at time 0). The code starts every region
  the same way the existing atlases do (create, region, `Play`) and restarts a one-shot with `Stop` then `Play`. The `RollOffMode`,
  `SoundService` and `Sound` pages were blocked by the fetch tool; `Enum.RollOffMode.Linear` is looked up through pcall and falls
  back to InverseTapered. Which sounds `AmbientReverb` is applied to (every sound, or only positional ones, UI and music included
  or not) is also not stated on any page read; the 24 `ReverbType` names were read from the enum page.
- **Pre-existing, not touched:** in `Atmos.luau` the local `snowing` is used in `step` (about line 231 of the file at the time) before
  its declaration (about line 246), so it is a global read that is always nil there. Reported, not changed.

## 7. What has to be done next

1. **Owner's session:** upload `assets/audio/out/ZR_SFX_Amb.ogg` (Open Cloud, audio, same way as the other atlases), then set
   `Sounds.AMB_ATLAS = "rbxassetid://<id>"` in `src/shared/Sounds.luau`. Never put in an id that was not returned by the upload.
2. **Listen and set the levels:** `LAYERS` (room 0.11, car park 0.22, hum 0.085), `DRIP_VOL` 0.09 and `GUN_VOL` 0.25 in
   `Ambience.luau`; the siren and generator ranges in `Play.luau` and `Outside.luau` (min 14 / max 150, min 7 / max 85).
3. **Tests:** six checks were added at the end of `src/server/Tests/LogicTests.luau` ("atmosphere ...": the atlas, the sound maker, the
   `Enum.ReverbType` names, the published switch state, the lever's wrapper, the skylight tags and floor marks). They have **not
   run**; `ZR_Dev:Invoke("tests")` should now show six more LogicTests than the baseline in `NEXT_TASK.md`.
4. **Studio checks** (client bridge, `execute_luau` in the client data model: `ZR_ClientDev:Invoke("ambience", true)` returns the space
   class, the reverb, the measurements, the layer levels, dust emitters lit and the ray count): the car park L0 reads `carpark` /
   `ParkingLot`; an anchor hall reads `hangar` / `Auditorium`; a L1 gallery `corridor` or `hall`; a washroom `mark:Bathroom`; a shop
   `room`; the open ground `outdoors`; the substation switch hall `room` or `hall`; the hum is on only after the lever is thrown;
   the siren starts 3 s after the IRONSIGHT front door opens and stops at the terminal; no warnings in the output with the id empty.
5. **Frame rate** with the id set, at HIGH and MEDIUM, in the car park, a hall under skylights and the bunker, in the front window.
