extends Area3D
## Forwards bullet hits from a hitbox area to its owning enemy.

@export var headshot := false

func apply_hit(damage: float, dir: Vector3, point: Vector3, head := false) -> void:
	var node := get_parent()
	while node and not node.has_method("take_hit"):
		node = node.get_parent()
	if not node:
		return
	if Net.is_client and int(node.get("net_id")) > 0:
		get_tree().current_scene.rpc_id(1, "rpc_enemy_hit", int(node.get("net_id")), damage, headshot or head)
		return
	node.take_hit(damage, headshot or head, dir, point)
