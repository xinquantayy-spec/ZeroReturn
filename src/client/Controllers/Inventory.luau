--!nonstrict
-- Tarkov-style inventory: equipment slots, pockets, nested rig/backpack/secure grids, stash, containers, bodies.
-- Mouse: drag & drop (R rotates while dragging), right-click menu, Ctrl+click quick move, Alt+click equip.
-- Touch / gamepad: select an item, then a cell or slot, or use the action buttons. The server is authoritative;
-- the UI re-renders from snapshots ("me" = my holder, "c:<cid>" = the open container or body).
local UIS = game:GetService("UserInputService")
local DEBUG = game:GetService("RunService"):IsStudio()
local GuiService = game:GetService("GuiService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Weapons = require(Shared.Weapons)
local WP = require(Shared.WeaponParts)
local Grid = require(Shared.Grid)
local Util = require(Shared.Util)
local Maps = require(Shared.Maps)
local TD = require(Shared.TraderData)
local Drop = require(Shared.DropRules) -- what a drag-and-drop would do (the fit cue, audit ui.9)
local Plates = require(Shared.Plates) -- plate slots of vests and armoured rigs (gameplay-2a)

local Inventory = { open = false, tab = "GEAR", cpanel = "GEAR" }
-- ui-3a: on a phone (under about 500 pt of height) one panel at a time behind a rail: EQUIPMENT, BAGS, STASH (or LOOT)
local compact = false
local COMPACT_H = 500
local ctx, K
local gui, panel, menu, ghost
local loot = nil
local selected = nil -- { g, ref }
local rot = 0
local searchText = "" -- the stash search (Tarkov 0.16.7): non-matching items are dimmed
local SEARCH_CAT = {
	weapon = "weapons", pistol = "weapons", melee = "weapons", mod = "parts", mag = "magazines", ammo = "ammo", grenade = "grenades",
	armor = "gear armor", helmet = "gear helmets", rig = "gear rigs", backpack = "gear backpacks", headwear = "gear", headset = "gear headsets", plate = "gear armor plates",
	facecover = "gear", eyewear = "gear eyewear glasses", secure = "gear", med = "medical meds", food = "provisions food", key = "keys", loot = "barter", quest = "quest",
}
local gridTargets, slotTargets = {}, {}
local drag = nil
local busy = false
local openTabBtn = nil -- the open character tab's button: the gamepad's default selection (audit ui.5)
local focusTab = false -- the next draw puts the gamepad selection on the open tab (a tab change), not where it was
local status = nil -- { text, t0, dur }
local hoverG = nil
local hover = nil -- drop target under the cursor, from engine MouseEnter events (matches what the user sees)
local updateCue -- the green / red fit cue (set below; audit ui.9)
local targetOf = setmetatable({}, { __mode = "k" }) -- cell, tile or slot button -> its drop target (the gamepad's cue)

local function hoverOn(obj, target)
	targetOf[obj] = target
	obj.MouseEnter:Connect(function()
		hover = target
		if updateCue then
			updateCue()
		end
	end)
	obj.MouseLeave:Connect(function()
		if hover == target then
			hover = nil
			if updateCue then
				updateCue()
			end
		end
	end)
end

local defs = Items.defs
-- grid size of an item as it lies (M14: a gun's build sets its size, it.sz from the server)
local function sizeOf(it)
	if it and it.sz then
		return it.sz[1], it.sz[2]
	end
	local d = it and defs[it.id]
	return d and d.w or 1, d and d.h or 1
end
-- Tarkov's gear column, in slot cells (7 wide): earpiece, headwear, face cover; eyewear beside the body armour (the cells on
-- its right stay free for an armband); the weapons on sling and on back; holster and scabbard. The rig, backpack and secure
-- container head their grids in the middle column.
local SLOT_LAYOUT = {
	{ "ears", 0, 0, 2, 2 }, { "head", 2, 0, 3, 2 }, { "face", 5, 0, 2, 2 },
	{ "eyes", 0, 2, 2, 2 }, { "armor", 2, 2, 3, 3 },
	{ "primary", 0, 5, 7, 2 }, { "secondary", 0, 7, 7, 2 },
	{ "holster", 0, 9, 4, 2 }, { "melee", 4, 9, 3, 2 },
}
local SLOT_ROWS = 11

-- Tarkov's character tabs along the top of the screen: GEAR (the inventory itself), HEALTH, SKILLS, MASTERING, TASKS (in
-- and out of a raid since audit ui.14; Tarkov's character screen has it in the main menu too), and OVERALL out of a raid
local function tabList(inRaid)
	local tabs = { "GEAR", "HEALTH", "SKILLS", "MASTERING", "TASKS" }
	if not inRaid then
		table.insert(tabs, "OVERALL")
	end
	return tabs
end

-- ── helpers ────────────────────────────────────────────────────────────────────
local function data()
	return ctx.State.data
end

local function known(id)
	local d = data()
	return (d and d.known and d.known[id]) or Items.knownByDefault(id)
end

local function viewOf(ref)
	if ref == "me" then
		return data()
	end
	if loot and ref == "c:" .. loot.cid then
		return loot
	end
	return nil
end

local function req(payload)
	if busy then
		return nil
	end
	busy = true
	-- equipment changes carry the equipment revision they were made against (M16); a stale one is refused
	local d = data()
	if d and (payload.op == "equip" or (payload.op == "move" and type(payload.dest) == "table" and payload.dest.slot ~= nil)) then
		payload.rev = d.erev or 0
	end
	local res = ctx.State.req("inv", payload)
	busy = false
	if res and res.ok and d and type(res.data) == "table" and type(res.data.erev) == "number" then
		d.erev = res.data.erev
	end
	if res and not res.ok and not res.msg then
		ctx.State.toast(string.gsub(res.code or "FAILED", "_", " "), "warn")
	end
	return res
end

local function locate(view, g)
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
	return nil
end
Inventory.locate = locate

local function massOf(view, g, depth)
	local it = view.items[g]
	local d = it and defs[it.id]
	if not d then
		return 0
	end
	local m = d.mass * ((d.stack > 1) and it.n or 1)
	if it.a and it.at and defs[it.at] then
		m += it.a * defs[it.at].mass
	end
	if it.mag then
		m += massOf(view, it.mag, (depth or 0) + 1)
	end
	-- the plates in a vest or armoured rig weigh with it (gameplay-2a)
	if it.mods and Plates.slotsOf(d) then
		for _, pg in it.mods do
			if view.items[pg] then
				m += massOf(view, pg, (depth or 0) + 1)
			end
		end
	end
	if view.grids and view.grids[g] and (depth or 0) < 6 then
		for cg in view.grids[g] do
			m += massOf(view, cg, (depth or 0) + 1)
		end
	end
	return m
end

local function gearWeight(view)
	local m = 0
	for _, g in view.slots or {} do
		m += massOf(view, g)
	end
	for g in (view.grids and view.grids.pockets) or {} do
		m += massOf(view, g)
	end
	return m
end

local function inside(obj, pos)
	local p, s = obj.AbsolutePosition, obj.AbsoluteSize
	return pos.X >= p.X and pos.Y >= p.Y and pos.X < p.X + s.X and pos.Y < p.Y + s.Y
end

-- every column keeps its place when the screen is drawn again (a move, new server state, a tab change); a redraw used
-- to send a long stash back to the top, and the gamepad selection found again could sit out of view
local scrollAt = {} -- [column key] = CanvasPosition
local function keepScroll(sf, key)
	task.defer(function()
		if sf.Parent and scrollAt[key] then
			sf.CanvasPosition = scrollAt[key]
		end
	end)
	sf:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		scrollAt[key] = sf.CanvasPosition
	end)
end

-- the pointer in GUI space: GetMouseLocation counts from the top of the screen, a frame's AbsolutePosition from under
-- Roblox's top bar (the GUI inset), so without this the context menu and the drag picture sat 58 px under the cursor
local function mouse()
	return UIS:GetMouseLocation() - GuiService:GetGuiInset()
end

local function cornerText(view, it)
	local d = defs[it.id]
	if not known(it.id) then
		return ""
	end
	if d.kind == "weapon" or d.kind == "pistol" then
		if d.family then
			local m = it.mag and view.items[it.mag]
			return m and "MAG" or "NO MAG"
		end
		-- tube-fed: the tube part holds the shells (M14)
		local cap = d.capacity or 0
		if WP.SLOTS[it.id] and WP.SLOTS[it.id].tube then
			local tg = it.mods and it.mods.tube
			local t = tg and view.items[tg]
			cap = (t and WP.parts[t.id] and WP.parts[t.id].capacity) or 0
		end
		return string.format("%d/%d", it.a or 0, cap)
	elseif d.kind == "mag" then
		return string.format("%d/%d", it.a or 0, d.capacity)
	elseif d.stack > 1 then
		return tostring(it.n)
	elseif d.armor and it.dur then
		return string.format("%d/%d", math.ceil(it.dur), d.armor.dur)
	elseif d.med and d.med.hp and it.hp then
		return string.format("%d/%d", math.ceil(it.hp), d.med.hp)
	elseif it.uses then
		return tostring(it.uses)
	end
	return ""
end

Inventory.cornerText = cornerText

-- the item under the mouse ({ g, ref }), for quick-slot binding
function Inventory.hovered()
	return hoverG
end

local function findFree(view, cid, w, h)
	local pl = view.grids and view.grids[cid]
	if not pl then
		return nil
	end
	local cw, ch
	if cid == "stash" then
		cw, ch = Config.STASH_W, view.stashH or Config.STASH_H
	elseif cid == "pockets" then
		cw, ch = view.pocketsW or Config.POCKETS_W, view.pocketsH or Config.POCKETS_H
	elseif cid == "main" then
		cw, ch = view.mainW or 0, view.mainH or 0
	else
		local c = view.items[cid]
		local cd = c and defs[c.id]
		if not (cd and cd.grid) then
			return nil
		end
		cw, ch = cd.grid.w, cd.grid.h
	end
	local function sz(gg)
		return sizeOf(view.items[gg])
	end
	if cid == "pockets" and ch > 1 then
		-- five double pockets (THE HOUNDS' bodies): one column is one pocket, an item lies one cell wide (Inv pocketSpot)
		local r = w > 1 and 1 or 0
		local rw, rh = Grid.dims(w, h, r)
		if rw > 1 then
			return nil
		end
		for x = 1, cw do
			for y = 1, ch - rh + 1 do
				if Grid.fits(cw, ch, pl, sz, x, y, rw, rh) then
					return x, y, r
				end
			end
		end
		return nil
	end
	local x, y, r = Grid.findFree(cw, ch, pl, sz, w, h)
	return x, y, r
end

-- ── actions ────────────────────────────────────────────────────────────────────
local function quick(ref, g)
	local inRaid = ctx.State.inRaid()
	if ref == "me" then
		if loot then
			return req({ op = "quick", g = g, from = "me", to = "c:" .. loot.cid })
		end
		if not inRaid then
			local k, cid = locate(data(), g)
			if k == "grid" and cid == "stash" then
				return req({ op = "quick", g = g, from = "me" })
			end
			return req({ op = "quick", g = g, from = "me", to = "stash" })
		end
		return req({ op = "quick", g = g, from = "me" })
	end
	return req({ op = "quick", g = g, from = ref, to = "me" })
end

-- client mirror of the server's Inv.attachMod: a free slot on the build that takes the part, else one it can replace
local function modSlot(view, wg, pid)
	local pg, sname = WP.freeSlot(view.items, wg, pid)
	if pg then
		return pg, sname, false
	end
	pg, sname = WP.swapSlot(view.items, wg, pid)
	return pg, sname, pg ~= nil
end

-- client mirror of Settle.insurable (EFT wiki, Insurance): no secure containers, melee weapons (but the cult's knife),
-- consumables (meds, food, ammo), keys, quest items, recovery-kit items or secure-container contents
local NOT_INSURABLE = { secure = true, quest = true, ammo = true, med = true, food = true, key = true, melee = true }
local INSURABLE_IDS = { RITUAL_KNIFE = true }
local Progress = require(Shared.Progress) -- Charisma's discount on insurance (Settle charges the same)
local function holderOf(view, g)
	local k, cid = locate(view, g)
	if k == "grid" then
		return (cid ~= "stash" and cid ~= "pockets" and cid ~= "main") and cid or nil
	elseif k == "slot" then
		return nil
	end
	for wg, w in view.items do
		if w.mag == g then
			return wg
		end
		for _, mg in w.mods or {} do
			if mg == g then
				return wg
			end
		end
	end
	return nil
end

local function insurable(view, g)
	local it = view.items[g]
	local d = it and defs[it.id]
	if not d or it.rk or (NOT_INSURABLE[d.kind] and not INSURABLE_IDS[it.id]) then
		return false
	end
	local sg = view.slots and view.slots.secure
	local cur = g
	for _ = 1, 10 do
		if cur == sg then
			return false
		end
		cur = holderOf(view, cur)
		if not cur then
			return true
		end
	end
	return true
end

-- what Settle.insure would charge with one insurer (gameplay-6b): the item, its magazine, every part on it and, for a
-- container, everything inside that can be insured (Inv.descendants on the server)
local function insureCost(view, g, isr)
	local uid = game:GetService("Players").LocalPlayer.UserId
	local list, items = { g }, {}
	local i = 1
	while i <= #list and i <= 400 do
		local it = view.items[list[i]]
		if it then
			if it.mag then
				table.insert(list, it.mag)
			end
			for _, mg in it.mods or {} do
				table.insert(list, mg)
			end
			for cg in (view.grids and view.grids[list[i]]) or {} do
				table.insert(list, cg)
			end
		end
		i += 1
	end
	for _, x in list do
		local xi = view.items[x]
		if xi and xi.ins ~= uid and insurable(view, x) then
			table.insert(items, xi)
		end
	end
	return TD.insureTotal(isr, items, Progress.bonus(view.econ and view.econ.skills, "charisma"))
end

local function actionsFor(ref, g)
	local view = viewOf(ref)
	local it = view and view.items[g]
	if not it then
		return {}
	end
	local d = defs[it.id]
	local inRaid = ctx.State.inRaid()
	local mine = ref == "me"
	local list = {}
	local function add(label, fn, tone)
		local e = { label = label, fn = fn, tone = tone }
		table.insert(list, e)
		return e
	end
	if not known(it.id) then
		add("EXAMINE", function()
			req({ op = "examine", g = g, from = ref })
		end, "good")
	end
	add(mine and (loot and "MOVE TO " .. string.upper(loot.label) or (inRaid and "AUTO-ARRANGE" or "QUICK MOVE")) or "TAKE", function()
		quick(ref, g)
	end)
	local k = locate(view, g)
	if Items.SLOTS and (d.kind == "weapon" or d.kind == "pistol" or d.kind == "melee" or d.kind == "helmet" or d.kind == "headwear" or d.kind == "headset" or d.kind == "facecover" or d.kind == "eyewear" or d.kind == "armor" or d.kind == "rig" or d.kind == "backpack" or (d.kind == "secure" and not inRaid)) and k ~= "slot" then
		add("EQUIP", function()
			req({ op = "equip", g = g, from = ref, to = "me" })
		end)
	end
	if mine and (d.kind == "med" or d.kind == "food" or (d.kind == "flare" and inRaid)) and known(it.id) then
		add("USE", function()
			req({ op = "use", g = g })
		end, "good")
	end
	-- M11 part B: the gunsmith repair kit on a worn weapon (out of raid)
	if mine and not inRaid and (d.kind == "weapon" or d.kind == "pistol") and (it.wear or 100) < (it.wmax or 100) - 0.5 then
		for kg, kit in view.items do
			local kd = defs[kit.id]
			if kd and kd.repair and (kit.pts or kd.repair.points) >= 1 then
				add(string.format("REPAIR (KIT %d)", math.floor(kit.pts or kd.repair.points)), function()
					req({ op = "repairKit", g = g, kit = kg })
				end, "good")
				break
			end
		end
	end
	if mine and (d.kind == "mag" or ((d.kind == "weapon" or d.kind == "pistol") and d.capacity and not d.family)) then
		if (it.a or 0) > 0 then
			add("UNLOAD AMMO", function()
				req({ op = "unload", g = g })
			end)
		end
		local cal = d.caliber
		local seen = {}
		for ag, a in view.items do
			local ad = defs[a.id]
			if ad.kind == "ammo" and ad.caliber == cal and not seen[a.id] and locate(view, ag) == "grid" then
				seen[a.id] = true
				add("LOAD " .. ad.short .. " (" .. a.n .. ")", function()
					req({ op = "load", g = g, ammo = ag })
				end)
			end
		end
	end
	if mine and (d.kind == "weapon" or d.kind == "pistol") and it.mag then
		add("REMOVE MAGAZINE", function()
			req({ op = "quick", g = it.mag, from = "me", to = (not inRaid) and "stash" or nil })
		end)
	end
	-- weapon modding (M14, Tarkov): the modding screen for a gun (or a part with slots); a loose part goes
	-- straight onto a gun you have where a slot takes it
	if mine and (WP.isBase(it.id) or (WP.SLOTS[it.id] and d.kind == "mod")) and ctx.Modding then
		add("MODDING", function()
			ctx.Modding.open(g)
		end, "good")
	end
	-- goggles (Tarkov): onto a helmet's or head strap's night-vision mount, and off again
	if mine and d.kind == "nvg" and locate(view, g) == "grid" then
		for hg, h in view.items do
			if h ~= it and WP.SLOTS[h.id] and WP.SLOTS[h.id].mount and locate(view, hg) ~= nil and WP.fits(h.id, "mount", it.id) then
				local cur = h.mods and h.mods.mount
				add((cur and "SWAP ONTO " or "INSTALL ON ") .. defs[h.id].short, function()
					req({ op = "mod", g = hg, slot = "mount", mod = g })
				end, "good")
			end
		end
	end
	if mine and WP.SLOTS[it.id] and WP.SLOTS[it.id].mount and it.mods and it.mods.mount and view.items[it.mods.mount] then
		add("REMOVE " .. defs[view.items[it.mods.mount].id].short, function()
			req({ op = "unmod", g = g, slot = "mount" })
		end)
	end
	-- plates (Tarkov 0.14, gameplay-2a): into a slot of a vest or armoured rig that is not worn, and out again. Tarkov
	-- wants a worn vest taken off first; the menu says so instead of offering it. Same menu on mouse, touch and gamepad.
	local SLOT_SHORT = { front = "FRONT", back = "BACK", lside = "LEFT SIDE", rside = "RIGHT SIDE" }
	if mine and d.kind == "plate" and locate(view, g) == "grid" then
		local wornHint = nil
		for cg, c in view.items do
			local cd = defs[c.id]
			local slots = cd and Plates.slotsOf(cd)
			local where = slots and locate(view, cg)
			if where then
				for _, s in Plates.SLOTS do
					if slots[s] and Plates.fits(cd, s, d) then
						if where == "slot" then
							wornHint = wornHint or cd.short
						else
							local cur = c.mods and c.mods[s] and view.items[c.mods[s]]
							add(string.format("%s %s  ·  %s", cur and "SWAP INTO" or "INSERT INTO", cd.short, SLOT_SHORT[s]), function()
								req({ op = "mod", g = cg, slot = s, mod = g })
							end, "good")
						end
					end
				end
			end
		end
		if wornHint then
			add("TAKE OFF " .. wornHint .. " TO PUT IN PLATES", function() end)
		end
	end
	if mine and Plates.slotsOf(d) and it.mods then
		local worn = locate(view, g) == "slot"
		local any = false
		for _, s in Plates.SLOTS do
			local p = it.mods[s] and view.items[it.mods[s]]
			if p and defs[p.id] then
				any = true
				if not worn then
					add(string.format("REMOVE %s PLATE (%s)", SLOT_SHORT[s], defs[p.id].short), function()
						req({ op = "unmod", g = g, slot = s })
					end)
				end
			end
		end
		if worn and any then
			add("TAKE IT OFF TO CHANGE PLATES", function() end)
		end
	end
	if mine and d.kind == "mod" and locate(view, g) == "grid" then
		for wg, w in view.items do
			if w ~= it and WP.isBase(w.id) and locate(view, wg) ~= nil then
				local pg, sname, swap = modSlot(view, wg, it.id)
				if pg then
					add((swap and "SWAP ONTO " or "INSTALL ON ") .. defs[w.id].short, function()
						req({ op = "mod", g = pg, slot = sname, mod = g })
					end, "good")
				end
			end
		end
	end
	if mine and d.stack > 1 and it.n > 1 then
		add("SPLIT IN HALF", function()
			local _, cid = locate(view, g)
			local x, y, r = findFree(view, cid, d.w, d.h)
			if not x then
				ctx.State.toast("NO SPACE TO SPLIT", "warn")
				return
			end
			req({ op = "split", g = g, n = math.floor(it.n / 2), dest = { c = cid, x = x, y = y, r = r } })
		end)
	end
	if mine and inRaid and view.slots.secure ~= g then
		-- in a raid Tarkov's discard (Del) puts the item on the ground: our DROP (audit ui.9)
		local function drop()
			req({ op = "drop", g = g })
		end
		local entry = add("DROP", drop, "warn")
		entry.discard = drop
	end
	if mine and not inRaid and insurable(view, g) then
		-- EFT's choice of insurers (gameplay-6b), each with its price: VOS returns in 2-3 h, HALE in 1-2 h, BRAM in 10-20 min
		-- (TraderData.INSURERS); the same entries on mouse, touch and gamepad
		for _, isr in TD.INSURER_LIST do
			local cost = insureCost(view, g, isr)
			if cost > 0 then
				add(string.format("INSURE · %s (%s)  -%s %s", TD.defs[isr].name, (TD.insureSpan(isr)), Util.commas(cost), Config.CURRENCY), function()
					req({ op = "insure", g = g, isr = isr })
				end, "good")
			end
		end
	end
	if mine and not inRaid and view.slots.secure ~= g then
		-- sold to the trader paying the most (containers must be empty; mags and attachments go with a weapon)
		local karma = view.econ and view.econ.karma
		local tid = known(it.id) and not it.rk and TD.bestBuyer(it, karma)
		if tid then
			if view.grids[g] and next(view.grids[g]) then
				add("EMPTY IT TO SELL", function() end)
			else
				local price = TD.sellPrice(tid, it, karma) or 0
				if it.mag and view.items[it.mag] then
					price += TD.sellPrice(tid, view.items[it.mag], karma) or TD.sellPrice("fence", view.items[it.mag], karma) or 0
				end
				for _, mg in it.mods or {} do
					local m = view.items[mg]
					if m then
						price += TD.sellPrice(tid, m, karma) or TD.sellPrice("fence", m, karma) or 0
					end
				end
				add(string.format("SELL TO %s  +%s %s", TD.defs[tid].name, Util.commas(price), Config.CURRENCY), function()
					req({ op = "sell", g = g, trader = tid })
					selected = nil
				end, "warn")
			end
		end
		-- Tarkov asks before throwing an item away (audit ui.2): the first press arms it, a second within 3 s confirms.
		-- The Delete key on the hovered or selected item goes through the same two presses (audit ui.9)
		local armed = Inventory.discardArmed
		local confirm = armed and armed.g == g and os.clock() - armed.t < 3
		local function discard(byKey)
			if confirm then
				Inventory.discardArmed = nil
				req({ op = "discard", g = g })
				selected = nil
			else
				Inventory.discardArmed = { g = g, t = os.clock() }
				ctx.State.toast(byKey and "PRESS DEL AGAIN TO THROW IT AWAY" or "PRESS DISCARD AGAIN TO THROW IT AWAY", "warn")
				Inventory.render()
				task.delay(3.1, function()
					if Inventory.open and Inventory.discardArmed and Inventory.discardArmed.g == g then
						Inventory.discardArmed = nil
						Inventory.render()
					end
				end)
			end
		end
		local entry = add(confirm and "CONFIRM DISCARD" or "DISCARD", function()
			discard(false)
		end, "warn")
		entry.discard = function()
			discard(true)
		end
	end
	return list
end

local function closeMenu()
	if menu then
		menu:Destroy()
		menu = nil
	end
end

local function openMenu(ref, g, pos)
	closeMenu()
	local list = actionsFor(ref, g)
	local v = viewOf(ref)
	if v and v.items[g] and known(v.items[g].id) and Inventory.inspect then
		table.insert(list, 1, { label = "INSPECT", fn = function()
			Inventory.inspect({ ref = ref, g = g })
		end })
	end
	if #list == 0 then
		return
	end
	pos = K.toLocal(gui, pos) -- the screen point in the menu root's units (MENU TEXT SIZE)
	menu = K.frame(K.root(gui), { Name = "ContextMenu", Position = UDim2.fromOffset(pos.X + 4, pos.Y + 4), Size = UDim2.fromOffset(230, #list * 30 + 8), BackgroundColor3 = K.C.bg, ZIndex = 50 })
	K.stroke(menu, K.C.line, 0.4)
	K.pad(menu, 4)
	K.list(menu, nil, 2)
	for i, a in list do
		local b = K.button(menu, a.label, { Size = UDim2.new(1, 0, 0, 28), TextSize = 13, ZIndex = 51, LayoutOrder = i, TextXAlignment = Enum.TextXAlignment.Left })
		b.Text = "  " .. a.label
		if a.tone == "warn" then
			b.TextColor3 = K.C.orange
		elseif a.tone == "good" then
			b.TextColor3 = K.C.green
		end
		b.Activated:Connect(function()
			closeMenu()
			a.fn()
		end)
	end
	local vp = K.viewport(gui)
	local s = Vector2.new(menu.Size.X.Offset, menu.Size.Y.Offset)
	local barH = ctx.MenuBar and ctx.MenuBar.reserve() or 0 -- above the menu bar, which draws over this screen
	menu.Position = UDim2.fromOffset(math.min(pos.X + 4, vp.X - s.X - 4), math.max(0, math.min(pos.Y + 4, vp.Y - barH - s.Y - 4)))
end

-- ── drawing ────────────────────────────────────────────────────────────────────
local lastClick = nil -- { g, t }: a second click on the same item within 0.35 s uses it (DOUBLE-CLICK QUICK USE)
local function onTileClick(ref, g)
	local now = os.clock()
	if lastClick and lastClick.g == g and now - lastClick.t < 0.35 and ref == "me" and ctx.Settings.data.dblUse ~= false then
		lastClick = nil
		local v = viewOf(ref)
		local it = v and v.items[g]
		local d = it and defs[it.id]
		if d and (d.kind == "med" or d.kind == "food") and known(it.id) then
			selected = nil
			req({ op = "use", g = g })
			return
		end
	end
	lastClick = { g = g, t = now }
	local cur = selected
	if cur and cur.g ~= g and cur.ref then
		-- second tap on another item: drop onto it (merge / insert magazine / into container)
		local view = viewOf(ref)
		local k, cid, p = locate(view, g)
		if k == "grid" then
			req({ op = "move", g = cur.g, from = cur.ref, to = ref, dest = { c = cid, x = p.x, y = p.y, r = 0 } })
			selected = nil
			return
		end
	end
	if cur and cur.g == g then
		selected = nil
	else
		selected = { g = g, ref = ref }
	end
	Inventory.render()
end

-- Tarkov's middle mouse button: an unknown item is examined, a known one opens its INSPECT window (audit ui.9)
local function middleClick(ref, g)
	local v = viewOf(ref)
	local it = v and v.items[g]
	if not it then
		return
	end
	closeMenu()
	if known(it.id) then
		Inventory.inspect({ ref = ref, g = g })
	else
		req({ op = "examine", g = g, from = ref })
	end
end

local function tile(parent, view, ref, g, px, py, pw, ph, cellAbs, dropAs)
	local it = view.items[g]
	local d = defs[it.id]
	local isKnown = known(it.id)
	local isSel = selected and selected.g == g and selected.ref == ref
	-- a dark tile with a faint tint of the item's colour, its Blender picture on top (Tarkov's stash look)
	local base = isKnown and d.color:Lerp(K.C.panel2, 0.78) or Color3.fromHex("232627")
	local t = K.new("TextButton", {
		Name = "Tile_" .. g, Text = "", AutoButtonColor = true, BorderSizePixel = 0, Position = UDim2.fromOffset(px, py),
		Size = UDim2.fromOffset(pw, ph), BackgroundColor3 = base, ZIndex = 4, Selectable = true, SelectionImageObject = K.selection(),
	}, parent)
	K.stroke(t, isSel and K.C.ochre or K.C.line, isSel and 0 or 0.72, isSel and 2 or 1)
	-- Tarkov marks wish-listed items
	if isKnown and ctx.Settings.data.wish and ctx.Settings.data.wish[it.id] then
		K.label(t, "W", 10, { Name = "Wish", Position = UDim2.fromOffset(3, 2), Size = UDim2.fromOffset(10, 12), TextColor3 = K.C.ochre, FontFace = K.bold, ZIndex = 7 })
	end
	-- Tarkov marks a quick-slot item with its key
	local qs = ref == "me" and ctx.QuickSlots and ctx.QuickSlots.slotOf(g)
	if qs then
		K.label(t, qs, 11, { Name = "Quick", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 3, 1, -1), Size = UDim2.fromOffset(12, 12), TextColor3 = K.C.ochre, FontFace = K.bold, ZIndex = 7 })
	end
	local iw, ih = sizeOf(it)
	local rotated = iw ~= ih and ((pw > ph) ~= (iw > ih))
	if K.isBuild(view.items, g) then
		-- a gun is drawn as it is built: every part on it, at the stash scale (Tarkov)
		K.gunPicture(t, view.items, g, pw, ph, rotated, 4, (cellAbs or Inventory.cell or 40) / 64)
	else
		K.itemIcon(t, it.id, pw, ph, rotated, not isKnown, 4)
	end
	local small = math.min(pw, ph) < 40
	K.label(t, isKnown and d.short or "?", (small and 10 or 12) + (compact and 1 or 0), { Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -5, 0, 13), FontFace = K.bold, ZIndex = 5, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Right })
	local corner = cornerText(view, it)
	if corner ~= "" then
		K.label(t, corner, small and 10 or 11, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -1), Size = UDim2.new(1, -6, 0, 13), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
	end
	if isKnown and (Items.RARITY[d.rarity] or 0) > 0 then
		local col = ({ K.C.ochre, K.C.orange, Color3.fromHex("B05CC8"), K.C.red })[Items.RARITY[d.rarity]] or K.C.ochre
		K.frame(t, { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = col, ZIndex = 5 })
	end
	local tags = {}
	if it.fir then
		table.insert(tags, '<font color="#93A57C">FIR</font>')
	elseif it.rk then
		table.insert(tags, '<font color="#8C948D">RK</font>')
	end
	if it.ins then
		table.insert(tags, '<font color="#7FB2D9">INS</font>')
	end
	if #tags > 0 then
		K.label(t, table.concat(tags, " "), 9, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 3, 1, -1), Size = UDim2.fromOffset(44, 11), ZIndex = 5 })
	end
	if d.armor and it.dur then
		local f = math.clamp(it.dur / d.armor.dur, 0, 1)
		K.frame(t, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 2, 1, -14), Size = UDim2.new(f, -4, 0, 2), BackgroundColor3 = f > 0.5 and K.C.green or K.C.orange, ZIndex = 5 })
	end
	t.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			closeMenu()
			if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl) then
				quick(ref, g)
				return
			end
			if UIS:IsKeyDown(Enum.KeyCode.LeftAlt) then
				req({ op = "equip", g = g, from = ref, to = "me" })
				return
			end
			local m = mouse()
			if DEBUG then
				print("[ZR] drag begin", g:sub(1, 6), m)
			end
			local rel = m - t.AbsolutePosition
			local gc = (cellAbs or Inventory.cell or 40) * K.menuScale -- the cell on screen (MENU TEXT SIZE)
			drag = { g = g, ref = ref, id = it.id, unknown = not isKnown, start = m, started = false, grabX = cellAbs and math.floor(rel.X / gc) or 0, grabY = cellAbs and math.floor(rel.Y / gc) or 0, cell = Inventory.cell or gc, w = (sizeOf(it)), h = select(2, sizeOf(it)), r = 0, label = isKnown and d.short or "?", items = view.items }
			local _, _, p = locate(viewOf(ref), g)
			if p and p.r == 1 then
				drag.w, drag.h, drag.r = drag.h, drag.w, 1
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			openMenu(ref, g, mouse())
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 and not (drag and drag.started) then
			middleClick(ref, g)
		end
	end)
	t.MouseEnter:Connect(function()
		hoverG = { g = g, ref = ref }
	end)
	t.MouseLeave:Connect(function()
		if hoverG and hoverG.g == g and hoverG.ref == ref then
			hoverG = nil
		end
	end)
	if dropAs then
		hoverOn(t, dropAs)
	end
	t.Activated:Connect(function(input)
		if input and input.UserInputType == Enum.UserInputType.MouseButton1 then
			return -- mouse handled by the drag logic
		end
		onTileClick(ref, g)
	end)
	return t
