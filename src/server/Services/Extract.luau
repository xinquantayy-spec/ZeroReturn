--!nonstrict
-- Extraction zones: server checks position at 5 Hz; 6 s hold; leaving, dying or timer expiry cancels.
-- Tarkov extract rules: open, paid (MK on exit), key (carry the key), chance (open or closed for the whole
-- raid, unknown until you get there), scav-only and power (works once a switch such as a generator is on; `also` names a
-- switch that must be on first, as Interchange's shelter: mall power, then the washroom lever) and nobag (the Hole in the
-- Fence: the backpack slot must be empty, checked on entering and again during the hold). PMCs get their side's list, scavs
-- every extract except the cars.
-- Cars (Tarkov's vehicle exits, V-Ex; docs/design/EFT_PARITY.md "Car exits"): a paid exit whose rule has `seats`,
--   { kind = "paid", cost, chance, seats, depart }. The car is there in some raids only (`chance`, rolled with the other
--   chance exits at raid start); the fare is paid at the car (a prompt on it, PMCs only; the money goes at once) and buys one
--   of `seats` seats; the first fare starts one countdown of `depart` seconds that every later passenger joins; when it ends
--   the car leaves for good: seated passengers inside the zone extract, the others are left behind without a refund.
--   Standing in the zone does nothing (a hint says where to pay): a car has no hold.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)

local Extract = {}
local ctx

local DEFAULT_DEPART = 60 -- seconds from the first fare to the car leaving, when the rule has no `depart` (grade C: to confirm)
local PAY_HOLD = 1.5 -- seconds the fare prompt is held

-- this raid's cars: [exit id] = { seats = { { player = Player, s = session } }, departAt = server time | nil, left = bool }
-- (reset at every raid start; a seat keeps its session so a passenger who died or left is told by `s.done`)
Extract.cars = {}

function Extract.init(c)
	ctx = c
end

function Extract.inside(e, p)
	local lp = e.cf:PointToObjectSpace(p)
	return math.abs(lp.X) <= e.size.X / 2 and math.abs(lp.Y) <= e.size.Y / 2 + 2 and math.abs(lp.Z) <= e.size.Z / 2
end

local function carries(h, id)
	for _, it in h.items do
		if it.id == id then
			return true
		end
	end
	return false
end

-- is a backpack worn? (the inventory's `back` slot holds the pack's id)
local function wearsBackpack(h)
	return h ~= nil and h.slots ~= nil and h.slots.back ~= nil
end

-- the rules that can break while the hold runs (a pack put on mid-hold): nil, or (reason code, text)
function Extract.holdBlocked(s, e)
	local r = e and e.rule or {}
	if r.kind == "nobag" and wearsBackpack(s.inv) then
		return "BACKPACK", "BACKPACK SLOT MUST BE EMPTY"
	end
	return nil
end

-- ── cars ─────────────────────────────────────────────────────────────────────────────────────────────────────
-- a paid exit with seats is a car (the other paid exits keep the plain hold)
function Extract.isCar(e)
	local r = e and e.rule
	return r ~= nil and r.kind == "paid" and type(r.seats) == "number" and r.seats > 0
end

-- does the exit roll for being there this raid? (kind chance, or any rule that carries a chance, as the car does)
function Extract.hasChance(r)
	return r ~= nil and (r.kind == "chance" or type(r.chance) == "number")
end

-- the per-raid roll for one rule: an exit without a chance is always there. `roll` (0 to 1) is a test seam.
function Extract.rollOpen(r, roll)
	if not Extract.hasChance(r) then
		return true
	end
	return (roll or math.random()) < (r.chance or 0.5)
end

-- is the exit there this raid? (only a rolling exit can be absent; a roll that has not happened yet counts as absent)
local function isOpen(e)
	return not Extract.hasChance(e.rule) or ctx.Match.extractOpen[e.id] == true
end

-- the car's state for this raid, created on the first fare
local function carOf(e)
	local c = Extract.cars[e.id]
	if not c then
		c = { seats = {}, departAt = nil, left = false }
		Extract.cars[e.id] = c
	end
	return c
