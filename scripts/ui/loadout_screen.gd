extends Control
## شاشة تجهيز الجندي كاملة: معاينة ثلاثية الأبعاد بمنصة (اسحب للتدوير) + تبويبات:
## الفئة، السلاح (بطاقات وإحصائيات)، المظهر (تمويه، لون البشرة، الخوذة، السترة، طلاء السلاح).

signal closed

const UI := preload("res://scripts/ui/ui.gd")
const SM := preload("res://scripts/models/soldier_model.gd")
const Thumbs := preload("res://scripts/ui/thumbs.gd")
const P := preload("res://scripts/models/parts.gd")
const M := preload("res://scripts/models/mats.gd")

var _spin: Node3D
var _dragging := false
var _pages: Array = []
var _tab_btns: Array = []
var _cbars := {}
var _wbars := {}
var _holder: Node
var _wtex := {}
var _sum: Label
var _cls_grp := ButtonGroup.new()
var _wpn_grp := ButtonGroup.new()
var _tab_grp := ButtonGroup.new()


func _ready() -> void:
	theme = UI.make_theme()
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.03, 0.98)
	UI.full_rect(bg)
	add_child(bg)
	_holder = Node.new()
	add_child(_holder)

	var margin := MarginContainer.new()
	UI.full_rect(margin)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 22)
	add_child(margin)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	# ---------- المعاينة ----------
	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.9
	root.add_child(left)
	var lv := VBoxContainer.new()
	left.add_child(lv)
	_sum = UI.label("", 26)
	_sum.add_theme_color_override("font_color", UI.AMBER)
	lv.add_child(_sum)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.custom_minimum_size = Vector2(360, 420)
	svc.gui_input.connect(_on_preview_input)
	lv.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	svc.add_child(sv)
	_build_stage(sv)
	var hint := UI.label("اسحب لتدوير الجندي", 14)
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(hint)

	# ---------- التبويبات ----------
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	right.add_child(rv)
	var head := HBoxContainer.new()
	rv.add_child(head)
	var title := UI.label("تجهيز الجندي والسلاح", 28)
	title.add_theme_color_override("font_color", UI.AMBER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UI.button("✕", _close)
	x.custom_minimum_size = Vector2(54, 42)
	head.add_child(x)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	rv.add_child(tabs)
	var names := ["الفئة", "السلاح", "المظهر"]
	for i in 3:
		var tb := Button.new()
		tb.text = names[i]
		tb.toggle_mode = true
		tb.button_group = _tab_grp
		tb.button_pressed = (i == 0)
		tb.custom_minimum_size = Vector2(0, 50)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 22)
		tb.pressed.connect(_show_tab.bind(i))
		tb.pressed.connect(func(): Sfx.ui("click"))
		UI.hover_anim(tb, 1.03)
		tabs.add_child(tb)
		_tab_btns.append(tb)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(sc)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(stack)
	_pages = [_page_class(), _page_weapon(), _page_look()]
	for pg in _pages:
		stack.add_child(pg)
	var done := UI.button("تم", _close)
	done.custom_minimum_size = Vector2(0, 54)
	done.add_theme_font_size_override("font_size", 22)
	rv.add_child(done)
	var note := UI.label("يُحفظ تلقائيًا ويُستخدم عند الانتشار في المباراة.", 14)
	note.modulate = Color(1, 1, 1, 0.55)
	rv.add_child(note)

	_show_tab(0)
	_rebuild_preview()
	_refresh_stats()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	UI.pop_in(right, 0.05)
	UI.pop_in(left, 0.0)


func _build_stage(sv: SubViewport) -> void:
	var root := Node3D.new()
	sv.add_child(root)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.65)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.07, 0.05)
	env.fog_density = 0.05
	we.environment = env
	root.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-8, 160, 0)
	rim.light_color = Color(1.0, 0.65, 0.35)
	rim.light_energy = 1.4
	root.add_child(rim)
	P.cyl(root, 1.35, 0.12, Vector3(0, -0.06, 0), M.solid(Color(0.1, 0.11, 0.1), 0.4, 0.7))
	P.cyl(root, 1.4, 0.04, Vector3(0, -0.01, 0), M.emissive(UI.AMBER, 1.6))
	P.cyl(root, 1.1, 0.02, Vector3(0, 0.0, 0), M.solid(Color(0.16, 0.18, 0.14), 0.5, 0.6))
	_spin = Node3D.new()
	_spin.rotation.y = PI + 0.4
	root.add_child(_spin)
	var cam := Camera3D.new()
	cam.fov = 38.0
	root.add_child(cam)
	cam.position = Vector3(0, 1.2, 4.4)
	cam.look_at(Vector3(0, 0.95, 0))
	cam.current = true


