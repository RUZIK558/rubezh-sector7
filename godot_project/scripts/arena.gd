class_name Arena
extends Node3D
## Builds the SECTOR 7 arena from Blender props and procedural structure.

const CRATE := preload("res://assets/models/crate.glb")
const BARREL := preload("res://assets/models/barrel.glb")
const BARREL_EXPLOSIVE := preload("res://assets/models/barrel_explosive.glb")
const BARRIER := preload("res://assets/models/barrier.glb")
const CONTAINER := preload("res://assets/models/container.glb")
const SANDBAGS := preload("res://assets/models/sandbags.glb")
const LIGHTPOST := preload("res://assets/models/lightpost.glb")
const PLATFORM := preload("res://assets/models/platform.glb")
const RAMP := preload("res://assets/models/ramp.glb")
const GATE := preload("res://assets/models/gate.glb")
const WATCHTOWER := preload("res://assets/models/watchtower.glb")
const FUEL_TANK := preload("res://assets/models/fuel_tank.glb")
const BLOCK_LARGE := preload("res://assets/models/block_large.glb")
const RADAR := preload("res://assets/models/radar_dish.glb")
const TERMINAL := preload("res://assets/models/shop_terminal.glb")

const TEX_FLOOR := preload("res://assets/textures/concrete_floor.png")
const TEX_WALL := preload("res://assets/textures/concrete_wall.png")
const TEX_METAL := preload("res://assets/textures/metal_plate.png")
const TEX_HAZARD := preload("res://assets/textures/hazard_stripes.png")
const TEX_GLOW := preload("res://assets/textures/fx_glow.png")
const TEX_DETAIL_WOOD := preload("res://assets/textures/detail_wood.png")
const TEX_DETAIL_METAL := preload("res://assets/textures/detail_metal.png")
const TEX_DETAIL_CONCRETE := preload("res://assets/textures/detail_concrete.png")
const TEX_DETAIL_SAND := preload("res://assets/textures/detail_sand.png")
const FONT_BLACK := preload("res://assets/fonts/Montserrat-ExtraBold.otf")
const FONT_BOLD := preload("res://assets/fonts/Montserrat-Bold.otf")

const HALF_X := 32.0
const HALF_Z := 28.0

var spawn_points: Array[Dictionary] = []
var barrels: Array[Node] = []

var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_hazard: StandardMaterial3D
var _mat_dark: StandardMaterial3D

func _ready() -> void:
	_make_materials()
	_build_ground()
	_build_walls()
	_build_markings()
	_build_cover()
	_build_platform()
	_build_gates()
	_build_expansion()
	_build_lights()
	_build_atmosphere()

func _make_materials() -> void:
	_mat_floor = StandardMaterial3D.new()
	_mat_floor.albedo_texture = TEX_FLOOR
	_mat_floor.uv1_scale = Vector3(9, 9, 1)
	_mat_floor.roughness = 0.94
	_mat_floor.albedo_color = Color(0.86, 0.86, 0.84)
	_mat_wall = StandardMaterial3D.new()
	_mat_wall.albedo_texture = TEX_WALL
	_mat_wall.uv1_triplanar = true
	_mat_wall.uv1_scale = Vector3(0.34, 0.34, 0.34)
	_mat_wall.albedo_color = Color(0.82, 0.82, 0.8)
	_mat_wall.roughness = 0.96
	_mat_metal = StandardMaterial3D.new()
	_mat_metal.albedo_texture = TEX_METAL
	_mat_metal.uv1_triplanar = true
	_mat_metal.uv1_scale = Vector3(0.5, 0.5, 0.5)
	_mat_metal.albedo_color = Color(0.8, 0.8, 0.82)
	_mat_metal.metallic = 0.55
	_mat_metal.roughness = 0.45
	_mat_hazard = StandardMaterial3D.new()
	_mat_hazard.albedo_texture = TEX_HAZARD
	_mat_hazard.uv1_scale = Vector3(2, 1, 1)
	_mat_hazard.roughness = 0.7
	_mat_hazard.albedo_color = Color(0.9, 0.85, 0.7)
	_mat_dark = StandardMaterial3D.new()
	_mat_dark.albedo_color = Color(0.035, 0.04, 0.045)
	_mat_dark.metallic = 0.5
	_mat_dark.roughness = 0.55

func _build_ground() -> void:
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(67.0, 59.0)
	plane.mesh = mesh
	plane.material_override = _mat_floor
	plane.position.y = 0.0
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(67.0, 0.6, 59.0)
	cs.shape = box
	cs.position.y = -0.3
	body.add_child(cs)
	add_child(body)

