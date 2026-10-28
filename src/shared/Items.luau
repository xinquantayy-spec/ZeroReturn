--!strict
-- Item definitions (read-only, original names). Instances/ownership are server truth (server Services/Inv).
-- kinds: weapon | pistol | melee | mag | ammo | helmet | armor | rig | backpack | secure | med | food | key | loot | quest
-- Values are in MK (Tarkov-like magnitudes). Optional blocks by kind:
--   caliber (weapon/pistol/mag/ammo), weapon (Weapons key), family (mag compatibility), capacity (mag / internal tube)
--   ammo = { dmg, pen, armorDmg, pellets, bleedL, bleedH, frag, subsonic }
--   armor = { class, dur, zones, blunt, destr, coverage?, ricochet?, face? }   (helmets/armor/armored rigs)
--   grid = { w, h }   (rigs / backpacks / secure containers)
--   med = { light, heavy, fracture, pain, surgery, hp, uses, time, duration }
--   food = { energy, water, time, stamina }
--   key = { door, uses }
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
add("R17_RIFLE", { name = "R-17 Carbine", short = "R-17", kind = "weapon", w = 5, h = 2, mass = 3.2, value = 32000, caliber = "6.2", weapon = "R17", family = "R17", desc = "Fictional 6.2x40 service carbine. Dependable, stiff recoil.", color = c("#55605A") })
add("KST_RIFLE", { name = "Kestrel KS-7", short = "KS-7", kind = "weapon", w = 5, h = 2, mass = 3.5, value = 41000, caliber = "7.6", weapon = "KST", family = "KST", rarity = "uncommon", desc = "Stamped-receiver 7.6x39 rifle. Heavy hitter, climbs hard.", color = c("#5C5446") })
add("SPARROW_SMG", { name = "Sparrow SMG-9", short = "SMG-9", kind = "weapon", w = 4, h = 2, mass = 2.6, value = 27000, caliber = "9", weapon = "SPARROW", family = "SPARROW", desc = "Compact 9x19 submachine gun. Fast, controllable, weak against plates.", color = c("#4B5054") })
add("HARROW12", { name = "Harrow-12 Pump", short = "H-12", kind = "weapon", w = 5, h = 1, mass = 3.4, value = 19000, caliber = "12", weapon = "HARROW", capacity = 6, desc = "12-gauge pump with a 6-shell tube. Load shells directly.", color = c("#5A4B3C") })
add("TUNDRA_BOLT", { name = "Tundra Bolt Rifle", short = "TUNDRA", kind = "weapon", w = 6, h = 1, mass = 4.1, value = 46000, caliber = "7.6L", weapon = "TUNDRA", capacity = 5, rarity = "uncommon", desc = "Long bolt-action in 7.6x54. Five-round internal magazine.", color = c("#4F4A3B") })
add("P9_PISTOL", { name = "P-9 Vesna", short = "P-9", kind = "pistol", w = 2, h = 1, mass = 0.8, value = 9500, caliber = "9", weapon = "P9", family = "P9", desc = "9x19 service pistol. Holster sidearm.", color = c("#45494B") })
add("FIELD_KNIFE", { name = "Field Knife", short = "KNIFE", kind = "melee", w = 1, h = 2, mass = 0.3, value = 4000, weapon = "KNIFE", desc = "Fixed-blade utility knife.", color = c("#5E5E58") })

