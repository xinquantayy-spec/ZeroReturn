--!nonstrict
-- Economy regression checks for the audit's quick wins (docs/audit/2026-11-07/economy.md): the flea market's category
-- gates and ban list (economy.3), Fence's loyalty and prices from karma (economy.5). Run with the other test modules
-- via ZR_Dev "tests"; ctx is the server's service table. Most checks call the shared modules' pure functions; the rest
-- use stand-in profiles, never a real player's.
local Services = script.Parent.Parent:WaitForChild("Services")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local FR = require(Shared.FleaRules)
local P = require(Shared.Progress)
local TD = require(Shared.TraderData)
local Settle = require(Services.Settle)

local T = {}

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

	-- economy.3: EFT's flea ban list (top armour, helmets, thermals, raid pack, top AP rounds, red flare, tags, amulet,
	-- the "bitcoin") and EFT 1.0's category gates (20 bolt-action, foregrips, muzzle devices; 25 assault rifles,
	-- backpacks, lights and lasers; 30 barter items, gear components, injectors, keycards; M80 at 35)
	do
		local known = true
		for id in FR.BANNED_ITEMS do
			known = known and Items.defs[id] ~= nil and not FR.tradeable(id)
		end
		check("flea ban list: every banned id is a real item and cannot be traded", known)
		local topArmour, topHelmets = true, true
		for id, d in Items.defs do
			if d.kind == "armor" and d.armor and d.armor.class >= 5 then
				topArmour = topArmour and not FR.tradeable(id)
			elseif d.kind == "helmet" and d.armor and d.armor.class >= 4 then
				topHelmets = topHelmets and not FR.tradeable(id)
			end
		end
		check("flea: no class 5-6 body armour and no class 4-5 helmet on the market (EFT's ban list)", topArmour and topHelmets)
		check("flea: thermals, the panoramic goggles, the raid pack and the welding mask are banned",
			not FR.tradeable("TH_T7") and not FR.tradeable("NV_QUAD") and not FR.tradeable("BAG_RAID") and not FR.tradeable("MASK_WELDER"))
		check("flea: the top AP round of each calibre is banned, the common rounds are not",
			not FR.tradeable("A62_AP") and not FR.tradeable("A76_BP") and not FR.tradeable("A76L_SNB") and not FR.tradeable("A9_AP")
				and FR.tradeable("A62_FMJ") and FR.tradeable("A76_PS") and FR.tradeable("A9_PST") and FR.tradeable("A12_SLUG"))
		check("flea: the red (airdrop) flare is banned, the green (exit) flare is not",
			not FR.tradeable("FLARE_RED") and FR.tradeable("FLARE_GREEN"))
		check("flea: class 2-4 armour, class 2-3 helmets and secure containers keep their old status",
			FR.tradeable("ARMOR_C4") and FR.tradeable("RIG_PLATE") and FR.tradeable("HELMET_C3") and not FR.tradeable("SECURE_S") and not FR.tradeable("SEALED_DRIVE"))
		local gates = {
			TUNDRA_BOLT = 20, GRIP_V = 20, SUPP_62 = 20, R17_BRK = 20,
			R17_RIFLE = 25, KST_RIFLE = 25, BAG_PATROL = 25, CANVAS_BAG = 25, LIGHT_T = 25, LASER_DOT = 25,
			BOLTS = 30, GPU_CARD = 30, WEAPON_KIT = 30, NV_BINO = 30, ANTIDOTE = 30, RUSTED_KEYCARD = 30, KEY_MM_UNIT14 = 30,
			A76L_LPS = 35,
			SPARROW_SMG = 15, HARROW12 = 15, P9_PISTOL = 15, FIELD_KNIFE = 15, KEY_OFFICE = 15, A62_FMJ = 15, BANDAGE = 15,
			ARMOR_C3 = 15, HELMET_C2 = 15, RIG_CHEST = 15, SCOPE_4X = 15, R17_MAG = 15, GREN_RK5 = 15, FLARE_GREEN = 15,
		}
		local bad = {}
		for id, lvl in gates do
			if FR.levelFor(id) ~= lvl then
				table.insert(bad, id .. "=" .. tostring(FR.levelFor(id)))
			end
		end
		check("flea gates by category (EFT 1.0): " .. (#bad == 0 and "all as expected" or table.concat(bad, ", ")), #bad == 0)
		local reachable = true
		for id in Items.defs do
			if FR.tradeable(id) and FR.levelFor(id) > P.MAX_LEVEL then
				reachable = false
			end
		end
		check("flea: every tradeable item can be bought by the top level", reachable)
		local okLow, whyLow = FR.canBuy("R17_RIFLE", 24)
		local okBan, whyBan = FR.canBuy("ARMOR_C6", P.MAX_LEVEL)
		check("flea: an assault rifle needs level 25, banned armour never sells",
			okLow == false and whyLow == "LOCKED" and FR.canBuy("R17_RIFLE", 25) == true and okBan == false and whyBan == "BANNED"
				and FR.canBuy("SPARROW_SMG", FR.LEVEL) == true)
		if ctx and ctx.Flea then
			local m = ctx.Flea.market({ known = { ARMOR_C6 = true, TH_T7 = true } })
			check("flea market: banned items are left out, gated ones are listed (greyed out on the client)",
				m.offers.ARMOR_C6 == nil and m.offers.TH_T7 == nil and m.offers.R17_RIFLE ~= nil and #m.offers.R17_RIFLE > 0)
		end
	end

	-- economy.5: Fence's LL from karma (EFT: LL2 at a standing of 6.0) and EFT's PriceModifier on his goods both ways
	do
		check("karma runs over EFT's Fence standing range, -7 to 6, from 0.2", P.KARMA.min == -7 and P.KARMA.max == 6 and P.KARMA.start == 0.2)
		check("fence loyalty: LL1 below 6.0 (also when negative), LL2 from 6.0 (a float just under 6 counts as 6.00)",
			TD.fenceLoyalty(P.KARMA.start) == 1 and TD.fenceLoyalty(-7) == 1 and TD.fenceLoyalty(5.98) == 1
				and TD.fenceLoyalty(6) == 2 and TD.fenceLoyalty(6 - 1e-9) == 2 and TD.fenceLoyalty(nil) == 1)
		check("fence price modifier: EFT's table by whole point of standing, rounded down and clamped to -7..6",
			TD.fencePriceMul(-7) == 1.2 and TD.fencePriceMul(-10) == 1.2 and TD.fencePriceMul(-0.5) == 1.05 and TD.fencePriceMul(0.2) == 1
				and TD.fencePriceMul(2.99) == 0.95 and TD.fencePriceMul(5) == 0.85 and TD.fencePriceMul(6) == 0.8 and TD.fencePriceMul(9) == 0.8)
		local ll2 = nil
		for _, o in TD.offers.fence do
			if o.ll == 2 then
				ll2 = o
			end
		end
		local bandage = TD.offers.fence[3]
		local base = Items.defs[bandage.id].value * bandage.n * TD.defs.fence.markup
		check("fence prices move with karma both ways (dearer when it is low, cheaper when high)",
			bandage.id == "BANDAGE" and TD.price("fence", bandage, 1, -7) > TD.price("fence", bandage, 1, 0.2)
				and TD.price("fence", bandage, 1, 0.2) > TD.price("fence", bandage, 1, 6)
				and TD.price("fence", bandage, 1, 6) == math.ceil(base * 0.8) and TD.price("fence", bandage, 1, nil) == math.ceil(base))
		local rifle = TD.offers.vos[1]
		check("karma leaves the other traders' prices alone", TD.price("vos", rifle, 1, -7) == TD.price("vos", rifle, 1, 6) and TD.price("vos", rifle, 1, 6) == TD.price("vos", rifle, 1))
		if ctx and ctx.Economy then
			local fp = Settle.newProfile()
			fp.karma = 5.5
			local llLow = ctx.Economy.loyalty(fp, "fence")
			fp.karma = 6
			local llTop = ctx.Economy.loyalty(fp, "fence")
			fp.xp = 0
			local st = ctx.Economy.stateFor(fp)
			local mailed = 0
			for _, m in fp.msgs or {} do
				if m.f == "fence" then
					mailed += 1
				end
			end
			ctx.Economy.stateFor(fp)
			local mailedAgain = 0
			for _, m in fp.msgs or {} do
				if m.f == "fence" then
					mailedAgain += 1
				end
			end
			check("fence LL2 at karma 6 for a level 1 player with no trades: his LL2 offer opens and he writes once",
				ll2 ~= nil and llLow == 1 and llTop == 2 and st.traders.fence.ll == 2 and ll2.ll <= st.traders.fence.ll and mailed == 1 and mailedAgain == 1)
		end
	end

	-- economy.7: Pouch M from TILDA's LL2 barter (EFT's Beta), Pouch L from FENCE's collector task (EFT's Kappa); weapon
	-- parts, grenades and eyewear (and goggles, headsets) go into secure containers, guns and armour still do not
	do
		local K = Items.SECURE_KINDS
		check("secure containers take weapon parts, goggles, grenades, eyewear and headsets",
			K.mod == true and K.nvg == true and K.grenade == true and K.eyewear == true and K.headset == true and K.ammo == true and K.key == true)
		check("secure containers still refuse guns, armour, helmets, rigs, packs and other secure containers",
			not K.weapon and not K.pistol and not K.armor and not K.helmet and not K.rig and not K.backpack and not K.secure)
		local sp = Settle.newProfile()
		local Inv = require(Services.Inv)
		local function enters(id)
			local g, it = Inv.newItem(id, 1)
			Inv.place(sp, g, it, { "stash" })
			local ok, why = Inv.canEnter(sp, g, sp.slots.secure)
			Inv.take(sp, g)
			return ok, why
		end
		local _, whyRifle = enters("R17_RIFLE")
		check("Inv: a sight, a grenade and glasses enter Pouch S; a rifle is refused",
			enters("RED_DOT") == true and enters("GREN_RK5") == true and enters("GLASSES_BG1") == true and enters("SUPP_62") == true
				and whyRifle == "SECURE_RESTRICTED")
		local beta = nil
		for _, bt in TD.barters.tilda do
			if bt.id == "SECURE_M" then
				beta = bt
			end
		end
		local okGive = beta ~= nil
		for _, need in (beta and beta.give) or {} do
			okGive = okGive and Items.defs[need[1]] ~= nil and need[2] >= 1
		end
		check("Pouch M: TILDA's barter at loyalty 2, one a restock, for real items", beta ~= nil and beta.ll == 2 and beta.limit == 1 and okGive)
		local QD = require(Shared.QuestData)
		local kappa = QD.byId.F2
		local rewardL = false
		for _, e in (kappa and kappa.reward.items) or {} do
			rewardL = rewardL or e[1] == "SECURE_L"
		end
		check("Pouch L: FENCE's collector task pays the pouch alone (EFT: no money or XP), level 40, karma 3, LL4, the chains' last tasks",
			kappa ~= nil and kappa.trader == "fence" and rewardL and (kappa.reward.money or 0) == 0 and (kappa.reward.xp or 0) == 0
				and kappa.level == 40 and kappa.karma == 3 and kappa.ll == 4 and #kappa.needs == 4)
		local handOk = kappa ~= nil and #kappa.obj >= 10
		for _, o in (kappa and kappa.obj) or {} do
			handOk = handOk and o.kind == "handin" and o.n == 1 and Items.defs[o.item] ~= nil and Items.defs[o.item].kind == "loot"
		end
		check("Pouch L: ten or more valuables, one each, found in raid", handOk)
		if ctx and ctx.Quests and ctx.Economy and kappa then
			local qp = Settle.newProfile()
			local before = ctx.Quests.status(qp, kappa)
			qp.xp = P.xpFor(40)
			for _, id in { "F1", "V4", "H4", "T4", "T5" } do
				qp.quests[id] = { s = "claimed", p = {} }
			end
			qp.karma = 3
			local top = TD.LL[4]
			for _, tid in { "vos", "hale", "tilda" } do
				qp.traders[tid] = { spent = top.spent, rep = top.rep }
			end
			local open = ctx.Quests.status(qp, kappa)
			qp.karma = 2.9
			local lowKarma = ctx.Quests.status(qp, kappa)
			qp.karma = 3
			qp.traders.hale.spent = 0
			local lowLL = ctx.Quests.status(qp, kappa)
			qp.traders.hale.spent = top.spent
			qp.quests.T5 = nil
			local lowTasks = ctx.Quests.status(qp, kappa)
			check("Pouch L task: locked until level 40, karma 3.0, LL4 with VOS, HALE and TILDA and the four chains are done",
				before == "locked" and open == "available" and lowKarma == "locked" and lowLL == "locked" and lowTasks == "locked")
		end
	end

	-- economy.9: tasks on the visit zones of Border Yard, Meridian Mall and the Smelter, each on its own map; the two boss
	-- tasks name their boss (the Foreman, the Broker), so another boss's kill no longer counts
	do
		local QD = require(Shared.QuestData)
		local Maps = require(Shared.Maps)
		local perMap, namesOk, mapsOk, bossTasks, anyBoss = {}, true, true, {}, false
		for _, q in QD.list do
			for _, o in q.obj do
				if o.kind == "visit" then
					namesOk = namesOk and QD.ZONE_NAMES[o.zone] ~= nil
					mapsOk = mapsOk and o.map ~= nil and Maps.defs[o.map] ~= nil
					if o.map then
						perMap[o.map] = (perMap[o.map] or 0) + 1
					end
				elseif o.kind == "extract" and o.map then
					mapsOk = mapsOk and Maps.defs[o.map] ~= nil
				elseif o.kind == "kill" and o.target == "boss" then
					if o.boss then
						bossTasks[o.boss] = q.id
					else
						anyBoss = true
					end
				end
			end
		end
		check("tasks visit places on Border Yard, Meridian Mall and the Smelter, every zone named for the UI and tied to a map",
			(perMap.border or 0) >= 4 and (perMap.meridian or 0) >= 3 and (perMap.smelter or 0) >= 1 and namesOk and mapsOk)
		check("the two boss tasks name their boss: Heavy Plate the Foreman, Dealer's Due the Broker; none takes any boss",
			bossTasks.Foreman == "T4" and bossTasks.Broker == "V7" and not anyBoss and QD.BOSS_NAMES.Foreman ~= nil and QD.BOSS_NAMES.Broker ~= nil)
		check("task text names the boss and the map", QD.describe(QD.byId.T4.obj[1]) == "Eliminate the Foreman"
			and string.find(QD.describe(QD.byId.V5.obj[1]), "BORDER YARD", 1, true) ~= nil)
		if ctx and ctx.Quests and ctx.World then
			local Q = ctx.Quests
			local foreman = QD.byId.T4.obj[1]
			check("a named boss counts only for itself; a follower or another boss does not",
				Q.killMatches(foreman, "boss", "Foreman") and not Q.killMatches(foreman, "boss", "Caretaker") and not Q.killMatches(foreman, "follower", "Foreman")
					and not Q.killMatches(foreman, "boss", nil) and Q.killMatches({ kind = "kill", target = "boss", n = 1 }, "boss", "Halberd"))
			local exM = QD.byId.T6.obj[4]
			check("an extract objective with a map counts on that map only",
				Q.extractMatches(exM, { scav = false }, "meridian") and not Q.extractMatches(exM, { scav = false }, "border")
					and Q.extractMatches(QD.byId.F3.obj[2], { scav = true }, "border") and not Q.extractMatches(QD.byId.F3.obj[2], { scav = false }, "border"))
			-- the zones themselves exist where those maps are built (a lean server builds only some, tech-4b)
			local missing, seen = {}, 0
			for _, q in QD.list do
				for _, o in q.obj do
					local m = o.kind == "visit" and o.map and ctx.World.maps and ctx.World.maps[o.map]
					if m then
						seen += 1
						if not (m.visitZones and m.visitZones[o.zone]) or Q.zoneFor(o, { scav = o.scav == true }, o.map) == nil then
							table.insert(missing, o.map .. ":" .. o.zone)
						end
					end
				end
			end
			check("every task zone exists in its built map (" .. seen .. " checked)" .. (#missing > 0 and (": missing " .. table.concat(missing, ", ")) or ""), #missing == 0)
			local derrick = QD.byId.V5.obj[1]
			check("a zone counts only in its own map and, for a scav errand, only as a scav",
				Q.zoneFor(derrick, {}, "meridian") == nil and Q.zoneFor(QD.byId.F3.obj[1], { scav = false }, "border") == nil)
			-- the named bosses are bosses of the built maps (their Label: b.label, the Foreman by default)
			local labels, built = {}, {}
			for id, m in ctx.World.maps or {} do
				built[id] = true
				for _, b in m.bosses or (m.boss and { m.boss }) or {} do
					labels[b.label or "Foreman"] = true
				end
			end
			check("the Foreman and the Broker are bosses on the maps that are built",
				(not built.quay7 or labels.Foreman == true) and (not built.border or labels.Broker == true))
		end
	end

	-- economy.11: flares in the handbook and the flea categories (EFT files the RSP-30 under special equipment); the
	-- client's category table is read from the synced client module, which needs nothing client-only to load
	do
		local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
		local client = sps and sps:FindFirstChild("ZRClient")
		local controllers = client and client:FindFirstChild("Controllers")
		local mod = controllers and controllers:FindFirstChild("Menus")
		local okM, Menus = false, nil
		if mod then
			okM, Menus = pcall(require, mod)
		end
		if okM and type(Menus) == "table" and Menus.CAT then
			local missing = {}
			for _, d in Items.defs do
				if d.kind ~= "hazard" and not Menus.CAT[d.kind] and not table.find(missing, d.kind) then
					table.insert(missing, d.kind)
				end
			end
			check("handbook: flares under SPECIAL EQUIPMENT, a category in the list, every item kind has one"
				.. (#missing > 0 and (" (none for " .. table.concat(missing, ", ") .. ")") or ""),
				Menus.CAT.flare == "SPECIAL EQUIPMENT" and table.find(Menus.CATS, "SPECIAL EQUIPMENT") ~= nil and #missing == 0)
		else
			check("handbook: the client's Menus module loads for the category check", false)
		end
		check("flea: the green flare lists and sells from level 15; the red one stays off the market (EFT)",
			FR.canBuy("FLARE_GREEN", FR.LEVEL) == true and not FR.tradeable("FLARE_RED"))
	end

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T
