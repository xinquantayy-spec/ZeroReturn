--!nonstrict
-- Flea market checks for decision economy-3a ("a real market with an AI floor"): EFT's rules (FleaRules.luau), and the
-- market's trades on scratch profiles over FleaStore's in-server backend, never the live stores: listing (fee, slots,
-- found in raid, bans, listing limits, full ammo stacks), the shop window across servers (cheapest first, sellers'
-- names and ratings), whole and partial purchases and packs, two buyers on two servers at once (only one wins),
-- REMOVE against a purchase, expiry back to the seller, the mailbox paying an offline seller exactly once, a server
-- dying at each step of a trade, the AI floor only where players offer too little, AI buyers ignoring overpriced
-- offers, the operators' stock shared by every server, the index losing an entry, MemoryStore down (the Roblox
-- backend's own fallback, with stand-in services), the memory quota, old offers moving over, and payload checks.
-- Run via ZR_Dev "tests" (every module in Tests); offline the same file runs under Lua 5.4 with Roblox stand-ins.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Services = script.Parent.Parent:WaitForChild("Services")
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local FR = require(Shared.FleaRules)
local Inv = require(Services.Inv)
local FleaStore = require(Services.FleaStore)

local T = {}
local LVL = 40 -- the buyers' level (past every category gate)

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local function holder(money)
	local p = Inv.newHolder("profile")
	p.money, p.known, p.msgs, p.xp, p.rev = money or 10000000, {}, {}, 0, 0
	return p
end

-- an item into the stash; found in raid with every part a gun is built with (as raid loot is)
local function put(p, id, n, fir)
	local g, it = Inv.newItem(id, n or 1, fir and { fir = true } or nil)
	assert(Inv.place(p, g, it, { "stash" }), "no room for " .. id)
	if fir then
		for _, sg in Inv.descendants(p, g) do
			p.items[sg].fir = true
		end
	end
	return g
end

-- units of an item in the stash, and how many of them are found in raid
local function units(p, id)
	local n, fir = 0, 0
	for g in p.grids.stash or {} do
		local it = p.items[g]
		if it and it.id == id then
			n += it.n or 1
			if it.fir then
				fir += it.n or 1
			end
		end
	end
	return n, fir
end

