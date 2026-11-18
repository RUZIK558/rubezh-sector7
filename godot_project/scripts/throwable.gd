extends Node3D
## Player-thrown knife or fragmentation grenade.

enum Kind { KNIFE, GRENADE }

const GRENADE_MODEL := preload("res://assets/models/grenade.glb")
const KNIFE_MODEL := preload("res://assets/models/knife_klin.glb")

@export var kind: int = Kind.GRENADE

var velocity := Vector3.ZERO
var damage := 90.0
var fuse := 1.5
var _alive := true
var _time := 0.0
var _stuck := false

func _ready() -> void:
	add_to_group("throwables")
	var area := Area3D.new()
	area.name = "HitArea"
	area.collision_layer = 0
	area.collision_mask = 1 | 8
	area.monitoring = true
	var shape := SphereShape3D.new()
	shape.radius = 0.13 if kind == Kind.GRENADE else 0.10
	var cs := CollisionShape3D.new()
	cs.shape = shape
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_body)
	area.area_entered.connect(_on_area)
	var model: Node3D = (GRENADE_MODEL if kind == Kind.GRENADE else KNIFE_MODEL).instantiate()
	model.scale = Vector3.ONE * (1.9 if kind == Kind.GRENADE else 1.25)
	if kind == Kind.KNIFE:
		model.rotation_degrees.y = -90.0
	add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func launch(from: Vector3, dir: Vector3, speed: float) -> void:
	global_position = from
	velocity = dir * speed + Vector3.UP * 1.8

func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_time += delta
	if not _stuck:
		velocity.y -= 19.0 * delta
		global_position += velocity * delta
		if kind == Kind.GRENADE:
			rotation.x += delta * 9.0
			rotation.z += delta * 6.0
		else:
			look_at(global_position + velocity, Vector3.UP)
			rotation.z += delta * 14.0
	if kind == Kind.GRENADE:
		if _time >= fuse:
			_explode()
	elif _time >= 5.0:
		_despawn()

func _on_body(body: Node) -> void:
	if not _alive or kind == Kind.GRENADE:
		return
	_stuck = true
	velocity = Vector3.ZERO
	FX.impact(global_position, Vector3.UP, false)

func _on_area(area: Area3D) -> void:
	if not _alive or kind != Kind.KNIFE:
		return
	if area.has_method("apply_hit"):
		var from := global_position
		var dir: Vector3 = velocity.normalized() if velocity.length() > 0.1 else Vector3.FORWARD
		area.apply_hit(damage, dir, from, false)
		FX.hit_spark(from, -dir, false)
		AudioManager.play_3d("knife_hit", from, -2.0)
		_despawn()

func _explode() -> void:
	if not _alive:
		return
	_alive = false
	var origin := global_position
	FX.explosion(origin, 1.5)
	AudioManager.play_3d("explosion", origin, 1.0)
	FX.shake(0.75)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_hit"):
			continue
		var d: float = enemy.global_position.distance_to(origin)
		if d < 6.0:
			var amount := lerpf(130.0, 35.0, clampf(d / 6.0, 0.0, 1.0))
			enemy.take_hit(amount, false, (enemy.global_position - origin).normalized(), enemy.global_position + Vector3.UP)
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		var pd: float = player.global_position.distance_to(origin)
		if pd < 6.0:
			player.take_damage(lerpf(95.0, 12.0, clampf(pd / 6.0, 0.0, 1.0)), origin)
	for barrel in get_tree().get_nodes_in_group("explosive_barrels"):
		if is_instance_valid(barrel) and barrel.global_position.distance_to(origin) < 5.0:
			barrel.call_deferred("explode")
	queue_free()

func _despawn() -> void:
	if not _alive:
		return
	_alive = false
	queue_free()