func _on_preview_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_dragging = e.pressed
	elif e is InputEventMouseMotion and _dragging:
		_spin.rotation.y += e.relative.x * 0.012


func _process(delta: float) -> void:
	if _spin and not _dragging:
		_spin.rotation.y += delta * 0.5


func _close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		closed.emit()
		queue_free())


func _show_tab(i: int) -> void:
	for k in _pages.size():
		(_pages[k] as Control).visible = (k == i)
	if i < _pages.size():
		UI.pop_in(_pages[i])


func _card_styles(b: Button) -> void:
	b.add_theme_stylebox_override("normal", UI.sb(Color(0.1, 0.13, 0.08, 0.95), UI.OLIVE, 2, 6, 10))
	b.add_theme_stylebox_override("hover", UI.sb(Color(0.2, 0.25, 0.1, 0.98), UI.AMBER, 3, 6, 10))
	b.add_theme_stylebox_override("pressed", UI.sb(Color(0.34, 0.27, 0.08), UI.AMBER, 4, 6, 10))
	b.add_theme_stylebox_override("hover_pressed", UI.sb(Color(0.38, 0.3, 0.09), UI.AMBER, 4, 6, 10))


func _bar_row(parent: Control, text: String, store: Dictionary, key: String) -> void:
	var row := HBoxContainer.new()
	var l := UI.label(text, 17)
	l.custom_minimum_size = Vector2(140, 0)
	row.add_child(l)
	var pb := ProgressBar.new()
	pb.max_value = 100.0
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 16)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pb)
	parent.add_child(row)
	store[key] = pb


# ---------------- صفحة الفئة ----------------
func _page_class() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in Cfg.CLASSES:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _cls_grp
		b.button_pressed = (k == Cfg.profile.cls)
		b.custom_minimum_size = Vector2(0, 96)
		_card_styles(b)
		b.pressed.connect(_pick_class.bind(k))
		b.pressed.connect(func(): Sfx.ui("click"))
		UI.hover_anim(b, 1.02)
		var cv := VBoxContainer.new()
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.full_rect(cv)
		cv.offset_left = 14.0
		cv.offset_right = -14.0
		cv.offset_top = 8.0
		var nl := UI.label(Cfg.CLASSES[k].name, 24)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(nl)
		var dl := UI.label(str(Cfg.CLASS_DESC[k]), 15)
		dl.modulate = Color(1, 1, 1, 0.7)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(dl)
		b.add_child(cv)
		v.add_child(b)
	v.add_child(HSeparator.new())
	_bar_row(v, "الصحة", _cbars, "hp")
	_bar_row(v, "سرعة الحركة", _cbars, "spd")
	return v


