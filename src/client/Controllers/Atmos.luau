--!nonstrict
-- Raid atmosphere (M10, client-only): lights the raid from its time of day and weather (shared Env, rolled by
-- the server per raid), runs the rain (streaks around the camera that stop under roofs, splashes, droplets on
-- the bodycam lens, rain on the roof indoors), wind, distant thunder with lightning, street lamps that switch on
-- in the dark, and day/night ambience (gulls by day, insects at night). The hideout keeps its indoor lighting.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Env = require(Shared.Env)
local Textures = require(Shared.Textures)

local Atmos = { env = nil, mode = nil, rain = 0, dark = 0, cover = 0 }
local ctx
local cam = workspace.CurrentCamera

local function lerp(a, b, t)
	return a + (b - a) * t
end
local function lerpC(a, b, t)
	return a:Lerp(b, math.clamp(t, 0, 1))
end
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- ── lighting targets ─────────────────────────────────────────────────────────
local hideout -- captured from the server's lighting at start (the safehouse look)
local atm, clouds, grade

local function capture()
	atm = Lighting:FindFirstChildOfClass("Atmosphere")
	clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	grade = Lighting:FindFirstChild("ZR_Grade")
	hideout = {
		ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
		ColorShift_Top = Lighting.ColorShift_Top, EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
		atmDensity = atm and atm.Density or 0.4, atmOffset = atm and atm.Offset or 0.2, atmColor = atm and atm.Color or rgb(170, 180, 178),
		atmDecay = atm and atm.Decay or rgb(92, 106, 105), atmGlare = atm and atm.Glare or 0, atmHaze = atm and atm.Haze or 2,
		cloudCover = clouds and clouds.Cover or 0.8, cloudDensity = clouds and clouds.Density or 0.6, cloudColor = clouds and clouds.Color or rgb(199, 205, 203),
		gradeSat = grade and grade.Saturation or -0.2, gradeContrast = grade and grade.Contrast or 0.08, gradeTint = grade and grade.TintColor or rgb(236, 239, 232),
		exposure = 0, grain = 1, wind = Vector3.new(4, 0, 2),
	}
end

-- what the raid should look like at in-world hour h under weather w (rain intensity r)
local function raidTargets(e, now)
	local w = Env.WEATHER[e.w] or Env.WEATHER.clear
	local h = Env.clock(e, now)
	local d = Env.daylight(h)
	local gold = Env.golden(h) * lerp(0.35, 1, w.light)
	local sun = d * w.light
	local rain = e.rain or 0
	local t = {}
	t.ClockTime = h
	t.Brightness = lerp(0.55, 2.0, d) * lerp(0.6, 1, w.light)
	-- outdoor fill (Roblox lights in linear space, so the night fill has to be high to read at all): day
	-- grey-green, overcast flatter; night moonlit blue-grey (darker without a moon behind cloud); dusk warm.
	-- Tuned in Studio: night ~ a grainy auto-gain bodycam, dark but readable.
	local dayAmb = lerpC(rgb(104, 110, 113), rgb(124, 133, 131), w.light)
	local nightAmb = lerpC(rgb(92, 98, 112), rgb(146, 156, 178), w.light)
	t.OutdoorAmbient = lerpC(lerpC(nightAmb, dayAmb, d), rgb(150, 124, 108), gold * 0.35)
	-- indoor fill (sky occluded): dim but readable rooms by day, darker at night (lamps and lights matter)
	t.Ambient = lerpC(rgb(66, 70, 80), rgb(96, 100, 102), d)
	t.ColorShift_Top = lerpC(rgb(0, 0, 0), rgb(255, 172, 118), gold * 0.55)
	t.EnvironmentDiffuseScale = lerp(0.25, 0.55, d)
	t.EnvironmentSpecularScale = 0.25 + rain * 0.6
	-- atmosphere (fog colour follows the light; fog weather pulls it in close)
	local dayFog = lerpC(rgb(150, 158, 160), rgb(169, 180, 177), w.light)
	local nightFog = rgb(58, 64, 74)
	t.atmColor = lerpC(lerpC(nightFog, dayFog, d), rgb(196, 158, 128), gold * 0.45)
	t.atmDecay = lerpC(lerpC(rgb(26, 30, 38), rgb(93, 106, 105), d), rgb(122, 88, 74), gold * 0.45)
	t.atmDensity = w.fog + (1 - d) * 0.05
	t.atmOffset = (e.w == "fog") and 0.04 or 0.18
	t.atmGlare = (e.w == "clear") and gold * 1.4 or 0
	t.atmHaze = w.haze
	t.cloudCover = w.clouds
	t.cloudDensity = w.cloudDensity
	t.cloudColor = lerpC(lerpC(rgb(52, 56, 64), rgb(199, 205, 203), d * lerp(0.65, 1, w.light)), rgb(222, 168, 136), gold * 0.5)
	-- grade: night cool and desaturated, rain cold, dusk warm
	t.gradeSat = lerp(-0.46, -0.22, d) - rain * 0.08
	t.gradeContrast = lerp(0.13, 0.08, d)
	local tint = lerpC(rgb(186, 204, 230), rgb(236, 239, 232), d)
	tint = lerpC(tint, rgb(255, 226, 202), gold * 0.5)
	t.gradeTint = lerpC(tint, rgb(220, 229, 236), rain * 0.5)
	-- bodycam auto-gain lifts dark scenes (and their noise)
	t.exposure = lerp(0.62, 0, d) + (1 - sun) * 0.1
	t.grain = lerp(1.4, 1, d)
	t.wind = Vector3.new(w.wind * 14, 0, w.wind * 7)
	return t, d, h
