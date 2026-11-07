--!nonstrict
-- Raid orchestration: player lifecycle, deploy reservation (PMC or player scav), raid sessions, settlement,
-- inventory requests. The shared raid clock, queue, squads and insurance settlement live in Match.luau.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local InputMap = require(Shared.InputMap)
local TouchLayout = require(Shared.TouchLayout)
local TD = require(Shared.TraderData)
local Grid = require(Shared.Grid)
local WP = require(Shared.WeaponParts)
local Inv = require(script.Parent.Inv)
local Settle = require(script.Parent.Settle)
local Progress = require(Shared.Progress)

local Raid = {}
local ctx
local sessions = {} -- [Player] = session
local deploying = {}
Raid.world = { status = "IDLE", seed = 0, resets = 0 }

local function now()
	return workspace:GetServerTimeNow()
end
local function fail(code, msg)
	return ctx.Remotes.fail(code, msg)
end
local function ok(data)
	return ctx.Remotes.ok(data)
end
-- analytics hooks (audit tech.16; Services/Analytics.luau, loaded by Raid.init): optional like Glass, and every call is
-- guarded, so a fault in it never touches a raid
local function track(fn, ...)
	local A = ctx and ctx.Analytics
	if A and A[fn] then
		local okT, errT = pcall(A[fn], ...)
		if not okT then
			warn("[ZR] analytics", fn, errT)
		end
	end
end

function Raid.session(player)
	return sessions[player]
end
function Raid.sessions()
	return sessions
end
-- Studio test hook: forget a raid session without settling it (simulates the server dying mid-raid).
function Raid.dropForTest(player)
	if RunService:IsStudio() then
		sessions[player] = nil
	end
end

function Raid.holder(player)
	local s = sessions[player]
	if s then
		return s.inv, true
	end
	return ctx.Profiles.get(player), false
end

function Raid.raidInfo(s)
	local ex = {}
	local exts = ctx.Extract.listFor(s)
	for _, id in s.extracts do
		local e = exts[id]
		local r = e.rule or {}
		-- a car (paid exit with seats) that rolls for being there is listed like a chance exit; one that has left is closed for good
		local gone = ctx.Extract.carLeft(e)
		table.insert(ex, {
			id = id, name = e.name, pos = e.pos, rule = r.kind, cost = r.cost, key = r.key, powered = (r.kind == "power" and ctx.World.switchOn(r.switch) and (not r.also or ctx.World.switchOn(r.also))
				and (not r.last or ctx.World.switchOn(r.last))) or nil,
			chance = (r.kind ~= "chance" and ctx.Extract.hasChance(r)) or nil, seats = r.seats, depart = r.depart,
			flared = (r.kind == "flare" and ctx.Match.flareOpen[ctx.Extract.key(e)]) or nil, area = r.kind == "flare" and (r.radius or 60) or nil,
			closed = gone or nil, closedText = gone and "THE CAR HAS LEFT" or nil,
		})
	end
	return {
		id = s.id, started = s.raidStart or s.started, endsAt = s.endsAt, spawn = s.spawn, extracts = ex, state = s.state,
		exEnds = s.exEnds, exZone = s.exZone, scav = s.scav, env = ctx.Match.env, map = s.map or ctx.Match.map,
		transits = ctx.Transit and ctx.Transit.infoFor(s) or nil, transit = s.transit and { to = s.transit.to, ends = s.transit.ends } or nil,
	}
end

-- insurance returns waiting for this profile (ready ones are delivered to the stash automatically)
local function claimsInfo(prof)
	local ready, waiting, nextAt = 0, 0, nil
	local t = os.time()
	for _, c in prof.claims or {} do
		local n = #(c.bundles or {})
		if (c.readyAt or 0) <= t then
			ready += n
		else
			waiting += n
			nextAt = math.min(nextAt or math.huge, c.readyAt)
		end
	end
	return { ready = ready, waiting = waiting, nextIn = nextAt and (nextAt - t) or nil }
end

