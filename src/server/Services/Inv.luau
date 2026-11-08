--!strict
-- Inventory 2.0 (pure, no yields): Tarkov-style equipment slots, nested container grids, magazines in weapons.
-- holder = {
--   items = { [guid] = item },   item = { id, n, a?(rounds), at?(ammo id), mag?(guid), dur?, uses?, hp?, fir?, fip?, rk?,
--                                        mods?(slot -> part guid), sz?({ w, h }: a build's grid size, M14) }
--   grids = { [cid] = { [guid] = { x, y, r } } },   cid = "stash" | "pockets" | "main" | <container item guid>
--   slots = { [slot] = guid },   mainW?, mainH?  (world boxes / ground piles)
--   erev?  equipment revision: bumped on every slot change (stale equip requests are refused, M16)
-- }
-- Invariant: every item has exactly one location: a grid placement, a slot, a weapon's magazine well, or a slot
-- of a weapon part (M14 builds: a weapon base holds parts, parts hold parts; see WeaponParts), or a plate slot of a
-- vest or armoured rig (gameplay-2a: it.mods[front | back | lside | rside] = plate guid; see Plates).
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("ZR")
local Items = require(Shared.Items)
local Grid = require(Shared.Grid)
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Equipment = require(Shared.Equipment)
local WP = require(Shared.WeaponParts)
local Plates = require(Shared.Plates)

local Inv = {}
local defs = Items.defs
local SLOTS = Items.SLOTS
local BUILTIN = { stash = true, pockets = true, main = true }
Inv.BUILTIN = BUILTIN

-- grid size of an item as it lies: a build takes the size of its parts (it.sz), anything else its definition's
function Inv.sizeOf(it: any): (number, number)
	local sz = it and it.sz
	if sz then
		return sz[1], sz[2]
	end
	local d = it and defs[it.id]
	if not d then
		return 1, 1
	end
	return d.w, d.h
end

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
		return Inv.sizeOf(h.items[g])
	end
end

-- Double pockets (THE HOUNDS; Tarkov's Goons have five 1 x 2 pockets instead of four 1 x 1): the holder carries
-- pocketsW = 5, pocketsH = 2 and each column is one pocket, so an item lies one cell wide in it. Fills pocket by pocket.
local function pocketSpot(h: any, cw: number, ch: number, pl: any, iw: number, ih: number): (number?, number?, number?)
	local r = iw > 1 and 1 or 0
	local rw, rh = Grid.dims(iw, ih, r)
	if rw > 1 then
		return nil, nil, nil
	end
	for x = 1, cw do
		for y = 1, ch - rh + 1 do
			if Grid.fits(cw, ch, pl, sizer(h), x, y, rw, rh) then
				return x, y, r
			end
		end
	end
	return nil, nil, nil
end
Inv.sizer = sizer

function Inv.dims(h: any, cid: string): (number, number)
	if cid == "stash" then
		if h.grids.stash then
			return Config.STASH_W, h.stashH or Config.STASH_H -- storage racks add rows (hideout)
		end
		return 0, 0
	elseif cid == "pockets" then
		if h.grids.pockets then
			return h.pocketsW or Config.POCKETS_W, h.pocketsH or Config.POCKETS_H -- double pockets: see pocketSpot
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
				Inv.descendants(h, mg, list) -- parts hold parts (M14)
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

-- every equipment slot write goes through here: the revision lets the server refuse requests made against an
-- older equipment state and lets observers know the worn kit changed
local function setSlot(h: any, slot: string, g: string?)
	h.slots[slot] = g
	h.erev = (h.erev or 0) + 1
end
Inv.setSlot = setSlot

-- the root of the build g is on (follows magazine wells and part slots only, not containers)
function Inv.buildRoot(h: any, g: string): string
	local cur = g
	for _ = 1, 32 do
		local k, a = Inv.locate(h, cur)
		if k ~= "mod" and k ~= "mag" then
			return cur
		end
		cur = a
	end
	return cur
end

-- recompute a build's grid size (it.sz) from its parts; plain items keep their definition's size
local function measure(h: any, g: string)
	local it = h.items[g]
	if not it then
		return
	end
	if WP.measured(it) then
		local d = defs[it.id]
		local w, hh = WP.buildSize(h.items, g, d.w, d.h)
		if w and hh and (w ~= d.w or hh ~= d.h) then
			it.sz = { w, hh }
		else
			it.sz = nil
		end
	else
		it.sz = nil
	end
end

-- after a build changed: the item itself and the root of the build it is on
function Inv.resize(h: any, g: string)
	measure(h, g)
	local root = Inv.buildRoot(h, g)
	if root ~= g then
		measure(h, root)
	end
end

local function detach(h: any, g: string)
	local k, a, b = Inv.locate(h, g)
	if k == "grid" then
		h.grids[a][g] = nil
	elseif k == "slot" then
		setSlot(h, a, nil)
	elseif k == "mag" then
		h.items[a].mag = nil
		Inv.resize(h, a)
	elseif k == "mod" then
		h.items[a].mods[b] = nil
		if next(h.items[a].mods) == nil then
			h.items[a].mods = nil
		end
		Inv.resize(h, a)
		measure(h, g)
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
	local iw, ih = Inv.sizeOf(it)
	if cid == "pockets" and iw * ih > (h.pocketsH or Config.POCKETS_H) then
		return false, "TOO_BIG" -- a pocket holds a 1 x 1 item (a double pocket a 1 x 2)
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
	-- visual compatibility (M16): a full-cut helmet or a hard hat leaves no room for a headset, etc.
	local worn = {}
	for s, sg in h.slots do
		local wi = s ~= slot and sg ~= g and h.items[sg]
		if wi then
			worn[s] = wi.id
		end
	end
	local code = Equipment.conflict(worn, slot, it.id)
	if code then
		return false, code
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
	Inv.resize(h, wg)
	-- a bigger magazine makes the gun taller (Tarkov): it must still fit where it lies
	if not Inv.fitsWhereItLies(h, Inv.buildRoot(h, wg)) then
		w.mag = old
		Inv.resize(h, wg)
		if k == "grid" and p then
			h.grids[cid][mg] = p
		end
		return false, "NO_SPACE"
	end
	if old then
		local od = defs[h.items[old].id]
		local ow, oh = Grid.dims(od.w, od.h, p and p.r or 0)
		local cw, ch = 0, 0
		if k == "grid" and p then
			cw, ch = Inv.dims(h, cid)
		end
		if k == "grid" and p and od.w == md.w and od.h == md.h and Grid.fits(cw, ch, h.grids[cid], sizer(h), p.x, p.y, ow, oh, nil) then
			h.grids[cid][old] = { x = p.x, y = p.y, r = p.r }
		elseif not Inv.autoPlace(h, old, Inv.loadOrder(h)) then
			-- undo: nowhere to put the old magazine
			w.mag = old
			Inv.resize(h, wg)
			if k == "grid" and p then
				h.grids[cid][mg] = p
			end
			return false, "NO_SPACE"
		end
	end
	return true, nil
end

-- does the item still fit at its grid placement (after its build grew)? Items in slots or attached always do.
function Inv.fitsWhereItLies(h: any, g: string): boolean
	local k, cid, p = Inv.locate(h, g)
	if k ~= "grid" then
		return true
	end
	local iw, ih = Inv.sizeOf(h.items[g])
	local w, hh = Grid.dims(iw, ih, p.r)
	local cw, ch = Inv.dims(h, cid)
	return Grid.fits(cw, ch, h.grids[cid], sizer(h), p.x, p.y, w, hh, g)
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
	if Inv.vitalLocked(h, g, opts) then
		return false, "NEED_MULTITOOL"
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
				return Inv.attachMod(h, occ, g, (not (opts and opts.inRaid) and h.grids.stash) and { "stash" } or Inv.loadOrder(h), opts)
			end
		end
		-- a plate onto a worn vest: Tarkov 0.14 wants the vest taken off first
		if od and d.kind == "plate" and Plates.slotsOf(od) then
			return false, "TAKE_OFF_FIRST"
		end
		local okE, errE = Inv.canEquip(h, g, dest.slot)
		if not okE then
			return false, errE
		end
		if h.slots[dest.slot] == g then
			return true, nil
		end
		detach(h, g)
		setSlot(h, dest.slot, g)
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
		-- what a swap takes out goes where the modding menu sends it: the stash out of a raid, the carried grids in one
		local outOrder = (not (opts and opts.inRaid) and h.grids.stash) and { "stash" } or Inv.loadOrder(h)
		if d.kind == "mod" and WP.SLOTS[t.id] then
			-- a part dropped on a gun or a part goes into a free slot that takes it (Tarkov)
			return Inv.attachMod(h, target, g, outOrder, opts)
		end
		-- a plate dropped on a vest or armoured rig goes into a plate slot that takes it (a rig's grid otherwise)
		if d.kind == "plate" and Plates.slotsOf(td) and (Plates.freeSlot(td, t.mods, d) or Plates.swapSlot(td, t.mods, d)) then
			return Inv.attachPlateAny(h, target, g, outOrder, opts)
		end
		if td.grid and target ~= g then
			return Inv.autoPlace(h, g, { target })
		end
	end
	local okC, errC = Inv.canEnter(h, g, cid)
	if not okC then
		return false, errC
	end
	local iw, ih = Inv.sizeOf(it)
	local w, hh = Grid.dims(iw, ih, r)
	local cw, ch = Inv.dims(h, cid)
	if cid == "pockets" and ch > 1 and w > 1 then
		return false, "NO_FIT" -- a double pocket takes an item one cell wide (pocketSpot)
	end
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
				local iw, ih = Inv.sizeOf(it)
				local x, y, r
				if cid == "pockets" and ch > 1 then
					x, y, r = pocketSpot(h, cw, ch, pl, iw, ih)
				else
					x, y, r = Grid.findFree(cw, ch, pl, sizer(h), iw, ih)
				end
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

-- M14: a new weapon base comes as a whole gun: its default build, or it.preset (a trader's or a kit's build).
-- The preset's magazine is added (empty) only with it.presetMag; kits and starter loadouts add loaded ones.
-- it.bare keeps a stripped receiver.
function Inv.expandBuild(h: any, g: string)
	local it = h.items[g]
	if it and Plates.slotsOf(defs[it.id]) then
		Inv.expandArmour(h, g)
		return
	end
	if not it or not WP.isBase(it.id) or it.mods ~= nil or it.bare then
		it.preset, it.presetMag = nil, nil
		return
	end
	local pr = WP.META.presets[it.preset or it.id]
	if not pr or pr.base ~= it.id then
		pr = WP.META.presets[it.id]
	end
	local withMag = it.presetMag == true and it.mag == nil
	it.preset, it.presetMag = nil, nil
	if not pr then
		return
	end
	local function grow(node: any, t: any)
		for sname, sub in t[2] do
			if sname == "mag" then
				if withMag and node == it and defs[sub[1]] then
					local mg, mag = Inv.newItem(sub[1], 1)
					h.items[mg] = mag
					it.mag = mg
				end
			elseif defs[sub[1]] then
				local pg, part = Inv.newItem(sub[1], 1)
				h.items[pg] = part
				node.mods = node.mods or {}
				node.mods[sname] = pg
				grow(part, sub)
			end
		end
	end
	grow(it, pr.tree)
	Inv.resize(h, g)
end

-- Tarkov's SORT button: the stash rearranged by kind (weapons, gear, parts, ammo, meds...), larger items first;
-- all or nothing (the old layout stays if the new one does not fit)
local SORT_KIND = {
	weapon = 1, pistol = 2, melee = 3, armor = 4, plate = 4.5, helmet = 5, rig = 6, backpack = 7, secure = 8, headwear = 9, headset = 10,
	facecover = 11, eyewear = 12, mod = 13, mag = 14, ammo = 15, grenade = 16, med = 17, food = 18, repair = 19, key = 20, loot = 21, quest = 22,
}
function Inv.sortStash(h: any): (boolean, string?)
	local pl = h.grids and h.grids.stash
	if not pl then
		return false, "NO_ITEM"
	end
	local list = {}
	for g in pl do
		if h.items[g] then
			table.insert(list, g)
		end
	end
	local function rank(g)
		local it = h.items[g]
		local d = defs[it.id]
		local w, hh = Inv.sizeOf(it)
		return SORT_KIND[d.kind] or 50, -(w * hh), d.name
	end
	table.sort(list, function(a, b)
		local a1, a2, a3 = rank(a)
		local b1, b2, b3 = rank(b)
		if a1 ~= b1 then
			return a1 < b1
		elseif a2 ~= b2 then
			return a2 < b2
		elseif a3 ~= b3 then
			return a3 < b3
		end
		return a < b
	end)
	local cw, ch = Inv.dims(h, "stash")
	local fresh = {}
	local function size(g)
		return Inv.sizeOf(h.items[g])
	end
	for _, g in list do
		local w, hh = Inv.sizeOf(h.items[g])
		local x, y, r = Grid.findFree(cw, ch, fresh, size, w, hh)
		if not x then
			return false, "NO_SPACE"
		end
		fresh[g] = { x = x, y = y, r = r }
	end
	table.clear(pl)
	for g, p in fresh do
		pl[g] = p
	end
	return true, nil
end

-- Add a new item record (not yet in h). Stacks merge first. Returns ok, info ("MERGED" when fully merged).
function Inv.place(h: any, g: string, it: any, order: { string }): (boolean, string?)
	if not defs[it.id] or h.items[g] then
		return false, "BAD_ITEM"
	end
	h.items[g] = it
	Inv.expandBuild(h, g)
	local okP, err = Inv.autoPlace(h, g, order)
	if not okP then
		if h.items[g] then
			for _, sg in Inv.descendants(h, g) do
				h.items[sg] = nil
				h.grids[sg] = nil
			end
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
	Inv.expandBuild(h, g)
	local okE, err = Inv.canEquip(h, g, slot)
	if not okE then
		for _, sg in Inv.descendants(h, g) do
			h.items[sg] = nil
			h.grids[sg] = nil
		end
		h.items[g] = nil
		h.grids[g] = nil
		return false, err
	end
	setSlot(h, slot, g)
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
	-- a build that lost parts on the way (insurance returns) takes its new size
	measure(h, b.g)
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
		setSlot(h, f.a, b.g)
	elseif f.k == "mag" and h.items[f.a] then
		h.items[f.a].mag = b.g
		Inv.resize(h, f.a)
	elseif f.k == "mod" and h.items[f.a] then
		h.items[f.a].mods = h.items[f.a].mods or {}
		h.items[f.a].mods[f.b] = b.g
		Inv.resize(h, f.a)
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
	if Inv.vitalLocked(src, g, opts) then
		return false, "NEED_MULTITOOL"
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

-- ── weapon parts (M14, Tarkov-style modding; docs/weapons/WEAPON_MODDING.md) ──────────────────────
local function isVital(id: string?): boolean
	local p = id and WP.parts[id]
	return p ~= nil and WP.CATS[p.cat] ~= nil and WP.CATS[p.cat].group == "vital"
end
Inv.isVital = isVital

-- carrying a multitool anywhere on you (Tarkov 0.14) lets you change vital parts in a raid
function Inv.hasTool(h: any): boolean
	for g, it in h.items do
		if it.id == WP.MULTITOOL and Inv.locate(h, g) ~= nil then
			return true
		end
	end
	return false
end

-- an attached vital part cannot leave its gun during a raid without a multitool
function Inv.vitalLocked(h: any, g: string, opts: any?): boolean
	if not (opts and opts.inRaid) then
		return false
	end
	local it = h.items[g]
	if not it or not isVital(it.id) then
		return false
	end
	local k = Inv.locate(h, g)
	return k == "mod" and not Inv.hasTool(h)
end

-- is `inner` part of the build under `outer` (through part slots and magazine wells)?
local function inBuild(h: any, outer: string, inner: string): boolean
	local cur = inner
	for _ = 1, 32 do
		if cur == outer then
			return true
		end
		local k, a = Inv.locate(h, cur)
		if k ~= "mod" and k ~= "mag" then
			return false
		end
		cur = a
	end
	return false
end

-- put part mg into slot `sname` of item pg (a weapon or a part). An occupied slot swaps: the part there (with
-- its own parts) goes to the grids in `order`. Fails when the part does not fit the slot, conflicts with the
-- build, would make the gun too big for where it lies, or is a vital part in a raid without a multitool.
function Inv.attachPart(h: any, pg: string, sname: string, mg: string, order: { string }, opts: any?): (boolean, string?)
	local parent, part = h.items[pg], h.items[mg]
	if not parent or not part then
		return false, "NO_ITEM"
	end
	if Plates.slotsOf(defs[parent.id]) then
		return Inv.attachPlate(h, pg, sname, mg, order, opts)
	end
	if type(sname) ~= "string" then
		return false, "BAD_INPUT"
	end
	if pg == mg or inBuild(h, mg, pg) then
		return false, "SELF"
	end
	local okF, errF = WP.fits(parent.id, sname, part.id)
	if not okF then
		return false, errF
	end
	local old = parent.mods and parent.mods[sname]
	if old == mg then
		return true, nil
	end
	local root = Inv.buildRoot(h, pg)
	if WP.conflict(h.items, root, part.id, old) then
		return false, "CONFLICT"
	end
	if opts and opts.inRaid and (isVital(part.id) or (old and h.items[old] and isVital(h.items[old].id))) and not Inv.hasTool(h) then
		return false, "NEED_MULTITOOL"
	end
	if opts and opts.inRaid and Inv.vitalLocked(h, mg, opts) then
		return false, "NEED_MULTITOOL"
	end
	-- a shell tube that would hold fewer shells than are loaded: unload first
	local rootIt = h.items[root]
	if old and rootIt and (rootIt.a or 0) > 0 and sname == "tube" and (WP.parts[part.id].capacity or 0) < rootIt.a then
		return false, "UNLOAD_FIRST"
	end
	local sk, sa, sb = Inv.locate(h, mg)
	detach(h, mg)
	parent.mods = parent.mods or {}
	parent.mods[sname] = mg
	Inv.resize(h, pg)
	local ok = Inv.fitsWhereItLies(h, root)
	if ok and old and h.items[old] then
		measure(h, old)
		ok = (Inv.autoPlace(h, old, order))
	end
	if not ok then
		-- undo: the old part back in the slot (or the slot empty), the new one back where it was
		parent.mods[sname] = old
		if parent.mods and next(parent.mods) == nil then
			parent.mods = nil
		end
		if sk == "grid" and h.grids[sa] then
			h.grids[sa][mg] = sb
		elseif sk == "slot" then
			setSlot(h, sa, mg)
		elseif sk == "mod" and h.items[sa] then
			h.items[sa].mods = h.items[sa].mods or {}
			h.items[sa].mods[sb] = mg
			Inv.resize(h, sa)
		end
		measure(h, mg)
		Inv.resize(h, pg)
		return false, "NO_SPACE"
	end
	return true, nil
end

-- take the part out of slot `sname` of pg (with the parts on it) and put it into the grids in `order`
function Inv.detachPart(h: any, pg: string, sname: string, order: { string }, opts: any?): (boolean, string?)
	local parent = h.items[pg]
	if parent and Plates.slotsOf(defs[parent.id]) then
		return Inv.detachPlate(h, pg, sname, order, opts)
	end
	local mg = parent and parent.mods and parent.mods[sname]
	if not mg or not h.items[mg] then
		return false, "NO_MOD"
	end
	if Inv.vitalLocked(h, mg, opts) then
		return false, "NEED_MULTITOOL"
	end
	local root = Inv.buildRoot(h, pg)
	if sname == "tube" and h.items[root] and (h.items[root].a or 0) > 0 then
		return false, "UNLOAD_FIRST"
	end
	detach(h, mg)
	local okP, err = Inv.autoPlace(h, mg, order)
	if not okP then
		parent.mods = parent.mods or {}
		parent.mods[sname] = mg
		Inv.resize(h, pg)
		measure(h, mg)
		return false, err
	end
	return true, nil
end

-- a part dropped onto a gun (or onto a part): the first free slot on that build that takes it, else a slot
-- whose part it can replace
function Inv.attachMod(h: any, wg: string, mg: string, order: { string }, opts: any?): (boolean, string?)
	local m = h.items[mg]
	if not h.items[wg] or not m then
		return false, "NO_ITEM"
	end
	if defs[m.id] and defs[m.id].kind == "plate" then
		return Inv.attachPlateAny(h, wg, mg, order, opts)
	end
	if not WP.parts[m.id] then
		return false, "INCOMPATIBLE"
	end
	local root = Inv.buildRoot(h, wg)
	local pg, sname = WP.freeSlot(h.items, root, m.id)
	if not pg then
		pg, sname = WP.swapSlot(h.items, root, m.id)
	end
	if not pg or not sname then
		return false, "NO_SLOT"
	end
	return Inv.attachPart(h, pg, sname, mg, order, opts)
end

-- the old name: take whatever is in slot `mount` of wg off
function Inv.detachMod(h: any, wg: string, mount: string, order: { string }, opts: any?): (boolean, string?)
	return Inv.detachPart(h, wg, mount, order, opts)
end

-- handling of a weapon's build (WeaponParts.stats): ergonomics delta, recoil / accuracy / velocity / loudness
-- multipliers against the default build, sights, light, laser, suppressed, operable
function Inv.modStats(h: any, wg: string): any
	return WP.stats(h.items, wg)
end

-- ── plates (Tarkov 0.14, decision gameplay-2a; the rules in Plates.luau) ─────────────────────────────────────────────
-- A vest or armoured rig keeps its plates in it.mods[front | back | lside | rside]. Tarkov: plates go in and out only
-- while the vest is not worn ("take it off first"); a plate fits a slot by its position and its family.

-- is g worn (in an equipment slot)?
function Inv.isWorn(h: any, g: string): boolean
	return Inv.locate(h, g) == "slot"
end

-- put plate pg into slot `slot` of carrier cg; a plate already there goes to the grids in `order`
function Inv.attachPlate(h: any, cg: string, slot: string, pg: string, order: { string }, _opts: any?): (boolean, string?)
	local c, p = h.items[cg], h.items[pg]
	if not c or not p then
		return false, "NO_ITEM"
	end
	if type(slot) ~= "string" then
		return false, "BAD_INPUT"
	end
	local okF, errF = Plates.fits(defs[c.id], slot, defs[p.id])
	if not okF then
		return false, errF
	end
	if Inv.isWorn(h, cg) then
		return false, "TAKE_OFF_FIRST"
	end
	local old = c.mods and c.mods[slot]
	if old == pg then
		return true, nil
	end
	local sk, sa, sb = Inv.locate(h, pg)
	if sk == "slot" or sk == "mag" then
		return false, "BAD_SOURCE"
	end
	if sk == "mod" and sa and Inv.isWorn(h, sa) then
		return false, "TAKE_OFF_FIRST" -- out of another vest that is worn
	end
	detach(h, pg)
	c.mods = c.mods or {}
	c.mods[slot] = pg
	if old and h.items[old] and not Inv.autoPlace(h, old, order) then
		-- undo: the old plate back in, the new one back where it was
		c.mods[slot] = old
		if sk == "grid" and h.grids[sa] then
			h.grids[sa][pg] = sb
		elseif sk == "mod" and h.items[sa] then
			h.items[sa].mods = h.items[sa].mods or {}
			h.items[sa].mods[sb] = pg
		end
		return false, "NO_SPACE"
	end
	return true, nil
end

-- a plate dropped on a carrier: the first empty slot that takes it, else a filled one it can replace
function Inv.attachPlateAny(h: any, cg: string, pg: string, order: { string }, opts: any?): (boolean, string?)
	local c, p = h.items[cg], h.items[pg]
	if not c or not p then
		return false, "NO_ITEM"
	end
	local cd, pd = defs[c.id], defs[p.id]
	if not Plates.slotsOf(cd) then
		return false, "INCOMPATIBLE"
	end
	local slot = Plates.freeSlot(cd, c.mods, pd) or Plates.swapSlot(cd, c.mods, pd)
	if not slot then
		return false, "NO_SLOT"
	end
	return Inv.attachPlate(h, cg, slot, pg, order, opts)
end

-- take the plate out of slot `slot` of carrier cg into the grids in `order`
function Inv.detachPlate(h: any, cg: string, slot: string, order: { string }, _opts: any?): (boolean, string?)
	local c = h.items[cg]
	local pg = c and c.mods and c.mods[slot]
	if not pg or not h.items[pg] then
		return false, "NO_MOD"
	end
	if Inv.isWorn(h, cg) then
		return false, "TAKE_OFF_FIRST"
	end
	detach(h, pg)
	local okP, err = Inv.autoPlace(h, pg, order)
	if not okP then
		c.mods = c.mods or {}
		c.mods[slot] = pg
		return false, err
	end
	return true, nil
end

-- A new vest comes with its default plates (Tarkov: traders sell, and loot and bodies carry, the preset), as worn as the
-- vest itself. it.pf marks it done, so a vest a player emptied stays empty; it.bare keeps a new one empty.
function Inv.expandArmour(h: any, g: string)
	local it = h.items[g]
	local d = it and defs[it.id]
	local slots = d and Plates.slotsOf(d)
	if not slots or it.pf or it.bare then
		return
	end
	it.pf = true
	local frac = math.clamp((it.dur or d.armor.dur) / math.max(d.armor.dur, 1e-6), 0, 1)
	for _, s in Plates.SLOTS do
		local e = slots[s]
		local pd = e and e.def and defs[e.def]
		if pd and not (it.mods and it.mods[s]) then
			local pg, p = Inv.newItem(e.def, 1)
			p.dur = Plates.tenth(pd.armor.dur * frac)
			p.fir, p.fip, p.ins, p.isr = it.fir, it.fip, it.ins, it.isr
			h.items[pg] = p
			it.mods = it.mods or {}
			it.mods[s] = pg
		end
	end
end

-- Old saves (before gameplay-2a): a vest, rig or helmet held one durability against its old maximum. It becomes its new
-- form once: every part at the share it had, a vest's default plates at the same share. Returns how many items changed.
-- Runs on every holder Health.attach sees (the profile in the bunker, raid kits) and wherever Profiles.load calls it.
function Inv.migrateArmour(h: any): number
	if not (h and h.items) then
		return 0
	end
	local list = {}
	for g, it in h.items do
		local d = defs[it.id]
		if d and Plates.multi(d) and it.sd == nil then
			table.insert(list, g)
		end
	end
	for _, g in list do
		local it = h.items[g]
		local d = defs[it.id]
		local old = Plates.OLD_DUR[it.id] or d.armor.dur
		local f = math.clamp((it.dur or old) / old, 0, 1)
		local fm = it.dmax and math.clamp(it.dmax / old, 0, 1) or nil
		Plates.initParts(it, d, f)
		if fm then
			it.dmax = Plates.tenth(d.armor.dur * fm)
		end
		if Plates.slotsOf(d) and not it.pf then
			Inv.expandArmour(h, g)
		end
	end
	return #list
end

-- shells a tube-fed gun holds (its tube part), or a magazine's / internal magazine's capacity
function Inv.capacityOf(h: any, g: string): number?
	local it = h.items[g]
	local d = it and defs[it.id]
	if not d then
		return nil
	end
	if d.kind == "mag" then
		return d.capacity
	end
	if (d.kind == "weapon" or d.kind == "pistol") and not d.family then
		local s = WP.SLOTS[it.id]
		if s and s.tube then
			local tg = it.mods and it.mods.tube
			local t = tg and h.items[tg]
			local p = t and WP.parts[t.id]
			return p and p.capacity or 0
		end
		return d.capacity
	end
	return nil
end

-- ── ammunition ─────────────────────────────────────────────────────────────────
-- capacity/caliber of a loadable target (magazine, or weapon with an internal tube)
function Inv.loadable(it: any, h: any?, g: string?): (number?, string?)
	local d = it and defs[it.id]
	if not d then
		return nil, nil
	end
	if d.kind == "mag" then
		return d.capacity, d.caliber
	end
	if (d.kind == "weapon" or d.kind == "pistol") and d.capacity and not d.family then
		-- tube-fed guns hold what their tube part holds (M14)
		if h and g then
			return Inv.capacityOf(h, g), d.caliber
		end
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
	local cap, cal = Inv.loadable(t, h, tg)
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
			local iw, ih = Inv.sizeOf(h.items[g])
			local w, hh = Grid.dims(iw, ih, p.r)
			if not Grid.fits(cw, ch, pl, sizer(h), p.x, p.y, w, hh, g) then
				return false, "overlap/out of bounds " .. g .. " in " .. cid
			end
			if cid == "pockets" and ch > 1 and w > 1 then
				return false, "across two pockets " .. g
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
			local cap = Inv.loadable(it, h, g)
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
			for sname, mg in it.mods do
				local e = mark(mg, "mod:" .. sname)
				if e then
					return false, e
				end
				local m = h.items[mg]
				local fits
				if Plates.slotsOf(d) then
					fits = m ~= nil and (Plates.fits(d, sname, defs[m.id])) -- a plate in a vest's plate slot
				else
					fits = m ~= nil and (WP.fits(it.id, sname, m.id))
				end
				if not fits then
					return false, "part " .. tostring(m and m.id) .. " does not fit " .. it.id .. "." .. sname
				end
			end
		end
		-- a build's grid size follows its parts (a part that sits on a gun has no size of its own)
		if WP.measured(it) then
			if Inv.locate(h, g) ~= "mod" then
				local d = defs[it.id]
				local mw, mh = WP.buildSize(h.items, g, d.w, d.h)
				local sw, sh = Inv.sizeOf(it)
				if mw and (mw ~= sw or mh ~= sh) then
					return false, string.format("stale size %s %dx%d (parts say %dx%d)", it.id, sw, sh, mw, mh)
				end
			end
		elseif it.sz then
			return false, "size on a plain item " .. g
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
		-- each built-in part at full durability (Plates: it.sd per part, it.dur their sum)
		Plates.initParts(it, d, 1)
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
		-- a durability given for the whole armour (kits, loot) spreads over its parts at the same share
		if d and d.armor and type(extra.dur) == "number" and extra.sd == nil and Plates.multi(d) then
			Plates.initParts(it, d, extra.dur / math.max(d.armor.dur, 1e-6))
		end
	end
	return Util.guid(), it
end

return Inv
