--!nonstrict
-- Third-person procedural animation for every operator rig (other players, AI, and your own body in the Studio
-- orbit view). RigMath full-body pose: velocity-driven gait (feet planted by IK), crouch depth / prone / lean /
-- aim pitch from replicated attributes, both hands on the weapon, one-shot gestures (reload, tube, check, heal,
-- draw, slash). Writes Motor6D.Transform relative to the server's C0 hitbox pose. Footsteps come from the gait.
-- Distance LOD: full rate < 80 studs, half < 160, quarter < 300, frozen beyond.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local WeaponModels = require(Shared.WeaponModels)
local RigMath = require(Shared.RigMath)

local Animator = {}
local ctx
local rigs = {}
local player = Players.LocalPlayer
local frame = 0
local nextSlot = 0
local TAU = math.pi * 2
local CF, ANG = CFrame.new, CFrame.Angles

-- extra chest-space holds for gestures
local SLASH_WIND = CF(0.75, 0.15, -0.45) * ANG(math.rad(30), math.rad(40), math.rad(-70))
local SLASH_FOLLOW = CF(-0.35, -0.45, -0.95) * ANG(math.rad(-20), math.rad(-50), math.rad(-80))
local CHEST_HAND = CF(-0.15, -0.05, -0.62) * ANG(0, 0, math.rad(80))
local BELT = CF(0.35, -0.8, -0.35)
local GESTURE_SFX = {
	reload = { { 0.14, "mag_out", 0.7 }, { 0.76, "mag_in", 0.8 } },
	tube = { { 0.6, "shell_insert", 0.7 } },
	check = { { 0.2, "mag_out", 0.3 } },
	heal = { { 0.1, "bandage_rip", 0.7 } },
	draw = { { 0.0, "cloth_2", 0.5 } },
	slash = { { 0.25, "knife_whoosh", 0.7 } },
}

