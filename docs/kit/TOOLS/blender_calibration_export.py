"""Optional demonstration script, only run after verifying Blender path and user-approved scratch location.
blender --background --python TOOLS/blender_calibration_export.py -- /absolute/path/to/exports
Creates only a simple calibration cube, for scale/pivot import verification. Does not touch existing .blend files.
"""
import bpy, sys, os
from pathlib import Path
args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if not args:
    raise SystemExit('Pass output folder as argument after --; refusing implicit output directory')
root = Path(args[0]).resolve()
root.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.mesh.primitive_cube_add(size=2, location=(0,0,1))
cube = bpy.context.object
cube.name = 'EFB_CALIBRATION_CUBE_2x2x2'
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
mat = bpy.data.materials.new('EFB_CHECK_ORANGE')
mat.diffuse_color=(0.68,0.33,0.15,1.0)
cube.data.materials.append(mat)
blend = root/'calibration_cube.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
for x in bpy.context.selected_objects: x.select_set(False)
cube.select_set(True)
bpy.context.view_layer.objects.active = cube
bpy.ops.export_scene.fbx(filepath=str(root/'calibration_cube.fbx'), use_selection=True, apply_unit_scale=True)
print('EXPORTED', str(blend), str(root/'calibration_cube.fbx'))
