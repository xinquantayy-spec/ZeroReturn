"""Offline previews of SMELTER on Escape from Tarkov's Factory layout (art-1a).

  run  <record.json>          build src/server/Maps/Smelter.luau and its SmelterParts under Lua 5.4 (lupa) with a stub
                              kit that records every part, container, extract, loose spot, door, light, spawn and AI
                              table; writes the record as JSON
  draw <record.json> [out]    draw the record per floor over the reference outlines and run MapTests-like checks with
                              axis-aligned boxes (default out: docs/maps/reference/smelter_build_preview.png); exits 1
                              when a check fails
  paths <record.json> [out]   walk the build offline (voxels at 0.5 studs, two agents): every spawn reaches every exit it
                              lists, the scav exits and the transit, every floor of the office and every AI point (strict
                              agent, radius 1.5), every task place, loot box and loose spot (soft agent, radius 1); exits 1
                              when anything is cut off; out: a picture of the pieces per storey
  all  [out]                  run + draw + paths (needs lupa, numpy, scipy and matplotlib in the same Python)
  ref  [out]                  the reference alone, from factory_layout.json (default
                              docs/maps/reference/factory_layout_preview.png)

NOT Roblox and NOT Studio: no physics, no raycasts, no lighting, no streaming, no frame rate. The Luau -> Lua
conversion only handles what the Smelter modules use (type annotations, casts, compound assignment, generalized
for-in on one line). Run from anywhere with `python3 -I tools/smelter_preview.py ...`; `run` needs a Python with
lupa (pip install lupa in a venv), `draw` and `ref` need numpy and matplotlib, `paths` numpy and scipy.
"""
import json, math, os, re, sys, tempfile

# ---- Luau -> Lua 5.4 (enough for the Smelter modules) ----
def mask(src):
    """Same-length copy: string contents -> \x02, comments -> \x01 (newlines kept)."""
    out, i, n = [], 0, len(src)
    while i < n:
        if src.startswith('--', i):
            m = re.match(r'--\[(=*)\[', src[i:])
            if m:
                close = ']' + m.group(1) + ']'
                j = src.find(close, i); j = n if j < 0 else j + len(close)
            else:
                j = src.find('\n', i); j = n if j < 0 else j
            out.append(''.join('\n' if ch == '\n' else '\x01' for ch in src[i:j])); i = j; continue
        m = re.match(r'\[(=*)\[', src[i:])
        if m:
            close = ']' + m.group(1) + ']'
            j = src.find(close, i); j = n if j < 0 else j + len(close)
            out.append(src[i:i + len(m.group(0))] + ''.join('\n' if ch == '\n' else '\x02' for ch in src[i + len(m.group(0)):j - len(close)]) + close); i = j; continue
        c = src[i]
        if c in '"\'':
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == '\\' else 1
            out.append(c + '\x02' * (j - i - 1) + c); i = j + 1; continue
        out.append(c); i += 1
    return ''.join(out)

OPEN, CLOSE = '([{<', ')]}>'

def skip_ws(m, i):
    while i < len(m) and m[i] in ' \t':
        i += 1
    return i

def type_end(m, i):
    """End index of a type expression starting at i (masked text)."""
    i = skip_ws(m, i)
    while True:
        if i < len(m) and m[i] in '({':
            depth, j = 0, i
            while j < len(m):
                if m[j] in '({[':
                    depth += 1
                elif m[j] in ')}]':
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            i = j + 1
        else:
            mm = re.match(r'(typeof\s*\([^)]*\)|[A-Za-z_][\w.]*)', m[i:])
            if not mm:
                return i
            i += mm.end()
            if i < len(m) and m[i] == '<':  # generic arguments
                depth, j = 0, i
                while j < len(m):
                    if m[j] == '<':
                        depth += 1
                    elif m[j] == '>':
                        depth -= 1
                        if depth == 0:
                            break
                    j += 1
                i = j + 1
        k = skip_ws(m, i)
        if k < len(m) and m[k] == '?':
            i = k + 1; k = skip_ws(m, i)
        if m.startswith('->', k):
            i = skip_ws(m, k + 2); continue
        if k < len(m) and m[k] in '|&':
            i = skip_ws(m, k + 1); continue
        return i

def conv(src):
    m = mask(src)
    cut = []  # (start, end) ranges to delete
    # type declarations
    for t in re.finditer(r'(?m)^(\s*)(export\s+)?type\s+\w+(<[^>]*>)?\s*=', m):
        e = type_end(m, t.end())
        cut.append((t.start(), e))
    # casts
    for t in re.finditer(r'::', m):
        cut.append((t.start(), type_end(m, t.end())))
    # function parameter lists and return types
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
        # params: strip ': type' at depth 1
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
    # local declarations: local a: T, b: U = ...
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
    # apply cuts (merged, from the end)
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
    # line passes: compound assignment and for-in
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
        else:
            f = re.search(r'\bfor\s+[\w\s,]+\s+in\s+(.+?)\s+do\b', code_m)
            if f:
                a, b = f.span(1)
                code_o = code_o[:a] + '__iter(' + code_o[a:b] + ')' + code_o[b:]
        out.append(code_o + ('' if cpos < 0 else o[cpos:]))
    src = '\n'.join(out)
    # requires: script.Parent.X / Shared.X / Services.X / script.Parent.Parent.Tests.X -> REQ("X")
    src = re.sub(r'require\(\s*(?:script\.Parent|Shared|Services)\.(\w+)\s*\)', r'REQ("\1")', src)
    src = re.sub(r'require\(\s*script\.Parent\.Parent:WaitForChild\("Services"\)\.(\w+)\s*\)', r'REQ("\1")', src)
    return src


