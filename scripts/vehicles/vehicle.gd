extends CharacterBody3D
## مركبة واحدة بسكربت واحد: جيب / ناقلة / دبابة / راجمة / مروحية / طائرة.
## المحاكاة كلها على المضيف. السائق يرسل مدخلاته فقط، والموقع يُزامَن للجميع.

const Fx := preload("res://scripts/match/fx.gd")

var kind := "jeep"
var team := 0
var driver := 0
var health := 100.0
var ammo := -1
var cur_speed := 0.0
var st: Dictionary

var in_thr := 0.0
var in_str := 0.0
var in_lift := 0.0
var in_pitch := 0.0
var in_roll := 0.0
var in_aim_yaw := 0.0
var in_fire := false
var in_orig := Vector3.ZERO
var in_dir := Vector3.FORWARD

var _throttle := 0.6
var _next_fire := 0.0
var _reload := 0.0
var _dead := false
var _rig: Node3D
var _arm: SpringArm3D
var _cam: Camera3D
var _cam_yaw := 0.0
var _cam_pitch := -0.25
var turret: Node3D
var rotor: Node3D


func setup(d: Dictionary) -> void:
	name = d.name
	kind = d.kind
	team = d.team
	driver = d.driver
	position = d.pos
	rotation.y = d.get("yaw", 0.0)
	st = Cfg.VSTATS[kind]
	health = st.hp
	ammo = int(st.ammo)
	_cam_yaw = rotation.y


func _ready() -> void:
	add_to_group("vehicle")
	add_to_group("damageable")
	var size: Vector3 = st.size
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	col.position.y = size.y / 2.0
	add_child(col)
	turret = Node3D.new()
	turret.name = "Turret"
	add_child(turret)
	_build_mesh()

	var sy := MultiplayerSynchronizer.new()
	sy.name = "Sync"
	var rc := SceneReplicationConfig.new()
	for p in [".:position", ".:rotation", "Turret:rotation", ".:health", ".:ammo", ".:cur_speed"]:
		rc.add_property(NodePath(p))
		rc.property_set_replication_mode(NodePath(p), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sy.replication_config = rc
	add_child(sy)

	_rig = Node3D.new()
	_rig.top_level = true
	add_child(_rig)
	_arm = SpringArm3D.new()
	_arm.spring_length = float(st.cam)
	_arm.add_excluded_object(get_rid())
	_rig.add_child(_arm)
	_cam = Camera3D.new()
	_cam.far = 1500.0
	_arm.add_child(_cam)


# ---------- الشكل (أشكال بدائية؛ استبدلها بنماذج glb لاحقًا) ----------

func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.rotation = rot
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	m.material_override = mat
	parent.add_child(m)
	return m


func _wheel(pos: Vector3, r := 0.45) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.35
	m.mesh = c
	m.position = pos
	m.rotation.z = PI / 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.08)
	m.material_override = mat
	add_child(m)


func _build_mesh() -> void:
	var hull := Color(0.30, 0.34, 0.24).lerp(Cfg.TEAMS[team].color, 0.35)
	var dark := Color(0.1, 0.1, 0.1)
	match kind:
		"jeep":
			_box(self, Vector3(2.0, 0.8, 4.2), Vector3(0, 0.9, 0), hull)
			_box(self, Vector3(1.8, 0.7, 1.8), Vector3(0, 1.6, 0.4), hull.darkened(0.1))
			for x in [-1.1, 1.1]:
				for z in [-1.4, 1.4]:
					_wheel(Vector3(x, 0.45, z))
			_box(self, Vector3(0.12, 0.12, 1.2), Vector3(0, 2.1, -0.2), dark)
		"apc":
			_box(self, Vector3(2.8, 1.4, 6.0), Vector3(0, 1.2, 0), hull)
			for x in [-1.4, 1.4]:
				for z in [-2.2, 0.0, 2.2]:
					_wheel(Vector3(x, 0.55, z), 0.55)
			turret.position = Vector3(0, 2.2, -0.5)
			_box(turret, Vector3(1.4, 0.6, 1.8), Vector3.ZERO, hull.darkened(0.1))
			_box(turret, Vector3(0.15, 0.15, 2.0), Vector3(0, 0.1, -1.6), dark)
		"tank":
			for x in [-1.4, 1.4]:
				_box(self, Vector3(0.8, 1.0, 7.0), Vector3(x, 0.55, 0), dark)
			_box(self, Vector3(2.6, 0.9, 6.4), Vector3(0, 1.15, 0), hull)
			turret.position = Vector3(0, 1.9, 0.3)
			_box(turret, Vector3(2.2, 0.8, 3.0), Vector3.ZERO, hull.darkened(0.1))
			_box(turret, Vector3(0.22, 0.22, 4.2), Vector3(0, 0.1, -3.2), dark)
		"mlrs":
			for x in [-1.4, 1.4]:
				_box(self, Vector3(0.8, 1.0, 7.0), Vector3(x, 0.55, 0), dark)
			_box(self, Vector3(2.8, 1.1, 6.2), Vector3(0, 1.1, 0), hull)
			_box(self, Vector3(2.4, 1.2, 1.8), Vector3(0, 2.0, -2.2), hull.darkened(0.1))
			turret.position = Vector3(0, 2.1, 1.2)
			_box(turret, Vector3(2.6, 0.5, 4.0), Vector3.ZERO, hull.darkened(0.15), Vector3(0.5, 0, 0))
			_box(turret, Vector3(2.3, 0.35, 3.6), Vector3(0, 0.25, 0), dark, Vector3(0.5, 0, 0))
		"heli":
			_box(self, Vector3(2.0, 2.0, 6.0), Vector3(0, 1.6, 0), hull)
			_box(self, Vector3(1.6, 1.4, 1.8), Vector3(0, 1.3, -3.6), hull.darkened(0.15))
			_box(self, Vector3(0.6, 0.6, 5.0), Vector3(0, 2.0, 5.2), hull)
			_box(self, Vector3(0.2, 1.6, 1.0), Vector3(0, 2.7, 7.4), hull)
			for x in [-1.1, 1.1]:
				_box(self, Vector3(0.15, 0.15, 4.5), Vector3(x, 0.3, 0), dark)
			rotor = Node3D.new()
			rotor.position = Vector3(0, 2.9, 0)
			add_child(rotor)
			_box(rotor, Vector3(13, 0.08, 0.45), Vector3.ZERO, dark)
			_box(rotor, Vector3(0.45, 0.08, 13), Vector3.ZERO, dark)
		"jet":
			_box(self, Vector3(1.3, 1.1, 11.0), Vector3(0, 1.0, 0), hull)
			_box(self, Vector3(0.8, 0.8, 3.0), Vector3(0, 1.0, -6.8), hull.lightened(0.15))
			_box(self, Vector3(9.0, 0.15, 3.5), Vector3(0, 0.9, 1.5), hull.darkened(0.1))
			_box(self, Vector3(4.0, 0.12, 1.8), Vector3(0, 1.0, 4.8), hull.darkened(0.1))
			_box(self, Vector3(0.15, 1.6, 2.0), Vector3(0, 2.0, 4.5), hull)
			_box(self, Vector3(0.7, 0.5, 2.0), Vector3(0, 1.7, -1.5), Color(0.4, 0.6, 0.8))


