--!strict
-- Raid environment (M10): time of day and weather. The server rolls one per raid (Match); clients light the
-- world from it (Atmos.luau) and the AI scale their senses with it. In-world time runs 7x real time (Tarkov),
-- so a 25-minute raid covers about three hours: a dusk raid starts in daylight and ends in the dark.
local Env = {}

Env.SCALE = 7

-- raid start times (hours) and how often each comes up
Env.SLOTS = {
	{ h = 8.6, w = 2 }, { h = 12.7, w = 2 }, { h = 15.2, w = 2 }, -- day
	{ h = 17.1, w = 1.6 }, -- dusk: sunset during the raid
	{ h = 21.4, w = 1.2 }, { h = 0.7, w = 1 }, { h = 2.9, w = 1 }, -- night
	{ h = 4.8, w = 1.4 }, -- dawn: sunrise during the raid
}

export type Weather = {
	id: string, name: string, clouds: number, cloudDensity: number, fog: number, haze: number, rain: number,
	wind: number, sight: number, hear: number, light: number, w: number,
}

-- fog = Atmosphere density, light = how much sun gets through, sight/hear = AI sense multipliers
Env.WEATHER = {
	clear = { id = "clear", name = "CLEAR", clouds = 0.32, cloudDensity = 0.42, fog = 0.3, haze = 1.3, rain = 0, wind = 0.25, sight = 1, hear = 1, light = 1, w = 3 },
	overcast = { id = "overcast", name = "OVERCAST", clouds = 0.9, cloudDensity = 0.74, fog = 0.42, haze = 2.1, rain = 0, wind = 0.5, sight = 0.95, hear = 1, light = 0.72, w = 3 },
	fog = { id = "fog", name = "FOG", clouds = 0.96, cloudDensity = 0.6, fog = 0.74, haze = 5, rain = 0, wind = 0.12, sight = 0.55, hear = 1, light = 0.6, w = 1.5 },
	rain = { id = "rain", name = "RAIN", clouds = 1, cloudDensity = 0.95, fog = 0.52, haze = 2.8, rain = 1, wind = 0.85, sight = 0.8, hear = 0.72, light = 0.5, w = 2.5 },
} :: { [string]: Weather }
Env.ORDER = { "clear", "overcast", "fog", "rain" }

export type State = { clock0: number, w: string, rain: number, t0: number?, season: string? }

-- seasons (Tarkov 0.16): the world turns with the calendar (Russia: winter Dec-Feb, spring Mar-May, summer
-- Jun-Aug, autumn Sep-Nov). Winter brings snow (rain falls as snow), autumn turns the foliage and wets the ground.
Env.SEASONS = {
	summer = { name = "SUMMER", rainW = 1 },
	autumn = { name = "AUTUMN", rainW = 1.6 },
	winter = { name = "WINTER", rainW = 1.3 },
	spring = { name = "SPRING", rainW = 1.3 },
}
function Env.seasonOf(month: number): string
	if month == 12 or month <= 2 then
		return "winter"
	elseif month <= 5 then
		return "spring"
	elseif month <= 8 then
		return "summer"
	end
	return "autumn"
end

local function pick(list: { any }, weight: (any) -> number, r: number): any
	local total = 0
	for _, e in list do
		total += weight(e)
	end
	local x = r * total
	for _, e in list do
		x -= weight(e)
		if x <= 0 then
			return e
		end
	end
	return list[#list]
end

-- roll a raid environment (rng: Random)
function Env.roll(rng: Random): State
	local slot = pick(Env.SLOTS, function(s)
		return s.w
	end, rng:NextNumber())
	local ws = {}
	for _, id in Env.ORDER do
		table.insert(ws, Env.WEATHER[id])
	end
	local season = Env.seasonOf(os.date("!*t").month)
	local sw = Env.SEASONS[season].rainW
	local w = pick(ws, function(x)
		return x.w * ((x.rain > 0) and sw or 1)
	end, rng:NextNumber())
	return {
		clock0 = (slot.h + rng:NextNumber(-0.25, 0.25)) % 24,
		w = w.id,
		rain = (w.rain > 0) and rng:NextNumber(0.45, 1) or 0,
		season = season,
	}
end

-- in-world hour (0..24) at server time `now`
function Env.clock(e: State, now: number): number
	return (e.clock0 + (now - (e.t0 or now)) * Env.SCALE / 3600) % 24
end

local function smooth(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0 = night, 1 = full day (the Roblox sun rises about 6:00 and sets about 18:00)
function Env.daylight(h: number): number
	if h < 12 then
		return smooth(5.25, 7.1, h)
	end
	return 1 - smooth(17.0, 18.85, h)
end

-- 0..1: how golden the light is (low sun at dawn/dusk)
function Env.golden(h: number): number
	local function bump(c: number, wdt: number): number
		return math.max(0, 1 - math.abs(h - c) / wdt)
	end
	return math.max(bump(6.4, 1.2), bump(17.7, 1.3))
end

-- AI sight multiplier: darkness and weather shorten how far anyone can be picked out
function Env.sight(e: State?, now: number): number
	if not e then
		return 1
	end
	local w = Env.WEATHER[e.w] or Env.WEATHER.clear
	local d = Env.daylight(Env.clock(e, now))
	return (0.38 + 0.62 * d) * w.sight
end

-- AI hearing multiplier (rain masks footsteps)
function Env.hearing(e: State?): number
	if not e then
		return 1
	end
	local w = Env.WEATHER[e.w] or Env.WEATHER.clear
	return 1 - (1 - w.hear) * math.max(e.rain, w.rain > 0 and 0.5 or 0)
end

function Env.isDark(e: State?, now: number): boolean
	return e ~= nil and Env.daylight(Env.clock(e, now)) < 0.35
end

-- "19:42 · RAIN"
function Env.label(e: State?, now: number): string
	if not e then
		return "--:--"
	end
	local h = Env.clock(e, now)
	local w = Env.WEATHER[e.w] or Env.WEATHER.clear
	return string.format("%02d:%02d  ·  %s", math.floor(h), math.floor((h % 1) * 60), w.name)
end

return Env
