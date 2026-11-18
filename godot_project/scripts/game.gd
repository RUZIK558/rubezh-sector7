extends Node3D
## Game director: state machine, waves, scoring, drops and the orbiting menu camera.

const PLAYER := preload("res://scenes/player.tscn")
const ENEMY := preload("res://scenes/enemy.tscn")
const PICKUP := preload("res://scenes/pickup.tscn")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const MAIN_MENU := preload("res://scripts/ui/main_menu.gd")
const PAUSE_MENU := preload("res://scripts/ui/pause_menu.gd")
const SETTINGS_PANEL := preload("res://scripts/ui/settings_panel.gd")
const RESULTS_SCREEN := preload("res://scripts/ui/results_screen.gd")
const SHOP_PANEL := preload("res://scripts/ui/shop_panel.gd")

enum State { MENU, PLAYING, PAUSED, SETTINGS, SHOP, RESULTS }

const WAVE_NAMES := [
	"РАЗВЕДКА", "НАЖИМ", "РЫВОК", "ОСАДА", "ТИТАН",
	"КОНТРРАЗВЕДКА", "ШТУРМ", "ЗАСЕКА", "ПЛОТНЫЙ ОГОНЬ", "ТИТАН МК-II",
	"ОХОТА", "ВЗЛОМ", "ЛАВИНА", "ЖЕЛЕЗНЫЙ ВАЛ", "ТИТАН МК-III",
	"ПОСЛЕДНИЙ РУБЕЖ", "ТОТАЛЬНАЯ ВОЙНА", "ШТОРМ", "ФИНАЛЬНЫЙ НАЖИМ", "ТИТАН-ОМЕГА",
]
const WAVE_COUNT := 20

func _wave_def(index: int) -> Dictionary:
	var i := clampi(index, 1, WAVE_COUNT)
	var tier := (i - 1) / 5 + 1
	var boss := i % 5 == 0
	var name: String = WAVE_NAMES[i - 1]
	if boss:
		return {"name": name, "scouts": 5 + tier * 2, "juggs": 2 + tier,
			"boss": true, "tier": tier, "interval": maxf(0.5, 1.15 - float(i) * 0.025)}
	return {"name": name, "scouts": mini(6 + i, 17), "juggs": mini(1 + i / 2, 7),
		"boss": false, "tier": 1, "interval": maxf(0.48, 1.2 - float(i) * 0.035)}

@onready var arena: Node3D = $Arena
@onready var menu_camera: Camera3D = $MenuCamera
@onready var ui: CanvasLayer = $UI

var state: State = State.MENU
var player = null
var hud = null
var main_menu = null
var pause_menu = null
var settings_panel = null
var results_screen = null
var shop_panel = null

var score := 0
var combo := 1.0
var combo_timer := 0.0
var kills := 0
var headshots := 0
var wave_index := -1
var run_time := 0.0
var credits := 0
var ending := false

var _alive: Array[Node] = []
var _spawn_queue: Array[int] = []
var _spawn_timer := 0.0
var _intermission := 0.0
var _menu_angle := 0.4
var _menu_time := 0.0
var _settings_return: State = State.MENU
var _boss = null

func _ready() -> void:
	($Moon as DirectionalLight3D).rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	_build_ui()
	AudioManager.play_music("menu")
	main_menu.enter()
	menu_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_ui() -> void:
	hud = HUD_SCRIPT.new()
	hud.name = "HUD"
	hud.visible = false
	ui.add_child(hud)

	main_menu = MAIN_MENU.new()
	main_menu.name = "MainMenu"
	ui.add_child(main_menu)
	main_menu.start_requested.connect(start_game)
	main_menu.settings_requested.connect(_open_settings_from_menu)

	pause_menu = PAUSE_MENU.new()
	pause_menu.name = "PauseMenu"
	ui.add_child(pause_menu)
	pause_menu.visible = false
	pause_menu.resume_requested.connect(_resume_game)
	pause_menu.settings_requested.connect(_open_settings_from_pause)
	pause_menu.restart_requested.connect(_restart_game)
	pause_menu.menu_requested.connect(_go_to_menu)

	settings_panel = SETTINGS_PANEL.new()
	settings_panel.name = "SettingsPanel"
	ui.add_child(settings_panel)
	settings_panel.closed.connect(_on_settings_closed)

	results_screen = RESULTS_SCREEN.new()
	results_screen.name = "ResultsScreen"
	ui.add_child(results_screen)
	results_screen.restart_requested.connect(_restart_game)
	results_screen.menu_requested.connect(_go_to_menu)

	shop_panel = SHOP_PANEL.new()
	shop_panel.name = "ShopPanel"
	ui.add_child(shop_panel)
	shop_panel.buy_requested.connect(_on_buy)
	shop_panel.continue_requested.connect(_start_next_wave)

