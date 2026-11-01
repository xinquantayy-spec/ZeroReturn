--!nonstrict
-- Meridian Mall shell, step 2: the ways between the floors. Stairs and the (stopped) escalators are solid treads, 0.6 studs of rise
-- at most, each as one box from the lower floor up to its tread; the last tread is level with the upper floor. The flight lies on
-- the plan's grid so that the opening in the upper floor is exactly the flight; a landing of at least 4.5 studs of floor follows at
-- both ends (MallPlan). The ramp in the south atrium is one wedge. The dock ramps outside are Ground's; their deck pieces are in
-- MallShell.
return function(ctx)
	local plan, O = ctx.plan, ctx.O
	local C, M, hex = ctx.C, ctx.M, ctx.hex
	local YL = plan.YL
	local ab, boxCF, glassOf = ctx.ab, ctx.boxCF, ctx.glassOf
	local par = ctx.m.links
	local STAIR = hex("86877F")
	local ESC = hex("33383B")
	local METAL = C.metalDark
	local RAMP = hex("7A7B74")

	-- a rail along a flight: a panel parallel to the slope on each side, with a handrail on top
	local function sides(ln, y0, rise, glass)
		local hw = ln.w / 2
		local mid = Vector3.new(O.X + (ln.x0 + ln.x1) / 2, y0 + rise / 2, O.Z + (ln.z0 + ln.z1) / 2)
		local d = Vector3.new(ln.ux * ln.len, rise, ln.uz * ln.len)
		local slope = d.Magnitude
		local perp = Vector3.new(-ln.uz, 0, ln.ux)
		for _, s in { -1, 1 } do
			local pos = mid + perp * (s * (hw - 0.2)) + Vector3.new(0, 1.7, 0)
			local panel = boxCF(par, CFrame.lookAt(pos, pos + d), 0.3, 3.4, slope, glass and ctx.GLASS or ESC, glass and M.Glass or M.Metal)
			if glass then
				glassOf(panel)
			end
			local top = pos + Vector3.new(0, 1.9, 0)
			local hr = boxCF(par, CFrame.lookAt(top, top + d), 0.6, 0.5, slope, METAL, M.Metal)
			if hr then
				hr.Name = "Handrail"
			end
		end
	end

	local nTreads = 0
	for _, ln in plan.links do
		if ln.type == "ramp" then
			local y0, y1 = YL[ln.lo], YL[ln.hi]
			local rise = y1 - y0
			local mid = Vector3.new(O.X + (ln.x0 + ln.x1) / 2, y0 + rise / 2, O.Z + (ln.z0 + ln.z1) / 2)
			local cf = CFrame.lookAt(mid, mid - Vector3.new(ln.ux, 0, ln.uz))
			local wedge = boxCF(par, cf, ln.w, rise, ln.len, RAMP, M.Concrete, "WedgePart")
			if wedge then
				wedge.Name = ln.id
			end
			sides(ln, y0, rise, false)
		elseif ln.type == "stairs" or ln.type == "escalator" then
			local y0, y1 = YL[ln.lo], YL[ln.hi]
			local rise = y1 - y0
			local steps = math.ceil(rise / 0.6)
			local rs = rise / steps
			local run = ln.len / steps
			local hw = ln.w / 2
			local color, mat = STAIR, M.Concrete
			if ln.type == "escalator" then
				color, mat = ESC, M.Metal
			end
			for k = 1, steps do
				local a0, a1 = (k - 1) * run, k * run
				local xa, xb = ln.x0 + ln.ux * a0, ln.x0 + ln.ux * a1
				local za, zb = ln.z0 + ln.uz * a0, ln.z0 + ln.uz * a1
				local x0b, x1b = math.min(xa, xb), math.max(xa, xb)
				local z0b, z1b = math.min(za, zb), math.max(za, zb)
				if ln.ux ~= 0 then
					z0b, z1b = ln.ax - hw, ln.ax + hw
				else
					x0b, x1b = ln.ax - hw, ln.ax + hw
				end
				local p = ab(par, x0b, y0 - 0.2, z0b, x1b, y0 + k * rs, z1b, color, mat)
				if p then
					nTreads += 1
				end
			end
			sides(ln, y0, rise, ln.type == "stairs")
		end
	end
	ctx.stat.treads = nTreads
end
