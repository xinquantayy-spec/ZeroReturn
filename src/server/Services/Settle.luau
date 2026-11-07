--!strict
-- Pure profile transactions: new profile, migration (wipe on schema change), deploy reservation,
-- idempotent raid settlement (secure container survives death, found-in-raid on extraction), recovery kit.
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local Inv = require(script.Parent.Inv)
local WP = require(Shared.WeaponParts)
local Progress = require(Shared.Progress)

local Settle = {}
Settle.SCHEMA = 3 -- 3: M14 weapon builds (guns are part trees); older profiles are wiped like a Tarkov wipe

local function equip(p: any, slot: string, id: string, extra: any?): string
	local g, it = Inv.newItem(id, 1, extra)
	local ok, err = Inv.placeSlot(p, g, it, slot)
	assert(ok, "starter equip failed: " .. tostring(err))
	return g
end

local function put(p: any, id: string, n: number?, order: { string }, extra: any?): string?
	local g, it = Inv.newItem(id, n, extra)
	local ok = Inv.place(p, g, it, order)
	return ok and g or nil
end

local function loadedMag(p: any, id: string, ammoId: string, order: { string }, rk: boolean?): string?
	local cap = Items.defs[id].capacity
	return put(p, id, 1, order, { a = cap, at = ammoId, rk = rk })
end

local function weaponWithMag(p: any, slot: string, wid: string, mid: string, ammoId: string, rk: boolean?): string
	local wg = equip(p, slot, wid, { rk = rk })
	local mg, mag = Inv.newItem(mid, 1, { a = Items.defs[mid].capacity, at = ammoId, rk = rk })
	p.items[mg] = mag
	p.items[wg].mag = mg
	Inv.resize(p, wg)
	return wg
end

function Settle.newProfile(): any
	local p = Inv.newHolder("profile")
	p.schema = Settle.SCHEMA
	p.rev = 0
	p.money = Config.START_MONEY
	p.finalized = {}
	p.stats = { raids = 0, survived = 0, kia = 0, mia = 0, lost = 0, kills = 0, extractedValue = 0, pmcKills = 0, scavKills = 0, bossKills = 0, scavRaids = 0, scavSurvived = 0 }
	p.claims = {}
	p.scavReadyAt = 0
	p.settings = {}
	p.known = {}
	Settle.progressFields(p)
	-- worn kit
	equip(p, "back", "CANVAS_BAG")
	local rig = equip(p, "rig", "RIG_CHEST")
	equip(p, "armor", "ARMOR_C2")
	equip(p, "secure", "SECURE_S")
	equip(p, "melee", "FIELD_KNIFE")
	weaponWithMag(p, "primary", "R17_RIFLE", "R17_MAG", "A62_FMJ")
	weaponWithMag(p, "holster", "P9_PISTOL", "P9_MAG", "A9_PST")
	local back = p.slots.back
	loadedMag(p, "R17_MAG", "A62_FMJ", { rig })
	loadedMag(p, "R17_MAG", "A62_FMJ", { rig })
	loadedMag(p, "P9_MAG", "A9_PST", { rig })
	put(p, "BANDAGE", 1, { rig })
	put(p, "MEDKIT_M", 1, { rig })
	put(p, "TOURNIQUET", 1, { "pockets" })
	put(p, "PAINKILLERS", 1, { "pockets" })
	put(p, "WATER", 1, { back })
	put(p, "STEW", 1, { back })
	put(p, "SPLINT", 1, { back })
	put(p, "A62_FMJ", 60, { back })
	-- stash
	for _, e in { { "A62_FMJ", 60 }, { "A62_FMJ", 60 }, { "A9_PST", 50 }, { "BANDAGE", 1 }, { "BANDAGE", 1 }, { "MEDKIT_S", 1 }, { "HARDTACK", 1 }, { "HELMET_C2", 1 } } do
		put(p, e[1], e[2], { "stash" })
	end
	put(p, "R17_MAG", 1, { "stash" }, { a = 0 })
	return p
end

function Settle.migrate(p: any): any
	if (p.schema or 1) < Settle.SCHEMA then
		-- schema change = wipe (Tarkov-style); keep player settings
		local fresh = Settle.newProfile()
		fresh.settings = p.settings or {}
		fresh.wiped = (p.wiped or 0) + 1
		for k in p do
			p[k] = nil
		end
		for k, v in fresh do
			p[k] = v
		end
		return p
	end
	p.rev = p.rev or 0
	p.money = math.max(0, p.money or Config.START_MONEY)
	p.items = p.items or {}
	p.grids = p.grids or {}
	p.grids.stash = p.grids.stash or {}
	p.grids.pockets = p.grids.pockets or {}
	p.slots = p.slots or {}
	p.finalized = p.finalized or {}
	p.stats = p.stats or {}
	for _, k in { "raids", "survived", "kia", "mia", "lost", "kills", "extractedValue", "pmcKills", "scavKills", "bossKills", "scavRaids", "scavSurvived" } do
		p.stats[k] = p.stats[k] or 0
	end
	p.claims = p.claims or {}
	p.scavReadyAt = p.scavReadyAt or 0
	p.settings = p.settings or {}
	p.known = p.known or {}
	Settle.progressFields(p)
	return p
