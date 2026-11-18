class_name RubezhUI
## Shared visual language: colours, fonts and widget factories.

const BG := Color("#0a0d10")
const PANEL := Color("#11161b")
const PANEL_LIGHT := Color("#182028")
const TEXT := Color("#e9e6df")
const MUTED := Color("#8a949e")
const DIM := Color("#5b666f")
const AMBER := Color("#ffb03a")
const AMBER_DARK := Color("#b87418")
const RED := Color("#e0442f")
const GREEN := Color("#6ddc8a")
const BLACK := Color("#070808")

const FONT_REGULAR := preload("res://assets/fonts/Montserrat-Regular.otf")
const FONT_MEDIUM := preload("res://assets/fonts/Montserrat-Medium.otf")
const FONT_SEMIBOLD := preload("res://assets/fonts/Montserrat-SemiBold.otf")
const FONT_BOLD := preload("res://assets/fonts/Montserrat-Bold.otf")
const FONT_BLACK := preload("res://assets/fonts/Montserrat-ExtraBold.otf")

static func style_box(bg: Color, border := Color.TRANSPARENT, border_width := 0, radius := 4,
		margin := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	return s

static func label(text: String, size := 16, color := TEXT, font: Font = FONT_MEDIUM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func rich(text: String, size := 16, color := TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.add_theme_font_override("normal_font", FONT_MEDIUM)
	r.add_theme_font_override("bold_font", FONT_BOLD)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", color)
	return r

static func button(text: String, primary := false, size := 18) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_override("font", FONT_SEMIBOLD)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", BLACK if primary else TEXT)
	b.add_theme_color_override("font_hover_color", BLACK if primary else AMBER)
	b.add_theme_color_override("font_pressed_color", BLACK)
	b.add_theme_color_override("font_focus_color", BLACK if primary else AMBER)
	var normal := style_box(AMBER if primary else Color(0.07, 0.085, 0.10, 0.75),
			Color.TRANSPARENT if primary else Color(1, 1, 1, 0.10), 1 if not primary else 0, 3, 18)
	var hover := style_box(AMBER if primary else Color(0.11, 0.085, 0.03, 0.92),
			Color.TRANSPARENT if primary else AMBER, 1 if not primary else 0, 3, 18)
	var pressed := style_box(AMBER_DARK, Color.TRANSPARENT, 0, 3, 18)
	var focus := style_box(Color.TRANSPARENT, AMBER, 2, 3, 18)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("disabled", style_box(Color(0.1, 0.1, 0.1, 0.4), Color.TRANSPARENT, 0, 3, 18))
	b.mouse_entered.connect(func(): AudioManager.play("ui_hover"))
	b.pressed.connect(func(): AudioManager.play("ui_click"))
	return b

static func accent_button(text: String, size := 18) -> Button:
	return button(text, true, size)

static func separator(color := Color(1, 1, 1, 0.09), height := 1) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func hspacer(width: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 0)
	return c

static func vspacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

static func panel(color := PANEL, border := Color(1, 1, 1, 0.08), radius := 4) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style_box(color, border, 1, radius))
	return p

static func tag(text: String, color := AMBER) -> Label:
	var l := label(text.to_upper(), 11, color, FONT_BOLD)
	l.add_theme_constant_override("outline_size", 0)
	return l

static func slider(value: float, min_value: float, max_value: float, step := 0.01) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_value
	s.max_value = max_value
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(220, 26)
	s.add_theme_stylebox_override("slider", style_box(Color(1, 1, 1, 0.22), Color.TRANSPARENT, 0, 3))
	s.add_theme_stylebox_override("grabber_area", style_box(AMBER, Color.TRANSPARENT, 0, 2))
	s.add_theme_stylebox_override("grabber_area_highlight", style_box(AMBER, Color.TRANSPARENT, 0, 2))
	s.add_theme_icon_override("grabber", _circle_icon(16, AMBER))
	s.add_theme_icon_override("grabber_highlight", _circle_icon(16, Color.WHITE))
	return s

static func _circle_icon(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			var a := clampf(1.0 - (d - (c - 2.0)), 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(img)

static func checkbox(text: String, checked: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = checked
	c.add_theme_font_override("font", FONT_MEDIUM)
	c.add_theme_font_size_override("font_size", 16)
	c.add_theme_color_override("font_color", TEXT)
	c.add_theme_color_override("font_hover_color", AMBER)
	c.add_theme_color_override("font_pressed_color", TEXT)
	return c

static func progress_bar(fill := AMBER, bg := Color(1, 1, 1, 0.09)) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.add_theme_stylebox_override("background", style_box(bg, Color.TRANSPARENT, 0, 2))
	p.add_theme_stylebox_override("fill", style_box(fill, Color.TRANSPARENT, 0, 2))
	return p
