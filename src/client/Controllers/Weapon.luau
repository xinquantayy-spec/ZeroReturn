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
local Ballistics = require(Shared.Ballistics)
local Progress = require(Shared.Progress)
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Weapons = require(Shared.Weapons)
local Sounds = require(Shared.Sounds)
local Textures = require(Shared.Textures)
local WeaponModels = require(Shared.WeaponModels)
local WP = require(Shared.WeaponParts)
local GunBuild = require(Shared.GunBuild)
local Equipment = require(Shared.Equipment)
local RigSpec = require(Shared.RigSpec)

local Weapon = {
	aiming = false, reloading = false, healing = false, drawing = false, checking = false, light = false, scoped = false,
	ammo = 0, spare = 0, mode = 1, modeName = "SEMI", hasWeapon = false, melee = false, lastShot = 0,
	weaponName = nil, slot = nil,
	-- Relay 7 firing range (lobby L5): { slot, cap } while you stand in a booth (Lobby controller). Your gun comes up
	-- with free practice ammo; shots go to the Range service, which only scores the targets (no damage anywhere).
	practice = nil,
}
local ctx
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

-- tunables (live-editable from the Studio dev bridge: "tune" / "pose")
local TUNE = {
	vms = 0.55, -- viewmodel scale of the shared weapon spec
	upper = 0.56, fore = 0.54, -- arm segment lengths (viewmodel studs)
	upperW = 0.21, foreW = 0.17, -- sleeve thickness (round, the forearm swells toward the elbow)
	rShoulder = Vector3.new(0.5, -0.74, 0.08), lShoulder = Vector3.new(-0.46, -0.7, -0.3),
	rPole = Vector3.new(0.7, -1, 0.3), lPole = Vector3.new(-1, -0.7, 0.1),
	-- the character's own block arms in first person: lengths and thickness relative to the body (1 = the body's
	-- exact proportions), and where each fist sits in its hand frame (tuned in Studio for hip, ADS, pistol, knife)
	armScale = 0.62, armThick = 0.45,
	rFist = Vector3.new(0, 0, 0), lFist = Vector3.new(0, -0.05, 0),
}
Weapon.TUNE = TUNE
local GLOVE_SEAM = Color3.fromHex("181A19") -- glove colours come from the look (Equipment.fpColors)
local ROT_Y90 = CFrame.Angles(0, math.rad(90), 0)
local L_REST = CFrame.new(-0.34, -0.68, -0.36) * CFrame.Angles(math.rad(50), 0, math.rad(20)) -- knife: free hand low
local POUCH = CFrame.new(-0.14, -0.98, -0.28) -- camera space, off-screen (rig pouches)
local BELT = CFrame.new(0.06, -0.95, -0.3) -- camera space, off-screen (shells)
local SLOT_KEYS = { Primary = "primary", Secondary = "secondary", Sidearm = "holster", Knife = "melee" }
local CYCLE = { "primary", "secondary", "holster", "melee" }
local SLASH_TIME = 0.5