end

local NUM = { "ClockTime", "Brightness", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" }
local COL = { "Ambient", "OutdoorAmbient", "ColorShift_Top" }
local cur -- smoothed values actually applied

local function blend(target, k)
	if not cur or k >= 1 then
		cur = table.clone(target)
	else
		for key, v in target do
			local c = cur[key]
			if type(v) == "number" then
				if key == "ClockTime" then
					-- wrap-aware approach (23.9 -> 0.1)
					local dlt = ((v - c + 12) % 24) - 12
					cur[key] = (c + dlt * k) % 24
				else
					cur[key] = lerp(c, v, k)
				end
			elseif typeof(v) == "Color3" then
				cur[key] = c:Lerp(v, k)
			elseif typeof(v) == "Vector3" then
				cur[key] = c:Lerp(v, k)
			end
		end
	end
	for _, key in NUM do
		Lighting[key] = cur[key]
	end
	for _, key in COL do
		Lighting[key] = cur[key]
	end
	if atm then
		atm.Density, atm.Offset, atm.Color, atm.Decay, atm.Glare, atm.Haze = cur.atmDensity, cur.atmOffset, cur.atmColor, cur.atmDecay, cur.atmGlare, cur.atmHaze
	end
	if clouds then
		clouds.Cover, clouds.Density, clouds.Color = cur.cloudCover, cur.cloudDensity, cur.cloudColor
	end
	if grade then
		grade.Saturation, grade.Contrast, grade.TintColor = cur.gradeSat, cur.gradeContrast, cur.gradeTint
	end
	ctx.Post.envExposure = cur.exposure
	ctx.Post.grainMul = cur.grain
	workspace.GlobalWind = cur.wind
end

-- ── rain ─────────────────────────────────────────────────────────────────────
local CELL, N = 14, 5 -- 5x5 cells of 14 studs around the camera
local rainFolder, cells = nil, {}
local rayUp = RaycastParams.new()
rayUp.FilterType = Enum.RaycastFilterType.Exclude

local function seq(a, b)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

local function cellPart(name)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(CELL, 0.2, CELL)
	p.Parent = rainFolder
	return p
end

local function buildRain()
	rainFolder = Instance.new("Folder")
	rainFolder.Name = "ZR_Rain"
	rainFolder.Parent = workspace
	for i = 1, N * N do
		local top = cellPart("RainCell")
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = Textures.RAIN
		pe.EmissionDirection = Enum.NormalId.Bottom
		pe.Orientation = Enum.ParticleOrientation.VelocityParallel
		pe.Speed = NumberRange.new(68, 82)
		pe.Lifetime = NumberRange.new(0.55, 0.7)
		pe.Size = seq(1.7, 1.7)
		pe.Transparency = seq(0.45, 0.6)
		pe.Color = ColorSequence.new(rgb(206, 216, 226))
		pe.LightEmission = 0.05
		pe.LightInfluence = 0.9
		pe.Rate = 0
		pe.SpreadAngle = Vector2.new(2, 2)
		pe.Parent = top
		local ground = cellPart("RainGround")
		ground.Size = Vector3.new(CELL, 0.1, CELL)
		local sp = Instance.new("ParticleEmitter")
		sp.Texture = Textures.SPLASH
		sp.EmissionDirection = Enum.NormalId.Top
		sp.Speed = NumberRange.new(0, 0)
		sp.Lifetime = NumberRange.new(0.12, 0.2)
		sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.7) })
		sp.Transparency = seq(0.35, 1)
		sp.Color = ColorSequence.new(rgb(214, 222, 230))
		sp.LightInfluence = 0.9
		sp.Rate = 0
		sp.Parent = ground
		cells[i] = { top = top, pe = pe, ground = ground, sp = sp, covered = false, gy = 0 }
	end
end

