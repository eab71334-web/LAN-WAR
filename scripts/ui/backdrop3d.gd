extends SubViewportContainer
## خلفية سينمائية ثلاثية الأبعاد: معسكر بمركبات، مروحية تحوم، طائرة تدور، وكاميرا تدور 360° حول المشهد.

const VM := preload("res://scripts/models/vehicle_models.gd")
const M := preload("res://scripts/models/mats.gd")
const P := preload("res://scripts/models/parts.gd")
const MapBuilder := preload("res://scripts/match/map_builder.gd")

var radius := 19.0
var height := 5.2
var speed := 0.1
var _cam: Camera3D
var _t := 0.0
var _focus := Vector3(0, 2.3, 0)
var _spinners: Array = []
var _tails: Array = []
var _heli: Node3D
var _jet: Node3D
var _burner: Node3D


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.size = Vector2i(1280, 720)
	add_child(sv)
	var root := Node3D.new()
	sv.add_child(root)
	MapBuilder.setup_env(root, "menu")
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(700, 700)
	ground.mesh = pm
	ground.material_override = M.ground(Color(0.6, 0.47, 0.3), Color(0.78, 0.62, 0.4), 0.06)
	root.add_child(ground)

	_vehicle(root, "mlrs", Vector3(0, 0, 0), 0.0, 0)
	_vehicle(root, "tank", Vector3(-11, 0, -5), 0.9, 1)
	_vehicle(root, "apc", Vector3(10, 0, -8), -0.7, 2)
	_vehicle(root, "jeep", Vector3(7, 0, 8), 2.4, 3)
	_heli = _vehicle(root, "heli", Vector3(-8, 6, 9), 0.5, 1)
	_jet = _vehicle(root, "jet", Vector3(0, 30, 55), 0.0, 0)

	var crate := M.solid(Color(0.3, 0.33, 0.2), 0.9)
	var drum := M.solid(Color(0.2, 0.3, 0.18), 0.5, 0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 12:
		var a := rng.randf() * TAU
		var r := rng.randf_range(7.0, 16.0)
		var pos := Vector3(cos(a) * r, 0, sin(a) * r)
		if i % 2 == 0:
			P.box(root, Vector3(1.2, 0.9, 1.2), pos + Vector3(0, 0.45, 0), crate, Vector3(0, rng.randf() * 90.0, 0))
		else:
			P.cyl(root, 0.35, 0.9, pos + Vector3(0, 0.45, 0), drum)
	for i in 14:
		var a2 := float(i) / 14.0 * TAU
		P.box(root, Vector3(2.4, 0.8, 0.8), Vector3(cos(a2) * 6.5, 0.4, sin(a2) * 6.5), M.ground(Color(0.55, 0.5, 0.36), Color(0.7, 0.64, 0.48), 0.9), Vector3(0, -rad_to_deg(a2) + 90.0, 0))

	# غبار عائم
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = M.emissive(Color(1.0, 0.85, 0.6, 0.5), 0.6)
	var dust := CPUParticles3D.new()
	dust.amount = 90
	dust.lifetime = 9.0
	dust.local_coords = false
	dust.mesh = sm
	dust.direction = Vector3(1, 0.1, 0.3)
	dust.spread = 50.0
	dust.initial_velocity_min = 0.4
	dust.initial_velocity_max = 1.4
	dust.gravity = Vector3.ZERO
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(30, 5, 30)
	root.add_child(dust)
	dust.position = Vector3(0, 4, 0)

	_cam = Camera3D.new()
	_cam.far = 900.0
	root.add_child(_cam)
	_cam.current = true
	_update_cam(0.0)


func _vehicle(root: Node3D, kind: String, pos: Vector3, yaw: float, team: int) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	root.add_child(holder)
	var turret := Node3D.new()
	holder.add_child(turret)
	var d := VM.build(holder, turret, kind, Cfg.TEAMS[team].color)
	if d.rotor:
		_spinners.append(d.rotor)
	if d.tail:
		_tails.append(d.tail)
	if d.burner:
		_burner = d.burner
	return holder


func _update_cam(delta: float) -> void:
	_t += delta
	var a := _t * speed
	_cam.position = _focus + Vector3(sin(a) * radius, height + sin(_t * 0.35) * 1.4, cos(a) * radius)
	_cam.look_at(_focus + Vector3(0, sin(_t * 0.5) * 0.5, 0))
	_cam.fov = 58.0 + sin(_t * 0.2) * 3.0


func _process(delta: float) -> void:
	if _cam == null:
		return
	_update_cam(delta)
	for r in _spinners:
		(r as Node3D).rotate_y(delta * 30.0)
	for tl in _tails:
		(tl as Node3D).rotate_x(delta * 40.0)
	if _heli:
		_heli.position.y = 6.0 + sin(_t * 1.1) * 0.35
		_heli.rotation.z = sin(_t * 0.8) * 0.04
	if _jet:
		var ja := _t * 0.35
		_jet.position = Vector3(cos(ja) * 60.0, 30.0 + sin(_t * 0.5) * 3.0, sin(ja) * 60.0)
		_jet.rotation = Vector3(0, PI - ja, 0.45)
