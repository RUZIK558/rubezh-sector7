extends Node3D
## Game director: state machine, waves, scoring, drops and the orbiting menu camera.

const PLAYER := preload("res://scenes/player.tscn")
const ENEMY := preload("res://scenes/enemy.tscn")
const PICKUP := preload("res://scenes/pickup.tscn")
const PROJECTILE := preload("res://scenes/projectile.tscn")
const SUPPLY_POD := preload("res://assets/models/supply_pod.glb")
const OPERATIVE := preload("res://assets/models/operative.glb")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const MAIN_MENU := preload("res://scripts/ui/main_menu.gd")
const PAUSE_MENU := preload("res://scripts/ui/pause_menu.gd")
const SETTINGS_PANEL := preload("res://scripts/ui/settings_panel.gd")
const RESULTS_SCREEN := preload("res://scripts/ui/results_screen.gd")
const SHOP_PANEL := preload("res://scripts/ui/shop_panel.gd")
const CONTROLS_PANEL := preload("res://scripts/ui/controls_panel.gd")

enum State { MENU, PLAYING, PAUSED, SETTINGS, SHOP, RESULTS }

const WAVE_NAMES := [
	"РАЗВЕДКА", "НАЖИМ", "РЫВОК", "ОСАДА", "ТИТАН",
	"КОНТРРАЗВЕДКА", "ШТУРМ", "ЗАСЕКА", "ПЛОТНЫЙ ОГОНЬ", "ТИТАН МК-II",
	"ОХОТА", "ВЗЛОМ", "ЛАВИНА", "ЖЕЛЕЗНЫЙ ВАЛ", "ТИТАН МК-III",
	"ПОСЛЕДНИЙ РУБЕЖ", "ТОТАЛЬНАЯ ВОЙНА", "ШТОРМ", "ФИНАЛЬНЫЙ НАЖИМ", "ТИТАН-ОМЕГА",
]
const WAVE_COUNT := 20

