extends Node3D
## المباراة: تحميل متزامن، شاشة التجهيز، الانتشار، حدود المركبات (يفرضها المضيف)، النتائج.

const MapBuilder := preload("res://scripts/match/map_builder.gd")
const SoldierS := preload("res://scripts/player/soldier.gd")
const VehicleS := preload("res://scripts/vehicles/vehicle.gd")
const Fx := preload("res://scripts/match/fx.gd")
const UI := preload("res://scripts/ui/ui.gd")
const HudS := preload("res://scripts/ui/hud.gd")
const TouchS := preload("res://scripts/ui/touch_controls.gd")
const Buildings := preload("res://scripts/match/buildings.gd")
const SM := preload("res://scripts/models/soldier_model.gd")

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

var hud: Control
var _loadout: PanelContainer
var _kind_btns := {}
var _loadout_msg: Label
var _over_panel: PanelContainer
var _over_label: Label
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
	var wind := AudioStreamPlayer.new()
	wind.stream = Sfx.stream("wind")
	wind.volume_db = -20.0
	add_child(wind)
	if wind.stream:
		wind.play()
	Net.peer_left.connect(_on_peer_left)
	_announce_loop()
	if multiplayer.is_server():
		_server_timeout()


func _exit_tree() -> void:
	Cfg.touch_live = false


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
		v.tree_exiting.connect(_vehicle_gone.bind(v, cat))
		_counts.rpc(vcount)
		serial += 1
		player_entity[id] = spawner.spawn({"type": "soldier", "name": "S%d" % serial, "peer": id, "team": team, "cls": cls, "weapon": weapon, "pos": vp})
	else:
		serial += 1
		player_entity[id] = spawner.spawn({"type": "soldier", "name": "S%d" % serial, "peer": id, "team": team, "cls": cls, "weapon": weapon, "pos": _spawn_pos(team)})


func release_slot(v) -> void:
	if not multiplayer.is_server() or v.released:
		return
	v.released = true
	var cat: String = Cfg.KINDS[v.kind].cat
	vcount[cat] = maxi(0, int(vcount[cat]) - 1)
	_counts.rpc(vcount)


func _vehicle_gone(v, cat: String) -> void:
	if not multiplayer.is_server() or not Net.in_match or v.released:
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
	hud.notice(msg)


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
		if not is_instance_valid(s.vehicle):
			_corpse.rpc(s.global_position, s.rotation.y, Net.players[pid].team, str(s.weapon), str(s.cls))
		s.queue_free()


func vehicle_destroyed(v, attacker: int) -> void:
	if v.driver != 0:
		var s = player_entity.get(v.driver)
		if is_instance_valid(s):
			s.take_damage(99999.0, attacker, true)
	explode(v.global_position, 9.0, 160.0, attacker, v.team)


func explode(pos: Vector3, radius: float, dmg: float, attacker: int, atk_team: int) -> void:
	if not multiplayer.is_server():
		return
	for n in get_tree().get_nodes_in_group("damageable"):
		var d: float = n.global_position.distance_to(pos)
		if d <= radius and n.get("team") != atk_team:
			n.take_damage(dmg * (1.0 - 0.7 * d / radius), attacker, true)
	_boom.rpc(pos, radius)


@rpc("authority", "call_local", "unreliable")
func tracer(a: Vector3, b: Vector3, kind: String) -> void:
	Fx.tracer(get_tree(), a, b, kind)


@rpc("authority", "call_local", "reliable")
func rocket_fx(a: Vector3, b: Vector3, t: float, h: float) -> void:
	Fx.rocket(get_tree(), a, b, t, h)


@rpc("authority", "call_local", "reliable")
func _boom(pos: Vector3, radius: float) -> void:
	Fx.explosion(get_tree(), pos, radius)
	Buildings.destroy(get_tree(), pos, radius)


@rpc("authority", "call_local", "unreliable")
func _hitmark() -> void:
	hud.hitmark()
	Sfx.ui("hit_flesh", -4.0)


@rpc("authority", "call_local", "reliable")
func _sync_scores(s: Dictionary) -> void:
	scores = s


