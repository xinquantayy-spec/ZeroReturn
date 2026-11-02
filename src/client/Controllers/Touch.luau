--!nonstrict
-- Touch layout: thumb-reachable action cluster on the right (Roblox thumbstick + jump stay on default
-- positions). FIRE also drags to aim, LOOK drags to look around (free look). Visible only when touch is the preferred
-- input and no menu is open. A button with a hold action does its own action on a tap and the other when held
-- (Input.HOLD): CHK checks the chamber, SWAP inspects the weapon, MODE opens the weapon tray (fire-mode check, zeroing,
-- the sight's mode; KNOWN_ISSUES 76).
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local Touch = {}
local ctx, K
local gui, topGui
local buttons = {}
local touchMode = false
local topKey = "" -- the menu row's shown buttons, as last placed
local press = {} -- [action] = { begin(pos), finish(), drag(pos) }: what a finger on the button does (tests use it too)

-- action, label, anchor position (scale), size px, hold action ("tray": the weapon tray)
local LAYOUT = {
	{ "Fire", "FIRE", Vector2.new(0.885, 0.50), 96 },
	{ "Aim", "ADS", Vector2.new(0.765, 0.43), 62 },
	{ "Reload", "RLD", Vector2.new(0.955, 0.33), 56 },
	{ "Crouch", "CRCH", Vector2.new(0.70, 0.62), 56 },
	{ "Sprint", "RUN", Vector2.new(0.10, 0.48), 56 },
	{ "Heal", "MED", Vector2.new(0.69, 0.30), 52 },
	{ "CycleWeapon", "SWAP", Vector2.new(0.765, 0.62), 52, "InspectWeapon" },
	{ "MagCheck", "CHK", Vector2.new(0.955, 0.62), 46, "ChamberCheck" },
	-- Tarkov's B (fire mode) on a tap, the weapon tray held; Alt (free look) on LOOK, which drags like FIRE
	{ "FireMode", "MODE", Vector2.new(0.60, 0.30), 46, "tray" },
	{ "FreeLook", "LOOK", Vector2.new(0.53, 0.30), 46 },
	{ "LeanLeft", "LN-L", Vector2.new(0.62, 0.74), 46 },
	{ "LeanRight", "LN-R", Vector2.new(0.70, 0.80), 46 },
	{ "Prone", "PRN", Vector2.new(0.62, 0.86), 46 },
	{ "Grenade", "NADE", Vector2.new(0.885, 0.73), 50 },
	-- shown only when there is something to switch: a light or laser on the gun (a tap: on/off, held: its mode), goggles
	-- or a face shield on the head
	{ "Light", "LGT", Vector2.new(0.60, 0.58), 42 },
	{ "ToggleNVG", "NV", Vector2.new(0.60, 0.44), 42 },
	-- at a stationary gun these replace the personal-weapon buttons (the Stationary controller; FIRE drags to aim)
	{ "MountFire", "FIRE", Vector2.new(0.885, 0.50), 96 },
	{ "MountZoom", "ZOOM", Vector2.new(0.765, 0.43), 62 },
	{ "MountLeave", "LEAVE", Vector2.new(0.955, 0.33), 56 },
}
local MOUNT = { MountFire = true, MountZoom = true, MountLeave = true }
-- the menu row stands in the top bar's free band (GuiService.TopbarInset: Roblox leaves it, right of its own menu, for a
-- game's buttons), centred, so it covers neither the vitals (top left) nor the recorder line and the raid clock (top
-- right; KNOWN_ISSUES 75) nor the thumb buttons. The buttons shown are centred together (EXIT is for raids only).
local TOP_ROW = { { "Settings", "SET" }, { "Extracts", "EXIT" }, { "Inventory", "BAG" } }
local TOP = { Settings = true, Extracts = true, Inventory = true }
local TOP_SIZE, TOP_GAP = 46, 12
-- the weapon tray (MODE held): a row under the menu row, open until 4 s pass without a tap on it or MODE is tapped
local TRAY = { { "FireModeCheck", "CHECK" }, { "ZeroUp", "ZERO +" }, { "ZeroDown", "ZERO -" }, { "SightMode", "SIGHT" } }
local TRAY_W, TRAY_H, TRAY_GAP, TRAY_TIME = 64, 36, 8, 4
local trayButtons = {}
local trayOpen, trayUntil = false, 0
Touch.tray = function()
	return trayOpen
end

local function topCentreY()
	return math.max(GuiService.TopbarInset.Max.Y, TOP_SIZE + 8) * 0.5
end

-- where the menu row ends (screen pixels from the top) while the touch layout is on, else nil: the HUD drops the exits
-- list under it and keeps its notices below it
function Touch.topRowBottom()
	if not touchMode then
		return nil
	end
	return topCentreY() + TOP_SIZE * 0.5
