--!nonstrict
-- Meridian outside structures (foundation, part 2 of 2). Map-local studs (see Layout.luau), the footprints are the
-- reference's outdoor buildings (L.blds), the buildings, names and colours are ours. Built here:
--   THE SUBSTATION  the power station main building (switch hall with the power lever, office, locked utility room) and its
--                   compound (transformers on the four pads, the yard sheds); the lever is W.switches.MALL_POWER
--   WEST CAMP       the ten huts of the scav camp          RESCUE CAMP        four tents and four shipping containers
--   RESCUE CHECKPOINT  an office, a guardhouse, a check booth, barriers, sandbags, signs
--   booths, huts and sheds (highway booths, the east huts, the wall-break hut, the railside hut, the yard sheds)
--   the KART PIT HOUSE and the two sign pylons (NESTA and BOLTWORKS)
-- Every building is a shell from wallHoles (door and window openings, gable or flat roof) with a floor slab and a few Blender
-- kit props inside; only THE SUBSTATION and the checkpoint office have door leaves (W.doors). Outdoor loot, containers outside
-- THE SUBSTATION, AI posts and extracts are the gameplay part's.
-- The power lever: Outside registers W.switches.MALL_POWER (the gameplay and store parts must NOT register it again). Anything
-- else that follows the power adds a function(on) to B.powerHooks (a list the lever calls, pcall each, whenever it changes) and
-- applies the off state itself when it is built (the lever resets to off every raid).
-- Named world points (Vector3 at standing height) go into B.points: SUBSTATION_SWITCH, SUBSTATION_UTILITY, SUBSTATION_GATE,
-- RESCUE_CHECKPOINT (in front of the office door), RESCUE_GATE (the road at the extract), WEST_CAMP, RESCUE_CAMP, KART_PIT,
-- NESTA_TOWER, BOLTWORKS_TOWER.
-- Counts: B.count.struct (structures), prop (kit props), door (door leaves), light, container (all in THE SUBSTATION).
local PI = math.pi

