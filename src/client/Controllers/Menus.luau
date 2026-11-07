--!nonstrict
-- Tarkov's MESSENGER and HANDBOOK (docs/design/EFT_PARITY.md section 3), drawn inside the relay radio screen.
-- MESSENGER: one dialog per trader plus INSURANCE and SYSTEM; insurance returns list their items and when they are
-- ready, RECEIVE ALL brings the ready ones to the stash; tasks and loyalty levels report here.
-- HANDBOOK: every item by category with a search; unexamined items stay unknown; a click opens the INSPECT window,
-- where items go on or off the WISH LIST (its own category here, and a mark on the item in the stash).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local TD = require(Shared.TraderData)

local Menus = {}
local ctx, K
local ui = { dialog = "insurance", cat = "ALL", search = "", scroll = {} }

local function scroller(parent, x, y, w, h, key)
	local sf = K.new("ScrollingFrame", {
		Name = key, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Selectable = false,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
	K.list(sf, nil, 4)
	task.defer(function()
		sf.CanvasPosition = ui.scroll[key] or Vector2.zero
	end)
	sf:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		ui.scroll[key] = sf.CanvasPosition
	end)
	return sf
end

local function ago(t, now)
	local s = math.max(0, now - (t or now))
	if s < 60 then
		return "JUST NOW"
	elseif s < 3600 then
		return math.floor(s / 60) .. " MIN AGO"
	elseif s < 86400 then
		return math.floor(s / 3600) .. " H AGO"
	end
	return math.floor(s / 86400) .. " D AGO"
end

local function sideButton(parent, label, on, order, fn)
	local b = K.button(parent, label, {
		LayoutOrder = order, Size = UDim2.new(1, -6, 0, 32), TextSize = 12, BackgroundColor3 = on and Color3.fromHex("3A3524") or K.C.panel2,
		TextColor3 = on and K.C.ochre or K.C.dim, TextXAlignment = Enum.TextXAlignment.Left,
	})
	K.new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, b)
	b.Activated:Connect(fn)
	return b
end

local function message(parent, order, head, body, color)
	local m = K.frame(parent, { LayoutOrder = order, BackgroundColor3 = K.C.panel, BackgroundTransparency = 0.2, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	K.pad(m, 8)
	K.list(m, nil, 2)
	K.label(m, head, 11, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 14), TextColor3 = K.C.dim })
	K.label(m, body, 13, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextColor3 = color or K.C.text })
	return m
end

