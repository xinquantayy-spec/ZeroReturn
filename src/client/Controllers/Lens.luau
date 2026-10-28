--!nonstrict
-- Lens HUD kit. Text and icons are laid out glyph by glyph and pushed through a barrel (fisheye) mapping so
-- the overlay reads as if it sits on the recorder lens: lines bow, glyphs shrink and tilt toward the edges.
-- Each glyph gets red/blue split copies (chromatic aberration), a soft glow and a spring "pop" on change.
-- Only objects that changed (or are animating) are re-laid out; sway moves one root frame.
local TextService = game:GetService("TextService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Textures = require(Shared.Textures)

local Lens = {}
Lens.__index = Lens
Lens.FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
Lens.FONT_MED = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Medium)
Lens.version = 0

local TextObj = {}
TextObj.__index = TextObj
local LineObj = {}
LineObj.__index = LineObj

local RED = Color3.new(1, 0.12, 0.1)
local BLUE = Color3.new(0.12, 0.55, 1)

-- ── glyph advance widths (size 100), measured asynchronously and cached ──────
local widths = {}
local pending = {}

local function fkey(font)
	return font.Family .. "|" .. tostring(font.Weight)
end

local function boundsX(font, s)
	local p = Instance.new("GetTextBoundsParams")
	p.Text = s
	p.Font = font
	p.Size = 100
	p.Width = 100000
	return TextService:GetTextBoundsAsync(p).X
end

local function advance(font, ch)
	local key = fkey(font)
	local t = widths[key]
	if not t then
		t = {}
		widths[key] = t
	end
	local w = t[ch]
	if w then
		return w
	end
	local pk = key .. "\0" .. ch
	if not pending[pk] then
		pending[pk] = true
		task.spawn(function()
			local ok, v = pcall(function()
				if ch == " " then
					return boundsX(font, "a a") - boundsX(font, "aa")
				end
				return boundsX(font, ch)
			end)
			t[ch] = (ok and type(v) == "number" and v > 0) and v or 40
			pending[pk] = nil
			Lens.version += 1
		end)
	end
	return ch == " " and 22 or 46
end

function Lens.prewarm(font, chars)
	for _, cp in utf8.codes(chars) do
		advance(font, utf8.char(cp))
	end
end

-- ── lens ───────────────────────────────────────────────────────────────────────
function Lens.new(gui, opts)
	opts = opts or {}
	local self = setmetatable({}, Lens)
	self.gui = gui
	self.k = opts.k or 0.11
	self.caScale = opts.ca or 1
	self.warpOn = true
	self.scale = 1
	self.objs = {}
	self.W, self.H, self.unit = 1920, 1080, 1
	local root = Instance.new("Frame")
	root.Name = "LensRoot"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	self.root = root
	self:resize()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:resize()
	end)
	return self
end

function Lens:resize()
	local s = self.gui.AbsoluteSize
	if s.X > 0 and s.Y > 0 then
		self.W, self.H = s.X, s.Y
	end
	-- sizes are authored at 1080p; smaller screens (laptops, Studio, phones) shrink less than linearly so the
	-- numerals stay readable, while everything stays in the margins
	self.unit = math.max((self.H / 1080) ^ 0.6, 0.5) * self.scale
	for _, o in self.objs do
		o.dirty = true
	end
end

function Lens:setOptions(warpOn, caOn, scale)
	self.warpOn = warpOn ~= false
	self.caScale = caOn == false and 0 or 1
	self.scale = scale or 1
	self:resize()
end

-- barrel mapping in pixel space -> X, Y, uniform glyph scale, glyph rotation (deg), nx, ny.
-- Normalised by the half-diagonal so r <= 1 on any aspect ratio; with k < 1/3 the map stays invertible.
function Lens:warp(x, y)
	local cx, cy = self.W * 0.5, self.H * 0.5
	local R = math.sqrt(cx * cx + cy * cy)
	local nx, ny = (x - cx) / R, (y - cy) / R
	local k = self.warpOn and self.k or 0
	local r2 = nx * nx + ny * ny
	local f = 1 - k * r2
	local dXdx = f - 2 * k * nx * nx
	local dYdx = -2 * k * nx * ny
	return cx + nx * f * R, cy + ny * f * R, 1 - k * r2 * 1.1, math.deg(math.atan2(dYdx, dXdx)), nx, ny
