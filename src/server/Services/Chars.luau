--!nonstrict
-- Characters: the operator rig (our own R15-named Motor6D skeleton with human proportions and Blender body
-- meshes, part-built fallback) used by players (StarterCharacter) and AI; gear visuals; the weapon in hand
-- (WeaponRoot driven by a WeaponGrip motor on the right hand, posed by RigMath) and slung long guns; the
-- server hitbox pose (stance, crouch depth, lean, aim pitch, weapon hold) written to Motor6D.C0; ragdoll.
-- Clients animate on top through Motor6D.Transform (Animator.luau), using the same RigMath solver.
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local WeaponModels = require(Shared.WeaponModels)
local RigSpec = require(Shared.RigSpec)
local RigMath = require(Shared.RigMath)

local Chars = {}
local ctx

local LOOKS = {
	player = { jacket = "5A6047", pants = "40433A", gear = "5F5E46", helmet = "4E5240" },
	guard = { jacket = "3B4652", pants = "2E343A", gear = "2B2F33", helmet = "1F2326" },
	scav = { jacket = "5C554A", pants = "3D3B36", gear = "4A443A", helmet = "3A3833" },
	boss = { jacket = "2F3330", pants = "262826", gear = "1E201F", helmet = "171918" },
}
Chars.LOOKS = LOOKS
local CLOTH = {
	UpperTorso = "jacket", LeftUpperArm = "jacket", RightUpperArm = "jacket", LeftLowerArm = "jacket", RightLowerArm = "jacket",
	LowerTorso = "pants", LeftUpperLeg = "pants", RightUpperLeg = "pants", LeftLowerLeg = "pants", RightLowerLeg = "pants",
}
local FALLBACK = { Head = "25272A", LeftHand = "1D1E1D", RightHand = "1D1E1D", LeftFoot = "4A3F33", RightFoot = "4A3F33" }
local COLLIDE = { UpperTorso = true, LowerTorso = true, Head = true }
local GEAR_PARTS = { Helmet = true, FacePlate = true, Visor = true, Cap = true, Vest = true, ArmGuard = true, Pouch = true, BodyCam = true, CamLens = true, Pack = true, Holster = true }
local WEAPON_PARTS = { TPWeapon = true, TPSling = true, TPRifle = true, WeaponRoot = true }

-- ── rig ──────────────────────────────────────────────────────────────────────
function Chars.buildRig(kind)
	local look = LOOKS[kind] or LOOKS.player
	local model = Instance.new("Model")
	model.Name = "Operator"
	local parts = {}
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = RigSpec.hrp.size
	hrp.CFrame = CFrame.new(RigSpec.hrp.center)
	hrp.Transparency = 1
	hrp.CanCollide = true
	hrp.CanQuery = false
	hrp.TopSurface = Enum.SurfaceType.Smooth
	hrp.BottomSurface = Enum.SurfaceType.Smooth
	hrp.Parent = model
	parts.HumanoidRootPart = hrp
	local lib = ReplicatedStorage:FindFirstChild("ZR_Assets")
	for name, spec in RigSpec.parts do
		local mesh = lib and lib:FindFirstChild("ZR_OP_" .. name)
		local p
		if mesh then
			p = mesh:Clone()
		else
			p = Instance.new("Part")
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
		end
		p.Name = name
		p.Anchored = false
		p.Size = spec.size
		p.CFrame = CFrame.new(spec.center)
		local cloth = CLOTH[name]
		if cloth then
			p.Color = Color3.fromHex(look[cloth])
			p.Material = Enum.Material.Fabric
		else
			p.Color = mesh and Color3.new(1, 1, 1) or Color3.fromHex(FALLBACK[name] or "333333")
			p.Material = Enum.Material.SmoothPlastic
		end
		p.CanCollide = COLLIDE[name] == true
		p.CanTouch = false
		p.Massless = name ~= "UpperTorso" and name ~= "LowerTorso"
		p.Parent = model
		parts[name] = p
	end
	for _, j in RigSpec.joints do
		local p0, p1 = parts[j.p0], parts[j.p1]
		local m = Instance.new("Motor6D")
		m.Name = j.name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = p0.CFrame:Inverse() * CFrame.new(j.pos)
		m.C1 = p1.CFrame:Inverse() * CFrame.new(j.pos)
		m.Parent = p1
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = RigSpec.hipHeight
	hum.AutomaticScalingEnabled = false
	hum.Parent = model
	model.PrimaryPart = hrp
	model:SetAttribute("ZR_Rig", 1)
	return model