end

local function placeSelected(ref, dest)
	if not selected then
		return
	end
	local res = req({ op = "move", g = selected.g, from = selected.ref, to = ref, dest = dest })
	if res and res.ok then
		selected = nil
	end
end

local function drawGrid(parent, view, ref, cid, title, cw, ch, cell, x0, y0, clip)
	local holder = K.frame(parent, { BackgroundTransparency = 1, Position = UDim2.fromOffset(x0, y0), Size = UDim2.fromOffset(math.max(cw * cell, 60), ch * cell + 18) })
	K.label(holder, title, 11, { Size = UDim2.new(1, 0, 0, 16), TextColor3 = K.C.dim })
	if cw == 0 or ch == 0 then
		return holder, 18
	end
	local g = K.frame(holder, { Name = "Grid_" .. string.sub(cid, 1, 8), Position = UDim2.fromOffset(0, 17), Size = UDim2.fromOffset(cw * cell, ch * cell), BackgroundColor3 = K.C.panel })
	K.stroke(g, K.C.line, 0.75)
	for yy = 1, ch do
		for xx = 1, cw do
			local cb = K.new("TextButton", {
				Name = string.format("Cell_%d_%d", xx, yy), Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = K.C.cell,
				BackgroundTransparency = 0.5, Position = UDim2.fromOffset((xx - 1) * cell + 1, (yy - 1) * cell + 1), Size = UDim2.fromOffset(cell - 2, cell - 2),
				Selectable = true, SelectionImageObject = K.selection(), ZIndex = 2,
			}, g)
			hoverOn(cb, { kind = "cell", ref = ref, cid = cid, x = xx, y = yy })
			cb.Activated:Connect(function(input)
				if input and input.UserInputType == Enum.UserInputType.MouseButton1 and not selected then
					return
				end
				if selected then
					placeSelected(ref, { c = cid, x = xx, y = yy, r = rot })
				end
			end)
		end
	end
	for guid, p in (view.grids and view.grids[cid]) or {} do
		local it = view.items[guid]
		if it then
			local d = defs[it.id]
			local iw, ih = Grid.dims(sizeOf(it))
			if p.r == 1 then
				iw, ih = ih, iw
			end
			tile(g, view, ref, guid, (p.x - 1) * cell + 1, (p.y - 1) * cell + 1, iw * cell - 2, ih * cell - 2, cell, { kind = "cell", ref = ref, cid = cid, x = p.x, y = p.y, occupied = guid })
			if cid == "stash" and searchText ~= "" then
				local q = string.lower(searchText)
				local hit = known(it.id) and (string.find(string.lower(d.name), q, 1, true) or string.find(string.lower(d.short or ""), q, 1, true)
					or string.find(SEARCH_CAT[d.kind] or "", q, 1, true))
				local t = g:FindFirstChild("Tile_" .. guid)
				if t and not hit then
					K.frame(t, { Name = "SearchDim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3, ZIndex = 9 })
				end
			end
		end
	end
	table.insert(gridTargets, { ref = ref, cid = cid, frame = g, cell = cell, w = cw, h = ch, clip = clip })
	return holder, ch * cell + 22
end

local function drawSlot(parent, view, ref, slot, x0, y0, w, h, cell)
	local holder = K.frame(parent, { Name = "Slot_" .. slot, BackgroundTransparency = 1, Position = UDim2.fromOffset(x0, y0), Size = UDim2.fromOffset(w, h + 16) })
	K.label(holder, Items.SLOT_NAMES[slot] or slot, 10, { Size = UDim2.new(1, 0, 0, 14), TextColor3 = K.C.dim, TextTruncate = Enum.TextTruncate.AtEnd })
	local box = K.frame(holder, { Position = UDim2.fromOffset(0, 15), Size = UDim2.fromOffset(w, h), BackgroundColor3 = K.C.panel })
	K.stroke(box, K.C.line, 0.6)
	local g = view.slots and view.slots[slot]
	local slotTarget = { kind = "slot", ref = ref, slot = slot }
	if g and view.items[g] then
		tile(box, view, ref, g, 1, 1, w - 2, h - 2, nil, slotTarget)
	else
		local e = K.new("TextButton", { Name = "Btn_SLOT_" .. string.upper(slot), Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Selectable = true, SelectionImageObject = K.selection(), ZIndex = 3 }, box)
		hoverOn(e, slotTarget)
		e.Activated:Connect(function()
			if selected then
				placeSelected(ref, { slot = slot })
			end
		end)
	end
	table.insert(slotTargets, { ref = ref, slot = slot, frame = box })
	return holder
end

local PART_ORDER = { "head", "thorax", "stomach", "larm", "rarm", "lleg", "rleg" }
local PART_SHORT = { head = "HEAD", thorax = "THORAX", stomach = "STOMACH", larm = "L.ARM", rarm = "R.ARM", lleg = "L.LEG", rleg = "R.LEG" }

-- body-part health; with a medical item selected, click a part to treat it (Tarkov drag-onto-body)
local function drawHealth(parent, width)
	local v = ctx.State.vitals
	if not v or not v.parts then
		return 0
	end
	K.label(parent, string.format("HEALTH  %d/%d     ENERGY %d     HYDRATION %d", math.ceil(v.hp), math.floor(v.max), math.floor(v.energy or 0), math.floor(v.water or 0)), 12, { Size = UDim2.new(1, 0, 0, 16), FontFace = K.bold, TextColor3 = (v.hp / v.max < 0.4) and K.C.red or K.C.text })
	local bw = math.floor((width - 6 * 4) / 7)
	for i, k in PART_ORDER do
		local p = v.parts[k]
		if p then
			local hp, max, bleed, frac = p[1], p[2], p[3], p[4]
			local f = max > 0 and hp / max or 0
			local col = (hp <= 0 and Color3.fromHex("1A1A1A")) or (f < 0.4 and Color3.fromHex("6A2A22")) or (f < 0.75 and Color3.fromHex("5E5228")) or Color3.fromHex("2F4A33")
			local b = K.button(parent, "", { Name = "Btn_PART_" .. string.upper(k), Position = UDim2.fromOffset((i - 1) * (bw + 4), 20), Size = UDim2.fromOffset(bw, 40), BackgroundColor3 = col })
			b.Text = string.format("%s\n%d/%d", PART_SHORT[k], hp, max)
			b.TextSize = 11
			if hp <= 0 then
				b.TextColor3 = K.C.red
			end
			local marks = (bleed == 2 and "HB " or (bleed == 1 and "LB " or "")) .. (frac and "FX" or "")
			if marks ~= "" then
				K.label(b, marks, 9, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 1), Size = UDim2.fromOffset(40, 10), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = K.C.orange, ZIndex = 5 })
			end
			b.Activated:Connect(function()
				local sel = selected
				local it = sel and sel.ref == "me" and data().items[sel.g]
				local d = it and defs[it.id]
				if d and (d.kind == "med") and ctx.State.inRaid() then
					req({ op = "use", g = sel.g, part = k })
					selected = nil
				end
			end)
		end
	end
	return 66
