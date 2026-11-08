"""Offline part census of the map builders, by builder call (art-5b phase 1, docs/look/MODULAR_KIT.md).

  run <map> <out.json> [--kit5] [--merge[=A]]
                                  build one map (border, meridian, smelter, relay7) under Lua 5.4 (lupa) with a Roblox
                                  stand-in and record every part left in the map: class, size, frame, flags and the
                                  builder call stack that made it. --kit5: the ZR_Kit5 meshes (stair flights, railings,
                                  fence modules, assets/blender_scripts/build_kit5.py) count as loaded, with metadata
                                  from build_kit5.expected_meta(); without it the builders take their part fallbacks
                                  (today's look). --merge[=A]: the mall and bunker kits' merged pieces (art-5b phase 2)
                                  count as exported and loaded with zr_kit.merge_plan(absorb A, default 1.0: one opaque
                                  piece per prop), and Kit.MERGE is on for every batch
  report <out.json> [...]         parts by group (the map model's children), by category (stairs, rails, walls ...) and
                                  by builder function (module:function)
  compare <before.json> <after.json>  the change by category and group, and the kit calls (kit or fallback)
  tests [--kit5] [--merge[=A]]    src/server/Tests/KitTests.luau under the stand-in (rays against boxes and wedges, the
                                  collision groups), with the Smelter built; exit 1 on a failure
  merge [A]                       the merge plan per kit batch: pieces before and after, the look cost (the share of the
                                  surface whose Roblox material changes); the areas come from the build scripts run
                                  under an offline stand-in for Blender's bmesh (no Blender)
  mergecost <split.json> <merged.json>  a map's look cost from two runs, by the props placed: the share of the placed kit
                                  surface that changes material, and the parts saved
  all [outdir]                    run + report every map, before and after (default outdir: a temp folder)

NOT Roblox and NOT Studio: no physics, no streaming, no Tidy pass, no wear pass, no frame rate. The terrain is not
written (voxel calls do nothing; terrain rays miss, so TerrainKit falls back to its height grid). The prop kits
(ZR_MK_*), nature and cover meshes count as loaded, as in Studio with every batch uploaded: one MeshPart per piece.
Luau -> Lua: type annotations, casts, compound assignment and generalized for-in (the subset the map modules use;
adapted from tools/smelter_preview.py). Run with a Python that has lupa: `python3 -I tools/kit_census.py all`.
"""
import json, math, os, re, sys, tempfile, types
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from smelter_preview import mask, type_end, skip_ws  # noqa: E402  (the factory thread's Luau scanner)


def conv(src):
    """Luau -> Lua 5.4 for the map modules (tools/smelter_preview.py's conv without its require rewrite)."""
    m = mask(src)
    cut = []
    for t in re.finditer(r'(?m)^(\s*)(export\s+)?type\s+\w+(<[^>]*>)?\s*=', m):
        cut.append((t.start(), type_end(m, t.end())))
    for t in re.finditer(r'::', m):
        cut.append((t.start(), type_end(m, t.end())))
    for t in re.finditer(r'\bfunction\b[^(\n]*\(', m):
        i = t.end(); depth = 1; j = i
        while j < len(m):
            if m[j] in '({[':
                depth += 1
            elif m[j] in ')}]':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        close = j
        k = i; d = 1
        while k < close:
            ch = m[k]
            if ch in '({[':
                d += 1
            elif ch in ')}]':
                d -= 1
            elif ch == ':' and d == 1:
                e = type_end(m, k + 1)
                cut.append((k, e)); k = e; continue
            k += 1
        k = skip_ws(m, close + 1)
        if k < len(m) and m[k] == ':' and not m.startswith('::', k):
            cut.append((k, type_end(m, k + 1)))
    for t in re.finditer(r'\blocal\s+(?!function\b)', m):
        k = t.end()
        while True:
            mm = re.match(r'[A-Za-z_]\w*', m[k:])
            if not mm:
                break
            k += mm.end()
            k2 = skip_ws(m, k)
            if k2 < len(m) and m[k2] == ':' and not m.startswith('::', k2):
                e = type_end(m, k2 + 1); cut.append((k2, e)); k = e
            k2 = skip_ws(m, k)
            if k2 < len(m) and m[k2] == ',':
                k = skip_ws(m, k2 + 1); continue
            break
    cut.sort()
    merged = []
    for a, b in cut:
        if merged and a <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], b))
        else:
            merged.append((a, b))
    s = list(src)
    for a, b in reversed(merged):
        del s[a:b]
    src = ''.join(s)
    # generalized for-in (the expression may run over several lines): for names in <expr> do -> for names in __iter(<expr>) do
    m = mask(src)
    spans = []
    for f in re.finditer(r'\bfor\s+[A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*\s+in\s+', m):
        i, depth = f.end(), 0
        while i < len(m):
            ch = m[i]
            if ch in '({[':
                depth += 1
            elif ch in ')}]':
                depth -= 1
            elif depth == 0 and m.startswith('do', i) and not (m[i - 1].isalnum() or m[i - 1] == '_') and not (i + 2 < len(m) and (m[i + 2].isalnum() or m[i + 2] == '_')):
                break
            i += 1
        e = i
        while e > f.end() and m[e - 1] in ' \t\n':
            e -= 1
        spans.append((f.end(), e))
    for a, b in reversed(spans):
        src = src[:a] + '__iter(' + src[a:b] + ')' + src[b:]
    m = mask(src)
    out = []
    for o, mm in zip(src.split('\n'), m.split('\n')):
        cpos = mm.find('\x01')
        code_o = o if cpos < 0 else o[:cpos]
        code_m = mm if cpos < 0 else mm[:cpos]
        c = re.match(r'^(\s*)([^=\s][^=]*?)\s*(\+|-|\*|//|/|\.\.|%|\^)=\s*([^=].*)$', code_m.rstrip())
        if c and '==' not in code_m and not re.match(r'\s*(local|if|elseif|while|until|return|for)\b', code_m):
            lv = code_o[c.start(2):c.end(2)]
            rhs = code_o[c.start(4):].rstrip()
            code_o = f"{c.group(1)}{lv} = {lv} {c.group(3)} ({rhs})"
        out.append(code_o + ('' if cpos < 0 else o[cpos:]))
    return '\n'.join(out)


