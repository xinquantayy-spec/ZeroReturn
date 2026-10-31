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

-- skills (Tarkov): levels 0..51, elite at 51; level n costs min(10n, 100) points (550 to level 10, 4,650 to elite).
-- Gains tire within a raid (Economy: 129% before the first point, then 0.6^(points-1) after two, back to 100% after
-- 200 s without gains). per = the effect per level (an elite skill gives per x 51).
P.SKILL_MAX = 51
P.SKILLS = {
	-- physical
	endurance = { cat = "PHYSICAL", name = "ENDURANCE", desc = "Sprinting drains less stamina.", per = 0.006 },
	strength = { cat = "PHYSICAL", name = "STRENGTH", desc = "Raises your weight limits.", per = 0.004 },
	vitality = { cat = "PHYSICAL", name = "VITALITY", desc = "Lowers the chance to bleed when hit.", per = 0.005 },
	health = { cat = "PHYSICAL", name = "HEALTH", desc = "Fewer fractures and less fall damage. Grows with the other physical skills.", per = 0.006 },
	stress = { cat = "PHYSICAL", name = "STRESS RESISTANCE", desc = "Painkillers last longer; pain bothers you less.", per = 0.006 },
	metabolism = { cat = "PHYSICAL", name = "METABOLISM", desc = "Energy and hydration drain slower.", per = 0.006 },
	-- mental
	perception = { cat = "MENTAL", name = "PERCEPTION", desc = "You hear footsteps from further away.", per = 0.008 },
	intellect = { cat = "MENTAL", name = "INTELLECT", desc = "Examining is faster; repair kits take less off the maximum.", per = 0.008 },
	attention = { cat = "MENTAL", name = "ATTENTION", desc = "Searching containers and bodies is faster.", per = 0.005 },
	charisma = { cat = "MENTAL", name = "CHARISMA", desc = "Traders sell to you for less. Grows with the other mental skills.", per = 0.003 },
	-- practical
	covert = { cat = "PRACTICAL", name = "COVERT MOVEMENT", desc = "Your footsteps carry less far.", per = 0.008 },
	search = { cat = "PRACTICAL", name = "SEARCH", desc = "Searching containers and bodies is faster.", per = 0.004 },
	surgery = { cat = "PRACTICAL", name = "SURGERY", desc = "Surgery takes less time.", per = 0.008 },
	troubleshooting = { cat = "PRACTICAL", name = "TROUBLESHOOTING", desc = "Malfunctions are cleared faster.", per = 0.008 },
	lightvests = { cat = "PRACTICAL", name = "LIGHT VESTS", desc = "Class 2-3 armour slows you less.", per = 0.008 },
	heavyvests = { cat = "PRACTICAL", name = "HEAVY VESTS", desc = "Class 4-6 armour slows you less.", per = 0.008 },
	crafting = { cat = "PRACTICAL", name = "CRAFTING", desc = "Hideout crafts finish sooner.", per = 0.006 },
	-- combat
	rifles = { cat = "COMBAT", name = "ASSAULT RIFLES", desc = "Less recoil with assault rifles.", per = 0.004 },
	smg = { cat = "COMBAT", name = "SUBMACHINE GUNS", desc = "Less recoil with submachine guns.", per = 0.004 },
	pistols = { cat = "COMBAT", name = "PISTOLS", desc = "Less recoil with pistols.", per = 0.004 },
	shotguns = { cat = "COMBAT", name = "SHOTGUNS", desc = "Less recoil with shotguns.", per = 0.004 },
	boltaction = { cat = "COMBAT", name = "BOLT-ACTION RIFLES", desc = "Less recoil with bolt-action rifles.", per = 0.004 },
	throwables = { cat = "COMBAT", name = "THROWABLES", desc = "Grenades fly further.", per = 0.004 },
	melee = { cat = "COMBAT", name = "MELEE", desc = "Knife hits do more damage.", per = 0.006 },
}
P.SKILL_ORDER = {
	"endurance", "strength", "vitality", "health", "stress", "metabolism",
	"perception", "intellect", "attention", "charisma",
	"covert", "search", "surgery", "troubleshooting", "lightvests", "heavyvests", "crafting",
	"rifles", "smg", "pistols", "shotguns", "boltaction", "throwables", "melee",
}
-- the weapon skill that a weapon class trains and improves
P.WEAPON_SKILL = { rifle = "rifles", smg = "smg", pistol = "pistols", shotgun = "shotguns", bolt = "boltaction" }
-- gains in these also train another skill (Tarkov: Health from the physical skills, Charisma from the mental ones)
P.SKILL_SPILL = {
	endurance = { "health", 0.3 }, strength = { "health", 0.3 }, vitality = { "health", 0.3 }, metabolism = { "health", 0.3 },
	stress = { "health", 0.3 }, perception = { "charisma", 0.4 }, intellect = { "charisma", 0.4 }, attention = { "charisma", 0.4 },
}

-- level, points into it and the level's cost
function P.skillProgress(points: number?): (number, number, number)
	local p, lvl = points or 0, 0
	while lvl < P.SKILL_MAX do
		local cost = math.min(10 * (lvl + 1), 100)
		if p < cost then
			return lvl, p, cost
		end
		p -= cost
		lvl += 1
	end
	return P.SKILL_MAX, 0, 0
end
P.SKILL_CAP = 4650 -- points at elite

function P.skillLevel(points: number?): number
	return (P.skillProgress(points))
end

-- a skill's effect (e.g. endurance drain multiplier = 1 - bonus)
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
