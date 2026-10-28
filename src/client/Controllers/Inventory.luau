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
local Grid = require(Shared.Grid)
local Util = require(Shared.Util)
local TD = require(Shared.TraderData)

local Inventory = { open = false }
local ctx, K
local gui, panel, menu, ghost
local loot = nil
local selected = nil -- { g, ref }
local rot = 0
local gridTargets, slotTargets = {}, {}
local drag = nil
local busy = false
local firstFocus = nil
local status = nil -- { text, t0, dur }
local hoverG = nil
local hover = nil -- drop target under the cursor, from engine MouseEnter events (matches what the user sees)

local function hoverOn(obj, target)
	obj.MouseEnter:Connect(function()
		hover = target
	end)
	obj.MouseLeave:Connect(function()
		if hover == target then
			hover = nil
		end
	end)
end

local defs = Items.defs
local MOUNTS = { "rail", "muzzle", "under", "side" }
local MOUNT_NAMES = { rail = "OPTIC", muzzle = "MUZZLE", under = "FOREGRIP", side = "TACTICAL" }
local SLOT_LAYOUT = {
	{ "head", 0, 0, 2, 2 }, { "ears", 0, 2, 1, 1 }, { "face", 1, 2, 1, 1 }, { "armor", 2, 0, 3, 3 }, { "rig", 5, 0, 3, 3 }, { "back", 8, 0, 3, 3 },
	{ "primary", 0, 3, 5, 2 }, { "holster", 5, 3, 2, 2 }, { "melee", 7, 3, 1, 2 }, { "secure", 8, 3, 3, 2 },
	{ "secondary", 0, 5, 5, 2 },
}

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

local function mouse()
	return UIS:GetMouseLocation()
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
		return string.format("%d/%d", it.a or 0, d.capacity or 0)
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

local function findFree(view, cid, w, h)
	local pl = view.grids and view.grids[cid]
	if not pl then
		return nil
	end
	local cw, ch
	if cid == "stash" then
		cw, ch = Config.STASH_W, view.stashH or Config.STASH_H
	elseif cid == "pockets" then
		cw, ch = Config.POCKETS_W, Config.POCKETS_H
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
	local x, y, r = Grid.findFree(cw, ch, pl, function(gg)
		local it = view.items[gg]
		local d = it and defs[it.id]
		return d and d.w or 1, d and d.h or 1
	end, w, h)
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

-- client mirror of the server's Inv.canMod (mount present, muzzle devices match the caliber)
local function modFits(wit, mit)
	local wd, md = defs[wit.id], defs[mit.id]
	local spec = wd and wd.weapon and Weapons[wd.weapon]
	local slotOk = spec and spec.slots and md and md.mod and spec.slots[md.mod.slot]
	if not slotOk then
		return false
	end
	return not (md.mod.caliber and slotOk ~= true and slotOk ~= md.mod.caliber)
end

-- client mirror of Settle.insurable: no ammo, quest items, recovery-kit items or secure-container contents
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
	if not d or it.rk or d.kind == "secure" or d.kind == "quest" or d.kind == "ammo" then
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

