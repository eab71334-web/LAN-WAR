extends Control
## الشاشة الرئيسية: إنشاء غرفة LAN، أو الانضمام (اكتشاف تلقائي أو بالـ IP).

const UI := preload("res://scripts/ui/ui.gd")

var _name: LineEdit
var _room: LineEdit
var _ip: LineEdit
var _list: ItemList
var _status: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UI.backdrop(self)
	var c := CenterContainer.new()
	UI.full_rect(c)
	add_child(c)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(560, 0)
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)

	var t := UI.label("LAN WAR", 56)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UI.label("حرب عسكرية ثلاثية الأبعاد عبر الشبكة المحلية", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	_name = LineEdit.new()
	_name.placeholder_text = "اسم اللاعب"
	_name.text = "لاعب%d" % randi_range(100, 999)
	v.add_child(_name)
	_room = LineEdit.new()
	_room.placeholder_text = "اسم الغرفة"
	_room.text = "غرفة LAN WAR"
	v.add_child(_room)
	v.add_child(UI.button("إنشاء غرفة LAN (أنا المضيف)", _host))
	v.add_child(HSeparator.new())

	v.add_child(UI.label("الغرف المكتشفة على الشبكة", 18))
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 140)
	_list.item_activated.connect(_join_item)
	v.add_child(_list)
	v.add_child(UI.button("انضمام للغرفة المحددة", func(): _join_item(_list.get_selected_items()[0] if _list.get_selected_items().size() > 0 else -1)))

	var row := HBoxContainer.new()
	_ip = LineEdit.new()
	_ip.placeholder_text = "أو اكتب IP المضيف مثل 192.168.1.10"
	_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_ip)
	row.add_child(UI.button("انضمام", _join_ip))
	v.add_child(row)

	_status = UI.label("", 16)
	_status.modulate = Color(1, 0.5, 0.4)
	v.add_child(_status)
	v.add_child(UI.button("خروج", func(): get_tree().quit()))

	Net.rooms_changed.connect(_refresh_rooms)
	Net.error.connect(_on_error)
	Net.joined.connect(_on_joined)
	Net.start_search()
	if Net.last_error != "":
		_status.text = Net.last_error
		Net.last_error = ""


func _exit_tree() -> void:
	Net.stop_search()


func _on_error(m: String) -> void:
	_status.text = m


func _host() -> void:
	if Net.host_room(_name.text.strip_edges(), _room.text.strip_edges()):
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _join_item(i: int) -> void:
	if i < 0:
		_status.text = "اختر غرفة من القائمة"
		return
	_join(str(_list.get_item_metadata(i)))


func _join_ip() -> void:
	_join(_ip.text.strip_edges())


func _join(ip: String) -> void:
	if ip == "":
		return
	_status.text = "جارٍ الاتصال..."
	Net.join_room(ip, _name.text.strip_edges())


func _on_joined() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _refresh_rooms() -> void:
	_list.clear()
	for ip in Net.rooms:
		var r = Net.rooms[ip]
		var i := _list.add_item("%s  (%d/%d)  — %s" % [r.name, r.n, r.max, ip])
		_list.set_item_metadata(i, ip)