-- ── attachments (weapon mods) ────────────────────────────────────────────────
-- mod = { slot = "rail"|"muzzle"|"under"|"side", caliber?, ergo?, recoil? (multiplier), loud? (multiplier), zoom?, reflex?, light? }
local MODC = c("#33383A")
add("RED_DOT", { name = "RS-1 Reflex Sight", short = "REFLEX", kind = "mod", w = 1, h = 1, mass = 0.2, value = 16000, mod = { slot = "rail", ergo = -1, reflex = true }, desc = "Open reflex sight with a red dot. Mounts on the top rail.", color = MODC })
add("SCOPE_4X", { name = "C4 Combat Scope", short = "4X", kind = "mod", w = 2, h = 1, mass = 0.55, value = 48000, rarity = "uncommon", mod = { slot = "rail", ergo = -4, zoom = 4 }, desc = "Fixed 4x prism scope. Mounts on the top rail.", color = MODC })
add("SUPP_62", { name = "6.2 Suppressor", short = "SUPP 6.2", kind = "mod", w = 2, h = 1, mass = 0.5, value = 36000, rarity = "uncommon", mod = { slot = "muzzle", caliber = "6.2", loud = 0.35, recoil = 0.93, ergo = -3 }, desc = "Sound suppressor for 6.2 rifles. Hides the muzzle flash.", color = MODC })
add("SUPP_9", { name = "9mm Suppressor", short = "SUPP 9", kind = "mod", w = 2, h = 1, mass = 0.3, value = 24000, mod = { slot = "muzzle", caliber = "9", loud = 0.3, recoil = 0.95, ergo = -2 }, desc = "Sound suppressor for 9x19 weapons.", color = MODC })
add("BRAKE_76", { name = "7.6 Muzzle Brake", short = "BRAKE", kind = "mod", w = 1, h = 1, mass = 0.2, value = 12000, mod = { slot = "muzzle", caliber = "7.6", loud = 1.15, recoil = 0.85 }, desc = "Muzzle brake for 7.6x39. Less recoil, more noise.", color = MODC })
add("GRIP_V", { name = "Vertical Foregrip", short = "GRIP", kind = "mod", w = 1, h = 1, mass = 0.1, value = 9000, mod = { slot = "under", recoil = 0.9, ergo = 4 }, desc = "Vertical grip. Steadier bursts, faster handling.", color = MODC })
add("LIGHT_T", { name = "WL-2 Weapon Light", short = "LIGHT", kind = "mod", w = 1, h = 1, mass = 0.15, value = 11000, mod = { slot = "side", light = true, ergo = -1 }, desc = "Weapon light. Toggle with L.", color = MODC })

-- ── magazines ─────────────────────────────────────────────────────────────────
add("R17_MAG", { name = "R-17 25-rd Magazine", short = "MAG 25", kind = "mag", w = 1, h = 2, mass = 0.3, value = 2800, capacity = 25, caliber = "6.2", family = "R17", desc = "25-round steel box magazine for the R-17.", color = c("#3E4440") })
add("R17_MAG40", { name = "R-17 40-rd Magazine", short = "MAG 40", kind = "mag", w = 1, h = 3, mass = 0.45, value = 9500, capacity = 40, caliber = "6.2", family = "R17", rarity = "uncommon", desc = "Extended 40-round magazine. Slower to load, heavier on the rig.", color = c("#3A403D") })
add("KST_MAG", { name = "KS-7 30-rd Magazine", short = "MAG 30", kind = "mag", w = 1, h = 2, mass = 0.33, value = 3400, capacity = 30, caliber = "7.6", family = "KST", desc = "Curved 30-round 7.6x39 magazine.", color = c("#4A4237") })
add("SPARROW_MAG", { name = "SMG-9 30-rd Magazine", short = "MAG 30", kind = "mag", w = 1, h = 2, mass = 0.22, value = 2600, capacity = 30, caliber = "9", family = "SPARROW", desc = "Straight 30-round 9x19 stick magazine.", color = c("#3F4346") })
add("P9_MAG", { name = "P-9 17-rd Magazine", short = "MAG 17", kind = "mag", w = 1, h = 1, mass = 0.12, value = 1900, capacity = 17, caliber = "9", family = "P9", desc = "Double-stack pistol magazine.", color = c("#3C3F41") })

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
ammo("A12_SLUG", "12/70 Slug", "12 SLUG", "12", 20, 380, { dmg = 168, pen = 22, armorDmg = 0.75, bleedL = 0.3, bleedH = 0.2, frag = 0.1 }, "uncommon", "Single heavy lead slug.")
ammo("A76L_LPS", "7.6x54R LPS", "7.6L LPS", "7.6L", 40, 520, { dmg = 81, pen = 42, armorDmg = 0.78, bleedL = 0.2, bleedH = 0.15, frag = 0.18 }, "uncommon", "Full-power rifle cartridge.")
ammo("A76L_SNB", "7.6x54R SNB", "7.6L SNB", "7.6L", 40, 1600, { dmg = 75, pen = 62, armorDmg = 0.87, bleedL = 0.15, bleedH = 0.12, frag = 0.08 }, "rare", "Sniper armor-piercing load.")