local function ease(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function seg(p, a, b)
	return ease((p - a) / (b - a))
end

local function setup(model)
	if not model:GetAttribute("ZR_Rig") then
		return nil
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		return nil
	end
	local motors = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and RigMath.joints[d.Name] then
			motors[d.Name] = d
		end
	end
	if not motors.Root then
		return nil
	end
	nextSlot += 1
	local r = {
		model = model, hum = hum, root = root, motors = motors, slot = nextSlot, phase = math.random() * TAU, amp = 0,
		dir = Vector3.new(0, 0, -1), pitch = 0, lean = 0, depth = 0.7, proneA = 0, holdCF = nil, holdKind = nil,
		lastPhase = 0,
	}
	rigs[model] = r
	return r
end

local function weaponGrip(r)
	local g = r.grip
	if g and g.Parent and g.Parent.Parent == r.model then
		return g
	end
	local wr = r.model:FindFirstChild("WeaponRoot")
	g = wr and wr:FindFirstChild("WeaponGrip")
	r.grip = g
	return g
end

local function step(r, foot, intensity)
	if ctx.Effects.footstep then
		ctx.Effects.footstep(foot, intensity, r.model)
	end
end

local function animate(r, dt)
	local m, root = r.model, r.root
	if r.hum.Health <= 0 or not r.motors.Root.Parent then
		return
	end
	local rootCF = root.CFrame
	local vel = root.AssemblyLinearVelocity
	local flatV = Vector3.new(vel.X, 0, vel.Z)
	local speed = flatV.Magnitude
	local stance = m:GetAttribute("Stance") or (m:GetAttribute("Crouch") and "c" or "s")
	local aim = m:GetAttribute("Aim") == true
	local sprint = m:GetAttribute("Sprint") == true
	local k = math.min(1, dt * 10)
	r.pitch += (math.rad(m:GetAttribute("Pitch") or 0) - r.pitch) * k
	r.lean += ((m:GetAttribute("Lean") or 0) - r.lean) * math.min(1, dt * 8)
	r.depth += ((m:GetAttribute("Depth") or 0.7) - r.depth) * k
	r.proneA += ((stance == "p" and 1 or 0) - r.proneA) * math.min(1, dt * 5)
	local airborne = math.abs(vel.Y) > 5
	-- gait
	local stride = (stance == "c" and 1.0) or (stance == "p" and 0.6) or (sprint and 2.0 or 1.35)
	r.amp += (math.clamp(speed / 9, 0, 1) - r.amp) * math.min(1, dt * 8)
	local eff = math.max(0.35, r.amp * stride)
	local prev = r.phase
	r.phase = (r.phase + dt * math.pi * speed / eff) % TAU
	if speed > 0.6 then
		r.dir = r.dir:Lerp(rootCF:VectorToObjectSpace(flatV).Unit, math.min(1, dt * 10))
	end
	-- footsteps: right foot plants at phase 0, left at pi
	if speed > 1.5 and not airborne and r.proneA < 0.5 then
		local intensity = math.clamp(speed / 16, 0.15, 1) * (stance == "c" and 0.45 or 1) * (sprint and 1.25 or 1)
		if r.phase < prev then
			step(r, (rootCF * CF(0.4, -3, 0)).Position, intensity)
		elseif prev < math.pi and r.phase >= math.pi then
			step(r, (rootCF * CF(-0.4, -3, 0)).Position, intensity)
		end
	end
	-- weapon hold + gestures
	local kind, anchors = WeaponModels.holdOf(m:GetAttribute("ActiveWeapon"))
	local now = workspace:GetServerTimeNow()
	local act = m:GetAttribute("Act")
	local ap = act and (now - (m:GetAttribute("ActT") or 0)) / math.max(0.05, m:GetAttribute("ActD") or 1) or 2
	local gesture = (ap >= 0 and ap <= 1) and act or nil
	-- gesture sounds for others (you hear enemies reload, heal and draw; Tarkov)
	local actT = m:GetAttribute("ActT")
	if act and actT and actT ~= r.lastActT then
		r.lastActT = actT
		if ap >= 0 and ap < 0.3 and m ~= player.Character then
			local dur = m:GetAttribute("ActD") or 1
			local cues = GESTURE_SFX[act]
			for _, cue in cues or {} do
				task.delay(math.max(0, cue[1] * dur - (now - actT)), function()
					if root.Parent then
						ctx.Effects.sfx(cue[2], root.Position, cue[3], 1, 45)
					end
				end)
			end
		end
	end
	local mode = (sprint and "sprint") or (aim and "aim") or "ready"
	if gesture == "heal" then
		mode = "low"
	end
	local p = {
		stance = r.proneA > 0.5 and "p" or stance, depth = r.depth, lean = r.lean, pitch = r.pitch, hold = kind, weapon = anchors,
		crouchFwd = stance == "c" and 0.15 * r.depth or 0, airborne = airborne,
		gait = { phase = r.phase, amp = r.amp, dir = r.dir, stride = stride, lift = stance == "c" and 0.22 or 0.32 },
		bob = (1 - math.abs(math.sin(r.phase))) * 0.07 * r.amp, sway = math.sin(r.phase) * 0.03 * r.amp,
		fwd = sprint and -0.14 or 0,
	}
	if kind then
		local holds = RigMath.HOLD[kind]
		local target = holds[mode] or holds.ready
		if gesture == "draw" then
			target = holds.low:Lerp(target, ease(ap))
		elseif gesture == "slash" then
			if ap < 0.35 then
				target = target:Lerp(SLASH_WIND, ease(ap / 0.35))
			elseif ap < 0.6 then
				target = SLASH_WIND:Lerp(SLASH_FOLLOW, ease((ap - 0.35) / 0.25))
			else
				target = SLASH_FOLLOW:Lerp(target, ease((ap - 0.6) / 0.4))
			end
		end
		if r.holdKind ~= kind or not r.holdCF then
			r.holdCF, r.holdKind = (gesture == "draw") and holds.low or target, kind
		end
		local fast = gesture == "slash" or gesture == "draw"
		r.holdCF = fast and target or r.holdCF:Lerp(target, math.min(1, dt * (aim and 12 or 8)))
		p.holdCF = r.holdCF
	end
	-- first solve without hand overrides to know the weapon frame, then place the support hand for gestures
	local L, W, rHand = RigMath.pose(rootCF, p)
	if W and anchors and kind ~= "melee" and gesture and gesture ~= "draw" and gesture ~= "slash" then
		local _, chest = RigMath.spine(rootCF, p)
		local base = W * CF(anchors.hand) * (kind == "pistol" and RigMath.GRIP_LP or RigMath.GRIP_L)
		local grab = anchors.magwell and (W * CF(anchors.magwell) * CF(-0.04, -0.2, 0) * ANG(0, 0, math.rad(90))) or base
		local lh
		if gesture == "reload" then
			local pouch = chest * RigMath.POUCH
			if ap < 0.15 then
				lh = base:Lerp(grab, seg(ap, 0, 0.15))
			elseif ap < 0.4 then
				lh = grab:Lerp(pouch, seg(ap, 0.15, 0.4))
			elseif ap < 0.6 then
				lh = pouch
			elseif ap < 0.82 then
				lh = pouch:Lerp(grab, seg(ap, 0.6, 0.82))
			else
				lh = grab:Lerp(base, seg(ap, 0.82, 1))
			end
		elseif gesture == "check" then
			lh = (ap < 0.25 and base:Lerp(grab, seg(ap, 0, 0.25))) or (ap < 0.75 and grab) or grab:Lerp(base, seg(ap, 0.75, 1))
		elseif gesture == "tube" then
			local port = anchors.port and (W * CF(anchors.port) * ANG(0, 0, math.rad(90))) or grab
			local belt = chest * BELT
			local q = (ap * 4) % 1 -- several shells per gesture window
			lh = (q < 0.4 and port:Lerp(belt, seg(q, 0, 0.4))) or (q < 0.8 and belt:Lerp(port, seg(q, 0.4, 0.8))) or port
		elseif gesture == "heal" then
			lh = chest * CHEST_HAND
		end
		if lh then
			p.lHand = lh
			L, W, rHand = RigMath.pose(rootCF, p)
		end
	end
	-- prone transition: blend the standing/crouched and prone solutions
	if r.proneA > 0.02 and r.proneA < 0.98 then
		local q = table.clone(p)
		q.stance = p.stance == "p" and "c" or "p"
		local L2, W2 = RigMath.pose(rootCF, q)
		local a = p.stance == "p" and (1 - r.proneA) or r.proneA
		for name, l in L do
			local o = L2[name]
			if o then
				L[name] = l:Lerp(o, a)
			end
		end
		if W and W2 then
			W = W:Lerp(W2, a)
		end
	end
	local motors = r.motors
	for name, l in L do
		local mt = motors[name]
		if mt then
			mt.Transform = mt.C0:Inverse() * CF(RigMath.joints[name].p0) * l
		end
	end
	local grip = weaponGrip(r)
	if grip and W and rHand then
		grip.Transform = grip.C0:Inverse() * rHand:Inverse() * W
	end
end

local function consider(model, camPos)
	local r = rigs[model] or setup(model)
	if not r or not r.root.Parent then
		return
	end
	local dist = (r.root.Position - camPos).Magnitude
	local every = (dist < 80 and 1) or (dist < 160 and 2) or (dist < 300 and 4) or 0
	if every > 0 and (frame + r.slot) % every == 0 then
		local ok, err = pcall(animate, r, (r.lastDt or 0.016) * every)
		if not ok and not r.warned then
			r.warned = true
			warn("[ZR] animator", model:GetFullName(), err)
		end
	end
end

function Animator.init(c)
	ctx = c
	RunService.Stepped:Connect(function(_, dt)
		frame += 1
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		for _, p in Players:GetPlayers() do
			local char = p.Character
			if char and (p ~= player or (ctx.Camera and ctx.Camera.orbit)) then
				local r = rigs[char]
				if r then
					r.lastDt = dt
				end
				consider(char, camPos)
			end
		end
		local ai = workspace:FindFirstChild("ZR_AI")
		if ai then
			for _, model in ai:GetChildren() do
				local r = rigs[model]
				if r then
					r.lastDt = dt
				end
				consider(model, camPos)
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