func _wave_def(index: int) -> Dictionary:
	var i := clampi(index, 1, wave_count)
	var tier := mini(int(float(i - 1) / 5.0) + 1, 10)
	var boss := i % 5 == 0
	var wave_name: String = WAVE_NAMES[(i - 1) % WAVE_NAMES.size()]
	if i > WAVE_NAMES.size():
		wave_name = "ВОЛНА %d // РЕЖИМ ОБОРОНЫ" % i
	if boss:
		return {"name": wave_name, "scouts": 5 + tier * 2, "juggs": 2 + tier,
			"boss": true, "tier": tier, "interval": maxf(0.5, 1.15 - float(i) * 0.025)}
	return {"name": wave_name, "scouts": mini(6 + i, 17), "juggs": mini(1 + int(i / 2.0), 7),
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
var controls_panel = null

var score := 0
var combo := 1.0
var combo_timer := 0.0
var kills := 0
var headshots := 0
var wave_index := -1
var run_time := 0.0
var credits := 0
var net_mode := 0  # 0 solo, 1 host, 2 client
var wave_count := 20
var _players: Array[Node] = []
var _net_sync_timer := 0.0
var _next_enemy_id := 1
var _remote_enemies: Dictionary = {}
var _remote_pickups: Dictionary = {}
var _remote_projectiles: Dictionary = {}
var _got_snapshot := false
var _last_remote_wave := -1
var _got_wave_banner := false
var _sent_input_debug := false
var _killed_self := false
var _debug_loop_timer := 0.0
var _faced_partner := false
var spectating = null
var _debug_pos_timer := 0.0
var ending := false

var _alive: Array[Node] = []
var _spawn_queue: Array[int] = []
var _spawn_timer := 0.0
var _menu_angle := 0.4
var _menu_time := 0.0
var _settings_return: State = State.MENU
var _boss = null
var _event_timer := 26.0

func _ready() -> void:
	($Moon as DirectionalLight3D).rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	_build_ui()
	AudioManager.play_music("menu")
	main_menu.enter()
	var args := OS.get_cmdline_args()
	var i := args.find("--host")
	if i != -1:
		call_deferred("_host_game")
	else:
		var j := args.find("--join")
		if j != -1 and args.size() > j + 1:
			call_deferred("_join_game", args[j + 1])
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
	main_menu.start_requested.connect(func(): start_game(0))
	main_menu.settings_requested.connect(_open_settings_from_menu)
	main_menu.quit_requested.connect(_quit_game)
	main_menu.host_requested.connect(_host_game)
	main_menu.join_requested.connect(_join_game)

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
	settings_panel.controls_requested.connect(func(): controls_panel.open())

	controls_panel = CONTROLS_PANEL.new()
	controls_panel.name = "ControlsPanel"
	ui.add_child(controls_panel)

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
	if OS.get_cmdline_args().has("--debug-loop"):
		_debug_loop_timer -= delta
		if _debug_loop_timer <= 0.0:
			_debug_loop_timer = 2.0
			print("COOP: loop net=", net_mode, " state=", state, " is_client=", Net.is_client, " NetPeer=", Net.peer, " treePeer=", multiplayer.multiplayer_peer, " status=", (multiplayer.get_connection_status() if multiplayer.multiplayer_peer else -9))
	if state == State.MENU:
		_menu_angle += delta * 0.055
		_menu_time += delta
		var r := 25.0 + sin(_menu_time * 0.21) * 2.0
		menu_camera.global_position = Vector3(sin(_menu_angle) * r, 7.5 + sin(_menu_time * 0.33) * 0.4, cos(_menu_angle) * r)
		menu_camera.look_at(Vector3(0.0, 1.35, 0.0))
		return
	var targs := OS.get_cmdline_args()
	var ti := targs.find("--teleport")
	if ti != -1 and targs.size() >= ti + 4 and player and state == State.PLAYING:
		player.global_position = Vector3(float(targs[ti+1]), float(targs[ti+2]), float(targs[ti+3]))
	if OS.get_cmdline_args().has("--hide-all") and player:
		for c in player.camera.find_children("*", "Node3D", true, false):
			c.visible = false
		for p2 in _players:
			var m := p2.get_node_or_null("OperativeModel")
			if m:
				m.visible = false
	if OS.get_cmdline_args().has("--auto-move") and player and state == State.PLAYING:
		Input.action_press("move_forward")
		Input.action_press("fire")
	if OS.get_cmdline_args().has("--kill-self") and player and state == State.PLAYING and not _killed_self:
		_killed_self = true
		player.invuln = 0.0
		player.take_damage(9999.0)
	if OS.get_cmdline_args().has("--spectate-look") and spectating and is_instance_valid(spectating):
		spectating.yaw += delta * 0.9
		spectating.rotation.y = spectating.yaw
	if OS.get_cmdline_args().has("--hide-hud"):
		hud.visible = false
	if OS.get_cmdline_args().has("--hide-weapon") and player and player.get_weapon():
		player.get_weapon().visible = false
	if OS.get_cmdline_args().has("--face-partner") and not _faced_partner and player and state == State.PLAYING:
		_faced_partner = true
		player.yaw = -PI / 2.0 if net_mode == 1 else PI / 2.0
		for p in _players:
			if p != player:
				p.yaw = PI / 2.0 if net_mode == 1 else -PI / 2.0
	if net_mode == 2 and Net.is_client:
		var real_id := multiplayer.get_unique_id()
		if real_id > 1 and real_id != Net.self_id:
			Net.self_id = real_id
			if player:
				player.peer_id = real_id
				player.global_position = _spawn_pos_for(real_id)
	if OS.get_cmdline_args().has("--debug-ray") and player:
		_debug_pos_timer -= delta
		if _debug_pos_timer <= 0.0:
			_debug_pos_timer = 2.0
			print("DEBUG RAY ", debug_ray())
	if OS.get_cmdline_args().has("--debug-state") and player:
		_debug_pos_timer -= delta
		if _debug_pos_timer <= 0.0:
			_debug_pos_timer = 2.0
			var cam: Camera3D = player.camera
			print("DEBUG state=", state, " me=", player.global_position, " cam=", cam.global_position, " rot=", cam.rotation, " pitch=", player.pitch, " net=", net_mode, " inp=", player.move_vector(), " vel=", player.velocity, " hubvis=", player.get_weapon().visible, " ray=", debug_ray(), " activecam=", (get_viewport().get_camera_3d().get_parent().name if get_viewport().get_camera_3d() else "NONE"), " campos=", (get_viewport().get_camera_3d().global_position if get_viewport().get_camera_3d() else Vector3.ZERO))
			for p2 in _players:
				if p2 != player:
					print("DEBUG partner=", p2.peer_id, " pos=", p2.global_position, " remote=", p2.network_remote)
	if net_mode == 1:
		_net_sync_timer -= delta
		if _net_sync_timer <= 0.0:
			_broadcast_snapshot()
			_net_sync_timer = 0.08
	elif net_mode == 2:
		_net_sync_timer -= delta
		if _net_sync_timer <= 0.0 and state == State.PLAYING:
			_send_client_input()
			_net_sync_timer = 0.05
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
	_event_timer -= delta
	if _event_timer <= 0.0 and net_mode != 2:
		_trigger_event()
		_event_timer = randf_range(28.0, 46.0)
	if net_mode != 2:
		_spawn_timer -= delta
		if _spawn_queue.size() > 0 and _spawn_timer <= 0.0:
			_spawn_enemy(_spawn_queue.pop_front())
			_spawn_timer = float(_wave_def(wave_index + 1)["interval"]) * randf_range(0.75, 1.3)
		if _spawn_queue.is_empty() and _alive.is_empty() and _spawn_timer < -0.4:
			_wave_cleared()
	_hud_objective()

func _unhandled_input(event: InputEvent) -> void:
	if spectating and is_instance_valid(spectating) and state == State.PLAYING:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var sens := 0.0023 * Settings.mouse_sensitivity
			spectating.yaw -= event.relative.x * sens
			spectating.pitch = clampf(spectating.pitch - event.relative.y * sens, -1.45, 1.45)
			spectating.rotation.y = spectating.yaw
			spectating.camera.rotation.x = spectating.pitch
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if settings_panel.visible:
			return
		if state == State.PLAYING:
			_pause_game()
		elif state == State.PAUSED:
			_resume_game()

# ------------------------------------------------------------------ run control
func start_game(mode: int = 0) -> void:
	if state == State.PLAYING:
		return
	net_mode = mode
	wave_count = 100 if mode != 0 else 20
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
	main_menu.hide_net_panel()
	results_screen.hide_screen()
	shop_panel.hide_panel()
	pause_menu.hide_menu()
	settings_panel.visible = false
	hud.visible = true
	_players.clear()
	player = _spawn_player(Net.self_id if net_mode == 2 else 1, _spawn_pos_for(Net.self_id if net_mode == 2 else 1), false)
	if net_mode == 1:
		for id in Net.connected_peers():
			if id != 1:
				_spawn_player(id, _spawn_pos_for(id), true)
	menu_camera.current = false
	player.camera.current = true
	player.camera.make_current()
	player.health_changed.connect(hud.set_health)
	player.damaged.connect(func(_amount: float, source: Vector3): hud.damage_from(source))
	player.notice.connect(hud.notice)
	var weapon = player.get_weapon()
	weapon.ammo_changed.connect(hud.set_ammo)
	weapon.hit_confirmed.connect(_on_hit_confirmed)
	weapon.weapon_name_changed.connect(hud.set_weapon_name)
	hud.set_weapon_name(weapon.get_current_label())
	player.set_active(true)
	state = State.PLAYING
	AudioManager.play_music("combat")
	if net_mode != 2:
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
	for th in get_tree().get_nodes_in_group("throwables"):
		if is_instance_valid(th):
			_free_now(th)
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

func _on_player_died(dead_player: Node = null) -> void:
	if ending or net_mode == 2:
		return
	if dead_player == player and net_mode != 0:
		for p2 in _players:
			if p2 != player and is_instance_valid(p2) and not p2.dead:
				_set_spectator(p2)
				hud.show_banner("НАБЛЮДЕНИЕ ЗА СОЮЗНИКОМ", "ВОЗВРАТ В СЛЕДУЮЩЕЙ ВОЛНЕ", 3.0, RubezhUI.AMBER)
				return
	for p in _players:
		if is_instance_valid(p) and not p.dead:
			var title := "ВЫ ПОГИБЛИ" if dead_player == player else "СОЮЗНИК ПОГИБ"
			hud.show_banner(title, "ВОЗРОЖДЕНИЕ В СЛЕДУЮЩЕЙ ВОЛНЕ", 2.4, RubezhUI.RED)
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

func _spawn_pos_for(peer_id: int) -> Vector3:
	var slots := [
		Vector3(-2.2, 0.02, 12.0),
		Vector3(2.2, 0.02, 12.0),
		Vector3(0.0, 0.02, 16.0),
		Vector3(0.0, 0.02, 8.0),
	]
	if peer_id == 1:
		return slots[0]
	return slots[1 + (abs(peer_id) % 3)]

func _spawn_player(peer_id: int, pos: Vector3, remote: bool) -> Node:
	var p = PLAYER.instantiate()
	p.name = "Player_%d" % peer_id
	add_child(p)
	p.peer_id = peer_id
	p.network_remote = remote
	if remote:
		print("COOP: operative model added for ", peer_id)
		var body := OPERATIVE.instantiate()
		body.name = "OperativeModel"
		body.rotation_degrees.y = 180.0
		p.add_child(body)
		for mi in body.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.global_position = pos
	p.reset_player(pos, 0.0)
	p.set_active(true)
	if remote and p.get_weapon():
		p.get_weapon().set_enabled(false)
		p.get_weapon().visible = false
	p.camera.current = not remote
	if not remote:
		p.camera.make_current()
	elif player and is_instance_valid(player):
		player.camera.make_current()
		menu_camera.current = false
	print("COOP: spawn peer=", peer_id, " remote=", remote, " pos=", p.global_position)
	p.died.connect(func(): _on_player_died(p))
	_players.append(p)
	return p

func _host_game() -> void:
	var err := Net.host()
	if err != OK:
		main_menu.set_net_status("НЕ УДАЛОСЬ СОЗДАТЬ СЕРВЕР: %d" % err)
		return
	Net.peer_joined.connect(_on_net_peer_joined)
	start_game(1)

func _join_game(ip: String) -> void:
	var err := Net.join(ip)
	if err != OK:
		main_menu.set_net_status("НЕ УДАЛОСЬ ПОДКЛЮЧИТЬСЯ: %d" % err)
		return
	start_game(2)

func _on_net_peer_joined(id: int) -> void:
	print("COOP: peer joined ", id, " mode=", net_mode)
	if net_mode == 1 and state != State.MENU:
		if not _find_player(id):
			_spawn_player(id, _spawn_pos_for(id), true)
		main_menu.set_net_status("ИГРОК %d ПОДКЛЮЧИЛСЯ" % id)

func _set_spectator(target: Node) -> void:
	spectating = target
	if target:
		target.camera.current = true
		target.camera.make_current()
		var model: Node = target.get_node_or_null("OperativeModel")
		if model:
			model.visible = false
		if target.get_weapon():
			target.get_weapon().set_enabled(false)
			target.get_weapon().visible = false
		hud.set_health(target.health, target.max_health)

func _find_player(peer_id: int) -> Node:
	for p in _players:
		if is_instance_valid(p) and int(p.peer_id) == peer_id:
			return p
	return null

func _quit_game() -> void:
	Settings.save_settings()
	get_tree().quit()

func _restart_game() -> void:
	get_tree().paused = false
	start_game()

func _go_to_menu() -> void:
	get_tree().paused = false
	if net_mode != 0:
		Net.reset()
		net_mode = 0
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
	for p in _players:
		if not is_instance_valid(p):
			continue
		if p.dead:
			p.reset_player(_spawn_pos_for(int(p.peer_id)), 0.0)
			p.health = maxf(1.0, p.max_health * 0.6)
			p.health_changed.emit(p.health, p.max_health)
			if net_mode == 1 and int(p.peer_id) != 1:
				rpc_id(int(p.peer_id), "rpc_revive", int(p.peer_id))
		else:
			p.ensure_min_health(0.45)
	if spectating and is_instance_valid(spectating):
		spectating.camera.current = false
		var old_model: Node = spectating.get_node_or_null("OperativeModel")
		if old_model:
			old_model.visible = true
	spectating = null
	if player and is_instance_valid(player):
		player.camera.current = true
		player.camera.make_current()
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
	_event_timer = randf_range(22.0, 34.0)
	hud.set_wave(index, wave_count, str(def["name"]), _spawn_queue.size())
	var sub := "УНИЧТОЖЬТЕ ВСЕ ЦЕЛИ"
	if bool(def["boss"]):
		sub = "ОПАСНО // ШТУРМОВОЙ РОБОТ"
	hud.show_banner("ВОЛНА %d / %d" % [index, wave_count], str(def["name"]) + "  ·  " + sub, 2.4,
			RubezhUI.AMBER if not bool(def["boss"]) else RubezhUI.RED)
	AudioManager.play("wave_start")
	if bool(def["boss"]):
		AudioManager.play_music("boss")
	else:
		AudioManager.play_music("combat")

func _wave_cleared() -> void:
	if wave_index >= wave_count - 1:
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
	if Net.is_client:
		rpc_id(1, "rpc_buy", id)
		return
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
			player.add_grenades(2)
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
	if Net.is_client:
		rpc_id(1, "rpc_continue")
		return
	if state != State.SHOP:
		return
	shop_panel.hide_panel()
	if player:
		player.set_active(true)
	state = State.PLAYING
	_start_wave(wave_index + 2)

func _trigger_event() -> void:
	if state != State.PLAYING or ending:
		return
	var roll := randi() % 3
	print("EVENT: triggered ", roll)
	match roll:
		0: _event_supply_drop()
		1: _event_artillery()
		2: _event_reinforcement()

func _event_supply_drop() -> void:
	hud.show_banner("СБРОС ПРИПАСОВ", "ГУМАНИТАРНЫЙ КОНТЕЙНЕР ПРИЗЕМЛИЛСЯ", 2.4, RubezhUI.GREEN)
	AudioManager.play("wave_clear")
	var pos := Vector3(randf_range(-22.0, 22.0), 8.0, randf_range(-18.0, 18.0))
	var pod = SUPPLY_POD.instantiate()
	add_child(pod)
	pod.global_position = pos
	var tw := create_tween()
	tw.tween_property(pod, "global_position:y", 0.05, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if not is_instance_valid(pod):
			return
		var pp: Vector3 = pod.global_position
		for i in 3:
			var p = PICKUP.instantiate()
			p.kind = "ammo" if i < 2 else "med"
			add_child(p)
			p.global_position = pp + Vector3(randf_range(-1.4, 1.4), 0.05, randf_range(-1.4, 1.4))
		FX.spawn_burst(pp + Vector3.UP * 0.5, Color(0.3, 1.0, 0.5), 14)
		AudioManager.play("pickup_ammo")
		pod.queue_free())

func _event_artillery() -> void:
	hud.show_banner("АРТИЛЛЕРИЙСКИЙ УДАР", "ВНИМАНИЕ — ОПАСНАЯ ЗОНА", 2.2, RubezhUI.RED)
	AudioManager.play("boss_roar", -6.0)
	var targets: Array[Vector3] = []
	for e in _alive:
		if is_instance_valid(e) and targets.size() < 4:
			targets.append(e.global_position)
	while targets.size() < 2:
		targets.append(Vector3(randf_range(-20.0, 20.0), 0, randf_range(-16.0, 16.0)))
	for target in targets:
		var pos := target
		var timer := get_tree().create_timer(1.6)
		timer.timeout.connect(func():
			if state != State.PLAYING:
				return
			var origin := pos + Vector3.UP * 0.4
			FX.explosion(origin, 1.3)
			AudioManager.play_3d("explosion", origin, 0.0)
			FX.shake(0.5)
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) and enemy.has_method("take_hit"):
					var d: float = enemy.global_position.distance_to(pos)
					if d < 5.0:
						enemy.take_hit(lerpf(110.0, 30.0, d / 5.0), false,
							(enemy.global_position - pos).normalized(), enemy.global_position + Vector3.UP))

