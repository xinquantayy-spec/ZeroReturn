--!nonstrict
-- Tarkov's armour since 0.14 (decision gameplay-2a): soft armour in zones, separate plates in the front, back and side
-- slots of plate carriers and armoured rigs, helmets in zones, and Tarkov's penetration, blunt and durability maths.
-- Pure data and functions only (no Instances, no services): Health.luau resolves every hit with it, Inv.luau keeps the
-- plate slots with it, the inventory and INSPECT draw it, Items.luau builds its armour entries with it, PlateTests checks it.
--
-- Where the numbers come from (EFT facts; what is ours says so where it is used):
-- - SPT's copy of EFT's globals (read as data only): an armour class resists class x 10 (armor.class[n].resistance), each
--   material's destructibility (ArmorMaterials), BluntDamageReduceFromSoftArmorMod 0.6, and the hit colliders of 0.14
--   (BodyPartColliderSettings: ParietalHead, BackHead, Ears, Eyes, Jaw, HeadCommon, NeckFront, NeckBack, RibcageUp,
--   RibcageLow, SpineTop, SpineDown, Left/RightSideChestUp, Left/RightSideChestDown, Pelvis, PelvisBack, arms, legs).
-- - EFT 0.14.0.0 patch notes (devtrackers.gg): the head split into zones that match helmet and mask protection, the
--   chest and stomach split into front, back and sides, the pelvis into groin and buttocks (both stomach); 37 plates
--   (7 chest, 6 back, 20 either, 4 side); plates cannot go in or out of a worn vest; armour protects only the zones it
--   covers, no vest covers the armpits, many have a collar for the neck; each built-in zone has its own durability.
-- - EFT 0.14.1.0 notes (consolepcgaming.com): every penetrated layer takes penetration and damage off the bullet; blunt
--   damage drops when soft armour sits behind the part that stopped the round.
-- - EFT 0.14.6.0 notes (sportskeeda.com): a round 15 or more above the armour's effective durability always goes through;
--   intact armour's effective durability is about its class x 10 and falls as it loses durability.
-- - EFT wiki, Ballistics: a penetrating round loses 0-40 % of its damage, about 20 % at the threshold, none for a PACA
--   against M995; durability % = current / original maximum; every hit takes at least 1 durability, a penetrating one
--   10-15 % less than a stopped one; the 1.0 destructibility table (the same as SPT's globals).
-- - eft-ammo.com: the helmet zones by angle: eyes and jaws the front 120 degrees (eyes a slit from the top zone to the
--   nose, jaws below), ears 60 degrees each side, the nape the back 120; the top a cap above the temples.
-- - The penetration curve, the blunt factor and the damage-loss clamp are the community's port of the game's code
--   (tarkov.dev's ballistic calculator; not reachable from here, so the constants are as that port has them, checked
--   against what the sources above say: about 90 % at equal values, none 15 below, always 15 above).
local P = {}

-- ── materials (EFT 1.0 ArmorMaterials, SPT globals; the EFT wiki Ballistics table has the same) ─────────────────────
P.MATERIALS = {
	aramid = { name = "ARAMID", destr = 0.1875, expl = 0.15 },
	uhmwpe = { name = "UHMWPE", destr = 0.3375, expl = 0.3 },
	combined = { name = "COMBINED MATERIALS", destr = 0.375, expl = 0.2 },
	titan = { name = "TITANIUM", destr = 0.4125, expl = 0.375 },
	aluminium = { name = "ALUMINIUM", destr = 0.45, expl = 0.45 },
	steel = { name = "ARMORED STEEL", destr = 0.525, expl = 0.45 },
	ceramic = { name = "CERAMIC", destr = 0.6, expl = 0.525 },
	glass = { name = "GLASS", destr = 0.6, expl = 0.6 },
}
P.SOFT_BEHIND = 0.6 -- BluntDamageReduceFromSoftArmorMod (SPT globals): blunt under a stopped plate with soft armour behind it

-- ── hit zones (EFT 0.14's colliders; pool = the health part they hurt) ─────────────────────────────────────────────
-- The throat and the back of the neck were head zones in 0.14.0; players report them moved to the chest later (Reddit
-- r/EscapefromTarkov, January 2025: "they moved the hitbox to the chest"), so they hurt the thorax here.
P.ZONES = {
	top = { name = "HEAD TOP", pool = "head", col = "ParietalHead" },
	nape = { name = "NAPE", pool = "head", col = "BackHead" },
	ears = { name = "EARS", pool = "head", col = "Ears" },
	eyes = { name = "EYES", pool = "head", col = "Eyes" },
	jaw = { name = "JAWS", pool = "head", col = "Jaw" },
	head = { name = "HEAD", pool = "head", col = "HeadCommon" },
	throat = { name = "THROAT", pool = "thorax", col = "NeckFront" },
	neck = { name = "BACK NECK", pool = "thorax", col = "NeckBack" },
	chest = { name = "THORAX", pool = "thorax", col = "RibcageUp" },
	uback = { name = "UPPER BACK", pool = "thorax", col = "SpineTop" },
	lsideup = { name = "UPPER LEFT SIDE", pool = "thorax", col = "LeftSideChestUp" },
	rsideup = { name = "UPPER RIGHT SIDE", pool = "thorax", col = "RightSideChestUp" },
	belly = { name = "STOMACH", pool = "stomach", col = "RibcageLow" },
	lback = { name = "LOWER BACK", pool = "stomach", col = "SpineDown" },
	lside = { name = "LEFT SIDE", pool = "stomach", col = "LeftSideChestDown" },
	rside = { name = "RIGHT SIDE", pool = "stomach", col = "RightSideChestDown" },
	groin = { name = "GROIN", pool = "stomach", col = "Pelvis" },
	buttocks = { name = "BUTTOCKS", pool = "stomach", col = "PelvisBack" },
	lshoulder = { name = "LEFT SHOULDER", pool = "larm", col = "LeftUpperArm" },
	rshoulder = { name = "RIGHT SHOULDER", pool = "rarm", col = "RightUpperArm" },
	larm = { name = "LEFT FOREARM", pool = "larm", col = "LeftForearm" },
	rarm = { name = "RIGHT FOREARM", pool = "rarm", col = "RightForearm" },
	lthigh = { name = "LEFT THIGH", pool = "lleg", col = "LeftThigh" },
	rthigh = { name = "RIGHT THIGH", pool = "rleg", col = "RightThigh" },
	lcalf = { name = "LEFT CALF", pool = "lleg", col = "LeftCalf" },
	rcalf = { name = "RIGHT CALF", pool = "rleg", col = "RightCalf" },
}
-- the order INSPECT lists armoured zones in
P.ZONE_ORDER = {
	"top", "nape", "ears", "eyes", "jaw", "throat", "neck", "chest", "uback", "lsideup", "rsideup", "belly", "lback", "lside",
	"rside", "groin", "buttocks", "lshoulder", "rshoulder",
}
-- group names an armour entry may use for several zones (the welding mask's "face")
P.ALIAS = { face = { "eyes", "jaw" } }

-- Built-in armour parts (EFT's soft armour inserts and helmet parts): each has its own durability (0.14). A def's part
-- may list its own zones (a carrier whose back panel covers only the upper back).
P.PARTS = {
	front = { name = "FRONT", zones = { "chest", "belly" } },
	back = { name = "BACK", zones = { "uback", "lback" } },
	left = { name = "LEFT SIDE", zones = { "lside" } },
	right = { name = "RIGHT SIDE", zones = { "rside" } },
	collar = { name = "COLLAR", zones = { "throat", "neck" } },
	groin = { name = "GROIN", zones = { "groin" } },
	buttocks = { name = "BUTTOCKS", zones = { "buttocks" } },
	shoulders = { name = "SHOULDERS", zones = { "lshoulder", "rshoulder" } },
	top = { name = "TOP", zones = { "top" } },
	nape = { name = "NAPE", zones = { "nape" } },
	ears = { name = "EARS", zones = { "ears" } },
	visor = { name = "FACE SHIELD", zones = { "eyes", "jaw" }, visor = true }, -- raised (Tarkov's N) it protects nothing
	face = { name = "FACE", zones = { "eyes", "jaw" } },
	eyes = { name = "EYES", zones = { "eyes" } },
}

-- Plate slots of carriers and armoured rigs (EFT: Front_plate, Back_plate, Left_side_plate, Right_side_plate)
P.SLOTS = { "front", "back", "lside", "rside" }
P.SLOT_NAMES = { front = "FRONT PLATE", back = "BACK PLATE", lside = "LEFT SIDE PLATE", rside = "RIGHT SIDE PLATE" }
local SIDE = { lside = true, rside = true }
P.SIDE = SIDE

-- Ricochet (helmets and face shields). EFT gives each piece RicochetParams (x the greatest chance, y the smallest, z the
-- smallest angle that can deflect) and labels them low / medium / high; the per-item numbers were out of reach, so these
-- three steps are ours. The angle is between the bullet's path and the surface's normal: 0 head-on, 90 grazing.
P.RICOCHET = {
	low = { x = 0.3, y = 0.1, z = 80 },
	medium = { x = 0.5, y = 0.25, z = 70 },
	high = { x = 0.8, y = 0.4, z = 60 },
}

-- ── where a hit lands ────────────────────────────────────────────────────────────────────────────────────────────
-- The block R15 rig (RigSpec): UpperTorso is chest and belly together (1.7 studs), LowerTorso the pelvis. A human's
-- ribcage is about the top 60 % of the trunk above the pelvis, so the thorax ends 0.15 studs below the UpperTorso's middle
-- (ours, from the rig's proportions): v below Y0 on it is the stomach.
local Y0 = -0.176
P.Y0 = Y0
local NECK_U, NECK_V = 0.32, 0.7 -- the neck: the middle third of the UpperTorso's top band (ours)
local ARMPIT_V = 0.41 -- above this on the UpperTorso's sides: the armpits, which no vest covers (0.14 notes)
local HEAD_TOP, HEAD_EYES, HEAD_LOW = 0.43, -0.1, -0.6 -- head bands, in the head's half-height (ours, on eft-ammo's layout)

-- the point where the line from `from` to `to` (both in the part's own space) first meets the box of half-size h.
-- A ray's hit on the surface stays where it is (a bullet's arc is not the straight line from the muzzle); a point inside
-- the box (a blow or a blast aimed at the part's middle, or a hit on a rounded mesh) moves out along the line to the
-- face it came through; `to` itself when there is no line or it misses the box.
function P.entry(from, to, h)
	if not from or math.max(math.abs(to.X / h.X), math.abs(to.Y / h.Y), math.abs(to.Z / h.Z)) >= 0.97 then
		return to
	end
	local d = to - from
	local t0, t1 = -math.huge, math.huge
	for _, ax in { "X", "Y", "Z" } do
		local o, dd, e = from[ax], d[ax], h[ax]
		if math.abs(dd) < 1e-9 then
			if o < -e or o > e then
				return to
			end
		else
			local a, b = (-e - o) / dd, (e - o) / dd
			if a > b then
				a, b = b, a
			end
			t0 = math.max(t0, a)
			t1 = math.min(t1, b)
		end
	end
	if t0 > t1 or t1 < 0 or t0 < 0 then
		return to
	end
	return from + d * t0
end

-- which face of a box a surface point lies on, and where on it: face, u (across), v (up), both -1..1. Faces: "front"
-- (-Z, the way a character faces), "back", "left" (-X), "right", "top", "bottom". u runs along X on the front and back
-- faces and along Z on the sides; v is always Y.
function P.faceOf(lp, h)
	local nx, ny, nz = lp.X / h.X, lp.Y / h.Y, lp.Z / h.Z
	local ax, ay, az = math.abs(nx), math.abs(ny), math.abs(nz)
	if ay >= ax and ay >= az and ay > 0.98 then
		return ny > 0 and "top" or "bottom", nx, nz
	end
	if ax >= az then
		return nx < 0 and "left" or "right", nz, ny
	end
	return nz < 0 and "front" or "back", nx, ny
end

local LIMBS = {
	LeftUpperArm = "lshoulder", RightUpperArm = "rshoulder", LeftLowerArm = "larm", LeftHand = "larm", RightLowerArm = "rarm",
	RightHand = "rarm", LeftUpperLeg = "lthigh", RightUpperLeg = "rthigh", LeftLowerLeg = "lcalf", LeftFoot = "lcalf",
	RightLowerLeg = "rcalf", RightFoot = "rcalf",
}

-- the zone a hit on body part `name` lands in. lp = the hit point in the part's own space (on its surface), h = the
-- part's half-size. Returns { zone, pool, face, u, v }.
function P.zoneOf(name, lp, h)
	local face, u, v = P.faceOf(lp, h)
	local zone
	if name == "Head" then
		-- eft-ammo's layout: a cap on top; below it eyes and jaws in the front 120 degrees, ears 60 each side, the nape
		-- behind; the lowest band at the sides and back belongs to no helmet zone (EFT's HeadCommon)
		local ny = lp.Y / h.Y
		local ang = math.deg(math.atan2(math.abs(lp.X / h.X), -lp.Z / h.Z)) -- 0 = straight ahead, 180 = behind
		if ny > HEAD_TOP or face == "top" then
			zone = "top"
		elseif ang <= 60 then
			zone = ny > HEAD_EYES and "eyes" or "jaw"
		elseif ny <= HEAD_LOW then
			zone = "head"
		elseif ang <= 120 then
			zone = "ears"
		else
			zone = "nape"
		end
	elseif name == "UpperTorso" or name == "Torso" then
		if face == "top" then
			-- from above: the neck in the middle, the shoulders' tops either side
			if math.abs(u) <= NECK_U then
				zone = v < 0 and "throat" or "neck"
			else
				zone = v < 0 and "chest" or "uback"
			end
		elseif face == "bottom" then
			zone = v < 0 and "belly" or "lback"
		elseif face == "front" or face == "back" then
			local f = face == "front"
			if v > NECK_V and math.abs(u) <= NECK_U then
				zone = f and "throat" or "neck"
			elseif v > Y0 then
				zone = f and "chest" or "uback"
			else
				zone = f and "belly" or "lback"
			end
		else
			local l = face == "left"
			if v > Y0 then
				zone = l and "lsideup" or "rsideup"
			else
				zone = l and "lside" or "rside"
			end
		end
	elseif name == "LowerTorso" then
		if face == "top" then
			zone = v < 0 and "belly" or "lback"
		elseif face == "front" then
			zone = "groin"
		elseif face == "back" then
			zone = "buttocks"
		elseif face == "bottom" then
			zone = v < 0 and "groin" or "buttocks"
		else
			zone = u < 0 and "groin" or "buttocks" -- a side face: u runs along Z, front is -Z
		end
	else
		zone = LIMBS[name] or "chest"
	end
	return { zone = zone, pool = P.ZONES[zone].pool, face = face, u = u, v = v }
end

-- the angle (degrees) between a bullet's path and the head's surface where it lands: 0 head-on, 90 grazing. The head is
-- taken as the ellipsoid inside its box (ours: the game uses the mesh's normal).
function P.incidence(lp, h, dir)
	local n = Vector3.new(lp.X / (h.X * h.X), lp.Y / (h.Y * h.Y), lp.Z / (h.Z * h.Z))
	if n.Magnitude < 1e-6 or dir.Magnitude < 1e-6 then
		return 0
	end
	local c = math.clamp(-dir.Unit:Dot(n.Unit), -1, 1)
	return math.deg(math.acos(c))
end

-- ── plates: where each format covers (EFT 0.14: "plate zones follow the average size of real plates of that format") ─
-- u across the face, v up it (P.faceOf). SAPI: a rectangle over the chest or the upper back; Korund (Eastern): taller,
-- reaching the top of the stomach, with the upper outer corners cut ("Eastern plates leave a small thorax area
-- uncovered", GGRecon); side plates: "high" on the thorax side under the armpit (Korund-VM), "low" on the stomach side
-- (6B43's Granit sides). The sizes are ours, measured off the rig.
P.SHAPES = {
	sapi = { u = 0.74, v0 = Y0, v1 = 0.73, zones = { chest = true, uback = true } },
	korund = { u = 0.79, v0 = Y0 - 0.24, v1 = 0.73, cutU = 0.51, cutV = 0.47, zones = { chest = true, uback = true, belly = true, lback = true } },
	high = { u = 0.78, v0 = Y0, v1 = ARMPIT_V, zones = { lsideup = true, rsideup = true } },
	low = { u = 0.78, v0 = -0.71, v1 = Y0, zones = { lside = true, rside = true } },
}
local FACE_OF_SLOT = { front = "front", back = "back", lside = "left", rside = "right" }

-- does a plate of `shape` in carrier slot `slot` cover the hit `w` (from P.zoneOf on the UpperTorso)?
function P.plateCovers(shape, slot, w)
	local s = P.SHAPES[shape]
	if not s or not w or FACE_OF_SLOT[slot] ~= w.face or not s.zones[w.zone] then
		return false
	end
	if math.abs(w.u) > s.u or w.v <= s.v0 or w.v > s.v1 then
		return false
	end
	if s.cutU and math.abs(w.u) > s.cutU and w.v > s.cutV then
		return false
	end
	return true
end

-- ── Tarkov's maths ─────────────────────────────────────────────────────────────────────────────────────────────
-- the armour's effective resistance at a durability fraction (EFT: class x 10 when intact, falling with durability)
function P.armourValue(class, durFrac)
	local pct = math.clamp(durFrac or 1, 0, 1) * 100
	return (class or 0) * 10 * (121 - 5000 / (45 + pct * 2)) / 100
end

-- the chance (0..1) a round of penetration `pen` goes through armour of `class` at durability fraction `durFrac`
function P.penChance(pen, class, durFrac)
	local d = P.armourValue(class, durFrac)
	pen = pen or 0
	if pen >= d + 15 then
		return 1 -- EFT 0.14.6.0: 15 or more above always goes through
	end
	if d >= pen + 15 then
		return 0
	end
	if d >= pen then
		return 0.4 * (d - pen - 15) ^ 2 / 100
	end
	return math.clamp((100 + pen / (0.9 * d - pen)) / 100, 0, 1)
end

-- what a penetrating round keeps of its damage and its penetration after a layer (EFT: 0-40 % lost, about 20 % at the
-- threshold; nothing lost when it far outclasses the armour)
function P.reduction(pen, class, durFrac)
	return math.clamp((pen or 0) / (P.armourValue(class, durFrac) + 12), 0.6, 1)
end

-- the blunt damage a stopped round still does to the body part (EFT: from the armour's blunt throughput, its class and
-- durability and the round's penetration; less with soft armour behind the part that stopped it)
function P.blunt(dmg, pen, class, durFrac, throughput, softBehind)
	local d = P.armourValue(class, durFrac)
	local k = math.clamp(1 - 0.03 * (d - (pen or 0)), 0.2, 1)
	return (dmg or 0) * (throughput or 0.3) * k * (softBehind and P.SOFT_BEHIND or 1)
end

-- the durability a hit takes off a piece of armour. EFT (wiki): from the round's penetration against the class, times
-- the round's armour damage and the material's destructibility, at least 1; a penetrating round 10-15 % less. The clamp
-- and the 10 % are ours, in that shape. No penetration or no armour damage (a fall, a blast's push) takes nothing.
function P.durLoss(pen, armorDmg, class, destr, penetrated)
	pen, armorDmg = pen or 0, armorDmg or 0
	if pen <= 0 or armorDmg <= 0 then
		return 0
	end
	local k = math.clamp(pen / math.max(10, (class or 1) * 10), 0.5, 0.9)
	return math.max(1, pen * armorDmg * (destr or 0.5) * k * (penetrated and 0.9 or 1))
end

-- the chance (0..1) a hit at `angle` degrees off head-on deflects from a piece with ricochet step `tier` (P.RICOCHET)
function P.ricochetChance(tier, angle)
	local r = type(tier) == "table" and tier or P.RICOCHET[tier or ""]
	if not r or not angle or angle < r.z then
		return 0
	end
	local t = math.clamp((angle - r.z) / math.max(1, 90 - r.z), 0, 1)
	return r.y + (r.x - r.y) * t
end

-- Resolve one hit through the layers it meets, outermost first. Each layer: { class, cur, max, destr, blunt, soft, ric }.
-- shot: { dmg, pen, armorDmg, angle? }. roll() -> 0..1. Returns { penetrated, dmg, pen, losses = { [i] = durability },
-- stop (the layer that stopped it), ricochet }. Pure: the caller writes the durability back.
function P.resolve(layers, shot, roll)
	local out = { penetrated = true, dmg = shot.dmg or 0, pen = shot.pen or 0, losses = {}, ricochet = false }
	for i, L in layers do
		if L.ric and shot.angle then
			local rc = P.ricochetChance(L.ric, shot.angle)
			if rc > 0 and roll() < rc then
				-- a deflected round does next to nothing and takes the minimum off the piece (eft-ammo.com)
				out.losses[i] = math.min(1, L.cur)
				out.ricochet, out.penetrated, out.dmg, out.stop = true, false, 0, i
				return out
			end
		end
		local frac = (L.max or 0) > 0 and L.cur / L.max or 0
		local through = roll() < P.penChance(out.pen, L.class, frac)
		out.losses[i] = math.min(L.cur, P.durLoss(out.pen, shot.armorDmg, L.class, L.destr, through))
		if through then
			local f = P.reduction(out.pen, L.class, frac)
			out.dmg *= f
			out.pen *= f
		else
			local behind = false
			for j = i + 1, #layers do
				behind = behind or layers[j].soft == true
			end
			out.dmg = P.blunt(out.dmg, out.pen, L.class, frac, L.blunt, behind)
			out.penetrated, out.stop = false, i
			return out
		end
	end
	return out
end

-- ── armour entries (Items.luau builds them with P.armour) ─────────────────────────────────────────────────────────
-- a = { class (shown: the best class with the default plates in), pc (the parts' class when it differs: a carrier's soft
-- armour), mat, blunt, type ("light" / "heavy", EFT's armour type for the vests skills), ric, parts = { { k, dur, zones?,
-- class?, mat?, blunt? }, ... }, plates = { [slot] = { fams = { west | east = true }, side = "high" | "low" (side slots),
-- def = default plate id } } }. Fills dur (all parts), destr (the material's), zones (a set of every zone the parts cover,
-- with the aliases a part used).
function P.armour(a)
	local mat = P.MATERIALS[a.mat or "aramid"] or P.MATERIALS.aramid
	a.destr = a.destr or mat.destr
	local total, zones = 0, {}
	for i, p in a.parts or {} do
		local e = {
			k = p.k or p[1], dur = p.dur or p[2], class = p.class or a.pc or a.class, mat = p.mat or a.mat,
			blunt = p.blunt or a.blunt, ric = p.ric or a.ric,
		}
		local base = P.PARTS[e.k]
		e.name = (base and base.name) or string.upper(e.k)
		e.visor = base and base.visor or nil
		local zl = p.zones or (base and base.zones) or {}
		e.zones = {}
		for _, z in zl do
			if P.ALIAS[z] then
				zones[z] = true
				for _, az in P.ALIAS[z] do
					e.zones[az] = true
				end
			else
				e.zones[z] = true
			end
		end
		for z in e.zones do
			zones[z] = true
		end
		e.destr = (P.MATERIALS[e.mat or ""] or mat).destr
		total += e.dur
		a.parts[i] = e
	end
	a.dur = a.dur or total
	a.zones = zones
	return a
end

-- the built-in parts of an armour def, or nil
function P.partsOf(d)
	return d and d.armor and d.armor.parts
end

-- items made before parts (one durability for the whole vest) and single-part items keep only it.dur
function P.multi(d)
	local parts = P.partsOf(d)
	return parts ~= nil and #parts > 1
end

-- the current durability of part `k` of item `it`
function P.partDur(it, d, k)
	local parts = P.partsOf(d)
	if not parts then
		return 0
	end
	local p
	for _, e in parts do
		if e.k == k then
			p = e
		end
	end
	if not p then
		return 0
	end
	if it.sd and it.sd[k] then
		return it.sd[k]
	end
	-- no per-part record: the part's share of the whole
	local total = d.armor.dur
	return p.dur * math.clamp((it.dur or total) / math.max(total, 1e-6), 0, 1)
end

-- a durability kept to a tenth (a share like 22 x 0.6 would otherwise read 13.200000000000001, and the inventory's
-- rounding up shows 30.000000000000004 as 31)
local function tenth(x)
	return math.floor(x * 10 + 0.5) / 10
end
P.tenth = tenth

-- give a new (or migrated) item its parts' durability at `frac` of their maximum; it.dur becomes their sum
function P.initParts(it, d, frac)
	if not P.multi(d) then
		it.dur = tenth(d.armor.dur * math.clamp(frac or 1, 0, 1))
		return
	end
	it.sd = {}
	local sum = 0
	for _, e in P.partsOf(d) do
		local v = tenth(e.dur * math.clamp(frac or 1, 0, 1))
		it.sd[e.k] = v
		sum += v
	end
	it.dur = tenth(sum)
end

-- something outside this module changed it.dur (a trader's repair sets it to the new maximum): the parts follow, each
-- at the same share of its maximum
function P.sync(it, d)
	if not (it.sd and P.multi(d)) then
		return
	end
	local sum = 0
	for _, v in it.sd do
		sum += v
	end
	if it.dur == nil or math.abs(sum - it.dur) <= 0.01 then
		return
	end
	local f = math.clamp(it.dur / math.max(d.armor.dur, 1e-6), 0, 1)
	sum = 0
	for _, e in P.partsOf(d) do
		local v = tenth(e.dur * f)
		it.sd[e.k] = v
		sum += v
	end
	it.dur = tenth(sum)
end

-- set part `k` of item `it` to `v` (it.dur follows)
function P.setPart(it, d, k, v)
	if not P.multi(d) then
		it.dur = math.max(0, v)
		return
	end
	if not it.sd then
		P.initParts(it, d, (it.dur or d.armor.dur) / math.max(d.armor.dur, 1e-6))
	end
	it.sd[k] = math.max(0, v)
	local sum = 0
	for _, x in it.sd do
		sum += x
	end
	it.dur = sum
end

-- ── carriers ───────────────────────────────────────────────────────────────────────────────────────────────────
-- the plate slots of a carrier def: { [slot] = { fams, side?, def? } }, or nil
function P.slotsOf(d)
	return d and d.armor and d.armor.plates
end

-- can plate def `pd` go into slot `slot` of carrier def `cd`?
function P.fits(cd, slot, pd)
	local slots = P.slotsOf(cd)
	local s = slots and slots[slot]
	if not s then
		return false, "NO_SLOT"
	end
	local p = pd and pd.plate
	if not p then
		return false, "NOT_A_PLATE"
	end
	if (p.pos == "side") ~= (SIDE[slot] == true) or (p.pos == "front" and slot ~= "front") or (p.pos == "back" and slot ~= "back") then
		return false, "WRONG_SLOT"
	end
	if not s.fams[p.fam] then
		return false, "WRONG_FIT"
	end
	return true, nil
end

-- the format a plate covers in a slot: the carrier's side position for side slots, the plate's own shape otherwise
function P.shapeOf(cd, slot, pd)
	local s = P.slotsOf(cd)
	s = s and s[slot]
	if SIDE[slot] then
		return s and s.side or "low"
	end
	return pd and pd.plate and pd.plate.shape or "sapi"
end

-- the first empty slot of a carrier that takes the plate, then the first filled one it could replace
function P.freeSlot(cd, mods, pd)
	for _, s in P.SLOTS do
		if not (mods and mods[s]) and P.fits(cd, s, pd) then
			return s
		end
	end
	return nil
end

function P.swapSlot(cd, mods, pd)
	for _, s in P.SLOTS do
		if mods and mods[s] and P.fits(cd, s, pd) then
			return s
		end
	end
	return nil
end

-- the class a carrier shows: its best part or plate in place (defs = Items.defs, items = the holder's items)
function P.classOf(defs, items, it)
	local d = it and defs[it.id]
	if not (d and d.armor) then
		return 0
	end
	local best = 0
	for _, e in P.partsOf(d) or {} do
		best = math.max(best, e.class or 0)
	end
	if not P.partsOf(d) then
		best = d.armor.class or 0
	end
	for _, s in P.SLOTS do
		local pg = it.mods and it.mods[s]
		local p = pg and items and items[pg]
		local pd = p and defs[p.id]
		if pd and pd.armor then
			best = math.max(best, pd.armor.class or 0)
		end
	end
	return best
end

-- names of the zones an armour def covers (with what its default plates add), in INSPECT order
function P.zoneNames(set)
	local out = {}
	for _, z in P.ZONE_ORDER do
		if set[z] then
			table.insert(out, P.ZONES[z].name)
		end
	end
	return out
end

-- the zones a plate protects in a slot (for INSPECT): the shape's zones on that slot's face
function P.plateZones(cd, slot, pd)
	local shape = P.SHAPES[P.shapeOf(cd, slot, pd)]
	local out = {}
	if not shape then
		return out
	end
	local face = FACE_OF_SLOT[slot]
	for z in shape.zones do
		local ok = (face == "front" and (z == "chest" or z == "belly")) or (face == "back" and (z == "uback" or z == "lback"))
			or (face == "left" and (z == "lsideup" or z == "lside")) or (face == "right" and (z == "rsideup" or z == "rside"))
		if ok then
			out[z] = true
		end
	end
	return out
end

-- Durability of each armour item before gameplay-2a (old saves: Inv.migrateArmour keeps the share it had)
P.OLD_DUR = {
	ARMOR_C2 = 40, ARMOR_C3 = 50, ARMOR_C4 = 55, ARMOR_C5 = 70, ARMOR_C6 = 85, RIG_PLATE = 50,
	HELMET_C2 = 30, HELMET_C3 = 36, HELMET_C4 = 45, HELMET_C5 = 60, HARDHAT_FOREMAN = 22,
}

return P
