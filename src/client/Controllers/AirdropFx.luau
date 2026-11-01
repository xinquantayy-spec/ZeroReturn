--!nonstrict
-- Airdrops seen and heard (Services/Airdrop.luau; docs/design/AIRDROPS.md). The server sends one "airdrop" fx message:
-- { kind, pos = the landing point, from, to = the plane's track at drop height, t0 = server time it starts, flight,
-- release = seconds after t0 the crate leaves the plane, fall = seconds it then takes to land, yaw }.
-- Here each client draws the transport flying the track with its engines' drone, the countermeasure flares it fires as
-- it crosses, and the crate sinking under its canopy. At the landing the server's crate (the one with the loot and the
-- red smoke) takes over, and this one goes. Nothing here touches the server or collides with anything.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local AirdropFx = {}
local E -- the Effects module (atlas sounds)

local GREY, DARK = Color3.fromRGB(118, 124, 122), Color3.fromRGB(84, 90, 90)
local OLIVE, CANOPY = Color3.fromRGB(78, 86, 58), Color3.fromRGB(104, 112, 80)

local function part(parent, size, cf, color, mat)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function now()
	return workspace:GetServerTimeNow()
end

local function fxFolder()
	local f = workspace:FindFirstChild("ZR_Fx")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ZR_Fx"
		f.Parent = workspace
	end
	return f
end

-- a four-engine high-wing transport, about 46 m long with a 50 m span (3.1 studs a metre), nose toward -Z
local function buildPlane()
	local m = Instance.new("Model")
	m.Name = "ZR_AirdropPlane"
	local body = part(m, Vector3.new(11, 11, 112), CFrame.new(0, 0, 0), GREY, Enum.Material.Metal)
	part(m, Vector3.new(9.4, 8.6, 16), CFrame.new(0, -0.9, -63), GREY, Enum.Material.Metal)
	part(m, Vector3.new(7, 4, 4), CFrame.new(0, 1.6, -60), Color3.fromRGB(40, 46, 52), Enum.Material.Glass) -- the cockpit
	part(m, Vector3.new(8, 8, 22), CFrame.new(0, 2.2, 66) * CFrame.Angles(math.rad(-8), 0, 0), GREY, Enum.Material.Metal)
	part(m, Vector3.new(156, 1.6, 21), CFrame.new(0, 5.4, -8), GREY, Enum.Material.Metal) -- the wing
	part(m, Vector3.new(1.4, 27, 19), CFrame.new(0, 18, 70), GREY, Enum.Material.Metal) -- the fin
	part(m, Vector3.new(54, 1.2, 12), CFrame.new(0, 31, 74), GREY, Enum.Material.Metal) -- the T-tail
	for _, x in { -54, -29, 29, 54 } do
		part(m, Vector3.new(4.8, 4.8, 15), CFrame.new(x, 2.4, -13), DARK, Enum.Material.Metal)
	end
	for _, x in { -6.5, 6.5 } do
		part(m, Vector3.new(4, 5, 30), CFrame.new(x, -4.4, 2), DARK, Enum.Material.Metal) -- the gear fairings
	end
	m.PrimaryPart = body
	return m, body
end

-- two flares off the tail: bright balls that drop and drift back, then burn out
local function flares(at, right, back)
	for _, side in { -1, 1 } do
		local p = part(fxFolder(), Vector3.new(1.2, 1.2, 1.2), CFrame.new(at), Color3.fromRGB(255, 214, 150), Enum.Material.Neon)
		p.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 196, 120)
		light.Brightness = 4
		light.Range = 36
		light.Parent = p
		local v = right * (side * (18 + math.random() * 10)) + back * 16 + Vector3.new(0, -6, 0)
		local t0, life = os.clock(), 3.6
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local t = os.clock() - t0
			if t >= life or not p.Parent then
				conn:Disconnect()
				p:Destroy()
				return
			end
			p.Position = at + v * t + Vector3.new(0, -9, 0) * t * t
			local k = t / life
			p.Transparency = k * 0.9
			light.Brightness = 4 * (1 - k)
		end)
	end
