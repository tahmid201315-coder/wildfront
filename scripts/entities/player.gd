class_name Player
extends Actor
## Kael. Responsive platforming (coyote time, jump buffer, variable jump, wall jump, double jump, dash, ladders,
## water) plus a three-hit combo, heavy, air, dash and magic attacks, healing and a stasis pulse.

signal died
signal hurt_signal(amount: float)

const ATTACKS := {
	"l1": {"start": 0.05, "active": 0.09, "rec": 0.13, "dmg": 10.0, "reach": 48.0, "h": 40.0, "knock": Vector2(170, -50), "lunge": 110.0},
	"l2": {"start": 0.04, "active": 0.09, "rec": 0.14, "dmg": 12.0, "reach": 52.0, "h": 40.0, "knock": Vector2(190, -70), "lunge": 130.0},
	"l3": {"start": 0.08, "active": 0.14, "rec": 0.26, "dmg": 20.0, "reach": 62.0, "h": 48.0, "knock": Vector2(320, -200), "lunge": 190.0, "crit": true},
	"heavy": {"start": 0.30, "active": 0.16, "rec": 0.34, "dmg": 34.0, "reach": 68.0, "h": 54.0, "knock": Vector2(460, -240), "lunge": 150.0, "guard_break": true},
	"air": {"start": 0.05, "active": 0.20, "rec": 0.12, "dmg": 13.0, "reach": 50.0, "h": 56.0, "knock": Vector2(190, -110), "lunge": 0.0},
	"dash": {"start": 0.03, "active": 0.14, "rec": 0.20, "dmg": 18.0, "reach": 72.0, "h": 38.0, "knock": Vector2(380, -90), "lunge": 0.0},
}

const MAGIC_COST := 14.0
const STASIS_COST := 30.0

var state: String = "normal"           # normal attack dash dodge hurt climb heal magic interact dead victory
var state_t: float = 0.0
var inp: Dictionary = {}
var use_script: bool = false
var coyote_t: float = 0.0
var jump_buf: float = 0.0
var jumping: bool = false
var air_jumps: int = 0
var air_dash_used: bool = false
var wall_dir: int = 0
var wall_lock_t: float = 0.0
var dash_cd: float = 0.0
var invuln_t: float = 0.0
var land_t: float = 0.0
var crouching: bool = false
var drop_t: float = 0.0
var atk_kind: String = ""
var atk_step: int = 0
var atk_t: float = 0.0
var atk_hit_ids: Dictionary = {}
var atk_queued: String = ""
var combo_window: float = 0.0
var magic_cd: float = 0.0
var heal_t: float = 0.0
var interact_t: float = 0.0
var hurt_flash: float = 0.0
var dash_dir: int = 1
var dash_attack_ok: bool = false
var in_water: bool = false
var air_time: float = 0.0
var peak_fall: float = 0.0
var cast_done: bool = false
var step_t: float = 0.0
var stasis_cd: float = 0.0
var art: KaelArt
var last_safe: Vector2 = Vector2.ZERO
var control_lock: bool = false         # cutscenes and dialogue
var stat_hits: int = 0

const STAND_H := 42.0
const CROUCH_H := 28.0


func _ready() -> void:
	size = Vector2(Tune.PLAYER_SIZE.x, STAND_H)
	art = KaelArt.new()
	art.player = self
	add_child(art)
	z_index = 5


func reset_for_spawn(p: Vector2) -> void:
	position = p
	vel = Vector2.ZERO
	state = "normal"
	state_t = 0.0
	invuln_t = 1.2
	alive = true
	size.y = STAND_H
	crouching = false
	atk_kind = ""
	atk_step = 0
	hurt_flash = 0.0
	last_safe = p
	air_dash_used = false
	air_jumps = 0


# ------------------------------------------------------------------ input
func _read_input() -> void:
	if use_script:
		return
	if control_lock or not Game.is_playing():
		inp = {}
		return
	inp = {
		"x": Input.get_axis("left", "right"),
		"y": Input.get_axis("up", "down"),
		"jump_down": Input.is_action_pressed("jump"),
		"jump_pressed": Input.is_action_just_pressed("jump"),
		"jump_released": Input.is_action_just_released("jump"),
		"light": Input.is_action_just_pressed("light"),
		"heavy": Input.is_action_just_pressed("heavy"),
		"dodge": Input.is_action_just_pressed("dodge"),
		"magic": Input.is_action_just_pressed("magic"),
		"ability": Input.is_action_just_pressed("ability"),
		"interact": Input.is_action_just_pressed("interact"),
		"heal": Input.is_action_just_pressed("heal"),
		"down_held": Input.is_action_pressed("down"),
	}


