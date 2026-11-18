"""Extra Blender props and shop icons for RUBEZH // СЕКТОР 7.

Run: ~/.local/bin/blender -b --python tools/build_arena_expansion.py

Exports GLB -> godot_project/assets/models/:
    watchtower.glb, fuel_tank.glb, block_large.glb, radar_dish.glb, shop_terminal.glb
Renders shop icons -> godot_project/assets/textures/:
    shop_ak.png, shop_pistol.png, shop_knife.png
"""
import math
import os

import bpy
from mathutils import Vector

ROOT = "/home/ruzik-admin/Документы/Проект по умолчанию"
MODELS = os.path.join(ROOT, "godot_project/assets/models")
TEX = os.path.join(ROOT, "godot_project/assets/textures")
os.makedirs(MODELS, exist_ok=True)
os.makedirs(TEX, exist_ok=True)


def clean():
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials):
        if block.users == 0:
            bpy.data.materials.remove(block)


clean()
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
try:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.world.color = (0.014, 0.017, 0.022)


def mat(name, rgb, metallic=0.0, rough=0.7, emission=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    if emission:
        try:
            b.inputs["Emission Color"].default_value = (*emission, 1.0)
            b.inputs["Emission Strength"].default_value = strength
        except Exception:
            pass
    return m


STEEL = mat("steel", (0.32, 0.36, 0.40), 0.8, 0.4)
DARK = mat("dark_steel", (0.08, 0.095, 0.11), 0.7, 0.5)
CONCRETE = mat("concrete", (0.46, 0.47, 0.45), 0.0, 0.95)
RUST = mat("rust", (0.36, 0.17, 0.08), 0.25, 0.85)
HAZARD = mat("hazard", (0.85, 0.58, 0.10), 0.1, 0.7)
AMBER = mat("amber_glow", (1.0, 0.58, 0.12), 0.0, 0.4, (1.0, 0.4, 0.05), 3.0)
TEAL = mat("teal_glow", (0.2, 0.9, 0.85), 0.0, 0.4, (0.1, 0.9, 0.8), 2.5)


def box(name, loc, size, material, bevel=0.0, rot=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = size
    o.rotation_euler = rot
    if parent:
        o.parent = parent
    if material:
        o.data.materials.append(material)
    if bevel:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = 2
    return o


def cyl(name, loc, r, h, material, verts=16, rot=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc)
    o = bpy.context.object
    o.name = name
    o.rotation_euler = rot
    if parent:
        o.parent = parent
    if material:
        o.data.materials.append(material)
    return o


def cone(name, loc, r1, r2, h, material, verts=16, rot=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=h, location=loc)
    o = bpy.context.object
    o.name = name
    o.rotation_euler = rot
    if parent:
        o.parent = parent
    if material:
        o.data.materials.append(material)
    return o


def root(name):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    return o


def export(o, filename):
    bpy.ops.object.select_all(action="DESELECT")
    members = [o]
    stack = list(o.children)
    while stack:
        c = stack.pop()
        members.append(c)
        stack.extend(c.children)
    for m in members:
        m.select_set(True)
    bpy.context.view_layer.objects.active = o
    p = os.path.join(MODELS, filename)
    bpy.ops.export_scene.gltf(filepath=p, export_format="GLB", use_selection=True,
                             export_apply=True, export_yup=True, export_cameras=False,
                             export_lights=False, export_extras=True)
    print("EXPORTED", filename, os.path.getsize(p))


# ============================================================ WATCHTOWER 5.6 m
g = root("Watchtower")
for sx in (-1, 1):
    for sy in (-1, 1):
        x, y = sx * 0.95, sy * 0.95
        leg = cyl("Leg", (x, y, 2.5), 0.065, 5.0, STEEL, verts=8)
        leg.parent = g
        leg.rotation_euler.y = math.radians(sx * 1.8)
        leg.rotation_euler.x = math.radians(-sy * 1.8)
        box("Foot", (x, y, 0.05), (0.32, 0.32, 0.10), DARK, 0.02, parent=g)
for z in (1.4, 3.0, 4.4):
    for sx in (-1, 1):
        box("Brace", (sx * 0.95, 0, z), (0.05, 1.9, 0.05), STEEL, parent=g)
        box("Brace", (0, sx * 0.95, z), (1.9, 0.05, 0.05), STEEL, parent=g)
box("Deck", (0, 0, 4.98), (2.5, 2.5, 0.14), DARK, 0.02, parent=g)
box("DeckEdge", (0, 0, 5.08), (2.7, 2.7, 0.06), HAZARD, 0.01, parent=g)
for sx in (-1, 1):
    box("Rail", (sx * 1.22, 0, 5.55), (0.06, 2.5, 0.06), STEEL, parent=g)
    box("Rail", (0, sx * 1.22, 5.55), (2.5, 0.06, 0.06), STEEL, parent=g)
for dx in (-1, 1):
    for dy in (-1, 1):
        cyl("Post", (dx * 1.22, dy * 1.22, 5.3), 0.045, 0.62, STEEL, verts=8, parent=g)
# roof
box("Canopy", (0, 0, 6.15), (2.9, 2.9, 0.09), DARK, 0.02, parent=g)
for sx in (-1, 1):
    for sy in (-1, 1):
        cyl("RoofPost", (sx * 1.3, sy * 1.3, 5.65), 0.04, 0.9, STEEL, verts=8, parent=g)
# ladder
for sx in (-1, 1):
    box("LadderRail", (sx * 0.22, -1.02, 2.5), (0.04, 0.04, 5.0), STEEL, parent=g)
for i in range(11):
    box("Rung", (0, -1.02, 0.4 + i * 0.42), (0.44, 0.04, 0.04), STEEL, parent=g)
box("Beacon", (0, 0, 6.26), (0.14, 0.14, 0.12), AMBER, 0.02, parent=g)
export(g, "watchtower.glb")


# ============================================================ FUEL TANK 3.2 m
g = root("FuelTank")
cyl("Tank", (0, 0, 1.55), 1.18, 2.9, RUST, verts=24, parent=g)
cyl("Top", (0, 0, 3.05), 1.18, 0.10, STEEL, verts=24, parent=g)
for z in (0.55, 1.55, 2.55):
    cyl("Band", (0, 0, z), 1.21, 0.09, STEEL, verts=24, parent=g)
for i in range(12):
    a = i / 12 * math.tau
    box("Rib", (math.cos(a) * 1.19, math.sin(a) * 1.19, 1.55),
        (0.06, 0.06, 2.7), STEEL, parent=g, rot=(0, 0, a))
for sx in (-1, 1):
    box("Skid", (sx * 0.7, 0, 0.12), (0.24, 2.4, 0.24), DARK, 0.02, parent=g)
cyl("Valve", (0.6, 0.7, 3.18), 0.16, 0.22, STEEL, verts=12, parent=g)
cyl("Pipe", (0.6, 0.7, 2.2), 0.06, 1.9, STEEL, verts=10, parent=g)
box("HazardPlate", (0, -1.21, 1.7), (0.7, 0.04, 0.45), HAZARD, parent=g)
export(g, "fuel_tank.glb")


# ============================================================ BIG CONCRETE BLOCK
g = root("BlockLarge")
box("Body", (0, 0, 1.15), (2.6, 2.6, 2.3), CONCRETE, 0.04, parent=g)
box("Cap", (0, 0, 2.36), (2.75, 2.75, 0.12), DARK, 0.02, parent=g)
for sx in (-1, 1):
    for sy in (-1, 1):
        cyl("Rebar", (sx * 1.05, sy * 1.05, 2.58), 0.035, 0.42, STEEL, verts=8, parent=g)
for z in (0.45, 1.85):
    box("Stripe", (0, -1.31, z), (2.3, 0.03, 0.14), HAZARD, parent=g)
export(g, "block_large.glb")


# ============================================================ RADAR DISH
g = root("RadarDish")
cyl("Base", (0, 0, 0.18), 0.55, 0.36, DARK, verts=12, parent=g)
cyl("Mast", (0, 0, 1.9), 0.10, 3.4, STEEL, verts=10, parent=g)
for z in (0.8, 1.7, 2.6):
    cyl("Collar", (0, 0, z), 0.16, 0.12, DARK, verts=10, parent=g)
dish = cone("Dish", (0, 0, 3.9), 1.05, 0.18, 0.45, STEEL, verts=24,
            rot=(math.radians(28), 0, 0), parent=g)
cyl("Feed", (0, -0.35, 4.25), 0.045, 0.75, DARK, verts=8,
    rot=(math.radians(28), 0, 0), parent=g)
box("Panel", (0, 0.2, 2.4), (0.6, 0.12, 0.8), DARK, 0.02, parent=g)
box("PanelGlow", (0, 0.13, 2.4), (0.4, 0.02, 0.5), TEAL, parent=g)
export(g, "radar_dish.glb")


# ============================================================ SHOP TERMINAL
g = root("ShopTerminal")
box("Base", (0, 0, 0.45), (0.8, 0.55, 0.9), DARK, 0.04, parent=g)
box("Body", (0, 0, 1.15), (0.7, 0.45, 0.7), STEEL, 0.04, parent=g)
box("Screen", (0, -0.24, 1.25), (0.58, 0.04, 0.48), TEAL, 0.01, parent=g)
box("ScreenFrame", (0, -0.26, 1.25), (0.66, 0.03, 0.56), DARK, 0.01, parent=g)
box("Top", (0, 0, 1.55), (0.9, 0.6, 0.08), HAZARD, 0.02, parent=g)
cyl("Antenna", (0.25, 0.1, 1.85), 0.02, 0.55, STEEL, verts=8, parent=g)
box("Beacon", (0.25, 0.1, 2.14), (0.08, 0.08, 0.08), AMBER, parent=g)
export(g, "shop_terminal.glb")


# ============================================================ SHOP ICON RENDERS
scene.render.resolution_x = 520
scene.render.resolution_y = 300
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"

icons = [
    ("ak47_fps.glb", "shop_ak.png", 0.9, 1.5, (-0.3, -1.3, 0.9)),
    ("pistol_pm9.glb", "shop_pistol.png", 1.5, 1.0, (-0.05, -0.85, 0.55)),
    ("knife_klin.glb", "shop_knife.png", 1.6, 1.0, (-0.05, -0.85, 0.5)),
]

for glb, png, scale, ortho, camloc in icons:
    clean()
    path = os.path.join(MODELS, glb)
    if not os.path.exists(path):
        print("SKIP icon", glb)
        continue
    bpy.ops.import_scene.gltf(filepath=path)
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH":
            o.scale *= scale
    bpy.ops.object.camera_add(location=camloc)
    cam = bpy.context.object
    cam.rotation_euler = (math.radians(65), 0, 0)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    scene.camera = cam
    bpy.ops.object.light_add(type="AREA", location=(-0.3, -0.5, 1.1))
    key = bpy.context.object
    key.data.energy = 280
    key.data.size = 1.2
    key.rotation_euler = (math.radians(40), 0, math.radians(-20))
    bpy.ops.object.light_add(type="AREA", location=(0.4, 0.4, 0.8))
    fill = bpy.context.object
    fill.data.energy = 130
    fill.data.size = 1.0
    scene.render.filepath = os.path.join(TEX, png)
    bpy.ops.render.render(write_still=True)
    print("ICON", png)
