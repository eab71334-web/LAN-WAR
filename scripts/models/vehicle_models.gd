extends RefCounted
## نماذج المركبات المفصّلة (من أشكال أساسية). الاتجاه للأمام = -Z.
## build() يرجع قاموسًا: wheels, tip, rotor, tail, burner, gun, body

const P := preload("res://scripts/models/parts.gd")
const M := preload("res://scripts/models/mats.gd")


static func build(v: Node3D, turret: Node3D, kind: String, team_col: Color) -> Dictionary:
	var d := {"wheels": [], "tip": null, "rotor": null, "tail": null, "burner": null, "gun": null, "body": null}
	match kind:
		"mlrs": _mlrs(v, turret, d, team_col)
		"tank": _tank(v, turret, d, team_col)
		"apc": _apc(v, turret, d, team_col)
		"jeep": _jeep(v, turret, d, team_col)
		"heli": _heli(v, d, team_col)
		"jet": _jet(v, d, team_col)
	return d


static func _tracks(v: Node3D, d: Dictionary, xo: float, length: float, n: int, wr: float, steel: Material, rub: Material, hub: Material) -> void:
	var step := (length - 1.2) / float(n - 1)
	for sx in [-1.0, 1.0]:
		var x: float = sx * xo
		P.box(v, Vector3(0.5, wr * 2.2, length), Vector3(x, wr + 0.12, 0.0), rub)
		for i in n:
			var w := P.pivot(v, Vector3(x, wr + 0.05, -length * 0.5 + 0.6 + i * step))
			P.cyl(w, wr, 0.64, Vector3.ZERO, steel, Vector3(0, 0, 90))
			P.cyl(w, wr * 0.5, 0.7, Vector3.ZERO, hub, Vector3(0, 0, 90))
			d.wheels.append(w)
		for z in [-length * 0.5 + 0.2, length * 0.5 - 0.2]:
			var w2 := P.pivot(v, Vector3(x, wr + 0.2, z))
			P.cyl(w2, wr * 1.15, 0.6, Vector3.ZERO, steel, Vector3(0, 0, 90))
			P.cyl(w2, wr * 0.5, 0.66, Vector3.ZERO, hub, Vector3(0, 0, 90))
			d.wheels.append(w2)
		for i in 3:
			P.cyl(v, wr * 0.35, 0.5, Vector3(x, wr * 2.4, -length * 0.3 + i * length * 0.3), steel, Vector3(0, 0, 90))


