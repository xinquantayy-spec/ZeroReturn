--!strict
-- Pure inventory logic over a "holder":
--   { items = {[guid] = {id, n, a?(mag rounds), mag?(guid of loaded mag), rk?(recovery kit)}},
--     stash = placements? (profile only), pockets = placements, bag = placements,
--     slots = {primary = guid?, bag = guid?} }
-- Invariant: every item guid has exactly one location (a grid placement, a slot, or loaded in a weapon).
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("EFB")
local Items = require(Shared.Items)
local Grid = require(Shared.Grid)
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons)
local Util = require(Shared.Util)

local Inv = {}
local defs = Items.defs
local GRIDS = { "stash", "pockets", "bag" }

function Inv.newHolder(withStash: boolean): any
	return { items = {}, stash = withStash and {} or nil, pockets = {}, bag = {}, slots = {} }
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

function Inv.dims(h: any, c: string): (number, number)
	if c == "stash" then
		if h.stash then
			return Config.STASH_W, Config.STASH_H
		end
		return 0, 0
	elseif c == "pockets" then
		return Config.POCKETS_W, Config.POCKETS_H
	elseif c == "bag" then
		local g = h.slots.bag
		local it = g and h.items[g]
		local d = it and defs[it.id]
		if d and d.bagW then
			return d.bagW, d.bagH
		end
	end
	return 0, 0
end

function Inv.locate(h: any, g: string): (string?, any)
	for _, c in GRIDS do
		local pl = h[c]
		if pl and pl[g] then
			return c, pl[g]
		end
	end
	for s, sg in h.slots do
		if sg == g then
			return "slot", s
		end
	end
	for wg, it in h.items do
		if it.mag == g then
			return "weapon", wg
		end
	end
	return nil, nil
end

local function detach(h: any, g: string)
	local where, info = Inv.locate(h, g)
	if where == "slot" then
		h.slots[info] = nil
	elseif where == "weapon" then
		h.items[info].mag = nil
	elseif where then
		h[where][g] = nil
	end
end

function Inv.itemAt(h: any, c: string, x: number, y: number): string?
	local pl = h[c]
	if not pl then
		return nil
	end
	return Grid.at(pl, sizer(h), x, y)
end

-- Move an owned item to dest = {c=grid, x, y, r} or {slot = "primary"|"bag"}.
function Inv.move(h: any, g: string, dest: any): (boolean, string?)
	local it = h.items[g]
	if not it then
		return false, "NO_ITEM"
	end
	local from, info = Inv.locate(h, g)
	if not from then
		return false, "NO_LOCATION"
	end
	local d = defs[it.id]
	if type(dest) ~= "table" then
		return false, "BAD_INPUT"
	end
	if dest.slot ~= nil then
		local s = dest.slot
		if s ~= "primary" and s ~= "bag" then
			return false, "BAD_SLOT"
		end
		if (s == "primary" and d.kind ~= "weapon") or (s == "bag" and d.kind ~= "bag") then
			return false, "WRONG_SLOT"
		end
		if h.slots[s] == g then
			return true, nil
		end
		if h.slots[s] then
			return false, "SLOT_FULL"
		end
		if from == "slot" and info == "bag" and next(h.bag) ~= nil then
			return false, "BAG_NOT_EMPTY"
		end
		detach(h, g)
		h.slots[s] = g
		return true, nil
	end
	local c = dest.c
	if c ~= "stash" and c ~= "pockets" and c ~= "bag" then
		return false, "BAD_CONTAINER"
	end
	if not h[c] then
		return false, "NO_ACCESS"
	end
	if not (Grid.isInt(dest.x) and Grid.isInt(dest.y)) then
		return false, "BAD_INPUT"
	end
	local r = dest.r == 1 and 1 or 0
	if d.kind == "bag" and c == "bag" then
		return false, "BAG_IN_BAG"
	end
	if from == "slot" and info == "bag" and next(h.bag) ~= nil then
		return false, "BAG_NOT_EMPTY"
	end
	-- stack merge onto an identical stackable item
	local target = Inv.itemAt(h, c, dest.x, dest.y)
	if target and target ~= g and d.stack > 1 and h.items[target].id == it.id then
		local t = h.items[target]
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
		end
		return true, nil
	end
	local w, hh = Grid.dims(d.w, d.h, r)
	local cw, ch = Inv.dims(h, c)
	local ignore = (from == c) and g or nil
	if not Grid.fits(cw, ch, h[c], sizer(h), dest.x, dest.y, w, hh, ignore) then
		return false, "NO_FIT"
	end
	detach(h, g)
	h[c][g] = { x = dest.x, y = dest.y, r = r }
	return true, nil
