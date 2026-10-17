extends CharacterBody3D
## مركبة واحدة بسكربت واحد: جيب / ناقلة / دبابة / راجمة M270 / مروحية / طائرة.
## المحاكاة والأسلحة كلها على المضيف. السائق يرسل مدخلاته فقط، والموقع يُزامَن للجميع.

const VM := preload("res://scripts/models/vehicle_models.gd")
const M := preload("res://scripts/models/mats.gd")
const P := preload("res://scripts/models/parts.gd")
const Fx := preload("res://scripts/match/fx.gd")

var kind := "jeep"
var team := 0
var driver := 0
var health := 100.0
var ammo := -1
var alt_ammo := -1
var cur_speed := 0.0
var st: Dictionary

var in_thr := 0.0
var in_str := 0.0
var in_lift := 0.0
var in_pitch := 0.0
var in_roll := 0.0
var in_aim_yaw := 0.0
var in_fire := false
var in_alt := false
var in_orig := Vector3.ZERO
var in_dir := Vector3.FORWARD

var _throttle := 0.6
var _next_fire := 0.0
var _next_alt := 0.0
var _reload := 0.0
var _dead := false
var released := false
var _crashing := false
var _crash_v := Vector3.ZERO
var _wreck := false
var _trk: AudioStreamPlayer3D
var _last_yaw := 0.0
var _rig: Node3D
var _arm: SpringArm3D
var _cam: Camera3D
var _cam_yaw := 0.0
var _cam_pitch := -0.25
var _eng: AudioStreamPlayer3D
var turret: Node3D
var _m := {}


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
	alt_ammo = int(st.get("alt_ammo", -1))
	_cam_yaw = rotation.y
	_last_yaw = rotation.y


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
	_m = VM.build(self, turret, kind, Cfg.TEAMS[team].color)

	var sy := MultiplayerSynchronizer.new()
	sy.name = "Sync"
	var rc := SceneReplicationConfig.new()
	var paths := [".:position", ".:rotation", "Turret:rotation", ".:health", ".:ammo", ".:alt_ammo", ".:cur_speed"]
	if _m.gun:
		paths.append("Turret/Gun:rotation")
	for p in paths:
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

	_eng = AudioStreamPlayer3D.new()
	var sname := "engine_diesel"
	if st.mode == "heli":
		sname = "engine_heli"
	elif st.mode == "jet":
		sname = "engine_jet"
	_eng.stream = Sfx.stream(sname)
	_eng.unit_size = 14.0
	_eng.max_distance = 170.0
	_eng.volume_db = -3.0
	add_child(_eng)
	if st.mode == "track":
		_trk = AudioStreamPlayer3D.new()
		_trk.stream = Sfx.stream("tracks")
		_trk.unit_size = 12.0
		_trk.max_distance = 120.0
		_trk.volume_db = -5.0
		add_child(_trk)


# ---------- السائق ----------

func _is_me() -> bool:
	return driver != 0 and driver == multiplayer.get_unique_id()


func cam_node() -> Camera3D:
	return _cam


@rpc("authority", "call_local", "reliable")
func set_driver(p: int) -> void:
	if p != driver:
		Sfx.play3d("door", global_position + Vector3.UP, -4.0, 1.0, 60.0)
	driver = p


func _unhandled_input(e: InputEvent) -> void:
	if not _is_me() or kind == "jet":
		return
	if e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION and Cfg.input_live():
		_cam_yaw -= e.relative.x * 0.0025 * float(Cfg.opts.sens)
		_cam_pitch = clampf(_cam_pitch - e.relative.y * 0.0025 * float(Cfg.opts.sens), -1.3, 0.6)


