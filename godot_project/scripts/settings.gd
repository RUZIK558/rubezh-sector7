extends Node
## Persisted user settings (sensitivity, volume, fullscreen, shake, key bindings).

signal changed

const PATH := "user://settings.cfg"
const BIND_PATH := "user://bindings.cfg"

const ACTIONS := [
	"move_forward", "move_back", "move_left", "move_right",
	"jump", "crouch", "sprint", "fire", "aim", "reload",
	"throw_knife", "grenade", "pause",
]

var mouse_sensitivity: float = 1.0
var master_volume: float = 0.8
var fullscreen: bool = false
var screen_shake: float = 1.0
var bindings: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	load_bindings()
	apply()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	mouse_sensitivity = clampf(float(cfg.get_value("input", "sensitivity", 1.0)), 0.15, 2.5)
	master_volume = clampf(float(cfg.get_value("audio", "volume", 0.8)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	screen_shake = clampf(float(cfg.get_value("video", "shake", 1.0)), 0.0, 1.5)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "volume", master_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "shake", screen_shake)
	cfg.save(PATH)
	changed.emit()

func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	_apply_window_mode()

func _apply_window_mode() -> void:
	if OS.has_feature("editor"):
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_size.call_deferred(_window_size())
	DisplayServer.window_set_position.call_deferred(_window_position())

func _window_size() -> Vector2i:
	if fullscreen:
		return Vector2i(DisplayServer.screen_get_size())
	return Vector2i(1600, 900)

func _window_position() -> Vector2i:
	var screen := Vector2i(DisplayServer.screen_get_size())
	if fullscreen:
		return Vector2i.ZERO
	return Vector2i((Vector2(screen) - Vector2(1600, 900)) / 2.0)

# ------------------------------------------------------------------ bindings
func default_binding(action: String) -> Dictionary:
	match action:
		"move_forward": return {"type": "key", "code": KEY_W}
		"move_back": return {"type": "key", "code": KEY_S}
		"move_left": return {"type": "key", "code": KEY_A}
		"move_right": return {"type": "key", "code": KEY_D}
		"jump": return {"type": "key", "code": KEY_SPACE}
		"crouch": return {"type": "key", "code": KEY_CTRL}
		"sprint": return {"type": "key", "code": KEY_SHIFT}
		"fire": return {"type": "mouse", "code": MOUSE_BUTTON_LEFT}
		"aim": return {"type": "mouse", "code": MOUSE_BUTTON_RIGHT}
		"reload": return {"type": "key", "code": KEY_R}
		"throw_knife": return {"type": "key", "code": KEY_V}
		"grenade": return {"type": "key", "code": KEY_G}
		"pause": return {"type": "key", "code": KEY_ESCAPE}
	return {}

func load_bindings() -> void:
	bindings.clear()
	for action in ACTIONS:
		bindings[action] = default_binding(action)
	var cfg := ConfigFile.new()
	if cfg.load(BIND_PATH) != OK:
		apply_bindings()
		return
	for action in ACTIONS:
		var saved = cfg.get_value("bindings", action, [])
		if saved is Array and saved.size() >= 2:
			bindings[action] = {"type": str(saved[0]), "code": int(saved[1])}
	apply_bindings()

func save_bindings() -> void:
	var cfg := ConfigFile.new()
	for action in ACTIONS:
		var b: Dictionary = bindings.get(action, {})
		cfg.set_value("bindings", action, [str(b.get("type", "key")), int(b.get("code", 0))])
	cfg.save(BIND_PATH)

func apply_bindings() -> void:
	for action in ACTIONS:
		var b: Dictionary = bindings.get(action, {})
		if b.is_empty():
			continue
		InputMap.action_erase_events(action)
		var ev: InputEvent
		if str(b["type"]) == "mouse":
			var mb := InputEventMouseButton.new()
			match int(b["code"]):
				1: mb.button_index = MOUSE_BUTTON_LEFT
				2: mb.button_index = MOUSE_BUTTON_RIGHT
				3: mb.button_index = MOUSE_BUTTON_MIDDLE
				4: mb.button_index = MOUSE_BUTTON_WHEEL_UP
				5: mb.button_index = MOUSE_BUTTON_WHEEL_DOWN
				_: mb.button_index = MOUSE_BUTTON_LEFT
			ev = mb
		else:
			var kb := InputEventKey.new()
			kb.physical_keycode = int(b["code"])
			ev = kb
		InputMap.action_add_event(action, ev)

func set_binding(action: String, event: InputEvent) -> void:
	var b := {}
	if event is InputEventMouseButton:
		b = {"type": "mouse", "code": int(event.button_index)}
	elif event is InputEventKey:
		b = {"type": "key", "code": int(event.physical_keycode) if event.physical_keycode != 0 else int(event.keycode)}
	if b.is_empty():
		return
	bindings[action] = b
	apply_bindings()
	save_bindings()

func reset_bindings() -> void:
	bindings.clear()
	for action in ACTIONS:
		bindings[action] = default_binding(action)
	apply_bindings()
	save_bindings()

func binding_label(action: String) -> String:
	var b: Dictionary = bindings.get(action, {})
	if b.is_empty():
		return "—"
	if str(b["type"]) == "mouse":
		match int(b["code"]):
			MOUSE_BUTTON_LEFT: return "ЛКМ"
			MOUSE_BUTTON_RIGHT: return "ПКМ"
			MOUSE_BUTTON_MIDDLE: return "СКМ"
			MOUSE_BUTTON_WHEEL_UP: return "КОЛЕСО↑"
			MOUSE_BUTTON_WHEEL_DOWN: return "КОЛЕСО↓"
			_: return "КНОПКА %d" % int(b["code"])
	var code := int(b["code"])
	var names := {
		KEY_W: "W", KEY_A: "A", KEY_S: "S", KEY_D: "D", KEY_SPACE: "ПРОБЕЛ",
		KEY_CTRL: "CTRL", KEY_SHIFT: "SHIFT", KEY_R: "R", KEY_V: "V", KEY_G: "G",
		KEY_ESCAPE: "ESC", KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→",
	}
	if names.has(code):
		return str(names[code])
	var text := OS.get_keycode_string(code)
	return text if text != "" else str(code)
