--!nonstrict
-- Studio dev commands for transits (docs/design/TRANSITS.md), added to the ZR_Dev bridge by Dev.init. name = a player's
-- name, nil = the first one.
--   ZR_Dev:Invoke("transits")              every map's transits (id, to, where) and the counts
--   ZR_Dev:Invoke("transitGo", name, id)   put the player in transit id's zone (on its map)
--   ZR_Dev:Invoke("transitStart", name)    what holding the prompt does, for the transit the player stands in
--   ZR_Dev:Invoke("transitState", name)    the session's map, its exits and any countdown
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local function plr(name)
	return (name and Players:FindFirstChild(name)) or Players:GetPlayers()[1]
end

return function(C, ctx)
	local function find(id)
		for mid, m in ctx.World.maps do
			for _, tr in m.transits or {} do
				if tr.id == id then
					return tr, mid
				end
			end
		end
		return nil
	end

	function C.transits()
		local T = ctx.Transit
		if not T then
			return "no Transit service"
		end
		local out = { string.format("started %d, arrived %d, cancelled %d", T.stats.started, T.stats.arrived, T.stats.cancelled) }
		for mid, m in ctx.World.maps do
			for _, tr in m.transits or {} do
				table.insert(out, string.format("%s on %s -> %s at %.0f,%.0f,%.0f", tr.id, mid, tr.to, tr.pos.X, tr.pos.Y, tr.pos.Z))
			end
		end
		return table.concat(out, "\n")
	end

	function C.transitGo(name, id)
		local tr = find(id)
		if not tr then
			return "no transit " .. tostring(id)
		end
		return C.tp(plr(name).Name, tr.pos + Vector3.new(0, 3.5, 0))
	end

	function C.transitStart(name)
		local p = plr(name)
		local s = ctx.Raid.session(p)
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if not s or not root then
			return "not in raid"
		end
		for _, m in ctx.World.maps do
			for _, tr in m.transits or {} do
				if ctx.Transit.inside(tr, root.Position) then
					local ok, why = ctx.Transit.start(p, tr)
					return tostring(ok) .. " " .. tostring(why)
				end
			end
		end
		return "not in a transit zone"
	end

	function C.transitState(name)
		local s = ctx.Raid.session(plr(name))
		if not s then
			return "not in raid"
		end
		return HttpService:JSONEncode({
			map = s.map, active = ctx.World.activeMap, extracts = s.extracts, transits = s.transits,
			transit = s.transit and { to = s.transit.to, left = s.transit.ends - workspace:GetServerTimeNow() } or nil, state = s.state,
		})
	end
end
