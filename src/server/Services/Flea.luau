--!nonstrict
-- Tarkov's flea market (docs/design/EFT_PARITY.md sections 3 and 10) as a real market across servers (decision
-- economy-3a, "a real market with an AI floor"). Players' offers are held in escrow in their seller's book and shown on
-- every server through the index (FleaStore.luau); operators (AI sellers) fill only items that players offer too
-- little of, and AI buyers take only the cheapest offer of an item at or below the going rate (FleaRules.luau).
-- EFT's rules kept from before: level 15, EFT 1.0's category gates for buying, the ban list, found-in-raid listings,
-- EFT's fee formula (5 % since 1.1.0), offer slots by rating, rating from sales, 12-hour offers, purchases not found in
-- raid. Added from EFT: a price per item with partial purchases of a stack, or a pack sold whole ("List as a pack");
-- REMOVE ends an offer 72 s later and it can be bought until then; an offer that ends unsold costs rating with its
-- value; the item comes back still found in raid; Ragman's role (TILDA) mails the sales and the returns; EFT's listing
-- limits and 1.0.4.0's full ammo stacks.
--
-- Exactly-once trades (the buyer's profile, the seller's book and the seller's profile are three DataStore keys, so
-- each step is idempotent and ordered so that a crash at any point is finished by the next run):
--   buy:     hold the money and write the intent (prof.flea.buys[pid]) -> save -> claim in the seller's book under pid
--            (atomic, at most once per pid) -> deliver, note the owed acknowledgement -> save -> acknowledge in the book.
--            A crash or a lost reply leaves the intent: collect() asks the book (recover: claimed -> deliver; never
--            claimed -> the pid is voided so a late claim cannot land, and the money comes back).
--   list:    take the item, pay the fee, write the offer as "new" with the item -> save -> put into the book (once per
--            offer id) -> on show in the index. A crash re-puts it (a no-op if it is there).
--   collect: (the seller's server, on joining, every minute and when an offer ends) read the book in one UpdateAsync
--            that also ends offers past their time and applies the AI buyers' purchases; credit sales and take returns
--            not yet in prof.flea.got, record them there -> save -> the next collect marks them paid / removes them from
--            the book. So a sale pays its seller exactly once, online or offline.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local FR = require(Shared.FleaRules)
local Inv = require(script.Parent.Inv)
local FleaStore = require(script.Parent.FleaStore)

local Flea = setmetatable({}, { __index = FR })
Flea.Store = FleaStore
Flea.POLL = 60 -- a seller with offers is collected this often while online (ours: the DataStore budget)
Flea.MAX_IDS = 160 -- items one market request may ask for (a category or a search)
local ctx
local live -- the live server's market (Flea.newServer), rebuilt when the profiles' store mode changes
local pstate = {} -- [user id] = { due, n }: when the loop collects that player next

local function fail(code, msg)
	return { ok = false, code = code, msg = msg }
end
local function ok(data)
	return { ok = true, data = data }
end

local function window(t)
	return math.floor(t / FR.WINDOW)
end

local function nameOf(id)
	local d = Items.defs[id]
	return d and d.name or tostring(id)
end

local function fleaOf(prof)
	local f = prof.flea
	if type(f) ~= "table" then
		-- offer and purchase ids are "<user id>-<n>"; a new market state starts n at a random point so that a profile
		-- made again for the same user cannot reuse the ids still recorded in their old book
		f = { rating = FR.RATING_START, offers = {}, n = math.random(1, 99999) * 10000 }
		prof.flea = f
	end
	f.offers, f.buys, f.acks, f.got, f.back = f.offers or {}, f.buys or {}, f.acks or {}, f.got or {}, f.back or {}
	f.n = f.n or 0
	f.rating = f.rating or FR.RATING_START
	return f
end
Flea.fleaOf = fleaOf

local function count(t)
	local n = 0
	for _ in t or {} do
		n += 1
	end
	return n
end

local function mail(prof, text)
	if ctx and ctx.Economy then
		-- EFT: the flea market's sales and returns come in Ragman's chat (EFT wiki, Flea market: "Proceeds are mailed via
		-- Ragman"); TILDA is Ragman's role here (decision economy-2a)
		ctx.Economy.mail(prof, "tilda", text)
	end
end

local function note(who, text, tone)
	if who.player and ctx and ctx.Remotes then
		ctx.Remotes.note(who.player, "toast", { text = text, tone = tone or "good" })
	end
end

local function dirty(who)
	if who.player and ctx and ctx.Profiles then
		ctx.Profiles.markDirty(who.player)
	end
end

local function step(sv, name)
	if sv.crash then
		sv.crash(name) -- tests: a server dying at this point raises here
	end
end

-- collect this player again within seconds (a purchase or listing waits on the store)
local function soon(who)
	pstate[who.uid] = pstate[who.uid] or { due = 0, n = 0 }
	pstate[who.uid].due = 0
end

-- ── items in and out of the stash ────────────────────────────────────────────────────────────────────────────────
-- Inv.place merges a stack into same-id stacks as it places it, which cannot be undone item by item; so a placement is
-- first tried on a scratch copy of the stash, and made for real only when the whole of it fits (all or nothing)
local function scratch(prof)
	return { items = Util.copy(prof.items), grids = Util.copy(prof.grids), slots = Util.copy(prof.slots or {}), stashH = prof.stashH }
end

local function placeUnits(h, id, n, extra)
	local d = Items.defs[id]
	local left = n
	while left > 0 do
		local take = math.min(left, d.stack)
		local g, it = Inv.newItem(id, take, extra and Util.copy(extra) or nil)
		if not Inv.place(h, g, it, { "stash" }) then
			return false
		end
		left -= take
	end
	return true
end

-- can n units of id go into the stash
local function roomFor(prof, id, n)
	return Items.defs[id] ~= nil and n >= 1 and placeUnits(scratch(prof), id, n, nil)
end

-- n units of an item as fresh stacks in the stash, all or nothing
local function giveUnits(prof, id, n, extra)
	if not roomFor(prof, id, n) then
		return false
	end
	placeUnits(prof, id, n, extra)
	prof.known = prof.known or {}
	prof.known[id] = true
	return true
end

-- a bought item is not found in raid and carries nobody's insurance (EFT: flea purchases are not found in raid)
local function strip(b)
	b.it.fir, b.it.ins, b.it.isr = nil, nil, nil
	for _, s in b.subs or {} do
		s.it.fir, s.it.ins, s.it.isr = nil, nil, nil
	end
end

-- a returned item keeps its found-in-raid mark (EFT wiki, Found in raid: items "will not lose the found in raid status
-- if they are put up for sale on the Flea Market and expire or are removed"); into the stash, else it waits in MY
-- OFFERS (EFT keeps it on Ragman's message for 72 h)
local function giveBack(prof, key, r, now)
	local f = fleaOf(prof)
	local d = Items.defs[r.i]
	local placed
	if r.b and d and d.stack <= 1 then
		local b = Util.copy(r.b)
		placed = Inv.give(prof, b, nil, { "stash" })
		if not placed then
			f.back[key] = { b = b, i = r.i, n = 1, t = now, e = now + FR.RETURN_HOLD }
		end
	else
		placed = giveUnits(prof, r.i, r.n, r.nofir and nil or { fir = true })
		if not placed then
			f.back[key] = { i = r.i, n = r.n, fir = not r.nofir, t = now, e = now + FR.RETURN_HOLD }
		end
	end
	return placed
end

-- a purchase into the buyer's stash: the listed item itself when it is a single item (a gun with its parts), else
-- fresh units; neither is found in raid
local function deliver(prof, key, sale, now)
	local f = fleaOf(prof)
	local d = Items.defs[sale.i]
	prof.known = prof.known or {}
	prof.known[sale.i] = true
	if sale.b and d and d.stack <= 1 then
		local b = Util.copy(sale.b)
		strip(b)
		if Inv.give(prof, b, nil, { "stash" }) then
			return true
		end
		f.back[key] = { b = b, i = sale.i, n = 1, t = now, e = now + FR.RETURN_HOLD }
		return false
	end
	if giveUnits(prof, sale.i, sale.n, nil) then
		return true
	end
	f.back[key] = { i = sale.i, n = sale.n, t = now, e = now + FR.RETURN_HOLD }
	return false
end

-- returned or bought items left waiting for stash room past their 72 h are gone (EFT: Ragman's message expires)
local function expireBack(prof, now)
	local f = prof.flea
	local gone = {}
	for k, b in (type(f) == "table" and f.back) or {} do
		if (b.e or 0) <= now then
			table.insert(gone, k)
		end
	end
	table.sort(gone)
	for _, k in gone do
		local b = f.back[k]
		f.back[k] = nil
		mail(prof, string.format("Nobody collected %s in time; it is gone.", nameOf(b.i or (b.b and b.b.it.id))))
	end
	return #gone > 0
end
Flea.expireBack = expireBack

-- ── a server's market ────────────────────────────────────────────────────────────────────────────────────────────
-- backend: FleaStore.robloxBackend / memoryBackend. opts: now (clock), rng / rngInt (random), save(who, prof) -> ok
-- (the live one saves the profile; tests keep a copy), crash (tests). FleaTests makes two of these on one backend.
function Flea.newServer(backend, opts)
	opts = opts or {}
	local R = Random.new(opts.seed or math.floor(os.clock() * 1000))
	local sv = {
		S = FleaStore.new(backend, { now = opts.now }),
		now = opts.now or os.time,
		rng = opts.rng or function()
			return R:NextNumber()
		end,
		rngInt = opts.rngInt or function(a, b)
			return R:NextInteger(a, b)
		end,
		save = opts.save or function()
			return true
		end,
		crash = opts.crash,
		busy = {},
		unsaved = {}, -- [prof] = { [id] = true }: credits made here and not yet saved (never settled before saved)
	}
	return sv
end

local function save(sv, who, prof)
	local okSave = sv.save(who, prof)
	if okSave then
		sv.unsaved[prof] = nil
	end
	return okSave
end

local function markUnsaved(sv, prof, id)
	sv.unsaved[prof] = sv.unsaved[prof] or {}
	sv.unsaved[prof][id] = true
end

-- live player offers of an item in an index entry
local function liveOffers(e, now)
	local out = {}
	for _, o in (e and e.o) or {} do
		if o.e > now and o.n > 0 then
			table.insert(out, o)
		end
	end
	return out
end

-- the market for a player: offers on the items asked for (ids: a category or a search; nil = every item they have
-- examined, Tarkov's handbook rule), players' and operators' together, cheapest first (by the price of one unit)
function Flea.market(prof, ids, sv, who)
	sv = sv or Flea.server()
	local now = sv and sv.now() or os.time()
	local w = window(now)
	local idx = sv and sv.S:index() or {}
	local out = {}
	local list = ids
	if not list then
		list = {}
		for id in Items.defs do
			table.insert(list, id)
		end
	end
	local known = prof.known or {}
	for _, id in list do
		if Flea.tradeable(id) and (known[id] or Items.knownByDefault(id)) and not out[id] then
			local e = idx[id]
			local rows = {}
			local players = liveOffers(e, now)
			for _, o in players do
				table.insert(rows, {
					k = o.o, seller = o.nm, r = o.r, price = o.p, unit = FR.unitOf(o), pk = o.pk or nil, left = o.n, ends = o.e - now,
					mine = (who ~= nil and FR.sellerOf(o.o) == who.uid) or nil,
				})
			end
			for _, a in FR.aiFloor(id, w, #players) do
				local bought = (e and e.w == w and e.a[a.i]) or 0
				table.insert(rows, { i = a.i, seller = a.seller, r = FR.aiRating(a.seller), price = a.price, unit = a.price, left = math.max(0, a.stock - bought), ai = true })
			end
			table.sort(rows, function(a, b)
				if a.unit ~= b.unit then
					return a.unit < b.unit
				end
				if (a.ai == true) ~= (b.ai == true) then
					return not a.ai
				end
				return tostring(a.k or a.i) < tostring(b.k or b.i)
			end)
			out[id] = rows
		end
	end
	return { offers = out, refreshIn = math.min(FleaStore.TTL, FR.WINDOW - now % FR.WINDOW) }
end

-- the player's flea state for snapshots: rating, slots, own offers (the mirror of their book), returned items waiting
function Flea.stateFor(prof)
	local f = prof.flea or {}
	local now = os.time()
	local mine, back = {}, {}
	for k, o in f.offers or {} do
		if o.st then
			table.insert(mine, { k = k, id = o.id, n = o.n, n0 = o.n0, price = o.p, pk = o.pk, left = math.max(0, (o.e or now) - now), st = o.x and "removing" or o.st, t = o.t or 0 })
		else
			-- an offer from before economy-3a, moved to the new market at the next collect
			local n = o.n or 1
			table.insert(mine, { k = k, id = o.id, n = n, n0 = n, price = o.price, pk = n > 1 or nil, left = math.max(0, (o.t or now) + FR.DURATION - now), st = "new", t = o.t or 0 })
		end
	end
	table.sort(mine, function(a, b)
		return a.t == b.t and a.k < b.k or a.t < b.t
	end)
	for k, b in f.back or {} do
		table.insert(back, { k = k, id = b.i or (b.b and b.b.it.id), n = b.n or 1, left = math.max(0, (b.e or now) - now) })
	end
	table.sort(back, function(a, b)
		return a.k < b.k
	end)
	return { rating = f.rating or FR.RATING_START, slots = FR.slots(f.rating), offers = mine, back = back, level = FR.LEVEL, pending = count(f.buys) }
end

-- the index row of a seller's offer
local function rowOf(oid, o, who, rating)
	return { o = oid, p = o.p, n = o.n, e = o.e, r = rating or FR.RATING_START, nm = FR.cleanName(who.name), pk = o.pk }
end

-- ── buying ─────────────────────────────────────────────────────────────────────────────────────────────────────
local function finishBuy(sv, who, prof, pid, b, sale, now)
	local f = fleaOf(prof)
	local placed = deliver(prof, "p" .. pid, sale, now)
	if (sale.m or b.m) < b.m then
		prof.money += b.m - sale.m
	end
	f.buys[pid] = nil
	f.acks[pid] = b.s
	local saved = save(sv, who, prof)
	step(sv, "afterDeliver")
	if saved then
		local okAck = sv.S:ack(b.s, { pid })
		if okAck then
			f.acks[pid] = nil
		end
	end
	dirty(who)
	return placed
end

local function buyPlayer(sv, who, prof, p, now)
	local f = fleaOf(prof)
	local id, oid = p.id, p.k
	local seller = FR.sellerOf(oid)
	if not seller then
		return fail("BAD_INPUT")
	end
	if seller == who.uid then
		return fail("OWN_OFFER", "That is your own offer.")
	end
	local function find(e)
		for _, o in liveOffers(e, now) do
			if o.o == oid then
				return o
			end
		end
		return nil
	end
	-- the offer as the index shows it (re-read once if this server's copy does not have it yet)
	local row = find(sv.S:entry(id)) or find(sv.S:entry(id, 0))
	if not row then
		return fail("SOLD", "Sorry, the offer has already been purchased.")
	end
	local n = math.floor(p.n)
	if row.pk and n ~= row.n then
		-- EFT's "List as a pack": bought whole or not at all
		return fail("PACK", string.format("That offer is sold only as a pack of %d.", row.n))
	end
	if n > row.n then
		return fail("SHORT", "Only " .. row.n .. " left in that offer.")
	end
	if type(p.price) == "number" and FR.unitOf(row) > p.price + 0.001 then
		return fail("CHANGED", "That offer changed; the list is refreshed.")
	end
	local cost = row.pk and row.p or row.p * n
	if prof.money < cost then
		return fail("NOT_ENOUGH_MONEY", "You don't have enough money for the transaction.")
	end
	if not roomFor(prof, id, n) then
		return fail("NO_SPACE", "No room in your stash.")
	end
	-- the money is held and the order written down before the claim: a crash from here on is finished by collect()
	f.n += 1
	local pid = tostring(who.uid) .. "-" .. f.n
	local b = { s = seller, k = oid, i = id, n = n, m = cost, t = now }
	prof.money -= cost
	f.buys[pid] = b
	if not save(sv, who, prof) then
		prof.money += cost
		f.buys[pid] = nil
		return fail("TRY_AGAIN", "The market could not take your order; try again.")
	end
	step(sv, "afterHold")
	local status, sale, left = sv.S:claim(seller, oid, pid, n, { uid = who.uid, name = FR.cleanName(who.name) }, now, cost)
	step(sv, "afterClaim")
	if status == nil then
		dirty(who)
		soon(who)
		return fail("PENDING", "The market is slow to answer; your purchase finishes in a moment.")
	end
	if status == "claimed" then
		finishBuy(sv, who, prof, pid, b, sale, now)
		sv.S:setOffer(id, oid, left or 0, row.e)
		note(who, string.format("BOUGHT %s%s  -%s %s", string.upper(nameOf(id)), n > 1 and (" x" .. n) or "", Util.commas(cost), Config.CURRENCY))
		return ok()
	end
	-- someone was quicker (another server), or the offer ended: the money comes back
	prof.money += cost
	f.buys[pid] = nil
	dirty(who)
	if status == "short" or status == "pack" then
		sv.S:setOffer(id, oid, left or 0, row.e)
		if (left or 0) > 0 then
			return fail("SHORT", "Only " .. left .. " left in that offer.")
		end
	elseif status == "changed" then
		return fail("CHANGED", "That offer changed; the list is refreshed.")
	else
		sv.S:setOffer(id, oid, 0)
	end
	return fail("SOLD", "Sorry, the offer has already been purchased.")
end

local function buyAi(sv, who, prof, p, now)
	local id, i = p.id, p.i
	local e = sv.S:entry(id)
	local offer
	for _, a in FR.aiFloor(id, window(now), #liveOffers(e, now)) do
		if a.i == i then
			offer = a
		end
	end
	if not offer then
		return fail("SOLD", "Offer was sold out")
	end
	if type(p.price) == "number" and offer.price ~= p.price then
		return fail("CHANGED", "The operators' prices changed; the list is refreshed.")
	end
	local n = math.floor(p.n)
	local cost = offer.price * n
	if prof.money < cost then
		return fail("NOT_ENOUGH_MONEY", "You don't have enough money for the transaction.")
	end
	if not roomFor(prof, id, n) then
		return fail("NO_SPACE", "No room in your stash.")
	end
	-- the operators' stock is shared by every server (the index entry), taken atomically before the goods change hands;
	-- nothing is owed to an operator, so a crash here costs the buyer nothing
	local got, left = sv.S:aiTake(id, i, n, offer.stock)
	if not got then
		if type(left) == "number" then
			return fail("SHORT", left > 0 and ("Only " .. left .. " left in that offer.") or "Offer was sold out")
		end
		return fail("TRY_AGAIN", "The market is slow to answer; try again.")
	end
	if not giveUnits(prof, id, n, nil) then
		local f = fleaOf(prof)
		f.n += 1
		f.back["p" .. who.uid .. "-" .. f.n] = { i = id, n = n, t = now, e = now + FR.RETURN_HOLD }
	end
	prof.money -= cost
	dirty(who)
	note(who, string.format("BOUGHT %s%s  -%s %s", string.upper(nameOf(id)), n > 1 and (" x" .. n) or "", Util.commas(cost), Config.CURRENCY))
	return ok()
end

-- ── listing ────────────────────────────────────────────────────────────────────────────────────────────────────
local function list(sv, who, prof, p, now)
	local f = fleaOf(prof)
	local g = p.g
	local it = prof.items[g]
	local where, cid = Inv.locate(prof, g)
	if not it or where ~= "grid" or cid ~= "stash" then
		return fail("NO_ITEM", "Offer items from your stash.")
	end
	local n = it.n or 1
	local okList, why = FR.listable(it.id, n)
	if not okList then
		if why == "FULL_STACK" then
			return fail("FULL_STACK", "Rounds go on the market only in full stacks.")
		end
		return fail("BANNED", "This item can't be sold at the Flea Market.")
	end
	-- the item and every part on it must be found in raid (Tarkov)
	local fir = it.fir
	for _, sg in Inv.descendants(prof, g) do
		fir = fir and prof.items[sg].fir
	end
	if not fir then
		return fail("NOT_FIR", "You can't sell an item which was not found in raid.")
	end
	if prof.grids[g] and next(prof.grids[g]) then
		return fail("NOT_EMPTY", "You can't sell non-empty container at the flea market.")
	end
	if count(f.offers) >= FR.slots(f.rating) then
		return fail("NO_SLOTS", "Reached maximum amount of offers (flea rating " .. string.format("%.2f", f.rating) .. ").")
	end
	local limit = FR.LIST_LIMIT[it.id]
	if limit then
		local listed = 0
		for _, o in f.offers do
			if o.id == it.id then
				listed += o.n or 1
			end
		end
		if listed + n > limit then
			return fail("LIMIT", string.format("This item (%s) has a listing limit! Maximum: %d", nameOf(it.id), limit))
		end
	end
	local pk = p.pk == true and n > 1
	local price = math.floor(p.price)
	local total = pk and price or price * n
	-- the intelligence center's level 3 cuts the fee 30 % (EFT wiki, Flea market; economy-7b)
	local cut = (ctx and ctx.Hideout and ctx.Hideout.cut) and ctx.Hideout.cut(prof, "fleaFee") or 1
	local fee = math.floor(FR.fee(Items.defs[it.id].value or 0, n, total) * cut)
	if prof.money < fee then
		return fail("NOT_ENOUGH_MONEY", "The listing fee is " .. Util.commas(fee) .. " " .. Config.CURRENCY .. ".")
	end
	if #liveOffers(sv.S:entry(it.id), now) >= FR.MAX_PER_ITEM then
		return fail("MARKET_FULL", "The market has no room for more offers of that item right now.")
	end
	f.n += 1
	local oid = tostring(who.uid) .. "-" .. f.n
	local b = Inv.take(prof, g)
	if not b then
		return fail("NO_ITEM")
	end
	local single = Items.defs[it.id].stack <= 1
	prof.money -= fee
	local mo = { id = it.id, n = n, n0 = n, p = price, pk = pk or nil, t = now, e = now + FR.DURATION, st = "new", b = b, fee = fee }
	f.offers[oid] = mo
	if not save(sv, who, prof) then
		f.offers[oid] = nil
		prof.money += fee
		giveBack(prof, "r" .. oid, { i = it.id, n = n, b = single and b or nil }, now)
		return fail("TRY_AGAIN", "The market could not take your offer; try again.")
	end
	step(sv, "afterListSave")
	local put = { i = it.id, n = n, n0 = n, p = price, pk = pk or nil, t = now, e = mo.e, b = single and b or nil }
	local okPut, putSt = sv.S:putOffer(who.uid, oid, put)
	step(sv, "afterPut")
	if not okPut or putSt == "taken" then
		-- no answer (or an id used before): the offer is saved as "new" and collect() puts it up
		dirty(who)
		soon(who)
		return fail("PENDING", "The market is slow to answer; your offer goes up in a moment.")
	end
	local shown, whyShow = sv.S:addOffer(it.id, rowOf(oid, mo, who, f.rating))
	if not shown and (whyShow == "full" or whyShow == "TotalMemoryOverLimit") then
		-- the shop window has no room: take the offer back while nobody can have bought it, fee and all
		if sv.S:withdraw(who.uid, oid) == "withdrawn" then
			f.offers[oid] = nil
			prof.money += fee
			giveBack(prof, "r" .. oid, { i = it.id, n = n, b = single and b or nil, nofir = not it.fir }, now)
			dirty(who)
			return fail("MARKET_FULL", "The market has no room for more offers right now; your item and fee are back.")
		end
	end
	mo.st, mo.b = "open", nil
	if not shown then
		-- held in escrow but not on show yet: the next collect puts it in the index
		mo.hide = true
		soon(who)
	end
	dirty(who)
	note(who, string.format("OFFER PLACED  ·  FEE -%s %s", Util.commas(fee), Config.CURRENCY))
	return ok({ k = oid })
end

-- ── removing ───────────────────────────────────────────────────────────────────────────────────────────────────
local function remove(sv, who, prof, p, now)
	local f = fleaOf(prof)
	local o = f.offers[p.k]
	if not o then
		return fail("BAD_INPUT")
	end
	if o.st ~= "open" then
		return fail("PENDING", "That offer is still going up; try again in a moment.")
	end
	if o.x then
		return fail("REMOVING", "That offer is already being removed.")
	end
	local status, ends = sv.S:cancel(who.uid, p.k, now)
	if status == nil then
		return fail("TRY_AGAIN", "The market is slow to answer; try again.")
	end
	if status == "gone" then
		-- it sold out or ended a moment ago: collect settles it
		pstate[who.uid] = pstate[who.uid] or { due = 0, n = 0 }
		pstate[who.uid].due = 0
		return fail("SOLD", "That offer has already ended.")
	end
	o.x, o.e = true, ends
	sv.S:setOffer(o.id, p.k, o.n, ends)
	pstate[who.uid] = pstate[who.uid] or { due = 0, n = 0 }
	pstate[who.uid].due = math.min(pstate[who.uid].due, ends + 1)
	dirty(who)
	note(who, "OFFER REMOVED  ·  IT ENDS IN " .. math.max(0, ends - now) .. " S", "info")
	return ok({ ends = ends - now })
end

-- RECEIVE: returned or bought items that waited for stash room
local function receive(sv, who, prof, p, now)
	local f = fleaOf(prof)
	local got, waiting = 0, 0
	local keys = {}
	for k in f.back do
		table.insert(keys, k)
	end
	table.sort(keys)
	for _, k in keys do
		local b = f.back[k]
		if p.k == nil or p.k == k then
			if (b.e or 0) <= now then
				f.back[k] = nil
			else
				local placed
				if b.b then
					placed = Inv.give(prof, Util.copy(b.b), nil, { "stash" })
				else
					placed = giveUnits(prof, b.i, b.n, b.fir and { fir = true } or nil)
				end
				if placed then
					f.back[k] = nil
					got += 1
				else
					waiting += 1
				end
			end
		end
	end
	local _ = sv
	dirty(who)
	if got == 0 and waiting > 0 then
		return fail("NO_SPACE", "No room in your stash.")
	end
	return ok({ got = got, waiting = waiting })
end

-- ── the seller's collection (also finishes the player's own interrupted purchases) ─────────────────────────────
-- the AI buyers' chance a minute for one of the seller's offers: only the item's cheapest offer, at or below the going
-- rate (FleaRules.aiBuyRate); the competition is the index entry (at most a minute old) and the operators' floor
local function aiRate(sv, o, oid, now)
	local e = sv.S:entry(o.id, FleaStore.TTL)
	local players, cheapest, here = 0, math.huge, false
	for _, x in liveOffers(e, now) do
		players += 1
		if x.o == oid then
			here = true
		else
			cheapest = math.min(cheapest, FR.unitOf(x))
		end
	end
	if not here then
		players += 1
	end
	for _, a in FR.aiFloor(o.id, window(now), players) do
		cheapest = math.min(cheapest, a.price)
	end
	return FR.aiBuyRate(FR.unitOf(o), FR.aiRef(o.id, cheapest))
end
Flea.aiRate = aiRate

-- opts: inRaid (sales are credited, returns wait until the stash is reachable), republish (check the shop window for
-- this seller's offers), noAi (no AI buyers). Returns changed, sold, returned.
function Flea.collect(sv, who, prof, opts)
	opts = opts or {}
	local f = fleaOf(prof)
	local now = sv.now()
	local changed, sold, returned = false, 0, 0
	-- returned items past their storage time are gone (EFT: 72 h on Ragman's message)
	if expireBack(prof, now) then
		changed = true
	end
	-- 1. this player's purchases left pending by a crash or a lost reply
	local pids = {}
	for pid in f.buys do
		table.insert(pids, pid)
	end
	table.sort(pids)
	for _, pid in pids do
		local b = f.buys[pid]
		local status, sale = sv.S:recover(b.s, pid, now)
		if status == "claimed" then
			finishBuy(sv, who, prof, pid, b, sale, now)
			changed = true
			mail(prof, string.format("Your purchase of %s (%d) went through: check your stash.", nameOf(b.i), b.n))
		elseif status == "void" then
			prof.money += b.m
			f.buys[pid] = nil
			changed = true
			mail(prof, string.format("Your purchase of %s (%d) did not go through: the offer had ended. %s %s returned.", nameOf(b.i), b.n, Util.commas(b.m), Config.CURRENCY))
		end
	end
	-- 2. offers from before economy-3a (kept in the profile with the whole stack's price): still running ones move to the
	-- market as packs at their price and end time, ended ones come back (no rating change: the old market never showed them)
	local puts, migrated = {}, false
	local legacy = {}
	for k, o in f.offers do
		if not o.st then
			table.insert(legacy, k)
		end
	end
	table.sort(legacy)
	for _, k in legacy do
		local o = f.offers[k]
		f.offers[k] = nil
		migrated = true
		local n = o.n or 1
		if not o.b or not Items.defs[o.id] then
			-- nothing to move
		elseif now >= (o.t or 0) + FR.DURATION then
			giveBack(prof, "r" .. k, { i = o.id, n = n, b = o.b }, now)
			mail(prof, string.format("Your offer of (%s) has expired! The item is back.", nameOf(o.id)))
		else
			f.n += 1
			local oid = tostring(who.uid) .. "-" .. f.n
			f.offers[oid] = { id = o.id, n = n, n0 = n, p = math.max(1, math.floor(o.price or 1)), pk = n > 1 or nil, t = o.t, e = o.t + FR.DURATION, st = "new", b = o.b, lg = true }
		end
	end
	if migrated then
		changed = true
		save(sv, who, prof)
	end
	for oid, o in f.offers do
		if o.st == "new" then
			local single = Items.defs[o.id] and Items.defs[o.id].stack <= 1
			puts[oid] = { i = o.id, n = o.n, n0 = o.n0, p = o.p, pk = o.pk, t = o.t, e = o.e, b = single and o.b or nil, lg = o.lg }
		end
	end
	-- 3. the AI buyers since the last look (the seller's offers sell while they are offline too: the time is caught up)
	local plans = {}
	if not opts.noAi then
		local oids = {}
		for oid in f.offers do
			table.insert(oids, oid)
		end
		table.sort(oids)
		for _, oid in oids do
			local o = f.offers[oid]
			if o.st == "open" then
				local from = o.chk or o.t
				local to = math.min(now, o.e)
				if to > from then
					o.chk = to
					local rate = aiRate(sv, o, oid, now)
					if rate > 0 and sv.rng() < 1 - (1 - rate) ^ ((to - from) / 60) then
						table.insert(plans, { o = oid, pid = "a" .. oid .. "-" .. to, t = to - 1, n = o.pk and o.n or sv.rngInt(1, o.n), bn = FR.SELLERS[sv.rngInt(1, #FR.SELLERS)] })
					end
				end
			end
		end
	end
	-- 4. the book, in one UpdateAsync: settle what the saved profile already holds, end offers, apply the AI buyers
	local got = {}
	local unsaved = sv.unsaved[prof] or {}
	for id in f.got do
		if not unsaved[id] then
			got[id] = true
		end
	end
	step(sv, "beforeCollect")
	local book = sv.S:collect(who.uid, { now = now, got = got, ai = plans, puts = puts })
	if not book then
		return changed, 0, 0
	end
	for id in got do
		f.got[id] = nil
	end
	local show, rekeyed = {}, false
	for oid in puts do
		local o = f.offers[oid]
		if o and book.k[oid] == o.t then
			o.st, o.b = "open", nil
			show[oid] = true
			changed = true
		elseif o and book.k[oid] ~= nil then
			-- the id was used for another listing (a profile made again): the offer takes the next id and goes up next time
			f.offers[oid] = nil
			f.n += 1
			f.offers[tostring(who.uid) .. "-" .. f.n] = o
			rekeyed, changed = true, true
		end
	end
	if rekeyed then
		save(sv, who, prof)
	end
	-- 5. sales: the money, the rating, Ragman's message
	local sids = {}
	for pid in book.s do
		table.insert(sids, pid)
	end
	table.sort(sids)
	for _, pid in sids do
		local s = book.s[pid]
		if not s.pd and not f.got[pid] then
			prof.money += s.m
			f.rating += FR.ratingGain(s.m)
			f.got[pid] = now
			markUnsaved(sv, prof, pid)
			sold += 1
			changed = true
			-- EFT's text: "Your {soldItem} {itemCount} items were bought by {buyerNickname}." (locale 5bdabfb886f7743e152e867e 0)
			mail(prof, string.format("Your %s (%d) were bought by %s for %s %s.", nameOf(s.i), s.n, s.bn ~= "" and s.bn or "an operator", Util.commas(s.m), Config.CURRENCY))
		end
	end
	-- 6. returns: ended or removed offers' unsold units (in a raid they wait in the book until the stash is reachable)
	local ended = {}
	if not opts.inRaid then
		local rids = {}
		for rid in book.r do
			table.insert(rids, rid)
		end
		table.sort(rids)
		for _, rid in rids do
			local r = book.r[rid]
			if not f.got[rid] then
				local placed = giveBack(prof, rid, r, now)
				-- EFT: an offer that ends unsold, or is removed, costs rating with the unsold value (FleaRules.ratingLoss)
				if not r.lg then
					f.rating -= FR.ratingLoss(r.pk and r.p or r.p * r.n)
				end
				f.got[rid] = now
				markUnsaved(sv, prof, rid)
				ended[r.o] = true
				returned += 1
				changed = true
				local where = placed and "The item is back in your stash." or "Your stash is full: it waits in MY OFFERS for 72 hours."
				if r.x then
					mail(prof, string.format("Your offer of (%s) was removed. %s", nameOf(r.i), where))
				else
					-- EFT's text: "Your offer of ({0}) has expired!"
					mail(prof, string.format("Your offer of (%s) has expired! %s", nameOf(r.i), where))
				end
			end
		end
	end
	-- 7. the mirror follows the book (units left, ends, removal); an offer no longer there sold out or ended
	local sync = {}
	for oid, o in f.offers do
		if o.st == "open" then
			local bo = book.o[oid]
			if bo then
				if o.n ~= bo.n or o.e ~= bo.e then
					sync[oid] = { id = o.id, n = bo.n, e = bo.e }
				end
				o.n, o.e, o.x = bo.n, bo.e, bo.x
			elseif book.r["r" .. oid] and not f.got["r" .. oid] and not ended[oid] then
				o.st = "ended" -- its return waits for the end of the raid
			else
				sync[oid] = { id = o.id, n = 0 }
			end
		elseif o.st == "ended" and (f.got["r" .. oid] or not book.r["r" .. oid]) then
			sync[oid] = { id = o.id, n = 0 }
		end
	end
	for oid, s in sync do
		if s.n == 0 then
			f.offers[oid] = nil
			changed = true
		end
	end
	-- 8. the credits are saved before any later collect may settle them in the book
	if sv.unsaved[prof] and next(sv.unsaved[prof]) then
		save(sv, who, prof)
	end
	step(sv, "afterCollect")
	-- 9. acknowledgements this player's server still owes other sellers' books
	local owed = {}
	for pid, s in f.acks do
		owed[s] = owed[s] or {}
		table.insert(owed[s], pid)
	end
	for s, list in owed do
		if sv.S:ack(s, list) then
			for _, pid in list do
				f.acks[pid] = nil
			end
		end
	end
	-- 10. the shop window: units sold to the AI buyers, offers ended, new offers on show, lost entries put back
	for oid, s in sync do
		sv.S:setOffer(s.id, oid, s.n, s.e)
	end
	for oid, o in f.offers do
		if o.hide and o.st == "open" then
			show[oid] = true
		end
	end
	for oid in show do
		local o = f.offers[oid]
		if o and sv.S:addOffer(o.id, rowOf(oid, o, who, f.rating)) then
			o.hide = nil
		end
	end
	if opts.republish then
		for oid, o in f.offers do
			if o.st == "open" and not show[oid] and o.e > now then
				local present = false
				for _, x in liveOffers(sv.S:entry(o.id, 0), now) do
					present = present or x.o == oid
				end
				if not present then
					sv.S:addOffer(o.id, rowOf(oid, o, who, f.rating))
				end
			end
		end
	end
	if changed then
		dirty(who)
	end
	return changed, sold, returned
end

-- does this profile have anything for the book (offers, pending purchases, owed acknowledgements, unsettled credits)
function Flea.pending(prof)
	local f = prof.flea
	return type(f) == "table" and (next(f.offers or {}) ~= nil or next(f.buys or {}) ~= nil or next(f.acks or {}) ~= nil or next(f.got or {}) ~= nil)
end

-- ── requests ───────────────────────────────────────────────────────────────────────────────────────────────────
local function num(v, lo, hi)
	return type(v) == "number" and v == v and v >= lo and v <= hi
end
local function str(v, max)
	return type(v) == "string" and #v > 0 and #v <= max
end

-- one request on a profile that is out of the raid and level 15 (the live handler checks both); who = { uid, name,
-- player? }; lvl: the player's level (the category gates)
function Flea.handle(sv, who, prof, p, lvl)
	if type(p) ~= "table" or type(p.op) ~= "string" then
		return fail("BAD_INPUT")
	end
	local op = p.op
	if op == "market" then
		local ids
		if p.ids ~= nil then
			if type(p.ids) ~= "table" or #p.ids > Flea.MAX_IDS then
				return fail("BAD_INPUT")
			end
			ids = {}
			for _, id in p.ids do
				if not str(id, 40) then
					return fail("BAD_INPUT")
				end
				table.insert(ids, id)
			end
		end
		return ok(Flea.market(prof, ids, sv, who))
	end
	if op == "buy" then
		if not str(p.id, 40) or not Items.defs[p.id] or not num(p.n, 1, 100000) or (p.price ~= nil and not num(p.price, 0.001, 1e9)) then
			return fail("BAD_INPUT")
		end
		if (p.k == nil) == (p.i == nil) or (p.k ~= nil and not FR.sellerOf(p.k)) or (p.i ~= nil and not num(p.i, 1, 8)) then
			return fail("BAD_INPUT")
		end
		-- EFT 1.0's category gates (audit economy.3): the offer is there, greyed out, until the player's level
		local can, why = FR.canBuy(p.id, lvl or 1)
		if not can then
			if why == "LOCKED" then
				return fail("LOCKED", "Buying that on the flea market needs level " .. FR.levelFor(p.id) .. ".")
			end
			return fail("BAD_INPUT")
		end
	elseif op == "list" then
		if not str(p.g, 40) or not num(p.price, 1, 999999999) or (p.pk ~= nil and type(p.pk) ~= "boolean") then
			return fail("BAD_INPUT")
		end
	elseif op == "remove" then
		if not str(p.k, 24) then
			return fail("BAD_INPUT")
		end
	elseif op == "receive" then
		if p.k ~= nil and not str(p.k, 40) then
			return fail("BAD_INPUT")
		end
	else
		return fail("BAD_INPUT")
	end
	if not sv.S:usable() then
		return fail("MARKET_DOWN", "Flea Market is currently unavailable; your offers are safe.")
	end
	if op ~= "receive" and not sv.S:canWrite() then
		return fail("BUSY", "The market is busy; try again in a moment.")
	end
	if sv.busy[who.uid] then
		return fail("BUSY", "The market is still working on your last order.")
	end
	sv.busy[who.uid] = true
	local now = sv.now()
	local okCall, res = pcall(function()
		if op == "buy" then
			if p.k ~= nil then
				return buyPlayer(sv, who, prof, p, now)
			end
			return buyAi(sv, who, prof, p, now)
		elseif op == "list" then
			return list(sv, who, prof, p, now)
		elseif op == "remove" then
			return remove(sv, who, prof, p, now)
		end
		return receive(sv, who, prof, p, now)
	end)
	sv.busy[who.uid] = nil
	if not okCall then
		warn("[ZR] flea " .. op .. " stopped:", res)
		return fail("SERVER_ERROR")
	end
	return res
end

-- ── the live server ────────────────────────────────────────────────────────────────────────────────────────────
local function storeMode()
	return (ctx and ctx.Store and ctx.Store.mode) or "MEMORY"
end

-- the live market: DataStore books and the MemoryStore index when the profiles use the DataStore, in-server tables in
-- Studio without API access (the profiles live in memory there too), nothing while the DataStore is down (OFFLINE)
function Flea.server()
	local mode = storeMode()
	local want = mode == "MEMORY" and "memory" or "roblox"
	if live and live.kind == want then
		live.mode = mode
		return live
	end
	local backend
	if want == "roblox" then
		backend = FleaStore.robloxBackend(storeMode)
		if not backend then
			-- never hold a live server's escrow in memory: the market stays shut until the DataStore can be opened
			backend = FleaStore.memoryBackend(os.time)
			backend.usable = function()
				return false
			end
		end
	else
		backend = FleaStore.memoryBackend(os.time)
	end
	local kind = backend.kind == "memory" and want == "roblox" and "broken" or want
	live = Flea.newServer(backend, {
		save = function(who, prof)
			if not who.player or not ctx then
				return true
			end
			local okSave = ctx.Profiles.save(who.player, true)
			return okSave
		end,
	})
	live.mode, live.kind = mode, kind
	return live
end

local function whoOf(player)
	return { uid = player.UserId, name = player.Name, player = player }
end

local function req(player, p)
	local prof = ctx.Profiles.get(player)
	if not prof then
		return fail("NOT_READY")
	end
	if ctx.Raid.session(player) then
		return fail("IN_RAID", "The flea market is out of the raid.")
	end
	local lvl = ctx.Economy.level(prof)
	if lvl < FR.LEVEL then
		return fail("LOCKED", "The flea market opens at level " .. FR.LEVEL .. ".")
	end
	local res = Flea.handle(Flea.server(), whoOf(player), prof, p, lvl)
	if type(p) == "table" and p.op ~= "market" then
		ctx.Raid.afterChange(player, false)
	end
	return res
end

-- the old entry point (Dev's flea tool, LogicTests): collect this player's market now
function Flea.resolve(player, prof, now, inRaid)
	if not player then
		-- no player (a bare test profile): only offers from before economy-3a can be settled, by returning them
		local f = prof.flea
		local changed = false
		for k, o in (f and f.offers) or {} do
			if not o.st and o.b then
				f.offers[k] = nil
				giveBack(prof, "r" .. k, { i = o.id, n = o.n or 1, b = o.b }, now or os.time())
				changed = true
			end
		end
		return changed
	end
	local sv = Flea.server()
	local changed = Flea.collect(sv, whoOf(player), prof, { inRaid = inRaid })
	return changed
end

-- ZR_Dev: move the player's offers `minutes` back in time (their book and their mirror), then collect
function Flea.devAge(player, prof, minutes)
	local sv = Flea.server()
	local sec = math.floor((minutes or 10) * 60)
	sv.S:age(player.UserId, sec)
	for _, o in fleaOf(prof).offers do
		if o.st then
			o.t -= sec
			o.e -= sec
			o.chk = (o.chk or o.t) - sec
		end
	end
	return Flea.collect(sv, whoOf(player), prof, {})
end

function Flea.init(c)
	ctx = c
	ctx.Remotes.onReq("flea", req, 6, 10, Flea.MAX_IDS + 10)
end

-- every 5 s: players who are due are collected (on joining, every POLL seconds while they have offers or anything
-- pending, and just after one of their offers ends); returned items past their 72 h go
function Flea.start()
	task.spawn(function()
		while true do
			task.wait(5)
			local sv = Flea.server()
			if sv and sv.S:usable() then
				local now = os.time()
				local seen = {}
				for player in ctx.Profiles.all() do
					local prof = ctx.Profiles.get(player)
					if prof and typeof(player) == "Instance" and player.Parent then
						local uid = player.UserId
						seen[uid] = true
						local st = pstate[uid]
						if not st then
							st = { due = 0, n = 0 }
							pstate[uid] = st
						end
						if type(prof.flea) == "table" and next(prof.flea.back or {}) and expireBack(prof, now) then
							ctx.Profiles.markDirty(player)
						end
						if now >= st.due and not sv.busy[uid] and Flea.pending(prof) then
							st.n += 1
							sv.busy[uid] = true
							local inRaid = ctx.Raid.session(player) ~= nil
							local okRun, changed, sold, returned = pcall(Flea.collect, sv, whoOf(player), prof, { inRaid = inRaid, republish = st.n % 5 == 1 })
							sv.busy[uid] = nil
							if not okRun then
								warn("[ZR] flea collect:", changed)
							elseif changed then
								if (sold or 0) > 0 then
									-- EFT's notice: "Your offer was sold. Check your messages!"
									ctx.Remotes.note(player, "toast", { text = "YOUR OFFER WAS SOLD. CHECK YOUR MESSAGES!", tone = "good" })
								end
								if (returned or 0) > 0 then
									ctx.Remotes.note(player, "toast", { text = "AN OFFER OF YOURS HAS ENDED  ·  MESSENGER, TILDA", tone = "info" })
								end
								if not inRaid then
									ctx.Raid.afterChange(player, false)
								end
							end
							-- next time: a minute from now, or just after the soonest of their offers ends
							local nextAt = now + Flea.POLL
							for _, o in fleaOf(prof).offers do
								if o.e and o.e + 1 > now then
									nextAt = math.min(nextAt, o.e + 1)
								end
							end
							st.due = math.max(now + 5, nextAt)
						end
					end
				end
				for uid in pstate do
					if not seen[uid] then
						pstate[uid] = nil
					end
				end
			end
		end
	end)
end

return Flea
