extends RefCounted
## مبانٍ قابلة للدخول والتدمير: جدران من قطع (مع أبواب ونوافذ)، أرضيات وسقف وسلم،
## وتُهدم القطع حول أي انفجار (نفس النتيجة على كل الأجهزة) مع حطام وغبار وانهيار.

const P := preload("res://scripts/models/parts.gd")
const M := preload("res://scripts/models/mats.gd")
const Fx := preload("res://scripts/match/fx.gd")

const FH := 2.8


static func _chunk(bld: Node3D, size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	P.box(b, size, Vector3.ZERO, mat)
	b.position = pos
	bld.add_child(b)
	b.add_to_group("chunk")
	b.set_meta("bld", bld)
	b.set_meta("sz", size)
	b.set_meta("mat", mat)
	bld.set_meta("total", int(bld.get_meta("total", 0)) + 1)
	bld.set_meta("alive", int(bld.get_meta("alive", 0)) + 1)
	return b


static func _prop(bld: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	P.box(b, size, Vector3.ZERO, mat)
	b.position = pos
	bld.add_child(b)


## side: 0=-Z 1=+Z 2=-X 3=+X (جهة الباب)
static func enterable(parent: Node3D, c: Vector3, w: float, d: float, floors: int, col: Color, door_side: int, rng: RandomNumberGenerator) -> void:
	var bld := Node3D.new()
	bld.position = c
	parent.add_child(bld)
	var wall := M.wall(col)
	var slab := M.wall(col.darkened(0.22))
	var wood := M.solid(Color(0.38, 0.28, 0.18), 0.9)
	var t := 0.4
	var nx := maxi(3, roundi(w / 2.6))
	var nz := maxi(3, roundi(d / 2.6))
	var H := FH * floors

	for side in 4:
		var horiz := side < 2
		var span := w if horiz else d - 2.0 * t
		var n := nx if horiz else nz
		var seg := span / n
		for i in n:
			var along := -span / 2.0 + seg * (i + 0.5)
			for r in floors:
				var y0 := r * FH
				var is_door := side == door_side and r == 0 and i == n / 2
				if is_door:
					continue
				var px := 0.0
				var pz := 0.0
				var sz := Vector3.ZERO
				if horiz:
					px = along
					pz = (-d / 2.0 + t / 2.0) if side == 0 else (d / 2.0 - t / 2.0)
					sz = Vector3(seg, FH, t)
				else:
					pz = along
					px = (-w / 2.0 + t / 2.0) if side == 2 else (w / 2.0 - t / 2.0)
					sz = Vector3(t, FH, seg)
				var window := (i + r) % 2 == 1 and not (side == door_side and r == 0)
				if window:
					var sill := Vector3(sz.x, 0.9, sz.z)
					var lint := Vector3(sz.x, 0.7, sz.z)
					_chunk(bld, sill, Vector3(px, y0 + 0.45, pz), wall)
					_chunk(bld, lint, Vector3(px, y0 + FH - 0.35, pz), wall)
				else:
					_chunk(bld, sz, Vector3(px, y0 + FH / 2.0, pz), wall)

	# أرضية داخلية وأثاث
	P.box(bld, Vector3(w - 2.0 * t, 0.08, d - 2.0 * t), Vector3(0, 0.04, 0), wood)
	var rx := -w / 2.0 + t + 1.2
	var run := FH / tan(deg_to_rad(28.0))
	var zs := d / 2.0 - t - 0.3
	for i in 3:
		var fx := rng.randf_range(-w / 2.0 + 1.6, w / 2.0 - 1.6)
		var fz := rng.randf_range(-d / 2.0 + 1.6, d / 2.0 - 1.6)
		if floors >= 2 and absf(fx - rx) < 2.2 and fz > zs - run - 1.0:
			continue
		var door_pos := Vector2.ZERO
		match door_side:
			0: door_pos = Vector2(0, -d / 2.0)
			1: door_pos = Vector2(0, d / 2.0)
			2: door_pos = Vector2(-w / 2.0, 0)
			_: door_pos = Vector2(w / 2.0, 0)
		if Vector2(fx, fz).distance_to(door_pos) < 3.5:
			continue
		_prop(bld, Vector3(rng.randf_range(0.8, 1.6), rng.randf_range(0.6, 1.2), rng.randf_range(0.8, 1.4)), Vector3(fx, 0.5, fz), wood)

	# السلم (منحدر) والطابق الثاني
	if floors >= 2:
		var ang := atan(FH / run)
		var L := sqrt(run * run + FH * FH)
		var rb := StaticBody3D.new()
		var rcs := CollisionShape3D.new()
		var rsh := BoxShape3D.new()
		rsh.size = Vector3(1.8, 0.25, L)
		rcs.shape = rsh
		rb.add_child(rcs)
		P.box(rb, Vector3(1.8, 0.25, L), Vector3.ZERO, wood)
		for k in 6:
			P.box(rb, Vector3(1.8, 0.04, 0.06), Vector3(0, 0.14, -L / 2.0 + 0.5 + k * (L - 1.0) / 5.0), M.solid(Color(0.2, 0.15, 0.1), 0.9))
		rb.position = Vector3(rx, FH / 2.0, zs - run / 2.0)
		rb.rotation.x = ang
		bld.add_child(rb)
	for k in range(1, floors + 1):
		var y := FH * k
		var ix := w - 2.0 * t if k < floors else w
		var iz := d - 2.0 * t if k < floors else d
		var cnx := maxi(3, roundi(ix / 2.6))
		var cnz := maxi(3, roundi(iz / 2.6))
		var cw := ix / cnx
		var cd := iz / cnz
		for a in cnx:
			for b in cnz:
				var cx := -ix / 2.0 + cw * (a + 0.5)
				var cz := -iz / 2.0 + cd * (b + 0.5)
				if k == 1 and floors >= 2 and absf(cx - rx) < 1.7 and cz > zs - run + 0.7 and cz < zs + 0.5:
					continue
				_chunk(bld, Vector3(cw, 0.3, cd), Vector3(cx, y - 0.15, cz), slab)


# ---------------- التدمير ----------------

static func _hash01(v: Vector3) -> float:
	var h := hash(Vector3i(roundi(v.x * 10.0), roundi(v.y * 10.0), roundi(v.z * 10.0)))
	return float(absi(h) % 1000) / 1000.0


static func destroy(tree: SceneTree, pos: Vector3, radius: float) -> void:
	var touched := {}
	var removed := 0
	for n in tree.get_nodes_in_group("chunk"):
		if not is_instance_valid(n):
			continue
		var c: Vector3 = n.global_position
		var dd := c.distance_to(pos)
		if dd > radius + 2.0:
			continue
		if dd <= radius * (0.55 + 0.5 * _hash01(c)):
			touched[n.get_meta("bld")] = true
			_break(tree, n, pos)
			removed += 1
	if removed > 0:
		Fx.dust(tree, pos, radius * 0.8)
	for b in touched.keys():
		if is_instance_valid(b):
			_check_collapse(tree, b, pos)


static func _check_collapse(tree: SceneTree, b: Node3D, centre: Vector3) -> void:
	var total := int(b.get_meta("total", 1))
	var alive := int(b.get_meta("alive", 0))
	if b.get_meta("collapsing", false) or alive > total * 0.45:
		return
	b.set_meta("collapsing", true)
	Sfx.play3d("collapse", b.global_position, 8.0, 1.0, 400.0)
	Fx.dust(tree, b.global_position + Vector3(0, 3, 0), 14.0)
	for ch in tree.get_nodes_in_group("chunk"):
		if is_instance_valid(ch) and ch.get_meta("bld") == b:
			var delay := randf() * 1.6
			tree.create_timer(delay).timeout.connect(func(): _break(tree, ch, centre))


static func _break(tree: SceneTree, n, from: Vector3) -> void:
	if not is_instance_valid(n) or n.is_queued_for_deletion():
		return
	var b = n.get_meta("bld")
	if is_instance_valid(b):
		b.set_meta("alive", int(b.get_meta("alive", 1)) - 1)
	var sz: Vector3 = n.get_meta("sz")
	var mat: Material = n.get_meta("mat")
	var gp: Vector3 = n.global_position
	n.queue_free()
	if tree.get_nodes_in_group("debris").size() >= 70 or tree.current_scene == null:
		return
	var rb := RigidBody3D.new()
	rb.collision_layer = 2
	rb.collision_mask = 1
	rb.mass = 25.0
	var s := randf_range(0.45, 0.9)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3.ONE * s
	cs.shape = sh
	rb.add_child(cs)
	P.box(rb, Vector3.ONE * s, Vector3.ZERO, mat)
	rb.add_to_group("debris")
	tree.current_scene.add_child(rb)
	rb.global_position = gp + Vector3(randf_range(-0.5, 0.5) * sz.x * 0.5, randf_range(-0.5, 0.5) * sz.y * 0.5, randf_range(-0.5, 0.5) * sz.z * 0.5)
	var away := (rb.global_position - from)
	away.y = 0.0
	rb.apply_impulse(away.normalized() * randf_range(60.0, 180.0) + Vector3.UP * randf_range(40.0, 120.0))
	rb.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	tree.create_timer(randf_range(5.0, 8.0)).timeout.connect(rb.queue_free)