# ── the Roblox stand-in (Lua 5.4) ────────────────────────────────────────────────────────────────────────────────
MOCK = r"""
unpack = table.unpack
function __iter(a, b, c)
  if type(a) == "function" then return a, b, c end
  if type(a) ~= "table" then error("attempt to iterate over a " .. type(a) .. " value", 2) end
  local mt = getmetatable(a)
  if mt and mt.__iter then return mt.__iter(a) end
  local n = rawlen(a)
  local i, stage, rest, j = 0, 1, nil, 0
  return function()
    while stage == 1 do
      i = i + 1
      if i > n then stage = 2 break end
      local v = a[i]
      if v ~= nil then return i, v end
    end
    if not rest then
      -- the other keys in a fixed order (Lua 5.4 seeds its string hashes per process; Luau's order is fixed per engine
      -- build): numbers, then strings, then the rest, so two runs of a map build the same thing
      rest = {}
      for k in next, a do
        if not (math.type(k) == "integer" and k >= 1 and k <= n) then rest[#rest + 1] = k end
      end
      local rank = { number = 1, string = 2 }
      table.sort(rest, function(x, y)
        local tx, ty = rank[type(x)] or 3, rank[type(y)] or 3
        if tx ~= ty then return tx < ty end
        if tx == 3 then return tostring(x) < tostring(y) end
        return x < y
      end)
    end
    j = j + 1
    local k = rest[j]
    if k == nil then return nil end
    return k, a[k]
  end
end
function table.find(t, v, init) for i = init or 1, #t do if t[i] == v then return i end end return nil end
function table.create(n, v) local t = {} if v ~= nil then for i = 1, n do t[i] = v end end return t end
function table.clear(t) for k in pairs(t) do t[k] = nil end end
function table.clone(t) local o = {} for k, v in pairs(t) do o[k] = v end return setmetatable(o, getmetatable(t)) end
function table.freeze(t) return t end
function table.isfrozen() return false end
function math.clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end
function math.sign(x) if x > 0 then return 1 elseif x < 0 then return -1 end return 0 end
function math.round(x) if x >= 0 then return math.floor(x + 0.5) end return -math.floor(-x + 0.5) end
math.atan2 = function(y, x) return math.atan(y, x) end
math.pow = function(a, b) return a ^ b end
math.log10 = function(x) return math.log(x, 10) end
do -- Perlin noise like Roblox's math.noise (deterministic; the exact values differ)
  local p = {}
  local r = 12345
  local perm = {}
  for i = 0, 255 do perm[i] = i end
  for i = 255, 1, -1 do r = (r * 1103515245 + 12345) % 2147483648 local j = r % (i + 1) perm[i], perm[j] = perm[j], perm[i] end
  for i = 0, 511 do p[i] = perm[i % 256] end
  local function fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end
  local function lerp(t, a, b) return a + t * (b - a) end
  local function grad(h, x, y, z)
    h = h % 16
    local u = h < 8 and x or y
    local v = h < 4 and y or ((h == 12 or h == 14) and x or z)
    return ((h % 2) == 0 and u or -u) + ((h % 4) < 2 and v or -v)
  end
  function math.noise(x, y, z)
    x, y, z = x or 0, y or 0, z or 0
    local X, Y, Z = math.floor(x) % 256, math.floor(y) % 256, math.floor(z) % 256
    x, y, z = x - math.floor(x), y - math.floor(y), z - math.floor(z)
    local u, v, w = fade(x), fade(y), fade(z)
    local A, B = p[X] + Y, p[X + 1] + Y
    local AA, AB, BA, BB = p[A] + Z, p[A + 1] + Z, p[B] + Z, p[B + 1] + Z
    return lerp(w, lerp(v, lerp(u, grad(p[AA], x, y, z), grad(p[BA], x - 1, y, z)), lerp(u, grad(p[AB], x, y - 1, z), grad(p[BB], x - 1, y - 1, z))),
      lerp(v, lerp(u, grad(p[AA + 1], x, y, z - 1), grad(p[BA + 1], x - 1, y, z - 1)), lerp(u, grad(p[AB + 1], x, y - 1, z - 1), grad(p[BB + 1], x - 1, y - 1, z - 1))))
  end
end
do -- %d with a float argument: Luau truncates, Lua 5.4 raises
  local fmt = string.format
  string.format = function(f, ...)
    local args = table.pack(...)
    local i = 0
    for spec in f:gmatch("%%[-+ #0]*%d*%.?%d*([%a%%])") do
      if spec ~= "%" then
        i = i + 1
        if (spec == "d" or spec == "i" or spec == "x" or spec == "X") and type(args[i]) == "number" and math.type(args[i]) == "float" then
          args[i] = math.tointeger(args[i] >= 0 and math.floor(args[i]) or -math.floor(-args[i])) or 0
        end
      end
    end
    return fmt(f, table.unpack(args, 1, args.n))
  end
end
WARNS, PRINTS = {}, {}
function warn(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end WARNS[#WARNS + 1] = table.concat(t, " ") end
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end PRINTS[#PRINTS + 1] = table.concat(t, " ") end
local CLOCK = 0
local realClock = os.clock
os.clock = function() return realClock() + CLOCK end
tick = os.clock
-- a spawned task runs until its first wait and is then left asleep (the build is one frame; game loops never end)
local SPAWNED = setmetatable({}, { __mode = "k" })
local function spawnTask(f, ...)
  local co = coroutine.create(f)
  SPAWNED[co] = true
  local ok, e = coroutine.resume(co, ...)
  if not ok then warn("task.spawn: " .. tostring(e)) end
  return co
end
task = { wait = function(t)
    if SPAWNED[coroutine.running()] then coroutine.yield() end
    CLOCK = CLOCK + math.max(t or 0.03, 0.03)
    return t or 0.03
  end,
  spawn = spawnTask, defer = spawnTask, delay = function() end, cancel = function() end }

-- Vector3 / Vector2
local V3 = {}
V3.__type = "Vector3"
V3.__index = function(t, k)
  if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
  if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) if m == 0 then return t end return Vector3.new(t.X / m, t.Y / m, t.Z / m) end
  return V3[k]
end
function V3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3.Cross(a, b) return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V3.Lerp(a, b, t) return Vector3.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end
function V3.Abs(a) return Vector3.new(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end
function V3.Min(a, b) return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
function V3.Max(a, b) return Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
function V3.FuzzyEq(a, b, e) e = e or 1e-5 return math.abs(a.X - b.X) <= e and math.abs(a.Y - b.Y) <= e and math.abs(a.Z - b.Z) <= e end
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
  if type(a) == "number" then return Vector3.new(a * b.X, a * b.Y, a * b.Z) end
  if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
  return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
  if type(b) == "number" then return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
  return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("%.3f, %.3f, %.3f", a.X, a.Y, a.Z) end
Vector3 = {}
function Vector3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
Vector3.zero, Vector3.one = Vector3.new(0, 0, 0), Vector3.new(1, 1, 1)
Vector3.xAxis, Vector3.yAxis, Vector3.zAxis = Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)
local V2 = { __type = "Vector2" }
V2.__index = function(t, k)
  if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y) end
  if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y) if m == 0 then return t end return Vector2.new(t.X / m, t.Y / m) end
  return V2[k]
end
function V2.Dot(a, b) return a.X * b.X + a.Y * b.Y end
function V2.Cross(a, b) return a.X * b.Y - a.Y * b.X end
function V2.Lerp(a, b, t) return Vector2.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end
V2.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
  if type(a) == "number" then return Vector2.new(a * b.X, a * b.Y) end
  if type(b) == "number" then return Vector2.new(a.X * b, a.Y * b) end
  return Vector2.new(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b) if type(b) == "number" then return Vector2.new(a.X / b, a.Y / b) end return Vector2.new(a.X / b.X, a.Y / b.Y) end
V2.__unm = function(a) return Vector2.new(-a.X, -a.Y) end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
Vector2 = { new = function(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end }
Vector2.zero = Vector2.new(0, 0)

-- CFrame (position x, y, z; rotation rows a b c / d e f / g h i)
local CF = { __type = "CFrame" }
local function mkcf(x, y, z, a, b, c, d, e, f, g, h, i) return setmetatable({ x = x, y = y, z = z, a = a, b = b, c = c, d = d, e = e, f = f, g = g, h = h, i = i }, CF) end
CF.__index = function(t, k)
  if k == "Position" or k == "p" then return Vector3.new(t.x, t.y, t.z) end
  if k == "X" then return t.x elseif k == "Y" then return t.y elseif k == "Z" then return t.z end
  if k == "RightVector" or k == "XVector" then return Vector3.new(t.a, t.d, t.g) end
  if k == "UpVector" or k == "YVector" then return Vector3.new(t.b, t.e, t.h) end
  if k == "LookVector" then return Vector3.new(-t.c, -t.f, -t.i) end
  if k == "ZVector" then return Vector3.new(t.c, t.f, t.i) end
  if k == "Rotation" then return mkcf(0, 0, 0, t.a, t.b, t.c, t.d, t.e, t.f, t.g, t.h, t.i) end
  return CF[k]
end
local function matmul(p, q)
  return mkcf(p.a * q.x + p.b * q.y + p.c * q.z + p.x, p.d * q.x + p.e * q.y + p.f * q.z + p.y, p.g * q.x + p.h * q.y + p.i * q.z + p.z,
    p.a * q.a + p.b * q.d + p.c * q.g, p.a * q.b + p.b * q.e + p.c * q.h, p.a * q.c + p.b * q.f + p.c * q.i,
    p.d * q.a + p.e * q.d + p.f * q.g, p.d * q.b + p.e * q.e + p.f * q.h, p.d * q.c + p.e * q.f + p.f * q.i,
    p.g * q.a + p.h * q.d + p.i * q.g, p.g * q.b + p.h * q.e + p.i * q.h, p.g * q.c + p.h * q.f + p.i * q.i)
end
CF.__mul = function(p, q)
  if getmetatable(q) == CF then return matmul(p, q) end
  if getmetatable(q) == V3 then return Vector3.new(p.a * q.X + p.b * q.Y + p.c * q.Z + p.x, p.d * q.X + p.e * q.Y + p.f * q.Z + p.y, p.g * q.X + p.h * q.Y + p.i * q.Z + p.z) end
  error("CFrame * " .. type(q), 2)
end
CF.__add = function(p, v) return mkcf(p.x + v.X, p.y + v.Y, p.z + v.Z, p.a, p.b, p.c, p.d, p.e, p.f, p.g, p.h, p.i) end
CF.__sub = function(p, v) return mkcf(p.x - v.X, p.y - v.Y, p.z - v.Z, p.a, p.b, p.c, p.d, p.e, p.f, p.g, p.h, p.i) end
CF.__eq = function(p, q) return p.x == q.x and p.y == q.y and p.z == q.z and p.a == q.a and p.e == q.e and p.i == q.i and p.b == q.b and p.c == q.c end
function CF.Inverse(p)
  return mkcf(-(p.a * p.x + p.d * p.y + p.g * p.z), -(p.b * p.x + p.e * p.y + p.h * p.z), -(p.c * p.x + p.f * p.y + p.i * p.z), p.a, p.d, p.g, p.b, p.e, p.h, p.c, p.f, p.i)
end
function CF.PointToObjectSpace(p, v) return p:Inverse() * v end
function CF.PointToWorldSpace(p, v) return p * v end
function CF.VectorToWorldSpace(p, v) return Vector3.new(p.a * v.X + p.b * v.Y + p.c * v.Z, p.d * v.X + p.e * v.Y + p.f * v.Z, p.g * v.X + p.h * v.Y + p.i * v.Z) end
function CF.VectorToObjectSpace(p, v) return p:Inverse():VectorToWorldSpace(v) end
function CF.ToObjectSpace(p, q) return p:Inverse() * q end
function CF.ToWorldSpace(p, q) return p * q end
function CF.GetComponents(p) return p.x, p.y, p.z, p.a, p.b, p.c, p.d, p.e, p.f, p.g, p.h, p.i end
CF.components = CF.GetComponents
function CF.ToEulerAnglesYXZ(p)
  local rx = math.asin(math.max(-1, math.min(1, -p.f)))
  return rx, math.atan(p.c, p.i), math.atan(p.d, p.e)
end
CF.ToOrientation = CF.ToEulerAnglesYXZ
function CF.ToEulerAnglesXYZ(p)
  local ry = math.asin(math.max(-1, math.min(1, p.c)))
  return math.atan(-p.f, p.i), ry, math.atan(-p.b, p.a)
end
function CF.Lerp(p, q, t)
  return mkcf(p.x + (q.x - p.x) * t, p.y + (q.y - p.y) * t, p.z + (q.z - p.z) * t, p.a, p.b, p.c, p.d, p.e, p.f, p.g, p.h, p.i)
end
CFrame = {}
local function lookAtCF(at, target, up)
  up = up or Vector3.new(0, 1, 0)
  local look = target - at
  if look.Magnitude < 1e-9 then return mkcf(at.X, at.Y, at.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1) end
  look = look.Unit
  local right = look:Cross(up)
  if right.Magnitude < 1e-6 then right = Vector3.new(1, 0, 0) else right = right.Unit end
  local u = right:Cross(look)
  return mkcf(at.X, at.Y, at.Z, right.X, u.X, -look.X, right.Y, u.Y, -look.Y, right.Z, u.Z, -look.Z)
end
function CFrame.new(x, y, z, ...)
  if x == nil then return mkcf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1) end
  if getmetatable(x) == V3 then
    if y ~= nil and getmetatable(y) == V3 then return lookAtCF(x, y) end
    return mkcf(x.X, x.Y, x.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
  end
  local r = { ... }
  if #r == 9 then return mkcf(x, y, z, table.unpack(r)) end
  if #r == 4 then -- quaternion
    local qx, qy, qz, qw = r[1], r[2], r[3], r[4]
    return mkcf(x, y, z, 1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw), 2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw), 2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy))
  end
  return mkcf(x, y or 0, z or 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
end
function CFrame.lookAt(at, target, up) return lookAtCF(at, target, up) end
function CFrame.Angles(rx, ry, rz)
  local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
  local Rx = mkcf(0, 0, 0, 1, 0, 0, 0, cx, -sx, 0, sx, cx)
  local Ry = mkcf(0, 0, 0, cy, 0, sy, 0, 1, 0, -sy, 0, cy)
  local Rz = mkcf(0, 0, 0, cz, -sz, 0, sz, cz, 0, 0, 0, 1)
  return matmul(matmul(Rx, Ry), Rz)
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(rx, ry, rz) return matmul(matmul(CFrame.Angles(0, ry, 0), CFrame.Angles(rx, 0, 0)), CFrame.Angles(0, 0, rz)) end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
function CFrame.fromAxisAngle(ax, an)
  ax = ax.Unit
  local c, s = math.cos(an), math.sin(an)
  local t = 1 - c
  local x, y, z = ax.X, ax.Y, ax.Z
  return mkcf(0, 0, 0, t * x * x + c, t * x * y - s * z, t * x * z + s * y, t * x * y + s * z, t * y * y + c, t * y * z - s * x, t * x * z - s * y, t * y * z + s * x, t * z * z + c)
end
function CFrame.fromMatrix(pos, rx, ry, rz)
  rz = rz or rx:Cross(ry).Unit
  return mkcf(pos.X, pos.Y, pos.Z, rx.X, ry.X, rz.X, rx.Y, ry.Y, rz.Y, rx.Z, ry.Z, rz.Z)
end
CFrame.identity = CFrame.new()

-- Color3, Enum, Random, misc
local C3 = { __type = "Color3" }
C3.__index = C3
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
function C3.ToHSV(c)
  local r, g, b = c.R, c.G, c.B
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local d, h = mx - mn, 0
  if d > 0 then
    if mx == r then h = ((g - b) / d) % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
    h = h / 6
  end
  return h, mx == 0 and 0 or d / mx, mx
end
function C3.Lerp(a, b, t) return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
function C3.ToHex(c) return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
Color3 = {}
function Color3.new(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
function Color3.fromRGB(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHex(h)
  local s = tostring(h):gsub("^#", "")
  return Color3.fromRGB(tonumber(s:sub(1, 2), 16) or 0, tonumber(s:sub(3, 4), 16) or 0, tonumber(s:sub(5, 6), 16) or 0)
end
function Color3.fromHSV(h, s, v)
  local i = math.floor(h * 6)
  local f = h * 6 - i
  local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
  i = i % 6
  if i == 0 then return Color3.new(v, t, p) elseif i == 1 then return Color3.new(q, v, p) elseif i == 2 then return Color3.new(p, v, t)
  elseif i == 3 then return Color3.new(p, q, v) elseif i == 4 then return Color3.new(t, p, v) end
  return Color3.new(v, p, q)
end
BrickColor = { new = function(n) return { Name = tostring(n), Color = Color3.new(0.5, 0.5, 0.5) } end }
Enum = setmetatable({}, { __index = function(t, k)
  local sub = setmetatable({}, { __index = function(_, name) return "Enum." .. k .. "." .. name end })
  rawset(t, k, sub)
  return sub
end })
local RND = {}
RND.__index = RND
function RND:_next()
  self.s = (self.s * 6364136223846793005 + 1442695040888963407) & 0x7fffffffffffffff
  return ((self.s >> 11) & 0xfffffffffffff) / 4503599627370496.0
end
function RND:NextNumber(a, b) local r = self:_next() if a == nil then return r end return a + (b - a) * r end
function RND:NextInteger(a, b) return a + math.floor(self:_next() * (b - a + 1)) end
function RND:NextUnitVector() local v = Vector3.new(self:NextNumber(-1, 1), self:NextNumber(-1, 1), self:NextNumber(-1, 1)) return v.Magnitude > 0 and v.Unit or Vector3.new(0, 1, 0) end
function RND:Shuffle(t) for i = #t, 2, -1 do local j = self:NextInteger(1, i) t[i], t[j] = t[j], t[i] end end
function RND:Clone() return setmetatable({ s = self.s }, RND) end
Random = { new = function(seed) return setmetatable({ s = (math.floor((seed or 1) * 1000) * 2654435761 + 12345) & 0x7fffffffffffffff }, RND) end }
function typeof(x)
  local mt = getmetatable(x)
  if type(mt) == "table" and mt.__type then return mt.__type end
  if type(x) == "table" and rawget(x, "ClassName") then return "Instance" end
  return type(x)
end
UDim2 = { fromScale = function(x, y) return { x, y } end, new = function(a, b, c, d) return { a, b, c, d } end, fromOffset = function(x, y) return { x, y } end }
UDim = { new = function(a, b) return { a, b } end }
Font = { new = function(...) return { ... } end, fromEnum = function(e) return { e } end }
Region3 = { new = function(a, b) return { CFrame = CFrame.new((a + b) / 2), Size = b - a } end }
NumberSequence = { new = function(...) return { ... } end }
ColorSequence = { new = function(...) return { ... } end }
NumberRange = { new = function(...) return { ... } end }
NumberSequenceKeypoint = { new = function(...) return { ... } end }
ColorSequenceKeypoint = { new = function(...) return { ... } end }
PhysicalProperties = { new = function(...) return { ... } end }
Faces = { new = function(...) return { ... } end }
TweenInfo = { new = function(...) return { ... } end }
local function paramsNew() return { FilterType = "Enum.RaycastFilterType.Exclude", FilterDescendantsInstances = {}, IgnoreWater = false, RespectCanCollide = false, CollisionGroup = "Default",
  AddToFilter = function(self, x) table.insert(self.FilterDescendantsInstances, x) end } end
RaycastParams = { new = paramsNew }
OverlapParams = { new = paramsNew }

-- Instances
local BASEPART = { Part = true, WedgePart = true, MeshPart = true, TrussPart = true, CornerWedgePart = true, SpawnLocation = true, UnionOperation = true, Seat = true }
CENSUS = { parts = {}, kit5 = false }
local function frames()
  local out, lvl = {}, 3
  while true do
    local info = debug.getinfo(lvl, "Sln")
    if not info then break end
    local src = info.source or ""
    if src:sub(1, 3) == "=M:" then
      out[#out + 1] = { src:sub(4), info.name or "?", info.linedefined or 0, info.currentline or 0 }
      if #out >= 10 then break end
    end
    lvl = lvl + 1
  end
  return out
end
local function isA(inst, cls)
  local c = inst.ClassName
  if c == cls or cls == "Instance" then return true end
  if cls == "BasePart" or cls == "PVInstance" then return BASEPART[c] == true or (cls == "PVInstance" and c == "Model") end
  if cls == "Light" then return c == "PointLight" or c == "SpotLight" or c == "SurfaceLight" end
  if cls == "GuiObject" then return c == "TextLabel" or c == "Frame" or c == "ImageLabel" end
  if cls == "LuaSourceContainer" then return c == "ModuleScript" end
  return false
end
local IM = {}
local function descend(inst, out)
  for _, ch in ipairs(inst._children) do out[#out + 1] = ch descend(ch, out) end
  return out
end
IM.GetChildren = function(self) local o = {} for i, c in ipairs(self._children) do o[i] = c end return o end
IM.GetDescendants = function(self) return descend(self, {}) end
IM.IsA = isA
IM.FindFirstChild = function(self, name, rec)
  for _, c in ipairs(self._children) do if c.Name == name then return c end end
  local hook = rawget(self, "_find")
  if hook then local r = hook(self, name) if r then return r end end
  if rec then for _, c in ipairs(self._children) do local r = c:FindFirstChild(name, true) if r then return r end end end
  return nil
end
IM.WaitForChild = function(self, name) return IM.FindFirstChild(self, name) end
IM.FindFirstChildOfClass = function(self, cls) for _, c in ipairs(self._children) do if c.ClassName == cls then return c end end return nil end
IM.FindFirstChildWhichIsA = function(self, cls) for _, c in ipairs(self._children) do if isA(c, cls) then return c end end return nil end
IM.FindFirstAncestor = function(self, name) local q = rawget(self, "_parent") while q do if q.Name == name then return q end q = rawget(q, "_parent") end return nil end
IM.FindFirstAncestorOfClass = function(self, cls) local q = rawget(self, "_parent") while q do if q.ClassName == cls then return q end q = rawget(q, "_parent") end return nil end
IM.FindFirstAncestorWhichIsA = function(self, cls) local q = rawget(self, "_parent") while q do if isA(q, cls) then return q end q = rawget(q, "_parent") end return nil end
IM.SetAttribute = function(self, k, v) self._attrs[k] = v end
IM.GetAttribute = function(self, k) return self._attrs[k] end
IM.GetAttributes = function(self) return self._attrs end
IM.Destroy = function(self) self.Parent = nil rawset(self, "_destroyed", true) end
IM.ClearAllChildren = function(self) for _, c in ipairs(self:GetChildren()) do c.Parent = nil end end
IM.IsDescendantOf = function(self, p) local q = rawget(self, "_parent") while q do if q == p then return true end q = rawget(q, "_parent") end return false end
IM.IsAncestorOf = function(self, d) return d:IsDescendantOf(self) end
IM.GetFullName = function(self) local n = self.Name local q = rawget(self, "_parent") while q do n = q.Name .. "." .. n q = rawget(q, "_parent") end return n end
IM.GetPropertyChangedSignal = function() return { Connect = function() return { Disconnect = function() end } end } end
IM.Play = function() end
IM.Stop = function() end
IM.GetPivot = function(self)
  if rawget(self, "CFrame") then return self.CFrame end
  local pp = rawget(self, "PrimaryPart")
  if pp then return pp.CFrame end
  for _, d in ipairs(self:GetDescendants()) do if BASEPART[d.ClassName] then return d.CFrame end end
  return CFrame.new()
end
IM.PivotTo = function(self, cf)
  local old = self:GetPivot()
  local delta = cf * old:Inverse()
  if BASEPART[self.ClassName] then self.CFrame = cf return end
  for _, d in ipairs(self:GetDescendants()) do if BASEPART[d.ClassName] then rawset(d, "CFrame", delta * d.CFrame) end end
end
IM.GetBoundingBox = function(self)
  local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
  for _, d in ipairs(self:GetDescendants()) do
    if BASEPART[d.ClassName] then
      local p, s = d.CFrame.Position, d.Size / 2
      lo, hi = lo:Min(p - s), hi:Max(p + s)
    end
  end
  if lo.X > hi.X then return CFrame.new(), Vector3.zero end
  return CFrame.new((lo + hi) / 2), hi - lo
end
IM.GetExtentsSize = function(self) local _, s = self:GetBoundingBox() return s end
IM.ScaleTo = function() end
IM.Clone = function(self)
  local c = Instance.new(self.ClassName)
  for k, v in pairs(self) do
    if k ~= "_children" and k ~= "_attrs" and k ~= "_parent" and k ~= "_frames" and k ~= "ClassName" and k ~= "_find" then rawset(c, k, v) end
  end
  for k, v in pairs(self._attrs) do c._attrs[k] = v end
  for _, ch in ipairs(self._children) do ch:Clone().Parent = c end
  return c
end
local IMT = {}
IMT.__type = "Instance"
IMT.__index = function(t, k)
  if k == "Parent" then return rawget(t, "_parent") end
  if k == "Position" and BASEPART[t.ClassName] then return rawget(t, "CFrame").Position end
  if k == "Orientation" and BASEPART[t.ClassName] then return Vector3.zero end
  if (k == "Play" or k == "Stop") and t.ClassName ~= "Sound" then
    for _, c in ipairs(rawget(t, "_children")) do if c.Name == k then return c end end
    local hook = rawget(t, "_find")
    if hook then return hook(t, k) end
    return nil
  end
  local f = IM[k]
  if f then return f end
  for _, c in ipairs(rawget(t, "_children")) do if c.Name == k then return c end end
  local hook = rawget(t, "_find")
  if hook then return hook(t, k) end
  return nil
end
IMT.__newindex = function(t, k, v)
  if k == "Parent" then
    local old = rawget(t, "_parent")
    if old then for i, c in ipairs(old._children) do if c == t then table.remove(old._children, i) break end end end
    rawset(t, "_parent", v)
    if v ~= nil then v._children[#v._children + 1] = t end
    return
  end
  if k == "Position" and BASEPART[t.ClassName] then
    local cf = rawget(t, "CFrame")
    rawset(t, "CFrame", CFrame.new(v.X, v.Y, v.Z) * cf.Rotation)
    return
  end
  if (k == "Size" or k == "CFrame") and BASEPART[t.ClassName] and type(v) ~= "table" then error("bad " .. k, 2) end
  rawset(t, k, v)
end
IMT.__tostring = function(t) return t.Name end
Instance = {}
function Instance.new(cls, parent)
  local t = { ClassName = cls, Name = cls, _children = {}, _attrs = {} }
  if BASEPART[cls] then
    t.Anchored = false t.CanCollide = true t.CanQuery = true t.CanTouch = true t.Transparency = 0
    t.Size = Vector3.new(4, 1, 2) t.CFrame = CFrame.new() t.Color = Color3.new(0.64, 0.64, 0.64) t.Material = "Enum.Material.Plastic"
    t.CastShadow = true t.Reflectance = 0 t.MaterialVariant = "" t.Massless = false t.CollisionGroup = "Default"
    if cls == "Part" then t.Shape = "Enum.PartType.Block" end
    t._frames = frames()
    CENSUS.parts[#CENSUS.parts + 1] = t
  elseif cls == "TextLabel" then
    t.Text = ""
  end
  setmetatable(t, IMT)
  if parent then t.Parent = parent end
  return t
end
-- a clone of a library mesh is a part made where it is cloned
local plainClone = IM.Clone
IM.Clone = function(self)
  local c = plainClone(self)
  local function mark(x)
    if BASEPART[x.ClassName] then rawset(x, "_frames", frames()) CENSUS.parts[#CENSUS.parts + 1] = x end
    for _, ch in ipairs(x._children) do mark(ch) end
  end
  mark(c)
  return c
end

-- the services and the workspace
local function folder(name, parent) local f = Instance.new("Folder") f.Name = name if parent then f.Parent = parent end return f end
local SERVICES = {}
workspace = Instance.new("Workspace")
workspace.Name = "Workspace"
local terrain = Instance.new("Terrain")
terrain.Name = "Terrain"
terrain.Parent = workspace
for _, m in ipairs({ "FillBlock", "FillBall", "FillCylinder", "FillWedge", "FillRegion", "WriteVoxels", "SetMaterialColor", "Clear", "ReplaceMaterial", "PasteRegion" }) do
  rawset(terrain, m, function() end)
end
rawset(terrain, "ReadVoxels", function() return {}, {} end)
rawset(terrain, "GetMaterialColor", function() return Color3.new(0.5, 0.5, 0.5) end)
GROUPS, NOCOLLIDE = {}, {}
-- rays against boxes and wedges (meshes by their box), as Roblox picks them: CanCollide parts always, others when CanQuery;
-- RespectCanCollide; the cast's collision group against the part's; Include / Exclude filters
local function rayPart(p, o, d)
  local cf, sz = p.CFrame, p.Size
  local lo = cf:PointToObjectSpace(o)
  local ld = cf:VectorToObjectSpace(d)
  local h = { sz.X / 2, sz.Y / 2, sz.Z / 2 }
  local O, D = { lo.X, lo.Y, lo.Z }, { ld.X, ld.Y, ld.Z }
  local t0, t1, n0 = 0, 1, nil
  for i = 1, 3 do
    if math.abs(D[i]) < 1e-12 then
      if O[i] < -h[i] or O[i] > h[i] then return nil end
    else
      local a, b = (-h[i] - O[i]) / D[i], (h[i] - O[i]) / D[i]
      local na = { 0, 0, 0 }
      na[i] = -1
      if a > b then a, b = b, a na[i] = 1 end
      if a > t0 then t0, n0 = a, na end
      if b < t1 then t1 = b end
      if t0 > t1 then return nil end
    end
  end
  if p.ClassName == "WedgePart" or p.Shape == "Wedge" then
    -- inside: y / Y - z / Z <= 0 (the slope from the bottom front edge to the top back edge)
    local nx, ny, nz = 0, 1 / sz.Y, -1 / sz.Z
    local f0 = ny * O[2] + nz * O[3]
    local fd = ny * D[2] + nz * D[3]
    if math.abs(fd) < 1e-12 then
      if f0 > 0 then return nil end
    else
      local tc = -f0 / fd
      if fd < 0 then
        if tc > t0 then t0, n0 = tc, { nx, ny, nz } end
      else
        if tc < t1 then t1 = tc end
      end
      if t0 > t1 then return nil end
    end
  end
  if not n0 then return nil end -- starts inside
  local nn = cf:VectorToWorldSpace(Vector3.new(n0[1], n0[2], n0[3])).Unit
  return t0, nn
end
local function inList(inst, list)
  for _, f in ipairs(list or {}) do
    if inst == f or inst:IsDescendantOf(f) then return true end
  end
  return false
end
rawset(workspace, "Raycast", function(self, o, d, params)
  params = params or RaycastParams.new()
  local cands
  local include = params.FilterType == "Enum.RaycastFilterType.Include"
  if include then
    cands = {}
    for _, f in ipairs(params.FilterDescendantsInstances or {}) do
      if BASEPART[f.ClassName] then cands[#cands + 1] = f end
      for _, x in ipairs(f:GetDescendants()) do cands[#cands + 1] = x end
    end
  else
    cands = workspace:GetDescendants()
  end
  local best, bt, bn = nil, math.huge, nil
  local group = params.CollisionGroup or "Default"
  for _, p in ipairs(cands) do
    if BASEPART[p.ClassName] and (p.CanCollide or p.CanQuery) and (not params.RespectCanCollide or p.CanCollide)
      and not NOCOLLIDE[group .. "|" .. (p.CollisionGroup or "Default")] and (include or not inList(p, params.FilterDescendantsInstances)) then
      local t, n = rayPart(p, o, d)
      if t and t < bt then best, bt, bn = p, t, n end
    end
  end
  if not best then return nil end
  return { Instance = best, Position = o + d * bt, Normal = bn, Distance = d.Magnitude * bt, Material = best.Material }
end)
rawset(workspace, "GetPartBoundsInBox", function() return {} end)
rawset(workspace, "GetPartBoundsInRadius", function() return {} end)
rawset(workspace, "GetPartsInPart", function() return {} end)
rawset(workspace, "Blockcast", function() return nil end)
rawset(workspace, "Spherecast", function() return nil end)
workspace.Gravity = 196.2
game = Instance.new("DataModel")
game.Name = "Game"
rawset(game, "GetService", function(self, n)
  local s = SERVICES[n]
  if not s then
    s = Instance.new(n)
    s.Name = n
    if n == "CollectionService" then
      local tags = {}
      rawset(s, "AddTag", function(_, inst, tag) tags[tag] = tags[tag] or {} tags[tag][inst] = true end)
      rawset(s, "RemoveTag", function(_, inst, tag) if tags[tag] then tags[tag][inst] = nil end end)
      rawset(s, "HasTag", function(_, inst, tag) return tags[tag] ~= nil and tags[tag][inst] == true end)
      rawset(s, "GetTagged", function(_, tag) local o = {} for i in pairs(tags[tag] or {}) do o[#o + 1] = i end return o end)
      rawset(s, "GetInstanceAddedSignal", function() return { Connect = function() end } end)
    elseif n == "RunService" then
      rawset(s, "IsStudio", function() return false end)
      rawset(s, "IsServer", function() return true end)
      rawset(s, "IsClient", function() return false end)
      s.Heartbeat = { Connect = function() return { Disconnect = function() end } end, Wait = function() return 0.03 end }
    elseif n == "PhysicsService" then
      rawset(s, "RegisterCollisionGroup", function(_, g) GROUPS[g] = true end)
      rawset(s, "UnregisterCollisionGroup", function(_, g) GROUPS[g] = nil end)
      rawset(s, "IsCollisionGroupRegistered", function(_, g) return g == "Default" or GROUPS[g] == true end)
      rawset(s, "CollisionGroupSetCollidable", function(_, a, b, on) NOCOLLIDE[a .. "|" .. b] = not on or nil NOCOLLIDE[b .. "|" .. a] = not on or nil end)
      rawset(s, "CollisionGroupsAreCollidable", function(_, a, b) return not NOCOLLIDE[a .. "|" .. b] end)
    elseif n == "Players" then
      rawset(s, "GetPlayers", function() return {} end)
    end
    SERVICES[n] = s
    s.Parent = game
  end
  return s
end)
game:GetService("Workspace")
SERVICES.Workspace = workspace

-- the mesh library (ServerStorage.ZR_Assets): every uploaded batch counts as loaded; a ZR_Kit5 mesh only with --kit5
LIBSIZE = {}
local lib = folder("ZR_Assets", game:GetService("ServerStorage"))
rawset(lib, "_find", function(self, name)
  if type(name) ~= "string" or name:sub(1, 3) ~= "ZR_" then return nil end
  if name:sub(1, 7) == "ZR_MK_K" and name:match("^ZR_MK_K5") and not CENSUS.kit5 then return nil end
  local m = Instance.new("MeshPart")
  -- library templates are not map parts
  table.remove(CENSUS.parts)
  m.Name = name
  m.Size = LIBSIZE[name] or Vector3.new(4, 6, 4)
  m.Anchored = true
  m.Parent = self
  return m
end)
"""


