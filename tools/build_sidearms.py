"""Build pistols and knives for RUBEZH // СЕКТОР 7.

Run:  ~/.local/bin/blender -b --python tools/build_sidearms.py

Exports to godot_project/assets/models/:
    pistol_pm9.glb, pistol_cobalt.glb, knife_klin.glb, knife_stiletto.glb
Preview: sidearms_preview.png

Convention: barrel/blade points along local -X (same as ak47_fps.glb),
Godot rotates the model -90 degrees around Y to make it point down -Z.
"""
import math
import os

import bpy
from mathutils import Vector, Euler

ROOT = "/home/ruzik-admin/Документы/Проект по умолчанию"
MODELS = os.path.join(ROOT, "godot_project/assets/models")
os.makedirs(MODELS, exist_ok=True)

# ------------------------------------------------------------------ clean
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

scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
try:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.world.color = (0.015, 0.018, 0.024)


# ------------------------------------------------------------------ materials
def mat(name, rgb, metallic=0.0, rough=0.6, emission=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        try:
            bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
            bsdf.inputs["Emission Strength"].default_value = strength
        except Exception:
            pass
    return m


STEEL = mat("steel_satin", (0.36, 0.39, 0.42), 0.85, 0.32)
GUNMETAL = mat("gunmetal_dark", (0.09, 0.105, 0.12), 0.75, 0.38)
POLYMER = mat("polymer_black", (0.055, 0.06, 0.065), 0.05, 0.82)
POLYMER_GREY = mat("polymer_grey", (0.17, 0.19, 0.21), 0.08, 0.76)
WOOD = mat("wood_walnut", (0.29, 0.15, 0.07), 0.0, 0.68)
BRASS = mat("brass", (0.68, 0.48, 0.16), 0.9, 0.26)
BLUE = mat("cobalt_blue", (0.06, 0.19, 0.38), 0.55, 0.3)
RED = mat("red_sight", (0.9, 0.08, 0.04), 0.2, 0.4, (1.0, 0.05, 0.02), 2.5)
BLADE = mat("blade_steel", (0.55, 0.6, 0.65), 0.95, 0.18)
LEATHER = mat("leather", (0.12, 0.075, 0.045), 0.0, 0.88)


# ------------------------------------------------------------------ helpers
def finish(ob, material, bevel=0.0, segments=2):
    if material:
        ob.data.materials.append(material)
    if bevel > 0:
        mod = ob.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.affect = "EDGES"
    return ob


def box(name, loc, size, material, bevel=0.0, rot=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.scale = size
    ob.rotation_euler = rot
    if parent:
        ob.parent = parent
    finish(ob, material, bevel)
    return ob


def cyl(name, loc, radius, depth, material, verts=16, rot=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.rotation_euler = rot
    if parent:
        ob.parent = parent
    finish(ob, material, 0.0)
    return ob


def cone(name, loc, r1, r2, depth, material, verts=4, rot=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.rotation_euler = rot
    if parent:
        ob.parent = parent
    finish(ob, material, 0.0)
    return ob


def root(name):
    ob = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(ob)
    return ob


def export(ob, filename):
    bpy.ops.object.select_all(action="DESELECT")
    members = [ob]
    stack = list(ob.children)
    while stack:
        child = stack.pop()
        members.append(child)
        stack.extend(child.children)
    for member in members:
        member.select_set(True)
    bpy.context.view_layer.objects.active = ob
    path = os.path.join(MODELS, filename)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_extras=True,
    )
    print("EXPORTED", path, os.path.getsize(path))


# ================================================================== PM-9
# Compact 9 mm service pistol. Overall length ~0.20 m, barrel along -X.
g = root("Pistol_PM9")
frame = box("Frame", (-0.005, 0, 0.0), (0.165, 0.032, 0.042), POLYMER, 0.006, parent=g)
slide = root("Slide")
slide.parent = g
box("SlideBody", (-0.012, 0, 0.020), (0.190, 0.036, 0.030), GUNMETAL, 0.004, parent=slide)
box("SlideTop", (-0.010, 0, 0.037), (0.150, 0.030, 0.006), STEEL, 0.002, parent=slide)
box("MuzzleRing", (-0.106, 0, 0.020), (0.012, 0.032, 0.028), STEEL, 0.002, parent=slide)
cyl("Barrel", (-0.104, 0, 0.020), 0.009, 0.014, STEEL, rot=(0, math.pi / 2, 0), parent=slide)
# ejection port
box("Port", (-0.028, 0.016, 0.029), (0.035, 0.006, 0.010), POLYMER, 0.001, parent=slide)
# front / rear sights
box("FrontSight", (-0.088, 0, 0.048), (0.008, 0.008, 0.010), POLYMER, 0.001, parent=slide)
box("RearSight", (0.060, 0, 0.047), (0.010, 0.026, 0.010), POLYMER, 0.001, parent=slide)
box("SightDot", (-0.088, 0, 0.053), (0.004, 0.005, 0.003), RED, 0.0, parent=slide)
# grip, angled back
grip = box("Grip", (0.058, 0, -0.064), (0.040, 0.033, 0.108), POLYMER, 0.008,
           rot=(math.radians(-14), 0, 0), parent=g)
box("GripPanelL", (0.058, -0.018, -0.064), (0.034, 0.004, 0.086), POLYMER_GREY, 0.003,
    rot=(math.radians(-14), 0, 0), parent=g)
box("GripPanelR", (0.058, 0.018, -0.064), (0.034, 0.004, 0.086), POLYMER_GREY, 0.003,
    rot=(math.radians(-14), 0, 0), parent=g)
# trigger guard + trigger
box("GuardTop", (0.030, 0, -0.023), (0.045, 0.020, 0.006), POLYMER, 0.002, parent=g)
box("GuardFront", (0.009, 0, -0.036), (0.006, 0.020, 0.028), POLYMER, 0.002, parent=g)
box("GuardBack", (0.051, 0, -0.036), (0.006, 0.020, 0.028), POLYMER, 0.002, parent=g)
box("Trigger", (0.030, 0, -0.030), (0.006, 0.008, 0.020), STEEL, 0.001, parent=g)
# magazine + baseplate
mag = root("Magazine")
mag.parent = g
box("MagBody", (0.058, 0, -0.112), (0.030, 0.026, 0.026), GUNMETAL, 0.002, parent=mag)
box("MagPlate", (0.058, 0, -0.128), (0.034, 0.030, 0.008), POLYMER, 0.002, parent=mag)
box("SlideStop", (0.020, 0.019, -0.010), (0.020, 0.004, 0.008), STEEL, 0.001, parent=g)
export(g, "pistol_pm9.glb")


# ================================================================== COBALT
# Heavy .45 platform with compensator and cobalt-blue receiver accents.
g = root("Pistol_Cobalt")
box("Frame", (0.0, 0, 0.0), (0.185, 0.038, 0.050), POLYMER, 0.007, parent=g)
slide = root("Slide")
slide.parent = g
box("SlideBody", (-0.010, 0, 0.026), (0.225, 0.042, 0.036), GUNMETAL, 0.005, parent=slide)
box("SlideTop", (-0.010, 0, 0.046), (0.180, 0.034, 0.006), STEEL, 0.002, parent=slide)
box("AccentL", (-0.005, -0.022, 0.026), (0.150, 0.004, 0.026), BLUE, 0.001, parent=slide)
box("AccentR", (-0.005, 0.022, 0.026), (0.150, 0.004, 0.026), BLUE, 0.001, parent=slide)
box("MuzzleRing", (-0.123, 0, 0.026), (0.014, 0.038, 0.034), STEEL, 0.002, parent=slide)
cyl("Barrel", (-0.122, 0, 0.026), 0.011, 0.016, STEEL, rot=(0, math.pi / 2, 0), parent=slide)
# compensator ports
for yy in (-0.013, 0.013):
    box("CompPort", (-0.116, yy, 0.048), (0.026, 0.010, 0.004), POLYMER, 0.0, parent=slide)
box("Port", (-0.030, 0.020, 0.035), (0.038, 0.006, 0.010), POLYMER, 0.001, parent=slide)
box("FrontSight", (-0.100, 0, 0.058), (0.008, 0.010, 0.014), POLYMER, 0.001, parent=slide)
box("RearSight", (0.074, 0, 0.056), (0.012, 0.032, 0.012), POLYMER, 0.001, parent=slide)
box("SightDot", (-0.100, 0, 0.065), (0.004, 0.006, 0.003), RED, 0.0, parent=slide)
box("Grip", (0.072, 0, -0.074), (0.046, 0.038, 0.124), POLYMER, 0.009,
    rot=(math.radians(-16), 0, 0), parent=g)
box("GripPanelL", (0.072, -0.020, -0.074), (0.038, 0.004, 0.100), LEATHER, 0.003,
    rot=(math.radians(-16), 0, 0), parent=g)
box("GripPanelR", (0.072, 0.020, -0.074), (0.038, 0.004, 0.100), LEATHER, 0.003,
    rot=(math.radians(-16), 0, 0), parent=g)
box("GuardTop", (0.040, 0, -0.028), (0.052, 0.024, 0.006), POLYMER, 0.002, parent=g)
box("GuardFront", (0.014, 0, -0.044), (0.006, 0.024, 0.032), POLYMER, 0.002, parent=g)
box("GuardBack", (0.066, 0, -0.044), (0.006, 0.024, 0.032), POLYMER, 0.002, parent=g)
box("Trigger", (0.040, 0, -0.036), (0.006, 0.009, 0.024), STEEL, 0.001, parent=g)
mag = root("Magazine")
mag.parent = g
box("MagBody", (0.072, 0, -0.132), (0.034, 0.030, 0.028), GUNMETAL, 0.002, parent=mag)
box("MagPlate", (0.072, 0, -0.150), (0.040, 0.036, 0.010), POLYMER, 0.002, parent=mag)
box("Hammer", (0.095, 0, 0.010), (0.014, 0.022, 0.018), STEEL, 0.002, parent=g)
export(g, "pistol_cobalt.glb")


# ================================================================== KLIN
# Compact military knife with a 0.16 m drop-point blade.
g = root("Knife_Klin")
handle = box("Handle", (0.075, 0, 0.0), (0.125, 0.022, 0.028), POLYMER, 0.006, parent=g)
for i in range(5):
    box("GripGroove", (0.045 + i * 0.014, 0, 0.0), (0.004, 0.024, 0.030), LEATHER, 0.0, parent=g)
box("GuardFront", (0.014, 0, 0.0), (0.010, 0.040, 0.034), STEEL, 0.003, parent=g)
box("GuardBack", (0.135, 0, 0.0), (0.012, 0.036, 0.032), STEEL, 0.003, parent=g)
# blade: tapered wedge pointing -X
blade = root("Blade")
blade.parent = g
box("BladeRoot", (-0.035, 0, 0.0), (0.100, 0.006, 0.032), BLADE, 0.001, parent=blade)
cone("BladeTip", (-0.105, 0, 0.004), 0.016, 0.0, 0.065, BLADE, verts=4,
     rot=(math.pi / 2, 0, math.pi / 4), parent=blade)
box("Fuller", (-0.040, 0.0035, 0.012), (0.070, 0.002, 0.004), GUNMETAL, 0.0, parent=blade)
box("Pommel", (0.142, 0, 0.0), (0.016, 0.030, 0.036), STEEL, 0.003, parent=g)
export(g, "knife_klin.glb")


# ================================================================== STILETTO
# Long, thin armor-piercing dagger with a crossguard.
g = root("Knife_Stiletto")
box("Handle", (0.105, 0, 0.0), (0.160, 0.020, 0.024), LEATHER, 0.005, parent=g)
for i in range(6):
    ring = cyl("Wrap", (0.050 + i * 0.020, 0, 0.0), 0.013, 0.004, POLYMER, verts=12,
               rot=(0, math.pi / 2, 0), parent=g)
box("Guard", (0.024, 0, 0.0), (0.010, 0.072, 0.010), STEEL, 0.002, parent=g)
box("GuardL", (0.024, -0.034, 0.0), (0.010, 0.014, 0.018), BRASS, 0.002, parent=g)
box("GuardR", (0.024, 0.034, 0.0), (0.010, 0.014, 0.018), BRASS, 0.002, parent=g)
blade = root("Blade")
blade.parent = g
box("BladeRoot", (-0.050, 0, 0.0), (0.150, 0.004, 0.014), BLADE, 0.001, parent=blade)
cone("BladeTip", (-0.152, 0, 0.0), 0.008, 0.0, 0.075, BLADE, verts=4,
     rot=(math.pi / 2, 0, math.pi / 4), parent=blade)
box("Ridge", (-0.055, 0.0025, 0.0), (0.130, 0.002, 0.004), STEEL, 0.0, parent=blade)
box("Pommel", (0.190, 0, 0.0), (0.018, 0.028, 0.030), BRASS, 0.003, parent=g)
export(g, "knife_stiletto.glb")


# ================================================================== preview
# Lay the four models out side by side and render a studio preview.
bpy.ops.object.select_all(action="DESELECT")
try:
    bpy.ops.object.camera_add(location=(0.0, -0.85, 0.42))
    cam = bpy.context.object
    cam.rotation_euler = (math.radians(72), 0, 0)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 0.98
    scene.camera = cam
except Exception as exc:
    print("camera setup failed", exc)

try:
    bpy.ops.object.light_add(type="AREA", location=(-0.2, -0.45, 0.65))
    key = bpy.context.object
    key.data.energy = 320
    key.data.shape = "RECTANGLE"
    key.data.size = 0.9
    key.data.size_y = 0.6
    key.rotation_euler = (math.radians(35), 0, math.radians(-15))
    bpy.ops.object.light_add(type="AREA", location=(0.35, 0.25, 0.5))
    fill = bpy.context.object
    fill.data.energy = 160
    fill.data.size = 0.7
except Exception as exc:
    print("light setup failed", exc)

# shift each model into a row using its root object
placements = [("Pistol_PM9", -0.36, 0.10), ("Pistol_Cobalt", -0.12, 0.10),
              ("Knife_Klin", 0.12, 0.10), ("Knife_Stiletto", 0.36, 0.10)]
for name, x, z in placements:
    ob = bpy.data.objects.get(name)
    if ob:
        ob.location = (x, 0, z)

scene.render.filepath = os.path.join(ROOT, "sidearms_preview.png")
scene.render.image_settings.file_format = "PNG"
bpy.ops.render.render(write_still=True)
print("PREVIEW", scene.render.filepath)
