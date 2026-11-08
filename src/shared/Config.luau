--!strict
-- Zero Return: tunable constants shared by server and client (read-only).
local Config = {
	GAME_NAME = "ZERO RETURN",
	BUILD = "0.10.0-audit", -- the one build label (Version.luau, unused and stale, was removed: audit tech.15)
	MAP_NAME = "QUAY 7",
	RECORDER = "FIELD RECORDER M4",
	CURRENCY = "MK",

	RAID_DURATION = 1500, -- seconds: one shared 25-minute raid per cycle (Tarkov-length)
	MATCH_TIME = 12, -- countdown after the first player queues (others can join the queue)
	LATE_JOIN = 300, -- PMCs may still deploy into a running raid this long after it starts
	SCAV_CUTOFF = 360, -- player scavs can join until this many seconds remain
	-- Decision gameplay-6b, "Tarkov's rules, scaled times": EFT's out-of-raid waits, each divided (or its rate multiplied)
	-- by one constant so they fit Roblox sessions.
	-- Scav cooldown: EFT's is about 25 minutes before karma and hideout bonuses (west-games.com scav cooldown calculator, a
	-- planning figure, not official); ours is 15 minutes, still lengthened or shortened by karma (Progress.scavCooldown).
	SCAV_COOLDOWN = 900,
	MAX_PLAYERS = 12,
	MAX_SQUAD = 5,
	-- Insurance (EFT wiki, Insurance: Prapor returns after 24-36 h and holds 4 days, the Therapist 12-24 h and 6 days; EFT
	-- 1.1.0 added Jaeger, faster and dearer). Each insurer's hours and price are in TraderData.INSURERS; here the shared rules.
	INSURANCE_RATE = 0.07, -- VOS's (Prapor's) fee as a share of an item's value; HALE and BRAM multiply VOS's price
	INSURANCE_MIN = 150, -- the least VOS charges for one item
	INSURANCE_RETURN_DIV = 12, -- EFT's return windows divided by 12: Prapor's 24-36 h -> VOS 2-3 h
	INSURANCE_HOLD_DIV = 4, -- EFT's storage times divided by 4: Prapor's 4 days -> VOS 24 h in the messenger
	INSURANCE_DELAY = 0, -- added by Match.deliverInsured to a new claim's readyAt: 0, so readyAt is the moment the gear was lost and Settle.fileClaims rolls the insurer's own window from there
	-- Health after death or MIA (EFT wiki, Health system: "HP is reset to 30 % and automatically recovers"): every part at
	-- this share of its maximum when the player is next in the bunker.
	DEATH_HEALTH = 0.3,
	-- Out-of-raid recovery (EFT wiki, Health system: 456.6 HP an hour, 7.61 a minute, and 1 energy and 1 hydration a
	-- minute; the hideout's medical station raises it): EFT's rates times OUT_REGEN_MUL. The HP is one pool spread over the
	-- damaged parts (not per part); the medstation's multiplier (Hideout.healRate) applies to the HP.
	OUT_REGEN_MUL = 4,
	OUT_REGEN_HP_HOUR = 456.6, -- EFT's HP an hour (x OUT_REGEN_MUL = 1,826.4 an hour here)
	OUT_REGEN_VITALS_MIN = 1, -- EFT's energy and hydration a minute (x OUT_REGEN_MUL = 4 a minute here)
	-- Hideout (decision economy-7b with economy-4b, "EFT curves, faster clocks"): EFT's costs and requirements exactly
	-- (1 rouble = 1 MK), and every real-time hideout timer (construction, crafts, the scav case, the bitcoin farm, the
	-- generator's fuel burn) divided by this one constant. 4 is ours: the audit's example factor (economy.md, economy-4b).
	HIDEOUT_TIME_DIV = 4,
	BODY_TIME = 600, -- player bodies stay lootable this long (or until the raid ends)
	AI_MAX = 18, -- live AI cap per raid
	SCAV_START = 4, -- AI scavs at raid start (+ SCAV_PER_PLAYER per raider, up to SCAV_CAP)
	SCAV_PER_PLAYER = 0.5,
	SCAV_CAP = 10,
	SCAV_WAVE_EVERY = 240, -- seconds between scav waves (2-3 each) while more than 5 minutes remain
	BOSS_CHANCE = 0.5, -- the Foreman and his crew hold the freight depot in this share of raids
	EXTRACT_HOLD = 8, -- Tarkov's standard exit timer (SPT ExfiltrationTime); an exit with its own sets rule.time

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

	SAFEHOUSE_ORIGIN = Vector3.new(0, -300, 4000), -- Relay 7, far from every map: no map streams in while you are in the bunker
}

return Config
