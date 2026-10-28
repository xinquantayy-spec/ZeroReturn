--!nonstrict
-- Cosmetic-only effects: tracers, muzzle flashes, impacts, bullet marks, positional sounds. Bounded counts.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Sounds = require(Shared.Sounds)
local Atlas = require(Shared.SoundAtlas)
local EnvAtlas = require(Shared.EnvAtlas)

local Effects = {}
local ctx
local fx
local marks = {}
local live = {}

local function quality()
	return ctx and ctx.Settings.data.quality or 2
end

local function tmpPart(size, cf, color, mat, transparency)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Parent = fx
	return p
end

local function fade(p, life)
	table.insert(live, { p = p, t0 = os.clock(), life = life, base = p.Transparency })
end

function Effects.sound(id, at, volume, speed)
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = 600
	s.RollOffMinDistance = 12
	if typeof(at) == "Vector3" then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = workspace.Terrain
		s.Parent = a
		s.Ended:Connect(function()
			a:Destroy()
		end)
		task.delay(6, function()
			if a.Parent then
				a:Destroy()
			end
		end)
	else
		s.Parent = at or SoundService
		s.Ended:Connect(function()
			s:Destroy()
		end)
	end
	s:Play()
	return s
end

-- play one region of the sound atlas (2D when `at` is an Instance, positional for a Vector3)
local live3d = 0
function Effects.sfx(name, at, volume, speed, maxDist)
	local r, id = Atlas[name], Sounds.ATLAS
	if not r then
		r, id = EnvAtlas[name], Sounds.ENV_ATLAS -- world/UI one-shots (M10)
	end
	if not r or not id or id == "" then
		return nil
	end
	local positional = typeof(at) == "Vector3"
	if positional and live3d > 24 then
		return nil -- cap concurrent world sounds
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(r[1], r[1] + r[2])
	s.Volume = (volume or 0.6) * r[3]
	s.PlaybackSpeed = speed or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 5
	s.RollOffMaxDistance = maxDist or 120
	local life = r[2] / (speed or 1) + 0.25
	if positional then
		live3d += 1
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = workspace.Terrain
		s.Parent = a
		task.delay(life, function()
			live3d -= 1
			a:Destroy()
		end)
	else
		s.Parent = at or SoundService
		task.delay(life, function()
			s:Destroy()
		end)
	end
	s:Play()
	return s
end

-- a seamless looping region of the environment atlas (rain, wind, insects); starts silent, returns sound, gain
function Effects.loop(name, parent)
	local r = EnvAtlas[name]
	if not r or Sounds.ENV_ATLAS == "" then
		return nil, 0
	end
	local s = Instance.new("Sound")
	s.Name = "ZR_Loop_" .. name
	s.SoundId = Sounds.ENV_ATLAS
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(r[1], r[1] + r[2])
	s.LoopRegion = NumberRange.new(r[1], r[1] + r[2])
	s.Looped = true
	s.Volume = 0
	s.Parent = parent or SoundService
	s:Play()
	return s, r[3]
end

local function variant(prefix, n)
	return prefix .. math.random(1, n)
end

-- surface family under a point (footsteps / impacts)
local MAT = {
	[Enum.Material.Metal] = "metal", [Enum.Material.DiamondPlate] = "metal", [Enum.Material.CorrodedMetal] = "metal", [Enum.Material.Foil] = "metal",
	[Enum.Material.Wood] = "wood", [Enum.Material.WoodPlanks] = "wood",
	[Enum.Material.Grass] = "dirt", [Enum.Material.Ground] = "dirt", [Enum.Material.Mud] = "dirt", [Enum.Material.LeafyGrass] = "dirt", [Enum.Material.Sand] = "dirt", [Enum.Material.Snow] = "dirt",
	[Enum.Material.Pebble] = "gravel", [Enum.Material.Rock] = "gravel", [Enum.Material.Basalt] = "gravel", [Enum.Material.CrackedLava] = "gravel", [Enum.Material.Salt] = "gravel",
}
Effects.surfaceOf = function(material)
	return MAT[material] or "concrete"