# ---- the stub kit and Roblox stand-ins (Lua) ----
MAPMOCK = r"""-- Offline stand-ins for running the Smelter map builder under Lua 5.4 (NOT Roblox, NOT Studio). A stub `kit` records
-- every part the builder makes (size, frame, material, flags), every container, extract, loose spot, door and light.
unpack = table.unpack
function __iter(a, b, c)
  if type(a) == "function" then return a, b, c end
  if type(a) ~= "table" then error("attempt to iterate over a " .. type(a) .. " value", 2) end
  local n = rawlen(a)
  local i, stage, k = 0, 1, nil
  return function()
    if stage == 1 then
      i = i + 1
      if i <= n then return i, a[i] end
      stage = 2
    end
    while true do
      local v
      k, v = next(a, k)
      if k == nil then return nil end
      if not (math.type(k) == "integer" and k >= 1 and k <= n) then return k, v end
    end
  end
end
function table.find(t, v, init) for i = init or 1, #t do if t[i] == v then return i end end return nil end
function table.clear(t) for k in pairs(t) do t[k] = nil end end
function table.clone(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
function math.clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end
function math.sign(x) if x > 0 then return 1 elseif x < 0 then return -1 end return 0 end
function math.round(x) if x >= 0 then return math.floor(x + 0.5) end return -math.floor(-x + 0.5) end
WARNS = {}
warn = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end WARNS[#WARNS + 1] = table.concat(t, " ") print("WARN", ...) end
function assert(v, msg) if not v then error(msg or "assertion failed", 2) end return v end

-- ── Vector3 ──────────────────────────────────────────────────────────────────────────────────────────────
local V3 = {}
V3.__index = function(v, k)
  if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
  if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) return Vector3.new(v.X / m, v.Y / m, v.Z / m) end
  if k == "Lerp" then return function(a, b, t) return Vector3.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end end
  if k == "Abs" then return function(a) return Vector3.new(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end end
  if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
  return nil
end
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
  if type(a) == "number" then return Vector3.new(a * b.X, a * b.Y, a * b.Z) end
  if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
  return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, isV3 = true }, V3) end }
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

-- ── CFrame: position p and rotation rows r (3x3, columns = right, up, back) ─────────────────────────────────
local CF = {}
local function mkcf(p, r) return setmetatable({ p = p, r = r, isCF = true }, CF) end
local function mul33(a, b)
  local o = {}
  for i = 1, 3 do o[i] = {} for j = 1, 3 do o[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j] end end
  return o
end
local function apply(r, v) return Vector3.new(r[1][1] * v.X + r[1][2] * v.Y + r[1][3] * v.Z, r[2][1] * v.X + r[2][2] * v.Y + r[2][3] * v.Z, r[3][1] * v.X + r[3][2] * v.Y + r[3][3] * v.Z) end
local I3 = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
CF.__index = function(c, k)
  if k == "Position" then return c.p end
  if k == "X" then return c.p.X end
  if k == "Y" then return c.p.Y end
  if k == "Z" then return c.p.Z end
  if k == "RightVector" then return Vector3.new(c.r[1][1], c.r[2][1], c.r[3][1]) end
  if k == "UpVector" then return Vector3.new(c.r[1][2], c.r[2][2], c.r[3][2]) end
  if k == "LookVector" then return Vector3.new(-c.r[1][3], -c.r[2][3], -c.r[3][3]) end
  if k == "PointToWorldSpace" then return function(self, v) return self.p + apply(self.r, v) end end
  if k == "PointToObjectSpace" then return function(self, v) local d = v - self.p local r = self.r return Vector3.new(r[1][1] * d.X + r[2][1] * d.Y + r[3][1] * d.Z, r[1][2] * d.X + r[2][2] * d.Y + r[3][2] * d.Z, r[1][3] * d.X + r[2][3] * d.Y + r[3][3] * d.Z) end end
  return nil
end
CF.__mul = function(a, b)
  if type(b) == "table" and b.isCF then return mkcf(a.p + apply(a.r, b.p), mul33(a.r, b.r)) end
  if type(b) == "table" and b.isV3 then return a.p + apply(a.r, b) end
  error("bad CFrame multiply")
end
CF.__add = function(a, v) return mkcf(a.p + v, a.r) end
CF.__sub = function(a, v) return mkcf(a.p - v, a.r) end
CFrame = {}
CFrame.new = function(x, y, z)
  if type(x) == "table" and x.isV3 then return mkcf(x, I3) end
  return mkcf(Vector3.new(x or 0, y or 0, z or 0), I3)
end
CFrame.Angles = function(rx, ry, rz)
  local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
  local Rx = { { 1, 0, 0 }, { 0, cx, -sx }, { 0, sx, cx } }
  local Ry = { { cy, 0, sy }, { 0, 1, 0 }, { -sy, 0, cy } }
  local Rz = { { cz, -sz, 0 }, { sz, cz, 0 }, { 0, 0, 1 } }
  return mkcf(Vector3.zero, mul33(mul33(Rx, Ry), Rz))
end
CFrame.lookAt = function(at, target, up)
  local f = (target - at)
  local m = f.Magnitude
  if m < 1e-9 then return mkcf(at, I3) end
  f = f / m
  up = up or Vector3.yAxis
  local rx = Vector3.new(f.Y * up.Z - f.Z * up.Y, f.Z * up.X - f.X * up.Z, f.X * up.Y - f.Y * up.X)
  if rx.Magnitude < 1e-6 then rx = Vector3.xAxis else rx = rx.Unit end
  local ry = Vector3.new(rx.Y * f.Z - rx.Z * f.Y, rx.Z * f.X - rx.X * f.Z, rx.X * f.Y - rx.Y * f.X)
  local bz = -f
  return mkcf(at, { { rx.X, ry.X, bz.X }, { rx.Y, ry.Y, bz.Y }, { rx.Z, ry.Z, bz.Z } })
end

-- ── misc Roblox stand-ins ────────────────────────────────────────────────────────────────────────────────
Random = { new = function(seed)
  local s = (seed or 1) % 2147483647
  if s <= 0 then s = s + 2147483646 end
  local o = {}
  local function nx() s = (s * 48271) % 2147483647 return s / 2147483647 end
  function o:NextNumber(a, b) a = a or 0 b = b or 1 return a + (b - a) * nx() end
  function o:NextInteger(a, b) return a + math.floor(nx() * (b - a + 1)) end
  return o
end }
local function enumOf(name) return setmetatable({}, { __index = function(_, k) return name .. "." .. k end }) end
Enum = { Material = enumOf("Material"), PartType = enumOf("PartType"), NormalId = enumOf("NormalId"), SurfaceType = enumOf("SurfaceType") }
Color3 = { fromHex = function(h) return "#" .. h end, fromRGB = function(r, g, b) return string.format("rgb(%d,%d,%d)", r, g, b) end }

-- ── the recorder ─────────────────────────────────────────────────────────────────────────────────────────
REC = { parts = {}, containers = {}, extracts = {}, loose = {}, lights = 0, props = {} }
local PartMT = {}
PartMT.__index = function(p, k)
  if k == "SetAttribute" then return function(self, a, v) self.attrs[a] = v end end
  if k == "GetAttribute" then return function(self, a) return self.attrs[a] end end
  if k == "Position" then return rawget(p, "CFrame").p end
  return nil
end
local ModelMT = {}
local function descendants(m, out)
  for _, c in ipairs(m.children) do
    out[#out + 1] = c
    if c.children then descendants(c, out) end
  end
  return out
end
ModelMT.__index = function(m, k)
  if k == "GetDescendants" then return function(self) return descendants(self, {}) end end
  if k == "SetAttribute" then return function(self, a, v) end end
  if k == "FindFirstChild" then return function(self, n) for _, c in ipairs(self.children) do if c.Name == n then return c end end return nil end end
  return nil
end
local function newModel(name, parent)
  local m = setmetatable({ Name = name, children = {}, isModel = true, model = name }, ModelMT)
  if parent then table.insert(parent.children, m) end
  return m
end
local function newPart(parent, size, cf, color, mat, shape, tag)
  local p = setmetatable({ Size = size, CFrame = cf, Color = color, Material = mat, Shape = shape or "Block", Name = "Part", attrs = {}, CanCollide = true,
    CanQuery = true, Transparency = 0, CastShadow = true, parentName = parent and parent.Name or "?", tag = tag }, PartMT)
  REC.parts[#REC.parts + 1] = p
  if parent then table.insert(parent.children, p) end
  return p
end
local C = {
  concrete = "#6F716C", concreteDark = "#575A56", concreteLight = "#8C8D86", asphalt = "#3D403F", line = "#A99A62", rust = "#8A6252", rustDark = "#5E4236",
  metal = "#5C6461", metalDark = "#33383B", olive = "#5E6448", sand = "#B1A893", mist = "#96A4A2", orange = "#C07946", yellow = "#C29A38",
  pale = "#D6DBC9", wood = "#6E5A44", blue = "#3E5868", red = "#7A3E33", teal = "#3D5A57", wall = "#666A63", interior = "#7D7F76", floor = "#4C4F4B",
}
WORLD = { doors = {}, switches = {}, extracts = {}, spawns = {}, visitZones = {}, natureRegions = {}, containers = {} }
ROOT = newModel("ZR_World", nil)
local kit = {}
kit.World = WORLD
kit.root = ROOT
kit.C = C
kit.M = Enum.Material
kit.hex = function(h) return "#" .. h end
kit.rng = Random.new(7)
kit.part = function(parent, size, cf, color, mat, class) return newPart(parent, size, cf, color, mat, class == "WedgePart" and "Wedge" or "Block") end
kit.box = function(parent, sx, sy, sz, x, y, z, color, mat, ry)
  local cf = CFrame.new(x, y, z)
  if ry then cf = cf * CFrame.Angles(0, math.rad(ry), 0) end
  return newPart(parent, Vector3.new(sx, sy, sz), cf, color, mat)
end
kit.boxCF = function(parent, sx, sy, sz, cf, color, mat) return newPart(parent, Vector3.new(sx, sy, sz), cf, color, mat) end
kit.cyl = function(parent, length, diameter, cf, color, mat) return newPart(parent, Vector3.new(length, diameter, diameter), cf, color, mat, "Cylinder") end
kit.vcyl = function(parent, h, d, x, y, z, color, mat) return kit.cyl(parent, h, d, CFrame.new(x, y + h / 2, z) * CFrame.Angles(0, 0, math.rad(90)), color, mat) end
kit.model = newModel
kit.jitter = function(c) return c end
kit.light = function(parent) REC.lights = REC.lights + 1 return {} end
kit.sign = function() return {} end
kit.mesh = function() return nil end
-- the real container spot's box by kind (World.addContainerSpot): front faces local -Z
kit.container = function(parent0, id, kind, label, cf)
  local m = newModel("Box_" .. id, parent0)
  local size, oy = Vector3.new(4, 4, 4), 2
  if kind == "locker" then size, oy = Vector3.new(3, 7, 2.2), 3.5
  elseif kind == "drawer" then size, oy = Vector3.new(5, 3, 2.6), 1.5
  elseif kind == "safe" then size, oy = Vector3.new(3, 3.2, 2.6), 1.6 end
  local p = newPart(m, size, cf * CFrame.new(0, oy, 0), "#806040", "Material.WoodPlanks", "Block", "loot")
  p.Name = "Loot_" .. id
  REC.containers[#REC.containers + 1] = { id = id, kind = kind, label = label, cf = cf, part = p }
  WORLD.containers[#WORLD.containers + 1] = { id = id, kind = kind }
end
kit.extract = function(parent, id, name, pos, size, rule, opts)
  REC.extracts[#REC.extracts + 1] = { id = id, name = name, pos = pos, size = size, rule = rule }
  WORLD.extracts[id] = { id = id, name = name, pos = pos, size = size, rule = rule }
end
kit.loose = function(x, y, z, tbl, chance, area, snap)
  REC.loose[#REC.loose + 1] = { pos = Vector3.new(x, y, z), tbl = tbl, chance = chance, snap = snap }
end
kit.stationary = function() return nil end
KIT = kit

-- the Blender prop kit: a box of the prop's KitMeta size (scaled) at its frame, tagged with its name
KITSIZES = KITSIZES or {}
KitStub = { GROUND = {} }
function KitStub.place(parent, name, cf, opts)
  local m = KITSIZES[name]
  if not m then return nil end
  local sc = (opts and opts.scale) or 1
  local p = newPart(parent, Vector3.new(m[1] * sc, m[2] * sc, m[3] * sc), cf * CFrame.new(m[4] * sc, m[5] * sc, m[6] * sc), "#7a7a7a", "Material.Metal", "Block", "prop:" .. name)
  REC.props[#REC.props + 1] = { name = name, part = p }
  return newModel("Kit_" .. name, parent)
end

-- module references (script, game) for the builder's requires
local Ref = {}
Ref.__index = function(r, k)
  if k == "FindFirstChild" or k == "WaitForChild" then return function(self, n) return setmetatable({ __module = n, path = self.path .. "." .. n }, Ref) end end
  if k == "Parent" then return setmetatable({ __module = nil, path = r.path .. ".Parent" }, Ref) end
  return setmetatable({ __module = k, path = r.path .. "." .. k }, Ref)
end
script = setmetatable({ __module = "Smelter", path = "script" }, Ref)
game = { GetService = function(self, n) return setmetatable({ __module = n, path = n }, Ref) end }
function require(ref)
  if type(ref) == "table" and ref.__module then return REQ(ref.__module) end
  error("require of a non-module " .. tostring(ref))
end
"""


