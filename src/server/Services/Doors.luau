--!nonstrict
-- Doors (M9, M10): hinged doors in the raid world. Locked doors open with the right key or keycard from the
-- raid inventory (limited uses, Tarkov-style); once unlocked a door stays unlocked for the rest of the raid.
-- Every raid starts with doors closed and locked (some ordinary doors are left ajar). AI open unlocked doors on
-- their way (AI.luau); pathfinding treats unlocked doors as passable and locked ones as walls.
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local Inv = require(script.Parent.Inv)

local Doors = {}
local ctx
local LED_LOCKED, LED_OPEN = Color3.fromHex("C24A35"), Color3.fromHex("6CC27A")

local function keyName(d)
	local def = d.key and Items.defs[d.key]
	return def and string.upper(def.name) or "A KEY"
end

local function refresh(d)
	if d.modifier then
		d.modifier.PassThrough = not d.locked
	end
	if d.led then
		d.led.Color = d.locked and LED_LOCKED or LED_OPEN
	end
	local pp = d.prompt
	if not pp then
		return
	end
	if d.locked then
		pp.ActionText = d.card and "Swipe card" or "Unlock"
		pp.ObjectText = d.label .. "  ·  " .. keyName(d)
	else
		pp.ActionText = d.open and "Close" or "Open"
		pp.ObjectText = d.label
	end
end

local function set(d, open, instant)
	d.open = open
	d.changedAt = os.clock()
	local hinge = d.cf * CFrame.new(-d.size.X / 2, 0, 0)
	local target = open and (hinge * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(d.size.X / 2, 0, 0)) or d.cf
	if instant then
		d.part.CFrame = target
	else
		TweenService:Create(d.part, TweenInfo.new(d.card and 1.1 or 0.55, Enum.EasingStyle.Quad), { CFrame = target }):Play()
		ctx.Remotes.fx("sfx", { n = open and "door_open" or "door_close", p = d.cf.Position })
	end
	refresh(d)
end

-- the key (or keycard) for this door anywhere in the raid inventory
local function findKey(s, d)
	for g, it in s.inv.items do
		if it.id == d.key then
			return g, it
		end
	end
	return nil
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
		local kg, kit = findKey(s, d)
		if not kg then
			ctx.Remotes.fx("sfx", { n = "door_locked", p = d.cf.Position, v = 0.8 })
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
		ctx.Remotes.fx("sfx", { n = d.card and "keycard" or "key_unlock", p = d.cf.Position, v = 0.9 })
		ctx.Remotes.note(player, "toast", { text = "UNLOCKED  ·  " .. string.upper(d.label), tone = "good" })
		ctx.Raid.push(player)
		task.delay(d.card and 0.5 or 0.25, function()
			set(d, true)
		end)
		return
	end
	set(d, not d.open)
end

-- AI: open a closed, unlocked door they are walking through (returns true if it started opening)
function Doors.aiOpen(d)
	if d.locked or d.open or (os.clock() - (d.changedAt or 0)) < 0.8 then
		return false
	end
	set(d, true)
	return true
end

-- closed doors within r studs of pos (AI uses this while moving)
function Doors.near(pos, r)
	local out = {}
	for _, d in ctx.World.doors do
		if d.part and not d.open and (d.cf.Position - pos).Magnitude <= r then
			table.insert(out, d)
		end
	end
	return out
end

-- raid start: every door closed and locked again; some ordinary doors are left ajar
function Doors.reset()
	for _, d in ctx.World.doors do
		d.locked = d.key ~= nil
		if d.part then
			set(d, (not d.locked) and math.random() < (d.openChance or 0), true)
		end
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
