--!nonstrict
-- Tarkov's menu bar (decision ui-6a). Out of a raid every screen opens from a bar at the foot of the screen, as EFT's
-- footer opens HIDEOUT, CHARACTER, TRADERS and FLEA MARKET, with the handbook and the messenger (its unread count) beside
-- them; DEPLOY stands for EFT's ESCAPE FROM TARKOV button. The bar shows under every bunker screen; walking about the
-- bunker, M opens it (gamepad: tap D-down; touch: the menu button). Each screen also has a PC key of its own, ours
-- (EFT gives these no keys): H hideout, Tab character, Y traders, U flea market, K handbook, J messenger. The owner's
-- rule: every Tarkov screen still opens from its key. The stations in the bunker open the same screens.
local MB = { H = 40, forced = false }
local ctx, K
local gui, bar, closeBtn
local buttons = {}

MB.ITEMS = {
	{ id = "hideout", label = "HIDEOUT", action = "ScreenHideout" },
	{ id = "character", label = "CHARACTER", action = "Inventory" },
	{ id = "traders", label = "TRADERS", action = "ScreenTraders" },
	{ id = "flea", label = "FLEA MARKET", action = "ScreenFlea" },
	{ id = "handbook", label = "HANDBOOK", action = "ScreenHandbook" },
	{ id = "messenger", label = "MESSENGER", action = "ScreenMessenger" },
	{ id = "deploy", label = "DEPLOY", right = true },
}

local function inRaid()
	return ctx.State.inRaid()
end

-- which bar screen is open now (nil: none of them)
function MB.current()
	if ctx.Inventory.open then
		return "character"
	end
	local S = ctx.Screens
	if not S.modal then
		return nil
	end
	if S.kind == "deploy" then
		return "deploy"
	end
	if ctx.Trade.frame == S.modal then
		if ctx.Trade.open == "hideout" then
			return "hideout"
		end
		local tab = ctx.Trade.tab and ctx.Trade.tab()
		if tab == "flea" or tab == "handbook" or tab == "messenger" then
			return tab
		end
		return "traders"
	end
	return nil
end

-- the height the open screens leave free at the foot for the bar
function MB.reserve()
	if not ctx or inRaid() then
		return 0
	end
	return MB.H
end

function MB.go(id)
	if inRaid() then
		return
	end
	MB.forced = false
	if id == "hideout" then
		ctx.Trade.hideout()
	elseif id == "character" then
		if ctx.Screens.modal then
			ctx.Screens.close()
		end
		ctx.Inventory.show()
	elseif id == "traders" then
		ctx.Trade.traders(ctx.Trade.lastTrader and ctx.Trade.lastTrader() or nil, "trade")
	elseif id == "flea" or id == "handbook" or id == "messenger" then
		ctx.Trade.traders(id)
	elseif id == "deploy" then
		ctx.Screens.deploy()
	end
	MB.refresh()
end

local function unread()
	local Menus = ctx.Menus
	local d = ctx.State.data
	local ok, n = pcall(function()
		return Menus and Menus.unread and d and Menus.unread(d) or 0
	end)
	return ok and n or 0
end

-- the input and prompts follow whether anything is open (a screen, the inventory or the bar itself)
local function settle()
	local open = MB.forced or ctx.Screens.modal ~= nil or ctx.Inventory.open == true
	ctx.Input.setMenu(open)
	ctx.Interact.setEnabled(not open)
end

