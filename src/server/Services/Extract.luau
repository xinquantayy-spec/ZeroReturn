--!nonstrict
-- Extraction zones: server checks position at 5 Hz; 6 s hold; leaving, dying or timer expiry cancels.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("EFB")
local Config = require(Shared.Config)

local Extract = {}
local ctx

function Extract.init(c)
	ctx = c
end

function Extract.inside(e, p)
	local lp = e.cf:PointToObjectSpace(p)
	return math.abs(lp.X) <= e.size.X / 2 and math.abs(lp.Y) <= e.size.Y / 2 + 2 and math.abs(lp.Z) <= e.size.Z / 2
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
			if s.state == "ACTIVE" and zone then
				s.state = "EXTRACTING"
				s.exZone = zone
				s.exEnds = t + Config.EXTRACT_HOLD
				ctx.Remotes.note(player, "extract", { state = "start", zone = zone, name = ctx.World.extracts[zone].name, ends = s.exEnds })
			elseif s.state == "EXTRACTING" then
				if zone ~= s.exZone then
					s.state = "ACTIVE"
					s.exZone = nil
					s.exEnds = nil
					ctx.Remotes.note(player, "extract", { state = "cancel" })
				elseif t >= s.exEnds then
					ctx.Raid.finalize(player, "SUCCESS")
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
				warn("[EFB] extract tick", err)
			end
		end
	end)
end

return Extract
