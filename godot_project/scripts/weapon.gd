extends Node3D
## Universal viewmodel: AK rifle, two pistols and two knives.
## Stats, geometry and animations are selected by `kind`.

signal ammo_changed(mag: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished
signal hit_confirmed(headshot: bool)
signal fired

enum Kind { AK, PM9, KLIN }

const MODELS := [
	preload("res://assets/models/ak47_fps.glb"),
	preload("res://assets/models/pistol_pm9.glb"),
	preload("res://assets/models/knife_klin.glb"),
]

const CFG := [
	{ # 0 — AK-47
		"label": "АК-47 // 7,62×39", "mag": 30, "reserve": 120, "interval": 0.1,
		"reload": 2.25, "damage": 34.0, "head": 2.5, "range": 250.0,
		"spread_ads": 0.16, "spread_hip": 0.85, "recoil": 0.72, "yaw": 0.28,
		"base": Vector3(0.10, -0.155, -0.58), "ads": Vector3(0.0, -0.085, -0.52),
		"scale": 0.9, "model_yaw": -90.0, "muzzle": Vector3(-0.50, 0.03, 0.0),
		"auto": true, "melee": false, "shot": "shot_1", "reload_sfx": "reload_out",
		"mag_node": "AK_Magazine", "slide_node": "AK_Bolt", "melee_range": 0.0,
	},
	{ # 1 — PM-9
		"label": "ПИСТОЛЕТ PM-9 // 9×19", "mag": 15, "reserve": 90, "interval": 0.17,
		"reload": 1.55, "damage": 28.0, "head": 2.0, "range": 140.0,
		"spread_ads": 0.20, "spread_hip": 1.05, "recoil": 1.0, "yaw": 0.20,
		"base": Vector3(0.10, -0.145, -0.42), "ads": Vector3(0.0, -0.095, -0.38),
		"scale": 1.35, "model_yaw": -90.0, "muzzle": Vector3(-0.21, 0.025, 0.0),
		"auto": false, "melee": false, "shot": "pistol_shot", "reload_sfx": "pistol_reload",
		"mag_node": "Magazine", "slide_node": "Slide", "melee_range": 0.0,
	},
	{ # 2 — Klin knife
		"label": "НОЖ «КЛИН» // БОЕВОЙ", "mag": -1, "reserve": -1, "interval": 0.44,
		"reload": 0.0, "damage": 65.0, "head": 1.6, "range": 20.0,
		"spread_ads": 0.0, "spread_hip": 0.0, "recoil": 0.0, "yaw": 0.0,
		"base": Vector3(0.10, -0.10, -0.50), "ads": Vector3(0.06, -0.08, -0.46),
		"scale": 1.4, "model_yaw": -90.0, "muzzle": Vector3.ZERO,
		"auto": false, "melee": true, "shot": "knife_swing", "reload_sfx": "",
		"mag_node": "", "slide_node": "", "melee_range": 2.4,
	},
]

@export var kind: int = Kind.AK

var player = null
var camera: Camera3D
var model: Node3D
var muzzle: Node3D
var mag_node: Node3D
var slide_node: Node3D

var mag := 30
var reserve := 120
var enabled := false
var reloading := false
var reload_timer := 0.0
var ads := false
var ads_amount := 0.0
var shots := 0
var hits := 0
var headshots := 0
var is_melee := false
var weapon_label := ""
var damage_mult := 1.0
var mag_size := 30
var spread_mult := 1.0

var _cfg: Dictionary = {}
var _cooldown := 0.0
var _empty_cd := 0.0
var _kick := 0.0
var _sway := Vector2.ZERO
var _reload_pose := 0.0
var _slash := 0.0
var _slash_sign := 1.0
var _base_pos := Vector3.ZERO
var _ads_pos := Vector3.ZERO
var _mag_base := Vector3.ZERO
var _slide_base := Vector3.ZERO
var _bob := 0.0

func _ready() -> void:
	_cfg = CFG[clampi(kind, 0, CFG.size() - 1)]
	weapon_label = str(_cfg["label"])
	is_melee = bool(_cfg["melee"])
	var node: Node = get_parent()
	while node and not (node is Camera3D):
		node = node.get_parent()
	camera = node as Camera3D
	model = MODELS[clampi(kind, 0, MODELS.size() - 1)].instantiate()
	add_child(model)
	model.rotation_degrees.y = float(_cfg["model_yaw"])
	model.scale = Vector3.ONE * float(_cfg["scale"])
	model.position = Vector3.ZERO
	_base_pos = _cfg["base"]
	_ads_pos = _cfg["ads"]
	position = _base_pos
	mag_size = int(_cfg["mag"])
	mag = mag_size
	reserve = int(_cfg["reserve"])
	if str(_cfg["mag_node"]) != "":
		mag_node = model.find_child(str(_cfg["mag_node"]), true, false)
	if str(_cfg["slide_node"]) != "":
		slide_node = model.find_child(str(_cfg["slide_node"]), true, false)
	if mag_node:
		_mag_base = mag_node.position
	if slide_node:
		_slide_base = slide_node.position
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	model.add_child(muzzle)
	muzzle.position = _cfg["muzzle"]
	_set_shadows_off(model)

func _set_shadows_off(node: Node) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	if not enabled:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_empty_cd = maxf(0.0, _empty_cd - delta)
	_kick = lerpf(_kick, 0.0, delta * 12.0)
	_sway = _sway.lerp(Vector2.ZERO, clampf(delta * 8.0, 0, 1))
	_bob += delta
	var want_ads := Input.is_action_pressed("aim") and not reloading
	ads = want_ads
	ads_amount = move_toward(ads_amount, 1.0 if ads else 0.0, delta * 7.0)
	var base := _base_pos.lerp(_ads_pos, ads_amount)
	var speed := 0.0
	if player:
		speed = Vector2(player.velocity.x, player.velocity.z).length()
	var bob_amt := clampf(speed / 7.0, 0, 1) * (1.0 - ads_amount * 0.75)
	var bob_vec := Vector3(sin(_bob * 5.5) * 0.006, sin(_bob * 11.0) * 0.004, 0) * bob_amt
	var sway_vec := Vector3(-_sway.x * 0.00055, _sway.y * 0.00045, 0)
	var reload_vec := Vector3(0, -0.115 * _reload_pose, 0)
	var slash_vec := Vector3(-0.10 * _slash, 0.03 * _slash, 0) * _slash_sign
	position = position.lerp(base + bob_vec + sway_vec + reload_vec + slash_vec + Vector3(0, 0, _kick * 0.035), delta * 14.0)
	rotation.x = lerpf(rotation.x, _kick * 0.055 + (_sway.y * 0.0003) - 0.14 * _reload_pose, delta * 12.0)
	rotation.z = lerpf(rotation.z, -_sway.x * 0.0004 + 0.32 * _reload_pose + 0.85 * _slash * _slash_sign, delta * 12.0)
	rotation.y = lerpf(rotation.y, -0.28 * _slash * _slash_sign, delta * 12.0)
	if reloading:
		_update_reload(delta)
	var wants_fire := false
	if bool(_cfg["auto"]):
		wants_fire = Input.is_action_pressed("fire")
	else:
		wants_fire = Input.is_action_just_pressed("fire")
	if wants_fire and _cooldown <= 0.0:
		try_fire()
	if Input.is_action_just_pressed("reload") and not is_melee:
		start_reload()

func _update_reload(delta: float) -> void:
	reload_timer -= delta
	if reload_timer <= 0.0:
		_finish_reload()

func try_fire() -> void:
	if reloading or not enabled or _cooldown > 0.0:
		return
	if is_melee:
		_melee_attack()
		return
	if mag <= 0:
		if reserve > 0:
			start_reload()
		else:
			if _empty_cd <= 0.0:
				AudioManager.play("empty", 0.0, randf_range(0.96, 1.04))
				_empty_cd = 0.35
		return
	_cooldown = float(_cfg["interval"])
	mag -= 1
	shots += 1
	_kick = minf(1.4, _kick + (0.85 if is_melee == false else 0.0))
	ammo_changed.emit(mag, reserve)
	fired.emit()
	AudioManager.play(str(_cfg["shot"]), -1.0, randf_range(0.96, 1.035))
	_slide_kick()
	var spread_deg := (float(_cfg["spread_ads"]) if ads_amount > 0.6 else float(_cfg["spread_hip"])) * spread_mult
	var is_crouch: bool = player != null and Input.is_action_pressed("crouch")
	if is_crouch:
		spread_deg *= 0.65
	if player:
		var speed := Vector2(player.velocity.x, player.velocity.z).length()
		spread_deg += minf(speed / 7.0, 1.0) * 0.55
	var from := camera.global_position
	var dir := -camera.global_basis.z
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var s := tan(deg_to_rad(spread_deg))
	dir = (dir + right * randf_range(-s, s) + up * randf_range(-s, s)).normalized()
	var to := from + dir * float(_cfg["range"])
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 8)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var hit_pos := to
	var hit := false
	var headshot := false
	if not result.is_empty():
		hit_pos = result.position
		var collider = result.collider
		if collider is Area3D and collider.has_method("apply_hit"):
			headshot = bool(collider.get("headshot"))
			var dmg := float(_cfg["damage"]) * damage_mult * (float(_cfg["head"]) if headshot else 1.0)
			collider.apply_hit(dmg, dir, hit_pos, headshot)
			hit = true
			FX.hit_spark(hit_pos, result.normal, headshot)
		else:
			if collider.has_method("take_damage"):
				collider.take_damage(float(_cfg["damage"]) * damage_mult, false, hit_pos)
				hit = true
			var metal := collider is StaticBody3D and str(collider.get_meta("surface", "")) == "metal"
			FX.impact(hit_pos, result.normal, metal)
			FX.hit_spark(hit_pos, result.normal, false)
	else:
		hit_pos = from + dir * minf(70.0, float(_cfg["range"]))
	var muzzle_pos := muzzle.global_position
	FX.tracer(muzzle_pos, hit_pos)
	FX.muzzle_flash(muzzle_pos, dir, 0.7 if kind == Kind.AK else 0.45)
	FX.shell(muzzle_pos, dir, right)
	var recoil_pitch := float(_cfg["recoil"]) * (0.64 if ads_amount > 0.6 else 1.0)
	var recoil_yaw := randf_range(-float(_cfg["yaw"]), float(_cfg["yaw"]))
	if player:
		player.add_recoil(recoil_pitch, recoil_yaw)
		player.add_trauma(0.045 if ads_amount < 0.6 else 0.028)
	if hit:
		hits += 1
		if headshot:
			headshots += 1
			AudioManager.play("headshot", -2.0, randf_range(0.97, 1.04))
		hit_confirmed.emit(headshot)