-- reposition the cells around the camera and decide which ones are under a roof
local function placeRain(intensity, windDrift)
	local cp = cam.CFrame.Position
	local bx, bz = math.floor(cp.X / CELL), math.floor(cp.Z / CELL)
	local half = math.floor(N / 2)
	local char = game.Players.LocalPlayer.Character
	rayUp.FilterDescendantsInstances = { char, rainFolder, workspace:FindFirstChild("ZR_Fx") }
	local covered = 0
	local i = 0
	for gx = -half, half do
		for gz = -half, half do
			i += 1
			local c = cells[i]
			local x, z = (bx + gx + 0.5) * CELL, (bz + gz + 0.5) * CELL
			local topY = cp.Y + 30
			-- first surface below the emitter: a roof/overhang above head height means this cell is covered
			local hit = workspace:Raycast(Vector3.new(x, topY, z), Vector3.new(0, -80, 0), rayUp)
			local roof = hit and hit.Position.Y > cp.Y + 2.5
			c.covered = roof
			c.top.CFrame = CFrame.new(x - windDrift.X * 0.25, topY, z - windDrift.Z * 0.25)
			c.pe.Acceleration = Vector3.new(windDrift.X, 0, windDrift.Z)
			local near = math.abs(gx) <= 1 and math.abs(gz) <= 1
			c.pe.Rate = roof and 0 or (near and 260 or 170) * intensity
			if hit and not roof and near then
				c.ground.CFrame = CFrame.new(x, hit.Position.Y + 0.08, z)
				c.sp.Rate = 70 * intensity
			else
				c.sp.Rate = 0
			end
			if gx == 0 and gz == 0 then
				covered = roof and 1 or 0
			end
		end
	end
	return covered
end

local function stopRain()
	for _, c in cells do
		c.pe.Rate = 0
		c.sp.Rate = 0
	end
end

-- ── sound beds ───────────────────────────────────────────────────────────────
local beds = {}
local function bed(name)
	if beds[name] == nil then
		local s, gain = ctx.Effects.loop(name)
		beds[name] = s and { s = s, gain = gain, v = 0 } or false
	end
	return beds[name] or nil
end

local function mix(name, target, dt)
	local b = bed(name)
	if not b then
		return
	end
	b.v += (target - b.v) * math.min(1, dt * 1.5)
	b.s.Volume = b.v * b.gain
end

-- ── lens droplets ────────────────────────────────────────────────────────────
local drops, wet = nil, 0
local function buildDrops()
	local gui = ctx.Post.gui
	if not gui then
		return
	end
	drops = Instance.new("ImageLabel")
	drops.Name = "LensDrops"
	drops.BackgroundTransparency = 1
	drops.Image = Textures.DROPS
	drops.Size = UDim2.fromScale(1, 1)
	drops.ImageTransparency = 1
	drops.ZIndex = 4 -- above the lens haze, under the vignette (Post)
	drops.Parent = gui
end

-- ── lamps ────────────────────────────────────────────────────────────────────
local lampsOn = true -- the server builds them lit
local function lamp(head, on)
	if head:IsA("BasePart") then
		head.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
		head.Color = on and rgb(255, 217, 160) or rgb(150, 146, 136)
		for _, l in head:GetChildren() do
			if l:IsA("Light") then
				l.Enabled = on
			end
		end
	end
end
local function setLamps(on)
	if lampsOn == on then
		return
	end
	lampsOn = on
	for _, head in CollectionService:GetTagged("ZR_Lamp") do
		lamp(head, on)
	end
end

