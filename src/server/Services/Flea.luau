--!nonstrict
-- Tarkov's flea market (docs/design/EFT_PARITY.md section 3), adapted to Roblox's small servers: the market is
-- other operators' offers (a deterministic set per 15-minute window, priced around each item's value) plus your own
-- offers, which other operators buy over time (the closer to the market price, the sooner). Tarkov's rules: unlocked
-- at level 15; only found-in-raid items can be offered; secure containers, quest items and money cannot; Tarkov's
-- listing fee formula; offer slots by flea rating (+0.01 per 50,000 sold, a loss when an offer is pulled or
-- expires); bought items are not found in raid; sales are reported in the messenger.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local Inv = require(script.Parent.Inv)

local Flea = setmetatable({}, { __index = require(Shared.FleaRules) })
local ctx
local bought, boughtW = {}, -1 -- units bought from each operator offer this window, on this server

local function fail(code, msg)
	return ctx.Remotes.fail(code, msg)
end

local function window(t)
	return math.floor(t / Flea.WINDOW)
end

local function boughtOf(w, key)
	if w ~= boughtW then
		bought, boughtW = {}, w
	end
	return bought[key] or 0
end

-- the market for a player: the items they have examined (Tarkov's handbook rule), each with its offers
function Flea.market(prof)
	local w = window(os.time())
	local out = {}
	for id, d in Items.defs do
		if Flea.tradeable(id) and (prof.known[id] or Items.knownByDefault(id)) then
			local offers = Flea.offersFor(id, w)
			for _, o in offers do
				o.left = math.max(0, o.stock - boughtOf(w, id .. ":" .. o.i))
			end
			out[id] = offers
		end
	end
	return { offers = out, refreshIn = Flea.WINDOW - (os.time() % Flea.WINDOW) }
end

-- the player's flea state for snapshots: rating, slots, own offers
function Flea.stateFor(prof)
	local f = prof.flea or { rating = 0.2, offers = {} }
	local now = os.time()
	local mine = {}
	for k, o in f.offers or {} do
		table.insert(mine, { k = k, id = o.id, n = o.n, price = o.price, left = math.max(0, (o.t or now) + Flea.DURATION - now) })
	end
	return { rating = f.rating or 0.2, slots = Flea.slots(f.rating), offers = mine, level = Flea.LEVEL }
end

local function fleaOf(prof)
	prof.flea = prof.flea or { rating = 0.2, offers = {}, n = 0 }
	prof.flea.offers = prof.flea.offers or {}
	return prof.flea
end

-- resolve the player's offers up to now (also after time offline): sales, and expiries once out of the raid
function Flea.resolve(player, prof, now, inRaid)
	local f = prof.flea
	if not f or not f.offers then
		return false
	end
	now = now or os.time()
	local changed = false
	for k, o in f.offers do
		local last = o.chk or o.t
		local minutes = math.max(0, (math.min(now, o.t + Flea.DURATION) - last) / 60)
		o.chk = now
		local unit = Flea.marketPrice(o.id) * (o.n or 1)
		local p = 1 - (1 - Flea.saleRate(o.price, unit)) ^ minutes
		if minutes > 0 and math.random() < p then
			prof.money += o.price
			f.rating = (f.rating or 0.2) + o.price / 50000 * 0.01
			f.offers[k] = nil
			changed = true
			ctx.Economy.mail(prof, "system", string.format("Flea market: your %s%s sold for %s %s.", Items.defs[o.id].name, (o.n or 1) > 1 and (" x" .. o.n) or "", Util.commas(o.price), Config.CURRENCY))
		elseif not inRaid and now >= o.t + Flea.DURATION then
			-- expired: the item comes back (to the stash when there is room) and the rating dips
			if Inv.give(prof, o.b, nil, { "stash" }) then
				f.offers[k] = nil
				f.rating = math.max(0, (f.rating or 0.2) - 0.02)
				changed = true
				ctx.Economy.mail(prof, "system", "Flea market: your offer for " .. Items.defs[o.id].name .. " expired; the item is back in your stash.")
			end
		end
	end
	if changed and player then
		ctx.Profiles.markDirty(player)
	end
	return changed
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
	if lvl < Flea.LEVEL then
		return fail("LOCKED", "The flea market opens at level " .. Flea.LEVEL .. ".")
	end
	local f = fleaOf(prof)
	if p.op == "market" then
		return ctx.Remotes.ok(Flea.market(prof))
	elseif p.op == "buy" then
		if type(p.id) ~= "string" or not Flea.tradeable(p.id) or type(p.i) ~= "number" then
			return fail("BAD_INPUT")
		end
		local n = (type(p.n) == "number" and p.n == p.n) and math.clamp(math.floor(p.n), 1, 200) or 1
		local w = window(os.time())
		local offer
		for _, o in Flea.offersFor(p.id, w) do
			if o.i == p.i then
				offer = o
			end
		end
		if not offer then
			return fail("SOLD_OUT", "That offer is gone.")
		end
		local key = p.id .. ":" .. offer.i
		local left = offer.stock - boughtOf(w, key)
		if left < n then
			return fail("SOLD_OUT", "Not enough left in that offer.")
		end
		local cost = offer.price * n
		if prof.money < cost then
			return fail("NOT_ENOUGH_MONEY", "Not enough money.")
		end
		-- flea purchases are not found in raid (Tarkov)
		if not ctx.Economy.giveStash(prof, p.id, n, nil) then
			return fail("NO_SPACE", "No room in your stash.")
		end
		prof.money -= cost
		bought[key] = (bought[key] or 0) + n
		ctx.Remotes.note(player, "toast", { text = string.format("BOUGHT %s%s  -%s %s", string.upper(Items.defs[p.id].name), n > 1 and (" x" .. n) or "", Util.commas(cost), Config.CURRENCY), tone = "good" })
	elseif p.op == "list" then
		if type(p.g) ~= "string" or #p.g > 40 or type(p.price) ~= "number" or p.price ~= p.price or p.price < 1 or p.price > 50000000 then
			return fail("BAD_INPUT")
		end
		local it = prof.items[p.g]
		local where, cid = Inv.locate(prof, p.g)
		if not it or where ~= "grid" or cid ~= "stash" then
			return fail("NO_ITEM", "Offer items from your stash.")
		end
		if not Flea.tradeable(it.id) then
			return fail("BANNED", "That can't go on the flea market.")
		end
		-- the item and every part on it must be found in raid (Tarkov)
		local fir = it.fir
		for _, sg in Inv.descendants(prof, p.g) do
			fir = fir and prof.items[sg].fir
		end
		if not fir then
			return fail("NOT_FIR", "Only found-in-raid items can be offered.")
		end
		if prof.grids[p.g] and next(prof.grids[p.g]) then
			return fail("NOT_EMPTY", "Empty it first.")
		end
		local count = 0
		for _ in f.offers do
			count += 1
		end
		if count >= Flea.slots(f.rating) then
			return fail("NO_SLOTS", "No free offer slots (flea rating " .. string.format("%.2f", f.rating or 0.2) .. ").")
		end
		local price = math.floor(p.price)
		local fee = Flea.fee(Items.defs[it.id].value or 0, it.n or 1, price)
		if prof.money < fee then
			return fail("NOT_ENOUGH_MONEY", "The listing fee is " .. Util.commas(fee) .. " " .. Config.CURRENCY .. ".")
		end
		local b = Inv.take(prof, p.g)
		if not b then
			return fail("NO_ITEM")
		end
		prof.money -= fee
		f.n = (f.n or 0) + 1
		f.offers["o" .. f.n] = { id = it.id, n = it.n or 1, price = price, t = os.time(), b = b }
		ctx.Remotes.note(player, "toast", { text = string.format("OFFER PLACED  ·  FEE -%s %s", Util.commas(fee), Config.CURRENCY), tone = "good" })
	elseif p.op == "remove" then
		local o = type(p.k) == "string" and f.offers[p.k]
		if not o then
			return fail("BAD_INPUT")
		end
		if not Inv.give(prof, o.b, nil, { "stash" }) then
			return fail("NO_SPACE", "No room in your stash.")
		end
		f.offers[p.k] = nil
		f.rating = math.max(0, (f.rating or 0.2) - 0.02)
	else
		return fail("BAD_INPUT")
	end
	ctx.Raid.afterChange(player, false)
	return ctx.Remotes.ok()
end

function Flea.init(c)
	ctx = c
	ctx.Remotes.onReq("flea", req, 6, 10)
end

-- every 30 s: other operators buy what is fairly priced
function Flea.start()
	task.spawn(function()
		while true do
			task.wait(30)
			for player, prof in ctx.Profiles.all() do
				-- offers sell while you are in a raid too; the stash and messenger catch up when you are back
				local inRaid = ctx.Raid.session(player) ~= nil
				if prof.flea and next(prof.flea.offers or {}) and Flea.resolve(player, prof, os.time(), inRaid) and not inRaid then
					ctx.Raid.afterChange(player, false)
				end
			end
		end
	end)
end

return Flea
