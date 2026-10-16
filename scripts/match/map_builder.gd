extends RefCounted
## يبني الخرائط الأربع برمجيًا (خامات إجرائية بدون ملفات). نفس seed على كل الأجهزة = نفس الخريطة.

const P := preload("res://scripts/models/parts.gd")
const M := preload("res://scripts/models/mats.gd")
const VM := preload("res://scripts/models/vehicle_models.gd")

const HALF := 300.0
const CORNERS := [Vector2(-240, -240), Vector2(240, -240), Vector2(240, 240), Vector2(-240, 240)]


static func build(parent: Node3D, map_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_id.hash()
	var th := _theme(map_id)
	_environment(parent, th)
	_solid(parent, Vector3(HALF * 2, 2, HALF * 2), Vector3(0, -1, 0), th.g0, Vector3.ZERO, M.ground(th.g0, th.g1, th.uv))
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


static func setup_env(parent: Node, id: String) -> void:
	_environment(parent, _theme(id))


static func _theme(id: String) -> Dictionary:
	match id:
		"desert_base": return {"g0": Color(0.62, 0.5, 0.33), "g1": Color(0.75, 0.62, 0.42), "uv": 0.06, "top": Color(0.27, 0.45, 0.78), "hor": Color(0.82, 0.74, 0.6), "fog": 0.0014}
		"forest": return {"g0": Color(0.16, 0.27, 0.1), "g1": Color(0.28, 0.4, 0.15), "uv": 0.09, "top": Color(0.28, 0.46, 0.72), "hor": Color(0.68, 0.76, 0.78), "fog": 0.0035}
		"military_base": return {"g0": Color(0.33, 0.34, 0.3), "g1": Color(0.45, 0.45, 0.4), "uv": 0.07, "top": Color(0.27, 0.46, 0.78), "hor": Color(0.74, 0.8, 0.85), "fog": 0.0015}
	return {"g0": Color(0.4, 0.36, 0.3), "g1": Color(0.55, 0.5, 0.41), "uv": 0.07, "top": Color(0.36, 0.46, 0.64), "hor": Color(0.78, 0.72, 0.64), "fog": 0.0028}


static func _environment(parent: Node, th: Dictionary) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = th.top
	sm.sky_horizon_color = th.hor
	sm.ground_horizon_color = th.hor
	sm.ground_bottom_color = Color(th.g0).darkened(0.5)
	sm.sun_angle_max = 25.0
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(th.hor).lerp(Color(0.6, 0.65, 0.75), 0.5)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.fog_enabled = true
	env.fog_light_color = th.hor
	env.fog_density = th.fog
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 170.0
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


static func _solid(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO, mat: Material = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	P.box(body, size, Vector3.ZERO, mat if mat else M.solid(col, 0.9))
	body.position = pos
	body.rotation = rot
	parent.add_child(body)
	return body


static func _cyl_solid(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	body.add_child(cs)
	P.cyl(body, radius, height, Vector3.ZERO, mat)
	body.position = pos
	parent.add_child(body)
	return body


static func _flat(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	P.box(parent, size, pos, mat)


static func _rock(parent: Node3D, pos: Vector3, s: float, rng: RandomNumberGenerator, col: Color) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(s * 1.5, s, s * 1.3)
	cs.shape = bs
	cs.position.y = s * 0.2
	body.add_child(cs)
	var m := P.sph(body, s * 0.8, Vector3(0, s * 0.15, 0), M.ground(col.darkened(0.2), col.lightened(0.15), 0.4), Vector3(1.0, 0.7, 0.85))
	m.rotation.y = rng.randf() * TAU
	body.position = pos
	parent.add_child(body)


static func _car(parent: Node3D, pos: Vector3, yaw: float, col: Color) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.0, 1.4, 4.4)
	cs.shape = bs
	cs.position.y = 0.7
	body.add_child(cs)
	var paint := M.solid(col, 0.5, 0.4)
	P.box(body, Vector3(1.9, 0.65, 4.3), Vector3(0, 0.65, 0), paint)
	P.box(body, Vector3(1.7, 0.55, 2.2), Vector3(0, 1.2, 0.2), paint)
	P.box(body, Vector3(1.6, 0.4, 2.0), Vector3(0, 1.25, 0.2), M.glass())
	for sx in [-1.0, 1.0]:
		for z in [-1.4, 1.4]:
			P.cyl(body, 0.36, 0.25, Vector3(sx * 0.95, 0.36, z), M.solid(Color(0.04, 0.04, 0.04), 0.95), Vector3(0, 0, 90))
	body.position = pos
	body.rotation.y = yaw
	parent.add_child(body)


static func _building(parent: Node3D, x: float, z: float, w: float, h: float, d: float, rng: RandomNumberGenerator, palette: Array) -> void:
	var col: Color = palette[rng.randi() % palette.size()]
	col = col.darkened(rng.randf_range(0.0, 0.15))
	var body := _solid(parent, Vector3(w, h, d), Vector3(x, h / 2.0, z), col, Vector3.ZERO, M.building(col))
	P.box(body, Vector3(w + 0.4, 0.4, d + 0.4), Vector3(0, h / 2.0 + 0.2, 0), M.solid(col.darkened(0.35), 0.95))
	if rng.randf() < 0.5:
		P.box(body, Vector3(2.0, 1.0, 2.0), Vector3(rng.randf_range(-w / 3.0, w / 3.0), h / 2.0 + 0.9, rng.randf_range(-d / 3.0, d / 3.0)), M.solid(Color(0.5, 0.5, 0.5), 0.6, 0.4))
	if rng.randf() < 0.35:
		P.box(body, Vector3(w * 0.5, h * 0.35, d + 0.08), Vector3(w * 0.2, h * 0.3, 0), M.solid(Color(0.12, 0.11, 0.1), 1.0))


# ---------------- مدينة مدمرة (مع مسجد بمئذنتين وقباب زرقاء) ----------------
static func _city(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var asphalt := M.ground(Color(0.1, 0.1, 0.11), Color(0.18, 0.18, 0.19), 0.2, 0.05)
	var line := M.solid(Color(0.85, 0.8, 0.4), 0.8)
	_flat(parent, Vector3(HALF * 2, 0.06, 14), Vector3(0, 0.03, 0), asphalt)
	_flat(parent, Vector3(14, 0.06, HALF * 2), Vector3(0, 0.03, 0), asphalt)
	_flat(parent, Vector3(HALF * 2, 0.06, 10), Vector3(0, 0.03, 130), asphalt)
	_flat(parent, Vector3(10, 0.06, HALF * 2), Vector3(-130, 0.03, 0), asphalt)
	for i in range(-14, 15):
		_flat(parent, Vector3(0.3, 0.02, 6), Vector3(0, 0.08, i * 20.0), line)
		_flat(parent, Vector3(6, 0.02, 0.3), Vector3(i * 20.0, 0.08, 0), line)
	var palette := [Color(0.76, 0.69, 0.56), Color(0.67, 0.61, 0.5), Color(0.82, 0.77, 0.67), Color(0.6, 0.54, 0.46)]
	var made := 0
	var tries := 0
	while made < 100 and tries < 1000:
		tries += 1
		var x := rng.randf_range(-280, 280)
		var z := rng.randf_range(-280, 280)
		if _near_corner(x, z) or absf(x) < 16 or absf(z) < 16 or absf(z - 130) < 13 or absf(x + 130) < 13:
			continue
		if Vector2(x, z).distance_to(Vector2(60, 60)) < 45:
			continue
		_building(parent, x, z, rng.randf_range(9, 20), rng.randf_range(7, 26), rng.randf_range(9, 20), rng, palette)
		made += 1
	for i in 22:
		var cx := rng.randf_range(-250, 250)
		var onx := rng.randf() < 0.5
		var pos := Vector3(cx, 0.0, rng.randf_range(-4, 4)) if onx else Vector3(rng.randf_range(-4, 4), 0.0, cx)
		if _near_corner(pos.x, pos.z, 30.0):
			continue
		_car(parent, pos, (PI * 0.5 if onx else 0.0) + rng.randf_range(-0.3, 0.3), [Color(0.15, 0.15, 0.15), Color(0.5, 0.5, 0.52), Color(0.55, 0.12, 0.1), Color(0.2, 0.25, 0.4)][rng.randi() % 4])
	for i in 28:
		var x := rng.randf_range(-270, 270)
		var z := rng.randf_range(-270, 270)
		if _near_corner(x, z, 35.0) or (absf(x) < 10 and absf(z) < 10):
			continue
		_solid(parent, Vector3(0.8, 2.6, 3.2), Vector3(x, 1.3, z), Color(0.6, 0.6, 0.58), Vector3(0, rng.randf() * PI, 0), M.ground(Color(0.45, 0.45, 0.43), Color(0.62, 0.62, 0.6), 0.5))
	for i in 70:
		var x := rng.randf_range(-280, 280)
		var z := rng.randf_range(-280, 280)
		if _near_corner(x, z, 30.0):
			continue
		var s := rng.randf_range(0.8, 2.2)
		_solid(parent, Vector3(s * 1.4, s * 0.7, s), Vector3(x, s * 0.3, z), Color(0.5, 0.46, 0.4), Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2)), M.ground(Color(0.4, 0.37, 0.33), Color(0.55, 0.5, 0.44), 0.8))
	for i in 24:
		var x := rng.randf_range(-270, 270)
		var z := rng.randf_range(-270, 270)
		if _near_corner(x, z, 30.0) or absf(x) < 12 or absf(z) < 12:
			continue
		var sh := rng.randf_range(4.0, 6.0)
		_cyl_solid(parent, 0.25, sh, Vector3(x, sh / 2.0, z), M.solid(Color(0.3, 0.2, 0.12), 0.95))
		P.sph(parent, 2.6, Vector3(x, sh + 1.0, z), M.solid(Color(0.15, 0.3, 0.12), 0.95), Vector3(1.0, 0.8, 1.0))
	_mosque(parent, Vector3(60, 0, 60))


static func _mosque(parent: Node3D, c: Vector3) -> void:
	var stone := M.solid(Color(0.86, 0.8, 0.67), 0.9)
	var blue := M.solid(Color(0.15, 0.5, 0.82), 0.3, 0.3)
	var dark := M.solid(Color(0.1, 0.1, 0.12), 0.7)
	_solid(parent, Vector3(44, 1, 40), c + Vector3(0, 0.5, 0), Color(0.8, 0.75, 0.62))
	var hall := _solid(parent, Vector3(28, 10, 22), c + Vector3(0, 6, 0), Color(0.86, 0.8, 0.66), Vector3.ZERO, stone)
	for i in 5:
		P.box(hall, Vector3(2.2, 4.0, 0.3), Vector3(-9.0 + i * 4.5, -2.0, -11.1), dark)
		P.cyl(hall, 1.1, 0.3, Vector3(-9.0 + i * 4.5, 0.0, -11.1), dark, Vector3(90, 0, 0))
	P.cyl(parent, 8.0, 1.2, c + Vector3(0, 11.4, 0), stone)
	P.sph(parent, 7.5, c + Vector3(0, 12.0, 0), blue, Vector3.ONE, true)
	P.cyl(parent, 0.3, 3.0, c + Vector3(0, 20.5, 0), blue)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			P.sph(parent, 3.0, c + Vector3(sx * 11.0, 11.0, sz * 8.0), blue, Vector3.ONE, true)
	for sx in [-1.0, 1.0]:
		var mc := c + Vector3(sx * 17.0, 0, -15.0)
		_cyl_solid(parent, 1.7, 36.0, mc + Vector3(0, 18, 0), stone)
		P.cyl(parent, 2.4, 0.6, mc + Vector3(0, 29.0, 0), stone)
		P.cyl(parent, 1.9, 0.3, mc + Vector3(0, 29.4, 0), dark)
		P.cyl(parent, 1.4, 4.0, mc + Vector3(0, 32.0, 0), stone)
		P.cyl(parent, 1.6, 0.4, mc + Vector3(0, 34.2, 0), blue)
		P.sph(parent, 1.4, mc + Vector3(0, 34.4, 0), blue, Vector3.ONE, true)
		P.cyl(parent, 0.08, 2.2, mc + Vector3(0, 37.4, 0), blue)
	for sx in [-1.0, 1.0]:
		_solid(parent, Vector3(0.8, 3.0, 40), c + Vector3(sx * 22.0, 2.0, 0), Color(0.8, 0.74, 0.62))
	_solid(parent, Vector3(44, 3.0, 0.8), c + Vector3(0, 2.0, 20.0), Color(0.8, 0.74, 0.62))


# ---------------- صحراء عسكرية ----------------
static func _desert(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var sand := Color(0.64, 0.52, 0.36)
	for i in 22:
		var x := rng.randf_range(-280, 280)
		var z := rng.randf_range(-280, 280)
		P.sph(parent, 1.0, Vector3(x, -0.4, z), M.ground(sand.darkened(0.05), sand.lightened(0.1), 0.05), Vector3(rng.randf_range(25, 55), rng.randf_range(1.2, 2.0), rng.randf_range(25, 55)))
	for i in 90:
		var x := rng.randf_range(-285, 285)
		var z := rng.randf_range(-285, 285)
		if _near_corner(x, z, 40.0):
			continue
		_rock(parent, Vector3(x, 0.4, z), rng.randf_range(2.0, 6.0), rng, Color(0.55, 0.45, 0.33))
	var mud := [Color(0.72, 0.6, 0.43), Color(0.66, 0.54, 0.38), Color(0.78, 0.67, 0.5)]
	var made := 0
	var tries := 0
	while made < 24 and tries < 300:
		tries += 1
		var x := rng.randf_range(-270, 270)
		var z := rng.randf_range(-270, 270)
		if _near_corner(x, z, 50.0) or Vector2(x, z).length() < 45.0:
			continue
		_building(parent, x, z, rng.randf_range(7, 13), rng.randf_range(4, 9), rng.randf_range(7, 13), rng, mud)
		made += 1
	var wall := M.ground(Color(0.55, 0.5, 0.42), Color(0.7, 0.64, 0.54), 0.3)
	for s in [-1.0, 1.0]:
		_solid(parent, Vector3(72, 5, 2), Vector3(0, 2.5, s * 36), Color(0.6, 0.55, 0.46), Vector3.ZERO, wall)
	_solid(parent, Vector3(2, 5, 28), Vector3(-36, 2.5, -22), Color(0.6, 0.55, 0.46), Vector3.ZERO, wall)
	_solid(parent, Vector3(2, 5, 28), Vector3(-36, 2.5, 22), Color(0.6, 0.55, 0.46), Vector3.ZERO, wall)
	_solid(parent, Vector3(2, 5, 72), Vector3(36, 2.5, 0), Color(0.6, 0.55, 0.46), Vector3.ZERO, wall)
	for c in [Vector3(-36, 0, -36), Vector3(36, 0, 36), Vector3(-36, 0, 36), Vector3(36, 0, -36)]:
		_solid(parent, Vector3(6, 13, 6), c + Vector3(0, 6.5, 0), Color(0.6, 0.55, 0.46), Vector3.ZERO, wall)
		P.box(parent, Vector3(7, 0.5, 7), c + Vector3(0, 13.2, 0), M.solid(Color(0.4, 0.37, 0.32)))
	var bag := M.ground(Color(0.55, 0.5, 0.36), Color(0.7, 0.64, 0.48), 0.9)
	for i in 26:
		_solid(parent, Vector3(3.0, 0.9, 0.9), Vector3(rng.randf_range(-30, 30), 0.45, rng.randf_range(-30, 30)), Color(0.6, 0.55, 0.4), Vector3(0, rng.randf() * PI, 0), bag)
	for i in 6:
		var x := rng.randf_range(-250, 250)
		var z := rng.randf_range(-250, 250)
		if _near_corner(x, z, 40.0):
			continue
		_car(parent, Vector3(x, 0, z), rng.randf() * TAU, Color(0.2, 0.18, 0.15))


# ---------------- غابة ----------------
static func _forest(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var bark := M.solid(Color(0.3, 0.2, 0.12), 0.95)
	var pine := [M.solid(Color(0.06, 0.22, 0.1), 0.95), M.solid(Color(0.08, 0.27, 0.12), 0.95), M.solid(Color(0.1, 0.3, 0.14), 0.95)]
	var leaf := [M.solid(Color(0.14, 0.34, 0.1), 0.95), M.solid(Color(0.2, 0.4, 0.12), 0.95), M.solid(Color(0.3, 0.42, 0.12), 0.95)]
	for i in 140:
		var x := rng.randf_range(-290, 290)
		var z := rng.randf_range(-290, 290)
		if _near_corner(x, z, 35.0):
			continue
		var h := rng.randf_range(8, 14)
		var tree := _cyl_solid(parent, 0.5, h, Vector3(x, h / 2.0, z), bark)
		if rng.randf() < 0.55:
			var m: Material = pine[rng.randi() % 3]
			for k in 4:
				var r := (h * 0.3) * (1.0 - k * 0.2)
				P.cyl(tree, r, h * 0.35, Vector3(0, h * (-0.05 + k * 0.22), 0), m, Vector3.ZERO, 0.0)
		else:
			var m2: Material = leaf[rng.randi() % 3]
			var r2 := rng.randf_range(3.0, 4.6)
			P.sph(tree, r2, Vector3(0, h * 0.5 + 1.0, 0), m2, Vector3(1.0, 0.85, 1.0))
			P.sph(tree, r2 * 0.7, Vector3(r2 * 0.5, h * 0.5 - 0.2, 0.3), m2)
	for i in 60:
		var x := rng.randf_range(-290, 290)
		var z := rng.randf_range(-290, 290)
		if _near_corner(x, z, 30.0):
			continue
		P.sph(parent, rng.randf_range(0.6, 1.3), Vector3(x, 0.4, z), leaf[rng.randi() % 3], Vector3(1.4, 0.8, 1.2))
	for i in 28:
		var x := rng.randf_range(-280, 280)
		var z := rng.randf_range(-280, 280)
		if _near_corner(x, z, 35.0):
			continue
		_rock(parent, Vector3(x, 0.3, z), rng.randf_range(1.5, 4.0), rng, Color(0.4, 0.4, 0.38))
	for i in 14:
		var x := rng.randf_range(-260, 260)
		var z := rng.randf_range(-260, 260)
		if _near_corner(x, z, 35.0):
			continue
		var lg := _cyl_solid(parent, 0.45, 7.0, Vector3(x, 0.45, z), bark)
		lg.rotation = Vector3(PI * 0.5, rng.randf() * PI, 0)
	for i in 6:
		var x := rng.randf_range(-230, 230)
		var z := rng.randf_range(-230, 230)
		if _near_corner(x, z, 40.0):
			continue
		_building(parent, x, z, 8, 4.5, 6, rng, [Color(0.4, 0.28, 0.18), Color(0.45, 0.32, 0.2)])


# ---------------- قاعدة عسكرية (مدرج + حظائر + برج مراقبة + طائرات) ----------------
static func _base(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var asphalt := M.ground(Color(0.1, 0.1, 0.11), Color(0.17, 0.17, 0.18), 0.2, 0.05)
	var white := M.solid(Color(0.9, 0.9, 0.88), 0.8)
	_flat(parent, Vector3(44, 0.06, 540), Vector3(0, 0.03, 0), asphalt)
	for z in range(-250, 251, 40):
		_flat(parent, Vector3(1.4, 0.02, 16), Vector3(0, 0.08, z), white)
	for sx in [-1.0, 1.0]:
		_flat(parent, Vector3(0.4, 0.02, 540), Vector3(sx * 20.0, 0.08, 0), white)
	_flat(parent, Vector3(120, 0.06, 40), Vector3(-82, 0.03, 20), asphalt)
	var metal := M.ground(Color(0.42, 0.46, 0.4), Color(0.55, 0.58, 0.52), 0.25)
	for sx in [-1.0, 1.0]:
		for i in 3:
			var hz := -100.0 + i * 100.0
			var hangar := _solid(parent, Vector3(30, 8, 22), Vector3(sx * 75.0, 4, hz), Color(0.45, 0.5, 0.42), Vector3.ZERO, metal)
			P.cyl(hangar, 8.5, 22.0, Vector3(0, 4.0, 0), M.solid(Color(0.36, 0.4, 0.34), 0.6, 0.4), Vector3(90, 0, 0))
			P.box(hangar, Vector3(18, 7, 0.4), Vector3(0, -0.5, -11.1), M.solid(Color(0.1, 0.11, 0.1), 0.7))
	var tower := _solid(parent, Vector3(6, 24, 6), Vector3(44, 12, 0), Color(0.7, 0.7, 0.68), Vector3.ZERO, M.solid(Color(0.7, 0.7, 0.68), 0.8))
	P.box(tower, Vector3(10, 4.5, 10), Vector3(0, 14.2, 0), M.glass())
	P.box(tower, Vector3(11, 0.6, 11), Vector3(0, 16.8, 0), M.solid(Color(0.3, 0.3, 0.3)))
	P.cyl(tower, 0.1, 5.0, Vector3(3, 19.2, 3), M.solid(Color(0.3, 0.3, 0.3)))
	P.sph(tower, 2.2, Vector3(-2.5, 18.0, -2.5), M.solid(Color(0.8, 0.8, 0.8), 0.6), Vector3(1.0, 0.5, 1.0), true)
	for i in 6:
		_cyl_solid(parent, 4.2, 9.0, Vector3(-150 + i * 12.0, 4.5, 215), M.solid(Color(0.5, 0.52, 0.5), 0.6, 0.4))
	var conts := [Color(0.5, 0.15, 0.1), Color(0.15, 0.3, 0.5), Color(0.2, 0.4, 0.2), Color(0.55, 0.45, 0.2)]
	for i in 14:
		var x := rng.randf_range(-280, 280)
		var z := rng.randf_range(-280, 280)
		if _near_corner(x, z, 45.0) or absf(x) < 30.0 or absf(x - 75) < 20 or absf(x + 75) < 20:
			continue
		_solid(parent, Vector3(2.6, 2.6, 6.1), Vector3(x, 1.3, z), conts[rng.randi() % 4], Vector3(0, rng.randi() % 2 * PI * 0.5, 0), M.solid(conts[rng.randi() % 4], 0.6, 0.3))
	for i in 40:
		var x := rng.randf_range(-280, 280)
		var z := rng.randf_range(-280, 280)
		if _near_corner(x, z, 40.0) or absf(x) < 26.0:
			continue
		_solid(parent, Vector3(3.5, 1.8, 1.4), Vector3(x, 0.9, z), Color(0.5, 0.48, 0.38), Vector3(0, rng.randf() * TAU, 0), M.ground(Color(0.4, 0.38, 0.3), Color(0.55, 0.52, 0.42), 0.8))
	for p in [[Vector3(-12, 0, -20), "jet", PI * 0.0], [Vector3(-12, 0, 40), "jet", 0.0], [Vector3(-100, 0, 20), "heli", 0.6], [Vector3(-70, 0, 30), "heli", -0.4]]:
		var holder := Node3D.new()
		holder.position = p[0]
		holder.rotation.y = p[2]
		parent.add_child(holder)
		var turret := Node3D.new()
		holder.add_child(turret)
		VM.build(holder, turret, p[1], Color(0.5, 0.5, 0.5))
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(7, 2.5, 11) if p[1] == "jet" else Vector3(2.6, 3, 9)
		cs.shape = bs
		cs.position.y = 1.4
		sb.add_child(cs)
		holder.add_child(sb)
