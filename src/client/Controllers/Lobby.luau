--!nonstrict
-- Relay 7 lobby, your side (L4). What in the bunker is yours is drawn only on your screen:
--   * the mirror: a slow orbit round your character in the kit you would deploy with (move to step away);
--   * your gun clamped in the gunsmith's vise, built from its Blender parts as it is now, and your other guns
--     standing in the racks on the gunsmith's wall;
--   * your pigeonhole lamp (lit while insurance returns are on their way or waiting);
--   * your hideout: the wing's lights run off your generator, the racks fill with your storage level, a finished
--     craft waits on the workbench, and each module's label reads your level;
--   * your active tasks pinned on the ops room's cork board;
--   * the firing range: in a booth your gun comes up with practice ammo; steel falls back and paper keeps holes;
--   * the van (board to queue, step out to cancel, doors slam and the screen fades at departure) and the scav
--     hatch with your cooldown on its sign;
--   * a flickering tube here and there.
-- The shared screens (departure board, roster, map sheets, locker callsigns) are the server's (Lobby service).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local GunBuild = require(Shared.GunBuild)
local WP = require(Shared.WeaponParts)
local Items = require(Shared.Items)
local QD = require(Shared.QuestData)
local TD = require(Shared.TraderData)
local HD = require(Shared.HideoutData)

local Lobby = {}
local ctx
local me = Players.LocalPlayer
local localRoot -- client-only models (the vise gun, the racked guns)

local function bunker()
	local w = workspace:FindFirstChild("ZR_World")
	return w and w:FindFirstChild("Relay7")
end
local function holder(name)
	if not localRoot or not localRoot.Parent then
		localRoot = Instance.new("Folder")
		localRoot.Name = "ZR_LobbyLocal"
		localRoot.Parent = workspace
	end
	local m = localRoot:FindFirstChild(name)
	if not m then
		m = Instance.new("Model")
		m.Name = name
		m.Parent = localRoot
	end
	return m
end
local function serverNow()
	local d = ctx.State.data
	return d and d.serverTime and (d.serverTime + (os.clock() - (ctx.State.dataClock or os.clock()))) or os.time()
end

-- ── the mirror ───────────────────────────────────────────────────────────────────────────────────────────
local mirrorConn
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
function Lobby.leaveMirror()
	if mirrorConn then
		mirrorConn:Disconnect()
		mirrorConn = nil
	end
	ctx.Camera.orbit = nil
end
function Lobby.mirror()
	if ctx.Camera.orbit then
		Lobby.leaveMirror()
		return
	end
	local char = me.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	-- turn round to face the room (away from the mirror), the camera swings out in front of you
	local b = bunker()
	local m = b and b:FindFirstChild("Mirror", true)
	if m and m:IsA("BasePart") then
		local d = root.Position - m.Position
		d = Vector3.new(d.X, 0, d.Z)
		if d.Magnitude > 0.1 then
			ctx.Camera.yaw = math.atan2(-d.X, -d.Z)
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, ctx.Camera.yaw, 0)
		end
	end
	local orbit = { dist = 6.2, yaw = math.pi, pitch = -0.1, h = 0.9 }
	ctx.Camera.orbit = orbit
	rayParams.FilterDescendantsInstances = { char }
	local t0 = os.clock()
	ctx.State.toast("MIRROR  ·  MOVE TO STEP AWAY")
	mirrorConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		orbit.yaw = math.pi + math.sin(t * 0.32) * 1.0
		-- keep the camera in the room
		local r = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
		if r then
			local centre = r.Position + Vector3.new(0, orbit.h, 0)
			local cf = CFrame.new(centre) * CFrame.Angles(0, ctx.Camera.yaw + orbit.yaw, 0) * CFrame.Angles(orbit.pitch, 0, 0)
			local dir = cf:VectorToWorldSpace(Vector3.new(0, 0, 1))
			local hit = workspace:Raycast(centre, dir * 6.6, rayParams)
			orbit.dist = hit and math.max(1.8, hit.Distance - 0.4) or 6.2
		end
		local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
		if (t > 0.6 and (not hum or hum.MoveDirection.Magnitude > 0.1 or hum.Jump)) or t > 45 or ctx.State.inRaid() then
			Lobby.leaveMirror()
		end
	end)
