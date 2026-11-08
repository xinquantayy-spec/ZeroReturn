--!nonstrict
-- Text chat in raids (decision ui-7a). Tarkov has no text chat in a raid: only proximity voice (since 0.12.12), and
-- text out of a raid. Roblox gives a server one public channel, so the dead back in the bunker could call out
-- positions to the living. Here a raider neither hears the public channel nor speaks on it: what a raider types goes
-- to the squad channel (ZR_Squad), which reaches only the squad, in a raid and out. The bunker keeps the public channel.
-- The client points its chat bar at ZR_Squad while in a raid (RaidChat.luau).
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Chat = {}
local ctx

local function inRaid(p)
	local s = p and ctx and ctx.Raid.session(p)
	return s ~= nil and not s.done
end
Chat.inRaid = inRaid

local function playerOf(source)
	return source and Players:GetPlayerByUserId(source.UserId) or nil
end

-- a public message goes only between two players in the bunker
function Chat.allowPublic(from, to)
	return not inRaid(from) and not inRaid(to)
end

-- a squad message goes to the sender and the sender's squad
function Chat.allowSquad(from, to)
	if from == to then
		return true
	end
	local a = ctx and ctx.Match.squadOf(from)
	local b = ctx and ctx.Match.squadOf(to)
	return a ~= nil and a == b
end

function Chat.init(c)
	ctx = c
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		warn("[ZR] Chat: the place uses legacy chat, so the raid chat rules are off")
		return
	end
	task.spawn(function()
		local channels = TextChatService:WaitForChild("TextChannels", 30)
		if not channels then
			warn("[ZR] Chat: no TextChannels, the raid chat rules are off")
			return
		end
		local general = channels:WaitForChild("RBXGeneral", 30)
		if general then
			general.ShouldDeliverCallback = function(message, textSource)
				local from, to = playerOf(message.TextSource), playerOf(textSource)
				if not (from and to) then
					return true
				end
				return Chat.allowPublic(from, to)
			end
		end
		local squad = channels:FindFirstChild("ZR_Squad") or Instance.new("TextChannel")
		squad.Name = "ZR_Squad"
		squad.Parent = channels
		squad.ShouldDeliverCallback = function(message, textSource)
			local from, to = playerOf(message.TextSource), playerOf(textSource)
			if not (from and to) then
				return false
			end
			return Chat.allowSquad(from, to)
		end
		Chat.squad = squad
		local function join(p)
			local ok, err = pcall(function()
				squad:AddUserAsync(p.UserId)
			end)
			if not ok then
				warn("[ZR] Chat: could not add", p.Name, "to the squad channel:", err)
			end
		end
		for _, p in Players:GetPlayers() do
			task.spawn(join, p)
		end
		Players.PlayerAdded:Connect(join)
	end)
end

return Chat
