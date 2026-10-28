--!nonstrict
-- First-person bodycam: scriptable camera with mount lag, footfall bob, strafe/turn roll, idle breathing,
-- landing dips, damage flinch, recoil climb + recovery, wide lens FOV with ADS narrowing.
-- Mouse, right stick and touch-drag look. Reduce-motion aware.
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
local flinchP, flinchY, flinchR = 0, 0, 0
local land, landV = 0, 0
local lastYaw = 0
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

-- damage flinch (radians-ish impulse scaled by severity)
function Camera.flinch(a)
	local k = (ctx.Settings.data.shake or 1) * math.clamp(a or 0.5, 0, 1.5)
	flinchP += (math.random() * 0.6 + 0.4) * 0.05 * k
	flinchY += (math.random() * 2 - 1) * 0.04 * k
	flinchR += (math.random() * 2 - 1) * 0.06 * k
end

function Camera.impact(a)
	landV -= math.clamp(a or 0.5, 0, 1.5) * 4.5
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
	local hum = char:WaitForChild("Humanoid", 5)
	if hum then
		local fallSpeed = 0
		hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Freefall then
				fallSpeed = 0
			elseif new == Enum.HumanoidStateType.Landed and root then
				Camera.impact(math.clamp(fallSpeed / 45, 0.15, 1.4))
			end
		end)
		hum.FreeFalling:Connect(function()
			task.spawn(function()
				while hum.Parent and hum:GetState() == Enum.HumanoidStateType.Freefall do
					fallSpeed = math.max(fallSpeed, -(root.AssemblyLinearVelocity.Y))
					task.wait()
				end
			end)
		end)
	end
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
	local sens = (S.sens or 1) * (aiming and (ctx.Weapon.aimSens and ctx.Weapon.aimSens() or 0.62) or 1)
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
	local kf = math.min(1, dt * 7)
	flinchP -= flinchP * kf
	flinchY -= flinchY * kf
	flinchR -= flinchR * kf
	-- landing dip: critically damped spring
	landV += (-120 * land - 18 * landV) * dt
	land += landV * dt

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local orbit = Camera.orbit -- Studio inspection view of your own character (dev bridge "orbit")
	for _, p in hidden do
		p.LocalTransparencyModifier = orbit and 0 or 1
	end
	if not (hum and root) then
		return
	end
	if orbit then
		local center = root.Position + Vector3.new(0, orbit.h or 1.2, 0)
		cam.CFrame = CFrame.new(center) * CFrame.Angles(0, Camera.yaw + (orbit.yaw or 0), 0) * CFrame.Angles(orbit.pitch or -0.2, 0, 0) * CFrame.new(0, 0, orbit.dist or 8)
		cam.FieldOfView = 50
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
		Camera.bobPhase += dt * (4.4 + flatSpeed * 0.36)
	end
	-- footfall bob: a dip on every step (|sin|), lateral sway once per stride, plus a little step roll
	local amp = math.clamp(flatSpeed / 14, 0, 1.3) * 0.085 * motion * (aiming and 0.35 or 1)
	local stepS = math.sin(Camera.bobPhase)
	local bobY = (0.5 - math.abs(stepS)) * amp * 1.3
	local bobX = math.cos(Camera.bobPhase) * amp * 0.55
	local stepRoll = math.cos(Camera.bobPhase) * amp * 0.11
	local localVel = root.CFrame:VectorToObjectSpace(vel)
	local yawVel = dt > 0 and (Camera.yaw - lastYaw) / dt or 0
	lastYaw = Camera.yaw
	local turnRoll = math.clamp(-yawVel * 0.006, -0.045, 0.045)
	roll += ((-localVel.X * 0.0045 + turnRoll) * motion - roll) * math.min(1, dt * 6)
	-- idle breathing (affects aim slightly, as a body-worn camera would)
	local t = os.clock()
	local breathe = (aiming and 0.5 or 1) * motion
	local breathP = math.sin(t * 1.65) * 0.0026 * breathe
	local breathY = math.sin(t * 0.83 + 1.3) * 0.0019 * breathe
	local tr = (Camera.tremor or 0) * (aiming and 1 or 0.35)
	if tr > 0 then
		breathP += (math.noise(t * 7, 1.7) * 0.006 + math.sin(t * 23) * 0.0012) * tr
		breathY += (math.noise(t * 7, 9.1) * 0.006) * tr
	end
	local target = root.Position + Vector3.new(0, eyeOffset, 0)
	if smoothPos then
		smoothPos = smoothPos:Lerp(target, math.min(1, dt * 22))
		if (smoothPos - target).Magnitude > 3 then
			smoothPos = target
		end
	else
		smoothPos = target
	end
	local rot = CFrame.Angles(0, Camera.yaw + breathY + flinchY, 0) * CFrame.Angles(Camera.pitch + recoilP + breathP + flinchP + land * 0.02, recoilY, roll + stepRoll + flinchR)
	cam.CFrame = CFrame.new(smoothPos) * rot * CFrame.new(bobX, bobY + land * 0.35, -0.3)
	local baseFov = S.fov or Config.FOV
	local fovTarget = aiming and (ctx.Weapon.aimFov and ctx.Weapon.aimFov(baseFov) or baseFov * Config.AIM_FOV_MUL) or baseFov
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