func _event_reinforcement() -> void:
	hud.show_banner("ПОДКРЕПЛЕНИЕ ВРАГА", "ЭЛИТНЫЕ БОЕВЫЕ МАШИНЫ", 2.2, RubezhUI.RED)
	AudioManager.play("boss_roar", -8.0)
	for i in 3:
		_spawn_enemy(3)

func _spawn_enemy(type: int) -> void:
	if net_mode == 2 or state != State.PLAYING or arena == null:
		return
	var points: Array[Dictionary] = arena.spawn_points
	if points.is_empty():
		return
	var sp: Dictionary = points.pick_random()
	var e = ENEMY.instantiate()
	e.enemy_type = 2 if type == 2 else (1 if type >= 3 else type)
	e.elite = type == 3
	if net_mode == 1:
		e.net_id = _next_enemy_id
		_next_enemy_id += 1
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
	if net_mode == 2:
		return
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
	credits += maxi(4, int(float(points) / 10.0))
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
	if net_mode == 2:
		return
	var roll := randf()
	if roll > 0.58:
		return
	var p = PICKUP.instantiate()
	if Net.is_host:
		p.net_id = Net.alloc_id()
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
		"wave_total": wave_count,
		"time": run_time,
	}
	if net_mode == 1:
		var net_data := [score, kills, headshots, 0.0 if weapon == null or weapon.shots == 0 else float(weapon.hits) / float(weapon.shots),
			wave_index + 1, wave_count, run_time]
		rpc("rpc_finish", victory, net_data)
	await get_tree().create_timer(1.9).timeout
	if state == State.RESULTS:
		hud.visible = false
		results_screen.set_coop_mode(net_mode != 0)
		results_screen.show_results(data, victory)


