--!nonstrict
-- Grenades on the client (M11, Tarkov rules). G held: the weapon drops, the right hand brings up the first grenade
-- from the rig or pockets and the left hand pulls the pin; release G to throw (hold aim while releasing for a
-- short underhand toss). Gamepad: hold D-down (a tap still shows the extracts). Touch: NADE.
-- The server owns the grenade: it sends the whole bouncing path at release and the blast when the fuse runs out.
-- This controller draws every grenade in flight (spin, bounce sounds), the explosion (flash, fireball, smoke,
-- debris, scorch), stun flashes, smoke clouds, and the local effects: blast shake and concussion, white-out,
-- deafness and ringing ears, the grey veil inside smoke. First-person hands come from Weapon.update via
-- Grenade.hands; third person is the Animator ("Nade" attribute, pin/toss gestures).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local G = require(Shared.Grenades)

local Grenade = { state = nil } -- nil | "pull" | "ready" | "throw"
local ctx
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local CF, ANG, R = CFrame.new, CFrame.Angles, math.rad
local THROW_T = 0.62 -- throw animation; the weapon comes back up after it
local RELEASE = 0.17 -- the grenade leaves the hand this far into the throw

local st0, wantThrow, under, itemId, padT, nextAllowed = 0, false, false, nil, nil, 0
local handsFrame = -1
local frameN = 0
local vmNade = nil -- first-person grenade { model, parts, offs, item }
local flying = {} -- [id] = { model, path, t0, bi, spin, item, k }
local clouds = {}
local scorches = {}
local fxFolder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- ── grenade models (first person at hand scale, world at full scale) ─────────
local LOOK = {
	frag = { body = "ball", color = Color3.fromHex("556048"), top = Color3.fromHex("3E433A") },
	stun = { body = "can", color = Color3.fromHex("4D5257"), top = Color3.fromHex("C8A63A") },
	smoke = { body = "can", color = Color3.fromHex("6C7469"), top = Color3.fromHex("D9DCD5") },
}

local function part(model, size, color, shape, mat)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
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