def module_tree():
    """name -> source path of every ModuleScript the map builders can reach, Rojo's layout: src/server/Maps (Maps),
    src/server/Services (Services), src/shared (ReplicatedStorage.ZR)."""
    mods = {}
    def walk(folder, prefix):
        for f in sorted(os.listdir(folder)):
            p = os.path.join(folder, f)
            if os.path.isdir(p):
                init = os.path.join(p, "init.luau")
                mods[prefix + f] = init if os.path.exists(init) else None
                walk(p, prefix + f + "/")
            elif f.endswith(".luau") and f != "init.luau":
                mods[prefix + f[:-5]] = p
    walk(os.path.join(ROOT, "src", "server", "Maps"), "Maps/")
    walk(os.path.join(ROOT, "src", "server", "Services"), "Services/")
    walk(os.path.join(ROOT, "src", "server", "Tests"), "Tests/")
    walk(os.path.join(ROOT, "src", "shared"), "ZR/")
    return mods


# modules that only reach services at run time (doors, hazards, ambient sound): a stand-in answers every call with nil
STUB_MODULES = {"Services/Hazards", "Services/Doors", "Services/Glass", "Services/Stationary", "Services/SpotFinder", "Services/Extract",
                "Services/Transit", "Services/Tripwires", "Services/Range", "Services/Loot", "Services/AI", "Services/Lobby"}

