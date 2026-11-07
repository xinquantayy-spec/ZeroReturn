--!nonstrict
-- World loot (Tarkov-style): containers are real inventory holders with grids. Opening one starts a
-- progressive search that reveals contents one item at a time (per player, resumable). Bodies expose their
-- equipment; their pockets/rig/backpack are searched the same way. Dropped gear forms ground piles.
-- All moves go through Raid.inv (holder refs "c:<cid>"); this module owns access checks and views.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Progress = require(Shared.Progress)
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local GunBuild = require(Shared.GunBuild)
local Inv = require(script.Parent.Inv)
local WP = require(Shared.WeaponParts)

local Loot = {}
local ctx
local containers = {}
local pileN = 0
Loot.containers = containers

-- container kinds: grid size + loot pool
local KINDS = {
	crate = { w = 5, h = 4, count = { 2, 5 }, pool = "crate" },
	locker = { w = 4, h = 5, count = { 2, 4 }, pool = "locker" },
	drawer = { w = 3, h = 2, count = { 1, 3 }, pool = "drawer" },
	medbag = { w = 4, h = 3, count = { 2, 4 }, pool = "medbag" },
	weaponbox = { w = 6, h = 4, count = { 1, 3 }, pool = "weaponbox" },
	toolbox = { w = 4, h = 3, count = { 2, 4 }, pool = "toolbox" },
	jacket = { w = 2, h = 2, count = { 0, 2 }, pool = "jacket" },
	safe = { w = 3, h = 3, count = { 1, 3 }, pool = "safe" },
	-- M13 Meridian Mall
	register = { w = 2, h = 2, count = { 0, 2 }, pool = "register" },
	techbox = { w = 4, h = 3, count = { 1, 3 }, pool = "tech" },
	pharmacy = { w = 4, h = 3, count = { 2, 4 }, pool = "pharmacy" },
	grocery = { w = 4, h = 3, count = { 1, 4 }, pool = "grocery" },
	cooler = { w = 3, h = 3, count = { 1, 3 }, pool = "drinks" },
}
Loot.KINDS = KINDS

