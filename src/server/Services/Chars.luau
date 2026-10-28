--!nonstrict
-- Characters: custom (non-default) operator look, gear visuals, spawning, ragdoll. No avatar items are loaded.
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local WeaponModels = require(Shared.WeaponModels)

local Chars = {}
local ctx

local LOOKS = {
	player = { torso = "5E6448", arms = "5E6448", legs = "474A3C", head = "4A4640", gear = "6B6A4E", helmet = "55593F" },
	guard = { torso = "3B4652", arms = "3B4652", legs = "2E343A", head = "2F3236", gear = "2B2F33", helmet = "1F2326" },
}

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
end

function Chars.description(kind: string): HumanoidDescription
	local look = LOOKS[kind] or LOOKS.player
	local d = Instance.new("HumanoidDescription")
	d.HeadColor = Color3.fromHex(look.head)
	d.TorsoColor = Color3.fromHex(look.torso)
	d.LeftArmColor = Color3.fromHex(look.arms)
	d.RightArmColor = Color3.fromHex(look.arms)
	d.LeftLegColor = Color3.fromHex(look.legs)
	d.RightLegColor = Color3.fromHex(look.legs)
	d.HeightScale = 1
	d.WidthScale = 0.9
	d.DepthScale = 0.92
	d.HeadScale = 0.9
	d.BodyTypeScale = 0.25
	d.ProportionScale = 0.5
	return d
end

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

local WEAPON_PARTS = { TPWeapon = true, TPSling = true, TPRifle = true }

local function buildInto(char, host, holder, it, cf, name)
	local b = WeaponModels.build(holder.items, it, cf, 1)
	if not b then
		return nil
	end
	local all = table.clone(b.parts)
	for _, p in b.mag do
		table.insert(all, p)
	end
	weldAll(all, host, char, name)
	return b
end

-- Third-person weapons: the active one in hand (low ready; M6 animator re-poses it with the arms), the other
-- long guns slung on the back. A tactical light on the active weapon follows the "WeaponLight" attribute.
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
	local it = holder and g and holder.items[g]
	if not torso then
		return
	end
	if it then
		local d = Items.defs[it.id]
		char:SetAttribute("ActiveWeapon", it.id)
		local grip = torso.CFrame * CFrame.new(0.38, -0.45, -0.55) * CFrame.Angles(math.rad(-10), math.rad(6), 0)
		if d.kind == "pistol" or d.kind == "melee" then
			grip = torso.CFrame * CFrame.new(0.55, -0.6, -0.55) * CFrame.Angles(math.rad(-35), 0, 0)
		end
		local b = buildInto(char, torso, holder, it, grip, "TPWeapon")
		if b and b.lightPart then
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
	else
		char:SetAttribute("ActiveWeapon", nil)
	end
	if not holder then
		return
	end
	-- long guns not in hand go on the back (two sling positions)
	local n = 0
	for _, slot in { "primary", "secondary" } do
		local lg = holder.slots[slot]
		local long = lg and lg ~= g and holder.items[lg]
		if long then
			n += 1
			local back = torso.CFrame * CFrame.new(n == 1 and 0.15 or -0.2, 0.1, 0.75 + n * 0.08) * CFrame.Angles(0, math.rad(180), math.rad(n == 1 and -55 or 55))
			buildInto(char, torso, holder, long, back, "TPSling")
		end
	end
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

local GEAR_PARTS = { Helmet = true, FacePlate = true, Visor = true, Cap = true, Vest = true, ArmGuard = true, Pouch = true, BodyCam = true, CamLens = true, Pack = true, Holster = true }

-- refresh visible gear after mid-raid equipment changes
function Chars.redress(char, holder, activeSlot)
	if not char then
		return
	end
	for _, c in char:GetChildren() do
		if GEAR_PARTS[c.Name] or WEAPON_PARTS[c.Name] then
			c:Destroy()
		end
	end
	Chars.dress(char, "player", Chars.gearOf(holder, activeSlot))
end

local PACK_SIZE = {
	BAG_SLING = Vector3.new(1.1, 1.2, 0.55), CANVAS_BAG = Vector3.new(1.55, 1.8, 0.8),
	BAG_PATROL = Vector3.new(1.8, 2.2, 1.0), BAG_RAID = Vector3.new(2.0, 2.6, 1.2),
}

