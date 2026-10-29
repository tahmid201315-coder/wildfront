class_name Enemy
extends Actor
## One class, eight state machines. Each kind has a data row and a _think_<kind> function.
## Every attack is telegraphed (wind-up with a visible tell) and leaves a vulnerability window.

const DATA := {
	"slime":   {"name": "Sky Slime", "hp": 24.0, "dmg": 8.0, "speed": 90.0, "size": Vector2(30, 24), "shards": 2, "xp": 4, "flying": false},
	"guard":   {"name": "Ruin Guard", "hp": 48.0, "dmg": 14.0, "speed": 55.0, "size": Vector2(30, 46), "shards": 5, "xp": 9, "flying": false},
	"crawler": {"name": "Ember Crawler", "hp": 30.0, "dmg": 12.0, "speed": 70.0, "size": Vector2(38, 22), "shards": 3, "xp": 6, "flying": false},
	"archer":  {"name": "Crystal Archer", "hp": 28.0, "dmg": 11.0, "speed": 70.0, "size": Vector2(24, 44), "shards": 4, "xp": 8, "flying": false},
	"stalker": {"name": "Thorn Stalker", "hp": 40.0, "dmg": 15.0, "speed": 80.0, "size": Vector2(34, 36), "shards": 5, "xp": 10, "flying": false},
	"knight":  {"name": "Frost Knight", "hp": 80.0, "dmg": 18.0, "speed": 60.0, "size": Vector2(34, 52), "shards": 8, "xp": 16, "flying": false},
	"drone":   {"name": "Clockwork Drone", "hp": 26.0, "dmg": 12.0, "speed": 110.0, "size": Vector2(30, 26), "shards": 4, "xp": 9, "flying": true},
	"wraith":  {"name": "Eclipse Wraith", "hp": 44.0, "dmg": 16.0, "speed": 100.0, "size": Vector2(30, 46), "shards": 7, "xp": 14, "flying": true},
}

var kind: String = "slime"
var uid: int = 0
var elite: bool = false
var hp: float = 20.0
var max_hp: float = 20.0
var contact_damage: float = 8.0
var speed: float = 80.0
var flying: bool = false
var state: String = "idle"
var st: float = 0.0                  # time in state
var home: Vector2 = Vector2.ZERO
var patrol: float = 120.0
var hurt_t: float = 0.0
var stagger_t: float = 0.0
var frozen_t: float = 0.0
var armor_front: float = 0.0         # fraction of damage blocked from the front
var super_armor: bool = false
var dir_to_player: int = 1
var aggro: float = 280.0
var tele: float = 0.0                # 0..1 telegraph intensity for drawing
var vulnerable: bool = true
var dying: float = -1.0
var fade: float = 1.0
var _atk_cd: float = 0.0
var _aim: Vector2 = Vector2.ZERO
var _flag: bool = false
var static_uid: int = 0
static var _counter: int = 0


static func create(k: String) -> Enemy:
	var e := Enemy.new()
	e.kind = k
	_counter += 1
	e.uid = _counter
	return e


func _ready() -> void:
	var d: Dictionary = DATA[kind]
	size = d["size"]
	var diff := Game.difficulty()
	max_hp = float(d["hp"]) * float(diff["enemy_hp"])
	hp = max_hp
	contact_damage = float(d["dmg"])
	speed = float(d["speed"])
	flying = d["flying"]
	aggro = 300.0 * float(diff["aggro"])
	home = position
	if elite:
		max_hp *= 2.2
		hp = max_hp
		contact_damage *= 1.3
		size *= 1.15
		modulate = Color(1.25, 1.0, 0.6)
	z_index = 4
	facing = -1 if int(position.x) % 2 == 0 else 1
	match kind:
		"guard": armor_front = 0.5
		"knight": armor_front = 0.35
		"stalker": contact_damage = 0.0
		"wraith": contact_damage = 0.0
		"archer": contact_damage = 4.0
	state = "idle" if kind != "stalker" else "hide"


func hit_rect() -> Rect2:
	return rect().grow(2.0)


func contact_rect() -> Rect2:
	var r := rect()
	return r.grow(-4.0)


