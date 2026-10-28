--!nonstrict
-- Local weapon handling: custom viewmodel (Blender mesh if uploaded, part-built fallback), procedural
-- ADS/sprint/reload poses, sway, recoil, predicted ammo (server reconciles), stance/stamina/movement.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("EFB")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Weapons = require(Shared.Weapons)
local Sounds = require(Shared.Sounds)

local Weapon = {
	aiming = false, crouching = false, sprinting = false, reloading = false, healing = false,
	ammo = 0, spare = 0, stamina = Config.MAX_STAMINA, mode = 1, hasWeapon = false, lastShot = 0,
}
local ctx
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local vm, vmRoot, magPart
local magHome = CFrame.new(0, -0.4, -0.55) * CFrame.Angles(math.rad(12), 0, 0)
local MUZZLE = CFrame.new(0, 0.03, -2.5)
local SIGHT = Vector3.new(0, 0.27, -0.1)
local HIP = CFrame.new(0.4, -0.44, -0.62)
local AIM = CFrame.new(-SIGHT.X, -SIGHT.Y, -0.5 - SIGHT.Z)
local SPRINT = HIP * CFrame.new(-0.12, -0.14, 0.08) * CFrame.Angles(math.rad(-20), math.rad(40), math.rad(14))
local RELOAD = HIP * CFrame.new(-0.06, -0.08, 0.06) * CFrame.Angles(math.rad(14), math.rad(-10), math.rad(28))
local seq = 0
local semiLatch = false
local aimA, sprintA, reloadA = 0, 0, 0
local reloadT0, reloadDur = nil, 2.2
local kickZ, kickRot = 0, 0
local sway = CFrame.identity
local defaultHip = nil
local lastStance = nil
local lastStanceT = 0
local dryLatch = false

local function wdef()
	local d = ctx.State.data
	local g = d and d.slots and d.slots.primary
	local it = g and d.items[g]
	local idef = it and Items.defs[it.id]
	return idef and Weapons[idef.weapon], it
end

local function computeAmmo()
	local d = ctx.State.data
	if not d or not d.slots then
		return 0, 0, false
	end
	local g = d.slots.primary
	local it = g and d.items[g]
	local mag = it and it.mag and d.items[it.mag]
	local spare = 0
	for _, c in { "pockets", "bag" } do
		for gg in d[c] or {} do
			local x = d.items[gg]
			if x and x.id == "R17_MAG" then
				spare += x.a or 0
			end
		end
	end
	return mag and mag.a or 0, spare, it ~= nil
end
Weapon.computeAmmo = computeAmmo