# ---------- السائق ----------

func _is_me() -> bool:
	return driver != 0 and driver == multiplayer.get_unique_id()


@rpc("authority", "call_local", "reliable")
func set_driver(p: int) -> void:
	driver = p


func _unhandled_input(e: InputEvent) -> void:
	if not _is_me() or kind == "jet":
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_cam_yaw -= e.relative.x * 0.0025
		_cam_pitch = clampf(_cam_pitch - e.relative.y * 0.0025, -1.3, 0.6)


func _process(delta: float) -> void:
	if rotor:
		rotor.rotate_y(delta * (28.0 if driver != 0 else 2.0))
	var me := _is_me()
	_cam.current = me
	if not me:
		return
	if kind == "jet":
		_rig.global_transform = Transform3D(global_transform.basis, global_position + global_transform.basis.y * 1.5)
		_arm.rotation.x = -0.1
	else:
		_rig.global_position = global_position + Vector3.UP * (float(st.size.y) * 0.8)
		_rig.rotation.y = _cam_yaw
		_arm.rotation.x = _cam_pitch


func _physics_process(delta: float) -> void:
	if _is_me():
		_send_input()
	if multiplayer.is_server():
		_simulate(delta)


func _send_input() -> void:
	var cap := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var thr := Input.get_axis("move_back", "move_fwd") if cap else 0.0
	var strv := Input.get_axis("move_left", "move_right") if cap else 0.0
	var lift := 0.0
	var pitch := 0.0
	var roll := 0.0
	if cap and kind == "heli":
		lift = Input.get_axis("crouch", "jump")
	if cap and kind == "jet":
		lift = Input.get_axis("crouch", "sprint")
		pitch = Input.get_axis("move_fwd", "move_back")
		roll = strv
	var fire := cap and Input.is_action_pressed("fire")
	_input_rpc.rpc_id(1, thr, strv, lift, pitch, roll, _cam_yaw, fire, _cam.global_position, -_cam.global_transform.basis.z)


