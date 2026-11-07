--!nonstrict
-- Modal screens: deployment order, post-raid dossier, settings, exits list. Gamepad focus + Back support.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local Env = require(Shared.Env)
local Maps = require(Shared.Maps)

local Screens = { modal = nil }
local ctx, K
local gui, exitGui

local function closeModal()
	if ctx.Inspect then
		ctx.Inspect.closeAll()
	end
	if Screens.modal then
		Screens.modal:Destroy()
		Screens.modal = nil
		ctx.Input.setMenu(false)
		ctx.Interact.setEnabled(true)
		pcall(function()
			GuiService.SelectedObject = nil
		end)
	end
end
Screens.close = closeModal

local function modal(w, h, title)
	-- the same screen drawn again keeps the gamepad selection where it was; a tab change (Screens.tabSwitch) lands on
	-- the new tab instead (audit ui.5)
	local keep = nil
	local same = Screens.modal ~= nil and Screens.title == title
	if same and not Screens.tabSwitch then
		keep = ctx.Input.focusPath(Screens.modal)
	end
	Screens.switched = Screens.tabSwitch == true -- the builder picks the open tab as its focus then
	Screens.tabSwitch = false
	if same then
		-- drawn again in place (new server state, a setting changed): inspect windows opened over it stay open
		Screens.modal:Destroy()
		Screens.modal = nil
	else
		closeModal()
	end
	Screens.keep, Screens.title, Screens.kind, Screens.focusDefault = keep, title, nil, nil
	if ctx.Inventory.open then
		ctx.Inventory.close()
	end
	local vp = K.viewport(gui)
	-- ui-3a: a phone (under 500 pt of height) gets the whole screen with a thin margin
	local phone = vp.Y < 500
	w = phone and vp.X or math.min(w, vp.X - 16)
	h = phone and vp.Y or math.min(h, vp.Y - 12)
	local pad = phone and 6 or 14
	local f = K.frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h), BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.03 })
	K.stroke(f, K.C.line, 0.4)
	K.pad(f, pad)
	K.label(f, title, 17, { FontFace = K.bold, Size = UDim2.new(1, 0, 0, phone and 36 or 24), TextYAlignment = phone and Enum.TextYAlignment.Center or nil })
	f.Name = "Modal"
	Screens.modal = f
	ctx.Input.setMenu(true)
	ctx.Interact.setEnabled(false)
	return f, w - 2 * pad, h - 2 * pad
end
Screens.openModal = modal

-- the gamepad selection for the screen just drawn (audit ui.5): only while a pad is in use; the control the player was
-- on when it was drawn again in place, else `default` (the open tab, or the screen's main button)
function Screens.focus(default)
	Screens.focusDefault = default
	if Screens.modal then
		ctx.Input.refocus(Screens.modal, Screens.keep, default)
	end
	Screens.keep = nil
end

local function line(parent, y, text, color, size)
	return K.label(parent, text, size or 13, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, (size or 13) + 6), TextColor3 = color or K.C.text, TextWrapped = true })
end

-- plain-text raid cycle status for UI panels (the HUD draws the same through the lens)
local function matchText(m)
	local now = workspace:GetServerTimeNow()
	if not m then
		return "CONNECTING TO THE RAID SERVER...", K.C.dim
	end
	local function t(sec)
		return Util.clock(math.max(0, sec))
	end
	-- the raid's local time and weather (Tarkov shows both before you go in)
	local function conditions()
		local e = m.env
		if not e then
			return ""
		end
		if m.state == "MATCHING" then
			local w = Env.WEATHER[e.w] or Env.WEATHER.clear
			local snowy = e.season == "winter" and e.w == "rain"
			return string.format("\nINSERTION AT %02d:%02d LOCAL  ·  %s  ·  %s", math.floor(e.clock0), math.floor((e.clock0 % 1) * 60), snowy and "SNOW" or w.name, Env.SEASONS[e.season or "summer"] and Env.SEASONS[e.season or "summer"].name or "SUMMER")
		end
		return "\n" .. Maps.nameOf(m.map) .. " LOCAL TIME " .. Env.label(e, now)
	end
	if m.state == "MATCHING" then
		return string.format("%s  ·  INSERTION IN %s  ·  %d QUEUED", m.queued and "YOU ARE QUEUED" or "RAID FORMING", t(m.startsAt - now), m.inQueue or 0) .. conditions(), K.C.ochre
	elseif m.state == "RUNNING" then
		-- player scavs enter in EFT's window (audit ai-7a): from scavFrom (17 minutes in on the big maps) to scavUntil
		local scavText = now < (m.scavFrom or 0) and ("SCAV ENTRY OPENS IN " .. t(m.scavFrom - now)) or ("SCAV ENTRY OPEN FOR " .. t((m.scavUntil or 0) - now))
		if m.queued == "scav" and now < (m.scavFrom or 0) then
			return "QUEUED AS SCAV  ·  " .. scavText, K.C.ochre
		elseif m.queued then
			return "QUEUED FOR THE NEXT RAID  ·  CURRENT RAID ENDS IN " .. t(m.endsAt - now), K.C.ochre
		end
		local s = string.format("RAID IN PROGRESS  ·  %s LEFT  ·  %d/%d INSIDE", t(m.endsAt - now), m.inRaid or 0, m.maxPlayers or Config.MAX_PLAYERS) .. conditions()
		if now < (m.lateUntil or 0) then
			s ..= "\nPMC ENTRY OPEN FOR " .. t(m.lateUntil - now) .. "  ·  " .. scavText
		elseif now < (m.scavUntil or 0) then
			s ..= "\nPMC ENTRY CLOSED (NEXT RAID)  ·  " .. scavText
		else
			s ..= "\nENTRY CLOSED  ·  DEPLOYING NOW QUEUES FOR THE NEXT RAID"
		end
		return s, K.C.orange
	end
	return "NO RAID IN PROGRESS  ·  DEPLOYING STARTS ONE (" .. Config.MATCH_TIME .. " S TO GATHER THE QUEUE)", K.C.green
end
Screens.matchText = matchText

local deployMode = "pmc"
local deployVote = nil -- map this player votes for (nil = any map)
-- the map you picked at the ops table (the van takes it with your boarding)
function Screens.vote()
	return deployVote
end

local function scroller(parent, x, y, w, h)
	local sf = K.new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Selectable = false,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
	K.list(sf, nil, 4)
	return sf
