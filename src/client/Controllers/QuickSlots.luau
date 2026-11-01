--!nonstrict
-- Tarkov's quick slots (4 to 0, docs/design/EFT_PARITY.md section 4): with the inventory open, hover a med, food
-- or grenade in your pockets or rig and press a key to bind it; in a raid the key uses it (meds, food) or readies
-- it (grenades: hold, release to throw, like G). The bar along the bottom shows the bound items for a moment when a
-- key is pressed or a binding changes (Tarkov's auto-hide), and the inventory marks bound items with their key.
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)

local Quick = {}
local ctx, K, gui, bar
Quick.SLOTS = { "4", "5", "6", "7", "8", "9", "0" }
local KINDS = { med = true, food = true, grenade = true }
local showUntil = 0
local held = {} -- slot -> the grenade it readied (so the release throws it)

-- on you: in the pockets or the rig (Tarkov binds and uses quick slots only from there)
local function onYou(d, g)
	if not d or not d.grids or not g then
		return false
	end
	if d.grids.pockets and d.grids.pockets[g] then
		return true
	end
	local rig = d.slots and d.slots.rig
	return rig ~= nil and d.grids[rig] ~= nil and d.grids[rig][g] ~= nil
end

-- the quick slot an item is bound to, if any (the inventory shows it on the tile)
function Quick.slotOf(g)
	for slot, qg in ctx.Settings.data.quick or {} do
		if qg == g then
			return slot
		end
	end
	return nil
end

local function render()
	bar:ClearAllChildren()
	K.list(bar, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center)
	local d = ctx.State.data
	for i, slot in Quick.SLOTS do
		local g = ctx.Settings.data.quick[slot]
		local it = d and d.items and g and d.items[g]
		local live = it and onYou(d, g)
		local box = K.frame(bar, { Name = "Q" .. slot, LayoutOrder = i, Size = UDim2.fromOffset(46, 46), BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.25 })
		K.stroke(box, live and K.C.line or K.C.panel2, 0.4)
		if it then
			local pic = K.frame(box, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
			K.itemIcon(pic, it.id, 46, 46, false, false, 2)
			if not live then
				K.frame(box, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 4 })
			end
		end
		K.label(box, slot, 12, {
			Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(14, 14), FontFace = K.bold, ZIndex = 5, TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0.2, BackgroundColor3 = K.C.bg,
		})
	end
end

local function show(t)
	if (ctx.Settings.data.quickBar or 1) == 3 then
		return -- NEVER
	end
	showUntil = os.clock() + t
	render()
	bar.Visible = true
end
Quick.show = show

local function press(slot, down)
	local d = ctx.State.data
	if not d or not d.items then
		return
	end
	if ctx.Inventory.open then
		if not down then
			return
		end
		local h = ctx.Inventory.hovered and ctx.Inventory.hovered()
		if not h or h.ref ~= "me" then
			return
		end
		local it = d.items[h.g]
		local def = it and Items.defs[it.id]
		if def and KINDS[def.kind] and onYou(d, h.g) then
			ctx.Settings.setQuick(slot, h.g)
			ctx.Inventory.render()
			show(3)
		else
			ctx.State.toast("QUICK SLOTS TAKE MEDS, FOOD AND GRENADES IN YOUR POCKETS OR RIG", "warn")
		end
		return
	end
	if not down then
		if held[slot] then
			held[slot] = nil
			ctx.Grenade.release()
		end
		return
	end
	if ctx.Input.isMenu() or ctx.Input.isMounted() or not ctx.State.inRaid() then
		return
	end
	show(2.5)
	local g = ctx.Settings.data.quick[slot]
	local it = g and d.items[g]
	local def = it and Items.defs[it.id]
	if not def or not onYou(d, g) then
		ctx.State.toast("QUICK SLOT " .. slot .. " IS EMPTY", "warn")
		return
	end
	if def.kind == "grenade" then
		if ctx.Grenade.begin(g) then
			held[slot] = g
		end
	else
		ctx.State.req("inv", { op = "use", g = g })
	end
end

function Quick.init(c)
	ctx = c
	K = c.UiKit
	gui = K.screen("ZR_Quick", 8)
	bar = K.frame(gui, {
		Name = "Bar", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.fromOffset(#Quick.SLOTS * 50, 46), Visible = false,
	})
	for _, slot in Quick.SLOTS do
		c.Input.on("Quick" .. slot, function(down)
			press(slot, down)
		end)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		-- Tarkov's QUICK SLOTS setting: 1 auto-hide, 2 always (in a raid), 3 never
		local mode = c.Settings.data.quickBar or 1
		if mode == 2 and c.State.inRaid() and not c.Input.isMenu() then
			if not bar.Visible then
				render()
				bar.Visible = true
			end
		elseif bar.Visible and (mode == 3 or os.clock() > showUntil) then
			bar.Visible = false
		end
	end)
	c.State.changed:Connect(function()
		if bar.Visible then
			render()
		end
	end)
end

return Quick
