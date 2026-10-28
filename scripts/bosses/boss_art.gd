class_name BossArt
extends RefCounted
## Procedural drawings for the seven guardians. Origin = feet centre, boss faces +x.

static func draw_boss(b: Boss, m: Color) -> void:
	var t := b._anim_t
	var w := b.size.x
	var h := b.size.y
	var wind := b.tele  # 0..1 wind-up amount
	match b.id:
		"meadow_colossus": _colossus(b, m, t, w, h, wind)
		"furnace_behemoth": _behemoth(b, m, t, w, h, wind)
		"astral_watcher": _watcher(b, m, t, w, h, wind)
		"thorn_queen": _matriarch(b, m, t, w, h, wind)
		"frostbound_king": _regent(b, m, t, w, h, wind)
		"clockwork_sovereign": _sovereign(b, m, t, w, h, wind)
		_: _architect(b, m, t, w, h, wind)
	# soft ground shadow
	if not b.flying:
		b.draw_rect(Rect2(-w * 0.45, -3, w * 0.9, 5), Color(0, 0, 0, 0.25 * m.a))


static func _c(c: Color, m: Color) -> Color:
	return Color(c.r * m.r, c.g * m.g, c.b * m.b, c.a * m.a)


static func _colossus(b: Boss, m: Color, t: float, w: float, h: float, k: float) -> void:
	var stone := _c(Color(0.52, 0.5, 0.45), m)
	var dark := _c(Color(0.34, 0.33, 0.3), m)
	var moss := _c(Color(0.35, 0.65, 0.3), m)
	var bob := sin(t * 2.0) * 3.0
	var arm := -k * 40.0
	b.draw_rect(Rect2(-w * 0.34, -h * 0.35, w * 0.24, h * 0.35), dark)
	b.draw_rect(Rect2(w * 0.1, -h * 0.35, w * 0.24, h * 0.35), dark)
	b.draw_rect(Rect2(-w * 0.4, -h * 0.85 + bob, w * 0.8, h * 0.55), stone)
	b.draw_rect(Rect2(-w * 0.4, -h * 0.85 + bob, w * 0.8, h * 0.1), moss)
	b.draw_rect(Rect2(-w * 0.62, -h * 0.8 + bob + arm, w * 0.22, h * 0.5), dark)
	b.draw_rect(Rect2(w * 0.4, -h * 0.8 + bob + arm, w * 0.22, h * 0.5), dark)
	b.draw_rect(Rect2(-w * 0.2, -h * 1.05 + bob, w * 0.4, h * 0.25), stone)
	var eye := Color(1.0, 0.85, 0.3, m.a) if not b.vulnerable else Color(0.5, 1.0, 0.6, m.a)
	b.draw_circle(Vector2(w * 0.07, -h * 0.93 + bob), 6.0 + k * 3.0, eye)
	b.draw_circle(Vector2(-w * 0.07, -h * 0.93 + bob), 6.0 + k * 3.0, eye)
	for i in 5:
		b.draw_circle(Vector2(-w * 0.3 + i * w * 0.15, -h * 0.85 + bob), 7.0, moss)
	b.draw_circle(Vector2(0, -h * 0.55 + bob), 9.0, Color(0.6, 0.95, 1.0, m.a) if b.vulnerable else dark)


static func _behemoth(b: Boss, m: Color, t: float, w: float, h: float, k: float) -> void:
	var iron := _c(Color(0.3, 0.24, 0.24), m)
	var glow := _c(Color(1.0, 0.45 + 0.2 * sin(t * 6.0), 0.1), m)
	var step := sin(t * 5.0) * 4.0 * (1.0 if absf(b.vel.x) > 10.0 else 0.0)
	b.draw_rect(Rect2(-w * 0.38, -h * 0.3 - step, w * 0.22, h * 0.3 + step), iron)
	b.draw_rect(Rect2(w * 0.14, -h * 0.3 + step, w * 0.22, h * 0.3 - step), iron)
	b.draw_rect(Rect2(-w * 0.45, -h * 0.75, w * 0.9, h * 0.5), iron)
	b.draw_rect(Rect2(-w * 0.3, -h * 0.68, w * 0.6, h * 0.3), glow)
	b.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.15, -h * 0.72), Vector2(w * 0.55 + k * 20.0, -h * 0.82), Vector2(w * 0.5, -h * 0.5), Vector2(w * 0.15, -h * 0.45)]), iron)
	b.draw_circle(Vector2(w * 0.38, -h * 0.68), 6.0 + k * 4.0, glow)
	for i in 4:
		b.draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.35 + i * w * 0.2, -h * 0.75), Vector2(-w * 0.28 + i * w * 0.2, -h * 0.92), Vector2(-w * 0.2 + i * w * 0.2, -h * 0.75)]), glow)


static func _watcher(b: Boss, m: Color, t: float, w: float, h: float, k: float) -> void:
	var c := Vector2(0, -h * 0.5 + sin(t * 2.0) * 6.0)
	var brass := _c(Color(0.75, 0.65, 0.35), m)
	var eye := _c(Color(0.5, 0.85, 1.0), m)
	for i in 3:
		var r := w * (0.52 - i * 0.1)
		b.draw_arc(c, r, t * (0.8 + i * 0.4) * (1 if i % 2 == 0 else -1), t * (0.8 + i * 0.4) * (1 if i % 2 == 0 else -1) + TAU * 0.8, 28, brass, 5.0)
	b.draw_circle(c, w * 0.28, _c(Color(0.12, 0.16, 0.3), m))
	b.draw_circle(c + Vector2(6, 0), w * 0.18 + k * 8.0, eye)
	b.draw_circle(c + Vector2(10, 0), w * 0.08, _c(Color(0.05, 0.05, 0.15), m))