end

local function installStarterCharacter()
	local old = StarterPlayer:FindFirstChild("StarterCharacter")
	if old then
		old:Destroy()
	end
	local rig = Chars.buildRig("player")
	rig.Name = "StarterCharacter"
	rig.Parent = StarterPlayer
	local meshes = rig.UpperTorso:IsA("MeshPart")
	print("[ZR] operator rig installed (" .. (meshes and "Blender meshes" or "part fallback") .. ")")
end

function Chars.init(c)
	ctx = c
	Players.CharacterAutoLoads = false
	StarterPlayer.LoadCharacterAppearance = false
	StarterPlayer.EnableMouseLockOption = false
	StarterPlayer.CharacterWalkSpeed = Config.WALK_SPEED
	local scs = StarterPlayer:FindFirstChildOfClass("StarterCharacterScripts")
	if scs then
		-- empty overrides: no default animations (client animator poses rigs) and no health regen
		for name, class in { Animate = "LocalScript", Health = "Script" } do
			if not scs:FindFirstChild(name) then
				local s = Instance.new(class)
				s.Name = name
				s.Parent = scs
			end
		end
	end
	installStarterCharacter()
end

-- ── gear ─────────────────────────────────────────────────────────────────────
local function attach(char, partName, size, offset, color, material, name, shape)
	local host = char:FindFirstChild(partName)
	if not host then
		return nil
	end
	local p = Instance.new("Part")
	p.Name = name or "Gear"
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = host.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = host
	w.Part1 = p
	w.Parent = p
	p.Parent = char
	return p
end

local function weldAll(parts, host, parent, name)
	for _, p in parts do
		p.Name = name
		p.CastShadow = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = host
		w.Part1 = p
		w.Parent = p
		p.Parent = parent
	end
end

-- weapon kind for holds + the anchors the hands use (third-person scale)
Chars.holdOf = WeaponModels.holdOf

-- Third-person weapons: the active one on a WeaponGrip motor (right hand) so every client can pose it with the
-- arms; the other long guns slung on the back. A tactical light follows the "WeaponLight" attribute.
function Chars.setWeapon(char, holder, g)
	if not char then
		return
	end
	for _, c in char:GetChildren() do
		if WEAPON_PARTS[c.Name] then
			c:Destroy()
		end
	end
	local torso = char:FindFirstChild("UpperTorso")
	local hand = char:FindFirstChild("RightHand")
	local it = holder and g and holder.items[g]
	if not torso or not hand then
		return
	end
	if it then
		char:SetAttribute("ActiveWeapon", it.id)
		local root = Instance.new("Part")
		root.Name = "WeaponRoot"
		root.Size = Vector3.new(0.1, 0.1, 0.1)
		root.Transparency = 1
		root.CanCollide = false
		root.CanQuery = false
		root.CanTouch = false
		root.Massless = true
		local _, anchors = Chars.holdOf(it.id)
		local c0 = CFrame.new(0, -0.05, -0.02) * CFrame.new(-(anchors and anchors.grip or Vector3.zero))
		root.CFrame = hand.CFrame * c0
		local m = Instance.new("Motor6D")
		m.Name = "WeaponGrip"
		m.Part0 = hand
		m.Part1 = root
		m.C0 = c0
		m.C1 = CFrame.identity
		m.Parent = root
		root.Parent = char
		local b = WeaponModels.build(holder.items, it, root.CFrame, 1)
		if b then
			local all = table.clone(b.parts)
			for _, p in b.mag do
				table.insert(all, p)
			end
			weldAll(all, root, char, "TPWeapon")
			if b.lightPart then
				local l = Instance.new("SpotLight")
				l.Name = "WeaponLight"
				l.Face = Enum.NormalId.Right
				l.Range = 42
				l.Angle = 42
				l.Brightness = 3.2
				l.Color = Color3.fromRGB(255, 244, 222)
				l.Shadows = true
				l.Enabled = char:GetAttribute("WeaponLight") == true
				l.Parent = b.lightPart
			end
		end
	else
		char:SetAttribute("ActiveWeapon", nil)
	end
	if holder then
		-- long guns not in hand go on the back (two sling positions)
		local n = 0
		for _, slot in { "primary", "secondary" } do
			local lg = holder.slots[slot]
			local long = lg and lg ~= g and holder.items[lg]
			if long then
				n += 1
				local back = torso.CFrame * CFrame.new(n == 1 and 0.12 or -0.16, 0.05, 0.52 + n * 0.08) * CFrame.Angles(0, math.rad(180), math.rad(n == 1 and -55 or 55))
				local bb = WeaponModels.build(holder.items, long, back, 1)
				if bb then
					local all = table.clone(bb.parts)
					for _, p in bb.mag do
						table.insert(all, p)
					end
					weldAll(all, torso, char, "TPSling")
				end
			end
		end
	end
	Chars.pose(char)
