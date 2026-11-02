--!nonstrict
-- Tripwires (Tarkov 0.15; docs/design/BOSS_FORESTER.md). THE FORESTER, our Partisan, leaves them in doorways near his
-- walk: a wire at shin height between two stakes, a grenade at the foot of one. A raider who walks or crawls through it
-- pulls the pin: the grenade drops and goes off on its own fuse (Tarkov: each grenade keeps its own delay). A shot that
-- meets the wire or a blast close by sets it off too. Look at it from close by and hold the prompt to disarm it (11 s,
-- 3 s with a multitool: Tarkov's numbers) and keep the grenade. AI never set off the Forester's (our choice: the bots
-- walk the same doorways). Every wire is checked where it is laid: both stakes on one floor, nothing across the wire,
-- nothing where a stake goes, the door's leaf swinging the other way.
-- Raiders set their own too (Tarkov 0.15): a tripwire kit and a grenade in hand, then B; the wire runs from near their
-- feet to where they look, the kit and the grenade are used up, the bots and everyone else set it off, and it disarms
-- itself after 10 minutes, leaving the grenade.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local ItemModel = require(Shared.ItemModel)
local Ballistics = require(Shared.Ballistics)
local Inv = require(script.Parent.Inv)

local Tripwires = { list = {}, stats = { placed = 0, refused = 0, triggered = 0, disarmed = 0 } }
local ctx
local folder = nil
local CFG = {
	height = 0.55, -- the wire above the floor (about 18 cm)
	stake = 0.85, -- a stake's height above the floor
	inset = 0.35, -- the stakes stand this far in from the door's jambs
	off = 1.0, -- the wire's distance from the door's plane, on the side the leaf does not swing to
	near = 60, -- doors this close to a point of the boss's loop are candidates
	pad = 0.45, -- a step that ends this close to the wire sets it off
	reach = 5, -- the prompt shows from this close, while you look at the wire
	disarm = 11, -- seconds by hand (Tarkov)
	disarmTool = 3, -- with a multitool (Tarkov)
	grenades = { "GREN_F7", "GREN_RK5" },
	-- a raider's own wire (Tarkov 0.15: a kit and a grenade in hand; "minimum and maximum length limits", numbers not
	-- published, so these are ours; it disarms itself after 10 minutes, Shacknews)
	minLen = 2.5, -- studs, about 0.8 m
	maxLen = 12, -- about 3.8 m
	plantReach = 7, -- the near end lies this close to the raider
	life = 600,
	kit = "TRIPWIRE_KIT",
}
Tripwires.CFG = CFG
local WIRE = Color3.fromRGB(150, 150, 138) -- bare steel wire: thin, but it catches the light if you look for it
local STAKE = Color3.fromRGB(96, 78, 56)

local function trapsFolder()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "ZR_Traps"
		folder.Parent = workspace
	end
	return folder
end

-- ── pure geometry (LogicTests) ────────────────────────────────────────────────
-- does a step from p0 to p1 cross the wire a-b (seen from above), or end within `pad` of it?
function Tripwires.crosses(a, b, p0, p1, pad)
	local function orient(p, q, r)
		return (q.X - p.X) * (r.Z - p.Z) - (q.Z - p.Z) * (r.X - p.X)
	end
	local d1, d2 = orient(a, b, p0), orient(a, b, p1)
	local d3, d4 = orient(p0, p1, a), orient(p0, p1, b)
	if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)) then
		return true
	end
	local ax, az = b.X - a.X, b.Z - a.Z
	local len2 = ax * ax + az * az
	local t = len2 > 0 and math.clamp(((p1.X - a.X) * ax + (p1.Z - a.Z) * az) / len2, 0, 1) or 0
	local cx, cz = a.X + ax * t - p1.X, a.Z + az * t - p1.Z
	return cx * cx + cz * cz < (pad or CFG.pad) ^ 2
end

-- the wire's two ends on the sill of a door (frame cf, slab size), on the side its leaf does not swing to (Doors: turn 1
-- opens toward the door's -Z)
function Tripwires.doorEnds(cf, size, turn)
	local side = ((turn or 1) == 1) and 1 or -1
	local y = -size.Y / 2
	local half = size.X / 2 - CFG.inset
	return (cf * CFrame.new(-half, y, side * CFG.off)).Position, (cf * CFrame.new(half, y, side * CFG.off)).Position, side
end