-- camera-space grip poses per weapon kind
local POSE = {
	long = {
		hip = CFrame.new(0.17, -0.25, -0.62) * CFrame.Angles(math.rad(1), math.rad(4), math.rad(-4)),
		sprint = CFrame.new(0.08, -0.4, -0.42) * CFrame.Angles(math.rad(-25), math.rad(45), math.rad(15)),
		reload = CFrame.new(0.15, -0.3, -0.46) * CFrame.Angles(math.rad(12), math.rad(-8), math.rad(30)),
		-- WEAPON MASTERING (02): the second reload motion, canted further toward the support hand and held higher
		reload2 = CFrame.new(0.13, -0.27, -0.48) * CFrame.Angles(math.rad(16), math.rad(-12), math.rad(46)),
		check = CFrame.new(0.12, -0.25, -0.46) * CFrame.Angles(math.rad(8), math.rad(-20), math.rad(52)),
		tube = CFrame.new(0.16, -0.27, -0.46) * CFrame.Angles(math.rad(10), math.rad(-6), math.rad(-55)),
		low = CFrame.new(0.26, -0.85, -0.3) * CFrame.Angles(math.rad(-60), math.rad(12), 0),
		eyeDist = 0.42,
	},
	pistol = {
		hip = CFrame.new(0.11, -0.23, -0.6) * CFrame.Angles(math.rad(2), math.rad(3), 0),
		sprint = CFrame.new(0.15, -0.48, -0.45) * CFrame.Angles(math.rad(-55), math.rad(5), 0),
		reload = CFrame.new(0.08, -0.26, -0.55) * CFrame.Angles(math.rad(15), math.rad(-10), math.rad(25)),
		reload2 = CFrame.new(0.07, -0.24, -0.53) * CFrame.Angles(math.rad(20), math.rad(-14), math.rad(38)),
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
local HEAT = { rifle = 0.011, smg = 0.009, pistol = 0.012, shotgun = 0.03, bolt = 0.035 } -- as Combat.luau
local heat, heatT = 0, 0
local MODE_NAMES = { AUTO = "FULL AUTO", SEMI = "SINGLE", BURST = "BURST", PUMP = "PUMP-ACTION", BOLT = "BOLT-ACTION" }
local inspectT0 = nil -- L: Tarkov's weapon inspection (the gun turned to show one side, then the other)
local INSPECT_TIME = 2.6
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
Weapon.zeros = {} -- [weapon guid] = zeroing distance (m) the server set
local zoomSel = {} -- [sight guid] = chosen magnification index (variable scopes)
local function practicing()
	return Weapon.practice ~= nil and not ctx.State.inRaid()
end
-- a gun in your hands: in a raid, or at the range in the lobby
local function armed()
	return ctx.State.inRaid() or practicing()
end
-- Tarkov's weapon mastering (Progress.MASTERING) of the weapon in hands, from the points the server sends: level 2 gives
-- the magazine reload a second motion, level 3 lets you reload while aiming down sights (the server holds the same rule)
local function mastery()
	local econ = ctx.State.data and ctx.State.data.econ
	return vm and Progress.masteryFor(econ and econ.mastering, vm.def.id) or 0
end

local function activeItem()
	local d = ctx.State.data
	local slot = d and d.active
	if practicing() then
		slot = Weapon.practice.slot
	end
	if not d or not d.slots or not slot then
		return nil, d, nil
	end
	local g = d.slots[slot]
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
	if practicing() and not def.melee then
		return Weapon.practice.cap, 99, true, def -- practice ammo: a full magazine on every reload
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
-- the local character's outfit (server-set Look / LookVariant attributes): first-person sleeves and gloves
local function myLook()
	local me = Players.LocalPlayer.Character
	return (me and me:GetAttribute("Look")) or "player", (me and me:GetAttribute("LookVariant")) or 1
end

local function vmKey(it, g)
	local look, variant = myLook()
	local me = Players.LocalPlayer.Character
	local items = ctx.State.data and ctx.State.data.items or {}
	-- the build (M14) and whether its part meshes have loaded (the gun is rebuilt from Blender parts when they do)
	local k = { g, it.mag and "M" or "-", look .. variant, tostring(me and me:GetAttribute("AppearanceRev") or 0), tostring(me),
		WP.signature(items, g), GunBuild.ready(items, g) and "mesh" or "spec" }
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
	-- a variable scope (Tarkov's Alt + right mouse): its magnifications, starting at the lowest
	local sp = o.ms and o.ms.sight and d.items[o.ms.sight]
	local zl = sp and WP.parts[sp.id] and WP.parts[sp.id].zooms
	if zl then
		-- the chosen magnification stays with the scope when the view model is rebuilt
		o.zooms, o.sightG = zl, o.ms.sight
		o.zoomI = zoomSel[o.sightG] or 1
		o.zoom = zl[o.zoomI]
	end
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
	-- arms (posed by two-bone IK every frame), then the shell used by tube reloads. Sleeves and gloves come from
	-- the same look definitions as the third-person body (Equipment.fpColors: operator, scav variants, ...); the
	-- sleeves are the block-sleeve meshes of the gear batch (round parts until it loads).
	o.vms = VMS
	local look, variant = myLook()
	local fp = Equipment.fpColors(look, variant)
	local sleeve = fp.sleeve:Lerp(Color3.new(0, 0, 0), 0.12)
	local cuffC = fp.cuff
	local glove, gloveP = fp.glove, fp.pad
	local lib = game:GetService("ReplicatedStorage"):FindFirstChild("ZR_Assets")
	-- smooth material: world-scaled Fabric texture is coarse on viewmodel-scale sleeves (the mesh carries the seams)
	local CLOTH = Enum.Material.SmoothPlastic
	local sleeveMesh = lib and lib:FindFirstChild("ZR_FP_Sleeve")
	local cuffMesh = lib and lib:FindFirstChild("ZR_FP_Cuff")
	local function round(size, color, mat, shape)
		local p = vpart(model, size, color, mat)
		p.Shape = shape or Enum.PartType.Cylinder
		return p
	end
	-- block sleeve segment (mesh stretched along X by seg()), or the round part
	local function sleevePart(size, color, mesh)
		if not mesh then
			return round(size, color, CLOTH)
		end
		local p = mesh:Clone()
		p.Size = size
		p.Color = color
		p.Material = CLOTH
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = model
		return p
	end
	local function arm()
		return {
			upper = sleevePart(Vector3.new(TUNE.upper, TUNE.upperW, TUNE.upperW), sleeve, sleeveMesh),
			elbow = round(Vector3.new(TUNE.upperW * 0.98, TUNE.upperW * 0.98, TUNE.upperW * 0.98), sleeve, CLOTH, Enum.PartType.Ball),
			fore = sleevePart(Vector3.new(TUNE.fore, TUNE.foreW, TUNE.foreW), sleeve, sleeveMesh),
			bulk = sleevePart(Vector3.new(TUNE.fore * 0.5, TUNE.foreW * 1.16, TUNE.foreW * 1.16), sleeve, sleeveMesh),
			cuff = sleevePart(Vector3.new(0.06, TUNE.foreW * 1.1, TUNE.foreW * 1.1), cuffC, cuffMesh),
			palm = vpart(model, Vector3.new(0.05, 0.14, 0.13), glove, CLOTH),
			pad = vpart(model, Vector3.new(0.022, 0.09, 0.1), gloveP),
			fingers = vpart(model, Vector3.new(0.045, 0.125, 0.085), glove, CLOTH),
			thumb = vpart(model, Vector3.new(0.034, 0.034, 0.08), glove, CLOTH),
			seam = vpart(model, Vector3.new(0.056, 0.02, 0.135), GLOVE_SEAM),
		}
	end
	-- first person shows the character's own arms: its block arm segments and hands (same meshes, outfit colours
	-- and worn arm gear: armbands, shoulder markers, arm guards), cloned and scaled for the viewmodel
	local char = player.Character
	local function bodyArm(side)
		local up = char and char:FindFirstChild(side .. "UpperArm")
		local lo = char and char:FindFirstChild(side .. "LowerArm")
		local ha = char and char:FindFirstChild(side .. "Hand")
		if not (up and lo and ha and up:IsA("BasePart") and lo:IsA("BasePart") and ha:IsA("BasePart")) then
			return nil
		end
		local s, t = TUNE.armScale, TUNE.armThick
		local function scaled(v)
			return Vector3.new(v.X * s * t, v.Y * s, v.Z * s * t)
		end
		local function clone(src)
			local p = src:Clone()
			for _, ch in p:GetChildren() do
				if not (ch:IsA("SurfaceAppearance") or ch:IsA("Decal") or ch:IsA("Texture")) then
					ch:Destroy()
				end
			end
			p.Size = scaled(src.Size)
			-- the body's Fabric texture is world-scaled: coarse at viewmodel size, so the clones are smooth
			if p.Material == Enum.Material.Fabric then
				p.Material = CLOTH
			end
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Massless = true
			p.Transparency = 0
			p.LocalTransparencyModifier = 0
			p.Parent = model
			return p
		end
		local a = { upper = clone(up), lower = clone(lo), hand = clone(ha), gear = {} }
		local hostOf = { [up] = "upper", [lo] = "lower", [ha] = "hand" }
		for _, g in char:GetChildren() do
			if g.Name == "Gear" and g:IsA("BasePart") then
				local w = g:FindFirstChildOfClass("WeldConstraint")
				local host = w and hostOf[w.Part0]
				if host then
					local rel = w.Part0.CFrame:ToObjectSpace(g.CFrame)
					table.insert(a.gear, { part = clone(g), host = host, off = CFrame.new(scaled(rel.Position)) * rel.Rotation })
				end
			end
		end
		-- joint geometry from the rig: segment lengths, where each part's centre sits between its joints
		local P, J = RigSpec.parts, {}
		for _, j in RigSpec.joints do
			J[j.name] = j.pos
		end
		local sh, el, wr = J[side .. "Shoulder"], J[side .. "Elbow"], J[side .. "Wrist"]
		a.lenU = (sh - el).Magnitude * s
		a.lenF = (el - wr).Magnitude * s
		a.tU = (sh.Y - P[side .. "UpperArm"].center.Y) / (sh.Y - el.Y)
		a.tF = (el.Y - P[side .. "LowerArm"].center.Y) / (el.Y - wr.Y)
		a.handOff = (wr.Y - P[side .. "Hand"].center.Y) * s
		return a
	end
	local rA, lA = bodyArm("Right"), bodyArm("Left")
	if rA and lA then
		o.block = true
		o.armR, o.armL = rA, lA
		for _, a in { rA, lA } do
			for _, k in { "upper", "lower", "hand" } do
				table.insert(o.all, a[k])
				table.insert(o.cfs, a[k].CFrame)
			end
			for _, g in a.gear do
				table.insert(o.all, g.part)
				table.insert(o.cfs, g.part.CFrame)
			end
		end
	else
		-- no character yet: the old block sleeves until the next rebuild
		o.armR, o.armL = arm(), arm()
		for _, a in { o.armR, o.armL } do
			for _, k in { "upper", "elbow", "fore", "bulk", "cuff", "palm", "pad", "fingers", "thumb", "seam" } do
				table.insert(o.all, a[k])
				table.insert(o.cfs, a[k].CFrame)
			end
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
		l.Enabled = false -- set by applyDevice once the viewmodel is in place
		l.Parent = b.lightPart
		o.lamp = l
	end
	o.laser = b.laserPart -- the visible laser's aperture (LaserFx draws the beam while the device runs a laser)
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

-- a frame along a limb segment from joint A (proximal) to joint B (distal): +Y toward A like the body's rest pose,
-- +X toward the camera's right (the body's parts are not mirrored), the part centre at fraction t from A to B
local function segFrame(A, B, t, right)
	local y = A - B
	y = y.Magnitude > 1e-4 and y.Unit or Vector3.yAxis
	local x = right - y * right:Dot(y)
	x = x.Magnitude > 1e-4 and x.Unit or y:Cross(Vector3.zAxis).Unit
	return CFrame.fromMatrix(A + (B - A) * t, x, y, x:Cross(y))
end

-- the wrist that puts the fist's centre on the hand frame H (fist offset in H's space), reaching from shoulder S
local function wristFor(a, H, S, fist)
	local c = (H * CFrame.new(fist)).Position
	local d = c - S
	d = d.Magnitude > 1e-4 and d.Unit or Vector3.new(0, 0, -1)
	return c - d * a.handOff
