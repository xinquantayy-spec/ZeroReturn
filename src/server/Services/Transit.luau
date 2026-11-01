--!nonstrict
-- Transits (Tarkov 0.15, docs/design/TRANSITS.md): from Border Yard to Meridian Mall and back without going home. A
-- transit stands at a map's edge where Tarkov's does (Customs: the vehicles by the Trailer Park; Interchange: the
-- highway's south end). It opens a minute into the raid. Hold the prompt at it: a 20 s countdown starts, during which no
-- other exit can be used and you must stay in its zone (a squad goes only when every living member stands there). Then
-- you arrive at the other map's transit with everything you carry and every wound, and that map's exits are yours.
-- The SPT numbers: available 60 s into the raid, 20 s timer.
-- All maps stand in the server at once, so a transit is a move within the same raid: the raid's clock keeps running (the
-- map in play sets it), and the map you arrive on gets a few scavs of its own if nobody went there before you.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Maps = require(Shared.Maps)

local Transit = { stats = { started = 0, arrived = 0, cancelled = 0 } }
local ctx
local CFG = { openAfter = 60, timer = 20, scavs = 6, hold = 1 }
Transit.CFG = CFG
local visited = {} -- [map id] = true once someone arrived there this raid (its exits rolled, its scavs out)

local function now()
	return workspace:GetServerTimeNow()
end

