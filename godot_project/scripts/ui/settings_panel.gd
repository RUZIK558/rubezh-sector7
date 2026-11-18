class_name SettingsPanel
extends Control
## Settings overlay usable from both the main menu and the pause menu.

signal closed

var _panel: PanelContainer
var _sens: HSlider
var _volume: HSlider
var _shake: HSlider
var _sens_value: Label
var _volume_value: Label
var _shake_value: Label
var _fullscreen_btn: Button
var _back: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.02, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_panel = RubezhUI.panel(Color(0.045, 0.055, 0.065, 0.99), Color(1, 1, 1, 0.12), 6)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(660, 660)
	_panel.offset_left = -330
	_panel.offset_right = 330
	_panel.offset_top = -330
	_panel.offset_bottom = 330
	add_child(_panel)
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 40)
	inner.add_theme_constant_override("margin_right", 40)
	inner.add_theme_constant_override("margin_top", 32)
	inner.add_theme_constant_override("margin_bottom", 28)
	_panel.add_child(inner)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	inner.add_child(v)

	v.add_child(RubezhUI.label("НАСТРОЙКИ // СЕКТОР 7", 10, RubezhUI.AMBER, RubezhUI.FONT_BOLD))
	v.add_child(RubezhUI.vspacer(4))
	v.add_child(RubezhUI.label("ПАРАМЕТРЫ СИСТЕМЫ", 34, RubezhUI.TEXT, RubezhUI.FONT_BLACK))
	v.add_child(RubezhUI.vspacer(4))
	v.add_child(RubezhUI.label("Значения применяются сразу и сохраняются автоматически.", 12, RubezhUI.MUTED))
	v.add_child(RubezhUI.vspacer(14))
	var rule := ColorRect.new()
	rule.color = Color(RubezhUI.AMBER.r, RubezhUI.AMBER.g, RubezhUI.AMBER.b, 0.45)
	rule.custom_minimum_size = Vector2(0, 2)
	v.add_child(rule)
	v.add_child(RubezhUI.vspacer(22))

	v.add_child(_section(v, "УПРАВЛЕНИЕ"))
	v.add_child(RubezhUI.vspacer(14))
	_sens = _row(v, "ЧУВСТВИТЕЛЬНОСТЬ МЫШИ", "0.15", "2.50", "%.2f")
	v.add_child(RubezhUI.vspacer(22))
	v.add_child(_section(v, "ЗВУК И КАМЕРА"))
	v.add_child(RubezhUI.vspacer(14))
	_volume = _row(v, "ГРОМКОСТЬ", "0%", "100%", "%.0f%%")
	v.add_child(RubezhUI.vspacer(18))
	_shake = _row(v, "ТРЯСКА КАМЕРЫ", "0%", "150%", "%.0f%%")
	v.add_child(RubezhUI.vspacer(22))
	v.add_child(_section(v, "ВИДЕО"))
	v.add_child(RubezhUI.vspacer(14))
	_fullscreen_btn = RubezhUI.button("ПОЛНОЭКРАННЫЙ РЕЖИМ: ВЫКЛ", false, 15)
	_fullscreen_btn.custom_minimum_size = Vector2(0, 52)
	_fullscreen_btn.toggle_mode = true
	_fullscreen_btn.toggled.connect(_on_fullscreen_toggled)
	v.add_child(_fullscreen_btn)
	v.add_child(RubezhUI.vspacer(26))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var reset := RubezhUI.button("СБРОСИТЬ", 15)
	reset.custom_minimum_size = Vector2(200, 52)
	reset.pressed.connect(func(): _reset())
	row.add_child(reset)
	_back = RubezhUI.accent_button("ГОТОВО", 17)
	_back.custom_minimum_size = Vector2(0, 52)
	_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back.pressed.connect(func(): _close())
	row.add_child(_back)
	v.add_child(RubezhUI.vspacer(12))
	v.add_child(RubezhUI.label("ESC — СОХРАНИТЬ И ВЫЙТИ", 10, RubezhUI.DIM, RubezhUI.FONT_MEDIUM))

func _section(parent: VBoxContainer, text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_child(RubezhUI.label(text, 11, RubezhUI.AMBER, RubezhUI.FONT_BOLD))
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.08)
	line.custom_minimum_size = Vector2(0, 1)
	box.add_child(line)
	return box