func take_hit(info: Dictionary) -> bool:
	if not alive or dying >= 0.0:
		return false
	if kind == "wraith" and state in ["fade", "appear"]:
		return false
	var dmg: float = info["damage"]
	var knock: Vector2 = info.get("knock", Vector2(80, -60))
	var from_left: bool = float(info["from"].x if info.get("from") is Vector2 else position.x - 1.0) < position.x
	var blocked := 0.0
	if armor_front > 0.0 and state in ["idle", "patrol", "walk", "tele"]:
		var front_dir := facing
		if (from_left and front_dir < 0) or (not from_left and front_dir > 0):
			blocked = armor_front
			if dmg < 14.0 and not info.get("magic", false):
				blocked = armor_front
			else:
				blocked = armor_front * 0.4
	if kind == "stalker" and state == "hide":
		_wake()
	dmg *= (1.0 - blocked)
	if frozen_t > 0.0:
		dmg *= 1.25
	hp -= dmg
	hurt_t = 0.15
	if blocked > 0.0:
		stage.fx.burst(center() + Vector2(facing * 14.0, 0), Color(0.8, 0.9, 1.0), 4, 120.0)
		Sfx.play("block")
	else:
		Sfx.play("hit")
	if not super_armor:
		stagger_t = 0.22 if dmg < 14.0 else 0.4
		if not flying or kind == "drone":
			vel = Vector2(knock.x * (0.55 if kind in ["knight", "guard"] else 1.0), knock.y)
		else:
			vel = Vector2(knock.x, knock.y * 0.5)
		if state in ["tele", "attack", "charge", "dive", "leap", "shoot"]:
			_go("recover" if kind != "slime" else "idle")
	if hp <= 0.0:
		_die()
	return true


func freeze(t: float) -> void:
	frozen_t = maxf(frozen_t, t)
	stage.fx.ring(center(), Color(0.6, 0.85, 1.0))


func _die() -> void:
	dying = 0.0
	alive = false          # stops contact damage and hits immediately
	kills_notify()
	stage.fx.burst(center(), Color(1, 0.95, 0.8), 14, 240.0)
	stage.fx.burst(center(), Color(DATA_COLOR[kind]), 14, 200.0)
	stage.shake(3.0)
	Sfx.play("enemy_die")
	stage.drop_loot(center(), int(DATA[kind]["shards"]) * (4 if elite else 1), 0.18, 0.16)
	if elite:
		Achievements.bump("elites")
		Game.event.emit("elite")
	Game.add_xp(int(DATA[kind]["xp"]))
	Game.enemy_killed.emit(kind)
	if is_inside_tree():
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)


func kills_notify() -> void:
	stage.kills += 1


const DATA_COLOR := {
	"slime": Color(0.5, 0.9, 1.0), "guard": Color(0.8, 0.8, 0.7), "crawler": Color(1.0, 0.5, 0.2), "archer": Color(0.6, 0.85, 1.0),
	"stalker": Color(0.7, 0.4, 0.9), "knight": Color(0.8, 0.95, 1.0), "drone": Color(1.0, 0.8, 0.3), "wraith": Color(1.0, 0.4, 0.85),
}


func _go(s: String) -> void:
	state = s
	st = 0.0
	tele = 0.0


func _wake() -> void:
	if state == "hide":
		_go("tele")


func _player_dx() -> float:
	return stage.player.position.x - position.x


func _player_dist() -> float:
	return stage.player.center().distance_to(center())


func _can_see() -> bool:
	if not stage.player.alive:
		return false
	var d := _player_dist()
	if d > aggro:
		return false
	return absf(stage.player.position.y - position.y) < 150.0 or flying


func _face_player() -> void:
	dir_to_player = 1 if _player_dx() >= 0.0 else -1
	facing = dir_to_player


func tick(dt: float) -> void:
	if dying >= 0.0:
		return
	_anim_t += dt
	st += dt
	hurt_t = maxf(hurt_t - dt, 0.0)
	_atk_cd = maxf(_atk_cd - dt, 0.0)
	if frozen_t > 0.0:
		frozen_t -= dt
		if not flying:
			vel.x = 0.0
			vel.y = minf(vel.y + Tune.GRAVITY * dt, Tune.MAX_FALL)
			step_physics(dt, false)
		queue_redraw()
		return
	if stagger_t > 0.0:
		stagger_t -= dt
		vel.x = move_toward(vel.x, 0.0, 600.0 * dt)
		if flying:
			vel.y = move_toward(vel.y, 0.0, 600.0 * dt)
			_fly_move(dt)
		else:
			step_physics(dt, true)
		queue_redraw()
		return
	match kind:
		"slime": _think_slime(dt)
		"guard": _think_guard(dt)
		"crawler": _think_crawler(dt)
		"archer": _think_archer(dt)
		"stalker": _think_stalker(dt)
		"knight": _think_knight(dt)
		"drone": _think_drone(dt)
		"wraith": _think_wraith(dt)
	queue_redraw()


func _fly_move(dt: float) -> void:
	var r := rect()
	var res := level.move_body(r, vel, dt, true, false)
	set_rect_pos(res["rect"])
	vel = res["vel"]
	on_floor = res["floor"]
	wall_hit = res["wall"]


