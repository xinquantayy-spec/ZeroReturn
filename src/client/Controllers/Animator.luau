--!nonstrict
-- Procedural third-person animation for other players and AI (no default Roblox animations are used).
-- Poses R15 Motor6D.Transform from velocity + replicated attributes (Crouch, Aim, Pitch). Distance-throttled.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Animator = {}
local rigs = {}
local player = Players.LocalPlayer
local frame = 0

local function motor(model, partName, motorName)
	local p = model:FindFirstChild(partName)
	local m = p and p:FindFirstChild(motorName)
	return (m and m:IsA("Motor6D")) and m or nil
end

local function setup(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		return nil
	end
	local r = {
		model = model, hum = hum, root = root, phase = math.random() * 6,
		lHip = motor(model, "LeftUpperLeg", "LeftHip"), rHip = motor(model, "RightUpperLeg", "RightHip"),
		lKnee = motor(model, "LeftLowerLeg", "LeftKnee"), rKnee = motor(model, "RightLowerLeg", "RightKnee"),
		lSh = motor(model, "LeftUpperArm", "LeftShoulder"), rSh = motor(model, "RightUpperArm", "RightShoulder"),
		lEl = motor(model, "LeftLowerArm", "LeftElbow"), rEl = motor(model, "RightLowerArm", "RightElbow"),
		waist = motor(model, "UpperTorso", "Waist"), neck = motor(model, "Head", "Neck"),
	}
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, t in animator:GetPlayingAnimationTracks() do
			t:Stop(0)
		end
	end
	rigs[model] = r
	return r
end

local function set(m, cf)
	if m and m.Parent then
		m.Transform = cf
	end
end

local function animate(r, dt)
	if r.hum.Health <= 0 then
		return
	end
	local vel = r.root.AssemblyLinearVelocity
	local sp = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local m = r.model
	local crouch = m:GetAttribute("Crouch") == true
	local aim = m:GetAttribute("Aim") == true
	local pitch = math.rad(m:GetAttribute("Pitch") or 0)
	r.phase += dt * sp * 0.48
	local amp = math.clamp(sp / 14, 0, 1)
	local s = math.sin(r.phase)
	local hip = crouch and 0.9 or 0
	local knee = crouch and -1.55 or 0
	set(r.lHip, CFrame.Angles(hip + s * 0.62 * amp, 0, 0))
	set(r.rHip, CFrame.Angles(hip - s * 0.62 * amp, 0, 0))
	set(r.lKnee, CFrame.Angles(knee - math.max(0, -s) * 0.95 * amp, 0, 0))
	set(r.rKnee, CFrame.Angles(knee - math.max(0, s) * 0.95 * amp, 0, 0))
	set(r.waist, CFrame.Angles(pitch * 0.3 + (crouch and 0.22 or 0), math.cos(r.phase) * 0.05 * amp, 0))
	set(r.neck, CFrame.Angles(pitch * 0.45, 0, 0))
	local raise = (aim and 1.5 or 1.12) + pitch * 0.55
	set(r.rSh, CFrame.Angles(raise, -0.28, 0.12))
	set(r.rEl, CFrame.Angles(aim and 0.35 or 0.75, 0, 0))
	set(r.lSh, CFrame.Angles(raise + 0.12, 0.7, -0.1))
	set(r.lEl, CFrame.Angles(aim and 0.25 or 0.55, 0, 0))
end

local function collect()
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			table.insert(list, p.Character)
		end
	end
	local ai = workspace:FindFirstChild("EFB_AI")
	if ai then
		for _, m in ai:GetChildren() do
			table.insert(list, m)
		end
	end
	return list
end

function Animator.init(_ctx)
	RunService.Stepped:Connect(function(_, dt)
		frame += 1
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		for _, model in collect() do
			local r = rigs[model] or setup(model)
			if r and r.root.Parent then
				local dist = (r.root.Position - camPos).Magnitude
				if dist < 120 or (dist < 300 and frame % 3 == 0) then
					animate(r, dist < 120 and dt or dt * 3)
				end
			end
		end
		if frame % 120 == 0 then
			for model in rigs do
				if not model.Parent then
					rigs[model] = nil
				end
			end
		end
	end)
end

return Animator
