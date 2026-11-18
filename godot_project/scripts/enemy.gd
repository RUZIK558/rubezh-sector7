class_name Enemy
extends CharacterBody3D
## Wave enemy: scout, juggernaut and the Titan boss.

signal died(enemy: Node, score: int, headshot: bool)
signal health_changed(current: float, maximum: float)
signal summon_requested(origin: Vector3)

enum Type { SCOUT, JUGGERNAUT, TITAN }

const SENTINEL := preload("res://assets/models/sentinel.glb")
const JUGGERNAUT := preload("res://assets/models/juggernaut.glb")
const PROJECTILE := preload("res://scenes/projectile.tscn")
const GLOW := preload("res://assets/textures/fx_glow.png")

@export var enemy_type: int = Type.SCOUT
@export var wave: int = 1
@export var tier: int = 1
@export var elite: bool = false

var max_hp := 70.0
var hp := 70.0
var speed := 3.4
var damage := 7.0
var score_value := 110
var preferred_range := 11.0
var attack_range := 28.0
var fire_cooldown := 2.4
var projectile_count := 1
var burst_size := 3
var projectile_speed := 22.0
var is_boss := false
var dying := false
var combat_active := true
var spawn_timer := 0.85

var player: Node3D
var model_root: Node3D
var model: Node3D
var hitboxes: Node3D
var overlay_mat: StandardMaterial3D
var eye_light: OmniLight3D
var _flash_tween: Tween
var _base_scale := 1.0
var _body_scale := 1.0

var _anim: Dictionary = {}
var _base_rot: Dictionary = {}
var _base_pos: Dictionary = {}
var _muzzles: Array[Node3D] = []
var _walk_phase := 0.0
var _time := 0.0
var _strafe_sign := 1.0
var _strafe_timer := 1.5
var _stuck_timer := 0.0
var _last_pos := Vector3.ZERO
var _windup := 0.0
var _burst_left := 0
var _burst_timer := 0.0
var _cooldown := 0.0
var _summoned := false
var _muzzle_index := 0

