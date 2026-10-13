extends CharacterBody3D
## الجندي: منظور ثالث. الحركة بسلطة اللاعب المالك، أما الإصابات والقتل فالمضيف هو المرجع.

const Fx := preload("res://scripts/match/fx.gd")
const JUMP := 6.0
const GRAV := 20.0

var peer := 0
var team := 0
var cls := "assault"
var weapon := "rifle"
var health := 100.0
var alive := true
var vehicle = null            # المركبة التي يقودها (أو null)

var _last_xf := Transform3D.IDENTITY
var _pitch := 0.0
var _cd := 0.0
var _srv_next := 0.0
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
	health = Cfg.CLASSES[cls].hp
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

	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	body.mesh = cm
	body.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Cfg.TEAMS[team].color.darkened(0.25)
	body.material_override = mat
	add_child(body)
	var gun := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.1, 0.12, 0.8)
	gun.mesh = gm
	gun.position = Vector3(0.3, 1.2, -0.55)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.1, 0.1, 0.1)
	gun.material_override = gmat
	add_child(gun)

	var sy := MultiplayerSynchronizer.new()
	sy.name = "Sync"
	var rc := SceneReplicationConfig.new()
	for p in [".:position", ".:rotation", ".:visible"]:
		rc.add_property(NodePath(p))
		rc.property_set_replication_mode(NodePath(p), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sy.replication_config = rc
	add_child(sy)
	sy.set_multiplayer_authority(peer)

	if is_multiplayer_authority():
		_arm = SpringArm3D.new()
		_arm.spring_length = 3.2
		_arm.position = Vector3(0.6, 1.6, 0.0)
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


func _unhandled_input(e: InputEvent) -> void:
	if not is_multiplayer_authority() or not alive:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and vehicle == null:
		rotate_y(-e.relative.x * 0.0025)
		_pitch = clampf(_pitch - e.relative.y * 0.0025, -1.2, 1.0)
		_arm.rotation.x = _pitch
	if e.is_action_pressed("interact"):
		if is_instance_valid(vehicle):
			_req_exit.rpc_id(1)
		else:
			_try_enter()


func _try_enter() -> void:
	var best = null
	var bd := 7.0
	for v in get_tree().get_nodes_in_group("vehicle"):
		var d: float = v.global_position.distance_to(global_position)
		if v.team == team and v.driver == 0 and d < bd:
			bd = d
			best = v
	if best:
		_req_enter.rpc_id(1, best.name)


func _physics_process(delta: float) -> void:
	var had := is_instance_valid(vehicle)
	var v = _find_vehicle()
	if had and v == null and is_multiplayer_authority():
		# خرج من المركبة: ضعه بجانبها
		global_position = _last_xf.origin + _last_xf.basis.x * 3.0 + Vector3.UP * 2.0
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

	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var sp: float = Cfg.CLASSES[cls].speed * (1.5 if Input.is_action_pressed("sprint") else 1.0)
	var inp := Input.get_vector("move_left", "move_right", "move_fwd", "move_back") if captured else Vector2.ZERO
	var dir := (global_transform.basis * Vector3(inp.x, 0, inp.y)).normalized()
	velocity.x = dir.x * sp
	velocity.z = dir.z * sp
	if is_on_floor():
		velocity.y = JUMP if (captured and Input.is_action_just_pressed("jump")) else 0.0
	else:
		velocity.y -= GRAV * delta
	move_and_slide()

	_cd -= delta
	if captured and Input.is_action_pressed("fire") and _cd <= 0.0:
		_cd = Cfg.WEAPONS[weapon].rate
		_req_fire.rpc_id(1, _cam.global_position, -_cam.global_transform.basis.z)


# ---------- RPC (تُنفَّذ على المضيف) ----------

@rpc("any_peer", "call_local", "reliable")
func _req_fire(o: Vector3, d: Vector3) -> void:
	if not multiplayer.is_server() or _sender() != peer or not alive or is_instance_valid(vehicle):
		return
	var w = Cfg.WEAPONS[weapon]
	var now := Time.get_ticks_msec() / 1000.0
	if now < _srv_next:
		return
	_srv_next = now + float(w.rate) * 0.8
	if o.distance_to(global_position) > 8.0:
		o = global_position + Vector3.UP * 1.6
	d = d.normalized()
	var q := PhysicsRayQueryParameters3D.create(o, o + d * float(w.range))
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = o + d * float(w.range)
	if not hit.is_empty():
		end = hit.position
		var c = hit.collider
		if c.has_method("take_damage") and c.get("team") != team:
			c.take_damage(float(w.dmg) * float(Net.settings.damage), peer, false)
	var m = get_tree().current_scene
	m.tracer.rpc(global_position + Vector3(0, 1.3, 0) - global_transform.basis.z * 0.8, end)


@rpc("any_peer", "call_local", "reliable")
func _req_enter(vname: String) -> void:
	if not multiplayer.is_server() or _sender() != peer or not alive or is_instance_valid(vehicle):
		return
	var v = get_tree().current_scene.get_node_or_null("Entities/" + vname)
	if v and v.is_in_group("vehicle") and v.driver == 0 and v.team == team and v.global_position.distance_to(global_position) < 9.0:
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