func _i(key: String, default: Variant = 0.0) -> Variant:
	return inp.get(key, default)


# ------------------------------------------------------------------ main tick
func tick(dt: float) -> void:
	_anim_t += dt
	state_t += dt
	_read_input()
	invuln_t = maxf(invuln_t - dt, 0.0)
	hurt_flash = maxf(hurt_flash - dt, 0.0)
	dash_cd = maxf(dash_cd - dt, 0.0)
	magic_cd = maxf(magic_cd - dt, 0.0)
	stasis_cd = maxf(stasis_cd - dt, 0.0)
	land_t = maxf(land_t - dt, 0.0)
	wall_lock_t = maxf(wall_lock_t - dt, 0.0)
	drop_t = maxf(drop_t - dt, 0.0)
	combo_window = maxf(combo_window - dt, 0.0)
	if combo_window <= 0.0 and state != "attack":
		atk_step = 0
	if state != "dead":
		Game.mp = minf(Game.mp + Game.mp_regen() * dt, Game.max_mp())
	if _i("jump_pressed", false):
		jump_buf = Tune.JUMP_BUFFER
	else:
		jump_buf = maxf(jump_buf - dt, 0.0)
	in_water = level.in_water(rect())
	match state:
		"normal": _tick_normal(dt)
		"attack": _tick_attack(dt)
		"dash", "dodge": _tick_dash(dt)
		"hurt": _tick_hurt(dt)
		"climb": _tick_climb(dt)
		"heal": _tick_heal(dt)
		"magic": _tick_magic(dt)
		"interact": _tick_interact(dt)
		"dead", "victory":
			vel.x = move_toward(vel.x, 0.0, 1600.0 * dt)
			step_physics(dt)
	_check_hazards()
	if on_floor and state in ["normal", "attack"] and level.rect_hits_solid(Rect2(rect().position + Vector2(0, 6), rect().size)) == false:
		if level.tile_at_px(position + Vector2(0, 4)) != Tiles.ICE or true:
			last_safe = position
	if position.y > level.pixel_size().y + 160.0 and state != "dead":
		_fall_into_void()
	art.queue_redraw()


func _set_state(s: String) -> void:
	state = s
	state_t = 0.0


func _speed_mult() -> float:
	return 1.0 + Game.equip_stat("speed")


func _accel_for(x_in: float) -> float:
	var ice := on_floor and floor_tile == Tiles.ICE and Game.equip_stat("ice") <= 0.0
	if on_floor:
		if ice:
			return Tune.ICE_ACCEL if absf(x_in) > 0.1 else Tune.ICE_DECEL
		return Tune.GROUND_ACCEL if absf(x_in) > 0.1 else Tune.GROUND_DECEL
	return Tune.AIR_ACCEL * (1.0 + Game.equip_stat("air"))


