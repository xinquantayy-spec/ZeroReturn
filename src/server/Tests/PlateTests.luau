--!nonstrict
-- Plate checks for decision gameplay-2a (Tarkov 0.14's armour): the pure maths and zones in Plates.luau, the armour
-- entries in Items, the plate slots and the old-save migration in Inv, and hits through Health on a rig that never
-- enters the world. Run via ZR_Dev "tests" (every module in Tests). Rolls are fixed where a check needs one outcome.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local Plates = require(Shared.Plates)

local T = {}

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

function T.run(ctx)
	local passed, failed, notes = 0, 0, {}
	local function check(name, cond)
		if cond then
			passed += 1
		else
			failed += 1
			table.insert(notes, "FAIL " .. name)
		end
	end
	local function guard(label, fn)
		local ok, err = pcall(fn)
		if not ok then
			check(label .. ": the checks ran without an error (" .. tostring(err) .. ")", false)
		end
	end
	local defs = Items.defs
	local P = Plates
	local function always()
		return 0 -- every chance above nothing succeeds
	end
	local function never()
		return 0.999999 -- only a sure thing succeeds
	end

	-- ── Tarkov's maths ──────────────────────────────────────────────────────────────────────────────────────────
	guard("maths", function()
		check("effective armour: intact class x 10 (EFT 0.14.6 notes: 'about its class x 10'), less when worn",
			near(P.armourValue(4, 1), 40.24, 0.01) and near(P.armourValue(6, 1), 60.35, 0.01) and P.armourValue(4, 0.5) < P.armourValue(4, 1) and P.armourValue(4, 0) < 5)
		check("penetration: no chance 15 or more below the armour (pen 25 against fresh class 4)", P.penChance(25, 4, 1) == 0)
		check("penetration: 90 % at equal values", near(P.penChance(P.armourValue(4, 1), 4, 1), 0.9, 1e-6))
		check("penetration: always 15 or more above (EFT 0.14.6), just under that about 97 %",
			P.penChance(56, 4, 1) == 1 and P.penChance(55, 4, 1) > 0.96 and P.penChance(55, 4, 1) < 1)
		check("penetration: worn armour lets more through (pen 30 against class 4 at 100 % and 50 %)", P.penChance(30, 4, 0.5) > P.penChance(30, 4, 1) and P.penChance(30, 4, 1) > 0)
		check("penetration: the INSPECT window's chances are the same curve (Items.penChance)",
			Items.penChance(43, 4, 1) == P.penChance(43, 4, 1) and Items.penChance(26, 2, 1) == P.penChance(26, 2, 1))
		check("damage through armour: 0-40 % lost, about 23 % at the threshold, nothing for a far better round (EFT wiki: PACA vs M995)",
			near(P.reduction(P.armourValue(4, 1), 4, 1), 0.7703, 1e-3) and P.reduction(53, 2, 1) == 1 and P.reduction(30, 6, 1) == 0.6)
		local b1, b2 = P.blunt(46, 20, 4, 1, 0.2, false), P.blunt(46, 20, 4, 1, 0.2, true)
		check("blunt: from the throughput, less with soft armour behind (x0.6, EFT globals), more for a harder round",
			b1 > 0 and near(b2, b1 * 0.6) and P.blunt(46, 30, 4, 1, 0.2, false) > b1 and near(P.blunt(100, 0, 6, 1, 0.3, false), 6))
		check("durability: at least 1 a hit, buckshot pellets too (EFT wiki)", P.durLoss(1, 0.65, 2, 0.1875, false) == 1)
		check("durability: a penetrating round takes 10 % less than a stopped one",
			near(P.durLoss(30, 0.5, 4, 0.3375, true), 0.9 * P.durLoss(30, 0.5, 4, 0.3375, false)))
		check("durability: steel wears faster than aramid; no penetration or no armour damage takes nothing",
			P.durLoss(30, 0.5, 4, P.MATERIALS.steel.destr, false) > P.durLoss(30, 0.5, 4, P.MATERIALS.aramid.destr, false) and P.durLoss(0, 0.5, 4, 0.5, false) == 0 and P.durLoss(30, 0, 4, 0.5, false) == 0)
		check("materials: EFT 1.0's destructibility (aramid 0.1875, UHMWPE 0.3375, ceramic 0.6, steel 0.525)",
			P.MATERIALS.aramid.destr == 0.1875 and P.MATERIALS.uhmwpe.destr == 0.3375 and P.MATERIALS.ceramic.destr == 0.6 and P.MATERIALS.steel.destr == 0.525)
		check("ricochet: none under the step's angle, its least chance at it, its greatest when grazing",
			P.ricochetChance("high", 50) == 0 and near(P.ricochetChance("high", 60), 0.4) and near(P.ricochetChance("high", 90), 0.8) and P.ricochetChance("low", 79) == 0)
	end)

	guard("resolve", function()
		local free = P.resolve({}, { dmg = 50, pen = 30, armorDmg = 0.4 }, always)
		check("resolve: no armour, the round goes in whole", free.penetrated and free.dmg == 50 and next(free.losses) == nil)
		local plate = { class = 4, cur = 40, max = 40, destr = 0.3375, blunt = 0.2 }
		local soft = { class = 2, cur = 22, max = 22, destr = 0.1875, blunt = 0.33, soft = true }
		local stop = P.resolve({ plate, soft }, { dmg = 46, pen = 20, armorDmg = 0.4 }, always)
		check("resolve: a plate stops a weak round; blunt under it is cut by the soft armour behind; only the plate wears",
			not stop.penetrated and stop.stop == 1 and near(stop.dmg, P.blunt(46, 20, 4, 1, 0.2, true)) and stop.losses[1] >= 1 and stop.losses[2] == nil)
		-- pen 30 has a small chance through class 4 (rolled through here): it keeps 60 % at the plate, then goes through
		-- the soft armour too and keeps 60 % of that
		local thru = P.resolve({ plate, soft }, { dmg = 60, pen = 30, armorDmg = 0.5 }, always)
		check("resolve: a round through both layers loses damage at each and wears both",
			thru.penetrated and near(thru.dmg, 60 * 0.6 * 0.6) and thru.losses[1] > 0 and thru.losses[2] > 0 and near(thru.pen, 30 * 0.6 * 0.6))
		local sure = P.resolve({ plate }, { dmg = 60, pen = 70, armorDmg = 0.5 }, never)
		check("resolve: a round 15 above the armour goes through even on the worst roll, keeping its damage",
			sure.penetrated and sure.dmg == 60)
		local helm = { class = 4, cur = 24, max = 24, destr = 0.375, blunt = 0.143, ric = "high" }
		local ric = P.resolve({ helm }, { dmg = 50, pen = 60, armorDmg = 0.5, angle = 85 }, always)
		local square = P.resolve({ helm }, { dmg = 50, pen = 60, armorDmg = 0.5, angle = 10 }, always)
		check("resolve: a grazing hit on a helmet can ricochet (no damage, 1 durability); a square hit never does",
			ric.ricochet and ric.dmg == 0 and ric.losses[1] == 1 and not square.ricochet)
	end)

	-- ── where a hit lands (R15 block rig sizes, RigSpec) ──────────────────────────────────────────────────────────
	guard("zones", function()
		local HH, UT, LT = Vector3.new(0.63, 0.58, 0.59), Vector3.new(1.08, 0.85, 0.54), Vector3.new(1.08, 0.2, 0.54)
		local function z(name, x, y, zz, h)
			return P.zoneOf(name, Vector3.new(x, y, zz), h).zone
		end
		check("head: the top cap, the eyes slit and the jaws in front, the ears at the sides, the nape behind, the low back no zone",
			z("Head", 0, 0.5, 0, HH) == "top" and z("Head", 0.2, 0.07, -0.58, HH) == "eyes" and z("Head", 0, -0.3, -0.58, HH) == "jaw"
				and z("Head", 0.63, 0, 0, HH) == "ears" and z("Head", 0, 0, 0.59, HH) == "nape" and z("Head", 0, -0.45, 0.59, HH) == "head")
		check("torso front: thorax above the ribcage line, stomach below, the throat in the middle of the collar",
			z("UpperTorso", 0, 0.3, -0.54, UT) == "chest" and z("UpperTorso", 0, -0.6, -0.54, UT) == "belly" and z("UpperTorso", 0, 0.75, -0.54, UT) == "throat"
				and z("UpperTorso", 0.8, 0.75, -0.54, UT) == "chest")
		check("torso back and sides: upper back, lower back, the back of the neck; upper sides (thorax) and sides (stomach)",
			z("UpperTorso", 0, 0.3, 0.54, UT) == "uback" and z("UpperTorso", 0, -0.6, 0.54, UT) == "lback" and z("UpperTorso", 0, 0.75, 0.54, UT) == "neck"
				and z("UpperTorso", -1.08, 0.2, 0, UT) == "lsideup" and z("UpperTorso", 1.08, -0.5, 0, UT) == "rside")
		check("pelvis: groin in front, buttocks behind (both stomach, EFT 0.14)", z("LowerTorso", 0, 0, -0.54, LT) == "groin" and z("LowerTorso", 0, 0, 0.54, LT) == "buttocks")
		check("pools: throat and upper sides hurt the thorax, groin and sides the stomach, the upper arm its arm",
			P.ZONES.throat.pool == "thorax" and P.ZONES.lsideup.pool == "thorax" and P.ZONES.groin.pool == "stomach" and P.ZONES.lside.pool == "stomach"
				and P.zoneOf("LeftUpperArm", Vector3.new(0, 0, -0.5), Vector3.new(0.52, 0.48, 0.52)).pool == "larm")
		local e = P.entry(Vector3.new(-30, 0, 0), Vector3.zero, UT)
		check("a blow aimed at the middle meets the surface on the side it came from", near(e.X, -1.08, 1e-6) and P.zoneOf("UpperTorso", e, UT).zone == "lsideup")
		local function w(x, y, zz)
			return P.zoneOf("UpperTorso", Vector3.new(x, y, zz), UT)
		end
		check("SAPI plate: the chest's middle, not its outer edge, not the stomach, not from behind",
			P.plateCovers("sapi", "front", w(0, 0.3, -0.54)) and not P.plateCovers("sapi", "front", w(1.0, 0.3, -0.54))
				and not P.plateCovers("sapi", "front", w(0, -0.3, -0.54)) and not P.plateCovers("sapi", "front", w(0, 0.3, 0.54)))
		check("Korund plate: reaches the top of the stomach, leaves the chest's upper outer corners",
			P.plateCovers("korund", "front", w(0, -0.25, -0.54)) and not P.plateCovers("korund", "front", w(0.7, 0.55, -0.54)) and P.plateCovers("korund", "front", w(0.3, 0.55, -0.54)))
		check("side plates: high under the armpit (thorax), never the armpit itself; low on the stomach's side",
			P.plateCovers("high", "lside", w(-1.08, 0.2, 0)) and not P.plateCovers("high", "lside", w(-1.08, 0.6, 0)) and P.plateCovers("low", "rside", w(1.08, -0.4, 0))
				and not P.plateCovers("low", "lside", w(1.08, -0.4, 0)))
	end)

	-- ── the armour entries ───────────────────────────────────────────────────────────────────────────────────────
	guard("items", function()
		local nPlates, okPlates, okParts, okDefaults, softMax = 0, true, true, true, 0
		for id, d in defs do
			if d.kind == "plate" then
				nPlates += 1
				local a, p = d.armor, d.plate
				okPlates = okPlates and a and a.class >= 3 and a.class <= 6 and a.dur > 0 and P.MATERIALS[a.mat] ~= nil and p ~= nil
					and (p.pos == "any" or p.pos == "front" or p.pos == "back" or p.pos == "side") and (p.fam == "west" or p.fam == "east") and d.mass > 0
			end
			if d.armor and d.armor.parts then
				local sum = 0
				for _, e in d.armor.parts do
					sum += e.dur
					for zn in e.zones do
						okParts = okParts and P.ZONES[zn] ~= nil
					end
					if (d.kind == "armor" or d.kind == "rig") then
						softMax = math.max(softMax, e.class)
					end
				end
				okParts = okParts and near(sum, d.armor.dur) and P.MATERIALS[d.armor.mat] ~= nil
				for s, e in P.slotsOf(d) or {} do
					local pd = e.def and defs[e.def]
					okDefaults = okDefaults and (e.def == nil or (pd ~= nil and P.fits(d, s, pd) == true))
				end
				if not okParts then
					table.insert(notes, "bad parts: " .. id)
				end
			end
		end
		check("16 plates, each with a class 3-6, durability, an EFT material, a position and a fit", nPlates == 16 and okPlates)
		check("every armour part lists real zones and the item's durability is their sum", okParts)
		check("every vest's default plates exist and fit their slots", okDefaults)
		check("soft armour stops at class 3 (EFT 0.14: 'most armour now only provides class 3 at most')", softMax == 3)
		check("old readers keep working: the vests keep their shown class, the mask its face zone, the glasses their eyes",
			defs.ARMOR_C4.armor.class == 4 and defs.ARMOR_C5.armor.class == 5 and defs.ARMOR_C6.armor.class == 6 and defs.MASK_WELDER.armor.zones.face == true
				and defs.GLASSES_BG1.armor.zones.eyes == true and defs.GLASSES_BG1.armor.dur == 25 and defs.HELMET_C2.armor.class == 2)
		check("a kit costs what the vest used to: PC-4 82,000, HP-5 165,000, Bulwark 330,000, plate rig 95,000 (Items.kitValue)",
			Items.kitValue("ARMOR_C4") == 82000 and Items.kitValue("ARMOR_C5") == 165000 and Items.kitValue("ARMOR_C6") == 330000 and Items.kitValue("RIG_PLATE") == 95000)
		check("fits: a front-only plate not in the back, an eastern plate not in a western rig, a side plate only in a side slot",
			not P.fits(defs.ARMOR_C5, "back", defs.PLATE_HP5F) and not P.fits(defs.RIG_PLATE, "front", defs.PLATE_PC4F) and P.fits(defs.RIG_PLATE, "front", defs.PLATE_CE6)
				and not P.fits(defs.ARMOR_C5, "front", defs.PLATE_HP5S) and P.fits(defs.ARMOR_C5, "lside", defs.PLATE_HP5S) and P.fits(defs.ARMOR_C4, "back", defs.PLATE_PE4))
		local gp = Items.gearPenalties({ slots = { armor = "a" }, items = { a = { id = "ARMOR_C5", mods = { front = "f" } }, f = { id = "PLATE_HP5F" } } })
		check("gear penalties: the plates in a worn vest add theirs", near(gp.speed, defs.ARMOR_C5.pen.speed + defs.PLATE_HP5F.pen.speed) and near(gp.ergo, defs.ARMOR_C5.pen.ergo + defs.PLATE_HP5F.pen.ergo))
	end)

	-- ── plate slots in the inventory ─────────────────────────────────────────────────────────────────────────────
	local Inv = ctx.Inv
	guard("inventory", function()
		local h = Inv.newHolder("profile")
		local cg, c = Inv.newItem("ARMOR_C5", 1, { dur = defs.ARMOR_C5.armor.dur * 0.5 })
		check("a new vest given a durability spreads it over its parts", c.sd ~= nil and near(c.sd.front, 23 * 0.5) and near(c.dur, defs.ARMOR_C5.armor.dur * 0.5))
		local okP = Inv.place(h, cg, c, { "stash" })
		local f, b, l, r = c.mods and c.mods.front, c.mods and c.mods.back, c.mods and c.mods.lside, c.mods and c.mods.rside
		check("a new vest comes with its default plates, worn like it, and the holder stays valid",
			okP and c.pf == true and f and b and l and r and h.items[f].id == "PLATE_HP5F" and near(h.items[f].dur, 30) and h.items[l].id == "PLATE_HP5S" and (Inv.check(h)))
		local mass = Inv.weight(h, { cg, f, b, l, r })
		check("the plates weigh with the vest (9.8 kg kit)", near(mass, 1.9 + 3.4 + 2.3 + 1.1 + 1.1, 1e-6))
		-- worn: no plate in or out (Tarkov 0.14)
		local okE = Inv.move(h, cg, { slot = "armor" })
		local _, eOut = Inv.detachPlate(h, cg, "front", { "stash" })
		local ug, u = Inv.newItem("PLATE_CE6", 1)
		Inv.place(h, ug, u, { "stash" })
		local _, eIn = Inv.attachPlate(h, cg, "back", ug, { "stash" })
		local _, eDrop = Inv.move(h, ug, { slot = "armor" })
		check("a worn vest takes no plate in or out: TAKE IT OFF FIRST (EFT 0.14 notes)", okE and eOut == "TAKE_OFF_FIRST" and eIn == "TAKE_OFF_FIRST" and eDrop == "TAKE_OFF_FIRST")
		Inv.autoPlace(h, cg, { "stash" }) -- taken off
		local okSwap = Inv.attachPlate(h, cg, "back", ug, { "stash" })
		check("taken off, a western plate swaps into its SAPI back slot and the old plate goes to the stash",
			okSwap and c.mods.back == ug and h.items[b] ~= nil and Inv.locate(h, b) == "grid" and (Inv.check(h)))
		local _, eFit = Inv.attachPlate(h, cg, "front", b, { "stash" })
		check("a back plate refused in the front slot (WRONG_SLOT)", eFit == "WRONG_SLOT")
		local okOut = Inv.detachPlate(h, cg, "lside", { "stash" })
		local outInGrid = Inv.locate(h, l) == "grid" -- (read before the drop puts it back in the vest)
		local _, _, at = Inv.locate(h, cg)
		local okDrop = at ~= nil and Inv.move(h, l, { c = "stash", x = at.x, y = at.y, r = 0 }) -- dropped on the vest's tile
		check("a side plate out of its slot, and back in by dropping it on the vest", okOut and outInGrid and okDrop and c.mods.lside == l and Inv.locate(h, l) == "mod" and (Inv.check(h)))
		-- a vest a player emptied stays empty when it moves
		Inv.detachPlate(h, cg, "front", { "stash" })
		local b2 = Inv.take(h, cg)
		Inv.give(h, b2, nil, { "stash" })
		check("an emptied slot stays empty when the vest moves (no new default plate)", c.mods.front == nil and (Inv.check(h)))
	end)

	guard("migration", function()
		-- a profile saved before gameplay-2a: one durability against the old maximum, no parts, no plates
		local h = Inv.newHolder("profile")
		h.items.V = { id = "ARMOR_C4", n = 1, dur = 33, dmax = 50 }
		h.items.H = { id = "HELMET_C3", n = 1, dur = 18 }
		h.items.G = { id = "GLASSES_BG1", n = 1, dur = 20 }
		h.grids.stash.V = { x = 1, y = 1, r = 0 }
		h.grids.stash.H = { x = 5, y = 1, r = 0 }
		h.grids.stash.G = { x = 8, y = 1, r = 0 }
		local n1 = Inv.migrateArmour(h)
		local v = h.items.V
		local f = v.mods and v.mods.front and h.items[v.mods.front]
		local b = v.mods and v.mods.back and h.items[v.mods.back]
		check("old save: the vest keeps its share (33 of 55 = 60 %) in every part and its plates come in at it",
			n1 == 2 and v.sd ~= nil and near(v.sd.front, 22 * 0.6) and near(v.dur, defs.ARMOR_C4.armor.dur * 0.6) and f ~= nil and f.id == "PLATE_PC4F" and near(f.dur, 30)
				and b ~= nil and near(b.dur, 24) and v.pf == true and near(v.dmax, defs.ARMOR_C4.armor.dur * 50 / 55))
		check("old save: the helmet's parts at its share (18 of 36), the glasses as they were",
			h.items.H.sd ~= nil and near(h.items.H.sd.top, 9) and near(h.items.H.dur, 18) and h.items.G.dur == 20 and h.items.G.sd == nil)
		local n2 = Inv.migrateArmour(h)
		check("old save: migrated once (a second run changes nothing) and the holder is valid", n2 == 0 and (Inv.check(h)))
		-- a trader's repair writes it.dur; the parts follow at one share
		v.dur = defs.ARMOR_C4.armor.dur * 0.9
		P.sync(v, defs.ARMOR_C4)
		check("a repair that sets the whole durability spreads it over the parts", near(v.sd.collar, 22 * 0.9) and near(v.dur, defs.ARMOR_C4.armor.dur * 0.9))
	end)

	-- ── hits through Health on a rig (never parented to the world) ────────────────────────────────────────────────
	guard("hits", function()
		local okR, rig = pcall(ctx.Chars.buildRig, "guard", 1)
		if not (okR and rig) then
			check("hits: a rig to shoot at (" .. tostring(rig) .. ")", false)
			return
		end
		local h = Inv.newHolder("raid")
		local function wear(slot, id)
			local g, it = Inv.newItem(id, 1)
			Inv.placeSlot(h, g, it, slot)
			return g, it
		end
		local vg, vest = wear("armor", "ARMOR_C4")
		local hg, helm = wear("head", "HELMET_C3")
		ctx.Health.attach(rig, { kind = "ai", holder = function()
			return h
		end })
		local hs = ctx.Health.get(rig)
		local ut, head = rig:FindFirstChild("UpperTorso"), rig:FindFirstChild("Head")
		local function shoot(part, lx, ly, lz, fx, fy, fz, dmg, pen)
			return ctx.Health.hit(rig, {
				dmg = dmg, pen = pen, armorDmg = 0.4, bleedL = 0, bleedH = 0, part = part,
				hitPos = part.CFrame * Vector3.new(lx, ly, lz), from = part.CFrame * Vector3.new(fx, fy, fz),
			})
		end
		local front = h.items[vest.mods.front]
		local f0, s0 = front.dur, vest.sd.front
		local thorax0 = hs.parts.thorax.hp
		local r1 = shoot(ut, 0, 0.3, -0.54, 0, 0.3, -30, 40, 20)
		check("a weak round to the chest stops on the front plate: blunt damage only, the plate wears, the soft armour behind does not",
			r1 ~= nil and r1.zone == "chest" and r1.part == "thorax" and not r1.penetrated and r1.armor == "PLATE_PC4F" and front.dur < f0 and vest.sd.front == s0
				and hs.parts.thorax.hp < thorax0 and thorax0 - hs.parts.thorax.hp < 40 * 0.33)
		local st0 = hs.parts.stomach.hp
		local r2 = shoot(ut, 0, -0.6, -0.54, 0, -0.6, -30, 30, 60)
		check("below the plate the stomach has only soft armour: a strong round goes through it and loses no damage",
			r2 ~= nil and r2.zone == "belly" and r2.part == "stomach" and r2.penetrated and r2.armor == "ARMOR_C4" and vest.sd.front < s0 and near(st0 - hs.parts.stomach.hp, 30, 1e-6))
		local r3 = shoot(ut, 0, 0.75, -0.54, 0, 0.75, -30, 5, 5)
		check("the throat is under the vest's collar and hurts the thorax", r3 ~= nil and r3.zone == "throat" and r3.part == "thorax" and r3.armor == "ARMOR_C4")
		local r4 = shoot(ut, -1.08, 0.6, 0, -30, 0.6, 0, 5, 5)
		check("the armpit: no vest covers it", r4 ~= nil and r4.zone == "lsideup" and r4.armor == nil and r4.penetrated)
		local r5 = shoot(head, 0, 0.5, 0, 0, 30, 0, 5, 5)
		local r6 = shoot(head, 0.63, 0, 0, 30, 0, 0, 5, 5)
		check("a cut helmet guards the top, not the ears", r5 ~= nil and r5.zone == "top" and r5.armor == "HELMET_C3" and r6 ~= nil and r6.zone == "ears" and r6.armor == nil)
		front.dur = 0
		local r7 = shoot(ut, 0, 0.3, -0.54, 0, 0.3, -30, 5, 5)
		check("a broken plate no longer protects; the soft armour behind still does", r7 ~= nil and r7.armor == "ARMOR_C4")
		ctx.Health.states[rig] = nil
		rig:Destroy()
		check("hits: the helmet and the vest stayed in the holder", h.items[hg] ~= nil and h.items[vg] ~= nil)
	end)

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T
