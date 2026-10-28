class_name Backdrop
extends Node2D
## Procedural parallax background drawn in screen space (lives on a back CanvasLayer).
## Silhouette layers are generated once per region; ambient particles drift per region identity.

var region: String = "meadows"
var cam: Vector2 = Vector2.ZERO
var t: float = 0.0
var _layers: Array = []      # each {depth, color, pts(PackedVector2Array), base_y}
var _stars: Array = []
var _amb: Array = []
var _theme: Dictionary = {}
var _vp: Vector2 = Vector2(1280, 720)
var _special: Array = []


func setup(region_id: String) -> void:
	region = region_id
	_theme = Defs.REGIONS[region_id]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(region_id)
	_layers.clear()
	_stars.clear()
	_amb.clear()
	_special.clear()
	var top: Color = _theme["sky_top"]
	var bot: Color = _theme["sky_bot"]
	var n_layers := 4
	for i in n_layers:
		var depth := 0.12 + 0.17 * i
		var hill: Color = _theme["accent"] if region in ["meadows", "thornwild"] else _theme["stone"]
		var col := bot.lerp(hill, 0.3 + 0.2 * i).darkened(0.02 + 0.07 * i)
		if region in ["observatory", "eclipse", "ember", "clockwork"]:
			col = top.lerp(hill, 0.18 + 0.1 * i).darkened(0.1 * i)
		var pts := PackedVector2Array()
		var x := -200.0
		var base := 430.0 + 70.0 * i
		var amp := 130.0 - 20.0 * i
		while x < 3200.0:
			var step := rng.randf_range(40.0, 120.0)
			var hgt := _silhouette_height(i, rng, amp)
			pts.append(Vector2(x, base - hgt))
			x += step
		_layers.append({"depth": depth, "color": col, "pts": pts, "base": base, "period": 3400.0})
	for i in 90:
		_stars.append(Vector3(rng.randf() * 1300.0, rng.randf() * 420.0, rng.randf_range(0.5, 1.6)))
	var amb_n := 28
	for i in amb_n:
		_amb.append({"x": rng.randf() * 1400.0, "y": rng.randf() * 760.0, "s": rng.randf_range(0.5, 1.5), "ph": rng.randf() * TAU})
	for i in 14:
		_special.append({"x": rng.randf() * 2800.0, "y": rng.randf_range(60.0, 400.0), "r": rng.randf_range(30.0, 90.0), "ph": rng.randf() * TAU})


func _silhouette_height(layer: int, rng: RandomNumberGenerator, amp: float) -> float:
	match region:
		"meadows": return rng.randf_range(10.0, amp)                          # rolling hills
		"ember": return rng.randf_range(0.0, amp * 1.2) if rng.randf() > 0.3 else 0.0   # jagged stalagmites
		"observatory": return (amp * 0.9 if rng.randf() > 0.55 else rng.randf_range(0, 30.0))   # pillars
		"thornwild": return rng.randf_range(30.0, amp * 1.3)                  # tree trunks
		"frostfall": return rng.randf_range(0.0, amp * 1.4)                    # ice peaks
		"clockwork": return rng.randf_range(20.0, amp * 1.1)
		_: return rng.randf_range(0.0, amp * 1.5)


func update_view(cam_pos: Vector2, viewport: Vector2, dt: float) -> void:
	cam = cam_pos
	_vp = viewport
	t += dt
	queue_redraw()