end

-- equipment layout + pockets + container grids for any holder view (mine or a body)
-- the gear column: health (yours), then the slots (Tarkov's arrangement)
local function drawSlots(parent, view, ref, cell, width)
	local y = 0
	if ref == "me" then
		local hf = K.frame(parent, { Name = "Health", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 64) })
		y += drawHealth(hf, width - 12)
	end
	local slotCell = math.floor(math.min(cell * 1.15, (width - 6) / 7))
	for _, e in SLOT_LAYOUT do
		local slot, sx, sy, sw, sh = e[1], e[2], e[3], e[4], e[5]
		drawSlot(parent, view, ref, slot, sx * slotCell, y + sy * slotCell + math.floor(sy / 2) * 2, sw * slotCell - 6, sh * slotCell - 18, slotCell)
	end
	return y + SLOT_ROWS * slotCell + 14
end

-- the container column: each container's slot with its grid beside it (rig, pockets, backpack, secure container)
local function drawContainers(parent, view, ref, cell, width)
	local y = 0
	local box = math.floor(cell * 2)
	local function container(slot, title)
		local cg = view.slots and view.slots[slot]
		local it = cg and view.items[cg]
		drawSlot(parent, view, ref, slot, 0, y, box, box - 16, cell)
		local gx = box + 8
		if it and view.grids and view.grids[cg] then
			local cd = defs[it.id]
			local _, gh = drawGrid(parent, view, ref, cg, title .. "  ·  " .. string.upper(cd.short or cd.name), cd.grid.w, cd.grid.h, cell, gx, y, nil)
			y += math.max(gh, box + 2) + 6
		else
			local why = (it and ref ~= "me") and "NOT SEARCHED" or "EMPTY"
			K.label(parent, title .. "  ·  " .. why, 11, { Position = UDim2.fromOffset(gx, y), Size = UDim2.new(1, -gx, 0, 16), TextColor3 = K.C.dim })
			y += box + 8
		end
	end
	container("rig", "TACTICAL RIG")
	-- pockets (no slot of their own)
	if view.grids and view.grids.pockets then
		local _, h0 = drawGrid(parent, view, ref, "pockets", "POCKETS", view.pocketsW or Config.POCKETS_W, view.pocketsH or Config.POCKETS_H, cell, box + 8, y, nil)
		y += h0 + 6
	else
		K.label(parent, "POCKETS  ·  NOT SEARCHED", 11, { Position = UDim2.fromOffset(box + 8, y), Size = UDim2.new(1, 0, 0, 16), TextColor3 = K.C.dim })
		y += 22
	end
	container("back", "BACKPACK")
	container("secure", "SECURE CONTAINER")
	return y
