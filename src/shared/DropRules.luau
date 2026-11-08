--!nonstrict
-- What an inventory drag-and-drop would do (audit ui.9), pure functions only: a mirror of the server's Inv.move and
-- Inv.transfer rules for the green / red fit cue while dragging (Inventory.luau) and for the move request it sends.
-- Views are holder snapshots ({ items, grids, slots, stashH?, pocketsW?, pocketsH?, mainW?, mainH? }), the same shape
-- as the server's holders, so UiTests checks these answers against the real Inv.move. The server stays the judge: a
-- red cue still sends the request, the cue only says what to expect.
local Shared = script.Parent
local Items = require(Shared.Items)
local Grid = require(Shared.Grid)
local Config = require(Shared.Config)
local WP = require(Shared.WeaponParts)
local Equipment = require(Shared.Equipment)
local Plates = require(Shared.Plates)

local Drop = {}
local defs = Items.defs
local BUILTIN = { stash = true, pockets = true, main = true }

-- an item's grid size as it lies, unturned: a build carries its own (it.sz), anything else its definition's
local function sizeOf(it)
	if it and it.sz then
		return it.sz[1], it.sz[2]
	end
	local d = it and defs[it.id]
	return d and d.w or 1, d and d.h or 1
end

-- a grid's size in a view (Inv.dims)
function Drop.dims(view, cid)
	local grids = view.grids or {}
	if cid == "stash" then
		return grids.stash and Config.STASH_W or 0, grids.stash and (view.stashH or Config.STASH_H) or 0
	elseif cid == "pockets" then
		return grids.pockets and (view.pocketsW or Config.POCKETS_W) or 0, grids.pockets and (view.pocketsH or Config.POCKETS_H) or 0
	elseif cid == "main" then
		return view.mainW or 0, view.mainH or 0
	end
	local c = view.items[cid]
	local cd = c and defs[c.id]
	if cd and cd.grid then
		return cd.grid.w, cd.grid.h
	end
	return 0, 0
end

-- where g is in a view (Inv.locate): "grid", cid, placement | "slot", name | "mag", gun | "mod", item, mount
local function locateIn(view, g)
	for cid, pl in view.grids or {} do
		if pl[g] then
			return "grid", cid, pl[g]
		end
	end
	for s, sg in view.slots or {} do
		if sg == g then
			return "slot", s
		end
	end
	for wg, w in view.items do
		if w.mag == g then
			return "mag", wg
		end
		for mount, mg in w.mods or {} do
			if mg == g then
				return "mod", wg, mount
			end
		end
	end
	return nil
end

-- the item g sits in or on (Inv.parentOf): a container, or the gun or part it is fitted to
local function parentIn(view, g)
	local k, a = locateIn(view, g)
	if (k == "grid" and not BUILTIN[a]) or k == "mag" or k == "mod" then
		return a
	end
	return nil
end

-- the top of the build g is on: magazine wells and part slots, not containers (Inv.buildRoot)
local function buildRoot(view, g)
	local cur = g
	for _ = 1, 32 do
		local k, a = locateIn(view, cur)
		if k ~= "mag" and k ~= "mod" then
			return cur
		end
		cur = a
	end
	return cur
end

-- does a part go on the build item tg is part of, into a free slot or in place of one (Inv.attachMod)
local function partFits(view, tg, pid)
	if not WP.parts[pid] then
		return false
	end
	local root = buildRoot(view, tg)
	return WP.freeSlot(view.items, root, pid) ~= nil or WP.swapSlot(view.items, root, pid) ~= nil
end

local function emptyGrid(view, g)
	local pl = view.grids and view.grids[g]
	return pl == nil or next(pl) == nil
end

-- may item g of src go into grid cid of dst, size aside (Inv.canEnter)
local function canEnter(src, g, it, dst, cid)
	local d = defs[it.id]
	if not (d and dst.grids and dst.grids[cid]) or cid == g then
		return false
	end
	if d.kind == "secure" and cid ~= "stash" then
		return false
	end
	local iw, ih = sizeOf(it)
	if cid == "pockets" and iw * ih > (dst.pocketsH or Config.POCKETS_H) then
		return false -- a pocket holds a 1 x 1 item (a double pocket a 1 x 2)
	end
	if not BUILTIN[cid] then
		if src == dst then
			-- not into itself or into something it holds
			local cur = cid
			for _ = 1, 32 do
				cur = parentIn(dst, cur)
				if not cur then
					break
				elseif cur == g then
					return false
				end
			end
		end
		local c = dst.items[cid]
		local cd = c and defs[c.id]
		if not cd then
			return false
		end
		if cd.kind == "secure" and not Items.SECURE_KINDS[d.kind] then
			return false
		end
		if d.grid and not emptyGrid(src, g) then
			return false
		end
		if d.kind == "backpack" and cd.kind == "backpack" then
			return false
		end
	elseif cid == "pockets" and d.grid and not emptyGrid(src, g) then
		return false
	end
	return true
end