func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	hitboxes = $Hitboxes
	_apply_stats()
	_build_model()
	_last_pos = global_position
	_cooldown = randf_range(1.4, 3.0)
	FX.spawn_burst(global_position + Vector3.UP * 0.7, _eye_color(), 12)
	AudioManager.play_3d("summon", global_position, -12.0, randf_range(0.9, 1.1))
	var tw := create_tween()
	var final_scale := _base_scale * (1.12 if elite else 1.0)
	tw.tween_property(model_root, "scale", Vector3.ONE * final_scale, 0.55).from(Vector3.ONE * _base_scale * 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	health_changed.emit(hp, max_hp)

func _apply_stats() -> void:
	match enemy_type:
		Type.SCOUT:
			max_hp = 70.0
			speed = 3.4
			damage = 10.0
			score_value = 110
			preferred_range = 12.0
			attack_range = 30.0
			fire_cooldown = 2.0
			projectile_count = 1
			burst_size = 2
			projectile_speed = 20.0
			_base_scale = 1.0
			_body_scale = 1.0
		Type.JUGGERNAUT:
			max_hp = 300.0
			speed = 2.3
			damage = 18.0
			score_value = 350
			preferred_range = 11.0
			attack_range = 30.0
			fire_cooldown = 2.6
			projectile_count = 3
			burst_size = 1
			projectile_speed = 18.0
			_base_scale = 1.0
			_body_scale = 1.19
		Type.TITAN:
			max_hp = 1600.0
			speed = 1.9
			damage = 22.0
			score_value = 1500
			preferred_range = 12.0
			attack_range = 34.0
			fire_cooldown = 2.4
			projectile_count = 4
			burst_size = 1
			projectile_speed = 18.0
			is_boss = true
			_base_scale = 1.3
			_body_scale = 1.19
	if not is_boss:
		max_hp *= 1.0 + 0.06 * float(wave - 1)
		speed *= 1.0 + 0.02 * float(wave - 1)
	else:
		max_hp *= float(tier)
		damage *= 1.0 + 0.30 * float(tier - 1)
		score_value *= tier
	if elite and not is_boss:
		max_hp *= 2.1
		damage *= 1.35
		score_value = int(float(score_value) * 1.7)
		speed *= 1.1
	hp = max_hp

func _build_model() -> void:
	model_root = Node3D.new()
	add_child(model_root)
	model = (SENTINEL if enemy_type == Type.SCOUT else JUGGERNAUT).instantiate()
	model_root.add_child(model)
	model_root.scale = Vector3.ONE * _base_scale * 0.05
	hitboxes.scale = Vector3.ONE * (_body_scale * _base_scale * (1.12 if elite else 1.0))
	# keep the physical capsule in sync
	var col := $Collision as CollisionShape3D
	col.scale = Vector3.ONE * _body_scale * _base_scale
	for n in ["ThighL", "ShinL", "ThighR", "ShinR", "ArmL", "ArmR", "Upper", "Head"]:
		var node := model.find_child(n, true, false)
		if node:
			_anim[n] = node
			_base_rot[n] = node.rotation
			_base_pos[n] = node.position
	for muzzle_name in ["Muzzle", "Muzzle1"]:
		var m := model.find_child(muzzle_name, true, false)
		if m:
			_muzzles.append(m)
	# hit flash overlay
	overlay_mat = StandardMaterial3D.new()
	overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay_mat.albedo_color = Color(1.0, 0.85, 0.7, 0.0)
	overlay_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	overlay_mat.disable_receive_shadows = true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = overlay_mat
	# glowing eye / visor light
	eye_light = OmniLight3D.new()
	var eye_col := _eye_color()
	if elite and not is_boss:
		eye_col = Color(1.0, 0.82, 0.22)
	eye_light.light_color = eye_col
	eye_light.light_energy = 0.55 if not is_boss else 1.4
	eye_light.omni_range = 2.2 if not is_boss else 4.0
	eye_light.shadow_enabled = false
	eye_light.position = Vector3(0, _eye_height(), -0.28 * _base_scale)
	add_child(eye_light)
	if enemy_type == Type.TITAN:
		_add_titan_armor()

func _add_titan_armor() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.18, 0.06, 0.05)
	m.metallic = 0.7
	m.roughness = 0.35
	for sx in [-1, 1]:
		var pod := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.34, 0.5, 0.62)
		pod.mesh = mesh
		pod.material_override = m
		pod.position = Vector3(sx * 0.52, 1.62, 0.02)
		pod.rotation_degrees.z = sx * -12.0
		model_root.add_child(pod)
		var glow := MeshInstance3D.new()
		var orb := SphereMesh.new()
		orb.radius = 0.075
		orb.height = 0.15
		glow.mesh = orb
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.albedo_color = Color(1.0, 0.12, 0.05)
		gm.emission_enabled = true
		gm.emission = Color(1.0, 0.08, 0.03)
		gm.emission_energy_multiplier = 5.0
		glow.material_override = gm
		glow.position = pod.position + Vector3(sx * 0.2, 0.05, -0.18)
		model_root.add_child(glow)

func _eye_color() -> Color:
	if elite and not is_boss:
		return Color(1.0, 0.82, 0.22)
	if enemy_type == Type.TITAN:
		return Color(1.0, 0.09, 0.04)
	return Color(1.0, 0.55, 0.16) if enemy_type == Type.SCOUT else Color(1.0, 0.78, 0.2)

func _eye_height() -> float:
	if enemy_type == Type.TITAN:
		return 2.55
	return 1.62 if enemy_type == Type.SCOUT else 1.92

