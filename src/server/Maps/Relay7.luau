--!nonstrict
-- Relay 7: the safehouse bunker (the physical lobby, owner approved 2026-10-29). A cold-war relay station dug under
-- the zone and taken over by the contractors. Seven rooms off one corridor, every Tarkov screen a station:
--   bunk room (spawn bunks, stash lockers, mirror) · ops room (map table, departure board, roster, task board,
--   insurance window) · traders' hall (VOS, HALE, TILDA counters, the Fence at the back door, mail pigeonholes) ·
--   hideout wing (module bays) · gunsmith bench · firing range (booths, plates at 10/25/50 m) · motor pool (the van,
--   the scav hatch).
-- Design: docs/maps/RELAY7_LOBBY.md. Plan coordinates are studs: x east 0..140, z south 0..104, floor at y 0; the
-- plan's centre (70, 52) sits on Config.SAFEHOUSE_ORIGIN, far from every map so no map streams in while you are here.
-- This module owns the layout and builds the shell (concrete, painted wall bands) and the stations (invisible boxes
-- carrying the prompts); Relay7Dress.luau places the Blender bunker kit on the same plan.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Config = require(Shared.Config)

local Relay7 = {}
local M = Enum.Material
local V = Vector3.new

Relay7.W, Relay7.D = 140, 104
-- rooms: { x0, z0, x1, z1, ceiling height }
Relay7.ROOMS = {
	bunk = { 0, 0, 40, 36, 12 },
	ops = { 40, 0, 92, 36, 12 },
	traders = { 92, 0, 140, 36, 12 },
	corridor = { 0, 36, 140, 44, 10 },
	hideout = { 0, 44, 52, 76, 12 },
	gunsmith = { 52, 44, 92, 76, 12 },
	range = { 0, 76, 92, 104, 11 },
	tunnel = { -78, 98, 0, 104, 9 },
	motor = { 92, 44, 140, 104, 22 }, -- high bay: the ramp climbs 9 to the roller door in the south wall
}
-- walls: axis "x" runs along x at z = at (from a to b); "z" runs along z at x = at. gaps = { { from, to, top } };
-- the last field says which face is indoors ("+": toward +z / +x, "-": the other side, nil: both) for the paint band
local DOOR = 8.5
Relay7.DOOR = DOOR
Relay7.WALLS = {
	{ "x", 0, 0, 140, 12, nil, "+" }, -- north
	{ "x", 104, -78, 92, 11, nil, "-" }, -- south: tunnel and range
	{ "x", 104, 92, 140, 22, nil, "-" }, -- south: motor pool (the roller door at the top of the ramp)
	{ "z", 0, 0, 98, 12, nil, "+" }, -- west (the 50 m lane runs on into the tunnel)
	{ "z", -78, 98, 104, 9, nil, "+" }, -- tunnel end
	{ "x", 98, -78, 0, 9, nil, "+" }, -- tunnel north wall
	{ "z", 140, 0, 44, 12, nil, "-" }, -- east: traders and corridor
	{ "z", 140, 44, 104, 22, nil, "-" }, -- east: motor pool
	{ "z", 40, 0, 36, 12, { { 14, 22, DOOR } } }, -- bunk | ops
	{ "z", 92, 0, 36, 12, { { 14, 22, DOOR } } }, -- ops | traders
	{ "x", 36, 0, 140, 12, { { 14, 22, DOOR }, { 62, 70, DOOR }, { 98, 106, DOOR }, { 128, 136, DOOR } } }, -- row A | corridor
	{ "x", 44, 0, 92, 12, { { 20, 28, DOOR }, { 84, 90, DOOR } } }, -- corridor | hideout, gunsmith
	{ "x", 44, 92, 140, 22, { { 100, 124, 12 } } }, -- corridor | motor pool (wide vehicle opening)
	{ "z", 52, 44, 76, 12 }, -- hideout | gunsmith
	{ "z", 92, 44, 104, 22 }, -- gunsmith, range | motor pool
	{ "x", 76, 0, 92, 12, { { 84, 90, DOOR } } }, -- hideout, gunsmith | range
}
-- stations (plan coordinates; the kit dressing places its props on the same spots)
Relay7.BUNKS = { 7, 11.5, 16, 20.5, 25, 29.5 } -- bunk units along the west wall (x 1.5..8.5), 3 deep each
Relay7.TRADERS = {
	{ id = "vos", label = "VOS", x0 = 95, x1 = 107 },
	{ id = "hale", label = "HALE", x0 = 110, x1 = 122 },
	{ id = "tilda", label = "TILDA", x0 = 125, x1 = 137 },
}
Relay7.HIDEOUT = {
	{ id = "generator", label = "Generator", x0 = 3, z0 = 45, x1 = 15, z1 = 50 },
	{ id = "workbench", label = "Workbench", x0 = 35.5, z0 = 45, x1 = 44.5, z1 = 49 },
	{ id = "medstation", label = "Medstation", x0 = 46.5, z0 = 53, x1 = 51, z1 = 71 },
	{ id = "water", label = "Water collector", x0 = 1, z0 = 58.5, x1 = 6, z1 = 65.5 },
	{ id = "storage", label = "Storage racks", x0 = 9, z0 = 72, x1 = 37, z1 = 75.4 },
}
Relay7.FIRING_LINE = 82 -- x of the booths' front edge; lanes run west
Relay7.LANES = { { 82, 87.5 }, { 87.5, 93 }, { 93, 98.5 }, { 98.5, 104 } } -- z bands; lane 4 runs into the tunnel
Relay7.STUDS_PER_M = 3.125
Relay7.PLATES = { 10, 25, 50 } -- metres from the firing line