func _walk(dt: float, dir: int, spd: float) -> void:
	vel.x = move_toward(vel.x, dir * spd, 900.0 * dt)
	var ahead_x := position.x + dir * (size.x * 0.5 + 6.0)
	var edge := not Tiles.is_solid(level.tile_at_px(Vector2(ahead_x, position.y + 6.0))) and level.tile_at_px(Vector2(ahead_x, position.y + 6.0)) != Tiles.ONEWAY
	step_physics(dt, true)
	if on_floor and (wall_hit != 0 or edge):
		patrol_flip()


func patrol_flip() -> void:
	facing = -facing
	vel.x = 0.0


# ---------------------------------------------------------------- 1. Sky Slime: hop & squash
func _think_slime(dt: float) -> void:
	match state:
		"idle":
			vel.x = move_toward(vel.x, 0.0, 800.0 * dt)
			step_physics(dt, true)
			if on_floor and st > 0.9 and _can_see() and _atk_cd <= 0.0:
				_face_player()
				_go("tele")
			elif on_floor and st > 1.6:
				facing = -facing if randf() < 0.5 else facing
				_go("tele")
		"tele":
			tele = clampf(st / 0.4, 0.0, 1.0)
			vel.x = 0.0
			step_physics(dt, true)
			if st >= 0.4:
				var power := 1.0 if _can_see() else 0.5
				vel = Vector2(facing * 150.0 * power, -420.0 * (0.8 + 0.2 * power))
				on_floor = false
				_go("hop")
		"hop":
			step_physics(dt, true)
			if wall_hit != 0:
				vel.x = -vel.x * 0.4
			if on_floor and st > 0.1:
				stage.fx.dust(position, 3)
				_atk_cd = 0.3
				_go("idle")


# ---------------------------------------------------------------- 2. Ruin Guard: shielded patrol + heavy swing
func _think_guard(dt: float) -> void:
	match state:
		"idle", "patrol":
			if _can_see() and _atk_cd <= 0.0 and absf(_player_dx()) < 200.0:
				_face_player()
				if absf(_player_dx()) < 82.0:
					_go("tele")
					return
				_walk(dt, facing, speed * 1.5)
			else:
				_walk(dt, facing, speed * 0.6)
		"tele":
			_face_player()
			tele = clampf(st / 0.55, 0.0, 1.0)
			vel.x = 0.0
			step_physics(dt, true)
			if st >= 0.55:
				_go("attack")
				stage.shake(2.0)
		"attack":
			vel.x = facing * 80.0 if st < 0.1 else 0.0
			step_physics(dt, true)
			if st > 0.06 and st < 0.2:
				var hb := Rect2(position.x + (0.0 if facing > 0 else -70.0) , position.y - 50.0, 70.0, 50.0)
				if hb.intersects(stage.player.rect()) and stage.player.alive:
					stage.damage_player(contact_damage + 4.0, position.x, 1.2)
			if st >= 0.28:
				_atk_cd = 1.2
				_go("recover")
		"recover":
			vel.x = 0.0
			step_physics(dt, true)
			if st >= 0.7:
				_go("idle")


# ---------------------------------------------------------------- 3. Ember Crawler: charge then stun
func _think_crawler(dt: float) -> void:
	match state:
		"idle", "patrol":
			if _can_see() and _atk_cd <= 0.0 and absf(stage.player.position.y - position.y) < 60.0:
				_face_player()
				_go("tele")
				return
			_walk(dt, facing, speed * 0.7)
		"tele":
			_face_player()
			tele = clampf(st / 0.5, 0.0, 1.0)
			vel.x = 0.0
			step_physics(dt, true)
			if int(st * 30.0) % 4 == 0:
				stage.fx.sparkle(position + Vector2(randf_range(-14, 14), -10), Color(1.0, 0.6, 0.2))
			if st >= 0.5:
				_go("charge")
		"charge":
			vel.x = facing * speed * 4.0
			step_physics(dt, true)
			stage.fx.dust(position, 1)
			if wall_hit != 0 or st > 0.8:
				if wall_hit != 0:
					stage.shake(3.0)
					stage.fx.burst(position + Vector2(facing * 14, -10), Color(1.0, 0.6, 0.2), 8, 160.0)
				_go("recover")
		"recover":
			vel.x = move_toward(vel.x, 0.0, 900.0 * dt)
			step_physics(dt, true)
			if st >= 0.9:
				_atk_cd = 1.0
				facing = -facing if wall_hit != 0 else facing
				_go("idle")


