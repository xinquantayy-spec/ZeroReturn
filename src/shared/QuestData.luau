--!strict
-- Trader tasks (original, Tarkov-style). Decision economy-6a, "map-first core, about 120": EFT's task patterns written for
-- our four maps (Border Yard = Customs, Meridian Mall = Interchange, Smelter = Factory, Quay 7 = our own port), side tasks
-- in loyalty-level groups as in EFT 1.1.0, every EFT objective type, task-locked trader offers (TraderData) and daily and
-- weekly operational tasks. EFT sources (read 2026-11-08):
--   1.1.0 (3 Aug 2026): "Reworked side task distribution to be tied to specific Trader Loyalty Levels in groups of 2-4";
--     "Scav elimination tasks now only count regular, sniper, and player Scavs" (patched.gg/games/escape-from-tarkov/
--     patch-1100); each trader offers basic tasks at LL1 and "completing several of them, or raising the trader's Loyalty
--     Level, opens the next batch"; a few chains stay, "usually for rare trade offers" (allthings.how/escape-from-tarkov-1-
--     1-0-side-task-changes-explained); a loyalty level "opens a pool of tasks" (timesaver.gg/blog/tarkov-season-1-quests-
--     task-rework).
--   531 tasks: Prapor 68, Therapist 56, Skier 66, Peacekeeper 52, Mechanic 91, Ragman 61, Jaeger 65, Fence 16 (tarkovforge.com
--     /task-guide); ours keep about that share per trader.
--   objective and reward types, quest items, operational tasks: escapefromtarkov.fandom.com/wiki/Quests.
-- Objective kinds (n = how many; every objective may name a map):
--   kill    { target = "scav" | "watch" | "pmc" | "boss" | "follower" | "any", n, boss? / label? (the AI's Label: one boss or
--           guard), map?, zone? (the killer stands in a task place), weapon? (class or list: rifle, smg, shotgun, bolt, pistol,
--           melee, grenade), gun? (weapon item id), dist? / maxDist? (metres), part? (head, thorax, stomach, arms, legs),
--           time? ({ from, to } raid clock hours), scav? (as a scav), suppressed?, noArmor? (no body armour or helmet), noNv?
--           (no night vision), wear? (an item worn), raid? (all in one raid) }
--   handin  { item, n, fir? }      found-in-raid items (fir = false: any), handed in at turn-in; a quest item counts from
--                                  the quest-item pouch
--   extract { n, exfil?, scav?, map? }   survive and extract (a run-through does not count: EFT wiki)
--   visit   { zone, map?, scav? }        reach a task place during a raid
--   plant   { item, zone, map }          leave an item at a task place (hold F there)
--   mark    { zone, map }                mark a task place with a Spot Marker, then stay alive 30 s (EFT's MS2000)
--   find    { item, zone, map }          pick up a quest item at a task place; it goes to the quest-item pouch and is kept
--                                        only by extracting (EFT: lost on a failed extraction)
--   build   { base, dur?, ergo?, recoil?, cap?, mass?, moa?, zoom?, device?, light?, laser?, suppressed?, sight?, foregrip?,
--           muzzle? }  a gunsmith build in the stash that meets the specification, handed over at turn-in (EFT's Gunsmith)
-- Task places: each map's W.visitZones (World on Quay 7, src/server/Maps/* on the others): { pos, r, h? } (h: half height,
-- for places on one floor). Q.NEW_ZONES lists the places these tasks added, for the coordinator to place.
-- Unlocking: level; tl (the loyalty level needed with the task's own trader: EFT 1.1.0's LL groups); after (the task before
-- it); optionally needs { ids }, karma (the Fence standing it needs) and ll (the loyalty level with every trader but Fence).
-- Rewards: money, xp, rep (standing with the giver), reps ({ [trader] = change } for others, EFT's BP Depot: Jaeger -0.01),
-- karma, items { { id, n } }; trader offers that a task opens are in TraderData (offers with task = id).
-- Standing: since economy-6a every trader's tasks give at least EFT 1.1.0's LL4 standing, so the loyalty table is EFT's
-- own (TraderData.LOYALTY). We have about a quarter of EFT's tasks a trader, so a task here gives about four times EFT's
-- standing (EFT's Debut and Shootout Picnic give +0.10, tarkovforge); within each trader, the tasks of LL1 give a little
-- more than LL2 asks, LL1 and LL2 together a little more than LL3 asks, and so on.
-- Traders (decision economy-2a, EFT's eight): each task belongs to the trader whose EFT counterpart gives that kind of task.
-- The tasks from before economy-6a keep their ids, chains, objectives and rewards (old saves, TraderTests).
local Maps = require(script.Parent.Maps)
local Items = require(script.Parent.Items)
local Weapons = require(script.Parent.Weapons)
local WP = require(script.Parent.WeaponParts)

local Q = {}

Q.MARKER = "MARKER" -- the Spot Marker (EFT's MS2000 marker)
Q.PLANT_HOLD = 6 -- seconds to plant an item (ours; EFT's plant times were not found)
Q.MARK_HOLD = 4 -- seconds to set a marker (ours)
Q.MARK_SURVIVE = 30 -- a marker counts once you have stayed alive 30 s after setting it (EFT wiki, BP Depot)
Q.STUDS_PER_M = 3.125 -- studs a metre on the real-scale maps (Ballistics.STUDS_PER_M)

local function with(o: any, t: any?): any
	if type(t) == "table" then
		for k, v in t do
			o[k] = v
		end
	end
	return o
end
-- b: a boss's name (the old form) or a table of conditions
local function kill(target: string, n: number, b: any?): any
	local o: any = { kind = "kill", target = target, n = n }
	if type(b) == "string" then
		o.boss = b
	else
		with(o, b)
	end
	return o
end
local function handin(item: string, n: number, fir: boolean?): any
	return { kind = "handin", item = item, n = n, fir = fir }
end
local function extract(n: number, exfil: string?, scav: boolean?, map: string?): any
	return { kind = "extract", n = n, exfil = exfil, scav = scav, map = map }
end
local function visit(zone: string, map: string?, scav: boolean?): any
	return { kind = "visit", zone = zone, n = 1, map = map, scav = scav }
end
local function plant(item: string, zone: string, map: string): any
	return { kind = "plant", item = item, zone = zone, map = map, n = 1 }
end
local function mark(zone: string, map: string): any
	return { kind = "mark", item = Q.MARKER, zone = zone, map = map, n = 1 }
end
local function find(item: string, zone: string, map: string): any
	return { kind = "find", item = item, zone = zone, map = map, n = 1 }
end
-- ref: one build that meets the specification (a trader preset with parts swapped or added), for TaskTests only
local function build(base: string, spec: any, ref: any): any
	local o = with({ kind = "build", base = base, n = 1 }, spec)
	o.ref = ref
	return o
end

Q.list = {
	-- ════ VOS (EFT's Prapor) ═══════════════════════════════════════════════════════════════════════════════════════
	-- LL1: V1, V8 and V9 open at once; V2, V6 and V11 after V1, V10 after V8
	-- V1 is after EFT's "Debut", Prapor's first task (eliminate scavs on Customs)
	{ id = "V1", trader = "vos", tl = 1, name = "Signal Check", level = 1, after = nil,
		desc = "Scavs keep cutting the relay cables. Thin them out.",
		obj = { kill("scav", 5) }, reward = { money = 15000, xp = 500, rep = 0.05, items = { { "R17_MAG40", 1 } } } },
	-- after EFT's "No Place for Renegades" (Prapor: eliminate 5 Raiders in the Reserve command bunker; consolepcgaming.com/
	-- eft-no-place-for-renegades): the Watch are this game's raiders
	{ id = "V2", trader = "vos", tl = 1, name = "Range Day", level = 2, after = "V1",
		desc = "The Harbor Watch think the quay is theirs. Show them otherwise.",
		obj = { kill("watch", 3) }, reward = { money = 30000, xp = 1200, rep = 0.07 } },
	{ id = "V6", trader = "vos", tl = 1, name = "Slag Run", level = 3, after = "V1",
		desc = "Someone keeps a lookout on the slag stack in the smelter's north yard. Go and look, then get out of there alive.",
		obj = { visit("STACK", "smelter"), extract(1, nil, nil, "smelter") }, reward = { money = 20000, xp = 900, rep = 0.04 } },
	-- after EFT's "Debut" (Prapor: eliminate 5 Scavs on Woods, Ground Zero, Interchange or Customs; +3,000 XP, +0.10 standing;
	-- tarkovforge.com/task-guide/debut), on Border Yard
	{ id = "V8", trader = "vos", tl = 1, name = "Yard Sweep", level = 1,
		desc = "The customs yard is crawling with scavs picking over my stock. Go to Border Yard and put five of them down.",
		obj = { kill("scav", 5, { map = "border" }) }, reward = { money = 12000, xp = 900, rep = 0.15, items = { { "P9_MAG", 2 } } } },
	-- after EFT's "Shootout Picnic" (Prapor: eliminate 15 targets of any kind; +3,000 XP, +0.10; tarkovforge)
	{ id = "V9", trader = "vos", tl = 1, name = "Open Season", level = 3,
		desc = "Anyone walking Meridian Mall with a gun is in my way. Twelve of them, I don't care who.",
		obj = { kill("any", 12, { map = "meridian" }) }, reward = { money = 18000, xp = 1000, rep = 0.15, items = { { "GREN_RK5", 2 } } } },
	-- after EFT's "BP Depot" (Prapor: mark four fuel tankers on Customs with MS2000 markers and extract; +0.03 Prapor, -0.01
	-- Jaeger; it unlocks a gun at Prapor LL1; markers from Prapor or Ragman; EFT wiki BP_Depot)
	{ id = "V10", trader = "vos", tl = 1, name = "Fuel Count", level = 5, after = "V8",
		desc = "Somebody is selling fuel out of the Border Yard tank farm. Put a marker on the first and the third tank so my people find them, then get out.",
		obj = { mark("BY_TANK1", "border"), mark("BY_TANK3", "border"), extract(1, nil, nil, "border") },
		reward = { money = 25000, xp = 1100, rep = 0.2, reps = { bram = -0.01 } } },
	-- after EFT 1.1.0's "Stirrup" (Prapor: 10 pistol kills on Factory; allthings.how 1.1.0 changes)
	{ id = "V11", trader = "vos", tl = 1, name = "Short Barrel", level = 4, after = "V1",
		desc = "A rifle is a luxury. Go into the Smelter with a pistol and come back with eight kills.",
		obj = { kill("any", 8, { map = "smelter", weapon = "pistol" }) }, reward = { money = 15000, xp = 900, rep = 0.15, items = { { "P9_MAG33", 1 } } } },
	-- LL2: V3, T7, V12 and V13 open at once; V4 and V14 after V3, V15 after V12
	{ id = "V3", trader = "vos", tl = 2, name = "Iron Discipline", level = 5, after = "V2",
		desc = "Other operators are stripping our caches. Find them first.",
		obj = { kill("pmc", 2) }, reward = { money = 60000, xp = 2500, rep = 0.1, items = { { "SUPP_62", 1 } } } },
	{ id = "V4", trader = "vos", tl = 2, name = "The Foreman's Ledger", level = 8, after = "V3",
		desc = "The Foreman keeps a ledger of every crate that left the harbour. Bring it to me.",
		obj = { handin("LEDGER", 1) }, reward = { money = 250000, xp = 6000, rep = 0.15 } },
	-- Customs' marked room 314 in the three-storey dorm is Border Yard's block A room 314 (its key: KEY_BY_314). VOS's: EFT's
	-- dorm-room task is Prapor's "Shaking up the Teller" (the valuable item in dorm room 203, access to room 214; gamemaps.net);
	-- the marked room itself has no task in EFT (tarkovforge.com/keys/dorm-room-314-marked-key)
	{ id = "T7", trader = "vos", tl = 2, name = "Room 314", level = 6, after = "T3",
		desc = "Block A, room 314, on Border Yard. People pay well to know what is behind that door. Go and see for yourself.",
		obj = { visit("DORM314", "border") }, reward = { money = 40000, xp = 1500, rep = 0.05 } },
	-- a quest item to find and hand over (EFT: "Locate and obtain", then "Hand over"; EFT wiki Quests)
	{ id = "V12", trader = "vos", tl = 2, name = "Watch Room", level = 8,
		desc = "The watchhouse by the old checkpoint kept a log of every truck it waved through. It is still in the watch room upstairs. Bring it.",
		obj = { find("QI_WATCHLOG", "BY_WATCHROOM", "border"), handin("QI_WATCHLOG", 1) },
		reward = { money = 40000, xp = 1800, rep = 0.5, items = { { "KEY_BY_WATCHSTORE", 1 } } } },
	-- a time window on the raid clock (EFT's Tarkov Shooter - Part 5: 21:00-5:00; gamemaps.net)
	{ id = "V13", trader = "vos", tl = 2, name = "Night Shift", level = 9,
		desc = "The Smelter runs a night shift of scavs. Work it with them: six of them, between nine at night and five in the morning.",
		obj = { kill("scav", 6, { map = "smelter", time = { 21, 5 } }) }, reward = { money = 35000, xp = 1700, rep = 0.5 } },
	-- a kill in a place (EFT's InZone condition, e.g. Peacekeeper's scav hunt in the mall), all in one raid (EFT's
	-- objectives that reset when the raid ends)
	{ id = "V14", trader = "vos", tl = 2, name = "Bastion Census", level = 10, after = "V3",
		desc = "The scavs in the Bastion have started charging a toll. Count eight of them out, inside the walls, in one raid.",
		obj = { kill("scav", 8, { map = "border", zone = "BY_BASTION", raid = true }) }, reward = { money = 45000, xp = 2000, rep = 0.5 } },
	-- grenade kills (EFT: Prapor's grenade task)
	{ id = "V15", trader = "vos", tl = 2, name = "Frag Season", level = 12, after = "V12",
		desc = "I have crates of grenades nobody buys. Show the buyers what they do: four kills with grenades, anywhere.",
		obj = { kill("any", 4, { weapon = "grenade" }) }, reward = { money = 40000, xp = 2000, rep = 0.5, items = { { "GREN_F7", 2 } } } },
	-- LL3: four at once
	{ id = "V16", trader = "vos", tl = 3, name = "Foreman's Notes", level = 21,
		desc = "The Foreman wrote everything down: buyers, prices, dates. His notebook is in his room, 203, in the crew dormitory on Quay 7.",
		obj = { find("QI_NOTEBOOK", "Q7_DORM203", "quay7"), handin("QI_NOTEBOOK", 1) }, reward = { money = 90000, xp = 4000, rep = 1.4 } },
	{ id = "V17", trader = "vos", tl = 3, name = "Hold the Line", level = 23,
		desc = "Operators are moving into the Border Yard dorms. I want five of them gone, and I want it done in the dorm yard.",
		obj = { kill("pmc", 5, { map = "border", zone = "BY_DORMS" }) }, reward = { money = 120000, xp = 4500, rep = 1.4 } },
	-- distance (EFT's operational kills: "beyond 20-50 m" for scavs; EFT wiki Quests)
	{ id = "V18", trader = "vos", tl = 3, name = "Long Reach", level = 24,
		desc = "Anyone can shoot a man at arm's length. Six scavs from sixty metres or more.",
		obj = { kill("scav", 6, { dist = 60 }) }, reward = { money = 90000, xp = 4000, rep = 1.4 } },
	{ id = "V19", trader = "vos", tl = 3, name = "Iron Hands", level = 26,
		desc = "The KASSA hall in Meridian Mall belongs to whoever holds it. Make it ours: four operators, with a rifle, inside the hall.",
		obj = { kill("pmc", 4, { map = "meridian", zone = "MM_KASSA", weapon = "rifle" }) }, reward = { money = 120000, xp = 4500, rep = 1.4 } },
	-- LL4
	{ id = "V20", trader = "vos", tl = 4, name = "Clean Sheets", level = 36,
		desc = "Six operators, each with one shot to the head. Clean work only.",
		obj = { kill("pmc", 6, { part = "head" }) }, reward = { money = 200000, xp = 6000, rep = 0.3, items = { { "GREN_F7", 3 } } } },
	{ id = "V21", trader = "vos", tl = 4, name = "Old Debts", level = 37,
		desc = "The harbourmaster owed me a brass lion. He is not coming back for it. You are.",
		obj = { handin("BRASS_LION", 1) }, reward = { money = 250000, xp = 6000, rep = 0.3 } },

	-- ════ HALE (EFT's Therapist) ════════════════════════════════════════════════════════════════════════════════════
	-- LL1: H1, H7, H8 and H9 at once; H2 after H1, H3 and H5 after H2
	{ id = "H1", trader = "hale", tl = 1, name = "First Aid", level = 1, after = nil,
		desc = "My shelves are empty. Bring dressings and a kit you found out there.",
		obj = { handin("BANDAGE", 2), handin("MEDKIT_S", 1) }, reward = { money = 12000, xp = 400, rep = 0.05, items = { { "MEDKIT_M", 1 } } } },
	{ id = "H2", trader = "hale", tl = 1, name = "Supply Run", level = 2, after = "H1",
		desc = "Go in, come back. Twice. I need to know the routes still work.",
		obj = { extract(2) }, reward = { money = 20000, xp = 800, rep = 0.06 } },
	{ id = "H3", trader = "hale", tl = 1, name = "Cold Chain", level = 3, after = "H2",
		desc = "Clean water and food for the relay crew.",
		obj = { handin("WATER", 2), handin("STEW", 2) }, reward = { money = 25000, xp = 900, rep = 0.06, items = { { "HEMOSTAT", 1 } } } },
	-- after EFT's "Operation Aquarius" (Therapist: locate the hidden water stash on Customs), on Border Yard's boiler house
	{ id = "H5", trader = "hale", tl = 1, name = "Cellar Stock", level = 4, after = "H2",
		desc = "The crossing's last medic hid supplies in the boiler house cellar on Border Yard. Find the cellar and come back to tell me it is still dry.",
		obj = { visit("BOILER", "border"), extract(1, nil, nil, "border") }, reward = { money = 25000, xp = 1100, rep = 0.05, items = { { "MEDKIT_M", 1 } } } },
	-- after EFT's "Shortage" (Therapist: hand over found-in-raid medicine)
	{ id = "H7", trader = "hale", tl = 1, name = "Shortfall", level = 2,
		desc = "Painkillers and splints walk out of here faster than I can stock them. Bring me some you found yourself.",
		obj = { handin("PAINKILLERS", 3), handin("SPLINT", 2) }, reward = { money = 15000, xp = 800, rep = 0.15 } },
	-- after the Therapist's hygiene hand-ins ("Sanitary Standards")
	{ id = "H8", trader = "hale", tl = 1, name = "Clean Hands", level = 3,
		desc = "An aid station without soap is a morgue. Soap, bleach and toothpaste from the mall's shelves.",
		obj = { handin("SOAP", 2), handin("BLEACH", 1), handin("TOOTHPASTE", 1) }, reward = { money = 15000, xp = 800, rep = 0.15 } },
	-- after EFT's "Postman Pat - Part 1" (Therapist: find a letter and hand it over)
	{ id = "H9", trader = "hale", tl = 1, name = "Letters Home", level = 4,
		desc = "A family that used to live in the squat on Border Yard left their letters behind. Find the bundle. Somebody is still waiting for them.",
		obj = { find("QI_LETTERS", "BY_SQUAT", "border"), handin("QI_LETTERS", 1) }, reward = { money = 18000, xp = 900, rep = 0.15 } },
	-- LL2: H4, H6, H10 and H11 at once; H12 after H10, H13 after H11
	{ id = "H4", trader = "hale", tl = 2, name = "Field Surgeon", level = 6, after = "H3",
		desc = "Someone left surgical tools in a locker on the quay. I want them.",
		obj = { handin("MED_TOOLS", 1) }, reward = { money = 40000, xp = 1500, rep = 0.08, items = { { "SURGKIT", 1 } } } },
	{ id = "H6", trader = "hale", tl = 2, name = "Outside the Mall", level = 6, after = "H3",
		desc = "Two camps stand outside Meridian Mall: the rescue camp and the west camp. Check both for survivors, then come home.",
		obj = { visit("RESCUE_CAMP", "meridian"), visit("WEST_CAMP", "meridian"), extract(1, nil, nil, "meridian") },
		reward = { money = 30000, xp = 1300, rep = 0.05 } },
	{ id = "H10", trader = "hale", tl = 2, name = "Cold Samples", level = 8,
		desc = "The pharmacy on the mall's upper floor kept a sealed sample case in its locked store room. I need it unopened.",
		obj = { find("QI_SAMPLES", "MM_MEDIQ", "meridian"), handin("QI_SAMPLES", 1) }, reward = { money = 40000, xp = 1800, rep = 0.45 } },
	{ id = "H11", trader = "hale", tl = 2, name = "Field Kit", level = 10,
		desc = "Stop the bleeding first, ask questions later. Hemostatic packs, tourniquets and a field medkit, found out there.",
		obj = { handin("HEMOSTAT", 2), handin("TOURNIQUET", 2), handin("MEDKIT_L", 1) }, reward = { money = 45000, xp = 2000, rep = 0.4 } },
	-- planting (EFT's "stash an item at a place", e.g. Fishing Gear)
	{ id = "H12", trader = "hale", tl = 2, name = "Aid Station", level = 12, after = "H10",
		desc = "Leave a road kit in the RESCUE POINT store inside the mall and one at the rescue camp outside. People still come looking.",
		obj = { plant("MEDKIT_M", "MM_RESCUE_POINT", "meridian"), plant("MEDKIT_M", "RESCUE_CAMP", "meridian") },
		reward = { money = 45000, xp = 2000, rep = 0.4 } },
	{ id = "H13", trader = "hale", tl = 2, name = "After Hours", level = 11, after = "H11",
		desc = "Three trips into Meridian Mall and three trips back. I need someone who knows the way out.",
		obj = { extract(3, nil, nil, "meridian") }, reward = { money = 35000, xp = 1700, rep = 0.35 } },
	-- LL3: three at once
	{ id = "H14", trader = "hale", tl = 3, name = "Reagents", level = 18,
		desc = "The smelter's lab kept reagents in a case in the casting shed. If it still holds, it is worth more than you.",
		obj = { find("QI_REAGENT", "SM_CASTING", "smelter"), handin("QI_REAGENT", 1) }, reward = { money = 90000, xp = 3500, rep = 1.25 } },
	{ id = "H15", trader = "hale", tl = 3, name = "Surgeon's Debt", level = 20,
		desc = "A surgical kit, a trauma case and two rolls of surgical tools, all found out there. I have patients waiting.",
		obj = { handin("SURGKIT", 1), handin("MEDKIT_XL", 1), handin("MED_TOOLS", 2) }, reward = { money = 120000, xp = 4000, rep = 1.3 } },
	-- gear and distance (EFT's "Decontamination Service": scavs at close range in a gas mask)
	{ id = "H16", trader = "hale", tl = 3, name = "Clean Air", level = 22,
		desc = "Something in the mall air makes the scavs sick and mean. Wear a gas mask and clear eight of them at close range, twenty metres or less.",
		obj = { kill("scav", 8, { map = "meridian", maxDist = 20, wear = "GAS_MASK" }) }, reward = { money = 100000, xp = 4000, rep = 1.3 } },
	-- LL4
	{ id = "H17", trader = "hale", tl = 4, name = "Stockpile", level = 37,
		desc = "Two trauma cases and two antidotes, found out there. Winter is coming to the relay.",
		obj = { handin("MEDKIT_XL", 2), handin("ANTIDOTE", 2) }, reward = { money = 200000, xp = 6000, rep = 0.3 } },
	{ id = "H18", trader = "hale", tl = 4, name = "Clinic Supply", level = 38,
		desc = "Two field surgical kits. Do not ask what for.",
		obj = { handin("SURGKIT", 2) }, reward = { money = 180000, xp = 6000, rep = 0.3 } },

	-- ════ ROOK (EFT's Skier) ════════════════════════════════════════════════════════════════════════════════════════
	-- LL1: T3, R1, R2 and R3 at once; R4 after R2
	-- ROOK's (EFT's Skier): no EFT task asks for one exit like this; Skier, the customs-terminal smuggler, runs the
	-- couriers, so the courier route is his
	{ id = "T3", trader = "rook", tl = 1, name = "Dead Drop", level = 3, after = "T2",
		desc = "Use the rail cut. If it's clear, my couriers will too.",
		obj = { extract(1, "C", nil, "quay7") }, reward = { money = 25000, xp = 900, rep = 0.06 } },
	-- after EFT's "Supplier" (Skier: hand over gear)
	{ id = "R1", trader = "rook", tl = 1, name = "Packing List", level = 1,
		desc = "My couriers travel light. Bring me a utility belt and a day bag you found out there.",
		obj = { handin("RIG_BELT", 1), handin("BAG_SLING", 1) }, reward = { money = 12000, xp = 700, rep = 0.15 } },
	{ id = "R2", trader = "rook", tl = 1, name = "Paper Trail", level = 3,
		desc = "Store 17's foreman kept a transit manifest in his office on the mezzanine. I want to know which of my crates he signed for.",
		obj = { find("QI_MANIFEST", "BY_STORE17", "border"), handin("QI_MANIFEST", 1) }, reward = { money = 18000, xp = 900, rep = 0.15 } },
	{ id = "R3", trader = "rook", tl = 1, name = "Toll Booth", level = 4,
		desc = "Scavs charge my couriers to cross the main bridge on Border Yard. Six of them, on the bridge.",
		obj = { kill("scav", 6, { map = "border", zone = "BY_BRIDGE" }) }, reward = { money = 15000, xp = 900, rep = 0.15 } },
	{ id = "R4", trader = "rook", tl = 1, name = "Smugglers' Tide", level = 5, after = "R2",
		desc = "The smugglers' boat on Border Yard still has its logbook aboard. Every run I ever made is in it.",
		obj = { find("QI_BOATLOG", "BY_BOAT", "border"), handin("QI_BOATLOG", 1) }, reward = { money = 20000, xp = 1000, rep = 0.15 } },
	-- LL2: R5, R6, R7 and R8 at once; R9 after R7
	{ id = "R5", trader = "rook", tl = 2, name = "Silent Partner", level = 9,
		desc = "Quiet business needs quiet tools. Eight scavs in Meridian Mall with a suppressed weapon.",
		obj = { kill("scav", 8, { map = "meridian", suppressed = true }) }, reward = { money = 40000, xp = 1800, rep = 0.35 } },
	-- after EFT 1.1.0's "Safe Corridor" (5 Scavs plus 3 found-in-raid keys for that place; allthings.how)
	{ id = "R6", trader = "rook", tl = 2, name = "Keyring", level = 10,
		desc = "Clear five scavs on Border Yard and bring me the keys to the fuel stop till, the old pumps and the squat, found out there.",
		obj = { kill("scav", 5, { map = "border" }), handin("KEY_BY_FUELTILL", 1), handin("KEY_BY_PUMPS", 1), handin("KEY_BY_SQUAT", 1) },
		reward = { money = 45000, xp = 2000, rep = 0.45 } },
	{ id = "R7", trader = "rook", tl = 2, name = "Seized Goods", level = 11,
		desc = "Customs locked a parcel of mine in the wire cage at the Red Stores. Get it back before somebody opens it.",
		obj = { find("QI_PARCEL", "BY_RED_CAGE", "border"), handin("QI_PARCEL", 1) }, reward = { money = 45000, xp = 2000, rep = 0.4 } },
	-- marking (EFT 1.1.0's "Tigr Safari": mark one vehicle with an MS2000 marker)
	{ id = "R8", trader = "rook", tl = 2, name = "Shop Lights", level = 12,
		desc = "Put a marker on the NESTA sign tower and the BOLTWORKS sign tower outside Meridian Mall. My spotters will do the rest.",
		obj = { mark("MM_NESTA_TOWER", "meridian"), mark("MM_BOLT_TOWER", "meridian") }, reward = { money = 45000, xp = 2000, rep = 0.35 } },
	{ id = "R9", trader = "rook", tl = 2, name = "Cold Cargo", level = 14, after = "R7",
		desc = "The quay's customs seal press is in the cold store on Quay 7. With it, any crate I like is cleared.",
		obj = { find("QI_SEAL", "Q7_COLDSTORE", "quay7"), handin("QI_SEAL", 1) }, reward = { money = 50000, xp = 2200, rep = 0.4 } },
	-- LL3: three at once
	{ id = "R10", trader = "rook", tl = 3, name = "Ghost Courier", level = 22,
		desc = "Leave Border Yard through the smugglers' hole. If you can find the way, so can my couriers.",
		obj = { extract(1, "SH", nil, "border") }, reward = { money = 100000, xp = 3500, rep = 1.2 } },
	{ id = "R11", trader = "rook", tl = 3, name = "Market Day", level = 24,
		desc = "Operators camp the food court in Meridian Mall and tax my runners. Four of them, in the food court.",
		obj = { kill("pmc", 4, { map = "meridian", zone = "MM_FOOD_COURT" }) }, reward = { money = 120000, xp = 4000, rep = 1.2 } },
	{ id = "R12", trader = "rook", tl = 3, name = "Paid in Full", level = 25,
		desc = "Two gold chains, a captain's watch and two old coins, found out there. Call it interest.",
		obj = { handin("GOLD_CHAIN", 2), handin("CAPT_WATCH", 1), handin("OLD_COIN", 2) }, reward = { money = 120000, xp = 4000, rep = 1.2 } },
	-- LL4
	{ id = "R13", trader = "rook", tl = 4, name = "Last Crossing", level = 38,
		desc = "Take the smugglers' boat out of Border Yard. Twice. Then we talk about the big run.",
		obj = { extract(2, "SB", nil, "border") }, reward = { money = 200000, xp = 6000, rep = 0.3 } },
	{ id = "R14", trader = "rook", tl = 4, name = "Fixer's Cut", level = 38,
		desc = "A cold wallet and a graphics card, found out there. My cut of the old days.",
		obj = { handin("COLD_WALLET", 1), handin("GPU_CARD", 1) }, reward = { money = 220000, xp = 6000, rep = 0.3 } },

	-- ════ DEKKER (EFT's Peacekeeper) ════════════════════════════════════════════════════════════════════════════════
	-- LL1: T2, D1, D2 and D3 at once
	-- after EFT's "Fishing Gear" (Peacekeeper: locate the boat hidden by the breakwater on Shoreline; tarkovforge.com/
	-- task-guide/fishing-gear)
	{ id = "T2", trader = "dekker", tl = 1, name = "Tide Marks", level = 2, after = "T1",
		desc = "Check that the pier boat and the relay tower are still standing.",
		obj = { visit("PIER3", "quay7"), visit("RELAY", "quay7") }, reward = { money = 30000, xp = 1000, rep = 0.07 } },
	-- after EFT 1.1.0's "Fishing Gear" (stash a multitool and UNTAR body armour; allthings.how): our UN vest is ARMOR_C3
	{ id = "D1", trader = "dekker", tl = 1, name = "Waterproof", level = 3,
		desc = "My people will need tools and a vest when they come ashore on Quay 7. Leave a multitool and a patrol vest at the pier 3 boat.",
		obj = { plant("MULTITOOL", "Q7_BOAT", "quay7"), plant("ARMOR_C3", "Q7_BOAT", "quay7") }, reward = { money = 15000, xp = 800, rep = 0.15 } },
	{ id = "D2", trader = "dekker", tl = 1, name = "Patrol Duty", level = 2,
		desc = "The quay needs a patrol and I have none. Five scavs on Quay 7, with a rifle.",
		obj = { kill("scav", 5, { map = "quay7", weapon = "rifle" }) }, reward = { money = 12000, xp = 700, rep = 0.15 } },
	{ id = "D3", trader = "dekker", tl = 1, name = "Line of Sight", level = 4,
		desc = "I need eyes on the west of Border Yard. Get into the army post hut, then up on the depot roof.",
		obj = { visit("BY_ARMYHUT", "border"), visit("BY_DEPOT_ROOF", "border") }, reward = { money = 15000, xp = 900, rep = 0.2 } },
	-- LL2: four at once
	{ id = "D4", trader = "dekker", tl = 2, name = "Tape Delay", level = 9,
		desc = "Meridian's security room recorded the day the mall fell. The tape is still in the machine. Bring it before somebody wipes it.",
		obj = { find("QI_TAPE", "MM_SECURITY", "meridian"), handin("QI_TAPE", 1) }, reward = { money = 40000, xp = 1800, rep = 0.45 } },
	-- distance on PMC kills (EFT: "beyond 20-100 m"; EFT wiki Quests)
	{ id = "D5", trader = "dekker", tl = 2, name = "Wet Work", level = 11,
		desc = "Three operators on Border Yard, from fifty metres or more. Nobody gets close to my people.",
		obj = { kill("pmc", 3, { map = "border", dist = 50 }) }, reward = { money = 50000, xp = 2200, rep = 0.5 } },
	{ id = "D6", trader = "dekker", tl = 2, name = "Armoury Count", level = 12,
		desc = "The army post hut kept a register of every rifle in its armoury. I want to know where they went.",
		obj = { find("QI_REGISTER", "BY_ARMYHUT", "border"), handin("QI_REGISTER", 1) }, reward = { money = 45000, xp = 2000, rep = 0.45 } },
	-- after EFT's signal tasks (Mechanic's "Signal" series): beacons at two places
	{ id = "D7", trader = "dekker", tl = 2, name = "Relay Watch", level = 13,
		desc = "Plant a signal beacon at the relay tower on Quay 7 and one on the furnace catwalk in the Smelter. KOVAC sells them.",
		obj = { plant("BEACON", "RELAY", "quay7"), plant("BEACON", "SM_CATWALK", "smelter") }, reward = { money = 50000, xp = 2200, rep = 0.45 } },
	-- LL3: three at once
	{ id = "D8", trader = "dekker", tl = 3, name = "Night Optics", level = 19,
		desc = "Night is when the scavs move my crates. Six of them on Border Yard, between nine at night and five in the morning.",
		obj = { kill("scav", 6, { map = "border", time = { 21, 5 } }) }, reward = { money = 90000, xp = 3500, rep = 1.3 } },
	{ id = "D9", trader = "dekker", tl = 3, name = "Hound Hunt", level = 22,
		desc = "Halberd and his Hounds shot up one of my convoys on Border Yard. Halberd himself. Nobody else will do.",
		obj = { kill("boss", 1, "Halberd") }, reward = { money = 150000, xp = 4500, rep = 1.35 } },
	{ id = "D10", trader = "dekker", tl = 3, name = "Hard Currency", level = 20,
		desc = "Two flash modules and an intel folder, found out there. My buyers pay in favours.",
		obj = { handin("FLASH_MODULE", 2), handin("INTEL_FOLDER", 1) }, reward = { money = 120000, xp = 4000, rep = 1.35 } },
	-- LL4
	{ id = "D11", trader = "dekker", tl = 4, name = "Blue Line", level = 37,
		desc = "Five operators, head shots, from forty metres or more. The mission's standards.",
		obj = { kill("pmc", 5, { part = "head", dist = 40 }) }, reward = { money = 200000, xp = 6000, rep = 0.3 } },
	{ id = "D12", trader = "dekker", tl = 4, name = "Full Mandate", level = 37,
		desc = "Walk out of Border Yard, Meridian Mall, the Smelter and Quay 7 alive. Then you can call yourself a peacekeeper.",
		obj = { extract(1, nil, nil, "border"), extract(1, nil, nil, "meridian"), extract(1, nil, nil, "smelter"), extract(1, nil, nil, "quay7") },
		reward = { money = 180000, xp = 6000, rep = 0.3 } },

	-- ════ KOVAC (EFT's Mechanic) ════════════════════════════════════════════════════════════════════════════════════
	-- LL1: V5, K1, K2 and K3 at once; K4 after K2, K5 after K3
	-- V5 is KOVAC's (EFT's Mechanic) since decision economy-2a: after EFT's "Signal - Part 1" (Mechanic: two signal sources
	-- on high points of one map, in one raid; consolepcgaming.com/eft-signal-part-1)
	{ id = "V5", trader = "kovac", tl = 1, name = "High Ground", level = 5, after = "V2",
		desc = "Two places on Border Yard see the whole crossing: the top of the derrick and the top of the frame. Climb both and tell me who has been up there.",
		obj = { visit("DERRICK", "border"), visit("FRAME", "border") }, reward = { money = 35000, xp = 1600, rep = 0.05 } },
	{ id = "K1", trader = "kovac", tl = 1, name = "Spare Parts", level = 1,
		desc = "Spark plugs, wire and a capacitor, found out there. The bench eats them.",
		obj = { handin("SPARK_PLUG", 2), handin("WIRES", 2), handin("CAPACITOR", 1) }, reward = { money = 12000, xp = 700, rep = 0.15 } },
	-- the gunsmith series after EFT's "Gunsmith - Part 1" (Mechanic, level 2: modify an MP-133 to durability 60, ergonomics
	-- 47 or more, recoil 850 or less, 4 cells or fewer, a magazine of 5 or more and a tactical device; it unlocks a gas block
	-- at Mechanic LL1; escapefromtarkov.fandom.com/wiki/Gunsmith_-_Part_1). Figures are ours, set on our parts.
	{ id = "K2", trader = "kovac", tl = 1, name = "Bench Work - Part 1", level = 2,
		desc = "Show me you can hold a screwdriver. A P-9 with a light or a laser on it, still handy, recoil in check.",
		obj = { build("P9_PISTOL", { dur = 60, ergo = 82, recoil = 740, cap = 17, device = true }, { preset = "P9_PISTOL", add = { { "P9_PISTOL", "tactical", "LIGHT_T" } } }) },
		reward = { money = 10000, xp = 500, rep = 0.15, items = { { "BOLTS", 1 } } } },
	-- after the Mechanic's "Signal" tasks: a beacon at a place
	{ id = "K3", trader = "kovac", tl = 1, name = "Static", level = 5,
		desc = "Plant one of my signal beacons in the Smelter's pump house and get out. I want to hear what the furnace crews say on the radio.",
		obj = { plant("BEACON", "SM_PUMPHOUSE", "smelter"), extract(1, nil, nil, "smelter") }, reward = { money = 15000, xp = 800, rep = 0.15 } },
	{ id = "K4", trader = "kovac", tl = 1, name = "Bench Work - Part 2", level = 6, after = "K2",
		desc = "An SMG-9 that does not climb: a muzzle device on it, recoil down, still light in the hand.",
		obj = { build("SPARROW_SMG", { dur = 60, ergo = 68, recoil = 248, cap = 30, muzzle = true }, { preset = "SPARROW_SMG", add = { { "SPARROW_SMG", "muzzle", "SPR_FH_3L" } } }) },
		reward = { money = 15000, xp = 900, rep = 0.15 } },
	-- after EFT 1.1.0's "Informed Means Armed" (WI-FI cameras on Woods and Interchange; allthings.how)
	{ id = "K5", trader = "kovac", tl = 1, name = "Eyes On", level = 8, after = "K3",
		desc = "Set my trail cameras: one at the kart track outside Meridian Mall, one by the main bridge on Border Yard.",
		obj = { plant("CAMERA", "KART_TRACK", "meridian"), plant("CAMERA", "BY_BRIDGE", "border") }, reward = { money = 20000, xp = 1000, rep = 0.15 } },
	-- LL2: K6, K7, K8 and K9 at once; K10 after K7
	{ id = "K6", trader = "kovac", tl = 2, name = "Circuitry", level = 13,
		desc = "Two logic boards and a military circuit, found out there. I am building something.",
		obj = { handin("LOGIC_BOARD", 2), handin("MIL_CIRCUIT", 1) }, reward = { money = 45000, xp = 2000, rep = 0.35 } },
	{ id = "K7", trader = "kovac", tl = 2, name = "Bench Work - Part 3", level = 13,
		desc = "An R-17 for a patrol: a tactical device, a foregrip, ergonomics 54 or better, recoil 265 or less.",
		obj = { build("R17_RIFLE", { dur = 60, ergo = 54, recoil = 265, cap = 25, device = true, foregrip = true }, { preset = "R17_PATROL", swap = { AR_CH_STD = "AR_CH_EXT" } }) },
		reward = { money = 40000, xp = 2000, rep = 0.35 } },
	{ id = "K8", trader = "kovac", tl = 2, name = "Container Count", level = 15,
		desc = "UNIT 14 under Meridian Mall had an inventory sheet taped inside. I want to know what was in those crates.",
		obj = { find("QI_UNIT14", "MM_UNIT14", "meridian"), handin("QI_UNIT14", 1) }, reward = { money = 50000, xp = 2200, rep = 0.35 } },
	{ id = "K9", trader = "kovac", tl = 2, name = "Test Fire", level = 16,
		desc = "I need to know an SMG holds up. Ten scavs in the Smelter with one.",
		obj = { kill("scav", 10, { map = "smelter", weapon = "smg" }) }, reward = { money = 45000, xp = 2000, rep = 0.3 } },
	{ id = "K10", trader = "kovac", tl = 2, name = "Bench Work - Part 4", level = 18, after = "K7",
		desc = "A suppressed KS-7 with a red dot or a holo, ergonomics 35 or better, recoil 280 or less.",
		obj = { build("KST_RIFLE", { dur = 60, ergo = 35, recoil = 280, cap = 30, suppressed = true, sight = true }, { preset = "KST_TAC", swap = { BRAKE_76 = "SUPP_76" } }) },
		reward = { money = 50000, xp = 2500, rep = 0.35 } },
	-- LL3: K11, K12, K13 and K14 at once; K15 after K13
	{ id = "K11", trader = "kovac", tl = 3, name = "Graphics Department", level = 26,
		desc = "Two graphics cards, found out there. Do not ask.",
		obj = { handin("GPU_CARD", 2) }, reward = { money = 120000, xp = 4000, rep = 1.45 } },
	{ id = "K12", trader = "kovac", tl = 3, name = "Furnace Readings", level = 27,
		desc = "The Smelter's manager logged every furnace run in his office. I need those readings.",
		obj = { find("QI_FURNACE", "SM_MANAGER", "smelter"), handin("QI_FURNACE", 1) }, reward = { money = 120000, xp = 4000, rep = 1.45 } },
	{ id = "K13", trader = "kovac", tl = 3, name = "Bench Work - Part 5", level = 28,
		desc = "A quiet Tundra: a scope of 4x or more, a suppressor, a minute of angle or better, and no heavier than 5.5 kg.",
		obj = { build("TUNDRA_BOLT", { dur = 60, ergo = 15, recoil = 690, zoom = 4, suppressed = true, moa = 1.0, mass = 5.5 }, { preset = "TUN_SCOUT", swap = { TUN_BRK = "SUPP_76L" } }) },
		reward = { money = 100000, xp = 4000, rep = 1.45 } },
	{ id = "K14", trader = "kovac", tl = 3, name = "Black Box", level = 30,
		desc = "Two more cameras: the crane yard on Quay 7 and the hopper wagons on the Smelter's rail siding.",
		obj = { plant("CAMERA", "Q7_CRANE", "quay7"), plant("CAMERA", "SM_SIDING", "smelter") }, reward = { money = 120000, xp = 4500, rep = 1.45 } },
	{ id = "K15", trader = "kovac", tl = 3, name = "Bench Work - Part 6", level = 33, after = "K13",
		desc = "A marksman R-17: 6x or more, forty rounds, two and a half minutes of angle or better, ergonomics 36, recoil 230.",
		obj = { build("R17_RIFLE", { dur = 60, ergo = 36, recoil = 230, cap = 40, zoom = 6, moa = 2.4 }, { preset = "R17_DMR", swap = { AR_PG_A2 = "AR_PG_ERGO" } }) },
		reward = { money = 150000, xp = 5000, rep = 0.3 } },
	-- LL4
	{ id = "K16", trader = "kovac", tl = 4, name = "Bench Work - Part 7", level = 40,
		desc = "The best SMG-9 you can make: suppressed, a light and a laser, a sight, ergonomics 60, recoil 210.",
		obj = { build("SPARROW_SMG", { dur = 60, ergo = 60, recoil = 210, cap = 30, suppressed = true, light = true, laser = true, sight = true }, { preset = "SPR_TAC", swap = { SPR_STK_FIXED = "SPR_STK_SLIDE" } }) },
		reward = { money = 200000, xp = 6000, rep = 0.3 } },
	{ id = "K17", trader = "kovac", tl = 4, name = "Precision Order", level = 40,
		desc = "Two military circuits, found out there. The last piece.",
		obj = { handin("MIL_CIRCUIT", 2) }, reward = { money = 220000, xp = 6000, rep = 0.3 } },

	-- ════ TILDA (EFT's Ragman) ══════════════════════════════════════════════════════════════════════════════════════
	-- LL1: T1, T6, L1 and L2 at once; L3 after L1, L4 after L2
	{ id = "T1", trader = "tilda", tl = 1, name = "Dress Code", level = 1, after = nil,
		desc = "Cigarettes and matches buy thread around here. Bring me some.",
		obj = { handin("CIGARETTES", 2), handin("MATCHES", 2) }, reward = { money = 10000, xp = 300, rep = 0.05, items = { { "BAG_SLING", 1 } } } },
	-- after EFT's "Big Sale" (Ragman: visit five Interchange stores and extract; 8,200 XP, +0.03, 30,000 roubles and a
	-- backpack; sportskeeda.com), in Meridian Mall
	{ id = "T6", trader = "tilda", tl = 1, name = "Window Shopping", level = 8, after = "T2",
		desc = "I want to know what is left in Meridian Mall. Walk the concourse, look into IRONSIGHT and the kart track, then get out with your eyes intact.",
		obj = { visit("CONCOURSE", "meridian"), visit("IRONSIGHT", "meridian"), visit("KART_TRACK", "meridian"), extract(1, nil, nil, "meridian") },
		reward = { money = 30000, xp = 3000, rep = 0.03, items = { { "CANVAS_BAG", 1 } } } },
	{ id = "L1", trader = "tilda", tl = 1, name = "Field Wardrobe", level = 2,
		desc = "A field cap and a knit beanie, found out there. Customers like a story with their clothes.",
		obj = { handin("CAP_FIELD", 1), handin("BEANIE", 1) }, reward = { money = 10000, xp = 600, rep = 0.12 } },
	{ id = "L2", trader = "tilda", tl = 1, name = "Shades", level = 3,
		desc = "Two pairs of sport sunglasses, found out there. Do not scratch them.",
		obj = { handin("GLASSES_SUN", 2) }, reward = { money = 12000, xp = 700, rep = 0.12 } },
	{ id = "L3", trader = "tilda", tl = 1, name = "Mall Rats", level = 5, after = "L1",
		desc = "Scavs are wearing my stock around the KASSA hall in Meridian Mall. Six of them, in the hall.",
		obj = { kill("scav", 6, { map = "meridian", zone = "MM_KASSA" }) }, reward = { money = 15000, xp = 900, rep = 0.12 } },
	{ id = "L4", trader = "tilda", tl = 1, name = "Patchwork", level = 6, after = "L2",
		desc = "A shell helmet and a quay security vest, found out there. I can make two good ones from them.",
		obj = { handin("HELMET_C2", 1), handin("ARMOR_C2", 1) }, reward = { money = 18000, xp = 1000, rep = 0.12 } },
	-- LL2: four at once
	{ id = "L5", trader = "tilda", tl = 2, name = "Fitting Room", level = 13,
		desc = "A chest rig and a canvas pack, found out there.",
		obj = { handin("RIG_CHEST", 1), handin("CANVAS_BAG", 1) }, reward = { money = 40000, xp = 1800, rep = 0.4 } },
	{ id = "L6", trader = "tilda", tl = 2, name = "Price Check", level = 14,
		desc = "BOLTWORKS priced everything in a ledger in their offices. I want to know what they charged for what I sell.",
		obj = { find("QI_PRICELIST", "MM_BOLT_OFFICE", "meridian"), handin("QI_PRICELIST", 1) }, reward = { money = 45000, xp = 2000, rep = 0.4 } },
	-- body part (EFT's operational kills with a body part; EFT wiki Quests)
	{ id = "L7", trader = "tilda", tl = 2, name = "Sharp Dressers", level = 15,
		desc = "Eight scavs in Meridian Mall, shot through the head. I want the jackets clean.",
		obj = { kill("scav", 8, { map = "meridian", part = "head" }) }, reward = { money = 45000, xp = 2000, rep = 0.4 } },
	{ id = "L8", trader = "tilda", tl = 2, name = "Under the Mall", level = 16,
		desc = "Six scavs down in the car park under Meridian Mall, then get yourself out.",
		obj = { kill("scav", 6, { map = "meridian", zone = "MM_CARPARK" }), extract(1, nil, nil, "meridian") }, reward = { money = 45000, xp = 2000, rep = 0.45 } },
	-- LL3: four at once
	{ id = "L9", trader = "tilda", tl = 3, name = "Heavy Order", level = 27,
		desc = "A PC-4 carrier and a B4 helmet, found out there.",
		obj = { handin("ARMOR_C4", 1), handin("HELMET_C4", 1) }, reward = { money = 110000, xp = 4000, rep = 1.2 } },
	{ id = "L10", trader = "tilda", tl = 3, name = "Shelter Inventory", level = 28,
		desc = "Get into the shelter under Meridian Mall and out through its own door. I hear it is fitted out like a showroom.",
		obj = { visit("SHELTER", "meridian"), extract(1, "SE", nil, "meridian") }, reward = { money = 120000, xp = 4000, rep = 1.2 } },
	{ id = "L11", trader = "tilda", tl = 3, name = "Fashion Week", level = 30,
		desc = "Six operators in Meridian Mall. They wear the best kit in the city, and I want it off the market.",
		obj = { kill("pmc", 6, { map = "meridian" }) }, reward = { money = 150000, xp = 4500, rep = 1.2 } },
	-- night without night vision (EFT's "The Survivalist Path - Eagle-Owl": 6 Scavs at 21:00-04:00 without NVGs or thermal
	-- sights; gamemaps.net)
	{ id = "L12", trader = "tilda", tl = 3, name = "Lights Out", level = 29,
		desc = "Ten scavs in Meridian Mall between ten at night and five in the morning, with no night vision. Your own eyes only.",
		obj = { kill("scav", 10, { map = "meridian", time = { 22, 5 }, noNv = true }) }, reward = { money = 120000, xp = 4000, rep = 1.2 } },
	-- LL4
	{ id = "L13", trader = "tilda", tl = 4, name = "Full Kit", level = 40,
		desc = "An HP-5 heavy vest and a raid pack, found out there.",
		obj = { handin("ARMOR_C5", 1), handin("BAG_RAID", 1) }, reward = { money = 220000, xp = 6000, rep = 0.3 } },
	{ id = "L14", trader = "tilda", tl = 4, name = "Tailor's Reserve", level = 40,
		desc = "A comms headset and AF-2 glasses, found out there.",
		obj = { handin("HEADSET_COMM", 1), handin("GLASSES_AF2", 1) }, reward = { money = 180000, xp = 6000, rep = 0.3 } },

	-- ════ BRAM (EFT's Jaeger) ═══════════════════════════════════════════════════════════════════════════════════════
	-- LL1: T5, B1, B2 and B3 at once; B4 after B1
	-- the Sealed Drive had no use (audit economy.8): someone wants what is on it, like Tarkov's data-carrier tasks. BRAM's:
	-- after EFT's "Shady Business" (Jaeger: find 3 Secure Flash drives in raid and hand them over; consolepcgaming.com/
	-- eft-shady-business)
	{ id = "T5", trader = "bram", tl = 1, name = "Sealed Records", level = 9, after = "T3",
		desc = "The evacuation office kept its records on sealed drives. Find two and bring them to me unopened.",
		obj = { handin("SEALED_DRIVE", 2) }, reward = { money = 180000, xp = 5000, rep = 0.12 } },
	-- after Jaeger's first task (hand over food)
	{ id = "B1", trader = "bram", tl = 1, name = "Camp Rations", level = 1,
		desc = "Two packs of hardtack and two bottles of water, found out there. The camp eats before it talks.",
		obj = { handin("HARDTACK", 2), handin("WATER", 2) }, reward = { money = 10000, xp = 600, rep = 0.15 } },
	-- after EFT's "The Survivalist Path - Eagle-Owl" (Jaeger, level 2: 6 Scavs at 21:00-04:00 without NVGs or thermal sights;
	-- +0.02, 40,000 roubles; gamemaps.net)
	{ id = "B2", trader = "bram", tl = 1, name = "Night Owl", level = 2,
		desc = "A hunter sees in the dark. Six scavs between nine at night and four in the morning, without night vision.",
		obj = { kill("scav", 6, { time = { 21, 4 }, noNv = true }) }, reward = { money = 20000, xp = 1000, rep = 0.15 } },
	-- after EFT's "The Tarkov Shooter" series (Jaeger: bolt-action kills)
	{ id = "B3", trader = "bram", tl = 1, name = "Patient Shot", level = 4,
		desc = "Five scavs with a bolt-action rifle, each from forty metres or more. One breath, one shot.",
		obj = { kill("scav", 5, { weapon = "bolt", dist = 40 }) }, reward = { money = 18000, xp = 900, rep = 0.15 } },
	-- after EFT's "The Huntsman Path - Forest Cleaning" (Jaeger: Scavs on Woods), on Border Yard's woods and yards
	{ id = "B4", trader = "bram", tl = 1, name = "Thinning the Yard", level = 5, after = "B1",
		desc = "Too many scavs on Border Yard for the game to come back. Ten of them.",
		obj = { kill("scav", 10, { map = "border" }) }, reward = { money = 18000, xp = 900, rep = 0.12 } },
	-- LL2: T4, V7, B5 and B7 at once; B6 after B5
	-- the Foreman by name: any boss used to count (audit economy.9). BRAM's (EFT's Jaeger): EFT's boss hunts are Jaeger's
	-- "The Huntsman Path" tasks (Trophy: Reshala, as V7)
	{ id = "T4", trader = "bram", tl = 2, name = "Heavy Plate", level = 7, after = "T3",
		desc = "The Foreman wears the best plate on the quay. Take it off him.",
		obj = { kill("boss", 1, "Foreman") }, reward = { money = 120000, xp = 4000, rep = 0.12, items = { { "ARMOR_C4", 1 } } } },
	-- the second boss task with its own target (audit economy.9), after EFT's "The Huntsman Path - Trophy" (Jaeger: locate
	-- and neutralize Reshala, +3,000 XP, +0.10 standing, no money; tarkovforge.com/task-guide). EFT also wants his golden
	-- TT handed in; the Broker carries no unique item yet. Trophy is Jaeger's, so the task is BRAM's (decision economy-2a).
	{ id = "V7", trader = "bram", tl = 2, name = "Dealer's Due", level = 10, after = "V3",
		desc = "The Broker sells our crates back to us out of the Border Yard dorms. He has bodyguards. Settle it.",
		obj = { kill("boss", 1, "Broker") }, reward = { xp = 3000, rep = 0.1 } },
	-- after EFT's "The Huntsman Path - Factory Chief" (Jaeger, level 12: eliminate Tagilla, find his BOSS cap in raid and hand
	-- it over; 700,000 roubles, +0.02; gamemaps.net): our Stoker and his welding mask
	{ id = "B5", trader = "bram", tl = 2, name = "Hot Iron", level = 12,
		desc = "The Stoker swings his hammer in the Smelter like he owns it. Put him down and bring me that welding mask of his.",
		obj = { kill("boss", 1, "Stoker"), handin("MASK_WELDER", 1) }, reward = { money = 120000, xp = 3500, rep = 0.5 } },
	-- after EFT's "The Tarkov Shooter - Part 5" (Jaeger: 8 Scavs on Customs with a bolt-action rifle at 21:00-5:00; +0.02,
	-- 80,000 roubles; gamemaps.net)
	{ id = "B6", trader = "bram", tl = 2, name = "Dusk Rounds", level = 13, after = "B5",
		desc = "Six scavs on Border Yard with a bolt-action rifle, between nine at night and five in the morning.",
		obj = { kill("scav", 6, { map = "border", weapon = "bolt", time = { 21, 5 } }) }, reward = { money = 60000, xp = 2500, rep = 0.5 } },
	-- after EFT's survivalist kills without armour (Jaeger's "The Survivalist Path")
	{ id = "B7", trader = "bram", tl = 2, name = "Bare Skin", level = 11,
		desc = "Five scavs with no body armour and no helmet on you. Learn what it is to be the prey.",
		obj = { kill("scav", 5, { noArmor = true }) }, reward = { money = 40000, xp = 1800, rep = 0.5 } },
	-- LL3: four at once
	{ id = "B8", trader = "bram", tl = 3, name = "Hounds' Den", level = 20,
		desc = "Halberd's Hounds: Mortar and Kestrel. Both of them, on Border Yard.",
		obj = { kill("follower", 1, { label = "Mortar" }), kill("follower", 1, { label = "Kestrel" }) }, reward = { money = 140000, xp = 4500, rep = 1.35 } },
	{ id = "B9", trader = "bram", tl = 3, name = "Candlelight", level = 22,
		desc = "The cult lights candles in the dark and hunts with knives. Four of the cultists.",
		obj = { kill("follower", 4, { label = "Cultist" }) }, reward = { money = 120000, xp = 4000, rep = 1.35 } },
	{ id = "B10", trader = "bram", tl = 3, name = "Woodsman", level = 24,
		desc = "The Forester walks the trees on Border Yard and takes what he likes. Hunt the hunter.",
		obj = { kill("boss", 1, "Forester") }, reward = { money = 150000, xp = 4500, rep = 1.35 } },
	{ id = "B11", trader = "bram", tl = 3, name = "Long Shot", level = 26,
		desc = "Three operators with a bolt-action rifle, from a hundred metres or more.",
		obj = { kill("pmc", 3, { weapon = "bolt", dist = 100 }) }, reward = { money = 150000, xp = 5000, rep = 1.35 } },
	-- LL4
	{ id = "B12", trader = "bram", tl = 4, name = "Last Rites", level = 34,
		desc = "The cult's priest. End it.",
		obj = { kill("boss", 1, "Priest") }, reward = { money = 200000, xp = 6000, rep = 0.3 } },
	{ id = "B13", trader = "bram", tl = 4, name = "Caretaker", level = 35,
		desc = "The Caretaker keeps Meridian Mall like it is his. It is not. Bring him down.",
		obj = { kill("boss", 1, "Caretaker") }, reward = { money = 220000, xp = 6000, rep = 0.3 } },

	-- ════ FENCE ═════════════════════════════════════════════════════════════════════════════════════════════════════
	-- (Fence's loyalty comes from karma, so his tasks pay karma and have no LL group)
	{ id = "F1", trader = "fence", name = "Local Rules", level = 1, after = nil,
		desc = "Go in as one of the locals and come back. Twice. Don't make enemies.",
		obj = { extract(2, nil, true) }, reward = { money = 10000, xp = 400, karma = 0.5 } },
	-- a scav errand on Border Yard; EFT's Fence assignments pay +0.01 to +0.05 standing (escapefromtarkov.party karma guide)
	{ id = "F3", trader = "fence", name = "Smugglers' Way", level = 1, after = "F1",
		desc = "As a local, find the smugglers' hole on Border Yard and walk out the way you came. Nobody sees you, nobody gets hurt.",
		obj = { visit("SMUGGLERS", "border", true), extract(1, nil, true, "border") }, reward = { money = 15000, xp = 600, karma = 0.05 } },
	-- scav raids for Fence (EFT's Fence tasks are played as a scav; his scav operational tasks too: altchar.com)
	{ id = "F4", trader = "fence", name = "Good Neighbour", level = 5, after = "F1",
		desc = "Walk out of Meridian Mall as a local three times. The mall people should know your face.",
		obj = { extract(3, nil, true, "meridian") }, reward = { money = 20000, xp = 800, karma = 0.1 } },
	{ id = "F5", trader = "fence", name = "Bad Blood", level = 10, after = "F1",
		desc = "Operators shoot my people on sight. As a local, return the favour: two of them.",
		obj = { kill("pmc", 2, { scav = true }) }, reward = { money = 40000, xp = 1500, karma = 0.15 } },
	{ id = "F6", trader = "fence", name = "Tags", level = 15, after = "F5",
		desc = "Five dog tags, found out there. I collect what others leave behind.",
		obj = { handin("DOGTAG", 5) }, reward = { money = 60000, xp = 2000, karma = 0.2 } },
	-- Pouch L (audit economy.7) as EFT's Kappa, the reward of Fence's "The Collector": since 1.1.0 it needs character
	-- level 40, LL4 with every trader, a Fence standing of 3.0 and the last task of each trader's chain (timesaver.gg,
	-- 24 Jul 2026, quoting Battlestate), then 44 collectibles, one each, all found in raid, for the container alone: "no
	-- rouble or XP payout" (timesaver.gg checklist, 26 Sep 2026). Ours: ten of the rarest valuables, one from each corner
	-- of the maps.
	{ id = "F2", trader = "fence", name = "Keepsakes", level = 40, after = "F1", needs = { "V4", "H4", "T4", "T5" }, karma = 3, ll = 4,
		desc = "I keep a cabinet of things nobody else can find. Bring me one of each, found out there with your own hands, and the best pouch I have is yours.",
		obj = {
			handin("OLD_COIN", 1), handin("CAPT_WATCH", 1), handin("GOLD_CHAIN", 1), handin("BRASS_LION", 1), handin("RITUAL_AMULET", 1),
			handin("INTEL_FOLDER", 1), handin("FLASH_MODULE", 1), handin("COLD_WALLET", 1), handin("GPU_CARD", 1), handin("PHONE", 1),
		},
		reward = { items = { { "SECURE_L", 1 } } } },
}

Q.byId = {}
for _, q in Q.list do
	Q.byId[q.id] = q
end

-- task places are defined per map (World on Quay 7, src/server/Maps/* on the others: position + radius); names for the UI
Q.ZONE_NAMES = {
	PIER3 = "Pier 3 boat", RELAY = "Relay tower",
	DORM314 = "block A room 314", BOILER = "the boiler house cellar", DERRICK = "the top of the derrick", FRAME = "the top of the frame",
	SMUGGLERS = "the smugglers' hole",
	SUBSTATION = "the substation switch", SHELTER = "the shelter", IRONSIGHT = "the IRONSIGHT gun shop", CONCOURSE = "the concourse",
	WEST_CAMP = "the west camp", RESCUE_CAMP = "the rescue camp", KART_TRACK = "the kart track",
	STACK = "the slag stack",
	-- economy-6a
	BY_TANK1 = "fuel tank 1 at the tank farm", BY_TANK3 = "fuel tank 3 at the tank farm", BY_DORMS = "the dorm yard",
	BY_BASTION = "the Bastion", BY_BRIDGE = "the main bridge", BY_WATCHROOM = "the watchhouse watch room", BY_SQUAT = "the squat",
	BY_STORE17 = "the Store 17 foreman's office", BY_BOAT = "the smugglers' boat", BY_RED_CAGE = "the Red Stores cage",
	BY_ARMYHUT = "the army post hut", BY_DEPOT_ROOF = "the depot roof",
	MM_KASSA = "the KASSA hall", MM_FOOD_COURT = "the food court", MM_MEDIQ = "the MEDIQ store room", MM_SECURITY = "the security room",
	MM_UNIT14 = "UNIT 14", MM_BOLT_OFFICE = "the BOLTWORKS offices", MM_RESCUE_POINT = "the RESCUE POINT store",
	MM_NESTA_TOWER = "the NESTA sign tower", MM_BOLT_TOWER = "the BOLTWORKS sign tower", MM_CARPARK = "the underground car park",
	SM_CATWALK = "the furnace catwalk", SM_MANAGER = "the manager's office", SM_CASTING = "the casting shed",
	SM_PUMPHOUSE = "the pump house", SM_SIDING = "the hopper wagons on the siding",
	Q7_DORM203 = "dorm room 203", Q7_COLDSTORE = "the cold store", Q7_BOAT = "the pier 3 boat", Q7_CRANE = "the crane yard",
}

-- the task places economy-6a added, for the coordinator to place in the maps' W.visitZones (TaskTests reports any that is
-- still missing as pending): map, where, radius in studs (h: half height, for a place on one floor), what for
Q.NEW_ZONES = {
	BY_TANK1 = { map = "border", r = 5, where = "FUEL TANK 1 at the tank farm (-1430, -200): the foot of the tank by its stair", what = "mark" },
	BY_TANK3 = { map = "border", r = 5, where = "FUEL TANK 3 at the tank farm: the foot of the tank by its stair", what = "mark" },
	BY_DORMS = { map = "border", r = 110, h = 30, where = "the yard between BLOCK A and BLOCK B (-130, 600)", what = "kill area" },
	BY_BASTION = { map = "border", r = 70, h = 25, where = "THE BASTION and its walled yard (-125, -300)", what = "kill area" },
	BY_BRIDGE = { map = "border", r = 60, h = 20, where = "the MAIN BRIDGE deck (729, 130)", what = "kill area, camera" },
	BY_WATCHROOM = { map = "border", r = 4, where = "the watch room upstairs in the WATCHHOUSE (-1272, -108), behind KEY_BY_WATCHROOM's door", what = "quest item" },
	BY_SQUAT = { map = "border", r = 4, where = "a shelf or table inside THE SQUAT (247, -379)", what = "quest item" },
	BY_STORE17 = { map = "border", r = 4, where = "the foreman's office on the STORE 17 mezzanine (360, -94)", what = "quest item" },
	BY_BOAT = { map = "border", r = 5, where = "aboard the SMUGGLERS' BOAT exit's boat (625, 474)", what = "quest item" },
	BY_RED_CAGE = { map = "border", r = 4, where = "inside the wire cage of seized goods in the RED STORES (1163, -273)", what = "quest item" },
	BY_ARMYHUT = { map = "border", r = 4, where = "the armoury of the ARMY POST HUT (-1310, 150), behind KEY_BY_ARMYHUT's door", what = "visit, quest item" },
	BY_DEPOT_ROOF = { map = "border", r = 10, where = "the DEPOT roof perch (-976, -101), 42 studs up", what = "visit" },
	MM_KASSA = { map = "meridian", r = 140, h = 16, where = "the KASSA anchor hall on L1 (its middle)", what = "kill area" },
	MM_FOOD_COURT = { map = "meridian", r = 60, h = 12, where = "the L2 food court among the food units", what = "kill area" },
	MM_MEDIQ = { map = "meridian", r = 4, where = "the MEDIQ STORE ROOM (L2_ultra_med_locked_room, KEY_MEDIQ)", what = "quest item" },
	MM_SECURITY = { map = "meridian", r = 4, where = "the SECURITY room on L1 (593, 230), on the desk by the monitor", what = "quest item" },
	MM_UNIT14 = { map = "meridian", r = 4, where = "inside UNIT 14 in car park A (behind the card door at 34, -819)", what = "quest item" },
	MM_BOLT_OFFICE = { map = "meridian", r = 4, where = "a desk in the BOLTWORKS OFFICES (BACK_4)", what = "quest item" },
	MM_RESCUE_POINT = { map = "meridian", r = 4, where = "the counter of the RESCUE POINT store on L1 (L1_emercom)", what = "plant" },
	MM_NESTA_TOWER = { map = "meridian", r = 6, where = "the plinth of the NESTA TOWER sign pylon (112, -1137)", what = "mark" },
	MM_BOLT_TOWER = { map = "meridian", r = 6, where = "the plinth of the BOLTWORKS TOWER sign pylon (-394, 695)", what = "mark" },
	MM_CARPARK = { map = "meridian", r = 300, h = 8, where = "the L0 car parks A to D (centre of the car park level, y about 8)", what = "kill area" },
	SM_CATWALK = { map = "smelter", r = 5, where = "the furnace hall catwalk by the overwatch post (0, DY, -54)", what = "plant" },
	SM_MANAGER = { map = "smelter", r = 4, where = "the desk in the manager's office (door SM_MGR, KEY_SMELT_OFFICE)", what = "quest item" },
	SM_CASTING = { map = "smelter", r = 4, where = "a bench in the casting shed (door SM_SHED, about -15, 0, 34)", what = "quest item" },
	SM_PUMPHOUSE = { map = "smelter", r = 5, where = "inside the pump house (door SM_PUMP, about 76, 0, 50)", what = "plant" },
	SM_SIDING = { map = "smelter", r = 6, where = "beside the hopper wagons on the rail siding (111, 0, -2)", what = "plant" },
	Q7_DORM203 = { map = "quay7", r = 4, where = "inside crew dormitory room 203 (door dorm203, KEY_DORM_203)", what = "quest item" },
	Q7_COLDSTORE = { map = "quay7", r = 4, where = "inside the cold store by the COLD STORE spawn (60, 184)", what = "quest item" },
	Q7_BOAT = { map = "quay7", r = 5, where = "aboard the pier 3 boat (236, 0, 150)", what = "plant" },
	Q7_CRANE = { map = "quay7", r = 5, where = "the foot of the crane in the crane yard by CRANE YARD LIFT (-122, 0, 184)", what = "plant" },
}

-- the bosses and guards a kill objective can name (the AI's Label attribute, set from each map's boss definition)
Q.BOSS_NAMES = {
	Foreman = "the Foreman", Broker = "the Broker", Halberd = "Halberd of the Hounds", Priest = "the cult's priest", Forester = "the Forester",
	Caretaker = "the Caretaker", Stoker = "the Stoker", Mortar = "Mortar of the Hounds", Kestrel = "Kestrel of the Hounds", Cultist = "cultists",
}
Q.BOSS_MAP = { Foreman = "quay7", Broker = "border", Halberd = "border", Priest = "border", Forester = "border", Caretaker = "meridian", Stoker = "smelter" }

local CLASS_NAMES = { rifle = "a rifle", smg = "an SMG", shotgun = "a shotgun", bolt = "a bolt-action rifle", pistol = "a pistol", melee = "a melee weapon", grenade = "grenades" }
local PART_NAMES = { head = "head", thorax = "thorax", stomach = "stomach", arms = "arm", legs = "leg" }

local function mapName(id: string?): string?
	local d = id and (Maps.defs[id] or (Maps.parked :: any)[id])
	return d and d.name or id
end
local function itemName(id: string?): string
	local d = id and Items.defs[id]
	return d and d.name or tostring(id)
end
local function oneText(v: any, names: { [string]: string }): string
	if type(v) == "table" then
		local out = {}
		for _, x in v do
			table.insert(out, names[x] or x)
		end
		return table.concat(out, " or ")
	end
	return names[v] or tostring(v)
end
local function hh(h: number): string
	return string.format("%02d:00", h % 24)
end

function Q.describe(o: any): string
	local where = o.map and (" on " .. (mapName(o.map) or o.map)) or ""
	if o.kind == "kill" then
		local names = { scav = "scavs", watch = "Harbor Watch", pmc = "operators (PMC)", boss = "a boss", follower = "guards", any = "targets" }
		local who = (o.boss or o.label) and oneText(o.boss or o.label, Q.BOSS_NAMES) or names[o.target] or o.target
		local s = "Eliminate " .. who .. where
		if o.zone then
			s ..= " in " .. (Q.ZONE_NAMES[o.zone] or o.zone)
		end
		if o.weapon then
			s ..= " with " .. oneText(o.weapon, CLASS_NAMES)
		end
		if o.gun then
			s ..= " with a " .. oneText(o.gun, {})
		end
		if o.suppressed then
			s ..= ", suppressed"
		end
		if o.dist then
			s ..= string.format(" from %d m or more", o.dist)
		end
		if o.maxDist then
			s ..= string.format(" within %d m", o.maxDist)
		end
		if o.part then
			s ..= " with " .. oneText(o.part, PART_NAMES) .. " shots"
		end
		if o.time then
			s ..= " between " .. hh(o.time[1]) .. " and " .. hh(o.time[2])
		end
		if o.wear then
			s ..= " wearing a " .. itemName(o.wear)
		end
		if o.noArmor then
			s ..= " without body armour or a helmet"
		end
		if o.noNv then
			s ..= " without night vision"
		end
		if o.scav then
			s ..= " as a scav"
		end
		if o.raid then
			s ..= " in one raid"
		end
		return s
	elseif o.kind == "handin" then
		local d = Items.defs[o.item]
		return (d and d.kind == "quest" or o.fir == false) and "Hand over" or "Hand in (found in raid)"
	elseif o.kind == "extract" then
		return (o.scav and "Extract as a scav" or "Survive and extract") .. where .. (o.exfil and (" via exfil " .. o.exfil) or "")
	elseif o.kind == "visit" then
		return "Visit " .. (Q.ZONE_NAMES[o.zone] or o.zone) .. where .. (o.scav and " as a scav" or "")
	elseif o.kind == "plant" then
		return "Plant a " .. itemName(o.item) .. " at " .. (Q.ZONE_NAMES[o.zone] or o.zone) .. where
	elseif o.kind == "mark" then
		return "Mark " .. (Q.ZONE_NAMES[o.zone] or o.zone) .. where .. " with a " .. itemName(o.item)
	elseif o.kind == "find" then
		return "Locate and obtain the " .. itemName(o.item) .. " at " .. (Q.ZONE_NAMES[o.zone] or o.zone) .. where
	elseif o.kind == "build" then
		-- EFT: "Modify an MP-133 to comply with the given specifications" (Gunsmith - Part 1)
		return "Modify the " .. itemName(o.base) .. " to spec: " .. Q.buildText(o)
	end
	return "?"
end

-- ── gunsmith builds (EFT's Gunsmith tasks: a weapon with stated figures, handed over) ───────────────────────────────
-- The figures the weapon screen shows (the same sums as Modding.figures): ergonomics, recoil (vertical + horizontal, the
-- sum EFT's Gunsmith - Part 1 states), accuracy in MOA, weight, magazine size, magnification and what is fitted.
function Q.buildFigures(items: any, g: string): any?
	local it = items and items[g]
	local d = it and Items.defs[it.id]
	local w = d and d.weapon and (Weapons :: any)[d.weapon]
	if type(w) ~= "table" or w.class == "melee" then
		return nil
	end
	local st = WP.stats(items, g)
	local cats = {}
	WP.walk(items, g, function(_, pit)
		local p = WP.parts[pit.id]
		if p then
			cats[p.cat] = true
		end
	end)
	local mass = (d.mass or 0) + (st.mass or 0)
	local cap = d.capacity
	local mag = it.mag and items[it.mag]
	if mag then
		local md = Items.defs[mag.id]
		local ad = mag.at and Items.defs[mag.at]
		mass += (md and md.mass or 0) + (mag.a or 0) * (ad and ad.mass or 0)
		cap = md and md.capacity or cap
	end
	if st.capacity then
		cap = st.capacity -- a shotgun's tube
	end
	local rv = math.floor(w.recoilV * 100 * st.recoil + 0.5)
	local rh = math.floor(w.recoilH * 100 * st.recoil + 0.5)
	return {
		ergo = math.max(1, math.floor(w.ergo + st.ergo + 0.5)), recoilV = rv, recoilH = rh, recoil = rv + rh, moa = w.aimSpread * 60 * st.acc,
		mass = mass, cap = cap or 0, zoom = st.zoom or 0, light = st.light == true, laser = st.laser == true, suppressed = st.suppressed == true,
		sight = cats.sight == true, foregrip = cats.foregrip == true, muzzle = cats.muzzle == true, operable = st.operable == true,
		dur = it.wear or 100,
	}
end

-- does the build at g meet the objective's specification? (and the names of what it misses)
function Q.buildMatches(o: any, items: any, g: string): (boolean, { string })
	local miss = {}
	local it = items and items[g]
	local f = it and it.id == o.base and Q.buildFigures(items, g) or nil
	if not f then
		return false, { "weapon" }
	end
	local function need(ok: boolean, what: string)
		if not ok then
			table.insert(miss, what)
		end
	end
	need(f.operable, "a working build")
	need(o.dur == nil or f.dur >= o.dur, "durability")
	need(o.ergo == nil or f.ergo >= o.ergo, "ergonomics")
	need(o.recoil == nil or f.recoil <= o.recoil, "recoil")
	need(o.cap == nil or f.cap >= o.cap, "magazine")
	need(o.mass == nil or f.mass <= o.mass + 1e-6, "weight")
	need(o.moa == nil or f.moa <= o.moa + 1e-6, "accuracy")
	need(o.zoom == nil or f.zoom >= o.zoom, "magnification")
	need(not o.device or f.light or f.laser, "tactical device")
	need(not o.light or f.light, "light")
	need(not o.laser or f.laser, "laser")
	need(not o.suppressed or f.suppressed, "suppressor")
	need(not o.sight or f.sight, "sight")
	need(not o.foregrip or f.foregrip, "foregrip")
	need(not o.muzzle or f.muzzle, "muzzle device")
	return #miss == 0, miss
end

-- the specification in words, for the task screens
function Q.buildText(o: any): string
	local out = {}
	if o.ergo then
		table.insert(out, "ergonomics " .. o.ergo .. "+")
	end
	if o.recoil then
		table.insert(out, "recoil " .. o.recoil .. " or less")
	end
	if o.cap then
		table.insert(out, "magazine " .. o.cap .. "+")
	end
	if o.zoom then
		table.insert(out, o.zoom .. "x sight or more")
	end
	if o.moa then
		table.insert(out, string.format("%.1f MOA or better", o.moa))
	end
	if o.mass then
		table.insert(out, string.format("%.1f kg or less", o.mass))
	end
	if o.device then
		table.insert(out, "a tactical device")
	end
	if o.light then
		table.insert(out, "a light")
	end
	if o.laser then
		table.insert(out, "a laser")
	end
	if o.suppressed then
		table.insert(out, "a suppressor")
	end
	if o.sight then
		table.insert(out, "a sight")
	end
	if o.foregrip then
		table.insert(out, "a foregrip")
	end
	if o.muzzle then
		table.insert(out, "a muzzle device")
	end
	if o.dur then
		table.insert(out, "durability " .. o.dur .. "%+")
	end
	return table.concat(out, ", ")
end

-- ── operational tasks (EFT's dailies and weeklies) ────────────────────────────────────────────────────────────────
-- EFT: daily operational tasks from level 5, weekly ones from level 15; they kill scavs (4-25) or PMCs (2-15) with
-- modifiers (distance beyond 20-50 m for scavs or 20-100 m for PMCs, a body part, a weapon class, a map) or a boss,
-- survive and extract 1-12 times or through one exit, or find and hand over items; rewards are items and XP plus +0.01
-- standing; replacing one costs money and standing (EFT wiki Quests). A failed one is replaced when its timer runs out,
-- and a finished one waits for the timer too (NME, 0.12.12). Most give +0.01 to +0.03 standing (gameskinny.com). Fence
-- gives scav tasks (EFT: from the Intelligence Center level 1, which Relay 7 does not have; ours from level 5) for +0.01
-- to +0.04 karma (altchar.com). Ours: three dailies and one weekly from the seven, one scav task from Fence; the counts,
-- the reward formulas and the replace price are ours (EFT's figures were not found).
Q.OPS = {
	daily = { n = 3, level = 5, period = 86400, rep = 0.01, mul = 1, name = "DAILY" },
	weekly = { n = 1, level = 15, period = 604800, rep = 0.03, mul = 4, name = "WEEKLY" },
	scav = { n = 1, level = 5, period = 86400, karma = 0.02, mul = 0.8, name = "SCAV" },
}
Q.OPS_ORDER = { "daily", "weekly", "scav" }
Q.OPS_GIVERS = { "vos", "hale", "rook", "dekker", "kovac", "tilda", "bram" }
Q.REPLACE_SHARE = 0.5 -- replacing costs half the task's money (ours)
Q.REPLACE_REP = 0.01 -- and this much standing (karma for Fence's)
-- what completion tasks ask for (common and uncommon barter goods, medicine and food)
Q.OPS_ITEMS = {
	common = { "BOLTS", "DUCT_TAPE", "WIRES", "CIGARETTES", "MATCHES", "SPARK_PLUG", "LIGHTBULB", "TOOTHPASTE", "SOAP", "BLEACH",
		"POWER_BANK", "BANDAGE", "PAINKILLERS", "SPLINT", "MEDKIT_S", "WATER", "STEW", "HARDTACK" },
	uncommon = { "CAPACITOR", "BATTERY", "LOGIC_BOARD", "HDD", "RAM_STICK", "PHONE", "MED_TOOLS", "OLD_COIN", "HEMOSTAT", "MEDKIT_L",
		"SIGNAL_COIL", "CERAMIC_FUSE" },
}
-- what a weekly may pay on top (ours)
Q.OPS_REWARD_ITEMS = { "MEDKIT_L", "GREN_F7", "R17_MAG40", "KST_MAG40", "HELMET_C3", "SURGKIT", "WEAPON_KIT", "RIG_CHEST" }
Q.OPS_CLASSES = { "rifle", "smg", "shotgun", "bolt", "pistol" }
Q.OPS_PARTS = { "head", "thorax", "legs" }

-- the period number of an operational task kind at time t, and when it ends (days from midnight UTC; weeks from Monday)
function Q.periodOf(kind: string, t: number): (number, number)
	local per = Q.OPS[kind].period
	local off = (kind == "weekly") and 3 * 86400 or 0 -- 1 January 1970 was a Thursday
	local n = math.floor((t + off) / per)
	return n, (n + 1) * per - off
end

local function pick(list: { any }, rng: any): any
	return list[rng:NextInteger(1, #list)]
end

-- one operational task for a player of `level`: { k, trader, name, obj, reward }. rng: a Random; exits: { [map] = { exit
-- ids } } of the built maps (a specific exit only where it is known)
function Q.rollOp(kind: string, level: number, rng: any, exits: any?): any
	local cfg = Q.OPS[kind]
	local weekly = kind == "weekly"
	local trader = kind == "scav" and "fence" or pick(Q.OPS_GIVERS, rng)
	local o: any
	local what: string
	local r = rng:NextNumber()
	if kind == "scav" then
		-- Fence's: walk out as a scav, or settle a score with operators as one
		if r < 0.6 then
			what = "EXPLORATION"
			o = extract(rng:NextInteger(1, 2), nil, true, pick(Maps.order, rng))
		else
			what = "ELIMINATION"
			o = kill("pmc", rng:NextInteger(1, 2), { scav = true })
		end
	elseif r < 0.5 then
		what = "ELIMINATION"
		local t = rng:NextNumber()
		if weekly and t < 0.12 then
			-- a boss on its map
			local names = {}
			for label in Q.BOSS_MAP do
				table.insert(names, label)
			end
			table.sort(names)
			local label = pick(names, rng)
			o = kill("boss", 1, { boss = label, map = Q.BOSS_MAP[label] })
		else
			local pmc = t < (weekly and 0.4 or 0.25)
			local n
			if pmc then
				n = weekly and rng:NextInteger(5, 10) or rng:NextInteger(2, 4)
			else
				n = weekly and rng:NextInteger(15, 25) or (rng:NextInteger(4, 8) + math.floor(level / 15))
			end
			o = kill(pmc and "pmc" or "scav", n)
			if rng:NextNumber() < 0.35 then
				o.map = pick(Maps.order, rng)
			end
			-- EFT leaves distance off Factory-type maps
			if rng:NextNumber() < 0.25 and o.map ~= "smelter" then
				o.dist = pmc and rng:NextInteger(2, 10) * 10 or rng:NextInteger(2, 5) * 10
			end
			if rng:NextNumber() < 0.25 then
				o.part = pick(Q.OPS_PARTS, rng)
			end
			if rng:NextNumber() < 0.25 then
				o.weapon = pick(Q.OPS_CLASSES, rng)
			end
		end
	elseif r < 0.78 then
		what = "EXPLORATION"
		local map = pick(Maps.order, rng)
		o = extract(weekly and rng:NextInteger(4, 8) or rng:NextInteger(1, 3), nil, nil, map)
		local list = exits and exits[map]
		if list and #list > 0 and rng:NextNumber() < 0.25 then
			o.exfil = pick(list, rng)
			o.n = 1
		end
	else
		what = "COMPLETION"
		local unc = rng:NextNumber() < (weekly and 0.6 or 0.25)
		local id = pick(unc and Q.OPS_ITEMS.uncommon or Q.OPS_ITEMS.common, rng)
		local n = unc and rng:NextInteger(1, 2) or rng:NextInteger(2, 4)
		o = handin(id, weekly and n * 3 or n)
	end
	-- the PMC's operational tasks count in PMC raids, Fence's in scav raids (EFT: Fence's are played as a scav)
	if kind ~= "scav" and (o.kind == "kill" or o.kind == "extract") then
		o.scav = false
	end
	local mul = cfg.mul
	local reward: any = {
		money = math.floor((6000 + 1800 * level) * mul / 100) * 100,
		xp = math.floor((400 + 90 * level) * mul),
		rep = cfg.rep, karma = cfg.karma,
	}
	if weekly then
		reward.items = { { pick(Q.OPS_REWARD_ITEMS, rng), 1 } }
	end
	return { k = kind, trader = trader, name = cfg.name .. ": " .. what, obj = { o }, reward = reward }
end

-- what replacing an operational task costs: money, standing (karma for Fence's)
function Q.replaceCost(inst: any): (number, number)
	local money = (inst.reward and inst.reward.money) or 0
	return math.floor(money * Q.REPLACE_SHARE / 100) * 100, Q.REPLACE_REP
end

return Q