# ---------------------------------------------------------------- راجمة M270 MLRS
static func _mlrs(v: Node3D, t: Node3D, d: Dictionary, team_col: Color) -> void:
	var camo := M.camo("woodland")
	var steel := M.solid(Color(0.17, 0.18, 0.16), 0.55, 0.5)
	var rub := M.solid(Color(0.06, 0.06, 0.055), 0.95)
	var hub := M.solid(Color(0.3, 0.3, 0.27), 0.5, 0.5)
	var dark := M.solid(Color(0.05, 0.05, 0.05), 0.6)
	_tracks(v, d, 1.2, 6.4, 6, 0.4, steel, rub, hub)
	# بدن
	P.box(v, Vector3(2.6, 0.8, 6.3), Vector3(0, 1.22, 0.0), camo)
	P.box(v, Vector3(2.8, 0.1, 6.4), Vector3(0, 0.82, 0), steel)
	for sx in [-1.0, 1.0]:
		P.box(v, Vector3(0.35, 0.1, 6.0), Vector3(sx * 1.45, 1.18, 0.0), camo)
	# قمرة القيادة (أمام)
	P.box(v, Vector3(2.5, 1.25, 2.3), Vector3(0, 2.25, -2.0), camo)
	P.box(v, Vector3(2.5, 0.45, 0.7), Vector3(0, 1.75, -3.3), camo, Vector3(-32, 0, 0))
	P.box(v, Vector3(2.3, 0.85, 0.08), Vector3(0, 2.4, -3.18), M.glass(), Vector3(-16, 0, 0))
	P.box(v, Vector3(2.6, 0.12, 0.5), Vector3(0, 2.95, -3.1), camo, Vector3(-6, 0, 0))
	for sx in [-1.0, 1.0]:
		P.box(v, Vector3(0.06, 0.6, 1.2), Vector3(sx * 1.27, 2.45, -2.2), M.glass())
		P.box(v, Vector3(0.18, 0.5, 0.18), Vector3(sx * 1.33, 2.3, -3.0), steel)
	P.cyl(v, 0.32, 0.1, Vector3(0.5, 2.9, -1.8), steel)
	# فتحات التهوية
	for i in 3:
		P.box(v, Vector3(0.72, 0.07, 1.1), Vector3(-0.8 + i * 0.8, 1.72, -0.2), steel, Vector3(-12, 0, 0))
		for j in 4:
			P.box(v, Vector3(0.68, 0.02, 0.05), Vector3(-0.8 + i * 0.8, 1.77, -0.55 + j * 0.25), dark, Vector3(-12, 0, 0))
	# مصابيح ومصد
	for sx in [-1.0, 1.0]:
		P.sph(v, 0.11, Vector3(sx * 0.85, 1.5, -3.38), M.emissive(Color(1, 0.96, 0.8), 1.6))
		P.box(v, Vector3(0.45, 0.18, 0.08), Vector3(sx * 0.85, 1.5, -3.34), dark)
	P.box(v, Vector3(2.7, 0.22, 0.22), Vector3(0, 0.9, -3.28), steel)
	P.box(v, Vector3(0.8, 0.06, 0.4), Vector3(0, 2.06, -3.34), dark)
	# هوائيات وعلم الفريق
	for a in [Vector3(-1.0, 3.9, -1.4), Vector3(1.0, 3.5, -1.0)]:
		P.cyl(v, 0.012, 2.0, a, steel)
	P.box(v, Vector3(0.02, 0.28, 0.45), Vector3(-1.0, 4.7, -1.2), M.solid(team_col, 0.6))
	# حاوية الصواريخ على المفصلة الخلفية
	t.position = Vector3(0, 1.65, 2.75)
	var pod := P.pivot(t, Vector3.ZERO, "Pod")
	pod.rotation_degrees = Vector3(43, 0, 0)
	d["pod"] = pod
	P.box(pod, Vector3(2.3, 1.0, 3.9), Vector3(0, 0.6, -1.95), camo)
	P.box(pod, Vector3(2.5, 0.12, 4.0), Vector3(0, 1.14, -1.95), steel)
	P.box(pod, Vector3(2.5, 0.12, 4.0), Vector3(0, 0.04, -1.95), steel)
	for sx in [-1.0, 1.0]:
		P.box(pod, Vector3(0.14, 1.2, 4.0), Vector3(sx * 1.2, 0.6, -1.95), steel)
	for i in 3:
		P.box(pod, Vector3(2.3, 0.05, 0.08), Vector3(0, 1.0, -0.6 - i * 1.2), steel)
	for r in 2:
		for c in 6:
			var tx := -0.95 + c * 0.38
			var ty := 0.3 + r * 0.5
			P.cyl(pod, 0.19, 0.06, Vector3(tx, ty, -3.93), hub, Vector3(90, 0, 0))
			P.cyl(pod, 0.155, 0.1, Vector3(tx, ty, -3.95), dark, Vector3(90, 0, 0))
	d["tip"] = P.pivot(pod, Vector3(0, 0.55, -4.1), "Tip")
	for sx in [-1.0, 1.0]:
		P.cyl(v, 0.09, 1.95, Vector3(sx * 0.9, 2.25, 2.05), steel, Vector3(-21.6, 0, 0))
		P.box(v, Vector3(0.3, 0.3, 0.3), Vector3(sx * 0.9, 1.75, 1.45), steel)
	P.box(v, Vector3(2.2, 0.5, 0.6), Vector3(0, 1.75, 2.9), camo)


