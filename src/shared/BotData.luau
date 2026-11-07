--!strict
-- EFT's numbers for the AI's senses and aim (audit decision ai-3a): sight and cone, notice time by distance, hearing,
-- memory, aim that settles, aim knocked off by hits, the 1.0 detection changes, rain and fog, and a difficulty per spawn.
-- Source: SPT's copy of the game's data, read 2026-11-08 as data only (never shipped): bots/types/<role>.json (the
-- difficulty sections Core, Look, Hearing, Mind, Aiming, Scattering, Patrol), globals.json bot_presets and
-- locations/<map>/base.json (BotLocationModifier, the difficulty mix). Battlestate does not document these keys: what each
-- one means is read from its name and its spread over the roles, and the readings are noted where they matter.
-- Distances are in metres as in EFT; BotData.stats turns them into studs, the one place that does. Pure: no services.
local BotData = {}

BotData.STUDS = 3.125 -- studs a metre on the real-scale maps (docs/maps/BORDER_CUSTOMS_BUILD.md)

-- Notice time by distance, the same for every role here (Look): CloseDeltaTimeSec 0.1 s next to the bot,
-- MiddleDeltaTimeSec 1 s at MIDDLE_DIST 90 m, FarDeltaTimeSec 3 s at FAR_DISTANCE 160 m, straight lines between; past
-- 160 m (marksmen and Birdeye see that far) the last slope carries on (our reading: EFT gives no point beyond)
BotData.LOOK = { close = 0.1, middle = 1, far = 3, midDist = 90, farDist = 160 }

-- The same for every role here: Mind.TIME_TO_FIND_ENEMY 22 s (how long a lost enemy is searched for),
-- Aiming.FIRST_CONTACT_ADD_CHANCE_100 80, Scattering.WorkingScatter 0.15
BotData.SHARED = { find = 22, firstChance = 0.8, scatterWork = 0.15 }

-- EFT 1.0 (patch notes, November 2025: PCGamesN, Express Tribune): a bot that has not seen you for 15 s no longer aims
-- at the head
BotData.HEAD_UNSEEN = 15

