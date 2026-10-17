extends RefCounted
## مؤثرات: وميض فوهة، تتبع الرصاص، انفجارات بدخان وشرر، صواريخ بدخان.

const P := preload("res://scripts/models/parts.gd")
const M := preload("res://scripts/models/mats.gd")

const KINDS := {
	"rifle": {"w": 0.025, "c": Color(1.0, 0.85, 0.4), "snd": "rifle", "db": 0.0, "flash": 1.0},
	"support": {"w": 0.03, "c": Color(1.0, 0.8, 0.4), "snd": "support", "db": 1.0, "flash": 1.1},
	"sniper": {"w": 0.04, "c": Color(1.0, 0.92, 0.7), "snd": "sniper", "db": 5.0, "flash": 1.3},
	"lmg": {"w": 0.03, "c": Color(1.0, 0.8, 0.35), "snd": "lmg", "db": 2.0, "flash": 1.2},
	"mg": {"w": 0.045, "c": Color(1.0, 0.75, 0.3), "snd": "mg", "db": 3.0, "flash": 1.6},
	"cannon": {"w": 0.14, "c": Color(1.0, 0.6, 0.2), "snd": "cannon", "db": 9.0, "flash": 4.0},
}


static func _free_later(tree: SceneTree, n: Node, t: float) -> void:
	tree.create_timer(t).timeout.connect(n.queue_free)


static func tracer(tree: SceneTree, a: Vector3, b: Vector3, kind: String) -> void:
	var root := tree.current_scene
	if root == null:
		return
	var k: Dictionary = KINDS.get(kind, KINDS["rifle"])
	Sfx.play3d(k.snd, a, k.db)
	var dir := (b - a)
	muzzle(tree, a, dir, k.flash)
	var dist := a.distance_to(b)
	if dist < 0.5:
		return
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(k.w, k.w, minf(dist, 40.0))
	m.mesh = bm
	m.material_override = M.emissive(k.c, 3.0)
	root.add_child(m)
	var end := a + dir.normalized() * minf(dist, 40.0)
	m.global_position = (a + end) * 0.5
	var up := Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT
	m.look_at(end, up)
	m.create_tween().tween_property(m, "scale:z", 0.1, 0.09)
	_free_later(tree, m, 0.1)
	impact(tree, b)


static func muzzle(tree: SceneTree, pos: Vector3, dir: Vector3, size := 1.0) -> void:
	var root := tree.current_scene
	if root == null or dir.length() < 0.01:
		return
	var f := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.1 * size
	s.height = 0.2 * size
	f.mesh = s
	f.material_override = M.emissive(Color(1.0, 0.85, 0.5), 4.0)
	root.add_child(f)
	f.global_position = pos
	var up := Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT
	f.look_at(pos + dir, up)
	f.scale = Vector3(1.0, 1.0, 2.6)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.45)
	l.light_energy = 2.0 * size
	l.omni_range = 4.0 + 2.0 * size
	root.add_child(l)
	l.global_position = pos
	_free_later(tree, f, 0.05)
	_free_later(tree, l, 0.05)


static func impact(tree: SceneTree, pos: Vector3) -> void:
	var root := tree.current_scene
	if root == null:
		return
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.08
	s.height = 0.16
	m.mesh = s
	m.material_override = M.emissive(Color(1.0, 0.8, 0.4), 3.0)
	root.add_child(m)
	m.global_position = pos
	m.create_tween().tween_property(m, "scale", Vector3.ONE * 3.0, 0.08)
	_free_later(tree, m, 0.1)
	var cam := tree.root.get_viewport().get_camera_3d()
	if cam and randf() < 0.35 and cam.global_position.distance_to(pos) < 70.0:
		Sfx.play3d("impact", pos, -8.0, randf_range(0.9, 1.2), 70.0)


static func _particles(amount: int, life: float, mesh: Mesh) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.mesh = mesh
	p.emitting = true
	return p


