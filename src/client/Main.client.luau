--!nonstrict
-- Zero Return client bootstrap: controllers share one ctx table; explicit init order.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = { "UiKit", "State", "Settings", "Input", "Effects", "Camera", "Movement", "Weapon", "Grenade", "Animator", "Hud", "Post", "Atmos", "Interact", "Touch", "Inventory", "Screens", "Trade" }
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
			local W, M = ctx.Weapon, ctx.Movement
			local vmModel = workspace.CurrentCamera:FindFirstChild("ZR_Viewmodel")
			return HttpService:JSONEncode({
				phase = ctx.State.data and ctx.State.data.phase, ammo = W.ammo, spare = W.spare, hasWeapon = W.hasWeapon,
				reloading = W.reloading, aiming = W.aiming, crouching = M.crouching, stamina = math.floor(M.stamina),
				weapon = W.weaponName, slot = W.slot, mode = W.modeName, drawing = W.drawing, checking = W.checking,
				light = W.light, scoped = W.scoped, melee = W.melee, vmParts = vmModel and #vmModel:GetChildren() or 0,
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
		elseif cmd == "traders" then
			ctx.Trade.traders(a)
			return "ok"
		elseif cmd == "hideout" then
			ctx.Trade.hideout()
			return "ok"
		elseif cmd == "closeModal" then
			ctx.Screens.close()
			return "ok"
		elseif cmd == "settings" then
			ctx.Screens.settings()
			return "ok"
		elseif cmd == "aim" then
			ctx.Weapon.setAim(a == true)
			return "ok"
		elseif cmd == "switch" then
			ctx.Weapon.switchTo(a)
			return "ok"
		elseif cmd == "cycle" then
			ctx.Weapon.cycleWeapon()
			return "ok"
		elseif cmd == "magcheck" then
			ctx.Weapon.magCheck()
			return "ok"
		elseif cmd == "light" then
			ctx.Weapon.toggleLight()
			return tostring(ctx.Weapon.light)
		elseif cmd == "slash" then
			ctx.Weapon.slash()
			return "ok"
		elseif cmd == "tune" then
			-- a = { key = value, ... } (viewmodel TUNE); rebuilds so sizes/scale apply
			for k, v in a or {} do
				ctx.Weapon.TUNE[k] = v
			end
			ctx.Weapon.rebuild()
			return "ok"
		elseif cmd == "pose" then
			-- a = { kind = "long", name = "hip", cf = CFrame }
			ctx.Weapon.POSE[a.kind][a.name] = a.cf
			return "ok"
		elseif cmd == "stance" then
			-- a = "s" | "c" | "p"
			ctx.Movement.setStance(a)
			return "ok"
		elseif cmd == "lean" then
			ctx.Movement.leanTarget = a or 0
			return "ok"
		elseif cmd == "move" then
			local M = ctx.Movement
			return HttpService:JSONEncode({
				stance = M.stance, depth = M.depth, lean = M.lean, speedStep = M.speedStep, stamina = math.floor(M.stamina), arms = math.floor(M.arms),
				weight = math.floor(M.weight * 10) / 10, vaulting = M.vaulting, busy = M.busy(), breath = M.breath,
				walkSpeed = (game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") or {}).WalkSpeed,
				hip = (game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") or {}).HipHeight,
			})
		elseif cmd == "orbit" then
			-- a = { dist, yaw, pitch, h, target = model name (AI or player) } or nil to return to first person
			if a and a.target then
				local ai = workspace:FindFirstChild("ZR_AI")
				local cp = workspace:FindFirstChild("ZR_Corpses")
				local sr = workspace:FindFirstChild("ZR_Showroom")
				local pl = Players:FindFirstChild(a.target)
				a.model = (ai and ai:FindFirstChild(a.target)) or (cp and cp:FindFirstChild(a.target)) or (sr and sr:FindFirstChild(a.target)) or (pl and pl.Character) or nil
			end
			ctx.Camera.orbit = a
			return "ok"
		elseif cmd == "firemode" then
			ctx.Input.trigger("FireMode", true)
			ctx.Input.trigger("FireMode", false)
			return ctx.Weapon.modeName
		elseif cmd == "studio" then
			-- capture mode: no HUD or lens overlays, no post effects, neutral daylight (a = true / false)
			local on = a ~= false
			local Lighting = game:GetService("Lighting")
			ctx.Atmos.frozen, ctx.Post.frozen, ctx.studio = on, on, on
			local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
			for _, g in pg:GetChildren() do
				if g:IsA("ScreenGui") then
					if on then
						if g:GetAttribute("StudioWas") == nil then
							g:SetAttribute("StudioWas", g.Enabled)
						end
						g.Enabled = false
					elseif g:GetAttribute("StudioWas") ~= nil then
						g.Enabled = g:GetAttribute("StudioWas")
						g:SetAttribute("StudioWas", nil)
					end
				end
			end
			for _, e in Lighting:GetChildren() do
				if e:IsA("PostEffect") then
					e.Enabled = not on
				end
			end
			if on then
				Lighting.ClockTime, Lighting.Brightness, Lighting.ExposureCompensation = 13.5, 2.2, 0
				Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(110, 112, 114), Color3.fromRGB(140, 142, 144)
				Lighting.FogEnd, Lighting.GlobalShadows = 100000, true
				local atm = Lighting:FindFirstChildOfClass("Atmosphere")
				if atm then
					atm.Density, atm.Haze, atm.Glare = 0.05, 0, 0
				end
			else
				ctx.Post.apply()
			end
			return "studio=" .. tostring(on)
		elseif cmd == "look" then
			ctx.Camera.yaw, ctx.Camera.pitch = math.rad(a and a.yaw or 0), math.rad(a and a.pitch or 0)
			return "ok"
		elseif cmd == "nade" then
			-- a = { hold = seconds, under = bool }: press G, hold, release
			return ctx.Grenade.testThrow(a and a.hold, a and a.under)
		elseif cmd == "hidden" then
			-- first-person hidden set vs the character's parts (C12: no growth with equipment churn)
			local me = Players.LocalPlayer.Character
			local parts = 0
			for _, d in me and me:GetDescendants() or {} do
				if d:IsA("BasePart") then
					parts += 1
				end
			end
			return string.format("hidden=%d parts=%d", ctx.Camera.hiddenCount(), parts)
		elseif cmd == "nadeState" then
			return tostring(ctx.Grenade.state)
		elseif cmd == "nadeTune" then
			-- a = { key = CFrame | number }: first-person grenade hand poses (Grenade.POSE)
			for k, v in a or {} do
				ctx.Grenade.POSE[k] = v
			end
			return "ok"
		end
		return "unknown"
	end
	bf.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")
end
print("[ZR] client ready; input:", ctx.Input.backend)
