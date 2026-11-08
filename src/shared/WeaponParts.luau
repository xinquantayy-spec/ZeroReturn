--!strict
-- Weapon parts (M14, Tarkov-style modding; docs/weapons/WEAPON_MODDING.md). Original names and stats.
--
-- Tarkov's three groups of mods: functional (muzzle devices, sights, foregrips, tactical devices), gear (mounts,
-- stocks, charging handles, magazines and tubes) and vital parts (barrels, gas blocks, handguards, pistol grips,
-- receivers and slides; vital parts cannot be changed in raid without a multitool).
--
-- Every part fits slots by a fit tag (a thread, a rail, a platform) and its category; slots can be required (the
-- gun does not work without them). Stats are Tarkov-style: ergonomics adds points, recoil / accuracy / velocity
-- are percentages, loudness multiplies. Geometry (where the slots are, the pictures, the meshes) is generated
-- from Blender into GunMeta; this module is the rules.
local W = {}

W.CATS = {
	muzzle = { group = "functional", name = "MUZZLE DEVICE" },
	sight = { group = "functional", name = "SIGHT" },
	ironfront = { group = "functional", name = "FRONT SIGHT" },
	ironrear = { group = "functional", name = "REAR SIGHT" },
	foregrip = { group = "functional", name = "FOREGRIP" },
	tactical = { group = "functional", name = "TACTICAL DEVICE" },
	mount = { group = "gear", name = "MOUNT" },
	nvg = { group = "gear", name = "NIGHT VISION" },
	stock = { group = "gear", name = "STOCK" },
	charge = { group = "gear", name = "CHARGING HANDLE" },
	tube = { group = "gear", name = "MAGAZINE TUBE" },
	barrel = { group = "vital", name = "BARREL" },
	gasblock = { group = "vital", name = "GAS BLOCK" },
	handguard = { group = "vital", name = "HANDGUARD" },
	grip = { group = "vital", name = "PISTOL GRIP" },
	receiver = { group = "vital", name = "RECEIVER" },
}