local function newPart(parent, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.Metal
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Anchored = false
	p.Massless = true
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	if vmRoot then
		local w = Instance.new("WeldConstraint")
		w.Part0 = vmRoot
		w.Part1 = p
		w.Parent = p
	end
	return p
end

local function limb(parent, from, to, thick, color, mat)
	local len = (to - from).Magnitude
	return newPart(parent, Vector3.new(thick, thick, len), CFrame.lookAt((from + to) / 2, to), color, mat or Enum.Material.Fabric)
end

local function buildViewmodel()
	if vm then
		vm:Destroy()
	end
	vm = Instance.new("Model")
	vm.Name = "EFB_Viewmodel"
	vmRoot = Instance.new("Part")
	vmRoot.Name = "Root"
	vmRoot.Size = Vector3.new(0.1, 0.1, 0.1)
	vmRoot.Transparency = 1
	vmRoot.Anchored = true
	vmRoot.CanCollide = false
	vmRoot.CanQuery = false
	vmRoot.CanTouch = false
	vmRoot.CFrame = CFrame.identity
	vmRoot.Parent = vm
	vm.PrimaryPart = vmRoot
	local o = CFrame.identity
	local lib = ReplicatedStorage:FindFirstChild("EFB_Assets")
	local meshGun = lib and lib:FindFirstChild("EFB_VM_R17")
	local meshArms = lib and lib:FindFirstChild("EFB_VM_Arms")
	local dark, furn, metal = Color3.fromHex("2A2E2C"), Color3.fromHex("515B55"), Color3.fromHex("3B403D")
	if meshGun then
		local g = meshGun:Clone()
		g.Anchored = false
		g.Massless = true
		g.CanCollide = false
		g.CanQuery = false
		g.CastShadow = false
		g.CFrame = o * CFrame.new(0, 0, -0.95) -- mesh authored centred on its bounds; see EFB_VM_R17 notes
		g.Parent = vm
		local w = Instance.new("WeldConstraint")
		w.Part0 = vmRoot
		w.Part1 = g
		w.Parent = g
	else
		newPart(vm, Vector3.new(0.24, 0.3, 1.15), o * CFrame.new(0, 0.02, -0.45), dark)
		newPart(vm, Vector3.new(0.15, 0.05, 1.0), o * CFrame.new(0, 0.195, -0.5), metal)
		newPart(vm, Vector3.new(0.27, 0.27, 0.85), o * CFrame.new(0, 0, -1.42), furn, Enum.Material.SmoothPlastic)
		for k = 0, 3 do
			newPart(vm, Vector3.new(0.28, 0.035, 0.08), o * CFrame.new(0, 0.06, -1.15 - k * 0.18), dark)
		end
		newPart(vm, Vector3.new(0.55, 0.075, 0.075), o * CFrame.new(0, 0.03, -2.1) * CFrame.Angles(0, math.rad(90), 0), metal, Enum.Material.Metal, Enum.PartType.Cylinder)
		newPart(vm, Vector3.new(0.11, 0.11, 0.2), o * CFrame.new(0, 0.03, -2.42), dark)
		newPart(vm, Vector3.new(0.035, 0.13, 0.035), o * CFrame.new(0, 0.2, -1.78), dark)
		newPart(vm, Vector3.new(0.12, 0.06, 0.08), o * CFrame.new(0, 0.14, -1.78), dark)
		newPart(vm, Vector3.new(0.13, 0.07, 0.09), o * CFrame.new(0, 0.245, -0.1), dark)
		newPart(vm, Vector3.new(0.16, 0.3, 0.7), o * CFrame.new(0, -0.06, 0.5), furn, Enum.Material.SmoothPlastic)
		newPart(vm, Vector3.new(0.18, 0.36, 0.06), o * CFrame.new(0, -0.08, 0.87), dark, Enum.Material.Rubber)
		newPart(vm, Vector3.new(0.12, 0.34, 0.16), o * CFrame.new(0, -0.3, 0.02) * CFrame.Angles(math.rad(-15), 0, 0), furn, Enum.Material.SmoothPlastic)
		newPart(vm, Vector3.new(0.05, 0.05, 0.26), o * CFrame.new(0, -0.17, -0.2), dark)
		newPart(vm, Vector3.new(0.05, 0.12, 0.05), o * CFrame.new(0.14, 0.06, -0.35), metal) -- charging handle
	end
	if meshArms then
		local a = meshArms:Clone()
		a.Anchored = false
		a.Massless = true
		a.CanCollide = false
		a.CanQuery = false
		a.CastShadow = false
		a.CFrame = o * CFrame.new(0, -0.35, -0.55)
		a.Parent = vm
		local w = Instance.new("WeldConstraint")
		w.Part0 = vmRoot
		w.Part1 = a
		w.Parent = a
	else
		local sleeve, glove = Color3.fromHex("5E6448"), Color3.fromHex("262827")
		newPart(vm, Vector3.new(0.21, 0.23, 0.27), o * CFrame.new(0.05, -0.27, 0.0), glove, Enum.Material.Fabric)
		limb(vm, Vector3.new(0.1, -0.34, 0.12), Vector3.new(0.42, -0.62, 0.95), 0.28, sleeve)
		newPart(vm, Vector3.new(0.23, 0.2, 0.3), o * CFrame.new(-0.04, -0.15, -1.38), glove, Enum.Material.Fabric)
		limb(vm, Vector3.new(-0.08, -0.22, -1.3), Vector3.new(-0.5, -0.62, -0.4), 0.27, sleeve)
		newPart(vm, Vector3.new(0.3, 0.06, 0.3), o * CFrame.new(-0.27, -0.42, -0.85) * CFrame.Angles(math.rad(-30), math.rad(-40), 0), Color3.fromHex("6B6A4E"), Enum.Material.Fabric) -- cuff band
	end
	magPart = Instance.new("Part")
	magPart.Name = "Mag"
	magPart.Size = Vector3.new(0.13, 0.48, 0.24)
	magPart.Color = Color3.fromHex("33383B")
	magPart.Material = Enum.Material.Metal
	magPart.Anchored = true
	magPart.CanCollide = false
	magPart.CanQuery = false
	magPart.CanTouch = false
	magPart.CastShadow = false
	magPart.Parent = vm
end

local function alive()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0 and hum or nil, char
end

local function canFire()
	return ctx.State.inRaid() and Weapon.hasWeapon and not Weapon.reloading and not Weapon.healing
		and not ctx.Input.isMenu() and sprintA < 0.35 and alive() ~= nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function fireOnce(def)
	local t = os.clock()
	if t - Weapon.lastShot < 60 / def.rpm then
		return
	end
	if Weapon.ammo <= 0 then
		if not dryLatch then
			dryLatch = true
			ctx.Effects.sound(Sounds.DRY_FIRE, SoundService, 0.6)
			ctx.State.toast("EMPTY  ·  [" .. ctx.Input.label("Reload") .. "] RELOAD", "warn")
		end
		return
	end
	Weapon.lastShot = t
	seq += 1
	Weapon.ammo -= 1
	local camCF = cam.CFrame
	local spread = Weapon.aiming and def.aimSpread or def.hipSpread
	if ctx.Camera.speed > 2 then
		spread += def.moveSpread * (Weapon.aiming and 0.35 or 1)
	end
	if Weapon.crouching then
		spread *= 0.8
	end
	local r = math.rad(spread) * 0.5
	local dir = (camCF * CFrame.Angles((math.random() * 2 - 1) * r, (math.random() * 2 - 1) * r, 0)).LookVector
	local origin = camCF.Position
	ctx.State.shoot(seq, origin, dir)
	rayParams.FilterDescendantsInstances = { player.Character, vm, workspace:FindFirstChild("EFB_Fx") }
	local res = workspace:Raycast(origin, dir * def.range, rayParams)
	local hit = res and res.Position or (origin + dir * def.range)
	local muzzle = (vmRoot.CFrame * MUZZLE).Position
	ctx.Effects.flash(muzzle)
	ctx.Effects.tracer(muzzle, hit)
	if res then
		local m = res.Instance:FindFirstAncestorOfClass("Model")
		ctx.Effects.impact(res.Position, res.Normal, m and m:FindFirstChildOfClass("Humanoid") ~= nil)
	end
	ctx.Effects.sound(Sounds.R17_FIRE, SoundService, 0.9, 1 + math.random() * 0.06)
	local k = (Weapon.aiming and 0.72 or 1) * (Weapon.crouching and 0.85 or 1)
	ctx.Camera.kick(def.recoilPitch * k, (math.random() * 2 - 1) * def.recoilYaw)
	kickZ += 0.075
	kickRot += math.rad(2.2)
end

function Weapon.startReload()
	if Weapon.reloading or not Weapon.hasWeapon or not ctx.State.inRaid() then
		return
	end
	local def = wdef()
	if not def then
		return
	end
	local _, spare = computeAmmo()
	if spare <= 0 then
		ctx.State.toast("NO SPARE MAGAZINES", "warn")
		return
	end
	if ctx.Interact and ctx.Interact.current then
		return -- gamepad X is shared with interact prompts
	end
	Weapon.reloading = true
	Weapon.aiming = false
	reloadT0 = os.clock()
	reloadDur = def.reload
	ctx.State.act("reload")
	ctx.Effects.sound(Sounds.RELOAD, SoundService, 0.7)
	task.delay(def.reload + 0.8, function()
		if Weapon.reloading and reloadT0 and os.clock() - reloadT0 >= def.reload + 0.7 then
			Weapon.reloading = false -- server never confirmed; resync from snapshot
			Weapon.ammo = computeAmmo()
		end
	end)
end

function Weapon.fireForTest(n)
	local def = wdef()
	if not def then
		return "no weapon"
	end
	for _ = 1, n or 1 do
		Weapon.lastShot = 0
		if canFire() then
			fireOnce(def)
		end
		task.wait(60 / def.rpm + 0.01)
	end
	return Weapon.ammo
end

local function sendStance()
	local pitch = math.deg(ctx.Camera.pitch)
	local st = { c = Weapon.crouching, a = Weapon.aiming, s = Weapon.sprinting, p = pitch }
	local t = os.clock()
	if lastStance and lastStance.c == st.c and lastStance.a == st.a and lastStance.s == st.s and math.abs(lastStance.p - pitch) < 6 then
		return
	end
	if t - lastStanceT < 0.15 then
		return
	end
	lastStance, lastStanceT = st, t
	ctx.State.act("stance", st)
end

local function update(dt)
	local hum, char = alive()
	local inRaid = ctx.State.inRaid()
	local def = wdef()
	local show = inRaid and Weapon.hasWeapon and hum ~= nil and not ctx.Input.isMenu()
	if vm then
		vm.Parent = show and cam or nil
	end
	if hum then
		if defaultHip == nil then
			defaultHip = hum.HipHeight
		end
		local moving = ctx.Camera.speed > 1
		if Weapon.sprinting and (not moving or Weapon.stamina <= 0 or Weapon.crouching) then
			Weapon.sprinting = false
		end
		if Weapon.sprinting then
			Weapon.stamina = math.max(0, Weapon.stamina - Config.SPRINT_DRAIN * dt)
		else
			Weapon.stamina = math.min(Config.MAX_STAMINA, Weapon.stamina + Config.STAMINA_REGEN * dt)
		end
		local speed = Config.WALK_SPEED
		if Weapon.sprinting then
			speed = Config.SPRINT_SPEED
		elseif Weapon.crouching then
			speed = Config.CROUCH_SPEED
		elseif Weapon.aiming then
			speed = Config.AIM_SPEED
		end
		if Weapon.healing then
			speed = math.min(speed, Config.CROUCH_SPEED)
		end
		hum.WalkSpeed = speed
		hum.HipHeight = Weapon.crouching and (defaultHip - 1.0) or defaultHip
		hum.UseJumpPower = false
		hum.JumpHeight = (Weapon.crouching or Weapon.stamina < Config.JUMP_COST) and 0 or 3.6
		sendStance()
	end
	-- firing
	if def and ctx.Input.down("Fire") and canFire() then
		if Weapon.mode == 1 then
			fireOnce(def)
		elseif not semiLatch then
			semiLatch = true
			fireOnce(def)
		end
	end
	if not ctx.Input.down("Fire") then
		semiLatch = false
		dryLatch = false
	end
	if not show or not vmRoot then
		return
	end
	-- pose blending
	local a = math.min(1, dt * 14)
	aimA += ((Weapon.aiming and not Weapon.reloading and 1 or 0) - aimA) * a
	sprintA += ((Weapon.sprinting and 1 or 0) - sprintA) * math.min(1, dt * 9)
	reloadA += ((Weapon.reloading and 1 or 0) - reloadA) * math.min(1, dt * 10)
	kickZ -= kickZ * math.min(1, dt * 14)
	kickRot -= kickRot * math.min(1, dt * 12)
	local md = ctx.Input.isMenu() and Vector2.zero or UIS:GetMouseDelta()
	local motion = ctx.Settings.data.reduceMotion and 0.3 or 1
	local sx = math.clamp(-md.X * 0.0014, -0.08, 0.08) * motion * (1 - aimA * 0.7)
	local sy = math.clamp(-md.Y * 0.0014, -0.08, 0.08) * motion * (1 - aimA * 0.7)
	sway = sway:Lerp(CFrame.Angles(sy, sx, sx * 0.6), math.min(1, dt * 10))
	local ph = ctx.Camera.bobPhase
	local bobAmt = math.clamp(ctx.Camera.speed / 16, 0, 1.2) * (1 - aimA * 0.85) * motion
	local bob = CFrame.new(math.cos(ph) * 0.03 * bobAmt, -math.abs(math.sin(ph)) * 0.025 * bobAmt, 0)
	local base = HIP:Lerp(AIM, aimA):Lerp(SPRINT, sprintA):Lerp(RELOAD, reloadA * 0.85)
	-- wall pullback
	rayParams.FilterDescendantsInstances = { char, vm, workspace:FindFirstChild("EFB_Fx") }
	local wallHit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 2.6, rayParams)
	local push = wallHit and (2.6 - wallHit.Distance) or 0
	local pull = CFrame.new(0, -push * 0.12, push * 0.75) * CFrame.Angles(push * 0.22, 0, 0)
	vmRoot.CFrame = cam.CFrame * base * bob * sway * pull * CFrame.new(0, 0, kickZ) * CFrame.Angles(kickRot, 0, 0)
	-- magazine (reload animation)
	local magCF = magHome
	if Weapon.reloading and reloadT0 then
		local p = (os.clock() - reloadT0) / reloadDur
		if p > 0.15 and p < 0.4 then
			magCF = magHome * CFrame.new(0, -((p - 0.15) / 0.25) * 0.8, 0.1)
		elseif p >= 0.4 and p < 0.55 then
			magCF = magHome * CFrame.new(0, -3, 0)
		elseif p >= 0.55 and p < 0.82 then
			magCF = magHome * CFrame.new(0, -(1 - (p - 0.55) / 0.27) * 0.8, 0.05)
		end
	end
	magPart.CFrame = vmRoot.CFrame * magCF
