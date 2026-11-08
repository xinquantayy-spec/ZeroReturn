--!nonstrict
-- Breakable glass (docs/design/GLASS.md). A shot or a blow breaks a whole pane, the bullet goes on from just past it with a
-- little less damage, and a broken pane no longer blocks movement (a window can be climbed through like an open one).
--
-- A pane is any part tagged "ZR_Glass" by the map that built it (the Border Yard dorm windows, the Meridian shopfronts). An
-- intact pane blocks movement (CanCollide) and stops no ray (CanQuery false): the Border panes were built so, and registering
-- makes the Meridian ones so. Beside each pane the service puts a hit shell: an invisible, non-colliding box of the same size in
-- the collision group ZR_Glass, which does not collide with "Default". Every ray cast the usual way (the AI's sight, the camera,
-- the vault, loot, grenades ...) is in "Default" and so never meets a shell; no other raycast in the game had to change. Bullets
-- and blows are cast in the group ZR_Shot (Ballistics.shotGroup), which collides with everything, so they alone meet the shell.
-- Ballistics asks Glass.through at every hit: for a shell it answers "keep this share of your damage, the far side is this far
-- on", and a real bullet breaks the pane on the way.
--
-- Breaking: the pane goes Transparency 1, CanCollide false, its shell CanQuery false, and the attributes GlassBroken (and
-- GlassFloorA / GlassFloorB: where the floor is under each side) tell clients to leave shards there. One "glass" fx event carries
-- the burst and the sound. Doors.reset (a new raid) calls Glass.reset: every pane is whole again.
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Ballistics = require(Shared.Ballistics)

local Glass = {}
local ctx

Glass.TAG = "ZR_Glass" -- the tag a map puts on every breakable pane
Glass.GROUP = "ZR_Glass" -- the hit shells' collision group (collides with nothing but shots)
Glass.SHOT_GROUP = "ZR_Shot" -- the group bullets and blows are cast in
-- Roblox ignores CanQuery on a part that collides, so a whole pane (it blocks walking) meets every ordinary ray. The panes go in
-- their own group, and the AI's sight and aim checks are cast in ZR_Sight, which passes panes and shells: the AI sees through
-- glass as in Tarkov (Studio 2026-11-01: the test ray still met a pane set CanQuery = false)
Glass.PANE_GROUP = "ZR_Pane"
Glass.SIGHT_GROUP = "ZR_Sight"

