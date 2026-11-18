class_name ControlsPanel
extends Control
## Full key-rebinding screen with every action listed.

signal closed

var _panel: PanelContainer
var _rows: Dictionary = {}
var _rebind_hint: Label
var _rebinding := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.02, 0.93)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = RubezhUI.panel(Color(0.045, 0.055, 0.065, 0.99), Color(1, 1, 1, 0.12), 6)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(720, 760)
	_panel.offset_left = -360
	_panel.offset_right = 360
	_panel.offset_top = -380
	_panel.offset_bottom = 380
	add_child(_panel)
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 34)
	inner.add_theme_constant_override("margin_right", 34)
	inner.add_theme_constant_override("margin_top", 26)
	inner.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(inner)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	inner.add_child(v)
	v.add_child(RubezhUI.label("НАСТРОЙКИ УПРАВЛЕНИЯ // СЕКТОР 7", 10, RubezhUI.AMBER, RubezhUI.FONT_BOLD))
	v.add_child(RubezhUI.vspacer(4))
	v.add_child(RubezhUI.label("КЛАВИШИ", 32, RubezhUI.TEXT, RubezhUI.FONT_BLACK))
	v.add_child(RubezhUI.vspacer(4))
	_rebind_hint = RubezhUI.label("Нажмите «ИЗМЕНИТЬ», затем нужную клавишу или кнопку мыши. ESC — отмена.", 12, RubezhUI.MUTED)
	v.add_child(_rebind_hint)
	v.add_child(RubezhUI.vspacer(14))
	var rule := ColorRect.new()
	rule.color = Color(RubezhUI.AMBER.r, RubezhUI.AMBER.g, RubezhUI.AMBER.b, 0.45)
	rule.custom_minimum_size = Vector2(0, 2)
	v.add_child(rule)
	v.add_child(RubezhUI.vspacer(12))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 520)
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for action in Settings.ACTIONS:
		list.add_child(_row(action))

	v.add_child(RubezhUI.vspacer(12))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	var reset := RubezhUI.button("СБРОСИТЬ ВСЁ", 14)
	reset.custom_minimum_size = Vector2(190, 46)
	reset.pressed.connect(func(): _reset_all())
	foot.add_child(reset)
	var done := RubezhUI.accent_button("ГОТОВО", 16)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.custom_minimum_size = Vector2(0, 46)
	done.pressed.connect(func(): close())
	foot.add_child(done)

func _row(action: String) -> Control:
	var card := RubezhUI.panel(Color(0.075, 0.085, 0.10, 0.9), Color(1, 1, 1, 0.07), 3)
	card.custom_minimum_size = Vector2(0, 44)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(margin)
	margin.add_child(h)
	var name_label := RubezhUI.label(_action_name(action), 14, RubezhUI.TEXT, RubezhUI.FONT_BOLD)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_label)
	var key := RubezhUI.label(Settings.binding_label(action), 15, RubezhUI.AMBER, RubezhUI.FONT_BOLD)
	key.custom_minimum_size = Vector2(120, 0)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(key)
	_rows[action] = key
	var btn := RubezhUI.button("ИЗМЕНИТЬ", false, 12)
	btn.custom_minimum_size = Vector2(120, 32)
	btn.pressed.connect(func(): _begin_rebind(action))
	h.add_child(btn)
	return card

func _action_name(action: String) -> String:
	var names := {
		"move_forward": "ДВИЖЕНИЕ ВПЕРЁД", "move_back": "ДВИЖЕНИЕ НАЗАД",
		"move_left": "ДВИЖЕНИЕ ВЛЕВО", "move_right": "ДВИЖЕНИЕ ВПРАВО",
		"jump": "ПРЫЖОК", "crouch": "ПРИСЕДАНИЕ", "sprint": "СПРИНТ",
		"fire": "СТРЕЛЬБА", "aim": "ПРИЦЕЛИВАНИЕ", "reload": "ПЕРЕЗАРЯДКА",
		"throw_knife": "БРОСОК НОЖА", "grenade": "ГРАНАТА", "pause": "ПАУЗА",
	}
	return str(names.get(action, action.to_upper()))

func _begin_rebind(action: String) -> void:
	_rebinding = action
	_rebind_hint.text = "ОЖИДАНИЕ КЛАВИШИ: %s  ·  ESC — ОТМЕНА" % _action_name(action)
	_rebind_hint.add_theme_color_override("font_color", RubezhUI.AMBER)

func _input(event: InputEvent) -> void:
	if _rebinding == "" or not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_rebind()
		return
	if event is InputEventKey or event is InputEventMouseButton:
		Settings.set_binding(_rebinding, event)
		var label: Label = _rows.get(_rebinding)
		if label:
			label.text = Settings.binding_label(_rebinding)
		_rebinding = ""
		_rebind_hint.text = "Нажмите «ИЗМЕНИТЬ», затем нужную клавишу или кнопку мыши. ESC — отмена."
		_rebind_hint.add_theme_color_override("font_color", RubezhUI.MUTED)
		get_viewport().set_input_as_handled()

func _cancel_rebind() -> void:
	_rebinding = ""
	_rebind_hint.text = "Нажмите «ИЗМЕНИТЬ», затем нужную клавишу или кнопку мыши. ESC — отмена."
	_rebind_hint.add_theme_color_override("font_color", RubezhUI.MUTED)
	get_viewport().set_input_as_handled()

func _reset_all() -> void:
	Settings.reset_bindings()
	for action in Settings.ACTIONS:
		var label: Label = _rows.get(action)
		if label:
			label.text = Settings.binding_label(action)

func open() -> void:
	for action in Settings.ACTIONS:
		var label: Label = _rows.get(action)
		if label:
			label.text = Settings.binding_label(action)
	visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.2)

func close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _rebinding != "":
			_cancel_rebind()
		else:
			close()
