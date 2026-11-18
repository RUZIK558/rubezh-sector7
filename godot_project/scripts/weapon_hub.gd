extends Node3D
## Owns all viewmodels and handles 1–5 / mouse-wheel weapon switching.

signal ammo_changed(mag: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished
signal hit_confirmed(headshot: bool)
signal fired
signal weapon_name_changed(label: String)

const WEAPON_SCRIPT := preload("res://scripts/weapon.gd")

var player = null
var weapons: Array[Node] = []
var current_index := 0
var enabled := false
var total_shots := 0
var total_hits := 0
var total_headshots := 0

var ads_amount: float:
	get:
		return float(_cur().get("ads_amount")) if not weapons.is_empty() else 0.0
var reloading: bool:
	get:
		return bool(_cur().get("reloading")) if not weapons.is_empty() else false
var mag: int:
	get:
		return int(_cur().get("mag")) if not weapons.is_empty() else 0
var reserve: int:
	get:
		return int(_cur().get("reserve")) if not weapons.is_empty() else 0
var shots: int:
	get:
		return total_shots
var hits: int:
	get:
		return total_hits
var headshots: int:
	get:
		return total_headshots
var is_melee: bool:
	get:
		return bool(_cur().get("is_melee")) if not weapons.is_empty() else false

func _ready() -> void:
	for i in 3:
		var w = WEAPON_SCRIPT.new()
		w.kind = i
		w.player = player
		w.name = "Weapon%d" % i
		add_child(w)
		weapons.append(w)
		w.ammo_changed.connect(_on_weapon_ammo)
		w.reload_started.connect(reload_started.emit)
		w.reload_finished.connect(reload_finished.emit)
		w.hit_confirmed.connect(_on_hit)
		w.fired.connect(_on_fired)
	_select(0)

func _on_fired() -> void:
	total_shots += 1
	fired.emit()

func _on_hit(headshot: bool) -> void:
	total_hits += 1
	if headshot:
		total_headshots += 1
	hit_confirmed.emit(headshot)

func _cur() -> Node:
	if weapons.is_empty():
		return self
	return weapons[clampi(current_index, 0, weapons.size() - 1)]

func _on_weapon_ammo(m: int, r: int) -> void:
	ammo_changed.emit(m, r)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or weapons.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.keycode
		if code >= KEY_1 and code <= KEY_3:
			_select(code - KEY_1)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select((current_index + weapons.size() - 1) % weapons.size())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select((current_index + 1) % weapons.size())

func _select(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	for w in weapons:
		w.set_enabled(false)
	current_index = index
	var active = weapons[index]
	active.player = player
	active.set_enabled(true)
	weapon_name_changed.emit(str(active.get("weapon_label")))
	ammo_changed.emit(int(active.get("mag")), int(active.get("reserve")))

func set_enabled(value: bool) -> void:
	enabled = value
	if not weapons.is_empty():
		weapons[current_index].set_enabled(value)

func add_look(rel: Vector2) -> void:
	if not weapons.is_empty():
		weapons[current_index].add_look(rel)

func try_fire() -> void:
	_cur().try_fire()

func start_reload() -> void:
	_cur().start_reload()

func add_reserve(amount: int) -> void:
	for w in weapons:
		w.add_reserve(amount)
	ammo_changed.emit(mag, reserve)

func get_reload_fraction() -> float:
	return float(_cur().get_reload_fraction())

func reset_weapon() -> void:
	total_shots = 0
	total_hits = 0
	total_headshots = 0
	for w in weapons:
		w.reset_weapon()
	_select(0)

func get_knife_damage() -> float:
	if weapons.size() > 2:
		return float(weapons[2].get_melee_damage())
	return 65.0

func get_current_label() -> String:
	return str(_cur().get("weapon_label"))

func apply_upgrade(id: String) -> void:
	for w in weapons:
		w.apply_upgrade(id)
	ammo_changed.emit(mag, reserve)

func refill_all() -> void:
	for w in weapons:
		w.add_reserve(999)
	ammo_changed.emit(mag, reserve)