local function rootOf(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char
end

local function inside(tr, p)
	local lp = tr.cf:PointToObjectSpace(p)
	return math.abs(lp.X) <= tr.size.X / 2 and math.abs(lp.Y) <= tr.size.Y / 2 + 2 and math.abs(lp.Z) <= tr.size.Z / 2
end
Transit.inside = inside

-- the transits of the map a raider is on
local function listOn(mapId)
	local m = mapId and ctx.World.maps[mapId]
	return (m and m.transits) or {}
end

local function mapName(id)
	local d = Maps.defs[id]
	return string.upper((d and d.name) or tostring(id))
end
Transit.mapName = mapName

-- what the raid info shows (Raid.raidInfo): this map's transits and whether they are open yet
function Transit.infoFor(s)
	local out = {}
	local open = ctx.Match.startedAt and now() - ctx.Match.startedAt >= CFG.openAfter
	for _, tr in listOn(s.map or ctx.Match.map) do
		table.insert(out, { id = tr.id, name = tr.name, to = tr.to, toName = mapName(tr.to), pos = tr.pos, open = open == true })
	end
	return out
end

-- the exits a raider gets on arriving: a scav every exit a scav may use (Extract.scavMay); a PMC the list of the spawn
-- nearest the arrival
-- (Tarkov does not tie a transit to a spawn group; the nearest spawn's side is ours)
function Transit.extractsFor(mapId, pos, scav)
	local m = ctx.World.maps[mapId]
	if not m then
		return {}
	end
	if scav then
		local all = {}
		for id, e in m.extracts or {} do
			if ctx.Extract.scavMay(e) then
				table.insert(all, id)
			end
		end
		table.sort(all)
		return all
	end
	local best, bd = nil, math.huge
	for _, sp in m.spawns or {} do
		local p = sp.pos or (sp.cf and sp.cf.Position)
		if p then
			local d = (p - pos).Magnitude
			if d < bd and sp.extracts then
				best, bd = sp, d
			end
		end
	end
	return best and table.clone(best.extracts) or {}
end

-- the squadmates still alive in this raid (Tarkov: a squad transits only together)
local function squadmates(player)
	local sq = ctx.Match.squadOf and ctx.Match.squadOf(player)
	local out = {}
	for _, m in (sq and sq.members) or {} do
		local s = ctx.Raid.session(m)
		local root = rootOf(m)
		local hum = m.Character and m.Character:FindFirstChildOfClass("Humanoid")
		if m ~= player and s and not s.done and root and hum and hum.Health > 0 then
			table.insert(out, m)
		end
	end
	return out
end

local function note(player, s, d)
	ctx.Remotes.note(player, "transit", d)
	ctx.Remotes.note(player, "raid", ctx.Raid.raidInfo(s))
end

-- the prompt at a transit was held: start the countdown (for the whole squad when it stands there)
function Transit.start(player, tr)
	local s = ctx.Raid.session(player)
	local root = rootOf(player)
	if not s or s.done or s.state ~= "ACTIVE" or s.transit or not root then
		return false, "NOT_NOW"
	end
	if (s.map or ctx.Match.map) ~= tr.map then
		return false, "OTHER_MAP"
	end
	if not inside(tr, root.Position) then
		return false, "OUTSIDE"
	end
	if not ctx.Match.startedAt or now() - ctx.Match.startedAt < CFG.openAfter then
		ctx.Remotes.note(player, "toast", { text = "THE TRANSIT OPENS A MINUTE INTO THE RAID", tone = "warn" })
		return false, "TOO_EARLY"
	end
	local group = { player }
	for _, m in squadmates(player) do
		local r = rootOf(m)
		if not (r and inside(tr, r.Position)) then
			ctx.Remotes.note(player, "toast", { text = "YOUR WHOLE SQUAD MUST STAND AT THE TRANSIT", tone = "warn" })
			return false, "SQUAD"
		end
		table.insert(group, m)
	end
	local ends = now() + CFG.timer
	for _, m in group do
		local ms = ctx.Raid.session(m)
		if ms and not ms.done and not ms.transit then
			ms.transit = { tr = tr, to = tr.to, ends = ends }
			Transit.stats.started += 1
			note(m, ms, { state = "start", to = tr.to, toName = mapName(tr.to), name = tr.name, ends = ends, total = CFG.timer })
		end
	end
	return true
end

-- the map you arrive on: its transit back (the one that leads to where you came from), else its first transit
local function arrivalOn(to, from)
	local list = listOn(to)
	for _, tr in list do
		if tr.to == from then
			return tr
		end
	end
	return list[1]
end

function Transit.arrive(player, s)
	local t = s.transit
	s.transit = nil
	local from = s.map or ctx.Match.map
	local dest = arrivalOn(t.to, from)
	local root, char = rootOf(player)
	if not dest or not root then
		note(player, s, { state = "cancel", text = "THE TRANSIT FAILED" })
		return false
	end
	-- the first raider to arrive on a map that is not the one in play rolls its chance exits and lets out its scavs
	if t.to ~= ctx.World.activeMap and not visited[t.to] then
		visited[t.to] = true
		local m = ctx.World.maps[t.to]
		for _, e in (m and m.extracts) or {} do
			ctx.Match.extractOpen[ctx.Extract.key(e)] = ctx.Extract.rollOpen(e.rule)
		end
		if ctx.AI.populate then
			task.spawn(ctx.AI.populate, t.to, CFG.scavs)
		end
	end
	-- out of the zone a little, facing away from the transit's sign
	local spot = dest.cf * CFrame.new(0, 3.5, dest.size.Z / 2 - 3)
	char:PivotTo(CFrame.new(spot.Position, spot.Position + dest.cf.LookVector))
	char:SetAttribute("TP", os.clock()) -- Guard: a server move, not a speed hack
	s.map = t.to
	s.extracts = Transit.extractsFor(t.to, dest.pos, s.scav)
	s.transits = (s.transits or 0) + 1
	s.exDenied = nil
	Transit.stats.arrived += 1
	note(player, s, { state = "arrived", to = t.to, toName = mapName(t.to) })
	return true
end

function Transit.cancel(player, s, text)
	s.transit = nil
	Transit.stats.cancelled += 1
	note(player, s, { state = "cancel", text = text or "TRANSIT CANCELLED" })
end

-- every 0.2 s (Extract's tick): a raider who left the zone or died loses the countdown; at zero they cross
function Transit.tick()
	local t = now()
	for player, s in ctx.Raid.sessions() do
		if s.transit and not s.done then
			local root, char = rootOf(player)
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not root or not hum or hum.Health <= 0 then
				s.transit = nil
			elseif not inside(s.transit.tr, root.Position) then
				Transit.cancel(player, s, "YOU LEFT THE TRANSIT ZONE")
			elseif t >= s.transit.ends then
				local ok, err = pcall(Transit.arrive, player, s)
				if not ok then
					warn("[ZR] transit", err)
					s.transit = nil
				end
			end
		end
	end
end

-- a new raid: nobody has been anywhere yet
function Transit.reset()
	table.clear(visited)
end

-- ── the sign at each transit: a post with a blue lamp and the destination, the prompt on it ─────────────────────
local function part(parent, size, cf, color, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.CastShadow = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Parent = parent
	return p
end

local function sign(plate, face, text)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 50
	g.Parent = plate
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.Oswald
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(150, 196, 230)
	l.Text = text
	l.Parent = g
end

local function build(tr, parent)
	local m = Instance.new("Model")
	m.Name = "Transit_" .. tr.id
	local base = tr.cf * CFrame.new(tr.size.X / 2 - 1.5, -tr.size.Y / 2, -tr.size.Z / 2 + 1.5)
	local metal = Color3.fromRGB(52, 56, 58)
	part(m, Vector3.new(0.5, 8, 0.5), base * CFrame.new(0, 4, 0), metal, Enum.Material.Metal)
	local lamp = part(m, Vector3.new(0.7, 0.7, 0.7), base * CFrame.new(0, 8.35, 0), Color3.fromRGB(90, 160, 220), Enum.Material.Neon)
	lamp.CanCollide = false
	lamp.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = lamp.Color
	light.Range = 16
	light.Brightness = 1.1
	light.Parent = lamp
	-- the plate hangs beside the pole like a road sign, so the pole hides no letter from either side
	local plate = part(m, Vector3.new(5.2, 1.5, 0.2), base * CFrame.new(-2.85, 5.6, 0), metal, Enum.Material.Metal)
	local text = "TRANSIT  ·  " .. mapName(tr.to)
	sign(plate, Enum.NormalId.Front, text)
	sign(plate, Enum.NormalId.Back, text)
	local mark = part(m, Vector3.new(tr.size.X, 0.06, tr.size.Z), tr.cf * CFrame.new(0, -tr.size.Y / 2 + 0.04, 0), Color3.fromRGB(90, 160, 220), Enum.Material.SmoothPlastic)
	mark.Transparency = 0.84
	mark.CanCollide = false
	mark.CanQuery = false
	local pp = Instance.new("ProximityPrompt")
	pp.KeyboardKeyCode = Enum.KeyCode.F
	pp.ActionText = "Transit"
	pp.ObjectText = mapName(tr.to)
	pp.HoldDuration = CFG.hold
	pp.MaxActivationDistance = 9
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.Parent = plate
	pp.Triggered:Connect(function(player)
		local ok, err = pcall(Transit.start, player, tr)
		if not ok then
			warn("[ZR] transit start", err)
		end
	end)
	m.Parent = parent
	tr.sign = plate
end

function Transit.init(c)
	ctx = c
	for id, m in ctx.World.maps do
		for _, tr in m.transits or {} do
			tr.map = id
			local ok, err = pcall(build, tr, m.model)
			if not ok then
				warn("[ZR] transit sign", tr.id, err)
			end
		end
	end
end

return Transit