func _process(delta: float) -> void:
	# ---- مؤثرات بصرية على كل الأجهزة ----
	if st.mode != "heli":
		for w in _m.wheels:
			(w as Node3D).rotate_x(-cur_speed * delta / 0.4)
	if _m.rotor and not _wreck:
		(_m.rotor as Node3D).rotate_y(delta * (32.0 if driver != 0 else 4.0))
	if _m.tail and not _wreck:
		(_m.tail as Node3D).rotate_x(delta * (40.0 if driver != 0 else 5.0))
	if _m.burner:
		var ratio := clampf((cur_speed - float(st.min)) / (float(st.speed) - float(st.min)), 0.0, 1.0)
		(_m.burner as Node3D).scale.y = 0.25 + ratio
	if st.mode == "heli" and _m.body:
		var b: Node3D = _m.body
		var yr := wrapf(rotation.y - _last_yaw, -PI, PI) / maxf(delta, 0.001)
		b.rotation.x = lerpf(b.rotation.x, -clampf(cur_speed / float(st.speed), 0.0, 1.0) * 0.2, minf(delta * 3.0, 1.0))
		b.rotation.z = lerpf(b.rotation.z, clampf(yr * 0.25, -0.35, 0.35), minf(delta * 3.0, 1.0))
	_last_yaw = rotation.y
	var want := (driver != 0 or absf(cur_speed) > 1.0) and not _wreck
	if _trk and _trk.stream:
		var tw_ := absf(cur_speed) > 1.2 and not _wreck
		if tw_ and not _trk.playing:
			_trk.play()
		elif not tw_ and _trk.playing:
			_trk.stop()
		_trk.pitch_scale = 0.8 + clampf(absf(cur_speed) / maxf(float(st.speed), 1.0), 0.0, 1.0) * 0.6
	if _eng.stream:
		if want and not _eng.playing:
			_eng.play()
		elif not want and _eng.playing:
			_eng.stop()
		var ratio2 := clampf(absf(cur_speed) / maxf(float(st.speed), 1.0), 0.0, 1.0)
		_eng.pitch_scale = (1.0 + ratio2 * 0.3) if st.mode == "heli" else (0.7 + ratio2 * 0.8)

	# ---- كاميرا السائق ----
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
	var live := Cfg.input_live()
	var thr := Input.get_axis("move_back", "move_fwd") if live else 0.0
	var strv := Input.get_axis("move_left", "move_right") if live else 0.0
	var lift := 0.0
	var pitch := 0.0
	var roll := 0.0
	if live and kind == "heli":
		lift = Input.get_axis("crouch", "jump")
	if live and kind == "jet":
		lift = Input.get_axis("crouch", "sprint")
		pitch = Input.get_axis("move_fwd", "move_back")
		roll = strv
	var fire := live and Input.is_action_pressed("fire")
	var alt := live and Input.is_action_pressed("alt")
	_input_rpc.rpc_id(1, thr, strv, lift, pitch, roll, _cam_yaw, fire, alt, _cam.global_position, -_cam.global_transform.basis.z)


@rpc("any_peer", "call_local", "unreliable_ordered")
func _input_rpc(thr: float, strv: float, lift: float, pitch: float, roll: float, aim_yaw: float, fire: bool, alt: bool, o: Vector3, d: Vector3) -> void:
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
	in_alt = alt
	in_orig = o
	in_dir = d


# ---------- المحاكاة (المضيف فقط) ----------

func _simulate(delta: float) -> void:
	if _crashing:
		_sim_crash(delta)
		return
	if _dead:
		return
	if driver == 0:
		in_thr = 0.0
		in_str = 0.0
		in_lift = 0.0
		in_pitch = 0.0
		in_roll = 0.0
		in_fire = false
		in_alt = false
	match str(st.mode):
		"wheel", "track": _sim_ground(delta)
		"heli": _sim_heli(delta)
		"jet": _sim_jet(delta)
	if driver != 0 and (kind == "tank" or kind == "apc"):
		var target := wrapf(in_aim_yaw - rotation.y, -PI, PI)
		turret.rotation.y = lerp_angle(turret.rotation.y, target, minf(1.0, delta * 3.0))
		if _m.gun and in_dir.length() > 0.5:
			var g: Node3D = _m.gun
			var el := clampf(asin(clampf(in_dir.normalized().y, -1.0, 1.0)), -0.12, 0.35)
			g.rotation.x = lerpf(g.rotation.x, el, minf(1.0, delta * 3.0))
	if driver != 0 and kind == "jeep":
		turret.rotation.y = lerp_angle(turret.rotation.y, wrapf(in_aim_yaw - rotation.y, -PI, PI), minf(1.0, delta * 4.0))
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


