extends Node3D
## المباراة: تحميل متزامن، شاشة التجهيز، الانتشار، حدود المركبات (يفرضها المضيف)، النتائج.

const MapBuilder := preload("res://scripts/match/map_builder.gd")
const SoldierS := preload("res://scripts/player/soldier.gd")
const VehicleS := preload("res://scripts/vehicles/vehicle.gd")
const Fx := preload("res://scripts/match/fx.gd")
const UI := preload("res://scripts/ui/ui.gd")
const TouchS := preload("res://scripts/ui/touch_controls.gd")

var local_soldier = null
var spawn_points := {}
var entities: Node3D
var spawner: MultiplayerSpawner
var started := false
var game_over := false
var loaded := {}
var vcount := {}
var scores := {}
var player_entity := {}
var dead_until := {}
var serial := 0
var respawn_left := 0.0

var _hud_health: Label
var _hud_vehicle: Label
var _hud_scores: Label
var _hud_msg: Label
var _loadout: PanelContainer
var _cls_opt: OptionButton
var _wpn_opt: OptionButton
var _kind_opt: OptionButton
var _deploy: Button
var _loadout_msg: Label
var _over_panel: PanelContainer
var _over_label: Label
var _cls_keys := []
var _wpn_keys := []
var _kind_keys := []


func _ready() -> void:
	Cfg.touch_live = false
	spawn_points = MapBuilder.build(self, Net.match_map)
	entities = Node3D.new()
	entities.name = "Entities"
	add_child(entities)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = NodePath("../Entities")
	spawner.spawn_function = _spawn_entity
	for cat in Cfg.LIMIT_DEFAULTS:
		vcount[cat] = 0
	for t in int(Net.settings.team_count):
		scores[t] = 0
	_build_ui()
	Net.peer_left.connect(_on_peer_left)
	_announce_loop()
	if multiplayer.is_server():
		_server_timeout()


# ---------- التحميل المتزامن ----------

func _announce_loop() -> void:
	while not started and is_inside_tree():
		_loaded.rpc_id(1)
		await get_tree().create_timer(0.7).timeout


func _server_timeout() -> void:
	await get_tree().create_timer(25.0).timeout
	if started or not is_inside_tree():
		return
	for id in Net.players.keys():
		if id != 1 and not loaded.has(id):
			multiplayer.multiplayer_peer.disconnect_peer(id)
	_go.rpc()


@rpc("any_peer", "call_local", "reliable")
func _loaded() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	loaded[id] = true
	if not started and loaded.size() >= Net.players.size():
		_go.rpc()


@rpc("authority", "call_local", "reliable")
func _go() -> void:
	if started:
		return
	started = true
	_show_loadout("")
	_refresh_kinds()


# ---------- الانتشار ----------

func _sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return 1 if s == 0 else s


func _spawn_pos(team: int, spread := 8.0) -> Vector3:
	var b: Vector3 = spawn_points.get(team, Vector3.ZERO)
	return b + Vector3(randf_range(-spread, spread), 1.0, randf_range(-spread, spread))


func _spawn_entity(d: Dictionary) -> Node:
	if d.type == "soldier":
		var s := SoldierS.new()
		s.setup(d)
		return s
	var v := VehicleS.new()
	v.setup(d)
	return v


@rpc("any_peer", "call_local", "reliable")
func request_deploy(cls: String, weapon: String, kind: String) -> void:
	if not multiplayer.is_server() or not started or game_over:
		return
	var id := _sender()
	if not Net.players.has(id):
		return
	if not Cfg.CLASSES.has(cls) or not Cfg.WEAPONS.has(weapon) or not Cfg.KINDS.has(kind):
		return
	if is_instance_valid(player_entity.get(id)):
		return
	if int(dead_until.get(id, 0)) > Time.get_ticks_msec():
		_notice.rpc_id(id, "انتظر انتهاء وقت العودة")
		return
	var team: int = Net.players[id].team
	var cat: String = Cfg.KINDS[kind].cat
	# المضيف هو المرجع لحدود المركبات
	if cat != "" and int(vcount.get(cat, 0)) >= int(Net.settings.limits.get(cat, 0)):
		_notice.rpc_id(id, "هذه المركبة غير متوفرة الآن، اختر مركبة أخرى أو انتظر")
		return
	if cat != "":
		serial += 1
		var vp := _spawn_pos(team, 14.0)
		if kind == "jet":
			vp.y = 90.0
		var face := -Vector3(vp.x, 0, vp.z).normalized()
		var v = spawner.spawn({"type": "vehicle", "name": "V%d" % serial, "kind": kind, "team": team, "pos": vp, "driver": id, "yaw": atan2(-face.x, -face.z)})
		vcount[cat] = int(vcount[cat]) + 1
		v.tree_exiting.connect(_vehicle_gone.bind(cat))
		_counts.rpc(vcount)
		serial += 1
		player_entity[id] = spawner.spawn({"type": "soldier", "name": "S%d" % serial, "peer": id, "team": team, "cls": cls, "weapon": weapon, "pos": vp})
	else:
		serial += 1
		player_entity[id] = spawner.spawn({"type": "soldier", "name": "S%d" % serial, "peer": id, "team": team, "cls": cls, "weapon": weapon, "pos": _spawn_pos(team)})


