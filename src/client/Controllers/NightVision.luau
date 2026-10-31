--!nonstrict
-- Tarkov's night vision, thermal goggles and face shields (docs/design/EFT_PARITY.md section 6). Goggles sit on a
-- helmet's mount or a head strap; N (Tarkov's key) flips them down or up, with a short black-out while they move.
-- Down, the world is seen through the tube: its mask (a small circle for the monocular, a pair for binoculars, a
-- wide band for the panoramic quad), its phosphor colour, its gain (night turns bright, day washes out), its grain,
-- and bloom that floods round lights on the cheaper tubes. The thermal goggles show heat: people and animals glow
-- white against a dark brown world whatever the light, and magnified optics cannot be used with them.
-- Without goggles, N raises or lowers a helmet's face shield (the server knows: a raised shield leaves the face
-- open); a lowered shield is a tinted visor round the view.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)

local NV = { down = false, dev = nil, visorUp = false }
local ctx
local gui, hole, stroke, visor, cc
local flipT, FLIP = -10, 0.45
local highlights = {}
local BODY_FOLDERS = { "ZR_AI", "ZR_Traders" }
local scanT = 0

-- the goggles on the worn helmet or strap: (def, part record) or nil
function NV.device()
	local d = ctx.State.data
	if not d or not d.slots or not d.items then
		return nil
	end
	local hg = d.slots.head
	local h = hg and d.items[hg]
	local mg = h and h.mods and h.mods.mount
	local m = mg and d.items[mg]
	local def = m and Items.defs[m.id]
	if def and def.part and def.part.nv then
		return def, def.part.nv
	end
	return nil
end

local function visorHelmet()
	local d = ctx.State.data
	local hg = d and d.slots and d.slots.head
	local h = hg and d.items[hg]
	local def = h and Items.defs[h.id]
	return def and def.armor and def.armor.face == true
end

-- thermal goggles down: no magnified optics (Tarkov: iron sights only)
function NV.blocksOptics()
	return NV.down and NV.dev ~= nil and NV.dev.thermal == true
end