local function lastMsg(p)
	return (p.msgs and p.msgs[#p.msgs]) or { f = "", x = "" }
end

local function size(t)
	local n = 0
	for _ in t or {} do
		n += 1
	end
	return n
end

function T.run(ctx)
	local Flea = (ctx and ctx.Flea) or require(Services.Flea)
	local passed, failed, notes = 0, 0, {}
	local function check(name, cond)
		if cond then
			passed += 1
		else
			failed += 1
			table.insert(notes, "FAIL " .. name)
		end
	end
	local function section(name, fn)
		local okRun, err = pcall(fn)
		if not okRun then
			failed += 1
			table.insert(notes, "ERROR in " .. name .. ": " .. tostring(err))
		end
	end

	-- a shared store (one memory backend, its own clock) that several "servers" use; saves keep a copy per user id
	local function world()
		local W = { t = 1800000000, saves = {}, failSave = false, roll = 0.999 }
		W.now = function()
			return W.t
		end
		W.b = FleaStore.memoryBackend(W.now)
		function W.server(crash, backend)
			return Flea.newServer(backend or W.b, {
				now = W.now,
				rng = function()
					return W.roll
				end,
				rngInt = function(_, hi)
					return hi
				end,
				save = function(who, prof)
					if W.failSave then
						return false
					end
					W.saves[who.uid] = Util.copy(prof)
					return true
				end,
				crash = crash,
			})
		end
		return W
	end
	local function crashAt(stepName)
		return function(s)
			if s == stepName then
				error("CRASH " .. s)
			end
		end
	end
	local function list(sv, who, p, g, price, pk)
		return Flea.handle(sv, who, p, { op = "list", g = g, price = price, pk = pk }, LVL)
	end
	local function buy(sv, who, p, id, k, n, lvl)
		return Flea.handle(sv, who, p, { op = "buy", id = id, k = k, n = n }, lvl or LVL)
	end
	local function rowOf(sv, p, who, id, k)
		local m = Flea.market(p, { id }, sv, who).offers[id] or {}
		for _, r in m do
			if r.k == k then
				return r, m
			end
		end
		return nil, m
	end

	-- ── EFT's rules ──────────────────────────────────────────────────────────────────────────────────────────────
	section("rules", function()
		check("fee: EFT's formula at 1.1.0's 5 %: 10 % of the value at the value, steeper when overpriced",
			FR.fee(10000, 1, 10000) == 1000 and FR.fee(10000, 1, 20000) == 1791 and FR.fee(10000, 1, 5000) == 896)
		check("fee: a stack pays for every unit", FR.fee(120, 60, 120 * 60) == 720)
		check("offer slots by rating (EFT wiki's table, negative ratings too)", FR.slots(0.19) == 1 and FR.slots(0.2) == 2 and FR.slots(7) == 3
			and FR.slots(30) == 4 and FR.slots(60) == 5 and FR.slots(100) == 6 and FR.slots(150) == 8 and FR.slots(1000) == 10 and FR.slots(-3) == 1)
		check("rating: +0.02 per 100,000 sold (to 50M a sale), -0.03 per 100,000 unsold (to 30M an offer; EFT's settings)",
			near(FR.ratingGain(50000), 0.01) and near(FR.ratingGain(1e9), 10) and near(FR.ratingLoss(100000), 0.03) and near(FR.ratingLoss(1e9), 9))
		local real = true
		for id in FR.LIST_LIMIT do
			real = real and Items.defs[id] ~= nil and FR.tradeable(id)
		end
		check("listing limits: every limited id is a real, tradeable item", real)
		check("EFT 1.0.4.0: rounds only in full stacks", FR.listable("A62_FMJ", Items.defs.A62_FMJ.stack) == true and select(2, FR.listable("A62_FMJ", 1)) == "FULL_STACK" and FR.listable("LEDX", 1) == true)
		local all = FR.offersFor("A62_FMJ", 77)
		local f0, f1, fn = FR.aiFloor("A62_FMJ", 77, 0), FR.aiFloor("A62_FMJ", 77, 1), FR.aiFloor("A62_FMJ", 77, #all)
		check("AI floor: every operator with no player offer, one fewer per player offer, none once players offer as many; the cheapest step aside",
			#f0 == #all and #f1 == math.max(0, #all - 1) and #fn == 0 and (#all < 2 or f1[1].price == all[2].price))
		check("AI buyers: nothing above the going rate, faster the cheaper",
			FR.aiBuyRate(101, 100) == 0 and FR.aiBuyRate(100, 100) > 0 and FR.aiBuyRate(85, 100) > FR.aiBuyRate(100, 100) and FR.aiBuyRate(70, 100) > FR.aiBuyRate(85, 100))
		check("AI sellers have a fixed rating per name", FR.aiRating("Kestrel") == FR.aiRating("Kestrel") and FR.aiRating("Kestrel") >= 20)
		-- the index codec and the memory budget: the longest offer row and a full entry
		local long = {}
		for i = 1, FR.MAX_PER_ITEM do
			table.insert(long, { o = "99999999999-" .. (999900 + i), p = 999999999, n = 9999, e = 1999999999, r = 9999.99, nm = string.rep("W", 20), pk = true })
		end
		local aiFull = { [1] = 9999, [2] = 9999, [3] = 9999, [4] = 9999 }
		local s = FR.encodeEntry({ w = 9999999, a = aiFull, o = long })
		local per = (#s - #FR.encodeEntry({ w = 9999999, a = aiFull, o = {} })) / FR.MAX_PER_ITEM
		check(string.format("quota: the longest offer row is %d bytes, a full entry (%d offers) %d bytes, under Roblox's 32 KB", math.floor(per), FR.MAX_PER_ITEM, #s), per <= 80 and #s < FR.ENTRY_LIMIT)
		local d = FR.decodeEntry(s)
		check("index codec: a round trip keeps every field", #d.o == FR.MAX_PER_ITEM and d.o[1].p == 999999999 and d.o[1].pk == true
			and d.o[1].nm == string.rep("W", 20) and d.a[4] == 9999 and near(d.o[1].r, 9999.99) and d.w == 9999999)
		check("index codec: garbage reads as an empty entry", #FR.decodeEntry("x|y").o == 0 and #FR.decodeEntry(nil).o == 0 and #FR.decodeEntry("1|0||bad;1-1,2,3").o == 0)
		check("offer ids: the seller is the user id before the dash", FR.sellerOf("123-4") == 123 and FR.sellerOf("x-1") == nil and FR.sellerOf(string.rep("1", 30) .. "-1") == nil)
		check("purchases need the category's level (EFT 1.0): an assault rifle at 25", FR.canBuy("R17_RIFLE", 24) == false and FR.canBuy("R17_RIFLE", 25) == true)
	end)

	-- ── listing ──────────────────────────────────────────────────────────────────────────────────────────────────
	section("listing", function()
		local W = world()
		local A = W.server()
		local seller = { uid = 101, name = "Seller_A" }
		local p = holder(1000000)
		local g = put(p, "R17_RIFLE", 1, true)
		local res = list(A, seller, p, g, 9000)
		local fee = FR.fee(Items.defs.R17_RIFLE.value, 1, 9000)
		local oid = res.data and res.data.k
		local book = A.S:book(101)
		local e = A.S:entry("R17_RIFLE", 0)
		check("list: the fee is paid, the item leaves the stash for the seller's book and shows in the index",
			res.ok and p.money == 1000000 - fee and p.items[g] == nil and book.o[oid] ~= nil and book.o[oid].b ~= nil and e ~= nil and #e.o == 1 and e.o[1].o == oid and e.o[1].nm == "Seller_A")
		local st = Flea.stateFor(p)
		check("list: MY OFFERS mirrors it (price, time left, open)", p.flea.offers[oid].st == "open" and p.flea.offers[oid].b == nil and #st.offers == 1 and st.offers[1].price == 9000 and st.offers[1].left > 0 and st.offers[1].st == "open")
		local g2, g3 = put(p, "R17_RIFLE", 1, true), put(p, "R17_RIFLE", 1, true)
		local r2, r3 = list(A, seller, p, g2, 9000), list(A, seller, p, g3, 9000)
		check("list: two offer slots at the starting rating; the third is refused and the item stays", r2.ok and not r3.ok and r3.code == "NO_SLOTS" and p.items[g3] ~= nil)
		local q = holder(10000000)
		q.flea = { rating = 1000, offers = {}, n = 0 }
		local sellerB = { uid = 102, name = "Seller_B" }
		local gNF, gBan, gAmmo, gBag = put(q, "R17_RIFLE", 1, false), put(q, "ARMOR_C6", 1, true), put(q, "A62_FMJ", 59, true), put(q, "BAG_SLING", 1, true)
		local ig, iit = Inv.newItem("BOLTS", 1, { fir = true })
		Inv.place(q, ig, iit, { gBag })
		local codes = {}
		for _, gg in { gNF, gBan, gAmmo, gBag } do
			table.insert(codes, tostring(list(A, sellerB, q, gg, 1000).code))
		end
		check("list: not found in raid, banned, a short ammo stack (EFT 1.0.4.0) and a full bag are refused (" .. table.concat(codes, ",") .. ")",
			codes[1] == "NOT_FIR" and codes[2] == "BANNED" and codes[3] == "FULL_STACK" and codes[4] == "NOT_EMPTY")
		local okN, lastCode = 0, nil
		for _ = 1, 6 do
			local r = list(A, sellerB, q, put(q, "LEDX", 1, true), 900000)
			if r.ok then
				okN += 1
			else
				lastCode = r.code
			end
		end
		check("list: EFT's listing limit, five LEDX on the market at a time", okN == 5 and lastCode == "LIMIT")
		check("list: only from the stash", list(A, sellerB, q, "nope", 5).code == "NO_ITEM")
		local full = holder(10)
		check("list: the fee must be paid", list(A, { uid = 103, name = "Poor" }, full, put(full, "R17_RIFLE", 1, true), 9000).code == "NOT_ENOUGH_MONEY")
	end)

	-- ── buying, the shop window, the seller's mailbox ───────────────────────────────────────────────────────────
	section("buy", function()
		local W = world()
		local A, B = W.server(), W.server()
		local S, Bu = { uid = 201, name = "Seller" }, { uid = 202, name = "Buyer" }
		local ps, pb = holder(1000000), holder(1000000)
		local oid = list(A, S, ps, put(ps, "R17_RIFLE", 1, true), 9000).data.k
		local m0 = ps.money
		local row, all = rowOf(B, pb, Bu, "R17_RIFLE", oid)
		local sorted, ai = true, 0
		for i, r in all do
			sorted = sorted and (i == 1 or r.unit >= all[i - 1].unit)
			if r.ai then
				ai += 1
			end
		end
		check("market: another server shows the offer with the seller's name and rating among the operators, cheapest first",
			row ~= nil and row.seller == "Seller" and near(row.r, 0.2) and row.left == 1 and sorted and ai == #FR.aiFloor("R17_RIFLE", FleaStore.window(W.t), 1))
		local own = rowOf(A, ps, S, "R17_RIFLE", oid)
		check("market: the seller sees it as their own, and cannot buy it", own ~= nil and own.mine == true and buy(A, S, ps, "R17_RIFLE", oid, 1).code == "OWN_OFFER")
		check("buy: an assault rifle needs level 25 (greyed out below)", buy(B, Bu, pb, "R17_RIFLE", oid, 1, 24).code == "LOCKED")
		local r = buy(B, Bu, pb, "R17_RIFLE", oid, 1)
		local n, fir = units(pb, "R17_RIFLE")
		check("buy: the buyer pays and gets the item, not found in raid", r.ok and pb.money == 1000000 - 9000 and n == 1 and fir == 0 and next(pb.flea.buys) == nil and next(pb.flea.acks) == nil)
		local book = B.S:book(201)
		local sale
		for _, s in book.s do
			sale = s
		end
		check("buy: the seller's book holds the sale (acknowledged by the buyer's server, its item gone) until the seller is paid",
			sale ~= nil and sale.m == 9000 and sale.gt == true and sale.b == nil and not sale.pd and book.o[oid] == nil)
		check("buy: the offer leaves the shop window", rowOf(B, pb, Bu, "R17_RIFLE", oid) == nil)
		check("buy: someone who comes second is told so", buy(B, { uid = 203, name = "Late" }, holder(100000), "R17_RIFLE", oid, 1).code == "SOLD")
		-- the seller was offline: their next server (a fresh one) pays them from the book
		local C = W.server()
		local _, sold = Flea.collect(C, S, ps)
		check("mailbox: the seller's next collect pays the sale once, with the rating and Ragman's (TILDA's) message",
			sold == 1 and ps.money == m0 + 9000 and near(ps.flea.rating, 0.2 + FR.ratingGain(9000)) and lastMsg(ps).f == "tilda" and string.find(lastMsg(ps).x, "bought by Buyer", 1, true) ~= nil)
		local _, sold2 = Flea.collect(C, S, ps)
		check("mailbox: collecting again pays nothing more and settles the book", sold2 == 0 and ps.money == m0 + 9000 and next(C.S:book(201).s) == nil and next(ps.flea.got) == nil and next(ps.flea.offers) == nil)
		-- a crash after the credit was saved and before the book was settled: the saved profile does not take it twice
		local W2 = world()
		local A2 = W2.server()
		local ps2, pb2 = holder(1000000), holder(1000000)
		local oid2 = list(A2, S, ps2, put(ps2, "R17_RIFLE", 1, true), 9000).data.k
		buy(A2, Bu, pb2, "R17_RIFLE", oid2, 1)
		local before = ps2.money
		Flea.collect(A2, S, ps2)
		local again = Util.copy(W2.saves[201])
		local D = W2.server()
		local _, soldD = Flea.collect(D, S, again)
		check("mailbox: a server dying after the credit is saved does not pay it twice", again.money == before + 9000 and soldD == 0 and next(D.S:book(201).s) == nil)
		-- the save of the credit fails and the server dies: the last good save gets it once
		local W3 = world()
		local A3 = W3.server()
		local ps3, pb3 = holder(1000000), holder(1000000)
		local oid3 = list(A3, S, ps3, put(ps3, "R17_RIFLE", 1, true), 9000).data.k
		buy(A3, Bu, pb3, "R17_RIFLE", oid3, 1)
		local good = Util.copy(W3.saves[201])
		local m3 = ps3.money
		W3.failSave = true
		Flea.collect(A3, S, ps3)
		Flea.collect(A3, S, ps3) -- the save keeps failing: the credit must stay unsettled and not be paid again
		local settled = W3.b.books["b201"].val.s
		local stillOwed = false
		for _, s in settled do
			stillOwed = stillOwed or not s.pd
		end
		W3.failSave = false
		local E = W3.server()
		local _, soldE = Flea.collect(E, S, good)
		check("mailbox: an unsaved credit is paid once in memory and never settled in the book; the last good save collects it once",
			ps3.money == m3 + 9000 and stillOwed and soldE == 1 and good.money == ps3.money)
	end)

	-- ── partial purchases and packs ──────────────────────────────────────────────────────────────────────────────
	section("partial", function()
		local W = world()
		local A, B = W.server(), W.server()
		local S, Bu = { uid = 301, name = "Ammo_Guy" }, { uid = 302, name = "Shooter" }
		local ps, pb = holder(1000000), holder(1000000)
		local stack = Items.defs.A62_FMJ.stack
		local oid = list(A, S, ps, put(ps, "A62_FMJ", stack, true), 130).data.k
		local r1 = buy(B, Bu, pb, "A62_FMJ", oid, 20)
		local row = rowOf(B, pb, Bu, "A62_FMJ", oid)
		local n1 = units(pb, "A62_FMJ")
		check("partial: 20 of a stack at the price per round; the rest stays on offer", r1.ok and pb.money == 1000000 - 20 * 130 and n1 == 20 and row ~= nil and row.left == stack - 20)
		check("partial: more than is left is refused", buy(B, Bu, pb, "A62_FMJ", oid, stack).code == "SHORT")
		local r2 = buy(B, Bu, pb, "A62_FMJ", oid, stack - 20)
		local n2, fir2 = units(pb, "A62_FMJ")
		Flea.collect(A, S, ps)
		local _, soldAgain = Flea.collect(A, S, ps)
		check("partial: the last rounds end the offer; the seller is paid for both sales, once", r2.ok and n2 == stack and fir2 == 0 and soldAgain == 0 and next(ps.flea.offers) == nil
			and near(ps.flea.rating, 0.2 + FR.ratingGain(20 * 130) + FR.ratingGain((stack - 20) * 130)))
		local pk = list(A, S, ps, put(ps, "A62_FMJ", stack, true), 7000, true).data.k
		local C = W.server() -- a server that has not cached the item yet (B's view is up to a minute old)
		local prow = rowOf(C, pb, Bu, "A62_FMJ", pk)
		check("pack: EFT's 'List as a pack' shows one price for the whole stack and refuses part of it",
			prow ~= nil and prow.pk == true and prow.price == 7000 and buy(C, Bu, pb, "A62_FMJ", pk, 10).code == "PACK")
		local m = pb.money
		local r3 = buy(C, Bu, pb, "A62_FMJ", pk, stack)
		check("pack: bought whole at the pack's price", r3.ok and pb.money == m - 7000)
	end)

	-- ── two buyers on two servers at once ───────────────────────────────────────────────────────────────────────
	section("race", function()
		local W = world()
		local A, B, Sv = W.server(), W.server(), W.server()
		local S = { uid = 401, name = "Seller" }
		local ps = holder(1000000)
		ps.flea = { rating = 1000, offers = {}, n = 0 } -- room for three offers
		local oid = list(Sv, S, ps, put(ps, "R17_RIFLE", 1, true), 9000).data.k
		local pa, pb = holder(100000), holder(100000)
		local rb
		-- server B's whole purchase lands between server A's claim and its commit
		W.b.hook = function(kind)
			if kind == "book" then
				rb = buy(B, { uid = 403, name = "Bea" }, pb, "R17_RIFLE", oid, 1)
			end
		end
		local ra = buy(A, { uid = 402, name = "Abe" }, pa, "R17_RIFLE", oid, 1)
		local na, nb = units(pa, "R17_RIFLE"), units(pb, "R17_RIFLE")
		local sales = size(Sv.S:book(401).s)
		check("race: two buyers on two servers, one rifle: only one gets it, the other is told and refunded",
			rb and rb.ok and not ra.ok and ra.code == "SOLD" and na + nb == 1 and nb == 1 and pa.money == 100000 and pb.money == 100000 - 9000 and sales == 1)
		-- partial: 40 and 30 of 60 at once
		local stack = Items.defs.A62_FMJ.stack
		local oid2 = list(Sv, S, ps, put(ps, "A62_FMJ", stack, true), 100).data.k
		local pc, pd = holder(100000), holder(100000)
		local rd
		W.b.hook = function(kind)
			if kind == "book" then
				rd = buy(B, { uid = 405, name = "Dee" }, pd, "A62_FMJ", oid2, 30)
			end
		end
		local rc = buy(A, { uid = 404, name = "Cal" }, pc, "A62_FMJ", oid2, stack - 20)
		check("race: two partial purchases that do not both fit: the second is told how many are left, nothing is lost",
			rd and rd.ok and not rc.ok and rc.code == "SHORT" and units(pd, "A62_FMJ") == 30 and units(pc, "A62_FMJ") == 0 and pc.money == 100000 and Sv.S:book(401).o[oid2].n == stack - 30)
		-- REMOVE while someone buys: EFT keeps the offer up 72 s, so the purchase still goes through
		local oid3 = list(Sv, S, ps, put(ps, "R17_RIFLE", 1, true), 9000).data.k
		local pe = holder(100000)
		local rr
		W.b.hook = function(kind)
			if kind == "book" then
				rr = Flea.handle(Sv, S, ps, { op = "remove", k = oid3 }, LVL)
			end
		end
		local re = buy(A, { uid = 406, name = "Eve" }, pe, "R17_RIFLE", oid3, 1)
		check("race: REMOVE during a purchase: the removal holds the offer 72 s (EFT), the purchase goes through", rr and rr.ok and re.ok and units(pe, "R17_RIFLE") == 1)
	end)

	-- ── REMOVE, expiry and returns ───────────────────────────────────────────────────────────────────────────────
	section("returns", function()
		local W = world()
		local A, B = W.server(), W.server()
		local S = { uid = 501, name = "Seller" }
		local ps = holder(1000000)
		local stack = Items.defs.A62_FMJ.stack
		local oid = list(A, S, ps, put(ps, "A62_FMJ", stack, true), 130).data.k
		local rr = Flea.handle(A, S, ps, { op = "remove", k = oid }, LVL)
		check("remove: the offer ends 72 s later (EFT's offerDurationTimeInHourAfterRemove) and shows REMOVING", rr.ok and rr.data.ends == FR.REMOVE_DELAY and Flea.stateFor(ps).offers[1].st == "removing")
		local pb = holder(100000)
		local rb = buy(B, { uid = 502, name = "Quick" }, pb, "A62_FMJ", oid, 10)
		W.t += FR.REMOVE_DELAY + 1
		local rl = buy(B, { uid = 503, name = "Slow" }, holder(100000), "A62_FMJ", oid, 10)
		check("remove: a claim on the seller's book after the end is refused even if a server still shows the offer",
			B.S:claim(501, oid, "503-77", 1, { uid = 503, name = "Slow" }, W.t) == "gone")
		local rating0 = ps.flea.rating
		local _, sold, back = Flea.collect(A, S, ps)
		local n, fir = units(ps, "A62_FMJ")
		check("remove: bought within the 72 s, gone after; the unsold rounds come back found in raid; the fee stays paid",
			rb.ok and rl.code == "SOLD" and sold == 1 and back == 1 and n == stack - 10 and fir == stack - 10 and next(ps.flea.offers) == nil)
		check("remove: the unsold value costs rating, the sale earned some (EFT)", near(ps.flea.rating, rating0 + FR.ratingGain(10 * 130) - FR.ratingLoss((stack - 10) * 130)))
		check("remove: Ragman's (TILDA's) message says so", lastMsg(ps).f == "tilda" and string.find(lastMsg(ps).x, "was removed", 1, true) ~= nil)
		-- expiry after 12 h, with no room in the stash: the item waits in MY OFFERS for 72 h
		local q = holder(1000000)
		local SQ = { uid = 504, name = "Full_Stash" }
		q.stashH = 2
		local oid2 = list(A, SQ, q, put(q, "R17_RIFLE", 1, true), 50000).data.k
		put(q, "R17_RIFLE", 1, false)
		put(q, "R17_RIFLE", 1, false)
		W.t += FR.DURATION + 5
		local _, _, back2 = Flea.collect(A, SQ, q)
		local st = Flea.stateFor(q)
		check("expiry: after 12 h the offer ends; with the stash full the item waits in MY OFFERS (72 h), Ragman says it expired",
			back2 == 1 and #st.back == 1 and st.back[1].id == "R17_RIFLE" and string.find(lastMsg(q).x, "has expired", 1, true) ~= nil and next(q.flea.offers) == nil and oid2 ~= nil)
		check("expiry: RECEIVE waits for room", Flea.handle(A, SQ, q, { op = "receive" }, LVL).code == "NO_SPACE")
		for g in q.grids.stash do
			if q.items[g] and not q.items[g].fir then
				Inv.take(q, g)
				break
			end
		end
		local rcv = Flea.handle(A, SQ, q, { op = "receive" }, LVL)
		local nq, fq = units(q, "R17_RIFLE")
		check("expiry: RECEIVE brings it to the stash, still found in raid", rcv.ok and rcv.data.got == 1 and nq == 2 and fq == 1 and next(q.flea.back) == nil)
		-- the 72 h storage time
		local r = holder(1000000)
		local SR = { uid = 505, name = "Away" }
		r.stashH = 2
		list(A, SR, r, put(r, "R17_RIFLE", 1, true), 50000)
		put(r, "R17_RIFLE", 1, false)
		put(r, "R17_RIFLE", 1, false)
		W.t += FR.DURATION + 5
		Flea.collect(A, SR, r)
		local waiting = size(r.flea.back)
		W.t += FR.RETURN_HOLD + 1
		Flea.expireBack(r, W.t)
		check("expiry: a returned item left past 72 h is gone, with a message (EFT)", waiting == 1 and size(r.flea.back) == 0 and string.find(lastMsg(r).x, "gone", 1, true) ~= nil)
	end)

	-- ── a server dying in the middle of a purchase ───────────────────────────────────────────────────────────────
	section("crash", function()
		local W = world()
		local Sv = W.server()
		local S, Bu = { uid = 601, name = "Seller" }, { uid = 602, name = "Buyer" }
		local ps = holder(1000000)
		ps.flea = { rating = 1000, offers = {}, n = 0 } -- ten offer slots
		local oid = list(Sv, S, ps, put(ps, "R17_RIFLE", 1, true), 9000).data.k
		-- dies after holding the money, before the claim
		local pb = holder(100000)
		local r1 = buy(W.server(crashAt("afterHold")), Bu, pb, "R17_RIFLE", oid, 1)
		local saved = Util.copy(W.saves[602])
		local held = saved.money == 100000 - 9000 and size(saved.flea.buys) == 1
		local pid
		for k in saved.flea.buys do
			pid = k
		end
		Flea.collect(W.server(), Bu, saved)
		local late = W.server().S:claim(601, oid, pid, 1, { uid = 602, name = "Buyer" }, W.t)
		check("crash before the claim: the saved order is voided, the money comes back, the offer stays, a late claim cannot land",
			r1.code == "SERVER_ERROR" and held and saved.money == 100000 and next(saved.flea.buys) == nil and Sv.S:book(601).o[oid] ~= nil and late == "void"
				and string.find(lastMsg(saved).x, "did not go through", 1, true) ~= nil)
		-- dies after the claim, before the delivery is saved
		local pc = holder(100000)
		local Bc = { uid = 607, name = "Buyer2" }
		local r2 = buy(W.server(crashAt("afterClaim")), Bc, pc, "R17_RIFLE", oid, 1)
		local saved2 = Util.copy(W.saves[607])
		local R = W.server()
		Flea.collect(R, Bc, saved2)
		local n2, fir2 = units(saved2, "R17_RIFLE")
		local s2
		for _, s in R.S:book(601).s do
			s2 = s
		end
		Flea.collect(R, Bc, saved2)
		check("crash after the claim: the next server delivers it once (not found in raid) and acknowledges it",
			r2.code == "SERVER_ERROR" and n2 == 1 and fir2 == 0 and saved2.money == 100000 - 9000 and next(saved2.flea.buys) == nil and s2 ~= nil and s2.gt == true and units(saved2, "R17_RIFLE") == 1)
		local _, soldS = Flea.collect(W.server(), S, ps)
		check("crash after the claim: the seller is paid once", soldS == 1 and ps.money == 1000000 - FR.fee(Items.defs.R17_RIFLE.value, 1, 9000) + 9000)
		-- the claim lands but its reply is lost: the purchase waits (PENDING) and the next collect finishes it
		local oid4 = list(Sv, S, ps, put(ps, "R17_RIFLE", 1, true), 9000).data.k
		local B4 = W.server()
		local pd = holder(100000)
		W.b.loseReply = 1
		local r4 = buy(B4, { uid = 603, name = "Lag" }, pd, "R17_RIFLE", oid4, 1)
		local pendingOk = r4.code == "PENDING" and pd.money == 100000 - 9000 and units(pd, "R17_RIFLE") == 0
		Flea.collect(B4, { uid = 603, name = "Lag" }, pd)
		check("lost reply: the money stays held (PENDING), then the purchase finishes once", pendingOk and units(pd, "R17_RIFLE") == 1 and pd.money == 100000 - 9000 and next(pd.flea.buys) == nil)
		-- dies after saving the delivery, before the acknowledgement
		local oid5 = list(Sv, S, ps, put(ps, "R17_RIFLE", 1, true), 9000).data.k
		local pe = holder(100000)
		buy(W.server(crashAt("afterDeliver")), { uid = 604, name = "Ack" }, pe, "R17_RIFLE", oid5, 1)
		local saved5 = Util.copy(W.saves[604])
		local owed = size(saved5.flea.acks) == 1
		Flea.collect(W.server(), { uid = 604, name = "Ack" }, saved5)
		local gt = false
		for _, s in W.b.books["b601"].val.s do
			gt = gt or s.gt == true
		end
		check("crash before the acknowledgement: the saved profile still owes it and sends it later; no second delivery",
			owed and next(saved5.flea.acks) == nil and gt and units(saved5, "R17_RIFLE") == 1)
		-- the store does not answer at the claim: PENDING, then refunded when it was never claimed
		local oid6 = list(Sv, S, ps, put(ps, "R17_RIFLE", 1, true), 9000).data.k
		local pf = holder(100000)
		local B6 = W.server()
		W.b.failBook = 1
		local r6 = buy(B6, { uid = 605, name = "Down" }, pf, "R17_RIFLE", oid6, 1)
		Flea.collect(B6, { uid = 605, name = "Down" }, pf)
		check("store down at the claim: PENDING, then the money comes back and the offer is still there",
			r6.code == "PENDING" and pf.money == 100000 and units(pf, "R17_RIFLE") == 0 and Sv.S:book(601).o[oid6] ~= nil)
		-- a listing that dies after its save: the next collect puts it up once
		local pg = holder(1000000)
		local SL = { uid = 606, name = "Lister" }
		list(W.server(crashAt("afterListSave")), SL, pg, put(pg, "R17_RIFLE", 1, true), 9000)
		local saved7 = Util.copy(W.saves[606])
		local newOne = false
		for _, o in saved7.flea.offers do
			newOne = o.st == "new" and o.b ~= nil
		end
		local R7 = W.server()
		Flea.collect(R7, SL, saved7)
		Flea.collect(R7, SL, saved7)
		local inBook = size(R7.S:book(606).o)
		local open = false
		for k, o in saved7.flea.offers do
			open = o.st == "open" and o.b == nil and rowOf(W.server(), holder(), Bu, "R17_RIFLE", k) ~= nil
		end
		check("crash while listing: the saved offer goes up once at the next collect", newOne and inBook == 1 and open)
	end)

	-- ── the AI floor and the AI buyers ───────────────────────────────────────────────────────────────────────────
	section("ai", function()
		local W = world()
		local A = W.server()
		local pv = holder()
		local id = "A62_FMJ"
		local mk = Flea.market(pv, { id }, A).offers[id]
		local allAi = #mk > 0
		for _, r in mk do
			allAi = allAi and r.ai == true
		end
		local count = #FR.offersFor(id, FleaStore.window(W.t))
		check("AI floor: an item nobody offers shows the operators' offers", allAi and #mk == count)
		local stack = Items.defs[id].stack
		for i = 1, count do
			local s = { uid = 700 + i, name = "P" .. i }
			local p = holder()
			list(A, s, p, put(p, id, stack, true), 200)
		end
		local mk2 = Flea.market(pv, { id }, W.server()).offers[id]
		local ai2 = 0
		for _, r in mk2 do
			if r.ai then
				ai2 += 1
			end
		end
		check("AI floor: once players offer as many, the operators step aside", ai2 == 0 and #mk2 == count)
		-- AI buyers: an overpriced offer never sells, the cheapest fair one does, one undercut does not
		local W2 = world()
		local A2 = W2.server()
		W2.roll = 0 -- every roll that has a chance succeeds
		local mp = FR.marketPrice("R17_RIFLE")
		local dear = { uid = 711, name = "Dear" }
		local pdear = holder()
		list(A2, dear, pdear, put(pdear, "R17_RIFLE", 1, true), math.floor(mp * 1.2))
		local cheap, under = { uid = 712, name = "Cheap" }, { uid = 713, name = "Under" }
		local pch, pun = holder(), holder()
		local oidC = list(A2, cheap, pch, put(pch, "R17_RIFLE", 1, true), math.floor(mp * 0.5)).data.k
		list(A2, under, pun, put(pun, "R17_RIFLE", 1, true), math.floor(mp * 0.6))
		W2.t += 600
		local _, soldDear = Flea.collect(A2, dear, pdear)
		local _, soldUnder = Flea.collect(A2, under, pun)
		local _, soldCheap = Flea.collect(A2, cheap, pch)
		check("AI buyers: an offer at 1.2x the going rate does not sell, nor one undercut by another player; the cheapest fair one does",
			soldDear == 0 and soldUnder == 0 and soldCheap == 1 and string.find(lastMsg(pch).x, "were bought by", 1, true) ~= nil and pch.money == 10000000 - FR.fee(Items.defs.R17_RIFLE.value, 1, math.floor(mp * 0.5)) + math.floor(mp * 0.5))
		local _, soldDear2 = Flea.collect(A2, dear, pdear)
		W2.t += FR.DURATION
		local _, soldDear3, backDear = Flea.collect(A2, dear, pdear)
		check("AI buyers: twelve hours later the overpriced offer still has not sold and comes back", soldDear2 == 0 and soldDear3 == 0 and backDear == 1 and oidC ~= nil)
		-- the operators' stock is one for every server
		local W3 = world()
		local S1, S2 = W3.server(), W3.server()
		local rows = Flea.market(holder(), { id }, S1).offers[id]
		local a = rows[1]
		local b1 = Flea.handle(S1, { uid = 721, name = "One" }, holder(), { op = "buy", id = id, i = a.i, n = a.left - 1, price = a.price }, LVL)
		local b2 = Flea.handle(S2, { uid = 722, name = "Two" }, holder(), { op = "buy", id = id, i = a.i, n = 2, price = a.price }, LVL)
		local b3 = Flea.handle(S2, { uid = 722, name = "Two" }, holder(), { op = "buy", id = id, i = a.i, n = 1, price = a.price }, LVL)
		local left = 99
		for _, r in Flea.market(holder(), { id }, W3.server()).offers[id] do
			if r.ai and r.i == a.i then
				left = r.left
			end
		end
		check("AI floor: an operator's stock is shared by every server (no more per-server stock, audit economy.25)", b1.ok and b2.code == "SHORT" and b3.ok and left == 0)
		check("AI floor: a price from an old window is refused (the list refreshes)", Flea.handle(S2, { uid = 723, name = "Old" }, holder(), { op = "buy", id = id, i = a.i, n = 1, price = a.price + 1 }, LVL).code == "CHANGED")
	end)

	-- ── the index (MemoryStore) losing or lagging, MemoryStore down, the memory quota ─────────────────────────────
	section("index", function()
		local W = world()
		local A = W.server()
		local S = { uid = 801, name = "Seller" }
		local ps = holder()
		local oid = list(A, S, ps, put(ps, "R17_RIFLE", 1, true), 9000).data.k
		W.b.idx["R17_RIFLE"] = nil -- MemoryStore lost the entry
		local gone = rowOf(W.server(), holder(), { uid = 1, name = "x" }, "R17_RIFLE", oid) == nil
		Flea.collect(W.server(), S, ps, { republish = true })
		check("index: a lost entry hides the offer; the seller's server puts it back (the escrow is the truth)", gone and rowOf(W.server(), holder(), { uid = 1, name = "x" }, "R17_RIFLE", oid) ~= nil)
		local B = W.server()
		B.S:addOffer("R17_RIFLE", { o = "999-1", p = 10, n = 1, e = W.t + 3600, r = 0.2, nm = "Ghost" })
		local pb = holder(100000)
		local rg = buy(B, { uid = 802, name = "Fooled" }, pb, "R17_RIFLE", "999-1", 1)
		check("index: a stale offer the book does not hold cannot be bought; the buyer keeps the money and the row goes",
			rg.code == "SOLD" and pb.money == 100000 and rowOf(B, holder(), { uid = 1, name = "x" }, "R17_RIFLE", "999-1") == nil)
		-- an index row that shows a lower price than the book: the claim never takes more than the buyer put aside
		local e = FR.decodeEntry(W.b.idx["R17_RIFLE"].val)
		for _, o in e.o do
			if o.o == oid then
				o.p = 10
			end
		end
		W.b.idx["R17_RIFLE"].val = FR.encodeEntry(e)
		local pz = holder(100000)
		local rz = buy(W.server(), { uid = 808, name = "Bargain" }, pz, "R17_RIFLE", oid, 1)
		check("index: a wrong (cheaper) price in the index is refused by the book; the buyer keeps the money",
			rz.code == "CHANGED" and pz.money == 100000 and units(pz, "R17_RIFLE") == 0 and A.S:book(801).o[oid] ~= nil)
		-- the DataStore write budget runs low: trades wait (BUSY) before any money is held
		local lowB = FleaStore.memoryBackend(W.now)
		lowB.canWrite = function()
			return false
		end
		local pl = holder(100000)
		check("budget: with the server's DataStore writes nearly spent the market says BUSY and holds nothing",
			buy(W.server(nil, lowB), { uid = 809, name = "Wait" }, pl, "R17_RIFLE", oid, 1).code == "BUSY" and pl.money == 100000 and pl.flea == nil)
		-- the index refuses a write (an error): the offer stays in escrow and goes on show at the seller's next look
		W.b.failIdx = 1
		local p2 = holder()
		local S2 = { uid = 807, name = "Seller2" }
		local r2 = list(A, S2, p2, put(p2, "R17_RIFLE", 1, true), 9100)
		local k2 = r2.data and r2.data.k
		local hidden = rowOf(W.server(), holder(), { uid = 1, name = "x" }, "R17_RIFLE", k2) == nil
		Flea.collect(W.server(), S2, p2, { republish = true })
		check("index: a failed index write keeps the offer in escrow and shows it later", r2.ok and hidden and rowOf(W.server(), holder(), { uid = 1, name = "x" }, "R17_RIFLE", k2) ~= nil)
		-- the memory quota: the listing is refused before anything is lost
		local W2 = world()
		local A2 = W2.server()
		W2.b.memLimit = W2.b.size() + 10
		local p3 = holder(1000000)
		local g3 = put(p3, "R17_RIFLE", 1, true)
		local r3 = list(A2, { uid = 803, name = "Full" }, p3, g3, 9000)
		local n3, f3 = units(p3, "R17_RIFLE")
		check("quota: at the memory quota a listing is refused, the item and the fee come back",
			r3.code == "MARKET_FULL" and p3.money == 1000000 and n3 == 1 and f3 == 1 and next(p3.flea.offers) == nil and next(A2.S:book(803).o) == nil)
		-- the Roblox backend with stand-in services: MemoryStore down, the server's own index serves; escrow works
		local dsData = {}
		local fakeDS = {}
		function fakeDS.UpdateAsync(_, key, fn)
			local new = fn(Util.copy(dsData[key]))
			if new ~= nil then
				dsData[key] = Util.copy(new)
			end
			return new
		end
		function fakeDS.GetAsync(_, key)
			return Util.copy(dsData[key])
		end
		local function boom()
			error("MemoryStore is down")
		end
		local badMap = { GetAsync = boom, UpdateAsync = boom, GetRangeAsync = boom, RemoveAsync = boom }
		local W3 = world()
		local rb = FleaStore.robloxBackend(function()
			return "DATASTORE"
		end, { ds = fakeDS, map = badMap, quiet = true, now = W3.now })
		local R = W3.server(nil, rb)
		local p4, p5 = holder(), holder(100000)
		local r4 = list(R, { uid = 804, name = "Local" }, p4, put(p4, "R17_RIFLE", 1, true), 9000)
		local k4 = r4.data and r4.data.k
		local seen = rowOf(R, p5, { uid = 805, name = "Here" }, "R17_RIFLE", k4) ~= nil
		local r5 = buy(R, { uid = 805, name = "Here" }, p5, "R17_RIFLE", k4, 1)
		check("fallback: with MemoryStore down this server's own index shows its offers and trades still go through the DataStore escrow",
			r4.ok and seen and r5.ok and units(p5, "R17_RIFLE") == 1 and dsData["b804"] ~= nil and rb.downUntil > 0)
		local off = FleaStore.robloxBackend(function()
			return "OFFLINE"
		end, { ds = fakeDS, map = badMap, quiet = true, now = W3.now })
		check("fallback: with the DataStore down (OFFLINE) the market refuses trades, reads still work",
			Flea.handle(W3.server(nil, off), { uid = 806, name = "Wait" }, holder(), { op = "buy", id = "R17_RIFLE", k = "804-1", n = 1 }, LVL).code == "MARKET_DOWN"
				and Flea.handle(W3.server(nil, off), { uid = 806, name = "Wait" }, holder(), { op = "market", ids = { "R17_RIFLE" } }, LVL).ok)
	end)

	-- ── offers from before economy-3a ────────────────────────────────────────────────────────────────────────────
	section("legacy", function()
		local W = world()
		local A = W.server()
		local p = holder(0)
		local b1 = Inv.take(p, put(p, "R17_RIFLE", 1, true))
		local b2 = Inv.take(p, put(p, "A62_FMJ", Items.defs.A62_FMJ.stack, true))
		p.flea = { rating = 0.5, n = 2, offers = {
			o1 = { id = "R17_RIFLE", n = 1, price = 9000, t = W.t - 3600, b = b1 },
			o2 = { id = "A62_FMJ", n = Items.defs.A62_FMJ.stack, price = 9000, t = W.t - FR.DURATION - 10, b = b2 },
		} }
		Flea.collect(A, { uid = 901, name = "Old" }, p)
		Flea.collect(A, { uid = 901, name = "Old" }, p)
		local book = A.S:book(901)
		local moved
		for _, o in book.o do
			moved = o
		end
		local n2, f2 = units(p, "A62_FMJ")
		check("old offers: a running one moves to the shared market at its price and end time; an ended one comes back; no rating change",
			moved ~= nil and moved.i == "R17_RIFLE" and moved.p == 9000 and moved.e == W.t - 3600 + FR.DURATION and n2 == Items.defs.A62_FMJ.stack and f2 == n2
				and near(p.flea.rating, 0.5) and p.flea.offers.o1 == nil and p.flea.offers.o2 == nil and size(p.flea.offers) == 1)
	end)

	-- ── payloads ─────────────────────────────────────────────────────────────────────────────────────────────────
	section("payloads", function()
		local W = world()
		local A = W.server()
		local who = { uid = 990, name = "Hacker" }
		local p = holder()
		local big = {}
		for i = 1, Flea.MAX_IDS + 1 do
			big[i] = "R17_RIFLE"
		end
		local bad = {
			{ op = 5 }, {}, { op = "nope" },
			{ op = "buy", id = 5, k = "1-1", n = 1 }, { op = "buy", id = "R17_RIFLE", k = "1-1", n = 0 / 0 }, { op = "buy", id = "R17_RIFLE", k = "1-1", n = -1 },
			{ op = "buy", id = "R17_RIFLE", k = "1-1", n = math.huge }, { op = "buy", id = "R17_RIFLE", n = 1 }, { op = "buy", id = "R17_RIFLE", k = "1-1", i = 1, n = 1 },
			{ op = "buy", id = "R17_RIFLE", k = "abc", n = 1 }, { op = "buy", id = "NOT_AN_ITEM", k = "1-1", n = 1 }, { op = "buy", id = "R17_RIFLE", i = 99, n = 1 },
			{ op = "buy", id = "R17_RIFLE", k = "1-1", n = 1, price = -3 },
			{ op = "list", g = "x", price = 0 / 0 }, { op = "list", g = "x", price = 0 }, { op = "list", g = "x", price = -5 }, { op = "list", g = "x", price = 1e12 },
			{ op = "list", g = string.rep("x", 41), price = 5 }, { op = "list", g = "x", price = 5, pk = "yes" }, { op = "list", price = 5 },
			{ op = "remove", k = string.rep("1", 30) }, { op = "remove" },
			{ op = "market", ids = "R17_RIFLE" }, { op = "market", ids = { 5 } }, { op = "market", ids = big },
			{ op = "receive", k = 5 },
		}
		local okAll, which = true, {}
		for i, pay in bad do
			local r = Flea.handle(A, who, p, pay, LVL)
			if r.code ~= "BAD_INPUT" then
				okAll = false
				table.insert(which, i .. "=" .. tostring(r.code))
			end
		end
		check("payloads: wrong types, NaN, infinite or negative numbers, long strings and unknown ops are refused" .. (#which > 0 and (" (" .. table.concat(which, " ") .. ")") or ""), okAll)
		check("payloads: nothing changed hands", p.money == 10000000 and next((p.flea or {}).offers or {}) == nil)
	end)

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T