func _build_walls() -> void:
	var h := 4.4
	var t := 0.55
	# north / south
	for sz in [-1, 1]:
		var wall := _box(Vector3(HALF_X * 2 + 1.2, h, t), _mat_wall)
		wall.position = Vector3(0, h * 0.5, sz * (HALF_Z + t * 0.5))
		_add_static_box(Vector3(HALF_X * 2 + 1.2, h, t), wall.position)
		var trim := _box(Vector3(HALF_X * 2 + 1.4, 0.16, t + 0.2), _mat_metal)
		trim.position = Vector3(0, h, sz * (HALF_Z + t * 0.5))
		var stripe := _paint_box(Vector3(HALF_X * 2, 0.34, 0.03), _mat_hazard)
		stripe.position = Vector3(0, 0.22, sz * (HALF_Z - 0.02))
	# east / west
	for sx in [-1, 1]:
		var wall := _box(Vector3(t, h, HALF_Z * 2 + 1.2), _mat_wall)
		wall.position = Vector3(sx * (HALF_X + t * 0.5), h * 0.5, 0)
		_add_static_box(Vector3(t, h, HALF_Z * 2 + 1.2), wall.position)
		var trim := _box(Vector3(t + 0.2, 0.16, HALF_Z * 2 + 1.4), _mat_metal)
		trim.position = Vector3(sx * (HALF_X + t * 0.5), h, 0)
		var stripe := _paint_box(Vector3(0.03, 0.34, HALF_Z * 2), _mat_hazard)
		stripe.position = Vector3(sx * (HALF_X - 0.02), 0.22, 0)
	# structural columns
	for sx in [-1, 1]:
		for z in range(-28, 29, 7):
			var col := _box(Vector3(0.34, h, 0.34), _mat_dark)
			col.position = Vector3(sx * (HALF_X - 0.16), h * 0.5, z)
			_add_static_box(Vector3(0.34, h, 0.34), col.position)
	for sz in [-1, 1]:
		for x in range(-28, 29, 7):
			var col := _box(Vector3(0.34, h, 0.34), _mat_dark)
			col.position = Vector3(x, h * 0.5, sz * (HALF_Z - 0.16))
			_add_static_box(Vector3(0.34, h, 0.34), col.position)
	# corner pylons with red beacons
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var pylon := _box(Vector3(0.7, 6.4, 0.7), _mat_metal)
			pylon.position = Vector3(sx * (HALF_X - 0.4), 3.2, sz * (HALF_Z - 0.4))
			_add_static_box(Vector3(0.7, 6.4, 0.7), pylon.position)
			var cap := _box(Vector3(0.9, 0.22, 0.9), _mat_dark)
			cap.position = Vector3(pylon.position.x, 6.5, pylon.position.z)
			var beacon := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.12
			sph.height = 0.24
			beacon.mesh = sph
			var bm := StandardMaterial3D.new()
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bm.albedo_color = Color(1.0, 0.1, 0.05)
			bm.emission_enabled = true
			bm.emission = Color(1.0, 0.08, 0.03)
			bm.emission_energy_multiplier = 4.0
			beacon.material_override = bm
			beacon.position = Vector3(pylon.position.x, 6.7, pylon.position.z)
			add_child(beacon)
			var bl := OmniLight3D.new()
			bl.light_color = Color(1.0, 0.1, 0.05)
			bl.light_energy = 0.7
			bl.omni_range = 5.0
			bl.shadow_enabled = false
			bl.position = beacon.position
			add_child(bl)

func _build_markings() -> void:
	# central lane lines
	var paint_dark := _flat_mat(Color(0.55, 0.44, 0.15), 0.9)
	_paint_quad(Vector2(0.18, 46.0), Vector3(-3.0, 0.012, 0), paint_dark)
	_paint_quad(Vector2(0.18, 46.0), Vector3(3.0, 0.012, 0), paint_dark)
	for i in range(11):
		_paint_quad(Vector2(3.2, 0.14), Vector3(0, 0.013, -25 + i * 5.0), paint_dark)
	# central circle
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.4
	torus.outer_radius = 3.6
	torus.rings = 40
	torus.ring_segments = 4
	ring.mesh = torus
	var ring_mat := _flat_mat(Color(0.55, 0.42, 0.12), 0.9)
	ring.material_override = ring_mat
	ring.position.y = 0.014
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	# gate pads
	for d in spawn_points:
		var pad := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.7
		cyl.bottom_radius = 1.7
		cyl.height = 0.03
		pad.mesh = cyl
		var pad_mat := _flat_mat(Color(0.22, 0.045, 0.035), 0.8)
		pad_mat.emission_enabled = true
		pad_mat.emission = Color(0.45, 0.03, 0.02)
		pad_mat.emission_energy_multiplier = 1.3
		pad.material_override = pad_mat
		pad.position = d.pos + Vector3(0, 0.018, 0)
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pad)
	# stencilled wall text
	_label3d("СЕКТОР 7", Vector3(0, 2.65, -HALF_Z + 0.08), 0.0, 1.35, Color(0.52, 0.55, 0.55))
	_label3d("ОПАСНАЯ ЗОНА // 07", Vector3(0, 1.55, -HALF_Z + 0.08), 0.0, 0.34, Color(0.46, 0.34, 0.20))
	_label3d("РУБЕЖ", Vector3(-HALF_X + 0.08, 2.7, 6.0), 90.0, 0.8, Color(0.45, 0.48, 0.5))
	_label3d("07", Vector3(HALF_X - 0.08, 2.8, -8.0), -90.0, 1.8, Color(0.35, 0.37, 0.4))

