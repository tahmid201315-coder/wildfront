class_name PushBlock
extends Node2D
## A pushable stone block. Acts as a solid for Kael, can rest on pressure plates and is carried by platforms.

var stage: Stage
var level: Level
var vel: Vector2 = Vector2.ZERO
var top_only: bool = false
var delta: Vector2 = Vector2.ZERO
var on_floor: bool = false
var alive: bool = true
var home: Vector2 = Vector2.ZERO
const S := 32.0


func rect() -> Rect2:
	return Rect2(position.x - S * 0.5, position.y - S, S, S)


func solid_rect() -> Rect2:
	return rect()


func _ready() -> void:
	z_index = 3
	level = stage.level
	home = position
	level.solids.append(self)


func _exit_tree() -> void:
	if level != null:
		level.solids.erase(self)


func tick(dt: float) -> void:
	var before := position
	var p: Player = stage.player
	var pr := p.rect()
	var touch_l := Rect2(rect().position + Vector2(-3, 4), Vector2(3, S - 8))
	var touch_r := Rect2(rect().position + Vector2(S, 4), Vector2(3, S - 8))
	var want := 0.0
	var ix: float = p.inp.get("x", 0.0) if p.alive else 0.0
	if p.on_floor and touch_l.intersects(pr) and ix > 0.3:
		want = 1.0
	elif p.on_floor and touch_r.intersects(pr) and ix < -0.3:
		want = -1.0
	vel.x = want * 62.0
	vel.y = minf(vel.y + Tune.GRAVITY * dt, Tune.MAX_FALL)
	level.solids.erase(self)
	var res := level.move_body(rect(), vel, dt, false, true)
	level.solids.append(self)
	position = Vector2(res["rect"].position.x + S * 0.5, res["rect"].end.y)
	vel = res["vel"]
	on_floor = res["floor"]
	if on_floor and res["floor_obj"] != null and res["floor_obj"].get("delta") != null:
		position += res["floor_obj"].delta
	delta = position - before
	if want != 0.0 and absf(delta.x) > 0.1 and Engine.get_physics_frames() % 12 == 0:
		stage.fx.dust(position, 1)
	if position.y > level.pixel_size().y + 100.0:
		position = before
	queue_redraw()


func _draw() -> void:
	var th: Dictionary = Defs.REGIONS[level.region_id]
	var c: Color = th["stone"]
	draw_rect(Rect2(-S * 0.5, -S, S, S), c.darkened(0.1))
	draw_rect(Rect2(-S * 0.5, -S, S, S), Color(0.05, 0.05, 0.08), false, 3.0)
	draw_rect(Rect2(-S * 0.5 + 4, -S + 4, S - 8, S - 8), c.lightened(0.12), false, 2.0)
	draw_line(Vector2(-8, -16), Vector2(8, -16), th["accent"], 2.0)
	draw_line(Vector2(0, -24), Vector2(0, -8), th["accent"], 2.0)
