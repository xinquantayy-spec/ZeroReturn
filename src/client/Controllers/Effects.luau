--!nonstrict
-- Cosmetic-only effects: tracers, muzzle flashes, impacts, bullet marks, positional sounds. Bounded counts.
-- World sounds run through one SoundGroup so a blast or a stun charge can muffle them (deafness, M11).
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Sounds = require(Shared.Sounds)
local Atlas = require(Shared.SoundAtlas)
local EnvAtlas = require(Shared.EnvAtlas)
local CombatAtlas = require(Shared.CombatAtlas)
local AmbAtlas = require(Shared.AmbAtlas)
-- breaking glass: the spray, the sound and the floor shards (docs/design/GLASS.md); optional, a fault in it must not take the other effects down
-- airdrops: the plane, its flares and the falling crate (Services/Airdrop.luau); optional like the glass
local okAirdropFx, AirdropFx = pcall(require, script.Parent.AirdropFx)
if not okAirdropFx then
	warn("[ZR] AirdropFx failed to load:", AirdropFx)
	AirdropFx = nil
end
local okLaserFx, LaserFx = pcall(require, script.Parent.LaserFx)
if not okLaserFx then
	warn("[ZR] LaserFx failed to load:", LaserFx)
	LaserFx = nil
end
local okGlassFx, GlassFx = pcall(require, script.Parent.GlassFx)
if not okGlassFx then
	warn("[ZR] GlassFx failed to load:", GlassFx)
	GlassFx = nil
end

local Effects = {}
local ctx
local fx
local marks = {}
local live = {}
local world, deafEq, tinnitus, tinnitusGain
local deaf = { amt = 0, untilT = 0, span = 1 }

-- the combat atlas (grenades, malfunctions) is uploaded separately: until it is, these play stand-ins from the
-- main atlas (name, speed, volume) or from the recorded gunshot
local COMBAT_FALLBACK = {
	nade_pin = { "bolt_up", 1.5, 0.9 }, nade_spoon = { "selector", 0.55, 1 }, nade_throw = { "knife_whoosh", 0.7, 0.9 },
	nade_bounce_1 = { "impact_metal_1", 1.7, 0.4 }, nade_bounce_2 = { "impact_metal_2", 1.8, 0.4 }, nade_bounce_3 = { "impact_metal_1", 1.5, 0.4 },
	explosion_debris = { "impact_dirt_1", 0.6, 0.6 }, smoke_pop = { "mag_out", 0.45, 0.9 }, malf_click = { "selector", 0.8, 1 },
	malf_clear = { "bolt_back", 0.9, 1 }, malf_jam = { "bolt_back", 0.75, 1 }, repair_kit = { "rummage", 1, 1 },
}
local BIG_FALLBACK = { explosion_near = { "R17_FIRE", 0.42, 1.7 }, explosion_far = { "R17_FIRE_FAR", 0.5, 1.4 }, flashbang = { "R17_FIRE", 0.8, 1.5 } }

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
	s.SoundGroup = world
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

local function region(name)
	local r = Atlas[name]
	if r then
		return r, Sounds.ATLAS
	end
	r = EnvAtlas[name] -- world/UI one-shots (M10)
	if r then
		return r, Sounds.ENV_ATLAS
	end
	r = CombatAtlas[name] -- grenades, malfunctions (M11)
	if r and (Sounds.COMBAT_ATLAS or "") ~= "" then
		return r, Sounds.COMBAT_ATLAS
	end
	r = AmbAtlas[name] -- drips and distant gunfire (atmosphere pass; silent until ZR_SFX_Amb is uploaded)
	if r and (Sounds.AMB_ATLAS or "") ~= "" then
		return r, Sounds.AMB_ATLAS
	end
	return nil, nil
end

