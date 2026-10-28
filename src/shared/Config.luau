--!strict
-- Zero Return: tunable constants shared by server and client (read-only).
local Config = {
	GAME_NAME = "ZERO RETURN",
	BUILD = "0.6.0-m9",
	MAP_NAME = "QUAY 7",
	RECORDER = "FIELD RECORDER M4",
	CURRENCY = "MK",

	RAID_DURATION = 1500, -- seconds: one shared 25-minute raid per cycle (Tarkov-length)
	MATCH_TIME = 12, -- countdown after the first player queues (others can join the queue)
	LATE_JOIN = 300, -- PMCs may still deploy into a running raid this long after it starts
	SCAV_CUTOFF = 360, -- player scavs can join until this many seconds remain
	SCAV_COOLDOWN = 600,
	MAX_PLAYERS = 12,
	MAX_SQUAD = 5,
	INSURANCE_RATE = 0.07, -- fee as a share of item value
	INSURANCE_DELAY = 900, -- seconds until unlooted insured gear comes back
	BODY_TIME = 600, -- player bodies stay lootable this long (or until the raid ends)
	AI_MAX = 18, -- live AI cap per raid
	SCAV_START = 4, -- AI scavs at raid start (+ SCAV_PER_PLAYER per raider, up to SCAV_CAP)
	SCAV_PER_PLAYER = 0.5,
	SCAV_CAP = 10,
	SCAV_WAVE_EVERY = 240, -- seconds between scav waves (2-3 each) while more than 5 minutes remain
	BOSS_CHANCE = 0.5, -- the Foreman and his crew hold the freight depot in this share of raids
	EXTRACT_HOLD = 6,
	SEARCH_TIME = 1.2,
	INTERACT_RANGE = 10,
	RESPAWN_DELAY = 4,

	STASH_W = 10,
	STASH_H = 20,
	POCKETS_W = 4,
	POCKETS_H = 1,
	START_MONEY = 250000,
	RECOVERY_MONEY = 60000, -- free basic kit only when broke and without any firearm
	SELL_RATE = 0.6,
	MAX_HEALTH = 100,
	MAX_STAMINA = 100,

	WALK_SPEED = 11,
	SPRINT_SPEED = 17,
	CROUCH_SPEED = 6,
	PRONE_SPEED = 2.6,
	AIM_SPEED = 7,
	LEAN_SPEED = 6,
	SPRINT_DRAIN = 9, -- leg stamina per second (a full bar is ~11 s of sprint)
	STAMINA_REGEN = 6,
	JUMP_COST = 12,
	MAX_ARMS = 100, -- arm stamina: aiming and holding breath
	ADS_DRAIN = 0.8, -- per second, plus 0.25 per kg of weapon (a light carbine holds ~1 min)
	BREATH_DRAIN = 14,
	ARMS_REGEN = 9,
	WEIGHT_OVER = 26, -- kg: Tarkov-style overweight thresholds
	WEIGHT_CRIT = 46,
	WEIGHT_MAX = 66,
	PRONE_TIME = 0.9, -- stance transition to/from prone (no firing)
	VAULT_LOW = 0.55,
	VAULT_HIGH = 0.95,

	FOV = 85, -- wide bodycam lens (vertical FOV)
	AIM_FOV = 58,
	AIM_FOV_MUL = 0.84, -- iron/red-dot ADS narrows the lens slightly

	DATASTORE_LIVE = "ZR_Profiles_v1",
	DATASTORE_DEV = "DEV_ZR_Profiles_v1",
	LOCK_TTL = 150,
	AUTOSAVE = 60,
	FINALIZED_LOG = 20,

	SAFEHOUSE_ORIGIN = Vector3.new(0, -300, 0),
}

return Config
