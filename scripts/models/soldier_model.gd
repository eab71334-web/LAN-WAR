extends RefCounted
## جندي بشري مفصّل: خوذة، نظارة، سترة، حقيبة، قفازات، أحذية، سلاح بيدين.

const P := preload("res://scripts/models/parts.gd")
const M := preload("res://scripts/models/mats.gd")
const W := preload("res://scripts/models/weapon_models.gd")


static func build(parent: Node3D, team_col: Color, weapon_key: String) -> Dictionary:
	var uni := M.camo("digital")
	var vest := M.solid(Color(0.27, 0.25, 0.19), 0.9)
	var skin := M.solid(Color(0.76, 0.57, 0.44), 0.7)
	var dark := M.solid(Color(0.09, 0.09, 0.09), 0.6)
	var boot := M.solid(Color(0.15, 0.11, 0.08), 0.8)
	var helmet := M.solid(Color(0.29, 0.33, 0.24), 0.65)
	var band := M.solid(team_col, 0.6)
	var root := P.pivot(parent, Vector3.ZERO, "Model")
	var d := {"root": root}

	for side in [-1.0, 1.0]:
		var leg := P.pivot(root, Vector3(side * 0.12, 0.92, 0.0))
		P.box(leg, Vector3(0.17, 0.46, 0.2), Vector3(0, -0.22, 0), uni)
		var knee := P.pivot(leg, Vector3(0, -0.45, 0))
		P.box(knee, Vector3(0.15, 0.4, 0.17), Vector3(0, -0.2, 0), uni)
		P.box(knee, Vector3(0.16, 0.08, 0.06), Vector3(0, -0.03, -0.1), vest)
		P.box(knee, Vector3(0.17, 0.12, 0.3), Vector3(0, -0.42, -0.05), boot)
		P.box(knee, Vector3(0.15, 0.05, 0.1), Vector3(0, -0.47, -0.2), dark)
		d["leg_l" if side < 0.0 else "leg_r"] = leg

	P.box(root, Vector3(0.36, 0.14, 0.22), Vector3(0, 0.96, 0), uni)
	var torso := P.pivot(root, Vector3(0, 0.95, 0), "Torso")
	d["torso"] = torso
	P.box(torso, Vector3(0.36, 0.2, 0.22), Vector3(0, 0.1, 0), uni)
	P.box(torso, Vector3(0.44, 0.42, 0.26), Vector3(0, 0.4, 0), uni)
	P.box(torso, Vector3(0.48, 0.36, 0.3), Vector3(0, 0.42, 0), vest)
	for px in [-0.12, 0.0, 0.12]:
		P.box(torso, Vector3(0.09, 0.11, 0.06), Vector3(px, 0.34, -0.17), dark)
	P.box(torso, Vector3(0.34, 0.42, 0.17), Vector3(0, 0.42, 0.23), vest)
	P.cyl(torso, 0.05, 0.3, Vector3(0.12, 0.72, 0.25), dark, Vector3(0, 0, 90))
	P.box(torso, Vector3(0.18, 0.05, 0.2), Vector3(0, 0.66, 0), vest)

	var head := P.pivot(torso, Vector3(0, 0.74, 0), "Head")
	d["head"] = head
	P.sph(head, 0.115, Vector3(0, 0.1, 0), skin)
	P.sph(head, 0.15, Vector3(0, 0.12, 0), helmet, Vector3(1.0, 1.0, 1.12), true)
	P.box(head, Vector3(0.22, 0.045, 0.06), Vector3(0, 0.12, -0.115), dark)
	P.box(head, Vector3(0.18, 0.1, 0.05), Vector3(0, 0.02, -0.1), dark)
	P.box(head, Vector3(0.04, 0.05, 0.05), Vector3(0, 0.25, -0.1), dark)
	P.box(head, Vector3(0.03, 0.1, 0.06), Vector3(0.12, 0.07, 0.0), dark)

	for side in [-1.0, 1.0]:
		var arm := P.pivot(torso, Vector3(side * 0.29, 0.6, 0))
		P.box(arm, Vector3(0.12, 0.3, 0.13), Vector3(0, -0.15, 0), uni)
		P.sph(arm, 0.075, Vector3(0, 0.0, 0), vest)
		var fore := P.pivot(arm, Vector3(0, -0.3, 0))
		P.box(fore, Vector3(0.11, 0.26, 0.12), Vector3(0, -0.13, 0), uni)
		P.box(fore, Vector3(0.1, 0.1, 0.11), Vector3(0, -0.3, 0), dark)
		if side > 0.0:
			P.box(arm, Vector3(0.135, 0.05, 0.145), Vector3(0, -0.12, 0), band)
		d["arm_l" if side < 0.0 else "arm_r"] = arm
		d["fore_l" if side < 0.0 else "fore_r"] = fore

	d["arm_r"].rotation_degrees = Vector3(72, 0, -16)
	d["fore_r"].rotation_degrees = Vector3(28, 0, 0)
	d["arm_l"].rotation_degrees = Vector3(80, 0, 24)
	d["fore_l"].rotation_degrees = Vector3(30, 0, 0)

	var mount := P.pivot(torso, Vector3(0.1, 0.52, -0.36), "Weapon")
	d["weapon"] = mount
	var gun := W.build(mount, weapon_key)
	d["muzzle"] = gun.get_node_or_null("Muzzle")
	return d
