extends Control
## الشاشة الرئيسية: خلفية ثلاثية الأبعاد (راجمة M270)، إنشاء غرفة LAN أو الانضمام.

const UI := preload("res://scripts/ui/ui.gd")
const VM := preload("res://scripts/models/vehicle_models.gd")
const MapBuilder := preload("res://scripts/match/map_builder.gd")
const M := preload("res://scripts/models/mats.gd")

var _name: LineEdit
var _room: LineEdit
var _ip: LineEdit
var _list: ItemList
var _status: Label
var _spin: Node3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = UI.make_theme()
	UI.backdrop(self)
	_build_backdrop()

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	UI.full_rect(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var c := CenterContainer.new()
	UI.full_rect(c)
	add_child(c)
	var panel := PanelContainer.new()
	c.add_child(panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(560, 0)
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var t := UI.label("LAN WAR", 60)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", UI.AMBER)
	v.add_child(t)
	var sub := UI.label("حرب عسكرية ثلاثية الأبعاد عبر الشبكة المحلية", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(HSeparator.new())

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
	_list.custom_minimum_size = Vector2(0, 120)
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


func _build_backdrop() -> void:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	UI.full_rect(svc)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.size = Vector2i(1280, 720)
	svc.add_child(sv)
	var root := Node3D.new()
	sv.add_child(root)
	MapBuilder.setup_env(root, "desert_base")
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	ground.material_override = M.ground(Color(0.62, 0.5, 0.33), Color(0.75, 0.62, 0.42), 0.06)
	root.add_child(ground)
	_spin = Node3D.new()
	root.add_child(_spin)
	var turret := Node3D.new()
	_spin.add_child(turret)
	VM.build(_spin, turret, "mlrs", Cfg.TEAMS[0].color)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(9.5, 4.2, 11.5)
	cam.look_at(Vector3(0, 2.2, 0))
	cam.current = true


func _process(delta: float) -> void:
	if _spin:
		_spin.rotation.y += delta * 0.25


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
