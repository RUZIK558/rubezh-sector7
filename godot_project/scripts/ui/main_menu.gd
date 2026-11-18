class_name MainMenu
extends Control
## Cinematic main menu shown over the orbiting arena camera.

signal start_requested
signal settings_requested
signal quit_requested

var _title: Label
var _kicker: Label
var _buttons: VBoxContainer
var _hint: Label
var _accent: ColorRect
var _t := 0.0
var _entered := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	_build_content()
	_build_footer()

func _build_backdrop() -> void:
	var grad := Gradient.new()
	grad.add_point(0.0, Color(0.02, 0.025, 0.03, 0.985))
	grad.add_point(0.48, Color(0.02, 0.025, 0.03, 0.965))
	grad.add_point(0.75, Color(0.02, 0.025, 0.03, 0.82))
	grad.add_point(1.0, Color(0.02, 0.025, 0.03, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2.ZERO
	tex.fill_to = Vector2(1, 0)
	var grad_rect := TextureRect.new()
	grad_rect.texture = tex
	grad_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad_rect.stretch_mode = TextureRect.STRETCH_SCALE
	grad_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad_rect)
	var veil := ColorRect.new()
	veil.anchor_left = 0.42
	veil.anchor_right = 1.0
	veil.anchor_top = 0.0
	veil.anchor_bottom = 1.0
	veil.color = Color(0.02, 0.025, 0.03, 0.48)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var bottom := ColorRect.new()
	bottom.anchor_top = 0.7
	bottom.anchor_bottom = 1.0
	bottom.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	bottom.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	bottom.color = Color(0.015, 0.02, 0.025, 0.34)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	var noise := TextureRect.new()
	noise.texture = preload("res://assets/textures/ui_scanlines.png")
	noise.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	noise.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	noise.stretch_mode = TextureRect.STRETCH_TILE
	noise.modulate = Color(1, 1, 1, 0.035)
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(noise)

func _build_content() -> void:
	var box := VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_top = 0.0
	box.anchor_right = 0.0
	box.anchor_bottom = 0.0
	box.offset_left = 92
	box.offset_top = 96
	box.offset_right = 690
	box.offset_bottom = 760
	box.add_theme_constant_override("separation", 0)
	add_child(box)

	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 12)
	box.add_child(brand)
	_accent = ColorRect.new()
	_accent.color = RubezhUI.AMBER
	_accent.custom_minimum_size = Vector2(30, 4)
	brand.add_child(_accent)
	brand.add_child(RubezhUI.label("RUBEZH // TACTICAL DIVISION", 12, RubezhUI.AMBER, RubezhUI.FONT_BOLD))

	box.add_child(RubezhUI.vspacer(34))

	_kicker = RubezhUI.label("ОПЕРАЦИЯ «ТИШИНА»  ·  07.11.2026", 13, RubezhUI.MUTED, RubezhUI.FONT_BOLD)
	box.add_child(_kicker)
	box.add_child(RubezhUI.vspacer(14))

	_title = RubezhUI.label("РУБЕЖ", 104, RubezhUI.TEXT, RubezhUI.FONT_BLACK)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	_title.add_theme_constant_override("outline_size", 2)
	box.add_child(_title)
	var sub := RubezhUI.label("С Е К Т О Р   7", 28, RubezhUI.AMBER, RubezhUI.FONT_BOLD)
	box.add_child(sub)
	box.add_child(RubezhUI.vspacer(8))

	var rule := ColorRect.new()
	rule.color = Color(RubezhUI.AMBER.r, RubezhUI.AMBER.g, RubezhUI.AMBER.b, 0.45)
	rule.custom_minimum_size = Vector2(380, 2)
	box.add_child(rule)
	box.add_child(RubezhUI.vspacer(24))

	var brief := RubezhUI.rich(
		"[b]ЗАДАНИЕ[/b]  Удержать сектор до полного уничтожения сил противника.\n" +
		"Двадцать волн. Каждые пять — штурмовой робот [b]«ТИТАН»[/b].
Между волнами — магазин квартирмейстера с улучшениями.\n\n" +
		"[color=#8a949e]Поддержка: патроны и аптечки на поле боя. " +
		"Взрывоопасные бочки наносят урон всем, кто рядом — включая вас.[/color]",
		15, RubezhUI.TEXT)
	brief.custom_minimum_size = Vector2(500, 0)
	box.add_child(brief)
	box.add_child(RubezhUI.vspacer(34))

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	box.add_child(_buttons)
	var start := RubezhUI.accent_button("НАЧАТЬ ОПЕРАЦИЮ", 19)
	start.custom_minimum_size = Vector2(360, 62)
	start.pressed.connect(func(): start_requested.emit())
	_buttons.add_child(start)
	var settings := RubezhUI.button("НАСТРОЙКИ", 16)
	settings.custom_minimum_size = Vector2(360, 52)
	settings.pressed.connect(func(): settings_requested.emit())
	_buttons.add_child(settings)
	var quit := RubezhUI.button("ВЫЙТИ", 16)
	quit.custom_minimum_size = Vector2(360, 52)
	quit.pressed.connect(func(): quit_requested.emit())
	_buttons.add_child(quit)
	start.grab_focus()

func _build_footer() -> void:
	_hint = RubezhUI.label("WASD — ДВИЖЕНИЕ    ЛКМ — ОГОНЬ    ПКМ — ПРИЦЕЛ    1–3 / КОЛЕСО — ОРУЖИЕ   ·   V — НОЖ   ·   G — ГРАНАТА    R — ПЕРЕЗАРЯДКА    ESC — ПАУЗА",
			11, RubezhUI.DIM, RubezhUI.FONT_MEDIUM)
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 92
	_hint.offset_right = -40
	_hint.offset_top = -46
	_hint.offset_bottom = -20
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	var ver := RubezhUI.label("BUILD 1.0.7  //  SECTOR-7", 10, RubezhUI.DIM, RubezhUI.FONT_BOLD)
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 0.0
	ver.anchor_bottom = 0.0
	ver.offset_left = -320
	ver.offset_right = -46
	ver.offset_top = 46
	ver.offset_bottom = 70
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ver)

func _process(delta: float) -> void:
	_t += delta
	if _accent:
		_accent.color.a = 0.75 + 0.25 * sin(_t * 2.0)

func enter() -> void:
	_entered = true
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.5)
	for c in _buttons.get_children():
		c.modulate.a = 0.0
		c.position.x = 24
	tw.chain()
	for c in _buttons.get_children():
		var t := create_tween().set_parallel(true)
		t.tween_property(c, "modulate:a", 1.0, 0.35)
		t.tween_property(c, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	first_button().grab_focus()

func first_button() -> Button:
	return _buttons.get_child(0) as Button