end

-- one block arm's CFrames: upper arm (shoulder S to elbow E), lower arm (E to wrist W), the fist beyond the wrist,
-- then the worn arm gear on its host segment
local function blockArmCFrames(a, S, E, W, right, out, i)
	local fU = segFrame(S, E, a.tU, right)
	local fL = segFrame(E, W, a.tF, right)
	local fH = fL.Rotation + (W + (W - E).Unit * a.handOff)
	out[i] = fU
	out[i + 1] = fL
	out[i + 2] = fH
	local frames = { upper = fU, lower = fL, hand = fH }
	i += 3
	for _, g in a.gear do
		out[i] = frames[g.host] * g.off
		i += 1
	end
	return i
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
	if vm and vm.zoom and vm.zoom > 1 and aimA > 0.5 and not (ctx.NightVision and ctx.NightVision.blocksOptics()) then
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
	local scoped = show and vm ~= nil and vm.zoom ~= nil and vm.zoom > 1 and aimA > 0.85 and not (ctx.NightVision and ctx.NightVision.blocksOptics())
	-- a variable scope at 1x reads like a red dot (the whole view, a lit reticle)
	local dotOn = show and vm ~= nil and (vm.reflex or vm.zoom == 1) and aimA > 0.8
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
	return vm ~= nil and not Weapon.melee and not (Weapon.reloading and mastery() < 3) and not Weapon.checking and not Weapon.healing
		and switching == nil and armed() and not ctx.Input.isMenu() and not (ctx.Grenade and ctx.Grenade.busy())
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
	if not (armed() and vm and Weapon.hasWeapon and not Weapon.melee) then
		return false
	end
	if (Weapon.reloading and not tubeT0) or Weapon.healing or Weapon.drawing or Weapon.checking or switching or cycleT0 then
		return false
	end
	if ctx.Grenade and ctx.Grenade.busy() then
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
	-- M11 part B: a malfunctioning gun clicks (L identifies it, Shift+T clears it)
	if Weapon.malf and not practicing() then
		if not dryLatch then
			dryLatch = true
			ctx.Effects.sound(Sounds.DRY_FIRE, SoundService, 0.6)
		end
		return
	end
	-- M14: a gun missing a required part does not fire (the server refuses the shot too)
	if o.ms.operable == false then
		if not dryLatch then
			dryLatch = true
			ctx.Effects.sound(Sounds.DRY_FIRE, SoundService, 0.6)
			ctx.State.toast("WEAPON IS MISSING PARTS", "warn")
		end
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
	if not practicing() then
		Weapon.ammo -= 1
	else
		Weapon.ammo = math.max(0, Weapon.ammo - 1)
	end
	local M = ctx.Movement
	local crouch = M and M.crouching
	local camCF = ctx.Camera.aimCFrame or cam.CFrame -- free look does not move the weapon
	local spread = (Weapon.aiming and def.aimSpread or def.hipSpread) * (Weapon.aiming and (o.ms.acc or 1) or 1)
	if not Weapon.aiming and select(2, Weapon.deviceState()) then
		spread *= 0.8 -- a visible laser steadies hip fire (Tarkov: while it is on)
	end
	-- M11 part B: a hot barrel throws shots wider (medium overheating and up; the server keeps the real heat)
	local t0 = os.clock()
	heat = heat * math.exp(-(t0 - heatT) / 30) + (HEAT[def.class] or 0.012)
	heatT = t0
	if heat > 0.6 then
		spread *= 1 + (heat - 0.6) * 1.5
	end
	if ctx.Camera.speed > 2 then
		spread += def.moveSpread * (Weapon.aiming and 0.35 or 1)
	end
	if crouch then
		spread *= 0.8
	end
	local r = math.rad(spread) * 0.5
	local dir = (camCF * CFrame.Angles((math.random() * 2 - 1) * r, (math.random() * 2 - 1) * r, 0)).LookVector
	local origin = camCF.Position
	if practicing() then
		-- (act payloads carry plain numbers only)
		ctx.State.act("range", { s = seq, ox = origin.X, oy = origin.Y, oz = origin.Z, dx = dir.X, dy = dir.Y, dz = dir.Z, slot = Weapon.practice.slot })
	else
		ctx.State.shoot(seq, origin, dir)
	end
	rayParams.FilterDescendantsInstances = { player.Character, o.model, workspace:FindFirstChild("ZR_Fx") }
	local res = workspace:Raycast(origin, dir * def.range, rayParams)
	local hit = res and res.Position or (origin + dir * def.range)
	local muzzle = (o.grip * CFrame.new(o.muzzle)).Position
	if not o.ms.suppressed and not Weapon.scoped then
		ctx.Effects.flash(muzzle, 0.12)
		if ctx.Post then
			ctx.Post.burst(0.1)
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
	-- the weapon class's skill (Tarkov's weapon skills): less recoil
	local econ = ctx.State.data and ctx.State.data.econ
	k *= 1 - Progress.bonus(econ and econ.skills, Progress.WEAPON_SKILL[def.class] or "")
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

