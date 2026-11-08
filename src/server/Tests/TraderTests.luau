--!nonstrict
-- Trader checks for decision economy-2a, "EFT's eight, one currency" (docs/audit/2026-11-07/economy.md, decision
-- economy-2): the eight traders and their goods, barters, loyalty tables, buying and repairs (shared/TraderData.luau), the
-- tasks each now gives (shared/QuestData.luau) and old four-trader saves moving over (Economy.migrate). Run with the other
-- test modules via ZR_Dev "tests"; ctx is the server's service table. Pure checks call the shared modules; the rest use
-- stand-in profiles, never a real player's.
local Services = script.Parent.Parent:WaitForChild("Services")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local WP = require(Shared.WeaponParts)
local P = require(Shared.Progress)
local TD = require(Shared.TraderData)
local QD = require(Shared.QuestData)
local HD = require(Shared.HideoutData)
local Settle = require(Services.Settle)

local T = {}

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

function T.run(ctx)
	local passed, failed, notes = 0, 0, {}
	local function check(name, cond)
		if cond then
			passed += 1
		else
			failed += 1
			table.insert(notes, "FAIL " .. name)
		end
	end
	local function listed(bad)
		return #bad == 0 and "" or (": " .. table.concat(bad, ", "))
	end
	local EIGHT = { "vos", "hale", "fence", "rook", "dekker", "kovac", "tilda", "bram" }

	-- ── the eight traders ─────────────────────────────────────────────────────────────────────────────────────
	do
		local same = #TD.list == #EIGHT
		for i, id in EIGHT do
			same = same and TD.list[i] == id
		end
		local names, okDefs = {}, true
		for _, id in TD.list do
			local d = TD.defs[id]
			okDefs = okDefs and d ~= nil and type(d.name) == "string" and type(d.title) == "string" and type(d.markup) == "number"
				and d.buys ~= nil and type(TD.offers[id]) == "table" and type(TD.barters[id]) == "table"
			if d then
				okDefs = okDefs and not names[d.name]
				names[d.name] = true
			end
		end
		check("eight traders in EFT's order (Prapor, Therapist, Fence, Skier, Peacekeeper, Mechanic, Ragman, Jaeger), each defined once", same and okDefs)
	end

	-- ── goods and barters use real items ─────────────────────────────────────────────────────────────────────
	local sold, bartered = {}, {}
	do
		local bad = {}
		for tid, list in TD.offers do
			for i, o in list do
				local d = Items.defs[o.id]
				local pr = o.preset and WP.META.presets[o.preset]
				local ok = d ~= nil and (o.ll == 1 or o.ll == 2 or o.ll == 3 or o.ll == 4) and (o.limit or 0) >= 1
					and (o.n or 1) >= 1 and d ~= nil and (o.n or 1) <= (d.stack or 1)
					and (o.preset == nil or (pr ~= nil and pr.base == o.id)) and d.kind ~= "quest"
				if ok then
					sold[o.id] = sold[o.id] or {}
					table.insert(sold[o.id], { tid = tid, ll = o.ll, preset = o.preset })
				else
					table.insert(bad, tid .. "[" .. i .. "] " .. tostring(o.id))
				end
			end
		end
		check("every offer is a real item (presets on their base, stacks that fit), loyalty 1-4, a limit" .. listed(bad), #bad == 0)
		local badB = {}
		for tid, list in TD.barters do
			for i, bt in list do
				local ok = Items.defs[bt.id] ~= nil and (bt.ll == 1 or bt.ll == 2 or bt.ll == 3 or bt.ll == 4) and (bt.limit or 0) >= 1 and #bt.give >= 1
				for _, g in bt.give do
					ok = ok and Items.defs[g[1]] ~= nil and (g[2] or 0) >= 1
				end
				if ok then
					bartered[bt.id] = bartered[bt.id] or {}
					table.insert(bartered[bt.id], { tid = tid, ll = bt.ll, limit = bt.limit })
				else
					table.insert(badB, tid .. "[" .. i .. "] " .. tostring(bt.id))
				end
			end
		end
		check("every barter gives a real item for real items" .. listed(badB), #badB == 0)
		-- what a barter asks for can be had: found in a loot pool, bought from a trader or crafted
		local got = {}
		local okLoot, Loot = pcall(require, Services.Loot)
		if okLoot and type(Loot) == "table" and Loot.POOLS then
			for _, pool in Loot.POOLS do
				for _, e in pool do
					if type(e) == "table" and e.id then
						got[e.id] = true
					end
				end
			end
		end
		for id in sold do
			got[id] = true
		end
		for _, r in HD.recipes or {} do
			if r.get then
				got[r.get[1]] = true
			end
		end
		local missing = {}
		for _, list in TD.barters do
			for _, bt in list do
				for _, g in bt.give do
					if not got[g[1]] and not table.find(missing, g[1]) then
						table.insert(missing, g[1])
					end
				end
			end
		end
		check("every barter ingredient can be found, bought or crafted" .. listed(missing), okLoot and #missing == 0)
		-- nothing the four traders sold before the split was lost (the T-7 thermals are BRAM's barter now)
		local before = {
			"R17_RIFLE", "P9_PISTOL", "HARROW12", "SPARROW_SMG", "FIELD_KNIFE", "R17_MAG", "P9_MAG", "SPARROW_MAG", "A62_FMJ", "A9_PST", "A12_BUCK",
			"RED_DOT", "GRIP_V", "LIGHT_T", "GREN_RK5", "GREN_SMOKE", "FLARE_GREEN", "KST_RIFLE", "KST_MAG", "A76_PS", "A62_HP", "R17_MAG40",
			"SUPP_9", "BRAKE_76", "GREN_STUN", "GREN_F7", "WEAPON_KIT", "TUNDRA_BOLT", "A76L_LPS", "A62_AP", "A9_AP", "A12_SLUG", "SUPP_62",
			"SCOPE_4X", "A76_BP", "A76L_SNB", "R17_HG_MLOK", "R17_BRL_18", "SUPP_62C", "SUPP_76", "SCOPE_16", "SCOPE_8X", "SUPP_76L", "R17_MAG60",
			"NV_STRAP", "NV_BINO", "NV_GREEN", "NV_MONO", "NV_QUAD", "TH_T7", "ARMOR_C2", "ARMOR_C3", "ARMOR_C4", "ARMOR_C5", "HELMET_C2",
			"HELMET_C3", "HELMET_C4", "RIG_BELT", "RIG_CHEST", "RIG_PLATE", "BAG_SLING", "CANVAS_BAG", "BAG_PATROL", "BAG_RAID", "HEADSET_GS1",
			"HEADSET_COMM", "GLASSES_SUN", "GLASSES_RANGE", "GLASSES_BG1", "GLASSES_AF2", "SECURE_M", "BANDAGE", "SURGKIT", "MEDKIT_XL",
		}
		local lost = {}
		for _, id in before do
			if not sold[id] and not bartered[id] then
				table.insert(lost, id)
			end
		end
		local presets = {}
		for _, list in TD.offers do
			for _, o in list do
				if o.preset then
					presets[o.preset] = true
				end
			end
		end
		for pid in WP.PRESET_NAMES do
			if not presets[pid] then
				table.insert(lost, pid)
			end
		end
		check("everything the four traders sold is still sold by one of the eight, every build too" .. listed(lost), #lost == 0)
	end

	-- ── each trader in its EFT role ─────────────────────────────────────────────────────────────────────────
	do
		local function at(tid, id, ll)
			for _, e in sold[id] or {} do
				if e.tid == tid and (ll == nil or e.ll == ll) then
					return true
				end
			end
			return false
		end
		local function barterAt(tid, id, ll)
			for _, e in bartered[id] or {} do
				if e.tid == tid and (ll == nil or e.ll == ll) then
					return e
				end
			end
			return nil
		end
		check("VOS (Prapor): the Grach and the MP-133 at LL1, the AKM at LL2, all four grenades, eastern ammunition",
			at("vos", "P9_PISTOL", 1) and at("vos", "HARROW12", 1) and at("vos", "KST_RIFLE", 2) and at("vos", "GREN_RK5") and at("vos", "GREN_F7")
				and at("vos", "GREN_STUN") and at("vos", "GREN_SMOKE") and at("vos", "A76_PS") and at("vos", "A76L_SNB", 4) and not at("vos", "R17_RIFLE"))
		check("DEKKER (Peacekeeper): the M4-type R-17 and its 6.2 rounds at LL1, the MP5-type SMG at LL2, the N-15 at LL3, the GPNVG at LL4, Pouch M at LL2",
			at("dekker", "R17_RIFLE", 1) and at("dekker", "A62_FMJ", 1) and at("dekker", "SPARROW_SMG", 2) and at("dekker", "NV_GREEN", 3)
				and at("dekker", "NV_QUAD", 4) and (barterAt("dekker", "SECURE_M", 2) or {}).limit == 1)
		check("ROOK (Skier): parts and sights from LL1, the PNV-10T at LL2, the PVS-14 at LL3, smuggled western guns from LL3",
			at("rook", "RED_DOT", 1) and at("rook", "NV_BINO", 2) and at("rook", "NV_MONO", 3) and at("rook", "SPARROW_SMG", 3))
		local function presetAt(tid, pid)
			for _, o in TD.offers[tid] or {} do
				if o.preset == pid then
					return o.ll
				end
			end
			return nil
		end
		check("KOVAC (Mechanic): the R-17 builds from LL2 to LL4, compact suppressors and the 8x scope gated by loyalty",
			presetAt("kovac", "R17_PATROL") == 2 and presetAt("kovac", "R17_CQB") == 3 and presetAt("kovac", "R17_DMR") == 4
				and at("kovac", "SUPP_62C", 3) and at("kovac", "SCOPE_8X", 4))
		-- (plates are gear too since gameplay-2a: TILDA keeps a spare class 3 plate)
		local gearKinds = { armor = true, plate = true, helmet = true, rig = true, backpack = true, headwear = true, headset = true, facecover = true, eyewear = true }
		local onlyGear = true
		for _, o in TD.offers.tilda do
			onlyGear = onlyGear and gearKinds[Items.defs[o.id].kind] == true
		end
		check("TILDA (Ragman): gear only, class 2 armour at LL1 up to class 5 at LL4, no night vision",
			onlyGear and at("tilda", "ARMOR_C2", 1) and at("tilda", "ARMOR_C5", 4) and not at("tilda", "NV_BINO") and not at("tilda", "TH_T7"))
		check("BRAM (Jaeger): the hunting shotgun and knife at LL1, the bolt rifle at LL2, the T-7 thermals as his LL4 barter",
			at("bram", "HARROW12", 1) and at("bram", "FIELD_KNIFE", 1) and at("bram", "TUNDRA_BOLT", 2) and barterAt("bram", "TH_T7", 4) ~= nil and not sold.TH_T7)
		local medsOnly = true
		for _, o in TD.offers.hale do
			local k = Items.defs[o.id].kind
			medsOnly = medsOnly and (k == "med" or k == "food")
		end
		check("HALE (Therapist): medicine and food only", medsOnly)
	end

	-- ── loyalty levels (EFT 1.1.0: player level and standing, no sales) ───────────────────────────────────────
	local taskRep = {}
	for _, q in QD.list do
		local r = q.reward and q.reward.rep
		if r and r > 0 then
			taskRep[q.trader] = (taskRep[q.trader] or 0) + r
		end
	end
	do
		local bad = {}
		for _, tid in TD.list do
			if tid ~= "fence" then
				local list, eft = TD.LOYALTY[tid], TD.EFT_LL[tid]
				local ok = list ~= nil and eft ~= nil and #list == 4 and list[1].level == 1 and list[1].rep == 0 and list[1].spent == 0
				for i = 2, 4 do
					local req = list and list[i]
					ok = ok and req ~= nil and req.level == math.min(eft[i - 1][1], P.MAX_LEVEL) and req.spent == 0
						and req.level >= list[i - 1].level and req.rep >= list[i - 1].rep
				end
				if not ok then
					table.insert(bad, tid)
				end
			end
		end
		check("loyalty tables: LL1 free, EFT 1.1.0's player levels (capped at the top level), no money asked, never falling" .. listed(bad), #bad == 0)
		-- reachable: the level by the top level, the standing from that trader's own tasks, which can all be done
		local unreach = {}
		for _, tid in TD.list do
			if tid ~= "fence" then
				for ll = 2, 4 do
					local req = TD.loyaltyReq(tid, ll)
					if not req or req.level > P.MAX_LEVEL or req.rep > (taskRep[tid] or 0) + 1e-6 then
						table.insert(unreach, tid .. " LL" .. ll)
					end
				end
			end
		end
		local tasksDoable = true
		for _, q in QD.list do
			tasksDoable = tasksDoable and (q.level or 1) <= P.MAX_LEVEL
		end
		check("every LL requirement is reachable: levels by " .. P.MAX_LEVEL .. ", standing from the trader's own tasks; Fence's LL2 karma within range"
			.. listed(unreach), #unreach == 0 and tasksDoable and TD.FENCE_LL2 <= P.KARMA.max)
		local scaled = true
		for _, tid in TD.list do
			if tid ~= "fence" then
				local eft4 = TD.EFT_LL[tid][3][2]
				local want = math.floor(math.min(taskRep[tid] or 0, eft4) * 100 + 1e-6) / 100
				scaled = scaled and near(TD.loyaltyReq(tid, 4).rep, want, 1e-9)
			end
		end
		check("LL4 standing: all that a trader's tasks give while they give less than EFT's figure", scaled)
		local r2 = TD.loyaltyReq("vos", 2)
		local r4 = TD.loyaltyReq("vos", 4)
		check("loyalty needs the level and the standing together (VOS)",
			TD.loyaltyOf("vos", r2.level - 1, 9) == 1 and TD.loyaltyOf("vos", r2.level, r2.rep) == 2
				and (r2.rep == 0 or TD.loyaltyOf("vos", r2.level, r2.rep - 0.01) == 1)
				and TD.loyaltyOf("vos", P.MAX_LEVEL, taskRep.vos) == 4 and TD.loyaltyOf("vos", r4.level - 1, 9) == 3)
	end

	-- a player who finishes every task reaches LL4 with all seven by the top level, and the collector task opens
	if ctx and ctx.Economy and ctx.Quests then
		local E, Q = ctx.Economy, ctx.Quests
		local fp = Settle.newProfile()
		local fresh = true
		for _, tid in TD.list do
			fresh = fresh and E.loyalty(fp, tid) == 1
		end
		check("a new profile is at LL1 with all eight", fresh)
		fp.xp = P.xpFor(P.MAX_LEVEL)
		fp.karma = 3
		for _, q in QD.list do
			if q.id ~= "F2" then
				fp.quests[q.id] = { s = "claimed", p = {} }
				if q.reward and q.reward.rep then
					E.standing(fp, q.trader).rep += q.reward.rep
				end
			end
		end
		local top, low = true, {}
		for _, tid in TD.list do
			if tid ~= "fence" and E.loyalty(fp, tid) ~= 4 then
				top = false
				table.insert(low, tid .. "=" .. E.loyalty(fp, tid))
			end
		end
		check("every task done by the top level: LL4 with all seven traders but Fence" .. listed(low), top)
		local kappa = QD.byId.F2
		local open = kappa and Q.status(fp, kappa)
		local saved = fp.traders.kovac and fp.traders.kovac.rep
		if fp.traders.kovac then
			fp.traders.kovac.rep = 0
		end
		local lowKovac = kappa and Q.status(fp, kappa)
		if fp.traders.kovac then
			fp.traders.kovac.rep = saved
		end
		check("Pouch L task (EFT's Kappa): opens with LL4 at all seven, stays locked while one trader (KOVAC) is short",
			open == "available" and lowKovac == "locked")
	end

	-- ── prices, buying and repairs ───────────────────────────────────────────────────────────────────────────
	do
		local flat = true
		for tid, list in TD.offers do
			if tid ~= "fence" then
				for _, o in list do
					flat = flat and TD.price(tid, o, 1) == TD.price(tid, o, 4) and TD.price(tid, o, 1) > 0
				end
			end
		end
		check("a loyalty level opens goods and leaves their price alone (EFT)", flat)
		local fo = TD.offers.fence[1]
		check("Fence's prices still move with karma", fo ~= nil and TD.price("fence", fo, 1, 6) < TD.price("fence", fo, 1, -7))
		local function one(id, extra)
			local it = { id = id, n = 1 }
			for k, v in extra or {} do
				it[k] = v
			end
			return it
		end
		local chain = one("GOLD_CHAIN")
		local whoC, priceC = TD.bestBuyer(chain, 0)
		local whoK = TD.bestBuyer(one("KEY_OFFICE"), 0)
		local whoS = TD.bestBuyer(one("SCOPE_4X"), 0)
		local whoH = TD.bestBuyer(one("HARROW12", { wear = 100 }), 0)
		local whoR = TD.bestBuyer(one("R17_RIFLE", { wear = 100 }), 0)
		local whoA = TD.bestBuyer(one("ARMOR_C4"), 0)
		local whoM = TD.bestBuyer(one("MEDKIT_M"), 0)
		check("who pays most: HALE for valuables (half their value) and keys, BRAM for hunting guns and scopes, KOVAC for rifles, TILDA for armour, HALE for medicine",
			whoC == "hale" and priceC == math.floor(Items.defs.GOLD_CHAIN.value * 0.5) and whoK == "hale" and whoS == "bram" and whoH == "bram"
				and whoR == "kovac" and whoA == "tilda" and whoM == "hale")
		local knife = one("FIELD_KNIFE")
		local knifeBuyers = {}
		for _, tid in TD.list do
			if TD.sellPrice(tid, knife, 0) then
				table.insert(knifeBuyers, tid)
			end
		end
		check("only BRAM and FENCE buy knives (EFT: Jaeger and Fence)" .. listed(knifeBuyers),
			#knifeBuyers == 2 and table.find(knifeBuyers, "bram") ~= nil and table.find(knifeBuyers, "fence") ~= nil)
		check("BRAM takes no automatic rifle; DEKKER takes intelligence and armour; TILDA and HALE take no guns; KOVAC no armour",
			TD.sellPrice("bram", one("R17_RIFLE", { wear = 100 }), 0) == nil and TD.sellPrice("dekker", one("FLASH_MODULE"), 0) ~= nil
				and TD.sellPrice("dekker", one("ARMOR_C4"), 0) ~= nil and TD.sellPrice("tilda", one("R17_RIFLE", { wear = 100 }), 0) == nil
				and TD.sellPrice("hale", one("P9_PISTOL", { wear = 100 }), 0) == nil and TD.sellPrice("kovac", one("ARMOR_C4"), 0) == nil)
		local quiet = true
		for _, tid in TD.list do
			quiet = quiet and TD.sellPrice(tid, one("LEDGER"), 0) == nil and TD.sellPrice(tid, one("SECURE_M"), 0) == nil
		end
		check("no trader buys task items or secure containers", quiet)
		-- repairs: EFT's Prapor and Mechanic repair weapons, Skier weapons and armour, the Ragman nothing
		local gun = { id = "R17_RIFLE", n = 1, wear = 60 }
		local vest = { id = "ARMOR_C4", n = 1, dur = 10 }
		local glasses = { id = "GLASSES_BG1", n = 1, dur = 10 }
		check("repairs as EFT: VOS and KOVAC weapons only, ROOK weapons, armour and ballistic glasses, TILDA and the rest none",
			TD.repairQuote("vos", gun) ~= nil and TD.repairQuote("vos", vest) == nil and TD.repairQuote("kovac", gun) ~= nil and TD.repairQuote("kovac", vest) == nil
				and TD.repairQuote("rook", gun) ~= nil and TD.repairQuote("rook", vest) ~= nil and select(1, TD.repairQuote("rook", glasses)) == 15
				and TD.repairQuote("tilda", vest) == nil and TD.repairQuote("hale", gun) == nil and TD.repairQuote("dekker", gun) == nil and TD.repairQuote("bram", gun) == nil)
		local _, v1 = TD.repairQuote("vos", gun, 0, 1)
		local _, v4 = TD.repairQuote("vos", gun, 0, 4)
		local _, s1 = TD.repairQuote("rook", gun, 0, 1)
		check("repair price by loyalty level (EFT: Prapor 80 to 100 %, Skier 110 to 140 %)",
			v1 ~= nil and v4 ~= nil and s1 ~= nil and v1 < v4 and v1 < s1 and near(v4 / v1, 1 / 0.8, 0.01))
	end

	-- ── tasks ────────────────────────────────────────────────────────────────────────────────────────────────
	do
		local bad = {}
		local per = {}
		for _, q in QD.list do
			local ok = TD.defs[q.trader] ~= nil and (q.after == nil or QD.byId[q.after] ~= nil)
			for _, id in q.needs or {} do
				ok = ok and QD.byId[id] ~= nil
			end
			if not ok then
				table.insert(bad, q.id)
			end
			per[q.trader] = (per[q.trader] or 0) + 1
		end
		local none = {}
		for _, tid in TD.list do
			if (per[tid] or 0) == 0 then
				table.insert(none, tid)
			end
		end
		check("every task has a trader that exists, and its chain points at real tasks" .. listed(bad), #bad == 0)
		check("every one of the eight gives at least one task" .. listed(none), #none == 0)
		local want = {
			V1 = "vos", V2 = "vos", V3 = "vos", V4 = "vos", V6 = "vos", T7 = "vos", V5 = "kovac", V7 = "bram", T4 = "bram", T5 = "bram",
			T2 = "dekker", T3 = "rook", T1 = "tilda", T6 = "tilda", H1 = "hale", H2 = "hale", H3 = "hale", H4 = "hale", H5 = "hale", H6 = "hale",
			F1 = "fence", F2 = "fence", F3 = "fence",
		}
		local wrong = {}
		for id, tid in want do
			if not QD.byId[id] or QD.byId[id].trader ~= tid then
				table.insert(wrong, id)
			end
		end
		check("tasks sit with the trader of their EFT counterpart (Trophy and the boss hunts with Jaeger's BRAM, Fishing Gear with DEKKER, Signal with KOVAC)"
			.. listed(wrong), #wrong == 0)
		local q = QD.byId
		local chains = q.V5 and q.V5.after == "V2" and q.V7 and q.V7.after == "V3" and q.T2 and q.T2.after == "T1" and q.T3 and q.T3.after == "T2"
			and q.T4 and q.T4.after == "T3" and q.T5 and q.T5.after == "T3" and q.T7 and q.T7.after == "T3"
			and q.T4.obj[1].boss == "Foreman" and q.V7.obj[1].boss == "Broker" and q.T5.obj[1].item == "SEALED_DRIVE"
		local needs = q.F2 and q.F2.needs or {}
		check("the moved tasks kept their chains, objectives and the collector's needs",
			chains and #needs == 4 and needs[1] == "V4" and needs[2] == "H4" and needs[3] == "T4" and needs[4] == "T5")
	end

	-- ── old saves ────────────────────────────────────────────────────────────────────────────────────────────
	if ctx and ctx.Economy then
		local E = ctx.Economy
		local old = Settle.newProfile()
		old.trv = nil
		old.xp = P.xpFor(10)
		old.traders = {
			vos = { spent = 200000, rep = 0.56, llSeen = 3 }, hale = { spent = 50000, rep = 0.35, llSeen = 2 },
			tilda = { spent = 90000, rep = 0.5, llSeen = 2 }, fence = { spent = 1000, rep = 0 }, ghost = { spent = 5, rep = 1 },
		}
		for _, id in { "V1", "V2", "V3", "V4", "V5", "V6", "V7", "T1", "T2", "T3", "T4", "T5", "T6", "T7" } do
			old.quests[id] = { s = "claimed", p = {} }
		end
		local w = E.window(os.time())
		old.bought = { ["vos:12"] = { n = 1, w = w }, ["b:tilda:4"] = { n = 1, w = w } }
		local okRun, moved = pcall(E.migrate, old)
		local tr = old.traders
		local rep = function(tid)
			return tr[tid] and tr[tid].rep or 0
		end
		check("an old four-trader save migrates without an error and marks itself (trv 2)", okRun and moved == true and old.trv == E.TRADERS_V)
		check("the standing of claimed tasks moves with them (V5 to KOVAC, V7, T4, T5 to BRAM, T2 to DEKKER, T3 to ROOK, T7 to VOS)",
			near(rep("vos"), 0.56 - 0.05 - 0.1 + 0.05) and near(rep("tilda"), 0.5 - 0.07 - 0.06 - 0.12 - 0.05 - 0.12) and near(rep("kovac"), 0.05)
				and near(rep("bram"), 0.1 + 0.12 + 0.12) and near(rep("dekker"), 0.07) and near(rep("rook"), 0.06) and near(rep("hale"), 0.35))
		check("money spent stays with the trader it was spent with; this restock's purchase counts are cleared",
			tr.vos.spent == 200000 and tr.tilda.spent == 90000 and tr.hale.spent == 50000 and next(old.bought) == nil)
		local before = rep("bram")
		local again = E.migrate(old)
		check("migrating twice changes nothing", again == false and near(rep("bram"), before))
		local okState, st = pcall(E.stateFor, old)
		local all = okState and type(st) == "table" and type(st.traders) == "table"
		for _, tid in TD.list do
			all = all and st.traders[tid] ~= nil and (st.traders[tid].ll or 0) >= 1
		end
		check("the migrated save's trader screen state lists all eight with a loyalty level (an unknown old id is ignored)", all and st.traders.ghost == nil)
		-- a level 1 save with nothing done: every new trader starts at LL1; a save missing its tables loads too
		local bare = Settle.newProfile()
		bare.trv, bare.traders, bare.bought, bare.quests = nil, nil, nil, nil
		local okBare = pcall(E.migrate, bare)
		local lls = okBare and type(bare.traders) == "table" and type(bare.quests) == "table"
		for _, tid in TD.list do
			lls = lls and E.loyalty(bare, tid) == 1
		end
		check("a save with no trader, purchase or task tables loads, and every trader starts at LL1", lls)
	end

	-- ── the relay radio window lists every trader ─────────────────────────────────────────────────────────────
	do
		local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
		local client = sps and sps:FindFirstChild("ZRClient")
		local controllers = client and client:FindFirstChild("Controllers")
		local mod = controllers and controllers:FindFirstChild("Trade")
		local okT, Trade = false, nil
		if mod then
			okT, Trade = pcall(require, mod)
		end
		local tabs = okT and type(Trade) == "table" and Trade.RADIO_TABS
		local ok = type(tabs) == "table" and #tabs == #TD.list + 3
		for i, id in TD.list do
			ok = ok and tabs[i] == id
		end
		ok = ok and tabs[#TD.list + 1] == "flea" and tabs[#TD.list + 2] == "messenger" and tabs[#TD.list + 3] == "handbook"
		check("the relay radio has a tab for each of the eight, then flea market, messenger and handbook", ok)
	end

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T
