--!nonstrict
-- Cosmetic-only effects: tracers, muzzle flashes, impacts, bullet marks, positional sounds. Bounded counts.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Sounds = require(Shared.Sounds)

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
	local cam = workspace.CurrentCamera
	local dist = cam and (cam.CFrame.Position - d.o).Magnitude or 0
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
	end
end

return Effects
