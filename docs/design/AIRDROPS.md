# Airdrops

Built 2026-11-02. Code:
- `src/server/Services/Airdrop.luau`: the roll, the drop points, the landed crate.
- `src/client/Controllers/AirdropFx.luau`: the plane, its flares, the falling crate.
- `Loot.spawnCrate` and the four `airdrop_*` pools in `Loot.luau`.

## Tarkov (researched 2026-11-02)

**Maps.** Airdrops come on every map except Ground Zero, Factory, The Lab and The Labyrinth. That includes Customs and
Interchange, which Border Yard and Meridian Mall copy.

**The plane.** An IL-76MD-90A flies over the drop position, fires countermeasure flares at intervals, releases the
crate and turns away.

**The crate.**
- It comes down under a parachute.
- Once down it gives off red smoke that can be seen across the map.
- Four kinds, each a 10 x 12 grid, sometimes with a bonus backpack:
  - **Common supply** (unmarked): barter goods, meds, weapons, ammunition, gear.
  - **Medical** (a cross): meds and provisions.
  - **Supply** (a box symbol): barter goods.
  - **Weapon** (a crosshair): weapons, mods, ammunition.

**When.** The numbers come from each map's location data, recorded in our layouts on 2026-11-01 as `L.hazard.airdrop`:
- Customs and Interchange: a 20 % chance per raid;
- at least 6 players in the raid;
- the first plane 300 to 900 s in;
- a cooldown: Customs 600 to 700 s, Interchange 800 to 900 s.

The location data allows one plane per raid.

**Red flares.** A red flare (the RSP-30 or a signal pistol cartridge) fired skyward calls a plane to that spot. The
calls have a 15 to 17 minute cooldown ("Airspace is congested").

Sources:
- [BoostMatch: Tarkov airdrops 2026](https://boostmatch.gg/blog/escape-from-tarkov/articles/tarkov-airdrops-event-2026-guide)
- [ItemLevel: flares and airdrops (2022)](https://itemlevel.net/everything-you-need-to-know-about-flares-and-airdrops-escape-from-tarkov/)

## Ours

**The roll.**
- A new raid on Border Yard or Meridian Mall rolls its map's `L.hazard.airdrop`.
- At the rolled time the plane comes if at least `minPlayers` are alive in the raid. People and AI both count; Tarkov does
  not publish what it counts.
- One plane per raid.

**Drop points.** They are found once per map from the built world:
- terrain under open sky, level within 2 studs for 14 studs round;
- not in water;
- 70 studs or more from the map's exits and spawns;
- 220 studs or more apart.

Border has 41 points and Meridian 80. A drop takes one of them at random.

**The plane.**
- A four-engine high-wing transport, 46 m long with a 50 m span, built from parts.
- It flies a 3,200-stud run at 420 studs (about 135 m) and 140 studs a second, over the point.
- It fires a pair of flares every 2.6 s while it is near the drop.
- Every client draws it from one fx message, so it moves smoothly.

**The crate.**
- It leaves the plane over the point and sinks at 7 studs a second under a canopy on four lines, which takes about a
  minute.
- The server places the real crate on landing: an olive box on a pallet with its kind's marking, the canopy collapsed
  beside it, and red smoke for 5 minutes.
- It is searched like any container (`Loot.spawnCrate`, 10 x 12) and goes at the raid's end.

**Kinds.** Their weights are ours:

| Kind | Weight | Items |
|---|---|---|
| common | 4 | 10 to 16 |
| medical | 2 | 12 to 18 |
| supply | 2 | 10 to 15 |
| weapon | 1.5 | 6 to 10 |

**The red flare (built 2026-11-02).** `FLARE_RED`, our "Red Signal Flare": 1 x 2, 0.19 kg, gone after one shot.
- **Where it turns up:** crates, jackets, weapon boxes and toolboxes, now and then.
- **Using it:** USE in the inventory, or a quick slot. It goes through the med "use" path: a 1.2 s hold, then the shot.
- **Open sky only:** under a roof it is refused with "Fire the flare under the open sky." and not used up.
- **The star:** fired outdoors, a red star climbs about 130 studs, hangs and sinks for 9 s with a glare and a smoke trail.
- **The call:** on a map with airdrops it calls a plane to drop within 15 studs of the spot 90 to 150 s later.
- **Congested airspace:** a second call before the plane comes, or within Tarkov's 15 to 17 minutes after the last
  call, gets "WAIT FOR ARRIVAL! AIRSPACE IS CONGESTED". That flare still fires.

**Dev commands (ZR_Dev `airdrop`):**
- `airdrop(kind, x, z)`: send a plane now;
- `airdrop("force", true / false / nil)`: plane in every raid / in none / roll;
- `airdrop("points")`: list the drop points;
- `airdrop("status")`: this raid's plan.

**Checked in Studio (2026-11-02, one player).** A forced weapon crate on Border Yard:
- the plane crossed overhead;
- the crate came down under its canopy and landed after 71 s;
- the smoke rose;
- the search revealed a built rifle, two magazines, 108 rounds and a grenade.

Pictures: `docs/maps/evidence/BY_airdrop_plane.jpg`, `BY_airdrop_falling.jpg`, `BY_airdrop_landed.jpg`.

**The red flare, checked in Studio the same day:**
- under the fuel stop roof it was refused and kept;
- in the open its star climbed and burned (`BY_red_flare.jpg`);
- a common crate landed 191 s later, 8 studs from the spot;
- a second flare 20 s after the first fired but called nothing: still one crate at 261 s.

## Gaps (also in `EFT_PARITY.md`)

- **The plane is silent.** It plays the generator drone pitched down, there is no plane sound in the atlases, and the
  ambience atlas asset currently loads as 0.0 s long (KNOWN_ISSUES). A real engine sound needs an upload from the owner's
  machine.
- **The flare is used from the inventory or a quick slot.** Tarkov fires it from a special slot, which we do not have,
  and there is no flare gun (Tarkov's signal pistol).
- **No green or yellow flares** (flare exits, quests).
- **Drop points are found, not placed.** Tarkov uses fixed drop zones per map; ours are open, level spots found from the
  world.
- **No bonus backpack** in the crates, and no wait to open a crate before the search.
- **The plane and the crate are built from parts**, not meshes.