# ---- run: the offline build ----
def run(root, outp):
    """Build the map offline with the stub kit and write the record JSON."""
    from lupa.lua54 import LuaRuntime
    MAPS = root + '/src/server/Maps/'
    PATHS = {'Smelter': MAPS + 'Smelter.luau', 'MapKit': MAPS + 'MapKit.luau'}
    for f in os.listdir(MAPS + 'SmelterParts'):
        if f.endswith('.luau'):
            PATHS[f[:-5]] = MAPS + 'SmelterParts/' + f
    # KitMeta sizes: name -> size x, y, z and centre x, y, z
    km = open(root + '/src/shared/KitMeta.luau').read()
    sizes = {}
    for m in re.finditer(r'^\s*(\w+)\s*=\s*\{ batch = "[^"]+", size = V\(([^)]*)\), center = V\(([^)]*)\)', km, re.M):
        s = [float(v) for v in m.group(2).split(',')]
        c = [float(v) for v in m.group(3).split(',')]
        sizes[m.group(1)] = s + c

    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(MAPMOCK)
    ks = lua.eval('KITSIZES')
    for k, v in sizes.items():
        ks[k] = lua.table(*v)
    STUBS = {
        'Kit': 'return KitStub',
        'AssetMeta': 'return {}',
        'Wear': 'return { DEC = {} }',
        # the two Smelter items main has (the crawl exit and the store's card lock get built)
        'Items': 'return { defs = { NOTE_SMELT_CRAWL = { kind = "key" }, KEY_SMELT_STORE = { kind = "key" } } }',
        # no Kit5 batch offline: MapKit's H.k5Flight / H.k5Rail fall back to the part-built steps and rails
        'KitMeta': 'return { props = {} }',
    }
    cache = {}


    def load(name):
        if name in cache:
            return cache[name]
        if name in STUBS:
            cache[name] = lua.execute(STUBS[name])
            return cache[name]
        path = PATHS.get(name)
        if not path:
            raise RuntimeError('no module ' + name)
        src = conv(open(path).read())
        fn = lua.execute('return function(src, name) local f, err = load(src, "=" .. name) if not f then error(err) end return f end')(src, name)
        cache[name] = fn()
        return cache[name]


    lua.globals().PYLOAD = load
    lua.execute('function REQ(name) return PYLOAD(name) end')
    out = lua.execute('''
    local build = REQ("Smelter")
    local map = build(KIT, ROOT)
    return map
    ''')
    G = lua.globals()
    REC, W = G.REC, G.WORLD


    def v3(v):
        return [v.X, v.Y, v.Z]


    def cf(c):
        r = c.r
        return {'p': v3(c.p), 'r': [[r[i][j] for j in (1, 2, 3)] for i in (1, 2, 3)]}


    parts = []
    for i in range(1, len(REC.parts) + 1):
        p = REC.parts[i]
        parts.append({'size': v3(p.Size), 'cf': cf(p.CFrame), 'mat': str(p.Material), 'shape': str(p.Shape), 'name': str(p.Name),
                      'parent': str(p.parentName), 'collide': bool(p.CanCollide), 'transp': float(p.Transparency), 'tag': str(p.tag) if p.tag else None,
                      'nodetail': bool(p.attrs['NoDetail']) if p.attrs['NoDetail'] is not None else False})
    rec = {'parts': parts, 'lights': REC.lights,
           'containers': [{'id': c.id, 'kind': c.kind, 'label': c.label, 'cf': cf(c.cf)} for c in REC.containers.values()],
           'extracts': [{'id': e.id, 'name': e.name, 'pos': v3(e.pos), 'size': v3(e.size), 'rule': dict(e.rule)} for e in REC.extracts.values()],
           'loose': [{'pos': v3(l.pos), 'tbl': l.tbl, 'chance': l.chance} for l in REC.loose.values()],
           'props': [p.name for p in REC.props.values()],
           'spawns': [{'id': s.id, 'name': s.name, 'cf': cf(s.cf), 'side': s.side, 'extracts': list(s.extracts.values())} for s in W.spawns.values()],
           'sideExtracts': {k: list(v.values()) for k, v in W.sideExtracts.items()},
           'patrols': {k: [v3(p) for p in v.values()] for k, v in W.patrols.items()},
           'watchPosts': [{'route': w.route, 'post': v3(w.post) if w.post else None, 'label': w.label, 'kind': w.kind} for w in W.watchPosts.values()],
           'scavZones': [v3(p) for p in W.scavZones.values()],
           'visitZones': {k: {'pos': v3(z.pos), 'r': z.r, 'free': z.free} for k, z in W.visitZones.items()},
           'doors': {k: {'cf': cf(d.cf), 'size': v3(d.size), 'key': d.key, 'label': d.label} for k, d in W.doors.items()},
           'transits': [{'id': t.id, 'name': t.name, 'to': t.to, 'pos': v3(t.pos), 'size': v3(t.size)} for t in (W.transits.values() if W.transits else [])],
           'bosses': [{'name': b.name, 'label': b.label, 'chance': b.chance, 'night': b.night, 'hp': b.hp, 'charge': b.charge, 'route': len(b.route) if b.route else 0,
                       'zones': [{'name': z.name, 'home': v3(z.home), 'crew': [v3(c.pos) for c in z.crew.values()] if z.crew else []} for z in b.zones.values()]} for b in W.bosses.values()],
           'bounds': dict(W.bounds), 'warns': list(G.WARNS.values()), 'descendants': len(out.GetDescendants(out))}
    json.dump(rec, open(outp, 'w'))
    from collections import Counter
    print('parts', len(parts), 'lights', REC.lights, 'containers', len(rec['containers']), 'extracts', len(rec['extracts']), 'loose', len(rec['loose']),
          'props', len(rec['props']), 'spawns', len(rec['spawns']), 'doors', len(rec['doors']), 'descendants', rec['descendants'])
    print('by parent', Counter(p['parent'] for p in parts).most_common(30))
    print('warns', rec['warns'][:20])


