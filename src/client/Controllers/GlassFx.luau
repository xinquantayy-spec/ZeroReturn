--!nonstrict
-- Breaking glass, seen and heard (docs/design/GLASS.md). The server breaks a pane (Glass service) and sends one "glass" fx event,
-- { cf = the pane's CFrame, sz = its size, d = the way the shot went, h = where it hit }. Here that becomes a burst of shards
-- sprayed from the pane (one of three pooled emitters, at most 20 particles, none on POTATO) and the break sound.
-- The shards that lie on the floor afterwards are not made from the event but from the pane's replicated attributes (GlassBroken
-- and GlassFloorA / GlassFloorB, the floor on each side), so a pane that streams in already broken shows them too and a pane
-- that is whole again (a new raid) loses them. They are a few flat glass parts, capped per pane and in all. Effects.luau calls
-- init and burst; nothing here touches the server.
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Sounds = require(Shared.Sounds)
local AmbAtlas = require(Shared.AmbAtlas)

local GlassFx = {}
local ctx, E -- the client ctx and the Effects module (its sfx plays atlas regions)

local TAG = "ZR_Glass"
local SOUNDS = { "glass_break_1", "glass_break_2", "glass_break_3" }
local AXES = { "X", "Y", "Z" }
-- the face of a box that looks along axisVec(cf, axis) and the face opposite it, for the emission direction: [axis] = { along, against }.
-- (axisVec gives RightVector, UpVector and LookVector, and the box's Front face looks along LookVector)
local FACE = {
	X = { Enum.NormalId.Right, Enum.NormalId.Left },
	Y = { Enum.NormalId.Top, Enum.NormalId.Bottom },
	Z = { Enum.NormalId.Front, Enum.NormalId.Back },
}

GlassFx.CFG = {
	hosts = 3, -- pooled emitters (a break takes the next one)
	burstMin = 8, -- fewest and most particles one break throws, before the quality share
	burstMax = 20,
	cover = 9, -- the sprayed region of a pane is at most this many studs each way, round the hit
	range = 450, -- no spray further than this from the camera (the sound has its own reach)
	share = { [0] = 0, [1] = 0.4, [2] = 0.7, [3] = 1 }, -- the share of the burst each graphics level (0 POTATO .. 3 HIGH) gets
	perSide = { [0] = 2, [1] = 3, [2] = 4, [3] = 6 }, -- floor shards on each side of a broken pane, by graphics level
	maxShards = 160, -- floor shards in the whole world
	settle = 0.4, -- seconds after the break before its floor shards appear (the spray has to land first)
}
local CFG = GlassFx.CFG
GlassFx.stats = { bursts = 0, sounds = 0, sprays = 0 }

local fxFolder, shardFolder
local hosts, nextHost = {}, 0
local watched = {} -- [pane] = { shards = {parts}, conns = {...}, queued = bool }
local shardCount = 0
local audible = false -- the uploaded atlas holds the glass_break regions (checked once, below)
local inited = false

local function quality()
	local q = ctx and ctx.Settings and ctx.Settings.data and ctx.Settings.data.quality
	if type(q) ~= "number" then
		return 2
	end
	return math.clamp(math.floor(q), 0, 3)
end

-- the thinnest local axis of a box: a pane's normal
local function thinAxis(size)
	if size.X <= size.Y and size.X <= size.Z then
		return "X"
	end
	if size.Y <= size.Z then
		return "Y"
	end
	return "Z"
end

local function axisVec(cf, ax)
	if ax == "X" then
		return cf.RightVector
	elseif ax == "Y" then
		return cf.UpVector
	end
	return cf.LookVector
end

-- ── the sound ───────────────────────────────────────────────────────────────────────────────────────────────────
-- The glass_break regions sit at the end of the ambience atlas (ZR_SFX_Amb). Until that asset is re-uploaded with them the old file
-- is shorter than the regions' start, so nothing is played: the file's length is read once from a probe Sound.
local function probeAtlas()
	local id = Sounds.AMB_ATLAS
	if type(id) ~= "string" or id == "" then
		return
	end
	local need = 0
	for _, name in SOUNDS do
		local r = AmbAtlas[name]
		if type(r) == "table" then
			need = math.max(need, r[1] + r[2])
		end
	end
	if need <= 0 then
		return
	end
	task.spawn(function()
		local len = 0
		local probe = Instance.new("Sound")
		probe.SoundId = id
		probe.Volume = 0
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ probe })
			len = probe.TimeLength
		end)
		probe:Destroy()
		audible = ok and len >= need - 0.15
		if not audible then
			print(string.format("[ZR] GlassFx: the ambience atlas asset is %.1f s long and the glass_break sounds end at %.1f s: silent until ZR_SFX_Amb is re-uploaded", len, need))
		end
	end)