LOADER = r"""
local PY = ...
local cache, refs = {}, {}
local SERVER = Instance.new("Folder")
SERVER.Name = "ServerScriptService"
rawset(SERVER, "_find", function(self, name) if name == "Maps" or name == "Services" or name == "Tests" then return REF(name) end return nil end)
local function ref(path, kind)
  local r = refs[path]
  if r then return r end
  r = Instance.new(kind or "ModuleScript")
  r.Name = path:match("([^/]+)$")
  rawset(r, "_path", path)
  rawset(r, "_find", function(self, name)
    if type(name) ~= "string" then return nil end
    local p = path .. "/" .. name
    if PY.exists(p) then return REF(p) end
    return nil
  end)
  refs[path] = r
  local parent = path:match("^(.*)/[^/]+$")
  if parent then rawset(r, "_parent", REF(parent)) else rawset(r, "_parent", SERVER) end
  return r
end
function REF(path) return ref(path, PY.isfolder(path) and "Folder" or "ModuleScript") end
local permissive = setmetatable({}, { __index = function() return function() return nil end end })
function require(r)
  local path = type(r) == "table" and rawget(r, "_path")
  if not path then error("require of a non-module " .. tostring(r), 2) end
  if cache[path] ~= nil then return cache[path] end
  if PY.stub(path) then cache[path] = permissive return permissive end
  local src = PY.source(path)
  if not src then error("no module " .. path, 2) end
  local env = setmetatable({ script = r }, { __index = _G })
  local fn, err = load(src, "=M:" .. path:gsub("^Maps/", ""):gsub("^ZR/", "shared/"), "t", env)
  if not fn then error(err, 2) end
  cache[path] = true -- a cycle sees true
  local ok, res = pcall(fn)
  if not ok then
    if path:sub(1, 3) == "ZR/" then warn("shared module " .. path .. " failed (stand-in used): " .. tostring(res)) cache[path] = permissive return permissive end
    error(res, 0)
  end
  cache[path] = res == nil and true or res
  return cache[path]
end
-- ReplicatedStorage.ZR is the shared folder; the server's Maps and Services folders sit under ServerScriptService
local RS = game:GetService("ReplicatedStorage")
local zr = REF("ZR")
rawset(zr, "_parent", RS)
RS._children[#RS._children + 1] = zr
"""