end

-- ── guns: the vise and the racks ───────────────────────────────────────────────────────────────────────
local function buildKey(items, g)
	local parts = { g }
	for _, e in WP.layout(items, g) do
		table.insert(parts, e.id)
	end
	return table.concat(parts, ",")
end
-- the gun's meshes placed so that `place(lo, hi)` (its box in the gun's own frame) gives the gun origin's frame
local SCALE = 1.35 -- guns in the world are drawn at the third-person scale (WeaponModels.TP_SCALE)
local function gunAt(items, g, frameFor)
	local parts = GunBuild.pieces(items, g, CFrame.new(), SCALE)
	if not parts then
		return nil
	end
	local lo, hi = GunBuild.bounds(parts)
	local origin = frameFor(lo, hi)
	for _, p in parts do
		p.CFrame = origin * p.CFrame
	end
	return parts
end
local viseKey, rackKey
local function updateGuns(refs)
	local d = ctx.State.data
	if not (d and d.items and d.slots) then
		return
	end
	local viseCF = refs:GetAttribute("ViseCF")
	-- the vise: your primary (or the next gun you carry), across the vise, muzzle toward the wall
	local g = d.slots.primary or d.slots.secondary or d.slots.holster
	local key = (g and d.items[g]) and buildKey(d.items, g) or "-"
	if viseCF and key ~= viseKey then
		local m = holder("Vise")
		m:ClearAllChildren()
		viseKey = key
		if key ~= "-" then
			-- along the bench, its right side toward you and the muzzle to your right, clamped by the magwell
			-- between the vise jaws (the receiver resting on them); a gun without a magwell lies on the bench mat
			local frame = viseCF * CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.yAxis)
			local root = d.items[g]
			local pm = root and WP.META.parts[root.id]
			local well = pm and pm.slots and pm.slots.mag
			local parts = gunAt(d.items, g, function(lo, hi)
				local mid = (lo + hi) / 2
				if well then
					local w = well.Position * SCALE
					return frame * CFrame.new(-w.X, 0.2 - w.Y, -w.Z)
				end
				return frame * CFrame.new(-mid.X, -0.7 - lo.Y, -mid.Z) * CFrame.new(0, 0, 0)
			end)
			if parts then
				for _, p in parts do
					p.Parent = m
				end
			else
				viseKey = nil -- meshes still loading: try again on the next pass
			end
		end
	end
	-- the racks: the guns lying in your stash, standing muzzle up, their right side toward the room
	local guns = {}
	for cg in (d.grids and d.grids.stash) or {} do
		local it = d.items[cg]
		local def = it and Items.defs[it.id]
		if def and def.weapon and def.kind ~= "melee" and cg ~= g then
			table.insert(guns, cg)
		end
	end
	table.sort(guns)
	local keys = {}
	for i = 1, math.min(#guns, 10) do
		keys[i] = buildKey(d.items, guns[i])
	end
	local rk = table.concat(keys, "|")
	if rk ~= rackKey then
		local m = holder("Racks")
		m:ClearAllChildren()
		rackKey = rk
		for i = 1, math.min(#guns, 10) do
			local rack = refs:GetAttribute(i <= 5 and "Rack1" or "Rack2")
			if rack then
				local slot = (i - 1) % 5
				local slotCF = rack * CFrame.new(3.8 - slot * 1.9, 0, -0.3) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(90), 0, 0)
				local parts = gunAt(d.items, guns[i], function(lo, hi)
					local mid = (lo + hi) / 2
					return slotCF * CFrame.new(-mid.X, -mid.Y, -mid.Z) -- the gun's box centred on the slot
				end)
				if parts then
					-- lift so the lowest point sits on the ledge
					local blo = GunBuild.bounds(parts, rack)
					local up = 0.45 - blo.Y
					for _, p in parts do
						p.CFrame = p.CFrame + rack.UpVector * up
						p.Parent = m
					end
				else
					rackKey = nil
				end
			end
		end
	end
end

-- ── your pigeonhole ───────────────────────────────────────────────────────────────────────────────────
local mailLight
local function updateMail(b)
	local d = ctx.State.data
	local bed = me:GetAttribute("Bed")
	local lamps = b:FindFirstChild("MailLamps", true)
	if not lamps then
		return
	end
	local c = d and d.claims or {}
	local ready, waiting = (c.ready or 0) > 0, (c.waiting or 0) > 0
	for _, l in lamps:GetChildren() do
		if l:IsA("BasePart") then
			local mine = l:GetAttribute("Bed") == bed
			local on = mine and (ready or (waiting and (os.clock() % 2 < 1.2)))
			l.Transparency = on and 0 or 1
			if mine then
				if not mailLight or mailLight.Parent ~= l then
					if mailLight then
						mailLight:Destroy()
					end
					mailLight = Instance.new("PointLight")
					mailLight.Color = Color3.fromHex("FFB24A")
					mailLight.Range = 4
					mailLight.Brightness = 1.2
					mailLight.Parent = l
				end
				mailLight.Enabled = on
			end
		end
	end
end

-- ── your hideout ──────────────────────────────────────────────────────────────────────────────────────
local function setGlow(model, on)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("KitMat") == "glow" then
			if p:GetAttribute("GlowColor") == nil then
				p:SetAttribute("GlowColor", p.Color)
			end
			p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			p.Color = on and p:GetAttribute("GlowColor") or Color3.fromRGB(70, 72, 70)
		elseif p:IsA("Light") then
			p.Enabled = on
		end
	end
end
local function showModel(model, on)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "KitCollider" then
			p.LocalTransparencyModifier = on and 0 or 1
		end
	end
end
local function updateHideout(b)
	local d = ctx.State.data
	local h = d and d.hideout
	local wing = b:FindFirstChild("Hideout", true)
	if not (h and wing) then
		return
	end
	local lv = h.levels or {}
	local power = (lv.generator or 0) >= 1
	local t = serverNow()
	for _, m in wing:GetChildren() do
		if m:IsA("Model") then
			if m:GetAttribute("Powered") then
				setGlow(m, power)
			end
			local rack = m:GetAttribute("Rack")
			if rack then
				local full = rack <= math.min(3, 1 + (lv.storage or 0))
				showModel(m, (m:GetAttribute("Full") == true) == full)
			end
			local craft = m:GetAttribute("CraftReady")
			if craft then
				local c = h.crafts and h.crafts[craft]
				showModel(m, c ~= nil and (c.at or math.huge) <= t)
			end
		elseif m.Name == "GenLamp" then
			m.Color = power and Color3.fromHex("4FD06A") or Color3.fromHex("8A2A20")
		elseif m.Name == "Stencil" and m:GetAttribute("Module") then
			local id = m:GetAttribute("Module")
			local def = HD.modules[id]
			local tl = m:FindFirstChildWhichIsA("TextLabel", true)
			if def and tl then
				local n = lv[id] or 0
				local text = "YOUR " .. def.name .. (n > 0 and ("  ·  LV " .. n) or "  ·  NOT BUILT")
				if h.build and h.build.m == id then
					text = "YOUR " .. def.name .. "  ·  BUILDING LV " .. (h.build.l or n + 1)
				end
				tl.Text = text
			end
		end
	end
end

-- ── your tasks on the cork board ───────────────────────────────────────────────────────────────────────
local taskKey
local function updateTasks(b)
	local d = ctx.State.data
	local scr = b:FindFirstChild("TaskScreen", true)
	local gui = scr and scr:FindFirstChild("Gui")
	if not (d and d.quests and gui) then
		return
	end
	local cards = {}
	for _, q in QD.list do
		local s = d.quests[q.id]
		if s and s.s == "active" then
			local prog = {}
			for i, o in q.obj do
				table.insert(prog, ("%d/%d"):format(math.min((s.p and s.p[i]) or 0, o.n or 1), o.n or 1))
			end
			table.insert(cards, { trader = (TD.defs[q.trader] and TD.defs[q.trader].name) or "", name = q.name, prog = table.concat(prog, "  ") })
		end
	end
	local key = ""
	for _, c in cards do
		key ..= c.name .. c.prog
	end
	if key == taskKey then
		return
	end
	taskKey = key
	gui:ClearAllChildren()
	local font = Font.fromEnum(Enum.Font.SpecialElite)
	if #cards == 0 then
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.6, 0.2)
		t.Position = UDim2.fromScale(0.2, 0.4)
		t.Text = "NO ACTIVE TASKS"
		t.TextScaled = true
		t.FontFace = font
		t.TextColor3 = Color3.fromHex("3A2E22")
		t.Parent = gui
		return
	end
	for i = 1, math.min(#cards, 6) do
		local c = cards[i]
		local col, row = (i - 1) % 3, (i - 1) // 3
		local f = Instance.new("Frame")
		f.BackgroundColor3 = (i % 2 == 0) and Color3.fromHex("E8DFC4") or Color3.fromHex("F1EBDA")
		f.BorderSizePixel = 0
		f.Size = UDim2.fromScale(0.29, 0.42)
		f.Position = UDim2.fromScale(0.03 + col * 0.33, 0.05 + row * 0.5)
		f.Rotation = ((i * 37) % 7 - 3) * 0.9
		f.Parent = gui
		local pin = Instance.new("Frame")
		pin.BackgroundColor3 = ({ Color3.fromHex("B03A2E"), Color3.fromHex("2E5AA8"), Color3.fromHex("C9A13C") })[i % 3 + 1]
		pin.BorderSizePixel = 0
		pin.Size = UDim2.fromScale(0.07, 0.11)
		pin.Position = UDim2.fromScale(0.465, 0.03)
		pin.Parent = f
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = pin
		for k, line in { { c.trader, 0.18, 0.16 }, { c.name, 0.36, 0.26 }, { c.prog, 0.68, 0.2 } } do
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(0.9, line[3])
			t.Position = UDim2.fromScale(0.05, line[2])
			t.Text = string.upper(line[1])
			t.TextScaled = true
			t.TextWrapped = true
			t.FontFace = font
			t.TextColor3 = k == 3 and Color3.fromHex("7A2A24") or Color3.fromHex("2A2A24")
			t.Parent = f
		end
	end
end

-- ── flickering tubes ───────────────────────────────────────────────────────────────────────────────────
local flickers = {}
local function scanFlicker(b)
	for _, m in b:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("Flicker") and not flickers[m] then
			flickers[m] = { next = os.clock() + math.random() * 3, on = true }
		end
	end
end
local function stepFlicker()
	local t = os.clock()
	for m, f in flickers do
		if not m.Parent then
			flickers[m] = nil
		elseif t >= f.next then
			f.on = not f.on
			-- mostly on; now and then a stutter of quick blinks
			f.next = t + (f.on and (math.random() < 0.3 and 0.05 + math.random() * 0.1 or 1 + math.random() * 4) or 0.04 + math.random() * 0.14)
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") and p:GetAttribute("KitMat") == "glow" then
					p.Transparency = f.on and 0 or 0.85
				elseif p:IsA("Light") then
					p.Enabled = f.on
				end
			end
		end
	end
end

-- ── the firing range ──────────────────────────────────────────────────────────────────────────────────────
-- standing in a booth brings your gun up with practice ammo (Weapon practice mode); the Range service scores it
local function practiceFor(d)
	for _, slot in { "primary", "secondary", "holster" } do
		local g = d.slots and d.slots[slot]
		local it = g and d.items[g]
		local idef = it and Items.defs[it.id]
		if idef and idef.weapon and idef.kind ~= "melee" then
			local cap = idef.capacity
			local mag = it.mag and d.items[it.mag]
			if mag and Items.defs[mag.id] then
				cap = Items.defs[mag.id].capacity
			elseif idef.family and not cap then
				for _, md in Items.defs do
					if md.kind == "mag" and md.family == idef.family then
						cap = math.max(cap or 0, md.capacity or 0)
					end
				end
			end
			return { slot = slot, cap = math.max(1, cap or 30) }
		end
	end
	return nil
end
local inBooth = false
local function stepBooth()
	local W = ctx.Weapon
	if not W or not W.setPractice then
		return
	end
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	local b = bunker()
	local refs = b and b:FindFirstChild("LobbyRefs", true)
	local lane = nil
	if root and refs and not ctx.State.inRaid() then
		for _, z in refs:GetChildren() do
			if z.Name:sub(1, 9) == "BoothZone" then
				local lp = z.CFrame:PointToObjectSpace(root.Position)
				local h = z.Size / 2
				if math.abs(lp.X) <= h.X and math.abs(lp.Z) <= h.Z and math.abs(lp.Y) <= h.Y + 4 then
					lane = z:GetAttribute("Lane")
					break
				end
			end
		end
	end
	local want = lane and ctx.State.data and practiceFor(ctx.State.data) or nil
	W.setPractice(want)
	if (want ~= nil) ~= inBooth then
		inBooth = want ~= nil
		if inBooth then
			ctx.State.toast(("RANGE  ·  LANE %d  ·  PRACTICE AMMO"):format(lane))
		end
	end
end

-- targets: steel falls back on a hit and stands up again, paper keeps the holes until your next string
local holes = {} -- [lane] = { parts }
local falling = {}
local function targetModel(name)
	local b = bunker()
	local r = b and b:FindFirstChild("Range", true)
	return r and r:FindFirstChild(name)
end
local function onRangeFx(kind, data)
	if type(data) ~= "table" then
		return
	end
	if kind == "rangeReset" then
		for _, p in holes[data.lane] or {} do
			p:Destroy()
		end
		holes[data.lane] = {}
		return
	end
	if kind ~= "range" then
		return
	end
	local m = targetModel(data.t)
	if not m then
		return
	end
	if data.k == "paper" and typeof(data.p) == "Vector3" then
		local n = typeof(data.n) == "Vector3" and data.n or Vector3.xAxis
		local h = Instance.new("Part")
		h.Name = "Hole"
		h.Anchored, h.CanCollide, h.CanQuery, h.CanTouch, h.CastShadow = true, false, false, false, false
		h.Size = Vector3.new(0.09, 0.09, 0.02)
		h.Color = Color3.fromRGB(18, 16, 14)
		h.Material = Enum.Material.SmoothPlastic
		h.CFrame = CFrame.lookAt(data.p + n * 0.012, data.p + n)
		h.Parent = holder("Holes")
		local list = holes[data.lane] or {}
		holes[data.lane] = list
		table.insert(list, h)
		if #list > 40 then
			table.remove(list, 1):Destroy()
		end
	elseif data.k == "steel" then
		ctx.Effects.impactSound(data.p, false, Enum.Material.Metal)
		if falling[m] then
			return
		end
		local frame = m:GetAttribute("Frame")
		if not frame then
			return
		end
		local plate = {}
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and p:GetAttribute("KitMat") == "paint" then
				plate[p] = p.CFrame
			end
		end
		falling[m] = true
		local hinge = frame * CFrame.new(0, 2.1, 0)
		local inv = hinge:Inverse()
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			-- knocked back 80 degrees in a quarter second, down for two, back up in half a second
			local a
			if t < 0.25 then
				a = (t / 0.25) ^ 2 * 80
			elseif t < 2.25 then
				a = 80 + math.sin((t - 0.25) * 18) * math.max(0, 6 - (t - 0.25) * 8)
			elseif t < 2.75 then
				a = 80 * (1 - (t - 2.25) / 0.5)
			else
				a = 0
			end
			for p, cf in plate do
				p.CFrame = hinge * CFrame.Angles(math.rad(a), 0, 0) * inv * cf
			end
			if t >= 2.75 then
				conn:Disconnect()
				falling[m] = nil
			end
		end)
	end
