--!nonstrict
-- Player settings (persisted in the profile) + graphics presets (quality 0 POTATO, 1 LOW, 2 MEDIUM, 3 HIGH).
-- Presets change presentation only, never what the server simulates.
local Lighting = game:GetService("Lighting")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)

local Settings = {
	data = {
		fov = Config.FOV, sens = 1, quality = 3, autoGfx = true, shake = 1, reduceMotion = false, film = true, reticle = false, adsToggle = false,
		grain = 0.5, lens = true, mblur = true, curve = false, hudScale = 1, hitfx = false,
		aimOnFire = true, joyFloat = true, -- touch: FIRE aims down sights while held; the stick comes to the thumb (Touch.luau)
		touchLayout = nil, -- touch: the player's own layout ({ [id] = { x, y, s, o, h } }, TouchLayout.sanitize)
		wish = {}, -- Tarkov's wish list (item ids)
		pins = {}, -- pinned tasks (task ids; Tarkov 0.16.7 keeps them at the top of the TASKS list)
		binds = {}, quick = {}, -- rebound PC keys (Input.setBinds) and Tarkov quick slots 4 to 0 (item guids)
		-- Tarkov's GAME / POSTFX / SOUND / CONTROLS rows (docs/design/EFT_PARITY.md section 5)
		headBob = 1, quickBar = 1, aimSens = 1,
		-- Tarkov's HEALTH CONDITION and STAMINA AND STANCE (1 always shown, 2 auto-hide, 3 never) and HEALTH COLOR SCHEME
		-- (1 polychrome, 2 monochrome) (audit ui-1a)
		hudHealth = 1, hudStamina = 2, hudColors = 1,
		-- audit ui.7, ui.8, ui.6: a sensitivity per input, invert Y, Tarkov's malfunction notice and double-click use,
		-- and the time the messenger was last read (its unread count)
		padSens = 1, touchSens = 1, invertY = false, malfNotes = true, dblUse = true, msgSeen = 0,
		pfxBright = 0, pfxSat = 0, pfxClarity = 0, pfxGrade = 0, pfxGradeK = 0.5,
		volMaster = 1, volFx = 1, volUi = 1, volAmb = 1,
		-- accessibility (decision ui-8a): EFT's COLORBLIND MODE (0 none, 1 protanopia, 2 deuteranopia, 3 tritanopia) and
		-- its intensity, done on the HUD and menu colours; MENU TEXT SIZE (1 to 1.5, per device); HINTS (the control hints)
		cvdMode = 0, cvdK = 1, menuScale = 1, hints = true,
		-- RECORDER OVERLAY (decision ui-2b): 1 FULL, 2 CLEAN (default), 3 OFF; `film` was its old on/off
		recOverlay = 2,
	},
}
local SoundService = game:GetService("SoundService")
-- colour grading tints (our own presets in the spirit of Tarkov's filters)
local GRADES = { Color3.fromRGB(196, 214, 255), Color3.fromRGB(255, 218, 178), Color3.fromRGB(212, 236, 196), Color3.fromRGB(232, 204, 244) }
local pfx

local function applyPostFX(d)
	if not pfx or not pfx.Parent then
		pfx = Lighting:FindFirstChild("ZR_PlayerPostFX") or Instance.new("ColorCorrectionEffect")
		pfx.Name = "ZR_PlayerPostFX"
		pfx.Parent = Lighting
	end
	pfx.Brightness = d.pfxBright or 0
	pfx.Saturation = d.pfxSat or 0
	pfx.Contrast = d.pfxClarity or 0
	local tint = GRADES[d.pfxGrade or 0]
	pfx.TintColor = tint and Color3.new(1, 1, 1):Lerp(tint, d.pfxGradeK or 0.5) or Color3.new(1, 1, 1)
end

-- sound volumes: world effects run through Effects' ZR_World group (it multiplies in Settings.fxVolume()),
-- interface and looped ambience get their own groups; a sound nobody grouped is sorted when it appears
local groups = {}
local function group(name)
	local g = SoundService:FindFirstChild(name) or Instance.new("SoundGroup")
	g.Name = name
	g.Parent = SoundService
	return g
end
function Settings.fxVolume()
	local d = Settings.data
	return (d.volMaster or 1) * (d.volFx or 1)
end
local function applyVolumes(d)
	groups.ui.Volume = (d.volMaster or 1) * (d.volUi or 1)
	groups.amb.Volume = (d.volMaster or 1) * (d.volAmb or 1)
end
local function sortSound(snd)
	task.defer(function()
		if snd.SoundGroup or not snd.Parent then
			return
		end
		local n = string.lower(snd.Name)
		local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if (pg and snd:IsDescendantOf(pg)) or string.find(n, "click", 1, true) or string.sub(n, 1, 3) == "ui_" then
			snd.SoundGroup = groups.ui
		elseif snd.Looped then
			snd.SoundGroup = groups.amb
		else
			snd.SoundGroup = SoundService:FindFirstChild("ZR_World")
		end
	end)
end
local ctx
local loadedFromServer = false
local changedEvent = Instance.new("BindableEvent")
Settings.changed = changedEvent.Event

local bindSig = nil
function Settings.apply()
	-- rebuild the key bindings only when they changed
	local parts = {}
	for a, b in Settings.data.binds or {} do
		table.insert(parts, a .. "=" .. tostring(b.key) .. "+" .. tostring(b.mod))
	end
	table.sort(parts)
	local sig = table.concat(parts, ";")
	if sig ~= bindSig and ctx and ctx.Input and ctx.Input.setBinds then
		bindSig = sig
		ctx.Input.setBinds(Settings.data.binds)
	end
	applyPostFX(Settings.data)
	if groups.ui then
		applyVolumes(Settings.data)
	end
	-- accessibility (ui-8a): the menu and HUD palettes, the menu scale; an open screen is built again to take them
	local K = ctx and ctx.UiKit
	if K and K.setCvd then
		local recoloured = K.setCvd(Settings.data.cvdMode, Settings.data.cvdK)
		local rescaled = K.setMenuScale(Settings.data.menuScale)
		Settings.restyled = recoloured or rescaled
	end
	changedEvent:Fire(Settings.data)
end

-- rebind one PC action (key = KeyCode name, nil restores the default)
function Settings.setBind(action, key, mod)
	Settings.data.binds = Settings.data.binds or {}
	Settings.data.binds[action] = key and { key = key, mod = mod } or nil
	Settings.apply()
	if ctx then
		ctx.State.req("settings", { bind = { action = action, key = key, mod = mod } })
	end
end

function Settings.resetBinds()
	Settings.data.binds = {}
	Settings.apply()
	if ctx then
		ctx.State.req("settings", { bindsReset = true })
	end
end

-- Tarkov's wish list: an item id on or off
function Settings.setWish(id, on)
	Settings.data.wish = Settings.data.wish or {}
	Settings.data.wish[id] = on or nil
	Settings.apply()
	if ctx then
		ctx.State.req("settings", { wish = { id = id, on = on == true } })
	end
end

-- Tarkov quick slot ("4".."0") -> item guid; one key per item
function Settings.setQuick(slot, g)
	local q = Settings.data.quick
	for k, v in q do
		if v == g then
			q[k] = nil
		end
	end
	q[slot] = g
	Settings.apply()
	if ctx then
		ctx.State.req("settings", { quick = { slot = slot, g = g or "" } })
	end
end

-- Graphics level, FOV, sensitivity and grain are kept per kind of device, so a phone does not inherit the PC's HIGH
-- (audit tech-3 and quick win tech.8). Phones start at LOW, consoles at MEDIUM, PCs at HIGH; HOLD 30 FPS (Detail)
-- still steps the level down when a device cannot keep up.
local PER_DEVICE = { quality = true, fov = true, sens = true, grain = true, menuScale = true }
local CLASS_QUALITY = { phone = 1, console = 2, pc = 3 }
local deviceClass = nil
function Settings.deviceClass(): string
	if not deviceClass then
		local UIS = game:GetService("UserInputService")
		local GuiService = game:GetService("GuiService")
		if GuiService:IsTenFootInterface() then
			deviceClass = "console"
		elseif UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.MouseEnabled then
			deviceClass = "phone"
		else
			deviceClass = "pc"
		end
	end
	return deviceClass
end

function Settings.set(key, value)
	Settings.data[key] = value
	local payload = { [key] = value }
	if PER_DEVICE[key] then
		local cls = Settings.deviceClass()
		Settings.data.dev = Settings.data.dev or {}
		Settings.data.dev[cls] = Settings.data.dev[cls] or {}
		Settings.data.dev[cls][key] = value
		payload.dev = { [cls] = { [key] = value } }
	end
	Settings.apply()
	if ctx then
		ctx.State.req("settings", payload)
	end
end

-- settings with no default (absent until the player makes one) and the type the profile must hold for them
local OPTIONAL = { touchLayout = "table", dev = "table" }

-- the profile's settings as the server sent them on join: each known key of the right type replaces the default, then
-- this device's own graphics level, FOV, sensitivity and grain (or its class's starting level) go on top
function Settings.fromServer(s)
	if type(s) ~= "table" then
		return
	end
	for k, v in s do
		local want = OPTIONAL[k] or (Settings.data[k] ~= nil and type(Settings.data[k]))
		if want and type(v) == want then
			Settings.data[k] = v
		end
	end
	-- the old RECORDER OVERLAY switch: a player who had turned it off keeps it off
	if s.film == false and s.recOverlay == nil then
		Settings.data.recOverlay = 3
	end
	local cls = Settings.deviceClass()
	local mine = type(Settings.data.dev) == "table" and Settings.data.dev[cls]
	if not (type(mine) == "table" and type(mine.quality) == "number") and cls ~= "pc" then
		-- first time on this kind of device: its starting level (a PC keeps the level saved before levels were per device)
		Settings.data.quality = CLASS_QUALITY[cls] or Settings.data.quality
	end
	if type(mine) == "table" then
		for k in PER_DEVICE do
			if type(mine[k]) == type(Settings.data[k]) then
				Settings.data[k] = mine[k]
			end
		end
	end
	Settings.apply()
end

function Settings.init(c)
	ctx = c
	groups.ui, groups.amb = group("ZR_Interface"), group("ZR_Ambient")
	for _, root in { workspace, SoundService, Lighting, game:GetService("Players").LocalPlayer } do
		for _, d in root:GetDescendants() do
			if d:IsA("Sound") then
				sortSound(d)
			end
		end
		root.DescendantAdded:Connect(function(d)
			if d:IsA("Sound") then
				sortSound(d)
			end
		end)
	end
	c.State.changed:Connect(function(snap)
		if not loadedFromServer and snap.settings then
			loadedFromServer = true
			Settings.fromServer(snap.settings)
		end
	end)
	-- graphics (quality): 3 HIGH by default on every platform, phones included (owner decision, M12);
	-- MEDIUM, LOW and POTATO are opt-in. Small touch screens only start with lighter film grain.
	local UIS = game:GetService("UserInputService")
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then
		Settings.data.grain = 0.35
	end
	task.defer(Settings.apply)
end

return Settings
