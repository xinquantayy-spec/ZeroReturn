--!strict
-- Creates remotes and routes client requests through validation, token-bucket rate limits and
-- request-id de-duplication (repeated rid returns the original result, never re-executes).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("EFB")
local Net = require(Shared.Net)
local Util = require(Shared.Util)

local Remotes = {}
local folder: Folder
local req: RemoteFunction
local shoot: RemoteEvent
local act: RemoteEvent
local state: RemoteEvent
local note: RemoteEvent
local fx: UnreliableRemoteEvent

local reqHandlers: { [string]: any } = {}
local actHandlers: { [string]: any } = {}
local shootHandler: any = nil
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}
local results: { [Player]: { map: { [string]: any }, order: { string } } } = {}
Remotes.strikes = {} :: { [Player]: number }

local function make(class: string, name: string): any
	local r = Instance.new(class)
	r.Name = name
	r.Parent = folder
	return r
end

-- token bucket: rate per second, burst capacity
function Remotes.allow(player: Player, key: string, rate: number, burst: number): boolean
	local pb = buckets[player]
	if not pb then
		pb = {}
		buckets[player] = pb
	end
	local now = os.clock()
	local b = pb[key]
	if not b then
		b = { tokens = burst, last = now }
		pb[key] = b
	end
	b.tokens = math.min(burst, b.tokens + (now - b.last) * rate)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

function Remotes.strike(player: Player, why: string)
	local n = (Remotes.strikes[player] or 0) + 1
	Remotes.strikes[player] = n
	if n % 25 == 1 then
		warn("[EFB] rejected input from", player.Name, why, "strikes", n)
	end
end

local function fail(code: string, msg: string?): any
	return { ok = false, code = code, msg = msg }
end
Remotes.fail = fail

function Remotes.ok(data: any?): any
	return { ok = true, data = data }
end

function Remotes.onReq(action: string, fn: (Player, any) -> any, rate: number?, burst: number?)
	reqHandlers[action] = { fn = fn, rate = rate or 5, burst = burst or 8 }
end

function Remotes.onAct(action: string, fn: (Player, any) -> (), rate: number?, burst: number?)
	actHandlers[action] = { fn = fn, rate = rate or 5, burst = burst or 8 }
end

function Remotes.onShoot(fn: (Player, any, any, any) -> ())
	shootHandler = fn
end

-- Exposed for tests: dedupe/rate-limited dispatch without a real remote.
function Remotes.dispatch(player: Player, action: any, payload: any): any
	if type(action) ~= "string" or #action > 32 then
		Remotes.strike(player, "bad action")
		return fail("BAD_INPUT")
	end
	local h = reqHandlers[action]
	if not h then
		Remotes.strike(player, "unknown action " .. action)
		return fail("BAD_INPUT")
	end
	if payload ~= nil and (type(payload) ~= "table" or not Util.sane(payload, 16, 3)) then
		Remotes.strike(player, "bad payload " .. action)
		return fail("BAD_INPUT")
	end
	payload = payload or {}
	local rid = payload.rid
	local cache = results[player]
	if not cache then
		cache = { map = {}, order = {} }
		results[player] = cache
	end
	if rid ~= nil then
		if type(rid) ~= "string" or #rid > 40 then
			return fail("BAD_INPUT")
		end
		local prev = cache.map[action .. ":" .. rid]
		if prev then
			return prev
		end
	end
	if not Remotes.allow(player, "req:" .. action, h.rate, h.burst) then
		return fail("COOLDOWN", "Slow down.")
	end
	local ok, res = pcall(h.fn, player, payload)
	if not ok then
		warn("[EFB] handler error", action, res)
		res = fail("SERVER_ERROR")
	end
	res = res or fail("SERVER_ERROR")
	if rid ~= nil then
		local k = action .. ":" .. rid
		cache.map[k] = res
		table.insert(cache.order, k)
		if #cache.order > 64 then
			cache.map[table.remove(cache.order, 1)] = nil
		end
	end
	return res
end

function Remotes.init(_ctx: any)
	local old = ReplicatedStorage:FindFirstChild(Net.FOLDER)
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = Net.FOLDER
	req = make("RemoteFunction", Net.Req)
	shoot = make("RemoteEvent", Net.Shoot)
	act = make("RemoteEvent", Net.Act)
	state = make("RemoteEvent", Net.State)
	note = make("RemoteEvent", Net.Note)
	fx = make("UnreliableRemoteEvent", Net.Fx)
	folder.Parent = ReplicatedStorage

	req.OnServerInvoke = function(player: Player, action: any, payload: any)
		return Remotes.dispatch(player, action, payload)
	end
	act.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
		if type(action) ~= "string" then
			return Remotes.strike(player, "bad act")
		end
		local h = actHandlers[action]
		if not h or (payload ~= nil and not Util.sane(payload, 8, 2)) then
			return Remotes.strike(player, "bad act payload")
		end
		if not Remotes.allow(player, "act:" .. action, h.rate, h.burst) then
			return
		end
		local ok, err = pcall(h.fn, player, payload)
		if not ok then
			warn("[EFB] act error", action, err)
		end
	end)
	shoot.OnServerEvent:Connect(function(player: Player, seq: any, origin: any, dir: any)
		-- generous bucket (fire-rate itself is enforced in Combat); stops floods cheaply
		if not Remotes.allow(player, "shoot", 14, 16) then
			return Remotes.strike(player, "shoot flood")
		end
		if shootHandler then
			local ok, err = pcall(shootHandler, player, seq, origin, dir)
			if not ok then
				warn("[EFB] shoot error", err)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		buckets[p] = nil
		results[p] = nil
		Remotes.strikes[p] = nil
	end)
end

function Remotes.push(player: Player, snapshot: any)
	state:FireClient(player, snapshot)
end

function Remotes.note(player: Player, kind: string, data: any?)
	note:FireClient(player, kind, data)
end

function Remotes.noteAll(kind: string, data: any?)
	note:FireAllClients(kind, data)
end

function Remotes.fx(kind: string, data: any, except: Player?)
	for _, p in Players:GetPlayers() do
		if p ~= except then
			fx:FireClient(p, kind, data)
		end
	end
end

return Remotes
