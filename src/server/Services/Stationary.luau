--!nonstrict
-- Stationary (mounted) weapons, server: Tarkov's fixed NSV Utyos and AGS-30 as our HMG-12 'Bastion' and AGL-30
-- (docs/design/STATIONARY_WEAPONS.md). A gun is a model on a tripod with one operator at a time: a raider mounts it from the
-- Interact prompt and is held at the operator spot, or a guard posted at the spot mans it from the AI (Stationary.crew).
-- The server owns everything that counts: who is on the gun, its arcs, rate of fire, belt, the rounds in flight and what they
-- hit. The operator's client only says where it is aiming and whether the trigger is down (act "staim") or that it leaves
-- (act "stleave"). Rounds are real bullets through the same hit path as every other weapon (Ballistics, Combat.hitModel,
-- Hazards); the AGL-30's rounds burst like a frag grenade (Grenades.blastAt, item AGL30_ROUND). Maps place guns while they
-- build (World.kit().stationary), before init: place() needs no ctx.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local S = require(Shared.Stationary)
local Ballistics = require(Shared.Ballistics)
local Weapons = require(Shared.Weapons)
local RigMath = require(Shared.RigMath)
local Util = require(Shared.Util)

local Stationary = {
	guns = {}, stats = { rounds = 0, mounts = 0, shells = 0 },
	KEEP = 0.7, -- seconds without an aim update before the trigger counts as released
	LOST = 4, -- seconds a crew keeps firing at a target it can no longer see
	REACH = 12, -- studs from the operator spot a prompt press is still accepted
	RESTART = 0.6, -- seconds before a player who left can mount again (Leave and Interact are both F)
	TAG = "ZR_Stationary",
}
local ctx
local mounted = {} -- [player] = gun
local blocked = setmetatable({}, { __mode = "k" }) -- [player] = os.clock() before which they cannot mount
local nextId = 0
local started = false
local M = Enum.Material
local STAND = RigMath.STAND_HIP + RigMath.hrpHalf -- root height above the floor, standing

-- tell an operator's client something (a player who left, or a stand-in operator of the logic tests, has nobody to tell)
local function tell(player, kind, data)
	if typeof(player) == "Instance" and player.Parent then
		ctx.Remotes.note(player, kind, data)
	end
end

-- the raid session of an operator (the logic tests swap this for a stand-in operator)
function Stationary.sessionOf(player)
	return ctx.Raid.session(player)
end

-- ── models: built from parts, no meshes (about 30 parts a gun) ─────────────────────────────────────────────
local PAINT = {
	HMG12 = { body = "3A3F3C", dark = "2B2E2C", barrel = "232624", grip = "1F2120", box = "4C5738", lid = "58653F", brass = "B08A3E", leg = "464A40" },
	AGL30 = { body = "474D42", dark = "2E312D", barrel = "262926", grip = "202221", box = "55603F", lid = "5F6B45", brass = "B08A3E", leg = "3E4238" },
}

