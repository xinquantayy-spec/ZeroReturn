--!nonstrict
-- Trader tasks (M9): accept in the hideout, progress during raids (kills count even if you die, extractions,
-- visiting places), hand in found-in-raid items and collect rewards at the trader.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local QD = require(Shared.QuestData)
local TD = require(Shared.TraderData)
local P = require(Shared.Progress)
local Inv = require(script.Parent.Inv)

local Quests = {}
local ctx

local function fail(code, msg)
	return ctx.Remotes.fail(code, msg)
end

function Quests.status(prof, q)
	local st = prof.quests[q.id]
	if st then
		return st.s
	end
	if q.after and not (prof.quests[q.after] and prof.quests[q.after].s == "claimed") then
		return "locked"
	end
	if ctx.Economy.level(prof) < (q.level or 1) then
		return "locked"
	end
	return "available"
end

-- is g in the stash grid or inside a container that is in the stash?
local function inStash(prof, g)
	local cur = g
	for _ = 1, 12 do
		if prof.grids.stash and prof.grids.stash[cur] then
			return true
		end
		local parent = nil
		for cid, pl in prof.grids do
			if pl[cur] then
				parent = cid
				break
			end
		end
		if not parent or parent == "stash" or parent == "pockets" then
			return parent == "stash"
		end
		cur = parent
	end
	return false
end

-- found-in-raid items of this id anywhere in the stash, not inside containers you are wearing
local function firCount(prof, id)
	local n = 0
	for g, it in prof.items do
		if it.id == id and it.fir and inStash(prof, g) then
			n += it.n or 1
		end
	end
	return n
end

-- objective progress (handins are counted from the stash; others are stored)
function Quests.progress(prof, q, i)
	local o = q.obj[i]
	if o.kind == "handin" then
		return math.min(o.n, firCount(prof, o.item))
	end
	local st = prof.quests[q.id]
	return math.min(o.n, (st and st.p and st.p[tostring(i)]) or 0)
end

function Quests.complete(prof, q)
	for i, o in q.obj do
		if Quests.progress(prof, q, i) < o.n then
			return false
		end
	end
	return true
end

local function bump(player, prof, q, i, by)
	local st = prof.quests[q.id]
	local o = q.obj[i]
	local k = tostring(i)
	local cur = st.p[k] or 0
	if cur >= o.n then
		return
	end
	st.p[k] = math.min(o.n, cur + (by or 1))
	ctx.Profiles.markDirty(player)
	ctx.Remotes.note(player, "toast", { text = string.format("TASK  %s  ·  %s %d/%d", string.upper(q.name), string.upper(QD.describe(o)), st.p[k], o.n), tone = "good" })
end

local function active(prof)
	local list = {}
	for _, q in QD.list do
		local st = prof.quests[q.id]
		if st and st.s == "active" then
			st.p = st.p or {}
			table.insert(list, q)
		end
	end
	return list
end

local KILL_MATCH = {
	scav = { scav = true, pscav = true }, watch = { watch = true }, pmc = { pmc = true }, boss = { boss = true },
	any = { scav = true, pscav = true, watch = true, pmc = true, boss = true, follower = true },
}

function Quests.onKill(player, kind)
	local prof = ctx.Profiles.get(player)
	if not prof then
		return
	end
	for _, q in active(prof) do
		for i, o in q.obj do
			if o.kind == "kill" and KILL_MATCH[o.target] and KILL_MATCH[o.target][kind] then
				bump(player, prof, q, i)
			end
		end
	end
end

function Quests.onExtract(player, prof, s)
	for _, q in active(prof) do
		for i, o in q.obj do
			if o.kind == "extract" and (o.scav == nil or o.scav == (s.scav == true)) and (not o.exfil or o.exfil == s.exZone) then
				bump(player, prof, q, i)
			end
		end
	end
end

local function visitTick()
	local zones = ctx.World.visitZones or {}
	for player, s in ctx.Raid.sessions() do
		local prof = not s.done and ctx.Profiles.get(player)
		local root = prof and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			for _, q in active(prof) do
				for i, o in q.obj do
					local z = o.kind == "visit" and zones[o.zone]
					if z and (prof.quests[q.id].p[tostring(i)] or 0) < 1 and (root.Position - z.pos).Magnitude <= z.r then
						bump(player, prof, q, i)
					end
				end
			end
		end
	end
end

