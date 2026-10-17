extends RefCounted
## نماذج الأسلحة (الاتجاه للأمام = -Z). كل سلاح فيه عقدة Muzzle.

const P := preload("res://scripts/models/parts.gd")
const M := preload("res://scripts/models/mats.gd")


static func build(parent: Node3D, key: String, finish := "black") -> Node3D:
	var w := P.pivot(parent, Vector3.ZERO, "Gun")
	var fin: Dictionary = Cfg.FINISHES.get(finish, Cfg.FINISHES["black"])
	var dark := M.solid(fin.dark, 0.45, 0.5)
	var metal := M.solid(Color(0.22, 0.22, 0.24), 0.35, 0.7)
	var tan := M.solid(fin.furn, 0.8)
	var grip := M.solid(Color(0.12, 0.11, 0.1), 0.9)
	match key:
		"sniper":
			P.box(w, Vector3(0.07, 0.11, 0.6), Vector3(0, 0, 0), dark)
			P.box(w, Vector3(0.06, 0.13, 0.4), Vector3(0, -0.02, 0.45), tan, Vector3(-6, 0, 0))
			P.box(w, Vector3(0.05, 0.07, 0.35), Vector3(0, 0.0, -0.45), tan)
			P.cyl(w, 0.014, 0.75, Vector3(0, 0.01, -0.85), metal, Vector3(90, 0, 0))
			P.cyl(w, 0.022, 0.12, Vector3(0, 0.01, -1.25), dark, Vector3(90, 0, 0))
			P.cyl(w, 0.032, 0.3, Vector3(0, 0.11, -0.02), dark, Vector3(90, 0, 0))
			P.cyl(w, 0.042, 0.04, Vector3(0, 0.11, -0.18), metal, Vector3(90, 0, 0))
			P.cyl(w, 0.042, 0.04, Vector3(0, 0.11, 0.14), metal, Vector3(90, 0, 0))
			for s in [-1.0, 1.0]:
				P.cyl(w, 0.008, 0.28, Vector3(s * 0.05, -0.1, -0.6), metal, Vector3(0, 0, s * 25))
			P.box(w, Vector3(0.04, 0.12, 0.05), Vector3(0, -0.1, 0.06), grip, Vector3(15, 0, 0))
			P.pivot(w, Vector3(0, 0.01, -1.32), "Muzzle")
		"lmg":
			P.box(w, Vector3(0.09, 0.13, 0.55), Vector3(0, 0, 0), dark)
			P.box(w, Vector3(0.07, 0.12, 0.35), Vector3(0, -0.02, 0.42), tan)
			P.cyl(w, 0.03, 0.45, Vector3(0, 0.01, -0.5), metal, Vector3(90, 0, 0))
			P.cyl(w, 0.014, 0.35, Vector3(0, 0.01, -0.9), dark, Vector3(90, 0, 0))
			P.box(w, Vector3(0.13, 0.15, 0.2), Vector3(0.02, -0.15, 0.0), M.solid(Color(0.25, 0.28, 0.2), 0.7))
			P.box(w, Vector3(0.03, 0.03, 0.2), Vector3(0.1, -0.05, 0.0), metal, Vector3(0, 0, 20))
			P.box(w, Vector3(0.04, 0.05, 0.14), Vector3(0, 0.1, -0.05), dark)
			for s in [-1.0, 1.0]:
				P.cyl(w, 0.008, 0.3, Vector3(s * 0.06, -0.12, -0.75), metal, Vector3(0, 0, s * 22))
			P.box(w, Vector3(0.04, 0.12, 0.05), Vector3(0, -0.1, 0.12), grip, Vector3(15, 0, 0))
			P.pivot(w, Vector3(0, 0.01, -1.1), "Muzzle")
		"support":
			P.box(w, Vector3(0.06, 0.1, 0.4), Vector3(0, 0, -0.05), dark)
			P.box(w, Vector3(0.05, 0.1, 0.28), Vector3(0, -0.02, 0.25), tan, Vector3(-5, 0, 0))
			P.box(w, Vector3(0.06, 0.07, 0.3), Vector3(0, 0, -0.38), tan)
			P.cyl(w, 0.012, 0.2, Vector3(0, 0.01, -0.62), metal, Vector3(90, 0, 0))
			P.cyl(w, 0.032, 0.34, Vector3(0, -0.07, -0.38), metal, Vector3(90, 0, 0))
			P.cyl(w, 0.036, 0.04, Vector3(0, -0.07, -0.56), dark, Vector3(90, 0, 0))
			P.box(w, Vector3(0.04, 0.17, 0.07), Vector3(0, -0.13, -0.08), dark, Vector3(-10, 0, 0))
			P.box(w, Vector3(0.04, 0.05, 0.12), Vector3(0, 0.075, -0.05), dark)
			P.pivot(w, Vector3(0, 0.01, -0.74), "Muzzle")
		_:
			P.box(w, Vector3(0.06, 0.1, 0.4), Vector3(0, 0, -0.05), dark)
			P.box(w, Vector3(0.055, 0.075, 0.3), Vector3(0, 0, -0.4), tan)
			P.cyl(w, 0.012, 0.22, Vector3(0, 0.01, -0.66), metal, Vector3(90, 0, 0))
			P.cyl(w, 0.02, 0.07, Vector3(0, 0.01, -0.78), dark, Vector3(90, 0, 0))
			P.box(w, Vector3(0.05, 0.1, 0.3), Vector3(0, -0.02, 0.27), tan, Vector3(-6, 0, 0))
			P.box(w, Vector3(0.042, 0.19, 0.08), Vector3(0, -0.14, -0.1), dark, Vector3(-12, 0, 0))
			P.box(w, Vector3(0.04, 0.1, 0.05), Vector3(0, -0.1, 0.07), grip, Vector3(15, 0, 0))
			P.box(w, Vector3(0.03, 0.04, 0.1), Vector3(0, 0.075, -0.05), dark)
			P.box(w, Vector3(0.015, 0.05, 0.015), Vector3(0, 0.06, -0.58), dark)
			P.pivot(w, Vector3(0, 0.01, -0.82), "Muzzle")
	var g := {
		"sniper": [Vector3(0, -0.1, 0.06), Vector3(0, -0.05, -0.38)],
		"lmg": [Vector3(0, -0.1, 0.12), Vector3(0, -0.04, -0.42)],
		"support": [Vector3(0, -0.12, -0.08), Vector3(0, -0.05, -0.36)],
	}
	var gg: Array = g.get(key, [Vector3(0, -0.1, 0.07), Vector3(0, -0.04, -0.34)])
	w.set_meta("grip_r", gg[0])
	w.set_meta("grip_l", gg[1])
	return w
