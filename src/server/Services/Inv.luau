--!strict
-- Inventory 2.0 (pure, no yields): Tarkov-style equipment slots, nested container grids, magazines in weapons.
-- holder = {
--   items = { [guid] = item },   item = { id, n, a?(rounds), at?(ammo id), mag?(guid), dur?, uses?, hp?, fir?, fip?, rk? }
--   grids = { [cid] = { [guid] = { x, y, r } } },   cid = "stash" | "pockets" | "main" | <container item guid>
--   slots = { [slot] = guid },   mainW?, mainH?  (world boxes / ground piles)
-- }
-- Invariant: every item has exactly one location: a grid placement, a slot, or a weapon's magazine well.
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("ZR")
local Items = require(Shared.Items)
local Grid = require(Shared.Grid)
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local Inv = {}
local defs = Items.defs
local SLOTS = Items.SLOTS
local BUILTIN = { stash = true, pockets = true, main = true }
Inv.BUILTIN = BUILTIN

function Inv.newHolder(kind: string?, w: number?, h: number?): any
	if kind == "box" then
		return { items = {}, grids = { main = {} }, slots = {}, mainW = w or 5, mainH = h or 4 }
	end
	local hold = { items = {}, grids = { pockets = {} }, slots = {} }
	if kind == "profile" then
		hold.grids.stash = {}
	end
	return hold
end

local function sizer(h: any)
	return function(g: string): (number, number)
		local it = h.items[g]
		local d = it and defs[it.id]
		if not d then
			return 1, 1
		end
		return d.w, d.h
	end
end

function Inv.dims(h: any, cid: string): (number, number)
	if cid == "stash" then
		if h.grids.stash then
			return Config.STASH_W, h.stashH or Config.STASH_H -- storage racks add rows (hideout)
		end
		return 0, 0
	elseif cid == "pockets" then
		if h.grids.pockets then
			return Config.POCKETS_W, Config.POCKETS_H
		end
		return 0, 0
	elseif cid == "main" then
		return h.mainW or 0, h.mainH or 0
	end
	local it = h.items[cid]
	local d = it and defs[it.id]
	if d and d.grid then
		return d.grid.w, d.grid.h
	end
	return 0, 0
end

-- where is g?  "grid", cid, placement | "slot", name | "mag", weaponGuid | "mod", weaponGuid, mount | nil
function Inv.locate(h: any, g: string): (string?, any, any)
	for cid, pl in h.grids do
		local p = pl[g]
		if p then
			return "grid", cid, p
		end
	end
	for s, sg in h.slots do
		if sg == g then
			return "slot", s, nil
		end
	end
	for wg, it in h.items do
		if it.mag == g then
			return "mag", wg, nil
		end
		if it.mods then
			for mount, mg in it.mods do
				if mg == g then
					return "mod", wg, mount
				end
			end
		end
	end
	return nil, nil, nil
end

-- direct parent item (container or weapon), nil for top-level (stash/pockets/main/slot)
function Inv.parentOf(h: any, g: string): string?
	local k, a = Inv.locate(h, g)
	if k == "grid" and not BUILTIN[a] then
		return a
	elseif k == "mag" or k == "mod" then
		return a
	end
	return nil
end

-- true when `inner` sits (directly or deeply) inside `outer`
function Inv.isInside(h: any, outer: string, inner: string): boolean
	local cur = inner
	for _ = 1, 32 do
		local p = Inv.parentOf(h, cur)
		if not p then
			return false
		end
		if p == outer then
			return true
		end
		cur = p
	end
	return false
end

function Inv.topOf(h: any, g: string): string
	local cur = g
	for _ = 1, 32 do
		local p = Inv.parentOf(h, cur)
		if not p then
			return cur
		end
		cur = p
	end
	return cur
end

