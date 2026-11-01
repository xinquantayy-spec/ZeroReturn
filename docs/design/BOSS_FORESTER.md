# Border Yard's lone trapper (THE FORESTER, our Partisan)

Status 2026-11-02: **built and checked in Studio with one player** (TEST_RESULTS "THE FORESTER and tripwires").

## What Tarkov does

- **Who:** Partisan, a lone boss added in patch 0.15. No followers, no fixed territory: he roams.
- **Where and how often:**
  - Customs, Woods, Lighthouse and Shoreline.
  - 25 % on each (tarkovforge, live from tarkov.dev); "about 15 %" (timesaver, September 2026).
  - On Customs: the tree lines and the construction site's edges, not the warehouses (timesaver); most often seen
    around the dorms (Prima Games).
- **Health:** 950 (head 80, thorax 220, stomach 190, each arm 110, each leg 120). No armour and no other protection
  (the Japanese wiki).
- **Karma:** he hunts players with low karma, PMCs and scavs alike, and comes more often to raids that have them.
  He also turns on anyone who comes too close (GGRecon, Prima Games). Higher Fence reputation lowers the chance he
  targets you (timesaver).
- **Traps:** he ties grenades to tripwires across doorways, narrow trails, fence gaps and log piles. Often the fight
  starts when someone sets one off. Neither his own tripwires nor players' set him off (the wiki via timesaver).
- **How he fights:** quiet, almost soundless steps; only the grass rustles. He flanks, throws frags and stuns at people
  who stay put behind cover, and moves on after a fight.
- **Gear:** Partisan's bag (4x3, 20 slots, 0.7 kg; -5 % speed, -2 % turn, -8 ergonomics). Weapons:
  - AK family rifles (AKS-74, AK-103, AKMS);
  - the AVT-40;
  - pump shotguns (MP-133, MP-155);
  - the APS pistol;
  - grenades: F-1, RGD-5, VOG-25 and others;
  - an ice pick.
  He sometimes carries AFAKs.
- **Tripwires** (players get them from Jaeger):
  - they go off when someone steps into them, when they are shot close up, or when shrapnel hits them;
  - the grenade keeps its own fuse;
  - disarming takes 11 s by hand, 3 s with a multitool, and you keep the grenade;
  - a player's tripwire disarms itself after 10 minutes.
- **Sources:**
  - [tarkovforge: Partisan](https://tarkovforge.com/bosses/partisan);
  - [timesaver.gg: Partisan guide (2026-09-21)](https://timesaver.gg/blog/tarkov-partisan-boss-guide-loot-table);
  - [wikiwiki.jp: Partisan](https://wikiwiki.jp/eft/Partisan);
  - [Prima Games: where to find Partisan](https://primagames.com/tips/where-to-find-partisan-in-escape-from-tarkov);
  - [GGRecon: PMC karma and Partisan](https://www.ggrecon.com/guides/escape-from-tarkov-pmc-karma-partisan/);
  - [tarkovforge: Partisan's bag](https://tarkovforge.com/backpacks/partisans-bag);
  - [Shacknews: tripwires](https://www.shacknews.com/article/141406/tarkov-tripwire);
  - [GGRecon: tripwires](https://ggrecon.com/guides/escape-from-tarkov-tripwires-how-to-get-use).

## Built (2026-11-02)

- **THE FORESTER on Border Yard** (`Maps/Border/Play.luau`, "forester"):
  - one man, rolled at 20 % beside the other bosses;
  - 10 % more for each raider with low karma in the queue, up to 50 % (`AI.forestChance`, `Match.raidKarma`);
  - `ZR_Dev boss(true, "Forester")` forces him in.
- **His walk:** an 8-point loop that starts at a random point each raid. Each leg was checked with the AI pathfinder.
  The points, in order:
  1. the frame's south apron;
  2. between the two woods south of it;
  3. the near wood's west edge;
  4. north of BLOCK B;
  5. along the wood south of the dorms;
  6. east of BLOCK A;
  7. the long wood's east edge;
  8. back to the start.
- **Health:** 950 (`hp` = 950 / 440).
- **Who he fights** (`AI.forestHostile`):
  - raiders whose karma (the Fence standing) is below 0;
  - anyone who comes within 25 studs (8 m) or shoots him, from then on for the whole raid (`u.grudge`).
  - Other raiders he walks past. The other AI are friends.
- **Silent:** every client plays none of his footsteps (`SilentSteps`). On grass a faint rustle remains.
- **Kit** (`Loot.foresterLoadout`):
  - no armour or helmet, an olive beanie;
  - THE FORESTER'S PACK;
  - the KS-7 with BP or PS rounds (now and then the quiet build), or a quarter of the time the pump shotgun;
  - the P-9;
  - two to four grenades (F-7 and RK-5);
  - a dressing, a field medkit half the time, dorm loot.
- **FORESTER_PACK** (new item): Tarkov's numbers.
- **Look:** a faded olive padded jacket and dark olive trousers.
- **Tripwires** (`Services/Tripwires.luau`, new):
  - **Where they go:**
    - When he spawns, five wires go into doorways within 60 studs of his loop.
    - Only unlocked doors that are not sealed or powered.
    - Building entrances come first, then inside doors.
    - Never two within 6 studs of each other.
  - **How each is laid:**
    - Both stakes on the same floor at the sill, 0.35 in from the jambs.
    - The wire 1 stud out, on the side the leaf does not swing to, at 0.55 studs (18 cm).
    - It is checked in the world: nothing across the wire, nothing where a stake goes, nothing between the door and
      the wire.
  - **What it looks like:** two thin stakes, a bare steel wire and the grenade at the foot of one stake, tied to it.
  - **What sets it off:**
    - a raider whose step crosses the wire or ends on it (checked 10 times a second);
    - a shot that meets it (an invisible 0.16-stud shell in the shots' group);
    - a frag blast within reach.
  - **When it goes off:** the wire snaps, the pin and spoon sound, and the grenade drops and goes off on its own fuse.
  - **Disarming:**
    - Look at the wire from within about 5 studs and the DISARM prompt shows.
    - Hold it 11 s, or 3 s with a multitool anywhere on you. The server checks the multitool again.
    - The grenade goes into your inventory, or is dropped there if it does not fit.
  - **The hold bar:** held prompts (this one and the car fare) now fill a bar under the button.
  - **Who sets them off:** AI never do.
- **Dev commands** (`DevExt/Traps.luau`): `traps`, `trapLay`, `trapGo`, `forester`, `karma`.

## Gaps (also in `EFT_PARITY.md`)

- **Karma is the Fence standing.** Tarkov's PMC karma is hidden and moves with how you play; ours moves only with
  scav kills and scav extracts.
- **Traps only in doorways.** Not across trails, fence gaps or log piles, and all are laid at spawn rather than as he
  walks.
- **No tripwire kit for players** (Tarkov: from Jaeger after two tasks), so no 10-minute timeout either.
- **AI never set off a wire.** Tarkov does not say.
- **His weapons are ours:** no AVT-40, no APS, no VOG or RGO grenades, no ice pick. He carries no GP-25.
- **One map:** only on Border Yard. He does not roam other maps, and nothing tracks him.
- **No new art:** the pack uses the canvas pack's mesh, and FORESTER_PACK has no inventory picture.
- **One AI:** he does not throw stuns on purpose at players who hold still, and does not move on after a fight. He
  uses the boss skill and the usual grenade throws.
