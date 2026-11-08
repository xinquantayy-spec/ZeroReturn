--!strict
-- Item definitions (read-only, original names). Instances/ownership are server truth (server Services/Inv).
-- kinds: weapon | pistol | melee | mag | ammo | helmet | armor | rig | backpack | secure | med | food | key | loot | quest
--        | grenade | repair | headwear | headset | facecover | eyewear | nvg | plate
-- Values are in MK (Tarkov-like magnitudes). Optional blocks by kind:
--   caliber (weapon/pistol/mag/ammo), weapon (Weapons key), family (mag compatibility), capacity (mag / internal tube)
--   ammo = { dmg, pen, armorDmg, pellets, bleedL, bleedH, frag, subsonic }
--   armor = Plates.armour{ class (shown), mat, destr, blunt, type?, ric?, face?, dur (all parts), zones (set of Plates.ZONES),
--           parts = { { k, name, dur, class, zones, destr, blunt, ric, visor? } }, plates? = { [slot] = { fams, side?, def? } } }
--           (helmets, body armour, armoured rigs, plates, ballistic glasses, the welding mask; decision gameplay-2a)
--   plate = { pos = "any" | "front" | "back" | "side", fam = "west" | "east", shape }   (ballistic plates)
--   item records of armour: dur (all parts), sd? ({ [part] = durability }, more than one part), dmax?, mods?
--           ({ [plate slot] = plate guid }, carriers), pf? (true once the default plates went in)
--   eye = { flash, tint, shade, lens }   (eyewear and gas masks: flash = the share of a stun charge's white-out the lenses stop
--           (Tarkov's blindness protection), tint = lens colour, shade = 0..1 how strongly it tints the view, lens = its name)
--   grid = { w, h }   (rigs / backpacks / secure containers)
--   med = { light, heavy, fracture, pain, surgery, hp, uses, time, duration, stim (a Stims.DEFS id) }
--   food = { energy, water, time, stamina }
--   pen = { speed, turn, ergo }   (worn gear: movement speed, turn speed and weapon ergonomics in %, Tarkov)
--   key = { door, uses }
--   nade = { type = "frag"|"stun"|"smoke", fuse, frag: frags, fragR, fragDmg {lo,hi}, fragPen {lo,hi}, blastR, blastDmg;
--            stun: blindR, deafR; smoke: smokeR, smokeT }
--   repair = { points, uses }   (weapon repair kits)
local function c(hex: string): Color3
	return Color3.fromHex(hex)
end

local defs: { [string]: any } = {}

local function add(id: string, d: any)
	d.id = id
	d.stack = d.stack or 1
	d.mass = d.mass or 0.1
	d.rarity = d.rarity or "common"
	d.desc = d.desc or ""
	defs[id] = d
end

-- ── weapons ───────────────────────────────────────────────────────────────────
add("R17_RIFLE", { name = "R-17 Carbine", short = "R-17", kind = "weapon", w = 5, h = 2, mass = 1.3, value = 8000, caliber = "6.2", weapon = "R17", family = "R17", desc = "Fictional 6.2x40 service carbine. Dependable, stiff recoil.", color = c("#55605A") })
add("KST_RIFLE", { name = "Kestrel KS-7", short = "KS-7", kind = "weapon", w = 5, h = 2, mass = 2.4, value = 27000, caliber = "7.6", weapon = "KST", family = "KST", rarity = "uncommon", desc = "Stamped-receiver 7.6x39 rifle. Heavy hitter, climbs hard.", color = c("#5C5446") })
-- MORTAR's grenade launcher (decision ai-5b), in the place of EFT's M32A1 MSGL (Big Pipe's): six 40x46 rounds in a
-- revolving cylinder, loaded one at a time (guns_gl6.py; stats in Weapons.GL6)
add("GL6_LAUNCHER", { name = "Bittern GL-6", short = "GL-6", kind = "weapon", w = 4, h = 2, mass = 5.3, value = 98000, caliber = "40", weapon = "GL6", capacity = 6, rarity = "rare", desc = "Six-shot revolving grenade launcher for 40x46 rounds. A round arms only after about 20 m of flight: closer in it will not go off.", color = c("#2F3331") })
-- THE CARETAKER's light machine gun (decision ai-5b), in the place of EFT's RPK-16 (Killa's gun): the KS-7 action with a
-- heavy barrel and a folded bipod; every KS-7 part and magazine fits it (guns_ksl.py; stats in Weapons.KSL)
add("KSL_LMG", { name = "Kestrel KS-L", short = "KS-L", kind = "weapon", w = 6, h = 2, mass = 3.4, value = 43000, caliber = "7.6", weapon = "KSL", family = "KST", rarity = "rare", desc = "Light machine gun on the KS-7 action: a heavy barrel for long bursts and a folding bipod. Takes every KS-7 magazine and the 95-round drum.", color = c("#4A4A44") })
add("SPARROW_SMG", { name = "Sparrow SMG-9", short = "SMG-9", kind = "weapon", w = 3, h = 2, mass = 2.0, value = 11000, caliber = "9", weapon = "SPARROW", family = "SPARROW", desc = "Compact 9x19 submachine gun. Fast, controllable, weak against plates.", color = c("#4B5054") })
add("HARROW12", { name = "Harrow-12 Pump", short = "H-12", kind = "weapon", w = 6, h = 1, mass = 1.4, value = 4800, caliber = "12", weapon = "HARROW", capacity = 6, desc = "12-gauge pump with a 6-shell tube. Load shells directly.", color = c("#5A4B3C") })
add("TUNDRA_BOLT", { name = "Tundra Bolt Rifle", short = "TUNDRA", kind = "weapon", w = 6, h = 1, mass = 2.8, value = 40000, caliber = "7.6L", weapon = "TUNDRA", capacity = 5, rarity = "uncommon", desc = "Long bolt-action in 7.6x54. Five-round internal magazine.", color = c("#4F4A3B") })
add("P9_PISTOL", { name = "P-9 Vesna", short = "P-9", kind = "pistol", w = 2, h = 1, mass = 0.5, value = 2400, caliber = "9", weapon = "P9", family = "P9", desc = "9x19 service pistol. Holster sidearm.", color = c("#45494B") })
-- THE CULT's knife, looted from a warrior or the priest: in a player's hand it cuts like the field knife (logged gap)
add("RITUAL_KNIFE", { name = "Ritual Knife", short = "RITUAL", kind = "melee", w = 1, h = 2, mass = 0.25, value = 42000, rarity = "rare", weapon = "KNIFE", desc = "A cultist's blackened knife with a carved bone grip. Its poison is spent; in your hand it cuts like any knife.", color = c("#2E2A27") })
add("FIELD_KNIFE", { name = "Field Knife", short = "KNIFE", kind = "melee", w = 1, h = 2, mass = 0.3, value = 4000, weapon = "KNIFE", desc = "Fixed-blade utility knife.", color = c("#5E5E58") })

-- ── magazines ─────────────────────────────────────────────────────────────────
add("R17_MAG", { name = "R-17 25-rd Magazine", short = "MAG 25", kind = "mag", w = 1, h = 2, mass = 0.3, value = 2800, capacity = 25, caliber = "6.2", family = "R17", desc = "25-round steel box magazine for the R-17.", color = c("#3E4440") })
add("R17_MAG40", { name = "R-17 40-rd Magazine", short = "MAG 40", kind = "mag", w = 1, h = 3, mass = 0.45, value = 9500, capacity = 40, caliber = "6.2", family = "R17", rarity = "uncommon", desc = "Extended 40-round magazine. Slower to load, heavier on the rig.", color = c("#3A403D") })
add("KST_MAG", { name = "KS-7 30-rd Magazine", short = "MAG 30", kind = "mag", w = 1, h = 2, mass = 0.33, value = 3400, capacity = 30, caliber = "7.6", family = "KST", desc = "Curved 30-round 7.6x39 magazine.", color = c("#4A4237") })
add("SPARROW_MAG", { name = "SMG-9 30-rd Magazine", short = "MAG 30", kind = "mag", w = 1, h = 2, mass = 0.22, value = 2600, capacity = 30, caliber = "9", family = "SPARROW", desc = "Straight 30-round 9x19 stick magazine.", color = c("#3F4346") })
add("P9_MAG", { name = "P-9 17-rd Magazine", short = "MAG 17", kind = "mag", w = 1, h = 1, mass = 0.12, value = 1900, capacity = 17, caliber = "9", family = "P9", desc = "Double-stack pistol magazine.", color = c("#3C3F41") })
-- M14: more magazines (Tarkov-style: a bigger magazine makes the gun taller in the inventory)
add("R17_MAG60", { name = "R-17 60-rd Magazine", short = "MAG 60", kind = "mag", w = 1, h = 3, mass = 0.75, value = 22000, capacity = 60, caliber = "6.2", family = "R17", rarity = "rare", desc = "Quad-stack 60-round magazine. Heavy and slow to load, but you rarely need to.", color = c("#2E3230") })
add("KST_MAG_POLY", { name = "KS-7 30-rd Polymer Magazine", short = "MAG 30P", kind = "mag", w = 1, h = 2, mass = 0.25, value = 4200, capacity = 30, caliber = "7.6", family = "KST", desc = "Ribbed polymer 30-round magazine. Lighter than the steel one.", color = c("#3A3532") })
add("KST_MAG40", { name = "KS-7 40-rd Magazine", short = "MAG 40", kind = "mag", w = 1, h = 3, mass = 0.42, value = 11000, capacity = 40, caliber = "7.6", family = "KST", rarity = "uncommon", desc = "Long 40-round magazine from the support-weapon variant.", color = c("#42392F") })
-- the KS-L's drum: EFT's RPK-16 95-round drum, 0.68 kg (TarkovForge); its feed failures come from Weapons.magMalf
add("KSL_DRUM95", { name = "KS-L 95-rd Drum", short = "DRUM 95", kind = "mag", w = 2, h = 2, mass = 0.68, value = 31000, capacity = 95, caliber = "7.6", family = "KST", rarity = "rare", desc = "95-round drum for the KS-L light machine gun. It fits any KS-7 too. Slow to load and prone to feed failures.", color = c("#2E3131") })
add("SPR_MAG50", { name = "SMG-9 50-rd Drum", short = "DRUM 50", kind = "mag", w = 2, h = 2, mass = 0.6, value = 16000, capacity = 50, caliber = "9", family = "SPARROW", rarity = "rare", desc = "Twin-spring 50-round drum. Slow to load, heavy on the rig.", color = c("#34383A") })
add("P9_MAG33", { name = "P-9 33-rd Extended Magazine", short = "MAG 33", kind = "mag", w = 1, h = 2, mass = 0.24, value = 7400, capacity = 33, caliber = "9", family = "P9", rarity = "uncommon", desc = "Extended stick magazine for the P-9.", color = c("#35383A") })

-- ── ammunition ────────────────────────────────────────────────────────────────
local function ammo(id: string, name: string, short: string, caliber: string, stack: number, value: number, a: any, rarity: string?, desc: string?)
	add(id, { name = name, short = short, kind = "ammo", w = 1, h = 1, mass = 0.012, stack = stack, value = value, caliber = caliber, ammo = a, rarity = rarity, desc = desc or "", color = c("#A08A5C") })
end
ammo("A62_FMJ", "6.2x40 FMJ", "6.2 FMJ", "6.2", 60, 120, { dmg = 46, pen = 26, armorDmg = 0.38, bleedL = 0.12, bleedH = 0.06, frag = 0.2 }, nil, "General purpose full metal jacket.")
ammo("A62_AP", "6.2x40 AP", "6.2 AP", "6.2", 60, 650, { dmg = 41, pen = 43, armorDmg = 0.55, bleedL = 0.1, bleedH = 0.05, frag = 0.05 }, "uncommon", "Hardened core. Defeats class 4 plates.")
ammo("A62_HP", "6.2x40 HP", "6.2 HP", "6.2", 60, 90, { dmg = 62, pen = 12, armorDmg = 0.25, bleedL = 0.3, bleedH = 0.15, frag = 0.45 }, nil, "Hollow point. Brutal on flesh, useless on plates.")
ammo("A76_PS", "7.6x39 PS", "7.6 PS", "7.6", 60, 140, { dmg = 54, pen = 35, armorDmg = 0.52, bleedL = 0.15, bleedH = 0.08, frag = 0.17 }, nil, "Mild steel core 7.6x39.")
ammo("A76_BP", "7.6x39 BP", "7.6 BP", "7.6", 60, 780, { dmg = 50, pen = 47, armorDmg = 0.58, bleedL = 0.12, bleedH = 0.07, frag = 0.12 }, "rare", "Armor-piercing 7.6x39.")
ammo("A76_US", "7.6x39 US", "7.6 US", "7.6", 60, 220, { dmg = 58, pen = 10, armorDmg = 0.3, bleedL = 0.2, bleedH = 0.1, frag = 0.1, subsonic = true }, "uncommon", "Subsonic heavy bullet. Quiet with a suppressor.")
ammo("A9_PST", "9x19 PST", "9 PST", "9", 50, 80, { dmg = 54, pen = 20, armorDmg = 0.33, bleedL = 0.12, bleedH = 0.05, frag = 0.15 }, nil, "Steel-core 9x19.")
ammo("A9_AP", "9x19 AP", "9 AP", "9", 50, 420, { dmg = 48, pen = 30, armorDmg = 0.4, bleedL = 0.1, bleedH = 0.05, frag = 0.05 }, "uncommon", "Penetrator 9x19.")
ammo("A9_RIP", "9x19 RIP", "9 RIP", "9", 50, 260, { dmg = 102, pen = 2, armorDmg = 0.11, bleedL = 0.4, bleedH = 0.3, frag = 1 }, "uncommon", "Fragmenting hollow point.")
ammo("A12_BUCK", "12/70 Buckshot", "12 BUCK", "12", 20, 90, { dmg = 37, pen = 1, armorDmg = 0.65, pellets = 8, bleedL = 0.25, bleedH = 0.1, frag = 0 }, nil, "Eight pellets per shell.")
-- the GL-6's round (ai-5b), after EFT's 40x46 M406 (HE): 76 m/s, armed after 0.26 s of flight, an explosion of 1 to
-- 7 m (the wiki's 40x46mm page); the fragments, blast and their reach are in our grenade model (Grenades.luau)
add("A40_HE", { name = "40x46 HE Grenade", short = "40 HE", kind = "ammo", w = 1, h = 1, mass = 0.23, stack = 1, value = 9000, caliber = "40", rarity = "rare",
	ammo = { dmg = 199, pen = 1, armorDmg = 0.95, bleedL = 0, bleedH = 0, frag = 0, subsonic = true },
	nade = { type = "frag", impact = true, arm = 0.26, flight = 10, fuse = 10, frags = 120, fragR = 22, fragDmg = { 24, 38 }, fragPen = { 10, 17 }, blastR = 6, blastDmg = 120 },
	desc = "High-explosive 40x46 grenade for the GL-6. It arms after about 20 m of flight and goes off where it strikes.", color = c("#4F5539") })
ammo("A12_SLUG", "12/70 Slug", "12 SLUG", "12", 20, 380, { dmg = 168, pen = 22, armorDmg = 0.75, bleedL = 0.3, bleedH = 0.2, frag = 0.1 }, "uncommon", "Single heavy lead slug.")
ammo("A76L_LPS", "7.6x54R LPS", "7.6L LPS", "7.6L", 40, 520, { dmg = 81, pen = 42, armorDmg = 0.78, bleedL = 0.2, bleedH = 0.15, frag = 0.18 }, "uncommon", "Full-power rifle cartridge.")
ammo("A76L_SNB", "7.6x54R SNB", "7.6L SNB", "7.6L", 40, 1600, { dmg = 75, pen = 62, armorDmg = 0.87, bleedL = 0.15, bleedH = 0.12, frag = 0.08 }, "rare", "Sniper armor-piercing load.")

-- ── armour, plates, helmets (Tarkov since 0.14, decision gameplay-2a; the rules in Plates.luau) ──────────────────────
-- A vest or rig is built-in soft armour in parts (front, back, sides, collar, groin...), each with its own durability and
-- covering only its zones, plus plate slots (front, back, sides) for separate plates. A helmet is parts too (top, nape,
-- ears, a face shield). Each entry copies a Tarkov 1.0 counterpart (named in its comment) for class, material, weight,
-- penalties, blunt throughput and zones (tarkovforge.com armour, helmet and plate charts and item pages, 2026-11-08; the
-- EFT wiki's Armor plates page for plate penalties). Durability: tarkovforge's figure for the whole item less its default
-- plates, split evenly over the parts (EFT gives every helmet part the same share: Altyn 81 = 3 x 27, FAST MT 48 = 2 x 24;
-- the even split of vests is ours). Values in MK keep each kit (carrier + default plates) at its old price.
local PL = require(script.Parent.Plates)
local WEST, EAST, BOTH = { west = true }, { east = true }, { west = true, east = true }

-- Plates (EFT 1.0: 37 plates; these 16 copy one each). pos: "any" (front or back), "front", "back" or "side"; fam: the
-- carriers that take it (west = SAPI-type universal plates, east = the Russian vests' own); shape: the area it covers
-- (Plates.SHAPES). Grid size 2 x 3 (sides 1 x 2) is ours.
local function plate(id: string, name: string, short: string, cls: number, dur: number, mat: string, kg: number, pos: string, fam: string, shape: string, pen: any, value: number, rarity: string, desc: string)
	local side = pos == "side"
	add(id, {
		name = name, short = short, kind = "plate", w = side and 1 or 2, h = side and 2 or 3, mass = kg, value = value, rarity = rarity,
		-- blunt 20 % for every plate is ours (the plate pages give none)
		armor = PL.armour({ class = cls, mat = mat, blunt = 0.2, parts = { { "plate", dur } } }),
		plate = { pos = pos, fam = fam, shape = side and "side" or shape }, pen = pen, desc = desc, color = c(mat == "ceramic" and "#6A665C" or mat == "steel" and "#4E5250" or "#5E6258"),
	})
end
-- universal SAPI-type plates (front or back of a western carrier, and of the Russian vests whose slot is SAPI-shaped)
plate("PLATE_PE3", "Kite PE Plate", "KITE III", 3, 35, "uhmwpe", 0.43, "any", "west", "sapi", { speed = -1, ergo = -1 }, 25000, "uncommon", "Thin polyethylene plate, class 3. Almost weightless; it stops pistol rounds and buckshot, not rifles. Front or back.") -- PRTCTR Lightweight
plate("PLATE_PE4", "Heron PE Plate", "HERON IV", 4, 40, "uhmwpe", 1.35, "any", "west", "sapi", { speed = -1, ergo = -1 }, 24000, "uncommon", "Polyethylene plate, class 4. Light, and it holds up well to repairs. Front or back.") -- Monoclete level III PE
plate("PLATE_CE4", "Shale Ceramic Plate", "SHALE IV", 4, 45, "ceramic", 1.6, "any", "west", "sapi", { speed = -1, ergo = -1.5 }, 20000, "uncommon", "Ceramic plate, class 4. Light, but ceramic cracks fast and repairs badly. Front or back.") -- SPRTN Elaphros
plate("PLATE_CE5", "Basalt Ceramic Plate", "BASALT V", 5, 50, "ceramic", 1.82, "any", "west", "sapi", { speed = -1, turn = -0.5, ergo = -1.5 }, 62000, "rare", "Ceramic plate, class 5. Front or back.") -- SAPI level III+
plate("PLATE_PE5", "Egret PE Plate", "EGRET V", 5, 45, "uhmwpe", 0.97, "any", "west", "sapi", { speed = -1, ergo = -1 }, 88000, "rare", "Polyethylene plate, class 5, under a kilogram. Front or back.") -- GAC 3s15m
plate("PLATE_CE6", "Obsidian Ceramic Plate", "OBSIDIAN VI", 6, 55, "ceramic", 3.2, "any", "west", "sapi", { speed = -1.5, turn = -0.5, ergo = -1.5 }, 115000, "epic", "Ceramic plate, class 6. Stops almost anything a few times. Front or back.") -- ESAPI level IV
plate("PLATE_PE6", "Albatross PE Plate", "ALBATROSS VI", 6, 50, "uhmwpe", 2.7, "any", "west", "sapi", { speed = -1.5, turn = -0.5, ergo = -1.5 }, 155000, "epic", "Polyethylene plate, class 6. Front or back.") -- GAC 4sss2
plate("PLATE_CE5S", "Basalt Ceramic Side Plate", "BASALT S", 5, 15, "ceramic", 1.0, "side", "west", "side", { speed = -0.5, turn = -0.5 }, 14000, "rare", "Small ceramic side plate, class 5, for the side pockets of a western carrier.") -- SSAPI level III+ (Side)
-- the Russian vests' own plates (front-only, back-only and side)
plate("PLATE_PC4F", "PC-4 Steel Front Plate", "PC-4 F", 4, 50, "steel", 3.7, "front", "east", "korund", { speed = -2.5, turn = -1, ergo = -1 }, 14000, "uncommon", "Tall steel chest plate, class 4, the PC-4's own. It reaches the top of the stomach but leaves the upper corners of the chest.") -- 6B33 (Front)
plate("PLATE_PC4B", "PC-4 Steel Back Plate", "PC-4 B", 4, 40, "steel", 3.5, "back", "east", "sapi", { speed = -1.5, ergo = -0.5 }, 9000, "uncommon", "Steel back plate, class 4, the PC-4's own.") -- 6B23-2 (Back)
plate("PLATE_HP5F", "HP-5 Steel Front Plate", "HP-5 F", 5, 60, "steel", 3.4, "front", "east", "korund", { speed = -2, turn = -1, ergo = -1 }, 29000, "rare", "Tall steel chest plate, class 5, the HP-5's own.") -- Korund-VM (Front)
plate("PLATE_HP5B", "HP-5 Steel Back Plate", "HP-5 B", 5, 40, "steel", 2.3, "back", "east", "sapi", { speed = -1, turn = -0.5, ergo = -1 }, 24000, "rare", "Steel back plate, class 5, the HP-5's own.") -- Korund-VM (Back)
plate("PLATE_HP5S", "HP-5 Steel Side Plate", "HP-5 S", 5, 25, "steel", 1.1, "side", "east", "side", { speed = -0.5 }, 11000, "rare", "Steel side plate, class 5, for the HP-5's high side pockets under the arm.") -- Korund-VM (Side)
plate("PLATE_BWF", "Bulwark Ceramic Front Plate", "BULWARK F", 6, 55, "ceramic", 3.5, "front", "east", "sapi", { speed = -2.5, turn = -2, ergo = -1.5 }, 70000, "epic", "Ceramic chest plate, class 6, the Bulwark's own.") -- Granit 4RS (Front)
plate("PLATE_BWB", "Bulwark Ceramic Back Plate", "BULWARK B", 6, 50, "ceramic", 3.8, "back", "east", "sapi", { speed = -2, turn = -1, ergo = -1 }, 60000, "epic", "Ceramic back plate, class 6, the Bulwark's own.") -- Granit 4RS (Back)
plate("PLATE_BWS", "Bulwark Ceramic Side Plate", "BULWARK S", 6, 20, "ceramic", 1.3, "side", "east", "side", { speed = -0.75, turn = -0.75 }, 30000, "epic", "Ceramic side plate, class 6, for the Bulwark's low side pockets.") -- Granit (Side)

-- body armour (soft parts' class in pc where plates make the item's class higher)
add("ARMOR_C2", { name = "Quay Security Vest", short = "VEST II", kind = "armor", w = 3, h = 3, mass = 3.5, value = 18000,
	-- PACA soft armour: class 2 aramid all round the torso, 100 durability, 3.5 kg, speed -1 ergo -1, blunt 35.6 %
	armor = PL.armour({ class = 2, mat = "aramid", blunt = 0.356, type = "light", parts = { { "front", 25 }, { "back", 25 }, { "left", 25 }, { "right", 25 } } }),
	pen = { speed = -1, ergo = -1 },
	desc = "Soft aramid security vest, class 2 all round the torso: chest and stomach, the back and both sides. No plate pockets; it stops pistol rounds and buckshot, not rifle rounds.", color = c("#4C5545") })
add("ARMOR_C3", { name = "Patrol Soft Armor", short = "VEST III", kind = "armor", w = 3, h = 3, mass = 8.5, value = 38000,
	-- MF-UNTAR body armour: class 3 aluminium inserts all round the torso, 100 durability, 8.5 kg, -3/-1/-2, blunt 23.8 %
	armor = PL.armour({ class = 3, mat = "aluminium", blunt = 0.238, type = "light", parts = { { "front", 25 }, { "back", 25 }, { "left", 25 }, { "right", 25 } } }),
	pen = { speed = -3, turn = -1, ergo = -2 },
	desc = "Patrol vest with aluminium inserts, class 3 all round the torso: chest and stomach, the back and both sides. Heavy for what it stops, and no plate pockets.", color = c("#4A5242") })
add("ARMOR_C4", { name = "PC-4 Plate Carrier", short = "PC-4", kind = "armor", w = 3, h = 3, mass = 3.3, value = 59000, rarity = "uncommon",
	-- 6B23-2: class 2 soft armour nearly everywhere (collar, groin, buttocks too), class 4 plates front (Korund-shaped) and
	-- back (SAPI-shaped); 246 durability with its plates, 3.3 kg empty, -1/-1/-2.5, blunt 33 % (GGRecon 0.14.11; tarkovforge)
	armor = PL.armour({ class = 4, pc = 2, mat = "aramid", blunt = 0.33, type = "light",
		parts = { { "front", 22 }, { "back", 22 }, { "left", 22 }, { "right", 22 }, { "collar", 22 }, { "groin", 22 }, { "buttocks", 22 } },
		plates = { front = { fams = EAST, def = "PLATE_PC4F" }, back = { fams = BOTH, def = "PLATE_PC4B" } } }),
	pen = { speed = -1, turn = -1, ergo = -2.5 },
	desc = "Carrier with class 2 soft armour almost everywhere, the collar, groin and buttocks too, and a front and a back plate pocket. Comes with its class 4 steel plates.", color = c("#575A47") })
add("ARMOR_C5", { name = "HP-5 Heavy Vest", short = "HP-5", kind = "armor", w = 3, h = 3, mass = 1.9, value = 90000, rarity = "rare",
	-- Korund-VM: soft armour nearly everywhere, class 5 steel plates front (Korund), back (SAPI) and both high sides;
	-- 310 durability with plates, 1.9 kg empty, -5/-2.5/-3, blunt 28.5 %, heavy. Its soft armour's class 3 is ours.
	armor = PL.armour({ class = 5, pc = 3, mat = "aramid", blunt = 0.285, type = "heavy",
		parts = { { "front", 23 }, { "back", 23 }, { "left", 23 }, { "right", 23 }, { "collar", 23 }, { "groin", 23 }, { "buttocks", 23 } },
		plates = {
			front = { fams = EAST, def = "PLATE_HP5F" }, back = { fams = BOTH, def = "PLATE_HP5B" },
			lside = { fams = EAST, side = "high", def = "PLATE_HP5S" }, rside = { fams = EAST, side = "high", def = "PLATE_HP5S" },
		} }),
	pen = { speed = -5, turn = -2.5, ergo = -3 },
	desc = "Heavy vest: class 3 soft armour almost everywhere, with front, back and high side plate pockets. Comes with its class 5 steel plates. Slows you down.", color = c("#4D4F45") })
add("ARMOR_C6", { name = "Bulwark Assault Armor", short = "BULWARK", kind = "armor", w = 4, h = 4, mass = 10.8, value = 140000, rarity = "epic",
	-- 6B43 Zabralo-Sh: soft armour with shoulders and collar, class 6 plates front, back (SAPI) and low sides; 510
	-- durability with plates, 10.8 kg empty, -9/-5.5/-7, blunt 29.7 %, heavy. Its soft armour's class 3 is ours.
	armor = PL.armour({ class = 6, pc = 3, mat = "aramid", blunt = 0.297, type = "heavy",
		parts = { { "front", 45 }, { "back", 45 }, { "left", 45 }, { "right", 45 }, { "collar", 45 }, { "groin", 45 }, { "shoulders", 90 } },
		plates = {
			front = { fams = BOTH, def = "PLATE_BWF" }, back = { fams = BOTH, def = "PLATE_BWB" },
			lside = { fams = BOTH, side = "low", def = "PLATE_BWS" }, rside = { fams = BOTH, side = "low", def = "PLATE_BWS" },
		} }),
	pen = { speed = -9, turn = -5.5, ergo = -7 },
	desc = "Assault armour: class 3 soft armour from the collar to the groin, shoulders included, with front, back and low side plate pockets. Comes with its class 6 ceramic plates. Very heavy.", color = c("#3E423D") })

-- helmets (parts: top, nape, ears; Tarkov's helmet zones are chosen by where the hit lands)
add("HELMET_C2", { name = "Shell Helmet", short = "SHELL", kind = "helmet", w = 2, h = 2, mass = 1.9, value = 14000,
	-- Kolpak-1S riot helmet: class 2 aramid, top, nape and ears, 45 durability, 1.9 kg, turn -2, ergo -2, blunt 23.8 %, low ricochet (EFT wiki)
	armor = PL.armour({ class = 2, mat = "aramid", blunt = 0.238, ric = "low", parts = { { "top", 15 }, { "nape", 15 }, { "ears", 15 } } }),
	pen = { turn = -2, ergo = -2 }, desc = "Class 2 riot helmet in pressed aramid. Covers the top, the nape and the ears; no room for a headset.", color = c("#55593F") })
add("HELMET_C3", { name = "Tac Helmet", short = "TAC III", kind = "helmet", w = 2, h = 2, mass = 0.95, value = 34000,
	-- LShZ light helmet: class 3 aramid, top and nape, 36 durability, 0.95 kg, turn -1, ergo -1, blunt 23.8 %, medium ricochet
	armor = PL.armour({ class = 3, mat = "aramid", blunt = 0.238, ric = "medium", parts = { { "top", 18 }, { "nape", 18 } } }),
	pen = { turn = -1, ergo = -1 }, desc = "Class 3 cut helmet with rails and a night-vision mount. Covers the top and the nape; the ears stay open for a headset.", color = c("#4F5340") })
add("HELMET_C4", { name = "Ballistic Helmet B4", short = "B4", kind = "helmet", w = 2, h = 2, mass = 0.9, value = 78000, rarity = "uncommon",
	-- Ops-Core FAST MT: class 4 combined materials, top and nape, 48 durability, 0.9 kg, turn -1, ergo -1, blunt 14.3 %, high ricochet
	armor = PL.armour({ class = 4, mat = "combined", blunt = 0.143, ric = "high", parts = { { "top", 24 }, { "nape", 24 } } }),
	pen = { turn = -1, ergo = -1 }, desc = "Class 4 high-cut helmet with a night-vision mount. Covers the top and the nape; bullets that glance off it often ricochet.", color = c("#45493C") })
add("HELMET_C5", { name = "Bulwark Faceplate Helmet", short = "FACEPLATE", kind = "helmet", w = 2, h = 2, mass = 3.5, value = 260000, rarity = "epic",
	-- Altyn: class 5 armoured steel, top, nape and ears, 81 durability, 2.5 kg, -1/-4/-3, blunt 16.7 %, high ricochet;
	-- its face shield (eyes and jaws, raised with N) as class 5 steel of 50 and 1 kg is ours
	armor = PL.armour({ class = 5, mat = "steel", blunt = 0.167, ric = "high", face = true,
		parts = { { "top", 27 }, { "nape", 27 }, { "ears", 27 }, { "visor", 50 } } }),
	pen = { speed = -1, turn = -4, ergo = -3 }, desc = "Class 5 steel helmet with a steel face shield. Covers the top, the nape and the ears, and with the shield down the eyes and the jaw.", color = c("#34372F") })

-- THE FOREMAN's hard hat: no Tarkov counterpart; class 2 over the top only, in polyethylene (ours)
add("HARDHAT_FOREMAN", { name = "Foreman's Hard Hat", short = "HARD HAT", kind = "helmet", w = 2, h = 2, mass = 0.6, value = 98000, rarity = "rare",
	armor = PL.armour({ class = 2, mat = "uhmwpe", blunt = 0.35, ric = "medium", parts = { { "top", 22 } } }),
	desc = "The Quay foreman's battered hard hat with a lamp bracket. Class 2 over the top of the head only. Stops little; worth a lot to the right people.", color = c("#C9A23C") })

-- ── headwear, headsets, face covers (M16 visible equipment; no protection) ─────────────────────────────
add("CAP_FIELD", { name = "Field Cap", short = "CAP", kind = "headwear", w = 2, h = 1, mass = 0.1, value = 2500, desc = "Soft patrol cap. Keeps the sun out of your eyes; stops nothing.", color = c("#4A4A3E") })
add("BEANIE", { name = "Knit Beanie", short = "BEANIE", kind = "headwear", w = 1, h = 1, mass = 0.1, value = 1800, desc = "Warm knit hat. No protection.", color = c("#3A3833") })
add("HEADSET_GS1", { name = "GS-1 Active Headset", short = "GS-1", kind = "headset", w = 2, h = 1, mass = 0.35, value = 21000, rarity = "uncommon", desc = "Electronic hearing protection: quiet sounds carry further, blasts and stun charges deafen you less. Fits under cut helmets, caps and beanies, not full-cut shells or a hard hat.", color = c("#3A3D36") })
add("HEADSET_COMM", { name = "Comms Headset", short = "COMMS", kind = "headset", w = 2, h = 1, mass = 0.4, value = 34000, rarity = "rare", desc = "Hearing protection with a boom microphone. Same hearing as the GS-1. Fits under cut helmets and caps.", color = c("#2A2C2E") })
add("GAITER", { name = "Field Gaiter", short = "GAITER", kind = "facecover", w = 1, h = 1, mass = 0.08, value = 1500, desc = "Fabric neck gaiter worn over the mouth and nose. Cosmetic.", color = c("#6B6B5E") })

-- ── eyewear and the gas mask (Tarkov: the EYEWEAR slot, EFT_PARITY.md section 6) ────────────────────────────
-- Glasses shorten a stun charge's white-out (blindness protection: sport sunglasses 15 %, safety glasses 15 %, ballistic
-- glasses 10-15 %). Only ballistic glasses have armour (class 1-2, zone EYES) and so a durability; the rest have none, as in
-- Tarkov. Weights, values and the trader levels follow the wiki's rows (docs/design/EFT_PARITY.md, sources). A gas mask is a
-- face cover with no armour that leaves no room for glasses (Equipment.VIS blocks).
add("GLASSES_SUN", { name = "Sport Sunglasses", short = "SUNGLASSES", kind = "eyewear", w = 2, h = 1, mass = 0.05, value = 2250,
	eye = { flash = 0.15, tint = c("#6B4A2C"), shade = 0.14, lens = "BROWN" },
	desc = "Wrap-around sport sunglasses with brown lenses; the view darkens a little. A stun charge blinds you a little less; they stop nothing.", color = c("#4A3828") })
add("GLASSES_RANGE", { name = "Range Glasses", short = "RANGE", kind = "eyewear", w = 1, h = 1, mass = 0.03, value = 6900,
	eye = { flash = 0.15, tint = c("#E0BE3A"), shade = 0.1, lens = "YELLOW" },
	desc = "Shooting glasses with yellow lenses; the view takes a warm tint. A stun charge blinds you a little less; they stop nothing.", color = c("#C4A63C") })
add("GLASSES_BG1", { name = "BG-1 Ballistic Glasses", short = "BG-1", kind = "eyewear", w = 2, h = 1, mass = 0.11, value = 20000, rarity = "uncommon",
	armor = PL.armour({ class = 1, mat = "glass", blunt = 0.35, parts = { { "eyes", 25 } } }), eye = { flash = 0.1, tint = c("#C9D6DC"), shade = 0.03, lens = "CLEAR" },
	desc = "Clear class 1 ballistic glasses. They stop fragments, buckshot and weak rounds that hit the eyes; a rifle bullet goes straight through.", color = c("#5C666B") })
add("GLASSES_AF2", { name = "AF-2 Anti-Fragmentation Glasses", short = "AF-2", kind = "eyewear", w = 2, h = 1, mass = 0.27, value = 40000, rarity = "rare",
	armor = PL.armour({ class = 2, mat = "glass", blunt = 0.3, parts = { { "eyes", 30 } } }), eye = { flash = 0.15, tint = c("#4678C8"), shade = 0.1, lens = "BLUE" },
	desc = "Blue-lens class 2 anti-fragmentation glasses on a head strap. Heavier than the BG-1, and they hold up to a few more hits.", color = c("#3E5E8C") })
add("GAS_MASK", { name = "Canister Gas Mask", short = "GAS MASK", kind = "facecover", w = 2, h = 2, mass = 0.45, value = 45000, rarity = "uncommon",
	eye = { flash = 0, tint = c("#3C4B3C"), shade = 0.16, lens = "SMOKED" },
	desc = "Full-face rubber mask with two lenses and a filter canister. The rubber frames your view and the lenses are smoked; there is no room for glasses under it. It is not armour.", color = c("#4A5240") })
-- THE STOKER's welding mask (Tarkov: Tagilla's welding masks, face cover class 5, durability 40, 50 % blindness protection,
-- 1.5 kg): a steel face cover that is armour for the face (Health.armorFor reads face covers with zones.face)
add("MASK_WELDER", { name = "Stoker's Welding Mask", short = "WELD MASK", kind = "facecover", w = 2, h = 2, mass = 1.5, value = 95000, rarity = "epic",
	armor = PL.armour({ class = 5, mat = "steel", blunt = 0.2, parts = { { "face", 40, zones = { "face" } } } }), eye = { flash = 0.5, tint = c("#2A2C26"), shade = 0.32, lens = "SMOKED" },
	desc = "A boiler stoker's steel welding mask with a dark slit. Class 5 for the face; the view through the slit is narrow and dim, and a stun charge's flash blinds you half as much.", color = c("#3A3B35") })

-- ── rigs, backpacks, secure containers ───────────────────────────────────────
add("RIG_BELT", { name = "Utility Belt", short = "BELT", kind = "rig", w = 2, h = 2, mass = 0.4, value = 6000, grid = { w = 4, h = 1 }, desc = "Four pouches on a belt.", color = c("#5E5A47") })
add("RIG_CHEST", { name = "Chest Rig", short = "CHEST RIG", kind = "rig", w = 2, h = 2, mass = 0.8, value = 16000, grid = { w = 4, h = 2 }, desc = "Open chest rig, eight cells.", color = c("#5A5844") })
-- an armoured rig: FirstSpear Strandhogg (class 2 soft armour over the chest, stomach, upper back and sides, SAPI plates
-- front and back, high side plate pockets; 198 durability with plates, 3.2 kg empty, speed -1, blunt 24 %). Its soft
-- class 2 and the two class 4 plates it comes with are ours.
add("RIG_PLATE", { name = "Assault Plate Rig", short = "PLATE RIG", kind = "rig", w = 3, h = 3, mass = 3.2, value = 47000, rarity = "uncommon", grid = { w = 4, h = 2 },
	armor = PL.armour({ class = 4, pc = 2, mat = "aramid", blunt = 0.24, type = "light",
		parts = { { "front", 30 }, { "back", 30, zones = { "uback" } }, { "left", 30 }, { "right", 30 } },
		plates = {
			front = { fams = WEST, def = "PLATE_PE4" }, back = { fams = WEST, def = "PLATE_PE4" },
			lside = { fams = WEST, side = "high" }, rside = { fams = WEST, side = "high" },
		} }),
	pen = { speed = -1 }, desc = "Armoured rig: class 2 soft armour over the chest, stomach, upper back and sides, a front and a back plate pocket (two class 4 polyethylene plates come with it) and side plate pockets. Cannot be worn with body armour.", color = c("#4F513F") })
add("BAG_SLING", { name = "Day Bag", short = "DAY BAG", kind = "backpack", w = 2, h = 2, mass = 0.4, value = 7500, grid = { w = 3, h = 2 }, desc = "Small two-strap day bag.", color = c("#6B6A4E") })
add("CANVAS_BAG", { name = "Canvas Pack", short = "CANVAS", kind = "backpack", w = 3, h = 3, mass = 0.9, value = 18000, grid = { w = 4, h = 4 }, pen = { speed = -1 }, desc = "Worn canvas backpack with a 4x4 compartment.", color = c("#6B6A4E") })
add("BAG_PATROL", { name = "Patrol Pack", short = "PATROL", kind = "backpack", w = 4, h = 4, mass = 1.3, value = 42000, rarity = "uncommon", grid = { w = 5, h = 5 }, pen = { speed = -2, turn = -1 }, desc = "Framed patrol pack.", color = c("#5C5B44") })
-- THE FORESTER's bag (Tarkov's Partisan's bag: 4x3 outside, 20 slots, 0.7 kg, -5 % speed, -2 % turn, -8 ergonomics)
add("FORESTER_PACK", { name = "Forester's Pack", short = "FORESTER", kind = "backpack", w = 4, h = 3, mass = 0.7, value = 95000, rarity = "rare", grid = { w = 5, h = 4 }, pen = { speed = -5, turn = -2, ergo = -8 }, desc = "A patched canvas hunting pack that carries more than its size suggests. Taken from the man who lays wires in the woods.", color = c("#4C4A36") })
add("BAG_RAID", { name = "Raid Pack", short = "RAID", kind = "backpack", w = 5, h = 5, mass = 2.1, value = 88000, rarity = "rare", grid = { w = 6, h = 6 }, pen = { speed = -3, turn = -2 }, desc = "Large expedition pack. Heavy when full.", color = c("#53523F") })
add("SECURE_S", { name = "Pouch S", short = "POUCH S", kind = "secure", w = 2, h = 2, mass = 0.5, value = 0, grid = { w = 2, h = 2 }, desc = "Secure container. Contents survive death.", color = c("#3B3F3F") })
-- the bigger pouches have EFT's paths (audit economy.7): M is TILDA's loyalty 2 barter (EFT's Beta from Peacekeeper at
-- LL2), L is the reward of FENCE's collector task (EFT's Kappa from Fence's The Collector)
add("SECURE_M", { name = "Pouch M", short = "POUCH M", kind = "secure", w = 3, h = 3, mass = 0.7, value = 0, rarity = "rare", grid = { w = 3, h = 3 }, desc = "Secure container. Contents survive death. DEKKER trades one for military electronics at loyalty 2.", color = c("#3B3F3F") })
add("SECURE_L", { name = "Pouch L", short = "POUCH L", kind = "secure", w = 3, h = 4, mass = 0.9, value = 0, rarity = "epic", grid = { w = 4, h = 3 }, desc = "Secure container. Contents survive death. FENCE gives one to an operator who brings him a collection of rare valuables.", color = c("#3B3F3F") })

-- ── medical, provisions ───────────────────────────────────────────────────────
local MED = c("#C9CDBE")
add("BANDAGE", { name = "Field Dressing", short = "DRESSING", kind = "med", w = 1, h = 1, mass = 0.05, value = 2500, med = { light = true, uses = 1, time = 3 }, desc = "Stops a light bleed.", color = MED })
add("TOURNIQUET", { name = "Strap Tourniquet", short = "TQ", kind = "med", w = 1, h = 1, mass = 0.08, value = 6500, med = { heavy = true, limbsOnly = true, uses = 1, time = 3 }, desc = "Stops a heavy bleed on a limb.", color = MED })
add("HEMOSTAT", { name = "Hemostatic Pack", short = "HEMO", kind = "med", w = 1, h = 1, mass = 0.1, value = 14000, rarity = "uncommon", med = { heavy = true, light = true, uses = 3, time = 2.5 }, desc = "Stops light and heavy bleeds. 3 uses.", color = MED })
add("SPLINT", { name = "Ladder Splint", short = "SPLINT", kind = "med", w = 1, h = 1, mass = 0.1, value = 3500, med = { fracture = true, uses = 1, time = 4.5 }, desc = "Sets a fracture.", color = MED })
-- the cult's toxin (THE CULT, Tarkov's cultist knife) is stopped only by an antidote (Tarkov: the xTG-12 or Augmentin)
add("ANTIDOTE", { name = "Antidote Injector", short = "ANTIDOTE", kind = "med", w = 1, h = 1, mass = 0.05, value = 38000, rarity = "rare", med = { antidote = true, uses = 1, time = 3 }, desc = "An auto-injector against poisoning. It stops the toxin of a cultist's knife and heals nothing else.", color = MED })
add("PAINKILLERS", { name = "Analgesic Tabs", short = "PAINKILL", kind = "med", w = 1, h = 1, mass = 0.05, value = 6000, med = { pain = true, uses = 4, time = 1.5, duration = 240 }, desc = "Suppresses pain for 4 minutes. 4 uses.", color = MED })
add("MEDKIT_S", { name = "Pocket Aid Kit", short = "AID 100", kind = "med", w = 1, h = 1, mass = 0.2, value = 5000, med = { hp = 100, time = 2.5 }, desc = "Restores health (100 points). Does not stop bleeding.", color = MED })
add("MEDKIT_M", { name = "Road Kit", short = "ROAD 220", kind = "med", w = 1, h = 2, mass = 0.4, value = 9000, med = { hp = 220, light = true, time = 3 }, desc = "Restores health (220 points), stops light bleeds.", color = MED })
add("MEDKIT_L", { name = "Field Medkit", short = "FIELD 400", kind = "med", w = 1, h = 2, mass = 0.6, value = 21000, rarity = "uncommon", med = { hp = 400, light = true, heavy = true, time = 3 }, desc = "Restores health (400 points), stops all bleeding.", color = MED })
add("MEDKIT_XL", { name = "Trauma Case", short = "TRAUMA", kind = "med", w = 2, h = 2, mass = 1.6, value = 75000, rarity = "rare", med = { hp = 1200, light = true, heavy = true, fracture = true, time = 4 }, desc = "Restores health (1200), stops bleeds, sets fractures.", color = MED })
add("SURGKIT", { name = "Field Surgical Kit", short = "SURGERY", kind = "med", w = 2, h = 1, mass = 0.8, value = 52000, rarity = "rare", med = { surgery = true, uses = 2, time = 12 }, desc = "Restores a destroyed limb (reduced max health). 2 uses.", color = MED })
-- Tarkov's stimulant injectors (gameplay-4b; their courses in Stims.luau): after Propital, SJ6, Zagustin and the
-- Adrenaline injector. EFT: 1x1, 0.05 kg, 2 s to inject, one use
add("STIM_REGEN", { name = "RG-5 Regenerative Injector", short = "RG-5", kind = "med", w = 1, h = 1, mass = 0.05, value = 36000, rarity = "rare", med = { stim = "STIM_REGEN", uses = 1, time = 2 }, desc = "A regenerative stimulant. Slowly restores health for 5 minutes and kills pain for about 4. Hand tremor and tunnel vision near the end.", color = MED })
add("STIM_STAMINA", { name = "SV-3 Combat Stimulant", short = "SV-3", kind = "med", w = 1, h = 1, mass = 0.05, value = 85000, rarity = "rare", med = { stim = "STIM_STAMINA", uses = 1, time = 2 }, desc = "A combat stimulant. More stamina and faster recovery for 4 minutes. Hand tremor and tunnel vision near the end.", color = MED })
add("STIM_HEMO", { name = "HM-2 Hemostatic Injector", short = "HM-2", kind = "med", w = 1, h = 1, mass = 0.05, value = 50000, rarity = "rare", med = { stim = "STIM_HEMO", uses = 1, time = 2 }, desc = "A hemostatic stimulant. Stops all bleeding, and no new bleed takes for 3 minutes. Hand tremor and heavy dehydration near the end.", color = MED })
add("STIM_ADREN", { name = "Adrenaline Injector", short = "ADRENALINE", kind = "med", w = 1, h = 1, mass = 0.05, value = 16000, rarity = "uncommon", med = { stim = "STIM_ADREN", uses = 1, time = 2 }, desc = "Kills pain for about a minute, gives a short burst of health and a minute of endurance, strength and recoil control. Hunger and thirst follow.", color = MED })
add("WATER", { name = "Water Bottle", short = "WATER", kind = "food", w = 1, h = 2, mass = 0.6, value = 8000, food = { water = 60, time = 4 }, desc = "Hydration +60.", color = c("#7FA8B8") })
add("STEW", { name = "Canned Stew", short = "STEW", kind = "food", w = 1, h = 1, mass = 0.4, value = 6500, food = { energy = 55, water = -5, time = 5 }, desc = "Energy +55.", color = c("#8F6A4A") })
add("HARDTACK", { name = "Hardtack", short = "HARDTACK", kind = "food", w = 1, h = 1, mass = 0.15, value = 3000, food = { energy = 30, water = -12, time = 3 }, desc = "Energy +30, dries you out.", color = c("#A48C64") })
add("VOLT_DRINK", { name = "Volt Energy Drink", short = "VOLT", kind = "food", w = 1, h = 2, mass = 0.4, value = 11000, rarity = "uncommon", food = { energy = 20, water = 35, stamina = 60, time = 3 }, desc = "Energy +20, hydration +35; stamina recovers 50 % faster for a minute.", color = c("#6E8F3C") })
-- M13 Meridian Mall: groceries
add("JUICE", { name = "Fruit Juice Carton", short = "JUICE", kind = "food", w = 1, h = 2, mass = 0.5, value = 7000, food = { water = 45, energy = 10, time = 3 }, desc = "Hydration +45, energy +10. Still sealed.", color = c("#C8962E") })
add("CHOC_BAR", { name = "Chocolate Bar", short = "CHOC", kind = "food", w = 1, h = 1, mass = 0.1, value = 5000, food = { energy = 25, water = -6, time = 2 }, desc = "Energy +25.", color = c("#6E3E2A") })

-- ── grenades (M11) ───────────────────────────────────────────────────────────
-- thrown with G from the rig or pockets (Tarkov: never from the backpack); the fuse starts on release
add("GREN_RK5", { name = "RK-5 Frag Grenade", short = "RK-5", kind = "grenade", w = 1, h = 1, mass = 0.31, value = 11000, nade = { type = "frag", fuse = 3.5, frags = 190, fragR = 17, fragDmg = { 24, 38 }, fragPen = { 10, 17 }, blastR = 4, blastDmg = 55 }, desc = "Offensive fragmentation grenade with a thin steel body. 3.5 s fuse.", color = c("#556048") })
-- map hazards: a propane cylinder's burst uses the grenade blast (a fireball close in, a few fragments)
add("PROPANE_TANK", { name = "Propane Cylinder", short = "PROPANE", kind = "hazard", w = 1, h = 2, mass = 20, value = 0, nade = { type = "frag", fuse = 0, frags = 40, fragR = 10, fragDmg = { 18, 30 }, fragPen = { 6, 12 }, blastR = 8, blastDmg = 170 }, desc = "A burst propane cylinder.", color = c("#C45C22") })
-- the AGL-30 stationary launcher's round (Stationary.luau): bursts where it lands, like a thrown frag; never an item you hold
add("AGL30_ROUND", { name = "30 mm Launcher Round", short = "AGL ROUND", kind = "hazard", w = 1, h = 1, mass = 0.35, value = 0, nade = { type = "frag", fuse = 0, frags = 150, fragR = 16, fragDmg = { 24, 38 }, fragPen = { 10, 16 }, blastR = 4.5, blastDmg = 85 }, desc = "A 30 mm grenade fired by the AGL-30.", color = c("#6A5C3A") })
add("GREN_F7", { name = "F-7 Defensive Grenade", short = "F-7", kind = "grenade", w = 1, h = 1, mass = 0.6, value = 16500, rarity = "uncommon", nade = { type = "frag", fuse = 3.8, frags = 330, fragR = 26, fragDmg = { 26, 40 }, fragPen = { 12, 22 }, blastR = 4.5, blastDmg = 65 }, desc = "Heavy cast-iron fragmentation grenade. Throw it from cover: the fragments carry further than you can throw.", color = c("#4A5640") })
add("GREN_STUN", { name = "ZS-3 Stun Charge", short = "STUN", kind = "grenade", w = 1, h = 1, mass = 0.35, value = 9000, nade = { type = "stun", fuse = 2.5, blindR = 26, deafR = 22 }, desc = "Flash-bang. Blinds anyone facing it and deafens everyone close by. 2.5 s fuse.", color = c("#4D5257") })
add("GREN_SMOKE", { name = "DS-2 Smoke Grenade", short = "SMOKE", kind = "grenade", w = 1, h = 1, mass = 0.5, value = 7000, nade = { type = "smoke", fuse = 2, smokeR = 15, smokeT = 55 }, desc = "White smoke screen for about a minute. Blocks sight for people and AI alike.", color = c("#6C7469") })
-- signal flares (Tarkov's reactive signal cartridges, 1 x 2, 0.19 kg, gone after one shot): the red one, fired up under
-- the open sky on a map with airdrops, calls a plane to that spot (Services/Airdrop.luau); the green one, fired up inside
-- a flare exit's signal area, opens that exit (Services/Extract.luau, kind "flare")
add("FLARE_RED", { name = "Red Signal Flare", short = "RED FLARE", kind = "flare", w = 1, h = 2, mass = 0.19, value = 38000, rarity = "rare", flare = { color = "red", call = true }, desc = "A hand-held signal cartridge that fires a red star straight up. Fired under the open sky in a raid with airdrops, it calls a supply plane to drop a crate near you a couple of minutes later. One plane at a time: a second flare too soon gets no answer.", color = c("#A8322A") })
add("FLARE_GREEN", { name = "Green Signal Flare", short = "GREEN FLARE", kind = "flare", w = 1, h = 2, mass = 0.19, value = 12000, rarity = "uncommon", flare = { color = "green", exit = true }, desc = "A hand-held signal cartridge that fires a green star straight up. Fired under the open sky inside an exit's signal area, it opens that exit for the rest of the raid (NORTH LINE on Border Yard, RIVER PATH on Meridian Mall). Anywhere else it is only a light in the sky.", color = c("#3E8A3A") })

-- ── weapon maintenance (M11) ─────────────────────────────────────────────────
add("WEAPON_KIT", { name = "Gunsmith Repair Kit", short = "GUN KIT", kind = "repair", w = 2, h = 1, mass = 1.1, value = 34000, rarity = "uncommon", repair = { points = 150 }, desc = "Springs, pins and a cleaning set. Restores weapon durability out of raid (150 points), with less wear than a trader repair.", color = c("#5B5E52") })
add("MULTITOOL", { name = "Multitool", short = "MTOOL", kind = "loot", w = 2, h = 1, mass = 0.25, value = 18000, rarity = "uncommon", desc = "Pliers, drivers and a file in one. Carrying it lets you change vital weapon parts (barrels, gas blocks, handguards, pistol grips, receivers) during a raid.", color = c("#8A3E32") })

-- ── keys, quest items ─────────────────────────────────────────────────────────
add("KEY_OFFICE", { name = "Harbor Office Key", short = "OFFICE KEY", kind = "key", w = 1, h = 1, mass = 0.02, value = 22000, rarity = "uncommon", key = { door = "office", uses = 25 }, desc = "Opens the harbor office.", color = c("#8C7A4E") })
add("RUSTED_KEYCARD", { name = "Vault Keycard", short = "VAULT", kind = "key", w = 1, h = 1, mass = 0.02, value = 95000, rarity = "rare", key = { door = "vault", uses = 10, card = true }, desc = "Quay authority keycard. Opens the depot vault behind the harbor office. 10 uses.", color = c("#8A6252") })
add("KEY_PINE_BUNKER", { name = "Shelter P-7 Key", short = "P-7 KEY", kind = "key", w = 1, h = 1, mass = 0.02, value = 38000, rarity = "uncommon", key = { door = "pine_shelter", uses = 20 }, desc = "Pinewatch: the old shelter under the north ridge. Opens the armoury and the emergency hatch out of the woods.", color = c("#6E6A5A") })
add("KEY_SMELT_OFFICE", { name = "Smelter Office Key", short = "SMELT KEY", kind = "key", w = 1, h = 1, mass = 0.02, value = 26000, rarity = "uncommon", key = { door = "smelter_office", uses = 25 }, desc = "Smelter office block: opens the manager's office upstairs and the watchman's door in the west fence.", color = c("#7A6E58") })
-- M13 Border Yard keys
add("KEY_BY_314", { name = "Block A Room 314 Key", short = "ROOM 314", kind = "key", w = 1, h = 1, mass = 0.02, value = 34000, rarity = "uncommon", key = { door = "by_314", uses = 20 }, desc = "Brass key on a plastic fob: Border Yard dormitory, block A, room 314.", color = c("#8C7A4E") })
add("KEY_BY_RECORDS", { name = "Customs Records Room Key", short = "RECORDS", kind = "key", w = 1, h = 1, mass = 0.02, value = 28000, rarity = "uncommon", key = { door = "by_records", uses = 25 }, desc = "Opens the records room in the Border Yard customs office.", color = c("#7A6E50") })
add("KEY_BY_BOILER", { name = "Boiler House Key", short = "BOILER", kind = "key", w = 1, h = 1, mass = 0.02, value = 41000, rarity = "rare", key = { door = "by_boiler", uses = 15 }, desc = "Heavy key to the Border Yard boiler house. The cellar runs under the fence.", color = c("#6F5F45") })
-- Border Yard on the Customs layout (2026-11-01): keys for the industrial side (Maps/Border/Works.luau)
add("KEY_BY_K11", { name = "Bunker K-11 Key", short = "K-11", kind = "key", w = 1, h = 1, mass = 0.02, value = 52000, rarity = "rare", key = { door = "by_k11", uses = 10 }, desc = "Stamped steel key to the blast door of bunker K-11 under the west yard.", color = c("#5B6066") })
add("KEY_BY_STORE", { name = "Store 7 Office Key", short = "STORE 7", kind = "key", w = 1, h = 1, mass = 0.02, value = 24000, rarity = "uncommon", key = { door = "by_store7", uses = 25 }, desc = "Opens the locked office in Store 7.", color = c("#7A6A4A") })
add("KEY_BY_RED", { name = "Red Stores Cage Key", short = "RED CAGE", kind = "key", w = 1, h = 1, mass = 0.02, value = 36000, rarity = "uncommon", key = { door = "by_red", uses = 20 }, desc = "Opens the wire cage of the seized-goods store at the Red Stores.", color = c("#8C3A30") })
add("KEY_BY_BASTION", { name = "Bastion Strongroom Key", short = "BASTION", kind = "key", w = 1, h = 1, mass = 0.02, value = 47000, rarity = "rare", key = { door = "by_bastion", uses = 15 }, desc = "Opens the strongroom of the old fortified block in the north yard.", color = c("#4E5248") })
add("KEY_BY_MOTOR", { name = "Motor Shop Office Key", short = "MOTOR", kind = "key", w = 1, h = 1, mass = 0.02, value = 21000, rarity = "uncommon", key = { door = "by_motor", uses = 25 }, desc = "Opens the foreman's office in the motor shop.", color = c("#6A5A40") })
-- Border Yard on the Customs layout (2026-11-01): keys for the living side (Maps/Border/Living.luau)
add("KEY_BY_A103", { name = "Block A Room 103 Key", short = "A 103", kind = "key", w = 1, h = 1, mass = 0.02, value = 18000, rarity = "uncommon", key = { door = "by_a103", uses = 25 }, desc = "Brass key on a plastic fob: Border Yard dormitory, block A, room 103.", color = c("#7E8A6B") })
add("KEY_BY_A125", { name = "Block A Room 125 Key", short = "A 125", kind = "key", w = 1, h = 1, mass = 0.02, value = 21000, rarity = "uncommon", key = { door = "by_a125", uses = 25 }, desc = "Brass key on a plastic fob: Border Yard dormitory, block A, room 125.", color = c("#7A8466") })
add("KEY_BY_A128", { name = "Block A Room 128 Key", short = "A 128", kind = "key", w = 1, h = 1, mass = 0.02, value = 24000, rarity = "uncommon", key = { door = "by_a128", uses = 25 }, desc = "Brass key on a plastic fob: Border Yard dormitory, block A, room 128.", color = c("#6E7C8A") })
add("KEY_BY_A201", { name = "Block A Room 201 Key", short = "A 201", kind = "key", w = 1, h = 1, mass = 0.02, value = 26000, rarity = "uncommon", key = { door = "by_a201", uses = 25 }, desc = "Brass key on a plastic fob: Border Yard dormitory, block A, room 201.", color = c("#8A7E5E") })
add("KEY_BY_A212", { name = "Block A Room 212 Key", short = "A 212", kind = "key", w = 1, h = 1, mass = 0.02, value = 22000, rarity = "uncommon", key = { door = "by_a212", uses = 25 }, desc = "Brass key on a plastic fob: Border Yard dormitory, block A, room 212.", color = c("#7B8A6E") })
add("KEY_BY_A225", { name = "Block A Room 225 Key", short = "A 225", kind = "key", w = 1, h = 1, mass = 0.02, value = 27000, rarity = "uncommon", key = { door = "by_a225", uses = 25 }, desc = "Brass key on a plastic fob: Border Yard dormitory, block A, room 225.", color = c("#8A6E5E") })
add("KEY_BY_A228", { name = "Block A Room 228 Key", short = "A 228", kind = "key", w = 1, h = 1, mass = 0.02, value = 29000, rarity = "uncommon", key = { door = "by_a228", uses = 25 }, desc = "Brass key on a plastic fob: Border Yard dormitory, block A, room 228.", color = c("#6E8A7E") })
add("KEY_BY_A229", { name = "Block A Room 229 Key", short = "A 229", kind = "key", w = 1, h = 1, mass = 0.02, value = 31000, rarity = "uncommon", key = { door = "by_a229", uses = 20 }, desc = "Brass key on a plastic fob: Border Yard dormitory, block A, room 229.", color = c("#7E6E8A") })
add("KEY_BY_A303", { name = "Block A Room 303 Key", short = "A 303", kind = "key", w = 1, h = 1, mass = 0.02, value = 28000, rarity = "uncommon", key = { door = "by_a303", uses = 25 }, desc = "Brass key on a plastic fob: Border Yard dormitory, block A, room 303.", color = c("#8A8A5E") })
add("KEY_BY_A310", { name = "Block A Room 310 Key", short = "A 310", kind = "key", w = 1, h = 1, mass = 0.02, value = 33000, rarity = "uncommon", key = { door = "by_a310", uses = 20 }, desc = "Brass key on a plastic fob: Border Yard dormitory, block A, room 310.", color = c("#5E7E8A") })
add("KEY_BY_A317", { name = "Block A Room 317 Key", short = "A 317", kind = "key", w = 1, h = 1, mass = 0.02, value = 30000, rarity = "uncommon", key = { door = "by_a317", uses = 20 }, desc = "Brass key on a plastic fob: Border Yard dormitory, block A, room 317.", color = c("#8A5E6E") })
add("KEY_BY_A325", { name = "Block A Room 325 Key", short = "A 325", kind = "key", w = 1, h = 1, mass = 0.02, value = 35000, rarity = "uncommon", key = { door = "by_a325", uses = 20 }, desc = "Brass key on a plastic fob: Border Yard dormitory, block A, room 325.", color = c("#6E8A5E") })
add("KEY_BY_B103", { name = "Block B Room 103 Key", short = "B 103", kind = "key", w = 1, h = 1, mass = 0.02, value = 17000, rarity = "uncommon", key = { door = "by_b103", uses = 25 }, desc = "Steel key on a rope loop: Border Yard dormitory, block B, room 103.", color = c("#7A8A72") })
add("KEY_BY_B111", { name = "Block B Room 111 Key", short = "B 111", kind = "key", w = 1, h = 1, mass = 0.02, value = 20000, rarity = "uncommon", key = { door = "by_b111", uses = 25 }, desc = "Steel key on a rope loop: Border Yard dormitory, block B, room 111.", color = c("#8A7A6A") })
add("KEY_BY_B116", { name = "Block B Room 116 Key", short = "B 116", kind = "key", w = 1, h = 1, mass = 0.02, value = 23000, rarity = "uncommon", key = { door = "by_b116", uses = 25 }, desc = "Steel key on a rope loop: Border Yard dormitory, block B, room 116.", color = c("#6A7A8A") })
add("KEY_BY_B124", { name = "Block B Room 124 Key", short = "B 124", kind = "key", w = 1, h = 1, mass = 0.02, value = 25000, rarity = "uncommon", key = { door = "by_b124", uses = 25 }, desc = "Steel key on a rope loop: Border Yard dormitory, block B, room 124.", color = c("#8A6A7A") })
add("KEY_BY_B223", { name = "Block B Room 223 Key", short = "B 223", kind = "key", w = 1, h = 1, mass = 0.02, value = 30000, rarity = "uncommon", key = { door = "by_b223", uses = 20 }, desc = "Steel key on a rope loop: Border Yard dormitory, block B, room 223.", color = c("#7A6A8A") })
add("KEY_BY_FUELSTORE", { name = "Fuel Stop Storeroom Key", short = "FUEL STORE", kind = "key", w = 1, h = 1, mass = 0.02, value = 24000, rarity = "uncommon", key = { door = "by_fuelstore", uses = 25 }, desc = "Opens the storeroom behind the Fuel Stop shop.", color = c("#8A7A3E") })
add("KEY_BY_FUELTILL", { name = "Fuel Stop Till Office Key", short = "FUEL TILL", kind = "key", w = 1, h = 1, mass = 0.02, value = 36000, rarity = "uncommon", key = { door = "by_fueltill", uses = 20 }, desc = "Small key for the till office and safe closet at the Fuel Stop.", color = c("#7A6A3E") })
add("KEY_BY_WATCHROOM", { name = "Watchhouse Night Room Key", short = "NIGHT ROOM", kind = "key", w = 1, h = 1, mass = 0.02, value = 43000, rarity = "rare", key = { door = "by_watchroom", uses = 15 }, desc = "Opens the night room at the back of the watchhouse. The bulbs in there never go off.", color = c("#5E4E6A") })
add("KEY_BY_WATCHSTORE", { name = "Watchhouse Store Key", short = "WATCH STORE", kind = "key", w = 1, h = 1, mass = 0.02, value = 39000, rarity = "uncommon", key = { door = "by_watchstore", uses = 20 }, desc = "Opens the supply room on the watchhouse ground floor.", color = c("#6A5E4E") })
add("KEY_BY_ARMYHUT", { name = "Army Post Hut Key", short = "ARMY HUT", kind = "key", w = 1, h = 1, mass = 0.02, value = 36000, rarity = "uncommon", key = { door = "by_armyhut", uses = 20 }, desc = "Opens the guardroom of the army post hut.", color = c("#5E6648") })
add("KEY_BY_HUTSKIOSK", { name = "Huts Kiosk B Key", short = "HUTS KIOSK", kind = "key", w = 1, h = 1, mass = 0.02, value = 17000, rarity = "uncommon", key = { door = "by_hutskiosk", uses = 30 }, desc = "Opens the back door of the second kiosk at the huts.", color = c("#7A7E5E") })
add("KEY_BY_TRAILERA", { name = "Trailer A Key", short = "TRAILER A", kind = "key", w = 1, h = 1, mass = 0.02, value = 28000, rarity = "uncommon", key = { door = "by_trailera", uses = 25 }, desc = "Padlock key for trailer A on the trailer lot.", color = c("#7E6A4E") })
add("KEY_BY_TRAILERB", { name = "Trailer B Key", short = "TRAILER B", kind = "key", w = 1, h = 1, mass = 0.02, value = 31000, rarity = "uncommon", key = { door = "by_trailerb", uses = 20 }, desc = "Padlock key for trailer B on the trailer lot.", color = c("#6E7E4E") })
add("KEY_BY_SHACK4", { name = "Store 4 Shack Key", short = "SHACK 4", kind = "key", w = 1, h = 1, mass = 0.02, value = 19000, rarity = "uncommon", key = { door = "by_shack4", uses = 25 }, desc = "Opens the tin shack by the store 4 yard.", color = c("#6A6E5A") })
add("KEY_BY_ROADSHACK", { name = "Roadside Shack Key", short = "ROAD SHACK", kind = "key", w = 1, h = 1, mass = 0.02, value = 18000, rarity = "uncommon", key = { door = "by_roadshack", uses = 25 }, desc = "Opens the east roadside shack.", color = c("#706A56") })
add("KEY_BY_SQUAT", { name = "Squat Back Door Key", short = "THE SQUAT", kind = "key", w = 1, h = 1, mass = 0.02, value = 34000, rarity = "uncommon", key = { door = "by_squat", uses = 20 }, desc = "Rusty key to the back door of the squat. Somebody scratched an X on the bow.", color = c("#7A4E42") })
add("KEY_BY_PUMPS", { name = "Old Pumps Storeroom Key", short = "OLD PUMPS", kind = "key", w = 1, h = 1, mass = 0.02, value = 22000, rarity = "uncommon", key = { door = "by_pumps", uses = 25 }, desc = "Opens the back room of the old gas station.", color = c("#7E6E44") })
add("KEY_DORM_104", { name = "Dorm Room 104 Key", short = "DORM 104", kind = "key", w = 1, h = 1, mass = 0.02, value = 16000, rarity = "uncommon", key = { door = "dorm104", uses = 30 }, desc = "Crew dormitory, ground floor, room 104.", color = c("#7E8A6B") })
add("KEY_DORM_203", { name = "Dorm Room 203 Key", short = "DORM 203", kind = "key", w = 1, h = 1, mass = 0.02, value = 34000, rarity = "uncommon", key = { door = "dorm203", uses = 20 }, desc = "Crew dormitory, upper floor, room 203. The foreman's quarters.", color = c("#6B7E8A") })
-- M13 Meridian Mall keys
add("KEY_MALL_STAFF", { name = "Meridian Staff Key", short = "STAFF KEY", kind = "key", w = 1, h = 1, mass = 0.02, value = 28000, rarity = "uncommon", key = { door = "mall_staff", uses = 20 }, desc = "Meridian Mall, upper floor: the staff door of the food-court kitchen.", color = c("#6E7A8A") })
add("KEY_MALL_SECURITY", { name = "Mall Security Key", short = "SECURITY", kind = "key", w = 1, h = 1, mass = 0.02, value = 64000, rarity = "rare", key = { door = "mall_security", uses = 15 }, desc = "Meridian Mall, first floor: the security office. Its terminal switches off the IRONSIGHT shop alarm.", color = c("#3E4E6E") })
add("KEY_VOLTA_STORE", { name = "VOLTA Store Room Key", short = "VOLTA KEY", kind = "key", w = 1, h = 1, mass = 0.02, value = 82000, rarity = "rare", key = { door = "volta_store", uses = 12 }, desc = "Meridian Mall: the stock room behind the VOLTA electronics store.", color = c("#C8B23A") })
add("KEY_MEDIQ", { name = "MEDIQ Dispensary Key", short = "MEDIQ KEY", kind = "key", w = 1, h = 1, mass = 0.02, value = 36000, rarity = "uncommon", key = { door = "mediq", uses = 40 }, desc = "Meridian Mall: the locked dispensary behind the MEDIQ pharmacy counter.", color = c("#4E8A6E") })
add("CARD_MALL_VAULT", { name = "Shelter Keycard", short = "SHELTER CARD", kind = "key", w = 1, h = 1, mass = 0.02, value = 140000, rarity = "rare", key = { door = "mm_shelter", uses = 10, card = true }, desc = "Meridian Mall: the card for the sealed shelter door in car park C. The reader is dead until the mall power is on. 10 uses.", color = c("#8C3E5A") })
-- Meridian Mall on Interchange's layout (2026-11-01): the ten new keys (doors listed in docs/maps/MERIDIAN_MALL.md, Part 3)
add("KEY_MM_IRON_FRONT", { name = "IRONSIGHT Front Door Key", short = "IRON FRONT", kind = "key", w = 1, h = 1, mass = 0.02, value = 96000, rarity = "rare", key = { door = "mm_iron_front", uses = 40 }, desc = "Meridian Mall, first floor: the steel front door of the IRONSIGHT gun shop. The lock is electric (dead without power) and the shop alarm sounds a few seconds after the door opens.", color = c("#8E3B2F") })
add("KEY_MM_IRON_GRATE", { name = "IRONSIGHT Back Grate Key", short = "IRON GRATE", kind = "key", w = 1, h = 1, mass = 0.02, value = 82000, rarity = "rare", key = { door = "mm_iron_grate", uses = 40 }, desc = "Meridian Mall, first floor: the inner grate of the IRONSIGHT gun shop, in front of the weapon room. Electric lock; the front door comes first.", color = c("#7C3A30") })
add("KEY_MM_RESCUE", { name = "RESCUE POINT Key", short = "RESCUE", kind = "key", w = 1, h = 1, mass = 0.02, value = 41000, rarity = "uncommon", key = { door = "mm_rescue", uses = 40 }, desc = "Meridian Mall, first floor: the three service doors of the RESCUE POINT store (north, east and west). Every opening costs a use.", color = c("#B5532E") })
add("KEY_MM_NESTA_REG", { name = "NESTA Till Office Key", short = "NESTA TILLS", kind = "key", w = 1, h = 1, mass = 0.02, value = 22000, rarity = "uncommon", key = { door = "mm_nesta_reg", uses = 40 }, desc = "Meridian Mall: the cash office behind the NESTA tills, where the registers are emptied.", color = c("#3E8A8A") })
add("KEY_MM_KASSA_REG", { name = "KASSA Till Office Key", short = "KASSA TILLS", kind = "key", w = 1, h = 1, mass = 0.02, value = 24000, rarity = "uncommon", key = { door = "mm_kassa_reg", uses = 40 }, desc = "Meridian Mall: the cash office behind the KASSA tills, where the registers are emptied.", color = c("#8A3E4E") })
add("KEY_MM_BOLT_REG", { name = "BOLTWORKS Till Office Key", short = "BOLT TILLS", kind = "key", w = 1, h = 1, mass = 0.02, value = 21000, rarity = "uncommon", key = { door = "mm_bolt_reg", uses = 40 }, desc = "Meridian Mall: the cash office behind the BOLTWORKS tills, where the registers are emptied.", color = c("#C27A2E") })
add("KEY_MM_BOLT_OFFICE", { name = "BOLTWORKS Office Key", short = "BOLT OFFICE", kind = "key", w = 1, h = 1, mass = 0.02, value = 38000, rarity = "uncommon", key = { door = "mm_bolt_office", uses = 40 }, desc = "Meridian Mall: the administration office in the west wing of BOLTWORKS.", color = c("#B8742A") })
add("KEY_MM_BOLT_GOODS", { name = "BOLTWORKS Goods-In Key", short = "GOODS-IN", kind = "key", w = 1, h = 1, mass = 0.02, value = 33000, rarity = "uncommon", key = { door = "mm_bolt_goods", uses = 40 }, desc = "Meridian Mall: the goods-in office and stock room of BOLTWORKS, off the west wing.", color = c("#A8682A") })
add("KEY_MM_SUBSTATION", { name = "SUBSTATION Utility Room Key", short = "UTILITY", kind = "key", w = 1, h = 1, mass = 0.02, value = 58000, rarity = "rare", key = { door = "mm_substation", uses = 40 }, desc = "The utility room of THE SUBSTATION, beside the switch hall: tool lockers, spare parts and a few things nobody signed back.", color = c("#6B7A5E") })
add("KEY_MM_UNIT14", { name = "UNIT 14 Keycard", short = "UNIT 14", kind = "key", w = 1, h = 1, mass = 0.02, value = 175000, rarity = "rare", key = { door = "mm_unit14", uses = 10, card = true }, desc = "Meridian Mall, car park A: the keycard for the container room UNIT 14. The reader needs the mall power. 10 uses.", color = c("#4E5E8A") })
add("SEALED_DRIVE", { name = "Sealed Drive", short = "DRIVE", kind = "quest", w = 1, h = 1, mass = 0.1, value = 120000, rarity = "rare", desc = "Evacuation office data drive in a sealed sleeve.", color = c("#C07946") })
add("LEDGER", { name = "Harbormaster's Ledger", short = "LEDGER", kind = "quest", w = 1, h = 1, mass = 0.3, value = 450000, rarity = "legendary", desc = "Leather ledger of every shipment that left Quay 7.", color = c("#7A4A2E") })
-- decision economy-6a: quest items a task sends you to find (EFT: they spawn only for players with the task, go to the
-- quest-item pouch, cannot be sold or used, and are lost on a failed extraction; EFT wiki Quests). They never lie in the
-- stash here: Quests keeps them in the profile's quest-item pouch (prof.qitems) until they are handed over.
local function questItem(id: string, name: string, short: string, value: number, desc: string, col: string)
	add(id, { name = name, short = short, kind = "quest", w = 1, h = 1, mass = 0.2, value = value, rarity = "rare", desc = desc, color = c(col) })
end
questItem("QI_WATCHLOG", "Watch Room Logbook", "WATCH LOG", 60000, "The watchhouse's log of every truck waved through the old checkpoint.", "#5E5A4A")
questItem("QI_NOTEBOOK", "Foreman's Notebook", "NOTEBOOK", 90000, "A grease-stained notebook: buyers, prices and dates in the Foreman's hand.", "#4E3E2E")
questItem("QI_LETTERS", "Bundle of Letters", "LETTERS", 30000, "Letters tied with string, never sent, never read.", "#C8BFA0")
questItem("QI_SAMPLES", "Sealed Sample Case", "SAMPLES", 80000, "A small cold case of pharmacy samples, its seal unbroken.", "#B8C8D0")
questItem("QI_REAGENT", "Reagent Case", "REAGENTS", 90000, "A padded case of lab reagents from the Smelter.", "#6A8A7A")
questItem("QI_MANIFEST", "Transit Manifest", "MANIFEST", 40000, "Customs transit manifest with the Store 17 foreman's signatures.", "#A89A7A")
questItem("QI_BOATLOG", "Boat Logbook", "BOAT LOG", 50000, "The smugglers' boat's logbook: every run, every crossing.", "#4A5A6A")
questItem("QI_PARCEL", "Seized Parcel", "PARCEL", 70000, "A taped parcel with a customs seizure tag. Somebody wants it unopened.", "#8A7A5A")
questItem("QI_SEAL", "Customs Seal Press", "SEAL", 80000, "The quay's customs seal press. Whoever holds it clears any crate.", "#7A6A4A")
questItem("QI_TAPE", "Security Tape", "TAPE", 60000, "A recorder tape from the mall's security room, labelled with the day it fell.", "#2E2E32")
questItem("QI_REGISTER", "Armoury Register", "REGISTER", 60000, "The army post's register of every rifle signed in and out.", "#5A6A4A")
questItem("QI_UNIT14", "Unit 14 Inventory Sheet", "UNIT 14 LIST", 70000, "The list taped inside UNIT 14: what went into the crates.", "#D0D0C0")
questItem("QI_FURNACE", "Furnace Log", "FURNACE LOG", 90000, "The Smelter manager's log of every furnace run.", "#6E4A3A")
questItem("QI_PRICELIST", "Price Ledger", "PRICES", 50000, "BOLTWORKS' price ledger, every line marked up.", "#C27A2E")
-- what tasks have you plant (EFT's MS2000 marker, WI-FI camera and signal jammer roles). Kind "loot" so traders sell and
-- buy them (TraderData's task-locked offers) and the flea lists them
add("MARKER", { name = "Spot Marker", short = "MARKER", kind = "loot", w = 1, h = 1, mass = 0.2, value = 9000, desc = "A small radio marker. Set it on something and the people who sent you can find it.", color = c("#C24A35") })
add("CAMERA", { name = "Trail Camera", short = "CAMERA", kind = "loot", w = 1, h = 1, mass = 0.3, value = 14000, rarity = "uncommon", desc = "Battery wildlife camera with a radio link. Strap it somewhere with a view.", color = c("#4E5A3E") })
add("BEACON", { name = "Signal Beacon", short = "BEACON", kind = "loot", w = 1, h = 1, mass = 0.4, value = 22000, rarity = "uncommon", desc = "A radio relay beacon. Planted high, it listens to everything nearby.", color = c("#3E5A6E") })

-- ── barter / valuables ────────────────────────────────────────────────────────
local function loot(id: string, name: string, short: string, w: number, h: number, mass: number, value: number, rarity: string, desc: string, col: string)
	add(id, { name = name, short = short, kind = "loot", w = w, h = h, mass = mass, value = value, rarity = rarity, desc = desc, color = c(col) })
end
loot("BOLTS", "Bolts", "BOLTS", 1, 1, 0.3, 4000, "common", "A bag of assorted bolts.", "#7B7C78")
loot("DUCT_TAPE", "Duct Tape", "TAPE", 1, 1, 0.2, 5500, "common", "Fixes everything.", "#8E9091")
loot("WIRES", "Wire Bundle", "WIRES", 1, 1, 0.25, 6000, "common", "Insulated copper wiring.", "#9C6B42")
loot("CIGARETTES", "Cigarettes", "CIGS", 1, 1, 0.05, 3000, "common", "Crushed pack of cigarettes.", "#B0A68A")
loot("MATCHES", "Matches", "MATCH", 1, 1, 0.02, 2500, "common", "Waterproof matches.", "#9E5E3A")
loot("SPARK_PLUG", "Spark Plug", "PLUG", 1, 1, 0.1, 4500, "common", "Generator spark plug.", "#8C8F8A")
loot("SIGNAL_COIL", "Signal Coil", "COIL", 1, 1, 0.5, 12000, "common", "Copper induction coil pulled from a harbor relay.", "#9C6B42")
loot("CERAMIC_FUSE", "Ceramic Fuse", "FUSE", 1, 1, 0.2, 9000, "common", "High-voltage ceramic fuse. Dock cranes still need them.", "#B9B3A2")
loot("CAPACITOR", "Power Capacitor", "CAP", 1, 1, 0.4, 18000, "uncommon", "Industrial capacitor.", "#5F7A86")
loot("CRACKED_LENS", "Cracked Lens", "LENS", 1, 1, 0.4, 22000, "uncommon", "Coated optical lens. Chipped, still valuable.", "#6F8A8C")
loot("BATTERY", "Lead Battery", "BATT", 2, 1, 4.5, 26000, "uncommon", "Heavy deep-cycle battery.", "#4D5356")
loot("LOGIC_BOARD", "Logic Board", "BOARD", 1, 1, 0.3, 30000, "uncommon", "Control board from a crane cab.", "#3F6B4A")
loot("FUEL_CAN", "Fuel Canister", "FUEL", 2, 2, 5.5, 34000, "uncommon", "Generator fuel, half full.", "#8A3A2A")
loot("MED_TOOLS", "Surgical Tools", "TOOLS", 1, 2, 0.6, 28000, "uncommon", "Sterile instrument roll.", "#A9B3B3")
loot("OLD_COIN", "Old Coin", "COIN", 1, 1, 0.02, 20000, "uncommon", "Silver coin from a captain's cabin.", "#B8B8A8")
loot("DECK_TRANSCEIVER", "Deck Transceiver", "XCVR", 2, 2, 1.8, 45000, "uncommon", "Ship-to-shore radio set. Heavy but in demand.", "#4B5652")
loot("GOLD_CHAIN", "Gold Chain", "CHAIN", 1, 1, 0.05, 62000, "rare", "Heavy gold chain.", "#C9A13C")
loot("RITUAL_AMULET", "Ritual Amulet", "AMULET", 1, 1, 0.1, 120000, "epic", "A tarnished amulet on a leather cord, carried by the cult's priest.", "#7A6A3E")
loot("CAPT_WATCH", "Captain's Watch", "WATCH", 1, 1, 0.1, 85000, "rare", "Swiss-style dive watch.", "#B39A5A")
loot("FLASH_MODULE", "Flash Module", "FLASH", 1, 1, 0.05, 70000, "rare", "Encrypted flash module.", "#4F6E8C")
loot("INTEL_FOLDER", "Intel Folder", "INTEL", 1, 1, 0.2, 90000, "rare", "Stamped folder of shipping manifests.", "#9C7A4A")
loot("MIL_CIRCUIT", "Military Circuit", "MIL CIRC", 2, 1, 0.4, 160000, "epic", "Hardened military control circuit.", "#2F5A3A")
loot("COLD_WALLET", "Cold Wallet", "WALLET", 1, 1, 0.05, 220000, "epic", "Hardware wallet. Someone will pay for it.", "#C07946")
loot("BRASS_LION", "Brass Lion", "LION", 2, 2, 3.2, 280000, "epic", "Brass lion statuette from the harbormaster's office.", "#B08A3C")
-- M13 Meridian Mall: electronics and household goods
loot("GPU_CARD", "Graphics Card", "GPU", 2, 1, 0.9, 190000, "epic", "A boxed high-end graphics card from the VOLTA stock room. Someone always wants one.", "#3A4A5A")
loot("HDD", "Hard Drive", "HDD", 1, 1, 0.4, 24000, "uncommon", "A 3.5-inch hard drive, data unknown.", "#5A6066")
loot("RAM_STICK", "Memory Module", "RAM", 1, 1, 0.05, 15000, "uncommon", "A desktop memory stick in a blister pack.", "#3A6E4A")
loot("PHONE", "Smartphone", "PHONE", 1, 1, 0.2, 32000, "uncommon", "A display-model phone with a cracked screen.", "#2E3238")
loot("POWER_BANK", "Power Bank", "PWR BANK", 1, 1, 0.3, 9000, "common", "Portable battery, half charged.", "#4A5E7A")
loot("LIGHTBULB", "Light Bulb", "BULB", 1, 1, 0.1, 3500, "common", "An incandescent bulb, still in its sleeve.", "#D8D2A8")
loot("TOOTHPASTE", "Toothpaste", "PASTE", 1, 1, 0.15, 4000, "common", "Unopened tube of toothpaste.", "#5A8EB8")
loot("SOAP", "Soap Bar", "SOAP", 1, 1, 0.1, 3000, "common", "Wrapped bar of soap.", "#C8B8D8")
loot("BLEACH", "Bleach", "BLEACH", 1, 2, 1.0, 8000, "common", "A bottle of household bleach.", "#D8DCE0")
-- decision economy-7b (the hideout's economy core): three barter goods EFT's hideout leans on that had no counterpart here.
-- GUNPOWDER stands for EFT's gunpowder "Kite", "Hawk" and "Eagle" (the workbench's ammunition and grenade crafts),
-- FABRIC for its aramid, Cordura, ripstop and fleece (the lavatory's gear crafts), MOONSHINE for its bottle of moonshine
-- (the scav case's dearest run and its construction). Sizes after EFT's (gunpowder and moonshine 1x2); values ours.
loot("GUNPOWDER", "Powder Tin", "POWDER", 1, 2, 0.6, 15000, "uncommon", "A sealed tin of smokeless rifle powder. Reloaders and grenade makers pay well for it.", "#5E6650")
loot("FABRIC", "Fabric Roll", "FABRIC", 1, 1, 0.3, 9000, "common", "A tight roll of heavy-duty technical fabric: aramid weave and ripstop offcuts. Good for mending vests and packs.", "#5C6B4E")
loot("MOONSHINE", "Moonshine", "MOONSHINE", 1, 2, 1.1, 140000, "rare", "A corked bottle of home-distilled spirit, strong enough to strip paint. Scavs will do a lot for one.", "#B9A97A")
add("DOGTAG", { name = "Dog Tag", short = "TAG", kind = "loot", w = 1, h = 1, mass = 0.02, value = 12000, rarity = "uncommon", desc = "An operator's identification tag. Worth more the more experienced its owner was.", color = c("#A7A9A0") })

-- ── M14 weapon parts (WeaponParts.luau): every part is an item of kind "mod" with its part record ──────────
local WP = require(script.Parent.WeaponParts)
local PART_COLOR = {
	barrel = "3A3F42", gasblock = "3C4143", handguard = "3E4346", grip = "34383A", receiver = "3B4042", stock = "3A3E40",
	charge = "3B3F41", tube = "3A3F42", muzzle = "33383A", sight = "2F3436", ironfront = "3A3E40", ironrear = "3A3E40",
	mount = "393E40", foregrip = "36393B", tactical = "34383A", nvg = "2F3A34",
}
for id, p in WP.parts do
	add(id, {
		name = p.name, short = p.short, kind = "mod", w = p.w, h = p.h, mass = p.mass, value = p.value, rarity = p.rarity,
		desc = p.desc, color = c("#" .. (PART_COLOR[p.cat] or "3A3E40")), part = p,
	})
	-- goggles are gear components, not weapon parts (they go on a helmet's mount)
	if p.cat == "nvg" then
		defs[id].kind = "nvg"
	end
end
add("NV_STRAP", { name = "Goggle Head Strap", short = "STRAP", kind = "headwear", w = 2, h = 1, mass = 0.15, value = 9000,
	desc = "Elastic head harness with a night-vision mount, for when there is no helmet.", color = c("#2E302B") })

local Items = { defs = defs }

-- equipment slots and the kinds each accepts
Items.SLOTS = {
	head = { helmet = true, headwear = true }, ears = { headset = true }, face = { facecover = true }, eyes = { eyewear = true },
	armor = { armor = true }, rig = { rig = true }, back = { backpack = true }, secure = { secure = true },
	primary = { weapon = true }, secondary = { weapon = true }, holster = { pistol = true }, melee = { melee = true },
}
Items.SLOT_ORDER = { "head", "ears", "face", "eyes", "armor", "rig", "back", "secure", "primary", "secondary", "holster", "melee" }
Items.SLOT_NAMES = {
	head = "HEADWEAR", ears = "EARPIECE", face = "FACE COVER", eyes = "EYEWEAR", armor = "BODY ARMOR", rig = "TACTICAL RIG", back = "BACKPACK", secure = "SECURE CONTAINER",
	primary = "ON SLING", secondary = "ON BACK", holster = "HOLSTER", melee = "SCABBARD",
}
Items.RARITY = { common = 0, uncommon = 1, rare = 2, epic = 3, legendary = 4 }
-- secure containers refuse bulky gear (Tarkov-like restriction). EFT players keep weapon parts and scopes, grenades,
-- glasses and headsets in theirs (audit economy.7; Prima Games on the 0.16.8 hardcore rules: "weapon mods and scopes",
-- "expensive headsets"); goggles are weapon-part records here (EFT files night vision under its scopes). Guns, armour,
-- rigs, packs, helmets and other secure containers stay out.
Items.SECURE_KINDS = {
	ammo = true, mag = true, med = true, food = true, key = true, loot = true, quest = true,
	mod = true, nvg = true, grenade = true, eyewear = true, headset = true,
}

function Items.get(id: string): any
	return defs[id]
end

function Items.valueOf(it: any): number
	local d = defs[it.id]
	if not d or it.rk then
		return 0
	end
	local v = d.value * (it.n or 1)
	if it.a and it.at and defs[it.at] then
		v += it.a * defs[it.at].value
	end
	if d.armor and it.dur then
		v = math.floor(v * (0.35 + 0.65 * math.clamp(it.dur / d.armor.dur, 0, 1)))
	end
	if d.med and d.med.hp and it.hp then
		v = math.floor(v * math.clamp(it.hp / d.med.hp, 0.1, 1))
	end
	if d.repair and it.pts then
		v = math.floor(v * math.clamp(it.pts / d.repair.points, 0.1, 1))
	end
	if d.weapon and it.wear then
		-- worn weapons sell for less (Tarkov: price follows durability)
		v = math.floor(v * (0.35 + 0.65 * math.clamp(it.wear / 100, 0, 1)))
	end
	if it.tag and type(it.tag.lvl) == "number" then
		v = math.floor(v * (1 + 0.15 * it.tag.lvl))
	end
	return v
end

-- Tarkov's gear penalties: the movement speed, turn speed and ergonomics percentages of everything worn
local WORN = { "armor", "head", "rig", "back", "ears", "face", "eyes" }
-- armourMul(class) -> multiplier for an armoured item's penalties (the Light / Heavy Vests skills)
function Items.gearPenalties(view: any, armourMul: ((number) -> number)?): { speed: number, turn: number, ergo: number }
	local out = { speed = 0, turn = 0, ergo = 0 }
	local slots = view and view.slots
	for _, slot in WORN do
		local g = slots and slots[slot]
		local it = g and view.items[g]
		local d = it and defs[it.id]
		local pen = d and d.pen
		if pen then
			local m = (armourMul and d.armor and (slot == "armor" or slot == "rig")) and armourMul(d.armor.class or 0) or 1
			out.speed += (pen.speed or 0) * m
			out.turn += (pen.turn or 0) * m
			out.ergo += (pen.ergo or 0) * m
		end
		-- the plates in a worn carrier add their own penalties (Tarkov 0.14)
		if it and it.mods and PL.slotsOf(d) then
			for _, s in PL.SLOTS do
				local pg = it.mods[s]
				local p = pg and view.items[pg]
				local pd = p and defs[p.id]
				if pd and pd.pen then
					local m = armourMul and armourMul(pd.armor and pd.armor.class or 0) or 1
					out.speed += (pd.pen.speed or 0) * m
					out.turn += (pd.pen.turn or 0) * m
					out.ergo += (pd.pen.ergo or 0) * m
				end
			end
		end
	end
	return out
end

-- the chance a round with penetration `pen` goes through armor of `class` at durability fraction `durFrac`: Tarkov's
-- curve (Plates.penChance). Health.luau resolves every hit with it; the INSPECT window shows it against fresh armour.
function Items.penChance(pen: number, class: number, durFrac: number): number
	return PL.penChance(pen, class, durFrac)
end

-- what a carrier costs with the plates it comes with (traders sell it so; Tarkov prices a preset by its parts)
function Items.kitValue(id: string): number
	local d = defs[id]
	if not d then
		return 0
	end
	local v = d.value
	local slots = PL.slotsOf(d)
	if slots then
		for _, s in slots do
			local pd = s.def and defs[s.def]
			if pd then
				v += pd.value
			end
		end
	end
	return v
end

-- items that start examined for every player (Tarkov: common gear is known)
function Items.knownByDefault(id: string): boolean
	local d = defs[id]
	if not d then
		return false
	end
	return d.kind ~= "loot" and d.kind ~= "quest" and d.kind ~= "key" or d.rarity == "common" or id == "DOGTAG"
end

return Items
