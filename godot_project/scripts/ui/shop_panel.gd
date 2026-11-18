class_name ShopPanel
extends Control
## Between-wave quartermaster: clean 3x2 upgrade grid.

signal buy_requested(id: String)
signal continue_requested

const ICON_AK := preload("res://assets/textures/shop_ak.png")
const ICON_PISTOL := preload("res://assets/textures/shop_pistol.png")
const ICON_KNIFE := preload("res://assets/textures/shop_knife.png")
const ICON_MED := preload("res://assets/textures/shop_med.png")
const ICON_ARMOR := preload("res://assets/textures/shop_armor.png")

const ITEMS := [
	{"id": "ammo", "name": "БОЕПРИПАСЫ", "desc": "Пополнить магазины и резерв", "price": 60, "icon": 0},
	{"id": "med", "name": "АПТЕЧКА", "desc": "Полное восстановление здоровья", "price": 80, "icon": 3},
	{"id": "armor", "name": "БРОНЕПЛАСТИНА", "desc": "+25 к макс. здоровью", "price": 140, "icon": 4},
	{"id": "damage", "name": "БОЕВОЙ ЗАРЯД", "desc": "+15% урона всем оружиям", "price": 180, "icon": 0},
	{"id": "extmag", "name": "МАГАЗИН НА 45", "desc": "АК: увеличенная ёмкость", "price": 160, "icon": 0},
	{"id": "sharp", "name": "ЗАТОЧКА КЛИНКА", "desc": "Нож: +50% урона", "price": 120, "icon": 2},
]

var _panel: PanelContainer
var _credits_label: Label
var _wave_label: Label
var _cards: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.008, 0.012, 0.016, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_panel = RubezhUI.panel(Color(0.045, 0.055, 0.065, 0.99), Color(1, 1, 1, 0.12), 6)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(1120, 700)
	_panel.offset_left = -560
	_panel.offset_right = 560
	_panel.offset_top = -350
	_panel.offset_bottom = 350
	add_child(_panel)
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 38)
	inner.add_theme_constant_override("margin_right", 38)
	inner.add_theme_constant_override("margin_top", 30)
	inner.add_theme_constant_override("margin_bottom", 26)
	_panel.add_child(inner)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	inner.add_child(v)

	# ---------------------------------------------------------------- header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	v.add_child(head)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(left)
	left.add_child(RubezhUI.label("КВАРТИРМЕЙСТЕР // СЕКТОР 7", 10, RubezhUI.AMBER, RubezhUI.FONT_BOLD))
	left.add_child(RubezhUI.vspacer(4))
	_wave_label = RubezhUI.label("ПОДГОТОВКА К ВОЛНЕ 2", 32, RubezhUI.TEXT, RubezhUI.FONT_BLACK)
	left.add_child(_wave_label)
	left.add_child(RubezhUI.vspacer(6))
	left.add_child(RubezhUI.label("Закупите улучшения перед высадкой противника.", 12, RubezhUI.MUTED))

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(210, 92)
	badge.add_theme_stylebox_override("panel", RubezhUI.style_box(
		Color(0.10, 0.075, 0.025, 0.9), Color(RubezhUI.AMBER.r, RubezhUI.AMBER.g, RubezhUI.AMBER.b, 0.45), 1, 4, 16))
	var bv := VBoxContainer.new()
	badge.add_child(bv)
	bv.add_child(RubezhUI.label("КРЕДИТЫ", 10, RubezhUI.AMBER, RubezhUI.FONT_BOLD))
	_credits_label = RubezhUI.label("0", 34, RubezhUI.AMBER, RubezhUI.FONT_BLACK)
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bv.add_child(_credits_label)
	head.add_child(badge)

	v.add_child(RubezhUI.vspacer(18))
	var rule := ColorRect.new()
	rule.color = Color(RubezhUI.AMBER.r, RubezhUI.AMBER.g, RubezhUI.AMBER.b, 0.45)
	rule.custom_minimum_size = Vector2(0, 2)
	v.add_child(rule)
	v.add_child(RubezhUI.vspacer(20))

	# ---------------------------------------------------------------- grid
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(grid)
	for item in ITEMS:
		grid.add_child(_make_card(item))

	v.add_child(RubezhUI.vspacer(22))

	# ---------------------------------------------------------------- footer
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 20)
	v.add_child(foot)
	var tip := RubezhUI.label("Кредиты начисляются за убийства и завершение волн.", 11, RubezhUI.DIM)
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(tip)
	var go := RubezhUI.accent_button("НАЧАТЬ ВОЛНУ", 17)
	go.custom_minimum_size = Vector2(260, 52)
	go.pressed.connect(func(): continue_requested.emit())
	foot.add_child(go)

func _make_card(item: Dictionary) -> Control:
	var card := RubezhUI.panel(Color(0.075, 0.09, 0.105, 0.96), Color(1, 1, 1, 0.09), 5)
	card.custom_minimum_size = Vector2(320, 216)
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 14)
	outer.add_theme_constant_override("margin_right", 14)
	outer.add_theme_constant_override("margin_top", 10)
	outer.add_theme_constant_override("margin_bottom", 12)
	card.add_child(outer)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	outer.add_child(vbox)

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(0, 82)
	icon_box.add_theme_stylebox_override("panel", RubezhUI.style_box(Color(0.02, 0.025, 0.03, 0.75), Color(1, 1, 1, 0.05), 1, 3))
	var icon := TextureRect.new()
	var icons := [ICON_AK, ICON_AK, ICON_KNIFE, ICON_MED, ICON_ARMOR]
	icon.texture = icons[int(item["icon"])]
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(280, 78)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(icon)
	vbox.add_child(icon_box)
	vbox.add_child(RubezhUI.vspacer(4))
	vbox.add_child(RubezhUI.label(str(item["name"]), 14, RubezhUI.TEXT, RubezhUI.FONT_BOLD))
	var desc := RubezhUI.label(str(item["desc"]), 11, RubezhUI.MUTED)
	desc.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(desc)
	vbox.add_child(RubezhUI.vspacer(4))
	var buy := RubezhUI.button("КУПИТЬ · %d" % int(item["price"]), false, 13)
	buy.custom_minimum_size = Vector2(0, 38)
	buy.pressed.connect(func(): buy_requested.emit(str(item["id"])))
	vbox.add_child(buy)
	_cards.append({"id": str(item["id"]), "price": int(item["price"]), "button": buy})
	return card

func open(next_wave: int, credits: int) -> void:
	_wave_label.text = "ПОДГОТОВКА К ВОЛНЕ %d" % next_wave
	visible = true
	refresh(credits)
	_panel.modulate.a = 0.0
	_panel.position.y = 14
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(_panel, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func refresh(credits: int) -> void:
	_credits_label.text = str(credits)
	for c in _cards:
		var btn: Button = c["button"]
		btn.disabled = credits < int(c["price"])

func hide_panel() -> void:
	visible = false
