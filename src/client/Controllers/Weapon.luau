--!nonstrict
-- Local weapon handling (Tarkov rules, original content). The viewmodel is the shared part-built weapon spec
-- (WeaponModels, the same one the third-person weapon uses) at viewmodel scale, held by procedural two-bone arms.
-- Slots 1-4 / cycle with draw times, per-weapon fire modes (auto/semi/pump/bolt), magazine and shell-by-shell
-- reloads, mag check (estimate only), knife, optics (irons / reflex dot / 4x scope overlay with zoom-scaled
-- sensitivity), suppressors, tactical light. The server owns ammo, cadence, reload/draw timing and damage;
-- the client predicts the round count only for dry-fire feedback (Tarkov shows no ammo counter).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UIS = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Weapons = require(Shared.Weapons)
local Sounds = require(Shared.Sounds)
local Textures = require(Shared.Textures)
local WeaponModels = require(Shared.WeaponModels)

local Weapon = {
	aiming = false, reloading = false, healing = false, drawing = false, checking = false, light = false, scoped = false,
	ammo = 0, spare = 0, mode = 1, modeName = "SEMI", hasWeapon = false, melee = false, lastShot = 0,
	weaponName = nil, slot = nil,
}
local ctx
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

-- tunables (live-editable from the Studio dev bridge: "tune" / "pose")
local TUNE = {
	vms = 0.55, -- viewmodel scale of the shared weapon spec
	upper = 0.56, fore = 0.54, -- arm segment lengths (viewmodel studs)
	upperW = 0.21, foreW = 0.17, -- sleeve thickness (round, the forearm swells toward the elbow)
	rShoulder = Vector3.new(0.4, -0.58, 0.02), lShoulder = Vector3.new(-0.42, -0.62, -0.32),
	rPole = Vector3.new(0.7, -1, 0.3), lPole = Vector3.new(-1, -0.7, 0.1),
}
Weapon.TUNE = TUNE
local SLEEVE, GLOVE = Color3.fromHex("3E4334"), Color3.fromHex("2A2C2B")
local GLOVE_PAD, GLOVE_SEAM = Color3.fromHex("3B3E3A"), Color3.fromHex("181A19")
local ROT_Y90 = CFrame.Angles(0, math.rad(90), 0)
local L_REST = CFrame.new(-0.34, -0.68, -0.36) * CFrame.Angles(math.rad(50), 0, math.rad(20)) -- knife: free hand low
local POUCH = CFrame.new(-0.14, -0.98, -0.28) -- camera space, off-screen (rig pouches)
local BELT = CFrame.new(0.06, -0.95, -0.3) -- camera space, off-screen (shells)
local SLOT_KEYS = { Primary = "primary", Secondary = "secondary", Sidearm = "holster", Knife = "melee" }
local CYCLE = { "primary", "secondary", "holster", "melee" }
local MOUNTS = { "rail", "muzzle", "under", "side" }
local SLASH_TIME = 0.5

-- camera-space grip poses per weapon kind
local POSE = {
	long = {
		hip = CFrame.new(0.17, -0.25, -0.62) * CFrame.Angles(math.rad(1), math.rad(4), math.rad(-4)),
		sprint = CFrame.new(0.08, -0.4, -0.42) * CFrame.Angles(math.rad(-25), math.rad(45), math.rad(15)),
		reload = CFrame.new(0.15, -0.3, -0.46) * CFrame.Angles(math.rad(12), math.rad(-8), math.rad(30)),
		check = CFrame.new(0.12, -0.25, -0.46) * CFrame.Angles(math.rad(8), math.rad(-20), math.rad(52)),
		tube = CFrame.new(0.16, -0.27, -0.46) * CFrame.Angles(math.rad(10), math.rad(-6), math.rad(-55)),
		low = CFrame.new(0.26, -0.85, -0.3) * CFrame.Angles(math.rad(-60), math.rad(12), 0),
		eyeDist = 0.42,
	},
	pistol = {
		hip = CFrame.new(0.11, -0.23, -0.6) * CFrame.Angles(math.rad(2), math.rad(3), 0),
		sprint = CFrame.new(0.15, -0.48, -0.45) * CFrame.Angles(math.rad(-55), math.rad(5), 0),
		reload = CFrame.new(0.08, -0.26, -0.55) * CFrame.Angles(math.rad(15), math.rad(-10), math.rad(25)),
		check = CFrame.new(0.06, -0.22, -0.5) * CFrame.Angles(math.rad(10), math.rad(-15), math.rad(45)),
		low = CFrame.new(0.2, -0.8, -0.35) * CFrame.Angles(math.rad(-70), 0, 0),
		eyeDist = 0.48,
	},
	melee = {
		hip = CFrame.new(0.32, -0.36, -0.55) * CFrame.Angles(math.rad(22), math.rad(12), math.rad(-28)),
		sprint = CFrame.new(0.3, -0.5, -0.4) * CFrame.Angles(math.rad(-30), math.rad(10), math.rad(-20)),
		low = CFrame.new(0.3, -0.85, -0.3) * CFrame.Angles(math.rad(-60), 0, 0),
		windup = CFrame.new(0.48, -0.14, -0.38) * CFrame.Angles(math.rad(25), math.rad(45), math.rad(-70)),
		follow = CFrame.new(-0.28, -0.46, -0.72) * CFrame.Angles(math.rad(-15), math.rad(-55), math.rad(-85)),
	},
}

Weapon.POSE = POSE