local function build()
	gui = K.screen("ZR_MenuBar", 40)
	gui.Enabled = false
	bar = K.frame(K.root(gui), { Name = "Bar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, -16, 0, MB.H - 4), BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.05 })
	K.stroke(bar, K.C.line, 0.5)
	local left = K.frame(bar, { Name = "Left", BackgroundTransparency = 1, Size = UDim2.new(1, -190, 1, 0) }) -- clear of X and DEPLOY
	K.list(left, Enum.FillDirection.Horizontal, 4)
	K.pad(left, 3)
	for i, it in MB.ITEMS do
		local parent = left
		-- six buttons share the strip left of DEPLOY, so they fit a phone and a larger MENU TEXT SIZE
		local props = { LayoutOrder = i, Size = UDim2.new(1 / 6, -4, 1, 0), TextSize = 13, AutoButtonColor = true, TextTruncate = Enum.TextTruncate.AtEnd }
		if it.right then
			parent = bar
			props = { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -3, 0.5, 0), Size = UDim2.new(0, 140, 1, -6), TextSize = 14, BackgroundColor3 = K.C.ochre, TextColor3 = K.C.bg }
		end
		local b = K.button(parent, it.label, props, function()
			MB.go(it.id)
		end)
		buttons[it.id] = b
	end
	-- the bar opened while walking about closes again here (touch has no key for it)
	closeBtn = K.button(bar, "X", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -148, 0.5, 0), Size = UDim2.new(0, 36, 1, -6), Visible = false }, function()
		MB.forced = false
		settle()
		MB.refresh()
	end)
end

-- the labels: each screen's key on PC (none on a pad or touch), the messenger's unread count
local function labels()
	local dev = ctx.Input.device()
	local n = unread()
	-- a narrow bar (a phone, a large menu text size) leaves the keys out: a button under 150 wide fits only its name
	local narrow = (K.viewport(gui).X - 212) / 6 < 150
	for _, it in MB.ITEMS do
		local b = buttons[it.id]
		local key = (dev == "KBM" and it.action and ctx.Input.hints() and not narrow) and ctx.Input.pcLabel(it.action) or nil
		local text = it.label
		if it.id == "messenger" and n > 0 then
			text ..= "  (" .. n .. ")"
		end
		if key and key ~= "" then
			text = "[" .. key .. "]  " .. text
		end
		b.Text = text
	end
end

function MB.refresh()
	if not gui then
		return
	end
	local raid = inRaid()
	local cur = not raid and MB.current() or nil
	-- only under the bar's own screens, or opened on purpose (the raid report, settings and the rest keep the screen)
	local show = not raid and (cur ~= nil or MB.forced)
	gui.Enabled = show
	if closeBtn then
		closeBtn.Visible = MB.forced and cur == nil
	end
	if not show then
		return
	end
	labels()
	for _, it in MB.ITEMS do
		local b = buttons[it.id]
		local on = it.id == cur
		if not it.right then
			b.BackgroundColor3 = on and K.C.ochre or K.C.panel2
			b.TextColor3 = on and K.C.bg or K.C.text
		end
	end
end

function MB.toggle()
	if inRaid() then
		return
	end
	if MB.current() then
		-- a bar screen is open: the bar is already there, M closes the screen
		if ctx.Inventory.open then
			ctx.Inventory.close()
		else
			ctx.Screens.close()
		end
		MB.forced = false
	else
		MB.forced = not MB.forced
	end
	settle()
	MB.refresh()
	if MB.forced and ctx.Input.device() == "Gamepad" then
		K.focus(buttons.character)
	end
end

function MB.init(c)
	ctx = c
	K = c.UiKit
	build()
	c.Input.on("MenuBar", function(down)
		if down then
			MB.toggle()
		end
	end)
	for _, it in MB.ITEMS do
		if it.action and it.action ~= "Inventory" then
			c.Input.on(it.action, function(down)
				if down and not inRaid() then
					if MB.current() == it.id then
						ctx.Screens.close() -- the key again closes the screen it opened
						MB.refresh()
					else
						MB.go(it.id)
					end
				end
			end)
		end
	end
	c.Input.on("Back", function(down)
		if down and MB.forced and not ctx.Screens.modal and not ctx.Inventory.open then
			MB.forced = false
			settle()
			MB.refresh()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			pcall(MB.refresh)
		end
	end)
end

return MB
