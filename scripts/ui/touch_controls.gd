extends Control
## أزرار اللمس للجوال: عصا حركة (يسار)، نظر بالسحب (يمين)، وأزرار.
## الطائرة: العصا = رفع/خفض الأنف وميلان. RUN = زيادة الدفع. DOWN = تقليل الدفع.
## المروحية: JUMP = صعود، DOWN = نزول.

const STICK_R := 90.0

var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _look_id := -1
var _held := {}   # رقم الإصبع -> اسم الفعل


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _buttons() -> Array:
	var s := size
	return [
		{"a": "fire", "p": Vector2(s.x - 120, s.y - 140), "r": 60.0, "t": "FIRE"},
		{"a": "jump", "p": Vector2(s.x - 265, s.y - 90), "r": 42.0, "t": "JUMP"},
		{"a": "sprint", "p": Vector2(s.x - 290, s.y - 200), "r": 42.0, "t": "RUN"},
		{"a": "crouch", "p": Vector2(s.x - 200, s.y - 290), "r": 42.0, "t": "DOWN"},
		{"a": "interact", "p": Vector2(s.x - 90, s.y - 285), "r": 42.0, "t": "E"},
	]


func _process(_d: float) -> void:
	if Cfg.touch_live or _held.size() > 0 or _stick_id != -1:
		queue_redraw()


func _draw() -> void:
	if not Cfg.touch_live:
		return
	var base := _stick_origin if _stick_id != -1 else Vector2(150, size.y - 150)
	draw_circle(base, STICK_R, Color(1, 1, 1, 0.10))
	draw_circle(base + _stick_vec * STICK_R, 38.0, Color(1, 1, 1, 0.30))
	for b in _buttons():
		var down: bool = _held.values().has(b.a)
		draw_circle(b.p, b.r, Color(1, 1, 1, 0.30 if down else 0.12))
		draw_string(ThemeDB.fallback_font, b.p + Vector2(-b.r, 7), b.t, HORIZONTAL_ALIGNMENT_CENTER, b.r * 2.0, 18, Color.WHITE)


func _input(e: InputEvent) -> void:
	if not Cfg.touch_live:
		if _held.size() > 0 or _stick_id != -1 or _look_id != -1:
			_release_all()
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			_down(e.index, e.position)
		else:
			_up(e.index)
	elif e is InputEventScreenDrag:
		_drag(e.index, e.position, e.relative)


func _down(i: int, p: Vector2) -> void:
	for b in _buttons():
		if p.distance_to(b.p) <= float(b.r) * 1.15:
			_held[i] = b.a
			_press(b.a)
			return
	if p.x < size.x * 0.4 and p.y > size.y * 0.3 and _stick_id == -1:
		_stick_id = i
		_stick_origin = p
		_stick_vec = Vector2.ZERO
	elif p.x >= size.x * 0.4 and _look_id == -1:
		_look_id = i


func _up(i: int) -> void:
	if _held.has(i):
		_release(_held[i])
		_held.erase(i)
	if i == _stick_id:
		_stick_id = -1
		_stick_vec = Vector2.ZERO
		_apply_stick()
	if i == _look_id:
		_look_id = -1


func _drag(i: int, p: Vector2, rel: Vector2) -> void:
	if i == _stick_id:
		_stick_vec = (p - _stick_origin).limit_length(STICK_R) / STICK_R
		_apply_stick()
	elif i == _look_id:
		var ev := InputEventMouseMotion.new()
		ev.relative = rel * 1.2
		ev.position = p
		Input.parse_input_event(ev)


func _apply_stick() -> void:
	var v := _stick_vec
	_axis("move_right", maxf(v.x, 0.0))
	_axis("move_left", maxf(-v.x, 0.0))
	_axis("move_back", maxf(v.y, 0.0))
	_axis("move_fwd", maxf(-v.y, 0.0))


func _axis(a: String, s: float) -> void:
	if s > 0.2:
		Input.action_press(a, s)
	else:
		Input.action_release(a)


func _press(a: String) -> void:
	if a == "interact":
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		Input.parse_input_event(ev)
	else:
		Input.action_press(a)


func _release(a: String) -> void:
	if a == "interact":
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = false
		Input.parse_input_event(ev)
	else:
		Input.action_release(a)


func _release_all() -> void:
	for i in _held.keys():
		_release(_held[i])
	_held.clear()
	_stick_id = -1
	_look_id = -1
	_stick_vec = Vector2.ZERO
	_apply_stick()
