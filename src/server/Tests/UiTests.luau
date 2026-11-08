--!nonstrict
-- UI checks that run on the server (audit ui.5, ui.9, ui.14): the menu bindings in the shared input map, and the
-- inventory's fit cue (DropRules) against the server's own Inv.move / Inv.transfer on the same holders. The screens
-- themselves are client UI and are checked in Studio by the coordinator. Run with the other test modules (ZR_Dev "tests").
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Services = script.Parent.Parent:WaitForChild("Services")
local InputMap = require(Shared.InputMap)
local Items = require(Shared.Items)
local Drop = require(Shared.DropRules)
local Inv = require(Services.Inv)

local T = {}

local function copy(t)
	if type(t) ~= "table" then
		return t
	end
	local o = {}
	for k, v in t do
		o[k] = copy(v)
	end
	return o
end

function T.run(_ctx)
	local passed, failed, notes = 0, 0, {}
	local function check(name, cond)
		if cond then
			passed += 1
		else
			failed += 1
			table.insert(notes, "FAIL " .. name)
		end
	end

	-- ui.5: in a menu LB and RB step through the open screen's tabs (the console convention; Tarkov has no gamepad)
	local prev, nxt = InputMap.TabPrev, InputMap.TabNext
	check("input map: TabPrev is LB and TabNext is RB, in menus only",
		prev ~= nil and nxt ~= nil and prev.context == "menu" and nxt.context == "menu"
		and prev.pad[1] == Enum.KeyCode.ButtonL1 and nxt.pad[1] == Enum.KeyCode.ButtonR1)
	check("input map: the tab buttons take no PC key (a mouse clicks the tabs)", #prev.keys == 0 and #nxt.keys == 0)
	check("input map: on foot LB and RB still lean (the play context is off while a menu is open)",
		InputMap.LeanLeft.pad[1] == Enum.KeyCode.ButtonL1 and InputMap.LeanLeft.context == "play"
		and InputMap.LeanRight.pad[1] == Enum.KeyCode.ButtonR1 and InputMap.LeanRight.context == "play")
	-- no two actions that can fire in a menu (menu and global contexts) share a gamepad button: Back is B, the tabs LB / RB,
	-- the inventory Y, the settings View; one tapped and one held may (a tap opens the settings, a hold the menu bar)
	local seen, clash = {}, nil
	for action, spec in InputMap do
		if spec.context == "menu" or spec.context == "global" then
			for _, k in spec.pad or {} do
				local other = seen[k]
				if other then
					local a, b = InputMap[other].padHow, spec.padHow
					if not ((a == "tap" and b == "hold") or (a == "hold" and b == "tap")) then
						clash = other .. " and " .. action .. " on " .. k.Name
					end
				end
				seen[k] = action
			end
		end
	end
	check("input map: the menu bar is M and a held View, Tarkov's screens on H, Y, U, K and J (ui-6a)",
		InputMap.MenuBar and InputMap.MenuBar.keys[1] == Enum.KeyCode.M and InputMap.MenuBar.pad[1] == Enum.KeyCode.ButtonSelect
		and InputMap.MenuBar.padHow == "hold" and InputMap.Settings.padHow == "tap" and InputMap.ScreenHideout.keys[1] == Enum.KeyCode.H
		and InputMap.ScreenTraders.keys[1] == Enum.KeyCode.Y and InputMap.ScreenFlea.keys[1] == Enum.KeyCode.U
		and InputMap.ScreenHandbook.keys[1] == Enum.KeyCode.K and InputMap.ScreenMessenger.keys[1] == Enum.KeyCode.J)
	check("input map: one action per gamepad button in menus" .. (clash and (" (" .. clash .. ")") or ""), clash == nil)

	-- ui.9: the green / red fit cue says what the server will do with the drop. Each case plans a drop with DropRules,
	-- runs the same request through Inv.move (or Inv.transfer between holders) on a copy of the holder, and checks that
	-- the two agree, and that the case comes out as Tarkov's rules say
	local okDrop, errDrop = pcall(function()
		local h = Inv.newHolder("profile")
		local function put(holder, id, n, x, y, cid, r)
			local g, it = Inv.newItem(id, n)
			holder.items[g] = it
			holder.grids[cid or "stash"][g] = { x = x, y = y, r = r or 0 }
			if Items.defs[id].grid then
				holder.grids[g] = holder.grids[g] or {}
			end
			return g
		end
		-- rows 3 to 6 stay free (a gun that grows with its magazine keeps room where it lies), rows 14 on too
		local rifle = put(h, "R17_RIFLE", 1, 1, 1) -- 5 x 2
		local mag = put(h, "R17_MAG", 1, 7, 1) -- 1 x 2
		local ammo = put(h, "A62_FMJ", 30, 8, 1) -- a stack of 60 at most
		local full = put(h, "A62_FMJ", 60, 9, 1)
		local loose = put(h, "A62_FMJ", 10, 10, 1)
		local chain = put(h, "GOLD_CHAIN", 1, 10, 2)
		local sling = put(h, "BAG_SLING", 1, 1, 7) -- 2 x 2, holds 3 x 2
		local canvas = put(h, "CANVAS_BAG", 1, 4, 7) -- 3 x 3, holds 4 x 4
		local secure = put(h, "SECURE_S", 1, 8, 7)
		local helmet = put(h, "HELMET_C4", 1, 1, 11)
		local armor2 = put(h, "ARMOR_C2", 1, 4, 11)
		local inside = put(h, "BOLTS", 1, 1, 1, sling) -- something in the sling
		local worn, wornIt = Inv.newItem("ARMOR_C3", 1)
		Inv.placeSlot(h, worn, wornIt, "armor")
		local flat = { r = 0, r0 = 0, grabX = 0, grabY = 0 }
		local function cell(x, y, cid, occupied)
			return { kind = "cell", cid = cid or "stash", x = x, y = y, occupied = occupied }
		end
		local function agree(name, src, g, dst, tgt, dd, expect, inRaid)
			local plan = Drop.plan(src, g, dst, tgt, dd or flat, inRaid)
			if not plan then
				check("fit cue: " .. name .. " (no plan)", false)
				return
			end
			local okS
			if src == dst then
				okS = Inv.move(copy(src), g, plan.dest, { inRaid = inRaid })
			else
				okS = Inv.transfer(copy(src), g, copy(dst), plan.dest, nil, { inRaid = inRaid })
			end
			check(string.format("fit cue: %s (cue %s, server %s)", name, tostring(plan.ok), tostring(okS)), plan.ok == (okS == true) and plan.ok == expect)
		end
		agree("a 1 x 1 onto a free cell", h, chain, h, cell(6, 16), nil, true)
		agree("the rifle over the magazine and ammo beside it is refused", h, rifle, h, cell(6, 1), nil, false)
		agree("the rifle hanging past the stash's edge is refused", h, rifle, h, cell(8, 17), nil, false)
		agree("the rifle turned upright (R) fits where it lies flat does not", h, rifle, h, cell(9, 15), { r = 1, r0 = 0, grabX = 0, grabY = 0 }, true)
		agree("the rifle flat at the same cell does not", h, rifle, h, cell(9, 15), nil, false)
		agree("ammo onto a stack of its kind with room merges", h, loose, h, cell(8, 1, "stash", ammo), nil, true)
		agree("ammo onto a full stack is refused", h, loose, h, cell(9, 1, "stash", full), nil, false)
		agree("a magazine onto its rifle loads it", h, mag, h, cell(1, 1, "stash", rifle), nil, true)
		agree("a magazine whose corner lands on the rifle loads it too (Inv.move reads the corner cell)", h, mag, h, cell(5, 3), { r = 0, r0 = 0, grabX = 0, grabY = 1 }, true)
		agree("a chain onto a backpack goes inside", h, chain, h, cell(1, 7, "stash", sling), nil, true)
		agree("a backpack into a backpack is refused", h, sling, h, cell(4, 7, "stash", canvas), nil, false)
		agree("a secure container into a backpack is refused", h, secure, h, cell(4, 7, "stash", canvas), nil, false)
		agree("a backpack into its own grid is refused", h, sling, h, cell(3, 2, sling), nil, false)
		agree("ammo onto a gold chain is refused (the cell is taken)", h, loose, h, cell(10, 2, "stash", chain), nil, false)
		agree("a helmet into the head slot", h, helmet, h, { kind = "slot", slot = "head" }, nil, true)
		agree("a helmet into the armour slot is refused", h, helmet, h, { kind = "slot", slot = "armor" }, nil, false)
		agree("armour into a taken armour slot is refused", h, armor2, h, { kind = "slot", slot = "armor" }, nil, false)
		agree("the item in the sling into the pockets", h, inside, h, cell(1, 1, "pockets"), nil, true)
		-- between holders (a crate in a raid): onto a free cell, and onto a stack of its kind
		local box = Inv.newHolder("box", 5, 4)
		local crateAmmo = put(box, "A62_FMJ", 20, 1, 1, "main")
		local crateChain = put(box, "GOLD_CHAIN", 1, 3, 1, "main")
		agree("from a crate onto a free stash cell", box, crateChain, h, cell(6, 18), nil, true)
		agree("from a crate onto a stack of its kind in the stash", box, crateAmmo, h, cell(8, 1, "stash", ammo), nil, true)
		agree("from the stash into a crate's taken cell is refused", h, chain, box, cell(1, 1, "main", crateAmmo), nil, false)
		-- the secure container stays on in a raid
		local h2 = Inv.newHolder("profile")
		local sec2, sec2It = Inv.newItem("SECURE_S", 1)
		Inv.placeSlot(h2, sec2, sec2It, "secure")
		agree("the worn secure container does not move in a raid", h2, sec2, h2, cell(1, 1, "pockets"), nil, false, true)
		-- plates (gameplay-2a): a plate onto a vest's tile goes into a slot that takes it; onto the worn vest it is refused
		-- (Tarkov 0.14: take it off first); a plate it replaces goes to the stash out of a raid, to the carried grids in one
		local hp = Inv.newHolder("profile")
		local vest = put(hp, "ARMOR_C4", 1, 1, 1) -- 3 x 3: a front and a back slot, both empty
		local frontP = put(hp, "PLATE_PC4F", 1, 5, 1)
		local westP = put(hp, "PLATE_CE4", 1, 8, 1) -- west: fits only the back slot
		local sideP = put(hp, "PLATE_HP5S", 1, 1, 5)
		local vest2 = put(hp, "ARMOR_C4", 1, 1, 8)
		local inFront = put(hp, "PLATE_PC4F", 1, 5, 8)
		Inv.attachPlate(hp, vest2, "front", inFront, { "stash" })
		local wornVest, wornVestIt = Inv.newItem("ARMOR_C4", 1)
		Inv.placeSlot(hp, wornVest, wornVestIt, "armor")
		agree("a front plate onto a vest's tile goes into its front slot", hp, frontP, hp, cell(1, 1, "stash", vest), nil, true)
		agree("a west plate onto the same vest goes into its back slot", hp, westP, hp, cell(2, 2, "stash", vest), nil, true)
		agree("a side plate onto a vest with no side slots is refused", hp, sideP, hp, cell(1, 1, "stash", vest), nil, false)
		local wornPlan = Drop.plan(hp, westP, hp, { kind = "slot", slot = "armor" }, flat)
		check("fit cue: a plate onto the worn vest is red, take it off first", wornPlan ~= nil and wornPlan.ok == false and wornPlan.why == "TAKE_OFF_FIRST"
			and select(2, Inv.move(copy(hp), westP, { slot = "armor" })) == "TAKE_OFF_FIRST")
		agree("a plate replacing one in the bunker sends the old one to the stash", hp, frontP, hp, cell(1, 8, "stash", vest2), nil, true)
		agree("a plate replacing one in a raid with nowhere for the old one is refused", hp, frontP, hp, cell(1, 8, "stash", vest2), nil, false, true)
	end)
	if not okDrop then
		check("fit cue: the checks ran without an error (" .. tostring(errDrop) .. ")", false)
	end

	-- every item a player can carry has an inventory picture (a rendered icon, or a weapon part's own picture)
	do
		local Icons = require(Shared.ItemIcons)
		local WP = require(Shared.WeaponParts)
		local none = {}
		for id, d in Items.defs do
			if not Icons.items[id] and not WP.parts[id] and d.kind ~= "hazard" then
				table.insert(none, id)
			end
		end
		table.sort(none)
		check("every carried item has a picture" .. (#none > 0 and (" (none: " .. table.concat(none, ", ") .. ")") or ""), #none == 0)
	end

	-- accessibility (ui-8a) and the recorder overlay (ui-2b): the settings request takes the new rows (the menu text size
	-- clamped to 150 % and kept per device too) and refuses a wrong type; the profile's settings are put back after
	do
		local pl = game:GetService("Players"):GetPlayers()[1]
		local prof = pl and _ctx and _ctx.Profiles.get(pl)
		if prof and prof.settings then
			local keep = copy(prof.settings)
			local r1 = _ctx.Remotes.dispatch(pl, "settings", { cvdMode = 2, cvdK = 0.5, menuScale = 1.3, hints = false, recOverlay = 1, dev = { phone = { menuScale = 1.4 } } })
			local s = prof.settings
			local took = r1 and r1.ok and s.cvdMode == 2 and s.cvdK == 0.5 and s.menuScale == 1.3 and s.hints == false and s.recOverlay == 1
				and type(s.dev) == "table" and type(s.dev.phone) == "table" and s.dev.phone.menuScale == 1.4
			task.wait(0.6)
			local r2 = _ctx.Remotes.dispatch(pl, "settings", { menuScale = 9, recOverlay = 0 })
			local clamped = r2 and r2.ok and prof.settings.menuScale == 1.5 and prof.settings.recOverlay == 1
			task.wait(0.6)
			local r3 = _ctx.Remotes.dispatch(pl, "settings", { hints = "no" })
			prof.settings = keep
			check("accessibility settings: colorblind mode and intensity, menu text size (to 150 %, per device), hints and the recorder overlay are kept; a wrong type is refused",
				took and clamped and r3 ~= nil and not r3.ok)
		else
			table.insert(notes, "accessibility settings: no player in the playtest")
		end
	end

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T
