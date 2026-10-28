--!nonstrict
-- Studio-only test bridge: ServerStorage.EFB_Dev:Invoke(cmd, ...) drives full-loop tests via MCP execute_luau.
-- Never created on live servers.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("EFB")
local Items = require(Shared.Items)
local Inv = require(script.Parent.Inv)

local Dev = {}
local ctx

local function plr(name)
	return (name and Players:FindFirstChild(name)) or Players:GetPlayers()[1]
end

local function brief(h)
	local list = {}
	for g, it in h.items do
		local where, info = Inv.locate(h, g)
		table.insert(list, string.format("%s x%d%s @%s%s", it.id, it.n, it.a and ("(" .. it.a .. ")") or "", tostring(where), type(info) == "string" and (":" .. info) or ""))
	end
	table.sort(list)
	return list
end

local C = {}

function C.state(name)
	local p = plr(name)
	local prof = ctx.Profiles.get(p)
	local s = ctx.Raid.session(p)
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return HttpService:JSONEncode({
		player = p.Name, rev = prof and prof.rev, money = prof and prof.money, pending = prof and prof.pendingRaid and prof.pendingRaid.id,
		stats = prof and prof.stats, profileItems = prof and brief(prof), invariant = prof and select(2, Inv.check(prof)) or "ok",
		raid = s and { id = s.id, state = s.state, left = math.floor(s.endsAt - workspace:GetServerTimeNow()), extracts = s.extracts, kills = s.kills, items = brief(s.inv), invariant = select(2, Inv.check(s.inv)) or "ok" } or nil,
		health = hum and hum.Health, pos = root and tostring(Vector3.new(math.floor(root.Position.X), math.floor(root.Position.Y), math.floor(root.Position.Z))),
		persistence = ctx.Store.mode, world = ctx.Raid.world.status,
	})
end

function C.deploy(name)
	local p = plr(name)
	local prof = ctx.Profiles.get(p)
	local res = ctx.Raid.deploy(p, { rev = prof.rev })
	task.wait(1.5)
	return HttpService:JSONEncode(res)
end

function C.tp(name, where)
	local p = plr(name)
	local char = p.Character
	local cf
	local lc = ctx.Loot.containers[where]
	if lc and lc.part then
		cf = lc.part.CFrame * CFrame.new(0, 2, -4)
	elseif ctx.World.extracts[where] then
		cf = CFrame.new(ctx.World.extracts[where].pos + Vector3.new(0, 3.5, 0))
	elseif where == "safehouse" then
		cf = ctx.World.safehouse.spawn
	elseif typeof(where) == "Vector3" then
		cf = CFrame.new(where)
	end
	if not cf or not char then
		return "no target"
	end
	char:PivotTo(cf)
	return "ok " .. tostring(cf.Position)
end

function C.loot(name, cid)
	local p = plr(name)
	C.tp(name, cid)
	task.wait(0.3)
	ctx.Loot.open(p, cid)
	local c = ctx.Loot.containers[cid]
	return HttpService:JSONEncode(c and ctx.Loot.view(c) or "none")
end

function C.take(name, cid, index)
	local p = plr(name)
	local c = ctx.Loot.containers[cid]
	local b = c and c.items[index or 1]
	if not b then
		return "nothing"
	end
	return HttpService:JSONEncode(ctx.Loot.take(p, cid, b.g))
end

function C.takeTwice(name, cid)
	local p = plr(name)
	local c = ctx.Loot.containers[cid]
	local b = c and c.items[1]
	if not b then
		return "nothing"
	end
	local r1, r2
	task.spawn(function()
		r1 = ctx.Remotes.dispatch(p, "inv", { op = "take", cid = cid, g = b.g, rid = "dupA" })
	end)
	task.spawn(function()
		r2 = ctx.Remotes.dispatch(p, "inv", { op = "take", cid = cid, g = b.g, rid = "dupB" })
	end)
	task.wait(0.2)
	local count = 0
	for g in ctx.Raid.session(p).inv.items do
		if g == b.g then
			count += 1
		end
	end
	return HttpService:JSONEncode({ r1 = r1, r2 = r2, copiesInBag = count })
end

function C.kill(name)
	local p = plr(name)
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = 0
	end
	task.wait(0.5)
	return "killed"
end

function C.extract(name)
	local s = ctx.Raid.session(plr(name))
	if not s then
		return "not in raid"
	end
	C.tp(name, s.extracts[1])
	return "moved to " .. s.extracts[1]
end

function C.rejoin(name)
	local p = plr(name)
	if ctx.Raid.session(p) then
		ctx.Raid.finalize(p, "DISCONNECTED")
	end
	local prof, rec = ctx.Profiles.reload(p)
	ctx.Raid.push(p)
	return HttpService:JSONEncode({ loaded = prof ~= nil, recovered = rec ~= nil, items = prof and brief(prof) })
end

function C.failWrites(n)
	ctx.Store.failNext = n or 1
	return "next writes fail: " .. tostring(ctx.Store.failNext)
end

function C.ai()
	local out = {}
	for _, g in ctx.AI.guards do
		table.insert(out, string.format("%s %s hp=%d pos=%s", g.name, g.state, g.hum and g.hum.Health or -1, g.root and tostring(Vector3.new(math.floor(g.root.Position.X), math.floor(g.root.Position.Y), math.floor(g.root.Position.Z))) or "?"))
	end
	return table.concat(out, " | ")
end

function C.tests()
	local folder = script.Parent.Parent:FindFirstChild("Tests")
	local report = {}
	for _, m in folder:GetChildren() do
		if m:IsA("ModuleScript") then
			local ok, res = pcall(function()
				return require(m).run(ctx)
			end)
			table.insert(report, m.Name .. ": " .. (ok and res or ("ERROR " .. tostring(res))))
		end
	end
	return table.concat(report, "\n")
end

function C.shots()
	return HttpService:JSONEncode(ctx.Combat.stats)
end

function Dev.init(c)
	ctx = c
	if not RunService:IsStudio() then
		return
	end
	local old = ServerStorage:FindFirstChild("EFB_Dev")
	if old then
		old:Destroy()
	end
	local bf = Instance.new("BindableFunction")
	bf.Name = "EFB_Dev"
	bf.OnInvoke = function(cmd, a, b, d)
		local f = C[cmd]
		if not f then
			return "unknown cmd"
		end
		local ok, res = pcall(f, a, b, d)
		return ok and res or ("ERR " .. tostring(res))
	end
	bf.Parent = ServerStorage
end

return Dev
