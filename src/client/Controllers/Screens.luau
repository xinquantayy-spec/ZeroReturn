--!nonstrict
-- Modal screens: deployment order, post-raid dossier, settings, exits list. Gamepad focus + Back support.
local GuiService = game:GetService("GuiService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("EFB")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)

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

local function line(parent, y, text, color, size)
	return K.label(parent, text, size or 13, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, (size or 13) + 6), TextColor3 = color or K.C.text, TextWrapped = true })
end

function Screens.deploy()
	local d = ctx.State.data
	if not d or ctx.State.inRaid() then
		return
	end
	local f, w, h = modal(560, 420, "DEPLOYMENT ORDER  //  " .. Config.MAP_NAME)
	local wg = d.slots.primary
	local w8 = wg and d.items[wg]
	local mag = w8 and w8.mag and d.items[w8.mag]
	local mags, rounds, meds, other, value = 0, 0, 0, 0, 0
	for _, c in { "pockets", "bag" } do
		for g in d[c] or {} do
			local it = d.items[g]
			local def = Items.defs[it.id]
			if def.kind == "mag" then
				mags += 1
				rounds += it.a or 0
			elseif def.kind == "heal" then
				meds += it.n
			else
				other += 1
			end
			value += Items.valueOf(it)
		end
	end
	for _, g in d.slots do
		local it = d.items[g]
		value += Items.valueOf(it)
		if it.mag and d.items[it.mag] then
			value += Items.valueOf(d.items[it.mag])
		end
	end
	line(f, 34, "RAID WINDOW  " .. Util.clock(Config.RAID_DURATION) .. "    INSERTION  randomized (Ferry Tunnel / South Yard)", K.C.dim, 12)
	line(f, 52, "EXFIL  assigned on insertion · hold position " .. Config.EXTRACT_HOLD .. " s at the radio beacon", K.C.dim, 12)
	line(f, 84, "PRIMARY   " .. (w8 and string.format("R-17 Carbine  %d/25", mag and mag.a or 0) or "NONE  -  you will deploy unarmed"), w8 and K.C.text or K.C.orange, 14)
	line(f, 106, string.format("SPARE     %d magazines · %d rounds", mags, rounds), K.C.text, 14)
	line(f, 128, string.format("MEDICAL   %d field dressings", meds), K.C.text, 14)
	line(f, 150, string.format("OTHER     %d items   ·   PACK %s", other, d.slots.bag and "worn" or "none"), K.C.text, 14)
	line(f, 182, string.format("AT RISK   %s %s", Util.commas(value), Config.CURRENCY), K.C.ochre, 15)
	line(f, 206, "Everything in your loadout is lost if you are killed or miss extraction. Your stash stays safe.", K.C.dim, 12)
	local row = K.frame(f, { Name = "Row", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 40) })
	K.list(row, Enum.FillDirection.Horizontal, 10)
	local deploy = K.button(row, "DEPLOY", { Size = UDim2.fromOffset(180, 40), BackgroundColor3 = Color3.fromHex("3A3524"), TextColor3 = K.C.ochre, TextSize = 16 })
	local edit = K.button(row, "EDIT LOADOUT", { Size = UDim2.fromOffset(170, 40) })
	local cancel = K.button(row, "CANCEL", { Size = UDim2.fromOffset(140, 40) })
	deploy.Activated:Connect(function()
		deploy.Text = "COMMITTING..."
		local res = ctx.State.req("deploy", { rev = d.rev })
		if res and res.ok then
			closeModal()
		else
			deploy.Text = "DEPLOY"
			if res and res.code == "STALE_REVISION" then
				task.wait(0.3)
				Screens.deploy()
			elseif res and not res.msg then
				ctx.State.toast("DEPLOY FAILED: " .. tostring(res.code), "warn")
			end
		end
	end)
	edit.Activated:Connect(function()
		closeModal()
		ctx.Inventory.show("stash")
	end)
	cancel.Activated:Connect(closeModal)
	K.focus(deploy)
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
	local f, w, h = modal(720, 470, "RAID REPORT  //  " .. o[1])
	f:FindFirstChildOfClass("TextLabel").TextColor3 = K.C[o[2]]
	line(f, 30, string.format("DURATION %s   ·   KILLS %d   ·   RAID %s", Util.clock(s.time or 0), s.kills or 0, string.sub(s.raidId or "", 1, 8)), K.C.dim, 12)
	local colW = math.floor((w - 12) / 2)
	local listH = h - 140
	local retained = s.retained or {}
	local lost = s.lost or {}
	itemList(f, 0, 56, colW, listH, "CARRIED OUT  (" .. #retained .. ")", retained, K.C.green)
	itemList(f, colW + 12, 56, colW, listH, "LOST  (" .. #lost .. ")", lost, K.C.red)
	local net = s.outcome == "SUCCESS" and ("+" .. Util.commas(s.value or 0)) or ("-" .. Util.commas(s.value or 0))
	line(f, h - 78, string.format("NET VALUE  %s %s   ·   FOUND IN RAID %d", net, Config.CURRENCY, #(s.found or {})), K.C.ochre, 14)
	local b = K.button(f, "RETURN TO SAFEHOUSE", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(280, 42), TextSize = 15, TextColor3 = K.C.ochre })
	b.Activated:Connect(closeModal)
	K.focus(b)
end

function Screens.settings()
	local f, w, h = modal(520, 430, "RECORDER SETTINGS")
	local S = ctx.Settings
	local y = 36
	local function row(label, value, onMinus, onPlus)
		local r = K.frame(f, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 34) })
		K.label(r, label, 13, { Size = UDim2.new(0.5, 0, 1, 0) })
		local v = K.label(r, value, 13, { Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.2, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, FontFace = K.bold })
		local m = K.button(r, onPlus and "−" or "TOGGLE", { Position = UDim2.fromScale(0.72, 0), Size = UDim2.new(onPlus and 0.13 or 0.28, 0, 1, -4) })
		m.Activated:Connect(function()
			onMinus()
			Screens.settings()
		end)
		if onPlus then
			local p = K.button(r, "+", { Position = UDim2.fromScale(0.87, 0), Size = UDim2.new(0.13, 0, 1, -4) })
			p.Activated:Connect(function()
				onPlus()
				Screens.settings()
			end)
		end
		y += 40
		return m
	end
	local d = S.data
	local q = { "LOW", "MEDIUM", "HIGH" }
	local first = row("QUALITY PRESET", q[d.quality], function()
		S.set("quality", math.max(1, d.quality - 1))
	end, function()
		S.set("quality", math.min(3, d.quality + 1))
	end)
	row("FIELD OF VIEW", tostring(d.fov), function()
		S.set("fov", math.max(65, d.fov - 5))
	end, function()
		S.set("fov", math.min(90, d.fov + 5))
	end)
	row("SENSITIVITY", string.format("%.1f", d.sens), function()
		S.set("sens", math.max(0.2, math.floor((d.sens - 0.1) * 10 + 0.5) / 10))
	end, function()
		S.set("sens", math.min(3, math.floor((d.sens + 0.1) * 10 + 0.5) / 10))
	end)
	row("SCREEN SHAKE", string.format("%d%%", d.shake * 100), function()
		S.set("shake", math.max(0, d.shake - 0.25))
	end, function()
		S.set("shake", math.min(1, d.shake + 0.25))
	end)
	row("REDUCE MOTION", d.reduceMotion and "ON" or "OFF", function()
		S.set("reduceMotion", not d.reduceMotion)
	end)
	row("RECORDER OVERLAY", d.film and "ON" or "OFF", function()
		S.set("film", not d.film)
	end)
	row("CENTER DOT", d.reticle and "ON" or "OFF", function()
		S.set("reticle", not d.reticle)
	end)
	row("AIM MODE", d.adsToggle and "TOGGLE" or "HOLD", function()
		S.set("adsToggle", not d.adsToggle)
	end)
	local close = K.button(f, "CLOSE", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(140, 34) })
	close.Activated:Connect(closeModal)
	K.focus(first)
