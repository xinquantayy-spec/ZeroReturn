--!nonstrict
-- Exit walk for the Studio test bridge. A player in a raid is put in each exit of the map in play, in turn, and the
-- server's own extract tick (Extract.tick, every 0.2 s) decides what happens there: refused with its reason, or the
-- hold started. Then the exit's rule is met the way a player meets it (the power switches thrown, the backpack taken
-- off, a scav's raid, the key carried) and the tick is read again. The character really stands in the zone; nothing
-- is decided here.
-- The hold is never left to run out (the player steps out first), except at the exit named `finish`, which is held to
-- the end and ends the raid as a real extraction does.
--   ZR_Dev:Invoke("exitwalk", name, finish)   start (name = a player's name, nil = the first one)
--   ZR_Dev:Invoke("exitwalkresult")           what it has found so far
local Players = game:GetService("Players")
local Inv = require(script.Parent.Parent.Inv)

local function plr(name)
	return (name and Players:FindFirstChild(name)) or Players:GetPlayers()[1]
end

return function(C, ctx)
	local run = nil

	function C.exitwalkresult()
		if not run then
			return "not started"
		end
		return (run.done and "done" or "running") .. "\n" .. table.concat(run.out, "\n")
	end

	function C.exitwalk(name, finish)
		local p = plr(name)
		local s = p and ctx.Raid.session(p)
		if not s then
			return "not in a raid"
		end
		run = { out = {}, done = false }
		local out = run.out
		task.spawn(function()
			local ok, err = pcall(function()
				local W, X = ctx.World, ctx.Extract
				local ids = {}
				for id, e in W.extracts do
					if e.map == ctx.Match.map or not e.map then
						table.insert(ids, id)
					end
				end
				table.sort(ids, function(a, b)
					-- the finishing exit last
					if a == finish or b == finish then
						return b == finish and a ~= finish
					end
					return a < b
				end)
				local keep = table.clone(s.extracts)
				local function now()
					return workspace:GetServerTimeNow()
				end
				local function read(e)
					local why, text = X.blocked(p, s, e)
					local st = s.state
					if st == "EXTRACTING" and s.exEnds then
						return string.format("EXTRACTING (%.1f s left)", s.exEnds - now())
					end
					return string.format("%s%s", st, why and string.format(" · refused %s: %s", why, tostring(text)) or "")
				end
				local function stepOut(e)
					C.tp(p.Name, e.pos + Vector3.new(e.size.X / 2 + 30, 3.5, 0))
					task.wait(0.6)
				end
				for _, id in ids do
					local e = W.extracts[id]
					local r = e.rule or {}
					s.extracts = { id }
					ctx.Remotes.note(p, "raid", ctx.Raid.raidInfo(s))
					local line = { string.format("%s %s [%s]:", id, e.name, tostring(r.kind)) }
					stepOut(e)
					if X.hasChance(r) or X.isCar(e) then
						C.exitOpen(id, true)
						table.insert(line, "rolled open for the test ·")
					end
					C.tp(p.Name, id)
					task.wait(0.8)
					table.insert(line, "in the zone: " .. read(e))
					if r.kind == "power" then
						if r.also then
							ctx.Doors.setSwitch(r.also, true)
							task.wait(0.8)
							table.insert(line, "· " .. r.also .. " on: " .. read(e))
						end
						ctx.Doors.setSwitch(r.switch, true)
						task.wait(0.8)
						table.insert(line, "· " .. tostring(r.switch) .. " on: " .. read(e))
					elseif r.kind == "nobag" then
						local bag = s.inv.slots and s.inv.slots.back
						if bag then
							s.inv.slots.back = nil
							task.wait(0.8)
							table.insert(line, "· backpack off: " .. read(e))
							s.inv.slots.back = bag
							task.wait(0.5)
							table.insert(line, "· backpack back on mid-hold: " .. read(e))
						else
							table.insert(line, "· (no backpack worn)")
						end
					elseif r.kind == "scav" then
						s.scav = true
						task.wait(0.8)
						table.insert(line, "· as a scav: " .. read(e))
						if id ~= finish then
							stepOut(e)
							s.scav = nil
						end
					elseif r.kind == "key" and r.key then
						-- the key put in the raid inventory, then taken out again after the reading
						local g = C.give(p.Name, r.key, 1)
						task.wait(0.8)
						table.insert(line, "· carrying " .. tostring(r.key) .. ": " .. read(e))
						if type(g) == "string" and string.sub(g, 1, 3) ~= "ERR" and s.inv.items[g] then
							Inv.consume(s.inv, g)
							ctx.Raid.afterChange(p, true)
						end
					elseif X.isCar(e) then
						table.insert(line, "· (a car: the fare is paid at the car; not paid here)")
					end
					if id == finish then
						local t0 = now()
						while not s.done and now() - t0 < 20 do
							task.wait(0.2)
						end
						table.insert(line, string.format("· held: %s after %.1f s", s.done and ("raid over, " .. tostring(s.result or s.state)) or read(e), now() - t0))
					else
						stepOut(e)
						table.insert(line, "· stepped out: " .. read(e))
					end
					table.insert(out, table.concat(line, " "))
					if s.done then
						break
					end
				end
				if not s.done then
					s.extracts = keep
					ctx.Remotes.note(p, "raid", ctx.Raid.raidInfo(s))
				end
			end)
			if not ok then
				table.insert(out, "error: " .. tostring(err))
			end
			run.done = true
		end)
		return "started"
	end
end
