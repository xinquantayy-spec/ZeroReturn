--!strict
-- Traders (original characters, Tarkov rules): loyalty levels gate what they sell; each trader buys certain kinds
-- of items at a share of their value; barter trades swap items for items; stock is limited per restock window.
-- Shared so the client shows exactly the prices the server charges (server truth: Economy.luau).
local Items = require(script.Parent.Items)
local WP = require(script.Parent.WeaponParts)

local T = {}

T.RESTOCK = 1800 -- seconds between restocks (per player purchase limits reset)

T.list = { "vos", "hale", "tilda", "fence" }
T.defs = {
	vos = {
		name = "VOS", title = "Quartermaster", markup = 1.25,
		desc = "Ex-harbour armourer. Sells weapons, magazines, ammunition, attachments and grenades; repairs weapons.",
		buys = { weapon = 0.55, pistol = 0.55, melee = 0.5, mod = 0.55, mag = 0.5, ammo = 0.5, key = 0.5, grenade = 0.5, repair = 0.5 },
	},
	hale = {
		name = "HALE", title = "Field Medic", markup = 1.2,
		desc = "Runs the relay's aid station. Medicine, food, and a soft spot for valuables.",
		buys = { med = 0.55, food = 0.5, loot = 0.5 },
	},
	tilda = {
		name = "TILDA", title = "Outfitter", markup = 1.25,
		desc = "Stitches, sells and fits armour, helmets, rigs, packs, eyewear and night vision.",
		buys = { armor = 0.55, helmet = 0.55, rig = 0.55, backpack = 0.55, headwear = 0.5, headset = 0.55, facecover = 0.5, eyewear = 0.5 },
	},
	fence = {
		name = "FENCE", title = "Fence", markup = 1.7,
		desc = "Buys anything, no questions. Remembers how you treat the locals.",
		buys = "*", buyRate = 0.4,
	},
}

-- loyalty level requirements (LL1 is free)
T.LL = {
	{ level = 1, spent = 0, rep = 0 },
	{ level = 3, spent = 150000, rep = 0.15 },
	{ level = 7, spent = 500000, rep = 0.35 },
	{ level = 12, spent = 1200000, rep = 0.6 },
}

-- offers: id, loyalty level, limit per restock, n = stack per purchase (ammo), a = rounds in a sold magazine
local function o(id: string, ll: number, limit: number, n: number?): any
	return { id = id, ll = ll, limit = limit, n = n or 1 }
end
-- M14: a gun sold as a build (Tarkov trader presets): the base item with the preset's parts and an empty magazine
local function pre(preset: string, ll: number, limit: number): any
	local pr = WP.META.presets[preset]
	return { id = pr.base, ll = ll, limit = limit, n = 1, preset = preset }
