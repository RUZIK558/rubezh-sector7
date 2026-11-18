extends Control
## In-game HUD: health, ammo, waves, boss, crosshair and hit feedback.

const TEX_VIGNETTE := preload("res://assets/textures/ui_vignette.png")
const TEX_VIGNETTE_RED := preload("res://assets/textures/ui_vignette_red.png")
const TEX_SCAN := preload("res://assets/textures/ui_scanlines.png")

var _health := 100.0
var _health_max := 100.0
var _health_bar: ProgressBar
var _health_label: Label
var _health_state: Label
var _health_fill: StyleBoxFlat

var _wave_kicker: Label
var _wave_name: Label
var _objective: Label
var _score_label: Label
var _combo_label: Label
var _score_panel: Control

var _mag_label: Label
var _reserve_label: Label
var _weapon_label: Label
var _reload_bar: ProgressBar
var _ammo_panel: Control

var _boss_box: Control
var _boss_fill: StyleBoxFlat
var _boss_label: Label
var _boss_bar: ProgressBar

var _banner_box: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _notice_label: Label
var _notice_tween: Tween
var _grenade_status: Label
var _knife_status: Label

var _red: TextureRect
var _damage_flash := 0.0
var _dmg_angle := 0.0
var _dmg_alpha := 0.0
var _hit_timer := 0.0
var _hit_head := false
var _on_target := false
var _target_check := 0.0
var _time := 0.0
var _display_score := 0
var _score_target := 0
var _combo := 1.0
var _boss_active := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_vignettes()
	_build_health()
	_build_wave()
	_build_score()
	_build_ammo()
	_build_boss()
	_build_banner()
	_build_notice()
	_build_throwables()
	set_process(true)

func _build_vignettes() -> void:
	var black := TextureRect.new()
	black.texture = TEX_VIGNETTE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	black.stretch_mode = TextureRect.STRETCH_SCALE
	black.modulate = Color(1, 1, 1, 0.55)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_red = TextureRect.new()
	_red.texture = TEX_VIGNETTE_RED
	_red.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_red.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_red.stretch_mode = TextureRect.STRETCH_SCALE
	_red.modulate = Color(1, 1, 1, 0.0)
	_red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_red)
	var scan := TextureRect.new()
	scan.texture = TEX_SCAN
	scan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scan.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scan.stretch_mode = TextureRect.STRETCH_TILE
	scan.modulate = Color(1, 1, 1, 0.035)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scan)

func _panel(x: float, y: float, w: float, h: float, ax := 0.0, ay := 0.0) -> VBoxContainer:
	var p := PanelContainer.new()
	p.anchor_left = ax
	p.anchor_right = ax
	p.anchor_top = ay
	p.anchor_bottom = ay
	p.offset_left = x
	p.offset_right = x + w
	p.offset_top = y
	p.offset_bottom = y + h
	var sb := RubezhUI.style_box(Color(0.025, 0.033, 0.04, 0.55), Color(1, 1, 1, 0.07), 1, 3)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 11
	sb.content_margin_bottom = 11
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	return v

func _build_health() -> void:
	var v := _panel(42, 38, 338, 94)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(RubezhUI.label("ЗДОРОВЬЕ", 10, RubezhUI.MUTED, RubezhUI.FONT_BOLD))
	_health_state = RubezhUI.label("БОЕСПОСОБЕН", 10, RubezhUI.GREEN, RubezhUI.FONT_BOLD)
	_health_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_health_state)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	_health_label = RubezhUI.label("100", 38, RubezhUI.TEXT, RubezhUI.FONT_BLACK)
	_health_label.custom_minimum_size = Vector2(82, 0)
	row.add_child(_health_label)
	var bar_box := VBoxContainer.new()
	bar_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_box.add_theme_constant_override("separation", 5)
	row.add_child(bar_box)
	var cap := RubezhUI.label("ЦЕЛОСТНОСТЬ КОРПУСА", 9, RubezhUI.DIM)
	bar_box.add_child(cap)
	_health_bar = RubezhUI.progress_bar(RubezhUI.AMBER)
	_health_bar.custom_minimum_size = Vector2(186, 7)
	_health_bar.max_value = 100
	_health_bar.value = 100
	_health_fill = _health_bar.get_theme_stylebox("fill")
	bar_box.add_child(_health_bar)

