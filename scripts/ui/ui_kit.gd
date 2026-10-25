extends RefCounted
## Shared UI helpers. Use via: const UI = preload("res://scripts/ui/ui_kit.gd")

const COL_BG := Color(0.05, 0.08, 0.09, 0.94)
const COL_PANEL := Color(0.09, 0.13, 0.14, 0.96)
const COL_PANEL_LIGHT := Color(0.14, 0.20, 0.21, 1.0)
const COL_ACCENT := Color(0.96, 0.72, 0.28)
const COL_ACCENT2 := Color(0.36, 0.82, 0.68)
const COL_TEXT := Color(0.94, 0.96, 0.94)
const COL_DIM := Color(0.62, 0.70, 0.70)
const COL_BAD := Color(0.95, 0.38, 0.32)
const COL_GOOD := Color(0.48, 0.88, 0.52)

static var _theme: Theme = null


static func style(bg: Color, radius: int = 12, border: Color = Color(0, 0, 0, 0), border_w: int = 0, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", style(COL_PANEL_LIGHT, 12, Color(1, 1, 1, 0.12), 1, 14))
	t.set_stylebox("hover", "Button", style(COL_PANEL_LIGHT.lightened(0.12), 12, COL_ACCENT2, 2, 14))
	t.set_stylebox("pressed", "Button", style(COL_ACCENT.darkened(0.2), 12, COL_ACCENT, 2, 14))
	t.set_stylebox("disabled", "Button", style(Color(0.12, 0.15, 0.16), 12, Color(1, 1, 1, 0.05), 1, 14))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", COL_TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.5, 0.5))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_color", "Label", COL_TEXT)
	t.set_stylebox("panel", "PanelContainer", style(COL_PANEL, 18, Color(1, 1, 1, 0.14), 2, 16))
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("h_separation", "GridContainer", 8)
	t.set_constant("v_separation", "GridContainer", 8)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.25)
	sb.set_corner_radius_all(8)
	t.set_stylebox("grabber", "VScrollBar", sb)
	t.set_stylebox("grabber_highlight", "VScrollBar", sb)
	t.set_stylebox("grabber_pressed", "VScrollBar", sb)
	var tex := _circle_tex(22)
	t.set_icon("grabber", "HSlider", tex)
	t.set_icon("grabber_highlight", "HSlider", tex)
	t.set_icon("grabber_disabled", "HSlider", tex)
	var track := style(Color(1, 1, 1, 0.18), 6, Color(0, 0, 0, 0), 0, 0)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", style(COL_ACCENT2, 6, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", style(COL_ACCENT2, 6, Color(0, 0, 0, 0), 0, 0))
	t.set_font_size("font_size", "CheckBox", 22)
	_theme = t
	return t


