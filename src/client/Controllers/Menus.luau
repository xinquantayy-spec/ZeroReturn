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
local HD = require(Shared.HideoutData)

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

-- a list button down the left side; tall: a phone's 44 pt touch height (the radio's compact layout, ui-3a)
local function sideButton(parent, label, on, order, fn, tall)
	local b = K.button(parent, label, {
		LayoutOrder = order, Size = UDim2.new(1, -6, 0, tall and 44 or 32), TextSize = tall and 13 or 12, BackgroundColor3 = on and Color3.fromHex("3A3524") or K.C.panel2,
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
	-- one chat per trader (EFT's eight, in TraderData's order) plus INSURANCE and SYSTEM; a phone gets a narrower list of
	-- taller buttons, which scrolls (ten chats do not fit a landscape phone's height)
	local compact = K.viewport().Y < 500
	local listW = compact and math.clamp(math.floor(w * 0.3), 150, 220) or 220
	local left = scroller(f, x, y, listW, h, "Dialogs")
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
		end, compact)
		b.Name = "Dialog_" .. e[1]
	end
	local right = scroller(f, x + listW + 12, y, w - listW - 12, h - 44, "Messages")
	local order = 0
	if ui.dialog == "insurance" then
		-- insurance returns (decision gameplay-6b): each from its insurer, with its items, when it arrives and how long the
		-- messenger holds it; RECEIVE ALL brings the ready ones to the stash; a return not collected in time is gone (EFT).
		-- Task rewards that did not fit the stash wait here too.
		local function hms(sec)
			-- returns and storage run for hours: H:MM:SS from an hour up (Util.clock shows MM:SS)
			sec = math.max(0, math.floor(sec))
			return sec >= 3600 and string.format("%d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60) or Util.clock(sec)
		end
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
			local who = c.k == "task" and "TASK REWARD" or ((c.isr and TD.defs[c.isr]) and TD.defs[c.isr].name or "INSURANCE")
			local head = who .. "  ·  " .. (not isReady and ("ARRIVES IN " .. hms(c.readyIn))
				or (c.expIn and ("READY  ·  COLLECT WITHIN " .. hms(c.expIn)) or "READY TO COLLECT"))
			local body = c.k == "task" and ("Task reward items waiting for room in your stash: " .. table.concat(names, ", ") .. ".")
				or (isReady and ("Your insured items were not found by anyone and came back: " .. table.concat(names, ", ") .. ".")
					or ("Nobody found your insured items; the insurer is bringing them back: " .. table.concat(names, ", ") .. "."))
			message(right, order, head, body, isReady and ((c.expIn and c.expIn < 3600) and K.C.orange or K.C.green) or K.C.text)
		end
		-- the insurers' notices: returns nobody collected in time (newest first)
		local msgs = d.msgs or {}
		for i = #msgs, 1, -1 do
			local m = msgs[i]
			if m.f == "insurance" then
				order += 1
				message(right, order, "INSURANCE  ·  " .. ago(m.t, now), m.x, K.C.orange)
			end
		end
		if order == 0 then
			message(right, 1, "INSURANCE", "Nothing is on its way. Insured items lost in a raid come back here from their insurer if nobody extracts with them; collect them before the storage time runs out.", K.C.dim)
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
	-- task mail (economy-6a, Quests tags it): EFT's trader sends the task's text when you take it, the reward when you turn
	-- it in, and a note when an operational task's time runs out
	local TASK_HEAD = { start = "NEW TASK", done = "TASK COMPLETE", fail = "TASK FAILED" }
	local TASK_COLOR = { start = K.C.ochre, done = K.C.green, fail = K.C.red }
	for i = #list, 1, -1 do
		local m = list[i]
		order += 1
		local from = ui.dialog == "system" and "SYSTEM" or (TD.defs[ui.dialog] and TD.defs[ui.dialog].name or string.upper(ui.dialog))
		local tag = m.k and TASK_HEAD[m.k]
		message(right, order, from .. "  ·  " .. (tag and (tag .. "  ·  ") or "") .. ago(m.t, now), m.x, m.k and TASK_COLOR[m.k] or nil)
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
	armor = "GEAR", plate = "GEAR", helmet = "GEAR", rig = "GEAR", backpack = "GEAR", headwear = "GEAR", headset = "GEAR", facecover = "GEAR", eyewear = "GEAR", secure = "CONTAINERS",
	med = "MEDICATION", food = "PROVISIONS", key = "KEYS", loot = "BARTER ITEMS", repair = "BARTER ITEMS", quest = "INFO ITEMS", nvg = "GEAR",
	flare = "SPECIAL EQUIPMENT",
}
local CATS = { "ALL", "WEAPONS", "WEAPON PARTS", "MAGAZINES", "AMMUNITION", "GRENADES", "GEAR", "CONTAINERS", "MEDICATION", "PROVISIONS", "KEYS", "BARTER ITEMS", "SPECIAL EQUIPMENT", "INFO ITEMS", "WISH LIST" }
Menus.CAT, Menus.CATS = CAT, CATS -- read by EconomyTests (every item kind has a category)
-- EFT's handbook folders inside BARTER ITEMS (each barter good's def.cat, economy-1a's second slice): shown under it in
-- the HANDBOOK and the flea market's BROWSE tree when BARTER ITEMS is open
local SUBS = {
	{ "building", "BUILDING MATERIALS" }, { "electronics", "ELECTRONICS" }, { "energy", "ENERGY ELEMENTS" }, { "flammable", "FLAMMABLE MATERIALS" },
	{ "household", "HOUSEHOLD MATERIALS" }, { "info", "INFO ITEMS" }, { "medical", "MEDICAL SUPPLIES" }, { "others", "OTHERS" },
	{ "tools", "TOOLS" }, { "valuables", "VALUABLES" },
}
Menus.SUBS = SUBS

-- the category list down the left side: the categories, and EFT's folders under BARTER ITEMS when it is open.
-- st = { cat, sub } (the handbook's or the flea market's choice); skip: categories left out; prefix: button names
local function catList(left, st, skip, refresh, prefix)
	for i, c in CATS do
		if not (skip and skip[c]) then
			sideButton(left, c, st.cat == c and st.sub == nil, i * 100, function()
				st.cat, st.sub = c, nil
				refresh()
			end).Name = (prefix or "Cat_") .. c
			if c == "BARTER ITEMS" and st.cat == c then
				for k, s in SUBS do
					sideButton(left, "   " .. s[2], st.sub == s[1], i * 100 + k, function()
						st.sub = s[1]
						refresh()
					end).Name = "Sub_" .. s[1]
				end
			end
		end
	end
end

-- is an item in the chosen category (and folder)
local function inCat(def, cat, sub)
	return (cat == "ALL" or CAT[def.kind] == cat) and (sub == nil or def.cat == sub)
end
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
	catList(left, ui, nil, refresh)
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
		local shown = inCat(def, ui.cat, ui.sub) or (ui.cat == "WISH LIST" and wish[id])
		local hit = q == "" or (known and (string.find(string.lower(def.name), q, 1, true) or string.find(string.lower(def.short or ""), q, 1, true)))
		if shown and hit then
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
-- Tarkov's flea market, shared by every server since decision economy-3a: BROWSE (categories and search over players'
-- and operators' offers together, cheapest first by the price of one unit, each seller's name and rating, PURCHASE
-- with a quantity, packs bought whole), WISH LIST, MY OFFERS (units left, time left, REMOVE, which ends an offer 72 s
-- later as in EFT; returned items that found no room wait here with RECEIVE) and ADD OFFER (found-in-raid stash items,
-- a price per item or for the whole pack, Tarkov's listing fee worked out by the same rules as the server, the cheapest
-- offer now). It opens at level 15; EFT 1.0's gated categories show greyed out with the level they need
-- (FleaRules.levelFor, audit economy.3). Someone buying an offer first is told by the server and the list refreshes.
local FR = require(Shared.FleaRules)
local flea = { view = "browse", cat = "ALL", search = "", qty = "1", at = 0, pack = false }
local ROW_MAX = 100
local MAX_IDS = 160 -- the server's limit on items one market request may ask for (Flea.MAX_IDS)

local function fleaKnown(d, id)
	return (d.known and d.known[id]) or Items.knownByDefault(id)
end

-- the items the current BROWSE or WISH LIST view can show (the server is asked only for these)
local function viewIds(d)
	local wish = ctx.Settings.data.wish or {}
	local q = string.lower(flea.search)
	local out = {}
	for _, id in allItems() do
		local def = Items.defs[id]
		if #out < MAX_IDS and FR.tradeable(id) and fleaKnown(d, id) then
			local show
			if flea.view == "wish" then
				show = wish[id] == true
			else
				show = inCat(def, flea.cat, flea.sub)
					and (q == "" or string.find(string.lower(def.name), q, 1, true) ~= nil or string.find(string.lower(def.short or ""), q, 1, true) ~= nil)
			end
			if show then
				table.insert(out, id)
			end
		end
	end
	return out
end

local function viewKey()
	return flea.view .. "|" .. flea.cat .. "|" .. (flea.sub or "") .. "|" .. flea.search
end

local function fetchMarket(d, refresh)
	if flea.loading then
		return
	end
	flea.loading = true
	local key, ids = viewKey(), viewIds(d)
	task.spawn(function()
		local res = ctx.State.req("flea", { op = "market", ids = ids })
		flea.loading = false
		if res.ok and res.data then
			flea.market, flea.key = res.data.offers, key
			-- players' offers come and go: the list is asked for again every half minute while it is open
			flea.at = os.clock() + math.clamp(res.data.refreshIn or 30, 5, 30)
		else
			flea.market = flea.market or {}
			flea.at = os.clock() + 5
		end
		refresh()
	end)
end

-- EFT shows each seller's rating beside the name
local function ratingText(r)
	r = r or 0
	return math.abs(r) >= 100 and string.format("%.0f", r) or string.format("%.2f", r)
end

local function timeLeft(sec)
	sec = math.max(0, math.floor(sec or 0))
	if sec >= 3600 then
		return string.format("%d H %02d MIN", sec // 3600, (sec % 3600) // 60)
	end
	return string.format("%d:%02d", sec // 60, sec % 60)
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
	local idle = flea.view == "browse" and flea.cat == "ALL" and flea.search == ""
	if not idle and (not flea.market or flea.key ~= viewKey() or os.clock() > flea.at) then
		fetchMarket(d, refresh)
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
		catList(left, flea, { ["WISH LIST"] = true, ["CONTAINERS"] = true, ["INFO ITEMS"] = true }, refresh, "FleaCat_")
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
	local q = string.lower(flea.search)
	if idle then
		K.label(list, "Choose a category or search for an item.", 12, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), TextColor3 = K.C.dim })
		return
	end
	if not flea.market or flea.key ~= viewKey() then
		K.label(list, "LOADING OFFERS...", 12, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), TextColor3 = K.C.dim })
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
			show = inCat(def, flea.cat, flea.sub)
				and (q == "" or string.find(string.lower(def.name), q, 1, true) ~= nil or string.find(string.lower(def.short or ""), q, 1, true) ~= nil)
		end
		if show then
			for _, o in offers do
				order += 1
				if order > ROW_MAX then
					break
				end
				local r, pw = itemRow(list, order, id, def.name, true)
				r.Name = "Offer_" .. id .. "_" .. tostring(o.k or o.i)
				if gated then
					r.BackgroundTransparency = 0.6
				end
				K.label(r, CAT[def.kind] .. "  ·  AVG " .. Util.commas(FR.marketPrice(id)) .. (o.mine and "  ·  YOUR OFFER" or ""), 11, { Position = UDim2.fromOffset(pw + 10, 22), Size = UDim2.fromOffset(340, 16), TextColor3 = o.mine and K.C.ochre or K.C.dim })
				-- EFT's "Trader (rating)" column: the seller's name and flea rating
				cell(r, string.format("%s (%s)", o.seller or "?", ratingText(o.r)), 446, 150, gated and K.C.dim or K.C.text)
				cell(r, o.left > 0 and ("x" .. o.left) or "SOLD OUT", 606, 90, gated and K.C.dim or (o.left > 0 and K.C.text or K.C.red))
				-- a price per item, or EFT's "per pack (N items)" for an offer sold whole
				cell(r, Util.commas(o.price) .. " " .. Config.CURRENCY .. (o.pk and ("  PER PACK (" .. o.left .. ")") or ""), 706, 190, gated and K.C.dim or K.C.ochre)
				if gated then
					K.label(r, "REQUIRES LEVEL " .. need, 12, {
						Name = "Locked", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(140, 30),
						TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = K.C.orange,
					})
				elseif o.left > 0 and not o.mine then
					local b = K.button(r, "PURCHASE", { Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(100, 30), TextSize = 12 })
					b.Activated:Connect(function()
						local n = o.pk and o.left or math.clamp(math.floor(tonumber(flea.qty) or 1), 1, o.left)
						task.spawn(function()
							-- a player's offer by its id, an operator's by its number; the price seen goes along so a changed
							-- offer is refused rather than bought dearer. If someone bought it first the server says so and
							-- the list is asked for again.
							ctx.State.req("flea", { op = "buy", id = id, k = o.k, i = (not o.k) and o.i or nil, n = n, price = o.unit or o.price })
							flea.at = 0
							refresh()
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

local STATE_TEXT = { new = "GOING UP", ended = "ENDED  ·  COMES BACK AFTER THE RAID" }
local function mine(f, x, y, w, h, d, fl)
	local list = scroller(f, x, y, w, h - 30, "FleaMine")
	local order = 0
	for _, o in fl.offers or {} do
		local def = Items.defs[o.id]
		if def then
			order += 1
			local units = (o.n0 or 1) > 1 and string.format("  %d / %d", o.n or 0, o.n0) or ""
			local r = itemRow(list, order, o.id, def.name .. units, true)
			r.Name = "Mine_" .. o.k
			cell(r, Util.commas(o.price) .. " " .. Config.CURRENCY .. (o.pk and "  PER PACK" or ((o.n0 or 1) > 1 and "  EACH" or "")), 446, 170, K.C.ochre)
			local status = STATE_TEXT[o.st] or (o.st == "removing" and ("REMOVING  ·  ENDS IN " .. timeLeft(o.left)) or ("EXPIRES IN " .. timeLeft(o.left)))
			cell(r, status, 626, 230, o.st == "removing" and K.C.orange or K.C.dim)
			if o.st == "open" then
				local b = K.button(r, "REMOVE", { Name = "Remove", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(100, 30), TextSize = 12 })
				b.Activated:Connect(function()
					task.spawn(function()
						ctx.State.req("flea", { op = "remove", k = o.k })
					end)
				end)
			end
		end
	end
	-- returned items (and purchases) that found no room in the stash: they wait here 72 h (EFT keeps them on Ragman's
	-- message that long)
	for _, b in fl.back or {} do
		local def = Items.defs[b.id]
		if def then
			order += 1
			local r = itemRow(list, order, b.id, def.name .. ((b.n or 1) > 1 and ("  x" .. b.n) or ""), true)
			r.Name = "Back_" .. b.k
			cell(r, "WAITING FOR STASH ROOM", 446, 170, K.C.orange)
			cell(r, "COLLECT WITHIN " .. timeLeft(b.left), 626, 230, b.left < 3600 and K.C.orange or K.C.dim)
			local btn = K.button(r, "RECEIVE", { Name = "Receive", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(100, 30), TextSize = 12, TextColor3 = K.C.green })
			btn.Activated:Connect(function()
				task.spawn(function()
					ctx.State.req("flea", { op = "receive", k = b.k })
				end)
			end)
		end
	end
	if order == 0 then
		K.label(list, "You have no offers. ADD OFFER puts a found-in-raid item from your stash on the market.", 12, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), TextColor3 = K.C.dim })
	end
	K.label(f, "Players on every server can buy your offers; operators buy only the cheapest at a fair price. Sales are paid by message from TILDA, even while you are away. Offers run 12 hours; REMOVE ends one 72 s later. An offer that ends unsold costs rating; the fee is not returned.", 11, {
		Position = UDim2.fromOffset(x, y + h - 26), Size = UDim2.fromOffset(w - 20, 26), TextColor3 = K.C.dim, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
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
		local can, whyNot = FR.listable(it.id, it.n or 1)
		local why = (not can and whyNot == "FULL_STACK") and ("ONLY FULL STACKS (" .. def.stack .. ")")
			or (not can) and "CAN'T BE OFFERED"
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
				flea.sel, flea.price, flea.pack = g, nil, false
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
	local pack = flea.pack and n > 1
	-- the competition for this item now (the cheapest and the dearest offer of one unit, your own left out), asked for
	-- once when the item is chosen
	flea.peek = flea.peek or {}
	local pk = flea.peek[it.id]
	if not pk or os.clock() - pk.at > 30 then
		flea.peek[it.id] = { at = os.clock() }
		task.spawn(function()
			local res = ctx.State.req("flea", { op = "market", ids = { it.id } })
			local lo, hi = nil, nil
			for _, o in (res.ok and res.data and res.data.offers[it.id]) or {} do
				if not o.mine and (o.left or 0) > 0 then
					lo = math.min(lo or math.huge, o.unit or o.price)
					hi = math.max(hi or 0, o.unit or o.price)
				end
			end
			flea.peek[it.id] = { at = os.clock(), lo = lo, hi = hi }
			if flea.sel and d.items[flea.sel] and d.items[flea.sel].id == it.id then
				refresh()
			end
		end)
		pk = flea.peek[it.id]
	end
	local unitAvg = FR.marketPrice(it.id)
	local price = flea.price or (pack and unitAvg * n or unitAvg)
	local panel = K.frame(f, { Name = "OfferPanel", BackgroundColor3 = K.C.panel, BackgroundTransparency = 0.2, Position = UDim2.fromOffset(px, y), Size = UDim2.fromOffset(pw, 340) })
	K.pad(panel, 12)
	K.label(panel, def.name .. (n > 1 and ("  x" .. n) or ""), 16, { Size = UDim2.new(1, 0, 0, 22), FontFace = K.bold })
	local market = "AVERAGE PRICE  " .. Util.commas(unitAvg) .. " " .. Config.CURRENCY .. (n > 1 and " EACH" or "")
	if pk.lo then
		market ..= "  ·  CHEAPEST NOW  " .. Util.commas(math.floor(pk.lo)) .. (n > 1 and " EACH" or "")
	end
	K.label(panel, market, 13, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 18), TextColor3 = K.C.dim, TextTruncate = Enum.TextTruncate.AtEnd })
	K.label(panel, pack and "PRICE PER PACK" or (n > 1 and "PRICE EACH" or "YOUR PRICE"), 13, { Position = UDim2.fromOffset(0, 60), Size = UDim2.fromOffset(120, 28) })
	local box = K.new("TextBox", {
		Name = "FleaPrice", Position = UDim2.fromOffset(120, 60), Size = UDim2.fromOffset(180, 28), Text = tostring(price), ClearTextOnFocus = false,
		TextSize = 14, FontFace = K.font, TextColor3 = K.C.ochre, BackgroundColor3 = K.C.panel2, BorderSizePixel = 0,
	}, panel)
	if n > 1 then
		-- EFT's "List as a pack": one price for the whole stack, bought whole
		local t = K.button(panel, pack and "LIST AS A PACK: ON" or "LIST AS A PACK: OFF", {
			Name = "FleaPack", Position = UDim2.fromOffset(310, 60), Size = UDim2.fromOffset(170, 28), TextSize = 12,
			BackgroundColor3 = pack and Color3.fromHex("3A3524") or K.C.panel2, TextColor3 = pack and K.C.ochre or K.C.dim,
		})
		t.Activated:Connect(function()
			local v = math.floor(tonumber(box.Text) or 0)
			flea.pack = not pack
			if v >= 1 then
				flea.price = flea.pack and v * n or math.max(1, math.floor(v / n))
			end
			refresh()
		end)
	end
	local totalL = K.label(panel, "", 13, { Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 18) })
	local feeL = K.label(panel, "", 13, { Position = UDim2.fromOffset(0, 118), Size = UDim2.new(1, 0, 0, 18) })
	local warnL = K.label(panel, "", 11, { Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, 0, 0, 30), TextWrapped = true, TextColor3 = K.C.orange })
	local function update()
		local v = math.floor(tonumber(box.Text) or 0)
		if v >= 1 then
			flea.price = v
			local total = pack and v or v * n
			local unit = total / n
			local hd = d and d.hideout
			local fee = math.floor(FR.fee(def.value or 0, n, total) * (1 - (hd and HD.bonus(hd, "fleaFee", hd.power) or 0) / 100))
			totalL.Text = "TOTAL  " .. Util.commas(total) .. " " .. Config.CURRENCY
			feeL.Text = "LISTING FEE  " .. Util.commas(fee) .. " " .. Config.CURRENCY
			-- EFT's warnings (locale ragfair/TooLittleWarning, TooMuchWarning); the half and double are ours
			if pk.lo and unit < pk.lo * 0.5 then
				warnL.Text = "You are going to put the item at a cost much lower than the cheapest existing similar offer."
			elseif pk.hi and unit > pk.hi * 2 then
				warnL.Text = "You are going to place an item at a cost much higher than the most expensive existing similar offer."
			else
				warnL.Text = ""
			end
		else
			totalL.Text, feeL.Text, warnL.Text = "TOTAL  -", "LISTING FEE  -", ""
		end
	end
	box:GetPropertyChangedSignal("Text"):Connect(update)
	update()
	local used = #(fl.offers or {})
	local limit = FR.LIST_LIMIT[it.id]
	K.label(panel, string.format("OFFERS  %d / %d  ·  RATING %.2f", used, fl.slots or 2, fl.rating or 0.2) .. (limit and ("  ·  LISTING LIMIT " .. limit) or ""), 12, { Position = UDim2.fromOffset(0, 176), Size = UDim2.new(1, 0, 0, 18), TextColor3 = K.C.dim })
	K.label(panel, "The fee is paid now and not returned. The offer runs 12 hours on every server; REMOVE ends it 72 s later. If it ends unsold, your rating falls with its value.", 11, { Position = UDim2.fromOffset(0, 200), Size = UDim2.new(1, 0, 0, 44), TextWrapped = true, TextColor3 = K.C.dim })
	local place = K.button(panel, "PLACE OFFER", { Name = "PlaceOffer", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(180, 36), TextColor3 = K.C.green })
	place.Activated:Connect(function()
		update()
		local g, v = flea.sel, flea.price
		task.spawn(function()
			local res = ctx.State.req("flea", { op = "list", g = g, price = v, pk = pack or nil })
			if res.ok or res.code == "PENDING" then
				flea.view, flea.sel, flea.price, flea.pack = "mine", nil, nil, false
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
