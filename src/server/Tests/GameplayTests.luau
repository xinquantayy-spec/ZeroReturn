--!nonstrict
-- Gameplay checks for the 2026-11-07 audit quick wins (gameplay.9, gameplay.11, tech.9, tech.12, tech.16): the pure
-- rules, plus the server pieces that can run on one Studio server. Run via ZR_Dev "tests" (every module in Tests).
-- Stand-ins replace a service function only inside a check that does not yield, and are put back at once.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Progress = require(Shared.Progress)
local Hearing = require(Shared.Hearing)

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

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T