def lua_runtime(kit5):
    from lupa.lua54 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(MOCK)
    mods = module_tree()
    conv_cache = {}

    class PY:
        @staticmethod
        def exists(path):
            return path in mods

        @staticmethod
        def isfolder(path):
            return path in mods and mods[path] is None

        @staticmethod
        def stub(path):
            return path in STUB_MODULES

        @staticmethod
        def source(path):
            f = mods.get(path)
            if not f:
                return None
            if f not in conv_cache:
                conv_cache[f] = conv(open(f, encoding="utf-8").read())
            return conv_cache[f]

    lua.execute(LOADER, PY)
    G = lua.globals()
    G.CENSUS.kit5 = bool(kit5)
    # library sizes: kit pieces get their prop's size, nature and cover meshes a nominal one
    km = open(os.path.join(ROOT, "src", "shared", "KitMeta.luau"), encoding="utf-8").read()
    ls = G.LIBSIZE
    for m in re.finditer(r'^\s*(\w+)\s*=\s*\{ batch = "[^"]+", size = V\(([^)]*)\)', km, re.M):
        s = [float(v) for v in m.group(2).split(',')]
        for mat in re.findall(r'mat = "(\w+)"', km[m.end():km.find('\n', m.end())]):
            ls["ZR_MK_%s__%s" % (m.group(1), mat)] = lua.eval("Vector3.new")(*s)
    return lua, G


# World.luau's primitives and kit (World.kit()), run as they are: the text from the palette to the end of addExtract
WORLD_HEAD = r"""
local World = WORLD_T
local root = ROOT_T
local currentMap = "census"
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Config = require(Shared.Config)
local AssetMeta = require(Shared.AssetMeta)
"""
WORLD_TAIL = r"""
return {
  World = World, root = root, C = C, M = M, hex = hex, rng = rng, Props = Props,
  part = part, box = box, boxCF = boxCF, cyl = cyl, vcyl = vcyl, model = model, jitter = jitter, light = light,
  sign = sign, mesh = mesh, wall = wall, wallHoles = wallHoles, loose = loose,
  container = addContainerSpot, extract = addExtract, foliage = function() return {} end,
  stationary = function() return nil end,
}
"""


def world_kit(lua, G):
    src = open(os.path.join(ROOT, "src", "server", "Services", "World.luau"), encoding="utf-8").read()
    a = src.index("local rng = Random.new(707)")
    b = src.index("local function buildGround(map)")
    body = conv(src[a:b])
    lua.execute("""
      WORLD_T = { spawns = {}, extracts = {}, containers = {}, patrols = {}, doors = {}, switches = {}, looseSpots = {}, sideExtracts = {},
        scavZones = {}, watchPosts = {}, visitZones = {}, natureRegions = {}, transits = {}, maps = {}, foliage = { cells = {}, n = 0 } }
      ROOT_T = Instance.new("Folder")
      ROOT_T.Name = "ZR_World"
      local trig = Instance.new("Folder")
      trig.Name = "Triggers"
      trig.Parent = ROOT_T
    """)
    env = lua.eval("setmetatable({ script = REF('Services/World') }, { __index = _G })")
    fn = lua.eval("function(src, env) local f, e = load(src, '=M:World', 't', env) if not f then error(e) end return f() end")
    return fn(WORLD_HEAD + body + WORLD_TAIL, env)


MAPS = {
    "border": ("Maps/Border", "Border"),
    "meridian": ("Maps/Meridian", "Meridian"),
    "smelter": ("Maps/Smelter", "Smelter"),
    "relay7": ("Maps/Relay7", "Relay7"),
}


def runtime(kit5, merge=None):
    """the stand-in with the World kit; with kit5, the Kit5 props in KitMeta and their meshes in the library; with merge
    (an absorb share), the merged pieces in KitMeta and the library and Kit.MERGE on for the mall and bunker batches"""
    lua, G = lua_runtime(kit5)
    if kit5:
        # the Kit5 props as tools/kit_meta.py will list them after the export, and their meshes in the library
        meta = kit5_meta()
        ls = G.LIBSIZE
        v3 = lua.eval("Vector3.new")
        props = lua.eval('require(REF("ZR/KitMeta"))').props
        for pname, m in meta.items():
            pieces = lua.table()
            for i, pc in enumerate(m["pieces"], 1):
                pieces[i] = lua.table_from({"mat": pc["mat"], "center": v3(*pc["center"]), "tris": pc["tris"]})
                ls["ZR_MK_%s__%s" % (pname, pc["mat"])] = v3(*pc["size"])
            props[pname] = lua.table_from({"batch": m["batch"], "size": v3(*m["size"]), "center": v3(*m["center"]), "pieces": pieces})
    if merge is not None:
        v3 = lua.eval("Vector3.new")
        props = lua.eval('require(REF("ZR/KitMeta"))').props
        for nm, e in merge_entries(merge).items():
            if props[nm] is not None:
                props[nm].merged = lua.table_from({"mat": e["mat"], "center": v3(*e["center"]), "tris": e["tris"], "of": lua.table_from(e["of"])})
                G.LIBSIZE["ZR_MK_%s__%s_M" % (nm, e["mat"])] = v3(*e["size"])
        K = lua.eval('require(REF("Maps/Kit"))')
        for b in KIT_SCRIPTS:
            K.MERGE[b] = True
    # every Kit.place call: the prop and whether it took its merged piece (mergecost)
    lua.execute("""
      KITPLACES = {}
      local K = require(REF("Maps/Kit"))
      local place = K.place
      K.place = function(parent, name, cf, opts)
        local m = place(parent, name, cf, opts)
        local merged = false
        if m then
          for _, c in ipairs(m:GetChildren()) do
            if c:GetAttribute("KitMerged") then merged = true end
          end
        end
        KITPLACES[#KITPLACES + 1] = { name = name, merged = merged }
        return m
      end
    """)
    kit = world_kit(lua, G)
    return lua, G, kit


def run(name, outp, kit5=False, quiet=False, merge=None):
    lua, G, kit = runtime(kit5, merge)
    G.ZR_KIT5_LOG = lua.table()
    path, model = MAPS[name]
    runner = lua.eval("""function(kit, path, name)
      local t0 = os.clock()
      local m
      if name == "Relay7" then
        local R = require(REF(path))
        local sh = R.build(kit.root, Vector3.new(0, 0, 4000))
        m = sh and (sh.model or sh.shell)
      else
        m = require(REF(path))(kit, kit.root)
      end
      return m, os.clock() - t0
    end""")
    m, secs = runner(kit, path, model)
    if m is None:
        raise SystemExit("%s: the builder returned no model; warnings: %s" % (name, list(G.WARNS.values())[:10]))
    rec_fn = lua.eval("""function(m)
      local out = {}
      for _, d in ipairs(m:GetDescendants()) do
        if d.ClassName == "Part" or d.ClassName == "WedgePart" or d.ClassName == "MeshPart" or d.ClassName == "CornerWedgePart" or d.ClassName == "TrussPart" then
          local path, q = {}, rawget(d, "_parent")
          while q and q ~= m do table.insert(path, 1, q.Name) q = rawget(q, "_parent") end
          local cf = d.CFrame
          out[#out + 1] = { cls = d.ClassName, name = d.Name, path = path, size = d.Size, cf = cf, collide = d.CanCollide, query = d.CanQuery,
            transp = d.Transparency, mat = tostring(d.Material), frames = rawget(d, "_frames") or {}, attrs = d._attrs }
        end
      end
      return out
    end""")
    recs = rec_fn(m)

    def v3(v):
        return [round(v.X, 4), round(v.Y, 4), round(v.Z, 4)]

    parts = []
    for i in range(1, len(recs) + 1):
        r = recs[i]
        cf = r.cf
        parts.append({
            "cls": r.cls, "name": str(r.name), "path": [str(x) for x in r.path.values()], "size": v3(r.size),
            "pos": [round(cf.x, 3), round(cf.y, 3), round(cf.z, 3)], "rot": [round(cf[k], 4) for k in "abcdefghi"],
            "collide": bool(r.collide), "query": bool(r.query), "transp": float(r.transp), "mat": r.mat,
            "frames": [[str(f[1]), str(f[2]), int(f[3]), int(f[4])] for f in r.frames.values()],
            "attrs": {str(k): (v if isinstance(v, (int, float, str, bool)) else str(v)) for k, v in r.attrs.items()},
        })
    log = []
    for i in range(1, len(G.ZR_KIT5_LOG) + 1):
        e = G.ZR_KIT5_LOG[i]
        log.append({str(k): (v if isinstance(v, (int, float, str, bool)) else str(v)) for k, v in e.items()})
    places = [[str(e.name), bool(e.merged)] for e in G.KITPLACES.values()]
    rec = {"map": name, "kit5": kit5, "merge": merge, "seconds": secs, "parts": parts, "kitlog": log, "places": places,
           "warns": [str(w) for w in G.WARNS.values()], "prints": [str(p) for p in G.PRINTS.values()]}
    with open(outp, "w") as f:
        json.dump(rec, f)
    if not quiet:
        print("%s%s%s: %d parts in %.1f s, %d warnings" % (name, " (kit5)" if kit5 else "", (" (merge %.2f)" % merge) if merge is not None else "",
                                                         len(parts), secs, len(rec["warns"])))
        for w in rec["warns"][:12]:
            print("   warn:", w[:220])
    return rec


def tests(kit5, merge=None):
    """src/server/Tests/KitTests.luau under the stand-in, with the Smelter built (its K05 map): NOT Studio"""
    lua, G, kit = runtime(kit5, merge)
    res = lua.eval("""function(kit)
      local m = require(REF("Maps/Smelter"))(kit, kit.root)
      kit.root.Parent = workspace
      local W = { kit = function() return kit end, maps = { smelter = { model = m } } }
      return require(REF("Tests/KitTests")).run({ World = W })
    end""")(kit)
    print("KitTests%s%s (offline, Lua 5.4 stand-in): %s" % (" with ZR_Kit5" if kit5 else "", " and merged pieces" if merge is not None else "", res))
    for w in list(G.WARNS.values())[:10]:
        print("   warn:", str(w)[:200])
    return res