func _tick_normal(dt: float) -> void:
	var x_in: float = _i("x")
	var y_in: float = _i("y")
	# ----- ladder entry
	if level.ladder_at(rect()) and (absf(y_in) > 0.5 and (y_in < -0.5 or not on_floor or level.tile_at_px(position + Vector2(0, 6)) == Tiles.LADDER)):
		if not (on_floor and y_in > 0.5 and level.tile_at_px(position + Vector2(0, 6)) != Tiles.LADDER):
			_begin_climb()
			return
	# ----- crouch
	var want_crouch: bool = on_floor and y_in > 0.6 and not level.ladder_at(rect()) and level.tile_at_px(position + Vector2(0, 4)) != Tiles.ONEWAY
	if want_crouch and not crouching:
		crouching = true
		size.y = CROUCH_H
	elif crouching and not want_crouch:
		var tall := Rect2(position.x - size.x * 0.5, position.y - STAND_H, size.x, STAND_H)
		if not level.rect_hits_solid(tall):
			crouching = false
			size.y = STAND_H
	# ----- horizontal
	var locked := wall_lock_t > 0.0
	var spd := Tune.RUN_SPEED * _speed_mult()
	if absf(x_in) < 0.55:
		spd = Tune.WALK_SPEED
	if crouching:
		spd *= 0.35
	if in_water:
		spd *= 0.72
	var target := signf(x_in) * spd * (1.0 if absf(x_in) > 0.15 else 0.0)
	if locked:
		target = vel.x
	vel.x = move_toward(vel.x, target, _accel_for(x_in) * dt)
	if absf(x_in) > 0.2 and not locked:
		facing = 1 if x_in > 0.0 else -1
	# ----- gravity and water
	var g_scale := 1.0
	if in_water:
		g_scale = 0.3
	gravity_scale = g_scale
	# ----- ground / coyote bookkeeping
	if on_floor:
		coyote_t = Tune.COYOTE
		air_jumps = 0
		air_dash_used = false
		wall_dir = 0
	else:
		coyote_t = maxf(coyote_t - dt, 0.0)
	# ----- wall slide
	wall_dir = 0
	if not on_floor and Game.has_ability("wall_jump") and not in_water and vel.y > 0.0:
		for d in [-1, 1]:
			if level.wall_probe(rect(), d) and signf(x_in) == float(d):
				wall_dir = d
	# ----- jump
	if jump_buf > 0.0:
		if in_water and not on_floor:
			vel.y = -250.0
			jump_buf = 0.0
			Sfx.play("splash", 1.2)
		elif on_floor and y_in > 0.6 and level.tile_at_px(position + Vector2(0, 4)) == Tiles.ONEWAY:
			drop_t = 0.22
			jump_buf = 0.0
			position.y += 3.0
		elif coyote_t > 0.0:
			_do_jump()
		elif wall_dir != 0:
			vel = Vector2(-wall_dir * Tune.WALL_JUMP_V.x, Tune.WALL_JUMP_V.y)
			facing = -wall_dir
			wall_lock_t = 0.16
			jump_buf = 0.0
			jumping = true
			air_jumps = 0
			Sfx.play("jump", 1.15)
			stage.fx.dust(position, 5)
		elif Game.has_ability("double_jump") and air_jumps < 1:
			air_jumps += 1
			vel.y = -Tune.JUMP_V * 0.92
			jump_buf = 0.0
			jumping = true
			Sfx.play("jump", 1.3)
			stage.fx.ring(position + Vector2(0, -6), Defs.REGIONS[level.region_id]["glow"])
	if _i("jump_released", false) and jumping and vel.y < 0.0:
		vel.y *= Tune.JUMP_CUT
		jumping = false
	if vel.y >= 0.0:
		jumping = false
	if wall_dir != 0:
		vel.y = minf(vel.y, Tune.WALL_SLIDE)
	# ----- actions
	if _try_actions():
		return
	# ----- move
	var was_floor := on_floor
	var fall_speed := vel.y
	step_physics(dt, true, drop_t > 0.0)
	if in_water:
		vel.y = clampf(vel.y, -400.0, 150.0)
	if on_floor and not was_floor and fall_speed > 260.0:
		land_t = 0.14 if fall_speed > 520.0 else 0.08
		stage.fx.dust(position, 4 + int(fall_speed / 200.0))
		Sfx.play("land", 1.0 - fall_speed / 3000.0)
	if not on_floor:
		air_time += dt
	else:
		air_time = 0.0
	# footsteps
	if on_floor and absf(vel.x) > 80.0:
		step_t -= dt
		if step_t <= 0.0:
			step_t = 0.28 if absf(vel.x) > 200.0 else 0.4
			Sfx.play("step_" + _surface(), randf_range(0.9, 1.1))
			if absf(vel.x) > 200.0:
				stage.fx.dust(position + Vector2(-facing * 6, 0), 1)


func _surface() -> String:
	match floor_tile:
		Tiles.ICE: return "ice"
		Tiles.BRICK: return "stone"
	return "grass" if level.region_id in ["meadows", "thornwild"] else "stone"


func _do_jump() -> void:
	vel.y = -Tune.JUMP_V
	coyote_t = 0.0
	jump_buf = 0.0
	jumping = true
	on_floor = false
	Sfx.play("jump")
	stage.fx.dust(position, 3)