# ---------------------------------------------------------------- 4. Crystal Archer: keep distance, telegraphed shot
func _think_archer(dt: float) -> void:
	match state:
		"idle", "walk":
			var d := absf(_player_dx())
			if _can_see():
				_face_player()
				if d < 150.0:
					vel.x = move_toward(vel.x, -dir_to_player * speed * 1.3, 900.0 * dt)
					step_physics(dt, true)
					if wall_hit != 0 and _atk_cd <= 0.0:
						_go("tele")
					return
				if _atk_cd <= 0.0 and d < 420.0:
					_go("tele")
					return
			vel.x = move_toward(vel.x, 0.0, 800.0 * dt)
			step_physics(dt, true)
		"tele":
			_face_player()
			tele = clampf(st / 0.6, 0.0, 1.0)
			_aim = (stage.player.center() - (position + Vector2(facing * 10.0, -28.0))).normalized()
			vel.x = 0.0
			step_physics(dt, true)
			if st >= 0.6:
				stage.spawn_enemy_shot(position + Vector2(facing * 14.0, -28.0), _aim * 330.0, contact_damage, "arrow", Color(0.7, 0.9, 1.0), 6.0, 2.5)
				Sfx.play("arrow")
				_go("recover")
		"recover":
			step_physics(dt, true)
			if st >= 0.5:
				_atk_cd = 1.4
				_go("idle")


# ---------------------------------------------------------------- 5. Thorn Stalker: ambush leap
func _think_stalker(dt: float) -> void:
	match state:
		"hide":
			vel.x = 0.0
			step_physics(dt, true)
			if _can_see() and _player_dist() < 190.0:
				_face_player()
				_go("tele")
		"idle":
			if _can_see():
				_face_player()
				if absf(_player_dx()) < 230.0 and _atk_cd <= 0.0:
					_go("tele")
					return
				_walk(dt, facing, speed)
			else:
				_walk(dt, facing, speed * 0.5)
		"tele":
			_face_player()
			tele = clampf(st / 0.45, 0.0, 1.0)
			vel.x = 0.0
			step_physics(dt, true)
			if st >= 0.45:
				var dx := clampf(_player_dx(), -260.0, 260.0)
				vel = Vector2(dx * 1.6, -480.0)
				on_floor = false
				contact_damage = float(DATA["stalker"]["dmg"])
				_go("leap")
		"leap":
			step_physics(dt, true)
			if on_floor and st > 0.15:
				stage.fx.dust(position, 5)
				stage.shake(2.0)
				contact_damage = 0.0
				_go("recover")
		"recover":
			vel.x = move_toward(vel.x, 0.0, 1200.0 * dt)
			step_physics(dt, true)
			if st >= 0.85:
				_atk_cd = 1.0
				_go("idle")


# ---------------------------------------------------------------- 6. Frost Knight: bash + slam wave, super armor on wind-up
func _think_knight(dt: float) -> void:
	super_armor = state in ["tele", "attack", "charge"]
	match state:
		"idle", "patrol":
			if _can_see() and _atk_cd <= 0.0:
				_face_player()
				var d := absf(_player_dx())
				if d < 110.0:
					_go("tele")
					_flag = true       # slam
				elif d < 320.0:
					_go("tele")
					_flag = false      # bash
				else:
					_walk(dt, facing, speed)
			else:
				_walk(dt, facing, speed * 0.6)
		"tele":
			_face_player()
			tele = clampf(st / 0.65, 0.0, 1.0)
			vel.x = 0.0
			step_physics(dt, true)
			if st >= 0.65:
				_go("attack" if _flag else "charge")
		"charge":
			vel.x = facing * 300.0
			step_physics(dt, true)
			stage.fx.trail(position, facing)
			if wall_hit != 0 or st > 0.55:
				_go("recover")
		"attack":
			vel.x = 0.0
			step_physics(dt, true)
			if st > 0.02 and st < 0.08:
				stage.shake(5.0)
				for d2 in [-1, 1]:
					var w := stage.spawn_enemy_shot(position + Vector2(d2 * 20.0, -10.0), Vector2(d2 * 260.0, 0), contact_damage, "shard", Color(0.8, 0.95, 1.0), 9.0, 1.2)
					w.gravity = 0.0
				stage.fx.burst(position + Vector2(0, -4), Color(0.8, 0.95, 1.0), 12, 220.0)
			if st >= 0.3:
				_go("recover")
		"recover":
			vel.x = move_toward(vel.x, 0.0, 900.0 * dt)
			step_physics(dt, true)
			if st >= 0.95:
				_atk_cd = 1.1
				_go("idle")


