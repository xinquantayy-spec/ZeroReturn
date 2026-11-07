--!nonstrict
-- Action adapter. Primary: Roblox Input Action System (InputContext/InputAction/InputBinding) built from
-- shared InputMap. Fallback: ContextActionService. Touch buttons call Input.trigger. Contexts: play/global/menu.
-- PC keys are Tarkov's defaults; chords (Alt+T, Shift+T, Alt+B) are resolved here: an action with `mod` fires
-- only with that modifier held, and a key's plain action only without any of its chord modifiers. Players can
-- rebind PC keys (Settings: binds), which rebuilds the bindings.
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local InputMap = require(Shared.InputMap)

local Input = { backend = "none", actions = {} }
local handlers = {}
local down = {}
local contexts = {}
local menu = false
local mounted = false -- at a stationary gun: the "mount" actions replace the "play" ones
local deviceEvent = Instance.new("BindableEvent")
Input.deviceChanged = deviceEvent.Event
local lastDevice = nil
local overrides = {} -- [action] = { key = "T", mod = "Alt" } (rebinding)
local container

local MODKEYS = {
	Alt = { Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt },
	Shift = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift },
	Ctrl = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl },
}
Input.MODS = { "Alt", "Shift", "Ctrl" }

local function modDown(m)
	for _, k in MODKEYS[m] or {} do
		if UIS:IsKeyDown(k) then
			return true
		end
	end
	return false
end

-- the PC keys of an action after rebinding: list of KeyCodes and its chord modifier
function Input.keysOf(action)
	local spec = InputMap[action]
	if spec and spec.like then
		return Input.keysOf(spec.like) -- follows the other action's (rebound) keys
	end
	local o = overrides[action]
	if o then
		local k = o.key and Enum.KeyCode[o.key]
		return k and { k } or {}, o.mod
	end
	return spec and spec.keys or {}, spec and spec.mod
end

-- which modifiers some action chords with each key
local chordMods = {}
local function buildChords()
	table.clear(chordMods)
	for action in InputMap do
		local keys, mod = Input.keysOf(action)
		if mod then
			for _, k in keys do
				chordMods[k] = chordMods[k] or {}
				chordMods[k][mod] = true
			end
		end
	end
end

local function keyboardOk(action)
	local keys, mod = Input.keysOf(action)
	if mod then
		return modDown(mod)
	end
	for _, k in keys do
		for m in chordMods[k] or {} do
			if modDown(m) then
				return false
			end
		end
	end
	return true
end

local function dispatch(action, isDown)
	if down[action] == isDown then
		return
	end
	down[action] = isDown
	for _, fn in handlers[action] or {} do
		task.spawn(fn, isDown)
	end
end

-- tests and dev tools: press or release an action as if its key had been used
function Input.press(action, isDown)
	dispatch(action, isDown ~= false)
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

-- is this context live: play on foot, mount at a stationary gun, menu in a menu, global always
local function contextOn(name)
	if name == "global" then
		return true
	elseif name == "menu" then
		return menu
	elseif name == "mount" then
		return mounted and not menu
	end
	return not menu and not mounted
end

local function blocked(spec)
	return (spec.context == "play" and (menu or mounted)) or (spec.context == "mount" and (menu or not mounted))
end

function Input.trigger(action, isDown)
	local spec = InputMap[action]
	if isDown and spec and blocked(spec) then
		return
	end
	dispatch(action, isDown)
end

-- ── shared gamepad buttons (InputMap padHow / padAim; KNOWN_ISSUES 76) ──────────────────────────────────────────
-- Each action bound to a pad button hears that button; this decides which of them a press is: a tap (let go within
-- HOLD), a hold (held that long; it ends when the button is let go) or a plain press, and for padAim whether the player
-- was aiming when the button went down.
Input.HOLD = 0.35
local ictx
local padState = {} -- [action] = { t0, held } for the press in progress
local function aimingNow()
	return ictx ~= nil and ictx.Weapon ~= nil and ictx.Weapon.aiming == true
end

