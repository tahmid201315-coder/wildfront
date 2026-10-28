class_name Breakable
extends Node2D
## A cracked wall tile (tile 'X'). Any sword hit or bolt breaks it, opening hidden rooms and shortcuts.

var stage: Stage
var tx: int = 0
var ty: int = 0
var alive: bool = true
var uid: int = 0
static var _c: int = 90000


func _init() -> void:
	_c += 1
	uid = _c


func hit_rect() -> Rect2:
	return Rect2(tx * Level.T, ty * Level.T, Level.T, Level.T)


func take_hit(_info: Dictionary) -> bool:
	if not alive:
		return false
	alive = false
	stage.level.set_tile(tx, ty, Tiles.AIR)
	var c := hit_rect().get_center()
	stage.fx.burst(c, Color(0.7, 0.65, 0.6), 10, 200.0)
	stage.fx.dust(c + Vector2(0, 16), 5)
	stage.shake(2.0)
	Sfx.play("break")
	Game.set_flag("broke_%s_%d_%d" % [stage.room_id, tx, ty])
	Game.event.emit("secret")
	return true
