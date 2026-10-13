extends RefCounted
## مؤثرات بصرية بسيطة (تتبع الرصاص والانفجارات)

static func tracer(tree: SceneTree, a: Vector3, b: Vector3, width := 0.05, color := Color(1.0, 0.85, 0.3)) -> void:
	var dist := a.distance_to(b)
	if dist < 0.1 or tree.current_scene == null:
		return
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width, dist)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	tree.current_scene.add_child(m)
	m.global_position = (a + b) * 0.5
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT
	m.look_at(b, up)
	tree.create_timer(0.07).timeout.connect(m.queue_free)


static func explosion(tree: SceneTree, pos: Vector3, radius: float) -> void:
	if tree.current_scene == null:
		return
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.1, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	tree.current_scene.add_child(m)
	m.global_position = pos
	m.scale = Vector3.ONE * 0.5
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * maxf(radius * 0.6, 1.0), 0.35)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(m.queue_free)