func _build_wave() -> void:
	var v := _panel(-240, 30, 480, 84, 0.5, 0.0)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	_wave_kicker = RubezhUI.label("ВОЛНА 1 / 5", 10, RubezhUI.AMBER, RubezhUI.FONT_BOLD)
	head.add_child(_wave_kicker)
	var dot := RubezhUI.label("·", 10, RubezhUI.DIM)
	head.add_child(dot)
	_objective = RubezhUI.label("ЦЕЛЕЙ: 0", 10, RubezhUI.MUTED, RubezhUI.FONT_BOLD)
	head.add_child(_objective)
	_wave_name = RubezhUI.label("РАЗВЕДКА", 20, RubezhUI.TEXT, RubezhUI.FONT_BOLD)
	_wave_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_wave_name.add_theme_constant_override("outline_size", 4)
	v.add_child(_wave_name)

func _build_score() -> void:
	var v := _panel(-306, 38, 264, 94, 1.0, 0.0)
	_score_panel = v.get_parent()
	var top := HBoxContainer.new()
	v.add_child(top)
	top.add_child(RubezhUI.label("СЧЁТ", 10, RubezhUI.MUTED, RubezhUI.FONT_BOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_combo_label = RubezhUI.label("×1.00", 13, RubezhUI.MUTED, RubezhUI.FONT_BOLD)
	top.add_child(_combo_label)
	_score_label = RubezhUI.label("0", 38, RubezhUI.TEXT, RubezhUI.FONT_BLACK)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_score_label)

func _build_ammo() -> void:
	var v := _panel(42, -132, 326, 94, 0.0, 1.0)
	_ammo_panel = v.get_parent()
	var top := HBoxContainer.new()
	v.add_child(top)
	_weapon_label = RubezhUI.label("АК-47 // 7,62×39", 10, RubezhUI.MUTED, RubezhUI.FONT_BOLD)
	top.add_child(_weapon_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_reload_bar = RubezhUI.progress_bar(RubezhUI.AMBER, Color(1, 1, 1, 0.08))
	_reload_bar.custom_minimum_size = Vector2(100, 3)
	_reload_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reload_bar.visible = false
	top.add_child(_reload_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	v.add_child(row)
	_mag_label = RubezhUI.label("30", 40, RubezhUI.TEXT, RubezhUI.FONT_BLACK)
	_mag_label.custom_minimum_size = Vector2(68, 0)
	row.add_child(_mag_label)
	_reserve_label = RubezhUI.label("/ 120", 17, RubezhUI.MUTED, RubezhUI.FONT_SEMIBOLD)
	_reserve_label.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_reserve_label)

func _build_boss() -> void:
	_boss_box = Control.new()
	_boss_box.anchor_left = 0.5
	_boss_box.anchor_right = 0.5
	_boss_box.offset_left = -300
	_boss_box.offset_right = 300
	_boss_box.offset_top = 128
	_boss_box.offset_bottom = 194
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	add_child(_boss_box)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 4)
	_boss_box.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_boss_label = RubezhUI.label("ТИТАН // ОСАДНЫЙ КЛАСС", 11, RubezhUI.RED, RubezhUI.FONT_BOLD)
	top.add_child(_boss_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var boss_hp := RubezhUI.label("1600", 11, RubezhUI.MUTED, RubezhUI.FONT_BOLD)
	boss_hp.name = "BossHP"
	top.add_child(boss_hp)
	_boss_bar = RubezhUI.progress_bar(RubezhUI.RED, Color(0.1, 0.02, 0.02, 0.8))
	_boss_bar.custom_minimum_size = Vector2(600, 11)
	_boss_bar.max_value = 1600
	_boss_bar.value = 1600
	_boss_fill = _boss_bar.get_theme_stylebox("fill")
	v.add_child(_boss_bar)

func _build_banner() -> void:
	_banner_box = VBoxContainer.new()
	_banner_box.anchor_left = 0.5
	_banner_box.anchor_right = 0.5
	_banner_box.anchor_top = 0.32
	_banner_box.anchor_bottom = 0.32
	_banner_box.offset_left = -380
	_banner_box.offset_right = 380
	_banner_box.offset_top = -50
	_banner_box.offset_bottom = 50
	_banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_box.add_theme_constant_override("separation", 6)
	_banner_box.modulate.a = 0.0
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner_box)
	_banner_title = RubezhUI.label("", 46, RubezhUI.TEXT, RubezhUI.FONT_BLACK)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_banner_title.add_theme_constant_override("outline_size", 8)
	_banner_box.add_child(_banner_title)
	_banner_sub = RubezhUI.label("", 15, RubezhUI.AMBER, RubezhUI.FONT_SEMIBOLD)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_box.add_child(_banner_sub)

func _build_notice() -> void:
	_notice_label = RubezhUI.label("", 14, RubezhUI.AMBER, RubezhUI.FONT_SEMIBOLD)
	_notice_label.anchor_left = 0.5
	_notice_label.anchor_right = 0.5
	_notice_label.anchor_top = 0.5
	_notice_label.anchor_bottom = 0.5
	_notice_label.offset_left = -260
	_notice_label.offset_right = 260
	_notice_label.offset_top = 64
	_notice_label.offset_bottom = 92
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.modulate.a = 0.0
	_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notice_label)
	var hint := RubezhUI.label("WASD — ДВИЖЕНИЕ   ·   ЛКМ — ОГОНЬ   ·   ПКМ — ПРИЦЕЛ   ·   1–3 / КОЛЕСО — ОРУЖИЕ   ·   V — НОЖ   ·   G — ГРАНАТА   ·   R — ПЕРЕЗАРЯДКА   ·   ESC — ПАУЗА", 10, RubezhUI.DIM, RubezhUI.FONT_MEDIUM)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -430
	hint.offset_right = 430
	hint.offset_top = -32
	hint.offset_bottom = -12
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