-- play one region of the sound atlas (2D when `at` is an Instance, positional for a Vector3)
local live3d = 0
function Effects.sfx(name, at, volume, speed, maxDist)
	local r, id = region(name)
	if not r then
		local fb = COMBAT_FALLBACK[name]
		if fb then
			return Effects.sfx(fb[1], at, (volume or 0.6) * fb[3], (speed or 1) * fb[2], maxDist)
		end
		local big = BIG_FALLBACK[name]
		if big and Sounds[big[1]] ~= "" then
			local s = Effects.sound(Sounds[big[1]], at, (volume or 0.6) * big[3], (speed or 1) * big[2])
			if s then
				s.RollOffMaxDistance = maxDist or 600
				s.RollOffMinDistance = 30
			end
			return s
		end
		return nil
	end
	if not id or id == "" then
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
	s.RollOffMinDistance = (maxDist and maxDist > 300) and 30 or 5
	s.RollOffMaxDistance = maxDist or 120
	s.SoundGroup = world
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

-- a seamless looping region of the environment or combat atlas (rain, wind, insects, smoke hiss, tinnitus);
-- starts silent, returns sound, gain. noGroup: keep it out of the world mix (tinnitus is in your head).
function Effects.loop(name, parent, noGroup)
	local r, id = EnvAtlas[name], Sounds.ENV_ATLAS
	if not r then
		r, id = CombatAtlas[name], Sounds.COMBAT_ATLAS or ""
	end
	if not r then
		r, id = AmbAtlas[name], Sounds.AMB_ATLAS or ""
	end
	if not r or id == "" then
		return nil, 0
	end
	local s = Instance.new("Sound")
	s.Name = "ZR_Loop_" .. name
	s.SoundId = id
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(r[1], r[1] + r[2])
	s.LoopRegion = NumberRange.new(r[1], r[1] + r[2])
	s.Looped = true
	s.Volume = 0
	if not noGroup then
		s.SoundGroup = world
	end
	s.Parent = parent or SoundService
	s:Play()
	return s, r[3]
end

-- ── hearing protection (M16): the server sets Gear_ears on the character from the worn headset item ─────────
local function headset()
	local me = Players.LocalPlayer.Character
	return me ~= nil and me:GetAttribute("Gear_ears") ~= nil
end
Effects.headset = headset

-- ── deafness (blasts, stun charges): world sounds muffled and quieter, ears ringing ───────────────────────
function Effects.deafLevel()
	local left = deaf.untilT - os.clock()
	if left <= 0 then
		return 0
	end
	return deaf.amt * math.clamp(left / deaf.span, 0, 1)
end

function Effects.deafen(amount, dur)
	-- an active headset clamps blast and stun-charge noise
	amount = math.clamp((amount or 0) * (headset() and 0.55 or 1), 0, 1)
	if amount <= 0.01 then
		return
	end
	if amount >= Effects.deafLevel() then
		deaf.amt = amount
		deaf.untilT = os.clock() + dur
		deaf.span = math.min(dur, 3)
	else
		deaf.untilT = math.max(deaf.untilT, os.clock() + dur * 0.5)
	end
	if not tinnitus then
		tinnitus, tinnitusGain = Effects.loop("tinnitus_loop", SoundService, true)
	end
end

local function updateDeaf()
	local k = Effects.deafLevel()
	if deafEq then
		deafEq.Enabled = k > 0.01
		deafEq.HighGain = -40 * k
		deafEq.MidGain = -24 * k
		deafEq.LowGain = -6 * k
	end
	if world then
		world.Volume = (1 - 0.5 * k) * (ctx.Settings.fxVolume and ctx.Settings.fxVolume() or 1)
	end
	if tinnitus then
		tinnitus.Volume = (tinnitusGain or 0.5) * 1.2 * k
	end
end

