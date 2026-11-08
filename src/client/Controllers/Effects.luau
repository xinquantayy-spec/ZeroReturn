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
local Hearing = require(Shared.Hearing)
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
-- world sounds through the Audio API with Acoustic Simulation (gameplay-3a); without it the legacy path below
local okWorldAudio, WorldAudio = pcall(require, script.Parent.WorldAudio)
if not okWorldAudio then
	warn("[ZR] WorldAudio failed to load:", WorldAudio)
	WorldAudio = nil
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

-- the scripted occlusion (gameplay-3's option b, ours): where Acoustic Simulation is off (POTATO, the maps not yet
-- piloted) a world sound counts the walls between it and the camera once, as it starts, and each one muffles it
local occParams = RaycastParams.new()
occParams.FilterType = Enum.RaycastFilterType.Include
occParams.RespectCanCollide = true
occParams.IgnoreWater = true
Effects.OCCLUDE = { vol = 0.25, high = -12, mid = -5, max = 3 } -- near the 17 dB a wall takes off in WorldAudio
function Effects.wallsBetween(at)
	local cam = workspace.CurrentCamera
	local map = workspace:FindFirstChild("ZR_World") -- the raid map and the bunker
	if not (cam and map) then
		return 0
	end
	occParams.FilterDescendantsInstances = { map }
	local from = cam.CFrame.Position
	local n = 0
	for _ = 1, Effects.OCCLUDE.max do
		local d = at - from
		if d.Magnitude < 1 then
			break
		end
		local hit = workspace:Raycast(from, d, occParams)
		if not hit then
			break
		end
		n += 1
		from = hit.Position + d.Unit * 0.6 -- on through the wall
	end
	return n
end

local function occlude(s, at)
	local n = Effects.wallsBetween(at)
	if n > 0 then
		local O = Effects.OCCLUDE
		s.Volume *= O.vol ^ n
		local e = Instance.new("EqualizerSoundEffect")
		e.Name = "Occlusion"
		e.HighGain = O.high * n
		e.MidGain = O.mid * n
		e.LowGain = 0
		e.Parent = s
	end
end

