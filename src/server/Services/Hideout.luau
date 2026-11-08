--!nonstrict
-- Hideout (decision economy-7b): EFT's economy core of fourteen modules (HideoutData.luau has the data and the pure
-- rules). Build and upgrade modules with money, items, other modules and skills (several at once, EFT); craft in built
-- modules; fuel the generator (power: crafts in powered modules start only with power and crawl without it, the bitcoin
-- farm stops); send the scavs out with the scav case; mine cold wallets with graphics cards. Everything runs on real time,
-- also offline and in a raid (EFT), every timer divided by Config.HIDEOUT_TIME_DIV. Effects: stash rows, health
-- regeneration (Hideout.healRate, read by Health), and Hideout.bonus for the other services.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Progress = require(Shared.Progress)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local HD = require(Shared.HideoutData)
local HS = require(Shared.HideoutStyle)
local Inv = require(script.Parent.Inv)

local Hideout = {}
local ctx

local function fail(code, msg)
	return ctx.Remotes.fail(code, msg)
end

local function toast(player, text, tone)
	if player and ctx and ctx.Remotes then
		ctx.Remotes.note(player, "toast", { text = text, tone = tone or "good" })
	end
end

local function itemName(id)
	local d = Items.defs[id]
	return d and string.upper(d.name) or id
end

function Hideout.levelOf(prof, m)
	return HD.levelOf(prof.hideout, m)
end

-- old saves take the new shape once (hideout.v; HideoutData.migrate); new profiles start here too
function Hideout.migrate(prof, now)
	prof.hideout = prof.hideout or {}
	local hd = prof.hideout
	hd.levels = hd.levels or {}
	hd.crafts = hd.crafts or {}
	return HD.migrate(hd, now or os.time())
end

function Hideout.powered(prof)
	return prof ~= nil and prof.hideout ~= nil and HD.powered(prof.hideout)
end

-- a bonus summed over the built levels (HideoutData.BONUS lists the kinds); a powered module's only while it has power
function Hideout.bonus(prof, kind)
	local hd = prof and prof.hideout
	if not hd or not hd.levels then
		return 0
	end
	return HD.bonus(hd, kind, HD.powered(hd))
end

-- out-of-raid health regeneration multiplier for Health (EFT: the medstation +6 / +12 / +20 %, the nutrition unit's level
-- 2 +7 %, the rest space +5 / +10 %, all added up while the generator runs)
function Hideout.healRate(prof)
	return 1 + Hideout.bonus(prof, "hpRegen") / 100
end

