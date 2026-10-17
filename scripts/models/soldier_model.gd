extends RefCounted
## جندي مفصّل: أطراف منحنية، خوذة بسكك ونظارة، سترة تكتيكية، حقيبة حسب الفئة،
## وذراعان بحل IK يمسكان السلاح من المقبض والمقدمة بشكل صحيح.

const P := preload("res://scripts/models/parts.gd")
const M := preload("res://scripts/models/mats.gd")
const W := preload("res://scripts/models/weapon_models.gd")

const L1 := 0.35
const L2 := 0.34


static func _down_basis(d: Vector3, pole: Vector3) -> Basis:
	var y := -d.normalized()
	var x := pole.cross(y)
	if x.length() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


static func _solve_arm(arm: Node3D, fore: Node3D, s: Vector3, t: Vector3, pole: Vector3) -> void:
	var to := t - s
	var dist := clampf(to.length(), 0.05, L1 + L2 - 0.002)
	var dir := to.normalized()
	var a := (L1 * L1 - L2 * L2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(L1 * L1 - a * a, 0.0))
	var pp := (pole - dir * pole.dot(dir)).normalized()
	var elbow := s + dir * a + pp * h
	var wrist := s + dir * dist
	arm.position = s
	arm.basis = _down_basis(elbow - s, pp)
	var fb := _down_basis(wrist - elbow, pp)
	fore.basis = arm.basis.inverse() * fb


