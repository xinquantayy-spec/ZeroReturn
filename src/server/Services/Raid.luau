--!nonstrict
-- Raid orchestration: player lifecycle, deploy reservation, raid sessions/timers, settlement, inventory requests.
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
local spawnTurn = 0
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
		table.insert(ex, { id = id, name = e.name, pos = e.pos })
	end
	return { id = s.id, started = s.started, endsAt = s.endsAt, spawn = s.spawn, extracts = ex, state = s.state, exEnds = s.exEnds, exZone = s.exZone }
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

function Raid.pickSpawn()
	spawnTurn += 1
	local list = ctx.World.spawns
	return list[(spawnTurn % #list) + 1]
end

function Raid.resetWorld()
	Raid.world.seed = math.random(1, 1e9)
	Raid.world.resets += 1
	ctx.Loot.reset(Raid.world.seed)
	ctx.AI.reset()
	Raid.world.status = "RUNNING"
end

local function checkIdle()
	if next(sessions) == nil and Raid.world.status == "RUNNING" then
		Raid.world.status = "IDLE"
		ctx.AI.clear()
	end
end

-- ── deploy / finalize ─────────────────────────────────────────────────────────
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
	if p.rev ~= prof.rev then
		Raid.push(player)
		return fail("STALE_REVISION", "Inventory changed - review and deploy again.")
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
	deploying[player] = true
	local backup = Util.copy(prof)
	local raidId = Util.guid()
	local raidInv, err = Settle.deploy(prof, raidId, os.time())
	if not raidInv then
		deploying[player] = nil
		return fail(err)
	end
	local saved = ctx.Profiles.save(player, true)
	if not saved then
		ctx.Profiles.set(player, backup)
		deploying[player] = nil
		Raid.push(player)
		return fail("STORE_UNAVAILABLE", "Could not reserve your gear. Nothing was lost - try again.")
	end
	if Raid.world.status ~= "RUNNING" then
		Raid.resetWorld()
	end
	local spawn = Raid.pickSpawn()
	local t = now()
	local s = {
		id = raidId, inv = raidInv, state = "ACTIVE", started = t, endsAt = t + Config.RAID_DURATION,
		spawn = spawn.id, extracts = spawn.extracts, kills = 0, risked = {}, found = {},
		active = (raidInv.slots.primary and "primary") or (raidInv.slots.secondary and "secondary") or (raidInv.slots.holster and "holster") or (raidInv.slots.melee and "melee") or nil,
	}
	for g in raidInv.items do
		s.risked[g] = true
	end
	sessions[player] = s
	deploying[player] = nil
	ctx.Combat.reset(player)
	task.spawn(function()
		local cf = spawn.cf * CFrame.new(math.random(-4, 4), 0, math.random(-4, 4))
		ctx.Chars.spawn(player, cf, s.inv, s.active)
		s.gearKey = gearKey(s.inv, s.active)
		Raid.push(player)
		ctx.Remotes.note(player, "raid", Raid.raidInfo(s))
	end)
	return ok({ raidId = raidId })
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
	if prof then
		-- Tarkov: survivors keep their wounds (recovering in the hideout); death resets health
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
		retained = receipt and receipt.retained or {},
		lost = receipt and receipt.lost or {},
		kept = receipt and receipt.kept or {},
		value = receipt and receipt.value or 0,
		found = itemsList(s.inv, function(g)
			return not s.risked[g]
		end),
	}
	ctx.Combat.reset(player)
	-- what was lost stays in the world as a lootable body (KIA) for whoever finds it
	if outcome == "KIA" and receipt and next(s.inv.items) ~= nil then
		local char = player.Character
		if char then
			ctx.Loot.spawnBody(char, s.inv, player.DisplayName)
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
	checkIdle()
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

function Raid.addKill(player, victimPlayer)
	local s = sessions[player]
	if s then
		s.kills += 1
		if victimPlayer then
			s.pmcKills = (s.pmcKills or 0) + 1
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
				name = "HARBOR WATCH"
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
	-- raid clock (1 Hz): timer expiry => MIA
	task.spawn(function()
		while true do
			task.wait(1)
			local t = now()
			for player, s in sessions do
				if not s.done and t >= s.endsAt then
					local char = player.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					Raid.finalize(player, "MIA")
					if hum and hum.Health > 0 then
						char:SetAttribute("InRaid", false)
					end
				end
			end
		end
	end)
end

return Raid
