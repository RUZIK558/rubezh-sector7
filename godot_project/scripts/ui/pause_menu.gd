class_name PauseMenu
extends Control
## Pause overlay. Still processes while the scene tree is paused.

signal resume_requested
signal settings_requested
signal restart_requested
signal menu_requested

var _panel: PanelContainer
var _title: Label
var _hint: Label
var _resume: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.02, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_panel = RubezhUI.panel(Color(0.04, 0.052, 0.062, 0.97), Color(1, 1, 1, 0.10), 5)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(470, 0)
	_panel.offset_left = -235
	_panel.offset_right = 235
	_panel.offset_top = -260
	_panel.offset_bottom = 260
	add_child(_panel)
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 38)
	inner.add_theme_constant_override("margin_right", 38)
	inner.add_theme_constant_override("margin_top", 34)
	inner.add_theme_constant_override("margin_bottom", 30)
	_panel.add_child(inner)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	inner.add_child(v)

	var kicker := RubezhUI.label("СЕКТОР 7 // ОПЕРАЦИЯ ПРИОСТАНОВЛЕНА", 10, RubezhUI.AMBER, RubezhUI.FONT_BOLD)
	v.add_child(kicker)
	v.add_child(RubezhUI.vspacer(10))
	_title = RubezhUI.label("ПАУЗА", 52, RubezhUI.TEXT, RubezhUI.FONT_BLACK)
	v.add_child(_title)
	v.add_child(RubezhUI.vspacer(6))
	var rule := ColorRect.new()
	rule.color = Color(RubezhUI.AMBER.r, RubezhUI.AMBER.g, RubezhUI.AMBER.b, 0.5)
	rule.custom_minimum_size = Vector2(70, 3)
	v.add_child(rule)
	v.add_child(RubezhUI.vspacer(30))

	var resume := RubezhUI.accent_button("ПРОДОЛЖИТЬ", 18)
	resume.custom_minimum_size = Vector2(0, 56)
	resume.pressed.connect(func(): resume_requested.emit())
	_resume = resume
	v.add_child(resume)
	v.add_child(RubezhUI.vspacer(9))
	var settings := RubezhUI.button("НАСТРОЙКИ", 16)
	settings.custom_minimum_size = Vector2(0, 50)
	settings.pressed.connect(func(): settings_requested.emit())
	v.add_child(settings)
	v.add_child(RubezhUI.vspacer(9))
	var restart := RubezhUI.button("НАЧАТЬ ЗАНОВО", 16)
	restart.custom_minimum_size = Vector2(0, 50)
	restart.pressed.connect(func(): restart_requested.emit())
	v.add_child(restart)
	v.add_child(RubezhUI.vspacer(9))
	var menu := RubezhUI.button("В ГЛАВНОЕ МЕНЮ", 16)
	menu.custom_minimum_size = Vector2(0, 50)
	menu.pressed.connect(func(): menu_requested.emit())
	v.add_child(menu)
	v.add_child(RubezhUI.vspacer(24))
	_hint = RubezhUI.label("ESC — ВЕРНУТЬСЯ В БОЙ", 10, RubezhUI.DIM, RubezhUI.FONT_MEDIUM)
	v.add_child(_hint)
	resume.grab_focus()

func show_menu() -> void:
	visible = true
	var tw := create_tween().set_parallel(true)
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.22)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _resume:
		_resume.grab_focus()

func hide_menu() -> void:
	visible = false

func first_button() -> Button:
	return _resume

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		resume_requested.emit()
