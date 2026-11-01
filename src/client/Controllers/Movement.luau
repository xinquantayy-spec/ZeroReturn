--!nonstrict
-- Local movement, Tarkov rules: stand / crouch (C, adjustable depth with C + wheel) / prone (Z, timed transition),
-- lean Q/E (toggle, blocked by walls), walking-speed steps on the mouse wheel, sprint, leg stamina (sprint, jumps)
-- and arm stamina (aiming, hold breath = Shift while aiming), carried-weight penalties, inertia, vaulting and
-- mantling over waist/chest-high cover (Space), footsteps. Replicates stance/depth/lean/aim/sprint/pitch to the
-- server ("stance" act) for third-person animation and server hitboxes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local RigMath = require(Shared.RigMath)
local Progress = require(Shared.Progress)

local Movement = {
	stance = "s", depth = 0.7, lean = 0, leanTarget = 0, speedStep = 10, sprinting = false, crouching = false, prone = false,
	stamina = Config.MAX_STAMINA, arms = Config.MAX_ARMS, breath = false, weight = 0, vaulting = false, transitionUntil = 0,
	armFatigue = 0,
}
local ctx
local player = Players.LocalPlayer
local lastStance, lastStanceT = nil, 0
local accel = 1 -- inertia factor (0.3 .. 1)
local lastMove = Vector3.zero
local crouchHeld = false
local exhaustedUntil = 0
local lastBob = 0
local vaultAvail = nil
local vaultParams = RaycastParams.new()
vaultParams.FilterType = Enum.RaycastFilterType.Exclude

local function alive()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0 and hum or nil, char
end
Movement.alive = alive

function Movement.stopSprint()
	Movement.sprinting = false
end

-- firing / aiming is blocked during stance transitions and vaults
function Movement.busy()
	return Movement.vaulting or os.clock() < Movement.transitionUntil
end

-- pose parameters for the first-person eye (matches what other players see)
function Movement.poseParams()
	return { stance = Movement.stance, depth = Movement.depth, lean = Movement.lean, pitch = 0, crouchFwd = Movement.stance == "c" and 0.15 * Movement.depth or 0 }
end

local function setStance(st)
	if st == Movement.stance then
		return
	end
	if st == "p" or Movement.stance == "p" then
		Movement.transitionUntil = os.clock() + Config.PRONE_TIME
	end
	Movement.stance = st
	Movement.crouching = st == "c"
	Movement.prone = st == "p"
	if st ~= "s" then
		Movement.sprinting = false
	end
	if st == "p" then
		Movement.leanTarget = 0
	end
end
Movement.setStance = setStance

-- carried weight from the snapshot (raid kit only; the hideout stash is not carried)
local function computeWeight()
	local d = ctx.State.data
	if not d or not ctx.State.inRaid() then
		return 0
	end
	local w = 0
	for _, it in d.items or {} do
		local def = Items.defs[it.id]
		if def then
			w += (def.mass or 0) * (((def.stack or 1) > 1) and (it.n or 1) or 1)
			if it.a and it.at and Items.defs[it.at] then
				w += it.a * (Items.defs[it.at].mass or 0)
			end
		end
	end
	return w
end

local function sendStance()
	local W = ctx.Weapon
	local pitch = math.floor(math.deg(ctx.Camera.pitch))
	local st = { st = Movement.stance, d = math.floor(Movement.depth * 20 + 0.5) / 20, l = Movement.leanTarget, a = W.aiming, s = Movement.sprinting, p = pitch }
	local t = os.clock()
	local same = lastStance and lastStance.st == st.st and lastStance.d == st.d and lastStance.l == st.l and lastStance.a == st.a and lastStance.s == st.s
	if same and math.abs(lastStance.p - pitch) < 6 then
		return
	end
	if t - lastStanceT < 0.12 then
		return
	end
	lastStance, lastStanceT = st, t
	ctx.State.act("stance", st)
end

