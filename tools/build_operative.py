"""Build the player operative model for RUBEZH // СЕКТОР 7.

Visible on remote players in co-op; the local player stays first-person.
Run: ~/.local/bin/blender -b --python tools/build_operative.py
"""
import math, os
import bpy

ROOT = "/home/ruzik-admin/Документы/Проект по умолчанию"
OUT = os.path.join(ROOT, "godot_project/assets/models/operative.glb")

if bpy.context.object and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0


def mat(name, rgb, metal=0.0, rough=0.7, emission=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emission:
        try:
            b.inputs["Emission Color"].default_value = (*emission, 1.0)
            b.inputs["Emission Strength"].default_value = strength
        except Exception:
            pass
    return m


ARMOR = mat("op_armor", (0.09, 0.16, 0.20), 0.35, 0.62)
FABRIC = mat("op_fabric", (0.06, 0.08, 0.10), 0.0, 0.9)
PLATE = mat("op_plate", (0.16, 0.24, 0.28), 0.5, 0.45)
AMBER = mat("op_amber", (0.95, 0.52, 0.10), 0.3, 0.4, (1.0, 0.35, 0.02), 1.8)
VISOR = mat("op_visor", (0.1, 0.85, 0.9), 0.2, 0.25, (0.05, 0.9, 1.0), 2.5)
GUN = mat("op_gun", (0.12, 0.13, 0.15), 0.7, 0.4)
SKIN = mat("op_skin", (0.55, 0.4, 0.3), 0.0, 0.85)

root = bpy.data.objects.new("Operative", None)
bpy.context.collection.objects.link(root)


def node(name):
    o = bpy.data.objects.new(name, None)
    o.parent = root
    bpy.context.collection.objects.link(o)
    return o


def box(name, loc, size, material, bevel=0.0, rot=(0, 0, 0), parent=root):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.parent = parent
    o.scale = size
    o.rotation_euler = rot
    o.data.materials.append(material)
    if bevel:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = 2
    return o


def cyl(name, loc, r, h, material, verts=12, rot=(0, 0, 0), parent=root):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc)
    o = bpy.context.object
    o.name = name
    o.parent = parent
    o.rotation_euler = rot
    o.data.materials.append(material)
    return o


# Torso and hips (Blender Z is up)
torso = node("Torso")
box("Chest", (0, 0, 1.28), (0.52, 0.30, 0.62), ARMOR, 0.05, parent=torso)
box("ChestPlate", (0, -0.16, 1.32), (0.40, 0.06, 0.42), PLATE, 0.03, parent=torso)
box("Belt", (0, 0, 0.98), (0.48, 0.30, 0.12), FABRIC, 0.03, parent=torso)
box("Backpack", (0, 0.21, 1.30), (0.38, 0.20, 0.46), FABRIC, 0.04, parent=torso)
for sx in (-1, 1):
    box("Shoulder", (sx * 0.32, 0, 1.50), (0.20, 0.30, 0.20), PLATE, 0.04, parent=torso)
    box("ChestStripe", (sx * 0.12, -0.195, 1.32), (0.06, 0.02, 0.40), AMBER, parent=torso)

# Head with helmet and visor
head = node("Head")
head.location = (0, 0, 1.72)
box("Skull", (0, 0, 0.0), (0.28, 0.26, 0.30), SKIN, 0.08, parent=head)
box("Helmet", (0, 0, 0.10), (0.32, 0.30, 0.20), ARMOR, 0.07, parent=head)
box("Visor", (0, -0.145, 0.01), (0.25, 0.035, 0.09), VISOR, 0.02, parent=head)
box("CommLight", (0.13, -0.13, 0.14), (0.035, 0.035, 0.035), AMBER, parent=head)

# Arms (pivot at shoulder, geometry hanging down)
for side, sign in (("L", -1), ("R", 1)):
    arm = node("Arm" + side)
    arm.location = (sign * 0.32, 0, 1.48)
    cyl("UpperArm" + side, (0, 0, -0.20), 0.075, 0.40, FABRIC, parent=arm)
    cyl("Forearm" + side, (0, -0.02, -0.50), 0.07, 0.36, ARMOR, parent=arm)
    box("Glove" + side, (0, -0.04, -0.70), (0.12, 0.12, 0.12), FABRIC, 0.02, parent=arm)

# Legs
for side, sign in (("L", -1), ("R", 1)):
    thigh = node("Thigh" + side)
    thigh.location = (sign * 0.15, 0, 0.96)
    cyl("UpperLeg" + side, (0, 0, -0.22), 0.10, 0.46, FABRIC, parent=thigh)
    shin = node("Shin" + side)
    shin.location = (0, 0, -0.46)
    shin.parent = thigh
    cyl("LowerLeg" + side, (0, 0, -0.21), 0.09, 0.44, ARMOR, parent=shin)
    box("Boot" + side, (0, -0.05, -0.44), (0.16, 0.26, 0.12), FABRIC, 0.02, parent=shin)

# No gun mesh: the local player always sees their own first-person weapon;
# a separate gun glued to the chest looked like it was sticking out of the belly.

bpy.ops.object.select_all(action="DESELECT")
members = [root]
stack = list(root.children)
while stack:
    c = stack.pop()
    members.append(c)
    stack.extend(c.children)
for o in members:
    o.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                         export_apply=True, export_yup=True, export_cameras=False,
                         export_lights=False, export_extras=True)
print("EXPORTED", OUT, os.path.getsize(OUT))