local function part(parent, name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.fromHex(color)
	p.Material = mat or M.Metal
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false -- bullets, sight lines and prompts pass through: a gun never blocks its own crew
	p.CanTouch = false
	p:SetAttribute("Wear", "") -- keep the plain material (World.applyWear)
	p.Parent = parent
	return p
end

-- a cylinder along an axis (length first, then the diameter)
local AXIS = { x = CFrame.new(), y = CFrame.Angles(0, 0, math.rad(90)), z = CFrame.Angles(0, math.rad(90), 0) }
local function cyl(parent, name, axis, length, dia, cf, color, mat)
	return part(parent, name, Vector3.new(length, dia, dia), cf * AXIS[axis], color, mat, Enum.PartType.Cylinder)
end

-- the tripod, the cradle and a spare ammunition can: fixed to the ground frame
local function tripod(model, g, c)
	local spec, f = g.spec, g.frame
	local H = spec.pivotH
	local top = Vector3.new(0, H - 0.8, 0)
	local post = H - 1.2
	cyl(model, "Post", "y", post, 0.5, f * CFrame.new(0, 0.4 + post / 2, 0), c.leg)
	part(model, "Cradle", Vector3.new(1.7, 0.3, 1.0), f * CFrame.new(0, H - 0.5, 0), c.dark)
	part(model, "Screw", Vector3.new(0.5, 0.6, 0.5), f * CFrame.new(0, H - 1.2, 0.35), c.dark)
	for i, foot in { Vector3.new(-2.0, 0.1, -1.8), Vector3.new(2.0, 0.1, -1.8), Vector3.new(0, 0.1, 2.0) } do
		local len = (foot - top).Magnitude
		part(model, "Leg" .. i, Vector3.new(0.3, 0.3, len), f * CFrame.lookAt(top, foot) * CFrame.new(0, 0, -len / 2), c.leg)
		part(model, "Foot" .. i, Vector3.new(0.8, 0.16, 0.8), f * CFrame.new(foot), c.dark)
	end
	part(model, "Can", Vector3.new(1.1, 0.7, 0.6), f * CFrame.new(1.7, 0.45, spec.op.Z - 1.2), c.box)
	part(model, "CanLid", Vector3.new(1.15, 0.1, 0.65), f * CFrame.new(1.7, 0.85, spec.op.Z - 1.2), c.lid)
end

-- spade grips and their cross bar, the trunnions and sights shared by both heads (pivot frame P, -z is forward)
local function fittings(head, P, c, gripZ, sightZ)
	local function at(x, y, z)
		return P * CFrame.new(x, y, z)
	end
	part(head, "GripL", Vector3.new(0.2, 0.75, 0.2), at(-0.45, 0.3, gripZ) * CFrame.Angles(math.rad(-15), 0, 0), c.grip, M.SmoothPlastic)
	part(head, "GripR", Vector3.new(0.2, 0.75, 0.2), at(0.45, 0.3, gripZ) * CFrame.Angles(math.rad(-15), 0, 0), c.grip, M.SmoothPlastic)
	part(head, "Cross", Vector3.new(1.3, 0.16, 0.16), at(0, 0.62, gripZ + 0.1), c.grip, M.SmoothPlastic)
	part(head, "FrontSight", Vector3.new(0.1, 0.4, 0.1), at(0, 0.8, sightZ), c.dark)
	cyl(head, "TrunnionL", "x", 0.35, 0.5, at(-0.68, -0.1, 0), c.dark)
	cyl(head, "TrunnionR", "x", 0.35, 0.5, at(0.68, -0.1, 0), c.dark)
end

-- the head turns with the aim: receiver, barrel with its brake (the tip is spec.muzzleLen ahead of the pivot), ammunition box
-- and belt on the left, grips behind
local function headHMG(head, P, c)
	local function at(x, y, z)
		return P * CFrame.new(x, y, z)
	end
	part(head, "Receiver", Vector3.new(1.0, 1.2, 3.0), at(0, 0, 0.4), c.body)
	part(head, "Back", Vector3.new(0.8, 0.9, 0.5), at(0, 0.05, 2.15), c.dark)
	cyl(head, "Shroud", "z", 2.0, 0.7, at(0, 0.1, -2.1), c.dark)
	cyl(head, "Barrel", "z", 2.4, 0.3, at(0, 0.1, -4.3), c.barrel)
	cyl(head, "Brake", "z", 0.5, 0.55, at(0, 0.1, -5.55), c.barrel)
	part(head, "Handle", Vector3.new(0.18, 0.14, 1.3), at(0, 0.66, -0.8), c.dark)
	part(head, "AmmoBox", Vector3.new(0.9, 1.0, 1.5), at(-1.3, -0.35, 0.3), c.box)
	part(head, "BoxLid", Vector3.new(0.9, 0.1, 1.5), at(-1.3, 0.2, 0.3), c.lid)
	part(head, "Feed", Vector3.new(0.8, 0.12, 0.7), at(-0.85, 0.15, -0.2), c.dark)
	part(head, "Belt", Vector3.new(0.28, 0.5, 0.9), at(-0.95, -0.1, -0.2), c.brass)
	part(head, "RearSight", Vector3.new(0.5, 0.3, 0.12), at(0, 0.75, 0.9), c.dark)
	fittings(head, P, c, 2.45, -2.9)
end

-- the grenade launcher: a boxy receiver, a short heavy barrel with a brake, a round drum on the left
local function headAGL(head, P, c)
	local function at(x, y, z)
		return P * CFrame.new(x, y, z)
	end
	part(head, "Receiver", Vector3.new(1.3, 1.2, 2.4), at(0, 0, 0.3), c.body)
	part(head, "Back", Vector3.new(1.0, 1.0, 0.4), at(0, 0, 1.7), c.dark)
	cyl(head, "Shroud", "z", 1.4, 0.8, at(0, 0.1, -1.6), c.dark)
	cyl(head, "Barrel", "z", 1.0, 0.5, at(0, 0.1, -2.8), c.barrel)
	cyl(head, "Brake", "z", 0.5, 0.75, at(0, 0.1, -3.35), c.barrel)
	cyl(head, "Drum", "x", 0.9, 1.7, at(-1.45, 0.1, 0.3), c.lid)
	cyl(head, "DrumHub", "x", 1.0, 0.5, at(-1.45, 0.1, 0.3), c.dark)
	part(head, "Chute", Vector3.new(0.5, 0.5, 0.7), at(-0.82, 0.1, 0.3), c.dark)
	part(head, "Optic", Vector3.new(0.3, 0.45, 0.9), at(0.55, 0.85, 0.2), c.dark)
	fittings(head, P, c, 1.95, -1.2)
end

local function build(g, parent)
	local spec, f = g.spec, g.frame
	local c = PAINT[g.kind]
	local model = Instance.new("Model")
	model.Name = "Stationary_" .. g.kind .. "_" .. g.id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("NoDetail", true) -- not a wall: no grime or fittings from the detail plan
	model:SetAttribute("Id", g.id)
	model:SetAttribute("Kind", g.kind)
	model:SetAttribute("Frame", f)
	model:SetAttribute("ArcL", g.arcs.l)
	model:SetAttribute("ArcR", g.arcs.r)
	model:SetAttribute("ArcU", g.arcs.up)
	model:SetAttribute("ArcD", g.arcs.dn)
	local head = Instance.new("Model")
	head.Name = "Head" -- the client turns these parts with the aim; the server's copy stays in the neutral pose
	head.Parent = model
	tripod(model, g, c)
	if g.kind == "AGL30" then
		headAGL(head, S.pivot(f, spec), c)
	else
		headHMG(head, S.pivot(f, spec), c)
	end
	model.PrimaryPart = model:FindFirstChild("Post")
	-- the operator spot carries the Interact prompt
	local spot = part(model, "Spot", Vector3.new(2.2, 0.2, 2.2), CFrame.new(S.opSpot(f, spec) + Vector3.new(0, 0.1, 0)), c.dark)
	spot.Transparency = 1
	local pp = Instance.new("ProximityPrompt")
	pp.KeyboardKeyCode = Enum.KeyCode.F -- Tarkov's interact key
	pp.ActionText = "Man the gun"
	pp.ObjectText = spec.name
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 7
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.Parent = spot
	model.Parent = parent
	CollectionService:AddTag(model, Stationary.TAG)
	return model, pp
end

local function folderFor(parent)
	if parent then
		return parent
	end
	local world = workspace:FindFirstChild("ZR_World") or workspace
	local f = world:FindFirstChild("Stationary")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Stationary"
		f.Parent = world
	end
	return f
end

-- replicate what clients draw: the belt, the aim (the head turns on every client), the operator's name
local function publish(g, force, t)
	local m, s = g.model, g.sent
	if not (m and m.Parent) then
		return
	end
	if force or g.rounds ~= s.r then
		s.r = g.rounds
		m:SetAttribute("Rounds", g.rounds)
		g.prompt.ObjectText = g.spec.name .. (g.rounds > 0 and "" or "  (EMPTY)")
	end
	if force or (t - s.t >= 0.066 and (math.abs(g.yaw - s.y) > 0.004 or math.abs(g.pitch - s.p) > 0.004)) then
		s.y, s.p, s.t = g.yaw, g.pitch, t
		m:SetAttribute("Yaw", g.yaw)
		m:SetAttribute("Pitch", g.pitch)
	end
end

-- kind: "HMG12" or "AGL30". cf: the ground point under the pivot; its heading (rotation about y) is where the gun points at
-- yaw 0. opts: parent (default the world's Stationary folder), arcs ({ left, right, up, down } in degrees over the kind's)
function Stationary.place(kind, cf, opts)
	opts = opts or {}
	local spec = S.KINDS[kind]
	if not spec or typeof(cf) ~= "CFrame" then
		warn("[ZR] stationary: cannot place", tostring(kind))
		return nil
	end
	for i = #Stationary.guns, 1, -1 do
		local old = Stationary.guns[i]
		if not (old.model and old.model.Parent) then
			table.remove(Stationary.guns, i) -- a map was rebuilt
		end
	end
	nextId += 1
	local g = {
		id = nextId, kind = kind, spec = spec, frame = S.frame(cf), arcs = S.makeArcs(spec, opts.arcs), rounds = spec.belt,
		yaw = 0, pitch = 0, bloom = 0, nextShot = 0, last = -10, seen = 0, shots = 0, fire = false,
		burstN = 0, burstLen = 1, lastSeen = 0, sent = { r = -1, y = 0, p = 0, t = 0 },
	}
	g.model, g.prompt = build(g, folderFor(opts.parent))
	g.prompt.Triggered:Connect(function(player)
		Stationary.mount(player, g)
	end)
	table.insert(Stationary.guns, g)
	publish(g, true, os.clock())
	return g
end

function Stationary.remove(g)
	if g.op then
		Stationary.vacate(g, "removed")
	end
	if g.crew then
		Stationary.release(g, g.crew)
	end
	for i = #Stationary.guns, 1, -1 do
		if Stationary.guns[i] == g then
			table.remove(Stationary.guns, i)
		end
	end
	if g.model then
		g.model:Destroy()
	end
end

-- ── fire: rate, belt, the round in flight ───────────────────────────────────────────────────────────────────
-- damage falls off with distance like every other weapon (Weapons.FALLOFF_START / FALLOFF_MIN of the range)
function Stationary.falloff(dist, range)
	local fs = range * Weapons.FALLOFF_START
	if dist <= fs then
		return 1
	end
	return math.max(Weapons.FALLOFF_MIN, 1 - (dist - fs) / (range - fs) * (1 - Weapons.FALLOFF_MIN))
end

-- schedule the next round: a steady rate while firing, from now after a pause
local function cadence(g, t)
	local iv = S.interval(g.spec)
	if t - g.nextShot > iv then
		g.nextShot = t + iv
	else
		g.nextShot += iv
	end
end

-- dir turned by a random angle inside a cone of `deg` degrees
local function scatter(dir, deg)
	local r = math.rad(deg) * math.sqrt(math.random())
	local a = math.random() * math.pi * 2
	return (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(r * math.sin(a), r * math.cos(a), 0)).LookVector
end

-- the AGL-30's round bursts where it lands (a frag blast); closer than its arming distance it is a dud
function Stationary.burst(g, who, res, hitPos, dist)
	local spec = g.spec
	ctx.Hazards.hit(res.Instance, who)
	if dist < spec.arm then
		return
	end
	Stationary.stats.shells += 1
	ctx.Grenades.blastAt(hitPos + res.Normal * 0.5, spec.round, who)
end

-- a round reached something (the bullet's hit callback): same rules as Combat.shoot
function Stationary.land(g, who, from, res, hitPos, dist)
	local spec = g.spec
	if spec.round then
		return Stationary.burst(g, who, res, hitPos, dist)
	end
	if ctx.Hazards.hit(res.Instance, who) then
		return
	end
	local model = res.Instance:FindFirstAncestorOfClass("Model")
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0) then
		return
	end
	if g.crew and ctx.AI.byModel(model) then
		return -- a crew never hurts its own side
	end
	local fall = Stationary.falloff(dist, spec.range)
	local r = ctx.Combat.hitModel(model, {
		dmg = spec.dmg * fall, pen = spec.pen * (0.85 + 0.15 * fall), armorDmg = spec.armorDmg, bleedL = spec.bleedL, bleedH = spec.bleedH,
		part = res.Instance, hitPos = hitPos, attacker = who, from = from, weapon = spec.name, ammo = spec.ammoName,
	})
	if r and typeof(who) == "Instance" and who:IsA("Player") and who.Parent then
		ctx.Remotes.note(who, "hit", { kill = r.killed })
	end
end

-- a round that flew its whole range without hitting anything: the AGL-30's self-destructs there
function Stationary.expire(g, who, pos)
	if g.spec.round then
		Stationary.stats.shells += 1
		ctx.Grenades.blastAt(pos, g.spec.round, who)
	end
end

-- the round in flight. who: the operator (Player), a crew's model or nil. It starts at the operator's eye and flies along
-- the aim (the crosshair is where it lands), the bore tilted for the zero, spread by the bloom. The belt and the rate are
-- Stationary.trigger's.
function Stationary.fire(g, who)
	local spec = g.spec
	local player, body = nil, nil
	if typeof(who) == "Instance" then
		if who:IsA("Player") then
			player, body = who, who.Character
		else
			body = who -- a crew's model
		end
	end
	local eye = S.eye(g.frame, spec, g.yaw)
	local cone = spec.spread + g.bloom + (g.crew and spec.aiErr or 0)
	g.bloom = math.min(spec.bloomMax, g.bloom + spec.bloomPerShot)
	local dir = scatter(S.dirOf(g.frame, spec, g.yaw, g.pitch), cone)
	local v0, k = Ballistics.muzzle(spec), spec.drag
	local bore = Ballistics.tilt(dir, Ballistics.zeroAngle(spec.zero, v0, k))
	local params = ctx.Combat.filter(body)
	-- the effects follow the arc as the world stands now; the damage comes from the bullet in flight
	local pres, ppos = Ballistics.trace(eye, bore, v0, k, spec.range, params)
	local pm = pres and pres.Instance:FindFirstAncestorOfClass("Model")
	local predHit = pm ~= nil and pm:FindFirstChildOfClass("Humanoid") ~= nil
	Ballistics.fly(eye, bore, v0, k, spec.range, params, function(res, hitPos, dist)
		Stationary.land(g, who, eye, res, hitPos, dist)
	end, function(pos)
		Stationary.expire(g, who, pos)
	end)
	local tracer = spec.tracerEvery > 0 and g.shots % spec.tracerEvery == 0
	-- the operator's own client draws its flash, sound and tracer itself; everyone else gets the usual shot effect
	ctx.Remotes.fx("shot", {
		o = S.muzzle(g.frame, spec, g.yaw, g.pitch), p = ppos, n = pres and pres.Normal or nil, h = predHit, w = spec.id,
		t = tracer or nil, m = pres and pres.Material or nil, ai = (player == nil) or nil,
	}, player)
	ctx.AI.hearShot(eye, who, g.crew, spec.loud)
	ctx.AI.bulletPassed(eye, ppos, body)
end

-- fire one round if the belt has one and the rate allows it at time t: the belt loses a round, the next one is scheduled,
-- the bullet flies. Returns true when a round left the gun.
function Stationary.trigger(g, t, who)
	if g.rounds <= 0 or t < g.nextShot then
		return false
	end
	cadence(g, t)
	g.rounds = math.max(0, g.rounds - 1)
	g.shots += 1
	g.last = t
	Stationary.stats.rounds += 1
	Stationary.fire(g, who)
	return true
end

-- ── the operator: mount, aim, leave ─────────────────────────────────────────────────────────────────────────
-- put a player on the gun: held at the operator spot, facing along the gun, one operator at a time
function Stationary.occupy(g, player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or g.op or g.crew or mounted[player] then
		return false
	end
	g.op, g.fire, g.seen, g.yaw, g.pitch = player, false, os.clock(), 0, 0
	mounted[player] = g
	g.prompt.Enabled = false
	char:PivotTo(CFrame.new(S.opSpot(g.frame, g.spec) + Vector3.new(0, STAND, 0)) * CFrame.Angles(0, S.heading(g.frame), 0))
	root.AssemblyLinearVelocity = Vector3.zero -- a raider who ran up to the gun does not slide off it
	char:SetAttribute("TP", os.clock()) -- the movement guard takes this as a server teleport
	char:SetAttribute("Stance", "s")
	char:SetAttribute("Lean", 0)
	char:SetAttribute("Mounted", g.id)
	g.model:SetAttribute("Op", player.DisplayName)
	Stationary.stats.mounts += 1
	tell(player, "stmount", { id = g.id, kind = g.kind, rounds = g.rounds })
	publish(g, true, os.clock())
	return true
end

-- the Interact prompt was used: the raider must be alive in a raid, near the gun, not busy and the gun free
function Stationary.mount(player, g)
	local s = Stationary.sessionOf(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (s and not s.done and hum and hum.Health > 0 and root) or mounted[player] or g.op or g.crew then
		return false
	end
	if os.clock() < (blocked[player] or 0) or (root.Position - S.opSpot(g.frame, g.spec)).Magnitude > Stationary.REACH + STAND then
		return false
	end
	local hs = ctx.Health.of(player)
	if (hs and hs.using) or (ctx.Grenades and ctx.Grenades.busy(player)) then
		return false -- busy treating a wound or throwing
	end
	return Stationary.occupy(g, player)
end

-- the operator is off the gun: left, died, went too far, the raid ended or the gun was reset
function Stationary.vacate(g, why)
	local p = g.op
	if not p then
		return
	end
	g.op, g.fire = nil, false
	mounted[p] = nil
	blocked[p] = os.clock() + Stationary.RESTART
	local char = p.Character
	if char then
		char:SetAttribute("Mounted", nil) -- they stand where they were: behind the gun
	end
	g.prompt.Enabled = g.crew == nil
	g.model:SetAttribute("Op", "")
	tell(p, "stend", { id = g.id, why = why })
end

function Stationary.leave(player)
	local g = mounted[player]
	if g then
		Stationary.vacate(g, "leave")
	end
end

function Stationary.gunOf(player)
	return mounted[player]
end

-- an aim update from the operator's client: where it looks (relative to the gun) and whether the trigger is down
function Stationary.setAim(g, y, p, fire, t)
	g.yaw, g.pitch = S.clamp(g.arcs, y, p)
	g.fire = fire == true
	g.seen = t
end

function Stationary.aim(player, p)
	local g = mounted[player]
	if g and type(p) == "table" and Util.finite(p.y) and Util.finite(p.p) then
		Stationary.setAim(g, p.y, p.p, p.f == 1 or p.f == true, os.clock())
	end
end

-- why the operator cannot stay on the gun (nil when all is well)
local function opProblem(g)
	local p = g.op
	if not p.Parent then
		return "gone"
	end
	local s = Stationary.sessionOf(p)
	if not s or s.done then
		return "raid"
	end
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root) or hum.Health <= 0 then
		return "dead"
	end
	if (root.Position - (S.opSpot(g.frame, g.spec) + Vector3.new(0, STAND, 0))).Magnitude > S.LEASH then
		return "away"
	end
	return nil
end

-- ── crews: guards posted at a gun ───────────────────────────────────────────────────────────────────────────
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- the free gun whose operator spot is where a unit stands, or nil
function Stationary.gunNear(pos, radius)
	local best, bd = nil, radius or 4
	for _, g in Stationary.guns do
		if g.model.Parent and not g.op and not g.crew then
			local spot = S.opSpot(g.frame, g.spec)
			local d = flat(spot - pos).Magnitude
			if d <= bd and math.abs(spot.Y + STAND - pos.Y) < 4 then
				best, bd = g, d
			end
		end
	end
	return best
end

-- can a round fired from the eye reach pos: inside the arcs and between the crew's shortest and longest range
function Stationary.reaches(g, pos)
	local spec = g.spec
	local y, p = S.anglesFrom(g.frame, spec, pos)
	local d = (pos - S.eye(g.frame, spec, y)).Magnitude
	return S.inArc(g.arcs, y, p, math.rad(1)) and d <= spec.aiRange and d >= spec.aiMin
end

function Stationary.seat(g, u, t)
	local spec = g.spec
	g.crew, u.gun = u, g
	g.lastSeen, g.burstN, g.burstLen = t, 0, math.random(spec.burst[1], spec.burst[2])
	g.nextShot = math.max(g.nextShot, t + 0.5 + math.random() * 0.4) -- a moment to get on the gun
	g.prompt.Enabled = false
	g.model:SetAttribute("Op", u.label or "Guard")
end

function Stationary.release(g, u)
	if g.crew == u then
		g.crew, g.tpart = nil, nil
		g.prompt.Enabled = g.op == nil
		g.model:SetAttribute("Op", "")
	end
	if u.gun == g then
		u.gun = nil
	end
end

-- AI hook (AI.think, 5 Hz): a guard posted at a gun who is engaging a raider the gun can reach mans it. Returns true and a
-- point to face while the guard is on the gun, so the AI skips its own moves. The guard walks off when the target is dead,
-- gone for LOST seconds or out of reach, the belt is empty, or the guard was moved away from the spot.
function Stationary.crew(u, t)
	local g = u.gun
	if g and (g.crew ~= u or not u.alive) then
		u.gun, g = nil, nil
	end
	local tm = u.target
	local hum = tm and tm.Parent and tm:FindFirstChildOfClass("Humanoid")
	if not (u.alive and u.state == "ENGAGE" and hum and hum.Health > 0) then
		if g then
			Stationary.release(g, u)
		end
		return false
	end
	if not g then
		g = u.post and Stationary.gunNear(u.root.Position, 4)
		if not g or g.rounds <= 0 then
			return false
		end
	end
	local seen = ctx.AI.visiblePart(u, tm, S.eye(g.frame, g.spec, g.yaw))
	local aimable = seen ~= nil and Stationary.reaches(g, seen.Position)
	if not u.gun then
		if not aimable then
			return false
		end
		Stationary.seat(g, u, t)
	end
	if aimable then
		g.tpart, g.lastSeen = seen, t
	end
	if g.rounds <= 0 or t - g.lastSeen > Stationary.LOST or flat(u.root.Position - S.opSpot(g.frame, g.spec)).Magnitude > 6 then
		Stationary.release(g, u)
		return false
	end
	return true, S.muzzle(g.frame, g.spec, g.yaw, g.pitch)
end

-- aim ahead of a moving target by the round's flight time (capped)
local function lead(g, tp)
	local root = tp.Parent and tp.Parent:FindFirstChild("HumanoidRootPart")
	if not root then
		return Vector3.zero
	end
	local v = root.AssemblyLinearVelocity
	local d = (tp.Position - S.eye(g.frame, g.spec, g.yaw)).Magnitude
	return flat(v) * math.min(0.6, d / (Ballistics.muzzle(g.spec) * 0.85))
end

-- the aim that puts the round on goal: the arc lies above the line of sight by the bore tilt and below it by the drop
local function crewAim(g, goal)
	local spec = g.spec
	local y = S.anglesFrom(g.frame, spec, goal)
	local v0, k = Ballistics.muzzle(spec), spec.drag
	local d = (goal - S.eye(g.frame, spec, y)).Magnitude
	local over = Ballistics.dropAt(d, v0, k) - d * math.tan(Ballistics.zeroAngle(spec.zero, v0, k))
	return S.anglesFrom(g.frame, spec, goal + Vector3.new(0, over, 0))
end

local function friendNear(pos, crewUnit)
	for _, o in ctx.AI.units do
		if o ~= crewUnit and o.alive and o.root and (o.root.Position - pos).Magnitude < 12 then
			return true
		end
	end
	return false
end

-- every frame: slew at the gun's turn rate, fire short bursts while the target is in sight and the gun is laid on it
local function crewDrive(g, t, dt)
	local u, spec = g.crew, g.spec
	if not (u.alive and u.root and u.root.Parent) then
		Stationary.release(g, u)
		return
	end
	local tp = g.tpart
	if not (tp and tp.Parent) or t - g.lastSeen > Stationary.LOST then
		return -- nothing to shoot at: the gun stays as it is
	end
	local goal = tp.Position + lead(g, tp)
	local y, p = S.clamp(g.arcs, crewAim(g, goal))
	g.yaw = S.approach(g.yaw, y, spec.turnRate * dt)
	g.pitch = S.approach(g.pitch, p, spec.turnRate * dt)
	local laid = math.abs(S.wrap(y - g.yaw)) < math.rad(2.5) and math.abs(p - g.pitch) < math.rad(2.5)
	if t - g.lastSeen < 1 and laid and g.rounds > 0 and t >= g.nextShot then
		if spec.round and friendNear(goal, u) then
			g.nextShot = t + 0.5 -- a friend stands where the burst would fall
			return
		end
		if Stationary.trigger(g, t, u.model) then
			g.burstN += 1
			if g.burstN >= g.burstLen then
				g.burstN = 0
				g.burstLen = math.random(spec.burst[1], spec.burst[2])
				g.nextShot = t + spec.pause[1] + math.random() * (spec.pause[2] - spec.pause[1])
			end
		end
	end
end

-- ── the clock ───────────────────────────────────────────────────────────────────────────────────────────────
-- one step of a gun: the operator's trigger, a crew's aim and fire, the bloom settling, what clients see
function Stationary.update(g, t, dt)
	if g.op then
		local why = opProblem(g)
		if why then
			Stationary.vacate(g, why)
		elseif g.fire and t - g.seen <= Stationary.KEEP then
			Stationary.trigger(g, t, g.op)
		end
	elseif g.crew then
		crewDrive(g, t, dt)
	end
	if t - g.last > 0.12 then
		g.bloom = math.max(0, g.bloom - g.spec.bloomDecay * dt)
	end
	publish(g, false, t)
end

-- belt full, nobody on the gun, aimed straight ahead (guns spawn loaded every raid and cannot be reloaded)
function Stationary.refill(g)
	if g.op then
		Stationary.vacate(g, "reset")
	end
	if g.crew then
		Stationary.release(g, g.crew)
	end
	g.rounds, g.yaw, g.pitch, g.bloom, g.fire, g.nextShot, g.last, g.shots = g.spec.belt, 0, 0, 0, false, 0, -10, 0
	if g.model.Parent then
		g.prompt.Enabled = true
		publish(g, true, os.clock())
	end
end

-- a new raid: every gun full again
function Stationary.reset()
	for _, g in Stationary.guns do
		Stationary.refill(g)
	end
end

function Stationary.init(c)
	ctx = c
	ctx.Remotes.onAct("staim", function(player, p)
		Stationary.aim(player, p)
	end, 30, 40)
	ctx.Remotes.onAct("stleave", function(player)
		Stationary.leave(player)
	end, 4, 6)
	Players.PlayerRemoving:Connect(function(p)
		local g = mounted[p]
		if g then
			Stationary.vacate(g, "gone")
		end
		blocked[p] = nil -- after the vacate, which sets it
	end)
end

function Stationary.start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		for _, g in Stationary.guns do
			if g.model.Parent then
				local ok, err = pcall(Stationary.update, g, t, dt)
				if not ok then
					warn("[ZR] stationary:", err)
				end
			end
		end
	end)
end

return Stationary