-- ── vault / mantle ───────────────────────────────────────────────────────────
-- obstacle in front between knee and chest-high with a clear top: returns landing CFrame + duration
local function findVault(char, root)
	local look = root.CFrame.LookVector
	local floor = root.Position.Y - RigMath.hipFor(Movement.stance, Movement.depth) - RigMath.hrpHalf
	vaultParams.FilterDescendantsInstances = { char, workspace.CurrentCamera, workspace:FindFirstChild("ZR_Fx") }
	local low = workspace:Raycast(Vector3.new(root.Position.X, floor + 1.1, root.Position.Z), look * 2.6, vaultParams)
	if not low or low.Normal.Y > 0.75 then
		return nil
	end
	-- highest surface just past the face (handles sloped barriers and rounded tops)
	local topHit
	for _, d in { 0.25, 0.55, 0.85, 1.15, 1.45 } do
		local o = low.Position + look * d
		local hit = workspace:Raycast(Vector3.new(o.X, floor + 6.2, o.Z), Vector3.new(0, -6, 0), vaultParams)
		if hit and hit.Position.Y > floor + 0.6 and (not topHit or hit.Position.Y > topHit.Position.Y + 0.02) then
			topHit = hit
		end
	end
	if not topHit then
		return nil
	end
	local edge = topHit.Position
	local h = topHit.Position.Y - floor
	if h < 1.0 or h > 4.6 then
		return nil
	end
	-- head room above the top and a body-sized gap
	if workspace:Raycast(topHit.Position + Vector3.new(0, 0.1, 0), Vector3.new(0, 5.4, 0), vaultParams) then
		return nil
	end
	-- thin cover (<= 2.2 deep, top <= 2.9): vault over to the far side; otherwise climb onto it
	local far = workspace:Raycast(Vector3.new(edge.X, topHit.Position.Y + 0.4, edge.Z), look * 2.4, vaultParams)
	local backDown = workspace:Raycast(topHit.Position + look * 1.7 + Vector3.new(0, 1, 0), Vector3.new(0, -1.6, 0), vaultParams)
	local over = h <= 2.9 and not far and not backDown
	local land
	if over then
		local ground = workspace:Raycast(topHit.Position + look * 2.6 + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), vaultParams)
		if not ground then
			return nil
		end
		land = ground.Position
	else
		if far and (far.Position - edge).Magnitude < 1.4 then
			return nil -- a wall right behind the ledge
		end
		land = topHit.Position + look * 1.2
	end
	local hip = RigMath.STAND_HIP + RigMath.hrpHalf
	return { top = topHit.Position.Y, land = CFrame.new(land + Vector3.new(0, hip, 0)) * root.CFrame.Rotation, dur = (h > 2.9 or not over) and Config.VAULT_HIGH or Config.VAULT_LOW, over = over }
end

local function doVault(v)
	local hum, char = alive()
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or Movement.vaulting then
		return
	end
	Movement.vaulting = true
	Movement.sprinting = false
	ctx.Weapon.cancelAim()
	setStance("s")
	local start = root.CFrame
	local apex = Vector3.new(0, v.top + RigMath.STAND_HIP + RigMath.hrpHalf - 0.6, 0)
	hum.PlatformStand = true
	if ctx.Effects.cloth then
		ctx.Effects.cloth(0.6)
	end
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local p = math.clamp((os.clock() - t0) / v.dur, 0, 1)
		if not root.Parent or hum.Health <= 0 then
			conn:Disconnect()
			Movement.vaulting = false
			return
		end
		-- up first (hands on the ledge), then over
		local up = math.min(1, p / 0.45)
		local fwd = math.max(0, (p - 0.25) / 0.75)
		local e = fwd * fwd * (3 - 2 * fwd)
		local pos = start.Position:Lerp(v.land.Position, e)
		local y = math.max(pos.Y, start.Position.Y + (apex.Y - start.Position.Y) * math.sin(up * math.pi / 2))
		if p > 0.7 then
			y = y + (v.land.Position.Y - y) * ((p - 0.7) / 0.3)
		end
		root.CFrame = CFrame.new(pos.X, y, pos.Z) * start.Rotation
		root.AssemblyLinearVelocity = Vector3.zero
		if p >= 1 then
			conn:Disconnect()
			hum.PlatformStand = false
			Movement.vaulting = false
			ctx.Camera.impact(0.35)
		end
	end)
end