# ------------------------------------------------------------------ network
func _send_client_input() -> void:
	if not Net.is_client or player == null:
		return
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if not _sent_input_debug:
		_sent_input_debug = true
		print("COOP: sending pose")
	rpc_id(1, "rpc_player_pose", Net.self_id,
		player.global_position.x, player.global_position.y, player.global_position.z,
		player.yaw, player.pitch)
	player.net_look = Vector2.ZERO

@rpc("any_peer", "call_remote", "reliable")
func rpc_input(data: Array) -> void:
	if not Net.is_host or data.size() < 12:
		return
	var id := multiplayer.get_remote_sender_id()
	var p := _find_player(id)
	print("COOP: input from ", id, " -> player ", (p.peer_id if p else -1))
	if p:
		p.set_remote_input(data)

func _broadcast_snapshot() -> void:
	var players_data := []
	for p in _players:
		if not is_instance_valid(p):
			continue
		players_data.append([int(p.peer_id), p.global_position.x, p.global_position.y, p.global_position.z,
			p.yaw, p.pitch, p.health, p.dead])
	var enemies_data := []
	for e in _alive:
		if not is_instance_valid(e) or int(e.net_id) <= 0:
			continue
		enemies_data.append([int(e.net_id), int(e.enemy_type), e.global_position.x, e.global_position.y,
			e.global_position.z, e.rotation.y, e.hp, e.elite])
	var pickups_data := []
	for pk in get_tree().get_nodes_in_group("pickups"):
		if is_instance_valid(pk) and int(pk.get("net_id")) > 0:
			pickups_data.append([int(pk.get("net_id")), str(pk.get("kind")),
				pk.global_position.x, pk.global_position.y, pk.global_position.z])
	var projectiles_data := []
	for pr in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(pr) and int(pr.get("net_id")) > 0:
			projectiles_data.append([int(pr.get("net_id")),
				pr.global_position.x, pr.global_position.y, pr.global_position.z,
				pr.direction.x, pr.direction.y, pr.direction.z, pr.scale_visual])
	rpc("rpc_snapshot", players_data, enemies_data, pickups_data, projectiles_data,
		[wave_index, score, credits, int(state), wave_count])

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_snapshot(players_data: Array, enemies_data: Array, pickups_data: Array, projectiles_data: Array, meta: Array) -> void:
	if not Net.is_client:
		return
	if not _got_snapshot:
		_got_snapshot = true
		print("COOP: first snapshot players=", players_data.size(), " enemies=", enemies_data.size(), " pickups=", pickups_data.size(), " projectiles=", projectiles_data.size())
	# players
	var seen: Array[int] = []
	for entry in players_data:
		var id := int(entry[0])
		seen.append(id)
		var target := _find_player(id)
		if target == null:
			target = _spawn_player(id, _spawn_pos_for(id), id != Net.self_id)
		if player and is_instance_valid(player):
			player.camera.make_current()
		var pos := Vector3(float(entry[1]), float(entry[2]), float(entry[3]))
		if id != Net.self_id:
			target.global_position = target.global_position.lerp(pos, 0.5)
		target.yaw = float(entry[4])
		target.pitch = float(entry[5])
		target.health = float(entry[6])
		target.dead = bool(entry[7])
		target.health_changed.emit(target.health, target.max_health)
		if spectating and target == spectating:
			hud.set_health(target.health, target.max_health)
	for p in _players.duplicate():
		if is_instance_valid(p) and int(p.peer_id) not in seen and int(p.peer_id) != Net.self_id:
			_free_now(p)
			_players.erase(p)
	# enemies
	var enemy_seen: Array[int] = []
	for entry in enemies_data:
		var eid := int(entry[0])
		enemy_seen.append(eid)
		var node: Node = _remote_enemies.get(eid)
		if not is_instance_valid(node):
			node = ENEMY.instantiate()
			add_child(node)
			node.network_remote = true
			node.net_id = eid
			node.enemy_type = int(entry[1])
			_remote_enemies[eid] = node
		node.global_position = node.global_position.lerp(Vector3(float(entry[2]), float(entry[3]), float(entry[4])), 0.5)
		node.rotation.y = float(entry[5])
		node.hp = float(entry[6])
		node.elite = bool(entry[7])
	for eid in _remote_enemies.keys():
		if int(eid) not in enemy_seen:
			var node: Node = _remote_enemies[eid]
			if is_instance_valid(node):
				_free_now(node)
			_remote_enemies.erase(eid)
	# pickups
	var pickup_seen: Array[int] = []
	for entry in pickups_data:
		var pid := int(entry[0])
		pickup_seen.append(pid)
		var node: Node = _remote_pickups.get(pid)
		if not is_instance_valid(node):
			node = PICKUP.instantiate()
			node.kind = str(entry[1])
			node.network_remote = true
			node.net_id = pid
			add_child(node)
			_remote_pickups[pid] = node
		node.global_position = Vector3(float(entry[2]), float(entry[3]), float(entry[4]))
	for pid in _remote_pickups.keys():
		if int(pid) not in pickup_seen:
			var node: Node = _remote_pickups[pid]
			if is_instance_valid(node):
				_free_now(node)
			_remote_pickups.erase(pid)
	# projectiles
	var proj_seen: Array[int] = []
	for entry in projectiles_data:
		var qid := int(entry[0])
		proj_seen.append(qid)
		var node: Node = _remote_projectiles.get(qid)
		if not is_instance_valid(node):
			node = PROJECTILE.instantiate()
			node.network_remote = true
			node.net_id = qid
			node.scale_visual = float(entry[7])
			add_child(node)
			_remote_projectiles[qid] = node
		node.target_pos = Vector3(float(entry[1]), float(entry[2]), float(entry[3]))
		node.direction = Vector3(float(entry[4]), float(entry[5]), float(entry[6]))
	for qid in _remote_projectiles.keys():
		if int(qid) not in proj_seen:
			var node: Node = _remote_projectiles[qid]
			if is_instance_valid(node):
				_free_now(node)
			_remote_projectiles.erase(qid)
	# meta
	if meta.size() >= 5:
		wave_index = int(meta[0])
		score = int(meta[1])
		credits = int(meta[2])
		var remote_state := int(meta[3])
		wave_count = int(meta[4])
		hud.set_score(score, 1.0)
		hud.set_objective(enemies_data.size())
		if wave_index != _last_remote_wave:
			_last_remote_wave = wave_index
			var wave_name: String = WAVE_NAMES[wave_index % WAVE_NAMES.size()]
			hud.set_wave(wave_index + 1, wave_count, wave_name, enemies_data.size())
			if not _got_wave_banner:
				_got_wave_banner = true
				hud.show_banner("ВОЛНА %d / %d" % [wave_index + 1, wave_count], wave_name, 2.2)
		if remote_state == 4 and not shop_panel.visible:
			state = State.SHOP
			if player:
				player.set_active(false)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			shop_panel.open(wave_index + 2, credits)
		elif remote_state != 4 and shop_panel.visible:
			shop_panel.hide_panel()
			state = State.PLAYING
			if player:
				player.set_active(true)

