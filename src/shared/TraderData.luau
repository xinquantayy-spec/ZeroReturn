--!strict
-- Traders (original characters, Tarkov rules). Audit decision economy-2a, "EFT's eight, one currency": each trader plays
-- one of EFT's eight trader roles, with that role's goods, buying, loyalty and services; MK stays the only currency.
--   VOS    Quartermaster  = Prapor: Soviet-bloc guns, ammunition, grenades; repairs weapons
--   HALE   Field Medic    = Therapist: medicine and food; pays the most for valuables, barter goods and keys
--   FENCE  Fence          = Fence: buys anything; loyalty and prices from karma
--   ROOK   Fixer          = Skier: weapon parts and smuggled goods, smuggled Western guns later; repairs weapons and armour
--   DEKKER Liaison        = Peacekeeper: NATO guns, Western ammunition and optics; Pouch M (EFT's Beta)
--   KOVAC  Gunsmith       = Mechanic: gunsmith parts, suppressors, optics and finished builds; repairs weapons
--   TILDA  Outfitter      = Ragman: armour, helmets, rigs, packs, clothing, headsets and eyewear
--   BRAM   Gamekeeper     = Jaeger: bolt-action rifles, hunting shotguns, food and field medicine; T-7 thermals at the top
-- What each EFT trader sells and buys: tarkovforge.com/traders/<name> (read 2026-11-08); gameslikefinder.com/article/
-- trader-order-tarkov/ (buy categories); wikiwiki.jp/eft trader page (who pays more, who repairs); night vision by trader and
-- level: ggrecon.com/guides/escape-from-tarkov-night-vision-comparison-full-list. Loyalty levels open goods; each trader
-- buys certain kinds of items at a share of their value; barters swap items for items; stock is limited per restock window.
-- Shared so the client shows exactly the prices the server charges (server truth: Economy.luau).
local Items = require(script.Parent.Items)
local WP = require(script.Parent.WeaponParts)
local P = require(script.Parent.Progress)
local QD = require(script.Parent.QuestData)
local Config = require(script.Parent.Config)

local T = {}

T.RESTOCK = 1800 -- seconds between restocks (per player purchase limits reset)

-- EFT's order on its trader screen: Prapor, Therapist, Fence, Skier, Peacekeeper, Mechanic, Ragman, Jaeger
T.list = { "vos", "hale", "fence", "rook", "dekker", "kovac", "tilda", "bram" }

-- buy shares (what a trader pays as a share of an item's value). EFT's own figures (the traders' buy coefficients) were out
-- of reach: SPT's trader files are not on disk and tarkov.dev is blocked. So the shares are ours, ranked as the sources
-- describe EFT: the Therapist pays the most for medicine, valuables and keys, the Ragman for gear, the Mechanic a little more
-- than Prapor for weapons and parts, Skier less than the Mechanic, Jaeger at or above the Mechanic for the guns and scopes he
-- takes and a little under the Therapist for medicine, the Peacekeeper little, Fence least. Only Jaeger and Fence buy melee
-- weapons (wikiwiki.jp/eft).
T.defs = {
	vos = {
		name = "VOS", title = "Quartermaster", markup = 1.25,
		desc = "Ex-harbour armourer. Sells eastern rifles, pistols and shotguns, their ammunition, grenades and magazines; repairs weapons.",
		buys = { weapon = 0.55, pistol = 0.55, mod = 0.55, mag = 0.5, ammo = 0.5, key = 0.5, grenade = 0.5, repair = 0.5 },
	},
	hale = {
		name = "HALE", title = "Field Medic", markup = 1.2,
		desc = "Runs the relay's aid station. Medicine and food, and she pays best for valuables, barter goods and keys.",
		buys = { med = 0.55, food = 0.5, loot = 0.5, key = 0.55 },
	},
	fence = {
		name = "FENCE", title = "Fence", markup = 1.7,
		desc = "Buys anything, no questions. Remembers how you treat the locals.",
		buys = "*", buyRate = 0.4,
	},
	rook = {
		name = "ROOK", title = "Fixer", markup = 1.25,
		desc = "Ran the customs terminal before it fell. Parts, sights and night vision that fell off a truck, smuggled guns later; repairs weapons and armour.",
		buys = { weapon = 0.5, pistol = 0.5, mod = 0.5, nvg = 0.5, mag = 0.48, loot = 0.45 },
	},
	dekker = {
		name = "DEKKER", title = "Liaison", markup = 1.25,
		desc = "Stayed on after the ceasefire mission left. Western rifles, ammunition, optics and night vision for anything of value.",
		buys = { weapon = 0.45, pistol = 0.45, mod = 0.45, nvg = 0.45, ammo = 0.45, armor = 0.45, helmet = 0.45, plate = 0.45 },
		-- EFT's Peacekeeper also takes intelligence: drives, diaries, flash drives (gameslikefinder.com)
		buyIds = { FLASH_MODULE = 0.45, INTEL_FOLDER = 0.45, HDD = 0.45 },
	},
	kovac = {
		name = "KOVAC", title = "Gunsmith", markup = 1.25,
		desc = "Builds and tunes rifles in the back room. Parts, suppressors, optics and finished builds as he comes to trust you; repairs weapons.",
		buys = { weapon = 0.57, pistol = 0.57, mod = 0.57, nvg = 0.57, mag = 0.5, ammo = 0.5, grenade = 0.5 },
	},
	tilda = {
		name = "TILDA", title = "Outfitter", markup = 1.25,
		desc = "Stitches, sells and fits armour, helmets, rigs, packs, headsets and eyewear.",
		buys = { armor = 0.55, helmet = 0.55, plate = 0.55, rig = 0.55, backpack = 0.55, headwear = 0.5, headset = 0.55, facecover = 0.5, eyewear = 0.5 },
	},
	bram = {
		-- Jaeger's food and basic medicine are among the cheapest (tarkovforge.com/traders/jaeger): a lower markup
		name = "BRAM", title = "Gamekeeper", markup = 1.15,
		desc = "Keeps a camp in the woods. Bolt rifles, hunting shotguns, food and field medicine; buys knives, hunting guns, scopes and building materials.",
		buys = { melee = 0.55, med = 0.53, food = 0.5 },
		-- Jaeger takes some guns (shotguns and bolt-actions, no automatic military weapons), scopes and building materials
		buyIds = {
			HARROW12 = 0.58, TUNDRA_BOLT = 0.58, SCOPE_4X = 0.58, SCOPE_16 = 0.58, SCOPE_8X = 0.58,
			BOLTS = 0.48, DUCT_TAPE = 0.48, WIRES = 0.48, SPARK_PLUG = 0.48, FUEL_CAN = 0.48, BLEACH = 0.48,
		},
	},
}

-- ── loyalty levels ──────────────────────────────────────────────────────────────────────────────────────────────
-- EFT 1.1.0 (3 Aug 2026): a loyalty level needs a player level and a standing; "removed the required trader sales volume
-- from Loyalty Level requirements" (patch notes, quoted by switchbladegaming.com/escape-from-tarkov/first-quests/). EFT's
-- player levels and standings for LL2, LL3, LL4 (tarkovforge.com/traders/<name>, live from tarkov.dev, read 2026-11-08):
T.EFT_LL = {
	vos = { { 6, 0.7 }, { 21, 2.7 }, { 36, 7.9 } }, -- Prapor
	hale = { { 5, 0.6 }, { 18, 2.1 }, { 37, 5.8 } }, -- Therapist
	rook = { { 7, 0.6 }, { 22, 2.1 }, { 38, 5.8 } }, -- Skier
	dekker = { { 8, 0.5 }, { 19, 2.2 }, { 37, 6.0 } }, -- Peacekeeper
	kovac = { { 12, 0.6 }, { 26, 2.3 }, { 40, 7.6 } }, -- Mechanic
	tilda = { { 12, 0.5 }, { 27, 2.0 }, { 42, 6.5 } }, -- Ragman
	bram = { { 9, 0.6 }, { 17, 2.1 }, { 33, 7.3 } }, -- Jaeger (in EFT locked until Mechanic's "Introduction"; open here)
}
-- Standing comes from tasks (EFT 1.1.0). Decision economy-6a gave every trader enough tasks: each trader's tasks now give
-- at least EFT's LL4 standing (QuestData: about four times EFT's standing a task, since we have about a quarter of EFT's
-- tasks a trader), so the standings below are EFT's own, unscaled (before economy-6a they were scaled down so that LL4 needed
-- all of a trader's few tasks: VOS's LL4 was 0.46, now 7.9). The scaling stays for a trader whose tasks give less than
-- EFT's LL4 standing: then its standings are EFT's scaled so that LL4 needs exactly what its tasks give (LL2 and LL3 keep
-- EFT's share of LL4), rounded down to 0.01. Player levels are EFT's (since economy-4b our levels run to EFT's 79, so
-- Ragman's LL4 at 42 is no longer capped). Money spent is still counted but asks nothing, as in EFT 1.1.0.
T.TASK_REP = {} :: { [string]: number } -- [trader] = net standing all tasks give it (QuestData rewards: rep, and reps from others)
for _, q in QD.list do
	local r = q.reward and q.reward.rep
	if r and r > 0 then
		T.TASK_REP[q.trader] = (T.TASK_REP[q.trader] or 0) + r
	end
	for tid, d in (q.reward and q.reward.reps) or {} do
		T.TASK_REP[tid] = (T.TASK_REP[tid] or 0) + d
	end
end
local function down2(x: number): number
	return math.floor(x * 100 + 1e-6) / 100
end
T.LOYALTY = {} :: { [string]: { any } } -- [trader] = { [ll] = { level, rep, spent, eftLevel, eftRep } }; LL1 is free
for tid, rows in T.EFT_LL do
	local top = rows[#rows][2]
	local k = math.min(1, (T.TASK_REP[tid] or 0) / top)
	local list = { { level = 1, rep = 0, spent = 0 } }
	for _, r in rows do
		table.insert(list, { level = math.min(r[1], P.MAX_LEVEL), rep = down2(r[2] * k), spent = 0, eftLevel = r[1], eftRep = r[2] })
	end
	T.LOYALTY[tid] = list
end
-- older readers (EconomyTests) index TD.LL[n]: VOS's table
T.LL = T.LOYALTY.vos

function T.loyaltyReq(tid: string, ll: number): any
	local list = T.LOYALTY[tid]
	return list and list[ll]
end

-- a trader's loyalty level for a player level, standing and money spent (not Fence: TraderData.fenceLoyalty). The standing
-- is compared with a hair of slack, so 0.05 + 0.07 + ... summed in another order still counts.
function T.loyaltyOf(tid: string, level: number, rep: number?, spent: number?): number
	local list = T.LOYALTY[tid]
	if not list then
		return 1
	end
	local ll = 1
	for i = 2, #list do
		local req = list[i]
		if level >= req.level and (rep or 0) + 1e-6 >= req.rep and (spent or 0) >= req.spent then
			ll = i
		else
			break
		end
	end
	return ll
end

-- Fence (audit economy.5): his loyalty comes from karma, the Fence standing, as in EFT: LL1 at any standing, LL2 at 6.0,
-- with no player level or money needed (EFT's trader base: minStanding 0 and 6, minLevel 1, minSalesSum 0, as the SPT
-- server copies it; tarkovforge.com/traders/fence). His prices move with karma both ways: EFT's FenceSettings
-- PriceModifier for each whole point of standing from -7 to +6 (EFT's globals, as SPT copies them in
-- project/assets/database/globals.json); the standing is rounded to 0.01 and then down to a whole point, as SPT does.
T.FENCE_LL2 = 6
T.FENCE_PRICE = {
	[-7] = 1.2, [-6] = 1.17, [-5] = 1.15, [-4] = 1.12, [-3] = 1.1, [-2] = 1.08, [-1] = 1.05,
	[0] = 1, [1] = 0.97, [2] = 0.95, [3] = 0.92, [4] = 0.9, [5] = 0.85, [6] = 0.8,
}
local function standingOf(karma: number?): number
	return math.floor((karma or 0) * 100 + 0.5) / 100
end
function T.fencePriceMul(karma: number?): number
	return T.FENCE_PRICE[math.clamp(math.floor(standingOf(karma)), -7, 6)] or 1
end
function T.fenceLoyalty(karma: number?): number
	return standingOf(karma) >= T.FENCE_LL2 and 2 or 1
end

-- ── goods ───────────────────────────────────────────────────────────────────────────────────────────────────────
-- offers: id, loyalty level, limit per restock, n = stack per purchase (ammo). The same item may sit with two traders at
-- different levels, as in EFT. Our guns copy EFT's: R-17 = M4A1, KS-7 = AKM, SMG-9 = MP5, Harrow-12 = MP-133, Tundra =
-- Mosin, P-9 = MP-443 Grach (Weapons.luau); each goes to the trader that sells its counterpart.
local function o(id: string, ll: number, limit: number, n: number?): any
	return { id = id, ll = ll, limit = limit, n = n or 1 }
end
-- task-locked offers (decision economy-6a; EFT: a task reward "Unlocks purchase of X at Trader LLn", e.g. Gunsmith - Part 1
-- opens a gas block at Mechanic LL1 and BP Depot a gun at Prapor LL1; EFT wiki). task = on sale once that task is turned
-- in; start = on sale while one of those tasks is taken or done (EFT 1.1.0: in the few chains left, "the key reward appears
-- when you accept the first task", allthings.how). They sit at the end of each list, so older offers keep their index.
local function ot(id: string, ll: number, limit: number, n: number?, task: string?, start: { string }?): any
	local x = o(id, ll, limit, n)
	x.task, x.start = task, start
	return x
end
-- M14: a gun sold as a build (Tarkov trader presets): the base item with the preset's parts and an empty magazine
local function pre(preset: string, ll: number, limit: number, task: string?): any
	local pr = WP.META.presets[preset]
	return { id = pr.base, ll = ll, limit = limit, n = 1, preset = preset, task = task }
end
T.offers = {
	-- Prapor: "AK platform rifles, Russian ammunition, grenades" (tarkovforge): the Grach and the MP-133 from LL1, the AKM
	-- and its ammunition from LL2, rifle-cartridge and slug ammunition, a PSO-style 4x and a suppressor at LL3, AP rounds at LL4
	vos = {
		o("P9_PISTOL", 1, 2), o("HARROW12", 1, 2), o("P9_MAG", 1, 10), o("KST_MAG", 1, 6),
		o("GREN_RK5", 1, 4), o("GREN_SMOKE", 1, 3), o("FLARE_GREEN", 1, 2),
		o("KST_FH_SLANT", 1, 3), o("AK_PG_RUB", 1, 2), o("KST_HG_POLY", 1, 2),
		o("KST_RIFLE", 2, 1), o("KST_MAG_POLY", 2, 6), o("A76_PS", 2, 8, 60), o("GREN_STUN", 2, 3), o("GREN_F7", 2, 3),
		o("BRAKE_76", 2, 1), o("KST_STK_FOLD", 2, 1), o("P9_MAG33", 2, 3), pre("HAR_SHORT", 2, 1),
		o("A76L_LPS", 3, 4, 40), o("SCOPE_4X", 3, 1), o("SUPP_76", 3, 1), o("KST_MAG40", 3, 3),
		o("A76_BP", 4, 3, 60), pre("KST_QUIET", 4, 1),
		-- rounds (economy-1a; EFT's Prapor, wiki and xgamingserver item pages): US and T-45M1 at LL3, PP and PBP at LL4, the
		-- T-46M at LL3 and PS gzh at LL4. PS stays at LL2 here: it stands in for EFT's 7.62x39 FMJ and SP, which we do not have
		o("A76_US", 3, 4, 60), o("A76_TR", 3, 4, 60), o("A76L_TR", 3, 4, 40), o("A76_PP", 4, 3, 60), o("A9_PBP", 4, 3, 50),
		o("A76L_PS", 4, 3, 40),
		-- the sixth slice: EFT's Prapor sells 9x39 SP-5 at LL2 and SPP and SP-6 at LL4 (tarkovforge.com's round pages)
		o("A939_SP5", 2, 6, 50), o("A939_SPP", 4, 4, 50), o("A939_SP6", 4, 3, 50),
		-- the third slice (tarkovforge.com round pages, 2026-11-08): Prapor sells 5.45 US gs at LL1, T gs and PS gs at LL2 and
		-- BT gs at LL4 (BP gs and BS gs come from loot and crafts), and the 9x18 P, PPT, Pst, RG028 and PBM loads at LL1;
		-- the 6L20 magazine at LL1 and the 6L26 at LL3
		o("A54_US", 1, 6, 60), o("A54_T", 2, 6, 60), o("A54_PS", 2, 8, 60), o("A54_BT", 4, 3, 60),
		o("A918_P", 1, 10, 50), o("A918_PPT", 1, 8, 50), o("A918_PST", 1, 8, 50), o("A918_RG", 1, 6, 50), o("A918_PBM", 1, 4, 50),
		o("KS74_MAG", 1, 6), o("KS74_MAG45", 3, 3), o("PM_MAG", 1, 10),
		-- plates (gameplay-2a): EFT sells the Korund-VM plates at Prapor LL4 (tarkovforge); the PC-4's at LL2 (ours)
		o("PLATE_PC4F", 2, 2), o("PLATE_PC4B", 2, 2), o("PLATE_HP5F", 4, 1), o("PLATE_HP5B", 4, 1), o("PLATE_HP5S", 4, 2),
		-- task-locked (economy-6a): Fuel Count opens the KS-7 at LL1 (EFT's BP Depot opens a gun at Prapor LL1); markers for
		-- the marking tasks (EFT: "Additional ones can be bought from Prapor or Ragman", wiki BP_Depot; TILDA sells gear only)
		ot("KST_RIFLE", 1, 1, 1, "V10"), ot("MARKER", 1, 4, 1, nil, { "V10", "R8" }), ot("KST_MAG40", 2, 2, 1, "V14"), ot("A76_BP", 3, 2, 60, "V17"),
	},
	-- the Therapist: dressings and painkillers first, bigger kits and stimulants of their kind higher up
	hale = {
		o("BANDAGE", 1, 10), o("PAINKILLERS", 1, 5), o("MEDKIT_S", 1, 5), o("SPLINT", 1, 5), o("WATER", 1, 5), o("HARDTACK", 1, 5),
		o("TOURNIQUET", 2, 5), o("MEDKIT_M", 2, 4), o("STEW", 2, 5), o("VOLT_DRINK", 2, 3),
		o("HEMOSTAT", 3, 3), o("MEDKIT_L", 3, 2), o("ANTIDOTE", 3, 1),
		o("SURGKIT", 4, 1), o("MEDKIT_XL", 4, 1),
		-- stimulants (gameplay-4b): EFT's Therapist sells Propital and Zagustin at LL4 (TarkovForge); the adrenaline at LL2
		-- is ours; nobody sells the SJ6's kind for cash (TarkovForge), so the SV-3 is loot only
		o("STIM_ADREN", 2, 3), o("STIM_REGEN", 4, 2), o("STIM_HEMO", 4, 2),
		-- task-locked (economy-6a): a level earlier than the open offer
		ot("MEDKIT_L", 2, 1, 1, "H9"), ot("SURGKIT", 3, 1, 1, "H11"), ot("MEDKIT_XL", 3, 1, 1, "H14"),
	},
	fence = {
		o("RIG_BELT", 1, 2), o("BAG_SLING", 1, 2), o("BANDAGE", 1, 4), o("R17_MAG", 1, 4), o("A62_FMJ", 1, 4, 60), o("KEY_OFFICE", 1, 1),
		o("KEY_DORM_104", 1, 1), o("KEY_DORM_203", 2, 1), o("GREN_RK5", 1, 2), o("KEY_SMELT_OFFICE", 1, 1),
		o("MULTITOOL", 1, 1),
	},
	-- Skier: "weapon modifications and attachments", "smuggled western weapons at his higher levels" (tarkovforge); the
	-- PNV-10T at LL2 and the PVS-14 at LL3 (ggrecon): our NV-2 and NV-1
	rook = {
		o("RED_DOT", 1, 1), o("GRIP_V", 1, 2), o("GRIP_STOP", 1, 3), o("LIGHT_T", 1, 2), o("R17_FH_A2", 1, 3), o("R17_RS_FLIP", 1, 2),
		o("R17_FS_FLIP", 1, 2), o("AR_PG_ERGO", 1, 2), o("MNT_RISER", 1, 3), o("KST_MAG", 1, 6),
		o("A12_BUCK", 1, 8, 20), o("A12_SLUG", 1, 4, 20), -- EFT's Skier sells 7 mm buckshot and the lead slug at LL1 (economy-1a)
		o("A76N_SP", 2, 6, 40), -- the fifth slice: EFT's Skier sells 7.62x51 TCW SP at LL2 (tarkovforge.com)
		o("NV_BINO", 2, 1), o("KST_DC_RAIL", 2, 1), o("KST_HG_RAIL", 2, 1), o("AK_PG_ERGO", 2, 2), o("GRIP_ANG", 2, 2),
		o("LASER_DOT", 2, 2), o("KST_MNT_SIDE", 2, 1), o("SPR_FH_3L", 2, 2),
		o("NV_MONO", 3, 1), o("SPARROW_SMG", 3, 1), o("KST_STK_TUBE", 3, 1), o("HAR_STK_TACT", 3, 1), pre("KST_TAC", 3, 1), pre("HAR_TAC", 3, 1),
		o("LASER_COMBO", 4, 1), pre("SPR_TAC", 4, 1),
		-- task-locked (economy-6a)
		ot("NV_BINO", 1, 1, 1, "R4"), ot("NV_MONO", 2, 1, 1, "R7"), ot("LASER_COMBO", 3, 1, 1, "R9"),
	},
	-- the Peacekeeper: "NATO platform weapons, including M4 platform rifles and HK builds", "western optics", "western
	-- ammunition" (tarkovforge); the UN vest from LL1 (EFT's MF-UNTAR, which his Fishing Gear task asks for); the N-15 at LL3
	-- and the GPNVG-18 at LL4 (ggrecon): our G-15 and NV-4
	dekker = {
		o("R17_RIFLE", 1, 2), o("R17_MAG", 1, 10), o("SPARROW_MAG", 1, 6), o("ARMOR_C3", 1, 1), o("GREN_RK5", 1, 2),
		o("SPARROW_SMG", 2, 1), o("R17_MAG40", 2, 3), o("HOLO_EX", 2, 1), o("SUPP_9", 2, 1),
		o("NV_GREEN", 3, 1), o("SCOPE_16", 3, 1), o("SUPP_62", 3, 1),
		o("A76N_BALL", 4, 6, 40), -- the fifth slice: EFT's Peacekeeper sells 7.62x51 M80 at LL4 (tarkovforge.com)
		-- the seventh slice: EFT's Peacekeeper sells 5.7x28 SS198LF (LL1), SS197SR and SB193 (LL2), L191 (LL3) and SS190 (LL4)
		o("A57_LF", 1, 6, 60), o("A57_SR", 2, 6, 60), o("A57_SUB", 2, 6, 60), o("A57_TR", 3, 4, 60), o("A57_SS", 4, 4, 60),
		-- the eighth slice: EFT's Peacekeeper sells .45 ACP Lasermatch and Match FMJ (LL1), Hydra-Shok (LL2) and AP (LL4)
		o("A114_TR", 1, 6, 50), o("A114_FMJ", 1, 6, 50), o("A114_HP", 2, 6, 50), o("A114_AP", 4, 3, 50),
		-- rounds (economy-1a; EFT's Peacekeeper, wiki and tarkovforge): 9x19 FMJ M882 and the lead slug at LL1, 5.56 FMJ at
		-- LL2, M855 and AP 6.3 at LL3, M856A1 at LL4; M995 by barter only (no trader sells it for cash in EFT)
		o("A9_FMJ", 1, 10, 50), o("A12_SLUG", 1, 4, 20), o("A62_FMJ", 2, 10, 60), o("A62_SS", 3, 6, 60), o("A9_AP", 3, 4, 50),
		o("A62_TR", 4, 3, 60),
		-- EFT's Peacekeeper sells a 40x46 round at LL3 (the M386, after a task; the wiki); the GL-6 itself is MORTAR's only
		o("A40_HE", 3, 6),
		o("NV_QUAD", 4, 1), o("R17_MAG60", 4, 2),
		-- western plates by loyalty (ours, gameplay-2a): class 3 polyethylene at LL1 up to class 5 side plates at LL3
		o("PLATE_PE3", 1, 2), o("PLATE_CE4", 2, 2), o("PLATE_PE4", 3, 1), o("PLATE_CE5S", 3, 2),
		-- task-locked (economy-6a)
		ot("NV_GREEN", 2, 1, 1, "D5"), ot("A62_AP", 2, 3, 60, "D6"), ot("R17_MAG60", 3, 1, 1, "D10"),
	},
	-- the Mechanic: "high-end attachments, suppressors, and optics" gated by loyalty, "pre-built custom weapons, available at
	-- higher loyalty levels" (tarkovforge): plain parts at LL1, rails, brakes and the first builds at LL2, free-float
	-- handguards, compact suppressors and the close-quarters builds at LL3, the 8x scope and the marksman build at LL4
	kovac = {
		o("AR_STK_CARB", 1, 2), o("P9_BRL_THR", 1, 2), o("AR_CH_EXT", 1, 2), o("GRIP_STUB", 1, 2), o("SPR_STK_FIXED", 1, 1),
		o("R17_HG_QUAD", 2, 2), o("R17_COMP", 2, 2), o("R17_BRK", 2, 2), o("AR_PG_ANG", 2, 2), o("SIGHT_MICRO", 2, 1),
		o("P9_SLIDE_CUT", 2, 1), o("P9_COMP", 2, 1), o("R17_BRL_105", 2, 1), o("SPR_HG_TRI", 2, 1), o("SPR_MNT_CLAW", 2, 1),
		o("WEAPON_KIT", 2, 1), pre("R17_PATROL", 2, 1), pre("P9_TAC", 2, 1),
		o("R17_HG_MLOK", 3, 1), o("R17_GAS_LOW", 3, 2), o("R17_BRL_18", 3, 1), o("SUPP_62C", 3, 1), o("AR_STK_SKEL", 3, 1),
		o("MNT_RINGS", 3, 1), o("LASER_COMBO", 3, 1), o("SPR_GRIP_NAVY", 3, 1), o("SPR_MAG50", 3, 2),
		-- the KS-74 at LL2: EFT's Mechanic sells the AK-74N at LL2 (tarkovforge.com's AK-74N page)
		o("KS74_RIFLE", 2, 1), o("BRAKE_74", 1, 2),
		-- the fifth slice: EFT's Mechanic sells the M1A at LL3 (tarkovforge.com's M1A page); its magazines, flash suppressor and
		-- mount beside it (ours)
		o("M1A_RIFLE", 3, 1), o("M1A_MAG", 3, 4), o("M1A_MAG20", 3, 3), o("M1A_FH", 3, 2), o("M1A_MNT", 3, 2),
		-- the seventh slice: EFT's Mechanic sells 4.6x30 Action SX (LL1), Subsonic SX (LL2), JSP SX (LL3) and FMJ SX (LL4), and
		-- 5.7x28 R37.X (LL2) and R37.F (LL3) (tarkovforge.com's round pages)
		o("A46_HP", 1, 6, 60), o("A46_SUB", 2, 6, 60), o("A46_JSP", 3, 6, 60), o("A46_FMJ", 4, 4, 60), o("A57_EX", 2, 6, 60), o("A57_FX", 3, 6, 60),
		o("A114_FX", 4, 4, 50), -- the eighth slice: EFT's Mechanic sells .45 ACP RIP at LL4 (tarkovforge.com)
		-- rounds (economy-1a; EFT's Mechanic): the green tracer at LL1, Pst gzh at LL2, RIP at LL4
		o("A9_TR", 1, 10, 50), o("A9_PST", 2, 10, 50), o("A9_RIP", 4, 3, 50),
		pre("R17_CQB", 3, 1), pre("SPR_TAC", 3, 1),
		o("SCOPE_8X", 4, 1), pre("R17_DMR", 4, 1),
		-- task-locked (economy-6a): Bench Work - Part 1 opens the low-profile gas block at LL1 (EFT's Gunsmith - Part 1 opens a
		-- gas block at Mechanic LL1, wiki); beacons and trail cameras for the planting tasks
		ot("R17_GAS_LOW", 1, 2, 1, "K2"), ot("SPR_HG_TRI", 1, 1, 1, "K4"), ot("BEACON", 1, 3, 1, nil, { "K3", "D7" }),
		ot("CAMERA", 1, 3, 1, nil, { "K5", "K14" }), ot("SUPP_62C", 2, 1, 1, "K7"), ot("SCOPE_8X", 3, 1, 1, "K13"), pre("R17_DMR", 3, 1, "K15"),
	},
	-- the Ragman: "body armor and armored rigs", "helmets and face protection", "backpacks and tactical clothing"
	-- (tarkovforge); class 2 at LL1 up to class 5 at LL4, the bigger packs and the headsets as loyalty grows
	tilda = {
		o("RIG_BELT", 1, 3), o("BAG_SLING", 1, 3), o("ARMOR_C2", 1, 2), o("HELMET_C2", 1, 2),
		o("CAP_FIELD", 1, 3), o("BEANIE", 1, 3), o("GAITER", 1, 3), o("NV_STRAP", 1, 2), o("HEADSET_GS1", 2, 1), o("HEADSET_COMM", 3, 1),
		o("RIG_CHEST", 2, 2), o("CANVAS_BAG", 2, 2), o("ARMOR_C3", 2, 2), o("HELMET_C3", 2, 1),
		o("BAG_PATROL", 3, 1), o("ARMOR_C4", 3, 1), o("HELMET_C4", 3, 1), o("RIG_PLATE", 3, 1),
		o("BAG_RAID", 4, 1), o("ARMOR_C5", 4, 1), o("PLATE_PE3", 2, 2), -- (a spare class 3 plate, gameplay-2a)
		-- eyewear (Tarkov: the outfitter's plain glasses from LL1, the shooting glasses at LL3, ballistic glasses at LL3-4; gas masks
		-- are not sold for cash)
		o("GLASSES_SUN", 1, 3), o("GLASSES_RANGE", 3, 2), o("GLASSES_BG1", 3, 1), o("GLASSES_AF2", 4, 1),
		-- task-locked (economy-6a), gear only as ever
		ot("BAG_PATROL", 2, 1, 1, "L4"), ot("HELMET_C4", 2, 1, 1, "L7"), ot("ARMOR_C5", 3, 1, 1, "L11"),
	},
	-- Jaeger: "bolt-action rifles and hunting shotguns", "medical supplies", "food", "wilderness gear" (tarkovforge); the
	-- shotgun, knife and basic supplies at LL1, the bolt rifle at LL2, its scope and rifle cartridges at LL3, its chassis,
	-- suppressor and marksman build at LL4; the T-7 thermals are his LL4 deal (ggrecon), as a barter
	bram = {
		o("HARROW12", 1, 2), o("A12_BUCK", 1, 8, 20), o("FIELD_KNIFE", 1, 3), o("BANDAGE", 1, 5), o("WATER", 1, 3), o("HARDTACK", 1, 5),
		-- rounds (economy-1a; EFT's Jaeger, the wiki's 12/70 page and round pages): the lead slug and the 5.56 and 7.62x39
		-- hollow points at LL1, Poleva-6u at LL2, Magnum buckshot and flechettes at LL3
		o("A12_SLUG", 1, 4, 20), o("A62_HP", 1, 6, 60), o("A76_HP", 1, 6, 60), o("A12_SABOT", 2, 4, 20), o("A12_MAG", 3, 4, 20),
		o("A54_HP", 1, 6, 60), o("A918_PSV", 2, 6, 50), -- the third slice: Jaeger's 5.45 HP (LL1) and 9x18 PSV (LL2)
		-- the fifth slice: Jaeger's 7.62x51 Ultra Nosler at LL1 and BCP FMJ at LL3 (tarkovforge.com's round pages); the OB-7's
		-- magazines and rail base (ours; the rifle itself is a barter, below)
		o("A76N_HP", 1, 6, 40), o("A76N_FMJ", 3, 6, 40), o("M700_MAG", 2, 4), o("M700_MAG10", 3, 2), o("M700_RAIL", 2, 2),
		o("A939_FMJ", 1, 6, 50), -- the sixth slice: EFT's Jaeger sells 9x39 FMJ at LL1 (tarkovforge.com)
		o("A12_FLECH", 3, 3, 20),
		o("HAR_FE_POLY", 1, 2), o("HAR_STK_PG", 1, 1),
		o("TUNDRA_BOLT", 2, 1), o("TUN_MNT_SCOUT", 2, 1), o("TUN_STK_SPORT", 2, 1), o("HAR_FE_RAIL", 2, 1),
		o("HAR_BRK", 2, 1), o("HAR_CHOKE", 2, 1), o("HAR_BRL_14", 2, 1), o("HAR_TUBE_4", 2, 1), o("SPLINT", 2, 3), o("STEW", 2, 3),
		o("A76L_LPS", 3, 4, 40), o("TUN_MNT_SIDE", 3, 1), o("TUN_BRK", 3, 1), o("HAR_BRL_20", 3, 1), o("HAR_TUBE_8", 3, 1),
		o("SCOPE_4X", 3, 1), o("MEDKIT_M", 3, 2), o("JUICE", 3, 3), pre("TUN_SCOUT", 3, 1),
		o("SUPP_76L", 4, 1), o("TUN_STK_CHAS", 4, 1), pre("TUN_MARKSMAN", 4, 1),
		-- task-locked (economy-6a)
		ot("TUN_MNT_SIDE", 2, 1, 1, "B3"), ot("SUPP_76L", 3, 1, 1, "B6"), pre("TUN_MARKSMAN", 3, 1, "B11"),
	},
}

-- barter trades: get `id` for the items in `give` ({ id, n })
local function b(id: string, ll: number, limit: number, give: { any }, n: number?): any
	return { id = id, ll = ll, limit = limit, give = give, n = n }
end
T.barters = {
	vos = {
		b("KST_RIFLE", 1, 1, { { "CAPACITOR", 1 }, { "LOGIC_BOARD", 1 } }),
		-- EFT's SKS and SVDS are barter-only (tarkovforge.com: no trader sells them for money): the SK-45 at LL1 for hardware,
		-- the MR-10 at LL3 for valuables (the goods ours)
		b("SKS_RIFLE", 1, 2, { { "SCREWS", 2 }, { "NUTS", 1 } }),
		b("SVD_RIFLE", 3, 1, { { "GOLD_CHAIN", 2 }, { "SKULL_RING", 1 } }),
		b("SVD_MAG", 3, 4, { { "SPARE_PARTS", 1 } }),
		-- EFT sells neither the VSS nor the AS VAL for money (tarkovforge.com), nor PAB-9 and BP: here by barter at Prapor, the
		-- levels and goods ours
		b("VSS_RIFLE", 3, 1, { { "GOLD_CHAIN", 1 }, { "MIL_CIRCUIT", 1 } }),
		b("VAL_RIFLE", 4, 1, { { "GOLD_CHAIN", 2 }, { "MIL_CIRCUIT", 1 } }),
		b("VSS_MAG10", 3, 4, { { "SPARE_PARTS", 1 } }),
		b("VSS_MAG20", 3, 3, { { "SPARE_PARTS", 1 }, { "BOLTS", 1 } }),
		b("A939_PAB", 4, 2, { { "GUNPOWDER", 2 }, { "BOLTS", 2 } }, 50),
		b("A939_BP", 4, 1, { { "GUNPOWDER", 3 }, { "CAPACITOR", 2 } }, 50),
		-- EFT's PM is barter-only (tarkovforge.com: no trader sells it for money); ours at Prapor for small household goods
		b("PM_PISTOL", 1, 2, { { "TOILET_PAPER", 1 }, { "SOAP", 1 } }),
		-- EFT's RPK-16 comes by Prapor's barters at LL2 and LL3 (wiki): the KS-L and its drum at LL3 here
		b("KSL_LMG", 3, 1, { { "LOGIC_BOARD", 2 }, { "CAPACITOR", 2 }, { "BOLTS", 4 } }),
		b("KSL_DRUM95", 3, 1, { { "BOLTS", 3 }, { "DUCT_TAPE", 2 } }),
		b("GREN_F7", 1, 2, { { "BOLTS", 1 }, { "MATCHES", 2 } }),
		b("SCOPE_4X", 2, 1, { { "CRACKED_LENS", 1 }, { "WIRES", 2 } }),
		-- EFT sells SNB for no money (raids, barters and crafts, tarkovforge): a stack by barter at LL4, the goods ours (economy-1a)
		b("A76L_SNB", 4, 2, { { "GUNPOWDER", 2 }, { "BOLTS", 4 } }, 40),
	},
	hale = {
		b("MEDKIT_M", 1, 3, { { "CIGARETTES", 2 }, { "MATCHES", 1 } }),
		b("HEMOSTAT", 2, 2, { { "MED_TOOLS", 1 } }),
		b("SURGKIT", 3, 1, { { "MED_TOOLS", 1 }, { "CAPT_WATCH", 1 } }),
		-- EFT's Therapist trades the expeditionary fuel tank at LL2 for four packs of buckwheat (xgamingserver item page,
		-- 2026-11-04); stew stands in for the buckwheat, the limit is ours (economy-7b)
		b("FUEL_CAN", 2, 2, { { "STEW", 4 } }),
	},
	fence = {},
	-- Skier trades sights and night vision for household and electrical goods
	rook = {
		b("RED_DOT", 1, 1, { { "CIGARETTES", 3 }, { "LIGHTBULB", 2 } }),
		b("NV_BINO", 2, 1, { { "BATTERY", 1 }, { "WIRES", 2 } }),
	},
	dekker = {
		b("R17_MAG40", 1, 2, { { "BOLTS", 2 }, { "SPARK_PLUG", 1 } }),
		-- Pouch M (audit economy.7) as EFT's Beta container: Peacekeeper's LL2 barter, one a restock, for a 6-STEN-140-M
		-- military battery, 3 Iridium thermal vision modules, 3 Virtex processors and 5 military cables (EFT's assort as
		-- SPT copies it, traders/5935c25fb3acc3127c3d8cd9). Ours, all items that spawn: the deep-cycle battery, control
		-- boards, flash modules and wires
		b("SECURE_M", 2, 1, { { "BATTERY", 1 }, { "LOGIC_BOARD", 3 }, { "FLASH_MODULE", 3 }, { "WIRES", 5 } }),
		b("PLATE_CE5", 4, 1, { { "MIL_CIRCUIT", 2 }, { "BATTERY", 1 } }), -- a class 5 plate for military electronics (ours, gameplay-2a)
		-- EFT sells M995 for no money (raids, barters and crafts, tarkovforge): a stack by barter at LL4, the goods ours (economy-1a)
		b("A62_AP", 4, 2, { { "GUNPOWDER", 2 }, { "CAPACITOR", 2 } }, 60),
		-- the fifth slice: EFT sells M62, M80A1, M61 and M993 for no money (barters, crafts and raids; tarkovforge.com): stacks by
		-- barter here, the tracer at LL3 and the piercers at LL4 (the goods ours)
		b("A76N_TR", 3, 2, { { "GUNPOWDER", 1 }, { "BOLTS", 2 } }, 40),
		b("A76N_EP", 4, 2, { { "GUNPOWDER", 2 }, { "SPARK_PLUG", 2 } }, 40),
		b("A76N_AP", 4, 2, { { "GUNPOWDER", 2 }, { "CAPACITOR", 2 } }, 40),
		b("A76N_TC", 4, 1, { { "GUNPOWDER", 3 }, { "MIL_CIRCUIT", 1 } }, 40),
		-- the seventh slice: EFT sells neither the MP7A1 nor the P90 for money, nor 4.6x30 AP SX (tarkovforge.com); here by barter,
		-- with their magazines (levels and goods ours)
		b("MP7_SMG", 3, 1, { { "GOLD_CHAIN", 1 }, { "CAPACITOR", 2 } }),
		b("P90_SMG", 3, 1, { { "GOLD_CHAIN", 1 }, { "MIL_CIRCUIT", 1 } }),
		b("MP7_MAG20", 2, 4, { { "SPARE_PARTS", 1 } }),
		b("MP7_MAG30", 3, 3, { { "SPARE_PARTS", 1 }, { "BOLTS", 1 } }),
		b("MP7_MAG40", 4, 2, { { "SPARE_PARTS", 2 }, { "CAPACITOR", 1 } }),
		b("P90_MAG", 3, 3, { { "SPARE_PARTS", 1 }, { "BOLTS", 2 } }),
		b("A46_AP", 4, 2, { { "GUNPOWDER", 2 }, { "CAPACITOR", 1 } }, 60),
		-- the eighth slice: EFT sells none of the UMP 45, M1911A1 and Five-seveN for money (tarkovforge.com); here by barter, with
		-- their magazines (levels and goods ours)
		b("UMP_SMG", 2, 1, { { "WEAPON_PARTS", 1 }, { "BOLTS", 3 } }),
		b("M1911_PISTOL", 1, 1, { { "SCREWS", 2 }, { "BOLTS", 1 } }),
		b("FN57_PISTOL", 2, 1, { { "WEAPON_PARTS", 1 }, { "CAPACITOR", 1 } }),
		b("UMP_MAG", 2, 4, { { "SPARE_PARTS", 1 } }),
		b("M1911_MAG", 1, 5, { { "SCREWS", 1 } }),
		b("M1911_MAG11", 2, 3, { { "SPARE_PARTS", 1 } }),
		b("FN57_MAG", 2, 4, { { "SPARE_PARTS", 1 } }),
	},
	kovac = {
		b("WEAPON_KIT", 1, 1, { { "DUCT_TAPE", 2 }, { "SPARK_PLUG", 1 }, { "WIRES", 1 } }),
		b("SUPP_62", 2, 1, { { "SIGNAL_COIL", 2 }, { "CERAMIC_FUSE", 2 }, { "DUCT_TAPE", 1 } }),
	},
	tilda = {
		b("ARMOR_C3", 1, 1, { { "DUCT_TAPE", 2 }, { "WIRES", 2 }, { "BOLTS", 1 } }),
		b("ARMOR_C4", 2, 1, { { "GOLD_CHAIN", 1 }, { "WIRES", 2 }, { "DUCT_TAPE", 2 } }),
		b("BAG_RAID", 3, 1, { { "DECK_TRANSCEIVER", 1 }, { "FUEL_CAN", 1 }, { "GOLD_CHAIN", 1 } }),
	},
	-- Jaeger: an early bolt rifle for fuel and bolts; the T-7 thermals for high-end electronics and valuables
	bram = {
		b("TUNDRA_BOLT", 1, 1, { { "FUEL_CAN", 1 }, { "BOLTS", 2 } }),
		-- EFT's Remington Model 700 is barter-only (tarkovforge.com: no trader sells it for money); the trader, level and goods ours
		b("M700_BOLT", 2, 1, { { "GUN_LUBE", 1 }, { "WEAPON_PARTS", 2 } }),
		b("TH_T7", 4, 1, { { "MIL_CIRCUIT", 2 }, { "COLD_WALLET", 2 }, { "BATTERY", 2 } }),
	},
}

-- value of a gun as a build: the base plus every part of its preset (default build when preset is nil) and the
-- preset's magazine
function T.buildValue(id: string, preset: string?): number
	local d = Items.defs[id]
	local pr = WP.META.presets[preset or id]
	if not pr or pr.base ~= id then
		return d and d.value or 0
	end
	local v = 0
	local function add(t)
		local pd = Items.defs[t[1]]
		v += pd and pd.value or 0
		for _, sub in t[2] do
			add(sub)
		end
	end
	add(pr.tree)
	return v
end

-- price of one purchase. EFT: a loyalty level opens goods, it does not lower their price (the old 5 % a level is gone;
-- the argument stays for callers). karma: the player's Fence standing, which moves Fence's prices both ways (EFT's
-- PriceModifier, above; audit economy.5). Charisma no longer touches trader prices (audit economy.6).
function T.price(traderId: string, offer: any, _ll: number?, karma: number?): number
	local d = Items.defs[offer.id]
	local tr = T.defs[traderId]
	-- (a carrier comes with its default plates since gameplay-2a, so it costs the vest and the plates: Items.kitValue)
	local value = WP.isBase(offer.id) and T.buildValue(offer.id, offer.preset) or Items.kitValue(offer.id)
	local mul = traderId == "fence" and T.fencePriceMul(karma) or 1
	return math.max(1, math.ceil(value * (offer.n or 1) * tr.markup * mul))
end

-- is an offer or barter closed to this player? ll: the player's loyalty level with that trader; quests: the profile's task
-- states (server: prof.quests) or the snapshot's (client: d.quests), both { [task id] = { s = ... } }. Returns locked,
-- why (for the buy refusal and the deal panel). The server (Economy buy and barter) and the client ask the same.
function T.offerLock(offer: any, ll: number, quests: any?): (boolean, string?)
	if (offer.ll or 1) > ll then
		return true, "Requires loyalty level " .. offer.ll .. "."
	end
	local qs = type(quests) == "table" and quests or {}
	if offer.task then
		local st = qs[offer.task]
		if not (type(st) == "table" and st.s == "claimed") then
			local q = QD.byId[offer.task]
			return true, "Complete the task " .. (q and q.name or offer.task) .. " to unlock."
		end
	end
	if offer.start then
		for _, id in offer.start do
			local st = qs[id]
			if type(st) == "table" and (st.s == "active" or st.s == "claimed") then
				return false, nil
			end
		end
		local q = QD.byId[offer.start[1]]
		return true, "On sale once you take the task " .. (q and q.name or tostring(offer.start[1])) .. "."
	end
	return false, nil
end

-- the offers a task opens: { { trader, offer } } (the task screens list them under the reward)
function T.unlocksOf(taskId: string): { any }
	local out = {}
	for _, tid in T.list do
		for _, x in T.offers[tid] or {} do
			if x.task == taskId then
				table.insert(out, { trader = tid, offer = x })
			end
		end
	end
	return out
end

-- what a trader pays for an item instance (nil = not interested): a share by item id first (buyIds), then by kind. Fence
-- pays less with bad karma: 4 % a point between -3 and +3 (ours: EFT says only that he pays more as his standing grows; it
-- publishes no figure)
function T.sellPrice(traderId: string, it: any, karma: number?): number?
	local d = Items.defs[it.id]
	local tr = T.defs[traderId]
	if not d or not tr or it.rk or d.kind == "quest" or d.kind == "secure" then
		return nil
	end
	local rate
	if tr.buys == "*" then
		rate = (tr.buyRate or 0.4) * (1 + 0.04 * math.clamp(karma or 0, -3, 3))
	else
		rate = (tr.buyIds and tr.buyIds[it.id]) or (tr.buys :: any)[d.kind]
	end
	if not rate then
		return nil
	end
	return math.floor(Items.valueOf(it) * rate)
end

-- ── repairs (Tarkov: traders restore condition, but every repair costs some maximum durability) ───────────────
-- EFT's repairers: Prapor and the Mechanic repair weapons, Skier armour and weapons; the Ragman does not repair (wikiwiki.jp/
-- eft trader page; consolepcgaming.com, "armor repairs with Skier", Mechanic's weapon repairs). The price by loyalty level
-- follows EFT's repair price coefficients: Prapor 80, 90, 95, 100 %, Skier 110, 120, 130, 140 % (futuregamereleases.com,
-- Sept 2022); the Mechanic's was not found (100 % here). weapon: cost a point per MK of value; armor: the share of the
-- value a full repair costs. The repair kit works on weapons out of raid with less wear.
local GUNS = { weapon = true, pistol = true }
T.REPAIRS = {
	vos = { kinds = GUNS, weapon = 0.004, coef = { 0.8, 0.9, 0.95, 1 } },
	-- plain glasses have no durability: nothing to repair
	rook = { kinds = { weapon = true, pistol = true, armor = true, helmet = true, plate = true, rig = true, eyewear = true }, weapon = 0.004, armor = 0.4, coef = { 1.1, 1.2, 1.3, 1.4 } },
	kovac = { kinds = GUNS, weapon = 0.004, coef = { 1, 1, 1, 1 } },
}
T.KIT_DEGRADE = 0.03

-- condition now / maximum / the design maximum of an item (weapons 0-100, armour in its points)
function T.condition(it: any): (number?, number?, number?)
	local d = Items.defs[it.id]
	if not d then
		return nil
	end
	if d.kind == "weapon" or d.kind == "pistol" then
		return it.wear or 100, it.wmax or 100, 100
	elseif d.armor then
		return it.dur or d.armor.dur, it.dmax or d.armor.dur, d.armor.dur
	end
	return nil
end

-- a trader's repair of an item at a loyalty level: points restored, cost, the new maximum (nil = nothing to repair / not
-- theirs). discount: Charisma (Tarkov: 0.1 % off a level)
function T.repairQuote(traderId: string, it: any, discount: number?, ll: number?): (number?, number?, number?)
	local r = T.REPAIRS[traderId]
	local d = Items.defs[it.id]
	if not r or not d or not r.kinds[d.kind] or (d.kind == "rig" and not d.armor) then
		return nil
	end
	local cur, max, design = T.condition(it)
	if not cur or max - cur < 0.5 then
		return nil
	end
	local pts = max - cur
	local deg = d.armor and (0.04 + (d.armor.destr or 0.3) * 0.12) or 0.08
	local cost
	if d.armor then
		cost = pts / design * d.value * (r.armor or 0)
	else
		cost = pts * d.value * (r.weapon or 0)
	end
	cost = math.ceil(cost) * (r.coef[math.clamp(math.floor(ll or 1), 1, #r.coef)] or 1)
	return pts, math.max(1, math.ceil(cost * (1 - (discount or 0)))), math.max(1, max - pts * deg)
end

-- ── insurance (decision gameplay-6b, "Tarkov's rules, scaled times") ──────────────────────────────────────────────────
-- EFT wiki, Insurance (escapefromtarkov.fandom.com/wiki/Insurance): Prapor returns insured items after 24-36 h and holds
-- them 4 days (96 h); the Therapist returns them after 12-24 h, holds them 6 days (144 h) and is "~1.43x-1.23x more
-- expensive depending on trader level". EFT 1.1.0 (neonsect.com/escape-from-tarkov/tarkov-patch-1-1-0-0/, insider-gaming.com
-- 1.1.0 notes): insurance returns faster and costs a little more, and Jaeger insures too, "at significantly higher prices",
-- returning "within a couple of hours"; his exact figures were not published, so BRAM's 2-4 h and 2.5x are ours (1.1.0's
-- faster returns for Prapor and the Therapist were not published either: their pre-1.1 hours are used). eft = { fastest
-- return, slowest return, storage } in EFT's hours; the game divides returns by Config.INSURANCE_RETURN_DIV (12) and
-- storage by Config.INSURANCE_HOLD_DIV (4): VOS 2-3 h, held 24 h; HALE 1-2 h, held 36 h; BRAM 10-20 min, held 24 h. mul:
-- the price as a multiple of VOS's (HALE takes the middle of EFT's 1.23x-1.43x). VOS = Prapor, HALE = Therapist, BRAM = Jaeger.
T.INSURER_LIST = { "vos", "hale", "bram" }
T.INSURERS = {
	vos = { eft = { 24, 36, 96 }, mul = 1 },
	hale = { eft = { 12, 24, 144 }, mul = 1.33 },
	bram = { eft = { 2, 4, 96 }, mul = 2.5 },
} :: { [string]: any }

-- an insurer id, or VOS for anything else (an old save's insured item has no insurer: it was VOS's)
function T.insurerOf(isr: any): string
	return (type(isr) == "string" and T.INSURERS[isr]) and isr or "vos"
end

-- seconds: the fastest and slowest return and how long the messenger holds the items
function T.insureWindow(isr: string): (number, number, number)
	local e = T.INSURERS[T.insurerOf(isr)].eft
	local r, hold = 3600 / Config.INSURANCE_RETURN_DIV, 3600 / Config.INSURANCE_HOLD_DIV
	return e[1] * r, e[2] * r, e[3] * hold
end

-- the return window and the storage time as the screens show them: "2-3 H" and "24 H" (BRAM: "10-20 MIN")
function T.insureSpan(isr: string): (string, string)
	local lo, hi, hold = T.insureWindow(isr)
	local span = hi < 3600 and string.format("%d-%d MIN", math.floor(lo / 60), math.floor(hi / 60))
		or string.format("%d-%d H", math.floor(lo / 3600), math.floor(hi / 3600))
	return span, string.format("%d H", math.floor(hold / 3600))
end

-- what one item costs to insure with an insurer. Rounds in a magazine (or a gun's internal magazine) are not insured and
-- not paid for (EFT wiki: "If you insure a magazine with ammunition inside, you will only get the magazine back").
function T.insurePrice(isr: string, it: any): number
	local v = Items.valueOf(it)
	local ad = it.a and it.at and Items.defs[it.at]
	if ad then
		v -= it.a * ad.value
	end
	local base = math.max(Config.INSURANCE_MIN, math.floor(v * Config.INSURANCE_RATE))
	return math.floor(base * T.INSURERS[T.insurerOf(isr)].mul)
end

-- the bill for a list of items, Charisma's discount taken off the sum (Tarkov: 0.1 % a level; audit economy.6)
function T.insureTotal(isr: string, items: { any }, discount: number?): number
	local sum = 0
	for _, it in items do
		sum += T.insurePrice(isr, it)
	end
	return math.floor(sum * (1 - (discount or 0)))
end

-- ── HALE's treatment (EFT's Therapist, decision gameplay-6b) ───────────────────────────────────────────────────────
-- EFT wiki, Health system: out of raid the Therapist heals for 30 / 33 / 36 / 40.5 roubles a missing HP at her loyalty
-- levels 1-4, 750 a light bleed, 1,400 a heavy bleed and 1,350 a fracture, and for free for players at level 5 or below;
-- MK are close to roubles 1:1. EFT does not publish the price of restoring a destroyed part: ours is the part's missing HP
-- (all of it) at the per-HP price plus 2,500 MK.
T.TREATMENT = { trader = "hale", perHp = { 30, 33, 36, 40.5 }, light = 750, heavy = 1400, fracture = 1350, destroyed = 2500, freeLevel = 5 }
T.TREAT_PARTS = { "head", "thorax", "stomach", "larm", "rarm", "lleg", "rleg" }

-- state: { [part] = { hp, max, bleed = 0 | 1 | 2, fract } } with the numbers as the health screen shows them (hp rounded
-- up, max down; hp 0 = destroyed). Returns the bill, the lines ({ part, kind = "hp" | "destroyed" | "light" | "heavy" |
-- "fracture", hp = HP restored, cost }, in body order) and whether it is free (the lines keep their prices then).
function T.treatQuote(state: any, ll: number?, level: number?): (number, { any }, boolean)
	local tr = T.TREATMENT
	local per = tr.perHp[math.clamp(math.floor(ll or 1), 1, #tr.perHp)]
	local lines, total = {}, 0
	local function add(part: string, kind: string, hp: number, cost: number)
		cost = math.ceil(cost)
		table.insert(lines, { part = part, kind = kind, hp = hp, cost = cost })
		total += cost
	end
	for _, k in T.TREAT_PARTS do
		local s = state and state[k]
		if s then
			local max = math.floor(s.max or 0)
			local hp = math.clamp(math.ceil(s.hp or 0), 0, max)
			if max > 0 and hp <= 0 then
				add(k, "destroyed", max, max * per + tr.destroyed)
			elseif hp < max then
				add(k, "hp", max - hp, (max - hp) * per)
			end
			if s.bleed == 2 then
				add(k, "heavy", 0, tr.heavy)
			elseif s.bleed == 1 then
				add(k, "light", 0, tr.light)
			end
			if s.fract then
				add(k, "fracture", 0, tr.fracture)
			end
		end
	end
	local free = (level or 1) <= tr.freeLevel
	return free and 0 or total, lines, free
end

-- the trader paying the most for an item: id, price (the first in list order on a tie)
function T.bestBuyer(it: any, karma: number?): (string?, number?)
	local best, bestP = nil, nil
	for _, id in T.list do
		local p = T.sellPrice(id, it, karma)
		if p and (not bestP or p > bestP) then
			best, bestP = id, p
		end
	end
	return best, bestP
end

return T
