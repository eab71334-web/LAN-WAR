extends Control
## شاشة مراجعة الغرفة + إعدادات المضيف.

const UI := preload("res://scripts/ui/ui.gd")

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


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UI.backdrop(self)
	var margin := MarginContainer.new()
	UI.full_rect(margin)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 24)
	add_child(margin)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	margin.add_child(root)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)
	left.add_child(UI.label("LAN WAR — " + Net.room_name, 30))
	_info = UI.label("", 16)
	left.add_child(_info)
	left.add_child(UI.label("اللاعبون", 20))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sc)
	_players_box = VBoxContainer.new()
	_players_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_players_box)
	_team_row = HBoxContainer.new()
	left.add_child(_team_row)
	_err = UI.label("", 16)
	_err.modulate = Color(1, 0.4, 0.4)
	left.add_child(_err)
	_start = UI.button("بدء المباراة", Net.start_match)
	left.add_child(_start)
	left.add_child(UI.button("مغادرة الغرفة", _leave))

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(400, 0)
	root.add_child(right)
	right.add_child(UI.label("إعدادات المباراة", 22))
	_max = _spin(right, "الحد الأقصى للاعبين", 1, 16, func(v): Net.set_setting("max_players", v))
	var trow := HBoxContainer.new()
	trow.add_child(UI.label("عدد الفرق", 16))
	_teams = OptionButton.new()
	for n in [2, 3, 4]:
		_teams.add_item("%d فرق" % n)
	_teams.item_selected.connect(func(i): Net.set_setting("team_count", i + 2))
	trow.add_child(_teams)
	right.add_child(trow)
	_choice = _check(right, "السماح باختيار الفريق", func(b): Net.set_setting("team_choice", b))
	_bots = _check(right, "جنود الكمبيوتر (غير منفذ بعد)", func(b): Net.set_setting("bots", b))
	var mrow := HBoxContainer.new()
	mrow.add_child(UI.label("الخريطة", 16))
	_map = OptionButton.new()
	_map.add_item("عشوائي")
	for id in Cfg.MAPS:
		_map.add_item(Cfg.MAPS[id])
	_map.item_selected.connect(func(i): Net.set_setting("map", "" if i == 0 else Cfg.MAPS.keys()[i - 1]))
	mrow.add_child(_map)
	right.add_child(mrow)
	_win = _spin(right, "نقاط الفوز", 1, 999, func(v): Net.set_setting("win_score", v))
	_resp = _spin(right, "العودة بعد الإقصاء (ثوانٍ)", 1, 30, func(v): Net.set_setting("respawn", v))
	_dmg = _spin(right, "مستوى الضرر (×)", 0.25, 3.0, func(v): Net.set_setting("damage", v), 0.25)
	right.add_child(UI.label("مدة المباراة: بلا حد زمني", 16))
	right.add_child(HSeparator.new())
	right.add_child(UI.label("حدود المركبات (إجمالي المباراة)", 20))
	for cat in Cfg.LIMIT_DEFAULTS:
		_limit_spin[cat] = _spin(right, Cfg.LIMIT_NAMES[cat], 0, Cfg.LIMIT_DEFAULTS[cat], func(v): Net.set_limit(cat, v))
	_limit_total = UI.label("", 16)
	right.add_child(_limit_total)

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


func _refresh() -> void:
	var host := Net.is_host
	var s: Dictionary = Net.settings
	_info.text = "المتصلون: %d / %d" % [Net.players.size(), int(s.max_players)]
	for c in _players_box.get_children():
		c.queue_free()
	var ids := Net.players.keys()
	ids.sort()
	for id in ids:
		var p = Net.players[id]
		var row := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.color = Cfg.TEAMS[p.team].color
		sw.custom_minimum_size = Vector2(18, 18)
		row.add_child(sw)
		row.add_child(UI.label("%s%s — %s — متصل" % [p.name, " (المضيف)" if id == 1 else "", Cfg.TEAMS[p.team].name], 18))
		_players_box.add_child(row)

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