-- build a grenade of item `id` at scale s: returns { model, parts, offs } (offsets from the grenade centre;
-- the long axis is local Y, the fuse on top)
local function build(id, s, parent)
	local d = Items.defs[id]
	local kind = d and d.nade and d.nade.type or "frag"
	local L = LOOK[kind]
	local col = (d and d.color) or L.color
	local model = Instance.new("Model")
	model.Name = "ZR_Nade"
	local list, offs = {}, {}
	local function add(p, off)
		table.insert(list, p)
		table.insert(offs, off)
	end
	local up = ANG(0, 0, R(90)) -- cylinders: axis X -> local Y
	if L.body == "ball" then
		add(part(model, Vector3.new(0.3, 0.34, 0.3) * s, col, Enum.PartType.Ball), CF(0, 0, 0))
		if id == "GREN_F7" then
			-- cast-iron segments: a few dark rings
			for k = -1, 1 do
				add(part(model, Vector3.new(0.012, 0.31, 0.31) * s, L.top, Enum.PartType.Cylinder), CF(0, k * 0.08 * s, 0) * up)
			end
		end
		add(part(model, Vector3.new(0.09, 0.075, 0.075) * s, L.top, Enum.PartType.Cylinder), CF(0, 0.2 * s, 0) * up)
	else
		add(part(model, Vector3.new(0.36, 0.2, 0.2) * s, col, Enum.PartType.Cylinder), up)
		add(part(model, Vector3.new(0.05, 0.205, 0.205) * s, L.top, Enum.PartType.Cylinder), CF(0, 0.19 * s, 0) * up)
		add(part(model, Vector3.new(0.06, 0.08, 0.08) * s, Color3.fromHex("3A3D3A"), Enum.PartType.Cylinder), CF(0, 0.24 * s, 0) * up)
	end
	-- lever along the side and the pull ring
	add(part(model, Vector3.new(0.035, 0.24, 0.05) * s, Color3.fromHex("6E7064"), nil, Enum.Material.Metal), CF(0.15 * s, 0.06 * s, 0) * ANG(0, 0, R(-8)))
	add(part(model, Vector3.new(0.012, 0.075, 0.075) * s, Color3.fromHex("9A9C92"), Enum.PartType.Cylinder, Enum.Material.Metal), CF(-0.05 * s, 0.23 * s, 0.02 * s))
	model.Parent = parent
	return { model = model, parts = list, offs = offs, item = id, ring = list[#list], lever = list[#list - 1] }
end

local function place(g, cf)
	local cfs = table.create(#g.parts)
	for i, off in g.offs do
		cfs[i] = cf * off
	end
	workspace:BulkMoveTo(g.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

-- ── input and state ──────────────────────────────────────────────────────────
local function alive()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0 and hum or nil
end

function Grenade.busy()
	return Grenade.state ~= nil
end

function Grenade.itemName()
	local d = itemId and Items.defs[itemId]
	return d and string.upper(d.short) or "GRENADE"
end

-- the weapon is lowered while a grenade is in hand
function Grenade.lower()
	return Grenade.state ~= nil
end

local function firstGrenade()
	local d = ctx.State.data
	if not d or not d.items or not d.grids then
		return nil
	end
	local g = G.pick(d, Items.defs)
	return g and d.items[g] and d.items[g].id or nil
end

local function reset()
	Grenade.state = nil
	wantThrow = false
	padT = nil
	if vmNade then
		vmNade.model:Destroy()
		vmNade = nil
	end
end

local function throw()
	Grenade.state = "throw"
	st0 = os.clock()
	local lv = (ctx.Camera.aimCFrame or cam.CFrame).LookVector
	ctx.State.act("nade", { op = "throw", x = lv.X, y = lv.Y, z = lv.Z, u = under })
	ctx.Effects.sfx("nade_throw", SoundService, 0.45)
	task.delay(RELEASE, function()
		ctx.Effects.sfx("nade_spoon", SoundService, 0.3)
	end)
	nextAllowed = os.clock() + THROW_T + 0.35
end

function Grenade.begin()
	if Grenade.state or not ctx.State.inRaid() or ctx.Input.isMenu() or not alive() or os.clock() < nextAllowed then
		return false
	end
	local W, M = ctx.Weapon, ctx.Movement
	if W.healing or W.reloading or W.checking or W.drawing or (M and M.busy and M.busy()) then
		return false
	end
	local id = firstGrenade()
	if not id then
		ctx.State.toast("NO GRENADES IN RIG OR POCKETS", "warn")
		return false
	end
	itemId = id
	Grenade.state = "pull"
	st0 = os.clock()
	wantThrow, under = false, false
	W.cancelAim()
	if M and M.stopSprint then
		M.stopSprint()
	end
	ctx.State.act("nade", { op = "pull" })
	task.delay(0.36, function()
		if Grenade.state == "pull" or Grenade.state == "ready" then
			ctx.Effects.sfx("nade_pin", SoundService, 0.55)
		end
	end)
	return true
end

function Grenade.release()
	if ctx.Input.isMenu() then
		return -- a menu opened while holding it (inputs are released): keep it in hand, G again throws
	end
	if Grenade.state == "pull" then
		wantThrow = true
		under = ctx.Input.down("Aim")
	elseif Grenade.state == "ready" then
		under = ctx.Input.down("Aim")
		throw()
	end
end

-- Studio test bridge: a full press/hold/release
function Grenade.testThrow(holdFor, underhand)
	if not Grenade.begin() then
		return "refused"
	end
	task.wait(holdFor or 0.7)
	under = underhand == true
	if Grenade.state == "ready" then
		throw()
	else
		wantThrow = true
	end
	return "thrown"
end

-- ── first-person hands ───────────────────────────────────────────────────────
-- camera-space hand frames (the hand holds an object along its local Y, palm on +X: Weapon.armCFrames).
-- Live-tunable from the Studio bridge ("nadeTune").
local P = {
	R_LOW = CF(0.32, -0.95, -0.25) * ANG(R(-40), 0, 0),
	R_HOLD = CF(0.2, -0.34, -0.66) * ANG(R(12), R(-18), R(-6)),
	R_COCK = CF(0.24, -0.3, -0.62) * ANG(R(14), R(-25), R(-12)),
	R_BACK = CF(0.46, 0.06, 0.02) * ANG(R(65), 0, R(-18)),
	R_REL = CF(0.16, 0.0, -0.86) * ANG(R(-25), R(6), 0),
	R_FOLLOW = CF(-0.04, -0.62, -0.55) * ANG(R(-75), 0, R(10)),
	RU_BACK = CF(0.38, -0.88, 0.04) * ANG(R(-60), 0, 0),
	RU_REL = CF(0.2, -0.42, -0.82) * ANG(R(-10), 0, 0),
	RU_FOLLOW = CF(0.14, -0.2, -0.76) * ANG(R(18), 0, 0),
	L_LOW = CF(-0.36, -0.95, -0.25) * ANG(R(-40), 0, 0),
	L_PULLED = CF(-0.24, -0.26, -0.62) * ANG(0, 0, R(60)),
	L_BAL = CF(-0.3, -0.36, -0.7) * ANG(R(-20), 0, R(40)),
	NADE_IN_HAND = CF(-0.004, 0.095, 0), -- grenade centre from the hand frame: the top half shows above the fist
	PIN = CF(-0.02, 0.1, -0.015) * ANG(0, 0, R(90)), -- left hand on the ring, from the right hand
	scale = 0.36, -- first-person grenade size (world grenade = 1)
}
Grenade.POSE = P

local function ease(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function seg(p, a, b)
	return ease((p - a) / (b - a))
end

-- (rHand, lHand) world CFrames while a grenade is in hand, else nil. Also places the hand grenade.
function Grenade.hands(now, camCF)
	if not Grenade.state then
		return nil, nil
	end
	handsFrame = frameN
	local t = now - st0
	local r, l
	local show = true
	local idle = CF(math.sin(now * 1.7) * 0.004, math.sin(now * 2.3) * 0.004, 0)
	if Grenade.state == "pull" or Grenade.state == "ready" then
		local p = math.min(t, G.PULL_TIME)
		local rc = P.R_LOW:Lerp(P.R_HOLD, seg(p, 0, 0.22))
		rc = rc:Lerp(P.R_COCK, seg(p, 0.42, 0.55))
		r = camCF * rc * idle
		local pin = r * P.PIN
		local lc = camCF * P.L_LOW
		if p < 0.18 then
			l = lc
		elseif p < 0.32 then
			l = lc:Lerp(pin, seg(p, 0.18, 0.32))
		elseif p < 0.42 then
			l = pin:Lerp(camCF * P.L_PULLED, seg(p, 0.32, 0.42))
			if vmNade and vmNade.ring then
				vmNade.ringOff = true
			end
		else
			l = (camCF * P.L_PULLED):Lerp(lc, seg(p, 0.42, 0.55))
		end
	else -- throw
		local p = math.min(t, THROW_T)
		local back, rel, follow = P.R_BACK, P.R_REL, P.R_FOLLOW
		if under then
			back, rel, follow = P.RU_BACK, P.RU_REL, P.RU_FOLLOW
		end
		local rc
		if p < 0.1 then
			rc = P.R_COCK:Lerp(back, seg(p, 0, 0.1))
		elseif p < 0.2 then
			rc = back:Lerp(rel, seg(p, 0.1, 0.2))
		elseif p < 0.38 then
			rc = rel:Lerp(follow, seg(p, 0.2, 0.38))
		else
			rc = follow:Lerp(P.R_LOW, seg(p, 0.38, THROW_T))
		end
		r = camCF * rc
		l = (camCF * P.L_LOW):Lerp(camCF * P.L_BAL, seg(p, 0.02, 0.16) - seg(p, 0.3, 0.5))
		show = p < RELEASE
	end
	if vmNade then
		for _, pt in vmNade.parts do
			local hide = (not show) or (pt == vmNade.ring and vmNade.ringOff)
			if (pt.Transparency >= 1) ~= hide then
				pt.Transparency = hide and 1 or 0
			end
		end
		if show then
			place(vmNade, r * P.NADE_IN_HAND)
		end
	end
	return r, l
end

-- ── grenades in the world ────────────────────────────────────────────────────
local function onThrown(d)
	if type(d) ~= "table" or type(d.t) ~= "table" or type(d.p) ~= "table" or #d.p == 0 then
		return
	end
	local g = build(d.item, 1, fxFolder)
	local axis = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
	axis = axis.Magnitude > 0.05 and axis.Unit or Vector3.xAxis
	flying[d.id] = { g = g, path = { t = d.t, p = d.p }, t0 = d.t0, bi = 1, b = d.b or {}, axis = axis, k = d.k, item = d.item, fuse = d.f or 3.5 }
	place(g, CF(d.p[1]))
end

local function emitter(parentPart, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 0
	for k, v in props do
		e[k] = v
	end
	e.Parent = parentPart
	return e
end

local function anchorPart(pos, size)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CF(pos)
	p.Parent = fxFolder
	return p
end

local function flashLight(pos, range, brightness, color, life)
	local p = anchorPart(pos)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = color
	l.Shadows = false
	l.Parent = p
	local t0 = os.clock()
	local cn
	cn = RunService.Heartbeat:Connect(function()
		local a = (os.clock() - t0) / life
		if a >= 1 then
			cn:Disconnect()
			p:Destroy()
		else
			l.Brightness = brightness * (1 - a) * (1 - a)
		end
	end)
end

local function fireball(pos, size, color, life)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.one * 0.5
	p.CFrame = CF(pos)
	p.Parent = fxFolder
	local t0 = os.clock()
	local cn
	cn = RunService.Heartbeat:Connect(function()
		local a = (os.clock() - t0) / life
		if a >= 1 then
			cn:Disconnect()
			p:Destroy()
		else
			p.Size = Vector3.one * (0.5 + size * math.sqrt(a))
			p.Transparency = 0.1 + 0.9 * a
		end
	end)
end

local function quality()
	return ctx.Settings.data.quality or 2
end

local function groundBelow(pos)
	rayParams.FilterDescendantsInstances = { fxFolder, player.Character, workspace:FindFirstChild("ZR_AI"), workspace:FindFirstChild("ZR_Corpses") }
	local r = workspace:Raycast(pos + Vector3.new(0, 0.5, 0), Vector3.new(0, -3, 0), rayParams)
	return r
end

local function scorch(pos)
	local r = groundBelow(pos)
	if not r or r.Normal.Y < 0.6 then
		return
	end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.04, 3.2, 3.2)
	p.CFrame = CF(r.Position + r.Normal * 0.03) * CFrame.fromRotationBetweenVectors(Vector3.xAxis, r.Normal)
	p.Color = Color3.fromHex("1A1917")
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = 0.35
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = fxFolder
	table.insert(scorches, { p = p, t0 = os.clock() })
	if #scorches > 12 then
		table.remove(scorches, 1).p:Destroy()
	end
end

-- line of sight from a blast to the camera (world and bodies block; effects do not)
local function clearTo(pos, to)
	rayParams.FilterDescendantsInstances = { fxFolder, player.Character, workspace.CurrentCamera }
	local d = to - pos
	return workspace:Raycast(pos, d, rayParams) == nil
end

local function fragFx(pos)
	flashLight(pos, 46, 9, Color3.fromRGB(255, 196, 140), 0.22)
	fireball(pos, 6.5, Color3.fromRGB(255, 186, 104), 0.14)
	local p = anchorPart(pos)
	local q = quality()
	emitter(p, {
		Color = ColorSequence.new(Color3.fromRGB(62, 58, 54), Color3.fromRGB(110, 106, 100)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 13) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(2.2, 4), Speed = NumberRange.new(6, 15), SpreadAngle = Vector2.new(180, 180), Drag = 3.5,
		Acceleration = Vector3.new(0, 2.5, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30), LightInfluence = 1,
	}):Emit(q >= 3 and 22 or (q >= 2 and 16 or 9))
	emitter(p, {
		Color = ColorSequence.new(Color3.fromRGB(122, 112, 96)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 7) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.9, 1.8), Speed = NumberRange.new(14, 24), SpreadAngle = Vector2.new(180, 12), Drag = 5,
		EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360), LightInfluence = 1,
	}):Emit(q >= 2 and 14 or 7)
	local sparks = emitter(p, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 120)), LightEmission = 1,
		Size = NumberSequence.new(0.18), Lifetime = NumberRange.new(0.25, 0.7), Speed = NumberRange.new(28, 50),
		SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -60, 0),
	})
	sparks:Emit(q >= 2 and 30 or 14)
	task.delay(5, function()
		p:Destroy()
	end)
	scorch(pos)