static func build(parent: Node3D, team_col: Color, weapon_key: String, cls := "assault", look := {}) -> Dictionary:
	var lk := Cfg.sanitize_look(look)
	var uni := M.camo(lk.camo, 1.6)
	var vest := M.solid(Cfg.VESTS[lk.vest], 0.9)
	var vest2 := M.solid((Cfg.VESTS[lk.vest] as Color).darkened(0.3), 0.9)
	var skin := M.solid(Cfg.SKINS[lk.skin], 0.7)
	var dark := M.solid(Color(0.08, 0.08, 0.08), 0.6)
	var boot := M.solid(Color(0.14, 0.1, 0.07), 0.8)
	var helmet := M.solid(Cfg.HELMETS[lk.helmet], 0.6, 0.1)
	var band := M.solid(team_col, 0.6)
	var mask := M.solid(Color(0.17, 0.16, 0.12), 0.9)
	var root := P.pivot(parent, Vector3.ZERO, "Model")
	var d := {"root": root}

	# ---- الساقان ----
	for side in [-1.0, 1.0]:
		var leg := P.pivot(root, Vector3(side * 0.105, 0.93, 0.0))
		P.caps(leg, 0.088, 0.5, Vector3(0, -0.23, 0), uni)
		var knee := P.pivot(leg, Vector3(0, -0.45, 0))
		P.caps(knee, 0.072, 0.46, Vector3(0, -0.21, 0), uni)
		P.sph(knee, 0.085, Vector3(0, 0.01, -0.06), vest2, Vector3(1.0, 1.0, 0.55))
		P.box(knee, Vector3(0.12, 0.12, 0.28), Vector3(0, -0.44, -0.05), boot)
		P.box(knee, Vector3(0.125, 0.035, 0.3), Vector3(0, -0.5, -0.05), dark)
		P.cyl(knee, 0.075, 0.1, Vector3(0, -0.39, 0.0), boot)
		d["leg_l" if side < 0.0 else "leg_r"] = leg
		d["knee_l" if side < 0.0 else "knee_r"] = knee
		if side > 0.0:
			P.box(leg, Vector3(0.05, 0.22, 0.14), Vector3(0.1, -0.2, 0.0), vest2)

	# ---- الحوض والحزام ----
	P.caps(root, 0.12, 0.38, Vector3(0, 0.98, 0), uni, Vector3(0, 0, 90), Vector3(1, 1, 0.85))
	P.box(root, Vector3(0.42, 0.07, 0.27), Vector3(0, 1.04, 0), dark)
	P.box(root, Vector3(0.07, 0.1, 0.06), Vector3(0.0, 1.02, -0.15), vest2)

	# ---- الجذع ----
	var torso := P.pivot(root, Vector3(0, 1.0, 0), "Torso")
	d["torso"] = torso
	P.caps(torso, 0.14, 0.36, Vector3(0, 0.14, 0), uni, Vector3.ZERO, Vector3(1.05, 1, 0.8))
	P.caps(torso, 0.15, 0.56, Vector3(0, 0.44, 0), uni, Vector3(0, 0, 90), Vector3(1, 1, 0.85))
	P.box(torso, Vector3(0.5, 0.36, 0.3), Vector3(0, 0.42, 0), vest)
	P.box(torso, Vector3(0.3, 0.26, 0.04), Vector3(0, 0.46, -0.17), vest2)
	for px in [-0.15, -0.05, 0.05, 0.15]:
		P.box(torso, Vector3(0.075, 0.12, 0.07), Vector3(px, 0.28, -0.17), dark)
	P.box(torso, Vector3(0.14, 0.1, 0.06), Vector3(-0.2, 0.46, -0.16), vest2)
	for sx in [-1.0, 1.0]:
		P.box(torso, Vector3(0.09, 0.3, 0.3), Vector3(sx * 0.17, 0.62, 0.0), vest)
	P.cyl(torso, 0.06, 0.12, Vector3(0, 0.7, 0), skin)
	P.box(torso, Vector3(0.22, 0.06, 0.24), Vector3(0, 0.66, 0.0), vest)

	# ---- حقيبة حسب الفئة ----
	match cls:
		"medic":
			P.box(torso, Vector3(0.38, 0.46, 0.2), Vector3(0, 0.42, 0.25), M.solid(Color(0.82, 0.82, 0.78), 0.8))
			P.box(torso, Vector3(0.18, 0.05, 0.02), Vector3(0, 0.45, 0.355), M.solid(Color(0.8, 0.1, 0.08)))
			P.box(torso, Vector3(0.05, 0.18, 0.02), Vector3(0, 0.45, 0.355), M.solid(Color(0.8, 0.1, 0.08)))
		"engineer":
			P.box(torso, Vector3(0.4, 0.44, 0.24), Vector3(0, 0.42, 0.26), M.solid(Color(0.3, 0.27, 0.16), 0.9))
			P.cyl(torso, 0.06, 0.4, Vector3(0, 0.7, 0.28), M.solid(Color(0.35, 0.3, 0.12), 0.8), Vector3(0, 0, 90))
			P.cyl(torso, 0.02, 0.4, Vector3(0.15, 0.4, 0.4), M.solid(Color(0.5, 0.5, 0.5), 0.4, 0.7), Vector3(15, 0, 0))
		"sniper":
			P.box(torso, Vector3(0.32, 0.4, 0.16), Vector3(0, 0.42, 0.23), vest2)
			for i in 6:
				P.box(torso, Vector3(0.05, 0.22 + (i % 3) * 0.06, 0.02), Vector3(-0.2 + i * 0.08, 0.2, 0.2), M.solid(Color(0.2, 0.3, 0.14), 0.95), Vector3(0, 0, (i - 3) * 6))
		_:
			P.box(torso, Vector3(0.34, 0.4, 0.17), Vector3(0, 0.42, 0.23), vest)
			P.cyl(torso, 0.025, 0.7, Vector3(0.14, 0.9, 0.28), dark)

	# ---- الرأس ----
	var head := P.pivot(torso, Vector3(0, 0.8, 0), "Head")
	d["head"] = head
	P.sph(head, 0.105, Vector3(0, 0.05, 0), skin, Vector3(0.95, 1.12, 1.0))
	P.box(head, Vector3(0.17, 0.08, 0.05), Vector3(0, -0.01, -0.09), mask)
	P.box(head, Vector3(0.2, 0.045, 0.05), Vector3(0, 0.06, -0.095), dark)
	for sx in [-1.0, 1.0]:
		P.box(head, Vector3(0.075, 0.035, 0.02), Vector3(sx * 0.045, 0.06, -0.12), M.emissive(Color(0.2, 0.5, 0.7), 0.6))
		P.cyl(head, 0.045, 0.04, Vector3(sx * 0.11, 0.04, 0.0), dark, Vector3(0, 0, 90))
	if cls == "sniper":
		P.cyl(head, 0.2, 0.015, Vector3(0, 0.15, 0), M.solid(Color(0.3, 0.33, 0.2), 0.95))
		P.sph(head, 0.115, Vector3(0, 0.15, 0), M.solid(Color(0.3, 0.33, 0.2), 0.95), Vector3(1, 0.8, 1), true)
	else:
		P.sph(head, 0.15, Vector3(0, 0.1, 0.0), helmet, Vector3(1.0, 1.0, 1.1), true)
		P.cyl(head, 0.152, 0.025, Vector3(0, 0.1, 0.0), helmet, Vector3.ZERO)
		P.box(head, Vector3(0.05, 0.06, 0.06), Vector3(0, 0.18, -0.1), dark)
		P.box(head, Vector3(0.025, 0.025, 0.2), Vector3(0.13, 0.15, 0.0), dark)
		P.box(head, Vector3(0.1, 0.02, 0.01), Vector3(0, 0.12, -0.17), band)
		if cls == "medic":
			P.box(head, Vector3(0.01, 0.06, 0.02), Vector3(0.152, 0.16, 0.0), M.solid(Color(0.85, 0.1, 0.08)))
			P.box(head, Vector3(0.01, 0.02, 0.06), Vector3(0.152, 0.16, 0.0), M.solid(Color(0.85, 0.1, 0.08)))

	# ---- السلاح ----
	var mount := P.pivot(torso, Vector3(0.16, 0.6, -0.2), "Weapon")
	d["weapon"] = mount
	var gun := W.build(mount, weapon_key, lk.finish)
	d["muzzle"] = gun.get_node_or_null("Muzzle")
	var grip_r: Vector3 = mount.position + (gun.get_meta("grip_r") as Vector3)
	var grip_l: Vector3 = mount.position + (gun.get_meta("grip_l") as Vector3)

	# ---- الذراعان (IK) ----
	for side in [-1.0, 1.0]:
		var arm := P.pivot(torso, Vector3(side * 0.27, 0.6, 0))
		P.sph(arm, 0.085, Vector3.ZERO, vest)
		P.caps(arm, 0.062, L1 + 0.04, Vector3(0, -L1 * 0.5, 0), uni)
		var fore := P.pivot(arm, Vector3(0, -L1, 0))
		P.caps(fore, 0.055, L2 - 0.04, Vector3(0, -(L2 - 0.04) * 0.5, 0), uni)
		P.sph(fore, 0.06, Vector3(0, -L2 + 0.02, 0), dark, Vector3(1, 1.2, 1))
		P.box(fore, Vector3(0.09, 0.06, 0.09), Vector3(0, 0.0, 0.0), vest2)
		if side > 0.0:
			P.box(arm, Vector3(0.13, 0.05, 0.13), Vector3(0, -0.14, 0), band)
		var tgt: Vector3 = grip_r if side > 0.0 else grip_l
		_solve_arm(arm, fore, Vector3(side * 0.27, 0.6, 0), tgt, Vector3(side * 0.6, -1.0, 0.25))
		d["arm_l" if side < 0.0 else "arm_r"] = arm
	return d
