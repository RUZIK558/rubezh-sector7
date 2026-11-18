extends Node
## Persisted user settings (sensitivity, volume, fullscreen, shake).

signal changed

const PATH := "user://settings.cfg"

var mouse_sensitivity: float = 1.0
var master_volume: float = 0.8
var fullscreen: bool = false
var screen_shake: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
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
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
