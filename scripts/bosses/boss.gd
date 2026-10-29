class_name Boss
extends Actor
## Boss fight controller: entrance, telegraphed attack scripts, vulnerability windows, phase changes, defeat and reward.

var id: String = ""
var cfg: Dictionary = {}
var uid: int = 777
var hp: float = 100.0
var max_hp: float = 100.0
var phase: int = 0
var state: String = "dormant"       # dormant intro fight phase dying dead
var st: float = 0.0
var contact_damage: float = 0.0
var contact_base: float = 18.0
var flying: bool = false
var vulnerable: bool = false
var stun_t: float = 0.0
var tele: float = 0.0
var hurt_t: float = 0.0
var steps: Array = []
var si: int = 0
var op_t: float = 0.0
var op_init: bool = false
var cur_attack: String = ""
var cd: float = 1.0
var speed_mul: float = 1.0
var floor_y: float = 0.0
var arena_x0: float = 0.0
var arena_x1: float = 0.0
var marks: Array = []
var cols: Array = []
var beam_on: bool = false
var beam_ang: float = 0.0
var beam_dmg: float = 0.0
var beam_cd: float = 0.0
var melee_rect: Rect2 = Rect2()
var melee_on: bool = false
var melee_hit: bool = false
var fade: float = 1.0
var _lob_left: int = 0
var _lob_t: float = 0.0
var _hover_y: float = 0.0
var _fly_from: Vector2 = Vector2.ZERO
var _fly_to: Vector2 = Vector2.ZERO
var _leap_t: float = 0.0
var _dash_dir: int = 1
var _blink_to: Vector2 = Vector2.ZERO
var _last_attacks: Array = []
var intro_done: bool = false
var last_attack_log: Array = []     # names of attacks used, for tests
var attacks_used: Dictionary = {}
var phases_reached: int = 0
var _death_fx_t: float = 0.0
var _hit_flash: float = 0.0
var damage_taken_blocked: int = 0
var echo: bool = false
var hits_at_start: int = 0


func setup(boss_id: String) -> void:
	id = boss_id
	cfg = BossData.DATA[boss_id]


func _ready() -> void:
	size = cfg["size"]
	flying = cfg["flying"]
	contact_base = float(cfg["contact"])
	var diff := Game.difficulty()
	echo = Game.bosses.has(id) and Game.completed
	max_hp = float(cfg["hp"]) * float(diff["enemy_hp"]) * (1.6 if echo else 1.0)
	hp = max_hp
	z_index = 4
	var arena: Dictionary = stage.data.meta.get("arena", {})
	floor_y = float(arena.get("fy", 21)) * Level.T
	arena_x0 = 3.0 * Level.T
	arena_x1 = float(stage.level.w - 3) * Level.T
	_hover_y = floor_y - 190.0
	facing = -1
	if flying:
		position.y = _hover_y + size.y
	else:
		position.y = floor_y
	cd = 1.0


func hit_rect() -> Rect2:
	return rect().grow(-6.0)


func contact_rect() -> Rect2:
	return rect().grow(-14.0)


func center_pos() -> Vector2:
	return center()


func take_hit(info: Dictionary) -> bool:
	if not alive or state in ["dormant", "dying", "dead", "intro", "phase"]:
		return false
	var dmg: float = info["damage"]
	if not vulnerable and stun_t <= 0.0:
		dmg *= 0.6
		damage_taken_blocked += 1
		stage.fx.number(hit_rect().get_center() + Vector2(0, -40), "Armored", Color(0.7, 0.8, 1.0))
		Sfx.play("block")
	else:
		stage.fx.burst(hit_rect().get_center(), Color(1.0, 0.9, 0.6), 8, 200.0)
		Sfx.play("hit")
	hp -= dmg
	_hit_flash = 0.12
	_emit_bar()
	if hp <= 0.0:
		_begin_death()
	else:
		_check_phase()
	return true


func freeze(t: float) -> void:
	# Stasis Pulse: stuns for a short moment, opening a vulnerability window
	if state == "fight":
		stun_t = maxf(stun_t, t)
		steps = []
		cur_attack = ""
		beam_on = false
		melee_on = false
		stage.fx.ring(center(), Color(0.7, 0.9, 1.0))
		Game.toast.emit("%s is stunned!" % cfg["name"], "info")