end

local function stunFx(pos)
	flashLight(pos, 70, 22, Color3.fromRGB(255, 252, 240), 0.3)
	fireball(pos, 2.5, Color3.fromRGB(255, 255, 245), 0.09)
	local p = anchorPart(pos)
	emitter(p, {
		Color = ColorSequence.new(Color3.fromRGB(200, 200, 196)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.2, 2.2), Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(180, 180), Drag = 3, LightInfluence = 1,
	}):Emit(8)
	task.delay(3, function()
		p:Destroy()
	end)
end

local function startCloud(id, pos, spec, canister)
	local center = pos + Vector3.new(0, 4, 0)
	local p = anchorPart(center, Vector3.one * 4)
	p.Shape = Enum.PartType.Ball
	local q = quality()
	local main = emitter(p, {
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Color = ColorSequence.new(Color3.fromRGB(206, 208, 204), Color3.fromRGB(178, 182, 178)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(0.3, 11), NumberSequenceKeypoint.new(1, 15) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.22), NumberSequenceKeypoint.new(0.75, 0.32), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(0.4, 1.6), SpreadAngle = Vector2.new(180, 180), Drag = 0.8,
		Acceleration = Vector3.new(0, 0.35, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-12, 12), LightInfluence = 1,
	})
	local rate = (q >= 3 and 24) or (q >= 2 and 17) or 10
	-- the canister billows hard for the first seconds
	local jetPart = anchorPart(pos + Vector3.new(0, 0.3, 0))
	local jet = emitter(jetPart, {
		Color = ColorSequence.new(Color3.fromRGB(214, 216, 212)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(5, 9), SpreadAngle = Vector2.new(35, 35), Drag = 1.6,
		EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360), LightInfluence = 1,
	})
	jet.Rate = q >= 2 and 12 or 6
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = workspace.Terrain
	local hiss, gain = ctx.Effects.loop("smoke_hiss_loop", att)
	if hiss then
		hiss.RollOffMode = Enum.RollOffMode.InverseTapered
		hiss.RollOffMinDistance = 4
		hiss.RollOffMaxDistance = 70
	end
	table.insert(clouds, { id = id, center = center, spec = spec, t0 = os.clock(), part = p, main = main, rate = rate, jetPart = jetPart, jet = jet, att = att, hiss = hiss, gain = gain or 0.6, canister = canister })
