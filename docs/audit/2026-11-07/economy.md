# Economy audit: loot, items, traders, flea market, quests, hideout, progression

Area id: `economy`. Audited 2026-11-07 against the repo at `/home/claude/EscapeFromBloxov` (build `0.9.2-m13`) and EFT as
of late 2026 (1.0 on 15 Nov 2025, 1.1.0 "Kord Breach" on 3 Aug 2026, 1.2.0 on 6 Oct 2026). Nothing in the repo was
changed.

Terms used: **FIR** = found in raid (EFT's tag that lets an item be sold on the flea market or handed in for a task).
**LL** = trader loyalty level (1 to 4). **MK** = our currency. **EV** = expected value (the average a roll gives).
**SPT** = the community single-player server whose data copies EFT's loot tables.

## Current state

Everything below is built and runs in Studio (one player, in-memory profiles). Nothing has run against the real
DataStore or with two players.

| Part | What exists | Key files |
|---|---|---|
| Item catalogue | 281 definitions, of which 279 are real items (2 are blast hazards): 6 guns and 2 knives, 96 weapon parts, 10 magazines, 13 rounds in 5 calibers, 5 armours, 5 helmets, 3 rigs, 5 packs, 3 secure pouches, 11 meds, 6 foods, 4 grenades, 2 flares, 58 keys, 2 task items, 35 barter and valuable items. Every item has weight, grid size, value and rarity. | `src/shared/Items.luau`, `WeaponParts.luau`, `ItemIcons.luau`, `ItemMeta.luau` |
| Loot | 13 container kinds, each with one global loot pool (`Loot.luau:21-36`); 31 pools in all (`:40-238`); loose-loot spots with a chance and a pool per spot; airdrops (20 %, 6 alive, 10 x 12 crate, 4 kinds, red flare); keys with uses and locked rooms (Border Yard 37 keys, Meridian 15). Border Yard has 534 containers, Meridian about 420. Every container is filled in every raid (`Loot.luau:557-563`). | `Loot.luau`, `Airdrop.luau`, `World.luau`, map `Play.luau` files |
| Stash and inventory | Stash 10 x 20, 10 x 25 and 10 x 30 with storage racks (`Config.luau:32-33`, `HideoutData.luau:45`); pockets 4 x 1; nested rig, pack and secure grids; a non-empty container cannot go into another (`Inv.luau:303-305`); secure pouches S 2 x 2, M 3 x 3, L 4 x 3, but only S is ever given. | `Inv.luau`, `Items.luau:136-138, 324` |
| Traders | 4: VOS (weapons, ammo, parts, repairs), HALE (meds, food), TILDA (armour, gear, eyewear, goggles), FENCE (buys anything). LL 1-4 from level, money traded and standing, 5 % cheaper per LL, per-player stock limits per 30-minute restock, 12 barters, repairs, gun presets. One currency. | `TraderData.luau`, `Economy.luau`, `client/Controllers/Trade.luau` |
| Flea market | Level 15, FIR-only offers (parts too), EFT's fee formula with 3 %, offer slots by rating, rating +0.01 per 50,000 sold, 12 h offers, purchases not FIR, sales in the messenger. The other sellers and all buyers are simulated. | `FleaRules.luau`, `Flea.luau`, `client/Controllers/Menus.luau:231+` |
| Tasks | 13 tasks in 4 short chains (VOS 4, HALE 4, TILDA 4, FENCE 1); objective types kill, hand in FIR, extract, visit; rewards money, XP, standing, FIR items. | `QuestData.luau`, `Quests.luau` |
| Hideout | 5 modules, 8 levels (generator, medstation 2, workbench 2, storage racks 2, water collector), one build at a time, 10 crafts, real-time timers that run offline; wall, floor and ceiling styles; a free firing range in the lobby. | `HideoutData.luau`, `Hideout.luau`, `HideoutStyle.luau`, `Range.luau` |
| Progression | XP to level 40 on `1000 x (level-1)^1.5`; 24 skills to level 51 with EFT's point cost and raid fatigue; weapon mastering; scav karma -3 to 3; run-through at 7 min and 200 XP; dog tags; insurance at 7 % with returns 15 min after the raid. | `Progress.luau`, `Economy.luau`, `Settle.luau`, `Config.luau:14-18` |
| Persistence | One DataStore key per player with a session lock; in Studio an in-memory store. | `Store.luau`, `Profiles.luau`, `Settle.luau` |

How complete: the loop works end to end (TEST_RESULTS "M9 Economy", lines 1179-1194), and the rules copied so far are
close to EFT's. What is thin is the content and the balance: about a tenth of EFT's items, a fortieth of its tasks, a
fifth of its hideout, a seventieth of its barters, and money that piles up with almost nothing to spend it on.

## Strengths

- **The systems are server-authoritative and idempotent.** Raids settle by raid id, loadouts are held in escrow, every
  trade, craft and sale is checked on the server (`Settle.luau:151-179, 338+`, `Economy.luau:144-183`).
- **Many EFT rules are already exact:** the flea fee formula and constants, the offer-slot table and the starting
  rating (`FleaRules.luau:13-43`, matching the wiki's table); the run-through rule (7 min / 200 XP, matching EFT's FIR
  page); FIR-only flea offers; quest rewards are FIR; skill point costs and raid fatigue; selling needs examined, empty
  items; repairs that lower the maximum.
- **Airdrops are a close copy** of EFT's numbers (20 %, 6 players, 300-900 s, one plane, red flare with the 15-17 min
  "airspace is congested" rule; `docs/design/AIRDROPS.md`).
