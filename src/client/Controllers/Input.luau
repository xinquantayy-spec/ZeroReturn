--!nonstrict
-- Action adapter. Primary: Roblox Input Action System (InputContext/InputAction/InputBinding) built from
-- shared InputMap. Fallback: ContextActionService. Touch buttons call Input.trigger. Contexts: play/global/menu.
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local InputMap = require(Shared.InputMap)

local Input = { backend = "none", actions = {} }
local handlers = {}
local down = {}
local contexts = {}
local menu = false
local deviceEvent = Instance.new("BindableEvent")
Input.deviceChanged = deviceEvent.Event
local lastDevice = nil

local function dispatch(action, isDown)
	if down[action] == isDown then
		return
	end
	down[action] = isDown
	for _, fn in handlers[action] or {} do
		task.spawn(fn, isDown)
	end
end

function Input.on(action, fn)
	handlers[action] = handlers[action] or {}
	table.insert(handlers[action], fn)
end

function Input.down(action)
	return down[action] == true
end

function Input.isMenu()
	return menu
end

function Input.trigger(action, isDown)
	local spec = InputMap[action]
	if isDown and menu and spec and spec.context == "play" then
		return
	end
	dispatch(action, isDown)
end

local function setupIAS(container)
	return pcall(function()
		for name, prio in { play = 10, global = 15, menu = 20 } do
			local c = Instance.new("InputContext")
			c.Name = "ZR_" .. name
			c.Priority = prio
			c.Sink = false
			c.Enabled = name ~= "menu"
			c.Parent = container
			contexts[name] = c
		end
		for action, spec in InputMap do
			local a = Instance.new("InputAction")
			a.Name = action
			a.Type = Enum.InputActionType.Bool
			for _, k in spec.keys do
				local b = Instance.new("InputBinding")
				b.KeyCode = k
				b.Parent = a
			end
			for _, k in spec.pad do
				local b = Instance.new("InputBinding")
				b.KeyCode = k
				b.Parent = a
			end
			a.Parent = contexts[spec.context]
			a.Pressed:Connect(function()
				if UIS:GetFocusedTextBox() then
					return
				end
				dispatch(action, true)
			end)
			a.Released:Connect(function()
				dispatch(action, false)
			end)
			Input.actions[action] = a
		end
	end)
end

local function setupCAS()
	for action, spec in InputMap do
		local inputs = {}
		for _, k in spec.keys do
			if k == Enum.KeyCode.MouseLeftButton then
				table.insert(inputs, Enum.UserInputType.MouseButton1)
			elseif k == Enum.KeyCode.MouseRightButton then
				table.insert(inputs, Enum.UserInputType.MouseButton2)
			else
				table.insert(inputs, k)
			end
		end
		for _, k in spec.pad do
			table.insert(inputs, k)
		end
		CAS:BindActionAtPriority("ZR_" .. action, function(_, state)
			if state == Enum.UserInputState.Begin then
				if menu and spec.context == "play" then
					return Enum.ContextActionResult.Pass
				end
				if menu == false and spec.context == "menu" then
					return Enum.ContextActionResult.Pass
				end
				dispatch(action, true)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				dispatch(action, false)
			end
			return Enum.ContextActionResult.Pass
		end, false, 2000, table.unpack(inputs))
	end
end

function Input.setMenu(open)
	menu = open
	if Input.backend == "IAS" then
		contexts.play.Enabled = not open
		contexts.menu.Enabled = open
	end
	if open then
		for action, spec in InputMap do
			if spec.context == "play" and down[action] then
				dispatch(action, false)
			end
		end
	end
end

function Input.device()
	local ok, pi = pcall(function()
		return UIS.PreferredInput
	end)
	if ok and pi then
		if pi == Enum.PreferredInput.Gamepad then
			return "Gamepad"
		elseif pi == Enum.PreferredInput.Touch then
			return "Touch"
		end
		return "KBM"
	end
	local last = UIS:GetLastInputType()
	if last.Name:find("Gamepad") then
		return "Gamepad"
	elseif last == Enum.UserInputType.Touch then
		return "Touch"
	end
	return "KBM"
end

local LABELS = {
	KBM = {
		Fire = "LMB", Aim = "RMB", Reload = "R", Sprint = "SHIFT", Crouch = "C", Heal = "H", FireMode = "V", Extracts = "O", Inventory = "TAB",
		Settings = "P", Back = "BKSP", Interact = "E", Primary = "1", Secondary = "2", Sidearm = "3", Knife = "4", MagCheck = "T", Light = "L",
	},
	Gamepad = {
		Fire = "RT", Aim = "LT", Reload = "X", Sprint = "L3", Crouch = "B", Heal = "D-UP", FireMode = "D-RIGHT", Extracts = "D-DOWN", Inventory = "Y",
		Settings = "VIEW", Back = "B", Interact = "X", CycleWeapon = "D-LEFT", MagCheck = "R3",
	},
	Touch = { Interact = "TAP", CycleWeapon = "SWAP", MagCheck = "CHK" },
}
function Input.label(action)
	local dev = Input.device()
	return (LABELS[dev] and LABELS[dev][action]) or LABELS.KBM[action] or action
end

function Input.init(_ctx)
	local container = script
	local ok = setupIAS(container)
	if ok then
		Input.backend = "IAS"
	else
		for _, c in contexts do
			c:Destroy()
		end
		table.clear(contexts)
		setupCAS()
		Input.backend = "CAS"
	end
	print("[ZR] input backend:", Input.backend)
	lastDevice = Input.device()
	local function check()
		local d = Input.device()
		if d ~= lastDevice then
			lastDevice = d
			deviceEvent:Fire(d)
		end
	end
	pcall(function()
		UIS:GetPropertyChangedSignal("PreferredInput"):Connect(check)
	end)
	UIS.LastInputTypeChanged:Connect(check)
end

return Input
