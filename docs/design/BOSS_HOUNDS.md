# Border Yard's second boss group (THE HOUNDS, our Goons)

Status 2026-11-02: **built and checked in Studio with one player** (TEST_RESULTS "THE HOUNDS").

## What Tarkov does

- **The group.** Three bosses who move together:
  - Knight, the leader, pushes your position.
  - Big Pipe, the grenadier, flushes cover with a grenade launcher.
  - Birdeye, the marksman, holds long angles and watches over the others.
- **Where.** Customs 20 % (at the Stronghold, our Bastion; tarkovforge "live from tarkov.dev"); timesaver's 1.1.0 guide
  gives "roughly 15 %". Woods, Lighthouse and Shoreline have the same chance. They rotate between those maps and roam
  rather than hold one spot.
- **Health.**

  | | Head | Thorax | Stomach | Each arm | Each leg | Total |
  |---|---|---|---|---|---|---|
  | Knight | 80 | 220 | 220 | 150 | 150 | 1,120 |
  | Big Pipe | 70 | 220 | 200 | 110 | 100 | 910 |
  | Birdeye | 70 | 175 | 150 | 100 | 100 | 795 |

- **Gear named by the wiki:**
  - Knight: the CPC plate carrier, Goons edition (a class 5 armoured rig) and the Death Knight mask (a class 1 face
    cover). His head is otherwise unarmoured (timesaver), and he is known for his panoramic goggles.
  - Big Pipe: his bandana and his smoking pipe, no helmet.
  - Birdeye: a class 4 concealable vest, a chest rig (Goons edition) and a radio frame pack. His clothes are a Baja-style
    jacket and woodland pants.
  - All three have **five double pockets** (ten cells) instead of the usual four.
- **Sources:**
  - [tarkovforge: Knight](https://tarkovforge.com/bosses/knight), [Big Pipe](https://tarkovforge.com/bosses/big-pipe),
    [Birdeye](https://tarkovforge.com/bosses/birdeye);
  - [timesaver.gg: Goons guide (patch 1.1.0, updated 2026-09-21)](https://timesaver.gg/blog/tarkov-goons-boss-guide);
  - Fandom: [Knight](https://escapefromtarkov.fandom.com/wiki/Knight),
    [Big Pipe](https://escapefromtarkov.fandom.com/wiki/Big_Pipe),
    [Birdeye](https://escapefromtarkov.fandom.com/wiki/Birdeye).

## Built (2026-11-02)

- **A second boss group on Border Yard** (`Maps/Border/Play.luau`, "hounds").
  - `W.bosses` holds THE BROKER and THE HOUNDS. Each is rolled on its own, THE HOUNDS at 20 %.
  - They start at the Bastion yard (`BASTION_YARD`, our Stronghold).
  - They walk a 10-point loop of the map: the Bastion, the dorms side, the gas station side and back. Every leg was
    checked with the pathfinder.
  - `ZR_Dev boss(true, "Halberd")` forces them in.
- **Three men of their own.** A crew entry in `AI.reset` can now carry its own look, kit, health, label and skill.
  - **HALBERD** (Knight) leads. **MORTAR** (Big Pipe) and **KESTREL** (Birdeye) spawn as his crew.
  - All three fight with the boss's skill (`opts.skill`).
  - Health is Tarkov's: 1,120, 910 and 795 (`hp` = total / 440).
- **Looks** (`Equipment.luau`):
  - HALBERD: black, with a tan armband;
  - MORTAR: olive, with a black armband;
  - KESTREL: brown-green, with a hood.
- **Kits** (`Loot.halberdLoadout`, `mortarLoadout`, `kestrelLoadout`):
  - **HALBERD:**
    - a class 5 vest under a black chest rig;
    - a goggle head mount, with the panoramic NV-4 in 35 % of raids;
    - a black gaiter;
    - the R-17 close-quarters build with AP rounds and three spare magazines, and the P-9 with a spare;
    - a field medkit, a hemostat, a grenade, sometimes a gold chain, dorm loot.
  - **MORTAR:**
    - a class 5 vest, a chest rig, a beanie (no head armour);
    - the KS-7 with BP rounds and three spare magazines;
    - six grenades (three F-7, three RK-5): the AI throws them at cover;
    - a field medkit, painkillers, a splint, crate loot.
  - **KESTREL:**
    - a class 4 vest, a chest rig, a frame pack, a class 3 helmet;
    - the R-17 marksman build (a 1-6x scope) with four spare magazines;
    - two smoke grenades, a road kit, painkillers, a red flare in 30 % of raids, dorm loot.
- **Five double pockets** (`Inv.luau`, `pocketsW` 5 x `pocketsH` 2).
  - A kit's holder can have Tarkov's Goon pockets: five pockets of 1 x 2, ten cells.
  - Each column is one pocket. An item lies one cell wide in it (a 2 x 1 item turns upright), and nothing bigger than 2 cells
    goes in. The same rule applies when placing by hand, auto-placing and in `Inv.check`.
  - The loot screen draws the body's pockets as 5 x 2 (`pocketsW` and `pocketsH` in the view).

## Gaps (also in `EFT_PARITY.md`)

- **One launcher round.** Since 2026-11-08 (ai-5b) MORTAR carries the GL-6 six-shot launcher (our M32A1) with 40x46
  HE rounds, lobs them past 13 m and takes his KS-7 inside 7 m, since a round arms only after about 20 m; EFT's other
  40x46 rounds (buckshot, HEDP) are not in.
- **No Mk47, no 7.62 x 51 marksman rifle.** HALBERD uses the R-17 close-quarters build and KESTREL the R-17 marksman build.
- **No skull mask item.** HALBERD wears a black gaiter: cosmetic, where Tarkov's mask is class 1 for the face.
- **No bandana or pipe items.** MORTAR wears a beanie, also no protection.
- **No class 5 armoured rig.** HALBERD wears a class 5 vest with a chest rig on top.
- **Ours, not Tarkov's:**
  - KESTREL's class 3 helmet (no source names Birdeye's head gear);
  - the NV-4 chance;
  - the loot rolls.
- **One map only.** They do not move between Border Yard and the other maps, and there is no tracker.
- **One AI for all three.** They share the boss's skill: HALBERD does not push harder and KESTREL does not hold long
  angles on purpose.
- **Even health spread.** The body's parts scale evenly from 440, not Tarkov's per-part numbers above.
- **No new meshes.** The looks reuse existing overlays and gear.