func _process(delta: float) -> void:
	if state == State.MENU:
		_menu_angle += delta * 0.055
		_menu_time += delta
		var r := 25.0 + sin(_menu_time * 0.21) * 2.0
		menu_camera.global_position = Vector3(sin(_menu_angle) * r, 7.5 + sin(_menu_time * 0.33) * 0.4, cos(_menu_angle) * r)
		menu_camera.look_at(Vector3(0.0, 1.35, 0.0))
		return
	if state != State.PLAYING:
		return
	run_time += delta
	if ending:
		return
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 1.0
			hud.set_score(score, combo)
	_spawn_timer -= delta
	if _spawn_queue.size() > 0 and _spawn_timer <= 0.0:
		_spawn_enemy(_spawn_queue.pop_front())
		_spawn_timer = float(_wave_def(wave_index + 1)["interval"]) * randf_range(0.75, 1.3)
	_hud_objective()
	if _spawn_queue.is_empty() and _alive.is_empty() and _spawn_timer < -0.4:
		_wave_cleared()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if settings_panel.visible:
			return
		if state == State.PLAYING:
			_pause_game()
		elif state == State.PAUSED:
			_resume_game()

# ------------------------------------------------------------------ run control
func start_game() -> void:
	if state == State.PLAYING:
		return
	_cleanup_run()
	_rebuild_arena()
	score = 0
	combo = 1.0
	combo_timer = 0.0
	kills = 0
	headshots = 0
	wave_index = -1
	run_time = 0.0
	credits = 0
	ending = false
	main_menu.visible = false
	results_screen.hide_screen()
	shop_panel.hide_panel()
	pause_menu.hide_menu()
	settings_panel.visible = false
	hud.visible = true
	player = PLAYER.instantiate()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0, 0.02, 12.0)
	player.reset_player(player.global_position, 0.0)
	player.health_changed.connect(hud.set_health)
	player.damaged.connect(func(_amount: float, source: Vector3): hud.damage_from(source))
	player.died.connect(_on_player_died)
	player.notice.connect(hud.notice)
	var weapon = player.get_weapon()
	weapon.ammo_changed.connect(hud.set_ammo)
	weapon.hit_confirmed.connect(_on_hit_confirmed)
	weapon.weapon_name_changed.connect(hud.set_weapon_name)
	hud.set_weapon_name(weapon.get_current_label())
	player.set_active(true)
	state = State.PLAYING
	AudioManager.play_music("combat")
	_start_wave(1)

func _cleanup_run() -> void:
	ending = true
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			_free_now(e)
	for p in get_tree().get_nodes_in_group("pickups"):
		if is_instance_valid(p):
			_free_now(p)
	for pr in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(pr):
			_free_now(pr)
	for c in get_children():
		if c.is_in_group("player"):
			_free_now(c)
	_alive.clear()
	_spawn_queue.clear()
	_boss = null
	hud.hide_boss()
	if is_instance_valid(player):
		player = null

func _free_now(node: Node) -> void:
	var parent := node.get_parent()
	if parent:
		parent.remove_child(node)
	node.queue_free()

func _rebuild_arena() -> void:
	if is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
	var a := Node3D.new()
	a.name = "Arena"
	a.set_script(preload("res://scripts/arena.gd"))
	add_child(a)
	arena = a

func _on_player_died() -> void:
	if ending:
		return
	_end_run(false)

func _pause_game() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player:
		player.set_active(false)
	pause_menu.show_menu()

func _resume_game() -> void:
	if state != State.PAUSED:
		return
	pause_menu.hide_menu()
	get_tree().paused = false
	state = State.PLAYING
	if player:
		player.set_active(true)

