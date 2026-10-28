--!strict
-- Traders (original characters, Tarkov rules): loyalty levels gate what they sell; each trader buys certain kinds
-- of items at a share of their value; barter trades swap items for items; stock is limited per restock window.
-- Shared so the client shows exactly the prices the server charges (server truth: Economy.luau).
local Items = require(script.Parent.Items)

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
		desc = "Stitches, sells and fits armour, helmets, rigs and packs.",
		buys = { armor = 0.55, helmet = 0.55, rig = 0.55, backpack = 0.55, headwear = 0.5, headset = 0.55, facecover = 0.5 },
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
T.offers = {
	vos = {
		o("R17_RIFLE", 1, 2), o("P9_PISTOL", 1, 2), o("HARROW12", 1, 2), o("SPARROW_SMG", 1, 1), o("FIELD_KNIFE", 1, 3),
		o("R17_MAG", 1, 10), o("P9_MAG", 1, 10), o("SPARROW_MAG", 1, 6),
		o("A62_FMJ", 1, 10, 60), o("A9_PST", 1, 10, 50), o("A12_BUCK", 1, 8, 20),
		o("RED_DOT", 1, 1), o("GRIP_V", 1, 2), o("LIGHT_T", 1, 2), o("GREN_RK5", 1, 4), o("GREN_SMOKE", 1, 3),
		o("KST_RIFLE", 2, 1), o("KST_MAG", 2, 6), o("A76_PS", 2, 8, 60), o("A62_HP", 2, 6, 60), o("R17_MAG40", 2, 3),
		o("SUPP_9", 2, 1), o("BRAKE_76", 2, 1), o("GREN_STUN", 2, 3), o("GREN_F7", 2, 3), o("WEAPON_KIT", 2, 1),
		o("TUNDRA_BOLT", 3, 1), o("A76L_LPS", 3, 4, 40), o("A62_AP", 3, 4, 60), o("A9_AP", 3, 4, 50), o("A12_SLUG", 3, 4, 20),
		o("SUPP_62", 3, 1), o("SCOPE_4X", 3, 1),
		o("A76_BP", 4, 3, 60), o("A76L_SNB", 4, 2, 40),
	},
	hale = {
		o("BANDAGE", 1, 10), o("PAINKILLERS", 1, 5), o("MEDKIT_S", 1, 5), o("SPLINT", 1, 5), o("WATER", 1, 5), o("HARDTACK", 1, 5),
		o("TOURNIQUET", 2, 5), o("MEDKIT_M", 2, 4), o("STEW", 2, 5), o("VOLT_DRINK", 2, 3),
		o("HEMOSTAT", 3, 3), o("MEDKIT_L", 3, 2),
		o("SURGKIT", 4, 1), o("MEDKIT_XL", 4, 1),
	},
	tilda = {
		o("RIG_BELT", 1, 3), o("BAG_SLING", 1, 3), o("ARMOR_C2", 1, 2), o("HELMET_C2", 1, 2),
		o("CAP_FIELD", 1, 3), o("BEANIE", 1, 3), o("GAITER", 1, 3), o("HEADSET_GS1", 2, 1), o("HEADSET_COMM", 3, 1),
		o("RIG_CHEST", 2, 2), o("CANVAS_BAG", 2, 2), o("ARMOR_C3", 2, 2), o("HELMET_C3", 2, 1),
		o("BAG_PATROL", 3, 1), o("ARMOR_C4", 3, 1), o("HELMET_C4", 3, 1), o("RIG_PLATE", 3, 1),
		o("BAG_RAID", 4, 1), o("ARMOR_C5", 4, 1),
	},
	fence = {
		o("RIG_BELT", 1, 2), o("BAG_SLING", 1, 2), o("BANDAGE", 1, 4), o("R17_MAG", 1, 4), o("A62_FMJ", 1, 4, 60), o("KEY_OFFICE", 1, 1),
		o("KEY_DORM_104", 1, 1), o("KEY_DORM_203", 2, 1), o("GREN_RK5", 1, 2), o("KEY_SMELT_OFFICE", 1, 1),
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

-- price of one purchase at a loyalty level (each level is 5% cheaper)
function T.price(traderId: string, offer: any, ll: number): number
	local d = Items.defs[offer.id]
	local tr = T.defs[traderId]
	return math.max(1, math.ceil(d.value * (offer.n or 1) * tr.markup * (1 - 0.05 * (math.max(1, ll) - 1))))
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
