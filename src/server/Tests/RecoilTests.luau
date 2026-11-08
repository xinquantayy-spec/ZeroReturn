--!nonstrict
-- Recoil checks for audit decision gameplay-1a (Tarkov's recoil model): the pure rules in Recoil.luau, the guns'
-- recoil fields in Weapons.luau and the parts' figures in WeaponParts.luau. Run via ZR_Dev "tests" (every module in
-- Tests). Pure functions only: nothing here touches the world or a player.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Recoil = require(Shared.Recoil)
local Weapons = require(Shared.Weapons)
local WP = require(Shared.WeaponParts)
local Progress = require(Shared.Progress)

local T = {}

local GUNS = { "R17", "KST", "SPARROW", "HARROW", "TUNDRA", "P9" }

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local function mean(list, i, j)
	local s = 0
	for k = i, j do
		s += list[k]
	end
	return s / (j - i + 1)
end

-- n shots at the gun's rate, the springs stepped in frames of dt between them. o: rec (the build's recoil multiplier),
-- ergo, skills, stance, depth, dt, rng (nil: every draw in the middle, so the kick goes straight along the angle).
-- Returns the climb just before each next shot, the highest climb, the widest sideways throw, the state and profile.
local function burst(def, n, o)
	o = o or {}
	local prof = Recoil.profile(def, o.rec or 1, o.ergo or def.ergo, o.skills)
	local st = Recoil.new()
	local period = 60 / def.rpm
	local dt = o.dt or 1 / 30
	local pv, ph, pb = Recoil.pose(o.stance or "s", o.depth)
	local rng = o.rng
	local idx, top, side = 0, 0, 0
	local after = {}
	for k = 1, n do
		idx = Recoil.nextIndex(idx, k == 1 and 10 or period, period)
		local u1 = rng and rng:NextNumber() or 0.5
		local u2 = rng and rng:NextNumber() or 0.5
		local jp, jy = Recoil.kick(prof, idx, pv, ph, pb, u1, u2, 0.5)
		Recoil.shot(st, prof, jp, jy)
		local left = period
		while left > 1e-9 do
			local h = math.min(dt, left)
			Recoil.step(st, h)
			left -= h
			local gp, gy = Recoil.gun(st)
			top = math.max(top, gp)
			side = math.max(side, math.abs(gy))
		end
		after[k] = (Recoil.gun(st))
	end
	return after, top, side, st, prof
end

