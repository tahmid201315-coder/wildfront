class_name Hazard
extends Node2D
## Dynamic damaging objects: crushers, laser gates and saw blades. All freeze under the Stasis Pulse.
## Laser gates are the "dash hazard" puzzle: Kael's dash grants invulnerability frames, so a well-timed dash passes through.

var stage: Stage
var kind: String = "crusher"
var damage: float = 16.0
var alive: bool = true
var frozen_t: float = 0.0
var t: float = 0.0
var props: Dictionary = {}
var w: float = 64.0
var h: float = 64.0
var drop: float = 128.0
var _y_off: float = 0.0
var _on: bool = false
var _warn: bool = false
var _pts: Array = []
var _i: int = 0
var _dir: int = 1
var theme: Dictionary = {}
var period: float = 3.0
var phase: float = 0.0


static func create(k: String, p: Dictionary) -> Hazard:
	var hz := Hazard.new()
	hz.kind = k
	hz.props = p
	return hz


func _ready() -> void:
	z_index = 6
	theme = Defs.REGIONS[stage.level.region_id]
	period = float(props.get("period", 3.0))
	phase = float(props.get("phase", 0.0))
	t = phase
	match kind:
		"crusher":
			w = float(props.get("w", 64))
			h = 56.0
			drop = float(props.get("drop", 128))
			damage = 22.0
		"laser":
			w = float(props.get("len", 160))
			h = 8.0
			damage = 14.0
		"saw":
			w = 40.0
			h = 40.0
			damage = 16.0
			_pts = props.get("pts", [])


func freeze(sec: float) -> void:
	frozen_t = maxf(frozen_t, sec)


func hurt_rect() -> Rect2:
	match kind:
		"crusher":
			if _y_off < 6.0:
				return Rect2()
			return Rect2(position.x - w * 0.5, position.y + _y_off, w, h).grow(-4.0)
		"laser":
			if not _on:
				return Rect2()
			if props.get("vertical", false):
				return Rect2(position.x - 4.0, position.y, 8.0, w)
			return Rect2(position.x, position.y - 4.0, w, 8.0)
		"saw":
			return Rect2(position.x - 15.0, position.y - 15.0, 30.0, 30.0)
	return Rect2()


func tick(dt: float) -> void:
	if frozen_t > 0.0:
		frozen_t -= dt
		queue_redraw()
		return
	t += dt
	match kind:
		"crusher":
			var c := fmod(t, period)
			var rest := period * 0.45
			var tele := 0.35
			if c < rest:
				_y_off = move_toward(_y_off, 0.0, 180.0 * dt)
				_warn = false
			elif c < rest + tele:
				_warn = true
			elif c < rest + tele + 0.5:
				_warn = false
				_y_off = move_toward(_y_off, drop, 1500.0 * dt)
				if _y_off >= drop - 1.0 and not _hit_ground:
					_hit_ground = true
					stage.shake(3.0)
					stage.fx.dust(position + Vector2(0, drop + h), 6)
			else:
				_y_off = move_toward(_y_off, 0.0, 120.0 * dt)
				_hit_ground = false
		"laser":
			var c2 := fmod(t, period)
			_warn = c2 > period * 0.55 and c2 < period * 0.75
			_on = c2 >= period * 0.75
		"saw":
			if _pts.size() >= 2:
				var tgt: Array = _pts[_i + _dir]
				var tp := Vector2(tgt[0], tgt[1])
				var dv := tp - position
				var step := float(props.get("speed", 90.0)) * dt
				if dv.length() <= step:
					position = tp
					_i += _dir
					if _i + _dir < 0 or _i + _dir >= _pts.size():
						_dir = -_dir
				else:
					position += dv.normalized() * step
	queue_redraw()


var _hit_ground: bool = false


func _draw() -> void:
	var a: Color = theme.get("accent", Color.WHITE)
	var st_c: Color = theme.get("stone", Color.GRAY)
	var ice := frozen_t > 0.0
	match kind:
		"crusher":
			# chain/rail
			draw_line(Vector2(0, -400), Vector2(0, _y_off), st_c.darkened(0.4), 3.0)
			var r := Rect2(-w * 0.5, _y_off, w, h)
			draw_rect(r, st_c.darkened(0.2))
			draw_rect(r, Color(0.05, 0.05, 0.08), false, 3.0)
			for i in 4:
				var x := -w * 0.5 + 8.0 + i * (w - 16.0) / 3.0
				draw_colored_polygon(PackedVector2Array([Vector2(x - 6, _y_off + h), Vector2(x + 6, _y_off + h), Vector2(x, _y_off + h + 11)]), Color(0.85, 0.85, 0.9))
			if _warn:
				draw_rect(Rect2(-w * 0.5, drop + h, w, 6.0), Color(1.0, 0.3, 0.2, 0.5 + 0.4 * sin(t * 40.0)))
			if ice:
				draw_rect(r.grow(2), Color(0.7, 0.95, 1.0, 0.4))
		"laser":
			var v: bool = props.get("vertical", false)
			var e := Vector2(0, w) if v else Vector2(w, 0)
			draw_circle(Vector2.ZERO, 8.0, Color(0.2, 0.2, 0.25))
			draw_circle(e, 8.0, Color(0.2, 0.2, 0.25))
			if _on:
				draw_line(Vector2.ZERO, e, Color(1.0, 0.2, 0.3, 0.3), 12.0)
				draw_line(Vector2.ZERO, e, Color(1.0, 0.85, 0.9), 4.0)
			elif _warn:
				draw_line(Vector2.ZERO, e, Color(1.0, 0.3, 0.3, 0.4 + 0.3 * sin(t * 30.0)), 2.0)
			else:
				draw_line(Vector2.ZERO, e, Color(1.0, 0.3, 0.3, 0.12), 1.0)
			if ice:
				draw_circle(Vector2.ZERO, 12.0, Color(0.7, 0.95, 1.0, 0.5))
		"saw":
			var pts := PackedVector2Array()
			for i in 16:
				var ang := t * 9.0 + TAU * i / 16.0
				pts.append(Vector2.from_angle(ang) * (20.0 if i % 2 == 0 else 14.0))
			draw_colored_polygon(pts, Color(0.8, 0.82, 0.88) if not ice else Color(0.7, 0.95, 1.0))
			draw_circle(Vector2.ZERO, 5.0, Color(0.2, 0.2, 0.25))