local function padEvent(action, spec, isDown)
	local how = spec.padHow
	if how == nil and spec.padAim == nil then
		dispatch(action, isDown)
		return
	end
	if isDown then
		if spec.padAim ~= nil and spec.padAim ~= aimingNow() then
			padState[action] = nil -- this press is the other variant's
			return
		end
		local st = { t0 = os.clock(), held = false }
		padState[action] = st
		if how == "hold" then
			task.delay(Input.HOLD, function()
				if padState[action] == st and not blocked(spec) then
					st.held = true
					dispatch(action, true)
				end
			end)
		elseif how ~= "tap" then
			st.held = true
			dispatch(action, true)
		end
		return
	end
	local st = padState[action]
	padState[action] = nil
	if not st then
		return
	end
	if st.held then
		dispatch(action, false)
	elseif how == "tap" and os.clock() - st.t0 < Input.HOLD and not blocked(spec) then
		dispatch(action, true)
		dispatch(action, false)
	end
end

-- tests and the Studio bridge: press or let go of a gamepad button by name ("DPadUp"), as the bindings would hear it
function Input.padButton(keyName, isDown)
	local key = Enum.KeyCode[keyName]
	for action, spec in InputMap do
		if table.find(spec.pad or {}, key) and (not isDown or not blocked(spec)) then
			padEvent(action, spec, isDown)
		end
	end
end

local function setupIAS()
	return pcall(function()
		for name, prio in { play = 10, mount = 12, global = 15, menu = 20 } do
			local c = Instance.new("InputContext")
			c.Name = "ZR_" .. name
			c.Priority = prio
			c.Sink = false
			c.Enabled = contextOn(name)
			c.Parent = container
			contexts[name] = c
		end
		for action, spec in InputMap do
			local keys = Input.keysOf(action)
			-- keyboard and gamepad are separate actions so chords only apply to the keyboard
			for _, set in { { keys, true }, { spec.pad, false } } do
				if #set[1] > 0 then
					local a = Instance.new("InputAction")
					a.Name = action .. (set[2] and "" or "_Pad")
					a.Type = Enum.InputActionType.Bool
					for _, k in set[1] do
						local b = Instance.new("InputBinding")
						b.KeyCode = k
						b.Parent = a
					end
					a.Parent = contexts[spec.context]
					local kbd = set[2]
					a.Pressed:Connect(function()
						if UIS:GetFocusedTextBox() or (kbd and not keyboardOk(action)) then
							return
						end
						if kbd then
							dispatch(action, true)
						else
							padEvent(action, spec, true)
						end
					end)
					a.Released:Connect(function()
						if kbd then
							dispatch(action, false)
						else
							padEvent(action, spec, false)
						end
					end)
					if kbd or not Input.actions[action] then
						Input.actions[action] = a
					end
				end
			end
		end
	end)
end

local function setupCAS()
	for action, spec in InputMap do
		local inputs = {}
		for _, k in Input.keysOf(action) do
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
		if #inputs > 0 then
			CAS:BindActionAtPriority("ZR_" .. action, function(_, state, obj)
				if state == Enum.UserInputState.Begin then
					if blocked(spec) then
						return Enum.ContextActionResult.Pass
					end
					if menu == false and spec.context == "menu" then
						return Enum.ContextActionResult.Pass
					end
					local kbd = obj and (obj.UserInputType == Enum.UserInputType.Keyboard or obj.UserInputType.Name:find("Mouse") ~= nil)
					if UIS:GetFocusedTextBox() or (kbd and not keyboardOk(action)) then
						return Enum.ContextActionResult.Pass
					end
					if obj and obj.UserInputType.Name:find("Gamepad") then
						padEvent(action, spec, true)
					else
						dispatch(action, true)
					end
				elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
					if obj and obj.UserInputType.Name:find("Gamepad") then
						padEvent(action, spec, false)
					else
						dispatch(action, false)
					end
				end
				return Enum.ContextActionResult.Pass
			end, false, 2000, table.unpack(inputs))
		end
	end
end

local function teardown()
	for _, c in contexts do
		c:Destroy()
	end
	table.clear(contexts)
	table.clear(Input.actions)
	for action in InputMap do
		CAS:UnbindAction("ZR_" .. action)
	end
end