# ---------------------------------------------------------------- 7. Clockwork Drone: hover, dive, drop gears
func _think_drone(dt: float) -> void:
	match state:
		"idle":
			var target := home + Vector2(sin(_anim_t * 0.8) * patrol, -40.0 + sin(_anim_t * 2.0) * 12.0)
			if _can_see():
				target = Vector2(stage.player.position.x + sin(_anim_t * 1.3) * 90.0, stage.player.position.y - 140.0)
			var dv := (target - position)
			vel = vel.lerp(dv.limit_length(speed), clampf(4.0 * dt, 0.0, 1.0))
			facing = 1 if vel.x >= 0.0 else -1
			_fly_move(dt)
			if _can_see() and _atk_cd <= 0.0 and absf(stage.player.position.x - position.x) < 70.0 and st > 0.8:
				_go("tele")
		"tele":
			tele = clampf(st / 0.5, 0.0, 1.0)
			vel = vel.lerp(Vector2.ZERO, clampf(8.0 * dt, 0.0, 1.0))
			_fly_move(dt)
			_aim = (stage.player.center() - center()).normalized()
			if st >= 0.5:
				_go("dive")
		"dive":
			vel = _aim * 400.0
			_fly_move(dt)
			if st > 0.5 or on_floor or wall_hit != 0:
				_go("recover")
		"recover":
			vel = vel.lerp(Vector2(0, -80.0), clampf(4.0 * dt, 0.0, 1.0))
			_fly_move(dt)
			if st >= 0.8:
				_atk_cd = 1.5
				_go("idle")