-- the messenger's insurance dialog: each return with its items and when it is ready
local function claimList(prof)
	local out, t = {}, os.time()
	for _, c in prof.claims or {} do
		local ids = {}
		for i, b in c.bundles or {} do
			if i > 12 then
				break
			end
			table.insert(ids, b.it and b.it.id or "?")
		end
		table.insert(out, { readyIn = math.max(0, (c.readyAt or 0) - t), ids = ids, n = #(c.bundles or {}) })
	end
	return out
end

function Raid.state(player)
	local prof = ctx.Profiles.get(player)
	if not prof then
		return nil
	end
	local s = sessions[player]
	local h = s and s.inv or prof
	return {
		rev = prof.rev,
		money = prof.money,
		phase = s and "RAID" or "SAFEHOUSE",
		items = h.items,
		grids = h.grids,
		slots = h.slots,
		erev = h.erev or 0, -- equipment revision (M16): equip requests carry it back
		known = prof.known,
		active = s and s.active or nil,
		stats = prof.stats,
		settings = prof.settings,
		persistence = ctx.Store.mode,
		raid = s and Raid.raidInfo(s) or nil,
		claims = claimsInfo(prof),
		claimList = (not s) and claimList(prof) or nil,
		msgs = (not s) and prof.msgs or nil,
		insureAll = (not s) and Settle.insureQuote(prof, player.UserId) or nil,
		scavReadyAt = prof.scavReadyAt or 0,
		serverTime = os.time(),
		queued = ctx.Match.queuedKind(player),
		stashH = prof.stashH,
		econ = ctx.Economy.stateFor(prof),
		-- hideout-only blocks (traders, tasks, modules) are left out of the frequent in-raid snapshots
		quests = ctx.Quests.stateFor(prof), -- in a raid too: the inventory's TASKS tab (Tarkov)
		hideout = (not s) and ctx.Hideout.stateFor(prof) or nil,
		flea = (not s) and ctx.Flea.stateFor(prof) or nil,
	}
end

local GEAR_SLOTS = { "head", "ears", "face", "eyes", "armor", "rig", "back", "holster", "primary", "secondary", "melee" }
local DRAW_ORDER = { "primary", "secondary", "holster", "melee" }

local function weaponAt(h, slot)
	local g = slot and h.slots[slot]
	local it = g and h.items[g]
	local d = it and Items.defs[it.id]
	return (d and d.weapon) and g or nil
end

-- the night-vision device (guid) on the head item's mount, or nil
local function nvgOf(h)
	local hg = h.slots.head
	local hit = hg and h.items[hg]
	local mg = hit and hit.mods and hit.mods.mount
	local it = mg and h.items[mg]
	local d = it and Items.defs[it.id]
	return (d and d.kind == "nvg") and mg or nil
end
Raid.nvgOf = nvgOf

local function gearKey(h, active, nvDown)
	local parts = { tostring(active) }
	for _, slot in GEAR_SLOTS do
		local g = h.slots[slot]
		parts[#parts + 1] = (g and h.items[g]) and h.items[g].id or "-"
	end
	-- goggles on the head item's mount, and whether they are down over the eyes (others see both)
	local dg = nvgOf(h)
	parts[#parts + 1] = dg and h.items[dg].id or "-"
	parts[#parts + 1] = (dg and nvDown) and "nv" or "-"
	-- every carried gun's build (M14: the parts show in the hands and slung on the back)
	for _, slot in DRAW_ORDER do
		local g = h.slots[slot]
		if g and h.items[g] then
			parts[#parts + 1] = WP.signature(h.items, g)
		end
	end
	return table.concat(parts, "|")
end

function Raid.push(player)
	if typeof(player) ~= "Instance" then
		return -- test double (CharTests)
	end
	local st = Raid.state(player)
	if st then
		ctx.Remotes.push(player, st)
	end
end

-- your bunk in Relay 7: each player keeps one spot for the session (twelve bunks, two per bunk unit)
local bunkOf = {}
function Raid.bedOf(player)
	local i = bunkOf[player]
	if i and not player.Parent then
		bunkOf[player] = nil
		return nil
	end
	return i
end
function Raid.safeSpawnCF(player: Player?)
	local sh = ctx.World.safehouse
	local list = sh.spawns
	if not list or #list == 0 then
		return sh.spawn * CFrame.new(math.random(-2, 2), 0, math.random(-2, 2))
	end
	local i = player and bunkOf[player]
	if player and not i then
		local used = {}
		for p, k in bunkOf do
			if p.Parent then
				used[k] = true
			else
				bunkOf[p] = nil
			end
		end
		for k = 1, #list do
			if not used[k] then
				i = k
				break
			end
		end
		i = i or math.random(1, #list)
		bunkOf[player] = i
		if typeof(player) == "Instance" then
			player:SetAttribute("Bed", i) -- your locker card and your pigeonhole (Lobby)
		end
	end
	return list[i or math.random(1, #list)]
end

function Raid.resetWorld()
	Raid.world.seed = math.random(1, 1e9)
	Raid.world.resets += 1
	ctx.Loot.reset(Raid.world.seed)
	ctx.Doors.reset()
	ctx.Hazards.reset()
	if ctx.Stationary then
		ctx.Stationary.reset() -- the mounted guns are full again
	end
	-- the cars: no seats, no countdown, no departure; each shown or hidden by the roll Match just made (a failure here must never stop a raid)
	local okCars, errCars = pcall(ctx.Extract.reset)
	if not okCars then
		warn("[ZR] car reset", errCars)
	end
	if ctx.Transit then
		pcall(ctx.Transit.reset) -- nobody has crossed to another map yet
	end
	ctx.AI.reset()
	Raid.world.status = "RUNNING"
end

-- raid over (Match settled insurance first): AI, bodies, corpses and dropped gear go away
function Raid.clearWorld()
	if ctx.Grenades then
		ctx.Grenades.clear()
	end
	if ctx.Tripwires then
		pcall(ctx.Tripwires.clear)
	end
	ctx.AI.clear()
	ctx.Loot.clearTemp()
	ctx.Chars.clearCorpses()
	Raid.world.status = "IDLE"
end

-- ── deploy / enter / finalize ─────────────────────────────────────────────────
-- Deploy request from the hideout terminal. Validates, then joins the server's raid cycle: straight into the
-- running raid while its entry window is open (PMC: first minutes, scav: until late), otherwise the queue.
function Raid.deploy(player, p)
	local prof = ctx.Profiles.get(player)
	if not prof then
		return fail("NOT_READY")
	end
	if sessions[player] or prof.pendingRaid then
		return fail("ALREADY_IN_RAID")
	end
	if deploying[player] then
		return fail("BUSY")
	end
	if ctx.Match.isQueued(player) then
		return fail("QUEUED", "Already waiting for insertion.")
	end
	local kind = (p.kind == "scav") and "scav" or "pmc"
	if kind == "pmc" and p.rev ~= prof.rev then
		Raid.push(player)
		return fail("STALE_REVISION", "Inventory changed - review and deploy again.")
	end
	if kind == "scav" and (prof.scavReadyAt or 0) > os.time() then
		return fail("SCAV_COOLDOWN", "Scav ready in " .. Util.clock(prof.scavReadyAt - os.time()) .. ".")
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root then
		return fail("NOT_AUTHORIZED")
	end
	if not ctx.World.inSafehouse(root.Position) then
		return fail("NOT_AUTHORIZED")
	end
	-- p.map: the map this player votes for if the request queues (ignored when joining a running raid)
	if ctx.Match.request(player, kind, p.map) == "enter" then
		local spawn, idx = ctx.Match.spawnFor(player, kind)
		local okE, err = Raid.enter(player, kind, spawn, idx)
		if not okE then
			return fail(err or "FAILED")
		end
		local s = sessions[player]
		return ok({ entered = true, raidId = s and s.id })
	end
	Raid.push(player)
	return ok({ queued = true, status = ctx.Match.status(player) })
end

-- Insert a player into the running raid (Match: queue at raid start; deploy: late entry). PMCs bring their
-- loadout (escrowed in the profile first); player scavs get a generated kit and start the scav cooldown.
function Raid.enter(player, kind, spawn, idx)
	local prof = ctx.Profiles.get(player)
	if not prof or not player.Parent then
		return false, "NOT_READY"
	end
	if sessions[player] or prof.pendingRaid or deploying[player] then
		return false, "ALREADY_IN_RAID"
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		ctx.Remotes.note(player, "toast", { text = "INSERTION CANCELLED", tone = "warn" })
		return false, "NOT_AUTHORIZED"
	end
	local scav = kind == "scav"
	deploying[player] = true
	local backup = Util.copy(prof)
	local raidId = Util.guid()
	local raidInv, err
	if scav then
		raidInv, err = Settle.deployScav(prof, raidId, os.time(), ctx.Loot.scavLoadout(Random.new()))
	else
		raidInv, err = Settle.deploy(prof, raidId, os.time())
	end
	if not raidInv then
		deploying[player] = nil
		ctx.Remotes.note(player, "toast", { text = "INSERTION FAILED: " .. tostring(err), tone = "warn" })
		Raid.push(player)
		return false, err
	end
	local saved = ctx.Profiles.save(player, true)
	if not saved then
		ctx.Profiles.set(player, backup)
		deploying[player] = nil
		Raid.push(player)
		ctx.Remotes.note(player, "toast", { text = "COULD NOT RESERVE YOUR GEAR - NOTHING WAS LOST", tone = "warn" })
		return false, "STORE_UNAVAILABLE"
	end
	local t = now()
	local s = {
		id = raidId, inv = raidInv, state = "ACTIVE", started = t, raidStart = ctx.Match.startedAt, endsAt = ctx.Match.endsAt,
		match = ctx.Match.id, spawn = spawn.id, extracts = ctx.Match.extractsFor(spawn, scav), kills = 0, risked = {}, found = {},
		scav = scav, xp = 0, karma = prof.karma or 0, karmaDelta = 0, map = ctx.Match.map,
		active = (raidInv.slots.primary and "primary") or (raidInv.slots.secondary and "secondary") or (raidInv.slots.holster and "holster") or (raidInv.slots.melee and "melee") or nil,
	}
	for g in raidInv.items do
		s.risked[g] = true
	end
	sessions[player] = s
	deploying[player] = nil
	if not player.Parent then
		-- left while the reservation was saving: settle as a disconnect
		Raid.finalize(player, "DISCONNECTED")
		return false, "LEFT"
	end
	ctx.Combat.reset(player)
	-- squad members fan out around the insertion point
	local i = (idx or 1) - 1
	local cf = spawn.cf * CFrame.new((i % 3 - 1) * 4 + math.random() * 1.5, 0, math.floor(i / 3) * 4 + math.random() * 1.5)
	-- the bunker is far from the maps (streaming): load the insertion point before the character lands there
	pcall(player.RequestStreamAroundAsync, player, cf.Position, 4)
	if not scav then
		Raid.keepHideoutHealth(player)
	end
	ctx.Chars.spawn(player, cf, s.inv, s.active, { scav = scav })
	s.nvDown = nil
	s.gearKey = gearKey(s.inv, s.active, s.nvDown)
	Raid.push(player)
	ctx.Remotes.note(player, "raid", Raid.raidInfo(s))
	ctx.Match.touch(player)
	track("deploy", player, s)
	return true
end

-- bunker recovery is kept (audit quick win gameplay.1): the hideout character's health goes into the profile before
-- a PMC raid and when the player leaves, so the next raid starts from it instead of from the last raid's end
function Raid.keepHideoutHealth(player)
	local prof = ctx.Profiles.get(player)
	local char = player.Character
	local hs = char and ctx.Health and ctx.Health.get(char)
	if prof and hs and not hs.dead and not hs.inRaid then
		prof.health = ctx.Health.save(hs)
		return true
	end
	return false
end

local function itemsList(h, filter)
	local out = {}
	for g, it in h.items do
		if not filter or filter(g) then
			table.insert(out, { id = it.id, n = it.n, a = it.a })
		end
	end
	return out
end

function Raid.finalize(player, outcome)
	local s = sessions[player]
	if not s or s.done then
		return nil
	end
	s.done = true
	s.state = outcome
	sessions[player] = nil
	local prof = ctx.Profiles.get(player)
	local char0 = player.Character
	local hs0 = char0 and ctx.Health and ctx.Health.get(char0)
	local death = (outcome == "KIA" and char0) and Raid.deathInfo(char0) or nil
	-- SERVER_CLOSED (audit tech-7): a raid cut off by the server closing (an update, a crash) ends as if the raider
	-- had left at that moment with everything on them, but nothing counts as found in raid and it is not a survival.
	-- Nobody loses a kit to a shutdown. (Tarkov has no Roblox-style server shutdowns; this is ours.)
	local closed = outcome == "SERVER_CLOSED"
	local settleAs = closed and "SUCCESS" or outcome
	if prof and not s.scav then
		-- Tarkov: survivors keep their wounds (recovering in the hideout); death resets health.
		-- A player-scav raid never touches the PMC's health.
		prof.health = (settleAs == "SUCCESS" and hs0 and not hs0.dead) and ctx.Health.save(hs0) or nil
		if settleAs ~= "SUCCESS" and hs0 then
			prof.health = { energy = math.max(40, math.floor(hs0.energy)), water = math.max(40, math.floor(hs0.water)) }
		end
	end
	-- run-through (Tarkov): extracted very quickly having done almost nothing -> loot is not found-in-raid
	local runThrough = closed or (outcome == "SUCCESS" and not s.scav and (now() - s.started) < Progress.XP.runThrough.time and (s.xp or 0) < Progress.XP.runThrough.xp)
	local receipt, err = nil, nil
	local xpGained, levelUp = 0, false
	if prof then
		receipt, err = Settle.finalize(prof, s.id, settleAs, s.inv, os.time(), { runThrough = runThrough, closed = closed })
		if receipt and closed then
			receipt.outcome = outcome
			-- the player is disconnected with the server, so the bunker messenger tells them on their next visit
			ctx.Economy.mail(prof, "system", "The server closed during your raid. You kept everything you carried, but none of it counts as found in raid and the raid is not counted as survived.")
		end
		if receipt then
			xpGained, levelUp = ctx.Economy.afterRaid(player, prof, s, outcome, runThrough)
			prof.stats.kills += s.kills
			prof.stats.pmcKills += s.pmcKills or 0
			prof.stats.scavKills += s.scavKills or 0
			prof.stats.bossKills = (prof.stats.bossKills or 0) + (s.bossKills or 0)
			local good, msg = Inv.check(prof)
			if not good then
				warn("[ZR] INVARIANT after settlement", player.Name, msg)
			end
			task.spawn(ctx.Profiles.save, player, true)
		else
			warn("[ZR] settlement skipped", player.Name, err)
		end
	end
	-- a PMC's dog tag stays on the body for whoever finds it (added after settlement: it is not part of the
	-- player's own lost/found lists)
	if outcome == "KIA" and not s.scav and prof then
		local tg, tag = Inv.newItem("DOGTAG", 1, { tag = { name = player.DisplayName, lvl = ctx.Economy.level(prof), by = death and death.killer or nil } })
		if Inv.place(s.inv, tg, tag, Inv.loadOrder(s.inv)) then
			s.risked[tg] = true
		end
	end
	local summary = {
		outcome = outcome,
		raidId = s.id,
		time = now() - s.started,
		kills = s.kills,
		death = death,
		scav = s.scav,
		sold = receipt and receipt.sold or 0,
		xp = xpGained, levelUp = levelUp or nil, level = prof and ctx.Economy.level(prof) or nil, runThrough = runThrough or nil,
		retained = receipt and receipt.retained or {},
		lost = receipt and receipt.lost or {},
		kept = receipt and receipt.kept or {},
		value = receipt and receipt.value or 0,
		-- a run-through keeps the loot but nothing counts as found-in-raid
		found = (not runThrough) and itemsList(s.inv, function(g)
			return not s.risked[g]
		end) or {},
	}
	ctx.Combat.reset(player)
	local char = player.Character
	if (outcome == "KIA" or outcome == "DISCONNECTED") and char and char.Parent then
		-- the body stays in the raid with everything that was lost, for whoever finds it
		local bodyModel = char
		if outcome == "DISCONNECTED" then
			bodyModel = ctx.Chars.dropBody(char) or char
		else
			char:SetAttribute("KeepCorpse", true) -- copied into a corpse when the player respawns in the hideout
		end
		if receipt and next(s.inv.items) ~= nil then
			ctx.Loot.spawnBody(bodyModel, s.inv, "Body")
		end
	elseif outcome == "MIA" then
		-- an MIA kit is gone for everyone: insured items go straight back to their owners
		local returns = {}
		if ctx.Match.collectInsured(s.inv, returns) > 0 then
			ctx.Match.deliverInsured(returns)
		end
		if char and char.Parent then
			char:SetAttribute("InRaid", false)
		end
	end
	if player.Parent and outcome ~= "DISCONNECTED" then
		ctx.Remotes.note(player, "summary", summary)
		task.delay((outcome == "KIA") and Config.RESPAWN_DELAY or 0.6, function()
			if player.Parent and not sessions[player] then
				ctx.Chars.spawn(player, Raid.safeSpawnCF(player), nil)
				Raid.push(player)
			end
		end)
	end
	ctx.Match.touch(player)
	track("raidEnd", player, s, outcome, summary, char0)
	return receipt, summary
end

function Raid.onDied(player, char)
	if player.Character ~= char then
		return
	end
	local s = sessions[player]
	if s and not s.done then
		Raid.finalize(player, "KIA")
	elseif not s then
		task.delay(2, function()
			if player.Parent and player.Character == char and not sessions[player] then
				ctx.Chars.spawn(player, Raid.safeSpawnCF(player), nil)
				Raid.push(player)
			end
		end)
	end
end

function Raid.addKill(player, victimPlayer, victimModel, headshot)
	local s = sessions[player]
	if s then
		ctx.Economy.onKill(player, victimPlayer, victimModel, headshot)
		s.kills += 1
		if victimPlayer then
			s.pmcKills = (s.pmcKills or 0) + 1
		elseif victimModel and victimModel:GetAttribute("Kind") == "scav" then
			s.scavKills = (s.scavKills or 0) + 1
		elseif victimModel and victimModel:GetAttribute("Kind") == "boss" then
			s.bossKills = (s.bossKills or 0) + 1
		end
	end
end

-- who/what killed this character (Tarkov death screen)
function Raid.deathInfo(char)
	local hs = ctx.Health and ctx.Health.get(char)
	local lh = hs and hs.lastHit
	if not hs then
		return nil
	end
	local info = { cause = hs.cause or "UNKNOWN" }
	if lh and os.clock() - lh.at < 30 then
		local a = lh.attacker
		local name = "UNKNOWN"
		if type(a) == "string" then
			name = a -- a map hazard (the border sniper)
		elseif typeof(a) == "Instance" then
			if a:IsA("Player") then
				name = a.DisplayName
			elseif a:IsA("Model") then
				name = string.upper(a:GetAttribute("Label") or "UNKNOWN")
			end
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		info.killer = name
		info.weapon = lh.weapon
		info.ammo = lh.ammo
		info.part = ctx.Health.NAMES[lh.part]
		info.dist = (root and typeof(lh.from) == "Vector3") and math.floor((root.Position - lh.from).Magnitude * 0.32) or nil -- 0.32 m a stud, as INSPECT (audit gameplay.6)
	end
	return info
end

-- ── inventory requests ────────────────────────────────────────────────────────
-- holder refs: "me" (profile in the safehouse, raid kit in raid) | "c:<cid>" (opened container / body)
local function validDest(d)
	if type(d) ~= "table" then
		return nil
	end
	if d.slot ~= nil then
		if type(d.slot) == "string" and Items.SLOTS[d.slot] then
			return { slot = d.slot }
		end
		return nil
	end
	if type(d.c) == "string" and #d.c <= 40 and Grid.isInt(d.x) and Grid.isInt(d.y) then
		return { c = d.c, x = d.x, y = d.y, r = (d.r == 1) and 1 or 0 }
	end
	return nil
end

local function resolve(player, ref, inRaid)
	if ref == nil or ref == "me" then
		return Raid.holder(player), nil
	end
	if type(ref) == "string" and string.sub(ref, 1, 2) == "c:" and #ref <= 24 then
		if not inRaid then
			return nil, "NOT_IN_RAID"
		end
		local c, err = ctx.Loot.access(player, string.sub(ref, 3))
		if not c then
			return nil, err
		end
		return c.holder, c
	end
	return nil, "BAD_INPUT"
end

local SLOT_FOR = {
	helmet = "head", headwear = "head", headset = "ears", facecover = "face", eyewear = "eyes", armor = "armor", rig = "rig", backpack = "back", secure = "secure",
	pistol = "holster", melee = "melee",
}

local function slotFor(h, d)
	if d.kind == "weapon" then
		return (not h.slots.primary and "primary") or (not h.slots.secondary and "secondary") or "primary"
	end
	return SLOT_FOR[d.kind]
end

-- items taken from the world in raid become "found in progress" (found-in-raid if extracted)
local function markFound(s, h, g)
	if not s then
		return
	end
	local list = { g }
	Inv.descendants(h, g, list)
	for _, x in list do
		local it = h.items[x]
		if it and not s.risked[x] and not it.fir then
			it.fip = true
		end
	end
end

local examining = {}

local function examine(player, h, g, c)
	local prof = ctx.Profiles.get(player)
	local it = h.items[g]
	if not it or not prof then
		return fail("NO_ITEM")
	end
	if prof.known[it.id] or Items.knownByDefault(it.id) then
		return fail("ALREADY_KNOWN")
	end
	if examining[player] then
		return fail("BUSY")
	end
	local d = Items.defs[it.id]
	local t = (1.2 + (Items.RARITY[d.rarity] or 0) * 0.7) * (1 - Progress.bonus(prof.skills, "intellect"))
	examining[player] = true
	ctx.Remotes.note(player, "progress", { label = "EXAMINING", t = t })
	task.delay(t, function()
		examining[player] = nil
		if not player.Parent then
			return
		end
		local still = (c and c.holder.items[g]) or (not c and Raid.holder(player).items[g])
		if not still then
			ctx.Remotes.note(player, "toast", { text = "EXAMINE INTERRUPTED", tone = "warn" })
			return
		end
		prof.known[it.id] = true
		ctx.Economy.addXp(prof, Progress.XP.examine)
		ctx.Economy.skillUp(player, prof, "intellect", 2)
		ctx.Economy.skillUp(player, prof, "attention", 0.5)
		ctx.Profiles.markDirty(player)
		ctx.Remotes.note(player, "toast", { text = "EXAMINED: " .. string.upper(d.name) .. "  +" .. Progress.XP.examine .. " XP", tone = "good" })
		Raid.push(player)
		if c then
			ctx.Loot.broadcast(c)
		end
	end)
	return ok()
end

function Raid.inv(player, p)
	local me, inRaid = Raid.holder(player)
	if not me then
		return fail("NOT_READY")
	end
	if deploying[player] then
		return fail("BUSY")
	end
	local op, g = p.op, p.g
	if g ~= nil and (type(g) ~= "string" or #g > 40) then
		return fail("BAD_INPUT")
	end
	-- a queued PMC's loadout is committed: no gear changes until insertion (or leaving the queue)
	if not inRaid and ctx.Match.queuedKind(player) == "pmc" and op ~= "examine" and op ~= "insure" and op ~= "claim" then
		return fail("QUEUED", "Leave the queue to change your loadout.")
	end
	local s = sessions[player]
	if inRaid then
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not s or s.done or not hum or hum.Health <= 0 then
			return fail("NOT_AUTHORIZED")
		end
	end
	-- equipment revision (M16): a request made against an older equipment state is refused (the client refreshes)
	if p.rev ~= nil and (type(p.rev) ~= "number" or p.rev ~= (me.erev or 0)) then
		return fail("STALE_REVISION")
	end
	local opts = { inRaid = inRaid }
	local src, sc = resolve(player, p.from, inRaid)
	if not src then
		return fail(sc or "BAD_INPUT")
	end
	if g and sc and not ctx.Loot.visible(sc, player, g) then
		return fail("NOT_SEARCHED")
	end
	local touched = sc
	local done, err
	if op == "move" or op == "quick" or op == "equip" then
		local dst, dc = src, sc
		-- "stash" is not a holder ref: the quick-move branch below sends the item to the profile stash
		if p.to ~= nil and not (op == "quick" and p.to == "stash") then
			dst, dc = resolve(player, p.to, inRaid)
			if not dst then
				return fail(dc or "BAD_INPUT")
			end
		end
		touched = touched or dc
		local it = src.items[g]
		if not it then
			return fail("NO_ITEM")
		end
		local dest, order
		if op == "move" then
			dest = validDest(p.dest)
			if not dest then
				return fail("BAD_INPUT")
			end
		elseif op == "equip" then
			local slot = slotFor(dst, Items.defs[it.id])
			if not slot then
				return fail("WRONG_SLOT")
			end
			if slot == "secure" and inRaid then
				return fail("SECURE_LOCKED")
			end
			dest = { slot = slot }
		else
			if p.to == "stash" then
				if inRaid then
					return fail("NO_ACCESS")
				end
				dst, dc, order = me, nil, { "stash" }
			elseif dst == me then
				order = Inv.loadOrder(me)
			else
				order = Inv.loadOrder(dst)
			end
		end
		if src == dst then
			if dest then
				done, err = Inv.move(src, g, dest, opts)
			else
				done, err = Inv.autoPlace(src, g, order)
			end
		else
			done, err = Inv.transfer(src, g, dst, dest, order, opts)
			if done and dst == me and sc then
				markFound(s, me, g)
			end
		end
	elseif op == "split" then
		if sc then
			return fail("NOT_AUTHORIZED")
		end
		local dest = validDest(p.dest)
		if not dest or type(p.n) ~= "number" then
			return fail("BAD_INPUT")
		end
		done, err = Inv.split(src, g, p.n, dest)
	elseif op == "load" then
		if sc or type(p.ammo) ~= "string" then
			return fail("BAD_INPUT")
		end
		local n, e = Inv.loadAmmo(src, g, p.ammo)
		done, err = n > 0, e
	elseif op == "unload" then
		if sc then
			return fail("NOT_AUTHORIZED")
		end
		local n, e = Inv.unloadAmmo(src, g, inRaid and Inv.loadOrder(src) or { "stash" })
		done, err = n > 0, e
	elseif op == "mod" or op == "unmod" then
		-- weapon modding (M14): a part into a slot of a gun or of a part on it (p.slot), or into the first slot
		-- that takes it; "unmod" takes the part in slot p.slot (or the old p.mount) off item p.g
		if sc then
			return fail("NOT_AUTHORIZED")
		end
		if not g or not src.items[g] then
			return fail("NO_ITEM")
		end
		local slotName = p.slot or p.mount
		if slotName ~= nil and (type(slotName) ~= "string" or #slotName > 24) then
			return fail("BAD_INPUT")
		end
		local order = inRaid and Inv.loadOrder(src) or { "stash" }
		if op == "mod" then
			if type(p.mod) ~= "string" or #p.mod > 40 or not src.items[p.mod] then
				return fail("BAD_INPUT")
			end
			if slotName == "mag" then
				-- the modding screen's magazine slot: the same as dropping the magazine on the gun
				done, err = Inv.insertMag(src, p.mod, g)
			elseif slotName then
				done, err = Inv.attachPart(src, g, slotName, p.mod, order, opts)
			else
				done, err = Inv.attachMod(src, g, p.mod, order, opts)
			end
		else
			if not slotName then
				return fail("BAD_INPUT")
			end
			if slotName == "mag" then
				local mg = src.items[g].mag
				if not mg then
					return fail("NO_MOD")
				end
				Inv.detach(src, mg)
				done, err = Inv.autoPlace(src, mg, order)
				if not done then
					src.items[g].mag = mg
					Inv.resize(src, g)
				end
			else
				done, err = Inv.detachPart(src, g, slotName, order, opts)
			end
		end
		if err == "NEED_MULTITOOL" then
			return fail(err, "Vital parts need a multitool in a raid.")
		elseif err == "CONFLICT" then
			return fail(err, "That part does not go with the rest of the build.")
		elseif err == "UNLOAD_FIRST" then
			return fail(err, "Unload the shells first.")
		end
	elseif op == "examine" then
		return examine(player, src, g, sc)
	elseif op == "use" then
		if sc then
			return fail("NOT_AUTHORIZED")
		end
		return ctx.Health.use(player, g, p.part)
	elseif op == "drop" then
		if not inRaid or sc then
			return fail("NOT_IN_RAID")
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return fail("NOT_AUTHORIZED")
		end
		if me.slots.secure == g then
			return fail("SECURE_LOCKED")
		end
		if Inv.vitalLocked(me, g, opts) then
			return fail("NEED_MULTITOOL", "Vital parts need a multitool in a raid.")
		end
		local b = Inv.take(me, g)
		if not b then
			return fail("NO_ITEM")
		end
		ctx.Loot.spawnPile(root.Position + root.CFrame.LookVector * 2.5 - Vector3.new(0, 2.5, 0), { b })
		done = true
	elseif op == "sell" then
		-- sold to a trader (the best buyer unless one is named); see Economy.sell
		if inRaid or sc then
			return fail("NOT_AUTHORIZED")
		end
		if p.trader ~= nil and type(p.trader) ~= "string" then
			return fail("BAD_INPUT")
		end
		local res = ctx.Economy.sell(player, me, g, p.trader)
		if res ~= true then
			return res
		end
		done = true
	elseif op == "repairKit" then
		-- the gunsmith repair kit on a weapon, out of raid: its points restore condition with little wear (Tarkov)
		if inRaid or sc then
			return fail("NOT_AUTHORIZED")
		end
		if type(p.kit) ~= "string" or #p.kit > 40 then
			return fail("BAD_INPUT")
		end
		local it, kit = me.items[g or ""], me.items[p.kit]
		local kd = kit and Items.defs[kit.id]
		local d = it and Items.defs[it.id]
		if not it or not kd or not kd.repair then
			return fail("NO_ITEM")
		end
		if not (d.kind == "weapon" or d.kind == "pistol") then
			return fail("NOT_REPAIRABLE", "The kit is for weapons.")
		end
		local cur, max = TD.condition(it)
		local left = kit.pts or kd.repair.points
		local pts = math.min(max - cur, left)
		if pts < 0.5 then
			return fail("NOTHING_TO_REPAIR", "It is in full condition.")
		end
		kit.pts = left - pts
		-- out of raid the holder is the profile (luau_lint found `prof` undefined here, 2026-11-07: every repair errored)
		local prof = ctx.Profiles.get(player) or me
		local newMax = max - pts * TD.KIT_DEGRADE * (1 - Progress.bonus(prof.skills, "intellect"))
		ctx.Economy.skillUp(player, prof, "intellect", 3)
		it.wear, it.wmax = math.min(newMax, cur + pts), newMax
		it.mf, it.mfk, it.mfh = nil, nil, nil
		if kit.pts < 1 then
			Inv.take(me, p.kit)
		end
		done = true
		ctx.Remotes.note(player, "toast", { text = string.format("REPAIRED %s  +%.1f", string.upper(d.name), pts), tone = "good" })
	elseif op == "sort" then
		-- Tarkov's stash SORT (out of raid)
		if inRaid or sc then
			return fail("NOT_AUTHORIZED")
		end
		done, err = Inv.sortStash(me)
		if not done then
			return fail(err or "FAILED", err == "NO_SPACE" and "The stash can't be sorted with this much in it." or nil)
		end
	elseif op == "discard" then
		if inRaid or sc then
			return fail("NOT_AUTHORIZED")
		end
		if not me.items[g] then
			return fail("NO_ITEM")
		end
		if me.slots.secure == g then
			return fail("NOT_AUTHORIZED")
		end
		if not Inv.take(me, g) then
			return fail("NO_ITEM")
		end
		done = true
	elseif op == "insure" then
		-- Tarkov insurance: pay a share of the value; if the item is lost and nobody extracts with it, it comes back
		if inRaid or sc then
			return fail("NOT_AUTHORIZED")
		end
		local cost, e
		if p.all == true then
			cost, e = Settle.insureAll(me, player.UserId)
		else
			if not g then
				return fail("BAD_INPUT")
			end
			cost, e = Settle.insure(me, g, player.UserId)
		end
		if not cost then
			local msgs = { NOT_ENOUGH_MONEY = "Not enough money.", ALREADY_INSURED = "Already insured.", NOT_INSURABLE = "That can't be insured." }
			return fail(e or "FAILED", msgs[e or ""])
		end
		done = true
		ctx.Remotes.note(player, "toast", { text = string.format("INSURED  -%s %s", Util.commas(cost), Config.CURRENCY), tone = "good" })
	elseif op == "claim" then
		if inRaid then
			return fail("NOT_AUTHORIZED")
		end
		local n, waiting = Settle.claim(me, os.time())
		if n == 0 then
			return fail("NOTHING_READY", waiting > 0 and "Insurance returns are not ready yet." or "Nothing to collect.")
		end
		done = true
		ctx.Remotes.note(player, "toast", { text = string.format("INSURANCE RETURN: %d ITEM(S) IN YOUR STASH", n), tone = "good" })
	elseif op == "recovery" then
		if inRaid then
			return fail("NOT_AUTHORIZED")
		end
		done, err = Settle.recoveryKit(me)
	else
		return fail("BAD_INPUT")
	end
	if not done then
		return fail(err or "FAILED")
	end
	if touched then
		ctx.Loot.changed(touched)
	end
	Raid.afterChange(player, inRaid)
	return ok({ erev = me.erev or 0 })
end

-- Keep the hands slot valid after inventory changes (moving the weapon in hands away draws the next one,
-- with its draw time) and refresh third-person gear/weapon visuals when the visible kit changed.
function Raid.syncGear(player)
	local s = sessions[player]
	if not s or s.done then
		return
	end
	local h = s.inv
	-- goggles taken off the mount: the down pose goes with them
	if s.nvDown and not nvgOf(h) then
		s.nvDown = nil
		local c = player.Character
		if c then
			c:SetAttribute("NvDown", nil)
		end
	end
	if not weaponAt(h, s.active) then
		s.active = nil
		for _, slot in DRAW_ORDER do
			if weaponAt(h, slot) then
				s.active = slot
				ctx.Combat.drawDelay(player, slot)
				break
			end
		end
	end
	local key = gearKey(h, s.active, s.nvDown)
	if key ~= s.gearKey then
		s.gearKey = key
		local char = player.Character
		if char and char.Parent then
			ctx.Chars.redress(char, h, s.active)
		end
	end
end

function Raid.afterChange(player, inRaid)
	local h = Raid.holder(player)
	if h then
		local good, msg = Inv.check(h)
		if not good then
			warn("[ZR] INVARIANT", player.Name, msg)
		end
	end
	if inRaid then
		Raid.syncGear(player)
	end
	if not inRaid then
		-- safehouse: the character wears the profile kit (preview of the next raid), diffed per slot
		local char = player.Character
		if h and char and char.Parent and not char:GetAttribute("InRaid") then
			ctx.Appearance.apply(char, { holder = h, weapons = false })
		end
		local prof = ctx.Profiles.get(player)
		if prof then
			prof.rev += 1
			ctx.Profiles.markDirty(player)
		end
	end
	Raid.push(player)
end

local function saveSettings(player, p)
	local prof = ctx.Profiles.get(player)
	if not prof then
		return fail("NOT_READY")
	end
	local s = prof.settings
	local function num(k, lo, hi)
		if p[k] ~= nil then
			if type(p[k]) ~= "number" or not Util.finite(p[k]) then
				return false
			end
			s[k] = math.clamp(p[k], lo, hi)
		end
		return true
	end
	local function bool(k)
		if p[k] ~= nil then
			if type(p[k]) ~= "boolean" then
				return false
			end
			s[k] = p[k]
		end
		return true
	end
	if not (num("headBob", 0.2, 1) and num("quickBar", 1, 3) and num("aimSens", 0.2, 3) and num("pfxBright", -0.5, 0.5) and num("pfxSat", -1, 1)
		and num("pfxClarity", -0.5, 0.5) and num("pfxGrade", 0, 4) and num("pfxGradeK", 0, 1) and num("volMaster", 0, 1) and num("volFx", 0, 1)
		and num("volUi", 0, 1) and num("volAmb", 0, 1) and num("padSens", 0.2, 3) and num("touchSens", 0.2, 3)
		and num("msgSeen", 0, 4e9) and bool("invertY") and bool("malfNotes") and bool("dblUse")) then
		return fail("BAD_INPUT")
	end
	if not (num("fov", 50, 100) and num("sens", 0.2, 3) and num("quality", 0, 3) and num("shake", 0, 1) and num("grain", 0, 1) and num("hudScale", 0.7, 1.4)
		and bool("reduceMotion") and bool("film") and bool("reticle") and bool("adsToggle") and bool("lens") and bool("mblur") and bool("curve") and bool("hitfx")
		and bool("aimOnFire") and bool("joyFloat") and bool("autoGfx")) then
		return fail("BAD_INPUT")
	end
	if s.quality then
		s.quality = math.floor(s.quality + 0.5) -- graphics preset: 0 POTATO, 1 LOW, 2 MEDIUM, 3 HIGH
	end
	-- per kind of device (Settings.luau): { dev = { phone|console|pc = { quality, fov, sens, grain } } }
	if p.dev ~= nil then
		if type(p.dev) ~= "table" then
			return fail("BAD_INPUT")
		end
		local LIM = { quality = { 0, 3 }, fov = { 50, 100 }, sens = { 0.2, 3 }, grain = { 0, 1 } }
		s.dev = type(s.dev) == "table" and s.dev or {}
		for cls, vals in p.dev do
			if (cls ~= "phone" and cls ~= "console" and cls ~= "pc") or type(vals) ~= "table" then
				return fail("BAD_INPUT")
			end
			local d = type(s.dev[cls]) == "table" and s.dev[cls] or {}
			for k, v in vals do
				local lim = LIM[k]
				if not lim or type(v) ~= "number" or not Util.finite(v) then
					return fail("BAD_INPUT")
				end
				d[k] = math.clamp(k == "quality" and math.floor(v + 0.5) or v, lim[1], lim[2])
			end
			s.dev[cls] = d
		end
	end
	-- key rebinding, one action per request: { bind = { action, key (KeyCode name, nil = default), mod } }
	if p.bindsReset == true then
		s.binds = {}
	end
	if p.bind ~= nil then
		local b = p.bind
		if type(b) ~= "table" or type(b.action) ~= "string" or not InputMap[b.action] then
			return fail("BAD_INPUT")
		end
		s.binds = s.binds or {}
		if b.key == nil then
			s.binds[b.action] = nil
		else
			local okKey = type(b.key) == "string" and #b.key <= 24 and pcall(function()
				return Enum.KeyCode[b.key]
			end)
			if not okKey or (b.mod ~= nil and b.mod ~= "Alt" and b.mod ~= "Shift" and b.mod ~= "Ctrl") then
				return fail("BAD_INPUT")
			end
			s.binds[b.action] = { key = b.key, mod = b.mod }
		end
	end
	-- the touch layout (Settings, CONTROLS, EDIT TOUCH LAYOUT): only known controls, numbers in range (TouchLayout.sanitize);
	-- an empty one is the defaults
	if p.touchLayout ~= nil then
		if type(p.touchLayout) ~= "table" then
			return fail("BAD_INPUT")
		end
		s.touchLayout = TouchLayout.sanitize(p.touchLayout)
	end
	-- Tarkov's wish list: { wish = { id = item id, on = bool } }
	if p.wish ~= nil then
		local wq = p.wish
		if type(wq) ~= "table" or type(wq.id) ~= "string" or not Items.defs[wq.id] or type(wq.on) ~= "boolean" then
			return fail("BAD_INPUT")
		end
		s.wish = s.wish or {}
		s.wish[wq.id] = wq.on or nil
	end
	-- Tarkov quick slots 4 to 0: { quick = { slot = "4", g = item guid or "" to clear } }; one key per item
	if p.quick ~= nil then
		local q = p.quick
		if type(q) ~= "table" or type(q.slot) ~= "string" or not string.match(q.slot, "^[4-90]$") or (q.g ~= nil and (type(q.g) ~= "string" or #q.g > 40)) then
			return fail("BAD_INPUT")
		end
		s.quick = s.quick or {}
		if q.g == nil or q.g == "" then
			s.quick[q.slot] = nil
		else
			for k, v in s.quick do
				if v == q.g then
					s.quick[k] = nil
				end
			end
			s.quick[q.slot] = q.g
		end
	end
	ctx.Profiles.markDirty(player)
	return ok()
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────
local function onPlayerAdded(player)
	local prof, recovered = ctx.Profiles.load(player)
	if not prof then
		if player.Parent then
			if ctx.Store.mode == "OFFLINE" then
				player:Kick("Zero Return: Roblox's save service isn't answering this server, so it can't keep your progress. Nothing was lost. Please rejoin in a few minutes.")
			else
				player:Kick("Zero Return: profile unavailable (" .. tostring(recovered) .. "). Please rejoin in a minute.")
			end
		end
		return
	end
	local isNew = not prof.msgs
	if not prof.msgs then
		ctx.Economy.mail(prof, "system", "Welcome to Relay 7. Trade at the counters, plan at the ops table, board the van. Insurance returns and task rewards are reported here.")
	end
	track("join", player, isNew)
	ctx.Chars.spawn(player, Raid.safeSpawnCF(player), nil)
	Raid.push(player)
	ctx.Remotes.note(player, "match", ctx.Match.status(player))
	if type(recovered) == "table" then
		ctx.Remotes.note(player, "summary", {
			outcome = "DISCONNECTED", raidId = recovered.raidId, time = 0, kills = 0,
			retained = {}, lost = recovered.lost, value = recovered.value, found = {},
		})
	end
end

function Raid.init(c)
	ctx = c
	do
		local okA, A = pcall(require, script.Parent.Analytics)
		local okI, errI = false, A
		if okA then
			okI, errI = pcall(A.init, c)
		end
		if okI then
			ctx.Analytics = A
		else
			warn("[ZR] Analytics failed to load, no analytics this server:", errI)
			ctx.Remotes.onAct("perf", function() end, 0.2, 2) -- clients still report their frame rate: take it quietly
		end
	end
	ctx.Remotes.onReq("deploy", Raid.deploy, 1, 2)
	ctx.Remotes.onReq("inv", Raid.inv, 12, 16)
	ctx.Remotes.onReq("settings", saveSettings, 2, 4, 32) -- a touch layout holds up to 24 controls (TouchLayout.ELEMENTS)
	ctx.Remotes.onReq("sync", function(player)
		Raid.push(player)
		return ok()
	end, 2, 4)
end

function Raid.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		if sessions[player] then
			Raid.finalize(player, "DISCONNECTED")
		else
			Raid.keepHideoutHealth(player)
		end
		ctx.Profiles.release(player)
	end)
	game:BindToClose(function()
		-- a closing server refunds every raid in progress (SERVER_CLOSED above) instead of taking the kits
		for player, s in sessions do
			Raid.finalize(player, (s.done or s.dead) and "DISCONNECTED" or "SERVER_CLOSED")
		end
		pcall(ctx.Match.settleInsurance)
		local pending = 0
		for player in ctx.Profiles.all() do
			pending += 1
			task.spawn(function()
				ctx.Profiles.release(player)
				pending -= 1
			end)
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do
			task.wait(0.2)
		end
	end)
	-- insurance returns land in the stash once they are ready (hideout only)
	task.spawn(function()
		while true do
			task.wait(10)
			local t = os.time()
			for player in ctx.Profiles.all() do
				local prof = ctx.Profiles.get(player)
				if prof and player.Parent and not sessions[player] and not deploying[player] and prof.claims and #prof.claims > 0 then
					local ready = false
					for _, c in prof.claims do
						if (c.readyAt or 0) <= t then
							ready = true
							break
						end
					end
					if ready then
						local n, waiting = Settle.claim(prof, t)
						if n > 0 then
							ctx.Remotes.note(player, "toast", { text = string.format("INSURANCE RETURN: %d ITEM(S) IN YOUR STASH", n), tone = "good" })
							Raid.afterChange(player, false)
						elseif waiting > 0 then
							ctx.Remotes.note(player, "toast", { text = "INSURANCE RETURN WAITING - FREE UP STASH SPACE", tone = "warn" })
						end
					end
				end
			end
		end
	end)
end

return Raid
