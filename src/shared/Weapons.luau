--!strict
-- Fictional weapon handling (game feel, not real ballistics). Damage/penetration come from the loaded ammo.
-- rpm, ergo (ADS speed / sway), recoil (vertical/horizontal), reload times (tactical vs empty), modes.
-- aimSpread is the aimed accuracy in degrees on Tarkov's scale (x60 = MOA): rifles about 3 MOA, the SMG 6, the bolt
-- rifle 1, the pistol 12, the shotgun's slug 36 (2026-10-31 parity pass; recoil and sway still limit real groups).
--
-- Recoil (Tarkov's model, audit decision gameplay-1a; the rules are in Recoil.luau). recoilV / recoilH: the default
-- build's vertical and horizontal recoil as Tarkov shows them for the gun each copies, divided by 100 (the gunsmith
-- screen shows x100): Tarkov's base figure times its default preset's part modifiers summed, Tarkov 1.0 after the
-- 1.0.4.5 barrel and handguard rework (tarkovforge.com weapon and attachment pages, read 2026-11-08):
--   R-17 = M4A1 119 / 342, -33.4 % (M4SS stock -20.5, carbine buffer tube -0.5, 14.5" barrel -7.4, A2 flash hider -5)
--   KS-7 = AKM 121 / 298, -26 % (wooden stock -22, slant brake -4)
--   SMG-9 = MP5 56 / 275, -23 % (our default has the A3 stock; Tarkov's preset shows 43 / 209, the A2 stock's -24 %)
--   Harrow-12 = MP-133 397 / 522, -27 % (wooden stock -24, 510 mm barrel -3)
--   Tundra = Mosin infantry 288 / 877, -38.3 % (730 mm barrel -18.3, infantry stock -20; our base has the barrel)
--   P-9 = MP-443 Grach 425 / 310 (none of its parts change it)
-- (The EFT wiki's infoboxes still show the M4A1 at 84 / 243 and the Mosin at 202 / 614, a flat -29 and -30 %: most
-- likely the figures from before 1.0.4.5 moved recoil from handguards to barrels.)
-- Tarkov's horizontal figure is the rearward kick into the shoulder; the sideways throw comes from the recoil angle's
-- dispersion (VK "Tarkovskoe Metadvizhenie", 13 March 2023). Ours, by class (Tarkov's per-gun figures were out of reach:
-- tarkov.dev and SPT's item templates): recoilAngle (90 = straight up, more = left), recoilDisp (degrees either side;
-- the same article gives 12 for the steadiest rifle, 35 for a jumpy SMG), recoilConv (the pull back to the aim point, a
-- second, at 50 ergonomics), recoilCam (the camera's share of the gun's kick), recoilStable (full auto settles after
-- this shot; 0 for guns that cannot fire it).
local W = {
	R17 = {
		id = "R17", item = "R17_RIFLE", name = "R-17", class = "rifle", rpm = 650, range = 900, velocity = 880,
		ergo = 48, recoilV = 0.79, recoilH = 2.28, reload = 2.3, reloadEmpty = 2.9, hipSpread = 2.6, aimSpread = 0.05,
		recoilAngle = 90, recoilDisp = 18, recoilConv = 6, recoilCam = 0.4, recoilStable = 4,
		moveSpread = 1.6, modes = { "AUTO", "SEMI" }, loudness = 1, viewmodel = "R17", draw = 0.75,
		slots = { rail = true, muzzle = "6.2", under = true, side = true },
	},
	KST = {
		id = "KST", item = "KST_RIFLE", name = "KS-7", class = "rifle", rpm = 600, range = 800, velocity = 715,
		ergo = 40, recoilV = 0.9, recoilH = 2.21, reload = 2.5, reloadEmpty = 3.1, hipSpread = 2.9, aimSpread = 0.057,
		recoilAngle = 90, recoilDisp = 26, recoilConv = 5, recoilCam = 0.5, recoilStable = 4,
		moveSpread = 1.8, modes = { "AUTO", "SEMI" }, loudness = 1.1, viewmodel = "KST", draw = 0.8,
		slots = { rail = true, muzzle = "7.6", under = true, side = true },
	},
	-- THE CARETAKER's light machine gun (decision ai-5b) in the place of EFT's RPK-16: 650 rounds a minute, ergonomics 45,
	-- recoil 106 / 316, single and full auto, 650 m effective (TarkovForge's RPK-16 page); a 7.6 KS-7 action here, so the
	-- muzzle speed is the KS-7's with a longer barrel (ours)
	KSL = {
		id = "KSL", item = "KSL_LMG", name = "KS-L", class = "lmg", rpm = 650, range = 650, velocity = 745,
		ergo = 45, recoilV = 1.06, recoilH = 3.16, reload = 3.2, reloadEmpty = 3.9, hipSpread = 3.4, aimSpread = 0.05,
		recoilAngle = 90, recoilDisp = 22, recoilConv = 4, recoilCam = 0.45, recoilStable = 6,
		moveSpread = 2.2, modes = { "AUTO", "SEMI" }, loudness = 1.15, viewmodel = "KST", draw = 1.0,
		slots = { rail = true, muzzle = "7.6", under = true, side = true },
	},
	-- the KS-74 (economy-1a, third slice) in the place of EFT's AK-74N: 650 rounds a minute, single and full auto, 650 m
	-- effective, recoil 96 / 244 (tarkovforge.com's AK-74N page, read 2026-11-08) with its default build's stock and brake
	-- (-22 % for the stock, the AKM wooden stock's figure as the AK-74's page was out of reach, and the brake's -5 %): 70 /
	-- 178; ergonomics near the KS-7's (EFT's list gives the AK-74N 31, ours runs higher for every gun); 900 m/s with PS
	KS74 = {
		id = "KS74", item = "KS74_RIFLE", name = "KS-74", class = "rifle", rpm = 650, range = 650, velocity = 900,
		ergo = 38, recoilV = 0.7, recoilH = 1.78, reload = 2.5, reloadEmpty = 3.1, hipSpread = 2.8, aimSpread = 0.055,
		recoilAngle = 90, recoilDisp = 22, recoilConv = 5, recoilCam = 0.45, recoilStable = 4,
		moveSpread = 1.8, modes = { "AUTO", "SEMI" }, loudness = 1.05, viewmodel = "KST", draw = 0.8,
		slots = { rail = true, muzzle = "5.4", under = true, side = true },
	},
	-- the SK-45 (economy-1a, fourth slice) in the place of EFT's SKS: single shots, ergonomics 40, recoil 155 / 360, 400 m
	-- (tarkovforge.com's SKS page; its figures are taken as the built gun's, which has no parts); a fixed 10-round magazine
	-- loaded a round at a time (EFT also takes stripper clips: logged); 735 m/s with PS (its 520 mm barrel)
	SKS = {
		id = "SKS", item = "SKS_RIFLE", name = "SK-45", class = "rifle", rpm = 400, range = 400, velocity = 735,
		ergo = 40, recoilV = 1.55, recoilH = 3.6, reload = 0.6, reloadEmpty = 0.6, hipSpread = 2.9, aimSpread = 0.057,
		recoilAngle = 90, recoilDisp = 20, recoilConv = 5, recoilCam = 0.5, recoilStable = 0,
		moveSpread = 1.9, modes = { "SEMI" }, loudness = 1.1, internal = true, viewmodel = "TUNDRA", draw = 0.85,
		slots = {},
	},
	-- the MR-10 (economy-1a, fourth slice) in the place of EFT's SVDS: single shots, ergonomics 47, recoil 220 / 647 (its
	-- flash hider changes nothing here), about 900 m (tarkovforge.com's SVDS page); 830 m/s with LPS (its 620 mm barrel).
	-- EFT counts it a marksman rifle with a skill of its own; here it trains the rifle skill (logged)
	SVD = {
		id = "SVD", item = "SVD_RIFLE", name = "MR-10", class = "rifle", rpm = 400, range = 900, velocity = 830,
		ergo = 47, recoilV = 2.2, recoilH = 6.47, reload = 3.0, reloadEmpty = 3.6, hipSpread = 3.4, aimSpread = 0.03,
		recoilAngle = 90, recoilDisp = 14, recoilConv = 4, recoilCam = 0.5, recoilStable = 0,
		moveSpread = 2.2, modes = { "SEMI" }, loudness = 1.35, viewmodel = "KST", draw = 0.9,
		slots = { rail = true, muzzle = "7.6L" },
	},
	-- the S-14 (economy-1a, fifth slice) in the place of EFT's M1A: single shots, ergonomics 28, recoil 214 / 405, 700 m
	-- (tarkovforge.com's M1A page; its figures are taken as the built gun's); 820 m/s with the ball round (ours: EFT's M80
	-- speed, the barrel's own change not found)
	M1A = {
		id = "M1A", item = "M1A_RIFLE", name = "S-14", class = "rifle", rpm = 700, range = 700, velocity = 820,
		ergo = 28, recoilV = 2.14, recoilH = 4.05, reload = 3.0, reloadEmpty = 3.6, hipSpread = 3.4, aimSpread = 0.033,
		recoilAngle = 90, recoilDisp = 14, recoilConv = 4, recoilCam = 0.5, recoilStable = 0,
		moveSpread = 2.2, modes = { "SEMI" }, loudness = 1.35, viewmodel = "KST", draw = 0.9,
		slots = { rail = true, muzzle = "7.6N" },
	},
	-- the OB-7 (economy-1a, fifth slice) in the place of EFT's Remington Model 700: bolt action, ergonomics 49, recoil
	-- 199 / 670, 1,000 m (tarkovforge.com's M700 page); a detachable box magazine; 840 m/s with the ball round (ours, its
	-- 26-inch barrel)
	M700 = {
		id = "M700", item = "M700_BOLT", name = "OB-7", class = "bolt", rpm = 30, range = 1000, velocity = 840,
		ergo = 49, recoilV = 1.99, recoilH = 6.7, reload = 2.8, reloadEmpty = 3.6, hipSpread = 4.0, aimSpread = 0.012,
		recoilAngle = 90, recoilDisp = 8, recoilConv = 4, recoilCam = 0.5, recoilStable = 0,
		moveSpread = 2.4, modes = { "BOLT" }, loudness = 1.35, viewmodel = "TUNDRA", draw = 0.9,
		slots = { rail = true },
	},
	-- the SV-9 and AV-9 (economy-1a, sixth slice) in the place of EFT's VSS Vintorez and AS VAL: single shots or bursts at
	-- 900 a minute, ergonomics 43, recoil 80 / 270, 400 m (tarkovforge.com's VSS and AS VAL pages give both the same
	-- figures; taken as the built guns'); 290 m/s with SP-5. Their integral suppressors (barrel parts) make them quiet
	VSS = {
		id = "VSS", item = "VSS_RIFLE", name = "SV-9", class = "rifle", rpm = 900, range = 400, velocity = 290,
		ergo = 43, recoilV = 0.8, recoilH = 2.7, reload = 2.6, reloadEmpty = 3.2, hipSpread = 2.8, aimSpread = 0.045,
		recoilAngle = 90, recoilDisp = 18, recoilConv = 5, recoilCam = 0.45, recoilStable = 4,
		moveSpread = 1.8, modes = { "SEMI", "AUTO" }, loudness = 0.4, viewmodel = "KST", draw = 0.8,
		slots = { rail = true },
	},
	VAL = {
		id = "VAL", item = "VAL_RIFLE", name = "AV-9", class = "rifle", rpm = 900, range = 400, velocity = 290,
		ergo = 43, recoilV = 0.8, recoilH = 2.7, reload = 2.5, reloadEmpty = 3.1, hipSpread = 2.7, aimSpread = 0.05,
		recoilAngle = 90, recoilDisp = 20, recoilConv = 5, recoilCam = 0.45, recoilStable = 4,
		moveSpread = 1.8, modes = { "AUTO", "SEMI" }, loudness = 0.42, viewmodel = "KST", draw = 0.75,
		slots = { rail = true },
	},
	-- the PW-46 and PD-57 (economy-1a, seventh slice) in the place of EFT's HK MP7A1 and FN P90: single shots or bursts,
	-- 200 m; MP7A1 ergonomics 65, recoil 50 / 178, 950 a minute; P90 ergonomics 60, recoil 54 / 243, 900 a minute
	-- (tarkovforge.com's pages, taken as the built guns'); speeds those of FMJ SX and SS190
	MP7 = {
		id = "MP7", item = "MP7_SMG", name = "PW-46", class = "smg", rpm = 950, range = 200, velocity = 620,
		ergo = 65, recoilV = 0.5, recoilH = 1.78, reload = 2.0, reloadEmpty = 2.6, hipSpread = 2.0, aimSpread = 0.1,
		recoilAngle = 90, recoilDisp = 18, recoilConv = 7, recoilCam = 0.35, recoilStable = 5,
		moveSpread = 1.1, modes = { "AUTO", "SEMI" }, loudness = 0.8, viewmodel = "SPARROW", draw = 0.5,
		slots = { rail = true },
	},
	P90 = {
		id = "P90", item = "P90_SMG", name = "PD-57", class = "smg", rpm = 900, range = 200, velocity = 715,
		ergo = 60, recoilV = 0.54, recoilH = 2.43, reload = 2.6, reloadEmpty = 3.2, hipSpread = 2.1, aimSpread = 0.1,
		recoilAngle = 90, recoilDisp = 18, recoilConv = 7, recoilCam = 0.35, recoilStable = 5,
		moveSpread = 1.2, modes = { "AUTO", "SEMI" }, loudness = 0.85, viewmodel = "SPARROW", draw = 0.55,
		slots = {},
	},
	-- MORTAR's grenade launcher (ai-5b) in the place of EFT's M32A1: 76 m/s, single shots from a six-round cylinder
	-- loaded one round at a time; the round flies as a grenade (Grenades.launchFrom). Rate 30, ergonomics 30, recoil
	-- 238 / 560 and an effective distance of 70 m (219 studs) as tarkovforge's M32A1 page gives them
	GL6 = {
		id = "GL6", item = "GL6_LAUNCHER", name = "GL-6", class = "launcher", launcher = true, rpm = 30, range = 219, velocity = 76,
		ergo = 30, recoilV = 2.38, recoilH = 5.6, reload = 0.8, reloadEmpty = 0.8, hipSpread = 3.0, aimSpread = 0.12,
		recoilAngle = 90, recoilDisp = 10, recoilConv = 3, recoilCam = 0.6, recoilStable = 0,
		moveSpread = 2.0, modes = { "SEMI" }, loudness = 0.7, internal = true, viewmodel = "KST", draw = 1.1,
		slots = { rail = true },
	},
	SPARROW = {
		id = "SPARROW", item = "SPARROW_SMG", name = "SMG-9", class = "smg", rpm = 800, range = 450, velocity = 400,
		ergo = 70, recoilV = 0.43, recoilH = 2.12, reload = 2.0, reloadEmpty = 2.6, hipSpread = 2.0, aimSpread = 0.1,
		recoilAngle = 90, recoilDisp = 20, recoilConv = 7, recoilCam = 0.35, recoilStable = 5,
		moveSpread = 1.2, modes = { "AUTO", "SEMI" }, loudness = 0.8, viewmodel = "SPARROW", draw = 0.6,
		slots = { rail = true, muzzle = "9", under = true, side = true },
	},
	HARROW = {
		id = "HARROW", item = "HARROW12", name = "Harrow-12", class = "shotgun", rpm = 70, range = 300, velocity = 400,
		ergo = 52, recoilV = 2.9, recoilH = 3.81, reload = 0.55, reloadEmpty = 0.55, hipSpread = 3.2, aimSpread = 0.6,
		recoilAngle = 90, recoilDisp = 12, recoilConv = 4, recoilCam = 0.6, recoilStable = 0,
		moveSpread = 1.6, modes = { "PUMP" }, loudness = 1.3, internal = true, pelletSpread = 2.6, viewmodel = "HARROW", draw = 0.8,
		slots = { rail = true, side = true },
	},
	TUNDRA = {
		id = "TUNDRA", item = "TUNDRA_BOLT", name = "Tundra", class = "bolt", rpm = 45, range = 1400, velocity = 830,
		ergo = 30, recoilV = 1.78, recoilH = 5.41, reload = 0.75, reloadEmpty = 0.75, hipSpread = 4.0, aimSpread = 0.017,
		recoilAngle = 90, recoilDisp = 8, recoilConv = 4, recoilCam = 0.5, recoilStable = 0,
		moveSpread = 2.4, modes = { "BOLT" }, loudness = 1.4, internal = true, viewmodel = "TUNDRA", draw = 0.9,
		slots = { rail = true },
	},
	P9 = {
		id = "P9", item = "P9_PISTOL", name = "P-9", class = "pistol", rpm = 420, range = 300, velocity = 360,
		ergo = 85, recoilV = 4.25, recoilH = 3.1, reload = 1.7, reloadEmpty = 2.1, hipSpread = 1.8, aimSpread = 0.2,
		recoilAngle = 90, recoilDisp = 12, recoilConv = 7, recoilCam = 0.55, recoilStable = 0,
		moveSpread = 1.0, modes = { "SEMI" }, loudness = 0.85, viewmodel = "P9", draw = 0.45,
		slots = { muzzle = "9", side = true },
	},
	-- the Makar PM (economy-1a, third slice) in the place of EFT's PM: single shots, ergonomics 85, recoil 380 / 265 (no
	-- part changes it), 50 m effective (tarkovforge.com's PM page); 302 m/s with P gzh
	PM = {
		id = "PM", item = "PM_PISTOL", name = "PM", class = "pistol", rpm = 400, range = 50, velocity = 302,
		ergo = 85, recoilV = 3.8, recoilH = 2.65, reload = 1.6, reloadEmpty = 2.0, hipSpread = 1.9, aimSpread = 0.25,
		recoilAngle = 90, recoilDisp = 12, recoilConv = 7, recoilCam = 0.55, recoilStable = 0,
		moveSpread = 1.0, modes = { "SEMI" }, loudness = 0.8, viewmodel = "P9", draw = 0.45,
		slots = { side = true },
	},
	KNIFE = {
		id = "KNIFE", item = "FIELD_KNIFE", name = "Knife", class = "melee", rpm = 90, range = 6, velocity = 0,
		ergo = 90, recoilV = 0, recoilH = 0, reload = 0, reloadEmpty = 0, hipSpread = 0, aimSpread = 0, moveSpread = 0,
		modes = { "SLASH" }, loudness = 0.1, viewmodel = "KNIFE", draw = 0.35, melee = true, damage = 38, pen = 6, slots = {},
	},
}

-- shared rules
W.HEAD_MULT = 1 -- Tarkov: no generic multipliers; body-part HP pools do the work (see Health)
W.FALLOFF_START = 0.35 -- fraction of range before damage falls off
W.FALLOFF_MIN = 0.6

-- ── heat, wear and malfunctions (Tarkov; audit gameplay.11) ──────────────────────────────────────────────────────
-- Pure rules used by the server (Combat: wear, malfunctions, cook-offs) and the client (Weapon: spread, the rate of fire
-- when hot). Tarkov's own rules and globals: the EFT wiki's Weapon_malfunctions page; the game's code as read for the TRP
-- spec (github.com/JuanFNQ/TRP, docs/spec/malfunctions.md, 2026-10-25, with a recorded AKM); SPT's copy of the globals
-- (github.com/7ripleSeven7s/spt-diffpatch, test/g-test.json: Overheat and Malfunction). Heat runs 0 to 200 as in Tarkov.
W.OVERHEAT = {
	MAX = 200, -- MaxOverheat
	PROBLEMS = 100, -- OverheatProblemsStart: the wiki's medium stage, where heat starts to hurt
	WEAR = { 1, 3 }, -- DurReduceMinMult, DurReduceMaxMult: a shot's wear x1 at 100, x3 at 200
	MALF = { 0.5, 9 }, -- MinMalfChance, MaxMalfChance: the heat's malfunction chance, per mille, from 100 to 200
	SPREAD = 1.5, -- MaxCOIIncreaseMult: a shot's spread x1 at 100, x1.5 at 200
	MAXWEAR = { 0.1, 0.2 }, -- MinWearOnOverheat, MaxWearOnOverheat: greatest durability a hot shot takes, 100 to 200
	MAXWEAR_TOP = { 0.2, 0.7 }, -- MinWearOnMaxOverheat, MaxWearOnMaxOverheat: drawn at the top heat
	MAXWEAR_FLOOR = 55, -- OverheatWearLimit 0.55: heat never takes the greatest durability below 55
	RATE_ABOVE = 140, -- FirerateOverheatBorder: the wiki's severe stage changes the rate of fire
	RATE = { 0.85, 1.15 }, -- FirerateReduceMinMult, FirerateReduceMaxMult: the factor drawn
	COOKOFF_FROM = 170, -- AutoshotMinOverheat
	COOKOFF_CHANCE = 0.2, -- AutoshotChance
	COOKOFF_DELAY = { 0.05, 3 }, -- the delay drawn, to AutoshotPossibilityDuration 3 s
	SLIDE_AT = 200, -- StartSlideOverheat: the wiki's maximum stage holds the bolt
	SLIDE_FREE = 170, -- FixSlideOverheat: until a shot leaves the heat at 170 or below
	COOL_C = 6, -- MaxOverheatCoolCoef
	COOL = 3, -- CoolFactorGun x the parts' CoolFactor of the AKM: 4.2 a second from 200, about 3 below 120
}
-- heat one shot adds: the recorded AKM's 1.30777 with its stock parts for the rifles; the other classes keep the ratios
-- this game used before (SMG 0.82, pistol 1.09, shotgun 2.7, bolt 3.2 of a rifle's)
W.HEAT_SHOT = { rifle = 1.31, smg = 1.07, pistol = 1.43, shotgun = 3.57, bolt = 4.16 }
W.MALF = {
	IGNORE_ABOVE = 93, -- DurRangeToIgnoreMalfs 93-100: no durability, round or magazine malfunctions (heat's stay)
	HARD_BELOW = 5, -- a hard jammed bolt (Tarkov's hard slide) only at 5 % or less
	QUICKDRAW = 5, -- TimeToQuickdrawPistol: seconds after a malfunction during which the pistol comes out fast
	QUICKDRAW_MULT = 3, -- OutToIdleSpeedMultForPistol 3 (and IdleToOutSpeedMultOnMalf 3 putting the gun away)
	GLOW_DELAY = 0.15, -- the red glow 150 ms after the shot that malfunctioned
	GLOW_ASKS = 3, -- ShowGlowAttemptsCount: a reminder glow shows at the third ask...
	GLOW_WINDOW = 2, -- ...within 2 s of the first
	-- the kinds each source gives (Tarkov's weights): eject = Tarkov's "jam" (failure to eject), soft and hard = its
	-- soft and hard slide (a jammed bolt)
	DUR = { feed = 0.1, misfire = 0.1, eject = 0.6, soft = 0.2, hard = { 0.3, 0.8 } }, -- Dur*Wt
	AMMO = { misfire = 0.7, feed = 0.2, eject = 0.1 }, -- Ammo*Wt (the misfire's over the round's two chances summed)
	HEAT = { feed = 0.35, eject = 0.25, soft = 0.7, hard = { 0.3, 1.2 } }, -- Overheat*Wt; no misfire
}
-- BaseMalfunctionChance (Tarkov's template B): the AKM's 0.1771, solved from its recorded chance at 35 % durability
-- (0.0164727, TRP spec). It is the only figure verified for Tarkov 1.0, so every gun has it for now; the curve's own
-- rate-of-fire term still makes the slow guns (pump, bolt) worse when worn. (An old copy of Tarkov's items shows one
-- weapon of each class at 0.154 to 0.2475, unnamed; the curve is too steep at low rates of fire to guess with them.)
W.BASE_MALF = { R17 = 0.1771, KST = 0.1771, KS74 = 0.1771, KSL = 0.1771, GL6 = 0.1771, SPARROW = 0.1771, HARROW = 0.1771, TUNDRA = 0.1771, P9 = 0.1771,
	PM = 0.1771, SKS = 0.1771, SVD = 0.1771, M1A = 0.1771, M700 = 0.1771, VSS = 0.1771, VAL = 0.1771, MP7 = 0.1771, P90 = 0.1771 }
-- a round's misfire and feed chances summed, per mille (AmmoMalfChanceMult 1). Tarkov's recorded 7.62x39 FMJ and PS
-- have 0.174; other cartridges' own figures were not found, so every round has it until they are (by item id here).
W.ROUND_MALF = {}
W.ROUND_MALF_DEFAULT = 0.174

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * math.clamp(k, 0, 1)
end
local function hot(h: number): number -- 0 at 100, 1 at 200
	local O = W.OVERHEAT
	return (h - O.PROBLEMS) / (O.MAX - O.PROBLEMS)
end

-- the heat now from the last shot's heat L, dt seconds after it: Tarkov's straight fall at a rate L sets
function W.heatNow(L: number, dt: number, cool: number?): number
	if L <= 0 then
		return 0
	end
	local O = W.OVERHEAT
	local k = cool or O.COOL
	local rate = k
	if L >= 1 then
		rate = L * k / (L - (L / O.MAX + 0.0338 * O.COOL_C + 0.2925) ^ (9.667 + 0.0668 * O.COOL_C))
	end
	return math.max(0, L - math.max(0, dt) * rate)
end

-- the heat after one more shot of a weapon class
function W.heatShot(hNow: number, class: string?): number
	return math.min(W.OVERHEAT.MAX, hNow + (W.HEAT_SHOT[class or ""] or W.HEAT_SHOT.rifle))
end

-- a shot's wear multiplier by the last shot's heat
function W.heatWearMul(h: number): number
	return lerp(W.OVERHEAT.WEAR[1], W.OVERHEAT.WEAR[2], hot(h))
end

-- a shot's spread multiplier by the last shot's heat
function W.heatSpread(h: number): number
	return lerp(1, W.OVERHEAT.SPREAD, hot(h))
end

-- the greatest durability a shot this hot takes (roll 0..1: the draw at the top heat)
function W.heatMaxWear(h: number, roll: number): number
	local O = W.OVERHEAT
	if h < O.PROBLEMS then
		return 0
	elseif h >= O.MAX then
		return lerp(O.MAXWEAR_TOP[1], O.MAXWEAR_TOP[2], roll)
	end
	return lerp(O.MAXWEAR[1], O.MAXWEAR[2], hot(h))
end

-- the greatest durability after a hot shot: cut only while the durability is below it by more than the cut, and
-- never below 55 (TRP spec, "Hot shots wear the greatest durability too")
function W.wearMax(wear: number, wmax: number, h: number, roll: number): number
	local cut = W.heatMaxWear(h, roll)
	local floor = W.OVERHEAT.MAXWEAR_FLOOR
	if cut <= 0 or wmax < floor or wmax - wear <= cut then
		return wmax
	end
	return math.max(floor, wmax - cut)
end

-- the rate-of-fire factor drawn above 140 (roll 0..1)
function W.rateFactor(roll: number): number
	return lerp(W.OVERHEAT.RATE[1], W.OVERHEAT.RATE[2], roll)
end

-- the durability's malfunction chance (a probability): Tarkov's curve by B, the template's rate of fire FR and the
-- durability's whole part
function W.durMalf(B: number, FR: number, wear: number): number
	local w = math.floor(math.clamp(wear, 0, 100))
	local e
	if w > 59 then
		e = 3 + (100 - w) / (20 - 10 / (FR / 10) ^ 0.322)
	else
		e = ((50 - w ^ 1.286 / 4.8) / (FR ^ 0.17 / 2.9815 + 2.1)) * math.log10(101 - w)
	end
	return ((B + 1) ^ e - 1) / 1000
end

-- the heat's malfunction chance, per mille: none below 100
function W.heatMalf(h: number): number
	if h < W.OVERHEAT.PROBLEMS then
		return 0
	end
	return lerp(W.OVERHEAT.MALF[1], W.OVERHEAT.MALF[2], hot(h))
end

-- a magazine's malfunction chance, per mille (MagazineMalfChanceMult 1): the recorded AKM magazine's 0.09 for the
-- usual ones; the 40-round and bigger keep this game's earlier figures (2 and 3) for the wiki's feed failures from
-- "high-capacity and drum magazines"
function W.magMalf(magDef: any?): number
	if not magDef then
		return 0
	end
	local cap = magDef.capacity or 0
	return (cap >= 50 and 3) or (cap >= 40 and 2) or 0.09
end

function W.roundMalf(ammoId: string?): number
	return (ammoId and W.ROUND_MALF[ammoId]) or W.ROUND_MALF_DEFAULT
end

-- a shot's malfunction chance, worked out before it (Tarkov's GetTotalMalfunctionChance): the durability's part (a
-- probability) plus the round's, the magazine's and the heat's (per mille); from 93 % only the heat's counts.
-- Returns total, durability, round, magazine, heat.
function W.malfParts(wdef: any, wear: number, roundPm: number?, magPm: number?, h: number): (number, number, number, number, number)
	local dur, rnd, mag = 0, 0, 0
	if wear < W.MALF.IGNORE_ABOVE then
		dur = math.min(1, W.durMalf(W.BASE_MALF[wdef.id] or 0.1771, wdef.rpm or 600, wear))
		rnd = roundPm or 0
		mag = magPm or 0
	end
	local heat = W.heatMalf(h)
	return dur + (rnd + mag + heat) / 1000, dur, rnd, mag, heat
end

local function pick(k: number, list: { any }): any
	local sum = 0
	for _, e in list do
		sum += e[2]
	end
	if sum <= 0 then
		return nil
	end
	local x = k * sum
	for _, e in list do
		x -= e[2]
		if x < 0 then
			return e[1]
		end
	end
	return list[#list][1]
end

-- which malfunction (Tarkov's GetMalfunctionSources, then GetSpecificMalfunctionVariants): u (0..1) against the total
-- picks none or a source, in the order durability, round, magazine (only with rounds left in it), heat; k (0..1) picks
-- the kind by that source's weights. Returns kind ("misfire", "eject", "feed", "jam") and whether a jam is hard.
function W.malfKind(u: number, k: number, dur: number, rnd: number, mag: number, heat: number, wear: number, rounds: boolean): (string?, boolean)
	local parts = { { "dur", dur }, { "rnd", rnd / 1000 }, { "mag", rounds and mag / 1000 or 0 }, { "heat", heat / 1000 } }
	local src
	local x = u
	for _, p in parts do
		x -= p[2]
		if x < 0 then
			src = p[1]
			break
		end
	end
	if not src then
		return nil, false
	end
	local M = W.MALF
	local hardK = wear <= M.HARD_BELOW and (M.HARD_BELOW - wear) / M.HARD_BELOW or nil
	local kind
	if src == "dur" then
		kind = pick(k, {
			{ "feed", rounds and M.DUR.feed or 0 }, { "misfire", M.DUR.misfire }, { "eject", M.DUR.eject },
			{ "soft", rounds and M.DUR.soft or 0 }, { "hard", hardK and lerp(M.DUR.hard[1], M.DUR.hard[2], hardK) or 0 },
		})
	elseif src == "rnd" then
		kind = pick(k, { { "misfire", M.AMMO.misfire / math.max(rnd, 1e-6) }, { "feed", rounds and M.AMMO.feed or 0 }, { "eject", M.AMMO.eject } })
	elseif src == "mag" then
		kind = "feed"
	else
		kind = pick(k, {
			{ "feed", rounds and M.HEAT.feed or 0 }, { "eject", M.HEAT.eject }, { "soft", rounds and M.HEAT.soft or 0 },
			{ "hard", hardK and lerp(M.HEAT.hard[1], M.HEAT.hard[2], hardK) or 0 },
		})
	end
	if kind == "soft" then
		return "jam", false
	elseif kind == "hard" then
		return "jam", true
	end
	return kind, false
end

return W
