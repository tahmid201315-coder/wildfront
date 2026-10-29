class_name Fx
extends Node2D
## Pooled particle + floating-text system drawn in a single _draw call. Fixed capacity, no per-frame allocation churn.

const CAP := 420
const TEXT_CAP := 40

var _p: PackedVector2Array = PackedVector2Array()
var _v: PackedVector2Array = PackedVector2Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _max: PackedFloat32Array = PackedFloat32Array()
var _sz: PackedFloat32Array = PackedFloat32Array()
var _col: PackedColorArray = PackedColorArray()
var _grav: PackedFloat32Array = PackedFloat32Array()
var _kind: PackedByteArray = PackedByteArray()       # 0 dot, 1 ring, 2 streak, 3 spark(star), 4 smoke
var _next: int = 0
var count: int = 0

var _texts: Array = []
var font: Font


func _ready() -> void:
	_p.resize(CAP); _v.resize(CAP); _life.resize(CAP); _max.resize(CAP); _sz.resize(CAP)
	_col.resize(CAP); _grav.resize(CAP); _kind.resize(CAP)
	for i in CAP:
		_life[i] = 0.0
	font = ThemeDB.fallback_font
	z_index = 20


func _amount(n: int) -> int:
	var lvl: int = int(Game.settings.get("particles", 2))
	if Game.settings.get("battery_saver", false):
		lvl = mini(lvl, 1)
	var q: float = [0.2, 0.5, 1.0][clampi(lvl, 0, 2)]
	return maxi(int(round(n * q)), 1 if n > 0 else 0)


func _emit(pos: Vector2, vel: Vector2, life: float, size: float, col: Color, grav: float, kind: int) -> void:
	var i := _next
	_next = (_next + 1) % CAP
	_p[i] = pos; _v[i] = vel; _life[i] = life; _max[i] = life; _sz[i] = size
	_col[i] = col; _grav[i] = grav; _kind[i] = kind


func dust(pos: Vector2, n: int = 4) -> void:
	for i in _amount(n):
		_emit(pos + Vector2(randf_range(-8, 8), -2), Vector2(randf_range(-50, 50), randf_range(-45, -8)), randf_range(0.25, 0.45),
			randf_range(2.0, 4.2), Color(0.85, 0.82, 0.75, 0.55), -40.0, 4)


func ring(pos: Vector2, col: Color = Color.WHITE) -> void:
	_emit(pos, Vector2.ZERO, 0.35, 4.0, col, 0.0, 1)


func trail(pos: Vector2, dir: int) -> void:
	if Engine.get_physics_frames() % 2 == 0:
		_emit(pos + Vector2(-dir * 8.0, -20.0 + randf_range(-10, 10)), Vector2(-dir * 30.0, 0), 0.22, 16.0, Color(0.5, 0.9, 1.0, 0.5), 0.0, 2)


func burst(pos: Vector2, col: Color, n: int = 10, speed: float = 180.0) -> void:
	for i in _amount(n):
		var a := randf() * TAU
		var s := speed * randf_range(0.3, 1.0)
		_emit(pos, Vector2.from_angle(a) * s, randf_range(0.25, 0.55), randf_range(2.0, 4.0), col, 260.0, 0)


func sparkle(pos: Vector2, col: Color) -> void:
	_emit(pos, Vector2(randf_range(-12, 12), randf_range(-35, -10)), randf_range(0.5, 0.9), randf_range(2.0, 3.5), col, -10.0, 3)


func slash_hit(pos: Vector2, dir: int, col: Color = Color(1, 1, 0.85)) -> void:
	for i in _amount(7):
		var a := randf_range(-0.7, 0.7) + (0.0 if dir > 0 else PI)
		_emit(pos, Vector2.from_angle(a) * randf_range(140, 330), randf_range(0.12, 0.28), randf_range(10, 20), col, 0.0, 2)
	_emit(pos, Vector2.ZERO, 0.22, 3.0, col, 0.0, 1)


func number(pos: Vector2, text: String, col: Color = Color.WHITE, big: bool = false) -> void:
	if _texts.size() >= TEXT_CAP:
		_texts.pop_front()
	_texts.append({"p": pos + Vector2(randf_range(-6, 6), 0), "t": text, "c": col, "life": 0.8, "big": big})


func tick(dt: float) -> void:
	count = 0
	for i in CAP:
		if _life[i] <= 0.0:
			continue
		_life[i] -= dt
		if _life[i] <= 0.0:
			continue
		count += 1
		_v[i].y += _grav[i] * dt
		if _kind[i] == 4:
			_v[i] *= (1.0 - 2.0 * dt)
		_p[i] += _v[i] * dt
	for t in _texts:
		t["life"] -= dt
		t["p"] += Vector2(0, -42.0 * dt)
	_texts = _texts.filter(func(t): return t["life"] > 0.0)
	queue_redraw()


func clear() -> void:
	for i in CAP:
		_life[i] = 0.0
	_texts.clear()


func _draw() -> void:
	for i in CAP:
		var l := _life[i]
		if l <= 0.0:
			continue
		var u: float = 1.0 - l / _max[i]
		var c: Color = _col[i]
		match _kind[i]:
			0:
				c.a *= 1.0 - u * u
				draw_circle(_p[i], _sz[i] * (1.0 - u * 0.5), c)
			1:
				c.a *= 1.0 - u
				draw_arc(_p[i], 6.0 + u * 46.0, 0.0, TAU, 28, c, 3.0 * (1.0 - u) + 1.0, true)
			2:
				c.a *= 1.0 - u
				var d := _v[i].normalized() if _v[i].length() > 1.0 else Vector2.RIGHT
				draw_line(_p[i], _p[i] - d * _sz[i] * (1.0 - u * 0.5), c, 2.5, true)
			3:
				c.a *= 1.0 - u
				var s: float = _sz[i] * (1.0 - u * 0.4)
				draw_line(_p[i] + Vector2(-s, 0), _p[i] + Vector2(s, 0), c, 1.4, true)
				draw_line(_p[i] + Vector2(0, -s), _p[i] + Vector2(0, s), c, 1.4, true)
				draw_circle(_p[i], s * 0.4, Color(1, 1, 1, c.a))
			4:
				c.a *= (1.0 - u) * 0.8
				draw_circle(_p[i], _sz[i] * (1.0 + u), c)
	for t in _texts:
		var a: float = clampf(t["life"] / 0.35, 0.0, 1.0)
		var col: Color = t["c"]
		col.a = a
		var fs := 26 if t["big"] else 18
		draw_string(font, t["p"] + Vector2(1, 1), t["t"], HORIZONTAL_ALIGNMENT_CENTER, 120, fs, Color(0, 0, 0, a * 0.8))
		draw_string(font, t["p"], t["t"], HORIZONTAL_ALIGNMENT_CENTER, 120, fs, col)
