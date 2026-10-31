--!nonstrict
-- Hideout (M9): build and upgrade modules with money and items (real-time builds that finish while offline),
-- start crafts in built modules and collect the results. Effects: more stash rows, faster healing between raids.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Progress = require(Shared.Progress)
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local HD = require(Shared.HideoutData)

local Hideout = {}
local ctx

local function fail(code, msg)
	return ctx.Remotes.fail(code, msg)
end

function Hideout.levelOf(prof, m)
	return (prof.hideout and prof.hideout.levels[m]) or 0
end

local function applyEffects(prof)
	prof.stashH = HD.STASH_ROWS[Hideout.levelOf(prof, "storage")] or Config.STASH_H
end

-- finish a build whose timer ran out (also on load: builds progress while offline)
function Hideout.settle(prof, player)
	local b = prof.hideout.build
	if b and os.time() >= b.at then
		prof.hideout.levels[b.m] = b.l
		prof.hideout.build = nil
		applyEffects(prof)
		if player then
			ctx.Remotes.note(player, "toast", { text = string.format("%s LEVEL %d READY", HD.modules[b.m].name, b.l), tone = "good" })
		end
		return true
	end
	applyEffects(prof)
	return false
end

local function needsMet(prof, needs)
	for _, n in needs or {} do
		if Hideout.levelOf(prof, n[1]) < n[2] then
			return false, n
		end
	end
	return true
end

local function haveItems(prof, list)
	for _, e in list or {} do
		local _, have = ctx.Economy.stashItems(prof, e[1])
		if have < e[2] then
			return false, e
		end
	end
	return true
end

local function build(player, prof, m)
	local mod = HD.modules[m]
	if not mod then
		return fail("BAD_INPUT")
	end
	if prof.hideout.build then
		return fail("BUSY", "Another module is being built.")
	end
	local nextL = Hideout.levelOf(prof, m) + 1
	local def = mod.levels[nextL]
	if not def then
		return fail("MAX_LEVEL", "Already at the highest level.")
	end
	local okN, n = needsMet(prof, def.needs)
	if not okN then
		return fail("REQUIREMENTS", string.format("Requires %s level %d.", HD.modules[n[1]].name, n[2]))
	end
	if prof.money < def.cost then
		return fail("NOT_ENOUGH_MONEY", "Not enough money.")
	end
	local okI, e = haveItems(prof, def.items)
	if not okI then
		return fail("MISSING_ITEMS", "Missing: " .. Items.defs[e[1]].name .. ".")
	end
	prof.money -= def.cost
	for _, it in def.items or {} do
		ctx.Economy.consumeStash(prof, it[1], it[2])
	end
	prof.hideout.build = { m = m, l = nextL, at = os.time() + def.time }
	ctx.Remotes.note(player, "toast", { text = string.format("BUILDING %s LEVEL %d  ·  %s", mod.name, nextL, Util.clock(def.time)), tone = "good" })
	return true
end

local function craft(player, prof, id)
	local r = HD.byRecipe[id]
	if not r then
		return fail("BAD_INPUT")
	end
	if Hideout.levelOf(prof, r.module) < r.level then
		return fail("LOCKED", string.format("Requires %s level %d.", HD.modules[r.module].name, r.level))
	end
	if prof.hideout.crafts[r.module] then
		return fail("BUSY", "This module is already crafting.")
	end
	local okI, e = haveItems(prof, r.give)
	if not okI then
		return fail("MISSING_ITEMS", "Missing: " .. Items.defs[e[1]].name .. ".")
	end
	for _, it in r.give do
		ctx.Economy.consumeStash(prof, it[1], it[2])
	end
	local ctime = math.floor(r.time * (1 - Progress.bonus(prof.skills, "crafting")))
	prof.hideout.crafts[r.module] = { r = r.id, at = os.time() + ctime }
	ctx.Remotes.note(player, "toast", { text = string.format("CRAFTING %s  ·  %s", string.upper(Items.defs[r.get[1]].name), Util.clock(r.time)), tone = "good" })
	return true
end

local function collect(player, prof, m)
	local c = prof.hideout.crafts[m]
	if not c then
		return fail("NOTHING")
	end
	if os.time() < c.at then
		return fail("NOT_READY", "Not finished yet.")
	end
	local r = HD.byRecipe[c.r]
	if not r or not ctx.Economy.giveStash(prof, r.get[1], r.get[2]) then
		return fail("NO_SPACE", "No room in your stash.")
	end
	prof.hideout.crafts[m] = nil
	ctx.Economy.skillUp(player, prof, "crafting", 4)
	ctx.Remotes.note(player, "toast", { text = string.format("COLLECTED %s x%d", string.upper(Items.defs[r.get[1]].name), r.get[2]), tone = "good" })
	return true
end

local function hideoutReq(player, p)
	local prof = ctx.Profiles.get(player)
	if not prof then
		return fail("NOT_READY")
	end
	if ctx.Raid.session(player) then
		return fail("IN_RAID")
	end
	if ctx.Match.queuedKind(player) == "pmc" then
		return fail("QUEUED", "Leave the queue first.")
	end
	Hideout.settle(prof, player)
	local res
	if p.op == "build" and type(p.m) == "string" then
		res = build(player, prof, p.m)
	elseif p.op == "craft" and type(p.r) == "string" then
		res = craft(player, prof, p.r)
	elseif p.op == "collect" and type(p.m) == "string" then
		res = collect(player, prof, p.m)
	else
		return fail("BAD_INPUT")
	end
	if res ~= true then
		return res
	end
	ctx.Raid.afterChange(player, false)
	return ctx.Remotes.ok()
end

function Hideout.stateFor(prof)
	return { levels = prof.hideout.levels, build = prof.hideout.build, crafts = prof.hideout.crafts, now = os.time() }
end

-- hideout healing multiplier (medstation)
function Hideout.healRate(prof)
	return HD.HEAL_RATE[Hideout.levelOf(prof, "medstation")] or 1
end

function Hideout.init(c)
	ctx = c
	ctx.Remotes.onReq("hideout", hideoutReq, 4, 6)
end

function Hideout.start()
	task.spawn(function()
		while true do
			task.wait(5)
			for player in ctx.Profiles.all() do
				local prof = ctx.Profiles.get(player)
				if prof and prof.hideout and Hideout.settle(prof, player) then
					ctx.Raid.afterChange(player, ctx.Raid.session(player) ~= nil)
				end
			end
		end
	end)
end

return Hideout