end

function Lens:unwarp(X, Y)
	local cx, cy = self.W * 0.5, self.H * 0.5
	local R = math.sqrt(cx * cx + cy * cy)
	local dx, dy = (X - cx) / R, (Y - cy) / R
	local k = self.warpOn and self.k or 0
	local rd = math.sqrt(dx * dx + dy * dy)
	if rd < 1e-5 or k == 0 then
		return X, Y
	end
	local ru = rd
	for _ = 1, 10 do
		ru = rd / math.max(0.5, 1 - k * ru * ru)
	end
	local m = ru / rd
	return cx + dx * m * R, cy + dy * m * R
end

function Lens:step(dt)
	for _, o in self.objs do
		o:_step(dt)
	end
end

-- ── text object ────────────────────────────────────────────────────────────────
-- o = { at = Vector2(u, v) (where the anchor should land on screen), align = 0|0.5|1, size = px @1080p,
--       font, color, ca = 0..1, glow = transparency or nil, alpha, tracking, z }
function Lens:text(o)
	local obj = setmetatable({
		lens = self, at = o.at or Vector2.new(0.5, 0.5), align = o.align or 0, size = o.size or 32,
		font = o.font or Lens.FONT, color = o.color or Color3.new(1, 1, 1), ca = o.ca == nil and 1 or o.ca,
		glow = o.glow, alpha = o.alpha or 0, tracking = o.tracking or 0.03, segs = {}, sig = "",
		tPool = {}, iPool = {}, pz = 0, popV = 0, shakeT = 0, shakeA = 0, ver = -1, dirty = true, visible = true,
	}, TextObj)
	local f = Instance.new("Frame")
	f.Name = o.name or "LensText"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = o.z or 1
	f.Parent = self.root
	obj.frame = f
	if obj.glow then
		local g = Instance.new("ImageLabel")
		g.Name = "Glow"
		g.BackgroundTransparency = 1
		g.Image = Textures.GLOW
		g.ImageTransparency = obj.glow
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.ZIndex = 0
		g.Parent = f
		obj.glowImg = g
	end
	table.insert(self.objs, obj)
	if o.text then
		obj:set(o.text)
	end
	return obj
end

function Lens:icon(o)
	local obj = self:text(o)
	obj:set({ { icon = o.index or 0, color = o.color } })
	return obj
end

