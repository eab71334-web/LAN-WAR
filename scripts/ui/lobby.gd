extends Control
## غرفة LAN: مشهد 360° خلف الواجهة، بطاقات لاعبين متحركة، وإعدادات المضيف.

const UI := preload("res://scripts/ui/ui.gd")
const Backdrop := preload("res://scripts/ui/backdrop3d.gd")

var _players_box: VBoxContainer
var _info: Label
var _err: Label
var _start: Button
var _team_row: HBoxContainer
var _max: SpinBox
var _teams: OptionButton
var _choice: CheckBox
var _bots: CheckBox
var _map: OptionButton
var _win: SpinBox
var _resp: SpinBox
var _dmg: SpinBox
var _limit_spin := {}
var _limit_total: Label
var _last_count := -1


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = UI.make_theme()
	UI.backdrop(self)
	var bd := Backdrop.new()
	bd.radius = 24.0
	bd.height = 6.5
	bd.speed = 0.07
	UI.full_rect(bd)
	add_child(bd)
	UI.vignette(self, 0.85)

	var margin := MarginContainer.new()
	UI.full_rect(margin)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 24)
	add_child(margin)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 22)
	margin.add_child(root)

	# ---- اللوحة اليسرى: اللاعبون ----
	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)
	var title := UI.label("LAN WAR", 40)
	title.add_theme_color_override("font_color", UI.AMBER)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 6)
	lv.add_child(title)
	var rn := UI.label("الغرفة: " + Net.room_name, 20)
	lv.add_child(rn)
	_info = UI.label("", 16)
	lv.add_child(_info)
	lv.add_child(HSeparator.new())
	lv.add_child(UI.label("اللاعبون", 20))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(sc)
	_players_box = VBoxContainer.new()
	_players_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_players_box.add_theme_constant_override("separation", 6)
	sc.add_child(_players_box)
	_team_row = HBoxContainer.new()
	lv.add_child(_team_row)
	_err = UI.label("", 16)
	_err.modulate = Color(1, 0.4, 0.4)
	lv.add_child(_err)
	_start = UI.button("▶  بدء المباراة", Net.start_match)
	_start.custom_minimum_size = Vector2(0, 58)
	_start.add_theme_font_size_override("font_size", 24)
	lv.add_child(_start)
	var pulse := _start.create_tween().set_loops()
	pulse.tween_property(_start, "self_modulate", Color(1.25, 1.15, 0.8), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_start, "self_modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)
	lv.add_child(UI.button("مغادرة الغرفة", _leave))
	UI.pop_in(left, 0.05)

	# ---- اللوحة اليمنى: الإعدادات ----
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(430, 0)
	root.add_child(right)
	var rsc := ScrollContainer.new()
	rsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rsc)
	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_theme_constant_override("separation", 6)
	rsc.add_child(rv)
	var st := UI.label("إعدادات المباراة", 24)
	st.add_theme_color_override("font_color", UI.AMBER)
	rv.add_child(st)
	_max = _spin(rv, "الحد الأقصى للاعبين", 1, 16, func(v): Net.set_setting("max_players", v))
	var trow := HBoxContainer.new()
	var tl := UI.label("عدد الفرق", 16)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(tl)
	_teams = OptionButton.new()
	for n in [2, 3, 4]:
		_teams.add_item("%d فرق" % n)
	_teams.item_selected.connect(func(i): Net.set_setting("team_count", i + 2))
	trow.add_child(_teams)
	rv.add_child(trow)
	_choice = _check(rv, "السماح باختيار الفريق", func(b): Net.set_setting("team_choice", b))
	_bots = _check(rv, "جنود الكمبيوتر (غير منفذ بعد)", func(b): Net.set_setting("bots", b))
	var mrow := HBoxContainer.new()
	var ml := UI.label("الخريطة", 16)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(ml)
	_map = OptionButton.new()
	_map.add_item("عشوائي")
	for id in Cfg.MAPS:
		_map.add_item(Cfg.MAPS[id])
	_map.item_selected.connect(func(i): Net.set_setting("map", "" if i == 0 else Cfg.MAPS.keys()[i - 1]))
	mrow.add_child(_map)
	rv.add_child(mrow)
	_win = _spin(rv, "نقاط الفوز", 1, 999, func(v): Net.set_setting("win_score", v))
	_resp = _spin(rv, "العودة بعد الإقصاء (ثوانٍ)", 1, 30, func(v): Net.set_setting("respawn", v))
	_dmg = _spin(rv, "مستوى الضرر (×)", 0.25, 3.0, func(v): Net.set_setting("damage", v), 0.25)
	rv.add_child(UI.label("مدة المباراة: بلا حد زمني", 15))
	rv.add_child(HSeparator.new())
	var lt := UI.label("حدود المركبات (إجمالي المباراة)", 20)
	lt.add_theme_color_override("font_color", UI.AMBER)
	rv.add_child(lt)
	for cat in Cfg.LIMIT_DEFAULTS:
		_limit_spin[cat] = _spin(rv, Cfg.LIMIT_NAMES[cat], 0, Cfg.LIMIT_DEFAULTS[cat], func(v): Net.set_limit(cat, v))
	_limit_total = UI.label("", 16)
	rv.add_child(_limit_total)
	UI.pop_in(right, 0.15)

	Net.players_changed.connect(_refresh)
	Net.error.connect(_on_error)
	_refresh()


