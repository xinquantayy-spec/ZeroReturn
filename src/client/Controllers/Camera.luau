--!nonstrict
-- First-person bodycam: scriptable camera with mount lag, footfall bob, strafe/turn roll, idle breathing,
-- landing dips, damage flinch, Tarkov's recoil (Recoil.luau: the gun and camera springs), wide lens FOV with ADS
-- narrowing. Mouse, right stick and touch-drag look. Reduce-motion aware.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local RigMath = require(Shared.RigMath)
local Recoil = require(Shared.Recoil)

-- freeYaw / freePitch: Alt free look (the body and weapon keep their aim); aimCFrame = camera without free look.
-- gunP / gunY: the gun's recoil offset from the aim point; recP / recY: the camera recoil in aimCFrame (radians)
local Camera = { yaw = 0, pitch = 0, bobPhase = 0, speed = 0, freeYaw = 0, freePitch = 0, aimCFrame = nil, gunP = 0, gunY = 0, recP = 0, recY = 0 }
local ctx
local cam = workspace.CurrentCamera
local player = Players.LocalPlayer
local recoilP, recoilY, roll = 0, 0, 0
local rec = Recoil.new() -- the recoil springs; Weapon kicks them on each shot, update steps them
local thump, thumpS = 0, 1 -- the buttstock's camera roll (radians) and its side
local flinchP, flinchY, flinchR = 0, 0, 0
local land, landV = 0, 0
local shakeAmt = 0 -- blast shake (radians), decays
local lastYaw = 0
local fov = Config.FOV
local stick = Vector2.zero
local lookAcc = Vector2.zero
local touchLook, touchLast = nil, nil
local hidden = {} -- set of local character parts hidden in first person
local eyeOffset = 1.6
local smoothPos = nil

function Camera.addLook(dx, dy)
	lookAcc += Vector2.new(dx, dy)
end

-- a shot's recoil (Weapon.fireOnce): the kick (degrees, Recoil.kick) goes into the gun's and the camera's springs; th
-- is the buttstock's roll (radians, Tarkov 0.16's camera shake). Nothing moves the aim for good: convergence brings
-- the gun back to where you aimed, and the same rule holds for mouse, stick and touch, since look input and recoil add
-- separately.
function Camera.recoilShot(prof, jp, jy, th)
	Recoil.shot(rec, prof, jp, jy)
	local S = ctx.Settings.data
	thump = math.max(thump, (th or 0) * (S.shake or 1) * (S.reduceMotion and 0.3 or 1))
	thumpS = math.random() < 0.5 and -1 or 1
end

-- where the gun points against the camera (radians: up, left). Bullets leave the barrel and the sights sit on it, so
-- the shot and the sight picture take this on top of aimCFrame.
function Camera.gunRel()
	return Camera.gunP - Camera.recP, Camera.gunY - Camera.recY
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

-- explosion nearby: a short violent shake (0..1)
function Camera.shake(a)
	local k = (ctx.Settings.data.shake or 1) * (ctx.Settings.data.reduceMotion and 0.3 or 1)
	shakeAmt = math.max(shakeAmt, math.clamp(a or 0.5, 0, 1) * 0.05 * k)
	landV -= math.clamp(a or 0.5, 0, 1) * 2.5 * k
end

-- first person: every part of the local character (body, worn gear, slung guns) is hidden for this client only
-- (LocalTransparencyModifier); other clients keep seeing the gear. The set follows the character as appearance
-- groups are rebuilt: removed parts leave it (no growth with equipment churn, C12).
local trackConns = {}
function Camera.hiddenCount()
	local n = 0
	for _ in hidden do
		n += 1
	end
	return n
end