end

local function onSnapshot()
	local ammo, spare, has = computeAmmo()
	Weapon.spare = spare
	Weapon.hasWeapon = has
	if os.clock() - Weapon.lastShot > 0.6 and not Weapon.reloading then
		Weapon.ammo = ammo
	end
	if not ctx.State.inRaid() then
		Weapon.reloading, Weapon.aiming, Weapon.sprinting, Weapon.healing = false, false, false, false
	end
end

function Weapon.init(c)
	ctx = c
	buildViewmodel()
	local Input = c.Input
	Input.on("Aim", function(down)
		local toggle = c.Settings.data.adsToggle or Input.device() == "Touch"
		if toggle then
			if down then
				Weapon.aiming = not Weapon.aiming
			end
		else
			Weapon.aiming = down
		end
		if Weapon.aiming then
			Weapon.sprinting = false
		end
	end)
	Input.on("Sprint", function(down)
		if Input.device() == "KBM" then
			Weapon.sprinting = down
		elseif down then
			Weapon.sprinting = not Weapon.sprinting
		end
		if Weapon.sprinting then
			Weapon.aiming = false
			Weapon.crouching = false
		end
	end)
	Input.on("Crouch", function(down)
		if down then
			Weapon.crouching = not Weapon.crouching
			if Weapon.crouching then
				Weapon.sprinting = false
			end
		end
	end)
	Input.on("Reload", function(down)
		if down then
			Weapon.startReload()
		end
	end)
	Input.on("Heal", function(down)
		if down and c.State.inRaid() then
			c.State.req("inv", { op = "use" })
		end
	end)
	Input.on("FireMode", function(down)
		if down then
			Weapon.mode = 3 - Weapon.mode
			c.State.toast((Weapon.mode == 1) and "FIRE MODE: AUTO" or "FIRE MODE: SEMI")
		end
	end)
	Input.on("Fire", function(down)
		if down and Weapon.sprinting then
			Weapon.sprinting = false
		end
	end)
	c.State.changed:Connect(onSnapshot)
	c.State.on("ammo", function(d)
		if type(d) == "table" and type(d.a) == "number" then
			Weapon.ammo = d.a
			Weapon.reloading = false
		end
	end)
	c.State.on("reload", function(d)
		if d and d.state == "none" then
			Weapon.reloading = false
		end
	end)
	c.State.on("heal", function(d)
		Weapon.healing = d and d.state == "start"
	end)
	player.CharacterAdded:Connect(function(char)
		defaultHip = nil
		Weapon.crouching, Weapon.sprinting, Weapon.aiming, Weapon.reloading, Weapon.healing = false, false, false, false, false
		Weapon.stamina = Config.MAX_STAMINA
		local hum = char:WaitForChild("Humanoid", 5)
		if hum then
			hum.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Jumping then
					Weapon.stamina = math.max(0, Weapon.stamina - Config.JUMP_COST)
				end
			end)
		end
	end)
	RunService:BindToRenderStep("EFB_Weapon", Enum.RenderPriority.Camera.Value + 2, update)
	-- rebuild when meshes arrive later (non-blocking)
	task.spawn(function()
		local lib = ReplicatedStorage:WaitForChild("EFB_Assets", 15)
		if lib then
			lib.ChildAdded:Connect(function(ch)
				if ch.Name == "EFB_VM_R17" or ch.Name == "EFB_VM_Arms" then
					buildViewmodel()
				end
			end)
			if lib:FindFirstChild("EFB_VM_R17") then
				buildViewmodel()
			end
		end
	end)
end

return Weapon