-- gear = Chars.gearOf(holder) or nil (safehouse: no kit visible)
function Chars.dress(char, kind, gear)
	local look = LOOKS[kind] or LOOKS.player
	local gc = Color3.fromHex(look.gear)
	gear = gear or {}
	local helmet = gear.head and Items.defs[gear.head]
	if helmet then
		local cls = helmet.armor and helmet.armor.class or 2
		local hs = 1.28 + cls * 0.025
		attach(char, "Head", Vector3.new(hs, 0.6 + cls * 0.02, hs + 0.08), CFrame.new(0, 0.42, 0.03), Color3.fromHex(look.helmet), Enum.Material.SmoothPlastic, "Helmet")
		if helmet.armor and helmet.armor.face then
			attach(char, "Head", Vector3.new(1.05, 0.75, 0.16), CFrame.new(0, -0.02, -0.64), Color3.fromHex("2A2D2B"), Enum.Material.Metal, "FacePlate")
		else
			attach(char, "Head", Vector3.new(1.0, 0.24, 0.12), CFrame.new(0, 0.05, -0.62), Color3.fromHex("161819"), Enum.Material.SmoothPlastic, "Visor")
		end
	elseif kind == "player" then
		attach(char, "Head", Vector3.new(1.12, 0.3, 1.18), CFrame.new(0, 0.48, 0.05), Color3.fromHex("3E4236"), Enum.Material.Fabric, "Cap")
	end
	local armor = gear.armor and Items.defs[gear.armor]
	local rig = gear.rig and Items.defs[gear.rig]
	if armor then
		local cls = armor.armor.class
		attach(char, "UpperTorso", Vector3.new(2.0 + cls * 0.03, 1.5 + cls * 0.03, 1.2 + cls * 0.05), CFrame.new(0, 0.05, 0), gc, Enum.Material.Fabric, "Vest")
		if armor.armor.zones and armor.armor.zones.arms then
			for _, side in { "LeftUpperArm", "RightUpperArm" } do
				attach(char, side, Vector3.new(1.08, 0.9, 1.08), CFrame.new(0, 0.15, 0), gc, Enum.Material.Fabric, "ArmGuard")
			end
		end
	end
	if rig then
		local plate = rig.armor ~= nil
		if plate and not armor then
			attach(char, "UpperTorso", Vector3.new(2.05, 1.55, 1.3), CFrame.new(0, 0.05, 0), gc, Enum.Material.Fabric, "Vest")
		end
		local n = rig.grid and rig.grid.w or 3
		for i = 1, math.min(n, 4) do
			local x = (i - (math.min(n, 4) + 1) / 2) * 0.48
			attach(char, "UpperTorso", Vector3.new(0.44, 0.58, 0.3), CFrame.new(x, -0.25, -0.72 - (armor and 0.06 or 0)), gc, Enum.Material.Fabric, "Pouch")
		end
	end
	if kind == "player" then
		local cam = attach(char, "UpperTorso", Vector3.new(0.34, 0.42, 0.18), CFrame.new(-0.45, 0.35, -0.8), Color3.fromHex("1A1C1D"), Enum.Material.SmoothPlastic, "BodyCam")
		if cam then
			local lens = attach(char, "UpperTorso", Vector3.new(0.14, 0.14, 0.05), CFrame.new(-0.45, 0.42, -0.91), Color3.fromHex("C24A35"), Enum.Material.Neon, "CamLens")
			if lens then
				lens.CastShadow = false
			end
		end
	end
	if gear.back then
		local size = PACK_SIZE[gear.back] or PACK_SIZE.CANVAS_BAG
		attach(char, "UpperTorso", size, CFrame.new(0, 0.1 - (size.Y - 1.8) * 0.3, 0.62 + size.Z * 0.5), Color3.fromHex("6B6A4E"), Enum.Material.Fabric, "Pack")
	end
	if gear.holder then
		Chars.setWeapon(char, gear.holder, gear.activeG)
	end
	if gear.holster then
		attach(char, "LowerTorso", Vector3.new(0.22, 0.5, 0.42), CFrame.new(0.72, -0.1, 0), Color3.fromHex("23262A"), Enum.Material.SmoothPlastic, "Holster")
	end
	local head = char:FindFirstChild("Head")
	if head then
		for _, d in head:GetChildren() do
			if d:IsA("Decal") then
				d:Destroy()
			end
		end
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

-- Spawns (or respawns) a player's character at cf. holder: raid inventory (for gear visuals) or nil.
function Chars.spawn(player: Player, cf: CFrame, holder: any?, activeSlot: string?)
	if not player.Parent then
		return nil
	end
	local ok, err = pcall(function()
		player:LoadCharacterWithHumanoidDescription(Chars.description("player"))
	end)
	if not ok then
		warn("[ZR] character load failed", err)
		player:LoadCharacter()
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
			player = player, kind = "player", inRaid = holder ~= nil, saved = prof and prof.health,
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
	Chars.dress(char, "player", Chars.gearOf(holder, activeSlot))
	char:SetAttribute("InRaid", holder ~= nil)
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
	for _, p in char:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and not p.Massless then
			p.CanCollide = true
		end
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		root.CanCollide = false
	end
end

return Chars