end

-- a button's box (GUI absolute pixels: x0, y0, x1, y1) while the touch layout is on, else nil (the HUD keeps its toasts
-- off RUN)
function Touch.rectOf(action)
	local b = buttons[action]
	if not (touchMode and b) then
		return nil
	end
	local p, s = b.AbsolutePosition, b.AbsoluteSize
	return p.X, p.Y, p.X + s.X, p.Y + s.Y
end

local function placeTop(list)
	local W = topGui.AbsoluteSize.X
	local rowW = #list * TOP_SIZE + math.max(0, #list - 1) * TOP_GAP
	local x0 = math.max(W * 0.5 - rowW * 0.5, GuiService.TopbarInset.Min.X + 10)
	local cy = topCentreY()
	for i, action in list do
		buttons[action].Position = UDim2.fromOffset(x0 + (i - 1) * (TOP_SIZE + TOP_GAP) + TOP_SIZE * 0.5, cy)
	end
end

local function setTray(on)
	trayOpen = on
	trayUntil = os.clock() + TRAY_TIME
	local W = topGui.AbsoluteSize.X
	local rowW = #TRAY * TRAY_W + (#TRAY - 1) * TRAY_GAP
	local y = topCentreY() + TOP_SIZE * 0.5 + 10 + TRAY_H * 0.5
	for i, t in TRAY do
		local b = trayButtons[t[1]]
		b.Position = UDim2.fromOffset(W * 0.5 - rowW * 0.5 + (i - 1) * (TRAY_W + TRAY_GAP) + TRAY_W * 0.5, y)
		b.Visible = on
	end
end

local function refresh()
	if not gui then
		return
	end
	local touch = ctx.Input.device() == "Touch" or (UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.GamepadEnabled)
	if touch ~= touchMode then
		touchMode = touch
		if ctx.Hud and ctx.Hud.layout then
			ctx.Hud.layout()
		end
	end
	gui.Enabled = touch and not ctx.Input.isMenu()
	topGui.Enabled = gui.Enabled
	local inRaid = ctx.State.inRaid()
	local atGun = ctx.Stationary ~= nil and ctx.Stationary.mounted == true
	local rects = ctx.Hud and ctx.Hud.exitRects -- the exits list's rows, while it shows: buttons under one fade so it reads
	for action, b in buttons do
		local raidOnly = action ~= "Inventory" and action ~= "Settings" and action ~= "Sprint" and action ~= "Crouch"
		local shown = inRaid or not raidOnly
		if MOUNT[action] then
			shown = shown and atGun
		elseif atGun then
			shown = shown and (action == "Inventory" or action == "Settings")
		end
		if action == "Light" then
			shown = shown and ctx.Weapon.hasDevice ~= nil and ctx.Weapon.hasDevice()
			b.BackgroundColor3 = ctx.Weapon.light and K.C.ochre or K.C.bg
		elseif action == "ToggleNVG" then
			local NV = ctx.NightVision
			shown = shown and NV ~= nil and NV.canFlip ~= nil and NV.canFlip()
			b.BackgroundColor3 = (NV and NV.down) and K.C.ochre or K.C.bg
		end
		b.Visible = shown
		local under = false
		if rects and shown and not TOP[action] then
			local p, sz = b.AbsolutePosition, b.AbsoluteSize
			for _, r in rects do
				if p.X < r[3] and p.X + sz.X > r[1] and p.Y < r[4] and p.Y + sz.Y > r[2] then
					under = true
					break
				end
			end
		end
		if under ~= (b:GetAttribute("Under") == true) then
			b:SetAttribute("Under", under)
			b.BackgroundTransparency = under and 0.85 or 0.35
			b.TextTransparency = under and 0.7 or 0
			local stroke = b:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Enabled = not under
			end
		end
		if action == "MountZoom" then
			b.BackgroundColor3 = ctx.Stationary.zooming and K.C.ochre or K.C.bg
		elseif action == "Aim" then
			b.BackgroundColor3 = ctx.Weapon.aiming and K.C.ochre or K.C.bg
		elseif action == "Sprint" then
			b.BackgroundColor3 = ctx.Movement.sprinting and K.C.ochre or K.C.bg
		elseif action == "Crouch" then
			b.BackgroundColor3 = ctx.Movement.crouching and K.C.ochre or K.C.bg
		elseif action == "Prone" then
			b.BackgroundColor3 = ctx.Movement.prone and K.C.ochre or K.C.bg
		elseif action == "LeanLeft" then
			b.BackgroundColor3 = ctx.Movement.leanTarget < 0 and K.C.ochre or K.C.bg
		elseif action == "LeanRight" then
			b.BackgroundColor3 = ctx.Movement.leanTarget > 0 and K.C.ochre or K.C.bg
		end
	end
	local list = {}
	for _, r in TOP_ROW do
		if buttons[r[1]].Visible then
			table.insert(list, r[1])
		end
	end
	local key = table.concat(list, ",")
	if key ~= topKey then
		topKey = key
		placeTop(list)
	end
	if trayOpen and (os.clock() > trayUntil or not gui.Enabled or not buttons.FireMode.Visible) then
		setTray(false)
	end