end

-- the crate as it comes down: the box on its pallet under a round canopy on four lines
local function buildFalling(kind)
	local m = Instance.new("Model")
	m.Name = "ZR_AirdropFalling_" .. tostring(kind)
	local box = part(m, Vector3.new(4.8, 4.4, 4.8), CFrame.new(0, 2.8, 0), OLIVE, Enum.Material.Metal)
	part(m, Vector3.new(5.4, 0.6, 5.4), CFrame.new(0, 0.3, 0), Color3.fromRGB(112, 92, 62), Enum.Material.WoodPlanks)
	local canopy = part(m, Vector3.new(3, 19, 19), CFrame.new(0, 21, 0) * CFrame.Angles(0, 0, math.rad(90)), CANOPY, Enum.Material.Fabric)
	canopy.Shape = Enum.PartType.Cylinder
	for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		local a, b = Vector3.new(c[1] * 2.2, 5, c[2] * 2.2), Vector3.new(c[1] * 6.6, 19.6, c[2] * 6.6)
		part(m, Vector3.new(0.08, 0.08, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(58, 58, 52))
	end
	local _ = box
	m.WorldPivot = CFrame.new() -- the pivot under the pallet: the model is placed by its foot
	return m
end

function AirdropFx.run(d)
	if type(d) ~= "table" or typeof(d.pos) ~= "Vector3" or typeof(d.from) ~= "Vector3" or typeof(d.to) ~= "Vector3" then
		return
	end
	-- only near the map in play: a client in the bunker does not build a plane over a map it cannot see
	local cam = workspace.CurrentCamera
	local me = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local from = (me and me.Position) or (cam and cam.CFrame.Position)
	if from and (Vector3.new(from.X, 0, from.Z) - Vector3.new(d.pos.X, 0, d.pos.Z)).Magnitude > 6000 then
		return
	end
	local dir = (d.to - d.from)
	local len = dir.Magnitude
	if len < 1 then
		return
	end
	dir = dir / len
	local right = dir:Cross(Vector3.new(0, 1, 0)).Unit
	local plane, body = buildPlane()
	plane.Parent = fxFolder()
	local drone, gain = nil, 0
	if E and E.loop then
		drone, gain = E.loop("generator_loop", body)
		if drone then
			drone.PlaybackSpeed = 0.42 -- the generator's drone pitched down: a distant four-engine transport (no plane sound yet)
			drone.RollOffMode = Enum.RollOffMode.InverseTapered
			drone.RollOffMinDistance = 260
			drone.RollOffMaxDistance = 3200
		end
	end
	local falling, landed = nil, false
	local nextFlare = 0
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = now() - (d.t0 or 0)
		-- the plane
		if plane and plane.Parent then
			local k = math.clamp(t / (d.flight or 1), 0, 1)
			local p = d.from + dir * (len * k)
			plane:PivotTo(CFrame.lookAt(p, p + dir))
			if drone then
				local fade = math.min(1, k * 8, (1 - k) * 8)
				drone.Volume = gain * 5 * fade
			end
			-- flares while it crosses the middle of its run
			if t >= nextFlare and math.abs(t - (d.release or 0)) < 9 then
				nextFlare = t + 2.6
				flares(p - dir * 70 + Vector3.new(0, -2, 0), right, -dir)
			end
			if k >= 1 then
				plane:Destroy()
				plane = nil
			end
		end
		-- the crate
		local tr = t - (d.release or 0)
		if tr >= 0 and not landed then
			if not falling then
				falling = buildFalling(d.kind)
				falling.Parent = fxFolder()
			end
			local top = d.pos.Y + ((d.fall or 1) * 7) + 6
			local k = math.clamp(tr / (d.fall or 1), 0, 1)
			local y = top + (d.pos.Y - top) * k
			local sway = math.sin(tr * 1.3) * math.rad(5)
			falling:PivotTo(CFrame.new(d.pos.X, y, d.pos.Z) * CFrame.Angles(sway * 0.6, math.rad(d.yaw or 0) + tr * 0.05, sway))
			if k >= 1 then
				landed = true
				-- the server's crate takes over; this one goes once that one is here (or after 3 s)
				local tl = os.clock()
				task.spawn(function()
					while os.clock() - tl < 3 do
						local f = workspace:FindFirstChild("ZR_Airdrops")
						local found = false
						for _, m in f and f:GetChildren() or {} do
							local pp = m:IsA("Model") and m.PrimaryPart
							if pp and (pp.Position - d.pos).Magnitude < 12 then
								found = true
							end
						end
						if found then
							break
						end
						task.wait(0.1)
					end
					if falling then
						falling:Destroy()
						falling = nil
					end
				end)
			end
		end
		if not plane and landed then
			conn:Disconnect()
		end
	end)
	-- a safety net: everything goes after the whole run
	task.delay((d.release or 0) + (d.fall or 0) + (d.flight or 0) + 10, function()
		if conn.Connected then
			conn:Disconnect()
		end
		if plane then
			plane:Destroy()
		end
		if falling then
			falling:Destroy()
		end
	end)