-- opts: min, max (roll-off distances), eq = { low, mid, high } dB (a suppressor's muffle)
function Effects.sound(id, at, volume, speed, opts)
	if not id or id == "" then
		return
	end
	local minD, maxD = (opts and opts.min) or 12, (opts and opts.max) or 600
	if typeof(at) == "Vector3" and WorldAudio and WorldAudio.on then
		return WorldAudio.play(id, at, volume or 0.6, speed or 1, nil, minD, maxD, opts and opts.eq, 6)
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = maxD
	s.RollOffMinDistance = minD
	s.SoundGroup = world
	if opts and opts.eq then
		local e = Instance.new("EqualizerSoundEffect")
		e.LowGain, e.MidGain, e.HighGain = opts.eq[1], opts.eq[2], opts.eq[3]
		e.Parent = s
	end
	if typeof(at) == "Vector3" then
		occlude(s, at)
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
			return Effects.sound(Sounds[big[1]], at, (volume or 0.6) * big[3], (speed or 1) * big[2], { min = 30, max = maxDist or 600 })
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
	local minD, maxD = (maxDist and maxDist > 300) and 30 or 5, maxDist or 120
	if positional and WorldAudio and WorldAudio.on then
		live3d += 1
		local life = r[2] / (speed or 1) + 0.25
		task.delay(life, function()
			live3d -= 1
		end)
		return WorldAudio.play(id, at, (volume or 0.6) * r[3], speed or 1, NumberRange.new(r[1], r[1] + r[2]), minD, maxD, nil, life)
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(r[1], r[1] + r[2])
	s.Volume = (volume or 0.6) * r[3]
	s.PlaybackSpeed = speed or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = minD
	s.RollOffMaxDistance = maxD
	s.SoundGroup = world
	local life = r[2] / (speed or 1) + 0.25
	if positional then
		occlude(s, at)
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

-- written only when the deafness or the effects volume changes (audit tech.12: no per-frame writes of unchanged values)
local deafShown, volShown = -1, -1
local function updateDeaf()
	local k = Effects.deafLevel()
	local fxVol = ctx.Settings.fxVolume and ctx.Settings.fxVolume() or 1
	if fxVol == volShown and (k == deafShown or (k > 0 and math.abs(k - deafShown) < 0.002)) then
		return -- (the last step down to 0 is always written)
	end
	deafShown, volShown = k, fxVol
	if deafEq then
		deafEq.Enabled = k > 0.01
		deafEq.HighGain = -40 * k
		deafEq.MidGain = -24 * k
		deafEq.LowGain = -6 * k
	end
	if world then
		world.Volume = (1 - 0.5 * k) * fxVol
	end
	if WorldAudio then
		WorldAudio.setMix(k, fxVol)
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

-- the listener's own skills (Perception) from the profile the server sends
local function mySkills()
	local d = ctx and ctx.State.data
	local econ = d and d.econ
	return econ and econ.skills
end

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
	local gearReach = 1
	if own then
		Effects.sfx(name, SoundService, vol, speed)
	else
		-- an active headset lifts quiet sounds: other people's steps are louder and carry further
		local hs = headset()
		-- how far steps carry (Hearing.stepRadius: Tarkov's distances, then the skills, audit gameplay.9): the listener's
		-- Perception and the walker's Covert Movement on this surface, his level from the SkillCovert attribute the
		-- server sets (Chars.syncSkills); his kit's rattle carries less far by the same skill
		local level = model and model:GetAttribute("SkillCovert")
		local skills = mySkills()
		gearReach = Hearing.perceptionReach(skills) * (1 - Hearing.covertQuiet(level, nil))
		Effects.sfx(name, hit and hit.Position or pos, vol * (hs and 1.35 or 1), speed, Hearing.stepRadius(intensity, hs, skills, level, fam))
	end
	-- an overweight walker's kit rattles more often, louder and further (Tarkov 0.12.4: overweight brings "increased
	-- equipment noise"; the server's Overweight attribute, Chars.luau; ours: how much more)
	local ow = 0
	if own then
		local M, L = ctx.Movement, ctx.Movement and ctx.Movement.limits
		ow = (M and L and ((M.weight > L.crit and 2) or (M.weight > L.over and 1))) or 0
	elseif model then
		ow = model:GetAttribute("Overweight") or 0
	end
	if (intensity > 0.9 and math.random() < 0.35 + 0.2 * ow) or (ow > 0 and intensity > 0.45 and math.random() < 0.25 * ow) then
		Effects.sfx("gear_rattle", own and SoundService or pos, vol * 0.5 * (1 + 0.3 * ow), 1, 40 * gearReach * (1 + 0.4 * ow))
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
	R17 = { s = 1.0, v = 0.9 }, KST = { s = 0.9, v = 0.95 }, KSL = { s = 0.86, v = 1.0 }, GL6 = { s = 0.42, v = 0.75 }, SPARROW = { s = 1.16, v = 0.8 },
	HARROW = { s = 0.68, v = 1.0 }, TUNDRA = { s = 0.78, v = 1.0 }, P9 = { s = 1.28, v = 0.72 },
	KS74 = { s = 0.98, v = 0.92 }, PM = { s = 1.36, v = 0.66 }, SKS = { s = 0.88, v = 0.98 }, SVD = { s = 0.74, v = 1.0 }, -- economy-1a's third slice: the 5.4 cracks sharper than the 7.6, the 9x18 pops
	-- the stationary guns (Stationary): the same recorded shot pitched down, louder
	HMG12 = { s = 0.52, v = 1.0 }, AGL30 = { s = 0.62, v = 1.0 },
}
function Effects.gunSound(weapon, at, suppressed, distant, volMul)
	local g = GUN[weapon] or GUN.R17
	local id = (distant and not suppressed and Sounds.R17_FIRE_FAR ~= "") and Sounds.R17_FIRE_FAR or Sounds.R17_FIRE
	local vol = g.v * (suppressed and 0.32 or 1) * (volMul or 1)
	local speed = g.s * (suppressed and 1.18 or 1) * (1 + (math.random() - 0.5) * 0.05)
	-- a suppressor: shorter reach and the highs cut
	return Effects.sound(id, at, vol, speed, suppressed and { max = 220, eq = { 2, -6, -20 } } or nil)
end

-- tracer colours (economy-1a: EFT's tracers burn red or green; anything else draws the old pale trace)
local TRACER = { red = Color3.fromHex("FF6A4A"), green = Color3.fromHex("8CFF7A") }

function Effects.tracer(o, p, colour)
	local d = p - o
	local len = d.Magnitude
	if len < 1 then
		return
	end
	local seg = math.min(len, 14)
	local start = o + d.Unit * math.min(2, len * 0.1)
	local part = tmpPart(Vector3.new(0.06, 0.06, seg), CFrame.lookAt(start + d.Unit * seg / 2, p), TRACER[colour or ""] or Color3.fromHex("F3E2B4"), Enum.Material.Neon, 0.35)
	fade(part, 0.07)
end

-- muzzle flash: a small round glow and a short light. size: the glow's diameter (first person passes a smaller
-- one, since the viewmodel muzzle sits right in front of the camera)
-- the muzzle flash (audit art.3): a hot core, a star of flame for two or three frames along the shot, sized by the muzzle
-- device (kind: a brake 1.35, a flash hider 0.55, a suppressor 0), and a wisp of smoke that drifts off. Textures are
-- Roblox's own particle images.
local function burst(pos, dir, props, n)
	local p = tmpPart(Vector3.new(0.1, 0.1, 0.1), dir and CFrame.lookAt(pos, pos + dir) or CFrame.new(pos), Color3.new(1, 1, 1), nil, 1)
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		e[k] = v
	end
	e.Rate = 0
	e.Parent = p
	e:Emit(n)
	task.delay(1.6, function()
		p:Destroy()
	end)
	return p
end

function Effects.flash(pos, size, dir, kind)
	size = size or 0.22
	local k = type(kind) == "number" and kind or 1
	local cam = workspace.CurrentCamera
	local near = not cam or (cam.CFrame.Position - pos).Magnitude < 150
	if k > 0 then
		local part = tmpPart(Vector3.new(size, size, size) * k, CFrame.new(pos), Color3.fromHex("FFD9A0"), Enum.Material.Neon, 0.3)
		part.Shape = Enum.PartType.Ball
		-- the light only near the camera (audit tech.6): a flash 150 studs off lights nothing anyone can see
		if near then
			local l = Instance.new("PointLight")
			l.Color = Color3.fromHex("FFC98A")
			l.Range = 9 * k
			l.Brightness = 1.6
			l.Parent = part
		end
		fade(part, 0.045)
		if near and quality() >= 1 then
			-- the star: flame facing every way for 0.03 to 0.06 s, pushed out along the barrel
			burst(pos, dir, {
				Texture = "rbxasset://textures/particles/fire_main.dds", LightEmission = 1, LightInfluence = 0,
				Color = ColorSequence.new(Color3.fromHex("FFE2B0"), Color3.fromHex("FF9A3C")),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 4.5 * k), NumberSequenceKeypoint.new(1, size * 2 * k) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(0.03, 0.06), Speed = NumberRange.new(dir and 6 or 0, dir and 14 or 2),
				SpreadAngle = Vector2.new(dir and 12 or 180, dir and 12 or 180), EmissionDirection = Enum.NormalId.Front,
				Rotation = NumberRange.new(0, 360), ZOffset = 1,
			}, 3)
		end
	end
	if near and quality() >= 2 then
		-- the wisp of smoke, suppressed or not
		burst(pos, dir, {
			Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromHex("B9B4AA")),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1.1) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0.6, 1.6), SpreadAngle = Vector2.new(20, 20),
			EmissionDirection = Enum.NormalId.Front, Acceleration = Vector3.new(0, 1.2, 0), Rotation = NumberRange.new(0, 360),
		}, 2)
	end
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

