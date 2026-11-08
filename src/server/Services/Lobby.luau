--!nonstrict
-- Relay 7 lobby (L4): the stations' shared screens, written once a second for everyone in the bunker: the
-- departure board (the server's one shared raid), the roster whiteboard (everyone on the server, their squad colour,
-- where they are), the four map sheets on the ops table (votes for the next raid) and the callsign card on each
-- player's locker. Per-player things (your pigeonhole lamp, your hideout levels, the gun in the vise, your pinned
-- tasks) are drawn by each client (Lobby controller). Nothing here changes a rule; it only shows Match and Raid state.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Maps = require(Shared.Maps)
local RigSpec = require(Shared.RigSpec)
local Inv = require(script.Parent.Inv)

local Lobby = {}
local ctx
local screens = nil -- found once the bunker is built
local departed = nil -- the raid start the van last left for
local last = {} -- [TextLabel] = text last written (only changes replicate)

local function now()
	return workspace:GetServerTimeNow()
end
local function mmss(t)
	t = math.max(0, math.floor(t))
	return string.format("%02d:%02d", t // 60, t % 60)
end
-- one departure-board row: exactly 24 characters, `left` from the start and `right` against the end
function Lobby.row(left, right)
	left, right = string.upper(left or ""), string.upper(right or "")
	if #right > 24 then
		right = string.sub(right, 1, 24)
	end
	if #left + #right > 23 then
		left = string.sub(left, 1, math.max(0, 23 - #right))
	end
	return left .. string.rep(" ", 24 - #left - #right) .. right
end
local row = Lobby.row

local function set(t, text)
	if t and last[t] ~= text then
		last[t] = text
		t.Text = text
	end
end

-- the four rows of the departure board for the current Match state
function Lobby.departure(st, t)
	local M = ctx.Match
	if st.state == "RUNNING" then
		local pmc = (t <= M.lateUntil) and ("OPEN " .. mmss(M.lateUntil - t)) or "CLOSED"
		local scavUntil = M.endsAt - Config.SCAV_CUTOFF
		local scav = (t <= scavUntil) and ("OPEN " .. mmss(scavUntil - t)) or "CLOSED"
		return {
			row(Maps.nameOf(M.map), "LIVE " .. mmss(M.endsAt - t)),
			row("PMC ENTRY", pmc),
			row("INSIDE", ("%d/%d"):format(st.inRaid or 0, Config.MAX_PLAYERS)),
			row("SCAV ENTRY", scav),
		}
	elseif st.state == "MATCHING" then
		local best, bestN = nil, 0
		for id, n in st.votes or {} do
			if n > bestN then
				best, bestN = id, n
			end
		end
		local w = M.nextEnv and M.nextEnv.w
		return {
			row("MATCHING", mmss(M.startsAt - t)),
			row("VOTE", best and (Maps.nameOf(best) .. " " .. bestN) or "ANY MAP"),
			row("QUEUED", tostring(st.inQueue or 0)),
			row("CONDITIONS", w and string.upper(tostring(w)) or "-"),
		}
	end
	return {
		row("NO RAID", "RELAY 7"),
		row("NEXT RAID", "BOARD THE VAN"),
		row("QUEUED", tostring(st.inQueue or 0)),
		row("SCAVS", "MANHOLE"),
	}
end

-- where a player is, as the roster shows it
function Lobby.whereIs(p)
	local s = ctx.Raid.session(p)
	if s and not s.done then
		return s.scav and "SCAV RAID" or "IN RAID"
	end
	if ctx.Match.isQueued(p) then
		return "QUEUED"
	end
	return "BUNKER"
end

local function find()
	local sh = ctx.World.safehouse
	local m = sh and sh.model
	if not m then
		return nil
	end
	local out = { cards = {}, sheets = {} }
	local dep = m:FindFirstChild("DepartureScreen", true)
	out.dep = dep and dep:FindFirstChild("Gui")
	local ros = m:FindFirstChild("RosterScreen", true)
	out.roster = ros and ros:FindFirstChild("Gui")
	for i = 1, 4 do
		local s = m:FindFirstChild("MapSheet" .. i, true)
		out.sheets[i] = s and s:FindFirstChild("Gui")
	end
	for k = 1, 12 do
		local c = m:FindFirstChild("Card" .. k, true)
		local g = c and c:FindFirstChild("Gui")
		out.cards[k] = g and g:FindFirstChild("Name", true)
	end
	local v = m:FindFirstChild("VanScreen", true)
	local vg = v and v:FindFirstChild("Gui")
	if vg then
		out.van = { State = vg:FindFirstChild("State", true), Clock = vg:FindFirstChild("Clock", true), Info = vg:FindFirstChild("Info", true) }
	end
	return out
end

local SHEETS = { "quay7", "smelter", "meridian", "border" } -- the fourth sheet: the next map (not in rotation yet)
local function update()
	screens = screens or find()
	if not screens then
		return
	end
	local t = now()
	local st = ctx.Match.status(nil)
	-- departure board
	if screens.dep then
		for r, text in Lobby.departure(st, t) do
			for c = 1, 24 do
				set(screens.dep:FindFirstChild(("R%dC%d"):format(r, c)), string.sub(text, c, c))
			end
		end
	end
	-- roster: squads together, then by name
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		local sa, sb = ctx.Match.squadOf(a), ctx.Match.squadOf(b)
		local ka, kb = sa and sa.id or "~", sb and sb.id or "~"
		if ka ~= kb then
			return tostring(ka) < tostring(kb)
		end
		return a.DisplayName < b.DisplayName
	end)
	if screens.roster then
		set(screens.roster:FindFirstChild("Count"), ("%d/%d ON SERVER"):format(#list, Config.MAX_PLAYERS))
		for i = 1, 12 do
			local p = list[i]
			local text = ""
			if p then
				local sq = ctx.Match.squadOf(p)
				local dot = sq and ('<font color="#%s">●</font> '):format(sq.color) or "○ "
				text = dot .. string.sub(string.upper(p.DisplayName), 1, 14) .. ' <font color="#7A2A24">' .. Lobby.whereIs(p) .. "</font>"
			end
			set(screens.roster:FindFirstChild("Row" .. i), text)
		end
	end
	-- map sheets: votes for the next raid, the raid running now
	for i, id in SHEETS do
		local g = screens.sheets[i]
		if g then
			local def = Maps.defs[id]
			if def then
				local n = (st.votes or {})[id] or 0
				set(g:FindFirstChild("Name"), def.name)
				set(g:FindFirstChild("Kind"), def.kind)
				set(g:FindFirstChild("Votes"), n > 0 and (string.rep("● ", math.min(n, 6)) .. (n == 1 and "1 VOTE" or n .. " VOTES")) or "NO VOTES")
				set(g:FindFirstChild("State"), (st.state == "RUNNING" and ctx.Match.map == id) and "RAID LIVE NOW" or "IN ROTATION")
			else
				set(g:FindFirstChild("Name"), "BORDER YARD")
				set(g:FindFirstChild("Kind"), "CHECKPOINT")
				set(g:FindFirstChild("Votes"), "")
				set(g:FindFirstChild("State"), "SURVEY ONLY · NOT IN ROTATION")
			end
		end
	end
	-- the van's dashboard (the matching countdown) and its departure: the doors slam a moment before the raid starts
	local M = ctx.Match
	if screens.van then
		local v = screens.van
		if st.state == "MATCHING" then
			set(v.State, "MATCHING")
			set(v.Clock, mmss(M.startsAt - t))
			set(v.Info, ("QUEUED %d"):format(st.inQueue or 0))
		elseif st.state == "RUNNING" then
			local open = t <= M.lateUntil
			set(v.State, open and "RAID LIVE" or "RAID SEALED")
			set(v.Clock, mmss((open and M.lateUntil or M.endsAt) - t))
			set(v.Info, open and "PMC ENTRY OPEN" or "NEXT RAID AFTER")
		else
			set(v.State, "STANDBY")
			set(v.Clock, "--:--")
			set(v.Info, "BOARD TO QUEUE")
		end
	end
	if st.state == "MATCHING" and M.startsAt - t <= 1.9 and departed ~= M.startsAt then
		departed = M.startsAt
		ctx.Remotes.fxReliable("van", { s = "go" })
	end
	-- callsigns on the lockers
	local owner = {}
	for _, p in list do
		local k = ctx.Raid.bedOf(p)
		if k then
			owner[k] = p
		end
	end
	for k = 1, 12 do
		local p = owner[k]
		set(screens.cards[k], p and string.sub(string.upper(p.DisplayName), 1, 12) or "")
	end
end
Lobby.update = update

-- ── the traders at work (lobby L7) ──────────────────────────────────────────────────────────────────────
-- Block-body NPCs in their own clothes and kit behind the counters (Relay7.TRADERS places them; the Fence by the
-- back door). They turn to the nearest customer and now and then do something with their hands; the trade screens
-- open from the counters.
local TRADERS = {
	{ id = "vos", act = "check", gear = { head = "CAP_FIELD", rig = "RIG_CHEST", ears = "HEADSET_COMM" } },
	{ id = "hale", act = "heal", gear = { head = "BEANIE", rig = "RIG_BELT" } },
	{ id = "tilda", act = "check", gear = { armor = "ARMOR_C4", ears = "HEADSET_GS1" } },
	{ id = "dekker", act = "check", gear = { armor = "ARMOR_C2", eyes = "GLASSES_BG1" } },
	{ id = "kovac", act = "check", gear = { eyes = "GLASSES_RANGE", rig = "RIG_BELT" } },
	{ id = "rook", act = "check", gear = { eyes = "GLASSES_SUN" } },
	{ id = "bram", act = "check", gear = { head = "CAP_FIELD", back = "CANVAS_BAG" } },
	{ id = "fence", x = 127.4, z = 32.4, face = 250, act = "check", gear = { face = "GAITER", back = "BAG_SLING" } },
}
local traders = {}
local function yawOf(deg)
	-- plan facing (clockwise from north) -> root yaw (Roblox: Angles(0, y, 0) looks along (-sin y, 0, -cos y))
	return -math.rad(deg)
end
function Lobby.spawnTraders()
	local R7 = ctx.World.Relay7
	if not R7 then
		return
	end
	local folder = workspace:FindFirstChild("ZR_Traders")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "ZR_Traders"
	folder.Parent = workspace
	local spots = {}
	for _, c in R7.TRADERS or {} do
		local _, _, _, _, x, z, face = R7.counter(c)
		spots[c.id] = { x = x, z = z, face = face }
	end
	for _, t in TRADERS do
		local s = spots[t.id] or t
		local rig = ctx.Chars.buildRig(t.id)
		rig.Name = "Trader_" .. t.id
		rig.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local hum = rig:FindFirstChildOfClass("Humanoid")
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		local root = rig.HumanoidRootPart
		root.Anchored = true
		local home = CFrame.new(R7.P(s.x, RigSpec.hrp.center.Y, s.z)) * CFrame.Angles(0, yawOf(s.face), 0)
		rig:PivotTo(home)
		rig.Parent = folder
		local holder = { items = {}, slots = {} }
		for slot, id in t.gear do
			local g, it = Inv.newItem(id, 1)
			holder.items[g] = it
			holder.slots[slot] = g
		end
		pcall(ctx.Appearance.apply, rig, { look = t.id, holder = holder })
		table.insert(traders, { rig = rig, root = root, home = home, yaw = yawOf(s.face), face = yawOf(s.face), act = t.act, nextAct = os.clock() + 6 + math.random() * 10 })
	end
end
local function stepTraders()
	local t = os.clock()
	for _, tr in traders do
		if tr.rig.Parent then
			local pos = tr.root.Position
			local best, bestD = nil, 14
			for _, p in Players:GetPlayers() do
				local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if r then
					local d = (r.Position - pos).Magnitude
					if d < bestD then
						best, bestD = r, d
					end
				end
			end
			local want = tr.face
			if best then
				local v = best.Position - pos
				want = math.atan2(-v.X, -v.Z)
			end
			local dy = ((want - tr.yaw + math.pi) % (2 * math.pi)) - math.pi
			tr.yaw += math.clamp(dy * 0.25, -0.3, 0.3)
			if math.abs(dy) > 0.01 then
				tr.root.CFrame = CFrame.new(pos) * CFrame.Angles(0, tr.yaw, 0)
			end
			if t >= tr.nextAct then
				tr.nextAct = t + 10 + math.random() * 14
				ctx.Chars.gesture(tr.rig, tr.act, 2.4)
			end
		end
	end
end

function Lobby.init(c)
	ctx = c
end

function Lobby.start()
	local ok, err = pcall(Lobby.spawnTraders)
	if not ok then
		warn("[ZR] lobby traders", err)
	end
	task.spawn(function()
		while true do
			pcall(stepTraders)
			task.wait(0.25)
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(update)
			if not ok then
				warn("[ZR] lobby screens", err)
			end
			task.wait(1)
		end
	end)
end

return Lobby
