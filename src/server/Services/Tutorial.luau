--!nonstrict
-- Decision ui-5a: the FIRST RAID (Tarkov 1.0's tutorial raid). The rules and the course are in shared/TutorialData.luau,
-- the area in Maps/Tutorial.luau. This service offers it to a player who has never raided, starts it (Raid.enterTutorial:
-- a loaned kit, a session of its own on the tutorial map), lays out its loot and its scavs, follows the player through
-- the steps (the objective line on the HUD, Controllers/Tutorial.luau) and closes it: an extract marks it done (the
-- loot goes to the stash like a scav run's), a death or a give-up costs nothing and the offer stays.
-- Requests ("tut"): { op = "state" } -> { offer, step, n, of, text }; { op = "start" }; { op = "skip" }.
local Tutorial = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local T = require(Shared.TutorialData)
local Items = require(Shared.Items)

local ctx
local runs = {} -- player -> { step = id, piles = { cid }, bots = { { group, u } }, body = model }

local function spec()
	return ctx.World.tutorial
end

local function note(player, data)
	if typeof(player) == "Instance" and player.Parent then
		ctx.Remotes.note(player, "tut", data)
	end
end

-- the loaned kit as a raid holder (Settle.deployTutorial takes it as it is)
function Tutorial.kit()
	local Inv = ctx.Inv
	local h = Inv.newHolder("raid")
	for slotName, id in T.KIT.slots do
		local g, it = Inv.newItem(id, 1)
		Inv.placeSlot(h, g, it, slotName)
	end
	for _, e in T.KIT.pockets do
		local g, it = Inv.newItem(e[1], e[2])
		Inv.place(h, g, it, { "pockets" })
	end
	return h
end

-- a ground pile holding exactly `list` ({ id, n, kind }); magazines come loaded with the tutorial's rounds
local function pile(pos, list, label)
	local Inv = ctx.Inv
	local c = ctx.Loot.spawnPile(pos, {})
	for _, e in list do
		for _ = 1, (e[3] == "mag") and e[2] or 1 do
			local extra = nil
			if e[3] == "mag" then
				extra = { a = Items.defs[e[1]].capacity, at = T.AMMO }
			end
			local g, it = Inv.newItem(e[1], (e[3] == "mag") and 1 or e[2], extra)
			if Inv.place(c.holder, g, it, { "main" }) then
				table.insert(c.order, g)
			end
		end
	end
	c.temp = false -- not swept when a match ends; Tutorial removes it with the run
	c.tutorial = true
	c.label = label
	local pp = c.part and c.part:FindFirstChildOfClass("ProximityPrompt")
	if pp then
		pp.ObjectText = label
	end
	ctx.Loot.changed(c)
	return c
end

-- the body in the corridor: a scav's rig laid on its back beside the pile (Tarkov: the MPX lies by a dead man)
local function body(cf)
	local ok, model = pcall(ctx.Chars.buildRig, "scav", 1)
	if not ok or not model then
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Humanoid") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	model.Name = "TutorialBody"
	model:PivotTo(cf * CFrame.Angles(math.rad(-90), 0, 0))
	model.Parent = workspace:FindFirstChild("ZR_Loot") or workspace
	return model
end

local function inZone(player, z)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not z then
		return false
	end
	local p = root.Position
	return p.X >= z.x0 and p.X <= z.x1 and p.Z >= z.z0 and p.Z <= z.z1
end

local function has(s, id)
	for _, it in s.inv.items do
		if it.id == id then
			return true
		end
	end
	return false
end

-- is a step's condition met? (TutorialData: has:ID, loaded, clear:GROUP, healthy, zone:NAME, extract)
function Tutorial.met(player, s, run, step)
	local d = step.done
	local id = string.match(d, "^has:(.+)$")
	if id then
		return has(s, id)
	end
	if d == "loaded" then
		local g = s.inv.slots.primary
		local it = g and s.inv.items[g]
		local mag = it and it.mag and s.inv.items[it.mag]
		return it ~= nil and it.id == "SPARROW_SMG" and mag ~= nil and (mag.a or 0) > 0 and s.active == "primary"
	end
	local group = string.match(d, "^clear:(.+)$")
	if group then
		for _, b in run.bots do
			if b.group == group and b.u.alive and b.u.hum and b.u.hum.Health > 0 then
				return false
			end
		end
		return true
	end
	if d == "healthy" then
		local hs = player.Character and ctx.Health.get(player.Character)
		return hs ~= nil and next(hs.bleedL) == nil and next(hs.bleedH) == nil and next(hs.fract) == nil
	end
	local zone = string.match(d, "^zone:(.+)$")
	if zone then
		return inZone(player, spec().zones[zone])
	end
	return false -- "extract": closed by Raid.finalize
end

local function sendStep(player, run)
	local step = T.step(run.step)
	if not step then
		return
	end
	local n = 0
	for i, x in T.STEPS do
		if x.id == step.id then
			n = i
		end
	end
	note(player, { step = step.id, text = step.text, n = n, of = #T.STEPS, signs = step.signs })
end

function Tutorial.state(player)
	local prof = ctx.Profiles.get(player)
	local run = runs[player]
	local step = run and T.step(run.step)
	return { offer = T.offered(prof) and run == nil, step = step and step.id, text = step and step.text }
end

function Tutorial.start(player)
	local prof = ctx.Profiles.get(player)
	if not T.offered(prof) then
		return false, "NOT_OFFERED"
	end
	local sp = spec()
	if not sp then
		return false, "NO_AREA"
	end
	-- one run at a time: the course is a single place on this server (Tarkov gives each player an instance of their
	-- own, which a Roblox server cannot)
	for other in runs do
		if other ~= player and other.Parent then
			return false, "IN_USE"
		end
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not ctx.World.inSafehouse(root.Position) then
		return false, "NOT_IN_BUNKER"
	end
	local okE, err = ctx.Raid.enterTutorial(player, Tutorial.kit(), sp.spawnCF, { T.EXIT }, T.TIME)
	if not okE then
		return false, err
	end
	local run = { step = T.STEPS[1].id, piles = {}, bots = {} }
	runs[player] = run
	table.insert(run.piles, pile(sp.desk, T.LOOT.desk, "Reception desk").id)
	table.insert(run.piles, pile(sp.body.pile, T.LOOT.body, "Dead man's gear").id)
	table.insert(run.piles, pile(sp.tentA, T.LOOT.tentA, "Field table").id)
	table.insert(run.piles, pile(sp.tentB, T.LOOT.tentB, "Field table").id)
	run.body = body(sp.body.cf)
	for _, p in sp.posts do
		-- leashed to their posts: they fight from their ground and never come hunting through the course
		local u = ctx.AI.spawn("scav", p.pos, { post = p.pos, zones = { p.pos }, tutorial = true, diff = "easy", leash = p.leash or 16 })
		if u then
			table.insert(run.bots, { group = p.group, u = u })
		end
	end
	sendStep(player, run)
	return true
end

function Tutorial.skip(player)
	local prof = ctx.Profiles.get(player)
	if not prof or prof.tut ~= nil or runs[player] then
		return false
	end
	prof.tut = "skipped"
	task.spawn(ctx.Profiles.save, player)
	return true
end

local function cleanup(run)
	for _, cid in run.piles do
		ctx.Loot.remove(cid)
	end
	for _, b in run.bots do
		if b.u.model and b.u.model.Parent then
			b.u.alive = false
			b.u.model:Destroy()
		end
	end
	if run.body and run.body.Parent then
		run.body:Destroy()
	end
end

-- Raid.finalize calls this for a tutorial session: an extract finishes it; anything else leaves the offer open
function Tutorial.finished(player, outcome, _s)
	local run = runs[player]
	runs[player] = nil
	if run then
		cleanup(run)
	end
	local prof = ctx.Profiles.get(player)
	if outcome == "SUCCESS" and prof then
		prof.tut = "done"
		ctx.Economy.mail(prof, "system", "First raid done. What you carried out is in your stash. The traders' terminals in Relay 7 have work for you: start with their first tasks.")
		task.spawn(ctx.Profiles.save, player)
		note(player, { done = true })
	else
		note(player, { ended = outcome })
	end
end

local function tick()
	for player, run in runs do
		local s = ctx.Raid.session(player)
		if not player.Parent or not s or not s.tutorial then
			if not player.Parent then
				runs[player] = nil
				cleanup(run)
			end
			continue
		end
		local step = T.step(run.step)
		-- several steps can be met at once (no wounds to treat): move on until one is not
		local guard = 0
		while step and step.done ~= "extract" and Tutorial.met(player, s, run, step) and guard < #T.STEPS do
			guard += 1
			local nx = T.next(step.id)
			if not nx then
				break
			end
			run.step = nx.id
			step = nx
			sendStep(player, run)
		end
	end
end

function Tutorial.init(c)
	ctx = c
	ctx.Remotes.onReq("tut", function(player, p)
		local op = type(p) == "table" and p.op or nil
		if op == "start" then
			local ok, err = Tutorial.start(player)
			return { ok = ok, err = err }
		elseif op == "skip" then
			return { ok = Tutorial.skip(player) }
		end
		return { ok = true, data = Tutorial.state(player) }
	end, 1, 3)
end

function Tutorial.boot()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(tick)
			if not ok then
				warn("[ZR] tutorial tick", err)
			end
		end
	end)
end

-- (TutorialTests) the run of a player
function Tutorial.runOf(player)
	return runs[player]
end

return Tutorial
