--!nonstrict
-- Studio dev commands for weapon mastering (docs/design/MASTERING.md), added to the ZR_Dev bridge by Dev.init (every
-- ModuleScript in Services/DevExt returns function(C, ctx)). A weapon is named by its group or Weapons id (R17, KST,
-- SPARROW, HARROW, TUNDRA, P9) or by its item id (R17_RIFLE), in any case. name = a player's name, nil = the first one.
--   ZR_Dev:Invoke("mastery", name, weapon, n)     grant n points (default 1) through the call a landed hit makes
--                                                  (Economy.masteryUp: the level-up notice and the state push)
--   ZR_Dev:Invoke("masterySet", name, weapon, n)  set the group's points to exactly n (0 resets it); no notice
--   ZR_Dev:Invoke("masteryShow", name)            every group: points, level, the next running total and whether the
--                                                  server lets it reload while aiming; the weapon in hands in a raid
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local P = require(Shared.Progress)

local function plr(name)
	return (name and Players:FindFirstChild(name)) or Players:GetPlayers()[1]
end

-- the group of a group, weapon or item id
local function groupOf(key)
	if type(key) ~= "string" then
		return nil
	end
	local k = string.upper(key)
	if P.MASTERING[k] then
		return k
	end
	if P.MASTERY_OF[k] then
		return P.MASTERY_OF[k]
	end
	local d = Items.defs[k]
	return d and d.weapon and P.MASTERY_OF[d.weapon] or nil
end

local USAGE = "usage: (name or nil, weapon, n) with a weapon of " .. table.concat(P.MASTERY_ORDER, ", ")

return function(C, ctx)
	local function show(p, prof)
		local groups = {}
		for _, gid in P.MASTERY_ORDER do
			local pts = (prof.mastering and prof.mastering[gid]) or 0
			local lvl, _, nxt = P.masteryProgress(gid, pts)
			groups[gid] = {
				points = pts, level = lvl, next = lvl < P.MASTERY_MAX and nxt or nil,
				adsReload = ctx.Combat.aimReload(prof, P.MASTERING[gid].weapons[1]),
			}
		end
		local s = ctx.Raid.session(p)
		local wdef
		if s then
			local _, _, wd = ctx.Combat.activeWeapon(s)
			wdef = wd
		end
		return HttpService:JSONEncode({
			player = p.Name, groups = groups, inHands = wdef and wdef.id or nil,
			levelInHands = wdef and P.masteryFor(prof.mastering, wdef.id) or nil,
		})
	end

	local function target(name, weapon)
		local p = plr(name)
		local prof = p and ctx.Profiles.get(p)
		return p, prof, groupOf(weapon)
	end

	function C.masteryShow(name)
		local p = plr(name)
		local prof = p and ctx.Profiles.get(p)
		if not prof then
			return "no profile"
		end
		return show(p, prof)
	end

	function C.mastery(name, weapon, n)
		local p, prof, gid = target(name, weapon)
		if not (prof and gid) then
			return USAGE
		end
		ctx.Economy.masteryUp(p, prof, P.MASTERING[gid].weapons[1], math.max(1, math.floor(tonumber(n) or 1)))
		ctx.Profiles.markDirty(p)
		ctx.Raid.push(p) -- the points show on the MASTERING tab even without a level-up
		return show(p, prof)
	end

	function C.masterySet(name, weapon, n)
		local p, prof, gid = target(name, weapon)
		if not (prof and gid and tonumber(n)) then
			return USAGE
		end
		prof.mastering = prof.mastering or {}
		prof.mastering[gid] = math.max(0, math.floor(tonumber(n)))
		ctx.Profiles.markDirty(p)
		ctx.Raid.push(p)
		return show(p, prof)
	end
end
