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
local Grid = require(Shared.Grid)
local Inv = require(script.Parent.Inv)
local Settle = require(script.Parent.Settle)

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
	for _, id in s.extracts do
		local e = ctx.World.extracts[id]
		local r = e.rule or {}
		table.insert(ex, { id = id, name = e.name, pos = e.pos, rule = r.kind, cost = r.cost, key = r.key })
	end
	return {
		id = s.id, started = s.raidStart or s.started, endsAt = s.endsAt, spawn = s.spawn, extracts = ex, state = s.state,
		exEnds = s.exEnds, exZone = s.exZone, scav = s.scav,
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
		known = prof.known,
		active = s and s.active or nil,
		stats = prof.stats,
		settings = prof.settings,
		persistence = ctx.Store.mode,
		raid = s and Raid.raidInfo(s) or nil,
		claims = claimsInfo(prof),
		insureAll = (not s) and Settle.insureQuote(prof, player.UserId) or nil,
		scavReadyAt = prof.scavReadyAt or 0,
		serverTime = os.time(),
		queued = ctx.Match.queuedKind(player),
	}
end

local GEAR_SLOTS = { "head", "armor", "rig", "back", "holster", "primary", "secondary", "melee" }
local MOUNTS = { "rail", "muzzle", "under", "side" }
local DRAW_ORDER = { "primary", "secondary", "holster", "melee" }

local function weaponAt(h, slot)
	local g = slot and h.slots[slot]
	local it = g and h.items[g]
	local d = it and Items.defs[it.id]
	return (d and d.weapon) and g or nil
end