func _open_settings_from_menu() -> void:
	_settings_return = State.MENU
	state = State.SETTINGS
	settings_panel.open()

func _open_settings_from_pause() -> void:
	_settings_return = State.PAUSED
	state = State.SETTINGS
	settings_panel.open()

func _on_settings_closed() -> void:
	if state != State.SETTINGS:
		return
	state = _settings_return
	if state == State.PAUSED:
		pause_menu.first_button().grab_focus()
	elif state == State.MENU:
		main_menu.first_button().grab_focus()

func _restart_game() -> void:
	get_tree().paused = false
	start_game()

func _go_to_menu() -> void:
	get_tree().paused = false
	_cleanup_run()
	results_screen.hide_screen()
	shop_panel.hide_panel()
	pause_menu.hide_menu()
	settings_panel.visible = false
	hud.visible = false
	state = State.MENU
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_camera.current = true
	AudioManager.play_music("menu")
	main_menu.visible = true
	main_menu.enter()

# ------------------------------------------------------------------ waves
func _start_wave(index: int) -> void:
	wave_index = index - 1
	var def: Dictionary = _wave_def(index)
	_spawn_queue.clear()
	for i in int(def["scouts"]):
		_spawn_queue.append(0)
	for i in int(def["juggs"]):
		_spawn_queue.append(3 if (index % 4 == 0 and i == 0) else 1)
	if bool(def["boss"]):
		_spawn_queue.append(2)
	_spawn_queue.shuffle()
	_spawn_timer = 0.9
	hud.set_wave(index, WAVE_COUNT, str(def["name"]), _spawn_queue.size())
	var sub := "УНИЧТОЖЬТЕ ВСЕ ЦЕЛИ"
	if bool(def["boss"]):
		sub = "ОПАСНО // ШТУРМОВОЙ РОБОТ"
	hud.show_banner("ВОЛНА %d / %d" % [index, WAVE_COUNT], str(def["name"]) + "  ·  " + sub, 2.4,
			RubezhUI.AMBER if not bool(def["boss"]) else RubezhUI.RED)
	AudioManager.play("wave_start")
	if bool(def["boss"]):
		AudioManager.play_music("boss")
	else:
		AudioManager.play_music("combat")

func _wave_cleared() -> void:
	if wave_index >= WAVE_COUNT - 1:
		return
	var next := wave_index + 2
	credits += 50 + wave_index * 15
	hud.show_banner("ВОЛНА ОЧИЩЕНА", "КВАРТИРМЕЙСТЕР ОТКРЫТ", 2.4, RubezhUI.GREEN)
	AudioManager.play("wave_clear")
	_open_shop(next)

func _open_shop(next: int) -> void:
	if state != State.PLAYING:
		return
	state = State.SHOP
	if player:
		player.set_active(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	shop_panel.open(next, credits)

func _on_buy(id: String) -> void:
	var price := 0
	for item in shop_panel.ITEMS:
		if str(item["id"]) == id:
			price = int(item["price"])
			break
	if price <= 0 or credits < price:
		return
	credits -= price
	match id:
		"ammo":
			player.get_weapon().refill_all()
		"med":
			player.heal(player.max_health)
		"armor":
			player.max_health += 25.0
			player.heal(25.0)
		"damage", "extmag", "sharp", "pistol_precision":
			player.get_weapon().apply_upgrade(id)
	shop_panel.refresh(credits)
	AudioManager.play("ui_click")

func _start_next_wave() -> void:
	if state != State.SHOP:
		return
	shop_panel.hide_panel()
	if player:
		player.set_active(true)
	state = State.PLAYING
	_start_wave(wave_index + 2)

func _spawn_enemy(type: int) -> void:
	if state != State.PLAYING or arena == null:
		return
	var points: Array[Dictionary] = arena.spawn_points
	if points.is_empty():
		return
	var sp: Dictionary = points.pick_random()
	var e = ENEMY.instantiate()
	e.enemy_type = 2 if type == 2 else (1 if type >= 3 else type)
	e.elite = type == 3
	e.wave = wave_index + 1
	e.tier = int(_wave_def(wave_index + 1).get("tier", 1))
	var pos: Vector3 = sp["pos"] + Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7))
	add_child(e)
	e.global_position = pos
	e.rotation.y = float(sp["yaw"])
	e.died.connect(_on_enemy_died)
	e.summon_requested.connect(_on_summon_requested)
	if type == 2:
		_boss = e
		e.health_changed.connect(_on_boss_health)
		hud.show_boss(e.max_hp)
		var boss_names := ["ТИТАН", "ТИТАН МК-II", "ТИТАН МК-III", "ТИТАН-ОМЕГА"]
		var boss_name: String = boss_names[clampi(int(_wave_def(wave_index + 1).get("tier", 1)) - 1, 0, 3)]
		hud.set_boss_name(boss_name + " // ОСАДНЫЙ КЛАСС")
		hud.show_banner("ОБНАРУЖЕН «" + boss_name + "»", "ОПАСНО // УНИЧТОЖЬТЕ ЦЕЛЬ", 2.8, RubezhUI.RED)
		AudioManager.duck_music(8.0, 1.2)
	_alive.append(e)
	_hud_objective()