# ---------- الأسلحة ----------

func _cast(o: Vector3, d: Vector3, length: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(o, o + d * length)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


func _muzzle() -> Vector3:
	var tip = _m.tip
	if tip:
		return (tip as Node3D).global_position
	return global_position + Vector3.UP * float(st.size.y) * 0.8 - global_transform.basis.z * float(st.size.z) * 0.35


## يرجع [المصدر، الاتجاه، نقطة الإصابة (أو الأفق)، نتيجة الشعاع]
func _aim() -> Array:
	var o := _muzzle()
	var d: Vector3
	if kind == "jet":
		d = -global_transform.basis.z
	else:
		var co := in_orig
		var cd := in_dir
		if co.distance_to(global_position) > 40.0 or cd.length() < 0.5:
			co = o
			cd = -global_transform.basis.z
		cd = cd.normalized()
		var h0 := _cast(co, cd, 1200.0)
		var tgt: Vector3 = co + cd * 1200.0 if h0.is_empty() else h0.position
		d = (tgt - o).normalized()
	var hit := _cast(o, d, 1200.0)
	var end: Vector3 = o + d * 1200.0 if hit.is_empty() else hit.position
	return [o, d, end, hit]


func _fire_logic(delta: float) -> void:
	_next_fire -= delta
	_next_alt -= delta
	if ammo == 0:
		_reload -= delta
		if _reload <= 0.0:
			ammo = int(st.ammo)
	if driver == 0:
		return
	if in_fire and _next_fire <= 0.0 and ammo != 0:
		_primary()
	if in_alt and st.has("alt") and _next_alt <= 0.0 and alt_ammo != 0:
		_secondary()


func _primary() -> void:
	_next_fire = float(st.rate)
	var a := _aim()
	var o: Vector3 = a[0]
	var d: Vector3 = a[1]
	var end: Vector3 = a[2]
	var hit: Dictionary = a[3]
	var m = get_tree().current_scene
	var mult := float(Net.settings.damage)
	match str(st.weapon):
		"gun":
			if not hit.is_empty():
				var c = hit.collider
				if c.has_method("take_damage") and c.get("team") != team:
					c.take_damage(float(st.dmg) * mult, driver, false)
			m.tracer.rpc(o, end, str(st.snd))
		"cannon":
			m.explode(end, float(st.radius), float(st.dmg) * mult, driver, team)
			m.tracer.rpc(o, end, "cannon")
		"rocket":
			var n := mini(2, ammo)
			ammo -= n
			if ammo == 0:
				_reload = 10.0
			var tgt := end
			if o.distance_to(tgt) < 40.0:
				tgt = o + Vector3(d.x, 0.0, d.z).normalized() * 60.0
			for i in n:
				_launch_rocket(o + Vector3(0, 0.0, 0.0), tgt + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), 150.0, 0.38, float(st.radius), float(st.dmg))


func _secondary() -> void:
	_next_alt = float(st.alt_rate)
	if alt_ammo > 0:
		alt_ammo -= 1
	var a := _aim()
	var o: Vector3 = a[0]
	var end: Vector3 = a[2]
	var hit: Dictionary = a[3]
	var m = get_tree().current_scene
	match str(st.alt):
		"mg":
			if not hit.is_empty():
				var c = hit.collider
				if c.has_method("take_damage") and c.get("team") != team:
					c.take_damage(float(st.alt_dmg) * float(Net.settings.damage), driver, false)
			m.tracer.rpc(o + Vector3.UP * 0.6, end, "mg")
		"rocket":
			_launch_rocket(o + Vector3.DOWN * 0.4, end, 220.0, 0.0, float(st.alt_radius), float(st.alt_dmg))