# ---- draw: the build over the reference, with checks ----
def draw(recp, refp, out):
    """Draw the record over the reference and run the checks; returns the problems found."""
    import numpy as np
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.patches import Rectangle
    rec = json.load(open(recp)); ref = json.load(open(refp))
    S, OX = 3.125, 1600.0
    LEVELS = {'basement': -8.44, 'sump': -12.38, 'hall': 0.0, 'west': 3.06, 'gallery': 8.22, 'second': 13.97, 'third': 25.41}
    FLOORS = sorted(LEVELS.values())


    def aabb(p):
        sx, sy, sz = p['size']
        r = p['cf']['r']
        c = p['cf']['p']
        h = [sum(abs(r[i][j]) * [sx, sy, sz][j] / 2 for j in range(3)) for i in range(3)]
        return (c[0] - OX - h[0], c[0] - OX + h[0], c[1] - h[1], c[1] + h[1], c[2] - h[2], c[2] + h[2])


    boxes = []
    for p in rec['parts']:
        b = aabb(p)
        area = (b[1] - b[0]) * (b[5] - b[4])
        top = b[3]
        floorish = (b[3] - b[2] <= 9) and area > 6 and any(abs(top - f) < 0.75 for f in FLOORS) and p['parent'] in ('Floors', 'Stairs', 'Roofs', 'Crucibles', 'Siding', 'TaskFurniture') and p['shape'] == 'Block'
        if p['name'] == 'Roof':
            floorish = False
        boxes.append({'b': b, 'p': p, 'floor': floorish})
    B = np.array([x['b'] for x in boxes])
    collide = np.array([x['p']['collide'] and x['p']['transp'] < 1 for x in boxes])
    isfloor = np.array([x['floor'] for x in boxes])
    parent = [x['p']['parent'] for x in boxes]


    def floor_below(x, z, y, maxd):
        """The highest floor-ish or solid top under (x, z) between y - maxd and y + 0.05."""
        m = (B[:, 0] <= x) & (B[:, 1] >= x) & (B[:, 4] <= z) & (B[:, 5] >= z) & (B[:, 3] <= y + 0.05) & (B[:, 3] >= y - maxd) & collide
        if not m.any():
            return None
        return float(B[m, 3].max())


    def rotated(i):
        r = boxes[i]['p']['cf']['r']
        return not all(abs(abs(r[a][b]) - (1 if a == b else 0)) < 1e-3 or abs(abs(r[a][b]) - 1) < 1e-3 or abs(r[a][b]) < 1e-3 for a in range(3) for b in range(3))


    def obb_hits(i, x0, x1, y0, y1, z0, z1):
        """Does the probe box meet part i's oriented box? (samples of the probe in the part's frame)"""
        p = boxes[i]['p']
        r = p['cf']['r']; c = p['cf']['p']; hs = [v / 2 for v in p['size']]
        for fx in (0, 0.25, 0.5, 0.75, 1):
            for fy in (0, 0.5, 1):
                for fz in (0, 0.25, 0.5, 0.75, 1):
                    q = [x0 + (x1 - x0) * fx + OX - c[0], y0 + (y1 - y0) * fy - c[1], z0 + (z1 - z0) * fz - c[2]]
                    loc = [r[0][k] * q[0] + r[1][k] * q[1] + r[2][k] * q[2] for k in range(3)]
                    if all(abs(loc[k]) <= hs[k] for k in range(3)):
                        return True
        return False


    def solids_in(x0, x1, y0, y1, z0, z1, exclude_floor=True, groups=None):
        m = (B[:, 0] < x1) & (B[:, 1] > x0) & (B[:, 2] < y1) & (B[:, 3] > y0) & (B[:, 4] < z1) & (B[:, 5] > z0) & collide
        idx = [i for i in np.nonzero(m)[0] if not rotated(i) or obb_hits(i, x0, x1, y0, y1, z0, z1)]
        if groups:
            idx = [i for i in idx if parent[i] in groups]
        return list(idx)


    problems = []
    # M02-like: spawns on a floor with head room
    for s in rec['spawns']:
        x, y, z = s['cf']['p'][0] - OX, s['cf']['p'][1], s['cf']['p'][2]
        f = floor_below(x, z, y + 1 - 3.4 + 3.4, 8)
        if f is None:
            problems.append(f"spawn {s['id']} {s['name']}: no floor under ({x:.0f}, {y:.1f}, {z:.0f})")
            continue
        hit = solids_in(x - 1.2, x + 1.2, f + 0.7, f + 5.7, z - 1.2, z + 1.2)
        if hit:
            problems.append(f"spawn {s['id']} {s['name']}: head room blocked by {[parent[i] + ':' + boxes[i]['p']['name'] for i in hit][:3]}")
    # M03-like: extracts over a floor
    for e in rec['extracts']:
        x, y, z = e['pos'][0] - OX, e['pos'][1], e['pos'][2]
        if floor_below(x, z, y + 2, 4) is None:
            problems.append(f"extract {e['id']}: no floor under ({x:.0f}, {y:.1f}, {z:.0f})")
    # M04-like: loose spots on a surface within 0.8 (before the snap)
    nl = 0
    for l in rec['loose']:
        x, y, z = l['pos'][0] - OX, l['pos'][1], l['pos'][2]
        f = floor_below(x, z, y + 0.3, 3.0)
        if f is None or y - f > 0.8:
            nl += 1
            problems.append(f"loose spot ({x:.0f}, {y:.1f}, {z:.0f}): surface {f}")
    # containers: on a floor, not in a wall or another solid (other than its own box)
    for c in rec['containers']:
        x, y, z = c['cf']['p'][0] - OX, c['cf']['p'][1], c['cf']['p'][2]
        f = floor_below(x, z, y + 0.05, 1.0)
        if f is None or abs(f - y) > 0.3:
            problems.append(f"container {c['id']} ({c['label']}): floor {f} under y {y:.2f} at ({x:.0f}, {z:.0f})")
        hit = [i for i in solids_in(x - 1.4, x + 1.4, y + 0.6, y + 2.5, z - 1.4, z + 1.4) if parent[i] in ('Walls', 'Stairs', 'Machines', 'Furniture', 'Railings', 'Crucibles', 'Siding', 'TaskFurniture')]
        if hit:
            problems.append(f"container {c['id']} ({c['label']}) at ({x:.0f}, {y:.1f}, {z:.0f}) meets {[parent[i] + ':' + boxes[i]['p']['name'] for i in hit][:3]}")
    # doors: the leaf sits in a gap (no wall through its middle)
    for k, d in rec['doors'].items():
        x, y, z = d['cf']['p'][0] - OX, d['cf']['p'][1], d['cf']['p'][2]
        hit = [i for i in solids_in(x - 0.3, x + 0.3, y - 0.5, y + 0.5, z - 0.3, z + 0.3) if parent[i] == 'Walls']
        if hit:
            problems.append(f"door {k}: a wall through it at ({x:.0f}, {y:.1f}, {z:.0f})")
        if floor_below(x, z, y - d['size'][1] / 2 + 0.3, 1.5) is None:
            problems.append(f"door {k}: no floor under it")
    # visit zones, scav zones, patrol points, boss homes: on a floor
    for k, v in rec['visitZones'].items():
        x, y, z = v['pos'][0] - OX, v['pos'][1], v['pos'][2]
        if floor_below(x, z, y + 0.1, 4) is None:
            problems.append(f"visit zone {k}: no floor under ({x:.0f}, {y:.1f}, {z:.0f})")
    for i, p in enumerate(rec['scavZones']):
        x, y, z = p[0] - OX, p[1], p[2]
        f = floor_below(x, z, y + 1, 3)
        if f is None:
            problems.append(f"scav zone {i}: no floor at ({x:.0f}, {y:.1f}, {z:.0f})")
        elif solids_in(x - 1, x + 1, f + 0.7, f + 5, z - 1, z + 1):
            problems.append(f"scav zone {i}: blocked at ({x:.0f}, {y:.1f}, {z:.0f})")
    for rid, pts in rec['patrols'].items():
        for p in pts:
            x, y, z = p[0] - OX, p[1], p[2]
            f = floor_below(x, z, y + 1, 3)
            if f is None or solids_in(x - 1, x + 1, f + 0.7, f + 5, z - 1, z + 1):
                problems.append(f"route {rid} point ({x:.0f}, {y:.1f}, {z:.0f}): no floor or blocked")
    for b in rec['bosses']:
        for zn in b['zones']:
            for p in [zn['home']] + zn['crew']:
                x, y, z = p[0] - OX, p[1], p[2]
                f = floor_below(x, z, y + 1, 3)
                if f is None or solids_in(x - 1, x + 1, f + 0.7, f + 5, z - 1, z + 1):
                    problems.append(f"{b['label']} zone {zn['name']} point ({x:.0f}, {y:.1f}, {z:.0f}): no floor or blocked")
    for t in rec['transits']:
        x, y, z = t['pos'][0] - OX, t['pos'][1], t['pos'][2]
        if floor_below(x, z, y + 1, 3) is None:
            problems.append(f"transit {t['id']}: no floor")
    # bounds
    bd = rec['bounds']
    for e in rec['extracts']:
        if not (bd['x0'] <= e['pos'][0] <= bd['x1'] and bd['z0'] <= e['pos'][2] <= bd['z1']):
            problems.append(f"extract {e['id']} outside the bounds")

    # ── drawing ──────────────────────────────────────────────────────────────────────────────────────────────
    PANELS = [('TUNNELS (game y -2.6; sump -3.9)', 'basement', -8.44, [-12.38, -8.44]), ('GROUND (hall 0.1; west wing 1.08)', 'ground', 0.0, [0.0, 3.06]),
              ('GALLERY 2.73 + SECOND FLOOR 4.57', 'second', 13.97, [8.22, 13.97]), ('THIRD FLOOR 8.23 + CATWALKS', 'third', 25.41, [25.41])]
    COL = {'Walls': '#141414', 'Stairs': '#d8b000', 'Railings': '#30c030', 'Machines': '#3050a8', 'Furniture': '#5070c0', 'TaskFurniture': '#a050a0',
           'Crucibles': '#203070', 'Siding': '#6a4a30', 'Lamps': None, 'Gates': '#40806a', 'Outside': None, 'Roofs': None, 'Floors': None}
    fig, axs = plt.subplots(2, 2, figsize=(24, 26), dpi=80)
    for ax, (title, lv, y0, fl) in zip(axs.flat, PANELS):
        ax.set_facecolor('#1b2427')
        # floors at this panel's levels
        for i, x in enumerate(boxes):
            b = x['b']
            if x['floor'] and any(abs(b[3] - f) < 0.75 for f in fl) and parent[i] != 'Roofs':
                col = '#7d858c' if parent[i] == 'Floors' else '#b09030'
                if x['p']['name'] == 'Ground':
                    col = '#2f3a2c'
                ax.add_patch(Rectangle((b[0], b[4]), b[1] - b[0], b[5] - b[4], facecolor=col, edgecolor='none', alpha=0.9))
        # solids crossing walking height over this panel's floors
        for i, x in enumerate(boxes):
            b = x['b']
            if x['floor'] or COL.get(parent[i], '#8a5030') is None:
                continue
            if not x['p']['collide'] and parent[i] not in ('Walls',):
                continue
            hit = any(b[2] < f + 4.5 and b[3] > f + 1.0 for f in fl)
            if hit:
                col = COL.get(parent[i], '#c06030')
                if parent[i].startswith('Box_'):
                    col = '#ff8c00'
                if x['p']['mat'].endswith('Glass'):
                    col = '#80c0d0'
                ax.add_patch(Rectangle((b[0], b[4]), b[1] - b[0], b[5] - b[4], facecolor=col, edgecolor='none', alpha=0.95))
        # the reference outline of this level (thin red)
        for r in ref['floors'][lv]:
            xs = [p[0] * S for p in r['pts']] + [r['pts'][0][0] * S]
            zs = [p[1] * S for p in r['pts']] + [r['pts'][0][1] * S]
            ax.plot(xs, zs, color='#ff3030' if r['role'] in ('outer', 'island') else '#ff9040', lw=0.6, alpha=0.7)
        for e in rec['extracts']:
            x, y, z = e['pos'][0] - OX, e['pos'][1], e['pos'][2]
            if any(abs(y - f) < 2 for f in fl):
                sz = e['size']
                pmc = e['rule'].get('kind') != 'scav'
                ax.add_patch(Rectangle((x - sz[0] / 2, z - sz[2] / 2), sz[0], sz[2], facecolor='none', edgecolor='lime' if pmc else 'cyan', lw=2))
                ax.text(x + sz[0] / 2 + 1, z, e['name'], color='lime' if pmc else 'cyan', fontsize=9, weight='bold')
        for t in rec['transits']:
            x, y, z = t['pos'][0] - OX, t['pos'][1], t['pos'][2]
            if any(abs(y - f) < 2 for f in fl):
                ax.add_patch(Rectangle((x - 7, z - 7), 14, 14, facecolor='none', edgecolor='#4aa0ff', lw=2))
                ax.text(x - 30, z - 9, t['name'], color='#4aa0ff', fontsize=8)
        for s in rec['spawns']:
            x, y, z = s['cf']['p'][0] - OX, s['cf']['p'][1] - 3.4, s['cf']['p'][2]
            if any(abs(y - f) < 2 for f in fl):
                r = s['cf']['r']
                lx, lz = -r[0][2], -r[2][2]
                ax.annotate('', xy=(x + lx * 7, z + lz * 7), xytext=(x, z), arrowprops=dict(arrowstyle='->', color='white', lw=1.5))
                ax.plot(x, z, 'o', color='white', ms=5)
        for l in rec['loose']:
            x, y, z = l['pos'][0] - OX, l['pos'][1], l['pos'][2]
            if any(abs(y - f) < 2 for f in fl):
                ax.plot(x, z, '.', color='#ff60ff', ms=4)
        for k, d in rec['doors'].items():
            x, y, z = d['cf']['p'][0] - OX, d['cf']['p'][1], d['cf']['p'][2]
            if any(abs(y - d['size'][1] / 2 - f) < 2 for f in fl):
                ax.plot(x, z, 's', color='#d07030' if d['key'] else '#a08060', ms=8)
        for k, v in rec['visitZones'].items():
            x, y, z = v['pos'][0] - OX, v['pos'][1], v['pos'][2]
            if any(-1 < y - f < 4 for f in fl):
                ax.add_patch(plt.Circle((x, z), v['r'], fill=False, color='#ff4080', lw=1.5))
                ax.text(x + v['r'], z - v['r'], k, color='#ff4080', fontsize=8)
        for b in rec['bosses']:
            for zn in b['zones']:
                x, y, z = zn['home'][0] - OX, zn['home'][1], zn['home'][2]
                if any(abs(y - f) < 2 for f in fl):
                    ax.plot(x, z, '*', color='red' if b['label'] == 'Stoker' else 'purple', ms=12)
        ax.set_xlim(-216, 216); ax.set_ylim(236, -236); ax.set_aspect('equal')
        ax.set_title(title, fontsize=14)
        ax.grid(True, alpha=0.15)
        ax.set_xlabel('x studs (east)'); ax.set_ylabel('z studs (south)')
    fig.suptitle('SMELTER on EFT Factory: what the builder makes (offline stub kit), over the reference outlines (red). '
                 'Grey floors, black walls, yellow stairs, green rails, blue machines, orange loot, white spawns, lime/cyan exits, pink task places, red stars THE STOKER', fontsize=12)
    fig.savefig(out, bbox_inches='tight')
    print(len(problems), 'problems')
    for p in problems:
        print(' ', p)
    return problems