end

-- progression and economy (M9): experience, skills, weapon mastering, trader standing, purchases, tasks, hideout, karma
function Settle.progressFields(p: any)
	p.xp = p.xp or 0
	p.skills = p.skills or {}
	p.mastering = p.mastering or {} -- [Progress.MASTERING group] = points (no schema change: older profiles start at 0)
	p.traders = p.traders or {}
	p.bought = p.bought or {}
	p.quests = p.quests or {}
	p.hideout = p.hideout or {}
	p.hideout.levels = p.hideout.levels or {}
	p.hideout.crafts = p.hideout.crafts or {}
	p.karma = p.karma or Progress.KARMA.start
	p.stashH = p.stashH or Config.STASH_H
end

local function snapshotSecure(h: any): any?
	local sg = h.slots.secure
	if not sg then
		return nil
	end
	local guids = { sg }
	Inv.descendants(h, sg, guids)
	local snap = { root = sg, items = {}, grids = {} }
	for _, g in guids do
		snap.items[g] = Util.copy(h.items[g])
		if h.grids[g] then
			snap.grids[g] = Util.copy(h.grids[g])
		end
	end
	return snap
end

-- Moves the whole loadout (slots, pockets and everything inside) into a raid holder and records a durable
-- reservation (with a copy of the secure container for crash recovery). Caller persists before spawning.
function Settle.deploy(p: any, raidId: string, now: number): (any?, string?)
	if p.pendingRaid then
		return nil, "ALREADY_IN_RAID"
	end
	if p.finalized[raidId] then
		return nil, "ALREADY_FINALIZED"
	end
	local guids = Inv.equippedGuids(p)
	local raid = Inv.newHolder("raid")
	local risked = {}
	for _, g in guids do
		local it = p.items[g]
		-- an item taken into a raid is no longer found in raid, whatever happens to it there (Tarkov; audit economy.4)
		it.fir = nil
		raid.items[g] = it
		p.items[g] = nil
		if p.grids[g] then
			raid.grids[g] = p.grids[g]
			p.grids[g] = nil
		end
		table.insert(risked, { g = g, id = it.id, n = it.n })
	end
	raid.grids.pockets = p.grids.pockets
	raid.slots = p.slots
	p.grids.pockets = {}
	p.slots = {}
	p.pendingRaid = { id = raidId, t = now, risked = risked, value = Inv.value(raid), secure = snapshotSecure(raid) }
	p.stats.raids += 1
	p.rev += 1
	return Util.copy(raid), nil
end

-- Player-scav raid: the PMC kit stays home; a generated scav kit goes in. Cooldown starts now.
function Settle.deployScav(p: any, raidId: string, now: number, kit: any): (any?, string?)
	if p.pendingRaid then
		return nil, "ALREADY_IN_RAID"
	end
	if (p.scavReadyAt or 0) > now then
		return nil, "SCAV_COOLDOWN"
	end
	p.pendingRaid = { id = raidId, t = now, risked = {}, value = 0, scav = true }
	p.scavReadyAt = now + Progress.scavCooldown(Config.SCAV_COOLDOWN, p.karma)
	p.stats.scavRaids += 1
	p.rev += 1
	return kit, nil
end

-- Tarkov insurance rules: weapons, gear, mags, attachments and loot can be insured; ammo, quest items, the
-- secure container (and what is inside it - it always comes home) and free recovery-kit items cannot.
local function insurable(p: any, g: string): boolean
	local it = p.items[g]
	local d = it and Items.defs[it.id]
	if not d or it.rk or d.kind == "secure" or d.kind == "quest" or d.kind == "ammo" then
		return false
	end
	local sg = p.slots.secure
	return not (sg and (g == sg or Inv.isInside(p, sg, g)))
end
Settle.insurable = insurable

local function insureCost(it: any): number
	return math.max(150, math.floor(Items.valueOf(it) * Config.INSURANCE_RATE))
end

-- cost and item count to insure everything not yet insured in `list`
local function quote(p: any, list: { string }, userId: number): (number, { string })
	local cost, todo = 0, {}
	for _, x in list do
		local xi = p.items[x]
		if xi and xi.ins ~= userId and insurable(p, x) then
			cost += insureCost(xi)
			table.insert(todo, x)
		end
	end
	-- Charisma: 0.1 % off a level (Tarkov; audit economy.6)
	return math.floor(cost * (1 - Progress.bonus(p.skills, "charisma"))), todo