- **Keys and locked rooms follow EFT's maps:** Border Yard's 37 keys and Meridian's 15 keys with EFT-style use counts
  (`Items.luau:183-245`), electric locks that need the mall power.
- **Item data is already rich enough to grow:** every item carries weight, size, value, rarity and kind blocks, and
  the Blender picture pipeline makes new items cheap to draw.
- **The trader, flea, messenger, handbook and wish-list screens exist**, so new content only needs data.

## Findings

Ranked by severity, then by how much they matter.

### P0

1. **P0: Progression persistence has never run against a real DataStore.** Every trader level, task, hideout build,
   flea offer and stash item lives in the profile, and in an unpublished place profiles live in memory only, so
   nothing here survives a restart and the lock, retry and size paths are unproven. Publishing privately to test it is
   the owner's call (project rule 3). Evidence: `KNOWN_ISSUES.md` items 1 and 33; `Store.luau:20-31` (falls back to
   memory); `TEST_RESULTS.md` line 9 ("NOT VERIFIED: real DataStore").

### P1

2. **P1: Money has almost nothing to be spent on, and the flea pays up to 3x the traders.** Simulated buyers keep
   buying overpriced offers: at 1.6x the market price (1.84x an item's value) an offer sells at 1.2 % a minute, so on
   average in 83 minutes and 99.98 % of the time within its 12 hours; after the 9.8 % fee the seller nets about 1.74x
   value, against 0.55x at the best trader. Even 2.875x value sells 76 % of the time. Demand never runs out. On the
   other side the whole hideout costs 785,000 MK once (EFT's Stash module alone costs about 44.7 million roubles), all
   13 tasks pay 647,000 MK, and there is no fuel, filter, scav case or other recurring cost. Most containers
   hold about 24-35k MK of loot on average, a drawer about 53k and a safe about 137k (my EV estimate from the pool
   weights and item values), and Border Yard has 534 containers. Expect money to stop mattering after a few raids. Evidence: `FleaRules.luau:84-98`,
   `Flea.luau:76-80`, `TraderData.luau:14-33`, `HideoutData.luau:7-41`, `QuestData.luau:23-67`, `Loot.luau:557-563`;
   `KNOWN_ISSUES.md` 23 ("first-pass").
3. **P1: Every container is filled in every raid, from pools shared by all maps.** EFT rolls containers: SPT's
   Interchange data draws 269-325 of 823 grouped containers per raid plus 130 that always spawn, and each container
   has a spawn probability of 0.08 to 0.71 (mean 0.28); each map has its own tables. Ours fill all of them from one
   pool per container kind, so a toolbox on Border Yard rolls the same items as one in the mall, and loot density is
   two to three times EFT's. Evidence: `Loot.luau:21-36, 547-563`; `docs/design/EFT_PARITY.md` line 409 ("Every
   container is filled in every raid"); `docs/maps/reference/INTERCHANGE_REFERENCE.md` section 8.4.
4. **P1: There are 13 tasks, all from before the new maps, against EFT's 531.** The tasks name Quay 7's places and
   the Foreman; Border Yard defines visit zones (DORM314, BOILER, DERRICK, FRAME, SMUGGLERS), and Meridian and Smelter
   define theirs, but no task uses them. Only four objective types exist (no plant or mark, no conditions on gear,
   weapon, distance or time, no quest items to find, no daily or weekly tasks, no task-locked trader offers). Evidence:
   `QuestData.luau:2-6, 23-75` (zone names only PIER3 and RELAY), `Maps/Border/Play.luau:8, 843-851`,
   `Maps/Smelter.luau:733`; `KNOWN_ISSUES.md` 24; EFT count from tarkovforge's task guide.
5. **P1: Progression is much shorter and faster than EFT's, and the status doc says the opposite.** Level 15 (the
   flea) needs 52,383 XP here against 161,139 in EFT; the cap is 40 (EFT's top level takes 82.6 million XP); every
   trader reaches LL4 at level 12 with 1.2 million MK traded (EFT: levels 33-42); builds take 5-40 minutes and crafts
   15-45 (EFT: hours to days, the Stash's last level 7 days); insurance returns in 15 minutes (EFT: 12-36 hours, or "a
   couple of hours" from Jaeger since 1.1.0); the scav cooldown is 10 minutes. `DEVELOPMENT_STATUS.md` line 93 says
   "levels follow Tarkov's curve", which the code does not. Evidence: `Progress.luau:6-14`, `TraderData.luau:37-42`,
   `HideoutData.luau`, `Config.luau:14-18`.
6. **P1: The hideout has 5 modules, 8 levels and 10 crafts; EFT has 26, 67 and 214.** Missing are the scav case,
   bitcoin farm, intelligence center (which cuts flea fees by 30 % in EFT), stash levels, lavatory, rest space,
   security, illumination, heating, vents, gym, library, air filtering, solar power, booze generator, weapon and gear
   racks, hall of fame, defective wall and cultist circle. The generator needs only to exist: there is no fuel, so no
   power cuts and no running cost. Only one module can be built at a time. Module requirements never ask for trader
   levels or skills. Evidence: `HideoutData.luau:7-61`, `Hideout.luau:62-93` (the BUSY rule at 67-69);
   `KNOWN_ISSUES.md` 17.
7. **P1: The item catalogue is about a tenth of EFT's, and loot has few uses besides selling.** 279 items against
   EFT's 2,169 in 2021 (102 weapons, 1,421 parts) and 184 rounds in 27 calibers today; we have 6 guns and 13 rounds in
   5 calibers. With only 12 barters and 10 crafts (EFT: 892 and 214) and 8 hideout levels, most barter items have no
   use but cash, so EFT's "keep it for the hideout or a task" decision never comes up. Evidence: `Items.luau`
   (counts above), `TraderData.luau:112-132`, `HideoutData.luau:50-61`.
8. **P1: The flea market lets any level 15 player buy end-game gear.** All gear counts as known (`Items.knownByDefault`
   excludes only loot, keys and task items), only secure containers and task items are banned, and EFT 1.0's
   category level gates (20 to 40) are missing, so the class 6 Bulwark, the class 5 faceplate helmet and thermal
   goggles sit on the market every 15 minutes. Epic and legendary items get as many offers as common ones because the
   rarity scaling only knows "rare" and "uncommon". Evidence: `FleaRules.luau:7-10, 45-48, 68`,
   `Items.luau:387-393`, `Flea.luau:34-47`; EFT gates from Insider Gaming, EFT ban list from the flea-market wiki
   page.

### P2

9. **P2: Two found-in-raid rules are the wrong way round.** Hideout crafts come out without FIR (EFT: crafted items
   are FIR), and items you take into a raid keep FIR (EFT: items a PMC brings in lose it). Evidence:
   `Hideout.luau:128` (`giveStash` with no FIR flag), `Settle.luau:151-179` (deploy never clears `fir`); EFT's
   "Found in raid" wiki page.
10. **P2: Four traders instead of EFT's ten or eleven, one currency, and a Fence that cannot level.** VOS does the work
    of Prapor, Mechanic and Jaeger, TILDA of Ragman, Skier and Peacekeeper. Fence's LL comes from task standing, but
    his only task rewards karma, so he stays at LL1 and his LL2 offer (the dorm 203 key) can never be bought. His
    stock is a fixed 11 items (EFT: what players sold him plus random goods), and karma changes only what he pays
    you, not what he charges. Evidence: `TraderData.luau:12-34, 101-105`, `Economy.luau:51-64`,
    `QuestData.luau:64-66`; EFT trader list from tarkovforge's task guide (11 traders with tasks).
11. **P2: The larger secure containers cannot be obtained, and the secure filter is stricter than EFT's.** Pouch M and
    L exist but no trader, task, loot pool or craft gives them (EFT: Beta from Peacekeeper, Epsilon from a task chain,
    Kappa from The Collector). Weapon parts, grenades and eyewear are refused (`SECURE_KINDS`), while EFT players keep
    scopes and parts in theirs. Evidence: `Items.luau:136-138, 324`; eft-ammo secure container guide; Prima's
    hardcore-wipe article.
12. **P2: No item cases.** EFT's SICC, keytool, documents case, junk box, medicine case, magazine case and keycard
    holder are central to stash management and secure-container use; here a container with anything in it cannot go
    into another. Evidence: `Inv.luau:303-305`; EFT's keycard holder and medicine and magazine cases in the 1.0.2 and
    1.1.0 notes.
13. **P2: Money is a number, not an item.** EFT's roubles, dollars and euros are stackable items that take stash space,
    can be carried, lost, secured and looted from registers and safes, and pay for car exits. Here paid exits charge
    the profile balance. Evidence: `KNOWN_ISSUES.md` 16, `Config.luau:8`; EFT 1.0.2 ("store money in the Keycard
    holder case").
14. **P2: The stash starts at 10 x 20 and stops at 10 x 30.** EFT's standard edition starts at 10 x 30 and the stash
    module goes up to the 10 x 68 and 10 x 72 of the top editions. Evidence: `Config.luau:32-33`,
    `HideoutData.luau:31-33, 45`; tarkovforge editions page.
15. **P2: Charisma makes trader goods up to 15 % cheaper; EFT's Charisma never touches trader prices.** EFT gives -0.1 %
    a level (-5 % at elite) on insurance, healing and paid exits, plus elite perks. Evidence: `Progress.luau:50`,
    `TraderData.luau:155-161`, `Economy.luau:161`; tarkovforge Charisma page.
16. **P2: Several EFT skills are missing**, including Hideout Management (hideout bonuses and fuel use), Mag Drills,
    Weapon Maintenance, Aim Drills, and the DMR, LMG, HMG, revolver and launcher skills. Evidence:
    `Progress.luau:38-73`; tarkovforge skill lists.
17. **P2: Insurance has one provider, a flat 7 % and a 15-minute return.** EFT has Prapor (cheap, 24-36 h), Therapist
    (12-24 h) and since 1.1.0 Jaeger (fast and expensive), and switches insurance off on seasonal characters.
    Evidence: `Config.luau:17-18`, `Settle.luau:196-278`; eft-ammo insurance guide; patched.gg 1.1.0 notes.
18. **P2: Some loot is useless or a trap.** The Sealed Drive is a task item that spawns in seven pools, but no task
    asks for it and traders refuse task items, so it can only take up space. The graphics card, military circuit and
    cold wallet exist only to be sold (no bitcoin farm, few barters). Evidence: `Items.luau:246`,
    `TraderData.luau:167`, `Loot.luau:61, 126, 130, 135, 164, 202, 225`.
19. **P2: Resets are only "wipe everyone when the schema changes"; no seasons, prestige or PvE profile.** EFT has not
    force-wiped its permanent characters since 1.0; 1.1.0 added opt-in seasonal characters that reset every 4-6
    months; prestige exists since 0.16 (six PvE prestige levels in 1.2.0); the PvE Zone has its own progression and
    AI operators. Evidence: `Settle.luau:14, 83-96`; patched.gg, neonsect and dlcompare articles.
20. **P2: The parity file has no economy section.** Project rule 2 asks for gaps in `docs/design/EFT_PARITY.md`, but
    traders, tasks, hideout modules, loot tables, XP and insurance are not logged there (only the flea market row,
    hideout style and airdrops). `DEVELOPMENT_STATUS.md` line 282 still says "no flea market yet". Evidence: the
    section list of `EFT_PARITY.md` (grep for "trader", "quest", "hideout").

### P3

21. **P3: The flea market has logic tests but no recorded Studio run.** Its screens and a real listing round trip are
    not in `TEST_RESULTS.md`. Evidence: `LogicTests.luau:345-373`; no flea entry in `TEST_RESULTS.md`.
22. **P3: Flares are missing from the handbook and flea categories** because the category map has no "flare" kind.
    Evidence: `client/Controllers/Menus.luau:138-143`.
23. **P3: Two tasks say "the Foreman" but any boss counts**, so killing the Caretaker or a Hound completes them.
    Evidence: `QuestData.luau:60-62`, `Quests.luau:110-113`.
24. **P3: Seven items have no inventory picture:** antidote, both flares, the Forester's pack, the welding mask, the
    ritual amulet and the ritual knife. Evidence: `ItemIcons.luau` has no entry; `UiKit.luau:173-176` then draws no
    icon.
25. **P3: Simulated flea stock is counted per server**, so the same "limited" offer can be bought on every server.
    Evidence: `Flea.luau:16, 26-31`.

## Gaps vs EFT

| EFT feature | Ours | Gap |
|---|---|---|
| Item catalogue: 2,169 items in 2021 (102 weapons, 1,421 parts), 184 rounds in 27 calibers in 2026 | 279 items: 6 guns, 96 parts, 13 rounds in 5 calibers, 58 keys | Large |
| Item stats: weight, grid size, base price | Weight, size, value on every item; values set by hand | Small |
| 21 container templates (SPT Interchange) | 13 container kinds | Medium |
| Containers roll: groups draw a subset, probability 0.08-0.71 each | Every container filled every raid | Large |
| Loot tables per map | One pool per container kind for all maps | Medium |
| High-value spawn spots (for example 4 LEDX spots on Interchange) | Vault, dorm and mall "good" pools, key tiles | Small |
| Keys, keycards and locked rooms per map | 58 keys with uses, locked rooms, electric locks | Close |
| Airdrops | 20 %, 6 players, 4 crates, red flare | Small (no bonus pack, no fixed zones) |
| Stash 10 x 30 (standard) up to 10 x 68 / 10 x 72 | 10 x 20 up to 10 x 30 | Medium |
| Secure containers Alpha 2x2, Beta 2x3, Epsilon 2x4, Gamma 3x3, Kappa 4x3 with trader and task paths | Pouch S/M/L; only S obtainable | Medium |
| Item cases (SICC, keytool, documents, junk box, medicine, magazine, keycard holder) | None; full containers cannot nest | Large |
| Money as items in three currencies | A balance in MK | Medium |
| Traders: Prapor, Therapist, Skier, Peacekeeper, Mechanic, Ragman, Jaeger, Fence, Ref, Lightkeeper, BTR Driver | VOS, HALE, TILDA, FENCE | Large |
| LL2-4 at levels about 13-42; 1.1.0 removed the sales-volume requirement | LL2-4 at levels 3, 7, 12 with 150k-1.2M traded | Medium |
| 892 trader barters | 12 | Large |
| Fence: sells what players sold him; LL2 at reputation 6.0 | Fixed 11 offers; stuck at LL1 | Medium |
| Trader restock timers and shared stock (unverified) | 30 min, per player | Small |
| Flea from level 15 with category gates to level 40 (1.0) | Level 15, no gates | Medium |
| Flea fee 3 %, raised to 5 % in 1.1.0 | 3 % | Small |
| Flea bans: secure containers, bitcoins, currency, some weapons, ammo, armour, packs, helmets | Secure containers and task items | Medium |
| Flea of real players; barter offers on the flea | Simulated sellers and buyers; cash only | Decision 3 |
| 531 tasks across 11 traders | 13 across 4 | Large |
| Objective types: conditional kills, FIR hand-ins, plant and mark, visit, extract, skill and LL, gunsmith builds | Kill, hand in, extract, visit | Large |
| Side tasks in groups of 2-4 per LL (1.1.0); daily and weekly operational tasks; task-locked offers | Linear chains; no dailies; no locked offers | Medium |
| Hideout: 26 modules, 67 levels | 5 modules, 8 levels | Large |
| 214 crafts | 10 | Large |
| Generator fuel and power | None | Medium |
| Scav case (5 inputs, FIR returns) | None | Medium |
| Bitcoin farm (10 / 25 / 50 cards, 3-coin cap) | None | Medium |
| Shooting range module | Free lobby range with scored targets | Small |
| Build and craft times in hours to days | 5-45 minutes | Decision 4 |
| Crafted items are FIR; items brought into a raid lose FIR | The opposite in both cases | Small (fix) |
| XP: level 15 at 161,139; top level at 82.6 million XP (level 79, unverified) | Level 15 at 52,383; cap 40 | Decision 4 |
| Skills incl. Hideout Management, Mag Drills, Weapon Maintenance, Aim Drills, DMR, LMG, HMG, revolvers, launchers | 24 skills | Medium |
| Charisma: -0.1 %/level on insurance, healing, paid exits | -0.3 %/level on trader prices | Small (fix) |
| Insurance: Prapor 24-36 h, Therapist 12-24 h, Jaeger fast (1.1.0) | One 7 % insurer, 15 min | Decisions 2 and 4 |
| No forced wipes since 1.0; seasonal characters reset every 4-6 months (1.1.0) | Wipe on schema change | Decision 5 |
| Prestige (0.16; six PvE levels in 1.2.0) | None | Medium |
| PvE Zone: AI operators, own progression, co-op | None | Decision 5 |
| Weapon builds that buy missing parts | None (`KNOWN_ISSUES.md` 54) | Medium |
| Beginner gear package (1.1.0) | Free recovery kit when broke | Close |
| Recurring money sinks: fuel, filters, scav case, multi-million builds, flea fees, insurance, repairs | Flea fees, insurance, repairs, a one-time 785k hideout | Large |
| Paid editions (stash, secure container, XP, standing); free battle pass (1.1.0) | None | Decision 8 |

## Decisions

Effort: S up to a day, M 2-5 days, L over a week. Perf: mobile performance impact. Parity: how close to EFT.

### economy-1: How big should the item catalogue be?

We have 279 items; EFT had 2,169 in 2021 and more now. Tasks, crafts and barters all need a web of specific barter
items, and each new item needs a Blender model, a slot in the 1024 px icon sheets (four today) and balance numbers.
A trader or flea list that shows many items loads many sheets on a phone.

| Option | What would be built | Effort | Perf | Parity |
|---|---|---|---|---|
| a. Core set, about 600 | Every EFT handbook category covered: about 20 guns across EFT's classes, 12 calibers with 4-6 rounds each, about 250 parts, about 120 barter items that tasks, crafts and barters actually use, keys for every map. Built to grow. | L | low | partial |
| b. Mid set, about 1,200 | Option a plus EFT's variants (about 40 guns, 600 parts, 25 calibers) and every EFT hideout and task barter item one for one. | L | med | close |
| c. Full mirror, 3,000+ | An original counterpart for every EFT item. | L | high | exact |
| d. Keep about 280 | Add items only when a feature needs them. | S | none | departure |

**Recommended: a, growing to b map by map.** It gives every system real items to use without the art and phone-memory
cost of a full mirror.

### economy-2: Keep four merged traders or copy EFT's set?

VOS, HALE, TILDA and FENCE cover EFT's ten-plus traders with one currency. Each trader is an NPC at a Relay 7 counter
and needs its own task line and assortment. Ref, Lightkeeper and the BTR Driver are tied to Arena, Lighthouse and the
BTR, which we do not have.

| Option | What would be built | Effort | Perf | Parity |
|---|---|---|---|---|
| a. EFT's eight, one currency | Split VOS into the Prapor, Mechanic and Jaeger roles and TILDA into the Ragman and Skier/Peacekeeper roles, with original names, EFT's assortments and LL rules, Fence driven by karma; MK only. | M | low | close |
| b. EFT's eight plus three currencies | Option a with MK, a dollar-like and a euro-like currency and an exchange at two traders, as in EFT; the other three traders when their maps exist. | L | low | exact |
| c. Keep four, deepen them | More offers, task-locked goods, Fence's player-fed stock. | M | none | departure |

**Recommended: a.** It restores EFT's trader roles and task lines; currencies can follow without redoing the split.

### economy-3: Should the flea market stay simulated or become a real market across servers?

Today each player sees AI sellers that refresh every 15 minutes, and AI buyers take your offers, even overpriced ones.
EFT's flea is a real player market. On Roblox a real one needs MemoryStore (free quota 64 KB + 1.2 KB per user and
1,000 + 120 requests per user a minute) plus DataStore escrow; going past the quota means paid Extended Services, which
needs the owner's approval. Small servers mean few sellers at quiet times.

| Option | What would be built | Effort | Perf | Parity |
|---|---|---|---|---|
| a. Real market with an AI floor | Offers stored per item in MemoryStore, items held in DataStore escrow, buyers pick the cheapest offer, sales mailed to offline sellers; AI sellers fill only empty items at quiet times. | L | low | exact |
| b. Hybrid | Keep AI sellers but make AI demand follow supply and the cheapest offer (overpriced offers stop selling), and price items from what players list. | M | none | close |
| c. Rules only | Keep the simulation; add the gates, bans and fixes in the quick wins. | S | none | partial |

**Recommended: a.** The flea is EFT's economy; the AI floor covers the low-population times that make a pure player
market risky on Roblox.

### economy-4: Should timers and curves match EFT's real time or stay compressed?

Ours: level 15 at 52k XP (EFT 161k), cap 40, LL4 at level 12, builds 5-40 min (EFT up to 7 days), crafts 15-45 min,
insurance 15 min (EFT 12-36 h), scav cooldown 10 min. EFT's pacing was built for long PC sessions and, until 1.0,
half-year wipes.

| Option | What would be built | Effort | Perf | Parity |
|---|---|---|---|---|
| a. EFT exact | EFT's XP table to its top level, LL thresholds, costs and every real-time timer (multi-day builds, 12-36 h insurance, bitcoin at 27-83 h a coin). | M | none | exact |
| b. EFT curves, faster clocks | EFT's XP table, LL thresholds and costs exactly; every real-time timer divided by one owner-chosen factor (for example 4). | M | none | close |
| c. Current pace | Keep and tune by playtest. | S | none | departure |

**Recommended: b.** The numbers that shape the economy stay EFT's, while days-long waits are cut for players who
cannot leave a PC running (our assumption about Roblox players, to check in playtests).

### economy-5: How should progress resets work?

Ours: a schema change wipes everyone; no seasons, prestige or PvE profile. EFT: no forced wipes on permanent PvP and
PvE characters since 1.0; opt-in seasonal characters that reset every 4-6 months since 1.1.0; prestige; a PvE Zone
with AI operators and separate progress. Splitting players into modes is riskier on Roblox's small servers.

| Option | What would be built | Effort | Perf | Parity |
|---|---|---|---|---|
| a. Permanent profile, no wipes | Keep one profile; schema changes migrate instead of wiping. | S | none | close |
| b. Permanent plus an opt-in season | A second profile slot that resets every 4-6 months with its own rewards; it plays in the same raids so the player base is not split. | M | none | close |
| c. Scheduled full wipes | Everyone resets about every 6 months (EFT before 1.0). | S | none | partial |
| d. Add a PvE profile | A separate profile and queue with AI operators (on top of a or b). | L | med | exact |

**Recommended: b, with prestige later.** It matches EFT today and keeps casual players' progress.

### economy-6: How many tasks, in what structure?

We have 13 tasks for Quay 7 with four objective types. EFT has 531 across 11 traders; since 1.1.0 side tasks unlock
in groups of 2-4 per LL, and there are daily and weekly operational tasks. Each task needs our places, items and
quest props.

| Option | What would be built | Effort | Perf | Parity |
|---|---|---|---|---|
| a. Map-first core, about 120 | EFT's task patterns written for our four maps, grouped by trader LL as in 1.1.0, every EFT objective type (plant, mark, conditional kills, quest items, gunsmith builds), task-locked offers, daily and weekly tasks. | L | low | partial |
| b. EFT's full tree, about 500 | Port EFT's tasks one by one with our names, swapping in our maps. | L | low | close |
| c. Small story and dailies | About 40 hand-written tasks plus generated dailies. | M | low | partial |

**Recommended: a.** Tasks need our maps' places and items; grow toward b as maps are added.

### economy-7: How much of EFT's hideout should Relay 7 get?

We have 5 modules, 8 levels and 10 crafts; EFT has 26, 67 and 214, with fuel, the scav case and the bitcoin farm.
Relay 7 is a shared, walk-around bunker, so each module also needs a physical station and art.

| Option | What would be built | Effort | Perf | Parity |
|---|---|---|---|---|
| a. Full EFT set | All 26 modules and levels, about 200 crafts, fuel and filters. | L | med | exact |
| b. Economy core, about 14 | Generator with fuel, stash (4 levels), medstation, workbench, nutrition unit, water collector, intelligence center, scav case, bitcoin farm, lavatory, security, illumination, rest space, shooting range; about 100 crafts. | L | low | close |
| c. Add two | Keep the five; add the scav case and bitcoin farm. | M | low | partial |

**Recommended: b, then a.** The core modules are the ones that drive money, loot use and pacing.

### economy-8: Which paid features, if any, should be planned? (options only; the owner approves any of them)

Roblox offers passes, developer products, subscriptions, paid private servers, paid access and immersive ads; random
paid rewards must be transparent and blocked with PolicyService where they are not allowed. EFT sells editions with a
bigger stash, a better secure container, more XP and standing, and added a free battle pass in 1.1.0.

| Option | What would be built | Effort | Perf | Parity |
|---|---|---|---|---|
| a. None for now | Balance the economy first; plan later. | S | none | departure |
| b. Cosmetics only | Hideout styles, dog tag styles, clothing, gun finishes as passes or products. | M | low | departure |
| c. EFT-style editions | Passes for a larger stash, secure container, XP bonus and trader standing. | M | none | exact |
| d. Private servers and a free pass | Paid private servers for squads plus a free season pass. | M | low | close |

**Recommended: a.** The economy is not balanced yet, and every paid feature needs the owner's approval.

## Quick wins

No decision needed: these copy EFT or fix a bug.

1. Stop simulated buyers from taking overpriced offers (no sales above about 1.25x the market price), so the flea
   no longer pays 1.74x value for anything (`FleaRules.luau:84-98`).
2. Give epic and legendary items fewer flea offers than rare ones (`FleaRules.luau:68`).
3. Add EFT 1.0's flea category gates (levels 20, 25, 30, 35, 40) and EFT's ban list, and keep top armour, helmets and
   thermals off the market (`FleaRules.luau:7-10`).
4. Make crafted items FIR (`Hideout.luau:128`) and clear FIR on items taken into a raid (`Settle.deploy`).
5. Drive Fence's LL from karma, so his LL2 offer can be bought, and let karma move his prices both ways
   (`Economy.luau:51-64`, `TraderData.luau:164-180`).
6. Change Charisma to EFT's effect (-0.1 % a level on insurance, repairs and paid exits) and remove the trader
   discount (`Progress.luau:50`, `TraderData.luau:155-161`).
7. Give Pouch M a trader path (LL2-3 purchase or barter, as Beta) and Pouch L a task path (as Kappa), and allow
   weapon parts, grenades and eyewear in secure containers (`Items.luau:137-138, 324`).
8. Use the Sealed Drive in a task or let traders buy it (`Items.luau:246`).
9. Write a few tasks around the visit zones Border Yard, Meridian and Smelter already define, and give the two boss
   tasks their own boss target (`QuestData.luau:60-62, 75`).
10. Roll a spawn chance for each container (about 0.3 to 0.5 to start, SPT's mean is 0.28), keeping locked rooms
    always stocked as EFT 1.2.0 does (`Loot.luau:557-563`; `CUSTOMS_REFERENCE.md` line 453).
11. Add "flare" to the handbook and flea categories (`Menus.luau:138-143`), and render the seven missing item
    pictures.
12. Fix `DEVELOPMENT_STATUS.md` lines 93 and 282, and add an economy section with the gap table above to
    `docs/design/EFT_PARITY.md`.

## Sources

EFT facts (fetched 2026-11-07):
- Patch 1.1.0 lines (flea fee 3 % to 5 %, trader prices, LL without sales volume, Jaeger insurance, side tasks in LL
  groups, seasonal characters every 4-6 months, hideout money costs): https://patched.gg/games/escape-from-tarkov/patch-1100
- 1.1.0 summary (date 3 Aug 2026, insurance off in seasons, beginner support): https://allthings.how/escape-from-tarkov-1-1-0-0-what-the-kord-breach-season-changes/
- No forced wipes since 1.0; Kappa now needs LL4 with all traders: https://neonsect.com/escape-from-tarkov/tarkov-1-1-0-0-patch-changes/
- PvE Zone: AI operators only, separate progress, no forced wipes: https://neonsect.com/es/escape-from-tarkov/tarkov-pve-vs-pvp/
- 1.2.0 (6 Oct 2026): PvE prestige with six levels, AI operators: https://www.dlcompare.com/gaming-news/escape-from-tarkov-1-2-0-update-brings-major-pve-improvements-86924
- Jaeger insurance "a couple of hours": https://ixbt.games/en/news/2026/07/23/escape-from-tarkov-sdelaiut-dostupnee-dlia-novickov-i-ulucsat-straxovku.html
- Flea category gates 20-40 in 1.0: https://insider-gaming.com/tarkov-flea-market-locked-level-40/
- Flea unlock at 15, 1.0.4.0 ammo-stack rule: https://timesaver.gg/blog/tarkov-how-to-unlock-flea-market
- Flea fee formula, Ti = Tr = 0.03, Intelligence Center -30 %, rating and slot table, FIR rules, ban list: https://escapefromtarkov.gamepedia.com/Flea_market
- 1.0.2 changes (money in the keycard holder case, trader limits): https://mp1st.com/?p=302928
- Prapor LL values and 68 tasks: https://tarkovforge.com/traders/prapor
- Fence LL2 at reputation 6 and 16 tasks: https://tarkovforge.com/traders/fence
- Fence reputation gains, 6.0 maximum: https://primagames.com/tips/the-fastest-way-to-increase-fence-reputation-in-escape-from-tarkov
- LL table for seven traders (pre-rework values with sales volume): https://timesaver.gg/blog/tarkov-trader-loyalty-levels-guide
- Side tasks unlock in groups of 2-4 per LL: https://timesaver.gg/blog/tarkov-season-1-quests-task-rework
- 531 tasks and per-trader counts: https://tarkovforge.com/task-guide
- Task objective and reward types: https://escapefromtarkov.gamepedia.com/Quests
- 214 crafts and 892 barters: https://xgamingserver.com/tools/escape-from-tarkov/crafts-barters
- 184 rounds in 27 calibers: https://xgamingserver.com/tools/escape-from-tarkov/price-checker
- 2,169 items, 102 weapons, 1,421 parts (2021): https://consolepcgaming.com/eft-6-year-evolution-achievements
- Hideout modules, levels, costs and build times: https://tarkov-market.com/economy/hideout
- Bitcoin farm (10 / 25 / 50 cards, rates, 3-coin cap, fuel): https://timesaver.gg/blog/tarkov-bitcoin-farm-guide
- Scav case inputs, times and FIR returns: https://gameslikefinder.com/article/tarkov-scav-case/
- Practical skills incl. Hideout Management: https://tarkovforge.com/skills/hideout-management
- Combat skills list and Aim Drills: https://tarkovforge.com/skills/aim-drills
- Charisma effects: https://tarkovforge.com/skills/charisma
- Level 15 at 161,139 XP; 82.6 million XP to the top level: https://leprestore.com/guides/eft/escape-from-tarkov-leveling-guide/
- FIR rules (crafts FIR, brought-in items lose FIR, run-through): https://escapefromtarkov.fandom.com/wiki/Found_in_raid
- Prapor 24-36 h and Therapist 12-24 h insurance: https://eft-ammo.com/wiki/escape-from-tarkov-insurance-guide
- Editions, stash sizes and secure containers (2026): https://tarkovforge.com/game-editions
- Secure container sizes and sources: https://www.eft-ammo.com/wiki/tarkov-secure-container
- Secure container contents (hardcore wipe restrictions): https://primagames.com/tips/what-items-are-restricted-in-the-secure-container-in-escape-from-tarkov-hardcore-wipe
- Prestige since 0.16.0.0 (as cited in `EFT_PARITY.md`): https://sportskeeda.com/esports/escape-tarkov-patch-notes-update-0-16-0-0-new-event-customs-rework-prestige-system

Roblox:
- Monetisation methods and chance-based rules: https://create.roblox.com/docs/en-us/production/monetization
- MemoryStore quotas and Extended Services: https://create.roblox.com/docs/en-us/cloud-services/memory-stores

Project docs used as evidence: `docs/maps/reference/INTERCHANGE_REFERENCE.md` section 8.4 (SPT container data),
`docs/maps/reference/CUSTOMS_REFERENCE.md` line 453 (1.2.0 locked containers always hold loot),
`docs/design/EFT_PARITY.md` lines 409-415, `docs/design/AIRDROPS.md`.

Unverified: EFT trader restock intervals and whether stock is shared; whether EFT builds several hideout modules at
once; exact LL thresholds after 1.1.0 (sources disagree); EFT's total item count in 2026; the top level being 79.
Could not be read: the fandom pages for Traders, Flea market, Fence and Character skills (fetch errors).