func _on_error(m: String) -> void:
	_err.text = m


func _spin(parent: Control, text: String, mn: float, mx: float, cb: Callable, step := 1.0) -> SpinBox:
	var row := HBoxContainer.new()
	var l := UI.label(text, 16)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = mn
	sb.max_value = mx
	sb.step = step
	sb.value_changed.connect(cb)
	row.add_child(sb)
	parent.add_child(row)
	return sb


func _check(parent: Control, text: String, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.toggled.connect(cb)
	parent.add_child(c)
	return c


func _leave() -> void:
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _card(pname: String, team: int, is_host: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.sb(Color(0.05, 0.07, 0.04, 0.85), Cfg.TEAMS[team].color, 2, 5, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var bar := ColorRect.new()
	bar.color = Cfg.TEAMS[team].color
	bar.custom_minimum_size = Vector2(8, 34)
	row.add_child(bar)
	var nm := UI.label(("👑 " if is_host else "") + pname, 20)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nm)
	var tg := UI.label(Cfg.TEAMS[team].name, 16)
	tg.modulate = Cfg.TEAMS[team].color.lightened(0.4)
	row.add_child(tg)
	var ok := UI.label("● متصل", 14)
	ok.modulate = Color(0.4, 1.0, 0.4)
	row.add_child(ok)
	return card


func _refresh() -> void:
	var host := Net.is_host
	var s: Dictionary = Net.settings
	_info.text = "المتصلون: %d / %d" % [Net.players.size(), int(s.max_players)]
	for c in _players_box.get_children():
		c.queue_free()
	var ids := Net.players.keys()
	ids.sort()
	var idx := 0
	for id in ids:
		var p = Net.players[id]
		var card := _card(str(p.name), int(p.team), id == 1)
		_players_box.add_child(card)
		if Net.players.size() != _last_count:
			UI.pop_in(card, idx * 0.06)
		idx += 1
	_last_count = Net.players.size()

	for c in _team_row.get_children():
		c.queue_free()
	if s.team_choice and not s.locked:
		for t in int(s.team_count):
			var b := Button.new()
			b.text = Cfg.TEAMS[t].name
			b.modulate = Cfg.TEAMS[t].color.lightened(0.4)
			b.pressed.connect(func(): Net.request_team(t))
			_team_row.add_child(b)

	_max.set_value_no_signal(s.max_players)
	_max.editable = host
	_teams.select(int(s.team_count) - 2)
	_teams.disabled = not host
	_choice.set_pressed_no_signal(s.team_choice)
	_choice.disabled = not host
	_bots.set_pressed_no_signal(s.bots)
	_bots.disabled = not host
	var mi := 0
	if s.map != "":
		mi = Cfg.MAPS.keys().find(s.map) + 1
	_map.select(mi)
	_map.disabled = not host
	_win.set_value_no_signal(s.win_score)
	_win.editable = host
	_resp.set_value_no_signal(s.respawn)
	_resp.editable = host
	_dmg.set_value_no_signal(s.damage)
	_dmg.editable = host
	var total := 0
	for cat in _limit_spin:
		_limit_spin[cat].set_value_no_signal(s.limits[cat])
		_limit_spin[cat].editable = host
		total += int(s.limits[cat])
	_limit_total.text = "الإجمالي: %d (الحد الأقصى 52)" % total
	_start.visible = host
