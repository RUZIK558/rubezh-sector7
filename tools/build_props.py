"""Build arena props for RUBEZH // SECTOR 7.

Run inside Blender (GUI, MCP):
    exec(compile(open('/home/ruzik-admin/Документы/Проект по умолчанию/tools/build_props.py', encoding='utf-8').read(), 'build_props.py', 'exec'))

Exports to godot_project/assets/models/:
    crate.glb, barrel.glb, barrel_explosive.glb, barrier.glb, container.glb,
    sandbags.glb, lightpost.glb, pickup_ammo.glb, pickup_med.glb,
    platform.glb, ramp.glb, gate.glb
Preview: props_preview.png
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
scene.render.resolution_x = 1500
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'Medium High Contrast'
scene.world.color = (0.012, 0.014, 0.018)

# ------------------------------------------------------------------ materials
def make_mat(name, rgb, metallic=0.0, roughness=0.6, emission=None, strength=0.0):
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

M = {}
M['wood'] = make_mat('Wood', (0.30, 0.17, 0.085), 0.0, 0.78)
M['wood_dark'] = make_mat('WoodDark', (0.15, 0.085, 0.045), 0.0, 0.82)
M['metal'] = make_mat('MetalDark', (0.075, 0.085, 0.095), 0.75, 0.42)
M['steel'] = make_mat('Steel', (0.36, 0.39, 0.42), 0.85, 0.34)
M['rust'] = make_mat('Rust', (0.30, 0.13, 0.065), 0.15, 0.82)
M['concrete'] = make_mat('Concrete', (0.31, 0.31, 0.30), 0.0, 0.92)
M['concrete_dark'] = make_mat('ConcreteDark', (0.18, 0.18, 0.18), 0.0, 0.95)
M['yellow'] = make_mat('HazardYellow', (0.78, 0.48, 0.045), 0.0, 0.62)
M['black'] = make_mat('Rubber', (0.022, 0.022, 0.024), 0.0, 0.9)
M['olive'] = make_mat('Olive', (0.13, 0.17, 0.09), 0.1, 0.72)
M['red'] = make_mat('RedPaint', (0.52, 0.045, 0.035), 0.1, 0.55)
M['white'] = make_mat('WhitePaint', (0.80, 0.81, 0.78), 0.0, 0.55)
M['teal'] = make_mat('ContainerTeal', (0.075, 0.19, 0.19), 0.35, 0.62)
M['rust2'] = make_mat('ContainerRust', (0.36, 0.15, 0.07), 0.1, 0.8)
M['sand'] = make_mat('Sandbag', (0.36, 0.31, 0.19), 0.0, 0.95)
M['sand_dark'] = make_mat('SandbagDark', (0.25, 0.21, 0.12), 0.0, 0.95)
M['green_glow'] = make_mat('GreenGlow', (0.05, 0.55, 0.18), 0.0, 0.4, (0.12, 1.0, 0.35), 6.0)
M['red_glow'] = make_mat('RedGlow', (0.7, 0.03, 0.02), 0.0, 0.4, (1.0, 0.06, 0.03), 7.0)
M['warm'] = make_mat('LampWarm', (1.0, 0.72, 0.35), 0.0, 0.35, (1.0, 0.62, 0.24), 9.0)
M['white_glow'] = make_mat('WhiteGlow', (0.9, 0.95, 1.0), 0.0, 0.3, (0.75, 0.88, 1.0), 5.0)


def set_mat(ob, mat):
    ob.data.materials.clear()
    ob.data.materials.append(mat)


def apply_bevel(ob, width, segments=2, angle=0.6):
    if width <= 0:
        return
    mod = ob.modifiers.new('Bevel', 'BEVEL')
    mod.width = width
    mod.segments = segments
    mod.limit_method = 'ANGLE'
    mod.angle_limit = angle
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def box(name, loc, size, mat, bevel=0.015, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    ob = bpy.context.object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    apply_bevel(ob, bevel)
    set_mat(ob, mat)
    return ob


def cyl(name, loc, radius, depth, mat, rot=(0, 0, 0), verts=24, bevel=0.015):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth,
                                        location=loc, rotation=rot)
    ob = bpy.context.object
    ob.name = name
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    apply_bevel(ob, bevel)
    set_mat(ob, mat)
    return ob


def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.object
    ob.name = name
    ob.data.name = name + '_Mesh'
    return ob


def ground_origin(ob):
    """Bake transform and put the origin at ground level (mesh z >= 0)."""
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    zs = [v.co.z for v in ob.data.vertices]
    dz = min(zs) if zs else 0.0
    for v in ob.data.vertices:
        v.co.z -= dz
    ob.location = (0, 0, 0)
    return ob


def export(ob, filename, root_name=None):
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    path = os.path.join(MODELS, filename)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_extras=True,
    )
    print(f'EXPORTED {path} {os.path.getsize(path)}')


# ================================================================== props
built = []

# ------------------------------------------------------------------ crate 1.2 m
def build_crate():
    p = []
    p.append(box('CrateBody', (0, 0, 0.60), (1.18, 1.18, 1.16), M['wood'], 0.035))
    # plank seams
    for i, z in enumerate((0.24, 0.60, 0.96)):
        p.append(box(f'Plank{i}', (0.0, -0.595, z), (1.14, 0.035, 0.055), M['wood_dark'], 0.008))
        p.append(box(f'PlankB{i}', (0.0, 0.595, z), (1.14, 0.035, 0.055), M['wood_dark'], 0.008))
    # metal corner braces (vertical)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box(f'Brace{sx}{sy}', (sx * 0.555, sy * 0.555, 0.60),
                         (0.11, 0.11, 1.17), M['metal'], 0.012))
    # top and bottom rims
    for z in (0.065, 1.135):
        p.append(box(f'RimX{z}', (0, 0, z), (1.20, 0.10, 0.09), M['metal'], 0.01))
        p.append(box(f'RimY{z}', (0, 0, z), (0.10, 1.20, 0.09), M['metal'], 0.01))
    # stenciled hazard plate
    p.append(box('CratePlate', (0.0, -0.605, 0.72), (0.52, 0.03, 0.22), M['yellow'], 0.006))
    p.append(box('CratePlateIn', (0.0, -0.622, 0.72), (0.40, 0.012, 0.10), M['black'], 0.004))
    return join(p, 'crate')


# ------------------------------------------------------------------ barrel
def build_barrel(name, body_mat, glow_mat=None):
    p = []
    p.append(cyl('BarrelBody', (0, 0, 0.50), 0.37, 0.96, body_mat, verts=28, bevel=0.018))
    for z in (0.14, 0.50, 0.86):
        p.append(cyl(f'Ring{z}', (0, 0, z), 0.395, 0.065, M['metal'], verts=28, bevel=0.012))
    p.append(cyl('BarrelLid', (0, 0, 0.985), 0.34, 0.035, M['metal'], verts=28, bevel=0.01))
    p.append(cyl('BarrelCap', (0.14, 0.0, 1.005), 0.075, 0.04, M['rust'], verts=16, bevel=0.006))
    if glow_mat:
        # hazard band and glowing warning placard
        band = cyl('HazardBand', (0, 0, 0.68), 0.398, 0.20, M['yellow'], verts=28, bevel=0.0)
        p.append(band)
        p.append(box('BarrelMark', (0.0, -0.392, 0.68), (0.30, 0.03, 0.16), glow_mat, 0.006))
    return join(p, name)


# ------------------------------------------------------------------ jersey barrier
def build_barrier():
    p = []
    p.append(box('BarrierBase', (0, 0, 0.14), (2.40, 0.72, 0.28), M['concrete'], 0.03))
    p.append(box('BarrierMid', (0, 0, 0.42), (2.40, 0.46, 0.34), M['concrete'], 0.025))
    p.append(box('BarrierTop', (0, 0, 0.76), (2.40, 0.30, 0.40), M['concrete'], 0.025))
    # chipped top edge + hazard stripes
    for i in range(5):
        x = -0.92 + i * 0.46
        p.append(box(f'Stripe{i}', (x, -0.152, 0.80), (0.24, 0.012, 0.20), M['yellow'], 0.003))
    p.append(box('BarrierCap', (0, 0, 0.975), (2.42, 0.34, 0.05), M['concrete_dark'], 0.012))
    return join(p, 'barrier')


# ------------------------------------------------------------------ container
def build_container():
    L, W, H = 6.0, 2.44, 2.60
    p = []
    p.append(box('ContainerBody', (0, 0, H / 2), (L, W, H), M['teal'], 0.03))
    # corrugated ribs on long sides
    for side in (-1, 1):
        n = 15
        for i in range(n):
            x = -L / 2 + 0.2 + i * (L - 0.4) / (n - 1)
            p.append(box(f'Rib{side}_{i}', (x, side * (W / 2 + 0.035), H / 2),
                         (0.10, 0.07, H - 0.18), M['teal'], 0.012))
    # top/bottom rails
    for z in (0.10, H - 0.10):
        for side in (-1, 1):
            p.append(box(f'Rail{side}{z}', (0, side * (W / 2 + 0.03), z),
                         (L + 0.04, 0.10, 0.16), M['metal'], 0.01))
    # corner posts
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box(f'Post{sx}{sy}', (sx * (L / 2 - 0.02), sy * (W / 2 - 0.02), H / 2),
                         (0.18, 0.18, H), M['metal'], 0.015))
    # doors on the -X end
    for i, y in enumerate((-0.58, 0.58)):
        p.append(box(f'Door{i}', (-L / 2 - 0.035, y, H / 2), (0.05, 1.10, H - 0.30),
                     M['rust2'], 0.01))
        p.append(box(f'DoorBar{i}', (-L / 2 - 0.075, y, H / 2), (0.05, 0.08, H - 0.34),
                     M['metal'], 0.008))
    # locking bars
    for y in (-0.85, 0.0, 0.85):
        p.append(cyl(f'Lock{y}', (-L / 2 - 0.10, y, H / 2), 0.035, H - 0.40, M['steel'],
                     verts=10, bevel=0.0))
    # rust patch panels
    p.append(box('RustPanelA', (1.6, W / 2 + 0.08, 0.75), (1.1, 0.012, 0.9), M['rust2'], 0.002))
    p.append(box('RustPanelB', (-2.0, -W / 2 - 0.08, 1.8), (1.4, 0.012, 0.7), M['rust2'], 0.002))
    # hazard label
    p.append(box('ContMark', (-2.55, W / 2 + 0.082, 1.95), (0.5, 0.012, 0.3), M['yellow'], 0.002))
    return join(p, 'container')


# ------------------------------------------------------------------ sandbags
def build_sandbags():
    p = []
    rows = 4
    for r in range(rows):
        count = 6 if r % 2 == 0 else 5
        z = 0.14 + r * 0.27
        offset = 0.0 if r % 2 == 0 else 0.22
        for i in range(count):
            x = -1.10 + offset + i * 0.44
            jitter = 0.012 * ((i * 7 + r * 3) % 5 - 2)
            mat = M['sand'] if (i + r) % 3 else M['sand_dark']
            b = box(f'Bag{r}_{i}', (x, jitter, z), (0.42, 0.34, 0.25), mat, 0.055)
            b.rotation_euler = (0, 0, math.radians(jitter * 160))
            p.append(b)
    # side support bags
    p.append(box('EndL', (-1.32, 0, 0.55), (0.28, 0.46, 0.96), M['sand'], 0.06))
    p.append(box('EndR', (1.32, 0, 0.55), (0.28, 0.46, 0.96), M['sand'], 0.06))
    return join(p, 'sandbags')


# ------------------------------------------------------------------ lightpost
def build_lightpost():
    p = []
    p.append(box('LampBase', (0, 0, 0.10), (0.64, 0.64, 0.20), M['concrete_dark'], 0.03))
    p.append(cyl('LampMast', (0, 0, 3.10), 0.105, 6.00, M['metal'], verts=16, bevel=0.01))
    p.append(cyl('LampCollar', (0, 0, 0.42), 0.16, 0.30, M['steel'], verts=16, bevel=0.01))
    p.append(box('LampArm', (0.52, 0, 5.86), (1.05, 0.14, 0.14), M['metal'], 0.012))
    p.append(box('LampHead', (1.02, 0, 5.72), (0.62, 0.46, 0.26), M['metal'], 0.03))
    p.append(box('LampLens', (1.02, 0, 5.565), (0.52, 0.36, 0.035), M['warm'], 0.006))
    p.append(box('LampVisor', (1.02, 0, 5.90), (0.70, 0.50, 0.06), M['metal'], 0.012))
    # small junction box and cable
    p.append(box('LampBox', (0.0, -0.16, 1.20), (0.22, 0.16, 0.42), M['metal'], 0.01))
    return join(p, 'lightpost')


# ------------------------------------------------------------------ pickups
def build_pickup_ammo():
    p = []
    p.append(box('AmmoCase', (0, 0, 0.19), (0.58, 0.40, 0.30), M['olive'], 0.025))
    p.append(box('AmmoLid', (0, 0, 0.355), (0.60, 0.42, 0.055), M['metal'], 0.012))
    p.append(box('AmmoStripe', (0, -0.207, 0.19), (0.50, 0.012, 0.06), M['green_glow'], 0.002))
    p.append(box('AmmoLatch', (0.20, -0.21, 0.30), (0.10, 0.02, 0.07), M['steel'], 0.004))
    for i in range(4):
        p.append(cyl(f'Bullet{i}', (-0.15 + i * 0.10, 0.0, 0.40), 0.022, 0.10, M['yellow'],
                     verts=8, bevel=0.002))
    return join(p, 'pickup_ammo')


def build_pickup_med():
    p = []
    p.append(box('MedCase', (0, 0, 0.16), (0.52, 0.36, 0.28), M['white'], 0.03))
    p.append(box('MedLid', (0, 0, 0.315), (0.545, 0.385, 0.05), M['white'], 0.012))
    p.append(box('MedHandle', (0, 0, 0.365), (0.18, 0.06, 0.05), M['steel'], 0.008))
    p.append(box('CrossV', (0, 0, 0.348), (0.075, 0.26, 0.018), M['red'], 0.003))
    p.append(box('CrossH', (0, 0, 0.348), (0.26, 0.075, 0.018), M['red'], 0.003))
    p.append(box('MedGlow', (0, -0.183, 0.16), (0.36, 0.012, 0.035), M['white_glow'], 0.002))
    return join(p, 'pickup_med')


# ------------------------------------------------------------------ platform + ramp
def build_platform():
    p = []
    p.append(box('PlatformTop', (0, 0, 0.225), (6.0, 4.6, 0.45), M['concrete'], 0.03))
    p.append(box('PlatformLip', (0, 0, 0.43), (6.04, 4.64, 0.06), M['concrete_dark'], 0.012))
    # painted edge hazard
    for i in range(9):
        p.append(box(f'Edge{i}', (-2.6 + i * 0.65, -2.31, 0.30), (0.32, 0.03, 0.18),
                     M['yellow'], 0.004))
    # underside supports
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box(f'PlatLeg{sx}{sy}', (sx * 2.7, sy * 2.0, 0.11), (0.35, 0.35, 0.22),
                         M['concrete_dark'], 0.02))
    return join(p, 'platform')


def build_ramp():
    # solid concrete wedge rising from z=0 to H over L, width W
    W, L, H = 2.20, 1.80, 0.46
    verts = [(-W / 2, 0, 0), (W / 2, 0, 0), (W / 2, L, 0), (-W / 2, L, 0),
             (W / 2, L, H), (-W / 2, L, H)]
    faces = [(0, 3, 2, 1), (3, 5, 4, 2), (0, 1, 4, 5), (0, 5, 3), (1, 2, 4)]
    me = bpy.data.meshes.new('RampWedge')
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new('RampBody', me)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    apply_bevel(ob, 0.018)
    set_mat(ob, M['concrete'])
    p = [ob]
    # cross grip bars lying on the slope
    angle = math.atan2(H, L)
    for i in range(5):
        y = 0.28 + i * 0.30
        z = H * (y / L) + 0.012
        p.append(box(f'RampGrip{i}', (0, y, z), (2.02, 0.065, 0.026),
                     M['metal'], 0.004, rot=(-angle, 0, 0)))
    # hazard edge stripes on the high end
    for i in range(3):
        p.append(box(f'RampMark{i}', (-0.7 + i * 0.7, L - 0.05, H - 0.05),
                     (0.26, 0.03, 0.10), M['yellow'], 0.003))
    return join(p, 'ramp')


# ------------------------------------------------------------------ spawn gate
def build_gate():
    p = []
    p.append(box('GateTop', (0, 0, 3.55), (3.60, 0.42, 0.44), M['metal'], 0.025))
    for sx in (-1, 1):
        p.append(box(f'GatePost{sx}', (sx * 1.72, 0, 1.78), (0.42, 0.42, 3.56), M['metal'], 0.025))
        p.append(box(f'GateFoot{sx}', (sx * 1.72, 0, 0.10), (0.66, 0.80, 0.20), M['concrete_dark'], 0.02))
        p.append(box(f'GateGlow{sx}', (sx * 1.44, -0.225, 2.10), (0.10, 0.03, 1.55), M['red_glow'], 0.004))
    p.append(box('GateSign', (0, -0.24, 3.45), (1.30, 0.04, 0.30), M['yellow'], 0.005))
    p.append(box('GateSignIn', (0, -0.265, 3.45), (1.06, 0.02, 0.14), M['black'], 0.003))
    return join(p, 'gate')


builders = [
    (build_crate, 'crate.glb'),
    (lambda: build_barrel('barrel', M['rust']), 'barrel.glb'),
    (lambda: build_barrel('barrel_explosive', M['red'], M['red_glow']), 'barrel_explosive.glb'),
    (build_barrier, 'barrier.glb'),
    (build_container, 'container.glb'),
    (build_sandbags, 'sandbags.glb'),
    (build_lightpost, 'lightpost.glb'),
    (build_pickup_ammo, 'pickup_ammo.glb'),
    (build_pickup_med, 'pickup_med.glb'),
    (build_platform, 'platform.glb'),
    (build_ramp, 'ramp.glb'),
    (build_gate, 'gate.glb'),
]

for fn, filename in builders:
    ob = fn()
    ground_origin(ob)
    me = ob.data
    if len(me.vertices):
        zs = [v.co.z for v in me.vertices]
        xs = [v.co.x for v in me.vertices]
        ys = [v.co.y for v in me.vertices]
        print(f'BOUNDS {filename}: x {min(xs):.2f}..{max(xs):.2f} y {min(ys):.2f}..{max(ys):.2f} z {min(zs):.2f}..{max(zs):.2f}')
    export(ob, filename)
    built.append(ob)

# ------------------------------------------------------------------ preview
for ob in built:
    ob.hide_render = True
for ob in built:
    ob.hide_render = False
    ob.hide_set(True)

# Layout visible duplicates for preview only: re-show originals in a grid instead
for i, ob in enumerate(built):
    ob.hide_set(False)
    col = i % 4
    row = i // 4
    # container is large: give it its own row
    ob.location = (-8.5 + col * 5.6, 6.0 - row * 4.6, 0)
    if ob.name in ('container',):
        ob.location = (0, 10.5, 0)
    if ob.name in ('platform',):
        ob.location = (8.0, 9.0, 0)
    if ob.name in ('lightpost',):
        ob.location = (-9.0, 9.0, 0)
    if ob.name in ('gate',):
        ob.location = (9.3, -1.0, 0)
    if ob.name in ('barrier',):
        ob.location = (-8.6, -4.0, 0)

# lights
bpy.ops.object.light_add(type='AREA', location=(4, -10, 12))
key = bpy.context.object
key.data.energy = 2600
key.data.size = 9
key.rotation_euler = (math.radians(52), 0, math.radians(22))
bpy.ops.object.light_add(type='AREA', location=(-10, 2, 7))
fill = bpy.context.object
fill.data.energy = 1400
fill.data.size = 8
fill.data.color = (0.55, 0.68, 1.0)
fill.rotation_euler = (math.radians(70), 0, math.radians(-70))
bpy.ops.object.light_add(type='SUN', location=(0, 0, 20))
sun = bpy.context.object
sun.data.energy = 1.4
sun.rotation_euler = (math.radians(50), math.radians(-15), math.radians(120))

# ground
bpy.ops.mesh.primitive_plane_add(size=140, location=(0, 0, -0.01))
ground = bpy.context.object
set_mat(ground, make_mat('PreviewGround', (0.095, 0.098, 0.102), 0.0, 0.9))

bpy.ops.object.camera_add(location=(16.0, -21.5, 12.5))
cam = bpy.context.object
cam.data.lens = 38
scene.camera = cam
target = Vector((0, 1.5, 2.0))
direction = target - cam.location
cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

scene.render.filepath = os.path.join(ROOT, 'props_preview.png')
bpy.ops.render.render(write_still=True)
print('PREVIEW', scene.render.filepath)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, 'props_work.blend'))
print('DONE')