func _build_cover() -> void:
	# central containers form a diagonal street
	_instance_prop(CONTAINER, Vector3(-5.6, 0, -3.2), 18.0, Vector3(6.08, 2.6, 2.48), Vector3(0, 1.3, 0))
	_instance_prop(CONTAINER, Vector3(6.8, 0, 4.6), -16.0, Vector3(6.08, 2.6, 2.48), Vector3(0, 1.3, 0))
	# crates
	var crates := [
		[Vector3(-12.4, 0, -8.6), 8.0, 1.2, 0.0],
		[Vector3(-11.1, 0, -8.7), -4.0, 1.2, 0.0],
		[Vector3(-11.8, 0, -8.6), 12.0, 1.2, 1.2],
		[Vector3(3.0, 0, 8.6), -12.0, 1.2, 0.0],
		[Vector3(3.1, 0, 8.5), 4.0, 1.2, 1.2],
		[Vector3(14.5, 0, -4.5), 21.0, 1.2, 0.0],
		[Vector3(-3.4, 0, 13.1), -7.0, 1.2, 0.0],
		[Vector3(12.6, 0, 12.4), 14.0, 1.2, 0.0],
		[Vector3(-16.0, 0, 2.0), 30.0, 1.2, 0.0],
		[Vector3(-15.9, 0, 2.1), -6.0, 1.2, 1.2],
	]
	for c in crates:
		var _inst := _instance_prop(CRATE, c[0] + Vector3(0, c[3], 0), c[1],
				Vector3(1.24, 1.18, 1.24), Vector3(0, 0.59, 0), true, 0.55)
	# barriers
	_instance_prop(BARRIER, Vector3(-4.2, 0, 9.6), 14.0, Vector3(2.44, 1.0, 0.75), Vector3(0, 0.5, 0))
	_instance_prop(BARRIER, Vector3(11.6, 0, 1.2), -21.0, Vector3(2.44, 1.0, 0.75), Vector3(0, 0.5, 0))
	_instance_prop(BARRIER, Vector3(-12.2, 0, -2.6), 68.0, Vector3(2.44, 1.0, 0.75), Vector3(0, 0.5, 0))
	_instance_prop(BARRIER, Vector3(1.4, 0, -12.4), 88.0, Vector3(2.44, 1.0, 0.75), Vector3(0, 0.5, 0))
	# sandbags
	_instance_prop(SANDBAGS, Vector3(-14.8, 0, 11.6), 28.0, Vector3(2.92, 1.08, 0.52), Vector3(0, 0.54, 0))
	_instance_prop(SANDBAGS, Vector3(6.4, 0, -12.6), -6.0, Vector3(2.92, 1.08, 0.52), Vector3(0, 0.54, 0))
	_instance_prop(SANDBAGS, Vector3(16.2, 0, 10.4), -33.0, Vector3(2.92, 1.08, 0.52), Vector3(0, 0.54, 0))
	_instance_prop(SANDBAGS, Vector3(-16.2, 0, -11.8), 74.0, Vector3(2.92, 1.08, 0.52), Vector3(0, 0.54, 0))
	# explosive barrels: risk / reward
	var boom := [
		Vector3(-8.1, 0, 1.6), Vector3(10.1, 0, -2.4), Vector3(-14.6, 0, 5.4),
		Vector3(4.9, 0, 12.1), Vector3(14.9, 0, 6.1), Vector3(-0.9, 0, -10.1),
	]
	for p in boom:
		_add_barrel(p, true)
	var regular := [
		Vector3(-9.0, 0, 1.7), Vector3(9.4, 0, -2.2), Vector3(-14.2, 0, 6.2),
		Vector3(5.5, 0, 12.6), Vector3(15.5, 0, 6.7), Vector3(-2.4, 0, 6.8),
		Vector3(-24.0, 0, -9.0), Vector3(23.0, 0, 16.0), Vector3(-18.0, 0, 21.0),
	]
	for p in regular:
		_add_barrel(p, false)
	var boom2 := [Vector3(-22.0, 0, 8.0), Vector3(20.0, 0, -12.0), Vector3(4.0, 0, 20.0)]
	for p in boom2:
		_add_barrel(p, true)

