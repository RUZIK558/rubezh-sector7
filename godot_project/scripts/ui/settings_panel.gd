class_name SettingsPanel
extends Control
## Settings overlay usable from both the main menu and the pause menu.

signal closed

var _panel: PanelContainer
var _sens: HSlider
var _volume: HSlider
var _shake: HSlider
var _fullscreen: CheckButton
var _dirty := false
var _back: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.02, 0.86)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_panel = RubezhUI.panel(Color(0.045, 0.055, 0.065, 0.98), Color(1, 1, 1, 0.1), 5)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.offset_left = -280
	_panel.offset_right = 280
	_panel.offset_top = -325
	_panel.offset_bottom = 325
	add_child(_panel)
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 40)
	inner.add_theme_constant_override("margin_right", 40)
	inner.add_theme_constant_override("margin_top", 34)
	inner.add_theme_constant_override("margin_bottom", 28)
	_panel.add_child(inner)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	inner.add_child(v)

	v.add_child(RubezhUI.label("НАСТРОЙКИ // СИСТЕМА", 10, RubezhUI.AMBER, RubezhUI.FONT_BOLD))
	v.add_child(RubezhUI.vspacer(8))
	v.add_child(RubezhUI.label("ПАРАМЕТРЫ", 40, RubezhUI.TEXT, RubezhUI.FONT_BLACK))
	v.add_child(RubezhUI.vspacer(6))
	var rule := ColorRect.new()
	rule.color = Color(RubezhUI.AMBER.r, RubezhUI.AMBER.g, RubezhUI.AMBER.b, 0.5)
	rule.custom_minimum_size = Vector2(70, 3)
	v.add_child(rule)
	v.add_child(RubezhUI.vspacer(30))

	_sens = _row(v, "ЧУВСТВИТЕЛЬНОСТЬ МЫШИ", "0.15 — 2.50")
	_sens.min_value = 0.15
	_sens.max_value = 2.5
	_sens.step = 0.05
	_sens.value = Settings.mouse_sensitivity
	_sens.value_changed.connect(_on_sens)
	v.add_child(RubezhUI.vspacer(16))

	_volume = _row(v, "ГРОМКОСТЬ", "0 — 100%")
	_volume.min_value = 0.0
	_volume.max_value = 1.0
	_volume.step = 0.01
	_volume.value = Settings.master_volume
	_volume.value_changed.connect(_on_volume)
	v.add_child(RubezhUI.vspacer(16))

	_shake = _row(v, "ТРЯСКА КАМЕРЫ", "0 — 150%")
	_shake.min_value = 0.0
	_shake.max_value = 1.5
	_shake.step = 0.05
	_shake.value = Settings.screen_shake
	_shake.value_changed.connect(_on_shake)
	v.add_child(RubezhUI.vspacer(22))

	_fullscreen = RubezhUI.checkbox("ПОЛНОЭКРАННЫЙ РЕЖИМ", Settings.fullscreen)
	_fullscreen.pressed.connect(func(val: bool):
		Settings.fullscreen = val
		Settings.apply()
		_dirty = true)
	v.add_child(_fullscreen)
	v.add_child(RubezhUI.vspacer(30))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var back := RubezhUI.accent_button("НАЗАД", 17)
	back.custom_minimum_size = Vector2(240, 52)
	back.pressed.connect(func(): _close())
	_back = back
	row.add_child(back)
	var reset := RubezhUI.button("СБРОС", 15)
	reset.custom_minimum_size = Vector2(180, 52)
	reset.pressed.connect(func(): _reset())
	row.add_child(reset)
	v.add_child(RubezhUI.vspacer(14))
	v.add_child(RubezhUI.label("ИЗМЕНЕНИЯ СОХРАНЯЮТСЯ АВТОМАТИЧЕСКИ", 10, RubezhUI.DIM, RubezhUI.FONT_MEDIUM))

func _row(parent: VBoxContainer, title: String, range_text: String) -> HSlider:
	var head := HBoxContainer.new()
	parent.add_child(head)
	head.add_child(RubezhUI.label(title, 14, RubezhUI.TEXT, RubezhUI.FONT_BOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var rng := RubezhUI.label(range_text, 10, RubezhUI.DIM, RubezhUI.FONT_MEDIUM)
	head.add_child(rng)
	var s := RubezhUI.slider(0.5, 0.0, 1.0)
	s.custom_minimum_size = Vector2(480, 26)
	parent.add_child(s)
	return s

func _on_sens(value: float) -> void:
	Settings.mouse_sensitivity = value
	_dirty = true

func _on_volume(value: float) -> void:
	Settings.master_volume = value
	Settings.apply()
	_dirty = true

func _on_shake(value: float) -> void:
	Settings.screen_shake = value
	_dirty = true

func _reset() -> void:
	Settings.mouse_sensitivity = 1.0
	Settings.master_volume = 0.8
	Settings.fullscreen = false
	Settings.screen_shake = 1.0
	Settings.apply()
	_sens.value = 1.0
	_volume.value = 0.8
	_shake.value = 1.0
	_fullscreen.button_pressed = false
	_dirty = true
	AudioManager.play("ui_click")

func open() -> void:
	_sens.value = Settings.mouse_sensitivity
	_volume.value = Settings.master_volume
	_shake.value = Settings.screen_shake
	_fullscreen.button_pressed = Settings.fullscreen
	_dirty = false
	visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.2)
	if _back:
		_back.grab_focus()

func _close() -> void:
	if _dirty:
		Settings.save_settings()
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()