func _build_throwables() -> void:
	var box := PanelContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -150
	box.offset_right = 150
	box.offset_top = -92
	box.offset_bottom = -56
	box.add_theme_stylebox_override("panel", RubezhUI.style_box(Color(0.02, 0.028, 0.035, 0.55), Color(1, 1, 1, 0.06), 1, 3))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_grenade_status = RubezhUI.label("ГРАНАТА ×2 [G]", 11, RubezhUI.TEXT, RubezhUI.FONT_BOLD)
	_knife_status = RubezhUI.label("НОЖ [V]", 11, RubezhUI.MUTED, RubezhUI.FONT_BOLD)
	row.add_child(_grenade_status)
	row.add_child(_knife_status)

func _process(delta: float) -> void:
	_time += delta
	_damage_flash = maxf(0.0, _damage_flash - delta * 1.6)
	_dmg_alpha = maxf(0.0, _dmg_alpha - delta * 0.9)
	_hit_timer = maxf(0.0, _hit_timer - delta)
	_display_score = int(lerpf(float(_display_score), float(_score_target), clampf(delta * 8.0, 0, 1)))
	if absf(float(_display_score) - float(_score_target)) < 2:
		_display_score = _score_target
	_score_label.text = _fmt(_display_score)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var gc: float = player.get_grenade_cd()
		var kc: float = player.get_knife_cd()
		var g_cd_text := ""
		if gc > 0.0:
			g_cd_text = " %.1f" % gc
		var k_cd_text := ""
		if kc > 0.0:
			k_cd_text = " %.1f" % kc
		_grenade_status.text = "ГРАНАТА ×%d [G]%s" % [player.get_grenades(), g_cd_text]
		_knife_status.text = "НОЖ [V]%s" % k_cd_text
		_grenade_status.add_theme_color_override("font_color", RubezhUI.DIM if gc > 0.0 or player.get_grenades() <= 0 else RubezhUI.TEXT)
		_knife_status.add_theme_color_override("font_color", RubezhUI.DIM if kc > 0.0 else RubezhUI.MUTED)
	if player and player.get_weapon():
		var weapon = player.get_weapon()
		_reload_bar.value = weapon.get_reload_fraction() * 100.0
		_reload_bar.visible = weapon.reloading and not weapon.is_melee
	var low := 0.0
	if _health < 35.0 and _health > 0.0:
		low = 0.12 + 0.10 * (0.5 + 0.5 * sin(_time * 5.0))
	_red.modulate.a = clampf(maxf(_damage_flash * 0.85, low), 0.0, 0.75)
	# target under crosshair
	_target_check -= delta
	if _target_check <= 0.0:
		_target_check = 0.09
		_update_target()
	queue_redraw()