local function gearKey(h, active)
	local parts = { tostring(active) }
	for _, slot in GEAR_SLOTS do
		local g = h.slots[slot]
		parts[#parts + 1] = (g and h.items[g]) and h.items[g].id or "-"
	end
	local ag = active and h.slots[active]
	local a = ag and h.items[ag]
	if a then
		parts[#parts + 1] = a.mag and "M" or "-"
		for _, mount in MOUNTS do
			local mg = a.mods and a.mods[mount]
			parts[#parts + 1] = (mg and h.items[mg]) and h.items[mg].id or "-"
		end
	end
	return table.concat(parts, "|")
end

function Raid.push(player)
	local st = Raid.state(player)
	if st then
		ctx.Remotes.push(player, st)
	end
end

function Raid.safeSpawnCF()
	return ctx.World.safehouse.spawn * CFrame.new(math.random(-2, 2), 0, math.random(-2, 2))
end

function Raid.resetWorld()
	Raid.world.seed = math.random(1, 1e9)
	Raid.world.resets += 1
	ctx.Loot.reset(Raid.world.seed)
	ctx.AI.reset()
	Raid.world.status = "RUNNING"
end

-- raid over (Match settled insurance first): AI, bodies, corpses and dropped gear go away
function Raid.clearWorld()
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
	if (root.Position - Config.SAFEHOUSE_ORIGIN).Magnitude > 80 then
		return fail("NOT_AUTHORIZED")
	end
	if ctx.Match.request(player, kind) == "enter" then
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
		scav = scav,
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
	ctx.Chars.spawn(player, cf, s.inv, s.active, { scav = scav })
	s.gearKey = gearKey(s.inv, s.active)
	Raid.push(player)
	ctx.Remotes.note(player, "raid", Raid.raidInfo(s))
	ctx.Match.touch(player)
	return true
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
	if prof and not s.scav then
		-- Tarkov: survivors keep their wounds (recovering in the hideout); death resets health.
		-- A player-scav raid never touches the PMC's health.
		prof.health = (outcome == "SUCCESS" and hs0 and not hs0.dead) and ctx.Health.save(hs0) or nil
		if outcome ~= "SUCCESS" and hs0 then
			prof.health = { energy = math.max(40, math.floor(hs0.energy)), water = math.max(40, math.floor(hs0.water)) }
		end
	end
	local receipt, err = nil, nil
	if prof then
		receipt, err = Settle.finalize(prof, s.id, outcome, s.inv, os.time())
		if receipt then
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
	local summary = {
		outcome = outcome,
		raidId = s.id,
		time = now() - s.started,
		kills = s.kills,
		death = death,
		scav = s.scav,
		sold = receipt and receipt.sold or 0,
		retained = receipt and receipt.retained or {},
		lost = receipt and receipt.lost or {},
		kept = receipt and receipt.kept or {},
		value = receipt and receipt.value or 0,
		found = itemsList(s.inv, function(g)
			return not s.risked[g]
		end),
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
				ctx.Chars.spawn(player, Raid.safeSpawnCF(), nil)
				Raid.push(player)
			end
		end)
	end
	ctx.Match.touch(player)
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
				ctx.Chars.spawn(player, Raid.safeSpawnCF(), nil)
				Raid.push(player)
			end
		end)
	end
end

function Raid.addKill(player, victimPlayer, victimModel)
	local s = sessions[player]
	if s then
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
		if typeof(a) == "Instance" then
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
		info.dist = (root and typeof(lh.from) == "Vector3") and math.floor((root.Position - lh.from).Magnitude * 0.28) or nil
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

local SLOT_FOR = { helmet = "head", armor = "armor", rig = "rig", backpack = "back", secure = "secure", pistol = "holster", melee = "melee" }

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
	local t = 1.2 + (Items.RARITY[d.rarity] or 0) * 0.7
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
		ctx.Profiles.markDirty(player)
		ctx.Remotes.note(player, "toast", { text = "EXAMINED: " .. string.upper(d.name), tone = "good" })
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
		if p.to ~= nil then
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
		if sc then
			return fail("NOT_AUTHORIZED")
		end
		local order = inRaid and Inv.loadOrder(src) or { "stash" }
		if op == "mod" then
			if type(p.mod) ~= "string" then
				return fail("BAD_INPUT")
			end
			done, err = Inv.attachMod(src, g, p.mod, order)
		else
			if type(p.mount) ~= "string" then
				return fail("BAD_INPUT")
			end
			done, err = Inv.detachMod(src, g, p.mount, order)
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
		local b = Inv.take(me, g)
		if not b then
			return fail("NO_ITEM")
		end
		ctx.Loot.spawnPile(root.Position + root.CFrame.LookVector * 2.5 - Vector3.new(0, 2.5, 0), { b })
		done = true
	elseif op == "sell" or op == "discard" then
		if inRaid or sc then
			return fail("NOT_AUTHORIZED")
		end
		local it = me.items[g]
		if not it then
			return fail("NO_ITEM")
		end
		if op == "sell" and not (me.known[it.id] or Items.knownByDefault(it.id)) then
			return fail("UNKNOWN_ITEM", "Examine it first.")
		end
		if me.slots.secure == g then
			return fail("NOT_AUTHORIZED")
		end
		local b = Inv.take(me, g)
		if not b then
			return fail("NO_ITEM")
		end
		if op == "sell" then
			local value = Items.valueOf(b.it)
			for _, sub in b.subs do
				value += Items.valueOf(sub.it)
			end
			me.money += math.floor(value * Config.SELL_RATE)
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
	return ok()
end

-- Keep the hands slot valid after inventory changes (moving the weapon in hands away draws the next one,
-- with its draw time) and refresh third-person gear/weapon visuals when the visible kit changed.
function Raid.syncGear(player)
	local s = sessions[player]
	if not s or s.done then
		return
	end
	local h = s.inv
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
	local key = gearKey(h, s.active)
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
	if not (num("fov", 65, 100) and num("sens", 0.2, 3) and num("quality", 1, 3) and num("shake", 0, 1) and num("grain", 0, 1) and num("hudScale", 0.7, 1.4)
		and bool("reduceMotion") and bool("film") and bool("reticle") and bool("adsToggle") and bool("lens") and bool("mblur") and bool("warp") and bool("hitfx")) then
		return fail("BAD_INPUT")
	end
	ctx.Profiles.markDirty(player)
	return ok()
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────
local function onPlayerAdded(player)
	local prof, recovered = ctx.Profiles.load(player)
	if not prof then
		if player.Parent then
			player:Kick("Zero Return: profile unavailable (" .. tostring(recovered) .. "). Please rejoin in a minute.")
		end
		return
	end
	ctx.Chars.spawn(player, Raid.safeSpawnCF(), nil)
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
	ctx.Remotes.onReq("deploy", Raid.deploy, 1, 2)
	ctx.Remotes.onReq("inv", Raid.inv, 12, 16)
	ctx.Remotes.onReq("settings", saveSettings, 2, 4)
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
		end
		ctx.Profiles.release(player)
	end)
	game:BindToClose(function()
		for player in sessions do
			Raid.finalize(player, "DISCONNECTED")
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