end
local stepParams = RaycastParams.new()
stepParams.FilterType = Enum.RaycastFilterType.Exclude

-- footstep at a foot position; intensity 0..1 (crouch/slow quiet, sprint loud). Own steps are quieter.
function Effects.footstep(pos, intensity, model, own)
	stepParams.FilterDescendantsInstances = { model, workspace.CurrentCamera, fx }
	local hit = workspace:Raycast(pos + Vector3.new(0, 1.2, 0), Vector3.new(0, -3, 0), stepParams)
	local fam = hit and Effects.surfaceOf(hit.Material) or "concrete"
	local name = (fam == "concrete" and variant("step_concrete_", 4)) or (fam == "metal" and variant("step_metal_", 3)) or (fam == "gravel" and variant("step_gravel_", 3))
		or (fam == "wood" and variant("step_wood_", 2)) or variant("step_dirt_", 2)
	local vol = (own and 0.32 or 0.95) * (0.25 + intensity * 0.75)
	local speed = 0.94 + math.random() * 0.12
	if own then
		Effects.sfx(name, SoundService, vol, speed)
	else
		Effects.sfx(name, hit and hit.Position or pos, vol, speed, 30 + intensity * 70)
	end
	if intensity > 0.9 and math.random() < 0.35 then
		Effects.sfx("gear_rattle", own and SoundService or pos, vol * 0.5, 1, 40)
	end
end

function Effects.cloth(vol)
	Effects.sfx(math.random() < 0.5 and "cloth_1" or "cloth_2", SoundService, vol or 0.4)
end

function Effects.breath(vol)
	Effects.sfx("breath_heavy", SoundService, vol or 0.5)
end

-- per-weapon report: pitch/volume variants of the recorded rifle shot; suppressors muffle and shorten it
local GUN = {
	R17 = { s = 1.0, v = 0.9 }, KST = { s = 0.9, v = 0.95 }, SPARROW = { s = 1.16, v = 0.8 },
	HARROW = { s = 0.68, v = 1.0 }, TUNDRA = { s = 0.78, v = 1.0 }, P9 = { s = 1.28, v = 0.72 },
}
function Effects.gunSound(weapon, at, suppressed, distant, volMul)
	local g = GUN[weapon] or GUN.R17
	local id = (distant and not suppressed and Sounds.R17_FIRE_FAR ~= "") and Sounds.R17_FIRE_FAR or Sounds.R17_FIRE
	local vol = g.v * (suppressed and 0.32 or 1) * (volMul or 1)
	local speed = g.s * (suppressed and 1.18 or 1) * (1 + (math.random() - 0.5) * 0.05)
	local s = Effects.sound(id, at, vol, speed)
	if s and suppressed then
		s.RollOffMaxDistance = 220
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = -20
		eq.MidGain = -6
		eq.LowGain = 2
		eq.Parent = s
	end
	return s
end

function Effects.tracer(o, p)
	local d = p - o
	local len = d.Magnitude
	if len < 1 then
		return
	end
	local seg = math.min(len, 14)
	local start = o + d.Unit * math.min(2, len * 0.1)
	local part = tmpPart(Vector3.new(0.06, 0.06, seg), CFrame.lookAt(start + d.Unit * seg / 2, p), Color3.fromHex("F3E2B4"), Enum.Material.Neon, 0.35)
	fade(part, 0.07)
end

function Effects.flash(pos)
	local part = tmpPart(Vector3.new(0.35, 0.35, 0.35), CFrame.new(pos), Color3.fromHex("FFD9A0"), Enum.Material.Neon, 0.2)
	local l = Instance.new("PointLight")
	l.Color = Color3.fromHex("FFC98A")
	l.Range = 12
	l.Brightness = 2.5
	l.Parent = part
	fade(part, 0.05)
end

function Effects.impactSound(pos, isBody, material)
	if isBody then
		Effects.sfx(variant("impact_body_", 2), pos, 0.7, 1, 70)
		return
	end
	local fam = material and Effects.surfaceOf(material) or "concrete"
	local name = (fam == "metal" and variant("impact_metal_", 2)) or (fam == "wood" and variant("impact_wood_", 2))
		or ((fam == "dirt" or fam == "gravel") and variant("impact_dirt_", 2)) or variant("impact_concrete_", 3)
	Effects.sfx(name, pos, 0.75, 0.95 + math.random() * 0.1, 110)