local function nadeBusy()
	return ctx.Grenade ~= nil and ctx.Grenade.busy()
end

function Weapon.startReload()
	local o = vm
	if not o or Weapon.melee or not armed() or Weapon.reloading or Weapon.drawing or Weapon.checking or switching or Weapon.healing or nadeBusy() then
		return
	end
	if practicing() then
		-- practice ammo: the usual reload, then a full magazine (nothing is asked of the server)
		if Weapon.ammo >= Weapon.practice.cap then
			return
		end
		Weapon.reloading = true
		reloadT0 = os.clock()
		reloadDur = ((Weapon.ammo > 0) and o.def.reload or o.def.reloadEmpty) or 2.4
		joltDone = false
		local token = reloadT0
		for _, e in { { 0.14, "mag_out" }, { 0.45, "cloth_1" }, { 0.76, "mag_in" } } do
			task.delay(reloadDur * e[1], function()
				if reloadT0 == token then
					ctx.Effects.sfx(e[2], SoundService, 0.55)
				end
			end)
		end
		task.delay(reloadDur, function()
			if reloadT0 == token and Weapon.practice then
				Weapon.reloading = false
				reloadT0 = nil
				Weapon.ammo = Weapon.practice.cap
			end
		end)
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

function Weapon.magCheck(chamber)
	if not vm or Weapon.melee or not ctx.State.inRaid() or Weapon.reloading or Weapon.drawing or Weapon.checking or switching or Weapon.healing or nadeBusy() then
		return
	end
	Weapon.checking = true
	Weapon.lastCheck = chamber and "chamber" or "mag"
	inspectT0 = nil
	checkT0 = os.clock()
	ctx.State.act("magcheck", chamber and { chamber = true } or nil)
	ctx.Effects.sfx("mag_out", SoundService, 0.25, 1.15)
	local token = checkT0
	task.delay(checkDur + 1.4, function()
		if checkT0 == token then
			Weapon.checking = false
			checkT0 = nil
		end
	end)
