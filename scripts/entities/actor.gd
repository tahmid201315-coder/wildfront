class_name Actor
extends Node2D
## Base for anything that moves through the level with tile collision. position = feet centre.
## Entities are ticked explicitly by the Stage (tick(dt)); they do not use _physics_process.

var stage: Stage = null
var level: Level = null
var size: Vector2 = Vector2(24, 40)
var vel: Vector2 = Vector2.ZERO
var facing: int = 1
var on_floor: bool = false
var floor_tile: int = 0
var floor_obj: Node = null
var wall_hit: int = 0
var ceil_hit: bool = false
var gravity_scale: float = 1.0
var alive: bool = true
var _anim_t: float = 0.0


func rect() -> Rect2:
	return Rect2(position.x - size.x * 0.5, position.y - size.y, size.x, size.y)


func center() -> Vector2:
	return Vector2(position.x, position.y - size.y * 0.5)


func set_rect_pos(r: Rect2) -> void:
	position = Vector2(r.position.x + size.x * 0.5, r.end.y)


## Applies gravity (optional) and tile/solid collision. Returns the collision result.
func step_physics(dt: float, apply_gravity: bool = true, drop: bool = false) -> Dictionary:
	if apply_gravity:
		vel.y = minf(vel.y + Tune.GRAVITY * gravity_scale * dt, Tune.MAX_FALL)
	# ride a moving platform
	if floor_obj != null and is_instance_valid(floor_obj) and floor_obj.get("delta") != null:
		position += floor_obj.delta
	var res := level.move_body(rect(), vel, dt, drop)
	set_rect_pos(res["rect"])
	vel = res["vel"]
	on_floor = res["floor"]
	floor_tile = res["floor_tile"]
	floor_obj = res["floor_obj"]
	wall_hit = res["wall"]
	ceil_hit = res["ceil"]
	return res


func tick(_dt: float) -> void:
	pass