func _emit_bar() -> void:
	Game.boss_changed.emit(state != "dead", cfg["name"], clampf(hp / max_hp, 0.0, 1.0))


# ------------------------------------------------------------------ flow
func tick(dt: float) -> void:
	_anim_t += dt
	st += dt
	_hit_flash = maxf(_hit_flash - dt, 0.0)
	match state:
		"dormant": _tick_dormant(dt)
		"intro": _tick_intro(dt)
		"fight": _tick_fight(dt)
		"phase": _tick_phase(dt)
		"dying": _tick_dying(dt)
	if state != "dormant":
		_tick_marks(dt)
		_tick_cols(dt)
	queue_redraw()


func _go(s: String) -> void:
	state = s
	st = 0.0


func _tick_dormant(dt: float) -> void:
	_ground_idle(dt)
	var p := stage.player
	if p.alive and p.position.x > arena_x0 + 3.0 * Level.T and absf(p.position.y - floor_y) < 200.0:
		begin_fight()


func begin_fight() -> void:
	if state != "dormant":
		return
	# close the doors behind Kael and take over the camera
	for c in stage.data.meta.get("arena", {}).get("gate", []):
		stage.level.set_tile(int(c[0]), int(c[1]), Tiles.GATE)
	stage.cam_lock = Rect2(Vector2.ZERO, stage.level.pixel_size())
	Game.in_boss_fight = true
	Sfx.play_music("boss")
	hits_at_start = Game.run_hits
	_go("intro")
	stage.player.control_lock = true
	stage.player.inp = {}
	stage.fx.ring(center(), Color(1, 0.8, 0.5))
	stage.shake(8.0)
	Sfx.play("boss_roar")
	_emit_bar()
	var lines: Array = Story.BOSSES[id]["intro"]
	stage.show_lines(lines, Callable(self, "_on_intro_done"), cfg["name"])


func _on_intro_done() -> void:
	intro_done = true


func _tick_intro(dt: float) -> void:
	_ground_idle(dt)
	if intro_done and st > 0.8:
		stage.player.control_lock = false
		_go("fight")
		cd = 0.8
		phases_reached = maxi(phases_reached, 1)
		_emit_bar()


func _tick_fight(dt: float) -> void:
	contact_damage = contact_base if (cur_attack in ["ram", "bash", "overclock"] or state == "fight") else 0.0
	if not stage.player.alive:
		beam_on = false
		melee_on = false
		steps = []
		_ground_idle(dt)
		return
	if stun_t > 0.0:
		stun_t -= dt
		vulnerable = true
		tele = 0.0
		_ground_idle(dt, 0.0)
		if stun_t <= 0.0:
			vulnerable = false
		return
	if steps.is_empty():
		_ground_idle(dt)
		cd -= dt
		if cd <= 0.0:
			_pick_attack()
		return
	_run_steps(dt)


func _ground_idle(dt: float, walk_scale: float = 1.0) -> void:
	var p := stage.player
	facing = 1 if p.position.x >= position.x else -1
	if flying:
		var hy := _hover_y + size.y + sin(_anim_t * 1.6) * 14.0
		var tx := clampf(p.position.x + 160.0 * -facing * 0.0, arena_x0 + 60.0, arena_x1 - 60.0)
		var want := Vector2(position.x + signf(p.position.x - position.x) * float(cfg["walk"]) * walk_scale * dt * 0.5, hy)
		position.x = clampf(want.x, arena_x0 + 40.0, arena_x1 - 40.0)
		position.y = lerpf(position.y, hy, clampf(2.0 * dt, 0.0, 1.0))
		return
	var dist := p.position.x - position.x
	var dir := signf(dist)
	var spd := float(cfg["walk"]) * walk_scale * (1.0 if absf(dist) > size.x * 0.7 else 0.0)
	vel.x = move_toward(vel.x, dir * spd, 600.0 * dt)
	step_physics(dt, true)
	position.x = clampf(position.x, arena_x0 + size.x * 0.5, arena_x1 - size.x * 0.5)