func _draw() -> void:
	if _theme.is_empty():
		return
	var top: Color = _theme["sky_top"]
	var bot: Color = _theme["sky_bot"]
	var vp := _vp
	# sky gradient (6 bands is plenty for a smooth look and cheap)
	var bands := 36
	for i in bands:
		var c := top.lerp(bot, float(i) / float(bands - 1))
		draw_rect(Rect2(0, vp.y * i / bands, vp.x, vp.y / bands + 1.0), c)
	# region-specific far elements
	_draw_far()
	for l in _layers:
		var par: float = l["depth"]
		var off := fposmod(-cam.x * par, l["period"])
		var pts: PackedVector2Array = l["pts"]
		var base_y: float = l["base"] - cam.y * par * 0.25
		for rep in 2:
			var poly := PackedVector2Array()
			poly.append(Vector2(pts[0].x + off - l["period"] * rep, vp.y + 40.0))
			for p in pts:
				poly.append(Vector2(p.x + off - l["period"] * rep, base_y - (l["base"] - p.y) + 0.0))
			poly.append(Vector2(pts[pts.size() - 1].x + off - l["period"] * rep, vp.y + 40.0))
			if poly.size() >= 3:
				draw_colored_polygon(poly, l["color"])
		_draw_layer_detail(l, off, base_y)
	_draw_ambient()


func _draw_far() -> void:
	var glow: Color = _theme["glow"]
	match region:
		"meadows":
			draw_circle(Vector2(_vp.x * 0.78 - cam.x * 0.02, 120.0), 52.0, Color(1.0, 0.97, 0.8, 0.95))
			draw_circle(Vector2(_vp.x * 0.78 - cam.x * 0.02, 120.0), 80.0, Color(1.0, 0.97, 0.8, 0.18))
			for c in _special:
				var x := fposmod(c["x"] - cam.x * 0.05 + t * 8.0, 1500.0) - 100.0
				draw_circle(Vector2(x, 90.0 + c["y"] * 0.4), c["r"] * 0.5, Color(1, 1, 1, 0.55))
				draw_circle(Vector2(x + 30.0, 98.0 + c["y"] * 0.4), c["r"] * 0.38, Color(1, 1, 1, 0.55))
				draw_circle(Vector2(x - 28.0, 100.0 + c["y"] * 0.4), c["r"] * 0.34, Color(1, 1, 1, 0.55))
		"ember":
			draw_circle(Vector2(_vp.x * 0.5, _vp.y + 40.0), 360.0, Color(1.0, 0.3, 0.05, 0.16))
			draw_circle(Vector2(_vp.x * 0.5, _vp.y + 40.0), 230.0, Color(1.0, 0.45, 0.1, 0.16))
		"observatory", "eclipse":
			for s in _stars:
				var tw := 0.6 + 0.4 * sin(t * 2.0 + s.x)
				draw_circle(Vector2(fposmod(s.x - cam.x * 0.03, 1300.0), s.y), s.z, Color(1, 1, 1, tw * 0.9))
			if region == "eclipse":
				var c := Vector2(_vp.x * 0.7 - cam.x * 0.02, 150.0)
				draw_circle(c, 92.0, Color(1.0, 0.45, 0.9, 0.18))
				draw_circle(c, 70.0, Color(1.0, 0.6, 0.95, 0.5))
				draw_circle(c, 64.0, Color(0.01, 0.0, 0.03))
			else:
				draw_circle(Vector2(_vp.x * 0.25, 110.0), 40.0, Color(0.85, 0.95, 1.0, 0.9))
				draw_circle(Vector2(_vp.x * 0.25 + 12.0, 102.0), 36.0, _theme["sky_top"])
		"thornwild":
			for i in 5:
				var x := fposmod(i * 330.0 - cam.x * 0.08, 1700.0) - 200.0
				draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 90, 0), Vector2(x + 140, _vp.y)]), Color(1.0, 0.95, 0.7, 0.05))
		"frostfall":
			for s in _stars:
				var y := fposmod(s.y * 1.7 + t * (60.0 + 40.0 * s.z), _vp.y)
				var x := fposmod(s.x - cam.x * 0.2 - t * 90.0 * s.z, _vp.x + 100.0)
				draw_line(Vector2(x, y), Vector2(x - 12.0, y + 4.0), Color(1, 1, 1, 0.5), 1.4)
		"clockwork":
			for c in _special:
				var cx := fposmod(c["x"] - cam.x * 0.1, 3000.0) - 300.0
				_draw_gear(Vector2(cx, c["y"]), c["r"] * 1.6, t * 0.35 * (1.0 if int(c["x"]) % 2 == 0 else -1.0) + c["ph"], Color(0.25, 0.2, 0.1, 0.5))