local vm = nil
local seq = 0
local fireLatch, dryLatch = false, false
local aimWanted = false
local aimA, sprintA, reloadA, checkA, tubeA, raise = 0, 0, 0, 0, 0, 0
local reloadT0, reloadDur, joltDone = nil, 2.2, false
local tubeT0, tubePeriod = nil, 0.55
local cycleT0, cycleDur, cycleKind = nil, 0, nil -- pump / bolt cycling after a shot
local slashT0, slashSent = nil, false
local checkT0, checkDur = nil, 1.1
local drawT0, drawDur = -10, 0.6
local switching = nil -- { slot, t0 } while the server swaps weapons
local lastActiveG = nil
local kickZ, kickRot, kickRoll = 0, 0, 0
local sway = CFrame.identity
local scopeGui, scopeImg, scopeBars, reflexDot
local tpLightT = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function ease(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function phase(p, a, b)
	return ease((p - a) / (b - a))
end

local function alive()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0 and hum or nil, char
end

-- ── snapshot helpers ──────────────────────────────────────────────────────────
local function activeItem()
	local d = ctx.State.data
	if not d or not d.slots or not d.active then
		return nil, d, nil
	end
	local g = d.slots[d.active]
	return g and d.items[g], d, g
end

local function weaponDef(it)
	local idef = it and Items.defs[it.id]
	return idef and idef.weapon and Weapons[idef.weapon], idef
end

local function weaponIn(slot)
	local d = ctx.State.data
	local g = d and d.slots and d.slots[slot]
	local it = g and d.items[g]
	return weaponDef(it) ~= nil
end

-- rounds in the weapon (magazine or tube), magazines a reload would take (rig, then pockets), has weapon, def.
-- `predicted` overrides the snapshot's round count (shots are not echoed back in snapshots).
local function computeAmmo(predicted)
	local it, d = activeItem()
	local def, idef = weaponDef(it)
	if not def then
		return 0, 0, false, nil
	end
	if def.melee then
		return 0, 0, true, def
	end
	local rounds = (idef.family and it.mag and d.items[it.mag]) or ((not idef.family) and it) or nil
	local cur = rounds and rounds.a or 0
	if predicted and rounds then
		cur = math.min(cur, predicted)
	end
	local better = 0
	if idef.family then
		local floor = it.mag and cur or -1
		local cids = {}
		if d.slots.rig then
			table.insert(cids, d.slots.rig)
		end
		table.insert(cids, "pockets")
		for _, cid in cids do
			for gg in (d.grids and d.grids[cid]) or {} do
				local x = d.items[gg]
				local xd = x and Items.defs[x.id]
				if xd and xd.kind == "mag" and xd.family == idef.family and (x.a or 0) > floor then
					better += 1
				end
			end
		end
	end
	return cur, better, true, def
end
Weapon.computeAmmo = computeAmmo

local function ammoDefOf(it, d)
	local idef = it and Items.defs[it.id]
	local rounds = idef and ((idef.family and it.mag and d.items[it.mag]) or ((not idef.family) and it))
	local ad = rounds and rounds.at and Items.defs[rounds.at]
	return ad and ad.ammo
end

-- ── viewmodel ────────────────────────────────────────────────────────────────
local function vmKey(it, g)
	local k = { g, it.mag and "M" or "-" }
	for _, mount in MOUNTS do
		k[#k + 1] = (it.mods and it.mods[mount]) or "-"
	end
	return table.concat(k, "|")
end

local function vpart(model, size, color, mat)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function destroyVm()
	if vm then
		vm.model:Destroy()
		vm = nil
	end
end

local function buildVm(it, d, g)
	destroyVm()
	local def = weaponDef(it)
	local VMS = TUNE.vms
	local b = def and WeaponModels.build(d.items, it, CFrame.identity, VMS)
	if not b then
		return
	end
	local model = Instance.new("Model")
	model.Name = "ZR_Viewmodel"
	local o = {
		model = model, def = def, g = g, key = vmKey(it, g), all = {}, offs = {}, kinds = {}, cfs = {},
		kind = def.melee and "melee" or (b.spec.pistol and "pistol" or "long"),
		anchors = b.anchors, ms = WeaponModels.modStats(d.items, it), eye = b.eye * VMS, muzzle = b.muzzle * VMS,
		zoom = b.zoom, reflex = b.reflex == true, magParts = {}, magHidden = false, grip = CFrame.identity,
	}
	local tag = {}
	for name, list in b.moving do
		for _, p in list do
			tag[p] = name
		end
	end
	local function add(p, kind)
		p.Anchored = true
		p.CastShadow = false
		p.Parent = model
		table.insert(o.all, p)
		table.insert(o.offs, p.CFrame)
		table.insert(o.kinds, kind)
		table.insert(o.cfs, p.CFrame)
	end
	for _, p in b.parts do
		add(p, tag[p] or "gun")
	end
	for _, p in b.mag do
		add(p, "mag")
		table.insert(o.magParts, p)
	end
	o.nFixed = #o.all
	-- arms (posed by two-bone IK every frame), then the shell used by tube reloads. Sleeves match the body's
	-- jacket (PMC or scav clothes).
	o.vms = VMS
	local sleeve = SLEEVE
	local me = game:GetService("Players").LocalPlayer.Character
	local ua = me and me:FindFirstChild("LeftUpperArm")
	if ua and ua:IsA("BasePart") then
		sleeve = ua.Color:Lerp(Color3.new(0, 0, 0), 0.18)
	end
	-- each arm: round sleeve (upper arm, elbow, forearm with a fuller elbow end, darker cuff) and a gloved
	-- hand (back of hand with a knuckle pad, curled fingers, thumb) - not sticks
	local cuffC = sleeve:Lerp(Color3.new(0, 0, 0), 0.35)
	local function round(size, color, mat, shape)
		local p = vpart(model, size, color, mat)
		p.Shape = shape or Enum.PartType.Cylinder
		return p
	end
	local function arm()
		return {
			upper = round(Vector3.new(TUNE.upper, TUNE.upperW, TUNE.upperW), sleeve, Enum.Material.Fabric),
			elbow = round(Vector3.new(TUNE.upperW * 0.98, TUNE.upperW * 0.98, TUNE.upperW * 0.98), sleeve, Enum.Material.Fabric, Enum.PartType.Ball),
			fore = round(Vector3.new(TUNE.fore, TUNE.foreW, TUNE.foreW), sleeve, Enum.Material.Fabric),
			bulk = round(Vector3.new(TUNE.fore * 0.5, TUNE.foreW * 1.16, TUNE.foreW * 1.16), sleeve, Enum.Material.Fabric),
			cuff = round(Vector3.new(0.06, TUNE.foreW * 1.1, TUNE.foreW * 1.1), cuffC, Enum.Material.Fabric),
			palm = vpart(model, Vector3.new(0.05, 0.14, 0.13), GLOVE, Enum.Material.Fabric),
			pad = vpart(model, Vector3.new(0.022, 0.09, 0.1), GLOVE_PAD),
			fingers = vpart(model, Vector3.new(0.045, 0.125, 0.085), GLOVE, Enum.Material.Fabric),
			thumb = vpart(model, Vector3.new(0.034, 0.034, 0.08), GLOVE, Enum.Material.Fabric),
			seam = vpart(model, Vector3.new(0.056, 0.02, 0.135), GLOVE_SEAM),
		}
	end
	o.armR, o.armL = arm(), arm()
	o.armOrder = { "upper", "elbow", "fore", "bulk", "cuff", "palm", "pad", "fingers", "thumb", "seam" }
	o.arms = {}
	for _, a in { o.armR, o.armL } do
		for _, k in o.armOrder do
			table.insert(o.arms, a[k])
			table.insert(o.all, a[k])
			table.insert(o.cfs, a[k].CFrame)
		end
	end
	o.shell = vpart(model, Vector3.new(0.11, 0.042, 0.042), Color3.fromHex("8E2B22"))
	o.shell.Shape = Enum.PartType.Cylinder
	o.shell.Transparency = 1
	table.insert(o.all, o.shell)
	table.insert(o.cfs, o.shell.CFrame)
	if b.lightPart then
		local l = Instance.new("SpotLight")
		l.Face = Enum.NormalId.Right
		l.Range = 42
		l.Angle = 42
		l.Brightness = 3.2
		l.Color = Color3.fromRGB(255, 244, 222)
		l.Shadows = true
		l.Enabled = Weapon.light
		l.Parent = b.lightPart
		o.lamp = l
	end
	local A = b.anchors
	o.rHand = CFrame.new((A.grip or Vector3.zero) * VMS) * CFrame.Angles(math.rad(-16), 0, 0) * CFrame.new(0.012, 0, 0)
	o.lHand = CFrame.new((A.hand or Vector3.zero) * VMS) * CFrame.new(-0.012, -0.03, 0) * CFrame.Angles(0, 0, math.rad(-20))
	if A.magwell and #o.magParts > 0 then
		o.magGrab = CFrame.new(A.magwell * VMS + Vector3.new(-0.02, -0.1, 0))
	end
	if A.port then
		o.port = CFrame.new(A.port * VMS) * CFrame.new(-0.02, -0.04, 0.02)
	end
	if A.bolt then
		o.bolt = CFrame.new(A.bolt * VMS) * CFrame.Angles(0, 0, math.rad(-70))
	end
	vm = o
end

-- two-bone IK: elbow position for shoulder S, wrist W, segment lengths a/b, pole direction
local function solve(S, W, a, b, pole)
	local d = W - S
	local dist = d.Magnitude
	local u = dist > 1e-4 and d / dist or Vector3.new(0, 0, -1)
	dist = math.clamp(dist, math.abs(a - b) + 1e-3, a + b - 1e-3)
	local cosA = (a * a + dist * dist - b * b) / (2 * a * dist)
	local sinA = math.sqrt(math.max(0, 1 - cosA * cosA))
	local p = pole - u * pole:Dot(u)
	if p.Magnitude < 1e-4 then
		p = Vector3.new(0, -1, 0)
	end
	return S + u * (a * cosA) + p.Unit * (a * sinA)
end

local function limb(part, from, to, thick)
	local len = (to - from).Magnitude
	if math.abs(part.Size.Z - len) > 0.01 then
		part.Size = Vector3.new(thick, thick, math.max(0.05, len))
	end
	return CFrame.lookAt((from + to) / 2, to)
end

-- a round (cylinder) sleeve segment from `from` to `to`: the cylinder axis is the part's X
local function seg(part, from, to)
	local len = math.max(0.03, (to - from).Magnitude)
	if math.abs(part.Size.X - len) > 0.01 then
		part.Size = Vector3.new(len, part.Size.Y, part.Size.Z)
	end
	return CFrame.lookAt((from + to) / 2, to) * ROT_Y90
end

-- one arm's CFrames: shoulder S, elbow E, wrist W and the hand frame H; side = 1 right hand (pistol grip),
-- -1 left hand (under the handguard)
local function armCFrames(a, S, E, W, H, side, out, i)
	local dir = (W - E)
	dir = dir.Magnitude > 1e-4 and dir.Unit or Vector3.new(0, 0, -1)
	out[i] = seg(a.upper, S, E)
	out[i + 1] = CFrame.new(E)
	out[i + 2] = seg(a.fore, E, W)
	out[i + 3] = seg(a.bulk, E + dir * 0.02, E + (W - E) * 0.5)
	out[i + 4] = seg(a.cuff, W - dir * 0.07, W - dir * 0.01)
	if side > 0 then
		-- wrapped around the pistol grip: back of the hand outside, fingers on the far side, thumb over the top
		out[i + 5] = H * CFrame.new(0.032, 0, 0.012)
		out[i + 6] = H * CFrame.new(0.06, 0.008, 0.012)
		out[i + 7] = H * CFrame.new(-0.036, -0.006, -0.018)
		out[i + 8] = H * CFrame.new(-0.022, 0.072, -0.036) * CFrame.Angles(math.rad(-25), math.rad(18), 0)
		out[i + 9] = H * CFrame.new(0.032, -0.072, 0.012)
	else
		-- cupping the handguard from below: palm under it, fingers up the far side, thumb along the near side
		out[i + 5] = H * CFrame.new(0, -0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
		out[i + 6] = H * CFrame.new(0, -0.08, 0.004) * CFrame.Angles(0, 0, math.rad(90))
		out[i + 7] = H * CFrame.new(0.052, -0.006, -0.006)
		out[i + 8] = H * CFrame.new(-0.05, 0.004, -0.02) * CFrame.Angles(math.rad(-10), 0, 0)
		out[i + 9] = H * CFrame.new(0, -0.05, 0.066) * CFrame.Angles(0, 0, math.rad(90))
	end
	return i + 10
end

local function setMagHidden(o, hidden)
	if o.magHidden ~= hidden then
		o.magHidden = hidden
		for _, p in o.magParts do
			p.Transparency = hidden and 1 or 0
		end
	end
end

-- ── optics ───────────────────────────────────────────────────────────────────
function Weapon.aimFov(base)
	if vm and vm.zoom and aimA > 0.5 then
		return math.deg(2 * math.atan(math.tan(math.rad(base) / 2) / vm.zoom))
	end
	return base * Config.AIM_FOV_MUL
end

-- look sensitivity multiplier while aiming (scaled with magnification)
function Weapon.aimSens()
	local base = (ctx.Settings.data.fov or Config.FOV)
	return 0.62 * Weapon.aimFov(base) / (base * Config.AIM_FOV_MUL)
end

local function buildScope()
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("ZR_Scope")
	if old then
		old:Destroy()
	end
	scopeGui = Instance.new("ScreenGui")
	scopeGui.Name = "ZR_Scope"
	scopeGui.IgnoreGuiInset = true
	scopeGui.ScreenInsets = Enum.ScreenInsets.None
	scopeGui.ResetOnSpawn = false
	scopeGui.DisplayOrder = 1 -- under the grain/lens overlay (2) and the HUD (5)
	scopeGui.Enabled = false
	scopeImg = Instance.new("ImageLabel")
	scopeImg.Name = "Eyepiece"
	scopeImg.AnchorPoint = Vector2.new(0.5, 0.5)
	scopeImg.Position = UDim2.fromScale(0.5, 0.5)
	scopeImg.Size = UDim2.fromScale(1, 1)
	scopeImg.SizeConstraint = Enum.SizeConstraint.RelativeYY
	scopeImg.BackgroundTransparency = 1
	scopeImg.Image = Textures.SCOPE
	scopeImg.Visible = false
	scopeImg.Parent = scopeGui
	scopeBars = {}
	for side = 0, 1 do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.AnchorPoint = Vector2.new(side, 0)
		f.Position = UDim2.fromScale(side, 0)
		f.Size = UDim2.new(0, 0, 1, 0)
		f.Visible = false
		f.Parent = scopeGui
		scopeBars[side + 1] = f
	end
	reflexDot = Instance.new("Frame")
	reflexDot.Name = "ReflexDot"
	reflexDot.AnchorPoint = Vector2.new(0.5, 0.5)
	reflexDot.Position = UDim2.fromScale(0.5, 0.5)
	reflexDot.Size = UDim2.fromOffset(5, 5)
	reflexDot.BackgroundColor3 = Color3.fromRGB(255, 52, 40)
	reflexDot.BorderSizePixel = 0
	reflexDot.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = reflexDot
	reflexDot.Parent = scopeGui
	scopeGui.Parent = pg
end

local function updateOptics(show)
	if not scopeGui then
		return
	end
	local scoped = show and vm ~= nil and vm.zoom ~= nil and aimA > 0.85
	local dotOn = show and vm ~= nil and vm.reflex and aimA > 0.8
	Weapon.scoped = scoped
	scopeGui.Enabled = scoped or dotOn
	scopeImg.Visible = scoped
	reflexDot.Visible = dotOn and not scoped
	if scoped then
		local v = cam.ViewportSize
		local w = math.max(0, (v.X - v.Y) / 2 + 2)
		for _, f in scopeBars do
			f.Visible = true
			f.Size = UDim2.new(0, w, 1, 0)
		end
	else
		for _, f in scopeBars do
			f.Visible = false
		end
	end
end

-- ── actions ──────────────────────────────────────────────────────────────────
local function canAim()
	local M = ctx.Movement
	if M and (M.busy() or (M.prone and ctx.Camera.speed > 0.6)) then
		return false -- stance transitions, vaults; no ADS while crawling (Tarkov)
	end
	return vm ~= nil and not Weapon.melee and not Weapon.reloading and not Weapon.checking and not Weapon.healing
		and switching == nil and ctx.State.inRaid() and not ctx.Input.isMenu()
end

function Weapon.cancelAim()
	aimWanted = false
	Weapon.aiming = false
end

function Weapon.setAim(on)
	aimWanted = on == true
end

local function canFire()
	local M = ctx.Movement
	if not (ctx.State.inRaid() and vm and Weapon.hasWeapon and not Weapon.melee) then
		return false
	end
	if (Weapon.reloading and not tubeT0) or Weapon.healing or Weapon.drawing or Weapon.checking or switching or cycleT0 then
		return false
	end
	if ctx.Input.isMenu() or (M and (M.sprinting or M.busy())) or sprintA > 0.35 then
		return false
	end
	return alive() ~= nil
end

local function fireOnce()
	local o = vm
	local def = o.def
	local t = os.clock()
	if t - Weapon.lastShot < 60 / def.rpm then
		return
	end
	if Weapon.ammo <= 0 then
		if not dryLatch then
			dryLatch = true
			ctx.Effects.sound(Sounds.DRY_FIRE, SoundService, 0.6)
		end
		return
	end
	if tubeT0 then
		tubeT0 = nil -- firing interrupts shell-by-shell loading (the server does the same)
		Weapon.reloading = false
	end
	Weapon.lastShot = t
	seq += 1
	Weapon.ammo -= 1
	local M = ctx.Movement
	local crouch = M and M.crouching
	local camCF = ctx.Camera.aimCFrame or cam.CFrame -- free look does not move the weapon
	local spread = Weapon.aiming and def.aimSpread or def.hipSpread
	if ctx.Camera.speed > 2 then
		spread += def.moveSpread * (Weapon.aiming and 0.35 or 1)
	end
	if crouch then
		spread *= 0.8
	end
	local r = math.rad(spread) * 0.5
	local dir = (camCF * CFrame.Angles((math.random() * 2 - 1) * r, (math.random() * 2 - 1) * r, 0)).LookVector
	local origin = camCF.Position
	ctx.State.shoot(seq, origin, dir)
	rayParams.FilterDescendantsInstances = { player.Character, o.model, workspace:FindFirstChild("ZR_Fx") }
	local res = workspace:Raycast(origin, dir * def.range, rayParams)
	local hit = res and res.Position or (origin + dir * def.range)
	local muzzle = (o.grip * CFrame.new(o.muzzle)).Position
	if not o.ms.suppressed and not Weapon.scoped then
		ctx.Effects.flash(muzzle)
		if ctx.Post then
			ctx.Post.burst(0.22)
		end
	end
	local it, d = activeItem()
	local ammo = it and ammoDefOf(it, d)
	if ammo and ammo.tracer then
		ctx.Effects.tracer(muzzle, hit) -- Tarkov: only tracer rounds leave a visible trace
	end
	if res then
		local m = res.Instance:FindFirstAncestorOfClass("Model")
		local body = m and m:FindFirstChildOfClass("Humanoid") ~= nil
		ctx.Effects.impact(res.Position, res.Normal, body)
		ctx.Effects.impactSound(res.Position, body, res.Material)
	end
	ctx.Effects.gunSound(def.id, SoundService, o.ms.suppressed, false)
	local k = (Weapon.aiming and 0.72 or 1) * (crouch and 0.85 or 1) * o.ms.recoil
	ctx.Camera.kick(def.recoilV * k, (math.random() * 2 - 1) * def.recoilH * k)
	kickZ += 0.045 * k
	kickRot += math.rad(2.2) * k
	kickRoll += (math.random() * 2 - 1) * math.rad(1.2) * k
	local mode = def.modes[Weapon.mode]
	if mode == "PUMP" or mode == "BOLT" then
		cycleKind = mode
		cycleT0 = t + 0.08
		cycleDur = mode == "PUMP" and 0.45 or 0.95
		local seq = mode == "PUMP" and { { 0.12, "pump_back" }, { 0.32, "pump_fwd" } }
			or { { 0.2, "bolt_up" }, { 0.32, "bolt_back" }, { 0.55, "bolt_fwd" }, { 0.75, "bolt_down" } }
		for _, e in seq do
			task.delay(e[1] + 0.08, function()
				ctx.Effects.sfx(e[2], SoundService, 0.5)
			end)
		end
	end
end

function Weapon.startReload()
	local o = vm
	if not o or Weapon.melee or not ctx.State.inRaid() or Weapon.reloading or Weapon.drawing or Weapon.checking or switching or Weapon.healing then
		return
	end
	if o.def.internal then
		ctx.State.act("reload") -- the server streams shells; its "tube" note starts the loop animation
		return
	end
	local cur, better = computeAmmo(Weapon.ammo)
	if better <= 0 then
		ctx.State.toast("NO SPARE MAGAZINES", "warn")
		return
	end
	local vit = ctx.State.vitals
	local slow = (vit and vit.mods and vit.mods.reload) or 1
	Weapon.reloading = true
	reloadT0 = os.clock()
	reloadDur = ((cur > 0) and o.def.reload or o.def.reloadEmpty) * slow
	joltDone = false
	ctx.State.act("reload")
	local token = reloadT0
	local empty = cur <= 0
	for _, e in { { 0.14, "mag_out" }, { 0.45, "cloth_1" }, { 0.76, "mag_in" }, { 0.93, empty and "bolt_fwd" or nil } } do
		if e[2] then
			task.delay(reloadDur * e[1], function()
				if reloadT0 == token then
					ctx.Effects.sfx(e[2], SoundService, 0.55)
				end
			end)
		end
	end
	task.delay(reloadDur + 1.0, function()
		if Weapon.reloading and reloadT0 == token then
			Weapon.reloading = false -- the server never confirmed; resync from the snapshot
			reloadT0 = nil
			Weapon.ammo = (computeAmmo())
		end
	end)
end

function Weapon.magCheck()
	if not vm or Weapon.melee or not ctx.State.inRaid() or Weapon.reloading or Weapon.drawing or Weapon.checking or switching or Weapon.healing then
		return
	end
	Weapon.checking = true
	checkT0 = os.clock()
	ctx.State.act("magcheck")
	ctx.Effects.sfx("mag_out", SoundService, 0.25, 1.15)
	local token = checkT0
	task.delay(checkDur + 1.4, function()
		if checkT0 == token then
			Weapon.checking = false
			checkT0 = nil
		end
	end)
end

function Weapon.slash()
	local o = vm
	if not o or not Weapon.melee or not ctx.State.inRaid() or slashT0 or Weapon.drawing or switching or Weapon.healing or ctx.Input.isMenu() then
		return
	end
	local t = os.clock()
	if t - Weapon.lastShot < 60 / o.def.rpm then
		return
	end
	Weapon.lastShot = t
	slashT0 = t
	slashSent = false
	ctx.Effects.sfx("knife_whoosh", SoundService, 0.55, 0.95 + math.random() * 0.1)
end

function Weapon.switchTo(slot)
	local d = ctx.State.data
	if not ctx.State.inRaid() or not d or d.active == slot or not weaponIn(slot) or switching or Weapon.healing then
		return
	end
	tubeT0, reloadT0, checkT0, slashT0, cycleT0 = nil, nil, nil, nil, nil
	Weapon.reloading, Weapon.checking = false, false
	Weapon.cancelAim()
	switching = { slot = slot, t0 = os.clock() }
	ctx.State.act("draw", { slot = slot })
	task.delay(1.3, function()
		if switching and switching.slot == slot and os.clock() - switching.t0 >= 1.2 then
			switching = nil -- the server refused: bring the current weapon back up
		end
	end)
end

function Weapon.cycleWeapon()
	local d = ctx.State.data
	if not d then
		return
	end
	local cur = 1
	for i, s in CYCLE do
		if s == d.active then
			cur = i
		end
	end
	for k = 1, #CYCLE - 1 do
		local s = CYCLE[(cur + k - 1) % #CYCLE + 1]
		if weaponIn(s) then
			Weapon.switchTo(s)
			return
		end
	end
end

function Weapon.toggleLight()
	if not vm or not vm.ms.light or not ctx.State.inRaid() then
		return
	end
	Weapon.light = not Weapon.light
	if vm.lamp then
		vm.lamp.Enabled = Weapon.light
	end
	ctx.Effects.sfx("selector", SoundService, 0.5, 1.3)
	ctx.State.act("light", { on = Weapon.light })
end

-- Studio tuning: rebuild the viewmodel (after changing TUNE.vms or arm sizes)
function Weapon.rebuild()
	local it, d, g = activeItem()
	if it then
		buildVm(it, d, g)
	end
end

function Weapon.fireForTest(n)
	if not vm then
		return "no weapon"
	end
	for _ = 1, n or 1 do
		Weapon.lastShot = 0
		if canFire() then
			fireOnce()
		end
		task.wait(math.max(60 / vm.def.rpm, cycleDur) + 0.05)
	end
	return Weapon.ammo
end

-- ── frame update ─────────────────────────────────────────────────────────────
local function handleFire()
	local fireDown = ctx.Input.down("Fire")
	if vm and fireDown and ctx.State.inRaid() then
		if Weapon.melee then
			if not fireLatch then
				fireLatch = true
				Weapon.slash()
			end
		else
			local mode = vm.def.modes[Weapon.mode]
			if mode == "AUTO" then
				if canFire() then
					fireOnce()
				end
			elseif not fireLatch then
				fireLatch = true
				if canFire() then
					fireOnce()
				end
			end
		end
	end
	if not fireDown then
		fireLatch = false
		dryLatch = false
	end
end

local function update(dt)
	local hum, char = alive()
	local inRaid = ctx.State.inRaid()
	local now = os.clock()
	Weapon.drawing = now - drawT0 < drawDur
	if cycleT0 and now - cycleT0 >= cycleDur then
		cycleT0 = nil
	end
	if slashT0 then
		local p = (now - slashT0) / SLASH_TIME
		if p >= 0.3 and not slashSent then
			slashSent = true
			local lv = (ctx.Camera.aimCFrame or cam.CFrame).LookVector
			ctx.State.act("melee", { x = lv.X, y = lv.Y, z = lv.Z })
		end
		if p >= 1 then
			slashT0 = nil
		end
	end
	handleFire()
	Weapon.aiming = aimWanted and canAim()
	local o = vm
	local show = o ~= nil and inRaid and hum ~= nil and not ctx.Input.isMenu() and not ctx.Camera.orbit
	-- local player's own third-person weapon light stays off (the viewmodel lamp lights the scene)
	if now - tpLightT > 0.25 and char then
		tpLightT = now
		for _, c in char:GetChildren() do
			if c.Name == "TPWeapon" then
				local l = c:FindFirstChild("WeaponLight")
				if l and l.Enabled then
					l.Enabled = false
				end
			end
		end
	end
	-- pose blends
	local ergo = o and (o.def.ergo + o.ms.ergo) or 50
	aimA += ((Weapon.aiming and 1 or 0) - aimA) * math.min(1, dt * (6 + ergo / 10))
	local M = ctx.Movement
	sprintA += (((M and M.sprinting) and 1 or 0) - sprintA) * math.min(1, dt * 9)
	reloadA += (((Weapon.reloading and not tubeT0) and 1 or 0) - reloadA) * math.min(1, dt * 10)
	tubeA += ((tubeT0 and 1 or 0) - tubeA) * math.min(1, dt * 10)
	checkA += ((Weapon.checking and 1 or 0) - checkA) * math.min(1, dt * 10)
	if Weapon.drawing and not switching then
		raise = ease((now - drawT0) / math.max(0.05, drawDur))
	else
		local Mv = ctx.Movement
		local target = (switching and 0) or (Weapon.healing and 0.3) or ((Mv and Mv.vaulting) and 0.2) or 1
		raise += (target - raise) * math.min(1, dt * 9)
	end
	kickZ -= kickZ * math.min(1, dt * 14)
	kickRot -= kickRot * math.min(1, dt * 12)
	kickRoll -= kickRoll * math.min(1, dt * 10)
	updateOptics(show)
	if o then
		o.model.Parent = (show and not Weapon.scoped) and cam or nil
	end
	if not show or Weapon.scoped then
		return
	end
	-- base pose
	local P = POSE[o.kind]
	local base = P.hip
	if o.kind ~= "melee" then
		local e = o.eye
		base = base:Lerp(CFrame.new(-e.X, -e.Y, -(P.eyeDist or 0.34) - e.Z), aimA)
	end
	base = base:Lerp(P.sprint, sprintA * (1 - aimA))
	if P.reload then
		base = base:Lerp(P.reload, reloadA)
	end
	if P.tube then
		base = base:Lerp(P.tube, tubeA)
	end
	if P.check then
		base = base:Lerp(P.check, checkA)
	end
	if slashT0 then
		local p = (now - slashT0) / SLASH_TIME
		if p < 0.25 then
			base = base:Lerp(P.windup, ease(p / 0.25))
		elseif p < 0.5 then
			base = P.windup:Lerp(P.follow, ease((p - 0.25) / 0.25))
		else
			base = P.follow:Lerp(base, ease((p - 0.5) / 0.5))
		end
	end
	base = P.low:Lerp(base, raise)
	-- sway (lags behind look input; less with good ergonomics and when aiming), bob, wall pullback
	local md = UIS:GetMouseDelta()
	local motion = ctx.Settings.data.reduceMotion and 0.3 or 1
	local swayK = motion * (1 - aimA * 0.7) * (1.5 - math.clamp(ergo, 0, 100) / 100)
	local sx = math.clamp(-md.X * 0.0014, -0.08, 0.08) * swayK
	local sy = math.clamp(-md.Y * 0.0014, -0.08, 0.08) * swayK
	sway = sway:Lerp(CFrame.Angles(sy, sx, sx * 0.6), math.min(1, dt * 10))
	local ph = ctx.Camera.bobPhase
	local bobAmt = math.clamp(ctx.Camera.speed / 16, 0, 1.2) * (1 - aimA * 0.85) * motion
	local bob = CFrame.new(math.cos(ph) * 0.03 * bobAmt, -math.abs(math.sin(ph)) * 0.025 * bobAmt, 0)
	rayParams.FilterDescendantsInstances = { char, o.model, workspace:FindFirstChild("ZR_Fx") }
	local camCF = ctx.Camera.aimCFrame or cam.CFrame
	local wallHit = workspace:Raycast(camCF.Position, camCF.LookVector * 1.7, rayParams)
	local push = wallHit and (1.7 - wallHit.Distance) or 0
	local pull = CFrame.new(0, -push * 0.12, push * 0.75) * CFrame.Angles(push * 0.22, 0, 0)
	local grip = camCF * base * bob * sway * pull * CFrame.new(0, 0, kickZ) * CFrame.Angles(kickRot, 0, kickRoll)
	o.grip = grip
	-- hands, magazine, pump, bolt, shell
	local lHand = (o.kind == "melee") and (camCF * L_REST) or (grip * o.lHand)
	local rHand = grip * o.rHand
	local magW = grip
	local pumpD, boltD = CFrame.identity, CFrame.identity
	local shellOn = false
	local hidden = false
	if reloadT0 and Weapon.reloading and not tubeT0 and o.magGrab then
		local p = (now - reloadT0) / reloadDur
		local grab = o.magGrab
		local out = CFrame.new(0, -0.3, 0.06) * CFrame.Angles(math.rad(-25), 0, 0)
		local pouch = camCF * POUCH
		if p < 0.14 then
			lHand = lHand:Lerp(grip * grab, phase(p, 0, 0.14))
		elseif p < 0.3 then
			magW = grip * CFrame.identity:Lerp(out, phase(p, 0.14, 0.3))
			lHand = magW * grab
		elseif p < 0.42 then
			local k = phase(p, 0.3, 0.42)
			lHand = (grip * out * grab):Lerp(pouch, k)
			magW = lHand * grab:Inverse()
			hidden = k > 0.85
		elseif p < 0.6 then
			lHand = pouch
			hidden = true
		elseif p < 0.72 then
			lHand = pouch:Lerp(grip * out * grab, phase(p, 0.6, 0.72))
			magW = lHand * grab:Inverse()
		elseif p < 0.8 then
			magW = grip * out:Lerp(CFrame.identity, phase(p, 0.72, 0.8))
			lHand = magW * grab
		else
			if not joltDone then
				joltDone = true
				kickRot += math.rad(1.6)
				kickZ += 0.02
			end
			lHand = (grip * grab):Lerp(grip * o.lHand, phase(p, 0.8, 1))
		end
	elseif checkT0 and Weapon.checking and o.magGrab then
		local p = (now - checkT0) / checkDur
		local grab = o.magGrab
		local pulled = CFrame.new(0, -0.05, 0.012) * CFrame.Angles(math.rad(-6), 0, 0)
		if p < 0.25 then
			lHand = lHand:Lerp(grip * grab, phase(p, 0, 0.25))
		elseif p < 0.75 then
			magW = grip * CFrame.identity:Lerp(pulled, phase(p, 0.25, 0.45) - phase(p, 0.6, 0.75))
			lHand = magW * grab
		else
			lHand = (grip * grab):Lerp(lHand, phase(p, 0.75, 1))
		end
	elseif tubeT0 and o.port then
		local p = ((now - tubeT0) % tubePeriod) / tubePeriod
		local belt = camCF * BELT
		local port = grip * o.port
		if p < 0.35 then
			lHand = port:Lerp(belt, phase(p, 0, 0.35))
		elseif p < 0.7 then
			lHand = belt:Lerp(port * CFrame.new(0, -0.03, 0.04), phase(p, 0.35, 0.7))
			shellOn = true
		elseif p < 0.85 then
			lHand = (port * CFrame.new(0, -0.03, 0.04)):Lerp(port, phase(p, 0.7, 0.85))
			shellOn = p < 0.8
		else
			lHand = port
		end
	end
	if cycleT0 then
		local p = math.clamp((now - cycleT0) / cycleDur, 0, 1)
		if cycleKind == "PUMP" then
			local z = 0.14 * o.vms * (p < 0.45 and phase(p, 0, 0.45) or (1 - phase(p, 0.45, 1)))
			pumpD = CFrame.new(0, 0, z)
			lHand = grip * pumpD * o.lHand
		elseif cycleKind == "BOLT" and o.bolt then
			local lift = 0.035 * o.vms * (phase(p, 0.18, 0.3) - phase(p, 0.68, 0.78))
			local back = 0.22 * o.vms * (phase(p, 0.3, 0.5) - phase(p, 0.5, 0.68))
			boltD = CFrame.new(0, lift, back)
			local knob = grip * boltD * o.bolt
			if p < 0.18 then
				rHand = rHand:Lerp(knob, phase(p, 0, 0.18))
			elseif p < 0.78 then
				rHand = knob
			else
				rHand = knob:Lerp(rHand, phase(p, 0.78, 1))
			end
		end
	end
	setMagHidden(o, hidden)
	-- write CFrames
	local cfs, offs, kinds = o.cfs, o.offs, o.kinds
	for i = 1, o.nFixed do
		local kind = kinds[i]
		if kind == "gun" then
			cfs[i] = grip * offs[i]
		elseif kind == "mag" then
			cfs[i] = magW * offs[i]
		elseif kind == "pump" then
			cfs[i] = grip * pumpD * offs[i]
		else
			cfs[i] = grip * boltD * offs[i]
		end
	end
	local rS, lS = camCF * TUNE.rShoulder, camCF * TUNE.lShoulder
	local rW = (rHand * CFrame.new(0, -0.04, 0.08)).Position
	local lW = (lHand * CFrame.new(-0.02, -0.035, 0.08)).Position
	local rE = solve(rS, rW, TUNE.upper, TUNE.fore, camCF:VectorToWorldSpace(TUNE.rPole))
	local lE = solve(lS, lW, TUNE.upper, TUNE.fore, camCF:VectorToWorldSpace(TUNE.lPole))
	local n = o.nFixed
	local nxt = armCFrames(o.armR, rS, rE, rW, rHand, 1, cfs, n + 1)
	nxt = armCFrames(o.armL, lS, lE, lW, lHand, -1, cfs, nxt)
	if (o.shell.Transparency < 1) ~= shellOn then
		o.shell.Transparency = shellOn and 0 or 1
	end
	cfs[nxt] = lHand * CFrame.new(0, 0.045, -0.05)
	workspace:BulkMoveTo(o.all, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

-- ── state sync ───────────────────────────────────────────────────────────────
local function resetActions()
	tubeT0, reloadT0, checkT0, slashT0, cycleT0, switching = nil, nil, nil, nil, nil, nil
	Weapon.reloading, Weapon.checking, Weapon.healing = false, false, false
	Weapon.cancelAim()
end

local function onSnapshot()
	local it, d, g = activeItem()
	local cur, better, has, def = computeAmmo()
	Weapon.spare = better
	if not ctx.State.inRaid() or not has then
		Weapon.hasWeapon = false
		destroyVm()
		lastActiveG = nil
		Weapon.light = false
		resetActions()
		return
	end
	Weapon.hasWeapon = true
	if not vm or vm.key ~= vmKey(it, g) then
		buildVm(it, d, g)
	end
	if g ~= lastActiveG then
		-- a different weapon came into the hands
		lastActiveG = g
		switching = nil
		Weapon.mode = 1
		Weapon.light = false
		raise = 0
		if os.clock() - drawT0 > 0.5 then
			drawT0, drawDur = os.clock(), def.draw or 0.6
		end
		Weapon.ammo = cur
		dryLatch = false
	elseif os.clock() - Weapon.lastShot > 0.6 and not Weapon.reloading then
		Weapon.ammo = cur
	end
	Weapon.melee = def.melee == true
	Weapon.slot = d.active
	local mass = Items.defs[it.id].mass or 3
	for _, mg in it.mods or {} do
		local mi = d.items[mg]
		mass += mi and Items.defs[mi.id] and Items.defs[mi.id].mass or 0
	end
	Weapon.mass = mass
	Weapon.weaponName = string.upper(Items.defs[it.id].name)
	Weapon.modeName = def.modes[Weapon.mode] or def.modes[1]
end

function Weapon.init(c)
	ctx = c
	buildScope()
	local Input = c.Input
	Input.on("Aim", function(down)
		local toggle = c.Settings.data.adsToggle or Input.device() == "Touch"
		if toggle then
			if down then
				aimWanted = not aimWanted
			end
		else
			aimWanted = down
		end
		if aimWanted and c.Movement then
			c.Movement.stopSprint()
		end
	end)
	Input.on("Reload", function(down)
		-- gamepad X is shared with the interaction prompt: a visible prompt takes the press
		if down and not (Input.device() == "Gamepad" and c.Interact and c.Interact.current) then
			Weapon.startReload()
		end
	end)
	Input.on("Heal", function(down)
		if down and c.State.inRaid() then
			c.State.req("inv", { op = "use" })
		end
	end)
	Input.on("FireMode", function(down)
		if not down or not vm or Weapon.melee then
			return
		end
		local modes = vm.def.modes
		if #modes > 1 then
			Weapon.mode = Weapon.mode % #modes + 1
			Weapon.modeName = modes[Weapon.mode]
			c.Effects.sfx("selector", SoundService, 0.5)
			c.State.toast("FIRE MODE: " .. Weapon.modeName)
		end
	end)
	Input.on("Fire", function(down)
		if down and c.Movement and c.Movement.sprinting then
			c.Movement.stopSprint()
		end
	end)
	Input.on("MagCheck", function(down)
		if down then
			Weapon.magCheck()
		end
	end)
	Input.on("Light", function(down)
		if down then
			Weapon.toggleLight()
		end
	end)
	Input.on("CycleWeapon", function(down)
		if down then
			Weapon.cycleWeapon()
		end
	end)
	for action, slot in SLOT_KEYS do
		Input.on(action, function(down)
			if down then
				Weapon.switchTo(slot)
			end
		end)
	end
	c.State.changed:Connect(onSnapshot)
	c.State.on("ammo", function(d)
		if type(d) ~= "table" or type(d.a) ~= "number" then
			return
		end
		Weapon.ammo = d.a
		if d.tube then
			c.Effects.sfx("shell_insert", SoundService, 0.55, 0.95 + math.random() * 0.1)
		elseif Weapon.reloading and not tubeT0 then
			Weapon.reloading = false
			reloadT0 = nil
		end
	end)
	c.State.on("reload", function(d)
		if type(d) ~= "table" then
			return
		end
		if d.state == "start" then
			if not reloadT0 then
				reloadT0 = os.clock()
				joltDone = false
			end
			Weapon.reloading = true
			reloadDur = d.t or reloadDur
		elseif d.state == "tube" then
			Weapon.reloading = true
			tubeT0 = os.clock()
			tubePeriod = d.t or 0.55
		elseif d.state == "done" or d.state == "none" then
			Weapon.reloading = false
			tubeT0, reloadT0 = nil, nil
		end
	end)
	c.State.on("draw", function(d)
		if type(d) == "table" then
			drawT0, drawDur = os.clock(), d.t or 0.6
		end
	end)
	c.State.on("magcheck", function(d)
		if type(d) == "table" and d.state == "done" then
			Weapon.checking = false
			checkT0 = nil
		elseif type(d) == "table" and d.state == "start" then
			checkDur = d.t or checkDur
		end
	end)
	c.State.on("heal", function(d)
		Weapon.healing = d and d.state == "start"
		if Weapon.healing then
			Weapon.cancelAim()
		end
	end)
	player.CharacterAdded:Connect(function()
		resetActions()
		lastActiveG = nil
	end)
	RunService:BindToRenderStep("ZR_Weapon", Enum.RenderPriority.Camera.Value + 2, update)
end

return Weapon
