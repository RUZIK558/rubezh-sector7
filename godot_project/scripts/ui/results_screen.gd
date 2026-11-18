class_name ResultsScreen
extends Control
## End-of-operation debrief with combat statistics.

signal restart_requested
signal menu_requested

var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _rows: VBoxContainer
var _restart: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.008, 0.012, 0.016, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_panel = RubezhUI.panel(Color(0.04, 0.05, 0.058, 0.98), Color(1, 1, 1, 0.1), 5)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(640, 0)
	_panel.offset_left = -320
	_panel.offset_right = 320
	_panel.offset_top = -330
	_panel.offset_bottom = 330
	add_child(_panel)
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 44)
	inner.add_theme_constant_override("margin_right", 44)
	inner.add_theme_constant_override("margin_top", 36)
	inner.add_theme_constant_override("margin_bottom", 32)
	_panel.add_child(inner)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	inner.add_child(v)

	_title = RubezhUI.label("", 11, RubezhUI.AMBER, RubezhUI.FONT_BOLD)
	v.add_child(_title)
	v.add_child(RubezhUI.vspacer(10))
	_subtitle = RubezhUI.label("", 46, RubezhUI.TEXT, RubezhUI.FONT_BLACK)
	v.add_child(_subtitle)
	v.add_child(RubezhUI.vspacer(8))
	var rule := ColorRect.new()
	rule.color = Color(RubezhUI.AMBER.r, RubezhUI.AMBER.g, RubezhUI.AMBER.b, 0.5)
	rule.custom_minimum_size = Vector2(70, 3)
	v.add_child(rule)
	v.add_child(RubezhUI.vspacer(26))

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 12)
	v.add_child(_rows)
	v.add_child(RubezhUI.vspacer(30))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_restart = RubezhUI.accent_button("ПОВТОРИТЬ ОПЕРАЦИЮ", 17)
	_restart.custom_minimum_size = Vector2(310, 54)
	_restart.pressed.connect(func(): restart_requested.emit())
	row.add_child(_restart)
	var menu := RubezhUI.button("В ГЛАВНОЕ МЕНЮ", 16)
	menu.custom_minimum_size = Vector2(240, 54)
	menu.pressed.connect(func(): menu_requested.emit())
	row.add_child(menu)
	v.add_child(RubezhUI.vspacer(12))
	v.add_child(RubezhUI.label("СЕКТОР 7 // ОТЧЁТ ПО ОПЕРАЦИИ", 10, RubezhUI.DIM, RubezhUI.FONT_MEDIUM))

func show_results(data: Dictionary, victory: bool) -> void:
	var accent := RubezhUI.GREEN if victory else RubezhUI.RED
	_title.text = "ОПЕРАЦИЯ ЗАВЕРШЕНА // УСПЕХ" if victory else "СИГНАЛ ПОТЕРЯН // ПОРАЖЕНИЕ"
	_title.add_theme_color_override("font_color", accent)
	_subtitle.text = "СЕКТОР УДЕРЖАН" if victory else "ВЫ ПОГИБЛИ"
	_subtitle.add_theme_color_override("font_color", RubezhUI.TEXT if victory else RubezhUI.RED)
	for c in _rows.get_children():
		c.queue_free()
	var defs := [
		["ФИНАЛЬНЫЙ СЧЁТ", _fmt(int(data.get("score", 0)))],
		["УНИЧТОЖЕНО ЦЕЛЕЙ", str(int(data.get("kills", 0)))],
		["ХЕДШОТЫ", str(int(data.get("headshots", 0)))],
		["ТОЧНОСТЬ", "%.1f%%" % (100.0 * float(data.get("accuracy", 0.0)))],
		["ДОСТИГНУТАЯ ВОЛНА", "%d / %d" % [int(data.get("wave", 1)), int(data.get("wave_total", 20))]],
		["ВРЕМЯ ОПЕРАЦИИ", _time_str(float(data.get("time", 0.0)))],
	]
	for d in defs:
		var r := HBoxContainer.new()
		var l: Label = RubezhUI.label(d[0], 14, RubezhUI.MUTED, RubezhUI.FONT_MEDIUM)
		r.add_child(l)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(sp)
		var value: Label = RubezhUI.label(d[1], 18, RubezhUI.TEXT if d[0] != "ФИНАЛЬНЫЙ СЧЁТ" else RubezhUI.AMBER, RubezhUI.FONT_BOLD)
		r.add_child(value)
		_rows.add_child(r)
	visible = true
	_panel.modulate.a = 0.0
	_panel.position.y = 18
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.45)
	tw.tween_property(_panel, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain()
	_restart.grab_focus()

func hide_screen() -> void:
	visible = false

func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return out

func _time_str(t: float) -> String:
	var total := int(t)
	return "%02d:%02d" % [int(total / 60.0), total % 60]