end

-- ── the van and the scav hatch ───────────────────────────────────────────────────────────────────────────
-- Boarding the van is the Ready button: you stand in the cargo box, the dashboard counts down, stepping out leaves
-- the queue. At departure the doors slam (everyone sees it: fx "van"), the bodycam starts recording, the screen
-- fades and the server puts you in the raid. With a raid running and PMC entry open you go straight in.
local TweenService = game:GetService("TweenService")
local van = nil -- { since, departing } while you are queued in the van
local fadeGui
local function fade(to, t)
	if not fadeGui then
		fadeGui = Instance.new("ScreenGui")
		fadeGui.Name = "ZR_VanFade"
		fadeGui.DisplayOrder = 50
		fadeGui.IgnoreGuiInset = true
		fadeGui.ResetOnSpawn = false
		local f = Instance.new("Frame")
		f.Name = "Black"
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.new()
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.Parent = fadeGui
		fadeGui.Parent = me:WaitForChild("PlayerGui")
	end
	local tw = TweenService:Create(fadeGui.Black, TweenInfo.new(t or 0.8, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 - to })
	tw:Play()
	return tw
end
local function refsOf()
	local b = bunker()
	return b and b:FindFirstChild("LobbyRefs", true)
end
-- swing both rear doors between open (1) and shut (0) over t seconds
local doorBusy = false
local function swingDoors(closing, t)
	local b = bunker()
	local pool = b and b:FindFirstChild("MotorPool", true)
	if not pool or doorBusy then
		return
	end
	local doors = {}
	for _, m in pool:GetChildren() do
		local hinge, open = m:GetAttribute("Hinge"), m:GetAttribute("OpenYaw")
		if hinge and open then
			local rel = {}
			local cur = m:GetAttribute("ClientYaw") or open
			local base = (hinge * CFrame.Angles(0, math.rad(cur), 0)):Inverse()
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					rel[p] = base * p.CFrame
				end
			end
			table.insert(doors, { m = m, hinge = hinge, from = cur, to = closing and 0 or open, rel = rel })
		end
	end
	doorBusy = true
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.min(1, (os.clock() - t0) / t)
		local e = closing and k * k or 1 - (1 - k) * (1 - k) -- slammed shut, swung open
		for _, d in doors do
			local yaw = d.from + (d.to - d.from) * e
			local cf = d.hinge * CFrame.Angles(0, math.rad(yaw), 0)
			for p, r in d.rel do
				p.CFrame = cf * r
			end
			if k >= 1 then
				d.m:SetAttribute("ClientYaw", d.to)
			end
		end
		if k >= 1 then
			conn:Disconnect()
			doorBusy = false
			if closing and doors[1] then
				ctx.Effects.impactSound(doors[1].hinge.Position, false, Enum.Material.Metal)
			end
		end
	end)
