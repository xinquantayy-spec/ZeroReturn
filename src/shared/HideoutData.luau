--!strict
-- Hideout (Tarkov-style): modules built and upgraded with money and items over real time; built modules give
-- bonuses and unlock crafts that also run in real time (even while offline). Server truth: Hideout.luau.
local H = {}

-- levels[i] = { cost = MK, items = { { id, n } }, needs = { { module, level } }, time = seconds, effect = text }
H.modules = {
	generator = {
		name = "GENERATOR", desc = "Powers the other modules.",
		levels = {
			{ cost = 40000, items = { { "FUEL_CAN", 1 }, { "SPARK_PLUG", 2 } }, needs = {}, time = 300, effect = "Power for the hideout" },
		},
	},
	medstation = {
		name = "MEDSTATION", desc = "Treat wounds faster between raids; craft medical supplies.",
		levels = {
			{ cost = 30000, items = { { "BANDAGE", 2 }, { "MEDKIT_S", 2 } }, needs = { { "generator", 1 } }, time = 600, effect = "Hideout healing x2" },
			{ cost = 120000, items = { { "MEDKIT_M", 2 }, { "MED_TOOLS", 1 } }, needs = { { "generator", 1 } }, time = 1800, effect = "Hideout healing x4" },
		},
	},
	workbench = {
		name = "WORKBENCH", desc = "Ammunition and gear crafts.",
		levels = {
			{ cost = 60000, items = { { "BOLTS", 3 }, { "DUCT_TAPE", 2 }, { "WIRES", 2 } }, needs = { { "generator", 1 } }, time = 900, effect = "Ammunition crafts" },
			{ cost = 180000, items = { { "LOGIC_BOARD", 1 }, { "CAPACITOR", 2 } }, needs = { { "generator", 1 } }, time = 2400, effect = "Advanced crafts" },
		},
	},
	storage = {
		name = "STORAGE RACKS", desc = "More rows in your stash.",
		levels = {
			{ cost = 80000, items = { { "BOLTS", 2 }, { "WIRES", 2 } }, needs = {}, time = 600, effect = "Stash 10x25" },
			{ cost = 250000, items = { { "LOGIC_BOARD", 1 }, { "FUEL_CAN", 1 } }, needs = { { "generator", 1 } }, time = 2400, effect = "Stash 10x30" },
		},
	},
	nutrition = {
		name = "WATER COLLECTOR", desc = "Collects and filters rainwater.",
		levels = {
			{ cost = 25000, items = { { "WATER", 1 }, { "DUCT_TAPE", 1 } }, needs = { { "generator", 1 } }, time = 600, effect = "Water crafts" },
		},
	},
}
H.ORDER = { "generator", "medstation", "workbench", "storage", "nutrition" }

-- stash rows by storage level
H.STASH_ROWS = { [0] = 20, [1] = 25, [2] = 30 }
-- hideout healing multiplier by medstation level
H.HEAL_RATE = { [0] = 1, [1] = 2, [2] = 4 }

-- crafts: module + level, inputs, output { id, n }, time (seconds)
H.recipes = {
	{ id = "AMMO_FMJ", module = "workbench", level = 1, give = { { "BOLTS", 1 } }, get = { "A62_FMJ", 60 }, time = 900 },
	{ id = "AMMO_PST", module = "workbench", level = 1, give = { { "BOLTS", 1 } }, get = { "A9_PST", 50 }, time = 900 },
	{ id = "AMMO_AP", module = "workbench", level = 2, give = { { "A62_FMJ", 60 }, { "CAPACITOR", 1 } }, get = { "A62_AP", 60 }, time = 2400 },
	{ id = "AMMO_BP", module = "workbench", level = 2, give = { { "A76_PS", 60 }, { "CERAMIC_FUSE", 2 } }, get = { "A76_BP", 60 }, time = 2700 },
	{ id = "NADE_RK5", module = "workbench", level = 1, give = { { "BOLTS", 1 }, { "MATCHES", 1 } }, get = { "GREN_RK5", 2 }, time = 1500 },
	{ id = "NADE_SMOKE", module = "workbench", level = 1, give = { { "CIGARETTES", 2 }, { "MATCHES", 1 } }, get = { "GREN_SMOKE", 1 }, time = 1200 },
	{ id = "GUN_KIT", module = "workbench", level = 2, give = { { "DUCT_TAPE", 2 }, { "BOLTS", 2 }, { "WIRES", 1 } }, get = { "WEAPON_KIT", 1 }, time = 2400 },
	{ id = "MED_ROAD", module = "medstation", level = 1, give = { { "MEDKIT_S", 2 }, { "BANDAGE", 1 } }, get = { "MEDKIT_M", 1 }, time = 1200 },
	{ id = "MED_HEMO", module = "medstation", level = 2, give = { { "MEDKIT_M", 1 }, { "TOURNIQUET", 1 } }, get = { "HEMOSTAT", 1 }, time = 1800 },
	{ id = "WATER", module = "nutrition", level = 1, give = {}, get = { "WATER", 1 }, time = 1800 },
}
H.byRecipe = {}
for _, r in H.recipes do
	H.byRecipe[r.id] = r
end

return H