-- ── MESSENGER ────────────────────────────────────────────────────────────────
function Menus.messenger(f, x, y, w, h, d, refresh)
	local now = d.serverTime or os.time()
	local left = scroller(f, x, y, 220, h, "Dialogs")
	local dialogs = { { "insurance", "INSURANCE" } }
	for _, id in TD.list do
		table.insert(dialogs, { id, TD.defs[id].name })
	end
	table.insert(dialogs, { "system", "SYSTEM" })
	local counts = {}
	for _, m in d.msgs or {} do
		counts[m.f] = (counts[m.f] or 0) + 1
	end
	counts.insurance = #(d.claimList or {})
	for i, e in dialogs do
		local n = counts[e[1]] or 0
		local b = sideButton(left, e[2] .. (n > 0 and ("   " .. n) or ""), ui.dialog == e[1], i, function()
			ui.dialog = e[1]
			refresh()
		end)
		b.Name = "Dialog_" .. e[1]
	end
	local right = scroller(f, x + 232, y, w - 232, h - 44, "Messages")
	local order = 0
	if ui.dialog == "insurance" then
		local ready = 0
		for _, c in d.claimList or {} do
			order += 1
			local names = {}
			for _, id in c.ids do
				table.insert(names, Items.defs[id] and Items.defs[id].name or id)
			end
			if c.n > #c.ids then
				table.insert(names, "+" .. (c.n - #c.ids) .. " more")
			end
			local isReady = c.readyIn <= 0
			if isReady then
				ready += c.n
			end
			message(right, order, isReady and "READY TO COLLECT" or ("ARRIVES IN " .. Util.clock(c.readyIn)),
				"Your insured items were not found by anyone and came back: " .. table.concat(names, ", ") .. ".", isReady and K.C.green or K.C.text)
		end
		if order == 0 then
			message(right, 1, "INSURANCE", "Nothing is on its way. Insured items lost in a raid come back here if nobody extracts with them.", K.C.dim)
		end
		local b = K.button(f, ready > 0 and ("RECEIVE ALL  (" .. ready .. ")") or "RECEIVE ALL", {
			Name = "ReceiveAll", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromOffset(x + w, y + h), Size = UDim2.fromOffset(200, 36),
			TextColor3 = ready > 0 and K.C.green or K.C.dim, AutoButtonColor = ready > 0,
		})
		if ready > 0 then
			b.Activated:Connect(function()
				ctx.State.req("inv", { op = "claim" })
			end)
		end
		return
	end
	local list = {}
	for _, m in d.msgs or {} do
		if m.f == ui.dialog then
			table.insert(list, m)
		end
	end
	for i = #list, 1, -1 do
		local m = list[i]
		order += 1
		local from = ui.dialog == "system" and "SYSTEM" or (TD.defs[ui.dialog] and TD.defs[ui.dialog].name or string.upper(ui.dialog))
		message(right, order, from .. "  ·  " .. ago(m.t, now), m.x)
	end
	if order == 0 then
		message(right, 1, "", "No messages.", K.C.dim)
	end
end

-- ── HANDBOOK ─────────────────────────────────────────────────────────────────
-- signal flares are EFT's RSP-30 cartridges, filed under SPECIAL EQUIPMENT (tarkovforge.com/special-equipment, 2026);
-- they had no category here, so the handbook and the flea market never listed them (audit economy.11)
local CAT = {
	weapon = "WEAPONS", pistol = "WEAPONS", melee = "WEAPONS", mod = "WEAPON PARTS", mag = "MAGAZINES", ammo = "AMMUNITION", grenade = "GRENADES",
	armor = "GEAR", helmet = "GEAR", rig = "GEAR", backpack = "GEAR", headwear = "GEAR", headset = "GEAR", facecover = "GEAR", eyewear = "GEAR", secure = "CONTAINERS",
	med = "MEDICATION", food = "PROVISIONS", key = "KEYS", loot = "BARTER ITEMS", repair = "BARTER ITEMS", quest = "INFO ITEMS", nvg = "GEAR",
	flare = "SPECIAL EQUIPMENT",
}
local CATS = { "ALL", "WEAPONS", "WEAPON PARTS", "MAGAZINES", "AMMUNITION", "GRENADES", "GEAR", "CONTAINERS", "MEDICATION", "PROVISIONS", "KEYS", "BARTER ITEMS", "SPECIAL EQUIPMENT", "INFO ITEMS", "WISH LIST" }
Menus.CAT, Menus.CATS = CAT, CATS -- read by EconomyTests (every item kind has a category)
local sorted
local function allItems()
	if not sorted then
		sorted = {}
		for id, def in Items.defs do
			if def.name and CAT[def.kind] then
				table.insert(sorted, id)
			end
		end
		table.sort(sorted, function(a, b)
			return Items.defs[a].name < Items.defs[b].name
		end)
	end
	return sorted
end

-- how many of an item you have in the stash and on you (wish list counts)
local function owned(d, id)
	local n = 0
	for _, it in d.items or {} do
		if it.id == id then
			n += it.n or 1
		end
	end
	return n
end

function Menus.handbook(f, x, y, w, h, d, refresh)
	local wish = ctx.Settings.data.wish or {}
	local left = scroller(f, x, y + 36, 220, h - 36, "HandbookCats")
	for i, c in CATS do
		local b = sideButton(left, c, ui.cat == c, i, function()
			ui.cat = c
			refresh()
		end)
		b.Name = "Cat_" .. c
	end
	local box = K.new("TextBox", {
		Name = "Search", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(214, 28), Text = ui.search, PlaceholderText = "SEARCH",
		ClearTextOnFocus = false, TextSize = 12, FontFace = K.font, TextColor3 = K.C.text, PlaceholderColor3 = K.C.dim, BackgroundColor3 = K.C.panel2,
		BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	K.new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)
	box.FocusLost:Connect(function()
		if box.Text ~= ui.search then
			ui.search = box.Text
			refresh()
		end
	end)
	local right = scroller(f, x + 232, y, w - 232, h, "HandbookItems")
	local q = string.lower(ui.search)
	local order = 0
	for _, id in allItems() do
		local def = Items.defs[id]
		local known = (d.known and d.known[id]) or Items.knownByDefault(id)
		local inCat = ui.cat == "ALL" or CAT[def.kind] == ui.cat or (ui.cat == "WISH LIST" and wish[id])
		local hit = q == "" or (known and (string.find(string.lower(def.name), q, 1, true) or string.find(string.lower(def.short or ""), q, 1, true)))
		if inCat and hit then
			order += 1
			local r = K.new("TextButton", {
				Name = "Item_" .. id, LayoutOrder = order, Text = "", AutoButtonColor = true, BorderSizePixel = 0, BackgroundColor3 = K.C.panel,
				BackgroundTransparency = 0.2, Size = UDim2.new(1, -8, 0, 44), Selectable = true, SelectionImageObject = K.selection(),
			}, right)
			local pw = math.floor(math.min(76, 40 * def.w / def.h))
			local pic = K.frame(r, { BackgroundColor3 = K.C.panel2, Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(pw, 40) })
			K.itemIcon(pic, id, pw, 40, false, not known, 3)
			K.label(r, known and def.name or "UNKNOWN ITEM", 13, { Position = UDim2.fromOffset(pw + 10, 4), Size = UDim2.new(0.6, -pw - 10, 0, 18), FontFace = K.bold, TextTruncate = Enum.TextTruncate.AtEnd })
			K.label(r, CAT[def.kind] .. (known and ("  ·  " .. Util.commas(def.value or 0) .. " " .. Config.CURRENCY) or ""), 11, { Position = UDim2.fromOffset(pw + 10, 22), Size = UDim2.new(0.6, -pw - 10, 0, 16), TextColor3 = K.C.dim })
			if wish[id] then
				K.label(r, "WISH LIST  ·  HAVE " .. owned(d, id), 11, {
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(200, 16), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = K.C.ochre,
				})
			end
			r.Activated:Connect(function()
				if ctx.Inspect then
					-- guns as their default build (Tarkov's handbook shows the standard preset)
					local items, g = K.iconItems(id)
					ctx.Inspect.open(items, g, { key = "hb:" .. id, unknown = not known })
				end
			end)
		end
	end
	if order == 0 then
		K.label(right, ui.cat == "WISH LIST" and "Your wish list is empty. Add items from their INSPECT window." or "Nothing matches.", 12, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), TextColor3 = K.C.dim })
	end
end

-- ── FLEA MARKET ──────────────────────────────────────────────────────────────
-- Tarkov's flea market: BROWSE (categories and search over the operators' offers, cheapest first, PURCHASE with a
-- quantity), WISH LIST, MY OFFERS (time left, REMOVE) and ADD OFFER (found-in-raid stash items, the asking price and
-- Tarkov's listing fee, worked out by the same rules as the server). It opens at level 15; EFT 1.0's gated categories
-- show greyed out with the level they need (FleaRules.levelFor, audit economy.3).
local FR = require(Shared.FleaRules)
local flea = { view = "browse", cat = "ALL", search = "", qty = "1", at = 0 }
local ROW_MAX = 100

local function fetchMarket(refresh)
	if flea.loading then
		return
	end
	flea.loading = true
	task.spawn(function()
		local res = ctx.State.req("flea", { op = "market" })
		flea.loading = false
		if res.ok and res.data then
			flea.market = res.data.offers
			flea.at = os.clock() + (res.data.refreshIn or FR.WINDOW)
		else
			flea.market = flea.market or {}
			flea.at = os.clock() + 5
		end
		refresh()
	end)
end

local function itemRow(parent, order, id, name, known, h)
	local def = Items.defs[id]
	local r = K.frame(parent, { LayoutOrder = order, BackgroundColor3 = K.C.panel, BackgroundTransparency = 0.2, Size = UDim2.new(1, -8, 0, h or 44) })
	local pw = math.floor(math.min(76, 40 * def.w / def.h))
	local pic = K.new("TextButton", { Text = "", AutoButtonColor = true, BorderSizePixel = 0, BackgroundColor3 = K.C.panel2, Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(pw, 40) }, r)
	K.itemIcon(pic, id, pw, 40, false, not known, 3)
	pic.Activated:Connect(function()
		local items, g = K.iconItems(id)
		ctx.Inspect.open(items, g, { key = "flea:" .. id, unknown = not known })
	end)
	K.label(r, name, 13, { Position = UDim2.fromOffset(pw + 10, 4), Size = UDim2.fromOffset(420 - pw, 18), FontFace = K.bold, TextTruncate = Enum.TextTruncate.AtEnd })
	return r, pw
end

local function cell(r, text, x, w, color, right)
	return K.label(r, text, 13, {
		Position = UDim2.fromOffset(x, 0), Size = UDim2.new(0, w, 1, 0), TextColor3 = color or K.C.text,
		TextXAlignment = right and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
	})
end

local function browse(f, x, y, w, h, d, refresh)
	if not flea.market or os.clock() > flea.at then
		fetchMarket(refresh)
	end
	local wish = ctx.Settings.data.wish or {}
	local lx = x
	if flea.view == "browse" then
		local box = K.new("TextBox", {
			Name = "FleaSearch", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(214, 28), Text = flea.search, PlaceholderText = "SEARCH",
			ClearTextOnFocus = false, TextSize = 12, FontFace = K.font, TextColor3 = K.C.text, PlaceholderColor3 = K.C.dim, BackgroundColor3 = K.C.panel2,
			BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left,
		}, f)
		K.new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)
		box.FocusLost:Connect(function()
			if box.Text ~= flea.search then
				flea.search = box.Text
				refresh()
			end
		end)
		local left = scroller(f, x, y + 36, 220, h - 36, "FleaCats")
		for i, c in CATS do
			if c ~= "WISH LIST" and c ~= "CONTAINERS" and c ~= "INFO ITEMS" then
				sideButton(left, c, flea.cat == c, i, function()
					flea.cat = c
					refresh()
				end).Name = "FleaCat_" .. c
			end
		end
		lx = x + 232
	end
	local lw = x + w - lx
	local cols = { { "ITEM", 0 }, { "SELLER", 440 }, { "STOCK", 600 }, { "PRICE", 700 } }
	for _, c in cols do
		K.label(f, c[1], 11, { Position = UDim2.fromOffset(lx + c[2] + 6, y + 6), Size = UDim2.fromOffset(120, 16), TextColor3 = K.C.dim })
	end
	K.label(f, "QTY", 11, { Position = UDim2.fromOffset(lx + lw - 120, y + 6), Size = UDim2.fromOffset(30, 16), TextColor3 = K.C.dim })
	local qty = K.new("TextBox", {
		Name = "FleaQty", Position = UDim2.fromOffset(lx + lw - 86, y), Size = UDim2.fromOffset(70, 28), Text = flea.qty, ClearTextOnFocus = false,
		TextSize = 13, FontFace = K.font, TextColor3 = K.C.text, BackgroundColor3 = K.C.panel2, BorderSizePixel = 0,
	}, f)
	qty.FocusLost:Connect(function()
		flea.qty = tostring(math.max(1, math.floor(tonumber(qty.Text) or 1)))
		qty.Text = flea.qty
	end)
	local list = scroller(f, lx, y + 34, lw, h - 34, "FleaOffers")
	if not flea.market then
		K.label(list, "LOADING OFFERS...", 12, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), TextColor3 = K.C.dim })
		return
	end
	local q = string.lower(flea.search)
	if flea.view == "browse" and flea.cat == "ALL" and q == "" then
		K.label(list, "Choose a category or search for an item.", 12, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), TextColor3 = K.C.dim })
		return
	end
	local myLevel = (d.econ and d.econ.level) or 1
	local order = 0
	for _, id in allItems() do
		local def = Items.defs[id]
		local offers = flea.market[id]
		-- EFT 1.0's category gates (audit economy.3): a gated offer shows greyed out with the level it needs
		local need = FR.levelFor(id)
		local gated = myLevel < need
		local show = offers and #offers > 0
		if show and flea.view == "wish" then
			show = wish[id] == true
		elseif show then
			show = (flea.cat == "ALL" or CAT[def.kind] == flea.cat)
				and (q == "" or string.find(string.lower(def.name), q, 1, true) ~= nil or string.find(string.lower(def.short or ""), q, 1, true) ~= nil)
		end
		if show then
			for _, o in offers do
				order += 1
				if order > ROW_MAX then
					break
				end
				local r, pw = itemRow(list, order, id, def.name, true)
				r.Name = "Offer_" .. id .. "_" .. o.i
				if gated then
					r.BackgroundTransparency = 0.6
				end
				K.label(r, CAT[def.kind] .. "  ·  AVG " .. Util.commas(FR.marketPrice(id)), 11, { Position = UDim2.fromOffset(pw + 10, 22), Size = UDim2.fromOffset(340, 16), TextColor3 = K.C.dim })
				cell(r, o.seller, 446, 150, gated and K.C.dim or K.C.text)
				cell(r, o.left > 0 and ("x" .. o.left) or "SOLD OUT", 606, 90, gated and K.C.dim or (o.left > 0 and K.C.text or K.C.red))
				cell(r, Util.commas(o.price) .. " " .. Config.CURRENCY, 706, 130, gated and K.C.dim or K.C.ochre)
				if gated then
					K.label(r, "REQUIRES LEVEL " .. need, 12, {
						Name = "Locked", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(140, 30),
						TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = K.C.orange,
					})
				elseif o.left > 0 then
					local b = K.button(r, "PURCHASE", { Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(100, 30), TextSize = 12 })
					b.Activated:Connect(function()
						local n = math.clamp(math.floor(tonumber(flea.qty) or 1), 1, o.left)
						task.spawn(function()
							if ctx.State.req("flea", { op = "buy", id = id, i = o.i, n = n }).ok then
								flea.at = 0
								refresh()
							end
						end)
					end)
				end
			end
		end
		if order > ROW_MAX then
			K.label(list, "More offers than fit here: narrow the search.", 12, { LayoutOrder = order + 1, Size = UDim2.new(1, 0, 0, 20), TextColor3 = K.C.dim })
			break
		end
	end
	if order == 0 then
		local msg = flea.view == "wish" and "Nothing on your wish list is offered right now." or "No offers."
		K.label(list, msg, 12, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), TextColor3 = K.C.dim })
	end