end

-- ── the spray ───────────────────────────────────────────────────────────────────────────────────────────────────
local function buildHosts()
	for i = 1, CFG.hosts do
		local p = Instance.new("Part")
		p.Name = "GlassHost" .. i
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = CFrame.new(0, -500, 0)
		p.Parent = fxFolder
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(205, 228, 235))
		e.LightEmission = 0.2
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.34), NumberSequenceKeypoint.new(1, 0.12) })
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.75, 0.25), NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(0.55, 1.0)
		e.Speed = NumberRange.new(4, 16)
		e.SpreadAngle = Vector2.new(38, 38)
		e.Acceleration = Vector3.new(0, -34, 0)
		e.Drag = 0.6
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-260, 260)
		e.Rate = 0
		e.EmissionDirection = Enum.NormalId.Front
		pcall(function()
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		end)
		e.Parent = p
		hosts[i] = { part = p, emitter = e }
	end
end

-- one break: d = { cf, sz, d, h } from the server's "glass" event
function GlassFx.burst(d)
	if type(d) ~= "table" then
		return
	end
	local cf, sz = d.cf, d.sz
	if typeof(cf) ~= "CFrame" or typeof(sz) ~= "Vector3" then
		return
	end
	local hit = typeof(d.h) == "Vector3" and d.h or cf.Position
	local dir = typeof(d.d) == "Vector3" and d.d or nil
	local cam = workspace.CurrentCamera
	local dist = cam and (cam.CFrame.Position - hit).Magnitude or 0
	local ax = thinAxis(sz)
	local area = 1
	for _, a in AXES do
		if a ~= ax then
			area *= sz[a]
		end
	end
	GlassFx.stats.bursts += 1
	-- the sound: a small pane, a window or a thick shopfront each have a recording; it carries further for a bigger pane
	if audible and E and E.sfx then
		local v = (area >= 40 and 2) or (area <= 3 and 3) or (math.random() < 0.7 and 1 or 3)
		local reach = 150 + math.min(math.max(sz.X, sz.Y, sz.Z), 20) * 5
		if dist <= reach + 20 then
			pcall(E.sfx, "glass_break_" .. v, hit, 1.0, 0.96 + math.random() * 0.1, reach)
			GlassFx.stats.sounds += 1
		end
	end
	-- the spray: nothing on POTATO, a share of it on LOW and MEDIUM
	local share = CFG.share[quality()] or 0
	if share <= 0 or dist > CFG.range or #hosts == 0 then
		return
	end
	nextHost = nextHost % #hosts + 1
	local h = hosts[nextHost]
	-- the sprayed region: the pane's face round the hit, at most CFG.cover studs each way, one tenth of a stud deep
	local lp = cf:PointToObjectSpace(hit)
	local size, centre = {}, {}
	local covered = 1
	for _, a in AXES do
		if a == ax then
			size[a], centre[a] = 0.1, 0
		else
			local full = sz[a]
			local part = math.min(full, CFG.cover)
			size[a] = part
			centre[a] = math.clamp(lp[a], -(full - part) / 2, (full - part) / 2)
			covered *= part
		end
	end
	h.part.Size = Vector3.new(size.X, size.Y, size.Z)
	h.part.CFrame = cf * CFrame.new(centre.X, centre.Y, centre.Z)
	local forward = (dir == nil) or dir:Dot(axisVec(cf, ax)) >= 0
	h.emitter.EmissionDirection = FACE[ax][forward and 1 or 2]
	local n = math.clamp(math.floor(covered * 0.5) + 6, CFG.burstMin, CFG.burstMax)
	h.emitter:Emit(math.max(1, math.floor(n * share)))
	GlassFx.stats.sprays += 1
end

-- ── the floor shards ────────────────────────────────────────────────────────────────────────────────────────────
local function clearShards(r)
	for i = #r.shards, 1, -1 do
		local s = r.shards[i]
		r.shards[i] = nil
		shardCount -= 1
		s:Destroy()
	end
end

