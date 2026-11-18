"""Build a fragmentation grenade for RUBEZH // СЕКТОР 7."""
import math, os
import bpy

ROOT = "/home/ruzik-admin/Документы/Проект по умолчанию"
MODEL = os.path.join(ROOT, "godot_project/assets/models/grenade.glb")

if bpy.context.object and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

scene = bpy.context.scene
scene.unit_settings.system = "METRIC"


def mat(name, rgb, metal=0.0, rough=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    return m


BODY = mat("grenade_green", (0.10, 0.20, 0.12), 0.35, 0.72)
METAL = mat("grenade_steel", (0.30, 0.33, 0.35), 0.85, 0.38)
LEVER = mat("grenade_lever", (0.55, 0.45, 0.12), 0.7, 0.45)

root = bpy.data.objects.new("Grenade", None)
bpy.context.collection.objects.link(root)


def attach(o):
    o.parent = root
    return o


bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=0.052, location=(0, 0, 0.055))
body = attach(bpy.context.object)
body.name = "Body"
body.data.materials.append(BODY)
body.scale = (1.0, 1.0, 1.18)

for z in (0.02, 0.055, 0.09):
    bpy.ops.mesh.primitive_torus_add(major_radius=0.050, minor_radius=0.004, location=(0, 0, z))
    t = attach(bpy.context.object)
    t.name = "Rib"
    t.data.materials.append(METAL)

bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.018, depth=0.022, location=(0, 0, 0.122))
cap = attach(bpy.context.object)
cap.name = "FuseCap"
cap.data.materials.append(METAL)

bpy.ops.mesh.primitive_torus_add(major_radius=0.016, minor_radius=0.003, location=(0.012, 0, 0.140))
ring = attach(bpy.context.object)
ring.name = "Pin"
ring.data.materials.append(LEVER)
ring.rotation_euler.y = math.radians(70)

bpy.ops.mesh.primitive_cube_add(size=1, location=(-0.055, 0, 0.095))
lever = attach(bpy.context.object)
lever.name = "Lever"
lever.scale = (0.045, 0.012, 0.022)
lever.data.materials.append(LEVER)

bpy.ops.object.select_all(action="DESELECT")
members = [root] + list(root.children)
for o in members:
    o.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(filepath=MODEL, export_format="GLB", use_selection=True,
                         export_apply=True, export_yup=True, export_cameras=False,
                         export_lights=False)
print("EXPORTED", MODEL, os.path.getsize(MODEL))