# ---------------------------------------------------------------- 8. Eclipse Wraith: blink, spread of void orbs
func _think_wraith(dt: float) -> void:
	match state:
		"idle":
			fade = move_toward(fade, 1.0, 3.0 * dt)
			var target := home + Vector2(sin(_anim_t * 0.6) * 60.0, sin(_anim_t * 1.4) * 20.0)
			if _can_see():
				_face_player()
				target = Vector2(stage.player.position.x - dir_to_player * 200.0, stage.player.position.y - 70.0)
			vel = vel.lerp((target - position).limit_length(speed), clampf(3.0 * dt, 0.0, 1.0))
			_fly_move(dt)
			if _can_see() and _atk_cd <= 0.0 and st > 0.8:
				_go("fade")
		"fade":
			fade = 1.0 - clampf(st / 0.35, 0.0, 1.0)
			if st >= 0.35:
				var pp: Vector2 = stage.player.position
				var side := 1 if randf() < 0.5 else -1
				var np := Vector2(pp.x + side * 210.0, pp.y - 60.0)
				if level.rect_hits_solid(Rect2(np.x - 15.0, np.y - size.y, size.x, size.y)):
					np = Vector2(pp.x - side * 210.0, pp.y - 60.0)
				if level.rect_hits_solid(Rect2(np.x - 15.0, np.y - size.y, size.x, size.y)):
					np = Vector2(pp.x, pp.y - 120.0)
				position = np
				_face_player()
				_go("appear")
		"appear":
			fade = clampf(st / 0.35, 0.0, 1.0)
			if st >= 0.35:
				_go("tele")
		"tele":
			_face_player()
			tele = clampf(st / 0.55, 0.0, 1.0)
			if st >= 0.55:
				var base := (stage.player.center() - center()).angle()
				for i in 3:
					var a := base + (i - 1) * 0.26
					stage.spawn_enemy_shot(center(), Vector2.from_angle(a) * 230.0, 12.0, "void", Color(1.0, 0.4, 0.9), 8.0, 3.5)
				Sfx.play("void")
				_go("recover")
		"recover":
			vel = vel.lerp(Vector2.ZERO, clampf(5.0 * dt, 0.0, 1.0))
			_fly_move(dt)
			if st >= 0.9:
				_atk_cd = 1.5
				_go("idle")


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var hurt := hurt_t > 0.0
	var mod := Color(2.2, 2.2, 2.2, 1.0) if hurt else Color.WHITE
	if frozen_t > 0.0:
		mod = Color(0.6, 0.85, 1.4)
	var f := float(facing)
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(f, 1.0))
	match kind:
		"slime": _art_slime(mod)
		"guard": _art_guard(mod)
		"crawler": _art_crawler(mod)
		"archer": _art_archer(mod)
		"stalker": _art_stalker(mod)
		"knight": _art_knight(mod)
		"drone": _art_drone(mod)
		"wraith": _art_wraith(mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hp < max_hp and hp > 0.0 and kind != "slime":
		var w := 34.0
		draw_rect(Rect2(-w * 0.5, -size.y - 12.0, w, 4.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w * 0.5, -size.y - 12.0, w * clampf(hp / max_hp, 0.0, 1.0), 4.0), Color(1.0, 0.4, 0.4))


func _warn(col: Color = Color(1, 0.3, 0.2)) -> void:
	# telegraph "!" mark above the enemy
	if tele > 0.0:
		var pulse := 0.6 + 0.4 * sin(_anim_t * 30.0)
		var c := Vector2(0, -size.y - 22.0)
		draw_circle(c, 9.0, Color(col.r, col.g, col.b, 0.35 * pulse))
		draw_line(c + Vector2(0, -6), c + Vector2(0, 2), Color(1, 1, 1, 0.95), 3.0)
		draw_circle(c + Vector2(0, 6), 1.6, Color(1, 1, 1, 0.95))


func _eye(p: Vector2, r: float = 2.2, c: Color = Color(0.1, 0.1, 0.2)) -> void:
	draw_circle(p, r, c)
	draw_circle(p + Vector2(r * 0.3, -r * 0.3), r * 0.35, Color.WHITE)


func _art_slime(mod: Color) -> void:
	var sq := 1.0
	var squash := 0.0
	if state == "tele":
		squash = tele
	elif state == "hop":
		squash = -0.3 if vel.y < 0 else 0.15
	else:
		squash = sin(_anim_t * 3.0) * 0.06
	var w := 15.0 * (1.0 + squash * 0.5)
	var h := 24.0 * (1.0 - squash * 0.5)
	var body := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		body.append(Vector2(cos(a) * w, sin(a) * h))
	draw_colored_polygon(body, Color(0.45, 0.88, 1.0, 0.92) * mod)
	draw_polyline(body, Color(0.1, 0.3, 0.5), 2.0, true)
	draw_arc(Vector2(-4, -h * 0.6), 6.0, PI, PI * 1.6, 8, Color(1, 1, 1, 0.7), 2.0)
	_eye(Vector2(5, -h * 0.5))
	_eye(Vector2(-2, -h * 0.5))
	# tiny star inside
	draw_circle(Vector2(0, -h * 0.3), 2.5, Color(1.0, 0.95, 0.5, 0.8))
	_warn()


func _art_guard(mod: Color) -> void:
	var sway := sin(_anim_t * 2.0) * 1.0
	var step := sin(_anim_t * 6.0) * 4.0 if absf(vel.x) > 10.0 else 0.0
	var stone := Color(0.62, 0.64, 0.6) * mod
	var dark := Color(0.38, 0.4, 0.38) * mod
	# legs
	draw_rect(Rect2(-9, -16, 7, 16), dark)
	draw_rect(Rect2(2 + step * 0.3, -16, 7, 16), dark)
	# torso
	draw_rect(Rect2(-13, -38 + sway, 26, 24), stone)
	draw_rect(Rect2(-13, -38 + sway, 26, 24), Color(0.15, 0.17, 0.15), false, 2.0)
	draw_line(Vector2(-8, -30), Vector2(8, -30), Color(0.3, 0.9, 0.9, 0.9), 2.0)
	# head
	draw_rect(Rect2(-8, -50 + sway, 16, 14), stone)
	draw_rect(Rect2(-8, -50 + sway, 16, 14), Color(0.15, 0.17, 0.15), false, 2.0)
	draw_rect(Rect2(1, -45 + sway, 6, 3), Color(0.4, 1.0, 1.0))
	# shield (front)
	if state in ["idle", "patrol", "tele"]:
		draw_rect(Rect2(8, -38, 7, 28), Color(0.55, 0.56, 0.5) * mod)
		draw_rect(Rect2(8, -38, 7, 28), Color(0.15, 0.17, 0.15), false, 1.5)
	# sword
	var raise := 0.0
	if state == "tele":
		raise = -2.2 * tele
	elif state == "attack":
		raise = lerpf(-2.2, 1.0, clampf(st / 0.12, 0.0, 1.0))
	elif state == "recover":
		raise = 1.0
	var a := raise - 0.2
	var hand := Vector2(10, -30)
	var tip := hand + Vector2.from_angle(a) * 36.0
	draw_line(hand, tip, Color(0.1, 0.1, 0.12), 5.0, true)
	draw_line(hand, tip, Color(0.75, 0.8, 0.85), 3.0, true)
	if state == "attack" and st < 0.2:
		draw_arc(Vector2(0, -28), 52.0, -1.8, 0.8, 12, Color(1, 1, 1, 0.5), 5.0)
	_warn()


func _art_crawler(mod: Color) -> void:
	var wob := sin(_anim_t * 14.0) * 2.0 if state == "charge" else sin(_anim_t * 6.0)
	var heat := tele if state == "tele" else (1.0 if state == "charge" else 0.0)
	var body := Color(0.3, 0.2, 0.2).lerp(Color(1.0, 0.45, 0.1), heat) * mod
	var shell := PackedVector2Array([Vector2(-19, -4), Vector2(-15, -20), Vector2(-2, -24), Vector2(12, -20), Vector2(19, -6), Vector2(18, 0), Vector2(-18, 0)])
	draw_colored_polygon(shell, body)
	draw_polyline(shell, Color(0.1, 0.05, 0.05), 2.0, true)
	for i in 5:
		var lx := -14.0 + i * 7.0
		draw_line(Vector2(lx, -1), Vector2(lx + sin(_anim_t * 12.0 + i) * 3.0, 3.0), Color(0.1, 0.05, 0.05), 2.5)
	for i in 3:
		draw_circle(Vector2(-8 + i * 8, -14 + wob * 0.2), 3.0, Color(1.0, 0.55 + 0.3 * heat, 0.15, 0.9))
	_eye(Vector2(13, -12), 2.4, Color(1.0, 0.9, 0.3))
	_warn(Color(1.0, 0.5, 0.1))


func _art_archer(mod: Color) -> void:
	var sway := sin(_anim_t * 2.5)
	var crystal := Color(0.55, 0.85, 1.0) * mod
	draw_rect(Rect2(-6, -20, 5, 20), Color(0.2, 0.3, 0.45) * mod)
	draw_rect(Rect2(1, -20, 5, 20), Color(0.2, 0.3, 0.45) * mod)
	var torso := PackedVector2Array([Vector2(-9, -20), Vector2(-7, -38 + sway), Vector2(7, -38 + sway), Vector2(9, -20)])
	draw_colored_polygon(torso, Color(0.25, 0.4, 0.6) * mod)
	draw_polyline(torso + PackedVector2Array([torso[0]]), Color(0.05, 0.1, 0.2), 1.5)
	draw_circle(Vector2(0, -44 + sway), 7.0, Color(0.25, 0.4, 0.6) * mod)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -49 + sway), Vector2(0, -60 + sway), Vector2(5, -49 + sway)]), crystal)
	_eye(Vector2(3, -44 + sway), 1.8, Color(0.6, 1.0, 1.0))
	# bow
	var aim_a := _aim.angle() if state == "tele" else 0.0
	if facing < 0 and state == "tele":
		aim_a = PI - aim_a
	var bc := Vector2(10, -30)
	draw_arc(bc, 14.0, aim_a - 1.1, aim_a + 1.1, 12, crystal, 3.0, true)
	if state == "tele":
		var tip := bc + Vector2.from_angle(aim_a) * 220.0
		draw_line(bc, tip, Color(1.0, 0.4, 0.4, 0.35 + 0.35 * tele), 1.5)
	_warn(Color(0.5, 0.9, 1.0))