local function insureCost(view, g)
	local uid = game:GetService("Players").LocalPlayer.UserId
	local it = view.items[g]
	local cost = 0
	local list = { g, it.mag }
	for _, mg in it.mods or {} do
		table.insert(list, mg)
	end
	for _, x in list do
		local xi = x and view.items[x]
		if xi and xi.ins ~= uid and insurable(view, x) then
			cost += math.max(150, math.floor(Items.valueOf(xi) * Config.INSURANCE_RATE))
		end
	end
	return cost
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
		table.insert(list, { label = label, fn = fn, tone = tone })
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
	if Items.SLOTS and (d.kind == "weapon" or d.kind == "pistol" or d.kind == "melee" or d.kind == "helmet" or d.kind == "headwear" or d.kind == "headset" or d.kind == "facecover" or d.kind == "armor" or d.kind == "rig" or d.kind == "backpack" or (d.kind == "secure" and not inRaid)) and k ~= "slot" then
		add("EQUIP", function()
			req({ op = "equip", g = g, from = ref, to = "me" })
		end)
	end
	if mine and (d.kind == "med" or d.kind == "food") and known(it.id) then
		add("USE", function()
			req({ op = "use", g = g })
		end, "good")
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
	-- weapon modding: detach installed attachments; install an attachment on any compatible weapon you carry
	if mine and d.weapon then
		for _, mount in MOUNTS do
			local mg = it.mods and it.mods[mount]
			local m = mg and view.items[mg]
			if m then
				add("REMOVE " .. defs[m.id].short, function()
					req({ op = "unmod", g = g, mount = mount })
				end)
			end
		end
	end
	if mine and d.kind == "mod" and locate(view, g) == "grid" then
		for wg, w in view.items do
			if w ~= it and defs[w.id].weapon and modFits(w, it) then
				local occupied = w.mods and w.mods[d.mod.slot]
				add((occupied and "SWAP ONTO " or "INSTALL ON ") .. defs[w.id].short, function()
					req({ op = "mod", g = wg, mod = g })
				end, "good")
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
		add("DROP", function()
			req({ op = "drop", g = g })
		end, "warn")
	end
	if mine and not inRaid and insurable(view, g) then
		local cost = insureCost(view, g)
		if cost > 0 then
			add(string.format("INSURE  -%s %s", Util.commas(cost), Config.CURRENCY), function()
				req({ op = "insure", g = g })
			end, "good")
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
		add("DISCARD", function()
			req({ op = "discard", g = g })
			selected = nil
		end, "warn")
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
	if #list == 0 then
		return
	end
	menu = K.frame(gui, { Name = "ContextMenu", Position = UDim2.fromOffset(pos.X + 4, pos.Y + 4), Size = UDim2.fromOffset(230, #list * 30 + 8), BackgroundColor3 = K.C.bg, ZIndex = 50 })
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
	local s = menu.AbsoluteSize
	menu.Position = UDim2.fromOffset(math.min(pos.X + 4, vp.X - s.X - 4), math.min(pos.Y + 4, vp.Y - s.Y - 4))
end

-- ── drawing ────────────────────────────────────────────────────────────────────
local function onTileClick(ref, g)
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

local function tile(parent, view, ref, g, px, py, pw, ph, cellAbs, dropAs)
	local it = view.items[g]
	local d = defs[it.id]
	local isKnown = known(it.id)
	local isSel = selected and selected.g == g and selected.ref == ref
	local base = isKnown and d.color:Lerp(K.C.panel, 0.42) or Color3.fromHex("2A2D2E")
	local t = K.new("TextButton", {
		Name = "Tile_" .. g, Text = "", AutoButtonColor = true, BorderSizePixel = 0, Position = UDim2.fromOffset(px, py),
		Size = UDim2.fromOffset(pw, ph), BackgroundColor3 = base, ZIndex = 4, Selectable = true, SelectionImageObject = K.selection(),
	}, parent)
	K.stroke(t, isSel and K.C.ochre or K.C.line, isSel and 0 or 0.72, isSel and 2 or 1)
	local small = math.min(pw, ph) < 40
	K.label(t, isKnown and d.short or "?", small and 10 or 12, { Position = UDim2.fromOffset(3, 2), Size = UDim2.new(1, -5, 0, 13), FontFace = K.bold, ZIndex = 5, TextTruncate = Enum.TextTruncate.AtEnd })
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
			local gc = cellAbs or Inventory.cell or 40
			drag = { g = g, ref = ref, start = m, started = false, grabX = cellAbs and math.floor(rel.X / gc) or 0, grabY = cellAbs and math.floor(rel.Y / gc) or 0, cell = Inventory.cell or gc, w = d.w, h = d.h, r = 0, label = isKnown and d.short or "?" }
			local _, _, p = locate(viewOf(ref), g)
			if p and p.r == 1 then
				drag.w, drag.h, drag.r = d.h, d.w, 1
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			openMenu(ref, g, mouse())
		end
	end)
	t.MouseEnter:Connect(function()
		hoverG = { g = g, ref = ref }
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
			if not firstFocus then
				firstFocus = cb
			end
		end
	end
	for guid, p in (view.grids and view.grids[cid]) or {} do
		local it = view.items[guid]
		if it then
			local d = defs[it.id]
			local iw, ih = Grid.dims(d.w, d.h, p.r)
			tile(g, view, ref, guid, (p.x - 1) * cell + 1, (p.y - 1) * cell + 1, iw * cell - 2, ih * cell - 2, cell, { kind = "cell", ref = ref, cid = cid, x = p.x, y = p.y, occupied = guid })
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
local function drawGear(parent, view, ref, cell, width)
	local y = 0
	if ref == "me" then
		local hf = K.frame(parent, { Name = "Health", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 64) })
		y += drawHealth(hf, width - 12)
	end
	local slotCell = math.floor(math.min(cell * 1.05, (width - 10) / 11))
	local y0 = y
	for _, e in SLOT_LAYOUT do
		local slot, sx, sy, sw, sh = e[1], e[2], e[3], e[4], e[5]
		drawSlot(parent, view, ref, slot, sx * slotCell, y0 + sy * (slotCell + 6), sw * slotCell - 6, sh * slotCell - 2, slotCell)
	end
	y += 7 * (slotCell + 6) + 4
	local ph
	if view.grids and view.grids.pockets then
		local _, h0 = drawGrid(parent, view, ref, "pockets", "POCKETS", Config.POCKETS_W, Config.POCKETS_H, cell, 0, y, nil)
		ph = h0
	else
		K.label(parent, "POCKETS  -  NOT SEARCHED", 11, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 16), TextColor3 = K.C.dim })
		ph = 20
	end
	local secure = view.slots and view.slots.secure
	if secure and view.grids and view.grids[secure] and view.items[secure] then
		local sd = defs[view.items[secure].id]
		drawGrid(parent, view, ref, secure, "SECURE", sd.grid.w, sd.grid.h, cell, (Config.POCKETS_W + 1) * cell, y, nil)
		ph = math.max(ph, sd.grid.h * cell + 22)
	end
	y += ph + 4
	for _, s in { "rig", "back" } do
		local cg = view.slots and view.slots[s]
		local it = cg and view.items[cg]
		if it and view.grids and view.grids[cg] then
			local cd = defs[it.id]
			local _, gh = drawGrid(parent, view, ref, cg, (s == "rig" and "RIG  " or "BACKPACK  ") .. string.upper(cd.name), cd.grid.w, cd.grid.h, cell, 0, y, nil)
			y += gh + 4
		elseif ref ~= "me" and it and defs[it.id].grid then
			-- body container not yet searched
			K.label(parent, (s == "rig" and "RIG" or "BACKPACK") .. "  -  NOT SEARCHED", 11, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 16), TextColor3 = K.C.dim })
			y += 20
		end
	end
	return y
