--!nonstrict
-- Bodycam post-processing (client-only, never replicated): camera grade, bloom, sun rays, depth haze,
-- turn blur, auto-exposure (indoor/outdoor adaptation with overshoot), film grain + lens overlays,
-- damage/pain flashes and muzzle exposure bursts. Settings-aware and quality-gated.
-- Bodycam lens (owner request): Roblox has no custom shaders, so the wide-angle lens is layered textures:
-- a light feathered vignette and a soft low-contrast edge haze tinted to the scene (reads as edge blur). The
-- haze grows when the camera turns or sprints (real BlurEffect joins in on fast turns) and eases off while
-- aiming. No colour fringing (the owner tried it and asked for it to be removed). Cheap full-screen images.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Textures = require(Shared.Textures)

-- envExposure / grainMul are driven by Atmos (night: brighter auto-gain and heavier sensor noise)
-- smoke (0..1) is set by the Grenade controller while the camera is inside a cloud
local Post = {
	dmg = 0, pain = 0, burstAmt = 0, low = 0, envExposure = 0, grainMul = 1, flash = 0, smoke = 0,
	nvExposure = 0, nvGrain = 1, nvBloom = 0, -- set by NightVision while goggles are down
	lum = 1, hazeTint = Color3.fromRGB(64, 70, 68), -- set by Atmos from the light and fog
}
local ctx
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local gui, grainA, grainB, lens, red, tunnel, haze, white, veil
local whiteOut = { amt = 0, t0 = 0, dur = 1 }
local concussion = { amt = 0, untilT = 0, span = 1 }
local lensMotion, lensAim = 0, 0
local fx = {}
local exposure, indoor, indoorTarget = 0.1, 0, 0
local lastLook, turnBlur = nil, 0
local grainClock, probeClock = 0, 0
local baseExposure = 0.1
local grainBase, grainShown = 0.5, -1
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
	Post.gui = gui
	tunnel = overlay("Tunnel", Textures.LENS, 1)
	tunnel.ImageColor3 = Color3.new(0, 0, 0)
	tunnel.ImageTransparency = 1
	-- lens stack: edge haze (2) -> [rain drops 4, Atmos] -> vignette (5)
	if Textures.EDGE_HAZE ~= "" then
		haze = overlay("LensHaze", Textures.EDGE_HAZE, 2)
	end
	lens = overlay("Lens", Textures.VIGNETTE ~= "" and Textures.VIGNETTE or Textures.LENS, 5)
	lens.ImageColor3 = Color3.new(0, 0, 0) -- darkening only: no colour at the edges
	if Textures.VIGNETTE == "" then
		lens.ImageTransparency = 0.35 -- fallback: the older lens texture is a heavy tunnel, keep it lighter
	else
		lens.ImageTransparency = 0 -- the new vignette texture is authored at the intended (lighter) strength
	end
	-- smoke veil (3): inside a smoke cloud the picture greys out
	veil = Instance.new("Frame")
	veil.Name = "SmokeVeil"
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromRGB(150, 154, 150)
	veil.BackgroundTransparency = 1
	veil.ZIndex = 3
	veil.Parent = gui
	-- stun charge white-out (9, over the grain): the sensor saturates
	white = Instance.new("Frame")
	white.Name = "WhiteOut"
	white.BorderSizePixel = 0
	white.Size = UDim2.fromScale(1, 1)
	white.BackgroundColor3 = Color3.fromRGB(255, 255, 252)
	white.BackgroundTransparency = 1
	white.ZIndex = 9
	white.Parent = gui
	red = overlay("Hurt", Textures.LENS, 6)
	red.ImageColor3 = Color3.fromRGB(150, 12, 8)
	red.ImageTransparency = 1
	for i, name in { "GrainA", "GrainB" } do
		local g = overlay(name, Textures.GRAIN, 6 + i)
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
	-- depth of field (HIGH) blurs only what is beyond ~100 studs; under a roof nothing is that far, so it is off
	-- indoors (it is the most expensive post effect, ~5 ms a frame on an integrated GPU at full quality)
	fx.dof.Enabled = q >= 3 and indoorTarget < 0.6
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Enabled = q >= 2
		bloom.Intensity = 0.55
		bloom.Size = 26
		bloom.Threshold = 1.2
	end
	lens.Visible = S.lens ~= false
	if haze then
		haze.Visible = S.lens ~= false
	end
	local g = math.clamp(S.grain or 0.5, 0, 1)
	grainA.Visible = g > 0.01
	grainB.Visible = g > 0.01 and q >= 2
	local tile = math.floor(300 * math.max(gui.AbsoluteSize.Y / 1080, 0.5))
	for _, l in { grainA, grainB } do
		l.TileSize = UDim2.fromOffset(tile, tile)
		l.Size = UDim2.new(1, tile, 1, tile)
	end
	grainBase = g
	grainShown = -1
end

local function updateGrain()
	-- grain halved on owner request (setting 0.5 -> ~15% opacity by day, ~21% at night)
	local base = Post.nvGrain > 1 and math.max(grainBase, 0.6) or grainBase -- a tube's noise shows whatever the setting
	local a = math.clamp(base * 0.3 * Post.grainMul * Post.nvGrain, 0, 0.6)
	if math.abs(a - grainShown) > 0.004 then
		grainShown = a
		grainA.ImageTransparency = 1 - a
		grainB.ImageTransparency = 1 - a
	end
