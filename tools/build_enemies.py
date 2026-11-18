"""Build stylized combat robots for RUBEZH // SECTOR 7.

Run inside Blender (GUI, MCP):
    exec(compile(open('/home/ruzik-admin/Документы/Проект по умолчанию/tools/build_enemies.py', encoding='utf-8').read(), 'build_enemies.py', 'exec'))

Exports:
  godot_project/assets/models/sentinel.glb
  godot_project/assets/models/juggernaut.glb
  enemy_scout_preview.png, enemy_heavy_preview.png
"""
import math
import os

import bpy
from mathutils import Vector

ROOT = "/home/ruzik-admin/Документы/Проект по умолчанию"
MODELS = os.path.join(ROOT, "godot_project/assets/models")
os.makedirs(MODELS, exist_ok=True)

# ------------------------------------------------------------------ clean file
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for block in list(bpy.data.meshes):
    if block.users == 0:
        bpy.data.meshes.remove(block)
for block in list(bpy.data.materials):
    if block.users == 0:
        bpy.data.materials.remove(block)

scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
try:
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
except TypeError:
    scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 1200
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'Medium High Contrast'
scene.world.color = (0.01, 0.012, 0.016)

# ------------------------------------------------------------------ materials
def make_mat(name, rgb, metallic=0.0, roughness=0.5, emission=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1.0)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    if emission:
        try:
            bsdf.inputs['Emission Color'].default_value = (*emission, 1.0)
            bsdf.inputs['Emission Strength'].default_value = strength
        except Exception:
            pass
    m.diffuse_color = (*rgb, 1.0)
    return m

ARMOR = make_mat('Bot_Armor', (0.035, 0.040, 0.048), 0.55, 0.48)
PLATE = make_mat('Bot_Plate', (0.075, 0.082, 0.094), 0.7, 0.38)
JOINT = make_mat('Bot_Joint', (0.018, 0.019, 0.023), 0.2, 0.8)
ACCENT = make_mat('Bot_Accent', (0.50, 0.16, 0.015), 0.15, 0.45)
ACCENT_GLOW = make_mat('Bot_Accent_Glow', (0.8, 0.25, 0.02), 0.0, 0.4,
                       emission=(1.0, 0.22, 0.01), strength=4.0)
VISOR = make_mat('Bot_Visor', (0.6, 0.02, 0.01), 0.0, 0.3,
                 emission=(1.0, 0.015, 0.005), strength=9.0)
VISOR_HEAVY = make_mat('Bot_Visor_Heavy', (0.6, 0.05, 0.0), 0.0, 0.3,
                       emission=(1.0, 0.08, 0.005), strength=10.0)
WHITE = make_mat('Bot_Marking', (0.55, 0.57, 0.55), 0.1, 0.6)

# ------------------------------------------------------------------- helpers
PARTS = []

def register(obj):
    PARTS.append(obj)
    return obj

def add_box(name, loc, size, mat, rot=(0, 0, 0), bevel=0.012, bevel_seg=3):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        md = o.modifiers.new('bevel', 'BEVEL')
        md.width = bevel
        md.segments = bevel_seg
        md.limit_method = 'ANGLE'
        md.angle_limit = math.radians(45)
    o.data.materials.append(mat)
    return register(o)

def add_cyl(name, a, b, r1, r2, mat, verts=14, bevel=0.006):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2,
                                    depth=d.length, location=(a + b) * 0.5)
    o = bpy.context.object
    o.name = name
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    if bevel > 0:
        md = o.modifiers.new('bevel', 'BEVEL')
        md.width = bevel
        md.segments = 2
    o.data.materials.append(mat)
    return register(o)

def add_sphere(name, loc, radius, mat, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=10,
                                         radius=radius, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    return register(o)

def add_beam(name, a, b, width, mat, bevel=0.006):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(a + b) * 0.5)
    o = bpy.context.object
    o.name = name
    o.scale = (width, width, d.length)
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        md = o.modifiers.new('bevel', 'BEVEL')
        md.width = bevel
        md.segments = 2
    o.data.materials.append(mat)
    return register(o)

def apply_modifiers_and_join(objects, name, pivot):
    for o in objects:
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            try:
                bpy.ops.object.modifier_apply(modifier=mod.name)
            except Exception:
                pass
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.name = name
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    scene.cursor.location = pivot
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return o

def make_empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = 'PLAIN_AXES'
    e.empty_display_size = 0.08
    e.location = loc
    scene.collection.objects.link(e)
    if parent:
        e.parent = parent
        e.matrix_parent_inverse = parent.matrix_world.inverted()
    return e

def parent_keep(obj, parent):
    obj.parent = parent
    obj.matrix_parent_inverse = parent.matrix_world.inverted()