func _try_actions() -> bool:
	if _i("interact", false) and on_floor and stage.try_interact(self):
		_set_state("interact")
		return true
	if _i("heal", false) and Game.heals_left > 0 and Game.hp < Game.max_hp() and on_floor:
		_set_state("heal")
		heal_t = 0.0
		vel.x = 0.0
		return true
	if _i("dodge", false):
		if _start_dash():
			return true
	if _i("heavy", false):
		_start_attack("heavy")
		return true
	if _i("light", false):
		_start_attack("air" if not on_floor and not in_water else _next_combo())
		return true
	if _i("magic", false) and magic_cd <= 0.0:
		var cost := Game.magic_cost(MAGIC_COST)
		if Game.mp >= cost:
			Game.mp -= cost
			_set_state("magic")
			cast_done = false
			magic_cd = 0.3
			Game.stats_changed.emit()
			return true
		else:
			Sfx.play("deny")
	if _i("ability", false) and Game.has_ability("stasis") and stasis_cd <= 0.0:
		var c2 := Game.magic_cost(STASIS_COST)
		if Game.mp >= c2:
			Game.mp -= c2
			stasis_cd = 2.0
			stage.stasis_pulse(center(), 230.0, 4.0)
			Sfx.play("stasis")
			_set_state("magic")
			cast_done = true
			Game.stats_changed.emit()
			return true
		else:
			Sfx.play("deny")
	return false


func _next_combo() -> String:
	var step := 1 if combo_window <= 0.0 else clampi(atk_step + 1, 1, 3)
	if step > 3:
		step = 1
	return "l%d" % step


# ------------------------------------------------------------------ attacks
func _start_attack(kind: String) -> void:
	atk_kind = kind
	if kind.begins_with("l"):
		atk_step = int(kind.substr(1))
	_set_state("attack")
	atk_t = 0.0
	atk_hit_ids.clear()
	atk_queued = ""
	var a: Dictionary = ATTACKS[kind]
	if on_floor and not crouching:
		vel.x = facing * float(a["lunge"])
	elif not on_floor and kind == "air":
		vel.y = minf(vel.y, 60.0) if vel.y > 0.0 else vel.y
	Sfx.play("swing_heavy" if kind == "heavy" else "swing", 0.9 + 0.1 * atk_step)


func _tick_attack(dt: float) -> void:
	var a: Dictionary = ATTACKS[atk_kind]
	atk_t += dt
	var s: float = a["start"]
	var ac: float = a["active"]
	var rec: float = a["rec"]
	# movement
	if on_floor:
		vel.x = move_toward(vel.x, 0.0, 1500.0 * dt)
	else:
		vel.x = move_toward(vel.x, _i("x") * Tune.WALK_SPEED, Tune.AIR_ACCEL * 0.5 * dt)
	gravity_scale = 0.6 if atk_kind == "air" else 1.0
	step_physics(dt)
	if on_floor:
		air_jumps = 0
	# hit window
	if atk_t >= s and atk_t <= s + ac:
		var hb := attack_hitbox(a)
		var info := {"damage": float(a["dmg"]) * _dmg_mult(atk_kind), "knock": Vector2(float(a["knock"].x) * facing, float(a["knock"].y)),
			"kind": atk_kind, "crit": bool(a.get("crit", false)), "guard_break": bool(a.get("guard_break", false)),
			"from": position, "element": "blade"}
		var n: int = stage.hit_targets(hb, info, atk_hit_ids)
		if n > 0:
			stat_hits += n
			var heavy := atk_kind == "heavy" or atk_kind == "l3"
			stage.hitstop(Tune.HITSTOP_HEAVY if heavy else Tune.HITSTOP_LIGHT)
			stage.shake(5.0 if heavy else 2.5)
			if atk_kind == "air":
				vel.y = -210.0
	# buffered inputs
	if _i("light", false) and atk_queued == "":
		atk_queued = "light"
	if _i("heavy", false):
		atk_queued = "heavy"
	if _i("dodge", false) and atk_t > s + ac:
		if _start_dash():
			return
	if atk_t >= s + ac + rec:
		combo_window = 0.35 if atk_kind.begins_with("l") else 0.0
		_set_state("normal")
		atk_kind = "" if atk_queued == "" else atk_kind
		if atk_queued == "light":
			_start_attack("air" if not on_floor else _next_combo())
		elif atk_queued == "heavy":
			_start_attack("heavy")
	elif atk_t > s + ac * 0.5 and atk_queued != "" and atk_t >= s + ac:
		# cancel recovery early into the queued attack (feels snappier for combos)
		if atk_queued == "light" and atk_kind.begins_with("l") and atk_t >= s + ac + rec * 0.55:
			_start_attack(_next_combo())