func _pick_attack() -> void:
	var pool: Array = cfg["phases"][phase]["pool"]
	var choices: Array = []
	for a in pool:
		if a != (_last_attacks[-1] if not _last_attacks.is_empty() else ""):
			choices.append(a)
	if choices.is_empty():
		choices = pool
	var name: String = choices[stage.rng.randi() % choices.size()]
	_last_attacks.append(name)
	if _last_attacks.size() > 4:
		_last_attacks.pop_front()
	start_attack(name)


func start_attack(name: String) -> void:
	cur_attack = name
	steps = cfg["attacks"][name].duplicate(true)
	si = 0
	op_t = 0.0
	op_init = false
	vulnerable = false
	attacks_used[name] = int(attacks_used.get(name, 0)) + 1
	last_attack_log.append(name)


func _next() -> void:
	si += 1
	op_t = 0.0
	op_init = false
	if si >= steps.size():
		steps = []
		cur_attack = ""
		vulnerable = false
		tele = 0.0
		cd = 0.55 / speed_mul + stage.rng.randf() * 0.35


func _run_steps(dt: float) -> void:
	var s: Array = steps[si]
	var op: String = s[0]
	op_t += dt
	var p := stage.player
	match op:
		"tele":
			var total: float = float(s[1]) / speed_mul
			if not op_init:
				op_init = true
				Sfx.play("telegraph")
				facing = 1 if p.position.x >= position.x else -1
			tele = clampf(op_t / total, 0.0, 1.0)
			_hold(dt)
			if op_t >= total:
				tele = 0.0
				_next()
		"wait":
			_hold(dt)
			if op_t >= float(s[1]) / speed_mul:
				_next()
		"vuln":
			vulnerable = true
			_hold(dt)
			if op_t >= float(s[1]):
				vulnerable = false
				_next()
		"wave":
			var half := size.x * 0.5
			for d in [-1, 1]:
				var pr := stage.spawn_enemy_shot(Vector2(position.x + d * half, floor_y - 16.0), Vector2(d * float(s[1]), 0), float(s[3]), str(s[2]), _kind_color(str(s[2])), 13.0, 3.2)
				pr.z_index = 5
			Sfx.play("wave")
			_next()
		"lob":
			if not op_init:
				op_init = true
				_lob_left = int(s[1])
				_lob_t = 0.0
			_hold(dt)
			_lob_t -= dt
			if _lob_t <= 0.0 and _lob_left > 0:
				var idx := int(s[1]) - _lob_left
				var spread := float(s[2]) * 300.0
				var tx := p.position.x + (idx - (int(s[1]) - 1) * 0.5) * spread * 0.5
				_lob_shot(tx, float(s[3]), str(s[4]))
				_lob_left -= 1
				_lob_t = 0.28 / speed_mul
			if _lob_left <= 0 and _lob_t <= 0.05:
				_next()
		"volley":
			var from := center() + Vector2(facing * size.x * 0.3, -size.y * 0.1)
			var base := (p.center() - from).angle()
			var n := int(s[1])
			var spread := float(s[2])
			for i in n:
				var a := base + (i - (n - 1) * 0.5) * (spread if n > 1 else 0.0)
				var pr2 := stage.spawn_enemy_shot(from, Vector2.from_angle(a) * float(s[3]), float(s[5]), str(s[4]), _kind_color(str(s[4])), 8.0 if str(s[4]) != "sun" else 26.0, 4.5 if str(s[4]) != "sun" else 7.0)
				if str(s[4]) == "sun":
					pr2.homing = 1.2
			Sfx.play("shot")
			_next()
		"ring":
			var n2 := int(s[1])
			var rot := stage.rng.randf() * TAU
			for i in n2:
				var a2 := rot + TAU * i / n2
				stage.spawn_enemy_shot(center(), Vector2.from_angle(a2) * float(s[2]), float(s[4]), str(s[3]), _kind_color(str(s[3])), 8.0, 3.5)
			stage.fx.ring(center(), _kind_color(str(s[3])))
			Sfx.play("shot")
			_next()
		"rain":
			var n3 := int(s[1])
			for i in n3:
				var x := p.position.x if i == 0 else stage.rng.randf_range(arena_x0 + 30.0, arena_x1 - 30.0)
				marks.append({"x": x, "t": 0.85 + i * 0.12 / speed_mul, "kind": str(s[2]), "dmg": float(s[3]), "tot": 0.85 + i * 0.12 / speed_mul})
			_next()
		"column":
			var n4 := int(s[1])
			var line_mode: bool = str(s[5]) == "line"
			for i in n4:
				var x2: float
				var delay := 0.0
				if line_mode:
					var dir := signf(p.position.x - position.x)
					x2 = position.x + dir * (size.x * 0.5 + 60.0 + i * float(s[2]))
					delay = i * 0.16 / speed_mul
				else:
					x2 = p.position.x + (i - (n4 - 1) * 0.5) * float(s[2])
				if x2 < arena_x0 or x2 > arena_x1:
					continue
				cols.append({"x": x2, "delay": delay, "mark": 0.75 / speed_mul, "act": 0.38, "w": 56.0, "h": 170.0, "dmg": float(s[3]), "kind": str(s[4]), "hit": false, "phase": 0})
			_next()
		"dash":
			if not op_init:
				op_init = true
				_dash_dir = 1 if p.position.x >= position.x else -1
				facing = _dash_dir
				Sfx.play("boss_roar")
			vel.x = _dash_dir * float(s[1]) * (0.9 + 0.1 * speed_mul)
			var old := position.x
			step_physics(dt, true)
			position.x = clampf(position.x, arena_x0 + size.x * 0.5, arena_x1 - size.x * 0.5)
			stage.fx.dust(position, 1)
			if wall_hit != 0 or absf(position.x - old) < 0.5 * dt * 60.0 * 0.2 and op_t > 0.2 or position.x <= arena_x0 + size.x * 0.5 + 2.0 or position.x >= arena_x1 - size.x * 0.5 - 2.0 or op_t > 1.8:
				vel.x = 0.0
				stage.shake(8.0)
				stage.fx.burst(position + Vector2(_dash_dir * size.x * 0.5, -size.y * 0.5), Color(1, 0.9, 0.6), 14, 260.0)
				stun_t = 1.6
				steps = []
				cur_attack = ""
				cd = 0.6
		"leap":
			if not op_init:
				op_init = true
				_leap_t = 0.0
				var T := 0.9
				vel = Vector2((clampf(p.position.x, arena_x0 + 70.0, arena_x1 - 70.0) - position.x) / T, -1500.0 * T * 0.5)
				on_floor = false
				Sfx.play("boss_roar")
			vel.y += 1500.0 * dt
			position += vel * dt
			position.x = clampf(position.x, arena_x0 + size.x * 0.5, arena_x1 - size.x * 0.5)
			if position.y >= floor_y and vel.y > 0.0:
				position.y = floor_y
				vel = Vector2.ZERO
				stage.shake(9.0)
				stage.fx.dust(position, 10)
				stage.fx.ring(position + Vector2(0, -8), Color(1, 0.8, 0.5))
				var hit := Rect2(position.x - 90.0, floor_y - 40.0, 180.0, 40.0)
				if p.alive and hit.intersects(p.rect()):
					stage.damage_player(contact_base, position.x, 1.3)
				_next()
		"blink":
			if not op_init:
				op_init = true
				var side := 1.0 if stage.rng.randf() < 0.5 else -1.0
				var tx2 := clampf(p.position.x + side * 190.0, arena_x0 + 60.0, arena_x1 - 60.0)
				_blink_to = Vector2(tx2, (floor_y if not flying else _hover_y + size.y + 40.0))
				Sfx.play("void")
			if op_t < 0.3:
				fade = 1.0 - op_t / 0.3
			elif op_t < 0.35:
				position = _blink_to
				facing = 1 if p.position.x >= position.x else -1
			else:
				fade = clampf((op_t - 0.35) / 0.3, 0.0, 1.0)
			if op_t >= 0.65:
				fade = 1.0
				_next()
		"beam":
			if not op_init:
				op_init = true
				beam_dmg = float(s[4])
				beam_on = true
				Sfx.play("beam")
			var dur := float(s[3]) / speed_mul
			var u := clampf(op_t / dur, 0.0, 1.0)
			beam_ang = deg_to_rad(lerpf(float(s[1]), float(s[2]), u))
			if facing < 0:
				pass
			beam_cd = maxf(beam_cd - dt, 0.0)
			_hold(dt)
			if p.alive and beam_cd <= 0.0 and _beam_hits(p.center()):
				if stage.damage_player(beam_dmg, position.x, 0.8):
					beam_cd = 0.7
			if op_t >= dur:
				beam_on = false
				_next()
		"summon":
			var alive_adds := 0
			for e in stage.enemies:
				if is_instance_valid(e) and e.alive:
					alive_adds += 1
			var n5 := int(s[2])
			for i in n5:
				if alive_adds >= 4:
					break
				var side2 := -1.0 if i % 2 == 0 else 1.0
				var sx := clampf(position.x + side2 * 260.0, arena_x0 + 40.0, arena_x1 - 40.0)
				var e2 := Spawner.spawn_entity(stage, {"t": "enemy", "k": str(s[1]), "x": int(sx / Level.T), "y": int(floor_y / Level.T) - 1 - (3 if str(s[1]) == "wraith" else 0)})
				if e2 != null:
					stage.fx.burst(e2.position + Vector2(0, -30), Color(1, 0.5, 0.9), 12, 200.0)
				alive_adds += 1
			Sfx.play("void")
			_next()
		"fly_to":
			if not op_init:
				op_init = true
				_fly_from = position
				var lvl_w := stage.level.pixel_size().x
				_fly_to = Vector2(lvl_w * float(s[1]), float(s[2]) + size.y)
			var u2 := clampf(op_t / float(s[3]), 0.0, 1.0)
			position = _fly_from.lerp(_fly_to, u2 * u2 * (3.0 - 2.0 * u2))
			if u2 >= 1.0:
				_next()
		"tile":
			if str(s[1]) == "ice":
				_freeze_floor()
			_next()
		"melee":
			if not op_init:
				op_init = true
				melee_hit = false
				melee_on = true
				facing = 1 if p.position.x >= position.x else -1
				Sfx.play("swing")
				stage.shake(4.0)
			var reach := float(s[1])
			var x0 := position.x + (size.x * 0.3 if facing > 0 else -size.x * 0.3 - reach)
			melee_rect = Rect2(x0, position.y - float(s[2]) - (0.0 if not flying else 20.0), reach, float(s[2]))
			if flying:
				melee_rect = Rect2(x0, center().y - float(s[2]) * 0.5, reach, float(s[2]))
			if not melee_hit and p.alive and melee_rect.intersects(p.rect()):
				melee_hit = true
				stage.damage_player(float(s[3]), position.x, 1.2)
			_hold(dt)
			if op_t >= float(s[4]):
				melee_on = false
				_next()
		"shake":
			stage.shake(float(s[1]))
			_next()
		"sfx":
			Sfx.play(str(s[1]))
			_next()
		"say":
			Game.toast.emit(str(s[1]), "info")
			_next()
		_:
			_next()