-- ── armor, helmets ────────────────────────────────────────────────────────────
local TS = { thorax = true }
local TSS = { thorax = true, stomach = true }
local TSSA = { thorax = true, stomach = true, arms = true }
add("ARMOR_C2", { name = "Quay Security Vest", short = "VEST II", kind = "armor", w = 3, h = 3, mass = 2.5, value = 18000, armor = { class = 2, dur = 40, zones = TS, blunt = 0.32, destr = 0.25 }, desc = "Soft aramid vest, class 2. Thorax only.", color = c("#4C5545") })
add("ARMOR_C3", { name = "Patrol Soft Armor", short = "VEST III", kind = "armor", w = 3, h = 3, mass = 3.6, value = 38000, armor = { class = 3, dur = 50, zones = TSS, blunt = 0.28, destr = 0.45 }, desc = "Class 3 soft armor. Covers thorax and stomach.", color = c("#4A5242") })
add("ARMOR_C4", { name = "PC-4 Plate Carrier", short = "PC-4", kind = "armor", w = 3, h = 3, mass = 6.8, value = 82000, rarity = "uncommon", armor = { class = 4, dur = 55, zones = TSS, blunt = 0.24, destr = 0.5 }, desc = "Class 4 plate carrier with soft backer.", color = c("#575A47") })
add("ARMOR_C5", { name = "HP-5 Heavy Vest", short = "HP-5", kind = "armor", w = 3, h = 3, mass = 9.8, value = 165000, rarity = "rare", armor = { class = 5, dur = 70, zones = TSS, blunt = 0.2, destr = 0.55 }, desc = "Class 5 composite. Heavy, slows you down.", color = c("#4D4F45") })
add("ARMOR_C6", { name = "Bulwark Assault Armor", short = "BULWARK", kind = "armor", w = 4, h = 4, mass = 13.5, value = 330000, rarity = "epic", armor = { class = 6, dur = 85, zones = TSSA, blunt = 0.18, destr = 0.6 }, desc = "Class 6 steel assault armor with arm protection.", color = c("#3E423D") })
add("HELMET_C2", { name = "Shell Helmet", short = "SHELL", kind = "helmet", w = 2, h = 2, mass = 1.2, value = 14000, armor = { class = 2, dur = 30, coverage = 0.55, ricochet = 0.2, blunt = 0.3, destr = 0.45 }, desc = "Class 2 pressed helmet. Top and nape.", color = c("#55593F") })
add("HELMET_C3", { name = "Tac Helmet", short = "TAC III", kind = "helmet", w = 2, h = 2, mass = 1.4, value = 34000, armor = { class = 3, dur = 36, coverage = 0.62, ricochet = 0.35, blunt = 0.27, destr = 0.45 }, desc = "Class 3 cut helmet with rails.", color = c("#4F5340") })
add("HELMET_C4", { name = "Ballistic Helmet B4", short = "B4", kind = "helmet", w = 2, h = 2, mass = 1.6, value = 78000, rarity = "uncommon", armor = { class = 4, dur = 45, coverage = 0.7, ricochet = 0.4, blunt = 0.24, destr = 0.5 }, desc = "Class 4 high-cut helmet.", color = c("#45493C") })
add("HELMET_C5", { name = "Bulwark Faceplate Helmet", short = "FACEPLATE", kind = "helmet", w = 2, h = 2, mass = 3.5, value = 260000, rarity = "epic", armor = { class = 5, dur = 60, coverage = 1, ricochet = 0.3, blunt = 0.2, destr = 0.55, face = true }, desc = "Class 5 helmet with steel face plate.", color = c("#34372F") })

