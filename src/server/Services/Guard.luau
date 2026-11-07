--!nonstrict
-- Movement guard (M15, hardened 2026-11-07 for audit tech-6): the client owns its character's physics, so the server
-- samples every player four times a second and pulls back moves no legal input explains.
--   speed     horizontal speed may reach 1.6x the character's walk speed plus 8 studs/s (3 studs of slack a sample),
--             climbing 28 studs/s plus 4 studs, dropping no faster than a fall from the speed it already had
--   teleport  one move over twice those limits is pulled back at once
--   walls     the straight line between the last good point and the new one may not pass through a solid wall
--             (anything collidable whose face is upright: closed doors and intact glass count, stairs and floors do not)
--   hovering  more than 7 studs above the floor below for over 1.5 s without coming down
-- Two speed or wall violations within three seconds pull the character back to its last good spot, and a violating
-- sample never becomes the new baseline (a single big jump used to). Ten pulls inside a minute send the player away.
-- Server teleports (spawns, dev tools) set the character's "TP" attribute, which resets the baseline; seated, dead,
-- climbing, swimming and ragdolled characters are skipped.
local Players = game:GetService("Players")

local Guard = {}
local ctx
local state = {} -- [player] = { char, pos, t, tp, good, strikes, lastStrike, vy, airT, airY, pulls }
Guard.STEP = 0.25
Guard.KICK_PULLS, Guard.KICK_WINDOW = 10, 60
Guard.log = {} -- the last pulls (tests and QA)

-- the furthest a character may legally travel in dt seconds at this walk speed: horizontal, upward
function Guard.limits(walkSpeed, dt)
	return (math.max(walkSpeed or 16, 16) * 1.6 + 8) * dt + 3, 28 * dt + 4
end

-- the furthest a character may legally drop in dt seconds, already falling at vy studs/s
function Guard.maxDrop(vy, dt)
	return (math.max(vy or 0, 0) + workspace.Gravity * dt) * dt + 6
end

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.RespectCanCollide = true
rp.IgnoreWater = true
local filterAt = -math.huge
local function params(now)
	if now - filterAt > 5 then
		filterAt = now
		local list = {}
		for _, n in { "ZR_AI", "ZR_Loot", "ZR_Loose", "ZR_Corpses", "ZR_Fx", "ZR_Traps", "ZR_GlassHit", "ZR_Traders", "ZR_Airdrops" } do
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
	end
	return rp
end