function Inv.descendants(h: any, g: string, out: { string }?): { string }
	local list = out or {}
	local it = h.items[g]
	if not it then
		return list
	end
	if it.mag and h.items[it.mag] then
		table.insert(list, it.mag)
		Inv.descendants(h, it.mag, list)
	end
	if it.mods then
		for _, mg in it.mods do
			if h.items[mg] then
				table.insert(list, mg)
			end
		end
	end
	local pl = h.grids[g]
	if pl then
		for cg in pl do
			table.insert(list, cg)
			Inv.descendants(h, cg, list)
		end
	end
	return list
end

local function detach(h: any, g: string)
	local k, a, b = Inv.locate(h, g)
	if k == "grid" then
		h.grids[a][g] = nil
	elseif k == "slot" then
		h.slots[a] = nil
	elseif k == "mag" then
		h.items[a].mag = nil
	elseif k == "mod" then
		h.items[a].mods[b] = nil
		if next(h.items[a].mods) == nil then
			h.items[a].mods = nil
		end
	end
end
Inv.detach = detach

function Inv.itemAt(h: any, cid: string, x: number, y: number): string?
	local pl = h.grids[cid]
	if not pl then
		return nil
	end
	return Grid.at(pl, sizer(h), x, y)
end

local function isEmptyContainer(h: any, g: string): boolean
	local pl = h.grids[g]
	return pl == nil or next(pl) == nil
end

-- can item g enter grid cid (ignoring geometry)?
function Inv.canEnter(h: any, g: string, cid: string): (boolean, string?)
	local it = h.items[g]
	local d = it and defs[it.id]
	if not d then
		return false, "NO_ITEM"
	end
	if not h.grids[cid] then
		return false, "BAD_CONTAINER"
	end
	if cid == g then
		return false, "SELF"
	end
	if d.kind == "secure" and cid ~= "stash" then
		return false, "SECURE_RESTRICTED"
	end
	if cid == "pockets" and d.w * d.h > 1 then
		return false, "TOO_BIG"
	end
	if not BUILTIN[cid] then
		if Inv.isInside(h, g, cid) then
			return false, "SELF"
		end
		local cdef = defs[h.items[cid].id]
		if cdef.kind == "secure" and not Items.SECURE_KINDS[d.kind] then
			return false, "SECURE_RESTRICTED"
		end
		if d.grid and not isEmptyContainer(h, g) then
			return false, "CONTAINER_NOT_EMPTY"
		end
		if d.kind == "backpack" and cdef.kind == "backpack" then
			return false, "BAG_IN_BAG"
		end
	elseif cid == "pockets" and d.grid and not isEmptyContainer(h, g) then
		return false, "CONTAINER_NOT_EMPTY"
	end
	return true, nil
end

function Inv.canEquip(h: any, g: string, slot: string): (boolean, string?)
	local it = h.items[g]
	local d = it and defs[it.id]
	local accepts = SLOTS[slot]
	if not d then
		return false, "NO_ITEM"
	end
	if not accepts then
		return false, "BAD_SLOT"
	end
	if not accepts[d.kind] then
		return false, "WRONG_SLOT"
	end
	local cur = h.slots[slot]
	if cur and cur ~= g then
		return false, "SLOT_FULL"
	end
	-- armored rigs cannot be worn together with body armor
	if slot == "armor" and h.slots.rig and h.items[h.slots.rig] and defs[h.items[h.slots.rig].id].armor then
		return false, "ARMOR_CONFLICT"
	end
	if slot == "rig" and d.armor and h.slots.armor then
		return false, "ARMOR_CONFLICT"
	end
	return true, nil
end

local function ensureGrid(h: any, g: string)
	local it = h.items[g]
	if it and defs[it.id] and defs[it.id].grid and not h.grids[g] then
		h.grids[g] = {}
	end
end

-- merge stack g into stack target (same id). Returns ok, err (partial merges keep the remainder in place).
local function mergeInto(h: any, g: string, target: string): (boolean, string?)
	local it, t = h.items[g], h.items[target]
	local d = defs[it.id]
	local room = d.stack - t.n
	if room <= 0 then
		return false, "STACK_FULL"
	end
	local moved = math.min(room, it.n)
	t.n += moved
	it.n -= moved
	if it.n <= 0 then
		detach(h, g)
		h.items[g] = nil
		h.grids[g] = nil
	end
	return true, nil
