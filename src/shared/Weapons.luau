--!strict
-- Fictional weapon handling (game feel, not real ballistics). Damage/penetration come from the loaded ammo.
-- rpm, ergo (ADS speed / sway), recoil (vertical/horizontal), reload times (tactical vs empty), modes.
local W = {
	R17 = {
		id = "R17", item = "R17_RIFLE", name = "R-17", class = "rifle", rpm = 650, range = 900, velocity = 880,
		ergo = 48, recoilV = 1.05, recoilH = 0.38, reload = 2.3, reloadEmpty = 2.9, hipSpread = 2.6, aimSpread = 0.22,
		moveSpread = 1.6, modes = { "AUTO", "SEMI" }, loudness = 1, viewmodel = "R17",
	},
	KST = {
		id = "KST", item = "KST_RIFLE", name = "KS-7", class = "rifle", rpm = 600, range = 800, velocity = 715,
		ergo = 40, recoilV = 1.45, recoilH = 0.55, reload = 2.5, reloadEmpty = 3.1, hipSpread = 2.9, aimSpread = 0.28,
		moveSpread = 1.8, modes = { "AUTO", "SEMI" }, loudness = 1.1, viewmodel = "R17",
	},
	SPARROW = {
		id = "SPARROW", item = "SPARROW_SMG", name = "SMG-9", class = "smg", rpm = 800, range = 450, velocity = 400,
		ergo = 70, recoilV = 0.6, recoilH = 0.3, reload = 2.0, reloadEmpty = 2.6, hipSpread = 2.0, aimSpread = 0.3,
		moveSpread = 1.2, modes = { "AUTO", "SEMI" }, loudness = 0.8, viewmodel = "R17",
	},
	HARROW = {
		id = "HARROW", item = "HARROW12", name = "Harrow-12", class = "shotgun", rpm = 70, range = 300, velocity = 400,
		ergo = 52, recoilV = 3.2, recoilH = 0.9, reload = 0.55, reloadEmpty = 0.55, hipSpread = 3.2, aimSpread = 1.4,
		moveSpread = 1.6, modes = { "PUMP" }, loudness = 1.3, internal = true, pelletSpread = 2.6, viewmodel = "R17",
	},
	TUNDRA = {
		id = "TUNDRA", item = "TUNDRA_BOLT", name = "Tundra", class = "bolt", rpm = 45, range = 1400, velocity = 830,
		ergo = 30, recoilV = 3.8, recoilH = 0.7, reload = 0.75, reloadEmpty = 0.75, hipSpread = 4.0, aimSpread = 0.05,
		moveSpread = 2.4, modes = { "BOLT" }, loudness = 1.4, internal = true, viewmodel = "R17",
	},
	P9 = {
		id = "P9", item = "P9_PISTOL", name = "P-9", class = "pistol", rpm = 420, range = 300, velocity = 360,
		ergo = 85, recoilV = 1.3, recoilH = 0.45, reload = 1.7, reloadEmpty = 2.1, hipSpread = 1.8, aimSpread = 0.45,
		moveSpread = 1.0, modes = { "SEMI" }, loudness = 0.85, viewmodel = "R17",
	},
}

-- shared rules
W.HEAD_MULT = 1 -- Tarkov: no generic multipliers; body-part HP pools do the work (see Health)
W.FALLOFF_START = 0.35 -- fraction of range before damage falls off
W.FALLOFF_MIN = 0.6

return W
