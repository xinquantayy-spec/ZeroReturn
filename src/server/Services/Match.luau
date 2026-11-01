--!nonstrict
-- Raid cycles on this server (one shared raid at a time, Tarkov rules):
--   IDLE -> MATCHING (countdown after the first player queues; others join the queue) -> RUNNING (one shared
--   raid clock; PMCs may still deploy for LATE_JOIN seconds, player scavs until SCAV_CUTOFF before the end)
--   -> IDLE when the clock runs out (everyone still inside is MIA) or when nobody is left inside.
--   Insurance is settled at the end of every raid and the world is cleared for the next one.
-- Squads: invite / accept / leave in the hideout; queued squad members spawn together and wear one armband
-- colour (no friendly markers, Tarkov-style). Spawns are picked far from anyone already in the raid.
-- Maps (M13): queued players vote for the map of the next raid; the most votes win and a tie (or no votes) is
-- settled at random. The raid length comes from the map.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Env = require(Shared.Env)
local Maps = require(Shared.Maps)
local Inv = require(script.Parent.Inv)

local Match = {
	state = "IDLE", id = nil, startsAt = 0, endsAt = 0, lateUntil = 0, startedAt = 0,
	extractOpen = {}, flareOpen = {}, usedSpawns = {}, squadSpawn = {}, raids = 0,
	env = nil, -- this raid's time of day and weather (Env.State, t0 = raid start)
	nextEnv = nil, -- rolled when matching starts, so the deploy screen can show it
	map = nil, -- map of the running (or last) raid
	forceMap = nil, -- dev: next raids on this map
}
local envRng = Random.new()
local ctx
local queue = {} -- [Player] = { kind = "pmc" | "scav", t, vote = map id or nil }
local squads = {} -- [sid] = { id, leader = Player, members = { Player }, color }
local squadOf = {} -- [Player] = sid
local invites = {} -- [Player target] = { from = Player, t }
local COLORS = { "D9A441", "4FA3D9", "D9584F", "6CC27A", "B97FD9", "E6E6E6" }
local colorTurn = 0
local lastBroadcast = 0

local function now()
	return workspace:GetServerTimeNow()
end

