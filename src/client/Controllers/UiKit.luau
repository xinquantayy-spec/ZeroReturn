--!nonstrict
-- Tiny UI helper kit: "field recorder" instrument style (charcoal panels, 1px pale strokes, mono type).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ItemIcons = require(game:GetService("ReplicatedStorage"):WaitForChild("ZR"):WaitForChild("ItemIcons"))

local K = {}
K.font = Font.fromEnum(Enum.Font.RobotoMono)
K.bold = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local function hex(h)
	return Color3.fromHex(h)
end
K.C = {
	bg = hex("101314"), panel = hex("1B1F21"), panel2 = hex("252A2C"), cell = hex("2C3234"), line = hex("D6DBC9"),
	text = hex("D6DBC9"), dim = hex("8C948D"), ochre = hex("C9A13C"), orange = hex("C07946"), rust = hex("8A6252"),
	red = hex("C24A35"), green = hex("93A57C"), black = hex("000000"),
}

function K.new(class, props, parent)
	local i = Instance.new(class)
	for k, v in props or {} do
		i[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end

function K.stroke(parent, color, transparency, thickness)
	return K.new("UIStroke", {
		Color = color or K.C.line, Transparency = transparency or 0.55, Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function K.frame(parent, props)
	local f = K.new("Frame", { BackgroundColor3 = K.C.panel, BorderSizePixel = 0, Name = "Panel" }, parent)
	for k, v in props or {} do
		f[k] = v
	end
	return f
end

function K.label(parent, text, size, props)
	local l = K.new("TextLabel", {
		BackgroundTransparency = 1, FontFace = K.font, Text = text or "", TextSize = size or 14, TextColor3 = K.C.text,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, RichText = true,
		Size = UDim2.new(1, 0, 0, (size or 14) + 6),
	}, parent)
	for k, v in props or {} do
		l[k] = v
	end
	return l
end

local selectionTemplate
function K.selection()
	if not selectionTemplate then
		selectionTemplate = K.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Name = "ZR_Select" })
		K.stroke(selectionTemplate, K.C.ochre, 0, 2)
	end
	return selectionTemplate
end

function K.button(parent, text, props, onClick)
	local b = K.new("TextButton", {
		BackgroundColor3 = K.C.panel2, BorderSizePixel = 0, AutoButtonColor = true, FontFace = K.bold, Text = text or "",
		TextSize = 14, TextColor3 = K.C.text, Size = UDim2.fromOffset(120, 34), Selectable = true,
		SelectionImageObject = K.selection(),
	}, parent)
	K.stroke(b, K.C.line, 0.6)
	b.Name = "Btn_" .. string.gsub(string.upper(text or ""), "[^%w]", "")
	for k, v in props or {} do
		b[k] = v
	end
	b.Activated:Connect(K.click)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- shared UI click (one cached Sound, restarted per press)
local clickSound
function K.click()
	local id = require(game:GetService("ReplicatedStorage"):WaitForChild("ZR").Sounds).UI_CLICK
	if id == "" then
		return
	end
	if not clickSound then
		clickSound = Instance.new("Sound")
		clickSound.SoundId = id
		clickSound.Volume = 0.22
		clickSound.PlaybackSpeed = 1.6
		clickSound.Parent = game:GetService("SoundService")
	end
	clickSound.TimePosition = 0
	clickSound:Play()
end

function K.pad(parent, px)
	return K.new("UIPadding", {
		PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px), PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
	}, parent)
end

function K.list(parent, dir, gap, align)
	return K.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical, Padding = UDim.new(0, gap or 6), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	}, parent)
end

function K.screen(name, order)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	return K.new("ScreenGui", {
		Name = name, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = order or 1,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, pg)
end

function K.focus(obj)
	if obj and GuiService then
		pcall(function()
			GuiService.SelectedObject = obj
		end)
	end
end

function K.viewport(gui)
	if gui and gui.AbsoluteSize.Y > 0 then
		return gui.AbsoluteSize -- safe area (excludes Roblox top bar / notches)
	end
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
	return Vector2.new(v.X, v.Y - 58)
end

-- uniform scale for HUD-like text based on screen height (720p reference)
function K.scale()
	local v = K.viewport()
	return math.clamp(v.Y / 720, 0.72, 1.6)
end

-- an item's Blender picture (ItemIcons atlas) centred in `parent`, w x h pixels as the item lies there;
-- rotated: the item lies turned (its picture turns 90 degrees); unknown: a dark silhouette until examined
function K.itemIcon(parent, id, w, h, rotated, unknown, z)
	local ic = ItemIcons.items[id]
	if not ic then
		return nil
	end
	local pad = math.max(1, math.floor(math.min(w, h) * 0.04))
	local img = K.new("ImageLabel", {
		Name = "Icon", BackgroundTransparency = 1, Image = ItemIcons.sheets[ic[1]], ImageRectOffset = Vector2.new(ic[2], ic[3]),
		ImageRectSize = Vector2.new(ic[4], ic[5]), ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), ZIndex = z or 4,
		Size = rotated and UDim2.fromOffset(h - pad * 2, w - pad * 2) or UDim2.fromOffset(w - pad * 2, h - pad * 2),
		Rotation = rotated and 90 or 0,
	}, parent)
	if unknown then
		img.ImageColor3 = Color3.fromRGB(26, 28, 29)
		img.ImageTransparency = 0.15
	end
	pcall(function()
		img.Interactable = false
	end)
	return img
end

function K.hasIcon(id)
	return ItemIcons.items[id] ~= nil
end

return K