func _hold(dt: float) -> void:
	if flying:
		position.y = lerpf(position.y, _hover_y + size.y + sin(_anim_t * 2.0) * 10.0, clampf(2.0 * dt, 0.0, 1.0)) if cur_attack != "beam" else position.y
		return
	vel.x = move_toward(vel.x, 0.0, 1500.0 * dt)
	step_physics(dt, true)


func _lob_shot(tx: float, dmg: float, kind: String) -> void:
	var from := center() + Vector2(facing * size.x * 0.3, -size.y * 0.25)
	var T := 1.1
	var g := 900.0
	var v := Vector2((tx - from.x) / T, ((floor_y - 20.0) - from.y - 0.5 * g * T * T) / T)
	stage.spawn_enemy_shot(from, v, dmg, kind, _kind_color(kind), 14.0 if kind == "boulder" else 9.0, 2.6, g)
	Sfx.play("shot")


func _kind_color(kind: String) -> Color:
	match kind:
		"flame": return Color(1.0, 0.5, 0.15)
		"shard": return Color(0.8, 0.95, 1.0)
		"orb": return Color(0.6, 0.85, 1.0)
		"spore": return Color(0.8, 0.4, 0.9)
		"thorn": return Color(0.5, 0.9, 0.3)
		"vine": return Color(0.4, 0.8, 0.3)
		"boulder": return Color(0.6, 0.58, 0.52)
		"gear": return Color(0.95, 0.75, 0.3)
		"void", "sun": return Color(1.0, 0.4, 0.9)
	return Color(1, 0.5, 0.4)