-- a base's default build as an item tree (GunMeta's preset), with parts swapped by id; returns items, root guid
local function buildOf(baseId, swap)
	local items, n = {}, 0
	local function add(t)
		n += 1
		local g = "t" .. n
		local it = { id = (swap and swap[t[1]]) or t[1] }
		items[g] = it
		for sname, sub in t[2] do
			if sname ~= "mag" then
				it.mods = it.mods or {}
				it.mods[sname] = add(sub)
			end
		end
		return g
	end
	local root = add(WP.META.presets[baseId].tree)
	return items, root
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
	local R17 = Weapons.R17
	local ELITE = Progress.SKILL_CAP

	-- ── full auto levels off, and convergence brings the aim back ─────────────────────────────────────────────────
	guard("full auto", function()
		local after, top, _, st = burst(R17, 30)
		-- the old rule: 60 % of each aimed kick (1.05 x 0.72 degrees) moved the aim for good
		local old = 30 * 1.05 * 0.72 * 0.6
		check(string.format("an R-17 30-round burst levels off: shots 21-30 hang no higher than 11-20 (%.2f, %.2f)", mean(after, 21, 30), mean(after, 11, 20)), mean(after, 21, 30) <= mean(after, 11, 20) + 0.05)
		check(string.format("... and tops out at %.2f degrees, where the old permanent kick climbed %.1f", top, old), top < 4 and after[30] < 2.5 and top < old / 3)
		check("the first shots fly up most, then it settles back down in auto (Tarkov's vanilla, Fontaine's description)", top > 1.4 * mean(after, 21, 30))
		for _ = 1, 45 do
			Recoil.step(st, 1 / 30)
		end
		local gp, gy = Recoil.gun(st)
		local cp, cy = Recoil.cam(st)
		check("convergence returns the gun and the camera to the aim point within 1.5 s of letting go", math.abs(gp) < 0.01 and math.abs(gy) < 0.01 and math.abs(cp) < 0.01 and math.abs(cy) < 0.01)
		local _, _, side = burst(R17, 30, { rng = Random.new(3) })
		check(string.format("random dispersion throws the burst sideways, and convergence keeps it near the aim (%.2f deg)", side), side > 0.05 and side < 1.5)
	end)

	-- ── frame rate: phones at 30 fps climb exactly as PCs at 144 ──────────────────────────────────────────────────
	guard("frame rate", function()
		local prof = Recoil.profile(R17, 1, 50, nil)
		local a, b = Recoil.new(), Recoil.new()
		Recoil.shot(a, prof, 1.2, 0.3)
		Recoil.shot(b, prof, 1.2, 0.3)
		Recoil.step(a, 0.1)
		for _ = 1, 14 do
			Recoil.step(b, 0.1 / 14)
		end
		local ap, ay = Recoil.gun(a)
		local bp, by = Recoil.gun(b)
		local acp = Recoil.cam(a)
		local bcp = Recoil.cam(b)
		check("the springs step exactly: one 0.1 s step lands where fourteen small ones do", near(ap, bp, 1e-9) and near(ay, by, 1e-9) and near(acp, bcp, 1e-9))
		local a30 = burst(R17, 30, { dt = 1 / 30 })
		local a144 = burst(R17, 30, { dt = 1 / 144 })
		check("a 30-round burst ends at the same climb at 30 and 144 fps", near(a30[30], a144[30], 1e-9) and near(a30[5], a144[5], 1e-9))
	end)

	-- ── one shot: its peak, the camera's share ─────────────────────────────────────────────────────────────────────
	guard("one shot", function()
		local ok = true
		for _, id in GUNS do
			local def = Weapons[id]
			local prof = Recoil.profile(def, 1, 50, nil)
			local st = Recoil.new()
			local jp = Recoil.kick(prof, 1, 1, 1, 1, 0.5, 0.5, 0.5)
			Recoil.shot(st, prof, jp, 0)
			local gTop, cTop = 0, 0
			for _ = 1, 600 do
				Recoil.step(st, 1 / 600)
				local gp = Recoil.gun(st)
				local cp = Recoil.cam(st)
				gTop = math.max(gTop, gp)
				cTop = math.max(cTop, cp)
			end
			local k = Recoil.kickDeg(def)
			if not (near(gTop, k, 0.01 * k) and near(cTop / gTop, def.recoilCam, 0.01)) then
				ok = false
				table.insert(notes, string.format("%s: one shot peaks %.3f (kickDeg %.3f), camera share %.3f", id, gTop, k, cTop / math.max(gTop, 1e-9)))
			end
		end
		check("one shot peaks at Recoil.kickDeg, the camera at its share of it (every gun)", ok)
		check("the AI's kick is a standing default shot in degrees (R-17 about 1.2)", near(Recoil.kickDeg(R17), 0.79 * 100 * Recoil.DEG_PER_V * Recoil.MEAN_STRENGTH, 1e-9) and Recoil.kickDeg(R17) > 1 and Recoil.kickDeg(R17) < 1.5)
	end)

	-- ── better recoil stats mean less climb ────────────────────────────────────────────────────────────────────────
	guard("builds", function()
		local after0, top0 = burst(R17, 30)
		local _, top75 = burst(R17, 30, { rec = 0.75 })
		check("a build with 25 % less recoil climbs 25 % less (the figures scale the kick)", near(top75 / top0, 0.75, 1e-6))
		local items, root = buildOf("R17_RIFLE", { AR_STK_CARB = "AR_STK_A2" })
		local ms = WP.stats(items, root)
		local _, topA2 = burst(R17, 30, { rec = ms.recoil })
		check(string.format("the fixed stock's build (x%.3f of the default's recoil) climbs less", ms.recoil), ms.recoil < 1 and topA2 < top0)
		check("the default build is x1 of its own figures", near(WP.stats(buildOf("R17_RIFLE")).recoil, 1))
		local a20 = burst(R17, 30, { ergo = 20 })
		local a90 = burst(R17, 30, { ergo = 90 })
		check("handier builds (more ergonomics) come back sooner and hang lower in full auto", mean(a90, 21, 30) < mean(a20, 21, 30) and mean(after0, 21, 30) < mean(a20, 21, 30))
		local _, topC = burst(R17, 30, { stance = "c", depth = 1 })
		local _, topP = burst(R17, 30, { stance = "p" })
		check("fully crouched climbs 30 % less, prone 40 % less (Tarkov's pose figures)", near(topC / top0, 0.7, 1e-6) and near(topP / top0, 0.6, 1e-6))
	end)

	-- ── dispersion stays inside its band ───────────────────────────────────────────────────────────────────────────
	guard("dispersion", function()
		local rng = Random.new(7)
		local ok = true
		for _, id in GUNS do
			local def = Weapons[id]
			local prof = Recoil.profile(def, 1, 50, nil)
			local lo, hi = math.huge, -math.huge
			for _ = 1, 400 do
				local jp, jy = Recoil.kick(prof, 1, 1, 1, 1, rng:NextNumber(), rng:NextNumber(), rng:NextNumber())
				local a = math.deg(math.atan2(jp, -jy))
				lo, hi = math.min(lo, a), math.max(hi, a)
				ok = ok and jp > 0
			end
			if not (lo >= def.recoilAngle - def.recoilDisp - 1e-6 and hi <= def.recoilAngle + def.recoilDisp + 1e-6 and lo < def.recoilAngle and hi > def.recoilAngle) then
				ok = false
				table.insert(notes, string.format("%s: kicks from %.2f to %.2f degrees", id, lo, hi))
			end
		end
		check("each shot's direction stays inside the angle +- its dispersion, uses both sides and always climbs", ok)
		local p = Recoil.profile(R17, 1, 50, nil)
		local rp, ry = Recoil.kick(p, 1, 1, 1, 1, 0, 0.5, 0.5)
		local lp, ly = Recoil.kick(p, 1, 1, 1, 1, 1, 0.5, 0.5)
		check("the band's edges: draw 0 throws right, draw 1 left, each by the full dispersion", near(math.deg(math.atan2(rp, -ry)), R17.recoilAngle - R17.recoilDisp, 1e-6) and near(math.deg(math.atan2(lp, -ly)), R17.recoilAngle + R17.recoilDisp, 1e-6) and ry < 0 and ly > 0)
	end)

	-- ── the skills scale the result; the pose ──────────────────────────────────────────────────────────────────────
	guard("skills and pose", function()
		check("skills: none means x1", Recoil.skillMul(nil, "rifle") == 1 and Recoil.skillMul({}, "rifle") == 1)
		check("skills: an elite weapon skill takes Tarkov's 15.3 % off", near(Recoil.skillMul({ rifles = ELITE }, "rifle"), 1 - 0.003 * 51))
		check("skills: only the gun's own class counts (pistols do nothing for a rifle)", Recoil.skillMul({ pistols = ELITE }, "rifle") == 1 and near(Recoil.skillMul({ pistols = ELITE }, "pistol"), 0.847))
		check("skills: Recoil Control at elite as well makes 0.847 x 0.847", near(Recoil.skillMul({ rifles = ELITE, recoil = ELITE }, "rifle"), 0.847 * 0.847))
		local p0 = Recoil.profile(R17, 1, 50, nil)
		local p1 = Recoil.profile(R17, 1, 50, { rifles = ELITE, recoil = ELITE })
		check("skills: they scale the figures, the climb and the rearward kick alike", near(p1.v / p0.v, 0.847 * 0.847) and near(p1.climb / p0.climb, 0.847 * 0.847) and near(p1.back / p0.back, 0.847 * 0.847))
		local _, top0 = burst(R17, 30)
		local _, top1 = burst(R17, 30, { skills = { rifles = ELITE } })
		check("skills: an elite rifleman's 30-round burst climbs 15.3 % less", near(top1 / top0, 0.847, 1e-6))
		local a, b, c = Recoil.pose("s")
		check("pose: standing x1 on every axis", a == 1 and b == 1 and c == 1)
		a, b, c = Recoil.pose("c", 1)
		check("pose: fully crouched x0.7 climb, sideways and rearward (RecoilX/Y/ZIntensityByPose)", near(a, 0.7) and near(b, 0.7) and near(c, 0.7))
		check("pose: a crouch near standing height is near x1", near((Recoil.pose("c", 0)), 1))
		a, b, c = Recoil.pose("p")
		check("pose: prone x0.6 climb, x0.7 sideways and rearward", near(a, 0.6) and near(b, 0.7) and near(c, 0.7))
	end)

	-- ── the stable shot and the series ─────────────────────────────────────────────────────────────────────────────
	guard("stable shot", function()
		local p = Recoil.profile(R17, 1, 50, nil)
		local ap, ay = Recoil.kick(p, R17.recoilStable, 1, 1, 1, 0.3, 0.5, 0.5)
		local bp, by = Recoil.kick(p, R17.recoilStable + 1, 1, 1, 1, 0.3, 0.5, 0.5)
		check("after the stable shot the climb kick is halved, the sideways throw stays", near(bp, ap * Recoil.STABLE_MUL) and near(by, ay))
		local hp = Recoil.profile(Weapons.HARROW, 1, 50, nil)
		check("guns that cannot fire full auto never settle", near((Recoil.kick(hp, 9, 1, 1, 1, 0.5, 0.5, 0.5)), (Recoil.kick(hp, 1, 1, 1, 1, 0.5, 0.5, 0.5))))
		check("series: a shot within two cycles counts on, a longer pause starts again", Recoil.nextIndex(3, 0.09, 0.0923) == 4 and Recoil.nextIndex(3, 0.19, 0.0923) == 1 and Recoil.nextIndex(0, 99, 0.0923) == 1)
	end)

	-- ── the guns' figures against Tarkov's ─────────────────────────────────────────────────────────────────────────
	guard("weapons", function()
		local ok = true
		for id, def in Weapons do
			if type(def) == "table" and def.modes and not def.melee then
				local auto = table.find(def.modes, "AUTO") ~= nil
				local good = (def.recoilV or 0) > 0 and (def.recoilH or 0) > 0 and type(def.recoilAngle) == "number" and def.recoilAngle >= 45
					and def.recoilAngle <= 135 and type(def.recoilDisp) == "number" and def.recoilDisp >= 0 and def.recoilDisp < 45
					and (def.recoilConv or 0) > 0 and def.recoilConv * Recoil.ERGO[2] < Recoil.CAM_RISE * 0.8 and (def.recoilCam or 0) > 0
					and def.recoilCam <= 1 and auto == ((def.recoilStable or 0) > 0)
				if not good then
					ok = false
					table.insert(notes, "recoil fields out of range: " .. tostring(id))
				end
			end
		end
		check("every gun has its recoil fields in range (full-auto guns settle, the rest do not)", ok)
		local want = { R17 = { 79, 228 }, KST = { 90, 221 }, KS74 = { 70, 178 }, KSL = { 106, 316 }, GL6 = { 238, 560 }, SPARROW = { 43, 212 }, HARROW = { 290, 381 }, TUNDRA = { 178, 541 },
			P9 = { 425, 310 }, PM = { 380, 265 }, SKS = { 155, 360 }, SVD = { 220, 647 }, M1A = { 214, 405 }, M700 = { 199, 670 }, VSS = { 80, 270 }, VAL = { 80, 270 }, MP7 = { 50, 178 }, P90 = { 54, 243 }, UMP = { 72, 240 }, M1911 = { 451, 355 }, FN57 = { 281, 240 }, TT = { 553, 325 }, PPSH = { 89, 294 }, W21 = { 442, 325 }, J21 = { 54, 234 }, T215 = { 200, 486 }, CRK357 = { 383, 280 }, CRK9 = { 306, 200 }, BZ12 = { 493, 340 }, D17 = { 311, 260 }, AV9 = { 51, 269 }, B19 = { 58, 270 } }
		local okF = true
		for id, f in want do
			local def = Weapons[id]
			if math.floor(def.recoilV * 100 + 0.5) ~= f[1] or math.floor(def.recoilH * 100 + 0.5) ~= f[2] then
				okF = false
				table.insert(notes, string.format("%s shows %d / %d", id, math.floor(def.recoilV * 100 + 0.5), math.floor(def.recoilH * 100 + 0.5)))
			end
		end
		check("the gunsmith figures are Tarkov's for each gun's counterpart (M4A1 79/228, AKM 90/221, AK-74N 70/178, RPK-16 106/316, M32A1 238/560, MP5 43/212, MP-133 290/381, Mosin 178/541, MP-443 425/310, PM 380/265, SKS 155/360, SVDS 220/647, M1A 214/405, M700 199/670, VSS and AS VAL 80/270, MP7A1 50/178, P90 54/243, UMP 45 72/240, M1911A1 451/355, Five-seveN MK2 281/240, TT-33 553/325, PPSh-41 89/294, SR-1MP 442/325, SR-2M 54/234, VPO-215 200/486, Rhino 50DS 383/280, Rhino 200DS 306/200, RSh-12 493/340, Glock 17 311/260, MPX 51/269, Vityaz 58/270)", okF)
	end)

	-- ── the parts: Tarkov 1.0.4.5 and the default builds ───────────────────────────────────────────────────────────
	guard("parts", function()
		local hgOk = true
		for id, part in WP.parts do
			if part.cat == "handguard" and (part.recoil or 0) ~= 0 then
				hgOk = false
				table.insert(notes, "handguard with recoil: " .. id)
			end
		end
		check("Tarkov 1.0.4.5: handguards no longer change recoil", hgOk)
		local P = WP.parts
		check("Tarkov 1.0.4.5: a longer barrel holds recoil better and costs ergonomics (R-17, Harrow-12)",
			P.R17_BRL_18.recoil < P.R17_BRL_145.recoil and P.R17_BRL_145.recoil < P.R17_BRL_105.recoil and P.R17_BRL_18.ergo < P.R17_BRL_145.ergo
				and P.R17_BRL_145.ergo < P.R17_BRL_105.ergo and P.HAR_BRL_20.recoil < P.HAR_BRL_18.recoil and P.HAR_BRL_18.recoil < P.HAR_BRL_14.recoil
				and P.HAR_BRL_20.ergo < P.HAR_BRL_18.ergo and P.HAR_BRL_18.ergo < P.HAR_BRL_14.ergo)
		check("Tarkov 1.0.4.5: a suppressor costs far more ergonomics than the muzzle device it replaces and takes only a little more recoil off",
			P.SUPP_62.recoil < P.R17_FH_A2.recoil and P.SUPP_62.ergo <= P.R17_FH_A2.ergo - 10 and P.SUPP_76.recoil < P.KST_FH_SLANT.recoil
				and P.SUPP_76.ergo <= (P.KST_FH_SLANT.ergo or 0) - 10)
		local sums = { R17_RIFLE = -33.4, KST_RIFLE = -26, KS74_RIFLE = -27, SPARROW_SMG = -23, HARROW12 = -27, TUNDRA_BOLT = -20, P9_PISTOL = 0, PM_PISTOL = 0, SKS_RIFLE = 0, SVD_RIFLE = 0, M1A_RIFLE = 0, M700_BOLT = 0, VSS_RIFLE = 0, VAL_RIFLE = 0, MP7_SMG = 0, P90_SMG = 0, UMP_SMG = 0, M1911_PISTOL = 0, FN57_PISTOL = 0, TT_PISTOL = 0, PPSH_SMG = 0, W21_PISTOL = 0, J21_SMG = 0, T215_BOLT = 0, CRK357_REV = 0, CRK9_REV = 0, BZ12_REV = 0, D17_PISTOL = 0, AV9_SMG = 0, B19_SMG = 0 }
		local okS = true
		for base, sum in sums do
			local got = WP.defaultSum(base).recoilPct
			if not near(got, sum, 1e-6) then
				okS = false
				table.insert(notes, string.format("%s default build sums %.2f %%", base, got))
			end
		end
		check("the default builds sum Tarkov's preset modifiers (M4A1 -33.4 %, AKM -26 %, MP-133 -27 %), so the figures hold", okS)
	end)

	-- ── the reflex dot ─────────────────────────────────────────────────────────────────────────────────────────────
	guard("screen", function()
		local x0, y0 = Recoil.screen(0, 0, 70, 1000)
		local x1, y1 = Recoil.screen(math.rad(1), 0, 70, 1000)
		local x2 = Recoil.screen(0, math.rad(1), 70, 1000)
		check("the dot's screen offset: none at rest, up for a climb, left for a throw to the left", x0 == 0 and y0 == 0 and x1 == 0 and x2 < 0
			and near(y1, -math.tan(math.rad(1)) / math.tan(math.rad(35)) * 500, 1e-6))
	end)

	local summary = string.format("RecoilTests: %d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T