func _build_platform() -> void:
	var _plat := _instance_prop(PLATFORM, Vector3(9.4, 0, -8.6), 0.0,
			Vector3(6.06, 0.46, 4.66), Vector3(0, 0.23, 0))
	var ramp := _instance_prop(RAMP, Vector3(9.4, 0, -4.42), 0.0)
	# ramp collision from its visual mesh
	var mi := ramp.find_children("*", "MeshInstance3D", true, false)
	if mi.size() > 0:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = mi[0].mesh.create_trimesh_shape()
		cs.transform = mi[0].transform
		body.add_child(cs)
		ramp.add_child(body)

func _build_gates() -> void:
	var defs := [
		{"pos": Vector3(0, 0, -27.55), "yaw": 0.0, "spawn": Vector3(0, 0, -25.6)},
		{"pos": Vector3(31.55, 0, 0.0), "yaw": -90.0, "spawn": Vector3(29.5, 0, 0)},
		{"pos": Vector3(-31.55, 0, 0.0), "yaw": 90.0, "spawn": Vector3(-29.5, 0, 0)},
		{"pos": Vector3(10.5, 0, 27.55), "yaw": 180.0, "spawn": Vector3(10.5, 0, 25.5)},
		{"pos": Vector3(-21.0, 0, 27.55), "yaw": 180.0, "spawn": Vector3(-21.0, 0, 25.5)},
		{"pos": Vector3(-31.55, 0, -18.0), "yaw": 90.0, "spawn": Vector3(-29.5, 0, -18.0)},
	]
	for d in defs:
		var gate := GATE.instantiate()
		gate.position = d.pos
		gate.rotation_degrees.y = d.yaw
		add_child(gate)
		# posts only (open passage)
		for sx in [-1.72, 1.72]:
			var offset := Vector3(sx, 1.78, 0).rotated(Vector3.UP, deg_to_rad(d.yaw))
			_add_static_box(Vector3(0.44, 3.56, 0.44), d.pos + offset)
		var inward: Vector3 = Vector3.ZERO - Vector3(d.pos)
		inward.y = 0
		spawn_points.append({
			"pos": d.spawn,
			"yaw": atan2(-inward.x, -inward.z),
			"gate": d.pos,
		})

func _build_expansion() -> void:
	# Watchtowers anchor the four corners of the enlarged field.
	for pos in [Vector3(-25.0, 0, -21.0), Vector3(25.0, 0, -21.0),
			Vector3(-25.0, 0, 21.0), Vector3(25.0, 0, 21.0)]:
		_instance_prop(WATCHTOWER, pos, 0.0, Vector3(2.7, 5.0, 2.7), Vector3(0, 2.5, 0))
	# Fuel farms and heavy concrete blocks create new lanes of cover.
	for pos in [Vector3(-27.0, 0, 6.0), Vector3(27.0, 0, -6.0), Vector3(16.0, 0, 23.0)]:
		_instance_prop(FUEL_TANK, pos, randf() * 30.0, Vector3(2.4, 3.1, 2.4), Vector3(0, 1.55, 0))
	for pos in [Vector3(-16.0, 0, -22.0), Vector3(22.0, 0, -19.0),
			Vector3(-26.0, 0, 16.0), Vector3(12.0, 0, -20.0)]:
		_instance_prop(BLOCK_LARGE, pos, randf_range(-18.0, 18.0),
			Vector3(2.7, 2.4, 2.7), Vector3(0, 1.2, 0), true, 1.1)
	_instance_prop(RADAR, Vector3(-28.0, 0, -26.0), 35.0, Vector3(1.2, 4.2, 1.2), Vector3(0, 2.1, 0))
	# Quartermaster terminals mark the deployment zone.
	_instance_prop(TERMINAL, Vector3(-3.2, 0, 14.0), 180.0)
	_instance_prop(TERMINAL, Vector3(3.2, 0, 14.0), 180.0)