-- ── rigs, backpacks, secure containers ───────────────────────────────────────
add("RIG_BELT", { name = "Utility Belt", short = "BELT", kind = "rig", w = 2, h = 2, mass = 0.4, value = 6000, grid = { w = 4, h = 1 }, desc = "Four pouches on a belt.", color = c("#5E5A47") })
add("RIG_CHEST", { name = "Chest Rig", short = "CHEST RIG", kind = "rig", w = 2, h = 2, mass = 0.8, value = 16000, grid = { w = 4, h = 2 }, desc = "Open chest rig, eight cells.", color = c("#5A5844") })
add("RIG_PLATE", { name = "Assault Plate Rig", short = "PLATE RIG", kind = "rig", w = 3, h = 3, mass = 6.0, value = 95000, rarity = "uncommon", grid = { w = 4, h = 2 }, armor = { class = 4, dur = 50, zones = TS, blunt = 0.25, destr = 0.5 }, desc = "Armored rig, class 4 front plate. Cannot be worn with body armor.", color = c("#4F513F") })
add("BAG_SLING", { name = "Sling Bag", short = "SLING", kind = "backpack", w = 2, h = 2, mass = 0.4, value = 7500, grid = { w = 3, h = 2 }, desc = "Small over-the-shoulder bag.", color = c("#6B6A4E") })
add("CANVAS_BAG", { name = "Canvas Pack", short = "CANVAS", kind = "backpack", w = 3, h = 3, mass = 0.9, value = 18000, grid = { w = 4, h = 4 }, desc = "Worn canvas backpack with a 4x4 compartment.", color = c("#6B6A4E") })
add("BAG_PATROL", { name = "Patrol Pack", short = "PATROL", kind = "backpack", w = 4, h = 4, mass = 1.3, value = 42000, rarity = "uncommon", grid = { w = 5, h = 5 }, desc = "Framed patrol pack.", color = c("#5C5B44") })
add("BAG_RAID", { name = "Raid Pack", short = "RAID", kind = "backpack", w = 5, h = 5, mass = 2.1, value = 88000, rarity = "rare", grid = { w = 6, h = 6 }, desc = "Large expedition pack. Heavy when full.", color = c("#53523F") })
add("SECURE_S", { name = "Pouch S", short = "POUCH S", kind = "secure", w = 2, h = 2, mass = 0.5, value = 0, grid = { w = 2, h = 2 }, desc = "Secure container. Contents survive death.", color = c("#3B3F3F") })
add("SECURE_M", { name = "Pouch M", short = "POUCH M", kind = "secure", w = 3, h = 3, mass = 0.7, value = 0, rarity = "rare", grid = { w = 3, h = 3 }, desc = "Secure container. Contents survive death.", color = c("#3B3F3F") })
add("SECURE_L", { name = "Pouch L", short = "POUCH L", kind = "secure", w = 3, h = 4, mass = 0.9, value = 0, rarity = "epic", grid = { w = 4, h = 3 }, desc = "Secure container. Contents survive death.", color = c("#3B3F3F") })

