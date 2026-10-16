extends RefCounted
## أدوات واجهة + ثيم عسكري موحّد.

const OLIVE := Color(0.45, 0.52, 0.25)
const AMBER := Color(0.96, 0.72, 0.25)
const INK := Color(0.92, 0.92, 0.85)


static func label(t: String, size: int = 18) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	return l


static func button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(cb)
	return b


static func full_rect(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)


static func backdrop(parent: Control) -> void:
	var r := ColorRect.new()
	r.color = Color(0.06, 0.08, 0.06)
	full_rect(r)
	parent.add_child(r)


static func sb(bg: Color, border: Color, bw := 1, radius := 4, pad := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = maxi(pad - 3, 2)
	s.content_margin_bottom = maxi(pad - 3, 2)
	return s


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 20
	var panel := sb(Color(0.08, 0.1, 0.07, 0.92), OLIVE, 2, 6, 14)
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("panel", "PopupPanel", panel)
	th.set_stylebox("panel", "PopupMenu", sb(Color(0.08, 0.1, 0.07, 0.98), OLIVE, 2, 4, 6))
	th.set_stylebox("hover", "PopupMenu", sb(Color(0.25, 0.3, 0.14), AMBER, 1, 3, 6))
	th.set_color("font_color", "PopupMenu", INK)
	th.set_color("font_hover_color", "PopupMenu", AMBER)
	for t in ["Button", "OptionButton", "MenuButton"]:
		th.set_stylebox("normal", t, sb(Color(0.15, 0.18, 0.11), OLIVE, 1, 4, 10))
		th.set_stylebox("hover", t, sb(Color(0.24, 0.29, 0.15), AMBER, 2, 4, 10))
		th.set_stylebox("pressed", t, sb(Color(0.4, 0.32, 0.1), AMBER, 2, 4, 10))
		th.set_stylebox("disabled", t, sb(Color(0.1, 0.1, 0.1, 0.6), Color(0.3, 0.3, 0.3), 1, 4, 10))
		th.set_stylebox("focus", t, StyleBoxEmpty.new())
		th.set_color("font_color", t, INK)
		th.set_color("font_hover_color", t, AMBER)
		th.set_color("font_pressed_color", t, Color.WHITE)
		th.set_color("font_disabled_color", t, Color(0.5, 0.5, 0.5))
	for t in ["CheckBox", "CheckButton"]:
		th.set_stylebox("normal", t, StyleBoxEmpty.new())
		th.set_stylebox("hover", t, StyleBoxEmpty.new())
		th.set_stylebox("pressed", t, StyleBoxEmpty.new())
		th.set_stylebox("focus", t, StyleBoxEmpty.new())
		th.set_color("font_color", t, INK)
		th.set_color("font_hover_color", t, AMBER)
	th.set_stylebox("normal", "LineEdit", sb(Color(0.05, 0.06, 0.04), OLIVE, 1, 4, 10))
	th.set_stylebox("focus", "LineEdit", sb(Color(0.07, 0.08, 0.05), AMBER, 2, 4, 10))
	th.set_stylebox("read_only", "LineEdit", sb(Color(0.05, 0.06, 0.04), Color(0.3, 0.3, 0.3), 1, 4, 10))
	th.set_color("font_color", "LineEdit", INK)
	th.set_color("caret_color", "LineEdit", AMBER)
	th.set_stylebox("panel", "ItemList", sb(Color(0.05, 0.06, 0.04), OLIVE, 1, 4, 6))
	th.set_stylebox("selected", "ItemList", sb(Color(0.3, 0.34, 0.14), AMBER, 1, 3, 4))
	th.set_stylebox("selected_focus", "ItemList", sb(Color(0.3, 0.34, 0.14), AMBER, 1, 3, 4))
	th.set_color("font_color", "ItemList", INK)
	th.set_color("font_color", "Label", INK)
	th.set_color("font_color", "SpinBox", INK)
	return th