end

function Touch.init(c)
	ctx = c
	K = c.UiKit
	gui = K.screen("ZR_Touch", 6)
	gui.Enabled = false
	-- the menu row's own screen, laid out in screen pixels from the very top (the top bar's band included)
	topGui = K.screen("ZR_TouchTop", 6)
	topGui.ScreenInsets = Enum.ScreenInsets.None
	topGui.Enabled = false
	local specs = table.clone(LAYOUT)
	for _, r in TOP_ROW do
		table.insert(specs, { r[1], r[2], nil, TOP_SIZE })
	end
	for _, spec in specs do
		local action, label, pos, size, hold = spec[1], spec[2], spec[3], spec[4], spec[5]
		local b = K.button(pos and gui or topGui, label, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = pos and UDim2.fromScale(pos.X, pos.Y) or UDim2.fromOffset(0, -100),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.35, TextSize = (size > 80) and 18 or 13, Selectable = false,
		})
		K.new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
		buttons[action] = b
		local last, tok, held = nil, nil, false
		local f = {}
		function f.begin(p)
			last = p
			if not hold then
				c.Input.trigger(action, true)
				return
			end
			-- a tap does the button's action when the finger lifts; held, the hold action starts
			local mine = {}
			tok, held = mine, false
			task.delay(c.Input.HOLD or 0.35, function()
				if tok ~= mine then
					return
				end
				held = true
				if hold == "tray" then
					setTray(true)
				else
					c.Input.trigger(hold, true)
				end
			end)
		end
		function f.finish()
			last = nil
			if not hold then
				c.Input.trigger(action, false)
				return
			end
			local wasHeld = held
			tok, held = nil, false
			if wasHeld then
				if hold ~= "tray" then
					c.Input.trigger(hold, false)
				end
			elseif hold == "tray" and trayOpen then
				setTray(false) -- a tap on MODE with the tray open closes it (no fire-mode change)
			else
				c.Input.trigger(action, true)
				c.Input.trigger(action, false)
			end
		end
		function f.drag(p)
			if last and (action == "Fire" or action == "MountFire" or action == "FreeLook") then
				c.Camera.addLook((p.X - last.X) * 0.8, (p.Y - last.Y) * 0.8)
				last = p
			end
		end
		press[action] = f
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				f.begin(Vector2.new(input.Position.X, input.Position.Y))
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				f.finish()
			end
		end)
		b.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				f.drag(Vector2.new(input.Position.X, input.Position.Y))
			end
		end)
	end
	-- the weapon tray's buttons (a tap does the action; each tap keeps the tray open a while longer)
	for _, t in TRAY do
		local action = t[1]
		local b = K.button(topGui, t[2], {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(TRAY_W, TRAY_H), BackgroundColor3 = K.C.bg,
			BackgroundTransparency = 0.25, TextSize = 12, Selectable = false, Visible = false,
		})
		K.new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
		trayButtons[action] = b
		local f = {}
		function f.begin()
			trayUntil = os.clock() + TRAY_TIME
			c.Input.trigger(action, true)
		end
		function f.finish()
			c.Input.trigger(action, false)
		end
		function f.drag() end
		press["tray:" .. action] = f
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				f.begin()
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				f.finish()
			end
		end)
	end
	c.Input.deviceChanged:Connect(refresh)
	-- the top bar's band can change (Roblox's menu opens wider) and the screen can turn: place the row again
	local function placeAgain()
		topKey = ""
		refresh()
		if touchMode and ctx.Hud and ctx.Hud.layout then
			ctx.Hud.layout()
		end
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeAgain)
	topGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeAgain)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc > 0.15 then
			acc = 0
			refresh()
		end
	end)
	refresh()
end

-- tests and the Studio bridge: a finger on a button (action, or "tray:<action>") for `secs`, dragged by `drag` pixels
function Touch.simulate(action, secs, drag)
	local f = press[action]
	if not f then
		return false
	end
	local b = buttons[action] or trayButtons[string.gsub(action, "^tray:", "")]
	local p0 = b and (b.AbsolutePosition + b.AbsoluteSize * 0.5) or Vector2.zero
	f.begin(p0)
	if drag then
		task.wait(0.05)
		f.drag(p0 + drag)
	end
	task.wait(secs or 0.05)
	f.finish()
	return true
end

return Touch