end
T.offers = {
	vos = {
		o("R17_RIFLE", 1, 2), o("P9_PISTOL", 1, 2), o("HARROW12", 1, 2), o("SPARROW_SMG", 1, 1), o("FIELD_KNIFE", 1, 3),
		o("R17_MAG", 1, 10), o("P9_MAG", 1, 10), o("SPARROW_MAG", 1, 6),
		o("A62_FMJ", 1, 10, 60), o("A9_PST", 1, 10, 50), o("A12_BUCK", 1, 8, 20),
		o("RED_DOT", 1, 1), o("GRIP_V", 1, 2), o("LIGHT_T", 1, 2), o("GREN_RK5", 1, 4), o("GREN_SMOKE", 1, 3), o("FLARE_GREEN", 1, 2),
		o("KST_RIFLE", 2, 1), o("KST_MAG", 2, 6), o("A76_PS", 2, 8, 60), o("A62_HP", 2, 6, 60), o("R17_MAG40", 2, 3),
		o("SUPP_9", 2, 1), o("BRAKE_76", 2, 1), o("GREN_STUN", 2, 3), o("GREN_F7", 2, 3), o("WEAPON_KIT", 2, 1),
		-- Tarkov's Jaeger sells the tripwire kit at LL3 after his task chain (no Jaeger here, no task gate)
		o("TRIPWIRE_KIT", 3, 2),
		o("TUNDRA_BOLT", 3, 1), o("A76L_LPS", 3, 4, 40), o("A62_AP", 3, 4, 60), o("A9_AP", 3, 4, 50), o("A12_SLUG", 3, 4, 20),
		o("SUPP_62", 3, 1), o("SCOPE_4X", 3, 1),
		o("A76_BP", 4, 3, 60), o("A76L_SNB", 4, 2, 40),
		-- M14 weapon parts and builds (Tarkov: the gunsmith's assortment grows with loyalty)
		o("GRIP_STOP", 1, 3), o("R17_FH_A2", 1, 3), o("KST_FH_SLANT", 1, 3), o("SPR_FH_3L", 1, 2), o("AR_PG_ERGO", 1, 2),
		o("AK_PG_RUB", 1, 2), o("MNT_RISER", 1, 3), o("R17_RS_FLIP", 1, 2), o("R17_FS_FLIP", 1, 2), o("AR_STK_CARB", 1, 2),
		o("KST_HG_POLY", 1, 2), o("HAR_FE_POLY", 1, 2), o("HAR_STK_PG", 1, 1), o("P9_BRL_THR", 1, 2), o("KST_MAG_POLY", 1, 6),
		o("R17_HG_QUAD", 2, 2), o("R17_COMP", 2, 2), o("R17_BRK", 2, 2), o("KST_DC_RAIL", 2, 1), o("KST_MNT_SIDE", 2, 1),
		o("KST_HG_RAIL", 2, 1), o("SPR_HG_TRI", 2, 1), o("SPR_MNT_CLAW", 2, 1), o("GRIP_ANG", 2, 2), o("GRIP_STUB", 2, 2),
		o("LASER_DOT", 2, 2), o("HOLO_EX", 2, 1), o("SIGHT_MICRO", 2, 1), o("AR_CH_EXT", 2, 2), o("AR_PG_ANG", 2, 2),
		o("AK_PG_ERGO", 2, 2), o("KST_STK_FOLD", 2, 1), o("SPR_STK_FIXED", 2, 1), o("HAR_FE_RAIL", 2, 1), o("HAR_BRK", 2, 1),
		o("HAR_CHOKE", 2, 1), o("TUN_MNT_SCOUT", 2, 1), o("P9_SLIDE_CUT", 2, 1), o("P9_COMP", 2, 1), o("R17_BRL_105", 2, 1),
		o("HAR_BRL_14", 2, 1), o("HAR_TUBE_4", 2, 1), o("KST_MAG40", 2, 3), o("P9_MAG33", 2, 3),
		pre("R17_PATROL", 2, 1), pre("HAR_SHORT", 2, 1), pre("P9_TAC", 2, 1),
		o("R17_HG_MLOK", 3, 1), o("R17_GAS_LOW", 3, 2), o("R17_BRL_18", 3, 1), o("SUPP_62C", 3, 1), o("SUPP_76", 3, 1),
		o("AR_STK_SKEL", 3, 1), o("KST_STK_TUBE", 3, 1), o("HAR_STK_TACT", 3, 1), o("HAR_BRL_20", 3, 1), o("HAR_TUBE_8", 3, 1),
		o("TUN_STK_SPORT", 3, 1), o("TUN_MNT_SIDE", 3, 1), o("TUN_BRK", 3, 1), o("MNT_RINGS", 3, 1), o("SCOPE_16", 3, 1),
		o("LASER_COMBO", 3, 1), o("SPR_GRIP_NAVY", 3, 1), o("SPR_MAG50", 3, 2),
		pre("KST_TAC", 3, 1), pre("SPR_TAC", 3, 1), pre("HAR_TAC", 3, 1), pre("TUN_SCOUT", 3, 1), pre("R17_CQB", 3, 1), pre("KST_QUIET", 3, 1),
		o("SCOPE_8X", 4, 1), o("SUPP_76L", 4, 1), o("TUN_STK_CHAS", 4, 1), o("R17_MAG60", 4, 2),
		pre("R17_DMR", 4, 1), pre("TUN_MARKSMAN", 4, 1),
	},
	hale = {
		o("BANDAGE", 1, 10), o("PAINKILLERS", 1, 5), o("MEDKIT_S", 1, 5), o("SPLINT", 1, 5), o("WATER", 1, 5), o("HARDTACK", 1, 5),
		o("TOURNIQUET", 2, 5), o("MEDKIT_M", 2, 4), o("STEW", 2, 5), o("VOLT_DRINK", 2, 3),
		o("HEMOSTAT", 3, 3), o("MEDKIT_L", 3, 2), o("ANTIDOTE", 3, 1),
		o("SURGKIT", 4, 1), o("MEDKIT_XL", 4, 1),
	},
	tilda = {
		o("RIG_BELT", 1, 3), o("BAG_SLING", 1, 3), o("ARMOR_C2", 1, 2), o("HELMET_C2", 1, 2),
		o("CAP_FIELD", 1, 3), o("BEANIE", 1, 3), o("GAITER", 1, 3), o("HEADSET_GS1", 2, 1), o("HEADSET_COMM", 3, 1),
		o("RIG_CHEST", 2, 2), o("CANVAS_BAG", 2, 2), o("ARMOR_C3", 2, 2), o("HELMET_C3", 2, 1),
		o("BAG_PATROL", 3, 1), o("ARMOR_C4", 3, 1), o("HELMET_C4", 3, 1), o("RIG_PLATE", 3, 1),
		o("BAG_RAID", 4, 1), o("ARMOR_C5", 4, 1),
		-- goggles (Tarkov: the cheap binoculars early, the monocular later, panoramic and thermal at the top)
		o("NV_STRAP", 1, 2), o("NV_BINO", 2, 1), o("NV_GREEN", 3, 1), o("NV_MONO", 3, 1), o("NV_QUAD", 4, 1), o("TH_T7", 4, 1),
		-- eyewear (Tarkov: the outfitter's plain glasses from LL1, the shooting glasses at LL3, ballistic glasses at LL3-4; gas masks
		-- are not sold for cash)
		o("GLASSES_SUN", 1, 3), o("GLASSES_RANGE", 3, 2), o("GLASSES_BG1", 3, 1), o("GLASSES_AF2", 4, 1),
	},
	fence = {
		o("RIG_BELT", 1, 2), o("BAG_SLING", 1, 2), o("BANDAGE", 1, 4), o("R17_MAG", 1, 4), o("A62_FMJ", 1, 4, 60), o("KEY_OFFICE", 1, 1),
		o("KEY_DORM_104", 1, 1), o("KEY_DORM_203", 2, 1), o("GREN_RK5", 1, 2), o("KEY_SMELT_OFFICE", 1, 1),
		o("MULTITOOL", 1, 1),
	},
}

-- barter trades: get `id` for the items in `give` ({ id, n })
local function b(id: string, ll: number, limit: number, give: { any }): any
	return { id = id, ll = ll, limit = limit, give = give }
end
T.barters = {
	vos = {
		b("R17_MAG40", 1, 2, { { "BOLTS", 2 }, { "SPARK_PLUG", 1 } }),
		b("KST_RIFLE", 1, 1, { { "CAPACITOR", 1 }, { "LOGIC_BOARD", 1 } }),
		b("SUPP_62", 2, 1, { { "SIGNAL_COIL", 2 }, { "CERAMIC_FUSE", 2 }, { "DUCT_TAPE", 1 } }),
		b("SCOPE_4X", 2, 1, { { "CRACKED_LENS", 1 }, { "WIRES", 2 } }),
		b("GREN_F7", 1, 2, { { "BOLTS", 1 }, { "MATCHES", 2 } }),
		b("WEAPON_KIT", 1, 1, { { "DUCT_TAPE", 2 }, { "SPARK_PLUG", 1 }, { "WIRES", 1 } }),
	},
	hale = {
		b("MEDKIT_M", 1, 3, { { "CIGARETTES", 2 }, { "MATCHES", 1 } }),
		b("HEMOSTAT", 2, 2, { { "MED_TOOLS", 1 } }),
		b("SURGKIT", 3, 1, { { "MED_TOOLS", 1 }, { "CAPT_WATCH", 1 } }),
	},
	tilda = {
		b("ARMOR_C3", 1, 1, { { "DUCT_TAPE", 2 }, { "WIRES", 2 }, { "BOLTS", 1 } }),
		b("ARMOR_C4", 2, 1, { { "GOLD_CHAIN", 1 }, { "WIRES", 2 }, { "DUCT_TAPE", 2 } }),
		b("BAG_RAID", 3, 1, { { "DECK_TRANSCEIVER", 1 }, { "FUEL_CAN", 1 }, { "GOLD_CHAIN", 1 } }),
	},
	fence = {},
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

-- price of one purchase at a loyalty level (each level is 5% cheaper)
function T.price(traderId: string, offer: any, ll: number, discount: number?): number
	local d = Items.defs[offer.id]
	local tr = T.defs[traderId]
	local value = WP.isBase(offer.id) and T.buildValue(offer.id, offer.preset) or d.value
	-- discount: Charisma (Tarkov: better trader prices with the skill)
	return math.max(1, math.ceil(value * (offer.n or 1) * tr.markup * (1 - 0.05 * (math.max(1, ll) - 1)) * (1 - (discount or 0))))
end

-- what a trader pays for an item instance (nil = not interested). Fence pays less with bad karma.
function T.sellPrice(traderId: string, it: any, karma: number?): number?
	local d = Items.defs[it.id]
	local tr = T.defs[traderId]
	if not d or it.rk or d.kind == "quest" or d.kind == "secure" then
		return nil
	end
	local rate
	if tr.buys == "*" then
		rate = (tr.buyRate or 0.4) * (1 + 0.04 * math.clamp(karma or 0, -3, 3))
	else
		rate = (tr.buys :: any)[d.kind]
	end
	if not rate then
		return nil
	end
	return math.floor(Items.valueOf(it) * rate)
end

-- ── repairs (Tarkov: traders restore condition, but every repair costs some maximum durability) ───────────────
-- VOS repairs weapons, TILDA armour, helmets and ballistic glasses; the repair kit works on weapons out of raid with less wear.
T.REPAIRS = {
	vos = { kinds = { weapon = true, pistol = true }, rate = 0.004 },
	tilda = { kinds = { armor = true, helmet = true, rig = true, eyewear = true }, rate = 0.4 }, -- plain glasses have no durability: nothing to repair
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

-- a trader's repair of an item: points restored, cost, the new maximum (nil = nothing to repair / not theirs)
function T.repairQuote(traderId: string, it: any): (number?, number?, number?)
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
		cost = math.ceil(pts / design * d.value * r.rate)
	else
		cost = math.ceil(pts * d.value * r.rate)
	end
	return pts, math.max(1, cost), math.max(1, max - pts * deg)
end

-- the trader paying the most for an item: id, price
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