-- does the straight line from a to b (both at the root's height) pass through a solid, upright wall?
function Guard.throughWall(a, b, now)
	local hit = workspace:Raycast(a, b - a, params(now or os.clock()))
	return hit ~= nil and math.abs(hit.Normal.Y) < 0.3, hit
end

-- line of sight for interactions (audit quick win tech.5): no looting or using doors through walls. The ray from the
-- head to the target counts when nothing solid is in the way, or what it meets lies within `margin` studs of the target
-- part's box (a drawer's own desk, a door's own slab).
function Guard.canSee(char, part, margin)
	local head = char and char:FindFirstChild("Head")
	if not head or not part then
		return true
	end
	local from, to = head.Position, part.Position
	local hit = workspace:Raycast(from, to - from, params(os.clock()))
	if not hit or hit.Instance == part then
		return true
	end
	local lp = part.CFrame:PointToObjectSpace(hit.Position)
	local h = part.Size / 2
	local out = Vector3.new(math.max(0, math.abs(lp.X) - h.X), math.max(0, math.abs(lp.Y) - h.Y), math.max(0, math.abs(lp.Z) - h.Z))
	return out.Magnitude <= (margin or 1.2)
end

local function reset(st, char, hrp, now)
	st.char, st.pos, st.t, st.tp = char, hrp.Position, now, char:GetAttribute("TP")
	st.good, st.strikes, st.vy, st.airT, st.airY = hrp.CFrame, 0, 0, nil, nil
end

local function pull(player, st, char, hrp, now, why, dist)
	hrp.CFrame = st.good
	hrp.AssemblyLinearVelocity = Vector3.zero
	char:SetAttribute("TP", now)
	ctx.Remotes.strike(player, why)
	table.insert(Guard.log, { player = player.Name, dist = dist, why = why, t = now })
	if #Guard.log > 20 then
		table.remove(Guard.log, 1)
	end
	st.pulls = st.pulls or {}
	table.insert(st.pulls, now)
	while st.pulls[1] and now - st.pulls[1] > Guard.KICK_WINDOW do
		table.remove(st.pulls, 1)
	end
	reset(st, char, hrp, now)
	if #st.pulls >= Guard.KICK_PULLS then
		warn("[ZR] guard: sending away", player.Name, "after", #st.pulls, "pulls; last:", why)
		player:Kick("Zero Return: your character kept moving in ways the game can't explain. If that was lag, please rejoin.")
	end
end

function Guard.sample(player, now)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then
		state[player] = nil
		return
	end
	local st = state[player]
	if not st then
		st = {}
		state[player] = st
		reset(st, char, hrp, now)
		return
	end
	local hs = hum:GetState()
	if st.char ~= char or st.tp ~= char:GetAttribute("TP") or hum.Health <= 0 or hum.SeatPart or char:GetAttribute("Ragdoll")
		or hs == Enum.HumanoidStateType.Climbing or hs == Enum.HumanoidStateType.Swimming then
		reset(st, char, hrp, now)
		return
	end
	local dt = math.max(now - st.t, 1 / 60)
	local pos = hrp.Position
	local d = pos - st.pos
	local maxH, maxUp = Guard.limits(hum.WalkSpeed, dt)
	local maxDown = Guard.maxDrop(st.vy, dt)
	local horiz = Vector3.new(d.X, 0, d.Z).Magnitude
	local dist = math.max(horiz, math.abs(d.Y))
	if horiz > maxH * 2 or d.Y > maxUp * 2 or -d.Y > maxDown * 2 then
		return pull(player, st, char, hrp, now, string.format("teleport: %.0f studs in %.2fs", dist, dt), dist)
	end
	local why = nil
	if horiz > maxH or d.Y > maxUp or -d.Y > maxDown then
		why = string.format("speed: %.0f studs in %.2fs", dist, dt)
	elseif horiz > 1.5 and Guard.throughWall(st.pos, pos, now) then
		why = string.format("through a wall: %.0f studs", horiz)
	end
	-- hovering: high above the floor below for a while without coming down
	local below = workspace:Raycast(pos, Vector3.new(0, -60, 0), params(now))
	local gap = below and (pos.Y - below.Position.Y) or 60
	if gap > 7 then
		st.airT = st.airT or now
		st.airY = math.max(st.airY or -math.huge, pos.Y)
		if now - st.airT > 1.5 and pos.Y > st.airY - 2 then
			return pull(player, st, char, hrp, now, string.format("hovering %.0f studs up for %.1fs", gap, now - st.airT), gap)
		end
	else
		st.airT, st.airY = nil, nil
	end
	if why then
		st.strikes = (now - (st.lastStrike or 0) < 3) and st.strikes + 1 or 1
		st.lastStrike = now
		if st.strikes >= 2 then
			return pull(player, st, char, hrp, now, why, dist)
		end
		-- a violating sample is never the new baseline: the next one is measured from the last good point
		return
	end
	st.good = hrp.CFrame
	st.vy = math.max(0, -d.Y / dt)
	st.pos, st.t = pos, now
end

function Guard.init(c)
	ctx = c
	Players.PlayerRemoving:Connect(function(p)
		state[p] = nil
	end)
end

function Guard.start()
	task.spawn(function()
		while true do
			task.wait(Guard.STEP)
			local now = os.clock()
			for _, p in Players:GetPlayers() do
				local ok, err = pcall(Guard.sample, p, now)
				if not ok then
					warn("[ZR] guard:", err)
				end
			end
		end
	end)
end

return Guard