local O = Vector3.zero
-- plan point -> world
local function P(x, y, z)
	return O + V(x - Relay7.W / 2, y, z - Relay7.D / 2)
end
Relay7.P = function(x, y, z)
	return P(x, y, z)
end

local function hex(h)
	return Color3.fromHex(h)
end
local C = {
	concrete = hex("6F6C64"), concreteDark = hex("4C4A45"), floor = hex("54524C"), ceiling = hex("5C5A55"),
	olive = hex("5B5F45"), steel = hex("4A4D4F"), rust = hex("7A4B32"), wood = hex("6E5A44"), paper = hex("C9C2A8"),
	yellow = hex("C9A13C"), red = hex("8A3A2E"), band = hex("4F5A47"), bandLine = hex("2A2D27"),
}

local function part(parent, size, cf, color, mat, variant, name)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.Concrete
	if variant then
		p.MaterialVariant = variant
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = name or "Part"
	p.Parent = parent
	return p
end
-- an axis-aligned block between plan corners (x0, y0, z0) and (x1, y1, z1)
local function block(parent, x0, y0, z0, x1, y1, z1, color, mat, variant, name)
	local a, b = P(x0, y0, z0), P(x1, y1, z1)
	return part(parent, (b - a):Abs(), CFrame.new((a + b) / 2), color, mat, variant, name)
end
Relay7.block = block

local function prompt(anchor, action, object, screen, range)
	local pp = Instance.new("ProximityPrompt")
	pp.KeyboardKeyCode = Enum.KeyCode.F -- Tarkov interact key (Q/E lean)
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = 0
	pp.MaxActivationDistance = range or 8
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp:SetAttribute("Screen", screen)
	pp.Parent = anchor
	return pp
end
-- an invisible, non-colliding box that carries a station's prompt
local function station(parent, name, x0, y0, z0, x1, y1, z1, action, object, screen, range)
	local s = block(parent, x0, y0, z0, x1, y1, z1, C.paper, M.SmoothPlastic, nil, name)
	s.Transparency = 1
	s.CanCollide = false
	s.CanQuery = false
	s.CanTouch = false
	s:SetAttribute("NoDetail", true)
	if action then
		prompt(s, action, object, screen, range)
	end
	return s
end