end
local function departure(after)
	if van and van.departing then
		return
	end
	if van then
		van.departing = true
	end
	swingDoors(true, 0.45)
	task.delay(0.45, function()
		ctx.Hud.recording = true -- the recording starts as the doors shut
	end)
	fade(1, 1.1)
	task.delay(1.2, function()
		if after then
			after()
		end
	end)
	-- back in the light once you are inside the raid (or if nothing happened)
	task.delay(6, function()
		fade(0, 0.9)
		ctx.Hud.recording = false
		swingDoors(false, 1.0)
		van = nil
	end)
end
local function intoVan()
	local refs = refsOf()
	local vcf = refs and refs:GetAttribute("VanCF")
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if not (vcf and root) then
		return false
	end
	-- the aisle between the benches, facing the open rear doors
	local hip = root.Position.Y - (vcf.Position.Y)
	local spot = vcf * CFrame.new((math.random() - 0.5) * 1.2, 1.75 + hip, 2.5 + math.random() * 4.5)
	local back = -vcf.LookVector
	root.CFrame = CFrame.lookAt(spot.Position, spot.Position + back)
	ctx.Camera.yaw = math.atan2(-back.X, -back.Z)
	return true
end
local function inVan()
	local refs = refsOf()
	local vcf = refs and refs:GetAttribute("VanCF")
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if not (vcf and root) then
		return false
	end
	local lp = vcf:PointToObjectSpace(root.Position)
	return math.abs(lp.X) < 3.3 and lp.Z > -3.2 and lp.Z < 10.2 and lp.Y > 1.0
