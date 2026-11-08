--!strict
-- Hideout (decision economy-7b, "Economy core, about 14"): Escape from Tarkov's hideout modules with EFT's levels,
-- construction requirements, bonuses and crafts, the generator's fuel, the scav case and the bitcoin farm. Pure data and
-- pure rules (bonuses, power, ticking the clocks, the migration of old saves, scav case rolls), shared by the server
-- (Hideout.luau), the HIDEOUT screen (Trade.luau) and HideoutTests. The server re-checks every request.
--
-- Where the numbers come from (fetched 2026-11-08): each module's levels, requirements, build times, bonuses and crafts
-- from tarkovforge.com/hideout/<module> (Hideout Tracker, EFT 1.1); fuel per unit and tank sizes from the EFT wiki
-- (escapefromtarkov.fandom.com/wiki/Hideout: "every 1 fuel resource powers the Hideout for 12 minutes and 38 seconds")
-- and GGRecon's fuel guide (expeditionary tank 60 units 12:37:53, metal tank 100 units 21:03:09); the bitcoin farm from
-- timesaver.gg's bitcoin farm guide (1.1.0: 300,000 s a coin with one card, 1 + (cards - 1) x 0.041225, three coins held,
-- 10 / 25 / 50 cards); the scav case runs from gameslikefinder.com and timesaver.gg (1.1.0: times and item counts); the
-- Fence standing's scav case time modifier from EFT's globals (SPT's copy, FenceSettings ScavCaseTimeModifier); how
-- bonuses add up, power and the bitcoin maths from SPT's server code (HideoutHelper.ts, HideoutController.ts), which
-- follows the game's: each level's bonuses are added to the profile, crafts in powered modules run slowly without
-- power, the farm and fuel stop. The euro at Skier's price (EUR 1 = 191 roubles, tarkovforge.com/currency).
--
-- Ours, by decision: 1 rouble = 1 MK (TraderData's rule); every real-time timer divided by Config.HIDEOUT_TIME_DIV (4,
-- decision economy-4b). Since economy-1a's second slice (2026-11-08) most of EFT's goods and tools have one of ours each;
-- where one still has none, the nearest of ours by what it is stands in (the EFT name is in the comment beside it); EFT modules outside the core (vents, heating, solar
-- power, library, gym, air filtering, booze generator, hall of fame) are not built, so prerequisites on them are left
-- out (noted per level). EFT's crafts whose product has no counterpart here, or that would only turn an item into more
-- of itself, are left out; the rest keep EFT's counts and times.
local Config = require(script.Parent.Config)
local Progress = require(script.Parent.Progress)
local Items = require(script.Parent.Items)

local H: any = {}

H.VERSION = 2 -- profile hideout.v: 2 = the economy-7b shape (Hideout.migrate)

-- every real-time timer divided by this (Config, decision economy-4b)
function H.div(): number
	return Config.HIDEOUT_TIME_DIV or 4
end

-- ── modules ──────────────────────────────────────────────────────────────────────────────────────────────────────
-- levels[i] = { cost = MK, items = { { id, n } }, needs = { { module, level } }, skills = { { skill, level } },
--   ll = { { trader, level } } (EFT has none on these fourteen today), time = EFT seconds (0 = instant), bonus = { [kind] = value },
--   gone = text (EFT prerequisites on modules we do not build) }
-- power = EFT's needsFuel: its crafts start only with power and run at H.NO_POWER without it, its bonuses work only with power
local M: any = {}
H.modules = M

M.security = { -- EFT area 1
	name = "SECURITY", short = "SECURITY", power = false,
	desc = "Doors, wire and a camera on the bunker's entrance. Other modules build on it.",
	levels = {
		{ cost = 20000, items = { { "TAPE_MEASURE", 1 } }, time = 0 }, -- construction measuring tape
		{ cost = 45000, items = { { "PLIERS", 1 }, { "PEN_OIL", 2 }, { "TNT", 2 } }, -- Pliers Elite, WD-40 x2, TP-200 TNT x2
			needs = { { "illumination", 1 }, { "security", 1 } }, skills = { { "endurance", 2 } }, time = 3600 },
		{ cost = 0, items = { { "PHONE", 2 }, { "WIRES", 10 }, { "CRACKED_LENS", 8 }, { "SSD", 1 } }, -- working LCD x2, wires, NIXXOR lens x8, SSD
			needs = { { "illumination", 3 }, { "security", 2 } }, time = 61200 },
	},
}
M.lavatory = { -- EFT area 2; works without power (EFT wiki: "does not require the generator")
	name = "LAVATORY", short = "LAVATORY", power = false,
	desc = "A toilet, a sink and a sewing table. Household and tailoring crafts; repair kits for armour.",
	levels = {
		{ cost = 2000, items = { { "TOILET_PAPER", 1 }, { "SOAP", 1 }, { "TOOTHPASTE", 1 }, { "AWL", 1 } }, time = 0, bonus = { armorKit = 1 } }, -- toilet paper, soap, toothpaste, awl
		{ cost = 0, items = { { "CORR_HOSE", 6 }, { "SCREWS", 6 }, { "POWER_DRILL", 1 }, { "SEWING_KIT", 2 }, { "SEAL_TAPE", 3 } }, -- corrugated hose x6, screws x6, electric drill, sewing kit x2, KEKTAPE x3
			needs = { { "water", 1 }, { "lavatory", 1 } }, gone = "VENTS 1", time = 3600, bonus = { armorKitCost = 3 } },
		{ cost = 0, items = { { "CORR_HOSE", 10 }, { "PRESSURE_GAUGE", 2 }, { "TOOLSET", 1 }, { "FOAM", 6 } }, -- hose x10, pressure gauge x2, toolset, Xenomorph sealing foam x6
			needs = { { "water", 2 }, { "lavatory", 2 } }, gone = "VENTS 2", time = 25200, bonus = { armorKitCost = 6 } },
	},
}
M.stash = { -- EFT area 3: level 1 is the Standard Edition's stash, everyone starts with it
	name = "STASH", short = "STASH", power = false,
	desc = "Your storage. Every level adds rows.",
	levels = {
		{ cost = 0, items = {}, time = 0, rows = 30 },
		{ cost = 2500000, items = { { "HAND_DRILL", 1 }, { "SCREWS", 10 }, { "NAILS", 5 }, { "PEN_OIL", 4 } }, -- hand drill, screws x10, nails x5, WD-40 x4
			needs = { { "stash", 1 } }, gone = "VENTS 1", time = 3600, rows = 40 },
		{ cost = 8500000, items = { { "POWER_DRILL", 2 }, { "SCREWS", 15 }, { "NAILS", 7 } }, -- electric drill x2, screws x15, nails x7
			needs = { { "stash", 2 } }, gone = "VENTS 2, HEATING 2", time = 43200, rows = 50 },
		{ cost = 38200000, items = { { "BOLTS", 10 }, { "NUTS", 10 }, { "FOAM", 8 }, { "RATCHET", 2 } }, -- EUR 200,000 x 191; bolts x10, screw nuts x10, Shustrilo foam x8, ratchet wrench x2
			needs = { { "generator", 3 }, { "workbench", 3 }, { "stash", 3 }, { "intel", 2 } }, gone = "HEATING 3", time = 345600, rows = 68 },
	},
}
M.generator = { -- EFT area 4
	name = "GENERATOR", short = "GENERATOR", power = false,
	desc = "Burns fuel to power the hideout. Without power, crafts crawl and the bitcoin farm stops.",
	levels = {
		{ cost = 100000, items = { { "SPARK_PLUG", 1 } }, needs = { { "security", 1 } }, time = 0, bonus = { fuelSlots = 2 } },
		{ cost = 0, items = { { "RELAY", 10 }, { "MOTOR", 1 }, { "WIRES", 15 }, { "PLIERS", 1 } }, -- phase control relay x10, electric motor, bundle of wires x15, cable cutter
			needs = { { "security", 1 }, { "generator", 1 } }, gone = "VENTS 1", time = 3600, bonus = { fuelSlots = 2 } },
		{ cost = 0, items = { { "RELAY", 12 }, { "MOTOR", 3 }, { "SPARK_PLUG", 16 }, { "PSU", 5 }, { "SPARE_PARTS", 10 } }, -- relay x12, motor x3, spark plug x16, power supply unit x5, metal spare parts x10
			needs = { { "security", 3 }, { "generator", 2 } }, gone = "VENTS 3", time = 57600, bonus = { fuelSlots = 2 } },
	},
}
M.water = { -- EFT area 6 (the old WATER COLLECTOR, id "nutrition" before hideout.v 2)
	name = "WATER COLLECTOR", short = "WATER", power = true,
	desc = "Collects and filters water. Faster hydration recovery; water crafts.",
	levels = {
		{ cost = 0, items = { { "CORR_HOSE", 4 }, { "BOLTS", 5 }, { "NUTS", 5 }, { "DUCT_TAPE", 3 } }, time = 0, bonus = { waterRegen = 10 } }, -- corrugated hose x4, bolts x5, screw nuts x5, duct tape x3
		{ cost = 0, items = { { "CORR_HOSE", 6 }, { "MOTOR", 2 }, { "TOOLSET", 2 }, { "SEAL_TAPE", 5 } }, -- hose x6, electric motor x2, toolset x2, KEKTAPE x5
			needs = { { "workbench", 1 }, { "water", 1 } }, skills = { { "attention", 3 } }, time = 7200, bonus = { waterRegen = 20 } },
		{ cost = 20000, items = { { "PLIERS", 2 }, { "RATCHET", 1 }, { "FOAM", 10 } }, -- Pliers Elite x2, ratchet wrench, Shustrilo foam x10
			needs = { { "generator", 3 }, { "water", 2 } }, gone = "HEATING 2", time = 57600, bonus = { waterRegen = 30, filterSlots = 1 } },
	},
}
M.medstation = { -- EFT area 7
	name = "MEDSTATION", short = "MEDSTATION", power = true,
	desc = "A field surgery. Faster health recovery between raids; medical crafts.",
	levels = {
		{ cost = 50000, items = { { "SYRINGE", 1 }, { "MEDS_PILE", 2 }, { "BANDAGE", 2 } }, time = 0, bonus = { hpRegen = 6 } }, -- disposable syringe, pile of meds, multivitamins (a second pile), aseptic bandage x2
		{ cost = 150000, items = { { "BLOODSET", 2 }, { "SALINE", 6 }, { "MED_TOOLS", 3 }, { "TOURNIQUET", 10 } }, -- bloodset x2, saline x6, medical tools x3, Esmarch x10
			needs = { { "generator", 1 }, { "medstation", 1 } }, skills = { { "health", 2 } }, time = 3600, bonus = { hpRegen = 12 } },
		{ cost = 500000, items = { { "SALINE", 10 }, { "LEDX", 1 }, { "OPHTHALMOSCOPE", 1 } }, -- saline x10, LEDX, ophthalmoscope
			needs = { { "generator", 2 }, { "lavatory", 2 }, { "medstation", 2 } }, skills = { { "vitality", 3 } }, time = 43200, bonus = { hpRegen = 20 } },
	},
}
M.nutrition = { -- EFT area 8 (new: before hideout.v 2 this id was the water collector)
	name = "NUTRITION UNIT", short = "NUTRITION", power = true,
	desc = "A field kitchen. Faster energy recovery; food and drink crafts.",
	levels = {
		{ cost = 25000, items = { { "RELAY", 2 }, { "POWER_CORD", 1 }, { "SALT", 1 } }, -- phase control relay x2, power cord, can of white salt
			needs = { { "generator", 1 } }, time = 0, bonus = { energyRegen = 10 } },
		{ cost = 0, items = { { "WRENCH", 4 }, { "CORR_HOSE", 4 }, { "ALKALI", 2 }, { "RELAY", 3 } }, -- wrench x4, corrugated hose x4, alkaline cleaner x2, relay x3
			needs = { { "lavatory", 2 }, { "nutrition", 1 } }, time = 0, bonus = { energyRegen = 20, hpRegen = 7 } },
		{ cost = 125000, items = { { "VOLT_DRINK", 5 }, { "SALT", 5 }, { "ALKALI", 2 } }, -- Majaica coffee beans x5, sodium bicarbonate x5 (white salt), Smoked Chimney drain cleaner x2 (alkaline cleaner)
			needs = { { "generator", 2 }, { "lavatory", 2 }, { "stash", 2 }, { "nutrition", 2 } }, skills = { { "metabolism", 3 } }, time = 50400, bonus = { energyRegen = 30, waterRegen = 20 } },
	},
}
M.rest = { -- EFT area 9; whether EFT's rest space needs power is not documented: ours does not
	name = "REST SPACE", short = "REST", power = false,
	desc = "Bunks, a lamp and a radio. Faster recovery between raids.",
	levels = {
		{ cost = 10000, items = { { "DUCT_TAPE", 1 }, { "MATCHES", 1 } }, gone = "VENTS 1", time = 0, bonus = { debuff = 10 } },
		{ cost = 75000, items = { { "HDD", 1 }, { "SIGNAL_COIL", 1 }, { "ES_LAMP", 5 } }, -- DVD drive, magnet, energy-saving lamp x5
			needs = { { "generator", 1 }, { "rest", 1 } }, time = 3600, bonus = { energyRegen = 5, hpRegen = 5 } },
		{ cost = 0, items = { { "POWER_CORD", 5 }, { "WIRES", 10 }, { "CAPACITOR", 5 }, { "LI_BATTERY", 4 } }, -- power cord x5, wires x10, capacitors x5, GreenBat lithium battery x4
			needs = { { "rest", 2 } }, time = 7200, bonus = { hpRegen = 10, maxEnergy = 10 } },
	},
}
M.workbench = { -- EFT area 10
	name = "WORKBENCH", short = "WORKBENCH", power = true,
	desc = "Vices and presses. Ammunition, grenade and repair crafts; weapon repair with repair kits.",
	levels = {
		{ cost = 0, items = { { "NUTS", 2 }, { "BOLTS", 2 }, { "MULTITOOL", 1 } }, time = 0, bonus = { weaponKit = 1 } }, -- screw nuts x2, bolts x2, Leatherman multitool
		{ cost = 0, items = { { "TOOLSET", 3 }, { "POWER_DRILL", 2 }, { "FILE_SET", 1 }, { "BOLTS", 10 }, { "WEAPON_PARTS", 3 } }, -- toolset x3, electric drill x2, set of files "Master", bolts x10, weapon parts x3
			needs = { { "illumination", 1 }, { "workbench", 1 } }, time = 3600, bonus = { weaponKitCost = 3 } },
		{ cost = 395000, items = { { "PLIERS", 2 }, { "GUN_LUBE", 1 }, { "THERMITE", 5 } }, -- Pliers Elite x2, gun lube, can of thermite x5
			needs = { { "generator", 2 }, { "stash", 2 }, { "workbench", 2 } }, time = 39600, bonus = { weaponKitCost = 6 } },
	},
}
M.intel = { -- EFT area 11
	name = "INTELLIGENCE CENTER", short = "INTEL", power = true,
	desc = "Maps, radios and a computer. Shorter scav cooldown, better task pay, faster insurance, a cheaper flea market.",
	levels = {
		{ cost = 0, items = { { "INTEL_FOLDER", 1 }, { "SURVEY_MAPS", 2 }, { "PHONE", 1 }, { "POWER_CORD", 1 } }, -- intelligence folder, topographic survey maps, factory plan map (a second set of maps), working LCD, power cord
			needs = { { "security", 1 }, { "generator", 1 }, { "workbench", 1 } }, gone = "VENTS 1", time = 0, bonus = { scavCooldown = 15, questMoney = 5 } },
		{ cost = 0, items = { { "INTEL_FOLDER", 3 }, { "SECURE_FLASH", 3 }, { "POWER_CORD", 7 }, { "HDD", 8 } }, -- folder x3, secure flash drive x3, power cord x7, damaged hard drive x8
			needs = { { "security", 2 }, { "medstation", 2 }, { "nutrition", 2 }, { "intel", 1 } }, skills = { { "attention", 3 } }, time = 3600, bonus = { questMoney = 10, insuranceTime = 20 } },
		{ cost = 0, items = { { "DECK_TRANSCEIVER", 2 }, { "FLASH_MODULE", 2 }, { "SECURE_FLASH", 8 }, { "MIL_CABLE", 8 }, { "HDD", 2 }, { "MIL_CIRCUIT", 1 } }, -- COFDM transmitter x2, VPX x2, military flash drive x8, military cable x8, magnetic tape x2, GPS amplifier
			needs = { { "workbench", 3 }, { "generator", 3 }, { "intel", 2 } }, time = 86400, bonus = { scavCooldown = 20, fleaFee = 30 } },
	},
}
M.range = { -- EFT area 12 (Relay 7's own firing range stays free to use: the bunker is ours, exception 2)
	name = "SHOOTING RANGE", short = "RANGE", power = false,
	desc = "Lanes and targets. At the top level, combat skills train faster.",
	levels = {
		{ cost = 20000, items = { { "NUTS", 1 }, { "BOLTS", 1 }, { "SPARE_PARTS", 1 } }, needs = { { "illumination", 1 } }, time = 3600 }, -- screw nuts, bolts, metal spare parts
		{ cost = 0, items = { { "TOOLSET", 1 }, { "TAPE_MEASURE", 1 }, { "POWER_DRILL", 1 }, { "SPARE_PARTS", 8 }, { "SCREWS", 3 }, { "WIRES", 6 }, { "SILICONE_TUBE", 3 }, { "MOTOR", 3 }, { "ES_LAMP", 6 }, { "CAMERA", 3 } }, -- toolset, measuring tape, drill, metal spare parts x8, screws x3, wires x6, Poxeram x3 (silicone tubes), electric motor x3, energy-saving lamp x6, WI-FI camera x3
			needs = { { "illumination", 3 }, { "workbench", 2 }, { "range", 1 } }, time = 86400 },
		{ cost = 0, items = { { "FILE_SET", 1 }, { "MULTITOOL", 1 }, { "WIRES", 10 }, { "POWER_CORD", 5 }, { "LOGIC_BOARD", 5 }, { "SPARE_PARTS", 5 }, { "CAPACITOR", 5 }, { "RELAY", 5 } }, -- files "Master", Leatherman, wires x10, power cord x5, PCB x5, metal spare parts x5, capacitors x5, relay x5 (tech manual: no counterpart)
			needs = { { "range", 2 } }, time = 86400, bonus = { skillCombat = 10 } },
	},
}
M.scavcase = { -- EFT area 14; runs without power
	name = "SCAV CASE", short = "SCAV CASE", power = false,
	desc = "Pay the scavs and they bring back what they find. Everything they bring is found in raid.",
	levels = {
		{ cost = 0, items = { { "BRASS_LION", 3 }, { "GOLD_ROOSTER", 1 }, { "SKULL_RING", 6 }, { "GOLD_CHAIN", 8 }, { "CAPT_WATCH", 4 }, { "MOONSHINE", 3 } }, -- bronze lion x3, golden rooster, gold skull ring x6, golden neck chain x8, Roler Submariner x4, moonshine x3 (Lucky Scav junk box: no counterpart)
			needs = { { "intel", 2 } }, time = 288000 },
	},
}
M.illumination = { -- EFT area 15; EFT's levels 2 and 3 need the generator running
	name = "ILLUMINATION", short = "LIGHTS", power = true,
	desc = "Lamps and wiring through the bunker. Other modules build on it.",
	levels = {
		{ cost = 10000, items = { { "LIGHTER", 1 } }, time = 0 }, -- Crickent lighter
		{ cost = 0, items = { { "LIGHTBULB", 14 }, { "WIRES", 10 } }, needs = { { "generator", 1 }, { "illumination", 1 } }, time = 0 },
		{ cost = 50000, items = { { "CAPACITOR", 7 }, { "WIRES", 12 }, { "ES_LAMP", 12 } }, -- capacitors x7, wires x12, energy-saving lamp x12
			needs = { { "generator", 2 }, { "workbench", 1 }, { "illumination", 2 } }, time = 21600 },
	},
}
M.bitcoin = { -- EFT area 20
	name = "BITCOIN FARM", short = "BITCOIN", power = true,
	desc = "Graphics cards mine coins onto cold wallets while the generator runs. Three wallets wait at most.",
	levels = {
		{ cost = 0, items = { { "CPU_FAN", 15 }, { "PSU", 10 }, { "POWER_CORD", 15 }, { "TPLUG", 10 }, { "FLASH_MODULE", 2 } }, -- CPU fan x15, power supply unit x10, power cord x15, T-shaped plug x10, VPX x2
			needs = { { "intel", 2 } }, time = 122400, bonus = { gpuSlots = 10 } },
		{ cost = 0, items = { { "CPU_FAN", 15 }, { "PSU", 10 }, { "LOGIC_BOARD", 15 }, { "RELAY", 10 }, { "POWER_FILTER", 5 } }, -- CPU fan x15, PSU x10, PCB x15, relay x10, military power filter x5
			needs = { { "bitcoin", 1 }, { "generator", 3 } }, time = 180000, bonus = { gpuSlots = 15 } },
		{ cost = 0, items = { { "CPU_FAN", 25 }, { "SILICONE_TUBE", 15 }, { "MOTOR", 10 }, { "PRESSURE_GAUGE", 10 }, { "BATTERY", 2 } }, -- CPU fan x25, silicone tube x15, electric motor x10, pressure gauge x10, 6-STEN-140-M battery x2 (our lead battery)
			needs = { { "bitcoin", 2 }, { "water", 3 } }, gone = "SOLAR POWER 1", time = 381600, bonus = { gpuSlots = 25 } },
	},
}
-- EFT's own order of these areas (its area numbers 1 to 20)
H.ORDER = { "security", "lavatory", "stash", "generator", "water", "medstation", "nutrition", "rest", "workbench", "intel", "range", "scavcase", "illumination", "bitcoin" }

-- ── bonuses ──────────────────────────────────────────────────────────────────────────────────────────────────────
-- Each built level adds its bonuses (SPT HideoutHelper.applyPlayerUpgradesBonuses: a level's bonuses are pushed onto the
-- profile, none removed; tarkovforge's bitcoin slots 10 + 15 + 25 = 50 and west-games.com's scav cooldown calculator,
-- "Level 3 - 35% total cooldown reduction" from the wiki's 15 % and +20 %, confirm it). Kinds that work without power
-- (slots and repair-kit unlocks) are passive; the rest of a powered module's bonuses work only while the generator runs.
H.PASSIVE = { fuelSlots = true, gpuSlots = true, filterSlots = true, weaponKit = true, weaponKitCost = true, armorKit = true, armorKitCost = true }
-- what each kind does here; nope = Zero Return has no such system yet (the bonus is shown, it changes nothing)
H.BONUS = {
	fuelSlots = { fmt = "%+d fuel slots" },
	gpuSlots = { fmt = "%+d graphics card slots" },
	filterSlots = { fmt = "%+d water filter slot", nope = true },
	hpRegen = { fmt = "Health regeneration %+d %%" },
	energyRegen = { fmt = "Energy regeneration %+d %%" },
	waterRegen = { fmt = "Hydration regeneration %+d %%" },
	maxEnergy = { fmt = "Maximum energy %+d", nope = true },
	debuff = { fmt = "Negative effects end %d %% sooner", nope = true },
	scavCooldown = { fmt = "Scav cooldown -%d %%" },
	questMoney = { fmt = "Task money rewards %+d %%" },
	insuranceTime = { fmt = "Insurance returns -%d %% time" },
	fleaFee = { fmt = "Flea market fee -%d %%" },
	weaponKit = { fmt = "Weapon repair with repair kits", flag = true },
	weaponKitCost = { fmt = "Weapon repair kits use -%d %% points" },
	armorKit = { fmt = "Armour repair with repair kits", flag = true, nope = true },
	armorKitCost = { fmt = "Armour repair kits use -%d %% points", nope = true },
	skillCombat = { fmt = "Combat skills train %+d %% faster" },
}

function H.bonusText(kind: string, v: number): string
	local b = H.BONUS[kind]
	if not b then
		return kind
	end
	if b.flag then
		return b.fmt
	end
	return string.format(b.fmt, v)
end

function H.levelOf(hd: any, m: string): number
	return (hd and hd.levels and hd.levels[m]) or 0
end

-- the sum of `kind` over every built level; with powered == false a powered module's non-passive bonuses are left out
function H.bonus(hd: any, kind: string, powered: boolean?): number
	local sum = 0
	for id, mod in M do
		local lv = H.levelOf(hd, id)
		if lv > 0 and (powered ~= false or not mod.power or H.PASSIVE[kind]) then
			for i = 1, math.min(lv, #mod.levels) do
				local b = mod.levels[i].bonus
				if b and b[kind] then
					sum += b[kind]
				end
			end
		end
	end
	return sum
end

-- stash rows by the stash's level (EFT: the stash item itself changes, 10x30 to 10x68)
function H.stashRows(hd: any): number
	local lv = math.max(1, H.levelOf(hd, "stash"))
	return M.stash.levels[math.min(lv, #M.stash.levels)].rows
end

-- ── fuel and power ───────────────────────────────────────────────────────────────────────────────────────────────
-- EFT: a unit of fuel lasts 12 min 38 s (wiki; generatorFuelFlowRate 0.0013194 a second); our FUEL_CAN is EFT's
-- expeditionary fuel tank (2x2, 60 units). Without power a powered module's craft advances at NO_POWER of its speed
-- (EFT wiki: power can be turned off after a craft starts, "this will increase the crafting time by more than 14
-- times"; SPT's generatorSpeedWithoutFuel). Construction and the scav case do not need power.
H.FUEL = { item = "FUEL_CAN", units = 60, sec = 758 }
H.NO_POWER = 0.07

function H.fuelSlots(hd: any): number
	return H.bonus(hd, "fuelSlots", true)
end

function H.fuelUnits(hd: any): number
	local s = 0
	for _, u in (hd and hd.fuel) or {} do
		s += u
	end
	return s
end

-- fuel burnt a real second while the generator runs
function H.burnRate(): number
	return H.div() / H.FUEL.sec
end

function H.powered(hd: any): boolean
	return H.levelOf(hd, "generator") >= 1 and hd.on == true and H.fuelUnits(hd) > 1e-6
end

-- seconds of power left at the current burn (0 when off)
function H.fuelSeconds(hd: any): number
	if not H.powered(hd) then
		return 0
	end
	return H.fuelUnits(hd) / H.burnRate()
end

local function burn(hd: any, units: number)
	while units > 1e-9 and #hd.fuel > 0 do
		local take = math.min(units, hd.fuel[1])
		hd.fuel[1] -= take
		units -= take
		if hd.fuel[1] <= 1e-6 then
			table.remove(hd.fuel, 1)
		end
	end
end

-- ── the bitcoin farm ─────────────────────────────────────────────────────────────────────────────────────────────
-- EFT 1.1.0: 300,000 s a coin with one card, (1 + (cards - 1) x 0.041225) times faster (SPT HideoutHelper.updateBitcoinFarm,
-- read from the client); production only with power; it halts with three coins waiting (five with elite Hideout
-- Management, a skill we do not have). Our physical bitcoin is the COLD_WALLET (FleaRules bans it like EFT's bitcoin).
H.BTC = { time = 300000, boost = 0.041225, cap = 3, gpu = "GPU_CARD", coin = "COLD_WALLET" }

function H.gpuSlots(hd: any): number
	return H.bonus(hd, "gpuSlots", true)
end

-- coins a real second with n cards (0 without cards)
function H.btcRate(n: number): number
	if n <= 0 then
		return 0
	end
	return H.div() * (1 + (n - 1) * H.BTC.boost) / H.BTC.time
end

-- ── crafts ───────────────────────────────────────────────────────────────────────────────────────────────────────
-- { id, module, level, time = EFT seconds, get = { id, n }, give = { { id, n } } (used up), tools = { { id, n } } (taken
-- while the craft runs and given back with the product, as EFT does), eft = EFT's product }
H.recipes = {}
local function R(id: string, module: string, level: number, time: number, get: string, n: number, give: any, tools: any, eft: string)
	table.insert(H.recipes, { id = id, module = module, level = level, time = time, get = { get, n }, give = give, tools = tools, eft = eft })
end
-- the tool a craft holds while it runs and gives back (EFT's own; since economy-1a's second slice each is its own item)
local function T(id: string): any
	return { { id, 1 } }
end
local TOOL = T("MULTITOOL") -- the Leatherman multitool

-- medstation (EFT's multivitamins: a pile of meds; its hydrogen peroxide: saline; its painkillers and drugs: PAINKILLERS)
R("MED_SALEWA", "medstation", 1, 2340, "MEDKIT_L", 1, { { "MEDKIT_M", 2 }, { "TOURNIQUET", 2 } }, nil, "Salewa first aid kit") -- car first aid kit x2, Esmarch x2
R("MED_AI2", "medstation", 1, 1320, "MEDKIT_S", 3, { { "MEDS_PILE", 1 } }, nil, "AI-2 medkit x3") -- pile of meds
R("MED_CMS", "medstation", 1, 2940, "SURGKIT", 1, { { "MED_TOOLS", 1 }, { "MEDKIT_M", 1 }, { "SPLINT", 1 } }, nil, "CMS surgical kit") -- medical tools, car first aid kit, aluminium splint
R("MED_ANTIDOTE", "medstation", 2, 4200, "ANTIDOTE", 1, { { "STIM_ADREN", 1 }, { "MEDKIT_S", 2 }, { "MEDS_PILE", 2 } }, nil, "xTG-12 antidote injector") -- adrenaline, AI-2 x2, pile of meds x2
R("MED_AHF1", "medstation", 2, 2820, "STIM_HEMO", 2, { { "MEDS_PILE", 5 }, { "SYRINGE", 2 }, { "HEMOSTAT", 1 }, { "SILICONE_TUBE", 1 } }, nil, "AHF1-M stimulant injector x2") -- meds x5, syringe x2, CALOK-B, silicone tube
R("MED_IFAK", "medstation", 2, 3000, "MEDKIT_L", 2, { { "MEDS_PILE", 2 }, { "BANDAGE", 2 }, { "TOURNIQUET", 1 } }, nil, "IFAK individual first aid kit x2") -- meds x2, bandage x2, Esmarch
R("MED_PNB", "medstation", 2, 3780, "STIM_STAMINA", 2, { { "MEDKIT_L", 2 }, { "SYRINGE", 2 }, { "SALINE", 2 } }, nil, "PNB (Product 16) stimulant injector x2") -- AFAK x2, syringe x2, saline, hydrogen peroxide
R("MED_SJ1", "medstation", 2, 4980, "STIM_STAMINA", 5, { { "MEDS_PILE", 7 }, { "SALINE", 2 }, { "STIM_REGEN", 3 }, { "PAINKILLERS", 1 } }, nil, "SJ1 TGLabs combat stimulant injector x5") -- meds x7, saline x2, Propital x3, morphine
R("MED_SJ6", "medstation", 3, 5100, "STIM_STAMINA", 2, { { "STIM_STAMINA", 1 }, { "MEDS_PILE", 3 }, { "SALINE", 1 } }, nil, "SJ6 TGLabs combat stimulant injector x2") -- SJ1, meds x2, saline, multivitamins
R("MED_PROPITAL", "medstation", 3, 6900, "STIM_REGEN", 4, { { "PAINKILLERS", 2 }, { "MEDS_PILE", 2 } }, nil, "Propital regenerative stimulant injector x4") -- ibuprofen, Golden Star balm, meds x2
R("MED_GRIZZLY", "medstation", 3, 4500, "MEDKIT_XL", 2, { { "MEDS_PILE", 4 }, { "TOURNIQUET", 2 }, { "SPLINT", 1 } }, nil, "Grizzly medical kit x2") -- meds x4, CAT x2, aluminium splint

-- workbench (EFT's gunpowders "Kite", "Hawk", "Eagle": GUNPOWDER;
-- calibres: 5.56 -> 6.2x40, 5.45 -> 5.4x39, 7.62x39 and .366 -> 7.6x39, 9x18 -> 9x18, 9x19 and 9x21 -> 9x19, 7.62x54R -> 7.6x54R)
R("NADE_RK5", "workbench", 1, 18300, "GREN_RK5", 6, { { "TNT", 2 }, { "FUZE", 3 } }, nil, "RGD-5 hand grenade x6") -- TP-200 x2, fuze x3
R("NADE_STUN", "workbench", 1, 4680, "GREN_STUN", 5, { { "FUZE", 5 }, { "GUNPOWDER", 1 } }, nil, "Zarya stun grenade x5") -- fuze x5, gunpowder "Kite"
R("WB_BULBS", "workbench", 1, 3600, "LIGHTBULB", 4, { { "WIRES", 2 }, { "NAILS", 1 }, { "SPARE_PARTS", 1 } }, nil, "Light bulb x4") -- wires x2, nails, metal spare parts
R("AMMO_PS", "workbench", 1, 4380, "A76_PS", 200, { { "GUNPOWDER", 1 } }, T("AWL"), "7.62x39mm FMJ x200") -- gunpowder "Eagle", awl
R("AMMO_PST", "workbench", 1, 6180, "A918_PST", 140, { { "GUNPOWDER", 1 } }, nil, "9x18mm PMM PstM gzh x140") -- gunpowder "Kite" (Pst gzh for PstM)
R("AMMO_RIP", "workbench", 1, 3300, "A918_PSV", 150, { { "A918_RG", 150 }, { "WIRES", 1 } }, nil, "9x18mm PM SP8 gzh x150") -- RG028 x150, wires (PSV for SP8)
R("AMMO_BP2", "workbench", 1, 8460, "A76_BP", 60, { { "GUNPOWDER", 2 }, { "A76_PS", 100 } }, T("PLIERS"), ".366 TKM AP-M x60") -- gunpowder "Hawk" x2, 7.62x39 PS x100, pliers
R("AMMO_BUCK", "workbench", 1, 5280, "A12_BUCK", 120, { { "NAILS", 1 }, { "GUNPOWDER", 1 } }, TOOL, "12/70 Piranha x120") -- nails, gunpowder "Hawk", multitool
R("WB_DRILL", "workbench", 1, 9000, "HAND_DRILL", 1, { { "NUTS", 1 }, { "BOLTS", 1 }, { "SPARE_PARTS", 2 } }, nil, "Hand drill") -- screw nuts, bolts, metal spare parts x2
R("WB_PLUG", "workbench", 1, 3420, "TPLUG", 3, { { "NAILS", 1 }, { "POWER_CORD", 1 } }, nil, "T-shaped plug x3") -- nails, power cord
R("WB_MAGNET", "workbench", 1, 2580, "SIGNAL_COIL", 1, { { "HDD", 1 } }, T("SCREWDRIVER"), "Magnet") -- hard drive, screwdriver
R("AMMO_LPS", "workbench", 2, 14400, "A76L_LPS", 50, { { "A76_PS", 70 }, { "GUNPOWDER", 1 } }, TOOL, "7.62x54mm R LPS gzh x50") -- FMJ x70, gunpowder "Hawk", multitool
R("WB_GUNPOWDER", "workbench", 2, 5880, "GUNPOWDER", 2, { { "GREN_RK5", 2 }, { "GREN_SMOKE", 1 } }, T("SCREWDRIVER"), "Gunpowder \"Eagle\" x2") -- M67 grenade x2, M18 smoke grenade, screwdriver
R("AMMO_SLUG", "workbench", 2, 4200, "A12_SLUG", 60, { { "A12_BUCK", 60 }, { "GUNPOWDER", 1 }, { "PEN_OIL", 1 } }, TOOL, "12/70 makeshift .50 BMG slug x60") -- 7 mm buckshot x60, gunpowder "Hawk", WD-40, multitool
R("WB_SPARK", "workbench", 2, 7020, "SPARK_PLUG", 1, { { "NUTS", 1 }, { "BOLTS", 2 }, { "LIGHTER", 1 } }, T("PLIERS"), "Spark plug") -- screw nuts, bolts x2, Survl lighter, pliers
R("AMMO_AP", "workbench", 3, 8400, "A62_AP", 90, { { "A62_FMJ", 180 }, { "GUNPOWDER", 2 } }, TOOL, "5.56x45mm M855A1 x90") -- M855 x180, gunpowder "Kite" and "Eagle", multitool
R("AMMO_BP", "workbench", 3, 9420, "A76_BP", 60, { { "A76_PS", 90 }, { "GUNPOWDER", 1 }, { "VOLT_DRINK", 1 } }, { { "PIPE_WRENCH", 1 }, { "POWER_DRILL", 1 } }, "7.62x39mm BP gzh x60") -- PP x90, gunpowder "Eagle", Hot Rod, pipe grip wrench and drill
R("AMMO_9AP", "workbench", 3, 7260, "A9_AP", 150, { { "A9_PST", 150 }, { "GUNPOWDER", 2 } }, T("TOOLSET"), "9x19mm AP 6.3 x150") -- M882 x150, gunpowder "Kite" x2, toolset
R("AMMO_SNB", "workbench", 3, 9480, "A76L_SNB", 30, { { "A76L_LPS", 50 }, { "THERMITE", 1 }, { "GUNPOWDER", 2 } }, T("FILE_SET"), "7.62x54mm R BT gzh x30") -- PS x50, thermite, gunpowder "Eagle" x2, files
R("AMMO_62BP", "workbench", 3, 13020, "A54_BP", 60, { { "A54_PS", 180 }, { "GUNPOWDER", 1 } }, T("TOOLSET"), "5.45x39mm BP gs x60") -- PS x180, gunpowder "Eagle", toolset
R("GUN_KIT", "workbench", 3, 1500, "WEAPON_KIT", 1, { { "GUN_LUBE", 1 }, { "WEAPON_PARTS", 3 }, { "SPARE_PARTS", 2 } }, T("TOOLSET"), "Weapon repair kit") -- gun lube, weapon parts x3, metal spare parts x2, toolset (EFT also takes a used kit to refill; ours makes a new one)

-- lavatory (EFT's fabrics: FABRIC; vodka used to clean: BLEACH; shampoo: SOAP)
R("NADE_SMOKE", "lavatory", 1, 3600, "GREN_SMOKE", 6, { { "CHLORINE", 1 }, { "MATCHES", 1 }, { "DUCT_TAPE", 1 }, { "TOILET_PAPER", 1 } }, nil, "RDG-2B smoke grenade x6") -- chlorine, hunting matches, duct tape, toilet paper
R("LAV_BANDAGE", "lavatory", 1, 1020, "BANDAGE", 10, { { "BANDAGE", 5 }, { "BLEACH", 1 } }, nil, "Army bandage x10") -- aseptic bandage x5, vodka
R("LAV_ASEPTIC", "lavatory", 1, 1920, "BANDAGE", 6, { { "FABRIC", 1 } }, nil, "Aseptic bandage x6") -- fleece fabric
R("LAV_ARAMID", "lavatory", 1, 1980, "FABRIC", 2, { { "ARMOR_C2", 1 } }, TOOL, "Aramid fiber fabric x2") -- PACA soft armor, multitool
R("LAV_RIPSTOP", "lavatory", 1, 2220, "FABRIC", 2, { { "RIG_CHEST", 1 } }, nil, "Ripstop fabric x2") -- scav vest
R("LAV_SOAP", "lavatory", 1, 3000, "SOAP", 6, { { "ALKALI", 1 }, { "SALT", 1 }, { "STEW", 1 } }, nil, "Soap x6") -- alkali, white salt, beef sausage
R("LAV_MODULE3M", "lavatory", 1, 3240, "ARMOR_C2", 1, { { "FABRIC", 2 } }, nil, "BNTI Module-3M body armor") -- aramid, ripstop
R("LAV_ZHUK", "lavatory", 1, 4020, "ARMOR_C3", 1, { { "FABRIC", 2 }, { "PLATE_PE3", 1 } }, nil, "BNTI Zhuk body armor (class 3)") -- aramid, ripstop, Zhuk-3 front plate
R("LAV_6B23", "lavatory", 1, 7020, "ARMOR_C4", 1, { { "PLATE_PC4F", 1 }, { "FABRIC", 2 }, { "BLEACH", 1 } }, nil, "6B23-2 body armor") -- 6B33 front plate, Cordura, aramid, bleach
R("LAV_MAG", "lavatory", 1, 4980, "KST_MAG40", 1, { { "KST_MAG", 4 }, { "SEAL_TAPE", 1 } }, T("SCREWDRIVER"), "AK-74 6L31 60-round magazine") -- 6L23 30-round x4, KEKTAPE, screwdriver
R("LAV_SCAVPACK", "lavatory", 1, 1200, "BAG_SLING", 1, { { "FABRIC", 1 }, { "DUCT_TAPE", 1 } }, nil, "Scav backpack") -- Cordura, insulating tape
R("LAV_FUEL", "lavatory", 2, 3720, "FUEL_CAN", 1, { { "LIGHTER", 4 }, { "SILICONE_TUBE", 1 }, { "WATER", 1 } }, nil, "Expeditionary fuel tank") -- Zibbo x2, Crickent x2, silicone tube, water
R("LAV_COMMANDO", "lavatory", 2, 2820, "RIG_CHEST", 1, { { "FABRIC", 2 } }, T("AWL"), "BlackHawk! Commando chest harness") -- Cordura, ripstop, awl
R("LAV_BLACKROCK", "lavatory", 2, 3600, "RIG_CHEST", 1, { { "RIG_BELT", 1 }, { "FABRIC", 2 } }, nil, "BlackRock chest rig") -- Tarzan M22 rig, ripstop, Cordura
R("LAV_SWITCHBLADE", "lavatory", 2, 2520, "BAG_PATROL", 1, { { "FABRIC", 4 }, { "BLEACH", 1 } }, nil, "Eberlestock F5 Switchblade backpack") -- ripstop x2, Cordura x2, bleach
R("LAV_HELMET", "lavatory", 2, 4320, "HELMET_C3", 1, { { "DUCT_TAPE", 2 }, { "FABRIC", 2 } }, T("FILE_SET"), "MSA ACH TC-2002 MICH helmet") -- duct tape x2, aramid, ripstop, files
R("LAV_CLIN", "lavatory", 2, 2460, "BLEACH", 2, { { "BLEACH", 1 }, { "SOAP", 1 }, { "SILICONE_TUBE", 1 } }, nil, "Clin window cleaner x2") -- vodka, shampoo, silicone tube
R("LAV_SHAMPOO", "lavatory", 1, 2100, "SOAP", 2, { { "SOAP", 1 }, { "JUICE", 1 } }, nil, "Schaman shampoo x2") -- soap, beer

-- nutrition unit (our pantry is small: tinned and boxed food -> STEW, crackers and croutons -> HARDTACK, sodas, teas, purees
-- and beer -> JUICE, energy drinks and coffee -> VOLT_DRINK, sweets -> CHOC_BAR; books and Geiger counters are left out)
R("NUT_WATER", "nutrition", 1, 4020, "WATER", 2, { { "WATER", 1 }, { "SEAL_TAPE", 1 }, { "SILICONE_TUBE", 1 } }, nil, "Emergency Water Ration x2") -- water, KEKTAPE, silicone tube
R("NUT_ENERGY", "nutrition", 1, 6480, "VOLT_DRINK", 4, { { "JUICE", 1 }, { "VOLT_DRINK", 1 }, { "WATER", 1 } }, nil, "Max Energy energy drink x4") -- TarCola, Majaica coffee, water
R("NUT_KVASS", "nutrition", 1, 3780, "JUICE", 2, { { "WATER", 2 }, { "HARDTACK", 2 } }, nil, "Norvinsky kvass x2") -- water x2, Emelya croutons x2
R("NUT_ISKRA", "nutrition", 1, 2880, "STEW", 2, { { "HARDTACK", 2 }, { "STEW", 1 }, { "JUICE", 1 } }, nil, "Iskra ration pack x2") -- crackers x2, Tushonka, Squash
R("NUT_MRE", "nutrition", 1, 2400, "STEW", 2, { { "STEW", 1 }, { "HARDTACK", 2 }, { "CHOC_BAR", 1 } }, nil, "MRE ration pack x2") -- Tushonka, crackers x2, Slickers
R("NUT_SAUSAGE", "nutrition", 1, 1980, "STEW", 3, { { "SALT", 1 }, { "STEW", 1 }, { "TOILET_PAPER", 1 } }, nil, "Salty Dog beef sausage x3") -- white salt, Tushonka, toilet paper
R("NUT_BEER", "nutrition", 3, 36000, "JUICE", 10, { { "HARDTACK", 5 }, { "JUICE", 3 }, { "WATER", 1 } }, nil, "Pevko Light beer x10") -- croutons x5, kvass x3, purified water
R("NUT_HOTROD", "nutrition", 3, 43200, "VOLT_DRINK", 20, { { "WATER", 1 }, { "CHOC_BAR", 1 }, { "VOLT_DRINK", 1 }, { "JUICE", 1 }, { "WATER_FILTER", 1 } }, nil, "Hot Rod energy drink x20") -- purified water, sugar, Majaica, tea, water filter

-- water collector
R("WC_RATION", "water", 2, 1800, "WATER", 2, { { "JUICE", 1 }, { "SILICONE_TUBE", 1 } }, nil, "Emergency Water Ration x2") -- Grand juice, silicone tube
R("WC_PURIFIED", "water", 3, 19500, "WATER", 10, { { "WATER_FILTER", 1 } }, nil, "Canister with purified water") -- 0.66 of a water filter (EFT runs it nonstop; ours is started each time)

-- intelligence center (electronic components: CAPACITOR; CPUs: LOGIC_BOARD; VPX: FLASH_MODULE)
R("INT_FLASH", "intel", 1, 28800, "SECURE_FLASH", 3, { { "CAPACITOR", 1 }, { "PHONE", 1 }, { "SSD", 1 } }, nil, "Secure Flash drive x3") -- electronic components, Golden 1GPhone X, SSD drive
R("INT_FOLDER", "intel", 3, 111600, "INTEL_FOLDER", 1, { { "SECURE_FLASH", 2 } }, nil, "Intelligence folder") -- military flash drive x2 (printer paper left out)
R("INT_GPU", "intel", 3, 54000, "GPU_CARD", 1, { { "LOGIC_BOARD", 4 }, { "CPU_FAN", 2 }, { "RAM_STICK", 1 }, { "FLASH_MODULE", 1 }, { "CAPACITOR", 4 } }, nil, "Graphics card") -- PCB x2, CPU x2, CPU fan x2, RAM, VPX, electronic components x4 (textbook left out)

H.byRecipe = {}
for _, r in H.recipes do
	H.byRecipe[r.id] = r
end

-- real seconds a craft takes: EFT's time / HIDEOUT_TIME_DIV, less the Crafting skill (EFT: 0.75 % a level of the
-- production time, SPT globals ProductionTimeReductionPerLevel; ours reads Progress' crafting rate), never under 5 s
-- (SPT's floor)
function H.craftNeed(r: any, skills: any?): number
	local t = r.time / H.div() * (1 - Progress.bonus(skills, "crafting"))
	return math.max(5, t)
end

function H.buildNeed(def: any): number
	return (def.time or 0) / H.div()
end

-- seconds until a craft with `left` seconds of work finishes, given the power now and how long the fuel lasts
function H.eta(left: number, needsPower: boolean, powered: boolean, fuelSecs: number): number
	if left <= 0 then
		return 0
	end
	if not needsPower then
		return left
	end
	if powered then
		if left <= fuelSecs then
			return left
		end
		return fuelSecs + (left - fuelSecs) / H.NO_POWER
	end
	return left / H.NO_POWER
end

-- ── the scav case ────────────────────────────────────────────────────────────────────────────────────────────────
-- EFT 1.1.0 (gameslikefinder.com, timesaver.gg): five runs, each its time and number of items; the split of those items
-- into EFT's common / rare / superrare tiers is SPT's scavcase.json as recalled (it adds up to the published counts).
-- What each run brings follows the guides' descriptions; tiers are our rarities (common and uncommon / rare / epic and
-- up). Every item comes back found in raid. Fence's standing shortens or stretches the time (EFT globals, below).
H.SCAV = {
	{ id = "MK2500", money = 2500, time = 2500, n = { common = { 1, 2 }, rare = { 0, 0 }, superrare = { 0, 0 } },
		kinds = { food = true, ammo = true }, what = "food and ammunition" },
	{ id = "MK15000", money = 15000, time = 7700, n = { common = { 2, 3 }, rare = { 0, 1 }, superrare = { 0, 0 } },
		kinds = { loot = true, mod = true }, what = "barter goods and weapon parts" },
	{ id = "MK95000", money = 95000, time = 8100, n = { common = { 2, 3 }, rare = { 0, 1 }, superrare = { 0, 1 } },
		kinds = { key = true, mod = true, loot = true, ammo = true, backpack = true, rig = true }, what = "keys, weapon parts, barter goods, ammunition and containers" },
	{ id = "MOONSHINE", item = "MOONSHINE", time = 16800, n = { common = { 2, 3 }, rare = { 1, 2 }, superrare = { 1, 1 } },
		kinds = { weapon = true, pistol = true, armor = true, helmet = true, plate = true }, sets = { "VALUABLES" }, what = "weapons, armour and valuables" },
	{ id = "INTEL", item = "INTEL_FOLDER", time = 19200, n = { common = { 3, 4 }, rare = { 1, 2 }, superrare = { 0, 1 } },
		kinds = { key = true }, sets = { "TECH" }, what = "keys, intelligence and electronics" },
}
H.byScav = {}
for _, s in H.SCAV do
	H.byScav[s.id] = s
end
H.VALUABLES = { OLD_COIN = true, GOLD_CHAIN = true, CAPT_WATCH = true, BRASS_LION = true, COLD_WALLET = true, DECK_TRANSCEIVER = true, MOONSHINE = true,
	GOLD_ROOSTER = true, SKULL_RING = true, LEDX = true }
H.TECH = { INTEL_FOLDER = true, FLASH_MODULE = true, HDD = true, LOGIC_BOARD = true, CAPACITOR = true, GPU_CARD = true, MIL_CIRCUIT = true,
	PHONE = true, RAM_STICK = true, POWER_BANK = true, BATTERY = true, SIGNAL_COIL = true, CERAMIC_FUSE = true, CRACKED_LENS = true, DECK_TRANSCEIVER = true,
	RELAY = true, MOTOR = true, PSU = true, CPU_FAN = true, POWER_CORD = true, TPLUG = true, POWER_FILTER = true, MIL_CABLE = true, ES_LAMP = true, SSD = true,
	SECURE_FLASH = true, SURVEY_MAPS = true, LI_BATTERY = true }
-- never in a run: boss and cult loot (EFT: no boss items), task goods sold only for tasks, tags, hazards, quest items, pouches
H.SCAV_NEVER = { RITUAL_KNIFE = true, RITUAL_AMULET = true, FORESTER_PACK = true, MASK_WELDER = true, MARKER = true, CAMERA = true, BEACON = true, DOGTAG = true }
-- EFT globals FenceSettings.Levels[standing].ScavCaseTimeModifier (SPT's copy): by whole points of Fence standing (karma)
H.SCAV_KARMA = { [-7] = 9, [-6] = 5.5, [-5] = 3.5, [-4] = 3, [-3] = 2, [-2] = 1.5, [-1] = 1.25, [0] = 1, [1] = 0.95, [2] = 0.9, [3] = 0.8, [4] = 0.7, [5] = 0.6, [6] = 0.5 }

function H.scavKarmaMul(karma: number?): number
	local k = math.clamp(math.floor(karma or 0), -7, 6)
	return H.SCAV_KARMA[k] or 1
end

function H.scavNeed(run: any, karma: number?): number
	return run.time * H.scavKarmaMul(karma) / H.div()
end

local TIER_OF = { common = "common", uncommon = "common", rare = "rare", epic = "superrare", legendary = "superrare" }
local poolCache: any = {}
-- the items a run can bring in one tier (sorted ids, so a seeded roll is repeatable)
function H.scavPool(run: any, tier: string): { string }
	local key = run.id .. ":" .. tier
	if poolCache[key] then
		return poolCache[key]
	end
	local list = {}
	for id, d in Items.defs do
		local inSet = false
		for _, s in run.sets or {} do
			if H[s][id] then
				inSet = true
			end
		end
		local ok = (run.kinds[d.kind] or inSet) and not H.SCAV_NEVER[id] and (d.value or 0) > 0
		if ok and run.kinds.loot == nil and d.kind == "loot" and not inSet then
			ok = false
		end
		if ok and TIER_OF[d.rarity or "common"] == tier then
			table.insert(list, id)
		end
	end
	table.sort(list)
	poolCache[key] = list
	return list
end

-- what the scavs bring back: { { id, n, tier } }; rng() in [0, 1). A tier with nothing to offer in this run falls back
-- to the tier below it.
function H.rollScav(run: any, rng: () -> number): { any }
	local out = {}
	for _, tier in { "common", "rare", "superrare" } do
		local lo, hi = run.n[tier][1], run.n[tier][2]
		local k = lo + math.floor(rng() * (hi - lo + 1))
		k = math.min(k, hi)
		for _ = 1, k do
			local list = H.scavPool(run, tier)
			if #list == 0 and tier == "superrare" then
				list = H.scavPool(run, "rare")
			end
			if #list == 0 and tier ~= "common" then
				list = H.scavPool(run, "common")
			end
			if #list > 0 then
				local id = list[math.min(#list, 1 + math.floor(rng() * #list))]
				local d = Items.defs[id]
				local n = 1
				if d.kind == "ammo" then
					n = math.max(1, math.floor(d.stack * (0.5 + 0.5 * rng())))
				end
				table.insert(out, { id = id, n = n, tier = tier })
			end
		end
	end
	return out
end

-- ── requirements (have / need), for the server's check and the screen's lines ─────────────────────────────────────
-- opts = { money, count = fn(id) -> n in the stash, skills, loyalty = fn(trader) -> level }
-- lines: { k = "money" | "item" | "module" | "skill" | "ll", id, need, have, ok }
function H.requirements(hd: any, def: any, opts: any): ({ any }, boolean)
	local lines, all = {}, true
	local function add(k, id, need, have)
		local ok = have >= need
		all = all and ok
		table.insert(lines, { k = k, id = id, need = need, have = have, ok = ok })
	end
	for _, n in def.needs or {} do
		add("module", n[1], n[2], H.levelOf(hd, n[1]))
	end
	for _, s in def.skills or {} do
		add("skill", s[1], s[2], Progress.skillLevel((opts.skills or {})[s[1]] or 0))
	end
	for _, l in def.ll or {} do
		add("ll", l[1], l[2], opts.loyalty and opts.loyalty(l[1]) or 1)
	end
	if (def.cost or 0) > 0 then
		add("money", "MK", def.cost, opts.money or 0)
	end
	for _, e in def.items or def.give or {} do
		add("item", e[1], e[2], opts.count and opts.count(e[1]) or 0)
	end
	for _, e in def.tools or {} do
		add("tool", e[1], e[2], opts.count and opts.count(e[1]) or 0)
	end
	return lines, all
end

-- ── time passing ─────────────────────────────────────────────────────────────────────────────────────────────────
-- Advance the hideout table to `now` (pure; also for time spent offline or in a raid, as EFT's hideout keeps running):
-- the generator burns fuel while it is on and switches itself off when the fuel runs out, crafts advance (full speed with
-- power or in a module that needs none, H.NO_POWER without; crafts started before hideout.v 2 run at full speed), the
-- bitcoin farm mines only with power and stops with three coins waiting, builds and the scav case finish on their clocks.
-- Returns events: { k = "build", m, l } | { k = "craft", m } | { k = "fuel" } | { k = "coin" } | { k = "scav" }.
function H.tick(hd: any, now: number): { any }
	local events = {}
	hd.fuel = hd.fuel or {}
	hd.crafts = hd.crafts or {}
	hd.builds = hd.builds or {}
	local t0 = hd.t or now
	local left = now - t0
	local guard = 0
	while left > 1e-9 and guard < 8 do
		guard += 1
		local powered = H.powered(hd)
		local seg = left
		if powered then
			local out = H.fuelUnits(hd) / H.burnRate()
			if out < seg then
				seg = math.max(0, out)
			end
		end
		for m, c in hd.crafts do
			if (c.done or 0) < (c.need or 0) then
				local mod = M[m]
				local rate = 1
				if not c.legacy and mod and mod.power and not powered then
					rate = H.NO_POWER
				end
				c.done = math.min(c.need, (c.done or 0) + seg * rate)
				if c.done >= c.need then
					table.insert(events, { k = "craft", m = m })
				end
			end
		end
		local b = hd.btc
		if b and powered and H.levelOf(hd, "bitcoin") >= 1 then
			local n = #(b.cards or {})
			if n > 0 and (b.coins or 0) < H.BTC.cap then
				b.prog = (b.prog or 0) + seg * H.btcRate(n)
				while b.prog >= 1 and b.coins < H.BTC.cap do
					b.prog -= 1
					b.coins += 1
					table.insert(events, { k = "coin" })
				end
				if b.coins >= H.BTC.cap then
					b.prog = 0
				end
			end
		end
		if powered then
			burn(hd, seg * H.burnRate())
			if H.fuelUnits(hd) <= 1e-6 then
				table.clear(hd.fuel)
				hd.on = false
				table.insert(events, { k = "fuel" })
			end
		end
		left -= seg
	end
	for m, bd in hd.builds do
		if now >= bd.at then
			hd.levels[m] = math.max(hd.levels[m] or 0, bd.l)
			hd.builds[m] = nil
			table.insert(events, { k = "build", m = m, l = bd.l })
		end
	end
	if hd.scav and not hd.scav.ready and now >= hd.scav.at then
		hd.scav.ready = true
		table.insert(events, { k = "scav" })
	end
	hd.t = math.max(t0, now)
	return events
end

-- ── old saves ────────────────────────────────────────────────────────────────────────────────────────────────────
-- Before hideout.v 2 Relay 7 had five modules: generator, medstation and workbench keep their ids and levels; "storage"
-- (STORAGE RACKS: 10x20, 10x25, 10x30) became the stash, each rack level one stash level above the 10x30 everyone now
-- starts with (no one loses rows or what they paid for); "nutrition" was the WATER COLLECTOR and is now "water" (the id
-- "nutrition" is EFT's nutrition unit). A build under way keeps its finish time; a craft under way keeps its finish time
-- and its product (and runs at full speed, as it did when started).
H.OLD = {
	ids = { generator = "generator", medstation = "medstation", workbench = "workbench", storage = "stash", nutrition = "water" },
	recipes = {
		AMMO_FMJ = { "A62_FMJ", 60 }, AMMO_PST = { "A9_PST", 50 }, AMMO_AP = { "A62_AP", 60 }, AMMO_BP = { "A76_BP", 60 },
		NADE_RK5 = { "GREN_RK5", 2 }, NADE_SMOKE = { "GREN_SMOKE", 1 }, GUN_KIT = { "WEAPON_KIT", 1 }, MED_ROAD = { "MEDKIT_M", 1 },
		MED_HEMO = { "HEMOSTAT", 1 }, WATER = { "WATER", 1 },
	},
}

local function newLevel(oldId: string, l: number): number
	if oldId == "storage" then
		return math.min(#M.stash.levels, 1 + l)
	end
	return math.min(l, #M[H.OLD.ids[oldId]].levels)
end

-- returns true when it changed anything (pure)
function H.migrate(hd: any, now: number): boolean
	if (tonumber(hd.v) or 1) >= H.VERSION then
		return false
	end
	local old = hd.levels or {}
	local lv = {}
	for oldId, l in old do
		local id = H.OLD.ids[oldId]
		if id and type(l) == "number" and l > 0 then
			lv[id] = math.max(lv[id] or 0, newLevel(oldId, l))
		end
	end
	lv.stash = math.max(lv.stash or 0, 1)
	local builds = {}
	local b = hd.build
	if type(b) == "table" and H.OLD.ids[b.m] and type(b.l) == "number" and type(b.at) == "number" then
		local id = H.OLD.ids[b.m]
		local l = newLevel(b.m, b.l)
		if l > (lv[id] or 0) then
			builds[id] = { l = l, at = b.at }
		end
	end
	local crafts = {}
	for oldM, c in hd.crafts or {} do
		local id = H.OLD.ids[oldM]
		local get = type(c) == "table" and H.OLD.recipes[c.r]
		if id and get and type(c.at) == "number" then
			crafts[id] = { r = c.r, get = { get[1], get[2] }, need = math.max(0, c.at - now), done = 0, legacy = true }
		end
	end
	hd.levels = lv
	hd.builds = builds
	hd.build = nil
	hd.crafts = crafts
	hd.fuel = hd.fuel or {}
	hd.on = hd.on == true
	hd.btc = hd.btc or { cards = {}, coins = 0, prog = 0 }
	hd.t = now
	hd.v = H.VERSION
	return true
end

return H