-- ── medical, provisions ───────────────────────────────────────────────────────
local MED = c("#C9CDBE")
add("BANDAGE", { name = "Field Dressing", short = "DRESSING", kind = "med", w = 1, h = 1, mass = 0.05, value = 2500, med = { light = true, uses = 1, time = 3 }, desc = "Stops a light bleed.", color = MED })
add("TOURNIQUET", { name = "Strap Tourniquet", short = "TQ", kind = "med", w = 1, h = 1, mass = 0.08, value = 6500, med = { heavy = true, limbsOnly = true, uses = 1, time = 3 }, desc = "Stops a heavy bleed on a limb.", color = MED })
add("HEMOSTAT", { name = "Hemostatic Pack", short = "HEMO", kind = "med", w = 1, h = 1, mass = 0.1, value = 14000, rarity = "uncommon", med = { heavy = true, light = true, uses = 3, time = 2.5 }, desc = "Stops light and heavy bleeds. 3 uses.", color = MED })
add("SPLINT", { name = "Ladder Splint", short = "SPLINT", kind = "med", w = 1, h = 1, mass = 0.1, value = 3500, med = { fracture = true, uses = 1, time = 4.5 }, desc = "Sets a fracture.", color = MED })
add("PAINKILLERS", { name = "Analgesic Tabs", short = "PAINKILL", kind = "med", w = 1, h = 1, mass = 0.05, value = 6000, med = { pain = true, uses = 4, time = 1.5, duration = 240 }, desc = "Suppresses pain for 4 minutes. 4 uses.", color = MED })
add("MEDKIT_S", { name = "Pocket Aid Kit", short = "AID 100", kind = "med", w = 1, h = 1, mass = 0.2, value = 5000, med = { hp = 100, time = 2.5 }, desc = "Restores health (100 points). Does not stop bleeding.", color = MED })
add("MEDKIT_M", { name = "Road Kit", short = "ROAD 220", kind = "med", w = 1, h = 2, mass = 0.4, value = 9000, med = { hp = 220, light = true, time = 3 }, desc = "Restores health (220 points), stops light bleeds.", color = MED })
add("MEDKIT_L", { name = "Field Medkit", short = "FIELD 400", kind = "med", w = 1, h = 2, mass = 0.6, value = 21000, rarity = "uncommon", med = { hp = 400, light = true, heavy = true, time = 3 }, desc = "Restores health (400 points), stops all bleeding.", color = MED })
add("MEDKIT_XL", { name = "Trauma Case", short = "TRAUMA", kind = "med", w = 2, h = 2, mass = 1.6, value = 75000, rarity = "rare", med = { hp = 1200, light = true, heavy = true, fracture = true, time = 4 }, desc = "Restores health (1200), stops bleeds, sets fractures.", color = MED })
add("SURGKIT", { name = "Field Surgical Kit", short = "SURGERY", kind = "med", w = 2, h = 1, mass = 0.8, value = 52000, rarity = "rare", med = { surgery = true, uses = 2, time = 12 }, desc = "Restores a destroyed limb (reduced max health). 2 uses.", color = MED })
add("WATER", { name = "Water Bottle", short = "WATER", kind = "food", w = 1, h = 2, mass = 0.6, value = 8000, food = { water = 60, time = 4 }, desc = "Hydration +60.", color = c("#7FA8B8") })
add("STEW", { name = "Canned Stew", short = "STEW", kind = "food", w = 1, h = 1, mass = 0.4, value = 6500, food = { energy = 55, water = -5, time = 5 }, desc = "Energy +55.", color = c("#8F6A4A") })
add("HARDTACK", { name = "Hardtack", short = "HARDTACK", kind = "food", w = 1, h = 1, mass = 0.15, value = 3000, food = { energy = 30, water = -12, time = 3 }, desc = "Energy +30, dries you out.", color = c("#A48C64") })
add("VOLT_DRINK", { name = "Volt Energy Drink", short = "VOLT", kind = "food", w = 1, h = 2, mass = 0.4, value = 11000, rarity = "uncommon", food = { energy = 20, water = 35, stamina = 60, time = 3 }, desc = "Energy +20, hydration +35, stamina boost.", color = c("#6E8F3C") })