return function(B)
	local kit, H, map, L, O, W, Kit, rng = B.kit, B.H, B.map, B.L, B.O, B.W, B.Kit, B.rng
	local C, M, hex = kit.C, kit.M, kit.hex
	local V = H.V
	local groundAt = B.ground
	local count = B.count or {}
	B.count = count
	for _, key in { "struct", "prop", "door", "light", "container" } do
		count[key] = count[key] or 0
	end
	B.points = B.points or {}
	B.powerHooks = B.powerHooks or {}
	local points = B.points
	local om = kit.model("Outside", map)

	local function step(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			warn("[ZR] Meridian outside: " .. name .. " failed: " .. tostring(err))
		end
		return ok
	end

	-- ── frames ───────────────────────────────────────────────────────────────────────────────────────────
	-- a building's local frame: u along its long side, v across (south for rot 0), y above the pad
	local function frameOf(b)
		local a = math.rad(b[9])
		local gy = groundAt(b[5], b[6])
		return {
			base = CFrame.new(O.X + b[5], gy, O.Z + b[6]) * CFrame.Angles(0, -a, 0), gy = gy, ca = math.cos(a), sa = math.sin(a),
			hw = b[7] / 2, hd = b[8] / 2, cx = b[5], cz = b[6],
		}
	end
	local function wp(F, u, y, v)
		return (F.base * CFrame.new(u, y, v)).Position
	end
	local function box(parent, F, sx, sy, sz, u, y, v, color, mat)
		return kit.boxCF(parent, sx, sy, sz, F.base * CFrame.new(u, y, v), color, mat)
	end
	-- a prop facing (fu, fv) in the local plane (its front is local -Z)
	local function yawFacing(fu, fv)
		return math.atan2(-fu, -fv)
	end
	local function prop(parent, F, name, u, v, yaw, y, opts)
		local o = { shadows = false }
		for k, val in opts or {} do
			o[k] = val
		end
		local m = Kit.place(parent, name, F.base * CFrame.new(u, y or 0.25, v) * CFrame.Angles(0, yaw or 0, 0), o)
		if m then
			count.prop += 1
		end
		return m
	end
	local function propSize(name)
		local sz = Kit.size(name)
		return sz or Vector3.new(4, 4, 4)
	end

	-- the nearest road point to (x, z): distance, the point and the road's unit direction there
	local function nearRoad(x, z)
		local best, bx, bz, bux, buz = math.huge, x, z, 1, 0
		for _, rd in L.roads do
			local pts = rd[4]
			for s = 1, #pts / 2 - 1 do
				local ax, az, ex, ez = pts[2 * s - 1], pts[2 * s], pts[2 * s + 1], pts[2 * s + 2]
				local dx, dz = ex - ax, ez - az
				local l2 = dx * dx + dz * dz
				local t = 0
				if l2 > 1e-9 then
					t = math.clamp(((x - ax) * dx + (z - az) * dz) / l2, 0, 1)
				end
				local px, pz = ax + dx * t, az + dz * t
				local d = (x - px) * (x - px) + (z - pz) * (z - pz)
				if d < best then
					best, bx, bz = d, px, pz
					if l2 > 1e-9 then
						local l = math.sqrt(l2)
						bux, buz = dx / l, dz / l
					end
				end
			end
		end
		return math.sqrt(best), bx, bz, bux, buz
	end
	-- the side of a building that faces the nearest road: "n" (-v), "s" (+v), "w" (-u), "e" (+u)
	local function pickFront(b, F)
		local d, px, pz = nearRoad(b[5], b[6])
		if d > 600 then
			return "s"
		end
		local dx, dz = px - b[5], pz - b[6]
		local du = dx * F.ca + dz * F.sa
		local dv = -dx * F.sa + dz * F.ca
		local best, side = -math.huge, "s"
		for _, c in { { "n", -dv }, { "s", dv }, { "w", -du }, { "e", du } } do
			if c[2] > best then
				best, side = c[2], c[1]
			end
		end
		return side
	end

	-- ── shells ───────────────────────────────────────────────────────────────────────────────────────────
	local OPP = { n = "s", s = "n", w = "e", e = "w" }
	local INWARD = { n = { 0, 1 }, s = { 0, -1 }, w = { 1, 0 }, e = { -1, 0 } } -- from a wall on that side into the room
	local DOORYAW = { n = PI, s = 0, w = -PI / 2, e = PI / 2 } -- a leaf in that wall swings into the room
	-- the length of the wall on a side (the side walls run between the end walls)
	local function wallLen(F, side, t)
		if side == "n" or side == "s" then
			return 2 * F.hw
		end
		return 2 * F.hd - 2 * t
	end
	-- the foot of a wall on that side
	local function wallCF(F, side, t)
		if side == "n" then
			return F.base * CFrame.new(0, 0, -(F.hd - t / 2))
		elseif side == "s" then
			return F.base * CFrame.new(0, 0, F.hd - t / 2)
		elseif side == "w" then
			return F.base * CFrame.new(-(F.hw - t / 2), 0, 0) * CFrame.Angles(0, -PI / 2, 0)
		end
		return F.base * CFrame.new(F.hw - t / 2, 0, 0) * CFrame.Angles(0, -PI / 2, 0)
	end
	-- the local (u, v) of an opening on a side at offset s along it
	local function openingUV(F, side, s, t)
		if side == "n" then
			return s, -(F.hd - t / 2)
		elseif side == "s" then
			return s, F.hd - t / 2
		elseif side == "w" then
			return -(F.hw - t / 2), s
		end
		return F.hw - t / 2, s
	end
	local function newHoles()
		return { n = {}, s = {}, w = {}, e = {} }
	end
	-- adds an opening if it fits the wall and clears the others
	local function addHole(holes, len, side, s, w, bottom, top)
		if math.abs(s) + w / 2 > len / 2 - 0.8 then
			return false
		end
		for _, o in holes[side] do
			if math.abs(s - o[1]) < (w + o[2]) / 2 + 1.2 then
				return false
			end
		end
		table.insert(holes[side], { s, w, bottom, top })
		return true
	end
	local function walls(parent, F, o, holes)
		for _, side in { "n", "s", "w", "e" } do
			kit.wallHoles(parent, wallCF(F, side, o.t), wallLen(F, side, o.t), o.h, o.t, o.wall, o.mat, holes[side])
		end
	end
	-- the floor slab top is FLOOR above the pad; props, doors and furniture stand on it
	local FLOOR = 0.25
	local function floorSlab(parent, F, color)
		kit.boxCF(parent, 2 * F.hw, 0.9, 2 * F.hd, F.base * CFrame.new(0, FLOOR - 0.45, 0), color or C.floor, M.Concrete)
	end
	-- a gable roof, ridge along u; the gable ends are filled with wedges
	local function gableRoof(parent, F, h, pitchDeg, color, mat, endColor)
		local hw, hd = F.hw, F.hd
		local p = math.rad(pitchDeg)
		local ov = 1.5
		local rise = hd * math.tan(p)
		local len = (hd + ov) / math.cos(p)
		for _, sg in { -1, 1 } do
			local ym = h + (hd - ov) * math.tan(p) / 2 + 0.25
			kit.boxCF(parent, 2 * hw + 2 * ov, 0.5, len, F.base * CFrame.new(0, ym, sg * (hd + ov) / 2) * CFrame.Angles(sg * p, 0, 0), color, mat)
			local yaw = 0
			if sg > 0 then
				yaw = PI
			end
			for _, su in { -1, 1 } do
				kit.part(parent, Vector3.new(0.6, rise, hd), F.base * CFrame.new(su * (hw - 0.3), h + rise / 2, sg * hd / 2) * CFrame.Angles(0, yaw, 0), endColor or color, mat, "WedgePart")
			end
		end
		kit.boxCF(parent, 2 * hw + 2 * ov, 0.4, 0.8, F.base * CFrame.new(0, h + rise + 0.3, 0), color, mat)
	end
	local function flatRoof(parent, F, h, color, mat, parapet)
		kit.boxCF(parent, 2 * F.hw + 1.6, 0.9, 2 * F.hd + 1.6, F.base * CFrame.new(0, h + 0.45, 0), color, mat)
		if parapet then
			local hh = 2.2
			for _, sg in { -1, 1 } do
				kit.boxCF(parent, 2 * F.hw + 1.6, hh, 0.8, F.base * CFrame.new(0, h + 0.9 + hh / 2, sg * (F.hd + 0.4)), color, mat)
				kit.boxCF(parent, 0.8, hh, 2 * F.hd - 0.8, F.base * CFrame.new(sg * (F.hw + 0.4), h + 0.9 + hh / 2, 0), color, mat)
			end
		end
	end
	-- a ceiling lamp (a lit box); grp collects the light and the lamp for a switch
	local function lamp(parent, F, u, y, v, range, grp, warm)
		local head = box(parent, F, 3.2, 0.35, 0.8, u, y, v, warm or hex("FFE2B0"), M.Neon)
		head.CastShadow = false
		head.CanCollide = false
		head:SetAttribute("NoDetail", true)
		local l = kit.light(head, warm or hex("FFD3A0"), range or 24, 0.9, false)
		count.light += 1
		if grp then
			-- a switched lamp starts dead; the lever turns the group on
			l.Enabled = false
			head.Material = M.SmoothPlastic
			head.Color = hex("6F6C64")
			table.insert(grp.lights, l)
			table.insert(grp.panels, head)
		end
		return head
	end
	-- a door leaf in a wall opening (W.doors): side, offset s, hole width and height; key makes it locked
	local function doorLeaf(parent, F, t, id, label, side, s, w, h, key, color)
		local u, v = openingUV(F, side, s, t)
		local d = {
			id = id, cf = F.base * CFrame.new(u, FLOOR + h / 2, v) * CFrame.Angles(0, DOORYAW[side], 0), size = Vector3.new(w, h, 0.35),
			key = key, label = label, parent = parent, color = color,
		}
		if not key then
			d.openChance = 0.35
		end
		W.doors[id] = d
		count.door += 1
		return d
	end
	-- props against the wall opposite the front, evenly spaced, front toward the room; a slot in front of an opening that
	-- reaches below the prop's top is left empty
	local function furnish(parent, F, t, front, names, holes)
		local back = OPP[front]
		local inw = INWARD[back]
		local alongU = back == "n" or back == "s"
		local span = (alongU and F.hw or F.hd) - t - 3
		local n = #names
		for i, name in names do
			local sz = propSize(name)
			local frac = (i - 0.5) / n
			local s = -span + 2 * span * frac
			local depth = sz.Z / 2 + 0.4
			local u, v
			if back == "n" then
				u, v = s, -(F.hd - t - depth)
			elseif back == "s" then
				u, v = s, F.hd - t - depth
			elseif back == "w" then
				u, v = -(F.hw - t - depth), s
			else
				u, v = F.hw - t - depth, s
			end
			local clear = (2 * span) / n > sz.X + 1
			for _, o in holes[back] do
				if o[3] < sz.Y and math.abs(s - o[1]) < (sz.X + o[2]) / 2 + 0.6 then
					clear = false
				end
			end
			if clear then
				prop(parent, F, name, u, v, yawFacing(inw[1], inw[2]), FLOOR)
			end
		end
	end

	-- ── structure styles by group ────────────────────────────────────────────────────────────────────────
	local STYLE = {
		camp = { h = 14, t = 1.2, wall = hex("6B5A44"), mat = M.WoodPlanks, floor = hex("4B4638"), roof = "gable", rc = hex("7B5A47"), rm = M.CorrodedMetal, pitch = 20, props = { "Bed", "BunkBed", "Table", "Locker", "StorageShelf", "Drum", "Sofa", "Chair" } },
		hut = { h = 13, t = 1.4, wall = hex("8B8A80"), mat = M.Concrete, floor = hex("5A5C57"), roof = "gable", rc = hex("5E6460"), rm = M.Metal, pitch = 16, props = { "Table", "Chair", "Bench", "Drum", "ToolChest", "StorageShelf" } },
		rail = { h = 13, t = 1.4, wall = hex("7E7A6E"), mat = M.Concrete, floor = hex("5A5C57"), roof = "gable", rc = hex("5B5048"), rm = M.CorrodedMetal, pitch = 14, props = { "Bench", "Locker", "Table", "ToolChest" } },
		shed = { h = 12, t = 0.9, wall = hex("5F6C66"), mat = M.Metal, floor = hex("55574F"), roof = "flat", rc = hex("4B5450"), rm = M.Metal, props = { "PalletBoxes", "Drum", "JerryCans", "StorageShelf", "ToolChest" } },
		booth = { h = 11, t = 1.0, wall = hex("A8AAA2"), mat = M.Plaster, floor = hex("6C6E68"), roof = "flat", rc = hex("3E4341"), rm = M.Concrete, props = { "OfficeDesk", "Chair", "Bin" } },
		check = { h = 13, t = 1.2, wall = hex("77848A"), mat = M.Plaster, floor = hex("5C6062"), roof = "flat", rc = hex("3A4044"), rm = M.Concrete, props = { "OfficeDesk", "Chair", "Locker", "Bench" } },
		kart = { h = 16, t = 1.2, wall = hex("B7B5AA"), mat = M.Concrete, floor = hex("6A6C66"), roof = "flat", rc = hex("8E3B33"), rm = M.Metal, props = { "TyreStack", "ToolChest", "Locker", "Bench" } },
	}

	-- an opening of width w at about frac of a wall of length len, kept clear of the wall's ends
	local function slot(len, frac, w)
		local lim = math.max(0, len / 2 - 0.9 - w / 2)
		return math.clamp(frac * len, -lim, lim)
	end
	local OUTWARD = { n = { 0, -1 }, s = { 0, 1 }, w = { -1, 0 }, e = { 1, 0 } }

	-- a plain building from the footprint record: floor, walls with a front door (and windows, or wide openings), a roof
	-- and a few props. Returns the model, its frame, the front side and the door offset along the front wall.
	local function building(b)
		local st = STYLE[b[4]]
		if not st then
			return nil
		end
		local F = frameOf(b)
		local m = kit.model(b[2], om)
		local front = pickFront(b, F)
		local t = st.t
		local holes = newHoles()
		local flen = wallLen(F, front, t)
		local bside = OPP[front]
		local blen = wallLen(F, bside, t)
		local doorS = nil
		local sgn = 1
		if rng:NextInteger(0, 1) == 0 then
			sgn = -1
		end
		if b[4] == "shed" then
			-- one wide opening on the front (a doorway when the wall is short)
			if flen >= 14 then
				doorS = slot(flen, rng:NextNumber(-0.15, 0.15), 9)
				addHole(holes, flen, front, doorS, 9, 0, 9.5)
			else
				doorS = 0
				addHole(holes, flen, front, 0, 4.4, 0, 8)
			end
		elseif b[4] == "kart" then
			-- three garage openings on the front, a door in the back wall
			for _, f in { -0.3, 0, 0.3 } do
				addHole(holes, flen, front, slot(flen, f, 10), 10, 0, 11)
			end
			doorS = 0
			addHole(holes, blen, bside, slot(blen, sgn * 0.3, 4.4), 4.4, 0, 8)
		elseif b[4] == "booth" then
			-- the door toward one end of the front wall, a counter window beside it, one in the back wall
			doorS = slot(flen, sgn * 0.3, 4.4)
			addHole(holes, flen, front, doorS, 4.4, 0, 8)
			addHole(holes, flen, front, slot(flen, -sgn * 0.22, 9), math.min(9, flen * 0.3), 4.2, 8.6)
			addHole(holes, blen, bside, slot(blen, 0, 9), math.min(9, blen * 0.4), 4.2, 8.6)
		elseif b[4] == "check" then
			doorS = slot(flen, sgn * 0.25, 4.4)
			addHole(holes, flen, front, doorS, 4.4, 0, 8)
			for _, f in { -0.33, 0.33 } do
				addHole(holes, flen, front, slot(flen, f, 5.5), 5.5, 4.4, 9)
			end
			addHole(holes, blen, bside, slot(blen, 0, 5.5), 5.5, 4.4, 9)
		else
			-- huts: a door in the front wall, a window in each long wall, a back door in the big ones
			doorS = slot(flen, rng:NextNumber(-0.25, 0.25), 4.4)
			addHole(holes, flen, front, doorS, 4.4, 0, 8)
			for _, side in { front, bside } do
				local len = wallLen(F, side, t)
				if len >= 20 then
					addHole(holes, len, side, slot(len, rng:NextNumber(-0.3, 0.3), 5), 5, 4.6, 9.4)
				end
			end
			if blen >= 28 then
				addHole(holes, blen, bside, slot(blen, rng:NextNumber(-0.3, 0.3), 4.4), 4.4, 0, 8)
			end
		end
		floorSlab(m, F, st.floor)
		walls(m, F, { h = st.h, t = t, wall = st.wall, mat = st.mat }, holes)
		if st.roof == "gable" then
			gableRoof(m, F, st.h, st.pitch, st.rc, st.rm, st.wall)
		else
			flatRoof(m, F, st.h, st.rc, st.rm, b[4] == "check" or b[4] == "kart")
		end
		if b[4] == "booth" then
			-- a canopy over the front
			local o = OUTWARD[front]
			local cu, cv = o[1] * (F.hw + 2.5), o[2] * (F.hd + 2.5)
			if front == "n" or front == "s" then
				box(m, F, 2 * F.hw - 2, 0.6, 5, cu, st.h + 0.3, cv, st.rc, st.rm)
			else
				box(m, F, 5, 0.6, 2 * F.hd - 2, cu, st.h + 0.3, cv, st.rc, st.rm)
			end
		end
		-- props against the back wall
		local names = {}
		local pool = st.props
		local want = 2
		if b[7] * b[8] > 700 then
			want = 3
		end
		if b[4] == "booth" or b[4] == "shed" then
			want = 1
		end
		for _ = 1, want do
			table.insert(names, pool[rng:NextInteger(1, #pool)])
		end
		furnish(m, F, t, front, names, holes)
		count.struct += 1
		return m, F, front, doorS
	end

	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	-- THE SUBSTATION
	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	local WARM = hex("FFD6A0")
	local function transformer(parent, F, u, v, yaw)
		local c = F.base * CFrame.new(u, 0.25, v) * CFrame.Angles(0, yaw or 0, 0)
		kit.boxCF(parent, 8.4, 0.8, 6.4, c * CFrame.new(0, 0.4, 0), hex("4E5650"), M.Concrete)
		local body = kit.boxCF(parent, 7.4, 8.2, 5.2, c * CFrame.new(0, 4.9, 0), hex("586656"), M.Metal)
		body.CastShadow = false
		kit.boxCF(parent, 7.8, 0.6, 5.6, c * CFrame.new(0, 9.3, 0), hex("48524A"), M.Metal)
		kit.boxCF(parent, 7.4, 6.4, 1.4, c * CFrame.new(0, 4.4, 3.3), hex("4F5B52"), M.Metal)
		for _, x in { -2.4, 0, 2.4 } do
			kit.vcyl(parent, 2.6, 0.9, (c * CFrame.new(x, 0, 0)).Position.X, c.Position.Y + 9.6, (c * CFrame.new(x, 0, 0)).Position.Z, hex("A39A82"), M.Concrete)
		end
	end

	local function substation(b)
		local F = frameOf(b)
		local m = kit.model("THE SUBSTATION", om)
		local hw, hd, t, h = F.hw, F.hd, 1.6, 20
		local WALL, BASE = hex("8A8C86"), hex("6B6E69")
		local powered = { lights = {}, panels = {} }
		local LAMP_OFF, LAMP_ON = hex("6F6C64"), hex("FFD6A0")
		local nlen, wlen = 2 * hw, 2 * hd - 2 * t

		-- the lever first: the exits that wait for the power need it whatever fails below
		local u1 = 10 -- the partition between the hall and the east rooms
		local leverV = -9
		local plate = box(m, F, 0.6, 7, 5.8, u1 - 0.8, 4.2, leverV, hex("3B403D"), M.Metal)
		plate.Name = "LeverPlate"
		box(m, F, 0.5, 0.8, 2.0, u1 - 1.3, 2.2, leverV, hex("55524A"), M.Metal)
		box(m, F, 0.5, 0.8, 2.0, u1 - 1.3, 6.2, leverV, hex("55524A"), M.Metal)
		local lampPart = box(m, F, 0.4, 0.7, 0.9, u1 - 1.2, 7.4, leverV + 1.8, LAMP_OFF, M.SmoothPlastic)
		table.insert(powered.panels, lampPart)
		local pivot = F.base * CFrame.new(u1 - 1.6, 4.2, leverV)
		local flip = CFrame.Angles(PI, 0, 0)
		local arm = kit.boxCF(m, 0.45, 3.0, 0.45, pivot * CFrame.new(0, 1.5, 0), hex("A9A48F"), M.Metal)
		local knob = kit.boxCF(m, 0.9, 0.9, 0.9, pivot * CFrame.new(0, 3.2, 0), hex("8E2F27"), M.SmoothPlastic)
		arm.Name = "LeverArm"
		arm.CanCollide = false
		knob.CanCollide = false
		local armOff, armOn = arm.CFrame, (pivot * flip) * CFrame.new(0, 1.5, 0)
		local knobOff, knobOn = knob.CFrame, (pivot * flip) * CFrame.new(0, 3.2, 0)
		local panel = box(m, F, 3.4, 6, 3.4, u1 - 2.0, 4.2, leverV, hex("6C7A72"), M.Metal)
		panel.Name = "LeverPanel"
		panel.Transparency = 1
		panel.CanCollide = false
		panel:SetAttribute("NoDetail", true)
		local pp = Instance.new("ProximityPrompt")
		pp.KeyboardKeyCode = Enum.KeyCode.F
		pp.ActionText = "Throw the switch"
		pp.ObjectText = "Power switch"
		pp.HoldDuration = 3
		pp.MaxActivationDistance = 8
		pp.RequiresLineOfSight = false
		pp.Style = Enum.ProximityPromptStyle.Custom
		pp.Parent = panel
		W.switches.MALL_POWER = {
			id = "MALL_POWER", label = "Power switch", part = panel, prompt = pp, delay = 6, startText = "THROWING THE SWITCH", doneText = "POWER ON",
			onChange = function(on)
				for _, l in powered.lights do
					l.Enabled = on
				end
				for _, p in powered.panels do
					p.Material = on and M.Neon or M.SmoothPlastic
					p.Color = on and LAMP_ON or LAMP_OFF
				end
				arm.CFrame = on and armOn or armOff
				knob.CFrame = on and knobOn or knobOff
				for _, fn in B.powerHooks do
					local ok, err = pcall(fn, on)
					if not ok then
						warn("[ZR] Meridian power hook: " .. tostring(err))
					end
				end
			end,
		}
		points.SUBSTATION_SWITCH = wp(F, u1 - 4.5, 3.3, leverV)
		-- an emergency lamp over the lever that stays lit
		local em = box(m, F, 0.9, 0.9, 0.9, u1 - 1.0, 8.8, leverV, hex("B8352B"), M.Neon)
		em.CastShadow = false
		em.CanCollide = false
		kit.light(em, hex("FF6A55"), 14, 0.7, false)
		count.light += 1

		-- floor, walls and openings
		local holes = newHoles()
		addHole(holes, wlen, "w", 0, 16, 0, 12) -- the vehicle gate on the apron side
		addHole(holes, nlen, "n", -22, 4.4, 0, 8.4) -- hall door
		addHole(holes, nlen, "n", 26, 4.4, 0, 8.4) -- the utility room (keyed)
		addHole(holes, nlen, "s", 26, 4.4, 0, 8.4) -- the office
		for _, s in { -34, -10, 2 } do
			addHole(holes, nlen, "n", s, 6, 11, 16)
		end
		for _, s in { -34, -22, -10, 2, 16 } do
			addHole(holes, nlen, "s", s, 6, 11, 16)
		end
		for _, s in { -14, 14 } do
			addHole(holes, wlen, "e", s, 5, 11, 15)
		end
		floorSlab(m, F, hex("55585A"))
		box(m, F, 2 * hw + 0.6, 1.4, 2 * hd + 0.6, 0, 0.7, 0, BASE, M.Concrete).Name = "Plinth"
		walls(m, F, { h = h, t = t, wall = WALL, mat = M.Concrete }, holes)
		flatRoof(m, F, h, hex("5A5E5A"), M.Concrete, true)
		-- the east rooms: a partition between them and the hall (a doorway into the office) and one between the two rooms
		local PW = hex("7C7F79")
		kit.wallHoles(m, F.base * CFrame.new(u1, 0, 0) * CFrame.Angles(0, -PI / 2, 0), 2 * (hd - t), h - 0.2, 1.0, PW, M.Concrete, { { 15, 6, 0, 9.4 } })
		kit.wallHoles(m, F.base * CFrame.new((u1 + hw - t) / 2, 0, 0), hw - t - u1, h - 0.2, 1.0, PW, M.Concrete, {})
		-- door leaves: the hall's side door, the office door and the locked utility room
		doorLeaf(m, F, t, "MM_SUB_HALL", "SUBSTATION", "n", -22, 4.4, 8.4, nil, hex("5A5F57"))
		doorLeaf(m, F, t, "MM_SUB_OFFICE", "SUBSTATION OFFICE", "s", 26, 4.4, 8.4, nil, hex("5A5F57"))
		doorLeaf(m, F, t, "MM_SUB_UTILITY", "UTILITY ROOM", "n", 26, 4.4, 8.4, "KEY_MM_SUBSTATION", hex("4A4F48"))
		local gu, gv = openingUV(F, "n", 26, t)
		points.SUBSTATION_UTILITY = wp(F, gu, 3.3, gv - 3)
		local wu, wv = openingUV(F, "w", 0, t)
		points.SUBSTATION_GATE = wp(F, wu - 4, 3.3, wv)

		-- lamps: six over the hall, one in each east room (switched with the lever)
		for _, u in { -30, -18, -6 } do
			for _, v in { -15, 15 } do
				lamp(m, F, u, h - 1.2, v, 26, powered, WARM)
			end
		end
		lamp(m, F, 24, h - 1.2, 15, 22, powered, WARM)
		lamp(m, F, 24, h - 1.2, -15, 22, powered, WARM)

		-- the hall: transformers, switch cabinets, a generator, wall boxes by the lever (the hall is west of the partition)
		transformer(m, F, -30, -17, 0)
		transformer(m, F, -16, -17, 0)
		transformer(m, F, -30, 16, PI)
		prop(m, F, "Generator", -4, -(hd - t - 3.2), PI, FLOOR)
		for _, u in { -37, -29, -21, -13 } do
			prop(m, F, "ElectricCabinet", u, hd - t - 1.2, 0, FLOOR)
		end
		prop(m, F, "FuseBox", u1 - 1.6, 5, PI / 2, 5)
		prop(m, F, "JunctionBox", u1 - 1.2, -17, PI / 2, 5)
		prop(m, F, "Extinguisher", u1 - 1.0, -3, PI / 2, 3)
		prop(m, F, "PipeRun", -22, -(hd - t - 1), PI, 15)
		prop(m, F, "PipeRun", -6, hd - t - 1, 0, 15)
		-- the office (south-east room: u 10.5 .. 39, v 0.5 .. 29; its door is in the south wall, a doorway to the hall in the partition)
		prop(m, F, "OfficeDesk", 33, 23.5, 0, FLOOR)
		prop(m, F, "Chair", 33, 19.8, PI, FLOOR)
		prop(m, F, "Locker", hw - t - 1.2, 5, PI / 2, FLOOR)
		prop(m, F, "Locker", hw - t - 1.2, 8, PI / 2, FLOOR)
		prop(m, F, "Bench", 22, 5, PI, FLOOR)
		prop(m, F, "FirstAid", u1 + 0.8, 24, -PI / 2, 5)
		-- the utility room (north-east, locked: u 10.5 .. 39, v -29 .. -0.5): shelving, chests, a tank
		prop(m, F, "StorageShelf", 15.5, -(hd - t - 1.4), PI, FLOOR)
		prop(m, F, "StorageShelf", 34, -(hd - t - 1.4), PI, FLOOR)
		prop(m, F, "ToolChest", hw - t - 1.6, -8, PI / 2, FLOOR)
		prop(m, F, "WaterTank", 16, -5, 0, FLOOR)
		prop(m, F, "PalletBoxes", 33, -5, 0.3, FLOOR)

		-- containers: two in the hall, two in the office, four in the utility room (the loot room)
		local function cont(kind, label, u, v, yaw)
			count.container += 1
			kit.container(m, "MM_SUB_C" .. count.container, kind, label, F.base * CFrame.new(u, FLOOR, v) * CFrame.Angles(0, yaw or 0, 0), nil)
		end
		cont("techbox", "Switchgear box", -37, -14, 0)
		cont("toolbox", "Electrician's chest", 4, hd - t - 2, 0)
		cont("drawer", "Filing drawers", hw - t - 1.5, 14, PI / 2)
		cont("locker", "Locker", 17, hd - t - 1.3, 0)
		cont("techbox", "Relay cabinet", 14, -14, PI / 2)
		cont("toolbox", "Linesman's chest", 36, -14, PI)
		cont("crate", "Spares crate", 26, -20, 0)
		cont("weaponbox", "Sealed crate", 36, -22, 0)

		-- the compound: transformers on the four pads, an electric cabinet or two, sheds are built as ordinary sheds
		for _, y in L.yards do
			local name = y[2]
			if string.sub(name, 1, 14) == "SUBSTATION PAD" then
				local yf = { base = CFrame.new(O.X + y[4], groundAt(y[4], y[5]), O.Z + y[5]) * CFrame.Angles(0, -math.rad(y[8]), 0) }
				local cm = kit.model(name, om)
				local n = 1
				if y[6] * y[7] > 2400 then
					n = 2
				end
				local hu = y[6] / 2 - 9
				for q = 1, n do
					local u = 0
					if n == 2 then
						u = -hu * 0.55 + (q - 1) * hu * 1.1
					end
					transformer(cm, yf, u, 0, 0)
				end
				prop(cm, yf, "ElectricCabinet", -y[6] / 2 + 4, y[7] / 2 - 4, 0, 0.25)
				prop(cm, yf, "HVAC", y[6] / 2 - 8, -y[7] / 2 + 5, PI, 0.25)
				count.struct += 1
			end
		end
		powered.panels[1].Name = "LeverLamp"
		W.switches.MALL_POWER.onChange(false)
		count.struct += 1
		return m
	end

	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	-- camps, checkpoint, pylons
	-- ═════════════════════════════════════════════════════════════════════════════════════════════════════
	-- a canvas tent: vertical walls with a pitched roof, ridge along u, one end open toward the nearest road, a groundsheet
	-- and two cots at the closed end
	local function tent(b)
		local F = frameOf(b)
		local m = kit.model(b[2], om)
		local hw, hd = F.hw, F.hd
		local wh = 4.4
		local rise = hd * 0.45
		local p = math.atan2(rise, hd)
		local len = math.sqrt(hd * hd + rise * rise)
		local CAN, DARK = hex("6F7556"), hex("5C6149")
		local d, px, pz = nearRoad(b[5], b[6])
		local open = 1
		if d < 600 and ((px - b[5]) * F.ca + (pz - b[6]) * F.sa) < 0 then
			open = -1
		end
		box(m, F, 2 * hw, 0.3, 2 * hd, 0, 0.15, 0, hex("4F5238"), M.Fabric)
		for _, sg in { -1, 1 } do
			local panel = kit.boxCF(m, 2 * hw + 0.8, 0.3, len + 0.6, F.base * CFrame.new(0, wh + rise / 2 + 0.3, sg * hd / 2) * CFrame.Angles(sg * p, 0, 0), CAN, M.Fabric)
			panel.CanCollide = false
			local yaw = 0
			if sg > 0 then
				yaw = PI
			end
			-- the gable above the closed end
			local wedge = kit.part(m, Vector3.new(0.4, rise, hd), F.base * CFrame.new(-open * (hw - 0.2), wh + rise / 2, sg * hd / 2) * CFrame.Angles(0, yaw, 0), CAN, M.Fabric, "WedgePart")
			wedge.CanCollide = false
			box(m, F, 2 * hw, wh, 0.3, 0, wh / 2 + 0.15, sg * (hd - 0.15), DARK, M.Fabric).Name = "TentWall"
			-- a post at each corner of the open end
			box(m, F, 0.4, wh, 0.4, open * (hw - 0.4), wh / 2 + 0.15, sg * (hd - 0.4), C.wood, M.Wood)
		end
		box(m, F, 0.3, wh, 2 * hd, -open * (hw - 0.15), wh / 2 + 0.15, 0, DARK, M.Fabric).Name = "TentWall"
		box(m, F, 0.4, wh + rise, 0.4, open * (hw - 0.4), (wh + rise) / 2 + 0.15, 0, C.wood, M.Wood)
		box(m, F, 2 * hw + 0.4, 0.3, 0.3, 0, wh + rise + 0.2, 0, C.wood, M.Wood)
		-- two cots along the walls at the closed end
		for _, sg in { -1, 1 } do
			prop(m, F, "MedCot", -open * (hw - 6), sg * (hd - 3), 0, 0.3)
		end
		count.struct += 1
	end

	-- a shipping container: skids, the body with ribs along both long sides, double doors with lock bars at one end
	local function container(b)
		local F = frameOf(b)
		local m = kit.model(b[2], om)
		local COL = { hex("8E4A36"), hex("3E5A57"), hex("A6702E"), hex("56626E") }
		local col = COL[(b[1] % #COL) + 1]
		local rib = Color3.new(col.R * 0.78, col.G * 0.78, col.B * 0.78)
		local hh, y0 = 8.2, 0.6
		for _, sg in { -1, 1 } do
			box(m, F, 2 * F.hw - 1, 0.6, 1.0, 0, 0.3, sg * (F.hd - 1.2), hex("3A3A36"), M.Metal)
		end
		local body = box(m, F, 2 * F.hw, hh, 2 * F.hd, 0, y0 + hh / 2, 0, col, M.CorrodedMetal)
		body.Name = "ContainerBody"
		local n = math.max(2, math.floor((2 * F.hw - 4) / 5))
		for k = 0, n do
			local u = -F.hw + 2 + (2 * F.hw - 6) * k / n
			for _, sg in { -1, 1 } do
				box(m, F, 0.5, hh - 0.8, 0.3, u, y0 + hh / 2, sg * (F.hd + 0.1), rib, M.Metal)
			end
		end
		local doorEnd = 1
		if b[1] % 2 == 0 then
			doorEnd = -1
		end
		for _, sg in { -1, 1 } do
			box(m, F, 0.3, hh - 0.8, F.hd - 0.5, doorEnd * (F.hw + 0.1), y0 + hh / 2, sg * (F.hd / 2), rib, M.Metal)
			for _, bar in { -0.35, 0.35 } do
				box(m, F, 0.3, hh - 1.2, 0.18, doorEnd * (F.hw + 0.3), y0 + hh / 2, sg * (F.hd / 2) + bar * F.hd * 0.5, hex("2A2C2A"), M.Metal)
			end
		end
		count.struct += 1
	end

	-- the checkpoint: an office and a guardhouse from the ordinary builder, plus a road gate (boom barriers across the road,
	-- a ticket booth, sandbags and signs) at the extract
	local function checkpoint(bs)
		for _, b in bs do
			local m, F, front, doorS = building(b)
			if m and string.find(b[2], "OFFICE", 1, true) then
				doorLeaf(m, F, STYLE.check.t, "MM_RC_OFFICE", "CHECKPOINT OFFICE", front, doorS or 0, 4.4, 8, nil, hex("4F5A5E"))
				local u, v = openingUV(F, front, doorS or 0, STYLE.check.t)
				local o = OUTWARD[front]
				points.RESCUE_CHECKPOINT = wp(F, u + o[1] * 5, 3.3, v + o[2] * 5)
			end
		end
		local ex = nil
		for _, e in L.ext do
			if e[1] == "RC" then
				ex = e
			end
		end
		if not ex then
			return
		end
		local _, rx, rz, dx, dz = nearRoad(ex[4], ex[5])
		local gm = kit.model("CHECKPOINT GATE", om)
		local inside = B.inside
		-- the road runs into the limit at this corner: the gate stands on the inland side of the extract
		if not inside(rx + dx * 40, rz + dz * 40) and inside(rx - dx * 40, rz - dz * 40) then
			dx, dz = -dx, -dz
		end
		local nx, nz = -dz, dx -- across the road
		local halfW = 11.4
		local function at(along, across)
			return rx + dx * along + nx * across, rz + dz * along + nz * across
		end
		local function put(name, along, across, faceX, faceZ)
			local x, z = at(along, across)
			if not inside(x, z) then
				return nil
			end
			local cf = CFrame.new(V(x, groundAt(x, z), z)) * CFrame.Angles(0, math.atan2(-faceX, -faceZ), 0)
			local pm = Kit.place(gm, name, cf, { shadows = false })
			if pm then
				count.prop += 1
			end
			return pm
		end
		-- two booms, staggered so a vehicle has to weave; each faces along the road, so its long side spans the carriageway
		put("ParkingBarrier", 22, 5, dx, dz)
		put("ParkingBarrier", 44, -5, dx, dz)
		put("TicketBooth", 22, halfW + 8, -nx, -nz)
		put("SignPost", 6, halfW + 3, -dx, -dz)
		put("SignPost", 64, -halfW - 3, dx, dz)
		for _, sb in { { 30, halfW + 4 }, { 34, halfW + 6 }, { 52, -halfW - 4 }, { 48, -halfW - 6 }, { 38, halfW + 12 }, { 14, -halfW - 12 } } do
			local sd = 1
			if sb[2] > 0 then
				sd = -1
			end
			put("Sandbags", sb[1], sb[2], sd * nx, sd * nz)
		end
		points.RESCUE_CHECKPOINT = points.RESCUE_CHECKPOINT or V(rx, groundAt(rx, rz) + 3.3, rz)
		points.RESCUE_GATE = V(rx, groundAt(rx, rz) + 3.3, rz)
		count.struct += 1
	end

	-- a sign pylon: plinth, a concrete shaft, a double-sided lit sign near the top
	local function pylon(b, text, bg, fg, trim)
		local F = frameOf(b)
		local m = kit.model(b[2], om)
		local H0, shaft = 88, hex("8C8E88")
		box(m, F, 2 * F.hw, 1.6, 2 * F.hd, 0, 0.8, 0, hex("6A6D68"), M.Concrete).Name = "Plinth"
		local core = box(m, F, 3.6, H0, 3.6, 0, 1.6 + H0 / 2, 0, shaft, M.Concrete)
		core.Name = "Shaft"
		for _, sg in { -1, 1 } do
			box(m, F, 1.2, H0 * 0.55, 6.5, sg * 2.4, 1.6 + H0 * 0.27, 0, hex("7C7E78"), M.Concrete)
		end
		local sy = 1.6 + H0 - 9
		local sign = box(m, F, 38, 14, 1.6, 0, sy, 0, bg, M.Metal)
		sign.Name = "SignBoard"
		sign.CastShadow = false
		kit.sign(sign, Enum.NormalId.Front, text, fg, bg)
		kit.sign(sign, Enum.NormalId.Back, text, fg, bg)
		for _, sg in { -1, 1 } do
			local strip = box(m, F, 38.8, 0.7, 2.0, 0, sy + sg * 7.2, 0, trim, M.Neon)
			strip.CastShadow = false
			strip.CanCollide = false
		end
		box(m, F, 5, 1.2, 5, 0, 1.6 + H0 + 0.6, 0, hex("5E625E"), M.Metal)
		for _, sg in { -1, 1 } do
			local lp = box(m, F, 1.0, 1.0, 1.0, 0, sy, sg * 2.6, trim, M.Neon)
			lp.CanCollide = false
			lp.CastShadow = false
			kit.light(lp, trim, 46, 0.9, false)
			count.light += 1
		end
		count.struct += 1
		return F
	end

	-- ── the work list: THE SUBSTATION first ─────────────────────────────────────────────────────────────
	local byGroup = {}
	for _, b in L.blds do
		byGroup[b[4]] = byGroup[b[4]] or {}
		table.insert(byGroup[b[4]], b)
	end
	for _, b in byGroup.sub or {} do
		step("THE SUBSTATION", function()
			substation(b)
		end)
	end
	for _, g in { "shed", "booth", "hut", "rail", "kart", "camp" } do
		for _, b in byGroup[g] or {} do
			step(b[2], function()
				local m, F = building(b)
				if m and g == "kart" then
					points.KART_PIT = wp(F, 0, 3.3, F.hd + 6)
				end
			end)
		end
	end
	step("RESCUE CAMP", function()
		local cx, cz, n = 0, 0, 0
		for _, b in byGroup.rescue or {} do
			step(b[2], function()
				if string.find(b[2], "TENT", 1, true) then
					tent(b)
				else
					container(b)
				end
			end)
			cx, cz, n = cx + b[5], cz + b[6], n + 1
		end
		if n > 0 then
			points.RESCUE_CAMP = V(cx / n, groundAt(cx / n, cz / n) + 3.3, cz / n)
		end
	end)
	step("RESCUE CHECKPOINT", function()
		checkpoint(byGroup.check or {})
	end)
	step("sign pylons", function()
		for _, b in byGroup.tower or {} do
			if string.find(b[2], "NESTA", 1, true) then
				local F = pylon(b, "NESTA", hex("1F5C5A"), hex("F1E9D2"), hex("9FE3D8"))
				points.NESTA_TOWER = wp(F, 0, 3.3, F.hd + 8)
			else
				local F = pylon(b, "BOLTWORKS", hex("C26B2B"), hex("232526"), hex("FFC27A"))
				points.BOLTWORKS_TOWER = wp(F, 0, 3.3, F.hd + 8)
			end
		end
	end)
	-- the west camp's centre
	local cx, cz, n = 0, 0, 0
	for _, b in byGroup.camp or {} do
		cx, cz, n = cx + b[5], cz + b[6], n + 1
	end
	if n > 0 then
		points.WEST_CAMP = V(cx / n, groundAt(cx / n, cz / n) + 3.3, cz / n)
	end
end
