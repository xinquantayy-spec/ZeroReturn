--!strict
-- Live profiles per player: load (lock + migrate + crash recovery), serialized saves, autosave, release.
local Players = game:GetService("Players")
local Store = require(script.Parent.Store)
local Settle = require(script.Parent.Settle)
local Inv = require(script.Parent.Inv)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)

local Profiles = {}
local live: { [Player]: any } = {}
local ctx: any

function Profiles.init(c: any)
	ctx = c
end

function Profiles.key(userId: number): string
	return "u_" .. tostring(userId)
end

function Profiles.get(player: Player): any
	local e = live[player]
	return e and e.data
end

function Profiles.set(player: Player, data: any)
	local e = live[player]
	if e then
		e.data = data
	end
end

function Profiles.markDirty(player: Player)
	local e = live[player]
	if e then
		e.dirty = true
	end
end

-- Returns profile, recoveredReceipt (unresolved raid settled as DISCONNECTED) or nil, err.
function Profiles.load(player: Player): (any?, any)
	local key = Profiles.key(player.UserId)
	local data, err = Store.acquire(key, Settle.newProfile)
	if not data then
		return nil, err
	end
	Settle.migrate(data)
	local recovered = nil
	if data.pendingRaid then
		recovered = Settle.finalize(data, data.pendingRaid.id, "DISCONNECTED", nil, os.time())
	end
	-- insurance returns mailed by other servers
	for _, entry in Store.drainMail(player.UserId) do
		if type(entry) == "table" and type(entry.bundles) == "table" then
			table.insert(data.claims, entry)
		end
	end
	if ctx and ctx.Hideout then
		ctx.Hideout.settle(data, nil)
	end
	local ok, msg = Inv.check(data)
	if not ok then
		warn("[ZR] profile invariant failure on load", player.Name, msg)
	end
	if not player.Parent then
		Store.write(key, data, true)
		return nil, "LEFT"
	end
	live[player] = { data = data, key = key, busy = false, dirty = recovered ~= nil }
	if recovered then
		Profiles.save(player, true)
	end
	return data, recovered
end

-- Serialized per player. critical=true retries with backoff. Returns ok, err.
function Profiles.save(player: Player, critical: boolean?, release: boolean?): (boolean, string?)
	local e = live[player]
	if not e then
		return false, "NO_PROFILE"
	end
	local waited = 0
	while e.busy and waited < 30 do
		task.wait(0.1)
		waited += 0.1
	end
	e.busy = true
	local attempts = critical and 4 or 1
	local ok, err = false, nil
	for i = 1, attempts do
		ok, err = Store.write(e.key, e.data, release)
		if ok or err == "LOCK_LOST" then
			break
		end
		task.wait(0.5 * 2 ^ (i - 1))
	end
	e.busy = false
	if ok then
		e.dirty = false
	else
		warn("[ZR] profile save failed", player.Name, err)
	end
	return ok, err
end

function Profiles.release(player: Player)
	local e = live[player]
	if not e then
		return
	end
	Profiles.save(player, true, true)
	live[player] = nil
end

function Profiles.start()
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE)
			for player, e in live do
				if player.Parent then
					task.spawn(Profiles.save, player, false)
				end
			end
		end
	end)
end

function Profiles.all(): { [Player]: any }
	return live
end

-- Studio test hook: drop the live profile without saving (simulates a crash; the last stored copy wins).
function Profiles.forgetForTest(player: Player)
	if game:GetService("RunService"):IsStudio() then
		live[player] = nil
	end
end

-- Studio test hook: simulate leave + rejoin on the same server (release then load again).
function Profiles.reload(player: Player): (any?, any)
	Profiles.release(player)
	return Profiles.load(player)
end

return Profiles