-- weighted pools: n = stack range, a = rounds range (for mags: ammo type from `at`)
local POOLS = {
	crate = {
		{ id = "BOLTS", w = 14 }, { id = "DUCT_TAPE", w = 12 }, { id = "WIRES", w = 12 }, { id = "SPARK_PLUG", w = 10 },
		{ id = "SIGNAL_COIL", w = 10 }, { id = "CERAMIC_FUSE", w = 10 }, { id = "A62_FMJ", w = 10, n = { 20, 45 } },
		{ id = "A76_PS", w = 6, n = { 15, 40 } }, { id = "CAPACITOR", w = 6 }, { id = "BATTERY", w = 4 },
		{ id = "FUEL_CAN", w = 3 }, { id = "DECK_TRANSCEIVER", w = 3 }, { id = "R17_MAG", w = 4, a = { 0, 25 }, at = "A62_FMJ" },
		{ id = "GREN_RK5", w = 3 }, { id = "GREN_SMOKE", w = 2 }, { id = "GLASSES_RANGE", w = 2 }, { id = "GAS_MASK", w = 1 },
		{ id = "FLARE_RED", w = 1.2 },
		{ id = "FLARE_GREEN", w = 1.6 },
	},
	locker = {
		{ id = "CIGARETTES", w = 12 }, { id = "MATCHES", w = 10 }, { id = "BANDAGE", w = 12 }, { id = "WATER", w = 8 },
		{ id = "HARDTACK", w = 8 }, { id = "A9_PST", w = 10, n = { 10, 35 } }, { id = "P9_MAG", w = 5, a = { 0, 17 }, at = "A9_PST" },
		{ id = "OLD_COIN", w = 5 }, { id = "KEY_OFFICE", w = 3 }, { id = "HELMET_C2", w = 3 }, { id = "RIG_BELT", w = 3 },
		{ id = "BAG_SLING", w = 3 }, { id = "GOLD_CHAIN", w = 2 }, { id = "CAPT_WATCH", w = 1 }, { id = "KEY_DORM_104", w = 2 },
		{ id = "CAP_FIELD", w = 3 }, { id = "BEANIE", w = 3 }, { id = "GAITER", w = 3 }, { id = "HEADSET_GS1", w = 1 },
		{ id = "GLASSES_SUN", w = 2 }, { id = "GLASSES_RANGE", w = 1 }, { id = "GAS_MASK", w = 1 },
		{ id = "GREN_RK5", w = 2 }, { id = "GREN_SMOKE", w = 2 },
	},
	drawer = {
		{ id = "CIGARETTES", w = 12 }, { id = "MATCHES", w = 12 }, { id = "OLD_COIN", w = 8 }, { id = "FLASH_MODULE", w = 4 },
		{ id = "INTEL_FOLDER", w = 3 }, { id = "KEY_OFFICE", w = 5 }, { id = "RUSTED_KEYCARD", w = 1 }, { id = "SEALED_DRIVE", w = 2 },
		{ id = "GOLD_CHAIN", w = 3 }, { id = "PAINKILLERS", w = 6 },
		{ id = "KEY_MM_BOLT_OFFICE", w = 1 }, { id = "KEY_MM_BOLT_GOODS", w = 1 }, { id = "KEY_MM_IRON_GRATE", w = 0.4 },
	},
	medbag = {
		{ id = "BANDAGE", w = 20 }, { id = "TOURNIQUET", w = 12 }, { id = "SPLINT", w = 12 }, { id = "PAINKILLERS", w = 12 },
		{ id = "MEDKIT_S", w = 12 }, { id = "MEDKIT_M", w = 8 }, { id = "HEMOSTAT", w = 5 }, { id = "MEDKIT_L", w = 3 },
		{ id = "MED_TOOLS", w = 4 }, { id = "SURGKIT", w = 1 }, { id = "MEDKIT_XL", w = 1 }, { id = "GAS_MASK", w = 1 },
	},
	weaponbox = {
		{ id = "A62_FMJ", w = 14, n = { 30, 60 } }, { id = "A62_AP", w = 4, n = { 15, 40 } }, { id = "A76_PS", w = 10, n = { 30, 60 } },
		{ id = "A76_BP", w = 2, n = { 10, 30 } }, { id = "A9_PST", w = 10, n = { 25, 50 } }, { id = "A12_BUCK", w = 8, n = { 8, 20 } },
		{ id = "A12_SLUG", w = 4, n = { 5, 15 } }, { id = "A76L_LPS", w = 4, n = { 10, 30 } }, { id = "R17_MAG", w = 8, a = { 0, 25 }, at = "A62_FMJ" },
		{ id = "KST_MAG", w = 6, a = { 0, 30 }, at = "A76_PS" }, { id = "SPARROW_MAG", w = 5, a = { 0, 30 }, at = "A9_PST" },
		{ id = "P9_PISTOL", w = 4 }, { id = "SPARROW_SMG", w = 2 }, { id = "HARROW12", w = 2 }, { id = "KST_RIFLE", w = 1 },
		{ id = "GREN_RK5", w = 6 }, { id = "GREN_F7", w = 2 }, { id = "GREN_STUN", w = 3 }, { id = "GREN_SMOKE", w = 4 },
		-- night vision (Tarkov: weapon boxes and tech crates hold goggles now and then) and ballistic eyewear
		{ id = "NV_BINO", w = 1 }, { id = "NV_GREEN", w = 0.5 }, { id = "NV_STRAP", w = 1 },
		{ id = "GLASSES_BG1", w = 1 }, { id = "GLASSES_AF2", w = 0.5 }, { id = "GAS_MASK", w = 0.5 },
		-- M14 weapon parts (Tarkov weapon boxes hold mods too)
		{ id = "GRIP_V", w = 3 }, { id = "GRIP_STUB", w = 2 }, { id = "GRIP_ANG", w = 1 }, { id = "LIGHT_T", w = 3 }, { id = "LASER_DOT", w = 2 },
		{ id = "RED_DOT", w = 2 }, { id = "SIGHT_MICRO", w = 1 }, { id = "MNT_RISER", w = 2 }, { id = "R17_FH_A2", w = 3 }, { id = "R17_COMP", w = 2 },
		{ id = "KST_FH_SLANT", w = 3 }, { id = "AR_PG_ERGO", w = 2 }, { id = "AK_PG_RUB", w = 2 }, { id = "R17_HG_QUAD", w = 1 },
		{ id = "KST_HG_POLY", w = 1 }, { id = "AR_STK_CARB", w = 2 }, { id = "KST_STK_FOLD", w = 1 }, { id = "R17_MAG40", w = 1, a = { 0, 40 }, at = "A62_FMJ" },
		{ id = "KST_MAG_POLY", w = 2, a = { 0, 30 }, at = "A76_PS" }, { id = "P9_MAG33", w = 1, a = { 0, 33 }, at = "A9_PST" },
		{ id = "FLARE_RED", w = 1 },
		{ id = "FLARE_GREEN", w = 1.2 },
	},
	toolbox = {
		{ id = "BOLTS", w = 16 }, { id = "DUCT_TAPE", w = 14 }, { id = "WIRES", w = 12 }, { id = "SPARK_PLUG", w = 12 },
		{ id = "CAPACITOR", w = 6 }, { id = "LOGIC_BOARD", w = 4 }, { id = "MIL_CIRCUIT", w = 1 }, { id = "WEAPON_KIT", w = 2 },
		{ id = "MULTITOOL", w = 3 }, { id = "AR_CH_EXT", w = 1 }, { id = "R17_GAS_LOW", w = 1 }, { id = "GAS_MASK", w = 1 },
		{ id = "FLARE_RED", w = 0.6 },
		{ id = "FLARE_GREEN", w = 0.9 },
	},
	jacket = {
		{ id = "CIGARETTES", w = 14 }, { id = "MATCHES", w = 12 }, { id = "KEY_OFFICE", w = 4 }, { id = "OLD_COIN", w = 4 },
		{ id = "A62_FMJ", w = 6, n = { 5, 20 } }, { id = "PAINKILLERS", w = 4 }, { id = "RUSTED_KEYCARD", w = 1 },
		{ id = "KEY_DORM_104", w = 3 }, { id = "KEY_DORM_203", w = 1 }, { id = "GREN_RK5", w = 1 },
		{ id = "GLASSES_SUN", w = 2 }, { id = "GLASSES_RANGE", w = 1 },
		{ id = "KEY_MALL_SECURITY", w = 1 }, { id = "KEY_MM_RESCUE", w = 1 }, { id = "KEY_MM_IRON_FRONT", w = 0.5 },
		{ id = "FLARE_RED", w = 0.6 },
		{ id = "FLARE_GREEN", w = 0.9 },
	},
	safe = {
		{ id = "GOLD_CHAIN", w = 10 }, { id = "CAPT_WATCH", w = 6 }, { id = "FLASH_MODULE", w = 6 }, { id = "INTEL_FOLDER", w = 5 },
		{ id = "COLD_WALLET", w = 2 }, { id = "OLD_COIN", w = 10 }, { id = "RUSTED_KEYCARD", w = 1 },
	},
	-- loose loot (M10): what lies around in the open, in the dorm rooms, the office and the vault
	junk = {
		{ id = "BOLTS", w = 12 }, { id = "WIRES", w = 10 }, { id = "DUCT_TAPE", w = 10 }, { id = "SPARK_PLUG", w = 8 },
		{ id = "CIGARETTES", w = 10 }, { id = "MATCHES", w = 9 }, { id = "WATER", w = 5 }, { id = "HARDTACK", w = 6 },
		{ id = "BANDAGE", w = 6 }, { id = "A62_FMJ", w = 6, n = { 5, 20 } }, { id = "A9_PST", w = 6, n = { 5, 20 } },
		{ id = "A12_BUCK", w = 4, n = { 3, 8 } }, { id = "BATTERY", w = 3 }, { id = "OLD_COIN", w = 3 }, { id = "CAPACITOR", w = 3 },
		{ id = "SIGNAL_COIL", w = 4 }, { id = "CERAMIC_FUSE", w = 4 },
	},
	dorm = {
		{ id = "CIGARETTES", w = 10 }, { id = "MATCHES", w = 8 }, { id = "OLD_COIN", w = 8 }, { id = "PAINKILLERS", w = 6 },
		{ id = "MEDKIT_S", w = 4 }, { id = "WATER", w = 6 }, { id = "STEW", w = 5 }, { id = "VOLT_DRINK", w = 2 },
		{ id = "CAPT_WATCH", w = 2 }, { id = "GOLD_CHAIN", w = 2 }, { id = "FLASH_MODULE", w = 3 }, { id = "INTEL_FOLDER", w = 2 },
		{ id = "LOGIC_BOARD", w = 2 }, { id = "P9_MAG", w = 3, a = { 0, 17 }, at = "A9_PST" }, { id = "A9_PST", w = 5, n = { 10, 30 } },
		{ id = "BATTERY", w = 2 }, { id = "P9_PISTOL", w = 1 }, { id = "GREN_RK5", w = 2 }, { id = "GREN_STUN", w = 1 },
	},
	dorm_good = {
		{ id = "GOLD_CHAIN", w = 8 }, { id = "CAPT_WATCH", w = 6 }, { id = "FLASH_MODULE", w = 6 }, { id = "INTEL_FOLDER", w = 5 },
		{ id = "SEALED_DRIVE", w = 2 }, { id = "LOGIC_BOARD", w = 5 }, { id = "MIL_CIRCUIT", w = 2 }, { id = "COLD_WALLET", w = 1 },
		{ id = "OLD_COIN", w = 6 }, { id = "MEDKIT_M", w = 4 }, { id = "HEMOSTAT", w = 2 }, { id = "RUSTED_KEYCARD", w = 1 },
	},
	office = {
		{ id = "INTEL_FOLDER", w = 6 }, { id = "FLASH_MODULE", w = 5 }, { id = "SEALED_DRIVE", w = 2 }, { id = "CIGARETTES", w = 6 },
		{ id = "OLD_COIN", w = 5 }, { id = "BATTERY", w = 3 }, { id = "CAPT_WATCH", w = 2 },
	},
	vault = {
		{ id = "GOLD_CHAIN", w = 8 }, { id = "BRASS_LION", w = 3 }, { id = "COLD_WALLET", w = 3 }, { id = "MIL_CIRCUIT", w = 4 },
		{ id = "SEALED_DRIVE", w = 5 }, { id = "INTEL_FOLDER", w = 6 }, { id = "CAPT_WATCH", w = 6 }, { id = "LEDGER", w = 2 },
		{ id = "FLASH_MODULE", w = 5 }, { id = "GREN_F7", w = 2 }, { id = "TH_T7", w = 0.3 }, { id = "NV_QUAD", w = 0.6 },
	},
	keys = {
		{ id = "KEY_DORM_104", w = 6 }, { id = "KEY_DORM_203", w = 4 }, { id = "KEY_OFFICE", w = 5 }, { id = "RUSTED_KEYCARD", w = 1 },
		{ id = "KEY_SMELT_OFFICE", w = 5 }, { id = "KEY_MALL_STAFF", w = 3 }, { id = "KEY_MEDIQ", w = 2 }, { id = "KEY_MALL_SECURITY", w = 1 },
		{ id = "KEY_BY_314", w = 3 }, { id = "KEY_BY_RECORDS", w = 4 }, { id = "KEY_BY_BOILER", w = 2 },
		{ id = "KEY_BY_K11", w = 1.5 }, { id = "KEY_BY_STORE", w = 4 }, { id = "KEY_BY_RED", w = 3 }, { id = "KEY_BY_BASTION", w = 1.5 }, { id = "KEY_BY_MOTOR", w = 4 },
		{ id = "KEY_BY_A103", w = 1.5 }, { id = "KEY_BY_A125", w = 1.5 }, { id = "KEY_BY_A128", w = 1.5 }, { id = "KEY_BY_A201", w = 1.5 },
		{ id = "KEY_BY_A212", w = 1.5 }, { id = "KEY_BY_A225", w = 1.5 }, { id = "KEY_BY_A228", w = 1.5 }, { id = "KEY_BY_A229", w = 1.5 },
		{ id = "KEY_BY_A303", w = 1.5 }, { id = "KEY_BY_A310", w = 1.5 }, { id = "KEY_BY_A317", w = 1.5 }, { id = "KEY_BY_A325", w = 1.5 },
		{ id = "KEY_BY_B103", w = 1.5 }, { id = "KEY_BY_B111", w = 1.5 }, { id = "KEY_BY_B116", w = 1.5 }, { id = "KEY_BY_B124", w = 1.5 },
		{ id = "KEY_BY_B223", w = 1.5 }, { id = "KEY_BY_FUELSTORE", w = 2 }, { id = "KEY_BY_FUELTILL", w = 2 }, { id = "KEY_BY_WATCHROOM", w = 1 },
		{ id = "KEY_BY_WATCHSTORE", w = 2 }, { id = "KEY_BY_ARMYHUT", w = 1.5 }, { id = "KEY_BY_HUTSKIOSK", w = 2 }, { id = "KEY_BY_TRAILERA", w = 2 },
		{ id = "KEY_BY_TRAILERB", w = 2 }, { id = "KEY_BY_SHACK4", w = 2 }, { id = "KEY_BY_ROADSHACK", w = 2 }, { id = "KEY_BY_SQUAT", w = 2 },
		{ id = "KEY_BY_PUMPS", w = 2 },
		-- Meridian on Interchange (2026-11-01): its keys turn up anywhere too, the gun shop's and UNIT 14's the rarest
		{ id = "KEY_MM_RESCUE", w = 1.5 }, { id = "KEY_MM_NESTA_REG", w = 2 }, { id = "KEY_MM_KASSA_REG", w = 2 }, { id = "KEY_MM_BOLT_REG", w = 2 },
		{ id = "KEY_MM_BOLT_OFFICE", w = 1.5 }, { id = "KEY_MM_BOLT_GOODS", w = 1.5 }, { id = "KEY_MM_SUBSTATION", w = 1 },
		{ id = "KEY_MM_IRON_FRONT", w = 0.6 }, { id = "KEY_MM_IRON_GRATE", w = 0.6 }, { id = "KEY_MM_UNIT14", w = 0.3 },
	},
	-- M13 Meridian Mall
	register = {
		{ id = "OLD_COIN", w = 10 }, { id = "CIGARETTES", w = 8 }, { id = "MATCHES", w = 6 }, { id = "POWER_BANK", w = 5 },
		{ id = "PHONE", w = 3 }, { id = "GOLD_CHAIN", w = 2 }, { id = "FLASH_MODULE", w = 2 }, { id = "KEY_MALL_STAFF", w = 2 },
	},
	tech = {
		{ id = "WIRES", w = 10 }, { id = "CAPACITOR", w = 8 }, { id = "LOGIC_BOARD", w = 8 }, { id = "HDD", w = 8 },
		{ id = "RAM_STICK", w = 8 }, { id = "POWER_BANK", w = 8 }, { id = "PHONE", w = 6 }, { id = "SIGNAL_COIL", w = 6 },
		{ id = "BATTERY", w = 4 }, { id = "FLASH_MODULE", w = 5 }, { id = "GPU_CARD", w = 3 }, { id = "SEALED_DRIVE", w = 2 },
		{ id = "DECK_TRANSCEIVER", w = 2 }, { id = "MIL_CIRCUIT", w = 1 }, { id = "NV_MONO", w = 0.4 }, { id = "NV_QUAD", w = 0.1 },
	},
	pharmacy = {
		{ id = "BANDAGE", w = 18 }, { id = "PAINKILLERS", w = 16 }, { id = "MEDKIT_S", w = 12 }, { id = "MEDKIT_M", w = 8 },
		{ id = "TOURNIQUET", w = 8 }, { id = "SPLINT", w = 8 }, { id = "HEMOSTAT", w = 5 }, { id = "MED_TOOLS", w = 4 },
		{ id = "MEDKIT_L", w = 3 }, { id = "SURGKIT", w = 1 }, { id = "MEDKIT_XL", w = 1 },
	},
	grocery = {
		{ id = "WATER", w = 14 }, { id = "JUICE", w = 10 }, { id = "CHOC_BAR", w = 12 }, { id = "STEW", w = 10 },
		{ id = "HARDTACK", w = 8 }, { id = "VOLT_DRINK", w = 5 }, { id = "TOOTHPASTE", w = 6 }, { id = "SOAP", w = 6 },
		{ id = "BLEACH", w = 4 }, { id = "CIGARETTES", w = 6 }, { id = "MATCHES", w = 6 }, { id = "LIGHTBULB", w = 4 },
	},
	drinks = { { id = "WATER", w = 14 }, { id = "JUICE", w = 12 }, { id = "VOLT_DRINK", w = 8 } },
	mall = {
		{ id = "CHOC_BAR", w = 10 }, { id = "JUICE", w = 8 }, { id = "WATER", w = 6 }, { id = "CIGARETTES", w = 8 },
		{ id = "MATCHES", w = 6 }, { id = "POWER_BANK", w = 6 }, { id = "LIGHTBULB", w = 6 }, { id = "TOOTHPASTE", w = 5 },
		{ id = "SOAP", w = 5 }, { id = "PHONE", w = 3 }, { id = "OLD_COIN", w = 3 }, { id = "BATTERY", w = 2 },
		{ id = "WIRES", w = 4 }, { id = "DUCT_TAPE", w = 4 }, { id = "A9_PST", w = 3, n = { 5, 15 } }, { id = "BANDAGE", w = 4 },
		{ id = "GLASSES_SUN", w = 2 },
	},
	mallkeys = {
		{ id = "KEY_MALL_STAFF", w = 8 }, { id = "KEY_MEDIQ", w = 6 }, { id = "KEY_MALL_SECURITY", w = 3 },
		{ id = "KEY_VOLTA_STORE", w = 2 }, { id = "CARD_MALL_VAULT", w = 1 },
		-- Interchange rebuild (2026-11-01): the ten KEY_MM_* keys, the rare ones (gun shop, UNIT 14) the scarcest
		{ id = "KEY_MM_RESCUE", w = 4 }, { id = "KEY_MM_NESTA_REG", w = 5 }, { id = "KEY_MM_KASSA_REG", w = 5 }, { id = "KEY_MM_BOLT_REG", w = 5 },
		{ id = "KEY_MM_BOLT_OFFICE", w = 3 }, { id = "KEY_MM_BOLT_GOODS", w = 3 }, { id = "KEY_MM_SUBSTATION", w = 2.5 },
		{ id = "KEY_MM_IRON_FRONT", w = 1.5 }, { id = "KEY_MM_IRON_GRATE", w = 1.5 }, { id = "KEY_MM_UNIT14", w = 0.8 },
	},
	-- one-key pools: a key tile holds its own key (Tarkov spawns the register keys by their registers)
	mk_nesta_reg = { { id = "KEY_MM_NESTA_REG", w = 1 } },
	mk_kassa_reg = { { id = "KEY_MM_KASSA_REG", w = 1 } },
	mk_bolt_reg = { { id = "KEY_MM_BOLT_REG", w = 1 } },
	mk_bolt_office = { { id = "KEY_MM_BOLT_OFFICE", w = 1 } },
	mk_bolt_goods = { { id = "KEY_MM_BOLT_GOODS", w = 1 } },
	mallgood = {
		{ id = "GPU_CARD", w = 2 }, { id = "FLASH_MODULE", w = 6 }, { id = "GOLD_CHAIN", w = 6 }, { id = "CAPT_WATCH", w = 4 },
		{ id = "PHONE", w = 8 }, { id = "HDD", w = 6 }, { id = "RAM_STICK", w = 6 }, { id = "INTEL_FOLDER", w = 3 },
		{ id = "SEALED_DRIVE", w = 2 }, { id = "MEDKIT_M", w = 4 }, { id = "KEY_MALL_SECURITY", w = 1 },
	},
	-- airdrops (Tarkov's four crates, 10 x 12 grids; Services/Airdrop.luau): the common crate a bit of everything, the
	-- medical one meds and provisions, the supply one barter goods, the weapon one guns, mods and ammunition
	airdrop_common = {
		{ id = "BOLTS", w = 6 }, { id = "WIRES", w = 6 }, { id = "CAPACITOR", w = 5 }, { id = "LOGIC_BOARD", w = 4 }, { id = "MIL_CIRCUIT", w = 2 },
		{ id = "BATTERY", w = 4 }, { id = "FUEL_CAN", w = 3 }, { id = "GOLD_CHAIN", w = 3 }, { id = "MEDKIT_M", w = 6 }, { id = "MEDKIT_L", w = 3 },
		{ id = "HEMOSTAT", w = 3 }, { id = "SPLINT", w = 4 }, { id = "PAINKILLERS", w = 4 }, { id = "WATER", w = 5 }, { id = "STEW", w = 4 },
		{ id = "A62_FMJ", w = 6, n = { 30, 60 } }, { id = "A76_PS", w = 6, n = { 30, 60 } }, { id = "A62_AP", w = 2, n = { 20, 40 } },
		{ id = "A9_PST", w = 4, n = { 30, 50 } }, { id = "R17_MAG", w = 3, a = { 0, 25 }, at = "A62_FMJ" }, { id = "KST_MAG", w = 3, a = { 0, 30 }, at = "A76_PS" },
		{ id = "HELMET_C3", w = 2 }, { id = "ARMOR_C4", w = 1.5 }, { id = "RIG_CHEST", w = 2 }, { id = "BAG_PATROL", w = 1.5 }, { id = "HEADSET_GS1", w = 1.5 },
		{ id = "R17_RIFLE", w = 1 }, { id = "KST_RIFLE", w = 1 }, { id = "SPARROW_SMG", w = 1 }, { id = "GREN_RK5", w = 3 }, { id = "GREN_F7", w = 1 },
	},
	airdrop_medical = {
		{ id = "MEDKIT_L", w = 8 }, { id = "MEDKIT_XL", w = 3 }, { id = "MEDKIT_M", w = 10 }, { id = "SURGKIT", w = 3 }, { id = "HEMOSTAT", w = 8 },
		{ id = "SPLINT", w = 8 }, { id = "TOURNIQUET", w = 8 }, { id = "PAINKILLERS", w = 8 }, { id = "BANDAGE", w = 8 }, { id = "MED_TOOLS", w = 4 },
		{ id = "WATER", w = 6 }, { id = "STEW", w = 5 }, { id = "HARDTACK", w = 5 }, { id = "VOLT_DRINK", w = 3 }, { id = "JUICE", w = 3 },
		{ id = "CHOC_BAR", w = 3 },
	},
	airdrop_supply = {
		{ id = "BOLTS", w = 8 }, { id = "DUCT_TAPE", w = 8 }, { id = "WIRES", w = 8 }, { id = "SPARK_PLUG", w = 6 }, { id = "CAPACITOR", w = 6 },
		{ id = "LOGIC_BOARD", w = 5 }, { id = "MIL_CIRCUIT", w = 3 }, { id = "SIGNAL_COIL", w = 5 }, { id = "CERAMIC_FUSE", w = 5 },
		{ id = "BATTERY", w = 5 }, { id = "FUEL_CAN", w = 4 }, { id = "DECK_TRANSCEIVER", w = 3 }, { id = "FLASH_MODULE", w = 4 },
		{ id = "SEALED_DRIVE", w = 2 }, { id = "GOLD_CHAIN", w = 4 }, { id = "CAPT_WATCH", w = 3 }, { id = "COLD_WALLET", w = 1 },
		{ id = "WEAPON_KIT", w = 2 }, { id = "MULTITOOL", w = 3 },
	},
	airdrop_weapon = {
		{ id = "R17_RIFLE", w = 3 }, { id = "KST_RIFLE", w = 3 }, { id = "SPARROW_SMG", w = 2 }, { id = "HARROW12", w = 2 }, { id = "P9_PISTOL", w = 2 },
		{ id = "R17_MAG", w = 4, a = { 0, 25 }, at = "A62_FMJ" }, { id = "R17_MAG40", w = 2, a = { 0, 40 }, at = "A62_FMJ" },
		{ id = "KST_MAG", w = 4, a = { 0, 30 }, at = "A76_PS" }, { id = "KST_MAG_POLY", w = 2, a = { 0, 30 }, at = "A76_PS" },
		{ id = "SPARROW_MAG", w = 3, a = { 0, 30 }, at = "A9_PST" }, { id = "A62_FMJ", w = 5, n = { 40, 60 } }, { id = "A62_AP", w = 3, n = { 20, 50 } },
		{ id = "A76_PS", w = 5, n = { 40, 60 } }, { id = "A76_BP", w = 2, n = { 20, 40 } }, { id = "A12_SLUG", w = 2, n = { 10, 20 } },
		{ id = "A76L_LPS", w = 2, n = { 20, 40 } }, { id = "RED_DOT", w = 2 }, { id = "SIGHT_MICRO", w = 1 }, { id = "GRIP_V", w = 2 },
		{ id = "LIGHT_T", w = 2 }, { id = "LASER_DOT", w = 1 }, { id = "R17_COMP", w = 1 }, { id = "KST_FH_SLANT", w = 1 }, { id = "AR_STK_CARB", w = 1 },
		{ id = "GREN_F7", w = 2 }, { id = "GREN_RK5", w = 3 }, { id = "ARMOR_C4", w = 1 }, { id = "ARMOR_C5", w = 0.5 }, { id = "HELMET_C4", w = 1 },
	},
}
Loot.POOLS = POOLS

local function fail(code, msg)
	return ctx.Remotes.fail(code, msg)
end

function Loot.rollEntry(rand, poolName)
	local pool = POOLS[poolName] or POOLS.crate
	local total = 0
	for _, e in pool do
		total += e.w
	end
	local r = rand:NextNumber() * total
	for _, e in pool do
		r -= e.w
		if r <= 0 then
			local n = e.n and rand:NextInteger(e.n[1], e.n[2]) or 1
			local extra = nil
			if e.a then
				local a = rand:NextInteger(e.a[1], e.a[2])
				extra = { a = a, at = a > 0 and e.at or nil }
			end
			local d = Items.defs[e.id]
			if d and d.weapon and d.kind ~= "melee" then
				extra = extra or {}
				extra.wear = math.floor(rand:NextNumber(45, 95) * 10) / 10 -- found weapons are used (M11)
				-- M14: now and then a found gun is somebody's build rather than the factory one
				local others = WP.PRESETS_OF[e.id]
				if others and #others > 0 and rand:NextNumber() < 0.3 then
					extra.preset = others[rand:NextInteger(1, #others)]
				end
			end
			return Inv.newItem(e.id, n, extra)
		end
	end
	return nil
end

-- fill a box holder's main grid; returns the reveal order (top-level guids)
function Loot.fill(holder, rand, poolName, count)
	local order = {}
	for _ = 1, count do
		local g, it = Loot.rollEntry(rand, poolName)
		if g then
			local ok, info = Inv.place(holder, g, it, { "main" })
			if ok and info ~= "MERGED" then
				table.insert(order, g)
			end
		end
	end
	return order
end

-- ── reveal (search) ───────────────────────────────────────────────────────────
-- Boxes: units = top-level items. Bodies: unit 0 = worn gear (instant), then each searchable grid.
local function revealCost(c, unit)
	if c.body then
		local pl = c.holder.grids[unit]
		local n = 0
		for _ in pl or {} do
			n += 1
		end
		return 0.6 + n * 0.35
	end
	local it = c.holder.items[unit]
	local d = it and Items.defs[it.id]
	local cells = d and d.w * d.h or 1
	local rare = d and (Items.RARITY[d.rarity] or 0) or 0
	return 0.45 + cells * 0.12 + rare * 0.18
end

local function units(c)
	if not c.body then
		return c.order
	end
	local list = { "pockets" }
	local h = c.holder
	for _, s in { "rig", "back" } do
		local g = h.slots[s]
		if g and h.grids[g] then
			table.insert(list, g)
		end
	end
	return list
end

-- Is item g visible to player? (revealed by their search)
function Loot.visible(c, player, g)
	local h = c.holder
	if not h.items[g] then
		return false
	end
	local n = c.revealed[player] or 0
	local list = units(c)
	if not c.body then
		local top = Inv.topOf(h, g)
		local idx = table.find(list, top)
		return idx ~= nil and idx <= n
	end
	-- bodies: worn items are visible; contents need their grid searched
	local cur = g
	for _ = 1, 32 do
		local k, a = Inv.locate(h, cur)
		if k == "slot" then
			return true
		end
		if k == "grid" then
			local idx = table.find(list, a)
			if idx then
				return idx <= n
			end
			if a == "main" then
				return true
			end
			cur = a
		elseif k == "mag" then
			cur = a
		else
			return false
		end
	end
	return false
end

-- snapshot of what this player can see
function Loot.view(c, player)
	local h = c.holder
	local items = {}
	for g in h.items do
		if Loot.visible(c, player, g) then
			items[g] = h.items[g]
		end
	end
	local slots = {}
	for s, g in h.slots do
		slots[s] = g
		items[g] = h.items[g]
	end
	local grids = {}
	local list0 = units(c)
	local n0 = c.revealed[player] or 0
	for cid, pl in h.grids do
		local unitIdx = c.body and table.find(list0, cid) or nil
		local hidden = unitIdx ~= nil and unitIdx > n0
		if not hidden and (Inv.BUILTIN[cid] or items[cid] ~= nil) then
			local out = {}
			for g, p in pl do
				if items[g] then
					out[g] = p
				end
			end
			grids[cid] = out
		end
	end
	local list = units(c)
	return {
		cid = c.id, label = c.label, kind = c.kind, body = c.body or nil, items = items, grids = grids, slots = slots,
		mainW = h.mainW, mainH = h.mainH, pocketsW = h.pocketsW, pocketsH = h.pocketsH,
		searched = (c.revealed[player] or 0) >= #list, searching = c.searching[player] ~= nil,
	}
end

local function reach(player, c, slack)
	local s = ctx.Raid.session(player)
	if not s or s.done then
		return false, "NOT_IN_RAID"
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root then
		return false, "NOT_AUTHORIZED"
	end
	if not c.part or not c.part.Parent then
		return false, "GONE"
	end
	if (root.Position - c.part.Position).Magnitude > Config.INTERACT_RANGE + (slack or 0) then
		return false, "TOO_FAR"
	end
	if ctx.Guard and ctx.Guard.canSee and not ctx.Guard.canSee(char, c.part, 1.2) then
		return false, "NO_LINE_OF_SIGHT"
	end
	return true, s
end
Loot.reach = reach

local function send(player, c)
	ctx.Remotes.note(player, "loot", Loot.view(c, player))
end

function Loot.broadcast(c)
	for p in c.viewers do
		if p.Parent and reach(p, c, 4) then
			send(p, c)
		else
			c.viewers[p] = nil
		end
	end
end

-- container a player may manipulate right now (opened, in reach)
function Loot.access(player, cid)
	local c = containers[cid]
	if not c then
		return nil, "GONE"
	end
	local okR, err = reach(player, c, 3)
	if not okR then
		return nil, err
	end
	if not c.viewers[player] then
		return nil, "NOT_OPEN"
	end
	return c, nil
end

local function searchLoop(player, c)
	if c.searching[player] then
		return
	end
	c.searching[player] = true
	local list = units(c)
	while (c.revealed[player] or 0) < #list do
		local nextUnit = list[(c.revealed[player] or 0) + 1]
		-- Attention and Search shorten every reveal (at most by half)
		local sprof = ctx.Profiles and ctx.Profiles.get(player)
		local sk = sprof and sprof.skills
		local t = revealCost(c, nextUnit) * math.max(0.5, 1 - Progress.bonus(sk, "attention") - Progress.bonus(sk, "search"))
		ctx.Remotes.note(player, "search", { cid = c.id, t = t, label = c.label })
		task.wait(t)
		if containers[c.id] ~= c or not c.viewers[player] or not reach(player, c, 2) then
			ctx.Remotes.note(player, "search", { cid = c.id, cancel = true })
			c.searching[player] = nil
			return
		end
		c.revealed[player] = (c.revealed[player] or 0) + 1
		if ctx.Economy then
			ctx.Economy.raidXp(player, 4)
			ctx.Economy.skillUp(player, sprof, "search", 0.4)
			ctx.Economy.skillUp(player, sprof, "attention", 0.25)
			ctx.Economy.skillUp(player, sprof, "perception", 0.15)
		end
		list = units(c)
		send(player, c)
	end
	c.searching[player] = nil
	ctx.Remotes.note(player, "search", { cid = c.id, cancel = true })
	send(player, c)
end

function Loot.open(player, cid)
	local c = containers[cid]
	if not c or not reach(player, c, 1) then
		return
	end
	if not ctx.Remotes.allow(player, "open", 2, 3) then
		return
	end
	if c.locked and not c.unlocked then
		ctx.Remotes.note(player, "toast", { text = "LOCKED", tone = "warn" })
		return
	end
	c.viewers[player] = true
	send(player, c)
	task.spawn(searchLoop, player, c)
end

function Loot.close(player, cid)
	local c = containers[cid]
	if c then
		c.viewers[player] = nil
	end
end

-- call after any change to a container's holder
function Loot.changed(c)
	if not c.body then
		-- newly put items are already known to whoever put them; keep order list in sync
		local seen = {}
		for _, g in c.order do
			seen[g] = true
		end
		for g in c.holder.grids.main or {} do
			if not seen[g] then
				table.insert(c.order, g)
				for p, n in c.revealed do
					if n >= #c.order - 1 then
						c.revealed[p] = n + 1
					end
				end
			end
		end
		for i = #c.order, 1, -1 do
			local g = c.order[i]
			if not (c.holder.grids.main or {})[g] then
				table.remove(c.order, i)
				for p, n in c.revealed do
					if n >= i then
						c.revealed[p] = n - 1
					end
				end
			end
		end
	end
	if c.temp and c.pile and next(c.holder.items) == nil and c.part then
		c.part:Destroy()
		containers[c.id] = nil
	end
	Loot.broadcast(c)
end

function Loot.reset(seed)
	for cid, c in containers do
		if c.temp then
			if c.part and c.part.Parent then
				c.part:Destroy()
			end
			containers[cid] = nil
		end
	end
	local rand = Random.new(seed)
	for _, c in containers do
		local k = KINDS[c.kind] or KINDS.crate
		c.holder = Inv.newHolder("box", k.w, k.h)
		c.order = Loot.fill(c.holder, rand, k.pool, rand:NextInteger(k.count[1], k.count[2]))
		c.revealed, c.viewers, c.searching = {}, {}, {}
		c.unlocked = nil
	end
	local ok, err = pcall(Loot.spawnLoose, seed and (seed + 77) or nil)
	if not ok then
		warn("[ZR] loose loot", err)
	end
end

-- raid over: bodies, dropped gear and leftover loose items disappear (Match settles insurance from them first)
function Loot.clearTemp()
	if Loot.clearLoose then
		Loot.clearLoose()
	end
	for cid, c in containers do
		if c.temp then
			if c.part and c.part.Parent then
				c.part:Destroy()
			end
			containers[cid] = nil
		end
	end
end

local function lootFolder()
	local folder = workspace:FindFirstChild("ZR_Loot")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ZR_Loot"
		folder.Parent = workspace
	end
	return folder
end

local function prompt(part, label, action)
	local pp = Instance.new("ProximityPrompt")
	pp.KeyboardKeyCode = Enum.KeyCode.F -- Tarkov interact key (Q/E lean)
	pp.ActionText = action or "Search"
	pp.ObjectText = label
	pp.HoldDuration = 0
	pp.MaxActivationDistance = Config.INTERACT_RANGE - 1
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.Parent = part
	return pp
end

function Loot.register(c)
	containers[c.id] = c
	return c
end

-- ground pile at pos (merges into a nearby pile); bundles = Inv.take results
function Loot.spawnPile(pos, bundles)
	for _, c in containers do
		if c.pile and c.part and (c.part.Position - pos).Magnitude < 3.5 then
			local allOk = true
			for _, b in bundles do
				if not Inv.give(c.holder, b, nil, { "main" }) then
					allOk = false
				end
			end
			if allOk then
				Loot.changed(c)
				return c
			end
		end
	end
	pileN += 1
	local cid = "P" .. pileN
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain, workspace:FindFirstChild("ZR_World") }
	rp.IgnoreWater = true
	local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -30, 0), rp)
	local ground = hit and hit.Position or pos
	local part = Instance.new("Part")
	part.Name = "Loot_" .. cid
	part.Size = Vector3.new(1.8, 0.7, 1.3)
	part.Anchored = true
	part.CanCollide = false
	part.Color = Color3.fromHex("4A4B3E")
	part.Material = Enum.Material.Fabric
	part.CFrame = CFrame.new(ground + Vector3.new(0, part.Size.Y / 2, 0)) * CFrame.Angles(0, math.random() * 6.28, 0)
	local holder = Inv.newHolder("box", 8, 8)
	local c = { id = cid, kind = "pile", label = "Dropped gear", part = part, holder = holder, order = {}, revealed = {}, viewers = {}, searching = {}, temp = true, pile = true }
	for _, b in bundles do
		Inv.give(holder, b, nil, { "main" })
	end
	for g in holder.grids.main do
		table.insert(c.order, g)
	end
	prompt(part, "Dropped gear", "Loot")
	part.Parent = lootFolder()
	containers[cid] = c
	part:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(p)
		c.revealed[p] = #c.order -- dropped gear needs no search
		Loot.open(p, cid)
	end)
	return c