-- every number that decides how glass behaves. Tarkov's own figures could not be found (docs/design/GLASS.md, Research): the
-- loss is the owner's 5 to 10 %, taken in the middle.
Glass.CFG = {
	keep = 0.925, -- share of a bullet's damage and penetration kept after a pane
	nudge = 0.05, -- studs past the far face of the pane the bullet goes on from
	maxExit = 3, -- longest way through a shell, studs (a very shallow hit)
	minThick = 0.2, -- a hit shell is never thinner than this
	floorReach = 6, -- studs below a sill the floor is looked for (the client's shards)
	floorSide = 1.5, -- studs out from the pane, on each side, where the floor is looked for
	blowNoise = 0.35, -- loudness the AI hears of a pane smashed by hand (a shot is loud already)
	fxPerSecond = 12, -- most break events sent per second (the break itself is never held back)
}
local CFG = Glass.CFG

local entries = {} -- [pane] = entry
local byShell = {} -- [shell] = entry
local broken = {} -- the entries broken since the last reset
local folder
local ready = false
local total = 0
local fxLeft, fxAt = CFG.fxPerSecond, os.clock()
Glass.stats = { panes = 0, broken = 0, shatters = 0 }

-- ── geometry ────────────────────────────────────────────────────────────────────────────────────────────────────
-- which local axis of a box is the thinnest ("X", "Y" or "Z"): a pane's normal
local function thinAxis(size)
	if size.X <= size.Y and size.X <= size.Z then
		return "X"
	end
	if size.Y <= size.Z then
		return "Y"
	end
	return "Z"
end
Glass.thinAxis = thinAxis

-- where a ray crosses out of a slab: along one axis, from l (local position) in direction d, half extent h
local function slab(l, d, h)
	if d > 1e-6 then
		return (h - l) / d
	elseif d < -1e-6 then
		return (-h - l) / d
	end
	return math.huge
end

-- the distance along the unit vector dir from p (on or inside the box with centre frame cf and size) to where the ray leaves it
function Glass.exitDist(cf, size, p, dir)
	local lp = cf:PointToObjectSpace(p)
	local ld = cf:VectorToObjectSpace(dir)
	local t = math.min(slab(lp.X, ld.X, size.X / 2), slab(lp.Y, ld.Y, size.Y / 2), slab(lp.Z, ld.Z, size.Z / 2))
	if t == math.huge or t ~= t then
		return 0
	end
	return math.max(t, 0)
end

-- ── groups ──────────────────────────────────────────────────────────────────────────────────────────────────────
local function ensureGroup(name)
	local exists = false
	pcall(function()
		exists = PhysicsService:IsCollisionGroupRegistered(name)
	end)
	if not exists then
		pcall(function()
			PhysicsService:RegisterCollisionGroup(name)
		end)
	end
end

local function makeGroups()
	local ok, err = pcall(function()
		ensureGroup(Glass.GROUP)
		ensureGroup(Glass.SHOT_GROUP)
		ensureGroup(Glass.PANE_GROUP)
		ensureGroup(Glass.SIGHT_GROUP)
		-- ordinary rays and bodies (group "Default") pass the shells; shots meet them and everything else
		PhysicsService:CollisionGroupSetCollidable(Glass.GROUP, "Default", false)
		PhysicsService:CollisionGroupSetCollidable(Glass.GROUP, Glass.GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(Glass.SHOT_GROUP, Glass.GROUP, true)
		PhysicsService:CollisionGroupSetCollidable(Glass.SHOT_GROUP, "Default", true)
		-- panes block bodies and meet shots and ordinary rays; sight rays pass panes and shells and meet everything else
		PhysicsService:CollisionGroupSetCollidable(Glass.PANE_GROUP, Glass.GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(Glass.SIGHT_GROUP, Glass.PANE_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(Glass.SIGHT_GROUP, Glass.GROUP, false)
	end)
	if not ok then
		warn("[ZR] Glass: the collision groups could not be made, panes will not break:", err)
	end
	return ok
end

-- ── the registry ────────────────────────────────────────────────────────────────────────────────────────────────
local function makeShell(pane)
	local size = pane.Size
	local sx, sy, sz = size.X, size.Y, size.Z
	local ax = thinAxis(size)
	if ax == "X" then
		sx = math.max(sx, CFG.minThick)
	elseif ax == "Y" then
		sy = math.max(sy, CFG.minThick)
	else
		sz = math.max(sz, CFG.minThick)
	end
	local shell = Instance.new("Part")
	shell.Name = "GlassHit"
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = true
	shell.CanTouch = false
	shell.CastShadow = false
	shell.Transparency = 1
	shell.Size = Vector3.new(sx, sy, sz)
	shell.CFrame = pane.CFrame
	shell.CollisionGroup = Glass.GROUP
	shell.Parent = folder
	return shell
end

-- a tagged pane joins the registry: its shell is made, its state as the map built it is remembered
function Glass.register(pane)
	if typeof(pane) ~= "Instance" or not pane:IsA("BasePart") then
		return nil
	end
	local e = entries[pane]
	if e or not ready or not pane:IsDescendantOf(workspace) then
		return e
	end
	local shell = makeShell(pane)
	e = { pane = pane, shell = shell, broken = false, orig = { t = pane.Transparency, c = pane.CanCollide, g = pane.CollisionGroup } }
	pane.CollisionGroup = Glass.PANE_GROUP
	-- an intact pane stops no ray but a shot's or a blow's (those meet its shell). The Border panes were built that way; Meridian's
	-- shop glass was queryable and stopped every ray (the AI's sight too), and now passes them like the Border panes do
	pane.CanQuery = false
	entries[pane] = e
	byShell[shell] = e
	total += 1
	Glass.stats.panes = total
	return e
end

local mend -- (defined with the breaking code below)

local function unregister(pane)
	local e = entries[pane]
	if not e then
		return
	end
	-- a pane that leaves the world broken is whole when it comes back: its state is read again when it registers
	if e.broken and mend then
		pcall(mend, e)
	end
	entries[pane] = nil
	byShell[e.shell] = nil
	if e.orig.g and pane.Parent then
		pcall(function()
			pane.CollisionGroup = e.orig.g
		end)
	end
	e.dead = true
	total -= 1
	Glass.stats.panes = total
	for i = #broken, 1, -1 do
		if broken[i] == e then
			table.remove(broken, i)
		end
	end
	Glass.stats.broken = #broken
	e.shell:Destroy()
end
Glass.unregister = unregister

function Glass.entryOf(pane)
	return entries[pane]
end

function Glass.count()
	return total
end

function Glass.isBroken(pane)
	local e = entries[pane]
	return e ~= nil and e.broken
end

-- ── breaking and mending ────────────────────────────────────────────────────────────────────────────────────────
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.IgnoreWater = true

-- the floor under one side of a pane (side 1 or -1 along its normal), or nil: shards fall there. The map's own geometry only.
local function floorUnder(pane, side)
	local cf, size = pane.CFrame, pane.Size
	local ax = thinAxis(size)
	local n = (ax == "X" and cf.RightVector) or (ax == "Y" and cf.UpVector) or cf.LookVector
	local flat = Vector3.new(n.X, 0, n.Z)
	if math.abs(n.Y) > 0.5 or flat.Magnitude < 0.1 then
		return nil -- a pane lying flat has no "under"
	end
	flat = flat.Unit
	local hy = (math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z) / 2
	local c = cf.Position
	local from = Vector3.new(c.X, c.Y - hy + 0.4, c.Z) + flat * (side * CFG.floorSide)
	local models = (ctx and ctx.World and ctx.World.mapModels and ctx.World.mapModels()) or {}
	table.insert(models, workspace.Terrain)
	floorParams.FilterDescendantsInstances = models
	local hit = workspace:Raycast(from, Vector3.new(0, -CFG.floorReach, 0), floorParams)
	return hit and hit.Position or nil
end

local function sendFx(e, hitPos, dir)
	local R = ctx and ctx.Remotes
	if not R or not R.fx then
		return
	end
	local now = os.clock()
	fxLeft = math.min(CFG.fxPerSecond, fxLeft + (now - fxAt) * CFG.fxPerSecond)
	fxAt = now
	if fxLeft < 1 then
		return
	end
	fxLeft -= 1
	-- the pane's frame and size, the way the shot was flying, where it hit: the client makes the burst and the sound
	R.fx("glass", { cf = e.pane.CFrame, sz = e.pane.Size, d = dir, h = hitPos })
end

-- break a pane (a no-op for one already broken). hitPos, dir: where and which way the blow came. Returns true if it broke now.
local function shatter(e, hitPos, dir)
	if not e or e.broken or e.dead then
		return false
	end
	local pane, shell = e.pane, e.shell
	e.broken = true
	-- the floor under each side first, the flag last: a client that sees the flag finds the floor already set (a failed look
	-- leaves the floor unknown, not the pane whole)
	local okA, floorA = pcall(floorUnder, pane, 1)
	local okB, floorB = pcall(floorUnder, pane, -1)
	pane:SetAttribute("GlassFloorA", okA and floorA or nil)
	pane:SetAttribute("GlassFloorB", okB and floorB or nil)
	pane.Transparency = 1
	pane.CanCollide = false
	pane.CanQuery = false
	shell.CanQuery = false
	pane:SetAttribute("GlassBroken", true)
	table.insert(broken, e)
	Glass.stats.broken = #broken
	Glass.stats.shatters += 1
	pcall(sendFx, e, hitPos, dir)
	return true
end
Glass.shatter = shatter

-- a pane whole again, as the map built it
function mend(e)
	if not e.broken then
		return
	end
	e.broken = false
	if e.dead then
		return
	end
	local pane = e.pane
	pane:SetAttribute("GlassBroken", nil)
	pane:SetAttribute("GlassFloorA", nil)
	pane:SetAttribute("GlassFloorB", nil)
	pane.Transparency = e.orig.t
	pane.CanCollide = e.orig.c
	pane.CanQuery = false
	e.shell.CanQuery = true
end
Glass.mend = mend

-- a new raid: every broken pane is whole again (Doors.reset calls this). Returns how many were mended.
function Glass.reset()
	local n = #broken
	for i = n, 1, -1 do
		local e = broken[i]
		broken[i] = nil
		local ok, err = pcall(mend, e)
		if not ok then
			warn("[ZR] Glass: mending a pane failed:", err)
		end
	end
	Glass.stats.broken = 0
	return n
end

-- ── what bullets and blows do ───────────────────────────────────────────────────────────────────────────────────
-- Ballistics calls this for every ray hit. res: the RaycastResult, dir: the unit direction of the ray, real: a bullet in flight
-- (true) or the effects trace (false). Not a pane's shell: nil. A shell: the share of damage kept and the distance along dir to
-- just past the pane; a real bullet breaks the pane on the way.
function Glass.through(res, dir, real)
	local e = res and byShell[res.Instance]
	if not e then
		return nil
	end
	local shell = e.shell
	local far = Glass.exitDist(shell.CFrame, shell.Size, res.Position, dir)
	far = math.clamp(far, 0, CFG.maxExit) + CFG.nudge
	if real and not e.broken then
		local ok, err = pcall(shatter, e, res.Position, dir)
		if not ok then
			warn("[ZR] Glass: breaking a pane failed:", err)
		end
	end
	return CFG.keep, far
end

-- a blow (a knife swing: Combat.melee): did the ray hit a pane's shell? If so the pane breaks (a smashed window is heard) and
-- the swing is spent. Returns true when it was a pane.
function Glass.blow(inst, hitPos, dir, attacker)
	local e = byShell[inst]
	if not e then
		return false
	end
	if not e.broken then
		local ok, err = pcall(shatter, e, hitPos, dir)
		if not ok then
			warn("[ZR] Glass: breaking a pane failed:", err)
		end
		if ctx and ctx.AI and ctx.AI.hearShot then
			pcall(ctx.AI.hearShot, hitPos, attacker, nil, CFG.blowNoise)
		end
	end
	return true
end

function Glass.init(c)
	ctx = c
	ready = makeGroups()
	if not ready then
		return
	end
	local old = workspace:FindFirstChild("ZR_GlassHit")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "ZR_GlassHit"
	folder.Parent = workspace
	-- panes join and leave the registry as their parts enter and leave the world (the maps build before this runs; a map built
	-- or removed later is covered by the signals)
	CollectionService:GetInstanceAddedSignal(Glass.TAG):Connect(function(p)
		local ok, err = pcall(Glass.register, p)
		if not ok then
			warn("[ZR] Glass: register failed:", err)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(Glass.TAG):Connect(function(p)
		pcall(unregister, p)
	end)
	for _, p in CollectionService:GetTagged(Glass.TAG) do
		local ok, err = pcall(Glass.register, p)
		if not ok then
			warn("[ZR] Glass: register failed:", err)
		end
	end
	Ballistics.shotGroup = Glass.SHOT_GROUP
	Ballistics.through = Glass.through
	if c.AI and c.AI.setSightGroup then
		c.AI.setSightGroup(Glass.SIGHT_GROUP)
	end
	-- grenades fly and blast in the sight group too: it passes panes and shells as the Default group did, and also the
	-- railings' body-only colliders (art-5b's ZR_Move), which bullets and sight already pass (EFT's thin railings shelter
	-- nobody from a blast)
	if c.Grenades and c.Grenades.setRayGroup then
		c.Grenades.setRayGroup(Glass.SIGHT_GROUP)
	end
	local per = {}
	if c.World and c.World.maps then
		for id, m in c.World.maps do
			local n = 0
			for pane in entries do
				if m.model and m.model:IsAncestorOf(pane) then
					n += 1
				end
			end
			if n > 0 then
				table.insert(per, string.format("%s %d", id, n))
			end
		end
		table.sort(per)
	end
	print(string.format("[ZR] Glass: %d breakable panes (%s)", total, table.concat(per, ", ")))
end

return Glass
