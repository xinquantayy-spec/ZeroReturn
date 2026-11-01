--!nonstrict
-- Stationary (mounted) weapons, client (docs/design/STATIONARY_WEAPONS.md; server: Services/Stationary.luau). Two jobs:
--   every gun in view: turn its head parts with the aim the server publishes (attributes Yaw and Pitch) and kick back when
--   its belt drops, so everyone sees a gun swing and fire; the server's copy of the model stays in the neutral pose
--   the gun you man (note "stmount" until "stend" or leaving): the camera sits at the gun's eye, look input (mouse, stick, touch
--   drag) is scaled by the zoom and held inside the arcs, the trigger fires the local flash, sound, tracer and shake, and
--   the aim and trigger go to the server (act "staim", 20 Hz and a keep-alive); the server owns rate, belt and damage
-- Input: the "mount" actions (MountFire, MountZoom, MountLeave) replace the personal-weapon ones (Input.setMounted); keyboard
-- LMB fires, RMB held zooms, F leaves; gamepad RT, LT, B with the right stick; touch FIRE (drags to aim), ZOOM (toggles), LEAVE.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local S = require(Shared.Stationary)
local Config = require(Shared.Config)

local TAG = "ZR_Stationary"
local KICK = { HMG12 = 0.16, AGL30 = 0.3 } -- studs the head slides back on a shot
-- mounted, zooming, name, rounds, belt: what the HUD and the touch buttons read; yaw and pitch (radians, relative to the gun) mirror the aim
local Stationary = { mounted = false, zooming = false, rounds = 0, belt = 0, name = "", yaw = 0, pitch = 0 }
local ctx
local cam = workspace.CurrentCamera
local player = Players.LocalPlayer
local guns = {} -- [model] = { model, spec, frame, arcs, rel, yaw, pitch, kick, rounds, shots }
local cur -- the gun being manned
local aimY, aimP = 0, 0 -- the operator's aim relative to the gun
local lastYaw, lastPitch = 0, 0 -- Camera.yaw / pitch as this controller left them: the change since is this frame's look
local sentY, sentP, sentF, sendT = 0, 0, 0, 0
local nextShot, shake, fov = 0, 0, nil
local enteredAt = 0 -- when the mount began: F both mounts and leaves, so a key still held from the prompt must not leave at once
local ended = {} -- [gun id] = os.clock() when the server said the operator is off it (enter may still be waiting for the model)
local gui, limit, readout
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- ── every gun in view ───────────────────────────────────────────────────────────────────────────────────────
local function pose(g, yaw, pitch)
	local aim = S.aimCF(g.frame, g.spec, yaw, pitch) * CFrame.new(0, 0, g.kick)
	for p, rel in g.rel do
		if p.Parent then
			p.CFrame = aim * rel
		end
	end
	g.yaw, g.pitch = yaw, pitch
end

