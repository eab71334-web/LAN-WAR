extends Control
## خريطة تكتيكية مصغّرة داخل لوحة MLRS: اضغط لتحديد الهدف.

signal picked(x: float, z: float)

const HALF := 300.0
var target := Vector2.ZERO
var has_target := false


func _ready() -> void:
	custom_minimum_size = Vector2(240, 240)


func _to_px(p: Vector2) -> Vector2:
	return (p / (HALF * 2.0) + Vector2(0.5, 0.5)) * size


func _gui_input(e: InputEvent) -> void:
	var pos := Vector2.ZERO
	var go := false
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position
		go = true
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pos = e.position
		go = true
	if go:
		var w := (pos / size - Vector2(0.5, 0.5)) * (HALF * 2.0)
		target = Vector2(clampf(w.x, -HALF, HALF), clampf(w.y, -HALF, HALF))
		has_target = true
		picked.emit(target.x, target.y)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.14, 0.08, 0.95))
	for i in range(1, 6):
		var f := float(i) / 6.0
		draw_line(Vector2(size.x * f, 0), Vector2(size.x * f, size.y), Color(1, 1, 1, 0.08))
		draw_line(Vector2(0, size.y * f), Vector2(size.x, size.y * f), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.52, 0.25), false, 2.0)
	var sc = get_tree().current_scene
	var my_team := -1
	if sc and "local_soldier" in sc and is_instance_valid(sc.local_soldier):
		my_team = sc.local_soldier.team
		var p := Vector2(sc.local_soldier.global_position.x, sc.local_soldier.global_position.z)
		draw_circle(_to_px(p), 5.0, Color.WHITE)
	for n in get_tree().get_nodes_in_group("soldier"):
		if n.team == my_team and n.alive:
			draw_circle(_to_px(Vector2(n.global_position.x, n.global_position.z)), 3.0, Cfg.TEAMS[n.team].color)
	for n in get_tree().get_nodes_in_group("vehicle"):
		if n.team == my_team:
			var q := _to_px(Vector2(n.global_position.x, n.global_position.z))
			draw_rect(Rect2(q - Vector2(4, 4), Vector2(8, 8)), Cfg.TEAMS[n.team].color)
	if has_target:
		var t := _to_px(target)
		draw_arc(t, 9.0, 0.0, TAU, 20, Color(1, 0.3, 0.2), 2.0)
		draw_line(t - Vector2(14, 0), t + Vector2(14, 0), Color(1, 0.3, 0.2), 2.0)
		draw_line(t - Vector2(0, 14), t + Vector2(0, 14), Color(1, 0.3, 0.2), 2.0)
	draw_string(get_theme_default_font(), Vector2(size.x * 0.5 - 4, 16), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.8))