local function setHighlights(on)
	if not on then
		for m, h in highlights do
			h:Destroy()
			highlights[m] = nil
		end
		return
	end
	-- the nearest 30 bodies (Roblox draws at most 31 highlights)
	local camPos = workspace.CurrentCamera.CFrame.Position
	-- bodies live in a few places: players' characters, the AI folder, the lobby's people (no full-workspace scan)
	local list = {}
	local function consider(m)
		if m ~= Players.LocalPlayer.Character and m:FindFirstChildOfClass("Humanoid") then
			local root = m:FindFirstChild("HumanoidRootPart")
			local dist = root and (root.Position - camPos).Magnitude
			if dist and dist < 260 and m:FindFirstChildOfClass("Humanoid").Health > 0 then
				table.insert(list, { m, dist })
			end
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			consider(p.Character)
		end
	end
	for _, name in BODY_FOLDERS do
		local f = workspace:FindFirstChild(name)
		if f then
			for _, m in f:GetChildren() do
				if m:IsA("Model") then
					consider(m)
				end
			end
		end
	end
	table.sort(list, function(a, b)
		return a[2] < b[2]
	end)
	local keep = {}
	for i = 1, math.min(30, #list) do
		keep[list[i][1]] = true
	end
	for m, h in highlights do
		if not keep[m] or not m.Parent then
			h:Destroy()
			highlights[m] = nil
		end
	end
	for m in keep do
		if not highlights[m] then
			local h = Instance.new("Highlight")
			h.FillColor = Color3.fromRGB(255, 250, 240)
			h.FillTransparency = 0.04
			h.OutlineTransparency = 1
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Adornee = m
			h.Parent = workspace.CurrentCamera
			highlights[m] = h
		end
	end
end

local function apply(dt)
	local def, dev = NV.device()
	if not dev and NV.down then
		NV.down = false
	end
	NV.dev = NV.down and dev or nil
	local t = os.clock() - flipT
	-- the flip: the view goes black for a moment while the tubes move
	local black = (t < FLIP) and math.sin(math.clamp(t / FLIP, 0, 1) * math.pi) or 0
	local on = NV.dev ~= nil and t >= FLIP * 0.5
	local Post = ctx.Post
	if on then
		local v = workspace.CurrentCamera.ViewportSize
		local hgt = v.Y * (NV.dev.mask == "mono" and 0.62 or NV.dev.mask == "quad" and 1.02 or 0.86)
		local wid = hgt * (NV.dev.mask == "mono" and 1 or NV.dev.mask == "quad" and 2.0 or 1.55)
		hole.Size = UDim2.fromOffset(wid, hgt)
		hole.Visible = true
		cc.Enabled = true
		cc.TintColor = NV.dev.tint
		if NV.dev.thermal then
			cc.Saturation, cc.Contrast, cc.Brightness = -1, 0.45, -0.18
			Post.nvExposure = -Post.envExposure - 0.2 -- light does not matter to a thermal
			scanT -= dt
			if scanT <= 0 then
				scanT = 0.4
				setHighlights(true)
			end
		else
			cc.Saturation, cc.Contrast, cc.Brightness = -1, 0.22, 0.04
			Post.nvExposure = NV.dev.gain
			setHighlights(false)
		end
		Post.nvGrain, Post.nvBloom = NV.dev.grain, NV.dev.bloom
	else
		hole.Visible = false
		cc.Enabled = false
		Post.nvExposure, Post.nvGrain, Post.nvBloom = 0, 1, 0
		setHighlights(false)
	end
	stroke.Transparency = 0
	gui.BackgroundFrame.BackgroundTransparency = 1 - black
	-- a lowered face shield: a tinted visor edge
	visor.Visible = (not NV.dev) and visorHelmet() and not NV.visorUp
end

local function toggle()
	local def = NV.device()
	if def then
		NV.down = not NV.down
		flipT = os.clock()
		ctx.Effects.sfx("selector", game:GetService("SoundService"), 0.35, NV.down and 0.8 or 0.7)
		return
	end
	if visorHelmet() then
		NV.visorUp = not NV.visorUp
		ctx.State.act("visor", { up = NV.visorUp })
		ctx.Effects.sfx("selector", game:GetService("SoundService"), 0.3, 0.7)
	end
end

function NV.init(c)
	ctx = c
	gui = Instance.new("ScreenGui")
	gui.Name = "ZR_NightVision"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -2 -- under the HUD
	local bf = Instance.new("Frame")
	bf.Name = "BackgroundFrame"
	bf.Size = UDim2.fromScale(1, 1)
	bf.BackgroundColor3 = Color3.new(0, 0, 0)
	bf.BackgroundTransparency = 1
	bf.BorderSizePixel = 0
	bf.ZIndex = 3
	bf.Parent = gui
	-- the tube mask: a rounded hole whose huge black stroke covers the rest of the screen
	hole = Instance.new("Frame")
	hole.Name = "Tube"
	hole.AnchorPoint = Vector2.new(0.5, 0.5)
	hole.Position = UDim2.fromScale(0.5, 0.5)
	hole.BackgroundTransparency = 1
	hole.Visible = false
	hole.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = hole
	stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 2400
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = hole
	-- face shield visor: tinted, darker at the edges
	visor = Instance.new("Frame")
	visor.Name = "Visor"
	visor.Size = UDim2.fromScale(1, 1)
	visor.BackgroundColor3 = Color3.fromRGB(40, 52, 58)
	visor.BackgroundTransparency = 0.86
	visor.BorderSizePixel = 0
	visor.Visible = false
	visor.Parent = gui
	local vs = Instance.new("UIStroke")
	vs.Color = Color3.fromRGB(16, 18, 18)
	vs.Thickness = 90
	vs.Transparency = 0.25
	vs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	vs.Parent = visor
	local vc = Instance.new("UICorner")
	vc.CornerRadius = UDim.new(0.18, 0)
	vc.Parent = visor
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ZR_NightVision"
	cc.Enabled = false
	cc.Parent = Lighting
	c.Input.on("ToggleNVG", function(down)
		if down then
			toggle()
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(apply, dt)
		if not ok then
			warn("[ZR] night vision:", err)
		end
	end)
end

return NV
