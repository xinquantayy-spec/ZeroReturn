--!nonstrict
-- Decision ui-5a: the FIRST RAID on the client (shared/TutorialData.luau has the rules, Services/Tutorial.luau runs it).
-- Three things: the offer (a player who has never raided is asked once per visit: START, SKIP or LATER), the objective
-- line at the top of the screen while the run lasts, and the control signs of the course, written for the device in
-- use (Tarkov 1.0's tutorial has control signs on its walls; ours name the keyboard key, the gamepad button or the touch
-- control). The signs are parts with the attribute ZR_TutSign (a comma list of Input actions) built by Maps/Tutorial.
local Tutorial = {}

local Players = game:GetService("Players")

local ctx, K
local gui, line
local current -- the step note being shown

-- what each action does, in the sign's words
local WORDS = {
	Interact = "SEARCH", Vault = "VAULT", Inventory = "INVENTORY", Crouch = "CROUCH", Sprint = "SPRINT", Primary = "PRIMARY WEAPON",
	Reload = "RELOAD", MagCheck = "CHECK MAGAZINE", Aim = "AIM", Fire = "FIRE", LeanLeft = "LEAN LEFT", LeanRight = "LEAN RIGHT",
	Heal = "USE MEDS", Extracts = "EXITS LIST",
}

local function keyFor(action)
	local Input = ctx.Input
	local dev = Input.device and Input.device() or "KBM"
	if action == "Vault" then -- Space: Roblox's jump, which Movement turns into a vault at cover
		return dev == "Gamepad" and "A" or (dev == "Touch" and "JUMP" or "SPACE")
	end
	if action == "Interact" then
		if dev == "Gamepad" then
			return "X"
		elseif dev == "Touch" then
			return "TAP THE PROMPT"
		end
		return "F"
	end
	local ok, l = pcall(Input.label, action)
	return (ok and l and l ~= "-") and l or "?"
end

function Tutorial.signText(actions)
	local out = {}
	for a in string.gmatch(actions or "", "[^,]+") do
		table.insert(out, string.format("[%s]  %s", keyFor(a), WORDS[a] or string.upper(a)))
	end
	return table.concat(out, "\n")
end

local function fill(part)
	local acts = part:GetAttribute("ZR_TutSign")
	local sg = part:FindFirstChildOfClass("SurfaceGui")
	local tl = sg and sg:FindFirstChildOfClass("TextLabel")
	if not acts or not tl then
		return
	end
	local title = part:GetAttribute("ZR_TutTitle") or ""
	tl.Text = title .. "\n" .. Tutorial.signText(acts)
end

local signs = {}
local function watchSigns()
	local function consider(d)
		if d:IsA("BasePart") and d:GetAttribute("ZR_TutSign") then
			signs[d] = true
			fill(d)
		end
	end
	for _, d in workspace:GetDescendants() do
		consider(d)
	end
	workspace.DescendantAdded:Connect(consider)
	workspace.DescendantRemoving:Connect(function(d)
		signs[d] = nil
	end)
	-- the device can change at any time (a gamepad picked up): rewrite the signs now and then
	task.spawn(function()
		local last
		while true do
			task.wait(1.5)
			local dev = ctx.Input.device and ctx.Input.device() or "KBM"
			if dev ~= last then
				last = dev
				for p in signs do
					if p.Parent then
						fill(p)
					end
				end
			end
		end
	end)
end

local function showLine(d)
	current = d
	if not line then
		return
	end
	if d and d.text then
		line.Visible = true
		line.Text = string.format("<b>FIRST RAID  %d/%d</b>   %s", d.n or 0, d.of or 0, string.upper(d.text))
	else
		line.Visible = false
	end
end

-- the offer goes in the shared modal window (Screens.ask): the mouse is freed, the prompts are off, a gamepad lands on START
function Tutorial.showOffer()
	ctx.Screens.ask("FIRST RAID", "A short guided raid that teaches the basics: looting, your weapon, first aid and getting out. About 20 minutes. Nothing from your stash goes in, and what you carry out is yours.", {
		{ "START", "ochre", function()
			local r = ctx.State.req("tut", { op = "start" })
			if not r.ok then
				local why = { IN_USE = "ANOTHER PLAYER IS ON THE COURSE, TRY AGAIN IN A FEW MINUTES", NOT_IN_BUNKER = "START IT FROM THE BUNKER" }
				ctx.State.toast("FIRST RAID: " .. (why[r.err] or tostring(r.err or r.code or "NOT AVAILABLE")), "warn")
			end
		end },
		{ "LATER" },
		{ "SKIP", nil, function()
			ctx.State.req("tut", { op = "skip" })
		end },
	})
end

function Tutorial.init(c)
	ctx = c
	K = c.UiKit
	gui = K.screen("ZR_Tutorial", 6)
	line = K.label(gui, "", 15, {
		Name = "Objective", Size = UDim2.new(0, 720, 0, 28), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64),
		BackgroundTransparency = 0.25, BackgroundColor3 = K.C.bg, TextXAlignment = Enum.TextXAlignment.Center, Visible = false,
		TextColor3 = K.C.green,
	})
	ctx.State.on("tut", function(d)
		if type(d) ~= "table" then
			return
		end
		if d.done then
			showLine(nil)
			ctx.State.toast("FIRST RAID COMPLETE: YOUR LOOT IS IN THE STASH", "good")
		elseif d.ended then
			showLine(nil)
		elseif d.step then
			if ctx.Screens.title == "FIRST RAID" and ctx.Screens.modal then
				ctx.Screens.close() -- started some other way while the offer was up
			end
			if d.n == 1 then
				-- the first step waits for the insertion card to clear the top of the screen
				task.delay(5, function()
					if current == d then
						showLine(d)
					end
				end)
				current = d
			else
				showLine(d)
			end
		end
	end)
	watchSigns()
	-- ask once the profile is there: is the first raid on offer, or running (a rejoin)?
	task.spawn(function()
		task.wait(6)
		local r = ctx.State.req("tut", { op = "state" })
		local d = r and r.data
		if type(d) == "table" then
			if d.step then
				showLine({ text = d.text, n = 0, of = 0 })
			elseif d.offer then
				-- at a free moment: out of a raid, with no window open (it never replaces one)
				for _ = 1, 180 do
					if not ctx.State.inRaid() and not ctx.Screens.modal and not ctx.Inventory.open then
						Tutorial.showOffer()
						break
					end
					task.wait(1)
				end
			end
		end
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		if current and not ctx.State.inRaid() then
			showLine(nil)
		end
	end)
end

return Tutorial
