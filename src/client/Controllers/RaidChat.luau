--!nonstrict
-- The chat bar's channel (decision ui-7a; the rules are the server's Chat.luau): in a raid what you type goes to your
-- squad channel (ZR_Squad), Tarkov having no public text chat in a raid; in the bunker it goes to the public channel.
local TextChatService = game:GetService("TextChatService")

local RaidChat = {}
local ctx

function RaidChat.init(c)
	ctx = c
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	task.spawn(function()
		local channels = TextChatService:WaitForChild("TextChannels", 30)
		local bar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		if not (channels and bar) then
			return
		end
		local was = nil
		while true do
			local raid = ctx.State.inRaid()
			if raid ~= was then
				local target = raid and channels:FindFirstChild("ZR_Squad") or channels:FindFirstChild("RBXGeneral")
				if target then
					bar.TargetTextChannel = target
					was = raid
				end
			end
			task.wait(1)
		end
	end)
end

return RaidChat