local function trackCharacter(char)
	for _, c in trackConns do
		c:Disconnect()
	end
	table.clear(trackConns)
	table.clear(hidden)
	smoothPos = nil
	local function add(d)
		if d:IsA("BasePart") then
			hidden[d] = true
		end
	end
	for _, d in char:GetDescendants() do
		add(d)
	end
	table.insert(trackConns, char.DescendantAdded:Connect(add))
	table.insert(trackConns, char.DescendantRemoving:Connect(function(d)
		hidden[d] = nil
	end))
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
	-- turn speed: heavy armour and helmets slow turning when not aiming (Tarkov's turn speed penalty)
	local gear = ctx.Movement and ctx.Movement.gear
	-- one sensitivity per input (mouse, gamepad, touch; audit ui.7), times the aiming or turn-speed factor
	local k = aiming and (ctx.Weapon.aimSens and ctx.Weapon.aimSens() or 0.62) * (S.aimSens or 1) or (1 + (gear and gear.turn or 0) / 100)
	local sens = (S.sens or 1) * k
	local padSens = (S.padSens or 1) * k
	local touchSens = (S.touchSens or 1) * k
	local invY = S.invertY and -1 or 1
	local free = not menu and ctx.Input.down("FreeLook") and not aiming
	if not menu then
		-- the mouse, the right stick and touch drags; with free look held (Alt, hold D-up, drag LOOK) they turn the head
		-- and not the body (up to 100 degrees either way and 60 up or down, our limits)
		local md = UIS:GetMouseDelta()
		local dYaw = -math.rad(md.X * 0.2 * sens) - math.rad(lookAcc.X * 0.28 * touchSens)
		local dPitch = (-math.rad(md.Y * 0.2 * sens) - math.rad(lookAcc.Y * 0.28 * touchSens)) * invY
		if stick.Magnitude > 0.14 then
			local s = (stick.Magnitude - 0.14) / 0.86
			local v = stick.Unit * s * s
			dYaw -= v.X * dt * 3.4 * padSens
			dPitch += v.Y * dt * 2.5 * padSens * invY
		end
		if free then
			Camera.freeYaw = math.clamp(Camera.freeYaw + dYaw, math.rad(-100), math.rad(100))
			Camera.freePitch = math.clamp(Camera.freePitch + dPitch, math.rad(-60), math.rad(60))
		else
			Camera.yaw += dYaw
			Camera.pitch += dPitch
		end
	end
	lookAcc = Vector2.zero
	Camera.pitch = math.clamp(Camera.pitch, math.rad(-80), math.rad(80))
	if not free then
		local kr = math.min(1, dt * 10)
		Camera.freeYaw -= Camera.freeYaw * kr
		Camera.freePitch -= Camera.freePitch * kr
	end
	-- recoil: the springs step exactly (the same climb at 30 and 144 frames a second)
	Recoil.step(rec, dt)
	local gp, gy = Recoil.gun(rec)
	Camera.gunP, Camera.gunY = math.rad(gp), math.rad(gy)
	if ctx.Weapon.scoped then
		-- a magnified scope shows the world along the gun, so the view takes all of the gun's recoil
		recoilP, recoilY = Camera.gunP, Camera.gunY
	else
		-- the camera's own, smaller kick; SCREEN SHAKE scales only this, never where the gun points
		local cp, cy = Recoil.cam(rec)
		local ks = S.shake or 1
		recoilP, recoilY = math.rad(cp) * ks, math.rad(cy) * ks
	end
	Camera.recP, Camera.recY = recoilP, recoilY
	thump *= math.exp(-22 * dt) -- the same few hundredths of a second at any frame rate
	local kf = math.min(1, dt * 7)
	flinchP -= flinchP * kf
	flinchY -= flinchY * kf
	flinchR -= flinchR * kf
	-- landing dip: critically damped spring
	landV += (-120 * land - 18 * landV) * dt
	land += landV * dt
	shakeAmt -= shakeAmt * math.min(1, dt * 3.2)
	local st = os.clock() * 31
	local shP, shY, shR = 0, 0, 0
	if shakeAmt > 1e-4 then
		shP = math.noise(st, 0.3) * shakeAmt
		shY = math.noise(st, 4.1) * shakeAmt
		shR = math.noise(st, 8.7) * shakeAmt * 1.4
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local orbit = Camera.orbit -- Studio inspection view of your own character (dev bridge "orbit")
	for p in hidden do
		p.LocalTransparencyModifier = orbit and 0 or 1
	end
	if not (hum and root) then
		return
	end
	if orbit then
		local tm = orbit.model
		local troot = tm and tm.Parent and tm:FindFirstChild("HumanoidRootPart")
		local center = (troot and troot.Position or root.Position) + Vector3.new(0, orbit.h or 1.2, 0)
		local baseYaw = troot and select(2, troot.CFrame:ToEulerAnglesYXZ()) or Camera.yaw
		cam.CFrame = CFrame.new(center) * CFrame.Angles(0, baseYaw + (orbit.yaw or 0), 0) * CFrame.Angles(orbit.pitch or -0.2, 0, 0) * CFrame.new(0, 0, orbit.dist or 8)
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
	local amp = math.clamp(flatSpeed / 14, 0, 1.3) * 0.085 * motion * (aiming and 0.35 or 1) * (S.headBob or 1)
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
	local M = ctx.Movement
	local held = M and M.breath
	local fatigue = M and M.armFatigue or 0
	local mounted = ctx.Weapon and ctx.Weapon.mounted ~= nil -- a mounted gun sways much less (gameplay-5b)
	local breathe = (aiming and (held and 0.12 or 0.5 + fatigue * 1.6) or 1) * motion * (mounted and ctx.Weapon.mountCut("sway") or 1)
	local breathP = math.sin(t * 1.65) * 0.0026 * breathe
	local breathY = math.sin(t * 0.83 + 1.3) * 0.0019 * breathe
	local tr = ((Camera.tremor or 0) + (aiming and fatigue * 0.7 or 0)) * (aiming and 1 or 0.35) * (held and 0.3 or 1)
	if tr > 0 then
		breathP += (math.noise(t * 7, 1.7) * 0.006 + math.sin(t * 23) * 0.0012) * tr
		breathY += (math.noise(t * 7, 9.1) * 0.006) * tr
	end
	-- eye from the rig pose: crouch depth, prone and lean move the camera exactly like the third-person head
	local yawCF = CFrame.new(root.Position) * CFrame.Angles(0, Camera.yaw, 0)
	local target = M and M.poseParams and RigMath.eye(yawCF, M.poseParams()).Position or (root.Position + Vector3.new(0, eyeOffset, 0))
	if smoothPos then
		local busy = M and M.busy and M.busy()
		smoothPos = smoothPos:Lerp(target, math.min(1, dt * (busy and 7 or 20)))
		if (smoothPos - target).Magnitude > 4 then
			smoothPos = target
		end
	else
		smoothPos = target
	end
	-- the buttstock's thump rolls the view (Tarkov 0.16); a roll does not move where the gun points
	local leanRoll = -(M and M.lean or 0) * 0.2 + thump * thumpS
	local aimRot = CFrame.Angles(0, Camera.yaw + breathY + flinchY + shY, 0) * CFrame.Angles(Camera.pitch + recoilP + breathP + flinchP + shP + land * 0.02, recoilY, roll + stepRoll + flinchR + leanRoll + shR)
	local offset = CFrame.new(bobX, bobY + land * 0.35, 0)
	Camera.aimCFrame = CFrame.new(smoothPos) * aimRot * offset
	if math.abs(Camera.freeYaw) + math.abs(Camera.freePitch) > 1e-3 then
		local rot = CFrame.Angles(0, Camera.yaw + Camera.freeYaw + breathY + flinchY + shY, 0) * CFrame.Angles(Camera.pitch + Camera.freePitch + recoilP + breathP + flinchP + shP + land * 0.02, recoilY, roll + stepRoll + flinchR + leanRoll + shR)
		cam.CFrame = CFrame.new(smoothPos) * rot * offset
	else
		cam.CFrame = Camera.aimCFrame
	end
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