-- ── the world checks ─────────────────────────────────────────────────────────
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.IgnoreWater = true
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Exclude

local function setFilter()
	local list = { trapsFolder() }
	for _, n in { "ZR_AI", "ZR_Loot", "ZR_Loose", "ZR_Corpses", "ZR_Fx", "ZR_Traders" } do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(list, f)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	rp.FilterDescendantsInstances = list
	op.FilterDescendantsInstances = list
end

local function floorAt(p)
	local hit = workspace:Raycast(p + Vector3.new(0, 2.5, 0), Vector3.new(0, -6, 0), rp)
	if hit and hit.Normal.Y > 0.8 then
		return hit.Position
	end
	return nil
end

local function clearLine(a, b)
	return workspace:Raycast(a, b - a, rp) == nil and workspace:Raycast(b, a - b, rp) == nil
end

-- floor points for a wire from a to b, or nil and why
function Tripwires.fit(a, b, from)
	local fa, fb = floorAt(a), floorAt(b)
	if not fa or not fb then
		return nil, nil, "no floor"
	end
	if math.abs(fa.Y - fb.Y) > 0.4 or math.abs(fa.Y - a.Y) > 0.8 then
		return nil, nil, "uneven"
	end
	local h = Vector3.new(0, CFG.height, 0)
	if not clearLine(fa + h, fb + h) then
		return nil, nil, "blocked"
	end
	-- the doorway side of it is open: nothing between the door and the wire
	if from and not clearLine(from, (fa + fb) / 2 + h) then
		return nil, nil, "behind something"
	end
	for _, f in { fa, fb } do
		local box = CFrame.new(f + Vector3.new(0, 0.1 + CFG.stake / 2, 0))
		if #workspace:GetPartBoundsInBox(box, Vector3.new(0.3, CFG.stake, 0.3), op) > 0 then
			return nil, nil, "stake in something"
		end
	end
	return fa, fb, nil
end

local function outdoors(p)
	return workspace:Raycast(p + Vector3.new(0, 1, 0), Vector3.new(0, 80, 0), rp) == nil
end

