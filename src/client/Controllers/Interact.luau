--!nonstrict
-- Custom-styled ProximityPrompts: our own prompt UI (device-aware key label, tappable on touch).
-- Terminal prompts (attribute Screen) open local screens; loot prompts are handled by the server.
local PPS = game:GetService("ProximityPromptService")
local Items = require(game:GetService("ReplicatedStorage"):WaitForChild("ZR").Items)

local Interact = { current = nil }
local ctx, K
local gui, btn

-- loose items carry their id: show the name only once this player has examined that kind of item (Tarkov)
local function objectText(p)
	local id = p:GetAttribute("ItemId")
	if id then
		local d = ctx.State.data
		if not ((d and d.known and d.known[id]) or Items.knownByDefault(id)) then
			return "UNKNOWN ITEM"
		end
	end
	return string.upper(p.ObjectText)
end

local function render()
	local p = Interact.current
	btn.Visible = p ~= nil and not ctx.Input.isMenu()
	if p then
		local key = ctx.Input.label("Interact")
		btn.Text = string.format("[%s]  %s  ·  %s", key, string.upper(p.ActionText), objectText(p))
		local w = math.max(260, #btn.Text * 10 + 32)
		btn.Size = UDim2.fromOffset(w, 42)
	end
end

function Interact.setEnabled(on)
	PPS.Enabled = on
	render()
end

function Interact.init(c)
	ctx = c
	K = c.UiKit
	gui = K.screen("ZR_Prompt", 7)
	btn = K.button(gui, "", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -196), Size = UDim2.fromOffset(260, 34),
		BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.25, TextSize = 18, Visible = false, Selectable = false,
	})
	btn.Activated:Connect(function()
		local p = Interact.current
		if p then
			p:InputHoldBegin()
			task.delay(0.05, function()
				p:InputHoldEnd()
			end)
		end
	end)
	-- the server rewrites prompt text (doors: Unlock -> Close -> Open), so follow the shown prompt's text
	local watch = {}
	local function unwatch()
		for _, cn in watch do
			cn:Disconnect()
		end
		table.clear(watch)
	end
	PPS.PromptShown:Connect(function(prompt)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			unwatch()
			Interact.current = prompt
			for _, prop in { "ActionText", "ObjectText" } do
				table.insert(watch, prompt:GetPropertyChangedSignal(prop):Connect(function()
					if Interact.current == prompt then
						render()
					end
				end))
			end
			render()
		end
	end)
	PPS.PromptHidden:Connect(function(prompt)
		if prompt == Interact.current then
			unwatch()
			Interact.current = nil
			render()
		end
	end)
	PPS.PromptTriggered:Connect(function(prompt)
		local screen = prompt:GetAttribute("Screen")
		if type(screen) ~= "string" then
			return
		end
		-- Relay 7 stations (docs/maps/RELAY7_LOBBY.md): "kind" or "kind:arg"
		local kind, arg = string.match(screen, "^([^:]+):?(.*)$")
		arg = (arg ~= "" and arg) or nil
		if kind == "stash" or kind == "mail" then
			c.Inventory.show("stash")
		elseif kind == "deploy" or kind == "insurance" or kind == "van" or kind == "scav" then
			c.Screens.deploy()
		elseif kind == "traders" or kind == "trader" or kind == "tasks" then
			c.Trade.traders(arg)
		elseif kind == "hideout" then
			c.Trade.hideout()
		elseif kind == "modding" then
			local d = c.State.data
			local g = d and d.slots and (d.slots.primary or d.slots.secondary or d.slots.holster)
			if g and c.Modding then
				c.Modding.open(g)
			else
				c.Inventory.show("stash")
			end
		elseif kind == "mirror" and c.Lobby and c.Lobby.mirror then
			c.Lobby.mirror()
		end
	end)
	c.Input.deviceChanged:Connect(render)
end

return Interact