end

-- Move an owned item to the first free spot (merging stacks first) in the given grids.
function Inv.autoMove(h: any, g: string, order: { string }): (boolean, string?)
	local it = h.items[g]
	if not it then
		return false, "NO_ITEM"
	end
	local d = defs[it.id]
	for _, c in order do
		local pl = h[c]
		if pl and not (d.kind == "bag" and c == "bag") then
			if d.stack > 1 then
				for og, p in pl do
					local o = h.items[og]
					if og ~= g and o and o.id == it.id and o.n < d.stack then
						Inv.move(h, g, { c = c, x = p.x, y = p.y })
						if not h.items[g] then
							return true, nil
						end
					end
				end
			end
			local cw, ch = Inv.dims(h, c)
			local own = pl[g]
			if own then
				pl[g] = nil
			end
			local x, y, r = Grid.findFree(cw, ch, pl, sizer(h), d.w, d.h)
			if own then
				pl[g] = own
			end
			if x then
				return Inv.move(h, g, { c = c, x = x, y = y, r = r })
			end
		end
	end
	return false, "NO_SPACE"
end

-- Auto-place an item record that is NOT yet in the holder. order: list of grids to try.
function Inv.place(h: any, g: string, it: any, order: { string }): (boolean, string?)
	local d = defs[it.id]
	if not d or h.items[g] then
		return false, "BAD_ITEM"
	end
	if d.stack > 1 then
		for _, c in order do
			local pl = h[c]
			if pl then
				for og in pl do
					local o = h.items[og]
					if o.id == it.id and o.n < d.stack and it.n > 0 then
						local moved = math.min(d.stack - o.n, it.n)
						o.n += moved
						it.n -= moved
					end
				end
			end
		end
		if it.n <= 0 then
			return true, "MERGED"
		end
	end
	for _, c in order do
		local pl = h[c]
		if pl and not (d.kind == "bag" and c == "bag") then
			local cw, ch = Inv.dims(h, c)
			local x, y, r = Grid.findFree(cw, ch, pl, sizer(h), d.w, d.h)
			if x then
				h.items[g] = it
				pl[g] = { x = x, y = y, r = r }
				return true, c
			end
		end
	end
	return false, "NO_SPACE"
end

-- Remove an item (and the magazine loaded in it) and return a transferable bundle.
function Inv.take(h: any, g: string): any?
	local it = h.items[g]
	if not it then
		return nil
	end
	if h.slots.bag == g and next(h.bag) ~= nil then
		return nil
	end
	detach(h, g)
	h.items[g] = nil
	local bundle = { g = g, it = it }
	if it.mag and h.items[it.mag] then
		bundle.sub = { g = it.mag, it = h.items[it.mag] }
		h.items[it.mag] = nil
	end
	return bundle
end

-- Insert a bundle produced by Inv.take (auto-placed using order).
function Inv.give(h: any, bundle: any, order: { string }): (boolean, string?)
	local d = defs[bundle.it.id]
	if not d then
		return false, "BAD_ITEM"
	end
	local ok, err = Inv.place(h, bundle.g, bundle.it, order)
	if not ok then
		return false, err
	end
	if bundle.sub and h.items[bundle.g] then
		h.items[bundle.sub.g] = bundle.sub.it
		bundle.it.mag = bundle.sub.g
	end
	return true, nil