-- the painted band on a wall face: olive paint to 4.5 studs, a dark line on top (peeling: ZR_PlasterPeel)
local BAND, LINE = 4.5, 0.28
local function band(parent, axis, at, s0, s1, side)
	if s1 - s0 < 0.05 then
		return
	end
	local off = side * (0.6 + 0.03)
	local function slab(y0, y1, color, mat, variant, name)
		local p
		if axis == "x" then
			p = block(parent, s0, y0, at + off - 0.03, s1, y1, at + off + 0.03, color, mat, variant, name)
		else
			p = block(parent, at + off - 0.03, y0, s0, at + off + 0.03, y1, s1, color, mat, variant, name)
		end
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p:SetAttribute("NoDetail", true)
	end
	slab(0, BAND, C.band, M.Plaster, "ZR_PlasterPeel", "PaintBand")
	slab(BAND, BAND + LINE, C.bandLine, M.SmoothPlastic, nil, "PaintLine")
end

local function wall(parent, w)
	local axis, at, a, b, h, gaps, faces = w[1], w[2], w[3], w[4], w[5], w[6] or {}, w[7]
	local T = 1.2
	table.sort(gaps, function(g1, g2)
		return g1[1] < g2[1]
	end)
	local cur = a
	local function seg(s0, s1, y0, y1)
		if s1 - s0 < 0.05 or y1 - y0 < 0.05 then
			return
		end
		local p
		if axis == "x" then
			p = block(parent, s0, y0, at - T / 2, s1, y1, at + T / 2, C.concrete, M.Concrete, "ZR_ConcreteWorn", "Wall")
		else
			p = block(parent, at - T / 2, y0, s0, at + T / 2, y1, s1, C.concrete, M.Concrete, "ZR_ConcreteWorn", "Wall")
		end
		p:SetAttribute("Wall", true)
		if y0 < 0.01 then
			if faces ~= "-" then
				band(parent, axis, at, s0, s1, 1)
			end
			if faces ~= "+" then
				band(parent, axis, at, s0, s1, -1)
			end
		end
	end
	for _, g in gaps do
		seg(cur, g[1], 0, h)
		seg(g[1], g[2], g[3], h) -- lintel over the doorway
		cur = g[2]
	end
	seg(cur, b, 0, h)
end

