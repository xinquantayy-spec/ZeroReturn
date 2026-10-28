"""Zero Return - character fit preview renders (separate "ZR_Preview" scene; the user's scene is untouched).
preview(pieces, out_png, views=(0, 90, 180), tints=None, size=(1500, 700), ortho=13.5, focus_y=2.75)
  pieces: list of (object_name, host_part_or_None, tint_key) - host = RigSpec part the piece is authored around
          (equipment authored in host-local space, body segments at their own centre).
Renders front / side / back (or any yaw list) side by side with EEVEE, neutral light, orthographic camera.
"""
import bpy, json, math, os
from mathutils import Vector, Euler

HERE = os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "assets", "blender_scripts")
TINTS = {
    "jacket": (0.36, 0.38, 0.28), "pants": (0.25, 0.26, 0.23), "skin": (0.86, 0.72, 0.6), "glove": (0.16, 0.16, 0.15),
    "boot": (0.35, 0.28, 0.2), "helmet": (0.3, 0.32, 0.25), "gear": (0.33, 0.34, 0.26), "white": (1, 1, 1),
}
BODY_TINT = {"UpperTorso": "jacket", "UpperArm": "jacket", "LowerArm": "jacket", "LowerTorso": "pants", "UpperLeg": "pants",
             "LowerLeg": "pants", "Head": "skin", "Hand": "glove", "Foot": "boot"}


def spec():
    return json.load(open(os.path.join(HERE, "rig_spec.json")))


def body_pieces(prefix="ZR_BLK_"):
    out = []
    for name in spec()["parts"]:
        tint = next((v for k, v in BODY_TINT.items() if name.endswith(k)), "white")
        out.append((prefix + name, name, tint, True))
    return out


def lin(h):
    """sRGB hex -> linear RGB (EEVEE shading space)"""
    h = h.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def _mat(tint, tints):
    """material = vertex colour x tint; tint is a TINTS key, a hex string or an RGB tuple"""
    if isinstance(tint, str) and tint.startswith("#"):
        rgb = lin(tint)
    elif isinstance(tint, (tuple, list)):
        rgb = tuple(tint)[:3]
    else:
        rgb = (tints or TINTS).get(tint, (1, 1, 1))
    name = "PV_tint_%.3f_%.3f_%.3f" % tuple(rgb)
    m = bpy.data.materials.get(name)
    if not m:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = 'RGBA'
        mix.blend_type = 'MULTIPLY'
        mix.inputs[0].default_value = 1.0
        nt.links.new(vc.outputs["Color"], mix.inputs[6])
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.8
        mix.inputs[7].default_value = tuple(rgb) + (1,)
    return m


def _place(prev, S, entries, ox, yaw, tag, tints=None):
    """entries: (object, host, tint[, opts]); opts {"scale": (sx, sy, sz), "shift": (dx, dy, dz)} in Roblox
    host space (the game's layer inflation / backpack offset, applied about the host origin)"""
    r = Euler((0, 0, math.radians(yaw)))
    for n, entry in enumerate(entries):
        objname, host, tint = entry[0], entry[1], entry[2]
        opts = entry[3] if len(entry) > 3 and isinstance(entry[3], dict) else {}
        src = bpy.data.objects.get(objname)
        if not src:
            print("missing", objname)
            continue
        mesh_copy = src.data.copy()
        mesh_copy.materials.clear()
        mesh_copy.materials.append(_mat(tint, tints))
        inst = bpy.data.objects.new("PV_%s_%d_%s" % (tag, n, objname), mesh_copy)
        c = S["parts"][host]["center"] if host in S["parts"] else (0, 0, 0)
        d = opts.get("shift", (0, 0, 0))
        sc = opts.get("scale", (1, 1, 1))
        p = Vector((-(c[0] + d[0]), c[2] + d[2], c[1] + d[1]))
        p.rotate(r)
        inst.location = p + Vector((ox, 0, 0))
        inst.rotation_euler = r
        inst.scale = (sc[0], sc[2], sc[1])
        prev.collection.objects.link(inst)


def _stage(name):
    prev = bpy.data.scenes.get(name)
    if prev:
        for o in list(prev.objects):
            bpy.data.objects.remove(o)
        bpy.data.scenes.remove(prev)
    return bpy.data.scenes.new(name)


def _render(prev, out_png, size, ortho, focus_y, cam_yaw=0.0, cam_pitch=0.0):
    cam = bpy.data.objects.new("PV_Cam", bpy.data.cameras.new("PV_Cam"))
    prev.collection.objects.link(cam)
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = ortho
    cy, cp = math.radians(cam_yaw), math.radians(cam_pitch)
    cam.location = (math.sin(cy) * 20 * math.cos(cp), -math.cos(cy) * 20 * math.cos(cp), focus_y + 20 * math.sin(cp))
    cam.rotation_euler = (math.radians(90) - cp, 0, cy)
    prev.camera = cam
    sun = bpy.data.objects.new("PV_Sun", bpy.data.lights.new("PV_Sun", 'SUN'))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(55), math.radians(15), math.radians(-30))
    prev.collection.objects.link(sun)
    w = bpy.data.worlds.get("PV_World") or bpy.data.worlds.new("PV_World")
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.55, 0.56, 0.57, 1)
    bg.inputs[1].default_value = 0.9
    prev.world = w
    prev.render.engine = 'BLENDER_EEVEE'
    prev.render.resolution_x, prev.render.resolution_y = size
    prev.render.filepath = out_png
    win = bpy.context.window
    old = win.scene
    win.scene = prev
    try:
        bpy.ops.render.render(write_still=True, scene=prev.name)
    finally:
        win.scene = old
    return out_png


def lineup(chars, out_png, yaw=0.0, size=(1900, 760), ortho=None, spacing=3.9, focus_y=2.8, tints=None, cam_pitch=0.0):
    """several characters side by side, all turned to `yaw` (0 = facing the camera, 90 = right side, 180 = back);
    chars = [entries | (entries, yaw), ...] (see _place)"""
    S = spec()
    prev = _stage("ZR_Preview")
    for i, ch in enumerate(chars):
        entries, cyaw = (ch[0], ch[1]) if isinstance(ch, tuple) else (ch, yaw)
        ox = (i - (len(chars) - 1) / 2) * spacing
        _place(prev, S, entries, ox, cyaw, "c%d" % i, tints)
    ortho = ortho or max(7.0, spacing * len(chars) * 1.02)
    return _render(prev, out_png, size, ortho, focus_y, cam_pitch=cam_pitch)


def preview(pieces, out_png, views=(0, 90, 180), tints=None, size=(1500, 700), ortho=13.5, focus_y=2.75, spacing=4.2, cam_yaw=0.0):
    S = spec()
    prev = _stage("ZR_Preview")
    for i, yaw in enumerate(views):
        ox = (i - (len(views) - 1) / 2) * spacing
        _place(prev, S, pieces, ox, yaw, "v%d" % i, tints)
    return _render(prev, out_png, size, ortho, focus_y, cam_yaw=cam_yaw)
