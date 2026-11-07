--!nonstrict
-- Ambience (atmosphere pass, client-only, cheap by design): the sound of the place you stand in.
--   Space and reverb: every 0.4 s up to 8 raycasts around the camera (a roof above, the floor under the feet, six rays round:
--   level ones on one probe, ones tilted up on the next) sort the place into outdoors / courtyard / hangar-size hall / hall /
--   car park / corridor / room, and SoundService.AmbientReverb follows (Tarkov: indoor sounds sound indoors). A class needs two
--   probes in a row to take over and a class we are in is easier to stay in, so the reverb never flickers. A floor part can name
--   its own reverb with the attribute Reverb (Meridian marks the floors of its washrooms, service tunnel and shelter rooms).
--   Graphics: POTATO has no reverb at all, LOW only indoors, MEDIUM and HIGH everywhere.
--   Layers (the ZR_Ambient sound group, so the player's ambience slider rules them): room tone indoors, car park tone in the car
--   park, the mains and fluorescent hum while Meridian's mall has power (replicated attribute ZR_Sw_MALL_POWER) and in the
--   bunker, water drips indoors (every 8 to 25 s, pooled sounds placed in line of sight), distant gunfire in raids (every 40 to
--   120 s, far and faint, fainter indoors). Rain and wind stay Atmos's. At most five of these sound at once, and a layer that
--   has faded out is paused.
--   Dust in the light: at most 6 particle emitters, a few motes a second, under the skylights (tag ZR_Skylight) near the camera,
--   by day and only at graphics MEDIUM and up.
--   Cost: one addition and a compare per frame; a layer step 12 times a second; a probe 2.5 times a second; a dust scan every
--   1.2 s. No Instance.new after the pools are built. While Sounds.AMB_ATLAS is empty the sounds are never created (reverb and
--   dust still work); with the ambience volume at 0 every layer fades out and pauses, and no drip or gunshot is started.
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local AmbSound = require(Shared.AmbSound)
local Textures = require(Shared.Textures)
local Env = require(Shared.Env)

local Ambience = {
	space = "outdoors", enclosed = 0, inMall = false, powered = false, reverb = "NoReverb", silent = true, rays = 0, probes = 0,
}
local ctx

local PROBE_EVERY = 0.4 -- seconds between space probes (8 rays each)
local STEP_EVERY = 0.08 -- seconds between layer updates
local REACH = 70 -- level rays, studs
local REACH_T = 80 -- tilted rays
local REACH_UP = 90 -- the roof
local REACH_DOWN = 16 -- the floor
local TILT = math.rad(32)

-- Sound.Volume of a layer at full weight, before the atlas gain and the player's ambience slider. Chosen from the A-weighted
-- loudness of each loop against the existing beds (steps about -39 dBFS, wind about -42, these about -43 to -47): NOT tuned by
-- ear, expect to move them.
local LAYERS = {
	room = { name = "room_tone_loop", vol = 0.11 },
	garage = { name = "garage_tone_loop", vol = 0.22 },
	hum = { name = "elec_hum_loop", vol = 0.085 },
}
local DRIP_VOL, GUN_VOL = 0.09, 0.25

-- Enum.ReverbType per class. NOT checked by ear: the biggest halls (Meridian's anchor halls, 28 studs high and hundreds wide) get
-- Auditorium (about 4 s of tail); "Hangar" (about 10 s) is a one-word change here if that turns out too tame.
local REVERB_OF = {
	outdoors = "Plain", alley = "Alley", hangar = "Auditorium", hall = "StoneRoom", carpark = "ParkingLot", corridor = "Hallway", room = "Room",
}
local MARK_CLASS = { ParkingLot = "carpark" } -- a floor mark that is also one of the plain classes

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
local FILTER = {}
local UP = Vector3.new(0, REACH_UP, 0)
local DOWN = Vector3.new(0, -REACH_DOWN, 0)
local EYE_DROP = Vector3.new(0, -1, 0)

-- six directions 60 degrees apart (offset by `offset`), as unit vectors on the ground plane and as ray vectors
local function makeRing(offset, tilted)
	local dirs, vecs = {}, {}
	local c, s, reach = 1, 0, REACH
	if tilted then
		c, s, reach = math.cos(TILT), math.sin(TILT), REACH_T
	end
	for i = 0, 5 do
		local a = offset + i * math.pi / 3
		dirs[i + 1] = Vector3.new(math.cos(a), 0, math.sin(a))
		vecs[i + 1] = Vector3.new(math.cos(a) * c, s, math.sin(a) * c) * reach
	end
	return { dirs = dirs, vecs = vecs, tilted = tilted }
end
-- level, tilted, level (turned 30 degrees), tilted (turned back): every direction is seen within 1.6 s
local RINGS = { makeRing(0, false), makeRing(math.pi / 6, true), makeRing(math.pi / 6, false), makeRing(0, true) }

local S = {
	tick = 0, first = true, cur = "outdoors", cand = nil, candN = 0,
	roofH = nil, roofInst = nil, floorD = nil, floorY = nil, mark = nil,
	dist = { REACH, REACH, REACH, REACH, REACH, REACH }, dirs = RINGS[1].dirs,
	dmean = nil, blocked = nil, wmin = nil, wmax = nil, cover = nil,
	inMall = false, powered = false,
}

-- ── small helpers ────────────────────────────────────────────────────────────────────────────────────────────
local function ema(old, new, a)
	if old == nil then
		return new
	end
	return old + (new - old) * a
end

local enumCache = {}
local function reverbEnum(name)
	if type(name) ~= "string" then
		return nil
	end
	local e = enumCache[name]
	if e == nil then
		local ok, v = pcall(function()
			return Enum.ReverbType[name]
		end)
		e = (ok and v) or false
		enumCache[name] = e
	end
	return e or nil
end

local function isIndoor(cls)
	return cls ~= "outdoors" and cls ~= "alley"
end

local ambGroupCache
local function ambGroup()
	if not ambGroupCache or not ambGroupCache.Parent then
		ambGroupCache = SoundService:FindFirstChild("ZR_Ambient")
	end
	return ambGroupCache
end

-- the mall: a roof part that belongs to Meridian's Mall model, or to one of its store models (a lamp or a fixture under a store
-- ceiling is the stores'), means we stand inside the building
local MALL_MODELS = { Mall = true, StoresL1 = true, StoresL2 = true }
local meridian, meridianCheckAt = nil, 0
local function findMeridian()
	if meridian and meridian.Parent then
		return meridian
	end
	local now = os.clock()
	if now < meridianCheckAt then
		return nil
	end
	meridianCheckAt = now + 4
	local w = workspace:FindFirstChild("ZR_World")
	meridian = w and w:FindFirstChild("Meridian") or nil
	return meridian
end
local function underMall(inst)
	local m = findMeridian()
	if not m or not inst then
		return false
	end
	local p = inst
	while p do
		local up = p.Parent
		if up == m then
			return MALL_MODELS[p.Name] == true
		end
		p = up
	end
	return false
end

-- ── space probe ──────────────────────────────────────────────────────────────────────────────────────────────
local function setFilter(cam)
	table.clear(FILTER)
	local function add(x)
		if x then
			FILTER[#FILTER + 1] = x
		end
	end
	add(cam)
	for _, p in Players:GetPlayers() do
		add(p.Character)
	end
	add(workspace:FindFirstChild("ZR_Fx"))
	add(workspace:FindFirstChild("ZR_Rain"))
	add(workspace:FindFirstChild("ZR_Dust"))
	add(workspace:FindFirstChild("ZR_AI"))
	add(workspace:FindFirstChild("ZR_Corpses"))
	add(workspace:FindFirstChild("ZR_Loot"))
	add(workspace:FindFirstChild("ZR_Loose"))
	params.FilterDescendantsInstances = FILTER
end

-- which kind of place the latest measurements describe; `cur` is the class we are in (it is easier to stay in)
local function classify(cur)
	local under = S.roofH ~= nil
	local cover, blocked = S.cover or 0, S.blocked or 0
	local sticky = (isIndoor(cur) and 0.75) or 1
	-- a roof over us that goes on (tilted rays reach a ceiling) or walls round us: inside; a porch or an awning is not
	local indoors = under and (cover >= 3 * sticky or blocked >= 3 * sticky)
	local dmean = S.dmean or REACH
	if not indoors then
		if blocked >= 4.5 and dmean < 26 * ((cur == "alley" and 1.25) or 1) then
			return "alley"
		end
		return "outdoors"
	end
	if S.mark then
		return MARK_CLASS[S.mark] or ("mark:" .. S.mark)
	end
	local wmin, wmax = S.wmin or (2 * REACH), S.wmax or (2 * REACH)
	local H = (S.roofH and S.floorD) and (S.roofH + S.floorD) or nil -- floor to ceiling
	local function keep(c)
		return (cur == c and 1.2) or 1
	end
	-- a car park: a low flat ceiling over a wide open floor (Meridian's L0 is 16.25 high; a 40 x 60 x 14 hall is not open enough)
	if H and H < 19 * keep("carpark") and dmean >= 28 / keep("carpark") and wmin >= 30 / keep("carpark") then
		return "carpark"
	end
	if wmin < 24 * keep("corridor") and wmax > 2.4 * wmin and dmean >= 9 then
		return "corridor"
	end
	if dmean < 16 * keep("room") then
		return "room"
	end
	if H and H >= 21 and dmean >= 34 / keep("hangar") then
		return "hangar"
	end
	if dmean >= 20 / keep("hall") then
		return "hall"
	end
	return "room"
end

local function applyReverb()
	local cls = S.cur
	local name = REVERB_OF[cls]
	if string.sub(cls, 1, 5) == "mark:" then
		name = string.sub(cls, 6)
	end
	local q = (ctx.Settings and ctx.Settings.data and ctx.Settings.data.quality) or 3
	if q <= 0 or (q == 1 and not isIndoor(cls)) then
		name = "NoReverb" -- POTATO: no reverb DSP at all; LOW: only where it is plainly indoors
	end
	local e = reverbEnum(name or "NoReverb")
	if e and SoundService.AmbientReverb ~= e then
		SoundService.AmbientReverb = e
	end
	Ambience.reverb = name or "NoReverb"
	Ambience.space = cls
	Ambience.enclosed = isIndoor(cls) and 1 or 0
end

local function probe()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	setFilter(cam)
	local o = cam.CFrame.Position
	S.tick += 1
	local ring = RINGS[(S.tick - 1) % 4 + 1]
	local rays = 2
	-- the roof above and the floor under the camera
	local up = workspace:Raycast(o, UP, params)
	local dn = workspace:Raycast(o, DOWN, params)
	S.roofH = up and up.Distance or nil
	S.roofInst = up and up.Instance or nil
	S.floorD = dn and dn.Distance or nil
	S.mark = nil
	if dn then
		S.floorY = dn.Position.Y
		local mark = dn.Instance:GetAttribute("Reverb")
		if type(mark) == "string" and reverbEnum(mark) then
			S.mark = mark
		end
	end
	if ring.tilted then
		-- how far the roof goes on: tilted rays that end on a ceiling
		local covered = 0
		for i = 1, 6 do
			local hit = workspace:Raycast(o, ring.vecs[i], params)
			rays += 1
			if hit and hit.Position.Y > o.Y + 1 and hit.Normal.Y < -0.25 then
				covered += 1
			end
		end
		S.cover = ema(S.cover, covered, 0.6)
	else
		-- how far the walls are
		local base = o + EYE_DROP
		local ds, ns, sum, blocked = {}, {}, 0, 0
		for i = 1, 6 do
			local hit = workspace:Raycast(base, ring.vecs[i], params)
			rays += 1
			local d = REACH
			if hit then
				d = hit.Distance
				blocked += 1
				ns[i] = hit.Normal
			end
			ds[i] = d
			sum += d
		end
		S.dist, S.dirs = ds, ring.dirs
		-- the width along each axis counts only between two walls that face each other (a corner is not a narrow room)
		local wmin, wmax = 2 * REACH, 0
		for i = 1, 3 do
			local w = 2 * REACH
			local a, b = ns[i], ns[i + 3]
			if a and b and a:Dot(b) < -0.7 then
				w = ds[i] + ds[i + 3]
			end
			wmin = math.min(wmin, w)
			wmax = math.max(wmax, w)
		end
		S.dmean = ema(S.dmean, sum / 6, 0.55)
		S.blocked = ema(S.blocked, blocked, 0.55)
		S.wmin = ema(S.wmin, wmin, 0.55)
		S.wmax = ema(S.wmax, wmax, 0.55)
	end
	Ambience.rays += rays
	Ambience.probes += 1
	-- the mall: the roof over us belongs to Meridian's Mall or its stores; its power is a replicated attribute (World.luau)
	S.inMall = underMall(S.roofInst)
	S.powered = workspace:GetAttribute("ZR_Sw_MALL_POWER") == true
	Ambience.inMall, Ambience.powered = S.inMall, S.powered
	-- the class, with a debounce: a new class has to win twice in a row (0.8 s)
	local cls = classify(S.cur)
	if S.first then
		S.first, S.cur, S.cand, S.candN = false, cls, nil, 0
	elseif cls == S.cur then
		S.cand, S.candN = nil, 0
	else
		if cls == S.cand then
			S.candN += 1
		else
			S.cand, S.candN = cls, 1
		end
		if S.candN >= 2 then
			S.cur, S.cand, S.candN = cls, nil, 0
		end
	end
	applyReverb()
end

-- ── layers (looped, 2D, crossfaded) ──────────────────────────────────────────────────────────────────────────
for _, L in LAYERS do
	L.v, L.on, L.started, L.snd, L.gain, L.dead = 0, false, false, nil, 0, false
end

local function stepLayer(L, target, k, master)
	L.v += (target - L.v) * k
	if target == 0 and L.v < 0.015 then
		L.v = 0
		if L.on then
			L.on = false
			if L.snd then
				L.snd:Pause() -- inaudible: stop paying for it
			end
		end
		return
	end
	if L.dead then
		return
	end
	if not L.snd then
		L.snd, L.gain = AmbSound.make(L.name, { parent = SoundService, volume = 0, group = ambGroup() })
		if not L.snd then
			L.dead = true
			return
		end
	end
	L.snd.Volume = L.v * L.vol * L.gain * master
	if not L.on then
		L.on = true
		if L.started then
			L.snd:Resume()
		else
			L.started = true
			L.snd:Play()
		end
	end
end

-- ── one-shots: drips and distant gunfire (one pooled Sound and Attachment per variant) ──────────────────────
local dripPool, gunPool = {}, {}
local function pooled(pool, name, opts)
	local p = pool[name]
	if p == nil then
		local att = Instance.new("Attachment")
		att.Name = "ZR_AmbSource"
		att.Parent = workspace.Terrain
		opts.parent = att
		local snd, gain = AmbSound.make(name, opts)
		if not snd then
			att:Destroy()
			p = false
		else
			p = { att = att, snd = snd, gain = gain }
		end
		pool[name] = p
	end
	return p or nil
end

local function playAt(p, pos, volume, speed)
	p.att.WorldPosition = pos
	p.snd.Volume = volume * p.gain
	p.snd.PlaybackSpeed = speed
	p.snd:Stop()
	p.snd:Play()
end

-- a drip lands on the floor somewhere we can see: along one of the level rays
local function dripSpot(o)
	local best = {}
	for i = 1, 6 do
		if S.dist[i] >= 7 then
			best[#best + 1] = i
		end
	end
	local y = (S.floorY or (o.Y - 4.5)) + 0.1
	if #best == 0 then
		local a = math.random() * math.pi * 2
		return Vector3.new(o.X + math.cos(a) * 5, y, o.Z + math.sin(a) * 5)
	end
	local i = best[math.random(1, #best)]
	local d = S.dirs[i]
	local r = 3 + math.random() * math.min(S.dist[i] * 0.8 - 3, 14)
	return Vector3.new(o.X + d.X * r, y, o.Z + d.Z * r)
end

local lastGun = 0
local function gunSpot(o)
	local a = math.random() * math.pi * 2
	local r = 200 + math.random() * 120
	return Vector3.new(o.X + math.cos(a) * r, o.Y + math.random() * 18, o.Z + math.sin(a) * r)
end

local nextDrip, nextGun = 0, 0
local function oneShots(now, ambOn, raid, master)
	if not ambOn or Ambience.silent then
		nextDrip, nextGun = 0, 0 -- start counting again when the sound is back
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local wet = S.cur == "carpark" or S.mark == "Bathroom" or S.mark == "StoneCorridor"
	if nextDrip == 0 then
		nextDrip = now + math.random(8, 25)
	end
	if nextGun == 0 then
		nextGun = now + math.random(25, 60)
	end
	if now >= nextDrip then
		nextDrip = now + (wet and math.random(5, 15) or math.random(8, 25))
		if Ambience.enclosed == 1 then
			local k = math.random(1, 3)
			local p = pooled(dripPool, "drip_" .. k, { volume = 1, minDist = 6, maxDist = 70, group = ambGroup() })
			if p then
				playAt(p, dripSpot(cam.CFrame.Position), DRIP_VOL * (0.8 + math.random() * 0.4) * master, 0.94 + math.random() * 0.14)
			end
		end
	end
	-- (the scripted distant gunfire every 40 to 120 s is gone: Tarkov plays only real shots; far ones come through
	-- Ambience.farShot below, audit gameplay.13)
	local _ = raid
end

-- a real shot too far away for its own sound (past about 560 studs): the distant-gunfire sample from its direction,
-- quieter with range, heard out to about 2,400 studs (750 m)
function Ambience.farShot(origin)
	local cam = workspace.CurrentCamera
	if not cam or Ambience.silent then
		return
	end
	local camPos = cam.CFrame.Position
	local d = origin - camPos
	local dist = d.Magnitude
	if dist < 560 or dist > 2400 then
		return
	end
	local k = math.random(1, 3)
	if k == lastGun then
		k = k % 3 + 1
	end
	lastGun = k
	local p = pooled(gunPool, "gun_far_" .. k, { volume = 1, linear = true, minDist = 140, maxDist = 520, group = ambGroup() })
	if p then
		local rain = (ctx.Atmos and ctx.Atmos.rain) or 0
		local inside = (Ambience.enclosed == 1 and 0.4) or 1
		local fall = 1 - math.clamp((dist - 560) / 1840, 0, 0.85)
		local master = (ctx.Settings and ctx.Settings.data and (ctx.Settings.data.volMaster or 1) * (ctx.Settings.data.volAmb or 1)) or 1
		playAt(p, camPos + d.Unit * 260 + Vector3.new(0, 10, 0), GUN_VOL * 1.6 * fall * inside * (1 - 0.3 * rain) * master, 0.96 + math.random() * 0.08)
	end
end

-- ── dust in the light ────────────────────────────────────────────────────────────────────────────────────────
local DUST_MAX, DUST_RANGE = 6, 60
local dust = { folder = nil, slots = nil, any = false, clock = 0 }

local function buildDust()
	local folder = Instance.new("Folder")
	folder.Name = "ZR_Dust"
	folder.Parent = workspace
	local tex = Textures.GLOW
	if type(tex) ~= "string" or tex == "" then
		tex = "rbxasset://textures/particles/smoke_main.dds"
	end
	local slots = {}
	for i = 1, DUST_MAX do
		local p = Instance.new("Part")
		p.Name = "DustVolume"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Size = Vector3.new(10, 14, 10)
		p.CFrame = CFrame.new(0, -300, 0)
		p.Parent = folder
		local e = Instance.new("ParticleEmitter")
		e.Texture = tex
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Rate = 0
		e.Lifetime = NumberRange.new(7, 11)
		e.Speed = NumberRange.new(0.05, 0.25)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 0.4
		e.RotSpeed = NumberRange.new(-20, 20)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.14) })
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.6), NumberSequenceKeypoint.new(0.85, 0.65), NumberSequenceKeypoint.new(1, 1),
		})
		e.LightEmission = 0.6
		e.LightInfluence = 0.2
		e.Color = ColorSequence.new(Color3.fromRGB(255, 238, 205))
		e.Parent = p
		slots[i] = { part = p, emitter = e, rate = 0 }
	end
	dust.folder, dust.slots = folder, slots
end

local function dustOff()
	if dust.any and dust.slots then
		for _, d in dust.slots do
			if d.rate ~= 0 then
				d.rate = 0
				d.emitter.Rate = 0
			end
		end
	end
	dust.any = false
end

local function dustStep(dt, raid)
	dust.clock += dt
	if dust.clock < 1.2 then
		return
	end
	dust.clock = 0
	local q = (ctx.Settings and ctx.Settings.data and ctx.Settings.data.quality) or 3
	local sunK = 0
	if raid and q >= 2 and Ambience.enclosed == 1 then
		local A = ctx.Atmos
		local e = A and A.env
		local w = e and Env.WEATHER[e.w]
		sunK = (1 - ((A and A.dark) or 0)) * ((w and w.light) or 1)
	end
	local cam = workspace.CurrentCamera
	if sunK <= 0.35 or not cam then
		dustOff()
		return
	end
	if not dust.slots then
		buildDust()
	end
	local cp = cam.CFrame.Position
	local cands = {}
	for _, pane in CollectionService:GetTagged("ZR_Skylight") do
		if pane:IsA("BasePart") then
			local d = pane.Position - cp
			local flat = math.sqrt(d.X * d.X + d.Z * d.Z)
			if flat < DUST_RANGE and d.Y > -4 then
				cands[#cands + 1] = { pane = pane, d = flat }
			end
		end
	end
	table.sort(cands, function(a, b)
		return a.d < b.d
	end)
	local rate = 1.5 + 2.5 * math.clamp((sunK - 0.35) / 0.65, 0, 1)
	local floorY = S.floorY or (cp.Y - 5)
	dust.any = false
	for i = 1, DUST_MAX do
		local slot = dust.slots[i]
		local c = cands[i]
		if c then
			-- a shaft under the part of the pane nearest to us: at most 12 x 12 studs, down toward the floor
			local pane = c.pane
			local sz = pane.Size
			local vx, vz = math.min(sz.X, 12), math.min(sz.Z, 12)
			local rel = pane.CFrame:PointToObjectSpace(cp)
			local cx = math.clamp(rel.X, -(sz.X - vx) / 2, (sz.X - vx) / 2)
			local cz = math.clamp(rel.Z, -(sz.Z - vz) / 2, (sz.Z - vz) / 2)
			local top = pane.Position.Y - sz.Y / 2
			local height = math.clamp(top - floorY, 5, 26)
			local at = pane.CFrame:PointToWorldSpace(Vector3.new(cx, 0, cz))
			slot.part.Size = Vector3.new(vx, height, vz)
			slot.part.CFrame = CFrame.new(at.X, top - height / 2, at.Z)
			if slot.rate ~= rate then
				slot.rate = rate
				slot.emitter.Rate = rate
			end
			dust.any = true
		elseif slot.rate ~= 0 then
			slot.rate = 0
			slot.emitter.Rate = 0
		end
	end
end

-- ── step ─────────────────────────────────────────────────────────────────────────────────────────────────────
local probeClock = 0
local function update(dt)
	local cam = workspace.CurrentCamera
	if not cam or not ctx then
		return
	end
	if ctx.Atmos and ctx.Atmos.frozen then
		return -- Studio capture mode (dev bridge "studio"): no atmosphere
	end
	probeClock += dt
	if probeClock >= PROBE_EVERY then
		probeClock = 0
		probe()
	end
	local now = os.clock()
	local d = (ctx.Settings and ctx.Settings.data) or {}
	local ambOn = (d.volMaster or 1) * (d.volAmb or 1) > 0.001
	local raid = (ctx.State and ctx.State.inRaid() and ctx.State.raid) or nil
	if not Ambience.silent then
		local deaf = (ctx.Effects and ctx.Effects.deafLevel and ctx.Effects.deafLevel()) or 0
		local master = 1 - 0.5 * deaf -- a blast muffles the ambience too (the world group does the rest for effects)
		local k = 1 - math.exp(-dt / 1.6)
		local rain = (ctx.Atmos and ctx.Atmos.rain) or 0
		local tRoom, tGarage, tHum = 0, 0, 0
		if ambOn and Ambience.enclosed == 1 then
			if S.cur == "carpark" then
				tGarage = 1 - 0.2 * rain
			else
				tRoom = ((raid and 1) or 0.8) * (1 - 0.4 * rain)
			end
			if raid then
				if S.inMall and S.powered then
					tHum = ((S.cur == "carpark" or S.cur == "corridor") and 0.6) or 1
				end
			else
				tHum = 0.6 -- the bunker's own lamps and relays
			end
		end
		stepLayer(LAYERS.room, tRoom, k, master)
		stepLayer(LAYERS.garage, tGarage, k, master)
		stepLayer(LAYERS.hum, tHum, k, master)
		oneShots(now, ambOn, raid ~= nil, master)
	end
	dustStep(dt, raid ~= nil)
end

-- ── Studio probe (ZR_ClientDev "ambience") ───────────────────────────────────────────────────────────────────
function Ambience.report(force)
	if force then
		probe()
	end
	local layers = {}
	for key, L in LAYERS do
		layers[key] = { v = math.floor(L.v * 100) / 100, on = L.on, made = L.snd ~= nil }
	end
	local lit = 0
	for _, slot in dust.slots or {} do
		if slot.rate > 0 then
			lit += 1
		end
	end
	return {
		space = Ambience.space, reverb = Ambience.reverb, ambientReverb = SoundService.AmbientReverb.Name, enclosed = Ambience.enclosed,
		inMall = S.inMall, powered = S.powered, silent = Ambience.silent, mark = S.mark,
		roofH = S.roofH and math.floor(S.roofH * 10) / 10 or nil, floorD = S.floorD and math.floor(S.floorD * 10) / 10 or nil,
		dmean = S.dmean and math.floor(S.dmean * 10) / 10 or nil, wmin = S.wmin and math.floor(S.wmin * 10) / 10 or nil,
		wmax = S.wmax and math.floor(S.wmax * 10) / 10 or nil, blocked = S.blocked and math.floor(S.blocked * 10) / 10 or nil,
		cover = S.cover and math.floor(S.cover * 10) / 10 or nil, probes = Ambience.probes, rays = Ambience.rays,
		layers = layers, dustLit = lit, nextDripIn = nextDrip > 0 and math.floor(nextDrip - os.clock()) or nil,
		nextGunIn = nextGun > 0 and math.floor(nextGun - os.clock()) or nil,
	}
end

function Ambience.init(c)
	ctx = c
	Ambience.silent = not AmbSound.ready()
	local acc, lastWarn = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < STEP_EVERY then
			return
		end
		local step = math.min(acc, 0.5)
		acc = 0
		local ok, err = pcall(update, step)
		if not ok and os.clock() - lastWarn > 5 then
			lastWarn = os.clock()
			warn("[ZR] ambience", err)
		end
	end)
end

return Ambience
