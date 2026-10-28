--!nonstrict
-- Characters: custom (non-default) operator look, gear visuals, spawning, ragdoll. No avatar items are loaded.
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Config = require(Shared.Config)
local AssetMeta = require(Shared.AssetMeta)

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

-- Third-person rifle silhouette (mesh if uploaded, else parts) carried at low-ready on the torso.
local function rifle(char, color)
	local torso = char:FindFirstChild("UpperTorso")
	if not torso then
		return
	end
	local lib = ReplicatedStorage:FindFirstChild("ZR_Assets")
	local meshRifle = lib and lib:FindFirstChild("ZR_WPN_R17_TP")
	local base = torso.CFrame * CFrame.new(0.45, -0.25, -1.05) * CFrame.Angles(math.rad(-8), math.rad(4), 0)
	local parts = {}
	if meshRifle then
		local m = meshRifle:Clone()
		local s = 0.7 -- uploaded at 1.15x viewmodel proportions; carbine ~2.8 studs on a ~5.5 stud operator
		m.Size *= s
		local grip = torso.CFrame * CFrame.new(0.38, -0.45, -0.5) * CFrame.Angles(math.rad(-10), math.rad(6), 0)
		m.CFrame = grip * CFrame.new(AssetMeta.ZR_WPN_R17_TP * s)
		table.insert(parts, m)
	else
		local function seg(sx, sy, sz, ox, oy, oz, col)
			local p = Instance.new("Part")
			p.Size = Vector3.new(sx, sy, sz)
			p.CFrame = base * CFrame.new(ox, oy, oz)
			p.Color = col
			p.Material = Enum.Material.Metal
			table.insert(parts, p)
		end
		local dark, mid = Color3.fromHex("2B2F2D"), color or Color3.fromHex("55605A")
		seg(0.32, 0.42, 1.6, 0, 0, 0, dark)
		seg(0.18, 0.18, 1.3, 0, 0.05, -1.4, dark)
		seg(0.3, 0.32, 0.9, 0, 0.02, -0.75, mid)
		seg(0.22, 0.55, 0.28, 0, -0.42, 0.05, dark)
		seg(0.24, 0.36, 0.9, 0, -0.05, 1.1, mid)
	end
	for _, p in parts do
		p.Name = "TPRifle"
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = torso
		w.Part1 = p
		w.Parent = p
		p.Parent = char
	end
end

-- gear: {bag = bool, rifle = bool}
function Chars.dress(char, kind, gear)
	local look = LOOKS[kind] or LOOKS.player
	local gc = Color3.fromHex(look.gear)
	attach(char, "Head", Vector3.new(1.32, 0.62, 1.42), CFrame.new(0, 0.42, 0.02), Color3.fromHex(look.helmet), Enum.Material.SmoothPlastic, "Helmet")
	attach(char, "Head", Vector3.new(1.0, 0.24, 0.12), CFrame.new(0, 0.05, -0.62), Color3.fromHex("161819"), Enum.Material.SmoothPlastic, "Visor")
	attach(char, "UpperTorso", Vector3.new(2.05, 1.55, 1.3), CFrame.new(0, 0.05, 0), gc, Enum.Material.Fabric, "Vest")
	for i = -1, 1 do
		attach(char, "UpperTorso", Vector3.new(0.5, 0.6, 0.3), CFrame.new(i * 0.6, -0.25, -0.75), gc, Enum.Material.Fabric, "Pouch")
	end
	if kind == "player" then
		local cam = attach(char, "UpperTorso", Vector3.new(0.34, 0.42, 0.18), CFrame.new(-0.45, 0.35, -0.75), Color3.fromHex("1A1C1D"), Enum.Material.SmoothPlastic, "BodyCam")
		if cam then
			local lens = attach(char, "UpperTorso", Vector3.new(0.14, 0.14, 0.05), CFrame.new(-0.45, 0.42, -0.86), Color3.fromHex("C24A35"), Enum.Material.Neon, "CamLens")
			if lens then
				lens.CastShadow = false
			end
		end
	end
	if gear and gear.bag then
		attach(char, "UpperTorso", Vector3.new(1.6, 1.9, 0.85), CFrame.new(0, 0, 1.05), Color3.fromHex("6B6A4E"), Enum.Material.Fabric, "Pack")
	end
	if gear and gear.rifle then
		rifle(char, nil)
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
function Chars.spawn(player: Player, cf: CFrame, holder: any?)
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
	local regen = char:FindFirstChild("Health")
	if regen and regen:IsA("Script") then
		regen:Destroy()
	end
	char:PivotTo(cf)
	Chars.dress(char, "player", holder and { bag = holder.slots.bag ~= nil, rifle = holder.slots.primary ~= nil } or nil)
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