func _vehicle_gone(cat: String) -> void:
	if not multiplayer.is_server() or not Net.in_match:
		return
	vcount[cat] = maxi(0, int(vcount[cat]) - 1)
	_counts.rpc(vcount)


@rpc("authority", "call_local", "reliable")
func _counts(c: Dictionary) -> void:
	vcount = c
	_refresh_kinds()


@rpc("authority", "call_local", "reliable")
func _notice(msg: String) -> void:
	_loadout_msg.text = msg
	_hud_msg.text = msg
	await get_tree().create_timer(3.0).timeout
	if _hud_msg.text == msg:
		_hud_msg.text = ""


# ---------- القتال والنتائج ----------

func soldier_died(pid: int, attacker: int) -> void:
	if not multiplayer.is_server():
		return
	var s = player_entity.get(pid)
	if attacker != 0 and attacker != pid and Net.players.has(attacker) and Net.players.has(pid):
		var at: int = Net.players[attacker].team
		if at != Net.players[pid].team:
			scores[at] = int(scores.get(at, 0)) + 1
			_sync_scores.rpc(scores)
			if int(scores[at]) >= int(Net.settings.win_score):
				_over.rpc(at)
	for v in get_tree().get_nodes_in_group("vehicle"):
		if v.driver == pid:
			v.set_driver.rpc(0)
	dead_until[pid] = Time.get_ticks_msec() + int(float(Net.settings.respawn) * 1000.0)
	player_entity.erase(pid)
	_you_died.rpc_id(pid, float(Net.settings.respawn))
	if is_instance_valid(s):
		s.queue_free()


func vehicle_destroyed(v, attacker: int) -> void:
	if v.driver != 0:
		var s = player_entity.get(v.driver)
		if is_instance_valid(s):
			s.take_damage(99999.0, attacker, true)
	explode(v.global_position, 8.0, 160.0, attacker, v.team)


func explode(pos: Vector3, radius: float, dmg: float, attacker: int, atk_team: int) -> void:
	if not multiplayer.is_server():
		return
	for n in get_tree().get_nodes_in_group("damageable"):
		var d: float = n.global_position.distance_to(pos)
		if d <= radius and n.get("team") != atk_team:
			n.take_damage(dmg * (1.0 - 0.7 * d / radius), attacker, true)
	_boom.rpc(pos, radius)


@rpc("authority", "call_local", "unreliable")
func tracer(a: Vector3, b: Vector3) -> void:
	Fx.tracer(get_tree(), a, b)


@rpc("authority", "call_local", "unreliable")
func _boom(pos: Vector3, radius: float) -> void:
	Fx.explosion(get_tree(), pos, radius)


@rpc("authority", "call_local", "reliable")
func _sync_scores(s: Dictionary) -> void:
	scores = s


@rpc("authority", "call_local", "reliable")
func _you_died(secs: float) -> void:
	respawn_left = secs
	_show_loadout("تم إقصاؤك — العودة بعد %d ثوانٍ" % int(secs))


@rpc("authority", "call_local", "reliable")
func _over(team: int) -> void:
	game_over = true
	Cfg.touch_live = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_loadout.visible = false
	_over_panel.visible = true
	_over_label.text = "فاز %s!" % Cfg.TEAMS[team].name


func _on_peer_left(id: int) -> void:
	if not multiplayer.is_server():
		return
	for v in get_tree().get_nodes_in_group("vehicle"):
		if v.driver == id:
			v.set_driver.rpc(0)
	var s = player_entity.get(id)
	if is_instance_valid(s):
		s.queue_free()
	player_entity.erase(id)


func on_local_spawn() -> void:
	_loadout.visible = false
	Cfg.touch_live = true
	if not Cfg.is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------- الواجهة ----------