# ---- paths: an offline walk of the build (Studio's exitcheck agent, a little stricter) ----
# Every colliding part is voxelised at 0.5 studs; a cell is standable where its column has a floor under it, the head
# room of the agent over it, and nothing taller than `body` studs over that floor within the agent's radius; standable
# cells join their eight neighbours a stud up or down (steps and stairs), so the storeys join wherever a flight, a ramp
# or a landing really meets them. Two agents walk: STRICT (radius 1.5, 6.5 tall; Roblox's pathfinding agent in
# exitcheck is radius 1, 5.6 tall, and failed on gaps this one also fails on) for the spawns, exits, office floors and
# AI points, SOFT (radius 1, 6 tall) for loot and task places (a player is narrower than the agent).
WALK_RES = 0.5
WALK_BOX = (-224.0, 224.0, -242.0, 242.0, -16.0, 50.0)  # map-local studs: x, z, y ranges
WALK_STEP = 1.0  # studs up or down between neighbouring cells
AGENTS = {"strict": (1.5, 6.5, 1.6), "soft": (1.0, 6.0, 1.0)}  # radius, head room, body from (studs)


def _walk_dims():
    x0, x1, z0, z1, y0, y1 = WALK_BOX
    return int((x1 - x0) / WALK_RES), int((z1 - z0) / WALK_RES), int((y1 - y0) / WALK_RES)