func _art_stalker(mod: Color) -> void:
	if state == "hide":
		# looks like a thorny bush with glinting eyes
		for i in 7:
			var a := PI + PI * i / 6.0
			draw_line(Vector2(cos(a) * 6.0, -6), Vector2(cos(a) * 20.0, -6 + sin(a) * 26.0), Color(0.2, 0.35, 0.15) * mod, 3.0)
		draw_circle(Vector2(0, -8), 12.0, Color(0.18, 0.3, 0.13) * mod)
		draw_circle(Vector2(5, -10), 1.5, Color(1.0, 0.8, 0.4, 0.5 + 0.4 * sin(_anim_t * 4.0)))
		return
	var crouch := tele * 8.0 if state == "tele" else 0.0
	var body := Color(0.35, 0.2, 0.45) * mod
	var torso := PackedVector2Array([Vector2(-16, -4), Vector2(-12, -26 + crouch), Vector2(8, -30 + crouch), Vector2(17, -14), Vector2(15, 0)])
	draw_colored_polygon(torso, body)
	draw_polyline(torso + PackedVector2Array([torso[0]]), Color(0.1, 0.05, 0.15), 2.0)
	for i in 5:
		draw_line(Vector2(-12 + i * 5.0, -26 + crouch), Vector2(-14 + i * 5.0, -36 + crouch + (i % 2) * 4.0), Color(0.45, 0.8, 0.3), 2.0)
	_eye(Vector2(11, -20 + crouch), 2.3, Color(1.0, 0.85, 0.3))
	draw_line(Vector2(13, -10), Vector2(24, -4 + sin(_anim_t * 6.0) * 2.0), Color(0.9, 0.9, 0.8), 3.0)
	_warn(Color(0.8, 0.4, 1.0))


