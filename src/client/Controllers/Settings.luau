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
		wish = {}, -- Tarkov's wish list (item ids)
		binds = {}, quick = {}, -- rebound PC keys (Input.setBinds) and Tarkov quick slots 4 to 0 (item guids)
		-- Tarkov's GAME / POSTFX / SOUND / CONTROLS rows (docs/design/EFT_PARITY.md section 5)
		headBob = 1, quickBar = 1, aimSens = 1,
		pfxBright = 0, pfxSat = 0, pfxClarity = 0, pfxGrade = 0, pfxGradeK = 0.5,
		volMaster = 1, volFx = 1, volUi = 1, volAmb = 1,
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

function Settings.set(key, value)
	Settings.data[key] = value
	Settings.apply()
	if ctx then
		ctx.State.req("settings", { [key] = value })
	end
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
			for k, v in snap.settings do
				if Settings.data[k] ~= nil and type(v) == type(Settings.data[k]) then
					Settings.data[k] = v
				end
			end
			Settings.apply()
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
