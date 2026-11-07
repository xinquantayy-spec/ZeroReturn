--!strict
-- Remote names. The server creates ReplicatedStorage.ZR_Net once it has started; clients wait for it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {
	FOLDER = "ZR_Net",
	Req = "Req", -- RemoteFunction  C->S  (action, payload) -> result
	Shoot = "Shoot", -- RemoteEvent  C->S  (seq, origin, dir)
	Act = "Act", -- RemoteEvent      C->S  (action, payload) fire-and-forget
	State = "State", -- RemoteEvent  S->C  own snapshot
	Note = "Note", -- RemoteEvent    S->C  (kind, data)
	Fx = "Fx", -- UnreliableRemoteEvent S->C cosmetic only
}

-- Clients wait for the remotes for as long as the server takes to start: it builds the maps first. On 2026-11-07 that
-- took over 30 s in Studio, and the old 30 s limit left the client with no state at all (STBY and 0 MK in a raid).
-- The join card (src/first/Loading.client.luau) covers the wait. onWait(seconds) runs every 2 s while waiting.
function Net.folder(onWait: ((number) -> ())?): Instance
	local t0 = os.clock()
	local folder = ReplicatedStorage:FindFirstChild(Net.FOLDER)
	while not folder do
		folder = ReplicatedStorage:WaitForChild(Net.FOLDER, 2)
		if not folder and onWait then
			onWait(os.clock() - t0)
		end
	end
	return folder
end

function Net.get(name: string): Instance
	local folder = Net.folder()
	local r = folder:FindFirstChild(name)
	while not r do
		r = folder:WaitForChild(name, 2)
	end
	return r
end

return Net