end
function Lobby.boardVan()
	local d = ctx.State.data
	if not d or ctx.State.inRaid() or van then
		return
	end
	local m = ctx.State.match
	local now = workspace:GetServerTimeNow()
	local direct = m and m.state == "RUNNING" and now < (m.lateUntil or 0)
	local vote = ctx.Screens.vote and ctx.Screens.vote() or nil
	if not intoVan() then
		return
	end
	van = { since = os.clock() }
	if direct then
		departure(function()
			local res = ctx.State.req("deploy", { rev = d.rev, kind = "pmc", map = vote })
			if not (res and res.ok) then
				ctx.State.toast("DEPLOY FAILED: " .. string.gsub(tostring(res and res.code or "?"), "_", " "), "warn")
			end
		end)
		return
	end
	local res = ctx.State.req("deploy", { rev = d.rev, kind = "pmc", map = vote })
	if res and res.ok and res.data and res.data.status then
		ctx.State.match = res.data.status
		ctx.State.matchClock = os.clock()
		ctx.State.toast("IN THE VAN  ·  STEP OUT TO LEAVE THE QUEUE")
	elseif res and res.ok and res.data and res.data.entered then
		van = nil
	else
		van = nil
		ctx.State.toast("CANNOT BOARD: " .. string.gsub(tostring(res and (res.msg or res.code) or "?"), "_", " "), "warn")
	end