-- out-of-raid energy and hydration regeneration multipliers (EFT: the nutrition unit +10 / +20 / +30 % energy and its
-- level 3 +20 % hydration, the water collector +10 / +20 / +30 % hydration, the rest space's level 2 +5 % energy)
function Hideout.vitalsRate(prof)
	return 1 + Hideout.bonus(prof, "energyRegen") / 100, 1 + Hideout.bonus(prof, "waterRegen") / 100
end

-- a multiplier from a percentage bonus that shortens or cheapens something (scav cooldown, insurance time, flea fee,
-- repair kit points): 1 - bonus / 100, never below 0
function Hideout.cut(prof, kind)
	return math.max(0, 1 - Hideout.bonus(prof, kind) / 100)
end

local function applyEffects(prof)
	prof.stashH = HD.stashRows(prof.hideout)
end

local function tell(player, ev, hd)
	if ev.k == "build" then
		toast(player, string.format("%s LEVEL %d READY", HD.modules[ev.m].name, ev.l))
	elseif ev.k == "craft" then
		local c = hd.crafts[ev.m]
		if c and c.get then
			toast(player, string.format("%s  ·  READY: %s x%d", HD.modules[ev.m].name, itemName(c.get[1]), c.get[2]))
		end
	elseif ev.k == "fuel" then
		toast(player, "GENERATOR OUT OF FUEL  ·  CRAFTS SLOW DOWN", "warn")
	elseif ev.k == "coin" then
		toast(player, "BITCOIN FARM  ·  A COLD WALLET IS READY")
	elseif ev.k == "scav" then
		toast(player, "SCAV CASE  ·  THE SCAVS ARE BACK")
	end
end

-- bring the hideout up to now: migrate once, run the clocks (fuel, crafts, the farm, builds, the scav case), apply the
-- stash size. True when something finished (the caller sends a new snapshot).
function Hideout.settle(prof, player)
	local now = os.time()
	local migrated = Hideout.migrate(prof, now)
	local hd = prof.hideout
	local events = HD.tick(hd, now)
	applyEffects(prof)
	if player then
		local said = {}
		for _, ev in events do
			local key = ev.k .. (ev.m or "")
			if not said[key] then
				said[key] = true
				tell(player, ev, hd)
			end
		end
	end
	return migrated or #events > 0
end

-- ── stash helpers ────────────────────────────────────────────────────────────────────────────────────────────────
local function stashCount(prof, id)
	local _, n = ctx.Economy.stashItems(prof, id)
	return n
end

local function reqOpts(prof)
	return {
		money = prof.money or 0,
		count = function(id)
			return stashCount(prof, id)
		end,
		skills = prof.skills,
		loyalty = function(tid)
			return ctx.Economy.loyalty(prof, tid)
		end,
	}
end

local function unmet(lines)
	for _, l in lines do
		if not l.ok then
			if l.k == "module" then
				return "REQUIREMENTS", string.format("Requires %s level %d.", HD.modules[l.id].name, l.need)
			elseif l.k == "skill" then
				local s = Progress.SKILLS[l.id]
				return "REQUIREMENTS", string.format("Requires %s level %d.", s and s.name or l.id, l.need)
			elseif l.k == "ll" then
				return "REQUIREMENTS", string.format("Requires loyalty level %d with %s.", l.need, string.upper(l.id))
			elseif l.k == "money" then
				return "NOT_ENOUGH_MONEY", "Not enough money."
			end
			return "MISSING_ITEMS", "Missing: " .. (Items.defs[l.id] and Items.defs[l.id].name or l.id) .. "."
		end
	end
	return nil
end

-- new items into the stash, all or nothing: list of { id, n, fir }
local function giveAll(prof, list)
	local placed = {}
	for _, e in list do
		local d = Items.defs[e[1]]
		local left = d and e[2] or 0
		while left > 0 do
			local take = math.min(left, d.stack or 1)
			local g, it = Inv.newItem(e[1], take, e[3] and { fir = true } or nil)
			if not Inv.place(prof, g, it, { "stash" }) then
				for _, pg in placed do
					Inv.take(prof, pg)
				end
				return false
			end
			table.insert(placed, g)
			left -= take
		end
	end
	prof.known = prof.known or {}
	for _, e in list do
		prof.known[e[1]] = true
	end
	return true
end
Hideout.giveAll = giveAll

-- one item of `id` out of the stash; returns its found-in-raid flag (nil when there is none)
local function takeOne(prof, id)
	local list = ctx.Economy.stashItems(prof, id)
	local pick = list[1]
	if not pick then
		return nil
	end
	local fir = pick.it.fir == true
	Inv.consume(prof, pick.g, 1)
	return fir
end

-- ── requests ─────────────────────────────────────────────────────────────────────────────────────────────────────
local function build(player, prof, m)
	local mod = HD.modules[m]
	if not mod then
		return fail("BAD_INPUT")
	end
	local hd = prof.hideout
	if hd.builds[m] then
		return fail("BUSY", "Already under construction.")
	end
	local cur = HD.levelOf(hd, m)
	local def = mod.levels[cur + 1]
	if not def then
		return fail("MAX_LEVEL", "Already at the highest level.")
	end
	-- ours: a module does not take an upgrade while its craft runs (collect or wait first)
	if hd.crafts[m] then
		return fail("BUSY", "Finish and collect its craft first.")
	end
	local code, msg = unmet((HD.requirements(hd, def, reqOpts(prof))))
	if code then
		return fail(code, msg)
	end
	prof.money -= def.cost or 0
	for _, it in def.items or {} do
		ctx.Economy.consumeStash(prof, it[1], it[2])
	end
	local t = math.ceil(HD.buildNeed(def))
	if t <= 0 then
		hd.levels[m] = cur + 1
		applyEffects(prof)
		toast(player, string.format("%s LEVEL %d READY", mod.name, cur + 1))
	else
		hd.builds[m] = { l = cur + 1, at = os.time() + t }
		toast(player, string.format("BUILDING %s LEVEL %d  ·  %s", mod.name, cur + 1, Util.clock(t)))
	end
	return true
end

local function craft(player, prof, id)
	local r = HD.byRecipe[id]
	if not r then
		return fail("BAD_INPUT")
	end
	local hd = prof.hideout
	local mod = HD.modules[r.module]
	if HD.levelOf(hd, r.module) < r.level then
		return fail("LOCKED", string.format("Requires %s level %d.", mod.name, r.level))
	end
	if hd.builds[r.module] then
		return fail("BUSY", "The module is being upgraded.")
	end
	if hd.crafts[r.module] then
		return fail("BUSY", "This module is already crafting.")
	end
	-- EFT wiki: "The Generator must be active to begin crafting" (not in the lavatory)
	if mod.power and not HD.powered(hd) then
		return fail("NO_POWER", "Turn the generator on first.")
	end
	local code, msg = unmet((HD.requirements(hd, { give = r.give, tools = r.tools }, reqOpts(prof))))
	if code then
		return fail(code, msg)
	end
	for _, e in r.give do
		ctx.Economy.consumeStash(prof, e[1], e[2])
	end
	-- tools go into the craft and come back with the product (EFT)
	local tools = {}
	for _, e in r.tools or {} do
		for _ = 1, e[2] do
			local fir = takeOne(prof, e[1])
			table.insert(tools, { e[1], fir == true })
		end
	end
	local need = HD.craftNeed(r, prof.skills)
	hd.crafts[r.module] = { r = r.id, get = { r.get[1], r.get[2] }, need = need, done = 0, tools = tools }
	toast(player, string.format("CRAFTING %s x%d  ·  %s", itemName(r.get[1]), r.get[2], Util.clock(need)))
	return true
end

local function collect(player, prof, m)
	local hd = prof.hideout
	local c = hd.crafts[m]
	if not c then
		return fail("NOTHING")
	end
	if (c.done or 0) < (c.need or 0) then
		return fail("NOT_READY", "Not finished yet.")
	end
	-- what the hideout makes is found in raid (EFT wiki, Found in raid; audit economy.4); tools keep their own flag
	local list = { { c.get[1], c.get[2], true } }
	for _, t in c.tools or {} do
		table.insert(list, { t[1], 1, t[2] })
	end
	if not giveAll(prof, list) then
		return fail("NO_SPACE", "No room in your stash.")
	end
	hd.crafts[m] = nil
	if player then
		ctx.Economy.skillUp(player, prof, "crafting", 4)
	end
	toast(player, string.format("COLLECTED %s x%d", itemName(c.get[1]), c.get[2]))
	return true
end

local function loadFuel(player, prof)
	local hd = prof.hideout
	if HD.levelOf(hd, "generator") < 1 then
		return fail("LOCKED", "Build the generator first.")
	end
	if #hd.fuel >= HD.fuelSlots(hd) then
		return fail("FULL", "Every fuel slot is taken.")
	end
	if stashCount(prof, HD.FUEL.item) < 1 then
		return fail("MISSING_ITEMS", "No fuel canister in your stash.")
	end
	local wasEmpty = HD.fuelUnits(hd) <= 1e-6
	ctx.Economy.consumeStash(prof, HD.FUEL.item, 1)
	table.insert(hd.fuel, HD.FUEL.units)
	-- ours: fuel into an empty generator starts it (EFT: you switch it on yourself)
	if wasEmpty then
		hd.on = true
	end
	toast(player, string.format("FUEL LOADED  ·  %d UNITS", HD.FUEL.units))
	return true
end

local function power(player, prof, on)
	local hd = prof.hideout
	if HD.levelOf(hd, "generator") < 1 then
		return fail("LOCKED", "Build the generator first.")
	end
	if on and HD.fuelUnits(hd) <= 1e-6 then
		return fail("NO_FUEL", "Load fuel first.")
	end
	hd.on = on == true
	toast(player, hd.on and "GENERATOR ON" or "GENERATOR OFF", hd.on and "good" or "warn")
	return true
end

local function gpu(player, prof, add)
	local hd = prof.hideout
	if HD.levelOf(hd, "bitcoin") < 1 then
		return fail("LOCKED", "Build the bitcoin farm first.")
	end
	hd.btc = hd.btc or { cards = {}, coins = 0, prog = 0 }
	local b = hd.btc
	b.cards = b.cards or {}
	if add then
		if #b.cards >= HD.gpuSlots(hd) then
			return fail("FULL", "Every card slot is taken.")
		end
		local fir = takeOne(prof, HD.BTC.gpu)
		if fir == nil then
			return fail("MISSING_ITEMS", "No graphics card in your stash.")
		end
		table.insert(b.cards, fir)
		toast(player, string.format("GRAPHICS CARD IN  ·  %d/%d", #b.cards, HD.gpuSlots(hd)))
	else
		if #b.cards == 0 then
			return fail("NOTHING")
		end
		if not giveAll(prof, { { HD.BTC.gpu, 1, b.cards[#b.cards] } }) then
			return fail("NO_SPACE", "No room in your stash.")
		end
		table.remove(b.cards)
		toast(player, string.format("GRAPHICS CARD OUT  ·  %d/%d", #b.cards, HD.gpuSlots(hd)))
	end
	return true
end

local function coins(player, prof)
	local b = prof.hideout.btc
	local n = b and b.coins or 0
	if n < 1 then
		return fail("NOTHING")
	end
	if not giveAll(prof, { { HD.BTC.coin, n, true } }) then
		return fail("NO_SPACE", "No room in your stash.")
	end
	b.coins = 0
	toast(player, string.format("COLLECTED %s x%d", itemName(HD.BTC.coin), n))
	return true
end

local function scavStart(player, prof, id)
	local hd = prof.hideout
	if HD.levelOf(hd, "scavcase") < 1 then
		return fail("LOCKED", "Build the scav case first.")
	end
	local run = HD.byScav[id]
	if not run then
		return fail("BAD_INPUT")
	end
	if hd.scav then
		return fail("BUSY", hd.scav.ready and "Collect what the scavs brought first." or "The scavs are still out.")
	end
	if run.money then
		if (prof.money or 0) < run.money then
			return fail("NOT_ENOUGH_MONEY", "Not enough money.")
		end
		prof.money -= run.money
	else
		if stashCount(prof, run.item) < 1 then
			return fail("MISSING_ITEMS", "Missing: " .. Items.defs[run.item].name .. ".")
		end
		ctx.Economy.consumeStash(prof, run.item, 1)
	end
	local t = math.ceil(HD.scavNeed(run, prof.karma))
	hd.scav = { r = run.id, at = os.time() + t, got = HD.rollScav(run, math.random) }
	toast(player, "SCAV CASE  ·  BACK IN " .. Util.clock(t))
	return true
end

local function scavGet(player, prof)
	local hd = prof.hideout
	local s = hd.scav
	if not s then
		return fail("NOTHING")
	end
	if not s.ready and os.time() < s.at then
		return fail("NOT_READY", "The scavs are still out.")
	end
	local list = {}
	for _, e in s.got or {} do
		table.insert(list, { e.id, e.n, true })
	end
	if not giveAll(prof, list) then
		return fail("NO_SPACE", "No room in your stash.")
	end
	hd.scav = nil
	toast(player, string.format("SCAV CASE  ·  %d ITEM%s COLLECTED", #list, #list == 1 and "" or "S"))
	return true
end

-- hideout style (Tarkov 0.16 customisation; HideoutStyle.luau): walls, floor, ceiling, each unlocked by level
local function style(player, prof, cat, id)
	local o = HS.option(cat, id)
	if not o then
		return fail("BAD_INPUT")
	end
	local lvl = ctx.Economy.level(prof)
	if not HS.unlocked(o, lvl) then
		return fail("LOCKED", string.format("Unlocks at level %d.", o.level))
	end
	prof.style = prof.style or {}
	prof.style[cat] = id
	toast(player, string.format("%s  ·  %s", HS.NAMES[cat] or string.upper(cat), string.upper(o.name)))
	return true
end

-- one hideout operation on a profile that is up to date (Hideout.settle first); player may be nil (HideoutTests).
-- Returns true, or a Remotes.fail result.
function Hideout.act(player, prof, p)
	local res
	if type(p) ~= "table" then
		return fail("BAD_INPUT")
	end
	if p.op == "build" and type(p.m) == "string" then
		res = build(player, prof, p.m)
	elseif p.op == "craft" and type(p.r) == "string" then
		res = craft(player, prof, p.r)
	elseif p.op == "collect" and type(p.m) == "string" then
		res = collect(player, prof, p.m)
	elseif p.op == "fuel" then
		res = loadFuel(player, prof)
	elseif p.op == "power" and type(p.on) == "boolean" then
		res = power(player, prof, p.on)
	elseif p.op == "gpu" and type(p.add) == "boolean" then
		res = gpu(player, prof, p.add)
	elseif p.op == "coins" then
		res = coins(player, prof)
	elseif p.op == "scav" and type(p.r) == "string" then
		res = scavStart(player, prof, p.r)
	elseif p.op == "scavGet" then
		res = scavGet(player, prof)
	elseif p.op == "style" and type(p.cat) == "string" and type(p.id) == "string" then
		res = style(player, prof, p.cat, p.id)
	else
		return fail("BAD_INPUT")
	end
	return res
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
	local res = Hideout.act(player, prof, p)
	if res ~= true then
		return res
	end
	ctx.Raid.afterChange(player, false)
	return ctx.Remotes.ok()
end

-- the snapshot's hideout block (out of raid). Finish times are estimates from the power now: the screen counts down to
-- them, and a new snapshot follows whenever something finishes or the player changes the fuel or the switch.
function Hideout.stateFor(prof)
	local hd = prof.hideout
	local now = os.time()
	local powered = HD.powered(hd)
	local fuelSecs = HD.fuelSeconds(hd)
	local crafts = {}
	for m, c in hd.crafts or {} do
		local left = math.max(0, (c.need or 0) - (c.done or 0))
		local mod = HD.modules[m]
		local needsPower = (mod and mod.power and not c.legacy) == true
		crafts[m] = {
			r = c.r, get = c.get, need = c.need, left = left, ready = left <= 0,
			rate = (needsPower and not powered) and HD.NO_POWER or 1, at = now + math.ceil(HD.eta(left, needsPower, powered, fuelSecs)),
		}
	end
	-- one running build for older readers (Lobby.luau's labels)
	local first
	for m, b in hd.builds or {} do
		if not first or b.at < first.at then
			first = { m = m, l = b.l, at = b.at }
		end
	end
	local btc
	if hd.btc and HD.levelOf(hd, "bitcoin") >= 1 then
		local n = #(hd.btc.cards or {})
		local rate = HD.btcRate(n)
		local coinsNow = hd.btc.coins or 0
		local at, short
		if powered and rate > 0 and coinsNow < HD.BTC.cap then
			local secs = (1 - (hd.btc.prog or 0)) / rate
			at, short = now + math.ceil(secs), secs > fuelSecs -- short: the fuel runs out before then
		end
		btc = { gpus = n, slots = HD.gpuSlots(hd), coins = coinsNow, cap = HD.BTC.cap, rate = rate, at = at, short = short }
	end
	local scav
	if hd.scav then
		scav = { r = hd.scav.r, at = hd.scav.at, ready = hd.scav.ready == true or now >= hd.scav.at, n = #(hd.scav.got or {}) }
	end
	return {
		v = hd.v, levels = hd.levels, builds = hd.builds or {}, build = first, crafts = crafts,
		power = powered, on = hd.on == true, fuel = hd.fuel or {}, cap = HD.fuelSlots(hd), burn = HD.burnRate(),
		fuelOut = powered and (now + math.floor(fuelSecs)) or nil, btc = btc, scav = scav, now = now, style = prof.style or {},
	}
end

-- finish every running build, craft and scav run now (ZR_Dev "hideoutNow")
function Hideout.devFinish(prof)
	Hideout.migrate(prof, os.time())
	local hd = prof.hideout
	for _, b in hd.builds do
		b.at = 0
	end
	for _, c in hd.crafts do
		c.done = c.need
	end
	if hd.scav then
		hd.scav.at = 0
	end
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
				-- the hideout runs on during a raid (EFT) but says nothing until you are back
				local inRaid = ctx.Raid.session(player) ~= nil
				if prof and prof.hideout and Hideout.settle(prof, (not inRaid) and player or nil) then
					ctx.Raid.afterChange(player, inRaid)
				end
			end
		end
	end)
end

return Hideout
