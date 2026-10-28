--!strict
-- Pure profile transactions: new profile, migration, deploy reservation and idempotent raid settlement.
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("EFB")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local Inv = require(script.Parent.Inv)

local Settle = {}
Settle.SCHEMA = 1

local function giveLoadoutKit(p: any, recovery: boolean)
	local rk = recovery or nil
	local rg, rifle = Inv.newItem("R17_RIFLE", 1, { rk = rk })
	local mg, mag = Inv.newItem("R17_MAG", 1, { a = 25, rk = rk })
	p.items[rg] = rifle
	p.items[mg] = mag
	rifle.mag = mg
	p.slots.primary = rg
	for i = 1, 2 do
		local g, it = Inv.newItem("R17_MAG", 1, { a = 25, rk = rk })
		Inv.place(p, g, it, { "pockets", "bag", "stash" })
	end
	local bg, band = Inv.newItem("BANDAGE", 1, { rk = rk })
	Inv.place(p, bg, band, { "pockets", "bag", "stash" })
end

function Settle.newProfile(): any
	local p = Inv.newHolder(true)
	p.schema = Settle.SCHEMA
	p.rev = 0
	p.money = Config.START_MONEY
	p.finalized = {}
	p.stats = { raids = 0, survived = 0, kia = 0, mia = 0, lost = 0, kills = 0, extractedValue = 0 }
	p.settings = {}
	local bagG, bag = Inv.newItem("CANVAS_BAG", 1)
	p.items[bagG] = bag
	p.slots.bag = bagG
	giveLoadoutKit(p, false)
	local ag, ammo = Inv.newItem("UC62", 60)
	Inv.place(p, ag, ammo, { "stash" })
	local mg, mag = Inv.newItem("R17_MAG", 1, { a = 0 })
	Inv.place(p, mg, mag, { "stash" })
	local bg, band = Inv.newItem("BANDAGE", 1)
	Inv.place(p, bg, band, { "stash" })
	return p
end

function Settle.migrate(p: any): any
	p.schema = p.schema or Settle.SCHEMA
	p.rev = p.rev or 0
	p.money = math.max(0, p.money or Config.START_MONEY)
	p.items = p.items or {}
	p.stash = p.stash or {}
	p.pockets = p.pockets or {}
	p.bag = p.bag or {}
	p.slots = p.slots or {}
	p.finalized = p.finalized or {}
	p.stats = p.stats or {}
	for _, k in { "raids", "survived", "kia", "mia", "lost", "kills", "extractedValue" } do
		p.stats[k] = p.stats[k] or 0
	end
	p.settings = p.settings or {}
	return p
end

-- Moves the whole loadout (slots, pockets, pack and loaded mags) out of the profile into a raid holder
-- and records a durable reservation. Caller must persist the profile before exposing the raid.
function Settle.deploy(p: any, raidId: string, now: number): (any?, string?)
	if p.pendingRaid then
		return nil, "ALREADY_IN_RAID"
	end
	if p.finalized[raidId] then
		return nil, "ALREADY_FINALIZED"
	end
	local guids = Inv.loadoutGuids(p)
	local raid = Inv.newHolder(false)
	local risked = {}
	for _, g in guids do
		local it = p.items[g]
		raid.items[g] = it
		p.items[g] = nil
		table.insert(risked, { g = g, id = it.id, n = it.n })
	end
	raid.pockets, raid.bag, raid.slots = p.pockets, p.bag, p.slots
	p.pockets, p.bag, p.slots = {}, {}, {}
	p.pendingRaid = { id = raidId, t = now, risked = risked, value = Inv.value(raid) }
	p.stats.raids += 1
	p.rev += 1
	return Util.copy(raid), nil
end

local function summarize(h: any): { any }
	local out = {}
	for _, it in h.items do
		table.insert(out, { id = it.id, n = it.n, a = it.a })
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
	local receipt = { raidId = raidId, outcome = outcome, retained = {}, lost = {}, value = 0, at = now }
	if outcome == "SUCCESS" and raid then
		if next(p.pockets) or next(p.bag) or next(p.slots) then
			return nil, "LOADOUT_NOT_EMPTY"
		end
		for g, it in raid.items do
			if p.items[g] then
				return nil, "GUID_COLLISION"
			end
		end
		for g, it in raid.items do
			p.items[g] = it
		end
		p.pockets, p.bag, p.slots = raid.pockets, raid.bag, raid.slots
		receipt.retained = summarize(raid)
		receipt.value = Inv.value(raid)
		p.stats.survived += 1
		p.stats.extractedValue += receipt.value
	else
		if raid then
			receipt.lost = summarize(raid)
			receipt.value = Inv.value(raid)
		else
			for _, r in pr.risked do
				table.insert(receipt.lost, { id = r.id, n = r.n })
			end
			receipt.value = pr.value or 0
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
	-- bounded receipt log
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

-- Free basic kit when the player owns no weapon at all (recovery items are worth 0 to traders).
function Settle.recoveryKit(p: any): (boolean, string?)
	if p.pendingRaid then
		return false, "IN_RAID"
	end
	if Inv.ownsId(p, "R17_RIFLE") then
		return false, "HAS_WEAPON"
	end
	if p.slots.primary then
		return false, "SLOT_FULL"
	end
	giveLoadoutKit(p, true)
	p.rev += 1
	return true, nil
end

return Settle