func _draw_gear(c: Vector2, r: float, rot: float, col: Color) -> void:
	var teeth := 10
	var pts := PackedVector2Array()
	for i in teeth * 2:
		var a := rot + TAU * i / (teeth * 2.0)
		var rr := r if i % 2 == 0 else r * 0.82
		pts.append(c + Vector2.from_angle(a) * rr)
	draw_colored_polygon(pts, col)
	draw_circle(c, r * 0.4, Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, col.a))


func _draw_layer_detail(l: Dictionary, off: float, base_y: float) -> void:
	if region == "thornwild" or region == "meadows":
		return
	if region == "observatory" and l["depth"] > 0.4:
		draw_rect(Rect2(0, _vp.y - 60.0, _vp.x, 60.0), Color(0.1, 0.35, 0.55, 0.25))


func _draw_ambient() -> void:
	var glow: Color = _theme["glow"]
	var q: int = int(Game.settings.get("particles", 2))
	var count := _amb.size() if q >= 2 else (_amb.size() / 2 if q == 1 else 4)
	for i in count:
		var a: Dictionary = _amb[i]
		var s: float = a["s"]
		match region:
			"meadows":
				var x := fposmod(a["x"] + t * 14.0 * s - cam.x * 0.3, _vp.x + 60.0)
				var y := fposmod(a["y"] * 0.6 + t * 10.0 * s, _vp.y)
				draw_circle(Vector2(x, y), 2.0 * s, Color(1.0, 1.0, 0.7, 0.5))
			"ember":
				var x2 := fposmod(a["x"] - cam.x * 0.3 + sin(t + a["ph"]) * 20.0, _vp.x + 40.0)
				var y2 := fposmod(a["y"] - t * 40.0 * s, _vp.y + 20.0)
				draw_circle(Vector2(x2, y2), 2.0 * s, Color(1.0, 0.55 + 0.3 * s * 0.5, 0.2, 0.7))
			"observatory":
				var x3 := fposmod(a["x"] - cam.x * 0.2 + sin(t * 0.7 + a["ph"]) * 14.0, _vp.x + 40.0)
				var y3 := fposmod(a["y"] - t * 25.0 * s, _vp.y + 20.0)
				draw_arc(Vector2(x3, y3), 3.0 * s, 0, TAU, 10, Color(0.7, 0.95, 1.0, 0.5), 1.2)
			"thornwild":
				var x4 := fposmod(a["x"] - cam.x * 0.25 + sin(t * 0.6 + a["ph"]) * 30.0, _vp.x + 40.0)
				var y4 := fposmod(a["y"] * 0.9 + sin(t * 0.8 + a["ph"]) * 20.0, _vp.y)
				var tw := 0.4 + 0.6 * sin(t * 2.0 + a["ph"]) * sin(t * 2.0 + a["ph"])
				draw_circle(Vector2(x4, y4), 2.4 * s, Color(glow.r, glow.g, glow.b, tw))
			"frostfall":
				pass
			"clockwork":
				var x5 := fposmod(a["x"] - cam.x * 0.3, _vp.x + 40.0)
				var y5 := fposmod(a["y"] - t * 20.0 * s, _vp.y + 20.0)
				draw_rect(Rect2(x5, y5, 2.5 * s, 2.5 * s), Color(1.0, 0.8, 0.4, 0.5))
			_:
				var x6 := fposmod(a["x"] - cam.x * 0.2, _vp.x + 40.0)
				var y6 := fposmod(a["y"] + sin(t * 0.5 + a["ph"]) * 30.0 - t * 12.0, _vp.y + 20.0)
				draw_circle(Vector2(x6, y6), 1.8 * s, Color(glow.r, glow.g, glow.b, 0.5))
