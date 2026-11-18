extends Node
## Lightweight procedural combat effects built from textured quads and tweens.

const TEX_FLASH := preload("res://assets/textures/fx_flash.png")
const TEX_SPARK := preload("res://assets/textures/fx_spark.png")
const TEX_SMOKE := preload("res://assets/textures/fx_smoke.png")
const TEX_HOLE := preload("res://assets/textures/fx_bullet_hole.png")
const TEX_GLOW := preload("res://assets/textures/fx_glow.png")

var _mat_flash: StandardMaterial3D
var _mat_spark: StandardMaterial3D
var _mat_smoke: StandardMaterial3D
var _mat_smoke_dark: StandardMaterial3D
var _mat_hole: StandardMaterial3D
var _mat_tracer: StandardMaterial3D
var _mat_ring: StandardMaterial3D
var _mat_brass: StandardMaterial3D
var _holes: Array[Node3D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_mat_flash = _billboard(TEX_FLASH, Color(1.0, 0.78, 0.42), true, false)
	_mat_spark = _billboard(TEX_SPARK, Color(1.0, 0.72, 0.3), true, true)
	_mat_smoke = _billboard(TEX_SMOKE, Color(0.55, 0.57, 0.58, 0.55), false, true)
	_mat_smoke_dark = _billboard(TEX_SMOKE, Color(0.16, 0.17, 0.18, 0.7), false, true)
	_mat_hole = _billboard(TEX_HOLE, Color(1, 1, 1, 1), false, true)
	_mat_hole.no_depth_test = false
	_mat_tracer = StandardMaterial3D.new()
	_mat_tracer.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_tracer.albedo_color = Color(1.0, 0.72, 0.32, 0.9)
	_mat_tracer.emission_enabled = true
	_mat_tracer.emission = Color(1.0, 0.55, 0.15)
	_mat_tracer.emission_energy_multiplier = 6.0
	_mat_tracer.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_tracer.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_ring = StandardMaterial3D.new()
	_mat_ring.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_ring.albedo_color = Color(1.0, 0.48, 0.12, 0.55)
	_mat_ring.emission_enabled = true
	_mat_ring.emission = Color(1.0, 0.4, 0.08)
	_mat_ring.emission_energy_multiplier = 4.0
	_mat_ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ring.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_ring.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_brass = StandardMaterial3D.new()
	_mat_brass.albedo_color = Color(0.72, 0.55, 0.24)
	_mat_brass.metallic = 0.9
	_mat_brass.roughness = 0.3

func _billboard(tex: Texture2D, color: Color, additive: bool, billboard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.disable_receive_shadows = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m

func _scene() -> Node3D:
	return get_tree().current_scene as Node3D

func _quad(size: Vector2, mat: Material) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	q.mesh = mesh
	q.material_override = mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return q

func muzzle_flash(pos: Vector3, dir: Vector3, scale := 1.0) -> void:
	var root := Node3D.new()
	root.position = pos
	_scene().add_child(root)
	var flash := _quad(Vector2(0.52, 0.52) * scale, _mat_flash)
	var yaw := randf() * TAU
	flash.rotation = Vector3(0, yaw, randf_range(-0.4, 0.4))
	flash.scale = Vector3.ONE * randf_range(0.85, 1.25)
	root.add_child(flash)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 2.4
	light.omni_range = 4.0
	light.shadow_enabled = false
	root.add_child(light)
	if randf() < 0.55:
		var smoke_puff := _quad(Vector2(0.35, 0.35), _mat_smoke)
		smoke_puff.position = dir * 0.25
		root.add_child(smoke_puff)
		var tw := smoke_puff.create_tween().set_parallel(true)
		tw.tween_property(smoke_puff, "scale", Vector3.ONE * 2.0, 0.5)
		tw.tween_property(smoke_puff, "transparency", 1.0, 0.5)
		tw.tween_property(smoke_puff, "position", dir * 0.7 + Vector3.UP * 0.25, 0.5)
	var t := root.create_tween().set_parallel(true)
	t.tween_property(flash, "scale", flash.scale * 1.5, 0.06)
	t.tween_property(flash, "transparency", 1.0, 0.07)
	t.tween_property(light, "light_energy", 0.0, 0.08)
	t.chain().tween_callback(root.queue_free)

func tracer(from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)
	if dist < 0.2:
		return
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.028, 0.028, dist)
	mi.mesh = mesh
	mi.material_override = _mat_tracer
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = (from + to) * 0.5
	var up := Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	_scene().add_child(mi)
	mi.look_at(to, up)
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "transparency", 1.0, 0.09)
	t.tween_property(mi, "scale", Vector3(0.3, 0.3, 1.0), 0.09)
	t.chain().tween_callback(mi.queue_free)

