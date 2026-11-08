--!nonstrict
-- The flea market's store (decision economy-3a, "a real market with an AI floor"): one adapter over two backends.
--   * Escrow books (DataStore, the truth): one key per seller, "b<userId>", holding that seller's open offers with
--     the listed items, the sales not yet paid out or delivered, the returned items not yet collected, and tombstones.
--     Every change is one UpdateAsync on that key, so a purchase claims units atomically and can be re-run by its
--     purchase id after a crash; nothing is lost or duplicated if a server dies mid-trade.
--   * The index (MemoryStore sorted map, the shop window): one entry per item with its player offers (cheapest first)
--     and the AI floor's stock bought this window, so every server shows the same offers. It may lag or lose an entry:
--     a purchase always checks the seller's book, and the seller's server puts missing offers back.
-- When MemoryStoreService or DataStoreService cannot be used (an unpublished place, Studio without API access, errors)
-- the same calls run on in-server tables (FleaStore.memoryBackend), so the market still works on one server, in Studio
-- and in the tests (FleaTests runs two "servers" on one shared memory backend).
--
-- FREE-QUOTA BUDGET (create.roblox.com/docs/cloud-services/memory-stores, read 2026-11-08: memory 64 KB + 1.2 KB per
-- user for the whole game, decaying over 8 days after users leave; 1,000 + 120 request units per concurrent user a
-- minute, GetRangeAsync costing one unit per item returned; values up to 32 KB; expiry up to 45 days):
--   memory: an offer is at most ~75 bytes in its item's entry ("<user id>-<n>,<price>,<units>,<ends>,<rating>,<name>,
--     <pack>"; FleaTests checks the longest), an entry ~20 bytes more, at most FleaRules.MAX_PER_ITEM (40) offers an
--     item (3 KB < 32 KB). Offers are bounded by the sellers' slots (2 at the starting rating, 10 at most) and live 12 h.
--     The quota holds about 16 live offers for every user it counts (1.2 KB / 75 B): a 12-player server whose players
--     fill 4 slots each uses 3.6 KB of the 14.4 KB its players add; offline sellers' offers stay up to 12 h within the
--     8-day decay. At the quota, a new offer is refused (MARKET_FULL) before anything is taken from the player.
--   requests: per server, the whole index is read at most once a minute while someone has BROWSE open (one unit per
--     item with player offers or AI stock bought: at most ~400, usually tens), one entry read per purchase or listing
--     (cached 15 s), one UpdateAsync per listing, purchase, removal, AI-floor purchase and AI-buyer sale, and every
--     5 minutes one GetAsync per item of each online seller's offers (to put back a lost entry). A busy 12-player
--     server stays under ~500 units a minute against the 1,440 its players add; with no flea screen open it uses none.
--   DataStore (60 + 10 per player UpdateAsync a minute per server): one book update a minute per online seller with
--     offers, one per listing, removal and due expiry, two per purchase (claim, the buyer's acknowledgement) plus the
--     buyer's two profile saves; the market refuses new trades while fewer than DS_RESERVE writes are left (BUSY), so
--     profile saves always have room. No busy loops: Flea's loop wakes every 5 s and touches only players who are due.
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local FR = require(Shared.FleaRules)

local FleaStore = {}
FleaStore.__index = FleaStore
FleaStore.TOMB = 14 * 86400 -- tombstones (void purchase ids, listed offer ids) stay in a book this long (ours)
FleaStore.TTL = 60 -- the whole index is re-read at most this often per server (ours: the request budget above)
FleaStore.ENTRY_TTL = 15 -- one item's entry is re-read at most this often when buying or listing
FleaStore.DS_RESERVE = 30 -- DataStore writes left for the profile saves: below it the market says BUSY
FleaStore.DOWN = 60 -- after a MemoryStore error, use this server's own index this long before trying again

local function window(t)
	return math.floor(t / FR.WINDOW)
end
FleaStore.window = window

-- ── the in-server backend (Studio, tests, fallback) ─────────────────────────────────────────────────────────────
-- DataStore-like books and a MemoryStore-like sorted map in tables. UpdateAsync is optimistic, like Roblox's: the
-- transform reads a copy, and if another writer committed in between it runs again on the new value. Test hooks:
-- failBook / failIdx (the next N calls fail), loseReply (the next N book writes commit but answer with an error, like a
-- reply lost on the way), hook (a function run once between a transform and its commit, to play another server's
-- write into that gap), memLimit (bytes: a write that grows the index past it fails like Roblox's TotalMemoryOverLimit).
function FleaStore.memoryBackend(clock)
	local b = { kind = "memory", books = {}, idx = {}, now = clock or os.time, failBook = 0, failIdx = 0, loseReply = 0, hook = nil, memLimit = nil, calls = { book = 0, idx = 0, units = 0 } }
	local function size()
		local n = 0
		for k, e in b.idx do
			n += #k + #(e.val or "")
		end
		return n
	end
	b.size = size
	function b.bookUpdate(_, key, fn)
		b.calls.book += 1
		if b.failBook > 0 then
			b.failBook -= 1
			return false, "SIMULATED_FAILURE"
		end
		for _ = 1, 8 do
			local cur = b.books[key]
			local ver = cur and cur.v or 0
			local new = fn(cur and Util.copy(cur.val) or nil)
			if new == nil then
				return true
			end
			local h = b.hook
			if h then
				b.hook = nil
				h("book", key)
			end
			local now = b.books[key]
			if (now and now.v or 0) == ver then
				b.books[key] = { v = ver + 1, val = Util.copy(new) }
				if b.loseReply > 0 then
					b.loseReply -= 1
					return false, "SIMULATED_LOST_REPLY"
				end
				return true
			end
		end
		return false, "CONFLICT"
	end
	function b.bookGet(_, key)
		b.calls.book += 1
		if b.failBook > 0 then
			b.failBook -= 1
			return false, "SIMULATED_FAILURE"
		end
		local cur = b.books[key]
		return true, cur and Util.copy(cur.val) or nil
	end
	local function live(key)
		local e = b.idx[key]
		if e and e.exp <= b.now() then
			b.idx[key] = nil
			return nil
		end
		return e
	end
	function b.idxGet(_, key)
		b.calls.idx += 1
		b.calls.units += 1
		if b.failIdx > 0 then
			b.failIdx -= 1
			return false, "SIMULATED_FAILURE"
		end
		local e = live(key)
		return true, e and e.val or nil
	end
	function b.idxUpdate(_, key, fn, ttl)
		b.calls.idx += 1
		b.calls.units += 1
		if b.failIdx > 0 then
			b.failIdx -= 1
			return false, "SIMULATED_FAILURE"
		end
		for _ = 1, 8 do
			local cur = live(key)
			local ver = cur and cur.v or 0
			local new = fn(cur and cur.val or nil)
			if new == nil then
				return true
			end
			local h = b.hook
			if h then
				b.hook = nil
				h("idx", key)
			end
			local now = live(key)
			if (now and now.v or 0) == ver then
				if b.memLimit and size() - (now and (#key + #now.val) or 0) + #key + #new > b.memLimit and #new > (now and #now.val or 0) then
					return false, "TotalMemoryOverLimit"
				end
				b.idx[key] = { v = ver + 1, val = new, exp = b.now() + math.clamp(ttl or 60, 1, 3888000) }
				return true
			end
		end
		return false, "CONFLICT"
	end
	function b.idxRange(_, after, count)
		b.calls.idx += 1
		if b.failIdx > 0 then
			b.failIdx -= 1
			return false, "SIMULATED_FAILURE"
		end
		local keys = {}
		for k in b.idx do
			if live(k) and (after == nil or k > after) then
				table.insert(keys, k)
			end
		end
		table.sort(keys)
		local out = {}
		for i = 1, math.min(count, #keys) do
			table.insert(out, { key = keys[i], value = b.idx[keys[i]].val })
		end
		b.calls.units += math.max(1, #out)
		return true, out
	end
	function b.idxRemove(_, key)
		b.calls.idx += 1
		b.idx[key] = nil
		return true
	end
	b.usable = function()
		return true
	end
	return b
end

-- ── the Roblox backend ──────────────────────────────────────────────────────────────────────────────────────────
-- DataStore books (Config.FLEA_BOOK_LIVE, or _DEV in Studio, like the profiles' store) and the MemoryStore index
-- (Config.FLEA_INDEX_LIVE / _DEV). Every call is wrapped in pcall; a MemoryStore error switches the index to this
-- server's own tables for FleaStore.DOWN seconds (offers listed here stay visible here; the escrow is unaffected).
-- inject (FleaTests only): ds / map stand-ins for the GlobalDataStore and the sorted map, now (a clock), quiet.
function FleaStore.robloxBackend(storeMode, inject)
	inject = inject or {}
	local clock = inject.now or os.time
	local studio = RunService:IsStudio()
	local okD, ds = true, inject.ds
	if not ds then
		okD, ds = pcall(function()
			return DataStoreService:GetDataStore(studio and Config.FLEA_BOOK_DEV or Config.FLEA_BOOK_LIVE)
		end)
	end
	if not okD or not ds then
		return nil, "DATASTORE"
	end
	local okM, map = true, inject.map
	if not map then
		okM, map = pcall(function()
			return MemoryStoreService:GetSortedMap(studio and Config.FLEA_INDEX_DEV or Config.FLEA_INDEX_LIVE)
		end)
	end
	local fallback = FleaStore.memoryBackend(clock)
	local b = { kind = "roblox", map = okM and map or nil, downUntil = okM and 0 or math.huge, fallback = fallback, calls = { book = 0, idx = 0, units = 0 } }
	local function budgetOk()
		local ok, n = pcall(function()
			return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
		end)
		return not ok or n >= FleaStore.DS_RESERVE
	end
	function b.bookUpdate(_, key, fn)
		if not budgetOk() then
			return false, "BUDGET"
		end
		b.calls.book += 1
		local ok, err = pcall(function()
			ds:UpdateAsync(key, function(old)
				return fn(old)
			end)
		end)
		return ok, (not ok) and tostring(err) or nil
	end
	function b.bookGet(_, key)
		b.calls.book += 1
		local v
		local ok, err = pcall(function()
			v = ds:GetAsync(key)
		end)
		return ok, ok and v or tostring(err)
	end
	local function down(err)
		if not inject.quiet then
			warn("[ZR] flea index: MemoryStore error, this server's own index for " .. FleaStore.DOWN .. " s:", err)
		end
		b.downUntil = clock() + FleaStore.DOWN
	end
	local function up()
		return b.map ~= nil and clock() >= b.downUntil
	end
	function b.idxGet(_, key)
		if not up() then
			return fallback:idxGet(key)
		end
		b.calls.idx += 1
		b.calls.units += 1
		local v
		local ok, err = pcall(function()
			v = b.map:GetAsync(key)
		end)
		if not ok then
			down(err)
			return fallback:idxGet(key)
		end
		return true, v
	end
	function b.idxUpdate(_, key, fn, ttl)
		-- a write also goes to this server's own index, so the offer shows here if MemoryStore fails later
		fallback:idxUpdate(key, fn, ttl)
		if not up() then
			return true
		end
		b.calls.idx += 1
		b.calls.units += 2
		local ok, err = pcall(function()
			b.map:UpdateAsync(key, function(old)
				return fn(old)
			end, math.clamp(math.floor(ttl or 60), 1, 3888000))
		end)
		if not ok then
			local msg = tostring(err)
			if string.find(msg, "Memory", 1, true) then
				return false, "TotalMemoryOverLimit"
			end
			down(msg)
			return true -- kept in this server's own index
		end
		return true
	end
	function b.idxRange(_, after, count)
		if not up() then
			return fallback:idxRange(after, count)
		end
		b.calls.idx += 1
		local list
		local ok, err = pcall(function()
			list = b.map:GetRangeAsync(Enum.SortDirection.Ascending, count, after and { key = after } or nil)
		end)
		if not ok then
			down(err)
			return fallback:idxRange(after, count)
		end
		b.calls.units += math.max(1, #list)
		return true, list
	end
	function b.idxRemove(_, key)
		fallback:idxRemove(key)
		if up() then
			pcall(function()
				b.map:RemoveAsync(key)
			end)
		end
		return true
	end
	b.usable = function()
		return storeMode() ~= "OFFLINE"
	end
	-- a trade takes up to four writes (two profile saves, the claim, the acknowledgement): keep that much above the
	-- reserve before starting one
	b.canWrite = function()
		local ok, n = pcall(function()
			return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
		end)
		return not ok or n >= FleaStore.DS_RESERVE + 4
	end
	return b
end

-- ── one server's view of the store ───────────────────────────────────────────────────────────────────────────────
function FleaStore.new(backend, opts)
	opts = opts or {}
	return setmetatable({ b = backend, now = opts.now or os.time, cache = {}, cacheAt = -math.huge, entryAt = {} }, FleaStore)
end

function FleaStore:usable()
	return self.b.usable == nil or self.b.usable()
end

-- is there DataStore write budget left for a trade (beyond what the profile saves need)
function FleaStore:canWrite()
	return self.b.canWrite == nil or self.b.canWrite()
end

local function newBook()
	return { v = 1, o = {}, s = {}, r = {}, w = {}, k = {} }
end
local function norm(book)
	book = type(book) == "table" and book or newBook()
	book.o, book.s, book.r, book.w, book.k = book.o or {}, book.s or {}, book.r or {}, book.w or {}, book.k or {}
	return book
end
FleaStore.norm = norm

local function key(uid)
	return "b" .. tostring(math.floor(uid))
end

-- the seller's book as it stands (a read, no write)
function FleaStore:book(uid)
	local ok, v = self.b:bookGet(key(uid))
	if not ok then
		return nil, v
	end
	return norm(v)
end

-- put a new offer into its seller's book; idempotent by offer id (an id once listed is never listed again, so a
-- listing re-run after a crash cannot put a sold offer back). Returns true and "put" / "exists" / "taken" (the id was
-- used for another listing, by a profile that was reset: the seller's next collect gives the offer a new id), or false
-- and why.
function FleaStore:putOffer(uid, oid, offer)
	local status
	local ok, err = self.b:bookUpdate(key(uid), function(book)
		book = norm(book)
		if book.k[oid] then
			status = book.k[oid] == offer.t and "exists" or "taken"
			return nil
		end
		book.o[oid] = offer
		book.k[oid] = offer.t
		status = "put"
		return book
	end)
	if not ok then
		return false, err
	end
	return true, status
end

-- take back an offer that never went on show (its index entry could not be written): only while no unit of it has
-- been sold. Returns "withdrawn", "sold" (keep it listed) or nil and the error.
function FleaStore:withdraw(uid, oid)
	local status
	local ok, err = self.b:bookUpdate(key(uid), function(book)
		book = norm(book)
		local o = book.o[oid]
		if not o then
			status = "gone"
			return nil
		end
		if o.n ~= o.n0 or o.x then
			status = "sold"
			return nil
		end
		book.o[oid] = nil
		status = "withdrawn"
		return book
	end)
	if not ok then
		return nil, err
	end
	return status
end

-- A buyer claims n units of an offer, atomically in the seller's book, under the buyer's purchase id. Re-running it
-- with the same id never claims twice. maxM: the most the buyer has put aside (a dearer book price is refused).
-- Returns status ("claimed", "gone", "short", "pack", "void", "changed"), the sale record (claimed) and the units left
-- (short / pack / claimed), or nil and the error (the claim may or may not have landed: the buyer's server settles it
-- later with recover()).
function FleaStore:claim(uid, oid, pid, n, buyer, now, maxM)
	local status, sale, left
	local ok, err = self.b:bookUpdate(key(uid), function(book)
		sale, left = nil, nil
		if not book then
			status = "gone"
			return nil
		end
		book = norm(book)
		if book.s[pid] then
			status, sale = "claimed", book.s[pid]
			return nil
		end
		if book.w[pid] then
			status = "void"
			return nil
		end
		local o = book.o[oid]
		if not o or now >= o.e then
			status = "gone"
			return nil
		end
		if o.pk and n ~= o.n then
			status, left = "pack", o.n
			return nil
		end
		if n > o.n then
			status, left = "short", o.n
			return nil
		end
		local m = o.pk and o.p or o.p * n
		if maxM and m > maxM then
			status = "changed"
			return nil
		end
		sale = { o = oid, i = o.i, n = n, m = m, by = buyer.uid, bn = buyer.name, t = now }
		if n >= o.n then
			-- the last units: the buyer gets the listed item itself (a gun keeps its parts and condition)
			sale.b = o.b
			book.o[oid] = nil
			left = 0
		else
			o.n -= n
			left = o.n
		end
		book.s[pid] = sale
		status = "claimed"
		return book
	end)
	if not ok then
		return nil, err
	end
	return status, sale, left
end

-- After a crash or a lost reply: was this purchase claimed? If not, mark its id void so that a late claim with it can
-- never land. Returns "claimed" and the sale, or "void", or nil and the error.
function FleaStore:recover(uid, pid, now)
	local status, sale
	local ok, err = self.b:bookUpdate(key(uid), function(book)
		book = norm(book)
		if book.s[pid] then
			status, sale = "claimed", book.s[pid]
			return nil
		end
		if book.w[pid] then
			status = "void"
			return nil
		end
		book.w[pid] = now
		status = "void"
		return book
	end)
	if not ok then
		return nil, err
	end
	return status, sale
end

-- the buyer's server has saved the delivery: the sale no longer needs its item; it goes once the seller is paid too
function FleaStore:ack(uid, pids)
	local ok, err = self.b:bookUpdate(key(uid), function(book)
		if not book then
			return nil
		end
		book = norm(book)
		local changed = false
		for _, pid in pids do
			local s = book.s[pid]
			if s and not s.gt then
				if s.pd then
					book.s[pid] = nil
				else
					s.gt, s.b = true, nil
				end
				changed = true
			end
		end
		return changed and book or nil
	end)
	return ok, err
end

-- EFT's REMOVE: the offer ends FleaRules.REMOVE_DELAY seconds from now and can be bought until then. Returns status
-- ("ok", "removing", "gone") and the new end, or nil and the error.
function FleaStore:cancel(uid, oid, now)
	local status, ends
	local ok, err = self.b:bookUpdate(key(uid), function(book)
		book = norm(book)
		local o = book.o[oid]
		if not o or now >= o.e then
			status = "gone"
			return nil
		end
		if o.x then
			status, ends = "removing", o.e
			return nil
		end
		o.x = true
		o.e = math.min(o.e, now + FR.REMOVE_DELAY)
		status, ends = "ok", o.e
		return book
	end)
	if not ok then
		return nil, err
	end
	return status, ends
end

-- The seller's collection, one UpdateAsync: settle what the seller's saved profile has already taken (opts.got: sales
-- marked paid, returns removed), turn ended offers into returns, apply the AI buyers' purchases (opts.ai: { o, pid, n,
-- bn }), (re)put listings (opts.puts) and drop old tombstones. Returns the book after it (a copy), or nil and the error.
function FleaStore:collect(uid, opts)
	local seen
	local now = opts.now
	local ok, err = self.b:bookUpdate(key(uid), function(book)
		book = norm(book)
		local changed = false
		for id in opts.got or {} do
			local s = book.s[id]
			if s and not s.pd then
				if s.gt then
					book.s[id] = nil
				else
					s.pd = true
				end
				changed = true
			end
			if book.r[id] then
				book.r[id] = nil
				changed = true
			end
		end
		-- the AI buyers' purchases first, each at the time it was rolled for (a.t, before the offer's end): the seller's
		-- offers sell while the seller is away, and the time is caught up when their server next looks
		for _, a in opts.ai or {} do
			local o = book.o[a.o]
			local at = a.t or now
			if o and at < o.e and not book.s[a.pid] and not book.w[a.pid] and o.n > 0 then
				local n = o.pk and o.n or math.clamp(a.n, 1, o.n)
				book.s[a.pid] = { o = a.o, i = o.i, n = n, m = o.pk and o.p or o.p * n, by = 0, bn = a.bn, t = at, gt = true }
				o.n -= n
				if o.n <= 0 then
					book.o[a.o] = nil
				end
				changed = true
			end
		end
		local ended = {}
		for oid, o in book.o do
			if now >= o.e then
				table.insert(ended, oid)
			end
		end
		table.sort(ended)
		for _, oid in ended do
			local o = book.o[oid]
			book.r["r" .. oid] = { o = oid, i = o.i, n = o.n, n0 = o.n0, p = o.p, pk = o.pk, b = o.b, x = o.x, lg = o.lg, t = now }
			book.o[oid] = nil
			changed = true
		end
		for oid, offer in opts.puts or {} do
			if not book.k[oid] then
				book.o[oid] = offer
				book.k[oid] = offer.t
				changed = true
			end
		end
		local old = {}
		for id, t in book.w do
			if now - t > FleaStore.TOMB then
				table.insert(old, id)
			end
		end
		for _, id in old do
			book.w[id] = nil
			changed = true
		end
		old = {}
		for id, t in book.k do
			if now - t > FleaStore.TOMB and not book.o[id] then
				table.insert(old, id)
			end
		end
		for _, id in old do
			book.k[id] = nil
			changed = true
		end
		seen = book
		return changed and book or nil
	end)
	if not ok then
		return nil, err
	end
	return Util.copy(seen or norm(nil))
end

-- tests and the Dev tool: move every open offer of a seller back in time
function FleaStore:age(uid, sec)
	return self.b:bookUpdate(key(uid), function(book)
		if not book then
			return nil
		end
		book = norm(book)
		for _, o in book.o do
			o.t -= sec
			o.e -= sec
		end
		for oid, t in book.k do
			book.k[oid] = t - sec
		end
		return book
	end)
end

-- ── the index ─────────────────────────────────────────────────────────────────────────────────────────────────────
local function byUnit(a, b)
	local ua, ub = FR.unitOf(a), FR.unitOf(b)
	if ua ~= ub then
		return ua < ub
	end
	return a.o < b.o
end

-- Edit one item's entry: fn(entry) changes the decoded entry (expired and empty offers already dropped, the AI stock
-- reset when its window has passed) and returns false for "no change". Returns ok (and the entry or the error).
function FleaStore:idxEdit(id, fn, aiOnly)
	local now = self.now()
	local w = window(now)
	local result, refused
	local cached = self.cache[id]
	-- the entry lives as long as an offer can (12 h) or, holding only the AI floor's stock, until the window ends
	local ttl = FR.DURATION + 120
	if aiOnly and (not cached or #cached.o == 0) then
		ttl = (w + 1) * FR.WINDOW - now + 60
	end
	local ok, err = self.b:idxUpdate(id, function(old)
		local e = FR.decodeEntry(old)
		local keep = {}
		for _, o in e.o do
			if o.e > now and o.n > 0 then
				table.insert(keep, o)
			end
		end
		e.o = keep
		if e.w ~= w then
			e.w, e.a = w, {}
		end
		refused = nil
		local r = fn(e)
		if r == false then
			result = e
			return nil
		elseif r == "full" then
			refused, result = "full", e
			return nil
		end
		table.sort(e.o, byUnit)
		local s = FR.encodeEntry(e)
		if #s > FR.ENTRY_LIMIT then
			refused, result = "full", e
			return nil
		end
		result = e
		return s
	end, ttl)
	if not ok then
		return false, err
	end
	if result then
		self.cache[id] = result
		self.entryAt[id] = now
	end
	if refused then
		return false, refused
	end
	return true, result
end

-- add (or refresh) a player offer row { o, p, n, e, r, nm, pk }; "full" when the item already shows MAX_PER_ITEM
function FleaStore:addOffer(id, row)
	return self:idxEdit(id, function(e)
		for _, o in e.o do
			if o.o == row.o then
				if o.n == row.n and o.e == row.e then
					return false
				end
				o.n, o.e = row.n, row.e
				return true
			end
		end
		if #e.o >= FR.MAX_PER_ITEM then
			return "full"
		end
		table.insert(e.o, { o = row.o, p = row.p, n = row.n, e = row.e, r = row.r, nm = row.nm, pk = row.pk })
		return true
	end)
end

-- set an offer's units left and end (0 units: off the shop window)
function FleaStore:setOffer(id, oid, n, ends)
	return self:idxEdit(id, function(e)
		for k, o in e.o do
			if o.o == oid then
				if n <= 0 then
					table.remove(e.o, k)
				else
					o.n, o.e = n, ends or o.e
				end
				return true
			end
		end
		return false
	end)
end

-- the AI floor's stock: take n of operator offer i (stock units this window); every server shares it. Returns true and
-- the units left, or false and the units left (not enough) / the error.
function FleaStore:aiTake(id, i, n, stock)
	local got, left = false, nil
	local ok, err = self:idxEdit(id, function(e)
		local bought = e.a[i] or 0
		left = stock - bought
		if left < n then
			return false
		end
		e.a[i] = bought + n
		left -= n
		got = true
		return true
	end, true)
	if not ok then
		return false, err
	end
	return got, left
end

-- the whole index (every item with player offers or AI stock bought this window), at most FleaStore.TTL seconds old
function FleaStore:index(force)
	local now = self.now()
	if not force and now - self.cacheAt < FleaStore.TTL then
		return self.cache
	end
	local map, after = {}, nil
	for _ = 1, 5 do
		local ok, list = self.b:idxRange(after, 200)
		if not ok then
			-- keep what we had and try again in 10 s
			self.cacheAt = now - FleaStore.TTL + 10
			return self.cache
		end
		for _, it in list do
			map[it.key] = FR.decodeEntry(it.value)
			after = it.key
		end
		if #list < 200 then
			break
		end
	end
	self.cache, self.cacheAt = map, now
	for k in map do
		self.entryAt[k] = now
	end
	return map
end

-- one item's entry, at most maxAge seconds old (default ENTRY_TTL): a GetAsync when the cache is older
function FleaStore:entry(id, maxAge)
	local now = self.now()
	if now - (self.entryAt[id] or -math.huge) < (maxAge or FleaStore.ENTRY_TTL) then
		return self.cache[id]
	end
	local ok, v = self.b:idxGet(id)
	if not ok then
		return self.cache[id]
	end
	local e = v and FR.decodeEntry(v) or nil
	self.cache[id] = e
	self.entryAt[id] = now
	return e
end

-- the cached entry without any request (the AI buyers' view of the competition)
function FleaStore:cached(id)
	return self.cache[id]
end

return FleaStore
