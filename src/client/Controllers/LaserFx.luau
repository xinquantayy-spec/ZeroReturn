--!nonstrict
-- Visible lasers (Tarkov's tactical lasers, the LC-4 and LP-1): every client draws the beam and the dot of each gun whose
-- laser is on. Its own in first person comes from the viewmodel's aperture (Weapon.deviceState); everyone else's, people
-- and AI, from the third-person gun's LaserEmitter while the server has WeaponLaser set (Combat.setLight, AI). A thin red
-- beam, clear in the dark and a hint by day, and a bright dot where it lands, up to 250 studs; nothing is drawn beyond
-- 600 studs of the camera.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LaserFx = {}
local ctx = nil
local RANGE, FAR = 250, 600
local RED = Color3.fromRGB(255, 38, 28)
local folder = nil
local pool = {} -- [key] = { beam, dot }
local emitters = {} -- [model] = the LaserEmitter attachment
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.IgnoreWater = true

local function fxFolder()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "ZR_LaserFx"
		folder.Parent = workspace
	end
	return folder
end

local function bare(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = RED
	return p
end

local function pairOf(key)
	local pr = pool[key]
	if pr and pr.beam.Parent then
		return pr
	end
	local beam = bare(Instance.new("Part"))
	beam.Name = "LaserBeam"
	beam.Transparency = 0.72
	local dot = bare(Instance.new("Part"))
	dot.Name = "LaserDot"
	dot.Shape = Enum.PartType.Ball
	dot.Size = Vector3.new(0.16, 0.16, 0.16)
	local glow = Instance.new("PointLight")
	glow.Color = RED
	glow.Range = 2.5
	glow.Brightness = 1.6
	glow.Shadows = false
	glow.Parent = dot
	beam.Parent, dot.Parent = fxFolder(), fxFolder()
	pr = { beam = beam, dot = dot }
	pool[key] = pr
	return pr
end

local beamAlpha = 0.72
local camPos = Vector3.zero
-- the instances a beam passes through (no holes in the list when one is missing)
local function skip(a, b)
	local t = { fxFolder() }
	if a then
		table.insert(t, a)
	end
	if b then
		table.insert(t, b)
	end
	return t
end

local function draw(key, origin, dir, ignore)
	rp.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(origin, dir * RANGE, rp)
	local stop = hit and hit.Position or (origin + dir * RANGE)
	local len = math.max(0.05, (stop - origin).Magnitude)
	local pr = pairOf(key)
	pr.beam.Transparency = beamAlpha
	pr.beam.Size = Vector3.new(0.026, 0.026, len)
	pr.beam.CFrame = CFrame.lookAt(origin, stop) * CFrame.new(0, 0, -len / 2)
	pr.dot.Transparency = hit and 0 or 1
	if hit then
		-- the dot keeps a few pixels at range, like a real laser's glare
		local d = math.max(0.12, (stop - camPos).Magnitude * 0.007)
		if math.abs(pr.dot.Size.X - d) > 0.01 then
			pr.dot.Size = Vector3.new(d, d, d)
		end
		pr.dot.CFrame = CFrame.new(stop + hit.Normal * (d * 0.3))
	end
end

-- the gun's emitter on a character or an AI (cached until the gun changes)
local function emitterOf(model)
	local em = emitters[model]
	if em and em.Parent and em:IsDescendantOf(model) then
		return em
	end
	em = model:FindFirstChild("LaserEmitter", true)
	emitters[model] = em
	return em
end

local function update()
	local used = {}
	local lp = Players.LocalPlayer
	local mine = lp.Character
	local cam = workspace.CurrentCamera
	camPos = cam and cam.CFrame.Position or Vector3.zero
	-- the beam shows in the dark and fades to a hint by day (the dot stays bright)
	local A = ctx and ctx.Atmos
	beamAlpha = 0.88 - 0.26 * math.clamp((A and A.dark) or 0, 0, 1)
	local W = ctx and ctx.Weapon
	local vmModel = nil
	if W and W.deviceState and W.vmLaser then
		local _, laser = W.deviceState()
		local ap
		ap, vmModel = W.vmLaser()
		if laser and ap and ap.Parent then
			local cf = ap.CFrame
			draw("me", cf.Position, cf.RightVector, skip(mine, vmModel))
			used.me = true
		end
	end
	-- someone else's laser stops on whatever it meets, this player included (the dot lands on you)
	local function consider(model)
		if model and model ~= mine and model:GetAttribute("WeaponLaser") == true then
			local em = emitterOf(model)
			if em and em.Parent and (em.WorldPosition - camPos).Magnitude < FAR then
				draw(model, em.WorldPosition, em.Parent.CFrame.RightVector, skip(model, vmModel))
				used[model] = true
			end
		end
	end
	for _, p in Players:GetPlayers() do
		if p ~= lp then
			consider(p.Character)
		end
	end
	local ai = workspace:FindFirstChild("ZR_AI")
	if ai then
		for _, m in ai:GetChildren() do
			consider(m)
		end
	end
	for key, pr in pool do
		if not used[key] then
			pr.beam:Destroy()
			pr.dot:Destroy()
			pool[key] = nil
		end
	end
	for model in emitters do
		if not model.Parent then
			emitters[model] = nil
		end
	end
end

function LaserFx.init(c)
	ctx = c
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(update)
		if not ok then
			warn("[ZR] LaserFx", err)
		end
	end)
end

return LaserFx
