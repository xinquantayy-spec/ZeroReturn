--!nonstrict
-- Doors (M9): hinged doors in the raid world. Locked doors open with the right key from the raid inventory
-- (keys have limited uses, Tarkov-style); once unlocked a door stays unlocked for the rest of the raid.
-- Every raid starts with doors closed and locked.
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local Inv = require(script.Parent.Inv)

local Doors = {}
local ctx

local function keyName(d)
	local def = d.key and Items.defs[d.key]
	return def and string.upper(def.name) or "A KEY"
end

local function refresh(d)
	local pp = d.prompt
	if not pp then
		return
	end
	if d.locked then
		pp.ActionText = "Unlock"
		pp.ObjectText = d.label .. "  ·  " .. keyName(d)
	else
		pp.ActionText = d.open and "Close" or "Open"
		pp.ObjectText = d.label
	end
end

local function set(d, open)
	d.open = open
	local hinge = d.cf * CFrame.new(-d.size.X / 2, 0, 0)
	local target = open and (hinge * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(d.size.X / 2, 0, 0)) or d.cf
	TweenService:Create(d.part, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { CFrame = target }):Play()
	refresh(d)
	ctx.Remotes.fx("sfx", { n = open and "door_open" or "door_close", p = d.cf.Position })
end

local function use(player, d)
	if not ctx.Remotes.allow(player, "door", 2, 3) then
		return
	end
	local s = ctx.Raid.session(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not s or s.done or not root or (root.Position - d.cf.Position).Magnitude > 10 then
		return
	end
	if d.locked then
		local kg, kit = nil, nil
		for g, it in s.inv.items do
			if it.id == d.key then
				kg, kit = g, it
				break
			end
		end
		if not kg then
			ctx.Remotes.note(player, "toast", { text = "LOCKED  ·  REQUIRES " .. keyName(d), tone = "warn" })
			return
		end
		local def = Items.defs[kit.id]
		kit.uses = (kit.uses or (def.key and def.key.uses) or 1) - 1
		if kit.uses <= 0 then
			Inv.consume(s.inv, kg)
			ctx.Remotes.note(player, "toast", { text = keyName(d) .. " IS WORN OUT", tone = "warn" })
		end
		d.locked = false
		ctx.Remotes.note(player, "toast", { text = "UNLOCKED  ·  " .. string.upper(d.label), tone = "good" })
		ctx.Raid.push(player)
		set(d, true)
		return
	end
	set(d, not d.open)
end

-- raid start: every door closed and locked again
function Doors.reset()
	for _, d in ctx.World.doors do
		d.locked = d.key ~= nil
		d.open = false
		if d.part then
			d.part.CFrame = d.cf
		end
		refresh(d)
	end
end

function Doors.init(c)
	ctx = c
	for _, d in c.World.doors do
		if d.prompt then
			d.prompt.Triggered:Connect(function(player)
				local ok, err = pcall(use, player, d)
				if not ok then
					warn("[ZR] door", err)
				end
			end)
		end
		d.locked = d.key ~= nil
		d.open = false
		refresh(d)
	end
end

return Doors
