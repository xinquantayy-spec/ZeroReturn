--!nonstrict
-- Modal screens: deployment order, post-raid dossier, settings, exits list. Gamepad focus + Back support.
local GuiService = game:GetService("GuiService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
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
	-- loadout summary from worn gear and carried containers
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
	line(f, 34, "RAID WINDOW  " .. Util.clock(Config.RAID_DURATION) .. "    INSERTION  randomized    EXFIL  assigned on insertion", K.C.dim, 12)
	line(f, 60, "PRIMARY    " .. slotName("primary") .. "     HOLSTER  " .. slotName("holster"), d.slots.primary and K.C.text or K.C.orange, 13)
	line(f, 80, "ARMOR      " .. slotName("armor") .. "     HELMET  " .. slotName("head"), K.C.text, 13)
	line(f, 100, "RIG        " .. slotName("rig") .. "     BACKPACK  " .. slotName("back"), K.C.text, 13)
	line(f, 124, string.format("SPARE      %d magazines · %d rounds     MEDICAL  %d items", mags, rounds, meds), K.C.text, 13)
	line(f, 152, string.format("AT RISK    %s %s", Util.commas(value), Config.CURRENCY), K.C.ochre, 15)
	line(f, 176, "Everything you wear and carry is lost if you are killed or miss extraction - except your secure container. Your stash stays safe.", K.C.dim, 12)
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
	local kept = s.kept or {}
	if s.outcome == "SUCCESS" then
		itemList(f, 0, 56, colW, listH, "CARRIED OUT  (" .. #retained .. ")", retained, K.C.green)
		itemList(f, colW + 12, 56, colW, listH, "FOUND IN RAID  (" .. #(s.found or {}) .. ")", s.found or {}, K.C.ochre)
	else
		itemList(f, 0, 56, colW, listH, "SECURE CONTAINER KEPT  (" .. #kept .. ")", kept, K.C.green)
		itemList(f, colW + 12, 56, colW, listH, "LOST  (" .. #lost .. ")", lost, K.C.red)
	end
	local net = s.outcome == "SUCCESS" and ("+" .. Util.commas(s.value or 0)) or ("-" .. Util.commas(s.value or 0))
	line(f, h - 78, string.format("NET VALUE  %s %s   ·   FOUND IN RAID %d", net, Config.CURRENCY, #(s.found or {})), K.C.ochre, 14)
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
	{ "HUD LENS WARP", "warp", "bool" },
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
