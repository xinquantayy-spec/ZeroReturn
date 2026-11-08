--!nonstrict
-- Tiny UI helper kit: "field recorder" instrument style (charcoal panels, 1px pale strokes, mono type).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ItemIcons = require(game:GetService("ReplicatedStorage"):WaitForChild("ZR"):WaitForChild("ItemIcons"))
local WP = require(game:GetService("ReplicatedStorage"):WaitForChild("ZR"):WaitForChild("WeaponParts"))
local GunMeta = WP.META

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
local BASE_C = table.clone(K.C)

-- ── colorblind palettes (decision ui-8a) ─────────────────────────────────────────────────────────────────────
-- EFT's COLORBLIND MODE filters the whole picture. Roblox cannot remap the colour channels of the 3D image, so the
-- HUD's and the menus' colours are daltonized instead (Fidaner, Lin and Ozguven, as the common daltonize tools do it):
-- what a protanope, deuteranope or tritanope would see is simulated in LMS space, and the difference they lose is moved
-- into the channels they still see. Words and shapes stay beside every colour. mode 0 none, 1 protanopia,
-- 2 deuteranopia, 3 tritanopia; k the intensity (0 to 1, EFT's slider).
local SIM = {
	function(l, m, s)
		return 2.02344 * m - 2.52581 * s, m, s
	end,
	function(l, m, s)
		return l, 0.494207 * l + 1.24827 * s, s
	end,
	function(l, m, s)
		return l, m, -0.395913 * l + 0.801109 * m
	end,
}
function K.cvd(c, mode, k)
	local sim = SIM[mode or 0]
	k = math.clamp(k or 0, 0, 1)
	if not sim or k <= 0 then
		return c
	end
	local r, g, b = c.R * 255, c.G * 255, c.B * 255
	local l = 17.8824 * r + 43.5161 * g + 4.11935 * b
	local m = 3.45565 * r + 27.1554 * g + 3.86714 * b
	local s = 0.0299566 * r + 0.184309 * g + 1.46709 * b
	l, m, s = sim(l, m, s)
	local r2 = 0.0809444479 * l - 0.130504409 * m + 0.116721066 * s
	local g2 = -0.0102485335 * l + 0.0540193266 * m - 0.113614708 * s
	local b2 = -0.000365296938 * l - 0.00412161469 * m + 0.693511405 * s
	local er, eg, eb = r - r2, g - g2, b - b2
	local ng = g + (0.7 * er + eg) * k
	local nb = b + (0.7 * er + eb) * k
	return Color3.fromRGB(math.clamp(math.floor(r + 0.5), 0, 255), math.clamp(math.floor(ng + 0.5), 0, 255), math.clamp(math.floor(nb + 0.5), 0, 255))
end

-- recolour a palette table in place from its base colours (the menus' K.C here; the HUD passes its own)
K.cvdMode, K.cvdK = 0, 1
function K.recolour(tbl, base)
	for key, col in base do
		tbl[key] = K.cvd(col, K.cvdMode, K.cvdK)
	end
end

-- the colorblind setting changed: true when the palettes changed (the open screens then need building again)
function K.setCvd(mode, k)
	mode, k = math.floor(tonumber(mode) or 0), math.clamp(tonumber(k) or 1, 0, 1)
	if mode == K.cvdMode and math.abs(k - K.cvdK) < 1e-3 then
		return false
	end
	K.cvdMode, K.cvdK = mode, k
	K.recolour(K.C, BASE_C)
	return true
end

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

local function rawViewport(gui)
	if K.previewSize then
		return K.previewSize -- Studio preview of another screen size (ZR_ClientDev "preview")
	end
	if gui and gui.AbsoluteSize.Y > 0 then
		return gui.AbsoluteSize -- safe area (excludes Roblox top bar / notches)
	end
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
	return Vector2.new(v.X, v.Y - 58)
end

-- MENU TEXT SIZE (decision ui-8a, 100 to 150 %): each menu screen's content sits in a root frame laid out for the screen
-- divided by this scale and drawn that much larger by a UIScale, so text, buttons and gaps grow together and every
-- layout still fits (a phone at 150 % gets the compact layouts sooner). The HUD keeps HUD SCALE.
K.menuScale = 1
local rooted = setmetatable({}, { __mode = "k" }) -- ScreenGui -> its root frame

-- the size a menu screen lays out for: the safe area divided by the menu scale
function K.viewport(gui)
	return rawViewport(gui) / K.menuScale
end

-- uniform scale for HUD-like text based on screen height (720p reference; not the menu scale)
function K.scale()
	local v = rawViewport()
	return math.clamp(v.Y / 720, 0.72, 1.6)
end

-- a menu ScreenGui's root frame (made on first use): menu content is parented here
function K.root(gui)
	local r = rooted[gui]
	if r and r.Parent == gui then
		return r
	end
	r = K.new("Frame", { Name = "ZR_Root", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1 / K.menuScale, 1 / K.menuScale) }, gui)
	K.new("UIScale", { Name = "MenuScale", Scale = K.menuScale }, r)
	rooted[gui] = r
	return r
end

-- a new menu scale for every root; true when it changed (the open screens then need building again)
function K.setMenuScale(s)
	s = math.clamp(tonumber(s) or 1, 1, 1.5)
	if math.abs(s - K.menuScale) < 1e-3 then
		return false
	end
	K.menuScale = s
	for _, r in rooted do
		if r.Parent then
			r.Size = UDim2.fromScale(1 / s, 1 / s)
			local u = r:FindFirstChild("MenuScale")
			if u then
				u.Scale = s
			end
		end
	end
	return true
end

-- a point in GUI space (AbsolutePosition's: GetMouseLocation less GuiService:GetGuiInset()) in a menu root's own
-- units; and a length the same way
function K.toLocal(gui, pt)
	local r = rooted[gui]
	if not r then
		return pt
	end
	return (pt - r.AbsolutePosition) / K.menuScale
end
function K.toLocalLen(v)
	return v / K.menuScale
end

-- an item's Blender picture centred in `parent`, w x h pixels as the item lies there; rotated: the item lies turned
-- (its picture turns 90 degrees); unknown: a dark silhouette until examined. Weapon parts and guns are drawn from
-- their part sprites (the same renders as the gun pictures, so a lone grip matches the grip on a gun); a gun id
-- may name a preset as "BASE#PRESET" (trader offers). maxScale: UI pixels per atlas pixel at most (stash scale).
function K.itemIcon(parent, id, w, h, rotated, unknown, z, maxScale)
	local base, preset = string.match(id, "^([^#]+)#(.+)$")
	base = base or id
	if not unknown and K.partPictures and K.partPictures(base) then
		local items, g = K.iconItems(base, preset)
		-- a small part's sprite blown up past 2.5x goes soft: its own close-up render reads better then
		local _, b = K.gunSprites(items, g)
		local pw, ph = rotated and h or w, rotated and w or h
		local sc = b and math.min(pw / math.max(1, b.x1 - b.x0), ph / math.max(1, b.y1 - b.y0), maxScale or math.huge) or 0
		if b and (sc <= 2.5 or not ItemIcons.items[base] or preset ~= nil or WP.isBase(base)) then
			local pic = K.gunPicture(parent, items, g, w, h, rotated, z, maxScale)
			if pic then
				pic.Name = "Icon"
				return pic
			end
		end
	end
	local ic = ItemIcons.items[base]
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
	local base = string.match(id, "^([^#]+)") or id
	return ItemIcons.items[base] ~= nil or (K.partPictures ~= nil and K.partPictures(base))
end

-- ── M14: a gun's picture put together from its parts ─────────────────────────
-- Tarkov draws a weapon as it is built: every part's side-view sprite (GunMeta, rendered in Blender at one scale
-- per picture class) is placed at its slot, back to front (WeaponParts.LAYER), and the whole build is fitted into
-- the item's tile. Parts turned onto a side rail use their turned sprite; ones on the far side go behind.
-- does this item have part sprites (a weapon part, magazine or gun with a part record)?
function K.partPictures(id)
	local pm = GunMeta.parts[id]
	if not pm then
		return false
	end
	-- the sprite of the part itself must be in the sheet
	return GunMeta.sprites[id .. "@" .. pm.cls] ~= nil
end

-- an item table to draw a lone item from: a part on its own, or a gun as its preset (default) build
function K.iconItems(base, preset)
	if not WP.isBase(base) then
		return { x = { id = base, n = 1 } }, "x"
	end
	local pr = GunMeta.presets[preset or base]
	if not pr or pr.base ~= base then
		pr = GunMeta.presets[base]
	end
	if not pr then
		return { x = { id = base, n = 1 } }, "x"
	end
	local items, n = {}, 0
	local function grow(t)
		n += 1
		local g = "p" .. n
		local it = { id = t[1], n = 1 }
		items[g] = it
		for sname, sub in t[2] do
			local cg = grow(sub)
			if sname == "mag" then
				it.mag = cg
			else
				it.mods = it.mods or {}
				it.mods[sname] = cg
			end
		end
		return g
	end
	return items, grow(pr.tree)
end

-- the sprites of a build in atlas pixels around the root's origin: { { spr, cx, cy, rot, layer } }, bounds
function K.gunSprites(items, g)
	local root = items[g]
	local meta = root and GunMeta.parts[root.id]
	if not meta then
		return nil
	end
	local cls = meta.cls
	local pps = (GunMeta.classes[cls] or 5.5) * GunMeta.cell / GunMeta.U -- atlas pixels per stud
	local out = {}
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, e in WP.layout(items, g) do
		local up = e.cf.UpVector
		local rolled = math.abs(up.X) > 0.7
		local name = e.id .. "@" .. cls
		if rolled and GunMeta.sprites[name .. "@L"] then
			name ..= "@L"
		end
		local sp = GunMeta.sprites[name]
		if sp then
			local p = WP.parts[e.id]
			local cat = (e.slot == "mag" and e.depth == 1) and "mag" or (p and p.cat) or (WP.isBase(e.id) and "base") or "mag"
			local layer = WP.LAYER[cat] or 30
			if rolled and up.X < 0 then
				layer = 5 -- on the far side of the gun: mostly hidden behind it
			end
			-- the part's own +Z (toward the stock) in the picture plane: right = +Z, up = +Y
			local zv = e.cf.ZVector
			local ang = math.atan2(zv.Y, zv.Z)
			local rot = -math.deg(ang) -- GuiObject.Rotation turns clockwise
			local ox, oy = e.cf.Position.Z * pps, -e.cf.Position.Y * pps
			-- the sprite's centre relative to its origin pixel, turned with the part
			local dx, dy = sp[4] / 2 - sp[6], sp[5] / 2 - sp[7]
			local c, s = math.cos(math.rad(rot)), math.sin(math.rad(rot))
			local cx, cy = ox + dx * c - dy * s, oy + dx * s + dy * c
			table.insert(out, { spr = sp, cx = cx, cy = cy, rot = rot, layer = layer })
			local hw, hh = sp[4] / 2, sp[5] / 2
			x0, y0, x1, y1 = math.min(x0, cx - hw), math.min(y0, cy - hh), math.max(x1, cx + hw), math.max(y1, cy + hh)
		end
	end
	if #out == 0 then
		return nil
	end
	table.sort(out, function(a, b)
		return a.layer < b.layer
	end)
	return out, { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

-- the build picture in `parent`, w x h pixels as the item lies there (rotated: turned 90 degrees in the grid);
-- scale = UI pixels per atlas pixel at most (keeps every gun at the same scale in a stash, like Tarkov's icons)
function K.gunPicture(parent, items, g, w, h, rotated, z, maxScale)
	local list, b = K.gunSprites(items, g)
	if not list then
		return nil
	end
	local bw, bh = b.x1 - b.x0, b.y1 - b.y0
	local pw, ph = rotated and h or w, rotated and w or h
	local pad = math.max(1, math.floor(math.min(pw, ph) * 0.03))
	local s = math.min((pw - pad * 2) / math.max(1, bw), (ph - pad * 2) / math.max(1, bh), maxScale or math.huge)
	local holder = K.new("Frame", {
		Name = "GunPicture", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(pw, ph), Rotation = rotated and 90 or 0, ZIndex = z or 4,
	}, parent)
	pcall(function()
		holder.Interactable = false
	end)
	local mx, my = (b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2
	for i, e in list do
		local sp = e.spr
		local img = K.new("ImageLabel", {
			Name = "Part", BackgroundTransparency = 1, Image = GunMeta.sheets[sp[1]], ImageRectOffset = Vector2.new(sp[2], sp[3]),
			ImageRectSize = Vector2.new(sp[4], sp[5]), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, (e.cx - mx) * s, 0.5, (e.cy - my) * s), Size = UDim2.fromOffset(sp[4] * s, sp[5] * s),
			Rotation = e.rot, ZIndex = i,
		}, holder)
		pcall(function()
			img.Interactable = false
		end)
	end
	return holder
end

-- is this item drawn from its parts (a gun base, or a part with parts on it)?
function K.isBuild(items, g)
	local it = items and items[g]
	return it ~= nil and WP.measured(it) and GunMeta.parts[it.id] ~= nil
end

return K