end

-- a crate dropped in the raid (airdrops): a box holder of w x h filled from `pool`, searched item by item like any
-- container, and cleared with the raid. part = the crate's body (it carries the prompt); o = { label, pool, w, h, count,
-- seed }. Returns the container.
function Loot.spawnCrate(part, o)
	pileN += 1
	local cid = "D" .. pileN
	local rand = Random.new(o.seed or math.random(1, 2 ^ 30))
	local holder = Inv.newHolder("box", o.w or 10, o.h or 12)
	local c = { id = cid, kind = "airdrop", label = o.label or "Supply crate", part = part, holder = holder, revealed = {}, viewers = {}, searching = {}, temp = true }
	c.order = Loot.fill(holder, rand, o.pool or "airdrop_common", o.count or 10)
	containers[cid] = c
	prompt(part, c.label, "Search").Triggered:Connect(function(p)
		Loot.open(p, cid)
	end)
	return c
end

-- a corpse: holder = full inventory (slots/pockets/containers). part = something to stand next to.
function Loot.spawnBody(model, holder, label)
	pileN += 1
	local cid = "B" .. pileN
	local root = model and (model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart"))
	local anchor = Instance.new("Part")
	anchor.Name = "Body_" .. cid
	anchor.Size = Vector3.new(2.6, 1.2, 2.6)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CFrame = CFrame.new(root and root.Position or model:GetPivot().Position)
	anchor.Parent = lootFolder()
	local c = { id = cid, kind = "body", body = true, label = label or "Body", part = anchor, holder = holder, order = {}, revealed = {}, viewers = {}, searching = {}, temp = true }
	containers[cid] = c
	prompt(anchor, label or "Body", "Search").Triggered:Connect(function(p)
		Loot.open(p, cid)
	end)
	-- keep the prompt on the ragdoll as it settles
	task.spawn(function()
		for _ = 1, 12 do
			task.wait(0.5)
			if not anchor.Parent then
				return
			end
			if root and root.Parent then
				anchor.CFrame = CFrame.new(root.Position)
			end
		end
	end)
	return c
end

-- ── loose loot (M10) ─────────────────────────────────────────────────────────
-- Items lying in the world (desks, shelves, floors) from World.looseSpots, rolled at each raid start. Picking
-- one up (F, line of sight) puts it in the raid inventory as found-in-progress (found-in-raid on extraction).
local loose = {} -- [id] = { id, holder, g, part, model }
Loot.loose = loose
local looseN = 0

local function looseFolder()
	local folder = workspace:FindFirstChild("ZR_Loose")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ZR_Loose"
		folder.Parent = workspace
	end
	return folder
end

local THICK = { ammo = 0.35, mag = 0.5, med = 0.4, food = 0.55, key = 0.1, loot = 0.3, quest = 0.18, mod = 0.3, rig = 0.5, backpack = 0.8, armor = 0.6, helmet = 0.8 }
local M = Enum.Material
local ItemModel = require(Shared.ItemModel)
local quietPart, placeItemModel, placeWearModel = ItemModel.quiet, ItemModel.placeMeta, ItemModel.placeWear
local MAT = { med = Enum.Material.Fabric, rig = Enum.Material.Fabric, backpack = Enum.Material.Fabric, armor = Enum.Material.Fabric, key = Enum.Material.Metal, mag = Enum.Material.Metal, ammo = Enum.Material.Metal, mod = Enum.Material.Metal }

-- an item lying at surface cf: weapons are built from the shared weapon spec lying on their side, other items
-- are their Blender model (ItemMeta) or, for worn gear, the character meshes; a block sized from the grid
-- footprint in the item's colour stands in when the meshes have not loaded
local function looseModel(holder, g, it, cf)
	local d = Items.defs[it.id]
	local model = Instance.new("Model")
	model.Name = "Loose_" .. it.id
	local hit = Instance.new("Part")
	hit.Name = "Pick"
	hit.Anchored = true
	hit.CanCollide = false
	hit.CanTouch = false
	hit.CanQuery = true
	hit.Transparency = 1
	hit.Parent = model
	-- guns and gun parts lie on their right side, built from their Blender parts as they are put together
	local lie = cf * CFrame.Angles(0, 0, math.rad(90))
	local pieces
	if d.kind == "weapon" or d.kind == "pistol" or d.kind == "mod" or d.kind == "mag" then
		pieces = ItemModel.gunPieces(holder.items, g, lie)
	end
	if pieces and #pieces > 0 then
		-- settle the build on the surface, centred over the spot (box in the spot's own yaw frame)
		local lo, hi = GunBuild.bounds(pieces, cf)
		local mid = (lo + hi) / 2
		local shift = cf:VectorToWorldSpace(Vector3.new(-mid.X, -lo.Y, -mid.Z))
		for _, p in pieces do
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CFrame = p.CFrame + shift
			p.Parent = model
		end
		hit.Size = (hi - lo):Max(Vector3.new(0.6, 0.4, 0.6)) + Vector3.new(0.2, 0.2, 0.2)
		hit.CFrame = cf * CFrame.new(0, (hi.Y - lo.Y) / 2, 0)
	else
		local size, centre = placeItemModel(model, it.id, cf)
		if not size then
			size, centre = placeWearModel(model, d, cf)
		end
		if size then
			hit.Size = size:Max(Vector3.new(0.6, 0.4, 0.6)) + Vector3.new(0.2, 0.2, 0.2)
			hit.CFrame = centre
			model.PrimaryPart = hit
			return model, hit
		end
		local sy = THICK[d.kind] or 0.3
		local block = Instance.new("Part")
		block.Name = "Item"
		block.Anchored = true
		block.CanCollide = false
		block.CanQuery = false
		block.CanTouch = false
		block.Size = Vector3.new(math.max(0.3, d.w * 0.42), sy, math.max(0.3, d.h * 0.42))
		block.CFrame = cf * CFrame.new(0, sy / 2, 0)
		block.Color = d.color or Color3.fromRGB(120, 120, 110)
		block.Material = MAT[d.kind] or Enum.Material.SmoothPlastic
		block.TopSurface = Enum.SurfaceType.Smooth
		block.BottomSurface = Enum.SurfaceType.Smooth
		block.Parent = model
		hit.Size = block.Size + Vector3.new(0.5, 0.5, 0.5)
		hit.CFrame = block.CFrame
	end
	model.PrimaryPart = hit
	return model, hit
end

function Loot.clearLoose()
	for id, e in loose do
		if e.model and e.model.Parent then
			e.model:Destroy()
		end
		loose[id] = nil
	end
end

-- raid start: roll every spot (spots that miss stay empty this raid)
function Loot.spawnLoose(seed)
	Loot.clearLoose()
	local rand = Random.new(seed)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain, workspace:FindFirstChild("ZR_World") }
	rp.IgnoreWater = true
	local n = 0
	for _, spot in ctx.World.looseSpots or {} do
		if rand:NextNumber() < spot.chance then
			local g, it = Loot.rollEntry(rand, spot.tbl)
			if g then
				local hitR = workspace:Raycast(spot.pos + Vector3.new(0, 1.2, 0), Vector3.new(0, -3, 0), rp)
				local base = hitR and hitR.Position or spot.pos
				local cf = CFrame.new(base) * CFrame.Angles(0, rand:NextNumber(0, math.pi * 2), 0)
				local holder = Inv.newHolder("box", 8, 8)
				Inv.place(holder, g, it, { "main" })
				looseN += 1
				local id = "L" .. looseN
				local model, pick = looseModel(holder, g, it, cf)
				local pp = Instance.new("ProximityPrompt")
				pp.KeyboardKeyCode = Enum.KeyCode.F
				pp.ActionText = "Take"
				pp.ObjectText = Items.defs[it.id].name
				pp.HoldDuration = 0
				pp.MaxActivationDistance = 5
				pp.RequiresLineOfSight = true
				pp.Style = Enum.ProximityPromptStyle.Custom
				pp:SetAttribute("ItemId", it.id) -- clients show "Unknown item" until examined
				pp.Parent = pick
				model.Parent = looseFolder()
				loose[id] = { id = id, holder = holder, g = g, model = model, part = pick, area = spot.area }
				pp.Triggered:Connect(function(player)
					local ok, err = pcall(Loot.takeLoose, player, id)
					if not ok then
						warn("[ZR] take loose", err)
					end
				end)
				n += 1
			end
		end
	end
	return n
end

-- pick up a loose item: same rules as looting a container (raid session, reach, space), found-in-progress
function Loot.takeLoose(player, id)
	local e = loose[id]
	local s = ctx.Raid.session(player)
	if not e or not s or s.done or s.state ~= "ACTIVE" then
		return false, "GONE"
	end
	if not ctx.Remotes.allow(player, "loose", 4, 6) then
		return false, "RATE"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - e.part.Position).Magnitude > 7 then
		return false, "TOO_FAR"
	end
	local b = Inv.take(e.holder, e.g)
	if not b then
		return false, "GONE"
	end
	for _, x in { b, table.unpack(b.subs) } do
		if not s.risked[x.g] then
			x.it.fip = true
		end
	end
	local d = Items.defs[b.it.id]
	local placed = false
	-- a weapon goes to a free weapon slot first (Tarkov), anything else into rig/pockets/backpack
	if d.kind == "weapon" or d.kind == "pistol" then
		for _, slot in (d.kind == "pistol") and { "holster" } or { "primary", "secondary" } do
			if not s.inv.slots[slot] and Inv.give(s.inv, b, { slot = slot }) then
				placed = true
				break
			end
		end
	end
	if not placed then
		placed = Inv.give(s.inv, b, nil, Inv.loadOrder(s.inv))
	end
	if not placed then
		Inv.give(e.holder, b, nil, { "main" })
		ctx.Remotes.note(player, "toast", { text = "NO SPACE", tone = "warn" })
		return false, "NO_SPACE"
	end
	loose[id] = nil
	if e.model then
		e.model:Destroy()
	end
	ctx.Remotes.fx("sfx", { n = "loot_pickup", p = root.Position, v = 0.7 })
	ctx.Remotes.note(player, "toast", { text = "+ " .. string.upper(d.name), tone = "good" })
	if ctx.Economy and ctx.Economy.raidXp then
		ctx.Economy.raidXp(player, 2)
	end
	ctx.Raid.afterChange(player, true)
	return true
