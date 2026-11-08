--!nonstrict
-- Gameplay checks for the 2026-11-07 audit quick wins (gameplay.9, gameplay.11, tech.9, tech.12, tech.16): the pure
-- rules, plus the server pieces that can run on one Studio server. Run via ZR_Dev "tests" (every module in Tests).
-- Stand-ins replace a service function only inside a check that does not yield, and are put back at once.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Progress = require(Shared.Progress)
local Hearing = require(Shared.Hearing)
local Weapons = require(Shared.Weapons)
local Items = require(Shared.Items)

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

	-- ── gameplay.9: Perception and Covert Movement in what players hear ─────────────────────────────
	guard("hearing", function()
		local per = Progress.SKILLS.covert.per
		check("covert: no skill, no attribute -> steps as loud as before", Hearing.covertQuiet(nil, "concrete") == 0 and Hearing.covertQuiet(0, "metal") == 0)
		check("covert: level 10 on a common surface takes per x 10 off the radius", near(Hearing.covertQuiet(10, "concrete"), math.min(0.6, per * 10)))
		check("covert: below elite the loud (uncommon) surfaces get half (Tarkov 0.6 % against 1.2 %)", near(Hearing.covertQuiet(10, "metal"), math.min(0.6, per * 5)) and near(Hearing.covertQuiet(10, "gravel"), Hearing.covertQuiet(10, "metal")))
		check("covert: elite is equal on every surface and capped at Tarkov's -60 %", near(Hearing.covertQuiet(Progress.SKILL_MAX, "metal"), Hearing.covertQuiet(Progress.SKILL_MAX, "dirt")) and Hearing.covertQuiet(Progress.SKILL_MAX, "dirt") <= 0.6 + 1e-9)
		check("perception: untrained hears at 1x, elite at most Tarkov's +15 %", near(Hearing.perceptionReach(nil), 1) and near(Hearing.perceptionReach({}), 1) and Hearing.perceptionReach({ perception = Progress.SKILL_CAP }) > 1 and Hearing.perceptionReach({ perception = Progress.SKILL_CAP }) <= 1.15 + 1e-9)
		-- Tarkov's measured distances (audit gameplay.5): slow crouch-walk about 134 studs, sprint over 312
		check("steps: untrained radius runs 137.6 (slow crouch) to 320 studs (sprint)", near(Hearing.stepRadius(0.11, false, nil, nil, "concrete"), 137.6, 1e-3) and near(Hearing.stepRadius(1.25, false, nil, nil, "concrete"), 320, 1e-3))
		check("steps: a headset carries them 1.3x further", near(Hearing.stepRadius(1.25, true, nil, nil, "concrete"), 416, 1e-3))
		local sprintElite = Hearing.stepRadius(1.25, false, nil, Progress.SKILL_MAX, "concrete")
		check("steps: an elite covert walker's sprint carries less far, never under Tarkov's 40 %", sprintElite >= 320 * 0.4 - 1e-3 and sprintElite < 320)
		check("steps: a trained listener hears further than an untrained one", Hearing.stepRadius(0.5, false, { perception = 2000 }, nil, "wood") > Hearing.stepRadius(0.5, false, nil, nil, "wood"))
	end)
	guard("covert attribute", function()
		local Chars = ctx.Chars
		check("covert level from the profile's points (Progress.skillLevel)", Chars.covertLevel({ skills = { covert = 550 } }) == 10 and Chars.covertLevel({ skills = {} }) == 0 and Chars.covertLevel(nil) == 0)
		local model = Instance.new("Model")
		local realGet = ctx.Profiles.get
		ctx.Profiles.get = function()
			return { skills = { covert = Progress.SKILL_CAP } }
		end
		local ok, err = pcall(Chars.syncSkills, {}, model)
		ctx.Profiles.get = realGet
		check("syncSkills writes SkillCovert on the character (" .. tostring(err) .. ")", ok and model:GetAttribute("SkillCovert") == Progress.SKILL_MAX)
		model:Destroy()
	end)

	-- ── gameplay.11: Tarkov's heat, wear and malfunction rules (Weapons.luau, Combat.luau) ──────────────────────
	guard("malfunction rules", function()
		local O, M = Weapons.OVERHEAT, Weapons.MALF
		-- the recorded AKM (TRP spec): 0.0164727 by the durability at 35 %, B 0.1771, rate of fire 600
		check("durability curve: the recorded AKM's chance at 35 %", near(Weapons.durMalf(0.1771, 600, 35), 0.0164727, 2e-6))
		check("durability curve: worse as the gun wears (80, 60, 35, 10)", Weapons.durMalf(0.1771, 650, 10) > Weapons.durMalf(0.1771, 650, 35) and Weapons.durMalf(0.1771, 650, 35) > Weapons.durMalf(0.1771, 650, 60) and Weapons.durMalf(0.1771, 650, 60) > Weapons.durMalf(0.1771, 650, 80))
		local t95 = Weapons.malfParts(Weapons.R17, 95, 0.174, Weapons.magMalf(Items.defs.R17_MAG60), 0)
		check("from 93 %: no durability, round or magazine malfunctions, even with a 60-round magazine", t95 == 0)
		local t95hot, _, _, _, h95 = Weapons.malfParts(Weapons.R17, 95, 0.174, 3, 150)
		check("from 93 %: the heat's chance still counts (4.75 per mille at 150)", near(h95, 4.75) and near(t95hot, 0.00475))
		check("heat's chance: none below 100, 0.5 per mille at 100, 9 at 200", Weapons.heatMalf(99) == 0 and near(Weapons.heatMalf(100), 0.5) and near(Weapons.heatMalf(200), 9))
		local tot, pd, pr, pm = Weapons.malfParts(Weapons.KST, 35, 0.174, 0.09, 0)
		check("the recorded AKM's total at 35 % with its magazine and round: 0.01674", near(tot, 0.01674, 1e-5) and near(pr, 0.174) and near(pm, 0.09) and pd > 0.016)
		check("per round: the round's chance is a part of the total (Weapons.roundMalf)", Weapons.roundMalf("A76_PS") > 0 and Weapons.roundMalf(nil) == Weapons.ROUND_MALF_DEFAULT)
		-- heat: Tarkov's 0-200 scale and its cooling
		check("heat: a rifle shot adds the recorded AKM's 1.31, capped at 200", near(Weapons.heatShot(0, "rifle"), 1.31) and Weapons.heatShot(199.5, "rifle") == 200)
		check("heat: cools about 4.2 a second from 200 and 3 a second when cool (the recorded AKM)", near(Weapons.heatNow(200, 1), 200 - 4.208, 0.01) and near(Weapons.heatNow(50, 10), 50 - 30.03, 0.05) and Weapons.heatNow(10, 60) == 0)
		check("heat: wear x1 to 100, x2 at 150, x3 at 200", near(Weapons.heatWearMul(90), 1) and near(Weapons.heatWearMul(150), 2) and near(Weapons.heatWearMul(200), 3))
		check("heat: spread x1 to 100, x1.5 at 200", near(Weapons.heatSpread(90), 1) and near(Weapons.heatSpread(200), 1.5))
		-- the greatest durability while hot
		check("hot shots cut the greatest durability: 0.15 at 150", near(Weapons.wearMax(80, 100, 150, 0.5), 99.85))
		check("...0.2 to 0.7 drawn at 200", near(Weapons.wearMax(80, 100, 200, 0), 99.8) and near(Weapons.wearMax(80, 100, 200, 1), 99.3))
		check("...not below 100 heat, not when the durability is that close to it, never under 55", Weapons.wearMax(80, 100, 99, 0.5) == 100 and Weapons.wearMax(99.9, 100, 150, 0.5) == 100 and near(Weapons.wearMax(40, 55.2, 200, 1), 55) and Weapons.wearMax(40, 54, 200, 1) == 54)
		-- the rate of fire and the cook-off thresholds
		check("rate of fire when hot: a factor of 0.85 to 1.15 above 140", near(Weapons.rateFactor(0), 0.85) and near(Weapons.rateFactor(1), 1.15) and O.RATE_ABOVE == 140)
		check("cook-off from 170 at a 0.2 chance within 3 s; the bolt holds at 200 until 170", O.COOKOFF_FROM == 170 and O.COOKOFF_CHANCE == 0.2 and O.COOKOFF_DELAY[2] == 3 and O.SLIDE_AT == 200 and O.SLIDE_FREE == 170)
		-- which malfunction
		check("which: a roll above the total is no malfunction", Weapons.malfKind(0.5, 0.5, 0.01, 0.174, 0, 0, 50, true) == nil)
		check("which: the durability's weights (feed, misfire, eject, soft jam)", Weapons.malfKind(0, 0.5, 0.5, 0, 0, 0, 50, true) == "eject" and Weapons.malfKind(0, 0.05, 0.5, 0, 0, 0, 50, true) == "feed" and Weapons.malfKind(0, 0.15, 0.5, 0, 0, 0, 50, true) == "misfire")
		local kSoft, hSoft = Weapons.malfKind(0, 0.95, 0.5, 0, 0, 0, 50, true)
		local kHard, hHard = Weapons.malfKind(0, 0.99, 0.5, 0, 0, 0, 0, true)
		check("which: a jammed bolt is soft above 5 %, may be hard at 5 % or less", kSoft == "jam" and hSoft == false and kHard == "jam" and hHard == true)
		check("which: the magazine's part gives feed failures, only with rounds left", Weapons.malfKind(0.001, 0.3, 0, 0, 2, 0, 50, true) == "feed" and Weapons.malfKind(0.001, 0.3, 0, 0, 2, 0, 50, false) == nil)
		local heatMisfire = false
		for _, k in { 0, 0.2, 0.4, 0.6, 0.8, 0.99 } do
			heatMisfire = heatMisfire or Weapons.malfKind(0, k, 0, 0, 0, 9, 50, true) == "misfire"
		end
		check("which: heat never causes a misfire; the round's part is mostly misfires", not heatMisfire and Weapons.malfKind(0, 0.5, 0, 0.174, 0, 0, 50, true) == "misfire")
		-- the pistol's quick draw (Combat.drawTime)
		local C = ctx.Combat
		check("quick draw: a loaded pistol within 5 s of a long gun's malfunction comes out 3x as fast", near(C.drawTime(0.45, "holster", 10, 13, 5), 0.15) and C.drawTime(0.45, "holster", 10, 16, 5) == 0.45
			and C.drawTime(0.45, "holster", 10, 13, 0) == 0.45 and C.drawTime(0.45, "holster", nil, 13, 5) == 0.45 and C.drawTime(0.75, "primary", 10, 13, 5) == 0.75 and M.QUICKDRAW == 5)
		check("Combat.malfChance: none at 95 % even with a drum, rising with wear, the drum and heat add below 93 %",
			C.malfChance(95, Items.defs.R17_MAG60, 0) == 0 and C.malfChance(20, nil, 0) > C.malfChance(50, nil, 0) and C.malfChance(50, Items.defs.R17_MAG60, 0) > C.malfChance(50, nil, 0) and C.malfChance(50, nil, 150) > C.malfChance(50, nil, 0))
		check("reminder glow at the third ask within 2 s, 150 ms after the shot", M.GLOW_ASKS == 3 and M.GLOW_WINDOW == 2 and M.GLOW_DELAY == 0.15)
	end)

	-- ── tech.16: analytics events (Services/Analytics.luau; Roblox records them only in a published game) ─────────
	guard("analytics", function()
		local A = ctx.Analytics
		check("analytics: loaded by Raid.init", A ~= nil)
		if not A then
			return
		end
		check("analytics: level bands for the custom field", A.levelBand(1) == "Level - 1-4" and A.levelBand(12) == "Level - 10-19" and A.levelBand(40) == "Level - 30-40")
		check("analytics: no recent hit means another cause of death", A.killerKind(nil) == "Killer - Other")
		-- a stand-in player (a plain table): nothing is ever sent for it, the events only reach the recent list
		local fake = { Name = "ZR_AnalyticsTest" }
		local s = { map = "test_map", scav = false }
		local okFlow, errFlow = pcall(function()
			check("analytics: no frame-rate report without a raid", A.perf(fake, { fps = 50, q = 3, dev = "pc", t = 300 }) == false)
			A.deploy(fake, s)
			local dep = A.recent[#A.recent]
			check("analytics: Deploy carries the map, the side and the level band", dep ~= nil and dep.name == "Deploy" and dep.fields ~= nil
				and dep.fields[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] == "Map - test_map" and dep.fields[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] == "Side - PMC")
			check("analytics: no report before the raid ends", A.perf(fake, { fps = 50, q = 3, dev = "pc", t = 300 }) == false)
			A.raidEnd(fake, s, "MIA", { time = 1234.6 }, nil)
			local mia = A.recent[#A.recent]
			check("analytics: MIA logged with the raid's length", mia ~= nil and mia.name == "MIA" and mia.value == 1234)
			check("analytics: a report shorter than 30 s or malformed is refused", A.perf(fake, { fps = 50, q = 3, dev = "pc", t = 10 }) == false and A.perf(fake, { fps = 0 / 0, t = 300 }) == false and A.perf(fake, "x") == false)
			check("analytics: one frame-rate report per raid", A.perf(fake, { fps = 47.6, q = 1, dev = "phone", t = 300 }) == true and A.perf(fake, { fps = 47.6, q = 1, dev = "phone", t = 300 }) == false)
			local fr = A.recent[#A.recent]
			check("analytics: RaidFps carries the rounded average, device, graphics level and map", fr ~= nil and fr.name == "RaidFps" and fr.value == 48
				and fr.fields[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] == "Device - phone" and fr.fields[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] == "Graphics - LOW"
				and fr.fields[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] == "Map - test_map")
			A.raidEnd(fake, s, "SUCCESS", { time = 900, runThrough = true }, nil)
			local ex = A.recent[#A.recent]
			check("analytics: Extract tells a run-through from a survival", ex ~= nil and ex.name == "Extract" and ex.fields[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] == "Exit - Run through")
			A.raidEnd(fake, s, "KIA", { time = 60 }, nil)
			check("analytics: Death logged with the killer's kind", A.recent[#A.recent].name == "Death" and A.recent[#A.recent].fields[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] == "Killer - Other")
		end)
		A.forget(fake)
		check("analytics: the event flow ran without an error (" .. tostring(errFlow) .. ")", okFlow)
	end)

	-- ── gameplay-4b: Tarkov's stimulants, fracture penalties and the destroyed stomach ─────────────────
	guard("stims and fractures", function()
		local Stims = require(Shared.Stims)
		local Recoil = require(Shared.Recoil)
		local Health = require(script.Parent.Parent:WaitForChild("Services").Health)
		local ok = true
		for _, id in { "STIM_REGEN", "STIM_STAMINA", "STIM_HEMO", "STIM_ADREN" } do
			local d = Items.defs[id]
			ok = ok and d ~= nil and d.kind == "med" and d.med.stim == id and Stims.DEFS[id] ~= nil and d.w == 1 and d.h == 1 and d.mass == 0.05 and d.med.time == 2 and d.med.uses == 1
		end
		check("stims: four injectors, 1x1, 0.05 kg, 2 s, one use, each with its course", ok)
		check("stims: courses last EFT's times (Propital 300 s, SJ6 240 s, Zagustin's side effects to 210 s, adrenaline's to 80 s)",
			Stims.length("STIM_REGEN") == 301 and Stims.length("STIM_STAMINA") == 241 and Stims.length("STIM_HEMO") == 210 and Stims.length("STIM_ADREN") == 80)
		local a = Stims.active({ STIM_REGEN = 0 }, 10)
		check("RG-5 (Propital): +1 health a second and +20 Metabolism, Health, Vitality; no side effect yet", a.regen == 1 and a.sk.metabolism == 20 and a.sk.health == 20 and a.sk.vitality == 20 and not a.tremor and not a.tunnel)
		a = Stims.active({ STIM_REGEN = 0 }, 275)
		check("RG-5: hand tremor and tunnel vision from 270 s", a.tremor and a.tunnel and a.regen == 1)
		a = Stims.active({ STIM_REGEN = 0 }, 302)
		check("RG-5: nothing left after its course", not a.any and a.regen == 0)
		local hs = Health.new()
		hs.stims.STIM_STAMINA = os.clock() - 10
		local m = Health.mods(hs)
		check("SV-3 (SJ6): maximum stamina +30 and recovery +2 a second in the mods", m.maxStamina == 30 and m.staminaAdd == 2 and m.tunnel == nil and m.pain == nil)
		hs.stims.STIM_STAMINA = os.clock() - 205
		m = Health.mods(hs)
		check("SV-3: from 200 s hand tremor and tunnel vision, without the pain overlay", m.tremor == 0.7 and m.tunnel == true and m.pain == nil)
		a = Stims.active({ STIM_HEMO = 0 }, 5)
		check("HM-2 (Zagustin): no bleed takes, Vitality +20, Metabolism -5", a.noBleed and a.sk.vitality == 20 and a.sk.metabolism == -5 and a.water == 0)
		a = Stims.active({ STIM_HEMO = 0 }, 175)
		check("HM-2: from 170 s hand tremor and hydration -1.4 a second", a.tremor and near(a.water, -1.4) and a.noBleed)
		a = Stims.active({ STIM_ADREN = 0 }, 5)
		check("adrenaline: Endurance, Strength, Recoil Control +10, Stress Resistance -10, +4 health a second", a.sk.endurance == 10 and a.sk.strength == 10 and a.sk.recoil == 10 and a.sk.stress == -10 and a.regen == 4)
		a = Stims.active({ STIM_ADREN = 0 }, 55)
		check("adrenaline: from 50 s energy -0.8 and hydration -1 a second", near(a.energy, -0.8) and near(a.water, -1) and a.regen == 0)
		check("skill buffs add levels, from 0 to elite", Progress.levelWith(nil, "vitality", { vitality = 20 }) == 20 and Progress.levelWith({ vitality = Progress.SKILL_CAP }, "vitality", { vitality = 20 }) == Progress.SKILL_MAX
			and Progress.levelWith(nil, "stress", { stress = -10 }) == 0 and near(Progress.bonus(nil, "endurance", { endurance = 10 }), Progress.SKILLS.endurance.per * 10))
		check("adrenaline's Recoil Control reaches the recoil", near(Recoil.skillMul(nil, "rifle", { recoil = 10 }), 1 - Recoil.CONTROL_PER * 10) and Recoil.skillMul(nil, "rifle") == 1)
		-- regeneration: one pool a second over the damaged living parts
		local hr = Health.new()
		hr.parts.thorax.hp, hr.parts.stomach.hp, hr.parts.larm.hp = 50, 60, 0
		Health.regen(hr, 2)
		check("regeneration splits evenly over the damaged parts and skips a destroyed one", near(hr.parts.thorax.hp, 51) and near(hr.parts.stomach.hp, 61) and hr.parts.larm.hp == 0)
		hr.parts.thorax.hp = 84.5
		Health.regen(hr, 2)
		check("regeneration a full part cannot take goes to the others", near(hr.parts.thorax.hp, 85) and near(hr.parts.stomach.hp, 62.5))
		-- fractures (EFT wiki, Health system)
		local F = Health.FRACTURE
		local hf = Health.new()
		hf.fract.rarm = true
		m = Health.mods(hf)
		check("broken right arm: reload, draw and aim x1.67, using and searching x1.5", near(m.reload, 1.67) and near(m.draw, 1.67) and near(m.aim, 1.67) and near(m.use, 1.5))
		hf.fract.rarm, hf.fract.larm = nil, true
		m = Health.mods(hf)
		check("broken left arm: reload and draw x1.5, aiming as before, using and searching x1.67", near(m.reload, 1.5) and near(m.draw, 1.5) and m.aim == 1 and near(m.use, 1.67))
		hf.parts.rarm.hp = 0
		m = Health.mods(hf)
		check("a destroyed right arm counts as broken; two arms multiply", near(m.reload, F.rHands * F.lHands) and near(m.use, F.rUse * F.lUse) and near(m.aim, 1.67))
		local hl = Health.new()
		hl.fract.lleg = true
		m = Health.mods(hl)
		check("broken leg: movement -45 %, no sprint, pain", near(m.speed, 0.55) and m.sprint == false and m.pain == true)
		hl.painUntil = os.clock() + 60
		m = Health.mods(hl)
		check("painkillers let you sprint on it but the leg still slows you", m.sprint == true and near(m.speed, 0.55) and m.pain == nil)
		hl.fract.rleg = true
		check("two broken legs: x0.55 x0.55", near(Health.mods(hl).speed, 0.55 * 0.55))
		check("a destroyed stomach drains energy and water five times as fast", Health.STOMACH_DRAIN == 5)
	end)

	-- the bosses' guns (decision ai-5b): the KS-L and the GL-6, and the launched round's impact fuze
	do
		local G = require(Shared.Grenades)
		local Ballistics = require(Shared.Ballistics)
		local ksl, gl6, a40 = Weapons.KSL, Weapons.GL6, Items.defs.A40_HE
		check("KS-L: EFT's RPK-16 figures (650 rpm, ergonomics 45, recoil 106 / 316), the light machine gun skill, the drum fits the KS-7 family",
			ksl ~= nil and ksl.rpm == 650 and ksl.ergo == 45 and near(ksl.recoilV, 1.06) and near(ksl.recoilH, 3.16)
				and Progress.WEAPON_SKILL.lmg == "lmg" and Items.defs.KSL_DRUM95.capacity == 95 and Items.defs.KSL_DRUM95.family == "KST"
				and Weapons.magMalf(Items.defs.KSL_DRUM95) > Weapons.magMalf(Items.defs.KST_MAG))
		check("GL-6: a six-round launcher at 76 m/s; its round arms after 0.26 s (about 20 m), as EFT's 40x46 M406",
			gl6 ~= nil and gl6.launcher == true and gl6.internal == true and gl6.velocity == 76 and Items.defs.GL6_LAUNCHER.capacity == 6
				and a40 ~= nil and a40.nade.impact == true and near(a40.nade.arm, 0.26)
				and near(gl6.velocity * a40.nade.arm, 19.76, 0.05))
		-- the flight on its own: a flat plane 40 studs below, nothing else (a stand-in for the world's raycast)
		local function floor(origin, dir)
			if dir.Y >= 0 then
				return nil
			end
			local k = (origin.Y - 0) / -dir.Y
			if k > dir.Magnitude then
				return nil
			end
			return origin + dir * k, Vector3.yAxis
		end
		local v0 = Ballistics.muzzle(gl6)
		local far = G.simulate(Vector3.new(0, 40, 0), Vector3.new(0, -0.15, -1).Unit * v0, 10, floor, true)
		local close = G.simulate(Vector3.new(0, 1, 0), Vector3.new(0, -0.6, -1).Unit * v0, 10, floor, true)
		check("a launched round stops where it strikes (hitT, hitN); far off it has armed, a short shot has not",
			far.hitT ~= nil and far.hitN == Vector3.yAxis and math.abs(far.final.Y - G.RADIUS) < 0.1 and far.hitT >= a40.nade.arm
				and close.hitT ~= nil and close.hitT < a40.nade.arm and #far.b == 0)
		local h = ctx and ctx.Loot and ctx.Loot.mortarLoadout and ctx.Loot.mortarLoadout(Random.new(4))
		if h then
			local pg, sg = h.slots.primary, h.slots.secondary
			local rounds = 0
			for _, it in h.items do
				if it.id == "A40_HE" then
					rounds += 1
				end
			end
			check("MORTAR carries the GL-6 loaded with six rounds, four more, and his rifle on his back",
				pg ~= nil and h.items[pg].id == "GL6_LAUNCHER" and h.items[pg].a == 6 and h.items[pg].at == "A40_HE" and rounds >= 4
					and sg ~= nil and h.items[sg].id == "KST_RIFLE")
		else
			table.insert(notes, "MORTAR's kit: no Loot service here")
		end
	end

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T