-- slot display names (Tarkov's slot names)
W.SLOT_NAMES = {
	grip = "PISTOL GRIP", stock = "STOCK", upper = "UPPER RECEIVER", mag = "MAGAZINE", barrel = "BARREL", handguard = "HANDGUARD",
	charge = "CHARGING HANDLE", scope = "SCOPE", rearsight = "REAR SIGHT", gas = "GAS BLOCK", muzzle = "MUZZLE", foregrip = "FOREGRIP",
	tactical = "TACTICAL", top = "MOUNT", dustcover = "DUST COVER", mount = "MOUNT", tube = "MAGAZINE TUBE", forend = "FOREND",
	sidemount = "SIDE MOUNT", scout = "SCOUT MOUNT", slide = "SLIDE", optic = "OPTIC",
}

-- slots of the weapon bases and the parts that have slots: fit tag, accepted categories (rails), required
local RAIL_SIGHT = { sight = true, mount = true }
W.SLOTS = {
	-- R-17 Carbine (AR-type)
	R17_RIFLE = { grip = { fit = "ar_grip", req = true }, stock = { fit = "ar_stock" }, upper = { fit = "r17_upper", req = true } },
	R17_UPPER = { barrel = { fit = "r17_barrel", req = true }, handguard = { fit = "r17_hg" }, charge = { fit = "ar_charge", req = true },
		scope = { fit = "pica", cats = RAIL_SIGHT }, rearsight = { fit = "pica", cats = { ironrear = true } } },
	R17_BRL_105 = { muzzle = { fit = "t62" }, gas = { fit = "r17_gas", req = true } },
	R17_BRL_145 = { muzzle = { fit = "t62" }, gas = { fit = "r17_gas", req = true } },
	R17_BRL_18 = { muzzle = { fit = "t62" }, gas = { fit = "r17_gas", req = true } },
	R17_HG_QUAD = { foregrip = { fit = "pica", cats = { foregrip = true } }, tactical = { fit = "pica", cats = { tactical = true } },
		top = { fit = "pica", cats = { ironfront = true, sight = true, mount = true } } },
	R17_HG_MLOK = { foregrip = { fit = "pica", cats = { foregrip = true } }, tactical = { fit = "pica", cats = { tactical = true } },
		top = { fit = "pica", cats = { ironfront = true, sight = true, mount = true } } },
	-- Kestrel KS-7 (AK-type)
	KST_RIFLE = { grip = { fit = "ak_grip", req = true }, stock = { fit = "ak_stock" }, dustcover = { fit = "ak_dc", req = true },
		handguard = { fit = "ak_hg", req = true }, muzzle = { fit = "t76" }, rearsight = { fit = "ak_rear" }, mount = { fit = "dovetail" } },
	-- Kestrel KS-74 (economy-1a, third slice): the KS-7's slots and furniture, its own 5.4 muzzle thread
	KS74_RIFLE = { grip = { fit = "ak_grip", req = true }, stock = { fit = "ak_stock" }, dustcover = { fit = "ak_dc", req = true },
		handguard = { fit = "ak_hg", req = true }, muzzle = { fit = "t54" }, rearsight = { fit = "ak_rear" }, mount = { fit = "dovetail" } },
	-- Kestrel KS-L (the KS-7's light machine gun, ai-5b): the KS-7's slots and parts
	KSL_LMG = { grip = { fit = "ak_grip", req = true }, stock = { fit = "ak_stock" }, dustcover = { fit = "ak_dc", req = true },
		handguard = { fit = "ak_hg", req = true }, muzzle = { fit = "t76" }, rearsight = { fit = "ak_rear" }, mount = { fit = "dovetail" } },
	KST_DC_RAIL = { scope = { fit = "pica", cats = RAIL_SIGHT } },
	-- Bittern GL-6 (ai-5b): one part, a rail for a sight
	GL6_LAUNCHER = { scope = { fit = "pica", cats = RAIL_SIGHT } },
	KST_HG_POLY = { foregrip = { fit = "pica", cats = { foregrip = true } } },
	KST_HG_RAIL = { foregrip = { fit = "pica", cats = { foregrip = true } }, tactical = { fit = "pica", cats = { tactical = true } },
		top = { fit = "pica", cats = RAIL_SIGHT } },
	KST_MNT_SIDE = { scope = { fit = "pica", cats = RAIL_SIGHT } },
	-- Sparrow SMG-9
	SPARROW_SMG = { grip = { fit = "spr_grip", req = true }, stock = { fit = "spr_stock" }, handguard = { fit = "spr_hg", req = true },
		muzzle = { fit = "lug9" }, mount = { fit = "spr_claw" } },
	SPR_HG_TRI = { foregrip = { fit = "pica", cats = { foregrip = true } }, tactical = { fit = "pica", cats = { tactical = true } } },
	SPR_MNT_CLAW = { scope = { fit = "pica", cats = RAIL_SIGHT } },
	-- Harrow-12
	HARROW12 = { barrel = { fit = "har_barrel", req = true }, tube = { fit = "har_tube", req = true }, forend = { fit = "har_fe", req = true },
		stock = { fit = "har_stock" }, scope = { fit = "pica", cats = RAIL_SIGHT } },
	HAR_BRL_14 = { muzzle = { fit = "t12" } },
	HAR_BRL_18 = { muzzle = { fit = "t12" } },
	HAR_BRL_20 = { muzzle = { fit = "t12" } },
	HAR_FE_RAIL = { tactical = { fit = "pica", cats = { tactical = true } } },
	-- Tundra
	TUNDRA_BOLT = { stock = { fit = "tun_stock", req = true }, muzzle = { fit = "t76l" }, sidemount = { fit = "tun_side" }, scout = { fit = "tun_scout" } },
	TUN_STK_CHAS = { foregrip = { fit = "pica", cats = { foregrip = true } } },
	TUN_MNT_SIDE = { scope = { fit = "pica", cats = RAIL_SIGHT } },
	TUN_MNT_SCOUT = { scope = { fit = "pica", cats = RAIL_SIGHT } },
	-- P-9 Vesna
	P9_PISTOL = { slide = { fit = "p9_slide", req = true }, barrel = { fit = "p9_barrel", req = true }, tactical = { fit = "pica", cats = { tactical = true } } },
	P9_SLIDE_CUT = { optic = { fit = "p9_optic", cats = { sight = true } } },
	P9_BRL_THR = { muzzle = { fit = "t9" } },
	-- Merlin MR-10 (economy-1a, fourth slice): a muzzle thread that takes the Tundra's devices and the AK-type dovetail
	SVD_RIFLE = { muzzle = { fit = "t76l" }, mount = { fit = "dovetail" } },
	-- Makar PM (economy-1a, third slice): EFT's PM has a slide, a magazine and grip panels; ours are on the frame
	PM_PISTOL = { slide = { fit = "pm_slide", req = true } },
	-- mounts
	MNT_RISER = { scope = { fit = "pica", cats = RAIL_SIGHT } },
	MNT_RINGS = { scope = { fit = "ring30", cats = { sight = true } } },
	-- helmets with a night-vision mount and the head strap (Tarkov: goggles go on a helmet's mount or a strap)
	HELMET_C3 = { mount = { fit = "nvg_mount" } },
	HELMET_C4 = { mount = { fit = "nvg_mount" } },
	NV_STRAP = { mount = { fit = "nvg_mount" } },
}

-- the parts: category, what they fit, standalone size, stats. Stats: ergo (points), recoil (%), acc (% spread),
-- vel (% muzzle velocity), loud (x), zoom / reflex / holo (sights), light / laser (tactical), capacity (tubes),
-- range (sighting range, m), mass (kg), value (MK)
-- Recoil and ergonomics follow Tarkov 1.0.4.5 (20 April 2026; AltChar, DLCompare): a longer barrel holds recoil better
-- and costs ergonomics, handguards no longer change recoil (only ergonomics), suppressors cost more ergonomics and take
-- less recoil off. Figures of the parts each stands in for (tarkovforge.com, read 2026-11-08): AR barrels 10.3" -5.2 % /
-- -2, 14.5" -7.4 / -12, 18" -9.1 / -26; A2 flash hider -5 / -1; a brake (Alientech) -10 / -4; M4SS stock -20.5 / +6 on
-- the carbine buffer tube -0.5 / -2; AKM wooden stock -22 / +3, slant brake -4; AK brake (JMac RRD-4C, EFT wiki) -14 /
-- -2; MP5 A2 stock -24 / +6, A3 -23 / +7; MP-133 wooden stock -24 / +6, 510 mm barrel -3 / -5, 540 mm -3.5 / -5; Mosin
-- infantry stock -20 / +9. A suppressor here takes the place of its muzzle device, so it carries Tarkov's mount with it:
-- A2 flash hider plus SOCOM556-RC2 (-1.5 / -12) or Mini Monster (-0.5 / -9). The other stocks and suppressors keep
-- their old spacing from those; grips, foregrips and the other muzzle devices keep this game's figures.
type Part = { [string]: any }
W.parts = {} :: { [string]: Part }
local function part(id: string, name: string, short: string, cat: string, fits: any, d: Part)
	d.name, d.short, d.cat = name, short, cat
	d.fits = type(fits) == "table" and fits or { fits }
	d.mass = d.mass or 0.1
	d.value = d.value or 1000
	d.rarity = d.rarity or "common"
	d.desc = d.desc or ""
	W.parts[id] = d
end

-- ── R-17 (AR-type, 6.2x40) ───────────────────────────────────────────────────
part("R17_UPPER", "R-17 flat-top upper receiver", "R17 UPPER", "receiver", "r17_upper", { w = 3, h = 1, mass = 0.32, value = 6000, ergo = 4, desc = "Forged upper receiver with a full-length top rail. Holds the barrel, handguard and charging handle." })
part("R17_BRL_105", "R-17 10.5\" barrel", "10.5\"", "barrel", "r17_barrel", { w = 3, h = 1, mass = 0.55, value = 7000, ergo = -2, acc = 18, vel = -9, recoil = -5.2, desc = "Short barrel: handy indoors, loses velocity and accuracy." })
part("R17_BRL_145", "R-17 14.5\" barrel", "14.5\"", "barrel", "r17_barrel", { w = 4, h = 1, mass = 0.72, value = 8000, ergo = -12, recoil = -7.4, desc = "Standard carbine barrel with a carbine-length gas system." })
part("R17_BRL_18", "R-17 18\" fluted barrel", "18\" DMR", "barrel", "r17_barrel", { w = 5, h = 1, mass = 0.86, value = 16000, rarity = "uncommon", ergo = -26, acc = -22, vel = 7, recoil = -9.1, desc = "Long fluted barrel for marksman builds. More velocity, tighter groups." })
part("R17_GAS_FSP", "R-17 front sight gas block", "FSB", "gasblock", "r17_gas", { w = 1, h = 1, mass = 0.16, value = 2000, ergo = -2, range = 300, desc = "Gas block with an integrated front sight post and bayonet lug." })
part("R17_GAS_LOW", "R-17 low-profile gas block", "LP GAS", "gasblock", "r17_gas", { w = 1, h = 1, mass = 0.06, value = 4800, desc = "Low gas block that fits under free-float handguards." })
part("R17_HG_CARB", "R-17 carbine handguard", "CARB HG", "handguard", "r17_hg", { w = 3, h = 1, mass = 0.24, value = 2500, ergo = 6, desc = "Ribbed polymer handguard with heat shields. No rails." })
part("R17_HG_QUAD", "Holt QR-9 quad rail", "QR-9", "handguard", "r17_hg", { w = 3, h = 1, mass = 0.38, value = 21000, ergo = 4, desc = "Carbine-length quad rail: a foregrip underneath, a light on the side, a sight on top." })
part("R17_HG_MLOK", "Tessel FL-13 free-float handguard", "FL-13", "handguard", "r17_hg", { w = 5, h = 1, mass = 0.33, value = 38000, rarity = "uncommon", ergo = 9, acc = -4, desc = "Long free-float handguard with a full top rail. Needs a low-profile gas block." })
part("AR_CH_STD", "R-17 charging handle", "CH", "charge", "ar_charge", { w = 1, h = 1, mass = 0.04, value = 800, desc = "Standard T-handle." })
part("AR_CH_EXT", "Vantor extended-latch charging handle", "CH EXT", "charge", "ar_charge", { w = 1, h = 1, mass = 0.05, value = 6400, ergo = 2, desc = "Oversized latch, easy to grab with gloves." })
part("AR_STK_CARB", "R-17 collapsible stock", "COLL", "stock", "ar_stock", { w = 2, h = 1, mass = 0.24, value = 3000, ergo = 4, recoil = -21, desc = "Six-position carbine stock." })
part("AR_STK_A2", "R-17 fixed rifle stock", "FIXED", "stock", "ar_stock", { w = 3, h = 1, mass = 0.4, value = 7500, ergo = 0, recoil = -27, desc = "Long fixed stock with a trap door. Steadier, heavier." })
part("AR_STK_SKEL", "Rovik SK skeleton stock", "SKEL", "stock", "ar_stock", { w = 2, h = 1, mass = 0.16, value = 15000, rarity = "uncommon", ergo = 8, recoil = -15, desc = "Light skeleton stock. Fast handling, less control." })
part("AR_PG_A2", "R-17 pistol grip", "PG", "grip", "ar_grip", { w = 1, h = 1, mass = 0.07, value = 1000, ergo = 6, desc = "Standard pistol grip with a finger ridge." })
part("AR_PG_ERGO", "Orsa EG-2 ergonomic grip", "EG-2", "grip", "ar_grip", { w = 1, h = 1, mass = 0.09, value = 5200, ergo = 10, desc = "Rubber-panelled grip with palm swell." })
part("AR_PG_ANG", "Rovik AG-15 angled grip", "AG-15", "grip", "ar_grip", { w = 1, h = 1, mass = 0.07, value = 4800, ergo = 9, recoil = -1, desc = "Steeper grip angle for a squared-up stance. Storage cap." })
part("R17_RS_FLIP", "R-17 flip-up rear sight", "REAR", "ironrear", "pica", { w = 1, h = 1, mass = 0.06, value = 2500, ergo = -1, range = 300, desc = "Folding aperture rear sight." })
part("R17_FS_FLIP", "R-17 flip-up front sight", "FRONT", "ironfront", "pica", { w = 1, h = 1, mass = 0.05, value = 4200, ergo = -1, range = 300, desc = "Folding front post for railed handguards." })
part("R17_FH_A2", "R-17 birdcage flash hider", "BIRDCAGE", "muzzle", "t62", { w = 1, h = 1, mass = 0.05, value = 1200, recoil = -5, ergo = -1, desc = "Closed-bottom flash hider." })
part("R17_BRK", "Kaltan MB-6 muzzle brake", "MB-6", "muzzle", "t62", { w = 1, h = 1, mass = 0.08, value = 9000, recoil = -10, ergo = -4, loud = 1.15, acc = 2, desc = "Ported brake: less recoil, more noise and flash." })
part("R17_COMP", "Kaltan CP-3 compensator", "CP-3", "muzzle", "t62", { w = 1, h = 1, mass = 0.07, value = 7800, recoil = -8, loud = 1.06, desc = "Top-ported compensator: keeps the muzzle down." })
part("SUPP_62", "6.2 Suppressor", "SUPP 6.2", "muzzle", "t62", { w = 2, h = 1, mass = 0.5, value = 36000, rarity = "uncommon", recoil = -6.5, ergo = -13, loud = 0.35, vel = 1, acc = -3, desc = "Sound suppressor for 6.2 rifles. Hides the muzzle flash." })
part("SUPP_62C", "Kaltan SR-6K compact suppressor", "SR-6K", "muzzle", "t62", { w = 2, h = 1, mass = 0.34, value = 31000, rarity = "uncommon", recoil = -5.5, ergo = -10, loud = 0.42, desc = "Short suppressor for short barrels." })

-- ── KS-7 (AK-type, 7.6x39) ───────────────────────────────────────────────────
part("KST_DC_STD", "KS-7 dust cover", "DC", "receiver", "ak_dc", { w = 3, h = 1, mass = 0.18, value = 2600, desc = "Stamped receiver cover." })
part("KST_DC_RAIL", "Holt RD-7 railed dust cover", "RD-7", "receiver", "ak_dc", { w = 3, h = 1, mass = 0.28, value = 19000, rarity = "uncommon", ergo = -1, desc = "Locking dust cover with a full top rail for optics." })
part("KST_HG_WOOD", "KS-7 wooden handguard", "WOOD HG", "handguard", "ak_hg", { w = 3, h = 1, mass = 0.28, value = 3000, ergo = 6, desc = "Laminated wood handguard and gas tube cover." })
part("KST_HG_POLY", "KS-7 polymer handguard", "POLY HG", "handguard", "ak_hg", { w = 3, h = 1, mass = 0.24, value = 6200, ergo = 8, desc = "Plum polymer handguard with a short rail for a foregrip." })
part("KST_HG_RAIL", "Holt KR-4 rail handguard", "KR-4", "handguard", "ak_hg", { w = 3, h = 1, mass = 0.42, value = 24000, rarity = "uncommon", ergo = 5, desc = "Railed handguard and gas tube cover: foregrip, light, sight." })
part("AK_PG_STD", "KS-7 pistol grip", "PG", "grip", "ak_grip", { w = 1, h = 1, mass = 0.06, value = 1200, ergo = 5, desc = "Bakelite grip." })
part("AK_PG_ERGO", "Orsa EK-1 ergonomic grip", "EK-1", "grip", "ak_grip", { w = 1, h = 1, mass = 0.08, value = 4600, ergo = 9, desc = "Modern grip with palm panels." })
part("AK_PG_RUB", "Rovik RK rubber grip", "RK", "grip", "ak_grip", { w = 1, h = 1, mass = 0.09, value = 5400, ergo = 8, recoil = -1, desc = "Over-moulded rubber grip." })
part("KST_STK_WOOD", "KS-7 wooden stock", "WOOD", "stock", "ak_stock", { w = 3, h = 1, mass = 0.5, value = 4200, ergo = 3, recoil = -22, desc = "Fixed wooden stock with a steel butt plate." })
part("KST_STK_FOLD", "KS-7 folding stock", "FOLD", "stock", "ak_stock", { w = 3, h = 1, mass = 0.32, value = 8800, ergo = 6, recoil = -15, desc = "Side-folding skeleton stock." })
part("KST_STK_TUBE", "Vantor TA-7 tube stock", "TA-7", "stock", "ak_stock", { w = 3, h = 1, mass = 0.42, value = 17000, rarity = "uncommon", ergo = 7, recoil = -24, desc = "Receiver adapter with a buffer tube and a collapsible stock." })
part("KST_RS_TAN", "KS-7 tangent rear sight", "REAR", "ironrear", "ak_rear", { w = 1, h = 1, mass = 0.06, value = 1600, range = 800, desc = "Tangent leaf with a range slider." })
part("KST_MNT_SIDE", "Holt SM-2 side mount", "SM-2", "mount", "dovetail", { w = 1, h = 1, mass = 0.2, value = 11000, ergo = -2, desc = "Quick-detach dovetail mount with a rail over the cover." })
part("KST_FH_SLANT", "KS-7 slant brake", "SLANT", "muzzle", "t76", { w = 1, h = 1, mass = 0.03, value = 1400, recoil = -4, desc = "Angled muzzle: pushes the muzzle down and right." })
part("BRAKE_76", "7.6 Muzzle Brake", "BRAKE", "muzzle", "t76", { w = 1, h = 1, mass = 0.2, value = 12000, recoil = -14, loud = 1.15, ergo = -2, desc = "Muzzle brake for 7.6x39. Less recoil, more noise." })
-- the KS-74's brake: EFT's AK-74 5.45x39 muzzle brake-compensator (recoil -5 %, ergonomics -0.5, 0.1 kg, 694; tarkovforge.com
-- and SPT's handbook)
part("BRAKE_74", "KS-74 muzzle brake", "74 BRAKE", "muzzle", "t54", { w = 1, h = 1, mass = 0.1, value = 694, recoil = -5, loud = 1.1, desc = "Two-port brake for the 5.4x39 rifles. Tames the climb a little." })
part("SUPP_76", "Kaltan SR-7 suppressor", "SR-7", "muzzle", "t76", { w = 2, h = 1, mass = 0.55, value = 39000, rarity = "uncommon", recoil = -5.5, ergo = -12, loud = 0.36, acc = -3, desc = "Sound suppressor for 7.6x39 rifles." })

-- ── SMG-9 ────────────────────────────────────────────────────────────────────
part("SPR_GRIP_STD", "SMG-9 trigger group", "TRIG", "grip", "spr_grip", { w = 1, h = 1, mass = 0.2, value = 6500, ergo = 8, desc = "Trigger group and pistol grip." })
part("SPR_GRIP_NAVY", "SMG-9 ambi trigger group", "AMBI", "grip", "spr_grip", { w = 1, h = 1, mass = 0.21, value = 12000, rarity = "uncommon", ergo = 10, desc = "Ambidextrous selector, sculpted grip." })
part("SPR_STK_FIXED", "SMG-9 fixed stock", "FIXED", "stock", "spr_stock", { w = 2, h = 1, mass = 0.38, value = 5600, ergo = 6, recoil = -24, desc = "Polymer fixed stock." })
part("SPR_STK_SLIDE", "SMG-9 retractable stock", "RETR", "stock", "spr_stock", { w = 2, h = 1, mass = 0.32, value = 7200, ergo = 7, recoil = -23, desc = "Sliding two-rail stock." })
part("SPR_STK_CAP", "SMG-9 end cap", "CAP", "stock", "spr_stock", { w = 1, h = 1, mass = 0.08, value = 1500, ergo = 13, desc = "No stock: short and quick, hard to control." })
part("SPR_HG_SLIM", "SMG-9 slim handguard", "SLIM", "handguard", "spr_hg", { w = 2, h = 1, mass = 0.1, value = 2400, ergo = 6, desc = "Slim polymer handguard." })
part("SPR_HG_TRI", "Holt TR-3 tri-rail handguard", "TR-3", "handguard", "spr_hg", { w = 2, h = 1, mass = 0.22, value = 14500, ergo = 4, desc = "Three rails: foregrip and lights." })
part("SPR_MNT_CLAW", "SMG-9 claw mount", "CLAW", "mount", "spr_claw", { w = 2, h = 1, mass = 0.14, value = 7600, ergo = -1, desc = "Claw mount with a rail for optics." })
part("SPR_FH_3L", "SMG-9 three-lug flash hider", "3-LUG", "muzzle", "lug9", { w = 1, h = 1, mass = 0.04, value = 2800, recoil = -3, desc = "Three-lug flash hider." })
part("SUPP_9", "9mm Suppressor", "SUPP 9", "muzzle", { "t9", "lug9" }, { w = 2, h = 1, mass = 0.3, value = 24000, recoil = -4.5, ergo = -10, loud = 0.3, acc = -2, desc = "Sound suppressor for 9x19 pistols and the SMG-9's three-lug barrel." })

-- ── Harrow-12 ────────────────────────────────────────────────────────────────
part("HAR_BRL_14", "Harrow 14\" barrel", "14\"", "barrel", "har_barrel", { w = 3, h = 1, mass = 0.8, value = 9000, ergo = -3, recoil = -2, acc = 12, vel = -6, desc = "Short barrel. Only fits the 4-shell tube." })
part("HAR_BRL_18", "Harrow 18.5\" barrel", "18.5\"", "barrel", "har_barrel", { w = 4, h = 1, mass = 1.0, value = 11000, ergo = -5, recoil = -3, desc = "Standard barrel with a bead sight." })
part("HAR_BRL_20", "Harrow 20\" heat-shield barrel", "20\" HS", "barrel", "har_barrel", { w = 5, h = 1, mass = 1.2, value = 16000, ergo = -6, recoil = -3.5, acc = -10, vel = 4, desc = "Long barrel with a ventilated heat shield." })
part("HAR_TUBE_4", "Harrow 4-shell magazine tube", "TUBE 4", "tube", "har_tube", { w = 3, h = 1, mass = 0.2, value = 2400, capacity = 4, ergo = 1, desc = "Short magazine tube." })
part("HAR_TUBE_6", "Harrow 6-shell magazine tube", "TUBE 6", "tube", "har_tube", { w = 4, h = 1, mass = 0.26, value = 3600, capacity = 6, ergo = -1, desc = "Standard magazine tube." })
part("HAR_TUBE_8", "Harrow 8-shell magazine tube", "TUBE 8", "tube", "har_tube", { w = 5, h = 1, mass = 0.32, value = 9600, capacity = 8, ergo = -3, rarity = "uncommon", desc = "Extended tube. Needs the 20\" barrel." })
part("HAR_FE_WOOD", "Harrow wooden forend", "WOOD FE", "handguard", "har_fe", { w = 2, h = 1, mass = 0.18, value = 1800, ergo = 5, desc = "Grooved wooden pump." })
part("HAR_FE_POLY", "Harrow polymer forend", "POLY FE", "handguard", "har_fe", { w = 2, h = 1, mass = 0.14, value = 2600, ergo = 6, desc = "Ribbed polymer pump." })
part("HAR_FE_RAIL", "Holt PF-2 rail forend", "PF-2", "handguard", "har_fe", { w = 2, h = 1, mass = 0.22, value = 9800, ergo = 4, desc = "Pump with rails for a light." })
part("HAR_STK_WOOD", "Harrow wooden stock", "WOOD", "stock", "har_stock", { w = 3, h = 1, mass = 0.6, value = 3400, ergo = 6, recoil = -24, desc = "Classic wooden stock." })
part("HAR_STK_PG", "Harrow pistol-grip stock", "PG STOCK", "stock", "har_stock", { w = 3, h = 1, mass = 0.55, value = 6800, ergo = 8, recoil = -23, desc = "Polymer stock with a pistol grip." })
part("HAR_STK_TACT", "Vantor TS-12 collapsible stock", "TS-12", "stock", "har_stock", { w = 3, h = 1, mass = 0.5, value = 16000, rarity = "uncommon", ergo = 10, recoil = -21, desc = "Pistol grip, buffer tube and a collapsible stock." })
part("HAR_CHOKE", "Harrow full choke", "CHOKE", "muzzle", "t12", { w = 1, h = 1, mass = 0.06, value = 3200, acc = -30, desc = "Tightens the shot pattern." })
part("HAR_BRK", "Harrow breacher brake", "BREACH", "muzzle", "t12", { w = 1, h = 1, mass = 0.12, value = 7400, recoil = -8, loud = 1.1, acc = 6, desc = "Toothed muzzle brake." })

-- ── Tundra ───────────────────────────────────────────────────────────────────
part("TUN_STK_WOOD", "Tundra wooden stock", "WOOD", "stock", "tun_stock", { w = 6, h = 1, mass = 1.3, value = 6000, ergo = 9, recoil = -20, desc = "Full-length service stock with barrel bands." })
part("TUN_STK_SPORT", "Tundra sporter stock", "SPORTER", "stock", "tun_stock", { w = 5, h = 1, mass = 1.0, value = 14000, rarity = "uncommon", ergo = 13, recoil = -21, desc = "Shortened stock with a pistol-grip wrist and a recoil pad." })
part("TUN_STK_CHAS", "Vantor CH-54 chassis", "CH-54", "stock", "tun_stock", { w = 5, h = 1, mass = 1.4, value = 42000, rarity = "rare", ergo = 17, recoil = -25, acc = -8, desc = "Aluminium chassis with a pistol grip, an adjustable stock and a rail for a grip." })
part("TUN_MNT_SIDE", "Tundra side mount", "SIDE MNT", "mount", "tun_side", { w = 2, h = 1, mass = 0.24, value = 9000, ergo = -2, desc = "Side mount with a rail over the receiver." })
part("TUN_MNT_SCOUT", "Tundra scout rail", "SCOUT", "mount", "tun_scout", { w = 2, h = 1, mass = 0.16, value = 7200, ergo = -1, desc = "Rail on the rear sight base for long eye relief optics." })
-- the MR-10's flash hider (EFT's SVD flash hider; ours changes no recoil, the gun's figures already hold it)
part("SVD_FH", "MR-10 flash hider", "FH", "muzzle", "t76l", { w = 1, h = 1, mass = 0.07, value = 602, loud = 0.95, desc = "Long slotted flash hider. Hides the flash, does little else." })
part("TUN_BRK", "Tundra muzzle brake", "BRAKE", "muzzle", "t76l", { w = 1, h = 1, mass = 0.12, value = 8000, recoil = -14, loud = 1.15, desc = "Ported brake for the full-power cartridge." })
part("SUPP_76L", "Kaltan SR-54 suppressor", "SR-54", "muzzle", "t76l", { w = 2, h = 1, mass = 0.62, value = 46000, rarity = "rare", recoil = -3, ergo = -13, loud = 0.38, acc = -4, desc = "Sound suppressor for 7.6x54R." })

-- ── P-9 ──────────────────────────────────────────────────────────────────────
part("P9_SLIDE_STD", "P-9 slide", "SLIDE", "receiver", "p9_slide", { w = 2, h = 1, mass = 0.22, value = 4200, ergo = 5, range = 50, desc = "Slide with a notch rear sight and a dotted front post." })
part("P9_SLIDE_CUT", "P-9 optic-cut slide", "MOS SLIDE", "receiver", "p9_slide", { w = 2, h = 1, mass = 0.21, value = 11000, rarity = "uncommon", ergo = 5, range = 50, desc = "Slide with a cut for a compact reflex sight." })
part("P9_BRL_STD", "P-9 barrel", "BRL", "barrel", "p9_barrel", { w = 2, h = 1, mass = 0.1, value = 3000, desc = "Standard barrel." })
part("P9_BRL_THR", "P-9 threaded barrel", "THR BRL", "barrel", "p9_barrel", { w = 2, h = 1, mass = 0.11, value = 7000, desc = "Threaded for a suppressor or a compensator." })
part("PM_SLIDE", "PM slide", "SLIDE", "receiver", "pm_slide", { w = 2, h = 1, mass = 0.2, value = 1500, ergo = 3, range = 25, desc = "Blued slide with a safety-decocker and fixed sights." }) -- value ours
part("P9_COMP", "Kaltan PC-1 pistol compensator", "PC-1", "muzzle", "t9", { w = 1, h = 1, mass = 0.05, value = 6400, recoil = -10, loud = 1.05, desc = "Top-ported compensator." })

-- ── generic rail parts ───────────────────────────────────────────────────────
part("RED_DOT", "RS-1 Reflex Sight", "REFLEX", "sight", "pica", { w = 1, h = 1, mass = 0.2, value = 16000, ergo = -1, reflex = true, range = 200, desc = "Tube reflex sight with a red dot on a quick-release mount." })
part("HOLO_EX", "Mirak HS-3 holographic sight", "HS-3", "sight", "pica", { w = 1, h = 1, mass = 0.32, value = 28000, rarity = "uncommon", ergo = -2, reflex = true, holo = true, range = 200, desc = "Holographic sight with a wide window." })
part("SIGHT_MICRO", "Mirak MR-1 compact reflex", "MR-1", "sight", { "pica", "p9_optic" }, { w = 1, h = 1, mass = 0.06, value = 18000, ergo = 0, reflex = true, range = 100, desc = "Compact open reflex sight for rails and pistol slides." })
part("SCOPE_4X", "C4 Combat Scope", "4X", "sight", "pica", { w = 2, h = 1, mass = 0.55, value = 48000, rarity = "uncommon", ergo = -4, zoom = 4, range = 600, desc = "Fixed 4x prism scope with an integrated mount." })
part("SCOPE_16", "Orsa V6 1-6x scope", "V6", "sight", "ring30", { w = 3, h = 1, mass = 0.6, value = 64000, rarity = "rare", ergo = -5, zoom = 6, zooms = { 1, 6 }, range = 800, desc = "Low-power variable scope. Needs a 30 mm mount." })
part("SCOPE_8X", "Orsa L8 8x scope", "L8", "sight", "ring30", { w = 3, h = 1, mass = 0.78, value = 82000, rarity = "rare", ergo = -7, zoom = 8, range = 1000, desc = "Long-range scope with a sunshade. Needs a 30 mm mount." })
part("MNT_RISER", "Holt RM-1 riser mount", "RISER", "mount", "pica", { w = 1, h = 1, mass = 0.05, value = 3600, desc = "Raises a sight to a comfortable height." })
part("MNT_RINGS", "Holt 30mm scope mount", "30MM MNT", "mount", "pica", { w = 2, h = 1, mass = 0.18, value = 9800, ergo = -1, desc = "One-piece cantilever mount for 30 mm scopes." })
part("GRIP_V", "Vertical Foregrip", "GRIP", "foregrip", "pica", { w = 1, h = 1, mass = 0.1, value = 9000, ergo = 4, recoil = -10, desc = "Vertical grip. Steadier bursts, faster handling." })
part("GRIP_ANG", "Rovik AFG angled foregrip", "AFG", "foregrip", "pica", { w = 1, h = 1, mass = 0.06, value = 11000, ergo = 6, recoil = -5, desc = "Angled grip that indexes the support hand." })
part("GRIP_STUB", "Rovik ST stubby grip", "STUBBY", "foregrip", "pica", { w = 1, h = 1, mass = 0.05, value = 6400, ergo = 5, recoil = -6, desc = "Short vertical grip." })
part("GRIP_STOP", "Rovik HS handstop", "HSTOP", "foregrip", "pica", { w = 1, h = 1, mass = 0.03, value = 3800, ergo = 3, recoil = -3, desc = "Small stop for a forward grip." })
part("LIGHT_T", "WL-2 Weapon Light", "LIGHT", "tactical", "pica", { w = 1, h = 1, mass = 0.15, value = 11000, ergo = -1, light = true, desc = "Weapon light. T turns it on and off." })
part("LASER_COMBO", "Tessel LC-4 light/laser", "LC-4", "tactical", "pica", { w = 1, h = 1, mass = 0.21, value = 26000, rarity = "uncommon", ergo = -2, light = true, laser = true, desc = "Light and visible laser in one housing. T turns it on and off; Ctrl+T switches between light, laser and both." })
part("LASER_DOT", "Tessel LP-1 laser pointer", "LP-1", "tactical", "pica", { w = 1, h = 1, mass = 0.07, value = 9500, ergo = -1, laser = true, desc = "Visible red laser: while it is on, hip fire is steadier. T turns it on and off." })

-- parts that cannot be on one build together (both directions are checked)
W.CONFLICTS = {
	R17_HG_MLOK = { R17_GAS_FSP = true },
	HAR_TUBE_6 = { HAR_BRL_14 = true },
	HAR_TUBE_8 = { HAR_BRL_14 = true, HAR_BRL_18 = true },
}

-- the builds traders sell (trees in GunMeta.presets): names in the stores
W.PRESET_NAMES = {
	R17_PATROL = "R-17 Carbine (Patrol)", R17_DMR = "R-17 Carbine (Marksman)", R17_CQB = "R-17 Carbine (Close quarters)",
	KST_TAC = "Kestrel KS-7 (Tactical)", KST_QUIET = "Kestrel KS-7 (Suppressed)", SPR_TAC = "Sparrow SMG-9 (Tactical)",
	HAR_TAC = "Harrow-12 (Tactical)", HAR_SHORT = "Harrow-12 (Short)", TUN_SCOUT = "Tundra (Scout)", TUN_MARKSMAN = "Tundra (Marksman)",
	P9_TAC = "P-9 Vesna (Tactical)",
}

-- magazines live in it.mag (the "mag" slot of a base): which magazine family a base takes (Items family)
W.MULTITOOL = "MULTITOOL"

-- ── night vision and thermal goggles (docs/design/EFT_PARITY.md section 6; the four kinds Tarkov has) ─────────
-- nv: mask (mono = a small circle, bino = a pair, quad = panoramic), phosphor tint, gain (exposure stops added),
-- grain (noise multiplier), bloom (how badly lights wash out), thermal (heat view: people white on dark brown,
-- light ignored, magnified optics unusable)
part("NV_MONO", "Nightjar NV-1 monocular", "NV-1", "nvg", "nvg_mount", { w = 1, h = 2, mass = 0.4, value = 105000, rarity = "rare",
	nv = { mask = "mono", tint = Color3.fromRGB(176, 255, 196), gain = 2.4, grain = 1.2, bloom = 0.35 },
	desc = "Single-tube monocular. Clear picture and good with lights, but the view is a small circle." })
part("NV_BINO", "Nightjar NV-2 binocular", "NV-2", "nvg", "nvg_mount", { w = 2, h = 1, mass = 0.5, value = 32000, rarity = "uncommon",
	nv = { mask = "bino", tint = Color3.fromRGB(130, 222, 255), gain = 2.1, grain = 2.2, bloom = 1.4 },
	desc = "Old binocular goggles with a blue-green phosphor. Grainy, and lights flare badly." })
part("NV_GREEN", "Hollis G-15 binocular", "G-15", "nvg", "nvg_mount", { w = 2, h = 1, mass = 0.45, value = 64000, rarity = "uncommon",
	nv = { mask = "bino", tint = Color3.fromRGB(150, 255, 150), gain = 2.3, grain = 1.6, bloom = 1.0 },
	desc = "Green binocular goggles. A fair picture; detail is lost round strong lights." })
part("NV_QUAD", "Nightjar NV-4 panoramic", "NV-4", "nvg", "nvg_mount", { w = 2, h = 2, mass = 0.9, value = 420000, rarity = "epic",
	nv = { mask = "quad", tint = Color3.fromRGB(190, 255, 205), gain = 2.6, grain = 0.7, bloom = 0.25 },
	desc = "Four-tube panoramic goggles: the widest view and the cleanest picture, barely bothered by lights." })
part("TH_T7", "Ember T-7 thermal goggles", "T-7", "nvg", "nvg_mount", { w = 2, h = 1, mass = 0.6, value = 1200000, rarity = "legendary",
	nv = { mask = "bino", thermal = true, tint = Color3.fromRGB(214, 168, 128), gain = 0, grain = 1.0, bloom = 0 },
	desc = "Thermal goggles: bodies glow white against a dark brown world, light or no light. Scopes can't be used with them; iron sights only." })

-- ── builds ───────────────────────────────────────────────────────────────────
-- A build is an item tree: an item's `mods` maps its slot names to the guids of the parts in them, parts carry
-- their own `mods`, and a weapon base also has `mag`. `items` is the holder's guid -> item table.
local GunMeta = require(script.Parent.GunMeta)
W.META = GunMeta
W.BASES = {} :: { [string]: boolean }
W.PRESETS_OF = {} :: { [string]: { string } } -- base id -> its other builds (traders, kits, loot)
for id, pr in GunMeta.presets do
	if pr.base == id then
		W.BASES[id] = true
	else
		W.PRESETS_OF[pr.base] = W.PRESETS_OF[pr.base] or {}
		table.insert(W.PRESETS_OF[pr.base], id)
	end
end
for _, list in W.PRESETS_OF do
	table.sort(list)
end
W.SIZE_TOL = 0.25 -- cells a build may overhang its grid size before it takes another row or column

-- the drawing order of a build's side picture (back to front): parts that sit inside others go first
W.LAYER = {
	barrel = 10, tube = 12, gasblock = 15, mag = 18, stock = 20, grip = 20, charge = 22, foregrip = 24, base = 28,
	receiver = 30, handguard = 40, ironfront = 45, ironrear = 45, muzzle = 50, mount = 55, sight = 60, tactical = 70,
}

function W.isBase(id: string?): boolean
	return id ~= nil and W.BASES[id] == true
end

-- can part `pid` go into slot `sname` of an item `parentId` (whatever is in it now)?
function W.fits(parentId: string, sname: string, pid: string): (boolean, string?)
	local s = W.SLOTS[parentId] and W.SLOTS[parentId][sname]
	if not s then
		return false, "NO_SLOT"
	end
	local p = W.parts[pid]
	if not p then
		return false, "NOT_A_PART"
	end
	if not table.find(p.fits, s.fit) then
		return false, "WRONG_FIT"
	end
	if s.cats and not s.cats[p.cat] then
		return false, "WRONG_TYPE"
	end
	return true, nil
end

-- visit a build, root first: fn(guid, item, parent guid, slot name, depth); the root's magazine as slot "mag"
function W.walk(items: any, g: string, fn: (string, any, string?, string?, number) -> (), parent: string?, sname: string?, depth: number?)
	local it = items[g]
	if not it then
		return
	end
	local dd = depth or 0
	fn(g, it, parent, sname, dd)
	if it.mods then
		local names = {}
		for s in it.mods do
			table.insert(names, s)
		end
		table.sort(names)
		for _, s in names do
			W.walk(items, it.mods[s], fn, g, s, dd + 1)
		end
	end
	if dd == 0 and it.mag and items[it.mag] then
		fn(it.mag, items[it.mag], g, "mag", 1)
	end
end

-- the parts of a build with their frames relative to the root: { { g, id, cf, slot, parentId, depth } }
function W.layout(items: any, g: string): { any }
	local out = {}
	local cfOf = {}
	W.walk(items, g, function(cg, it, parent, sname, depth)
		local cf = CFrame.identity
		local pid = parent and items[parent] and items[parent].id
		if parent and pid then
			local pm = GunMeta.parts[pid]
			local sl = pm and pm.slots[sname :: string]
			cf = (cfOf[parent] or CFrame.identity) * (sl or CFrame.identity)
		end
		cfOf[cg] = cf
		table.insert(out, { g = cg, id = it.id, cf = cf, slot = sname, parentId = pid, depth = depth })
	end)
	return out
end

-- grid size of a build from the geometry of its parts: length and height in cells at the picture class's scale
-- (Tarkov's attachments make a gun longer or taller in the inventory); nil for an item without a part record
function W.measure(items: any, g: string): (number?, number?)
	local root = items[g]
	local meta = root and GunMeta.parts[root.id]
	if not meta then
		return nil, nil
	end
	local z0, z1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
	local function add(id: string, cf: CFrame)
		local pm = GunMeta.parts[id]
		if pm then
			local ext = pm.ext
			for _, yy in { ext[3], ext[4] } do
				for _, zz in { ext[1], ext[2] } do
					local p = cf * Vector3.new(0, yy, zz)
					z0, z1 = math.min(z0, p.Z), math.max(z1, p.Z)
					y0, y1 = math.min(y0, p.Y), math.max(y1, p.Y)
				end
			end
		end
	end
	for _, e in W.layout(items, g) do
		add(e.id, e.cf)
	end
	-- an empty magazine well keeps the outline of the standard magazine (Tarkov: a 30-round magazine adds no
	-- size, so unloading a gun never shrinks it; a bigger magazine still grows it)
	if W.BASES[root.id] and root.mag == nil and meta.slots.mag then
		local pr = GunMeta.presets[root.id]
		local std = pr and pr.tree[2].mag
		if std then
			add(std[1], meta.slots.mag)
		end
	end
	if z0 > z1 then
		return nil, nil
	end
	local cpm = GunMeta.classes[meta.cls] or 5.5
	local k = cpm / GunMeta.U
	local w = math.max(1, math.ceil((z1 - z0) * k - W.SIZE_TOL))
	local h = math.max(1, math.ceil((y1 - y0) * k - W.SIZE_TOL))
	return w, h
end

-- a part's own measured size with nothing on it (cached)
local bareCache = {}
function W.bareSize(id: string): (number, number)
	local c = bareCache[id]
	if not c then
		local w, h = W.measure({ x = { id = id } }, "x")
		c = { w or 1, h or 1 }
		bareCache[id] = c
	end
	return c[1], c[2]
end

-- the grid size of a build. A weapon takes its measured size (taking its stock off makes it shorter, a
-- suppressor makes it longer). A part with parts on it keeps its own grid size and grows by what the parts add
-- past its own outline (Tarkov's ExtraSize: a barrel with a suppressor is longer than the bare barrel).
function W.buildSize(items: any, g: string, dw: number, dh: number): (number, number)
	local it = items[g]
	local w, h = W.measure(items, g)
	if not it or not w or not h then
		return dw, dh
	end
	if W.BASES[it.id] then
		return w, h
	end
	local bw, bh = W.bareSize(it.id)
	return dw + math.max(0, w - bw), dh + math.max(0, h - bh)
end

-- does this item get its grid size from its build (a weapon base, or a part with parts on it)?
function W.measured(it: any): boolean
	if not it then
		return false
	end
	if W.BASES[it.id] then
		return true
	end
	return it.mods ~= nil and next(it.mods) ~= nil and GunMeta.parts[it.id] ~= nil
end

-- the ids on a build (optionally skipping one guid's subtree): set of id -> guid
local function idsOn(items: any, rootG: string, skip: string?): { [string]: string }
	local ids = {}
	local skipSet = {}
	W.walk(items, rootG, function(cg, it, parent)
		if cg == skip or (parent and skipSet[parent]) then
			skipSet[cg] = true
			return
		end
		ids[it.id] = cg
	end)
	return ids
end

-- a part already on the build that cannot be together with `pid` (when `skip` is replaced, its subtree does not
-- count); returns that part's id
function W.conflict(items: any, rootG: string, pid: string, skip: string?): string?
	local mine = W.CONFLICTS[pid]
	for id in idsOn(items, rootG, skip) do
		if (mine and mine[id]) or (W.CONFLICTS[id] and W.CONFLICTS[id][pid]) then
			return id
		end
	end
	return nil
end

-- required slots that are empty: { { g = owner guid, id = owner id, slot = name } }
function W.missing(items: any, g: string): { any }
	local out = {}
	W.walk(items, g, function(cg, it)
		for sname, s in W.SLOTS[it.id] or {} do
			if s.req and not (it.mods and it.mods[sname] and items[it.mods[sname]]) then
				table.insert(out, { g = cg, id = it.id, slot = sname })
			end
		end
	end)
	table.sort(out, function(a, b)
		return a.slot < b.slot
	end)
	return out
end

-- a weapon that has every required part fires (Tarkov: a gun without a barrel or a bolt does not)
function W.operable(items: any, g: string): boolean
	return #W.missing(items, g) == 0
end

-- summed handling of a build, Tarkov-style: ergonomics in points, recoil / accuracy / velocity in percent,
-- loudness multiplied; sights, light, laser, the shell tube's capacity and the mass of the parts
function W.sum(items: any, g: string): any
	local st = { ergo = 0, recoilPct = 0, accPct = 0, velPct = 0, loud = 1, mass = 0, light = false, laser = false,
		zoom = nil :: number?, reflex = false, holo = false, range = nil :: number?, capacity = nil :: number?, sight = nil :: string?, n = 0 }
	local bestZ = -1
	W.walk(items, g, function(cg, it)
		local p = W.parts[it.id]
		if not p then
			return
		end
		st.n += 1
		st.ergo += p.ergo or 0
		st.recoilPct += p.recoil or 0
		st.accPct += p.acc or 0
		st.velPct += p.vel or 0
		st.loud *= p.loud or 1
		if p.cat == "muzzle" then
			-- the muzzle flash it leaves (Effects.flash): a brake throws more, a flash hider less, a suppressor none
			st.flash = (p.loud or 1) < 0.6 and 0 or (string.find(string.lower(p.desc or ""), "flash hider", 1, true) and 0.55)
				or ((p.loud or 1) > 1.05 and 1.35) or 1
		end
		st.mass += p.mass or 0
		st.light = st.light or p.light == true
		st.laser = st.laser or p.laser == true
		if p.capacity then
			st.capacity = p.capacity
		end
		if p.cat == "sight" then
			-- the optic in use: the most magnified, then a reflex sight (Tarkov lets you switch; ours picks)
			local z = p.zoom or 1
			if z > bestZ then
				bestZ = z
				st.sight = cg
				st.zoom = p.zoom
				st.reflex = p.reflex == true
				st.holo = p.holo == true
				st.range = p.range
			end
		elseif (p.cat == "ironrear" or p.cat == "ironfront") and not st.sight then
			st.range = math.max(st.range or 0, p.range or 0)
		end
	end)
	return st
end

-- the default build of each base, for handling relative to it (Weapons.luau tunes the default build)
local defaultSums = {}
local function defaultSum(baseId: string): any
	local s = defaultSums[baseId]
	if s then
		return s
	end
	local pr = GunMeta.presets[baseId]
	local items = {}
	local n = 0
	local function add(t): string
		n += 1
		local g = "d" .. n
		local it = { id = t[1] } :: any
		items[g] = it
		for sname, sub in t[2] do
			if sname ~= "mag" then
				it.mods = it.mods or {}
				it.mods[sname] = add(sub)
			end
		end
		return g
	end
	local root = pr and add(pr.tree) or nil
	s = root and W.sum(items, root) or W.sum({}, "none")
	defaultSums[baseId] = s
	return s
end
W.defaultSum = defaultSum

-- handling of a build relative to the base's default build (multipliers and an ergonomics delta), in the shape
-- the weapon code uses: { ergo, recoil, acc, vel, loud, zoom, reflex, holo, light, laser, suppressed, range,
-- capacity, sight, operable }
function W.stats(items: any, g: string): any
	local it = items[g]
	local s = W.sum(items, g)
	local d = it and W.BASES[it.id] and defaultSum(it.id) or { ergo = 0, recoilPct = 0, accPct = 0, velPct = 0, loud = 1 }
	return {
		ergo = s.ergo - d.ergo,
		recoil = math.max(0.3, (1 + s.recoilPct / 100) / (1 + d.recoilPct / 100)),
		acc = math.max(0.3, (1 + s.accPct / 100) / (1 + d.accPct / 100)),
		vel = math.max(0.5, (1 + s.velPct / 100) / (1 + d.velPct / 100)),
		loud = s.loud / math.max(0.05, d.loud),
		zoom = s.zoom, reflex = s.reflex, holo = s.holo, light = s.light, laser = s.laser,
		suppressed = s.loud < 0.6, range = s.range, capacity = s.capacity, sight = s.sight, mass = s.mass, flash = s.flash or 1,
		operable = W.operable(items, g),
		-- absolute Tarkov-style figures for the screens
		ergoPts = s.ergo, recoilPct = s.recoilPct, accPct = s.accPct, velPct = s.velPct,
	}
end

-- a string that changes whenever the build's parts change (visual rebuild keys)
function W.signature(items: any, g: string): string
	local out = {}
	W.walk(items, g, function(_, it, _, sname)
		table.insert(out, (sname or "") .. "=" .. it.id)
	end)
	return table.concat(out, ",")
end

-- the first empty slot on a build where part `pid` fits (shallow first): parent guid, slot name
function W.freeSlot(items: any, rootG: string, pid: string): (string?, string?)
	local best, bestS, bestD = nil, nil, math.huge
	W.walk(items, rootG, function(cg, it, _, _, depth)
		if depth >= bestD then
			return
		end
		local names = {}
		for sname in W.SLOTS[it.id] or {} do
			table.insert(names, sname)
		end
		table.sort(names)
		for _, sname in names do
			if not (it.mods and it.mods[sname]) and W.fits(it.id, sname, pid) then
				best, bestS, bestD = cg, sname, depth
				return
			end
		end
	end)
	return best, bestS
end

-- an occupied slot on the build where `pid` fits instead of the part there: parent guid, slot name
function W.swapSlot(items: any, rootG: string, pid: string): (string?, string?)
	local best, bestS = nil, nil
	W.walk(items, rootG, function(cg, it)
		if best then
			return
		end
		for sname, og in it.mods or {} do
			if items[og] and W.fits(it.id, sname, pid) then
				best, bestS = cg, sname
				return
			end
		end
	end)
	return best, bestS
end

return W