end

local function insureList(p: any, list: { string }, userId: number): (number?, string?)
	if p.pendingRaid then
		return nil, "IN_RAID"
	end
	local cost, todo = quote(p, list, userId)
	if #todo == 0 then
		return nil, "ALREADY_INSURED"
	end
	if p.money < cost then
		return nil, "NOT_ENOUGH_MONEY"
	end
	p.money -= cost
	for _, x in todo do
		p.items[x].ins = userId
	end
	p.rev += 1
	return cost, nil
end

-- Insure one item (and the parts attached to it: magazine, attachments) for the next raid.
function Settle.insure(p: any, g: string, userId: number): (number?, string?)
	local it = p.items[g]
	if not it then
		return nil, "NO_ITEM"
	end
	if not insurable(p, g) then
		return nil, "NOT_INSURABLE"
	end
	-- the item with its magazine and every part on it (M14 builds)
	local list = {}
	WP.walk(p.items, g, function(bg)
		table.insert(list, bg)
	end)
	return insureList(p, list, userId)
end

-- "Insure all" on the deploy screen: everything worn and carried that can be insured.
function Settle.insureAll(p: any, userId: number): (number?, string?)
	return insureList(p, Inv.equippedGuids(p), userId)
end

function Settle.insureQuote(p: any, userId: number): any
	local list = Inv.equippedGuids(p)
	local cost, todo = quote(p, list, userId)
	local insured = 0
	for _, g in list do
		local it = p.items[g]
		if it and it.ins == userId then
			insured += 1
		end
	end
	return { cost = cost, n = #todo, insured = insured }
end

-- Deliver ready insurance returns into the stash; returns items delivered and claims still waiting.
function Settle.claim(p: any, now: number): (number, number)
	local delivered, waiting = 0, 0
	local keep = {}
	for _, c in p.claims or {} do
		if (c.readyAt or 0) <= now then
			local rest = {}
			for _, b in c.bundles or {} do
				b.it.ins = nil
				for _, sub in b.subs or {} do
					sub.it.ins = nil
				end
				if Inv.give(p, b, nil, { "stash" }) then
					delivered += 1
				else
					table.insert(rest, b)
				end
			end
			if #rest > 0 then
				c.bundles = rest
				table.insert(keep, c)
				waiting += #rest
			end
		else
			table.insert(keep, c)
			waiting += #(c.bundles or {})
		end
	end
	p.claims = keep
	if delivered > 0 then
		p.rev += 1
	end
	return delivered, waiting
end

local function summarize(h: any, guids: { string }?): { any }
	local out = {}
	local list = guids
	if not list then
		list = {}
		for g in h.items do
			table.insert(list, g)
		end
	end
	for _, g in list do
		local it = h.items[g]
		if it then
			table.insert(out, { id = it.id, n = it.n, a = it.a })
		end
	end
	table.sort(out, function(a, b)
		return Items.valueOf(a) > Items.valueOf(b)
	end)
	return out
end

-- Idempotent settlement keyed by raidId. raid may be nil (crash recovery -> treated as failure).
-- opts.runThrough: survived but too quickly with too little done -> found items are not found-in-raid.
function Settle.finalize(p: any, raidId: string, outcome: string, raid: any?, now: number, opts: any?): (any?, string?)
	local runThrough = opts ~= nil and opts.runThrough == true
	-- opts.closed: the server closed mid-raid (Raid.finalize SERVER_CLOSED). Everything carried is kept, nothing becomes
	-- found-in-raid and the raid does not count as survived, for a PMC or a player scav alike.
	local closed = opts ~= nil and opts.closed == true
	if p.finalized[raidId] then
		return nil, "ALREADY_FINALIZED"
	end
	local pr = p.pendingRaid
	if not pr or pr.id ~= raidId then
		return nil, "NO_PENDING_RAID"
	end
	local receipt = { raidId = raidId, outcome = outcome, retained = {}, lost = {}, kept = {}, value = 0, at = now, scav = pr.scav, runThrough = runThrough or nil }
	if pr.scav then
		-- player scav: everything carried out goes to the stash (overflow is sold); nothing at stake otherwise
		if outcome == "SUCCESS" and raid then
			local tops = {}
			for _, g in raid.slots do
				table.insert(tops, g)
			end
			for g in raid.grids.pockets or {} do
				table.insert(tops, g)
			end
			local sold = 0
			for _, g in tops do
				if raid.items[g] then
					local b = Inv.take(raid, g)
					if b then
						for _, x in { b, table.unpack(b.subs) } do
							local it = x.it
							if it.fip then
								it.fip = nil
								it.fir = not closed or nil
							end
							it.ins = nil
						end
						receipt.value += Items.valueOf(b.it)
						table.insert(receipt.retained, { id = b.it.id, n = b.it.n, a = b.it.a })
						if not Inv.give(p, b, nil, { "stash" }) then
							local v = Items.valueOf(b.it)
							for _, sub in b.subs do
								v += Items.valueOf(sub.it)
							end
							sold += math.floor(v * Config.SELL_RATE)
						end
					end
				end
			end
			p.money += sold
			receipt.sold = sold
			if not closed then
				p.stats.scavSurvived += 1
				p.stats.extractedValue += receipt.value
			end
		end
		p.pendingRaid = nil
		p.finalized[raidId] = { o = outcome, t = now }
		p.rev += 1
		return receipt, nil
	end
	if outcome == "SUCCESS" and raid then
		if next(p.grids.pockets) or next(p.slots) then
			return nil, "LOADOUT_NOT_EMPTY"
		end
		for g in raid.items do
			if p.items[g] then
				return nil, "GUID_COLLISION"
			end
		end
		for g, it in raid.items do
			if it.fip then
				it.fip = nil
				if not runThrough then
					it.fir = true
				end
			end
			it.ins = nil -- insurance covers one raid (and loot from other bodies is now yours)
			p.items[g] = it
		end
		for cid, pl in raid.grids do
			if cid ~= "stash" then
				p.grids[cid] = pl
			end
		end
		p.slots = raid.slots
		receipt.retained = summarize(raid)
		receipt.value = Inv.value(raid)
		if not closed then
			p.stats.survived += 1
			p.stats.extractedValue += receipt.value
		end
	else
		-- the secure container (and contents) always comes home; found-in-raid status is lost
		if raid then
			local sg = raid.slots.secure
			local bundle = sg and Inv.take(raid, sg)
			receipt.lost = summarize(raid)
			receipt.value = Inv.value(raid)
			if bundle then
				local kept = { bundle.g }
				bundle.it.fip = nil
				for _, s in bundle.subs do
					s.it.fip = nil
					table.insert(kept, s.g)
				end
				Inv.give(p, bundle, { slot = "secure" })
				receipt.kept = summarize(p, kept)
			end
		else
			for _, r in pr.risked do
				if not (pr.secure and pr.secure.items[r.g]) then
					table.insert(receipt.lost, { id = r.id, n = r.n })
				end
			end
			receipt.value = pr.value or 0
			local snap = pr.secure
			if snap and not p.slots.secure then
				for g, it in snap.items do
					it.fip = nil
					p.items[g] = it
				end
				for g, pl in snap.grids do
					p.grids[g] = pl
				end
				p.slots.secure = snap.root
				receipt.kept = summarize(p, (function()
					local l = {}
					for g in snap.items do
						table.insert(l, g)
					end
					return l
				end)())
			end
		end
		if outcome == "KIA" then
			p.stats.kia += 1
		elseif outcome == "MIA" then
			p.stats.mia += 1
		else
			p.stats.lost += 1
		end
	end
	p.pendingRaid = nil
	p.finalized[raidId] = { o = outcome, t = now }
	local keys = {}
	for k, v in p.finalized do
		table.insert(keys, { k = k, t = v.t })
	end
	if #keys > Config.FINALIZED_LOG then
		table.sort(keys, function(a, b)
			return a.t > b.t
		end)
		for i = Config.FINALIZED_LOG + 1, #keys do
			p.finalized[keys[i].k] = nil
		end
	end
	p.rev += 1
	return receipt, nil
end

-- Free basic kit when the player owns no firearm and is nearly broke (kit items sell for 0).
function Settle.recoveryKit(p: any): (boolean, string?)
	if p.pendingRaid then
		return false, "IN_RAID"
	end
	if Inv.ownsKind(p, { weapon = true, pistol = true }) then
		return false, "HAS_WEAPON"
	end
	if p.money >= Config.RECOVERY_MONEY then
		return false, "NOT_BROKE"
	end
	local mg, mag = Inv.newItem("R17_MAG", 1, { a = 25, at = "A62_FMJ", rk = true })
	local wg, rifle = Inv.newItem("R17_RIFLE", 1, { rk = true, mag = mg })
	p.items[mg] = mag
	local okP = Inv.place(p, wg, rifle, { "stash" })
	if not okP then
		p.items[mg] = nil
		return false, "NO_SPACE"
	end
	put(p, "R17_MAG", 1, { "stash" }, { a = 25, at = "A62_FMJ", rk = true })
	put(p, "BANDAGE", 1, { "stash" }, { rk = true })
	p.rev += 1
	return true, nil
end

return Settle