-- flat glass parts on the floor under a broken pane, on each side where the server found a floor
local function scatter(pane)
	local r = watched[pane]
	if not r then
		return
	end
	clearShards(r)
	if pane:GetAttribute("GlassBroken") ~= true or not shardFolder then
		return
	end
	local cf, size = pane.CFrame, pane.Size
	local ax = thinAxis(size)
	local n = axisVec(cf, ax)
	-- the width axis: of the two other axes the one that lies more level
	local others = {}
	for _, a in AXES do
		if a ~= ax then
			table.insert(others, a)
		end
	end
	local wa = (math.abs(axisVec(cf, others[1]).Y) <= math.abs(axisVec(cf, others[2]).Y)) and others[1] or others[2]
	local flatN = Vector3.new(n.X, 0, n.Z)
	local wv = axisVec(cf, wa)
	local flatW = Vector3.new(wv.X, 0, wv.Z)
	if flatN.Magnitude < 0.1 or flatW.Magnitude < 0.1 then
		return -- a pane lying flat has no floor under it
	end
	flatN, flatW = flatN.Unit, flatW.Unit
	local width = size[wa]
	local per = CFG.perSide[quality()] or 3
	local count = math.min(per * 2, math.max(2, math.floor(width / 2.2))) -- a wide pane drops more, up to twice the usual
	local p0 = cf.Position
	local rng = Random.new(math.floor(p0.X * 31 + p0.Y * 17 + p0.Z * 7))
	for side = 1, 2 do
		local base = pane:GetAttribute(side == 1 and "GlassFloorA" or "GlassFloorB")
		if typeof(base) == "Vector3" then
			for _ = 1, count do
				if shardCount >= CFG.maxShards then
					return
				end
				local u = rng:NextNumber(-0.5, 0.5) * math.max(0.5, width - 0.6) -- along the pane
				local v = rng:NextNumber(-0.4, 1.4) * (side == 1 and 1 or -1) -- out from the pane, on this side
				local s = Instance.new("Part")
				s.Name = "Shard"
				s.Anchored = true
				s.CanCollide = false
				s.CanQuery = false
				s.CanTouch = false
				s.CastShadow = false
				s.Material = Enum.Material.Glass
				s.Color = Color3.fromRGB(200, 225, 232)
				s.Transparency = rng:NextNumber(0.35, 0.55)
				s.Size = Vector3.new(rng:NextNumber(0.25, 0.9), 0.04, rng:NextNumber(0.2, 0.7))
				s.CFrame = CFrame.new(base + flatW * u + flatN * v + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.2832), 0)
				s.Parent = shardFolder
				table.insert(r.shards, s)
				shardCount += 1
			end
		end
	end
end

-- (re)build a pane's shards on the next frame, after the spray when the break is live; one call however many attributes changed
local function request(pane, live)
	local r = watched[pane]
	if not r or r.queued then
		return
	end
	local broken = pane:GetAttribute("GlassBroken") == true
	if not broken and #r.shards == 0 then
		return
	end
	r.queued = true
	task.delay((live and broken) and CFG.settle or 0, function()
		if watched[pane] ~= r then
			return
		end
		r.queued = false
		local ok, err = pcall(scatter, pane)
		if not ok then
			warn("[ZR] GlassFx shards:", err)
		end
	end)
end

local function watch(pane)
	if watched[pane] or typeof(pane) ~= "Instance" or not pane:IsA("BasePart") then
		return
	end
	local r = { shards = {}, conns = {}, queued = false }
	watched[pane] = r
	for _, attr in { "GlassBroken", "GlassFloorA", "GlassFloorB" } do
		table.insert(r.conns, pane:GetAttributeChangedSignal(attr):Connect(function()
			request(pane, true)
		end))
	end
	request(pane, false) -- a pane that streams in already broken
end

local function unwatch(pane)
	local r = watched[pane]
	if not r then
		return
	end
	watched[pane] = nil
	for _, c in r.conns do
		c:Disconnect()
	end
	clearShards(r)
end

-- what the pane census sees, for a test or a look in Studio
function GlassFx.report()
	local panes, broken = 0, 0
	for pane in watched do
		panes += 1
		if pane:GetAttribute("GlassBroken") == true then
			broken += 1
		end
	end
	return { panes = panes, broken = broken, shards = shardCount, audible = audible, bursts = GlassFx.stats.bursts, sounds = GlassFx.stats.sounds, sprays = GlassFx.stats.sprays }
end

function GlassFx.init(c, effects)
	ctx, E = c, effects
	if inited then
		return
	end
	inited = true
	for _, name in { "ZR_GlassFx", "ZR_Shards" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ZR_GlassFx"
	fxFolder.Parent = workspace
	shardFolder = Instance.new("Folder")
	shardFolder.Name = "ZR_Shards"
	shardFolder.Parent = workspace
	buildHosts()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(unwatch)
	for _, pane in CollectionService:GetTagged(TAG) do
		watch(pane)
	end
	probeAtlas()
end

return GlassFx