-- value: string, or array of segments { t = string | icon = index, size, color, font, alpha, top = bool }
function TextObj:set(value)
	local segs = type(value) == "table" and value or { { t = tostring(value) } }
	local parts = {}
	for _, s in segs do
		local c = s.color or self.color
		parts[#parts + 1] = (s.t or ("#" .. tostring(s.icon))) .. "|" .. tostring(s.size or 0) .. "|" .. c:ToHex() .. "|" .. tostring(s.alpha or "") .. (s.top and "^" or "")
	end
	local sig = table.concat(parts, "~")
	if sig == self.sig then
		return false
	end
	self.sig = sig
	self.segs = segs
	self.dirty = true
	return true
end

function TextObj:setAt(u, v)
	if self.at.X ~= u or self.at.Y ~= v then
		self.at = Vector2.new(u, v)
		self.dirty = true
	end
end

function TextObj:setAlpha(a)
	if a ~= self.alpha then
		self.alpha = a
		self.dirty = true
	end
end

function TextObj:show(on)
	on = on and true or false
	if on ~= self.visible then
		self.visible = on
		self.frame.Visible = on
		if on then
			self.dirty = true
		end
	end
end

function TextObj:pop(amount)
	self.pz = amount or 0.3
	self.popV = 0
end

function TextObj:shake(amount, duration)
	self.shakeA = amount or 3
	self.shakeT = duration or 0.25
end

function TextObj:destroy()
	self.frame:Destroy()
	local list = self.lens.objs
	local i = table.find(list, self)
	if i then
		table.remove(list, i)
	end
end

local function newGlyph(class, parent, ca)
	local function mk(z)
		local l = Instance.new(class)
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.ZIndex = z
		if class == "TextLabel" then
			l.TextXAlignment = Enum.TextXAlignment.Center
			l.TextYAlignment = Enum.TextYAlignment.Center
		else
			l.Image = Textures.ICONS
			l.ScaleType = Enum.ScaleType.Fit
		end
		l.Parent = parent
		return l
	end
	local g = { main = mk(3) }
	if ca then
		g.r = mk(1)
		g.b = mk(2)
		if class == "TextLabel" then
			g.r.TextColor3 = RED
			g.b.TextColor3 = BLUE
		else
			g.r.ImageColor3 = RED
			g.b.ImageColor3 = BLUE
		end
	end
	return g
end

local function hideGlyph(g)
	g.main.Visible = false
	if g.r then
		g.r.Visible = false
		g.b.Visible = false
	end
end

function TextObj:layout()
	local L = self.lens
	local unit = L.unit
	self.ver = Lens.version
	self.dirty = false
	-- 1) glyph list in unwarped space, x along the line, relative to line start
	local list, x, maxSize = {}, 0, 0
	for _, s in self.segs do
		maxSize = math.max(maxSize, s.size or self.size)
	end
	for _, s in self.segs do
		local size = (s.size or self.size) * unit
		local color = s.color or self.color
		local yoff = s.top and -(maxSize * unit - size) * 0.36 or 0
		local alpha = s.alpha or self.alpha
		if s.icon then
			local w = size * 0.86
			list[#list + 1] = { icon = s.icon, x = x + w * 0.5, y = yoff, w = w, size = size * 0.86, color = color, alpha = alpha }
			x += w + size * 0.14
		elseif s.t then
			local font = s.font or self.font
			for _, cp in utf8.codes(s.t) do
				local ch = utf8.char(cp)
				local adv = advance(font, ch) * size / 100
				list[#list + 1] = { ch = ch, x = x + adv * 0.5, y = yoff, w = adv, size = size, color = color, alpha = alpha, font = font }
				x += adv + self.tracking * size
			end
		end
	end
	local total = x
	-- 2) anchor: invert the lens so the anchor lands where requested
	local ax, ay = L:unwarp(self.at.X * L.W, self.at.Y * L.H)
	local popS = 1 + self.pz
	local startX = -self.align * total
	local caPx = self.ca * L.caScale * unit * 1.6
	local ti, ii = 0, 0
	for _, g in list do
		local ux = ax + (startX + g.x) * popS
		local uy = ay + g.y * popS
		local X, Y, s, rot, nx, ny = L:warp(ux, uy)
		local sz = g.size * s * popS
		local glyph
		if g.icon then
			ii += 1
			glyph = self.iPool[ii]
			if not glyph then
				glyph = newGlyph("ImageLabel", self.frame, self.ca > 0)
				self.iPool[ii] = glyph
			end
			local off, size = Textures.rect(g.icon)
			for _, l in { glyph.main, glyph.r, glyph.b } do
				l.ImageRectOffset = off
				l.ImageRectSize = size
				l.Size = UDim2.fromOffset(sz, sz)
				l.Rotation = rot
			end
			glyph.main.ImageColor3 = g.color
			glyph.main.ImageTransparency = g.alpha
			if glyph.r then
				glyph.r.ImageTransparency = 0.45 + g.alpha * 0.55
				glyph.b.ImageTransparency = 0.45 + g.alpha * 0.55
			end
		else
			ti += 1
			glyph = self.tPool[ti]
			if not glyph then
				glyph = newGlyph("TextLabel", self.frame, self.ca > 0)
				self.tPool[ti] = glyph
			end
			local tsize = math.clamp(math.floor(sz + 0.5), 1, 100)
			local box = UDim2.fromOffset(g.w * s * popS * 1.7 + 6, sz * 1.5)
			for _, l in { glyph.main, glyph.r, glyph.b } do
				l.Text = g.ch
				l.FontFace = g.font
				l.TextSize = tsize
				l.Size = box
				l.Rotation = rot
			end
			glyph.main.TextColor3 = g.color
			glyph.main.TextTransparency = g.alpha
			if glyph.r then
				glyph.r.TextTransparency = 0.42 + g.alpha * 0.58
				glyph.b.TextTransparency = 0.42 + g.alpha * 0.58
			end
		end
		glyph.main.Position = UDim2.fromOffset(X, Y)
		glyph.main.Visible = true
		if glyph.r then
			local r = math.sqrt(nx * nx + ny * ny)
			local dx, dy = 1, 0
			if r > 0.02 then
				dx, dy = nx / r, ny / r
			end
			local m = caPx * (0.7 + r * 0.9)
			glyph.r.Position = UDim2.fromOffset(X + dx * m, Y + dy * m)
			glyph.b.Position = UDim2.fromOffset(X - dx * m, Y - dy * m)
			glyph.r.Visible = caPx > 0
			glyph.b.Visible = caPx > 0
		end
	end
	for i = ti + 1, #self.tPool do
		hideGlyph(self.tPool[i])
	end
	for i = ii + 1, #self.iPool do
		hideGlyph(self.iPool[i])
	end
	if self.glowImg then
		local gx, gy, s, rot = L:warp(ax + (startX + total * 0.5) * popS, ay)
		self.glowImg.Position = UDim2.fromOffset(gx, gy)
		self.glowImg.Size = UDim2.fromOffset((total * 1.25 + maxSize * unit) * s * popS, maxSize * unit * 2.1 * s * popS)
		self.glowImg.Rotation = rot
		local c = (self.segs[1] and self.segs[1].color) or self.color
		self.glowImg.ImageColor3 = c
		self.glowImg.ImageTransparency = self.glow + (1 - self.glow) * self.alpha
		self.glowImg.Visible = #list > 0
	end
	self.width = total
end

function TextObj:_step(dt)
	if not self.visible then
		return
	end
	if self.pz ~= 0 or self.popV ~= 0 then
		local a = -280 * self.pz - 16 * self.popV
		self.popV += a * dt
		self.pz += self.popV * dt
		if math.abs(self.pz) < 0.002 and math.abs(self.popV) < 0.02 then
			self.pz, self.popV = 0, 0
		end
		self.dirty = true
	end
	if self.dirty or self.ver ~= Lens.version then
		self:layout()
	end
	if self.shakeT > 0 then
		self.shakeT -= dt
		local a = self.shakeT > 0 and self.shakeA * self.lens.unit or 0
		self.frame.Position = UDim2.fromOffset((math.random() * 2 - 1) * a, (math.random() * 2 - 1) * a)
	end
end

-- ── lines (camcorder brackets, separators): endpoints warped, long lines split into segments ──
function Lens:line(o)
	local obj = setmetatable({ lens = self, a = o.a, b = o.b, thick = o.thick or 2, color = o.color or Color3.new(1, 1, 1), alpha = o.alpha or 0, n = o.segments or 4, parts = {}, dirty = true, visible = true, ver = -1 }, LineObj)
	local f = Instance.new("Frame")
	f.Name = o.name or "LensLine"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = o.z or 1
	f.Parent = self.root
	obj.frame = f
	for i = 1, obj.n do
		local p = Instance.new("Frame")
		p.BorderSizePixel = 0
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Parent = f
		obj.parts[i] = p
	end
	table.insert(self.objs, obj)
	return obj
end

function LineObj:show(on)
	self.visible = on and true or false
	self.frame.Visible = self.visible
	self.dirty = true
end

function LineObj:setColor(c, alpha)
	self.color = c
	self.alpha = alpha or self.alpha
	self.dirty = true
end

function LineObj:_step()
	if not self.visible or not self.dirty then
		return
	end
	self.dirty = false
	local L = self.lens
	local ax, ay = L:unwarp(self.a.X * L.W, self.a.Y * L.H)
	local bx, by = L:unwarp(self.b.X * L.W, self.b.Y * L.H)
	local prevX, prevY = L:warp(ax, ay)
	for i = 1, self.n do
		local t = i / self.n
		local X, Y = L:warp(ax + (bx - ax) * t, ay + (by - ay) * t)
		local p = self.parts[i]
		local dx, dy = X - prevX, Y - prevY
		local len = math.sqrt(dx * dx + dy * dy)
		p.Position = UDim2.fromOffset((X + prevX) * 0.5, (Y + prevY) * 0.5)
		p.Size = UDim2.fromOffset(len + 1, math.max(1, self.thick * L.unit))
		p.Rotation = math.deg(math.atan2(dy, dx))
		p.BackgroundColor3 = self.color
		p.BackgroundTransparency = self.alpha
		prevX, prevY = X, Y
	end
end

return Lens
