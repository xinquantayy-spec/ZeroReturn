--!nonstrict
-- Economy and progression (M9, Tarkov rules): traders sell by loyalty level with per-restock limits, buy the
-- kinds of items they deal in, swap items in barter trades; operators earn experience (kills, searching,
-- examining, surviving), level up, train skills by using them, and build scav karma with the Fence.
-- Run-through: extracting very quickly with almost no experience keeps the loot but it is not found-in-raid.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local TD = require(Shared.TraderData)
local P = require(Shared.Progress)
local Inv = require(script.Parent.Inv)

local Economy = {}
local ctx

local function fail(code, msg)
	return ctx.Remotes.fail(code, msg)
end

local function window(t)
	return math.floor(t / TD.RESTOCK)
end
Economy.window = window

function Economy.level(prof)
	return P.levelOf(prof.xp or 0)
end

local function standing(prof, tid)
	local tr = prof.traders[tid]
	if not tr then
		tr = { spent = 0, rep = 0 }
		prof.traders[tid] = tr
	end
	return tr
end
Economy.standing = standing

-- loyalty level: player level, money spent and earned with the trader, reputation
function Economy.loyalty(prof, tid)
	local lvl = Economy.level(prof)
	local tr = prof.traders[tid] or { spent = 0, rep = 0 }
	local ll = 1
	for i = 2, #TD.LL do
		local req = TD.LL[i]
		if lvl >= req.level and (tr.spent or 0) >= req.spent and (tr.rep or 0) >= req.rep then
			ll = i
		else
			break
		end
	end
	return ll
end

local function boughtCount(prof, key, w)
	local b = prof.bought[key]
	return (b and b.w == w) and b.n or 0
end

local function addBought(prof, key, w, n)
	local b = prof.bought[key]
	if not b or b.w ~= w then
		b = { n = 0, w = w }
		prof.bought[key] = b
	end
	b.n += n
	-- forget older windows so the profile stays small
	for k, v in prof.bought do
		if v.w < w then
			prof.bought[k] = nil
		end
	end
end

-- new items into the stash (ammo split into stacks); all-or-nothing
function Economy.giveStash(prof, id, n, extra)
	local d = Items.defs[id]
	if not d then
		return false
	end
	local left = n or 1
	local placed = {}
	while left > 0 do
		local take = math.min(left, d.stack)
		local g, it = Inv.newItem(id, take, extra and Util.copy(extra) or nil)
		if not Inv.place(prof, g, it, { "stash" }) then
			for _, pg in placed do
				Inv.take(prof, pg)
			end
			return false
		end
		table.insert(placed, g)
		left -= take
	end
	prof.known[id] = true
	return true
end

-- items in the stash (top level) with this id: list of { g, it } and the total count
local function stashItems(prof, id)
	local list, total = {}, 0
	for g in prof.grids.stash or {} do
		local it = prof.items[g]
		if it and it.id == id and not (prof.grids[g] and next(prof.grids[g])) then
			table.insert(list, { g = g, it = it })
			total += it.n or 1
		end
	end
	return list, total
end
Economy.stashItems = stashItems

-- remove n of id from the stash (smallest stacks first)
local function consumeStash(prof, id, n)
	local list = stashItems(prof, id)
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
Economy.consumeStash = consumeStash

-- ── trading ──────────────────────────────────────────────────────────────────
local function buy(player, prof, p)
	local tid = p.trader
	local offers = TD.offers[tid]
	local offer = offers and type(p.i) == "number" and offers[p.i]
	if not offer then
		return fail("BAD_INPUT")
	end
	local qty = (type(p.qty) == "number" and p.qty == p.qty) and math.clamp(math.floor(p.qty), 1, 10) or 1
	local ll = Economy.loyalty(prof, tid)
	if offer.ll > ll then
		return fail("LOCKED", "Requires loyalty level " .. offer.ll .. ".")
	end
	local w = window(os.time())
	local key = tid .. ":" .. p.i
	if boughtCount(prof, key, w) + qty > offer.limit then
		return fail("OUT_OF_STOCK", "Sold out until the restock.")
	end
	local price = TD.price(tid, offer, ll) * qty
	if prof.money < price then
		return fail("NOT_ENOUGH_MONEY", "Not enough money.")
	end
	local done = 0
	for _ = 1, qty do
		if not Economy.giveStash(prof, offer.id, offer.n) then
			break
		end
		done += 1
	end
	if done == 0 then
		return fail("NO_SPACE", "No room in your stash.")
	end
	local paid = TD.price(tid, offer, ll) * done
	prof.money -= paid
	standing(prof, tid).spent += paid
	addBought(prof, key, w, done)
	ctx.Remotes.note(player, "toast", { text = string.format("BOUGHT %s%s  -%s %s", string.upper(Items.defs[offer.id].name), done > 1 and (" x" .. done) or "", Util.commas(paid), Config.CURRENCY), tone = "good" })
	return true
