--!nonstrict
-- Inventory / stash / loot UI. Works without drag: select an item (click/tap/A), then tap a target cell,
-- a slot, or an action button. All changes are server requests; UI re-renders from the server snapshot.
local GuiService = game:GetService("GuiService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("EFB")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Grid = require(Shared.Grid)
local Util = require(Shared.Util)

local Inventory = { open = false }
local ctx, K
local gui, panel
local mode = "raid"
local selected = nil -- { g = guid, src = "inv" | "loot" }
local rot = 0
local loot = nil
local tiles = {}
local firstFocus = nil
local busy = false

local function req(payload)
	if busy then
		return
	end
	busy = true
	local res = ctx.State.req("inv", payload)
	busy = false
	if res and not res.ok and not res.msg then
		ctx.State.toast(string.gsub(res.code or "FAILED", "_", " "), "warn")
	end
	return res
end

local function itemText(it, d)
	local def = Items.defs[it.id]
	if def.kind == "weapon" then
		local mag = it.mag and d.items[it.mag]
		return mag and string.format("%d/%d", mag.a or 0, Items.defs.R17_MAG.capacity) or "NO MAG"
	elseif def.kind == "mag" then
		return string.format("%d/%d", it.a or 0, def.capacity)
	elseif def.stack > 1 then
		return "x" .. it.n
	end
	return ""
end

local function tile(parent, guid, it, d, px, py, pw, ph)
	local def = Items.defs[it.id]
	local isSel = selected and selected.g == guid
	local t = K.new("TextButton", {
		Text = "", AutoButtonColor = true, BorderSizePixel = 0, Position = UDim2.fromOffset(px, py), Size = UDim2.fromOffset(pw, ph),
		BackgroundColor3 = def.color:Lerp(K.C.panel, 0.45), ZIndex = 3, Selectable = true, SelectionImageObject = K.selection(),
	}, parent)
	K.stroke(t, isSel and K.C.ochre or K.C.line, isSel and 0 or 0.7, isSel and 2 or 1)
	K.label(t, def.short, 12, { Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -6, 0, 14), FontFace = K.bold, ZIndex = 4 })
	K.label(t, itemText(it, d), 11, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -1), Size = UDim2.new(1, -6, 0, 14), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
	if def.rarity ~= "common" then
		K.frame(t, { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = (def.rarity == "rare") and K.C.orange or K.C.ochre, ZIndex = 4 })
	end
	if it.rk then
		K.label(t, "RK", 9, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, -1), Size = UDim2.fromOffset(20, 12), TextColor3 = K.C.dim, ZIndex = 4 })
	end
	tiles[guid] = t
	return t
end

local function onTile(guid)
	local d = ctx.State.data
	if selected and selected.src == "inv" and selected.g ~= guid then
		local a, b = d.items[selected.g], d.items[guid]
		if a and b and a.id == b.id and Items.defs[a.id].stack > 1 then
			for _, c in { "stash", "pockets", "bag" } do
				local p = d[c] and d[c][guid]
				if p then
					req({ op = "move", g = selected.g, dest = { c = c, x = p.x, y = p.y, r = 0 } })
					selected = nil
					return
				end
			end
		end
	end
	selected = { g = guid, src = "inv" }
	Inventory.render()
end

local function onCell(c, x, y)
	if not selected then
		return
	end
	if selected.src == "inv" then
		local g = selected.g
		local res = req({ op = "move", g = g, dest = { c = c, x = x, y = y, r = rot } })
		if res and res.ok then
			selected = nil
		end
	elseif selected.src == "loot" and loot then
		req({ op = "take", cid = loot.cid, g = selected.g })
		selected = nil
	end
end

local function drawGrid(parent, d, c, title, w, h, cell, x0, y0)
	local holder = K.frame(parent, { BackgroundTransparency = 1, Position = UDim2.fromOffset(x0, y0), Size = UDim2.fromOffset(w * cell, h * cell + 20) })
	K.label(holder, title, 11, { Size = UDim2.new(1, 0, 0, 16), TextColor3 = K.C.dim })
	local g = K.frame(holder, { Position = UDim2.fromOffset(0, 18), Size = UDim2.fromOffset(w * cell, h * cell), BackgroundColor3 = K.C.panel })
	K.stroke(g, K.C.line, 0.75)
	if w == 0 or h == 0 then
		K.label(holder, "  — none —", 12, { Position = UDim2.fromOffset(0, 18), TextColor3 = K.C.dim })
		return holder
	end
	for yy = 1, h do
		for xx = 1, w do
			local cb = K.new("TextButton", {
				Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = K.C.cell, BackgroundTransparency = 0.45,
				Position = UDim2.fromOffset((xx - 1) * cell + 1, (yy - 1) * cell + 1), Size = UDim2.fromOffset(cell - 2, cell - 2),
				Selectable = true, SelectionImageObject = K.selection(), ZIndex = 2,
			}, g)
			cb.Activated:Connect(function()
				onCell(c, xx, yy)
			end)
			if not firstFocus then
				firstFocus = cb
			end
		end
	end
	for guid, p in d[c] or {} do
		local it = d.items[guid]
		if it then
			local def = Items.defs[it.id]
			local iw, ih = Grid.dims(def.w, def.h, p.r)
			local t = tile(g, guid, it, d, (p.x - 1) * cell + 1, (p.y - 1) * cell + 1, iw * cell - 2, ih * cell - 2)
			t.Activated:Connect(function()
				onTile(guid)
			end)
		end
	end
	return holder