end

-- AI loadouts (M8). Everything an AI carries is real inventory: it fires the rounds in its magazines, reloads
-- from its rig and drops all of it as a lootable body.
local function kit(rand)
	local h = Inv.newHolder("raid")
	local k = {}
	function k.slot(slotName, id, extra)
		local g, it = Inv.newItem(id, 1, extra)
		if Inv.placeSlot(h, g, it, slotName) then
			return g
		end
		return nil
	end
	-- weapon (its default build, or `preset`, M14) with a loaded magazine (or loaded tube) plus `spares`
	-- magazines into the rig/pockets
	function k.gun(slotName, id, magId, ammoId, spares, fill, preset)
		local wg = k.slot(slotName, id, preset and { preset = preset } or nil)
		if not wg then
			return nil
		end
		if k.wear then
			-- weapon durability (M11): AI guns are used, some badly
			h.items[wg].wear = math.floor(rand:NextNumber(k.wear[1], k.wear[2]) * 10) / 10
		end
		if magId then
			local cap = Items.defs[magId].capacity
			local mg, mag = Inv.newItem(magId, 1, { a = math.max(1, math.floor(cap * (fill or 1))), at = ammoId })
			h.items[mg] = mag
			h.items[wg].mag = mg
			Inv.resize(h, wg)
			for _ = 1, spares or 0 do
				local g, it = Inv.newItem(magId, 1, { a = cap, at = ammoId })
				Inv.place(h, g, it, Inv.loadOrder(h))
			end
		else
			local d = Items.defs[id]
			local cap = Inv.capacityOf(h, wg) or d.capacity or 5
			h.items[wg].a = cap
			h.items[wg].at = ammoId
			if (spares or 0) > 0 then
				local g, it = Inv.newItem(ammoId, math.min(Items.defs[ammoId].stack, cap * spares))
				Inv.place(h, g, it, Inv.loadOrder(h))
			end
		end
		return wg
	end
	function k.put(id, n, extra)
		local g, it = Inv.newItem(id, n or 1, extra)
		return Inv.place(h, g, it, Inv.loadOrder(h)) and g or nil
	end
	-- Tarkov's Goons carry five double pockets (5 x 2, one item one cell wide in each; Inv pocketSpot)
	function k.doublePockets()
		h.pocketsW, h.pocketsH = 5, 2
	end
	-- put a part on a weapon in the kit, in a free slot that takes it (skipped when there is none)
	function k.mod(wg, id)
		if not wg then
			return nil
		end
		local mg, m = Inv.newItem(id, 1)
		h.items[mg] = m
		local pg, sname = WP.freeSlot(h.items, wg, id)
		if pg and sname and Inv.attachPart(h, pg, sname, mg, {}) then
			return mg
		end
		h.items[mg] = nil
		return nil
	end
	function k.roll(pool, count)
		for _ = 1, count do
			local g, it = Loot.rollEntry(rand, pool)
			if g then
				Inv.place(h, g, it, Inv.loadOrder(h))
			end
		end
	end
	k.h = h
	k.wear = { 60, 96 }
	return k