# ---------------- صفحة السلاح ----------------
func _page_weapon() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	v.add_child(g)
	var finish := str(Cfg.current_look().finish)
	for k in Cfg.WEAPONS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _wpn_grp
		b.button_pressed = (k == Cfg.profile.weapon)
		b.custom_minimum_size = Vector2(0, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_card_styles(b)
		b.pressed.connect(_pick_weapon.bind(k))
		b.pressed.connect(func(): Sfx.ui("click"))
		UI.hover_anim(b, 1.03)
		var cv := VBoxContainer.new()
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.full_rect(cv)
		var tr := TextureRect.new()
		tr.texture = Thumbs.weapon(_holder, k, finish)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(0, 100)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(tr)
		var nl := UI.label(Cfg.WEAPONS[k].name, 18)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(nl)
		b.add_child(cv)
		g.add_child(b)
		_wtex[k] = tr
	v.add_child(HSeparator.new())
	_bar_row(v, "قوة الضرر", _wbars, "dmg")
	_bar_row(v, "سرعة الإطلاق", _wbars, "rof")
	_bar_row(v, "سعة المخزن", _wbars, "mag")
	_bar_row(v, "المدى", _wbars, "rng")
	_bar_row(v, "سرعة التعبئة", _wbars, "rel")
	return v


# ---------------- صفحة المظهر ----------------
func _page_look() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var camo_items := []
	var camo_cols := {"digital": Color(0.36, 0.41, 0.29), "woodland": Color(0.5, 0.54, 0.34), "desert": Color(0.76, 0.65, 0.45)}
	for k in Cfg.CAMOS:
		camo_items.append([k, camo_cols[k], str(Cfg.CAMOS[k])])
	_swatch_row(v, "تمويه الزي", camo_items, "camo", 120)
	var skin_items := []
	for i in Cfg.SKINS.size():
		skin_items.append([i, Cfg.SKINS[i], "لون البشرة"])
	_swatch_row(v, "لون البشرة", skin_items, "skin", 64)
	var hel_items := []
	for i in Cfg.HELMETS.size():
		hel_items.append([i, Cfg.HELMETS[i], "الخوذة"])
	_swatch_row(v, "لون الخوذة", hel_items, "helmet", 64)
	var vest_items := []
	for i in Cfg.VESTS.size():
		vest_items.append([i, Cfg.VESTS[i], "السترة"])
	_swatch_row(v, "لون السترة", vest_items, "vest", 64)
	var fin_items := []
	for k in Cfg.FINISHES:
		fin_items.append([k, (Cfg.FINISHES[k].dark as Color).lerp(Cfg.FINISHES[k].furn, 0.5), str(Cfg.FINISHES[k].name)])
	_swatch_row(v, "طلاء السلاح", fin_items, "finish", 100)
	return v


func _swatch_row(parent: Control, title: String, items: Array, key: String, w: float) -> void:
	var l := UI.label(title, 18)
	l.add_theme_color_override("font_color", UI.AMBER)
	parent.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var grp := ButtonGroup.new()
	for it in items:
		var col: Color = it[1]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = grp
		b.custom_minimum_size = Vector2(w, 60)
		b.add_theme_stylebox_override("normal", UI.sb(col, Color(0, 0, 0, 0.7), 2, 6, 0))
		b.add_theme_stylebox_override("hover", UI.sb(col.lightened(0.12), UI.AMBER, 3, 6, 0))
		b.add_theme_stylebox_override("pressed", UI.sb(col, UI.AMBER, 5, 6, 0))
		b.add_theme_stylebox_override("hover_pressed", UI.sb(col.lightened(0.1), UI.AMBER, 5, 6, 0))
		b.button_pressed = (Cfg.profile.look[key] == it[0])
		if w > 90:
			b.text = str(it[2])
			b.add_theme_color_override("font_color", Color.WHITE)
			b.add_theme_color_override("font_hover_color", Color.WHITE)
			b.add_theme_color_override("font_pressed_color", Color.WHITE)
			b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			b.add_theme_constant_override("outline_size", 5)
		b.pressed.connect(_pick_look.bind(key, it[0]))
		b.pressed.connect(func(): Sfx.ui("click"))
		row.add_child(b)


# ---------------- الاختيار ----------------
func _pick_class(k: String) -> void:
	Cfg.profile.cls = k
	Cfg.save()
	_rebuild_preview()
	_refresh_stats()


func _pick_weapon(k: String) -> void:
	Cfg.profile.weapon = k
	Cfg.save()
	_rebuild_preview()
	_refresh_stats()


func _pick_look(key: String, val) -> void:
	Cfg.profile.look[key] = val
	Cfg.profile.look = Cfg.sanitize_look(Cfg.profile.look)
	Cfg.save()
	_rebuild_preview()
	if key == "finish":
		for c in _holder.get_children():
			c.queue_free()
		for k in _wtex:
			(_wtex[k] as TextureRect).texture = Thumbs.weapon(_holder, k, str(Cfg.profile.look.finish))


func _rebuild_preview() -> void:
	for c in _spin.get_children():
		c.queue_free()
	SM.build(_spin, Cfg.TEAMS[0].color, str(Cfg.profile.weapon), str(Cfg.profile.cls), Cfg.current_look())
	_sum.text = "%s  •  %s" % [Cfg.CLASSES[Cfg.profile.cls].name, Cfg.WEAPONS[Cfg.profile.weapon].name]


func _refresh_stats() -> void:
	var w: Dictionary = Cfg.WEAPONS[Cfg.profile.weapon]
	var c: Dictionary = Cfg.CLASSES[Cfg.profile.cls]
	var wv := {
		"dmg": clampf(float(w.dmg) / 95.0 * 100.0, 5.0, 100.0),
		"rof": clampf((1.0 / float(w.rate)) / 13.3 * 100.0, 5.0, 100.0),
		"mag": clampf(float(w.mag) / 100.0 * 100.0, 5.0, 100.0),
		"rng": clampf(float(w.range) / 600.0 * 100.0, 5.0, 100.0),
		"rel": clampf(100.0 - (float(w.reload) - 1.5) * 28.0, 10.0, 100.0),
	}
	var cv := {
		"hp": clampf(float(c.hp) / 120.0 * 100.0, 5.0, 100.0),
		"spd": clampf(float(c.speed) / 6.5 * 100.0, 5.0, 100.0),
	}
	for k in wv:
		(_wbars[k] as ProgressBar).create_tween().tween_property(_wbars[k], "value", wv[k], 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for k in cv:
		(_cbars[k] as ProgressBar).create_tween().tween_property(_cbars[k], "value", cv[k], 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
