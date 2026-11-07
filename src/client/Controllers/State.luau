--!nonstrict
-- Client mirror of server state + note dispatch + request helpers. The server snapshot is authoritative.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Net = require(Shared.Net)

local State = { data = nil, raid = nil, ready = false }
local listeners = {}
local changed = Instance.new("BindableEvent")
State.changed = changed.Event
local req, act, shoot
local ridN = 0

function State.on(kind, fn)
	listeners[kind] = listeners[kind] or {}
	table.insert(listeners[kind], fn)
end

function State.emit(kind, data)
	for _, fn in listeners[kind] or {} do
		task.spawn(fn, data)
	end
end

function State.toast(text, tone)
	State.emit("toast", { text = text, tone = tone })
end

function State.req(action, payload)
	payload = payload or {}
	ridN += 1
	payload.rid = string.format("%d-%d", math.floor(os.clock() * 1000) % 100000000, ridN)
	if not req then
		return { ok = false, code = "NET" }
	end
	local ok, res = pcall(req.InvokeServer, req, action, payload)
	if not ok or type(res) ~= "table" then
		return { ok = false, code = "NET" }
	end
	if not res.ok and res.msg then
		State.toast(res.msg, "warn")
	end
	return res
end

function State.act(action, payload)
	if act then
		act:FireServer(action, payload)
	end
end

function State.shoot(seq, origin, dir)
	if shoot then
		shoot:FireServer(seq, origin, dir)
	end
end

function State.inRaid()
	return State.data ~= nil and State.data.phase == "RAID"
end

-- seconds until the player scav is ready (server os.time based, corrected for time since the snapshot)
function State.scavCooldown()
	local d = State.data
	if d and d.scavReadyAt and d.serverTime then
		return math.max(0, d.scavReadyAt - d.serverTime - (os.clock() - (State.dataClock or os.clock())))
	end
	local m = State.match
	if not m or not m.scavReadyAt then
		return 0
	end
	return math.max(0, m.scavReadyAt - m.serverTime - (os.clock() - (State.matchClock or os.clock())))
end

function State.init(_ctx)
	req = Net.get(Net.Req)
	act = Net.get(Net.Act)
	shoot = Net.get(Net.Shoot)
	local st = Net.get(Net.State)
	local note = Net.get(Net.Note)
	if not (req and st and note) then
		-- Net.get waits as long as the server takes; this only happens if the remotes are renamed
		warn("[ZR] remotes missing")
		return
	end
	st.OnClientEvent:Connect(function(snap)
		State.data = snap
		State.dataClock = os.clock()
		State.raid = snap.raid
		if not State.ready then
			-- the join card (src/first/Loading.client.luau) closes on this
			game:GetService("Players").LocalPlayer:SetAttribute("ZR_Ready", true)
		end
		State.ready = true
		changed:Fire(snap)
	end)
	note.OnClientEvent:Connect(function(kind, data)
		if kind == "raid" then
			State.raid = data
		elseif kind == "vitals" then
			State.vitals = data
		elseif kind == "match" then
			-- server raid cycle; serverTime is os.time() on the server (scav cooldown), clock marks arrival
			State.match = data
			State.matchClock = os.clock()
		elseif kind == "squad" then
			State.squad = (type(data) == "table" and data.members and #data.members > 0) and data or nil
		end
		State.emit(kind, data)
	end)
	State.fx = Net.get(Net.Fx)
	task.spawn(function()
		task.wait(2)
		if not State.ready then
			State.req("sync")
		end
	end)
end

return State