end

local function endCloud(c)
	for _, x in { c.part, c.jetPart, c.att } do
		if x then
			x:Destroy()
		end
	end
	if c.canister then
		c.canister.model:Destroy()
	end
end

-- the blast, as this player experiences it
local function localEffects(k, pos, spec)
	local camPos = cam.CFrame.Position
	local to = pos - camPos
	local d = to.Magnitude
	local los = clearTo(pos, camPos)
	if k == "frag" then
		local shake = math.clamp(1 - d / 50, 0, 1)
		if shake > 0 then
			ctx.Camera.shake(shake * (los and 1 or 0.6))
		end
		ctx.Post.burst(math.clamp(1 - d / 45, 0, 0.8) * (los and 1 or 0.3))
		local c = math.clamp(1 - d / 18, 0, 1) * (los and 1 or 0.55)
		if c > 0.03 then
			ctx.Post.concuss(c, 1.5 + 4.5 * c)
			ctx.Effects.deafen(c * 0.9, 1.5 + 5.5 * c)
		end
	elseif k == "stun" then
		local facing = (d > 0.1) and cam.CFrame.LookVector:Dot(to.Unit) or 1
		local b = G.blind(spec, d, facing, los)
		local f = G.deaf(spec, d, los)
		if b > 0.02 then
			ctx.Post.whiteout(b, 1.5 + 5.5 * b)
		end
		if f > 0.02 then
			ctx.Effects.deafen(f, 2 + 6 * f)
			ctx.Camera.shake(0.3 * f)
		end
	end
