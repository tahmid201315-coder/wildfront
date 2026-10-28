class_name Pickup
extends Actor
## Dropped collectibles: shards, health, mana, dust. Magnetise to Kael when near.

var kind: String = "shard"
var amount: int = 1
var life: float = 40.0
var magnet: bool = false
var _pop: float = 0.25


func _ready() -> void:
	size = Vector2(14, 14)
	z_index = 4


func tick(dt: float) -> void:
	_anim_t += dt
	life -= dt
	_pop -= dt
	if life <= 0.0:
		alive = false
		return
	var p: Player = stage.player
	var d: Vector2 = p.center() - position
	if _pop <= 0.0 and p.alive:
		var mag: float = 90.0 + Game.equip_stat("magnet") + 40.0 * Game.skill("gatherer")
		if d.length() < mag:
			magnet = true
	if magnet:
		vel = d.normalized() * minf(560.0, 200.0 + 900.0 * (1.0 - clampf(d.length() / 200.0, 0.0, 1.0)))
		position += vel * dt
		if d.length() < 18.0 and p.alive:
			_collect()
	else:
		vel.x = move_toward(vel.x, 0.0, 300.0 * dt)
		step_physics(dt, true)
		if on_floor:
			vel.y = 0.0
		if d.length() < 22.0 and p.alive and _pop <= 0.0:
			_collect()
	queue_redraw()


func _collect() -> void:
	alive = false
	match kind:
		"shard":
			Game.add_shards(amount)
			stage.fx.number(stage.player.position + Vector2(0, -50), "+%d" % amount, Color(1.0, 0.85, 0.35))
			Sfx.play("shard")
		"heart":
			Game.hp = minf(Game.hp + 14.0 * amount, Game.max_hp())
			Game.stats_changed.emit()
			stage.fx.number(stage.player.position + Vector2(0, -50), "+HP", Color(1.0, 0.45, 0.5))
			Sfx.play("pickup")
		"mana":
			Game.mp = minf(Game.mp + 14.0 * amount, Game.max_mp())
			Game.stats_changed.emit()
			Sfx.play("pickup")
		"dust":
			Game.dust += amount
			Game.progress_changed.emit()
			stage.fx.number(stage.player.position + Vector2(0, -50), "+%d dust" % amount, Color(0.7, 0.9, 1.0))
			Sfx.play("pickup")
	stage.fx.sparkle(stage.player.center(), Color(1, 1, 0.8))


func _draw() -> void:
	var bob := sin(_anim_t * 5.0) * 2.0
	var blink := life < 5.0 and int(_anim_t * 10.0) % 2 == 0
	if blink:
		return
	var c := Vector2(0, -7 + bob)
	match kind:
		"shard":
			var pts := PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(0, 8), c + Vector2(-6, 0)])
			draw_circle(c, 11.0, Color(1.0, 0.85, 0.3, 0.2))
			draw_colored_polygon(pts, Color(1.0, 0.85, 0.3))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.6, 0.4, 0.05), 1.2)
			draw_line(c + Vector2(-2, -3), c + Vector2(1, -5), Color.WHITE, 1.5)
		"heart":
			draw_circle(c + Vector2(-3, -2), 4.5, Color(1.0, 0.3, 0.4))
			draw_circle(c + Vector2(3, -2), 4.5, Color(1.0, 0.3, 0.4))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-7.5, 0), c + Vector2(7.5, 0), c + Vector2(0, 9)]), Color(1.0, 0.3, 0.4))
		"mana":
			draw_circle(c, 9.0, Color(0.3, 0.7, 1.0, 0.25))
			draw_circle(c, 5.5, Color(0.4, 0.8, 1.0))
			draw_circle(c + Vector2(-1.5, -1.5), 2.0, Color.WHITE)
		"dust":
			draw_circle(c, 6.0, Color(0.7, 0.9, 1.0, 0.8))
			draw_circle(c, 3.0, Color.WHITE)
