--!nonstrict
-- Tiny UI helper kit: "field recorder" instrument style (charcoal panels, 1px pale strokes, mono type).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

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
		selectionTemplate = K.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Name = "EFB_Select" })
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
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
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

return K
