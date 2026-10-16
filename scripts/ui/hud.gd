extends Control
## واجهة اللعب: بوصلة، رادار، صحة، ذخيرة، لوحة المركبة، نتائج الفرق، لوحة راجمة MLRS.

const UI := preload("res://scripts/ui/ui.gd")
const MlrsMap := preload("res://scripts/ui/mlrs_map.gd")

var _hit_t := 0.0
var _flash_a := 0.0
var _last_hp := -1.0
var _msg := ""
var _msg_t := 0.0
var _panel: PanelContainer
var _sx: SpinBox
var _sz: SpinBox
var _st: SpinBox
var _sn: SpinBox
var _map: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_panel()


func hitmark() -> void:
	_hit_t = 0.18


func notice(t: String) -> void:
	_msg = t
	_msg_t = 3.0


func panel_open() -> bool:
	return _panel.visible


func _build_panel() -> void:
	_panel = PanelContainer.new()
	add_child(_panel)
	_panel.visible = false
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	var head := UI.label("MLRS Control — راجمة صواريخ", 22)
	head.modulate = UI.AMBER
	v.add_child(head)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	_map = MlrsMap.new()
	_map.picked.connect(_on_pick)
	h.add_child(_map)
	var f := VBoxContainer.new()
	h.add_child(f)
	_sx = _field(f, "X", -300, 300, 0)
	_sz = _field(f, "Y", -300, 300, 0)
	_st = _field(f, "Timer", 0, 60, 0)
	_sn = _field(f, "Rockets", 1, 12, 6)
	v.add_child(UI.button("LAUNCH!", _launch))
	v.add_child(UI.button("إغلاق", toggle_panel))


func _field(parent: Control, text: String, mn: float, mx: float, val: float) -> SpinBox:
	var row := HBoxContainer.new()
	var l := UI.label(text, 18)
	l.custom_minimum_size = Vector2(80, 0)
	row.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = mn
	sb.max_value = mx
	sb.value = val
	sb.custom_minimum_size = Vector2(120, 0)
	row.add_child(sb)
	parent.add_child(row)
	return sb


func _on_pick(x: float, z: float) -> void:
	_sx.value = roundf(x)
	_sz.value = roundf(z)


func _my_vehicle():
	var s = get_tree().current_scene.local_soldier
	if is_instance_valid(s) and is_instance_valid(s.vehicle):
		return s.vehicle
	return null


func toggle_panel() -> void:
	var v = _my_vehicle()
	if not _panel.visible:
		if v == null or v.kind != "mlrs":
			return
		_panel.visible = true
		Cfg.touch_live = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_panel.visible = false
		Cfg.touch_live = true
		if not Cfg.is_mobile:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _launch() -> void:
	var v = _my_vehicle()
	if v == null or v.kind != "mlrs":
		return
	v.mlrs_launch.rpc_id(1, float(_sx.value), float(_sz.value), float(_st.value), int(_sn.value))
	notice("تم إطلاق الصواريخ على الهدف (%d, %d)" % [int(_sx.value), int(_sz.value)])
	toggle_panel()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("map_panel"):
		toggle_panel()


func _process(delta: float) -> void:
	_hit_t = maxf(_hit_t - delta, 0.0)
	_msg_t = maxf(_msg_t - delta, 0.0)
	_flash_a = maxf(_flash_a - delta * 1.6, 0.0)
	var s = get_tree().current_scene.local_soldier
	if is_instance_valid(s):
		if _last_hp >= 0.0 and s.health < _last_hp - 0.5:
			_flash_a = 0.55
		_last_hp = s.health
	else:
		_last_hp = -1.0
	queue_redraw()


func _bearing() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	var f := -cam.global_transform.basis.z
	return rad_to_deg(atan2(f.x, -f.z))


