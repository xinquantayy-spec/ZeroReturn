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
local SkySets = require(Shared.Sky)
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
-- classic distance fog (FOG weather): NO_FOG is "off"; below FOG_ON the fog is drawn and the Atmosphere parked
local NO_FOG, FOG_ON = 100000, 20000
local fogParked = false

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
		exposure = 0, grain = 1, wind = Vector3.new(4, 0, 2), fogEnd = NO_FOG,
	}
	-- the lobby is the Relay 7 bunker: no sky, warm dusty air, the rooms lit by their own fittings
	local bunker = rgb(78, 74, 68)
	hideout.Ambient, hideout.OutdoorAmbient = bunker, bunker
	hideout.EnvironmentDiffuseScale, hideout.EnvironmentSpecularScale = 0.3, 0.2
	hideout.atmDensity, hideout.atmOffset, hideout.atmHaze, hideout.atmGlare = 0.3, 0.1, 1.2, 0
	hideout.atmColor, hideout.atmDecay = rgb(138, 128, 112), rgb(70, 64, 54)
	hideout.gradeSat, hideout.gradeContrast, hideout.gradeTint = -0.16, 0.1, rgb(240, 234, 222)
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
	t.Ambient = lerpC(rgb(62, 66, 76), rgb(74, 77, 80), d) -- day fill lowered from 96,100,102 for contrast indoors (2026-11-01)
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
	t.fogEnd = w.fogEnd or NO_FOG
	t.cloudCover = w.clouds
	t.cloudDensity = w.cloudDensity
	t.cloudColor = lerpC(lerpC(rgb(52, 56, 64), rgb(199, 205, 203), d * lerp(0.65, 1, w.light)), rgb(222, 168, 136), gold * 0.5)
	-- grade: night cool and desaturated, rain cold, dusk warm
	t.gradeSat = lerp(-0.46, -0.22, d) - rain * 0.08
	t.gradeContrast = lerp(0.13, 0.08, d)
	local tint = lerpC(rgb(186, 204, 230), rgb(236, 239, 232), d)
	tint = lerpC(tint, rgb(255, 226, 202), gold * 0.5)
	t.gradeTint = lerpC(tint, rgb(220, 229, 236), rain * 0.5)
	-- bodycam auto-gain lifts dark scenes (and their noise); halved by decision art-8b so nights stay dark enough that
	-- goggles and lights matter (Tarkov's nights are dark), keeping a little of the bodycam's character
	t.exposure = lerp(0.31, 0, d) + (1 - sun) * 0.05
	t.grain = lerp(1.4, 1, d)
	t.wind = Vector3.new(w.wind * 14, 0, w.wind * 7)
	return t, d, h
end

local NUM = { "ClockTime", "Brightness", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" }
local COL = { "Ambient", "OutdoorAmbient", "ColorShift_Top" }
local cur -- smoothed values actually applied

-- write a lighting value only when it moved by a visible step (audit tech.12): the light eases toward its target every
-- frame, but the engine is told only when a value changes enough to see. A snap (deploy, return), the end of Studio
-- capture mode and a resync every 5 s write everything again.
local written = {} -- [object][property] = the value last written
local writtenAt = 0
local EPS = {
	ClockTime = 0.004, Brightness = 0.004, EnvironmentDiffuseScale = 0.003, EnvironmentSpecularScale = 0.003,
	Density = 0.002, Offset = 0.002, Glare = 0.01, Haze = 0.01, Cover = 0.002, Saturation = 0.002, Contrast = 0.002,
	FogStart = 1, FogEnd = 2, GlobalWind = 0.05,
}
local function put(obj, prop, v)
	local w = written[obj]
	if not w then
		w = {}
		written[obj] = w
	end
	local last = w[prop]
	if last ~= nil then
		local kind = typeof(v)
		if kind == "number" then
			if math.abs(v - last) < (EPS[prop] or 0.002) then
				return
			end
		elseif kind == "Color3" then
			if math.abs(v.R - last.R) < 0.004 and math.abs(v.G - last.G) < 0.004 and math.abs(v.B - last.B) < 0.004 then
				return
			end
		elseif kind == "Vector3" then
			if (v - last).Magnitude < (EPS[prop] or 0.05) then
				return
			end
		elseif v == last then
			return
		end
	end
	w[prop] = v
	obj[prop] = v
end
-- ClockTime wraps at 24: 23.999 -> 0.001 is a small step, not a large one
local function putClock(v)
	local w = written[Lighting]
	local last = w and w.ClockTime
	if last ~= nil and math.abs(((v - last + 12) % 24) - 12) < EPS.ClockTime then
		return
	end
	put(Lighting, "ClockTime", v)
end

local function blend(target, k)
	if not cur or k >= 1 or os.clock() - writtenAt > 5 then
		table.clear(written)
		writtenAt = os.clock()
	end
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
	putClock(cur.ClockTime)
	for _, key in NUM do
		if key ~= "ClockTime" then
			put(Lighting, key, cur[key])
		end
	end
	for _, key in COL do
		put(Lighting, key, cur[key])
	end
	if atm then
		put(atm, "Density", cur.atmDensity)
		put(atm, "Offset", cur.atmOffset)
		put(atm, "Color", cur.atmColor)
		put(atm, "Decay", cur.atmDecay)
		put(atm, "Glare", cur.atmGlare)
		put(atm, "Haze", cur.atmHaze)
	end
	-- FOG weather: classic distance fog closes the view (opaque from fogEnd on), and the Atmosphere is parked meanwhile, since
	-- Roblox uses the classic fog only when there is none. The fog takes the overcast sky's colour, so what lies beyond reads as sky
	local fogOn = cur.fogEnd < FOG_ON
	if fogOn then
		local c = cur.cloudColor
		local k = 0.86
		put(Lighting, "FogColor", Color3.new(c.R * k, c.G * k, c.B * k))
		put(Lighting, "FogStart", cur.fogEnd * 0.08)
		put(Lighting, "FogEnd", cur.fogEnd)
	end
	if fogOn ~= fogParked then
		fogParked = fogOn
		if atm then
			atm.Parent = (not fogOn) and Lighting or nil
		end
		if not fogOn then
			put(Lighting, "FogStart", 0)
			put(Lighting, "FogEnd", 100000)
		end
	end
	Atmos.fogEnd = fogOn and cur.fogEnd or nil
	if clouds then
		put(clouds, "Cover", cur.cloudCover)
		put(clouds, "Density", cur.cloudDensity)
		put(clouds, "Color", cur.cloudColor)
	end
	if grade then
		put(grade, "Saturation", cur.gradeSat)
		put(grade, "Contrast", cur.gradeContrast)
		put(grade, "TintColor", cur.gradeTint)
	end
	ctx.Post.envExposure = cur.exposure
	ctx.Post.grainMul = cur.grain
	put(workspace, "GlobalWind", cur.wind)
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

-- winter: snow falls from the rain cells (setSnow below). Declared before placeRain, which reads it: declared after, the
-- name was a global there and snow kicked up rain splashes (2026-11-01)
local snowing = false

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
			if hit and not roof and near and not snowing then
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

-- seasons (Tarkov 0.16): winter snow falls from the rain cells, terrain and foliage take the season's colours
local function setSnow(on)
	if on == snowing then
		return
	end
	snowing = on
	for _, c in cells do
		local pe = c.pe
		if on then
			pe.Orientation = Enum.ParticleOrientation.FacingCamera
			pe.Speed = NumberRange.new(5, 8)
			pe.Lifetime = NumberRange.new(5, 7)
			pe.Size = seq(0.18, 0.12)
			pe.Transparency = seq(0.08, 0.3)
			pe.Color = ColorSequence.new(rgb(246, 248, 252))
			pe.SpreadAngle = Vector2.new(25, 25)
			pe.RotSpeed = NumberRange.new(-80, 80)
			c.sp.Rate = 0
		else
			pe.Orientation = Enum.ParticleOrientation.VelocityParallel
			pe.Speed = NumberRange.new(68, 82)
			pe.Lifetime = NumberRange.new(0.55, 0.7)
			pe.Size = seq(1.7, 1.7)
			pe.Transparency = seq(0.45, 0.6)
			pe.Color = ColorSequence.new(rgb(206, 216, 226))
			pe.SpreadAngle = Vector2.new(2, 2)
			pe.RotSpeed = NumberRange.new(0, 0)
		end
	end
end

local TERRAIN_MATS = { Enum.Material.Grass, Enum.Material.LeafyGrass, Enum.Material.Ground, Enum.Material.Mud, Enum.Material.Rock, Enum.Material.Sand }
local SEASON_TERRAIN = {
	autumn = { Grass = rgb(140, 126, 74), LeafyGrass = rgb(150, 110, 56), Ground = rgb(104, 86, 64), Mud = rgb(70, 56, 42) },
	winter = { Grass = rgb(232, 236, 240), LeafyGrass = rgb(226, 230, 236), Ground = rgb(214, 218, 224), Mud = rgb(178, 176, 172), Rock = rgb(176, 178, 182), Sand = rgb(228, 230, 232) },
	spring = { Grass = rgb(94, 134, 62), LeafyGrass = rgb(82, 122, 56), Mud = rgb(68, 54, 40) },
}
local SEASON_FOLIAGE = { autumn = rgb(255, 192, 116), winter = rgb(214, 226, 238), spring = rgb(224, 255, 214) }
local baseTerrain
local seasonApplied = "summer"

-- bushes, grass and tree crowns (the nature kit's pieces) take the season's tint over their own colours. Each piece is
-- tinted as it arrives (audit tech.9): the map's as they stream into ZR_World (DescendantAdded), the client's ground
-- cover as Detail builds it (Atmos.tintNature). A season change re-tints the pieces already here, a few hundred a frame.
-- No whole-workspace scan: trees and bushes that stream in after the deploy get the season too.
-- (strong tables: an Instance key in a weak table can vanish while the part still exists; pieces that left are pruned)
local natParts = {} -- nature pieces seen -> true
local natBase = {} -- piece -> its own colour
local natCount, natKept = 0, 0 -- pieces registered, and how many were left after the last prune
local retint = nil -- { list, i } while a season change works through the pieces
local RETINT_BUDGET = 400 -- pieces a frame
local PRUNE_AFTER = 3000 -- new pieces between prunes of the ones that streamed out or were dropped

local function isFoliage(n)
	return string.sub(n, 1, 7) == "ZR_NAT_" and not string.find(n, "_T$") and not string.find(n, "Rock") and not string.find(n, "Log") and not string.find(n, "Stump")
end

local function tintOne(d)
	local base = natBase[d]
	if not base then
		base = d.Color
		natBase[d] = base
	end
	local season = seasonApplied
	local tint = SEASON_FOLIAGE[season]
	-- winter lays snow on them (toward white); autumn and spring tint them
	d.Color = (season == "winter" and base:Lerp(rgb(236, 240, 246), 0.6)) or (tint and Color3.new(base.R * tint.R, base.G * tint.G, base.B * tint.B)) or base
end

-- a nature piece arrived (streamed in, or built by Detail): it takes the season now
function Atmos.tintNature(d)
	if d.ClassName == "MeshPart" and isFoliage(d.Name) then
		if not natParts[d] then
			natParts[d] = true
			natCount += 1
		end
		if seasonApplied ~= "summer" then
			tintOne(d)
		elseif natBase[d] == nil then
			natBase[d] = d.Color -- its own colour, kept for a later season
		end
	end
end

local function stepRetint()
	local r = retint
	local stop = math.min(#r.list, r.i + RETINT_BUDGET - 1)
	for i = r.i, stop do
		local d = r.list[i]
		if d.Parent then
			tintOne(d)
		end
	end
	r.i = stop + 1
	if r.i > #r.list then
		retint = nil
	end
end

-- forget the pieces that streamed out or were dropped (their Parent is nil once removed or destroyed)
local function pruneNature()
	local n = 0
	for d in natParts do
		if d.Parent == nil then
			natParts[d] = nil
			natBase[d] = nil
		else
			n += 1
		end
	end
	natCount, natKept = n, n
end

local function applySeason(season)
	season = season or "summer"
	if season == seasonApplied then
		if retint then
			stepRetint()
		elseif natCount - natKept > PRUNE_AFTER then
			pruneNature()
		end
		return
	end
	seasonApplied = season
	local terrain = workspace.Terrain
	if not baseTerrain then
		baseTerrain = {}
		for _, m in TERRAIN_MATS do
			baseTerrain[m] = terrain:GetMaterialColor(m)
		end
	end
	local set = SEASON_TERRAIN[season] or {}
	for _, m in TERRAIN_MATS do
		terrain:SetMaterialColor(m, set[m.Name] or baseTerrain[m])
	end
	pruneNature()
	local list = {}
	for d in natParts do
		table.insert(list, d)
	end
	retint = { list = list, i = 1 }
	stepRetint()
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
	local vol = b.v * b.gain
	if math.abs(vol - (b.shown or -1)) > 0.002 then
		b.shown = vol -- written only on change (audit tech.12)
		b.s.Volume = vol
	end
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
-- M12 imperfection: the map marks some lamps (attribute "Lamp"): "flicker" ones stutter in short bursts,
-- "dead" ones never light. The same lamps on every client.
local lampsOn = true -- the server builds them lit
local flick = {} -- flickering lamp head -> { nxt, dipUntil, dim }
local function lamp(head, on)
	if head:IsA("BasePart") then
		local kind = head:GetAttribute("Lamp")
		if kind == "dead" then
			on = false
		elseif kind == "flicker" and not flick[head] then
			flick[head] = { nxt = os.clock() + math.random() * 6, dipUntil = 0, dim = false }
		end
		head.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
		head.Color = on and rgb(255, 217, 160) or rgb(150, 146, 136)
		for _, l in head:GetChildren() do
			if l:IsA("Light") then
				l.Enabled = on
			end
		end
	end
end
-- bursts of quick dips, then a pause of a few seconds; only while the lamps are lit
local function flickerStep()
	if not lampsOn then
		return
	end
	local t = os.clock()
	for head, f in flick do
		if not head.Parent then
			flick[head] = nil
			continue
		end
		if t >= f.nxt then
			f.dipUntil = t + 0.04 + math.random() * 0.14
			f.nxt = t + ((math.random() < 0.55) and (0.08 + math.random() * 0.22) or (2 + math.random() * 7))
		end
		local dim = t < f.dipUntil
		if dim ~= f.dim then
			f.dim = dim
			head.Material = dim and Enum.Material.SmoothPlastic or Enum.Material.Neon
			for _, l in head:GetChildren() do
				if l:IsA("Light") then
					l.Enabled = not dim
				end
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

-- ── shadows of the map's own lights (audit tech.12) ────────────────────────────────────────────────────────
-- Only the lights within about 60 studs of the camera cast shadows (and the first-person weapon lamp, and other people's
-- weapon lights in the same range: Weapon.luau). The lights the server made with shadows (the bunker's key lights, a
-- control-room lamp) are registered as they stream in and switched by distance 4 times a second; the rest stay without.
local mapLights = {} -- light -> true (strong keys; pruned when it leaves)
local LIGHT_SHADOW_R = 60
local lightClock = 0
local function addMapLight(d)
	local cn = d.ClassName
	if (cn == "PointLight" or cn == "SpotLight" or cn == "SurfaceLight") and d.Shadows then
		mapLights[d] = true
	end
end
local function lightShadows(camPos)
	for l in mapLights do
		local p = l.Parent
		if not p then
			mapLights[l] = nil
		else
			local pos = (p:IsA("BasePart") and p.Position) or (p:IsA("Attachment") and p.WorldPosition) or nil
			local want = pos ~= nil and (pos - camPos).Magnitude < LIGHT_SHADOW_R
			if l.Shadows ~= want then
				l.Shadows = want
			end
		end
	end
end
-- what streams into the world: nature pieces take the season, shadow lights are registered
local function worldAdded(d)
	Atmos.tintNature(d)
	addMapLight(d)
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

local wasFrozen = false
local ambV -- the ambience bed's volume as eased here
local function step(dt)
	if Atmos.frozen then
		wasFrozen = true
		return -- Studio capture mode (dev bridge "studio"): neutral light, no weather
	end
	if wasFrozen then
		wasFrozen = false
		table.clear(written) -- capture mode wrote its own light: write ours again
	end
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
	-- the sky set follows the weather and the hour (audit art.2): clear, overcast or night; only a change rewrites it
	local skyName = e and SkySets.pick(e.w, t.ClockTime or 12) or "clear"
	if skyName ~= Atmos.skyName then
		local sky = Lighting:FindFirstChild("ZR_Sky")
		if sky then
			SkySets.apply(sky, skyName)
			Atmos.skyName = skyName
		end
	end
	local w = e and (Env.WEATHER[e.w] or Env.WEATHER.clear) or nil
	local rain = e and (e.rain or 0) or 0
	Atmos.rain = rain
	-- the season paints the world on deploy; in winter the rain cells drop snow
	applySeason(e and e.season or nil)
	lightClock += dt
	if lightClock > 0.25 then
		lightClock = 0
		lightShadows(cam.CFrame.Position)
	end
	setSnow(e ~= nil and e.season == "winter" and rain > 0)
	local wetRain = snowing and 0 or rain
	-- rain particles (re-placed a few times a second; the grid follows the camera)
	placeClock += dt
	if placeClock > 0.2 then
		placeClock = 0
		if rain > 0 then
			local q = ctx.Settings.data.quality or 2
			Atmos.cover = placeRain(rain * (q >= 2 and 1 or (q >= 1 and 0.5 or 0.3)), cur.wind * 0.6)
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
		local target = (wetRain > 0 and indoor < 0.5) and (0.25 + 0.45 * wetRain) or 0
		wet += (target - wet) * math.min(1, dt * ((target > wet) and 0.08 or 0.04))
		-- hidden while dry, written only on change (audit tech.12)
		put(drops, "Visible", wet > 0.005)
		if wet > 0.005 then
			put(drops, "ImageTransparency", 1 - wet)
		end
	end
	-- sound beds
	local inRaid = e ~= nil
	mix("rain_loop", inRaid and wetRain * (1 - indoor) * 0.75 or 0, dt)
	mix("rain_roof_loop", inRaid and wetRain * indoor * 0.7 or 0, dt)
	mix("wind_loop", inRaid and (w.wind * (1 - indoor * 0.75)) * 0.45 or 0, dt)
	mix("crickets_loop", inRaid and math.clamp((Atmos.dark - 0.5) * 2, 0, 1) * (1 - rain) * (1 - indoor * 0.7) * 0.5 or 0, dt)
	local amb = ctx.Effects.ambience
	if amb then
		local target = inRaid and (0.35 * (1 - rain * 0.6) * (1 - Atmos.dark * 0.45) * (1 - indoor * 0.4)) or 0.12
		ambV = ambV or amb.Volume
		ambV += (target - ambV) * math.min(1, dt)
		put(amb, "Volume", ambV)
	end
	-- lamps: on in the dark, fog or heavy cloud
	if inRaid then
		setLamps(Atmos.dark > 0.45 or (e.w == "fog") or (e.w == "rain" and Atmos.dark > 0.2))
		flickerStep()
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
	-- the map's nature pieces take the season as they stream in (audit tech.9); what is already here when the client
	-- starts is registered once in the background, a few thousand a frame
	local function hookWorld(w)
		w.DescendantAdded:Connect(worldAdded)
		for i, d in w:GetDescendants() do
			worldAdded(d)
			if i % 3000 == 0 then
				task.wait()
			end
		end
	end
	workspace.ChildAdded:Connect(function(ch)
		if ch.Name == "ZR_World" and ch:IsA("Folder") then
			task.spawn(hookWorld, ch) -- a rebuilt world
		end
	end)
	local w = workspace:FindFirstChild("ZR_World")
	if w then
		task.spawn(hookWorld, w)
	end
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