-- what a bullet throws up, by what it hits (audit art.4): sparks off metal, splinters off wood, dirt and a dust ring off
-- the ground, grit and dust off concrete and stone, a splash off water; a body gives a dark red puff (art-7a)
local IMPACT = {
	metal = { tex = "rbxasset://textures/particles/sparkles_main.dds", color = { "FFE9B0", "FF9E3A" }, size = { 0.12, 0.02 }, life = { 0.15, 0.35 }, speed = { 12, 22 }, spread = 55, n = 8, light = 1, grav = -60, dust = "8C8984" },
	wood = { tex = "rbxasset://textures/particles/smoke_main.dds", color = { "7A5A3A", "5C4630" }, size = { 0.18, 0.05 }, life = { 0.3, 0.6 }, speed = { 6, 12 }, spread = 40, n = 7, grav = -40, dust = "8E7A62" },
	dirt = { tex = "rbxasset://textures/particles/smoke_main.dds", color = { "5E5244", "4A4136" }, size = { 0.35, 0.12 }, life = { 0.35, 0.7 }, speed = { 6, 12 }, spread = 30, n = 8, grav = -50, dust = "7C7262" },
	gravel = { tex = "rbxasset://textures/particles/smoke_main.dds", color = { "77736C", "5D5A55" }, size = { 0.2, 0.06 }, life = { 0.3, 0.6 }, speed = { 8, 14 }, spread = 40, n = 7, grav = -55, dust = "908B83" },
	concrete = { tex = "rbxasset://textures/particles/smoke_main.dds", color = { "A7A398", "8C887E" }, size = { 0.16, 0.05 }, life = { 0.25, 0.5 }, speed = { 8, 15 }, spread = 40, n = 6, grav = -50, dust = "A7A398" },
	water = { tex = "rbxasset://textures/particles/smoke_main.dds", color = { "C9D4D6", "9FB0B3" }, size = { 0.3, 0.1 }, life = { 0.4, 0.7 }, speed = { 10, 16 }, spread = 15, n = 10, grav = -70, dust = nil },
}
Effects.IMPACT = IMPACT

