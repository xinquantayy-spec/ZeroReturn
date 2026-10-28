--!nonstrict
-- Modal screens: deployment order, post-raid dossier, settings, exits list. Gamepad focus + Back support.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local Env = require(Shared.Env)

local Screens = { modal = nil }
local ctx, K
local gui, exitGui

local function closeModal()
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
	closeModal()
	if ctx.Inventory.open then
		ctx.Inventory.close()
	end
	local vp = K.viewport(gui)
	w = math.min(w, vp.X - 16)
	h = math.min(h, vp.Y - 12)
	local f = K.frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h), BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.03 })
	K.stroke(f, K.C.line, 0.4)
	K.pad(f, 14)
	K.label(f, title, 17, { FontFace = K.bold, Size = UDim2.new(1, 0, 0, 24) })
	f.Name = "Modal"
	Screens.modal = f
	ctx.Input.setMenu(true)
	ctx.Interact.setEnabled(false)
	return f, w - 28, h - 28
end
Screens.openModal = modal

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
			return string.format("\nINSERTION AT %02d:%02d LOCAL  ·  %s", math.floor(e.clock0), math.floor((e.clock0 % 1) * 60), w.name)
		end
		return "\nQUAY 7 LOCAL TIME " .. Env.label(e, now)
	end
	if m.state == "MATCHING" then
		return string.format("%s  ·  INSERTION IN %s  ·  %d QUEUED", m.queued and "YOU ARE QUEUED" or "RAID FORMING", t(m.startsAt - now), m.inQueue or 0) .. conditions(), K.C.ochre
	elseif m.state == "RUNNING" then
		if m.queued then
			return "QUEUED FOR THE NEXT RAID  ·  CURRENT RAID ENDS IN " .. t(m.endsAt - now), K.C.ochre
		end
		local s = string.format("RAID IN PROGRESS  ·  %s LEFT  ·  %d/%d INSIDE", t(m.endsAt - now), m.inRaid or 0, m.maxPlayers or Config.MAX_PLAYERS) .. conditions()
		if now < (m.lateUntil or 0) then
			s ..= "\nPMC ENTRY OPEN FOR " .. t(m.lateUntil - now) .. "  ·  SCAV ENTRY " .. t((m.scavUntil or 0) - now)
		elseif now < (m.scavUntil or 0) then
			s ..= "\nPMC ENTRY CLOSED (NEXT RAID)  ·  SCAV ENTRY OPEN FOR " .. t(m.scavUntil - now)
		else
			s ..= "\nENTRY CLOSED  ·  DEPLOYING NOW QUEUES FOR THE NEXT RAID"
		end
		return s, K.C.orange
	end
	return "NO RAID IN PROGRESS  ·  DEPLOYING STARTS ONE (" .. Config.MATCH_TIME .. " S TO GATHER THE QUEUE)", K.C.green
end
Screens.matchText = matchText