end

local function detail(parent, w, h)
	local det = K.frame(parent, { Name = "Detail", Size = UDim2.fromOffset(w, h), BackgroundColor3 = K.C.panel })
	K.stroke(det, K.C.line, 0.7)
	K.pad(det, 8)
	local sel = selected or hoverG
	local view = sel and viewOf(sel.ref)
	local it = view and view.items[sel.g]
	if not it then
		K.label(det, ctx.Input.device() == "Gamepad" and "Select an item (A), then a free cell or slot." or "Drag items between grids. Right-click for actions, Ctrl+click quick move, Alt+click equip, R rotates while dragging.", 12, { Size = UDim2.fromScale(1, 1), TextWrapped = true, TextColor3 = K.C.dim, TextYAlignment = Enum.TextYAlignment.Top })
		return
	end
	local d = defs[it.id]
	local isKnown = known(it.id)
	K.label(det, isKnown and string.upper(d.name) or "UNKNOWN ITEM", 14, { FontFace = K.bold, Size = UDim2.new(0.6, 0, 0, 18) })
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
			table.insert(lines, string.format("CLASS %d   DURABILITY %d/%d", d.armor.class, math.ceil(it.dur or d.armor.dur), d.armor.dur))
		end
		if d.grid then
			table.insert(lines, string.format("CAPACITY %dx%d", d.grid.w, d.grid.h))
		end
		local wspec = d.weapon and Weapons[d.weapon]
		if wspec and next(wspec.slots or {}) then
			local mods = {}
			for _, mount in MOUNTS do
				if wspec.slots[mount] then
					local mg = it.mods and it.mods[mount]
					local m = mg and view.items[mg]
					table.insert(mods, MOUNT_NAMES[mount] .. ": " .. (m and defs[m.id].short or "-"))
				end
			end
			table.insert(lines, table.concat(mods, "   "))
		end
		if d.mod then
			local fx = {}
			if d.mod.recoil and d.mod.recoil ~= 1 then
				table.insert(fx, string.format("RECOIL %+d%%", math.floor((d.mod.recoil - 1) * 100 + 0.5)))
			end
			if d.mod.ergo and d.mod.ergo ~= 0 then
				table.insert(fx, string.format("ERGO %+d", d.mod.ergo))
			end
			if d.mod.loud and d.mod.loud ~= 1 then
				table.insert(fx, string.format("LOUDNESS %+d%%", math.floor((d.mod.loud - 1) * 100 + 0.5)))
			end
			if d.mod.zoom then
				table.insert(fx, string.format("%dx ZOOM", d.mod.zoom))
			end
			table.insert(fx, "MOUNT: " .. (MOUNT_NAMES[d.mod.slot] or "?") .. (d.mod.caliber and (" " .. d.mod.caliber) or ""))
			table.insert(lines, table.concat(fx, "   "))
		end
		table.insert(lines, string.format("VALUE %s %s   ·   %.2f kg   ·   %dx%d%s%s", Util.commas(Items.valueOf(it)), Config.CURRENCY, massOf(view, sel.g), d.w, d.h, it.fir and "   ·   FOUND IN RAID" or "", it.ins and "   ·   INSURED" or ""))
	else
		table.insert(lines, "Examine this item to identify it.")
	end
	K.label(det, table.concat(lines, "\n"), 11, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(0.6, 0, 1, -20), TextWrapped = true, TextColor3 = K.C.dim, TextYAlignment = Enum.TextYAlignment.Top })
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

