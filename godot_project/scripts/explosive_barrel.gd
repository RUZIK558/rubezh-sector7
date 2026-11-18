extends StaticBody3D
## Red barrel: one bullet turns it into a 5.5 m blast.

var exploded := false

func _ready() -> void:
	add_to_group("explosive_barrels")
	set_meta("surface", "metal")

func take_damage(_amount := 1.0, _headshot := false, _pos := Vector3.ZERO) -> void:
	explode()

func explode() -> void:
	if exploded:
		return
	exploded = true
	var origin := global_position + Vector3.UP * 0.55
	FX.explosion(origin, 1.15)
	AudioManager.play_3d("explosion", origin, 1.0, randf_range(0.9, 1.05))
	# enemies
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.has_method("take_hit"):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < 5.5:
			var dmg := lerpf(95.0, 25.0, clampf(d / 5.5, 0.0, 1.0))
			e.take_hit(dmg, false, (e.global_position - global_position).normalized(), e.global_position + Vector3.UP)
	# player
	var p = get_tree().get_first_node_in_group("player")
	if p and is_instance_valid(p) and p.has_method("take_damage"):
		var pd: float = p.global_position.distance_to(global_position)
		if pd < 5.5:
			p.take_damage(lerpf(85.0, 15.0, clampf(pd / 5.5, 0.0, 1.0)), global_position)
	# chain reaction
	for other in get_tree().get_nodes_in_group("explosive_barrels"):
		if other == self or not is_instance_valid(other):
			continue
		if other.global_position.distance_to(global_position) < 4.8:
			other.call_deferred("explode")
	FX.shake(0.5)
	queue_free()
