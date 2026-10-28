--!nonstrict
-- Bodycam post-processing (client-only, never replicated): camera grade, bloom, sun rays, depth haze,
-- turn blur, auto-exposure (indoor/outdoor adaptation with overshoot), film grain + lens overlays,
-- damage/pain flashes and muzzle exposure bursts. Settings-aware and quality-gated.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Textures = require(Shared.Textures)

local Post = { dmg = 0, pain = 0, burstAmt = 0, low = 0 }
local ctx
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local gui, grainA, grainB, lens, red, tunnel
local fx = {}
local exposure, indoor, indoorTarget = 0.1, 0, 0
local lastLook, turnBlur = nil, 0
local grainClock, probeClock = 0, 0
local baseExposure = 0.1
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function effect(class, name)
	local e = Lighting:FindFirstChild(name)
	if not (e and e:IsA(class)) then
		e = Instance.new(class)
		e.Name = name
		e.Parent = Lighting
	end
	return e
end

local function overlay(name, image, z)
	local l = Instance.new("ImageLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Image = image
	l.Size = UDim2.fromScale(1, 1)
	l.ZIndex = z
	l.Parent = gui
	return l
end

local function build()
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("ZR_Bodycam")
	if old then
		old:Destroy()
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "ZR_Bodycam"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = pg
	tunnel = overlay("Tunnel", Textures.LENS, 1)
	tunnel.ImageColor3 = Color3.new(0, 0, 0)
	tunnel.ImageTransparency = 1
	lens = overlay("Lens", Textures.LENS, 2)
	red = overlay("Hurt", Textures.LENS, 3)
	red.ImageColor3 = Color3.fromRGB(150, 12, 8)
	red.ImageTransparency = 1
	for i, name in { "GrainA", "GrainB" } do
		local g = overlay(name, Textures.GRAIN, 4 + i)
		g.ScaleType = Enum.ScaleType.Tile
		if i == 1 then
			grainA = g
		else
			grainB = g
			g.Rotation = 180
		end
	end
	fx.grade = effect("ColorCorrectionEffect", "ZR_Cam")
	fx.blur = effect("BlurEffect", "ZR_CamBlur")
	fx.rays = effect("SunRaysEffect", "ZR_CamRays")
	fx.dof = effect("DepthOfFieldEffect", "ZR_CamDoF")
	fx.blur.Size = 0
	fx.rays.Intensity = 0.045
	fx.rays.Spread = 0.85
	fx.dof.FarIntensity = 0.14
	fx.dof.FocusDistance = 30
	fx.dof.InFocusRadius = 70
	fx.dof.NearIntensity = 0
end

function Post.apply()
	local S = ctx.Settings.data
	local q = S.quality or 2
	fx.rays.Enabled = q >= 2
	fx.dof.Enabled = q >= 3
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Enabled = q >= 2
		bloom.Intensity = 0.55
		bloom.Size = 26
		bloom.Threshold = 1.2
	end
	lens.Visible = S.lens ~= false
	local g = math.clamp(S.grain or 0.6, 0, 1)
	grainA.Visible = g > 0.01
	grainB.Visible = g > 0.01 and q >= 2
	local tile = math.floor(300 * math.max(gui.AbsoluteSize.Y / 1080, 0.5))
	for _, l in { grainA, grainB } do
		l.TileSize = UDim2.fromOffset(tile, tile)
		l.Size = UDim2.new(1, tile, 1, tile)
		l.ImageTransparency = 1 - g * 0.5
	end
end

-- muzzle flash / explosion: brief exposure + bloom spike
function Post.burst(amount)
	Post.burstAmt = math.max(Post.burstAmt, amount or 0.25)
end

function Post.hurt(amount)
	Post.dmg = math.clamp(math.max(Post.dmg, amount or 0.5), 0, 1)
end

local function probeIndoor()
	local char = player.Character
	local fxFolder = workspace:FindFirstChild("ZR_Fx")
	rayParams.FilterDescendantsInstances = { char, fxFolder }
	local origin = cam.CFrame.Position
	local score = 0
	if workspace:Raycast(origin, Vector3.new(0, 70, 0), rayParams) then
		score += 0.6
	end
	for _, d in { Vector3.new(30, 6, 0), Vector3.new(-30, 6, 0), Vector3.new(0, 6, 30), Vector3.new(0, 6, -30) } do
		if workspace:Raycast(origin, d, rayParams) then
			score += 0.1
		end
	end
	indoorTarget = math.clamp(score, 0, 1)
end

local function step(dt)
	local S = ctx.Settings.data
	-- grain: re-seed position at ~24 fps (film cadence)
	grainClock += dt
	if grainClock > 1 / 24 then
		grainClock = 0
		local t = grainA.TileSize.X.Offset
		grainA.Position = UDim2.fromOffset(-math.random(0, t), -math.random(0, t))
		grainB.Position = UDim2.fromOffset(-math.random(0, t), -math.random(0, t))
	end
	-- turn blur from camera angular speed
	local look = cam.CFrame.LookVector
	local ang = 0
	if lastLook and dt > 0 then
		ang = math.acos(math.clamp(look:Dot(lastLook), -1, 1)) / dt
	end
	lastLook = look
	local target = (S.mblur ~= false) and math.clamp((ang - 2.6) * 1.15, 0, 4.5) or 0
	turnBlur += (target - turnBlur) * math.min(1, dt * 14)
	-- auto-exposure: adapt slowly, so walking out of a building overexposes for a moment
	probeClock += dt
	if probeClock > 0.25 then
		probeClock = 0
		probeIndoor()
	end
	indoor += (indoorTarget - indoor) * math.min(1, dt * 0.9)
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	Post.burstAmt = math.max(0, Post.burstAmt - dt * 4)
	exposure = baseExposure + indoor * 0.55 + Post.burstAmt * 0.6
	Lighting.ExposureCompensation = exposure
	if bloom and bloom.Enabled then
		bloom.Intensity = 0.55 + Post.burstAmt * 1.2
	end
	-- damage / pain / low health (from the server health model)
	local v = ctx.State.vitals
	local tgtPain, tgtLow = 0, 0
	if v and v.max and v.max > 0 then
		tgtLow = math.clamp((0.42 - v.hp / v.max) / 0.42, 0, 1)
		tgtPain = (v.mods and v.mods.tremor or 0) > 0 and 1 or 0
	end
	Post.pain += (tgtPain - Post.pain) * math.min(1, dt * 1.5)
	Post.low += (tgtLow - Post.low) * math.min(1, dt * 2)
	Post.dmg = math.max(0, Post.dmg - dt * 1.3)
	red.ImageTransparency = 1 - Post.dmg * 0.85
	local low = Post.low
	tunnel.ImageTransparency = 1 - math.clamp(Post.pain * 0.55 + low * 0.45, 0, 0.8)
	fx.grade.Saturation = -0.1 - low * 0.45 - Post.pain * 0.15
	fx.grade.Contrast = 0.14 + Post.pain * 0.08
	fx.grade.TintColor = Color3.fromRGB(236, 243, 235):Lerp(Color3.fromRGB(255, 214, 205), Post.dmg * 0.6)
	fx.grade.Brightness = -0.015
	fx.blur.Size = math.max(turnBlur, Post.dmg * 6, Post.pain * 2)
end

function Post.init(c)
	ctx = c
	build()
	baseExposure = Lighting:GetAttribute("BaseExposure") or 0.1
	Lighting:GetAttributeChangedSignal("BaseExposure"):Connect(function()
		baseExposure = Lighting:GetAttribute("BaseExposure") or 0.1
	end)
	c.Settings.changed:Connect(Post.apply)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(Post.apply)
	Post.apply()
	c.State.on("dmg", function(d)
		Post.hurt(math.clamp((d.amt or 10) / 35, 0.3, 1))
		ctx.Camera.flinch((d.amt or 10) / 20)
	end)
	RunService:BindToRenderStep("ZR_Post", Enum.RenderPriority.Camera.Value + 5, step)
end

return Post
