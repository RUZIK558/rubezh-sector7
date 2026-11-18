class_name Player
extends CharacterBody3D
## First-person movement, camera feel, health and damage feedback.

signal health_changed(current: float, maximum: float)
signal died
signal damaged(amount: float, source: Vector3)
signal notice(text: String)

const WALK_SPEED := 5.6
const SPRINT_SPEED := 7.8
const CROUCH_SPEED := 2.8
const JUMP_VELOCITY := 5.2
const GRAVITY := 16.0
const MOUSE_BASE := 0.0023

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera

var max_health := 100.0
var health := 100.0
var active := false
var dead := false

var yaw := 0.0
var pitch := 0.0
var recoil_pitch := 0.0
var recoil_yaw := 0.0
var trauma := 0.0
var _shake_time := 0.0
var _time_since_damage := 99.0
var invuln := 0.0
var _bob_time := 0.0
var _bob_amount := 0.0
var _land_offset := 0.0
var _step_accum := 0.0
var _coyote := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _mv_input := Vector2.ZERO

var weapon = null

func _ready() -> void:
	add_to_group("player")
	var weapon_script = load("res://scripts/weapon_hub.gd")
	weapon = weapon_script.new()
	weapon.name = "Weapon"
	weapon.player = self
	camera.add_child(weapon)

func _unhandled_input(event: InputEvent) -> void:
	if not active or dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := 0.0023 * Settings.mouse_sensitivity
		var ads_mul := 1.0
		if weapon:
			ads_mul = 1.0 - weapon.ads_amount * 0.35
		yaw -= event.relative.x * sens * ads_mul
		pitch -= event.relative.y * sens * ads_mul
		pitch = clampf(pitch, -1.45, 1.45)
		if weapon:
			weapon.add_look(event.relative)

func _physics_process(delta: float) -> void:
	if not active:
		return
	_time_since_damage += delta
	invuln = maxf(0.0, invuln - delta)
	_regen(delta)
	_update_camera(delta)
	if dead:
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	_movement(delta)

func _movement(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = 0.12
	else:
		_coyote = maxf(0.0, _coyote - delta)
	if on_floor and not _was_on_floor and _fall_speed < -3.5:
		_land_offset = -0.075
		add_trauma(0.16)
		AudioManager.play("land", -2.0, randf_range(0.94, 1.05))
	_was_on_floor = on_floor
	_fall_speed = velocity.y

	var crouching := Input.is_action_pressed("crouch") and on_floor
	var aiming: bool = weapon != null and weapon.ads_amount > 0.5
	var sprinting := Input.is_action_pressed("sprint") and not crouching and not aiming and _mv_input.y < -0.2
	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED

	_mv_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(_mv_input.x, 0, _mv_input.y).rotated(Vector3.UP, yaw)
	var accel := 34.0 if on_floor else 10.0
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)

	if Input.is_action_just_pressed("jump") and (on_floor or _coyote > 0.0):
		velocity.y = JUMP_VELOCITY
		_coyote = 0.0
		AudioManager.play("jump", -8.0)
	if not on_floor:
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = -0.2

	move_and_slide()
	_clamp_to_arena()
	_footsteps(delta, speed)

func _footsteps(delta: float, speed: float) -> void:
	var horiz := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or horiz < 0.6:
		return
	_step_accum += horiz * delta
	var stride := 2.3 if speed > 6.0 else 2.0
	if _step_accum >= stride:
		_step_accum = 0.0
		var n := randi_range(1, 4)
		AudioManager.play("step_%d" % n, -3.0, randf_range(0.92, 1.06))

func _clamp_to_arena() -> void:
	global_position.x = clampf(global_position.x, -31.3, 31.3)
	global_position.z = clampf(global_position.z, -27.3, 27.3)

func _regen(delta: float) -> void:
	if dead:
		return
	if _time_since_damage > 10.0 and health < max_health:
		health = minf(max_health, health + 8.0 * delta)
		health_changed.emit(health, max_health)