# ---------------------------------------------------------------- دبابة (طراز أبرامز)
static func _tank(v: Node3D, t: Node3D, d: Dictionary, team_col: Color) -> void:
	var camo := M.camo("desert")
	var steel := M.solid(Color(0.16, 0.16, 0.15), 0.55, 0.5)
	var rub := M.solid(Color(0.06, 0.06, 0.055), 0.95)
	var hub := M.solid(Color(0.26, 0.26, 0.24), 0.5, 0.5)
	var dark := M.solid(Color(0.05, 0.05, 0.05), 0.6)
	_tracks(v, d, 1.5, 7.2, 7, 0.38, steel, rub, hub)
	for sx in [-1.0, 1.0]:
		P.box(v, Vector3(0.14, 0.9, 5.6), Vector3(sx * 1.95, 1.0, 0.5), camo)
		P.box(v, Vector3(0.3, 0.1, 6.8), Vector3(sx * 1.78, 1.5, 0.0), camo)
	P.box(v, Vector3(3.0, 0.85, 6.9), Vector3(0, 1.1, 0.0), camo)
	P.box(v, Vector3(3.0, 0.14, 2.1), Vector3(0, 1.45, -3.35), camo, Vector3(-24, 0, 0))
	P.box(v, Vector3(2.9, 0.35, 2.4), Vector3(0, 1.65, 2.5), steel)
	for i in 6:
		P.box(v, Vector3(2.6, 0.03, 0.06), Vector3(0, 1.84, 1.6 + i * 0.35), dark)
	P.box(v, Vector3(0.5, 0.35, 0.3), Vector3(0, 1.45, -3.9), dark)
	for sx in [-1.0, 1.0]:
		P.sph(v, 0.09, Vector3(sx * 1.2, 1.5, -4.28), M.emissive(Color(1, 0.95, 0.8), 1.4))
	t.position = Vector3(0, 1.95, 0.3)
	P.box(t, Vector3(2.5, 0.75, 3.2), Vector3(0, 0.35, 0.1), camo)
	for sx in [-1.0, 1.0]:
		P.box(t, Vector3(0.9, 0.7, 1.8), Vector3(sx * 0.95, 0.35, -1.4), camo, Vector3(0, sx * -28, 0))
	P.box(t, Vector3(2.4, 0.62, 1.2), Vector3(0, 0.42, 2.0), camo)
	P.cyl(t, 0.32, 0.2, Vector3(0.75, 0.78, 0.5), steel)
	P.cyl(t, 0.3, 0.14, Vector3(-0.75, 0.78, 0.9), steel)
	P.box(t, Vector3(0.1, 0.1, 0.5), Vector3(0.75, 1.0, 0.3), dark)
	P.cyl(t, 0.025, 1.6, Vector3(-1.0, 1.3, 2.2), steel)
	for sx in [-1.0, 1.0]:
		for i in 3:
			P.cyl(t, 0.07, 0.2, Vector3(sx * 1.3, 0.55, -0.9 + i * 0.22), dark, Vector3(0, 0, 90))
	var gun := P.pivot(t, Vector3(0, 0.4, -2.0), "Gun")
	d["gun"] = gun
	P.box(gun, Vector3(1.1, 0.75, 0.55), Vector3(0, 0, -0.1), camo)
	P.cyl(gun, 0.13, 4.5, Vector3(0, 0, -2.5), steel, Vector3(90, 0, 0))
	P.cyl(gun, 0.19, 0.5, Vector3(0, 0, -1.0), steel, Vector3(90, 0, 0))
	P.cyl(gun, 0.17, 0.4, Vector3(0, 0, -4.6), steel, Vector3(90, 0, 0))
	d["tip"] = P.pivot(gun, Vector3(0, 0, -4.85), "Tip")
	P.box(t, Vector3(0.02, 0.3, 0.5), Vector3(-1.26, 0.6, 1.8), M.solid(team_col, 0.6))