end

local function onBlast(d)
	if type(d) ~= "table" or typeof(d.p) ~= "Vector3" then
		return
	end
	local f = flying[d.id]
	flying[d.id] = nil
	local def = Items.defs[d.item or ""]
	local spec = def and def.nade
	if d.k == "smoke" then
		if spec then
			startCloud(d.id, d.p - Vector3.new(0, 0.35, 0), spec, f and f.g or nil)
		elseif f then
			f.g.model:Destroy()
		end
	elseif f then
		f.g.model:Destroy()
	end
	ctx.Effects.explosion(d.p, d.k)
	if d.k == "frag" then
		fragFx(d.p)
	elseif d.k == "stun" then
		stunFx(d.p)
	end
	if spec and ctx.State.inRaid() and alive() then
		localEffects(d.k, d.p, spec)
	end
end

local function clearAll()
	for _, f in flying do
		f.g.model:Destroy()
	end
	table.clear(flying)
	for _, c in clouds do
		endCloud(c)
	end
	table.clear(clouds)
	for _, s in scorches do
		s.p:Destroy()
	end
	table.clear(scorches)
end

-- ── frame ────────────────────────────────────────────────────────────────────
local function step(dt)
	frameN += 1
	local now = os.clock()
	-- local state
	if Grenade.state then
		if not ctx.State.inRaid() or not alive() then
			reset()
		elseif Grenade.state == "pull" and now - st0 >= G.PULL_TIME then
			Grenade.state = "ready"
			if wantThrow then
				throw()
			end
		elseif Grenade.state == "throw" and now - st0 >= THROW_T then
			reset()
		end
	end
	if Grenade.state and not vmNade and itemId then
		vmNade = build(itemId, P.scale, cam)
	end
	if vmNade and handsFrame ~= frameN - 1 and handsFrame ~= frameN and Grenade.state then
		-- no weapon in hands (Weapon.update did not run): still show the grenade
		Grenade.hands(now, ctx.Camera.aimCFrame or cam.CFrame)
	end
	-- gamepad: a held D-down readies a grenade
	if padT and now - padT >= 0.3 then
		padT = nil
		if ctx.Input.down("Grenade") then
			Grenade.begin()
		end
	end
	-- grenades in flight
	local sn = workspace:GetServerTimeNow()
	for id, f in flying do
		local t = sn - f.t0
		local pos = G.at(f.path, t)
		local ts = f.path.t
		local moving = t < ts[#ts]
		local rot
		if moving then
			local a = t * 13
			rot = CFrame.fromAxisAngle(f.axis, a) * ANG(0, t * 4, 0)
			f.lastRot = rot
		else
			-- at rest it lies on its side
			f.restRot = f.restRot or (CFrame.fromAxisAngle(f.axis, math.pi / 2) * ANG(0, math.random() * 6, 0))
			rot = f.restRot
		end
		place(f.g, CF(pos) * rot)
		while f.b[f.bi] and t >= f.b[f.bi] do
			ctx.Effects.sfx("nade_bounce_" .. math.random(1, 3), pos, 0.75, 0.95 + math.random() * 0.1, 60)
			f.bi += 1
		end
		if t > f.fuse + 3 then
			-- the blast never arrived (raid ended): drop it
			f.g.model:Destroy()
			flying[id] = nil
		end
	end
	-- smoke clouds and the veil when the camera is inside one
	local veil = 0
	local camPos = cam.CFrame.Position
	for i = #clouds, 1, -1 do
		local c = clouds[i]
		local age = now - c.t0
		local r, dens = G.cloud(c.spec, age)
		if age > c.spec.smokeT + 12 then
			endCloud(c)
			table.remove(clouds, i)
		else
			if r > 0 then
				c.part.Size = Vector3.one * (2 * r)
			end
			c.main.Rate = (age < c.spec.smokeT) and c.rate or 0
			if c.jet then
				c.jet.Rate = (age < 9) and c.jet.Rate or 0
			end
			if c.hiss then
				c.hiss.Volume = c.gain * math.clamp(1 - (age - 12) / 10, 0, 1)
			end
			local dist = (camPos - c.center).Magnitude
			local core = r * 0.82
			if dist < core then
				veil = math.max(veil, math.clamp((core - dist) / 3, 0, 1) * dens)
			end
		end
	end
	ctx.Post.smoke = veil
	-- scorch marks fade out
	for i = #scorches, 1, -1 do
		local s = scorches[i]
		local age = now - s.t0
		if age > 45 then
			s.p:Destroy()
			table.remove(scorches, i)
		elseif age > 35 then
			s.p.Transparency = 0.35 + 0.65 * (age - 35) / 10
		end
	end
end

function Grenade.init(c)
	ctx = c
	fxFolder = workspace:FindFirstChild("ZR_Fx")
	if not fxFolder then
		fxFolder = Instance.new("Folder")
		fxFolder.Name = "ZR_Fx"
		fxFolder.Parent = workspace
	end
	c.Input.on("Grenade", function(down)
		if down then
			if c.Input.device() == "Gamepad" then
				padT = os.clock() -- a tap is the extract list; holding readies the grenade (step)
			else
				Grenade.begin()
			end
		else
			padT = nil
			Grenade.release()
		end
	end)
	c.State.on("nade", onThrown)
	c.State.on("nadeX", onBlast)
	c.State.on("nadeClear", clearAll)
	c.State.on("nadeFail", function()
		if Grenade.state == "pull" or Grenade.state == "ready" then
			reset()
			c.State.toast("NO GRENADES IN RIG OR POCKETS", "warn")
		end
	end)
	player.CharacterAdded:Connect(reset)
	RunService:BindToRenderStep("ZR_Grenade", Enum.RenderPriority.Camera.Value + 3, step)
end

return Grenade
