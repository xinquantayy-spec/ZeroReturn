--!nonstrict
-- Touch layout: thumb-reachable action cluster on the right (Roblox thumbstick + jump stay on default
-- positions). FIRE also drags to aim. Visible only when touch is the preferred input and no menu is open.
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Touch = {}
local ctx, K
local gui
local buttons = {}

-- action, label, anchor position (scale), size px
local LAYOUT = {
	{ "Fire", "FIRE", Vector2.new(0.885, 0.50), 96 },
	{ "Aim", "ADS", Vector2.new(0.765, 0.43), 62 },
	{ "Reload", "RLD", Vector2.new(0.955, 0.33), 56 },
	{ "Crouch", "CRCH", Vector2.new(0.70, 0.62), 56 },
	{ "Sprint", "RUN", Vector2.new(0.10, 0.48), 56 },
	{ "Heal", "MED", Vector2.new(0.69, 0.30), 52 },
	{ "Inventory", "BAG", Vector2.new(0.955, 0.14), 52 },
	{ "Extracts", "EXIT", Vector2.new(0.875, 0.14), 52 },
	{ "Settings", "SET", Vector2.new(0.795, 0.14), 52 },
	{ "CycleWeapon", "SWAP", Vector2.new(0.765, 0.62), 52 },
	{ "MagCheck", "CHK", Vector2.new(0.955, 0.62), 46 },
	{ "LeanLeft", "LN-L", Vector2.new(0.62, 0.74), 46 },
	{ "LeanRight", "LN-R", Vector2.new(0.70, 0.80), 46 },
	{ "Prone", "PRN", Vector2.new(0.62, 0.86), 46 },
}

local function refresh()
	if not gui then
		return
	end
	local touch = ctx.Input.device() == "Touch" or (UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.GamepadEnabled)
	gui.Enabled = touch and not ctx.Input.isMenu()
	local inRaid = ctx.State.inRaid()
	for action, b in buttons do
		local raidOnly = action ~= "Inventory" and action ~= "Settings" and action ~= "Sprint" and action ~= "Crouch"
		b.Visible = inRaid or not raidOnly
		if action == "Aim" then
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
end

function Touch.init(c)
	ctx = c
	K = c.UiKit
	gui = K.screen("ZR_Touch", 6)
	gui.Enabled = false
	for _, spec in LAYOUT do
		local action, label, pos, size = spec[1], spec[2], spec[3], spec[4]
		local b = K.button(gui, label, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(pos.X, pos.Y), Size = UDim2.fromOffset(size, size),
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
		if action == "Fire" then
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
