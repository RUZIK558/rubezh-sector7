extends Area3D
## Floating ammo / medkit pickup.

const AMMO := preload("res://assets/models/pickup_ammo.glb")
const MED := preload("res://assets/models/pickup_med.glb")

@export_enum("ammo", "med") var kind := "ammo"

var _base_y := 0.0
var _t := 0.0
var _taken := false

func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 32
	collision_mask = 2
	body_entered.connect(_on_body)
	var holder := Node3D.new()
	holder.name = "Holder"
	add_child(holder)
	var model = (AMMO if kind == "ammo" else MED).instantiate()
	holder.add_child(model)
	_base_y = 0.0
	_t = randf() * TAU
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	torus.rings = 24
	torus.ring_segments = 4
	ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.2, 1.0, 0.45) if kind == "ammo" else Color(0.85, 0.95, 1.0)
	rm.emission_enabled = true
	rm.emission = rm.albedo_color
	rm.emission_energy_multiplier = 3.0
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color.a = 0.55
	ring.material_override = rm
	ring.position.y = 0.03
	ring.scale = Vector3(1, 1, 1)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = rm.albedo_color
	light.light_energy = 0.8
	light.omni_range = 2.4
	light.shadow_enabled = false
	light.position.y = 0.4
	add_child(light)

func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 1.3
	var holder := get_node_or_null("Holder")
	if holder:
		holder.position.y = 0.12 + sin(_t * 2.0) * 0.055
		holder.rotation.y = sin(_t * 0.9) * 0.08

func _on_body(body: Node) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	if kind == "ammo":
		body.add_ammo(60)
		body.add_grenades(1)
		AudioManager.play("pickup_ammo", -3.0, randf_range(0.98, 1.05))
		FX.spawn_burst(global_position + Vector3.UP * 0.4, Color(0.2, 1.0, 0.45), 7)
	else:
		body.heal(35.0)
		AudioManager.play("pickup_med", -3.0, randf_range(0.98, 1.05))
		FX.spawn_burst(global_position + Vector3.UP * 0.4, Color(0.85, 0.95, 1.0), 7)
	queue_free()