end

local function mine(f, x, y, w, h, d, fl)
	local list = scroller(f, x, y, w, h - 30, "FleaMine")
	for i, o in fl.offers or {} do
		local def = Items.defs[o.id]
		if def then
			local r = itemRow(list, i, o.id, def.name .. ((o.n or 1) > 1 and ("  x" .. o.n) or ""), true)
			r.Name = "Mine_" .. o.k
			cell(r, Util.commas(o.price) .. " " .. Config.CURRENCY, 446, 160, K.C.ochre)
			cell(r, string.format("EXPIRES IN %d H %02d MIN", o.left // 3600, (o.left % 3600) // 60), 616, 220, K.C.dim)
			local b = K.button(r, "REMOVE", { Name = "Remove", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(100, 30), TextSize = 12 })
			b.Activated:Connect(function()
				ctx.State.req("flea", { op = "remove", k = o.k })
			end)
		end
	end
	if #(fl.offers or {}) == 0 then
		K.label(list, "You have no offers. ADD OFFER puts a found-in-raid item from your stash on the market.", 12, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), TextColor3 = K.C.dim })
	end
	K.label(f, "Other operators buy your offers over time: the nearer the average price, the sooner. Unsold offers come back after 12 hours; pulling or losing an offer costs rating.", 11, {
		Position = UDim2.fromOffset(x, y + h - 22), Size = UDim2.fromOffset(w - 160, 18), TextColor3 = K.C.dim, TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

local function addOffer(f, x, y, w, h, d, fl, refresh)
	local list = scroller(f, x, y, 560, h, "FleaStash")
	local rows = {}
	for g in (d.grids and d.grids.stash) or {} do
		local it = d.items[g]
		if it and Items.defs[it.id] then
			table.insert(rows, g)
		end
	end
	table.sort(rows, function(a, b)
		local na, nb = Items.defs[d.items[a].id].name, Items.defs[d.items[b].id].name
		return na == nb and a < b or na < nb
	end)
	for i, g in rows do
		local it = d.items[g]
		local def = Items.defs[it.id]
		local why = (not FR.tradeable(it.id)) and "CAN'T BE OFFERED"
			or (not it.fir) and "NOT FOUND IN RAID"
			or (d.grids[g] and next(d.grids[g])) and "NOT EMPTY"
			or nil
		local r, pw = itemRow(list, i, it.id, def.name .. ((it.n or 1) > 1 and ("  x" .. it.n) or ""), true)
		r.Name = "Stash_" .. g
		r.BackgroundColor3 = flea.sel == g and Color3.fromHex("3A3524") or K.C.panel
		K.label(r, why or "FOUND IN RAID", 11, { Position = UDim2.fromOffset(pw + 10, 22), Size = UDim2.fromOffset(300, 16), TextColor3 = why and K.C.dim or K.C.green })
		if not why then
			local b = K.button(r, "SELECT", { Name = "Select", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(90, 30), TextSize = 12 })
			b.Activated:Connect(function()
				flea.sel, flea.price = g, nil
				refresh()
			end)
		end
	end
	if #rows == 0 then
		K.label(list, "Your stash is empty.", 12, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), TextColor3 = K.C.dim })
	end
	local px, pw = x + 580, w - 580
	local it = flea.sel and d.items[flea.sel]
	if not it then
		K.label(f, "Choose a found-in-raid item from your stash.", 13, { Position = UDim2.fromOffset(px, y + 10), Size = UDim2.fromOffset(pw, 20), TextColor3 = K.C.dim })
		return
	end
	local def = Items.defs[it.id]
	local n = it.n or 1
	local avg = FR.marketPrice(it.id) * n
	local price = flea.price or avg
	local panel = K.frame(f, { Name = "OfferPanel", BackgroundColor3 = K.C.panel, BackgroundTransparency = 0.2, Position = UDim2.fromOffset(px, y), Size = UDim2.fromOffset(pw, 300) })
	K.pad(panel, 12)
	K.label(panel, def.name .. (n > 1 and ("  x" .. n) or ""), 16, { Size = UDim2.new(1, 0, 0, 22), FontFace = K.bold })
	K.label(panel, "AVERAGE PRICE  " .. Util.commas(avg) .. " " .. Config.CURRENCY, 13, { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 18), TextColor3 = K.C.dim })
	K.label(panel, "YOUR PRICE", 13, { Position = UDim2.fromOffset(0, 70), Size = UDim2.fromOffset(120, 28) })
	local box = K.new("TextBox", {
		Name = "FleaPrice", Position = UDim2.fromOffset(120, 70), Size = UDim2.fromOffset(180, 28), Text = tostring(price), ClearTextOnFocus = false,
		TextSize = 14, FontFace = K.font, TextColor3 = K.C.ochre, BackgroundColor3 = K.C.panel2, BorderSizePixel = 0,
	}, panel)
	local feeL = K.label(panel, "", 13, { Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 18) })
	local function update()
		local v = math.floor(tonumber(box.Text) or 0)
		if v >= 1 then
			flea.price = v
			feeL.Text = "LISTING FEE  " .. Util.commas(FR.fee(def.value or 0, n, v)) .. " " .. Config.CURRENCY
		else
			feeL.Text = "LISTING FEE  -"
		end
	end
	box:GetPropertyChangedSignal("Text"):Connect(update)
	update()
	local used = #(fl.offers or {})
	K.label(panel, string.format("OFFERS  %d / %d  ·  RATING %.2f", used, fl.slots or 2, fl.rating or 0.2), 12, { Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, 0, 0, 18), TextColor3 = K.C.dim })
	K.label(panel, "The fee is paid now and not returned. The offer runs 12 hours.", 11, { Position = UDim2.fromOffset(0, 166), Size = UDim2.new(1, 0, 0, 30), TextWrapped = true, TextColor3 = K.C.dim })
	local place = K.button(panel, "PLACE OFFER", { Name = "PlaceOffer", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(180, 36), TextColor3 = K.C.green })
	place.Activated:Connect(function()
		update()
		local g, v = flea.sel, flea.price
		task.spawn(function()
			if ctx.State.req("flea", { op = "list", g = g, price = v }).ok then
				flea.view, flea.sel, flea.price = "mine", nil, nil
				refresh()
			end
		end)
	end)
