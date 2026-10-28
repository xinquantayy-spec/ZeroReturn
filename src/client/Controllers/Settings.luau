--!nonstrict
-- Player settings (persisted in the profile) + quality presets. Presets change presentation only.
local Lighting = game:GetService("Lighting")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)

local Settings = {
	data = { fov = Config.FOV, sens = 1, quality = 2, shake = 1, reduceMotion = false, film = true, reticle = true, adsToggle = false },
}
local ctx
local loadedFromServer = false
local changedEvent = Instance.new("BindableEvent")
Settings.changed = changedEvent.Event

function Settings.apply()
	local d = Settings.data
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Enabled = d.quality >= 2
	end
	local grade = Lighting:FindFirstChild("ZR_Grade")
	if grade then
		grade.Enabled = d.quality >= 2 or d.film
	end
	changedEvent:Fire(d)
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
	-- low-end touch devices start on LOW unless the player chose otherwise
	local UIS = game:GetService("UserInputService")
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then
		Settings.data.quality = 1
		Settings.data.film = false
	end
	task.defer(Settings.apply)
end

return Settings