func _beam_hits(pt: Vector2) -> bool:
	var o := center()
	var dir := Vector2.from_angle(beam_ang)
	var rel := pt - o
	var along := rel.dot(dir)
	if along < 0.0 or along > 1400.0:
		return false
	return absf(rel.cross(dir)) < 20.0


func _freeze_floor() -> void:
	for x in range(1, stage.level.w - 1):
		if stage.level.tile(x, int(floor_y / Level.T)) == Tiles.SOLID:
			stage.level.set_tile(x, int(floor_y / Level.T), Tiles.ICE)


# ------------------------------------------------------------------ marks (falling objects) and columns (eruptions)
func _tick_marks(dt: float) -> void:
	var i := marks.size() - 1
	while i >= 0:
		var m: Dictionary = marks[i]
		m["t"] -= dt
		if m["t"] <= 0.0:
			var top_y := floor_y - 520.0
			var pr := stage.spawn_enemy_shot(Vector2(m["x"], top_y), Vector2(0, 560), m["dmg"], str(m["kind"]), _kind_color(str(m["kind"])), 14.0, 1.5)
			pr.z_index = 5
			marks.remove_at(i)
		i -= 1


func _tick_cols(dt: float) -> void:
	var i := cols.size() - 1
	while i >= 0:
		var c: Dictionary = cols[i]
		if c["delay"] > 0.0:
			c["delay"] -= dt
		elif c["phase"] == 0:
			c["mark"] -= dt
			if c["mark"] <= 0.0:
				c["phase"] = 1
				stage.fx.burst(Vector2(c["x"], floor_y), _kind_color(str(c["kind"])), 10, 220.0)
				stage.shake(3.0)
				Sfx.play("erupt")
		else:
			c["act"] -= dt
			var r := Rect2(c["x"] - c["w"] * 0.5, floor_y - c["h"], c["w"], c["h"])
			var p := stage.player
			if not c["hit"] and p.alive and r.intersects(p.rect()):
				c["hit"] = true
				stage.damage_player(c["dmg"], c["x"], 1.0)
			if c["act"] <= 0.0:
				cols.remove_at(i)
		i -= 1


