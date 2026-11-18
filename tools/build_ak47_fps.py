"""Build a game-ready first-person AK-47 from ak47_detailed.blend.

Run inside Blender (GUI, MCP):
    exec(compile(open('/home/ruzik-admin/Документы/Проект по умолчанию/tools/build_ak47_fps.py', encoding='utf-8').read(), 'build_ak47_fps.py', 'exec'))

Result:
  - ak47_fps_work.blend (working copy)
  - godot_project/assets/models/ak47_fps.glb
  - ak47_fps_preview.png
"""
import math
import os

import bpy
from mathutils import Vector

ROOT = "/home/ruzik-admin/Документы/Проект по умолчанию"
OUT_GLB = os.path.join(ROOT, "godot_project/assets/models/ak47_fps.glb")
OUT_BLEND = os.path.join(ROOT, "ak47_fps_work.blend")
OUT_PREVIEW = os.path.join(ROOT, "ak47_fps_preview.png")

# ---------------------------------------------------------------- scene setup
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0

# Remove any previous helper objects from a re-run.
for o in list(bpy.data.objects):
    if o.name.startswith(("AK_Body", "AK_Magazine", "AK_Bolt", "Arms", "AK_Rig",
                          "PreviewCam", "PreviewKey", "PreviewFill")):
        bpy.data.objects.remove(o, do_unlink=True)

meshes = [o for o in scene.objects if o.type == 'MESH']
print("AK_FPS meshes before:", len(meshes))

# ------------------------------------------------------------- static materials
def static_mat(name, rgb, metallic=0.0, roughness=0.5):
    m = bpy.data.materials.get(name)
    if m:
        bpy.data.materials.remove(m)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1.0)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    m.diffuse_color = (*rgb, 1.0)
    return m

WOOD = static_mat('AK_Wood_Static', (0.315, 0.135, 0.052), 0.0, 0.46)
WOOD_DARK = static_mat('AK_WoodDark_Static', (0.205, 0.078, 0.030), 0.0, 0.52)
GLOVE = static_mat('Glove', (0.040, 0.042, 0.046), 0.0, 0.82)
GLOVE_PLATE = static_mat('GlovePlate', (0.095, 0.100, 0.110), 0.55, 0.48)
SLEEVE = static_mat('Sleeve', (0.105, 0.122, 0.072), 0.0, 0.88)
CUFF = static_mat('Cuff', (0.052, 0.058, 0.050), 0.0, 0.9)

# Replace the procedural wood shaders with exportable static colors.
for o in meshes:
    for slot in o.material_slots:
        m = slot.material
        if not m:
            continue
        if m.name == 'AK_Wood':
            slot.material = WOOD
        elif m.name == 'AK_Wood_Dark':
            slot.material = WOOD_DARK

# --------------------------------------------------------- apply bevels to all
for o in meshes:
    if o.mode != 'OBJECT':
        continue
    bpy.context.view_layer.objects.active = o
    for mod in list(o.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except Exception as exc:
            print("modifier skip", o.name, exc)

# ------------------------------------------------------------ split into groups
def mag_object(o):
    n = o.name
    if n in ('Curved magazine', 'Magazine lip', 'Magazine floor screw'):
        return True
    return n.startswith('Magazine rib') or n.startswith('Magazine floor')


mag_names = [o.name for o in meshes if mag_object(o)]
bolt_names = ['Charging handle']
group_mag = [o for o in meshes if o.name in mag_names]
group_bolt = [o for o in meshes if o.name in bolt_names]
group_body = [o for o in meshes if o not in group_mag and o not in group_bolt]
print("mag:", len(group_mag), "bolt:", len(group_bolt), "body:", len(group_body))

def join_group(objects, name, pivot):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    scene.cursor.location = pivot
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    # Put the origin of every split part at the exact same place in world
    # space, then zero the object location is NOT desired: Godot needs the
    # pivot translation to place the part. Keep location as-is.
    return obj

body = join_group(group_body, 'AK_Body', (0.0, 0.0, 0.0))
mag = join_group(group_mag, 'AK_Magazine', (0.02, 0.0, -0.062))
bolt = join_group(group_bolt, 'AK_Bolt', (0.105, 0.044, 0.022))

# --------------------------------------------------------------- arms / gloves
arm_objects = []

def add_mat(o, mat):
    o.data.materials.append(mat)
    return o

def bevel(o, width=0.008, segments=2):
    mod = o.modifiers.new('bevel', 'BEVEL')
    mod.width = width
    mod.segments = segments
    mod.limit_method = 'ANGLE'
    mod.angle_limit = math.radians(50)
    return o

def rbox(name, loc, size, mat, rot=(0, 0, 0), bv=0.008):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = size
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel(o, bv, 3)
    add_mat(o, mat)
    arm_objects.append(o)
    return o

def limb(name, a, b, r1, r2, mat, verts=12):
    a, b = Vector(a), Vector(b)
    d = b - a
    length = d.length
    mid = (a + b) * 0.5
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2,
                                    depth=length, location=mid)
    o = bpy.context.object
    o.name = name
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bevel(o, 0.006, 2)
    add_mat(o, mat)
    arm_objects.append(o)
    return o

def cuff(name, a, b, r, mat):
    a, b = Vector(a), Vector(b)
    d = b - a
    mid = (a + b) * 0.5
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=r, depth=0.032,
                                        location=mid)
    o = bpy.context.object
    o.name = name
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bevel(o, 0.004, 2)
    add_mat(o, mat)
    arm_objects.append(o)
    return o

