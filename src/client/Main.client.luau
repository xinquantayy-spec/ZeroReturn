--!nonstrict
-- Zero Return client bootstrap: controllers share one ctx table; explicit init order.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = { "UiKit", "State", "Settings", "Input", "Effects", "Camera", "Weapon", "Animator", "Hud", "Post", "Interact", "Touch", "Inventory", "Screens" }
local ctx = {}
for _, name in ORDER do
	ctx[name] = require(Controllers:WaitForChild(name))
end
for _, name in ORDER do
	local m = ctx[name]
	if m.init then
		local ok, err = pcall(m.init, ctx)
		if not ok then
			warn("[ZR] client init failed:", name, err)
		end
	end
end

task.spawn(function()
	for _ = 1, 30 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

-- Studio-only client test bridge (driven via MCP execute_luau in the Client datamodel)
if RunService:IsStudio() then
	local bf = Instance.new("BindableFunction")
	bf.Name = "ZR_ClientDev"
	bf.OnInvoke = function(cmd, a)
		if cmd == "state" then
			local W = ctx.Weapon
			return HttpService:JSONEncode({
				phase = ctx.State.data and ctx.State.data.phase, ammo = W.ammo, spare = W.spare, hasWeapon = W.hasWeapon,
				reloading = W.reloading, aiming = W.aiming, crouching = W.crouching, stamina = math.floor(W.stamina),
				input = ctx.Input.backend, device = ctx.Input.device(), invOpen = ctx.Inventory.open,
				modal = ctx.Screens.modal and ctx.Screens.modal:FindFirstChildOfClass("TextLabel").Text or nil,
				prompt = ctx.Interact.current and ctx.Interact.current.ObjectText or nil,
			})
		elseif cmd == "fire" then
			return ctx.Weapon.fireForTest(a or 1)
		elseif cmd == "reload" then
			ctx.Weapon.startReload()
			return "reload requested"
		elseif cmd == "inv" then
			ctx.Inventory.toggle()
			return tostring(ctx.Inventory.open)
		elseif cmd == "deployScreen" then
			ctx.Screens.deploy()
			return "ok"
		elseif cmd == "closeModal" then
			ctx.Screens.close()
			return "ok"
		elseif cmd == "settings" then
			ctx.Screens.settings()
			return "ok"
		elseif cmd == "aim" then
			ctx.Weapon.aiming = a == true
			return "ok"
		elseif cmd == "look" then
			ctx.Camera.yaw, ctx.Camera.pitch = math.rad(a and a.yaw or 0), math.rad(a and a.pitch or 0)
			return "ok"
		end
		return "unknown"
	end
	bf.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")
end
print("[ZR] client ready; input:", ctx.Input.backend)
