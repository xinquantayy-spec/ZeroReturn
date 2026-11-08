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
-- decision economy-1a, third slice (2026-11-08): EFT's two commonest scav guns. The KS-74 copies the AK-74N (5.45x39,
-- our 5.4x39): every KS-7 dust cover, handguard, grip, stock and mount fits it, its magazines are its own. The Makar PM
-- copies the PM (9x18): a fixed-barrel blowback pistol with an 8-round magazine. Values are EFT's handbook prices
-- (SPT's handbook.json: AK-74N 23,147, PM 4,097); weights EFT's (3.1 and 0.73 kg)
add("KS74_RIFLE", { name = "Kestrel KS-74", short = "KS-74", kind = "weapon", w = 5, h = 2, mass = 3.1, value = 23147, caliber = "5.4", weapon = "KS74", family = "KS74", rarity = "uncommon", desc = "The KS-7 action in 5.4x39: a slimmer barrel, a long two-port brake and a flatter shooting rifle. Takes the KS-7's furniture, not its magazines.", color = c("#4A4038") })
add("PM_PISTOL", { name = "Makar PM", short = "PM", kind = "pistol", w = 2, h = 1, mass = 0.73, value = 4097, caliber = "9.18", weapon = "PM", family = "PM", desc = "Small 9x18 blowback pistol with a fixed barrel. Eight rounds, a stiff trigger, everywhere in the region.", color = c("#3E4244") })
-- economy-1a, fourth slice (2026-11-08): EFT's self-loaders. The Siskin SK-45 copies the TOZ Simonov SKS (7.62x39 = our
-- 7.6x39): a fixed 10-round magazine loaded a round at a time. The Merlin MR-10 copies the SVD / SVDS (7.62x54R = our
-- 7.6x54R): a 10-round detachable magazine, the side dovetail for a scope mount, the Tundra's muzzle devices. Values are
-- EFT's handbook prices (SKS 19,331, SVDS 42,800); weights EFT's (3.9 and 4.3 kg)
add("SKS_RIFLE", { name = "Siskin SK-45", short = "SK-45", kind = "weapon", w = 6, h = 1, mass = 3.9, value = 19331, caliber = "7.6", weapon = "SKS", capacity = 10, desc = "Old self-loading carbine in 7.6x39 with a wooden stock and a folding bayonet. Ten rounds, loaded one at a time.", color = c("#6A4A2E") })
add("SVD_RIFLE", { name = "Merlin MR-10", short = "MR-10", kind = "weapon", w = 6, h = 2, mass = 4.3, value = 42800, caliber = "7.6L", weapon = "SVD", family = "SVD", rarity = "rare", desc = "Self-loading marksman rifle in 7.6x54R with a skeleton stock. Takes a scope on the side dovetail and the Tundra's muzzle devices.", color = c("#4E3A2A") })
-- economy-1a, fifth slice (2026-11-08): EFT's 7.62x51 NATO rifles (our 7.6x51). The Shrike S-14 copies the Springfield
-- Armory M1A (a marksman rifle in EFT's handbook): single shots, 10- and 20-round magazines, a bridge mount for a scope.
-- The Osprey OB-7 copies the Remington Model 700 bolt-action: a detachable 5- or 10-round magazine, no iron sights, a rail
-- base for a scope. Values are EFT's handbook prices (M1A 30,264, M700 17,500); the weights are ours (not found)
add("M1A_RIFLE", { name = "Shrike S-14", short = "S-14", kind = "weapon", w = 6, h = 2, mass = 4.2, value = 30264, caliber = "7.6N", weapon = "M1A", family = "M1A", rarity = "uncommon", desc = "Self-loading battle rifle in 7.6x51 with a synthetic stock. Heavy, slow to handle, hits hard at range. Takes a scope on its bridge mount.", color = c("#2E302E") })
add("M700_BOLT", { name = "Osprey OB-7", short = "OB-7", kind = "weapon", w = 6, h = 2, mass = 4.4, value = 17500, caliber = "7.6N", weapon = "M700", family = "M700", rarity = "uncommon", desc = "Bolt-action rifle in 7.6x51 with a heavy free-floated barrel and a detachable box magazine. No iron sights: it needs a scope on its rail base.", color = c("#4B5442") })
-- economy-1a, sixth slice (2026-11-08): EFT's 9x39 rifles. The Owl SV-9 copies the VSS Vintorez (a marksman rifle in EFT's
-- handbook) and the Nightjar AV-9 the AS VAL; both fire single shots or bursts, share the 10- and 20-round magazines and
-- carry their suppressor as their barrel (EFT's integral barrel-suppressors, parts of their own). Values are EFT's
-- handbook prices (VSS 65,203, AS VAL 66,869); the weights are ours (not found)
add("VSS_RIFLE", { name = "Owl SV-9", short = "SV-9", kind = "weapon", w = 5, h = 2, mass = 2.6, value = 65203, caliber = "9.39", weapon = "VSS", family = "VSS", rarity = "rare", desc = "Silenced marksman rifle in 9x39 with a wooden skeleton stock. Its barrel is the suppressor. Whisper quiet; the heavy bullet drops hard past 200 m.", color = c("#6B4429") })
add("VAL_RIFLE", { name = "Nightjar AV-9", short = "AV-9", kind = "weapon", w = 5, h = 2, mass = 2.5, value = 66869, caliber = "9.39", weapon = "VAL", family = "VSS", rarity = "rare", desc = "Silenced assault rifle in 9x39 with a folding skeleton stock. Takes the SV-9's magazines.", color = c("#5A3A34") })
-- economy-1a, seventh slice (2026-11-08): EFT's personal defence weapons. The Swift PW-46 copies the HK MP7A1 (4.6x30) and
-- the Petrel PD-57 the FN P90 (5.7x28); both fire single shots or bursts. Values are EFT's handbook prices (MP7A1 44,288,
-- P90 45,200); the weights are ours (not found)
add("MP7_SMG", { name = "Swift PW-46", short = "PW-46", kind = "weapon", w = 3, h = 2, mass = 1.9, value = 44288, caliber = "4.6", weapon = "MP7", family = "MP7", rarity = "rare", desc = "Compact personal defence weapon in 4.6x30 with the magazine in its grip, a top rail and a sliding stock. Fast, light recoil, small rounds that pierce.", color = c("#232526") })
add("P90_SMG", { name = "Petrel PD-57", short = "PD-57", kind = "weapon", w = 3, h = 2, mass = 2.6, value = 45200, caliber = "5.7", weapon = "P90", family = "P90", rarity = "rare", desc = "Bullpup personal defence weapon in 5.7x28 with a 50-round magazine lying on top and a built-in ring sight.", color = c("#3B3E36") })
-- economy-1a, eighth slice (2026-11-08): EFT's .45 ACP guns (our 11.4x23, the calibre's metric name) and its 5.7x28 pistol.
-- The Harrier HS-45 copies the HK UMP 45, the Lark L-11 the Colt M1911A1 and the Finch F-57 the FN Five-seveN MK2. Values
-- are EFT's handbook prices (UMP 45 26,500, M1911A1 5,408, Five-seveN MK2 14,238); the weights are ours (not found)
add("UMP_SMG", { name = "Harrier HS-45", short = "HS-45", kind = "weapon", w = 3, h = 2, mass = 2.3, value = 26500, caliber = "11.4", weapon = "UMP", family = "UMP", rarity = "uncommon", desc = "Boxy polymer submachine gun in 11.4x23 with a folding stock. Slow-firing, hard-hitting, easy to hold.", color = c("#1E1F20") })
add("M1911_PISTOL", { name = "Lark L-11", short = "L-11", kind = "pistol", w = 2, h = 1, mass = 1.1, value = 5408, caliber = "11.4", weapon = "M1911", family = "M1911", desc = "Single-action steel pistol in 11.4x23. Seven heavy rounds, a crisp trigger, a sharp kick.", color = c("#2C2E30") })
add("FN57_PISTOL", { name = "Finch F-57", short = "F-57", kind = "pistol", w = 2, h = 1, mass = 0.74, value = 14238, caliber = "5.7", weapon = "FN57", family = "FN57", rarity = "uncommon", desc = "Light polymer pistol in 5.7x28 with a 20-round magazine. Fires the PD-57's rounds.", color = c("#1C1D1E") })
-- economy-1a, ninth slice (2026-11-08): EFT's 7.62x25 TT guns (our 7.6x25). The Pipit P-33 copies the TT-33 and the
-- Grackle G-41 the PPSh-41. Values are EFT's handbook prices (TT-33 4,189, PPSh-41 10,251); the weights are ours
add("TT_PISTOL", { name = "Pipit P-33", short = "P-33", kind = "pistol", w = 2, h = 1, mass = 0.85, value = 4189, caliber = "7.6T", weapon = "TT", family = "TT", desc = "Flat steel pistol in 7.6x25. Eight fast rounds, a heavy kick, found everywhere.", color = c("#2D3032") })
add("PPSH_SMG", { name = "Grackle G-41", short = "G-41", kind = "weapon", w = 5, h = 2, mass = 3.6, value = 10251, caliber = "7.6T", weapon = "PPSH", family = "PPSH", desc = "Wooden-stocked submachine gun in 7.6x25 with a perforated jacket and a 71-round drum. A thousand rounds a minute.", color = c("#6A4228") })
-- economy-1a, tenth slice (2026-11-08): EFT's 9x21 guns and the .366 TKM bolt-action (our 9.6x39). The Wren W-21 copies
-- the SR-1MP Gyurza, the Jay J-21 the SR-2M Veresk and the Tern T-215 the VPO-215 Gornostay. Values are EFT's handbook
-- prices (19,292, 31,000 and 7,350); the weights are ours
add("W21_PISTOL", { name = "Wren W-21", short = "W-21", kind = "pistol", w = 2, h = 1, mass = 0.95, value = 19292, caliber = "9.21", weapon = "W21", family = "W21", rarity = "uncommon", desc = "Long-slide service pistol in 9x21 with a polymer frame and an 18-round magazine. Its rounds go through soft armour.", color = c("#2B2D2E") })
add("J21_SMG", { name = "Jay J-21", short = "J-21", kind = "weapon", w = 3, h = 2, mass = 1.65, value = 31000, caliber = "9.21", weapon = "J21", family = "J21", rarity = "rare", desc = "Compact 9x21 submachine gun with a top rail, a folding front grip and a pressed-steel stock. Light recoil, 950 rounds a minute.", color = c("#33373A") })
add("T215_BOLT", { name = "Tern T-215", short = "T-215", kind = "weapon", w = 6, h = 1, mass = 3.4, value = 7350, caliber = "9.6", weapon = "T215", family = "T215", desc = "Sporting bolt-action rifle in 9.6x39 on an old military action, with a walnut stock, a top rail and a 4-round magazine.", color = c("#5E3A22") })
-- economy-1a, eleventh slice (2026-11-08): EFT's revolvers. The Crake C-357 copies the Chiappa Rhino 50DS (.357 Magnum,
-- our 9x33R), the Crake C-9 the Rhino 200DS (9x19) and the Bustard B-12 the RSh-12 (12.7x55). Their cylinders are part
-- of the gun and load round by round (capacity, no magazine family). Values are EFT's handbook prices (10,443, 5,800, 30,443); weights ours
add("CRK357_REV", { name = "Crake C-357", short = "C-357", kind = "pistol", w = 2, h = 1, mass = 0.96, value = 10443, caliber = "9.33", weapon = "CRK357", capacity = 6, rarity = "uncommon", desc = "Six-shot 9x33R revolver that fires from the bottom chamber, so it kicks straight back. Loads one round at a time.", color = c("#3A3E42") })
add("CRK9_REV", { name = "Crake C-9", short = "C-9", kind = "pistol", w = 2, h = 1, mass = 0.7, value = 5800, caliber = "9", weapon = "CRK9", capacity = 6, desc = "Snub-nosed six-shot revolver in 9x19 on the C-357's frame. Loads one round at a time.", color = c("#3A3E42") })
add("BZ12_REV", { name = "Bustard B-12", short = "B-12", kind = "pistol", w = 3, h = 1, mass = 2.2, value = 30443, caliber = "12.7", weapon = "BZ12", capacity = 5, rarity = "rare", desc = "Huge five-shot revolver in 12.7x55 with a rail under the barrel. Every shot hits like a rifle's. Loads one round at a time.", color = c("#34383B") })
-- economy-1a, twelfth slice (2026-11-08): more 9x19 guns. The Dunlin D-17 copies the Glock 17, the Avocet AV-9 the SIG
-- MPX and the Bunting B-19 the PP-19-01 Vityaz. Values are EFT's handbook prices (6,608, 18,907, 14,751); weights ours
add("D17_PISTOL", { name = "Dunlin D-17", short = "D-17", kind = "pistol", w = 2, h = 1, mass = 0.63, value = 6608, caliber = "9", weapon = "D17", family = "D17", desc = "Striker-fired polymer pistol in 9x19 with a 17-round magazine. Light, simple, everywhere.", color = c("#2A2C2D") })
add("AV9_SMG", { name = "Avocet AV-9", short = "AV-9", kind = "weapon", w = 3, h = 2, mass = 2.3, value = 18907, caliber = "9", weapon = "AV9", family = "AV9", rarity = "uncommon", desc = "9x19 submachine gun on a rifle-style receiver with a full top rail and a collapsing stock. 850 rounds a minute.", color = c("#2B2E31") })
add("B19_SMG", { name = "Bunting B-19", short = "B-19", kind = "weapon", w = 4, h = 2, mass = 2.9, value = 14751, caliber = "9", weapon = "B19", family = "B19", desc = "9x19 submachine gun on a Kalashnikov-pattern receiver, with a side dovetail and a folding skeleton stock.", color = c("#303437") })
-- economy-1a, fourteenth slice (2026-11-09): EFT's Molot VPO-209, a hunting carbine on the AKM in .366 TKM (our 9.6x39).
-- The Tern T-209 takes the KS-7's magazines (family KST: EFT's AK 7.62x39 magazines, which take .366 TKM too, see
-- Items.MAG_CALIBERS) and fires 9.6x39 only (Items.fires). Value: EFT's handbook price (21,585, SPT's handbook.json); the
-- weight is the KS-7's (EFT gives the VPO-209 and the AKM the same 2.092 kg receiver, SPT 3.10.1 items.json)
add("T209_RIFLE", { name = "Tern T-209", short = "T-209", kind = "weapon", w = 5, h = 2, mass = 2.4, value = 21585, caliber = "9.6", weapon = "T209", family = "KST", desc = "Civilian hunting carbine on the KS-7's action in 9.6x39: a smooth bore rifled near the muzzle, wooden furniture, single shots only. Takes the KS-7's magazines loaded with 9.6x39.", color = c("#6A4A2E") })
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
-- economy-1a, third slice: EFT's 6L20 (30, plum polymer, 0.215 kg, 2,031), its 6L26 45-round magazine (3,765) and the PM's
-- 8-round magazine (940); handbook prices
add("KS74_MAG", { name = "KS-74 30-rd Magazine", short = "MAG 30", kind = "mag", w = 1, h = 2, mass = 0.215, value = 2031, capacity = 30, caliber = "5.4", family = "KS74", desc = "Plum polymer 30-round 5.4x39 magazine. The KS-7's will not fit.", color = c("#4A3530") })
add("KS74_MAG45", { name = "KS-74 45-rd Magazine", short = "MAG 45", kind = "mag", w = 1, h = 3, mass = 0.33, value = 3765, capacity = 45, caliber = "5.4", family = "KS74", rarity = "uncommon", desc = "Long 45-round magazine from the support-weapon variant.", color = c("#313537") })
add("SVD_MAG", { name = "MR-10 10-rd Magazine", short = "MAG 10", kind = "mag", w = 1, h = 1, mass = 0.22, value = 3750, capacity = 10, caliber = "7.6L", family = "SVD", desc = "Steel 10-round 7.6x54R magazine for the MR-10.", color = c("#2E3133") }) -- EFT's SVD 10-round magazine (3,750)
add("PM_MAG", { name = "PM 8-rd Magazine", short = "MAG 8", kind = "mag", w = 1, h = 1, mass = 0.093, value = 940, capacity = 8, caliber = "9.18", family = "PM", desc = "Single-stack 8-round magazine for the Makar PM.", color = c("#2F3233") })
-- economy-1a, fifth slice: EFT's M1A 10- and 20-round magazines (1,234 and 2,468) and the M700's 5- and 10-round
-- magazines (Wyatt's Outdoor, 1,850 and 3,500); handbook prices, weights ours
add("M1A_MAG", { name = "S-14 10-rd Magazine", short = "MAG 10", kind = "mag", w = 1, h = 1, mass = 0.16, value = 1234, capacity = 10, caliber = "7.6N", family = "M1A", desc = "Short steel 10-round 7.6x51 magazine for the S-14.", color = c("#2C2E2C") })
add("M1A_MAG20", { name = "S-14 20-rd Magazine", short = "MAG 20", kind = "mag", w = 1, h = 2, mass = 0.24, value = 2468, capacity = 20, caliber = "7.6N", family = "M1A", desc = "Steel 20-round 7.6x51 magazine for the S-14.", color = c("#2C2E2C") })
add("M700_MAG", { name = "OB-7 5-rd Magazine", short = "MAG 5", kind = "mag", w = 1, h = 1, mass = 0.12, value = 1850, capacity = 5, caliber = "7.6N", family = "M700", desc = "Flush 5-round 7.6x51 box magazine for the OB-7.", color = c("#262829") })
add("M700_MAG10", { name = "OB-7 10-rd Magazine", short = "MAG 10", kind = "mag", w = 1, h = 1, mass = 0.18, value = 3500, capacity = 10, caliber = "7.6N", family = "M700", rarity = "uncommon", desc = "Extended 10-round 7.6x51 box magazine for the OB-7.", color = c("#262829") })
-- economy-1a, sixth slice: EFT's VSS/VAL 6L24 10-round (4,637) and 6L25 20-round (5,999, plum) magazines; handbook prices,
-- weights ours
add("VSS_MAG10", { name = "SV-9 10-rd Magazine", short = "MAG 10", kind = "mag", w = 1, h = 1, mass = 0.12, value = 4637, capacity = 10, caliber = "9.39", family = "VSS", desc = "Steel 10-round 9x39 magazine for the SV-9 and the AV-9.", color = c("#2B2D2E") })
add("VSS_MAG20", { name = "SV-9 20-rd Magazine", short = "MAG 20", kind = "mag", w = 1, h = 2, mass = 0.17, value = 5999, capacity = 20, caliber = "9.39", family = "VSS", rarity = "uncommon", desc = "Plum polymer 20-round 9x39 magazine for the SV-9 and the AV-9.", color = c("#5A3A34") })
-- economy-1a, seventh slice: EFT's MP7 20-, 30- and 40-round magazines (4,026, 6,001, 12,142) and the P90's 50-round one
-- (10,500); handbook prices, weights ours
add("MP7_MAG20", { name = "PW-46 20-rd Magazine", short = "MAG 20", kind = "mag", w = 1, h = 1, mass = 0.1, value = 4026, capacity = 20, caliber = "4.6", family = "MP7", desc = "Short 20-round 4.6x30 magazine for the PW-46.", color = c("#1E1F20") })
add("MP7_MAG30", { name = "PW-46 30-rd Magazine", short = "MAG 30", kind = "mag", w = 1, h = 2, mass = 0.13, value = 6001, capacity = 30, caliber = "4.6", family = "MP7", desc = "30-round 4.6x30 magazine for the PW-46.", color = c("#1E1F20") })
add("MP7_MAG40", { name = "PW-46 40-rd Magazine", short = "MAG 40", kind = "mag", w = 1, h = 2, mass = 0.16, value = 12142, capacity = 40, caliber = "4.6", family = "MP7", rarity = "rare", desc = "Long 40-round 4.6x30 magazine for the PW-46.", color = c("#1E1F20") })
add("P90_MAG", { name = "PD-57 50-rd Magazine", short = "MAG 50", kind = "mag", w = 2, h = 1, mass = 0.2, value = 10500, capacity = 50, caliber = "5.7", family = "P90", rarity = "uncommon", desc = "Smoky polymer 50-round 5.7x28 magazine that lies on top of the PD-57.", color = c("#4A4D4F") })
-- economy-1a, eighth slice: EFT's UMP 45 25-round (2,300), M1911A1 7-round (1,100) and Mec-Gar 11-round (2,100) and
-- Five-seveN 20-round (3,660) magazines; handbook prices, weights ours
add("UMP_MAG", { name = "HS-45 25-rd Magazine", short = "MAG 25", kind = "mag", w = 1, h = 2, mass = 0.18, value = 2300, capacity = 25, caliber = "11.4", family = "UMP", desc = "Straight polymer 25-round 11.4x23 magazine for the HS-45.", color = c("#1E1F20") })
add("M1911_MAG", { name = "L-11 7-rd Magazine", short = "MAG 7", kind = "mag", w = 1, h = 1, mass = 0.07, value = 1100, capacity = 7, caliber = "11.4", family = "M1911", desc = "Single-stack steel 7-round 11.4x23 magazine for the L-11.", color = c("#2E3032") })
add("M1911_MAG11", { name = "L-11 11-rd Magazine", short = "MAG 11", kind = "mag", w = 1, h = 1, mass = 0.1, value = 2100, capacity = 11, caliber = "11.4", family = "M1911", rarity = "uncommon", desc = "Extended 11-round 11.4x23 magazine for the L-11.", color = c("#2E3032") })
add("FN57_MAG", { name = "F-57 20-rd Magazine", short = "MAG 20", kind = "mag", w = 1, h = 1, mass = 0.06, value = 3660, capacity = 20, caliber = "5.7", family = "FN57", desc = "Polymer 20-round 5.7x28 magazine for the F-57.", color = c("#1C1D1E") })
-- economy-1a, ninth slice: EFT's TT 8-round (1,157), PPSh-41 35-round (2,631) and 71-round drum (16,000) magazines;
-- handbook prices, weights ours
add("TT_MAG", { name = "P-33 8-rd Magazine", short = "MAG 8", kind = "mag", w = 1, h = 1, mass = 0.07, value = 1157, capacity = 8, caliber = "7.6T", family = "TT", desc = "Single-stack 8-round 7.6x25 magazine for the P-33.", color = c("#2E3133") })
add("PPSH_MAG35", { name = "G-41 35-rd Magazine", short = "MAG 35", kind = "mag", w = 1, h = 2, mass = 0.23, value = 2631, capacity = 35, caliber = "7.6T", family = "PPSH", desc = "Curved 35-round 7.6x25 magazine for the G-41.", color = c("#2B2E30") })
add("PPSH_DRUM", { name = "G-41 71-rd Drum", short = "DRUM 71", kind = "mag", w = 2, h = 2, mass = 1.8, value = 16000, capacity = 71, caliber = "7.6T", family = "PPSH", rarity = "rare", desc = "71-round 7.6x25 drum for the G-41. Heavy and slow to load.", color = c("#2D3032") })
-- economy-1a, tenth slice: EFT's SR-1MP 18-round (1,506), SR-2M 20- and 30-round (2,900 and 3,500) and VPO-215 4-round
-- (1,200) magazines; handbook prices, weights ours
add("W21_MAG", { name = "W-21 18-rd Magazine", short = "MAG 18", kind = "mag", w = 1, h = 1, mass = 0.12, value = 1506, capacity = 18, caliber = "9.21", family = "W21", desc = "Double-stack 18-round 9x21 magazine for the W-21.", color = c("#2D3032") })
add("J21_MAG20", { name = "J-21 20-rd Magazine", short = "MAG 20", kind = "mag", w = 1, h = 2, mass = 0.12, value = 2900, capacity = 20, caliber = "9.21", family = "J21", desc = "Short 20-round 9x21 magazine for the J-21.", color = c("#2B2E30") })
add("J21_MAG30", { name = "J-21 30-rd Magazine", short = "MAG 30", kind = "mag", w = 1, h = 2, mass = 0.15, value = 3500, capacity = 30, caliber = "9.21", family = "J21", desc = "30-round 9x21 magazine for the J-21.", color = c("#2B2E30") })
add("T215_MAG", { name = "T-215 4-rd Magazine", short = "MAG 4", kind = "mag", w = 1, h = 1, mass = 0.1, value = 1200, capacity = 4, caliber = "9.6", family = "T215", desc = "Detachable 4-round 9.6x39 box magazine for the T-215.", color = c("#2E3236") })
-- economy-1a, twelfth slice: EFT's Glock 17-round (1,476), MPX 20- and 30-round (1,450, 2,073) and Vityaz 30-round
-- (2,422) magazines; handbook prices, weights ours
add("D17_MAG", { name = "D-17 17-rd Magazine", short = "MAG 17", kind = "mag", w = 1, h = 1, mass = 0.08, value = 1476, capacity = 17, caliber = "9", family = "D17", desc = "Polymer 17-round 9x19 magazine for the D-17.", color = c("#2A2C2D") })
add("AV9_MAG20", { name = "AV-9 20-rd Magazine", short = "MAG 20", kind = "mag", w = 1, h = 1, mass = 0.1, value = 1450, capacity = 20, caliber = "9", family = "AV9", desc = "Short 20-round 9x19 magazine for the AV-9.", color = c("#2B2E30") })
add("AV9_MAG30", { name = "AV-9 30-rd Magazine", short = "MAG 30", kind = "mag", w = 1, h = 2, mass = 0.13, value = 2073, capacity = 30, caliber = "9", family = "AV9", desc = "30-round 9x19 magazine for the AV-9.", color = c("#2B2E30") })
add("B19_MAG", { name = "B-19 30-rd Magazine", short = "MAG 30", kind = "mag", w = 1, h = 2, mass = 0.18, value = 2422, capacity = 30, caliber = "9", family = "B19", desc = "Polymer 30-round 9x19 magazine for the B-19.", color = c("#2A2B2C") })
-- economy-1a, fourteenth slice: EFT's AK 7.62x39 aluminium 10-round magazine, the VPO-209's default (0.12 kg, 1 x 2 in
-- EFT's grid, handbook 700; SPT 3.10.1). Like every KS-7 magazine it takes 7.6x39 or 9.6x39 (Items.MAG_CALIBERS)
add("KST_MAG10", { name = "KS-7 10-rd Magazine", short = "MAG 10", kind = "mag", w = 1, h = 2, mass = 0.12, value = 700, capacity = 10, caliber = "7.6", family = "KST", desc = "Short aluminium 10-round magazine for the KS-7 family. Light and quick to load; takes 7.6x39 or 9.6x39.", color = c("#7E827E") })

-- ── ammunition ────────────────────────────────────────────────────────────────
local function ammo(id: string, name: string, short: string, caliber: string, stack: number, value: number, a: any, rarity: string?, desc: string?)
	add(id, { name = name, short = short, kind = "ammo", w = 1, h = 1, mass = 0.012, stack = stack, value = value, caliber = caliber, ammo = a, rarity = rarity, desc = desc or "", color = c("#A08A5C") })
end
-- Rounds (decision economy-1a, the catalogue's first slice, 2026-11-08): six of EFT's loads for each of our five gun
-- calibres, each copying one EFT round (named in its comment) for damage, penetration, armour damage, fragmentation,
-- muzzle velocity (speed, m/s: Ballistics.muzzle scales the gun's velocity by it against the calibre's reference
-- round), and the recoil and accuracy modifiers (recoil +0.08 = EFT's +8 %; acc -0.07 = -7 %). Sources: the EFT wiki's
-- round and 12/70 pages, tarkovforge.com/ammo/<round> and xgamingserver.com item pages (read 2026-11-08). EFT gives
-- bleeding as changes to a base chance; the base chances per calibre are ours, EFT's changes added on top. Values (MK)
-- are EFT's base prices in roubles where a page gave one; estimated from the trader price (about x0.7) where marked ~.
-- 6.2x40 (EFT's 5.56x45 NATO): FMJ, HP, M855, M856A1, M855A1, M995
ammo("A62_FMJ", "6.2x40 FMJ", "6.2 FMJ", "6.2", 60, 120, { dmg = 57, pen = 23, armorDmg = 0.33, bleedL = 0.12, bleedH = 0.06, frag = 0.5, speed = 957 }, nil, "General purpose full metal jacket.")
ammo("A62_HP", "6.2x40 HP", "6.2 HP", "6.2", 60, 90, { dmg = 79, pen = 7, armorDmg = 0.22, bleedL = 0.27, bleedH = 0.21, frag = 0.5, speed = 947 }, nil, "Hollow point. Brutal on flesh, useless on plates.") -- frag: ours (not published)
ammo("A62_SS", "6.2x40 SS", "6.2 SS", "6.2", 60, 240, { dmg = 54, pen = 31, armorDmg = 0.37, bleedL = 0.12, bleedH = 0.06, frag = 0.5, speed = 922 }, nil, "Standard steel-core penetrator load.") -- M855; value ~
ammo("A62_TR", "6.2x40 TR", "6.2 TR", "6.2", 60, 740, { dmg = 52, pen = 38, armorDmg = 0.44, bleedL = 0.12, bleedH = 0.06, frag = 0.43, speed = 940, recoil = 0.04, acc = -0.04, tracer = "red" }, "uncommon", "Penetrator with a red tracer.") -- M856A1; value ~
ammo("A62_EP", "6.2x40 EP", "6.2 EP", "6.2", 60, 950, { dmg = 49, pen = 44, armorDmg = 0.47, bleedL = 0.1, bleedH = 0.05, frag = 0.44, speed = 945, recoil = 0.05, acc = -0.05 }, "rare", "Enhanced penetrator with a hardened steel tip.") -- M855A1; value ours
ammo("A62_AP", "6.2x40 AP", "6.2 AP", "6.2", 60, 1200, { dmg = 42, pen = 53, armorDmg = 0.52, bleedL = 0.1, bleedH = 0.05, frag = 0.42, speed = 1013, recoil = 0.08, acc = -0.07 }, "rare", "Tungsten-core armour piercer. Defeats class 5 plates.") -- M995; value ours
-- 7.6x39 (EFT's 7.62x39): HP, FMJ, US, T-45M1, PS, PP, BP
ammo("A76_HP", "7.6x39 HP", "7.6 HP", "7.6", 60, 70, { dmg = 80, pen = 15, armorDmg = 0.2, bleedL = 0.2, bleedH = 0.12, frag = 0.4, speed = 754 }, nil, "Hollow point. Hits hard, stops at the first plate.")
-- FMJ (economy-1a's thirteenth slice): tarkovforge.com/ammo/762x39mm-fmj (read 2026-11-08: 63 damage, 26 penetration, 33 %
-- armour damage, 30 % fragmentation, 775 m/s, recoil -2 %, accuracy +2 %, no bleeding change); the value is EFT's handbook
-- price (SPT's handbook.json, 140)
ammo("A76_FMJ", "7.6x39 FMJ", "7.6 FMJ", "7.6", 60, 140, { dmg = 63, pen = 26, armorDmg = 0.33, bleedL = 0.15, bleedH = 0.08, frag = 0.3, speed = 775, recoil = -0.02, acc = 0.02 }, nil, "Plain full metal jacket in a lacquered steel case. Cheap practice ammunition, still a rifle round.")
ammo("A76_US", "7.6x39 US", "7.6 US", "7.6", 60, 220, { dmg = 56, pen = 29, armorDmg = 0.42, bleedL = 0.15, bleedH = 0.08, frag = 0.1, speed = 301, recoil = -0.3, acc = 0.05, subsonic = true }, "uncommon", "Subsonic heavy bullet. Quiet with a suppressor.") -- frag: ours
ammo("A76_TR", "7.6x39 TR", "7.6 TR", "7.6", 60, 230, { dmg = 65, pen = 30, armorDmg = 0.46, bleedL = 0.15, bleedH = 0.08, frag = 0.17, speed = 720, recoil = -0.06, acc = -0.04, tracer = "red" }, nil, "Steel-core load with a red tracer.") -- T-45M1; frag ours, value ~
ammo("A76_PS", "7.6x39 PS", "7.6 PS", "7.6", 60, 240, { dmg = 61, pen = 35, armorDmg = 0.52, bleedL = 0.15, bleedH = 0.08, frag = 0.2, speed = 717 }, nil, "Mild steel core 7.6x39.")
ammo("A76_PP", "7.6x39 PP", "7.6 PP", "7.6", 60, 900, { dmg = 59, pen = 41, armorDmg = 0.57, bleedL = 0.13, bleedH = 0.07, frag = 0.15, speed = 732, recoil = 0.05, acc = -0.01 }, "uncommon", "Improved penetration steel core.") -- value ~
ammo("A76_BP", "7.6x39 BP", "7.6 BP", "7.6", 60, 1111, { dmg = 58, pen = 47, armorDmg = 0.63, bleedL = 0.12, bleedH = 0.07, frag = 0.12, speed = 730 }, "rare", "Armor-piercing 7.6x39.")
-- 9x19: FMJ M882, Pst gzh, Green Tracer, AP 6.3, PBP gzh, RIP
ammo("A9_FMJ", "9x19 FMJ", "9 FMJ", "9", 50, 120, { dmg = 56, pen = 18, armorDmg = 0.35, bleedL = 0.12, bleedH = 0.05, frag = 0.2, speed = 385 }, nil, "Plain full metal jacket.") -- M882
ammo("A9_PST", "9x19 PST", "9 PST", "9", 50, 80, { dmg = 54, pen = 20, armorDmg = 0.33, bleedL = 0.12, bleedH = 0.05, frag = 0.15, speed = 457 }, nil, "Steel-core 9x19.")
ammo("A9_TR", "9x19 TR", "9 TR", "9", 50, 70, { dmg = 58, pen = 14, armorDmg = 0.33, bleedL = 0.12, bleedH = 0.05, frag = 0.15, speed = 365, recoil = -0.06, acc = -0.05, tracer = "green" }, nil, "Light load with a green tracer.") -- Green Tracer; frag ours, value ~
ammo("A9_AP", "9x19 AP", "9 AP", "9", 50, 210, { dmg = 52, pen = 30, armorDmg = 0.48, bleedL = 0.1, bleedH = 0.05, frag = 0.05, speed = 392 }, "uncommon", "Penetrator 9x19.") -- AP 6.3
ammo("A9_PBP", "9x19 PBP", "9 PBP", "9", 50, 900, { dmg = 44, pen = 39, armorDmg = 0.55, bleedL = 0.1, bleedH = 0.05, frag = 0.05, speed = 560, recoil = 0.05, acc = 0.05 }, "rare", "Hot armour-piercing load with a hardened core.") -- PBP gzh; value ~
ammo("A9_RIP", "9x19 FHP", "9 FHP", "9", 50, 422, { dmg = 102, pen = 2, armorDmg = 0.11, bleedL = 0.42, bleedH = 0.3, frag = 1, speed = 381, recoil = 0.2 }, "uncommon", "Fragmenting hollow point.") -- RIP (renamed: a maker's name)
-- 5.4x39 (EFT's 5.45x39; economy-1a, third slice): HP, US gs, T gs, PS gs, BT gs, BP gs, BS gs. Damage, penetration,
-- armour damage, fragmentation, speed and the recoil and accuracy modifiers from tarkovforge.com/ammo/545x39mm-<round>
-- (read 2026-11-08); values are EFT's handbook prices (SPT's handbook.json); bleeding as for the 6.2
ammo("A54_HP", "5.4x39 HP", "5.4 HP", "5.4", 60, 50, { dmg = 76, pen = 9, armorDmg = 0.15, bleedL = 0.27, bleedH = 0.21, frag = 0.35, speed = 884, recoil = -0.03, acc = 0.03 }, nil, "Hollow point. Tears flesh, stops at the first plate.")
ammo("A54_US", "5.4x39 US", "5.4 US", "5.4", 60, 88, { dmg = 65, pen = 17, armorDmg = 0.33, bleedL = 0.12, bleedH = 0.06, frag = 0.1, speed = 303, recoil = -0.15, subsonic = true }, nil, "Subsonic heavy bullet. Quiet behind a suppressor, slow and loopy beyond 100 m.")
ammo("A54_T", "5.4x39 T", "5.4 T", "5.4", 60, 90, { dmg = 59, pen = 20, armorDmg = 0.36, bleedL = 0.12, bleedH = 0.06, frag = 0.16, speed = 883, acc = -0.03, tracer = "red" }, nil, "Steel-core load with a red tracer.")
ammo("A54_PS", "5.4x39 PS", "5.4 PS", "5.4", 60, 140, { dmg = 56, pen = 28, armorDmg = 0.4, bleedL = 0.12, bleedH = 0.06, frag = 0.4, speed = 890 }, nil, "Standard steel-core service load.")
ammo("A54_BT", "5.4x39 BT", "5.4 BT", "5.4", 60, 540, { dmg = 54, pen = 37, armorDmg = 0.44, bleedL = 0.1, bleedH = 0.05, frag = 0.16, speed = 880, recoil = 0.05, acc = -0.04, tracer = "red" }, "uncommon", "Armour-piercing tracer.")
ammo("A54_BP", "5.4x39 BP", "5.4 BP", "5.4", 60, 630, { dmg = 48, pen = 45, armorDmg = 0.46, bleedL = 0.1, bleedH = 0.05, frag = 0.16, speed = 890, recoil = 0.07, acc = -0.03 }, "rare", "Hardened steel-core armour piercer.")
ammo("A54_BS", "5.4x39 BS", "5.4 BS", "5.4", 60, 780, { dmg = 45, pen = 54, armorDmg = 0.57, bleedL = 0.1, bleedH = 0.05, frag = 0.17, speed = 830, recoil = 0.1, acc = -0.04 }, "rare", "Tungsten-carbide core. Defeats class 5 plates.")
-- 9x18 (EFT's 9x18 PM): P gzh, PSV, PPT gzh, Pst gzh, RG028 gzh, PBM gzh (tarkovforge.com/ammo/9x18mm-pm-<round>,
-- read 2026-11-08; handbook prices)
ammo("A918_P", "9x18 P", "9x18 P", "9.18", 50, 12, { dmg = 50, pen = 5, armorDmg = 0.16, bleedL = 0.22, bleedH = 0.05, frag = 0.25, speed = 302 }, nil, "Plain lead-core pistol round.")
ammo("A918_PSV", "9x18 PSV", "9x18 PSV", "9.18", 50, 73, { dmg = 69, pen = 3, armorDmg = 0.05, bleedL = 0.22, bleedH = 0.05, frag = 0.4, speed = 280 }, nil, "Soft expanding bullet. Hurts badly, does nothing to armour.")
ammo("A918_PPT", "9x18 PPT", "9x18 PPT", "9.18", 50, 43, { dmg = 59, pen = 8, armorDmg = 0.22, bleedL = 0.27, bleedH = 0.05, frag = 0.17, speed = 301, recoil = -0.07, acc = -0.05, tracer = "red" }, nil, "Light load with a red tracer.")
ammo("A918_PST", "9x18 Pst", "9x18 PST", "9.18", 50, 45, { dmg = 50, pen = 12, armorDmg = 0.26, bleedL = 0.12, bleedH = 0.05, frag = 0.2, speed = 298 }, nil, "Steel-core 9x18.")
ammo("A918_RG", "9x18 RG", "9x18 RG", "9.18", 50, 86, { dmg = 65, pen = 13, armorDmg = 0.26, bleedL = 0.12, bleedH = 0.05, frag = 0.02, speed = 330 }, nil, "Heavier hot load with a hardened core.") -- RG028 gzh
ammo("A918_PBM", "9x18 PBM", "9x18 PBM", "9.18", 50, 121, { dmg = 40, pen = 28, armorDmg = 0.3, bleedL = 0.1, bleedH = 0.05, frag = 0.16, speed = 519, recoil = 0.04 }, "uncommon", "Armour-piercing bimetal load, very fast for a pistol round.")
-- the GL-6's round (ai-5b), after EFT's 40x46 M406 (HE): 76 m/s, armed after 0.26 s of flight, an explosion of 1 to
-- 7 m (the wiki's 40x46mm page); the fragments, blast and their reach are in our grenade model (Grenades.luau)
add("A40_HE", { name = "40x46 HE Grenade", short = "40 HE", kind = "ammo", w = 1, h = 1, mass = 0.23, stack = 1, value = 9000, caliber = "40", rarity = "rare",
	ammo = { dmg = 199, pen = 1, armorDmg = 0.95, bleedL = 0, bleedH = 0, frag = 0, subsonic = true },
	nade = { type = "frag", impact = true, arm = 0.26, flight = 10, fuse = 10, frags = 120, fragR = 22, fragDmg = { 24, 38 }, fragPen = { 10, 17 }, blastR = 6, blastDmg = 120 },
	desc = "High-explosive 40x46 grenade for the GL-6. It arms after about 20 m of flight and goes off where it strikes.", color = c("#4F5539") })
-- 12/70: 7mm buckshot, 8.5mm "Magnum" buckshot, flechette, lead slug, Poleva-6u, AP-20 (pellets x damage)
ammo("A12_BUCK", "12/70 Buckshot", "12 BUCK", "12", 20, 90, { dmg = 39, pen = 3, armorDmg = 0.26, pellets = 8, bleedL = 0.25, bleedH = 0.1, frag = 0, speed = 415 }, nil, "Eight 7 mm pellets per shell.")
ammo("A12_MAG", "12/70 Magnum Buckshot", "12 MAG", "12", 20, 175, { dmg = 50, pen = 2, armorDmg = 0.26, pellets = 8, bleedL = 0.45, bleedH = 0.1, frag = 0, speed = 385, recoil = 1.15, acc = -0.15 }, "uncommon", "Eight heavy 8.5 mm pellets on a stout charge. Kicks like a mule.") -- value ~
ammo("A12_FLECH", "12/70 Flechette", "12 FLE", "12", 20, 400, { dmg = 25, pen = 31, armorDmg = 0.26, pellets = 8, bleedL = 0.5, bleedH = 0.1, frag = 0, speed = 320, recoil = 0.25, acc = -0.1 }, "rare", "Eight steel darts. Goes through soft armour.") -- value ours
ammo("A12_SLUG", "12/70 Slug", "12 SLUG", "12", 20, 380, { dmg = 167, pen = 15, armorDmg = 0.55, bleedL = 0.3, bleedH = 0.2, frag = 0, speed = 370, recoil = 0.1 }, "uncommon", "Single heavy lead slug.")
ammo("A12_SABOT", "12/70 Sabot Slug", "12 SAB", "12", 20, 300, { dmg = 150, pen = 20, armorDmg = 0.5, bleedL = 0.2, bleedH = 0.2, frag = 0, speed = 430, recoil = -0.1 }, "uncommon", "Finned slug in a plastic wad. Flies flatter than lead.") -- Poleva-6u; value ours
ammo("A12_APS", "12/70 AP Slug", "12 APS", "12", 20, 1500, { dmg = 164, pen = 37, armorDmg = 0.65, bleedL = 0.25, bleedH = 0.2, frag = 0, speed = 510, recoil = 0.5 }, "rare", "Hardened armour-piercing slug.") -- AP-20; value ours
-- 7.6x54R (EFT's 7.62x54R): FMJ, LPS gzh, T-46M gzh, PS gzh, BT gzh, SNB gzh, BS gs
-- FMJ (economy-1a's thirteenth slice): tarkovforge.com/ammo/762x54mm-r-fmj (read 2026-11-08: 84 damage, 36 penetration,
-- 63 % armour damage, 20 % fragmentation, 760 m/s, no recoil, accuracy or bleeding change); value EFT's handbook price (270)
ammo("A76L_FMJ", "7.6x54R FMJ", "7.6L FMJ", "7.6L", 40, 270, { dmg = 84, pen = 36, armorDmg = 0.63, bleedL = 0.2, bleedH = 0.15, frag = 0.2, speed = 760 }, nil, "Plain full metal jacket with a lead core. Training ammunition with the full-power cartridge's punch.")
ammo("A76L_LPS", "7.6x54R LPS", "7.6L LPS", "7.6L", 40, 490, { dmg = 81, pen = 42, armorDmg = 0.78, bleedL = 0.2, bleedH = 0.15, frag = 0.18, speed = 865, acc = -0.05 }, "uncommon", "Full-power rifle cartridge.")
ammo("A76L_TR", "7.6x54R TR", "7.6L TR", "7.6L", 40, 356, { dmg = 82, pen = 41, armorDmg = 0.83, bleedL = 0.2, bleedH = 0.15, frag = 0.18, speed = 800, tracer = "red" }, "uncommon", "Full-power load with a red tracer.") -- T-46M
ammo("A76L_PS", "7.6x54R PS", "7.6L PS", "7.6L", 40, 920, { dmg = 84, pen = 45, armorDmg = 0.84, bleedL = 0.2, bleedH = 0.15, frag = 0.08, speed = 875 }, "uncommon", "Steel-core rifle cartridge.")
ammo("A76L_BT", "7.6x54R BT", "7.6L BT", "7.6L", 40, 1180, { dmg = 78, pen = 55, armorDmg = 0.87, bleedL = 0.18, bleedH = 0.12, frag = 0.08, speed = 875 }, "rare", "Armour-piercing core with a tracer base.")
ammo("A76L_SNB", "7.6x54R SNB", "7.6L SNB", "7.6L", 40, 1600, { dmg = 75, pen = 62, armorDmg = 0.87, bleedL = 0.15, bleedH = 0.12, frag = 0.08, speed = 875, recoil = 0.1 }, "rare", "Sniper armor-piercing load.")
ammo("A76L_BS", "7.6x54R BS", "7.6L BS", "7.6L", 40, 2500, { dmg = 72, pen = 70, armorDmg = 0.88, bleedL = 0.15, bleedH = 0.1, frag = 0.05, speed = 785 }, "rare", "Tungsten-carbide core. Nothing worn stops it.") -- BS gs; frag and value ours
-- 7.6x51 (EFT's 7.62x51 NATO; economy-1a, fifth slice): Ultra Nosler, TCW SP, BCP FMJ, M62 Tracer, M80, M80A1, M61, M993.
-- Damage, penetration, armour damage, fragmentation, speed and the recoil and accuracy modifiers from
-- tarkovforge.com/ammo/762x51mm-<round> (read 2026-11-08); values are EFT's handbook prices (SPT's handbook.json). EFT
-- gives bleeding as changes (+5 % on M993 to +20 % on Ultra Nosler); ours adds them to a base of 0.10 light and 0.05 heavy
ammo("A76N_HP", "7.6x51 HP", "7.6N HP", "7.6N", 40, 105, { dmg = 105, pen = 15, armorDmg = 0.4, bleedL = 0.3, bleedH = 0.25, frag = 0.7, speed = 800, recoil = -0.05, acc = 0.35 }, nil, "Polymer-tipped hunting bullet. Tears flesh apart, stopped by any plate.") -- Ultra Nosler
ammo("A76N_SP", "7.6x51 SP", "7.6N SP", "7.6N", 40, 170, { dmg = 85, pen = 30, armorDmg = 0.25, bleedL = 0.25, bleedH = 0.2, frag = 0.35, speed = 800, recoil = -0.03, acc = 0.2 }, nil, "Soft point in a steel case. Good on flesh, poor on armour.") -- TCW SP
ammo("A76N_FMJ", "7.6x51 FMJ", "7.6N FMJ", "7.6N", 40, 240, { dmg = 83, pen = 37, armorDmg = 0.56, bleedL = 0.22, bleedH = 0.17, frag = 0.2, speed = 840 }, nil, "Commercial full metal jacket in a steel case.") -- BCP FMJ
ammo("A76N_TR", "7.6x51 TR", "7.6N TR", "7.6N", 40, 600, { dmg = 82, pen = 42, armorDmg = 0.65, bleedL = 0.2, bleedH = 0.15, frag = 0.14, speed = 820, recoil = 0.01, acc = -0.1, tracer = "red" }, "uncommon", "Service load with an orange-tipped tracer.") -- M62 Tracer
ammo("A76N_BALL", "7.6x51 Ball", "7.6N BALL", "7.6N", 40, 420, { dmg = 80, pen = 43, armorDmg = 0.67, bleedL = 0.18, bleedH = 0.13, frag = 0.17, speed = 820, recoil = 0.01, acc = -0.13 }, nil, "Standard service ball round.") -- M80
ammo("A76N_EP", "7.6x51 EP", "7.6N EP", "7.6N", 40, 1200, { dmg = 75, pen = 55, armorDmg = 0.74, bleedL = 0.17, bleedH = 0.12, frag = 0.13, speed = 929, recoil = 0.04, acc = -0.05 }, "rare", "Enhanced service round with an exposed steel penetrator.") -- M80A1
ammo("A76N_AP", "7.6x51 AP", "7.6N AP", "7.6N", 40, 1240, { dmg = 73, pen = 60, armorDmg = 0.79, bleedL = 0.16, bleedH = 0.11, frag = 0.14, speed = 833, recoil = 0.03, acc = 0.05 }, "rare", "Black-tipped armour piercer with a hardened steel core.") -- M61
ammo("A76N_TC", "7.6x51 TC", "7.6N TC", "7.6N", 40, 1723, { dmg = 70, pen = 65, armorDmg = 0.85, bleedL = 0.15, bleedH = 0.1, frag = 0.13, speed = 930, recoil = 0.06, acc = 0.15 }, "rare", "Tungsten-carbide core. Goes through class 6 plates.") -- M993
-- 9x39 (EFT's 9x39; economy-1a, sixth slice): FMJ, SP-5 gs, SPP gs, PAB-9 gs, SP-6 gs, BP gs, all subsonic. Damage,
-- penetration, armour damage, fragmentation, speed and the recoil and accuracy modifiers from
-- tarkovforge.com/ammo/9x39mm-<round> (read 2026-11-08); values are EFT's handbook prices; bleeding as for the 6.2
ammo("A939_FMJ", "9x39 FMJ", "9x39 FMJ", "9.39", 50, 140, { dmg = 75, pen = 17, armorDmg = 0.28, bleedL = 0.12, bleedH = 0.06, frag = 0.3, speed = 330, recoil = -0.05, acc = 0.05, subsonic = true }, nil, "Plain full metal jacket. Heavy, slow and quiet.")
ammo("A939_SP5", "9x39 SP-5", "9x39 SP-5", "9.39", 50, 220, { dmg = 71, pen = 28, armorDmg = 0.39, bleedL = 0.12, bleedH = 0.16, frag = 0.2, speed = 290, subsonic = true }, nil, "Subsonic sniper load.")
ammo("A939_SPP", "9x39 SPP", "9x39 SPP", "9.39", 50, 440, { dmg = 68, pen = 35, armorDmg = 0.48, bleedL = 0.22, bleedH = 0.26, frag = 0.2, speed = 310, recoil = 0.07, acc = 0.1, subsonic = true }, "uncommon", "Improved sniper load with a steel core.")
ammo("A939_PAB", "9x39 PAB-9", "9x39 PAB-9", "9.39", 50, 670, { dmg = 62, pen = 43, armorDmg = 0.57, bleedL = 0.22, bleedH = 0.18, frag = 0.1, speed = 320, recoil = 0.1, acc = -0.15, subsonic = true }, "uncommon", "Armour-piercing load made for export.")
ammo("A939_SP6", "9x39 SP-6", "9x39 SP-6", "9.39", 50, 920, { dmg = 60, pen = 48, armorDmg = 0.64, bleedL = 0.22, bleedH = 0.16, frag = 0.1, speed = 305, recoil = 0.05, subsonic = true }, "rare", "Black-tipped armour piercer with a hardened core.")
ammo("A939_BP", "9x39 BP", "9x39 BP", "9.39", 50, 1300, { dmg = 58, pen = 54, armorDmg = 0.69, bleedL = 0.12, bleedH = 0.06, frag = 0.1, speed = 295, recoil = 0.15, acc = 0.1, subsonic = true }, "rare", "Hardened steel-core piercer. Defeats class 5 plates.")
-- 4.6x30 and 5.7x28 (EFT's 4.6x30 and 5.7x28; economy-1a, seventh slice): Action SX, Subsonic SX, JSP SX, FMJ SX, AP SX;
-- R37.F, R37.X, SS198LF, SS197SR, SB193, L191, SS190. Figures from tarkovforge.com/ammo/<round> (read 2026-11-08), values
-- EFT's handbook prices; bleeding as for the 6.2, with EFT's +20 % and +10 % on R37.F and R37.X
ammo("A46_HP", "4.6x30 HP", "4.6 HP", "4.6", 60, 70, { dmg = 65, pen = 18, armorDmg = 0.28, bleedL = 0.12, bleedH = 0.06, frag = 0.5, speed = 690 }, nil, "Expanding hollow point. Hurts flesh, stopped by plates.") -- Action SX
ammo("A46_SUB", "4.6x30 Subsonic", "4.6 SUB", "4.6", 60, 100, { dmg = 52, pen = 23, armorDmg = 0.33, bleedL = 0.12, bleedH = 0.06, frag = 0.2, speed = 290, recoil = -0.22, acc = 0.1, subsonic = true }, nil, "Subsonic load for suppressed fire.") -- Subsonic SX
ammo("A46_JSP", "4.6x30 JSP", "4.6 JSP", "4.6", 60, 280, { dmg = 46, pen = 32, armorDmg = 0.37, bleedL = 0.12, bleedH = 0.06, frag = 0.3, speed = 579 }, nil, "Jacketed soft point.") -- JSP SX
ammo("A46_FMJ", "4.6x30 FMJ", "4.6 FMJ", "4.6", 60, 425, { dmg = 43, pen = 40, armorDmg = 0.41, bleedL = 0.12, bleedH = 0.06, frag = 0.2, speed = 620 }, "uncommon", "Full metal jacket with a steel core. Goes through class 3 and 4.") -- FMJ SX
ammo("A46_AP", "4.6x30 AP", "4.6 AP", "4.6", 60, 745, { dmg = 35, pen = 53, armorDmg = 0.46, bleedL = 0.12, bleedH = 0.06, frag = 0.1, speed = 680, recoil = 0.1 }, "rare", "Hardened steel penetrator. Defeats class 5 plates.") -- AP SX
ammo("A57_FX", "5.7x28 FX", "5.7 FX", "5.7", 60, 335, { dmg = 98, pen = 8, armorDmg = 0.07, bleedL = 0.32, bleedH = 0.26, frag = 1, speed = 729 }, nil, "Fragmenting hunting bullet. Devastating on flesh, useless on armour.") -- R37.F
ammo("A57_EX", "5.7x28 EX", "5.7 EX", "5.7", 60, 220, { dmg = 81, pen = 11, armorDmg = 0.09, bleedL = 0.22, bleedH = 0.16, frag = 0.7, speed = 724, acc = -0.05 }, nil, "Expanding hunting bullet.") -- R37.X
ammo("A57_LF", "5.7x28 LF", "5.7 LF", "5.7", 60, 80, { dmg = 70, pen = 17, armorDmg = 0.19, bleedL = 0.12, bleedH = 0.06, frag = 0.8, speed = 792 }, nil, "Lead-free hollow point.") -- SS198LF
ammo("A57_SR", "5.7x28 SR", "5.7 SR", "5.7", 60, 150, { dmg = 62, pen = 25, armorDmg = 0.22, bleedL = 0.12, bleedH = 0.06, frag = 0.5, speed = 594, acc = 0.1 }, nil, "Sporting round with a polymer tip.") -- SS197SR
ammo("A57_SUB", "5.7x28 Subsonic", "5.7 SUB", "5.7", 60, 270, { dmg = 59, pen = 27, armorDmg = 0.37, bleedL = 0.12, bleedH = 0.06, frag = 0.35, speed = 299, recoil = -0.15, acc = 0.05, subsonic = true }, nil, "Subsonic load for suppressed fire.") -- SB193
ammo("A57_TR", "5.7x28 TR", "5.7 TR", "5.7", 60, 310, { dmg = 53, pen = 33, armorDmg = 0.41, bleedL = 0.12, bleedH = 0.06, frag = 0.2, speed = 715, acc = -0.04, tracer = "red" }, "uncommon", "Duty load with an orange-tipped tracer.") -- L191
ammo("A57_SS", "5.7x28 SS", "5.7 SS", "5.7", 60, 460, { dmg = 49, pen = 37, armorDmg = 0.43, bleedL = 0.12, bleedH = 0.06, frag = 0.2, speed = 715 }, "uncommon", "Duty round with a steel core. Goes through class 3 and 4.") -- SS190
-- 11.4x23 (EFT's .45 ACP; economy-1a, eighth slice): RIP, Hydra-Shok, Lasermatch FMJ, Match FMJ, AP, all subsonic.
-- Figures from tarkovforge.com/ammo/45-acp-<round> (read 2026-11-08), values EFT's handbook prices; bleeding as for the 6.2
-- with EFT's changes (RIP +30 % / +20 %, Hydra-Shok heavy +30 %)
ammo("A114_FX", "11.4x23 FX", "11.4 FX", "11.4", 50, 420, { dmg = 130, pen = 3, armorDmg = 0.12, bleedL = 0.42, bleedH = 0.26, frag = 1, speed = 293, acc = -0.05, subsonic = true }, "uncommon", "Fragmenting copper cup. Shreds flesh, stopped by anything.") -- RIP
ammo("A114_HP", "11.4x23 HP", "11.4 HP", "11.4", 50, 150, { dmg = 100, pen = 13, armorDmg = 0.3, bleedL = 0.12, bleedH = 0.36, frag = 0.5, speed = 274, subsonic = true }, nil, "Hollow point with a centre post.") -- Hydra-Shok
ammo("A114_TR", "11.4x23 TR", "11.4 TR", "11.4", 50, 76, { dmg = 76, pen = 19, armorDmg = 0.37, bleedL = 0.12, bleedH = 0.06, frag = 0.01, speed = 290, acc = 0.1, tracer = "red", subsonic = true }, nil, "Full metal jacket with an orange-tipped tracer.") -- Lasermatch FMJ
ammo("A114_FMJ", "11.4x23 FMJ", "11.4 FMJ", "11.4", 50, 94, { dmg = 72, pen = 25, armorDmg = 0.36, bleedL = 0.12, bleedH = 0.06, frag = 0.01, speed = 340, subsonic = true }, nil, "Match full metal jacket.") -- Match FMJ
ammo("A114_AP", "11.4x23 AP", "11.4 AP", "11.4", 50, 670, { dmg = 66, pen = 38, armorDmg = 0.48, bleedL = 0.12, bleedH = 0.06, frag = 0.01, speed = 299, recoil = 0.07, acc = -0.05, subsonic = true }, "rare", "Steel-core piercer. Goes through class 4.") -- AP
-- 7.6x25 (EFT's 7.62x25 TT; economy-1a, ninth slice): LRNPC, LRN, FMJ43, AKBS, P gl, PT gzh, Pst gzh and the sabot loads
-- TT M856A1, M855A1 and M995. Figures from tarkovforge.com/ammo/762x25mm-tt-<round> (read 2026-11-08); values EFT's handbook
-- prices, the three sabot loads' ours (not in SPT's handbook); bleeding as for the 6.2 with EFT's changes
ammo("A76T_LRNPC", "7.6x25 LRNPC", "7.6T LRNPC", "7.6T", 50, 68, { dmg = 66, pen = 7, armorDmg = 0.27, bleedL = 0.27, bleedH = 0.16, frag = 0.35, speed = 385, recoil = -0.1, acc = 0.1 }, nil, "Coated lead round nose. Soft and gentle to shoot.") -- LRNPC
ammo("A76T_LRN", "7.6x25 LRN", "7.6T LRN", "7.6T", 50, 48, { dmg = 64, pen = 8, armorDmg = 0.28, bleedL = 0.27, bleedH = 0.16, frag = 0.35, speed = 375, recoil = -0.05, acc = 0.05 }, nil, "Lead round nose.") -- LRN
ammo("A76T_FMJ", "7.6x25 FMJ", "7.6T FMJ", "7.6T", 50, 50, { dmg = 60, pen = 11, armorDmg = 0.29, bleedL = 0.12, bleedH = 0.06, frag = 0.25, speed = 427 }, nil, "Full metal jacket.") -- FMJ43
ammo("A76T_MATCH", "7.6x25 Match", "7.6T MATCH", "7.6T", 50, 49, { dmg = 58, pen = 12, armorDmg = 0.32, bleedL = 0.12, bleedH = 0.06, frag = 0.25, speed = 425, recoil = -0.15, acc = 0.15 }, nil, "Mild, accurate target load.") -- AKBS
ammo("A76T_P", "7.6x25 P", "7.6T P", "7.6T", 50, 52, { dmg = 58, pen = 14, armorDmg = 0.32, bleedL = 0.12, bleedH = 0.06, frag = 0.25, speed = 430 }, nil, "Service ball with a lead core.") -- P gl
ammo("A76T_PT", "7.6x25 PT", "7.6T PT", "7.6T", 50, 63, { dmg = 55, pen = 18, armorDmg = 0.34, bleedL = 0.12, bleedH = 0.06, frag = 0.17, speed = 415, acc = -0.1, tracer = "green" }, nil, "Green-tipped tracer.") -- PT gzh
ammo("A76T_PST", "7.6x25 PST", "7.6T PST", "7.6T", 50, 70, { dmg = 50, pen = 25, armorDmg = 0.36, bleedL = 0.12, bleedH = 0.06, frag = 0.2, speed = 430 }, nil, "Steel core. Gets through light vests.") -- Pst gzh
ammo("A76T_SBT", "7.6x25 SBT", "7.6T SBT", "7.6T", 50, 130, { dmg = 36, pen = 27, armorDmg = 0.31, bleedL = 0.38, bleedH = 0.13, frag = 0.08, speed = 900, tracer = "red" }, "uncommon", "Light sabot tracer. Very fast, little punch.") -- TT M856A1
ammo("A76T_SB", "7.6x25 SB", "7.6T SB", "7.6T", 50, 280, { dmg = 34, pen = 31, armorDmg = 0.33, bleedL = 0.29, bleedH = 0.12, frag = 0.02, speed = 900 }, "uncommon", "Light sabot penetrator. Very fast.") -- TT M855A1
ammo("A76T_SBAP", "7.6x25 SBAP", "7.6T SBAP", "7.6T", 50, 420, { dmg = 32, pen = 37, armorDmg = 0.36, bleedL = 0.26, bleedH = 0.1, frag = 0.25, speed = 940 }, "rare", "Sabot armour piercer. Goes through class 4.") -- TT M995
-- 9x21 (EFT's 9x21 gzh; economy-1a, tenth slice): PE, P, PS, 7U4 (our SUB), BT and 7N42 (our AP); and 9.6x39 (EFT's
-- .366 TKM): FMJ, Geksa (our EXP), EKO (our CU) and AP-M (our AP). Figures from tarkovforge.com/ammo/<round> (read
-- 2026-11-08); values EFT's handbook prices; bleeding as for the 6.2 with EFT's changes
ammo("A921_PE", "9x21 PE", "9x21 PE", "9.21", 50, 70, { dmg = 80, pen = 15, armorDmg = 0.63, bleedL = 0.27, bleedH = 0.16, frag = 0.35, speed = 415, recoil = -0.05, acc = 0.03 }, nil, "Expanding hollow point. Hits hard, stops at armour.") -- PE gzh
ammo("A921_P", "9x21 P", "9x21 P", "9.21", 50, 140, { dmg = 65, pen = 18, armorDmg = 0.44, bleedL = 0.27, bleedH = 0.16, frag = 0.3, speed = 413, recoil = -0.03, acc = 0.01 }, nil, "Lead core in a steel jacket.") -- P gzh
ammo("A921_PS", "9x21 PS", "9x21 PS", "9.21", 50, 242, { dmg = 59, pen = 22, armorDmg = 0.39, bleedL = 0.12, bleedH = 0.06, frag = 0.2, speed = 410 }, nil, "Steel core. Gets through light vests.") -- PS gzh
ammo("A921_SUB", "9x21 SUB", "9x21 SUB", "9.21", 50, 273, { dmg = 53, pen = 27, armorDmg = 0.44, bleedL = 0.12, bleedH = 0.06, frag = 0.25, speed = 300 }, "uncommon", "Heavy subsonic round for a suppressed gun.") -- 7U4
ammo("A921_BT", "9x21 BT", "9x21 BT", "9.21", 50, 558, { dmg = 52, pen = 32, armorDmg = 0.42, bleedL = 0.12, bleedH = 0.06, frag = 0.2, speed = 410, recoil = 0.05, acc = -0.05, tracer = "red" }, "uncommon", "Armour-piercing tracer.") -- BT gzh
ammo("A921_AP", "9x21 AP", "9x21 AP", "9.21", 50, 788, { dmg = 49, pen = 38, armorDmg = 0.47, bleedL = 0.12, bleedH = 0.06, frag = 0.1, speed = 400, recoil = 0.1, acc = -0.03 }, "rare", "Hardened steel penetrator. Goes through class 4.") -- 7N42 Zubilo
ammo("A96_FMJ", "9.6x39 FMJ", "9.6 FMJ", "9.6", 40, 80, { dmg = 98, pen = 23, armorDmg = 0.48, bleedL = 0.32, bleedH = 0.31, frag = 0.25, speed = 580, recoil = 0.1 }, nil, "Full metal jacket. Heavy and slow.") -- .366 TKM FMJ
ammo("A96_EXP", "9.6x39 EXP", "9.6 EXP", "9.6", 40, 75, { dmg = 110, pen = 14, armorDmg = 0.38, bleedL = 0.42, bleedH = 0.16, frag = 0.45, speed = 550 }, nil, "Expanding hunting bullet. Terrible wounds, no use against armour.") -- .366 TKM Geksa
ammo("A96_CU", "9.6x39 CU", "9.6 CU", "9.6", 40, 110, { dmg = 73, pen = 30, armorDmg = 0.4, bleedL = 0.12, bleedH = 0.26, frag = 0.2, speed = 770, recoil = -0.15, acc = -0.1 }, nil, "Light solid-copper bullet. Fast and flat.") -- .366 TKM EKO
ammo("A96_AP", "9.6x39 AP", "9.6 AP", "9.6", 40, 720, { dmg = 90, pen = 42, armorDmg = 0.6, bleedL = 0.12, bleedH = 0.16, frag = 0.01, speed = 602, recoil = 0.35, acc = -0.22 }, "rare", "Steel-core armour piercer. A brutal kick.") -- .366 TKM AP-M
-- 9x33R (EFT's .357 Magnum; economy-1a, eleventh slice): FMJ, JHP, HP and SP; and 12.7x55 (EFT's PS12, PS12A, PS12B).
-- Figures from tarkovforge.com/ammo/<round> (read 2026-11-08); values EFT's handbook prices; bleeding as for the 6.2
-- with EFT's changes
ammo("A933_FMJ", "9x33R FMJ", "9x33R FMJ", "9.33", 50, 142, { dmg = 70, pen = 35, armorDmg = 0.43, bleedL = 0.12, bleedH = 0.16, frag = 0.01, speed = 385, recoil = 0.12 }, "uncommon", "Full metal jacket magnum. Gets through light armour.") -- .357 Magnum FMJ
ammo("A933_JHP", "9x33R JHP", "9x33R JHP", "9.33", 50, 186, { dmg = 88, pen = 24, armorDmg = 0.28, bleedL = 0.37, bleedH = 0.31, frag = 0.6, speed = 425, recoil = 0.08, acc = 0.15 }, nil, "Jacketed hollow point.") -- .357 Magnum JHP
ammo("A933_HP", "9x33R HP", "9x33R HP", "9.33", 50, 122, { dmg = 99, pen = 18, armorDmg = 0.2, bleedL = 0.52, bleedH = 0.36, frag = 0.6, speed = 481, recoil = 0.15, acc = 0.15 }, nil, "Fast lead hollow point. Ugly wounds.") -- .357 Magnum HP
ammo("A933_SP", "9x33R SP", "9x33R SP", "9.33", 50, 100, { dmg = 108, pen = 12, armorDmg = 0.15, bleedL = 0.47, bleedH = 0.26, frag = 0.2, speed = 455, recoil = -0.29, acc = 0.27 }, nil, "Soft point. Hard on flesh, useless on plates.") -- .357 Magnum SP
ammo("A127_PS12", "12.7x55 PS12", "12.7 PS12", "12.7", 20, 360, { dmg = 115, pen = 28, armorDmg = 0.6, bleedL = 0.42, bleedH = 0.26, frag = 0.3, speed = 300, acc = 0.1 }, "uncommon", "Heavy subsonic bullet.") -- PS12
ammo("A127_PS12A", "12.7x55 PS12A", "12.7 PS12A", "12.7", 20, 220, { dmg = 165, pen = 10, armorDmg = 0.22, bleedL = 0.47, bleedH = 0.36, frag = 0.7, speed = 870, recoil = -0.12, acc = -0.15 }, "uncommon", "Light expanding bullet. Devastating on flesh.") -- PS12A
ammo("A127_PS12B", "12.7x55 PS12B", "12.7 PS12B", "12.7", 20, 900, { dmg = 102, pen = 46, armorDmg = 0.57, bleedL = 0.12, bleedH = 0.21, frag = 0.3, speed = 570, recoil = 0.15 }, "rare", "Hardened steel core. Goes through almost anything.") -- PS12B

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
-- Adrenaline injector, and SJ1 since economy-1a's thirteenth slice. EFT: 1x1, 0.05 kg, 2 s to inject, one use
add("STIM_REGEN", { name = "RG-5 Regenerative Injector", short = "RG-5", kind = "med", w = 1, h = 1, mass = 0.05, value = 36000, rarity = "rare", med = { stim = "STIM_REGEN", uses = 1, time = 2 }, desc = "A regenerative stimulant. Slowly restores health for 5 minutes and kills pain for about 4. Hand tremor and tunnel vision near the end.", color = MED })
add("STIM_STAMINA", { name = "SV-3 Combat Stimulant", short = "SV-3", kind = "med", w = 1, h = 1, mass = 0.05, value = 85000, rarity = "rare", med = { stim = "STIM_STAMINA", uses = 1, time = 2 }, desc = "A combat stimulant. More stamina and faster recovery for 4 minutes. Hand tremor and tunnel vision near the end.", color = MED })
add("STIM_HEMO", { name = "HM-2 Hemostatic Injector", short = "HM-2", kind = "med", w = 1, h = 1, mass = 0.05, value = 50000, rarity = "rare", med = { stim = "STIM_HEMO", uses = 1, time = 2 }, desc = "A hemostatic stimulant. Stops all bleeding, and no new bleed takes for 3 minutes. Hand tremor and heavy dehydration near the end.", color = MED })
add("STIM_ADREN", { name = "Adrenaline Injector", short = "ADRENALINE", kind = "med", w = 1, h = 1, mass = 0.05, value = 16000, rarity = "uncommon", med = { stim = "STIM_ADREN", uses = 1, time = 2 }, desc = "Kills pain for about a minute, gives a short burst of health and a minute of endurance, strength and recoil control. Hunger and thirst follow.", color = MED })
-- economy-1a's thirteenth slice: the SV-1 copies EFT's SJ1 TGLabs combat stimulant (1x1, 0.05 kg, 2 s to inject, one use:
-- xgamingserver.com's item page, snapshot 2026-11-04; EFT's handbook price, 35,893); its course in Stims.luau
add("STIM_COMBAT", { name = "SV-1 Combat Stimulant", short = "SV-1", kind = "med", w = 1, h = 1, mass = 0.05, value = 35893, rarity = "rare", med = { stim = "STIM_COMBAT", uses = 1, time = 2 }, desc = "A combat stimulant. Endurance, Strength and Stress Resistance up for 3 minutes. Hunger and thirst follow.", color = MED })
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
add("KEY_SMELT_OFFICE", { name = "Smelter Emergency Exit Key", short = "SMELT EXIT", kind = "key", w = 1, h = 1, mass = 0.02, value = 26000, rarity = "uncommon", key = { door = "smelter_office", uses = 20 }, desc = "Smelter: opens the aid post gate passage and the cable cellar door, both ways out, and the manager's office on the third floor.", color = c("#7A6E58") }) -- EFT's Factory emergency exit key (20 uses; the Med Tent gate, the Cellars and a third-floor office: tarkovforge.com/keys/factory-emergency-exit-key, read 2026-11-09)
-- the Smelter's sealed stores and smugglers' crawl (art-1a follow-up, 2026-11-09). EFT's TerraGroup storage room keycard:
-- 1x1, 0.01 kg, 10 uses, handbook 850,000 (xgamingserver.com item page, read 2026-11-09); EFT's note with the code word
-- "Ark" opens Factory's smugglers' passage, is found in filing cabinets and on bodies and cannot leave the raid
-- (primagames.com's secret exfil guide); ours carries another word. `raidOnly`: taken away when the raid settles;
-- `mapOnly`: loot rolls it only on that map.
add("KEY_SMELT_STORE", { name = "Smelter Stores Keycard", short = "STORES", kind = "key", w = 1, h = 1, mass = 0.01, value = 850000, rarity = "rare", key = { door = "smelter_store", uses = 10, card = true }, desc = "Smelter: the keycard for the sealed stores off the main hall.", color = c("#C9CCC4") })
add("NOTE_SMELT_CRAWL", { name = "Note With a Code Word", short = "NOTE", kind = "key", w = 1, h = 1, mass = 0.01, value = 1500, rarity = "uncommon", key = { door = "smelter_crawl", uses = 10 }, raidOnly = true, mapOnly = "smelter", desc = "A folded sheet with one pencilled word: \"KILN\". Said aloud at the right door in the Smelter's cellar it opens the smugglers' crawl. It does not leave the raid with you.", color = c("#E4DCC4") })
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
-- GUNPOWDER stood for EFT's gunpowder "Kite", "Hawk" and "Eagle" and FABRIC for its aramid, Cordura, ripstop and fleece;
-- since economy-1a's fifteenth slice (2026-11-09) each is its own item: GUNPOWDER is EFT's "Kite" and FABRIC its aramid
-- fiber fabric, with EFT's grid, weight and handbook price (SPT 3.10.1 items.json and handbook.json), the other two
-- powders and three fabrics follow the thirteenth slice's goods below. MOONSHINE is EFT's bottle of moonshine (the scav
-- case's dearest run and its construction; size after EFT's, value ours).
loot("GUNPOWDER", "Fine Powder Tin", "FINE PWD", 1, 2, 0.6, 14000, "uncommon", "A sealed tin of fine-grained smokeless powder, the quick-burning kind for pistol and light rifle loads. Reloaders and grenade makers pay well for it.", "#5E6650") -- gunpowder "Kite"
loot("FABRIC", "Aramid Fabric", "ARAMID", 2, 1, 0.14, 8800, "common", "A folded length of tough yellow aramid weave, the cloth soft armour is made of. Tailors cut it to make and mend armour.", "#B89A3E") -- aramid fiber fabric
loot("MOONSHINE", "Moonshine", "MOONSHINE", 1, 2, 1.1, 140000, "rare", "A corked bottle of home-distilled spirit, strong enough to strip paint. Scavs will do a lot for one.", "#B9A97A")
add("DOGTAG", { name = "Dog Tag", short = "TAG", kind = "loot", w = 1, h = 1, mass = 0.02, value = 12000, rarity = "uncommon", desc = "An operator's identification tag. Worth more the more experienced its owner was.", color = c("#A7A9A0") })
-- decision economy-1a, second slice (2026-11-08): the goods EFT's hideout is built from and its crafts use, which the
-- hideout had covered with stand-ins. One of ours for each EFT item named beside it, with EFT's grid size (tarkovforge.com
-- item pages) and EFT's handbook price as the value (SPT's handbook.json; 1 rouble = 1 MK, TraderData's rule). Weights
-- are ours (no page read gave them). The lighter stands for EFT's SurvL too, the penetrating oil for both WD-40 sizes;
-- EFT's Pliers Elite, cable cutter, Shustrilo foam, Zibbo, multivitamins and hydrogen peroxide, which pliers, the sealing
-- foam, the lighter, the pile of meds and saline stood for, are their own items since the fifteenth slice (below).
-- building materials
loot("SCREWS", "Screw Pack", "SCREWS", 1, 1, 0.15, 3140, "common", "A paper pack of wood and machine screws, mixed sizes.", "#8A8C86") -- pack of screws
loot("NUTS", "Hex Nuts", "NUTS", 1, 1, 0.2, 8700, "common", "A bag of zinc-plated hex nuts.", "#9A9C96") -- screw nuts
loot("NAILS", "Nail Pack", "NAILS", 1, 1, 0.2, 4105, "common", "A cardboard pack of building nails.", "#7E7466") -- pack of nails
loot("SILICONE_TUBE", "Silicone Tube", "TUBE", 1, 1, 0.3, 18900, "uncommon", "A cartridge of clear silicone sealant. Seals pipes, tanks and window frames.", "#C8CCC4") -- silicone tube
loot("CORR_HOSE", "Corrugated Hose", "HOSE", 2, 1, 0.5, 12201, "uncommon", "A coil of ribbed plastic hose with clamps on both ends.", "#3E4A52") -- corrugated hose
loot("PRESSURE_GAUGE", "Pressure Gauge", "GAUGE", 2, 1, 0.6, 61200, "rare", "A brass pressure gauge on a short pipe stub. Water and fuel systems need one.", "#B08A3C") -- pressure gauge
loot("SEAL_TAPE", "Sealing Tape", "SEAL", 1, 1, 0.2, 24000, "uncommon", "A heavy roll of waterproof sealing tape. Holds where duct tape lets go.", "#C8A43A") -- KEKTAPE duct tape
loot("FOAM", "Sealing Foam", "FOAM", 1, 3, 0.9, 33778, "uncommon", "A tall can of expanding polyurethane foam with a straw nozzle.", "#5E7A3E") -- Xenomorph sealing foam
loot("SPARE_PARTS", "Metal Spare Parts", "M.PARTS", 1, 1, 0.5, 5000, "common", "Brackets, springs and pins in a plastic bag. Someone always needs one of them.", "#7A7C76") -- metal spare parts
-- electronics
loot("RELAY", "Phase Relay", "RELAY", 1, 1, 0.3, 9500, "common", "A phase control relay off a switchboard rail.", "#3F4A5A") -- phase control relay
loot("MOTOR", "Electric Motor", "MOTOR", 2, 2, 2.5, 43000, "uncommon", "A small industrial electric motor with its mounting foot.", "#4E5A4A") -- electric motor
loot("PSU", "Power Supply", "PSU", 2, 2, 1.6, 7936, "common", "A desktop computer power supply with its cables cut short.", "#4A4E52") -- power supply unit
loot("CPU_FAN", "Cooling Fan", "FAN", 1, 1, 0.25, 4670, "common", "A processor cooler: an aluminium heatsink under a plastic fan.", "#5A5E62") -- CPU fan
loot("POWER_CORD", "Power Cord", "CORD", 2, 1, 0.4, 12623, "uncommon", "A coiled heavy power cord with a plug on one end.", "#2E3034") -- power cord
loot("TPLUG", "T-Plug", "T-PLUG", 1, 1, 0.1, 2481, "common", "A three-way mains adapter.", "#D8D4C8") -- T-shaped plug
loot("POWER_FILTER", "Power Filter", "PFILTER", 1, 1, 0.6, 55000, "rare", "A ruggedised power line filter in an olive case with military connectors.", "#4E5A3E") -- military power filter
loot("MIL_CABLE", "Military Cable", "MCABLE", 2, 1, 0.8, 41200, "uncommon", "A shielded field cable with round locking connectors.", "#3E4632") -- military cable
loot("ES_LAMP", "Energy-Saving Lamp", "ES LAMP", 1, 1, 0.15, 10822, "common", "A spiral fluorescent bulb, still in one piece.", "#E8E6DC") -- energy-saving lamp
loot("POWER_DRILL", "Power Drill", "DRILL", 2, 2, 1.8, 32943, "uncommon", "A cordless drill with a worn battery. Builders and gunsmiths both want one.", "#C86A2A") -- electric drill
-- info
loot("SSD", "SSD", "SSD", 1, 1, 0.08, 80000, "rare", "A solid-state drive pulled from a laptop. The data may still be there.", "#2E3640") -- SSD drive
loot("SURVEY_MAPS", "Survey Maps", "MAPS", 2, 1, 0.3, 72000, "rare", "A rolled set of topographic survey sheets with handwritten grid marks.", "#C8BC96") -- topographic survey maps
loot("SECURE_FLASH", "Secure Flash Drive", "FLASH", 1, 1, 0.03, 40152, "uncommon", "An encrypted USB stick in a metal shell.", "#5A6E7A") -- secure flash drive
-- energy elements
loot("LI_BATTERY", "Lithium Battery", "LI BATT", 1, 1, 0.3, 26000, "uncommon", "A lithium battery pack for field radios.", "#3E7A4A") -- GreenBat lithium battery
-- flammable materials
loot("PEN_OIL", "Penetrating Oil", "OIL", 1, 1, 0.15, 6958, "common", "A small spray can of penetrating oil. Frees rusted bolts and keeps hinges quiet.", "#3A5A9A") -- WD-40 (100 ml)
loot("TNT", "TNT Brick", "TNT", 1, 1, 0.25, 35000, "uncommon", "A 200-gram demolition charge in a paper wrapper.", "#8E8A6A") -- TP-200 TNT brick
loot("THERMITE", "Thermite Can", "THERM", 1, 1, 0.6, 52000, "rare", "A sealed can of thermite mix. Burns through steel.", "#8A5A3A") -- can of thermite
loot("LIGHTER", "Lighter", "LIGHTER", 1, 1, 0.05, 1320, "common", "A cheap disposable gas lighter.", "#C83A2A") -- Crickent lighter
loot("GUN_LUBE", "Gun Lube", "LUBE", 1, 1, 0.2, 36428, "uncommon", "A bottle of weapon lubricant with a needle tip.", "#2E5A7A") -- #FireKlean gun lube
-- household materials
loot("TOILET_PAPER", "Toilet Paper", "TP", 1, 1, 0.15, 8800, "common", "A single roll. In short supply everywhere.", "#E8E8E2") -- toilet paper
loot("SALT", "White Salt", "SALT", 1, 1, 0.6, 8000, "common", "A tin of coarse white salt.", "#D8DCE0") -- can of white salt
loot("CHLORINE", "Chlorine Pack", "CHLOR", 2, 1, 0.5, 11000, "uncommon", "A sealed pack of chlorine powder for disinfecting water.", "#E0E4D8") -- pack of chlorine
loot("ALKALI", "Alkaline Cleaner", "ALKALI", 1, 2, 1.1, 8457, "common", "A jug of alkaline descaler for heat exchangers.", "#4A7AA8") -- alkaline cleaner for heat exchangers
-- medical supplies
loot("SYRINGE", "Syringe", "SYRINGE", 1, 1, 0.02, 3000, "common", "A sterile disposable syringe in its blister.", "#E0E8EC") -- disposable syringe
loot("MEDS_PILE", "Pile of Meds", "MEDS", 1, 1, 0.2, 6500, "common", "Loose blister packs of assorted tablets.", "#C8B8A8") -- pile of meds
loot("SALINE", "Saline Bottle", "NACL", 1, 1, 0.5, 8508, "common", "A plastic bottle of sterile saline solution.", "#D8E4EC") -- bottle of saline solution
loot("BLOODSET", "Blood Set", "BLOODSET", 1, 1, 0.1, 9765, "common", "A sealed transfusion set: bag, line and needle.", "#B83A3A") -- medical bloodset
loot("LEDX", "Vein Transilluminator", "TRANSIL", 1, 1, 0.3, 970000, "epic", "A handheld transilluminator that shows veins under the skin. Hospitals would pay anything for one.", "#3A6E8A") -- LEDX skin transilluminator
loot("OPHTHALMOSCOPE", "Ophthalmoscope", "OSCOPE", 1, 1, 0.4, 84912, "rare", "A doctor's eye-examination light in a hard case.", "#2E3238") -- ophthalmoscope
-- others
loot("WEAPON_PARTS", "Weapon Parts", "WPARTS", 2, 1, 0.6, 14240, "uncommon", "Springs, pins and a spare extractor in an oily rag.", "#5A5C58") -- weapon parts
loot("WATER_FILTER", "Water Filter", "WFILTER", 1, 2, 0.9, 24500, "uncommon", "A replaceable carbon cartridge for a water purifier.", "#D8DCE0") -- water filter
loot("FUZE", "Grenade Fuze", "FUZE", 1, 1, 0.05, 8100, "common", "A hand grenade fuze with its pin and lever. Grenade makers need them.", "#5E6650") -- UZRGM grenade fuze
-- valuables
loot("GOLD_ROOSTER", "Golden Rooster", "ROOSTER", 2, 2, 2.0, 90566, "rare", "A gilded rooster figurine on a wooden base.", "#C9A13C") -- golden rooster figurine
loot("SKULL_RING", "Gold Skull Ring", "SKULL", 1, 1, 0.03, 55000, "rare", "A heavy gold ring cast as a grinning skull.", "#C9A13C") -- gold skull ring
-- tools (EFT keeps them as barter goods and as the tools its crafts hold while they run)
loot("SCREWDRIVER", "Screwdriver", "SCDR.", 1, 1, 0.15, 3500, "common", "A flat screwdriver with a worn handle.", "#C83A2A") -- screwdriver
loot("PLIERS", "Pliers", "PLIERS", 1, 1, 0.3, 8000, "common", "Combination pliers with insulated grips.", "#3A5A9A") -- pliers (and EFT's nippers, round pliers and metal cutting scissors in crafts)
loot("WRENCH", "Wrench", "WRENCH", 1, 1, 0.4, 3544, "common", "A double-ended open spanner.", "#8C8F8A") -- wrench
loot("RATCHET", "Ratchet Wrench", "RATCHET", 1, 2, 0.6, 124000, "rare", "A long ratchet handle with a socket still on it.", "#9A9C96") -- ratchet wrench
loot("PIPE_WRENCH", "Pipe Wrench", "PGW", 1, 2, 1.4, 132000, "rare", "A heavy adjustable pipe wrench in red enamel.", "#A83A2A") -- pipe grip wrench
loot("HAND_DRILL", "Hand Drill", "H.DRILL", 3, 2, 1.5, 60000, "rare", "An old crank-handle hand drill with a chuck key.", "#6E5A3E") -- hand drill
loot("TOOLSET", "Toolset", "TOOLSET", 2, 2, 2.4, 31000, "uncommon", "A plastic case of sockets, bits and a ratchet.", "#2E3238") -- toolset
loot("FILE_SET", "File Set", "FILES", 2, 2, 0.8, 35000, "uncommon", "A roll of machinist's files: flat, round and half-round.", "#5A4632") -- set of files "Master"
loot("TAPE_MEASURE", "Tape Measure", "MTAPE", 1, 1, 0.3, 3769, "common", "A five-metre tape measure in a yellow case.", "#D8B43A") -- construction measuring tape
loot("AWL", "Awl", "AWL", 1, 1, 0.1, 33000, "uncommon", "A leatherworker's awl with a wooden handle.", "#8A6A42") -- awl
loot("SEWING_KIT", "Sewing Kit", "SEWING", 1, 1, 0.2, 38000, "uncommon", "Heavy needles, waxed thread and a thimble in a tin.", "#7A5A8A") -- sewing kit
-- decision economy-1a, thirteenth slice (2026-11-08): the goods that let more of EFT's crafts in (the crafts thread's list).
-- One of ours for each EFT item beside it, with EFT's grid size (tarkovforge.com/loot/<item>, read 2026-11-08) and weight
-- (xgamingserver.com item pages, snapshot 2026-11-04), its handbook price as the value and its handbook folder (SPT's
-- handbook.json). The textbook's grid size and weight were ours then; SPT 3.10.1's items.json gives EFT's own, 1x2 and
-- 0.5 kg (the fifteenth slice took the weight).
loot("PRINTER_PAPER", "Printer Paper", "PAPER", 2, 1, 0.7, 2337, "common", "A ream of plain office paper in its wrapper. Printers, copiers and anyone with something to write down want it.", "#E8E8E2") -- printer paper
loot("COOK_BOOK", "Home Baking Cookbook", "COOKBOOK", 1, 2, 0.25, 58000, "rare", "A hardback of breads, pies and party dishes, its margins full of somebody's notes. A field kitchen runs better with one on the shelf.", "#B8442E") -- BakeEzy cook book
loot("GEIGER", "Geiger Counter", "GEIGER", 1, 2, 0.4, 16684, "uncommon", "A handheld radiation counter with a probe on a coiled lead. Still clicks when it should.", "#C8A43A") -- Geiger-Muller counter
loot("SEMI_TEXTBOOK", "Semiconductor Materials Textbook", "SEMI BOOK", 1, 2, 0.5, 490000, "epic", "A thick university textbook on semiconductor and display materials. Rare, and the one guide anyone has for making circuit boards from scratch.", "#2E4A7A") -- Advanced Electronic Materials textbook
loot("MAGNET", "Magnet", "MAGNET", 1, 1, 0.4, 12713, "uncommon", "A heavy ring magnet salvaged from a speaker or a drive. Motors and instruments cannot be built without one.", "#3A3C3E") -- magnet
loot("SLEDGEHAMMER", "Sledgehammer", "SLEDGE", 2, 5, 5.5, 132000, "rare", "A long-handled sledgehammer with a heavy steel head, for knocking down walls and beating stuck metal into shape.", "#4A4E52") -- Fierce Blow sledgehammer
-- decision economy-1a, fifteenth slice (2026-11-09): EFT's remaining barter goods that its hideout, crafts, barters and
-- dailies use. One of ours for each EFT item beside it, with EFT's grid size and weight (SPT 3.10.1's items.json,
-- github.com/sp-tarkov/server tag 3.10.1), its handbook price as the value and its handbook folder (SPT 3.10.1's
-- handbook.json). Names, looks and words are ours (no maker's names). Where EFT finds them: Loot.luau's pools.
-- electronics
loot("DISC_DRIVE", "Disc Drive", "DISC", 2, 1, 0.6, 8295, "uncommon", "A desktop optical drive in a scuffed beige case, its tray stuck half open. The laser sled and motors inside are worth salvaging.", "#C8C2B0") -- DVD drive
loot("PC_CPU", "Desktop Processor", "CPU", 1, 1, 0.08, 13914, "uncommon", "A square desktop processor, heat spreader on top and a field of gold pins underneath. Small, light and wanted by anyone building electronics.", "#8A8E8C") -- PC CPU
loot("LCD_PANEL", "LCD Panel", "LCD", 1, 2, 0.05, 38000, "uncommon", "A working liquid-crystal panel pulled from a monitor, its ribbon cable intact. Camera posts and terminals need one.", "#2A2E34") -- working LCD
loot("LCD_BROKEN", "Cracked LCD Panel", "BRK LCD", 1, 2, 0.05, 21500, "uncommon", "A liquid-crystal panel with a spider-web crack across one corner. A good workbench can bring it back.", "#30343A") -- broken LCD
loot("GAME_CONSOLE", "Handheld Game Console", "HANDHELD", 1, 2, 0.13, 120000, "rare", "A pocket game console from before the collapse with a cartridge still in the slot. Collectors and bored traders pay absurd money for one.", "#7A8A3A") -- Tetriz portable game console
loot("FPGA_CHIP", "Programmable Processor", "FPGA", 1, 1, 0.3, 120000, "rare", "A military-grade programmable logic processor on a small carrier board. Rare outside research labs; advanced electronics are built round it.", "#2E5A3A") -- Virtex programmable processor
loot("STORAGE_MODULE", "Rugged Storage Module", "STORAGE", 1, 1, 0.8, 152400, "rare", "A sealed, ruggedised flash storage module from a military computer rack, heavy for its size. Server racks and command posts run on them.", "#4A5258") -- VPX flash storage module
loot("GAS_ANALYSER", "Gas Analyser", "GAS AN.", 1, 2, 0.4, 21697, "uncommon", "A handheld gas detector with a sensor grille and a small display. Its sensors and board go into other instruments.", "#D8A82E") -- gas analyzer
-- the three other fabrics (aramid is FABRIC, above) and the two other powders (Kite is GUNPOWDER)
loot("FABRIC_POLY", "Polyamide Fabric", "POLYAMIDE", 2, 1, 0.11, 13200, "uncommon", "A folded length of heavy coated polyamide canvas that shrugs off abrasion. Packs and rigs are sewn from it.", "#5A6448") -- Cordura polyamide fabric
loot("FABRIC_RIPSTOP", "Ripstop Fabric", "RIPSTOP", 2, 1, 0.09, 5800, "common", "A folded length of light ripstop cloth with its reinforcing grid: a tear stops at the next thread. Rigs and tool rolls use it.", "#6E7A5A") -- ripstop fabric
loot("FABRIC_FLEECE", "Fleece Fabric", "FLEECE", 2, 1, 0.05, 4000, "common", "A folded length of soft synthetic fleece. Warm and light; bandages and padding are cut from it.", "#8A8478") -- fleece fabric
loot("POWDER_FLAKE", "Flake Powder Tin", "FLAKE PWD", 1, 2, 0.6, 35000, "uncommon", "A sealed tin of flake smokeless powder for full-power rifle loads. The workbench turns it into armour-piercing rounds.", "#7A3A30") -- gunpowder "Hawk"
loot("POWDER_BALL", "Ball Powder Tin", "BALL PWD", 1, 2, 0.6, 32000, "uncommon", "A sealed tin of dense, slow-burning ball powder for heavy bullets and slugs.", "#3E5A3A") -- gunpowder "Eagle"
-- tools, building materials and flammables
loot("PLIERS_HD", "Heavy-Duty Pliers", "HD PLIERS", 1, 1, 0.25, 29000, "uncommon", "Forged combination pliers with sprung, insulated grips and a hardened cutting edge. Gunsmiths and electricians keep a pair on the bench.", "#B83A2E") -- Pliers Elite
loot("CABLE_CUTTER", "Cable Cutter", "CUTTER", 1, 2, 0.55, 105000, "rare", "Long-handled ratchet cable cutters that bite through armoured cable in one squeeze. Generators are wired with their help.", "#C8442E") -- Bulbex cable cutter
loot("FOAM_MOUNT", "Mounting Foam", "M.FOAM", 1, 3, 1.0, 35502, "uncommon", "A tall can of expanding polyurethane mounting foam with a straw nozzle. Seals tanks and walls airtight.", "#3A6E9A") -- Shustrilo sealing foam
loot("COLD_WELD", "Cold Weld Epoxy", "EPOXY", 1, 1, 0.02, 19400, "uncommon", "A twin tube of two-part steel-filled epoxy. Mixed, it sets as hard as a weld without heat.", "#7A7E80") -- tube of Poxeram cold welding
loot("INSUL_TAPE", "Insulating Tape", "INS TAPE", 1, 1, 0.05, 2019, "common", "A roll of blue electrical tape. Every wire splice and grip wrap starts with it.", "#2E4E9A") -- insulating tape
loot("LIGHTER_WIND", "Windproof Lighter", "WINDPROOF", 1, 1, 0.1, 9617, "uncommon", "A brushed steel petrol lighter with a hinged lid and a chimney round the wick. Lights in a gale.", "#A8AAA6") -- Zibbo lighter
loot("MATCHES_HUNT", "Hunting Matches", "H.MATCH", 1, 1, 0.005, 3800, "common", "A tin of long stormproof matches that burn through wind and rain. Smoke grenades and campfires start with them.", "#C86A2E") -- hunting matches
-- household, medical supplies and others
loot("BICARB", "Sodium Bicarbonate", "BICARB", 1, 1, 0.5, 10200, "uncommon", "A paper pack of baking soda. It cleans, neutralises acid and goes into bleach, and medics trade for it.", "#E8E4D8") -- pack of sodium bicarbonate
loot("SHAMPOO", "Herbal Shampoo", "SHAMPOO", 1, 2, 0.45, 7000, "uncommon", "A tall bottle of herbal shampoo, nearly full. Soap makers and medics both have uses for it.", "#4A8A5A") -- Schaman shampoo
loot("MULTIVITAMINS", "Multivitamins", "VITAMINS", 1, 1, 0.2, 25090, "uncommon", "A plastic tub of multivitamin tablets, seal unbroken. Medics trade stimulants for them.", "#E8A030") -- bottle of OLOLO multivitamins
loot("PEROXIDE", "Hydrogen Peroxide", "H2O2", 1, 1, 0.1, 12168, "uncommon", "A small brown bottle of hydrogen peroxide for cleaning wounds and instruments.", "#5A3A2A") -- bottle of hydrogen peroxide
loot("COFFEE_BEANS", "Tin of Coffee Beans", "COFFEE", 1, 1, 0.5, 14977, "uncommon", "A vacuum tin of roasted coffee beans. Not food on its own, but a field kitchen brews energy drinks from it.", "#6A3E22") -- can of Majaica coffee beans
-- info and valuables: the other books
loot("OPTO_TEXTBOOK", "Optoelectronics Textbook", "OPTO BOOK", 1, 2, 0.5, 500000, "epic", "A thick university textbook on silicon optoelectronic circuits, rarer still than the semiconductor volume: the one guide to building imaging electronics from scratch.", "#5A2E6A") -- Silicon Optoelectronic Integrated Circuits textbook
loot("DIARY", "Diary", "DIARY", 1, 2, 0.2, 58000, "rare", "A hardback diary full of careful notes: names, places, dates. Intelligence people read every page.", "#6A4A2E") -- diary
loot("SLIM_DIARY", "Slim Diary", "S.DIARY", 1, 1, 0.1, 71000, "rare", "A thin pocket diary in a worn leather cover, written in a tight hand. Small, and worth more than it looks.", "#3A2A22") -- slim diary
loot("TECH_MANUAL", "Technical Manual", "MANUAL", 1, 2, 0.2, 3900, "common", "A ring-bound service manual for electrical equipment, its diagrams smudged with oil. A workshop wants one on the shelf.", "#D8C878") -- tech manual
loot("ANTIQUE_BOOK", "Battered Antique Book", "OLD BOOK", 1, 2, 0.4, 63029, "rare", "A leather-bound book two centuries old, spine cracked and corners worn through. Collectors still pay well for it.", "#5A2A1E") -- battered antique book
-- provisions: EFT's pack of sugar is food (energy +70, hydration -45, 9 s to eat; SPT 3.10.1 items.json); its Intellect
-- skill buff (+1 for 300 s, globals Buffs_food_sugar) and partial eating are not modelled
add("SUGAR", { name = "Pack of Sugar", short = "SUGAR", kind = "food", w = 1, h = 1, mass = 0.5, value = 21489, rarity = "uncommon", food = { energy = 70, water = -45, time = 9 }, desc = "Energy +70, hydration -45. A paper pack of white sugar; the field kitchen bakes and brews with it.", color = c("#E8E6E0") }) -- pack of sugar
-- EFT's handbook folders for every barter good (the HANDBOOK and flea market can group by it)
local BARTER_CAT = {
	building = { "BOLTS", "DUCT_TAPE", "SCREWS", "NUTS", "NAILS", "SILICONE_TUBE", "CORR_HOSE", "PRESSURE_GAUGE", "SEAL_TAPE", "FOAM", "SPARE_PARTS",
		"FOAM_MOUNT", "COLD_WELD", "INSUL_TAPE" },
	electronics = { "WIRES", "SPARK_PLUG", "SIGNAL_COIL", "CERAMIC_FUSE", "CAPACITOR", "CRACKED_LENS", "LOGIC_BOARD", "DECK_TRANSCEIVER", "FLASH_MODULE",
		"MIL_CIRCUIT", "GPU_CARD", "HDD", "RAM_STICK", "PHONE", "LIGHTBULB", "RELAY", "MOTOR", "PSU", "CPU_FAN", "POWER_CORD", "TPLUG", "POWER_FILTER",
		"MIL_CABLE", "ES_LAMP", "POWER_DRILL", "GEIGER", "MAGNET",
		"DISC_DRIVE", "PC_CPU", "LCD_PANEL", "LCD_BROKEN", "GAME_CONSOLE", "FPGA_CHIP", "STORAGE_MODULE", "GAS_ANALYSER" },
	energy = { "BATTERY", "POWER_BANK", "LI_BATTERY" },
	flammable = { "MATCHES", "FUEL_CAN", "GUNPOWDER", "PEN_OIL", "TNT", "THERMITE", "LIGHTER", "GUN_LUBE", "POWDER_FLAKE", "POWDER_BALL", "LIGHTER_WIND", "MATCHES_HUNT" },
	household = { "TOOTHPASTE", "SOAP", "BLEACH", "TOILET_PAPER", "SALT", "CHLORINE", "ALKALI", "PRINTER_PAPER", "BICARB", "SHAMPOO" },
	medical = { "MED_TOOLS", "SYRINGE", "MEDS_PILE", "SALINE", "BLOODSET", "LEDX", "OPHTHALMOSCOPE", "MULTIVITAMINS", "PEROXIDE" },
	info = { "INTEL_FOLDER", "SSD", "SURVEY_MAPS", "SECURE_FLASH", "COOK_BOOK", "SEMI_TEXTBOOK", "OPTO_TEXTBOOK", "DIARY", "SLIM_DIARY", "TECH_MANUAL" },
	valuables = { "OLD_COIN", "GOLD_CHAIN", "RITUAL_AMULET", "CAPT_WATCH", "COLD_WALLET", "BRASS_LION", "GOLD_ROOSTER", "SKULL_RING", "ANTIQUE_BOOK" },
	tools = { "SCREWDRIVER", "PLIERS", "WRENCH", "RATCHET", "PIPE_WRENCH", "HAND_DRILL", "TOOLSET", "FILE_SET", "TAPE_MEASURE", "AWL", "SEWING_KIT", "SLEDGEHAMMER",
		"PLIERS_HD", "CABLE_CUTTER" },
	others = { "CIGARETTES", "FABRIC", "MOONSHINE", "DOGTAG", "WEAPON_PARTS", "WATER_FILTER", "FUZE", "FABRIC_POLY", "FABRIC_RIPSTOP", "FABRIC_FLEECE", "COFFEE_BEANS" },
}
for cat, ids in BARTER_CAT do
	for _, id in ids do
		assert(defs[id], "BARTER_CAT: " .. id)
		defs[id].cat = cat
	end
end

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

-- ── calibres: the rounds a magazine takes and the rounds a gun fires (economy-1a, fourteenth slice) ─────────────
-- EFT keeps the two apart: a magazine's cartridge filter lists the rounds its feed lips take, a gun's chamber filter the
-- rounds it fires (SPT 3.10.1 items.json: every AK 7.62x39 magazine, the 6L10, AK-103, '55, 10-round, 40-round and drum
-- magazines alike, takes the four .366 TKM loads beside the nine 7.62x39 ones; the AKM's and VPO-136's chambers take
-- 7.62x39 only, the VPO-209's .366 TKM only). A magazine still fits a gun by its family, whatever it holds; a round the
-- chamber cannot take is never chambered (EFT's reload and draw states chamber only when the magazine's ammunition is
-- compatible with the weapon's chambers: the SPT Realism mod's copy of them, Weapons/ReloadPatches.cs, read 2026-11-09),
-- so the gun does not fire it. A magazine's def.caliber is its own calibre; MAG_CALIBERS lists every calibre a family's
-- feed lips take (the KS-7's magazines are EFT's AK 7.62x39 ones: 7.6x39 and 9.6x39, our .366 TKM). Internal magazines and
-- tubes take their gun's calibre only, so every older gun loads as before (EFT's SKS internal magazine also takes .366 TKM,
-- which the SKS cannot fire; logged).
Items.MAG_CALIBERS = {
	KST = { "7.6", "9.6" },
}

-- can these rounds (an ammo def) go into this magazine, or into this gun's internal magazine or tube?
function Items.takesRound(d: any, ammoDef: any): boolean
	if not (d and ammoDef and ammoDef.kind == "ammo" and ammoDef.caliber) then
		return false
	end
	if d.kind == "mag" then
		local list = d.family and Items.MAG_CALIBERS[d.family]
		if list then
			return table.find(list, ammoDef.caliber) ~= nil
		end
		return d.caliber == ammoDef.caliber
	end
	return (d.kind == "weapon" or d.kind == "pistol") and d.capacity ~= nil and not d.family and d.caliber == ammoDef.caliber
end

-- does this gun (its item def) chamber these rounds (an ammo id or def)? Nothing loaded counts as yes: an empty
-- magazine stops nothing
function Items.fires(wd: any, ammo: any): boolean
	if ammo == nil then
		return true
	end
	local ad = ammo
	if type(ammo) == "string" then
		ad = defs[ammo]
	end
	return wd ~= nil and ad ~= nil and wd.caliber ~= nil and ad.caliber == wd.caliber
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