func _physics_process(delta: float) -> void:
	if dying:
		return
	_time += delta
	if spawn_timer > 0.0:
		spawn_timer -= delta
		velocity.y -= 16.0 * delta
		move_and_slide()
		return
	if not combat_active:
		_animate(delta, 0.0)
		return
	if player == null or not is_instance_valid(player) or player.dead:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		velocity.y -= 16.0 * delta
		move_and_slide()
		_animate(delta, 0.0)
		return

	_attack_timer(delta)
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var see := _can_see_player()
	var desired := Vector3.ZERO
	var move_speed := speed
	if _windup > 0.0:
		move_speed = 0.0
	elif see:
		if dist > preferred_range + 1.2:
			desired = to_player.normalized()
		elif dist < preferred_range - 2.0:
			desired = -to_player.normalized()
		else:
			_strafe_timer -= delta
			if _strafe_timer <= 0.0:
				_strafe_sign = -1.0 if randf() < 0.5 else 1.0
				_strafe_timer = randf_range(1.2, 2.4)
			desired = to_player.normalized().cross(Vector3.UP) * _strafe_sign
	else:
		desired = to_player.normalized()
	# separation from other robots
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		var off: Vector3 = global_position - other.global_position
		off.y = 0.0
		var d := off.length()
		if d > 0.01 and d < 1.7:
			push += off.normalized() * (1.7 - d)
	desired = (desired + push * 0.7).normalized() if (desired + push * 0.7).length() > 0.01 else Vector3.ZERO
	# obstacle probing
	if desired.length() > 0.1:
		var motion := desired * move_speed * delta * 2.0
		if test_move(global_transform, motion):
			var found := false
			for ang in [65.0, -65.0, 115.0, -115.0]:
				var alt := desired.rotated(Vector3.UP, deg_to_rad(ang))
				if not test_move(global_transform, alt * move_speed * delta * 2.0):
					desired = alt
					found = true
					break
			if not found:
				desired = Vector3.ZERO
	# stuck detection
	var moved := global_position.distance_to(_last_pos)
	if moved < 0.02 and move_speed > 0.5:
		_stuck_timer += delta
		if _stuck_timer > 0.7:
			_strafe_sign = -_strafe_sign
			_strafe_timer = 1.2
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0
	_last_pos = global_position
	var target_vel := desired * move_speed
	var accel := 16.0
	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)
	velocity.y -= 16.0 * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, -30.0, 30.0)
	global_position.z = clampf(global_position.z, -26.0, 26.0)
	# face the player when engaging, otherwise face movement
	var face := to_player.normalized() if see else desired.normalized()
	if face.length() > 0.05:
		var target_yaw := atan2(-face.x, -face.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 6.0)
	_animate(delta, Vector2(velocity.x, velocity.z).length())

func _attack_timer(delta: float) -> void:
	if _windup > 0.0:
		_windup -= delta
		if eye_light:
			eye_light.light_energy = lerpf(0.5, 4.5, 1.0 - clampf(_windup / 0.5, 0.0, 1.0))
		if _windup <= 0.0:
			_release_attack()
		return
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_fire_volley()
			_burst_left -= 1
			_burst_timer = 0.14
			if _burst_left <= 0:
				_cooldown = fire_cooldown
		return
	_cooldown -= delta
	if _cooldown <= 0.0 and eye_light:
		eye_light.light_energy = 0.55 if not is_boss else 1.4
	if _cooldown <= 0.0 and player and not player.dead:
		var dist := global_position.distance_to(player.global_position)
		if dist < attack_range and _can_see_player():
			_windup = 0.5
			AudioManager.play_3d("enemy_charge", global_position + Vector3.UP * _eye_height(), -3.0, randf_range(0.95, 1.08))

func _release_attack() -> void:
	_windup = 0.0
	_burst_left = burst_size
	_burst_timer = 0.0
	if eye_light:
		eye_light.light_energy = 0.8

func _fire_volley() -> void:
	if player == null or not is_instance_valid(player):
		return
	var target: Vector3 = player.global_position + Vector3(0, 1.15, 0) + player.velocity * 0.12
	var n := projectile_count
	for i in n:
		var muzzle: Node3D = _muzzles[_muzzle_index % _muzzles.size()] if _muzzles.size() > 0 else null
		_muzzle_index += 1
		var origin := muzzle.global_position if muzzle else (global_position + Vector3.UP * _eye_height())
		var dir: Vector3 = (target - origin).normalized()
		if n > 1:
			var ang := (float(i) - float(n - 1) * 0.5) * 0.135
			dir = dir.rotated(Vector3.UP, ang)
		dir = dir.rotated(Vector3.UP, randf_range(-0.025, 0.025))
		dir = dir.rotated(Vector3.RIGHT, randf_range(-0.018, 0.018))
		var p = PROJECTILE.instantiate()
		p.direction = dir
		p.damage = damage
		p.speed = projectile_speed
		p.scale_visual = 1.35 if enemy_type == Type.TITAN else (1.0 if enemy_type == Type.JUGGERNAUT else 0.85)
		get_tree().current_scene.add_child(p)
		p.global_position = origin
		FX.muzzle_flash(origin, dir, 0.55 if enemy_type == Type.SCOUT else 0.9)
		AudioManager.play_3d("enemy_shot", origin, -2.0, randf_range(0.92, 1.08))

