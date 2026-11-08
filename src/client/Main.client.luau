--!nonstrict
-- Zero Return client bootstrap: controllers share one ctx table; explicit init order.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Controllers = script.Parent:WaitForChild("Controllers")
local Items = require(game:GetService("ReplicatedStorage"):WaitForChild("ZR"):WaitForChild("Items"))

local ORDER = { "UiKit", "State", "Settings", "Input", "Effects", "Camera", "Movement", "Weapon", "Grenade", "Animator", "Hud", "Post", "NightVision", "Eyewear", "Atmos", "Ambience", "Detail", "Interact", "Stationary", "Touch", "Inventory", "Character", "QuickSlots", "Modding", "Inspect", "Screens", "Trade", "Menus", "MenuBar", "RaidChat", "Lobby", "LobbyStyle", "Tutorial" }
local ctx = {}
for _, name in ORDER do
	ctx[name] = require(Controllers:WaitForChild(name))
end
for _, name in ORDER do
	local m = ctx[name]
	if m.init then
		local ok, err = pcall(m.init, ctx)
		if not ok then
			warn("[ZR] client init failed:", name, err)
		end
	end
end

task.spawn(function()
	for _ = 1, 30 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

-- Studio-only benchmark (Dev.luau BENCH): hold each viewpoint the server announces, count frames, show the table.
-- Studio slows a test window that is not in front (a steady 15 fps whatever the scene), so each row says whether the window
-- had focus while it counted; only FOCUSED rows are real numbers.
if RunService:IsStudio() then
	local lp = Players.LocalPlayer
	local UIS = game:GetService("UserInputService")
	local Stats = game:GetService("Stats")
	local rows, token, focused = {}, 0, nil
	UIS.WindowFocused:Connect(function()
		focused = true
	end)
	UIS.WindowFocusReleased:Connect(function()
		focused = false
	end)
	local function panel()
		local gui = lp:WaitForChild("PlayerGui"):FindFirstChild("ZR_Bench") or Instance.new("ScreenGui")
		gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "ZR_Bench", false, 50
		local t = gui:FindFirstChild("T") or Instance.new("TextLabel")
		t.Name, t.Size, t.Position = "T", UDim2.fromOffset(620, 210), UDim2.fromOffset(20, 220)
		t.BackgroundTransparency, t.BackgroundColor3, t.TextColor3 = 0.2, Color3.new(0, 0, 0), Color3.fromRGB(230, 220, 170)
		t.Font, t.TextSize, t.TextXAlignment, t.TextYAlignment = Enum.Font.Code, 15, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
		t.Text = "ZR BENCH  ·  keep this window in front (Studio slows background windows)\n" .. table.concat(rows, "\n")
		t.Parent = gui
		gui.Parent = lp.PlayerGui
	end
	lp:GetAttributeChangedSignal("ZR_BenchView"):Connect(function()
		local v = lp:GetAttribute("ZR_BenchView")
		pcall(function()
			RunService:UnbindFromRenderStep("ZR_Bench")
		end)
		if v == "done" then
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			table.insert(rows, "done")
			panel()
			print("[ZR] bench results:\n" .. table.concat(rows, "\n"))
			return
		end
		local i, n, name, a, b = string.match(tostring(v), "^(%d+)|(%d+)|([^|]+)|([^|]+)|([^|]+)$")
		if not i then
			return
		end
		local function vec(t)
			local x, y, z = string.match(t, "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)")
			return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
		end
		local cf = CFrame.lookAt(vec(a), vec(b))
		if ctx.Settings and ctx.Settings.data then
			ctx.Settings.data.autoGfx = false -- the bench measures the chosen level, not the fallback
		end
		RunService:BindToRenderStep("ZR_Bench", Enum.RenderPriority.Last.Value + 5, function()
			local cam = workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = cf
		end)
		token += 1
		local my = token
		task.delay(4, function()
			local dts, away = {}, false
			local c = RunService.RenderStepped:Connect(function(dt)
				dts[#dts + 1] = dt * 1000
				away = away or focused == false
			end)
			task.wait(6)
			c:Disconnect()
			if my ~= token or #dts < 3 then
				return
			end
			local total = 0
			for _, d in dts do
				total += d
			end
			table.sort(dts)
			local k = #dts
			local med, p90 = dts[k // 2], dts[math.floor(k * 0.9)]
			-- a background window runs at a steady ~66.7 ms whatever it draws
			local capped = dts[math.max(1, math.floor(k * 0.1))] > 60 and p90 < 72
			local q = ctx.Settings and ctx.Settings.data and ctx.Settings.data.quality or -1
			table.insert(rows, string.format("%s/%s %-13s %5.1f fps  median %3.0f ms  p90 %3.0f  render %4.1f ms  draws %d+%d  gfx %d%s",
				i, n, name, k / total * 1000, med, p90, Stats.RenderCPUFrameTime * 1000, Stats.SceneDrawcallCount, Stats.ShadowsDrawcallCount, q,
				(away or capped) and "  BACKGROUND" or (focused and "  FOCUSED" or "")))
			panel()
		end)
	end)
end

-- Studio-only client test bridge (driven via MCP execute_luau in the Client datamodel)
if RunService:IsStudio() then
	local bf = Instance.new("BindableFunction")
	bf.Name = "ZR_ClientDev"
	bf.OnInvoke = function(cmd, a, b)
		if cmd == "state" then
			local W, M = ctx.Weapon, ctx.Movement
			local vmModel = workspace.CurrentCamera:FindFirstChild("ZR_Viewmodel")
			return HttpService:JSONEncode({
				phase = ctx.State.data and ctx.State.data.phase, ammo = W.ammo, spare = W.spare, hasWeapon = W.hasWeapon,
				reloading = W.reloading, aiming = W.aiming, crouching = M.crouching, stamina = math.floor(M.stamina),
				weapon = W.weaponName, slot = W.slot, mode = W.modeName, drawing = W.drawing, checking = W.checking,
				light = W.light, deviceMode = W.deviceMode, laserOn = W.deviceState and select(2, W.deviceState()),
				scoped = W.scoped, melee = W.melee, vmParts = vmModel and #vmModel:GetChildren() or 0,
				input = ctx.Input.backend, device = ctx.Input.device(), invOpen = ctx.Inventory.open,
				modal = ctx.Screens.modal and ctx.Screens.modal:FindFirstChildOfClass("TextLabel").Text or nil,
				prompt = ctx.Interact.current and ctx.Interact.current.ObjectText or nil,
				stance = M.stance, lean = M.leanTarget, freeLook = ctx.Input.down("FreeLook"), freeYaw = math.deg(ctx.Camera.freeYaw or 0),
				lastCheck = W.lastCheck, modeCheckedAt = W.modeCheckedAt, now = os.clock(), tray = ctx.Touch.tray and ctx.Touch.tray(),
				gun = W.debugState and W.debugState() or nil, nade = ctx.Grenade and ctx.Grenade.state or nil,
			})
		elseif cmd == "fire" then
			return ctx.Weapon.fireForTest(a or 1)
		elseif cmd == "reload" then
			ctx.Weapon.startReload()
			return "reload requested"
		elseif cmd == "inv" then
			ctx.Inventory.toggle()
			return tostring(ctx.Inventory.open)
		elseif cmd == "deployScreen" then
			ctx.Screens.deploy()
			return "ok"
		elseif cmd == "traders" then
			ctx.Trade.traders(a, b)
			return "ok"
		elseif cmd == "touchDrag" then
			-- ui-4c: a scripted finger lifts the stash item a (an item id) and carries it to cell b = { grid, x, y } (a grid
			-- frame's name, e.g. "Grid_stash"); b.menu = true holds it and lets go in place (the action menu)
			local d = ctx.State.data
			local g
			for sg in (d and d.grids and d.grids.stash) or {} do
				if d.items[sg] and d.items[sg].id == a then
					g = sg
					break
				end
			end
			local pg = game:GetService("Players").LocalPlayer.PlayerGui
			local tile = g and pg:FindFirstChild("Tile_" .. g, true)
			if not tile then
				return "no tile"
			end
			local from = tile.AbsolutePosition + tile.AbsoluteSize / 2
			local to = from
			if type(b) == "table" and b.grid then
				local gf = pg:FindFirstChild(b.grid, true)
				local cell = gf and gf:FindFirstChild(string.format("Cell_%d_%d", b.x or 1, b.y or 1))
				if not cell then
					return "no cell"
				end
				to = cell.AbsolutePosition + cell.AbsoluteSize / 2
			end
			local lifted, rotateShown = ctx.Inventory.touchTest(tile, from, to, type(b) == "table" and b.menu == true)
			return { lifted = lifted, rotate = rotateShown, g = g, from = { from.X, from.Y }, to = { to.X, to.Y } }
		elseif cmd == "inspect" then
			-- a = an equipment slot ("primary") or an item id in the stash: Tarkov's INSPECT window for it
			local d = ctx.State.data
			local g = d and d.slots and d.slots[a]
			if not g and d then
				for sg in (d.grids and d.grids.stash) or {} do
					if d.items[sg] and d.items[sg].id == a then
						g = sg
						break
					end
				end
			end
			if not g then
				return "no item"
			end
			ctx.Inspect.open(d.items, g, { key = "dev:" .. g })
			return "ok"
		elseif cmd == "mount" then
			-- weapon mounting (gameplay-5b): what is under or beside the handguard now, and the mount in effect
			local W = ctx.Weapon
			if a == "on" then
				W.setMount(true)
			elseif a == "off" then
				W.setMount(false)
			end
			return tostring(W.mountSpot()) .. " | mountable " .. tostring(W.mountable()) .. " | mounted " .. tostring(W.mounted and W.mounted.kind) .. " | aiming " .. tostring(W.aiming)
		elseif cmd == "inspectClose" then
			ctx.Inspect.closeAll()
			return "ok"
		elseif cmd == "hideout" then
			ctx.Trade.hideout()
			return "ok"
		elseif cmd == "modding" then
			-- a = the weapon's guid (in the stash or equipped): the M14 modding screen
			ctx.Modding.open(a)
			return "ok"
		elseif cmd == "closeModal" then
			ctx.Screens.close()
			return "ok"
		elseif cmd == "settings" then
			ctx.Screens.settings(a) -- a = a tab name ("CONTROLS") or nil
			return "ok"
		elseif cmd == "pad" then
			-- a = gamepad button name ("DPadUp"), b = seconds held: through the shared-button arbitration (Input.padButton)
			ctx.Input.padButton(a, true)
			task.wait(b or 0.1)
			ctx.Input.padButton(a, false)
			return "ok"
		elseif cmd == "touch" then
			-- a = touch button action (or "tray:<action>"), b = { secs, dx, dy }: a finger held, optionally dragged
			local o = b or {}
			return tostring(ctx.Touch.simulate(a, o[1], (o[2] or o[3]) and Vector2.new(o[2] or 0, o[3] or 0) or nil))
		elseif cmd == "quick" then
			-- a = slot ("4".."0"), b = item kind ("med", "grenade"...): bind the first such item in the pockets or rig
			local d = ctx.State.data
			local rig = d.slots and d.slots.rig
			for _, grid in { d.grids.pockets, rig and d.grids[rig] } do
				for g in grid or {} do
					local it = d.items[g]
					local def = it and Items.defs[it.id]
					if def and def.kind == b then
						ctx.Settings.setQuick(a, g)
						return it.id
					end
				end
			end
			return "none"
		elseif cmd == "stick" then
			-- a = { dx, dy, secs, release, landX, landY }: the touch stick held at that offset (in radii; dy -1.5 runs),
			-- the thumb landing (landX, landY) radii off the stick's centre
			local o = a or {}
			return HttpService:JSONEncode(ctx.Touch.stick(o[1] or 0, o[2] or -1, o[3] or 0.5, o[4], o[5], o[6]))
		elseif cmd == "touchState" then
			return HttpService:JSONEncode(ctx.Touch.state())
		elseif cmd == "touchEdit" then
			-- a = "open", "save" or "cancel"
			if a == "open" then
				ctx.Touch.edit(true)
			else
				ctx.Touch.edit(false, a == "save")
			end
			return "ok"
		elseif cmd == "setting" then
			-- a = key, b = value (as the settings screen would set it; saved with the profile)
			ctx.Settings.set(a, b)
			return tostring(ctx.Settings.data[a])
		elseif cmd == "rejoinSettings" then
			-- the join load replayed: the touch layout forgotten here, a fresh snapshot asked for, the profile's settings
			-- loaded from it the way a new session does (Settings.fromServer); returns what came back
			ctx.Settings.data.touchLayout = nil
			ctx.Settings.apply()
			local clock = ctx.State.dataClock
			ctx.State.req("sync", {})
			local t0 = os.clock()
			while ctx.State.dataClock == clock and os.clock() - t0 < 3 do
				task.wait()
			end
			ctx.Settings.fromServer(ctx.State.data.settings)
			return HttpService:JSONEncode({ layout = ctx.Settings.data.touchLayout or false, fire = { ctx.Touch.rectOf("fire") } })
		elseif cmd == "aim" then
			ctx.Weapon.setAim(a == true)
			return "ok"
		elseif cmd == "switch" then
			ctx.Weapon.switchTo(a)
			return "ok"
		elseif cmd == "cycle" then
			ctx.Weapon.cycleWeapon()
			return "ok"
		elseif cmd == "poseHold" then
			-- a = { kind = "reload" | "mag" | "chamber", p = 0..1, empty?, quick? } holds that moment; nil lets go (art-6a)
			ctx.Weapon.poseHold = a
			if not a then
				ctx.Weapon.reloading, ctx.Weapon.checking = false, false
			end
			return "ok"
		elseif cmd == "magcheck" then
			ctx.Weapon.magCheck()
			return "ok"
		elseif cmd == "light" then
			ctx.Weapon.toggleLight()
			return tostring(ctx.Weapon.light)
		elseif cmd == "invPanel" then
			-- the phone layout's panel: "GEAR" (equipment), "BAGS" or "OTHER" (stash or loot)
			ctx.Inventory.cpanel = a
			if ctx.Inventory.open then
				ctx.Inventory.render()
			end
			return tostring(ctx.Inventory.cpanel)
		elseif cmd == "preview" then
			-- a, b = width and height in points: menus lay out as on a screen that size (the phone layouts, ui-3a);
			-- nil clears it. The panels draw centred at that size inside the Studio window.
			ctx.UiKit.previewSize = (type(a) == "number" and type(b) == "number") and Vector2.new(a, b) or nil
			if ctx.Inventory.open then
				ctx.Inventory.render()
			end
			return tostring(ctx.UiKit.previewSize)
		elseif cmd == "device" then
			-- a = "Gamepad" / "Touch" / nil: what Input.device() answers (the gamepad and touch paths without one)
			ctx.Input.forceDevice = a
			return ctx.Input.device()
		elseif cmd == "press" then
			-- a = { action, ... } pressed together for b seconds (a shared gamepad button sends both of its actions)
			for _, act in a do
				ctx.Input.trigger(act, true)
			end
			task.wait(b or 0.1)
			for _, act in a do
				ctx.Input.trigger(act, false)
			end
			task.wait(0.05)
			return "ok"
		elseif cmd == "look" then
			-- a = a world point: turn the view to it (the camera's yaw and pitch, as the mouse would)
			local d = a - workspace.CurrentCamera.CFrame.Position
			ctx.Camera.yaw = math.atan2(-d.X, -d.Z)
			ctx.Camera.pitch = math.atan2(d.Y, Vector3.new(d.X, 0, d.Z).Magnitude)
			return "ok"
		elseif cmd == "devicemode" then
			-- Ctrl+T: a light/laser combo's mode; returns the mode and what runs (light, laser)
			ctx.Weapon.cycleDeviceMode()
			local l, z = ctx.Weapon.deviceState()
			return string.format("%s light=%s laser=%s", ctx.Weapon.deviceMode, tostring(l), tostring(z))
		elseif cmd == "slash" then
			ctx.Weapon.slash()
			return "ok"
		elseif cmd == "tune" then
			-- a = { key = value, ... } (viewmodel TUNE); rebuilds so sizes/scale apply
			for k, v in a or {} do
				ctx.Weapon.TUNE[k] = v
			end
			ctx.Weapon.rebuild()
			return "ok"
		elseif cmd == "pose" then
			-- a = { kind = "long", name = "hip", cf = CFrame }
			ctx.Weapon.POSE[a.kind][a.name] = a.cf
			return "ok"
		elseif cmd == "stance" then
			-- a = "s" | "c" | "p"
			ctx.Movement.setStance(a)
			return "ok"
		elseif cmd == "lean" then
			ctx.Movement.leanTarget = a or 0
			return "ok"
		elseif cmd == "move" then
			local M = ctx.Movement
			return HttpService:JSONEncode({
				stance = M.stance, depth = M.depth, lean = M.lean, speedStep = M.speedStep, stamina = math.floor(M.stamina), arms = math.floor(M.arms),
				weight = math.floor(M.weight * 10) / 10, vaulting = M.vaulting, busy = M.busy(), breath = M.breath,
				walkSpeed = (game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") or {}).WalkSpeed,
				hip = (game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") or {}).HipHeight,
			})
		elseif cmd == "orbit" then
			-- a = { dist, yaw, pitch, h, target = model name (AI or player) } or nil to return to first person
			if a and a.target then
				local ai = workspace:FindFirstChild("ZR_AI")
				local cp = workspace:FindFirstChild("ZR_Corpses")
				local sr = workspace:FindFirstChild("ZR_Showroom")
				local pl = Players:FindFirstChild(a.target)
				a.model = (ai and ai:FindFirstChild(a.target)) or (cp and cp:FindFirstChild(a.target)) or (sr and sr:FindFirstChild(a.target)) or (pl and pl.Character) or nil
			end
			ctx.Camera.orbit = a
			return "ok"
		elseif cmd == "action" then
			ctx.Input.press(a, b)
			return "ok"
		elseif cmd == "firemode" then
			ctx.Input.trigger("FireMode", true)
			ctx.Input.trigger("FireMode", false)
			return ctx.Weapon.modeName
		elseif cmd == "studio" then
			-- capture mode: no HUD or lens overlays, no post effects, neutral daylight (a = true / false)
			local on = a ~= false
			local Lighting = game:GetService("Lighting")
			ctx.Atmos.frozen, ctx.Post.frozen, ctx.studio = on, on, on
			local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
			for _, g in pg:GetChildren() do
				if g:IsA("ScreenGui") then
					if on then
						if g:GetAttribute("StudioWas") == nil then
							g:SetAttribute("StudioWas", g.Enabled)
						end
						g.Enabled = false
					elseif g:GetAttribute("StudioWas") ~= nil then
						g.Enabled = g:GetAttribute("StudioWas")
						g:SetAttribute("StudioWas", nil)
					end
				end
			end
			for _, e in Lighting:GetChildren() do
				if e:IsA("PostEffect") then
					e.Enabled = not on
				end
			end
			if on then
				Lighting.ClockTime, Lighting.Brightness, Lighting.ExposureCompensation = 13.5, 2.2, 0
				Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(110, 112, 114), Color3.fromRGB(140, 142, 144)
				Lighting.FogEnd, Lighting.GlobalShadows = 100000, true
				local atm = Lighting:FindFirstChildOfClass("Atmosphere")
				if atm then
					atm.Density, atm.Haze, atm.Glare = 0.05, 0, 0
				end
			else
				ctx.Post.apply()
			end
			return "studio=" .. tostring(on)
		elseif cmd == "look" then
			ctx.Camera.yaw, ctx.Camera.pitch = math.rad(a and a.yaw or 0), math.rad(a and a.pitch or 0)
			return "ok"
		elseif cmd == "nade" then
			-- a = { hold = seconds, under = bool }: press G, hold, release
			return ctx.Grenade.testThrow(a and a.hold, a and a.under)
		elseif cmd == "detail" then
			-- M12 detail layer probe; a = graphics level to switch to (0 POTATO .. 3 HIGH), nil = just report
			if a ~= nil then
				ctx.Settings.set("quality", a)
			end
			local st = ctx.Detail.stats()
			st.shadows = game:GetService("Lighting").GlobalShadows
			local n, variants = 0, 0
			local w = workspace:FindFirstChild("ZR_World")
			for _, d in w and w:GetDescendants() or {} do
				if d:IsA("BasePart") then
					n += 1
					if d.MaterialVariant ~= "" then
						variants += 1
					end
				end
			end
			st.worldParts, st.worldVariants = n, variants
			return HttpService:JSONEncode(st)
		elseif cmd == "hidden" then
			-- first-person hidden set vs the character's parts (C12: no growth with equipment churn)
			local me = Players.LocalPlayer.Character
			local parts = 0
			for _, d in me and me:GetDescendants() or {} do
				if d:IsA("BasePart") then
					parts += 1
				end
			end
			return string.format("hidden=%d parts=%d", ctx.Camera.hiddenCount(), parts)
		elseif cmd == "nadeState" then
			return tostring(ctx.Grenade.state)
		elseif cmd == "nadeTune" then
			-- a = { key = CFrame | number }: first-person grenade hand poses (Grenade.POSE)
			for k, v in a or {} do
				ctx.Grenade.POSE[k] = v
			end
			return "ok"
		elseif cmd == "ambience" then
			-- atmosphere pass: a = true forces a probe first; reports the space class, the reverb, the layers, the dust and the ray count
			return HttpService:JSONEncode(ctx.Ambience.report(a == true))
		elseif cmd == "stationary" then
			-- the mounted gun: a = "leave" gets off it; reports the mode (use "action" with MountFire / MountZoom to drive it)
			local St = ctx.Stationary
			if a == "leave" then
				St.leave()
			end
			return HttpService:JSONEncode({
				mounted = St.mounted, gun = St.name, rounds = St.rounds, belt = St.belt, zooming = St.zooming,
				yawDeg = math.floor(math.deg(St.yaw) * 10 + 0.5) / 10, pitchDeg = math.floor(math.deg(St.pitch) * 10 + 0.5) / 10,
				inputMounted = ctx.Input.isMounted(), fov = math.floor(workspace.CurrentCamera.FieldOfView * 10 + 0.5) / 10,
			})
		end
		return "unknown"
	end
	bf.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")
end
print("[ZR] client ready; input:", ctx.Input.backend)