end

-- Harbor Watch (raider-type guards): service rifles or SMGs with decent ammo, armour, a few spare magazines
function Loot.guardLoadout(rand)
	rand = rand or Random.new()
	local k = kit(rand)
	-- coordinated Watch kit: black rigs, slate vests, full-cut shells or caps; some wear a headset (M16 visuals)
	k.slot("rig", rand:NextNumber() < 0.6 and "RIG_CHEST" or "RIG_BELT", { tint = "black" })
	if rand:NextNumber() < 0.7 then
		k.slot("armor", rand:NextNumber() < 0.65 and "ARMOR_C2" or "ARMOR_C3", { dur = rand:NextInteger(18, 45) })
	end
	if rand:NextNumber() < 0.55 then
		k.slot("head", rand:NextNumber() < 0.7 and "HELMET_C2" or "HELMET_C3", { dur = rand:NextInteger(10, 30), tint = "black" })
	elseif rand:NextNumber() < 0.6 then
		k.slot("head", "CAP_FIELD", { tint = "black" })
	end
	if rand:NextNumber() < 0.3 then
		k.slot("ears", "HEADSET_GS1") -- refused under a full-cut shell (Equipment compatibility)
	end
	if rand:NextNumber() < 0.2 then
		k.slot("face", "GAITER", { tint = "black" })
	end
	-- M14 builds: patrol builds carry a light on the rail (night patrols use it, AI.luau)
	if rand:NextNumber() < 0.7 then
		k.gun("primary", "R17_RIFLE", "R17_MAG", rand:NextNumber() < 0.25 and "A62_AP" or "A62_FMJ", rand:NextInteger(1, 3), rand:NextNumber(0.6, 1), rand:NextNumber() < 0.55 and "R17_PATROL" or nil)
	else
		k.gun("primary", "SPARROW_SMG", "SPARROW_MAG", rand:NextNumber() < 0.3 and "A9_AP" or "A9_PST", rand:NextInteger(1, 3), rand:NextNumber(0.6, 1), rand:NextNumber() < 0.45 and "SPR_TAC" or nil)
	end
	k.put(rand:NextNumber() < 0.5 and "BANDAGE" or "MEDKIT_S")
	if rand:NextNumber() < 0.4 then
		k.put("TOURNIQUET")
	end
	-- grenades (M11): the Watch flush raiders out of cover
	if rand:NextNumber() < 0.55 then
		k.put("GREN_RK5")
	end
	if rand:NextNumber() < 0.2 then
		k.put("GREN_SMOKE")
	end
	if rand:NextNumber() < 0.15 then
		k.put("GREN_STUN")
	end
	k.roll("jacket", rand:NextInteger(0, 2))
	-- eyewear (EYEWEAR slot): shooting glasses or ballistic glasses on some of the Watch; a gas mask on the face (rare) blocks them
	if rand:NextNumber() < 0.04 then
		k.slot("face", "GAS_MASK")
	end
	if rand:NextNumber() < 0.22 then
		if rand:NextNumber() < 0.6 then
			k.slot("eyes", "GLASSES_RANGE")
		else
			k.slot("eyes", "GLASSES_BG1", { dur = rand:NextInteger(12, 25) })
		end
	end
	return k.h