-- ── keys, quest items ─────────────────────────────────────────────────────────
add("KEY_OFFICE", { name = "Harbor Office Key", short = "OFFICE KEY", kind = "key", w = 1, h = 1, mass = 0.02, value = 22000, rarity = "uncommon", key = { door = "office", uses = 25 }, desc = "Opens the harbor office.", color = c("#8C7A4E") })
add("RUSTED_KEYCARD", { name = "Vault Keycard", short = "VAULT", kind = "key", w = 1, h = 1, mass = 0.02, value = 95000, rarity = "rare", key = { door = "vault", uses = 10 }, desc = "Quay authority keycard. Opens the depot vault. 10 uses.", color = c("#8A6252") })
add("SEALED_DRIVE", { name = "Sealed Drive", short = "DRIVE", kind = "quest", w = 1, h = 1, mass = 0.1, value = 120000, rarity = "rare", desc = "Evacuation office data drive in a sealed sleeve.", color = c("#C07946") })
add("LEDGER", { name = "Harbormaster's Ledger", short = "LEDGER", kind = "quest", w = 1, h = 1, mass = 0.3, value = 450000, rarity = "legendary", desc = "Leather ledger of every shipment that left Quay 7.", color = c("#7A4A2E") })

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
loot("CAPT_WATCH", "Captain's Watch", "WATCH", 1, 1, 0.1, 85000, "rare", "Swiss-style dive watch.", "#B39A5A")
loot("FLASH_MODULE", "Flash Module", "FLASH", 1, 1, 0.05, 70000, "rare", "Encrypted flash module.", "#4F6E8C")
loot("INTEL_FOLDER", "Intel Folder", "INTEL", 1, 1, 0.2, 90000, "rare", "Stamped folder of shipping manifests.", "#9C7A4A")
loot("MIL_CIRCUIT", "Military Circuit", "MIL CIRC", 2, 1, 0.4, 160000, "epic", "Hardened military control circuit.", "#2F5A3A")
loot("COLD_WALLET", "Cold Wallet", "WALLET", 1, 1, 0.05, 220000, "epic", "Hardware wallet. Someone will pay for it.", "#C07946")
loot("BRASS_LION", "Brass Lion", "LION", 2, 2, 3.2, 280000, "epic", "Brass lion statuette from the harbormaster's office.", "#B08A3C")
add("DOGTAG", { name = "Dog Tag", short = "TAG", kind = "loot", w = 1, h = 1, mass = 0.02, value = 12000, rarity = "uncommon", desc = "An operator's identification tag. Worth more the more experienced its owner was.", color = c("#A7A9A0") })

local Items = { defs = defs }

-- equipment slots and the kinds each accepts
Items.SLOTS = {
	head = { helmet = true }, armor = { armor = true }, rig = { rig = true }, back = { backpack = true }, secure = { secure = true },
	primary = { weapon = true }, secondary = { weapon = true }, holster = { pistol = true }, melee = { melee = true },
}
Items.SLOT_ORDER = { "head", "armor", "rig", "back", "secure", "primary", "secondary", "holster", "melee" }
Items.SLOT_NAMES = {
	head = "HEADWEAR", armor = "BODY ARMOR", rig = "TACTICAL RIG", back = "BACKPACK", secure = "SECURE CONTAINER",
	primary = "PRIMARY", secondary = "ON BACK", holster = "HOLSTER", melee = "SCABBARD",
}
Items.RARITY = { common = 0, uncommon = 1, rare = 2, epic = 3, legendary = 4 }
-- secure containers refuse bulky gear (Tarkov-like restriction)
Items.SECURE_KINDS = { ammo = true, mag = true, med = true, food = true, key = true, loot = true, quest = true }

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
	if it.tag and type(it.tag.lvl) == "number" then
		v = math.floor(v * (1 + 0.15 * it.tag.lvl))
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
