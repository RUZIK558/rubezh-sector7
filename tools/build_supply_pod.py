"""Supply pod dropped by the arena event system."""
import math, os
import bpy

ROOT = "/home/ruzik-admin/Документы/Проект по умолчанию"
OUT = os.path.join(ROOT, "godot_project/assets/models/supply_pod.glb")

if bpy.context.object and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def mat(name, rgb, metal=0.0, rough=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    return m


CRATE = mat("supply_crate", (0.22, 0.28, 0.18), 0.2, 0.8)
STRAP = mat("supply_strap", (0.7, 0.5, 0.12), 0.3, 0.6)
CHUTE = mat("supply_chute", (0.65, 0.68, 0.62), 0.0, 0.9)
LIGHT = mat("supply_light", (0.2, 1.0, 0.5), 0.0, 0.4)

root = bpy.data.objects.new("SupplyPod", None)
bpy.context.collection.objects.link(root)


def attach(o, name, material):
    o.parent = root
    o.name = name
    o.data.materials.append(material)
    return o


bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.45))
crate = attach(bpy.context.object, "Crate", CRATE)
crate.scale = (1.1, 0.9, 0.9)
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.92))
lid = attach(bpy.context.object, "Lid", STRAP)
lid.scale = (1.16, 0.96, 0.10)
for x in (-0.38, 0.38):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, 0, 0.45))
    s = attach(bpy.context.object, "Strap", STRAP)
    s.scale = (0.09, 0.94, 0.94)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.07, location=(0, 0, 1.02))
lamp = attach(bpy.context.object, "Beacon", LIGHT)

# folded parachute above the pod
bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.85, radius2=0.12, depth=0.45, location=(0, 0, 1.85))
chute = attach(bpy.context.object, "Parachute", CHUTE)
for a in range(6):
    ang = a / 6 * math.tau
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.008, depth=0.9,
                                        location=(math.cos(ang) * 0.45, math.sin(ang) * 0.45, 1.35))
    line = attach(bpy.context.object, "Line", STRAP)
    line.rotation_euler.y = math.radians(12 if a % 2 else -12)

bpy.ops.object.select_all(action="DESELECT")
for o in [root] + list(root.children):
    o.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                         export_apply=True, export_yup=True, export_cameras=False,
                         export_lights=False)
print("EXPORTED", OUT, os.path.getsize(OUT))