func _art_knight(mod: Color) -> void:
	var steel := Color(0.72, 0.84, 0.95) * mod
	var dark := Color(0.35, 0.45, 0.6) * mod
	var s := sin(_anim_t * 5.0) * 3.0 if absf(vel.x) > 10.0 else 0.0
	draw_rect(Rect2(-11, -20, 9, 20), dark)
	draw_rect(Rect2(2 + s * 0.2, -20, 9, 20), dark)
	draw_rect(Rect2(-15, -44, 30, 26), steel)
	draw_rect(Rect2(-15, -44, 30, 26), Color(0.1, 0.15, 0.25), false, 2.0)
	draw_line(Vector2(-10, -32), Vector2(10, -32), Color(0.6, 0.95, 1.0), 3.0)
	draw_rect(Rect2(-9, -56, 18, 14), steel)
	draw_rect(Rect2(-9, -56, 18, 14), Color(0.1, 0.15, 0.25), false, 2.0)
	draw_rect(Rect2(1, -51, 7, 3), Color(0.6, 1.0, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -56), Vector2(0, -66), Vector2(3, -56)]), Color(0.9, 0.3, 0.3))
	# pauldrons: icicles
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -44), Vector2(-8, -46), Vector2(-14, -34)]), Color(0.85, 0.95, 1.0))
	var arm := 0.2
	if state == "tele":
		arm = -2.4 * tele
	elif state == "attack":
		arm = lerpf(-2.4, 1.2, clampf(st / 0.1, 0.0, 1.0))
	var hand := Vector2(12, -34)
	var tip := hand + Vector2.from_angle(arm) * 42.0
	draw_line(hand, tip, Color(0.1, 0.15, 0.25), 8.0, true)
	draw_line(hand, tip, Color(0.85, 0.95, 1.0), 5.0, true)
	if state != "tele" and state != "attack" and state != "charge":
		draw_rect(Rect2(10, -46, 8, 34), Color(0.5, 0.65, 0.85) * mod)
	if state == "charge":
		draw_rect(Rect2(12, -46, 10, 34), Color(0.8, 0.95, 1.0))
	if super_armor:
		draw_arc(Vector2(0, -30), 34.0, 0, TAU, 20, Color(0.7, 0.9, 1.0, 0.25 + 0.2 * sin(_anim_t * 10.0)), 3.0)
	_warn(Color(0.7, 0.9, 1.0))


func _art_drone(mod: Color) -> void:
	var bob := sin(_anim_t * 6.0) * 2.0
	var brass := Color(0.82, 0.62, 0.25) * mod
	# rotors
	var rot := _anim_t * 25.0
	for s in [-1, 1]:
		draw_line(Vector2(s * 8.0, -22 + bob), Vector2(s * 20.0, -28 + bob), Color(0.3, 0.25, 0.15), 2.0)
		draw_line(Vector2(s * 20.0 - cos(rot) * 9.0, -28 + bob), Vector2(s * 20.0 + cos(rot) * 9.0, -28 + bob), Color(0.9, 0.9, 0.9, 0.7), 2.0)
	draw_circle(Vector2(0, -13 + bob), 13.0, brass)
	draw_arc(Vector2(0, -13 + bob), 13.0, 0, TAU, 20, Color(0.2, 0.12, 0.05), 2.0)
	var glow := Color(1.0, 0.3, 0.2) if state in ["tele", "dive"] else Color(0.4, 1.0, 0.8)
	draw_circle(Vector2(4, -14 + bob), 5.0, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(4, -14 + bob), 3.2, glow)
	draw_line(Vector2(-10, -13 + bob), Vector2(-4, -13 + bob), Color(0.2, 0.12, 0.05), 2.0)
	draw_circle(Vector2(-3, -5 + bob), 3.0, Color(0.3, 0.2, 0.1))
	if state == "tele" or state == "dive":
		draw_line(Vector2(0, -13), Vector2(_aim.x * facing, _aim.y) * 60.0 + Vector2(0, -13), Color(1, 0.3, 0.2, 0.4), 1.5)
	_warn(Color(1.0, 0.7, 0.2))


func _art_wraith(mod: Color) -> void:
	var a := fade
	var bob := sin(_anim_t * 3.0) * 3.0
	var col := Color(0.6, 0.15, 0.7, 0.85 * a) * Color(mod.r, mod.g, mod.b, 1.0)
	var pts := PackedVector2Array()
	pts.append(Vector2(-13, -44 + bob))
	pts.append(Vector2(13, -44 + bob))
	pts.append(Vector2(16, -20 + bob))
	for i in 5:
		pts.append(Vector2(16 - i * 8.0, -2 + bob + (i % 2) * 8.0 + sin(_anim_t * 5.0 + i) * 3.0))
	pts.append(Vector2(-16, -20 + bob))
	draw_colored_polygon(pts, col)
	draw_circle(Vector2(0, -40 + bob), 11.0, Color(0.15, 0.03, 0.2, a))
	draw_arc(Vector2(0, -40 + bob), 11.0, 0, TAU, 18, Color(1.0, 0.4, 0.9, a), 2.0)
	draw_circle(Vector2(4, -41 + bob), 2.6, Color(1.0, 0.8, 1.0, a))
	draw_circle(Vector2(-3, -41 + bob), 2.0, Color(1.0, 0.8, 1.0, a))
	if state == "tele":
		draw_circle(Vector2(14, -26 + bob), 4.0 + 8.0 * tele, Color(1.0, 0.4, 0.9, 0.4))
	_warn(Color(1.0, 0.4, 0.9))