end

-- muzzle flash / explosion: brief exposure + bloom spike
function Post.burst(amount)
	Post.burstAmt = math.max(Post.burstAmt, amount or 0.25)
end

function Post.hurt(amount)
	Post.dmg = math.clamp(math.max(Post.dmg, amount or 0.5), 0, 1)
end

-- stun charge: full white that holds, then fades (strength 0..1, seconds)
function Post.whiteout(amount, dur)
	if amount <= 0.02 then
		return
	end
	local cur = Post.whiteLevel()
	if amount >= cur then
		whiteOut.amt, whiteOut.t0, whiteOut.dur = amount, os.clock(), math.max(0.3, dur)
	end
	Post.flash = math.max(Post.flash, amount)
end

function Post.whiteLevel()
	local p = (os.clock() - whiteOut.t0) / whiteOut.dur
	if p >= 1 or p < 0 then
		return 0
	end
	local hold = 0.35
	if p < hold then
		return whiteOut.amt
	end
	local k = 1 - (p - hold) / (1 - hold)
	return whiteOut.amt * k * k
end

-- blast concussion (Tarkov contusion): blur, washed-out colour, a darker picture
function Post.concuss(amount, dur)
	amount = math.clamp(amount or 0, 0, 1)
	local left = concussion.untilT - os.clock()
	local cur = left > 0 and concussion.amt * math.clamp(left / concussion.span, 0, 1) or 0
	if amount > cur then
		concussion.amt, concussion.untilT, concussion.span = amount, os.clock() + dur, math.min(dur, 3)
	end
end

local function concussLevel()
	local left = concussion.untilT - os.clock()
	if left <= 0 then
		return 0
	end
	return concussion.amt * math.clamp(left / concussion.span, 0, 1)
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
	if Post.frozen then
		return -- Studio capture mode (dev bridge "studio")
	end
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
	local target = (S.mblur ~= false and (S.quality or 3) > 0) and math.clamp((ang - 2.6) * 1.15, 0, 4.5) or 0 -- no turn blur on POTATO
	turnBlur += (target - turnBlur) * math.min(1, dt * 14)
	-- auto-exposure: adapt slowly, so walking out of a building overexposes for a moment
	probeClock += dt
	if probeClock > 0.25 then
		probeClock = 0
		probeIndoor()
	end
	indoor += (indoorTarget - indoor) * math.min(1, dt * 0.9)
	Post.indoor = indoor
	local wantDof = (S.quality or 2) >= 3 and indoorTarget < 0.6
	if fx.dof.Enabled ~= wantDof then
		fx.dof.Enabled = wantDof
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	Post.burstAmt = math.max(0, Post.burstAmt - dt * 4)
	Post.flash = math.max(0, Post.flash - dt * 5)
	updateGrain()
	exposure = baseExposure + Post.envExposure + indoor * 0.55 + Post.burstAmt * 0.6 + Post.flash * 2.2 + Post.nvExposure
	Lighting.ExposureCompensation = exposure
	if bloom and bloom.Enabled then
		bloom.Intensity = 0.55 + Post.burstAmt * 1.2 + Post.nvBloom
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
	local cz = concussLevel()
	local wl = Post.whiteLevel()
	white.BackgroundTransparency = 1 - math.clamp(wl, 0, 1)
	local sm = math.clamp(Post.smoke, 0, 1)
	veil.BackgroundTransparency = 1 - sm * 0.82
	if sm > 0.01 then
		veil.BackgroundColor3 = Color3.fromRGB(150, 154, 150):Lerp(Post.hazeTint, 0.35):Lerp(Color3.new(0, 0, 0), math.clamp(1 - Post.lum, 0, 0.8))
	end
	fx.grade.Saturation = -0.1 - low * 0.45 - Post.pain * 0.15 - cz * 0.45
	fx.grade.Contrast = 0.14 + Post.pain * 0.08 - cz * 0.1
	fx.grade.TintColor = Color3.fromRGB(236, 243, 235):Lerp(Color3.fromRGB(255, 214, 205), Post.dmg * 0.6)
	fx.grade.Brightness = -0.015 - cz * 0.06
	fx.blur.Size = math.max(turnBlur, Post.dmg * 6, Post.pain * 2, cz * 14, wl * 10)
	-- lens: the soft edge grows with motion and eases off while aiming down sights
	local M, W = ctx.Movement, ctx.Weapon
	local moving = math.clamp(turnBlur / 3 + ((M and M.sprinting) and 0.45 or 0), 0, 1)
	lensMotion += (moving - lensMotion) * math.min(1, dt * 5)
	lensAim += (((W and W.aiming) and 1 or 0) - lensAim) * math.min(1, dt * 7)
	if haze then
		haze.ImageColor3 = Post.hazeTint
		haze.ImageTransparency = 1 - math.clamp(0.82 + 0.3 * lensMotion - 0.35 * lensAim + Post.dmg * 0.2, 0, 1)
	end
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