func _build_lights() -> void:
	var defs := [
		Vector3(-28.6, 0, -24.6), Vector3(28.6, 0, -24.6),
		Vector3(-28.6, 0, 24.6), Vector3(28.6, 0, 24.6),
		Vector3(-28.6, 0, 0.0), Vector3(28.6, 0, 0.0),
	]
	for p in defs:
		var dir: Vector3 = Vector3.ZERO - Vector3(p)
		dir.y = 0
		dir = dir.normalized()
		var yaw := atan2(-dir.z, dir.x)
		var post := LIGHTPOST.instantiate()
		post.position = p
		post.rotation.y = yaw
		add_child(post)
		_add_static_box(Vector3(0.5, 6.1, 0.5), p + Vector3(0, 3.05, 0))
		var head: Vector3 = Vector3(p) + Vector3(1.02, 5.72, 0).rotated(Vector3.UP, yaw)
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.72, 0.42)
		spot.light_energy = 11.0
		spot.spot_range = 36.0
		spot.spot_angle = 47.0
		spot.spot_angle_attenuation = 0.9
		spot.shadow_enabled = false
		add_child(spot)
		spot.position = head
		spot.look_at(Vector3(0, 0.2, 0), Vector3.UP)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.6, 0.3)
		lamp.light_energy = 1.0
		lamp.omni_range = 4.0
		lamp.shadow_enabled = false
		lamp.position = head
		add_child(lamp)

func _build_atmosphere() -> void:
	var dust := CPUParticles3D.new()
	dust.amount = 90
	dust.lifetime = 12.0
	dust.preprocess = 12.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(31.0, 3.0, 27.0)
	dust.position = Vector3(0, 2.6, 0)
	dust.gravity = Vector3(0, -0.015, 0)
	dust.initial_velocity_min = 0.01
	dust.initial_velocity_max = 0.09
	dust.scale_amount_min = 0.7
	dust.scale_amount_max = 2.0
	dust.color = Color(1.0, 0.78, 0.5, 0.28)
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	dust.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = TEX_GLOW
	m.albedo_color = Color(1.0, 0.75, 0.45, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.disable_receive_shadows = true
	dust.material_override = m
	add_child(dust)

# ------------------------------------------------------------------ helpers
func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	return mi

func _paint_box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := _box(size, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _paint_quad(size: Vector2, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.rotation_degrees.x = -90.0
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _flat_mat(color: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _add_static_box(size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.position = pos
	body.add_child(cs)
	add_child(body)
	return body

func _instance_prop(scene: PackedScene, pos: Vector3, yaw := 0.0,
		collision_size := Vector3.ZERO, collision_offset := Vector3.ZERO,
		detail := true, detail_scale := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = yaw
	add_child(root)
	var model := scene.instantiate()
	root.add_child(model)
	if collision_size != Vector3.ZERO:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = collision_size
		cs.shape = box
		cs.position = collision_offset
		body.add_child(cs)
		root.add_child(body)
	if detail:
		_apply_detail(model, detail_scale)
	return root

func _apply_detail(model: Node, scale_factor := 1.0) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var mat: Material = mi.get_active_material(i)
			if not (mat is StandardMaterial3D):
				continue
			var m: StandardMaterial3D = mat.duplicate()
			var n := m.resource_name.to_lower()
			var tex: Texture2D = TEX_DETAIL_CONCRETE
			if n.contains("wood"):
				tex = TEX_DETAIL_WOOD
			elif n.contains("metal") or n.contains("steel") or n.contains("rust"):
				tex = TEX_DETAIL_METAL
			elif n.contains("sand"):
				tex = TEX_DETAIL_SAND
			elif n.contains("teal"):
				tex = TEX_DETAIL_METAL
			m.albedo_texture = tex
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * (0.75 * scale_factor)
			if m.roughness < 0.4:
				m.roughness = 0.5
			mi.set_surface_override_material(i, m)

func _add_barrel(pos: Vector3, explosive: bool) -> void:
	var root := StaticBody3D.new()
	root.position = pos
	root.collision_layer = 1
	root.collision_mask = 0
	add_child(root)
	var model := (BARREL_EXPLOSIVE if explosive else BARREL).instantiate()
	root.add_child(model)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.39
	cyl.height = 1.0
	cs.shape = cyl
	cs.position.y = 0.5
	root.add_child(cs)
	if explosive:
		root.set_script(preload("res://scripts/explosive_barrel.gd"))
		barrels.append(root)

func _label3d(text: String, pos: Vector3, yaw_deg: float, pixel: float, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = FONT_BLACK
	l.font_size = 180
	l.pixel_size = pixel * 0.01
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.no_depth_test = false
	l.position = pos
	l.rotation_degrees.y = yaw_deg
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