static func _circle_tex(radius: int) -> ImageTexture:
	var d := radius * 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - radius, y + 0.5 - radius).length()
			var a := clampf(radius - dist, 0.0, 1.0)
			var col := Color(0.96, 0.72, 0.28, a) if dist < radius - 3.0 else Color(1, 1, 1, a)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func label(text: String, size: int = 22, color: Color = COL_TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 100
	return l


static func button(text: String, cb: Callable, min_size: Vector2 = Vector2(0, 56), accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	if accent:
		b.add_theme_stylebox_override("normal", style(COL_ACCENT.darkened(0.3), 12, COL_ACCENT, 2, 14))
		b.add_theme_stylebox_override("hover", style(COL_ACCENT.darkened(0.15), 12, COL_ACCENT, 2, 14))
		b.add_theme_stylebox_override("pressed", style(COL_ACCENT, 12, Color.WHITE, 2, 14))
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


static func spacer(h: int = 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func safe_margins(viewport: Viewport) -> Dictionary:
	var m := {"l": 16.0, "r": 16.0, "t": 12.0, "b": 12.0}
	if not OS.has_feature("mobile"):
		return m
	var win_size := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win_size.x <= 0 or safe.size.x <= 0:
		return m
	var vs := viewport.get_visible_rect().size
	var sx := vs.x / float(win_size.x)
	var sy := vs.y / float(win_size.y)
	m["l"] = maxf(m["l"], safe.position.x * sx)
	m["t"] = maxf(m["t"], safe.position.y * sy)
	m["r"] = maxf(m["r"], (win_size.x - safe.end.x) * sx)
	m["b"] = maxf(m["b"], (win_size.y - safe.end.y) * sy)
	return m


# ---------------------------------------------------------------- vector item icon
class ItemIcon extends Control:
	var item_id: String = ""
	var locked: bool = false

	func _init(id: String = "", sz: float = 56.0) -> void:
		item_id = id
		custom_minimum_size = Vector2(sz, sz)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_item(id: String) -> void:
		item_id = id
		queue_redraw()

	func _poly(pts: Array, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array(pts), col)

	func _draw() -> void:
		if not Data.items.has(item_id):
			return
		var d: Dictionary = Data.items[item_id]
		var col: Color = d["col"]
		var s := minf(size.x, size.y)
		var c := size * 0.5
		var r := s * 0.36
		var dark := col.darkened(0.45)
		var light := col.lightened(0.35)
		var wood := Color(0.55, 0.38, 0.22)
		match String(d["icon"]):
			"log":
				draw_rect(Rect2(c.x - r, c.y - r * 0.55, r * 2, r * 1.1), col)
				draw_circle(Vector2(c.x + r, c.y), r * 0.55, light)
				draw_arc(Vector2(c.x + r, c.y), r * 0.3, 0, TAU, 16, dark, 2.0)
			"stone":
				_poly([c + Vector2(-r, r * 0.6), c + Vector2(-r * 0.7, -r * 0.5), c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.3), c + Vector2(r, r * 0.6)], col)
				draw_line(c + Vector2(-r * 0.2, -r * 0.8), c + Vector2(r * 0.1, r * 0.5), dark, 2.0)
			"fiber", "herb":
				for i in 4:
					var a := -0.6 + i * 0.4
					draw_line(c + Vector2(0, r), c + Vector2(sin(a) * r * 1.1, -r * cos(a * 0.6)), col if i % 2 == 0 else light, 4.0)
			"hide":
				_poly([c + Vector2(-r, -r * 0.6), c + Vector2(-r * 0.4, -r * 0.8), c + Vector2(r * 0.4, -r * 0.8), c + Vector2(r, -r * 0.6), c + Vector2(r * 0.7, 0), c + Vector2(r, r * 0.7), c + Vector2(0, r * 0.9), c + Vector2(-r, r * 0.7), c + Vector2(-r * 0.7, 0)], col)
				draw_line(c + Vector2(-r * 0.3, -r * 0.3), c + Vector2(r * 0.3, r * 0.3), dark, 2.0)
			"fang":
				_poly([c + Vector2(-r * 0.5, -r), c + Vector2(r * 0.5, -r), c + Vector2(0, r)], col)
				_poly([c + Vector2(-r * 0.5, -r), c + Vector2(0, -r), c + Vector2(0, r)], light)
			"ore":
				_poly([c + Vector2(-r, r * 0.6), c + Vector2(-r * 0.7, -r * 0.5), c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.3), c + Vector2(r, r * 0.6)], Color(0.45, 0.43, 0.42))
				draw_circle(c + Vector2(-r * 0.2, -r * 0.1), r * 0.28, col)
				draw_circle(c + Vector2(r * 0.4, r * 0.15), r * 0.22, col.lightened(0.15))
			"ingot":
				_poly([c + Vector2(-r, r * 0.5), c + Vector2(-r * 0.6, -r * 0.2), c + Vector2(r * 0.6, -r * 0.2), c + Vector2(r, r * 0.5)], col)
				_poly([c + Vector2(-r * 0.6, -r * 0.2), c + Vector2(-r * 0.3, -r * 0.6), c + Vector2(r * 0.9, -r * 0.6), c + Vector2(r * 0.6, -r * 0.2)], light)
			"crystal":
				_poly([c + Vector2(0, -r), c + Vector2(r * 0.7, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.7, -r * 0.2)], col)
				_poly([c + Vector2(0, -r), c + Vector2(r * 0.7, -r * 0.2), c + Vector2(0, -r * 0.1)], light)
			"part":
				draw_circle(c, r * 0.8, Color(0.5, 0.54, 0.6))
				draw_circle(c, r * 0.35, Color(0.15, 0.17, 0.2))
				for i in 8:
					var a := i * TAU / 8.0
					draw_line(c + Vector2(cos(a), sin(a)) * r * 0.8, c + Vector2(cos(a), sin(a)) * r * 1.1, col, 5.0)
			"berry":
				draw_circle(c + Vector2(-r * 0.35, r * 0.2), r * 0.55, col)
				draw_circle(c + Vector2(r * 0.4, r * 0.3), r * 0.5, col.lightened(0.1))
				draw_circle(c + Vector2(0, -r * 0.4), r * 0.5, col.darkened(0.1))
				draw_line(c + Vector2(0, -r * 0.9), c + Vector2(r * 0.3, -r * 1.2), Color(0.3, 0.7, 0.3), 3.0)
			"coconut":
				draw_circle(c, r * 0.85, col)
				draw_circle(c + Vector2(-r * 0.25, -r * 0.2), r * 0.1, dark)
				draw_circle(c + Vector2(r * 0.1, -r * 0.3), r * 0.1, dark)
				draw_circle(c + Vector2(-r * 0.05, 0), r * 0.1, dark)
			"mushroom":
				draw_rect(Rect2(c.x - r * 0.25, c.y, r * 0.5, r), Color(0.92, 0.88, 0.8))
				draw_arc(c + Vector2(0, r * 0.1), r, PI, TAU, 18, col, r * 0.9)
				draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.12, Color(1, 1, 1, 0.8))
				draw_circle(c + Vector2(r * 0.3, -r * 0.25), r * 0.1, Color(1, 1, 1, 0.8))
			"meat":
				draw_circle(c + Vector2(-r * 0.1, 0), r * 0.75, col)
				draw_circle(c + Vector2(-r * 0.1, 0), r * 0.35, col.lightened(0.25))
				draw_rect(Rect2(c.x + r * 0.5, c.y - r * 0.15, r * 0.7, r * 0.3), Color(0.92, 0.9, 0.82))
			"cooked":
				draw_circle(c + Vector2(-r * 0.1, 0), r * 0.75, Color(0.55, 0.3, 0.16))
				draw_circle(c + Vector2(-r * 0.1, 0), r * 0.35, Color(0.7, 0.42, 0.22))
				draw_rect(Rect2(c.x + r * 0.5, c.y - r * 0.15, r * 0.7, r * 0.3), Color(0.92, 0.9, 0.82))
			"ration":
				draw_rect(Rect2(c - Vector2(r, r * 0.6), Vector2(r * 2, r * 1.2)), col)
				draw_rect(Rect2(c - Vector2(r, r * 0.6), Vector2(r * 2, r * 1.2)), dark, false, 2.0)
				draw_rect(Rect2(c.x - r * 0.3, c.y - r * 0.6, r * 0.6, r * 1.2), light)
			"stew":
				draw_arc(c + Vector2(0, -r * 0.2), r, 0, PI, 20, Color(0.35, 0.35, 0.38), r * 0.5)
				draw_rect(Rect2(c.x - r, c.y - r * 0.25, r * 2, r * 0.2), col)
			"bandage", "kit", "medkit":
				draw_rect(Rect2(c - Vector2(r, r * 0.7), Vector2(r * 2, r * 1.4)), Color(0.9, 0.9, 0.88))
				draw_rect(Rect2(c.x - r * 0.15, c.y - r * 0.5, r * 0.3, r), Color(0.85, 0.2, 0.2))
				draw_rect(Rect2(c.x - r * 0.5, c.y - r * 0.15, r, r * 0.3), Color(0.85, 0.2, 0.2))
			"tonic":
				draw_rect(Rect2(c.x - r * 0.55, c.y - r * 0.2, r * 1.1, r * 1.2), col)
				draw_rect(Rect2(c.x - r * 0.25, c.y - r, r * 0.5, r * 0.8), col.lightened(0.3))
				draw_rect(Rect2(c.x - r * 0.3, c.y - r * 1.1, r * 0.6, r * 0.2), wood)
			"axe":
				draw_line(c + Vector2(-r * 0.8, r), c + Vector2(r * 0.6, -r * 0.8), wood, 5.0)
				_poly([c + Vector2(r * 0.2, -r), c + Vector2(r, -r * 0.5), c + Vector2(r * 0.7, 0), c + Vector2(r * 0.1, -r * 0.4)], col)
			"pick":
				draw_line(c + Vector2(-r * 0.8, r), c + Vector2(r * 0.5, -r * 0.6), wood, 5.0)
				draw_arc(c + Vector2(r * 0.5, -r * 0.2), r * 0.8, PI * 1.1, PI * 1.9, 12, col, 6.0)
			"spear":
				draw_line(c + Vector2(-r, r), c + Vector2(r * 0.6, -r * 0.6), wood, 4.0)
				_poly([c + Vector2(r * 0.4, -r * 0.4), c + Vector2(r * 1.1, -r * 1.1), c + Vector2(r * 0.8, -r * 0.2)], col)
			"blade", "energy_blade":
				draw_line(c + Vector2(-r * 0.9, r * 0.9), c + Vector2(-r * 0.5, r * 0.5), wood, 6.0)
				draw_line(c + Vector2(-r * 0.7, r * 0.2), c + Vector2(-r * 0.2, r * 0.7), Color(0.4, 0.4, 0.42), 4.0)
				draw_line(c + Vector2(-r * 0.4, r * 0.4), c + Vector2(r, -r), col, 6.0)
				if String(d["icon"]) == "energy_blade":
					draw_line(c + Vector2(-r * 0.4, r * 0.4), c + Vector2(r, -r), Color(1, 1, 1, 0.7), 2.0)
			"cannon":
				draw_rect(Rect2(c.x - r, c.y - r * 0.3, r * 1.7, r * 0.6), col)
				draw_rect(Rect2(c.x - r * 0.9, c.y + r * 0.1, r * 0.5, r * 0.9), dark)
				draw_circle(c + Vector2(r * 0.7, 0), r * 0.25, Color(0.5, 0.95, 1.0))
			"armor":
				_poly([c + Vector2(-r, -r * 0.7), c + Vector2(-r * 0.4, -r), c + Vector2(r * 0.4, -r), c + Vector2(r, -r * 0.7), c + Vector2(r * 0.7, r * 0.2), c + Vector2(r * 0.5, r), c + Vector2(-r * 0.5, r), c + Vector2(-r * 0.7, r * 0.2)], col)
				draw_line(c + Vector2(0, -r * 0.9), c + Vector2(0, r * 0.9), dark, 2.0)
			"suit":
				_poly([c + Vector2(-r, -r * 0.7), c + Vector2(-r * 0.4, -r), c + Vector2(r * 0.4, -r), c + Vector2(r, -r * 0.7), c + Vector2(r * 0.7, r * 0.2), c + Vector2(r * 0.5, r), c + Vector2(-r * 0.5, r), c + Vector2(-r * 0.7, r * 0.2)], col)
				draw_rect(Rect2(c.x - r * 0.45, c.y - r * 0.5, r * 0.9, r * 0.45), Color(0.15, 0.2, 0.3))
			"pack":
				draw_rect(Rect2(c.x - r * 0.8, c.y - r * 0.8, r * 1.6, r * 1.8), col)
				draw_rect(Rect2(c.x - r * 0.5, c.y + r * 0.1, r, r * 0.6), col.lightened(0.2))
				draw_arc(c + Vector2(0, -r * 0.8), r * 0.4, PI, TAU, 10, dark, 3.0)
			"cell":
				draw_rect(Rect2(c.x - r * 0.6, c.y - r * 0.9, r * 1.2, r * 1.8), Color(0.3, 0.32, 0.36))
				draw_rect(Rect2(c.x - r * 0.4, c.y - r * 0.6, r * 0.8, r * 1.2), col)
				draw_rect(Rect2(c.x - r * 0.25, c.y - r * 1.1, r * 0.5, r * 0.2), Color(0.8, 0.8, 0.8))
			"seal":
				draw_circle(c, r * 0.9, col)
				draw_arc(c, r * 0.6, 0, TAU, 20, dark, 3.0)
				for i in 3:
					var a := i * TAU / 3.0 - PI * 0.5
					draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.55, light, 3.0)
			"key":
				draw_circle(c + Vector2(-r * 0.5, 0), r * 0.5, col)
				draw_circle(c + Vector2(-r * 0.5, 0), r * 0.2, Color(0.1, 0.1, 0.1))
				draw_rect(Rect2(c.x - r * 0.1, c.y - r * 0.1, r * 1.2, r * 0.2), col)
				draw_rect(Rect2(c.x + r * 0.7, c.y, r * 0.15, r * 0.4), col)
				draw_rect(Rect2(c.x + r * 0.45, c.y, r * 0.15, r * 0.3), col)
			_:
				draw_circle(c, r, col)
		if locked:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))