@rpc("any_peer", "call_local", "unreliable_ordered")
func _input_rpc(thr: float, strv: float, lift: float, pitch: float, roll: float, aim_yaw: float, fire: bool, o: Vector3, d: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var s := multiplayer.get_remote_sender_id()
	if s == 0:
		s = 1
	if s != driver:
		return
	in_thr = clampf(thr, -1.0, 1.0)
	in_str = clampf(strv, -1.0, 1.0)
	in_lift = clampf(lift, -1.0, 1.0)
	in_pitch = clampf(pitch, -1.0, 1.0)
	in_roll = clampf(roll, -1.0, 1.0)
	in_aim_yaw = aim_yaw
	in_fire = fire
	in_orig = o
	in_dir = d


# ---------- المحاكاة (المضيف فقط) ----------

func _simulate(delta: float) -> void:
	if _dead:
		return
	if driver == 0:
		in_thr = 0.0
		in_str = 0.0
		in_lift = 0.0
		in_pitch = 0.0
		in_roll = 0.0
		in_fire = false
	match str(st.mode):
		"wheel", "track": _sim_ground(delta)
		"heli": _sim_heli(delta)
		"jet": _sim_jet(delta)
	if turret and (kind == "tank" or kind == "apc") and driver != 0:
		var target := wrapf(in_aim_yaw - rotation.y, -PI, PI)
		turret.rotation.y = lerp_angle(turret.rotation.y, target, minf(1.0, delta * 3.0))
	_fire_logic(delta)


func _sim_ground(delta: float) -> void:
	var tracked: bool = st.mode == "track"
	var target: float = in_thr * float(st.speed) * (1.0 if in_thr >= 0.0 else 0.4)
	cur_speed = move_toward(cur_speed, target, float(st.accel) * delta)
	var fac := 1.0 if tracked else clampf(absf(cur_speed) / 5.0, 0.0, 1.0)
	var sgn := 1.0 if (tracked or cur_speed >= -0.01) else -1.0
	rotate_y(-in_str * float(st.turn) * delta * fac * sgn)
	var fwd := -global_transform.basis.z
	velocity.x = fwd.x * cur_speed
	velocity.z = fwd.z * cur_speed
	velocity.y = -2.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()


func _sim_heli(delta: float) -> void:
	rotate_y(-in_str * float(st.turn) * delta)
	var fwd := -global_transform.basis.z
	var tv := fwd * in_thr * float(st.speed) + Vector3.UP * in_lift * float(st.climb)
	if driver == 0:
		tv = Vector3(0, -6, 0)
	velocity = velocity.lerp(tv, clampf(delta * 1.6, 0.0, 1.0))
	cur_speed = Vector2(velocity.x, velocity.z).length()
	move_and_slide()


func _sim_jet(delta: float) -> void:
	_throttle = clampf(_throttle + in_lift * 0.6 * delta, 0.0, 1.0)
	cur_speed = lerpf(float(st.min), float(st.speed), _throttle)
	if driver == 0:
		rotate_object_local(Vector3.RIGHT, -0.3 * delta)
	rotate_object_local(Vector3.RIGHT, in_pitch * 1.0 * delta)
	rotate_object_local(Vector3.FORWARD, in_roll * 1.9 * delta)
	rotate_object_local(Vector3.UP, -in_roll * 0.3 * delta)
	basis = basis.orthonormalized()
	var c := move_and_collide(-global_transform.basis.z * cur_speed * delta)
	if c or global_position.length() > 900.0:
		take_damage(99999.0, 0, true)


func _cast(o: Vector3, d: Vector3, length: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(o, o + d * length)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


func _fire_logic(delta: float) -> void:
	_next_fire -= delta
	if ammo == 0:
		_reload -= delta
		if _reload <= 0.0:
			ammo = int(st.ammo)
	if not in_fire or driver == 0 or _next_fire > 0.0 or ammo == 0:
		return
	_next_fire = float(st.rate)
	if ammo > 0:
		ammo -= 1
		if ammo == 0:
			_reload = 8.0
	var size: Vector3 = st.size
	var o := global_position + Vector3.UP * size.y * 0.8 - global_transform.basis.z * size.z * 0.35
	var d: Vector3
	if kind == "jet":
		d = -global_transform.basis.z
	else:
		var co := in_orig
		if co.distance_to(global_position) > 40.0 or in_dir.length() < 0.5:
			co = o
		var cd := in_dir.normalized() if in_dir.length() > 0.5 else -global_transform.basis.z
		var h0 := _cast(co, cd, 1200.0)
		var tgt: Vector3 = co + cd * 1200.0 if h0.is_empty() else h0.position
		d = (tgt - o).normalized()
	var hit := _cast(o, d, 1200.0)
	var end: Vector3 = o + d * 1200.0 if hit.is_empty() else hit.position
	var m = get_tree().current_scene
	var mult := float(Net.settings.damage)
	match str(st.weapon):
		"gun":
			if not hit.is_empty():
				var c = hit.collider
				if c.has_method("take_damage") and c.get("team") != team:
					c.take_damage(float(st.dmg) * mult, driver, false)
			m.tracer.rpc(o, end)
		_:
			m.explode(end, float(st.radius), float(st.dmg) * mult, driver, team)
			m.tracer.rpc(o, end)


func take_damage(amount: float, attacker: int, explosive := false) -> void:
	if not multiplayer.is_server() or _dead:
		return
	health -= amount * (1.0 if explosive else float(st.armor))
	if health <= 0.0:
		_dead = true
		get_tree().current_scene.vehicle_destroyed(self, attacker)
		queue_free()


func hud_text() -> String:
	var s := "%s\nالسرعة: %d كم/س\nالمركبة: %d%%" % [Cfg.KINDS[kind].name, int(cur_speed * 3.6), int(100.0 * health / float(st.hp))]
	if kind == "heli" or kind == "jet":
		s += "\nالارتفاع: %d م" % int(global_position.y)
	if ammo >= 0:
		s += "\nالذخيرة: %d" % ammo
	return s