# ------------------------------------------------------------------ phases
func _check_phase() -> void:
	var frac := hp / max_hp
	var next_i := phase + 1
	var phases: Array = cfg["phases"]
	if next_i < phases.size() and frac <= float(phases[next_i]["at"]):
		phase = next_i
		phases_reached = phase + 1
		speed_mul = float(phases[phase]["speed"]) * (1.15 if echo else 1.0)
		steps = []
		cur_attack = ""
		beam_on = false
		melee_on = false
		vulnerable = false
		stun_t = 0.0
		marks.clear()
		_go("phase")
		stage.shake(10.0)
		stage.flash_screen(Color(1, 1, 1, 0.45))
		stage.fx.burst(center(), Color(1, 0.9, 0.7), 28, 320.0)
		stage.fx.ring(center(), Color(1, 0.7, 0.4))
		Sfx.play("boss_roar")
		if phases[phase].has("say"):
			Game.toast.emit(str(phases[phase]["say"]), "info")
		if phases[phase].get("tile", "") == "ice":
			_freeze_floor()


func _tick_phase(dt: float) -> void:
	_hold(dt)
	if st >= 1.4:
		_go("fight")
		cd = 0.5


# ------------------------------------------------------------------ defeat
func _begin_death() -> void:
	hp = 0.0
	alive = false
	_go("dying")
	steps = []
	beam_on = false
	melee_on = false
	marks.clear()
	cols.clear()
	contact_damage = 0.0
	for pr in stage.projectiles:
		if is_instance_valid(pr) and not pr.friendly:
			pr.alive = false
	for e in stage.enemies:
		if is_instance_valid(e) and e.alive:
			e.hp = 0.0
			e._die()
	Game.boss_changed.emit(false, "", 0.0)
	Sfx.play("boss_roar")
	stage.hitstop(0.25)
	stage.flash_screen(Color(1, 1, 1, 0.6))
	stage.player.control_lock = true
	stage.player.inp = {}
	if not stage.hittables.has(self):
		pass


