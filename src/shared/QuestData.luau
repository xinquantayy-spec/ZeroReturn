--!strict
-- Trader tasks (original, Tarkov-style). Objective types:
--   kill    { target = "scav" | "watch" | "pmc" | "boss" | "any", n, boss? }  (raid kills by this player; boss = one boss
--                                                                           by the AI's Label attribute, audit economy.9)
--   handin  { item, n }                                                    (found-in-raid items, handed in at turn-in)
--   extract { n, exfil?, scav?, map? }                                     (survive and extract; optionally via an exfil,
--                                                                           as a scav or on one map)
--   visit   { zone, map?, scav? }                                          (reach a place during a raid: the zone of that
--                                                                           name in the raid's map, World.maps[id].visitZones)
-- Unlocking: level, after (the task before it); optionally needs { ids } (more tasks to have finished), karma (the
-- Fence standing it needs) and ll (the loyalty level it needs with every trader but Fence; audit economy.7).
-- Rewards: money, xp, rep (trader standing), karma, items { { id, n } }.
local Maps = require(script.Parent.Maps)

local Q = {}

local function kill(target: string, n: number, boss: string?): any
	return { kind = "kill", target = target, n = n, boss = boss }
end
local function handin(item: string, n: number): any
	return { kind = "handin", item = item, n = n }
end
local function extract(n: number, exfil: string?, scav: boolean?, map: string?): any
	return { kind = "extract", n = n, exfil = exfil, scav = scav, map = map }
end
local function visit(zone: string, map: string?, scav: boolean?): any
	return { kind = "visit", zone = zone, n = 1, map = map, scav = scav }
end

Q.list = {
	-- VOS
	{ id = "V1", trader = "vos", name = "Signal Check", level = 1, after = nil,
		desc = "Scavs keep cutting the relay cables. Thin them out.",
		obj = { kill("scav", 5) }, reward = { money = 15000, xp = 500, rep = 0.05, items = { { "R17_MAG40", 1 } } } },
	{ id = "V2", trader = "vos", name = "Range Day", level = 2, after = "V1",
		desc = "The Harbor Watch think the quay is theirs. Show them otherwise.",
		obj = { kill("watch", 3) }, reward = { money = 30000, xp = 1200, rep = 0.07 } },
	{ id = "V3", trader = "vos", name = "Iron Discipline", level = 5, after = "V2",
		desc = "Other operators are stripping our caches. Find them first.",
		obj = { kill("pmc", 2) }, reward = { money = 60000, xp = 2500, rep = 0.1, items = { { "SUPP_62", 1 } } } },
	{ id = "V4", trader = "vos", name = "The Foreman's Ledger", level = 8, after = "V3",
		desc = "The Foreman keeps a ledger of every crate that left the harbour. Bring it to me.",
		obj = { handin("LEDGER", 1) }, reward = { money = 250000, xp = 6000, rep = 0.15 } },
	-- tasks on the new maps' places (audit economy.9), in EFT's patterns: reach and survey places, then get out
	{ id = "V5", trader = "vos", name = "High Ground", level = 5, after = "V2",
		desc = "Two places on Border Yard see the whole crossing: the top of the derrick and the top of the frame. Climb both and tell me who has been up there.",
		obj = { visit("DERRICK", "border"), visit("FRAME", "border") }, reward = { money = 35000, xp = 1600, rep = 0.05 } },
	{ id = "V6", trader = "vos", name = "Slag Run", level = 3, after = "V1",
		desc = "Someone keeps a lookout on the slag stack in the smelter's north yard. Go and look, then get out of there alive.",
		obj = { visit("STACK", "smelter"), extract(1, nil, nil, "smelter") }, reward = { money = 20000, xp = 900, rep = 0.04 } },
	-- the second boss task with its own target (audit economy.9), after EFT's "The Huntsman Path - Trophy" (Jaeger: locate
	-- and neutralize Reshala, +3,000 XP, +0.10 standing, no money; tarkovforge.com/task-guide). EFT also wants his golden
	-- TT handed in; the Broker carries no unique item yet.
	{ id = "V7", trader = "vos", name = "Dealer's Due", level = 10, after = "V3",
		desc = "The Broker sells our crates back to us out of the Border Yard dorms. He has bodyguards. Settle it.",
		obj = { kill("boss", 1, "Broker") }, reward = { xp = 3000, rep = 0.1 } },
	-- HALE
	{ id = "H1", trader = "hale", name = "First Aid", level = 1, after = nil,
		desc = "My shelves are empty. Bring dressings and a kit you found out there.",
		obj = { handin("BANDAGE", 2), handin("MEDKIT_S", 1) }, reward = { money = 12000, xp = 400, rep = 0.05, items = { { "MEDKIT_M", 1 } } } },
	{ id = "H2", trader = "hale", name = "Supply Run", level = 2, after = "H1",
		desc = "Go in, come back. Twice. I need to know the routes still work.",
		obj = { extract(2) }, reward = { money = 20000, xp = 800, rep = 0.06 } },
	{ id = "H3", trader = "hale", name = "Cold Chain", level = 3, after = "H2",
		desc = "Clean water and food for the relay crew.",
		obj = { handin("WATER", 2), handin("STEW", 2) }, reward = { money = 25000, xp = 900, rep = 0.06, items = { { "HEMOSTAT", 1 } } } },
	{ id = "H4", trader = "hale", name = "Field Surgeon", level = 6, after = "H3",
		desc = "Someone left surgical tools in a locker on the quay. I want them.",
		obj = { handin("MED_TOOLS", 1) }, reward = { money = 40000, xp = 1500, rep = 0.08, items = { { "SURGKIT", 1 } } } },
	-- after EFT's "Operation Aquarius" (Therapist: locate the hidden water stash on Customs), on Border Yard's boiler house
	{ id = "H5", trader = "hale", name = "Cellar Stock", level = 4, after = "H2",
		desc = "The crossing's last medic hid supplies in the boiler house cellar on Border Yard. Find the cellar and come back to tell me it is still dry.",
		obj = { visit("BOILER", "border"), extract(1, nil, nil, "border") }, reward = { money = 25000, xp = 1100, rep = 0.05, items = { { "MEDKIT_M", 1 } } } },
	{ id = "H6", trader = "hale", name = "Outside the Mall", level = 6, after = "H3",
		desc = "Two camps stand outside Meridian Mall: the rescue camp and the west camp. Check both for survivors, then come home.",
		obj = { visit("RESCUE_CAMP", "meridian"), visit("WEST_CAMP", "meridian"), extract(1, nil, nil, "meridian") },
		reward = { money = 30000, xp = 1300, rep = 0.05 } },
	-- TILDA
	{ id = "T1", trader = "tilda", name = "Dress Code", level = 1, after = nil,
		desc = "Cigarettes and matches buy thread around here. Bring me some.",
		obj = { handin("CIGARETTES", 2), handin("MATCHES", 2) }, reward = { money = 10000, xp = 300, rep = 0.05, items = { { "BAG_SLING", 1 } } } },
	{ id = "T2", trader = "tilda", name = "Tide Marks", level = 2, after = "T1",
		desc = "Check that the pier boat and the relay tower are still standing.",
		obj = { visit("PIER3", "quay7"), visit("RELAY", "quay7") }, reward = { money = 30000, xp = 1000, rep = 0.07 } },
	{ id = "T3", trader = "tilda", name = "Dead Drop", level = 3, after = "T2",
		desc = "Use the rail cut. If it's clear, my couriers will too.",
		obj = { extract(1, "C", nil, "quay7") }, reward = { money = 25000, xp = 900, rep = 0.06 } },
	-- the Foreman by name: any boss used to count (audit economy.9)
	{ id = "T4", trader = "tilda", name = "Heavy Plate", level = 7, after = "T3",
		desc = "The Foreman wears the best plate on the quay. Take it off him.",
		obj = { kill("boss", 1, "Foreman") }, reward = { money = 120000, xp = 4000, rep = 0.12, items = { { "ARMOR_C4", 1 } } } },
	-- after EFT's "Big Sale" (Ragman: visit five Interchange stores and extract; 8,200 XP, +0.03, 30,000 roubles and a
	-- backpack; sportskeeda.com), in Meridian Mall
	{ id = "T6", trader = "tilda", name = "Window Shopping", level = 8, after = "T2",
		desc = "I want to know what is left in Meridian Mall. Walk the concourse, look into IRONSIGHT and the kart track, then get out with your eyes intact.",
		obj = { visit("CONCOURSE", "meridian"), visit("IRONSIGHT", "meridian"), visit("KART_TRACK", "meridian"), extract(1, nil, nil, "meridian") },
		reward = { money = 30000, xp = 3000, rep = 0.03, items = { { "CANVAS_BAG", 1 } } } },
	-- Customs' marked room 314 in the three-storey dorm is Border Yard's block A room 314 (its key: KEY_BY_314)
	{ id = "T7", trader = "tilda", name = "Room 314", level = 6, after = "T3",
		desc = "Block A, room 314, on Border Yard. People pay well to know what is behind that door. Go and see for yourself.",
		obj = { visit("DORM314", "border") }, reward = { money = 40000, xp = 1500, rep = 0.05 } },
	-- the Sealed Drive had no use (audit economy.8): Tilda wants what is on it, like Tarkov's data-carrier tasks
	{ id = "T5", trader = "tilda", name = "Sealed Records", level = 9, after = "T3",
		desc = "The evacuation office kept its records on sealed drives. Find two and bring them to me unopened.",
		obj = { handin("SEALED_DRIVE", 2) }, reward = { money = 180000, xp = 5000, rep = 0.12 } },
	-- FENCE
	{ id = "F1", trader = "fence", name = "Local Rules", level = 1, after = nil,
		desc = "Go in as one of the locals and come back. Twice. Don't make enemies.",
		obj = { extract(2, nil, true) }, reward = { money = 10000, xp = 400, karma = 0.5 } },
	-- a scav errand on Border Yard; EFT's Fence assignments pay +0.01 to +0.05 standing (escapefromtarkov.party karma guide)
	{ id = "F3", trader = "fence", name = "Smugglers' Way", level = 1, after = "F1",
		desc = "As a local, find the smugglers' hole on Border Yard and walk out the way you came. Nobody sees you, nobody gets hurt.",
		obj = { visit("SMUGGLERS", "border", true), extract(1, nil, true, "border") }, reward = { money = 15000, xp = 600, karma = 0.05 } },
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

-- visit zones are defined per map (World on Quay 7, src/server/Maps/* on the others: position + radius); names for the UI
Q.ZONE_NAMES = {
	PIER3 = "Pier 3 boat", RELAY = "Relay tower",
	DORM314 = "block A room 314", BOILER = "the boiler house cellar", DERRICK = "the top of the derrick", FRAME = "the top of the frame",
	SMUGGLERS = "the smugglers' hole",
	SUBSTATION = "the substation switch", SHELTER = "the shelter", IRONSIGHT = "the IRONSIGHT gun shop", CONCOURSE = "the concourse",
	WEST_CAMP = "the west camp", RESCUE_CAMP = "the rescue camp", KART_TRACK = "the kart track",
	STACK = "the slag stack",
}
-- the bosses a kill objective can name (the AI's Label attribute, set from each map's boss definition)
Q.BOSS_NAMES = {
	Foreman = "the Foreman", Broker = "the Broker", Halberd = "Halberd of the Hounds", Priest = "the cult's priest", Forester = "the Forester",
	Caretaker = "the Caretaker", Stoker = "the Stoker",
}

local function mapName(id: string?): string?
	local d = id and (Maps.defs[id] or (Maps.parked :: any)[id])
	return d and d.name or id
end

function Q.describe(o: any): string
	local where = o.map and (" on " .. (mapName(o.map) or o.map)) or ""
	if o.kind == "kill" then
		local names = { scav = "scavs", watch = "Harbor Watch", pmc = "operators (PMC)", boss = "a boss", any = "targets" }
		return string.format("Eliminate %s", o.boss and (Q.BOSS_NAMES[o.boss] or o.boss) or names[o.target] or o.target)
	elseif o.kind == "handin" then
		return "Hand in (found in raid)"
	elseif o.kind == "extract" then
		return (o.scav and "Extract as a scav" or "Survive and extract") .. where .. (o.exfil and (" via exfil " .. o.exfil) or "")
	elseif o.kind == "visit" then
		return "Visit " .. (Q.ZONE_NAMES[o.zone] or o.zone) .. where .. (o.scav and " as a scav" or "")
	end
	return "?"
end

return Q
