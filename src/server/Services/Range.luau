--!nonstrict
-- Relay 7 firing range (lobby L5, docs/maps/RELAY7_LOBBY.md). From a booth you fire your own gun with free practice
-- ammo (the client's Weapon practice mode). Every shot comes here and counts only when it is fired from inside a
-- booth, aimed downrange and at the gun's fire rate. The ray can only meet the targets and the range itself
-- (people are not in its list, so nobody can be hurt anywhere in the bunker). Steel rings and falls, the paper keeps
-- your holes (clients animate both: fx "range"), and the booth's display shows your hits, the group on the paper and
-- the string's time. A string ends after a few seconds without a shot.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Weapons = require(Shared.Weapons)
local Util = require(Shared.Util)

local Range = { STRING_GAP = 6, CM_PER_STUD = 100 / 3.125 }
local ctx
local R7 -- the Relay7 layout module
local st = {} -- [Player] = { seq, last, lane, shots, hits, paper = { Vector2 }, t0, t1, slot }
local targets = {} -- [collider] = target model
local params
local screens = {} -- [lane] = SurfaceGui
local ready = false

-- world position -> plan (x, y, z) of the bunker
local function plan(pos)
	local O = Config.SAFEHOUSE_ORIGIN
	return pos.X - O.X + R7.W / 2, pos.Y - O.Y, pos.Z - O.Z + R7.D / 2
end
-- the lane whose booth you stand in (between the firing line and the back wall), or nil
function Range.laneAt(pos)
	if not R7 then
		return nil
	end
	local x, y, z = plan(pos)
	if x < R7.FIRING_LINE + 0.3 or x > 91.6 or y < -1 or y > 10 then
		return nil
	end
	for i, l in R7.LANES do
		if z >= l[1] + 0.15 and z <= l[2] - 0.15 then
			return i
		end
	end
	return nil
end

local function setup()
	local sh = ctx.World.safehouse
	local m = sh and sh.model
	R7 = ctx.World.Relay7
	if not (m and R7) then
		return false
	end
	local include = {}
	local range = m:FindFirstChild("Range", true)
	for _, d in m:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Lane") and d:GetAttribute("Metres") then
			for _, c in d:GetChildren() do
				if c.Name == "KitCollider" then
					targets[c] = d
				end
			end
		end
	end
	if range then
		table.insert(include, range)
	end
	if sh.shell then
		table.insert(include, sh.shell)
	end
	params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	params.RespectCanCollide = true
	for i = 1, #R7.LANES do
		local s = m:FindFirstChild("LaneScreen" .. i, true)
		screens[i] = s and s:FindFirstChild("Gui")
	end
	ready = true
	return true
end

local function show(lane, s)
	local g = screens[lane]
	if not g then
		return
	end
	local function set(name, text)
		local t = g:FindFirstChild(name, true)
		if t and t.Text ~= text then
			t.Text = text
		end
	end
	if not s then
		set("Who", "LANE " .. lane)
		set("Hits", "READY")
		set("Group", "")
		set("Time", "")
		return
	end
	set("Who", string.upper(string.sub(s.name or "", 1, 12)))
	set("Hits", ("HITS %d/%d"):format(s.hits, s.shots))
	set("Group", (#s.paper >= 2) and ("GROUP %.1f CM"):format(s.group * Range.CM_PER_STUD) or (#s.paper == 1 and "PAPER 1 HIT" or ""))
	set("Time", ("TIME %s"):format(string.format("%02d:%04.1f", math.floor((s.t1 - s.t0) / 60), (s.t1 - s.t0) % 60)))
end

-- the widest spread between two holes on the paper (studs)
local function spread(pts)
	local w = 0
	for i = 1, #pts do
		for j = i + 1, #pts do
			w = math.max(w, (pts[i] - pts[j]).Magnitude)
		end
	end
	return w
end

-- one shot from a booth: p = { s = seq, ox, oy, oz = origin, dx, dy, dz = direction, slot = "primary" | ... }
function Range.shot(player, p)
	if not ready and not setup() then
		return
	end
	if type(p) ~= "table" or type(p.s) ~= "number" or not Util.finite(p.s) then
		return
	end
	for _, k in { "ox", "oy", "oz", "dx", "dy", "dz" } do
		if type(p[k]) ~= "number" or not Util.finite(p[k]) then
			return
		end
	end
	p.o, p.d = Vector3.new(p.ox, p.oy, p.oz), Vector3.new(p.dx, p.dy, p.dz)
	if ctx.Raid.session(player) then
		return -- in a raid shots go to Combat
	end
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (head and hum and hum.Health > 0) then
		return
	end
	local lane = Range.laneAt(head.Position)
	if not lane then
		return
	end
	local prof = ctx.Profiles.get(player)
	local slot = (p.slot == "primary" or p.slot == "secondary" or p.slot == "holster") and p.slot or nil
	local g = prof and slot and prof.slots[slot]
	local it = g and prof.items[g]
	local idef = it and Items.defs[it.id]
	local wdef = idef and idef.weapon and Weapons[idef.weapon]
	if not wdef or wdef.melee then
		return
	end
	local s = st[player]
	local t = os.clock()
	if s and p.s <= s.seq then
		return
	end
	if s and t - s.last < (60 / wdef.rpm) * 0.8 then
		return
	end
	local dir = p.d
	local m = dir.Magnitude
	if m < 0.5 or m > 1.5 then
		return
	end
	dir /= m
	if dir.X > -0.4 then
		return -- downrange only (the lanes run toward -X)
	end
	local origin = p.o
	if (origin - head.Position).Magnitude > 4 then
		origin = head.Position
	end
	-- a new string after a pause, or in another lane
	if not s or s.lane ~= lane or t - s.last > Range.STRING_GAP or s.slot ~= slot then
		if s and s.lane ~= lane then
			show(s.lane, nil)
		end
		s = { seq = p.s, last = t, lane = lane, shots = 0, hits = 0, paper = {}, group = 0, t0 = t, t1 = t, slot = slot, name = player.DisplayName }
		st[player] = s
		ctx.Remotes.fx("rangeReset", { lane = lane })
	end
	s.seq, s.last, s.t1 = p.s, t, t
	s.shots += 1
	local pellets = (wdef.class == "shotgun") and 8 or 1
	local hitAny = false
	local firstPos, firstNormal
	for i = 1, pellets do
		local d2 = dir
		if pellets > 1 then
			local sp = math.rad(wdef.pelletSpread or 2.5)
			d2 = (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles((math.random() * 2 - 1) * sp, (math.random() * 2 - 1) * sp, 0)).LookVector
		end
		local res = workspace:Raycast(origin, d2 * math.min(wdef.range or 300, 320), params)
		local pos = res and res.Position or (origin + d2 * 320)
		if i == 1 then
			firstPos, firstNormal = pos, res and res.Normal or nil
		end
		local tm = res and targets[res.Instance]
		if tm then
			local kind = (tm:GetAttribute("Kit") == "PaperTarget") and "paper" or "steel"
			if not hitAny then
				hitAny = true
				s.hits += 1
			end
			if kind == "paper" then
				local cf = tm:GetAttribute("Frame") or tm:GetPivot()
				local lp = cf:PointToObjectSpace(pos)
				table.insert(s.paper, Vector2.new(lp.X, lp.Y))
				if #s.paper > 40 then
					table.remove(s.paper, 1)
				end
				s.group = spread(s.paper)
			end
			ctx.Remotes.fx("range", { t = tm.Name, k = kind, p = pos, n = res.Normal, lane = tm:GetAttribute("Lane") })
		end
	end
	show(lane, s)
	-- everyone else hears the shot (and sees the impact); the shooter's client made its own
	ctx.Remotes.fx("shot", { o = origin, p = firstPos, n = firstNormal, h = false, w = wdef.id, s = nil, t = nil, m = nil }, player)
end

function Range.init(c)
	ctx = c
	ctx.Remotes.onAct("range", Range.shot, 20, 30)
end

function Range.start()
	Players.PlayerRemoving:Connect(function(player)
		local s = st[player]
		st[player] = nil
		if s then
			show(s.lane, nil)
		end
	end)
	task.spawn(function()
		setup()
		for i = 1, 4 do
			show(i, nil)
		end
		-- strings end quietly: the display goes back to READY a while after the last shot
		while true do
			task.wait(2)
			local t = os.clock()
			for player, s in st do
				if t - s.last > 30 then
					st[player] = nil
					show(s.lane, nil)
				end
			end
		end
	end)
end

return Range