local function build()
	buildChords()
	if Input.backend ~= "CAS" and setupIAS() then
		Input.backend = "IAS"
	else
		teardown()
		setupCAS()
		Input.backend = "CAS"
	end
end

-- rebinding: overrides { [action] = { key = KeyCode name, mod = "Alt" / "Shift" / "Ctrl" / nil } }
function Input.setBinds(o)
	overrides = {}
	for action, b in o or {} do
		if InputMap[action] and type(b) == "table" and type(b.key) == "string" and pcall(function()
			return Enum.KeyCode[b.key]
		end) and (b.mod == nil or MODKEYS[b.mod]) then
			overrides[action] = { key = b.key, mod = b.mod }
		end
	end
	for action in InputMap do
		if down[action] then
			dispatch(action, false)
		end
	end
	if container then
		teardown()
		build()
	end
end

function Input.setMenu(open)
	menu = open
	if open then
		table.clear(padState)
	end
	if Input.backend == "IAS" and contexts.play then
		for name, c in contexts do
			c.Enabled = contextOn(name)
		end
	end
	if open then
		for action, spec in InputMap do
			if (spec.context == "play" or spec.context == "mount") and down[action] then
				dispatch(action, false)
			end
		end
	end
end

function Input.isMounted()
	return mounted
end

-- the Stationary controller: at a gun the personal-weapon actions are off and the mount actions are on
function Input.setMounted(on)
	on = on == true
	if mounted == on then
		return
	end
	mounted = on
	table.clear(padState)
	for action, spec in InputMap do
		if (spec.context == "play" or spec.context == "mount") and down[action] then
			dispatch(action, false)
		end
	end
	if Input.backend == "IAS" then
		for name, c in contexts do
			c.Enabled = contextOn(name)
		end
	end
end

function Input.device()
	if Input.forceDevice then
		return Input.forceDevice -- Studio test bridge (ZR_ClientDev "device"): the gamepad and touch paths without one
	end
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

-- key names for labels
local KEYNAME = {
	MouseLeftButton = "LMB", MouseRightButton = "RMB", LeftShift = "SHIFT", RightShift = "SHIFT", LeftAlt = "ALT", RightAlt = "ALT",
	LeftControl = "CTRL", RightControl = "CTRL", Backspace = "BKSP", CapsLock = "CAPS", Space = "SPACE", Return = "ENTER",
	One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
	Tab = "TAB",
}
function Input.keyName(k)
	return KEYNAME[k.Name] or string.upper(k.Name)
end

local LABELS = {
	Gamepad = {
		Fire = "RT", Aim = "LT", Reload = "X", Sprint = "L3", Crouch = "B", Heal = "D-UP", FireMode = "D-RIGHT", Extracts = "D-DOWN", Inventory = "Y",
		Settings = "VIEW", Back = "B", Interact = "X", CycleWeapon = "D-LEFT", MagCheck = "R3", LeanLeft = "LB", LeanRight = "RB",
		Grenade = "HOLD D-DOWN", MountFire = "RT", MountZoom = "LT", MountLeave = "B", TabPrev = "LB", TabNext = "RB",
		Prone = "HOLD B", ChamberCheck = "HOLD R3", FireModeCheck = "LT + R3", InspectWeapon = "HOLD Y", FreeLook = "HOLD D-UP",
		Sidearm = "D-LEFT", Primary = "D-LEFT", Secondary = "D-LEFT", Knife = "D-LEFT",
		Light = "HOLD D-RIGHT", DeviceMode = "LT + HOLD D-RIGHT", ToggleNVG = "HOLD D-LEFT", SightMode = "LT + D-LEFT",
		ZeroUp = "LT + D-UP", ZeroDown = "LT + D-DOWN",
	},
	-- touch (Touch.luau, TouchLayout.luau): the controls are icons; these name them as the layout editor does
	Touch = {
		Interact = "TAP", Fire = "FIRE", Aim = "AIM", Reload = "RELOAD", Sprint = "STICK PAST ITS RING", Crouch = "CROUCH",
		Prone = "HOLD CROUCH", Heal = "HOLD MED", MagCheck = "HOLD RELOAD", ChamberCheck = "MORE", FireMode = "MODE",
		FireModeCheck = "HOLD MODE", InspectWeapon = "HOLD WEAPON", FreeLook = "LOOK (DRAG)", Light = "MORE", DeviceMode = "MORE",
		ToggleNVG = "MORE", ZeroUp = "MORE", ZeroDown = "MORE", SightMode = "MORE", CycleWeapon = "WEAPON", Grenade = "GRENADE",
		LeanLeft = "LEAN LEFT", LeanRight = "LEAN RIGHT", Extracts = "EXITS", Inventory = "BAG", Settings = "SETTINGS",
		Sidearm = "WEAPON", Primary = "WEAPON", Secondary = "WEAPON", Knife = "WEAPON",
		Quick4 = "MED", Quick5 = "MED", Quick6 = "MED", Quick7 = "MED", Quick8 = "MED", Quick9 = "MED", Quick0 = "MED",
	},
}
-- the PC label of an action from its (rebound) keys, chords included ("ALT+T")
function Input.pcLabel(action)
	if action == "Interact" then
		return "F"
	end
	local keys, mod = Input.keysOf(action)
	if #keys == 0 then
		return "-"
	end
	return (mod and (string.upper(mod) .. "+") or "") .. Input.keyName(keys[1])