end

-- a signal flare: a star shot straight up (about 130 studs in 2.2 s) that hangs and sinks while it burns, lighting the
-- ground under it, with a thin smoke trail. d = { p = where it was fired, c = "red" (or another colour) }
local STAR = { red = Color3.fromRGB(255, 70, 52), green = Color3.fromRGB(90, 255, 110), yellow = Color3.fromRGB(255, 220, 90), white = Color3.fromRGB(255, 250, 235) }
function AirdropFx.flare(d)
	if type(d) ~= "table" or typeof(d.p) ~= "Vector3" then
		return
	end
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - d.p).Magnitude > 5000 then
		return
	end
	local col = STAR[d.c] or STAR.red
	local star = part(fxFolder(), Vector3.new(1.8, 1.8, 1.8), CFrame.new(d.p), col, Enum.Material.Neon)
	star.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = col
	light.Brightness = 6
	light.Range = 60
	light.Parent = star
	-- the glare round the star, so it reads as a signal from far off in daylight (a bare ball is a speck at 150 studs)
	local glow = Instance.new("ParticleEmitter")
	glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glow.Color = ColorSequence.new(col)
	glow.LightEmission = 0.55 -- at 1 the bloom washed the red out to white
	glow.LightInfluence = 0
	glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 7), NumberSequenceKeypoint.new(1, 5) })
	glow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	glow.Lifetime = NumberRange.new(0.15, 0.25)
	glow.Rate = 40
	glow.Speed = NumberRange.new(0)
	glow.LockedToPart = true
	glow.Parent = star
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.9, 0), Vector3.new(0, -0.9, 0)
	a0.Parent, a1.Parent = star, star
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 3.5
	trail.Color = ColorSequence.new(Color3.fromRGB(205, 200, 192))
	trail.Transparency = NumberSequence.new(0.25, 1)
	trail.WidthScale = NumberSequence.new(1, 4)
	trail.Parent = star
	if E and E.sfx then
		E.sfx("smoke_pop", d.p, 1.2, 1.25, 250)
	end
	local t0, RISE, BURN = os.clock(), 2.2, 9
	local top = d.p + Vector3.new(math.random() * 6 - 3, 130, math.random() * 6 - 3)
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t >= RISE + BURN or not star.Parent then
			conn:Disconnect()
			star:Destroy()
			return
		end
		if t < RISE then
			local k = t / RISE
			star.Position = d.p:Lerp(top, 1 - (1 - k) * (1 - k)) -- fast off the launcher, slowing at the top
		else
			local k = (t - RISE) / BURN
			star.Position = top + Vector3.new(k * 6, -k * 24, k * 3) -- it sinks and drifts as it burns
			light.Brightness = 6 * (1 - k * 0.6)
			if k > 0.85 then
				star.Transparency = (k - 0.85) / 0.15
			end
		end
	end)
end

function AirdropFx.init(_, effects)
	E = effects
end

return AirdropFx