func _on_summon_requested(origin: Vector3) -> void:
	hud.notice("«ТИТАН» ВЫЗЫВАЕТ ПОДКРЕПЛЕНИЕ")
	for i in 3:
		var e = ENEMY.instantiate()
		e.enemy_type = 0
		e.wave = wave_index + 1
		var ang := TAU * float(i) / 3.0 + randf_range(-0.3, 0.3)
		var pos := origin + Vector3(sin(ang), 0, cos(ang)) * 4.5
		pos.x = clampf(pos.x, -18.0, 18.0)
		pos.z = clampf(pos.z, -16.0, 16.0)
		add_child(e)
		e.global_position = pos
		e.died.connect(_on_enemy_died)
		_alive.append(e)
	_hud_objective()

func _on_enemy_died(_enemy: Node, points: int, headshot: bool) -> void:
	if _alive.has(_enemy):
		_alive.erase(_enemy)
	kills += 1
	if headshot:
		headshots += 1
	combo = minf(3.0, combo + 0.2)
	combo_timer = 5.0
	var gained := int(float(points) * combo)
	score += gained
	credits += maxi(4, points / 10)
	hud.set_score(score, combo)
	hud.kill_popup(gained, headshot)
	_maybe_drop(_enemy.global_position)
	_hud_objective()
	if _enemy == _boss:
		_boss = null
		hud.hide_boss()
		for e in _alive:
			if is_instance_valid(e) and e.has_method("set_combat"):
				e.set_combat(false)
		_end_run(true)

func _on_boss_health(current: float, maximum: float) -> void:
	hud.update_boss(current, maximum)

func _on_hit_confirmed(headshot: bool) -> void:
	hud.show_hitmarker(headshot)
	AudioManager.play("hitmarker", -4.0 if headshot else 0.0)

func _maybe_drop(pos: Vector3) -> void:
	var roll := randf()
	if roll > 0.58:
		return
	var p = PICKUP.instantiate()
	p.kind = "ammo" if roll > 0.18 else "med"
	add_child(p)
	p.global_position = pos + Vector3(randf_range(-0.5, 0.5), 0.05, randf_range(-0.5, 0.5))

func _hud_objective() -> void:
	if hud and state == State.PLAYING:
		hud.set_objective(_alive.size() + _spawn_queue.size())

func _end_run(victory: bool) -> void:
	if ending:
		return
	ending = true
	state = State.RESULTS
	get_tree().paused = false
	if player:
		player.set_active(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play("victory" if victory else "defeat")
	AudioManager.stop_music(1.5)
	hud.hide_boss()
	shop_panel.hide_panel()
	var weapon = null
	if player:
		weapon = player.get_weapon()
	var data := {
		"score": score,
		"kills": kills,
		"headshots": headshots,
		"accuracy": 0.0 if weapon == null or weapon.shots == 0 else float(weapon.hits) / float(weapon.shots),
		"wave": wave_index + 1,
		"wave_total": WAVE_COUNT,
		"time": run_time,
	}
	await get_tree().create_timer(1.9).timeout
	if state == State.RESULTS:
		hud.visible = false
		results_screen.show_results(data, victory)
