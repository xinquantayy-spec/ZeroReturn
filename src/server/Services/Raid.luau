--!nonstrict
-- Raid orchestration: player lifecycle, deploy reservation, raid sessions/timers, settlement, inventory requests.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("EFB")
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
		pockets = h.pockets,
		bag = h.bag,
		slots = h.slots,
		stash = (not s) and prof.stash or nil,
		stats = prof.stats,
		settings = prof.settings,
		persistence = ctx.Store.mode,
		raid = s and Raid.raidInfo(s) or nil,
	}
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
	}
	for g in raidInv.items do
		s.risked[g] = true
	end
	sessions[player] = s
	deploying[player] = nil
	ctx.Combat.reset(player)
	task.spawn(function()
		local cf = spawn.cf * CFrame.new(math.random(-4, 4), 0, math.random(-4, 4))
		ctx.Chars.spawn(player, cf, s.inv)
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
	local receipt, err = nil, nil
	if prof then
		receipt, err = Settle.finalize(prof, s.id, outcome, s.inv, os.time())
		if receipt then
			prof.stats.kills += s.kills
			local good, msg = Inv.check(prof)
			if not good then
				warn("[EFB] INVARIANT after settlement", player.Name, msg)
			end
			task.spawn(ctx.Profiles.save, player, true)
		else
			warn("[EFB] settlement skipped", player.Name, err)
		end
	end
	local summary = {
		outcome = outcome,
		raidId = s.id,
		time = now() - s.started,
		kills = s.kills,
		retained = receipt and receipt.retained or {},
		lost = receipt and receipt.lost or {},
		value = receipt and receipt.value or 0,
		found = itemsList(s.inv, function(g)
			return not s.risked[g]
		end),
	}
	ctx.Combat.reset(player)
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

function Raid.addKill(player)
	local s = sessions[player]
	if s then
		s.kills += 1
	end
end

-- ── inventory requests ────────────────────────────────────────────────────────
local function validDest(d)
	if type(d) ~= "table" then
		return nil
	end
	if d.slot ~= nil then
		if d.slot == "primary" or d.slot == "bag" then
			return { slot = d.slot }
		end
		return nil
	end
	if (d.c == "stash" or d.c == "pockets" or d.c == "bag") and Grid.isInt(d.x) and Grid.isInt(d.y) then
		return { c = d.c, x = d.x, y = d.y, r = (d.r == 1) and 1 or 0 }
	end
	return nil
end

function Raid.inv(player, p)
	local h, inRaid = Raid.holder(player)
	if not h then
		return fail("NOT_READY")
	end
	if deploying[player] then
		return fail("BUSY")
	end
	local op, g = p.op, p.g
	if g ~= nil and (type(g) ~= "string" or #g > 40) then
		return fail("BAD_INPUT")
	end
	if inRaid then
		local s = sessions[player]
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not s or s.done or not hum or hum.Health <= 0 then
			return fail("NOT_AUTHORIZED")
		end
	end
	local done, err
	if op == "move" then
		local dest = validDest(p.dest)
		if not dest then
			return fail("BAD_INPUT")
		end
		if inRaid and dest.c == "stash" then
			return fail("NO_ACCESS")
		end
		done, err = Inv.move(h, g, dest)
	elseif op == "quick" then
		local to = p.to
		if to == "equip" then
			local it = h.items[g]
			local d = it and Items.defs[it.id]
			if not d then
				return fail("NO_ITEM")
			end
			local slot = (d.kind == "weapon" and "primary") or (d.kind == "bag" and "bag") or nil
			if not slot then
				return fail("WRONG_SLOT")
			end
			done, err = Inv.move(h, g, { slot = slot })
		elseif to == "pockets" or to == "bag" or (to == "stash" and not inRaid) then
			done, err = Inv.autoMove(h, g, { to })
		elseif to == "loadout" and not inRaid then
			done, err = Inv.autoMove(h, g, { "pockets", "bag" })
		else
			return fail("BAD_INPUT")
		end
	elseif op == "take" then
		if not inRaid then
			return fail("NOT_IN_RAID")
		end
		return ctx.Loot.take(player, p.cid, g)
	elseif op == "put" then
		if not inRaid then
			return fail("NOT_IN_RAID")
		end
		return ctx.Loot.put(player, p.cid, g)
	elseif op == "drop" then
		if not inRaid then
			return fail("NOT_IN_RAID")
		end
		return ctx.Loot.drop(player, g)
	elseif op == "use" then
		if not inRaid then
			return fail("NOT_IN_RAID")
		end
		return ctx.Combat.startHeal(player, g)
	elseif op == "sell" then
		if inRaid then
			return fail("NOT_AUTHORIZED")
		end
		local it = h.items[g]
		if not it then
			return fail("NO_ITEM")
		end
		local bundle = Inv.take(h, g)
		if not bundle then
			return fail("BAG_NOT_EMPTY")
		end
		local value = Items.valueOf(bundle.it) + (bundle.sub and Items.valueOf(bundle.sub.it) or 0)
		h.money += math.floor(value * Config.SELL_RATE)
		done = true
	elseif op == "fill" then
		if inRaid then
			return fail("NOT_AUTHORIZED")
		end
		done = Inv.fillMags(h) > 0
		err = "NOTHING_TO_LOAD"
	elseif op == "recovery" then
		if inRaid then
			return fail("NOT_AUTHORIZED")
		end
		done, err = Settle.recoveryKit(h)
	else
		return fail("BAD_INPUT")
	end
	if not done then
		return fail(err or "FAILED")
	end
	Raid.afterChange(player, inRaid)
	return ok()
end

function Raid.afterChange(player, inRaid)
	local h = Raid.holder(player)
	if h then
		local good, msg = Inv.check(h)
		if not good then
			warn("[EFB] INVARIANT", player.Name, msg)
		end
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
	if not (num("fov", 65, 90) and num("sens", 0.2, 3) and num("quality", 1, 3) and num("shake", 0, 1) and bool("reduceMotion") and bool("film") and bool("reticle") and bool("adsToggle")) then
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
			player:Kick("Escape From Bloxov: profile unavailable (" .. tostring(recovered) .. "). Please rejoin in a minute.")
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
