--!nonstrict
-- Hideout terminals (M9): the relay radio (traders: buy, barter, tasks, loyalty; operator profile) and the
-- workbench (hideout modules and crafts). Prices and rules come from the shared data modules so the screens
-- show exactly what the server will charge; the server re-checks everything.
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local WP = require(game:GetService("ReplicatedStorage"):WaitForChild("ZR"):WaitForChild("WeaponParts"))
local Util = require(Shared.Util)
local TD = require(Shared.TraderData)
local QD = require(Shared.QuestData)
local HD = require(Shared.HideoutData)
local HS = require(Shared.HideoutStyle)
local P = require(Shared.Progress)

local Trade = { open = nil }
local ctx, K
local ui = { tab = "vos", scroll = {}, cpanel = "GOODS" }
-- the relay radio's tabs, left to right (LB / RB step through them on a gamepad; audit ui.5): EFT's eight traders in EFT's
-- order (TraderData.list, decision economy-2a), then the flea market, messenger and handbook
local RADIO_TABS = table.clone(TD.list)
for _, id in { "flea", "messenger", "handbook" } do
	table.insert(RADIO_TABS, id)
end
Trade.RADIO_TABS = RADIO_TABS -- read by TraderTests
-- ui-3a: on a phone (under about 500 pt of height) the trade tab shows one panel at a time: GOODS, STASH or DEAL
local compact = false
local live = {} -- { label, at (server os.time), fmt }
local dirty = false

-- the Charisma discount on repairs (audit economy.6; trader prices ignore it; the server charges the same)
local function charisma()
	local d = ctx.State.data
	return P.bonus(d and d.econ and d.econ.skills, "charisma")
end

local function data()
	return ctx.State.data
end

-- server os.time() now, from the last snapshot
local function serverNow()
	local d = data()
	local base = d and d.serverTime or os.time()
	return base + (os.clock() - (ctx.State.dataClock or os.clock()))
end

local function stashCount(d, id)
	local n = 0
	for g in (d.grids and d.grids.stash) or {} do
		local it = d.items[g]
		if it and it.id == id and not (d.grids[g] and next(d.grids[g])) then
			n += it.n or 1
		end
	end
	return n
end

local function req(action, payload)
	local res = ctx.State.req(action, payload)
	if res and not res.ok and not res.msg then
		ctx.State.toast(string.gsub(res.code or "FAILED", "_", " "), "warn")
	end
	return res
end

-- ── small layout helpers ─────────────────────────────────────────────────────
local function scroller(parent, x, y, w, h, key)
	local sf = K.new("ScrollingFrame", {
		Name = key, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Selectable = false,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
	K.list(sf, nil, 4)
	K.new("UIPadding", { PaddingRight = UDim.new(0, 8) }, sf)
	task.defer(function()
		sf.CanvasPosition = ui.scroll[key] or Vector2.zero
	end)
	sf:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		ui.scroll[key] = sf.CanvasPosition
	end)
	return sf
end

local order = 0
local function nextOrder()
	order += 1
	return order
end

local function text(parent, s, color, size, bold)
	return K.label(parent, s, size or 12, {
		LayoutOrder = nextOrder(), TextColor3 = color or K.C.text, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, (size or 12) + 4), FontFace = bold and K.bold or K.font,
	})
end

local function section(parent, s)
	local l = text(parent, s, K.C.ochre, 13, true)
	l.Size = UDim2.new(1, 0, 0, 22)
	return l
end

