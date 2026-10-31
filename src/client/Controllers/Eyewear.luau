--!nonstrict
-- Eyewear and gas mask overlays (docs/design/EFT_PARITY.md section 6), client-only. Tarkov: glasses tint the picture a little
-- (their lens colour) and stop part of a stun charge's flash (blindness protection); a gas mask puts the rubber of the mask
-- round the view with slightly smoked lenses. What is worn is read from the inventory snapshot (the EYEWEAR and FACE COVER
-- slots), and every number comes from the item's `eye` record (Items.luau): lens colour, how strongly it tints, flash share.
-- Nothing here is shared with the other screen effects, so none of them can fight over an instance:
--   * the tint is its own ColorCorrectionEffect "ZR_Eyewear" (the grade "ZR_Cam" is Post's, "ZR_NightVision" is the goggles');
--   * the mask frame is its own ScreenGui "ZR_Eyewear" at DisplayOrder -3, under the goggles' tube mask and the face
--     shield's visor (both -2) and under the HUD. Both overlays step aside while goggles are down: the picture then comes from
--     the tubes, not through the lenses.
-- They are cheap (one grade pass, a few frames) and the grade and goggle effects are not quality-gated, so these are not
-- either: they stay on at POTATO exactly as those do. In raid only (the lobby is not a raid).
-- No breathing loop: the sound atlases hold no looped breath (only the one-shot breath_heavy / breath_release), see KNOWN_ISSUES.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)

local Eyewear = { eyes = nil, face = nil }
local ctx
local gui, mask, soft, nose, glint, cc
local WHITE = Color3.new(1, 1, 1)
local RUBBER = Color3.fromRGB(17, 22, 17)
local tint, bright = WHITE, 0 -- what the lenses do to the picture now (eased towards the target)
local target = { tint = WHITE, bright = 0, frame = false }

-- the item (def, its eye record) worn in an inventory slot, or nil
local function worn(slot)
	local d = ctx.State.data
	local g = d and d.slots and d.slots[slot]
	local it = g and d.items and d.items[g]
	local def = it and Items.defs[it.id]
	if def and def.eye then
		return def, def.eye
	end
	return nil, nil
end

-- the share of a stun charge's white-out the worn lenses stop (0..1); glasses and a mask stack
function Eyewear.flash()
	if not ctx.State.inRaid() then
		return 0
	end
	local _, e = worn("eyes")
	local _, f = worn("face")
	return 1 - (1 - (e and e.flash or 0)) * (1 - (f and f.flash or 0))
end

-- recompute the target from what is worn
local function refresh()
	local _, e = worn("eyes")
	local _, f = worn("face")
	Eyewear.eyes, Eyewear.face = e, f
	local t, b = WHITE, 0
	if ctx.State.inRaid() then
		for _, lens in { e or false, f or false } do
			if lens then
				-- a lens passes its colour in proportion to its shade; stacked lenses multiply
				local c = WHITE:Lerp(lens.tint, lens.shade)
				t = Color3.new(t.R * c.R, t.G * c.G, t.B * c.B)
				b -= 0.15 * lens.shade
			end
		end
	end
	target.tint, target.bright = t, b
	target.frame = ctx.State.inRaid() and f ~= nil
end

local function step(dt)
	local nv = ctx.NightVision
	local hidden = nv ~= nil and nv.dev ~= nil -- goggles down: the tubes show the picture, not the lenses
	local k = 1 - math.exp(-dt * 7)
	tint = tint:Lerp(target.tint, k)
	bright += (target.bright - bright) * k
	local off = (math.abs(tint.R - 1) + math.abs(tint.G - 1) + math.abs(tint.B - 1) < 0.006) and math.abs(bright) < 0.002
	cc.Enabled = not hidden and not off
	if cc.Enabled then
		cc.TintColor = tint
		cc.Brightness = bright
	end
	gui.Enabled = target.frame and not hidden
end

function Eyewear.init(c)
	ctx = c
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("ZR_Eyewear")
	if old then
		old:Destroy()
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "ZR_Eyewear"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -3 -- under the goggles' tube mask and the visor (-2) and the HUD
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	-- the visor opening of the mask: a rounded hole whose huge rubber stroke covers the rest of the screen (the tube trick
	-- of NightVision.luau), sized in screen fractions so it fits any aspect ratio, phones included
	mask = Instance.new("Frame")
	mask.Name = "Mask"
	mask.AnchorPoint = Vector2.new(0.5, 0.5)
	mask.Position = UDim2.fromScale(0.5, 0.5)
	mask.Size = UDim2.fromScale(0.97, 0.9)
	mask.BackgroundTransparency = 1
	mask.Parent = gui
	local mc = Instance.new("UICorner")
	mc.CornerRadius = UDim.new(0.2, 0)
	mc.Parent = mask
	local ms = Instance.new("UIStroke")
	ms.Color = RUBBER
	ms.Thickness = 2400
	ms.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ms.Parent = mask
	-- a softer inner lip so the rubber does not end in a hard line
	soft = Instance.new("Frame")
	soft.Name = "Lip"
	soft.AnchorPoint = Vector2.new(0.5, 0.5)
	soft.Position = UDim2.fromScale(0.5, 0.5)
	soft.Size = UDim2.fromScale(0.93, 0.84)
	soft.BackgroundTransparency = 1
	soft.Parent = gui
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0.2, 0)
	sc.Parent = soft
	local ss = Instance.new("UIStroke")
	ss.Color = RUBBER
	ss.Thickness = 60
	ss.Transparency = 0.7
	ss.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ss.Parent = soft
	-- the nose bridge between the two eye lenses
	nose = Instance.new("Frame")
	nose.Name = "Nose"
	nose.AnchorPoint = Vector2.new(0.5, 1)
	nose.Position = UDim2.fromScale(0.5, 0.96)
	nose.Size = UDim2.fromScale(0.05, 0.2)
	nose.BackgroundColor3 = RUBBER
	nose.BorderSizePixel = 0
	nose.Parent = gui
	local nc = Instance.new("UICorner")
	nc.CornerRadius = UDim.new(0.5, 0)
	nc.Parent = nose
	-- one faint streak of light across the glass
	glint = Instance.new("Frame")
	glint.Name = "Glint"
	glint.AnchorPoint = Vector2.new(0.5, 0.5)
	glint.Position = UDim2.fromScale(0.3, 0.4)
	glint.Size = UDim2.fromScale(0.03, 0.5)
	glint.Rotation = 24
	glint.BackgroundColor3 = WHITE
	glint.BackgroundTransparency = 0.94
	glint.BorderSizePixel = 0
	glint.Parent = gui
	gui.Parent = pg
	cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ZR_Eyewear"
	cc.Enabled = false
	cc.Parent = Lighting
	refresh()
	ctx.State.changed:Connect(refresh)
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok then
			warn("[ZR] eyewear:", err)
		end
	end)
end

return Eyewear