func _melee_attack() -> void:
	_cooldown = float(_cfg["interval"])
	shots += 1
	_slash_sign = -_slash_sign if _slash > 0.05 else _slash_sign
	fired.emit()
	AudioManager.play("knife_swing", -2.0, randf_range(0.96, 1.04))
	var tw := create_tween()
	tw.tween_property(self, "_slash", 1.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_slash", 0.0, float(_cfg["interval"]) - 0.10).set_trans(Tween.TRANS_SINE)
	var from := camera.global_position
	var dir := -camera.global_basis.z
	var to := from + dir * float(_cfg["melee_range"])
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 8)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var hit_pos: Vector3 = result.position
	var collider = result.collider
	var headshot := false
	var damage := float(_cfg["damage"]) * damage_mult
	if collider is Area3D and collider.has_method("apply_hit"):
		headshot = bool(collider.get("headshot"))
		damage *= float(_cfg["head"]) if headshot else 1.0
		collider.apply_hit(damage, dir, hit_pos, headshot)
		hits += 1
		if headshot:
			headshots += 1
	elif collider.has_method("take_damage"):
		collider.take_damage(damage, false, hit_pos)
		hits += 1
	else:
		return
	AudioManager.play("knife_hit", -3.0, randf_range(0.94, 1.06))
	FX.hit_spark(hit_pos, result.normal, headshot)
	FX.spawn_burst(hit_pos, Color(1.0, 0.75, 0.4), 4)
	hit_confirmed.emit(headshot)

