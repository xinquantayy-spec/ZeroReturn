--!strict
-- Profile persistence with per-key session locks.
-- DATASTORE mode: UpdateAsync + lock {s = serverId, t = os.time()}. MEMORY mode: Studio/unpublished fallback.
-- Studio always uses the DEV_ store name; live servers use the live store.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local Store = {}
Store.serverId = (game.JobId ~= "" and game.JobId) or ("studio-" .. HttpService:GenerateGUID(false))
Store.mode = "MEMORY"
Store.failNext = 0 -- test hook: number of upcoming writes to fail (Studio only)

local memory: { [string]: any } = {}
local ds: GlobalDataStore? = nil

function Store.init(_ctx: any)
	local name = RunService:IsStudio() and Config.DATASTORE_DEV or Config.DATASTORE_LIVE
	local ok, err = pcall(function()
		ds = DataStoreService:GetDataStore(name)
		;(ds :: any):GetAsync("__probe")
	end)
	if ok then
		Store.mode = "DATASTORE"
		print("[ZR] Profiles: DataStore", name)
	else
		Store.mode = "MEMORY"
		warn("[ZR] Profiles: DataStore unavailable (" .. tostring(err) .. ") -> in-memory store, data lasts until server shutdown")
	end
end

local function update(key: string, fn: (any) -> any): (boolean, any)
	if Store.failNext > 0 and RunService:IsStudio() then
		Store.failNext -= 1
		return false, "SIMULATED_FAILURE"
	end
	if Store.mode == "MEMORY" then
		local cur = Util.copy(memory[key])
		local nv = fn(cur)
		if nv == nil then
			return true, Util.copy(memory[key])
		end
		memory[key] = Util.copy(nv)
		return true, Util.copy(nv)
	end
	local result
	local ok, err = pcall(function()
		result = (ds :: any):UpdateAsync(key, fn)
	end)
	if not ok then
		return false, err
	end
	return true, result
end

local function lockedElsewhere(data: any): boolean
	local lk = data and data.lock
	return lk ~= nil and lk.s ~= Store.serverId and (os.time() - (lk.t or 0)) < Config.LOCK_TTL
end

-- Acquire the session lock and return the stored profile (or a fresh one from newFn).
function Store.acquire(key: string, newFn: () -> any): (any?, string?)
	for attempt = 1, 6 do
		local ok, res = update(key, function(old)
			local data = old or newFn()
			if lockedElsewhere(data) then
				return nil
			end
			data.lock = { s = Store.serverId, t = os.time() }
			return data
		end)
		if ok and type(res) == "table" and res.lock and res.lock.s == Store.serverId then
			return res, nil
		end
		task.wait(math.min(2 ^ attempt, 15))
	end
	return nil, "PROFILE_LOCKED_OR_UNAVAILABLE"
end

-- Write while holding the lock. release=true clears it. Returns ok, err.
function Store.write(key: string, data: any, release: boolean?): (boolean, string?)
	local snapshot = Util.copy(data)
	local lost = false
	local ok, err = update(key, function(old)
		if lockedElsewhere(old) then
			lost = true
			return nil
		end
		if release then
			snapshot.lock = nil
		else
			snapshot.lock = { s = Store.serverId, t = os.time() }
		end
		return snapshot
	end)
	if not ok then
		return false, "STORE_ERROR:" .. tostring(err)
	end
	if lost then
		return false, "LOCK_LOST"
	end
	return true, nil
end

-- Cross-server mailbox (insurance returns): append under UpdateAsync, drained by the owner's server.
function Store.mail(userId: number, entry: any): boolean
	local ok = update("mail_" .. tostring(userId), function(old)
		local box = type(old) == "table" and old or {}
		table.insert(box, entry)
		while #box > 40 do
			table.remove(box, 1)
		end
		return box
	end)
	return ok
end

function Store.drainMail(userId: number): { any }
	local got = nil
	local ok = update("mail_" .. tostring(userId), function(old)
		got = old
		if type(old) == "table" and #old > 0 then
			return {}
		end
		return nil
	end)
	return (ok and type(got) == "table") and got or {}
end

-- Studio test helper: raw read of memory/DataStore value (no lock change).
function Store.peek(key: string): any
	if Store.mode == "MEMORY" then
		return Util.copy(memory[key])
	end
	local ok, v = pcall(function()
		return (ds :: any):GetAsync(key)
	end)
	return ok and v or nil
end

return Store