static func explosion(tree: SceneTree, pos: Vector3, radius: float) -> void:
	var root := tree.current_scene
	if root == null:
		return
	Sfx.play3d("explosion", pos, 6.0, clampf(1.3 - radius * 0.05, 0.6, 1.2), 400.0)
	# كرة النار
	var fb := MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = 1.0
	fs.height = 2.0
	fb.mesh = fs
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.55, 0.1, 0.9)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fb.material_override = fm
	root.add_child(fb)
	fb.global_position = pos
	fb.scale = Vector3.ONE * 0.5
	var tw := fb.create_tween()
	tw.tween_property(fb, "scale", Vector3.ONE * maxf(radius * 0.55, 1.2), 0.3)
	tw.parallel().tween_property(fm, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(fb.queue_free)
	# وميض ضوء
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 8.0
	l.omni_range = radius * 3.0 + 8.0
	root.add_child(l)
	l.global_position = pos + Vector3.UP
	var lt := l.create_tween()
	lt.tween_property(l, "light_energy", 0.0, 0.45)
	lt.tween_callback(l.queue_free)
	# دخان
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
	var smoke := _particles(int(clampf(radius * 4.0, 14.0, 40.0)), 3.2, sm)
	smoke.direction = Vector3.UP
	smoke.spread = 55.0
	smoke.initial_velocity_min = 1.5
	smoke.initial_velocity_max = 3.0 + radius * 0.5
	smoke.gravity = Vector3(0, 0.8, 0)
	smoke.scale_amount_min = 1.2 + radius * 0.1
	smoke.scale_amount_max = 2.4 + radius * 0.25
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.3, 0.26, 0.22, 0.9), Color(0.14, 0.14, 0.14, 0.6), Color(0.1, 0.1, 0.1, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	smoke.color_ramp = ramp
	root.add_child(smoke)
	smoke.global_position = pos
	_free_later(tree, smoke, 4.0)
	# شرر وشظايا
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.1, 0.1)
	bm.material = M.emissive(Color(1.0, 0.6, 0.2), 3.0)
	var sp := _particles(24, 1.0, bm)
	sp.direction = Vector3.UP
	sp.spread = 75.0
	sp.initial_velocity_min = 8.0
	sp.initial_velocity_max = 20.0 + radius
	sp.gravity = Vector3(0, -15, 0)
	root.add_child(sp)
	sp.global_position = pos
	_free_later(tree, sp, 1.5)


static func rocket(tree: SceneTree, a: Vector3, b: Vector3, t: float, h: float) -> void:
	var root := tree.current_scene
	if root == null:
		return
	var rk := Node3D.new()
	root.add_child(rk)
	rk.global_position = a
	var body := P.pivot(rk, Vector3.ZERO, "Body")
	P.cyl(body, 0.09, 1.2, Vector3.ZERO, M.solid(Color(0.85, 0.85, 0.8), 0.5, 0.3), Vector3(90, 0, 0))
	P.cyl(body, 0.01, 0.45, Vector3(0, 0, -0.8), M.solid(Color(0.7, 0.15, 0.1), 0.5), Vector3(90, 0, 0), 0.09)
	for i in 4:
		P.box(body, Vector3(0.02, 0.28, 0.25), Vector3.ZERO + Vector3(0, 0, 0.5), M.solid(Color(0.3, 0.3, 0.3)), Vector3(0, 0, i * 90.0 + 45.0))
	P.sph(body, 0.12, Vector3(0, 0, 0.75), M.emissive(Color(1.0, 0.6, 0.2), 4.0), Vector3(1, 1, 2.2))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 1.5
	l.omni_range = 9.0
	body.add_child(l)
	l.position = Vector3(0, 0, 1.0)
	# أثر الدخان
	var tm := SphereMesh.new()
	tm.radius = 0.25
	tm.height = 0.5
	tm.radial_segments = 8
	tm.rings = 4
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.vertex_color_use_as_albedo = true
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.material = tmat
	var trail := CPUParticles3D.new()
	trail.amount = 70
	trail.lifetime = 1.8
	trail.local_coords = false
	trail.mesh = tm
	trail.direction = Vector3(0, 0, 1)
	trail.spread = 5.0
	trail.initial_velocity_min = 0.5
	trail.initial_velocity_max = 1.5
	trail.gravity = Vector3(0, 0.3, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(1.0, 2.4))
	trail.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1.0, 0.85, 0.6, 0.9), Color(0.85, 0.85, 0.85, 0.7), Color(0.6, 0.6, 0.6, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	trail.color_ramp = ramp
	rk.add_child(trail)
	trail.position = Vector3(0, 0, 0.8)
	Sfx.play3d("rocket", a, 3.0)
	var step := func(k: float) -> void:
		if not is_instance_valid(rk):
			return
		var p: Vector3 = a.lerp(b, k) + Vector3.UP * (h * 4.0 * k * (1.0 - k))
		var dv: Vector3 = (b - a) + Vector3.UP * (h * 4.0 * (1.0 - 2.0 * k))
		rk.global_position = p
		if dv.length() > 0.01:
			var up := Vector3.UP if absf(dv.normalized().y) < 0.98 else Vector3.RIGHT
			rk.look_at(p + dv, up)
	var tw := rk.create_tween()
	tw.tween_method(step, 0.0, 1.0, maxf(t, 0.1))
	tw.tween_callback(func():
		if is_instance_valid(body):
			body.queue_free()
		trail.emitting = false)
	_free_later(tree, rk, t + 2.5)


static func dust(tree: SceneTree, pos: Vector3, size: float) -> void:
	var root := tree.current_scene
	if root == null:
		return
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = mat
	var p := _particles(int(clampf(size * 3.0, 12.0, 36.0)), 4.5, sm)
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0 + size * 0.4
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 1.5 + size * 0.1
	p.scale_amount_max = 3.5 + size * 0.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.4
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.72, 0.65, 0.54, 0.75), Color(0.6, 0.55, 0.47, 0.5), Color(0.55, 0.5, 0.45, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_ramp = ramp
	root.add_child(p)
	p.global_position = pos
	_free_later(tree, p, 5.5)