func attack_hitbox(a: Dictionary) -> Rect2:
	var reach: float = a["reach"]
	var h: float = a["h"]
	var x0 := position.x + (facing * (size.x * 0.5 - 4.0) if facing > 0 else -reach - (size.x * 0.5 - 4.0))
	var y0 := position.y - size.y * 0.5 - h * 0.5
	if atk_kind == "air":
		y0 = position.y - size.y * 0.6
	return Rect2(x0, y0, reach, h)


func _dmg_mult(kind: String) -> float:
	var m := 1.0
	if kind.begins_with("l") or kind == "air" or kind == "dash":
		m = Game.light_mult()
	elif kind == "heavy":
		m = Game.heavy_mult()
	return m


# ------------------------------------------------------------------ dash / dodge
func _start_dash() -> bool:
	if dash_cd > 0.0:
		return false
	var has_dash := Game.has_ability("dash")
	if not on_floor and (air_dash_used or not has_dash):
		return false
	if in_water:
		return false
	var dir := int(signf(_i("x"))) if absf(_i("x")) > 0.3 else facing
	dash_dir = dir
	if not on_floor:
		air_dash_used = true
	dash_attack_ok = has_dash
	_set_state("dash" if has_dash else "dodge")
	dash_cd = Game.dash_cooldown() * (1.0 if has_dash else 1.3)
	invuln_t = maxf(invuln_t, 0.28 if has_dash else 0.24)
	facing = dir
	Sfx.play("dash" if has_dash else "dodge")
	stage.fx.dust(position, 5)
	return true


func _tick_dash(dt: float) -> void:
	var has_dash := state == "dash"
	var dur := Tune.DASH_TIME * (1.0 + 0.1 * Game.skill("windstep")) if has_dash else 0.24
	var spd := Tune.DASH_SPEED * (1.0 + 0.08 * Game.skill("windstep")) if has_dash else 330.0
	vel.x = dash_dir * spd * (1.0 - 0.5 * state_t / dur)
	if has_dash:
		vel.y = 0.0
		step_physics(dt, false)
	else:
		step_physics(dt, true)
	stage.fx.trail(position, dash_dir)
	if has_dash and _i("light", false) and dash_attack_ok:
		_start_attack("dash")
		vel.x = dash_dir * 300.0
		return
	if state_t >= dur or wall_hit != 0:
		vel.x *= 0.4
		_set_state("normal")


# ------------------------------------------------------------------ hurt / death
func hurt(amount: float, from_x: float, knock: float = 1.0) -> bool:
	if invuln_t > 0.0 or state == "dead" or state == "victory" or amount <= 0.0:
		return false
	if state in ["dash"] and invuln_t > 0.0:
		return false
	var dmg := amount * (1.0 - Game.equip_stat("defense"))
	dmg = maxf(round(dmg), 1.0)
	Game.hp -= dmg
	Game.stats_changed.emit()
	hurt_signal.emit(dmg)
	invuln_t = Tune.INVULN_TIME
	Game.run_hits += 1
	hurt_flash = 0.3
	var dir := 1.0 if position.x >= from_x else -1.0
	vel = Vector2(dir * 230.0 * knock, -260.0)
	on_floor = false
	crouching = false
	size.y = STAND_H
	heal_t = 0.0
	atk_kind = ""
	stage.hitstop(0.07)
	stage.shake(7.0)
	stage.fx.burst(center(), Color(1, 0.4, 0.4), 8, 160.0)
	stage.flash_screen(Color(1, 0.2, 0.2, 0.25))
	Sfx.play("hurt")
	if Game.hp <= 0.0:
		die()
		return true
	_set_state("hurt")
	return true


func _tick_hurt(dt: float) -> void:
	vel.x = move_toward(vel.x, 0.0, 700.0 * dt)
	gravity_scale = 1.0
	step_physics(dt)
	if state_t >= 0.28 and (on_floor or state_t > 0.5):
		_set_state("normal")


func die() -> void:
	if state == "dead":
		return
	Game.hp = 0.0
	_set_state("dead")
	alive = false
	vel = Vector2(-facing * 120.0, -300.0)
	Sfx.play("defeat")
	stage.fx.burst(center(), Color(1, 0.9, 0.7), 18, 220.0)
	died.emit()


func _fall_into_void() -> void:
	# falling out of the world costs a little health and returns Kael to the last safe ground
	if not alive:
		return
	position = last_safe
	vel = Vector2.ZERO
	invuln_t = 1.0
	Game.hp = maxf(Game.hp - 12.0, 0.0)
	Game.stats_changed.emit()
	stage.flash_screen(Color(0, 0, 0, 0.5))
	Sfx.play("hurt")
	if Game.hp <= 0.0:
		die()