func impact(pos: Vector3, normal: Vector3, metal := false) -> void:
	AudioManager.play_3d("impact_metal" if metal else "impact_concrete", pos, -2.0, randf_range(0.9, 1.12))
	# sparks
	for i in 4:
		var s := _quad(Vector2(0.09, 0.09), _mat_spark)
		s.position = pos
		s.scale = Vector3.ONE * randf_range(0.7, 1.4)
		_scene().add_child(s)
		var dir := (normal + Vector3(randf_range(-0.7, 0.7), randf_range(-0.2, 0.9), randf_range(-0.7, 0.7))).normalized()
		var end := pos + dir * randf_range(0.25, 0.7) + Vector3.DOWN * 0.25
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", end, randf_range(0.16, 0.3)).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector3.ONE * 0.05, 0.25)
		tw.tween_property(s, "transparency", 1.0, 0.25)
		tw.chain().tween_callback(s.queue_free)
	if not metal:
		smoke(pos + normal * 0.04, 0.6, false)
	# bullet hole decal
	var hole := _quad(Vector2(0.17, 0.17), _mat_hole)
	hole.position = pos + normal * 0.012
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	_scene().add_child(hole)
	hole.look_at(hole.position - normal, up)
	hole.rotation.z = randf() * TAU
	_holes.append(hole)
	while _holes.size() > 42:
		var old: Node3D = _holes.pop_front()
		if is_instance_valid(old):
			old.queue_free()

func smoke(pos: Vector3, scale := 1.0, dark := true) -> void:
	var s := _quad(Vector2(0.6, 0.6) * scale, _mat_smoke_dark if dark else _mat_smoke)
	s.position = pos
	s.scale = Vector3.ONE * 0.6
	_scene().add_child(s)
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE * 2.4 * scale, 0.9)
	tw.tween_property(s, "position", pos + Vector3.UP * 0.5 * scale, 0.9)
	tw.tween_property(s, "transparency", 1.0, 0.9)
	tw.chain().tween_callback(s.queue_free)

func hit_spark(pos: Vector3, normal: Vector3, headshot := false) -> void:
	var n := 8 if headshot else 4
	for i in n:
		var s := _quad(Vector2(0.07, 0.07), _mat_spark)
		s.position = pos
		_scene().add_child(s)
		var dir := (normal + Vector3(randf_range(-0.8, 0.8), randf_range(-0.4, 0.9), randf_range(-0.8, 0.8))).normalized()
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", pos + dir * randf_range(0.2, 0.6), randf_range(0.15, 0.35))
		tw.tween_property(s, "transparency", 1.0, 0.3)
		tw.tween_property(s, "scale", Vector3.ONE * 0.1, 0.3)
		tw.chain().tween_callback(s.queue_free)

