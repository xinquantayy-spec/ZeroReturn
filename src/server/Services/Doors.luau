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

-- M13 switches (the Meridian Mall generator): hold the prompt to start a change that takes `delay` seconds and
-- lasts for the rest of the raid (lights, the exfils that need power). Every raid starts with them off.
local function useSwitch(player, sw)
	if sw.on or sw.pending then
		return
	end
	if not ctx.Remotes.allow(player, "switch", 2, 3) then
		return
	end
	local s = ctx.Raid.session(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not s or s.done or not root or (root.Position - sw.part.Position).Magnitude > 12 then
		return
	end
	sw.pending = true
	if sw.prompt then
		sw.prompt.Enabled = false
	end
	ctx.Remotes.note(player, "toast", { text = sw.startText or "STARTING", tone = "good" })
	ctx.Remotes.fx("sfx", { n = "metal_creak", p = sw.part.Position, v = 1 })
	local raid = ctx.Raid.world.resets
	task.delay(sw.delay or 6, function()
		if ctx.Raid.world.resets ~= raid or not sw.pending then
			return -- a new raid began meanwhile
		end
		sw.pending = nil
		sw.on = true
		if sw.onChange then
			local ok, err = pcall(sw.onChange, true)
			if not ok then
				warn("[ZR] switch", sw.id, err)
			end
		end
		ctx.Remotes.fx("sfx", { n = "keycard", p = sw.part.Position, v = 1 })
		-- exits that need power read it from the raid info: send everyone in the raid the new state
		for p, rs in ctx.Raid.sessions() do
			if not rs.done then
				ctx.Remotes.note(p, "raid", ctx.Raid.raidInfo(rs))
			end
		end
		if player.Parent then
			ctx.Remotes.note(player, "toast", { text = sw.doneText or "POWER ON", tone = "good" })
		end
	end)
end

function Doors.resetSwitches()
	for _, sw in ctx.World.switches do
		sw.on, sw.pending = false, nil
		if sw.prompt then
			sw.prompt.Enabled = true
		end
		if sw.onChange then
			local ok, err = pcall(sw.onChange, false)
			if not ok then
				warn("[ZR] switch", sw.id, err)
			end
		end
	end
end

-- raid start: every door closed and locked again; some ordinary doors are left ajar; switches off
function Doors.reset()
	for _, d in ctx.World.doors do
		d.locked = d.key ~= nil
		if d.part then
			set(d, (not d.locked) and math.random() < (d.openChance or 0), true)
		end
	end
	Doors.resetSwitches()
end

-- test hook: flip a switch now (Dev "switch")
function Doors.setSwitch(id, on)
	local sw = ctx.World.switches[id]
	if not sw then
		return false
	end
	sw.pending = nil
	sw.on = on and true or false
	if sw.prompt then
		sw.prompt.Enabled = not sw.on
	end
	if sw.onChange then
		pcall(sw.onChange, sw.on)
	end
	return true
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
	for _, sw in c.World.switches do
		sw.on = false
		if sw.prompt then
			sw.prompt.Triggered:Connect(function(player)
				local ok, err = pcall(useSwitch, player, sw)
				if not ok then
					warn("[ZR] switch", err)
				end
			end)
		end
	end
end

return Doors
