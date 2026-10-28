--!nonstrict
-- World loot: server-rolled contents with stable GUIDs, timed search, range checks, atomic claims.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Inv = require(script.Parent.Inv)

local Loot = {}
local ctx
local containers = {}
local pileN = 0
Loot.containers = containers

-- weighted pools: n = stack range, a = magazine rounds range
local POOLS = {
	crate = {
		{ id = "SIGNAL_COIL", w = 20 }, { id = "CERAMIC_FUSE", w = 20 }, { id = "UC62", w = 18, n = { 20, 45 } },
		{ id = "BANDAGE", w = 10 }, { id = "CRACKED_LENS", w = 10 }, { id = "R17_MAG", w = 7, a = { 0, 25 } },
		{ id = "DECK_TRANSCEIVER", w = 6 }, { id = "RUSTED_KEYCARD", w = 5 }, { id = "SEALED_DRIVE", w = 3 },
	},
	locker = {
		{ id = "BANDAGE", w = 18 }, { id = "UC62", w = 18, n = { 15, 40 } }, { id = "CERAMIC_FUSE", w = 16 },
		{ id = "RUSTED_KEYCARD", w = 12 }, { id = "R17_MAG", w = 10, a = { 5, 25 } }, { id = "SIGNAL_COIL", w = 10 },
		{ id = "CRACKED_LENS", w = 8 }, { id = "SEALED_DRIVE", w = 5 },
	},
	drawer = {
		{ id = "SEALED_DRIVE", w = 16 }, { id = "RUSTED_KEYCARD", w = 18 }, { id = "CRACKED_LENS", w = 16 },
		{ id = "CERAMIC_FUSE", w = 14 }, { id = "BANDAGE", w = 10 }, { id = "UC62", w = 8, n = { 10, 25 } },
	},
	guard = {
		{ id = "UC62", w = 30, n = { 15, 40 } }, { id = "R17_MAG", w = 24, a = { 5, 25 } }, { id = "BANDAGE", w = 18 },
		{ id = "SIGNAL_COIL", w = 10 }, { id = "RUSTED_KEYCARD", w = 8 }, { id = "SEALED_DRIVE", w = 4 },
	},
}
Loot.POOLS = POOLS

local function fail(code, msg)
	return ctx.Remotes.fail(code, msg)
end

function Loot.roll(rand, poolName, count)
	local pool = POOLS[poolName] or POOLS.crate
	local total = 0
	for _, e in pool do
		total += e.w
	end
	local out = {}
	for _ = 1, count do
		local r = rand:NextNumber() * total
		for _, e in pool do
			r -= e.w
			if r <= 0 then
				local n = e.n and rand:NextInteger(e.n[1], e.n[2]) or 1
				local extra = e.a and { a = rand:NextInteger(e.a[1], e.a[2]) } or nil
				local g, it = Inv.newItem(e.id, n, extra)
				table.insert(out, { g = g, it = it })
				break
			end
		end
	end
	return out
end

-- Pure claim used by take(): moves bundle g from container c into holder. No yields => atomic per server.
function Loot.claim(c, g, holder)
	local idx
	for i, b in c.items do
		if b.g == g then
			idx = i
			break
		end
	end
	if not idx then
		return false, "GONE"
	end
	local done, err = Inv.give(holder, c.items[idx], { "pockets", "bag" })
	if not done then
		return false, err
	end
	table.remove(c.items, idx)
	return true, nil
end

function Loot.view(c)
	local out = {}
	for _, b in c.items do
		table.insert(out, { g = b.g, id = b.it.id, n = b.it.n, a = b.it.a, sub = b.sub and { id = b.sub.it.id, a = b.sub.it.a } or nil })
	end
	return out
end

local function reach(player, c, slack)
	local s = ctx.Raid.session(player)
	if not s or s.done then
		return false, "NOT_IN_RAID"
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root then
		return false, "NOT_AUTHORIZED"
	end
	if not c.part or not c.part.Parent then
		return false, "GONE"
	end
	if (root.Position - c.part.Position).Magnitude > Config.INTERACT_RANGE + (slack or 0) then
		return false, "TOO_FAR"
	end
	return true, s
end

local function send(player, c)
	ctx.Remotes.note(player, "loot", { cid = c.id, label = c.label, items = Loot.view(c) })
end

local function broadcast(c)
	for p in c.viewers do
		if p.Parent and reach(p, c, 4) then
			send(p, c)
		else
			c.viewers[p] = nil
		end
	end
end

function Loot.reset(seed)
	for cid, c in containers do
		if c.temp then
			if c.part and c.part.Parent then
				c.part:Destroy()
			end
			containers[cid] = nil
		end
	end
	local rand = Random.new(seed)
	for _, c in containers do
		local count = (c.kind == "drawer") and rand:NextInteger(1, 3) or rand:NextInteger(2, 4)
		c.items = Loot.roll(rand, c.kind, count)
		c.searched = {}
		c.viewers = {}
		c.searching = {}
	end
end