def _span(lo, hi, o, n):
    return max(0, int(math.ceil((lo - o) / WALK_RES - 0.5))), min(n - 1, int(math.floor((hi - o) / WALK_RES - 0.5)))


def voxelise(parts, ox, oz):
    """The colliding parts (thin ones at least a cell thick) as a voxel grid [y, z, x]."""
    import numpy as np
    X0, X1, Z0, Z1, Y0, Y1 = WALK_BOX
    NX, NZ, NY = _walk_dims()
    O = np.zeros((NY, NZ, NX), bool)
    for p in parts:
        if not p['collide']:
            continue
        cx, cy, cz = p['cf']['p']
        cx -= ox
        cz -= oz
        R = p['cf']['r']
        sx, sy, sz = p['size']
        h = [max(sx / 2, 0.26), max(sy / 2, 0.26), max(sz / 2, 0.26)]
        if 'Cylinder' in p['shape'] and abs(R[1][0]) > 0.99:  # an upright cylinder (its axis is the part's x)
            rad = max(sy, sz) / 2
            k0, k1 = _span(cy - h[0], cy + h[0], Y0, NY)
            i0, i1 = _span(cx - rad, cx + rad, X0, NX)
            j0, j1 = _span(cz - rad, cz + rad, Z0, NZ)
            if k0 > k1 or i0 > i1 or j0 > j1:
                continue
            xs = X0 + (np.arange(i0, i1 + 1) + 0.5) * WALK_RES
            zs = Z0 + (np.arange(j0, j1 + 1) + 0.5) * WALK_RES
            O[k0:k1 + 1, j0:j1 + 1, i0:i1 + 1] |= ((xs[None, :] - cx) ** 2 + (zs[:, None] - cz) ** 2 <= rad * rad)[None]
        elif abs(R[1][1]) > 0.999999:  # turned about y only
            rx, rz, bx, bz = R[0][0], R[2][0], R[0][2], R[2][2]
            ex, ez = abs(rx) * h[0] + abs(bx) * h[2], abs(rz) * h[0] + abs(bz) * h[2]
            k0, k1 = _span(cy - h[1], cy + h[1], Y0, NY)
            i0, i1 = _span(cx - ex, cx + ex, X0, NX)
            j0, j1 = _span(cz - ez, cz + ez, Z0, NZ)
            if k0 > k1 or i0 > i1 or j0 > j1:
                continue
            if abs(abs(rx) - 1) < 1e-6 or abs(abs(rz) - 1) < 1e-6:
                O[k0:k1 + 1, j0:j1 + 1, i0:i1 + 1] = True
            else:
                xs = X0 + (np.arange(i0, i1 + 1) + 0.5) * WALK_RES - cx
                zs = Z0 + (np.arange(j0, j1 + 1) + 0.5) * WALK_RES - cz
                u = xs[None, :] * rx + zs[:, None] * rz
                w = xs[None, :] * bx + zs[:, None] * bz
                O[k0:k1 + 1, j0:j1 + 1, i0:i1 + 1] |= ((np.abs(u) <= h[0]) & (np.abs(w) <= h[2]))[None]
        else:  # any other frame: every voxel centre in the bounds tested against the box
            e = [sum(abs(R[i][j]) * h[j] for j in range(3)) for i in range(3)]
            i0, i1 = _span(cx - e[0], cx + e[0], X0, NX)
            k0, k1 = _span(cy - e[1], cy + e[1], Y0, NY)
            j0, j1 = _span(cz - e[2], cz + e[2], Z0, NZ)
            if k0 > k1 or i0 > i1 or j0 > j1:
                continue
            Yg, Zg, Xg = np.meshgrid(Y0 + (np.arange(k0, k1 + 1) + 0.5) * WALK_RES - cy, Z0 + (np.arange(j0, j1 + 1) + 0.5) * WALK_RES - cz,
                                     X0 + (np.arange(i0, i1 + 1) + 0.5) * WALK_RES - cx, indexing='ij')
            m = np.ones(Xg.shape, bool)
            for j in range(3):
                m &= np.abs(Xg * R[0][j] + Yg * R[1][j] + Zg * R[2][j]) <= h[j]
            O[k0:k1 + 1, j0:j1 + 1, i0:i1 + 1] |= m
    return O


def standable(O, radius, clear, body_from):
    """The cells (layer, z, x) an agent stands on: a floor under, `clear` studs of room over, nothing from `body_from`
    studs up within `radius`."""
    import numpy as np
    from scipy import ndimage
    NX, NZ, NY = _walk_dims()
    nc, nb = int(round(clear / WALK_RES)), int(round(body_from / WALK_RES))
    rr = radius / WALK_RES
    d = int(math.floor(rr))
    yy, xx = np.mgrid[-d:d + 1, -d:d + 1]
    disk = xx * xx + yy * yy <= rr * rr + 1e-9
    Ls, Zs, Xs = [], [], []
    for L in range(1, NY - nc):
        cand = O[L - 1] & ~O[L]
        if not cand.any():
            continue
        cand &= ~O[L:L + nc].any(axis=0)
        if not cand.any():
            continue
        cand &= ~ndimage.binary_dilation(O[L + nb:L + nc].any(axis=0), structure=disk)
        z, x = np.nonzero(cand)
        Ls.append(np.full(z.shape, L, np.int32))
        Zs.append(z.astype(np.int32))
        Xs.append(x.astype(np.int32))
    return np.concatenate(Ls), np.concatenate(Zs), np.concatenate(Xs)


