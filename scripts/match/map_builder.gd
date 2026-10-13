extends RefCounted
## يبني الخرائط الأربع برمجيًا (أشكال بسيطة). نفس seed على كل الأجهزة = نفس الخريطة.
## استبدلها لاحقًا بمشاهد/نماذج حقيقية (.glb) من Blender.

const HALF := 300.0
const CORNERS := [Vector2(-240, -240), Vector2(240, -240), Vector2(240, 240), Vector2(-240, 240)]


static func build(parent: Node3D, map_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_id.hash()
	var th := _theme(map_id)
	_environment(parent, th)
	_solid(parent, Vector3(HALF * 2, 2, HALF * 2), Vector3(0, -1, 0), th.ground)
	_border(parent)
	match map_id:
		"ruined_city": _city(parent, rng)
		"desert_base": _desert(parent, rng)
		"forest": _forest(parent, rng)
		"military_base": _base(parent, rng)
	var sp := {}
	for i in 4:
		sp[i] = Vector3(CORNERS[i].x, 0, CORNERS[i].y)
	return sp


static func _theme(id: String) -> Dictionary:
	match id:
		"desert_base": return {"ground": Color(0.76, 0.65, 0.45), "top": Color(0.35, 0.55, 0.85), "hor": Color(0.85, 0.78, 0.65), "fog": 0.0012}
		"forest": return {"ground": Color(0.2, 0.34, 0.15), "top": Color(0.3, 0.5, 0.75), "hor": Color(0.7, 0.8, 0.8), "fog": 0.003}
		"military_base": return {"ground": Color(0.4, 0.42, 0.38), "top": Color(0.3, 0.5, 0.8), "hor": Color(0.75, 0.8, 0.85), "fog": 0.0015}
	return {"ground": Color(0.55, 0.5, 0.42), "top": Color(0.42, 0.52, 0.7), "hor": Color(0.8, 0.75, 0.68), "fog": 0.0025}


static func _environment(parent: Node3D, th: Dictionary) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = th.top
	sm.sky_horizon_color = th.hor
	sm.ground_horizon_color = th.hor
	sm.ground_bottom_color = th.ground.darkened(0.4)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = th.hor
	env.fog_density = th.fog
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	parent.add_child(sun)


static func _border(parent: Node3D) -> void:
	var h := 60.0
	for d in [Vector3(HALF, 0, 0), Vector3(-HALF, 0, 0), Vector3(0, 0, HALF), Vector3(0, 0, -HALF)]:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2, h, HALF * 2) if d.x != 0 else Vector3(HALF * 2, h, 2)
		cs.shape = bs
		body.position = d + Vector3(0, h / 2.0, 0)
		body.add_child(cs)
		parent.add_child(body)


static func _near_corner(x: float, z: float, r := 45.0) -> bool:
	for c in CORNERS:
		if Vector2(x, z).distance_to(c) < r:
			return true
	return false