-- one row: label on the left, info in the middle, a button on the right
local function row(parent, label, info, btnText, enabled, onClick, infoColor, itemId)
	-- rows without a label (requirement lines) give the info the full width and let it wrap onto a second line
	local wide = label == ""
	local pic = itemId and K.hasIcon(itemId)
	local r = K.frame(parent, { BackgroundColor3 = K.C.panel, BackgroundTransparency = 0.2, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, wide and 36 or (pic and 40 or 30)) })
	if pic then
		local d = Items.defs[string.match(itemId, "^([^#]+)") or itemId]
		local ph = 36
		local pw = math.floor(math.min(72, ph * d.w / d.h))
		local box = K.frame(r, { Name = "Picture", Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(pw, ph), BackgroundColor3 = K.C.panel2 })
		K.itemIcon(box, itemId, pw, ph, false, false, 3)
		K.label(r, label, 12, { Position = UDim2.fromOffset(pw + 8, 0), Size = UDim2.new(0.5, -pw - 8, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
	elseif not wide then
		K.label(r, "  " .. label, 12, { Size = UDim2.new(0.5, 0, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
	end
	K.label(r, info or "", 11, {
		Position = wide and UDim2.fromOffset(8, 0) or UDim2.fromScale(0.5, 0), Size = wide and UDim2.new(1, -104, 1, 0) or UDim2.new(0.5, -96, 1, 0),
		TextColor3 = infoColor or K.C.dim, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	if btnText then
		local b = K.button(r, btnText, {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -3, 0.5, 0), Size = UDim2.fromOffset(86, 24), TextSize = 11,
			TextColor3 = enabled and K.C.green or K.C.dim, AutoButtonColor = enabled,
		})
		if enabled then
			b.Activated:Connect(onClick)
		end
		return r, b
	end
	return r
end

local function have(n, need)
	return string.format('<font color="#%s">%d/%d</font>', (n >= need) and "93A57C" or "C24A35", math.min(n, 99), need)
end

-- ── traders ──────────────────────────────────────────────────────────────────
local function loyaltyText(econ, tid)
	local st = econ.traders and econ.traders[tid] or { ll = 1, spent = 0, rep = 0 }
	if tid == "fence" then
		-- Fence's loyalty is karma alone (EFT: LL2 at standing 6.0, no level or money; audit economy.5)
		return (st.ll or 1) >= 2 and string.format("LOYALTY 2 (MAX)  ·  KARMA %.2f", econ.karma or 0)
			or string.format("LOYALTY 1  ·  NEXT: KARMA %.1f (%.2f)", TD.FENCE_LL2 or 6, econ.karma or 0)
	end
	-- each trader's own table (EFT 1.1.0: player level and standing; no money asked, so none shown)
	local ll = st.ll or 1
	local nextL = TD.loyaltyReq(tid, ll + 1)
	if not nextL then
		return string.format("LOYALTY %d (MAX)  ·  STANDING %.2f", ll, st.rep or 0)
	end
	local need = { string.format("LEVEL %d (%d)", nextL.level, econ.level or 1) }
	if (nextL.spent or 0) > 0 then
		table.insert(need, string.format("%s MK TRADED (%s)", Util.commas(nextL.spent), Util.commas(math.floor(st.spent or 0))))
	end
	table.insert(need, string.format("STANDING %.2f (%.2f)", nextL.rep, st.rep or 0))
	return string.format("LOYALTY %d  ·  NEXT: %s", ll, table.concat(need, " · "))
end

-- ── Tarkov's TRADE screen: the trader's goods as a grid with prices, your stash beside it, the deal below ──
local CAT = {
	weapon = "WEAPONS", pistol = "WEAPONS", melee = "WEAPONS", mod = "PARTS", mag = "MAGAZINES", ammo = "AMMO", grenade = "GRENADES",
	armor = "GEAR", helmet = "GEAR", rig = "GEAR", backpack = "GEAR", headwear = "GEAR", headset = "GEAR", facecover = "GEAR", eyewear = "GEAR", secure = "GEAR", nvg = "GEAR",
	med = "MEDICAL", food = "PROVISIONS",
}
local CAT_ORDER = { "ALL", "WEAPONS", "PARTS", "MAGAZINES", "AMMO", "GRENADES", "GEAR", "MEDICAL", "PROVISIONS", "OTHER" }
local COLS = 10
ui.mode, ui.cat, ui.sub, ui.qty, ui.basket = "buy", "ALL", "trade", 1, {}

local function catOf(id)
	local def = Items.defs[id]
	return (def and CAT[def.kind]) or "OTHER"
end

local function knownId(d, id)
	return (d.known and d.known[id]) or Items.knownByDefault(id)
end

local function sizeOf(it)
	if it.sz then
		return it.sz[1], it.sz[2]
	end
	local def = Items.defs[it.id]
	return def.w, def.h
end

-- an offer's item table (a gun offer is its preset build) and its size in cells
local function offerItems(o)
	local items, g = K.iconItems(o.id, o.preset)
	local it = items[g]
	local sw, sh = Items.defs[o.id].w, Items.defs[o.id].h
	if it and it.sz then
		sw, sh = it.sz[1], it.sz[2]
	end
	return items, g, sw, sh
end

-- first-fit packing of w x h tiles into COLS columns: positions { x, y, w, h } and the rows used
local function pack(sizes)
	local occ, out, rows = {}, {}, 0
	local function free(x, y, w, h)
		for yy = y, y + h - 1 do
			for xx = x, x + w - 1 do
				if occ[yy * 100 + xx] then
					return false
				end
			end
		end
		return true
	end
	for i, sz in sizes do
		local w, h = math.min(sz[1], COLS), sz[2]
		local y = 1
		while not out[i] do
			for x = 1, COLS - w + 1 do
				if free(x, y, w, h) then
					for yy = y, y + h - 1 do
						for xx = x, x + w - 1 do
							occ[yy * 100 + xx] = true
						end
					end
					out[i] = { x, y, w, h }
					rows = math.max(rows, y + h - 1)
					break
				end
			end
			y += 1
		end
	end
	return out, rows
end

-- what the trader pays for a stash item with its parts and magazine (Economy.quote); nil if not buying
local function subItems(items, g, out)
	local it = items[g]
	for _, cg in (it and it.mods) or {} do
		table.insert(out, cg)
		subItems(items, cg, out)
	end
	if it and it.mag then
		table.insert(out, it.mag)
		subItems(items, it.mag, out)
	end
	return out
end

local function quote(d, g, tid)
	local it = d.items[g]
	if not it or not knownId(d, it.id) or (d.grids[g] and next(d.grids[g])) then
		return nil
	end
	local karma = d.econ and d.econ.karma
	local price = TD.sellPrice(tid, it, karma)
	if not price then
		return nil
	end
	for _, sg in subItems(d.items, g, {}) do
		local sub = d.items[sg]
		price += (sub and (TD.sellPrice(tid, sub, karma) or TD.sellPrice("fence", sub, karma))) or 0
	end
	return price
end

local function gridScroller(parent, x, y, w, h, key, canvasH)
	local sf = K.new("ScrollingFrame", {
		Name = key, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		CanvasSize = UDim2.fromOffset(0, canvasH), ScrollBarThickness = 4, Selectable = false, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
	task.defer(function()
		sf.CanvasPosition = ui.scroll[key] or Vector2.zero
	end)
	sf:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		ui.scroll[key] = sf.CanvasPosition
	end)
	return sf
end

-- the empty grid: one panel with cell lines
local function drawCells(parent, cols, rows, cell)
	local bg = K.frame(parent, { Name = "Cells", BackgroundColor3 = K.C.panel, Size = UDim2.fromOffset(cols * cell, rows * cell) })
	K.stroke(bg, K.C.line, 0.6)
	for i = 1, cols - 1 do
		K.frame(bg, { BackgroundColor3 = K.C.line, BackgroundTransparency = 0.7, Position = UDim2.fromOffset(i * cell, 0), Size = UDim2.new(0, 1, 1, 0) })
	end
	for j = 1, rows - 1 do
		K.frame(bg, { BackgroundColor3 = K.C.line, BackgroundTransparency = 0.7, Position = UDim2.fromOffset(0, j * cell), Size = UDim2.new(1, 0, 0, 1) })
	end
end

-- one item tile: picture, short name top right, opts.topLeft, opts.corner bottom right, opts.price along the bottom,
-- opts.overlay darkens it (locked, sold out, not wanted)
local function itemTile(parent, items, g, px, py, pw, ph, opts)
	local it = items[g]
	local def = Items.defs[it.id]
	local b = K.new("TextButton", {
		Name = opts.name or ("Tile_" .. it.id), Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 2,
		BackgroundColor3 = K.C.panel2, BackgroundTransparency = 0.1, Position = UDim2.fromOffset(px, py), Size = UDim2.fromOffset(pw, ph),
		Selectable = true, SelectionImageObject = K.selection(),
	}, parent)
	K.stroke(b, opts.stroke or K.C.line, opts.stroke and 0 or 0.6, opts.stroke and 2 or 1)
	local pic = K.frame(b, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	if not opts.unknown and K.isBuild(items, g) then
		K.gunPicture(pic, items, g, pw, ph, opts.r == 1, 2)
	else
		K.itemIcon(pic, it.id, pw, ph, opts.r == 1, opts.unknown, 2)
	end
	K.label(b, opts.unknown and "?" or (def.short or def.name), 10, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 1), Size = UDim2.new(1, -6, 0, 12), TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
	})
	if opts.topLeft then
		K.label(b, opts.topLeft, 10, { Position = UDim2.fromOffset(3, 13), Size = UDim2.fromOffset(40, 12), TextColor3 = K.C.dim, ZIndex = 3 })
	end
	if opts.corner and opts.corner ~= "" then
		K.label(b, opts.corner, 10, {
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, opts.price and -15 or -1), Size = UDim2.new(1, -6, 0, 12),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3,
		})
	end
	if opts.price then
		local strip = K.frame(b, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.2, ZIndex = 3 })
		K.label(strip, opts.price, 10, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = opts.priceColor or K.C.ochre, FontFace = K.bold, ZIndex = 4 })
	end
	if opts.overlay then
		local ov = K.frame(b, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, ZIndex = 5 })
		K.label(ov, opts.overlay, 11, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = opts.overlayColor or K.C.orange, FontFace = K.bold, ZIndex = 6 })
	end
	return b
end

local function inspect(items, g, key, unknown)
	if ctx.Inspect then
		ctx.Inspect.open(items, g, { key = key, unknown = unknown })
	end
end

-- right-click, or Tarkov's middle mouse button, opens a tile's inspect window (audit ui.9); `middle` may do otherwise
-- (examine an unknown stash item)
local function onInspect(t, fn, middle)
	t.MouseButton2Click:Connect(fn)
	t.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			local f = middle or fn
			f()
		end
	end)
end

local function tradeTab(f, x, y, w, h, d, tid)
	local econ = d.econ or {}
	local st = econ.traders and econ.traders[tid] or { ll = 1 }
	local stash = (d.grids and d.grids.stash) or {}
	for i = #ui.basket, 1, -1 do
		if not (stash[ui.basket[i]] and quote(d, ui.basket[i], tid)) then
			table.remove(ui.basket, i)
		end
	end
	local cp = ui.cpanel or "GOODS"
	local showGoods = not compact or cp == "GOODS"
	local showStash = not compact or cp == "STASH"
	local showDeal = not compact or cp == "DEAL"
	local leftW = compact and w or math.floor((w - 12) * 0.5)
	local rightW = compact and w or w - leftW - 12
	local dealH = compact and h or (h < 420 and 64 or 92)
	local gridH = compact and h or h - dealH - 8
	if showGoods then
	-- BUY / SELL, then the categories this trader stocks
	local modes = K.frame(f, { BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(leftW, compact and 36 or 26) })
	K.list(modes, Enum.FillDirection.Horizontal, 4)
	for _, m in { "buy", "sell" } do
		local on = ui.mode == m
		local b = K.button(modes, string.upper(m) .. (m == "sell" and #ui.basket > 0 and (" (" .. #ui.basket .. ")") or ""), {
			Size = UDim2.fromOffset(compact and 100 or 84, compact and 36 or 26), TextSize = compact and 13 or 12, BackgroundColor3 = on and Color3.fromHex("3A3524") or K.C.panel2, TextColor3 = on and K.C.ochre or K.C.dim,
		})
		b.Name = "Mode_" .. string.upper(m)
		b.Activated:Connect(function()
			if ui.mode ~= m then
				ui.mode = m
				Trade.refresh()
			end
		end)
	end
	local gy = y + (compact and 40 or 30)
	local cellW = math.floor((leftW - 6) / COLS)
	if compact then
		cellW = math.clamp(cellW, 36, 48)
	end
	if ui.mode == "buy" then
		local has = { ALL = true }
		for _, o in TD.offers[tid] or {} do
			has[catOf(o.id)] = true
		end
		for _, bt in TD.barters[tid] or {} do
			has[catOf(bt.id)] = true
		end
		if not has[ui.cat] then
			ui.cat = "ALL"
		end
		local catH = compact and 34 or 22
		local cats = K.new("ScrollingFrame", {
			BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(x, gy), Size = UDim2.fromOffset(leftW, catH),
			ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollBarThickness = 0, Selectable = false,
		}, f)
		K.list(cats, Enum.FillDirection.Horizontal, 3)
		for _, c in CAT_ORDER do
			if has[c] then
				local on = ui.cat == c
				local b = K.button(cats, c, { Size = UDim2.fromOffset(compact and (#c * 9 + 20) or (#c * 7 + 14), catH), TextSize = compact and 13 or 10, BackgroundColor3 = on and Color3.fromHex("3A3524") or K.C.panel2, TextColor3 = on and K.C.ochre or K.C.dim })
				b.Name = "Cat_" .. c
				b.Activated:Connect(function()
					ui.cat = c
					Trade.refresh()
				end)
			end
		end
		gy += catH + 4
		-- the assortment: offers and barters packed like a stash, price under each
		local entries = {}
		for i, o in TD.offers[tid] or {} do
			if ui.cat == "ALL" or catOf(o.id) == ui.cat then
				table.insert(entries, { kind = "offer", i = i, o = o })
			end
		end
		for i, bt in TD.barters[tid] or {} do
			if ui.cat == "ALL" or catOf(bt.id) == ui.cat then
				table.insert(entries, { kind = "barter", i = i, o = bt })
			end
		end
		local sizes = {}
		for k, e in entries do
			local items, g, sw, sh = offerItems(e.o)
			e.items, e.g = items, g
			sizes[k] = { sw, sh }
		end
		local pos, rows = pack(sizes)
		local viewH = y + gridH - gy
		local sf = gridScroller(f, x, gy, leftW, viewH, "Shop_" .. tid, math.max(rows * cellW, viewH))
		drawCells(sf, COLS, math.max(rows, math.floor(viewH / cellW)), cellW)
		for k, e in entries do
			local p, o = pos[k], e.o
			-- a task-locked offer (economy-6a) shows greyed with TASK, as EFT shows the task that opens it
			local locked, lockWhy = o.ll > st.ll, nil
			if TD.offerLock then
				locked, lockWhy = TD.offerLock(o, st.ll, d.quests)
			end
			local used = (econ.bought and econ.bought[(e.kind == "barter" and "b:" or "") .. tid .. ":" .. e.i]) or 0
			local left = o.limit - used
			-- karma moves Fence's prices (the server charges the same; other traders ignore it, audit economy.5)
			local price = e.kind == "offer" and TD.price(tid, o, st.ll, econ.karma) or nil
			local on = ui.sel and ui.sel.kind == e.kind and ui.sel.i == e.i
			local t = itemTile(sf, e.items, e.g, (p[1] - 1) * cellW + 1, (p[2] - 1) * cellW + 1, p[3] * cellW - 2, p[4] * cellW - 2, {
				name = (e.kind == "offer" and "Offer_" or "Barter_") .. o.id,
				topLeft = (not locked and left > 0) and ("x" .. left) or nil,
				corner = (o.n or 1) > 1 and tostring(o.n) or nil,
				price = price and Util.commas(price) or "BARTER",
				priceColor = price and (((d.money or 0) >= price) and K.C.ochre or K.C.red) or K.C.green,
				overlay = locked and (o.ll > st.ll and ("LL" .. o.ll) or "TASK") or (left <= 0 and "SOLD OUT" or nil),
				stroke = on and K.C.ochre or nil,
			})
			t.Activated:Connect(function()
				ui.sel, ui.qty = { kind = e.kind, i = e.i }, 1
				if compact then
					ui.cpanel = "DEAL" -- a phone shows the deal on its own panel
				end
				Trade.refresh()
			end)
			onInspect(t, function()
				inspect(e.items, e.g, "offer:" .. tid .. ":" .. e.kind .. e.i)
			end)
		end
	else
		-- SELL: the items picked from the stash, with what this trader pays for each
		local sizes = {}
		for k, g in ui.basket do
			sizes[k] = { sizeOf(d.items[g]) }
		end
		local pos, rows = pack(sizes)
		local viewH = y + gridH - gy
		local sf = gridScroller(f, x, gy, leftW, viewH, "Sell_" .. tid, math.max(rows * cellW, viewH))
		drawCells(sf, COLS, math.max(rows, math.floor(viewH / cellW)), cellW)
		if #ui.basket == 0 then
			K.label(sf, "Click items in your stash to sell them to " .. TD.defs[tid].name .. ".\nClick them again to take them back.", 12, {
				Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = K.C.dim, TextWrapped = true, ZIndex = 3,
			})
		end
		for k, g in ui.basket do
			local p = pos[k]
			local t = itemTile(sf, d.items, g, (p[1] - 1) * cellW + 1, (p[2] - 1) * cellW + 1, p[3] * cellW - 2, p[4] * cellW - 2, {
				name = "Selling_" .. d.items[g].id, price = "+" .. Util.commas(quote(d, g, tid) or 0), priceColor = K.C.green,
				corner = ctx.Inventory.cornerText and ctx.Inventory.cornerText(d, d.items[g]) or nil,
			})
			t.Activated:Connect(function()
				local i = table.find(ui.basket, g)
				if i then
					table.remove(ui.basket, i)
				end
				Trade.refresh()
			end)
			onInspect(t, function()
				inspect(d.items, g, "stash:" .. g)
			end)
		end
	end
	end -- showGoods
	if showStash then
	-- your stash: click to put an item in the sell deal; what this trader will not buy is dimmed
	local rx = compact and x or x + leftW + 12
	local stashH = d.stashH or Config.STASH_H
	local scell = math.floor((rightW - 6) / Config.STASH_W)
	if compact then
		scell = math.clamp(scell, 36, 48)
	end
	K.label(f, string.format("STASH  %dx%d  ·  %s %s%s", Config.STASH_W, stashH, Util.commas(d.money or 0), Config.CURRENCY, compact and "  ·  TAP ITEMS TO SELL" or ""), compact and 13 or 11, {
		Position = UDim2.fromOffset(rx, y + 6), Size = UDim2.fromOffset(rightW, 16), TextColor3 = K.C.dim,
	})
	local ss = gridScroller(f, rx, y + 30, rightW, gridH - 30, "Stash_trade", stashH * scell)
	drawCells(ss, Config.STASH_W, stashH, scell)
	local inDeal = {}
	for _, g in ui.basket do
		inDeal[g] = true
	end
	for g, p in stash do
		local it = d.items[g]
		if it then
			local iw, ih = sizeOf(it)
			if p.r == 1 then
				iw, ih = ih, iw
			end
			local kn = knownId(d, it.id)
			local price = quote(d, g, tid)
			local t = itemTile(ss, d.items, g, (p.x - 1) * scell + 1, (p.y - 1) * scell + 1, iw * scell - 2, ih * scell - 2, {
				name = "Stash_" .. it.id, r = p.r, unknown = not kn, stroke = inDeal[g] and K.C.green or nil,
				corner = kn and ctx.Inventory.cornerText and ctx.Inventory.cornerText(d, it) or nil,
				overlay = (not price) and "" or nil,
			})
			t.Activated:Connect(function()
				if not price then
					ctx.State.toast(not kn and "EXAMINE IT FIRST" or (d.grids[g] and next(d.grids[g])) and "EMPTY IT FIRST" or (TD.defs[tid].name .. " DOESN'T BUY THAT"), "warn")
					return
				end
				local i = table.find(ui.basket, g)
				if i then
					table.remove(ui.basket, i)
				elseif #ui.basket < 40 then
					table.insert(ui.basket, g)
				end
				ui.mode = "sell"
				Trade.refresh()
			end)
			onInspect(t, function()
				inspect(d.items, g, "stash:" .. g, not kn)
			end, not kn and function()
				ctx.State.req("inv", { op = "examine", g = g, from = "me" }) -- Tarkov's middle mouse examines an unknown item
			end or nil)
		end
	end
	end -- showStash
	if not showDeal then
		return
	end
	-- the deal
	local deal = K.frame(f, { Name = "Deal", BackgroundColor3 = K.C.panel, Position = UDim2.fromOffset(x, y + h - dealH), Size = UDim2.fromOffset(w, dealH) })
	K.stroke(deal, K.C.line, 0.6)
	local function dealButton(textValue, enabled, onClick, xFromRight, width)
		local b = K.button(deal, textValue, {
			AnchorPoint = Vector2.new(1, compact and 1 or 0.5), Position = compact and UDim2.new(1, -xFromRight, 1, -10) or UDim2.new(1, -xFromRight, 0.5, 0),
			Size = UDim2.fromOffset(width or 120, compact and 44 or math.min(40, dealH - 16)), TextSize = 14,
			TextColor3 = enabled and K.C.green or K.C.dim, AutoButtonColor = enabled,
		})
		if enabled then
			b.Activated:Connect(onClick)
		end
		return b
	end
	if ui.mode == "sell" then
		local total, n = 0, 0
		for _, g in ui.basket do
			total += quote(d, g, tid) or 0
			n += 1
		end
		K.label(deal, n == 0 and "SELL" or string.format("SELL %d ITEM%s TO %s", n, n == 1 and "" or "S", TD.defs[tid].name), 15, { FontFace = K.bold, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(0.6, 0, 0, 20) })
		K.label(deal, string.format("YOU RECEIVE  +%s %s", Util.commas(total), Config.CURRENCY), 13, { Position = UDim2.fromOffset(10, 30), Size = UDim2.new(0.6, 0, 0, 18), TextColor3 = n > 0 and K.C.green or K.C.dim })
		local b = dealButton("DEAL!", n > 0, function()
			local gs = table.clone(ui.basket)
			local res = req("trade", { op = "sellmany", trader = tid, gs = gs })
			if res and res.ok then
				table.clear(ui.basket)
				Trade.refresh()
			end
		end, 10)
		b.Name = "Deal"
		if n > 0 then
			local c = dealButton("CLEAR", true, function()
				table.clear(ui.basket)
				Trade.refresh()
			end, 140, 90)
			c.Name = "Clear"
		end
		return
	end
	local e
	if ui.sel then
		local list = ui.sel.kind == "offer" and TD.offers[tid] or TD.barters[tid]
		local o = list and list[ui.sel.i]
		if o then
			e = { kind = ui.sel.kind, i = ui.sel.i, o = o }
		end
	end
	if not e then
		K.label(deal, "Select an item to buy it, or click items in your stash to sell them. Right-click or middle-click any item to inspect it.", 12, {
			Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), TextColor3 = K.C.dim, TextWrapped = true,
		})
		return
	end
	local o = e.o
	local items, g, sw, sh = offerItems(o)
	local ph = compact and math.min(dealH - 80, 160) or dealH - 12
	local pw = math.floor(math.min(150, ph * sw / sh))
	local box = K.frame(deal, { Name = "Picture", BackgroundColor3 = K.C.panel2, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(pw, ph) })
	if K.isBuild(items, g) then
		K.gunPicture(box, items, g, pw, ph, false, 2)
	else
		K.itemIcon(box, o.id, pw, ph, false, false, 2)
	end
	local tx = pw + 16
	local oname = (o.preset and WP.PRESET_NAMES[o.preset]) or Items.defs[o.id].name
	K.label(deal, string.upper(oname) .. ((o.n or 1) > 1 and ("  x" .. o.n) or ""), 14, { FontFace = K.bold, Position = UDim2.fromOffset(tx, 6), Size = UDim2.fromOffset(math.max(80, w - 380 - tx), 18), TextTruncate = Enum.TextTruncate.AtEnd })
	local locked, lockWhy = o.ll > st.ll, nil
	if TD.offerLock then
		locked, lockWhy = TD.offerLock(o, st.ll, d.quests)
	end
	local lockText = string.upper(lockWhy or ("Requires loyalty level " .. o.ll))
	local used = (econ.bought and econ.bought[(e.kind == "barter" and "b:" or "") .. tid .. ":" .. e.i]) or 0
	local left = math.max(0, o.limit - used)
	if e.kind == "offer" then
		local unit = TD.price(tid, o, st.ll, econ.karma)
		ui.qty = math.clamp(ui.qty, 1, math.max(1, math.min(10, left)))
		local total = unit * ui.qty
		local afford = (d.money or 0) >= total
		K.label(deal, locked and lockText or string.format("%s %s EACH  ·  %d LEFT UNTIL RESTOCK", Util.commas(unit), Config.CURRENCY, left), 12, {
			Position = UDim2.fromOffset(tx, 26), Size = UDim2.fromOffset(math.max(80, w - 380 - tx), 16), TextColor3 = locked and K.C.orange or K.C.dim,
		})
		K.label(deal, string.format("TOTAL  %s %s", Util.commas(total), Config.CURRENCY), 13, {
			Name = "Total", Position = UDim2.fromOffset(tx, 44), Size = UDim2.fromOffset(math.max(80, w - 380 - tx), 18), TextColor3 = afford and K.C.text or K.C.red, FontFace = K.bold,
		})
		-- quantity
		local qx = 270
		local minus = dealButton("-", ui.qty > 1, function()
			ui.qty -= 1
			Trade.refresh()
		end, qx + 70, 30)
		minus.Name = "QtyDown"
		local ql = K.label(deal, tostring(ui.qty), 14, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(qx + 34), 0.5, 0), Size = UDim2.fromOffset(36, 30), TextXAlignment = Enum.TextXAlignment.Center, FontFace = K.bold })
		ql.Name = "Qty"
		local plus = dealButton("+", ui.qty < math.min(10, left), function()
			ui.qty += 1
			Trade.refresh()
		end, qx, 30)
		plus.Name = "QtyUp"
		local b = dealButton("DEAL!", not locked and left > 0 and afford, function()
			req("trade", { op = "buy", trader = tid, i = e.i, qty = ui.qty })
		end, 10)
		b.Name = "Deal"
	else
		local parts, ok = {}, true
		for _, need in o.give do
			local n = stashCount(d, need[1])
			ok = ok and n >= need[2]
			table.insert(parts, Items.defs[need[1]].short .. " " .. have(n, need[2]))
		end
		K.label(deal, locked and lockText or ("BARTER FOR  " .. table.concat(parts, "   ")), 12, {
			Position = UDim2.fromOffset(tx, 26), Size = UDim2.new(1, -tx - 280, 0, 34), TextColor3 = locked and K.C.orange or K.C.text, RichText = true, TextWrapped = true,
		})
		local b = dealButton("DEAL!", ok and not locked and left > 0, function()
			req("trade", { op = "barter", trader = tid, i = e.i })
		end, 10)
		b.Name = "Deal"
	end
	local insp = dealButton("INSPECT", true, function()
		inspect(items, g, "offer:" .. tid .. ":" .. e.kind .. e.i)
	end, 140, 110)
	insp.Name = "Inspect"
end

-- an objective's line (the character tab's, so both screens say the same)
local function objText(o)
	if ctx.Character and ctx.Character.objectiveText then
		return ctx.Character.objectiveText(o)
	end
	local what = QD.describe(o)
	if o.kind == "handin" then
		what = what .. ": " .. Items.defs[o.item].name
	end
	return what
end

-- the reward line: money, XP, standing (and what it costs with another trader), karma, items and the offers it opens
local function rewardText(r, taskId)
	local rew = { Util.commas(r.money or 0) .. " " .. Config.CURRENCY, (r.xp or 0) .. " XP" }
	if r.rep then
		table.insert(rew, string.format("+%.2f standing", r.rep))
	end
	for otid, dv in r.reps or {} do
		table.insert(rew, string.format("%+.2f with %s", dv, TD.defs[otid] and TD.defs[otid].name or otid))
	end
	if r.karma then
		table.insert(rew, string.format("+%.2f karma", r.karma))
	end
	for _, e in r.items or {} do
		table.insert(rew, Items.defs[e[1]].name .. ((e[2] or 1) > 1 and (" x" .. e[2]) or ""))
	end
	-- EFT: "Unlocks purchase of X at Trader LLn" (TraderData's task-locked offers)
	for _, u in (taskId and TD.unlocksOf and TD.unlocksOf(taskId)) or {} do
		local od = Items.defs[u.offer.id]
		local oname = (u.offer.preset and WP.PRESET_NAMES[u.offer.preset]) or (od and od.name) or u.offer.id
		table.insert(rew, string.format("unlocks %s at %s LL%d", oname, TD.defs[u.trader].name, u.offer.ll))
	end
	return "  REWARD  " .. table.concat(rew, "  ·  ")
end

-- the operational tasks this trader gives (EFT's dailies and weeklies; Fence's scav task): timer, objectives, reward,
-- ACCEPT or TURN IN, and REPLACE for money and standing (economy-6a)
local function opsBlock(right, d, tid)
	local list = {}
	for _, inst in (d.quests and d.quests.ops) or {} do
		if inst.trader == tid and inst.s ~= "failed" then
			table.insert(list, inst)
		end
	end
	if #list == 0 then
		return
	end
	section(right, "OPERATIONAL TASKS")
	local now = d.serverTime or os.time()
	for _, inst in list do
		local statusText = ({ available = "AVAILABLE", active = "ACTIVE", claimed = "COMPLETED" })[inst.s] or string.upper(inst.s)
		local color = ({ available = K.C.ochre, active = K.C.green, claimed = K.C.dim })[inst.s] or K.C.text
		local left = ctx.Character and ctx.Character.timeLeft and ctx.Character.timeLeft(inst.ends, now) or ""
		text(right, string.format("%s   ·   %s   ·   %s LEFT", inst.name, statusText, left), color, 13, true)
		local complete = true
		for i, o in inst.obj do
			local p = (inst.p and inst.p[i]) or 0
			complete = complete and p >= o.n
			text(right, string.format("  •  %s   %s", objText(o), (inst.s == "available") and ("x" .. o.n) or have(p, o.n)), K.C.text, 11)
		end
		text(right, rewardText(inst.reward or {}, nil), K.C.green, 11)
		if inst.s == "available" then
			local _, b = row(right, "", "", "ACCEPT", true, function()
				req("quest", { op = "accept", id = inst.id })
			end)
			b.Name = "Accept_" .. inst.id
		elseif inst.s == "active" then
			local _, b = row(right, "", complete and "READY" or "IN PROGRESS", "TURN IN", complete, function()
				req("quest", { op = "turnin", id = inst.id })
			end, complete and K.C.green or K.C.dim)
			b.Name = "TurnIn_" .. inst.id
		end
		if inst.s == "available" or inst.s == "active" then
			local cost = inst.cost or 0
			local what = tid == "fence" and "karma" or "standing"
			local _, rb = row(right, "", string.format("REPLACE: %s %s, -%.2f %s", Util.commas(cost), Config.CURRENCY, inst.costRep or 0, what), "REPLACE",
				(d.money or 0) >= cost, function()
					req("quest", { op = "replace", id = inst.id })
				end, (d.money or 0) >= cost and K.C.dim or K.C.red)
			rb.Name = "Replace_" .. inst.id
		end
	end
	section(right, "TASKS")
end

local function tasksTab(f, x, y, w, h, d, tid)
	local econ = d.econ or {}
	local right = scroller(f, x, y, w, h, "Tasks_" .. tid)
	opsBlock(right, d, tid)
	local mine = {}
	for _, q in QD.list do
		if q.trader == tid then
			table.insert(mine, q)
		end
	end
	-- Tarkov 0.16.7: pinned tasks at the top of the list (audit ui.14)
	if ctx.Character and ctx.Character.pinnedFirst then
		mine = ctx.Character.pinnedFirst(mine, d)
	end
	for _, q in mine do
		local qs = (d.quests and d.quests[q.id]) or { s = "locked", p = {} }
		local statusText = ({ locked = "LOCKED", available = "AVAILABLE", active = "ACTIVE", claimed = "COMPLETED" })[qs.s] or qs.s
		local color = ({ locked = K.C.dim, available = K.C.ochre, active = K.C.green, claimed = K.C.dim })[qs.s] or K.C.text
		local title = string.upper(q.name) .. "   ·   " .. statusText
		if qs.s == "active" and ctx.Character then
			-- an active task takes a pin: it stays at the top here and in the character's TASKS tab
			local pinned = ctx.Character.isPinned(q.id)
			local r = K.frame(right, { Name = "Task_" .. q.id, BackgroundTransparency = 1, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, compact and 40 or 26) })
			K.label(r, title, 13, { FontFace = K.bold, TextColor3 = color, Size = UDim2.new(1, -(compact and 110 or 92), 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
			local pb = K.button(r, pinned and "PINNED" or "PIN", {
				Name = "Pin", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -3, 0.5, 0), Size = UDim2.fromOffset(compact and 104 or 86, compact and 36 or 24),
				TextSize = compact and 13 or 11, TextColor3 = pinned and K.C.ochre or K.C.dim,
			})
			pb.Activated:Connect(function()
				ctx.Character.setPin(q.id, not pinned)
				Trade.refresh()
			end)
		else
			text(right, title, color, 13, true)
		end
		if qs.s == "locked" then
			local why = {}
			if (econ.level or 1) < (q.level or 1) then
				table.insert(why, "level " .. q.level)
			end
			if q.after then
				table.insert(why, "after " .. QD.byId[q.after].name)
			end
			-- EFT 1.1.0: side tasks open in groups at the giver's loyalty levels (economy-6a; the server checks it too)
			local st = econ.traders and econ.traders[tid]
			if (q.tl or 1) > ((st and st.ll) or 1) then
				table.insert(why, "loyalty level " .. q.tl .. " with " .. (TD.defs[tid] and TD.defs[tid].name or tid))
			end
			-- EFT 1.1.0's collector rules (audit economy.7, the server checks them in Quests.status): more finished tasks,
			-- a Fence standing, a loyalty level with every trader
			for _, id in q.needs or {} do
				local nq = d.quests and d.quests[id]
				if not (nq and nq.s == "claimed") then
					table.insert(why, "after " .. (QD.byId[id] and QD.byId[id].name or id))
				end
			end
			if q.karma and (econ.karma or 0) < q.karma then
				table.insert(why, string.format("karma %.1f", q.karma))
			end
			if q.ll then
				table.insert(why, "loyalty " .. q.ll .. " with every trader")
			end
			text(right, #why > 0 and ("Requires " .. table.concat(why, ", ") .. ".") or "Not offered yet.", K.C.dim, 11)
		else
			text(right, q.desc, K.C.dim, 11)
			local complete = true
			for i, o in q.obj do
				local p = (qs.p and qs.p[i]) or 0
				if qs.s == "claimed" then
					p = o.n
				end
				complete = complete and p >= o.n
				text(right, string.format("  •  %s   %s", objText(o), (qs.s == "available") and ("x" .. o.n) or have(p, o.n)), K.C.text, 11)
			end
			text(right, rewardText(q.reward or {}, q.id), K.C.green, 11)
			if qs.s == "available" then
				local _, b = row(right, "", "", "ACCEPT", true, function()
					req("quest", { op = "accept", id = q.id })
				end)
				b.Name = "Accept_" .. q.id
			elseif qs.s == "active" then
				local _, b = row(right, "", complete and "READY" or "IN PROGRESS", "TURN IN", complete, function()
					req("quest", { op = "turnin", id = q.id })
				end, complete and K.C.green or K.C.dim)
				b.Name = "TurnIn_" .. q.id
			end
		end
	end
	if #mine == 0 then
		text(right, "No tasks.", K.C.dim)
	end
end


-- SERVICES: repairs (EFT's repairers: VOS and KOVAC weapons, ROOK weapons and armour); each repair costs some maximum
-- durability (Tarkov), and the price follows the trader's loyalty level (the server charges the same)
local function servicesTab(f, x, y, w, h, d, tid)
	local sf = scroller(f, x, y, w, h, "Services_" .. tid)
	local kinds = TD.REPAIRS[tid].kinds
	local st = d.econ and d.econ.traders and d.econ.traders[tid]
	local ll = (st and st.ll) or 1
	section(sf, "REPAIRS")
	local what = (kinds.weapon and kinds.armor) and " repairs weapons, body armour, armoured rigs, helmets and ballistic glasses."
		or (kinds.weapon and " repairs weapons." or " repairs body armour, armoured rigs, helmets and ballistic glasses.")
	text(sf, TD.defs[tid].name .. what .. " Every repair lowers the item's maximum durability a little; a repair kit wears it less.", K.C.dim, 11)
	local any = false
	for g, it in d.items or {} do
		local pts, cost, newMax = TD.repairQuote(tid, it, charisma(), ll)
		if pts then
			any = true
			local def = Items.defs[it.id]
			local cur, max = TD.condition(it)
			local info = string.format("%.1f / %.1f  ·  REPAIR TO %.1f  ·  %s %s", cur, max, newMax, Util.commas(cost), Config.CURRENCY)
			local _, b = row(sf, def.name, info, "REPAIR", (d.money or 0) >= cost, function()
				req("trade", { op = "repair", trader = tid, g = g })
			end, (d.money or 0) < cost and K.C.red or nil, it.id)
			if b then
				b.Name = "Repair_" .. it.id
			end
		end
	end
	if not any then
		text(sf, "Nothing of yours needs " .. TD.defs[tid].name .. "'s repairs.", K.C.dim, 12)
	end
end

local function traderPanel(f, x, y, w, h, d, tid)
	local econ = d.econ or {}
	local tr = TD.defs[tid]
	if compact then
		-- the phone layout: a rail of the trade panels and the trader's other tabs, one panel beside it
		local list = { { "GOODS", "trade" }, { "STASH", "trade" }, { "DEAL", "trade" }, { "TASKS", "tasks" } }
		if TD.REPAIRS[tid] then
			table.insert(list, { "SERVICES", "services" })
		end
		if not (ui.sub == "trade" or ui.sub == "tasks" or (ui.sub == "services" and TD.REPAIRS[tid])) then
			ui.sub = "trade"
		end
		local railW = 96
		local rail = K.frame(f, { Name = "Rail", BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(railW, h) })
		K.list(rail, nil, 6)
		for i, e in list do
			local on = ui.sub == e[2] and (e[2] ~= "trade" or ui.cpanel == e[1])
			local label = e[1]
			if e[1] == "DEAL" and #ui.basket > 0 then
				label = "DEAL (" .. #ui.basket .. ")"
			end
			local b = K.button(rail, label, { Name = "Rail_" .. e[1], LayoutOrder = i, Size = UDim2.new(1, 0, 0, 44), TextSize = 13, BackgroundColor3 = on and Color3.fromHex("3A3524") or K.C.panel2, TextColor3 = on and K.C.ochre or K.C.text })
			b.Activated:Connect(function()
				ui.sub = e[2]
				if e[2] == "trade" then
					ui.cpanel = e[1]
				end
				Trade.refresh()
			end)
		end
		local cx, cw = x + railW + 8, w - railW - 8
		K.label(f, loyaltyText(econ, tid), 12, { Position = UDim2.fromOffset(cx, y), Size = UDim2.fromOffset(cw, 16), TextTruncate = Enum.TextTruncate.AtEnd })
		local cy, ch = y + 20, h - 20
		if ui.sub == "tasks" then
			tasksTab(f, cx, cy, cw, ch, d, tid)
		elseif ui.sub == "services" then
			servicesTab(f, cx, cy, cw, ch, d, tid)
		else
			tradeTab(f, cx, cy, cw, ch, d, tid)
		end
		return
	end
	K.label(f, tr.title .. ".  " .. tr.desc, 12, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w - 310, 16), TextColor3 = K.C.dim, TextTruncate = Enum.TextTruncate.AtEnd })
	K.label(f, loyaltyText(econ, tid), 11, { Position = UDim2.fromOffset(x, y + 17), Size = UDim2.fromOffset(w - 310, 15), TextTruncate = Enum.TextTruncate.AtEnd })
	-- Tarkov's trader tabs: TRADE and TASKS
	local list = { "trade", "tasks" }
	if TD.REPAIRS[tid] then
		table.insert(list, "services")
	end
	if not table.find(list, ui.sub) then
		ui.sub = "trade"
	end
	local subs = K.frame(f, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(x + w, y), Size = UDim2.fromOffset(#list * 101, 30) })
	K.list(subs, Enum.FillDirection.Horizontal, 6)
	for _, s in list do
		local on = ui.sub == s
		local b = K.button(subs, string.upper(s), { Size = UDim2.fromOffset(95, 30), TextSize = 13, BackgroundColor3 = on and Color3.fromHex("3A3524") or K.C.panel2, TextColor3 = on and K.C.ochre or K.C.dim })
		b.Name = "Sub_" .. string.upper(s)
		b.Activated:Connect(function()
			if ui.sub ~= s then
				ui.sub = s
				Trade.refresh()
			end
		end)
	end
	if ui.sub == "tasks" then
		tasksTab(f, x, y + 38, w, h - 38, d, tid)
	elseif ui.sub == "services" then
		servicesTab(f, x, y + 38, w, h - 38, d, tid)
	else
		tradeTab(f, x, y + 38, w, h - 38, d, tid)
	end
end

local function profilePanel(f, x, y, w, h, d)
	local econ = d.econ or {}
	local sf = scroller(f, x, y, w, h, "Profile")
	local lvl = econ.level or 1
	local xp = econ.xp or 0
	local a, b = P.xpFor(lvl), P.xpFor(lvl + 1)
	section(sf, string.format("OPERATOR  ·  LEVEL %d", lvl))
	local bar = K.frame(sf, { LayoutOrder = nextOrder(), BackgroundColor3 = K.C.panel2, Size = UDim2.new(1, 0, 0, 10) })
	K.frame(bar, { BackgroundColor3 = K.C.ochre, Size = UDim2.fromScale(math.clamp((xp - a) / math.max(1, b - a), 0, 1), 1) })
	text(sf, string.format("%s / %s XP to level %d", Util.commas(xp), Util.commas(b), lvl + 1), K.C.dim, 11)
	section(sf, "SKILLS")
	for _, id in P.SKILL_ORDER do
		local def = P.SKILLS[id]
		local pts = (econ.skills and econ.skills[id]) or 0
		local sl = P.skillLevel(pts)
		local _, into, cost = P.skillProgress(pts)
		text(sf, string.format("%s  ·  LEVEL %d%s  ·  %s", def.name, sl, sl >= P.SKILL_MAX and " (ELITE)" or string.format(" (%d/%d)", math.floor(into), cost), def.desc), K.C.text, 12)
	end
	section(sf, "FENCE KARMA")
	local karma = econ.karma or 0
	text(sf, string.format("%.2f  ·  %s", karma, karma < P.KARMA.hostileBelow and "the locals shoot player scavs on sight" or "the locals tolerate your scav"), karma < 0 and K.C.orange or K.C.text, 12)
	text(sf, "Killing locals as a scav lowers karma; extracting as a scav raises it. Higher karma shortens the scav cooldown and improves the Fence's prices.", K.C.dim, 11)
	section(sf, "RECORD")
	local s = d.stats or {}
	text(sf, string.format("RAIDS %d  ·  SURVIVED %d  ·  KIA %d  ·  MIA %d  ·  KILLS %d (PMC %d, SCAV %d, BOSS %d)  ·  SCAV RAIDS %d",
		s.raids or 0, s.survived or 0, s.kia or 0, s.mia or 0, s.kills or 0, s.pmcKills or 0, s.scavKills or 0, s.bossKills or 0, s.scavRaids or 0), K.C.text, 12)
end

-- the trader radio's open tab (a trader's id, "flea", "handbook", "messenger" or "profile"), and the last trader shown
function Trade.tab()
	return ui.tab
end
function Trade.lastTrader()
	return TD.defs[ui.tab] and ui.tab or TD.list[1]
end

function Trade.traders(tab, sub)
	local d = data()
	if not d or ctx.State.inRaid() then
		return
	end
	if tab and tab ~= ui.tab then
		ui.sel, ui.cat, ui.mode = nil, "ALL", "buy"
		table.clear(ui.basket)
	end
	ui.tab = tab or ui.tab
	-- a counter or an old bridge call may name a trader this build does not have: open the first trader instead
	if not (TD.defs[ui.tab] or ui.tab == "flea" or ui.tab == "messenger" or ui.tab == "handbook" or ui.tab == "profile") then
		ui.tab = TD.list[1]
	end
	if sub == "GOODS" or sub == "STASH" or sub == "DEAL" then
		ui.sub, ui.cpanel = "trade", sub -- the phone layout's panels (also the test bridge's way to open one)
	else
		ui.sub = sub or ui.sub
	end
	order = 0
	table.clear(live)
	compact = K.viewport().Y < 500
	local f, w, h = ctx.Screens.openModal(1180, 700, compact and "TRADERS" or "RELAY RADIO  //  TRADERS")
	Trade.open = "traders"
	Trade.frame = f
	local econ = d.econ or {}
	local lvl = econ.level or 1
	-- on a phone the level, money and restock share the title row with CLOSE (every point of height counts)
	local infoY, infoX, infoW = compact and 0 or 26, compact and 110 or 0, compact and -(110 + 92 + 150) or -180
	K.label(f, compact and string.format("LEVEL %d  ·  %s %s", lvl, Util.commas(d.money or 0), Config.CURRENCY) or string.format("LEVEL %d  ·  %s / %s XP  ·  %s %s", lvl, Util.commas(econ.xp or 0), Util.commas(P.xpFor(lvl + 1)), Util.commas(d.money or 0), Config.CURRENCY), compact and 13 or 12, {
		Position = UDim2.fromOffset(infoX, infoY), Size = UDim2.new(1, infoW, 0, compact and 36 or 18), TextColor3 = K.C.dim, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local restock = K.label(f, "", compact and 13 or 12, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, compact and -92 or 0, 0, infoY), Size = UDim2.fromOffset(compact and 150 or 180, compact and 36 or 18), TextColor3 = K.C.dim, TextXAlignment = Enum.TextXAlignment.Right })
	-- restockIn is relative to the snapshot's server time; when it runs out, ask for fresh stock counts
	table.insert(live, { label = restock, at = (d.serverTime or os.time()) + (econ.restockIn or 0), fmt = "RESTOCK IN %s", onDone = function()
		ctx.State.req("sync", {})
	end })
	local tabH = compact and 40 or 32
	local tabs = K.new("ScrollingFrame", {
		Name = "Tabs", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, compact and 40 or 48), Size = UDim2.new(1, 0, 0, tabH),
		ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollBarThickness = 0, Selectable = false,
	}, f)
	K.list(tabs, Enum.FillDirection.Horizontal, 6)
	local first, firstX, tabW = nil, 0, 0
	-- eight traders and three more tabs: on a PC they share the row (about 100 pt each at full width); a phone's strip
	-- keeps 112 pt tabs and scrolls, bringing the open one into view (below)
	local nTabs = #RADIO_TABS
	tabW = compact and math.max(112, math.floor((w - 6 * (nTabs - 1)) / nTabs)) or math.max(92, math.min(170, math.floor((w - 6 * (nTabs - 1)) / nTabs)))
	local tabText = (compact or tabW >= 112) and 13 or 12
	for i, id in RADIO_TABS do
		local st = econ.traders and econ.traders[id]
		local label = (id == "flea" and "FLEA MARKET") or (id == "messenger" or id == "handbook") and string.upper(id) or string.format("%s · LL%d", TD.defs[id].name, st and st.ll or 1)
		if id == "messenger" and ctx.Menus then
			local n = ctx.Menus.unread(d)
			if n > 0 and ui.tab ~= "messenger" then
				label ..= " (" .. n .. ")" -- Tarkov's unread count (audit ui.6)
			end
		end
		local sel = ui.tab == id
		local b = K.button(tabs, label, {
			Size = UDim2.fromOffset(tabW, tabH), TextSize = tabText, LayoutOrder = i,
			BackgroundColor3 = sel and Color3.fromHex("3A3524") or K.C.panel2, TextColor3 = sel and K.C.ochre or K.C.dim,
		})
		b.Name = "Tab_" .. string.upper(id)
		b.Activated:Connect(function()
			if ui.tab ~= id then
				Trade.traders(id)
			end
		end)
		if sel then
			first, firstX = b, (i - 1) * (tabW + 6)
		end
	end
	-- a phone's strip scrolls: the open tab is brought into view (LB / RB walk off its edge; audit ui.5)
	if first then
		task.defer(function()
			if tabs.Parent then
				tabs.CanvasPosition = Vector2.new(math.max(0, firstX - math.max(0, (w - tabW) / 2)), 0)
			end
		end)
	end
	local top = compact and 86 or 88
	local bodyH = h - top - (compact and 0 or 42)
	if ui.tab == "messenger" and ctx.Menus then
		ctx.Menus.markRead(d)
		ctx.Menus.messenger(f, 0, top, w, bodyH, d, Trade.refresh)
	elseif ui.tab == "handbook" and ctx.Menus then
		ctx.Menus.handbook(f, 0, top, w, bodyH, d, Trade.refresh)
	elseif ui.tab == "flea" and ctx.Menus then
		ctx.Menus.flea(f, 0, top, w, bodyH, d, Trade.refresh)
	elseif ui.tab == "profile" then
		profilePanel(f, 0, top, w, bodyH, d)
	else
		traderPanel(f, 0, top, w, bodyH, d, ui.tab)
	end
	local close = compact and K.button(f, "CLOSE", { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(84, 36), TextSize = 13 })
		or K.button(f, "CLOSE", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(140, 34) })
	close.Activated:Connect(ctx.Screens.close)
	-- the gamepad lands on the open tab, and keeps its place when new server state draws the screen again (audit ui.5)
	ctx.Screens.focus(first)
end

-- ── hideout ──────────────────────────────────────────────────────────────────
function Trade.hideout()
	local d = data()
	if not d or ctx.State.inRaid() then
		return
	end
	order = 0
	table.clear(live)
	local f, w, h = ctx.Screens.openModal(980, 600, "HIDEOUT  //  RELAY 7")
	Trade.open = "hideout"
	Trade.frame = f
	local hd = d.hideout or { levels = {}, crafts = {} }
	local levels = hd.levels or {}
	K.label(f, string.format("%s %s  ·  STASH 10x%d", Util.commas(d.money or 0), Config.CURRENCY, d.stashH or Config.STASH_H), 12, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 18), TextColor3 = K.C.dim })
	local top, bodyH = 50, h - 50 - 42
	local lw = math.floor(w * 0.52)
	local left = scroller(f, 0, top, lw, bodyH, "Modules")
	local right = scroller(f, lw + 12, top, w - lw - 12, bodyH, "Crafts")
	section(left, "MODULES")
	local building = hd.build
	for _, m in HD.ORDER do
		local mod = HD.modules[m]
		local cur = levels[m] or 0
		local nextDef = mod.levels[cur + 1]
		text(left, string.format("%s  ·  LEVEL %d/%d", mod.name, cur, #mod.levels), cur > 0 and K.C.green or K.C.text, 13, true)
		text(left, mod.desc .. (cur > 0 and ("  Now: " .. mod.levels[cur].effect .. ".") or ""), K.C.dim, 11)
		if building and building.m == m then
			local l = text(left, "", K.C.ochre, 12, true)
			table.insert(live, { label = l, at = building.at, fmt = "BUILDING LEVEL " .. building.l .. "  ·  %s" })
		elseif nextDef then
			local parts, ok = {}, true
			table.insert(parts, Util.commas(nextDef.cost) .. " " .. Config.CURRENCY)
			ok = ok and (d.money or 0) >= nextDef.cost
			for _, e in nextDef.items or {} do
				local n = stashCount(d, e[1])
				ok = ok and n >= e[2]
				table.insert(parts, Items.defs[e[1]].short .. " " .. have(n, e[2]))
			end
			for _, nd in nextDef.needs or {} do
				local okN = (levels[nd[1]] or 0) >= nd[2]
				ok = ok and okN
				table.insert(parts, string.format('<font color="#%s">%s %d</font>', okN and "93A57C" or "C24A35", HD.modules[nd[1]].name, nd[2]))
			end
			text(left, "  NEXT: " .. nextDef.effect .. "  ·  " .. Util.clock(nextDef.time), K.C.text, 11)
			local _, b = row(left, "", table.concat(parts, "  "), building and "BUSY" or "BUILD", ok and not building, function()
				req("hideout", { op = "build", m = m })
			end)
			b.Name = "Build_" .. m
		end
	end
	-- hideout style (Tarkov 0.16 customisation): walls, floor and ceiling of the bunker as you see it, by level
	section(left, "STYLE")
	local lvl = (d.econ and d.econ.level) or 1
	local mine = hd.style or {}
	for _, cat in HS.CATS do
		local cur = mine[cat] or HS.default(cat)
		for _, o in (HS :: any)[cat] do
			local open = HS.unlocked(o, lvl)
			local using = o.id == cur
			local _, b = row(left, HS.NAMES[cat] .. "  ·  " .. string.upper(o.name), (using or open) and "" or ("LEVEL " .. o.level),
				using and "IN USE" or (open and "USE" or "LOCKED"), open and not using, function()
					req("hideout", { op = "style", cat = cat, id = o.id })
				end, using and K.C.green or nil)
			b.Name = "Style_" .. cat .. "_" .. o.id
		end
	end
	section(right, "CRAFTING")
	for _, m in HD.ORDER do
		local recipes = {}
		for _, r in HD.recipes do
			if r.module == m then
				table.insert(recipes, r)
			end
		end
		if #recipes > 0 then
			text(right, HD.modules[m].name, K.C.text, 12, true)
			local running = hd.crafts and hd.crafts[m]
			if running then
				local r = HD.byRecipe[running.r]
				local l = text(right, "", K.C.ochre, 12)
				local out = string.upper(Items.defs[r.get[1]].name) .. " x" .. r.get[2]
				table.insert(live, { label = l, at = running.at, fmt = "  CRAFTING " .. out .. "  ·  %s", done = "  READY: " .. out })
				local _, b = row(right, "", "", "COLLECT", true, function()
					req("hideout", { op = "collect", m = m })
				end)
				b.Name = "Collect_" .. m
			end
			for _, r in recipes do
				local locked = (levels[m] or 0) < r.level
				local parts, ok = {}, true
				for _, e in r.give do
					local n = stashCount(d, e[1])
					ok = ok and n >= e[2]
					table.insert(parts, Items.defs[e[1]].short .. " " .. have(n, e[2]))
				end
				if #parts == 0 then
					table.insert(parts, "no materials")
				end
				local name = Items.defs[r.get[1]].name .. " x" .. r.get[2]
				local _, b = row(right, name, locked and ("LEVEL " .. r.level) or (table.concat(parts, "  ") .. "  ·  " .. Util.clock(r.time)), locked and "LOCKED" or "START", ok and not locked and not running, function()
					req("hideout", { op = "craft", r = r.id })
				end)
				b.Name = "Craft_" .. r.id
			end
		end
	end
	local close = K.button(f, "CLOSE", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(140, 34) })
	close.Activated:Connect(ctx.Screens.close)
	ctx.Screens.focus(close)
end

function Trade.refresh()
	if Trade.open and ctx.Screens.modal and ctx.Screens.modal == Trade.frame then
		if Trade.open == "traders" then
			Trade.traders()
		else
			Trade.hideout()
		end
	end
end

function Trade.init(c)
	ctx = c
	K = c.UiKit
	-- LB / RB: the previous / next radio tab (traders, flea market, messenger, handbook), wrapping round (audit ui.5)
	local function stepTab(dir)
		if not (Trade.open == "traders" and ctx.Screens.modal and ctx.Screens.modal == Trade.frame) then
			return
		end
		local i = table.find(RADIO_TABS, ui.tab) or 0
		ctx.Screens.tabSwitch = true
		Trade.traders(RADIO_TABS[(i - 1 + dir) % #RADIO_TABS + 1])
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
	-- redraw on new server state while a terminal screen is open (debounced), tick the timers every second
	c.State.changed:Connect(function()
		dirty = true
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		if not (ctx.Screens.modal and ctx.Screens.modal == Trade.frame) then
			Trade.open = nil
			return
		end
		if dirty then
			dirty = false
			Trade.refresh()
			return
		end
		local now = serverNow()
		for _, e in live do
			if e.label.Parent then
				local left = e.at - now
				if left <= 0 and e.onDone and not e.fired then
					e.fired = true
					task.spawn(e.onDone)
				end
				if left <= 0 and e.done then
					e.label.Text = e.done
				else
					e.label.Text = string.format(e.fmt, Util.clock(math.max(0, left)))
				end
			end
		end
	end)
end

return Trade