# Right hand (screen right, +Y): cupped around the pistol grip.
rbox('Glove_R_Palm', (0.222, 0.030, -0.122), (0.062, 0.055, 0.105), GLOVE,
     rot=(0, math.radians(12), 0), bv=0.019)
rbox('Glove_R_Back', (0.252, 0.030, -0.120), (0.020, 0.045, 0.078), GLOVE_PLATE,
     rot=(0, math.radians(12), 0), bv=0.010)
for i, z in enumerate((-0.070, -0.098, -0.126, -0.154)):
    rbox(f'Glove_R_Finger{i}', (0.191, 0.040, z), (0.060, 0.023, 0.021), GLOVE,
         rot=(0, 0, 0), bv=0.008)
rbox('Glove_R_Thumb', (0.185, 0.004, -0.075), (0.022, 0.020, 0.055), GLOVE,
     rot=(math.radians(18), 0, 0), bv=0.008)
limb('Sleeve_R', (0.258, 0.040, -0.155), (0.455, 0.125, -0.315),
     0.045, 0.058, SLEEVE)
cuff('Cuff_R', (0.258, 0.040, -0.155), (0.286, 0.051, -0.176), 0.050, CUFF)

# Left hand (screen left, -Y): over the wooden handguard, fingers wrap down.
rbox('Glove_L_Palm', (-0.166, -0.022, -0.022), (0.085, 0.062, 0.048), GLOVE,
     rot=(0, math.radians(-4), 0), bv=0.015)
rbox('Glove_L_Back', (-0.148, -0.050, -0.018), (0.060, 0.020, 0.038), GLOVE_PLATE,
     rot=(0, 0, 0), bv=0.008)
for i, x in enumerate((-0.139, -0.158, -0.177, -0.196)):
    rbox(f'Glove_L_Finger{i}', (x, -0.055, -0.043), (0.020, 0.026, 0.050), GLOVE,
         rot=(0, 0, 0), bv=0.008)
rbox('Glove_L_Thumb', (-0.130, -0.006, -0.045), (0.020, 0.040, 0.022), GLOVE,
     rot=(0, 0, math.radians(12)), bv=0.007)
limb('Sleeve_L', (-0.205, -0.050, -0.058), (-0.005, -0.180, -0.275),
     0.042, 0.055, SLEEVE)
cuff('Cuff_L', (-0.205, -0.050, -0.058), (-0.232, -0.045, -0.078), 0.047, CUFF)

# Join arms into one object, origin at world zero.
bpy.ops.object.select_all(action='DESELECT')
for o in arm_objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm_objects[0]
bpy.ops.object.join()
arms = bpy.context.view_layer.objects.active
arms.name = 'Arms'
arms.data.name = 'Arms'
bpy.ops.object.select_all(action='DESELECT')
arms.select_set(True)
bpy.context.view_layer.objects.active = arms
scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

# --------------------------------------------------------------- hierarchy
root = bpy.data.objects.new('AK_Rig', None)
root.empty_display_type = 'PLAIN_AXES'
scene.collection.objects.link(root)
for o in (body, mag, bolt, arms):
    o.parent = root
    o.matrix_parent_inverse = root.matrix_world.inverted()
    # Keep the world transform exact after parenting.
    o.matrix_world = o.matrix_world

# Apply transforms into the split parts? Keep their pivot locations for Godot.
# Bake only rotations/scales to avoid non-uniform scale surprises.
for o in (body, mag, bolt, arms):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

# -------------------------------------------------------------------- export
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True)
for o in (body, mag, bolt, arms):
    o.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_yup=True,
    export_animations=False,
    export_cameras=False,
    export_lights=False,
    export_extras=True,
)
print("AK_FPS exported:", OUT_GLB, os.path.getsize(OUT_GLB))

# ------------------------------------------------------------------- preview
preview_cam_data = bpy.data.cameras.new('PreviewCamData')
preview_cam = bpy.data.objects.new('PreviewCam', preview_cam_data)
scene.collection.objects.link(preview_cam)
preview_cam.location = (0.66, -0.02, -0.14)
target = Vector((-0.12, 0.0, -0.05))
direction = target - preview_cam.location
preview_cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
preview_cam_data.lens = 55
scene.camera = preview_cam

key_data = bpy.data.lights.new('PreviewKeyData', 'AREA')
key_data.energy = 110
key_data.size = 1.2
key = bpy.data.objects.new('PreviewKey', key_data)
scene.collection.objects.link(key)
key.location = (0.55, -0.75, 0.85)
key.rotation_euler = (Vector((0.0, 0.0, 0.02)) - key.location).to_track_quat('-Z', 'Y').to_euler()

fill_data = bpy.data.lights.new('PreviewFillData', 'AREA')
fill_data.energy = 45
fill_data.size = 1.5
fill = bpy.data.objects.new('PreviewFill', fill_data)
scene.collection.objects.link(fill)
fill.location = (0.35, 0.85, 0.45)
fill.rotation_euler = (Vector((0.0, 0.0, 0.0)) - fill.location).to_track_quat('-Z', 'Y').to_euler()

scene.render.resolution_x = 1280
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.film_transparent = False
scene.render.filepath = OUT_PREVIEW
try:
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
except Exception:
    pass
try:
    scene.eevee.taa_render_samples = 32
except Exception:
    pass
try:
    bpy.ops.render.render(write_still=True)
    print("AK_FPS preview:", OUT_PREVIEW)
except Exception as exc:
    print("render failed:", exc)

# Save working copy (do not touch the original detailed file).
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
print("AK_FPS saved blend:", OUT_BLEND)