end

-- the Foreman: heavy armour, a 7.6 rifle with armour-piercing rounds, good meds, and the harbour's best loot
function Loot.bossLoadout(rand)
	rand = rand or Random.new()
	local k = kit(rand)
	k.wear = { 88, 100 }
	-- heavy armour worn under his padded work jacket (the Foreman look conceals it), his signature hard hat
	k.slot("armor", "ARMOR_C5", { dur = rand:NextInteger(55, 70) })
	k.slot("head", "HARDHAT_FOREMAN", { dur = rand:NextInteger(16, 22) })
	k.slot("rig", "RIG_CHEST", { tint = "charcoal" })
	k.slot("back", "BAG_PATROL", { tint = "charcoal" })
	k.gun("primary", "KST_RIFLE", "KST_MAG", "A76_BP", 3, nil, "KST_TAC")
	local pg = k.gun("holster", "P9_PISTOL", "P9_MAG", "A9_AP", 1)
	local _ = pg
	k.put("MEDKIT_L")
	k.put("HEMOSTAT")
	k.put("PAINKILLERS")
	k.put("GREN_F7")
	k.put("GREN_F7")
	k.put("GREN_SMOKE")
	if rand:NextNumber() < 0.6 then
		k.put("GREN_STUN")
	end
	if rand:NextNumber() < 0.4 then
		k.put("LEDGER")
	end
	if rand:NextNumber() < 0.35 then
		k.put("BRASS_LION")
	end
	if rand:NextNumber() < 0.5 then
		k.put("KEY_OFFICE")
	end
	k.roll("safe", rand:NextInteger(1, 3))
	return k.h