-- the chipped ring round a bullet hole, by surface
local CHIP = { concrete = "A9A59C", gravel = "9A958C", metal = "C4C0B8", wood = "C29A6B" }

-- ejected cases (audit art.5): client-only, pooled, at most 20 in the world; the shooter's own gun and shooters close
-- by. A small brass cylinder thrown right and back, spinning, settling for a few seconds.
local casings = {}
function Effects.casing(at, right, kind)
	if quality() < 1 then
		return
	end
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - at).Magnitude > 60 then
		return
	end
	local big = kind == "rifle"
	local c = Instance.new("Part")
	c.Name = "Casing"
	c.Shape = Enum.PartType.Cylinder
	c.Size = big and Vector3.new(0.17, 0.045, 0.045) or Vector3.new(0.09, 0.04, 0.04)
	c.Color = kind == "shell" and Color3.fromHex("8E2C24") or Color3.fromHex("B8913E")
	c.Material = Enum.Material.Metal
	c.CanCollide = true
	c.CanQuery = false
	c.CanTouch = false
	c.Massless = false
	c.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.4, 0.35) -- light: it never shoves anyone
	c.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
	c.Parent = fx
	local r = (right and right.Magnitude > 0) and right.Unit or Vector3.xAxis
	c.AssemblyLinearVelocity = r * (6 + math.random() * 3) + Vector3.new(0, 5 + math.random() * 2, 0)
	c.AssemblyAngularVelocity = Vector3.new(math.random(-30, 30), math.random(-30, 30), math.random(-30, 30))
	table.insert(casings, c)
	if #casings > 20 then
		local old = table.remove(casings, 1)
		if old then
			old:Destroy()
		end
	end
	task.delay(6, function()
		if c.Parent then
			c.Anchored = true -- lies where it fell, no physics cost
		end
	end)
	task.delay(20, function()
		local i = table.find(casings, c)
		if i then
			table.remove(casings, i)
		end
		c:Destroy()
	end)
