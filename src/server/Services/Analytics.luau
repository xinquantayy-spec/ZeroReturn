--!nonstrict
-- Measure after launch (audit tech.16): AnalyticsService custom events for join, deploy, extract, death and MIA, and
-- each raid's average frame rate and graphics level by device (the client measures it, Detail.luau, and reports it once
-- with the "perf" act when the raid ends). Roblox records these only from the server and only in a published game
-- ("Events can't be sent from the client or Studio": create.roblox.com/docs/production/analytics/custom-events), so every
-- call is wrapped in pcall and skipped in Studio, and nothing here can break a raid. Up to three custom fields carry
-- string values (create.roblox.com/docs/production/analytics/custom-fields: Enum.AnalyticsCustomFieldKeys, 8,000
-- combinations); six event names of the 100 allowed. Loaded by Raid.init (optional, like Glass).
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local STUDIO = game:GetService("RunService"):IsStudio()

local Analytics = {}
local ctx

local F1 = Enum.AnalyticsCustomFieldKeys.CustomField01.Name
local F2 = Enum.AnalyticsCustomFieldKeys.CustomField02.Name
local F3 = Enum.AnalyticsCustomFieldKeys.CustomField03.Name
local QNAMES = { [0] = "POTATO", "LOW", "MEDIUM", "HIGH" } -- the GRAPHICS levels (Detail.luau)
local DEVICES = { phone = true, pc = true, console = true } -- Settings.deviceClass on the client
local REPORT_WINDOW = 120 -- seconds after a raid in which its frame-rate report is taken

-- the last events, also in Studio where Roblox drops them (for checks and the dev console)
Analytics.recent = {}
local KEEP = 40
local lastRaid = {} -- [player] = { map, ended = time, reported } for the frame-rate report

function Analytics.send(player, name, value, fields)
	table.insert(Analytics.recent, { name = name, value = value, fields = fields, player = player and player.Name or nil })
	if #Analytics.recent > KEEP then
		table.remove(Analytics.recent, 1)
	end
	if STUDIO or not (player and player.Parent) then
		return false
	end
	local ok = pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, fields)
	end)
	return ok
end

local function sideOf(s)
	return (s and s.scav) and "Side - SCAV" or "Side - PMC"
end

local function mapOf(s)
	return "Map - " .. tostring(s and s.map or "?")
end

function Analytics.levelBand(level)
	level = tonumber(level) or 1
	return "Level - " .. ((level < 5 and "1-4") or (level < 10 and "5-9") or (level < 20 and "10-19") or (level < 30 and "20-29") or "30-40")
end

-- who killed a character: another player, the AI, a map hazard (a string attacker), or nothing recent (bleeding, a fall)
function Analytics.killerKind(char)
	local hs = char and ctx and ctx.Health and ctx.Health.get(char)
	local lh = hs and hs.lastHit
	if not lh or os.clock() - (lh.at or 0) > 30 then
		return "Killer - Other"
	end
	local a = lh.attacker
	if type(a) == "string" then
		return "Killer - Hazard"
	elseif typeof(a) == "Instance" then
		if a:IsA("Player") then
			return "Killer - Player"
		elseif a:IsA("Model") then
			return "Killer - AI"
		end
	end
	return "Killer - Other"
end

-- ── hooks (called from Raid.luau) ──────────────────────────────────────────────────────────────────────────
function Analytics.join(player, isNew)
	Analytics.send(player, "Join", 1, { [F1] = isNew and "Profile - New" or "Profile - Returning" })
end

function Analytics.deploy(player, s)
	local prof = ctx and ctx.Profiles.get(player)
	local level = prof and ctx.Economy and ctx.Economy.level(prof) or 1
	lastRaid[player] = { map = s and s.map or "?", ended = nil, reported = false }
	Analytics.send(player, "Deploy", 1, { [F1] = mapOf(s), [F2] = sideOf(s), [F3] = Analytics.levelBand(level) })
end

-- the raid's end: extracted (the value is the raid's length in seconds), killed or missing in action
function Analytics.raidEnd(player, s, outcome, summary, char)
	local secs = math.max(0, math.floor((summary and summary.time) or 0))
	local r = lastRaid[player]
	if r then
		r.ended = os.clock()
	end
	if outcome == "SUCCESS" then
		Analytics.send(player, "Extract", secs, { [F1] = mapOf(s), [F2] = sideOf(s), [F3] = (summary and summary.runThrough) and "Exit - Run through" or "Exit - Survived" })
	elseif outcome == "KIA" then
		Analytics.send(player, "Death", secs, { [F1] = mapOf(s), [F2] = sideOf(s), [F3] = Analytics.killerKind(char) })
	elseif outcome == "MIA" then
		Analytics.send(player, "MIA", secs, { [F1] = mapOf(s), [F2] = sideOf(s) })
	end
end

-- ── the client's frame-rate report ("perf" act): { fps, q = GRAPHICS level 0-3, dev = device class, t = seconds } ──
-- taken once per raid, within two minutes of its end, for a raid of at least 30 s measured
function Analytics.perf(player, p)
	if type(p) ~= "table" then
		return false
	end
	local fps, t = p.fps, p.t
	if type(fps) ~= "number" or fps ~= fps or type(t) ~= "number" or t ~= t or t < 30 then
		return false
	end
	local r = lastRaid[player]
	if not r or r.reported or not r.ended or os.clock() - r.ended > REPORT_WINDOW then
		return false
	end
	r.reported = true
	local q = type(p.q) == "number" and p.q == p.q and math.clamp(math.floor(p.q), 0, 3) or nil
	local dev = DEVICES[p.dev] and p.dev or "unknown"
	return Analytics.send(player, "RaidFps", math.clamp(math.floor(fps + 0.5), 1, 240), {
		[F1] = "Device - " .. dev, [F2] = "Graphics - " .. (q and QNAMES[q] or "?"), [F3] = "Map - " .. tostring(r.map),
	}) or STUDIO
end

function Analytics.forget(player)
	lastRaid[player] = nil
end

function Analytics.init(c)
	ctx = c
	ctx.Remotes.onAct("perf", Analytics.perf, 0.2, 2)
	Players.PlayerRemoving:Connect(Analytics.forget)
end

return Analytics