end

local function drawSlot(parent, d, slotName, title, x0, y0, w, h)
	local holder = K.frame(parent, { BackgroundTransparency = 1, Position = UDim2.fromOffset(x0, y0), Size = UDim2.fromOffset(w, h + 18) })
	K.label(holder, title, 11, { Size = UDim2.new(1, 0, 0, 16), TextColor3 = K.C.dim })
	local guid = d.slots[slotName]
	local it = guid and d.items[guid]
	if it then
		local t = tile(holder, guid, it, d, 0, 18, w, h)
		local def = Items.defs[it.id]
		K.label(t, def.name, 11, { Position = UDim2.fromOffset(4, 16), Size = UDim2.new(1, -8, 0, 14), TextColor3 = K.C.dim, ZIndex = 4 })
		t.Activated:Connect(function()
			onTile(guid)
		end)
	else
		local e = K.button(holder, "EMPTY", { Position = UDim2.fromOffset(0, 18), Size = UDim2.fromOffset(w, h), BackgroundColor3 = K.C.panel, TextColor3 = K.C.dim })
		e.Activated:Connect(function()
			if selected and selected.src == "inv" then
				req({ op = "quick", g = selected.g, to = "equip" })
				selected = nil
			end
		end)
	end
	return holder
end

local function loadMass(d, list)
	local m = 0
	for _, c in list do
		for g in d[c] or {} do
			local it = d.items[g]
			if it then
				m += Items.defs[it.id].mass * it.n
			end
		end
	end
	for _, g in d.slots or {} do
		local it = d.items[g]
		if it then
			m += Items.defs[it.id].mass
		end
	end
	return m
end

local function actionButtons(parent, d, y)
	local col = K.frame(parent, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 260) })
	K.list(col, nil, 6)
	local function act(text, fn, tone)
		local b = K.button(col, text, { Size = UDim2.new(1, 0, 0, 32), TextSize = 13 })
		if tone == "warn" then
			b.TextColor3 = K.C.orange
		end
		b.Activated:Connect(fn)
		return b
	end
	if not selected then
		return col
	end
	local g = selected.g
	if selected.src == "loot" then
		act("TAKE", function()
			req({ op = "take", cid = loot.cid, g = g })
			selected = nil
		end)
		return col
	end
	local it = d.items[g]
	if not it then
		return col
	end
	local def = Items.defs[it.id]
	if mode == "stash" then
		act("TO STASH", function()
			req({ op = "quick", g = g, to = "stash" })
		end)
		act("TO LOADOUT", function()
			req({ op = "quick", g = g, to = "loadout" })
		end)
	else
		act("TO POCKETS", function()
			req({ op = "quick", g = g, to = "pockets" })
		end)
		act("TO PACK", function()
			req({ op = "quick", g = g, to = "bag" })
		end)
	end
	if def.kind == "weapon" or def.kind == "bag" then
		act("EQUIP", function()
			req({ op = "quick", g = g, to = "equip" })
		end)
	end
	act("ROTATE NEXT PLACEMENT (" .. (rot == 1 and "ON" or "OFF") .. ")", function()
		rot = 1 - rot
		Inventory.render()
	end)
	if mode == "raid" then
		if def.kind == "heal" then
			act("USE", function()
				req({ op = "use", g = g })
			end)
		end
		if loot then
			act("PUT IN " .. string.upper(loot.label), function()
				req({ op = "put", cid = loot.cid, g = g })
				selected = nil
			end)
		end
		act("DROP", function()
			req({ op = "drop", g = g })
			selected = nil
		end, "warn")
	else
		local value = math.floor(Items.valueOf(it) * Config.SELL_RATE)
		act("SELL  +" .. value .. " " .. Config.CURRENCY, function()
			req({ op = "sell", g = g })
			selected = nil
		end, "warn")
	end
	return col
end

