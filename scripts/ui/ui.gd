class_name UI
extends RefCounted
## Shared UI helpers: theme, panels, buttons, sliders. Everything is built in code (no external assets).

const BG := Color(0.05, 0.07, 0.14, 0.94)
const PANEL := Color(0.09, 0.12, 0.22, 0.96)
const EDGE := Color(0.55, 0.8, 1.0)
const GOLD := Color(1.0, 0.85, 0.45)
const TEXT := Color(0.93, 0.96, 1.0)
const DIM := Color(0.6, 0.68, 0.82)


static func box(bg: Color, edge: Color, border: int = 2, radius: int = 8, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


static func make_theme(text_size: int = 1) -> Theme:
	var th := Theme.new()
	var fs: int = [20, 24, 30][clampi(text_size, 0, 2)]
	th.default_font_size = fs
	var hc: bool = Game.settings.get("high_contrast", false)
	var edge := Color.WHITE if hc else EDGE
	th.set_stylebox("normal", "Button", box(Color(0.12, 0.17, 0.3), Color(0.3, 0.45, 0.7) if not hc else Color.WHITE))
	th.set_stylebox("hover", "Button", box(Color(0.18, 0.26, 0.45), edge))
	th.set_stylebox("pressed", "Button", box(Color(0.3, 0.42, 0.7), GOLD))
	th.set_stylebox("focus", "Button", box(Color(0.2, 0.3, 0.5), GOLD, 3))
	th.set_stylebox("disabled", "Button", box(Color(0.1, 0.12, 0.18), Color(0.2, 0.24, 0.32)))
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_disabled_color", "Button", Color(0.45, 0.5, 0.6))
	th.set_color("font_color", "Label", TEXT)
	th.set_stylebox("panel", "PanelContainer", box(PANEL, edge, 2, 10, 16))
	th.set_stylebox("panel", "Panel", box(PANEL, edge, 2, 10, 16))
	var sl := box(Color(0.2, 0.28, 0.45), Color(0, 0, 0, 0), 0, 4, 0)
	sl.content_margin_top = 4
	sl.content_margin_bottom = 4
	th.set_stylebox("slider", "HSlider", sl)
	th.set_stylebox("grabber_area", "HSlider", box(GOLD, Color(0, 0, 0, 0), 0, 4, 0))
	th.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, Color(0, 0, 0, 0), 0, 4, 0))
	var grab := GradientTexture2D.new()
	grab.width = 28
	grab.height = 28
	grab.fill = GradientTexture2D.FILL_RADIAL
	grab.fill_from = Vector2(0.5, 0.5)
	grab.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 0.85, 0.45, 0.0))
	g.add_point(0.8, Color(1, 0.85, 0.45))
	grab.gradient = g
	th.set_icon("grabber", "HSlider", grab)
	th.set_icon("grabber_highlight", "HSlider", grab)
	th.set_constant("separation", "VBoxContainer", 8)
	th.set_constant("separation", "HBoxContainer", 10)
	return th


static func label(text: String, size: int = 0, col: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, cb: Callable, min_w: int = 0, min_h: int = 52) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		Sfx.play("ui_ok")
		cb.call())
	b.focus_entered.connect(func() -> void: Sfx.play("ui_move"))
	return b


static func panel(w: int, h: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, h)
	return p


## Row with a title and an HSlider (0..1). `on` receives the new value.
static func slider_row(title: String, value: float, on: Callable, minv: float = 0.0, maxv: float = 1.0, step: float = 0.05) -> HBoxContainer:
	var r := HBoxContainer.new()
	var l := label(title)
	l.custom_minimum_size = Vector2(260, 0)
	r.add_child(l)
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(300, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(func(v: float) -> void: on.call(v))
	r.add_child(s)
	return r


static func check_row(title: String, value: bool, on: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = title
	c.button_pressed = value
	c.focus_mode = Control.FOCUS_ALL
	c.custom_minimum_size = Vector2(0, 48)
	c.toggled.connect(func(v: bool) -> void:
		Sfx.play("ui_ok")
		on.call(v))
	return c


static func option_row(title: String, options: Array, index: int, on: Callable) -> HBoxContainer:
	var r := HBoxContainer.new()
	var l := label(title)
	l.custom_minimum_size = Vector2(260, 0)
	r.add_child(l)
	var o := OptionButton.new()
	for i in options.size():
		o.add_item(str(options[i]), i)
	o.selected = index
	o.custom_minimum_size = Vector2(240, 46)
	o.focus_mode = Control.FOCUS_ALL
	o.item_selected.connect(func(i: int) -> void: on.call(i))
	r.add_child(o)
	return r


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## Deferred focus that tolerates the control having been freed or removed in the meantime.
static func focus(c: Control) -> void:
	if c == null or not c.is_inside_tree():
		return
	var w: WeakRef = weakref(c)
	c.get_tree().process_frame.connect(func() -> void:
		var n: Control = w.get_ref() as Control
		if n != null and n.is_inside_tree() and n.is_visible_in_tree():
			n.grab_focus(), CONNECT_ONE_SHOT)