func _check_hazards() -> void:
	if invuln_t > 0.0 or state in ["dead", "victory"]:
		return
	var hz := level.hazard_in(rect())
	if hz.is_empty():
		return
	var dmg: float = hz["damage"]
	if hz["tile"] == Tiles.LAVA and Game.equip_stat("fire") > 0.0:
		dmg *= 0.6
	if hz["tile"] == Tiles.THORN:
		dmg *= 1.0 - Game.equip_stat("thorn")
	var from_x: float = position.x - float(facing) * 12.0
	var was_lava: bool = hz["tile"] == Tiles.LAVA
	if hurt(dmg, from_x):
		if alive and Game.hp > 0.0 and (hz["tile"] == Tiles.SPIKE or hz["tile"] == Tiles.LAVA):
			# bounce clear of the hazard and restore a safe position so a hit does not chain
			if was_lava:
				vel.y = -520.0
			position = last_safe if hz["tile"] == Tiles.SPIKE else position


# ------------------------------------------------------------------ ladder
func _begin_climb() -> void:
	_set_state("climb")
	vel = Vector2.ZERO
	position.x = level.ladder_column_x(rect())
	air_dash_used = false
	air_jumps = 0
	crouching = false
	size.y = STAND_H


func _tick_climb(dt: float) -> void:
	var y_in: float = _i("y")
	var x_in: float = _i("x")
	vel = Vector2(0.0, y_in * Tune.CLIMB_SPEED)
	var r := rect()
	var res := level.move_body(r, vel, dt, true)
	set_rect_pos(res["rect"])
	on_floor = res["floor"]
	floor_tile = res["floor_tile"]
	if jump_buf > 0.0:
		jump_buf = 0.0
		vel = Vector2(x_in * 160.0, -Tune.JUMP_V * 0.8)
		_set_state("normal")
		jumping = true
		return
	if not level.ladder_at(rect()) or (on_floor and y_in > 0.3):
		_set_state("normal")
		if not on_floor and y_in < 0.0:
			vel.y = -200.0
	if _i("light", false):
		_set_state("normal")
		_start_attack(_next_combo())


# ------------------------------------------------------------------ heal / magic / interact
func _tick_heal(dt: float) -> void:
	heal_t += dt
	vel.x = 0.0
	step_physics(dt)
	if int(heal_t * 20.0) % 3 == 0:
		stage.fx.sparkle(position + Vector2(randf_range(-10, 10), -randf_range(0, 40)), Color(0.5, 1.0, 0.7))
	if heal_t >= 0.7:
		Game.heals_left -= 1
		Game.hp = minf(Game.hp + Game.heal_amount(), Game.max_hp())
		Game.stats_changed.emit()
		Sfx.play("heal")
		stage.fx.ring(center(), Color(0.5, 1.0, 0.7))
		_set_state("normal")
	elif _i("dodge", false) and _start_dash():
		heal_t = 0.0


func _tick_magic(dt: float) -> void:
	vel.x = move_toward(vel.x, 0.0, 1400.0 * dt)
	step_physics(dt)
	if not cast_done and state_t >= 0.12:
		cast_done = true
		var dir := Vector2(facing, 0.0)
		var from_p := position + Vector2(facing * 16.0, -size.y * 0.55)
		if Game.settings.get("auto_aim", true):
			var bd := 460.0
			for h in stage.hittables:
				if not is_instance_valid(h) or not h.alive:
					continue
				var rel: Vector2 = h.hit_rect().get_center() - from_p
				if absf(rel.x) > 12.0 and signf(rel.x) != float(facing):
					continue
				if rel.length() < bd:
					bd = rel.length()
					dir = rel.normalized()
		var dmg := 16.0 * (1.0 + 0.1 * Game.skill("aether")) + 4.0 * Game.fragments
		stage.spawn_bolt(from_p, dir, dmg)
		Sfx.play("bolt")
	if state_t >= 0.26:
		_set_state("normal")


func _tick_interact(dt: float) -> void:
	vel.x = 0.0
	step_physics(dt)
	if state_t >= 0.3:
		_set_state("normal")


func _tick_interact_dummy() -> void:
	pass


func set_victory() -> void:
	_set_state("victory")
	vel = Vector2.ZERO
