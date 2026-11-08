--!strict
-- Operator progression (Tarkov-style): experience and level, skills that level with use, scav karma.
-- Shared so the client applies the same skill bonuses it shows (movement stamina, weight limits).
local P = {}

-- EFT's experience table (decision economy-4b): the total experience each level needs, levels 1 to 79 (senseos.gg's
-- "Tarkov XP Chart", checked against patch 1.3.0.0, read 2026-11-08; level 15, the flea market, at 177,337). It replaced
-- our 1000 x (level - 1)^1.5 to level 40.
P.LEVELS = {
	0, 1000, 4017, 8432, 14256, 21477, 30023, 39936, 51204, 63723, 77563, 93279, 115302, 143253, 177337, 217885, 264432,
	316851, 374400, 437465, 505161, 577978, 656347, 741150, 836066, 944133, 1066259, 1199423, 1343743, 1499338, 1666320,
	1846664, 2043349, 2258436, 2492126, 2750217, 3032022, 3337766, 3663831, 4010401, 4377662, 4765799, 5182399, 5627732,
	6102063, 6630287, 7189442, 7779792, 8401607, 9055144, 9740666, 10458431, 11219666, 12024744, 12874041, 13767918,
	14706741, 15690872, 16720667, 17816442, 19041492, 20360945, 21792266, 23350443, 25098462, 27100775, 29581231,
	33028574, 37953544, 44260543, 51901513, 60887711, 71228846, 82933459, 96009180, 110462910, 126300949, 144924572,
	172016256,
}
P.MAX_LEVEL = #P.LEVELS

