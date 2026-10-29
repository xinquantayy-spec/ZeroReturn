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
local P = require(Shared.Progress)

local Trade = { open = nil }
local ctx, K
local ui = { tab = "vos", scroll = {} }
local live = {} -- { label, at (server os.time), fmt }
local dirty = false

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
	local nextL = TD.LL[st.ll + 1]
	if not nextL then
		return string.format("LOYALTY %d (MAX)  ·  STANDING %.2f", st.ll, st.rep or 0)
	end
	return string.format("LOYALTY %d  ·  NEXT: LEVEL %d (%d) · %s MK TRADED (%s) · STANDING %.2f (%.2f)",
		st.ll, nextL.level, econ.level or 1, Util.commas(nextL.spent), Util.commas(math.floor(st.spent or 0)), nextL.rep, st.rep or 0)
end

local function traderPanel(f, x, y, w, h, d, tid)
	local econ = d.econ or {}
	local st = econ.traders and econ.traders[tid] or { ll = 1 }
	local tr = TD.defs[tid]
	local lw = math.floor(w * 0.56)
	local left = scroller(f, x, y, lw, h, "Shop_" .. tid)
	local right = scroller(f, x + lw + 12, y, w - lw - 12, h, "Tasks_" .. tid)
	text(left, tr.title .. ".  " .. tr.desc, K.C.dim, 12)
	text(left, loyaltyText(econ, tid), K.C.text, 11)
	section(left, "FOR SALE")
	for i, o in TD.offers[tid] or {} do
		local def = Items.defs[o.id]
		local locked = o.ll > st.ll
		local left_ = o.limit - ((econ.bought and econ.bought[tid .. ":" .. i]) or 0)
		local price = TD.price(tid, o, st.ll)
		local info = locked and ("LOYALTY " .. o.ll) or string.format("%s %s  ·  %d LEFT", Util.commas(price), Config.CURRENCY, math.max(0, left_))
		local can = not locked and left_ > 0 and (d.money or 0) >= price
		-- a gun sold as a preset shows the preset's name and its build (Tarkov's trader presets)
		local oname = o.preset and WP.PRESET_NAMES[o.preset] or def.name
		local _, b = row(left, oname .. ((o.n > 1) and (" x" .. o.n) or ""), info, locked and "LOCKED" or (left_ > 0 and "BUY" or "SOLD OUT"), can, function()
			req("trade", { op = "buy", trader = tid, i = i })
		end, (not locked and (d.money or 0) < price) and K.C.red or nil, o.preset and (o.id .. "#" .. o.preset) or o.id)
		if b then
			b.Name = "Buy_" .. o.id
		end
	end
	if #(TD.barters[tid] or {}) > 0 then
		section(left, "BARTER")
		for i, bt in TD.barters[tid] do
			local def = Items.defs[bt.id]
			local locked = bt.ll > st.ll
			local used = (econ.bought and econ.bought["b:" .. tid .. ":" .. i]) or 0
			local parts, ok = {}, true
			for _, need in bt.give do
				local n = stashCount(d, need[1])
				ok = ok and n >= need[2]
				table.insert(parts, Items.defs[need[1]].short .. " " .. have(n, need[2]))
			end
			row(left, def.name, locked and ("LOYALTY " .. bt.ll) or table.concat(parts, "  "), locked and "LOCKED" or (used < bt.limit and "TRADE" or "SOLD OUT"), ok and not locked and used < bt.limit, function()
				req("trade", { op = "barter", trader = tid, i = i })
			end, nil, bt.id)
		end
	end
	text(left, "Sell from your stash: right-click (or select) an item and choose SELL. The best-paying trader buys it.", K.C.dim, 11)
	-- tasks
	section(right, "TASKS")
	local any = false
	for _, q in QD.list do
		if q.trader == tid then
			any = true
			local qs = (d.quests and d.quests[q.id]) or { s = "locked", p = {} }
			local statusText = ({ locked = "LOCKED", available = "AVAILABLE", active = "ACTIVE", claimed = "COMPLETED" })[qs.s] or qs.s
			local color = ({ locked = K.C.dim, available = K.C.ochre, active = K.C.green, claimed = K.C.dim })[qs.s] or K.C.text
			text(right, string.upper(q.name) .. "   ·   " .. statusText, color, 13, true)
			if qs.s == "locked" then
				local why = {}
				if (econ.level or 1) < (q.level or 1) then
					table.insert(why, "level " .. q.level)
				end
				if q.after then
					table.insert(why, "after " .. QD.byId[q.after].name)
				end
				text(right, "Requires " .. table.concat(why, ", ") .. ".", K.C.dim, 11)
			else
				text(right, q.desc, K.C.dim, 11)
				local complete = true
				for i, o in q.obj do
					local p = (qs.p and qs.p[i]) or 0
					if qs.s == "claimed" then
						p = o.n
					end
					complete = complete and p >= o.n
					local what = QD.describe(o)
					if o.kind == "handin" then
						what = what .. ": " .. Items.defs[o.item].name
					end
					text(right, string.format("  •  %s   %s", what, (qs.s == "available") and ("x" .. o.n) or have(p, o.n)), K.C.text, 11)
				end
				local r = q.reward or {}
				local rew = { Util.commas(r.money or 0) .. " " .. Config.CURRENCY, (r.xp or 0) .. " XP" }
				if r.rep then
					table.insert(rew, string.format("+%.2f standing", r.rep))
				end
				if r.karma then
					table.insert(rew, string.format("+%.1f karma", r.karma))
				end
				for _, e in r.items or {} do
					table.insert(rew, Items.defs[e[1]].name .. ((e[2] or 1) > 1 and (" x" .. e[2]) or ""))
				end
				text(right, "  REWARD  " .. table.concat(rew, "  ·  "), K.C.green, 11)
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
	end
	if not any then
		text(right, "No tasks.", K.C.dim)
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
		text(sf, string.format("%s  ·  LEVEL %d%s  ·  %s", def.name, sl, sl >= 10 and " (ELITE)" or string.format(" (%d/100)", math.floor(pts % 100)), def.desc), K.C.text, 12)
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