end

-- Insert magazine mg into weapon wg (swapping: the old mag takes the new one's former spot when possible).
function Inv.insertMag(h: any, mg: string, wg: string): (boolean, string?)
	local m, w = h.items[mg], h.items[wg]
	if not m or not w then
		return false, "NO_ITEM"
	end
	local md, wd = defs[m.id], defs[w.id]
	if md.kind ~= "mag" or not wd.family or md.family ~= wd.family then
		return false, "INCOMPATIBLE"
	end
	if w.mag == mg then
		return true, nil
	end
	local k, cid, p = Inv.locate(h, mg)
	if k ~= "grid" then
		return false, "BAD_SOURCE"
	end
	local old = w.mag
	detach(h, mg)
	w.mag = mg
	if old then
		local od = defs[h.items[old].id]
		if k == "grid" and p and od.w == md.w and od.h == md.h then
			h.grids[cid][old] = { x = p.x, y = p.y, r = p.r }
		elseif not Inv.autoPlace(h, old, Inv.loadOrder(h)) then
			-- undo: nowhere to put the old magazine
			w.mag = old
			if k == "grid" and p then
				h.grids[cid][mg] = p
			end
			return false, "NO_SPACE"
		end
	end
	return true, nil
end

-- Move an item within one holder. dest = { c = cid, x, y, r } | { slot = name }.
-- opts.inRaid locks the secure container in its slot.
function Inv.move(h: any, g: string, dest: any, opts: any?): (boolean, string?)
	local it = h.items[g]
	if not it then
		return false, "NO_ITEM"
	end
	if type(dest) ~= "table" then
		return false, "BAD_INPUT"
	end
	if opts and opts.inRaid and h.slots.secure == g then
		return false, "SECURE_LOCKED"
	end
	local d = defs[it.id]
	ensureGrid(h, g)
	if dest.slot ~= nil then
		-- dropping a magazine or attachment onto the weapon in a slot loads / installs it (Tarkov)
		local occ = type(dest.slot) == "string" and h.slots[dest.slot] or nil
		local oit = occ and occ ~= g and h.items[occ]
		local od = oit and defs[oit.id]
		if od and od.weapon then
			if d.kind == "mag" and od.family and od.family == d.family then
				return Inv.insertMag(h, g, occ)
			elseif d.kind == "mod" then
				return Inv.attachMod(h, occ, g, Inv.loadOrder(h))
			end
		end
		local okE, errE = Inv.canEquip(h, g, dest.slot)
		if not okE then
			return false, errE
		end
		if h.slots[dest.slot] == g then
			return true, nil
		end
		detach(h, g)
		h.slots[dest.slot] = g
		return true, nil
	end
	local cid = dest.c
	if type(cid) ~= "string" or not h.grids[cid] then
		return false, "BAD_CONTAINER"
	end
	if not (Grid.isInt(dest.x) and Grid.isInt(dest.y)) then
		return false, "BAD_INPUT"
	end
	local r = dest.r == 1 and 1 or 0
	local target = Inv.itemAt(h, cid, dest.x, dest.y)
	if target and target ~= g then
		local t = h.items[target]
		local td = defs[t.id]
		if d.stack > 1 and t.id == it.id then
			return mergeInto(h, g, target)
		end
		if d.kind == "mag" and td.family and td.family == d.family and td.kind ~= "mag" then
			return Inv.insertMag(h, g, target)
		end
		if d.kind == "mod" and td.weapon then
			return Inv.attachMod(h, target, g, Inv.loadOrder(h))
		end
		if td.grid and target ~= g then
			return Inv.autoPlace(h, g, { target })
		end
	end
	local okC, errC = Inv.canEnter(h, g, cid)
	if not okC then
		return false, errC
	end
	local w, hh = Grid.dims(d.w, d.h, r)
	local cw, ch = Inv.dims(h, cid)
	local k, a = Inv.locate(h, g)
	local ignore = (k == "grid" and a == cid) and g or nil
	if not Grid.fits(cw, ch, h.grids[cid], sizer(h), dest.x, dest.y, w, hh, ignore) then
		return false, (target and target ~= g) and "OCCUPIED" or "NO_FIT"
	end
	detach(h, g)
	h.grids[cid][g] = { x = dest.x, y = dest.y, r = r }
	return true, nil
end

-- grids a player's quick actions fill, in Tarkov order: rig, pockets, backpack
function Inv.loadOrder(h: any): { string }
	local out = {}
	if h.slots.rig and h.grids[h.slots.rig] then
		table.insert(out, h.slots.rig)
	end
	if h.grids.pockets then
		table.insert(out, "pockets")
	end
	if h.slots.back and h.grids[h.slots.back] then
		table.insert(out, h.slots.back)
	end
	if h.grids.main then
		table.insert(out, "main")
	end
	return out
end

-- Move an item that is already in h (or freshly inserted without a location) to the first valid spot.
function Inv.autoPlace(h: any, g: string, order: { string }): (boolean, string?)
	local it = h.items[g]
	if not it then
		return false, "NO_ITEM"
	end
	local d = defs[it.id]
	ensureGrid(h, g)
	local lastErr = "NO_SPACE"
	for _, cid in order do
		local pl = h.grids[cid]
		if pl then
			local okC, errC = Inv.canEnter(h, g, cid)
			if okC then
				if d.stack > 1 then
					for og in pl do
						local o = h.items[og]
						if og ~= g and o and o.id == it.id and o.n < d.stack then
							mergeInto(h, g, og)
							if not h.items[g] then
								return true, nil
							end
						end
					end
				end
				local cw, ch = Inv.dims(h, cid)
				local own = pl[g]
				pl[g] = nil
				local x, y, r = Grid.findFree(cw, ch, pl, sizer(h), d.w, d.h)
				if own then
					pl[g] = own
				end
				if x then
					detach(h, g)
					pl[g] = { x = x, y = y, r = r }
					return true, nil
				end
			else
				lastErr = errC or lastErr
			end
		end
	end
	return false, lastErr
end

-- Add a new item record (not yet in h). Stacks merge first. Returns ok, info ("MERGED" when fully merged).
function Inv.place(h: any, g: string, it: any, order: { string }): (boolean, string?)
	if not defs[it.id] or h.items[g] then
		return false, "BAD_ITEM"
	end
	h.items[g] = it
	local okP, err = Inv.autoPlace(h, g, order)
	if not okP then
		if h.items[g] then
			h.items[g] = nil
			h.grids[g] = nil
		end
		return false, err
	end
	if not h.items[g] then
		return true, "MERGED"
	end
	return true, nil
end

-- Equip a new item record directly into a slot.
function Inv.placeSlot(h: any, g: string, it: any, slot: string): (boolean, string?)
	h.items[g] = it
	ensureGrid(h, g)
	local okE, err = Inv.canEquip(h, g, slot)
	if not okE then
		h.items[g] = nil
		h.grids[g] = nil
		return false, err
	end
	h.slots[slot] = g
	return true, nil
end

-- Remove an item and everything inside it; returns a bundle that Inv.give/restore can re-insert.
function Inv.take(h: any, g: string): any?
	local it = h.items[g]
	if not it then
		return nil
	end
	local k, a, b = Inv.locate(h, g)
	local subs = {}
	for _, sg in Inv.descendants(h, g) do
		local sk, sa, sb = Inv.locate(h, sg)
		table.insert(subs, { g = sg, it = h.items[sg], k = sk, a = sa, b = sb })
	end
	detach(h, g)
	for _, s in subs do
		h.items[s.g] = nil
	end
	for _, s in subs do
		h.grids[s.g] = nil
	end
	h.grids[g] = nil
	h.items[g] = nil
	return { g = g, it = it, subs = subs, from = { k = k, a = a, b = b } }
end

local function insertBundle(h: any, b: any)
	h.items[b.g] = b.it
	ensureGrid(h, b.g)
	for _, s in b.subs do
		h.items[s.g] = s.it
		ensureGrid(h, s.g)
	end
	for _, s in b.subs do
		if s.k == "grid" and h.grids[s.a] then
			h.grids[s.a][s.g] = { x = s.b.x, y = s.b.y, r = s.b.r }
		end
	end
end

local function removeBundle(h: any, b: any)
	for _, s in b.subs do
		h.items[s.g] = nil
		h.grids[s.g] = nil
	end
	detach(h, b.g)
	h.items[b.g] = nil
	h.grids[b.g] = nil
end

-- Re-insert a bundle exactly where Inv.take found it (rollback path).
function Inv.restore(h: any, b: any)
	insertBundle(h, b)
	local f = b.from
	if f.k == "grid" and h.grids[f.a] then
		h.grids[f.a][b.g] = { x = f.b.x, y = f.b.y, r = f.b.r }
	elseif f.k == "slot" then
		h.slots[f.a] = b.g
	elseif f.k == "mag" and h.items[f.a] then
		h.items[f.a].mag = b.g
	elseif f.k == "mod" and h.items[f.a] then
		h.items[f.a].mods = h.items[f.a].mods or {}
		h.items[f.a].mods[f.b] = b.g
	end
end

-- Insert a bundle at dest ({c,x,y,r} | {slot}) or auto (order). All-or-nothing.
function Inv.give(h: any, b: any, dest: any?, order: { string }?): (boolean, string?)
	if h.items[b.g] then
		return false, "GUID_COLLISION"
	end
	for _, s in b.subs do
		if h.items[s.g] then
			return false, "GUID_COLLISION"
		end
	end
	insertBundle(h, b)
	local okG, err
	if dest then
		okG, err = Inv.move(h, b.g, dest)
	else
		okG, err = Inv.autoPlace(h, b.g, order or Inv.loadOrder(h))
	end
	if okG and h.items[b.g] and not Inv.locate(h, b.g) then
		okG, err = false, "NO_LOCATION"
	end
	if not okG then
		if h.items[b.g] then
			removeBundle(h, b)
		end
		return false, err
	end
	return true, nil
end

-- Move g (and contents) from holder src to holder dst. Stack drops onto same-id stacks merge across holders.
function Inv.transfer(src: any, g: string, dst: any, dest: any?, order: { string }?, opts: any?): (boolean, string?)
	local it = src.items[g]
	if not it then
		return false, "NO_ITEM"
	end
	if opts and opts.inRaid and src.slots.secure == g then
		return false, "SECURE_LOCKED"
	end
	local d = defs[it.id]
	if dest and dest.c and d.stack > 1 and dst.grids[dest.c] and Grid.isInt(dest.x) and Grid.isInt(dest.y) then
		local tg = Inv.itemAt(dst, dest.c, dest.x, dest.y)
		local t = tg and dst.items[tg]
		if t and t.id == it.id then
			local room = d.stack - t.n
			if room <= 0 then
				return false, "STACK_FULL"
			end
			local moved = math.min(room, it.n)
			t.n += moved
			it.n -= moved
			if it.n <= 0 then
				detach(src, g)
				src.items[g] = nil
			end
			return true, nil
		end
	end
	local b = Inv.take(src, g)
	if not b then
		return false, "NO_ITEM"
	end
	local okG, err = Inv.give(dst, b, dest, order)
	if not okG then
		if b.it.n and b.it.n > 0 then
			Inv.restore(src, b)
		end
		return false, err
	end
	return true, nil
end

function Inv.split(h: any, g: string, n: number, dest: any): (boolean, string?)
	local it = h.items[g]
	if not it then
		return false, "NO_ITEM"
	end
	local d = defs[it.id]
	if d.stack <= 1 or not Grid.isInt(n) or n < 1 or n >= it.n then
		return false, "BAD_INPUT"
	end
	local ng = Util.guid()
	local copy = { id = it.id, n = n, fir = it.fir, fip = it.fip, rk = it.rk }
	h.items[ng] = copy
	local okM, err = Inv.move(h, ng, dest)
	if not okM or not Inv.locate(h, ng) then
		h.items[ng] = nil
		return false, err or "NO_FIT"
	end
	it.n -= n
	return true, nil
end

-- every item worn or carried (slots + pockets, recursively)
function Inv.equippedGuids(h: any): { string }
	local out = {}
	local function add(g: string)
		table.insert(out, g)
		Inv.descendants(h, g, out)
	end
	for g in h.grids.pockets or {} do
		add(g)
	end
	for _, g in h.slots do
		add(g)
	end
	return out
end
Inv.loadoutGuids = Inv.equippedGuids

function Inv.massOf(it: any): number
	local d = defs[it.id]
	if not d then
		return 0
	end
	local m = d.mass * ((d.stack > 1) and it.n or 1)
	if it.a and it.at and defs[it.at] then
		m += it.a * defs[it.at].mass
	end
	return m
end

function Inv.weight(h: any, guids: { string }?): number
	local m = 0
	for _, g in guids or Inv.equippedGuids(h) do
		local it = h.items[g]
		if it then
			m += Inv.massOf(it)
		end
	end
	return m
end

-- ── weapon attachments ────────────────────────────────────────────────────────
local Weapons = require(Shared.Weapons)

function Inv.canMod(h: any, wg: string, mg: string): (boolean, string?)
	local w, m = h.items[wg], h.items[mg]
	local wd, md = w and defs[w.id], m and defs[m.id]
	if not wd or not md or not md.mod or not wd.weapon then
		return false, "INCOMPATIBLE"
	end
	local spec = Weapons[wd.weapon]
	local slots = spec and spec.slots or {}
	local slotOk = slots[md.mod.slot]
	if not slotOk then
		return false, "NO_MOUNT"
	end
	if md.mod.caliber and slotOk ~= true and slotOk ~= md.mod.caliber then
		return false, "WRONG_CALIBER"
	end
	return true, nil
end

-- Install attachment mg on weapon wg (an occupied mount swaps: the old attachment is auto-placed).
function Inv.attachMod(h: any, wg: string, mg: string, order: { string }): (boolean, string?)
	local okM, err = Inv.canMod(h, wg, mg)
	if not okM then
		return false, err
	end
	local w = h.items[wg]
	local mount = defs[h.items[mg].id].mod.slot
	local k, cid, p = Inv.locate(h, mg)
	if k ~= "grid" then
		return false, "BAD_SOURCE"
	end
	local old = w.mods and w.mods[mount]
	detach(h, mg)
	w.mods = w.mods or {}
	w.mods[mount] = mg
	if old then
		local placed = Inv.autoPlace(h, old, order)
		if not placed then
			w.mods[mount] = old
			h.grids[cid][mg] = p
			return false, "NO_SPACE"
		end
	end
	return true, nil
end

function Inv.detachMod(h: any, wg: string, mount: string, order: { string }): (boolean, string?)
	local w = h.items[wg]
	local mg = w and w.mods and w.mods[mount]
	if not mg then
		return false, "NO_MOD"
	end
	detach(h, mg)
	local okP, err = Inv.autoPlace(h, mg, order)
	if not okP then
		w.mods = w.mods or {}
		w.mods[mount] = mg
		return false, err
	end
	return true, nil
end

-- combined handling modifiers from installed attachments
function Inv.modStats(h: any, wg: string): any
	local w = h.items[wg]
	local st = { ergo = 0, recoil = 1, loud = 1, zoom = nil, reflex = false, light = false, suppressed = false }
	for _, mg in (w and w.mods) or {} do
		local m = h.items[mg]
		local md = m and defs[m.id] and defs[m.id].mod
		if md then
			st.ergo += md.ergo or 0
			st.recoil *= md.recoil or 1
			st.loud *= md.loud or 1
			st.zoom = md.zoom or st.zoom
			st.reflex = st.reflex or md.reflex == true
			st.light = st.light or md.light == true
			st.suppressed = st.suppressed or (md.loud or 1) < 0.6
		end
	end
	return st
end

-- ── ammunition ─────────────────────────────────────────────────────────────────
-- capacity/caliber of a loadable target (magazine, or weapon with an internal tube)
function Inv.loadable(it: any): (number?, string?)
	local d = it and defs[it.id]
	if not d then
		return nil, nil
	end
	if d.kind == "mag" then
		return d.capacity, d.caliber
	end
	if (d.kind == "weapon" or d.kind == "pistol") and d.capacity and not d.family then
		return d.capacity, d.caliber
	end
	return nil, nil
end

-- Load up to `count` rounds from ammo stack ag into target tg. Returns rounds loaded, err.
function Inv.loadAmmo(h: any, tg: string, ag: string, count: number?): (number, string?)
	local t, am = h.items[tg], h.items[ag]
	if not t or not am then
		return 0, "NO_ITEM"
	end
	local cap, cal = Inv.loadable(t)
	local ad = defs[am.id]
	if not cap or ad.kind ~= "ammo" then
		return 0, "INCOMPATIBLE"
	end
	if ad.caliber ~= cal then
		return 0, "WRONG_CALIBER"
	end
	t.a = t.a or 0
	if t.a > 0 and t.at and t.at ~= am.id then
		return 0, "MIXED_AMMO"
	end
	local n = math.min(cap - t.a, am.n, count or math.huge)
	if n <= 0 then
		return 0, "FULL"
	end
	t.a += n
	t.at = am.id
	am.n -= n
	if am.n <= 0 then
		detach(h, ag)
		h.items[ag] = nil
	end
	return n, nil
end

-- Unload rounds back into stacks (placed by order); rounds that do not fit stay loaded.
function Inv.unloadAmmo(h: any, tg: string, order: { string }): (number, string?)
	local t = h.items[tg]
	if not t or not t.a or t.a <= 0 or not t.at then
		return 0, "EMPTY"
	end
	local d = defs[t.at]
	local moved = 0
	while t.a > 0 do
		local n = math.min(t.a, d.stack)
		local g = Util.guid()
		local okP = Inv.place(h, g, { id = t.at, n = n }, order)
		if not okP then
			break
		end
		t.a -= n
		moved += n
	end
	if t.a <= 0 then
		t.a, t.at = 0, nil
	end
	return moved, (moved == 0) and "NO_SPACE" or nil
end

-- fullest compatible magazine in the rig, then pockets (Tarkov quick reload ignores the backpack)
function Inv.bestMag(h: any, wg: string): string?
	local w = h.items[wg]
	local wd = w and defs[w.id]
	if not wd or not wd.family then
		return nil
	end
	local cur = w.mag and h.items[w.mag]
	local bestA = cur and (cur.a or 0) or -1
	local best = nil
	local sources = {}
	if h.slots.rig and h.grids[h.slots.rig] then
		table.insert(sources, h.slots.rig)
	end
	table.insert(sources, "pockets")
	for _, cid in sources do
		for g in h.grids[cid] or {} do
			local m = h.items[g]
			local md = m and defs[m.id]
			if md and md.kind == "mag" and md.family == wd.family and (m.a or 0) > bestA then
				best, bestA = g, m.a or 0
			end
		end
	end
	return best
end

function Inv.consume(h: any, g: string, n: number?)
	local it = h.items[g]
	if not it then
		return
	end
	it.n -= n or 1
	if it.n <= 0 then
		local b = Inv.take(h, g)
		if b then
			b.it.n = 0
		end
	end
end

function Inv.findKind(h: any, kind: string, grids: { string }?): string?
	for _, cid in grids or Inv.loadOrder(h) do
		for g in h.grids[cid] or {} do
			if defs[h.items[g].id].kind == kind then
				return g
			end
		end
	end
	return nil
end

function Inv.ownsKind(h: any, kinds: { [string]: boolean }): boolean
	for _, it in h.items do
		local d = defs[it.id]
		if d and kinds[d.kind] then
			return true
		end
	end
	return false
end

function Inv.value(h: any, guids: { string }?): number
	local v = 0
	if guids then
		for _, g in guids do
			local it = h.items[g]
			if it then
				v += Items.valueOf(it)
			end
		end
	else
		for _, it in h.items do
			v += Items.valueOf(it)
		end
	end
	return v
end

-- Full invariant check. Returns ok, message.
function Inv.check(h: any): (boolean, string?)
	local seen = {}
	local function mark(g: string, where: string): string?
		if not h.items[g] then
			return "missing item " .. g .. " in " .. where
		end
		if seen[g] then
			return "duplicate location for " .. g .. " (" .. seen[g] .. ", " .. where .. ")"
		end
		seen[g] = where
		return nil
	end
	for cid, pl in h.grids do
		if not BUILTIN[cid] then
			local owner = h.items[cid]
			if not owner or not defs[owner.id] or not defs[owner.id].grid then
				return false, "orphan grid " .. cid
			end
		end
		local cw, ch = Inv.dims(h, cid)
		for g, p in pl do
			local e = mark(g, cid)
			if e then
				return false, e
			end
			if g == cid then
				return false, "self-contained " .. g
			end
			local d = defs[h.items[g].id]
			if not d then
				return false, "unknown def in " .. cid
			end
			local w, hh = Grid.dims(d.w, d.h, p.r)
			if not Grid.fits(cw, ch, pl, sizer(h), p.x, p.y, w, hh, g) then
				return false, "overlap/out of bounds " .. g .. " in " .. cid
			end
		end
	end
	for s, g in h.slots do
		local e = mark(g, "slot:" .. s)
		if e then
			return false, e
		end
		local d = defs[h.items[g].id]
		if not SLOTS[s] or not SLOTS[s][d.kind] then
			return false, "wrong slot kind " .. s
		end
	end
	for g, it in h.items do
		local d = defs[it.id]
		if not d then
			return false, "unknown def " .. tostring(it.id)
		end
		if type(it.n) ~= "number" or it.n < 1 or it.n > d.stack then
			return false, "bad count " .. g
		end
		if d.grid and not h.grids[g] then
			return false, "container without grid " .. g
		end
		if it.a ~= nil then
			local cap = Inv.loadable(it)
			if not cap or it.a < 0 or it.a > cap then
				return false, "bad rounds " .. g
			end
		end
		if it.mag then
			local e = mark(it.mag, "weapon:" .. g)
			if e then
				return false, e
			end
		end
		if it.mods then
			for mount, mg in it.mods do
				local e = mark(mg, "mod:" .. mount)
				if e then
					return false, e
				end
				local md = h.items[mg] and defs[h.items[mg].id]
				if not md or not md.mod or md.mod.slot ~= mount then
					return false, "bad mod mount " .. mount
				end
			end
		end
	end
	for g in h.items do
		if not seen[g] then
			return false, "item without location " .. g
		end
		if Inv.isInside(h, g, g) then
			return false, "cycle at " .. g
		end
	end
	return true, nil
end

function Inv.newItem(id: string, n: number?, extra: any?): (string, any)
	local it = { id = id, n = n or 1 }
	local d = defs[id]
	if d and d.armor then
		it.dur = d.armor.dur
	end
	if d and d.med then
		if d.med.hp then
			it.hp = d.med.hp
		elseif d.med.uses and d.med.uses > 1 then
			it.uses = d.med.uses
		end
	end
	if d and d.key then
		it.uses = d.key.uses
	end
	if d and d.repair then
		it.pts = d.repair.points
	end
	if extra then
		for k, v in extra do
			it[k] = v
		end
	end
	return Util.guid(), it
end

return Inv
