extends Area3D
## Slow glowing enemy plasma bolt.

const GLOW := preload("res://assets/textures/fx_glow.png")

var direction := Vector3.FORWARD
var damage := 10.0
var speed := 22.0
var life := 5.0
var scale_visual := 1.0
var net_id := 0
var network_remote := false
var target_pos := Vector3.ZERO
var _alive := true
var _orb_mat: StandardMaterial3D
var _core: MeshInstance3D

func _ready() -> void:
	add_to_group("projectiles")
	collision_layer = 16
	collision_mask = 0 if network_remote else (1 | 2)
	body_entered.connect(_on_body)
	_build_visual()
	life = 5.0

func _build_visual() -> void:
	var col := Color(1.0, 0.28, 0.08) if scale_visual > 1.15 else Color(1.0, 0.52, 0.12)
	_orb_mat = StandardMaterial3D.new()
	_orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_orb_mat.albedo_color = col
	_orb_mat.emission_enabled = true
	_orb_mat.emission = col
	_orb_mat.emission_energy_multiplier = 8.0
	_core = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.17 * scale_visual
	sphere.height = 0.34 * scale_visual
	sphere.radial_segments = 12
	sphere.rings = 6
	_core.mesh = sphere
	_core.material_override = _orb_mat
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.05, 1.05) * scale_visual
	glow.mesh = q
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_texture = GLOW
	gm.albedo_color = Color(col.r, col.g, col.b, 0.65)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gm.disable_receive_shadows = true
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.mesh.material = gm
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.3
	light.omni_range = 3.4
	light.shadow_enabled = false
	add_child(light)

func _physics_process(delta: float) -> void:
	if not _alive:
		return
	if network_remote:
		global_position = global_position.lerp(target_pos, 0.6)
		if _core:
			_core.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.08)
		return
	global_position += direction * speed * delta
	life -= delta
	if _core:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.08
		_core.scale = Vector3.ONE * pulse
	if life <= 0.0:
		_alive = false
		queue_free()

func _on_body(body: Node) -> void:
	if not _alive or network_remote:
		return
	_alive = false
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, global_position)
		FX.spawn_burst(global_position, Color(1.0, 0.35, 0.1), 7)
		FX.smoke(global_position, 0.5, true)
		AudioManager.play_3d("impact_metal", global_position, -5.0)
	else:
		FX.impact(global_position, -direction, true)
	queue_free()