func _update_camera(delta: float) -> void:
	var horiz := Vector2(velocity.x, velocity.z).length()
	var ads: float = weapon.ads_amount if weapon else 0.0
	# head bob
	var moving := horiz > 0.5 and is_on_floor()
	if moving:
		_bob_time += delta * (5.5 + horiz * 0.9)
		_bob_amount = lerpf(_bob_amount, clampf(horiz / 7.0, 0, 1) * 0.025 * (1.0 - ads * 0.6), delta * 8.0)
	else:
		_bob_amount = lerpf(_bob_amount, 0.0, delta * 6.0)
	var bob_y := sin(_bob_time * 2.0) * _bob_amount
	var bob_x := sin(_bob_time) * _bob_amount * 0.6
	_crouch_mix = lerpf(_crouch_mix, 1.0 if Input.is_action_pressed("crouch") else 0.0, delta * 9.0)
	var stand := lerpf(1.62, 1.08, _crouch_mix)
	head.position.y = stand + bob_y + _land_offset
	head.position.x = bob_x
	_land_offset = lerpf(_land_offset, 0.0, delta * 9.0)
	# recoil recovery
	recoil_pitch = lerpf(recoil_pitch, 0.0, delta * 7.0)
	recoil_yaw = lerpf(recoil_yaw, 0.0, delta * 7.0)
	# trauma shake
	trauma = clampf(trauma - delta * 1.9, 0.0, 1.0)
	_shake_time += delta
	var s := trauma * trauma
	var shake_p := sin(_shake_time * 43.0) * s * 1.15
	var shake_y := sin(_shake_time * 37.0 + 1.3) * s * 1.15
	var roll := -_mv_input.x * 0.018 * (1.0 - ads)
	rotation.y = yaw
	camera.rotation.x = pitch + recoil_pitch + deg_to_rad(shake_p)
	camera.rotation.y = recoil_yaw + deg_to_rad(shake_y)
	camera.rotation.z = roll
	var target_fov := 78.0 - 23.0 * ads
	if horiz > 6.0 and ads < 0.2:
		target_fov += 2.5
	camera.fov = lerpf(camera.fov, target_fov, delta * 9.0)

var _crouch_mix := 0.0

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func add_recoil(pitch_deg: float, yaw_deg: float) -> void:
	recoil_pitch += deg_to_rad(pitch_deg)
	recoil_yaw += deg_to_rad(yaw_deg)

func take_damage(amount: float, source := Vector3.ZERO) -> void:
	if dead or not active or invuln > 0.0:
		return
	health = maxf(0.0, health - amount)
	_time_since_damage = 0.0
	health_changed.emit(health, max_health)
	damaged.emit(amount, source)
	AudioManager.play("hurt", -4.0, randf_range(0.94, 1.06))
	add_trauma(clampf(amount / 45.0, 0.18, 0.75))
	if health <= 0.0:
		_die()

func _die() -> void:
	if dead:
		return
	dead = true
	active = false
	if weapon:
		weapon.set_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tw := create_tween().set_parallel(true)
	tw.tween_property(head, "position:y", 0.55, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(camera, "rotation:z", deg_to_rad(24.0), 1.1)
	died.emit()

func heal(amount: float) -> void:
	if dead:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)
	notice.emit("+%d ЗДОРОВЬЯ" % int(amount))

func add_ammo(amount: int) -> void:
	if weapon:
		weapon.add_reserve(amount)
	notice.emit("+%d ПАТРОНОВ" % amount)

func reset_player(pos: Vector3, look_yaw := 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	health = max_health
	dead = false
	pitch = 0.0
	yaw = look_yaw
	recoil_pitch = 0.0
	recoil_yaw = 0.0
	trauma = 0.0
	_time_since_damage = 99.0
	invuln = 1.2
	head.position = Vector3(0, 1.62, 0)
	camera.rotation = Vector3.ZERO
	_crouch_mix = 0.0
	if weapon:
		weapon.reset_weapon()
	health_changed.emit(health, max_health)

func set_active(value: bool) -> void:
	active = value
	if value:
		dead = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if weapon:
		weapon.set_enabled(value)

func get_weapon():
	return weapon

func get_reload_fraction() -> float:
	if weapon:
		return weapon.get_reload_fraction()
	return 0.0