func _slide_kick() -> void:
	if slide_node == null:
		return
	var axis := "position:x"
	if kind == Kind.AK:
		axis = "position:x"
	var tw := create_tween()
	tw.tween_property(slide_node, axis, _slide_base.x + (0.075 if kind == Kind.AK else 0.035), 0.045)
	tw.tween_property(slide_node, axis, _slide_base.x, 0.10)

func start_reload() -> void:
	if is_melee or reloading or mag >= mag_size or reserve <= 0 or not enabled:
		return
	reloading = true
	reload_timer = float(_cfg["reload"])
	ads = false
	ads_amount = 0.0
	AudioManager.play(str(_cfg["reload_sfx"]), -2.0, randf_range(0.98, 1.02))
	reload_started.emit(reload_timer)
	create_tween().tween_property(self, "_reload_pose", 1.0, 0.22)
	if mag_node:
		var mtw := create_tween()
		mtw.tween_property(mag_node, "position:y", _mag_base.y - 0.24, 0.22).set_delay(0.20)
		mtw.tween_interval(reload_timer * 0.55)
		mtw.tween_property(mag_node, "position:y", _mag_base.y, 0.16)
	if slide_node and kind != Kind.AK:
		var stw := create_tween()
		stw.tween_property(slide_node, "position:x", _slide_base.x + 0.045, 0.12).set_delay(reload_timer * 0.7)
		stw.tween_property(slide_node, "position:x", _slide_base.x, 0.10)

