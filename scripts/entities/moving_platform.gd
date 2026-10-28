class_name MovingPlatform
extends Node2D
## A platform travelling between points. Actors standing on it are carried (see Actor.step_physics).
## Frozen by the Stasis Pulse.

var level: Level
var points: Array = []          # world-space Vector2 waypoints (ping-pong)
var speed: float = 70.0
var width: float = 96.0
var height: float = 16.0
var top_only: bool = true
var delta: Vector2 = Vector2.ZERO
var frozen_t: float = 0.0
var _i: int = 0
var _dir: int = 1
var theme: Dictionary = {}
var _gear_rot: float = 0.0


func setup(lv: Level, pts: Array, spd: float, w: float = 96.0) -> void:
	level = lv
	points = pts
	speed = spd
	width = w
	position = points[0]
	theme = lv.theme
	if lv.solids.find(self) < 0:
		lv.solids.append(self)


func solid_rect() -> Rect2:
	return Rect2(position.x - width * 0.5, position.y, width, height)


func tick(dt: float) -> void:
	delta = Vector2.ZERO
	frozen_t = maxf(frozen_t - dt, 0.0)
	if frozen_t > 0.0 or points.size() < 2:
		queue_redraw()
		return
	var target: Vector2 = points[_i + _dir]
	var to := target - position
	var step := speed * dt
	if to.length() <= step:
		delta = to
		position = target
		_i += _dir
		if _i + _dir < 0 or _i + _dir >= points.size():
			_dir = -_dir
	else:
		delta = to.normalized() * step
		position += delta
	_gear_rot += dt * 2.0
	queue_redraw()


func _draw() -> void:
	var w := width
	var c: Color = theme.get("stone", Color(0.5, 0.5, 0.5))
	var a: Color = theme.get("accent", Color.WHITE)
	var r := Rect2(-w * 0.5, 0, w, height)
	draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.3))
	draw_rect(r, c.darkened(0.35))
	draw_rect(Rect2(r.position, Vector2(w, 5)), c.lightened(0.2))
	draw_rect(Rect2(r.position + Vector2(0, 5), Vector2(w, 2)), a.darkened(0.2))
	for i in range(8, int(w) - 4, 24):
		draw_rect(Rect2(-w * 0.5 + i, 9, 10, 4), c.darkened(0.6))
	if frozen_t > 0.0:
		draw_rect(r.grow(2), Color(0.7, 0.95, 1.0, 0.35))
	draw_circle(Vector2(-w * 0.5 + 6, 8), 3, a)
	draw_circle(Vector2(w * 0.5 - 6, 8), 3, a)
