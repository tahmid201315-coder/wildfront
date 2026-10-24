extends Control
## A circular, multi-touch-safe action button. It never receives GUI mouse events;
## the TouchControls layer feeds it raw finger presses so several fingers can work at once
## (e.g. moving with one thumb while tapping Jump with the other).

signal pressed
signal released

var label: String = ""
var glyph: String = ""
var radius: float = 52.0
var enabled: bool = true
var held: bool = false
var finger: int = -1
var cooldown_frac: float = 0.0   # 0..1 overlay for ability cooldowns
var tint: Color = Color(0.98, 0.66, 0.2)
var badge: String = ""

const FONT_SIZE := 18


func _init(p_glyph: String = "", p_label: String = "", p_radius: float = 52.0) -> void:
	glyph = p_glyph
	label = p_label
	radius = p_radius
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func hit(p: Vector2) -> bool:
	if not is_visible_in_tree() or not enabled:
		return false
	var c := get_global_rect().get_center()
	return c.distance_to(p) <= radius * 1.15


func press(idx: int) -> void:
	finger = idx
	held = true
	pressed.emit()
	queue_redraw()


func release() -> void:
	if not held:
		return
	held = false
	finger = -1
	released.emit()
	queue_redraw()


func set_label(t: String) -> void:
	if t != label:
		label = t
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var alpha := 0.85 if enabled else 0.35
	var base := tint if not held else tint.lightened(0.35)
	draw_circle(c, radius, Color(0.05, 0.08, 0.1, 0.55 * alpha))
	draw_circle(c, radius - 4.0, Color(base.r, base.g, base.b, 0.5 * alpha))
	draw_arc(c, radius - 3.0, 0, TAU, 40, Color(1, 1, 1, 0.85 * alpha), 3.0, true)
	_draw_glyph(c, radius * 0.45, Color(1, 1, 1, alpha))
	if cooldown_frac > 0.0:
		var pts := PackedVector2Array([c])
		var steps := 24
		for i in range(steps + 1):
			var a := -PI / 2.0 + TAU * cooldown_frac * float(i) / steps
			pts.append(c + Vector2(cos(a), sin(a)) * (radius - 4.0))
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	if label != "":
		var font := ThemeDB.fallback_font
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE)
		var pos := Vector2(c.x - ts.x * 0.5, size.y + FONT_SIZE + 2.0)
		draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 6, Color(0, 0, 0, 0.85))
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1, 1, 1, alpha))
	if badge != "":
		draw_circle(Vector2(size.x - 10, 10), 13, Color(0.9, 0.25, 0.25))
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 16, 16), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _draw_glyph(c: Vector2, r: float, col: Color) -> void:
	match glyph:
		"jump":
			draw_polyline(PackedVector2Array([c + Vector2(-r, r * 0.4), c + Vector2(0, -r * 0.6), c + Vector2(r, r * 0.4)]), col, 6.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(-r, r * 1.0), c + Vector2(0, 0.0), c + Vector2(r, r * 1.0)]), col, 4.0, true)
		"act":
			draw_circle(c, r * 0.9, col)
			draw_circle(c, r * 0.5, Color(0.1, 0.12, 0.15, 0.9))
			draw_circle(c, r * 0.22, col)
		"strike":
			draw_line(c + Vector2(-r, r), c + Vector2(r * 0.8, -r * 0.8), col, 7.0)
			draw_line(c + Vector2(-r * 0.7, r * 0.3), c + Vector2(-r * 0.2, r * 0.8), col, 6.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.6, -r * 1.0), c + Vector2(r * 1.1, -r * 0.5), c + Vector2(r * 0.9, -r * 1.1)]), col)
		"paw":
			draw_circle(c + Vector2(0, r * 0.35), r * 0.55, col)
			for p in [Vector2(-r * 0.7, -r * 0.2), Vector2(-r * 0.25, -r * 0.75), Vector2(r * 0.25, -r * 0.75), Vector2(r * 0.7, -r * 0.2)]:
				draw_circle(c + p, r * 0.25, col)
		"build":
			draw_line(c + Vector2(-r, r), c + Vector2(r * 0.4, -r * 0.4), col, 7.0)
			draw_rect(Rect2(c + Vector2(r * 0.0, -r * 1.0), Vector2(r * 1.0, r * 0.6)), col)
		"bag":
			draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.4), Vector2(r * 1.6, r * 1.3)), col)
			draw_arc(c + Vector2(0, -r * 0.4), r * 0.45, PI, TAU, 12, col, 4.0)
		"pause":
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.8), Vector2(r * 0.45, r * 1.6)), col)
			draw_rect(Rect2(c + Vector2(r * 0.25, -r * 0.8), Vector2(r * 0.45, r * 1.6)), col)
		"map":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.6), c + Vector2(-r * 0.35, -r * 0.9), c + Vector2(r * 0.35, -r * 0.6), c + Vector2(r, -r * 0.9),
				c + Vector2(r, r * 0.6), c + Vector2(r * 0.35, r * 0.9), c + Vector2(-r * 0.35, r * 0.6), c + Vector2(-r, r * 0.9)]), col)
		"book":
			draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.9), Vector2(r * 1.6, r * 1.8)), col)
			draw_line(c + Vector2(0, -r * 0.9), c + Vector2(0, r * 0.9), Color(0.1, 0.12, 0.15), 3.0)
		"rotate":
			draw_arc(c, r * 0.8, -PI * 0.2, PI * 1.3, 20, col, 6.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.6, -r * 1.0), c + Vector2(r * 1.2, -r * 0.2), c + Vector2(r * 0.2, -r * 0.3)]), col)
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.8, 0), c + Vector2(-r * 0.2, r * 0.6), c + Vector2(r * 0.9, -r * 0.7)]), col, 8.0, true)
		"close":
			draw_line(c + Vector2(-r * 0.7, -r * 0.7), c + Vector2(r * 0.7, r * 0.7), col, 7.0)
			draw_line(c + Vector2(r * 0.7, -r * 0.7), c + Vector2(-r * 0.7, r * 0.7), col, 7.0)
		"glow":
			draw_circle(c, r * 0.5, col)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.75, c + Vector2(cos(a), sin(a)) * r * 1.1, col, 4.0)
		_:
			draw_circle(c, r * 0.5, col)