end

-- M13 the Caretaker (Meridian Mall): the mall's former security chief in assault armour with arm guards and a
-- face-plate helmet, a pump gun with slugs and a carbine slung behind, and the keys to the places he guards
function Loot.caretakerLoadout(rand)
	rand = rand or Random.new()
	local k = kit(rand)
	k.wear = { 85, 100 }
	k.slot("armor", "ARMOR_C6", { dur = rand:NextInteger(60, 80), tint = "black" })
	k.slot("head", "HELMET_C5", { dur = rand:NextInteger(30, 45) })
	k.slot("rig", "RIG_CHEST", { tint = "black" })
	k.gun("primary", "HARROW12", nil, rand:NextNumber() < 0.6 and "A12_SLUG" or "A12_BUCK", 4, nil, "HAR_TAC")
	k.gun("secondary", "R17_RIFLE", "R17_MAG40", "A62_AP", 2, nil, "R17_CQB")
	k.gun("holster", "P9_PISTOL", "P9_MAG", "A9_AP", 1, nil, "P9_TAC")
	k.put("MEDKIT_L")
	k.put("HEMOSTAT")
	k.put("PAINKILLERS")
	k.put("GREN_STUN")
	k.put("GREN_F7")
	if rand:NextNumber() < 0.5 then
		k.put("KEY_VOLTA_STORE")
	end
	if rand:NextNumber() < 0.35 then
		k.put("KEY_MALL_SECURITY")
	end
	if rand:NextNumber() < 0.15 then
		k.put("CARD_MALL_VAULT")
	end
	if rand:NextNumber() < 0.15 then
		k.put("KEY_MM_IRON_FRONT")
	end
	if rand:NextNumber() < 0.1 then
		k.put("KEY_MM_UNIT14")
	end
	if rand:NextNumber() < 0.4 then
		k.put("GPU_CARD")
	end
	k.roll("mallgood", rand:NextInteger(1, 3))
	return k.h
end

