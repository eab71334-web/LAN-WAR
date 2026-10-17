extends Control
## القائمة الرئيسية: مشهد سينمائي يدور 360°، قائمة منزلقة، نوافذ منبثقة متحركة:
## إنشاء غرفة، انضمام، تجهيز الجندي والسلاح (معاينة ثلاثية الأبعاد)، الإعدادات.

const UI := preload("res://scripts/ui/ui.gd")
const Backdrop := preload("res://scripts/ui/backdrop3d.gd")
const LoadoutScreen := preload("res://scripts/ui/loadout_screen.gd")

var _name_edit: LineEdit
var _status: Label
var _modal: PanelContainer = null
var _dim: ColorRect
var _col: Control
var _title: Label
var _host_panel: PanelContainer
var _join_panel: PanelContainer
var _set_panel: PanelContainer
var _room_edit: LineEdit
var _ip_edit: LineEdit
var _list: ItemList
var _join_status: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = UI.make_theme()
	UI.backdrop(self)
	var bd := Backdrop.new()
	UI.full_rect(bd)
	add_child(bd)
	UI.side_shade(self)
	UI.vignette(self)
	_build_column()
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0)
	UI.full_rect(_dim)
	_dim.visible = false
	add_child(_dim)
	_host_panel = _build_host()
	_join_panel = _build_join()
	_set_panel = _build_settings()

	var foot := UI.label("LAN WAR  •  v0.3  •  Godot 4", 14)
	foot.modulate = Color(1, 1, 1, 0.45)
	add_child(foot)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	foot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN

	Net.rooms_changed.connect(_refresh_rooms)
	Net.error.connect(_on_error)
	Net.joined.connect(_on_joined)
	Net.start_search()
	if Net.last_error != "":
		_status.text = Net.last_error
		Net.last_error = ""


func _exit_tree() -> void:
	Net.stop_search()
	if _name_edit:
		Cfg.profile.name = _name_edit.text.strip_edges()
		Cfg.save()


# ---------------- العمود الرئيسي ----------------

func _build_column() -> void:
	_col = Control.new()
	add_child(_col)
	_col.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_col.offset_left = 56.0
	_col.offset_right = 580.0
	_col.offset_top = -320.0
	_col.offset_bottom = 320.0

	_title = UI.label("LAN WAR", 88)
	_title.add_theme_color_override("font_color", UI.AMBER)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_title.add_theme_constant_override("outline_size", 10)
	_title.position = Vector2(0, -4)
	_col.add_child(_title)
	UI.slide_in(_title, -160.0, 0.0)
	var pulse := _title.create_tween().set_loops()
	pulse.tween_property(_title, "self_modulate", Color(1.0, 0.93, 0.78), 1.7)
	pulse.tween_property(_title, "self_modulate", Color.WHITE, 1.7)

	var bar := ColorRect.new()
	bar.color = UI.AMBER
	bar.position = Vector2(6, 124)
	bar.size = Vector2(0, 5)
	_col.add_child(bar)
	bar.create_tween().tween_property(bar, "size:x", 170.0, 0.9).set_delay(0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	var sub := UI.label("حرب عسكرية ثلاثية الأبعاد عبر الشبكة المحلية", 20)
	sub.position = Vector2(6, 138)
	sub.visible_ratio = 0.0
	_col.add_child(sub)
	sub.create_tween().tween_property(sub, "visible_ratio", 1.0, 1.4).set_delay(0.6)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "اسم اللاعب"
	_name_edit.text = Cfg.profile.name if str(Cfg.profile.name) != "" else "لاعب%d" % randi_range(100, 999)
	_name_edit.position = Vector2(0, 186)
	_name_edit.size = Vector2(440, 46)
	_col.add_child(_name_edit)
	UI.slide_in(_name_edit, -140.0, 0.1)

	var items := [
		["إنشاء غرفة LAN", func(): _open(_host_panel)],
		["الانضمام إلى غرفة", func(): _open(_join_panel)],
		["تجهيز الجندي والسلاح", func(): _open_loadout()],
		["الإعدادات", func(): _open(_set_panel)],
		["خروج", func(): get_tree().quit()],
	]
	for i in items.size():
		var b := UI.menu_button(items[i][0], items[i][1])
		b.position = Vector2(0, 252 + i * 62)
		b.size = Vector2(440, 54)
		_col.add_child(b)
		UI.slide_in(b, -180.0, 0.2 + i * 0.09)

	_status = UI.label("", 16)
	_status.modulate = Color(1, 0.5, 0.4)
	_status.position = Vector2(0, 570)
	_col.add_child(_status)


# ---------------- النوافذ المنبثقة ----------------

func _make_modal(title: String, w: float) -> PanelContainer:
	var p := PanelContainer.new()
	add_child(p)
	p.custom_minimum_size = Vector2(w, 0)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var tl := UI.label(title, 26)
	tl.modulate = UI.AMBER
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	var x := UI.button("✕", _close)
	x.custom_minimum_size = Vector2(52, 40)
	head.add_child(x)
	v.add_child(HSeparator.new())
	p.set_meta("body", v)
	return p


func _open(p: PanelContainer) -> void:
	if _modal and _modal != p:
		_modal.visible = false
	_modal = p
	_dim.visible = true
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	create_tween().tween_property(_dim, "color:a", 0.6, 0.25)
	p.visible = true
	p.modulate.a = 0.0
	await get_tree().process_frame
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(0.85, 0.85)
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_property(p, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close() -> void:
	if _modal == null:
		return
	var p := _modal
	_modal = null
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "modulate:a", 0.0, 0.18)
	tw.tween_property(p, "scale", Vector2(0.92, 0.92), 0.18)
	tw.chain().tween_callback(func(): p.visible = false)
	var td := create_tween()
	td.tween_property(_dim, "color:a", 0.0, 0.2)
	td.tween_callback(func():
		_dim.visible = false
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func _build_host() -> PanelContainer:
	var p := _make_modal("إنشاء غرفة LAN", 520)
	var body: VBoxContainer = p.get_meta("body")
	body.add_child(UI.label("اسم الغرفة", 18))
	_room_edit = LineEdit.new()
	_room_edit.text = "غرفة LAN WAR"
	body.add_child(_room_edit)
	body.add_child(UI.label("أنت المضيف: تتحكم بإعدادات المباراة وحدود المركبات.", 15))
	body.add_child(UI.button("إنشاء الغرفة", _host))
	return p


func _build_join() -> PanelContainer:
	var p := _make_modal("الانضمام إلى غرفة", 620)
	var body: VBoxContainer = p.get_meta("body")
	body.add_child(UI.label("الغرف المكتشفة على الشبكة", 18))
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 170)
	_list.item_activated.connect(_join_item)
	body.add_child(_list)
	body.add_child(UI.button("انضمام للغرفة المحددة", func(): _join_item(_list.get_selected_items()[0] if _list.get_selected_items().size() > 0 else -1)))
	var row := HBoxContainer.new()
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "أو اكتب IP المضيف مثل 192.168.1.10"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_ip_edit)
	row.add_child(UI.button("انضمام", _join_ip))
	body.add_child(row)
	_join_status = UI.label("", 16)
	_join_status.modulate = Color(1, 0.5, 0.4)
	body.add_child(_join_status)
	return p


