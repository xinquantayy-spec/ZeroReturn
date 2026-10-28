--!nonstrict
-- "Harbor Watch" guards: PATROL -> INVESTIGATE (gunfire) -> ENGAGE (sight/damage) -> SEARCH -> RETURN.
-- Perception at 5 Hz per guard, throttled pathfinding, server raycast LOS for sight and shots.
local Players = game:GetService("Players")
local DEV = game:GetService("RunService"):IsStudio()
local PathfindingService = game:GetService("PathfindingService")

local AI = {}
local ctx
local guards = {}
local folder
local gen = 0
AI.guards = guards

local SIGHT, CLOSE = 150, 16
local FOV_COS = math.cos(math.rad(65))
local DMG_MIN, DMG_MAX = 8, 13
local WALK, RUN = 8, 14

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function byModel(model)
	for _, g in guards do
		if g.model == model then
			return g
		end
	end
	return nil
end

local function visible(g, char)
	local head = char:FindFirstChild("Head")
	if not head or not g.head then
		return false, math.huge
	end
	local from = g.head.Position
	local d = head.Position - from
	local dist = d.Magnitude
	if dist > SIGHT or (char:GetAttribute("Crouch") and dist > 70) then
		return false, dist
	end
	if dist > CLOSE and g.root.CFrame.LookVector:Dot(d.Unit) < FOV_COS then
		return false, dist
	end
	params.FilterDescendantsInstances = { g.model, workspace:FindFirstChild("ZR_Fx") }
	local r = workspace:Raycast(from, d, params)
	return (r == nil) or r.Instance:IsDescendantOf(char), dist
end

local function findTarget(g)
	local best, bestD = nil, math.huge
	for player, s in ctx.Raid.sessions() do
		if not s.done and not (DEV and player:GetAttribute("DevIgnore")) then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local vis, dist = visible(g, char)
				if vis and dist < bestD then
					best, bestD = player, dist
				end
			end
		end
	end
	return best
end