func _finish_reload() -> void:
	var need := mag_size - mag
	var take := mini(need, reserve)
	mag += take
	reserve -= take
	reloading = false
	reload_timer = 0.0
	AudioManager.play("reload_in", -1.0, randf_range(0.98, 1.02))
	ammo_changed.emit(mag, reserve)
	reload_finished.emit()
	if mag_node:
		mag_node.position = _mag_base
	if slide_node:
		slide_node.position = _slide_base
	create_tween().tween_property(self, "_reload_pose", 0.0, 0.16)

func add_reserve(amount: int) -> void:
	if is_melee:
		return
	reserve = mini(300, reserve + amount)
	ammo_changed.emit(mag, reserve)

func get_reload_fraction() -> float:
	if not reloading or float(_cfg["reload"]) <= 0.0:
		return 0.0
	return clampf(1.0 - reload_timer / float(_cfg["reload"]), 0.0, 1.0)

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	if not value:
		ads = false
		reloading = false
		reload_timer = 0.0
		_reload_pose = 0.0
		_slash = 0.0
		if mag_node:
			mag_node.position = _mag_base
		if slide_node:
			slide_node.position = _slide_base

func add_look(rel: Vector2) -> void:
	_sway += rel

func reset_weapon() -> void:
	mag_size = int(_cfg["mag"])
	damage_mult = 1.0
	spread_mult = 1.0
	mag = mag_size
	reserve = int(_cfg["reserve"])
	reloading = false
	reload_timer = 0.0
	ads = false
	ads_amount = 0.0
	shots = 0
	hits = 0
	headshots = 0
	_cooldown = 0.0
	_kick = 0.0
	_sway = Vector2.ZERO
	_reload_pose = 0.0
	_slash = 0.0
	position = _base_pos
	rotation = Vector3.ZERO
	if mag_node:
		mag_node.position = _mag_base
	if slide_node:
		slide_node.position = _slide_base
	ammo_changed.emit(mag, reserve)


func apply_upgrade(id: String) -> void:
	match id:
		"damage":
			damage_mult += 0.15
		"extmag":
			if kind == Kind.AK:
				mag_size = 45
				mag = mini(mag_size, mag + 15)
		"pistol_precision":
			if kind == Kind.PM9:
				spread_mult = 0.55
		"sharp":
			if is_melee:
				damage_mult += 0.5
	ammo_changed.emit(mag, reserve)