def kit5_meta():
    """The ZR_Kit5 meshes' metadata as tools/kit_meta.py will write it after the export (computed from
    build_kit5.py's variant table, which needs no Blender)."""
    sys.path.insert(0, os.path.join(ROOT, "assets", "blender_scripts"))
    import build_kit5  # noqa: E402
    return build_kit5.expected_meta()


# ── an offline stand-in for Blender (mathutils, bmesh, bpy) ───────────────────────────────────────────────────
# Enough to run the kit build scripts' geometry outside Blender and measure each piece's surface area for the merge
# plan (art-5b phase 2). Bevels are skipped (a bevelled box counts as its box), n-gons stay n-gons (area is the same),
# vertex colours are kept per corner and never baked. NOT Blender: no export, no render.


class Vector:
    __slots__ = ("_v",)

    def __init__(self, v=(0.0, 0.0, 0.0)):
        self._v = [float(a) for a in v]

    def _g(i):
        return property(lambda s: s._v[i], lambda s, a: s._v.__setitem__(i, float(a)))
    x, y, z, w = _g(0), _g(1), _g(2), _g(3)
    del _g

    def __len__(self):
        return len(self._v)

    def __iter__(self):
        return iter(self._v)

    def __getitem__(self, i):
        return self._v[i]

    def __setitem__(self, i, a):
        self._v[i] = float(a)

    def __add__(self, o):
        return Vector([a + b for a, b in zip(self._v, o)])
    __radd__ = __add__

    def __sub__(self, o):
        return Vector([a - b for a, b in zip(self._v, o)])

    def __rsub__(self, o):
        return Vector([b - a for a, b in zip(self._v, o)])

    def __mul__(self, k):
        if isinstance(k, (int, float)):
            return Vector([a * k for a in self._v])
        return Vector([a * b for a, b in zip(self._v, k)])
    __rmul__ = __mul__

    def __truediv__(self, k):
        return Vector([a / k for a in self._v])

    def __neg__(self):
        return Vector([-a for a in self._v])

    def __matmul__(self, o):
        return sum(a * b for a, b in zip(self._v, o))

    def dot(self, o):
        return sum(a * b for a, b in zip(self._v, o))

    def cross(self, o):
        a, b = self._v, list(o)
        return Vector((a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]))

    @property
    def length(self):
        return math.sqrt(sum(a * a for a in self._v))

    @property
    def length_squared(self):
        return sum(a * a for a in self._v)

    def normalized(self):
        n = self.length
        return Vector([a / n for a in self._v]) if n > 0 else Vector(self._v)

    def normalize(self):
        n = self.length
        if n > 0:
            self._v = [a / n for a in self._v]

    def copy(self):
        return Vector(self._v)

    def orthogonal(self):
        x, y, z = self._v[:3]
        return Vector((-y, x, 0.0)) if abs(z) < 0.9 * max(abs(x), abs(y), abs(z), 1e-12) else Vector((0.0, -z, y))

    def lerp(self, o, t):
        return Vector([a + (b - a) * t for a, b in zip(self._v, o)])

    def rotation_difference(self, o):
        a, b = self.normalized(), Vector(o).normalized()
        d = max(-1.0, min(1.0, a.dot(b)))
        if d > 1 - 1e-12:
            return Quaternion()
        if d < -1 + 1e-12:
            ax = a.orthogonal().normalized()
            return Quaternion((0.0, ax.x, ax.y, ax.z))
        c = a.cross(b)
        q = Quaternion((1 + d, c.x, c.y, c.z))
        return q.normalized()

    def to_tuple(self, p=None):
        return tuple(self._v)

    def __repr__(self):
        return "Vector(%s)" % ", ".join("%.4f" % a for a in self._v)