end

-- visible gear derived from a holder's equipment slots
function Chars.gearOf(h, activeSlot)
	if not h then
		return nil
	end
	local function id(slot)
		local g = h.slots[slot]
		local it = g and h.items[g]
		return it and it.id or nil
	end
	local active = (activeSlot and h.slots[activeSlot]) or h.slots.primary or h.slots.secondary or h.slots.holster or h.slots.melee
	return { head = id("head"), armor = id("armor"), rig = id("rig"), back = id("back"), primary = id("primary") or id("secondary"), holster = id("holster"), holder = h, activeG = active }
end

-- refresh visible gear after mid-raid equipment changes
function Chars.redress(char, holder, activeSlot, kind)
	if not char then
		return
	end
	for _, c in char:GetChildren() do
		if GEAR_PARTS[c.Name] or WEAPON_PARTS[c.Name] then
			c:Destroy()
		end
	end
	Chars.dress(char, kind or (char:GetAttribute("Scav") and "scav") or "player", Chars.gearOf(holder, activeSlot))
end

local PACK_SIZE = {
	BAG_SLING = Vector3.new(0.9, 1.0, 0.45), CANVAS_BAG = Vector3.new(1.25, 1.5, 0.66),
	BAG_PATROL = Vector3.new(1.45, 1.8, 0.82), BAG_RAID = Vector3.new(1.6, 2.15, 0.98),
}

-- gear = Chars.gearOf(holder) or nil (safehouse: no kit visible). Sizes follow the operator rig.
function Chars.dress(char, kind, gear)
	local look = LOOKS[kind] or LOOKS.player
	local gc = Color3.fromHex(look.gear)
	gear = gear or {}
	local helmet = gear.head and Items.defs[gear.head]
	if helmet then
		local cls = helmet.armor and helmet.armor.class or 2
		local grow = cls * 0.012
		attach(char, "Head", Vector3.new(0.88 + grow, 0.52, 0.98 + grow), CFrame.new(0, 0.27, 0.03), Color3.fromHex(look.helmet), Enum.Material.SmoothPlastic, "Helmet")
		if helmet.armor and helmet.armor.face then
			attach(char, "Head", Vector3.new(0.74, 0.56, 0.08), CFrame.new(0, -0.03, -0.47), Color3.fromHex("2A2D2B"), Enum.Material.Metal, "FacePlate")
		else
			attach(char, "Head", Vector3.new(0.7, 0.07, 0.06), CFrame.new(0, 0.12, -0.45), Color3.fromHex("161819"), Enum.Material.SmoothPlastic, "Visor")
		end
	elseif kind == "player" then
		attach(char, "Head", Vector3.new(0.8, 0.2, 0.88), CFrame.new(0, 0.4, 0.01), Color3.fromHex("3E4236"), Enum.Material.Fabric, "Cap")
		attach(char, "Head", Vector3.new(0.62, 0.05, 0.3), CFrame.new(0, 0.33, -0.52), Color3.fromHex("3E4236"), Enum.Material.Fabric, "Cap")
	elseif kind == "scav" then
		attach(char, "Head", Vector3.new(0.84, 0.32, 0.9), CFrame.new(0, 0.34, 0.02), Color3.fromHex("2E2C29"), Enum.Material.Fabric, "Cap")
	end
	local armor = gear.armor and Items.defs[gear.armor]
	local rig = gear.rig and Items.defs[gear.rig]
	local front = -0.4
	if armor then
		local cls = armor.armor.class
		attach(char, "UpperTorso", Vector3.new(1.4 + cls * 0.02, 1.08 + cls * 0.02, 0.92 + cls * 0.04), CFrame.new(0, -0.06, 0), gc, Enum.Material.Fabric, "Vest")
		front = -(0.46 + cls * 0.02)
		if armor.armor.zones and armor.armor.zones.arms then
			for _, side in { "LeftUpperArm", "RightUpperArm" } do
				attach(char, side, Vector3.new(0.52, 0.5, 0.54), CFrame.new(0, 0.28, 0), gc, Enum.Material.Fabric, "ArmGuard")
			end
		end
	end
	if rig then
		if rig.armor ~= nil and not armor then
			attach(char, "UpperTorso", Vector3.new(1.44, 1.1, 0.98), CFrame.new(0, -0.06, 0), gc, Enum.Material.Fabric, "Vest")
			front = -0.49
		end
		local n = math.min(rig.grid and rig.grid.w or 3, 4)
		for i = 1, n do
			local x = (i - (n + 1) / 2) * 0.3
			attach(char, "UpperTorso", Vector3.new(0.27, 0.34, 0.18), CFrame.new(x, -0.24, front - 0.09), gc, Enum.Material.Fabric, "Pouch")
		end
	end
	if kind == "player" then
		local cam = attach(char, "UpperTorso", Vector3.new(0.2, 0.26, 0.12), CFrame.new(-0.36, 0.3, math.min(front, -0.4) - 0.06), Color3.fromHex("1A1C1D"), Enum.Material.SmoothPlastic, "BodyCam")
		if cam then
			local lens = attach(char, "UpperTorso", Vector3.new(0.08, 0.08, 0.04), CFrame.new(-0.36, 0.34, math.min(front, -0.4) - 0.13), Color3.fromHex("C24A35"), Enum.Material.Neon, "CamLens")
			if lens then
				lens.CastShadow = false
			end
		end
	end
	if gear.back then
		local size = PACK_SIZE[gear.back] or PACK_SIZE.CANVAS_BAG
		attach(char, "UpperTorso", size, CFrame.new(0, 0.05 - (size.Y - 1.5) * 0.3, 0.42 + size.Z * 0.5), Color3.fromHex("6B6A4E"), Enum.Material.Fabric, "Pack")
	end
	if gear.holster then
		attach(char, "RightUpperLeg", Vector3.new(0.18, 0.42, 0.34), CFrame.new(0.34, 0.18, 0), Color3.fromHex("23262A"), Enum.Material.SmoothPlastic, "Holster")
	end
	if gear.holder then
		Chars.setWeapon(char, gear.holder, gear.activeG)
	end
