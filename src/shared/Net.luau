--!strict
-- Remote names. The server creates ReplicatedStorage.EFB_Net; clients wait (bounded) for it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {
	FOLDER = "EFB_Net",
	Req = "Req", -- RemoteFunction  C->S  (action, payload) -> result
	Shoot = "Shoot", -- RemoteEvent  C->S  (seq, origin, dir)
	Act = "Act", -- RemoteEvent      C->S  (action, payload) fire-and-forget
	State = "State", -- RemoteEvent  S->C  own snapshot
	Note = "Note", -- RemoteEvent    S->C  (kind, data)
	Fx = "Fx", -- UnreliableRemoteEvent S->C cosmetic only
}

function Net.get(name: string): Instance?
	local folder = ReplicatedStorage:WaitForChild(Net.FOLDER, 30)
	if not folder then
		return nil
	end
	return folder:WaitForChild(name, 30)
end

return Net
