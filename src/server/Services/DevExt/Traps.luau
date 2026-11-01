--!nonstrict
-- Studio dev commands for tripwires and THE FORESTER (docs/design/BOSS_FORESTER.md), added to the ZR_Dev bridge by
-- Dev.init. name = a player's name, nil = the first one.
--   ZR_Dev:Invoke("traps")                 the counts and every wire: id, armed, grenade, length, middle
--   ZR_Dev:Invoke("trapLay", n)            lay n more wires along the active map's trap boss loop (no owner)
--   ZR_Dev:Invoke("trapGo", name, i, side, dist)  put the player dist studs (default 4) from wire i on its side 1 or -1,
--                                          facing it
--   ZR_Dev:Invoke("forester")              THE FORESTER this raid: state, hostility to each raider, grudges
--   ZR_Dev:Invoke("karma", name, v)        set a raider's karma (profile and raid session)
local Players = game:GetService("Players")

local function plr(name)
	return (name and Players:FindFirstChild(name)) or Players:GetPlayers()[1]
end

return function(C, ctx)
	function C.traps()
		local T = ctx.Tripwires
		if not T then
			return "no Tripwires service"
		end
		local s = T.stats
		local out = { string.format("placed %d, refused %d (last: %s), triggered %d, disarmed %d, live %d", s.placed, s.refused, tostring(T.lastRefusal), s.triggered, s.disarmed, #T.list) }
		for i, t in T.list do
			table.insert(out, string.format("%d: #%d %s %s len %.1f mid %.1f,%.1f,%.1f", i, t.id, t.armed and "ARMED" or "off", t.item, t.len, t.mid.X, t.mid.Y, t.mid.Z))
		end
		return table.concat(out, "\n")
	end

	function C.trapLay(n)
		local T = ctx.Tripwires
		local m = ctx.World.maps[ctx.World.activeMap]
		for _, b in (m and m.bosses) or {} do
			if b.traps and b.route then
				return "laid " .. tostring(T.layAlong(b.route, n or b.traps, nil))
			end
		end
		return "no trap boss on " .. tostring(ctx.World.activeMap)
	end

	function C.trapGo(name, i, side, dist)
		local t = ctx.Tripwires.list[i or 1]
		if not t then
			return "no wire " .. tostring(i)
		end
		local d = (t.b - t.a) * Vector3.new(1, 0, 1)
		local n = Vector3.new(-d.Z, 0, d.X).Unit
		local spot = t.mid + n * (side or 1) * (dist or 4) + Vector3.new(0, 3, 0)
		return C.place(plr(name).Name, spot, t.mid + Vector3.new(0, 3, 0))
	end

	-- a raider's karma (the Fence standing, Progress.KARMA) for tests: the profile and, in a raid, the session
	function C.karma(name, v)
		local p = plr(name)
		local prof = ctx.Profiles.get(p)
		if prof then
			prof.karma = v
		end
		local s = ctx.Raid.session(p)
		if s then
			s.karma, s.karmaDelta = v, 0
		end
		return "karma " .. tostring(v)
	end

	function C.forester()
		local out = {}
		for _, u in ctx.AI.units or {} do
			if u.karmaHunt then
				table.insert(out, string.format("%s %s alive=%s at %s silent=%s", u.name, u.state, tostring(u.alive), tostring(u.root and u.root.Position), tostring(u.model:GetAttribute("SilentSteps"))))
				for player, s in ctx.Raid.sessions() do
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					local dist = (root and u.root) and (root.Position - u.root.Position).Magnitude or nil
					table.insert(out, string.format("  %s karma %.2f dist %s grudge %s -> %s", player.Name, (s.karma or 0) + (s.karmaDelta or 0), dist and string.format("%.0f", dist) or "-", tostring(u.grudge[player]), tostring(ctx.AI.forestHostile((s.karma or 0) + (s.karmaDelta or 0), u.grudge[player], dist))))
				end
			end
		end
		return #out > 0 and table.concat(out, "\n") or "no FORESTER this raid"
	end
end