end

-- for the Studio bridge's state: the inspection, the zero and the scope's power of the weapon in hand
function Weapon.debugState()
	return { inspecting = inspectT0 ~= nil, zero = vm and Weapon.zeros[vm.g] or nil, zoom = vm and vm.zoom or nil }
end

-- the fire mode as Tarkov names it (FULL AUTO, SINGLE...)
function Weapon.modeLabel()
	return Weapon.modeName and (MODE_NAMES[Weapon.modeName] or Weapon.modeName) or nil
end

-- L: look the weapon over (any time it is up and not busy; aiming, firing or reloading ends it)
function Weapon.inspect()
	if not vm or Weapon.reloading or Weapon.drawing or Weapon.checking or switching or Weapon.healing or aimWanted or nadeBusy() then
		return
	end
	inspectT0 = os.clock()
	-- a malfunction is identified by looking the gun over (Tarkov)
	if Weapon.malf == "?" and ctx.State.inRaid() then
		ctx.State.act("inspect")
	end
end

function Weapon.slash()
	local o = vm
	if not o or not Weapon.melee or not ctx.State.inRaid() or slashT0 or Weapon.drawing or switching or Weapon.healing or ctx.Input.isMenu() or nadeBusy() then
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
	if not ctx.State.inRaid() or not d or d.active == slot or not weaponIn(slot) or switching or Weapon.healing or nadeBusy() then
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