func _tick_dying(dt: float) -> void:
	# `alive` is already false so the stage stops ticking us; the stage calls tick_dying() directly
	pass


func tick_dying(dt: float) -> void:
	_anim_t += dt
	st += dt
	_death_fx_t -= dt
	if _death_fx_t <= 0.0:
		_death_fx_t = 0.09
		var p := center() + Vector2(stage.rng.randf_range(-size.x * 0.5, size.x * 0.5), stage.rng.randf_range(-size.y * 0.5, size.y * 0.5))
		stage.fx.burst(p, Color(1.0, 0.9, 0.6) if stage.rng.randf() < 0.5 else _kind_color("flame"), 8, 240.0)
		stage.shake(4.0)
	fade = clampf(1.0 - maxf(st - 2.0, 0.0) / 1.0, 0.0, 1.0)
	if not flying:
		step_physics(dt, true)
	queue_redraw()
	if st >= 3.0 and state == "dying":
		_finish()


func _finish() -> void:
	state = "dead"
	var bid := id
	var ri := Defs.REGION_ORDER.find(stage.data.region)
	var flawless := Game.run_hits == hits_at_start
	if echo:
		Game.add_xp(200 + 60 * ri)
		Game.add_shards(300 + 60 * ri)
		Game.event.emit("echo")
	else:
		Game.bosses[bid] = true
		Game.set_flag("defeated_" + bid)
		Game.fragments = mini(Game.fragments + 1, 7)
		Game.region_unlocked = maxi(Game.region_unlocked, mini(ri + 2, 7))
		Game.add_xp(120 + 40 * ri)
		Game.add_shards(100 + 40 * ri)
		Game.skill_points += 1
	if flawless:
		Game.event.emit("flawless")
	Game.in_boss_fight = false
	Game.full_restore()
	Game.stats_changed.emit()
	Game.progress_changed.emit()
	if not echo:
		Game.event.emit("boss")
	# open the doors, spawn the reward altar
	for c in stage.data.meta.get("arena", {}).get("gate", []):
		if stage.level.tile(int(c[0]), int(c[1])) == Tiles.GATE:
			stage.level.set_tile(int(c[0]), int(c[1]), Tiles.AIR)
	var reward: String = str(stage.data.meta.get("arena", {}).get("reward", ""))
	if reward != "" and not echo:
		var alt := Interactable.create("altar", {"id": "reward", "grant": reward})
		alt.stage = stage
		alt.position = Vector2(float(stage.level.w) * 16.0, floor_y)
		stage.entities.add_child(alt)
		stage.interactables.append(alt)
	stage.cam_lock = null
	stage.player.control_lock = false
	Sfx.play_music(Defs.REGIONS[stage.data.region]["music"])
	if echo:
		Game.toast.emit("Echo defeated. +%d Star Shards" % (300 + 60 * ri), "good")
	else:
		Game.toast.emit("%s Fragment recovered (%d/7)" % [Story.FRAGMENT_NAMES[ri], Game.fragments], "good")
	stage.boss_defeated.emit(bid)
	stage.autosave()
	stage.show_lines(Story.BOSSES[bid]["defeat"], Callable(stage, "_after_boss_lines"), cfg["name"])
	queue_redraw()


