--!nonstrict
-- Extraction zones: server checks position at 5 Hz; 6 s hold; leaving, dying or timer expiry cancels.
-- Tarkov extract rules: open, paid (MK on exit), key (carry the key), chance (open or closed for the whole
-- raid, unknown until you get there), scav-only and power (works once a switch such as a generator is on). PMCs get their side's list, scavs every extract.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)

local Extract = {}
local ctx

function Extract.init(c)
	ctx = c
end

function Extract.inside(e, p)
	local lp = e.cf:PointToObjectSpace(p)
	return math.abs(lp.X) <= e.size.X / 2 and math.abs(lp.Y) <= e.size.Y / 2 + 2 and math.abs(lp.Z) <= e.size.Z / 2
end

local function carries(h, id)
	for _, it in h.items do
		if it.id == id then
			return true
		end
	end
	return false
end

-- nil when the extract can be used right now, else (reason code, text for the player)
function Extract.blocked(player, s, e)
	local r = e.rule or {}
	if r.kind == "chance" and not ctx.Match.extractOpen[e.id] then
		return "CLOSED", "NOT AVAILABLE THIS RAID"
	elseif r.kind == "scav" and not s.scav then
		return "SCAV_ONLY", "SCAVS ONLY"
	elseif r.kind == "power" and not ctx.World.switchOn(r.switch) then
		return "POWER", r.needs or "NO POWER"
	elseif r.kind == "key" and r.key and not carries(s.inv, r.key) then
		local d = Items.defs[r.key]
		return "KEY", "REQUIRES " .. string.upper(d and d.name or r.key)
	elseif r.kind == "paid" then
		local prof = ctx.Profiles.get(player)
		if not prof or prof.money < (r.cost or 0) then
			return "MONEY", "REQUIRES " .. Util.commas(r.cost or 0) .. " " .. Config.CURRENCY
		end
	end
	return nil
end

local function complete(player, s, e)
	local r = e.rule or {}
	if r.kind == "paid" then
		local prof = ctx.Profiles.get(player)
		if not prof or prof.money < (r.cost or 0) then
			return false
		end
		prof.money -= r.cost or 0
		ctx.Profiles.markDirty(player)
	end
	ctx.Raid.finalize(player, "SUCCESS")
	return true
end

function Extract.tick()
	local t = workspace:GetServerTimeNow()
	for player, s in ctx.Raid.sessions() do
		if not s.done and (s.state == "ACTIVE" or s.state == "EXTRACTING") then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local zone = nil
			if hum and hum.Health > 0 and root then
				for _, id in s.extracts do
					local e = ctx.World.extracts[id]
					if e and Extract.inside(e, root.Position) then
						zone = id
						break
					end
				end
			end
			if s.state == "ACTIVE" then
				if zone then
					local e = ctx.World.extracts[zone]
					local why, text = Extract.blocked(player, s, e)
					if why then
						if s.exDenied ~= zone then
							s.exDenied = zone
							ctx.Remotes.note(player, "extract", { state = "denied", zone = zone, reason = why, text = text })
						end
					else
						s.state = "EXTRACTING"
						s.exZone = zone
						s.exEnds = t + Config.EXTRACT_HOLD
						ctx.Remotes.note(player, "extract", { state = "start", zone = zone, name = e.name, ends = s.exEnds, cost = e.rule.kind == "paid" and e.rule.cost or nil })
					end
				else
					s.exDenied = nil
				end
			elseif s.state == "EXTRACTING" then
				if zone ~= s.exZone then
					s.state = "ACTIVE"
					s.exZone = nil
					s.exEnds = nil
					ctx.Remotes.note(player, "extract", { state = "cancel" })
				elseif t >= s.exEnds then
					if not complete(player, s, ctx.World.extracts[zone]) then
						s.state = "ACTIVE"
						s.exZone = nil
						s.exEnds = nil
						s.exDenied = zone
						ctx.Remotes.note(player, "extract", { state = "denied", zone = zone, reason = "MONEY", text = "NOT ENOUGH MONEY" })
					end
				end
			end
		end
	end
end

function Extract.start()
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(Extract.tick)
			if not ok then
				warn("[ZR] extract tick", err)
			end
		end
	end)
end

return Extract