-- the tactical device: T turns it on and off (Weapon.light), Ctrl+T switches a light/laser combo between "both", "light"
-- and "laser" (Tarkov); the server decides what others see (Combat.setLight)
Weapon.deviceMode = "both"
local DEVICE_LABEL = { both = "LIGHT + LASER", light = "LIGHT", laser = "LASER" }
local PAD_HOLD = 0.35 -- touch LGT: released sooner is a tap, held this long the mode (Input.HOLD, the gamepad's, is the same)
function Weapon.deviceState()
	if not vm or not Weapon.light then
		return false, false
	end
	local ms, mode = vm.ms, Weapon.deviceMode
	local light = ms.light == true and (not ms.laser or mode ~= "laser")
	local laser = ms.laser == true and (not ms.light or mode ~= "light")
	return light, laser
end
-- a light or a laser on the gun in hand (the touch LGT button shows only then)
function Weapon.hasDevice()
	return vm ~= nil and vm.ms ~= nil and (vm.ms.light == true or vm.ms.laser == true)
end
-- the viewmodel's laser aperture and the viewmodel itself (LaserFx draws the beam from it)
function Weapon.vmLaser()
	return vm and vm.laser, vm and vm.model
end
local function applyDevice()
	local light = Weapon.deviceState()
	if vm and vm.lamp then
		vm.lamp.Enabled = light
	end
end
Weapon.applyDevice = applyDevice
function Weapon.toggleLight()
	if not vm or not (vm.ms.light or vm.ms.laser) or not armed() then
		return
	end
	Weapon.light = not Weapon.light
	applyDevice()
	ctx.Effects.sfx("selector", SoundService, 0.5, 1.3)
	ctx.State.act("light", { on = Weapon.light, mode = Weapon.deviceMode })
end
function Weapon.cycleDeviceMode()
	if not vm or not (vm.ms.light and vm.ms.laser) or not armed() then
		return
	end
	Weapon.deviceMode = (Weapon.deviceMode == "both" and "light") or (Weapon.deviceMode == "light" and "laser") or "both"
	applyDevice()
	ctx.Effects.sfx("selector", SoundService, 0.4, 1.5)
	if not Weapon.light then
		-- off, nothing shows the change (Tarkov is silent; the HUD's weapon line names it once on)
		ctx.State.toast("DEVICE  ·  " .. DEVICE_LABEL[Weapon.deviceMode])
	end
	if Weapon.light then
		ctx.State.act("light", { on = true, mode = Weapon.deviceMode })
	end
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
	if vm and fireDown and armed() then
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
	local show = o ~= nil and (inRaid or practicing()) and hum ~= nil and not ctx.Input.isMenu() and not ctx.Camera.orbit and not ctx.Input.isMounted()
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
	local gear = ctx.Movement and ctx.Movement.gear
	local ergo = (o and (o.def.ergo + o.ms.ergo) or 50) * (1 + (gear and gear.ergo or 0) / 100)
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
		local target = (switching and 0) or (nadeBusy() and 0) or (Weapon.healing and 0.3) or ((Mv and Mv.vaulting) and 0.2) or 1
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
	-- weapon mastering: level 2 reloads a magazine with the second motion; at level 3 aiming through a reload keeps
	-- the gun at the eye and the reload only tips it a little (below 3 aiming is off while reloading: canAim)
	local mlvl = mastery()
	local keep = mlvl >= 3 and aimA * 0.8 or 0
	if P.reload then
		base = base:Lerp((mlvl >= 2 and P.reload2) or P.reload, reloadA * (1 - keep))
	end
	if P.tube then
		base = base:Lerp(P.tube, tubeA * (1 - keep))
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
	if inspectT0 then
		local p = (now - inspectT0) / INSPECT_TIME
		if p >= 1 or aimWanted or Weapon.reloading or Weapon.checking or switching then
			inspectT0 = nil
		else
			-- turn the left side up, then the right side
			local a1 = math.sin(math.pi * math.clamp(p / 0.52, 0, 1))
			local a2 = math.sin(math.pi * math.clamp((p - 0.48) / 0.52, 0, 1))
			base = base * CFrame.new(0.03 * (a1 - a2), 0.05 * (a1 + a2), -0.04 * (a1 + a2))
				* CFrame.Angles(math.rad(10) * (a1 + a2), math.rad(26) * a1 - math.rad(20) * a2, math.rad(-46) * a1 + math.rad(36) * a2)
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
			-- the second motion (WEAPON MASTERING (02)) ends with a palm tap on the seated magazine: the hand drops
			-- and strikes up, and the jolt comes with the strike
			local m2 = mlvl >= 2
			if not joltDone and (not m2 or p >= 0.9) then
				joltDone = true
				kickRot += math.rad(1.6)
				kickZ += 0.02
			end
			local tap = m2 and math.sin(math.pi * math.clamp((p - 0.8) / 0.1, 0, 1)) or 0
			lHand = (grip * CFrame.new(0, -0.05 * tap, 0) * grab):Lerp(grip * o.lHand, phase(p, m2 and 0.9 or 0.8, 1))
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
	-- a grenade in hand (M11): the throwing hands take over, the weapon hangs low out of view
	if ctx.Grenade and ctx.Grenade.state then
		local rG, lG = ctx.Grenade.hands(now, camCF)
		rHand = rG or rHand
		lHand = lG or lHand
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
	local n = o.nFixed
	local nxt
	if o.block then
		-- the character's own block arms: fists on the grip and the handguard
		local A, B = o.armR, o.armL
		local rW, lW = wristFor(A, rHand, rS, TUNE.rFist), wristFor(B, lHand, lS, TUNE.lFist)
		local rE = solve(rS, rW, A.lenU, A.lenF, camCF:VectorToWorldSpace(TUNE.rPole))
		local lE = solve(lS, lW, B.lenU, B.lenF, camCF:VectorToWorldSpace(TUNE.lPole))
		local right = camCF.RightVector
		nxt = blockArmCFrames(A, rS, rE, rW, right, cfs, n + 1)
		nxt = blockArmCFrames(B, lS, lE, lW, right, cfs, nxt)
	else
		local rW = (rHand * CFrame.new(0, -0.04, 0.08)).Position
		local lW = (lHand * CFrame.new(-0.02, -0.035, 0.08)).Position
		local rE = solve(rS, rW, TUNE.upper, TUNE.fore, camCF:VectorToWorldSpace(TUNE.rPole))
		local lE = solve(lS, lW, TUNE.upper, TUNE.fore, camCF:VectorToWorldSpace(TUNE.lPole))
		nxt = armCFrames(o.armR, rS, rE, rW, rHand, 1, cfs, n + 1)
		nxt = armCFrames(o.armL, lS, lE, lW, lHand, -1, cfs, nxt)
	end
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

local MALF_NAMES = { misfire = "MISFIRE", eject = "FAILURE TO EJECT", feed = "FAILURE TO FEED", jam = "JAMMED BOLT" }
local function onSnapshot()
	local it, d, g = activeItem()
	local cur, better, has, def = computeAmmo()
	Weapon.spare = better
	-- the malfunction belongs to the gun: follow the active gun's record (notes update it between snapshots)
	if it and not practicing() then
		Weapon.malf = it.mf and (it.mfk and it.mf or "?") or nil
		Weapon.malfName = it.mf and it.mfk and MALF_NAMES[it.mf] or nil
	end
	if not armed() or not has then
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
		applyDevice() -- a rebuilt gun (a part fitted) keeps the device as it was
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
	elseif os.clock() - Weapon.lastShot > 0.6 and not Weapon.reloading and not practicing() then
		Weapon.ammo = cur
	end
	Weapon.melee = def.melee == true
	Weapon.slot = practicing() and Weapon.practice.slot or d.active
	local mass = (Items.defs[it.id].mass or 3) + WP.sum(d.items, g).mass
	Weapon.mass = mass
	Weapon.weaponName = string.upper(Items.defs[it.id].name)
	Weapon.modeName = def.modes[Weapon.mode] or def.modes[1]
end

-- the Lobby controller puts you at the range (practice = { slot, cap }) or takes you off it (nil)
function Weapon.setPractice(p)
	local was = Weapon.practice
	if (was == nil) == (p == nil) and (not was or (was.slot == p.slot and was.cap == p.cap)) then
		return
	end
	Weapon.practice = p
	lastActiveG = nil
	resetActions()
	onSnapshot()
	if p then
		Weapon.ammo = p.cap
	end
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
	local function nextFireMode()
		if not vm or Weapon.melee then
			return
		end
		local modes = vm.def.modes
		if #modes > 1 then
			Weapon.mode = Weapon.mode % #modes + 1
			Weapon.modeName = modes[Weapon.mode]
			c.Effects.sfx("selector", SoundService, 0.5)
			c.State.toast("FIRE MODE: " .. (MODE_NAMES[Weapon.modeName] or Weapon.modeName))
		end
	end
	-- shared gamepad buttons (D-right: a tap is the fire mode, a hold the tactical device) are told apart in Input.luau
	Input.on("FireMode", function(down)
		if down then
			nextFireMode()
		end
	end)
	Input.on("Fire", function(down)
		if down then
			inspectT0 = nil
		end
		if down and c.Movement and c.Movement.sprinting then
			c.Movement.stopSprint()
		end
	end)
	Input.on("MagCheck", function(down)
		if down then
			Weapon.magCheck()
		end
	end)
	Input.on("ChamberCheck", function(down)
		if down then
			Weapon.magCheck(true)
		end
	end)
	Input.on("InspectWeapon", function(down)
		if down then
			Weapon.inspect()
		end
	end)
	-- Alt+B: check the fire mode without changing it (Tarkov)
	Input.on("FireModeCheck", function(down)
		if down and vm and not Weapon.melee and Weapon.modeName then
			Weapon.modeCheckedAt = os.clock()
			c.Effects.sfx("selector", SoundService, 0.25, 1.1)
			c.State.toast("FIRE MODE: " .. (MODE_NAMES[Weapon.modeName] or Weapon.modeName))
		end
	end)
	-- zeroing: the server keeps the zero per weapon and says what it set
	local function zeroStep(dir)
		local list = Ballistics.ZEROS
		local cur = Weapon.zeros[vm.g] or Ballistics.DEFAULT_ZERO
		local i = table.find(list, cur) or 2
		local nxt = list[math.clamp(i + dir, 1, #list)]
		if nxt ~= cur then
			c.State.act("zero", { d = nxt })
		end
	end
	Input.on("ZeroUp", function(down)
		if down and vm then
			zeroStep(1)
		end
	end)
	Input.on("ZeroDown", function(down)
		if down and vm then
			zeroStep(-1)
		end
	end)
	c.State.on("zero", function(d)
		Weapon.zeros[d.g or ""] = d.d
		c.Effects.sfx("selector", SoundService, 0.18, 1.6)
		c.State.toast(d.max and string.format("ZEROING %d M  (SIGHTS GO TO %d M)", d.d, d.max) or string.format("ZEROING %d M", d.d))
	end)
	Input.on("SightMode", function(down)
		if down and vm and vm.zooms then
			vm.zoomI = vm.zoomI % #vm.zooms + 1
			vm.zoom = vm.zooms[vm.zoomI]
			zoomSel[vm.sightG] = vm.zoomI
			c.Effects.sfx("selector", SoundService, 0.2, 1.4)
			c.State.toast(string.format("SCOPE %dx", vm.zoom))
		end
	end)
	-- the tactical device: T (Tarkov). Gamepad: hold D-right (Input.luau tells the hold from the fire mode's tap); held
	-- while aiming it is DeviceMode. Touch: a tap on LGT turns it on and off, holding it switches the mode (a light or a
	-- laser alone turns on and off either way).
	local devHold = nil
	Input.on("Light", function(down)
		local dev = c.Input.device()
		if dev ~= "Touch" then
			if down then
				Weapon.toggleLight()
			end
			return
		end
		if not down then
			local tapped = devHold ~= nil
			devHold = nil
			if tapped and dev == "Touch" then
				Weapon.toggleLight()
			end
			return
		end
		local tok = {}
		devHold = tok
		task.delay(PAD_HOLD, function()
			if devHold ~= tok then
				return
			end
			devHold = nil
			local combo = vm and vm.ms.light and vm.ms.laser
			if combo then
				Weapon.cycleDeviceMode()
			else
				Weapon.toggleLight()
			end
		end)
	end)
	Input.on("DeviceMode", function(down)
		if not down then
			return
		end
		-- a gamepad hold while aiming: a light or a laser alone just turns on and off
		if c.Input.device() == "Gamepad" and not (vm and vm.ms.light and vm.ms.laser) then
			Weapon.toggleLight()
		else
			Weapon.cycleDeviceMode()
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
	-- M11 part B malfunctions: "?" until inspected, then the kind; clearing plays the check motion
	c.State.on("malf", function(d)
		if type(d) ~= "table" then
			return
		end
		if d.state == "on" then
			Weapon.malf = Weapon.malf or "?"
			if Weapon.malf == "?" then
				Weapon.malfName = nil
			end
		elseif d.state == "known" then
			Weapon.malf = d.kind or "?"
			Weapon.malfName = d.name
		elseif d.state == "fixing" then
			Weapon.checking = true
			checkT0, checkDur = os.clock(), d.t or 1.2
		elseif d.state == "off" then
			Weapon.malf, Weapon.malfName = nil, nil
			Weapon.checking = false
			checkT0 = nil
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
	-- the first-person arms are the character's own: rebuild them for a new character and whenever what it wears
	-- changes (outfit, arm gear)
	local function watchChar(char)
		char:GetAttributeChangedSignal("AppearanceRev"):Connect(function()
			if vm and player.Character == char then
				destroyVm()
				onSnapshot()
			end
		end)
		task.spawn(function()
			char:WaitForChild("RightHand", 10)
			char:WaitForChild("LeftHand", 10)
			if player.Character == char and vm then
				destroyVm()
				onSnapshot()
			end
		end)
	end
	if player.Character then
		watchChar(player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		resetActions()
		lastActiveG = nil
		watchChar(char)
	end)
	RunService:BindToRenderStep("ZR_Weapon", Enum.RenderPriority.Camera.Value + 2, update)
end

return Weapon