func _update_target() -> void:
	_on_target = false
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var to := from - cam.global_basis.z * 90.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 8)
	var r: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	_on_target = not r.is_empty()

func _draw() -> void:
	var center := size * 0.5
	if not visible:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var spread := 6.0
	var ads := 0.0
	if player and player.get_weapon():
		var w: Node = player.get_weapon()
		ads = w.ads_amount
		var spd: float = Vector2(player.velocity.x, player.velocity.z).length()
		spread += clampf(spd / 7.0, 0.0, 1.0) * 7.0
		if not player.is_on_floor():
			spread += 5.0
		spread += 4.0 * (1.0 - ads)
	spread = lerpf(spread, 4.0, ads)
	var gap := spread
	var length := lerpf(7.0, 3.5, ads)
	var col := RubezhUI.AMBER if _on_target else Color(1.0, 0.97, 0.9, 0.92)
	var dirs := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for d in dirs:
		var a: Vector2 = center + d * gap
		var b: Vector2 = center + d * (gap + length)
		draw_line(a, b, Color(0, 0, 0, 0.55), 4.0)
		draw_line(a, b, col, 1.7)
	draw_circle(center, 1.5, col)
	if _hit_timer > 0.0:
		var a := clampf(_hit_timer / 0.16, 0.0, 1.0)
		var hc := RubezhUI.AMBER if _hit_head else Color(1, 1, 1, 0.95)
		hc.a = a
		for d in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			draw_line(center + d * 8.0, center + d * 16.0, Color(0, 0, 0, 0.5 * a), 3.6)
			draw_line(center + d * 8.0, center + d * 16.0, hc, 1.8)
	if _dmg_alpha > 0.0:
		var c := Color(0.95, 0.16, 0.1, _dmg_alpha * 0.9)
		draw_arc(center, 92.0, _dmg_angle - 0.19, _dmg_angle + 0.19, 10, c, 6.0, true)

func set_health(current: float, maximum: float) -> void:
	_health = current
	_health_max = maximum
	_health_label.text = str(int(ceil(current)))
	_health_bar.max_value = maximum
	_health_bar.value = current
	var frac: float = current / maximum if maximum > 0 else 0.0
	var col := RubezhUI.GREEN if frac > 0.55 else (RubezhUI.AMBER if frac > 0.25 else RubezhUI.RED)
	_health_fill.bg_color = col
	_health_state.text = "БОЕСПОСОБЕН" if frac > 0.55 else ("ПОВРЕЖДЁН" if frac > 0.25 else "КРИТИЧЕСКИ")
	_health_state.add_theme_color_override("font_color", col)
	_health_label.add_theme_color_override("font_color", col if frac <= 0.25 else RubezhUI.TEXT)

