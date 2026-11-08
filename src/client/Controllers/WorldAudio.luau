--!nonstrict
-- World sounds through Roblox's Audio API with Acoustic Simulation (decision gameplay-3a, piloted on Border Yard).
-- Tarkov 0.16.7 reworked how sound passes obstacles: walls of different thickness, floors and stairways, doors and
-- windows muffle a sound between its source and you. Roblox's Acoustic Simulation (released 22 September 2026) does the
-- same for AudioEmitters heard by an AudioListener: occlusion by each part's density and thickness, diffraction round
-- corners and reverb from the geometry, scaled down by Roblox on weak devices. Legacy Sounds are not simulated, so the
-- world one-shots (other people's shots and steps, impacts, blasts) play here; your own sounds stay 2D legacy Sounds.
-- The chain: the listener on the camera -> the deafness EQ (blasts, stun charges) -> the world volume -> the speakers.
-- On this client, parts that should not block sound (decor without collision, the detail layer, bodies, loot,
-- effects) get AudioCanCollide = false; walls, floors, doors, kit colliders and window panes keep it.
-- Off on POTATO and on the maps not yet piloted: Effects then muffles by counting walls (the scripted fallback).
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local W = { on = false, live = 0, MAX_LIVE = 24, PILOT = { border = true } }
local ctx
local folder, listener, eq, fader, out
local curves = {}
local hooked = {}

local function wire(a, b, parent)
	local w = Instance.new("Wire")
	w.SourceInstance = a
	w.TargetInstance = b
	w.Parent = parent
	return w
end

-- the legacy InverseTapered roll-off as a distance curve: inverse near the minimum distance, a linear square towards
-- the maximum (Roblox's description of InverseTapered), so a sound carries as far as before
local function curve(minD, maxD)
	minD = math.max(1, math.floor(minD + 0.5))
	maxD = math.max(minD + 1, math.floor(maxD + 0.5))
	local key = minD * 100000 + maxD
	local c = curves[key]
	if c then
		return c
	end
	c = { [0] = 1 }
	for i = 0, 20 do
		local d = minD + (maxD - minD) * (i / 20) ^ 1.7
		local t = (d - minD) / (maxD - minD)
		c[d] = math.clamp(math.min(minD / math.max(minD, d), (1 - t) ^ 2), 0, 1)
	end
	curves[key] = c
	return c
end
W.curve = curve

-- ── the listener chain ───────────────────────────────────────────────────────────────────────────────────────
local function placeListener()
	local cam = workspace.CurrentCamera
	if not (cam and listener) then
		return
	end
	listener.Parent = cam
	-- a default listener Roblox may have made (SoundService.DefaultListenerLocation) would hear the world twice
	for _, l in cam:GetChildren() do
		if l:IsA("AudioListener") and l ~= listener then
			l:Destroy()
		end
	end
end

local function build()
	if folder and folder.Parent then
		return
	end
	pcall(function()
		SoundService.DefaultListenerLocation = Enum.ListenerLocation.None
	end)
	for _, o in SoundService:GetChildren() do
		if o:IsA("AudioDeviceOutput") then
			o:Destroy() -- the default listener's output (ours lives in ZR_Audio)
		end
	end
	folder = Instance.new("Folder")
	folder.Name = "ZR_Audio"
	folder.Parent = SoundService
	listener = Instance.new("AudioListener")
	listener.Name = "ZR_Listener"
	eq = Instance.new("AudioEqualizer")
	eq.Name = "Deafen"
	eq.Bypass = true
	eq.Parent = folder
	fader = Instance.new("AudioFader")
	fader.Name = "World"
	fader.Volume = (ctx and ctx.Settings.fxVolume and ctx.Settings.fxVolume()) or 1
	fader.Parent = folder
	out = Instance.new("AudioDeviceOutput")
	out.Name = "ZR_Out"
	out.Parent = folder
	wire(listener, eq, folder)
	wire(eq, fader, folder)
	wire(fader, out, folder)
	placeListener()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(placeListener)
	-- the atlases load once up front, so the first shot of each plays at once
	local Sounds = require(game:GetService("ReplicatedStorage").ZR.Sounds)
	for _, id in { "ATLAS", "ENV_ATLAS", "COMBAT_ATLAS", "AMB_ATLAS", "R17_FIRE", "R17_FIRE_FAR" } do
		local a = Sounds[id]
		if type(a) == "string" and a ~= "" then
			local p = Instance.new("AudioPlayer")
			p.Name = "Preload_" .. id
			p.Asset = a
			p.Parent = folder
		end
	end
end
W.listener = function()
	return listener
end
W.folder = function()
	return folder
end

-- the deafness (Effects.deafLevel) and the world volume, as the legacy world SoundGroup gets them
function W.setMix(k, vol)
	if not eq then
		return
	end
	eq.Bypass = k <= 0.01
	eq.HighGain = -40 * k
	eq.MidGain = -24 * k
	eq.LowGain = -6 * k
	fader.Volume = (1 - 0.5 * k) * vol
end

-- ── what blocks sound ────────────────────────────────────────────────────────────────────────────────────────
local QUIET = { ZR_Detail = true, ZR_AI = true, ZR_Corpses = true, ZR_Loot = true, ZR_Fx = true, ZR_TaskSpots = true }

local function quiet(d)
	if d:IsA("BasePart") and d.AudioCanCollide then
		d.AudioCanCollide = false
	end
end

-- Roblox occludes by density x thickness, and at its own densities our thin plaster walls hardly muffle: a source
-- 9 studs away, outside the watchhouse's watch room, came in 2.8 dB under the free field (all map parts made
-- transparent to sound). Tarkov's walls muffle much more, so on this client the anchored solid parts get an acoustic
-- density of x3, at most 6: the same source then came in 17 dB down (x2: 16.9, x4.5: 21.8; measured in Studio with an
-- AudioAnalyzer on the listener, 2026-11-08). Anchored parts do not move, so physics is not touched (ours).
W.DENSITY_MUL, W.DENSITY_MAX = 3, 6
local function acoustic(d)
	if d.Anchored then
		local pp = d.CurrentPhysicalProperties
		local want = math.clamp(pp.Density * W.DENSITY_MUL, 0.5, W.DENSITY_MAX)
		if math.abs(want - pp.Density) > 0.01 then
			d.CustomPhysicalProperties = PhysicalProperties.new(want, pp.Friction, pp.Elasticity, pp.FrictionWeight, pp.ElasticityWeight)
		end
	end
end

local function decide(d)
	if not d:IsA("BasePart") then
		return
	end
	if d.CollisionGroup == "ZR_Pane" then
		-- a window pane blocks sound until it breaks (the server makes a broken pane passable)
		d.AudioCanCollide = d.CanCollide
		d:GetPropertyChangedSignal("CanCollide"):Connect(function()
			d.AudioCanCollide = d.CanCollide
		end)
		acoustic(d)
	elseif not d.CanCollide then
		if d.AudioCanCollide then
			d.AudioCanCollide = false -- kit pieces over their colliders, leaves, clutter
		end
	else
		acoustic(d)
	end
end

local function sweep(root, fn)
	task.spawn(function()
		local list = root:GetDescendants()
		for i, d in list do
			fn(d)
			if i % 1500 == 0 then
				task.wait()
			end
		end
	end)
	table.insert(hooked, root.DescendantAdded:Connect(fn))
end

local function character(ch)
	if ch then
		sweep(ch, quiet)
	end
end

local swept = {}
local function sweepAll()
	for _, c in workspace:GetChildren() do
		if not swept[c] then
			if c.Name == "ZR_World" then
				swept[c] = true
				sweep(c, decide)
			elseif QUIET[c.Name] then
				swept[c] = true
				sweep(c, quiet)
			end
		end
	end
end

-- ── one world sound ──────────────────────────────────────────────────────────────────────────────────────────
-- asset (rbxassetid), pos, volume, speed, region (NumberRange of the atlas or nil), min/max distance (the legacy
-- roll-off), eqGains = { low, mid, high } dB or nil (a suppressor), life (s): the longest it can play
function W.play(asset, pos, vol, speed, region, minD, maxD, eqGains, life)
	if not folder or W.live >= W.MAX_LIVE then
		return nil
	end
	W.live += 1
	local a = Instance.new("Attachment")
	a.Name = "ZR_Emit"
	a.WorldPosition = pos
	local em = Instance.new("AudioEmitter")
	em:SetDistanceAttenuation(curve(minD, maxD))
	em.Parent = a
	local pl = Instance.new("AudioPlayer")
	pl.Asset = asset
	pl.Volume = vol
	pl.PlaybackSpeed = speed
	if region then
		pl.PlaybackRegion = region
	end
	pl.Parent = a
	local src = pl
	if eqGains then
		local e = Instance.new("AudioEqualizer")
		e.LowGain, e.MidGain, e.HighGain = eqGains[1], eqGains[2], eqGains[3]
		e.Parent = a
		wire(pl, e, a)
		src = e
	end
	wire(src, em, a)
	a.Parent = workspace.Terrain
	pl:Play()
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		W.live -= 1
		a:Destroy()
	end
	pl.Ended:Connect(finish)
	task.delay(life or 6, finish)
	return pl
end

-- ── on and off ───────────────────────────────────────────────────────────────────────────────────────────────
local function want()
	local S = ctx.State
	local map = S.inRaid and S.inRaid() and S.raid and S.raid.map
	local q = ctx.Settings.data.quality or 2
	return map ~= nil and W.PILOT[map] == true and q >= 1
end

function W.set(on)
	if on and not folder then
		build()
	end
	if on then
		sweepAll()
	end
	W.on = on
	pcall(function()
		SoundService.AcousticSimulationEnabled = on
	end)
end

function W.init(c)
	ctx = c
	for _, p in Players:GetPlayers() do
		character(p.Character)
		p.CharacterAdded:Connect(character)
	end
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(character)
	end)
	task.spawn(function()
		while true do
			local ok, w = pcall(want)
			w = ok and w or false
			if w ~= W.on then
				W.set(w)
			elseif w then
				sweepAll() -- a map rebuilt for the next raid
			end
			task.wait(1)
		end
	end)
end

return W