end

-- Squad armband on both upper arms (Tarkov: coloured bands tell squadmates apart; no friendly markers).
function Chars.armband(char, color)
	if not char then
		return
	end
	for _, c in char:GetChildren() do
		if c.Name == "Armband" then
			c:Destroy()
		end
	end
	char:SetAttribute("Squad", color)
	if not color then
		return
	end
	for _, side in { "LeftUpperArm", "RightUpperArm" } do
		local b = attach(char, side, Vector3.new(0.5, 0.2, 0.52), CFrame.new(0, -0.1, 0), Color3.fromHex(color), Enum.Material.Fabric, "Armband")
		if b then
			b.CastShadow = false
		end
	end
end

-- clothing colours for a faction look (player scavs wear scav clothes)
function Chars.recolor(char, kind)
	local look = LOOKS[kind] or LOOKS.player
	for name, cloth in CLOTH do
		local p = char:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			p.Color = Color3.fromHex(look[cloth])
		end
	end
end

-- ── corpses ──────────────────────────────────────────────────────────────────
-- Bodies stay in the raid (lootable through Loot.spawnBody) after their owner respawns in the hideout or leaves.
-- Player:LoadCharacter() destroys the old character even when it was detached, so the body is a copy: the
-- engine-owned character goes, a static (or settling, then frozen) clone stays until the raid ends.
local corpses
local function corpseFolder()
	if not corpses or not corpses.Parent then
		corpses = workspace:FindFirstChild("ZR_Corpses") or Instance.new("Folder")
		corpses.Name = "ZR_Corpses"
		corpses.Parent = workspace
	end
	return corpses
end

function Chars.freeze(model)
	if not model or not model.Parent then
		return
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.AssemblyLinearVelocity = Vector3.zero
			p.AssemblyAngularVelocity = Vector3.zero
			p.Anchored = true
		end
	end
end

function Chars.freezeLater(model, delay)
	task.delay(delay or 8, Chars.freeze, model)
end