def walk_pieces(L, Z, X):
    """The connected pieces of the standable cells (eight neighbours, a stud up or down)."""
    import numpy as np
    from scipy import sparse
    from scipy.sparse.csgraph import connected_components
    NX, NZ, NY = _walk_dims()
    ns = int(round(WALK_STEP / WALK_RES))
    ids = (L.astype(np.int64) * NZ + Z) * NX + X
    order = np.argsort(ids)
    sid = ids[order]
    src, dst = [], []
    for dz, dx in ((0, 1), (1, -1), (1, 0), (1, 1)):
        okx = (X + dx >= 0) & (X + dx < NX) & (Z + dz < NZ)
        for dl in range(-ns, ns + 1):
            nbr = ((L + dl).astype(np.int64) * NZ + (Z + dz)) * NX + (X + dx)
            idx = np.searchsorted(sid, nbr)
            idx[idx >= len(sid)] = 0
            hit = okx & (L + dl >= 0) & (L + dl < NY) & (sid[idx] == nbr)
            src.append(np.nonzero(hit)[0])
            dst.append(order[idx[hit]])
    src, dst = np.concatenate(src), np.concatenate(dst)
    g = sparse.coo_matrix((np.ones(len(src), np.int8), (src, dst)), shape=(len(sid), len(sid)))
    return connected_components(g, directed=False)[1]


# office floor points (map-local studs: x, floor y, z): the ground floor, the second, the third floor's corridor and
# its three rooms
OFFICE_POINTS = {"office ground floor": (-120, 3.06, -40), "office second floor": (-120, 13.97, -40), "office third floor": (-115, 25.41, -45),
                 "shift office": (-118, 25.41, -35), "manager's office": (-118, 25.41, -78), "records room": (-118, 25.41, -60)}


def paths(recp, out=None):
    """Walk the build; returns the problems (an empty list when every check passes)."""
    import numpy as np
    rec = json.load(open(recp))
    b = rec['bounds']
    ox, oz = (b['x0'] + b['x1']) / 2, (b['z0'] + b['z1']) / 2
    X0, X1, Z0, Z1, Y0, Y1 = WALK_BOX
    O = voxelise(rec['parts'], ox, oz)
    problems, keep = [], {}
    for agent, (radius, clear, body) in AGENTS.items():
        L, Z, X = standable(O, radius, clear, body)
        lab = walk_pieces(L, Z, X)
        nx, nz, ny = X0 + (X + 0.5) * WALK_RES, Z0 + (Z + 0.5) * WALK_RES, Y0 + L * WALK_RES

        def near(x, y, z, rxy, ylo, yhi):
            m = (np.abs(nx - x) <= rxy) & (np.abs(nz - z) <= rxy) & (ny >= y + ylo) & (ny <= y + yhi)
            return np.nonzero(m)[0]

        def piece_at(x, y, z, rxy, ylo, yhi):
            idx = near(x, y, z, rxy, ylo, yhi)
            if not len(idx):
                return -1
            return int(lab[idx[np.argmin((nx[idx] - x) ** 2 + (nz[idx] - z) ** 2)]])

        sp = [piece_at(s['cf']['p'][0] - ox, s['cf']['p'][1], s['cf']['p'][2] - oz, 1.5, -6, 1) for s in rec['spawns']]
        main_ = max(set(sp), key=sp.count) if sp else -1
        bad = []
        exits = {e['id']: e for e in rec['extracts'] + rec.get('transits', [])}
        epiece = {k: piece_at(e['pos'][0] - ox, e['pos'][1], e['pos'][2] - oz, 3.0, -3, 4) for k, e in exits.items()}
        if agent == "strict":
            for s, p in zip(rec['spawns'], sp):
                miss = sorted(k for k in set(s['extracts']) | {k for k in exits if k.startswith('TR_')} | {k for k, e in exits.items()
                              if e.get('rule', {}).get('kind') in ('scav', 'key')} if k in epiece and epiece[k] != p)
                if p < 0:
                    bad.append('spawn %s %s has no room to stand' % (s['id'], s['name']))
                elif miss:
                    bad.append('spawn %s %s reaches none of %s' % (s['id'], s['name'], ', '.join(miss)))
            for k, p in epiece.items():
                if p != main_:
                    bad.append('exit %s %s: its centre is %s' % (k, exits[k]['name'], 'not standable' if p < 0 else 'cut off'))
            for nm, (x, y, z) in OFFICE_POINTS.items():
                if piece_at(x, y, z, 4.0, -1, 2) != main_:
                    bad.append(nm + ' cut off')
            pts = [('scav zone %d' % i, p) for i, p in enumerate(rec['scavZones'])]
            pts += [('route %s point %d' % (rid, i), p) for rid, r in rec['patrols'].items() for i, p in enumerate(r)]
            for bo in rec['bosses']:
                for zn in bo['zones']:
                    pts.append(('%s at %s' % (bo['label'], zn['name']), zn['home']))
                    pts += [('%s crew at %s' % (bo['label'], zn['name']), c) for c in zn['crew']]
            for nm, p in pts:
                if piece_at(p[0] - ox, p[1], p[2] - oz, 2.5, -3, 2) != main_:
                    bad.append(nm + ' cut off')
        else:
            for k, z_ in rec['visitZones'].items():
                x, y, z = z_['pos']
                if main_ not in set(lab[near(x - ox, y, z - oz, z_['r'] * 0.8, -4, 1.5)].tolist()):
                    bad.append('task place %s out of reach' % k)
            for c in rec['containers']:
                x, y, z = c['cf']['p']
                if main_ not in set(lab[near(x - ox, y, z - oz, 4.5, -2, 2)].tolist()):
                    bad.append('loot box %s (%s) out of reach' % (c['id'], c['label']))
            for l in rec['loose']:
                x, y, z = l['pos']
                if main_ not in set(lab[near(x - ox, y, z - oz, 3.5, -3, 1.5)].tolist()):
                    bad.append('loose spot at (%.0f, %.0f, %.0f) out of reach' % (x - ox, y, z - oz))
        print('%s agent (radius %.1f, %.1f tall): %d cells standable, %d problems' % (agent, radius, clear, len(L), len(bad)))
        for q in bad:
            print('  ', q)
        problems += ['%s: %s' % (agent, q) for q in bad]
        keep[agent] = (nx, ny, nz, lab, main_)
    if out:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        nx, ny, nz, lab, main_ = keep['strict']
        NX, NZ, NY = _walk_dims()
        bands = [('tunnels and the sump', -99, -4), ('halls, annexes, yards (-4..6)', -4, 6), ('gallery, dock, second floor (6..20)', 6, 20),
                 ('third floor and catwalks (20..32)', 20, 32)]
        fig, axs = plt.subplots(2, 2, figsize=(22, 24), dpi=70)
        cols = np.array([plt.get_cmap('tab20')(c % 20)[:3] for c in range(20)])
        for ax, (title, ylo, yhi) in zip(axs.flat, bands):
            m = (ny >= ylo) & (ny < yhi)
            img = np.full((NZ, NX, 3), 0.1)
            rgb = np.where((lab[m] == main_)[:, None], np.array([0.72, 0.75, 0.72]), cols[lab[m] % 20])
            img[((nz[m] - Z0) / WALK_RES).astype(int), ((nx[m] - X0) / WALK_RES).astype(int)] = rgb
            ax.imshow(img, extent=(X0, X1, Z1, Z0), interpolation='nearest')
            for s in rec['spawns']:
                x, y, z = s['cf']['p']
                if ylo <= y - 3 < yhi:
                    ax.plot(x - ox, z - oz, 'o', color='white', ms=8, mec='black')
                    ax.text(x - ox + 3, z - oz, s['name'], color='white', fontsize=7)
            for k, e in {e['id']: e for e in rec['extracts'] + rec.get('transits', [])}.items():
                x, y, z = e['pos']
                if ylo <= y < yhi:
                    ax.plot(x - ox, z - oz, 's', color='lime', ms=9, mec='black')
                    ax.text(x - ox + 3, z - oz + 6, k, color='lime', fontsize=8)
            ax.set_title(title)
            ax.set_xlim(-215, 215)
            ax.set_ylim(235, -235)
        fig.suptitle('SMELTER offline walk (strict agent): grey = the piece the spawns stand in, colours = cut-off pieces '
                     '(roof tops, machine tops and the ground outside are expected to be apart)', fontsize=11)
        fig.savefig(out, bbox_inches='tight')
        print('wrote', out)
    return problems


