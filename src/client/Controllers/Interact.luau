--!nonstrict
-- Custom-styled ProximityPrompts: our own prompt UI (device-aware key label, tappable on touch).
-- Terminal prompts (attribute Screen) open local screens; loot prompts are handled by the server.
local PPS = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Items = require(game:GetService("ReplicatedStorage"):WaitForChild("ZR").Items)

local Interact = { current = nil, locked = false }
local ctx, K
local gui, btn
local wanted = true -- what the menus last asked for (setEnabled), apart from the lock

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
	wanted = on
	PPS.Enabled = on and not Interact.locked
	render()
end

-- at a stationary gun the prompts stay off: F leaves the gun and must not also use a prompt
function Interact.lock(on)
	Interact.locked = on
	PPS.Enabled = wanted and not on
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
			-- a tap holds the prompt for its whole hold time (the car's fare, the mall's levers), so those work on a phone too
			task.delay(0.05 + (p.HoldDuration or 0), function()
				pcall(p.InputHoldEnd, p)
			end)
		end
	end)
	-- a held prompt (a car's fare, disarming a tripwire) fills a bar under the button while it is held
	local bar = Instance.new("Frame")
	bar.Name = "Hold"
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 0, 1, 0)
	bar.Size = UDim2.new(0, 0, 0, 3)
	bar.BackgroundColor3 = K.C.ochre
	bar.BorderSizePixel = 0
	bar.Parent = btn
	local holding, holdT0, holdDur = nil, 0, 1
	PPS.PromptButtonHoldBegan:Connect(function(prompt)
		if prompt.HoldDuration > 0 then
			holding, holdT0, holdDur = prompt, os.clock(), prompt.HoldDuration
		end
	end)
	PPS.PromptButtonHoldEnded:Connect(function(prompt)
		if prompt == holding then
			holding = nil
		end
	end)
	RunService.RenderStepped:Connect(function()
		if holding and holding == Interact.current then
			bar.Size = UDim2.new(math.clamp((os.clock() - holdT0) / holdDur, 0, 1), 0, 0, 3)
		elseif bar.Size.X.Scale ~= 0 then
			bar.Size = UDim2.new(0, 0, 0, 3)
		end
	end)
	-- tripwires (Tripwires.luau, Tarkov): a wire's disarm prompt shows only while you look at the wire from close by, and
	-- only the one that fits what you carry (a multitool makes it quicker; the server checks again)
	local function carries(id)
		local d = c.State.data
		for _, it in (d and d.items) or {} do
			if it.id == id then
				return true
			end
		end
		return false
	end
	local trapT = 0
	RunService.Heartbeat:Connect(function(dt)
		trapT += dt
		if trapT < 0.12 then
			return
		end
		trapT = 0
		local f = workspace:FindFirstChild("ZR_Traps")
		if not f then
			return
		end
		local cam = workspace.CurrentCamera
		local cf = cam and cam.CFrame
		for _, pp in f:GetDescendants() do
			if pp:IsA("ProximityPrompt") and pp:GetAttribute("Trap") then
				local want = false
				local anchor = pp.Parent
				if cf and anchor and anchor:IsA("BasePart") then
					local to = anchor.Position - cf.Position
					local dist = to.Magnitude
					if dist < 6 and dist > 0.01 and cf.LookVector:Dot(to / dist) > 0.9 then
						local need, unless = pp:GetAttribute("NeedsItem"), pp:GetAttribute("UnlessItem")
						want = (need == nil or carries(need)) and (unless == nil or not carries(unless))
					end
				end
				if pp.Enabled ~= want then
					pp.Enabled = want
				end
			end
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
		if kind == "mail" then
			c.Trade.traders("messenger") -- the pigeonholes: Tarkov's messenger (insurance returns, task rewards)
		elseif kind == "stash" then
			c.Inventory.show("stash")
		elseif kind == "van" and c.Lobby and c.Lobby.boardVan then
			c.Lobby.boardVan()
		elseif kind == "scav" and c.Lobby and c.Lobby.scavHatch then
			c.Lobby.scavHatch()
		elseif kind == "deploy" or kind == "insurance" or kind == "van" or kind == "scav" or kind == "squad" then
			c.Screens.deploy()
		elseif kind == "traders" or kind == "trader" or kind == "tasks" then
			c.Trade.traders(arg, kind == "tasks" and "tasks" or "trade")
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
