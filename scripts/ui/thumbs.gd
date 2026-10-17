extends RefCounted
## صور مصغّرة ثلاثية الأبعاد (تُرسم مرة واحدة في SubViewport) للمركبات والجندي والأسلحة.

const VM := preload("res://scripts/models/vehicle_models.gd")
const SM := preload("res://scripts/models/soldier_model.gd")
const W := preload("res://scripts/models/weapon_models.gd")


static func _stage(holder: Node, px: Vector2i) -> Array:
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.size = px
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	holder.add_child(sv)
	var root := Node3D.new()
	sv.add_child(root)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.88)
	env.ambient_light_energy = 0.75
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.light_energy = 1.25
	root.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 140, 0)
	rim.light_color = Color(1.0, 0.72, 0.45)
	rim.light_energy = 0.9
	root.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 35.0
	root.add_child(cam)
	cam.current = true
	return [sv, root, cam]


static func vehicle(holder: Node, kind: String, team_col: Color) -> Texture2D:
	var a := _stage(holder, Vector2i(300, 240))
	var root: Node3D = a[1]
	var cam: Camera3D = a[2]
	var h := Node3D.new()
	root.add_child(h)
	var turret := Node3D.new()
	h.add_child(turret)
	VM.build(h, turret, kind, team_col)
	h.rotation.y = 2.5
	var sz: Vector3 = Cfg.VSTATS[kind].size
	var dist := maxf(sz.x, sz.z) * 1.9 + 3.0
	var mid := sz.y * 0.5
	cam.position = Vector3(dist * 0.35, mid + dist * 0.22, dist)
	cam.look_at(Vector3(0, mid * 0.9, 0))
	return (a[0] as SubViewport).get_texture()


static func soldier(holder: Node, team_col: Color, weapon: String, cls: String, look: Dictionary) -> Texture2D:
	var a := _stage(holder, Vector2i(300, 240))
	var root: Node3D = a[1]
	var cam: Camera3D = a[2]
	var h := Node3D.new()
	root.add_child(h)
	SM.build(h, team_col, weapon, cls, look)
	h.rotation.y = PI + 0.5
	cam.position = Vector3(0, 1.1, 4.3)
	cam.look_at(Vector3(0, 0.9, 0))
	return (a[0] as SubViewport).get_texture()


static func weapon(holder: Node, key: String, finish: String) -> Texture2D:
	var a := _stage(holder, Vector2i(300, 160))
	var root: Node3D = a[1]
	var cam: Camera3D = a[2]
	var h := Node3D.new()
	root.add_child(h)
	W.build(h, key, finish)
	h.rotation.y = PI * 0.5 + 0.35
	h.rotation.x = 0.1
	cam.position = Vector3(0, 0.15, 3.0)
	cam.look_at(Vector3(0, -0.02, -0.15))
	return (a[0] as SubViewport).get_texture()