-- is there room for item g in container cid of dst: a stack tops up stacks of its kind first, then a free spot either
-- way round (Inv.autoPlace; double pockets take an item one cell wide). `free`: an item whose cells count as empty (it
-- will have moved away first)
local function roomIn(src, g, it, dst, cid, free)
	if not canEnter(src, g, it, dst, cid) then
		return false
	end
	local d = defs[it.id]
	local pl = dst.grids[cid]
	if d.stack > 1 then
		local need = it.n or 1
		for og in pl do
			local o = dst.items[og]
			if og ~= g and o and o.id == it.id and (o.n or 1) < d.stack then
				need -= d.stack - (o.n or 1)
				if need <= 0 then
					return true
				end
			end
		end
	end
	local others = pl
	if (src == dst and pl[g]) or (free and pl[free]) then
		others = table.clone(pl)
		others[g] = nil -- its own place does not count: it moves
		if free then
			others[free] = nil
		end
	end
	local cw, ch = Drop.dims(dst, cid)
	local iw, ih = sizeOf(it)
	local function sz(gg)
		return sizeOf(dst.items[gg])
	end
	if cid == "pockets" and ch > 1 then
		local rw, rh = Grid.dims(iw, ih, iw > 1 and 1 or 0)
		if rw > 1 then
			return false
		end
		for x = 1, cw do
			for y = 1, ch - rh + 1 do
				if Grid.fits(cw, ch, others, sz, x, y, rw, rh) then
					return true
				end
			end
		end
		return false
	end
	return Grid.findFree(cw, ch, others, sz, iw, ih) ~= nil
end

-- the grids a part or plate taken out goes to (Inv.move): the stash out of a raid, else the worn rig's grid, the
-- pockets, the worn pack's grid and a body's main grid (Inv.loadOrder)
local function outOrder(view, inRaid)
	local gr, sl = view.grids or {}, view.slots or {}
	if not inRaid and gr.stash then
		return { "stash" }
	end
	local out = {}
	if sl.rig and gr[sl.rig] then
		table.insert(out, sl.rig)
	end
	if gr.pockets then
		table.insert(out, "pockets")
	end
	if sl.back and gr[sl.back] then
		table.insert(out, sl.back)
	end
	if gr.main then
		table.insert(out, "main")
	end
	return out
end

-- a plate dropped on a vest or armoured rig lying in a grid (Inv.attachPlateAny): into the plate slot `slot`; a plate
-- taken out of a worn vest is refused (take it off first), and a plate it replaces must find room where taken-out
-- things go
local function plateOk(src, g, dst, tg, slot, inRaid)
	local k, a = locateIn(src, g)
	if k == "slot" or k == "mag" then
		return false
	end
	if k == "mod" then
		for _, sg in src.slots or {} do
			if sg == a then
				return false -- TAKE_OFF_FIRST
			end
		end
	end
	local t = dst.items[tg]
	local old = t and t.mods and t.mods[slot]
	local o = old and old ~= g and dst.items[old]
	if not o then
		return true
	end
	for _, cid in outOrder(dst, inRaid) do
		if roomIn(dst, old, o, dst, cid, src == dst and g or nil) then
			return true
		end
	end
	return false -- NO_SPACE
end

-- dropped onto item tg of dst: merge into its stack, load a gun's magazine well, fit a part on a build, put a plate in
-- a vest, or go inside a container, in the order Inv.move tries them; anything else is refused there (the cell is
-- taken)
local function combineOk(src, g, it, dst, tg, inRaid)
	local d = defs[it.id]
	local t = dst.items[tg]
	local td = t and defs[t.id]
	if not td then
		return false
	end
	if d.stack > 1 and t.id == it.id then
		return (t.n or 1) < d.stack
	end
	if d.kind == "mag" and td.family and td.family == d.family and td.kind ~= "mag" then
		return true -- Inv.insertMag (a longer magazine that leaves the gun no room where it lies is refused there)
	end
	if d.kind == "mod" and WP.SLOTS[t.id] then
		return partFits(dst, tg, it.id)
	end
	if d.kind == "plate" and Plates.slotsOf(td) then
		local slot = Plates.freeSlot(td, t.mods, d) or Plates.swapSlot(td, t.mods, d)
		if slot then
			return plateOk(src, g, dst, tg, slot, inRaid)
		end
	end
	if td.grid then
		return roomIn(src, g, it, dst, tg)
	end
	return false
end