class Quaternion:
    def __init__(self, wxyz=(1.0, 0.0, 0.0, 0.0)):
        self.w, self.x, self.y, self.z = [float(a) for a in wxyz]

    def normalized(self):
        n = math.sqrt(self.w ** 2 + self.x ** 2 + self.y ** 2 + self.z ** 2) or 1.0
        return Quaternion((self.w / n, self.x / n, self.y / n, self.z / n))

    def __matmul__(self, o):
        if isinstance(o, Quaternion):
            a, b = self, o
            return Quaternion((a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z, a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
                               a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x, a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w))
        return self.to_matrix() @ Vector(o)

    def to_matrix(self):
        w, x, y, z = self.w, self.x, self.y, self.z
        return Matrix([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                       [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                       [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])

    def to_euler(self, order="XYZ"):
        return self.to_matrix().to_euler()


class Euler:
    def __init__(self, v=(0.0, 0.0, 0.0), order="XYZ"):
        self.x, self.y, self.z = [float(a) for a in v]
        self.order = order

    def __iter__(self):
        return iter((self.x, self.y, self.z))

    def __getitem__(self, i):
        return (self.x, self.y, self.z)[i]

    def to_matrix(self):
        return Matrix.Rotation(self.z, 3, "Z") @ Matrix.Rotation(self.y, 3, "Y") @ Matrix.Rotation(self.x, 3, "X")

    def to_quaternion(self):
        def axis(a, i):
            v = [0.0, 0.0, 0.0]
            v[i] = math.sin(a / 2)
            return Quaternion((math.cos(a / 2), v[0], v[1], v[2]))
        return axis(self.z, 2) @ axis(self.y, 1) @ axis(self.x, 0)


class Matrix:
    def __init__(self, rows=None):
        self.m = [[float(a) for a in r] for r in rows] if rows is not None else [[float(i == j) for j in range(4)] for i in range(4)]

    @staticmethod
    def Identity(n):
        return Matrix([[float(i == j) for j in range(n)] for i in range(n)])

    @staticmethod
    def Translation(v):
        m = Matrix.Identity(4)
        v = list(v)
        for i in range(3):
            m.m[i][3] = float(v[i])
        return m

    @staticmethod
    def Rotation(angle, size, axis):
        c, s = math.cos(angle), math.sin(angle)
        if isinstance(axis, str):
            r = {"X": [[1, 0, 0], [0, c, -s], [0, s, c]], "Y": [[c, 0, s], [0, 1, 0], [-s, 0, c]], "Z": [[c, -s, 0], [s, c, 0], [0, 0, 1]]}[axis]
        else:
            x, y, z = Vector(axis).normalized()
            t = 1 - c
            r = [[t * x * x + c, t * x * y - s * z, t * x * z + s * y], [t * x * y + s * z, t * y * y + c, t * y * z - s * x],
                 [t * x * z - s * y, t * y * z + s * x, t * z * z + c]]
        if size == 3:
            return Matrix(r)
        m = Matrix.Identity(4)
        for i in range(3):
            m.m[i][:3] = [float(a) for a in r[i]]
        return m

    @staticmethod
    def LocRotScale(loc, rot, scale):
        r = Matrix.Identity(3)
        if isinstance(rot, Quaternion):
            r = rot.to_matrix()
        elif isinstance(rot, Euler):
            r = rot.to_matrix()
        elif isinstance(rot, Matrix):
            r = Matrix([row[:3] for row in rot.m[:3]])
        s = list(scale) if scale is not None else [1.0, 1.0, 1.0]
        m = Matrix.Identity(4)
        for i in range(3):
            for j in range(3):
                m.m[i][j] = r.m[i][j] * s[j]
        if loc is not None:
            loc = list(loc)
            for i in range(3):
                m.m[i][3] = float(loc[i])
        return m

    def __matmul__(self, o):
        if isinstance(o, Matrix):
            n = len(self.m)
            return Matrix([[sum(self.m[i][k] * o.m[k][j] for k in range(n)) for j in range(n)] for i in range(n)])
        v = list(o)
        n = len(self.m)
        if n == 4 and len(v) == 3:
            return Vector([sum(self.m[i][k] * v[k] for k in range(3)) + self.m[i][3] for i in range(3)])
        return Vector([sum(self.m[i][k] * v[k] for k in range(len(v))) for i in range(len(v))])

    def decompose(self):
        cols = [Vector([self.m[i][j] for i in range(3)]) for j in range(3)]
        s = Vector([c.length for c in cols])
        r = Matrix([[self.m[i][j] / (s[j] or 1.0) for j in range(3)] for i in range(3)])
        return Vector([self.m[i][3] for i in range(3)]), r.to_quaternion(), s

    def to_quaternion(self):
        m = self.m
        t = m[0][0] + m[1][1] + m[2][2]
        if t > 0:
            s = math.sqrt(t + 1.0) * 2
            return Quaternion((0.25 * s, (m[2][1] - m[1][2]) / s, (m[0][2] - m[2][0]) / s, (m[1][0] - m[0][1]) / s))
        if m[0][0] > m[1][1] and m[0][0] > m[2][2]:
            s = math.sqrt(1.0 + m[0][0] - m[1][1] - m[2][2]) * 2
            return Quaternion(((m[2][1] - m[1][2]) / s, 0.25 * s, (m[0][1] + m[1][0]) / s, (m[0][2] + m[2][0]) / s))
        if m[1][1] > m[2][2]:
            s = math.sqrt(1.0 + m[1][1] - m[0][0] - m[2][2]) * 2
            return Quaternion(((m[0][2] - m[2][0]) / s, (m[0][1] + m[1][0]) / s, 0.25 * s, (m[1][2] + m[2][1]) / s))
        s = math.sqrt(1.0 + m[2][2] - m[0][0] - m[1][1]) * 2
        return Quaternion(((m[1][0] - m[0][1]) / s, (m[0][2] + m[2][0]) / s, (m[1][2] + m[2][1]) / s, 0.25 * s))

    def to_euler(self, order="XYZ"):
        m = self.m
        y = math.asin(max(-1.0, min(1.0, -m[2][0])))
        if abs(m[2][0]) < 0.999999:
            x, z = math.atan2(m[2][1], m[2][2]), math.atan2(m[1][0], m[0][0])
        else:
            x, z = math.atan2(-m[1][2], m[1][1]), 0.0
        return Euler((x, y, z))


# bmesh
class _UV:
    __slots__ = ("uv",)

    def __init__(self):
        self.uv = (0.0, 0.0)


class BMLoop:
    __slots__ = ("vert", "face", "_d")

    def __init__(self, vert, face):
        self.vert, self.face, self._d = vert, face, {}

    def __getitem__(self, layer):
        if layer not in self._d:
            self._d[layer] = _UV() if layer[0] == "uv" else (1.0, 1.0, 1.0, 1.0)
        return self._d[layer]

    def __setitem__(self, layer, v):
        self._d[layer] = v


class BMVert:
    __slots__ = ("co", "__weakref__")

    def __init__(self, co):
        self.co = Vector(co)


class BMFace:
    __slots__ = ("verts", "loops", "smooth", "material_index", "__weakref__")

    def __init__(self, verts):
        self.verts = list(verts)
        self.loops = [BMLoop(v, self) for v in self.verts]
        self.smooth = False
        self.material_index = 0

    def _newell(self):
        n = [0.0, 0.0, 0.0]
        vs = [v.co for v in self.verts]
        for i in range(len(vs)):
            a, b = vs[i], vs[(i + 1) % len(vs)]
            n[0] += (a.y - b.y) * (a.z + b.z)
            n[1] += (a.z - b.z) * (a.x + b.x)
            n[2] += (a.x - b.x) * (a.y + b.y)
        return Vector(n)

    @property
    def normal(self):
        return self._newell().normalized()

    def normal_update(self):
        pass

    def calc_center_median(self):
        k = len(self.verts)
        return Vector((sum(v.co.x for v in self.verts) / k, sum(v.co.y for v in self.verts) / k, sum(v.co.z for v in self.verts) / k))

    def calc_area(self):
        vs = [v.co for v in self.verts]
        if len(vs) == 4:  # a quad may be bent (displaced sheets): two triangles
            return 0.5 * ((vs[1] - vs[0]).cross(vs[2] - vs[0]).length + (vs[2] - vs[0]).cross(vs[3] - vs[0]).length)
        return 0.5 * self._newell().length

    @property
    def edges(self):
        return [(self.verts[i], self.verts[(i + 1) % len(self.verts)]) for i in range(len(self.verts))]

    def flip(self):
        self.verts.reverse()
        self.loops.reverse()


class _Seq(list):
    def ensure_lookup_table(self):
        pass

    def index_update(self):
        pass


class _Verts(_Seq):
    def new(self, co=(0.0, 0.0, 0.0), example=None):
        v = BMVert(co)
        self.append(v)
        return v


class _Faces(_Seq):
    def new(self, verts, example=None):
        f = BMFace(verts)
        self.append(f)
        return f


class _LayerColl:
    def __init__(self, kind):
        self.kind, self.names = kind, set()

    def new(self, name="Col"):
        self.names.add(name)
        return (self.kind, name)

    def get(self, name):
        return (self.kind, name) if name in self.names else None


class BMesh:
    def __init__(self):
        self.verts, self.faces = _Verts(), _Faces()
        self.loops = types.SimpleNamespace(layers=types.SimpleNamespace(color=_LayerColl("color"), uv=_LayerColl("uv")))

    def normal_update(self):
        pass

    def free(self):
        self.verts, self.faces = _Verts(), _Faces()

    def to_mesh(self, me):
        idx = {v: i for i, v in enumerate(self.verts)}
        me._geo = ([tuple(v.co) for v in self.verts], [([idx[v] for v in f.verts], [dict(l._d) for l in f.loops], f.smooth) for f in self.faces])

    def from_mesh(self, me, **kw):
        vs, fs = me._geo or ([], [])
        nv = [self.verts.new(c) for c in vs]
        for ids, loops, smooth in fs:
            f = self.faces.new([nv[i] for i in ids])
            f.smooth = smooth
            for l, d in zip(f.loops, loops):
                l._d.update(d)

    def area(self):
        return sum(f.calc_area() for f in self.faces)


def _cube(bm, size=1.0, matrix=None, calc_uvs=False):
    m = matrix or Matrix.Identity(4)
    h = size / 2
    c = [bm.verts.new(m @ Vector((x * h, y * h, z * h))) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    # corner index: (x>0)*4 + (y>0)*2 + (z>0); faces wound outward
    for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        bm.faces.new([c[i] for i in q])
    return {"verts": c}


def _cone(bm, cap_ends=True, cap_tris=False, segments=8, radius1=1.0, radius2=1.0, depth=1.0, matrix=None, calc_uvs=False, **kw):
    m = matrix or Matrix.Identity(4)
    lo = [bm.verts.new(m @ Vector((radius1 * math.cos(2 * math.pi * k / segments), radius1 * math.sin(2 * math.pi * k / segments), -depth / 2))) for k in range(segments)]
    hi = [bm.verts.new(m @ Vector((radius2 * math.cos(2 * math.pi * k / segments), radius2 * math.sin(2 * math.pi * k / segments), depth / 2))) for k in range(segments)]
    for k in range(segments):
        k2 = (k + 1) % segments
        bm.faces.new((lo[k], lo[k2], hi[k2], hi[k]))
    if cap_ends:
        if radius1 > 0:
            bm.faces.new(list(reversed(lo)))
        if radius2 > 0:
            bm.faces.new(hi)
    return {"verts": lo + hi}


def _icosphere(bm, subdivisions=1, radius=1.0, matrix=None, calc_uvs=False, **kw):
    t = (1 + 5 ** 0.5) / 2
    pts = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    tris = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
            (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    P = [Vector(p).normalized() for p in pts]
    for _ in range(max(0, subdivisions - 1)):
        cache, nt = {}, []

        def mid(a, b):
            k = (min(a, b), max(a, b))
            if k not in cache:
                P.append(((P[a] + P[b]) / 2).normalized())
                cache[k] = len(P) - 1
            return cache[k]
        for a, b, c in tris:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            nt += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        tris = nt
    m = matrix or Matrix.Identity(4)
    vs = [bm.verts.new(m @ (p * radius)) for p in P]
    for a, b, c in tris:
        bm.faces.new((vs[a], vs[b], vs[c]))
    return {"verts": vs}


def _recalc(bm, faces=(), **kw):
    faces = list(faces)
    pts = {v for f in faces for v in f.verts}
    if not pts:
        return
    c = Vector((sum(v.co.x for v in pts) / len(pts), sum(v.co.y for v in pts) / len(pts), sum(v.co.z for v in pts) / len(pts)))
    for f in faces:
        if f._newell().dot(f.calc_center_median() - c) < 0:
            f.flip()


def _delete(bm, geom=(), context="FACES"):
    kill = set(id(g) for g in geom if isinstance(g, BMFace))
    bm.faces[:] = [f for f in bm.faces if id(f) not in kill]


def _transform(bm, matrix=None, verts=(), space=None, **kw):
    for v in verts:
        v.co = matrix @ v.co


def _scale(bm, vec=(1, 1, 1), verts=(), **kw):
    for v in verts:
        v.co = Vector((v.co.x * vec[0], v.co.y * vec[1], v.co.z * vec[2]))


class _Data:
    def __init__(self):
        self.store = {}

    def get(self, name):
        return self.store.get(name)

    def new(self, name, *a):
        o = types.SimpleNamespace(name=name, _geo=None, users=0, materials=[], color_attributes=None)
        self.store[name] = o
        return o

    def remove(self, o, **kw):
        self.store.pop(getattr(o, "name", None), None)

    def __iter__(self):
        return iter(list(self.store.values()))


def standin_install():
    """put the stand-in modules in sys.modules (bpy, bmesh, mathutils, mathutils.bvhtree)"""
    mu = types.ModuleType("mathutils")
    mu.Vector, mu.Matrix, mu.Euler, mu.Quaternion = Vector, Matrix, Euler, Quaternion
    bvh = types.ModuleType("mathutils.bvhtree")
    bvh.BVHTree = type("BVHTree", (), {})
    mu.bvhtree = bvh
    bm = types.ModuleType("bmesh")
    bm.new = BMesh
    bm.ops = types.SimpleNamespace(create_cube=_cube, create_cone=_cone, create_icosphere=_icosphere, bevel=lambda *a, **k: {},
                                   recalc_face_normals=_recalc, triangulate=lambda *a, **k: {}, delete=_delete, transform=_transform,
                                   scale=_scale, remove_doubles=lambda *a, **k: {})
    bpy = types.ModuleType("bpy")
    bpy.data = types.SimpleNamespace(meshes=_Data(), objects=_Data(), scenes=_Data(), materials=_Data(), worlds=_Data(),
                                     curves=_Data(), cameras=_Data())
    bpy.context = types.SimpleNamespace()
    bpy.ops = types.SimpleNamespace()
    for k, v in (("mathutils", mu), ("mathutils.bvhtree", bvh), ("bmesh", bm), ("bpy", bpy)):
        sys.modules[k] = v


# ── merged pieces (art-5b phase 2): the plan, its look cost and its parts ─────────────────────────────────────────
KIT_SCRIPTS = {"ZR_MallKitA": "build_mall_kit_a.py", "ZR_MallKitB": "build_mall_kit_b.py", "ZR_MallKitC": "build_mall_kit_c.py",
               "ZR_BunkerKitA": "build_bunker_kit_a.py", "ZR_BunkerKitB": "build_bunker_kit_b.py", "ZR_BunkerKitC": "build_bunker_kit_c.py"}
_AREAS = {}


def zr_kit_offline():
    """assets/blender_scripts/zr_kit.py imported under the stand-in (its merge rule needs no Blender)"""
    standin_install()
    bs = os.path.join(ROOT, "assets", "blender_scripts")
    if bs not in sys.path:
        sys.path.insert(0, bs)
    import zr_kit  # noqa: E402
    return zr_kit


def kit_areas():
    """every mall and bunker kit piece's surface area {batch: {prop: {mat: area}}}: the build scripts' PROPS run under the
    stand-in. Checked 2026-11-09 against the exported pieces' bounding boxes: 416 of 449 within 0.02 studs, the rest
    rubble chunks and cylinders turned a few degrees (their area is the same)."""
    if not _AREAS:
        zr_kit_offline()
        bs = os.path.join(ROOT, "assets", "blender_scripts")
        for batch, script in KIT_SCRIPTS.items():
            g = {"__name__": "kit_offline"}
            exec(compile(open(os.path.join(bs, script), encoding="utf-8").read(), script, "exec"), g)
            for nm, fn in g["PROPS"].items():
                P = fn()
                _AREAS.setdefault(batch, {})[nm] = {m: b.bm.area() for m, b in P.b.items() if len(b.bm.faces)}
    return _AREAS


def merge_entries(absorb=1.0):
    """the merged pieces as tools/kit_meta.py will list them after zr_kit.kit_export_merged(absorb), from the split
    exports' bounding boxes (a joined mesh's box is its pieces' boxes together), with each prop's areas and look cost"""
    zk = zr_kit_offline()
    out = {}
    for batch, props in kit_areas().items():
        meta = json.load(open(os.path.join(ROOT, "assets", "exports", batch + ".meta.json")))
        for nm, ar in props.items():
            plan = None if nm in zk.MERGE_SKIP else zk.merge_plan(ar, absorb)
            if plan is None:
                continue
            rep, joined, cost = plan
            lo, hi, tris = [1e9] * 3, [-1e9] * 3, 0
            for m in joined:
                e = meta["ZR_MK_%s__%s" % (nm, m)]
                for i in range(3):
                    lo[i] = min(lo[i], e["center"][i] - e["size"][i] / 2)
                    hi[i] = max(hi[i], e["center"][i] + e["size"][i] / 2)
                tris += e.get("tris", 0)
            out[nm] = {"batch": batch, "mat": rep, "of": joined, "center": [(lo[i] + hi[i]) / 2 for i in range(3)],
                       "size": [hi[i] - lo[i] for i in range(3)], "tris": tris, "cost": cost, "area": sum(ar.values())}
    return out


def merge_report(absorb=1.0):
    """the plan per batch: pieces for one of each prop before and after, and the look cost (the share of the batch's
    kit surface whose Roblox material, variant or reflectance changes)"""
    mg = merge_entries(absorb)
    print("merge plan, absorb %.2f (zr_kit.merge_plan; areas from the build scripts under the stand-in):" % absorb)
    rows = []
    for batch, props in kit_areas().items():
        before = sum(len(a) for a in props.values())
        after = sum(len(a) - (len(mg[nm]["of"]) - 1 if nm in mg else 0) for nm, a in props.items())
        area = sum(sum(a.values()) for a in props.values())
        cost = sum(mg[nm]["cost"] for nm in props if nm in mg)
        print("  %-14s %3d props, %3d merged: %3d pieces -> %3d; look cost %4.1f %% of its surface" % (
            batch, len(props), sum(1 for nm in props if nm in mg), before, after, 100 * cost / area))
        rows += [(mg[nm]["cost"] / mg[nm]["area"], nm, mg[nm]["mat"], mg[nm]["of"]) for nm in props if nm in mg]
    rows.sort(reverse=True)
    print("  highest look cost: " + "; ".join("%s %.0f %% (%s into %s)" % (nm, 100 * c, "+".join(of), mat) for c, nm, mat, of in rows[:8]))
    return mg


def mergecost(split_path, merged_path):
    """a map's merge from two runs of the same map (split, merged): the parts saved, the placements that took a merged
    piece (and why the others did not), and the look cost by what is placed: the share of the placed kit surface whose
    Roblox material changes"""
    a, b = json.load(open(split_path)), json.load(open(merged_path))
    mg = merge_entries(b.get("merge") if b.get("merge") is not None else 1.0)
    areas = {nm: ar for props in kit_areas().values() for nm, ar in props.items()}
    surf = cost = 0.0
    took = kept = 0
    for nm, merged in b.get("places", []):
        if nm not in areas:
            continue
        surf += sum(areas[nm].values())
        if merged:
            took += 1
            cost += mg[nm]["cost"]
        elif nm in mg:
            kept += 1
    print("=== %s: %d -> %d parts (%+d); %d kit placements took a merged piece, %d of mergeable props kept their pieces "
          "(tinted, re-materialled or NOMERGE); look cost %.1f %% of the placed kit surface ===" % (
              a["map"], len(a["parts"]), len(b["parts"]), len(b["parts"]) - len(a["parts"]), took, kept, 100 * cost / surf if surf else 0.0))


# ── categories by builder call ─────────────────────────────────────────────────────────────────────────────────
# (module suffix, function name) -> category; the innermost frame that matches decides
RULES = [
    # stairs
    ("MapKit", "stairs", "stairs"), ("Border/Works", "stairs", "stairs"), ("Border/Works", "bunkerStairs", "stairs"),
    ("Border/Works", "k13Flights", "stairs"), ("Border/Living", "flight", "stairs"), ("Border/Living", "dormStairs", "stairs"),
    ("SmelterParts/Shell", "flight", "stairs"), ("Meridian/MallLinks", "?", "stairs"), ("MapKit", "flight", "stairs"),
    ("MapKit", "k5Flight", "stairs"), ("MapKit", "k5Rail", "rails"),
    # railings and handrails
    ("MapKit", "rail", "rails"), ("Border/Works", "rail", "rails"), ("Border/Works", "railAt", "rails"), ("Border/Works", "railRect", "rails"),
    ("Border/Works", "pitRails", "rails"), ("Border/Living", "rail", "rails"), ("Meridian/MallShell", "railRun", "rails"),
    ("Meridian/MallLinks", "sides", "rails"),
    # walls, slabs, roofs
    ("World", "wallHoles", "walls"), ("World", "wall", "walls"), ("MapKit", "wallX", "walls"), ("MapKit", "wallZ", "walls"),
    ("Border/Works", "wl", "walls"), ("Border/Works", "rectWalls", "walls"), ("MapKit", "slab", "slabs"), ("Border/Works", "slab", "slabs"),
    ("MapKit", "roof", "roofs"), ("Border/Works", "gable", "roofs"),
    # fences, props, containers, nature
    ("MapKit", "fence", "fences"), ("Border/Works", "fenceRun", "fences"), ("Maps/Kit", "place", "kit props"), ("Kit", "place", "kit props"),
    ("World", "addContainerSpot", "containers"), ("World", "container", "containers"), ("World", "cont", "containers"),
    ("World", "addExtract", "extracts"), ("World", "extract", "extracts"), ("MapKit", "nat", "nature"),
    ("MapKit", "lampHang", "lamps"), ("MapKit", "desk", "furniture"), ("MapKit", "bunk", "furniture"), ("MapKit", "bed", "furniture"),
    ("MapKit", "truck", "vehicles"), ("World", "mesh", "meshes"),
]


GROUP_CATS = {"stairs": "stairs", "railings": "rails", "walls": "walls", "floors": "slabs", "roofs": "roofs", "lamps": "lamps",
              "fences": "fences", "forest": "nature", "roads": "roads", "rails": "railway", "power": "power lines",
              "machines": "kit props", "furniture": "furniture", "loot": "containers", "boundary": "boundary", "bridges": "bridges"}


def category(frames, path):
    """The pilot's categories (stairs, rails) and the big other families, from the builder call stack."""
    for mod, fn, _ld, _cl in frames:  # the kit's own placements first (their pieces are made by Kit.place)
        if mod == "MapKit" and fn in ("k5Flight", "k5Rail", "k5Fence"):
            return {"k5Flight": "stairs", "k5Rail": "rails", "k5Fence": "fences"}[fn]
    for mod, fn, _ld, _cl in frames:
        for rm, rf, cat in RULES:
            if rf == "?":
                continue
            if (mod == rm or mod.endswith("/" + rm)) and fn == rf:
                return cat
    for mod, fn, _ld, _cl in frames:
        if mod.endswith("Meridian/MallLinks"):
            return "stairs"
        if mod == "Kit":
            return "kit props"
    for p in path:
        c = GROUP_CATS.get(p.lower())
        if c:
            return c
    return None


PLAIN = {"B", "ab", "bc", "box", "boxCF", "part", "cyl", "vcyl", "VC", "beam", "?", "colm", "P", "block", "plain", "mk", "add",
         "try", "run", "step", "pcall", "bit", "fb", "tb", "blk", "x"}


def helper(frames):
    """The innermost builder function that is not a plain box maker (module:function), else the innermost map line."""
    for mod, fn, ld, _cl in frames:
        if fn not in PLAIN and mod != "World":
            return "%s:%s" % (mod, fn)
        if fn not in PLAIN and mod == "World" and fn not in ("box", "boxCF", "part", "cyl", "vcyl"):
            return "%s:%s" % (mod, fn)
    lines = ["%s@%d" % (mod, cl) for mod, fn, ld, cl in frames if mod != "World"][:2]
    return " < ".join(lines) if lines else "(none)"


def report(paths, top=25):
    for p in paths:
        rec = json.load(open(p))
        parts = rec["parts"]
        n = len(parts)
        print("\n=== %s%s: %d parts (offline, %.1f s) ===" % (rec["map"], " with ZR_Kit5" if rec.get("kit5") else "", n, rec["seconds"]))
        groups = Counter(x["path"][0] if x["path"] else "(top)" for x in parts)
        print("by group: " + ", ".join("%s %d" % kv for kv in groups.most_common(14)))
        cats = Counter()
        helpers = Counter()
        for x in parts:
            c = category(x["frames"], x["path"])
            cats[c or "other"] += 1
            helpers[helper(x["frames"])] += 1
        print("by category: " + ", ".join("%s %d" % kv for kv in cats.most_common()))
        print("by builder function (top %d):" % top)
        for h, k in helpers.most_common(top):
            print("   %6d  %s" % (k, h))


def compare(before, after):
    """parts by category and by group, before and after (two runs of one map)"""
    a, b = json.load(open(before)), json.load(open(after))
    ca, cb = census_counts(a), census_counts(b)
    print("\n=== %s: %d -> %d parts (%+d, %.1f%%) ===" % (a["map"], len(a["parts"]), len(b["parts"]), len(b["parts"]) - len(a["parts"]),
                                                    100.0 * (len(b["parts"]) - len(a["parts"])) / max(1, len(a["parts"]))))
    keys = sorted(set(ca) | set(cb), key=lambda k: -ca.get(k, 0))
    for k in keys:
        if ca.get(k, 0) != cb.get(k, 0):
            print("   %-12s %6d -> %6d (%+d)" % (k, ca.get(k, 0), cb.get(k, 0), cb.get(k, 0) - ca.get(k, 0)))
    ga = Counter(x["path"][0] if x["path"] else "(top)" for x in a["parts"])
    gb = Counter(x["path"][0] if x["path"] else "(top)" for x in b["parts"])
    print("   groups: " + ", ".join("%s %d -> %d" % (g, ga[g], gb[g]) for g in sorted(set(ga) | set(gb), key=lambda g: -ga[g]) if ga[g] != gb[g]))
    log = b.get("kitlog") or []
    used = Counter((e["kind"], e.get("style", ""), bool(e.get("kit"))) for e in log)
    print("   kit calls: " + ", ".join("%s%s %s %d" % (k[0], ":" + k[1] if k[1] else "", "kit" if k[2] else "fallback", n) for k, n in sorted(used.items())))
    return ca, cb


def pilot(rec):
    """the pilot's two categories in a record: stair and railing parts, whatever built them"""
    c = census_counts(rec)
    # with the kit, the flights and rails are kit props placed by MapKit's k5Flight / k5Rail: count them by their call
    stairs, rails = c.get("stairs", 0), c.get("rails", 0)
    for x in rec["parts"]:
        mods = [f[1] for f in x["frames"]]
        if "k5Flight" in mods and category(x["frames"], x["path"]) != "stairs":
            stairs += 1
        elif "k5Rail" in mods and category(x["frames"], x["path"]) != "rails":
            rails += 1
    return stairs, rails


def census_counts(rec):
    cats = Counter()
    for x in rec["parts"]:
        cats[category(x["frames"], x["path"]) or "other"] += 1
    return cats


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    cmd = argv[0]
    merge = None
    for a in argv:
        if a == "--merge" or a.startswith("--merge="):
            merge = float(a.split("=", 1)[1]) if "=" in a else 1.0
    if cmd == "run" and len(argv) >= 3:
        run(argv[1], argv[2], kit5="--kit5" in argv, merge=merge)
        return 0
    if cmd == "tests":
        r = tests("--kit5" in argv, merge)
        return 0 if " 0 failed" in r else 1
    if cmd == "merge":
        merge_report(float(argv[1]) if len(argv) > 1 else 1.0)
        return 0
    if cmd == "mergecost" and len(argv) == 3:
        mergecost(argv[1], argv[2])
        return 0
    if cmd == "compare" and len(argv) == 3:
        compare(argv[1], argv[2])
        return 0
    if cmd == "report" and len(argv) >= 2:
        report(argv[1:])
        return 0
    if cmd == "all":
        out = argv[1] if len(argv) > 1 and not argv[1].startswith("--") else tempfile.mkdtemp(prefix="kit_census_")
        os.makedirs(out, exist_ok=True)
        files = []
        for name in MAPS:
            for k5 in (False, True):
                p = os.path.join(out, "%s%s.json" % (name, "_kit5" if k5 else ""))
                run(name, p, kit5=k5)
                files.append(p)
        report(files)
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