# ---------------------------------------------------------------- ناقلة جنود (طراز برادلي)
static func _apc(v: Node3D, t: Node3D, d: Dictionary, team_col: Color) -> void:
	var camo := M.camo("desert")
	var steel := M.solid(Color(0.16, 0.16, 0.15), 0.55, 0.5)
	var rub := M.solid(Color(0.06, 0.06, 0.055), 0.95)
	var hub := M.solid(Color(0.26, 0.26, 0.24), 0.5, 0.5)
	var dark := M.solid(Color(0.05, 0.05, 0.05), 0.6)
	_tracks(v, d, 1.35, 5.6, 6, 0.36, steel, rub, hub)
	P.box(v, Vector3(2.9, 1.2, 5.4), Vector3(0, 1.3, 0.1), camo)
	P.box(v, Vector3(2.9, 0.8, 1.6), Vector3(0, 1.45, -2.9), camo, Vector3(-30, 0, 0))
	P.box(v, Vector3(2.8, 0.6, 5.0), Vector3(0, 2.2, 0.4), camo)
	for sx in [-1.0, 1.0]:
		P.box(v, Vector3(0.12, 0.9, 5.0), Vector3(sx * 1.55, 1.25, 0.2), camo)
		P.box(v, Vector3(0.06, 0.18, 0.7), Vector3(sx * 1.46, 2.25, -1.0), M.glass())
	P.box(v, Vector3(2.4, 1.1, 0.1), Vector3(0, 1.4, 2.82), dark)
	P.box(v, Vector3(0.9, 0.5, 0.3), Vector3(-0.7, 1.35, -3.5), dark)
	for sx in [-1.0, 1.0]:
		P.sph(v, 0.09, Vector3(sx * 1.0, 1.45, -3.55), M.emissive(Color(1, 0.95, 0.8), 1.4))
	t.position = Vector3(0, 2.75, -0.2)
	P.box(t, Vector3(1.5, 0.75, 1.9), Vector3(0, 0.25, 0), camo)
	P.box(t, Vector3(0.5, 0.5, 1.2), Vector3(1.0, 0.25, 0.0), camo)
	P.box(t, Vector3(0.5, 0.5, 1.0), Vector3(-1.0, 0.25, 0.0), steel)
	P.box(t, Vector3(0.45, 0.35, 0.6), Vector3(-1.0, 0.25, -0.9), dark)
	P.cyl(t, 0.055, 2.3, Vector3(0, 0.3, -1.9), steel, Vector3(90, 0, 0))
	P.cyl(t, 0.09, 0.4, Vector3(0, 0.3, -0.9), steel, Vector3(90, 0, 0))
	P.cyl(t, 0.2, 0.15, Vector3(0.4, 0.7, 0.5), steel)
	d["tip"] = P.pivot(t, Vector3(0, 0.3, -3.1), "Tip")
	P.cyl(v, 0.02, 1.6, Vector3(1.2, 3.6, 2.3), steel)
	P.box(v, Vector3(0.02, 0.25, 0.4), Vector3(1.2, 4.3, 2.4), M.solid(team_col, 0.6))


# ---------------------------------------------------------------- مركبة مدرعة (جيب)
static func _jeep(v: Node3D, t: Node3D, d: Dictionary, team_col: Color) -> void:
	var camo := M.camo("desert")
	var steel := M.solid(Color(0.16, 0.16, 0.15), 0.55, 0.5)
	var rub := M.solid(Color(0.05, 0.05, 0.05), 0.95)
	var hub := M.solid(Color(0.3, 0.3, 0.28), 0.5, 0.6)
	var dark := M.solid(Color(0.05, 0.05, 0.05), 0.6)
	P.box(v, Vector3(2.3, 0.85, 4.6), Vector3(0, 0.95, 0), camo)
	P.box(v, Vector3(2.0, 0.55, 1.3), Vector3(0, 1.3, -1.9), camo, Vector3(-8, 0, 0))
	P.box(v, Vector3(2.2, 0.95, 2.4), Vector3(0, 1.85, 0.35), camo)
	P.box(v, Vector3(1.9, 0.62, 0.08), Vector3(0, 1.98, -0.9), M.glass(), Vector3(-22, 0, 0))
	for sx in [-1.0, 1.0]:
		P.box(v, Vector3(0.06, 0.5, 0.9), Vector3(sx * 1.12, 2.0, -0.2), M.glass())
		P.box(v, Vector3(0.06, 0.5, 0.9), Vector3(sx * 1.12, 2.0, 0.9), M.glass())
		P.sph(v, 0.1, Vector3(sx * 0.8, 1.2, -2.6), M.emissive(Color(1, 0.95, 0.8), 1.4))
		P.box(v, Vector3(0.12, 0.2, 0.9), Vector3(sx * 1.2, 0.55, 0.0), camo)
		for z in [-1.5, 1.5]:
			var w := P.pivot(v, Vector3(sx * 1.12, 0.5, z))
			P.cyl(w, 0.5, 0.42, Vector3.ZERO, rub, Vector3(0, 0, 90))
			P.cyl(w, 0.27, 0.46, Vector3.ZERO, hub, Vector3(0, 0, 90))
			d.wheels.append(w)
	P.box(v, Vector3(1.4, 0.3, 0.06), Vector3(0, 1.1, -2.6), dark)
	P.box(v, Vector3(2.4, 0.2, 0.22), Vector3(0, 0.62, -2.5), steel)
	P.cyl(v, 0.42, 0.25, Vector3(0, 1.4, 2.4), rub, Vector3(90, 0, 0))
	P.cyl(v, 0.025, 1.8, Vector3(-1.0, 3.2, 1.2), steel)
	P.box(v, Vector3(0.02, 0.25, 0.4), Vector3(-1.0, 4.0, 1.3), M.solid(team_col, 0.6))
	t.position = Vector3(0, 2.4, 0.35)
	P.cyl(t, 0.4, 0.12, Vector3.ZERO, steel)
	P.box(t, Vector3(0.9, 0.7, 0.08), Vector3(0, 0.45, -0.35), steel)
	P.box(t, Vector3(0.12, 0.14, 0.6), Vector3(0, 0.35, -0.55), dark)
	P.cyl(t, 0.03, 0.9, Vector3(0, 0.37, -1.0), steel, Vector3(90, 0, 0))
	d["tip"] = P.pivot(t, Vector3(0, 0.37, -1.5), "Tip")