end

-- a body: its gear and its containers, one under the other (loot side)
local function drawGear(parent, view, ref, cell, width)
	local y = drawSlots(parent, view, ref, cell, width)
	local c = K.frame(parent, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 1600) })
	return y + drawContainers(c, view, ref, cell, width)
end

local detail
local drawOther
-- Tarkov's INSPECT window (Inspect.luau): the item's 3D model and its full attribute sheet
local function openInspect(sel)
	local view = viewOf(sel.ref)
	local it = view and view.items[sel.g]
	if it and ctx.Inspect then
		ctx.Inspect.open(view.items, sel.g, { key = tostring(sel.ref) .. ":" .. sel.g, mass = massOf(view, sel.g), unknown = not known(it.id) })
	end
end
Inventory.inspect = openInspect

function detail(parent, w, h, selOverride)
	local det = K.frame(parent, { Name = "Detail", Size = UDim2.fromOffset(w, h), BackgroundColor3 = K.C.panel })
	K.stroke(det, K.C.line, 0.7)
	K.pad(det, h < 60 and 5 or 8)
	local sel = selOverride or selected or hoverG
	local view = sel and viewOf(sel.ref)
	local it = view and view.items[sel.g]
	if it and h < 60 then
		-- the info bar: the item's name and key numbers, its actions in a row (touch and gamepad use these;
		-- the mouse also has the right-click menu); INSPECT opens the full card
		local d0 = defs[it.id]
		local kn = known(it.id)
		local sw0, sh0 = sizeOf(it)
		local nameW = compact and 0.3 or 0.34
		K.label(det, kn and string.upper(d0.name) or "UNKNOWN ITEM", compact and 14 or 13, { FontFace = K.bold, Size = UDim2.new(nameW, 0, 0, compact and 18 or 15), TextTruncate = Enum.TextTruncate.AtEnd })
		K.label(det, kn and string.format("%s %s  ·  %.2f kg  ·  %dx%d%s", Util.commas(Items.valueOf(it)), Config.CURRENCY, massOf(view, sel.g), sw0, sh0, it.fir and "  ·  FOUND IN RAID" or "") or "Examine it to identify it.", compact and 13 or 11, { Position = UDim2.fromOffset(0, compact and 20 or 15), Size = UDim2.new(nameW, 0, 0, compact and 16 or 14), TextColor3 = K.C.dim, TextTruncate = Enum.TextTruncate.AtEnd })
		local row = K.new("ScrollingFrame", {
			BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(1 - nameW, -6, 1, 0),
			ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollBarThickness = 0, Selectable = false,
		}, det)
		K.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, row)
		local list = actionsFor(sel.ref, sel.g)
		if kn then
			table.insert(list, 1, { label = "INSPECT", fn = function()
				openInspect({ ref = sel.ref, g = sel.g })
			end })
		end
		-- touch and gamepad turn an item before placing it (the mouse uses R while dragging; audit ui.1)
		local dev = ctx.Input.device()
		if dev == "Touch" or dev == "Gamepad" or compact then
			table.insert(list, 1, { label = "ROTATE " .. (rot == 1 and "ON" or "OFF"), fn = function()
				rot = 1 - rot
				Inventory.render()
			end })
		end
		for i, a in list do
			local b = K.button(row, a.label, { TextSize = compact and 13 or 10, LayoutOrder = i, Size = UDim2.fromOffset(compact and math.max(84, #a.label * 9 + 20) or math.max(70, #a.label * 7 + 16), h - 10) })
			if a.tone == "warn" then
				b.TextColor3 = K.C.orange
			elseif a.tone == "good" then
				b.TextColor3 = K.C.green
			end
			b.Activated:Connect(a.fn)
		end
		return
	end
	if not it then
		local dev = ctx.Input.device()
		local hint = dev == "Gamepad" and "Select an item (A), then a free cell or slot. LB / RB switch tabs, B closes."
			or (dev == "Touch" or compact) and "Tap an item, then a free cell or slot (switch panels on the left), or use its buttons here."
			or "Drag items between grids. Right-click for actions, Ctrl+click quick move, Alt+click equip, R rotates while dragging."
		K.label(det, hint, compact and 13 or 12, { Size = UDim2.fromScale(1, 1), TextWrapped = true, TextColor3 = K.C.dim, TextYAlignment = Enum.TextYAlignment.Center })
		return
	end
	local d = defs[it.id]
	local isKnown = known(it.id)
	K.label(det, isKnown and string.upper(d.name) or "UNKNOWN ITEM", 14, { FontFace = K.bold, Size = UDim2.new(0.6, 0, 0, 18) })
	-- the item's picture, as large as the strip allows, between the text and the buttons
	local sw, sh = sizeOf(it)
	local picH = math.max(24, h - 20)
	local picW = math.floor(math.min(w * 0.22, picH * sw / sh))
	picH = math.floor(math.min(picH, picW * sh / sw))
	local pic = K.frame(det, { Name = "Picture", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.62, -4, 0, 0), Size = UDim2.fromOffset(picW, picH) })
	if K.isBuild(view.items, sel.g) then
		K.gunPicture(pic, view.items, sel.g, picW, picH, false, 3)
	else
		K.itemIcon(pic, it.id, picW, picH, false, not isKnown, 3)
	end
	local lines = {}
	if isKnown then
		table.insert(lines, d.desc)
		if it.tag then
			table.insert(lines, string.format("OPERATOR %s  ·  LEVEL %d%s", string.upper(tostring(it.tag.name)), it.tag.lvl or 1, it.tag.by and ("  ·  KILLED BY " .. string.upper(tostring(it.tag.by))) or ""))
		end
		if d.ammo then
			table.insert(lines, string.format("DAMAGE %d%s   PEN %d   ARMOR DMG %d%%", d.ammo.dmg, d.ammo.pellets and ("x" .. d.ammo.pellets) or "", d.ammo.pen, math.floor(d.ammo.armorDmg * 100)))
		end
		if d.armor then
			table.insert(lines, string.format("CLASS %d   DURABILITY %d/%d", Plates.classOf(defs, view.items, it), math.ceil(it.dur or d.armor.dur), d.armor.dur))
			-- a vest's plate slots: what is in each (Tarkov 0.14)
			local slots = Plates.slotsOf(d)
			if slots then
				local parts = {}
				for _, s in Plates.SLOTS do
					if slots[s] then
						local p = it.mods and it.mods[s] and view.items[it.mods[s]]
						local pd = p and defs[p.id]
						table.insert(parts, string.format("%s %s", string.upper(s == "lside" and "left" or s == "rside" and "right" or s), pd and string.format("%s %d/%d", pd.short, math.ceil(p.dur or pd.armor.dur), pd.armor.dur) or "EMPTY"))
					end
				end
				table.insert(lines, "PLATES: " .. table.concat(parts, "  ·  "))
			end
		end
		if d.grid then
			table.insert(lines, string.format("CAPACITY %dx%d", d.grid.w, d.grid.h))
		end
		-- M14: a gun's build (handling, missing parts) or a part's effect and where it fits
		if ctx.Modding and (WP.isBase(it.id) or (d.part and it.mods)) then
			for _, line in ctx.Modding.describeBuild(view.items, sel.g, true) do
				table.insert(lines, line)
			end
		elseif ctx.Modding and d.part then
			for _, line in ctx.Modding.describePart(it.id, true) do
				table.insert(lines, line)
			end
		end
		table.insert(lines, string.format("VALUE %s %s   ·   %.2f kg   ·   %dx%d%s%s", Util.commas(Items.valueOf(it)), Config.CURRENCY, massOf(view, sel.g), sw, sh, it.fir and "   ·   FOUND IN RAID" or "", it.ins and "   ·   INSURED" or ""))
	else
		table.insert(lines, "Examine this item to identify it.")
	end
	K.label(det, table.concat(lines, "\n"), 11, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(0.62, -picW - 10, 1, -20), TextWrapped = true, TextColor3 = K.C.dim, TextYAlignment = Enum.TextYAlignment.Top })
	-- action buttons (touch / gamepad; mouse users also get the right-click menu)
	local col = K.frame(det, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.38, 0, 1, 0) })
	local grid = K.new("UIGridLayout", { CellSize = UDim2.new(0.5, -3, 0, 26), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder }, col)
	local list = actionsFor(sel.ref, sel.g)
	table.insert(list, 1, { label = "ROTATE " .. (rot == 1 and "ON" or "OFF"), fn = function()
		rot = 1 - rot
		Inventory.render()
	end })
	for i, a in list do
		local b = K.button(col, a.label, { TextSize = 11, LayoutOrder = i })
		if a.tone == "warn" then
			b.TextColor3 = K.C.orange
		elseif a.tone == "good" then
			b.TextColor3 = K.C.green
		end
		b.Activated:Connect(a.fn)
	end
	local _ = grid