# ---- ref: the reference alone ----
def ref_draw(refp, out):
    """The reference JSON alone (no SVG or infographic pixels), four levels, north up, metres."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.patches import Polygon, Circle
    d = json.load(open(refp))
    LV = [('tunnels (game y -2.6, the sump -3.9)', 'basement'), ('ground floor (hall 0.1, west wing 1.08)', 'ground'),
          ('gallery 2.73 and second floor 4.57', 'second'), ('third floor 8.23 and catwalks', 'third')]
    fig, axs = plt.subplots(2, 2, figsize=(22, 24), dpi=80)


    def obox(ax, b, **kw):
        c, s = math.cos(math.radians(b['rot'])), math.sin(math.radians(b['rot']))
        pts = []
        for a, bb in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            u, v = a * b['w'] / 2, bb * b['d'] / 2
            pts.append((b['cx'] + u * c - v * s, b['cz'] + u * s + v * c))
        ax.add_patch(Polygon(pts, **kw))


    for ax, (title, lv) in zip(axs.flat, LV):
        ax.set_facecolor('#1d3b3e')
        rings = d['floors'][lv]
        for r in rings:
            if r['role'] in ('outer', 'island'):
                ax.add_patch(Polygon(r['pts'], closed=True, facecolor='#9aa3ab', edgecolor='#333', lw=0.5))
        for r in rings:
            if r['role'] in ('hole', 'void'):
                ax.add_patch(Polygon(r['pts'], closed=True, facecolor='#1a2632' if r['role'] == 'hole' else '#1d3b3e', edgecolor='#333', lw=0.5))
        if lv == 'ground':
            for l in d['ledges']:
                obox(ax, l, facecolor='#d8d4d0', alpha=0.6, edgecolor='none')
            for o in d['obstacles']['ground']:
                obox(ax, o, facecolor='#24323f', edgecolor='none')
            for s in d['silos']:
                ax.add_patch(Circle((s['cx'], s['cz']), s['r'], color='#1a2632'))
            mh = d['machine_house']
            ax.add_patch(Polygon(mh['pts'], closed=True, facecolor='#1a2632'))
        if lv == 'second':
            for o in d['obstacles']['second']:
                obox(ax, o, facecolor='#24323f', edgecolor='none')
        key = {'ground': 'ground', 'second': 'second', 'third': 'third'}.get(lv)
        for pl in d['walls'].get(key, []) if key else []:
            ax.plot([p[0] for p in pl], [p[1] for p in pl], color='black', lw=1.2)
        for st in d['stairs']:
            show = (lv in st['levels']) or (lv == 'ground' and 'ground' in st['levels'])
            if show and st['id'] != 'drop':
                obox(ax, st, facecolor='#ffd700' if st['u_turn'] else '#ffa500', edgecolor='#806000', lw=0.5, alpha=0.9)
        level_of = {'basement': 'basement', 'ground': 'ground', 'courtyard': 'ground', 'second': 'second', 'third': 'third'}
        for lb in d['labels']:
            lo = lb['game_y_from'] if lb['game_y_from'] is not None else -1
            l2 = 'basement' if lo < -5 else ('third' if lo >= 6 else ('second' if lo >= 3 else 'ground'))
            if l2 == lv or (lv == 'ground' and lo == -1 and (lb['game_y_to'] or 0) > 5):
                ax.plot(lb['x'], lb['z'], '+', color='#ffe066')
                ax.text(lb['x'] + 0.6, lb['z'] - 0.6, lb['ours'] + '\n(' + lb['eft'] + ')', color='#ffe066', fontsize=7)
        for e in d['extracts']:
            if level_of[e['level']] == lv:
                col = 'lime' if 'pmc' in e['sides'] else 'cyan'
                ax.plot(e['x'], e['z'], 'o', color=col, ms=11, mec='black')
                ax.text(e['x'] + 1.2, e['z'] + 1.8, e['ours'] + '\n(' + e['eft'] + ', ' + e['grade'] + ')', color=col, fontsize=8, weight='bold')
        for t in d['transits']:
            if level_of[t['level']] == lv:
                ax.plot(t['x'], t['z'], 'D', color='#4aa0ff', ms=9, mec='black')
                ax.text(t['x'] + 1.2, t['z'] - 1.2, t['eft'], color='#4aa0ff', fontsize=7)
        for lk in d['icons']['locks']:
            if level_of[lk['level']] == lv:
                ax.plot(lk['x'], lk['z'], 's', color='#d08030', ms=8, mec='black')
        for c in d['spawns']['player_clusters']:
            l2 = 'basement' if c['y'] < -1 else ('second' if c['y'] > 2.5 else 'ground')
            if c['y'] > 6:
                l2 = 'third'
            if l2 == lv:
                ax.add_patch(Circle((c['x'], c['z']), 2.2, fill=False, color='white', lw=1.5, ls='--'))
        for p in d['spawns']['boss_capable']:
            l2 = 'basement' if p[2] < -1 else 'ground'
            if l2 == lv:
                ax.plot(p[0], p[1], '*', color='red', ms=11)
        for p in d['spawns']['scav_bot']:
            l2 = 'basement' if p[2] < -1 else ('second' if p[2] > 3 else 'ground')
            if l2 == lv:
                ax.plot(p[0], p[1], 'x', color='#ff80ff', ms=7)
        ax.set_xlim(-72, 72); ax.set_ylim(76, -76); ax.set_aspect('equal')
        ax.set_xticks(range(-70, 71, 10)); ax.set_yticks(range(-70, 71, 10)); ax.grid(True, color='white', alpha=0.15)
        ax.set_title(title, fontsize=13); ax.set_xlabel('x m (east)'); ax.set_ylabel('z m (south)')
    fig.suptitle('EFT Factory reference (factory_layout.json, metres, north up): floors grey, holes and walls dark, stairs orange (U-turn towers gold), '
                 'our names over EFT\'s, exits lime (PMC) / cyan (scav), transits blue, locked doors orange squares, PMC spawn groups white rings, '
                 'boss points red stars, scav points pink crosses', fontsize=11)
    fig.savefig(out, bbox_inches='tight')
    print('wrote', out)


def main(argv):
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    refp = os.path.join(root, 'docs', 'maps', 'reference', 'factory_layout.json')
    build_png = os.path.join(root, 'docs', 'maps', 'reference', 'smelter_build_preview.png')
    ref_png = os.path.join(root, 'docs', 'maps', 'reference', 'factory_layout_preview.png')
    cmd = argv[0] if argv else ''
    if cmd == 'run' and len(argv) == 2:
        run(root, argv[1])
        return 0
    if cmd == 'draw' and len(argv) in (2, 3):
        return 1 if draw(argv[1], refp, argv[2] if len(argv) == 3 else build_png) else 0
    if cmd == 'paths' and len(argv) in (2, 3):
        return 1 if paths(argv[1], argv[2] if len(argv) == 3 else None) else 0
    if cmd == 'all' and len(argv) in (1, 2):
        fd, tmp = tempfile.mkstemp(suffix='.json')
        os.close(fd)
        try:
            run(root, tmp)
            bad = draw(tmp, refp, argv[1] if len(argv) == 2 else build_png)
            return 1 if paths(tmp) or bad else 0
        finally:
            os.remove(tmp)
    if cmd == 'ref' and len(argv) in (1, 2):
        ref_draw(refp, argv[1] if len(argv) == 2 else ref_png)
        return 0
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
