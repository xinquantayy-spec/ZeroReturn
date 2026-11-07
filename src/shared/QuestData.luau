--!strict
-- Trader tasks (original, Tarkov-style). Objective types:
--   kill    { target = "scav" | "watch" | "pmc" | "boss" | "any", n }      (raid kills by this player)
--   handin  { item, n }                                                    (found-in-raid items, handed in at turn-in)
--   extract { n, exfil? , scav? }                                          (survive and extract; optionally via an exfil)
--   visit   { zone }                                                       (reach a place during a raid; World.visitZones)
-- Unlocking: level, after (the task before it); optionally needs { ids } (more tasks to have finished), karma (the
-- Fence standing it needs) and ll (the loyalty level it needs with every trader but Fence; audit economy.7).
-- Rewards: money, xp, rep (trader standing), karma, items { { id, n } }.
local Q = {}

local function kill(target: string, n: number): any
	return { kind = "kill", target = target, n = n }
end
local function handin(item: string, n: number): any
	return { kind = "handin", item = item, n = n }
end
local function extract(n: number, exfil: string?, scav: boolean?): any
	return { kind = "extract", n = n, exfil = exfil, scav = scav }
end
local function visit(zone: string): any
	return { kind = "visit", zone = zone, n = 1 }
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
	-- TILDA
	{ id = "T1", trader = "tilda", name = "Dress Code", level = 1, after = nil,
		desc = "Cigarettes and matches buy thread around here. Bring me some.",
		obj = { handin("CIGARETTES", 2), handin("MATCHES", 2) }, reward = { money = 10000, xp = 300, rep = 0.05, items = { { "BAG_SLING", 1 } } } },
	{ id = "T2", trader = "tilda", name = "Tide Marks", level = 2, after = "T1",
		desc = "Check that the pier boat and the relay tower are still standing.",
		obj = { visit("PIER3"), visit("RELAY") }, reward = { money = 30000, xp = 1000, rep = 0.07 } },
	{ id = "T3", trader = "tilda", name = "Dead Drop", level = 3, after = "T2",
		desc = "Use the rail cut. If it's clear, my couriers will too.",
		obj = { extract(1, "C") }, reward = { money = 25000, xp = 900, rep = 0.06 } },
	{ id = "T4", trader = "tilda", name = "Heavy Plate", level = 7, after = "T3",
		desc = "The Foreman wears the best plate on the quay. Take it off him.",
		obj = { kill("boss", 1) }, reward = { money = 120000, xp = 4000, rep = 0.12, items = { { "ARMOR_C4", 1 } } } },
	-- the Sealed Drive had no use (audit economy.8): Tilda wants what is on it, like Tarkov's data-carrier tasks
	{ id = "T5", trader = "tilda", name = "Sealed Records", level = 9, after = "T3",
		desc = "The evacuation office kept its records on sealed drives. Find two and bring them to me unopened.",
		obj = { handin("SEALED_DRIVE", 2) }, reward = { money = 180000, xp = 5000, rep = 0.12 } },
	-- FENCE
	{ id = "F1", trader = "fence", name = "Local Rules", level = 1, after = nil,
		desc = "Go in as one of the locals and come back. Twice. Don't make enemies.",
		obj = { extract(2, nil, true) }, reward = { money = 10000, xp = 400, karma = 0.5 } },
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

-- visit zones are defined in World (position + radius); names for the UI
Q.ZONE_NAMES = { PIER3 = "Pier 3 boat", RELAY = "Relay tower" }

function Q.describe(o: any): string
	if o.kind == "kill" then
		local names = { scav = "scavs", watch = "Harbor Watch", pmc = "operators (PMC)", boss = "the Foreman", any = "targets" }
		return string.format("Eliminate %s", names[o.target] or o.target)
	elseif o.kind == "handin" then
		return "Hand in (found in raid)"
	elseif o.kind == "extract" then
		return (o.scav and "Extract as a scav" or "Survive and extract") .. (o.exfil and (" via exfil " .. o.exfil) or "")
	elseif o.kind == "visit" then
		return "Visit " .. (Q.ZONE_NAMES[o.zone] or o.zone)
	end
	return "?"
end

return Q
