--!nonstrict
-- Economy and progression (M9, Tarkov rules): traders sell by loyalty level with per-restock limits, buy the
-- kinds of items they deal in, swap items in barter trades; operators earn experience (kills, searching,
-- examining, surviving), level up, train skills by using them, and build scav karma with the Fence.
-- Run-through: extracting very quickly with almost no experience keeps the loot but it is not found-in-raid.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local WP = require(Shared.WeaponParts)
local Util = require(Shared.Util)
local TD = require(Shared.TraderData)
local QD = require(Shared.QuestData)
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

-- the messenger (Tarkov): a message from a trader or the system, newest last, the last 40 kept
function Economy.mail(prof, from, text)
	prof.msgs = prof.msgs or {}
	table.insert(prof.msgs, { f = from, t = os.time(), x = string.sub(text, 1, 240) })
	while #prof.msgs > 40 do
		table.remove(prof.msgs, 1)
	end
end

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

-- loyalty level: each trader's own table (TraderData.LOYALTY: EFT 1.1.0's player level and standing; money spent is
-- counted but asks nothing). Fence's comes from karma alone (EFT: LL2 at a Fence standing of 6.0; TraderData.fenceLoyalty,
-- audit economy.5): his only task pays karma, so the standing rule left him at LL1 for good.
function Economy.loyalty(prof, tid)
	if tid == "fence" then
		return TD.fenceLoyalty(prof.karma or P.KARMA.start)
	end
	local tr = prof.traders and prof.traders[tid]
	return TD.loyaltyOf(tid, Economy.level(prof), tr and tr.rep or 0, tr and tr.spent or 0)
end