end

-- light blood (decision art-7a): a body hit leaves a small dark mark on the wall or floor behind it, where the round would
-- carry on, and now and then a drop on the floor under it. Small, few and fading (Roblox's "light realistic blood",
-- the Moderate maturity label the owner chooses when publishing): no pools, no sprays. Three overlapping discs of
-- different sizes, so a mark reads as a splat; at most 30, each gone after 40 s. Not on bodies (they move).
local bloodMarks = {}
local bloodParams = RaycastParams.new()
bloodParams.FilterType = Enum.RaycastFilterType.Include
bloodParams.RespectCanCollide = true
Effects.BLOOD = { reach = 7, max = 30, life = 40, drop = 0.35 }
local function bloodMark(at, normal, size)
	local B = Effects.BLOOD
	local face = CFrame.lookAt(at + normal * 0.014, at + normal * 2) * CFrame.Angles(0, math.pi / 2, 0)
	local base = tmpPart(Vector3.new(0.02, size, size), face, Color3.fromHex("4A110E"), Enum.Material.SmoothPlastic, 0.2)
	base.Name = "BloodMark"
	base.Shape = Enum.PartType.Cylinder
	for i = 1, 2 do
		local r = size * (0.35 + math.random() * 0.25)
		local off = Vector3.new(0.004 * i, (math.random() - 0.5) * size * 0.7, (math.random() - 0.5) * size * 0.7)
		local blob = tmpPart(Vector3.new(0.02, r, r), face * CFrame.new(off), Color3.fromHex(i == 1 and "380B09" or "561510"), Enum.Material.SmoothPlastic, 0.15)
		blob.Shape = Enum.PartType.Cylinder
		blob.Parent = base
	end
	table.insert(bloodMarks, base)
	if #bloodMarks > B.max then
		table.remove(bloodMarks, 1):Destroy()
	end
	task.delay(B.life, function()
		local i = table.find(bloodMarks, base)
		if i then
			table.remove(bloodMarks, i)
		end
		base:Destroy()
	end)
end

function Effects.blood(pos, dir)
	local world = workspace:FindFirstChild("ZR_World")
	if not world or quality() < 1 then
		return
	end
	local B = Effects.BLOOD
	bloodParams.FilterDescendantsInstances = { world }
	if dir and dir.Magnitude > 0.01 then
		local hit = workspace:Raycast(pos, dir.Unit * B.reach, bloodParams)
		if hit then
			bloodMark(hit.Position, hit.Normal, 0.35 + math.random() * 0.35)
		end
	end
	if math.random() < B.drop then
		local down = workspace:Raycast(pos, Vector3.new((math.random() - 0.5) * 0.6, -8, (math.random() - 0.5) * 0.6), bloodParams)
		if down and down.Normal.Y > 0.6 then
			bloodMark(down.Position, down.Normal, 0.18 + math.random() * 0.15)
		end
	end
end

