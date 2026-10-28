--!strict
-- Small shared helpers. Pure except guid().
local HttpService = game:GetService("HttpService")

local Util = {}

function Util.guid(): string
	local s = string.gsub(HttpService:GenerateGUID(false), "-", "")
	return string.lower(s)
end

function Util.copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in v do
		t[k] = Util.copy(x)
	end
	return t
end

function Util.finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Util.vec(v: any): boolean
	return typeof(v) == "Vector3" and Util.finite(v.X) and Util.finite(v.Y) and Util.finite(v.Z)
end

function Util.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- Validates a client payload: plain table, bounded keys/depth, no instances/functions.
function Util.sane(v: any, maxKeys: number, depth: number): boolean
	local tv = type(v)
	if tv == "string" then
		return #v <= 64
	elseif tv == "number" then
		return Util.finite(v)
	elseif tv == "boolean" or tv == "nil" then
		return true
	elseif tv ~= "table" or depth <= 0 then
		return false
	end
	local n = 0
	for k, x in v do
		n += 1
		if n > maxKeys or (type(k) ~= "string" and type(k) ~= "number") then
			return false
		end
		if not Util.sane(x, maxKeys, depth - 1) then
			return false
		end
	end
	return true
end

function Util.clock(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%02d:%02d", sec // 60, sec % 60)
end

function Util.commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

return Util