end

-- the third column (Tarkov's right side): what you are looting in a raid, the stash out of one (PC and phone layouts)
function drawOther(right, rightW, cell, d, inRaid)
	if loot and inRaid then
		local ref = "c:" .. loot.cid
		local title = string.upper(loot.label) .. ((loot.searching and not loot.searched) and "   ·   SEARCHING..." or "")
		K.label(right, title, 13, { Name = "LootTitle", Size = UDim2.new(1, 0, 0, 18), FontFace = K.bold, TextColor3 = K.C.ochre })
		local h2
		if loot.body then
			h2 = drawGear(K.frame(right, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 2000) }), loot, ref, cell, rightW)
		else
			local _, gh2 = drawGrid(right, loot, ref, "main", "CONTENTS", loot.mainW or 5, loot.mainH or 4, cell, 0, 24, nil)
			h2 = gh2
		end
		local takeAll = K.button(right, "TAKE ALL", { Name = "Btn_TAKEALL", Position = UDim2.fromOffset(0, h2 + 34), Size = UDim2.fromOffset(160, 30) })
		takeAll.Activated:Connect(function()
			local v = viewOf(ref)
			if not v then
				return
			end
			local list = {}
			for cid, pl in v.grids or {} do
				if cid == "main" or cid == "pockets" then
					for g in pl do
						table.insert(list, g)
					end
				end
			end
			for _, g in list do
				local r = req({ op = "quick", g = g, from = ref, to = "me" })
				if not r or not r.ok then
					break
				end
			end
		end)
		right.CanvasSize = UDim2.fromOffset(0, h2 + 80)
	elseif not inRaid then
		local stashH = d.stashH or Config.STASH_H
		-- on a phone the tools get a row of their own above the stash, at finger size
		local toolH = compact and 34 or 17
		local y0 = compact and toolH + 4 or 0
		local _, sh = drawGrid(right, d, "me", "stash", "STASH  " .. Config.STASH_W .. "x" .. stashH, Config.STASH_W, stashH, cell, 0, y0, nil)
		sh += y0
		right.CanvasSize = UDim2.fromOffset(0, sh + 60)
		-- Tarkov's stash tools: SORT and SEARCH (by name or category; press Enter)
		local sx = Config.STASH_W * cell
		local sortB = K.button(right, "SORT", { Name = "Sort", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(sx, -1), Size = UDim2.fromOffset(compact and 84 or 64, toolH), TextSize = compact and 13 or 10 })
		sortB.Activated:Connect(function()
			req({ op = "sort" })
		end)
		local box = K.new("TextBox", {
			Name = "Search", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(sx - (compact and 90 or 70), -1), Size = UDim2.fromOffset(compact and 190 or 150, toolH), Text = searchText,
			PlaceholderText = "SEARCH", ClearTextOnFocus = false, TextSize = compact and 13 or 10, FontFace = K.font, TextColor3 = K.C.text, PlaceholderColor3 = K.C.dim,
			BackgroundColor3 = K.C.panel2, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left,
		}, right)
		K.new("UIPadding", { PaddingLeft = UDim.new(0, 5) }, box)
		box.FocusLost:Connect(function()
			if box.Text ~= searchText then
				searchText = box.Text
				Inventory.render()
			end
		end)
		local row = K.frame(right, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, sh + 6), Size = UDim2.new(1, 0, 0, 32) })
		K.list(row, Enum.FillDirection.Horizontal, 6)
		local hasGun = false
		for _, it in d.items do
			local idf = defs[it.id]
			if idf and (idf.kind == "weapon" or idf.kind == "pistol") then
				hasGun = true
			end
		end
		if not hasGun and (d.money or 0) < (Config.RECOVERY_MONEY or 0) then
			K.button(row, "CLAIM RECOVERY KIT", { Size = UDim2.fromOffset(200, 30), TextSize = 13, TextColor3 = K.C.ochre }, function()
				req({ op = "recovery" })
			end)
		end
		local cl = d.claims
		if cl and cl.ready > 0 then
			K.button(row, string.format("COLLECT INSURANCE (%d)", cl.ready), { Size = UDim2.fromOffset(230, 30), TextSize = 13, TextColor3 = K.C.green }, function()
				req({ op = "claim" })
			end)
		elseif cl and cl.waiting > 0 then
			K.label(row, string.format("INSURANCE: %d ITEM(S) RETURNING IN %s", cl.waiting, Util.clock(math.max(0, cl.nextIn or 0))), 12, { Size = UDim2.fromOffset(330, 30), TextColor3 = K.C.green })
		end
	else
		K.label(right, "Open a container or body to loot it." .. (ctx.Input.hints() and ("\nPress " .. ctx.Input.label("Inventory") .. " to close.") or ""), 13, { Size = UDim2.new(1, 0, 0, 40), TextColor3 = K.C.dim, TextWrapped = true })
	end