-- a blast at pos: the close crack and debris, or the low boom from far away
function Effects.explosion(pos, kind)
	local cam = workspace.CurrentCamera
	local d = cam and (cam.CFrame.Position - pos).Magnitude or 0
	if kind == "stun" then
		Effects.sfx("flashbang", pos, 1, 1, 700)
		return
	end
	if kind == "smoke" then
		Effects.sfx("smoke_pop", pos, 0.8, 1, 90)
		return
	end
	if d < 150 then
		Effects.sfx("explosion_near", pos, 1, 0.97 + math.random() * 0.06, 900)
		if d < 70 then
			task.delay(0.25, function()
				Effects.sfx("explosion_debris", pos, 0.8, 1, 80)
			end)
		end
	else
		Effects.sfx("explosion_far", pos, 1, 0.97 + math.random() * 0.06, 1500)
	end
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
	if not own and model and model:GetAttribute("SilentSteps") then
		-- THE FORESTER (Tarkov's Partisan) makes no footstep sound: only the grass rustles under him, faintly
		if fam ~= "dirt" then
			return
		end
		name = math.random() < 0.5 and "cloth_1" or "cloth_2"
		vol *= 0.35
	end
	local speed = 0.94 + math.random() * 0.12
	if own then
		Effects.sfx(name, SoundService, vol, speed)
	else
		-- an active headset lifts quiet sounds: other people's steps are louder and carry further
		local hs = headset()
		Effects.sfx(name, hit and hit.Position or pos, vol * (hs and 1.35 or 1), speed, (30 + intensity * 70) * (hs and 1.3 or 1))
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
	-- the stationary guns (Stationary): the same recorded shot pitched down, louder
	HMG12 = { s = 0.52, v = 1.0 }, AGL30 = { s = 0.62, v = 1.0 },
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

-- muzzle flash: a small round glow and a short light. size: the glow's diameter (first person passes a smaller
-- one, since the viewmodel muzzle sits right in front of the camera)
function Effects.flash(pos, size)
	size = size or 0.22
	local part = tmpPart(Vector3.new(size, size, size), CFrame.new(pos), Color3.fromHex("FFD9A0"), Enum.Material.Neon, 0.3)
	part.Shape = Enum.PartType.Ball
	local l = Instance.new("PointLight")
	l.Color = Color3.fromHex("FFC98A")
	l.Range = 9
	l.Brightness = 1.6
	l.Parent = part
	fade(part, 0.045)
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
	-- bullet passing close by: supersonic crack where it passed (Tarkov-style shot awareness); a subsonic round has none
	if cam and dist > 18 and not d.sub then
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
	world = SoundService:FindFirstChild("ZR_World")
	if not world then
		world = Instance.new("SoundGroup")
		world.Name = "ZR_World"
		world.Volume = 1
		world.Parent = SoundService
	end
	deafEq = world:FindFirstChild("Deafen") or Instance.new("EqualizerSoundEffect")
	deafEq.Name = "Deafen"
	deafEq.Enabled = false
	deafEq.Parent = world
	if c.State.fx then
		c.State.fx.OnClientEvent:Connect(function(kind, d)
			if kind == "shot" and type(d) == "table" then
				Effects.remoteShot(d)
			elseif kind == "sfx" and type(d) == "table" and type(d.n) == "string" and typeof(d.p) == "Vector3" then
				Effects.sfx(d.n, d.p, d.v or 0.8, 1, 60)
			elseif kind == "flare" and AirdropFx and type(d) == "table" then
				local ok, err = pcall(AirdropFx.flare, d)
				if not ok then
					warn("[ZR] flare fx:", err)
				end
			elseif kind == "airdrop" and AirdropFx and type(d) == "table" then
				local ok, err = pcall(AirdropFx.run, d)
				if not ok then
					warn("[ZR] airdrop fx:", err)
				end
			elseif kind == "glass" and GlassFx and type(d) == "table" then
				local ok, err = pcall(GlassFx.burst, d)
				if not ok then
					warn("[ZR] glass fx:", err)
				end
			end
		end)
	end
	if AirdropFx then
		AirdropFx.init(c, Effects)
	end
	if LaserFx then
		local okLaser, errLaser = pcall(LaserFx.init, c)
		if not okLaser then
			warn("[ZR] LaserFx init:", errLaser)
		end
	end
	if GlassFx then
		local okGlass, errGlass = pcall(GlassFx.init, c, Effects)
		if not okGlass then
			warn("[ZR] GlassFx init failed:", errGlass)
		end
	end
	RunService.Heartbeat:Connect(function()
		updateDeaf()
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
		amb.SoundGroup = world
		amb.Parent = SoundService
		amb:Play()
		Effects.ambience = amb -- Atmos mixes it with weather and time of day
	end
end

return Effects