end
local function stepVan()
	if not van or van.departing then
		return
	end
	local m = ctx.State.match
	if ctx.State.inRaid() then
		van = nil
		return
	end
	if not (m and m.queued) and os.clock() - van.since > 3 then
		van = nil -- no longer queued (cancelled from the screen)
		return
	end
	if not inVan() then
		van = nil
		local res = ctx.State.req("queue", { op = "cancel" })
		if res and res.ok and res.data then
			ctx.State.match = res.data
			ctx.State.matchClock = os.clock()
		end
		ctx.State.toast("LEFT THE VAN  ·  QUEUE CANCELLED", "warn")
		return
	end
	if m.state == "MATCHING" and (m.startsAt or 0) - workspace:GetServerTimeNow() <= 1.8 then
		departure(nil)
	end
end
-- the scav hatch: your cooldown on its sign; down the hatch when you are ready
local function updateScavSign(b)
	local sign = b:FindFirstChild("ScavSign", true)
	local gui = sign and sign:FindFirstChild("Gui")
	local d = ctx.State.data
	if not (gui and d) then
		return
	end
	local left = (d.scavReadyAt or 0) - serverNow()
	local t = gui:FindFirstChild("State", true)
	if t then
		t.Text = left > 0 and ("COOLDOWN %02d:%02d"):format(left // 60, left % 60) or "READY"
	end
end
function Lobby.scavHatch()
	local d = ctx.State.data
	if not d or ctx.State.inRaid() then
		return
	end
	local left = (d.scavReadyAt or 0) - serverNow()
	if left > 0 then
		ctx.State.toast(("SCAV READY IN %02d:%02d"):format(left // 60, left % 60), "warn")
		return
	end
	local m = ctx.State.match
	local now = workspace:GetServerTimeNow()
	-- (EFT's window, audit ai-7a: scav entry opens some minutes in on the big maps; before it the run queues)
	local direct = m and m.state == "RUNNING" and now >= (m.scavFrom or 0) and now < (m.scavUntil or 0)
	if direct then
		fade(1, 0.9)
		task.delay(0.95, function()
			local res = ctx.State.req("deploy", { kind = "scav" })
			if not (res and res.ok) then
				ctx.State.toast("SCAV RUN FAILED: " .. string.gsub(tostring(res and (res.msg or res.code) or "?"), "_", " "), "warn")
			end
			task.delay(4, function()
				fade(0, 0.8)
			end)
		end)
		return
	end
	local res = ctx.State.req("deploy", { kind = "scav" })
	if res and res.ok and res.data and res.data.status then
		ctx.State.match = res.data.status
		ctx.State.matchClock = os.clock()
		local st = res.data.status
		local opens = st.state == "RUNNING" and (st.scavFrom or 0) - workspace:GetServerTimeNow() or 0
		ctx.State.toast(opens > 0 and ("SCAV RUN QUEUED  ·  ENTRY OPENS IN %02d:%02d"):format(opens // 60, opens % 60) or "SCAV RUN QUEUED  ·  WAIT BY THE HATCH")
	elseif not (res and res.ok) then
		ctx.State.toast("SCAV RUN FAILED: " .. string.gsub(tostring(res and (res.msg or res.code) or "?"), "_", " "), "warn")
	end
end

-- ── refresh ────────────────────────────────────────────────────────────────────────────────────────────
local function refresh()
	if ctx.State.inRaid() then
		return
	end
	local b = bunker()
	if not b then
		return
	end
	local refs = b:FindFirstChild("LobbyRefs", true)
	if refs then
		local ok, err = pcall(updateGuns, refs)
		if not ok then
			warn("[ZR] lobby guns", err)
		end
	end
	for _, f in { updateMail, updateHideout, updateTasks, scanFlicker, updateScavSign } do
		local ok, err = pcall(f, b)
		if not ok then
			warn("[ZR] lobby", err)
		end
	end
end
Lobby.refresh = refresh

function Lobby.init(c)
	ctx = c
	ctx.State.changed:Connect(function()
		task.defer(refresh)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)
	local boothClock = 0
	RunService.Heartbeat:Connect(function(dt)
		if next(flickers) then
			stepFlicker()
		end
		boothClock += dt
		if boothClock > 0.15 then
			boothClock = 0
			local ok, err = pcall(stepBooth)
			if not ok then
				warn("[ZR] lobby range", err)
			end
			ok, err = pcall(stepVan)
			if not ok then
				warn("[ZR] lobby van", err)
			end
		end
	end)
	if ctx.State.fx then
		ctx.State.fx.OnClientEvent:Connect(function(kind, data)
			if kind == "range" or kind == "rangeReset" then
				onRangeFx(kind, data)
			elseif kind == "van" and type(data) == "table" and data.s == "go" then
				-- the van leaves for the raid: its doors slam for everyone in the bunker, then swing open again
				if not (van and van.departing) then
					swingDoors(true, 0.45)
					task.delay(7, function()
						if not (van and van.departing) then
							swingDoors(false, 1.0)
						end
					end)
				end
			end
		end)
	end
end

return Lobby