-- ── frame ────────────────────────────────────────────────────────────────────
local function update(dt)
	local hum, char = alive()
	if not hum then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	local W = ctx.Weapon
	local inRaid = ctx.State.inRaid()
	local atGun = ctx.Input.isMounted() -- at a stationary gun: standing, planted (Stationary controller)
	if atGun and Movement.stance ~= "s" then
		setStance("s")
	end
	local vit = ctx.State.vitals
	local mods = vit and vit.mods or nil
	ctx.Camera.tremor = mods and mods.tremor or 0
	local moving = ctx.Camera.speed > 1
	local w = Movement.weight
	-- skills (M9): strength raises the weight limits, endurance lowers sprint drain
	local econ = ctx.State.data and ctx.State.data.econ
	local skills = econ and econ.skills
	local strong = 1 + Progress.bonus(skills, "strength")
	local wOver, wCrit, wMax = Config.WEIGHT_OVER * strong, Config.WEIGHT_CRIT * strong, Config.WEIGHT_MAX * strong
	Movement.limits = { over = wOver, crit = wCrit, max = wMax }
	local over = math.clamp((w - wOver) / (wCrit - wOver), 0, 1)
	local crit = math.clamp((w - wCrit) / (wMax - wCrit), 0, 1)
	local canSprint = Movement.stance == "s" and not W.aiming and (not mods or mods.sprint ~= false) and crit <= 0 and os.clock() > exhaustedUntil and not Movement.vaulting
	if Movement.sprinting and (not moving or Movement.stamina <= 0 or not canSprint) then
		Movement.sprinting = false
		if Movement.stamina <= 0 then
			exhaustedUntil = os.clock() + 3 -- winded: no sprint until breath recovers a little
			if ctx.Effects.breath then
				ctx.Effects.breath(0.8)
			end
		end
	end
	-- leg stamina
	local drainMul = 1 + over * 0.8 + crit * 1.2
	local regenMul = (mods and mods.staminaRegen or 1) * (1 - crit * 0.6) * (moving and 0.6 or 1.2)
	if Movement.sprinting then
		Movement.stamina = math.max(0, Movement.stamina - Config.SPRINT_DRAIN * drainMul * (1 - Progress.bonus(skills, "endurance")) * dt)
	else
		Movement.stamina = math.min(Config.MAX_STAMINA, Movement.stamina + Config.STAMINA_REGEN * regenMul * dt)
	end
	-- arm stamina: aiming costs more with heavy weapons; holding breath costs a lot
	Movement.breath = W.aiming and ctx.Input.down("Sprint") and Movement.arms > 2
	if W.aiming then
		local mass = W.mass or 3
		local drain = Config.ADS_DRAIN + mass * 0.25 + (Movement.breath and Config.BREATH_DRAIN or 0)
		if Movement.stance == "p" then
			drain *= 0.35 -- rested on the ground
		elseif Movement.stance == "c" then
			drain *= 0.8
		end
		Movement.arms = math.max(0, Movement.arms - drain * dt)
	else
		Movement.arms = math.min(Config.MAX_ARMS, Movement.arms + Config.ARMS_REGEN * dt)
	end
	Movement.armFatigue = Movement.arms < 25 and (1 - Movement.arms / 25) or 0
	-- lean (blocked by walls next to the head)
	if Movement.stance == "p" or Movement.sprinting or Movement.vaulting then
		Movement.leanTarget = 0
	end
	local leanGoal = Movement.leanTarget
	if leanGoal ~= 0 and root then
		local base = RigMath.eye(CFrame.new(root.Position) * CFrame.Angles(0, ctx.Camera.yaw, 0), { stance = Movement.stance, depth = Movement.depth, lean = 0 })
		local side = base.RightVector * (leanGoal > 0 and 1 or -1)
		vaultParams.FilterDescendantsInstances = { char, workspace.CurrentCamera }
		local hit = workspace:Raycast(base.Position, side * 1.4, vaultParams)
		if hit then
			leanGoal *= math.clamp((hit.Distance - 0.35) / 1.05, 0, 1)
		end
	end
	Movement.lean += (leanGoal - Movement.lean) * math.min(1, dt * 7)
	-- speed
	local speed = Config.WALK_SPEED * (Movement.speedStep / 10)
	if Movement.sprinting then
		speed = Config.SPRINT_SPEED
	elseif Movement.stance == "c" then
		speed = Config.CROUCH_SPEED * (1.15 - 0.45 * Movement.depth) * math.max(0.4, Movement.speedStep / 10)
	elseif Movement.stance == "p" then
		speed = Config.PRONE_SPEED
	end
	if W.aiming then
		speed = math.min(speed, Movement.stance == "p" and 0.8 or Config.AIM_SPEED)
	end
	if math.abs(Movement.lean) > 0.2 then
		speed = math.min(speed, Config.LEAN_SPEED)
	end
	if W.healing then
		speed = math.min(speed, Config.CROUCH_SPEED)
	end
	if os.clock() < Movement.transitionUntil or atGun then
		speed = 0
	end
	-- inertia: heavier kit takes longer to get going and to change direction
	local md = hum.MoveDirection
	-- free look turns only the head: keep walking where the body faces
	local fy = ctx.Camera.freeYaw or 0
	if math.abs(fy) > 0.01 and md.Magnitude > 0.1 then
		md = CFrame.Angles(0, -fy, 0):VectorToWorldSpace(md)
		hum:Move(md, false)
	end
	if md.Magnitude > 0.1 then
		if lastMove.Magnitude > 0.1 and md:Dot(lastMove) < -0.2 then
			accel = math.min(accel, 0.45)
		end
		accel = math.min(1, accel + dt / (0.22 + over * 0.35 + crit * 0.4))
		lastMove = md
	else
		accel = 0.35
		lastMove = Vector3.zero
	end
	local weightMul = (1 - over * 0.12) * (1 - crit * 0.45)
	if w > wMax then
		weightMul = 0.3
	end
	local gear = Movement.gear
	hum.WalkSpeed = speed * (mods and mods.speed or 1) * weightMul * accel * (1 + (gear and gear.speed or 0) / 100)
	hum.HipHeight = RigMath.hipFor(Movement.stance, Movement.depth)
	hum.UseJumpPower = false
	-- jump / vault (Space): vaulting takes priority over a jump when an obstacle is in front
	vaultAvail = (inRaid or true) and root and Movement.stance ~= "p" and not Movement.vaulting and findVault(char, root) or nil
	local canJump = Movement.stance == "s" and Movement.stamina >= Config.JUMP_COST and w <= wMax and not vaultAvail and not Movement.vaulting and not atGun
	hum.JumpHeight = canJump and 3.2 or 0
	-- local footsteps from the camera bob (others' come from the Animator)
	local bob = math.sin(ctx.Camera.bobPhase)
	if ctx.Camera.speed > 1.5 and lastBob * bob < 0 and hum.FloorMaterial ~= Enum.Material.Air and ctx.Effects.footstep then
		local intensity = math.clamp(ctx.Camera.speed / 16, 0.15, 1) * (Movement.stance == "c" and 0.45 or 1) * (Movement.sprinting and 1.25 or 1) * (Movement.stance == "p" and 0.2 or 1)
		ctx.Effects.footstep(root.Position - Vector3.new(0, hum.HipHeight + RigMath.hrpHalf, 0), intensity, char, true)
	end
	lastBob = bob
	sendStance()
end

function Movement.init(c)
	ctx = c
	local Input = c.Input
	Input.on("Sprint", function(down)
		if c.Weapon.aiming then
			return -- Shift while aiming holds breath (read in update)
		end
		if Input.device() == "KBM" then
			Movement.sprinting = down
		elseif down then
			Movement.sprinting = not Movement.sprinting
		end
		if Movement.sprinting then
			if Movement.stance ~= "s" then
				setStance("s")
			end
			Movement.leanTarget = 0
			c.Weapon.cancelAim()
		end
	end)
	Input.on("Crouch", function(down)
		crouchHeld = down
		if down then
			setStance(Movement.stance == "c" and "s" or "c")
		end
	end)
	Input.on("Prone", function(down)
		if down then
			setStance(Movement.stance == "p" and "s" or "p")
		end
	end)
	local function lean(dir)
		return function(down)
			if down then
				Movement.leanTarget = (Movement.leanTarget == dir) and 0 or dir
			end
		end
	end
	Input.on("LeanLeft", lean(-1))
	Input.on("LeanRight", lean(1))
	UIS.JumpRequest:Connect(function()
		if c.Input.isMounted() then
			return
		end
		if Movement.stance == "p" then
			setStance("c")
			return
		end
		if vaultAvail and not Movement.vaulting and not c.Input.isMenu() then
			doVault(vaultAvail)
		end
	end)
	UIS.InputChanged:Connect(function(input, gp)
		if gp or input.UserInputType ~= Enum.UserInputType.MouseWheel or c.Input.isMenu() or not c.State.inRaid() then
			return
		end
		local dz = input.Position.Z > 0 and 1 or -1
		if crouchHeld or (Movement.stance == "c" and UIS:IsKeyDown(Enum.KeyCode.C)) then
			Movement.depth = math.clamp(Movement.depth - dz * 0.1, 0, 1)
			c.State.emit("movenote", { text = string.format("STANCE %d%%", math.floor((1 - Movement.depth) * 100 + 0.5)) })
		else
			Movement.speedStep = math.clamp(Movement.speedStep + dz, 2, 10)
			c.State.emit("movenote", { text = string.format("SPEED %d%%", Movement.speedStep * 10) })
		end
	end)
	c.State.changed:Connect(function()
		Movement.weight = computeWeight()
		-- Tarkov gear penalties: movement speed, turn speed and weapon ergonomics from what you wear
		local snap = ctx.State.data
		local sk = snap.econ and snap.econ.skills
		Movement.gear = Items.gearPenalties(snap, function(cls)
			return 1 - Progress.bonus(sk, cls >= 4 and "heavyvests" or "lightvests")
		end)
		if not c.State.inRaid() then
			Movement.sprinting = false
		end
	end)
	player.CharacterAdded:Connect(function(char)
		setStance("s")
		Movement.sprinting, Movement.vaulting, Movement.leanTarget, Movement.lean = false, false, 0, 0
		Movement.stamina, Movement.arms = Config.MAX_STAMINA, Config.MAX_ARMS
		Movement.transitionUntil = 0
		local hum = char:WaitForChild("Humanoid", 5)
		if hum then
			hum.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Jumping then
					Movement.stamina = math.max(0, Movement.stamina - Config.JUMP_COST)
				end
			end)
		end
	end)
	RunService:BindToRenderStep("ZR_Movement", Enum.RenderPriority.Input.Value + 5, update)
end

return Movement
