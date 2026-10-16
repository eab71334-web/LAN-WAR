extends RefCounted
## أدوات بناء النماذج من أشكال أساسية.

static func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot_deg
	parent.add_child(m)
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(parent, b, pos, mat, rot_deg)


## r = نصف قطر الطرف السفلي (-Y)، r_top للطرف العلوي (+Y). بعد تدوير X=90: السفلي يصير للأمام (-Z).
static func cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO, r_top := -1.0) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if r_top < 0.0 else r_top
	c.height = h
	c.radial_segments = 14
	c.rings = 1
	return _mi(parent, c, pos, mat, rot_deg)


static func sph(parent: Node3D, r: float, pos: Vector3, mat: Material, scl := Vector3.ONE, hemi := false) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r if hemi else r * 2.0
	s.is_hemisphere = hemi
	s.radial_segments = 14
	s.rings = 7
	var m := _mi(parent, s, pos, mat, Vector3.ZERO)
	m.scale = scl
	return m


static func pivot(parent: Node3D, pos := Vector3.ZERO, nm := "") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	if nm != "":
		n.name = nm
	parent.add_child(n)
	return n