func set_ammo(mag: int, reserve: int) -> void:
	if mag < 0:
		_mag_label.text = "∞"
		_reserve_label.text = "БЕСКОНЕЧНО"
		_mag_label.add_theme_color_override("font_color", RubezhUI.TEXT)
		_reload_bar.visible = false
		return
	_mag_label.text = str(mag)
	_reserve_label.text = "/ %d" % reserve
	var col := RubezhUI.TEXT
	if mag <= 5:
		col = RubezhUI.RED
	elif mag <= 10:
		col = RubezhUI.AMBER
	_mag_label.add_theme_color_override("font_color", col)

func set_reload(value: float) -> void:
	_reload_bar.visible = value > 0.0
	_reload_bar.value = value * 100.0

func set_weapon_name(label: String) -> void:
	_weapon_label.text = label.to_upper()

func set_wave(index: int, total: int, wave_title: String, enemies: int) -> void:
	_wave_kicker.text = "ВОЛНА %d / %d" % [index, total]
	_wave_name.text = wave_title
	_objective.text = "ЦЕЛЕЙ: %d" % enemies

func set_objective(enemies: int) -> void:
	_objective.text = "ЦЕЛЕЙ: %d" % enemies

func set_score(score: int, combo: float) -> void:
	_score_target = score
	_combo = combo
	_combo_label.text = "×%.2f" % combo
	_combo_label.add_theme_color_override("font_color", RubezhUI.AMBER if combo > 1.01 else RubezhUI.MUTED)

func show_hitmarker(headshot: bool) -> void:
	_hit_timer = 0.16
	_hit_head = headshot

func damage_from(source: Vector3) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var local: Vector3 = player.camera.global_transform.affine_inverse() * source
	_dmg_angle = atan2(local.z, local.x)
	_dmg_alpha = 1.0
	_damage_flash = 1.0

func show_banner(title: String, subtitle: String, hold := 2.2, color := RubezhUI.TEXT) -> void:
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_title.text = title
	_banner_sub.text = subtitle
	_banner_title.add_theme_color_override("font_color", color)
	_banner_box.modulate.a = 0.0
	_banner_box.offset_top = -50.0
	_banner_box.offset_bottom = 50.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_box, "modulate:a", 1.0, 0.35)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(_banner_box, "modulate:a", 0.0, 0.6)
	_banner_tween.parallel().tween_property(_banner_box, "offset_top", -68.0, 0.6)
	_banner_tween.parallel().tween_property(_banner_box, "offset_bottom", 32.0, 0.6)

func notice(text: String) -> void:
	if _notice_tween and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice_label.text = text
	_notice_label.modulate.a = 0.0
	_notice_tween = create_tween()
	_notice_tween.tween_property(_notice_label, "modulate:a", 1.0, 0.15)
	_notice_tween.tween_interval(1.2)
	_notice_tween.tween_property(_notice_label, "modulate:a", 0.0, 0.5)

func show_boss(maximum: float) -> void:
	_boss_active = true
	_boss_box.visible = true
	_boss_bar.max_value = maximum
	_boss_bar.value = maximum
	var hp := _boss_box.find_child("BossHP", true, false) as Label
	if hp:
		hp.text = str(int(maximum))

func update_boss(current: float, maximum: float) -> void:
	_boss_active = true
	_boss_bar.max_value = maximum
	_boss_bar.value = current
	var hp := _boss_box.find_child("BossHP", true, false) as Label
	if hp:
		hp.text = str(int(ceil(current)))

func set_boss_name(text: String) -> void:
	_boss_label.text = text

func hide_boss() -> void:
	_boss_active = false
	_boss_box.visible = false

func kill_popup(points: int, headshot: bool) -> void:
	var l := RubezhUI.label(("ХЕДШОТ  " if headshot else "") + "+%d" % points, 15 if not headshot else 17,
			RubezhUI.AMBER if headshot else Color(1, 1, 1, 0.92), RubezhUI.FONT_BOLD)
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 0.5
	l.anchor_bottom = 0.5
	l.offset_left = -120
	l.offset_right = 120
	l.offset_top = 46
	l.offset_bottom = 74
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "offset_top", -6.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "offset_bottom", 22.0, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)

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