function Trade.traders(tab)
	local d = data()
	if not d or ctx.State.inRaid() then
		return
	end
	ui.tab = tab or ui.tab
	order = 0
	table.clear(live)
	local f, w, h = ctx.Screens.openModal(980, 600, "RELAY RADIO  //  TRADERS")
	Trade.open = "traders"
	Trade.frame = f
	local econ = d.econ or {}
	local lvl = econ.level or 1
	K.label(f, string.format("LEVEL %d  ·  %s / %s XP  ·  %s %s", lvl, Util.commas(econ.xp or 0), Util.commas(P.xpFor(lvl + 1)), Util.commas(d.money or 0), Config.CURRENCY), 12, {
		Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -180, 0, 18), TextColor3 = K.C.dim,
	})
	local restock = K.label(f, "", 12, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 26), Size = UDim2.fromOffset(180, 18), TextColor3 = K.C.dim, TextXAlignment = Enum.TextXAlignment.Right })
	-- restockIn is relative to the snapshot's server time; when it runs out, ask for fresh stock counts
	table.insert(live, { label = restock, at = (d.serverTime or os.time()) + (econ.restockIn or 0), fmt = "RESTOCK IN %s", onDone = function()
		ctx.State.req("sync", {})
	end })
	local tabs = K.frame(f, { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 32) })
	K.list(tabs, Enum.FillDirection.Horizontal, 6)
	local first
	for _, id in { "vos", "hale", "tilda", "fence", "profile" } do
		local st = econ.traders and econ.traders[id]
		local label = (id == "profile") and "PROFILE" or string.format("%s  ·  LL%d", TD.defs[id].name, st and st.ll or 1)
		local sel = ui.tab == id
		local b = K.button(tabs, label, {
			Size = UDim2.fromOffset(math.min(170, math.floor((w - 24) / 5)), 32), TextSize = 13,
			BackgroundColor3 = sel and Color3.fromHex("3A3524") or K.C.panel2, TextColor3 = sel and K.C.ochre or K.C.dim,
		})
		b.Name = "Tab_" .. string.upper(id)
		b.Activated:Connect(function()
			if ui.tab ~= id then
				Trade.traders(id)
			end
		end)
		if sel then
			first = b
		end
	end
	local top = 88
	local bodyH = h - top - 42
	if ui.tab == "profile" then
		profilePanel(f, 0, top, w, bodyH, d)
	else
		traderPanel(f, 0, top, w, bodyH, d, ui.tab)
	end
	local close = K.button(f, "CLOSE", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(140, 34) })
	close.Activated:Connect(ctx.Screens.close)
	K.focus(first)
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
	K.focus(close)
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