# --------------------------------------------------------------- robot builder
def build_robot(kind):
    heavy = kind == 'heavy'
    S = 1.0 if not heavy else 1.16          # overall bulk
    H = 1.0 if not heavy else 1.18          # height factor
    armor = ARMOR if not heavy else PLATE
    plate = PLATE if not heavy else ARMOR
    accent = ACCENT if not heavy else ACCENT_GLOW
    visor_mat = VISOR if not heavy else VISOR_HEAVY
    root = make_empty('Juggernaut' if heavy else 'Sentinel', (0, 0, 0))

    # ---------------------------------------------------------------- legs
    hip_x = 0.13 * S
    hip_z = 0.92 * H
    knee_z = 0.49 * H
    ankle_z = 0.13 * H
    hip_pos_l = (-hip_x, 0.0, hip_z)
    hip_pos_r = (hip_x, 0.0, hip_z)
    knee_l = (-hip_x * 1.03, 0.02, knee_z)
    knee_r = (hip_x * 1.03, 0.02, knee_z)
    ankle_l = (-hip_x * 1.02, 0.0, ankle_z)
    ankle_r = (hip_x * 1.02, 0.0, ankle_z)

    for side, hip, knee, ankle in (('L', hip_pos_l, knee_l, ankle_l),
                                   ('R', hip_pos_r, knee_r, ankle_r)):
        thigh = []
        thigh.append(add_cyl(f'Thigh_{side}', hip, knee, 0.095 * S, 0.080 * S, JOINT))
        thigh.append(add_box(f'ThighArmor_{side}',
                             ((hip[0] + knee[0]) / 2, 0.01, (hip[2] + knee[2]) / 2 + 0.01),
                             (0.19 * S, 0.20 * S, 0.30 * H), armor, bevel=0.02))
        thigh.append(add_box(f'ThighStripe_{side}',
                             (hip[0] + (0.065 * S if side == 'R' else -0.065 * S), 0.095,
                              (hip[2] + knee[2]) / 2 + 0.015),
                             (0.035, 0.012, 0.16), accent, bevel=0.004))
        thigh_obj = apply_modifiers_and_join(thigh, f'Thigh{side}', hip)
        parent_keep(thigh_obj, root)

        shin = []
        shin.append(add_cyl(f'Shin_{side}', knee, ankle, 0.078 * S, 0.060 * S, JOINT))
        shin.append(add_box(f'ShinArmor_{side}',
                            ((knee[0] + ankle[0]) / 2, 0.015, (knee[2] + ankle[2]) / 2),
                            (0.17 * S, 0.18 * S, 0.30 * H), armor, bevel=0.018))
        shin.append(add_box(f'KneeCap_{side}', (knee[0], 0.105, knee[2]),
                            (0.15 * S, 0.06, 0.13), plate, bevel=0.025))
        shin.append(add_box(f'Foot_{side}', (ankle[0], 0.075, 0.055 * H),
                            (0.17 * S, 0.30, 0.11 * H), armor, bevel=0.022))
        shin.append(add_box(f'Toe_{side}', (ankle[0], 0.18, 0.045 * H),
                            (0.15 * S, 0.10, 0.07), plate, bevel=0.018))
        shin_obj = apply_modifiers_and_join(shin, f'Shin{side}', knee)
        parent_keep(shin_obj, thigh_obj)

    # ---------------------------------------------------------------- pelvis
    pelvis = add_box('Pelvis', (0, 0, 0.99 * H), (0.34 * S, 0.24 * S, 0.20), armor,
                     bevel=0.025)
    apply_modifiers_and_join([pelvis], 'Pelvis', (0, 0, 0.99 * H))
    pelvis_obj = bpy.data.objects['Pelvis']
    parent_keep(pelvis_obj, root)

    # ---------------------------------------------------------------- upper
    waist = make_empty('Upper', (0, 0, 0.99 * H), root)
    torso = []
    torso.append(add_box('Torso', (0, 0, 1.26 * H), (0.42 * S, 0.26 * S, 0.40), armor,
                         bevel=0.03))
    torso.append(add_box('ChestPlate', (0, 0.115 * S, 1.31 * H),
                         (0.34 * S, 0.08, 0.26), plate, bevel=0.025))
    torso.append(add_box('ChestStripe', (0, 0.165 * S, 1.38 * H),
                         (0.16 * S, 0.012, 0.035), accent, bevel=0.004))
    torso.append(add_box('Collar', (0, 0.0, 1.47 * H), (0.30 * S, 0.22 * S, 0.08), plate,
                         bevel=0.018))
    torso.append(add_box('Backpack', (0, -0.18 * S, 1.29 * H),
                         (0.30 * S, 0.14, 0.28), armor, bevel=0.022))
    torso.append(add_cyl('Core', (0, -0.255 * S, 1.29 * H), (0, -0.30 * S, 1.29 * H),
                         0.085 * S, 0.085 * S, accent, verts=18))
    torso.append(add_box('Waist', (0, 0, 1.03 * H), (0.26 * S, 0.20 * S, 0.10), JOINT,
                         bevel=0.018))
    torso_obj = apply_modifiers_and_join(torso, 'Torso', (0, 0, 1.06 * H))
    parent_keep(torso_obj, waist)

    # ---------------------------------------------------------------- head
    head = []
    head.append(add_box('Head', (0, 0, 1.66 * H), (0.23, 0.25, 0.21), armor,
                        bevel=0.03))
    head.append(add_box('Face', (0, 0.125, 1.655 * H), (0.19, 0.035, 0.15), JOINT,
                        bevel=0.012))
    head.append(add_box('Visor', (0, 0.147, 1.68 * H), (0.17, 0.015, 0.055), visor_mat,
                        bevel=0.012))
    head.append(add_box('Brow', (0, 0.11, 1.755 * H), (0.24, 0.10, 0.055), plate,
                        bevel=0.012))
    head.append(add_cyl('Antenna', (0.085, -0.05, 1.76 * H), (0.11, -0.08, 1.91 * H),
                        0.012, 0.006, JOINT, verts=8))
    head.append(add_box('Jaw', (0, 0.09, 1.585 * H), (0.16, 0.06, 0.05), plate,
                        bevel=0.01))
    head_obj = apply_modifiers_and_join(head, 'Head', (0, 0, 1.545 * H))
    parent_keep(head_obj, waist)

    # ---------------------------------------------------------------- arms
    shoulder_z = 1.42 * H
    arm_data = {
        'R': {'shoulder': (0.29 * S, 0, shoulder_z),
              'elbow': (0.35 * S, 0.10, 1.20 * H),
              'wrist': (0.20 * S, 0.28 * S, 1.21 * H)},
        'L': {'shoulder': (-0.29 * S, 0, shoulder_z),
              'elbow': (-0.35 * S, 0.12, 1.17 * H),
              'wrist': (-0.05 * S, 0.34 * S, 1.23 * H)},
    }
    arm_objs = {}
    for side, data in arm_data.items():
        sh, el, wr = Vector(data['shoulder']), Vector(data['elbow']), Vector(data['wrist'])
        parts = []
        parts.append(add_sphere(f'ShoulderBall_{side}', sh, 0.105 * S, JOINT,
                                scale=(1.0, 1.0, 0.9)))
        parts.append(add_cyl(f'UpperArm_{side}', sh, el, 0.075 * S, 0.062 * S, JOINT))
        parts.append(add_box(f'UpperArmArmor_{side}',
                             (sh + el) * 0.5 + Vector((0.035 * (1 if side == 'R' else -1), 0.0, 0.02)),
                             (0.12 * S, 0.14 * S, (sh - el).length * 0.85), armor,
                             bevel=0.018))
        parts.append(add_sphere(f'Elbow_{side}', el, 0.072 * S, JOINT))
        parts.append(add_cyl(f'Forearm_{side}', el, wr, 0.060 * S, 0.048 * S, JOINT))
        parts.append(add_box(f'ForearmArmor_{side}', (el + wr) * 0.5,
                             (0.11 * S, 0.11 * S, (el - wr).length * 0.82), plate,
                             bevel=0.016))
        hand = wr + (wr - el).normalized() * 0.055
        parts.append(add_box(f'Hand_{side}', hand, (0.085 * S, 0.10 * S, 0.075),
                             JOINT, bevel=0.015))
        # Shoulder pad, a strong silhouette cue.
        pad_pos = sh + Vector((0.0, 0.0, 0.055))
        parts.append(add_box(f'ShoulderPad_{side}', pad_pos,
                             (0.19 * S, 0.24 * S, 0.15), armor, bevel=0.025))
        parts.append(add_box(f'ShoulderStripe_{side}',
                             sh + Vector((0.075 * (1 if side == 'R' else -1), 0.0, 0.075)),
                             (0.025, 0.15 * S, 0.04), accent, bevel=0.004))
        obj = apply_modifiers_and_join(parts, f'Arm{side}', data['shoulder'])
        parent_keep(obj, waist)
        arm_objs[side] = obj

    # ---------------------------------------------------------------- weapon
    if not heavy:
        grip = Vector((0.20 * S, 0.28 * S, 1.21 * H))
        gun = []
        gun.append(add_box('GunBody', grip + Vector((0, 0.12, 0.02)),
                           (0.085, 0.42, 0.11), JOINT, bevel=0.012))
        gun.append(add_box('GunPlate', grip + Vector((0, 0.12, 0.075)),
                           (0.07, 0.30, 0.03), PLATE, bevel=0.006))
        gun.append(add_cyl('GunBarrel', grip + Vector((0, 0.30, 0.02)),
                           grip + Vector((0, 0.52, 0.02)), 0.025, 0.022, PLATE, verts=12))
        gun.append(add_cyl('GunMuzzle', grip + Vector((0, 0.52, 0.02)),
                           grip + Vector((0, 0.56, 0.02)), 0.034, 0.030, JOINT, verts=12))
        gun.append(add_box('GunMag', grip + Vector((0, 0.04, -0.09)),
                           (0.06, 0.10, 0.17), JOINT, bevel=0.01,
                           rot=(math.radians(12), 0, 0)))
        gun.append(add_box('GunStock', grip + Vector((0, -0.18, 0.0)),
                           (0.06, 0.16, 0.08), PLATE, bevel=0.012))
        gun.append(add_box('GunGlow', grip + Vector((0, 0.16, 0.085)),
                           (0.02, 0.18, 0.012), ACCENT_GLOW, bevel=0.002))
        gun_obj = apply_modifiers_and_join(gun, 'Gun', tuple(grip))
        parent_keep(gun_obj, waist)
        muzzle = make_empty('Muzzle', tuple(grip + Vector((0, 0.58, 0.02))), gun_obj)
        # Empty is already positioned in world; parent_keep via make_empty keeps it.
    else:
        # Twin shoulder cannons.
        gun = []
        for i, x in enumerate((-0.19, 0.19)):
            base = Vector((x * S, 0.20 * S, 1.44 * H))
            gun.append(add_box(f'CannonBody_{i}', base + Vector((0, 0.10, 0)),
                               (0.13, 0.42, 0.14), PLATE, bevel=0.018))
            gun.append(add_cyl(f'CannonBarrel_{i}', base + Vector((0, 0.30, 0)),
                               base + Vector((0, 0.62, 0)), 0.055, 0.045, JOINT, verts=14))
            gun.append(add_cyl(f'CannonRing_{i}', base + Vector((0, 0.55, 0)),
                               base + Vector((0, 0.60, 0)), 0.068, 0.068, ACCENT_GLOW, verts=14))
            gun.append(add_box(f'CannonMount_{i}', base + Vector((0, -0.03, -0.08)),
                               (0.10, 0.18, 0.16), JOINT, bevel=0.015))
        gun_obj = apply_modifiers_and_join(gun, 'Gun', (0, 0, 1.0))
        parent_keep(gun_obj, waist)
        for i, x in enumerate((-0.19, 0.19)):
            make_empty(f'Muzzle' if i == 0 else f'Muzzle{i}', (x * S, 0.82 * S, 1.44 * H), gun_obj)

    # ------------------------------------------------------------- decoration
    # Hazard markings on the chest and shoulders.
    deco = []
    deco.append(add_box('ChestMark', (0.0, 0.168 * S, 1.24 * H),
                        (0.09, 0.008, 0.018), WHITE, bevel=0.002))
    deco.append(add_box('ChestMark2', (0.0, 0.168 * S, 1.205 * H),
                        (0.06, 0.008, 0.012), WHITE, bevel=0.002))
    apply_modifiers_and_join(deco, 'Markings', (0, 0, 1.24 * H))
    markings = bpy.data.objects['Markings']
    parent_keep(markings, waist)

    # Root-level metadata as custom properties.
    root['kind'] = kind
    root['height'] = 1.85 if not heavy else 2.20
    return root

