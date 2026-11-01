--!nonstrict
-- Touch layout: thumb-reachable action cluster on the right (Roblox thumbstick + jump stay on default
-- positions). FIRE also drags to aim. Visible only when touch is the preferred input and no menu is open.
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local Touch = {}
local ctx, K
local gui, topGui
local buttons = {}
local touchMode = false
local topKey = "" -- the menu row's shown buttons, as last placed

-- action, label, anchor position (scale), size px
local LAYOUT = {
	{ "Fire", "FIRE", Vector2.new(0.885, 0.50), 96 },
	{ "Aim", "ADS", Vector2.new(0.765, 0.43), 62 },
	{ "Reload", "RLD", Vector2.new(0.955, 0.33), 56 },
	{ "Crouch", "CRCH", Vector2.new(0.70, 0.62), 56 },
	{ "Sprint", "RUN", Vector2.new(0.10, 0.48), 56 },
	{ "Heal", "MED", Vector2.new(0.69, 0.30), 52 },
	{ "CycleWeapon", "SWAP", Vector2.new(0.765, 0.62), 52 },
	{ "MagCheck", "CHK", Vector2.new(0.955, 0.62), 46 },
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
		local action, label, pos, size = spec[1], spec[2], spec[3], spec[4]
		local b = K.button(pos and gui or topGui, label, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = pos and UDim2.fromScale(pos.X, pos.Y) or UDim2.fromOffset(0, -100),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.35, TextSize = (size > 80) and 18 or 13, Selectable = false,
		})
		K.new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
		buttons[action] = b
		local last = nil
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				last = Vector2.new(input.Position.X, input.Position.Y)
				c.Input.trigger(action, true)
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				last = nil
				c.Input.trigger(action, false)
			end
		end)
		if action == "Fire" or action == "MountFire" then
			b.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch and last then
					local p = Vector2.new(input.Position.X, input.Position.Y)
					c.Camera.addLook((p.X - last.X) * 0.8, (p.Y - last.Y) * 0.8)
					last = p
				end
			end)
		end
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

return Touch