@rpc("authority", "call_local", "reliable")
func _you_died(secs: float) -> void:
	respawn_left = secs
	_show_loadout("تم إقصاؤك")


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

func _build_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var root := Control.new()
	UI.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme()
	cl.add_child(root)

	hud = HudS.new()
	UI.full_rect(hud)
	root.add_child(hud)
	if Cfg.is_mobile:
		var tc := TouchS.new()
		UI.full_rect(tc)
		root.add_child(tc)

	_loadout = PanelContainer.new()
	root.add_child(_loadout)
	_loadout.custom_minimum_size = Vector2(540, 0)
	_loadout.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_loadout.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loadout.grow_vertical = Control.GROW_DIRECTION_BOTH
	_loadout.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_loadout.add_child(v)
	var my_team: int = Net.players.get(multiplayer.get_unique_id(), {"team": 0}).team
	var tl := UI.label("اختر مكان الانتشار — " + Cfg.TEAMS[my_team].name, 26)
	tl.modulate = Cfg.TEAMS[my_team].color.lightened(0.45)
	v.add_child(tl)
	var info := UI.label("%s  •  %s   (يتغيّر من القائمة الرئيسية)" % [Cfg.CLASSES[Cfg.profile.cls].name, Cfg.WEAPONS[Cfg.profile.weapon].name], 15)
	info.modulate = UI.AMBER
	v.add_child(info)
	v.add_child(HSeparator.new())
	for k in Cfg.KINDS:
		_kind_keys.append(k)
		var b := UI.button(Cfg.KINDS[k].name, _on_deploy.bind(k))
		b.custom_minimum_size = Vector2(0, 58 if Cfg.is_mobile else 48)
		_kind_btns[k] = b
		v.add_child(b)
	_loadout_msg = UI.label("", 16)
	_loadout_msg.modulate = Color(1, 0.6, 0.4)
	v.add_child(_loadout_msg)

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
	for k in _kind_keys:
		var cat: String = Cfg.KINDS[k].cat
		if cat == "":
			continue
		var lim := int(Net.settings.limits.get(cat, 0))
		var used := int(vcount.get(cat, 0))
		var b: Button = _kind_btns[k]
		b.text = "%s   (%d / %d)" % [Cfg.KINDS[k].name, used, lim]
		b.disabled = used >= lim or respawn_left > 0.0


func _set_deploy(on: bool) -> void:
	for k in _kind_keys:
		var cat: String = Cfg.KINDS[k].cat
		var full := cat != "" and int(vcount.get(cat, 0)) >= int(Net.settings.limits.get(cat, 0))
		(_kind_btns[k] as Button).disabled = (not on) or full


func _on_deploy(kind: String) -> void:
	request_deploy.rpc_id(1, Cfg.profile.cls, Cfg.profile.weapon, kind)


func _process(delta: float) -> void:
	if respawn_left > 0.0:
		respawn_left -= delta
		_set_deploy(respawn_left <= 0.0)
		if respawn_left > 0.0:
			_loadout_msg.text = "العودة بعد %d ثوانٍ" % ceili(respawn_left)
		else:
			_loadout_msg.text = ""


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and not hud.panel_open():
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif is_instance_valid(local_soldier) and not game_over:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseButton and e.pressed and is_instance_valid(local_soldier) and not game_over and not hud.panel_open() and not Cfg.is_mobile and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if e is InputEventKey and e.pressed and e.keycode == KEY_F10 and Net.is_host:
		Net.end_match()


@rpc("authority", "call_local", "reliable")
func _corpse(pos: Vector3, yaw: float, team: int, weapon: String, cls: String) -> void:
	Sfx.play3d("death", pos, 2.0, 1.0, 80.0)
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = pos
	holder.rotation.y = yaw
	var m := SM.build(holder, Cfg.TEAMS[team].color, weapon, cls)
	var tw := holder.create_tween()
	tw.tween_property(holder, "rotation:x", -PI * 0.5, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(holder, "position:y", pos.y + 0.15, 0.55)
	tw.tween_interval(9.0)
	tw.tween_property(holder, "position:y", pos.y - 1.2, 2.0)
	tw.tween_callback(holder.queue_free)
	var dummy = m
