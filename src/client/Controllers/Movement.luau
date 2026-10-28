--!nonstrict
-- Local movement: stance (crouch), sprint, stamina, walk speed from injuries/aiming/treatment, jump cost.
-- Replicates stance + look pitch to the server (third-person animation) via the "stance" act.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)

local Movement = { crouching = false, sprinting = false, stamina = Config.MAX_STAMINA }
local ctx
local player = Players.LocalPlayer
local defaultHip = nil
local lastStance, lastStanceT = nil, 0

local function alive()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0 and hum or nil, char
end
Movement.alive = alive

function Movement.stopSprint()
	Movement.sprinting = false
end

local function sendStance()
	local W = ctx.Weapon
	local pitch = math.deg(ctx.Camera.pitch)
	local st = { c = Movement.crouching, a = W.aiming, s = Movement.sprinting, p = pitch }
	local t = os.clock()
	if lastStance and lastStance.c == st.c and lastStance.a == st.a and lastStance.s == st.s and math.abs(lastStance.p - pitch) < 6 then
		return
	end
	if t - lastStanceT < 0.15 then
		return
	end
	lastStance, lastStanceT = st, t
	ctx.State.act("stance", st)
end

local function update(dt)
	local hum = alive()
	if not hum then
		return
	end
	local W = ctx.Weapon
	if defaultHip == nil then
		defaultHip = hum.HipHeight
	end
	local moving = ctx.Camera.speed > 1
	local vit = ctx.State.vitals
	local mods = vit and vit.mods or nil
	ctx.Camera.tremor = mods and mods.tremor or 0
	if Movement.sprinting and (not moving or Movement.stamina <= 0 or Movement.crouching or W.aiming or (mods and not mods.sprint)) then
		Movement.sprinting = false
	end
	if Movement.sprinting then
		Movement.stamina = math.max(0, Movement.stamina - Config.SPRINT_DRAIN * dt)
	else
		Movement.stamina = math.min(Config.MAX_STAMINA, Movement.stamina + Config.STAMINA_REGEN * dt * (mods and mods.staminaRegen or 1))
	end
	local speed = Config.WALK_SPEED
	if Movement.sprinting then
		speed = Config.SPRINT_SPEED
	elseif Movement.crouching then
		speed = Config.CROUCH_SPEED
	elseif W.aiming then
		speed = Config.AIM_SPEED
	end
	if W.healing then
		speed = math.min(speed, Config.CROUCH_SPEED)
	end
	hum.WalkSpeed = speed * (mods and mods.speed or 1)
	hum.HipHeight = Movement.crouching and (defaultHip - 1.0) or defaultHip
	hum.UseJumpPower = false
	hum.JumpHeight = (Movement.crouching or Movement.stamina < Config.JUMP_COST) and 0 or 3.6
	sendStance()
end

function Movement.init(c)
	ctx = c
	local Input = c.Input
	Input.on("Sprint", function(down)
		if Input.device() == "KBM" then
			Movement.sprinting = down
		elseif down then
			Movement.sprinting = not Movement.sprinting
		end
		if Movement.sprinting then
			c.Weapon.cancelAim()
			Movement.crouching = false
		end
	end)
	Input.on("Crouch", function(down)
		if down then
			Movement.crouching = not Movement.crouching
			if Movement.crouching then
				Movement.sprinting = false
			end
		end
	end)
	c.State.changed:Connect(function()
		if not c.State.inRaid() then
			Movement.sprinting = false
		end
	end)
	player.CharacterAdded:Connect(function(char)
		defaultHip = nil
		Movement.crouching, Movement.sprinting = false, false
		Movement.stamina = Config.MAX_STAMINA
		local hum = char:WaitForChild("Humanoid", 5)
		if hum then
			hum.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Jumping then
					Movement.stamina = math.max(0, Movement.stamina - Config.JUMP_COST)
				end
			end)
		end
	end)
	RunService:BindToRenderStep("ZR_Movement", Enum.RenderPriority.Input.Value + 5, update)
end

return Movement