func _draw() -> void:
	if state == "dead":
		return
	var f := float(facing)
	var mod := Color(2.0, 2.0, 2.0, fade) if _hit_flash > 0.0 else Color(1, 1, 1, fade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(f, 1.0))
	BossArt.draw_boss(self, mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# marks, columns, beam and melee in world space (relative to boss node position)
	for m in marks:
		var u: float = 1.0 - float(m["t"]) / float(m["tot"])
		var gp := Vector2(float(m["x"]) - position.x, floor_y - position.y)
		draw_circle(gp, 14.0 + 10.0 * u, Color(1.0, 0.3, 0.2, 0.25 + 0.4 * u))
		draw_arc(gp, 22.0, 0, TAU, 18, Color(1.0, 0.5, 0.3, 0.8), 2.0)
		draw_line(gp, gp + Vector2(0, -520.0 * u * 0.0 - 40.0), Color(1, 0.4, 0.3, 0.4 * u), 2.0)
	for c in cols:
		var gp2 := Vector2(float(c["x"]) - position.x, floor_y - position.y)
		var col := _kind_color(str(c["kind"]))
		if c["delay"] > 0.0:
			continue
		if c["phase"] == 0:
			var pulse := 0.5 + 0.5 * sin(_anim_t * 30.0)
			draw_rect(Rect2(gp2.x - 28.0, gp2.y - 6.0, 56.0, 6.0), Color(1.0, 0.3, 0.2, 0.4 + 0.4 * pulse))
			draw_line(gp2 + Vector2(-20, -3), gp2 + Vector2(20, -3), Color(1, 1, 1, 0.6), 2.0)
		else:
			var h: float = float(c["h"]) * clampf(1.0 - float(c["act"]) / 0.38 * 0.0, 0.0, 1.0)
			var pts := PackedVector2Array([gp2 + Vector2(-26, 0), gp2 + Vector2(-12, -h * 0.9), gp2 + Vector2(0, -h), gp2 + Vector2(12, -h * 0.85), gp2 + Vector2(26, 0)])
			draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.9))
			draw_polyline(pts, Color(1, 1, 1, 0.8), 2.0)
	if beam_on or (cur_attack in ["beam"] and steps.size() > 0 and str(steps[si][0]) == "tele"):
		var o := center() - position
		var ang := beam_ang
		if not beam_on:
			ang = deg_to_rad(float(cfg["attacks"][cur_attack][2][1]))
		var dir := Vector2.from_angle(ang)
		if beam_on:
			draw_line(o, o + dir * 1400.0, Color(1.0, 0.3, 0.3, 0.35), 22.0)
			draw_line(o, o + dir * 1400.0, Color(1.0, 0.9, 0.9, 0.95), 7.0)
		else:
			draw_line(o, o + dir * 1400.0, Color(1.0, 0.4, 0.4, 0.3 + 0.4 * tele), 2.0)
	if melee_on:
		var r := melee_rect
		draw_rect(Rect2(r.position - position, r.size), Color(1.0, 0.8, 0.5, 0.28))
		draw_rect(Rect2(r.position - position, r.size), Color(1.0, 0.95, 0.8, 0.8), false, 3.0)
	elif tele > 0.0 and cur_attack != "" and not steps.is_empty():
		var s2: Array = steps[mini(si + 1, steps.size() - 1)]
		if str(s2[0]) == "melee":
			var reach := float(s2[1])
			var x0 := (size.x * 0.3 if facing > 0 else -size.x * 0.3 - reach)
			var hh := float(s2[2])
			var rr := Rect2(x0, -hh, reach, hh) if not flying else Rect2(x0, -size.y * 0.5 - hh * 0.5, reach, hh)
			draw_rect(rr, Color(1.0, 0.3, 0.2, 0.12 + 0.3 * tele))
			draw_rect(rr, Color(1.0, 0.4, 0.3, 0.6), false, 2.0)
	if vulnerable or stun_t > 0.0:
		draw_circle(Vector2(0, -size.y - 18.0), 7.0, Color(1.0, 0.95, 0.4, 0.9))
		draw_circle(Vector2(0, -size.y - 18.0), 3.0, Color.WHITE)