end

function Inv.loadoutGuids(h: any): { string }
	local out = {}
	local function add(g: string)
		table.insert(out, g)
		local it = h.items[g]
		if it and it.mag and h.items[it.mag] then
			table.insert(out, it.mag)
		end
	end
	for _, c in { "pockets", "bag" } do
		for g in h[c] do
			add(g)
		end
	end
	for _, g in h.slots do
		add(g)
	end
	return out
end

-- Swap in the fullest spare magazine from pockets/bag. Returns rounds now loaded.
function Inv.reload(h: any): (boolean, any)
	local wg = h.slots.primary
	local w = wg and h.items[wg]
	if not w then
		return false, "NO_WEAPON"
	end
	local wd = Weapons[defs[w.id].weapon]
	local cur = w.mag and h.items[w.mag]
	local curA = cur and cur.a or 0
	local best, bestC, bestP
	for _, c in { "pockets", "bag" } do
		for g, p in h[c] do
			local it = h.items[g]
			if it.id == wd.mag and (it.a or 0) > curA and (not best or it.a > h.items[best].a) then
				best, bestC, bestP = g, c, p
			end
		end
	end
	if not best then
		return false, "NO_MAG"
	end
	h[bestC][best] = nil
	local old = w.mag
	w.mag = best
	if old then
		h[bestC][old] = { x = bestP.x, y = bestP.y, r = bestP.r }
	end
	return true, h.items[best].a
end

-- Safehouse: top up every magazine from loose cartridges anywhere in the holder.
function Inv.fillMags(h: any): number
	local loaded = 0
	local stacks = {}
	for g, it in h.items do
		if it.id == "UC62" then
			table.insert(stacks, g)
		end
	end
	for _, it in h.items do
		local d = defs[it.id]
		if d.kind == "mag" then
			it.a = it.a or 0
			while it.a < d.capacity and #stacks > 0 do
				local sg = stacks[#stacks]
				local s = h.items[sg]
				local take = math.min(d.capacity - it.a, s.n)
				it.a += take
				s.n -= take
				loaded += take
				if s.n <= 0 then
					detach(h, sg)
					h.items[sg] = nil
					table.remove(stacks)
				end
			end
		end
	end
	return loaded
end

function Inv.findKind(h: any, kind: string, grids: { string }): string?
	for _, c in grids do
		for g in h[c] or {} do
			if defs[h.items[g].id].kind == kind then
				return g
			end
		end
	end
	return nil
end

function Inv.consume(h: any, g: string)
	local it = h.items[g]
	if not it then
		return
	end
	it.n -= 1
	if it.n <= 0 then
		detach(h, g)
		h.items[g] = nil
	end
end

function Inv.ownsId(h: any, id: string): boolean
	for _, it in h.items do
		if it.id == id then
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
	for _, c in GRIDS do
		local pl = h[c]
		if pl then
			local cw, ch = Inv.dims(h, c)
			for g, p in pl do
				local e = mark(g, c)
				if e then
					return false, e
				end
				local d = defs[h.items[g].id]
				local w, hh = Grid.dims(d.w, d.h, p.r)
				if not Grid.fits(cw, ch, pl, sizer(h), p.x, p.y, w, hh, g) then
					return false, "overlap/out of bounds " .. g .. " in " .. c
				end
			end
		end
	end
	for s, g in h.slots do
		local e = mark(g, "slot:" .. s)
		if e then
			return false, e
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
		if it.mag then
			local e = mark(it.mag, "weapon:" .. g)
			if e then
				return false, e
			end
		end
	end
	for g in h.items do
		if not seen[g] then
			return false, "item without location " .. g
		end
	end
	return true, nil
end

function Inv.newItem(id: string, n: number?, extra: any?): (string, any)
	local it = { id = id, n = n or 1 }
	if extra then
		for k, v in extra do
			it[k] = v
		end
	end
	return Util.guid(), it
end

return Inv
