--!strict
-- Pure profile transactions: new profile, migration (wipe on schema change), deploy reservation,
-- idempotent raid settlement (secure container survives death, found-in-raid on extraction), recovery kit.
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local Inv = require(script.Parent.Inv)

local Settle = {}
Settle.SCHEMA = 2

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
	return wg
end

function Settle.newProfile(): any
	local p = Inv.newHolder("profile")
	p.schema = Settle.SCHEMA
	p.rev = 0
	p.money = Config.START_MONEY
	p.finalized = {}
	p.stats = { raids = 0, survived = 0, kia = 0, mia = 0, lost = 0, kills = 0, extractedValue = 0, pmcKills = 0, scavKills = 0 }
	p.settings = {}
	p.known = {}
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
	for _, k in { "raids", "survived", "kia", "mia", "lost", "kills", "extractedValue", "pmcKills", "scavKills" } do
		p.stats[k] = p.stats[k] or 0
	end
	p.settings = p.settings or {}
	p.known = p.known or {}
	return p
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
function Settle.finalize(p: any, raidId: string, outcome: string, raid: any?, now: number): (any?, string?)
	if p.finalized[raidId] then
		return nil, "ALREADY_FINALIZED"
	end
	local pr = p.pendingRaid
	if not pr or pr.id ~= raidId then
		return nil, "NO_PENDING_RAID"
	end
	local receipt = { raidId = raidId, outcome = outcome, retained = {}, lost = {}, kept = {}, value = 0, at = now }
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
				it.fir = true
			end
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
		p.stats.survived += 1
		p.stats.extractedValue += receipt.value
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