func _draw() -> void:
	var f := get_theme_default_font()
	var sz := size
	var cx := sz.x * 0.5
	var sc = get_tree().current_scene
	var s = sc.local_soldier
	var alive := is_instance_valid(s)

	# وميض الإصابة
	if _flash_a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.8, 0.0, 0.0, _flash_a * 0.35))

	# نتائج الفرق
	var teams: Array = sc.scores.keys()
	var tw := 120.0
	var x0 := cx - tw * teams.size() * 0.5
	for i in teams.size():
		var t: int = teams[i]
		var r := Rect2(x0 + i * tw, 8, tw - 6, 34)
		draw_rect(r, Color(0, 0, 0, 0.55))
		draw_rect(Rect2(r.position, Vector2(6, r.size.y)), Cfg.TEAMS[t].color)
		draw_string(f, r.position + Vector2(16, 25), str(sc.scores[t]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(f, Vector2(cx - 60, 62), "الفوز عند %d" % int(Net.settings.win_score), HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1, 1, 1, 0.6))

	# بوصلة
	var b := _bearing()
	var cw := minf(sz.x * 0.4, 460.0)
	var cy := 84.0
	draw_rect(Rect2(cx - cw * 0.5, cy - 14, cw, 28), Color(0, 0, 0, 0.35))
	for d in range(-90, 91, 5):
		var ang := fposmod(b + d, 360.0)
		var px := cx + (float(d) / 90.0) * cw * 0.5
		var big := int(roundf(ang)) % 15 == 0
		if int(roundf(ang)) % 5 == 0:
			draw_line(Vector2(px, cy + 8), Vector2(px, cy + (0 if big else 3)), Color(1, 1, 1, 0.7), 1.0)
		var lab := ""
		if absf(ang - 0.0) < 2.5 or absf(ang - 360.0) < 2.5:
			lab = "N"
		elif absf(ang - 90.0) < 2.5:
			lab = "E"
		elif absf(ang - 180.0) < 2.5:
			lab = "S"
		elif absf(ang - 270.0) < 2.5:
			lab = "W"
		elif int(roundf(ang)) % 30 == 0 and d % 5 == 0:
			lab = str(int(roundf(ang)))
		if lab != "":
			draw_string(f, Vector2(px - 12, cy - 2), lab, HORIZONTAL_ALIGNMENT_CENTER, 24, 14, UI.AMBER if lab.length() == 1 else Color(1, 1, 1, 0.8))
	draw_colored_polygon(PackedVector2Array([Vector2(cx, cy + 14), Vector2(cx - 5, cy + 22), Vector2(cx + 5, cy + 22)]), UI.AMBER)

	if not alive:
		return

	# رادار
	var rc := Vector2(96, 130)
	var rr := 80.0
	draw_circle(rc, rr, Color(0, 0.05, 0, 0.55))
	draw_arc(rc, rr, 0.0, TAU, 48, UI.OLIVE, 2.0)
	draw_arc(rc, rr * 0.5, 0.0, TAU, 32, Color(1, 1, 1, 0.12), 1.0)
	draw_line(rc - Vector2(rr, 0), rc + Vector2(rr, 0), Color(1, 1, 1, 0.1))
	draw_line(rc - Vector2(0, rr), rc + Vector2(0, rr), Color(1, 1, 1, 0.1))
	var brad := deg_to_rad(b)
	var sb_ := sin(brad)
	var cb_ := cos(brad)
	var me: Vector3 = s.global_position
	var scale_m := rr / 120.0
	for n in get_tree().get_nodes_in_group("soldier"):
		if n == s or n.team != s.team or not n.alive:
			continue
		var dx: float = n.global_position.x - me.x
		var dz: float = n.global_position.z - me.z
		var u := dx * sb_ - dz * cb_
		var r_ := dx * cb_ + dz * sb_
		var p := Vector2(r_, -u) * scale_m
		if p.length() < rr - 4.0:
			draw_circle(rc + p, 3.5, Cfg.TEAMS[n.team].color)
	for n in get_tree().get_nodes_in_group("vehicle"):
		if n.team != s.team:
			continue
		var dx2: float = n.global_position.x - me.x
		var dz2: float = n.global_position.z - me.z
		var u2 := dx2 * sb_ - dz2 * cb_
		var r2 := dx2 * cb_ + dz2 * sb_
		var p2 := Vector2(r2, -u2) * scale_m
		if p2.length() < rr - 5.0:
			draw_rect(Rect2(rc + p2 - Vector2(4, 4), Vector2(8, 8)), Cfg.TEAMS[n.team].color)
	draw_colored_polygon(PackedVector2Array([rc + Vector2(0, -8), rc + Vector2(-6, 6), rc + Vector2(6, 6)]), Color.WHITE)
	draw_string(f, rc + Vector2(-5, -rr + 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.AMBER)
	draw_string(f, Vector2(24, 232), "X: %d   Y: %d" % [int(me.x), int(me.z)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.85))

	# مؤشر التصويب
	var c := sz * 0.5
	var gap := 6.0
	var col := Color(1, 1, 1, 0.9)
	for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(c + dv * gap, c + dv * (gap + 9.0), col, 2.0)
	draw_circle(c, 1.5, col)
	if _hit_t > 0.0:
		for dv in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + dv * 7.0, c + dv * 15.0, Color(1, 0.25, 0.2), 3.0)

	# شريط الصحة
	var hx := cx - 330.0
	var hy := sz.y - 78.0
	var frac := clampf(s.health / s.max_health, 0.0, 1.0)
	draw_rect(Rect2(hx - 4, hy - 4, 316, 26), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(hx, hy, 308 * frac, 18), Color(0.85, 0.15, 0.1).lerp(Color(0.35, 0.8, 0.25), frac))
	draw_string(f, Vector2(hx, hy - 8), "HP  %d / %d" % [int(s.health), int(s.max_health)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	# لوحة السلاح أو المركبة
	var px2 := cx + 20.0
	var veh = s.vehicle
	if is_instance_valid(veh):
		var d: Dictionary = veh.hud_data()
		draw_rect(Rect2(px2 - 6, hy - 62, 330, 90), Color(0, 0, 0, 0.55))
		draw_string(f, Vector2(px2, hy - 40), str(d.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.AMBER)
		var line := "%d km/h" % int(d.kmh)
		if d.air:
			line += "   ALT %d m" % int(d.alt)
		draw_string(f, Vector2(px2, hy - 16), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		var ammo_txt := ""
		if int(d.ammo) >= 0:
			ammo_txt = ("RELOADING" if int(d.ammo) == 0 else "AMMO %d" % int(d.ammo))
		if int(d.alt_ammo) >= 0:
			ammo_txt += "   ALT %d" % int(d.alt_ammo)
		draw_string(f, Vector2(px2, hy + 8), ammo_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		draw_rect(Rect2(px2, hy + 14, 318, 8), Color(0.2, 0.2, 0.2, 0.8))
		draw_rect(Rect2(px2, hy + 14, 318.0 * float(d.hp), 8), Color(0.4, 0.8, 0.3))
		if d.kind == "mlrs":
			draw_string(f, Vector2(px2 + 200, hy - 40), "[M] MLRS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))
	else:
		draw_rect(Rect2(px2 - 6, hy - 50, 330, 76), Color(0, 0, 0, 0.55))
		draw_string(f, Vector2(px2, hy - 28), str(Cfg.WEAPONS[s.weapon].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.AMBER)
		draw_string(f, Vector2(px2, hy + 6), "%d / %d" % [s.ammo, s.mag], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.35, 0.3) if s.ammo <= int(s.mag * 0.2) else Color.WHITE)
		if s.reloading:
			draw_string(f, Vector2(px2 + 150, hy + 4), "RELOADING", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.AMBER)

	if _msg_t > 0.0:
		draw_string(f, Vector2(cx - 300, 150), _msg, HORIZONTAL_ALIGNMENT_CENTER, 600, 22, Color(1, 0.85, 0.4, minf(_msg_t, 1.0)))