func _launch_rocket(o: Vector3, tgt: Vector3, speed: float, arc: float, radius: float, dmg: float) -> void:
	var m = get_tree().current_scene
	var dist := o.distance_to(tgt)
	var t := maxf(dist / speed, 0.25)
	m.rocket_fx.rpc(o, tgt, t, dist * arc)
	var mult := float(Net.settings.damage)
	m.get_tree().create_timer(t).timeout.connect(m.explode.bind(tgt, radius, dmg * mult, driver, team))


@rpc("any_peer", "call_local", "reliable")
func mlrs_launch(x: float, z: float, delay: float, count: int) -> void:
	if not multiplayer.is_server() or kind != "mlrs" or _dead:
		return
	var s := multiplayer.get_remote_sender_id()
	if s == 0:
		s = 1
	if s != driver:
		return
	var cx := clampf(x, -300.0, 300.0)
	var cz := clampf(z, -300.0, 300.0)
	var gy := 0.0
	var h := _cast(Vector3(cx, 300.0, cz), Vector3.DOWN, 400.0)
	if not h.is_empty():
		gy = h.position.y
	var tgt := Vector3(cx, gy, cz)
	var dl := clampf(delay, 0.0, 60.0)
	for i in clampi(count, 1, 12):
		get_tree().create_timer(dl + i * 0.3).timeout.connect(_salvo_one.bind(tgt))


func _salvo_one(tgt: Vector3) -> void:
	if _dead or ammo == 0 or driver == 0:
		return
	ammo -= 1
	if ammo == 0:
		_reload = 10.0
	_launch_rocket(_muzzle(), tgt + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7)), 150.0, 0.38, float(st.radius), float(st.dmg))


func take_damage(amount: float, attacker: int, explosive := false) -> void:
	if not multiplayer.is_server() or _dead:
		return
	health -= amount * (1.0 if explosive else float(st.armor))
	if health <= 0.0:
		_destroy(attacker)


# ---------- التدمير والسقوط ----------

func _destroy(attacker: int) -> void:
	_dead = true
	var m = get_tree().current_scene
	m.vehicle_destroyed(self, attacker)
	m.release_slot(self)
	remove_from_group("vehicle")
	remove_from_group("damageable")
	var air: bool = (st.mode == "heli" or st.mode == "jet") and global_position.y > 5.0
	_destroyed_fx.rpc(air)
	if air:
		_crashing = true
		_crash_v = velocity if st.mode == "heli" else -global_transform.basis.z * cur_speed
	else:
		get_tree().create_timer(25.0).timeout.connect(queue_free)


func _sim_crash(delta: float) -> void:
	_crash_v.y -= 24.0 * delta
	rotate_object_local(Vector3.FORWARD, 2.4 * delta)
	rotate_object_local(Vector3.RIGHT, -0.5 * delta)
	if st.mode == "heli":
		rotate_y(3.5 * delta)
	basis = basis.orthonormalized()
	var c := move_and_collide(_crash_v * delta)
	if c:
		_crashing = false
		get_tree().current_scene.explode(global_position, 14.0, 220.0, 0, -1)
		_landed_fx.rpc()
		get_tree().create_timer(25.0).timeout.connect(queue_free)


@rpc("authority", "call_local", "reliable")
func _landed_fx() -> void:
	Fx.dust(get_tree(), global_position, 9.0)
	var scorch := P.cyl(self, 5.0, 0.03, Vector3(0, 0.06, 0), M.solid(Color(0.02, 0.02, 0.02), 1.0))
	scorch.top_level = true
	scorch.global_position = global_position + Vector3(0, 0.06, 0)
	scorch.global_rotation = Vector3.ZERO


