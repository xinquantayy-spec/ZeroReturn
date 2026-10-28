--!strict
-- Zero Return: tunable constants shared by server and client (read-only).
local Config = {
	GAME_NAME = "ZERO RETURN",
	BUILD = "0.1.0-m1",
	MAP_NAME = "QUAY 7",
	RECORDER = "FIELD RECORDER M4",
	CURRENCY = "MK",

	RAID_DURATION = 420, -- seconds (7 min test raids)
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
	AIM_SPEED = 7,
	SPRINT_DRAIN = 16,
	STAMINA_REGEN = 12,
	JUMP_COST = 14,

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