-- Per role and difficulty, the JSON key each field comes from. "Preset" marks the keys that globals.json bot_presets
-- (UseThis = true) sets over the bot file for that role and difficulty. They read as EFT 1.0's AI changes: they narrow
-- the cones and lengthen the first contact for the roles the patch notes name (scavs of every difficulty, sniper scavs,
-- raiders, rogues, PMC bots, most bosses and guards) and leave out the Goons, whom the notes exempt. So they win.
--   sight       Core.VisibleDistance, m (preset)
--   cone        Core.VisibleAngle, degrees off the look direction; 180 sees all round (preset). Read as the angle off the
--               look direction, not the whole cone: Birdeye's 179 beside the others' 180 only means something that way
--   notice      Look.VISIBILITY_CHANGE_SPEED: notice time divided by this (preset)
--   peace       Patrol.VISION_DIST_COEF_PEACE: share of sight while calm
--   lose        Look.GOAL_TO_FULL_DISSAPEAR, s out of view before a noticed target is lost (it then needs noticing again)
--   forget      Mind.TIME_TO_FORGOR_ABOUT_ENEMY_SEC, s
--   lightAdd    Look.ENEMY_LIGHT_ADD, m more sight on a target with a light on in the dark
--   hearClose   Hearing.CLOSE_DIST, m;  hearFar Hearing.FAR_DIST, m
--   hearChance  Hearing.CHANCE_TO_HEAR_SIMPLE_SOUND_0_1 (Birdeye's and Shturman's 1.98 read as 1)
--   hearDelay   Hearing.HEAR_DELAY_WHEN_HAVE_SMT, s;  hearPeace Hearing.HEAR_DELAY_WHEN_PEACE, s
--   aimTime     Aiming.MAX_AIM_TIME, s (missing for Birdeye, Shturman and his guards: assault's 1.5)
--   aimMove     Aiming.TIME_COEF_IF_MOVE
--   scatter     Scattering.MaxScatter (against SHARED.scatterWork)
--   shift       Aiming.BASE_SHIEF (only its ratio between a role's difficulties is used)
--   firstAdd    Aiming.FIRST_CONTACT_ADD_SEC, s (preset)
--   hitDelay    Aiming.BASE_HIT_AFFECTION_DELAY_SEC, s;  hitMin, hitMax Aiming.BASE_HIT_AFFECTION_MIN_ANG / MAX_ANG, degrees
--   discard     Aiming.DAMAGE_TO_DISCARD_AIM_0_100 / 100;  discardMin, discardMax Aiming.MIN / MAX_TIME_DISCARD_AIM_SEC, s
export type Role = {
	sight: number, cone: number, notice: number, peace: number, lose: number, forget: number, lightAdd: number,
	hearClose: number, hearFar: number, hearChance: number, hearDelay: number, hearPeace: number,
	aimTime: number, aimMove: number, scatter: number, shift: number, firstAdd: number,
	hitDelay: number, hitMin: number, hitMax: number, discard: number, discardMin: number, discardMax: number,
}
BotData.ROLES = {
	-- AI scavs (assault.json; preset "assault" each difficulty: sight 110/120/130 -> 125/129/137 m, cone 130/130/140 -> 70/70/75,
	-- first contact 0.1/0.05/0.05 -> 0.75 s)
	assault = {
		easy = {
			sight = 125, cone = 70, notice = 1, peace = 0.5, lose = 0.25, forget = 52, lightAdd = 45,
			hearClose = 10, hearFar = 30, hearChance = 0.45, hearDelay = 0.56, hearPeace = 0.85,
			aimTime = 1.5, aimMove = 1.5, scatter = 0.3, shift = 1, firstAdd = 0.75,
			hitDelay = 1.77, hitMin = 20, hitMax = 36, discard = 1, discardMin = 2.9, discardMax = 3.2,
		},
		normal = {
			sight = 129, cone = 70, notice = 1, peace = 0.75, lose = 0.25, forget = 52, lightAdd = 45,
			hearClose = 10, hearFar = 30, hearChance = 0.65, hearDelay = 0.5, hearPeace = 0.75,
			aimTime = 1.5, aimMove = 1.5, scatter = 0.3, shift = 0.8, firstAdd = 0.75,
			hitDelay = 1.17, hitMin = 19, hitMax = 32, discard = 0.96, discardMin = 2.3, discardMax = 3.1,
		},
		hard = {
			sight = 137, cone = 75, notice = 1, peace = 0.75, lose = 0.25, forget = 52, lightAdd = 45,
			hearClose = 10, hearFar = 30, hearChance = 0.7, hearDelay = 0.5, hearPeace = 0.75,
			aimTime = 1.5, aimMove = 1.5, scatter = 0.3, shift = 0.5, firstAdd = 0.75,
			hitDelay = 0.27, hitMin = 20, hitMax = 30, discard = 0.96, discardMin = 2.3, discardMax = 2.6,
		},
	},
	-- sniper scavs (marksman.json; preset "marksman": sight 132/137/147 -> 200/220/240 m, cone 120/120/130 -> 80/80/85,
	-- first contact 0.1 -> 0.75 s). No AI of ours is one yet (decision ai-1a puts them in Customs' perches)
	marksman = {
		easy = {
			sight = 200, cone = 80, notice = 1, peace = 0.5, lose = 0.5, forget = 52, lightAdd = 45,
			hearClose = 10, hearFar = 30, hearChance = 0.45, hearDelay = 0.56, hearPeace = 0.85,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.3, shift = 1, firstAdd = 0.75,
			hitDelay = 0.77, hitMin = 30, hitMax = 32, discard = 0.96, discardMin = 2.3, discardMax = 3.2,
		},
		normal = {
			sight = 220, cone = 80, notice = 1, peace = 0.75, lose = 0.5, forget = 52, lightAdd = 45,
			hearClose = 10, hearFar = 30, hearChance = 0.65, hearDelay = 0.5, hearPeace = 0.75,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.3, shift = 0.8, firstAdd = 0.75,
			hitDelay = 0.77, hitMin = 20, hitMax = 32, discard = 0.96, discardMin = 1.3, discardMax = 2.1,
		},
		hard = {
			sight = 240, cone = 85, notice = 2, peace = 0.75, lose = 0.5, forget = 52, lightAdd = 45,
			hearClose = 10, hearFar = 30, hearChance = 0.7, hearDelay = 0.5, hearPeace = 0.75,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.3, shift = 0.5, firstAdd = 0.75,
			hitDelay = 0.77, hitMin = 20, hitMax = 32, discard = 0.96, discardMin = 1.3, discardMax = 2.9,
		},
	},
	-- raiders (pmcbot.json; preset "pmcBot": sight 142 -> 127 m, cone 160 -> 70, first contact 0.1 -> 0.75 s)
	pmcbot = {
		normal = {
			sight = 127, cone = 70, notice = 2, peace = 0.75, lose = 0.2, forget = 52, lightAdd = 48,
			hearClose = 26, hearFar = 56, hearChance = 0.88, hearDelay = 0, hearPeace = 0,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.75,
			hitDelay = 0.57, hitMin = 4, hitMax = 10, discard = 0.86, discardMin = 0.3, discardMax = 0.6,
		},
	},
	-- Reshala (bossbully.json; preset "bossBully": sight 137 -> 140 m, cone 160 -> 80, first contact 0.1 -> 0.75 s)
	bossbully = {
		normal = {
			sight = 140, cone = 80, notice = 2, peace = 1, lose = 1.1, forget = 52, lightAdd = 43,
			hearClose = 26, hearFar = 56, hearChance = 0.98, hearDelay = 0, hearPeace = 0,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.75,
			hitDelay = 0.57, hitMin = 4, hitMax = 10, discard = 0.86, discardMin = 0.3, discardMax = 0.6,
		},
	},
	-- Reshala's guards (followerbully.json; no preset)
	followerbully = {
		normal = {
			sight = 142, cone = 160, notice = 2, peace = 0.85, lose = 1.1, forget = 52, lightAdd = 48,
			hearClose = 26, hearFar = 56, hearChance = 0.88, hearDelay = 0, hearPeace = 0,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.1,
			hitDelay = 0.57, hitMin = 4, hitMax = 10, discard = 0.86, discardMin = 0.3, discardMax = 0.6,
		},
	},
	-- Killa (bosskilla.json; no preset)
	bosskilla = {
		normal = {
			sight = 137, cone = 180, notice = 2, peace = 0.95, lose = 1.1, forget = 52, lightAdd = 43,
			hearClose = 36, hearFar = 66, hearChance = 0.98, hearDelay = 0, hearPeace = 0,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.1,
			hitDelay = 0.27, hitMin = 4, hitMax = 8, discard = 0.01, discardMin = 0, discardMax = 0,
		},
	},
	-- Tagilla (bosstagilla.json; no preset)
	bosstagilla = {
		normal = {
			sight = 137, cone = 180, notice = 2, peace = 0.95, lose = 1.1, forget = 52, lightAdd = 43,
			hearClose = 36, hearFar = 66, hearChance = 0.98, hearDelay = 0, hearPeace = 0,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.1,
			hitDelay = 0.27, hitMin = 4, hitMax = 8, discard = 0.01, discardMin = 0, discardMax = 0,
		},
	},
	-- the Goons, who kept their old sight and reactions in 1.0 (no presets): Knight (bossknight.json)
	bossknight = {
		normal = {
			sight = 142, cone = 160, notice = 4, peace = 0.95, lose = 1.1, forget = 104, lightAdd = 43,
			hearClose = 36, hearFar = 66, hearChance = 0.98, hearDelay = 0, hearPeace = 0,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.1,
			hitDelay = 0.57, hitMin = 4, hitMax = 10, discard = 0.16, discardMin = 0.3, discardMax = 0.6,
		},
	},
	-- Big Pipe (followerbigpipe.json)
	followerbigpipe = {
		normal = {
			sight = 170, cone = 180, notice = 2, peace = 0.95, lose = 1.1, forget = 52, lightAdd = 43,
			hearClose = 36, hearFar = 66, hearChance = 0.98, hearDelay = 0, hearPeace = 0,
			aimTime = 0.3, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.1,
			hitDelay = 0.27, hitMin = 4, hitMax = 8, discard = 0.01, discardMin = 0, discardMax = 0,
		},
	},
	-- Birdeye (followerbirdeye.json)
	followerbirdeye = {
		normal = {
			sight = 250, cone = 179, notice = 15.384, peace = 1, lose = 2, forget = 102, lightAdd = 48,
			hearClose = 36, hearFar = 66, hearChance = 1, hearDelay = 0, hearPeace = 0,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.1,
			hitDelay = 0.57, hitMin = 4, hitMax = 10, discard = 0.46, discardMin = 0.3, discardMax = 0.6,
		},
	},
	-- Partisan (bosspartisan.json; preset "bossPartisan": sight 142 -> 117 m, cone 160 -> 70, first contact 0.1 -> 0.75 s)
	bosspartisan = {
		normal = {
			sight = 117, cone = 70, notice = 2, peace = 1, lose = 1.1, forget = 52, lightAdd = 48,
			hearClose = 26, hearFar = 56, hearChance = 0.88, hearDelay = 0, hearPeace = 0,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.75,
			hitDelay = 0.57, hitMin = 4, hitMax = 10, discard = 0.86, discardMin = 0.3, discardMax = 0.6,
		},
	},
	-- the cultists' priest (sectantpriest.json; no preset)
	sectantpriest = {
		normal = {
			sight = 142, cone = 160, notice = 2, peace = 0.75, lose = 0.2, forget = 52, lightAdd = 48,
			hearClose = 36, hearFar = 66, hearChance = 0.88, hearDelay = 0, hearPeace = 0,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.1,
			hitDelay = 0.57, hitMin = 4, hitMax = 10, discard = 0.86, discardMin = 0.3, discardMax = 0.6,
		},
	},
	-- the cultists' warriors (sectantwarrior.json; no preset)
	sectantwarrior = {
		normal = {
			sight = 142, cone = 160, notice = 2, peace = 0.75, lose = 0.2, forget = 52, lightAdd = 48,
			hearClose = 36, hearFar = 66, hearChance = 0.88, hearDelay = 0, hearPeace = 0,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.1,
			hitDelay = 0.57, hitMin = 4, hitMax = 10, discard = 0.86, discardMin = 0.3, discardMax = 0.6,
		},
	},
	-- Glukhar (bossgluhar.json; preset "bossGluhar": sight 142 -> 140 m, cone 160 -> 85, first contact 0.1 -> 0.75 s), the
	-- nearest role for our Foreman
	bossgluhar = {
		normal = {
			sight = 140, cone = 85, notice = 2, peace = 1, lose = 1.1, forget = 52, lightAdd = 48,
			hearClose = 26, hearFar = 56, hearChance = 0.88, hearDelay = 0, hearPeace = 0,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.75,
			hitDelay = 0.57, hitMin = 4, hitMax = 10, discard = 0.86, discardMin = 0.3, discardMax = 0.6,
		},
	},
	-- Glukhar's assault guards (followergluharassault.json; preset "followerGluharAssault": sight 142 -> 117 m, cone
	-- 160 -> 70, first contact 0.1 -> 0.75 s), for the Foreman's crew
	followergluharassault = {
		normal = {
			sight = 117, cone = 70, notice = 2, peace = 1, lose = 1.1, forget = 52, lightAdd = 48,
			hearClose = 26, hearFar = 56, hearChance = 0.88, hearDelay = 0, hearPeace = 0,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.75,
			hitDelay = 0.57, hitMin = 4, hitMax = 10, discard = 0.86, discardMin = 0.3, discardMax = 0.6,
		},
	},
	-- Shturman (bosskojaniy.json; preset "bossKojaniy": sight 162 -> 165 m, cone 160 -> 85, first contact 0.1 -> 0.75 s),
	-- for our Sawyer on Pinewatch
	bosskojaniy = {
		normal = {
			sight = 165, cone = 85, notice = 15.384, peace = 1, lose = 2, forget = 102, lightAdd = 48,
			hearClose = 36, hearFar = 66, hearChance = 1, hearDelay = 0, hearPeace = 0,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.75,
			hitDelay = 0.57, hitMin = 4, hitMax = 10, discard = 0.46, discardMin = 0.3, discardMax = 0.6,
		},
	},
	-- Shturman's guards (followerkojaniy.json; no preset), for the Sawyer's crew
	followerkojaniy = {
		normal = {
			sight = 162, cone = 160, notice = 15.384, peace = 1, lose = 2, forget = 102, lightAdd = 48,
			hearClose = 36, hearFar = 66, hearChance = 1, hearDelay = 0, hearPeace = 0,
			aimTime = 1.5, aimMove = 1.1, scatter = 0.4, shift = 0.05, firstAdd = 0.1,
			hitDelay = 0.57, hitMin = 4, hitMax = 10, discard = 0.46, discardMin = 0.3, discardMax = 0.6,
		},
	},
} :: { [string]: { [string]: Role } }

-- ── who is which role ────────────────────────────────────────────────────────────
-- our bosses and named men (the Label attribute) and the EFT role each takes
BotData.BOSS_ROLE = {
	Broker = "bossbully", -- Reshala
	Caretaker = "bosskilla", -- Killa
	Stoker = "bosstagilla", -- Tagilla
	Halberd = "bossknight", -- THE HOUNDS: Knight,
	Mortar = "followerbigpipe", -- Big Pipe
	Kestrel = "followerbirdeye", -- and Birdeye
	Forester = "bosspartisan", -- Partisan
	Priest = "sectantpriest", -- THE CULT: the priest
	Cultist = "sectantwarrior", -- and his warriors
	Foreman = "bossgluhar", -- no EFT twin (Quay 7): Glukhar, the nearest (a boss with a crew who fight with rifles)
	Sawyer = "bosskojaniy", -- no EFT twin (Pinewatch, a Woods-type map): Shturman, the sawmill boss with two guards
} :: { [string]: string }
-- a boss's unnamed crew, by the boss's label
BotData.CREW_ROLE = { Broker = "followerbully", Foreman = "followergluharassault", Sawyer = "followerkojaniy" } :: { [string]: string }
-- by AI kind: the Harbor Watch have no EFT twin; raiders are the nearest (guards of raider grade)
BotData.KIND_ROLE = { scav = "assault", watch = "pmcbot", follower = "followerbully", boss = "bossgluhar" } :: { [string]: string }

function BotData.roleFor(kind: string, label: string?, leaderLabel: string?): string
	if kind == "scav" or kind == "watch" then
		return BotData.KIND_ROLE[kind]
	end
	local named = label and BotData.BOSS_ROLE[label]
	if named then
		return named
	end
	if kind == "follower" and leaderLabel and BotData.CREW_ROLE[leaderLabel] then
		return BotData.CREW_ROLE[leaderLabel]
	end
	return BotData.KIND_ROLE[kind] or "assault"
end

-- ── the maps ─────────────────────────────────────────────────────────────────────
-- BotLocationModifier and the difficulty mix (BotEasy, BotNormal, BotHard) of the map each of ours copies: Border Yard is
-- Customs (bigmap), Meridian Mall Interchange; the same numbers on both. The maps with no twin on disk take Customs'.
--   sight / gain        VisibleDistance / GainSight: map multipliers on sight and on notice speed
--   rainSight / rainSpeed  RainVisibilityDistanceCoef / RainVisibilitySpeedCoef;  fogSight / fogSpeed  the Fog ones
-- A coefficient is read as the share of the weather's effect a map takes (1 - coef x intensity): Customs' rain takes 35 %
-- off sight at full rain; 0 means no effect (read the other way, a 0 would blind every bot in fog)
export type MapMods = {
	sight: number, gain: number, rainSight: number, rainSpeed: number, fogSight: number, fogSpeed: number,
	mix: { easy: number, normal: number, hard: number },
}
local CUSTOMS: MapMods = {
	sight = 1, gain = 1, rainSight = 0.35, rainSpeed = 0, fogSight = 0, fogSpeed = 0,
	mix = { easy = 10, normal = 50, hard = 40 },
}
BotData.MAPS = { border = CUSTOMS, meridian = table.clone(CUSTOMS) } :: { [string]: MapMods }
function BotData.mapMods(id: string?): MapMods
	return (id and BotData.MAPS[id]) or CUSTOMS
end

-- sight and notice-speed multipliers for rain (0..1) and fog (0..1) on a map
function BotData.weather(mods: MapMods, rain: number, fog: number): (number, number)
	local sight = (1 - mods.rainSight * rain) * (1 - mods.fogSight * fog)
	local speed = (1 - mods.rainSpeed * rain) * (1 - mods.fogSpeed * fog)
	return sight, speed
end

-- ── difficulty ───────────────────────────────────────────────────────────────────
-- r in [0, 1) against the map's mix (percentages)
function BotData.roll(r: number, mix: { easy: number, normal: number, hard: number }): string
	local total = mix.easy + mix.normal + mix.hard
	local x = r * total
	if x < mix.easy then
		return "easy"
	elseif x < mix.easy + mix.normal then
		return "normal"
	end
	return "hard"
end

-- a new bot's difficulty: scavs roll the map's mix; EFT's sniper waves on Customs are all "hard" (BotPreset); bosses and
-- their guards are "normal" (BossDifficult, BossEscortDifficult)
function BotData.difficulty(role: string, r: number, mix: { easy: number, normal: number, hard: number }): string
	if role == "assault" then
		return BotData.roll(r, mix)
	elseif role == "marksman" then
		return "hard"
	end
	return "normal"
end

-- ── the rules ────────────────────────────────────────────────────────────────────
-- seconds to notice someone `m` metres away at notice speed 1 (Look)
function BotData.noticeTime(m: number): number
	local L = BotData.LOOK
	if m <= 0 then
		return L.close
	elseif m <= L.midDist then
		return L.close + (L.middle - L.close) * m / L.midDist
	end
	return L.middle + (L.far - L.middle) * (m - L.midDist) / (L.farDist - L.midDist)
end

-- the same for a bot of stats `s` (its notice speed), `studs` away
function BotData.noticeAt(studs: number, s: { notice: number }): number
	return BotData.noticeTime(studs / BotData.STUDS) / s.notice
end

-- the multiplier on a bot's tuned spread `elapsed` seconds into a contact: EFT's scatter starts at MaxScatter, settles to
-- WorkingScatter within MAX_AIM_TIME (TIME_COEF_IF_MOVE longer while the bot moves); before the aim starts (elapsed < 0,
-- an aim thrown away by a hit) it is at its widest
function BotData.aimMul(elapsed: number, s: { aimStart: number, aimTime: number, aimMove: number }, moving: boolean?): number
	local T = s.aimTime * (moving and s.aimMove or 1)
	if elapsed >= T then
		return 1
	elseif elapsed <= 0 then
		return s.aimStart
	end
	return s.aimStart + (1 - s.aimStart) * elapsed / T
end

-- how far off (degrees) a hit has thrown the aim `elapsed` seconds after it: `ang` at once, back on target after `dur`
-- (Aiming.BASE_HIT_AFFECTION_*)
function BotData.hitAngle(ang: number, dur: number, elapsed: number): number
	if elapsed >= dur then
		return 0
	elseif elapsed <= 0 then
		return ang
	end
	return ang * (1 - elapsed / dur)
end

-- may a bot aim at the head on a contact that began `gap` seconds after it last saw the target (nil: never seen)?
function BotData.headAllowed(gap: number?): boolean
	return gap ~= nil and gap < BotData.HEAD_UNSEEN
end

-- ── one role at one difficulty, in studs ─────────────────────────────────────────
export type Stats = {
	role: string, diff: string, sight: number, cone: number, coneCos: number, notice: number, peace: number,
	lose: number, forget: number, find: number, lightAdd: number, hearClose: number, hearFar: number,
	hearChance: number, hearDelay: number, hearPeace: number, shotHear: number, aimTime: number, aimMove: number,
	aimStart: number, spreadMul: number, firstAdd: number, firstChance: number, hitDelay: number, hitMin: number,
	hitMax: number, discard: number, discardMin: number, discardMax: number,
}
local cache: { [string]: Stats } = {}
function BotData.stats(role: string, diff: string?): Stats
	local key = role .. "/" .. (diff or "normal")
	local hit = cache[key]
	if hit then
		return hit
	end
	local set = BotData.ROLES[role] or BotData.ROLES.assault
	local base = set.normal
	local r = set[diff or "normal"] or base
	local S = BotData.STUDS
	local ref = BotData.ROLES.assault.normal
	local s: Stats = {
		role = role, diff = (set[diff or "normal"] and diff) or "normal",
		sight = r.sight * S, cone = r.cone,
		coneCos = (r.cone >= 180) and -2 or math.cos(math.rad(r.cone)), -- below -1: all round
		notice = r.notice, peace = r.peace, lose = r.lose, forget = r.forget, find = BotData.SHARED.find,
		lightAdd = r.lightAdd * S, hearClose = r.hearClose * S, hearFar = r.hearFar * S, hearChance = r.hearChance,
		hearDelay = r.hearDelay, hearPeace = r.hearPeace,
		-- gunfire carries as far for each role, against a scav, as its simple sounds do (EFT gives no gunfire figure)
		shotHear = r.hearFar / ref.hearFar,
		aimTime = r.aimTime, aimMove = r.aimMove, aimStart = r.scatter / BotData.SHARED.scatterWork,
		spreadMul = r.shift / base.shift,
		firstAdd = r.firstAdd, firstChance = BotData.SHARED.firstChance,
		hitDelay = r.hitDelay, hitMin = r.hitMin, hitMax = r.hitMax,
		discard = r.discard, discardMin = r.discardMin, discardMax = r.discardMax,
	}
	cache[key] = s
	return s
end

return BotData