local deployMode = "pmc"

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
	local f, w, h = modal(820, 500, "DEPLOYMENT TERMINAL  //  " .. Config.MAP_NAME)
	local me = Players.LocalPlayer
	local mode = deployMode
	-- mode tabs
	local tabs = K.frame(f, { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 34) })
	K.list(tabs, Enum.FillDirection.Horizontal, 8)
	local scavTabBtn
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
	R("RAID ON THIS SERVER", K.C.ochre, 13, true)
	live.match = R("", K.C.text, 12)
	R(string.format("%d-min raids · up to %d operators · PMCs, player scavs and the Harbor Watch share one map.", math.floor(Config.RAID_DURATION / 60), Config.MAX_PLAYERS), K.C.dim, 11)
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
		local res = ctx.State.req("deploy", { rev = cur and cur.rev, kind = mode })
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
					local enter = m and m.state == "RUNNING" and ((mode == "pmc" and now < (m.lateUntil or 0)) or (mode == "scav" and now < (m.scavUntil or 0)))
					deploy.Text = (mode == "scav" and "DEPLOY AS SCAV" or "DEPLOY AS PMC") .. (enter and "  ·  JOIN NOW" or "  ·  QUEUE")
					deploy.TextColor3 = K.C.ochre
				end
			end
			local sig = squadSignature()
			if sig ~= squadSig then
				squadSig = sig
				drawSquad()
			end
			task.wait(0.25)
		end
	end)
	K.focus(deploy)
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
	local f, w, h = modal(720, 470, "RAID REPORT  //  " .. o[1] .. (s.runThrough and " (RUN THROUGH)" or "") .. (s.scav and "  ·  SCAV" or ""))
	f:FindFirstChildOfClass("TextLabel").TextColor3 = K.C[o[2]]
	line(f, 30, string.format("DURATION %s   ·   KILLS %d   ·   +%d XP%s   ·   RAID %s", Util.clock(s.time or 0), s.kills or 0, s.xp or 0,
		s.levelUp and ("   ·   LEVEL UP: " .. tostring(s.level)) or "", string.sub(s.raidId or "", 1, 8)), s.levelUp and K.C.green or K.C.dim, 12)
	if s.runThrough then
		line(f, 44, "RUN THROUGH: you extracted too quickly with too little done. Your loot is kept but is not found-in-raid.", K.C.orange, 12)
	end
	if ctx.State.deathInfo and s.outcome == "KIA" then
		line(f, 44, ctx.State.deathInfo, K.C.red, 12)
	elseif s.outcome == "MIA" then
		line(f, 44, "THE RAID CLOCK RAN OUT BEFORE YOU REACHED AN EXFIL. INSURED GEAR WILL BE RETURNED.", K.C.orange, 12)
	end
	local colW = math.floor((w - 12) / 2)
	local top = (s.outcome == "KIA" or s.outcome == "MIA" or s.runThrough) and 68 or 56 -- room for the death / MIA / run-through line
	local listH = h - 140 - (top - 56)
	local retained = s.retained or {}
	local lost = s.lost or {}
	local kept = s.kept or {}
	if s.scav and s.outcome ~= "SUCCESS" then
		line(f, 70, "The scav kit is gone. Your PMC, stash and health were never at risk.", K.C.dim, 13)
	elseif s.outcome == "SUCCESS" then
		itemList(f, 0, top, colW, listH, (s.scav and "TO YOUR STASH  (" or "CARRIED OUT  (") .. #retained .. ")", retained, K.C.green)
		itemList(f, colW + 12, top, colW, listH, "FOUND IN RAID  (" .. #(s.found or {}) .. ")", s.found or {}, K.C.ochre)
	else
		itemList(f, 0, top, colW, listH, "SECURE CONTAINER KEPT  (" .. #kept .. ")", kept, K.C.green)
		itemList(f, colW + 12, top, colW, listH, "LOST  (" .. #lost .. ")", lost, K.C.red)
	end
	local net = s.outcome == "SUCCESS" and ("+" .. Util.commas(s.value or 0)) or ("-" .. Util.commas(s.value or 0))
	local sold = (s.sold or 0) > 0 and string.format("   ·   NO STASH SPACE: SOLD +%s %s", Util.commas(s.sold), Config.CURRENCY) or ""
	line(f, h - 78, string.format("NET VALUE  %s %s   ·   FOUND IN RAID %d%s", net, Config.CURRENCY, #(s.found or {}), sold), K.C.ochre, 14)
	local b = K.button(f, "RETURN TO SAFEHOUSE", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(280, 42), TextSize = 15, TextColor3 = K.C.ochre })
	b.Activated:Connect(closeModal)
	K.focus(b)
end

local SETTING_ROWS = {
	{ "QUALITY PRESET", "quality", "enum", { "LOW", "MEDIUM", "HIGH" } },
	{ "FIELD OF VIEW", "fov", "num", 65, 100, 5, "%d" },
	{ "SENSITIVITY", "sens", "num", 0.2, 3, 0.1, "%.1f" },
	{ "SCREEN SHAKE", "shake", "num", 0, 1, 0.25, "pct" },
	{ "FILM GRAIN", "grain", "num", 0, 1, 0.1, "pct" },
	{ "HUD SCALE", "hudScale", "num", 0.7, 1.4, 0.1, "pct" },
	{ "LENS EFFECTS", "lens", "bool" },
	{ "CURVED HUD", "curve", "bool" },
	{ "MOTION BLUR", "mblur", "bool" },
	{ "RECORDER OVERLAY", "film", "bool" },
	{ "REDUCE MOTION", "reduceMotion", "bool" },
	{ "CENTER DOT", "reticle", "bool" },
	{ "HIT FEEDBACK", "hitfx", "bool" },
	{ "AIM MODE", "adsToggle", "bool", "TOGGLE", "HOLD" },
}

function Screens.settings()
	local f, w, h = modal(820, 470, "RECORDER SETTINGS")
	local S = ctx.Settings
	local d = S.data
	local cols = w >= 600 and 2 or 1
	local colW = (w - (cols - 1) * 16) / cols
	local scroll = K.new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -76),
		ScrollBarThickness = 4, CanvasSize = UDim2.fromOffset(0, math.ceil(#SETTING_ROWS / cols) * 40), ScrollingDirection = Enum.ScrollingDirection.Y,
	}, f)
	local first
	for i, r in SETTING_ROWS do
		local label, key, kind = r[1], r[2], r[3]
		local col = (i - 1) % cols
		local rowI = math.floor((i - 1) / cols)
		local row = K.frame(scroll, { BackgroundTransparency = 1, Position = UDim2.fromOffset(col * (colW + 16), rowI * 40), Size = UDim2.fromOffset(colW, 34) })
		K.label(row, label, 13, { Size = UDim2.new(0.5, 0, 1, 0) })
		local value
		local v = d[key]
		if kind == "enum" then
			value = r[4][v] or tostring(v)
		elseif kind == "num" then
			value = r[7] == "pct" and string.format("%d%%", math.floor((v or 0) * 100 + 0.5)) or string.format(r[7], v or 0)
		else
			value = v and (r[4] or "ON") or (r[5] or "OFF")
		end
		K.label(row, value, 13, { Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.2, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, FontFace = K.bold })
		local function bump(dir)
			if kind == "enum" then
				S.set(key, math.clamp((v or 1) + dir, 1, #r[4]))
			elseif kind == "num" then
				local nv = math.clamp((v or 0) + dir * r[6], r[4], r[5])
				S.set(key, math.floor(nv * 100 + 0.5) / 100)
			else
				S.set(key, not v)
			end
			Screens.settings()
		end
		local b1 = K.button(row, kind == "bool" and "TOGGLE" or "-", { Position = UDim2.fromScale(0.72, 0), Size = UDim2.new(kind == "bool" and 0.28 or 0.13, 0, 1, -4) })
		b1.Name = "Btn_" .. string.upper(key) .. (kind == "bool" and "" or "_DOWN")
		b1.Activated:Connect(function()
			bump(-1)
		end)
		if kind ~= "bool" then
			local b2 = K.button(row, "+", { Position = UDim2.fromScale(0.87, 0), Size = UDim2.new(0.13, 0, 1, -4) })
			b2.Name = "Btn_" .. string.upper(key) .. "_UP"
			b2.Activated:Connect(function()
				bump(1)
			end)
		end
		first = first or b1
	end
	local close = K.button(f, "CLOSE", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(140, 34) })
	close.Activated:Connect(closeModal)
	K.focus(first)
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
		if down then
			if Screens.modal then
				closeModal()
			else
				Screens.settings()
			end
		end
	end)
	c.Input.on("Extracts", function(down)
		if down then
			Screens.exits()
		end
	end)
	c.Input.on("Back", function(down)
		if down and Screens.modal then
			closeModal()
		end
	end)
end

return Screens