## Original logo: a cut crystal over a mountain horizon and the game title.
static func draw_logo(c: CanvasItem, center: Vector2, s: float, t: float = 0.0) -> void:
	var glow := 0.5 + 0.5 * sin(t * 1.6)
	c.draw_circle(center + Vector2(0, -30 * s), 100.0 * s, Color(0.4, 0.9, 0.8, 0.08 + 0.05 * glow))
	var top := center + Vector2(0, -120 * s)
	var r := center + Vector2(55 * s, -60 * s)
	var l := center + Vector2(-55 * s, -60 * s)
	var bot := center + Vector2(0, 20 * s)
	c.draw_colored_polygon(PackedVector2Array([top, r, bot, l]), Color(0.35, 0.82, 0.72))
	c.draw_colored_polygon(PackedVector2Array([top, r, center + Vector2(0, -70 * s)]), Color(0.8, 1.0, 0.95))
	c.draw_colored_polygon(PackedVector2Array([top, l, center + Vector2(0, -70 * s)]), Color(0.55, 0.95, 0.85))
	c.draw_polyline(PackedVector2Array([top, r, bot, l, top]), Color(0.08, 0.25, 0.25), 3.0 * s)
	c.draw_colored_polygon(PackedVector2Array([center + Vector2(-130 * s, 20 * s), center + Vector2(-70 * s, -30 * s), center + Vector2(-35 * s, 0), center + Vector2(0, -20 * s), center + Vector2(40 * s, 5 * s), center + Vector2(80 * s, -35 * s), center + Vector2(130 * s, 20 * s)]), Color(0.12, 0.22, 0.2, 0.9))
	var font := ThemeDB.fallback_font
	var title := "PROJECT WILDLANDS"
	var fs := int(64 * s)
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	var tp := center + Vector2(-tw * 0.5, 100 * s)
	c.draw_string_outline(font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(12 * s), Color(0.06, 0.14, 0.14))
	c.draw_string(font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.98, 0.93, 0.72))
	var sub := "SURVIVE THE ISLAND. WAKE THE CORE."
	var fs2 := int(24 * s)
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, fs2).x
	var sp := center + Vector2(-sw * 0.5, 140 * s)
	c.draw_string_outline(font, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, int(7 * s), Color(0.06, 0.14, 0.14))
	c.draw_string(font, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0.5, 0.95, 0.85))