-- build the bunker under `root` around `origin`; returns the safehouse table World keeps
function Relay7.build(root, origin)
	O = origin
	local f = Instance.new("Model")
	f.Name = "Relay7"
	f.Parent = root
	local shell = Instance.new("Model")
	shell.Name = "Shell"
	shell.Parent = f
	-- floor (one slab under everything, the tunnel included) and ceilings per room
	block(shell, -78, -2, 0, 140, 0, 104, C.floor, M.Concrete, "ZR_ConcreteWorn", "Floor")
	for name, r in Relay7.ROOMS do
		local c = block(shell, r[1], r[5], r[2], r[3], r[5] + 1, r[4], C.ceiling, M.Concrete, "ZR_ConcreteWorn", "Ceiling_" .. name)
		c:SetAttribute("Ceiling", true)
	end
	for _, w in Relay7.WALLS do
		wall(shell, w)
	end

	-- stations: invisible boxes that carry the prompts (the kit dressing below is what you see and bump into)
	local st = Instance.new("Model")
	st.Name = "Stations"
	st.Parent = f
	local out = { center = origin, stations = {}, bunks = {}, spawns = {} }

	-- bunk room: six double bunks with a locker each (every locker opens your stash), the mirror
	for i, z in Relay7.BUNKS do
		out.bunks[i] = station(st, "Locker" .. i, 9.5, 0, z + 0.5, 11.5, 7, z + 2.5, "Open stash", "Locker", "stash", 7)
		for _, x in { 14.2, 16.8 } do
			table.insert(out.spawns, CFrame.lookAt(P(x, 3.2, z + 1.5), P(x + 10, 3.2, z + 1.5)))
		end
	end
	out.stash = out.bunks[1]
	out.stations.mirror = station(st, "Mirror", 31.5, 3.5, 0.6, 35.5, 8, 2.2, "Check your kit", "Mirror", "mirror")

	-- ops room: the map table (deploy), departure board, roster, task board, insurance window
	out.deploy = station(st, "DeployPrompt", 56, 0, 12, 80, 4.5, 22, "Plan deployment", "Map table", "deploy", 9)
	out.stations.departure = station(st, "DepartureBoard", 69, 5.2, 0.6, 81, 11, 1.4)
	out.stations.roster = station(st, "Roster", 40.6, 3.2, 24, 41.4, 7.4, 30)
	out.stations.tasks = station(st, "TaskBoard", 90.6, 3, 24, 91.4, 7.2, 32, "Read tasks", "Task board", "tasks", 8)
	out.stations.insurance = station(st, "InsuranceWindow", 44, 2, 33.5, 54, 7, 35.4, "Insure kit", "Insurance window", "insurance", 8)

	-- traders' hall: three counters, the Fence by the south wall, the mail pigeonholes
	for _, t in Relay7.TRADERS do
		out.stations["trader_" .. t.id] = station(st, "Counter_" .. t.id, t.x0, 0, 9, t.x1, 4, 12, "Trade", t.label, "trader:" .. t.id, 9)
	end
	out.stations.trader_fence = station(st, "FenceStall", 114.8, 0, 31, 119.2, 3.5, 35.4, "Trade", "The Fence", "trader:fence", 8)
	out.stations.mail = station(st, "Pigeonholes", 138.2, 1.5, 19.5, 139.4, 7.2, 25.5, "Collect mail", "Pigeonholes", "mail", 8)

	-- hideout wing: one bay per module
	for _, b in Relay7.HIDEOUT do
		out.stations["hideout_" .. b.id] = station(st, "Bay_" .. b.id, b.x0, 0, b.z0, b.x1, 5, b.z1, "Manage", b.label, "hideout:" .. b.id, 9)
	end

	-- gunsmith bench
	out.stations.gunsmith = station(st, "GunsmithBench", 59, 0, 44.6, 73, 4, 48, "Modify weapon", "Gunsmith bench", "modding", 9)

	-- firing range: lanes run west from the firing line (lane 4 on into the tunnel); the kit puts booths and plates
	out.range = { x0 = -78, x1 = 92, z0 = 76, z1 = 104, line = Relay7.FIRING_LINE }

	-- motor pool: the van (deploy), the ramp up to the roller door, the scav hatch
	out.stations.van = station(st, "VanRear", 114, 0, 79.4, 122, 7, 83, "Board the van", "PMC van", "van", 8)
	out.stations.scav = station(st, "ScavHatch", 96.4, 0, 95.4, 100.6, 3, 99.6, "Scav run", "Manhole hatch", "scav", 8)
	-- the ramp's slope (the kit Ramp is only the look): 13 wide, rising 9 over 36 toward the south wall
	local rp = P(132.8, 4.5, 85.4)
	local wedge = Instance.new("WedgePart")
	wedge.Name = "RampSlope"
	wedge.Anchored = true
	wedge.Size = V(13, 9, 36)
	wedge.CFrame = CFrame.lookAt(rp, rp - Vector3.zAxis) -- rises toward +Z (south), the foot at the north
	wedge.Transparency = 1
	wedge.Material = M.Concrete
	wedge:SetAttribute("NoDetail", true)
	wedge.Parent = st

	-- the kit: furniture, fittings, lights and paint (Maps/Relay7Dress.luau)
	local Dress = require(script.Parent.Relay7Dress)
	out.dress = Dress.build(f, P, Relay7)

	out.spawn = out.spawns[1]
	out.model = f
	-- the bunker's bounds (world), for "is this player in the safehouse"
	out.lo, out.hi = P(-80, -4, -2), P(142, 26, 106)
	return out
end

-- is a world position inside the bunker?
function Relay7.inside(sh, pos)
	return sh.lo ~= nil and pos.X >= sh.lo.X and pos.X <= sh.hi.X and pos.Y >= sh.lo.Y and pos.Y <= sh.hi.Y and pos.Z >= sh.lo.Z and pos.Z <= sh.hi.Z
end

return Relay7
