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
-- Standing comes from tasks, and EFT's standings assume 52 to 91 tasks a trader; we have a handful each. Until there are
-- enough tasks (decision economy-6a), each trader's standings are EFT's scaled so that LL4 needs exactly the standing all
-- that trader's tasks give (LL2 and LL3 keep EFT's share of LL4), rounded down to 0.01; once a trader's tasks give EFT's
-- LL4 standing or more, EFT's figures apply as they are. Player levels are EFT's, capped at our top level (EFT's Ragman
-- wants 42 for LL4; ours stops at 40). Money spent is still counted but asks nothing, as in EFT 1.1.0.
T.TASK_REP = {} :: { [string]: number } -- [trader] = standing all of its tasks give (QuestData rewards)
for _, q in QD.list do
	local r = q.reward and q.reward.rep
	if r and r > 0 then
		T.TASK_REP[q.trader] = (T.TASK_REP[q.trader] or 0) + r
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
-- M14: a gun sold as a build (Tarkov trader presets): the base item with the preset's parts and an empty magazine
local function pre(preset: string, ll: number, limit: number): any
	local pr = WP.META.presets[preset]
	return { id = pr.base, ll = ll, limit = limit, n = 1, preset = preset }
end
T.offers = {
	-- Prapor: "AK platform rifles, Russian ammunition, grenades" (tarkovforge): the Grach and the MP-133 from LL1, the AKM
	-- and its ammunition from LL2, rifle-cartridge and slug ammunition, a PSO-style 4x and a suppressor at LL3, AP rounds at LL4
	vos = {
		o("P9_PISTOL", 1, 2), o("HARROW12", 1, 2), o("P9_MAG", 1, 10), o("KST_MAG", 1, 6),
		o("A9_PST", 1, 10, 50), o("A12_BUCK", 1, 8, 20), o("GREN_RK5", 1, 4), o("GREN_SMOKE", 1, 3), o("FLARE_GREEN", 1, 2),
		o("KST_FH_SLANT", 1, 3), o("AK_PG_RUB", 1, 2), o("KST_HG_POLY", 1, 2),
		o("KST_RIFLE", 2, 1), o("KST_MAG_POLY", 2, 6), o("A76_PS", 2, 8, 60), o("GREN_STUN", 2, 3), o("GREN_F7", 2, 3),
		o("BRAKE_76", 2, 1), o("KST_STK_FOLD", 2, 1), o("P9_MAG33", 2, 3), pre("HAR_SHORT", 2, 1),
		o("A76L_LPS", 3, 4, 40), o("A12_SLUG", 3, 4, 20), o("SCOPE_4X", 3, 1), o("SUPP_76", 3, 1), o("KST_MAG40", 3, 3),
		o("A76_BP", 4, 3, 60), o("A76L_SNB", 4, 2, 40), pre("KST_QUIET", 4, 1),
		-- plates (gameplay-2a): EFT sells the Korund-VM plates at Prapor LL4 (tarkovforge); the PC-4's at LL2 (ours)
		o("PLATE_PC4F", 2, 2), o("PLATE_PC4B", 2, 2), o("PLATE_HP5F", 4, 1), o("PLATE_HP5B", 4, 1), o("PLATE_HP5S", 4, 2),
	},
	-- the Therapist: dressings and painkillers first, bigger kits and stimulants of their kind higher up
	hale = {
		o("BANDAGE", 1, 10), o("PAINKILLERS", 1, 5), o("MEDKIT_S", 1, 5), o("SPLINT", 1, 5), o("WATER", 1, 5), o("HARDTACK", 1, 5),
		o("TOURNIQUET", 2, 5), o("MEDKIT_M", 2, 4), o("STEW", 2, 5), o("VOLT_DRINK", 2, 3),
		o("HEMOSTAT", 3, 3), o("MEDKIT_L", 3, 2), o("ANTIDOTE", 3, 1),
		o("SURGKIT", 4, 1), o("MEDKIT_XL", 4, 1),
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
		o("NV_BINO", 2, 1), o("KST_DC_RAIL", 2, 1), o("KST_HG_RAIL", 2, 1), o("AK_PG_ERGO", 2, 2), o("GRIP_ANG", 2, 2),
		o("LASER_DOT", 2, 2), o("KST_MNT_SIDE", 2, 1), o("SPR_FH_3L", 2, 2),
		o("NV_MONO", 3, 1), o("SPARROW_SMG", 3, 1), o("KST_STK_TUBE", 3, 1), o("HAR_STK_TACT", 3, 1), pre("KST_TAC", 3, 1), pre("HAR_TAC", 3, 1),
		o("LASER_COMBO", 4, 1), pre("SPR_TAC", 4, 1),
	},
	-- the Peacekeeper: "NATO platform weapons, including M4 platform rifles and HK builds", "western optics", "western
	-- ammunition" (tarkovforge); the UN vest from LL1 (EFT's MF-UNTAR, which his Fishing Gear task asks for); the N-15 at LL3
	-- and the GPNVG-18 at LL4 (ggrecon): our G-15 and NV-4
	dekker = {
		o("R17_RIFLE", 1, 2), o("R17_MAG", 1, 10), o("A62_FMJ", 1, 10, 60), o("SPARROW_MAG", 1, 6), o("ARMOR_C3", 1, 1), o("GREN_RK5", 1, 2),
		o("SPARROW_SMG", 2, 1), o("R17_MAG40", 2, 3), o("A62_HP", 2, 6, 60), o("HOLO_EX", 2, 1), o("SUPP_9", 2, 1),
		o("NV_GREEN", 3, 1), o("A62_AP", 3, 4, 60), o("SCOPE_16", 3, 1), o("SUPP_62", 3, 1),
		o("NV_QUAD", 4, 1), o("R17_MAG60", 4, 2),
		-- western plates by loyalty (ours, gameplay-2a): class 3 polyethylene at LL1 up to class 5 side plates at LL3
		o("PLATE_PE3", 1, 2), o("PLATE_CE4", 2, 2), o("PLATE_PE4", 3, 1), o("PLATE_CE5S", 3, 2),
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
		o("MNT_RINGS", 3, 1), o("LASER_COMBO", 3, 1), o("SPR_GRIP_NAVY", 3, 1), o("SPR_MAG50", 3, 2), o("A9_AP", 3, 4, 50),
		pre("R17_CQB", 3, 1), pre("SPR_TAC", 3, 1),
		o("SCOPE_8X", 4, 1), pre("R17_DMR", 4, 1),
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
	},
	-- Jaeger: "bolt-action rifles and hunting shotguns", "medical supplies", "food", "wilderness gear" (tarkovforge); the
	-- shotgun, knife and basic supplies at LL1, the bolt rifle at LL2, its scope and rifle cartridges at LL3, its chassis,
	-- suppressor and marksman build at LL4; the T-7 thermals are his LL4 deal (ggrecon), as a barter
	bram = {
		o("HARROW12", 1, 2), o("A12_BUCK", 1, 8, 20), o("FIELD_KNIFE", 1, 3), o("BANDAGE", 1, 5), o("WATER", 1, 3), o("HARDTACK", 1, 5),
		o("HAR_FE_POLY", 1, 2), o("HAR_STK_PG", 1, 1),
		o("TUNDRA_BOLT", 2, 1), o("A12_SLUG", 2, 4, 20), o("TUN_MNT_SCOUT", 2, 1), o("TUN_STK_SPORT", 2, 1), o("HAR_FE_RAIL", 2, 1),
		o("HAR_BRK", 2, 1), o("HAR_CHOKE", 2, 1), o("HAR_BRL_14", 2, 1), o("HAR_TUBE_4", 2, 1), o("SPLINT", 2, 3), o("STEW", 2, 3),
		o("A76L_LPS", 3, 4, 40), o("TUN_MNT_SIDE", 3, 1), o("TUN_BRK", 3, 1), o("HAR_BRL_20", 3, 1), o("HAR_TUBE_8", 3, 1),
		o("SCOPE_4X", 3, 1), o("MEDKIT_M", 3, 2), o("JUICE", 3, 3), pre("TUN_SCOUT", 3, 1),
		o("SUPP_76L", 4, 1), o("TUN_STK_CHAS", 4, 1), pre("TUN_MARKSMAN", 4, 1),
	},
}

-- barter trades: get `id` for the items in `give` ({ id, n })
local function b(id: string, ll: number, limit: number, give: { any }): any
	return { id = id, ll = ll, limit = limit, give = give }
end
T.barters = {
	vos = {
		b("KST_RIFLE", 1, 1, { { "CAPACITOR", 1 }, { "LOGIC_BOARD", 1 } }),
		b("GREN_F7", 1, 2, { { "BOLTS", 1 }, { "MATCHES", 2 } }),
		b("SCOPE_4X", 2, 1, { { "CRACKED_LENS", 1 }, { "WIRES", 2 } }),
	},
	hale = {
		b("MEDKIT_M", 1, 3, { { "CIGARETTES", 2 }, { "MATCHES", 1 } }),
		b("HEMOSTAT", 2, 2, { { "MED_TOOLS", 1 } }),
		b("SURGKIT", 3, 1, { { "MED_TOOLS", 1 }, { "CAPT_WATCH", 1 } }),
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