end

local function seatIndex(c, player)
	for i, st in c.seats do
		if st.player == player then
			return i
		end
	end
	return nil
end

-- has this exit's car driven off (it never comes back in the same raid)
function Extract.carLeft(e)
	local c = e and Extract.cars[e.id]
	return c ~= nil and c.left == true
end

-- the root part of a raider who is alive, else nil
local function rootOf(player)
	local char = player and player.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if hum and hum.Health > 0 and root then
		return root
	end
	return nil
end

-- tell one player; a test double is a table, there is nobody to tell (the tests replace this to read what was sent)
function Extract.notify(player, kind, data)
	if typeof(player) == "Instance" and player.Parent then
		ctx.Remotes.note(player, kind, data)
	end
end

local function toast(player, text, tone)
	Extract.notify(player, "toast", { text = text, tone = tone or "warn" })
end

-- a passenger leaves with the car (the tests replace this to record who left)
function Extract.finish(player)
	return ctx.Raid.finalize(player, "SUCCESS")
end

-- Flare exits (Tarkov: "Shoot a green flare into the sky while inside the signal flare area"; Customs' Railroad Passage,
-- Interchange's Smuggler's Tunnel): a green flare fired under the open sky within `radius` of the exit opens it for
-- everyone in the raid until the raid ends. Tarkov's pages do not say who it opens for; one flare for all is ours.
-- Returns the names of the exits it opened (the active map's only: World.extracts is the map in play).
function Extract.openFlareAt(p)
	local opened = {}
	for id, e in ctx.World.extracts do
		local r = e.rule
		if r and r.kind == "flare" and not ctx.Match.flareOpen[id] then
			if Vector3.new(p.X - e.pos.X, 0, p.Z - e.pos.Z).Magnitude <= (r.radius or 60) then
				ctx.Match.flareOpen[id] = true
				table.insert(opened, e.name)
			end
		end
	end
	return opened
end

-- Exits that show they are open (Tarkov's Old Gas Station: "Green flares = Open"): while such an exit is there this
-- raid, a green star goes up over it now and then (rule.signal = "green"). The launch spot is the nearest point under
-- open sky within 40 studs of the zone (the exit itself may be in a basement); found once per map.
local SIGNAL_EVERY = { 50, 80 }
local signalSpot = {}
local nextSignal = {}
local function skySpot(e)
	local key = tostring(e.map) .. ":" .. e.id
	if signalSpot[key] ~= nil then
		return signalSpot[key] or nil
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { workspace:FindFirstChild("ZR_AI"), workspace:FindFirstChild("ZR_Corpses") }
	local found = false
	for _, r in { 0, 12, 24, 40 } do
		for k = 0, (r == 0 and 0 or 7) do
			local a = k * math.pi / 4
			local x, z = e.pos.X + math.cos(a) * r, e.pos.Z + math.sin(a) * r
			local down = workspace:Raycast(Vector3.new(x, e.pos.Y + 60, z), Vector3.new(0, -120, 0), rp)
			if down then
				local g = down.Position + Vector3.new(0, 2, 0)
				if not workspace:Raycast(g, Vector3.new(0, 220, 0), rp) then
					found = g
					break
				end
			end
		end
		if found then
			break
		end
	end
	signalSpot[key] = found
	return found or nil
end

function Extract.signalTick(t)
	if ctx.Match.state ~= "RUNNING" then
		table.clear(nextSignal)
		return
	end
	for id, e in ctx.World.extracts do
		local r = e.rule
		if r and r.signal and isOpen(e) then
			local due = nextSignal[id]
			if not due then
				nextSignal[id] = t + math.random(8, 30) -- the first star soon after the raid starts
			elseif t >= due then
				nextSignal[id] = t + math.random(SIGNAL_EVERY[1], SIGNAL_EVERY[2])
				local at = skySpot(e)
				if at then
					ctx.Remotes.fx("flare", { p = at, c = r.signal })
				end
			end
		end
	end
end

-- a green flare fired by a raider (Airdrop.flare, after the open-sky check in Health)
function Extract.flareFired(player, p)
	local s = ctx.Raid.session(player)
	if not s or s.done or ctx.Match.state ~= "RUNNING" then
		return false
	end
	local opened = Extract.openFlareAt(p)
	if #opened == 0 then
		return false
	end
	Extract.refresh()
	ctx.Remotes.note(player, "toast", { text = "SIGNAL SEEN  ·  " .. table.concat(opened, ", ") .. " OPEN", tone = "good" })
	return true
end

-- every raider still in the raid gets a fresh snapshot, which carries the exit list (the car has gone)
function Extract.refresh()
	for player, rs in ctx.Raid.sessions() do
		if not rs.done then
			ctx.Raid.push(player)
		end
	end
end

-- why this raider cannot take a seat in this car now: nil when they can, else (reason code, text for the player)
local function seatBlocked(player, s, e)
	if not s or s.done then
		return "NOT_IN_RAID", "NOT IN A RAID"
	elseif s.scav then
		return "PMC_ONLY", "PMCS ONLY"
	elseif type(s.extracts) == "table" and not table.find(s.extracts, e.id) then
		return "NOT_OFFERED", "NOT AVAILABLE TO YOU"
	elseif not isOpen(e) then
		return "CLOSED", "NOT AVAILABLE THIS RAID"
	end
	local c = Extract.cars[e.id]
	if c and c.left then
		return "LEFT", "THE CAR HAS LEFT"
	elseif c and seatIndex(c, player) then
		return "SEATED", "YOU ALREADY HAVE A SEAT"
	elseif c and #c.seats >= (e.rule.seats or 0) then
		return "FULL", "THE CAR IS FULL"
	end
	return nil
end

-- standing in a car's zone: nothing blocks a passenger (they wait for the car), anyone else is told where to pay
local function carBlocked(player, s, e)
	local why, text = seatBlocked(player, s, e)
	if why == "SEATED" then
		return nil
	elseif why then
		return why, text
	end
	return "PAY", "PAY AT THE CAR"
end

-- nil when the extract can be used right now, else (reason code, text for the player)
function Extract.blocked(player, s, e)
	local r = e.rule or {}
	if Extract.isCar(e) then
		return carBlocked(player, s, e)
	elseif Extract.hasChance(r) and not ctx.Match.extractOpen[e.id] then
		return "CLOSED", "NOT AVAILABLE THIS RAID"
	elseif r.kind == "flare" and not ctx.Match.flareOpen[e.id] then
		return "FLARE", r.needs or "FIRE A GREEN FLARE IN THE SIGNAL AREA"
	elseif r.kind == "scav" and not s.scav then
		return "SCAV_ONLY", "SCAVS ONLY"
	elseif r.kind == "power" and r.also and not ctx.World.switchOn(r.also) then
		return "POWER", r.needsAlso or r.needs or "NO POWER"
	elseif r.kind == "power" and not ctx.World.switchOn(r.switch) then
		return "POWER", r.needs or "NO POWER"
	elseif r.kind == "nobag" and wearsBackpack(s.inv) then
		return "BACKPACK", "BACKPACK SLOT MUST BE EMPTY"
	elseif r.kind == "key" and r.key and not carries(s.inv, r.key) then
		local d = Items.defs[r.key]
		return "KEY", "REQUIRES " .. string.upper(d and d.name or r.key)
	elseif r.kind == "paid" then
		local prof = ctx.Profiles.get(player)
		if not prof or prof.money < (r.cost or 0) then
			return "MONEY", "REQUIRES " .. Util.commas(r.cost or 0) .. " " .. Config.CURRENCY
		end
	end
	return nil
end

-- buy a seat: the fare goes at once (no refund, whatever happens), the first fare starts the countdown and a later one
-- boards the same car. Returns true, or false with (reason code, text for the player). `s` is the payer's raid session,
-- `t` the server time (a test seam).
function Extract.pay(player, s, e, t)
	if not Extract.isCar(e) then
		return false, "NOT_CAR", "THIS EXIT HAS NO CAR"
	end
	local why, text = seatBlocked(player, s, e)
	if why then
		return false, why, text
	end
	local r = e.rule
	local cost = r.cost or 0
	local prof = ctx.Profiles.get(player)
	if not prof or prof.money < cost then
		return false, "MONEY", "NOT ENOUGH MONEY  -  THE FARE IS " .. Util.commas(cost) .. " " .. Config.CURRENCY
	end
	t = t or workspace:GetServerTimeNow()
	prof.money -= cost
	ctx.Profiles.markDirty(player)
	local c = carOf(e)
	table.insert(c.seats, { player = player, s = s })
	local depart = r.depart or DEFAULT_DEPART
	if not c.departAt then
		c.departAt = t + depart
	end
	-- the same extract note a hold sends, flagged as the car's countdown (everyone aboard counts down to the same moment)
	Extract.notify(player, "extract", {
		state = "start", zone = e.id, name = e.name, ends = c.departAt, total = depart, car = true,
		cost = cost, seat = #c.seats, seats = r.seats,
	})
	ctx.Raid.push(player) -- the new balance
	return true
end

-- show or hide a car exit's model: it stands there when the roll put it there and it has not left
function Extract.syncCar(e)
	local rig = e and e.carRig
	if not rig or not rig.model then
		return
	end
	local want = (isOpen(e) and not Extract.carLeft(e)) and rig.home or nil
	if rig.model.Parent ~= want then
		rig.model.Parent = want
	end
end

-- the countdown has run out: the car leaves for good. Seated passengers inside the zone extract; the others (outside the
-- zone, dead, gone) are left behind, and nobody is refunded. Returns how many left in it and how many were left behind.
function Extract.depart(e)
	local c = Extract.cars[e.id]
	if not c or c.left then
		return 0, 0
	end
	c.left = true
	local took, missed = 0, 0
	for _, st in c.seats do
		local p, s = st.player, st.s
		if s and not s.done then
			local root = rootOf(p)
			if root and Extract.inside(e, root.Position) then
				s.exZone = e.id -- tasks that name an exit (Quests.onExtract) read it
				local ok, err = pcall(Extract.finish, p)
				if ok then
					took += 1
				else
					warn("[ZR] car departure", e.id, err)
				end
			else
				missed += 1
				Extract.notify(p, "extract", { state = "left", zone = e.id, car = true, text = "THE CAR HAS LEFT WITHOUT YOU" })
			end
		end
	end
	local okSync, errSync = pcall(Extract.syncCar, e)
	if not okSync then
		warn("[ZR] car departure", e.id, errSync)
	end
	Extract.refresh()
	return took, missed
end

-- called every tick: any car whose countdown has run out leaves (whoever is aboard, even if nobody is left in the raid)
function Extract.carTick(t)
	for id, c in Extract.cars do
		if c.departAt and not c.left and t >= c.departAt then
			local e = ctx.World.extracts[id]
			if e then
				Extract.depart(e)
			else
				c.left = true -- the map changed under it: nothing to show
			end
		end
	end
end

-- raid start: no seats, no countdown, every car back where the roll put it
function Extract.reset()
	table.clear(Extract.cars)
	for _, e in ctx.World.extracts do
		local ok, err = pcall(Extract.syncCar, e)
		if not ok then
			warn("[ZR] car reset", e.id, err)
		end
	end
end

local function complete(player, s, e)
	local r = e.rule or {}
	if r.kind == "paid" then
		local prof = ctx.Profiles.get(player)
		if not prof or prof.money < (r.cost or 0) then
			return false
		end
		prof.money -= r.cost or 0
		ctx.Profiles.markDirty(player)
	end
	ctx.Raid.finalize(player, "SUCCESS")
	return true
end

-- ── the car on the ground: a sedan beside the middle of the zone with the fare prompt on its right flank ───────────
-- (built once at server start for every map; hidden while the roll says no car, and after it has left)
local function groundAt(x, z, y0)
	local ok, hit = pcall(function()
		return workspace:Raycast(Vector3.new(x, y0 + 6, z), Vector3.new(0, -14, 0))
	end)
	if ok and hit and math.abs(hit.Position.Y - y0) <= 4 then
		return hit.Position.Y
	end
	return y0
end

-- the prompt was held: pay if the raider is at the car (the zone, or close to the prompt)
local function onPay(player, e)
	if not ctx.Remotes.allow(player, "carpay", 2, 3) then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	local rig = e.carRig
	local near = Extract.inside(e, root.Position) or (rig ~= nil and rig.pay ~= nil and (root.Position - rig.pay.Position).Magnitude <= Config.INTERACT_RANGE + 4)
	if not near then
		return
	end
	local ok, _, text = Extract.pay(player, ctx.Raid.session(player), e)
	if not ok then
		toast(player, text or "CANNOT PAY", "warn")
	end
end

local function buildCar(e)
	local home = (e.beacon and e.beacon.Parent) or workspace
	-- west of the middle, so the middle stays free to stand on (Dev tp lands there) and the prompt looks at it
	local x = e.pos.X - math.max(e.size.X / 2 - 5.5, 0)
	local z = e.pos.Z
	local cf = CFrame.new(x, groundAt(x, z, e.pos.Y), z)
	local holder = Instance.new("Model")
	holder.Name = "Car_" .. e.id
	holder:SetAttribute("NoDetail", true)
	holder:SetAttribute("Car", e.id)
	local paint = Color3.fromRGB(77, 91, 110)
	local placed = nil
	local okK, Kit = pcall(function()
		return require(script.Parent.Parent.Maps.Kit)
	end)
	if okK and type(Kit) == "table" and Kit.place then
		local okP, m = pcall(Kit.place, holder, "CarSedan", cf, { tint = paint })
		placed = okP and m or nil
	end
	if not placed then
		-- no kit: a plain box the size of a sedan
		local body = Instance.new("Part")
		body.Name = "CarBody"
		body.Anchored = true
		body.Size = Vector3.new(7, 4.7, 15.6)
		body.CFrame = cf * CFrame.new(0, 2.35, 0)
		body.Color = paint
		body.Material = Enum.Material.Metal
		body.TopSurface = Enum.SurfaceType.Smooth
		body.BottomSurface = Enum.SurfaceType.Smooth
		body.Parent = holder
	end
	-- where the fare is paid: outside the right flank at the driver's window
	local pay = Instance.new("Part")
	pay.Name = "PayPoint"
	pay.Anchored = true
	pay.CanCollide = false
	pay.CanQuery = false
	pay.CanTouch = false
	pay.Transparency = 1
	pay.Size = Vector3.new(1, 1, 1)
	pay.CFrame = cf * CFrame.new(4.1, 2.8, -1.5)
	pay.Parent = holder
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "PayPrompt"
	pp.KeyboardKeyCode = Enum.KeyCode.F -- Tarkov interact key
	pp.ActionText = "Pay " .. Util.commas(e.rule.cost or 0) .. " " .. Config.CURRENCY -- shown as "PAY 25,000 MK  ·  DORMS CAR"
	pp.ObjectText = e.name
	pp.HoldDuration = PAY_HOLD
	pp.MaxActivationDistance = Config.INTERACT_RANGE
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.Parent = pay
	pp.Triggered:Connect(function(player)
		local ok, err = pcall(onPay, player, e)
		if not ok then
			warn("[ZR] car fare", err)
		end
	end)
	e.carRig = { model = holder, home = home, pay = pay, prompt = pp }
	Extract.syncCar(e)
end

-- every map's car exits get their car (the maps are built before the services start)
function Extract.buildCars()
	local n = 0
	for _, m in ctx.World.maps or {} do
		for _, e in m.extracts or {} do
			if Extract.isCar(e) and not e.carRig then
				local ok, err = pcall(buildCar, e)
				if ok then
					n += 1
				else
					warn("[ZR] car exit " .. tostring(e.id) .. " has no car: " .. tostring(err))
				end
			end
		end
	end
	return n
end

function Extract.tick()
	local t = workspace:GetServerTimeNow()
	local okCar, errCar = pcall(Extract.carTick, t)
	if not okCar then
		warn("[ZR] car tick", errCar)
	end
	for player, s in ctx.Raid.sessions() do
		if not s.done and (s.state == "ACTIVE" or s.state == "EXTRACTING") then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local zone = nil
			if hum and hum.Health > 0 and root then
				for _, id in s.extracts do
					local e = ctx.World.extracts[id]
					if e and Extract.inside(e, root.Position) then
						zone = id
						break
					end
				end
			end
			if s.state == "ACTIVE" then
				if zone then
					local e = ctx.World.extracts[zone]
					if Extract.isCar(e) then
						-- a car has no hold: the fare is paid at the car, so the zone only says what to do (once per visit and reason)
						local why, text = Extract.blocked(player, s, e)
						local key = why and (zone .. "/" .. why) or nil
						if why and s.exDenied ~= key then
							s.exDenied = key
							ctx.Remotes.note(player, "extract", { state = "denied", zone = zone, reason = why, text = text, car = true })
						elseif not why then
							s.exDenied = nil
						end
					else
						local why, text = Extract.blocked(player, s, e)
						if why then
							if s.exDenied ~= zone then
								s.exDenied = zone
								ctx.Remotes.note(player, "extract", { state = "denied", zone = zone, reason = why, text = text })
							end
						else
							-- each exit's own timer, as in Tarkov (the shelter 3 s, the fence gap 10 s), else the standard 8 s
							local hold = (e.rule and tonumber(e.rule.time)) or Config.EXTRACT_HOLD
							s.state = "EXTRACTING"
							s.exZone = zone
							s.exEnds = t + hold
							ctx.Remotes.note(player, "extract", { state = "start", zone = zone, name = e.name, ends = s.exEnds, total = hold, cost = e.rule.kind == "paid" and e.rule.cost or nil })
						end
					end
				else
					s.exDenied = nil
				end
			elseif s.state == "EXTRACTING" then
				local whyHold, textHold = nil, nil
				if zone == s.exZone then
					whyHold, textHold = Extract.holdBlocked(s, ctx.World.extracts[zone])
				end
				if zone ~= s.exZone then
					s.state = "ACTIVE"
					s.exZone = nil
					s.exEnds = nil
					ctx.Remotes.note(player, "extract", { state = "cancel" })
				elseif whyHold then
					s.state = "ACTIVE"
					s.exZone = nil
					s.exEnds = nil
					s.exDenied = zone
					ctx.Remotes.note(player, "extract", { state = "denied", zone = zone, reason = whyHold, text = textHold })
				elseif t >= s.exEnds then
					if not complete(player, s, ctx.World.extracts[zone]) then
						s.state = "ACTIVE"
						s.exZone = nil
						s.exEnds = nil
						s.exDenied = zone
						ctx.Remotes.note(player, "extract", { state = "denied", zone = zone, reason = "MONEY", text = "NOT ENOUGH MONEY" })
					end
				end
			end
		end
	end
end

function Extract.start()
	local okCars, nCars = pcall(Extract.buildCars)
	if okCars then
		print("[ZR] car exits: " .. tostring(nCars) .. " car(s) built")
	else
		warn("[ZR] car exits", nCars)
	end
	task.spawn(function()
		local n = 0
		while true do
			task.wait(0.2)
			local ok, err = pcall(Extract.tick)
			if not ok then
				warn("[ZR] extract tick", err)
			end
			n += 1
			if n % 5 == 0 then
				local okS, errS = pcall(Extract.signalTick, workspace:GetServerTimeNow())
				if not okS then
					warn("[ZR] exit signal", errS)
				end
			end
		end
	end)
end

return Extract