-- ── main loop ────────────────────────────────────────────────────────────────
local placeClock = 0
local timers = {}
-- true once every lo..hi seconds (the first call only schedules)
local function due(key, lo, hi)
	local t = os.clock()
	local nxt = timers[key]
	if not nxt then
		timers[key] = t + math.random(lo, hi)
		return false
	end
	if t >= nxt then
		timers[key] = t + math.random(lo, hi)
		return true
	end
	return false
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function step(dt)
	local raid = ctx.State.inRaid() and ctx.State.raid or nil
	local e = raid and raid.env or nil
	local mode = e and "raid" or "hideout"
	local now = serverNow()
	local t
	if e then
		local d
		t, d = raidTargets(e, now)
		Atmos.dark = 1 - d
	else
		t = hideout
		Atmos.dark = 0
	end
	-- snap on a mode change (deploy / return), otherwise ease toward the target
	blend(t, (mode ~= Atmos.mode) and 1 or math.min(1, dt * 0.8))
	Atmos.mode = mode
	Atmos.env = e
	local w = e and (Env.WEATHER[e.w] or Env.WEATHER.clear) or nil
	local rain = e and (e.rain or 0) or 0
	Atmos.rain = rain
	-- rain particles (re-placed a few times a second; the grid follows the camera)
	placeClock += dt
	if placeClock > 0.2 then
		placeClock = 0
		if rain > 0 then
			local q = ctx.Settings.data.quality or 2
			Atmos.cover = placeRain(rain * (q >= 2 and 1 or 0.5), cur.wind * 0.6)
		elseif Atmos.raining then
			stopRain()
			Atmos.cover = 0
		end
		Atmos.raining = rain > 0
	end
	local indoor = math.max(Atmos.cover, (ctx.Post.indoor or 0) > 0.55 and 1 or 0)
	if rain == 0 then
		indoor = (ctx.Post.indoor or 0) > 0.55 and 1 or 0
	end
	-- lens edge haze takes the scene's colour; fringing shows less in the dark (Post)
	local indoorF = ctx.Post.indoor or 0
	if e then
		ctx.Post.lum = (1 - Atmos.dark) * (0.6 + 0.4 * w.light) * (1 - 0.5 * indoorF)
		local k = (0.25 + 0.2 * (1 - Atmos.dark)) * (1 - 0.35 * indoorF)
		ctx.Post.hazeTint = Color3.new(cur.atmColor.R * k, cur.atmColor.G * k, cur.atmColor.B * k)
	else
		ctx.Post.lum = 0.5
		ctx.Post.hazeTint = rgb(58, 56, 50)
	end
	-- droplets build up on the lens outdoors in the rain and dry off indoors
	if drops then
		local target = (rain > 0 and indoor < 0.5) and (0.25 + 0.45 * rain) or 0
		wet += (target - wet) * math.min(1, dt * ((target > wet) and 0.08 or 0.04))
		drops.ImageTransparency = 1 - wet
	end
	-- sound beds
	local inRaid = e ~= nil
	mix("rain_loop", inRaid and rain * (1 - indoor) * 0.75 or 0, dt)
	mix("rain_roof_loop", inRaid and rain * indoor * 0.7 or 0, dt)
	mix("wind_loop", inRaid and (w.wind * (1 - indoor * 0.75)) * 0.45 or 0, dt)
	mix("crickets_loop", inRaid and math.clamp((Atmos.dark - 0.5) * 2, 0, 1) * (1 - rain) * (1 - indoor * 0.7) * 0.5 or 0, dt)
	local amb = ctx.Effects.ambience
	if amb then
		local target = inRaid and (0.35 * (1 - rain * 0.6) * (1 - Atmos.dark * 0.45) * (1 - indoor * 0.4)) or 0.12
		amb.Volume += (target - amb.Volume) * math.min(1, dt)
	end
	-- lamps: on in the dark, fog or heavy cloud
	if inRaid then
		setLamps(Atmos.dark > 0.45 or (e.w == "fog") or (e.w == "rain" and Atmos.dark > 0.2))
	end
	-- occasional one-shots: thunder with lightning in heavy rain, gulls by day, a distant horn, creaking metal
	if inRaid then
		if rain > 0.7 and due("thunder", 35, 90) then
			ctx.Post.flash = indoor > 0.5 and 0.25 or 1
			task.delay(math.random(10, 40) / 10, function()
				ctx.Effects.sfx(math.random() < 0.5 and "thunder_1" or "thunder_2", SoundService, 0.75 * rain)
			end)
		end
		if Atmos.dark < 0.4 and rain < 0.5 and due("gull", 25, 70) then
			local p = cam.CFrame.Position + Vector3.new(math.random(-90, 90), math.random(25, 45), math.random(-90, 90))
			ctx.Effects.sfx(math.random() < 0.5 and "gull_1" or "gull_2", p, 0.9, math.random(90, 110) / 100, 240)
		end
		if due("horn", 180, 360) then
			ctx.Effects.sfx("ship_horn", SoundService, 0.22)
		end
		if due("creak", 40, 100) then
			local p = cam.CFrame.Position + Vector3.new(math.random(-50, 50), math.random(0, 12), math.random(-50, 50))
			ctx.Effects.sfx("metal_creak", p, 0.7, math.random(85, 110) / 100, 120)
		end
		if w.wind > 0.4 and due("gust", 15, 40) then
			ctx.Effects.sfx("wind_gust", SoundService, 0.5 * w.wind * (1 - indoor * 0.7))
		end
	end
end

function Atmos.init(c)
	ctx = c
	capture()
	buildRain()
	buildDrops()
	-- lamps streamed in later take the current state
	CollectionService:GetInstanceAddedSignal("ZR_Lamp"):Connect(function(head)
		lamp(head, lampsOn)
	end)
	local lastWarn = 0
	RunService:BindToRenderStep("ZR_Atmos", Enum.RenderPriority.Camera.Value + 4, function(dt)
		local ok, err = pcall(step, dt)
		if not ok and os.clock() - lastWarn > 5 then
			lastWarn = os.clock()
			warn("[ZR] atmos", err)
		end
	end)
end

return Atmos
