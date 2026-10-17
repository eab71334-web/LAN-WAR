extends RefCounted
## أدوات واجهة + ثيم عسكري موحّد + حركات.

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
	b.pressed.connect(func(): Sfx.ui("click"))
	hover_anim(b)
	return b


static func full_rect(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)


static func backdrop(parent: Control) -> void:
	var r := ColorRect.new()
	r.color = Color(0.06, 0.08, 0.06)
	full_rect(r)
	parent.add_child(r)


static func hover_anim(c: Control, amt := 1.04) -> void:
	c.resized.connect(func(): c.pivot_offset = c.size * 0.5)
	c.mouse_entered.connect(func():
		Sfx.ui("hover", -14.0)
		c.create_tween().tween_property(c, "scale", Vector2(amt, amt), 0.12).set_trans(Tween.TRANS_QUAD))
	c.mouse_exited.connect(func():
		c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.12))


## ظهور بتكبير ناعم (يصلح داخل الحاويات)
static func pop_in(c: Control, delay := 0.0) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2(0.9, 0.9)
	if c.is_inside_tree():
		await c.get_tree().process_frame
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.3).set_delay(delay)
	tw.tween_property(c, "scale", Vector2.ONE, 0.4).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## انزلاق أفقي لعنصر موضوع يدويًا (ليس داخل حاوية)
static func slide_in(c: Control, dx: float, delay := 0.0) -> void:
	var target := c.position
	c.position = target + Vector2(dx, 0)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "position", target, 0.55).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.35).set_delay(delay)


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


## زر قائمة رئيسية بشريط جانبي
static func menu_button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 24)
	var n := sb(Color(0.05, 0.07, 0.04, 0.6), Color(0, 0, 0, 0), 0, 2, 22)
	n.border_width_left = 5
	n.border_color = OLIVE
	var h := sb(Color(0.3, 0.34, 0.12, 0.85), AMBER, 0, 2, 22)
	h.border_width_left = 10
	h.border_color = AMBER
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	b.pressed.connect(func(): Sfx.ui("click"))
	b.mouse_entered.connect(func(): Sfx.ui("hover", -14.0))
	return b


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
	th.set_stylebox("hover_pressed", "Button", sb(Color(0.45, 0.36, 0.1), AMBER, 2, 4, 10))
	th.set_color("font_hover_pressed_color", "Button", Color.WHITE)
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
	th.set_stylebox("background", "ProgressBar", sb(Color(0.04, 0.05, 0.03), Color(0.3, 0.33, 0.2), 1, 3, 2))
	th.set_stylebox("fill", "ProgressBar", sb(AMBER, AMBER, 0, 3, 2))
	th.set_stylebox("slider", "HSlider", sb(Color(0.04, 0.05, 0.03), Color(0.3, 0.33, 0.2), 1, 3, 2))
	th.set_stylebox("grabber_area", "HSlider", sb(OLIVE, OLIVE, 0, 3, 2))
	th.set_stylebox("grabber_area_highlight", "HSlider", sb(AMBER, AMBER, 0, 3, 2))
	return th


## تظليل جانبي متدرّج لقراءة القائمة فوق المشهد
static func side_shade(parent: Control, strength := 0.88) -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.02, 0.03, 0.02, strength), Color(0.02, 0.03, 0.02, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(0.62, 0.5)
	gt.width = 256
	gt.height = 8
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(tr)
	parent.add_child(tr)


## إطار معتم حول الشاشة (vignette)
static func vignette(parent: Control, strength := 0.75) -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, strength)])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(tr)
	parent.add_child(tr)