-- ── old saves (decision economy-2a: four traders became EFT's eight) ─────────────────────────────────────────────
-- Profiles keep standing per trader id; VOS, HALE, TILDA and FENCE keep their ids and what was earned with them, the
-- new traders start at LL1. Two things moved with the split, once per profile (trv, the trader data version):
-- the standing of a claimed task that changed trader goes with the task (so standing stays the sum of each trader's
-- task rewards, as on a new profile), and this restock's purchase counts are cleared (they are kept by offer index,
-- and the offer lists changed). Money spent stays where it was spent.
Economy.TRADERS_V = 2
-- the trader each moved task had before (QuestData has the new one)
Economy.MOVED_TASKS = { V5 = "vos", V7 = "vos", T2 = "tilda", T3 = "tilda", T4 = "tilda", T5 = "tilda", T7 = "tilda" }
function Economy.migrate(prof)
	if type(prof) ~= "table" then
		return false
	end
	prof.traders = prof.traders or {}
	prof.bought = prof.bought or {}
	prof.quests = prof.quests or {}
	if (tonumber(prof.trv) or 1) >= Economy.TRADERS_V then
		return false
	end
	for id, old in Economy.MOVED_TASKS do
		local q = QD.byId[id]
		local st = prof.quests[id]
		local rep = q and q.reward and q.reward.rep
		if q and q.trader ~= old and type(st) == "table" and st.s == "claimed" and rep and rep > 0 then
			local from = standing(prof, old)
			from.rep = math.max(0, (from.rep or 0) - rep)
			local to = standing(prof, q.trader)
			to.rep = (to.rep or 0) + rep
		end
	end
	table.clear(prof.bought)
	prof.trv = Economy.TRADERS_V
	return true
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
	-- a refused delivery leaves the stash as it was: the stacks of this id that new units merged into get their counts
	-- back as well (the flea thread's finding, economy-3a: they used to keep the merged units)
	local before = {}
	for bg, bit in prof.items do
		if bit.id == id then
			before[bg] = bit.n
		end
	end
	local left = n or 1
	local placed = {}
	while left > 0 do
		local take = math.min(left, d.stack)
		local g, it = Inv.newItem(id, take, extra and Util.copy(extra) or nil)
		if not Inv.place(prof, g, it, { "stash" }) then
			for _, pg in placed do
				if prof.items[pg] then
					Inv.take(prof, pg)
				end
			end
			for bg, n0 in before do
				local bit = prof.items[bg]
				if bit then
					bit.n = n0
				end
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

-- remove n of id from the stash (smallest stacks first, then the most worn: a used repair kit goes before a fresh one,
-- as EFT's refill craft takes it)
local function consumeStash(prof, id, n)
	local list = stashItems(prof, id)
	table.sort(list, function(a, b)
		local na, nb = a.it.n or 1, b.it.n or 1
		if na ~= nb then
			return na < nb
		end
		return (a.it.pts or math.huge) < (b.it.pts or math.huge)
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
	if TD.offerLock then
		-- a task-locked offer (economy-6a; EFT: on sale once its task is done)
		local locked, why = TD.offerLock(offer, ll, prof.quests)
		if locked then
			return fail("LOCKED", why)
		end
	end
	local w = window(os.time())
	local key = tid .. ":" .. p.i
	if boughtCount(prof, key, w) + qty > offer.limit then
		return fail("OUT_OF_STOCK", "Sold out until the restock.")
	end
	-- karma moves Fence's prices both ways (audit economy.5); the other traders ignore it
	local price = TD.price(tid, offer, ll, prof.karma) * qty
	if prof.money < price then
		return fail("NOT_ENOUGH_MONEY", "Not enough money.")
	end
	local done = 0
	-- a gun comes as a build (its preset or the default one) with an empty magazine (M14)
	local extra = WP.isBase(offer.id) and { preset = offer.preset, presetMag = true } or nil
	for _ = 1, qty do
		if not Economy.giveStash(prof, offer.id, offer.n, extra) then
			break
		end
		done += 1
	end
	if done == 0 then
		return fail("NO_SPACE", "No room in your stash.")
	end
	local paid = TD.price(tid, offer, ll, prof.karma) * done
	prof.money -= paid
	standing(prof, tid).spent += paid
	addBought(prof, key, w, done)
	ctx.Remotes.note(player, "toast", { text = string.format("BOUGHT %s%s  -%s %s", string.upper(Items.defs[offer.id].name), done > 1 and (" x" .. done) or "", Util.commas(paid), Config.CURRENCY), tone = "good" })
	return true
end

-- SERVICES: a trader repairs an item (weapons at VOS and KOVAC, weapons and armour at ROOK, as EFT's Prapor, Mechanic and
-- Skier); each repair lowers the maximum (Tarkov), and the price follows the trader's loyalty level (TraderData.REPAIRS)
local function repair(player, prof, p)
	local tid = p.trader
	if type(tid) ~= "string" or type(p.g) ~= "string" or #p.g > 40 then
		return fail("BAD_INPUT")
	end
	local it = prof.items[p.g]
	if not it then
		return fail("NO_ITEM")
	end
	local pts, cost, newMax = TD.repairQuote(tid, it, P.bonus(prof.skills, "charisma"), Economy.loyalty(prof, tid))
	if not pts then
		return fail("NOT_REPAIRABLE", TD.defs[tid].name .. " can't repair that.")
	end
	if prof.money < cost then
		return fail("NOT_ENOUGH_MONEY", "Not enough money.")
	end
	prof.money -= cost
	standing(prof, tid).spent += cost
	local d = Items.defs[it.id]
	if d.armor then
		it.dur, it.dmax = newMax, newMax
	else
		it.wear, it.wmax = newMax, newMax
		it.mf, it.mfk, it.mfh = nil, nil, nil
	end
	ctx.Remotes.note(player, "toast", { text = string.format("REPAIRED %s  -%s %s", string.upper(d.name), Util.commas(cost), Config.CURRENCY), tone = "good" })
	return true
end

-- SERVICES at HALE: EFT's Therapist treatment (decision gameplay-6b). HEAL ALL: every missing HP, destroyed part, bleed
-- and fracture of the bunker body at TraderData.treatQuote's price (30 / 33 / 36 / 40.5 MK an HP by HALE's loyalty level,
-- 750 a light bleed, 1,400 a heavy one, 1,350 a fracture; a destroyed part its missing HP plus 2,500), free for players at
-- level 5 or below (EFT). Money paid counts as money spent with her.
local function treat(player, prof, p)
	if p.trader ~= TD.TREATMENT.trader then
		return fail("BAD_INPUT")
	end
	local hs = ctx.Health and ctx.Health.of(player)
	if not hs or hs.dead or hs.inRaid then
		return fail("NOT_READY", "Come back to the bunker first.")
	end
	local cost, lines, free = TD.treatQuote(ctx.Health.treatState(hs), Economy.loyalty(prof, p.trader), Economy.level(prof))
	if #lines == 0 then
		return fail("NOTHING_TO_TREAT", "Nothing to treat.")
	end
	if prof.money < cost then
		return fail("NOT_ENOUGH_MONEY", "Not enough money.")
	end
	prof.money -= cost
	if cost > 0 then
		standing(prof, p.trader).spent += cost
	end
	ctx.Health.treat(hs)
	ctx.Health.push(hs) -- the healed body reaches the client with the trade's answer, not up to a tick later
	prof.health = ctx.Health.save(hs)
	local paid = free and string.format("FREE AT LEVEL %d OR BELOW", TD.TREATMENT.freeLevel) or string.format("-%s %s", Util.commas(cost), Config.CURRENCY)
	ctx.Remotes.note(player, "toast", { text = "TREATED BY " .. TD.defs[p.trader].name .. "  ·  " .. paid, tone = "good" })
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
	if TD.offerLock then
		local locked, why = TD.offerLock(offer, Economy.loyalty(prof, tid), prof.quests)
		if locked then
			return fail("LOCKED", why)
		end
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
	-- a barter may give a stack (economy-1a: a box of rounds)
	if not Economy.giveStash(prof, offer.id, offer.n or 1, WP.isBase(offer.id) and { presetMag = true } or nil) then
		return fail("NO_SPACE", "No room in your stash.")
	end
	for _, need in offer.give do
		consumeStash(prof, need[1], need[2])
	end
	addBought(prof, key, w, 1)
	-- barters count toward loyalty at the item's value
	standing(prof, tid).spent += Items.defs[offer.id].value * (offer.n or 1)
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

-- sell one stash item (no message): price, trader | nil, failure
local function sellOne(prof, g, tid)
	if prof.slots.secure == g then
		return nil, fail("NOT_AUTHORIZED")
	end
	local it = prof.items[g]
	if not it then
		return nil, fail("NO_ITEM")
	end
	if not (prof.known[it.id] or Items.knownByDefault(it.id)) then
		return nil, fail("UNKNOWN_ITEM", "Examine it first.")
	end
	if tid ~= nil and not TD.defs[tid] then
		return nil, fail("BAD_INPUT")
	end
	local price, who = Economy.quote(prof, g, tid)
	if not price then
		local msgs = { NOT_EMPTY = "Empty it first.", NOT_BUYING = tid and (TD.defs[tid].name .. " doesn't buy that.") or "No trader buys that." }
		return nil, fail(who or "FAILED", msgs[who or ""])
	end
	if not Inv.take(prof, g) then
		return nil, fail("NO_ITEM")
	end
	prof.money += price
	standing(prof, who).spent += price
	return price, who
end
Economy.sellOne = sellOne

function Economy.sell(player, prof, g, tid)
	local price, who = sellOne(prof, g, tid)
	if not price then
		return who
	end
	ctx.Remotes.note(player, "toast", { text = string.format("SOLD TO %s  +%s %s", TD.defs[who].name, Util.commas(price), Config.CURRENCY), tone = "good" })
	return true
end

-- the trader screen's SELL deal: several items in one request (each checked like a single sale)
function Economy.sellMany(player, prof, gs, tid)
	local total, n, lastFail = 0, 0, nil
	for _, g in gs do
		local price, who = sellOne(prof, g, tid)
		if price then
			total += price
			n += 1
		else
			lastFail = who
		end
	end
	if n == 0 then
		return lastFail or fail("NOT_BUYING")
	end
	ctx.Remotes.note(player, "toast", { text = string.format("SOLD %d ITEM%s TO %s  +%s %s", n, n == 1 and "" or "S", tid and TD.defs[tid].name or "TRADERS", Util.commas(total), Config.CURRENCY), tone = "good" })
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
		prof.skills[id] = math.min(P.SKILL_CAP, (prof.skills[id] or 0) + pts)
		return P.skillLevel(prof.skills[id]) > before
	end
	return false
end

-- skill fatigue (Tarkov): within a raid a skill trains at 129% until its first point, 100% after, then
-- 0.6^(points - 1) from the second point on; 200 s without gains brings it back to 100%
local fatigue = setmetatable({}, { __mode = "k" }) -- [raid session or player][skill] = { n, t, fresh }
function Economy.fatigueMul(key, id, now)
	local per = fatigue[key]
	if not per then
		per = {}
		fatigue[key] = per
	end
	local f = per[id]
	if not f then
		f = { n = 0, t = now, fresh = true }
		per[id] = f
	end
	if now - f.t > 200 then
		f.n = 0
	end
	return f.fresh and 1.29 or (f.n < 2 and 1 or 0.6 ^ (f.n - 1)), f
end

local function skillUp(player, prof, id, pts, spilled)
	if not (prof and id and P.SKILLS[id] and pts and pts > 0) then
		return
	end
	local now = os.clock()
	local mul, f = Economy.fatigueMul(ctx.Raid.session(player) or player, id, now)
	-- the shooting range's level 3 trains combat skills 10 % faster (EFT's SkillGroupLevelingBoost; economy-7b)
	local gain = pts * mul * ((ctx.Hideout and P.SKILLS[id].cat == "COMBAT") and (1 + ctx.Hideout.bonus(prof, "skillCombat") / 100) or 1)
	f.n += gain
	f.t = now
	if f.n >= 1 then
		f.fresh = false
	end
	if Economy.skill(prof, id, gain) then
		local lvl = P.skillLevel(prof.skills[id])
		ctx.Remotes.note(player, "toast", { text = lvl >= P.SKILL_MAX and (P.SKILLS[id].name .. " IS ELITE") or string.format("%s RAISED TO %d", P.SKILLS[id].name, lvl), tone = "good" })
		ctx.Raid.push(player)
	end
	-- Health grows with the physical skills, Charisma with the mental ones
	local spill = not spilled and P.SKILL_SPILL[id]
	if spill then
		skillUp(player, prof, spill[1], pts * spill[2], true)
	end
end
Economy.skillUp = skillUp

-- weapon mastering (Tarkov; Progress.MASTERING): points into a weapon group, kept in the profile at once like the skills
-- (so a death keeps them) and with no raid fatigue; true when the group reached a new level
function Economy.mastery(prof, gid, pts)
	if not (prof and P.MASTERING[gid] and type(pts) == "number" and pts > 0) then
		return false
	end
	prof.mastering = prof.mastering or {}
	local before = P.masteryLevel(gid, prof.mastering[gid])
	prof.mastering[gid] = (prof.mastering[gid] or 0) + pts
	return P.masteryLevel(gid, prof.mastering[gid]) > before
end

-- a hit landed with this weapon (Weapons id): the server's only way in (Combat, once per hit and so per pellet)
function Economy.masteryUp(player, prof, weaponId, pts)
	local gid = weaponId and P.MASTERY_OF[weaponId]
	if gid and Economy.mastery(prof, gid, pts) then
		-- Tarkov's notice: "{0} mastering leveled up to {1}"
		local lvl = P.masteryLevel(gid, prof.mastering[gid])
		ctx.Remotes.note(player, "toast", { text = string.format("%s MASTERING LEVELED UP TO %d", string.upper(P.MASTERING[gid].name), lvl), tone = "good" })
		ctx.Raid.push(player) -- the new level applies at once (level 3: reload while aiming)
	end
end

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
		-- the victim's Label names a boss for tasks that want one boss (audit economy.9); its model lets the kill
		-- conditions read the killing hit (body part, weapon) and the distance (economy-6a)
		ctx.Quests.onKill(player, kind, victimModel and victimModel:GetAttribute("Label") or nil, victimModel or (victimPlayer and victimPlayer.Character))
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
	elseif outcome == "KIA" or outcome == "MIA" then
		gained = math.floor(gained * P.XP.lost) -- EFT keeps 75 % of a lost raid's experience (1.0.2.0; economy-4b)
	end
	-- a scav's raid moves the Fence standing; a PMC's only through a co-op exit (Extract, Progress.KARMA.coop)
	local k = s.karmaDelta or 0
	if s.scav and outcome == "SUCCESS" then
		k += P.KARMA.scavExtract
	end
	if s.scav or k ~= 0 then
		prof.karma = math.clamp((prof.karma or P.KARMA.start) + k, P.KARMA.min, P.KARMA.max)
	end
	local up = Economy.addXp(prof, gained)
	if player and ctx.Quests and ctx.Quests.onRaidEnd then
		-- every settled outcome (economy-6a): run-throughs do not count for extraction tasks, quest items are kept only
		-- on a survived raid, a death resets the in-one-raid objectives
		ctx.Quests.onRaidEnd(player, prof, s, outcome, runThrough)
	elseif player and outcome == "SUCCESS" and ctx.Quests then
		ctx.Quests.onExtract(player, prof, s)
	end
	return gained, up
end

-- the state block the client needs for traders / profile screens
function Economy.stateFor(prof)
	-- an old save moves to the eight traders before anything reads it (the snapshot is built before any request)
	Economy.migrate(prof)
	local w = window(os.time())
	local traders = {}
	for _, id in TD.list do
		local tr = prof.traders[id] or { spent = 0, rep = 0 }
		local ll = Economy.loyalty(prof, id)
		traders[id] = { ll = ll, spent = tr.spent or 0, rep = tr.rep or 0 }
		-- a new loyalty level arrives as a message from the trader (Tarkov's messenger); Fence's comes with karma, before
		-- any trade with him. EFT's levels open goods; prices stay
		if (prof.traders[id] or ll > 1) and ll > (tr.llSeen or 1) then
			tr = standing(prof, id)
			tr.llSeen = ll
			Economy.mail(prof, id, string.format("Loyalty level %d. New goods are open to you.", ll))
		end
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
	-- mastering points per group (the client's MASTERING tab, and the reload rules of the weapon in hands)
	local mastering = {}
	for gid in P.MASTERING do
		mastering[gid] = (prof.mastering and prof.mastering[gid]) or 0
	end
	return {
		xp = prof.xp or 0, level = Economy.level(prof), skills = skills, mastering = mastering, karma = prof.karma or P.KARMA.start,
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
	Economy.migrate(prof)
	local res
	if p.op == "buy" then
		res = buy(player, prof, p)
	elseif p.op == "barter" then
		res = barter(player, prof, p)
	elseif p.op == "repair" then
		res = repair(player, prof, p)
	elseif p.op == "treat" then
		res = treat(player, prof, p)
	elseif p.op == "sell" then
		if type(p.g) ~= "string" or #p.g > 40 then
			return fail("BAD_INPUT")
		end
		res = Economy.sell(player, prof, p.g, p.trader)
	elseif p.op == "sellmany" then
		if type(p.gs) ~= "table" or #p.gs == 0 or #p.gs > 40 then
			return fail("BAD_INPUT")
		end
		local seen = {}
		for _, g in p.gs do
			if type(g) ~= "string" or #g > 40 or seen[g] then
				return fail("BAD_INPUT")
			end
			seen[g] = true
		end
		res = Economy.sellMany(player, prof, p.gs, p.trader)
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
						-- covert movement: moving crouched or prone; the vests: moving in armour of their class
						local st = char:GetAttribute("Stance")
						if v > 1.5 and (st == "c" or st == "p") then
							skillUp(player, prof, "covert", 0.2)
						end
						local ag = s.inv.slots and s.inv.slots.armor
						local ad = ag and s.inv.items[ag] and Items.defs[s.inv.items[ag].id]
						if v > 2 and ad and ad.armor then
							-- (EFT's armour type, every vest has one since gameplay-2a: the PC-4 copies the light 6B23-2)
							local heavy = ad.armor.type == "heavy" or (ad.armor.type == nil and (ad.armor.class or 0) >= 4)
							skillUp(player, prof, heavy and "heavyvests" or "lightvests", 0.08)
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
