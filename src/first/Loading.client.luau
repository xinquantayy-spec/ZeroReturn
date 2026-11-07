--!strict
-- The join card. ReplicatedFirst runs before the rest of the game, so this covers the screen from the first frame
-- until the client has its first state from the server (LocalPlayer attribute ZR_Ready, set by State.luau). A fresh
-- server builds its maps before it lets clients in; the card says which stage it is at (the ReplicatedStorage
-- attribute ZR_Boot, set by Main.server.luau and World.luau), the way Tarkov's loading screen names its stages.
-- It never gives up: the game cannot run without the server's state.
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local lp = Players.LocalPlayer
local mono = Font.fromEnum(Enum.Font.RobotoMono)
local bold = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local TEXT = Color3.fromRGB(226, 228, 220)
local DIM = Color3.fromRGB(140, 146, 138)
local RED = Color3.fromRGB(214, 58, 46)

local gui = Instance.new("ScreenGui")
gui.Name = "ZR_Loading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ScreenInsets = Enum.ScreenInsets.None

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(10, 12, 11)
bg.BorderSizePixel = 0
bg.Parent = gui

local function label(text: string, font: Font, size: number, color: Color3, pos: UDim2, anchor: Vector2, align: Enum.TextXAlignment): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = font
	t.TextSize = size
	t.TextColor3 = color
	t.Text = text
	t.AutomaticSize = Enum.AutomaticSize.XY
	t.Position = pos
	t.AnchorPoint = anchor
	t.TextXAlignment = align
	t.Parent = bg
	return t
end

-- the bodycam frame: four corner brackets, as on the raid HUD
for i, c in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
	for _, horizontal in { true, false } do
		local b = Instance.new("Frame")
		b.BorderSizePixel = 0
		b.BackgroundColor3 = DIM
		b.AnchorPoint = c
		b.Size = horizontal and UDim2.fromOffset(46, 2) or UDim2.fromOffset(2, 46)
		b.Position = UDim2.new(c.X, c.X == 0 and 24 or -24, c.Y, c.Y == 0 and 24 or -24)
		b.Name = "Corner" .. i
		b.Parent = bg
	end
end

local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(10, 10)
dot.Position = UDim2.new(1, -40, 0, 46)
dot.AnchorPoint = Vector2.new(1, 0.5)
dot.BackgroundColor3 = RED
dot.BorderSizePixel = 0
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = dot
dot.Parent = bg
label("STBY", bold, 18, TEXT, UDim2.new(1, -56, 0, 46), Vector2.new(1, 0.5), Enum.TextXAlignment.Right)
label("ZR BODYCAM 4", bold, 16, DIM, UDim2.new(0, 40, 0, 46), Vector2.new(0, 0.5), Enum.TextXAlignment.Left)

local status = label("CONNECTING", bold, 22, TEXT, UDim2.fromScale(0.5, 0.48), Vector2.new(0.5, 0.5), Enum.TextXAlignment.Center)
local sub = label("", mono, 14, DIM, UDim2.new(0.5, 0, 0.48, 62), Vector2.new(0.5, 0.5), Enum.TextXAlignment.Center)
local clock = label("00:00", mono, 14, DIM, UDim2.new(0, 40, 1, -46), Vector2.new(0, 0.5), Enum.TextXAlignment.Left)

-- Tarkov's raid loading screen (patch 1.0.1.0, December 2025): a progress bar, the time left and the total wait. Ours
-- follows the server's boot (ReplicatedStorage attribute ZR_BootP, 0 to 1); the wait is the clock bottom left.
local track = Instance.new("Frame")
track.AnchorPoint = Vector2.new(0.5, 0.5)
track.Position = UDim2.new(0.5, 0, 0.48, 30)
track.Size = UDim2.new(0.36, 0, 0, 3)
track.BackgroundColor3 = Color3.fromRGB(44, 48, 45)
track.BorderSizePixel = 0
track.Parent = bg
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = TEXT
fill.BorderSizePixel = 0
fill.Parent = track
local left = label("", mono, 13, DIM, UDim2.new(0.5, 0, 0.48, 44), Vector2.new(0.5, 0.5), Enum.TextXAlignment.Center)

gui.Parent = lp:WaitForChild("PlayerGui")

local t0 = os.clock()
local done = false
local function finish()
	if done then
		return
	end
	done = true
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bg, info, { BackgroundTransparency = 1 }):Play()
	for _, d in bg:GetDescendants() do
		if d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextTransparency = 1 }):Play()
		elseif d:IsA("Frame") then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		end
	end
	task.delay(0.5, function()
		gui:Destroy()
	end)
end
lp:GetAttributeChangedSignal("ZR_Ready"):Connect(function()
	if lp:GetAttribute("ZR_Ready") then
		finish()
	end
end)

while not done do
	if lp:GetAttribute("ZR_Ready") then
		finish()
		break
	end
	local secs = os.clock() - t0
	local phase = ReplicatedStorage:GetAttribute("ZR_Boot")
	local p = ReplicatedStorage:GetAttribute("ZR_BootP")
	p = type(p) == "number" and math.clamp(p, 0, 1) or 0
	if phase == "READY" or phase == nil then
		-- a running server: the bar is full once the client has the world; until then it waits on the first state
		p = phase == "READY" and 1 or 0
	end
	fill.Size = UDim2.fromScale(math.max(fill.Size.X.Scale, p), 1)
	if p >= 0.1 and p < 1 and type(phase) == "string" and phase ~= "READY" then
		-- the estimate is the server's time so far stretched over what is left (its own pace)
		local bt0 = ReplicatedStorage:GetAttribute("ZR_BootT0")
		local bootSecs = type(bt0) == "number" and math.max(0, workspace:GetServerTimeNow() - bt0) or secs
		local est = math.max(1, math.floor(bootSecs * (1 - p) / p + 0.5))
		left.Text = string.format("ABOUT %d S LEFT", est)
	else
		left.Text = ""
	end
	if type(phase) ~= "string" then
		status.Text = "CONNECTING"
	elseif phase == "READY" then
		status.Text = "JOINING"
	else
		status.Text = "SERVER STARTING  ·  " .. phase
	end
	if secs > 90 then
		sub.Text = "THE SERVER IS TAKING LONGER THAN USUAL  ·  REJOIN IF THIS LASTS"
	elseif type(phase) == "string" and phase ~= "READY" then
		sub.Text = "A NEW SERVER BUILDS ITS MAPS BEFORE THE FIRST RAID"
	else
		sub.Text = ""
	end
	clock.Text = string.format("%02d:%02d", math.floor(secs / 60), math.floor(secs % 60))
	dot.BackgroundTransparency = (math.floor(secs * 2) % 2 == 0) and 0 or 0.7
	task.wait(0.25)
end