-- total experience needed to reach a level (level 1 = 0; past the top level, the top level's)
function P.xpFor(level: number): number
	if level <= 1 then
		return 0
	end
	return P.LEVELS[math.min(math.floor(level), P.MAX_LEVEL)]
end

-- how many times more experience a level takes on EFT's table than on our old curve (1000 x (level - 1)^1.5), at a
-- level: task rewards set against the old curve keep the share of a level they gave (economy-4b, QuestData)
function P.xpRatio(level: number): number
	local l = math.clamp(math.floor(level), 1, P.MAX_LEVEL - 1)
	return (P.LEVELS[l + 1] - P.LEVELS[l]) / (1000 * (l ^ 1.5 - (l - 1) ^ 1.5))
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
	headshot = 0.2, -- a head kill's bonus share: EFT's x1.2 (timesaver.gg, PMC kills; economy-4b)
	survive = 300, -- extraction bonus
	lost = 0.75, -- the raid's experience kept when killed or missing in action (EFT 1.0.2.0 raised it from 0.4; economy-4b)
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
	-- Tarkov's Perception (audit gameplay.9): hearing distance +0.3 % a level, +15 % at elite (EFT wiki, quoted by
	-- gamezo.gg/?p=72006); the coordinator's answer of 19:18 on the board
	perception = { cat = "MENTAL", name = "PERCEPTION", desc = "You hear footsteps from further away.", per = 0.003 },
	intellect = { cat = "MENTAL", name = "INTELLECT", desc = "Examining is faster; repair kits take less off the maximum.", per = 0.008 },
	attention = { cat = "MENTAL", name = "ATTENTION", desc = "Searching containers and bodies is faster.", per = 0.005 },
	-- Tarkov's Charisma (audit economy.6): 0.1 % off insurance, repairs and paid exits a level; no trader discount
	charisma = { cat = "MENTAL", name = "CHARISMA", desc = "Insurance, repairs and paid exits cost 0.1 % less a level. Grows with the other mental skills.", per = 0.001 },
	-- practical
	-- Tarkov's Covert Movement (audit gameplay.9): footstep noise on common surfaces -1.2 % a level, -60 % at elite
	-- (escapefromtarkov.fandom.com/wiki/Covert_Movement, tarkovforge.com/skills/covert-movement); users cap it at 0.6
	covert = { cat = "PRACTICAL", name = "COVERT MOVEMENT", desc = "Your footsteps carry less far.", per = 0.012 },
	search = { cat = "PRACTICAL", name = "SEARCH", desc = "Searching containers and bodies is faster.", per = 0.004 },
	surgery = { cat = "PRACTICAL", name = "SURGERY", desc = "Surgery takes less time.", per = 0.008 },
	troubleshooting = { cat = "PRACTICAL", name = "TROUBLESHOOTING", desc = "Malfunctions are cleared faster.", per = 0.008 },
	lightvests = { cat = "PRACTICAL", name = "LIGHT VESTS", desc = "Class 2-3 armour slows you less.", per = 0.008 },
	heavyvests = { cat = "PRACTICAL", name = "HEAVY VESTS", desc = "Class 4-6 armour slows you less.", per = 0.008 },
	crafting = { cat = "PRACTICAL", name = "CRAFTING", desc = "Hideout crafts finish sooner.", per = 0.0075 }, -- EFT: 0.75 % a level (SkillsSettings.Crafting, economy-7b)
	-- combat
	-- weapon skills and Recoil Control: 0.3 % less recoil a level each (SPT's copy of Tarkov's globals; the recoil
	-- thread, gameplay-1a). Recoil Control trains on every shot with any gun
	rifles = { cat = "COMBAT", name = "ASSAULT RIFLES", desc = "Less recoil with assault rifles.", per = 0.003 },
	smg = { cat = "COMBAT", name = "SUBMACHINE GUNS", desc = "Less recoil with submachine guns.", per = 0.003 },
	pistols = { cat = "COMBAT", name = "PISTOLS", desc = "Less recoil with pistols.", per = 0.003 },
	shotguns = { cat = "COMBAT", name = "SHOTGUNS", desc = "Less recoil with shotguns.", per = 0.003 },
	boltaction = { cat = "COMBAT", name = "BOLT-ACTION RIFLES", desc = "Less recoil with bolt-action rifles.", per = 0.003 },
	lmg = { cat = "COMBAT", name = "LIGHT MACHINE GUNS", desc = "Less recoil with light machine guns.", per = 0.003 },
	recoil = { cat = "COMBAT", name = "RECOIL CONTROL", desc = "Less recoil with every gun.", per = 0.003 },
	throwables = { cat = "COMBAT", name = "THROWABLES", desc = "Grenades fly further.", per = 0.004 },
	melee = { cat = "COMBAT", name = "MELEE", desc = "Knife hits do more damage.", per = 0.006 },
}
P.SKILL_ORDER = {
	"endurance", "strength", "vitality", "health", "stress", "metabolism",
	"perception", "intellect", "attention", "charisma",
	"covert", "search", "surgery", "troubleshooting", "lightvests", "heavyvests", "crafting",
	"rifles", "smg", "pistols", "shotguns", "boltaction", "lmg", "recoil", "throwables", "melee",
}
-- the weapon skill that a weapon class trains and improves
P.WEAPON_SKILL = { rifle = "rifles", smg = "smg", pistol = "pistols", shotgun = "shotguns", bolt = "boltaction", lmg = "lmg" }
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

-- a skill's level with a stimulant's buff on top (Stims.luau, gameplay-4b: a buff adds levels for its course, between
-- 0 and elite); buffs = { [skill id] = levels } or nil
function P.levelWith(skills: any?, id: string, buffs: any?): number
	local lvl = skills and P.skillLevel(skills[id]) or 0
	local b = buffs and buffs[id]
	if b then
		lvl = math.clamp(lvl + b, 0, P.SKILL_MAX)
	end
	return lvl
end

-- a skill's effect (e.g. endurance drain multiplier = 1 - bonus)
function P.bonus(skills: any?, id: string, buffs: any?): number
	local def = P.SKILLS[id]
	if not def or not (skills or buffs) then
		return 0
	end
	return def.per * P.levelWith(skills, id, buffs)
end

