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

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T