-- copy a character into a corpse; fall = true ragdolls the copy (it was still standing), else it is frozen as is
function Chars.keepCorpse(char, fall)
	if not char or not char.Parent then
		return nil
	end
	char:SetAttribute("KeepCorpse", nil)
	char.Archivable = true
	local ok, corpse = pcall(char.Clone, char)
	if not ok or not corpse then
		return nil
	end
	for _, d in corpse:GetDescendants() do
		if d:IsA("Humanoid") or d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ProximityPrompt") or d:IsA("Light") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanTouch = false
			d.Anchored = not fall
		end
	end
	corpse.Name = "Corpse"
	corpse:SetAttribute("Corpse", true)
	corpse.Parent = corpseFolder()
	if fall then
		Chars.ragdoll(corpse)
		for _, p in corpse:GetDescendants() do
			if p:IsA("BasePart") and not p.Anchored then
				pcall(p.SetNetworkOwner, p, nil)
			end
		end
		Chars.freezeLater(corpse, 8)
	end
	return corpse
end

-- a disconnecting raider drops where they stood (their character is removed with them)
function Chars.dropBody(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		local hs = ctx and ctx.Health and ctx.Health.get(char)
		if hs then
			ctx.Health.kill(hs, "SIGNAL LOST")
		end
	end
	local corpse = Chars.keepCorpse(char, true)
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 1
		end
	end
	return corpse
end

function Chars.clearCorpses()
	if corpses then
		corpses:ClearAllChildren()
	end
end

function Chars.setupHumanoid(hum: Humanoid)
	hum.MaxHealth = Config.MAX_HEALTH
	hum.Health = Config.MAX_HEALTH
	hum.WalkSpeed = Config.WALK_SPEED
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.NameOcclusion = Enum.NameOcclusion.OccludeAll
end

-- ── server hitbox pose ───────────────────────────────────────────────────────
-- Motor6D.C0 = joint rest offset * RigMath local: server raycasts see the stance, lean, aim pitch and the arms
-- holding the weapon. Only changed joints are written (replication cost).
local motorCache = setmetatable({}, { __mode = "k" })

local function motorsOf(char)
	local m = motorCache[char]
	if m and m.Root and m.Root.Parent then
		return m
	end
	m = {}
	for _, d in char:GetDescendants() do
		if d:IsA("Motor6D") and RigMath.joints[d.Name] then
			m[d.Name] = d
		end
	end
	motorCache[char] = m
	return m
end

local function changed(a, b)
	if (a.Position - b.Position).Magnitude > 0.015 then
		return true
	end
	local _, ang = (a.Rotation:Inverse() * b.Rotation):ToAxisAngle()
	return math.abs(ang) > 0.03
end

-- st = { stance = "s"|"c"|"p", depth, lean, pitch (deg), mode = "ready"|"aim"|"sprint"|"low" } (defaults: attributes)
function Chars.pose(char, st)
	if not char or not char.Parent then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 or not char:GetAttribute("ZR_Rig") then
		return
	end
	st = st or {}
	local stance = st.stance or char:GetAttribute("Stance") or "s"
	local depth = st.depth or char:GetAttribute("Depth") or 0.7
	local mode = st.mode
	if not mode then
		mode = (char:GetAttribute("Sprint") and "sprint") or (char:GetAttribute("Aim") and "aim") or "ready"
	end
	local hold, anchors = Chars.holdOf(char:GetAttribute("ActiveWeapon"))
	local p = {
		stance = stance, depth = depth, lean = st.lean or char:GetAttribute("Lean") or 0,
		pitch = math.rad(st.pitch or char:GetAttribute("Pitch") or 0), hold = hold, mode = mode, weapon = anchors,
		crouchFwd = stance == "c" and 0.15 * depth or 0,
	}
	local L, W, handCF = RigMath.pose(root.CFrame, p)
	local motors = motorsOf(char)
	for name, l in L do
		local m = motors[name]
		if m then
			local c0 = CFrame.new(RigMath.joints[name].p0) * l
			if changed(m.C0, c0) then
				m.C0 = c0
			end
		end
	end
	local wr = char:FindFirstChild("WeaponRoot")
	local grip = wr and wr:FindFirstChild("WeaponGrip")
	if grip and W and handCF then
		local c0 = handCF:Inverse() * W
		if changed(grip.C0, c0) then
			grip.C0 = c0
		end
	end
end

-- stance act from the owning client (validated): attributes for every client's animator + server hitboxes
function Chars.applyStance(player, p)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or type(p) ~= "table" then
		return
	end
	local stance = (p.st == "c" or p.st == "p") and p.st or "s"
	local depth = (type(p.d) == "number" and p.d == p.d) and math.clamp(p.d, 0, 1) or 0.7
	local lean = (type(p.l) == "number" and p.l == p.l) and math.clamp(p.l, -1, 1) or 0
	local sprint = p.s == true and stance == "s"
	if stance == "p" or sprint then
		lean = 0
	end
	char:SetAttribute("Stance", stance)
	char:SetAttribute("Depth", math.floor(depth * 20 + 0.5) / 20)
	char:SetAttribute("Lean", math.floor(lean * 10 + 0.5) / 10)
	char:SetAttribute("Crouch", stance == "c")
	char:SetAttribute("Aim", p.a == true and not sprint)
	char:SetAttribute("Sprint", sprint)
	if type(p.p) == "number" and p.p == p.p then
		char:SetAttribute("Pitch", math.clamp(math.floor(p.p), -85, 85))
	end
	Chars.pose(char)
end

-- one-shot gesture for third-person animation (reload, tube, check, heal, draw, slash)
function Chars.gesture(char, act, dur)
	if char then
		char:SetAttribute("Act", act)
		char:SetAttribute("ActT", workspace:GetServerTimeNow())
		char:SetAttribute("ActD", dur or 1)
	end
end

-- ── spawning ─────────────────────────────────────────────────────────────────
-- Spawns (or respawns) a player's character at cf. holder: raid inventory (for gear visuals) or nil.
function Chars.spawn(player: Player, cf: CFrame, holder: any?, activeSlot: string?, opts: any?)
	if not player.Parent then
		return nil
	end
	opts = opts or {}
	local old = player.Character
	if old and old:GetAttribute("KeepCorpse") then
		Chars.keepCorpse(old, false)
	end
	local ok, err = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		warn("[ZR] character load failed", err)
		return nil
	end
	local char = player.Character
	if not char then
		return nil
	end
	local hum = char:WaitForChild("Humanoid", 5)
	local root = char:WaitForChild("HumanoidRootPart", 5)
	if not hum or not root then
		return nil
	end
	Chars.setupHumanoid(hum)
	root.CanQuery = false
	if ctx and ctx.Health then
		local prof = ctx.Profiles.get(player)
		ctx.Health.attach(char, {
			-- a player scav is a fresh body: the PMC's wounds stay with the PMC
			player = player, kind = "player", inRaid = holder ~= nil, saved = (not opts.scav) and prof and prof.health or nil,
			holder = function()
				return (ctx.Raid.holder(player))
			end,
		})
	end
	local regen = char:FindFirstChild("Health")
	if regen and regen:IsA("Script") then
		regen:Destroy()
	end
	char:PivotTo(cf)
	char:SetAttribute("Stance", "s")
	char:SetAttribute("Lean", 0)
	char:SetAttribute("Pitch", 0)
	local kind = opts.scav and "scav" or "player"
	char:SetAttribute("Scav", opts.scav == true)
	if opts.scav then
		Chars.recolor(char, "scav")
	end
	Chars.dress(char, kind, Chars.gearOf(holder, activeSlot))
	char:SetAttribute("InRaid", holder ~= nil)
	local sq = ctx and ctx.Match and ctx.Match.squadOf(player)
	if sq then
		Chars.armband(char, sq.color)
	end
	hum.Died:Connect(function()
		Chars.ragdoll(char)
		if ctx and ctx.Raid then
			ctx.Raid.onDied(player, char)
		end
	end)
	return char
end

function Chars.ragdoll(char: Model)
	for _, m in char:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 and m.Name ~= "Root" then
			if m.Name == "WeaponGrip" then
				-- the weapon stays in the hand as it falls
				local w = Instance.new("WeldConstraint")
				w.Part0 = m.Part0
				w.Part1 = m.Part1
				w.Parent = m.Part1
				m:Destroy()
				continue
			end
			local a0 = Instance.new("Attachment")
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Attachment0 = a0
			bs.Attachment1 = a1
			bs.LimitsEnabled = true
			bs.UpperAngle = 45
			bs.TwistLimitsEnabled = true
			bs.TwistLowerAngle = -25
			bs.TwistUpperAngle = 25
			bs.Parent = m.Part0
			m:Destroy()
		end
	end
	for _, name in { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" } do
		local p = char:FindFirstChild(name)
		if p then
			p.CanCollide = true
			p.Massless = false
		end
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		root.CanCollide = false
	end
end

return Chars