-- weapon mastering (Tarkov; docs/design/MASTERING.md): progress per weapon group, one point for every hit on a living
-- target with a weapon of the group (every shotgun pellet that hits counts), granted on the server only. Level 1 from 0;
-- levels 2 and 3 at the group's Level2 and Level3, both running totals of the same progress (in Tarkov's globals Level3
-- is above Level2 in all 78 groups, and a profile keeps one progress number per group). The thresholds are Tarkov's for
-- the group each weapon copies: R-17 = M4, KS-7 = AKM, SMG-9 = MP5, Harrow-12 = MP-133, Tundra = Mosin, P-9 = MP-443.
-- The knife and the mounted guns have none, as in Tarkov. class = Tarkov's weapon class heading on the MASTERING tab.
P.MASTERY_MAX = 3
P.MASTERING = {
	R17 = { name = "R-17", class = "ASSAULT RIFLE", level2 = 1600, level3 = 2000, weapons = { "R17" } },
	-- the KS-L shares the KS-7's group (ours: the RPK-16's own thresholds were not found)
	KST = { name = "KS-7", class = "ASSAULT RIFLE", level2 = 500, level3 = 600, weapons = { "KST", "KSL" } },
	SPARROW = { name = "SMG-9", class = "SMG", level2 = 200, level3 = 250, weapons = { "SPARROW" } },
	HARROW = { name = "Harrow-12", class = "SHOTGUN", level2 = 150, level3 = 200, weapons = { "HARROW" } },
	TUNDRA = { name = "Tundra", class = "SNIPER RIFLE", level2 = 200, level3 = 250, weapons = { "TUNDRA" } },
	P9 = { name = "P-9", class = "PISTOL", level2 = 75, level3 = 100, weapons = { "P9" } },
	-- economy-1a's third slice: Tarkov keeps the AK-74 family and the PM in groups of their own; their thresholds were not
	-- found, so the KS-74 uses the KS-7's and the PM the P-9's (ours)
	KS74 = { name = "KS-74", class = "ASSAULT RIFLE", level2 = 500, level3 = 600, weapons = { "KS74" } },
	PM = { name = "PM", class = "PISTOL", level2 = 75, level3 = 100, weapons = { "PM" } },
	-- the fourth slice's self-loaders (thresholds not found: the SK-45 has the KS-7's, the MR-10 the Tundra's; ours)
	SKS = { name = "SK-45", class = "ASSAULT CARBINE", level2 = 500, level3 = 600, weapons = { "SKS" } },
	SVD = { name = "MR-10", class = "MARKSMAN RIFLE", level2 = 200, level3 = 250, weapons = { "SVD" } },
	-- the fifth slice (thresholds not found: the S-14 has the MR-10's, the OB-7 the Tundra's; ours)
	M1A = { name = "S-14", class = "MARKSMAN RIFLE", level2 = 200, level3 = 250, weapons = { "M1A" } },
	M700 = { name = "OB-7", class = "SNIPER RIFLE", level2 = 200, level3 = 250, weapons = { "M700" } },
	-- the sixth slice (thresholds not found: the SV-9 has the MR-10's, the AV-9 the KS-7's; ours)
	VSS = { name = "SV-9", class = "MARKSMAN RIFLE", level2 = 200, level3 = 250, weapons = { "VSS" } },
	VAL = { name = "AV-9", class = "ASSAULT RIFLE", level2 = 500, level3 = 600, weapons = { "VAL" } },
	-- the seventh slice (thresholds not found: the SMG-9's; ours)
	MP7 = { name = "PW-46", class = "SMG", level2 = 200, level3 = 250, weapons = { "MP7" } },
	P90 = { name = "PD-57", class = "SMG", level2 = 200, level3 = 250, weapons = { "P90" } },
	-- the eighth slice (thresholds not found: the SMG-9's and the PM's; ours)
	UMP = { name = "HS-45", class = "SMG", level2 = 200, level3 = 250, weapons = { "UMP" } },
	M1911 = { name = "L-11", class = "PISTOL", level2 = 75, level3 = 100, weapons = { "M1911" } },
	FN57 = { name = "F-57", class = "PISTOL", level2 = 75, level3 = 100, weapons = { "FN57" } },
	-- the ninth slice (thresholds not found: the PM's and the SMG-9's; ours)
	TT = { name = "P-33", class = "PISTOL", level2 = 75, level3 = 100, weapons = { "TT" } },
	PPSH = { name = "G-41", class = "SMG", level2 = 200, level3 = 250, weapons = { "PPSH" } },
	-- the tenth slice (thresholds ours, as the ninth's)
	W21 = { name = "W-21", class = "PISTOL", level2 = 75, level3 = 100, weapons = { "W21" } },
	J21 = { name = "J-21", class = "SMG", level2 = 200, level3 = 250, weapons = { "J21" } },
	T215 = { name = "T-215", class = "SNIPER RIFLE", level2 = 200, level3 = 250, weapons = { "T215" } },
	-- the eleventh slice: the two Crakes share a group, as EFT's Rhinos do (thresholds ours)
	CRK = { name = "Crake", class = "PISTOL", level2 = 75, level3 = 100, weapons = { "CRK357", "CRK9" } },
	BZ12 = { name = "B-12", class = "PISTOL", level2 = 75, level3 = 100, weapons = { "BZ12" } },
}
P.MASTERY_ORDER = { "R17", "KST", "KS74", "VAL", "SKS", "SPARROW", "MP7", "P90", "UMP", "PPSH", "J21", "HARROW", "SVD", "M1A", "VSS", "TUNDRA", "M700", "T215", "P9", "PM", "M1911", "FN57", "TT", "W21", "CRK", "BZ12" }
-- what a level gives (Tarkov): 2 another reload animation (magazine-fed guns here), 3 reloading while aiming down sights
P.MASTERY_PERKS = { [2] = "ANOTHER RELOAD ANIMATION", [3] = "RELOAD WHILE AIMING DOWN SIGHTS" }
-- [weapon id] = group id (a group may hold several weapons later, as Tarkov's do)
P.MASTERY_OF = {}
for gid, g in P.MASTERING do
	for _, wid in g.weapons do
		P.MASTERY_OF[wid] = gid
	end
end

-- a group's level (1..3) for some points
function P.masteryLevel(gid: string, points: number?): number
	local g = P.MASTERING[gid]
	local p = points or 0
	if not g then
		return 1
	end
	if p >= g.level3 then
		return 3
	elseif p >= g.level2 then
		return 2
	end
	return 1
end

-- level, and the running totals the bar runs between (from the level's start to the next level; equal at level 3)
function P.masteryProgress(gid: string, points: number?): (number, number, number)
	local g = P.MASTERING[gid]
	local lvl = P.masteryLevel(gid, points)
	if not g then
		return 1, 0, 0
	elseif lvl == 1 then
		return 1, 0, g.level2
	elseif lvl == 2 then
		return 2, g.level2, g.level3
	end
	return 3, g.level3, g.level3
end

-- the mastering level of a weapon (Weapons id) from a points table (the profile's or the snapshot's); 0 = no mastering
function P.masteryFor(mastering: any?, weaponId: string?): number
	local gid = weaponId and P.MASTERY_OF[weaponId]
	if not gid then
		return 0
	end
	return P.masteryLevel(gid, mastering and mastering[gid])
end

-- karma (Fence standing): -7 .. 6, EFT's range (audit economy.5: Fence's LL2 needs 6.0, TraderData.fenceLoyalty; his
-- prices follow the standing, TraderData.fencePriceMul). EFT starts every player at 0.2. Low karma turns the locals
-- hostile and lengthens the scav cooldown (both ours, below and in scavCooldown).
P.KARMA = { min = -7, max = 6, start = 0.2, killScav = -0.25, killPlayerScav = -0.4, scavExtract = 0.03, coop = 0.2, hostileBelow = -1 }

function P.scavCooldown(base: number, karma: number?): number
	return math.floor(base * (1 - 0.08 * math.clamp(karma or 0, -3, 3)))
end

return P
