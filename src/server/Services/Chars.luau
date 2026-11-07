--!nonstrict
-- Characters: the operator rig (our own R15-named Motor6D skeleton; body version ZR_BLOCK_R15_V1 = the owner's
-- Roblox block proportions, Blender body meshes with a part-built fallback) used by players (StarterCharacter)
-- and AI; worn gear through the Appearance service (Equipment definitions); the weapon in hand
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

local Equipment = require(Shared.Equipment)

local Chars = {}
local ctx

-- outfits live in Equipment.LOOKS (shared with the client's first-person sleeves); body part -> cloth key
Chars.LOOKS = Equipment.LOOKS
Chars.CLOTH = Equipment.CLOTH
local COLLIDE = { UpperTorso = true, LowerTorso = true, Head = true }
local WEAPON_PARTS = { TPWeapon = true, TPSling = true, TPRifle = true, WeaponRoot = true }

-- ── rig ──────────────────────────────────────────────────────────────────────
function Chars.buildRig(kind, variant)
	local look = Equipment.lookOf(kind, variant)
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
	local lib = game:GetService("ServerStorage"):FindFirstChild("ZR_Assets")
	for name, spec in RigSpec.parts do
		local mesh = lib and lib:FindFirstChild("ZR_BLK_" .. name)
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
		local cloth = Equipment.CLOTH[name]
		p.Color = Color3.fromHex(look[cloth] or "808080")
		p.Material = (cloth == "skin" or cloth == "boot") and Enum.Material.SmoothPlastic or Enum.Material.Fabric
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
	model:SetAttribute("BodyVersion", RigSpec.bodyVersion)
	model:SetAttribute("Look", Equipment.lookKey(kind))
	model:SetAttribute("LookVariant", variant or 1)
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
-- Worn equipment is built by the Appearance service from Equipment definitions (M16). The helper below only
-- makes the squad armbands: the band mesh when the gear batch loaded, a plain band otherwise.
local function band(char, partName, color)
	local host = char:FindFirstChild(partName)
	if not host then
		return nil
	end
	local lib = game:GetService("ServerStorage"):FindFirstChild("ZR_Assets")
	local src = lib and lib:FindFirstChild("ZR_OV_Armband")
	local p
	if src then
		p = src:Clone()
	else
		p = Instance.new("Part")
		p.Size = Vector3.new(1.09, 0.22, 1.09)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
	end
	p.Name = "Armband"
	p.Color = color
	p.Material = Enum.Material.Fabric
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	-- squad bands sit on the lower half of the upper arm (a guard's faction band uses the upper half)
	p.CFrame = host.CFrame * CFrame.new(0, -0.2, 0)
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
		local b = WeaponModels.build(holder.items, it, root.CFrame, WeaponModels.TP_SCALE)
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
			if b.laserPart then
				-- where every client's LaserFx starts this gun's beam (the part itself is renamed with the rest)
				local a = Instance.new("Attachment")
				a.Name = "LaserEmitter"
				a.Parent = b.laserPart
			end
		end
	else
		char:SetAttribute("ActiveWeapon", nil)
	end
	if ctx and ctx.Appearance then
		ctx.Appearance.noteWeapon(char, holder, g)
	end
	if holder then
		-- long guns not in hand go on the back (two sling positions), over whatever is worn there (pack, plates)
		local backZ = Equipment.backExtent(Equipment.resolve(Equipment.stateOf(holder, char:GetAttribute("Look"), char:GetAttribute("LookVariant"))))
		local n = 0
		for _, slot in { "primary", "secondary" } do
			local lg = holder.slots[slot]
			local long = lg and lg ~= g and holder.items[lg]
			if long then
				n += 1
				-- flat across the back, muzzle up over one shoulder, stock toward the other hip (barrel = -Z of
				-- the weapon spec, its top facing away from the back)
				local sx = n == 1 and 1 or -1
				local zAxis = -Vector3.new(sx * math.sin(math.rad(40)), math.cos(math.rad(40)), 0)
				local yAxis = Vector3.zAxis
				local back = torso.CFrame * CFrame.fromMatrix(Vector3.new(-sx * 0.1, -0.15, backZ + 0.12 + n * 0.1), yAxis:Cross(zAxis), yAxis, zAxis)
				local bb = WeaponModels.build(holder.items, long, back, WeaponModels.TP_SCALE)
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

-- refresh visible gear after mid-raid equipment changes (per-slot diff, see Appearance)
function Chars.redress(char, holder, activeSlot, kind)
	if not char then
		return
	end
	local gear = Chars.gearOf(holder, activeSlot)
	ctx.Appearance.apply(char, { look = kind or char:GetAttribute("Look"), holder = holder, active = gear and gear.activeG })
end

-- gear = Chars.gearOf(holder) or nil (no kit visible)
function Chars.dress(char, kind, gear)
	ctx.Appearance.apply(char, { look = kind, holder = gear and gear.holder, active = gear and gear.activeG })
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
		band(char, side, Color3.fromHex(color))
	end
end

-- clothing colours for a faction look (player scavs wear scav clothes)
function Chars.recolor(char, kind)
	local look = Equipment.lookOf(kind, char:GetAttribute("LookVariant"))
	for name, cloth in Equipment.CLOTH do
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
		pitch = math.rad(st.pitch or char:GetAttribute("Pitch") or 0), neckUp = char:GetAttribute("NeckUp"), hold = hold, mode = mode, weapon = anchors,
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
	char:SetAttribute("TP", os.clock()) -- the movement guard takes this as a server teleport
	char:SetAttribute("Stance", "s")
	char:SetAttribute("Lean", 0)
	char:SetAttribute("Pitch", 0)
	local kind = opts.scav and "scav" or "player"
	char:SetAttribute("Scav", opts.scav == true)
	local variant = opts.scav and math.random(1, Equipment.variants("scav")) or 1
	if holder then
		local gear = Chars.gearOf(holder, activeSlot)
		ctx.Appearance.apply(char, { look = kind, variant = variant, holder = holder, active = gear and gear.activeG })
	else
		-- safehouse: the profile's worn kit (what the next raid will look like), no weapons
		local h = ctx.Raid and ctx.Raid.holder(player)
		ctx.Appearance.apply(char, { look = kind, variant = variant, holder = h, weapons = false })
	end
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
	-- once the body has settled it is anchored where it lies (audit tech.11): a field of bodies costs no physics, and
	-- nothing can knock one around afterwards (looting reads the corpse's container, not its parts)
	task.delay(Chars.SETTLE_TIME, function()
		if char.Parent then
			for _, p in char:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = true
				end
			end
		end
	end)
end
Chars.SETTLE_TIME = 5

return Chars