local function track(model)
	if guns[model] then
		return
	end
	local head = model:WaitForChild("Head", 5)
	local spec = S.KINDS[model:GetAttribute("Kind") or ""]
	local frame = model:GetAttribute("Frame")
	if not (head and spec and typeof(frame) == "CFrame") or guns[model] then
		return
	end
	local g = {
		model = model, spec = spec, frame = frame, rel = {}, yaw = 0, pitch = 0, kick = 0, shots = 0,
		rounds = model:GetAttribute("Rounds") or spec.belt,
		arcs = { l = model:GetAttribute("ArcL") or 0, r = model:GetAttribute("ArcR") or 0, up = model:GetAttribute("ArcU") or 0, dn = model:GetAttribute("ArcD") or 0 },
	}
	local P = S.pivot(frame, spec)
	for _, p in head:GetDescendants() do
		if p:IsA("BasePart") then
			g.rel[p] = P:ToObjectSpace(p.CFrame)
		end
	end
	guns[model] = g
	model:GetAttributeChangedSignal("Rounds"):Connect(function()
		local r = model:GetAttribute("Rounds") or 0
		if r < g.rounds and g ~= cur then
			g.kick = KICK[spec.id] or 0.16 -- a round left: the head slides back (the operator's own gun kicks on the local shot)
		end
		g.rounds = r
	end)
	pose(g, model:GetAttribute("Yaw") or 0, model:GetAttribute("Pitch") or 0)
end

local function findGun(id)
	for model, g in guns do
		if model:GetAttribute("Id") == id then
			return g
		end
	end
	return nil
end

-- ── the gun you man ─────────────────────────────────────────────────────────────────────────────────────────
local function enter(d)
	if type(d) ~= "table" or Stationary.mounted then
		return
	end
	local g = findGun(d.id)
	local t0 = os.clock()
	while not g and os.clock() - t0 < 1.5 and (ended[d.id] or 0) < t0 do
		task.wait(0.1)
		g = findGun(d.id)
	end
	if (ended[d.id] or 0) >= t0 or Stationary.mounted then
		return -- the server took us off this gun while we waited for it (or another mount got here first)
	end
	if not g then
		ctx.State.act("stleave") -- the gun never streamed in: give it back
		return
	end
	cur = g
	enteredAt = os.clock()
	Stationary.mounted, Stationary.zooming = true, false
	Stationary.name, Stationary.belt = string.upper(g.spec.name), g.spec.belt
	Stationary.rounds = g.model:GetAttribute("Rounds") or d.rounds or 0
	ctx.Weapon.cancelAim()
	ctx.Movement.leanTarget = 0
	ctx.Input.setMounted(true)
	ctx.Interact.lock(true)
	aimY, aimP = 0, 0
	Stationary.yaw, Stationary.pitch = 0, 0
	ctx.Camera.yaw, ctx.Camera.pitch = S.heading(g.frame), 0
	lastYaw, lastPitch = ctx.Camera.yaw, 0
	nextShot, shake, fov = 0, 0, nil
	sentY, sentP, sentF, sendT = 0, 0, 0, 1
	readout.Text = ""
	gui.Enabled = true
end

local function exit()
	if not Stationary.mounted then
		return
	end
	Stationary.mounted, Stationary.zooming = false, false
	cur = nil
	ctx.Input.setMounted(false)
	gui.Enabled = false
	-- F both leaves and uses prompts: keep them off a moment so the same press does not mount the gun again
	task.delay(0.45, function()
		if not Stationary.mounted then
			ctx.Interact.lock(false)
		end
	end)
end

function Stationary.leave()
	if Stationary.mounted then
		ctx.State.act("stleave")
		exit()
	end
end

-- the picture of one round from your own gun: flash, report, tracer (every few rounds) and the impact where the aim lands
-- (a straight line: the server's round falls and flies on; this is only what you see)
local function localShot(g, t)
	local spec = g.spec
	local iv = S.interval(spec)
	if t - nextShot > iv then
		nextShot = t + iv
	else
		nextShot += iv
	end
	local E = ctx.Effects
	local muzzle = S.muzzle(g.frame, spec, aimY, aimP)
	local eye = S.eye(g.frame, spec, aimY)
	local dir = S.dirOf(g.frame, spec, aimY, aimP)
	rayParams.FilterDescendantsInstances = { player.Character, g.model, cam, workspace:FindFirstChild("ZR_Fx") }
	local res = workspace:Raycast(eye, dir * spec.range, rayParams)
	local hit = res and res.Position or (eye + dir * spec.range)
	g.shots += 1
	E.flash(muzzle, spec.id == "AGL30" and 0.9 or 0.6)
	E.gunSound(spec.id, muzzle, false, false, 1)
	if spec.tracerEvery > 0 and g.shots % spec.tracerEvery == 0 then
		E.tracer(muzzle, hit)
	end
	if res then
		E.impact(hit, res.Normal, false)
		E.impactSound(hit, false, res.Material)
	end
	g.kick = KICK[spec.id] or 0.16
	shake = math.min(0.014, shake + 0.004 * spec.shake)
end

local function atLimit(g)
	local a = g.arcs
	return aimY >= a.l - 0.006 or aimY <= -a.r + 0.006 or aimP >= a.up - 0.006 or aimP <= -a.dn + 0.006
end

-- the gun you man, every frame: zoom, look held inside the arcs, the camera at the gun's eye, the trigger, the aim to the server
local function mountedStep(dt)
	local g = cur
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (g and g.model.Parent and hum and hum.Health > 0 and ctx.State.inRaid()) then
		exit()
		return
	end
	-- zoom: a narrow lens, and the look Camera just applied turns slower with it
	local cfg = ctx.Settings.data
	local base = cfg.fov or Config.FOV
	fov = fov or base
	local want = base
	if Stationary.zooming then
		want = math.deg(2 * math.atan(math.tan(math.rad(base) / 2) / g.spec.zoom))
	end
	fov += (want - fov) * math.min(1, dt * 12)
	local k = math.tan(math.rad(fov) / 2) / math.tan(math.rad(base) / 2)
	local C = ctx.Camera
	local h = S.heading(g.frame)
	-- Camera ran just before this: its change to yaw and pitch is this frame's look; scale it, hold it inside the arcs
	local yaw = lastYaw + S.wrap(C.yaw - lastYaw) * k
	local pitch = lastPitch + (C.pitch - lastPitch) * k
	aimY, aimP = S.clamp(g.arcs, yaw - h, pitch)
	Stationary.yaw, Stationary.pitch = aimY, aimP
	C.yaw, C.pitch = h + aimY, aimP
	lastYaw, lastPitch = C.yaw, C.pitch
	-- camera at the gun's eye, with a shake per shot
	shake -= shake * math.min(1, dt * 12)
	local t = os.clock()
	local mot = (cfg.reduceMotion and 0.3 or 1) * (cfg.shake or 1)
	local shP, shY, shR = 0, 0, 0
	if shake > 1e-4 then
		shP, shY, shR = math.noise(t * 37, 0.3) * shake * mot, math.noise(t * 37, 4.1) * shake * mot, math.noise(t * 37, 8.7) * shake * mot * 1.4
	end
	cam.CFrame = CFrame.new(S.eye(g.frame, g.spec, aimY)) * CFrame.Angles(0, h + aimY + shY, 0) * CFrame.Angles(aimP + shP, 0, shR)
	cam.FieldOfView = fov
	-- the trigger: the local picture now, the real round from the server
	local firing = ctx.Input.down("MountFire") and not ctx.Input.isMenu()
	Stationary.rounds = g.rounds
	if firing and g.rounds > 0 and t >= nextShot then
		localShot(g, t)
	end
	limit.Text = atLimit(g) and "AT LIMIT" or ""
	if g.spec.round then
		-- a launcher lobs its rounds: the elevation (the arc) and the zeroing distance in metres, the two numbers an AGS shows while aiming
		readout.Text = string.format("ARC %.1f   ZERO %d M", math.deg(aimP), math.floor(g.spec.zero + 0.5))
	end
	-- aim and trigger to the server: at once when the trigger changes, 20 Hz while the aim moves, a keep-alive otherwise
	sendT += dt
	local f = firing and 1 or 0
	local moved = math.abs(aimY - sentY) > 0.002 or math.abs(aimP - sentP) > 0.002
	if f ~= sentF or (moved and sendT >= 0.05) or sendT >= 0.25 then
		sendT, sentY, sentP, sentF = 0, aimY, aimP, f
		ctx.State.act("staim", { y = aimY, p = aimP, f = f })
	end
end

local function step(dt)
	if Stationary.mounted then
		mountedStep(dt) -- first: your own gun is then posed with this frame's aim
	end
	local camPos = cam.CFrame.Position
	for model, g in guns do
		if not model.Parent then
			guns[model] = nil
		elseif g == cur or (g.frame.Position - camPos).Magnitude < S.SHOW_RANGE + 100 then
			local ty, tp = model:GetAttribute("Yaw") or 0, model:GetAttribute("Pitch") or 0
			local k = math.min(1, dt * 16)
			if g == cur then
				ty, tp, k = aimY, aimP, 1 -- your own gun follows your camera exactly
			end
			g.kick -= g.kick * math.min(1, dt * 22)
			pose(g, g.yaw + S.wrap(ty - g.yaw) * k, g.pitch + (tp - g.pitch) * k)
		end
	end
end

function Stationary.init(c)
	ctx = c
	local K = c.UiKit
	gui = K.screen("ZR_Mount", 5)
	gui.Enabled = false
	local ring = K.frame(gui, { Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1 })
	K.new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
	K.stroke(ring, K.C.line, 0.4, 1)
	for _, tk in { { -30, -1, 12, 2 }, { 18, -1, 12, 2 }, { -1, -30, 2, 12 }, { -1, 18, 2, 12 } } do
		K.frame(ring, { Name = "Tick", BackgroundColor3 = K.C.line, BackgroundTransparency = 0.35, Position = UDim2.new(0.5, tk[1], 0.5, tk[2]), Size = UDim2.fromOffset(tk[3], tk[4]) })
	end
	limit = K.label(gui, "", 14, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(300, 20),
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = K.C.ochre,
	})
	readout = K.label(gui, "", 14, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(300, 20),
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = K.C.text,
	})
	for _, m in CollectionService:GetTagged(TAG) do
		task.spawn(track, m)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(m)
		task.spawn(track, m)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(m)
		guns[m] = nil
	end)
	c.State.on("stmount", enter)
	c.State.on("stend", function(d)
		local id = type(d) == "table" and d.id or nil
		if id then
			ended[id] = os.clock()
		end
		if id == nil or (cur and cur.model:GetAttribute("Id") == id) then
			exit() -- a late "stend" of a gun we already left must not drop us off the one we man now
		end
	end)
	c.Input.on("MountLeave", function(down)
		if down and os.clock() - enteredAt > 0.4 then
			Stationary.leave()
		end
	end)
	-- zoom: held on keyboard and gamepad, toggled by the touch button
	c.Input.on("MountZoom", function(down)
		if not Stationary.mounted then
			return
		end
		if c.Input.device() == "Touch" then
			if down then
				Stationary.zooming = not Stationary.zooming
			end
		else
			Stationary.zooming = down
		end
	end)
	c.State.changed:Connect(function()
		if Stationary.mounted and not c.State.inRaid() then
			exit()
		end
	end)
	player.CharacterAdded:Connect(function()
		exit()
	end)
	RunService:BindToRenderStep("ZR_Stationary", Enum.RenderPriority.Camera.Value + 2, step)
end

return Stationary