end

local function barter(player, prof, p)
	local tid = p.trader
	local list = TD.barters[tid]
	local offer = list and type(p.i) == "number" and list[p.i]
	if not offer then
		return fail("BAD_INPUT")
	end
	if offer.ll > Economy.loyalty(prof, tid) then
		return fail("LOCKED", "Requires loyalty level " .. offer.ll .. ".")
	end
	local w = window(os.time())
	local key = "b:" .. tid .. ":" .. p.i
	if boughtCount(prof, key, w) >= offer.limit then
		return fail("OUT_OF_STOCK", "Sold out until the restock.")
	end
	for _, need in offer.give do
		local _, have = stashItems(prof, need[1])
		if have < need[2] then
			return fail("MISSING_ITEMS", "Missing: " .. Items.defs[need[1]].name .. ".")
		end
	end
	if not Economy.giveStash(prof, offer.id, 1) then
		return fail("NO_SPACE", "No room in your stash.")
	end
	for _, need in offer.give do
		consumeStash(prof, need[1], need[2])
	end
	addBought(prof, key, w, 1)
	-- barters count toward loyalty at the item's value
	standing(prof, tid).spent += Items.defs[offer.id].value
	ctx.Remotes.note(player, "toast", { text = "TRADED FOR " .. string.upper(Items.defs[offer.id].name), tone = "good" })
	return true
end

-- what a trader pays for a stash item with its magazine and attachments; containers must be empty
function Economy.quote(prof, g, tid)
	local it = prof.items[g]
	if not it then
		return nil, "NO_ITEM"
	end
	if prof.grids[g] and next(prof.grids[g]) then
		return nil, "NOT_EMPTY"
	end
	tid = tid or select(1, TD.bestBuyer(it, prof.karma))
	if not tid then
		return nil, "NOT_BUYING"
	end
	local price = TD.sellPrice(tid, it, prof.karma)
	if not price then
		return nil, "NOT_BUYING"
	end
	local subs = Inv.descendants(prof, g)
	for _, sg in subs do
		local sp = TD.sellPrice(tid, prof.items[sg], prof.karma) or TD.sellPrice("fence", prof.items[sg], prof.karma) or 0
		price += sp
	end
	return price, tid
end

function Economy.sell(player, prof, g, tid)
	if prof.slots.secure == g then
		return fail("NOT_AUTHORIZED")
	end
	local it = prof.items[g]
	if not it then
		return fail("NO_ITEM")
	end
	if not (prof.known[it.id] or Items.knownByDefault(it.id)) then
		return fail("UNKNOWN_ITEM", "Examine it first.")
	end
	if tid ~= nil and not TD.defs[tid] then
		return fail("BAD_INPUT")
	end
	local price, who = Economy.quote(prof, g, tid)
	if not price then
		local msgs = { NOT_EMPTY = "Empty it first.", NOT_BUYING = tid and (TD.defs[tid].name .. " doesn't buy that.") or "No trader buys that." }
		return fail(who or "FAILED", msgs[who or ""])
	end
	if not Inv.take(prof, g) then
		return fail("NO_ITEM")
	end
	prof.money += price
	standing(prof, who).spent += price
	ctx.Remotes.note(player, "toast", { text = string.format("SOLD TO %s  +%s %s", TD.defs[who].name, Util.commas(price), Config.CURRENCY), tone = "good" })
	return true
end

-- ── experience, skills, karma ─────────────────────────────────────────────────
function Economy.addXp(prof, n)
	local before = Economy.level(prof)
	prof.xp = (prof.xp or 0) + math.max(0, math.floor(n))
	return Economy.level(prof) > before
end

-- raid experience goes to the session and is banked when the raid settles (shown on the raid report)
function Economy.raidXp(player, n)
	local s = ctx.Raid.session(player)
	if s and not s.done then
		s.xp = (s.xp or 0) + n
	end
end

function Economy.skill(prof, id, pts)
	if prof and prof.skills and P.SKILLS[id] then
		local before = P.skillLevel(prof.skills[id])
		prof.skills[id] = math.min(1000, (prof.skills[id] or 0) + pts)
		return P.skillLevel(prof.skills[id]) > before
	end
	return false
end

local function skillUp(player, prof, id, pts)
	if Economy.skill(prof, id, pts) then
		ctx.Remotes.note(player, "toast", { text = string.format("%s RAISED TO %d", P.SKILLS[id].name, P.skillLevel(prof.skills[id])), tone = "good" })
		ctx.Raid.push(player)
	end
end
Economy.skillUp = skillUp