-- worn in slot `slot` of dst (Inv.move's slot branch, Inv.canEquip): a magazine or a part dropped on a worn gun goes on
-- it; else the slot must take the kind, be free, keep the armour rule and clear what the worn gear blocks
local function slotOk(g, it, dst, slot)
	local d = defs[it.id]
	local slots = dst.slots or {}
	local occ = slots[slot]
	local oit = occ and occ ~= g and dst.items[occ]
	local od = oit and defs[oit.id]
	if od and od.weapon then
		if d.kind == "mag" and od.family and od.family == d.family then
			return true
		elseif d.kind == "mod" then
			return partFits(dst, occ, it.id)
		end
	end
	if od and d.kind == "plate" and Plates.slotsOf(od) then
		return false, "TAKE_OFF_FIRST" -- a plate onto a worn vest: Tarkov 0.14 wants the vest taken off first
	end
	local accepts = Items.SLOTS[slot]
	if not (accepts and accepts[d.kind]) or (occ and occ ~= g) then
		return false
	end
	local rig = slots.rig and dst.items[slots.rig]
	if slot == "armor" and rig and defs[rig.id] and defs[rig.id].armor then
		return false -- an armoured rig and body armour are not worn together
	end
	if slot == "rig" and d.armor and slots.armor then
		return false
	end
	local worn = {}
	for s, sg in slots do
		local wi = s ~= slot and sg ~= g and dst.items[sg]
		if wi then
			worn[s] = wi.id
		end
	end
	return Equipment.conflict(worn, slot, it.id) == nil
end

-- the item (other than g) covering cell x, y of grid pl, with its placement
local function itemAt(dst, pl, g, x, y)
	for og, p in pl do
		if og ~= g then
			local w, h = sizeOf(dst.items[og])
			w, h = Grid.dims(w, h, p.r)
			if x >= p.x and x < p.x + w and y >= p.y and y < p.y + h then
				return og, p
			end
		end
	end
	return nil, nil
end

-- the plan for dropping item g of `src` at `tgt` in `dst`. tgt: { kind = "slot", slot } or { kind = "cell", cid, x, y,
-- occupied? } (a tile under the cursor names its item); dd: the drag, { r, r0, grabX, grabY } (r0: its turn when the
-- drag began). Returns nil (no target) or { dest (the move request's), ok (expected to be taken), why? (the server's
-- refusal, where the cue knows it), noop?, and the cells it takes: slot | cid, x, y, w, h }
function Drop.plan(src, g, dst, tgt, dd, inRaid)
	local it = src and src.items and src.items[g]
	local d = it and defs[it.id]
	if not (d and dst and dst.items and tgt) then
		return nil
	end
	local locked = inRaid == true and src.slots ~= nil and src.slots.secure == g -- the secure container stays on in a raid
	if tgt.kind == "slot" then
		local okS, why = slotOk(g, it, dst, tgt.slot)
		return { slot = tgt.slot, dest = { slot = tgt.slot }, ok = not locked and okS == true, why = why }
	end
	local cid = tgt.cid
	local pl = dst.grids and dst.grids[cid]
	if not pl then
		return nil
	end
	local function footprint(gg, p)
		local w, h = sizeOf(dst.items[gg])
		return Grid.dims(w, h, p.r)
	end
	-- back over its own tile: nothing moves
	if src == dst and tgt.occupied == g then
		local p = pl[g]
		if not p then
			return nil
		end
		local w, h = footprint(g, p)
		return { noop = true, ok = true, cid = cid, x = p.x, y = p.y, w = w, h = h }
	end
	-- over another item: combine with it, sent as a drop on its corner cell
	local occ, op = nil, nil
	if tgt.occupied and tgt.occupied ~= g and pl[tgt.occupied] then
		occ, op = tgt.occupied, pl[tgt.occupied]
	else
		occ, op = itemAt(dst, pl, g, tgt.x, tgt.y)
	end
	if occ then
		local w, h = footprint(occ, op)
		return { cid = cid, x = op.x, y = op.y, w = w, h = h, dest = { c = cid, x = op.x, y = op.y, r = 0 },
			ok = not locked and combineOk(src, g, it, dst, occ, inRaid) }
	end
	-- over free cells: the item lies with the cell it was grabbed by under the cursor, turned as it is now (R)
	local gx, gy = dd.grabX or 0, dd.grabY or 0
	if dd.r ~= (dd.r0 or dd.r) then
		gx, gy = gy, gx
	end
	local r = dd.r == 1 and 1 or 0
	local x, y = math.max(1, tgt.x - gx), math.max(1, tgt.y - gy)
	local dest = { c = cid, x = x, y = y, r = r }
	-- Inv.move looks at the cell the item's corner lands on: another item there makes it a combine with that item
	local at, ap = itemAt(dst, pl, g, x, y)
	if at then
		local w, h = footprint(at, ap)
		return { cid = cid, x = ap.x, y = ap.y, w = w, h = h, dest = dest, ok = not locked and combineOk(src, g, it, dst, at, inRaid) }
	end
	local iw, ih = sizeOf(it)
	local w, h = Grid.dims(iw, ih, r)
	local cw, ch = Drop.dims(dst, cid)
	local function sz(gg)
		return sizeOf(dst.items[gg])
	end
	local ok = not locked and canEnter(src, g, it, dst, cid) and not (cid == "pockets" and ch > 1 and w > 1)
		and Grid.fits(cw, ch, pl, sz, x, y, w, h, src == dst and g or nil)
	return { cid = cid, x = x, y = y, w = w, h = h, dest = dest, ok = ok == true }
end

return Drop