-- dir: the round's direction (where a body hit's blood carries)
function Effects.impact(pos, normal, isBody, material, dir)
	if isBody then
		Effects.blood(pos, dir)
	end
	local fam = isBody and "body" or (material == Enum.Material.Water and "water") or (material and Effects.surfaceOf(material)) or "concrete"
	local q = quality()
	if q >= 2 or isBody then
		local cf = normal and CFrame.lookAt(pos, pos + normal) or CFrame.new(pos)
		if isBody then
			burst(pos, normal, {
				Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromHex("5A1C18"), Color3.fromHex("3A1512")),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.9) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(0.25, 0.5), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(30, 30),
				EmissionDirection = Enum.NormalId.Front,
			}, q >= 3 and 6 or 4)
		else
			local f = IMPACT[fam] or IMPACT.concrete
			-- the bits: fast, thrown out of the surface, falling
			burst(pos, normal, {
				Texture = f.tex, LightEmission = f.light or 0, Color = ColorSequence.new(Color3.fromHex(f.color[1]), Color3.fromHex(f.color[2])),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, f.size[1]), NumberSequenceKeypoint.new(1, f.size[2]) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(f.life[1], f.life[2]), Speed = NumberRange.new(f.speed[1], f.speed[2]),
				SpreadAngle = Vector2.new(f.spread, f.spread), EmissionDirection = Enum.NormalId.Front, Acceleration = Vector3.new(0, f.grav, 0),
				Drag = 2, Rotation = NumberRange.new(0, 360),
			}, q >= 3 and f.n or math.ceil(f.n / 2))
			-- and the dust cloud that hangs a moment
			if f.dust then
				burst(pos, normal, {
					Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromHex(f.dust)),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.4) }),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
					Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1.5, 4), SpreadAngle = Vector2.new(25, 25),
					EmissionDirection = Enum.NormalId.Front, Drag = 3,
				}, q >= 3 and 5 or 3)
			end
		end
		local _ = cf
	end
	if not isBody and normal and fam ~= "water" and fam ~= "dirt" then
		-- the hole (audit art.4): a chipped ring in the surface's own light colour round a dark core. (The wear set's
		-- "old bullet holes" decal is a strip of holes and read as a smear on a single hit, checked in Studio.)
		local ring = CHIP[fam] or CHIP.concrete
		local face = CFrame.lookAt(pos + normal * 0.012, pos + normal * 2) * CFrame.Angles(0, math.pi / 2, 0)
		local m = tmpPart(Vector3.new(0.02, 0.32, 0.32), face, Color3.fromHex(ring), Enum.Material.SmoothPlastic, 0.25)
		m.Shape = Enum.PartType.Cylinder
		local core = tmpPart(Vector3.new(0.02, 0.13, 0.13), face * CFrame.new(0.006, 0, 0), Color3.fromHex("161614"), Enum.Material.SmoothPlastic, 0)
		core.Shape = Enum.PartType.Cylinder
		core.Parent = m
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
	-- a suppressed shot shows no flash, only its wisp of smoke; the shooter's device is not sent, so a bare muzzle's size
	local shotDir = (d.p - d.o).Magnitude > 0.01 and (d.p - d.o).Unit or nil
	Effects.flash(d.o, nil, shotDir, d.s and 0 or 1)
	if d.l then
		-- a grenade launcher (ai-5b): the round flies as a grenade (Grenade.luau draws it); here the flash and the thump
		local cam = workspace.CurrentCamera
		local dist = cam and (cam.CFrame.Position - d.o).Magnitude or 0
		Effects.gunSound(type(d.w) == "string" and d.w or "GL6", d.o, false, dist > 160, d.ai and 0.85 or 0.95)
		return
	end
	if shotDir then
		-- the shooter's case, out to his right (Effects.casing keeps it to shooters within 60 studs)
		local right = shotDir:Cross(Vector3.yAxis)
		Effects.casing(d.o - shotDir * 1.2 + right * 0.15, right, (d.w == "HARROW" and "shell") or ((d.w == "SPARROW" or d.w == "P9") and "pistol") or "rifle")
	end
	if d.t then
		Effects.tracer(d.o, d.p, d.t) -- tracer rounds only (Tarkov), in their colour
	end
	Effects.impact(d.p, d.n, d.h, typeof(d.m) == "EnumItem" and d.m or nil, shotDir)
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
	-- beyond the shot's own sound: the distant boom from its direction (audit gameplay.13; suppressed shots stay unheard)
	if dist > 560 and not d.s and ctx.Ambience and ctx.Ambience.farShot then
		ctx.Ambience.farShot(d.o)
	end
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
	if WorldAudio then
		local okWA, errWA = pcall(WorldAudio.init, c)
		if not okWA then
			warn("[ZR] WorldAudio init failed:", errWA)
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