# --------------------------------------------------------------------- build
for kind in ('scout', 'heavy'):
    # Remove leftovers from the previous robot, keep materials.
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    PARTS.clear()
    root = build_robot(kind)
    name = 'sentinel' if kind == 'scout' else 'juggernaut'
    out = os.path.join(MODELS, name + '.glb')
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for o in root.children_recursive:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=out, export_format='GLB', use_selection=True,
        export_apply=True, export_yup=True, export_animations=False,
        export_cameras=False, export_lights=False, export_extras=True,
    )
    print('EXPORTED', out, os.path.getsize(out))

    # Preview camera and lights.
    bpy.ops.object.camera_add(location=(2.25, -3.1, 1.75))
    cam = bpy.context.object
    cam.data.lens = 55
    cam.rotation_euler = (Vector((0, 0, 1.0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = cam
    for loc, energy, size in (((2.0, -2.2, 3.1), 320, 2.0),
                              ((-2.4, -1.4, 1.8), 160, 2.0),
                              ((0.3, 2.6, 2.0), 220, 1.5)):
        bpy.ops.object.light_add(type='AREA', location=loc)
        light = bpy.context.object
        light.data.energy = energy
        light.data.size = size
        light.rotation_euler = (Vector((0, 0, 1.0)) - light.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = os.path.join(ROOT, f'enemy_{kind}_preview.png')
    bpy.ops.render.render(write_still=True)
    print('PREVIEW', scene.render.filepath)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, 'enemies_work.blend'))
print('DONE')