end

function Menus.flea(f, x, y, w, h, d, refresh)
	local fl = d.flea
	local lvl = (d.econ and d.econ.level) or 1
	if not fl or lvl < FR.LEVEL then
		K.label(f, string.format("THE FLEA MARKET OPENS AT LEVEL %d  ·  YOU ARE LEVEL %d", FR.LEVEL, lvl), 16, {
			Name = "FleaLocked", Position = UDim2.fromOffset(x, y + 60), Size = UDim2.fromOffset(w, 24), FontFace = K.bold, TextColor3 = K.C.dim,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		return
	end
	local bar = K.frame(f, { BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w - 320, 30) })
	K.list(bar, Enum.FillDirection.Horizontal, 6)
	local views = { { "browse", "BROWSE" }, { "wish", "WISH LIST" }, { "mine", string.format("MY OFFERS  %d/%d", #(fl.offers or {}), fl.slots or 2) }, { "add", "ADD OFFER" } }
	for i, v in views do
		local on = flea.view == v[1]
		local b = K.button(bar, v[2], {
			LayoutOrder = i, Size = UDim2.fromOffset(150, 30), TextSize = 12,
			BackgroundColor3 = on and Color3.fromHex("3A3524") or K.C.panel2, TextColor3 = on and K.C.ochre or K.C.dim,
		})
		b.Name = "Flea_" .. v[1]
		b.Activated:Connect(function()
			flea.view, flea.sel, flea.price = v[1], nil, nil
			refresh()
		end)
	end
	K.label(f, string.format("FLEA RATING  %.2f", fl.rating or 0.2), 13, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(x + w, y + 6), Size = UDim2.fromOffset(300, 18), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = K.C.ochre,
	})
	local by, bh = y + 40, h - 40
	if flea.view == "mine" then
		mine(f, x, by, w, bh, d, fl)
	elseif flea.view == "add" then
		addOffer(f, x, by, w, bh, d, fl, refresh)
	else
		browse(f, x, by, w, bh, d, refresh)
	end
end

-- Tarkov's messenger keeps an unread count, and a new message pops a notice (audit ui.6). Read means older than the
-- time the messenger was last opened (Settings msgSeen, saved with the profile).
function Menus.unread(d)
	local seen = (ctx.Settings and ctx.Settings.data.msgSeen) or 0
	local n = 0
	for _, m in (d and d.msgs) or {} do
		if (m.t or 0) > seen then
			n += 1
		end
	end
	return n
end

function Menus.markRead(d)
	local newest = 0
	for _, m in (d and d.msgs) or {} do
		newest = math.max(newest, m.t or 0)
	end
	if newest > ((ctx.Settings and ctx.Settings.data.msgSeen) or 0) then
		ctx.Settings.set("msgSeen", newest)
	end
end

local FROM = { system = "SYSTEM", insurance = "INSURANCE" }
function Menus.init(c)
	ctx = c
	K = c.UiKit
	-- a notice when a message arrives (not for the ones already there on joining)
	local lastT = nil
	c.State.changed:Connect(function(snap)
		local msgs = snap and snap.msgs
		if type(msgs) ~= "table" then
			return
		end
		local newest, from = 0, nil
		for _, m in msgs do
			if (m.t or 0) >= newest then
				newest, from = m.t or 0, m.f
			end
		end
		if lastT ~= nil and newest > lastT then
			local who = FROM[from] or (TD.defs[from] and TD.defs[from].name) or "SOMEONE"
			c.State.toast("NEW MESSAGE  ·  " .. string.upper(who) .. "  ·  RELAY RADIO, MESSENGER", "info")
		end
		lastT = newest
	end)
end

return Menus