# ---------------- تجهيز الجندي والسلاح (شاشة كاملة) ----------------

func _open_loadout() -> void:
	var ls := LoadoutScreen.new()
	add_child(ls)


# ---------------- الإعدادات ----------------

func _build_settings() -> PanelContainer:
	var p := _make_modal("الإعدادات", 600)
	var body: VBoxContainer = p.get_meta("body")
	_slider(body, "مستوى الصوت", 0.0, 1.0, 0.05, float(Cfg.opts.volume), _set_opt.bind("volume"))
	_slider(body, "حساسية النظر", 0.3, 2.5, 0.05, float(Cfg.opts.sens), _set_opt.bind("sens"))
	_slider(body, "دقة الرسوم (أداء)", 0.5, 1.0, 0.05, float(Cfg.opts.scale), _set_opt.bind("scale"))
	_slider(body, "حجم أزرار اللمس", 0.7, 1.4, 0.05, float(Cfg.opts.touch), _set_opt.bind("touch"))
	var sh := CheckBox.new()
	sh.text = "الظلال (تتطلب إعادة تحميل الخريطة)"
	sh.button_pressed = bool(Cfg.opts.shadows)
	sh.toggled.connect(_set_opt.bind("shadows"))
	body.add_child(sh)
	var fp := CheckBox.new()
	fp.text = "إظهار FPS"
	fp.button_pressed = bool(Cfg.opts.fps)
	fp.toggled.connect(_set_opt.bind("fps"))
	body.add_child(fp)
	var hint := UI.label("للأداء على الجوال: قلّل دقة الرسوم وعطّل الظلال.", 14)
	hint.modulate = Color(1, 1, 1, 0.6)
	body.add_child(hint)
	return p


func _set_opt(v, key: String) -> void:
	Cfg.opts[key] = v
	Cfg.apply_opts()
	Cfg.save()


func _slider(parent: Control, text: String, mn: float, mx: float, step: float, val: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	var l := UI.label(text, 18)
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = val
	s.custom_minimum_size = Vector2(240, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vl := UI.label("%.2f" % val, 16)
	vl.custom_minimum_size = Vector2(54, 0)
	s.value_changed.connect(func(v):
		vl.text = "%.2f" % v
		cb.call(v))
	row.add_child(s)
	row.add_child(vl)
	parent.add_child(row)


# ---------------- الاتصال ----------------

func _on_error(m: String) -> void:
	_status.text = m
	if _join_status:
		_join_status.text = m


func _host() -> void:
	Cfg.profile.name = _name_edit.text.strip_edges()
	Cfg.save()
	if Net.host_room(_name_edit.text.strip_edges(), _room_edit.text.strip_edges()):
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _join_item(i: int) -> void:
	if i < 0:
		_join_status.text = "اختر غرفة من القائمة"
		return
	_join(str(_list.get_item_metadata(i)))


func _join_ip() -> void:
	_join(_ip_edit.text.strip_edges())


func _join(ip: String) -> void:
	if ip == "":
		return
	_join_status.text = "جارٍ الاتصال..."
	Cfg.profile.name = _name_edit.text.strip_edges()
	Cfg.save()
	Net.join_room(ip, _name_edit.text.strip_edges())


func _on_joined() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _refresh_rooms() -> void:
	_list.clear()
	for ip in Net.rooms:
		var r = Net.rooms[ip]
		var i := _list.add_item("%s  (%d/%d)  — %s" % [r.name, r.n, r.max, ip])
		_list.set_item_metadata(i, ip)