static func _solid(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	body.add_child(mi)
	body.position = pos
	body.rotation = rot
	parent.add_child(body)
	return body


static func _cyl_solid(parent: Node3D, radius: float, height: float, pos: Vector3, col: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	body.add_child(mi)
	body.position = pos
	parent.add_child(body)
	return body


static func _flat(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


# ---------------- مدينة مدمرة (مع مسجد بمئذنتين كمَعلَم) ----------------
static func _city(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var road := Color(0.18, 0.18, 0.19)
	_flat(parent, Vector3(HALF * 2, 0.05, 14), Vector3(0, 0.03, 0), road)
	_flat(parent, Vector3(14, 0.05, HALF * 2), Vector3(0, 0.03, 0), road)
	_flat(parent, Vector3(HALF * 2, 0.05, 10), Vector3(0, 0.03, 130), road)
	_flat(parent, Vector3(10, 0.05, HALF * 2), Vector3(-130, 0.03, 0), road)
	var made := 0
	var tries := 0
	while made < 100 and tries < 1000:
		tries += 1
		var x := rng.randf_range(-280, 280)
		var z := rng.randf_range(-280, 280)
		if _near_corner(x, z) or absf(x) < 14 or absf(z) < 14 or absf(z - 130) < 12 or absf(x + 130) < 12:
			continue
		if Vector2(x, z).distance_to(Vector2(55, 55)) < 40:
			continue
		var w := rng.randf_range(8, 20)
		var d := rng.randf_range(8, 20)
		var h := rng.randf_range(6, 26)
		var c := Color(0.72, 0.65, 0.52).darkened(rng.randf_range(0.0, 0.25))
		_solid(parent, Vector3(w, h, d), Vector3(x, h / 2.0, z), c)
		made += 1
	for i in 60:
		var x := rng.randf_range(-280, 280)
		var z := rng.randf_range(-280, 280)
		if _near_corner(x, z, 30.0):
			continue
		var s := rng.randf_range(1.0, 3.0)
		_solid(parent, Vector3(s, s * 0.6, s), Vector3(x, s * 0.3, z), Color(0.5, 0.46, 0.4), Vector3(0, rng.randf() * TAU, 0))
	# مسجد
	var mc := Vector3(55, 0, 55)
	_solid(parent, Vector3(36, 1, 30), mc + Vector3(0, 0.5, 0), Color(0.8, 0.75, 0.62))
	_solid(parent, Vector3(28, 10, 22), mc + Vector3(0, 6, 0), Color(0.86, 0.8, 0.66))
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 7.0
	sm.height = 14.0
	dome.mesh = sm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.2, 0.55, 0.85)
	dome.material_override = dm
	dome.position = mc + Vector3(0, 12, 0)
	parent.add_child(dome)
	for sx in [-16.0, 16.0]:
		_cyl_solid(parent, 1.6, 38.0, mc + Vector3(sx, 19, -13), Color(0.85, 0.8, 0.68))
		_cyl_solid(parent, 2.1, 1.5, mc + Vector3(sx, 33, -13), Color(0.2, 0.55, 0.85))


# ---------------- صحراء عسكرية ----------------
static func _desert(parent: Node3D, rng: RandomNumberGenerator) -> void:
	for i in 100:
		var x := rng.randf_range(-285, 285)
		var z := rng.randf_range(-285, 285)
		if _near_corner(x, z, 40.0):
			continue
		var s := rng.randf_range(3, 10)
		_solid(parent, Vector3(s, s * rng.randf_range(0.5, 1.2), s * 1.2), Vector3(x, s * 0.3, z), Color(0.62, 0.52, 0.38), Vector3(rng.randf() * 0.3, rng.randf() * TAU, rng.randf() * 0.3))
	for i in 18:
		var x := rng.randf_range(-280, 280)
		var z := rng.randf_range(-280, 280)
		_flat(parent, Vector3(rng.randf_range(30, 60), 2.0, rng.randf_range(30, 60)), Vector3(x, 0.4, z), Color(0.8, 0.7, 0.5))
	var wall := Color(0.55, 0.52, 0.45)
	for s in [-1.0, 1.0]:
		_solid(parent, Vector3(70, 5, 2), Vector3(0, 2.5, s * 35), wall)
		_solid(parent, Vector3(2, 5, 70), Vector3(s * 35, 2.5, 0), wall)
	for c in [Vector3(-30, 0, -30), Vector3(30, 0, 30)]:
		_solid(parent, Vector3(5, 12, 5), c + Vector3(0, 6, 0), wall.darkened(0.1))
	for i in 20:
		_solid(parent, Vector3(3, 1, 1), Vector3(rng.randf_range(-25, 25), 0.5, rng.randf_range(-25, 25)), Color(0.6, 0.55, 0.4))


# ---------------- غابة ----------------
static func _forest(parent: Node3D, rng: RandomNumberGenerator) -> void:
	for i in 170:
		var x := rng.randf_range(-290, 290)
		var z := rng.randf_range(-290, 290)
		if _near_corner(x, z, 35.0):
			continue
		var h := rng.randf_range(7, 12)
		_cyl_solid(parent, 0.5, h, Vector3(x, h / 2.0, z), Color(0.35, 0.22, 0.12))
		var crown := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(3, 4.5)
		sm.height = sm.radius * 2.0
		crown.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.1, 0.3 + rng.randf() * 0.15, 0.1)
		crown.material_override = m
		crown.position = Vector3(x, h + 1.0, z)
		parent.add_child(crown)
	for i in 30:
		var x := rng.randf_range(-280, 280)
		var z := rng.randf_range(-280, 280)
		if _near_corner(x, z, 35.0):
			continue
		var s := rng.randf_range(2, 5)
		_solid(parent, Vector3(s, s, s), Vector3(x, s * 0.4, z), Color(0.4, 0.4, 0.38), Vector3(0, rng.randf() * TAU, 0))


# ---------------- قاعدة عسكرية (مدرج + أبراج) ----------------
static func _base(parent: Node3D, rng: RandomNumberGenerator) -> void:
	_flat(parent, Vector3(40, 0.06, 520), Vector3(0, 0.04, 0), Color(0.15, 0.15, 0.16))
	for z in range(-240, 241, 40):
		_flat(parent, Vector3(1.2, 0.07, 14), Vector3(0, 0.06, z), Color(0.9, 0.9, 0.9))
	for sx in [-1.0, 1.0]:
		for i in 3:
			_solid(parent, Vector3(30, 12, 20), Vector3(sx * 70, 6, -90 + i * 90), Color(0.45, 0.5, 0.42))
	_solid(parent, Vector3(6, 22, 6), Vector3(40, 11, 0), Color(0.6, 0.6, 0.6))
	_solid(parent, Vector3(10, 4, 10), Vector3(40, 23, 0), Color(0.3, 0.45, 0.55))
	for i in 6:
		_cyl_solid(parent, 4.0, 8.0, Vector3(-150 + i * 12, 4, 200), Color(0.5, 0.52, 0.5))
	for i in 40:
		var x := rng.randf_range(-280, 280)
		var z := rng.randf_range(-280, 280)
		if _near_corner(x, z, 40.0) or absf(x) < 25:
			continue
		_solid(parent, Vector3(4, 2, 1.5), Vector3(x, 1, z), Color(0.5, 0.48, 0.38), Vector3(0, rng.randf() * TAU, 0))