end

-- ui-3a, the phone layout (under 500 pt of height; checked at 844x390, 667x375 and 932x430): one row of tabs, then a
-- rail of three panels (EQUIPMENT, BAGS, STASH or LOOT) beside one panel at a time; 36-pt cells, 44-pt buttons, 13-pt text.
-- Tarkov's PC columns hold the same three things side by side; a phone cannot fit them at a readable size.
function Inventory.renderCompact(d, W, H, inRaid)
	local weight = gearWeight(d)
	local closeW, gap = 84, 6
	local tabs = tabList(inRaid)
	if not table.find(tabs, Inventory.tab) then
		Inventory.tab = "GEAR"
	end
	-- the tabs keep 150 pt for the weight and money; past that (six tabs on a 667-pt phone) the row scrolls sideways and
	-- the open tab is brought into view
	local tw = math.clamp(math.floor((W - closeW - 3 * gap - 150) / #tabs) - 4, 76, 104)
	local rowW = #tabs * (tw + 4)
	local barW = math.min(rowW, math.max(tw + 4, W - closeW - 3 * gap - 150))
	local tabBar = K.new("ScrollingFrame", {
		Name = "Tabs", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(gap, gap), Size = UDim2.fromOffset(barW, 40),
		CanvasSize = UDim2.fromOffset(rowW, 40), ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 0, Selectable = false,
	}, panel)
	K.list(tabBar, Enum.FillDirection.Horizontal, 4)
	for i, t in tabs do
		local on = Inventory.tab == t
		local b = K.button(tabBar, t, { Name = "Tab_" .. t, LayoutOrder = i, Size = UDim2.fromOffset(tw, 40), TextSize = 13, BackgroundColor3 = on and Color3.fromHex("3A3524") or K.C.panel2, TextColor3 = on and K.C.ochre or K.C.dim })
		b.Activated:Connect(function()
			if Inventory.tab ~= t then
				Inventory.tab = t
				Inventory.render()
			end
		end)
		if on then
			openTabBtn = b
			if rowW > barW then
				local x = math.clamp((i - 1) * (tw + 4) - (barW - tw) / 2, 0, rowW - barW)
				task.defer(function()
					if tabBar.Parent then
						tabBar.CanvasPosition = Vector2.new(x, 0)
					end
				end)
			end
		end
	end
	local infoX = gap + barW + gap
	local info = string.format("%.1f KG", weight)
	if not inRaid then
		info ..= string.format("  ·  %s %s", Util.commas(d.money or 0), Config.CURRENCY)
	end
	if status and os.clock() - status.t0 < status.dur then
		info = string.format("%s %.1fs", status.text, status.dur - (os.clock() - status.t0))
	end
	K.label(panel, info, 13, { Position = UDim2.fromOffset(infoX, gap), Size = UDim2.fromOffset(math.max(0, W - infoX - closeW - 2 * gap), 40), TextColor3 = weight > 40 and K.C.orange or K.C.dim, TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Center })
	local close = K.button(panel, "CLOSE", { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -gap, 0, gap), Size = UDim2.fromOffset(closeW, 40), TextSize = 13 })
	close.Activated:Connect(Inventory.close)
	local top = gap + 40 + gap
	if Inventory.tab ~= "GEAR" and ctx.Character then
		local body = K.new("ScrollingFrame", {
			Name = "Character", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(gap, top), Size = UDim2.fromOffset(W - 2 * gap, H - top - gap),
			ScrollBarThickness = 6, CanvasSize = UDim2.new(), Selectable = false,
		}, panel)
		body.CanvasSize = UDim2.fromOffset(0, ctx.Character.draw(Inventory.tab, body, W - 2 * gap - 12, H - top - gap) + 20)
		keepScroll(body, "tab:" .. Inventory.tab)
		return
	end
	-- the rail: three panels, the open one lit; the item picked up stays picked up across panels
	local railW, detailH, cell = 96, 54, 36
	Inventory.cell = cell
	local bodyH = H - top - detailH - 2 * gap
	local otherName = (inRaid or loot) and "LOOT" or "STASH"
	local rail = K.frame(panel, { Name = "Rail", BackgroundTransparency = 1, Position = UDim2.fromOffset(gap, top), Size = UDim2.fromOffset(railW, bodyH) })
	K.list(rail, nil, 6)
	if not (Inventory.cpanel == "GEAR" or Inventory.cpanel == "BAGS" or Inventory.cpanel == "OTHER") then
		Inventory.cpanel = "GEAR"
	end
	-- (the worn-gear panel says EQUIPMENT: the GEAR tab above is the whole screen, as in Tarkov)
	for i, pnl in { { "GEAR", "EQUIPMENT" }, { "BAGS", "BAGS" }, { "OTHER", otherName } } do
		local on = Inventory.cpanel == pnl[1]
		local b = K.button(rail, pnl[2], {
			Name = "Rail_" .. pnl[1], LayoutOrder = i, Size = UDim2.new(1, 0, 0, 44), TextSize = 13,
			BackgroundColor3 = on and Color3.fromHex("3A3524") or K.C.panel2, TextColor3 = on and K.C.ochre or K.C.text,
		})
		b.Activated:Connect(function()
			if Inventory.cpanel ~= pnl[1] then
				Inventory.cpanel = pnl[1]
				Inventory.render()
			end
		end)
	end
	if selected then
		local sv = viewOf(selected.ref)
		local sit = sv and sv.items[selected.g]
		local sd = sit and defs[sit.id]
		if sd then
			K.label(rail, "MOVING\n" .. (known(sit.id) and sd.short or "?"), 13, {
				Name = "Moving", LayoutOrder = 9, Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, TextColor3 = K.C.ochre, FontFace = K.bold,
			})
		end
	end
	local x0 = gap + railW + gap
	local cw = W - x0 - gap
	local view = K.new("ScrollingFrame", {
		Name = "Panel_" .. Inventory.cpanel, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(x0, top), Size = UDim2.fromOffset(cw, bodyH),
		ScrollBarThickness = 6, CanvasSize = UDim2.new(), Selectable = false,
	}, panel)
	local nG, nS = #gridTargets, #slotTargets
	if Inventory.cpanel == "GEAR" then
		view.CanvasSize = UDim2.fromOffset(0, drawSlots(view, d, "me", cell, cw - 10) + 10)
	elseif Inventory.cpanel == "BAGS" then
		view.CanvasSize = UDim2.fromOffset(0, drawContainers(view, d, "me", cell, cw - 10) + 10)
	else
		drawOther(view, cw - 10, cell, d, inRaid)
	end
	for i = nG + 1, #gridTargets do
		gridTargets[i].clip = gridTargets[i].clip or view
	end
	for i = nS + 1, #slotTargets do
		slotTargets[i].clip = slotTargets[i].clip or view
	end
	keepScroll(view, "panel:" .. Inventory.cpanel .. ((Inventory.cpanel == "OTHER" and inRaid and loot) and (":" .. tostring(loot.cid)) or ""))
	local det = K.frame(panel, { BackgroundTransparency = 1, Position = UDim2.new(0, gap, 1, -detailH - gap), Size = UDim2.new(1, -2 * gap, 0, detailH) })
	detail(det, W - 2 * gap, detailH)
end

-- snapshots can arrive many times a second (looting, a fight): redraw at most four times a second for them, as the
-- trader screen does (audit tech.7); a player's own clicks still redraw at once
local renderPending, lastRender = false, 0
function Inventory.renderSoon()
	if renderPending then
		return
	end
	renderPending = true
	task.delay(math.max(0, 0.25 - (os.clock() - lastRender)), function()
		renderPending = false
		if Inventory.open then
			Inventory.render()
		end
	end)
end

-- the PC layout: header, character tabs, then Tarkov's three columns and the info bar
local function renderWide(d, W, H, inRaid)
	-- header
	local weight = gearWeight(d)
	local head = inRaid and ("FIELD KIT  //  " .. Maps.nameOf(ctx.State.raid and ctx.State.raid.map)) or "HIDEOUT  //  STASH & GEAR"
	K.label(panel, head, 16, { Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(W - 220, 22), FontFace = K.bold })
	local info = string.format("WEIGHT %.1f kg", weight)
	if not inRaid then
		info ..= string.format("   ·   %s %s", Util.commas(d.money or 0), Config.CURRENCY)
	end
	if status and os.clock() - status.t0 < status.dur then
		info ..= string.format("   ·   %s %.1fs", status.text, status.dur - (os.clock() - status.t0))
	end
	K.label(panel, info, 12, { Position = UDim2.fromOffset(12, 28), Size = UDim2.fromOffset(W - 220, 16), TextColor3 = weight > 40 and K.C.orange or K.C.dim })
	local close = K.button(panel, ctx.Input.hints() and ("CLOSE [" .. ctx.Input.label("Inventory") .. "]") or "CLOSE", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(150, 30) })
	close.Activated:Connect(Inventory.close)
	-- Tarkov's character tabs along the top (tabList). On narrow windows the tabs narrow so the row keeps clear of the
	-- header text (Roboto Mono is 0.6 em a glyph: 9.6 px at 16 px)
	local tabs = tabList(inRaid)
	if not table.find(tabs, Inventory.tab) then
		Inventory.tab = "GEAR"
	end
	local headW = 12 + math.ceil(#head * 9.6) + 16
	local tw = math.clamp(math.floor((W - 168 - math.max(250, headW)) / #tabs) - 4, 56, 92)
	local tabBar = K.frame(panel, { Name = "Tabs", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -168, 0, 8), Size = UDim2.fromOffset(#tabs * (tw + 4), 30) })
	K.list(tabBar, Enum.FillDirection.Horizontal, 4)
	for i, t in tabs do
		local on = Inventory.tab == t
		local b = K.button(tabBar, t, { Name = "Tab_" .. t, LayoutOrder = i, Size = UDim2.fromOffset(tw, 30), TextSize = tw < 76 and 10 or 12, BackgroundColor3 = on and Color3.fromHex("3A3524") or K.C.panel2, TextColor3 = on and K.C.ochre or K.C.dim })
		b.Activated:Connect(function()
			if Inventory.tab ~= t then
				Inventory.tab = t
				Inventory.render()
			end
		end)
		if on then
			openTabBtn = b
		end
	end
	if Inventory.tab ~= "GEAR" and ctx.Character then
		local body = K.new("ScrollingFrame", {
			Name = "Character", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 52), Size = UDim2.fromOffset(W - 24, H - 64),
			ScrollBarThickness = 5, CanvasSize = UDim2.new(), Selectable = false,
		}, panel)
		body.CanvasSize = UDim2.fromOffset(0, ctx.Character.draw(Inventory.tab, body, W - 40, H - 64) + 20)
		keepScroll(body, "tab:" .. Inventory.tab)
		return
	end
	-- Tarkov's three columns: your gear, your containers, then the stash (or what you are looting)
	local top, detailH = 52, 40
	local bodyH = H - top - detailH - 14
	local cell = math.floor(math.clamp((W - 60) / (8 + 2 + 7 + Config.STASH_W + 1.5), 24, 46))
	Inventory.cell = cell
	local leftW = math.floor(cell * 7.6)
	local midW = math.floor(cell * 8.8)
	local rightW = W - leftW - midW - 44
	local function column(name, x, w)
		return K.new("ScrollingFrame", { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(x, top), Size = UDim2.fromOffset(w, bodyH), ScrollBarThickness = 5, CanvasSize = UDim2.new(), Selectable = false }, panel)
	end
	local left = column("Gear", 12, leftW)
	left.CanvasSize = UDim2.fromOffset(0, drawSlots(left, d, "me", cell, leftW) + 10)
	local mid = column("Containers", 12 + leftW + 10, midW)
	local n0, s0 = #gridTargets, #slotTargets
	mid.CanvasSize = UDim2.fromOffset(0, drawContainers(mid, d, "me", cell, midW) + 10)
	for i, t in gridTargets do
		t.clip = t.clip or (i > n0 and mid or left)
	end
	for i, t in slotTargets do
		t.clip = t.clip or (i > s0 and mid or left)
	end
	-- right: stash / container / body
	local right = column("Other", 12 + leftW + midW + 22, rightW)
	local nG, nS = #gridTargets, #slotTargets
	drawOther(right, rightW, cell, d, inRaid)
	for i = nG + 1, #gridTargets do
		gridTargets[i].clip = right
	end
	for i = nS + 1, #slotTargets do
		slotTargets[i].clip = right
	end
	keepScroll(left, "col:Gear")
	keepScroll(mid, "col:Containers")
	keepScroll(right, "col:Other" .. ((inRaid and loot) and (":" .. tostring(loot.cid)) or ""))
	-- info bar (the hovered or selected item; INSPECT in its menu opens the full card)
	local det = K.frame(panel, { BackgroundTransparency = 1, Position = UDim2.new(0, 12, 1, -detailH - 8), Size = UDim2.new(1, -24, 0, detailH) })
	detail(det, W - 24, detailH)
end

function Inventory.render()
	if not Inventory.open then
		return
	end
	lastRender = os.clock()
	local d = data()
	if not d or not d.slots then
		return
	end
	if selected and not (viewOf(selected.ref) and viewOf(selected.ref).items[selected.g]) then
		selected = nil
	end
	-- where the gamepad selection was, to find it again in the new drawing (a tab change lands on the open tab instead)
	local keep = (panel and not focusTab) and ctx.Input.focusPath(panel) or nil
	focusTab = false
	if panel then
		panel:Destroy()
	end
	closeMenu()
	table.clear(gridTargets)
	table.clear(slotTargets)
	table.clear(targetOf)
	hover = nil
	openTabBtn = nil
	local inRaid = ctx.State.inRaid()
	local vp = K.viewport(gui)
	compact = vp.Y < COMPACT_H
	local barH = ctx.MenuBar and ctx.MenuBar.reserve() or 0 -- the menu bar out of a raid (ui-6a)
	local W = compact and math.floor(vp.X) or math.floor(math.min(vp.X - 12, 1360))
	local H = compact and math.floor(vp.Y - barH) or math.floor(math.min(vp.Y - 8 - barH, 800))
	panel = K.frame(K.root(gui), { Name = "InvPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -barH / 2), Size = UDim2.fromOffset(W, H), BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.03 })
	K.stroke(panel, K.C.line, 0.45)
	if compact then
		Inventory.renderCompact(d, W, H, inRaid)
	else
		renderWide(d, W, H, inRaid)
	end
	-- the gamepad selection (audit ui.5): only with a pad; where it was, else the open tab
	ctx.Input.refocus(panel, keep, openTabBtn)
	-- the fit cue goes back on the new grids (a redraw mid-drag, an item picked up, ROTATE)
	if updateCue then
		updateCue()
	end
end

-- ── drag & drop (mouse) ────────────────────────────────────────────────────────
local function dropTarget(pos)
	if hover then
		return hover
	end
	for _, s in slotTargets do
		if s.frame.Parent and inside(s.frame, pos) and (not s.clip or inside(s.clip, pos)) then
			return { kind = "slot", ref = s.ref, slot = s.slot }
		end
	end
	for _, t in gridTargets do
		if t.frame.Parent and inside(t.frame, pos) and (not t.clip or inside(t.clip, pos)) then
			local rel = pos - t.frame.AbsolutePosition
			local cs = t.cell * K.menuScale -- the cell on screen (MENU TEXT SIZE)
			return { kind = "cell", ref = t.ref, cid = t.cid, x = math.floor(rel.X / cs) + 1, y = math.floor(rel.Y / cs) + 1, cell = t.cell }
		end
	end
	return nil
end

-- ── the fit cue (audit ui.9) ───────────────────────────────────────────────────────
-- While an item is dragged the cells it would take light green when the server should take the drop and red when it
-- would refuse it (Tarkov's drag highlight, from memory: no source found); a slot lights whole; turning the item with
-- R moves the cells. DropRules decides, with the same plan endDrag sends.
local cue = nil
local function clearCue()
	if cue then
		cue:Destroy()
		cue = nil
	end
end

local function planFor(dd, tgt)
	local src, dst = viewOf(dd.ref), tgt and viewOf(tgt.ref)
	if not (src and dst) then
		return nil
	end
	return Drop.plan(src, dd.g, dst, tgt, dd, ctx.State.inRaid())
end

local function showCue(tgt, plan)
	local host, pos, size
	if plan and plan.slot then
		for _, s in slotTargets do
			if s.ref == tgt.ref and s.slot == plan.slot and s.frame.Parent then
				host, pos, size = s.frame, UDim2.new(), UDim2.fromScale(1, 1)
			end
		end
	elseif plan then
		for _, t in gridTargets do
			if t.ref == tgt.ref and t.cid == plan.cid and t.frame.Parent then
				-- the cells inside the grid (an item hanging over the edge lights what is left, in red)
				local x0, y0 = math.max(1, plan.x), math.max(1, plan.y)
				local x1, y1 = math.min(t.w, plan.x + plan.w - 1), math.min(t.h, plan.y + plan.h - 1)
				if x1 >= x0 and y1 >= y0 then
					host = t.frame
					pos = UDim2.fromOffset((x0 - 1) * t.cell + 1, (y0 - 1) * t.cell + 1)
					size = UDim2.fromOffset((x1 - x0 + 1) * t.cell - 2, (y1 - y0 + 1) * t.cell - 2)
				end
			end
		end
	end
	if not host then
		clearCue()
		return
	end
	if not (cue and cue.Parent == host) then
		clearCue()
		cue = K.frame(host, { Name = "FitCue", Active = false, ZIndex = 8, BackgroundTransparency = 0.55 })
		pcall(function()
			cue.Interactable = false -- the cells and tiles under it keep telling where the cursor is
		end)
		K.stroke(cue, K.C.green, 0, 2)
	end
	local col = plan.ok and K.C.green or K.C.red
	cue.Position, cue.Size, cue.BackgroundColor3 = pos, size, col
	local st = cue:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = col
	end
end

updateCue = function()
	if drag and drag.started then
		local tgt = dropTarget(mouse())
		local plan = tgt and planFor(drag, tgt)
		showCue(tgt, plan)
		-- the dragged picture's outline says the same (ochre over nothing)
		local st = ghost and ghost:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = plan and (plan.ok and K.C.green or K.C.red) or K.C.ochre
		end
		return
	end
	-- an item picked up by a tap, a click or A, then placed on a cell or slot (touch, gamepad, mouse): the cue follows the
	-- gamepad selection, or the cell under the cursor, laid as placing it would (its corner there, turned by ROTATE / R)
	local tgt = nil
	if Inventory.open and selected then
		if ctx.Input.device() == "Gamepad" then
			local obj = GuiService.SelectedObject
			tgt = obj and targetOf[obj]
		else
			tgt = hover
		end
	end
	if tgt and tgt.kind == "slot" then
		-- a tap on a worn item picks that one up instead (onTileClick): only an empty slot takes the carried item
		local v = viewOf(tgt.ref)
		if v and v.slots and v.slots[tgt.slot] then
			tgt = nil
		end
	end
	local plan = tgt and planFor({ ref = selected.ref, g = selected.g, r = rot, r0 = rot, grabX = 0, grabY = 0 }, tgt)
	if plan and not plan.noop then
		showCue(tgt, plan)
	else
		clearCue()
	end
end

local function endDrag()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	clearCue()
	local dd = drag
	drag = nil
	if not dd then
		return
	end
	if not dd.started then
		onTileClick(dd.ref, dd.g)
		return
	end
	local tgt = dropTarget(mouse())
	if DEBUG then
		print("[ZR] drop", dd.g:sub(1, 6), "at", mouse(), tgt and (tgt.kind .. " " .. tostring(tgt.slot or tgt.cid) .. " " .. tostring(tgt.x) .. "," .. tostring(tgt.y)) or "nothing")
	end
	-- the same plan the cue showed: a slot, an item to combine with (its corner cell), or free cells with the grabbed
	-- cell under the cursor; back over its own tile nothing moves. A red drop is still sent: the server is the judge
	local plan = tgt and planFor(dd, tgt)
	if plan and not plan.noop then
		req({ op = "move", g = dd.g, from = dd.ref, to = tgt.ref, dest = plan.dest })
	end
end

local function updateGhost()
	if not drag or not drag.started then
		return
	end
	local c = drag.cell
	if not ghost then
		-- no fill: the green / red cells show through under the picture (audit ui.9)
		ghost = K.frame(K.root(gui), { Name = "DragGhost", BackgroundColor3 = K.C.ochre, BackgroundTransparency = 1, ZIndex = 60, Active = false })
		pcall(function()
			ghost.Interactable = false
		end)
		K.stroke(ghost, K.C.ochre, 0)
		K.label(ghost, drag.label, 12, { Position = UDim2.fromOffset(3, 2), Size = UDim2.new(1, -4, 0, 14), FontFace = K.bold, ZIndex = 61 })
	end
	local m = K.toLocal(gui, mouse())
	local gx, gy = drag.grabX, drag.grabY
	if drag.r ~= drag.r0 then
		gx, gy = gy, gx
	end
	ghost.Size = UDim2.fromOffset(drag.w * c - 2, drag.h * c - 2)
	ghost.Position = UDim2.fromOffset(m.X - gx * c - c * 0.5 + 6, m.Y - gy * c - c * 0.5 + 6)
	-- the picture follows the drag (and turns with R)
	local d = defs[drag.id or ""]
	local key = string.format("%d_%d", drag.w, drag.h)
	if d and ghost:GetAttribute("IconKey") ~= key then
		ghost:SetAttribute("IconKey", key)
		-- the old picture goes (a gun's is a GunPicture frame, anything else's an Icon)
		for _, name in { "Icon", "GunPicture" } do
			local old = ghost:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
		local pw, ph = drag.w * c - 2, drag.h * c - 2
		local items = drag.items
		local it0 = items and items[drag.g]
		local sw, sh = sizeOf(it0 or { id = drag.id })
		local rotated = sw ~= sh and ((pw > ph) ~= (sw > sh))
		if items and K.isBuild(items, drag.g) then
			K.gunPicture(ghost, items, drag.g, pw, ph, rotated, 60, c / 64)
		else
			K.itemIcon(ghost, drag.id, pw, ph, rotated, drag.unknown, 60)
		end
	end
end

function Inventory.show()
	Inventory.open = true
	gui.Enabled = true
	ctx.Input.setMenu(true)
	ctx.Interact.setEnabled(false)
	Inventory.render()
end

function Inventory.close()
	if not Inventory.open then
		return
	end
	Inventory.open = false
	gui.Enabled = false
	if ctx.Inspect then
		ctx.Inspect.closeAll()
	end
	selected = nil
	rot = 0
	drag = nil
	closeMenu()
	clearCue()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	local l = loot
	loot = nil
	if ctx.Modding and ctx.Modding.open_ then
		ctx.Modding.close()
	end
	ctx.Input.setMenu(false)
	ctx.Interact.setEnabled(true)
	pcall(function()
		GuiService.SelectedObject = nil
	end)
	if l then
		task.spawn(ctx.State.req, "loot", { op = "close", cid = l.cid })
	end
end

function Inventory.toggle()
	if Inventory.open then
		Inventory.close()
	elseif ctx.Grenade and ctx.Grenade.busy() then
		return -- a grenade in hand: throw it first
	elseif not (ctx.Screens and ctx.Screens.modal) then
		Inventory.show()
	elseif ctx.MenuBar and not ctx.State.inRaid() and ctx.MenuBar.current() ~= nil then
		-- out of a raid Tab goes from a menu-bar screen to the character screen (Tarkov's menu bar, ui-6a)
		ctx.Screens.close()
		Inventory.show()
	end
end

function Inventory.init(c)
	ctx = c
	K = c.UiKit
	gui = K.screen("ZR_Inventory", 20)
	gui.Enabled = false
	c.Input.on("Inventory", function(down)
		if down then
			Inventory.toggle()
		end
	end)
	c.Input.on("Back", function(down)
		-- Back closes the modding screen first (it sits over the inventory)
		if ctx.Modding and (ctx.Modding.open_ or os.clock() - (ctx.Modding.closedAt or 0) < 0.15) then
			return
		end
		if down and Inventory.open then
			if menu then
				closeMenu()
			elseif not (ctx.Inspect and ctx.Inspect.closeTop()) then -- the top inspect window goes first (audit ui.5)
				Inventory.close()
			end
		end
	end)
	-- LB / RB: the previous / next character tab, wrapping round; the selection lands on the new tab (audit ui.5)
	local function stepTab(dir)
		if not Inventory.open or (ctx.Modding and ctx.Modding.open_) then
			return
		end
		local tabs = tabList(ctx.State.inRaid())
		local i = table.find(tabs, Inventory.tab) or 1
		Inventory.tab = tabs[(i - 1 + dir) % #tabs + 1]
		focusTab = true
		Inventory.render()
	end
	c.Input.on("TabPrev", function(down)
		if down then
			stepTab(-1)
		end
	end)
	c.Input.on("TabNext", function(down)
		if down then
			stepTab(1)
		end
	end)
	-- the hint line, ROTATE and the selection follow the device in use (a pad picked up or put down)
	c.Input.deviceChanged:Connect(function()
		if Inventory.open then
			Inventory.render()
		end
	end)
	-- a gamepad carrying a picked-up item: the fit cue follows the selection from cell to cell (audit ui.9)
	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		if Inventory.open and updateCue then
			updateCue()
		end
	end)
	c.State.changed:Connect(function()
		if Inventory.open then
			Inventory.renderSoon()
		end
	end)
	c.State.on("loot", function(v)
		if v and not loot then
			Inventory.cpanel = "OTHER" -- a container or body just opened: show it first on a phone
		end
		loot = v
		if Inventory.open then
			Inventory.render()
		else
			Inventory.show()
		end
	end)
	c.State.on("progress", function(p)
		status = { text = p.label or "WORKING", t0 = os.clock(), dur = p.t or 1 }
		if Inventory.open then
			Inventory.render()
			task.delay((p.t or 1) + 0.05, function()
				if Inventory.open then
					Inventory.render()
				end
			end)
		end
	end)
	c.State.on("summary", function()
		loot = nil
		Inventory.close()
	end)
	UIS.InputChanged:Connect(function(input)
		if drag and input.UserInputType == Enum.UserInputType.MouseMovement then
			if DEBUG and not drag.started then
				print("[ZR] drag move", mouse())
			end
			if not drag.started and (mouse() - drag.start).Magnitude > 6 then
				drag.started = true
				drag.r0 = drag.r
				selected = nil
			end
			updateGhost()
			updateCue()
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if drag and input.UserInputType == Enum.UserInputType.MouseButton1 then
			endDrag()
		end
	end)
	UIS.InputBegan:Connect(function(input)
		if not Inventory.open then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			if drag and drag.started then
				drag.w, drag.h = drag.h, drag.w
				drag.r = 1 - drag.r
				updateGhost()
				updateCue()
			else
				rot = 1 - rot
				updateCue()
			end
		elseif input.KeyCode == Enum.KeyCode.Delete and not UIS:GetFocusedTextBox() and not (drag and drag.started) then
			-- Tarkov: Del discards the item under the cursor (else the one picked up), through the same two presses as
			-- DISCARD; in a raid it goes on the ground, as DROP does (audit ui.9)
			local t = hoverG or selected
			if t then
				for _, a in actionsFor(t.ref, t.g) do
					if a.discard then
						a.discard()
						break
					end
				end
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and menu and not inside(menu, mouse()) then
			closeMenu()
		end
	end)
end

return Inventory