@rpc("authority", "call_local", "reliable")
func _destroyed_fx(air: bool) -> void:
	_wreck = true
	driver = 0
	if _eng:
		_eng.stop()
	if _trk:
		_trk.stop()
	_char(self, M.solid(Color(0.05, 0.045, 0.04), 0.95))
	_add_fire()
	if air:
		return
	if kind == "tank" or kind == "apc":
		var blown := Node3D.new()
		add_child(blown)
		blown.position = turret.position
		blown.rotation.y = turret.rotation.y
		for c in turret.get_children():
			turret.remove_child(c)
			blown.add_child(c)
		var p0 := blown.position
		var tw := blown.create_tween()
		tw.tween_property(blown, "position", p0 + Vector3(randf_range(-2.0, 2.0), 7.0, randf_range(-2.0, 2.0)), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(blown, "rotation:z", randf_range(-1.2, 1.2), 0.9)
		tw.tween_property(blown, "position", p0 + Vector3(randf_range(-3.0, 3.0), 0.2, randf_range(-3.0, 3.0)), 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	var sc := P.cyl(self, 4.0, 0.03, Vector3(0, 0.06, 0), M.solid(Color(0.02, 0.02, 0.02), 1.0))
	sc.top_level = true
	sc.global_position = global_position + Vector3(0, 0.06, 0)
	sc.global_rotation = Vector3.ZERO


func _char(n: Node, mat: Material) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = mat
		_char(c, mat)


func _add_fire() -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.vertex_color_use_as_albedo = true
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = smat
	var top := Vector3(0, float(st.size.y) * 0.6, 0)
	var smoke := CPUParticles3D.new()
	smoke.amount = 36
	smoke.lifetime = 4.5
	smoke.local_coords = false
	smoke.mesh = sm
	smoke.direction = Vector3.UP
	smoke.spread = 18.0
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 4.0
	smoke.gravity = Vector3(0, 1.2, 0)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.8
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(1.0, 3.2))
	smoke.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.1, 0.1, 0.1, 0.9), Color(0.14, 0.14, 0.14, 0.6), Color(0.2, 0.2, 0.2, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	smoke.color_ramp = ramp
	add_child(smoke)
	smoke.position = top
	var fm := SphereMesh.new()
	fm.radius = 0.3
	fm.height = 0.6
	fm.radial_segments = 8
	fm.rings = 4
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.vertex_color_use_as_albedo = true
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.material = fmat
	var flame := CPUParticles3D.new()
	flame.amount = 24
	flame.lifetime = 0.7
	flame.local_coords = false
	flame.mesh = fm
	flame.direction = Vector3.UP
	flame.spread = 25.0
	flame.initial_velocity_min = 1.0
	flame.initial_velocity_max = 3.0
	flame.gravity = Vector3(0, 2.0, 0)
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.7
	var fr := Gradient.new()
	fr.colors = PackedColorArray([Color(1.0, 0.9, 0.4, 0.95), Color(1.0, 0.45, 0.1, 0.8), Color(0.3, 0.1, 0.05, 0.0)])
	fr.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	flame.color_ramp = fr
	add_child(flame)
	flame.position = top - Vector3(0, 0.3, 0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 3.0
	l.omni_range = 14.0
	add_child(l)
	l.position = top
	var lt := l.create_tween().set_loops()
	lt.tween_property(l, "light_energy", 1.8, 0.11)
	lt.tween_property(l, "light_energy", 4.0, 0.14)
	var fp := AudioStreamPlayer3D.new()
	fp.stream = Sfx.stream("fire")
	fp.unit_size = 10.0
	fp.max_distance = 90.0
	fp.volume_db = -2.0
	add_child(fp)
	if fp.stream:
		fp.play()


func hud_data() -> Dictionary:
	return {
		"name": Cfg.KINDS[kind].name, "kind": kind, "kmh": int(cur_speed * 3.6),
		"hp": clampf(health / float(st.hp), 0.0, 1.0), "alt": global_position.y,
		"ammo": ammo, "alt_ammo": alt_ammo if st.has("alt") else -2,
		"air": st.mode == "heli" or st.mode == "jet",
	}