function Loot.open(player, cid)
	local c = containers[cid]
	if not c or not reach(player, c, 1) then
		return
	end
	if not ctx.Remotes.allow(player, "open", 2, 3) then
		return
	end
	if not c.searched[player] then
		if c.searching[player] then
			return
		end
		c.searching[player] = true
		ctx.Remotes.note(player, "search", { cid = cid, t = Config.SEARCH_TIME, label = c.label })
		task.wait(Config.SEARCH_TIME)
		c.searching[player] = nil
		if containers[cid] ~= c or not reach(player, c, 2) then
			ctx.Remotes.note(player, "search", { cid = cid, cancel = true })
			return
		end
		c.searched[player] = true
	end
	c.viewers[player] = true
	send(player, c)
end

function Loot.take(player, cid, g)
	if type(cid) ~= "string" or type(g) ~= "string" then
		return fail("BAD_INPUT")
	end
	local c = containers[cid]
	if not c then
		return fail("GONE")
	end
	local okk, s = reach(player, c, 3)
	if not okk then
		return fail(s)
	end
	if not c.searched[player] then
		return fail("NOT_AUTHORIZED")
	end
	local done, err = Loot.claim(c, g, s.inv)
	broadcast(c)
	if not done then
		ctx.Raid.push(player)
		if err == "GONE" then
			send(player, c)
			return fail("GONE", "Already taken.")
		end
		return fail(err, "No space in pockets or pack.")
	end
	ctx.Raid.afterChange(player, true)
	return ctx.Remotes.ok()
end

function Loot.put(player, cid, g)
	if type(cid) ~= "string" or type(g) ~= "string" then
		return fail("BAD_INPUT")
	end
	local c = containers[cid]
	if not c then
		return fail("GONE")
	end
	local okk, s = reach(player, c, 3)
	if not okk then
		return fail(s)
	end
	if not c.searched[player] then
		return fail("NOT_AUTHORIZED")
	end
	if #c.items >= Config.CONTAINER_MAX_ITEMS then
		return fail("FULL", "Container is full.")
	end
	local bundle = Inv.take(s.inv, g)
	if not bundle then
		return fail("NO_ITEM")
	end
	table.insert(c.items, bundle)
	broadcast(c)
	ctx.Raid.afterChange(player, true)
	return ctx.Remotes.ok()
end

function Loot.spawnPile(pos, label, items, kind)
	pileN += 1
	local cid = "P" .. pileN
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace:FindFirstChild("ZR_World") }
	local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -30, 0), rp)
	local ground = hit and hit.Position or pos
	local part = Instance.new("Part")
	part.Name = "Loot_" .. cid
	part.Size = (kind == "body") and Vector3.new(2.2, 1.1, 1.6) or Vector3.new(1.8, 0.9, 1.3)
	part.Anchored = true
	part.CanCollide = false
	part.Color = (kind == "body") and Color3.fromHex("2F3438") or Color3.fromHex("4A4B3E")
	part.Material = Enum.Material.Fabric
	part.CFrame = CFrame.new(ground + Vector3.new(0, part.Size.Y / 2, 0)) * CFrame.Angles(0, math.random() * 6.28, 0)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Search"
	pp.ObjectText = label
	pp.HoldDuration = 0
	pp.MaxActivationDistance = Config.INTERACT_RANGE - 1
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.Parent = part
	local folder = workspace:FindFirstChild("ZR_Loot")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ZR_Loot"
		folder.Parent = workspace
	end
	part.Parent = folder
	local c = { id = cid, kind = kind or "pile", label = label, part = part, items = items, searched = {}, viewers = {}, searching = {}, temp = true }
	containers[cid] = c
	pp.Triggered:Connect(function(p)
		Loot.open(p, cid)
	end)
	return c
end

function Loot.drop(player, g)
	if type(g) ~= "string" then
		return fail("BAD_INPUT")
	end
	local s = ctx.Raid.session(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not s or not root then
		return fail("NOT_AUTHORIZED")
	end
	local bundle = Inv.take(s.inv, g)
	if not bundle then
		return fail("NO_ITEM")
	end
	local c = Loot.spawnPile(root.Position + root.CFrame.LookVector * 2.5, "Dropped gear", { bundle }, "pile")
	ctx.Raid.afterChange(player, true)
	return ctx.Remotes.ok({ cid = c.id })
end

function Loot.spawnBody(model, poolName)
	local root = model:FindFirstChild("HumanoidRootPart")
	local pos = root and root.Position or model:GetPivot().Position
	local items = Loot.roll(Random.new(), poolName or "guard", math.random(2, 4))
	return Loot.spawnPile(pos + Vector3.new(1.5, 0, 0), "Harbor Watch kit", items, "body")
end

function Loot.init(c)
	ctx = c
	for _, spot in ctx.World.containers do
		local entry = { id = spot.id, kind = spot.kind, label = spot.label, part = spot.part, items = {}, searched = {}, viewers = {}, searching = {} }
		containers[spot.id] = entry
		spot.prompt.Triggered:Connect(function(player)
			Loot.open(player, spot.id)
		end)
	end
	ctx.Remotes.onReq("loot", function(player, p)
		if p.op == "close" and type(p.cid) == "string" and containers[p.cid] then
			containers[p.cid].viewers[player] = nil
		end
		return ctx.Remotes.ok()
	end, 6, 8)
end

return Loot