local function moveTo(g, goal, run)
	g.hum.WalkSpeed = run and RUN or WALK
	g.hum.AutoRotate = true
	local t = os.clock()
	if not g.pathGoal or (g.pathGoal - goal).Magnitude > 6 or t >= g.nextPath then
		g.nextPath = t + 3
		g.pathGoal = goal
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5.5, AgentCanJump = false, WaypointSpacing = 6 })
		local okk = pcall(function()
			path:ComputeAsync(g.root.Position, goal)
		end)
		if okk and path.Status == Enum.PathStatus.Success then
			g.path = path:GetWaypoints()
			g.pathI = math.min(2, #g.path)
		else
			g.path = nil
		end
	end
	local wp = goal
	if g.path and g.path[g.pathI] then
		wp = g.path[g.pathI].Position
		if (flat(wp) - flat(g.root.Position)).Magnitude < 3 then
			g.pathI += 1
			wp = g.path[g.pathI] and g.path[g.pathI].Position or goal
		end
	end
	g.hum:MoveTo(wp)
end

local function face(g, pos)
	g.hum.AutoRotate = false
	g.hum:MoveTo(g.root.Position)
	local p = g.root.Position
	g.root.CFrame = CFrame.lookAt(p, Vector3.new(pos.X, p.Y, pos.Z))
end

local function fire(g, char)
	local troot = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	if not troot then
		return
	end
	local muzzle = g.head.Position + g.root.CFrame.LookVector * 1.4 + Vector3.new(0, -0.45, 0)
	local aim = (head and math.random() < 0.2) and head.Position or (troot.Position + Vector3.new(0, 0.5, 0))
	local dist = (aim - muzzle).Magnitude
	local spread = 1.4 + dist * 0.02
	if troot.AssemblyLinearVelocity.Magnitude > 9 then
		spread += 1.8
	end
	if char:GetAttribute("Crouch") then
		spread += 0.6
	end
	local dir = (CFrame.lookAt(muzzle, aim) * CFrame.Angles(math.rad((math.random() * 2 - 1) * spread), math.rad((math.random() * 2 - 1) * spread), 0)).LookVector
	params.FilterDescendantsInstances = { g.model, workspace:FindFirstChild("ZR_Fx") }
	local r = workspace:Raycast(muzzle, dir * 400, params)
	local hitPos = r and r.Position or (muzzle + dir * 400)
	if r then
		local model = r.Instance:FindFirstAncestorOfClass("Model")
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		if hum and model == char then
			local dmg = math.random(DMG_MIN, DMG_MAX) * ((r.Instance.Name == "Head") and 1.8 or 1)
			ctx.Combat.damage(model, hum, dmg, g.model, muzzle)
		end
	end
	ctx.Remotes.fx("shot", { o = muzzle, p = hitPos, n = r and r.Normal or nil, ai = true })
	AI.hearShot(muzzle, nil, g)
end

local function think(g)
	local t = os.clock()
	local seen = findTarget(g)
	if seen then
		if g.state ~= "ENGAGE" then
			g.nextShot = t + 0.6 + math.random() * 0.5
			g.burst = math.random(3, 5)
		end
		g.state = "ENGAGE"
		g.target = seen
		g.lastSeen = t
		local tr = seen.Character and seen.Character:FindFirstChild("HumanoidRootPart")
		if tr then
			g.lastPos = tr.Position
		end
	end
	if g.state == "ENGAGE" then
		local char = g.target and g.target.Character
		local troot = char and char:FindFirstChild("HumanoidRootPart")
		local thum = char and char:FindFirstChildOfClass("Humanoid")
		if not troot or not thum or thum.Health <= 0 or not ctx.Raid.session(g.target) then
			g.state, g.target = "RETURN", nil
		elseif seen == g.target then
			face(g, troot.Position)
			if t >= g.nextShot then
				fire(g, char)
				g.burst -= 1
				if g.burst > 0 then
					g.nextShot = t + 0.13
				else
					g.burst = math.random(3, 5)
					g.nextShot = t + 0.9 + math.random() * 0.9
				end
			end
		elseif t - g.lastSeen > 1.5 then
			g.state = "SEARCH"
			g.searchUntil = t + 12
		end
	elseif g.state == "SEARCH" or g.state == "INVESTIGATE" then
		if g.lastPos and (flat(g.root.Position) - flat(g.lastPos)).Magnitude > 5 then
			moveTo(g, g.lastPos, g.state == "SEARCH")
		else
			g.hum:MoveTo(g.root.Position)
		end
		if t > (g.searchUntil or 0) then
			g.state = "RETURN"
		end
	else
		local wp = g.route[g.wp]
		if (flat(wp) - flat(g.root.Position)).Magnitude < 4.5 then
			g.wp = g.wp % #g.route + 1
			g.state = "PATROL"
			wp = g.route[g.wp]
		end
		moveTo(g, wp, false)
	end
	g.model:SetAttribute("Aim", g.state == "ENGAGE")
	g.model:SetAttribute("State", g.state)
end

local function spawnGuard(routeName, myGen)
	local route = ctx.World.patrols[routeName]
	if not route then
		return
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(ctx.Chars.description("guard"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model or myGen ~= gen then
		if not ok then
			warn("[ZR] guard spawn failed", model)
		end
		return
	end
	model.Name = "HarborWatch_" .. routeName
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	ctx.Chars.setupHumanoid(hum)
	hum.WalkSpeed = WALK
	local idx = math.random(1, #route)
	model:PivotTo(CFrame.new(route[idx] + Vector3.new(0, 3.3, 0)))
	ctx.Chars.dress(model, "guard", { rifle = true })
	model:SetAttribute("ZR_AI", true)
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local g = {
		model = model, hum = hum, root = root, head = model:FindFirstChild("Head"), route = route, wp = idx,
		state = "PATROL", lastSeen = 0, nextShot = 0, burst = 3, nextPath = 0, alive = true, name = routeName,
	}
	table.insert(guards, g)
	hum.Died:Connect(function()
		ctx.Chars.ragdoll(model)
		AI.onKilled(model, nil)
	end)
	task.spawn(function()
		while g.alive and model.Parent and myGen == gen do
			local okk, err = pcall(think, g)
			if not okk then
				warn("[ZR] AI think", err)
			end
			task.wait(0.2)
		end
	end)
end

function AI.hearShot(pos, _shooter, except)
	for _, g in guards do
		if g ~= except and g.alive and g.state ~= "ENGAGE" and g.root then
			if (g.root.Position - pos).Magnitude < 170 then
				g.state = "INVESTIGATE"
				g.lastPos = pos + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
				g.searchUntil = os.clock() + 14
			end
		end
	end
end

function AI.onDamaged(model, attacker)
	local g = byModel(model)
	if not g or not g.alive then
		return
	end
	if typeof(attacker) == "Instance" and attacker:IsA("Player") then
		local c = attacker.Character
		if c then
			g.lastPos = c:GetPivot().Position
			face(g, g.lastPos)
		end
		if g.state ~= "ENGAGE" then
			g.state = "SEARCH"
			g.searchUntil = os.clock() + 12
		end
	end
end

function AI.onKilled(model, _attacker)
	local g = byModel(model)
	if not g or not g.alive then
		return
	end
	g.alive = false
	g.state = "DEAD"
	model:SetAttribute("State", "DEAD")
	ctx.Loot.spawnBody(model, "guard")
	task.delay(90, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

function AI.clear()
	gen += 1
	for _, g in guards do
		g.alive = false
		if g.model and g.model.Parent then
			g.model:Destroy()
		end
	end
	table.clear(guards)
end

function AI.reset()
	AI.clear()
	local myGen = gen
	for _, routeName in { "HS", "PA", "FD" } do
		task.spawn(spawnGuard, routeName, myGen)
	end
end

function AI.init(c)
	ctx = c
	folder = Instance.new("Folder")
	folder.Name = "ZR_AI"
	folder.Parent = workspace
end

return AI