func _can_see_player() -> bool:
	if player == null:
		return false
	var from := global_position + Vector3.UP * _eye_height()
	var to := player.global_position + Vector3(0, 1.15, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.is_empty()

func _animate(delta: float, horiz_speed: float) -> void:
	var amp := clampf(horiz_speed / maxf(speed, 0.1), 0.0, 1.0)
	_walk_phase += delta * (3.0 + horiz_speed * 1.7)
	var s := sin(_walk_phase)
	var thigh_l: Node3D = _anim.get("ThighL")
	var thigh_r: Node3D = _anim.get("ThighR")
	var shin_l: Node3D = _anim.get("ShinL")
	var shin_r: Node3D = _anim.get("ShinR")
	var arm_l: Node3D = _anim.get("ArmL")
	var arm_r: Node3D = _anim.get("ArmR")
	var upper: Node3D = _anim.get("Upper")
	var head: Node3D = _anim.get("Head")
	if thigh_l:
		thigh_l.rotation.x = _base_rot["ThighL"].x + s * 0.52 * amp
	if thigh_r:
		thigh_r.rotation.x = _base_rot["ThighR"].x - s * 0.52 * amp
	if shin_l:
		shin_l.rotation.x = _base_rot["ShinL"].x - maxf(0.0, s) * 0.55 * amp
	if shin_r:
		shin_r.rotation.x = _base_rot["ShinR"].x - maxf(0.0, -s) * 0.55 * amp
	if arm_l:
		arm_l.rotation.x = _base_rot["ArmL"].x - s * 0.16 * amp
	if arm_r:
		arm_r.rotation.x = _base_rot["ArmR"].x + s * 0.16 * amp
	if upper:
		upper.position.y = _base_pos["Upper"].y + absf(sin(_walk_phase * 2.0)) * 0.028 * amp
	if head:
		head.rotation.y = sin(_time * 0.8) * 0.09
	if _windup > 0.0:
		model_root.rotation.x = lerpf(model_root.rotation.x, -0.06, delta * 8.0)
	else:
		model_root.rotation.x = lerpf(model_root.rotation.x, 0.0, delta * 8.0)

func take_hit(dmg: float, headshot: bool, dir: Vector3, point: Vector3) -> void:
	if dying or spawn_timer > 0.0:
		return
	hp -= dmg
	health_changed.emit(maxf(hp, 0.0), max_hp)
	AudioManager.play_3d("enemy_hit", point, -3.0, randf_range(0.9, 1.12))
	_flash(0.7 if headshot else 0.4)
	velocity += dir * (0.5 if not is_boss else 0.15)
	if is_boss and not _summoned and hp <= max_hp * 0.6:
		_summoned = true
		AudioManager.play_3d("boss_roar", global_position, 0.0, 0.9)
		summon_requested.emit(global_position)
		FX.spawn_burst(global_position + Vector3.UP * 2.0, Color(1.0, 0.1, 0.05), 26)
	if hp <= 0.0:
		_die(headshot)

func _flash(alpha: float) -> void:
	if overlay_mat == null:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	overlay_mat.albedo_color.a = alpha
	_flash_tween = create_tween()
	_flash_tween.tween_property(overlay_mat, "albedo_color:a", 0.0, 0.18)

func _die(headshot: bool) -> void:
	if dying:
		return
	dying = true
	combat_active = false
	collision_layer = 0
	collision_mask = 0
	for hb in hitboxes.get_children():
		if hb is Area3D:
			hb.set_deferred("monitorable", false)
	AudioManager.play_3d("enemy_death", global_position, 0.0, randf_range(0.88, 1.08) if is_boss else randf_range(0.96, 1.08))
	FX.spawn_burst(global_position + Vector3.UP * _eye_height() * 0.65, _eye_color(), 24 if is_boss else 13)
	FX.smoke(global_position + Vector3.UP, 1.4 if is_boss else 0.7)
	var l := OmniLight3D.new()
	l.light_color = _eye_color()
	l.light_energy = 5.0 if is_boss else 2.0
	l.omni_range = 6.0 if is_boss else 3.0
	l.position = global_position + Vector3.UP * 1.2
	l.shadow_enabled = false
	get_tree().current_scene.add_child(l)
	var lt := l.create_tween()
	lt.tween_property(l, "light_energy", 0.0, 0.55)
	lt.tween_callback(l.queue_free)
	died.emit(self, score_value, headshot)
	remove_from_group("enemies")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model_root, "rotation:x", deg_to_rad(78.0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(model_root, "position:y", -0.55, 0.9)
	tw.tween_property(model_root, "scale", model_root.scale * 0.92, 0.9)
	if eye_light:
		tw.tween_property(eye_light, "light_energy", 0.0, 0.4)
	overlay_mat.albedo_color = Color(0.05, 0.04, 0.035, 0.85)
	tw.chain().tween_callback(queue_free)

func set_combat(value: bool) -> void:
	combat_active = value
	if not value:
		_windup = 0.0
		_burst_left = 0