@rpc("authority", "call_remote", "reliable")
func rpc_player_health(peer_id: int, hp: float) -> void:
	if not Net.is_client:
		return
	var p := _find_player(peer_id)
	if p:
		p.health = hp
		p.health_changed.emit(p.health, p.max_health)
		if hp <= 0.0:
			p.dead = true
			if p == player and net_mode != 0:
				for p2 in _players:
					if p2 != player and is_instance_valid(p2) and not p2.dead:
						spectating = p2
						p2.camera.current = true
						hud.show_banner("НАБЛЮДЕНИЕ ЗА СОЮЗНИКОМ", "ВОЗВРАТ В СЛЕДУЮЩЕЙ ВОЛНЕ", 3.0, RubezhUI.AMBER)
						break

@rpc("any_peer", "call_remote", "reliable")
func rpc_enemy_hit(eid: int, damage: float, head: bool) -> void:
	if not Net.is_host:
		return
	for e in _alive:
		if is_instance_valid(e) and int(e.net_id) == eid:
			e.take_hit(damage, head, Vector3.FORWARD, e.global_position + Vector3.UP)
			return

@rpc("authority", "call_remote", "reliable")
func rpc_revive(peer_id: int) -> void:
	if not Net.is_client:
		return
	var p := _find_player(peer_id)
	if p:
		p.reset_player(_spawn_pos_for(peer_id), 0.0)
		p.health = p.max_health * 0.6
		p.health_changed.emit(p.health, p.max_health)