func _row(parent: VBoxContainer, title: String, min_text: String, max_text: String, fmt: String) -> HSlider:
	var head := HBoxContainer.new()
	parent.add_child(head)
	head.add_child(RubezhUI.label(title, 14, RubezhUI.TEXT, RubezhUI.FONT_BOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var value := RubezhUI.label("", 16, RubezhUI.AMBER, RubezhUI.FONT_BOLD)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(value)
	if title == "ЧУВСТВИТЕЛЬНОСТЬ МЫШИ":
		_sens_value = value
	elif title == "ГРОМКОСТЬ":
		_volume_value = value
	elif title == "ТРЯСКА КАМЕРЫ":
		_shake_value = value
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(0, 34)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 0.5
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.30)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	track.corner_radius_top_left = 3
	track.corner_radius_top_right = 3
	track.corner_radius_bottom_left = 3
	track.corner_radius_bottom_right = 3
	slider.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = RubezhUI.AMBER
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_icon_override("grabber", _circle(18, Color.WHITE))
	slider.add_theme_icon_override("grabber_highlight", _circle(18, RubezhUI.AMBER))
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	parent.add_child(slider)
	var scale_row := HBoxContainer.new()
	parent.add_child(scale_row)
	scale_row.add_child(RubezhUI.label(min_text, 9, RubezhUI.DIM))
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_row.add_child(sp2)
	scale_row.add_child(RubezhUI.label(max_text, 9, RubezhUI.DIM))
	return slider

func _circle(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			var a := clampf(1.0 - (d - (c - 3.0)), 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(img)

func _on_sens(value: float) -> void:
	Settings.mouse_sensitivity = value
	_sens_value.text = "%.2f" % value
	_save()

func _on_volume(value: float) -> void:
	Settings.master_volume = value
	_volume_value.text = "%d%%" % int(value * 100.0)
	Settings.apply()
	_save()

func _on_shake(value: float) -> void:
	Settings.screen_shake = value
	_shake_value.text = "%d%%" % int(value * 100.0)
	_save()

func _on_fullscreen_toggled(value: bool) -> void:
	Settings.fullscreen = value
	_fullscreen_btn.text = "ПОЛНОЭКРАННЫЙ РЕЖИМ: " + ("ВКЛ" if value else "ВЫКЛ")
	Settings.apply()
	_save()
	AudioManager.play("ui_click")

func _save() -> void:
	Settings.save_settings()

func _reset() -> void:
	Settings.mouse_sensitivity = 1.0
	Settings.master_volume = 0.8
	Settings.fullscreen = false
	Settings.screen_shake = 1.0
	Settings.apply()
	_fullscreen_btn.set_block_signals(true)
	_fullscreen_btn.button_pressed = false
	_fullscreen_btn.set_block_signals(false)
	_fullscreen_btn.text = "ПОЛНОЭКРАННЫЙ РЕЖИМ: ВЫКЛ"
	_sens.value = 1.0
	_volume.value = 0.8
	_shake.value = 1.0
	_sens_value.text = "1.00"
	_volume_value.text = "80%"
	_shake_value.text = "100%"
	_save()
	AudioManager.play("ui_click")

func open() -> void:
	_sens.value = Settings.mouse_sensitivity
	_volume.value = Settings.master_volume
	_shake.value = Settings.screen_shake
	_sens_value.text = "%.2f" % Settings.mouse_sensitivity
	_volume_value.text = "%d%%" % int(Settings.master_volume * 100.0)
	_shake_value.text = "%d%%" % int(Settings.screen_shake * 100.0)
	_fullscreen_btn.set_block_signals(true)
	_fullscreen_btn.button_pressed = Settings.fullscreen
	_fullscreen_btn.set_block_signals(false)
	_fullscreen_btn.text = "ПОЛНОЭКРАННЫЙ РЕЖИМ: " + ("ВКЛ" if Settings.fullscreen else "ВЫКЛ")
	_sens.min_value = 0.15
	_sens.max_value = 2.5
	_sens.step = 0.05
	_sens.value_changed.connect(_on_sens) if not _sens.value_changed.is_connected(_on_sens) else null
	_volume.min_value = 0.0
	_volume.max_value = 1.0
	_volume.step = 0.01
	_volume.value_changed.connect(_on_volume) if not _volume.value_changed.is_connected(_on_volume) else null
	_shake.min_value = 0.0
	_shake.max_value = 1.5
	_shake.step = 0.05
	_shake.value_changed.connect(_on_shake) if not _shake.value_changed.is_connected(_on_shake) else null
	visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.2)
	if _back:
		_back.grab_focus()

func _close() -> void:
	Settings.save_settings()
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()
