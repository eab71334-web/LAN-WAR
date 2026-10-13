extends RefCounted
## أدوات واجهة صغيرة (تُستخدم عبر preload)

static func label(t: String, size: int = 18) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	return l


static func button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(cb)
	return b


static func full_rect(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)


static func backdrop(parent: Control) -> void:
	var r := ColorRect.new()
	r.color = Color(0.07, 0.09, 0.07)
	full_rect(r)
	parent.add_child(r)