@rpc("any_peer", "call_remote", "reliable")
func rpc_buy(id: String) -> void:
	if Net.is_host and state == State.SHOP:
		_on_buy(id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_continue() -> void:
	if Net.is_host and state == State.SHOP:
		_start_next_wave()


@rpc("authority", "call_remote", "reliable")
func rpc_finish(victory: bool, data: Array) -> void:
	if not Net.is_client:
		return
	ending = true
	state = State.RESULTS
	if player:
		player.set_active(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	shop_panel.hide_panel()
	hud.visible = false
	var stats := {
		"score": int(data[0]), "kills": int(data[1]), "headshots": int(data[2]),
		"accuracy": float(data[3]), "wave": int(data[4]), "wave_total": int(data[5]),
		"time": float(data[6]),
	}
	results_screen.set_coop_mode(net_mode != 0)
	results_screen.show_results(stats, victory)


@rpc("any_peer", "call_remote", "reliable")
func rpc_pickup_taken(pid: int) -> void:
	if not Net.is_host:
		return
	for pk in get_tree().get_nodes_in_group("pickups"):
		if is_instance_valid(pk) and int(pk.get("net_id")) == pid:
			_free_now(pk)
			return


func debug_ray() -> Array:
	if player == null:
		return []
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var out := []
	for d in [Vector3.FORWARD, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT]:
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 12.0, 1 | 8)
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if r.is_empty():
			out.append("none")
		else:
			out.append(str(r.collider.get_parent().name) + "/" + str(r.collider.name) + "@" + str(snappedf(r.distance, 0.2)) + " pos=" + str(r.collider.global_position))
	return out


@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_player_pose(_peer_id: int, x: float, y: float, z: float, yaw: float, pitch: float) -> void:
	if not Net.is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 1:
		return
	var p := _find_player(id)
	if p:
		p.global_position = p.global_position.lerp(Vector3(x, y, z), 0.6)
		p.yaw = yaw
		p.pitch = pitch