-- a raid kill by this player (victimPlayer for raiders, victimModel for AI)
function Economy.onKill(player, victimPlayer, victimModel, headshot)
	local s = ctx.Raid.session(player)
	if not s or s.done then
		return
	end
	local kind
	if victimPlayer then
		local vs = ctx.Raid.session(victimPlayer)
		kind = (vs and vs.scav) and "pscav" or "pmc"
	else
		kind = victimModel and victimModel:GetAttribute("Kind") or "scav"
	end
	local xp = P.XP.kill[kind] or 50
	if headshot then
		xp = math.floor(xp * (1 + P.XP.headshot))
	end
	s.xp = (s.xp or 0) + xp
	if s.scav and (kind == "scav" or kind == "follower" or kind == "boss") then
		s.karmaDelta = (s.karmaDelta or 0) + P.KARMA.killScav
	elseif s.scav and kind == "pscav" then
		s.karmaDelta = (s.karmaDelta or 0) + P.KARMA.killPlayerScav
	end
	if ctx.Quests then
		ctx.Quests.onKill(player, kind)
	end
end

-- current karma for a session (deploy value plus what happened this raid)
function Economy.karmaOf(s)
	return (s.karma or 0) + (s.karmaDelta or 0)
end

-- settle experience, karma and task progress after a raid; returns gained xp, levelled up
function Economy.afterRaid(player, prof, s, outcome, runThrough)
	if outcome == "DISCONNECTED" then
		return 0, false
	end
	local gained = s.xp or 0
	if outcome == "SUCCESS" and not runThrough then
		gained += P.XP.survive
	end
	if s.scav then
		local k = (s.karmaDelta or 0) + ((outcome == "SUCCESS") and P.KARMA.scavExtract or 0)
		prof.karma = math.clamp((prof.karma or P.KARMA.start) + k, P.KARMA.min, P.KARMA.max)
	end
	local up = Economy.addXp(prof, gained)
	if outcome == "SUCCESS" and ctx.Quests then
		ctx.Quests.onExtract(player, prof, s)
	end
	return gained, up
end

-- the state block the client needs for traders / profile screens
function Economy.stateFor(prof)
	local w = window(os.time())
	local traders = {}
	for _, id in TD.list do
		local tr = prof.traders[id] or { spent = 0, rep = 0 }
		traders[id] = { ll = Economy.loyalty(prof, id), spent = tr.spent or 0, rep = tr.rep or 0 }
	end
	local bought = {}
	for k, v in prof.bought do
		if v.w == w then
			bought[k] = v.n
		end
	end
	local skills = {}
	for id in P.SKILLS do
		skills[id] = prof.skills[id] or 0
	end
	return {
		xp = prof.xp or 0, level = Economy.level(prof), skills = skills, karma = prof.karma or P.KARMA.start,
		traders = traders, bought = bought, restockIn = TD.RESTOCK - (os.time() % TD.RESTOCK),
	}
end

-- ── requests / loops ─────────────────────────────────────────────────────────
local function tradeReq(player, p)
	local prof = ctx.Profiles.get(player)
	if not prof then
		return fail("NOT_READY")
	end
	if ctx.Raid.session(player) then
		return fail("IN_RAID", "Traders are reachable from the hideout only.")
	end
	if ctx.Match.queuedKind(player) == "pmc" then
		return fail("QUEUED", "Leave the queue to trade.")
	end
	if p.trader ~= nil and (type(p.trader) ~= "string" or not TD.defs[p.trader]) then
		return fail("BAD_INPUT")
	end
	local res
	if p.op == "buy" then
		res = buy(player, prof, p)
	elseif p.op == "barter" then
		res = barter(player, prof, p)
	elseif p.op == "sell" then
		if type(p.g) ~= "string" or #p.g > 40 then
			return fail("BAD_INPUT")
		end
		res = Economy.sell(player, prof, p.g, p.trader)
	else
		return fail("BAD_INPUT")
	end
	if res ~= true then
		return res
	end
	ctx.Raid.afterChange(player, false)
	return ctx.Remotes.ok()
end

function Economy.init(c)
	ctx = c
	ctx.Remotes.onReq("trade", tradeReq, 6, 10)
end

-- 1 Hz: skills trained by moving in raid (sprinting -> endurance, moving heavy -> strength)
function Economy.start()
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				for player, s in ctx.Raid.sessions() do
					local prof = not s.done and ctx.Profiles.get(player)
					local char = prof and player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root then
						local v = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
						if char:GetAttribute("Sprint") and v > 12 then
							skillUp(player, prof, "endurance", 0.35)
						end
						if v > 2 then
							local kg = Inv.weight(s.inv)
							if kg > Config.WEIGHT_OVER * 0.8 then
								skillUp(player, prof, "strength", 0.25 * math.min(2, kg / Config.WEIGHT_OVER))
							end
						end
					end
				end
			end)
			if not ok then
				warn("[ZR] economy tick", err)
			end
		end
	end)
end

return Economy
