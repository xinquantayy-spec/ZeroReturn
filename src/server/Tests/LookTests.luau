--!nonstrict
-- M12 Look 2.0 checks (server side): the graphics setting through the real request path, the published detail
-- plan, and the wear-kit cover props. Run with ZR_Dev:Invoke("tests") (every module in Tests runs).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Wear = require(Shared.Wear)
local Services = script.Parent.Parent.Services

local T = {}

-- ground clutter the plan drops on floors (wall fittings and window pieces are not clutter)
local CLUTTER = {
	ZR_WK_Rubble = true, ZR_WK_RubbleLarge = true, ZR_WK_Chips = true, ZR_WK_Weeds = true, ZR_WK_Litter = true, ZR_WK_Bricks = true,
	ZR_WK_Planks = true, ZR_WK_Cardboard = true, ZR_WK_TrashBag = true, ZR_WK_Tyre = true, ZR_WK_Rebar = true, ZR_WK_BinTipped = true,
	ZR_WK_ChairTipped = true, ZR_WK_CeilingTile = true, ZR_WK_Mattress = true,
}

function T.run(ctx)
	local passed, failed, notes = 0, 0, {}
	local function check(name, cond, info)
		if cond then
			passed += 1
		else
			failed += 1
			table.insert(notes, "FAIL " .. name .. (info ~= nil and (" [" .. tostring(info) .. "]") or ""))
		end
	end

	-- L01 graphics level: POTATO 0 .. HIGH 3, whole numbers, through the real dispatcher (validation + rate limit)
	do
		local fake = { Name = "LT_fake", UserId = -17 }
		local prof = require(Services.Settle).newProfile()
		ctx.Profiles.attachTest(fake, prof)
		local function set(v)
			local r = ctx.Remotes.dispatch(fake, "settings", { quality = v })
			task.wait(0.55) -- settings requests are rate limited
			return r
		end
		local r0 = set(0)
		check("L01 POTATO (0) accepted", r0.ok and prof.settings.quality == 0, prof.settings.quality)
		set(3)
		check("L01 HIGH (3) accepted", prof.settings.quality == 3, prof.settings.quality)
		set(1.4)
		check("L01 a fractional level rounds", prof.settings.quality == 1, prof.settings.quality)
		set(9)
		check("L01 above HIGH clamps to 3", prof.settings.quality == 3, prof.settings.quality)
		set(-4)
		check("L01 below POTATO clamps to 0", prof.settings.quality == 0, prof.settings.quality)
		local bad = set("max")
		check("L01 a non-number is refused", bad.ok == false and bad.code == "BAD_INPUT", bad.code)
		ctx.Profiles.detachTest(fake)
	end

	-- L02 the detail plan: published, well formed, only known images and library meshes, clutter clear of play spots
	do
		local pf = ReplicatedStorage:FindFirstChild("ZR_DetailPlan")
		local t0 = os.clock()
		while not pf and os.clock() - t0 < 15 do
			task.wait(0.25)
			pf = ReplicatedStorage:FindFirstChild("ZR_DetailPlan")
		end
		check("L02 detail plan published", pf ~= nil)
		if pf then
			local decSet = {}
			for _, v in Wear.DEC do
				decSet[v] = true
			end
			local lib = ReplicatedStorage:FindFirstChild("ZR_Assets")
			local avoid = ctx.World.detailAvoid()
			local total, badCell, badDec, badMesh, near, bytes = 0, 0, 0, 0, 0, 0
			for _, sv in pf:GetChildren() do
				bytes += #sv.Value
				local ok, list = pcall(HttpService.JSONDecode, HttpService, sv.Value)
				local cx, cz = string.match(sv.Name, "^(-?%d+)_(-?%d+)u?$")
				if not ok or not cx then
					badCell += 1
					continue
				end
				for _, e in list do
					total += 1
					local x, y, z = e[3], e[4], e[5]
					if math.floor(x / Wear.CELL) ~= tonumber(cx) or math.floor(z / Wear.CELL) ~= tonumber(cz) then
						badCell += 1
					end
					if e[1] == 1 then
						if #e ~= 16 or not decSet[e[2]] or e[12] < 1 or e[12] > 3 then
							badDec += 1
						end
					elseif e[1] == 2 then
						if #e ~= 13 or not Wear.MESH[e[2]] or not (lib and lib:FindFirstChild(e[2])) or e[9] < 1 or e[9] > 3 then
							badMesh += 1
						end
						if CLUTTER[e[2]] then
							for _, a in avoid do
								local d = a.pos - Vector3.new(x, y, z)
								if math.abs(d.Y) < 4 and d.X * d.X + d.Z * d.Z < a.r * a.r then
									near += 1
									break
								end
							end
						end
					else
						badCell += 1
					end
				end
			end
			check("L02 plan has entries and the published count matches", total > 500 and total == pf:GetAttribute("Count"), total)
			check("L02 every entry well formed and in its own cell", badCell == 0, badCell)
			check("L02 decals use the uploaded wear images", badDec == 0, badDec)
			check("L02 meshes are wear-kit pieces in the library", badMesh == 0, badMesh)
			check("L02 ground clutter keeps clear of loot, containers, doors, exfils and spawns", near == 0, near)
			check("L02 plan stays small enough to replicate (< 400 KB)", bytes < 400 * 1024, math.floor(bytes / 1024) .. " KB")
		end
		check("L02 the server builds no detail itself (client only)", workspace:FindFirstChild("ZR_Detail") == nil)
	end

	-- L03 cover props from the wear kit: solid, clear of spawns and exfil zones, and they stop shots
	do
		local covers = {}
		local world = workspace:FindFirstChild("ZR_World")
		for _, d in world and world:GetDescendants() or {} do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 6) == "Cover_" then
				table.insert(covers, d)
			end
		end
		check("L03 cover props placed", #covers >= 28, #covers)
		local solid, meshes = true, 0
		for _, c in covers do
			if not (c.Anchored and c.CanCollide and c.CanQuery) then
				solid = false
			end
			if c:IsA("MeshPart") then
				meshes += 1
			end
		end
		check("L03 cover props are solid (collide, take queries)", solid)
		check("L03 cover props use the Blender meshes", meshes == #covers, meshes .. "/" .. #covers)
		local near = 0
		for _, c in covers do
			local flat = Vector3.new(c.Position.X, 0, c.Position.Z)
			local rad = math.max(c.Size.X, c.Size.Z) / 2
			for _, s in ctx.World.spawns do
				if (flat - Vector3.new(s.cf.X, 0, s.cf.Z)).Magnitude < rad + 8 then
					near += 1
				end
			end
			for _, e in ctx.World.extracts do
				if (flat - Vector3.new(e.pos.X, 0, e.pos.Z)).Magnitude < rad + math.max(e.size.X, e.size.Z) / 2 + 2 then
					near += 1
				end
			end
		end
		check("L03 cover keeps clear of spawns and exfil zones", near == 0, near)
		local car
		for _, c in covers do
			if c.Name == "Cover_CarWreck" then
				car = c
				break
			end
		end
		if car then
			local target = Vector3.new(car.Position.X, 1.6, car.Position.Z)
			local origin = target + car.CFrame.RightVector * 12
			local hit = workspace:Raycast(origin, target - origin, ctx.Combat.filter(nil))
			check("L03 a shot at a car wreck stops at the wreck", hit ~= nil and hit.Instance == car, hit and hit.Instance:GetFullName())
		end
	end

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T