-- THE STOKER (Meridian's KASSA GARAGE boss, our Tagilla; docs/design/BOSS_STOKER.md): a class 6 plate carrier, his
-- welding mask (class 5 for the face), no helmet, a 12 gauge with slugs (Tarkov's is a semi-auto; ours is the pump, a
-- logged gap). His sledgehammer is in his hands, not in his kit: it cannot be looted (as in Tarkov).
function Loot.stokerLoadout(rand)
	rand = rand or Random.new()
	local k = kit(rand)
	k.wear = { 80, 100 }
	k.slot("armor", "ARMOR_C6", { dur = rand:NextInteger(55, 80), tint = "black" })
	k.slot("face", "MASK_WELDER", { dur = rand:NextInteger(28, 40) })
	k.slot("rig", "RIG_CHEST", { tint = "charcoal" })
	k.gun("primary", "HARROW12", nil, rand:NextNumber() < 0.7 and "A12_SLUG" or "A12_BUCK", 3)
	k.put("MEDKIT_L")
	k.put("PAINKILLERS")
	if rand:NextNumber() < 0.5 then
		k.put("HEMOSTAT")
	end
	k.roll("mallgood", rand:NextInteger(0, 2))
	return k.h
end

-- THE HOUNDS (Border Yard's roaming trio, our Goons; docs/design/BOSS_HOUNDS.md). Each has Tarkov's five double pockets.
-- Tarkov's Knight wears a class 5 armoured rig (here a class 5 vest under a black chest rig), a class 1 skull mask (we have
-- none: a black gaiter) and a head mount for his panoramic goggles, no helmet, and fights with a kitted 7.62 AR. Big Pipe wears no helmet (a bandana and his
-- pipe) and flushes cover with a grenade launcher (we have none: MORTAR throws frags). Birdeye wears a class 4 concealable
-- vest, a chest rig and a radio frame pack and holds long angles with a marksman rifle.
function Loot.halberdLoadout(rand)
	rand = rand or Random.new()
	local k = kit(rand)
	k.wear = { 85, 100 }
	k.doublePockets()
	k.slot("armor", "ARMOR_C5", { dur = rand:NextInteger(50, 70), tint = "black" })
	-- no helmet (Tarkov: his head is unarmoured): a goggle head mount, now and then with the panoramic goggles
	local strap = k.slot("head", "NV_STRAP")
	if rand:NextNumber() < 0.35 then
		k.mod(strap, "NV_QUAD")
	end
	k.slot("face", "GAITER", { tint = "black" }) -- in place of the skull mask
	k.slot("rig", "RIG_CHEST", { tint = "black" })
	k.gun("primary", "R17_RIFLE", "R17_MAG", "A62_AP", 3, nil, "R17_CQB")
	k.gun("holster", "P9_PISTOL", "P9_MAG", "A9_AP", 1, nil, "P9_TAC")
	k.put("MEDKIT_L")
	k.put("HEMOSTAT")
	k.put("GREN_F7")
	if rand:NextNumber() < 0.5 then
		k.put("GOLD_CHAIN")
	end
	k.roll("dorm_good", rand:NextInteger(0, 2))
	return k.h
end

function Loot.mortarLoadout(rand)
	rand = rand or Random.new()
	local k = kit(rand)
	k.wear = { 80, 100 }
	k.doublePockets()
	k.slot("armor", "ARMOR_C5", { dur = rand:NextInteger(45, 65), tint = "olive" })
	k.slot("head", "BEANIE", { tint = "charcoal" }) -- in place of the bandana: no head armour, as Big Pipe
	k.slot("rig", "RIG_CHEST", { tint = "olive" })
	k.gun("primary", "KST_RIFLE", "KST_MAG", "A76_BP", 3, nil, "KST_TAC")
	for _ = 1, 3 do
		k.put("GREN_F7")
	end
	for _ = 1, 3 do
		k.put("GREN_RK5")
	end
	k.put("MEDKIT_L")
	k.put("PAINKILLERS")
	k.put("SPLINT")
	k.roll("crate", rand:NextInteger(0, 2))
	return k.h
end

function Loot.kestrelLoadout(rand)
	rand = rand or Random.new()
	local k = kit(rand)
	k.wear = { 85, 100 }
	k.doublePockets()
	k.slot("armor", "ARMOR_C4", { dur = rand:NextInteger(35, 50), tint = "olive" })
	k.slot("head", "HELMET_C3", { dur = rand:NextInteger(20, 35), tint = "tan" })
	k.slot("rig", "RIG_CHEST", { tint = "ranger" })
	k.slot("back", "BAG_PATROL", { tint = "tan" })
	k.gun("primary", "R17_RIFLE", "R17_MAG", "A62_AP", 4, nil, "R17_DMR")
	k.put("GREN_SMOKE")
	k.put("GREN_SMOKE")
	k.put("MEDKIT_M")
	k.put("PAINKILLERS")
	if rand:NextNumber() < 0.3 then
		k.put("FLARE_RED")
	end
	k.roll("dorm_good", rand:NextInteger(0, 2))
	return k.h
end

-- THE CULT (Border Yard's night group, Tarkov's cultists; docs/design/BOSS_CULT.md): robes and no armour, a suppressed SMG
-- for when the ambush fails, the knife (the poisoned one they stab with is the AI's; the looted RITUAL_KNIFE cuts like a
-- field knife), and now and then the antidote for their own blades. The priest carries the amulet and the better loot.
function Loot.cultistLoadout(rand)
	rand = rand or Random.new()
	local k = kit(rand)
	k.wear = { 70, 95 }
	k.slot("head", "BEANIE", { tint = "black" }) -- in place of a raised hood (the hood mesh only hangs down the back)
	k.slot("face", "GAITER", { tint = "black" })
	k.slot("rig", "RIG_CHEST", { tint = "black" })
	local wg = k.gun("primary", "SPARROW_SMG", "SPARROW_MAG", "A9_AP", 2)
	k.mod(wg, "SUPP_9")
	if rand:NextNumber() < 0.5 then
		k.put("RITUAL_KNIFE")
	end
	k.put("BANDAGE")
	if rand:NextNumber() < 0.25 then
		k.put("ANTIDOTE")
	end
	k.roll("dorm_good", rand:NextInteger(0, 1))
	return k.h
end

-- THE FORESTER (Tarkov's Partisan; docs/design/BOSS_FORESTER.md): no armour and no helmet (Tarkov: none), his own pack, an
-- old rifle from the AK family (here the KS-7, now and then the quiet build) or a pump shotgun, a pistol, two to four
-- grenades (F-1 and RGD-5 in Tarkov), sometimes a field medkit (Tarkov: AFAKs), keys from the dorms' pool
function Loot.foresterLoadout(rand)
	rand = rand or Random.new()
	local k = kit(rand)
	k.wear = { 60, 90 }
	k.slot("head", "BEANIE", { tint = "olive" })
	k.slot("back", "FORESTER_PACK")
	if rand:NextNumber() < 0.75 then
		k.gun("primary", "KST_RIFLE", "KST_MAG", rand:NextNumber() < 0.5 and "A76_BP" or "A76_PS", 3, nil, rand:NextNumber() < 0.35 and "KST_QUIET" or nil)
	else
		k.gun("primary", "HARROW12", nil, "A12_BUCK", 2)
	end
	k.gun("holster", "P9_PISTOL", "P9_MAG", "A9_PST", 1)
	for _ = 1, rand:NextInteger(2, 4) do
		k.put(rand:NextNumber() < 0.5 and "GREN_F7" or "GREN_RK5")
	end
	k.put("BANDAGE")
	if rand:NextNumber() < 0.5 then
		k.put("MEDKIT_L")
	end
	k.roll("dorm_good", rand:NextInteger(1, 2))
	return k.h
end

function Loot.priestLoadout(rand)
	rand = rand or Random.new()
	local k = kit(rand)
	k.wear = { 80, 100 }
	k.slot("head", "BEANIE", { tint = "black" })
	k.slot("face", "GAITER", { tint = "black" })
	k.slot("rig", "RIG_CHEST", { tint = "black" })
	local wg = k.gun("primary", "SPARROW_SMG", "SPARROW_MAG", "A9_AP", 2)
	k.mod(wg, "SUPP_9")
	k.put("RITUAL_KNIFE")
	if rand:NextNumber() < 0.6 then
		k.put("RITUAL_AMULET")
	end
	if rand:NextNumber() < 0.5 then
		k.put("ANTIDOTE")
	end
	k.put("BANDAGE")
	k.roll("dorm_good", rand:NextInteger(1, 2))
	return k.h
end

-- the Foreman's crew: plate carriers, AP or PS rounds, plenty of magazines
function Loot.crewLoadout(rand)
	rand = rand or Random.new()
	local k = kit(rand)
	k.wear = { 72, 98 }
	-- better-coordinated black kit, comms headsets (the white shoulder markers come with the bodyguard look)
	k.slot("armor", rand:NextNumber() < 0.5 and "ARMOR_C3" or "ARMOR_C4", { dur = rand:NextInteger(35, 55), tint = "black" })
	k.slot("head", "HELMET_C3", { dur = rand:NextInteger(20, 36), tint = "black" })
	k.slot("ears", "HEADSET_COMM")
	k.slot("rig", "RIG_CHEST", { tint = "black" })
	if rand:NextNumber() < 0.4 then
		k.slot("back", "BAG_SLING", { tint = "black" })
	end
	local tac = rand:NextNumber() < 0.65
	if rand:NextNumber() < 0.5 then
		k.gun("primary", "KST_RIFLE", "KST_MAG", "A76_PS", rand:NextInteger(2, 3), nil, tac and "KST_TAC" or nil)
	else
		k.gun("primary", "R17_RIFLE", "R17_MAG", "A62_AP", rand:NextInteger(2, 3), nil, tac and "R17_PATROL" or nil)
	end
	k.put("MEDKIT_M")
	k.put(rand:NextNumber() < 0.5 and "TOURNIQUET" or "BANDAGE")
	k.put("GREN_RK5")
	if rand:NextNumber() < 0.4 then
		k.put("GREN_F7")
	end
	if rand:NextNumber() < 0.3 then
		k.put("GREN_SMOKE")
	end
	k.roll("drawer", rand:NextInteger(0, 2))
	-- the crew wear class 2 glasses now and then (blocked by a gas mask, which they do not carry)
	if rand:NextNumber() < 0.3 then
		k.slot("eyes", "GLASSES_AF2", { dur = rand:NextInteger(15, 30) })
	end
	return k.h
end

-- Random scav kit (player scavs now, AI scavs in M8): a cheap weapon with some ammo, maybe a rig/pack,
-- a few meds and junk. None of it is found-in-raid.
local SCAV_GUNS = {
	{ "KST_RIFLE", 30, "KST_MAG", "A76_PS" }, { "SPARROW_SMG", 25, "SPARROW_MAG", "A9_PST" }, { "HARROW12", 25, nil, "A12_BUCK" },
	{ "TUNDRA_BOLT", 8, nil, "A76L_LPS" }, { "R17_RIFLE", 12, "R17_MAG", "A62_FMJ" },
}
local function pickWeighted(rand, list)
	local total = 0
	for _, e in list do
		total += e[2]
	end
	local r = rand:NextNumber() * total
	for _, e in list do
		r -= e[2]
		if r <= 0 then
			return e
		end
	end
	return list[1]
end

function Loot.scavLoadout(rand)
	rand = rand or Random.new()
	local h = Inv.newHolder("raid")
	local function slot(slotName, id, extra)
		local g, it = Inv.newItem(id, 1, extra)
		if Inv.placeSlot(h, g, it, slotName) then
			return g
		end
		return nil
	end
	local gun = pickWeighted(rand, SCAV_GUNS)
	local wd = Items.defs[gun[1]]
	local wg = slot("primary", gun[1])
	h.items[wg].wear = math.floor(rand:NextNumber(32, 82) * 10) / 10 -- scav guns are worn (M11)
	if gun[3] then
		local cap = Items.defs[gun[3]].capacity
		local mg, mag = Inv.newItem(gun[3], 1, { a = rand:NextInteger(math.floor(cap * 0.4), cap), at = gun[4] })
		h.items[mg] = mag
		h.items[wg].mag = mg
		Inv.resize(h, wg)
	else
		local cap = Inv.capacityOf(h, wg) or wd.capacity or 5
		h.items[wg].a = rand:NextInteger(math.max(1, cap - 3), cap)
		h.items[wg].at = gun[4]
	end
	local rig = rand:NextNumber() < 0.7 and slot("rig", rand:NextNumber() < 0.6 and "RIG_BELT" or "RIG_CHEST") or nil
	local back = rand:NextNumber() < 0.5 and slot("back", rand:NextNumber() < 0.6 and "BAG_SLING" or "CANVAS_BAG") or nil
	if rand:NextNumber() < 0.15 then
		slot("armor", "ARMOR_C2", { dur = rand:NextInteger(8, 30) })
	end
	-- mismatched headwear: an old shell now and then, otherwise a beanie or a cap; some cover their face
	local hr = rand:NextNumber()
	if hr < 0.2 then
		slot("head", "HELMET_C2", { dur = rand:NextInteger(6, 20) })
	elseif hr < 0.55 then
		slot("head", "BEANIE", rand:NextNumber() < 0.5 and { tint = "olive" } or nil)
	elseif hr < 0.85 then
		slot("head", "CAP_FIELD", rand:NextNumber() < 0.5 and { tint = "tan" } or nil)
	end
	if rand:NextNumber() < 0.25 then
		slot("face", "GAITER", rand:NextNumber() < 0.5 and { tint = "grey" } or nil)
	end
	if rand:NextNumber() < 0.06 then
		slot("ears", "HEADSET_GS1")
	end
	if rand:NextNumber() < 0.3 then
		local pg = slot("holster", "P9_PISTOL")
		if pg then
			h.items[pg].wear = math.floor(rand:NextNumber(40, 90) * 10) / 10
			local mg, mag = Inv.newItem("P9_MAG", 1, { a = rand:NextInteger(5, 17), at = "A9_PST" })
			h.items[mg] = mag
			h.items[pg].mag = mg
			Inv.resize(h, pg)
		end
	end
	if rand:NextNumber() < 0.7 then
		slot("melee", "FIELD_KNIFE")
	end
	local order = { "pockets" }
	if rig then
		table.insert(order, 1, rig)
	end
	if back then
		table.insert(order, back)
	end
	if gun[3] then
		for _ = 1, rand:NextInteger(0, 2) do
			local cap = Items.defs[gun[3]].capacity
			local g, it = Inv.newItem(gun[3], 1, { a = rand:NextInteger(0, cap), at = gun[4] })
			if it.a == 0 then
				it.at = nil
			end
			Inv.place(h, g, it, order)
		end
	else
		local g, it = Inv.newItem(gun[4], rand:NextInteger(4, 12))
		Inv.place(h, g, it, order)
	end
	for _ = 1, rand:NextInteger(1, 2) do
		local med = ({ "BANDAGE", "BANDAGE", "MEDKIT_S", "PAINKILLERS", "TOURNIQUET" })[rand:NextInteger(1, 5)]
		local g, it = Inv.newItem(med, 1)
		Inv.place(h, g, it, order)
	end
	if rand:NextNumber() < 0.6 then
		local g, it = Inv.newItem(({ "WATER", "STEW", "HARDTACK" })[rand:NextInteger(1, 3)], 1)
		Inv.place(h, g, it, order)
	end
	if rand:NextNumber() < 0.15 then
		local g, it = Inv.newItem("GREN_RK5", 1)
		Inv.place(h, g, it, order)
	end
	for _ = 1, rand:NextInteger(0, 2) do
		local g, it = Loot.rollEntry(rand, "jacket")
		if g then
			Inv.place(h, g, it, order)
		end
	end
	-- sunglasses on some, a gas mask on a few; the mask takes the face slot only when no gaiter is worn and refuses glasses
	if rand:NextNumber() < 0.04 then
		slot("face", "GAS_MASK")
	end
	if rand:NextNumber() < 0.1 then
		slot("eyes", rand:NextNumber() < 0.7 and "GLASSES_SUN" or "GLASSES_RANGE")
	end
	return h
end

function Loot.init(c)
	ctx = c
	for _, spot in ctx.World.containers do
		local entry = { id = spot.id, kind = spot.kind, label = spot.label, part = spot.part, holder = Inv.newHolder("box", 5, 4), order = {}, revealed = {}, viewers = {}, searching = {} }
		containers[spot.id] = entry
		spot.prompt.Triggered:Connect(function(player)
			Loot.open(player, spot.id)
		end)
	end
	ctx.Remotes.onReq("loot", function(player, p)
		if p.op == "close" and type(p.cid) == "string" then
			Loot.close(player, p.cid)
		end
		return ctx.Remotes.ok()
	end, 6, 8)
end

return Loot