end

function Effects.impact(pos, normal, isBody)
	if quality() >= 2 or isBody then
		local p = tmpPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), Color3.new(1, 1, 1), nil, 1)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(isBody and Color3.fromHex("3A3532") or Color3.fromHex("A7A398"))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.4) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.4, 0.8)
		e.Speed = NumberRange.new(2, 5)
		e.SpreadAngle = Vector2.new(25, 25)
		e.Rate = 0
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = p
		if normal then
			p.CFrame = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
		end
		e:Emit((quality() >= 3) and 8 or 4)
		task.delay(1.2, function()
			p:Destroy()
		end)
	end
	if not isBody and normal then
		local m = tmpPart(Vector3.new(0.05, 0.22, 0.22), CFrame.lookAt(pos + normal * 0.02, pos + normal * 2) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromHex("1E1E1C"), Enum.Material.SmoothPlastic, 0.1)
		m.Shape = Enum.PartType.Cylinder
		table.insert(marks, m)
		if #marks > 40 then
			table.remove(marks, 1):Destroy()
		end
		task.delay(25, function()
			if m.Parent then
				m:Destroy()
			end
		end)
	end
end

-- full remote shot (other players / AI): tracer + muzzle flash + sound + impact
function Effects.remoteShot(d)
	if typeof(d.o) ~= "Vector3" or typeof(d.p) ~= "Vector3" then
		return
	end
	if not d.s then
		Effects.flash(d.o)
	end
	if d.t then
		Effects.tracer(d.o, d.p) -- tracer rounds only (Tarkov)
	end
	Effects.impact(d.p, d.n, d.h)
	Effects.impactSound(d.p, d.h, d.m)
	local cam = workspace.CurrentCamera
	local dist = cam and (cam.CFrame.Position - d.o).Magnitude or 0
	-- bullet passing close by: supersonic crack where it passed (Tarkov-style shot awareness)
	if cam and dist > 18 then
		local cp = cam.CFrame.Position
		local seg = d.p - d.o
		local len = seg.Magnitude
		if len > 1 then
			local u = seg / len
			local k = math.clamp((cp - d.o):Dot(u), 0, len)
			local closest = d.o + u * k
			if (closest - cp).Magnitude < 6 and k < len - 1 then
				Effects.sfx(variant("crack_", 2), closest, 0.9, 0.95 + math.random() * 0.1, 30)
			end
		end
	end
	Effects.gunSound(type(d.w) == "string" and d.w or "R17", d.o, d.s == true, dist > 160, d.ai and 0.85 or 0.95)
end

function Effects.init(c)
	ctx = c
	local old = workspace:FindFirstChild("ZR_Fx")
	if old then
		old:Destroy()
	end
	fx = Instance.new("Folder")
	fx.Name = "ZR_Fx"
	fx.Parent = workspace
	if c.State.fx then
		c.State.fx.OnClientEvent:Connect(function(kind, d)
			if kind == "shot" and type(d) == "table" then
				Effects.remoteShot(d)
			elseif kind == "sfx" and type(d) == "table" and type(d.n) == "string" and typeof(d.p) == "Vector3" then
				Effects.sfx(d.n, d.p, d.v or 0.8, 1, 60)
			end
		end)
	end
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for i = #live, 1, -1 do
			local e = live[i]
			local a = (t - e.t0) / e.life
			if a >= 1 then
				e.p:Destroy()
				table.remove(live, i)
			else
				e.p.Transparency = e.base + (1 - e.base) * a
			end
		end
	end)
	if Sounds.AMBIENCE ~= "" then
		local amb = Instance.new("Sound")
		amb.SoundId = Sounds.AMBIENCE
		amb.Looped = true
		amb.Volume = 0.35
		amb.Parent = SoundService
		amb:Play()
		Effects.ambience = amb -- Atmos mixes it with weather and time of day
	end
end

return Effects
