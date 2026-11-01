# Border Yard's night group (THE CULT, Tarkov's cultists)

Status 2026-11-02: **built and checked in Studio with one player** (TEST_RESULTS "THE CULT").

## What Tarkov does

- **The group:** a Cultist Priest and two to four warriors. The timesaver guide's stats table says 2 to 4 followers; the
  wiki says groups of 3 to 5 by map. An older source says 4 to 7.
- **Where and when:**
  - Night raids only (v-tarkov: 23:00 to 06:00).
  - Customs at 20 % (tarkovforge, live from tarkov.dev), "~20 to 25 %" (timesaver, patch 1.1.5, September 2026).
  - Placement on Customs:
    - tarkov.dev: the Stronghold;
    - timesaver: the crackhouse and garage area and the construction area;
    - an older source: near ZB-013.
  - Also on Woods (20 %), Shoreline (17 %), night Factory (8 %) and Ground Zero 21+ (2 %).
- **Health:** the priest has 850 (head 50, thorax 200, stomach 200, each arm 100, each leg 100). No armour to speak of:
  a cloth robe (2026). An older source says class 5 and 6.
- **Behaviour:**
  - The warriors lie prone in the dark to ambush.
  - When a player comes close they stand and chase to stab with a knife, normal or poisoned.
  - If the stealth fails they fall back to firearms (older source: SMGs and silenced rifles with AP rounds).
  - The priest never speaks.
- **The poison:** the knife's toxin keeps hurting after the fight and does not clear on its own. Only an antidote stops it
  (older source: Augmentin or the xTG-12 antidote).
- **Loot:** the cultist knife (the signature drop), keys and keycards, tech and intel, meds, melee weapons.
- **Sources:**
  - [tarkovforge: Cultist Priest](https://tarkovforge.com/bosses/cultist-priest);
  - [timesaver.gg: Cultist Priest guide (patch 1.1.5, 2026-09-28)](https://timesaver.gg/blog/tarkov-cultist-priest-boss-guide);
  - [v-tarkov: the priest (older numbers)](https://v-tarkov.ru/en/boss/boss-zhrets).

## Built (2026-11-02)

- **THE CULT on Border Yard** (`Maps/Border/Play.luau`, "cult"):
  - a priest and two to four warriors, rolled at 20 %, only in a raid that starts in the dark;
  - three zones, one picked per raid: either side of THE SQUAT (the crackhouse) and the south side of THE FRAME (the
    construction site). The Stronghold is THE HOUNDS' home.
  - `ZR_Dev boss(true, "Priest")` forces them in.
- **Health:** priest 850; warriors 440.
- **Lying in wait** (`AI.luau`, `ambush`):
  - Each holds its own post prone in the grass, still and silent.
  - Within 22 studs it picks anyone out all round, dark or not.
  - A target within the knife's run and in sight brings it to its feet with the knife.
  - A hit makes it give up hiding and fight on with its suppressed SMG as well.
- **The knife** (the hammer charge generalised, `AI.MELEE`):
  - Runs from 40 studs at 17.
  - Stabs within 4 studs every 0.85 s for 36 (pen 14), 15 % of them at the head.
  - Every wound poisons.
  - The Stoker's hammer is unchanged.
- **The poison** (`Health`, `toxin`): 1 hp/s spread over the body by each part's share, faster thirst and hunger,
  trembling hands, and "POISONED" with a skull among the effects. It lasts until an **antidote injector** (`ANTIDOTE`,
  one use, 3 s) stops it.
- **Items:**
  - `ANTIDOTE`: 38,000; HALE at loyalty 3; some cultists carry one.
  - `RITUAL_KNIFE`: the looted knife, 42,000; it cuts like the field knife.
  - `RITUAL_AMULET`: the priest's valuable, 120,000.
- **Kits** (`Loot.cultistLoadout`, `priestLoadout`):
  - robes and no armour, a black beanie and gaiter;
  - a suppressed SMG-9 with AP rounds, a bandage;
  - the ritual knife (warriors half the time, the priest always), the antidote now and then;
  - the priest: the amulet (60 %) and more loot.
- **Looks** (`Equipment.luau`): dark brown robes; the priest near-black with a dark red armband.

## Gaps (also in `EFT_PARITY.md`)

- **No raised hood.** The hood mesh hangs down the back, so a black beanie covers the head. A hood-up mesh needs an
  upload from the owner's machine.
- **The toxin's numbers are ours.** No source gives its damage or its effects beyond "keeps hurting until an antidote".
- **One antidote.** Tarkov also cures it with Augmentin.
- **The looted knife does not poison** and has the field knife's stats.
- **The night window:** the cult rolls when the raid starts in the dark. With our 7x clock a night raid stays dark;
  Tarkov's exact hours are not applied.
- **Zones are ours:** the posts sit round three spots near the places the guides name.
- **No keys or keycards** in their loot rolls beyond the dorm pool.
- **No other maps.** They are only on Border Yard.
- **No ritual circles, no marked items** (Tarkov's cultist circle is a hideout feature, not built).