func _label(t := "", size := 22) -> Label:
	var l := UI.label(t, size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l


func _build_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var root := Control.new()
	UI.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)
	if Cfg.is_mobile:
		var tc := TouchS.new()
		UI.full_rect(tc)
		root.add_child(tc)

	_hud_scores = _label()
	root.add_child(_hud_scores)
	_hud_scores.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 10)
	_hud_scores.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_hud_health = _label()
	root.add_child(_hud_health)
	_hud_health.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	_hud_health.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_hud_vehicle = _label()
	root.add_child(_hud_vehicle)
	_hud_vehicle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	_hud_vehicle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud_vehicle.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var cross := _label("+", 28)
	root.add_child(cross)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	_hud_msg = _label("", 24)
	root.add_child(_hud_msg)
	_hud_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 50)
	_hud_msg.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_loadout = PanelContainer.new()
	root.add_child(_loadout)
	_loadout.custom_minimum_size = Vector2(440, 0)
	_loadout.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_loadout.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loadout.grow_vertical = Control.GROW_DIRECTION_BOTH
	_loadout.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_loadout.add_child(v)
	var my_team: int = Net.players.get(multiplayer.get_unique_id(), {"team": 0}).team
	var tl := UI.label("تجهيز اللاعب — " + Cfg.TEAMS[my_team].name, 22)
	tl.modulate = Cfg.TEAMS[my_team].color.lightened(0.4)
	v.add_child(tl)
	v.add_child(UI.label("فئة الجندي", 16))
	_cls_opt = OptionButton.new()
	for k in Cfg.CLASSES:
		_cls_keys.append(k)
		_cls_opt.add_item(Cfg.CLASSES[k].name)
	v.add_child(_cls_opt)
	v.add_child(UI.label("السلاح الأساسي", 16))
	_wpn_opt = OptionButton.new()
	for k in Cfg.WEAPONS:
		_wpn_keys.append(k)
		_wpn_opt.add_item(Cfg.WEAPONS[k].name)
	v.add_child(_wpn_opt)
	v.add_child(UI.label("مكان الانتشار", 16))
	_kind_opt = OptionButton.new()
	for k in Cfg.KINDS:
		_kind_keys.append(k)
		_kind_opt.add_item(Cfg.KINDS[k].name)
	v.add_child(_kind_opt)
	_loadout_msg = UI.label("", 16)
	_loadout_msg.modulate = Color(1, 0.6, 0.4)
	v.add_child(_loadout_msg)
	_deploy = UI.button("انتشار", _on_deploy)
	v.add_child(_deploy)

	_over_panel = PanelContainer.new()
	root.add_child(_over_panel)
	_over_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_over_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_over_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_over_panel.visible = false
	var ov := VBoxContainer.new()
	_over_panel.add_child(ov)
	_over_label = UI.label("", 40)
	ov.add_child(_over_label)
	var back := UI.button("العودة إلى الغرفة (المضيف)", Net.end_match)
	back.disabled = not Net.is_host
	ov.add_child(back)


func _show_loadout(msg: String) -> void:
	_loadout_msg.text = msg
	_loadout.visible = true
	Cfg.touch_live = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _refresh_kinds() -> void:
	if _kind_opt == null:
		return
	for i in _kind_keys.size():
		var k: String = _kind_keys[i]
		var cat: String = Cfg.KINDS[k].cat
		if cat == "":
			_kind_opt.set_item_text(i, Cfg.KINDS[k].name)
			continue
		var lim := int(Net.settings.limits.get(cat, 0))
		var used := int(vcount.get(cat, 0))
		_kind_opt.set_item_text(i, "%s (%d/%d)" % [Cfg.KINDS[k].name, used, lim])
		_kind_opt.set_item_disabled(i, used >= lim)


func _on_deploy() -> void:
	request_deploy.rpc_id(1, _cls_keys[_cls_opt.selected], _wpn_keys[_wpn_opt.selected], _kind_keys[_kind_opt.selected])


func _process(delta: float) -> void:
	if respawn_left > 0.0:
		respawn_left -= delta
		_deploy.disabled = respawn_left > 0.0
		if respawn_left > 0.0:
			_loadout_msg.text = "العودة بعد %d ثوانٍ" % ceili(respawn_left)
		else:
			_loadout_msg.text = ""
	var parts := []
	for t in scores:
		parts.append("%s: %d" % [Cfg.TEAMS[t].name, scores[t]])
	_hud_scores.text = "  |  ".join(parts) + "   (الفوز عند %d)" % int(Net.settings.win_score)
	var s = local_soldier
	if is_instance_valid(s):
		_hud_health.text = "الصحة: %d" % int(s.health)
		_hud_vehicle.text = s.vehicle.hud_text() if is_instance_valid(s.vehicle) else ""
	else:
		_hud_health.text = ""
		_hud_vehicle.text = ""


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif is_instance_valid(local_soldier) and not game_over:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseButton and e.pressed and is_instance_valid(local_soldier) and not game_over and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if e is InputEventKey and e.pressed and e.keycode == KEY_F10 and Net.is_host:
		Net.end_match()


func _exit_tree() -> void:
	Cfg.touch_live = false