function Inventory.render()
	if not Inventory.open then
		return
	end
	local d = ctx.State.data
	if not d then
		return
	end
	if selected and selected.src == "inv" and not d.items[selected.g] then
		selected = nil
	end
	if panel then
		panel:Destroy()
	end
	table.clear(tiles)
	firstFocus = nil
	local vp = K.viewport()
	local W = math.floor(math.min(vp.X * 0.96, 1200))
	local H = math.floor(math.min(vp.Y * 0.9, 700))
	panel = K.frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.04 })
	K.stroke(panel, K.C.line, 0.45)
	-- header
	local title = (mode == "stash") and "STASH & LOADOUT  //  RELAY 7" or "FIELD KIT  //  " .. Config.MAP_NAME
	K.label(panel, title, 16, { Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(W - 200, 22), FontFace = K.bold })
	local info = string.format("LOAD %.1f kg", loadMass(d, { "pockets", "bag" }))
	if mode == "stash" then
		info ..= string.format("   ·   %s %s", Util.commas(d.money or 0), Config.CURRENCY)
	end
	K.label(panel, info, 12, { Position = UDim2.fromOffset(14, 30), Size = UDim2.fromOffset(W - 200, 16), TextColor3 = K.C.dim })
	local close = K.button(panel, "CLOSE [" .. ctx.Input.label("Inventory") .. "]", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(150, 30) })
	close.Activated:Connect(Inventory.close)
	local top = 56
	local bodyH = H - top - 10
	-- column widths
	local detailW = math.floor(W * 0.24)
	local leftW = W - detailW - 30
	local cell
	if mode == "stash" then
		local stashW = math.floor(leftW * 0.56)
		cell = math.floor(math.clamp(math.min(stashW / Config.STASH_W, (bodyH - 30) / Config.STASH_H), 24, 50))
		drawGrid(panel, d, "stash", "STASH  " .. Config.STASH_W .. "x" .. Config.STASH_H, Config.STASH_W, Config.STASH_H, cell, 12, top)
		local lx = 12 + Config.STASH_W * cell + 18
		local lw = leftW - (lx - 12)
		local lcell = math.floor(math.clamp(math.min(lw / 4, (bodyH - 150) / 6), 22, 46))
		drawSlot(panel, d, "primary", "PRIMARY", lx, top, math.min(lw, lcell * 4), lcell + 6)
		drawSlot(panel, d, "bag", "PACK", lx, top + lcell + 30, math.min(lw, lcell * 2), lcell)
		drawGrid(panel, d, "pockets", "POCKETS", Config.POCKETS_W, Config.POCKETS_H, lcell, lx, top + lcell * 2 + 56)
		local bw, bh = 0, 0
		local bagIt = d.slots.bag and d.items[d.slots.bag]
		if bagIt then
			local bd = Items.defs[bagIt.id]
			bw, bh = bd.bagW, bd.bagH
		end
		drawGrid(panel, d, "bag", "PACK COMPARTMENT", bw, bh, lcell, lx, top + lcell * 3 + 82)
	else
		local lootW = loot and math.floor(leftW * 0.42) or 0
		local invW = leftW - lootW
		cell = math.floor(math.clamp(math.min(invW / 6, (bodyH - 120) / 6.4), 24, 52))
		drawSlot(panel, d, "primary", "PRIMARY", 12, top, cell * 4, cell + 6)
		drawSlot(panel, d, "bag", "PACK", 12 + cell * 4 + 12, top, cell * 2, cell + 6)
		drawGrid(panel, d, "pockets", "POCKETS", Config.POCKETS_W, Config.POCKETS_H, cell, 12, top + cell + 32)
		local bw, bh = 0, 0
		local bagIt = d.slots.bag and d.items[d.slots.bag]
		if bagIt then
			local bd = Items.defs[bagIt.id]
			bw, bh = bd.bagW, bd.bagH
		end
		drawGrid(panel, d, "bag", "PACK COMPARTMENT", bw, bh, cell, 12, top + cell * 2 + 58)
		if loot then
			local lx = 12 + invW
			local lf = K.frame(panel, { Position = UDim2.fromOffset(lx, top), Size = UDim2.fromOffset(lootW - 12, bodyH - 10), BackgroundColor3 = K.C.panel })
			K.stroke(lf, K.C.ochre, 0.4)
			K.label(lf, "  " .. string.upper(loot.label), 13, { Size = UDim2.new(1, 0, 0, 22), FontFace = K.bold, TextColor3 = K.C.ochre })
			local list = K.new("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 28), Size = UDim2.new(1, -12, 1, -76), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, BorderSizePixel = 0, Selectable = false }, lf)
			K.list(list, nil, 4)
			if #loot.items == 0 then
				K.label(list, "Empty.", 12, { TextColor3 = K.C.dim })
			end
			for i, li in loot.items do
				local def = Items.defs[li.id]
				local extra = (li.n and li.n > 1) and (" x" .. li.n) or ""
				if def and def.kind == "mag" then
					extra = string.format(" %d/%d", li.a or 0, def.capacity)
				end
				local b = K.button(list, "", { Size = UDim2.new(1, -6, 0, 34), LayoutOrder = i, TextXAlignment = Enum.TextXAlignment.Left })
				b.Text = string.format("  TAKE ▸ %s%s", def and def.name or li.id, extra)
				b.TextSize = 13
				if def and def.rarity ~= "common" then
					b.TextColor3 = (def.rarity == "rare") and K.C.orange or K.C.ochre
				end
				b.Activated:Connect(function()
					req({ op = "take", cid = loot.cid, g = li.g })
				end)
				if i == 1 then
					firstFocus = b
				end
			end
			local all = K.button(lf, "TAKE ALL", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -12, 0, 34) })
			all.Activated:Connect(function()
				for _, li in loot.items do
					local r = req({ op = "take", cid = loot.cid, g = li.g })
					if not r or not r.ok then
						break
					end
				end
			end)
		end
	end
	-- details column
	local dx = W - detailW - 12
	local det = K.frame(panel, { Position = UDim2.fromOffset(dx, top), Size = UDim2.fromOffset(detailW, bodyH - 10), BackgroundColor3 = K.C.panel })
	K.stroke(det, K.C.line, 0.7)
	K.pad(det, 10)
	local sel = selected and selected.src == "inv" and d.items[selected.g]
	if sel then
		local def = Items.defs[sel.id]
		K.label(det, string.upper(def.name), 15, { FontFace = K.bold, TextWrapped = true, Size = UDim2.new(1, 0, 0, 20) })
		K.label(det, def.desc, 12, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 48), TextWrapped = true, TextColor3 = K.C.dim, TextYAlignment = Enum.TextYAlignment.Top })
		K.label(det, string.format("VALUE %d %s   MASS %.1f   %dx%d", Items.valueOf(sel), Config.CURRENCY, def.mass * sel.n, def.w, def.h), 11, { Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 16), TextColor3 = K.C.ochre })
		actionButtons(det, d, 100)
	else
		K.label(det, "SELECT AN ITEM", 13, { FontFace = K.bold, TextColor3 = K.C.dim })
		K.label(det, "Tap or press " .. ((ctx.Input.device() == "Gamepad") and "A" or "click") .. " on an item, then a free cell, slot or action.", 12, { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 60), TextWrapped = true, TextColor3 = K.C.dim, TextYAlignment = Enum.TextYAlignment.Top })
	end
	if mode == "stash" then
		local gb = K.frame(det, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 112) })
		K.list(gb, nil, 6)
		K.button(gb, "FILL ALL MAGAZINES", { Size = UDim2.new(1, 0, 0, 32), TextSize = 13 }, function()
			req({ op = "fill" })
		end)
		local hasRifle = false
		for _, it in d.items do
			if it.id == "R17_RIFLE" then
				hasRifle = true
			end
		end
		if not hasRifle then
			K.button(gb, "CLAIM RECOVERY KIT", { Size = UDim2.new(1, 0, 0, 32), TextSize = 13, TextColor3 = K.C.ochre }, function()
				req({ op = "recovery" })
			end)
		end
	end
	-- gamepad focus: keep the selected tile, else first cell / loot row
	if ctx.Input.device() == "Gamepad" then
		local target = (selected and tiles[selected.g]) or firstFocus
		K.focus(target)
	end
end

function Inventory.show(m)
	if ctx.State.inRaid() then
		m = "raid"
	end
	mode = m or "raid"
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
	elseif not (ctx.Screens and ctx.Screens.modal) then
		Inventory.show(ctx.State.inRaid() and "raid" or "stash")
	end
end

function Inventory.init(c)
	ctx = c
	K = c.UiKit
	gui = K.screen("EFB_Inventory", 20)
	gui.Enabled = false
	c.Input.on("Inventory", function(down)
		if down then
			Inventory.toggle()
		end
	end)
	c.Input.on("Back", function(down)
		if down and Inventory.open then
			Inventory.close()
		end
	end)
	c.State.changed:Connect(function()
		if Inventory.open then
			Inventory.render()
		end
	end)
	c.State.on("loot", function(d)
		loot = d
		if Inventory.open then
			Inventory.render()
		else
			Inventory.show("raid")
		end
	end)
	c.State.on("summary", function()
		loot = nil
		Inventory.close()
	end)
end

return Inventory