local function count(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function liveSessions()
	local n = 0
	for _, s in ctx.Raid.sessions() do
		if not s.done then
			n += 1
		end
	end
	return n
end
Match.liveSessions = liveSessions

-- ── squads ───────────────────────────────────────────────────────────────────
function Match.squadOf(player)
	local sid = squadOf[player]
	return sid and squads[sid] or nil
end

local function memberStatus(m)
	local s = ctx.Raid.session(m)
	if s and not s.done then
		return s.scav and "SCAV RAID" or "IN RAID"
	elseif queue[m] then
		return queue[m].kind == "scav" and "QUEUED (SCAV)" or "QUEUED"
	end
	return "HIDEOUT"
end

function Match.pushSquad(sq)
	if not sq then
		return
	end
	local members = {}
	for _, m in sq.members do
		table.insert(members, { name = m.DisplayName, id = m.UserId, leader = m == sq.leader, status = memberStatus(m) })
	end
	local info = { id = sq.id, color = sq.color, leader = sq.leader.UserId, members = members }
	for _, m in sq.members do
		if m.Parent then
			ctx.Remotes.note(m, "squad", info)
		end
	end
end

-- called by Raid / queue changes so squadmates see who is where
function Match.touch(player)
	local sq = Match.squadOf(player)
	if sq then
		Match.pushSquad(sq)
	end
end

local function setArmband(player, color)
	local char = player.Character
	if char then
		ctx.Chars.armband(char, color)
	end
end

local function leave(player)
	local sid = squadOf[player]
	local sq = sid and squads[sid]
	squadOf[player] = nil
	if player.Parent then
		ctx.Remotes.note(player, "squad", { members = {} })
		if not ctx.Raid.session(player) then
			setArmband(player, nil)
		end
	end
	if not sq then
		return
	end
	local i = table.find(sq.members, player)
	if i then
		table.remove(sq.members, i)
	end
	if #sq.members <= 1 then
		for _, m in sq.members do
			squadOf[m] = nil
			if m.Parent then
				ctx.Remotes.note(m, "squad", { members = {} })
				if not ctx.Raid.session(m) then
					setArmband(m, nil)
				end
			end
		end
		squads[sid] = nil
		return
	end
	if sq.leader == player then
		sq.leader = sq.members[1]
	end
	Match.pushSquad(sq)
end
Match.leave = leave

local function squadReq(player, p)
	local op = p.op
	if op == "invite" then
		local target = type(p.target) == "number" and Players:GetPlayerByUserId(p.target)
		if not target or target == player then
			return ctx.Remotes.fail("NO_PLAYER", "That operator is not on this server.")
		end
		if ctx.Raid.session(player) or ctx.Raid.session(target) then
			return ctx.Remotes.fail("IN_RAID", "Squads form in the hideout.")
		end
		local sq = Match.squadOf(player)
		if sq and #sq.members >= Config.MAX_SQUAD then
			return ctx.Remotes.fail("SQUAD_FULL", "Squad is full.")
		end
		if squadOf[target] and squadOf[target] == squadOf[player] then
			return ctx.Remotes.fail("ALREADY_IN_SQUAD", "Already in your squad.")
		end
		invites[target] = { from = player, t = os.clock() }
		ctx.Remotes.note(target, "squadInvite", { from = player.DisplayName, fromId = player.UserId })
		return ctx.Remotes.ok()
	elseif op == "accept" then
		local inv = invites[player]
		local from = inv and inv.from
		if not from or not from.Parent or os.clock() - inv.t > 60 or type(p.from) ~= "number" or from.UserId ~= p.from then
			return ctx.Remotes.fail("NO_INVITE", "That invite expired.")
		end
		invites[player] = nil
		if ctx.Raid.session(player) or ctx.Raid.session(from) then
			return ctx.Remotes.fail("IN_RAID", "Squads form in the hideout.")
		end
		if squadOf[player] then
			leave(player)
		end
		local sq = Match.squadOf(from)
		if not sq then
			colorTurn = colorTurn % #COLORS + 1
			sq = { id = Util.guid(), leader = from, members = { from }, color = COLORS[colorTurn] }
			squads[sq.id] = sq
			squadOf[from] = sq.id
			setArmband(from, sq.color)
		end
		if #sq.members >= Config.MAX_SQUAD then
			return ctx.Remotes.fail("SQUAD_FULL", "Squad is full.")
		end
		table.insert(sq.members, player)
		squadOf[player] = sq.id
		setArmband(player, sq.color)
		Match.pushSquad(sq)
		return ctx.Remotes.ok()
	elseif op == "decline" then
		local inv = invites[player]
		invites[player] = nil
		if inv and inv.from and inv.from.Parent then
			ctx.Remotes.note(inv.from, "toast", { text = player.DisplayName .. " DECLINED THE INVITE", tone = "warn" })
		end
		return ctx.Remotes.ok()
	elseif op == "leave" then
		if ctx.Raid.session(player) then
			return ctx.Remotes.fail("IN_RAID", "Leave the squad from the hideout.")
		end
		leave(player)
		return ctx.Remotes.ok()
	elseif op == "kick" then
		local sq = Match.squadOf(player)
		local target = type(p.target) == "number" and Players:GetPlayerByUserId(p.target)
		if not sq or sq.leader ~= player or not target or squadOf[target] ~= sq.id or target == player then
			return ctx.Remotes.fail("NOT_AUTHORIZED")
		end
		if ctx.Raid.session(target) then
			return ctx.Remotes.fail("IN_RAID")
		end
		leave(target)
		return ctx.Remotes.ok()
	end
	return ctx.Remotes.fail("BAD_INPUT")
end

-- ── status ───────────────────────────────────────────────────────────────────
function Match.status(player)
	local prof = player and ctx.Profiles.get(player)
	local q = player and queue[player]
	return {
		state = Match.state, raidId = Match.id, startsAt = Match.startsAt, endsAt = Match.endsAt, lateUntil = Match.lateUntil,
		scavUntil = Match.endsAt - Config.SCAV_CUTOFF, queued = q and q.kind or nil, inQueue = count(queue),
		inRaid = liveSessions(), maxPlayers = Config.MAX_PLAYERS, scavReadyAt = prof and prof.scavReadyAt or 0, serverTime = os.time(),
		env = (Match.state == "RUNNING") and Match.env or Match.nextEnv,
		map = (Match.state == "RUNNING") and Match.map or nil, votes = Match.tally(), vote = q and q.vote or nil,
	}
end

-- ── map vote ─────────────────────────────────────────────────────────────────
function Match.tally()
	local t = {}
	for _, q in queue do
		if q.vote then
			t[q.vote] = (t[q.vote] or 0) + 1
		end
	end
	return t
end

-- change your vote while waiting in the queue (nil = any map)
function Match.vote(player, id)
	local q = queue[player]
	if not q then
		return false, "NOT_QUEUED"
	end
	if id ~= nil and not Maps.valid(id) then
		return false, "BAD_INPUT"
	end
	q.vote = id
	Match.broadcast()
	return true
end

-- the map for the raid that is about to start
function Match.pickMap()
	if Match.forceMap and Maps.valid(Match.forceMap) then
		return Match.forceMap
	end
	return Maps.winner(Match.tally(), function(n)
		return math.random(1, n)
	end)
end

function Match.broadcast()
	lastBroadcast = os.clock()
	for _, p in Players:GetPlayers() do
		if ctx.Profiles.get(p) then
			ctx.Remotes.note(p, "match", Match.status(p))
		end
	end
end

-- ── spawns / extracts ────────────────────────────────────────────────────────
function Match.pickSpawn()
	local best, bestScore
	for _, sp in ctx.World.spawns do
		local d = 1000
		for player, s in ctx.Raid.sessions() do
			local r = not s.done and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if r then
				d = math.min(d, (r.Position - sp.cf.Position).Magnitude)
			end
		end
		local score = d - (Match.usedSpawns[sp.id] and 250 or 0) + math.random() * 30
		if not bestScore or score > bestScore then
			best, bestScore = sp, score
		end
	end
	Match.usedSpawns[best.id] = true
	return best
end

-- a late-joining squad member inserts where the squad went in (within the late-join window)
function Match.spawnFor(player, kind)
	local sid = squadOf[player]
	local ss = sid and Match.squadSpawn[sid .. kind]
	if ss and ss.raid == Match.id and now() - ss.t < Config.LATE_JOIN then
		ss.n += 1
		return ss.spawn, ss.n
	end
	local spawn = Match.pickSpawn()
	if sid then
		Match.squadSpawn[sid .. kind] = { spawn = spawn, raid = Match.id, t = now(), n = 1 }
	end
	return spawn, 1
end

-- extracts for a session: PMCs get their side's list, scavs every extract including scav-only ones, except the cars
-- (Tarkov's vehicle exits are for PMCs only)
function Match.extractsFor(spawn, scav)
	if scav then
		local all = {}
		for id, e in ctx.World.extracts do
			if ctx.Extract.scavMay(e) then
				table.insert(all, id)
			end
		end
		table.sort(all)
		return all
	end
	return table.clone(spawn.extracts)
end

-- which exits are there this raid: a chance exit rolls its chance (a paid car too), every other exit is always there.
-- `roll` (optional, id -> number from 0 to 1) is a test seam.
function Match.rollExtracts(list, roll)
	local open = {}
	for id, e in list do
		open[id] = ctx.Extract.rollOpen(e.rule, roll and roll(id) or nil)
	end
	return open
end

-- ── queue / lifecycle ────────────────────────────────────────────────────────
-- can this kind of raider still enter the running raid?
function Match.canEnter(kind)
	if Match.state ~= "RUNNING" or liveSessions() >= Config.MAX_PLAYERS then
		return false
	end
	local t = now()
	if kind == "scav" then
		return t <= Match.endsAt - Config.SCAV_CUTOFF
	end
	return t <= Match.lateUntil
end

-- matching countdown; the next raid's time and weather are rolled now so the terminal can show them
local function beginMatching()
	Match.state = "MATCHING"
	Match.startsAt = now() + Config.MATCH_TIME
	Match.nextEnv = Match.forceEnv and table.clone(Match.forceEnv) or Env.roll(envRng)
end

-- returns "enter" (deploy now) or "queued"
function Match.request(player, kind, vote)
	if Match.canEnter(kind) then
		return "enter"
	end
	queue[player] = { kind = kind, t = now(), vote = Maps.valid(vote) and vote or nil }
	if Match.state == "IDLE" then
		beginMatching()
	end
	Match.broadcast()
	Match.touch(player)
	return "queued"
end

function Match.cancel(player)
	if queue[player] then
		queue[player] = nil
		if Match.state == "MATCHING" and next(queue) == nil then
			Match.state = "IDLE"
		end
		Match.broadcast()
		Match.touch(player)
		return true
	end
	return false
end

function Match.isQueued(player)
	return queue[player] ~= nil
end

function Match.queuedKind(player)
	local q = queue[player]
	return q and q.kind or nil
end

-- test hook (CharTests): mark a test double as queued without starting a match (set and cleared synchronously)
function Match.testQueue(player, kind)
	if typeof(player) == "Instance" then
		return
	end
	queue[player] = kind and { kind = kind, t = now() } or nil
end

local function startRaid()
	local t = now()
	Match.map = Match.pickMap()
	if not ctx.World.activate(Match.map) then
		Match.map = "quay7" -- the chosen map did not build (World logs why)
		ctx.World.activate(Match.map)
	end
	Match.state = "RUNNING"
	Match.id = Util.guid()
	Match.raids += 1
	Match.startedAt = t
	Match.endsAt = t + (Maps.defs[Match.map] and Maps.defs[Match.map].raidTime or Config.RAID_DURATION)
	Match.lateUntil = t + Config.LATE_JOIN
	Match.emptySince = nil
	Match.env = Match.nextEnv or (Match.forceEnv and table.clone(Match.forceEnv)) or Env.roll(envRng)
	Match.env.t0 = t
	Match.nextEnv = nil
	table.clear(Match.usedSpawns)
	table.clear(Match.squadSpawn)
	for id, open in Match.rollExtracts(ctx.World.extracts) do
		Match.extractOpen[id] = open
	end
	table.clear(Match.flareOpen) -- flare exits close again (Extract.openFlareAt)
	-- the queued raiders' karma, for this raid's boss rolls (THE FORESTER comes more often for low karma, AI.forestChance)
	Match.raidKarma = {}
	for player in queue do
		local prof = player.Parent and ctx.Profiles.get(player)
		if prof then
			table.insert(Match.raidKarma, prof.karma or 0)
		end
	end
	ctx.Raid.resetWorld() -- (also clears the cars' seats and shows or hides each car by this roll)
	-- group the queue: squad members of the same kind share a spawn
	local groups, bySquad = {}, {}
	for player, q in queue do
		if player.Parent then
			local sid = squadOf[player]
			local key = sid and (sid .. q.kind)
			if key and bySquad[key] then
				table.insert(bySquad[key].players, player)
			else
				local g = { kind = q.kind, players = { player }, key = key }
				table.insert(groups, g)
				if key then
					bySquad[key] = g
				end
			end
		end
	end
	table.clear(queue)
	for _, g in groups do
		local spawn = Match.pickSpawn()
		if g.key then
			Match.squadSpawn[g.key] = { spawn = spawn, raid = Match.id, t = t, n = #g.players }
		end
		for i, player in g.players do
			task.spawn(ctx.Raid.enter, player, g.kind, spawn, i)
		end
	end
	Match.broadcast()
end

-- Strip everything from a bundle that is not insured by `owner` (only insured parts come back).
local function stripUninsured(b, owner)
	local keep = { [b.g] = true }
	local kept = {}
	for _, sub in b.subs do
		if sub.it.ins == owner and keep[sub.a] then
			keep[sub.g] = true
			table.insert(kept, sub)
		end
	end
	b.subs = kept
	local all = { b }
	for _, sub in kept do
		table.insert(all, sub)
	end
	for _, x in all do
		local xi = x.it
		if xi.mag and not keep[xi.mag] then
			xi.mag = nil
		end
		if xi.mods then
			for mount, mg in xi.mods do
				if not keep[mg] then
					xi.mods[mount] = nil
				end
			end
			if next(xi.mods) == nil then
				xi.mods = nil
			end
		end
		xi.fip = nil
	end
end

-- Pull every insured item out of holder h into returns[owner] (an insured parent carries its insured parts).
function Match.collectInsured(h, returns)
	if not (h and h.items) then
		return 0
	end
	local list = {}
	for g, it in h.items do
		if it.ins then
			table.insert(list, g)
		end
	end
	local n = 0
	for _, g in list do
		local it = h.items[g]
		if it and it.ins then
			local parent = Inv.parentOf(h, g)
			local pit = parent and h.items[parent]
			if not (pit and pit.ins == it.ins) then
				local owner = it.ins
				local b = Inv.take(h, g)
				if b then
					stripUninsured(b, owner)
					returns[owner] = returns[owner] or {}
					table.insert(returns[owner], b)
					n += 1
				end
			end
		end
	end
	return n
end

-- Insured gear comes back to its owner after INSURANCE_DELAY (online: profile claims; offline: mailbox).
function Match.deliverInsured(returns)
	for owner, bundles in returns do
		local entry = { readyAt = os.time() + Config.INSURANCE_DELAY, bundles = bundles, raid = Match.id }
		local p = Players:GetPlayerByUserId(owner)
		local prof = p and ctx.Profiles.get(p)
		if prof then
			table.insert(prof.claims, entry)
			ctx.Profiles.markDirty(p)
			ctx.Remotes.note(p, "toast", { text = string.format("INSURANCE: %d ITEM(S) WILL BE RETURNED", #bundles), tone = "good" })
			ctx.Raid.push(p)
		else
			task.spawn(ctx.Store.mail, owner, entry)
		end
	end
end

function Match.settleInsurance()
	local returns = {}
	for _, c in ctx.Loot.containers do
		if c.temp and c.holder then
			Match.collectInsured(c.holder, returns)
		end
	end
	Match.deliverInsured(returns)
end

local function endRaid(reason)
	for player, s in ctx.Raid.sessions() do
		if not s.done then
			ctx.Raid.finalize(player, "MIA")
		end
	end
	local ok, err = pcall(Match.settleInsurance)
	if not ok then
		warn("[ZR] insurance settlement", err)
	end
	ctx.Raid.clearWorld()
	Match.state = "IDLE"
	Match.id = nil
	Match.endedReason = reason
	Match.env = nil
	if next(queue) then
		beginMatching()
	end
	Match.broadcast()
end
Match.endRaid = endRaid

local function tick()
	local t = now()
	if Match.state == "MATCHING" then
		for player in queue do
			if not player.Parent or not ctx.Profiles.get(player) then
				queue[player] = nil
			end
		end
		if next(queue) == nil then
			Match.state = "IDLE"
			Match.broadcast()
		elseif t >= Match.startsAt then
			startRaid()
		end
	elseif Match.state == "RUNNING" then
		if t >= Match.endsAt then
			endRaid("TIME")
			return
		end
		-- nobody inside: end early so the next raid starts fresh (and queued players get in)
		if liveSessions() == 0 and not Match.holdOpen then
			Match.emptySince = Match.emptySince or t
			if t - Match.emptySince > 8 then
				endRaid("EMPTY")
				return
			end
		else
			Match.emptySince = nil
		end
	end
	if os.clock() - lastBroadcast > 5 and Match.state ~= "IDLE" then
		Match.broadcast()
	end
end
Match.tick = tick

function Match.init(c)
	ctx = c
	ctx.Remotes.onReq("squad", squadReq, 4, 6)
	ctx.Remotes.onReq("queue", function(player, p)
		if p.op == "cancel" then
			Match.cancel(player)
		elseif p.op == "vote" then
			-- p.map: a map id, or nil for "any map"
			local ok, err = Match.vote(player, p.map)
			if not ok then
				return ctx.Remotes.fail(err)
			end
		end
		return ctx.Remotes.ok(Match.status(player))
	end, 4, 6)
end

function Match.start()
	Players.PlayerRemoving:Connect(function(player)
		queue[player] = nil
		invites[player] = nil
		if squadOf[player] then
			leave(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tick)
			if not ok then
				warn("[ZR] match tick", err)
			end
		end
	end)
end

return Match