-- consume found-in-raid items for a hand-in (smallest stacks first)
local function takeFir(prof, id, n)
	local list = {}
	for g, it in prof.items do
		if it.id == id and it.fir and inStash(prof, g) then
			table.insert(list, { g = g, it = it })
		end
	end
	table.sort(list, function(a, b)
		return (a.it.n or 1) < (b.it.n or 1)
	end)
	local left = n
	for _, e in list do
		if left <= 0 then
			break
		end
		local k = math.min(left, e.it.n or 1)
		Inv.consume(prof, e.g, k)
		left -= k
	end
	return left <= 0
end

local function questReq(player, p)
	local prof = ctx.Profiles.get(player)
	if not prof then
		return fail("NOT_READY")
	end
	if ctx.Raid.session(player) then
		return fail("IN_RAID", "Tasks are managed from the hideout.")
	end
	local q = type(p.id) == "string" and QD.byId[p.id]
	if not q then
		return fail("BAD_INPUT")
	end
	local status = Quests.status(prof, q)
	if p.op == "accept" then
		if status ~= "available" then
			return fail("NOT_AVAILABLE")
		end
		prof.quests[q.id] = { s = "active", p = {} }
		ctx.Remotes.note(player, "toast", { text = "TASK ACCEPTED: " .. string.upper(q.name), tone = "good" })
	elseif p.op == "turnin" then
		if status ~= "active" then
			return fail("NOT_ACTIVE")
		end
		if not Quests.complete(prof, q) then
			return fail("INCOMPLETE", "Objectives are not complete yet.")
		end
		for _, o in q.obj do
			if o.kind == "handin" and not takeFir(prof, o.item, o.n) then
				return fail("INCOMPLETE")
			end
		end
		prof.quests[q.id].s = "claimed"
		local r = q.reward or {}
		local rew = { Util.commas(r.money or 0) .. " " .. Config.CURRENCY, (r.xp or 0) .. " XP" }
		for _, e in r.items or {} do
			table.insert(rew, Items.defs[e[1]].name .. (((e[2] or 1) > 1) and (" x" .. e[2]) or ""))
		end
		ctx.Economy.mail(prof, q.trader, "Task complete: " .. q.name .. ". Your reward: " .. table.concat(rew, ", ") .. ".")
		prof.money += r.money or 0
		local up = ctx.Economy.addXp(prof, r.xp or 0)
		if r.rep then
			ctx.Economy.standing(prof, q.trader).rep += r.rep
		end
		if r.karma then
			prof.karma = math.clamp((prof.karma or P.KARMA.start) + r.karma, P.KARMA.min, P.KARMA.max)
		end
		-- reward items arrive like insurance returns: straight to the stash when there is room
		if r.items and #r.items > 0 then
			local bundles = {}
			for _, e in r.items do
				local d = Items.defs[e[1]]
				local left = e[2] or 1
				while left > 0 do
					local take = math.min(left, d.stack)
					local g, it = Inv.newItem(e[1], take)
					it.fir = true
					table.insert(bundles, { g = g, it = it, subs = {}, from = {} })
					left -= take
				end
			end
			table.insert(prof.claims, { readyAt = 0, bundles = bundles, raid = "task:" .. q.id })
		end
		ctx.Remotes.note(player, "toast", { text = string.format("TASK COMPLETE: %s  +%s %s", string.upper(q.name), Util.commas(r.money or 0), Config.CURRENCY), tone = "good" })
		if up then
			ctx.Remotes.note(player, "toast", { text = "LEVEL UP: " .. ctx.Economy.level(prof), tone = "good" })
		end
	else
		return fail("BAD_INPUT")
	end
	ctx.Raid.afterChange(player, false)
	return ctx.Remotes.ok()
end

-- client view: every task with its status and progress
function Quests.stateFor(prof)
	local out = {}
	for _, q in QD.list do
		local status = Quests.status(prof, q)
		local prog = {}
		if status == "active" or status == "claimed" then
			for i in q.obj do
				prog[i] = (status == "claimed") and q.obj[i].n or Quests.progress(prof, q, i)
			end
		end
		out[q.id] = { s = status, p = prog }
	end
	return out
end

function Quests.init(c)
	ctx = c
	ctx.Remotes.onReq("quest", questReq, 4, 6)
	local _ = TD
end

function Quests.start()
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(visitTick)
			if not ok then
				warn("[ZR] quest tick", err)
			end
		end
	end)
end

return Quests