static func _matriarch(b: Boss, m: Color, t: float, w: float, h: float, k: float) -> void:
	var bark := _c(Color(0.32, 0.22, 0.14), m)
	var leaf := _c(Color(0.35, 0.7, 0.3), m)
	var pet := _c(Color(0.85, 0.35, 0.65), m)
	b.draw_rect(Rect2(-w * 0.2, -h * 0.7, w * 0.4, h * 0.7), bark)
	for i in 5:
		var a := -PI * 0.5 + (i - 2) * 0.55 + sin(t * 2.0 + i) * 0.1
		var tip := Vector2(0, -h * 0.6) + Vector2.from_angle(a) * (w * 0.6 + k * 20.0)
		b.draw_line(Vector2(0, -h * 0.6), tip, leaf, 8.0)
		b.draw_circle(tip, 9.0, leaf)
	b.draw_circle(Vector2(0, -h * 0.82), w * 0.26, pet)
	b.draw_circle(Vector2(0, -h * 0.82), w * 0.14, Color(1.0, 0.9, 0.4, m.a) if not b.vulnerable else Color(0.6, 1, 0.7, m.a))
	for i in 6:
		var a2 := TAU * i / 6.0 + t * 0.6
		b.draw_circle(Vector2(0, -h * 0.82) + Vector2.from_angle(a2) * w * 0.3, 10.0, pet)


static func _regent(b: Boss, m: Color, t: float, w: float, h: float, k: float) -> void:
	var ice := _c(Color(0.7, 0.88, 1.0), m)
	var deep := _c(Color(0.35, 0.55, 0.8), m)
	b.draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.4, 0), Vector2(-w * 0.28, -h * 0.7), Vector2(w * 0.28, -h * 0.7), Vector2(w * 0.4, 0)]), deep)
	b.draw_circle(Vector2(0, -h * 0.82), w * 0.2, ice)
	for i in 5:
		var x := (i - 2) * w * 0.11
		b.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, -h * 0.98), Vector2(x, -h * (1.12 + (0.08 if i == 2 else 0.0))), Vector2(x + 8, -h * 0.98)]), ice)
	b.draw_line(Vector2(w * 0.35, -h * 0.35), Vector2(w * 0.65 + k * 15.0, -h * 0.9), ice, 6.0)
	b.draw_circle(Vector2(w * 0.65 + k * 15.0, -h * 0.9), 10.0, Color(1, 1, 1, m.a))
	b.draw_circle(Vector2(w * 0.06, -h * 0.84), 4.0, _c(Color(0.1, 0.2, 0.6), m))


static func _sovereign(b: Boss, m: Color, t: float, w: float, h: float, k: float) -> void:
	var brass := _c(Color(0.82, 0.62, 0.25), m)
	var dark := _c(Color(0.3, 0.24, 0.16), m)
	var c := Vector2(0, -h * 0.55)
	b.draw_rect(Rect2(-w * 0.32, -h * 0.9, w * 0.64, h * 0.7), dark)
	for i in 3:
		var gc := c + Vector2((i - 1) * w * 0.28, (i % 2) * 12.0 - 6.0)
		for j in 8:
			var a := t * (2.0 if i % 2 == 0 else -2.0) + TAU * j / 8.0
			b.draw_line(gc, gc + Vector2.from_angle(a) * (22.0 + k * 6.0), brass, 6.0)
		b.draw_circle(gc, 14.0, brass)
		b.draw_circle(gc, 5.0, dark)
	b.draw_circle(Vector2(w * 0.06, -h * 0.9), 7.0, _c(Color(1.0, 0.4 if not b.vulnerable else 0.9, 0.2), m))
	b.draw_rect(Rect2(-w * 0.35, -h * 0.2, w * 0.2, h * 0.2), dark)
	b.draw_rect(Rect2(w * 0.15, -h * 0.2, w * 0.2, h * 0.2), dark)


static func _architect(b: Boss, m: Color, t: float, w: float, h: float, k: float) -> void:
	var c := Vector2(0, -h * 0.55 + sin(t * 1.5) * 8.0)
	var void_c := _c(Color(0.12, 0.05, 0.2), m)
	var gold := _c(Color(1.0, 0.85, 0.5), m)
	var pink := _c(Color(1.0, 0.4, 0.9), m)
	b.draw_circle(c, w * 0.32 + k * 6.0, void_c)
	b.draw_arc(c, w * 0.34, 0, TAU, 32, pink, 3.0)
	for i in 6:
		var a := t * 0.9 + TAU * i / 6.0
		var p0 := c + Vector2.from_angle(a) * w * 0.36
		b.draw_line(p0, c + Vector2.from_angle(a) * w * 0.55, gold, 5.0)
		b.draw_circle(c + Vector2.from_angle(a) * w * 0.55, 6.0, pink)
	b.draw_circle(c, w * 0.14, gold if not b.vulnerable else Color(1, 1, 1, m.a))
	b.draw_circle(c + Vector2(6, 0), w * 0.05, void_c)
	b.draw_arc(c, w * 0.62, -PI * 0.9, -PI * 0.1, 20, gold, 4.0)
