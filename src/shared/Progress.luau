--!strict
-- Operator progression (Tarkov-style): experience and level, skills that level with use, scav karma.
-- Shared so the client applies the same skill bonuses it shows (movement stamina, weight limits).
local P = {}

P.MAX_LEVEL = 40

-- total experience needed to reach a level (level 1 = 0)
function P.xpFor(level: number): number
	if level <= 1 then
		return 0
	end
	return math.floor(1000 * (level - 1) ^ 1.5)
end

function P.levelOf(xp: number): number
	local lvl = 1
	while lvl < P.MAX_LEVEL and xp >= P.xpFor(lvl + 1) do
		lvl += 1
	end
	return lvl
end

-- raid experience
P.XP = {
	kill = { scav = 60, watch = 200, follower = 250, boss = 1200, pmc = 300, pscav = 100 },
	headshot = 0.5, -- bonus share for head kills
	survive = 300, -- extraction bonus
	search = 4, -- per item revealed in a container or body
	examine = 20,
	runThrough = { time = 420, xp = 200 }, -- extract sooner with less raid xp: "run through", loot is not found-in-raid
}

-- skills: points accumulate with use; 100 points per level, level 10 is elite
P.SKILLS = {
	endurance = { name = "ENDURANCE", desc = "Sprinting drains less stamina (-3% per level).", per = 0.03 },
	strength = { name = "STRENGTH", desc = "Raises your weight limits (+2% per level).", per = 0.02 },
	vitality = { name = "VITALITY", desc = "Lowers the chance to bleed when hit (-2.5% per level).", per = 0.025 },
	metabolism = { name = "METABOLISM", desc = "Energy and hydration drain slower (-3% per level).", per = 0.03 },
}
P.SKILL_ORDER = { "endurance", "strength", "vitality", "metabolism" }

function P.skillLevel(points: number?): number
	return math.clamp(math.floor((points or 0) / 100), 0, 10)
end

-- multiplier for a skill effect (e.g. endurance drain multiplier = 1 - 0.03 * level)
function P.bonus(skills: any?, id: string): number
	local def = P.SKILLS[id]
	if not def or not skills then
		return 0
	end
	return def.per * P.skillLevel(skills[id])
end

-- karma (Fence standing): -3 .. 3. Low karma turns the locals hostile and lengthens the scav cooldown.
P.KARMA = { min = -3, max = 3, start = 0.2, killScav = -0.25, killPlayerScav = -0.4, scavExtract = 0.03, hostileBelow = -1 }

function P.scavCooldown(base: number, karma: number?): number
	return math.floor(base * (1 - 0.08 * math.clamp(karma or 0, -3, 3)))
end

return P
