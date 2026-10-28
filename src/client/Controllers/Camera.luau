--!nonstrict
-- First-person "FIELD RECORDER" camera: scriptable camera with mount lag, capped step bob/roll,
-- recoil climb + recovery, ADS FOV. Mouse, right stick and touch-drag look. Reduce-motion aware.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)

local Camera = { yaw = 0, pitch = 0, bobPhase = 0, speed = 0 }
local ctx
local cam = workspace.CurrentCamera
local player = Players.LocalPlayer
local recoilP, recoilY, roll = 0, 0, 0
local fov = Config.FOV
local stick = Vector2.zero
local lookAcc = Vector2.zero
local touchLook, touchLast = nil, nil
local hidden = {}
local eyeOffset = 1.6
local smoothPos = nil

function Camera.addLook(dx, dy)
	lookAcc += Vector2.new(dx, dy)
end

function Camera.kick(pDeg, yDeg)
	local k = (ctx.Settings.data.shake or 1)
	Camera.pitch += math.rad(pDeg) * 0.6
	recoilP += math.rad(pDeg) * 0.4 * k
	recoilY += math.rad(yDeg) * k
end

local function trackCharacter(char)
	table.clear(hidden)
	smoothPos = nil
	local function add(d)
		if d:IsA("BasePart") then
			table.insert(hidden, d)
		end
	end
	for _, d in char:GetDescendants() do
		add(d)
	end
	char.DescendantAdded:Connect(add)
	local root = char:WaitForChild("HumanoidRootPart", 5)
	local head = char:WaitForChild("Head", 5)
	if root and head then
		eyeOffset = (head.Position.Y - root.Position.Y) + 0.2
		local _, y = root.CFrame:ToEulerAnglesYXZ()
		Camera.yaw = select(2, root.CFrame:ToEulerAnglesYXZ()) or y
		Camera.pitch = 0
	end
end

local function update(dt)
	cam.CameraType = Enum.CameraType.Scriptable
	local menu = ctx.Input.isMenu()
	UIS.MouseBehavior = menu and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
	UIS.MouseIconEnabled = menu
	local S = ctx.Settings.data
	local aiming = ctx.Weapon.aiming
	local sens = (S.sens or 1) * (aiming and 0.62 or 1)
	if not menu then
		local md = UIS:GetMouseDelta()
		Camera.yaw -= math.rad(md.X * 0.2 * sens)
		Camera.pitch -= math.rad(md.Y * 0.2 * sens)
		if stick.Magnitude > 0.14 then
			local s = (stick.Magnitude - 0.14) / 0.86
			local v = stick.Unit * s * s
			Camera.yaw -= v.X * dt * 3.4 * sens
			Camera.pitch += v.Y * dt * 2.5 * sens
		end
		Camera.yaw -= math.rad(lookAcc.X * 0.28 * sens)
		Camera.pitch -= math.rad(lookAcc.Y * 0.28 * sens)
	end
	lookAcc = Vector2.zero
	Camera.pitch = math.clamp(Camera.pitch, math.rad(-80), math.rad(80))
	local k = math.min(1, dt * 10)
	recoilP -= recoilP * k
	recoilY -= recoilY * k

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	for _, p in hidden do
		p.LocalTransparencyModifier = 1
	end
	if not (hum and root) then
		return
	end
	if hum.Health <= 0 then
		local head = char:FindFirstChild("Head")
		local base = head and head.Position or root.Position
		cam.CFrame = cam.CFrame:Lerp(CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, Camera.yaw, 0) * CFrame.Angles(math.rad(-55), 0, math.rad(28)), math.min(1, dt * 2))
		return
	end
	hum.AutoRotate = false
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, Camera.yaw, 0)
	local vel = root.AssemblyLinearVelocity
	local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	Camera.speed = flatSpeed
	local motion = (S.reduceMotion and 0.25 or 1) * (S.shake or 1)
	if flatSpeed > 0.5 and hum.FloorMaterial ~= Enum.Material.Air then
		Camera.bobPhase += dt * (5.5 + flatSpeed * 0.32)
	end
	local amp = math.clamp(flatSpeed / 16, 0, 1.2) * 0.07 * motion * (aiming and 0.3 or 1)
	local bobY = math.sin(Camera.bobPhase * 2) * amp
	local bobX = math.cos(Camera.bobPhase) * amp * 0.7
	local localVel = root.CFrame:VectorToObjectSpace(vel)
	roll += ((-localVel.X * 0.0035 * motion) - roll) * math.min(1, dt * 6)
	local target = root.Position + Vector3.new(0, eyeOffset, 0)
	if smoothPos then
		smoothPos = smoothPos:Lerp(target, math.min(1, dt * 22))
		if (smoothPos - target).Magnitude > 3 then
			smoothPos = target
		end
	else
		smoothPos = target
	end
	local rot = CFrame.Angles(0, Camera.yaw, 0) * CFrame.Angles(Camera.pitch + recoilP, recoilY, roll)
	cam.CFrame = CFrame.new(smoothPos) * rot * CFrame.new(bobX, bobY, -0.3)
	local fovTarget = aiming and Config.AIM_FOV or (S.fov or Config.FOV)
	fov += (fovTarget - fov) * math.min(1, dt * 12)
	cam.FieldOfView = fov
end

function Camera.init(c)
	ctx = c
	player.CharacterAdded:Connect(trackCharacter)
	if player.Character then
		task.spawn(trackCharacter, player.Character)
	end
	UIS.InputChanged:Connect(function(input, gp)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.new(input.Position.X, input.Position.Y)
		elseif touchLook and input == touchLook then
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			if touchLast then
				Camera.addLook(pos.X - touchLast.X, pos.Y - touchLast.Y)
			end
			touchLast = pos
		end
	end)
	UIS.InputBegan:Connect(function(input, gp)
		if input.UserInputType == Enum.UserInputType.Touch and not gp and not ctx.Input.isMenu() then
			if input.Position.X > cam.ViewportSize.X * 0.4 then
				touchLook = input
				touchLast = Vector2.new(input.Position.X, input.Position.Y)
			end
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input == touchLook then
			touchLook, touchLast = nil, nil
		end
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.zero
		end
	end)
	RunService:BindToRenderStep("ZR_Camera", Enum.RenderPriority.Camera.Value + 1, update)
end

return Camera