end

function Screens.exits()
	local raid = ctx.State.raid
	if not raid or not ctx.State.inRaid() then
		return
	end
	if exitGui then
		exitGui:Destroy()
	end
	exitGui = K.frame(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(420, 30 + #raid.extracts * 24), BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.2 })
	K.stroke(exitGui, K.C.ochre, 0.4)
	K.pad(exitGui, 8)
	K.list(exitGui, nil, 2)
	K.label(exitGui, "ASSIGNED EXFIL", 12, { FontFace = K.bold, TextColor3 = K.C.ochre, Size = UDim2.new(1, 0, 0, 16) })
	local cam = workspace.CurrentCamera
	for i, e in raid.extracts do
		local v = e.pos - cam.CFrame.Position
		K.label(exitGui, string.format("%s  %-12s  %s  %d m", e.id, e.name, ctx.Hud.compass(v), math.floor(v.Magnitude * 0.28)), 13, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 18) })
	end
	local mine = exitGui
	task.delay(5, function()
		if exitGui == mine then
			exitGui:Destroy()
			exitGui = nil
		end
	end)
end

function Screens.init(c)
	ctx = c
	K = c.UiKit
	gui = K.screen("EFB_Screens", 30)
	c.State.on("summary", function(s)
		print("[EFB] summary received:", s.outcome)
		task.wait(s.outcome == "KIA" and 2.5 or 0.4)
		Screens.summary(s)
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