func shell(pos: Vector3, dir: Vector3, right: Vector3) -> void:
	var sh := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018, 0.018, 0.052)
	sh.mesh = mesh
	sh.material_override = _mat_brass
	sh.position = pos
	sh.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene().add_child(sh)
	var end := pos + right * randf_range(0.45, 0.9) + Vector3.UP * 0.35 + dir * 0.15
	var tw := sh.create_tween().set_parallel(true)
	tw.tween_property(sh, "position", end + Vector3.DOWN * 0.9, 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(sh, "rotation", sh.rotation + Vector3(randf() * 9, randf() * 9, randf() * 9), 0.7)
	tw.tween_property(sh, "transparency", 1.0, 0.2).set_delay(0.55)
	tw.chain().tween_callback(sh.queue_free)

func explosion(pos: Vector3, scale := 1.0, with_sound := true) -> void:
	if with_sound:
		AudioManager.play_3d("explosion", pos, 1.0, randf_range(0.92, 1.05))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 10.0 * scale
	light.omni_range = 15.0 * scale
	light.position = pos + Vector3.UP
	light.shadow_enabled = false
	_scene().add_child(light)
	var flash := _quad(Vector2(2.6, 2.6) * scale, _mat_flash)
	flash.position = pos + Vector3.UP * 0.5
	_scene().add_child(flash)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = _mat_ring
	ring.scale = Vector3(0.6, 0.6, 0.6)
	ring.position = pos + Vector3.UP * 0.35
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene().add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(6.5, 1.8, 6.5) * scale, 0.55).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "transparency", 1.0, 0.55)
	tw.chain().tween_callback(ring.queue_free)
	var t := flash.create_tween().set_parallel(true)
	t.tween_property(flash, "scale", Vector3.ONE * 2.0, 0.25).set_ease(Tween.EASE_OUT)
	t.tween_property(flash, "transparency", 1.0, 0.3)
	t.chain().tween_callback(flash.queue_free)
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.45)
	lt.tween_callback(light.queue_free)
	for i in int(16 * scale):
		var s := _quad(Vector2(0.12, 0.12), _mat_spark)
		s.position = pos + Vector3.UP * randf_range(0.2, 1.0)
		s.scale = Vector3.ONE * randf_range(1.0, 2.4)
		_scene().add_child(s)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.15, 1.2), randf_range(-1, 1)).normalized()
		var tw2 := s.create_tween().set_parallel(true)
		tw2.tween_property(s, "position", s.position + dir * randf_range(2.0, 6.0) * scale, randf_range(0.4, 0.9)).set_ease(Tween.EASE_OUT)
		tw2.tween_property(s, "transparency", 1.0, 0.8)
		tw2.tween_property(s, "scale", Vector3.ONE * 0.1, 0.8)
		tw2.chain().tween_callback(s.queue_free)
	for i in 8:
		var puff := _quad(Vector2(1.2, 1.2) * scale, _mat_smoke_dark)
		puff.position = pos + Vector3.UP * randf_range(0.2, 1.2) + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
		puff.scale = Vector3.ONE * randf_range(0.2, 0.6)
		_scene().add_child(puff)
		var tw3 := puff.create_tween().set_parallel(true)
		tw3.tween_property(puff, "scale", Vector3.ONE * randf_range(2.5, 4.5) * scale, randf_range(0.7, 1.3))
		tw3.tween_property(puff, "position", puff.position + Vector3.UP * 1.4 + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), 1.2)
		tw3.tween_property(puff, "transparency", 1.0, 1.2)
		tw3.chain().tween_callback(puff.queue_free)
	shake(0.55 * scale)

func spawn_burst(pos: Vector3, color: Color, count := 14) -> void:
	var mat := _billboard(TEX_SPARK, color, true, true)
	for i in count:
		var s := _quad(Vector2(0.1, 0.1), mat)
		s.position = pos + Vector3.UP * randf_range(0.2, 1.8)
		_scene().add_child(s)
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized()
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", s.position + dir * randf_range(0.8, 2.2), 0.55).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "transparency", 1.0, 0.55)
		tw.tween_property(s, "scale", Vector3.ONE * 0.05, 0.55)
		tw.chain().tween_callback(s.queue_free)

func shake(amount: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_trauma"):
		player.add_trauma(amount * Settings.screen_shake)