end

local function para(parent, order, text, color, size, bold)
	return K.label(parent, text, size or 13, {
		LayoutOrder = order, TextColor3 = color or K.C.text, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, (size or 13) + 4), FontFace = bold and K.bold or K.font,
	})
end

-- Deployment terminal: PMC (your gear) or SCAV (free kit, cooldown), the server's raid status, insurance,
-- and the squad panel. Deploying joins the running raid while its entry window is open, otherwise the queue.
function Screens.deploy()
	local d = ctx.State.data
	if not d or ctx.State.inRaid() then
		return
	end
	local f, w, h = modal(820, 500, "OPS TABLE  ·  DEPLOYMENT")
	Screens.kind = "deploy"
	local me = Players.LocalPlayer
	local mode = deployMode
	-- mode tabs
	local tabs = K.frame(f, { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 34) })
	K.list(tabs, Enum.FillDirection.Horizontal, 8)
	local scavTabBtn, openTab
	for _, tb in { { "pmc", "PMC  ·  YOUR GEAR" }, { "scav", "SCAV  ·  FREE KIT" } } do
		local sel = mode == tb[1]
		local b = K.button(tabs, tb[2], {
			Size = UDim2.fromOffset(math.min(220, (w - 8) / 2), 34), TextSize = 14,
			BackgroundColor3 = sel and Color3.fromHex("3A3524") or K.C.panel2, TextColor3 = sel and K.C.ochre or K.C.dim,
		})
		b.Name = "Tab_" .. string.upper(tb[1])
		b.Activated:Connect(function()
			if deployMode ~= tb[1] then
				deployMode = tb[1]
				Screens.deploy()
			end
		end)
		if tb[1] == "scav" then
			scavTabBtn = b
		end
		if sel then
			openTab = b
		end
	end
	-- columns (two side by side when there is room, else stacked)
	local top, bottomH = 70, 46
	local bodyH = h - top - bottomH - 6
	local two = w >= 600
	local lw = two and math.floor((w - 14) * 0.55) or w
	local rw = two and (w - 14 - lw) or w
	local left = scroller(f, 0, top, lw, two and bodyH or math.floor(bodyH * 0.55))
	local right = scroller(f, two and (lw + 14) or 0, two and top or (top + math.floor(bodyH * 0.55) + 6), rw, two and bodyH or (bodyH - math.floor(bodyH * 0.55) - 6))
	left.Name = "Left"
	right.Name = "Right"
	local live = {} -- labels refreshed every tick
	local n = 0
	local function L(text, color, size, bold)
		n += 1
		return para(left, n, text, color, size, bold)
	end
	if mode == "pmc" then
		local value, mags, rounds, meds = 0, 0, 0, 0
		local function walk(g, depth)
			local it = d.items[g]
			if not it or depth > 6 then
				return
			end
			local def = Items.defs[it.id]
			value += Items.valueOf(it)
			if def.kind == "mag" then
				mags += 1
				rounds += it.a or 0
			elseif def.kind == "med" then
				meds += 1
			end
			if it.mag then
				walk(it.mag, depth + 1)
			end
			for _, mg in it.mods or {} do
				walk(mg, depth + 1)
			end
			for cg in (d.grids and d.grids[g]) or {} do
				walk(cg, depth + 1)
			end
		end
		for _, g in d.slots do
			walk(g, 0)
		end
		for g in (d.grids and d.grids.pockets) or {} do
			walk(g, 0)
		end
		local function slotName(slot)
			local g = d.slots[slot]
			local it = g and d.items[g]
			return it and Items.defs[it.id].name or "-"
		end
		L("LOADOUT", K.C.ochre, 13, true)
		L("PRIMARY   " .. slotName("primary") .. "\nHOLSTER   " .. slotName("holster"), d.slots.primary and K.C.text or K.C.orange, 13)
		L("ARMOR     " .. slotName("armor") .. "\nHELMET    " .. slotName("head"), K.C.text, 13)
		L("RIG       " .. slotName("rig") .. "\nBACKPACK  " .. slotName("back"), K.C.text, 13)
		L(string.format("SPARE     %d magazines · %d rounds · %d medical", mags, rounds, meds), K.C.dim, 12)
		L(string.format("AT RISK   %s %s", Util.commas(value), Config.CURRENCY), K.C.ochre, 15, true)
		L("Everything you wear and carry is lost if you are killed or miss extraction - except your secure container.", K.C.dim, 12)
		-- insurance
		local q = d.insureAll or { cost = 0, n = 0, insured = 0 }
		L("INSURANCE", K.C.ochre, 13, true)
		L(string.format("%d item(s) insured. Unlooted insured gear is returned %d min after the raid ends.", q.insured or 0, math.floor(Config.INSURANCE_DELAY / 60)), K.C.dim, 12)
		if (q.n or 0) > 0 then
			n += 1
			local ib = K.button(left, string.format("INSURE %d MORE  ·  %s %s", q.n, Util.commas(q.cost), Config.CURRENCY), { LayoutOrder = n, Size = UDim2.new(1, -8, 0, 32), TextSize = 13, TextColor3 = (d.money or 0) >= q.cost and K.C.green or K.C.dim })
			ib.Name = "Btn_INSUREALL"
			ib.Activated:Connect(function()
				local res = ctx.State.req("inv", { op = "insure", all = true })
				if res and res.ok then
					task.wait(0.25)
					Screens.deploy()
				end
			end)
		end
		local cl = d.claims
		if cl and (cl.waiting > 0 or cl.ready > 0) then
			local txt = cl.ready > 0 and string.format("%d RETURNED ITEM(S) WAITING FOR STASH SPACE", cl.ready) or string.format("%d ITEM(S) RETURNING IN %s", cl.waiting, Util.clock(cl.nextIn or 0))
			L("RETURNS   " .. txt, K.C.green, 12)
		end
	else
		L("PLAYER SCAV", K.C.ochre, 13, true)
		L("You go in as a local with a random kit: a cheap gun, a little ammo, some meds and junk. Your PMC, stash and health are never at risk.", K.C.text, 13)
		L("Everything you carry out goes to your stash (what doesn't fit is sold). Die or miss extraction and the kit is simply gone.", K.C.dim, 12)
		L(string.format("Scavs can use every exfil, including scav-only routes. Cooldown: %d min after each insertion.", math.floor(Config.SCAV_COOLDOWN / 60)), K.C.dim, 12)
		live.scav = L("", K.C.green, 15, true)
	end
	-- right column: raid status + squad
	local rn = 0
	local function R(text, color, size, bold)
		rn += 1
		return para(right, rn, text, color, size, bold)
	end
	-- map vote (M13): queued players vote for the next raid's map; most votes win, a tie is random
	R("MAP", K.C.ochre, 13, true)
	rn += 1
	local mapBox = K.frame(right, { Name = "Maps", LayoutOrder = rn, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -8, 0, 0) })
	K.list(mapBox, nil, 4)
	local mapSig = nil
	local function mapSignature()
		local m = ctx.State.match or {}
		local parts = { tostring(m.state), tostring(m.map), tostring(m.vote), tostring(deployVote), tostring(m.queued), table.concat(m.maps or {}, ",") }
		for _, id in Maps.order do
			table.insert(parts, tostring((m.votes or {})[id]))
		end
		return table.concat(parts, "|")
	end
	local function drawMaps()
		for _, c in mapBox:GetChildren() do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		local m = ctx.State.match or {}
		local k = 0
		local function info(text, color)
			k += 1
			K.label(mapBox, text, 12, { LayoutOrder = k, TextColor3 = color or K.C.dim, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 16) })
		end
		if m.state == "RUNNING" then
			info("RAID IN PROGRESS ON " .. Maps.nameOf(m.map) .. ". Joining now goes there; queueing votes for the next raid.", K.C.text)
		end
		local mine = m.queued and m.vote or deployVote
		local votes = m.votes or {}
		local function choice(id, label)
			k += 1
			local sel = mine == id
			local b = K.button(mapBox, label, {
				LayoutOrder = k, Size = UDim2.new(1, 0, 0, 28), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundColor3 = sel and Color3.fromHex("3A3524") or K.C.panel2, TextColor3 = sel and K.C.ochre or K.C.text,
			})
			b.Name = "Map_" .. string.upper(id or "ANY")
			b.Activated:Connect(function()
				deployVote = id
				if (ctx.State.match or {}).queued then
					local res = ctx.State.req("queue", { op = "vote", map = id })
					if res and res.ok and res.data then
						ctx.State.match = res.data
						ctx.State.matchClock = os.clock()
					end
				end
				mapSig = nil
			end)
		end
		-- only the maps this server runs (a lean server builds one, tech-4b); an older server sends no list: every map
		local here = nil
		if type(m.maps) == "table" then
			here = {}
			for _, id in m.maps do
				here[id] = true
			end
		end
		for _, id in Maps.order do
			local def = Maps.defs[id]
			local n = votes[id] or 0
			if here == nil or here[id] then
				choice(id, string.format("  %s  ·  %s  ·  %d MIN%s", def.name, def.kind, math.floor(def.raidTime / 60), n > 0 and string.format("  ·  %d VOTE%s", n, n == 1 and "" or "S") or ""))
			end
		end
		choice(nil, "  ANY MAP")
		local def = mine and Maps.defs[mine]
		info(def and def.desc or "No vote: the queue's votes decide, a tie is settled at random.")
	end
	R("RAID ON THIS SERVER", K.C.ochre, 13, true)
	live.match = R("", K.C.text, 12)
	R(string.format("Up to %d operators · PMCs, player scavs and the locals share one map per raid.", Config.MAX_PLAYERS), K.C.dim, 11)
	rn += 1
	local squadBox = K.frame(right, { Name = "Squad", LayoutOrder = rn, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -8, 0, 0) })
	K.list(squadBox, nil, 4)
	local squadSig = nil
	local function drawSquad()
		for _, c in squadBox:GetChildren() do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		local sq = ctx.State.squad
		local members = sq and sq.members or {}
		local inSquad = {}
		local amLeader = false
		local k = 0
		local function row(text, color, btnText, onClick, btnColor)
			k += 1
			if not btnText then
				-- information line: wraps instead of truncating
				K.label(squadBox, text, 12, { LayoutOrder = k, TextColor3 = color or K.C.text, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 16) })
				return
			end
			local r = K.frame(squadBox, { BackgroundTransparency = 1, LayoutOrder = k, Size = UDim2.new(1, 0, 0, 30) })
			K.label(r, text, 12, { Size = UDim2.new(1, btnText and -104 or 0, 1, 0), TextColor3 = color or K.C.text, TextTruncate = Enum.TextTruncate.AtEnd })
			if btnText then
				local b = K.button(r, btnText, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(98, 26), TextSize = 12, TextColor3 = btnColor or K.C.text })
				b.Activated:Connect(onClick)
			end
		end
		k += 1
		K.label(squadBox, "SQUAD" .. ((sq and sq.color) and "  ·  ARMBAND" or ""), 13, { LayoutOrder = k, FontFace = K.bold, TextColor3 = (sq and sq.color) and Color3.fromHex(sq.color) or K.C.ochre, Size = UDim2.new(1, 0, 0, 20) })
		for _, m in members do
			inSquad[m.id] = true
			if m.id == me.UserId and m.leader then
				amLeader = true
			end
		end
		if #members == 0 then
			row("Solo. Invite operators below - squads insert together and share an armband colour.", K.C.dim)
		end
		for _, m in members do
			local label = string.upper(m.name) .. (m.leader and " (LEAD)" or "") .. "  ·  " .. (m.status or "")
			if m.id == me.UserId then
				row(label, K.C.ochre, "LEAVE", function()
					ctx.State.req("squad", { op = "leave" })
				end, K.C.orange)
			elseif amLeader then
				row(label, K.C.text, "KICK", function()
					ctx.State.req("squad", { op = "kick", target = m.id })
				end, K.C.orange)
			else
				row(label, K.C.text)
			end
		end
		k += 1
		K.label(squadBox, "OPERATORS ON THIS SERVER", 13, { LayoutOrder = k, FontFace = K.bold, TextColor3 = K.C.ochre, Size = UDim2.new(1, 0, 0, 20) })
		local others = 0
		for _, p in Players:GetPlayers() do
			if p ~= me and not inSquad[p.UserId] then
				others += 1
				row(string.upper(p.DisplayName), K.C.text, "INVITE", function()
					local res = ctx.State.req("squad", { op = "invite", target = p.UserId })
					if res and res.ok then
						ctx.State.toast("INVITE SENT TO " .. string.upper(p.DisplayName), "good")
					end
				end, K.C.green)
			end
		end
		if others == 0 then
			row("Nobody else is on this server right now.", K.C.dim)
		end
	end
	local function squadSignature()
		local parts = {}
		for _, m in (ctx.State.squad and ctx.State.squad.members) or {} do
			table.insert(parts, m.id .. (m.status or "") .. (m.leader and "L" or ""))
		end
		for _, p in Players:GetPlayers() do
			table.insert(parts, "p" .. p.UserId)
		end
		return table.concat(parts, ",")
	end
	-- bottom row
	local row = K.frame(f, { Name = "Row", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 40) })
	K.list(row, Enum.FillDirection.Horizontal, 10)
	local deploy = K.button(row, "DEPLOY", { Size = UDim2.fromOffset(math.min(230, w * 0.36), 40), BackgroundColor3 = Color3.fromHex("3A3524"), TextColor3 = K.C.ochre, TextSize = 15 })
	deploy.Name = "Btn_DEPLOY"
	if mode == "pmc" then
		local edit = K.button(row, "EDIT LOADOUT", { Size = UDim2.fromOffset(math.min(170, w * 0.27), 40) })
		edit.Activated:Connect(function()
			closeModal()
			ctx.Inventory.show("stash")
		end)
	end
	local cancel = K.button(row, "CLOSE", { Size = UDim2.fromOffset(math.min(130, w * 0.2), 40) })
	cancel.Activated:Connect(closeModal)
	local busyDeploy = false
	local function queuedKind()
		local m = ctx.State.match
		return (m and m.queued) or (ctx.State.data and ctx.State.data.queued)
	end
	deploy.Activated:Connect(function()
		if busyDeploy then
			return
		end
		busyDeploy = true
		if queuedKind() then
			local res = ctx.State.req("queue", { op = "cancel" })
			if res and res.ok and res.data then
				ctx.State.match = res.data
				ctx.State.matchClock = os.clock()
			end
			busyDeploy = false
			return
		end
		deploy.Text = "COMMITTING..."
		local cur = ctx.State.data
		local res = ctx.State.req("deploy", { rev = cur and cur.rev, kind = mode, map = deployVote })
		busyDeploy = false
		if res and res.ok then
			if res.data and res.data.entered then
				closeModal()
			elseif res.data and res.data.status then
				ctx.State.match = res.data.status
				ctx.State.matchClock = os.clock()
			end
		elseif res and res.code == "STALE_REVISION" then
			task.wait(0.3)
			Screens.deploy()
		elseif res and not res.msg then
			ctx.State.toast("DEPLOY FAILED: " .. string.gsub(tostring(res.code), "_", " "), "warn")
		end
	end)
	-- live refresh while open (full redraw when the loadout, insurance or returns change)
	local function dataSig()
		local cd = ctx.State.data
		local q = cd and cd.insureAll
		local cl = cd and cd.claims
		return string.format("%s|%s|%s|%s|%s", tostring(cd and cd.rev), tostring(q and q.n), tostring(q and q.insured), tostring(cl and cl.ready), tostring(cl and cl.waiting))
	end
	local sig0 = dataSig()
	task.spawn(function()
		while Screens.modal == f do
			if dataSig() ~= sig0 and not busyDeploy then
				Screens.deploy()
				return
			end
			local mt, mc = matchText(ctx.State.match)
			live.match.Text = mt
			live.match.TextColor3 = mc
			local cd = ctx.State.scavCooldown()
			if live.scav then
				live.scav.Text = cd > 0 and ("SCAV READY IN " .. Util.clock(cd)) or "SCAV READY"
				live.scav.TextColor3 = cd > 0 and K.C.orange or K.C.green
			end
			scavTabBtn.Text = cd > 0 and ("SCAV  ·  " .. Util.clock(cd)) or "SCAV  ·  FREE KIT"
			if not busyDeploy then
				local q = queuedKind()
				if q then
					deploy.Text = "LEAVE QUEUE"
					deploy.TextColor3 = K.C.orange
				elseif mode == "scav" and cd > 0 then
					deploy.Text = "SCAV COOLDOWN"
					deploy.TextColor3 = K.C.dim
				else
					local m = ctx.State.match
					local now = workspace:GetServerTimeNow()
					local enter = m and m.state == "RUNNING"
						and ((mode == "pmc" and now < (m.lateUntil or 0)) or (mode == "scav" and now >= (m.scavFrom or 0) and now < (m.scavUntil or 0)))
					deploy.Text = (mode == "scav" and "DEPLOY AS SCAV" or "DEPLOY AS PMC") .. (enter and "  ·  JOIN NOW" or "  ·  QUEUE")
					deploy.TextColor3 = K.C.ochre
				end
			end
			local sig = squadSignature()
			if sig ~= squadSig then
				squadSig = sig
				drawSquad()
			end
			local ms = mapSignature()
			if ms ~= mapSig then
				mapSig = ms
				drawMaps()
			end
			task.wait(0.25)
		end
	end)
	Screens.focus(Screens.switched and openTab or deploy)
