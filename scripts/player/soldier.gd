extends CharacterBody3D
## الجندي: منظور ثالث. الحركة بسلطة اللاعب، أما الإصابات والذخيرة والقتل فالمضيف هو المرجع.

const SM := preload("res://scripts/models/soldier_model.gd")
const JUMP := 6.0
const GRAV := 20.0

var peer := 0
var team := 0
var cls := "assault"
var weapon := "rifle"
var health := 100.0
var max_health := 100.0
var alive := true
var vehicle = null
var aim_pitch := 0.0
var ammo := 30
var mag := 30
var reloading := false

var _model := {}
var _last_xf := Transform3D.IDENTITY
var _pitch := 0.0
var _cd := 0.0
var _srv_next := 0.0
var _s_ammo := 30
var _s_reload_until := 0.0
var _walk_t := 0.0
var _speed_vis := 0.0
var _last_pos := Vector3.ZERO
var _arm: SpringArm3D
var _cam: Camera3D
var _col: CollisionShape3D


func setup(d: Dictionary) -> void:
	name = d.name
	peer = d.peer
	team = d.team
	cls = d.cls
	weapon = d.weapon
	position = d.pos
	max_health = Cfg.CLASSES[cls].hp
	health = max_health
	mag = int(Cfg.WEAPONS[weapon].mag)
	ammo = mag
	_s_ammo = mag
	set_multiplayer_authority(peer)


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("soldier")
	_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	_col.shape = cap
	_col.position.y = 0.9
	add_child(_col)
	_model = SM.build(self, Cfg.TEAMS[team].color, weapon)
	_last_pos = global_position

	var sy := MultiplayerSynchronizer.new()
	sy.name = "Sync"
	var rc := SceneReplicationConfig.new()
	for p in [".:position", ".:rotation", ".:visible", ".:aim_pitch"]:
		rc.add_property(NodePath(p))
		rc.property_set_replication_mode(NodePath(p), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sy.replication_config = rc
	add_child(sy)
	sy.set_multiplayer_authority(peer)

	if is_multiplayer_authority():
		_arm = SpringArm3D.new()
		_arm.spring_length = 3.4
		_arm.position = Vector3(0.65, 1.75, 0.0)
		_arm.add_excluded_object(get_rid())
		add_child(_arm)
		_cam = Camera3D.new()
		_cam.far = 1500.0
		_arm.add_child(_cam)
		var m = get_tree().current_scene
		m.local_soldier = self
		m.on_local_spawn()


func _exit_tree() -> void:
	var m = get_tree().current_scene
	if m and "local_soldier" in m and m.local_soldier == self:
		m.local_soldier = null


func _sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return 1 if s == 0 else s


func _find_vehicle():
	for v in get_tree().get_nodes_in_group("vehicle"):
		if v.driver == peer:
			return v
	return null


func cam_node() -> Camera3D:
	return _cam


func _unhandled_input(e: InputEvent) -> void:
	if not is_multiplayer_authority() or not alive:
		return
	if e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION and Cfg.input_live() and vehicle == null:
		rotate_y(-e.relative.x * 0.0025)
		_pitch = clampf(_pitch - e.relative.y * 0.0025, -1.2, 1.0)
		_arm.rotation.x = _pitch
		aim_pitch = _pitch
	if e.is_action_pressed("interact"):
		if is_instance_valid(vehicle):
			_req_exit.rpc_id(1)
		else:
			_try_enter()
	if e.is_action_pressed("reload") and vehicle == null and not reloading and ammo < mag:
		_req_reload.rpc_id(1)


func _try_enter() -> void:
	var best = null
	var bd := 8.0
	for v in get_tree().get_nodes_in_group("vehicle"):
		var d: float = v.global_position.distance_to(global_position)
		if v.team == team and v.driver == 0 and d < bd:
			bd = d
			best = v
	if best:
		_req_enter.rpc_id(1, best.name)


func _process(delta: float) -> void:
	if _model.is_empty():
		return
	var sp := 0.0
	if is_multiplayer_authority():
		sp = Vector2(velocity.x, velocity.z).length()
	else:
		sp = Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length() / maxf(delta, 0.001)
	_last_pos = global_position
	_speed_vis = lerpf(_speed_vis, minf(sp, 10.0), minf(delta * 10.0, 1.0))
	_walk_t += _speed_vis * delta * 1.5
	var amt := clampf(_speed_vis / 6.0, 0.0, 1.0)
	var ll: Node3D = _model.leg_l
	var lr: Node3D = _model.leg_r
	var tr: Node3D = _model.torso
	ll.rotation.x = sin(_walk_t) * 0.75 * amt
	lr.rotation.x = -sin(_walk_t) * 0.75 * amt
	tr.position.y = 0.95 + absf(sin(_walk_t)) * 0.035 * amt
	tr.rotation.x = aim_pitch * 0.5


func _physics_process(delta: float) -> void:
	var had := is_instance_valid(vehicle)
	var v = _find_vehicle()
	if had and v == null and is_multiplayer_authority():
		global_position = _last_xf.origin + _last_xf.basis.x * 3.2 + Vector3.UP * 2.0
		velocity = Vector3.ZERO
	vehicle = v
	if v:
		_last_xf = v.global_transform
	_col.set_deferred("disabled", v != null)
	if not is_multiplayer_authority():
		return
	visible = v == null
	_cam.current = v == null and alive
	if not alive:
		return
	if v:
		global_position = v.global_position
		return

	var live := Cfg.input_live()
	var sp: float = Cfg.CLASSES[cls].speed * (1.5 if Input.is_action_pressed("sprint") else 1.0)
	var inp := Input.get_vector("move_left", "move_right", "move_fwd", "move_back") if live else Vector2.ZERO
	var dir := (global_transform.basis * Vector3(inp.x, 0, inp.y)).normalized()
	velocity.x = dir.x * sp
	velocity.z = dir.z * sp
	if is_on_floor():
		velocity.y = JUMP if (live and Input.is_action_just_pressed("jump")) else 0.0
	else:
		velocity.y -= GRAV * delta
	move_and_slide()

	_cd -= delta
	if live and Input.is_action_pressed("fire") and _cd <= 0.0 and ammo > 0 and not reloading:
		_cd = Cfg.WEAPONS[weapon].rate
		_req_fire.rpc_id(1, _cam.global_position, -_cam.global_transform.basis.z)
		_kick()


func _kick() -> void:
	var w: Node3D = _model.weapon
	var tw := create_tween()
	tw.tween_property(w, "position:z", -0.36 + 0.07, 0.03)
	tw.tween_property(w, "position:z", -0.36, 0.08)


func _muzzle_pos() -> Vector3:
	var mz = _model.get("muzzle")
	if mz:
		return mz.global_position
	return global_position + Vector3(0, 1.3, 0) - global_transform.basis.z * 0.8


# ---------- RPC (تُنفَّذ على المضيف) ----------

@rpc("any_peer", "call_local", "reliable")
func _req_fire(o: Vector3, d: Vector3) -> void:
	if not multiplayer.is_server() or _sender() != peer or not alive or is_instance_valid(vehicle):
		return
	var w = Cfg.WEAPONS[weapon]
	var now := Time.get_ticks_msec() / 1000.0
	if now < _srv_next or now < _s_reload_until or _s_ammo <= 0:
		return
	_srv_next = now + float(w.rate) * 0.8
	_s_ammo -= 1
	_set_ammo.rpc_id(peer, _s_ammo, false)
	if _s_ammo == 0:
		_start_reload()
	if o.distance_to(global_position) > 8.0:
		o = global_position + Vector3.UP * 1.6
	var sp := float(w.spread)
	d = (d.normalized() + Vector3(randf_range(-sp, sp), randf_range(-sp, sp), randf_range(-sp, sp))).normalized()
	var q := PhysicsRayQueryParameters3D.create(o, o + d * float(w.range))
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = o + d * float(w.range)
	var m = get_tree().current_scene
	if not hit.is_empty():
		end = hit.position
		var c = hit.collider
		if c.has_method("take_damage") and c.get("team") != team:
			c.take_damage(float(w.dmg) * float(Net.settings.damage), peer, false)
			m._hitmark.rpc_id(peer)
	m.tracer.rpc(_muzzle_pos(), end, str(w.snd))


@rpc("any_peer", "call_local", "reliable")
func _req_reload() -> void:
	if not multiplayer.is_server() or _sender() != peer or not alive or is_instance_valid(vehicle):
		return
	if _s_ammo < mag:
		_start_reload()


func _start_reload() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _s_reload_until:
		return
	var rt := float(Cfg.WEAPONS[weapon].reload)
	_s_reload_until = now + rt
	_set_ammo.rpc_id(peer, _s_ammo, true)
	get_tree().create_timer(rt).timeout.connect(_finish_reload)


func _finish_reload() -> void:
	if not alive or not is_inside_tree():
		return
	_s_ammo = mag
	_set_ammo.rpc_id(peer, _s_ammo, false)


@rpc("any_peer", "call_local", "reliable")
func _set_ammo(a: int, r: bool) -> void:
	var s := multiplayer.get_remote_sender_id()
	if s != 0 and s != 1:
		return
	ammo = a
	reloading = r


@rpc("any_peer", "call_local", "reliable")
func _req_enter(vname: String) -> void:
	if not multiplayer.is_server() or _sender() != peer or not alive or is_instance_valid(vehicle):
		return
	var v = get_tree().current_scene.get_node_or_null("Entities/" + vname)
	if v and v.is_in_group("vehicle") and v.driver == 0 and v.team == team and v.global_position.distance_to(global_position) < 10.0:
		v.set_driver.rpc(peer)


@rpc("any_peer", "call_local", "reliable")
func _req_exit() -> void:
	if not multiplayer.is_server() or _sender() != peer:
		return
	if is_instance_valid(vehicle):
		vehicle.set_driver.rpc(0)


func take_damage(amount: float, attacker: int, _explosive := false) -> void:
	if not multiplayer.is_server() or not alive:
		return
	health -= amount
	_set_health.rpc(health)
	if health <= 0.0:
		alive = false
		get_tree().current_scene.soldier_died(peer, attacker)


@rpc("any_peer", "call_local", "reliable")
func _set_health(h: float) -> void:
	var s := multiplayer.get_remote_sender_id()
	if s != 0 and s != 1:
		return
	health = h
