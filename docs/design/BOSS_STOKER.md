# Meridian's second boss (THE STOKER, our Tagilla)

Status 2026-11-02: **built and checked in Studio with one player** (TEST_RESULTS "THE STOKER"). The research and the
plan below are from 2026-11-01. What was built, and what is left, follows the plan.

## What Tarkov does

- **Interchange has two bosses, each rolled on its own.** Killa: 60 %, spawns at Center, OLI, IDEA or Goshan, hunts alone (our THE CARETAKER, built). Tagilla: about 35 % in the 2026 Season 1 sources (patch 1.1.0), no guards, spawns in the parking garage under Goshan; that is our KASSA GARAGE. The reference layout already has his marker at L0 (756.2, -431.2); the garage spans x 640.6 to 881.2, z -571.9 to -146.9. That both can be in one raid is Tarkov's usual per-boss roll, not stated outright by a 2026 source: an assumption.
- **Health** 1,220 in all: head 100, thorax 320, stomach 260, arms 130 each, legs 140 each.
- **Armour:** a class 6 plate carrier on the thorax only, no helmet, a welding mask as a face cover (class 5, durability 40, 50 % blindness protection, 1.5 kg).
- **Weapons:** a sledgehammer that cannot be looted; a semi-auto 12 gauge shotgun with slugs, or a flechette shotgun, sometimes a short rifle.
- **Behaviour:** active from the raid start, loud (yells, heavy steps), aggressive on sight. He shoots from about 15 m, then charges in a straight line and kills in one hit on contact. Shooting him mid-charge does not stop him; leg hits slow him. He switches to the gun when he cannot reach you, and can ambush, lay down suppressive fire and breach.
- **Sources:** [tarkovforge Interchange](https://tarkovforge.com/map-guide/interchange), [tarkovforge Tagilla](https://tarkovforge.com/bosses/tagilla), [tarkovforge Killa](https://tarkovforge.com/bosses/killa), [timesaver.gg Tagilla, 2026](https://timesaver.gg/blog/tarkov-tagilla-boss-guide), [thetarkovhandbook Interchange](https://thetarkovhandbook.com/Interchange.html), [Fandom: Tagilla](https://escapefromtarkov.fandom.com/wiki/Tagilla) (its Interchange page is out of date), [diamondlobby: how to kill Tagilla](https://diamondlobby.com/escape-from-tarkov/how-to-kill-tagilla-in-escape-from-tarkov/), the tarkovforge pages for his two welding masks and his plate carrier, and [diamondlobby: sledgehammer](https://diamondlobby.com/escape-from-tarkov/where-to-find-the-sledgehammer-eft/).

## Plan

1. **Several bosses per map.** `W.bosses` as a list ("bosses" in `PER_MAP` and `beginMap` in `World.luau`); in `AI.luau` a reader that still takes the old single `W.boss`, a testable roll per boss with forcing per boss, and the raid's list of bosses. `Dev.luau`: `boss(on, id)` forces one; `ai` lists each boss. He keeps kind "boss", so kills, XP and tasks count, and the death screen shows "KILLED BY STOKER".
2. **The hammer charge in `AI.luau`** (no change to `Combat.luau` or `Weapons.luau`): sprint straight at the target, swing within reach with the existing "slash" gesture, deal the hit through `ctx.Combat.hitModel`. The hammer is a few cosmetic parts in his hand (the animator only has the knife's one-hand pose). The shotgun at range or with no path. Health scale about 2.77 (1,220 / 440).
3. **Open decision, the mask:** `Health.luau` only takes face armour from the head slot. Either the mask is a head-slot item, or `Health.luau` lets the face-cover slot protect the face (Tarkov's way).
4. Items in `Items.luau`, a `stokerLoadout` in `Loot.luau` (we only have a pump shotgun, so the semi-auto is a gap), his look in `Equipment.luau`, the KASSA GARAGE entry and route in Meridian's `Play.luau` at 35 % (`Layout.luau` is generated, not edited by hand), LogicTests, then the docs.

## Built (2026-11-02)

- **Two bosses on Meridian, each rolled on its own.** `W.bosses` is a list, and `AI.reset` rolls every entry on its
  own: THE CARETAKER at 60 %, THE STOKER at 35 %. `W.boss` stays the Caretaker for the old readers.
  - `ZR_Dev boss(on, label)` forces one boss in or out; `boss(on)` still forces all.
  - The per-map fields include `bosses`.
- **THE STOKER** (`Meridian/Play.luau`): alone in the KASSA GARAGE on a six-point route from the reference's hammer
  marker (L0 756, -431).
  - Health 1,220 (`hp` = 1,220 / 440 on the body's parts).
  - Look `stoker` (`Equipment.luau`): navy work clothes, a scorched leather vest, knee pads.
  - Kit `Loot.stokerLoadout`: the welding mask, a class 6 carrier, a chest rig, the Harrow-12 with slugs (70 %) or
    buckshot, meds and a little mall loot.
- **The welding mask** `MASK_WELDER`: a face cover, class 5, durability 40, 1.5 kg, blindness protection 50 %.
  `Health.armorFor` now lets a face cover with `zones.face` take hits on the face (jaw and eyes, not the crown), as
  Tarkov's face covers do (CharTests C13).
- **The hammer charge** (`AI.luau`):
  - Within 15 m (47 studs) of a target he can see, with nothing between them, he takes the sledgehammer off his back
    and runs straight at the target at 18. Shots do not stop him; broken legs slow him (`Health.mods`).
  - Within 4.6 studs he swings: the knife's "slash" gesture, the blow 0.3 s later if the target is still in reach,
    60 % at the head, 110 damage at pen 35 through `Combat.hitModel`.
  - The raid report reads "KILLED BY STOKER · SLEDGEHAMMER · BLUNT · HEAD".
  - Otherwise he fights with the shotgun. The hammer is not in his kit, so it cannot be looted.

## Gaps (logged in `EFT_PARITY.md`)

- **No mesh for the mask yet.** New meshes are uploaded from the owner's machine, so it wears the faceplate helmet's
  plate in blackened steel. A player who loots and wears the mask sees the gas mask's frame, not a welding slit.
- **The hammer is three parts.** It goes into his hand when he charges, but the arms keep the shotgun pose.
- **His gun is the pump Harrow-12.** Tarkov's is a semi-auto 12 gauge.
- **No flechette rounds.**
- **No yell.** A heavy breath plays when he starts to run.
- **Health spread.** The body's parts scale evenly (thorax 235). Tarkov's thorax is 320.
- **Ambush and breaching are not built.**
