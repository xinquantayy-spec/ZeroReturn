--!nonstrict
-- M16 character / equipment checks (kit TESTS/AUTOMATED_VALIDATION.md C01-C12, the parts a single Studio server can
-- run). Builds dummies on a hidden stage through the real rig + Appearance path, drives equipment through Inv (and
-- the real "inv" request handler with a test-double player), and reports one line per check with its test id.
-- Run via ZR_Dev "chartests". Nothing here touches a real player's profile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Items = require(Shared.Items)
local AssetMeta = require(Shared.AssetMeta)
local Equipment = require(Shared.Equipment)

local CT = {}

function CT.run(ctx)
	local results = {}
	local function check(id, name, cond, note)
		table.insert(results, { id = id, name = name, ok = cond and true or false, note = note })
	end
	local Inv, Appearance = ctx.Inv, ctx.Appearance
	local lib = ReplicatedStorage:FindFirstChild("ZR_Assets")
	local stage = workspace:FindFirstChild("ZR_CharTest")
	if stage then
		stage:Destroy()
	end
	stage = Instance.new("Folder")
	stage.Name = "ZR_CharTest"
	stage.Parent = workspace
	local n = 0
	local function dummy(look, variant)
		n += 1
		local rig = ctx.Chars.buildRig(look, variant)
		rig.Name = "CT_" .. look .. "_" .. n
		rig:PivotTo(CFrame.new(n * 7, 3.21, 1400))
		rig.HumanoidRootPart.Anchored = true
		rig.Parent = stage
		return rig
	end
	local function holder()
		return { slots = {}, items = {}, grids = {} }
	end
	local function give(h, slot, id, tint)
		local g, it = Inv.newItem(id, 1, tint and { tint = tint } or nil)
		local ok, err = Inv.placeSlot(h, g, it, slot)
		return ok and g or nil, err
	end
	local function drop(h, slot)
		local g = h.slots[slot]
		if g then
			Inv.setSlot(h, slot, nil)
			h.items[g] = nil
			h.grids[g] = nil
		end
	end
	local function apply(m, h, extra)
		local spec = { holder = h, weapons = false }
		for k, v in extra or {} do
			spec[k] = v
		end
		return Appearance.apply(m, spec)
	end
	local function keys(m, group)
		local d = Appearance.describe(m)
		return d[group] and table.concat(d[group], "+") or ""
	end
	local function gearParts(m)
		local list = {}
		for _, c in m:GetChildren() do
			if c:GetAttribute("ZR_Gear") then
				table.insert(list, c)
			end
		end
		return list
	end
	local function firstOf(m, group)
		for _, c in m:GetChildren() do
			if c:GetAttribute("ZR_Gear") == group then
				return c
			end
		end
		return nil
	end

	-- ── C01: definitions resolve to imported meshes ─────────────────────────────────────────────────────────
	local missingMeta, missingLib, missingSize, pendingLib, stalePending = {}, {}, {}, {}, {}
	for _, key in Equipment.allKeys() do
		if not AssetMeta[key] then
			table.insert(missingMeta, key)
		end
		if not Equipment.SIZE[key] then
			table.insert(missingSize, key)
		end
		local imported = lib and lib:FindFirstChild(key) and lib[key]:IsA("MeshPart")
		if not imported then
			-- authored in build_eyewear.py but not uploaded yet (Equipment.PENDING): neutral boxes, listed here, not hidden
			table.insert(Equipment.PENDING[key] and pendingLib or missingLib, key)
		elseif Equipment.PENDING[key] then
			table.insert(stalePending, key)
		end
	end
	check("C01", "every equipment mesh key has an AssetMeta offset and a fallback size", #missingMeta == 0 and #missingSize == 0, table.concat(missingMeta, ",") .. table.concat(missingSize, ","))
	check("C01", "every equipment mesh imported as a MeshPart (ZR_CharGear / ZR_CharBase), apart from the pending ZR_EyeGear batch", #missingLib == 0,
		#missingLib > 0 and ("missing " .. table.concat(missingLib, ",")) or (#Equipment.allKeys() - #pendingLib .. " meshes"))
	check("C01", "pending meshes (build_eyewear.py not uploaded yet) are all of the ZR_EyeGear batch and none is still listed once imported", #stalePending == 0,
		#stalePending > 0 and ("imported, remove from Equipment.PENDING: " .. table.concat(stalePending, ",")) or (#pendingLib .. " pending: neutral boxes in use, KNOWN_ISSUES 64"))
	local noVis = {}
	for id, d in Items.defs do
		local slotKinds = { helmet = true, headwear = true, headset = true, facecover = true, eyewear = true, armor = true, rig = true, backpack = true }
		if slotKinds[d.kind] and not Equipment.VIS[id] then
			table.insert(noVis, id)
		end
	end
	check("C01", "every wearable item has a visual definition", #noVis == 0, table.concat(noVis, ","))
	local sizeOk = true
	for _, key in Equipment.allKeys() do
		local m = lib and lib:FindFirstChild(key)
		if m and m:IsA("MeshPart") and (m.Size - Equipment.SIZE[key]).Magnitude > 0.02 then
			sizeOk = false
			check("C01", "imported size matches the Blender export: " .. key, false, tostring(m.Size) .. " vs " .. tostring(Equipment.SIZE[key]))
		end
	end
	check("C01", "imported mesh sizes match the Blender exports (studs, no scale factor)", sizeOk)

	-- ── C03: equip A, replace with B, unequip; per-slot diff; covered regions restore ────────────────────────
	local m = dummy("player")
	local h = holder()
	apply(m, h)
	local base = #gearParts(m)
	give(h, "head", "HELMET_C3")
	apply(m, h)
	local partA = firstOf(m, "head")
	check("C03", "helmet A equipped: head shows ZR_EQ_HelmetA", keys(m, "head") == "ZR_EQ_HelmetA" and m:GetAttribute("Gear_head") == "HELMET_C3")
	drop(h, "head")
	give(h, "head", "HELMET_C2")
	apply(m, h)
	check("C03", "replaced by helmet B: only ZR_EQ_HelmetB remains, A destroyed", keys(m, "head") == "ZR_EQ_HelmetB" and partA.Parent == nil)
	drop(h, "head")
	apply(m, h)
	check("C03", "unequipped: no head piece, gear count back to the base", keys(m, "head") == "" and #gearParts(m) == base and m:GetAttribute("Gear_head") == nil)
	give(h, "head", "HELMET_C3")
	give(h, "back", "BAG_PATROL")
	apply(m, h)
	local headKeep = firstOf(m, "head")
	local outfitKeep = firstOf(m, "outfit")
	drop(h, "back")
	give(h, "back", "BAG_RAID")
	local rev0 = m:GetAttribute("AppearanceRev")
	apply(m, h)
	check("C03", "per-slot diff: changing the backpack keeps the helmet and outfit instances", firstOf(m, "head") == headKeep and firstOf(m, "outfit") == outfitKeep
		and string.find(keys(m, "back"), "ZR_EQ_PackRaid", 1, true) ~= nil and m:GetAttribute("AppearanceRev") == rev0 + 1)
	local rev1 = m:GetAttribute("AppearanceRev")
	local before = #gearParts(m)
	apply(m, h)
	check("C06", "reconstruction is idempotent (same state: no rebuild, same revision, no duplicates)", m:GetAttribute("AppearanceRev") == rev1 and #gearParts(m) == before)
	-- covered region: a backpack hides the chest rig's back harness; it comes back without the pack
	give(h, "rig", "RIG_CHEST")
	apply(m, h)
	local withPack = keys(m, "rig")
	drop(h, "back")
	apply(m, h)
	local noPack = keys(m, "rig")
	check("C03", "covered region: chest-rig back harness hidden under a backpack, restored without it", string.find(withPack, "ChestRigBack", 1, true) == nil and string.find(noPack, "ChestRigBack", 1, true) ~= nil)

	-- ── compatibility matrix (Inv.canEquip through Equipment) ───────────────────────────────────────────────
	local hc = holder()
	give(hc, "head", "HELMET_C2")
	local _, e1 = give(hc, "ears", "HEADSET_GS1")
	check("C05", "headset refused under a full-cut helmet", e1 == "HELMET_COVERS_EARS")
	local hd = holder()
	give(hd, "ears", "HEADSET_GS1")
	local _, e2 = give(hd, "head", "HELMET_C2")
	local _, e2b = give(hd, "head", "HARDHAT_FOREMAN")
	check("C05", "full-cut helmet and hard hat refused over a headset", e2 == "HELMET_COVERS_EARS" and e2b == "HARD_HAT_BRIM")
	local hp = holder()
	give(hp, "armor", "ARMOR_C4")
	local _, e3 = give(hp, "rig", "RIG_PLATE")
	check("C05", "armoured rig refused over body armour (no duplicate overlapping rigs)", e3 == "ARMOR_CONFLICT")
	local mh = dummy("player")
	local hh = holder()
	give(hh, "ears", "HEADSET_GS1")
	apply(mh, hh)
	local bare = keys(mh, "ears")
	give(hh, "head", "HELMET_C3")
	apply(mh, hh)
	local under = keys(mh, "ears")
	drop(hh, "head")
	give(hh, "head", "CAP_FIELD")
	apply(mh, hh)
	check("C03", "headset band goes over a bare head, behind the neck under a cut helmet or cap", bare == "ZR_EQ_Headset" and under == "ZR_EQ_HeadsetNeck" and keys(mh, "ears") == "ZR_EQ_HeadsetNeck")

	-- ── layering: rigs scale over armour, packs move back, the body camera forward ──────────────────────────
	local ml = dummy("player")
	local hl = holder()
	give(hl, "armor", "ARMOR_C4")
	give(hl, "rig", "RIG_CHEST")
	give(hl, "back", "BAG_PATROL")
	apply(ml, hl)
	local rig = nil
	for _, c in gearParts(ml) do
		if c:GetAttribute("Key") == "ZR_EQ_ChestRig" then
			rig = c
		end
	end
	local pack, cam
	for _, c in gearParts(ml) do
		if c:GetAttribute("Key") == "ZR_EQ_PackA" then
			pack = c
		elseif c:GetAttribute("Key") == "ZR_EQ_BodyCam" then
			cam = c
		end
	end
	local torso = ml.UpperTorso
	local packZ = pack and torso.CFrame:PointToObjectSpace(pack.Position).Z
	local camZ = cam and torso.CFrame:PointToObjectSpace(cam.Position).Z
	check("C02", "chest rig over a carrier is scaled clear of it", rig ~= nil and rig.Size.Z > lib.ZR_EQ_ChestRig.Size.Z * 1.2)
	check("C02", "backpack moved back by the carrier, body camera forward", packZ ~= nil and math.abs(packZ - (AssetMeta.ZR_EQ_PackA.Z + 0.17)) < 0.01 and camZ ~= nil and camZ < AssetMeta.ZR_EQ_BodyCam.Z - 0.2)

	-- ── C04: delayed asset loading: the latest equipment wins, the fallback never changes protection ─────────
	local stash = lib and lib:FindFirstChild("ZR_EQ_HelmetB")
	if stash then
		stash.Parent = nil -- simulate a batch that has not arrived yet
		local m4 = dummy("guard")
		local h4 = holder()
		give(h4, "head", "HELMET_C2")
		apply(m4, h4)
		local fb1 = keys(m4, "head")
		local fbPart = firstOf(m4, "head")
		local fbSafe = fbPart and fbPart.CanQuery == false and fbPart.CanCollide == false and fbPart.Massless
		drop(h4, "head")
		give(h4, "head", "HELMET_C3")
		apply(m4, h4)
		local mid = keys(m4, "head")
		drop(h4, "head")
		give(h4, "head", "HELMET_C2")
		apply(m4, h4)
		local revFb = m4:GetAttribute("AppearanceRev")
		local cls = Items.defs[h4.items[h4.slots.head].id].armor.class
		stash.Parent = lib
		ctx.Assets.announce("chartest")
		task.wait()
		check("C04", "missing mesh: neutral fallback box, decorative only", fb1 == "ZR_EQ_HelmetB(fallback)" and fbSafe == true)
		check("C04", "asset arrives: reconciled to the latest state (helmet B mesh), revision bumped", mid == "ZR_EQ_HelmetA" and keys(m4, "head") == "ZR_EQ_HelmetB"
			and m4:GetAttribute("AppearanceRev") > revFb)
		check("C04", "protection comes from the item (class 2 shell), not from the loaded mesh", cls == 2 and Items.defs.HELMET_C2.armor.class == 2)
	else
		check("C04", "delayed-load simulation", false, "ZR_EQ_HelmetB not in the library")
	end

	-- ── C05: invalid requests through the real "inv" handler (test-double player, fresh profile) ────────────
	local fake = { Name = "CT_fake", UserId = -16 }
	local prof = require(script.Parent.Parent.Services.Settle).newProfile()
	ctx.Profiles.attachTest(fake, prof)
	local okRun, err = pcall(function()
		local rid = 0
		local function req(p)
			rid += 1
			p.rid = "ct" .. rid
			return ctx.Remotes.dispatch(fake, "inv", p)
		end
		local hg, hit = Inv.newItem("HELMET_C3", 1)
		Inv.place(prof, hg, hit, { "stash" })
		local sg, sit = Inv.newItem("HEADSET_GS1", 1)
		Inv.place(prof, sg, sit, { "stash" })
		local r0 = req({ op = "equip", g = "not-a-real-guid", from = "me" })
		check("C05", "foreign / unknown item instance refused", r0.ok == false and r0.code == "NO_ITEM")
		local cur = prof.erev or 0
		local rs = req({ op = "equip", g = hg, from = "me", rev = cur + 7 })
		check("C05", "stale equipment revision refused", rs.ok == false and rs.code == "STALE_REVISION" and prof.slots.head ~= hg)
		local rb = req({ op = "equip", g = hg, from = "me", rev = cur, visual = "ZR_EQ_HardHat", mesh = "rbxassetid://1", armor = { class = 6 } })
		check("C05", "client-sent visual / mesh / armour fields ignored: the item's own definition rules", rb.ok == true and prof.slots.head == hg and prof.items[hg].id == "HELMET_C3"
			and prof.items[hg].armor == nil and Items.defs.HELMET_C3.armor.class == 3 and prof.erev == cur + 1)
		local rw = req({ op = "move", g = sg, from = "me", dest = { slot = "back" }, rev = prof.erev })
		check("C05", "item into an incompatible slot refused", rw.ok == false and rw.code == "WRONG_SLOT")
		-- swap to a full-cut shell, then the headset must be refused
		req({ op = "quick", g = hg, from = "me", to = "stash" })
		local fg, fit = Inv.newItem("HELMET_C2", 1)
		Inv.place(prof, fg, fit, { "stash" })
		req({ op = "equip", g = fg, from = "me", rev = prof.erev })
		local rh = req({ op = "equip", g = sg, from = "me", rev = prof.erev })
		check("C05", "incompatible combination refused by the server (headset under a full-cut helmet)", prof.slots.head == fg and rh.ok == false and rh.code == "HELMET_COVERS_EARS")
		local rc = req({ op = "quick", g = sg, from = "c:nope", to = "me" })
		check("C05", "wrong character state: raid containers refused in the safehouse", rc.ok == false and rc.code == "NOT_IN_RAID")
		if ctx.Match.testQueue then
			ctx.Match.testQueue(fake, "pmc")
			local rq = req({ op = "equip", g = sg, from = "me", rev = prof.erev })
			ctx.Match.testQueue(fake, nil)
			check("C05", "wrong character state: committed (queued) loadout refused", rq.ok == false and rq.code == "QUEUED")
		end
	end)
	ctx.Profiles.detachTest(fake)
	if not okRun then
		check("C05", "invalid-request suite ran", false, tostring(err))
	end

	-- ── C07: decorative gear never collides, blocks shots or changes hit regions ────────────────────────────
	local m7 = dummy("player")
	local h7 = holder()
	give(h7, "head", "HELMET_C2")
	give(h7, "armor", "ARMOR_C4")
	give(h7, "rig", "RIG_CHEST")
	give(h7, "back", "BAG_RAID")
	apply(m7, h7)
	local flagsOk = true
	for _, p in gearParts(m7) do
		if p.CanCollide or p.CanQuery or p.CanTouch or not p.Massless or p.Anchored then
			flagsOk = false
		end
	end
	check("C07", "worn pieces: no collision, queries or touch; massless, welded", flagsOk and #gearParts(m7) >= 6)
	local params = ctx.Combat.filter(workspace:FindFirstChild("ZR_Showroom") or Instance.new("Folder"))
	local tcf = m7.UpperTorso.CFrame
	local from = tcf * Vector3.new(0, 0, 6)
	local res = workspace:Raycast(from, (tcf.Position - from).Unit * 8, params)
	check("C07", "a shot from behind passes the backpack and hits the thorax (UpperTorso)", res ~= nil and res.Instance == m7.UpperTorso)
	local side = tcf * Vector3.new(-4, 0, 1.0)
	local res2 = workspace:Raycast(side, tcf.RightVector * 8, params)
	check("C07", "a shot through the backpack alone (outside the body) hits nothing on the character",
		res2 == nil or not res2.Instance:IsDescendantOf(m7))
	local hres = workspace:Raycast(m7.Head.Position + Vector3.new(0, 4, 0), Vector3.new(0, -5, 0), params)
	check("C07", "a shot down through the helmet hits the head part (armour decided by Health from the item)", hres ~= nil and hres.Instance == m7.Head)

	-- ── C09: role presets through the same rig / loadout / appearance path ─────────────────────────────────
	local function preset(name, seed)
		local P = Equipment.PRESETS[name]
		local hh2 = P.ai and ctx.AI.loadoutFor(P.ai, Random.new(seed)) or nil
		if not hh2 then
			hh2 = holder()
			for slot, id in P.kit do
				give(hh2, slot, id)
			end
		end
		local mm = dummy(P.look, 1)
		apply(mm, hh2)
		return mm, hh2
	end
	local function conflictsIn(hx)
		local worn = {}
		for s, g in hx.slots do
			worn[s] = hx.items[g] and hx.items[g].id
		end
		for s, id in worn do
			local others = table.clone(worn)
			others[s] = nil
			if Equipment.conflict(others, s, id) then
				return s .. ":" .. id
			end
		end
		return nil
	end
	local op, ho = preset("operator", 1)
	check("C09", "operator: helmet A, headset behind the neck, armoured rig, patrol pack, body camera, knee pads",
		keys(op, "head") == "ZR_EQ_HelmetA" and keys(op, "ears") == "ZR_EQ_HeadsetNeck" and keys(op, "rig") == "ZR_EQ_CarrierA+ZR_EQ_CarrierPouches"
		and keys(op, "back") == "ZR_EQ_PackA+ZR_EQ_PackStraps" and keys(op, "bodycam") == "ZR_EQ_BodyCam" and keys(op, "outfit") == "ZR_OV_KneePads+ZR_OV_KneePads"
		and conflictsIn(ho) == nil)
	local fo, hf = preset("foreman", 7)
	check("C09", "Foreman: hard hat, padded jacket, fleece collar, boot cuffs; armour worn but concealed",
		keys(fo, "head") == "ZR_EQ_HardHat" and string.find(keys(fo, "outfit"), "ZR_OV_PaddedJacket", 1, true) ~= nil and string.find(keys(fo, "outfit"), "ZR_OV_FleeceCollar", 1, true) ~= nil
		and keys(fo, "armor") == "" and fo:GetAttribute("Gear_armor") == "ARMOR_C5" and conflictsIn(hf) == nil)
	local bg, hb = preset("bodyguard", 3)
	check("C09", "bodyguard: guard-style kit + comms headset (boom mic) + white shoulder markers",
		keys(bg, "ears") == "ZR_EQ_BoomMic+ZR_EQ_HeadsetNeck" and string.find(keys(bg, "outfit"), "ZR_OV_ShoulderMarker+ZR_OV_ShoulderMarker", 1, true) ~= nil
		and conflictsIn(hb) == nil)
	local gd, hgd = preset("guard", 5)
	check("C09", "guard: faction armband, coordinated kit", string.find(keys(gd, "outfit"), "ZR_OV_Armband", 1, true) ~= nil and conflictsIn(hgd) == nil)
	local sc, hs = preset("scavenger", 11)
	check("C09", "scavenger: scav outfit, no body camera, valid kit", sc:GetAttribute("Look") == "scav" and keys(sc, "bodycam") == "" and conflictsIn(hs) == nil)
	-- many seeded kits: never an invalid combination
	local bad = nil
	for _, ai in { "scav", "watch", "follower", "boss" } do
		for seed = 1, 120 do
			local hx = ctx.AI.loadoutFor(ai, Random.new(seed))
			local c = hx and conflictsIn(hx)
			if c then
				bad = ai .. "#" .. seed .. " " .. c
				break
			end
		end
	end
	check("C09", "480 seeded AI kits: no incompatible worn combination", bad == nil, bad)
	local distinct = {}
	for _, mm in { op, sc, gd, bg, fo } do
		local d = Appearance.describe(mm)
		local sigParts = {}
		for g, ks in d do
			table.insert(sigParts, g .. "=" .. table.concat(ks, "+"))
		end
		table.sort(sigParts)
		distinct[mm:GetAttribute("Look") .. ":" .. table.concat(sigParts, ";")] = true
	end
	local nd = 0
	for _ in distinct do
		nd += 1
	end
	check("C09", "the five presets look distinct", nd == 5)

	-- ── C13: eyewear, the gas mask and goggles on the mount: visuals through the real path, protection from the item ──
	local function bareKey(model, group)
		return (string.gsub(keys(model, group), "%(fallback%)", ""))
	end
	local me = dummy("player")
	local he = holder()
	give(he, "eyes", "GLASSES_SUN")
	apply(me, he)
	local eyesPart = firstOf(me, "eyes")
	local fbOk = true
	if eyesPart and not eyesPart:IsA("MeshPart") then
		-- the mesh is not uploaded yet: a decorative box in the item's fallback colour (protection never depends on it)
		fbOk = eyesPart.CanQuery == false and eyesPart.CanCollide == false and eyesPart.Massless
			and string.upper(eyesPart.Color:ToHex()) == Equipment.VIS.GLASSES_SUN.pieces[1].fb
	end
	check("C13", "sunglasses in the eyes slot: the eyes group shows ZR_EQ_GlassSun (a fallback box until uploaded) and Gear_eyes is set",
		bareKey(me, "eyes") == "ZR_EQ_GlassSun" and me:GetAttribute("Gear_eyes") == "GLASSES_SUN" and eyesPart ~= nil and fbOk)
	local hm = holder()
	give(hm, "eyes", "GLASSES_BG1")
	local _, eMaskRefused = give(hm, "face", "GAS_MASK")
	drop(hm, "eyes")
	give(hm, "face", "GAS_MASK")
	local _, eGlassRefused = give(hm, "eyes", "GLASSES_SUN")
	local mm = dummy("player")
	apply(mm, hm)
	check("C13", "gas mask and glasses refuse each other either way round; the mask shows in the face group, the eyes group stays empty",
		eMaskRefused == "GAS_MASK_BLOCKS_EYEWEAR" and eGlassRefused == "GAS_MASK_BLOCKS_EYEWEAR" and bareKey(mm, "face") == "ZR_EQ_GasMask" and bareKey(mm, "eyes") == "")
	-- goggles on the helmet's mount: up by default, down when the character's NvDown attribute is set; only that group is rebuilt
	local mn = dummy("player")
	local hn = holder()
	give(hn, "head", "HELMET_C3")
	local helmItem = hn.items[hn.slots.head]
	helmItem.mods = { mount = "NVG1" }
	hn.items.NVG1 = { id = "NV_BINO", n = 1 }
	apply(mn, hn)
	local headKeep2 = firstOf(mn, "head")
	local upKey = bareKey(mn, "nvg")
	local revUp = mn:GetAttribute("AppearanceRev")
	mn:SetAttribute("NvDown", true)
	apply(mn, hn)
	local downKey = bareKey(mn, "nvg")
	check("C13", "goggles on the helmet mount: up by default, down when NvDown is set; only the nvg group is rebuilt (helmet kept)",
		upKey == "ZR_EQ_NvBinoUp" and downKey == "ZR_EQ_NvBinoDown" and firstOf(mn, "head") == headKeep2 and mn:GetAttribute("AppearanceRev") == revUp + 1)
	helmItem.mods = nil
	hn.items.NVG1 = nil
	apply(mn, hn)
	check("C13", "goggles taken off the mount leave nothing drawn, whatever NvDown says", bareKey(mn, "nvg") == "" and keys(mn, "head") ~= "")
	-- protection: ballistic glasses guard the eye band; Health decides from the item (the mesh and the fallback never matter)
	local function hitAt(worn, at, opts)
		opts = opts or {}
		local mx = dummy("guard")
		local hx = holder()
		for slot, id in worn do
			give(hx, slot, id)
		end
		if opts.dur then
			hx.items[hx.slots.eyes].dur = opts.dur
		end
		ctx.Health.attach(mx, { kind = "ai", holder = function()
			return hx
		end })
		if opts.visorUp then
			mx:SetAttribute("VisorUp", true)
		end
		local r = ctx.Health.hit(mx, { dmg = 4, pen = 6, part = mx.Head, hitPos = mx.Head.CFrame * at })
		ctx.Health.states[mx] = nil
		return r, hx
	end
	local EYES, JAW, BROW, CROWN = Vector3.new(0.2, 0.07, -0.58), Vector3.new(0, -0.3, -0.58), Vector3.new(0, 0.4, -0.58), Vector3.new(0, 0.5, 0)
	local rBG, hBG = hitAt({ eyes = "GLASSES_BG1" }, EYES)
	local rAF = hitAt({ eyes = "GLASSES_AF2" }, EYES)
	local rSun = hitAt({ eyes = "GLASSES_SUN" }, EYES)
	check("C13", "a hit on the eye band: ballistic glasses stop it (class 1 and class 2, durability drops); sunglasses protect nothing",
		rBG ~= nil and rBG.armor == "GLASSES_BG1" and hBG.items[hBG.slots.eyes].dur < Items.defs.GLASSES_BG1.armor.dur and rAF ~= nil and rAF.armor == "GLASSES_AF2" and rSun ~= nil and rSun.armor == nil)
	local rJaw = hitAt({ eyes = "GLASSES_BG1" }, JAW)
	local rBrow = hitAt({ eyes = "GLASSES_BG1" }, BROW)
	local rCrown = hitAt({ eyes = "GLASSES_BG1" }, CROWN)
	local rBroken = hitAt({ eyes = "GLASSES_BG1" }, EYES, { dur = 0 })
	check("C13", "glasses guard only the eyes: not the jaw, the brow or the crown, and not once their durability is gone",
		rJaw ~= nil and rJaw.armor == nil and rBrow ~= nil and rBrow.armor == nil and rCrown ~= nil and rCrown.armor == nil and rBroken ~= nil and rBroken.armor == nil)
	local rPlate = hitAt({ head = "HELMET_C5", eyes = "GLASSES_BG1" }, EYES)
	local rOpen = hitAt({ head = "HELMET_C5", eyes = "GLASSES_BG1" }, EYES, { visorUp = true })
	check("C13", "with a face-plate helmet the plate takes the eye hit while it is down, the glasses behind it once it is raised",
		rPlate ~= nil and rPlate.armor == "HELMET_C5" and rOpen ~= nil and rOpen.armor == "GLASSES_BG1")

	-- ── C12: equipment churn returns to the baseline (no growing meshes, welds or records) ──────────────────
	local mc = dummy("player")
	local hcx = holder()
	apply(mc, hcx)
	local function count(model)
		return #model:GetDescendants()
	end
	local baseD = count(mc)
	local cycle = { { "head", "HELMET_C3" }, { "head", "HELMET_C2" }, { "ears", nil }, { "back", "BAG_SLING" }, { "rig", "RIG_CHEST" }, { "armor", "ARMOR_C2" } }
	for i = 1, 60 do
		for _, c in cycle do
			drop(hcx, c[1])
			if c[2] and (i % 2 == 0) then
				give(hcx, c[1], c[2])
			end
		end
		apply(mc, hcx)
	end
	for _, c in cycle do
		drop(hcx, c[1])
	end
	apply(mc, hcx)
	check("C12", "360 equip/unequip changes: descendants back to the baseline", count(mc) == baseD, string.format("%d vs %d", count(mc), baseD))

	stage:Destroy()
	local passed, failed, lines = 0, 0, {}
	for _, r in results do
		if r.ok then
			passed += 1
		else
			failed += 1
		end
		table.insert(lines, string.format("%s %s %s%s", r.ok and "PASS" or "FAIL", r.id, r.name, r.note and r.note ~= "" and ("  [" .. r.note .. "]") or ""))
	end
	return string.format("CharTests: %d passed, %d failed\n%s", passed, failed, table.concat(lines, "\n")), passed, failed
end

return CT
