--!nonstrict
-- Tarkov's stimulant injectors (decision gameplay-4b): timed buffs and side effects. Four of EFT's, under our names,
-- with EFT's figures (EFT wiki, Medical: the injector table with each effect's delay and duration; TarkovForge's item
-- pages for the values; both read 2026-11-08):
--   STIM_REGEN    after Propital: from 1 s for 300 s health +1 a second, Metabolism, Health and Vitality +20 levels;
--                 a painkiller for 245 s; from 270 s for 30 s hand tremor and tunnel vision
--   STIM_STAMINA  after SJ6: from 1 s for 240 s maximum stamina +30 and stamina recovery +2 a second; from 200 s for
--                 40 s hand tremor and tunnel vision
--   STIM_HEMO     after Zagustin: stops every bleed, and no bleed takes for 180 s; Vitality +20 and Metabolism -5 for
--                 180 s; from 170 s for 40 s hand tremor and hydration -1.4 a second
--   STIM_ADREN    after the Adrenaline injector: a painkiller for 65 s; from 1 s for 60 s Endurance, Strength and Recoil
--                 Control +10 and Stress Resistance -10; for 15 s health +4 a second; from 50 s for 30 s energy -0.8
--                 and hydration -1 a second
-- Ours: health regeneration is one pool a second spread over the damaged living parts (EFT's split is not published);
-- the same injector again starts its course again; skill buffs add levels, between 0 and elite.
local Progress = require(script.Parent.Progress)

local S = {}

export type Fx = { kind: string, v: any, delay: number, dur: number, side: boolean? }

local function fx(kind: string, v: any, delay: number, dur: number, side: boolean?): Fx
	return { kind = kind, v = v, delay = delay, dur = dur, side = side }
end

S.DEFS = {
	STIM_REGEN = {
		pain = 245,
		fx = {
			fx("regen", 1, 1, 300),
			fx("skill", { metabolism = 20, health = 20, vitality = 20 }, 1, 300),
			fx("tremor", true, 270, 30, true),
			fx("tunnel", true, 270, 30, true),
		},
	},
	STIM_STAMINA = {
		fx = {
			fx("maxStamina", 30, 1, 240),
			fx("staminaRate", 2, 1, 240),
			fx("tremor", true, 200, 40, true),
			fx("tunnel", true, 200, 40, true),
		},
	},
	STIM_HEMO = {
		stopBleeds = true,
		fx = {
			fx("noBleed", true, 0, 180),
			fx("skill", { vitality = 20 }, 1, 180),
			fx("skill", { metabolism = -5 }, 1, 180, true),
			fx("tremor", true, 170, 40, true),
			fx("water", -1.4, 170, 40, true),
		},
	},
	STIM_ADREN = {
		pain = 65,
		fx = {
			fx("skill", { endurance = 10, strength = 10, recoil = 10 }, 1, 60),
			fx("skill", { stress = -10 }, 1, 60, true),
			fx("regen", 4, 1, 15),
			fx("energy", -0.8, 50, 30, true),
			fx("water", -1, 50, 30, true),
		},
	},
}

-- a course's length: the end of its last effect
function S.length(id: string): number
	local d = S.DEFS[id]
	local t = 0
	for _, f in d and d.fx or {} do
		t = math.max(t, f.delay + f.dur)
	end
	return t
end

-- everything in effect at `now` for the courses in stims ([id] = the time of the shot)
function S.active(stims: { [string]: number }?, now: number)
	local a = { regen = 0, maxStamina = 0, staminaRate = 0, energy = 0, water = 0, sk = {}, tremor = false, tunnel = false, noBleed = false, any = false }
	for id, t0 in stims or {} do
		local d = S.DEFS[id]
		if d then
			local t = now - t0
			for _, f in d.fx do
				if t >= f.delay and t < f.delay + f.dur then
					a.any = true
					if f.kind == "skill" then
						for k, n in f.v do
							a.sk[k] = (a.sk[k] or 0) + n
						end
					elseif f.kind == "tremor" or f.kind == "tunnel" or f.kind == "noBleed" then
						a[f.kind] = true
					else
						a[f.kind] += f.v
					end
				end
			end
		end
	end
	return a
end

-- the INSPECT window's lines for one effect: { label, value, tone }
local NAMES = {
	regen = "HEALTH REGENERATION", maxStamina = "MAX STAMINA", staminaRate = "STAMINA RECOVERY", noBleed = "STOPS BLEEDING",
	tremor = "HAND TREMOR", tunnel = "TUNNEL VISION", energy = "ENERGY", water = "HYDRATION",
}
local PER_SECOND = { regen = true, staminaRate = true, energy = true, water = true }

local function num(v: number): string
	local s = (v == math.floor(v)) and tostring(v) or string.format("%.1f", v)
	return (v > 0 and "+" or "") .. s
end

function S.lines(f: Fx): { { string } }
	local when = f.delay > 1 and string.format("AFTER %d S, %d S", f.delay, f.dur) or string.format("%d S", f.dur)
	local tone = f.side and "bad" or "good"
	local out = {}
	if f.kind == "skill" then
		local keys = {}
		for k in f.v do
			table.insert(keys, k)
		end
		table.sort(keys)
		for _, k in keys do
			local def = Progress.SKILLS[k]
			table.insert(out, { (def and def.name or string.upper(k)), num(f.v[k]) .. "  ·  " .. when, tone })
		end
	elseif type(f.v) == "number" then
		table.insert(out, { NAMES[f.kind] or string.upper(f.kind), num(f.v) .. (PER_SECOND[f.kind] and "/S" or "") .. "  ·  " .. when, tone })
	else
		table.insert(out, { NAMES[f.kind] or string.upper(f.kind), when, tone })
	end
	return out
end

return S