end

-- squad invite prompt (non-modal; expires)
local inviteFrame
function Screens.invite(dd)
	if inviteFrame then
		inviteFrame:Destroy()
	end
	local fr = K.frame(gui, { Name = "Invite", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(440, 92), BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.05 })
	inviteFrame = fr
	K.stroke(fr, K.C.ochre, 0.3)
	K.pad(fr, 10)
	K.label(fr, "SQUAD INVITE FROM " .. string.upper(tostring(dd.from)), 15, { FontFace = K.bold, TextColor3 = K.C.ochre, Size = UDim2.new(1, 0, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd })
	local row = K.frame(fr, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 34) })
	K.list(row, Enum.FillDirection.Horizontal, 10)
	local acc = K.button(row, "ACCEPT", { Size = UDim2.fromOffset(150, 34), TextColor3 = K.C.green })
	local dec = K.button(row, "DECLINE", { Size = UDim2.fromOffset(150, 34), TextColor3 = K.C.orange })
	acc.Activated:Connect(function()
		fr:Destroy()
		ctx.State.req("squad", { op = "accept", from = dd.fromId })
	end)
	dec.Activated:Connect(function()
		fr:Destroy()
		ctx.State.req("squad", { op = "decline" })
	end)
	task.delay(45, function()
		if fr.Parent then
			fr:Destroy()
		end
	end)
