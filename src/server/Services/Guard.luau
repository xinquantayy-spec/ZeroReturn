--!nonstrict
-- Movement guard (M15): the client owns its character's physics, so the server samples every player four times a
-- second and pulls back moves no legal input explains (speed and teleport cheats). The limits leave room for
-- sprinting, vaulting, ledge drops and blasts: horizontal speed may reach 1.6x the character's walk speed plus 8
-- studs/s (plus 3 studs of slack per sample), climbing 28 studs/s plus 4 studs; falls are free. Two violations within
-- three seconds snap the character back to its last good spot. Server teleports (spawns, dev tools) set the
-- character's "TP" attribute, which resets the baseline; seated, dead and ragdolled characters are skipped.
local Players = game:GetService("Players")

local Guard = {}
local ctx
local state = {} -- [player] = { char, pos, t, tp, good, strikes, lastStrike }
Guard.STEP = 0.25
Guard.log = {} -- the last pulls (tests and QA)

-- the furthest a character may legally travel in dt seconds at this walk speed: horizontal, upward
function Guard.limits(walkSpeed, dt)
	return (math.max(walkSpeed or 16, 16) * 1.6 + 8) * dt + 3, 28 * dt + 4
end

local function reset(st, char, hrp, now)
	st.char, st.pos, st.t, st.tp = char, hrp.Position, now, char:GetAttribute("TP")
	st.good, st.strikes = hrp.CFrame, 0
end

function Guard.sample(player, now)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then
		state[player] = nil
		return
	end
	local st = state[player]
	if not st then
		st = {}
		state[player] = st
		reset(st, char, hrp, now)
		return
	end
	if st.char ~= char or st.tp ~= char:GetAttribute("TP") or hum.Health <= 0 or hum.SeatPart or char:GetAttribute("Ragdoll") then
		reset(st, char, hrp, now)
		return
	end
	local dt = math.max(now - st.t, 1 / 60)
	local d = hrp.Position - st.pos
	local maxH, maxUp = Guard.limits(hum.WalkSpeed, dt)
	local horiz = Vector3.new(d.X, 0, d.Z).Magnitude
	if horiz > maxH or d.Y > maxUp then
		st.strikes = (now - (st.lastStrike or 0) < 3) and st.strikes + 1 or 1
		st.lastStrike = now
		if st.strikes >= 2 then
			hrp.CFrame = st.good
			hrp.AssemblyLinearVelocity = Vector3.zero
			char:SetAttribute("TP", now)
			ctx.Remotes.strike(player, string.format("moved %.0f studs in %.2fs", math.max(horiz, d.Y), dt))
			table.insert(Guard.log, { player = player.Name, dist = math.max(horiz, d.Y), t = now })
			if #Guard.log > 20 then
				table.remove(Guard.log, 1)
			end
			reset(st, char, hrp, now)
			return
		end
	else
		st.good = hrp.CFrame
	end
	st.pos, st.t = hrp.Position, now
end

function Guard.init(c)
	ctx = c
	Players.PlayerRemoving:Connect(function(p)
		state[p] = nil
	end)
end

function Guard.start()
	task.spawn(function()
		while true do
			task.wait(Guard.STEP)
			local now = os.clock()
			for _, p in Players:GetPlayers() do
				local ok, err = pcall(Guard.sample, p, now)
				if not ok then
					warn("[ZR] guard:", err)
				end
			end
		end
	end)
end

return Guard