end

-- an action's gamepad or touch label, or nil when that device has no way to it
function Input.deviceLabel(dev, action)
	return LABELS[dev] and LABELS[dev][action] or nil
end

function Input.label(action)
	local dev = Input.device()
	if dev ~= "KBM" and LABELS[dev] and LABELS[dev][action] then
		return LABELS[dev][action]
	end
	return Input.pcLabel(action)
end

-- ── menu focus for the gamepad (audit ui.5) ──────────────────────────────────────────────────────────────────────
-- Roblox's menu selection (the ochre ring) is set only while a gamepad is the device in use: a mouse or a finger never
-- gets it. A screen drawn again in place (a value changed, new server state) keeps the control the player was on:
-- focusPath notes where the selection sits under the old screen as a path of names (the n-th child of that name, so
-- rows of plain frames still count), refocus finds the same path under the new screen, else selects the default
-- (the open tab).
function Input.padFocus(obj)
	if obj and obj.Parent and Input.device() == "Gamepad" then
		pcall(function()
			GuiService.SelectedObject = obj
		end)
	end
end

function Input.focusPath(root)
	local sel = GuiService.SelectedObject
	if not (root and sel and sel:IsDescendantOf(root)) then
		return nil
	end
	local path = {}
	local o = sel
	while o and o ~= root do
		local n = 0
		for _, c in o.Parent:GetChildren() do
			if c.Name == o.Name then
				n += 1
			end
			if c == o then
				break
			end
		end
		table.insert(path, 1, { o.Name, n })
		o = o.Parent
	end
	return path
end

function Input.refocus(root, path, default)
	if Input.device() ~= "Gamepad" then
		return
	end
	local o = root
	for _, step in path or {} do
		local found, n = nil, 0
		for _, c in o:GetChildren() do
			if c.Name == step[1] then
				n += 1
				if n == step[2] then
					found = c
					break
				end
			end
		end
		o = found
		if not o then
			break
		end
	end
	if path and o and o ~= root and o:IsA("GuiObject") and o.Selectable and o.Visible then
		Input.padFocus(o)
	else
		Input.padFocus(default)
	end
end

function Input.init(_ctx)
	ictx = _ctx
	container = script
	build()
	print("[ZR] input backend:", Input.backend)
	lastDevice = Input.device()
	local function check()
		local d = Input.device()
		if d ~= lastDevice then
			lastDevice = d
			if d ~= "Gamepad" then
				-- the pad was put down: no selection ring left on a menu the mouse or a finger now works (audit ui.5)
				pcall(function()
					GuiService.SelectedObject = nil
				end)
			end
			deviceEvent:Fire(d)
		end
	end
	pcall(function()
		UIS:GetPropertyChangedSignal("PreferredInput"):Connect(check)
	end)
	UIS.LastInputTypeChanged:Connect(check)
end

return Input