end

local OUTCOME = {
	SUCCESS = { "EXTRACTED", "green" }, KIA = { "KILLED IN ACTION", "red" }, MIA = { "MISSING IN ACTION", "orange" },
	DISCONNECTED = { "SIGNAL LOST  -  RAID FORFEITED", "orange" },
	SERVER_CLOSED = { "SERVER CLOSED  -  KIT KEPT", "orange" },
}

local function itemList(parent, x, y, w, h, title, list, color)
	local box = K.frame(parent, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = K.C.panel })
	K.stroke(box, color, 0.4)
	K.label(box, "  " .. title, 13, { FontFace = K.bold, TextColor3 = color, Size = UDim2.new(1, 0, 0, 22) })
	local s = K.new("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 26), Size = UDim2.new(1, -12, 1, -30), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, BorderSizePixel = 0, Selectable = false }, box)
	K.list(s, nil, 2)
	if #list == 0 then
		K.label(s, "—", 12, { TextColor3 = K.C.dim })
	end
	for i, it in list do
		local def = Items.defs[it.id]
		local suffix = ((it.n or 1) > 1) and (" x" .. it.n) or ""
		K.label(s, (def and def.name or it.id) .. suffix, 12, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 16) })
	end
end

function Screens.summary(s)
	local o = OUTCOME[s.outcome] or { s.outcome, "text" }
	-- a raid cut off by the server closing is settled as a run-through; its own line says so
	local closed = s.outcome == "SERVER_CLOSED"
	local runThrough = s.runThrough and not closed
	local f, w, h = modal(720, 470, "RAID REPORT  //  " .. o[1] .. (runThrough and " (RUN THROUGH)" or "") .. (s.scav and "  ·  SCAV" or ""))
	f:FindFirstChildOfClass("TextLabel").TextColor3 = K.C[o[2]]
	line(f, 30, string.format("DURATION %s   ·   KILLS %d   ·   +%d XP%s   ·   RAID %s", Util.clock(s.time or 0), s.kills or 0, s.xp or 0,
		s.levelUp and ("   ·   LEVEL UP: " .. tostring(s.level)) or "", string.sub(s.raidId or "", 1, 8)), s.levelUp and K.C.green or K.C.dim, 12)
	if runThrough then
		line(f, 44, "RUN THROUGH: you extracted too quickly with too little done. Your loot is kept but is not found-in-raid.", K.C.orange, 12)
	end
	if ctx.State.deathInfo and s.outcome == "KIA" then
		line(f, 44, ctx.State.deathInfo, K.C.red, 12)
	elseif s.outcome == "MIA" then
		line(f, 44, "THE RAID CLOCK RAN OUT BEFORE YOU REACHED AN EXFIL. INSURED GEAR WILL BE RETURNED.", K.C.orange, 12)
	elseif s.outcome == "SERVER_CLOSED" then
		line(f, 44, "THE SERVER CLOSED DURING THE RAID. YOU KEEP WHAT YOU CARRIED; NOTHING IS FOUND IN RAID.", K.C.orange, 12)
	end
	local colW = math.floor((w - 12) / 2)
	local top = (s.outcome == "KIA" or s.outcome == "MIA" or closed or runThrough) and 68 or 56 -- room for the death / MIA / closed / run-through line
	local listH = h - 140 - (top - 56)
	local retained = s.retained or {}
	local lost = s.lost or {}
	local kept = s.kept or {}
	if s.scav and s.outcome ~= "SUCCESS" and not closed then
		line(f, 70, "The scav kit is gone. Your PMC, stash and health were never at risk.", K.C.dim, 13)
	elseif s.outcome == "SUCCESS" or closed then
		itemList(f, 0, top, colW, listH, (s.scav and "TO YOUR STASH  (" or "CARRIED OUT  (") .. #retained .. ")", retained, K.C.green)
		itemList(f, colW + 12, top, colW, listH, "FOUND IN RAID  (" .. #(s.found or {}) .. ")", s.found or {}, K.C.ochre)
	else
		itemList(f, 0, top, colW, listH, "SECURE CONTAINER KEPT  (" .. #kept .. ")", kept, K.C.green)
		itemList(f, colW + 12, top, colW, listH, "LOST  (" .. #lost .. ")", lost, K.C.red)
	end
	local net = (s.outcome == "SUCCESS" or closed) and ("+" .. Util.commas(s.value or 0)) or ("-" .. Util.commas(s.value or 0))
	local sold = (s.sold or 0) > 0 and string.format("   ·   NO STASH SPACE: SOLD +%s %s", Util.commas(s.sold), Config.CURRENCY) or ""
	line(f, h - 78, string.format("NET VALUE  %s %s   ·   FOUND IN RAID %d%s", net, Config.CURRENCY, #(s.found or {}), sold), K.C.ochre, 14)
	local b = K.button(f, "RETURN TO SAFEHOUSE", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(280, 42), TextSize = 15, TextColor3 = K.C.ochre })
	b.Activated:Connect(closeModal)
	Screens.focus(b)
end

-- Tarkov's settings tabs (docs/design/EFT_PARITY.md section 5). Rows: label, key, kind (enum / num / bool), then
-- enum: names, first index; num: min, max, step, format ("pct", "spct" signed, or a format string); bool: on, off text.
-- GRAPHICS covers what the game controls; resolution, frame cap, anti-aliasing and texture or shadow quality belong
-- to Roblox's own graphics slider.
local SETTING_TABS = {
	{ "GAME", {
		{ "FIELD OF VIEW", "fov", "num", 50, 100, 5, "%d" },
		{ "HEAD BOBBING", "headBob", "num", 0.2, 1, 0.1, "pct" },
		{ "SCREEN SHAKE", "shake", "num", 0, 1, 0.25, "pct" },
		{ "REDUCE MOTION", "reduceMotion", "bool" },
		{ "AIM MODE", "adsToggle", "bool", "TOGGLE", "HOLD" },
		{ "QUICK SLOTS", "quickBar", "enum", { "AUTO-HIDE", "ALWAYS", "NEVER" }, 1 },
		{ "CENTER DOT", "reticle", "bool" },
		{ "HIT FEEDBACK", "hitfx", "bool" },
		{ "HUD SCALE", "hudScale", "num", 0.7, 1.4, 0.1, "pct" },
		{ "CURVED HUD", "curve", "bool" },
		-- Tarkov's GAME tab (audit ui.8)
		{ "MALFUNCTION NOTIFICATIONS", "malfNotes", "bool" },
		{ "DOUBLE-CLICK QUICK USE", "dblUse", "bool" },
	} },
	{ "GRAPHICS", {
		{ "GRAPHICS", "quality", "enum", { [0] = "POTATO", "LOW", "MEDIUM", "HIGH" }, 0 },
		{ "HOLD 30 FPS", "autoGfx", "bool" },
		{ "FILM GRAIN", "grain", "num", 0, 1, 0.1, "pct" },
		{ "LENS EFFECTS", "lens", "bool" },
		{ "MOTION BLUR", "mblur", "bool" },
		{ "RECORDER OVERLAY", "film", "bool" },
	} },
	{ "SOUND", {
		{ "OVERALL VOLUME", "volMaster", "num", 0, 1, 0.1, "pct" },
		{ "EFFECTS", "volFx", "num", 0, 1, 0.1, "pct" },
		{ "INTERFACE", "volUi", "num", 0, 1, 0.1, "pct" },
		{ "AMBIENCE", "volAmb", "num", 0, 1, 0.1, "pct" },
	} },
	{ "POSTFX", {
		{ "BRIGHTNESS", "pfxBright", "num", -0.5, 0.5, 0.05, "spct" },
		{ "SATURATION", "pfxSat", "num", -1, 1, 0.1, "spct" },
		{ "CLARITY", "pfxClarity", "num", -0.5, 0.5, 0.05, "spct" },
		{ "COLOR GRADING", "pfxGrade", "enum", { [0] = "NONE", "STEEL", "EMBER", "MOSS", "DUSK" }, 0 },
		{ "GRADING INTENSITY", "pfxGradeK", "num", 0, 1, 0.1, "pct" },
	} },
	{ "CONTROLS", {
		{ "MOUSE SENSITIVITY", "sens", "num", 0.2, 3, 0.1, "%.1f" },
		{ "AIM SENSITIVITY", "aimSens", "num", 0.2, 3, 0.1, "%.1f" },
		{ "GAMEPAD SENSITIVITY", "padSens", "num", 0.2, 3, 0.1, "%.1f" },
		{ "TOUCH SENSITIVITY", "touchSens", "num", 0.2, 3, 0.1, "%.1f" },
		{ "INVERT Y AXIS", "invertY", "bool" },
		-- touch (Touch.luau): FIRE brings the sights up while held (CoD Mobile's ADS fire); the stick comes to the thumb
		{ "TOUCH: AIM WHEN FIRING", "aimOnFire", "bool" },
		{ "TOUCH: FLOATING STICK", "joyFloat", "bool" },
	} },
}
-- the PC keys a player can rebind, in Tarkov's order and wording
local BIND_ROWS = {
	{ "Reload", "RELOAD" }, { "Sprint", "SPRINT" }, { "Crouch", "CROUCH" }, { "Prone", "PRONE" }, { "LeanLeft", "LEAN LEFT" },
	{ "LeanRight", "LEAN RIGHT" }, { "FreeLook", "FREE LOOK" }, { "FireMode", "FIRE MODE" }, { "FireModeCheck", "CHECK FIRE MODE" },
	{ "MagCheck", "CHECK MAGAZINE" }, { "ChamberCheck", "CHECK CHAMBER" }, { "Light", "TACTICAL DEVICE" }, { "DeviceMode", "DEVICE MODE" }, { "InspectWeapon", "INSPECT WEAPON" },
	{ "ZeroUp", "ZEROING UP" }, { "ZeroDown", "ZEROING DOWN" }, { "SightMode", "SIGHT MODE" }, { "ToggleNVG", "NIGHT VISION" },
	{ "Sidearm", "SIDEARM" }, { "Primary", "WEAPON ON SLING" }, { "Secondary", "WEAPON ON BACK" }, { "Knife", "MELEE WEAPON" },
	{ "Grenade", "GRENADE" }, { "Extracts", "TIME (TWICE: EXITS)" }, { "Inventory", "INVENTORY" }, { "Settings", "SETTINGS" },
	{ "Quick4", "QUICK SLOT 4" }, { "Quick5", "QUICK SLOT 5" }, { "Quick6", "QUICK SLOT 6" }, { "Quick7", "QUICK SLOT 7" },
	{ "Quick8", "QUICK SLOT 8" }, { "Quick9", "QUICK SLOT 9" }, { "Quick0", "QUICK SLOT 0" },
}
local settingsTab = "GAME"
local settingsScroll = {} -- [tab] = where its list was scrolled to
local capture -- the keybind being changed: { action, conns }

local function endCapture()
	if capture then
		for _, cn in capture.conns do
			cn:Disconnect()
		end
		capture = nil
	end
end

local MODS = {
	[Enum.KeyCode.LeftAlt] = "Alt", [Enum.KeyCode.RightAlt] = "Alt", [Enum.KeyCode.LeftShift] = "Shift", [Enum.KeyCode.RightShift] = "Shift",
	[Enum.KeyCode.LeftControl] = "Ctrl", [Enum.KeyCode.RightControl] = "Ctrl",
}
-- wait for the next key (with Alt, Shift or Ctrl held it becomes a chord; a modifier alone binds itself)
local function startCapture(action)
	endCapture()
	local UIS = game:GetService("UserInputService")
	capture = { action = action, conns = {} }
	local pendingMod
	local function finish(keyName, mod)
		endCapture()
		local S = ctx.Settings
		for _, r in BIND_ROWS do
			local keys, m = ctx.Input.keysOf(r[1])
			if r[1] ~= action and keys[1] and keys[1].Name == keyName and m == mod then
				ctx.State.toast("ALSO BOUND TO " .. r[2], "warn")
			end
		end
		S.setBind(action, keyName, mod)
		Screens.settings()
	end
	table.insert(capture.conns, UIS.InputBegan:Connect(function(input)
		if not (Screens.modal and Screens.modal.Parent) then
			endCapture() -- the settings were closed while waiting
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.Backspace then
			endCapture()
			Screens.settings()
			return
		end
		if MODS[k] then
			pendingMod = k
			return
		end
		local mod
		for mk, name in MODS do
			if UIS:IsKeyDown(mk) then
				mod = name
				break
			end
		end
		finish(k.Name, mod)
	end))
	table.insert(capture.conns, UIS.InputEnded:Connect(function(input)
		if pendingMod and input.KeyCode == pendingMod then
			finish(pendingMod.Name, nil)
		end
	end))
end

local function fmtValue(r, v)
	local kind = r[3]
	if kind == "enum" then
		return r[4][v] or tostring(v)
	elseif kind == "num" then
		if r[7] == "pct" then
			return string.format("%d%%", math.floor((v or 0) * 100 + 0.5))
		elseif r[7] == "spct" then
			return string.format("%+d%%", math.floor((v or 0) * 100 + ((v or 0) >= 0 and 0.5 or -0.5)))
		end
		return string.format(r[7], v or 0)
	end
	return v and (r[4] or "ON") or (r[5] or "OFF")
end

function Screens.settings(tab, keepCapture)
	if not keepCapture then
		endCapture()
	end
	settingsTab = tab or settingsTab
	local f, w, h = modal(900, 560, "RECORDER SETTINGS")
	Screens.kind = "settings"
	local S = ctx.Settings
	local d = S.data
	-- Tarkov's tabs
	local tabs = K.frame(f, { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 30) })
	K.list(tabs, Enum.FillDirection.Horizontal, 6)
	local rows, openTab
	for _, t in SETTING_TABS do
		local on = settingsTab == t[1]
		if on then
			rows = t[2]
		end
		local b = K.button(tabs, t[1], { Size = UDim2.fromOffset(120, 30), TextSize = 13, BackgroundColor3 = on and Color3.fromHex("3A3524") or K.C.panel2, TextColor3 = on and K.C.ochre or K.C.dim })
		b.Name = "Tab_" .. t[1]
		b.Activated:Connect(function()
			if settingsTab ~= t[1] then
				Screens.settings(t[1])
			end
		end)
		if on then
			openTab = b -- the gamepad lands on the open tab, not the first one (audit ui.5)
		end
	end
	rows = rows or SETTING_TABS[1][2]
	local cols = w >= 600 and 2 or 1
	local colW = (w - (cols - 1) * 16) / cols
	local binds = settingsTab == "CONTROLS"
	local rowsH = math.ceil(#rows / cols) * 40
	local bindsH = binds and (math.ceil(#BIND_ROWS / cols) * 36 + 70) or 0
	local scroll = K.new("ScrollingFrame", {
		Name = "Rows", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -114),
		ScrollBarThickness = 4, CanvasSize = UDim2.fromOffset(0, rowsH + bindsH), ScrollingDirection = Enum.ScrollingDirection.Y,
	}, f)
	-- the list keeps its place when a change draws the screen again (each tab its own; audit ui.5)
	local tabNow = settingsTab
	task.defer(function()
		if scroll.Parent then
			scroll.CanvasPosition = settingsScroll[tabNow] or Vector2.zero
		end
	end)
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		settingsScroll[tabNow] = scroll.CanvasPosition
	end)
	for i, r in rows do
		local label, key, kind = r[1], r[2], r[3]
		local col = (i - 1) % cols
		local rowI = math.floor((i - 1) / cols)
		local row = K.frame(scroll, { BackgroundTransparency = 1, Position = UDim2.fromOffset(col * (colW + 16), rowI * 40), Size = UDim2.fromOffset(colW, 34) })
		K.label(row, label, 13, { Size = UDim2.new(0.5, 0, 1, 0) })
		local v = d[key]
		local valueLabel = K.label(row, fmtValue(r, v), 13, { Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.2, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, FontFace = K.bold })
		local function bump(dir, quiet)
			if kind == "enum" then
				local lo = r[5] or 1 -- first index (0 when the list starts at [0])
				S.set(key, math.clamp((v or lo) + dir, lo, #r[4]))
			elseif kind == "num" then
				local nv = math.clamp((v or 0) + dir * r[6], r[4], r[5])
				S.set(key, math.floor(nv * 100 + 0.5) / 100)
			else
				S.set(key, not v)
			end
			v = d[key]
			if quiet then
				valueLabel.Text = fmtValue(r, v) -- held down: the value runs without rebuilding the screen
			else
				Screens.settings()
			end
		end
		-- held down, - and + repeat after a short pause (audit ui.7)
		local function holdRepeat(btn, dir)
			local repeated = false
			btn.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					local token = {}
					Screens.holding = token
					repeated = false
					task.delay(0.45, function()
						while Screens.holding == token and btn.Parent do
							repeated = true
							bump(dir, true)
							task.wait(0.08)
						end
					end)
				end
			end)
			btn.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					Screens.holding = nil
				end
			end)
			btn.Activated:Connect(function()
				if repeated then
					repeated = false
					Screens.settings()
				else
					bump(dir)
				end
			end)
		end
		local b1 = K.button(row, kind == "bool" and "TOGGLE" or "-", { Position = UDim2.fromScale(0.72, 0), Size = UDim2.new(kind == "bool" and 0.28 or 0.13, 0, 1, -4) })
		b1.Name = "Btn_" .. string.upper(key) .. (kind == "bool" and "" or "_DOWN")
		if kind == "bool" then
			b1.Activated:Connect(function()
				bump(-1)
			end)
		else
			holdRepeat(b1, -1)
			local b2 = K.button(row, "+", { Position = UDim2.fromScale(0.87, 0), Size = UDim2.new(0.13, 0, 1, -4) })
			b2.Name = "Btn_" .. string.upper(key) .. "_UP"
			holdRepeat(b2, 1)
		end
	end
	if binds then
		-- key bindings (PC): CHANGE waits for a key, Alt / Shift / Ctrl held make a chord; BKSP cancels. With a gamepad or
		-- touch the list shows that device's buttons instead (they are fixed; KNOWN_ISSUES 76)
		local y0 = rowsH + 8
		local dev = ctx.Input.device()
		local padView = dev == "Gamepad" or dev == "Touch"
		local head = (dev == "Gamepad" and "GAMEPAD  ·  a tap and a hold do different things; with LT held (aiming) D-UP, D-DOWN, D-LEFT and R3 do more; in menus LB / RB switch tabs, the right stick turns an inspected item")
			or (dev == "Touch" and "TOUCH  ·  a held button does its second action; MORE holds the rarely used; EDIT TOUCH LAYOUT moves and resizes them")
			or "KEY BINDINGS  ·  CHANGE, then press a key (hold ALT, SHIFT or CTRL for a combination; BACKSPACE cancels)"
		K.label(scroll, head, 12, {
			Position = UDim2.fromOffset(0, y0), Size = UDim2.new(1, -150, 0, 24), TextColor3 = K.C.dim,
		})
		local reset = K.button(scroll, "RESET ALL", { Name = "ResetBinds", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, y0), Size = UDim2.fromOffset(130, 24), TextSize = 11 })
		reset.Visible = not padView
		reset.Activated:Connect(function()
			S.resetBinds()
			Screens.settings()
		end)
		-- the touch layout editor (Touch.edit): move, resize, fade and hide every touch control
		local editT = K.button(scroll, "EDIT TOUCH LAYOUT", {
			Name = "EditTouch", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -146, 0, y0), Size = UDim2.fromOffset(170, 24), TextSize = 11,
		})
		editT.Activated:Connect(function()
			closeModal()
			if ctx.Touch and ctx.Touch.edit then
				ctx.Touch.edit(true)
			end
		end)
		for i, r in BIND_ROWS do
			local action, name = r[1], r[2]
			local col = (i - 1) % cols
			local rowI = math.floor((i - 1) / cols)
			local row = K.frame(scroll, { Name = "Bind_" .. action, BackgroundColor3 = K.C.panel, BackgroundTransparency = 0.3, Position = UDim2.fromOffset(col * (colW + 16), y0 + 32 + rowI * 36), Size = UDim2.fromOffset(colW - 8, 32) })
			K.label(row, name, 12, { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.46, -8, 1, 0) })
			local waiting = capture and capture.action == action
			local custom = d.binds and d.binds[action]
			local keyText = waiting and "PRESS A KEY" or ctx.Input.pcLabel(action)
			if padView then
				keyText = ctx.Input.deviceLabel(dev, action) or "-"
			end
			K.label(row, keyText, padView and 11 or 13, {
				Name = "Key", Position = UDim2.fromScale(0.46, 0), Size = UDim2.new(padView and 0.54 or 0.22, padView and -8 or 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Center, FontFace = K.bold, TextColor3 = waiting and K.C.ochre or (custom and K.C.green or K.C.text),
			})
			if not padView then
				local ch = K.button(row, "CHANGE", { Name = "Change", Position = UDim2.fromScale(0.69, 0.1), Size = UDim2.new(0.15, -4, 0.8, 0), TextSize = 10 })
				ch.Activated:Connect(function()
					startCapture(action)
					Screens.settings(nil, true)
				end)
				local df = K.button(row, "DEFAULT", { Name = "Default", Position = UDim2.fromScale(0.84, 0.1), Size = UDim2.new(0.16, -4, 0.8, 0), TextSize = 10, TextColor3 = custom and K.C.text or K.C.dim })
				df.Activated:Connect(function()
					S.setBind(action, nil)
					Screens.settings()
				end)
			end
		end
	end
	local close = K.button(f, "CLOSE", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(140, 34) })
	close.Activated:Connect(closeModal)
	Screens.focus(openTab)
end

-- Tarkov-style: the extract list is shown on the HUD (names + status), no distances or compass
function Screens.exits()
	if ctx.State.inRaid() then
		ctx.Hud.showExits()
	end
end

function Screens.init(c)
	ctx = c
	K = c.UiKit
	gui = K.screen("ZR_Screens", 30)
	c.State.on("summary", function(s)
		print("[ZR] summary received:", s.outcome)
		local dth = s.death
		if dth then
			if dth.killer then
				ctx.State.deathInfo = string.format("KILLED BY %s  ·  %s  ·  %s  ·  %s%s", dth.killer, dth.weapon or "?", dth.ammo or "?", dth.part or "?", dth.dist and ("  ·  " .. dth.dist .. " M") or "")
			else
				ctx.State.deathInfo = "CAUSE  ·  " .. tostring(dth.cause)
			end
		else
			ctx.State.deathInfo = nil
		end
		task.wait(s.outcome == "KIA" and 2.5 or 0.4)
		Screens.summary(s)
	end)
	-- insertion closes any open terminal screen; squad invites pop up wherever you are in the hideout
	c.State.on("raid", function()
		if Screens.modal then
			closeModal()
		end
	end)
	c.State.on("squadInvite", function(dd)
		if type(dd) == "table" then
			Screens.invite(dd)
		end
	end)
	c.Input.on("Settings", function(down)
		if down and capture then
			return -- waiting for a key to bind: P is the key, not the menu
		end
		if down then
			if Screens.modal then
				closeModal()
			else
				Screens.settings()
			end
		end
	end)
	-- gamepad D-down also readies a grenade when held: Input.luau sends the exits only for a short tap
	local lastO = 0
	c.Input.on("Extracts", function(down)
		if not down then
			return
		end
		-- Tarkov: O checks the time, a double tap lists the exits (the pad and the touch button list them at once)
		local t = os.clock()
		if c.Input.device() == "KBM" and t - lastO > 0.45 then
			lastO = t
			c.Hud.timeCheck()
			return
		end
		lastO = 0
		if not (c.Grenade and c.Grenade.busy()) then
			Screens.exits()
		end
	end)
	c.Input.on("Back", function(down)
		if down and Screens.modal then
			-- B / Backspace closes the top inspect window over the screen first (audit ui.5)
			if ctx.Inspect and ctx.Inspect.closeTop() then
				return
			end
			closeModal()
		end
	end)
	-- LB / RB: the open screen's previous / next tab (audit ui.5); the trader radio handles its own (Trade.luau)
	local function stepTab(dir)
		if Screens.kind == "settings" and not capture then
			local i = 1
			for k, t in SETTING_TABS do
				if t[1] == settingsTab then
					i = k
				end
			end
			Screens.tabSwitch = true
			Screens.settings(SETTING_TABS[(i - 1 + dir) % #SETTING_TABS + 1][1])
		elseif Screens.kind == "deploy" then
			deployMode = deployMode == "pmc" and "scav" or "pmc"
			Screens.tabSwitch = true
			Screens.deploy()
		end
	end
	c.Input.on("TabPrev", function(down)
		if down and Screens.modal then
			stepTab(-1)
		end
	end)
	c.Input.on("TabNext", function(down)
		if down and Screens.modal then
			stepTab(1)
		end
	end)
	-- a pad picked up while a screen is open gets the selection there; put down, Input clears it (audit ui.5)
	c.Input.deviceChanged:Connect(function(dev)
		if dev == "Gamepad" and Screens.modal and Screens.focusDefault then
			c.Input.padFocus(Screens.focusDefault)
		end
	end)
end

return Screens