function Inventory.render()
	if not Inventory.open then
		return
	end
	local d = data()
	if not d or not d.slots then
		return
	end
	if selected and not (viewOf(selected.ref) and viewOf(selected.ref).items[selected.g]) then
		selected = nil
	end
	if panel then
		panel:Destroy()
	end
	closeMenu()
	table.clear(gridTargets)
	table.clear(slotTargets)
	hover = nil
	firstFocus = nil
	local inRaid = ctx.State.inRaid()
	local vp = K.viewport(gui)
	local W = math.floor(math.min(vp.X - 12, 1360))
	local H = math.floor(math.min(vp.Y - 8, 800))
	panel = K.frame(gui, { Name = "InvPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.03 })
	K.stroke(panel, K.C.line, 0.45)
	-- header
	local weight = gearWeight(d)
	local head = inRaid and ("FIELD KIT  //  " .. Config.MAP_NAME) or "HIDEOUT  //  STASH & GEAR"
	K.label(panel, head, 16, { Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(W - 220, 22), FontFace = K.bold })
	local info = string.format("WEIGHT %.1f kg", weight)
	if not inRaid then
		info ..= string.format("   ·   %s %s", Util.commas(d.money or 0), Config.CURRENCY)
	end
	if status and os.clock() - status.t0 < status.dur then
		info ..= string.format("   ·   %s %.1fs", status.text, status.dur - (os.clock() - status.t0))
	end
	K.label(panel, info, 12, { Position = UDim2.fromOffset(12, 28), Size = UDim2.fromOffset(W - 220, 16), TextColor3 = weight > 40 and K.C.orange or K.C.dim })
	local close = K.button(panel, "CLOSE [" .. ctx.Input.label("Inventory") .. "]", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(150, 30) })
	close.Activated:Connect(Inventory.close)
	local top, detailH = 52, 112
	local bodyH = H - top - detailH - 14
	local leftW = math.floor(W * 0.47)
	local rightW = W - leftW - 30
	-- cell size from the widest thing on the left (11 slot columns) and the right (stash 10 columns)
	local cell = math.floor(math.clamp(math.min((leftW - 20) / 11, (rightW - 24) / Config.STASH_W), 24, 46))
	Inventory.cell = cell
	-- left: my gear
	local left = K.new("ScrollingFrame", { Name = "Gear", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(12, top), Size = UDim2.fromOffset(leftW, bodyH), ScrollBarThickness = 5, CanvasSize = UDim2.new(), Selectable = false }, panel)
	local gh = drawGear(left, d, "me", cell, leftW)
	left.CanvasSize = UDim2.fromOffset(0, gh + 10)
	for _, t in gridTargets do
		t.clip = t.clip or left
	end
	for _, t in slotTargets do
		t.clip = t.clip or left
	end
	-- right: stash / container / body
	local right = K.new("ScrollingFrame", { Name = "Other", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(leftW + 22, top), Size = UDim2.fromOffset(rightW, bodyH), ScrollBarThickness = 5, CanvasSize = UDim2.new(), Selectable = false }, panel)
	local nG, nS = #gridTargets, #slotTargets
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
		local _, sh = drawGrid(right, d, "me", "stash", "STASH  " .. Config.STASH_W .. "x" .. stashH, Config.STASH_W, stashH, cell, 0, 0, nil)
		right.CanvasSize = UDim2.fromOffset(0, sh + 60)
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
		K.label(right, "Open a container or body to loot it.\nPress " .. ctx.Input.label("Inventory") .. " to close.", 13, { Size = UDim2.new(1, 0, 0, 40), TextColor3 = K.C.dim, TextWrapped = true })
	end
	for i = nG + 1, #gridTargets do
		gridTargets[i].clip = right
	end
	for i = nS + 1, #slotTargets do
		slotTargets[i].clip = right
	end
	-- detail strip
	local det = K.frame(panel, { BackgroundTransparency = 1, Position = UDim2.new(0, 12, 1, -detailH - 8), Size = UDim2.new(1, -24, 0, detailH) })
	detail(det, W - 24, detailH)
	if ctx.Input.device() == "Gamepad" then
		K.focus(firstFocus)
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
			return { kind = "cell", ref = t.ref, cid = t.cid, x = math.floor(rel.X / t.cell) + 1, y = math.floor(rel.Y / t.cell) + 1, cell = t.cell }
		end
	end
	return nil
end

local function endDrag()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
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
	if not tgt then
		return
	end
	if tgt.kind == "slot" then
		req({ op = "move", g = dd.g, from = dd.ref, to = tgt.ref, dest = { slot = tgt.slot } })
		return
	end
	local view = viewOf(tgt.ref)
	local occupant = nil
	if tgt.occupied and tgt.occupied ~= dd.g then
		local p = view and view.grids and view.grids[tgt.cid] and view.grids[tgt.cid][tgt.occupied]
		if p then
			req({ op = "move", g = dd.g, from = dd.ref, to = tgt.ref, dest = { c = tgt.cid, x = p.x, y = p.y, r = 0 } })
			return
		end
	end
	if tgt.occupied == dd.g then
		return
	end
	if view and view.grids and view.grids[tgt.cid] then
		for og, p in view.grids[tgt.cid] do
			local it = view.items[og]
			local d = it and defs[it.id]
			if d and og ~= dd.g then
				local w, h = Grid.dims(d.w, d.h, p.r)
				if tgt.x >= p.x and tgt.x < p.x + w and tgt.y >= p.y and tgt.y < p.y + h then
					occupant = p
				end
			end
		end
	end
	local dest
	if occupant then
		dest = { c = tgt.cid, x = occupant.x, y = occupant.y, r = 0 }
	else
		local gx, gy = dd.grabX, dd.grabY
		if dd.r ~= (dd.r0 or dd.r) then
			gx, gy = gy, gx
		end
		dest = { c = tgt.cid, x = math.max(1, tgt.x - gx), y = math.max(1, tgt.y - gy), r = dd.r }
	end
	req({ op = "move", g = dd.g, from = dd.ref, to = tgt.ref, dest = dest })
end

local function updateGhost()
	if not drag or not drag.started then
		return
	end
	local c = drag.cell
	if not ghost then
		ghost = K.frame(gui, { Name = "DragGhost", BackgroundColor3 = K.C.ochre, BackgroundTransparency = 0.6, ZIndex = 60, Active = false })
		pcall(function()
			ghost.Interactable = false
		end)
		K.stroke(ghost, K.C.ochre, 0)
		K.label(ghost, drag.label, 12, { Position = UDim2.fromOffset(3, 2), Size = UDim2.new(1, -4, 0, 14), FontFace = K.bold, ZIndex = 61 })
	end
	local m = mouse()
	local gx, gy = drag.grabX, drag.grabY
	if drag.r ~= drag.r0 then
		gx, gy = gy, gx
	end
	ghost.Size = UDim2.fromOffset(drag.w * c - 2, drag.h * c - 2)
	ghost.Position = UDim2.fromOffset(m.X - gx * c - c * 0.5 + 6, m.Y - gy * c - c * 0.5 + 6)
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
	selected = nil
	rot = 0
	drag = nil
	closeMenu()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	local l = loot
	loot = nil
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
		if down and Inventory.open then
			if menu then
				closeMenu()
			else
				Inventory.close()
			end
		end
	end)
	c.State.changed:Connect(function()
		if Inventory.open then
			Inventory.render()
		end
	end)
	c.State.on("loot", function(v)
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
			else
				rot = 1 - rot
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and menu and not inside(menu, mouse()) then
			closeMenu()
		end
	end)
end

return Inventory