-- ── building a wire ──────────────────────────────────────────────────────────
local function piece(name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	return p
end

local function prompt(anchor, name, hold, attr, object)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name
	pp.KeyboardKeyCode = Enum.KeyCode.F -- Tarkov's interact key
	pp.ActionText = "Disarm"
	pp.ObjectText = object
	pp.HoldDuration = hold
	pp.MaxActivationDistance = CFG.reach + 1
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom
	-- each client shows it only while it looks at the wire from close by, and only the one that fits what it carries
	-- (Interact); the server checks the multitool again
	pp:SetAttribute(attr, "MULTITOOL")
	pp:SetAttribute("Trap", true)
	pp.Parent = anchor
	return pp
end

local seq = 0
local disarm -- forward

-- a wire between floor points fa and fb with grenade `item` at fa's stake; owner is who set it (the kill's author)
function Tripwires.place(fa, fb, item, owner)
	seq += 1
	local m = Instance.new("Model")
	m.Name = "Tripwire_" .. seq
	local h = Vector3.new(0, CFG.height, 0)
	local A, B = fa + h, fb + h
	local dir = (fb - fa) * Vector3.new(1, 0, 1)
	dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.xAxis
	for _, f in { fa, fb } do
		-- a thin stake driven 0.15 into the floor
		piece("Stake", Vector3.new(0.08, CFG.stake + 0.15, 0.08), CFrame.new(f + Vector3.new(0, (CFG.stake - 0.15) / 2, 0)), STAKE, Enum.Material.Wood).Parent = m
	end
	local len = (B - A).Magnitude
	local wcf = CFrame.lookAt(A, B) * CFrame.new(0, 0, -len / 2)
	piece("Wire", Vector3.new(0.028, 0.028, len), wcf, WIRE, Enum.Material.Metal).Parent = m
	-- a wider, invisible shell: a shot that meets the wire close up snaps it (Tarkov)
	local shell = piece("TripWire", Vector3.new(0.16, 0.16, len), wcf, WIRE, Enum.Material.SmoothPlastic)
	shell.Transparency = 1
	shell.CanQuery = true
	shell:SetAttribute("TrapId", seq)
	shell.Parent = m
	-- the grenade stands at the foot of the first stake, outside the span, tied to the wire
	local ga = fa - dir * 0.2
	local gm = Instance.new("Model")
	gm.Name = "Grenade"
	if not ItemModel.placeMeta(gm, item, CFrame.lookAt(ga, ga + dir)) then
		local ball = piece("GrenadeBody", Vector3.new(0.2, 0.32, 0.2), CFrame.new(ga + Vector3.new(0, 0.16, 0)), Color3.fromRGB(74, 86, 64), Enum.Material.Metal)
		ball.Parent = gm
	end
	gm.Parent = m
	local tieA = ga + Vector3.new(0, 0.22, 0)
	local tl = (A - tieA).Magnitude
	piece("Tie", Vector3.new(0.022, 0.022, tl), CFrame.lookAt(tieA, A) * CFrame.new(0, 0, -tl / 2), WIRE, Enum.Material.Metal).Parent = m
	-- the disarm prompts (one for each hand: by hand, or quicker with a multitool), at the wire's middle
	local anchor = piece("TrapPrompt", Vector3.new(0.4, 0.4, 0.4), CFrame.new((A + B) / 2), WIRE, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.Parent = m
	local t = {
		id = seq, a = A, b = B, mid = (A + B) / 2, floorY = fa.Y, len = len, item = item, owner = owner, armed = true, model = m, ga = ga,
	}
	local slow = prompt(anchor, "Disarm", CFG.disarm, "UnlessItem", "Tripwire")
	local fast = prompt(anchor, "DisarmTool", CFG.disarmTool, "NeedsItem", "Tripwire  ·  multitool")
	slow.Triggered:Connect(function(player)
		disarm(t, player, false)
	end)
	fast.Triggered:Connect(function(player)
		disarm(t, player, true)
	end)
	m.Parent = trapsFolder()
	table.insert(Tripwires.list, t)
	Tripwires.stats.placed += 1
	return t
end

-- ── a raider's own wire (Tarkov 0.15) ───────────────────────────────────────────
-- the kit's guid in a holder, or nil
function Tripwires.kitIn(inv)
	for g, it in inv.items do
		if it.id == CFG.kit and Inv.locate(inv, g) ~= nil then
			return g
		end
	end
	return nil
end

-- the checks and the setting, for a session and a root given (LogicTests call it with stand-ins): grenade g (a guid in
-- the raider's holder) on a wire from near point a to point b. Returns the wire, or nil and why.
function Tripwires.plantFor(s, root, g, a, b, owner)
	if not s or s.done or (s.state and s.state ~= "ACTIVE") or not root then
		return nil, "NOT_NOW"
	end
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" or a ~= a or b ~= b then
		return nil, "BAD"
	end
	local inv = s.inv
	local it = type(g) == "string" and inv.items[g]
	local d = it and Items.defs[it.id]
	if not (d and d.kind == "grenade" and Inv.locate(inv, g) ~= nil) then
		return nil, "NO_GRENADE"
	end
	local kit = Tripwires.kitIn(inv)
	if not kit then
		return nil, "NO_KIT"
	end
	local flat = (b - a) * Vector3.new(1, 0, 1)
	if flat.Magnitude < CFG.minLen then
		return nil, "SHORT"
	elseif flat.Magnitude > CFG.maxLen then
		return nil, "LONG"
	end
	if (a - root.Position).Magnitude > CFG.plantReach then
		return nil, "FAR"
	end
	setFilter()
	local fa, fb, why = Tripwires.fit(a, b)
	if not fa then
		return nil, string.upper(string.gsub(why or "blocked", " ", "_"))
	end
	for _, t in Tripwires.list do
		if t.armed and (t.mid - (fa + fb) / 2 - Vector3.new(0, CFG.height, 0)).Magnitude < 2 then
			return nil, "CROWDED"
		end
	end
	local id = it.id
	Inv.consume(inv, g, 1)
	Inv.consume(inv, kit, 1)
	local t = Tripwires.place(fa, fb, id, owner)
	t.byPlayer = true
	t.expires = os.clock() + CFG.life
	return t
end

local WHY = {
	NO_KIT = "YOU NEED A TRIPWIRE KIT", NO_GRENADE = "NO GRENADE IN HAND", SHORT = "TOO SHORT FOR A TRIPWIRE",
	LONG = "TOO LONG FOR A TRIPWIRE", FAR = "TOO FAR AWAY", NO_FLOOR = "NEEDS FLAT GROUND AT BOTH ENDS",
	UNEVEN = "THE GROUND IS TOO UNEVEN", BLOCKED = "SOMETHING IS IN THE WAY", STAKE_IN_SOMETHING = "NO ROOM FOR A STAKE",
	CROWDED = "ANOTHER TRIPWIRE IS THERE",
}
-- the act from a raider's client (Grenades: "nade" op "wire"): a = the near end, b = the far end (floor points)
function Tripwires.plant(player, g, a, b)
	local s = ctx.Raid.session(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 then
		return nil, "NOT_NOW"
	end
	local t, why = Tripwires.plantFor(s, root, g, a, b, player)
	if not t then
		ctx.Remotes.note(player, "toast", { text = WHY[why] or "THE TRIPWIRE WOULD NOT HOLD HERE", tone = "warn" })
		return nil, why
	end
	ctx.Raid.afterChange(player, true)
	ctx.Remotes.note(player, "toast", { text = "TRIPWIRE SET: " .. string.upper(Items.defs[t.item].name), tone = "info" })
	ctx.Remotes.fx("sfx", { n = "nade_pin", p = t.ga, v = 0.35 })
	return t
end

-- ── setting it off and taking it apart ───────────────────────────────────────
local function trigger(t, _why)
	if not t.armed then
		return
	end
	t.armed = false
	Tripwires.stats.triggered += 1
	-- the wire snaps, the pin comes out and the grenade drops: the stakes stay
	if t.model then
		for _, c in t.model:GetChildren() do
			if c.Name ~= "Stake" then
				c:Destroy()
			end
		end
	end
	ctx.Remotes.fx("sfx", { n = "nade_pin", p = t.ga, v = 0.7 })
	task.delay(0.15, function()
		ctx.Remotes.fx("sfx", { n = "nade_spoon", p = t.ga, v = 0.6 })
	end)
	local owner = t.owner
	if typeof(owner) ~= "Instance" or not owner.Parent then
		owner = nil
	end
	ctx.Grenades.throwFrom(owner, t.ga + Vector3.new(0, 0.3, 0), Vector3.new(0, -1, 0), t.item)
end
Tripwires.trigger = trigger

disarm = function(t, player, tool)
	if not t.armed then
		return
	end
	local s = ctx.Raid.session(player)
	if not s or s.done then
		return
	end
	if tool and not Inv.hasTool(s.inv) then
		return -- the quick prompt is for whoever carries a multitool
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - t.mid).Magnitude > CFG.reach + 3 then
		return
	end
	t.armed = false
	Tripwires.stats.disarmed += 1
	if t.model then
		t.model:Destroy()
		t.model = nil
	end
	local g, it = Inv.newItem(t.item, 1)
	local b = { g = g, it = it, subs = {} }
	if not Inv.give(s.inv, b, nil, Inv.loadOrder(s.inv)) then
		ctx.Loot.spawnPile(t.ga, { b })
	end
	ctx.Raid.afterChange(player, true)
	ctx.Remotes.note(player, "toast", { text = "TRIPWIRE DISARMED: " .. string.upper(Items.defs[t.item].name), tone = "info" })
end

-- a blast nearby snaps any wire it reaches (Tarkov: shrapnel sets them off)
function Tripwires.blast(center, radius)
	for _, t in Tripwires.list do
		if t.armed and (t.mid - center).Magnitude < radius then
			task.delay(0.05 + math.random() * 0.1, trigger, t, "blast")
		end
	end
end

-- ── laying them for a boss ───────────────────────────────────────────────────
-- up to n wires in doorways near the points of `route`: unlocked doors first whose wire side is outdoors (a building's
-- way in), then the others; each checked in the world (Tripwires.fit). Returns how many were laid.
function Tripwires.layAlong(route, n, owner)
	setFilter()
	local outside, inside = {}, {}
	for _, d in ctx.World.doors do
		if not d.key and not d.sealed and not d.power and d.part and d.part.Parent and d.size and d.size.X >= 2.8 and d.size.X <= 7 then
			local near = false
			for _, p in route do
				if (d.cf.Position - p).Magnitude < CFG.near then
					near = true
					break
				end
			end
			if near then
				local a, b, side = Tripwires.doorEnds(d.cf, d.size, d.turn)
				local probe = d.cf * CFrame.new(0, -d.size.Y / 2 + 0.2, side * (CFG.off + 1.5))
				table.insert(outdoors(probe.Position) and outside or inside, { d = d, a = a, b = b, side = side })
			end
		end
	end
	local function shuffle(list)
		for i = #list, 2, -1 do
			local j = math.random(1, i)
			list[i], list[j] = list[j], list[i]
		end
	end
	shuffle(outside)
	shuffle(inside)
	local laid = 0
	for _, list in { outside, inside } do
		for _, c in list do
			if laid >= n then
				return laid
			end
			-- just off the door's plane on the wire's side (a ray from inside the leaf would meet the leaf)
			local from = (c.d.cf * CFrame.new(0, -c.d.size.Y / 2 + CFG.height, c.side * 0.3)).Position
			local mid = (c.a + c.b) / 2
			local crowded = false
			for _, t in Tripwires.list do
				if (t.mid - mid).Magnitude < 6 then
					crowded = true -- the other leaf of a double door, or a door beside one already wired
					break
				end
			end
			local fa, fb, why = nil, nil, "crowded"
			if not crowded then
				fa, fb, why = Tripwires.fit(c.a, c.b, from)
			end
			if fa then
				-- the grenade goes at the end nearer the hinge, out of the way of a hand on the handle
				if (c.d.hinge or -1) > 0 then
					fa, fb = fb, fa
				end
				Tripwires.place(fa, fb, CFG.grenades[math.random(1, #CFG.grenades)], owner)
				laid += 1
			else
				Tripwires.stats.refused += 1
				Tripwires.lastRefusal = why
			end
		end
	end
	return laid
end

function Tripwires.clear()
	for _, t in Tripwires.list do
		t.armed = false
		if t.model then
			t.model:Destroy()
			t.model = nil
		end
	end
	table.clear(Tripwires.list)
	if folder then
		folder:ClearAllChildren()
	end
end

-- ── who walks into them ──────────────────────────────────────────────────────
local last = {} -- [player or AI unit] = the root's last position
local acc = 0
-- a raider's wire left alone for CFG.life disarms itself (Tarkov); its grenade stays at the stake for anyone to take
local function expire(t)
	t.armed = false
	if t.model then
		t.model:Destroy()
		t.model = nil
	end
	local g, it = Inv.newItem(t.item, 1)
	ctx.Loot.spawnPile(t.ga, { { g = g, it = it, subs = {} } })
end
Tripwires.expire = expire

local function stepped(key, root, isPlayer)
	local p1 = root.Position
	local p0 = last[key] or p1
	last[key] = p1
	if (p1 - p0).Magnitude > 14 then
		p0 = p1 -- a teleport is not a step
	end
	for _, t in Tripwires.list do
		if t.armed and (t.byPlayer or isPlayer) then
			local up = p1.Y - t.floorY
			if up > -1 and up < 6 and (p1 - t.mid).Magnitude < t.len + 8 and Tripwires.crosses(t.a, t.b, p0, p1, CFG.pad) then
				trigger(t, key)
			end
		end
	end
end

local function watch(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0
	if #Tripwires.list == 0 then
		table.clear(last)
		return
	end
	local now, mine = os.clock(), false
	for _, t in Tripwires.list do
		if t.armed and t.expires and now > t.expires then
			expire(t)
		end
		mine = mine or (t.armed and t.byPlayer == true)
	end
	-- the bots walk into a raider's wire (Tarkov: players, bots and items set them off); the Forester's own they know
	if mine and ctx.AI and ctx.AI.units then
		for _, u in ctx.AI.units do
			if u.alive and u.root and u.root.Parent then
				stepped(u, u.root, false)
			else
				last[u] = nil
			end
		end
	end
	for player, s in ctx.Raid.sessions() do
		local root = not s.done and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			stepped(player, root, true)
		else
			last[player] = nil
		end
	end
end

function Tripwires.init(c)
	ctx = c
	-- a shot that meets a wire's shell snaps it and flies on (Ballistics asks at every hit; the panes of glass too)
	local prev = Ballistics.through
	Tripwires.prevThrough = prev -- the panes' answer (Glass.through), asked for everything that is not a wire
	Ballistics.through = function(res, dir, real)
		local inst = res.Instance
		if inst and inst.Name == "TripWire" then
			if real then
				local id = inst:GetAttribute("TrapId")
				for _, t in Tripwires.list do
					if t.id == id then
						trigger(t, "shot")
						break
					end
				end
			end
			return 1, 0.2
		end
		if prev then
			return prev(res, dir, real)
		end
		return nil
	end
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(watch, dt)
		if not ok then
			warn("[ZR] tripwires", err)
		end
	end)
end

return Tripwires
