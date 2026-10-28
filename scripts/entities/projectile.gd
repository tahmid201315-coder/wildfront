class_name Projectile
extends Node2D
## Small pooled-by-stage projectile: friendly bolts (Kael) and hostile shots (enemies, bosses).

var stage: Stage
var vel: Vector2 = Vector2.ZERO
var damage: float = 8.0
var friendly: bool = false
var radius: float = 7.0
var life: float = 3.0
var kind: String = "orb"        # orb, bolt, arrow, shard, spore, flame, gear, void
var gravity: float = 0.0
var color: Color = Color(1, 0.4, 0.3)
var alive: bool = true
var pierce: int = 0
var uid: int = 0
var homing: float = 0.0
var _t: float = 0.0
var bounces: int = 0
static var _uid_counter: int = 10000


func _init() -> void:
	_uid_counter += 1
	uid = _uid_counter


func tick(dt: float) -> void:
	_t += dt
	life -= dt
	if life <= 0.0:
		_expire()
		return
	if homing > 0.0 and stage.player != null and not friendly:
		var want: Vector2 = (stage.player.center() - position).normalized() * vel.length()
		vel = vel.lerp(want, clampf(homing * dt, 0.0, 1.0))
	vel.y += gravity * dt
	var np := position + vel * dt
	var lvl: Level = stage.level
	if Tiles.is_solid(lvl.tile_at_px(np)):
		if bounces > 0:
			bounces -= 1
			vel = -vel * 0.8
			return
		_expire(true)
		return
	position = np
	queue_redraw()
	if friendly:
		var hb := Rect2(position - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
		var ids := {}
		for h in stage.hittables:
			if not is_instance_valid(h) or not h.alive:
				continue
			if h.hit_rect().intersects(hb):
				var info := {"damage": damage, "knock": Vector2(signf(vel.x) * 120.0, -40.0), "magic": true, "uid": uid, "from": position}
				if h.take_hit(info):
					stage.fx.burst(position, color, 8, 180.0)
					stage.fx.number(position + Vector2(0, -12), str(int(round(damage))), Color(0.6, 0.95, 1.0))
					Sfx.play("magic_hit")
					if pierce <= 0:
						_expire()
						return
					pierce -= 1
	else:
		var p: Player = stage.player
		if p != null and p.alive:
			var pr := p.rect()
			var c := position
			var cx := clampf(c.x, pr.position.x, pr.end.x)
			var cy := clampf(c.y, pr.position.y, pr.end.y)
			if Vector2(cx, cy).distance_to(c) <= radius:
				if stage.damage_player(damage, position.x, 0.8):
					_expire()


func _expire(hit_wall: bool = false) -> void:
	alive = false
	if hit_wall:
		stage.fx.burst(position, color, 5, 120.0)


func _draw() -> void:
	var c := color
	match kind:
		"bolt":
			draw_circle(Vector2.ZERO, radius + 5.0, Color(c.r, c.g, c.b, 0.25))
			draw_circle(Vector2.ZERO, radius, c)
			draw_circle(Vector2.ZERO, radius * 0.5, Color.WHITE)
			var d := -vel.normalized()
			draw_line(Vector2.ZERO, d * 22.0, Color(c.r, c.g, c.b, 0.6), 4.0, true)
		"arrow":
			var d2 := vel.normalized()
			draw_line(-d2 * 14.0, d2 * 10.0, Color(0.75, 0.9, 1.0), 3.0, true)
			draw_line(d2 * 10.0, d2 * 4.0 + d2.rotated(0.9) * 5.0, Color.WHITE, 2.0, true)
			draw_line(d2 * 10.0, d2 * 4.0 + d2.rotated(-0.9) * 5.0, Color.WHITE, 2.0, true)
			draw_circle(-d2 * 14.0, 3.0, Color(0.6, 0.8, 1.0, 0.7))
		"shard":
			var d3 := vel.normalized()
			var n := d3.rotated(PI * 0.5)
			draw_colored_polygon(PackedVector2Array([d3 * 11.0, n * 4.0, -d3 * 8.0, -n * 4.0]), Color(0.8, 0.95, 1.0))
		"spore":
			draw_circle(Vector2.ZERO, radius + 3.0, Color(0.8, 0.4, 0.9, 0.3))
			draw_circle(Vector2.ZERO, radius, Color(0.75, 0.35, 0.9))
			draw_circle(Vector2(-2, -2), radius * 0.35, Color(1, 0.9, 1, 0.9))
		"flame":
			draw_circle(Vector2.ZERO, radius + 4.0, Color(1.0, 0.4, 0.1, 0.35))
			draw_circle(Vector2.ZERO, radius, Color(1.0, 0.6, 0.15))
			draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 0.95, 0.6))
		"gear":
			var pts := PackedVector2Array()
			for i in 12:
				var a := _t * 8.0 + TAU * i / 12.0
				pts.append(Vector2.from_angle(a) * (radius if i % 2 == 0 else radius * 0.72))
			draw_colored_polygon(pts, Color(0.9, 0.7, 0.3))
			draw_circle(Vector2.ZERO, radius * 0.3, Color(0.2, 0.15, 0.1))
		"void":
			draw_circle(Vector2.ZERO, radius + 5.0, Color(0.9, 0.2, 0.8, 0.3))
			draw_circle(Vector2.ZERO, radius, Color(0.1, 0.0, 0.15))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, Color(1.0, 0.4, 0.9), 2.0, true)
		_:
			draw_circle(Vector2.ZERO, radius + 4.0, Color(c.r, c.g, c.b, 0.3))
			draw_circle(Vector2.ZERO, radius, c)
			draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1, 0.9))
