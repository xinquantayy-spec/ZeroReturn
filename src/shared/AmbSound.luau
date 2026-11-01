--!nonstrict
-- Sounds from the ambience atlas (ZR_SFX_Amb, AmbAtlas.luau), used by the server (the IRONSIGHT siren, the substation generator)
-- and by the client (Ambience: layers, drips, distant gunfire). While Sounds.AMB_ATLAS is empty (the asset is not uploaded yet)
-- nothing is created: make() returns nil and every caller treats that as "stay silent".
local Sounds = require(script.Parent.Sounds)
local AmbAtlas = require(script.Parent.AmbAtlas)

local AmbSound = {}

-- Linear roll-off (full volume up to minDist, silent at maxDist) when asked for and the engine has it; else InverseTapered
local function rollOff(linear)
	if linear then
		local ok, mode = pcall(function()
			return Enum.RollOffMode.Linear
		end)
		if ok and mode then
			return mode
		end
	end
	return Enum.RollOffMode.InverseTapered
end

function AmbSound.ready()
	local id = Sounds.AMB_ATLAS
	return type(id) == "string" and id ~= ""
end

-- a Sound on one region of the atlas. o (all optional): parent, volume (the final Volume is volume x the region's gain), loop
-- (default: the region's own flag), group (a SoundGroup), minDist and maxDist (studs), linear (Linear roll-off instead of
-- InverseTapered), name. Returns sound, gain; or nil while the id is empty or the name is not in the atlas.
function AmbSound.make(name, o)
	o = o or {}
	local r = AmbAtlas[name]
	if type(r) ~= "table" or not AmbSound.ready() then
		return nil, 0
	end
	local s = Instance.new("Sound")
	s.Name = o.name or ("ZR_Amb_" .. name)
	s.SoundId = Sounds.AMB_ATLAS
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(r[1], r[1] + r[2])
	local loop = o.loop
	if loop == nil then
		loop = r[4] == true
	end
	if loop then
		s.LoopRegion = NumberRange.new(r[1], r[1] + r[2])
		s.Looped = true
	end
	s.Volume = (o.volume or 1) * r[3]
	s.RollOffMode = rollOff(o.linear)
	if o.minDist then
		s.RollOffMinDistance = o.minDist
	end
	if o.maxDist then
		s.RollOffMaxDistance = o.maxDist
	end
	if o.group then
		s.SoundGroup = o.group
	end
	s.Parent = o.parent
	return s, r[3]
end

return AmbSound