# ---------------------------------------------------------------- مروحية هجومية
static func _heli(v: Node3D, d: Dictionary, team_col: Color) -> void:
	var body := P.pivot(v, Vector3.ZERO, "Body")
	d["body"] = body
	var hull := M.solid(Color(0.2, 0.23, 0.22), 0.55, 0.3)
	var hull2 := M.solid(Color(0.15, 0.17, 0.16), 0.6, 0.3)
	var dark := M.solid(Color(0.05, 0.05, 0.05), 0.6)
	var steel := M.solid(Color(0.3, 0.3, 0.3), 0.4, 0.6)
	P.box(body, Vector3(1.25, 1.3, 4.0), Vector3(0, 1.9, 0.3), hull)
	P.box(body, Vector3(1.0, 1.0, 1.9), Vector3(0, 1.7, -2.5), hull2, Vector3(8, 0, 0))
	P.cyl(body, 0.05, 1.0, Vector3(0, 1.55, -3.6), hull2, Vector3(90, 0, 0), 0.5)
	P.box(body, Vector3(0.82, 0.55, 2.4), Vector3(0, 2.7, -1.5), M.glass(), Vector3(-5, 0, 0))
	P.box(body, Vector3(0.9, 0.08, 2.5), Vector3(0, 2.45, -1.5), dark)
	P.sph(body, 0.3, Vector3(0, 1.1, -3.0), dark)
	P.cyl(body, 0.04, 0.9, Vector3(0, 1.05, -3.55), steel, Vector3(90, 0, 0))
	for sx in [-1.0, 1.0]:
		P.box(body, Vector3(0.55, 0.6, 1.7), Vector3(sx * 0.62, 2.7, 1.3), hull)
		P.cyl(body, 0.16, 0.5, Vector3(sx * 0.62, 2.7, 2.2), dark, Vector3(90, 0, 0))
	P.box(body, Vector3(0.5, 0.55, 4.8), Vector3(0, 2.25, 4.4), hull)
	P.box(body, Vector3(0.1, 1.6, 1.1), Vector3(0, 3.0, 6.4), hull, Vector3(18, 0, 0))
	P.box(body, Vector3(2.4, 0.08, 0.65), Vector3(0, 2.45, 5.8), hull)
	P.box(body, Vector3(0.02, 0.5, 0.7), Vector3(0.06, 3.1, 6.5), M.solid(team_col, 0.6))
	P.box(body, Vector3(4.2, 0.1, 0.8), Vector3(0, 1.85, 0.4), hull2)
	for sx in [-1.0, 1.0]:
		for off in [1.05, 1.75]:
			P.cyl(body, 0.17, 1.3, Vector3(sx * (off + 0.35), 1.65, 0.3), M.solid(Color(0.25, 0.27, 0.24), 0.6, 0.3), Vector3(90, 0, 0))
			P.cyl(body, 0.03, 0.3, Vector3(sx * (off + 0.35), 1.65, -0.5), dark, Vector3(90, 0, 0))
	P.cyl(body, 0.06, 0.8, Vector3(0, 1.3, -2.1), steel, Vector3(10, 0, 0))
	P.cyl(body, 0.06, 0.8, Vector3(-0.9, 1.0, 1.3), steel)
	P.cyl(body, 0.06, 0.8, Vector3(0.9, 1.0, 1.3), steel)
	for p in [Vector3(0, 0.35, -2.2), Vector3(-0.9, 0.35, 1.3), Vector3(0.9, 0.35, 1.3)]:
		var w := P.pivot(body, p)
		P.cyl(w, 0.25, 0.14, Vector3.ZERO, M.solid(Color(0.05, 0.05, 0.05), 0.95), Vector3(0, 0, 90))
		d.wheels.append(w)
	P.cyl(body, 0.12, 0.5, Vector3(0, 3.1, 0.2), steel)
	var rotor := P.pivot(body, Vector3(0, 3.38, 0.2), "Rotor")
	d["rotor"] = rotor
	P.cyl(rotor, 0.2, 0.15, Vector3.ZERO, steel)
	P.box(rotor, Vector3(7.4, 0.04, 0.3), Vector3.ZERO, dark)
	P.box(rotor, Vector3(0.3, 0.04, 7.4), Vector3.ZERO, dark)
	var tail := P.pivot(body, Vector3(0.2, 3.1, 6.45), "Tail")
	d["tail"] = tail
	P.box(tail, Vector3(0.04, 1.3, 0.12), Vector3.ZERO, dark)
	P.box(tail, Vector3(0.04, 0.12, 1.3), Vector3.ZERO, dark)
	d["tip"] = P.pivot(body, Vector3(0, 1.05, -3.9), "Tip")


# ---------------------------------------------------------------- طائرة مقاتلة (طراز F-16)
static func _jet(v: Node3D, d: Dictionary, team_col: Color) -> void:
	var hull := M.solid(Color(0.55, 0.58, 0.6), 0.4, 0.4)
	var hull2 := M.solid(Color(0.42, 0.45, 0.48), 0.45, 0.4)
	var dark := M.solid(Color(0.06, 0.06, 0.07), 0.5, 0.4)
	var white := M.solid(Color(0.85, 0.85, 0.82), 0.5, 0.2)
	P.cyl(v, 0.06, 3.2, Vector3(0, 1.0, -5.3), hull, Vector3(90, 0, 0), 0.55)
	P.cyl(v, 0.55, 6.6, Vector3(0, 1.0, -0.4), hull, Vector3(90, 0, 0), 0.62)
	P.cyl(v, 0.62, 2.6, Vector3(0, 1.0, 3.2), hull2, Vector3(90, 0, 0), 0.44)
	P.cyl(v, 0.44, 0.9, Vector3(0, 1.0, 4.9), dark, Vector3(90, 0, 0), 0.38)
	var burner := P.cyl(v, 0.36, 2.6, Vector3(0, 1.0, 6.5), M.emissive(Color(1.0, 0.55, 0.15), 2.5), Vector3(90, 0, 0), 0.02)
	d["burner"] = burner
	P.box(v, Vector3(0.95, 0.55, 1.8), Vector3(0, 0.5, -2.4), dark)
	P.box(v, Vector3(1.1, 0.12, 1.9), Vector3(0, 0.78, -2.4), hull2)
	P.sph(v, 0.5, Vector3(0, 1.5, -1.9), M.glass(), Vector3(0.9, 0.7, 2.6))
	P.box(v, Vector3(0.9, 0.12, 2.6), Vector3(0, 1.28, -1.9), dark)
	for sx in [-1.0, 1.0]:
		P.box(v, Vector3(3.8, 0.1, 2.9), Vector3(sx * 2.3, 0.95, 1.6), hull2, Vector3(0, -sx * 26, 0))
		P.cyl(v, 0.07, 2.6, Vector3(sx * 4.35, 0.95, 2.4), white, Vector3(90, 0, 0), 0.07)
		for off in [2.0, 3.1]:
			P.cyl(v, 0.1, 3.0, Vector3(sx * off, 0.62, 1.0), white, Vector3(90, 0, 0), 0.1)
			P.cyl(v, 0.01, 0.5, Vector3(sx * off, 0.62, -0.7), M.solid(Color(0.7, 0.15, 0.1)), Vector3(90, 0, 0), 0.1)
		P.box(v, Vector3(1.9, 0.08, 1.4), Vector3(sx * 1.4, 1.0, 5.0), hull2, Vector3(0, -sx * 22, 0))
		P.box(v, Vector3(0.4, 0.3, 0.8), Vector3(sx * 0.65, 0.65, 1.8), hull2)
	P.box(v, Vector3(0.12, 1.9, 2.0), Vector3(0, 2.15, 4.4), hull, Vector3(18, 0, 0))
	P.box(v, Vector3(0.14, 0.7, 0.9), Vector3(0, 2.7, 4.9), M.solid(team_col, 0.6), Vector3(18, 0, 0))
	P.cyl(v, 0.3, 2.4, Vector3(0, 0.45, 0.6), hull2, Vector3(90, 0, 0), 0.3)
	d["tip"] = P.pivot(v, Vector3(0, 1.0, -6.9), "Tip")
